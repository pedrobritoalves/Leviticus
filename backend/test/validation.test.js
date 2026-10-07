import { test } from "node:test";
import assert from "node:assert/strict";
import { person, ministry } from "../src/validation.js";
test("endereço não aceita campos inesperados", () =>
  assert.throws(
    () =>
      person({
        name: "Pessoa",
        status: "member",
        address: { counseling: "confidential" },
      }),
    { code: "invalid-argument" },
  ));
test("datas eclesiásticas não podem anteceder nascimento", () =>
  assert.throws(
    () =>
      person({
        name: "Pessoa",
        status: "member",
        birthDate: "2000-01-01",
        baptismDate: "1990-01-01",
      }),
    { code: "invalid-argument" },
  ));
test("participantes duplicados são normalizados", () =>
  assert.deepEqual(
    ministry({
      name: "Equipe",
      description: "",
      active: true,
      leaderId: "a",
      memberIds: ["a", "a"],
    }).memberIds,
    ["a"],
  ));
test("lista de participantes possui limite explícito", () =>
  assert.throws(
    () =>
      ministry({
        name: "Equipe",
        active: true,
        memberIds: Array.from({ length: 201 }, (_, i) => `p${i}`),
      }),
    { code: "invalid-argument" },
  ));
