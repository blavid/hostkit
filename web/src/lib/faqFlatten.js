/**
 * TV shows at most 2 FAQ levels; deeper nests flatten into the parent.
 * Depth 0 = root category list; depth 1 = category's child categories;
 * anything deeper is merged into the nearest depth-1 (or root) parent.
 */

function cloneCategory(cat) {
  return {
    ...cat,
    items: Array.isArray(cat.items) ? cat.items.map((i) => ({ ...i })) : [],
    categories: Array.isArray(cat.categories)
      ? cat.categories.map(cloneCategory)
      : [],
  };
}

/**
 * Flatten a FAQ tree so no category has nested categories deeper than
 * `maxDepth` levels below the root list (default 2 → root + one child level).
 * Returns { preview, warnings } where preview is the flattened tree and
 * warnings list paths that were collapsed.
 */
export function flattenFaqsForTv(faqs, maxDepth = 2) {
  const warnings = [];
  if (!Array.isArray(faqs)) {
    return { preview: [], warnings: ["faqs must be an array"] };
  }

  function walk(cats, depth, path) {
    return cats.map((raw, idx) => {
      const cat = cloneCategory(raw);
      const here = `${path}/${cat.id || idx}`;
      const children = Array.isArray(cat.categories) ? cat.categories : [];

      if (depth >= maxDepth) {
        // Should not happen for root call; defensive.
        return { ...cat, categories: [] };
      }

      if (depth === maxDepth - 1) {
        // Last visible level: absorb deeper descendants into this category's items
        // and drop nested categories from the TV preview.
        const absorbed = [];
        function absorb(list, prefix) {
          for (const child of list) {
            const childPath = `${prefix}/${child.id || "?"}`;
            if (Array.isArray(child.items) && child.items.length) {
              absorbed.push(
                ...child.items.map((item) => ({
                  ...item,
                  q: item.q,
                  a: item.a,
                  // Keep identity for preview; optional note in title via prefix
                  _from: child.title || child.id,
                }))
              );
            }
            if (Array.isArray(child.categories) && child.categories.length) {
              warnings.push(
                `Flattened nested FAQ at ${childPath} into ${here} (TV max depth ${maxDepth})`
              );
              absorb(child.categories, childPath);
            } else if (Array.isArray(child.items) && child.items.length) {
              warnings.push(
                `Flattened FAQ category ${childPath} into ${here} (TV max depth ${maxDepth})`
              );
            }
          }
        }
        if (children.length) {
          absorb(children, here);
        }
        const items = [
          ...(Array.isArray(cat.items) ? cat.items : []),
          ...absorbed.map(({ _from, ...rest }) => rest),
        ];
        return { ...cat, items, categories: [] };
      }

      // depth < maxDepth - 1: keep one more level, recurse
      return {
        ...cat,
        categories: walk(children, depth + 1, here),
      };
    });
  }

  const preview = walk(faqs.map(cloneCategory), 0, "faqs");
  return { preview, warnings };
}

/**
 * True when any category nest exceeds maxDepth levels from the root list.
 */
export function faqExceedsTvDepth(faqs, maxDepth = 2) {
  function depthOf(cats, d) {
    let max = d;
    for (const c of cats || []) {
      if (Array.isArray(c.categories) && c.categories.length) {
        max = Math.max(max, depthOf(c.categories, d + 1));
      }
    }
    return max;
  }
  // Root list is level 1 in "levels shown"; a single category with no children
  // has depth 1. Nested child categories add depth.
  const deepest = depthOf(faqs, 1);
  return deepest > maxDepth;
}
