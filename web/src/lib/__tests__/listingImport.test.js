import assert from "node:assert/strict";
import { test } from "node:test";
import {
  CONSENT_TEXT,
  splitSentences,
  prepareImportReview,
  acceptedSentences,
  draftFromAccepted,
  parseCsv,
} from "../listingImport.js";

test("splits sentences and line breaks", () => {
  assert.deepEqual(splitSentences("Hello home. Welcome guests!\nQuiet after 10."), [
    "Hello home.",
    "Welcome guests!",
    "Quiet after 10.",
  ]);
});

test("rejects import without consent", () => {
  const review = prepareImportReview({
    sourceText: "A lovely cabin in the pines.",
    consent: false,
  });
  assert.equal(review.ok, false);
  assert.match(review.error, /Consent required/);
  assert.match(review.error, new RegExp(CONSENT_TEXT));
  assert.equal(review.sentences.length, 0);
});

test("paste import requires per-sentence acceptance before save", () => {
  const review = prepareImportReview({
    sourceText: "Hot tub on the deck. Parking for two cars.",
    consent: true,
  });
  assert.equal(review.ok, true);
  assert.equal(review.sentences.length, 2);
  assert.equal(review.sentences.every((s) => s.accepted === false), true);
  assert.deepEqual(acceptedSentences(review), []);
  review.sentences[0].accepted = true;
  assert.deepEqual(acceptedSentences(review), ["Hot tub on the deck."]);
  const draft = draftFromAccepted(acceptedSentences(review));
  assert.equal(draft.faqCategory.items.length, 1);
  assert.equal(draft.sentences.length, 1);
});

test("parses an official CSV export", () => {
  const csv = `title,description\n"Cabin","Quiet street. Great views."`;
  const rows = parseCsv(csv);
  assert.equal(rows[0].title, "Cabin");
  const review = prepareImportReview({ sourceText: csv, consent: true, filename: "listing.csv" });
  assert.equal(review.ok, true);
  assert.equal(review.kind, "csv");
  assert.ok(review.sentences.some((s) => s.text === "Quiet street."));
});

test("parses an official JSON export", () => {
  const json = JSON.stringify({ name: "Cabin", summary: "Two bedrooms. Walk to the village." });
  const review = prepareImportReview({ sourceText: json, consent: true, filename: "export.json" });
  assert.equal(review.kind, "json");
  assert.ok(review.sentences.some((s) => s.text.includes("Two bedrooms.")));
});
