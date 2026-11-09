"""Greeting rules mirrored from channel/components/GuestRules.brs.

Each name part is trimmed, punctuation is normalized, and the part is kept
only when every character is a letter (ASCII, Latin-1 except × and ÷, or
Latin Extended-A), hyphen, apostrophe, space, or period. The part must
contain a letter and is capped at 32 characters. The first name is required.
A missing or invalid last name is omitted.
"""

from __future__ import annotations

FALLBACK = "Welcome to Eaglewood 19"
NAME_LIMIT = 32
FONT_SIZES = (64, 52, 42, 34)
LABEL_WIDTH = 1760
BAR_BOTTOM = 960
BAR_MIN_HEIGHT = 160
BAR_PAD = 48
BAR_MIN_TOP = 48


def _is_letter(code: int) -> bool:
    if 65 <= code <= 90 or 97 <= code <= 122:
        return True
    if 192 <= code <= 255 and code not in (215, 247):
        return True
    return 256 <= code <= 383


def _normalize(text: str) -> str:
    out: list[str] = []
    for ch in text:
        code = ord(ch)
        if code in (8217, 8216, 700):
            out.append("'")
        elif code in (8211, 8212):
            out.append("-")
        elif code == 160:
            out.append(" ")
        else:
            out.append(ch)
    return "".join(out)


def _collapse_spaces(text: str) -> str:
    out: list[str] = []
    pending = False
    for ch in text:
        if ch == " ":
            if out:
                pending = True
        else:
            if pending:
                out.append(" ")
                pending = False
            out.append(ch)
    return "".join(out)


def _strip_trailing_punct(text: str) -> str:
    while text.endswith((" ", "-", "'", ".")):
        text = text[:-1]
    return text


def sanitize_name_part(raw: str | None) -> str:
    if raw is None:
        return ""
    text = _collapse_spaces(_normalize(raw.strip()))
    if not text:
        return ""
    for ch in text:
        if not (_is_letter(ord(ch)) or ch in " '-."):
            return ""
    if not any(_is_letter(ord(ch)) for ch in text):
        return ""
    if len(text) > NAME_LIMIT:
        text = _strip_trailing_punct(text[:NAME_LIMIT])
    if not text or not any(_is_letter(ord(ch)) for ch in text):
        return ""
    return text


def build_greeting(first: str | None, last: str | None = None, *, current: bool = True) -> str:
    first_name = sanitize_name_part(first)
    if not first_name or not current:
        return FALLBACK
    last_name = sanitize_name_part(last)
    if not last_name:
        return "Welcome, " + first_name
    return "Welcome, " + first_name + " " + last_name


def fallback_char_width(size: int) -> int:
    width = (size * 3) // 4
    return width if width > 0 else 1


def wrap_measured(text: str, max_width: int, measure) -> list[str]:
    """Break on spaces and hyphens. A token wider than the line breaks mid-word."""
    lines: list[str] = []
    remaining = text
    guard = 0
    while remaining:
        guard += 1
        if guard > 12:
            lines.append("overflow")
            break
        if measure(remaining) <= max_width:
            lines.append(remaining)
            break
        count = 1
        for index in range(2, len(remaining) + 1):
            if measure(remaining[:index]) > max_width:
                break
            count = index
        break_at = count
        for index in range(count, 0, -1):
            if remaining[index - 1] in " -":
                break_at = index
                break
        piece = remaining[:break_at]
        if len(piece) > 1 and piece.endswith(" "):
            piece = piece[:-1]
        if piece in ("", " "):
            piece = remaining[:1]
            break_at = 1
        lines.append(piece)
        if break_at >= len(remaining):
            break
        remaining = remaining[break_at:].lstrip(" ")
    return lines


def wrap_by_width(text: str, max_width: int, char_width: int) -> list[str]:
    return wrap_measured(text, max_width, lambda value: len(value) * max(char_width, 1))


def bar_box(line_count: int, line_height: int) -> tuple[int, int]:
    count = min(2, max(1, line_count))
    height = max(1, line_height)
    bar_height = count * height + BAR_PAD
    if bar_height < BAR_MIN_HEIGHT:
        bar_height = BAR_MIN_HEIGHT
    top = BAR_BOTTOM - bar_height
    if top < BAR_MIN_TOP:
        top = BAR_MIN_TOP
        bar_height = BAR_BOTTOM - top
    return top, bar_height
