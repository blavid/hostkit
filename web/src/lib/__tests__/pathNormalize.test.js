import assert from "node:assert/strict";
import { test } from "node:test";
import {
  normalizePreviewPathname,
  applyPreviewPathNormalization,
  legacyPreviewPath,
} from "../pathNormalize.js";

test("strips trailing slash and index.html", () => {
  assert.equal(normalizePreviewPathname("/wizard/"), "/wizard");
  assert.equal(normalizePreviewPathname("/wizard/index.html"), "/wizard");
  assert.equal(normalizePreviewPathname("/setup/"), "/setup");
  assert.equal(normalizePreviewPathname("/"), "/");
});

test("replaceState is used when the path needs normalizing", () => {
  const calls = [];
  const loc = { pathname: "/wizard/index.html", search: "?code=ABC234", hash: "" };
  const hist = { state: null, replaceState(_s, _t, url) { calls.push(url); } };
  applyPreviewPathNormalization(loc, hist);
  assert.deepEqual(calls, ["/wizard?code=ABC234"]);
});

test("old /hostkit-preview paths map to the root", () => {
  assert.equal(legacyPreviewPath("/hostkit-preview/"), "/");
  assert.equal(legacyPreviewPath("/hostkit-preview"), "/");
  assert.equal(legacyPreviewPath("/hostkit-preview/wizard/"), "/wizard/");
  assert.equal(legacyPreviewPath("/hostkit-preview/pair/ABC234"), "/pair/ABC234");
  assert.equal(legacyPreviewPath("/wizard/"), null);
  assert.equal(legacyPreviewPath("/hostkit-previewx/"), null);
});
