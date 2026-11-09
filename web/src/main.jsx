import React from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter, Routes, Route, Link, useParams } from "react-router-dom";
import { MarketingPage } from "./MarketingPage.jsx";
import { WizardPage } from "./WizardPage.jsx";
import { applyPreviewPathNormalization } from "./lib/pathNormalize.js";
import "./styles.css";

// Direct-upload Pages does not always honor _redirects. Missing paths may
// be served as the root index.html while keeping the original URL. If that
// root copy is the SPA, stay put; if the URL is outside the preview base,
// send the visitor there.
if (typeof window !== "undefined") {
  const path = window.location.pathname;
  if (path === "/" || !path.startsWith("/hostkit-preview")) {
    const next = path === "/" || path === "/index.html"
      ? "/hostkit-preview/"
      : "/hostkit-preview" + (path.startsWith("/") ? path : "/" + path);
    if (next !== path) {
      window.location.replace(next + window.location.search + window.location.hash);
    }
  } else {
    applyPreviewPathNormalization();
  }
}

function PairRedirect() {
  const { code } = useParams();
  return <WizardPage initialCode={code} />;
}

function App() {
  return (
    <BrowserRouter basename="/hostkit-preview">
      <header className="top">
        <Link to="/" className="brand">
          HostKit preview
        </Link>
        <nav>
          <Link to="/">Marketing</Link>
          <Link to="/wizard">Wizard</Link>
        </nav>
      </header>
      <main>
        <Routes>
          <Route path="/" element={<MarketingPage />} />
          <Route path="/wizard/*" element={<WizardPage />} />
          <Route path="/setup/*" element={<WizardPage />} />
          <Route path="/pair/:code" element={<PairRedirect />} />
        </Routes>
      </main>
    </BrowserRouter>
  );
}

createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
