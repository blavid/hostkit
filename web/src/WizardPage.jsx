import React, { useMemo, useState, useCallback, useEffect } from "react";
import { useSearchParams } from "react-router-dom";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import schema from "./hostkit.v1.schema.json";
import starter from "./starter-document.json";
import { flattenFaqsForTv, faqExceedsTvDepth } from "./lib/faqFlatten.js";
import { dedupeActivitiesById } from "./lib/activityDedupe.js";
import { checkBrandingContrast } from "./lib/contrast.js";
import { lintDocumentForHtml } from "./lib/htmlLint.js";
import { MockPaymentProvider } from "./lib/MockPaymentProvider.js";
import { FaqEditor } from "./wizard/FaqEditor.jsx";
import {
  isValidPairCode,
  normalizePairCode,
  codeFromLocation,
} from "./lib/pairingCode.js";
import {
  CONSENT_TEXT,
  prepareImportReview,
  acceptedSentences,
  draftFromAccepted,
} from "./lib/listingImport.js";
import {
  documentKeepsPlaceholders,
  lintDocumentForRawSecrets,
  sanitizePrivatePayload,
  PRIVATE_KEYS,
} from "./lib/privateValues.js";
import {
  curatedActivities,
  officialLinkTemplates,
  addActivities,
  makeOfficialLinkCard,
} from "./lib/activityLibrary.js";
import { loadApiConfig, TV_SERVICE_NOT_LIVE } from "./lib/apiConfig.js";
import {
  createHostApi,
  loadStoredSession,
  storeSession,
} from "./lib/hostApi.js";

function buildValidator() {
  const ajv = new Ajv2020({ allErrors: true, strict: false });
  addFormats(ajv);
  return ajv.compile(schema);
}

const payments = new MockPaymentProvider();

const STEPS = [
  { id: "account", label: "Account" },
  { id: "property", label: "Property" },
  { id: "links", label: "Links" },
  { id: "import", label: "Import" },
  { id: "faq", label: "FAQ" },
  { id: "activities", label: "Activities" },
  { id: "branding", label: "Branding" },
  { id: "private", label: "Private values" },
  { id: "pairing", label: "Pairing" },
  { id: "editors", label: "Editors" },
  { id: "publish", label: "Publish" },
];

export function WizardPage({ initialCode = "" }) {
  const [params] = useSearchParams();
  const validate = useMemo(() => buildValidator(), []);
  const [step, setStep] = useState(0);
  const [doc, setDoc] = useState(() => structuredClone(starter));
  const [raw, setRaw] = useState(() => JSON.stringify(starter, null, 2));
  const [parseError, setParseError] = useState(null);
  const [billing, setBilling] = useState(null);
  const [billingMsg, setBillingMsg] = useState("");
  const [session, setSession] = useState(() => loadStoredSession());
  const [apiConfig, setApiConfig] = useState({ apiBase: "" });
  const [apiNotice, setApiNotice] = useState(TV_SERVICE_NOT_LIVE);
  const [consent, setConsent] = useState(false);
  const [importText, setImportText] = useState("");
  const [importFileName, setImportFileName] = useState("");
  const [importReview, setImportReview] = useState(null);
  const [importError, setImportError] = useState("");
  const [privateValues, setPrivateValues] = useState({
    WIFI_SSID: "",
    WIFI_PASSWORD: "",
    HOST_PHONE: "",
    DOOR_CODE: "",
  });
  const [pairCode, setPairCode] = useState(() =>
    normalizePairCode(
      initialCode ||
        codeFromLocation(window.location.search, window.location.pathname) ||
        params.get("code") ||
        ""
    )
  );
  const [devices, setDevices] = useState([]);
  const [pairMsg, setPairMsg] = useState("");
  const [publishMsg, setPublishMsg] = useState("");
  const [publishResult, setPublishResult] = useState(null);
  const [confirmedIds, setConfirmedIds] = useState([]);
  const [officialUrl, setOfficialUrl] = useState("");
  const [officialKind, setOfficialKind] = useState("viator");

  const api = useMemo(
    () =>
      createHostApi({
        apiBase: apiConfig.apiBase,
        getToken: () => loadStoredSession()?.token || session?.token || "",
      }),
    [apiConfig.apiBase, session]
  );

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const cfg = await loadApiConfig();
      if (cancelled) return;
      setApiConfig(cfg);
      setApiNotice(cfg.apiBase ? "" : TV_SERVICE_NOT_LIVE);
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    const fromQuery = normalizePairCode(params.get("code") || initialCode || "");
    if (fromQuery && !pairCode) setPairCode(fromQuery);
  }, [params, initialCode, pairCode]);

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
      errors: (validate.errors || []).map((e) => `${e.instancePath || "/"} ${e.message}`),
    };
  }, [doc, parseError, validate]);

  const faqPreview = useMemo(() => flattenFaqsForTv(doc?.faqs || [], 2), [doc?.faqs]);
  const faqDeep = useMemo(() => faqExceedsTvDepth(doc?.faqs || [], 2), [doc?.faqs]);
  const activityInfo = useMemo(
    () => dedupeActivitiesById(doc?.activities || []),
    [doc?.activities]
  );
  const contrast = useMemo(
    () => checkBrandingContrast(doc?.branding || {}),
    [doc?.branding]
  );
  const htmlLint = useMemo(() => lintDocumentForHtml(doc || {}), [doc]);
  const secretLint = useMemo(() => lintDocumentForRawSecrets(doc || {}), [doc]);
  const placeholders = useMemo(() => documentKeepsPlaceholders(doc || {}), [doc]);

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

  const setProperty = (key, value) => {
    syncFromDoc({ ...doc, property: { ...(doc.property || {}), [key]: value } });
  };
  const setStats = (key, value) => {
    const stats = { ...(doc.property?.stats || {}), [key]: value };
    setProperty("stats", stats);
  };
  const setLink = (key, value) => {
    syncFromDoc({ ...doc, links: { ...(doc.links || {}), [key]: value } });
  };
  const setBrandColor = (key, value) => {
    syncFromDoc({
      ...doc,
      branding: {
        ...(doc.branding || {}),
        colors: { ...(doc.branding?.colors || {}), [key]: value },
      },
    });
  };

  const hostId = session?.hostId || "preview-host";

  const startTrial = async () => {
    try {
      let nextSession = session;
      if (api.live) {
        try {
          const signed = await api.signup();
          nextSession = {
            token: signed.token,
            hostId: signed.hostId,
            propertyId: signed.propertyId,
            expiresAt: signed.expiresAt,
          };
          storeSession(nextSession);
          setSession(nextSession);
          if (signed.propertyId) {
            syncFromDoc({
              ...doc,
              property: { ...doc.property, id: signed.propertyId },
            });
          }
          setApiNotice("");
        } catch (err) {
          if (err.code === "not_live") setApiNotice(TV_SERVICE_NOT_LIVE);
          else setBillingMsg(String(err.message || err));
        }
      } else {
        setApiNotice(TV_SERVICE_NOT_LIVE);
      }
      const status = await payments.startTrial(nextSession?.hostId || hostId, 30);
      setBilling(status);
      syncFromDoc({
        ...doc,
        property: {
          ...doc.property,
          id: nextSession?.propertyId || doc.property.id,
        },
        subscription: payments.toSchemaSubscription(status),
      });
      setBillingMsg("");
    } catch (err) {
      setBillingMsg(String(err.message || err));
    }
  };

  const runBilling = async (action, plan) => {
    try {
      const id = session?.hostId || hostId;
      let status;
      if (action === "trial") return startTrial();
      if (action === "subscribe") status = await payments.subscribe(id, plan);
      else if (action === "cancel") status = await payments.cancel(id);
      else status = await payments.getStatus(id);
      setBilling(status);
      syncFromDoc({ ...doc, subscription: payments.toSchemaSubscription(status) });
      setBillingMsg("");
    } catch (err) {
      setBillingMsg(String(err.message || err));
    }
  };

  const runImport = () => {
    const review = prepareImportReview({
      sourceText: importText,
      consent,
      filename: importFileName,
    });
    if (!review.ok) {
      setImportError(review.error);
      setImportReview(null);
      return;
    }
    setImportError("");
    setImportReview(review);
  };

  const saveAcceptedImport = () => {
    const accepted = acceptedSentences(importReview);
    const draft = draftFromAccepted(accepted);
    const faqs = [...(doc.faqs || [])];
    const existing = faqs.findIndex((c) => c.id === "imported-listing");
    if (existing >= 0) faqs[existing] = draft.faqCategory;
    else faqs.push(draft.faqCategory);
    syncFromDoc({ ...doc, faqs });
  };

  const addLibraryCards = (cards) => {
    const { activities, rejected } = addActivities(doc.activities || [], cards, {
      confirmedIds,
    });
    syncFromDoc({ ...doc, activities });
    return rejected;
  };

  const claimTv = async () => {
    const code = normalizePairCode(pairCode);
    if (!isValidPairCode(code)) {
      setPairMsg("Enter a valid 6-character code (no 0, O, 1, I, or L).");
      return;
    }
    if (!api.live) {
      setPairMsg(TV_SERVICE_NOT_LIVE);
      return;
    }
    try {
      const result = await api.claim(code, doc.property.id);
      setPairMsg(`Paired device ${result.deviceId || ""}`.trim());
      const listed = await api.listDevices().catch(() => ({ devices: [] }));
      setDevices(listed.devices || []);
    } catch (err) {
      setPairMsg(err.code === "not_live" ? TV_SERVICE_NOT_LIVE : String(err.message || err));
    }
  };

  const revokeDevice = async (deviceId) => {
    if (!api.live) {
      setPairMsg(TV_SERVICE_NOT_LIVE);
      return;
    }
    try {
      await api.revoke({ deviceId });
      const listed = await api.listDevices().catch(() => ({ devices: [] }));
      setDevices(listed.devices || []);
      setPairMsg("Device revoked.");
    } catch (err) {
      setPairMsg(String(err.message || err));
    }
  };

  const publish = async () => {
    setPublishResult(null);
    if (publishBlocked) {
      setPublishMsg("Fix validation, contrast, HTML, secrets, or placeholders first.");
      return;
    }
    if (!api.live) {
      setPublishMsg(TV_SERVICE_NOT_LIVE);
      return;
    }
    try {
      const values = sanitizePrivatePayload(privateValues);
      if (Object.keys(values).length) {
        await api.putPrivate(doc.property.id, values);
      }
      const result = await api.putConfig(doc);
      setPublishResult(result);
      setPublishMsg("Published. A paired TV can now GET /v1/config.");
    } catch (err) {
      setPublishMsg(err.code === "not_live" ? TV_SERVICE_NOT_LIVE : String(err.message || err));
    }
  };

  const publishBlocked =
    !validation.ok ||
    !contrast.ok ||
    !htmlLint.ok ||
    !secretLint.ok ||
    !placeholders.ok ||
    faqDeep;

  const links = doc?.links || {};
  const colors = doc?.branding?.colors || {};
  const property = doc?.property || {};

  return (
    <div>
      <h1>Host setup wizard</h1>
      <p>
        Twelve steps from a mock trial to a published config a paired TV can
        consume. Form controls and the raw JSON editor share one schema v1
        document.
      </p>
      {apiNotice && <p className="notice">{apiNotice}</p>}

      <div className="stepper" role="tablist" aria-label="Wizard steps">
        {STEPS.map((s, i) => (
          <button
            key={s.id}
            type="button"
            className={`${i === step ? "active" : ""} ${i < step ? "done" : ""}`}
            onClick={() => setStep(i)}
          >
            {i + 1}. {s.label}
          </button>
        ))}
      </div>

      {step === 0 && (
        <section className="card">
          <h2>Account and mock trial</h2>
          <p>
            Start a 30-day trial to explore the wizard. No payment is required.
            At the end of the trial, pick monthly or annual. MockPaymentProvider
            only — no card fields, no processor.
          </p>
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
          {session && (
            <p className="ok">
              Host session saved in this browser ({session.hostId}).
            </p>
          )}
        </section>
      )}

      {step === 1 && (
        <section className="card">
          <h2>Property basics</h2>
          <label>Name</label>
          <input type="text" value={property.name || ""} onChange={(e) => setProperty("name", e.target.value)} />
          <label>Display address</label>
          <input type="text" value={property.address || ""} onChange={(e) => setProperty("address", e.target.value)} />
          <label>Timezone</label>
          <input type="text" value={property.timezone || "America/Los_Angeles"} onChange={(e) => setProperty("timezone", e.target.value)} />
          <label>Check-in</label>
          <input type="text" value={property.checkIn || ""} onChange={(e) => setProperty("checkIn", e.target.value)} />
          <label>Check-out</label>
          <input type="text" value={property.checkOut || ""} onChange={(e) => setProperty("checkOut", e.target.value)} />
          <label>Guests</label>
          <input type="number" value={property.stats?.guests ?? 0} onChange={(e) => setStats("guests", Number(e.target.value))} />
          <label>Bedrooms</label>
          <input type="number" value={property.stats?.bedrooms ?? 0} onChange={(e) => setStats("bedrooms", Number(e.target.value))} />
          <label>Bathrooms</label>
          <input type="number" value={property.stats?.bathrooms ?? 0} onChange={(e) => setStats("bathrooms", Number(e.target.value))} />
          <label>Hero photo URL</label>
          <input
            type="url"
            value={property.images?.[0]?.url || ""}
            onChange={(e) =>
              setProperty("images", [
                { ...(property.images?.[0] || {}), url: e.target.value, role: "hero" },
              ])
            }
          />
        </section>
      )}

      {step === 2 && (
        <section className="card">
          <h2>Links</h2>
          <label htmlFor="hostToolsDirect">Host Tools direct booking URL</label>
          <input id="hostToolsDirect" type="url" value={links.hostToolsDirect || ""} onChange={(e) => setLink("hostToolsDirect", e.target.value)} />
          <label htmlFor="airbnb">Airbnb URL</label>
          <input id="airbnb" type="url" value={links.airbnb || ""} onChange={(e) => setLink("airbnb", e.target.value)} />
          <label htmlFor="vrbo">Vrbo URL</label>
          <input id="vrbo" type="url" value={links.vrbo || ""} onChange={(e) => setLink("vrbo", e.target.value)} />
          <label htmlFor="website">Website (optional)</label>
          <input id="website" type="url" value={links.website || ""} onChange={(e) => setLink("website", e.target.value)} />
        </section>
      )}

      {step === 3 && (
        <section className="card">
          <h2>Import listing copy</h2>
          <p>
            Paste your own listing text, or upload an official export (JSON or
            CSV) you downloaded yourself. HostKit does not fetch or scrape
            Airbnb, Vrbo, or Host Tools pages. Review every sentence before it
            is saved.
          </p>
          <label>
            <input type="checkbox" checked={consent} onChange={(e) => setConsent(e.target.checked)} />{" "}
            {CONSENT_TEXT}
          </label>
          <label>Paste text</label>
          <textarea className="short" value={importText} onChange={(e) => setImportText(e.target.value)} />
          <label>Official export file</label>
          <input
            type="file"
            accept=".json,.csv,text/csv,application/json,text/plain"
            onChange={async (e) => {
              const file = e.target.files?.[0];
              if (!file) return;
              setImportFileName(file.name);
              setImportText(await file.text());
            }}
          />
          <div className="row">
            <button type="button" onClick={runImport}>
              Prepare review
            </button>
          </div>
          {importError && <p className="errors">{importError}</p>}
          {importReview && (
            <div>
              <h3>Review imported sentences</h3>
              {importReview.sentences.map((s, i) => (
                <label className="sentence" key={s.id}>
                  <input
                    type="checkbox"
                    checked={s.accepted}
                    onChange={(e) => {
                      const next = {
                        ...importReview,
                        sentences: importReview.sentences.map((row, idx) =>
                          idx === i ? { ...row, accepted: e.target.checked } : row
                        ),
                      };
                      setImportReview(next);
                    }}
                  />
                  <span>{s.text}</span>
                </label>
              ))}
              <button type="button" onClick={saveAcceptedImport}>
                Save accepted sentences as FAQ starters
              </button>
            </div>
          )}
        </section>
      )}

      {step === 4 && (
        <section className="card">
          <h2>Hierarchical FAQ</h2>
          <p>Recursive categories and items. Warns when depth exceeds 2.</p>
          <FaqEditor
            faqs={doc.faqs || []}
            depthWarning={faqDeep}
            onChange={(faqs) => syncFromDoc({ ...doc, faqs })}
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
      )}

      {step === 5 && (
        <section className="card">
          <h2>Activities</h2>
          <p>
            Pick from the curated regional library (seeded from Eaglewood’s
            public activity cards). Viator and AllTrails are official-link or
            widget only — confirm the URL; nothing is scraped. Duplicates drop
            by id (first wins).
          </p>
          {activityInfo.duplicates.length > 0 && (
            <p className="warn">
              Duplicate ids: {activityInfo.duplicates.join(", ")}{" "}
              <button
                type="button"
                onClick={() => syncFromDoc({ ...doc, activities: activityInfo.activities })}
              >
                Apply dedupe
              </button>
            </p>
          )}
          <h3>Curated regional library</h3>
          <div className="library-grid">
            {curatedActivities().map((card) => (
              <div className="library-card" key={card.id}>
                <strong>{card.title}</strong>
                <div>{card.category}</div>
                {card.imageCredit && (
                  <div className="fineprint">
                    Photo: {card.imageCredit.author} ({card.imageCredit.license})
                  </div>
                )}
                {card.needsHostConfirm && (
                  <label>
                    <input
                      type="checkbox"
                      checked={confirmedIds.includes(card.id)}
                      onChange={(e) =>
                        setConfirmedIds((ids) =>
                          e.target.checked ? [...ids, card.id] : ids.filter((id) => id !== card.id)
                        )
                      }
                    />{" "}
                    I confirm this official {card.source} link
                  </label>
                )}
                <button type="button" onClick={() => addLibraryCards([card])}>
                  Add
                </button>
              </div>
            ))}
          </div>
          <h3>Official Viator or AllTrails link</h3>
          <label>
            Provider
            <select value={officialKind} onChange={(e) => setOfficialKind(e.target.value)}>
              <option value="viator">Viator</option>
              <option value="alltrails">AllTrails</option>
            </select>
          </label>
          <label>Official share URL or widget link</label>
          <input type="url" value={officialUrl} onChange={(e) => setOfficialUrl(e.target.value)} />
          <button
            type="button"
            onClick={() => {
              const template = officialLinkTemplates().find((t) => t.source === officialKind);
              const card = makeOfficialLinkCard(template, officialUrl);
              const ids = [...confirmedIds, card.id];
              setConfirmedIds(ids);
              const result = addActivities(doc.activities || [], [card], { confirmedIds: ids });
              syncFromDoc({ ...doc, activities: result.activities });
            }}
          >
            Add official link
          </button>
          <h3>Current activities</h3>
          <ul>
            {(doc.activities || []).map((a) => (
              <li key={a.id}>
                {a.title} ({a.id})
              </li>
            ))}
          </ul>
        </section>
      )}

      {step === 6 && (
        <section className="card">
          <h2>Branding (4.5:1 contrast)</h2>
          <label htmlFor="bg">Background</label>
          <input id="bg" type="text" value={colors.background || colors.bg || "#ffffff"} onChange={(e) => setBrandColor("background", e.target.value)} />
          <label htmlFor="textColor">Text</label>
          <input id="textColor" type="text" value={colors.text || colors.primary || ""} onChange={(e) => setBrandColor("text", e.target.value)} />
          <label htmlFor="accent">Accent</label>
          <input id="accent" type="text" value={colors.accent || ""} onChange={(e) => setBrandColor("accent", e.target.value)} />
          <label>Book Direct copy</label>
          <textarea
            className="short"
            value={doc.branding?.bookDirect?.body || doc.branding?.ad?.text || ""}
            onChange={(e) =>
              syncFromDoc({
                ...doc,
                branding: {
                  ...doc.branding,
                  ad: { ...(doc.branding?.ad || {}), text: e.target.value },
                  bookDirect: { ...(doc.branding?.bookDirect || {}), body: e.target.value },
                },
              })
            }
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
      )}

      {step === 7 && (
        <section className="card">
          <h2>Private values</h2>
          <p>
            Wi-Fi, door code, and phone are sent only to the Worker’s private
            endpoint. The document keeps placeholder tokens. The linter blocks
            raw values in the JSON.
          </p>
          {PRIVATE_KEYS.slice(0, 4).map((key) => {
            const hidden = /PASSWORD|CODE/.test(key);
            let inputType = "text";
            if (hidden) inputType = "password";
            return (
            <div key={key}>
              <label htmlFor={key}>{key}</label>
              <input
                id={key}
                type={inputType}
                autoComplete="off"
                value={privateValues[key] || ""}
                onChange={(e) => setPrivateValues({ ...privateValues, [key]: e.target.value })}
              />
            </div>
            );
          })}
          {placeholders.ok && secretLint.ok ? (
            <p className="ok">Document still uses placeholders only.</p>
          ) : (
            <div className="errors">
              {[...placeholders.issues, ...secretLint.findings].map((f, i) => (
                <div key={i}>{f.path}: {f.message || f.rule}</div>
              ))}
            </div>
          )}
        </section>
      )}

      {step === 8 && (
        <section className="card">
          <h2>Pair a TV</h2>
          <p>
            Enter the 6-character code from the TV. It is trimmed and uppercased.
            0, O, 1, I, and L are not used. The code is also read from{" "}
            <code>?code=</code> so a QR or short URL works.
          </p>
          <label htmlFor="pairCode">Pairing code</label>
          <input
            id="pairCode"
            type="text"
            value={pairCode}
            onChange={(e) => setPairCode(normalizePairCode(e.target.value))}
            maxLength={6}
            autoCapitalize="characters"
          />
          <div className="row">
            <button type="button" onClick={claimTv}>
              Claim code
            </button>
          </div>
          {pairMsg && <p className={pairMsg === TV_SERVICE_NOT_LIVE ? "notice" : "ok"}>{pairMsg}</p>}
          <h3>Devices</h3>
          {(devices || []).length === 0 ? (
            <p>No paired devices yet.</p>
          ) : (
            <ul>
              {devices.map((d) => (
                <li key={d.deviceId}>
                  {d.deviceId} {d.revoked ? "(revoked)" : ""}{" "}
                  {!d.revoked && (
                    <button type="button" onClick={() => revokeDevice(d.deviceId)}>
                      Revoke
                    </button>
                  )}
                </li>
              ))}
            </ul>
          )}
        </section>
      )}

      {step === 9 && (
        <section className="card">
          <h2>UI editor and raw JSON</h2>
          <p>The form and the raw editor stay in sync, with live Ajv validation.</p>
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
          {htmlLint.ok ? (
            <p className="ok">No HTML in text fields.</p>
          ) : (
            <div className="errors">
              {htmlLint.findings.map((f) => (
                <div key={f.path}>
                  {f.path}: {f.snippet}
                </div>
              ))}
            </div>
          )}
          {!secretLint.ok && (
            <div className="errors">Raw private values must stay out of the document.</div>
          )}
        </section>
      )}

      {step === 10 && (
        <section className="card">
          <h2>Preview and publish</h2>
          <div className="tv-frame" aria-label="TV-shaped preview">
            <h3>{property.name}</h3>
            <p>{property.tagline}</p>
            <p>
              {property.checkIn} check-in · {property.checkOut} check-out
            </p>
            <p>{(doc.activities || []).length} activities · {(doc.faqs || []).length} FAQ categories</p>
          </div>
          {publishBlocked ? (
            <p className="warn">
              Publish is blocked until schema, HTML, contrast, secrets, and FAQ
              depth are clean.
            </p>
          ) : (
            <p className="ok">Ready to publish a schema-valid document with placeholders.</p>
          )}
          <button type="button" onClick={publish} disabled={publishBlocked}>
            Publish to TV service
          </button>
          {publishMsg && (
            <p className={publishMsg === TV_SERVICE_NOT_LIVE ? "notice" : "ok"}>{publishMsg}</p>
          )}
          {publishResult && (
            <pre className="preview" aria-label="Publish result">
              {JSON.stringify(publishResult, null, 2)}
            </pre>
          )}
        </section>
      )}

      <div className="nav-row">
        <button type="button" disabled={step === 0} onClick={() => setStep((s) => Math.max(0, s - 1))}>
          Back
        </button>
        <button
          type="button"
          disabled={step === STEPS.length - 1}
          onClick={() => setStep((s) => Math.min(STEPS.length - 1, s + 1))}
        >
          Next
        </button>
      </div>
    </div>
  );
}
