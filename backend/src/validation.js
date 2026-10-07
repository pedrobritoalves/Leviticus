import { Fault } from "./errors.js";
const invalid = (message) => {
  throw new Fault("invalid-argument", message);
};
export function identifier(value) {
  if (typeof value !== "string" || !/^[a-zA-Z0-9_-]{1,100}$/.test(value))
    invalid("Identificador inválido.");
  return value;
}
function object(value, fields) {
  if (
    !value ||
    typeof value !== "object" ||
    Array.isArray(value) ||
    Object.keys(value).some((k) => !fields.includes(k))
  )
    invalid("Campos não permitidos.");
}
function text(value, max, label, required = false) {
  if (value == null) value = "";
  if (
    typeof value !== "string" ||
    value.length > max ||
    /[\x00-\x1f]/.test(value)
  )
    invalid(`${label} inválido.`);
  value = value.trim();
  if (required && value.length < 2) invalid(`Informe ${label}.`);
  return value;
}
function date(value, label) {
  value = text(value, 10, label);
  if (
    value &&
    (!/^\d{4}-\d{2}-\d{2}$/.test(value) ||
      !Number.isFinite(Date.parse(value)) ||
      new Date(value).toISOString().slice(0, 10) !== value)
  )
    invalid(`${label} inválida.`);
  return value;
}
export function person(input) {
  object(input, [
    "name",
    "preferredName",
    "email",
    "phone",
    "status",
    "birthDate",
    "admissionDate",
    "baptismDate",
    "congregation",
    "address",
  ]);
  const result = {
    name: text(input.name, 120, "nome", true),
    preferredName: text(input.preferredName, 80, "nome preferido"),
    email: text(input.email, 254, "e-mail").toLowerCase(),
    phone: text(input.phone, 30, "telefone"),
    status: input.status,
    birthDate: date(input.birthDate, "Data de nascimento"),
    admissionDate: date(input.admissionDate, "Data de admissão"),
    baptismDate: date(input.baptismDate, "Data de batismo"),
    congregation: text(input.congregation, 120, "congregação"),
  };
  if (!["visitor", "member"].includes(result.status))
    invalid("Vínculo inválido.");
  if (result.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(result.email))
    invalid("E-mail inválido.");
  if (result.phone && !/^[+\d ()-]{7,30}$/.test(result.phone))
    invalid("Telefone inválido.");
  const address = input.address ?? {};
  object(address, [
    "postalCode",
    "street",
    "number",
    "complement",
    "district",
    "city",
    "state",
    "country",
  ]);
  result.address = Object.fromEntries(
    [
      "postalCode",
      "street",
      "number",
      "complement",
      "district",
      "city",
      "state",
      "country",
    ].map((k) => [k, text(address[k], k === "street" ? 180 : 80, k)]),
  );
  if (
    result.birthDate &&
    result.birthDate > new Date().toISOString().slice(0, 10)
  )
    invalid("Nascimento não pode estar no futuro.");
  for (const key of ["admissionDate", "baptismDate"])
    if (result[key] && result.birthDate && result[key] < result.birthDate)
      invalid("Data eclesiástica anterior ao nascimento.");
  return result;
}
export function ministry(input) {
  object(input, ["name", "description", "leaderId", "memberIds", "active"]);
  if (typeof input.active !== "boolean")
    invalid("Situação do ministério inválida.");
  if (!Array.isArray(input.memberIds) || input.memberIds.length > 200)
    invalid("Informe até 200 participantes.");
  const memberIds = [...new Set(input.memberIds.map(identifier))];
  const leaderId = input.leaderId ? identifier(input.leaderId) : "";
  if (leaderId && !memberIds.includes(leaderId))
    invalid("O responsável deve participar do ministério.");
  return {
    name: text(input.name, 120, "nome", true),
    description: text(input.description, 500, "descrição"),
    leaderId,
    memberIds,
    active: input.active,
  };
}
