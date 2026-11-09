/**
 * Private values (Wi-Fi, door code, phone) live in a panel and are sent only
 * to the Worker's private endpoint. The document keeps {{PLACEHOLDER}} tokens.
 */

export const PRIVATE_TOKENS = {
  WIFI_SSID: "{{WIFI_SSID}}",
  WIFI_PASSWORD: "{{WIFI_PASSWORD}}",
  HOST_PHONE: "{{HOST_PHONE}}",
  DOOR_CODE: "{{DOOR_CODE}}",
  HOST_EMAIL: "{{HOST_EMAIL}}",
  PROPERTY_ADDRESS: "{{PROPERTY_ADDRESS}}",
};

const TOKEN_RE = /^\{\{[A-Z0-9_]+\}\}$/;

export function isPlaceholderToken(value) {
  return TOKEN_RE.test(String(value || "").trim());
}

export function documentKeepsPlaceholders(doc) {
  const wifi = doc?.wifi || {};
  const host = doc?.property?.host || {};
  const issues = [];
  const checks = [
    ["wifi.ssid", wifi.ssid, "WIFI_SSID"],
    ["wifi.password", wifi.password, "WIFI_PASSWORD"],
    ["property.host.phone", host.phone, "HOST_PHONE"],
    ["property.host.email", host.email, "HOST_EMAIL"],
  ];
  for (const [path, value, token] of checks) {
    if (value == null || value === "") continue;
    if (!isPlaceholderToken(value)) {
      issues.push({ path, token, message: `${path} must stay ${"{{"}${token}${"}}"} in the document` });
    }
  }
  return { ok: issues.length === 0, issues };
}

function looksLikePhone(value) {
  const digits = String(value).replace(/\D/g, "");
  return digits.length >= 10 && digits.length <= 15;
}

function looksLikePin(value) {
  return /^\d{4,6}$/.test(String(value).trim());
}

/**
 * Block raw private values in the published / editor-visible document.
 * Placeholders pass. Used alongside the HTML linter.
 */
export function lintDocumentForRawSecrets(doc) {
  const findings = [];
  const json = JSON.stringify(doc || {});

  function visit(value, path) {
    if (typeof value === "string") {
      if (isPlaceholderToken(value)) return;
      const key = path.split(".").pop() || "";
      if (/password|ssid/i.test(key) && value.length >= 4) {
        findings.push({ path, rule: "wifi-raw", snippet: "[redacted]" });
      } else if (/phone|tel|mobile/i.test(key) && looksLikePhone(value)) {
        findings.push({ path, rule: "phone-raw", snippet: "[redacted]" });
      } else if (/door|pin|lock|gate|accesscode/i.test(key) && looksLikePin(value)) {
        findings.push({ path, rule: "door-pin-raw", snippet: "[redacted]" });
      }
      return;
    }
    if (Array.isArray(value)) {
      value.forEach((v, i) => visit(v, `${path}[${i}]`));
      return;
    }
    if (value && typeof value === "object") {
      for (const [k, v] of Object.entries(value)) {
        visit(v, path ? `${path}.${k}` : k);
      }
    }
  }

  visit(doc, "");

  // Also catch explicit field patterns in serialized form
  const pin = /"(?:doorCode|door_code|lockCode|pin)"\s*:\s*"(\d{4,6})"/i.exec(json);
  if (pin && !findings.some((f) => f.rule === "door-pin-raw")) {
    findings.push({ path: pin[0].split(":")[0], rule: "door-pin-raw", snippet: "[redacted]" });
  }

  return { ok: findings.length === 0, findings };
}

/** Allowed keys sent to PUT /v1/host/private. Values never go in the document. */
export const PRIVATE_KEYS = [
  "WIFI_SSID",
  "WIFI_PASSWORD",
  "HOST_PHONE",
  "DOOR_CODE",
  "HOST_EMAIL",
  "PROPERTY_ADDRESS",
];

export function sanitizePrivatePayload(values) {
  const out = {};
  for (const key of PRIVATE_KEYS) {
    const v = values?.[key];
    if (typeof v === "string" && v.trim()) out[key] = v.trim();
  }
  return out;
}
