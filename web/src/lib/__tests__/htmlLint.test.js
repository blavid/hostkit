import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { looksLikeHtml, lintDocumentForHtml } from "../htmlLint.js";

describe("htmlLint", () => {
  it("detects tags and entities", () => {
    assert.equal(looksLikeHtml("Hello <b>world</b>"), true);
    assert.equal(looksLikeHtml("Tom &amp; Jerry"), true);
    assert.equal(looksLikeHtml("Plain text & ampersand ok?"), false);
    assert.equal(looksLikeHtml("https://example.com/path"), false);
  });

  it("walks a document for HTML fields", () => {
    const { ok, findings } = lintDocumentForHtml({
      faqs: [{ id: "x", items: [{ q: "Hi?", a: "<script>x</script>" }] }],
      property: { name: "Safe" },
    });
    assert.equal(ok, false);
    assert.ok(findings.some((f) => f.path.includes("faqs")));
  });
});
