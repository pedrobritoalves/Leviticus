import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
if (
  process.env.FIRESTORE_EMULATOR_HOST !== "127.0.0.1:8080" ||
  process.env.FIREBASE_AUTH_EMULATOR_HOST !== "127.0.0.1:9099"
)
  throw Error("Seed permitido somente nos emuladores locais.");
initializeApp({ projectId: "demo-leviticus" });
const auth = getAuth(),
  db = getFirestore();
for (const [uid, email, role, church] of [
  ["demo-secretary", "secretaria@example.test", "secretary", "igreja-demo"],
  ["demo-pastor", "pastor@example.test", "pastor", "igreja-demo"],
  ["demo-member", "membro@example.test", "member", "igreja-demo"],
  ["demo-consultant", "consultoria@example.test", "consultant", "igreja-demo"],
  ["demo-other", "outra@example.test", "admin", "outra-igreja"],
]) {
  const data = { email, password: "LeviticusDemo2026!", emailVerified: true };
  try {
    await auth.createUser({ uid, ...data });
  } catch (e) {
    if (e.code !== "auth/uid-already-exists") throw e;
    await auth.updateUser(uid, data);
  }
  await db.doc(`churches/${church}/users/${uid}`).set({ active: true, role });
  await db
    .doc(`churches/${church}`)
    .set({
      name:
        church === "igreja-demo" ? "Igreja de demonstração" : "Outra igreja",
      intakePastorUid: church === "igreja-demo" ? "demo-pastor" : "",
    });
}
console.log(
  "Contas fictícias criadas nos emuladores. Consulte docs/EXECUTAR.md.",
);
