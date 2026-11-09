#!/usr/bin/env python3
"""Make brs-node strict like Roku firmware for "=" and "<>".

brs-node 2.6.2 returns false for 1 = "1"; a Roku TV raises
Type Mismatch (Operator "=" can't be applied to "roInt" and "String").
This patches the operand check so a string compared with a non-string
(other than invalid) is a runtime error in the emulator too. Idempotent.
"""
import pathlib
import sys

OLD = ('function i(e,t,n){return e.kind===s.ValueKind.Invalid||n.kind===s.ValueKind.Invalid?'
       't===c.n_.Equal||t===c.n_.LessGreater:(')
NEW = ('function i(e,t,n){return e.kind===s.ValueKind.Invalid||n.kind===s.ValueKind.Invalid?'
       't===c.n_.Equal||t===c.n_.LessGreater:(0,s.isBrsString)(e)!==(0,s.isBrsString)(n)?!1:(')

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
if NEW in text:
    print("emu strict: already patched")
elif text.count(OLD) == 1:
    path.write_text(text.replace(OLD, NEW), encoding="utf-8")
    print("emu strict: patched string/non-string = and <>")
else:
    raise SystemExit("emu strict: operand check not found; brs-node changed")
