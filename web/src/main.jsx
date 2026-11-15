import React from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter, Routes, Route, Link, useParams } from "react-router-dom";
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

// /hostkit-preview/ is now the static sales site. If the SPA ever renders
// its root route (client-side nav or a stray shell), hand off to it.
function SalesHome() {
  React.useEffect(() => {
    window.location.replace("/hostkit-preview/" + window.location.search + window.location.hash);
  }, []);
  return null;
}

function App() {
  return (
    <BrowserRouter basename="/hostkit-preview">
      <header className="top">
        <a href="/hostkit-preview/" className="brand">
          HostKit preview
        </a>
        <nav>
          <a href="/hostkit-preview/">Home</a>
          <Link to="/wizard">Wizard</Link>
        </nav>
      </header>
      <main>
        <Routes>
          <Route path="/" element={<SalesHome />} />
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
