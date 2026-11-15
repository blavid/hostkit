import assert from "node:assert/strict";
import { test } from "node:test";
import {
  curatedActivities,
  officialLinkTemplates,
  addActivities,
  makeOfficialLinkCard,
} from "../activityLibrary.js";

test("curated library has stable ids, credits when present, and no private notes", () => {
  const cards = curatedActivities();
  assert.ok(cards.length > 10);
  const ids = new Set();
  for (const card of cards) {
    assert.ok(card.id && card.title && card.category);
    assert.equal(ids.has(card.id), false, `duplicate ${card.id}`);
    ids.add(card.id);
    const blob = JSON.stringify(card);
    assert.equal(/kitchen drawer|ask us|our garage|pid=/i.test(blob), false, card.id);
  }
  assert.ok(cards.some((c) => c.imageCredit && c.imageCredit.license));
});

test("dedupes by id when adding from the library", () => {
  const first = curatedActivities().find((c) => !c.needsHostConfirm);
  const { activities, duplicates } = addActivities([first], [first]);
  assert.equal(activities.length, 1);
  assert.deepEqual(duplicates, [first.id]);
});

test("Viator and AllTrails official-link entries require host confirmation and a URL", () => {
  const templates = officialLinkTemplates();
  const viator = templates.find((t) => t.source === "viator");
  const trails = templates.find((t) => t.source === "alltrails");
  assert.ok(viator && trails);
  const unconfirmed = addActivities([], [viator]);
  assert.equal(unconfirmed.activities.length, 0);
  assert.equal(unconfirmed.rejected[0].reason, "host-confirm-required");

  const noUrl = addActivities([], [viator], { confirmedIds: [viator.id] });
  assert.equal(noUrl.rejected[0].reason, "official-url-required");

  const card = makeOfficialLinkCard(viator, "https://www.viator.com/tours/Bend/example");
  const added = addActivities([], [card], { confirmedIds: [card.id] });
  assert.equal(added.activities.length, 1);
  assert.equal(added.activities[0].signupUrl, "https://www.viator.com/tours/Bend/example");
});
