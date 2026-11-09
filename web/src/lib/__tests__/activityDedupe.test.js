import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { dedupeActivitiesById } from "../activityDedupe.js";

describe("dedupeActivitiesById", () => {
  it("keeps first occurrence", () => {
    const { activities, duplicates } = dedupeActivitiesById([
      { id: "a", title: "First" },
      { id: "b", title: "Bee" },
      { id: "a", title: "Second" },
    ]);
    assert.deepEqual(
      activities.map((a) => a.title),
      ["First", "Bee"]
    );
    assert.deepEqual(duplicates, ["a"]);
  });

  it("preserves cards without ids", () => {
    const { activities, duplicates } = dedupeActivitiesById([
      { title: "No id" },
      { id: "x", title: "X" },
    ]);
    assert.equal(activities.length, 2);
    assert.equal(duplicates.length, 0);
  });
});
