#!/usr/bin/env node
/**
 * Prove: customer0 fixture passes; a bad fixture with a raw Wi-Fi password fails.
 */
import { writeFileSync, mkdirSync, rmSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { scanFiles, scanText } from "./secrets-scan.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, "..");
const tmp = join(root, "scripts", ".scan-fixtures-tmp");

let failed = 0;
function assert(cond, msg) {
  if (!cond) {
    console.error("FAIL:", msg);
    failed++;
  } else {
    console.log("OK  ", msg);
  }
}

// 1) Placeholders alone must pass
assert(
  scanText('{"wifi":{"ssid":"{{WIFI_SSID}}","password":"{{WIFI_PASSWORD}}"}}')
    .length === 0,
  "placeholders pass"
);

// 2) customer0 fixture must pass
const customer0 = join(root, "schema", "eaglewood.customer0.json");
const c0 = scanFiles([customer0]);
assert(c0.length === 0, `eaglewood.customer0.json passes (findings=${JSON.stringify(c0)})`);

// 3) Bad fixture with raw wifi password must fail
mkdirSync(tmp, { recursive: true });
const badPath = join(tmp, "bad-wifi.json");
writeFileSync(
  badPath,
  JSON.stringify(
    {
      wifi: { ssid: "MyHouse", password: "S3cretWifiPass" },
    },
    null,
    2
  )
);
const bad = scanFiles([badPath]);
assert(bad.length > 0, "raw wifi password fails");
assert(
  bad.some((f) => f.rule === "wifi-password-raw"),
  "failure rule is wifi-password-raw"
);

// 4) Door PIN fails
assert(
  scanText('{"lock":{"code":"482913"}}').some((f) => f.rule === "door-pin"),
  "door PIN fails"
);

// 5) Phone fails
assert(
  scanText('{"host":{"phone":"541-555-0199"}}').some(
    (f) => f.rule === "phone-number"
  ),
  "phone number fails"
);

rmSync(tmp, { recursive: true, force: true });

if (failed > 0) {
  console.error(`\n${failed} assertion(s) failed`);
  process.exit(1);
}
console.log("\nAll secrets-scan tests passed");
