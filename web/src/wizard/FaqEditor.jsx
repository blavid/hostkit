import React from "react";

function newId(prefix) {
  return `${prefix}-${Math.random().toString(36).slice(2, 8)}`;
}

export function FaqEditor({ faqs, onChange, depthWarning }) {
  const update = (next) => onChange(next);

  return (
    <div>
      {depthWarning && (
        <p className="warn">
          Warning: FAQ depth exceeds 2. The TV preview flattens deeper levels.
        </p>
      )}
      {(faqs || []).map((cat, i) => (
        <Category
          key={cat.id || i}
          cat={cat}
          depth={1}
          onChange={(next) => {
            const copy = faqs.slice();
            copy[i] = next;
            update(copy);
          }}
          onRemove={() => update(faqs.filter((_, idx) => idx !== i))}
        />
      ))}
      <button
        type="button"
        onClick={() =>
          update([
            ...(faqs || []),
            { id: newId("cat"), title: "New category", items: [], categories: [] },
          ])
        }
      >
        Add category
      </button>
    </div>
  );
}

function Category({ cat, depth, onChange, onRemove }) {
  const set = (patch) => onChange({ ...cat, ...patch });
  const items = Array.isArray(cat.items) ? cat.items : [];
  const children = Array.isArray(cat.categories) ? cat.categories : [];

  return (
    <div className="faq-cat" style={{ marginLeft: depth > 1 ? "0.75rem" : 0 }}>
      <label>
        Category {depth > 2 ? `(depth ${depth} — will flatten on the TV)` : ""}
      </label>
      <input
        type="text"
        value={cat.title || ""}
        onChange={(e) => set({ title: e.target.value })}
        aria-label="Category title"
      />
      {items.map((item, i) => (
        <div className="faq-item" key={`${cat.id}-item-${i}`}>
          <label>Question</label>
          <input
            type="text"
            value={item.q || ""}
            onChange={(e) => {
              const next = items.slice();
              next[i] = { ...item, q: e.target.value };
              set({ items: next });
            }}
          />
          <label>Answer</label>
          <textarea
            className="short"
            value={item.a || ""}
            onChange={(e) => {
              const next = items.slice();
              next[i] = { ...item, a: e.target.value };
              set({ items: next });
            }}
          />
          <button
            type="button"
            onClick={() => set({ items: items.filter((_, idx) => idx !== i) })}
          >
            Remove item
          </button>
        </div>
      ))}
      <div className="row">
        <button
          type="button"
          onClick={() => set({ items: [...items, { q: "", a: "" }] })}
        >
          Add item
        </button>
        <button
          type="button"
          onClick={() =>
            set({
              categories: [
                ...children,
                { id: newId("cat"), title: "Nested category", items: [], categories: [] },
              ],
            })
          }
        >
          Add nested category
        </button>
        <button type="button" onClick={onRemove}>
          Remove category
        </button>
      </div>
      {children.map((child, i) => (
        <Category
          key={child.id || i}
          cat={child}
          depth={depth + 1}
          onChange={(next) => {
            const copy = children.slice();
            copy[i] = next;
            set({ categories: copy });
          }}
          onRemove={() => set({ categories: children.filter((_, idx) => idx !== i) })}
        />
      ))}
    </div>
  );
}
