#!/usr/bin/env node
/**
 * Fail if committed files contain likely secrets.
 * Placeholders like {{WIFI_PASSWORD}} must pass.
 *
 * Usage:
 *   node scripts/secrets-scan.mjs              # scan repo (git ls-files)
 *   node scripts/secrets-scan.mjs <file...>    # scan listed files (tests)
 */
import { readFileSync, existsSync } from "node:fs";
import { execSync } from "node:child_process";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, "..");

const SKIP_NAMES = new Set([
  "package-lock.json",
  "pnpm-lock.yaml",
  "yarn.lock",
  "secrets-scan.mjs",
  "secrets-scan.test.mjs",
]);

const SKIP_EXT = new Set([
  ".png",
  ".jpg",
  ".jpeg",
  ".gif",
  ".webp",
  ".ico",
  ".woff",
  ".woff2",
  ".ttf",
  ".eot",
  ".mp4",
  ".zip",
  ".gz",
]);

function isPlaceholder(s) {
  return /^\{\{[A-Z0-9_]+\}\}$/.test(String(s).trim());
}

/** Strip {{PLACEHOLDER}} tokens before scanning so they never trip rules. */
function scrubPlaceholders(text) {
  return text.replace(/\{\{[A-Z0-9_]+\}\}/g, "{{__OK__}}");
}

/**
 * Patterns that indicate a likely committed secret.
 * Each returns { rule, match } or null.
 */
const RULES = [
  {
    id: "wifi-password-raw",
    // "password": "SomethingNotPlaceholder" near wifi context, or wifi.password style
    test(text) {
      const re =
        /(?:wifi["'\s]*[:=][\s\S]{0,200})?["']?password["']?\s*:\s*["']([^"']+)["']/gi;
      let m;
      while ((m = re.exec(text))) {
        const val = m[1];
        if (isPlaceholder(val) || val === "{{__OK__}}") continue;
        if (val.length < 4) continue;
        return { rule: "wifi-password-raw", match: val };
      }
      // ssid paired with a non-placeholder password on nearby lines
      const block =
        /"ssid"\s*:\s*"[^"]+"[\s\S]{0,120}"password"\s*:\s*"([^"]+)"/gi;
      while ((m = block.exec(text))) {
        if (isPlaceholder(m[1]) || m[1] === "{{__OK__}}") continue;
        return { rule: "wifi-password-raw", match: m[1] };
      }
      return null;
    },
  },
  {
    id: "door-pin",
    test(text) {
      // code / lock / pin / doorCode fields with 4-6 digit values
      const re =
        /["']?(?:doorCode|door_code|lockCode|lock_code|pin|gateCode|gate_code|accessCode|access_code|code)["']?\s*:\s*["']?(\d{4,6})["']?/gi;
      let m;
      while ((m = re.exec(text))) {
        return { rule: "door-pin", match: m[1] };
      }
      return null;
    },
  },
  {
    id: "phone-number",
    test(text) {
      // Only flag explicit phone-like fields (avoid Wikimedia file ids, etc.)
      const re =
        /["']?(?:phone|tel|mobile|hostPhone|host_phone)["']?\s*:\s*["']([^"']+)["']/gi;
      let m;
      while ((m = re.exec(text))) {
        const val = (m[1] || "").trim();
        if (!val || isPlaceholder(val) || val === "{{__OK__}}") continue;
        const digits = val.replace(/\D/g, "");
        if (digits.length >= 10 && digits.length <= 15) {
          return { rule: "phone-number", match: val };
        }
        // Non-placeholder phone field with any content still suspicious
        if (!/^\+?[\d\s().-]{7,}$/.test(val) && digits.length >= 7) {
          return { rule: "phone-number", match: val };
        }
        if (digits.length >= 7) {
          return { rule: "phone-number", match: val };
        }
      }
      return null;
    },
  },
  {
    id: "card-like",
    test(text) {
      // 13-19 digit runs that look like PANs (ignore shorter IDs)
      const re = /(?:\d[ -]*?){13,19}/g;
      let m;
      while ((m = re.exec(text))) {
        const digits = m[0].replace(/\D/g, "");
        if (digits.length < 13 || digits.length > 19) continue;
        // skip obvious non-cards (all same digit, ascending test patterns)
        if (/^(\d)\1+$/.test(digits)) continue;
        return { rule: "card-like", match: digits.slice(0, 4) + "…" };
      }
      return null;
    },
  },
  {
    id: "api-token-like",
    test(text) {
      const re =
        /(?:api[_-]?key|api[_-]?token|access[_-]?token|secret[_-]?key|bearer|GUEST_PATH_KEY|EAGLEWOOD_TOKEN|CLOUDFLARE_API_TOKEN)\s*[=:]\s*["']?([A-Za-z0-9_\-./+=]{16,})["']?/gi;
      let m;
      while ((m = re.exec(text))) {
        const val = m[1];
        if (isPlaceholder(val) || val === "{{__OK__}}") continue;
        if (/^\$\{\{\s*secrets\./i.test(m[0])) continue; // GH Actions ref
        if (val.includes("secrets.")) continue;
        return { rule: "api-token-like", match: val.slice(0, 8) + "…" };
      }
      // raw sk_live / pk_live / ghp_ / gho_ style
      const raw =
        /\b(sk_live_[A-Za-z0-9]{16,}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})\b/g;
      while ((m = raw.exec(text))) {
        return { rule: "api-token-like", match: m[1].slice(0, 8) + "…" };
      }
      return null;
    },
  },
];

function listGitFiles() {
  // Include untracked (but not ignored) files so local pre-commit scans work.
  const out = execSync("git ls-files -z -c -o --exclude-standard", {
    cwd: root,
    encoding: "buffer",
  });
  return out
    .toString("utf8")
    .split("\0")
    .filter(Boolean);
}

function shouldScan(relPath) {
  const base = relPath.split("/").pop();
  if (SKIP_NAMES.has(base)) return false;
  const ext = base.includes(".") ? "." + base.split(".").pop().toLowerCase() : "";
  if (SKIP_EXT.has(ext)) return false;
  return true;
}

export function scanText(text, label = "<text>") {
  const scrubbed = scrubPlaceholders(text);
  const findings = [];
  for (const rule of RULES) {
    const hit = rule.test(scrubbed);
    if (hit) findings.push({ file: label, ...hit });
  }
  return findings;
}

export function scanFiles(paths) {
  const findings = [];
  for (const p of paths) {
    const abs = p.startsWith("/") ? p : join(root, p);
    if (!existsSync(abs)) continue;
    const rel = relative(root, abs) || p;
    if (!shouldScan(rel)) continue;
    let text;
    try {
      text = readFileSync(abs, "utf8");
    } catch {
      continue; // binary
    }
    findings.push(...scanText(text, rel));
  }
  return findings;
}

function main() {
  const args = process.argv.slice(2);
  const files = args.length > 0 ? args : listGitFiles();
  const findings = scanFiles(files);
  if (findings.length > 0) {
    console.error("Secrets scan FAILED:");
    for (const f of findings) {
      console.error(`  [${f.rule}] ${f.file}: ${f.match}`);
    }
    process.exit(1);
  }
  console.log(`Secrets scan OK (${files.length} path(s) checked)`);
}

const isMain =
  process.argv[1] &&
  fileURLToPath(import.meta.url) === process.argv[1];

if (isMain) {
  main();
}
