import { createHash } from "node:crypto";
import { Fault } from "./errors.js";
import { identifier, person, ministry } from "./validation.js";
export { Fault, person };
export const id = identifier;
const fail = (code, message) => {
  throw new Fault(code, message);
};
export function authorize(auth, membership) {
  if (!auth?.uid) fail("unauthenticated", "Entre para continuar.");
  if (auth.email_verified !== true)
    fail("permission-denied", "Confirme seu e-mail.");
  if (
    membership?.active !== true ||
    !["admin", "secretary", "pastor"].includes(membership.role)
  )
    fail("permission-denied", "Acesso não autorizado para esta igreja.");
}
// All reads and writes in the callback must execute in one retriable transaction.
function resourceService(
  store,
  { collection, validate, idField, valueField, eventName },
) {
  return {
    async save(auth, data) {
      if (!auth?.uid) fail("unauthenticated", "Entre para continuar.");
      const churchId = id(data?.churchId),
        entityId = id(data?.[idField]),
        requestId = id(data?.requestId);
      const values = validate(data[valueField]),
        expected = data.expectedVersion;
      if (!Number.isInteger(expected) || expected < 0)
        fail("invalid-argument", "Versão inválida.");
      const fingerprint = createHash("sha256")
        .update(JSON.stringify({ entityId, values, expected }))
        .digest("hex");
      return store.transaction(churchId, async (tx) => {
        authorize(auth, await tx.membership(auth.uid));
        const receiptKey = createHash("sha256")
          .update(`${collection}:${auth.uid}:${requestId}`)
          .digest("hex");
        const receipt = await tx.receipt(receiptKey);
        if (receipt) {
          if (receipt.fingerprint !== fingerprint)
            fail("already-exists", "Identificador de operação reutilizado.");
          return receipt.result;
        }
        const current = await tx.record(collection, entityId);
        if ((current?.version ?? 0) !== expected)
          fail(
            "aborted",
            "Cadastro alterado por outra pessoa. Atualize a lista.",
          );
        if (collection === "ministries") {
          for (const personId of values.memberIds)
            if (!(await tx.record("people", personId)))
              fail(
                "failed-precondition",
                "Participante não cadastrado nesta igreja.",
              );
        }
        const time = store.now();
        const record = {
          ...values,
          id: entityId,
          churchId,
          version: expected + 1,
          createdAt: current?.createdAt ?? time,
          updatedAt: time,
        };
        const event = {
          type: `${eventName}${current ? "Updated" : "Created"}`,
          actorId: auth.uid,
          entityId,
          version: record.version,
          at: time,
          schemaVersion: 1,
        };
        tx.putRecord(collection, entityId, record);
        tx.putAudit(receiptKey, event);
        tx.putReceipt(receiptKey, { fingerprint, result: record });
        return record;
      });
    },
    async list(auth, data) {
      if (!auth?.uid) fail("unauthenticated", "Entre para continuar.");
      const churchId = id(data?.churchId),
        after = data.after ? id(data.after) : null;
      return store.transaction(churchId, async (tx) => {
        authorize(auth, await tx.membership(auth.uid));
        const items = await tx.records(collection, after, 100);
        tx.putAudit(store.newId(), {
          type: `${eventName}Listed`,
          actorId: auth.uid,
          at: store.now(),
          count: items.length,
          schemaVersion: 1,
        });
        return {
          items,
          nextCursor: items.length === 100 ? items.at(-1).id : null,
        };
      });
    },
  };
}
export const service = (store) =>
  resourceService(store, {
    collection: "people",
    validate: person,
    idField: "personId",
    valueField: "person",
    eventName: "Person",
  });
export const ministriesService = (store) =>
  resourceService(store, {
    collection: "ministries",
    validate: ministry,
    idField: "ministryId",
    valueField: "ministry",
    eventName: "Ministry",
  });
