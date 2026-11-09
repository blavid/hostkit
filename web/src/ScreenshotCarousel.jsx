import { useCallback, useId, useState } from "react";

const BASE = `${import.meta.env.BASE_URL}screenshots`;

function pictureSrc(id, width, ext) {
  return `${BASE}/${id}-${width}.${ext}`;
}

/** Real 1920×1080 Roku captures, resized only — no mocked or edited screens. */
export const TV_SHOTS = [
  {
    id: "intro-1",
    alt: "Unpaired Roku intro, first of three: HostKit title, a three-line pitch about a guest guide on the TV in a short-term rental, the first of three progress dots filled, and the hint Press OK to continue, over a dusk mountain.",
    caption: "Before pairing: HostKit introduces the guest guide.",
  },
  {
    id: "intro-2",
    alt: "Unpaired Roku intro, second of three: the heading Set up once, copy about pairing with a short code and updating the guide from the web, the second progress dot filled, and Press OK to continue.",
    caption: "Set up once: a short code on the TV, then edit the guide from the web.",
  },
  {
    id: "intro-3",
    alt: "Unpaired Roku intro, third of three: the heading Ready to pair, copy to open the link or scan the QR on the next screen with the code already filled in, the third progress dot filled, and the hint Press OK to get your code.",
    caption: "Ready to pair: the next screen shows a code, a link, and a QR.",
  },
  {
    id: "pairing-preview",
    alt: "Roku pairing screen: Connect this TV, a large gold six-character code in two groups of three, a preview pair URL wrapped onto two lines, a Scan to pair QR, the status Waiting for the host to finish setup, and This code is valid for 15 minutes.",
    caption: "Pairing on the preview Worker: enter the code, open both lines of the URL, or scan the QR.",
  },
  {
    id: "home-configured",
    alt: "Roku guest Home after a successful pair: Welcome to Eaglewood 19, a left rail with Home, Wi-Fi, Things to Do, House Rules, Quick Fixes, Book Direct, and Checkout, a Book your next stay direct prompt, labeled tiles, and a Book Direct badge with a QR for the public property site.",
    caption: "After the host claims the TV, guests land on the property Home.",
  },
];

export function ScreenshotCarousel({ shots = TV_SHOTS } = {}) {
  const labelId = useId();
  const [index, setIndex] = useState(0);
  const last = shots.length - 1;
  const slide = shots[index];

  const go = useCallback(
    (next) => {
      setIndex((i) => (next < 0 ? last : next > last ? 0 : next));
    },
    [last],
  );

  function onKeyDown(event) {
    if (event.key === "ArrowLeft") {
      event.preventDefault();
      go(index - 1);
    } else if (event.key === "ArrowRight") {
      event.preventDefault();
      go(index + 1);
    } else if (event.key === "Home") {
      event.preventDefault();
      go(0);
    } else if (event.key === "End") {
      event.preventDefault();
      go(last);
    }
  }

  return (
    <div
      className="carousel"
      role="region"
      aria-roledescription="carousel"
      aria-labelledby={labelId}
      onKeyDown={onKeyDown}
    >
      <div className="carousel-toolbar">
        <p id={labelId} className="carousel-status">
          Screenshot {index + 1} of {shots.length}
        </p>
        <div className="carousel-controls">
          <button type="button" onClick={() => go(index - 1)} aria-label="Previous screenshot">
            Previous
          </button>
          <button type="button" onClick={() => go(index + 1)} aria-label="Next screenshot">
            Next
          </button>
        </div>
      </div>

      <figure className="carousel-frame">
        <Picture shot={slide} />
        <figcaption className="carousel-caption" aria-live="polite">
          {slide.caption}
        </figcaption>
      </figure>

      <div className="carousel-dots" role="tablist" aria-label="Choose a screenshot">
        {shots.map((shot, i) => (
          <button
            key={shot.id}
            type="button"
            role="tab"
            aria-selected={i === index}
            aria-label={`${shot.caption} (${i + 1} of ${shots.length})`}
            className={i === index ? "active" : ""}
            onClick={() => go(i)}
          />
        ))}
      </div>
    </div>
  );
}

function Picture({ shot }) {
  return (
    <picture>
      <source
        type="image/avif"
        srcSet={`${pictureSrc(shot.id, 960, "avif")} 960w, ${pictureSrc(shot.id, 1920, "avif")} 1920w`}
        sizes="(max-width: 960px) 100vw, 896px"
      />
      <source
        type="image/webp"
        srcSet={`${pictureSrc(shot.id, 960, "webp")} 960w, ${pictureSrc(shot.id, 1920, "webp")} 1920w`}
        sizes="(max-width: 960px) 100vw, 896px"
      />
      <img
        src={pictureSrc(shot.id, 960, "jpg")}
        srcSet={`${pictureSrc(shot.id, 960, "jpg")} 960w, ${pictureSrc(shot.id, 1920, "jpg")} 1920w`}
        sizes="(max-width: 960px) 100vw, 896px"
        width={1920}
        height={1080}
        alt={shot.alt}
        decoding="async"
      />
    </picture>
  );
}
