#!/usr/bin/env python3
"""Flag "=" / "<>" comparisons between a string and a number in BrightScript.

Roku firmware raises Type Mismatch for 1 = "1"; brs-node returns false.
bsc 0.x does not type-check comparisons, so this lint infers each operand's
type from what the code shows:
  - literals: "..." is S; 12, &hFF, 1.5 are N
  - calls to functions declared "as string" / "as integer|float|double"
  - builtins (Len, Val, Count, InStr, Asc, Int, ... are N; Str, Left, Mid,
    LCase, ToStr, type, ... are S)
  - node fields that read back as numbers on the TV (color, blendColor,
    opacity, width, height, itemFocused, itemSelected, jumpToItem, loadStatus
    is S, text/uri/id are S)
  - params with "as string"/"as integer" and locals whose every assignment
    in the function has one inferred type
Anything it can't infer is skipped. Exit 1 on any finding.
"""
import pathlib
import re
import sys

NUM_FUNCS = {"len", "val", "int", "fix", "cint", "instr", "asc", "abs", "sgn", "count", "getint", "toint",
             "strtoi", "rnd", "getindex", "milliseconds", "totalmilliseconds", "asseconds", "totalseconds"}
STR_FUNCS = {"str", "stri", "left", "mid", "right", "lcase", "ucase", "chr", "tostr", "trim", "type",
             "substitute", "string", "getstring", "formatjson", "toisostring", "join", "escape", "encodeuri"}
NUM_FIELDS = {"color", "blendcolor", "opacity", "width", "height", "itemfocused", "itemselected",
              "jumptoitem", "rotation", "maxlines", "numrows", "numcolumns", "loadwidth", "loadheight",
              "bitmapwidth", "bitmapheight"}
STR_FIELDS = {"text", "uri", "id", "loadstatus", "state", "subtype", "title", "horizalign", "vertalign"}

DECL = re.compile(r"^\s*(?:function|sub)\s+(\w+)\s*\((.*?)\)\s*(?:as\s+(\w+))?", re.I)
END = re.compile(r"^\s*end\s+(?:function|sub)\b", re.I)
ASSIGN = re.compile(r"^\s*(\w+)\s*=\s*(.+)$")
PARAM = re.compile(r"(\w+)\s+as\s+(\w+)", re.I)
CMP = re.compile(r"(?<![<>=])(=|<>)(?!=)")


def kind_of_decl(t):
    t = (t or "").lower()
    if t == "string":
        return "S"
    if t in ("integer", "float", "double", "longinteger"):
        return "N"
    return None


def strip_strings(line):
    out, i, q = [], 0, False
    for ch in line:
        if ch == '"':
            q = not q
            out.append('"')
        elif q:
            out.append("x")
        else:
            out.append(ch)
    s = "".join(out)
    cut = s.find("'")
    return s if cut < 0 else s[:cut]


def wraps(e):
    depth = 0
    for i, c in enumerate(e):
        depth += (c == "(") - (c == ")")
        if depth == 0 and i < len(e) - 1:
            return False
    return True


def infer(expr, env, funcs):
    e = expr.strip()
    while e.startswith("(") and e.endswith(")") and wraps(e):
        e = e[1:-1].strip()
    if not e:
        return None
    if re.fullmatch(r'"x*"', e):
        return "S"
    if re.fullmatch(r"-?(\d+(\.\d+)?|&h[0-9a-f]+)[%!#&]?", e, re.I):
        return "N"
    if re.search(r'"\s*\+|\+\s*"', e):
        return "S"
    m = re.fullmatch(r"(?:[\w.\[\]]+\.)?(\w+)\s*\(.*\)", e)
    if m:
        name = m.group(1).lower()
        if name in NUM_FUNCS:
            return "N"
        if name in STR_FUNCS:
            return "S"
        return funcs.get(name)
    m = re.fullmatch(r"[\w\[\]]+(?:\.\w+)*\.(\w+)", e)
    if m:
        f = m.group(1).lower()
        if f in NUM_FIELDS:
            return "N"
        if f in STR_FIELDS:
            return "S"
        return None
    if re.fullmatch(r"\w+", e):
        return env.get(e.lower())
    return None


def operands(cond, pos):
    """Left and right operand text around a comparison operator at pos."""
    stop = re.compile(r"\b(and|or|not|then|if|while|return|else|until)\b|[(),]", re.I)
    left = cond[:pos]
    lm = list(stop.finditer(left))
    left = left[lm[-1].end():] if lm else left
    right = cond[pos:]
    rm = stop.search(right)
    right = right[: rm.start()] if rm else right
    return left, right


def balanced_operand(text, pos, op_len):
    # Re-take operands allowing a call with balanced parens on either side.
    def grab_left(s):
        depth, i = 0, len(s) - 1
        while i >= 0:
            c = s[i]
            if c == ")":
                depth += 1
            elif c == "(":
                if depth == 0:
                    break
                depth -= 1
            elif depth == 0 and (c == "," or re.match(r"\s", c) and re.search(r"\b(and|or|not|if|then|while|return)\s*$", s[: i + 1], re.I)):
                break
            i -= 1
        return s[i + 1:]

    def grab_right(s):
        depth, i = 0, 0
        while i < len(s):
            c = s[i]
            if c == "(":
                depth += 1
            elif c == ")":
                if depth == 0:
                    break
                depth -= 1
            elif depth == 0 and (c == "," or re.match(r"\s(and|or|then|else)\b", s[i:], re.I)):
                break
            i += 1
        return s[:i]

    return grab_left(text[:pos]).strip(), grab_right(text[pos + op_len:]).strip()


def lint(files):
    funcs = {}
    for f in files:
        for line in f.read_text(encoding="utf-8", errors="replace").splitlines():
            m = DECL.match(line)
            if m:
                k = kind_of_decl(m.group(3))
                if k:
                    funcs[m.group(1).lower()] = k
    findings = []
    for f in files:
        lines = f.read_text(encoding="utf-8", errors="replace").splitlines()
        i = 0
        while i < len(lines):
            m = DECL.match(lines[i])
            if not m:
                i += 1
                continue
            env = {}
            for pn, pt in PARAM.findall(m.group(2)):
                k = kind_of_decl(pt)
                if k:
                    env[pn.lower()] = k
            body = []
            j = i + 1
            while j < len(lines) and not END.match(lines[j]):
                body.append((j + 1, strip_strings(lines[j])))
                j += 1
            kinds = {}
            for _, line in body:
                a = ASSIGN.match(line)
                if a and not re.match(r"\s*(if|while|for|return)\b", line, re.I):
                    kinds.setdefault(a.group(1).lower(), set()).add(infer(a.group(2), env, funcs))
            for name, ks in kinds.items():
                if name in env:
                    continue
                if len(ks) == 1 and None not in ks:
                    env[name] = next(iter(ks))
            for no, line in body:
                if not re.search(r"\b(if|while|return|until)\b|^\s*\w+\s*=\s*.*(=|<>)", line, re.I):
                    continue
                text = line
                # "if cond then stmt": only the condition compares; stmt assigns.
                t = re.search(r"\bthen\b", text, re.I)
                if t and re.match(r"\s*(else\s+)?if\b", text, re.I):
                    text = text[: t.start()]
                a = ASSIGN.match(text)
                start = 0
                if a and not re.match(r"\s*(if|while|return)\b", line, re.I):
                    start = a.start(2)
                for c in CMP.finditer(text, start):
                    lo, ro = balanced_operand(text, c.start(), len(c.group(1)))
                    lo = re.sub(r"^\s*(if|while|return|until|not)\s+", "", lo, flags=re.I)
                    lk, rk = infer(lo, env, funcs), infer(ro, env, funcs)
                    if lk and rk and lk != rk:
                        findings.append(f"{f}:{no}: '{lo.strip()} {c.group(1)} {ro.strip()}' compares {'string' if lk == 'S' else 'number'} with {'string' if rk == 'S' else 'number'}")
            i = j + 1
    return findings


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "channel")
    files = sorted(p for p in root.rglob("*.brs") if "secrets" not in p.name)
    found = lint(files)
    for line in found:
        print(line)
    print(f"lint_compare: {len(found)} string/number comparison(s) in {len(files)} files")
    sys.exit(1 if found else 0)


if __name__ == "__main__":
    main()
