import assert from "node:assert/strict";
import { test } from "node:test";
import {
  normalizePreviewPathname,
  applyPreviewPathNormalization,
} from "../pathNormalize.js";

test("strips trailing slash and index.html", () => {
  assert.equal(normalizePreviewPathname("/hostkit-preview/wizard/"), "/hostkit-preview/wizard");
  assert.equal(normalizePreviewPathname("/hostkit-preview/wizard/index.html"), "/hostkit-preview/wizard");
  assert.equal(normalizePreviewPathname("/hostkit-preview/"), "/hostkit-preview");
  assert.equal(normalizePreviewPathname("/hostkit-preview"), "/hostkit-preview");
});

test("replaceState is used when the path needs normalizing", () => {
  const calls = [];
  const loc = { pathname: "/hostkit-preview/wizard/index.html", search: "?code=ABC234", hash: "" };
  const hist = { state: null, replaceState(_s, _t, url) { calls.push(url); } };
  applyPreviewPathNormalization(loc, hist);
  assert.deepEqual(calls, ["/hostkit-preview/wizard?code=ABC234"]);
});
