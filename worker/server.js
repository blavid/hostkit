#!/usr/bin/env node
/**
 * Tiny local wrapper so the Roku emulator can hit the Worker without Wrangler
 * or any Cloudflare call. Same fetch() handler, in-memory KV, seeded with
 * schema/eaglewood.customer0.json.
 *
 *   PORT=8787 node server.js
 */
import { createServer } from "node:http";
import { readFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import worker, { MemoryKV, ensureDefaultConfig } from "./src/index.js";

const here = dirname(fileURLToPath(import.meta.url));
const fixturePath = join(here, "..", "schema", "eaglewood.customer0.json");
if (!existsSync(fixturePath)) {
  console.error("missing schema/eaglewood.customer0.json");
  process.exit(1);
}

const port = Number(process.env.PORT || 8787);
const publicBase = (process.env.PUBLIC_BASE || `http://127.0.0.1:${port}`).replace(/\/+$/, "");
const env = {
  KV: new MemoryKV(),
  HOST_TOKEN: process.env.HOST_TOKEN || "host-preview",
  PUBLIC_BASE: publicBase,
  ALLOW_TEST_HOOKS: process.env.ALLOW_TEST_HOOKS || "1",
  DEFAULT_CONFIG: readFileSync(fixturePath, "utf8"),
};

await ensureDefaultConfig(env);

const server = createServer((req, res) => {
  const chunks = [];
  req.on("data", (c) => chunks.push(c));
  req.on("end", async () => {
    try {
      const url = `http://${req.headers.host || `127.0.0.1:${port}`}${req.url}`;
      const method = req.method || "GET";
      const headers = new Headers();
      for (const [key, value] of Object.entries(req.headers)) {
        if (value == null) continue;
        headers.set(key, Array.isArray(value) ? value.join(", ") : String(value));
      }
      const body = ["GET", "HEAD"].includes(method) ? undefined : Buffer.concat(chunks);
      const request = new Request(url, { method, headers, body });
      const response = await worker.fetch(request, env);
      res.statusCode = response.status;
      response.headers.forEach((value, key) => {
        res.setHeader(key, value);
      });
      const buf = Buffer.from(await response.arrayBuffer());
      res.end(buf);
    } catch (err) {
      res.statusCode = 500;
      res.setHeader("content-type", "application/json");
      res.end(JSON.stringify({ error: "wrapper", message: String(err && err.message ? err.message : err) }));
    }
  });
});

server.listen(port, "127.0.0.1", () => {
  console.log(`hostkit worker local ${publicBase}`);
});
