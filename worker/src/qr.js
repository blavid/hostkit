/**
 * Minimal QR encoder (byte mode, EC level M, versions 1–10) plus an
 * uncompressed PNG writer. No dependencies. Used so POST /v1/pair/start can
 * also expose a QR whose payload already embeds the pairing code.
 */
const EC_M = {
  // [ecCodewordsPerBlock, [block1Count, block1Data], optional [block2Count, block2Data]]
  1: [10, [1, 16]],
  2: [16, [1, 28]],
  3: [26, [1, 44]],
  4: [18, [2, 32]],
  5: [24, [2, 43]],
  6: [16, [4, 27]],
  7: [18, [4, 31]],
  8: [22, [2, 38], [2, 39]],
  9: [22, [3, 36], [2, 37]],
  10: [26, [4, 36], [1, 37]],
};

const ALIGN = {
  1: [],
  2: [6, 18],
  3: [6, 22],
  4: [6, 26],
  5: [6, 30],
  6: [6, 34],
  7: [6, 22, 38],
  8: [6, 24, 42],
  9: [6, 26, 46],
  10: [6, 28, 50],
};

const EXP = new Uint8Array(512);
const LOG = new Uint8Array(256);
(function initGf() {
  let x = 1;
  for (let i = 0; i < 255; i++) {
    EXP[i] = x;
    LOG[x] = i;
    x <<= 1;
    if (x & 0x100) x ^= 0x11d;
  }
  for (let i = 255; i < 512; i++) EXP[i] = EXP[i - 255];
})();

function gfMul(a, b) {
  if (a === 0 || b === 0) return 0;
  return EXP[LOG[a] + LOG[b]];
}

function rsGenerator(ecCount) {
  let poly = [1];
  for (let i = 0; i < ecCount; i++) {
    const next = new Array(poly.length + 1).fill(0);
    for (let j = 0; j < poly.length; j++) {
      next[j] ^= poly[j];
      next[j + 1] ^= gfMul(poly[j], EXP[i]);
    }
    poly = next;
  }
  return poly;
}

function rsRemainder(data, ecCount) {
  const gen = rsGenerator(ecCount);
  const out = new Array(ecCount).fill(0);
  for (const byte of data) {
    const factor = byte ^ out[0];
    out.shift();
    out.push(0);
    if (factor === 0) continue;
    for (let i = 0; i < gen.length - 1; i++) {
      out[i] ^= gfMul(gen[i + 1], factor);
    }
  }
  return out;
}

function versionFor(length) {
  for (let v = 1; v <= 10; v++) {
    const cap = dataCapacity(v);
    // mode(4) + length(8 or 16) + data + terminator, in bytes after padding
    const lenBits = v >= 10 ? 16 : 8;
    const needBits = 4 + lenBits + length * 8 + 4;
    const needBytes = Math.ceil(needBits / 8);
    if (needBytes <= cap) return v;
  }
  throw new Error("payload too long for QR versions 1–10");
}

function dataCapacity(version) {
  const row = EC_M[version];
  const ec = row[0];
  let blocks = 0;
  let data = 0;
  for (let i = 1; i < row.length; i++) {
    blocks += row[i][0];
    data += row[i][0] * row[i][1];
  }
  return data;
}

function totalCodewords(version) {
  const size = version * 4 + 17;
  // Use table: data + ec
  const row = EC_M[version];
  const ec = row[0];
  let blocks = 0;
  let data = 0;
  for (let i = 1; i < row.length; i++) {
    blocks += row[i][0];
    data += row[i][0] * row[i][1];
  }
  return data + blocks * ec;
}

function encodePayload(text, version) {
  const bytes = new TextEncoder().encode(text);
  const cap = dataCapacity(version);
  const bits = [];
  const push = (value, n) => {
    for (let i = n - 1; i >= 0; i--) bits.push((value >> i) & 1);
  };
  push(0b0100, 4); // byte mode
  push(bytes.length, version >= 10 ? 16 : 8);
  for (const b of bytes) push(b, 8);
  const maxBits = cap * 8;
  const term = Math.min(4, maxBits - bits.length);
  push(0, term);
  while (bits.length % 8 !== 0) bits.push(0);
  const data = [];
  for (let i = 0; i < bits.length; i += 8) {
    let v = 0;
    for (let j = 0; j < 8; j++) v = (v << 1) | bits[i + j];
    data.push(v);
  }
  const pads = [0xec, 0x11];
  let p = 0;
  while (data.length < cap) data.push(pads[p++ % 2]);
  return data;
}

function interleave(version, data) {
  const row = EC_M[version];
  const ecCount = row[0];
  const groups = row.slice(1);
  const blocks = [];
  let offset = 0;
  for (const [count, dataCount] of groups) {
    for (let i = 0; i < count; i++) {
      const slice = data.slice(offset, offset + dataCount);
      offset += dataCount;
      blocks.push({ data: slice, ec: rsRemainder(slice, ecCount) });
    }
  }
  const out = [];
  const maxData = Math.max(...blocks.map((b) => b.data.length));
  for (let i = 0; i < maxData; i++) {
    for (const b of blocks) if (i < b.data.length) out.push(b.data[i]);
  }
  for (let i = 0; i < ecCount; i++) {
    for (const b of blocks) out.push(b.ec[i]);
  }
  return out;
}

function moduleSize(version) {
  return version * 4 + 17;
}

function reservedMatrix(version) {
  const n = moduleSize(version);
  const reserved = Array.from({ length: n }, () => new Array(n).fill(false));
  const mark = (r, c) => {
    if (r >= 0 && r < n && c >= 0 && c < n) reserved[r][c] = true;
  };
  function finder(r, c) {
    for (let i = -1; i <= 7; i++) {
      for (let j = -1; j <= 7; j++) mark(r + i, c + j);
    }
  }
  finder(0, 0);
  finder(0, n - 7);
  finder(n - 7, 0);
  // timing
  for (let i = 0; i < n; i++) {
    mark(6, i);
    mark(i, 6);
  }
  // alignment
  const pos = ALIGN[version];
  for (const r of pos) {
    for (const c of pos) {
      if ((r === 6 && c === 6) || (r === 6 && c === n - 7) || (r === n - 7 && c === 6)) continue;
      for (let i = -2; i <= 2; i++) for (let j = -2; j <= 2; j++) mark(r + i, c + j);
    }
  }
  // format info
  for (let i = 0; i < 9; i++) {
    mark(8, i);
    mark(i, 8);
  }
  for (let i = 0; i < 8; i++) {
    mark(8, n - 1 - i);
    mark(n - 1 - i, 8);
  }
  mark(8, 8);
  // version info for v>=7
  if (version >= 7) {
    for (let i = 0; i < 6; i++) {
      for (let j = 0; j < 3; j++) {
        mark(n - 11 + j, i);
        mark(i, n - 11 + j);
      }
    }
  }
  return reserved;
}

function placeFinders(mod, n) {
  function finder(r, c) {
    for (let i = 0; i < 7; i++) {
      for (let j = 0; j < 7; j++) {
        const edge = i === 0 || i === 6 || j === 0 || j === 6;
        const core = i >= 2 && i <= 4 && j >= 2 && j <= 4;
        mod[r + i][c + j] = edge || core;
      }
    }
  }
  finder(0, 0);
  finder(0, n - 7);
  finder(n - 7, 0);
}

function placeTiming(mod, n) {
  // Only the stretch between the finders. Writing the full row/column
  // would punch holes in the finder patterns and break decoding.
  for (let i = 8; i < n - 8; i++) {
    mod[6][i] = i % 2 === 0;
    mod[i][6] = i % 2 === 0;
  }
}

function placeAlignment(mod, version) {
  const n = mod.length;
  const pos = ALIGN[version];
  for (const r of pos) {
    for (const c of pos) {
      if ((r === 6 && c === 6) || (r === 6 && c === n - 7) || (r === n - 7 && c === 6)) continue;
      for (let i = -2; i <= 2; i++) {
        for (let j = -2; j <= 2; j++) {
          const edge = Math.abs(i) === 2 || Math.abs(j) === 2;
          mod[r + i][c + j] = edge || (i === 0 && j === 0);
        }
      }
    }
  }
}

function placeDarkModule(mod, version) {
  const n = mod.length;
  mod[n - 8][8] = true;
}

const VERSION_BITS = {
  7: 0x07c94,
  8: 0x085bc,
  9: 0x09a99,
  10: 0x0a4d3,
};

function placeVersion(mod, version) {
  if (version < 7) return;
  const bits = VERSION_BITS[version];
  const n = mod.length;
  for (let i = 0; i < 18; i++) {
    const bit = ((bits >> i) & 1) === 1;
    const r = Math.floor(i / 3);
    const c = n - 11 + (i % 3);
    mod[r][c] = bit;
    mod[c][r] = bit;
  }
}

function maskFn(id) {
  switch (id) {
    case 0: return (r, c) => (r + c) % 2 === 0;
    case 1: return (r, c) => r % 2 === 0;
    case 2: return (r, c) => c % 3 === 0;
    case 3: return (r, c) => (r + c) % 3 === 0;
    case 4: return (r, c) => (Math.floor(r / 2) + Math.floor(c / 3)) % 2 === 0;
    case 5: return (r, c) => ((r * c) % 2) + ((r * c) % 3) === 0;
    case 6: return (r, c) => (((r * c) % 2) + ((r * c) % 3)) % 2 === 0;
    default: return (r, c) => (((r + c) % 2) + ((r * c) % 3)) % 2 === 0;
  }
}

function placeData(mod, reserved, codewords, maskId) {
  const n = mod.length;
  const bits = [];
  for (const b of codewords) {
    for (let i = 7; i >= 0; i--) bits.push((b >> i) & 1);
  }
  // remainder bits: versions have 0 or 7 remainder bits — leave 0 (already false)
  const mask = maskFn(maskId);
  let bit = 0;
  let upward = true;
  for (let col = n - 1; col > 0; col -= 2) {
    if (col === 6) col--;
    for (let i = 0; i < n; i++) {
      const row = upward ? n - 1 - i : i;
      for (const c of [col, col - 1]) {
        if (reserved[row][c]) continue;
        const val = bit < bits.length ? bits[bit] === 1 : false;
        bit++;
        mod[row][c] = mask(row, c) ? !val : val;
      }
    }
    upward = !upward;
  }
}

function formatBits(maskId) {
  // EC level M = 00, then 3-bit mask
  let data = (0b00 << 3) | maskId;
  let bits = data << 10;
  const gen = 0x537;
  for (let i = 14; i >= 10; i--) {
    if ((bits >> i) & 1) bits ^= gen << (i - 10);
  }
  const combined = ((data << 10) | bits) ^ 0x5412;
  return combined;
}

function placeFormat(mod, maskId) {
  const bits = formatBits(maskId);
  const n = mod.length;
  const at = (i) => ((bits >> i) & 1) === 1;
  // horizontal around finder, and vertical copy
  const orderA = [
    [8, 0], [8, 1], [8, 2], [8, 3], [8, 4], [8, 5], [8, 7], [8, 8],
    [7, 8], [5, 8], [4, 8], [3, 8], [2, 8], [1, 8], [0, 8],
  ];
  for (let i = 0; i < 15; i++) {
    const [r, c] = orderA[i];
    mod[r][c] = at(14 - i);
  }
  // other copy
  for (let i = 0; i < 8; i++) mod[n - 1 - i][8] = at(14 - i);
  for (let i = 0; i < 8; i++) mod[8][n - 8 + i] = at(6 - i); // wait, need correct mapping
}

// Fix placeFormat below with the standard mapping — the second loop above is wrong.
function placeFormatFixed(mod, maskId) {
  const bits = formatBits(maskId);
  const n = mod.length;
  const bit = (i) => ((bits >> (14 - i)) & 1) === 1;
  // Positions 0..14 along the two copies, per ISO Fig. 25.
  const horiz = [0, 1, 2, 3, 4, 5, 7, 8];
  const vert = [0, 1, 2, 3, 4, 5, 7, 8];
  // Copy 1 (top-left):
  // 0-5: (8,0..5); 6: (8,7); 7: (8,8); 8: (7,8); 9-14: (5..0,8)
  const copy1 = [
    [8, 0], [8, 1], [8, 2], [8, 3], [8, 4], [8, 5], [8, 7], [8, 8],
    [7, 8], [5, 8], [4, 8], [3, 8], [2, 8], [1, 8], [0, 8],
  ];
  const copy2 = [];
  // 0-6: (n-1 .. n-7, 8); 7-14: (8, n-8 .. n-1)
  for (let i = 0; i < 7; i++) copy2.push([n - 1 - i, 8]);
  for (let i = 0; i < 8; i++) copy2.push([8, n - 8 + i]);
  for (let i = 0; i < 15; i++) {
    const v = bit(i);
    mod[copy1[i][0]][copy1[i][1]] = v;
    mod[copy2[i][0]][copy2[i][1]] = v;
  }
}

function scoreMask(mod) {
  const n = mod.length;
  let score = 0;
  // N1: runs of 5+
  const runs = (get) => {
    let s = 0;
    for (let i = 0; i < n; i++) {
      let run = 1;
      for (let j = 1; j < n; j++) {
        if (get(i, j) === get(i, j - 1)) run++;
        else {
          if (run >= 5) s += 3 + (run - 5);
          run = 1;
        }
      }
      if (run >= 5) s += 3 + (run - 5);
    }
    return s;
  };
  score += runs((r, c) => mod[r][c]);
  score += runs((r, c) => mod[c][r]);
  // N2: 2x2 blocks
  for (let r = 0; r < n - 1; r++) {
    for (let c = 0; c < n - 1; c++) {
      const v = mod[r][c];
      if (mod[r][c + 1] === v && mod[r + 1][c] === v && mod[r + 1][c + 1] === v) score += 3;
    }
  }
  // N3: finder-like
  const pat = (get) => {
    let s = 0;
    for (let i = 0; i < n; i++) {
      let acc = 0;
      for (let j = 0; j < n; j++) {
        acc = ((acc << 1) & 0x7ff) | (get(i, j) ? 1 : 0);
        if (j >= 10 && (acc === 0x5d0 || acc === 0x05d)) s += 40;
      }
    }
    return s;
  };
  score += pat((r, c) => mod[r][c]);
  score += pat((r, c) => mod[c][r]);
  // N4: proportion
  let dark = 0;
  for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) if (mod[r][c]) dark++;
  const perc = (dark * 100) / (n * n);
  score += 10 * Math.floor(Math.abs(perc - 50) / 5);
  return score;
}

function buildMatrix(text) {
  const version = versionFor(new TextEncoder().encode(text).length);
  const data = encodePayload(text, version);
  const codewords = interleave(version, data);
  const n = moduleSize(version);
  const reserved = reservedMatrix(version);

  let best = null;
  let bestScore = Infinity;
  for (let mask = 0; mask < 8; mask++) {
    const mod = Array.from({ length: n }, () => new Array(n).fill(false));
    placeFinders(mod, n);
    placeTiming(mod, n);
    placeAlignment(mod, version);
    placeDarkModule(mod, version);
    placeVersion(mod, version);
    placeData(mod, reserved, codewords, mask);
    placeFormatFixed(mod, mask);
    const s = scoreMask(mod);
    if (s < bestScore) {
      bestScore = s;
      best = mod;
    }
  }
  return best;
}

function crc32(buf) {
  let c = 0xffffffff;
  const table = crc32.table || (crc32.table = (() => {
    const t = new Uint32Array(256);
    for (let i = 0; i < 256; i++) {
      let v = i;
      for (let k = 0; k < 8; k++) v = (v & 1) ? (0xedb88320 ^ (v >>> 1)) : (v >>> 1);
      t[i] = v >>> 0;
    }
    return t;
  })());
  for (const b of buf) c = table[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function adler32(buf) {
  let a = 1, b = 0;
  for (const x of buf) {
    a = (a + x) % 65521;
    b = (b + a) % 65521;
  }
  return ((b << 16) | a) >>> 0;
}

function u32(n) {
  return [(n >>> 24) & 0xff, (n >>> 16) & 0xff, (n >>> 8) & 0xff, n & 0xff];
}

function chunk(type, data) {
  const typ = [...type].map((ch) => ch.charCodeAt(0));
  const body = Uint8Array.from([...typ, ...data]);
  const crc = crc32(body);
  return Uint8Array.from([...u32(data.length), ...body, ...u32(crc)]);
}

// Version 3 is 29 modules. With a 4-module quiet zone that is 37 cells.
// 11px modules produce a 407px card (integer module size, Pixel M2 review).
export const QR_MODULE_PX = 11;
export const QR_QUIET_MODULES = 4;

export function qrPng(text, modulePx = QR_MODULE_PX, quiet = QR_QUIET_MODULES) {
  const mod = buildMatrix(text);
  const n = mod.length;
  const dim = (n + quiet * 2) * modulePx;
  // 8-bit grayscale, filter 0, uncompressed deflate stored blocks
  const raw = [];
  for (let y = 0; y < dim; y++) {
    raw.push(0); // filter
    const my = Math.floor(y / modulePx) - quiet;
    for (let x = 0; x < dim; x++) {
      const mx = Math.floor(x / modulePx) - quiet;
      let dark = false;
      if (my >= 0 && my < n && mx >= 0 && mx < n) dark = mod[my][mx];
      raw.push(dark ? 0 : 255);
    }
  }
  const rawBytes = Uint8Array.from(raw);
  // zlib: 0x78 0x01 + stored blocks + adler32
  const blocks = [];
  const max = 65535;
  for (let i = 0; i < rawBytes.length; i += max) {
    const slice = rawBytes.subarray(i, i + max);
    const last = i + max >= rawBytes.length ? 1 : 0;
    const len = slice.length;
    const nlen = (~len) & 0xffff;
    blocks.push(last, len & 0xff, (len >> 8) & 0xff, nlen & 0xff, (nlen >> 8) & 0xff, ...slice);
  }
  const zlib = Uint8Array.from([0x78, 0x01, ...blocks, ...u32(adler32(rawBytes))]);
  const ihdr = Uint8Array.from([
    ...u32(dim), ...u32(dim),
    8, 0, 0, 0, 0, // bit depth, color grayscale, no compression/filter/interlace flags (compression method 0)
  ]);
  const sig = [137, 80, 78, 71, 13, 10, 26, 10];
  const parts = [Uint8Array.from(sig), chunk("IHDR", ihdr), chunk("IDAT", zlib), chunk("IEND", [])];
  let len = 0;
  for (const p of parts) len += p.length;
  const out = new Uint8Array(len);
  let o = 0;
  for (const p of parts) {
    out.set(p, o);
    o += p.length;
  }
  return out;
}
