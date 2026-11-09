import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  contrastRatio,
  checkBrandingContrast,
  parseColor,
} from "../contrast.js";

describe("contrast", () => {
  it("parses hex colors", () => {
    assert.deepEqual(parseColor("#fff"), { r: 255, g: 255, b: 255 });
    assert.deepEqual(parseColor("#000000"), { r: 0, g: 0, b: 0 });
  });

  it("black on white is 21:1", () => {
    const r = contrastRatio("#000", "#fff");
    assert.ok(Math.abs(r - 21) < 0.05);
  });

  it("rejects low-contrast branding", () => {
    const res = checkBrandingContrast({
      colors: { text: "#777777", background: "#888888" },
    });
    assert.equal(res.ok, false);
    assert.ok(res.issues.length >= 1);
    assert.ok(res.issues[0].ratio < 4.5);
  });

  it("accepts high-contrast branding", () => {
    const res = checkBrandingContrast({
      colors: { text: "#111111", background: "#ffffff", accent: "#0000aa" },
    });
    assert.equal(res.ok, true);
  });
});
