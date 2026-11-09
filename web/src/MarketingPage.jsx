import React from "react";
import { Link } from "react-router-dom";
import { ScreenshotCarousel } from "./ScreenshotCarousel.jsx";

export function MarketingPage() {
  return (
    <div>
      <section className="hero">
        <p className="eyebrow">Hidden preview · noindex</p>
        <h1>A guest guide on the TV, set up in the browser.</h1>
        <p className="lede">
          HostKit turns one property document into a Roku guest guide: house
          FAQs, things to do, Book Direct, and Wi-Fi — without putting door
          codes or passwords in git. This staging path is unlisted and does
          not touch the live Eaglewood site or <code>/tv</code>.
        </p>
        <p>
          <Link className="cta" to="/wizard">
            Start a 30-day mock trial
          </Link>
        </p>
      </section>

      <div className="card">
        <h2>What hosts get</h2>
        <ul className="features">
          <li>Pair a Roku with a 6-character code. The QR and short URL already fill it in.</li>
          <li>Nested FAQs with a flattened TV preview, plus activities with an optional signup QR.</li>
          <li>Book Direct, Airbnb, and Vrbo links in one place.</li>
          <li>Wi-Fi, door codes, and the host phone stay in a private panel — the document keeps placeholders.</li>
        </ul>
      </div>

      <div className="card">
        <h2>On the TV</h2>
        <p>
          These are resizes of real 1920×1080 Roku captures from the
          M4 preview run — the three intro screens, a live preview pairing
          screen, and the guest Home after the host claims the TV. Local test
          pairing shots were left out because they printed a loopback address.
        </p>
        <ScreenshotCarousel />
      </div>

      <div className="card">
        <h2>Pricing (mock)</h2>
        <p className="fineprint">
          Amounts are placeholders until prices are set. Preview billing is a
          mock 30-day trial — no charges, no cards, no payment processor.
        </p>
        <div className="plans">
          <div className="plan">
            <h3>Trial</h3>
            <p className="price">30 days</p>
            <p>Explore the wizard and publish to a preview TV.</p>
          </div>
          <div className="plan">
            <h3>Monthly</h3>
            <p className="price">$TBD / month</p>
            <p>After the trial, stay month to month.</p>
          </div>
          <div className="plan">
            <h3>Annual</h3>
            <p className="price">$TBD / year</p>
            <p>Same product, billed once a year.</p>
          </div>
        </div>
        <p>
          <Link to="/wizard">Open the wizard →</Link>
        </p>
      </div>
    </div>
  );
}
