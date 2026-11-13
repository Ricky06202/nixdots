#!/usr/bin/env bun
// Loopback-only OpenAI-compatible adapter for OpenHands -> Jan's llama.cpp
// router. Jan chooses a random localhost port and API key at every launch;
// this bridge discovers both from the live worker and keeps a stable endpoint.

import { readFile, readdir } from "node:fs/promises";

const HOST = "127.0.0.1";
const PORT = Number(process.env.JAN_BRIDGE_PORT ?? 14040);
const CLIENT_KEY = "jan-local"; // placeholder for the loopback-only endpoint
const PRESET = "/home/ricky/.local/share/Jan/data/llamacpp/router.preset.ini";
const MODEL_IDS = new Set(["twil-8b", "qwen3-vl-4b"]);

type Worker = { pid: string; port: number; key: string };

function log(message: string) {
  // Never log request bodies or either API key.
  console.error(`[jan-api-bridge] ${message}`);
}

async function findWorker(): Promise<Worker | null> {
  let entries: string[];
  try {
    entries = await readdir("/proc");
  } catch {
    return null;
  }

  const sockets = Bun.spawnSync(["ss", "-ltnp"], { stdout: "pipe", stderr: "ignore" })
    .stdout.toString();

  for (const pid of entries) {
    if (!/^\d+$/.test(pid)) continue;

    let cmdline: string;
    try {
      cmdline = (await readFile(`/proc/${pid}/cmdline`)).toString().replaceAll("\0", " ");
    } catch {
      continue;
    }
    if (!cmdline.includes("jan-llama-worker") || !cmdline.includes(PRESET)) continue;

    let key = "";
    try {
      const env = (await readFile(`/proc/${pid}/environ`)).toString().split("\0");
      key = env.find((item) => item.startsWith("JAN_LLAMA_API_KEY="))?.slice("JAN_LLAMA_API_KEY=".length) ?? "";
    } catch {
      continue;
    }
    if (!key) continue;

    const listenLine = sockets
      .split("\n")
      .find((line) => line.includes(`pid=${pid},`) && /127\.0\.0\.1:\d+/.test(line));
    const port = Number(listenLine?.match(/127\.0\.0\.1:(\d+)/)?.[1]);
    if (Number.isInteger(port) && port > 0) return { pid, port, key };
  }
  return null;
}

async function janFetch(worker: Worker, path: string, init: RequestInit = {}) {
  const headers = new Headers(init.headers);
  headers.set("authorization", `Bearer ${worker.key}`);
  return fetch(`http://127.0.0.1:${worker.port}${path}`, {
    ...init,
    headers,
  });
}

async function getModels(worker: Worker): Promise<any[]> {
  const response = await janFetch(worker, "/models", { signal: AbortSignal.timeout(5_000) });
  if (!response.ok) throw new Error(`Jan /models returned ${response.status}`);
  const body = await response.json() as { data?: any[] };
  return body.data ?? [];
}

let modelSwitch = Promise.resolve();

function ensureModelLoaded(worker: Worker, model: string): Promise<void> {
  const operation = modelSwitch.then(async () => {
    const models = await getModels(worker);
    const target = models.find((item) => item.id === model);
    if (!target) throw new Error(`Model ${model} is not configured in Jan`);
    if (target.status?.value === "loaded") return;

    // Jan's own API refuses to unload a model while its prompt-cache slots are
    // retained. Its router is configured for two models, so load the second
    // profile on demand and let Jan manage those two slots.
    const loaded = await janFetch(worker, "/models/load", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ model }),
      signal: AbortSignal.timeout(300_000),
    });
    if (!loaded.ok) throw new Error(`Could not load ${model}: ${loaded.status}`);
    const result = await loaded.json() as { status?: string };
    if (result.status !== "loaded") throw new Error(`Jan did not load ${model}`);
  });

  modelSwitch = operation.catch(() => undefined);
  return operation;
}

function json(status: number, body: unknown) {
  return Response.json(body, { status, headers: { "cache-control": "no-store" } });
}

Bun.serve({
  hostname: HOST,
  port: PORT,
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === "/health") return new Response("ok", { headers: { "cache-control": "no-store" } });

    if (request.headers.get("authorization") !== `Bearer ${CLIENT_KEY}`) {
      return json(401, { error: { message: "Invalid local model key" } });
    }

    if (url.pathname === "/v1/models" && request.method === "GET") {
      const worker = await findWorker();
      if (!worker) return json(503, { error: { message: "Jan is not running" } });
      try {
        const response = await janFetch(worker, "/v1/models", { signal: AbortSignal.timeout(5_000) });
        if (!response.ok) return json(response.status, { error: { message: "Jan model list failed" } });
        const body = await response.json() as { data?: any[]; [key: string]: unknown };
        body.data = (body.data ?? []).filter((item) => MODEL_IDS.has(item.id));
        return json(200, body);
      } catch (error) {
        log(`model list failed: ${String(error)}`);
        return json(503, { error: { message: "Jan is unavailable" } });
      }
    }

    if (url.pathname === "/v1/chat/completions" && request.method === "POST") {
      const worker = await findWorker();
      if (!worker) return json(503, { error: { message: "Jan is not running" } });

      let body: Record<string, any>;
      try {
        body = await request.json() as Record<string, any>;
      } catch {
        return json(400, { error: { message: "Invalid JSON request" } });
      }

      const model = String(body.model ?? "").replace(/^openai\//, "");
      if (!MODEL_IDS.has(model)) {
        return json(400, { error: { message: "Only twil-8b and qwen3-vl-4b are available" } });
      }

      try {
        await ensureModelLoaded(worker, model);
        body.model = model;
        const response = await janFetch(worker, "/v1/chat/completions", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify(body),
          signal: AbortSignal.timeout(900_000),
        });
        const headers = new Headers(response.headers);
        headers.set("cache-control", "no-store");
        return new Response(response.body, { status: response.status, headers });
      } catch (error) {
        log(`completion failed for ${model}: ${String(error)}`);
        return json(502, { error: { message: `Jan request failed for ${model}` } });
      }
    }

    return json(404, { error: { message: "Not found" } });
  },
});

log(`listening on http://${HOST}:${PORT}`);
