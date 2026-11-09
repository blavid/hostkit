/**
 * Relative luminance and WCAG contrast ratio helpers.
 * Body text must meet 4.5:1 against its background.
 */

function srgbChannel(c) {
  const v = c / 255;
  return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
}

/** Parse #RGB / #RRGGBB / rgb() / rgba() into {r,g,b} 0–255. */
export function parseColor(input) {
  if (typeof input !== "string") return null;
  const s = input.trim();
  let m = /^#([0-9a-f]{3})$/i.exec(s);
  if (m) {
    const [r, g, b] = m[1].split("").map((ch) => parseInt(ch + ch, 16));
    return { r, g, b };
  }
  m = /^#([0-9a-f]{6})$/i.exec(s);
  if (m) {
    const n = m[1];
    return {
      r: parseInt(n.slice(0, 2), 16),
      g: parseInt(n.slice(2, 4), 16),
      b: parseInt(n.slice(4, 6), 16),
    };
  }
  m = /^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)/i.exec(s);
  if (m) {
    return { r: +m[1], g: +m[2], b: +m[3] };
  }
  return null;
}

export function relativeLuminance(color) {
  const c = typeof color === "string" ? parseColor(color) : color;
  if (!c) return null;
  const R = srgbChannel(c.r);
  const G = srgbChannel(c.g);
  const B = srgbChannel(c.b);
  return 0.2126 * R + 0.7152 * G + 0.0722 * B;
}

export function contrastRatio(fg, bg) {
  const L1 = relativeLuminance(fg);
  const L2 = relativeLuminance(bg);
  if (L1 == null || L2 == null) return null;
  const lighter = Math.max(L1, L2);
  const darker = Math.min(L1, L2);
  return (lighter + 0.05) / (darker + 0.05);
}

/**
 * Check branding color pairs for body-text contrast (4.5:1).
 * Expects branding.colors with primary/accent (and optional background/text).
 */
export function checkBrandingContrast(branding, minRatio = 4.5) {
  const colors = branding?.colors || {};
  const bg = colors.background || colors.bg || "#ffffff";
  const text = colors.text || colors.foreground || colors.primary;
  const accent = colors.accent;
  const issues = [];

  if (text) {
    const ratio = contrastRatio(text, bg);
    if (ratio == null) {
      issues.push({ pair: "text/background", error: "unparseable color" });
    } else if (ratio < minRatio) {
      issues.push({
        pair: "text/background",
        ratio: Number(ratio.toFixed(2)),
        required: minRatio,
        fg: text,
        bg,
      });
    }
  }

  if (accent) {
    const ratio = contrastRatio(accent, bg);
    if (ratio == null) {
      issues.push({ pair: "accent/background", error: "unparseable color" });
    } else if (ratio < minRatio) {
      issues.push({
        pair: "accent/background",
        ratio: Number(ratio.toFixed(2)),
        required: minRatio,
        fg: accent,
        bg,
      });
    }
  }

  // Also check primary on white if no explicit text (common logo/button case)
  if (!text && colors.primary) {
    const ratio = contrastRatio(colors.primary, bg);
    if (ratio != null && ratio < minRatio) {
      issues.push({
        pair: "primary/background",
        ratio: Number(ratio.toFixed(2)),
        required: minRatio,
        fg: colors.primary,
        bg,
      });
    }
  }

  return { ok: issues.length === 0, issues, minRatio };
}
