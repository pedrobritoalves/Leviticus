import { test } from "node:test";
import assert from "node:assert/strict";
import { service, ministriesService, eventsService } from "../src/service.js";
function fixture() {
  let state = {
    alpha: {
      users: {
        u: { active: true, role: "admin" },
        c: { active: true, role: "consultant" },
        s: { active: true, role: "secretary" },
      },
      people: {},
      ministries: {},
      events: {},
      operations: {},
      audit: {},
    },
    beta: {
      users: {},
      people: {},
      ministries: {},
      events: {},
      operations: {},
      audit: {},
    },
  };
  let n = 0;
  const store = {
    now: () => "2026-10-06T18:32:00Z",
    newId: () => `event${++n}`,
    transaction: async (church, fn) => {
      const draft = structuredClone(
        state[church] ?? {
          users: {},
          people: {},
          ministries: {},
          events: {},
          operations: {},
          audit: {},
        },
      );
      const result = await fn({
        membership: async (uid) => draft.users[uid],
        receipt: async (k) => draft.operations[k],
        record: async (c, k) => draft[c][k],
        records: async (c, after, limit) =>
          Object.values(draft[c])
            .sort((a, b) => a.id.localeCompare(b.id))
            .filter((p) => !after || p.id > after)
            .slice(0, limit),
        putRecord: (c, k, v) => {
          draft[c][k] = v;
        },
        putAudit: (k, v) => {
          draft.audit[k] = v;
        },
        putReceipt: (k, v) => {
          draft.operations[k] = v;
        },
      });
      state[church] = draft;
      return result;
    },
  };
  return {
    api: service(store),
    ministries: ministriesService(store),
    events: eventsService(store),
    state: () => state,
  };
}
const user = { uid: "u", email_verified: true };
const input = {
  churchId: "alpha",
  personId: "p1",
  requestId: "op1",
  expectedVersion: 0,
  person: {
    name: "Pessoa de Teste",
    email: "TESTE@example.com",
    phone: "",
    status: "visitor",
  },
};
test("criação grava pessoa, evento sem dados pessoais e recibo", async () => {
  const f = fixture();
  const p = await f.api.save(user, input);
  assert.equal(p.version, 1);
  assert.equal(p.email, "teste@example.com");
  assert.equal(Object.keys(f.state().alpha.audit).length, 1);
  assert.equal(
    JSON.stringify(f.state().alpha.audit).includes("Pessoa de Teste"),
    false,
  );
});
test("reenvio idempotente não duplica evento", async () => {
  const f = fixture();
  assert.deepEqual(
    await f.api.save(user, input),
    await f.api.save(user, input),
  );
  assert.equal(Object.keys(f.state().alpha.audit).length, 1);
});
test("mesma chave com payload diferente é rejeitada", async () => {
  const f = fixture();
  await f.api.save(user, input);
  await assert.rejects(
    f.api.save(user, {
      ...input,
      person: { ...input.person, name: "Outro Nome" },
    }),
    { code: "already-exists" },
  );
});
test("atualização preserva criação e incrementa versão", async () => {
  const f = fixture();
  const a = await f.api.save(user, input);
  const b = await f.api.save(user, {
    ...input,
    requestId: "op2",
    expectedVersion: 1,
    person: { ...input.person, status: "member" },
  });
  assert.equal(b.version, 2);
  assert.equal(a.createdAt, b.createdAt);
});
test("versão antiga não sobrescreve nem deixa auditoria parcial", async () => {
  const f = fixture();
  await f.api.save(user, input);
  await assert.rejects(f.api.save(user, { ...input, requestId: "op2" }), {
    code: "aborted",
  });
  assert.equal(Object.keys(f.state().alpha.audit).length, 1);
});
for (const [name, auth, change, code] of [
  ["sem login", null, {}, "unauthenticated"],
  ["email não confirmado", { uid: "u" }, {}, "permission-denied"],
  ["outra igreja", user, { churchId: "beta" }, "permission-denied"],
  ["consultoria", { uid: "c", email_verified: true }, {}, "permission-denied"],
  ["path injection", user, { churchId: "alpha/people" }, "invalid-argument"],
  [
    "campo pastoral indevido",
    user,
    { person: { ...input.person, counseling: "segredo" } },
    "invalid-argument",
  ],
  [
    "nome vazio",
    user,
    { person: { ...input.person, name: " " } },
    "invalid-argument",
  ],
]) {
  test(`nega ${name}`, async () => {
    const f = fixture();
    await assert.rejects(f.api.save(auth, { ...input, ...change }), { code });
    assert.equal(Object.keys(f.state().alpha.people).length, 0);
  });
}
test("revogação bloqueia leitura e reenvio de operação", async () => {
  const f = fixture();
  await f.api.save(user, input);
  f.state().alpha.users.u.active = false;
  await assert.rejects(f.api.save(user, input), { code: "permission-denied" });
  await assert.rejects(f.api.list(user, { churchId: "alpha" }), {
    code: "permission-denied",
  });
});
test("listagem é restrita à igreja e auditada", async () => {
  const f = fixture();
  await f.api.save(user, input);
  const list = await f.api.list(user, { churchId: "alpha" });
  assert.equal(list.items.length, 1);
  assert.equal(list.nextCursor, null);
  await assert.rejects(f.api.list(user, { churchId: "beta" }), {
    code: "permission-denied",
  });
});
test("secretaria pode cadastrar", async () => {
  const f = fixture();
  assert.equal(
    (await f.api.save({ uid: "s", email_verified: true }, input)).version,
    1,
  );
});

const ministryInput = {
  churchId: "alpha",
  ministryId: "m1",
  requestId: "min1",
  expectedVersion: 0,
  ministry: {
    name: "Recepção",
    description: "",
    leaderId: "p1",
    memberIds: ["p1"],
    active: true,
  },
};
test("ministério vincula membro da mesma igreja", async () => {
  const f = fixture();
  await f.api.save(user, input);
  const m = await f.ministries.save(user, ministryInput);
  assert.equal(m.leaderId, "p1");
  assert.equal(m.version, 1);
});
test("ministério não aceita pessoa inexistente ou de outra igreja", async () => {
  const f = fixture();
  await assert.rejects(f.ministries.save(user, ministryInput), {
    code: "failed-precondition",
  });
  assert.equal(Object.keys(f.state().alpha.ministries).length, 0);
});
test("liderança deve pertencer à equipe", async () => {
  const f = fixture();
  await assert.rejects(
    f.ministries.save(user, {
      ...ministryInput,
      ministry: { ...ministryInput.ministry, memberIds: [] },
    }),
    { code: "invalid-argument" },
  );
});
test("datas inválidas e nascimento futuro são rejeitados", async () => {
  const f = fixture();
  for (const birthDate of ["2025-02-30", "2999-01-01", "foo"])
    await assert.rejects(
      f.api.save(user, { ...input, person: { ...input.person, birthDate } }),
      { code: "invalid-argument" },
    );
});
test("cadastro expandido persiste endereço e dados eclesiásticos", async () => {
  const f = fixture();
  const p = await f.api.save(user, {
    ...input,
    person: {
      ...input.person,
      birthDate: "1990-02-01",
      baptismDate: "2010-05-09",
      address: { city: "São Paulo", state: "SP" },
    },
  });
  assert.equal(p.address.city, "São Paulo");
  assert.equal(p.birthDate, "1990-02-01");
});

const eventInput = {
  churchId: "alpha",
  eventId: "event1",
  requestId: "event-create",
  expectedVersion: 0,
  event: {
    title: "Reunião de equipe",
    location: "Sala 1",
    startsAt: "2026-10-13T18:00:00Z",
    endsAt: "2026-10-13T19:00:00Z",
    organizerId: "",
    status: "scheduled",
  },
};
test("agenda cria, lista e cancela preservando histórico e idempotência", async () => {
  const f = fixture();
  const first = await f.events.save(user, eventInput);
  assert.equal(first.startsAt, "2026-10-13T18:00:00.000Z");
  assert.deepEqual(await f.events.save(user, eventInput), first);
  assert.equal(Object.keys(f.state().alpha.audit).length, 1);
  const cancelled = await f.events.save(user, {
    ...eventInput,
    requestId: "cancel",
    expectedVersion: 1,
    event: { ...eventInput.event, status: "cancelled" },
  });
  assert.equal(cancelled.version, 2);
  assert.equal(cancelled.createdAt, first.createdAt);
  assert.equal(
    (await f.events.list(user, { churchId: "alpha" })).items[0].status,
    "cancelled",
  );
  assert.equal(
    JSON.stringify(f.state().alpha.audit).includes("Reunião"),
    false,
  );
});
test("agenda rejeita data inexistente, ausência de fuso, intervalo invertido e campo privado", async () => {
  const f = fixture();
  for (const delta of [
    { startsAt: "2026-02-30T18:00:00Z" },
    { startsAt: "2026-10-13T18:00:00" },
    { endsAt: eventInput.event.startsAt },
    { status: "unknown" },
    { counseling: "reservado" },
  ])
    await assert.rejects(
      f.events.save(user, {
        ...eventInput,
        event: { ...eventInput.event, ...delta },
      }),
      { code: "invalid-argument" },
    );
  assert.equal(Object.keys(f.state().alpha.events).length, 0);
});
test("agenda impede responsável de outra igreja e aceita pessoa local", async () => {
  const f = fixture();
  const request = {
    ...eventInput,
    event: { ...eventInput.event, organizerId: "p1" },
  };
  await assert.rejects(f.events.save(user, request), {
    code: "failed-precondition",
  });
  await f.api.save(user, input);
  assert.equal((await f.events.save(user, request)).organizerId, "p1");
});
test("agenda nega outra igreja, membro, consultoria e vínculo revogado", async () => {
  const f = fixture();
  f.state().alpha.users.member = { active: true, role: "member" };
  for (const uid of ["member", "c"]) {
    const auth = { uid, email_verified: true };
    await assert.rejects(f.events.save(auth, eventInput), {
      code: "permission-denied",
    });
    await assert.rejects(f.events.list(auth, { churchId: "alpha" }), {
      code: "permission-denied",
    });
  }
  await assert.rejects(f.events.list(user, { churchId: "beta" }), {
    code: "permission-denied",
  });
  await f.events.save(user, eventInput);
  f.state().alpha.users.u.active = false;
  await assert.rejects(f.events.save(user, eventInput), {
    code: "permission-denied",
  });
});
test("agenda detecta conflito de edição e reutilização indevida de operação", async () => {
  const f = fixture();
  await f.events.save(user, eventInput);
  await assert.rejects(
    f.events.save(user, { ...eventInput, requestId: "edit-stale" }),
    { code: "aborted" },
  );
  await assert.rejects(
    f.events.save(user, {
      ...eventInput,
      event: { ...eventInput.event, title: "Outro título" },
    }),
    { code: "already-exists" },
  );
  assert.equal(f.state().alpha.events.event1.version, 1);
});
