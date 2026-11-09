/**
 * Listing copy import within platform terms (SPEC §10.1.1).
 * Paste or official export (JSON/CSV) only. No fetching or scraping.
 * The host must consent and review every imported sentence before it is saved.
 */

const CONSENT_TEXT =
  "I own this listing and consent to importing my own text";

export { CONSENT_TEXT };

export function splitSentences(text) {
  const raw = String(text || "").replace(/\r\n/g, "\n").trim();
  if (!raw) return [];
  const parts = raw
    .split(/(?<=[.?!])\s+|\n+/)
    .map((s) => s.trim())
    .filter(Boolean);
  return parts;
}

function cellsFromCsvLine(line) {
  const out = [];
  let cur = "";
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (inQuotes) {
      if (ch === '"' && line[i + 1] === '"') {
        cur += '"';
        i++;
      } else if (ch === '"') {
        inQuotes = false;
      } else {
        cur += ch;
      }
    } else if (ch === '"') {
      inQuotes = true;
    } else if (ch === ",") {
      out.push(cur);
      cur = "";
    } else {
      cur += ch;
    }
  }
  out.push(cur);
  return out.map((s) => s.trim());
}

export function parseCsv(text) {
  const lines = String(text || "").replace(/\r\n/g, "\n").split("\n").filter((l) => l.trim());
  if (lines.length === 0) return [];
  const header = cellsFromCsvLine(lines[0]).map((h) => h.toLowerCase());
  const rows = [];
  for (const line of lines.slice(1)) {
    const cells = cellsFromCsvLine(line);
    const row = {};
    header.forEach((h, i) => {
      row[h] = cells[i] || "";
    });
    rows.push(row);
  }
  return rows;
}

function textFromJsonValue(value, acc) {
  if (typeof value === "string") {
    acc.push(value);
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((v) => textFromJsonValue(v, acc));
    return;
  }
  if (value && typeof value === "object") {
    for (const [k, v] of Object.entries(value)) {
      // Skip ids and urls — we want prose
      if (/^(id|url|href|image|photo|sku)$/i.test(k)) continue;
      textFromJsonValue(v, acc);
    }
  }
}

export function extractImportText(input, { filename = "" } = {}) {
  const text = String(input || "");
  const lower = filename.toLowerCase();
  if (lower.endsWith(".csv") || (!lower && /,\s*"?(title|description|question|answer|summary)/i.test(text.split("\n")[0] || ""))) {
    const rows = parseCsv(text);
    const chunks = [];
    for (const row of rows) {
      for (const key of Object.keys(row)) {
        if (row[key]) chunks.push(row[key]);
      }
    }
    return { kind: "csv", text: chunks.join("\n"), rows };
  }
  const trimmed = text.trim();
  if (trimmed.startsWith("{") || trimmed.startsWith("[")) {
    let parsed;
    try {
      parsed = JSON.parse(trimmed);
    } catch (err) {
      throw new Error(`Invalid JSON export: ${err.message}`);
    }
    const acc = [];
    textFromJsonValue(parsed, acc);
    return { kind: "json", text: acc.join("\n"), parsed };
  }
  return { kind: "paste", text };
}

/**
 * Build a review list. Nothing is marked accepted until the host says so.
 * Import is rejected without the consent checkbox.
 */
export function prepareImportReview({ sourceText, consent, filename } = {}) {
  if (!consent) {
    return {
      ok: false,
      error: `Consent required: "${CONSENT_TEXT}"`,
      sentences: [],
    };
  }
  const extracted = extractImportText(sourceText, { filename });
  const sentences = splitSentences(extracted.text).map((text, index) => ({
    id: `s${index + 1}`,
    text,
    accepted: false,
  }));
  return { ok: true, kind: extracted.kind, sentences };
}

export function acceptedSentences(review) {
  return (review?.sentences || []).filter((s) => s.accepted).map((s) => s.text);
}

/**
 * Turn accepted sentences into FAQ starter items (and optional property tagline).
 * The host still sees these in the editor before publish.
 */
export function draftFromAccepted(accepted, { title = "Imported listing copy" } = {}) {
  const items = accepted.map((text, i) => {
    const q = text.length > 80 ? `${text.slice(0, 77)}…` : text;
    return { q: `Note ${i + 1}: ${q}`, a: text };
  });
  return {
    faqCategory: {
      id: "imported-listing",
      title,
      items,
      categories: [],
    },
    sentences: accepted,
  };
}
