import React from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter, Routes, Route, Link } from "react-router-dom";
import { MarketingPage } from "./MarketingPage.jsx";
import { WizardPage } from "./WizardPage.jsx";
import "./styles.css";

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
          <Route path="/wizard" element={<WizardPage />} />
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
