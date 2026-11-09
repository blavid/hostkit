import assert from "node:assert/strict";
import { test } from "node:test";
import {
  CODE_ALPHABET,
  isValidPairCode,
  normalizePairCode,
  codeFromLocation,
} from "../pairingCode.js";

test("alphabet excludes 0, O, 1, I, and L", () => {
  for (const ch of ["0", "O", "1", "I", "L"]) {
    assert.equal(CODE_ALPHABET.includes(ch), false, ch);
  }
  assert.equal(isValidPairCode("ABCDEF"), true);
  assert.equal(isValidPairCode("abc234"), true);
  assert.equal(isValidPairCode("  abc234  "), true);
  assert.equal(isValidPairCode("AB0CDE"), false);
  assert.equal(isValidPairCode("ABOCDE"), false);
  assert.equal(isValidPairCode("AB1CDE"), false);
  assert.equal(isValidPairCode("ABICDE"), false);
  assert.equal(isValidPairCode("ABL234"), false);
  assert.equal(isValidPairCode("ABC23"), false);
});

test("normalize trims and uppercases", () => {
  assert.equal(normalizePairCode("  abcd2e "), "ABCD2E");
});

test("prefill from ?code= and /pair/:code", () => {
  assert.equal(codeFromLocation("?code=abC234", "/hostkit-preview/wizard"), "ABC234");
  assert.equal(codeFromLocation("", "/hostkit-preview/pair/xyz234"), "XYZ234");
  assert.equal(codeFromLocation("", "/hostkit-preview/pair/xyz234/"), "XYZ234");
  assert.equal(codeFromLocation("", "/wizard"), "");
});
