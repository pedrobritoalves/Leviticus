import { prayerService } from "../src/prayer_service.js";
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import {
  initializeTestEnvironment,
  assertFails,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { service, ministriesService } from "../src/service.js";
import { firestoreStore } from "../src/firestore_store.js";
const projectId = "demo-leviticus";
let environment, app, db, people, ministries;
const user = { uid: "secretary", email_verified: true };
const request = {
  churchId: "church-a",
  personId: "person-a",
  requestId: "create-a",
  expectedVersion: 0,
  person: { name: "Pessoa Teste", status: "member" },
};
before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST)
    throw Error("Emulador obrigatório.");
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules: await readFile(
        new URL("../../infra/firestore.rules", import.meta.url),
        "utf8",
      ),
    },
  });
  await environment.clearFirestore();
  app = initializeApp({ projectId }, "integration");
  db = getFirestore(app);
  await db
    .doc("churches/church-a/users/secretary")
    .set({ active: true, role: "secretary" });
  const store = firestoreStore(db);
  people = service(store);
  ministries = ministriesService(store);
});
after(async () => {
  await environment?.cleanup();
  if (app) await deleteApp(app);
});
test("transações reais: criação, idempotência, conflito e vínculo de ministério", async () => {
  const [a, b] = await Promise.all([
    people.save(user, request),
    people.save(user, request),
  ]);
  assert.deepEqual(a, b);
  assert.equal((await db.collection("churches/church-a/audit").get()).size, 1);
  const edits = await Promise.allSettled(
    ["edit1", "edit2"].map((requestId) =>
      people.save(user, {
        ...request,
        requestId,
        expectedVersion: 1,
        person: { ...request.person, name: requestId },
      }),
    ),
  );
  assert.equal(edits.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(
    edits.filter((r) => r.status === "rejected" && r.reason.code === "aborted")
      .length,
    1,
  );
  const ministry = await ministries.save(user, {
    churchId: "church-a",
    ministryId: "welcome",
    requestId: "min1",
    expectedVersion: 0,
    ministry: {
      name: "Recepção",
      description: "",
      active: true,
      leaderId: "person-a",
      memberIds: ["person-a"],
    },
  });
  assert.equal(ministry.version, 1);
  await assert.rejects(people.list(user, { churchId: "church-b" }), {
    code: "permission-denied",
  });
  await db.doc("churches/church-a/users/secretary").update({ active: false });
  await assert.rejects(people.save(user, request), {
    code: "permission-denied",
  });
});
test("regras negam acesso direto, promoção de papel e adulteração da auditoria", async () => {
  for (const client of [
    environment.unauthenticatedContext().firestore(),
    environment
      .authenticatedContext("secretary", { email_verified: true })
      .firestore(),
  ]) {
    await assertFails(getDoc(doc(client, "churches/church-a/people/person-a")));
    await assertFails(
      setDoc(doc(client, "churches/church-a/users/secretary"), {
        active: true,
        role: "admin",
      }),
    );
    await assertFails(
      setDoc(doc(client, "churches/church-a/audit/forged"), { type: "forged" }),
    );
    await assertFails(
      setDoc(doc(client, "churches/church-b/people/forged"), {
        name: "forged",
      }),
    );
  }
});

test("consulta sigilosa Firestore restringe autor e pastor atribuído", async () => {
  await db
    .doc("churches/prayer-church")
    .set({ intakePastorUid: "prayer-pastor" });
  for (const [uid, role] of [
    ["requester", "member"],
    ["outsider", "member"],
    ["prayer-pastor", "pastor"],
    ["another-pastor", "pastor"],
    ["office", "secretary"],
  ])
    await db
      .doc(`churches/prayer-church/users/${uid}`)
      .set({ active: true, role });
  const prayers = prayerService(firestoreStore(db));
  const auth = (uid) => ({ uid, email_verified: true });
  await prayers.submit(auth("requester"), {
    churchId: "prayer-church",
    prayerId: "request-one",
    requestId: "request-one",
    subject: "Oração reservada",
    body: "Conteúdo fictício protegido",
  });
  for (const [uid, count] of [
    ["requester", 1],
    ["prayer-pastor", 1],
    ["outsider", 0],
    ["another-pastor", 0],
  ])
    assert.equal(
      (await prayers.list(auth(uid), { churchId: "prayer-church" })).items
        .length,
      count,
    );
  await assert.rejects(
    prayers.list(auth("office"), { churchId: "prayer-church" }),
    { code: "permission-denied" },
  );
});
