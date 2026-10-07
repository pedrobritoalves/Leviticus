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
