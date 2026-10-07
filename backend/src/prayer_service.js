import { createHash } from "node:crypto";
import { Fault } from "./errors.js";
import { identifier as id } from "./validation.js";
const deny = () => {
  throw new Fault("permission-denied", "Acesso não autorizado.");
};
async function access(tx, auth) {
  if (!auth?.uid) throw new Fault("unauthenticated", "Entre para continuar.");
  const member = await tx.membership(auth.uid);
  if (
    auth.email_verified !== true ||
    member?.active !== true ||
    !["member", "pastor"].includes(member.role)
  )
    deny();
  return member;
}
function content(value, max) {
  if (
    typeof value !== "string" ||
    value.trim().length < 2 ||
    value.length > max ||
    /[\x00-\x08\x0b\x0c\x0e-\x1f]/.test(value)
  )
    throw new Fault("invalid-argument", "Pedido inválido.");
  return value.trim();
}
const hash = (value) => createHash("sha256").update(value).digest("hex");
export function prayerService(store) {
  return {
    async submit(auth, data) {
      const church = id(data?.churchId),
        requestId = id(data?.requestId),
        prayerId = id(data?.prayerId);
      const subject = content(data.subject, 120),
        body = content(data.body, 2000);
      return store.transaction(church, async (tx) => {
        await access(tx, auth);
        const key = hash(`prayer-submit:${auth.uid}:${requestId}`),
          fingerprint = hash(JSON.stringify({ prayerId, subject, body }));
        const receipt = await tx.receipt(key);
        if (receipt) {
          if (receipt.fingerprint !== fingerprint)
            throw new Fault("already-exists", "Operação reutilizada.");
          return receipt.result;
        }
        const settings = await tx.church();
        const assignedTo = settings?.intakePastorUid;
        if (!assignedTo)
          throw new Fault(
            "failed-precondition",
            "A igreja precisa configurar o pastor responsável pelo acolhimento.",
          );
        id(assignedTo);
        const pastor = await tx.membership(assignedTo);
        if (pastor?.active !== true || pastor.role !== "pastor")
          throw new Fault("failed-precondition", "Responsável indisponível.");
        if (await tx.record("prayers", prayerId))
          throw new Fault("already-exists", "Pedido já cadastrado.");
        const at = store.now(),
          record = {
            id: prayerId,
            churchId: church,
            subject,
            body,
            authorId: auth.uid,
            assignedTo,
            status: "open",
            nextContactAt: "",
            version: 1,
            createdAt: at,
            updatedAt: at,
          };
        tx.putRecord("prayers", prayerId, record);
        tx.putReceipt(key, { fingerprint, result: record });
        tx.putAudit(key, {
          type: "PrayerSubmitted",
          actorId: auth.uid,
          entityId: prayerId,
          at,
          schemaVersion: 1,
        });
        return record;
      });
    },
    async list(auth, data) {
      const church = id(data?.churchId),
        after = data.after ? id(data.after) : null;
      return store.transaction(church, async (tx) => {
        const member = await access(tx, auth);
        const items = await tx.prayers(
          auth.uid,
          member.role === "pastor",
          after,
          100,
        );
        tx.putAudit(store.newId(), {
          type: "PrayersRead",
          actorId: auth.uid,
          count: items.length,
          at: store.now(),
          schemaVersion: 1,
        });
        return {
          items,
          nextCursor: items.length === 100 ? items.at(-1).id : null,
        };
      });
    },
    async update(auth, data) {
      const church = id(data?.churchId),
        prayerId = id(data?.prayerId),
        requestId = id(data?.requestId);
      if (
        !["open", "in_progress", "closed"].includes(data.status) ||
        !Number.isInteger(data.expectedVersion) ||
        data.expectedVersion < 1
      )
        throw new Fault("invalid-argument", "Situação inválida.");
      const nextContactAt = data.nextContactAt ?? "";
      if (
        typeof nextContactAt !== "string" ||
        (nextContactAt &&
          (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(
            nextContactAt,
          ) ||
            !Number.isFinite(Date.parse(nextContactAt)) ||
            new Date(nextContactAt).toISOString() !== nextContactAt))
      )
        throw new Fault("invalid-argument", "Data de contato inválida.");
      if (data.status === "closed" && nextContactAt)
        throw new Fault(
          "invalid-argument",
          "Limpe o próximo contato ao encerrar.",
        );
      return store.transaction(church, async (tx) => {
        const member = await access(tx, auth);
        const current = await tx.record("prayers", prayerId);
        if (
          member.role !== "pastor" ||
          !current ||
          current.assignedTo !== auth.uid
        )
          deny();
        const key = hash(`prayer-update:${auth.uid}:${requestId}`),
          fingerprint = hash(
            JSON.stringify({
              prayerId,
              status: data.status,
              nextContactAt,
              expectedVersion: data.expectedVersion,
            }),
          );
        const receipt = await tx.receipt(key);
        if (receipt) {
          if (receipt.fingerprint !== fingerprint)
            throw new Fault("already-exists", "Operação reutilizada.");
          return receipt.result;
        }
        if (current.version !== data.expectedVersion)
          throw new Fault("aborted", "Pedido alterado. Atualize a lista.");
        const at = store.now(),
          record = {
            ...current,
            status: data.status,
            nextContactAt,
            version: current.version + 1,
            updatedAt: at,
          };
        tx.putRecord("prayers", prayerId, record);
        tx.putReceipt(key, { fingerprint, result: record });
        tx.putAudit(key, {
          type: "PrayerUpdated",
          actorId: auth.uid,
          entityId: prayerId,
          at,
          version: record.version,
          schemaVersion: 1,
        });
        return record;
      });
    },
  };
}
