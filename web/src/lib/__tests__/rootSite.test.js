import test from "node:test";
import assert from "node:assert/strict";
import vm from "node:vm";
import { readFileSync, readdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const web = join(dirname(fileURLToPath(import.meta.url)), "../../..");
const read = (p) => readFileSync(join(web, p), "utf8");

// Run the sales home's inline fallback script against a fake location.
function fallback(pathname, search = "", hash = "") {
  const html = read("sales-site/index.html");
  const js = html.match(/<script>([\s\S]*?)<\/script>/)[1];
  const calls = [];
  const location = { pathname, search, hash, replace: (u) => calls.push(u) };
  vm.runInNewContext(js, { location });
  return calls[0] ?? null;
}

test("the build serves at the root", () => {
  assert.match(read("vite.config.js"), /base: "\/",/);
  assert.ok(!read("src/main.jsx").includes('basename="/hostkit-preview"'));
});

test("hostkit-config.json points at api.host-kit.com", () => {
  assert.deepEqual(JSON.parse(read("public/hostkit-config.json")), { apiBase: "https://api.host-kit.com" });
});

test("_redirects moves /hostkit-preview/* to the root and keeps SPA deep links", () => {
  const rules = read("public/_redirects")
    .split("\n")
    .filter((l) => l.trim() && !l.startsWith("#"))
    .map((l) => l.trim().split(/\s+/));
  assert.deepEqual(rules, [
    ["/hostkit-preview", "/", "301"],
    ["/hostkit-preview/*", "/:splat", "301"],
    ["/pair/*", "/pair/", "200"],
    ["/wizard/*", "/wizard/", "200"],
    ["/setup/*", "/setup/", "200"],
  ]);
});

test("noindex header and robots.txt stay in place", () => {
  assert.match(read("public/_headers"), /^\/\*\n\s+X-Robots-Tag: noindex, nofollow/m);
  assert.equal(read("public/robots.txt"), "User-agent: *\nDisallow: /\n");
});

test("home page fallback forwards old links and pair codes, keeping the query", () => {
  assert.equal(fallback("/"), null);
  assert.equal(fallback("/hostkit-preview/", "?code=ABC234"), "/?code=ABC234");
  assert.equal(fallback("/hostkit-preview"), "/");
  assert.equal(fallback("/hostkit-preview/wizard/", "?code=ABC234", "#x"), "/wizard/?code=ABC234#x");
  assert.equal(fallback("/hostkit-preview/signup", "?code=ABC234"), "/signup?code=ABC234");
  assert.equal(fallback("/hostkit-preview/pair/abc234"), "/pair/abc234");
  assert.equal(fallback("/pair/abc234"), "/wizard/?code=ABC234");
  assert.equal(fallback("/nope", "?code=ABC234"), "/?code=ABC234");
});

test("no .example placeholder or preview URL is left in the site or wizard", () => {
  const files = [
    ...readdirSync(join(web, "sales-site")).filter((f) => f.endsWith(".html")).map((f) => `sales-site/${f}`),
    "sales-site/assets/site.js",
    "sales-site/assets/trial.js",
    "src/main.jsx",
    "src/WizardPage.jsx",
  ];
  for (const f of files) {
    const text = read(f);
    assert.ok(!/hostkit\.example|hostkit-preview\.pages\.dev|workers\.dev/.test(text), f);
  }
});
