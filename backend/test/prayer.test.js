import { test } from "node:test";
import assert from "node:assert/strict";
import { prayerService } from "../src/prayer_service.js";
function fixture() {
  let state = {
    users: {
      member: { active: true, role: "member" },
      other: { active: true, role: "member" },
      pastor: { active: true, role: "pastor" },
      pastor2: { active: true, role: "pastor" },
      secretary: { active: true, role: "secretary" },
      admin: { active: true, role: "admin" },
      consultant: { active: true, role: "consultant" },
    },
    prayers: {},
    operations: {},
    audit: {},
  };
  let count = 0;
  const api = prayerService({
    now: () => "2026-10-06T23:00:00.000Z",
    newId: () => `a${++count}`,
    transaction: async (church, fn) => {
      const d = structuredClone(state);
      const result = await fn({
        membership: async (uid) => (church === "church" ? d.users[uid] : null),
        church: async () => ({ intakePastorUid: "pastor" }),
        receipt: async (id) => d.operations[id],
        record: async (c, id) => d[c][id],
        prayers: async (uid, isPastor, after, limit) =>
          Object.values(d.prayers)
            .filter(
              (p) => p.authorId === uid || (isPastor && p.assignedTo === uid),
            )
            .sort((a, b) => a.id.localeCompare(b.id))
            .filter((p) => !after || p.id > after)
            .slice(0, limit),
        putRecord: (c, id, p) => {
          d[c][id] = p;
        },
        putReceipt: (id, p) => {
          d.operations[id] = p;
        },
        putAudit: (id, p) => {
          d.audit[id] = p;
        },
      });
      state = d;
      return result;
    },
  });
  return { api, state: () => state };
}
const auth = (uid) => ({ uid, email_verified: true });
const input = {
  churchId: "church",
  prayerId: "p1",
  requestId: "r1",
  subject: "Pedido reservado",
  body: "Texto confidencial de teste",
};
test("pedido encaminhado ao pastor configurado, sem conteúdo no log", async () => {
  const f = fixture();
  const p = await f.api.submit(auth("member"), input);
  assert.equal(p.assignedTo, "pastor");
  assert.equal(p.authorId, "member");
  assert.ok(!JSON.stringify(f.state().audit).includes(input.body));
});
test("autor e pastor designado veem; outro membro e pastor não veem", async () => {
  const f = fixture();
  await f.api.submit(auth("member"), input);
  for (const [uid, count] of [
    ["member", 1],
    ["pastor", 1],
    ["other", 0],
    ["pastor2", 0],
  ])
    assert.equal(
      (await f.api.list(auth(uid), { churchId: "church" })).items.length,
      count,
    );
});
for (const role of ["admin", "secretary", "consultant"])
  test(`sigilo nega ${role}`, async () => {
    const f = fixture();
    await assert.rejects(f.api.list(auth(role), { churchId: "church" }), {
      code: "permission-denied",
    });
  });
test("somente pastor atribuído altera acompanhamento", async () => {
  const f = fixture();
  await f.api.submit(auth("member"), input);
  const data = {
    churchId: "church",
    prayerId: "p1",
    requestId: "u1",
    expectedVersion: 1,
    status: "in_progress",
    nextContactAt: "2026-10-07T12:00:00.000Z",
  };
  for (const uid of ["member", "pastor2"])
    await assert.rejects(f.api.update(auth(uid), data), {
      code: "permission-denied",
    });
  assert.equal((await f.api.update(auth("pastor"), data)).version, 2);
  await assert.rejects(
    f.api.update(auth("pastor"), { ...data, requestId: "u2" }),
    { code: "aborted" },
  );
});
test("idempotência e revogação também se aplicam ao pedido", async () => {
  const f = fixture();
  assert.deepEqual(
    await f.api.submit(auth("member"), input),
    await f.api.submit(auth("member"), input),
  );
  f.state().users.member.active = false;
  await assert.rejects(f.api.submit(auth("member"), input), {
    code: "permission-denied",
  });
});
test("encerramento limpa próximo contato", async () => {
  const f = fixture();
  await f.api.submit(auth("member"), input);
  await assert.rejects(
    f.api.update(auth("pastor"), {
      churchId: "church",
      prayerId: "p1",
      requestId: "u1",
      expectedVersion: 1,
      status: "closed",
      nextContactAt: "2026-10-07T12:00:00.000Z",
    }),
    { code: "invalid-argument" },
  );
});

test("cliente não escolhe autor ou destinatário arbitrário", async () => {
  const f = fixture();
  const p = await f.api.submit(auth("member"), {
    ...input,
    authorId: "other",
    assignedTo: "pastor2",
  });
  assert.equal(p.authorId, "member");
  assert.equal(p.assignedTo, "pastor");
});
