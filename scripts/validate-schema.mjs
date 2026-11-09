#!/usr/bin/env node
/**
 * Validate every schema fixture (schema/fixtures/*.json and schema/*.json
 * except the schema document itself) against hostkit.v1.schema.json.
 */
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, dirname, basename } from "node:path";
import { fileURLToPath } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, "..");
const schemaDir = join(root, "schema");
const schemaPath = join(schemaDir, "hostkit.v1.schema.json");

const schema = JSON.parse(readFileSync(schemaPath, "utf8"));
const ajv = new Ajv2020({ allErrors: true, strict: false });
addFormats(ajv);
const validate = ajv.compile(schema);

function collectFixtures() {
  const files = [];
  for (const name of readdirSync(schemaDir)) {
    const p = join(schemaDir, name);
    if (!statSync(p).isFile()) continue;
    if (!name.endsWith(".json")) continue;
    if (name === "hostkit.v1.schema.json") continue;
    files.push(p);
  }
  const fixturesDir = join(schemaDir, "fixtures");
  try {
    for (const name of readdirSync(fixturesDir)) {
      if (!name.endsWith(".json")) continue;
      files.push(join(fixturesDir, name));
    }
  } catch {
    // fixtures/ optional
  }
  return files.sort();
}

const fixtures = collectFixtures();
if (fixtures.length === 0) {
  console.error("No fixtures found under schema/ or schema/fixtures/");
  process.exit(1);
}

let failed = 0;
for (const file of fixtures) {
  const rel = file.slice(root.length + 1);
  let data;
  try {
    data = JSON.parse(readFileSync(file, "utf8"));
  } catch (err) {
    console.error(`FAIL ${rel}: invalid JSON (${err.message})`);
    failed++;
    continue;
  }
  const ok = validate(data);
  if (ok) {
    console.log(`OK   ${rel}`);
  } else {
    failed++;
    console.error(`FAIL ${rel}`);
    for (const e of validate.errors || []) {
      console.error(`  - ${e.instancePath || "/"} ${e.message}`);
    }
  }
}

if (failed > 0) {
  console.error(`\n${failed} fixture(s) failed schema validation`);
  process.exit(1);
}
console.log(`\nValidated ${fixtures.length} fixture(s)`);
