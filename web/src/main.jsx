import React from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter, Routes, Route, Link, useParams } from "react-router-dom";
import { WizardPage } from "./WizardPage.jsx";
import { applyPreviewPathNormalization, legacyPreviewPath } from "./lib/pathNormalize.js";
import "./styles.css";

// The app used to live under /hostkit-preview/. Old links (and the TV
// short link on older Worker settings) still arrive there, so strip the
// prefix and keep the query and hash. _redirects does the same at the edge.
if (typeof window !== "undefined") {
  const legacy = legacyPreviewPath(window.location.pathname);
  if (legacy !== null) {
    window.location.replace(legacy + window.location.search + window.location.hash);
  } else {
    applyPreviewPathNormalization();
  }
}

function PairRedirect() {
  const { code } = useParams();
  return <WizardPage initialCode={code} />;
}

// / is the static sales site. If the SPA ever renders its root route
// (client-side nav or a stray shell), hand off to it.
function SalesHome() {
  React.useEffect(() => {
    window.location.replace("/" + window.location.search + window.location.hash);
  }, []);
  return null;
}

function App() {
  return (
    <BrowserRouter>
      <header className="top">
        <a href="/" className="brand">
          HostKit preview
        </a>
        <nav>
          <a href="/">Home</a>
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
