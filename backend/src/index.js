import { prayerService } from "./prayer_service.js";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { service, ministriesService, eventsService, Fault } from "./service.js";
import { firestoreStore } from "./firestore_store.js";
initializeApp();
const store = firestoreStore(getFirestore());
const people = service(store),
  ministries = ministriesService(store);
const options = {
  region: "southamerica-east1",
  maxInstances: 5,
  enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true",
};
const handler = (resource, method) =>
  onCall(options, async (request) => {
    try {
      return await resource[method](
        request.auth
          ? {
              uid: request.auth.uid,
              email_verified: request.auth.token.email_verified,
            }
          : null,
        request.data,
      );
    } catch (e) {
      if (e instanceof Fault) throw new HttpsError(e.code, e.message);
      throw new HttpsError("internal", "Não foi possível concluir a operação.");
    }
  });
export const savePerson = handler(people, "save");
export const listPeople = handler(people, "list");
export const saveMinistry = handler(ministries, "save");
export const listMinistries = handler(ministries, "list");

const events = eventsService(store);
export const saveEvent = handler(events, "save");
export const listEvents = handler(events, "list");

const prayers = prayerService(store);
export const submitPrayer = handler(prayers, "submit");
export const listPrayers = handler(prayers, "list");
export const updatePrayer = handler(prayers, "update");
export const getWorkspace = onCall(options, async (request) => {
  const auth = request.auth;
  if (!auth || auth.token.email_verified !== true)
    throw new HttpsError("unauthenticated", "Entre com e-mail confirmado.");
  const churchId = request.data?.churchId;
  if (typeof churchId !== "string" || !/^[a-zA-Z0-9_-]{1,100}$/.test(churchId))
    throw new HttpsError("invalid-argument", "Igreja inválida.");
  return store.transaction(churchId, async (tx) => {
    const member = await tx.membership(auth.uid);
    if (
      member?.active !== true ||
      !["admin", "secretary", "pastor", "member"].includes(member.role)
    )
      throw new HttpsError("permission-denied", "Acesso não autorizado.");
    return { role: member.role };
  });
});
