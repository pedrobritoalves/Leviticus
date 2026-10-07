import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
let app, token, consultantToken;
const projectId = "demo-leviticus";
async function signIn(email) {
  const response = await fetch(
    "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key",
    {
      method: "POST",
      signal: AbortSignal.timeout(20000),
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email,
        password: "EmulatorOnly2026!",
        returnSecureToken: true,
      }),
    },
  );
  assert.equal(response.status, 200);
  return (await response.json()).idToken;
}
async function call(name, data, auth) {
  return fetch(
    `http://127.0.0.1:5001/${projectId}/southamerica-east1/${name}`,
    {
      method: "POST",
      signal: AbortSignal.timeout(20000),
      headers: {
        "Content-Type": "application/json",
        ...(auth ? { Authorization: `Bearer ${auth}` } : {}),
      },
      body: JSON.stringify({ data }),
    },
  );
}
before(async () => {
  if (
    !process.env.FIRESTORE_EMULATOR_HOST ||
    !process.env.FIREBASE_AUTH_EMULATOR_HOST
  )
    throw Error("Somente emuladores.");
  app = initializeApp({ projectId }, "callable-e2e");
  const auth = getAuth(app),
    db = getFirestore(app);
  for (const [uid, role] of [
    ["e2e-admin", "admin"],
    ["e2e-consultant", "consultant"],
  ]) {
    await auth.createUser({
      uid,
      email: `${uid}@example.test`,
      password: "EmulatorOnly2026!",
      emailVerified: true,
    });
    await db
      .doc(`churches/e2e-church/users/${uid}`)
      .set({ active: true, role });
  }
  token = await signIn("e2e-admin@example.test");
  consultantToken = await signIn("e2e-consultant@example.test");
});
after(async () => {
  if (app) await deleteApp(app);
});
test("login por Auth → callable → Firestore → leitura em nova chamada", async () => {
  const response = await call(
    "savePerson",
    {
      churchId: "e2e-church",
      personId: "e2e-person",
      requestId: "e2e-create",
      expectedVersion: 0,
      person: { name: "Pessoa E2E", status: "member" },
    },
    token,
  );
  assert.equal(response.status, 200);
  assert.equal((await response.json()).result.version, 1);
  const list = await call("listPeople", { churchId: "e2e-church" }, token);
  assert.equal(list.status, 200);
  assert.equal((await list.json()).result.items[0].name, "Pessoa E2E");
});
test("callable rejeita anônimo, consultor e outra igreja", async () => {
  for (const [auth, church, expected] of [
    [null, "e2e-church", 401],
    [consultantToken, "e2e-church", 403],
    [token, "outra-igreja", 403],
  ]) {
    const response = await call("listPeople", { churchId: church }, auth);
    assert.equal(response.status, expected);
  }
});

test("agenda por callable persiste, cancela e nega acesso indevido", async () => {
  // Create our own person: this case does not depend on a previous test's record.
  const person = await call(
    "savePerson",
    {
      churchId: "e2e-church",
      personId: "agenda-person",
      requestId: "agenda-person-create",
      expectedVersion: 0,
      person: { name: "Responsável agenda", status: "member" },
    },
    token,
  );
  assert.equal(person.status, 200);
  const event = {
    title: "Evento E2E",
    location: "Sede",
    startsAt: "2026-10-13T18:00:00Z",
    endsAt: "2026-10-13T19:00:00Z",
    organizerId: "agenda-person",
    status: "scheduled",
  };
  const input = {
    churchId: "e2e-church",
    eventId: "e2e-event",
    requestId: "e2e-event-create",
    expectedVersion: 0,
    event,
  };
  const created = await call("saveEvent", input, token);
  assert.equal(created.status, 200);
  assert.equal((await created.json()).result.version, 1);
  const cancelled = await call(
    "saveEvent",
    {
      ...input,
      requestId: "e2e-event-cancel",
      expectedVersion: 1,
      event: { ...event, status: "cancelled" },
    },
    token,
  );
  assert.equal(cancelled.status, 200);
  const listed = await call("listEvents", { churchId: "e2e-church" }, token);
  assert.equal(listed.status, 200);
  assert.equal((await listed.json()).result.items[0].status, "cancelled");
  assert.equal(
    (await call("listEvents", { churchId: "e2e-church" }, consultantToken))
      .status,
    403,
  );
  assert.equal(
    (await call("saveEvent", { ...input, churchId: "another-church" }, token))
      .status,
    403,
  );
});
