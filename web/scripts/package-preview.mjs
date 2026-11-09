#!/usr/bin/env node
/**
 * Assemble a Pages upload tree:
 *   <out>/index.html          — SPA shell (same as /hostkit-preview/) so unknown paths still boot the app
 *   <out>/_headers
 *   <out>/_redirects
 *   <out>/robots.txt
 *   <out>/hostkit-preview/**  — vite dist (basename /hostkit-preview/)
 */
import { cpSync, mkdirSync, writeFileSync, rmSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const webRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const dist = join(webRoot, "dist");
const out = process.argv[2] || join(webRoot, "..", "..", "hostkit-preview-upload");

if (!existsSync(join(dist, "index.html"))) {
  throw new Error("web/dist is missing — run npm run build first");
}

mkdirSync(out, { recursive: true });
const destPreview = join(out, "hostkit-preview");
rmSync(destPreview, { recursive: true, force: true });
mkdirSync(destPreview, { recursive: true });
cpSync(dist, destPreview, { recursive: true });

const headers = "/*\n  X-Robots-Tag: noindex, nofollow\n";
const robots = "User-agent: *\nDisallow: /\n";
const redirects = `# SPA fallback for deep links and refresh.
# Existing static assets are served first; this rewrite only applies on miss.
/hostkit-preview/*  /hostkit-preview/index.html  200
/*                  /hostkit-preview/index.html  200
`;
// Root index.html is the same SPA shell (absolute asset URLs under
// /hostkit-preview/). Direct-upload Pages may serve this file for
// unknown paths, including /hostkit-preview/pair/:code.
writeFileSync(join(out, "_headers"), headers);
writeFileSync(join(out, "_redirects"), redirects);
writeFileSync(join(out, "robots.txt"), robots);
cpSync(join(dist, "index.html"), join(out, "index.html"));
writeFileSync(join(destPreview, "_headers"), headers);
writeFileSync(join(destPreview, "robots.txt"), robots);

console.log(`packed preview upload at ${out}`);
