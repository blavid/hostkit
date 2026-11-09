import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { qrPng, QR_MODULE_PX, QR_QUIET_MODULES } from "../src/qr.js";

const VENV = process.env.HOSTKIT_QR_PYTHON || "/tmp/hostkit-qrvenv/bin/python";
const DECODE_PY = `
import sys
from PIL import Image
path, expect = sys.argv[1], sys.argv[2]
img = Image.open(path)
text = None
try:
    import zxingcpp
    found = zxingcpp.read_barcodes(img)
    if found:
        text = found[0].text
except Exception:
    pass
if not text:
    import cv2, numpy as np
    val, pts, _ = cv2.QRCodeDetector().detectAndDecode(np.array(img.convert("RGB")))
    text = val or None
if text != expect:
    sys.stderr.write(f"decoded {text!r}, expected {expect!r}, size={img.size}\\n")
    sys.exit(1)
print(f"ok {img.size[0]}x{img.size[1]} {text}")
`;

function pngSize(bytes) {
  const buf = Buffer.from(bytes);
  if (buf[0] !== 0x89 || buf.toString("ascii", 1, 4) !== "PNG") {
    throw new Error("not a PNG");
  }
  return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
}

function ensureDecoderPython() {
  const probe = spawnSync(VENV, ["-c", "import zxingcpp, PIL, cv2"], { encoding: "utf8" });
  if (probe.status === 0) return VENV;
  const setup = spawnSync(
    "bash",
    ["-lc", "python3 -m venv /tmp/hostkit-qrvenv && /tmp/hostkit-qrvenv/bin/pip install -q zxing-cpp opencv-python-headless pillow"],
    { encoding: "utf8", timeout: 180_000 },
  );
  if (setup.status !== 0) {
    throw new Error(`QR decoder venv failed: ${setup.stderr || setup.stdout}`);
  }
  const again = spawnSync(VENV, ["-c", "import zxingcpp, PIL"], { encoding: "utf8" });
  if (again.status !== 0) {
    throw new Error(`QR decoder import failed: ${again.stderr}`);
  }
  return VENV;
}

function decodePng(png, url) {
  const python = ensureDecoderPython();
  const dir = mkdtempSync(join(tmpdir(), "hostkit-qr-"));
  const file = join(dir, "qr.png");
  writeFileSync(file, png);
  const run = spawnSync(python, ["-c", DECODE_PY, file, url], { encoding: "utf8" });
  if (run.status !== 0) {
    throw new Error(run.stderr || run.stdout || `decoder exit ${run.status}`);
  }
  return run.stdout.trim();
}

test("qrPng uses 11px modules and a 4-module quiet zone", () => {
  assert.equal(QR_MODULE_PX, 11);
  assert.equal(QR_QUIET_MODULES, 4);
});

test("qrPng decodes back to the exact pairing URL", () => {
  const url = "http://127.0.0.1:8787/pair/ABCDEF";
  const png = qrPng(url);
  const { width, height } = pngSize(png);
  // Version 3 is 29 modules; 29 + 2*4 quiet = 37 cells * 11px = 407.
  assert.equal(width, 407);
  assert.equal(height, 407);
  assert.equal((29 + QR_QUIET_MODULES * 2) * QR_MODULE_PX, 407);
  const out = decodePng(png, url);
  assert.match(out, /ok 407x407 http:\/\/127\.0\.0\.1:8787\/pair\/ABCDEF/);
});

test("qrPng decodes a second HostKit-shaped URL", () => {
  const url = "http://127.0.0.1:8787/pair/WXYZ29";
  const png = qrPng(url);
  const { width, height } = pngSize(png);
  assert.equal(width, height);
  assert.equal(width % QR_MODULE_PX, 0);
  decodePng(png, url);
});
