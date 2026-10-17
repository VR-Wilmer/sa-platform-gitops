// Practica 10: generador de trafico de usuarios (k6). Ver
// templates/generador-trafico.yaml para el porque.
import http from "k6/http";
import { check, sleep } from "k6";

const BASE = __ENV.BASE_URL;
const PAUSA = Number(__ENV.PAUSA_SEGUNDOS || 1);
const JSON_H = { "Content-Type": "application/json" };
const CATEGORIAS = ["SOFTWARE", "HARDWARE", "RED", "CUENTA"];
const RELOGIN_MS = 10 * 60 * 1000; // el JWT dura 30 min (JWT_EXPIRES_IN)

export const options = {
  vus: Number(__ENV.USUARIOS || 3),
  duration: "8760h",
  summaryTrendStats: [],
  discardResponseBodies: false,
};

function login(correo, contrasena) {
  const r = http.post(`${BASE}/api/identidad/login`, JSON.stringify({ correo, contrasena }),
    { headers: JSON_H, tags: { op: "login" } });
  return r.status === 200 ? r.json("token") : null;
}

function gql(path, token, query, variables, op) {
  return http.post(`${BASE}${path}`, JSON.stringify({ query, variables }), {
    headers: Object.assign({ Authorization: `Bearer ${token}` }, JSON_H),
    tags: { op },
  });
}

export function setup() {
  const correo = `cliente-${Date.now()}@trafico.local`;
  const contrasena = "Trafico-" + Math.random().toString(36).slice(2, 12);
  http.post(`${BASE}/api/identidad/registro`,
    JSON.stringify({ nombre: "Cliente simulado", correo, contrasena }), { headers: JSON_H });
  return { correo, contrasena };
}

// Estado por usuario virtual (cada VU tiene su propia copia del modulo).
let tokenCliente = null;
let tokenAgente = null;
let ultimoLogin = 0;

export default function (cred) {
  if (!tokenCliente || !tokenAgente || Date.now() - ultimoLogin > RELOGIN_MS) {
    tokenCliente = login(cred.correo, cred.contrasena);
    tokenAgente = login(__ENV.AGENTE1_EMAIL, __ENV.AGENTE1_PASSWORD);
    ultimoLogin = Date.now();
    if (!tokenCliente || !tokenAgente) { sleep(5); return; }
  }

  const categoria = CATEGORIAS[Math.floor(Math.random() * CATEGORIAS.length)];
  const creado = gql("/api/tickets", tokenCliente,
    "mutation($t:String!,$d:String!,$c:CategoriaTicket!){crearTicket(titulo:$t,descripcion:$d,categoria:$c){id estado}}",
    { t: "No funciona " + categoria.toLowerCase(), d: "Ticket generado por el trafico simulado", c: categoria },
    "crearTicket");
  if (creado.status === 401) { tokenCliente = null; return; }
  check(creado, { "ticket creado": (r) => r.status === 200 && !r.json("errors") });
  const id = creado.status === 200 ? creado.json("data.crearTicket.id") : null;

  gql("/api/tickets", tokenCliente, "{tickets{id estado}}", {}, "listarTickets");

  if (id) {
    if (Math.random() < 0.3) {
      gql("/api/tickets", tokenAgente,
        "mutation($id:ID!){actualizarEstadoTicket(id:$id,nuevoEstado:RESUELTO){id estado}}",
        { id }, "resolverTicket");
    }
    gql("/api/notificaciones", tokenAgente,
      "query($id:ID!){historialNotificaciones(ticketId:$id){id tipo estadoEnvio}}",
      { id }, "historialNotificaciones");
  }

  if (Math.random() < 0.05) {
    login(cred.correo, "contrasena-equivocada");
  }

  sleep(PAUSA);
}
