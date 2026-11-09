import React, { useMemo, useState, useCallback, useEffect } from "react";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import schema from "./hostkit.v1.schema.json";
import starter from "./starter-document.json";
import { flattenFaqsForTv, faqExceedsTvDepth } from "./lib/faqFlatten.js";
import { dedupeActivitiesById } from "./lib/activityDedupe.js";
import { checkBrandingContrast } from "./lib/contrast.js";
import { lintDocumentForHtml } from "./lib/htmlLint.js";
import { MockPaymentProvider } from "./lib/MockPaymentProvider.js";

function buildValidator() {
  const ajv = new Ajv2020({ allErrors: true, strict: false });
  addFormats(ajv);
  return ajv.compile(schema);
}

const payments = new MockPaymentProvider();

export function WizardPage() {
  const validate = useMemo(() => buildValidator(), []);
  const [doc, setDoc] = useState(() => structuredClone(starter));
  const [raw, setRaw] = useState(() => JSON.stringify(starter, null, 2));
  const [parseError, setParseError] = useState(null);
  const [billing, setBilling] = useState(null);
  const [billingMsg, setBillingMsg] = useState("");

  const syncFromDoc = useCallback((next) => {
    setDoc(next);
    setRaw(JSON.stringify(next, null, 2));
    setParseError(null);
  }, []);

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

  const faqPreview = useMemo(
    () => flattenFaqsForTv(doc?.faqs || [], 2),
    [doc?.faqs]
  );
  const faqDeep = useMemo(
    () => faqExceedsTvDepth(doc?.faqs || [], 2),
    [doc?.faqs]
  );
  const activityInfo = useMemo(
    () => dedupeActivitiesById(doc?.activities || []),
    [doc?.activities]
  );
  const contrast = useMemo(
    () => checkBrandingContrast(doc?.branding || {}),
    [doc?.branding]
  );
  const htmlLint = useMemo(() => lintDocumentForHtml(doc || {}), [doc]);

  const applyRaw = useCallback((text) => {
    setRaw(text);
    try {
      const parsed = JSON.parse(text);
      setParseError(null);
      setDoc(parsed);
    } catch (err) {
      setParseError(`JSON parse error: ${err.message}`);
    }
  }, []);

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

  const updateFaqJson = useCallback(
    (text) => {
      try {
        const faqs = JSON.parse(text);
        syncFromDoc({ ...doc, faqs });
      } catch (err) {
        setParseError(`FAQ JSON: ${err.message}`);
      }
    },
    [doc, syncFromDoc]
  );

  const updateActivitiesJson = useCallback(
    (text) => {
      try {
        const parsed = JSON.parse(text);
        const { activities } = dedupeActivitiesById(parsed);
        syncFromDoc({ ...doc, activities });
      } catch (err) {
        setParseError(`Activities JSON: ${err.message}`);
      }
    },
    [doc, syncFromDoc]
  );

  const setBrandColor = useCallback(
    (key, value) => {
      const next = {
        ...doc,
        branding: {
          ...(doc.branding || {}),
          colors: { ...(doc.branding?.colors || {}), [key]: value },
        },
      };
      syncFromDoc(next);
    },
    [doc, syncFromDoc]
  );

  const applyDedupe = useCallback(() => {
    syncFromDoc({ ...doc, activities: activityInfo.activities });
  }, [doc, activityInfo.activities, syncFromDoc]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        let status;
        try {
          status = await payments.getStatus("preview-host");
        } catch {
          status = await payments.startTrial("preview-host", 30);
        }
        if (!cancelled) setBilling(status);
      } catch (err) {
        if (!cancelled) setBillingMsg(String(err.message || err));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const runBilling = async (action, plan) => {
    try {
      let status;
      if (action === "trial") status = await payments.startTrial("preview-host", 30);
      else if (action === "subscribe")
        status = await payments.subscribe("preview-host", plan);
      else if (action === "cancel") status = await payments.cancel("preview-host");
      else status = await payments.getStatus("preview-host");
      setBilling(status);
      const coarse = payments.toSchemaSubscription(status);
      syncFromDoc({ ...doc, subscription: coarse });
      setBillingMsg("");
    } catch (err) {
      setBillingMsg(String(err.message || err));
    }
  };

  const links = doc?.links || {};
  const colors = doc?.branding?.colors || {};
  const publishBlocked =
    !validation.ok || !contrast.ok || !htmlLint.ok || faqDeep;

  return (
    <div>
      <h1>Wizard (M4 ahead)</h1>
      <p>
        Form controls and the raw JSON editor share one schema v1 document.
        Saves that fail AJV, HTML lint, or contrast checks must not publish.
      </p>

      <section className="card">
        <h2>Links</h2>
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
        <h2>FAQ editor</h2>
        <p>
          Recursive categories. TV shows at most 2 levels — deeper nests flatten
          into the parent (preview below).
        </p>
        {faqDeep && (
          <p className="warn">
            Warning: FAQ depth exceeds 2. TV preview flattens deeper levels.
          </p>
        )}
        <textarea
          aria-label="FAQ JSON"
          value={JSON.stringify(doc?.faqs || [], null, 2)}
          onChange={(e) => updateFaqJson(e.target.value)}
          spellCheck={false}
        />
        <h3>TV preview (flattened ≤2)</h3>
        {faqPreview.warnings.length > 0 && (
          <div className="warn">
            {faqPreview.warnings.map((w) => (
              <div key={w}>{w}</div>
            ))}
          </div>
        )}
        <pre className="preview" aria-label="FAQ TV preview">
          {JSON.stringify(faqPreview.preview, null, 2)}
        </pre>
      </section>

      <section className="card">
        <h2>Activities editor</h2>
        <p>Cards dedupe by <code>id</code> (first wins).</p>
        {activityInfo.duplicates.length > 0 && (
          <p className="warn">
            Duplicate ids (will be dropped on apply):{" "}
            {activityInfo.duplicates.join(", ")}
            {" "}
            <button type="button" onClick={applyDedupe}>
              Apply dedupe
            </button>
          </p>
        )}
        <textarea
          aria-label="Activities JSON"
          value={JSON.stringify(doc?.activities || [], null, 2)}
          onChange={(e) => updateActivitiesJson(e.target.value)}
          spellCheck={false}
        />
      </section>

      <section className="card">
        <h2>Branding contrast (4.5:1)</h2>
        <label htmlFor="bg">Background</label>
        <input
          id="bg"
          type="text"
          value={colors.background || colors.bg || "#ffffff"}
          onChange={(e) => setBrandColor("background", e.target.value)}
        />
        <label htmlFor="textColor">Text</label>
        <input
          id="textColor"
          type="text"
          value={colors.text || colors.primary || ""}
          onChange={(e) => setBrandColor("text", e.target.value)}
        />
        <label htmlFor="accent">Accent</label>
        <input
          id="accent"
          type="text"
          value={colors.accent || ""}
          onChange={(e) => setBrandColor("accent", e.target.value)}
        />
        {contrast.ok ? (
          <p className="ok">Contrast checks passed (≥ 4.5:1).</p>
        ) : (
          <div className="errors">
            {contrast.issues.map((i) => (
              <div key={i.pair}>
                {i.pair}: {i.error || `${i.ratio}:1 (need ${i.required}:1)`}
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="card">
        <h2>HTML rejection linter</h2>
        {htmlLint.ok ? (
          <p className="ok">No HTML detected in document text fields.</p>
        ) : (
          <div className="errors">
            {htmlLint.findings.map((f) => (
              <div key={f.path}>
                {f.path}: {f.snippet}
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="card">
        <h2>Mock billing (trial)</h2>
        <p>MockPaymentProvider only — no charges, no cards, no SDK.</p>
        {billing && (
          <pre className="preview" aria-label="Billing status">
            {JSON.stringify(payments.toSchemaSubscription(billing), null, 2)}
          </pre>
        )}
        {billingMsg && <p className="errors">{billingMsg}</p>}
        <div className="row">
          <button type="button" onClick={() => runBilling("trial")}>
            Start 30-day trial
          </button>
          <button type="button" onClick={() => runBilling("subscribe", "monthly")}>
            Subscribe monthly
          </button>
          <button type="button" onClick={() => runBilling("subscribe", "annual")}>
            Subscribe annual
          </button>
          <button type="button" onClick={() => runBilling("cancel")}>
            Cancel → grace
          </button>
        </div>
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
        {publishBlocked ? (
          <p className="warn">Publish blocked until schema, HTML, contrast, and FAQ depth are clean.</p>
        ) : (
          <p className="ok">Ready to publish (publish wiring comes with Worker claim).</p>
        )}
      </section>
    </div>
  );
}
