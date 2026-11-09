import library from "../data/regional-library.json" with { type: "json" };
import { dedupeActivitiesById } from "./activityDedupe.js";

export function getRegionalLibrary() {
  return library;
}

export function curatedActivities() {
  return library.curated.slice();
}

export function officialLinkTemplates() {
  return library.officialLinkTemplates.slice();
}

/**
 * Add selected library cards and official-link entries into the document list.
 * Cards with linkPolicy "official-link-or-widget" must be confirmed by the host.
 * Dedupe by id (first wins).
 */
export function addActivities(existing, additions, { confirmedIds = [] } = {}) {
  const confirmed = new Set(confirmedIds);
  const rejected = [];
  const accepted = [];
  for (const card of additions || []) {
    if (card?.linkPolicy === "official-link-or-widget" && !confirmed.has(card.id)) {
      rejected.push({ id: card.id, reason: "host-confirm-required" });
      continue;
    }
    if (card?.linkPolicy === "official-link-or-widget") {
      const url = card.signupUrl || card.url;
      if (!url) {
        rejected.push({ id: card.id, reason: "official-url-required" });
        continue;
      }
    }
    accepted.push(card);
  }
  const { activities, duplicates } = dedupeActivitiesById([
    ...(existing || []),
    ...accepted,
  ]);
  return { activities, duplicates, rejected };
}

export function makeOfficialLinkCard(template, officialUrl) {
  const card = { ...template };
  const url = String(officialUrl || "").trim();
  if (/viator\.com/i.test(url) || template.source === "viator") {
    card.signupUrl = url;
  } else {
    card.url = url;
  }
  card.id = template.id === "viator-official-link" || template.id === "alltrails-official-link"
    ? `${template.source}-${simpleId(url || template.id)}`
    : template.id;
  return card;
}

function simpleId(s) {
  return String(s)
    .toLowerCase()
    .replace(/^https?:\/\//, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 48) || "link";
}
