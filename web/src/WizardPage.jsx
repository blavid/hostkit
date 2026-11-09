import React, { useMemo, useState, useCallback } from "react";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import schema from "./hostkit.v1.schema.json";
import starter from "./starter-document.json";

function buildValidator() {
  const ajv = new Ajv2020({ allErrors: true, strict: false });
  addFormats(ajv);
  return ajv.compile(schema);
}

export function WizardPage() {
  const validate = useMemo(() => buildValidator(), []);
  const [doc, setDoc] = useState(() => structuredClone(starter));
  const [raw, setRaw] = useState(() => JSON.stringify(starter, null, 2));
  const [parseError, setParseError] = useState(null);

  const validation = useMemo(() => {
    if (parseError) return { ok: false, errors: [parseError] };
    const ok = validate(doc);
    if (ok) return { ok: true, errors: [] };
    return {
      ok: false,
      errors: (validate.errors || []).map(
        (e) => `${e.instancePath || "/"} ${e.message}`
      ),
    };
  }, [doc, parseError, validate]);

  const applyRaw = useCallback(
    (text) => {
      setRaw(text);
      try {
        const parsed = JSON.parse(text);
        setParseError(null);
        setDoc(parsed);
      } catch (err) {
        setParseError(`JSON parse error: ${err.message}`);
      }
    },
    []
  );

  const setLink = useCallback(
    (key, value) => {
      setDoc((prev) => {
        const next = {
          ...prev,
          links: { ...(prev.links || {}), [key]: value },
        };
        setRaw(JSON.stringify(next, null, 2));
        setParseError(null);
        return next;
      });
    },
    []
  );

  const links = doc?.links || {};

  return (
    <div>
      <h1>Wizard (M1 stub)</h1>
      <p>
        Form controls and the raw JSON editor share one schema v1 document.
        Saves that fail AJV must not publish (publish wiring comes later).
      </p>

      <section className="card">
        <h2>Links</h2>
        <p>
          Writes to <code>links.hostToolsDirect</code>, <code>links.airbnb</code>,{" "}
          <code>links.vrbo</code> per schema.
        </p>
        <label htmlFor="hostToolsDirect">Host Tools direct booking URL</label>
        <input
          id="hostToolsDirect"
          type="url"
          value={links.hostToolsDirect || ""}
          onChange={(e) => setLink("hostToolsDirect", e.target.value)}
          placeholder="https://"
        />
        <label htmlFor="airbnb">Airbnb URL</label>
        <input
          id="airbnb"
          type="url"
          value={links.airbnb || ""}
          onChange={(e) => setLink("airbnb", e.target.value)}
          placeholder="https://www.airbnb.com/rooms/…"
        />
        <label htmlFor="vrbo">Vrbo URL</label>
        <input
          id="vrbo"
          type="url"
          value={links.vrbo || ""}
          onChange={(e) => setLink("vrbo", e.target.value)}
          placeholder="https://www.vrbo.com/…"
        />
      </section>

      <section className="card">
        <h2>Raw JSON editor</h2>
        <p>Live AJV validation against <code>hostkit.v1.schema.json</code>.</p>
        <textarea
          aria-label="Raw JSON document"
          value={raw}
          onChange={(e) => applyRaw(e.target.value)}
          spellCheck={false}
        />
        {validation.ok ? (
          <p className="ok">Valid against schema v1.</p>
        ) : (
          <div className="errors">
            <strong>Validation errors:</strong>
            {"\n"}
            {validation.errors.join("\n")}
          </div>
        )}
      </section>
    </div>
  );
}
