import React from "react";
import { Link } from "react-router-dom";

export function MarketingPage() {
  return (
    <div>
      <h1>HostKit preview</h1>
      <p>
        TV guest guide + host wizard for short-term rentals. This staging path
        is hidden (<code>noindex</code>) and must not touch the live Eaglewood
        site or <code>/tv</code>.
      </p>
      <div className="card">
        <h2>Product pitch (placeholder)</h2>
        <ul>
          <li>Pair a Roku with a 6-character code + QR</li>
          <li>One JSON document drives the TV and the wizard</li>
          <li>Wi-Fi and door codes stay as placeholders in git</li>
        </ul>
        <p>
          <Link to="/wizard">Open the wizard stub →</Link>
        </p>
      </div>
      <div className="card todo">
        <strong>TODO (M2+):</strong> Screenshot carousel must use{" "}
        <em>real Roku emulator captures</em> after M2 (pairing, Home, FAQs, For
        You, Book Direct, Wi-Fi, plus wizard frames). No fake screenshots in
        this stub.
      </div>
      <div className="card">
        <h2>Pricing teaser (mock)</h2>
        <p>
          30-day trial · monthly · annual — amounts are placeholders until Blake
          sets prices. No real charges in preview.
        </p>
      </div>
    </div>
  );
}
