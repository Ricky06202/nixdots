#!/usr/bin/env bun
// Loopback-only OpenAI-compatible adapter for the phone PWA (jan-remoto).
//
// Antes descubría el puerto/clave aleatorios del worker de Jan y cargaba
// TwIL/Qwen a demanda. Desde 2026-11-16 el único modelo local es Spark-X2.6 4B,
// servido por llama-server en :8091 (`local-ai chat`), así que esto es un
// passthrough: mismo endpoint estable (:14040) para el celular, cero acople a
// Jan.

const HOST = "127.0.0.1";
const PORT = Number(process.env.JAN_BRIDGE_PORT ?? 14040);
const CLIENT_KEY = "jan-local"; // placeholder para un endpoint solo-loopback
const UPSTREAM = process.env.SPARK_URL ?? "http://127.0.0.1:8091/v1";
const MODEL_ID = "spark-4b";

function log(message: string) {
  // Nunca loguear cuerpos de request ni claves.
  console.error(`[jan-api-bridge] ${message}`);
}

function json(status: number, body: unknown) {
  return Response.json(body, { status, headers: { "cache-control": "no-store" } });
}

Bun.serve({
  hostname: HOST,
  port: PORT,
  async fetch(request) {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return new Response("ok", { headers: { "cache-control": "no-store" } });
    }

    if (request.headers.get("authorization") !== `Bearer ${CLIENT_KEY}`) {
      return json(401, { error: { message: "Invalid local model key" } });
    }

    if (url.pathname === "/v1/models" && request.method === "GET") {
      try {
        const response = await fetch(`${UPSTREAM}/models`, {
          signal: AbortSignal.timeout(5_000),
        });
        if (!response.ok) {
          return json(response.status, { error: { message: "Spark model list failed" } });
        }
        const body = (await response.json()) as { data?: any[]; [key: string]: unknown };
        body.data = (body.data ?? []).filter((item) => item.id === MODEL_ID);
        return json(200, body);
      } catch (error) {
        log(`model list failed: ${String(error)}`);
        return json(503, {
          error: { message: "Spark no esta corriendo. Ejecuta 'local-ai chat' en el PC." },
        });
      }
    }

    if (url.pathname === "/v1/chat/completions" && request.method === "POST") {
      let body: Record<string, any>;
      try {
        body = (await request.json()) as Record<string, any>;
      } catch {
        return json(400, { error: { message: "Invalid JSON request" } });
      }

      // El server sirve el GGUF que tenga cargado; el id es informativo.
      body.model = MODEL_ID;

      // Chat de celular: sin bloque de razonamiento. Spark piensa por defecto y
      // se come los max_tokens antes de responder (respuesta vacía). Si algún
      // cliente quiere razonar, que lo pida explícito.
      if (!body.chat_template_kwargs) {
        body.chat_template_kwargs = { enable_thinking: false };
      }

      try {
        const response = await fetch(`${UPSTREAM}/chat/completions`, {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify(body),
          signal: AbortSignal.timeout(900_000),
        });
        const headers = new Headers(response.headers);
        headers.set("cache-control", "no-store");
        return new Response(response.body, { status: response.status, headers });
      } catch (error) {
        log(`completion failed: ${String(error)}`);
        return json(502, { error: { message: "Spark request failed" } });
      }
    }

    return json(404, { error: { message: "Not found" } });
  },
});

log(`listening on http://${HOST}:${PORT} -> ${UPSTREAM}`);
