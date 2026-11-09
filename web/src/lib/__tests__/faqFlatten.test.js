import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { flattenFaqsForTv, faqExceedsTvDepth } from "../faqFlatten.js";

describe("flattenFaqsForTv", () => {
  it("keeps two levels intact", () => {
    const faqs = [
      {
        id: "root",
        title: "Root",
        items: [{ q: "A?", a: "1" }],
        categories: [
          {
            id: "child",
            title: "Child",
            items: [{ q: "B?", a: "2" }],
          },
        ],
      },
    ];
    const { preview, warnings } = flattenFaqsForTv(faqs, 2);
    assert.equal(warnings.length, 0);
    assert.equal(preview[0].categories.length, 1);
    assert.equal(preview[0].categories[0].id, "child");
    assert.equal(preview[0].categories[0].items[0].q, "B?");
  });

  it("flattens depth-3 into the depth-2 parent", () => {
    const faqs = [
      {
        id: "root",
        title: "Root",
        items: [],
        categories: [
          {
            id: "child",
            title: "Child",
            items: [{ q: "Keep?", a: "yes" }],
            categories: [
              {
                id: "grand",
                title: "Grand",
                items: [{ q: "Deep?", a: "flat" }],
              },
            ],
          },
        ],
      },
    ];
    const { preview, warnings } = flattenFaqsForTv(faqs, 2);
    assert.ok(warnings.length >= 1);
    assert.equal(preview[0].categories[0].categories.length, 0);
    const qs = preview[0].categories[0].items.map((i) => i.q);
    assert.deepEqual(qs, ["Keep?", "Deep?"]);
  });

  it("faqExceedsTvDepth detects deep trees", () => {
    assert.equal(faqExceedsTvDepth([{ id: "a", items: [] }], 2), false);
    assert.equal(
      faqExceedsTvDepth(
        [
          {
            id: "a",
            categories: [{ id: "b", categories: [{ id: "c", items: [] }] }],
          },
        ],
        2
      ),
      true
    );
  });
});
