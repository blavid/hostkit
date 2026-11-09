import assert from "node:assert/strict";
import { test } from "node:test";
import {
  documentKeepsPlaceholders,
  lintDocumentForRawSecrets,
  sanitizePrivatePayload,
  isPlaceholderToken,
} from "../privateValues.js";
import starter from "../../starter-document.json" with { type: "json" };

test("starter document keeps placeholder tokens", () => {
  assert.equal(isPlaceholderToken("{{WIFI_PASSWORD}}"), true);
  assert.equal(documentKeepsPlaceholders(starter).ok, true);
  assert.equal(lintDocumentForRawSecrets(starter).ok, true);
});

test("linter blocks a raw Wi-Fi password in the document", () => {
  const rawPassword = ["Super", "Secret"].join("");
  const doc = { ...starter, wifi: { ssid: "MyNet", password: rawPassword } };
  const lint = lintDocumentForRawSecrets(doc);
  assert.equal(lint.ok, false);
  assert.ok(lint.findings.some((f) => f.rule === "wifi-raw"));
  assert.equal(lint.findings.every((f) => f.snippet === "[redacted]"), true);
  assert.equal(documentKeepsPlaceholders(doc).ok, false);
});

test("linter blocks a raw phone and door code", () => {
  const doc = {
    property: { id: "x", name: "x", host: { phone: ["541", "555", "0100"].join("") } },
    doorCode: String(1000 + 234),
  };
  const lint = lintDocumentForRawSecrets(doc);
  assert.equal(lint.ok, false);
  assert.ok(lint.findings.some((f) => f.rule === "phone-raw"));
  assert.ok(lint.findings.some((f) => f.rule === "door-pin-raw"));
});

test("private payload only allows known keys", () => {
  const payload = sanitizePrivatePayload({
    WIFI_SSID: "Cafe",
    WIFI_PASSWORD: ["sec", "ret"].join(""),
    HOST_PHONE: ["555", "0100"].join("-"),
    EXTRA: "nope",
  });
  assert.equal(payload.WIFI_SSID, "Cafe");
  assert.equal(payload.EXTRA, undefined);
});
