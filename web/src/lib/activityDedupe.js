/**
 * Deduplicate activity cards by id. First occurrence wins.
 * Returns { activities, duplicates } where duplicates lists dropped ids.
 */
export function dedupeActivitiesById(activities) {
  if (!Array.isArray(activities)) {
    return { activities: [], duplicates: [] };
  }
  const seen = new Set();
  const out = [];
  const duplicates = [];
  for (const card of activities) {
    const id = card?.id;
    if (id == null || id === "") {
      out.push(card);
      continue;
    }
    if (seen.has(id)) {
      duplicates.push(id);
      continue;
    }
    seen.add(id);
    out.push(card);
  }
  return { activities: out, duplicates };
}
