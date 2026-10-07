import { FieldPath, Filter } from "firebase-admin/firestore";
import { randomUUID } from "node:crypto";
export function firestoreStore(db) {
  return {
    now: () => new Date().toISOString(),
    newId: randomUUID,
    transaction: (churchId, callback) =>
      db.runTransaction(async (transaction) => {
        const root = db.collection("churches").doc(churchId);
        const ref = (collection, key) => root.collection(collection).doc(key);
        const get = async (collection, key) =>
          (await transaction.get(ref(collection, key))).data();
        return callback({
          church: async () => (await transaction.get(root)).data(),
          prayers: async (uid, isPastor, after, limit) => {
            let q = root
              .collection("prayers")
              .where(
                isPastor
                  ? Filter.or(
                      Filter.where("authorId", "==", uid),
                      Filter.where("assignedTo", "==", uid),
                    )
                  : Filter.where("authorId", "==", uid),
              )
              .orderBy(FieldPath.documentId())
              .limit(limit);
            if (after) q = q.startAfter(after);
            return (await transaction.get(q)).docs.map((d) => d.data());
          },
          membership: (uid) => get("users", uid),
          receipt: (key) => get("operations", key),
          record: get,
          records: async (collection, after, limit) => {
            let q = root
              .collection(collection)
              .orderBy(FieldPath.documentId())
              .limit(limit);
            if (after) q = q.startAfter(after);
            return (await transaction.get(q)).docs.map((d) => d.data());
          },
          putRecord: (collection, key, value) =>
            transaction.set(ref(collection, key), value),
          putAudit: (key, value) =>
            transaction.create(ref("audit", key), value),
          putReceipt: (key, value) =>
            transaction.create(ref("operations", key), value),
        });
      }),
  };
}
