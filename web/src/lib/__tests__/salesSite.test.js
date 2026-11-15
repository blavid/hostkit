import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const site = join(dirname(fileURLToPath(import.meta.url)), "../../../sales-site");
const pages = readdirSync(site).filter((f) => f.endsWith(".html"));

test("sales site has every page, including signup", () => {
  for (const p of ["index.html", "guest-experience.html", "tour.html", "features.html", "pricing.html", "faq.html", "signup.html"]) {
    assert.ok(pages.includes(p), p);
  }
});

test("every page is noindex and shows the noindex-safe price wording only", () => {
  for (const p of pages) {
    const html = readFileSync(join(site, p), "utf8");
    assert.match(html, /<meta name="robots" content="noindex,nofollow">/, p);
    assert.ok(html.includes("30-day free trial, then $5/mo per property"), p);
    assert.ok(!/annual|monthly/i.test(html), `${p} mentions another plan`);
    assert.ok(html.includes("Hidden preview · noindex"), `${p} lacks the visible noindex note`);
    assert.match(html, /<footer[\s\S]*Hidden preview · noindex[\s\S]*<\/footer>/, `${p} noindex note is not in the footer`);
    assert.ok(!/<header[\s\S]*Hidden preview · noindex[\s\S]*<\/header>/.test(html), `${p} noindex note is in the header`);
  }
});

test("CTAs stay relative and no third-party fonts load", () => {
  for (const p of pages) {
    const html = readFileSync(join(site, p), "utf8");
    assert.ok(!html.includes('href="/signup'), `${p} has a root /signup link`);
    assert.ok(!/fonts\.(googleapis|gstatic)\.com/.test(html), p);
  }
  const css = readFileSync(join(site, "assets/site.css"), "utf8");
  assert.ok(!/fonts\.(googleapis|gstatic)\.com|@import/.test(css));
  for (const f of ["fraunces-latin-wght-normal.woff2", "inter-latin-wght-normal.woff2", "dm-mono-latin-500-normal.woff2", "OFL-Fraunces.txt", "OFL-Inter.txt", "OFL-DM-Mono.txt"]) {
    assert.ok(existsSync(join(site, "assets/fonts", f)), f);
  }
  const js = readFileSync(join(site, "assets/site.js"), "utf8");
  assert.ok(js.includes("'signup?code='"));
});

test("wizard step 1 and marketing copy offer only the single plan", () => {
  const src = join(dirname(fileURLToPath(import.meta.url)), "../..");
  for (const f of ["WizardPage.jsx", "MarketingPage.jsx"]) {
    const text = readFileSync(join(src, f), "utf8");
    assert.ok(!/annual|Subscribe monthly|pick monthly/i.test(text), `${f} still offers a plan choice`);
  }
});
