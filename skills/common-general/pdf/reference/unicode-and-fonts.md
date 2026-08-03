# ReportLab Unicode & Font Strategy

## The Problem

ReportLab's built-in fonts (Helvetica, Courier, Times) are Type 1 fonts with limited glyph sets. They CANNOT render:

- Box-drawing characters (`┌─┐│└┘├┤┬┴┼`)
- Block elements (`█▓▒░`)
- Arrows (`→←↑↓`)
- Mathematical symbols (`≤≥≠`)
- Smart quotes (`''""`)
- Em/en dashes (`—–`)
- Bullets (`•`)
- Triangles (`▼▲`)
- Subscript/superscript digits (`₀₁₂₃⁰¹²³`)

These characters render as **solid black boxes** in the PDF output. This is the #1 visual defect in ReportLab-generated PDFs.

## The Solution: Two-Track Font Strategy

### Track 1: Body Text (Helvetica)

Use Helvetica for body text, but **replace all Unicode characters with ASCII equivalents** before rendering.

```python
UNICODE_REPLACEMENTS = {
    # Box-drawing
    "\u2500": "-",  "\u2501": "=",
    "\u2502": "|",  "\u2503": "|",
    "\u250c": "+",  "\u250d": "+",  "\u250e": "+",  "\u250f": "+",
    "\u2510": "+",  "\u2511": "+",  "\u2512": "+",  "\u2513": "+",
    "\u2514": "+",  "\u2515": "+",  "\u2516": "+",  "\u2517": "+",
    "\u2518": "+",  "\u2519": "+",  "\u251a": "+",  "\u251b": "+",
    "\u251c": "+",  "\u251d": "+",  "\u251e": "+",  "\u251f": "+",
    "\u2520": "+",  "\u2524": "+",  "\u2525": "+",
    "\u252c": "+",  "\u2534": "+",  "\u253c": "+",
    # Block elements
    "\u2588": "#",  "\u2593": "#",  "\u2592": "#",  "\u2591": ".",
    # Arrows
    "\u2192": "->", "\u2190": "<-", "\u2191": "^",  "\u2193": "v",
    "\u21d2": "=>", "\u21d0": "<=",
    # Comparison / math
    "\u2264": "<=", "\u2265": ">=", "\u2260": "!=",
    "\u00d7": "x",  "\u00f7": "/",
    # Dashes
    "\u2014": "--", "\u2013": "-",  "\u2012": "-",
    # Quotes
    "\u2018": "'",  "\u2019": "'",  "\u201c": '"',  "\u201d": '"',
    # Bullets and symbols
    "\u2022": "*",  "\u2023": ">",  "\u25cf": "*",
    "\u2713": "[x]", "\u2717": "[ ]", "\u2714": "[x]", "\u2718": "[ ]",
    # Triangles
    "\u25bc": "v",  "\u25b2": "^",  "\u25ba": ">",  "\u25c4": "<",
    # Ellipsis
    "\u2026": "...",
    # Misc
    "\u00a0": " ",  # Non-breaking space
    "\u200b": "",   # Zero-width space
    "\u00b7": ".",  # Middle dot
}

def replace_unicode(text: str) -> str:
    for unicode_char, ascii_replacement in UNICODE_REPLACEMENTS.items():
        text = text.replace(unicode_char, ascii_replacement)
    return text
```

### Track 2: Code Blocks (Menlo / TTF)

For code blocks where Unicode fidelity matters (architecture diagrams, box-drawing art), register a TrueType font that includes Unicode glyphs.

**macOS**: Use Menlo (ships with macOS, excellent Unicode coverage):

```python
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

# Register Menlo (macOS only)
try:
    pdfmetrics.registerFont(TTFont("Menlo", "/System/Library/Fonts/Menlo.ttc", subfontIndex=0))
    CODE_FONT = "Menlo"
except:
    CODE_FONT = "Courier"  # Fallback — will show black boxes for Unicode
```

**Linux**: Use DejaVu Sans Mono or Liberation Mono:

```python
import os

FONT_PATHS = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    "/usr/share/fonts/TTF/DejaVuSansMono.ttf",
    "/usr/share/fonts/liberation-mono/LiberationMono-Regular.ttf",
]

CODE_FONT = "Courier"  # Default fallback
for path in FONT_PATHS:
    if os.path.exists(path):
        pdfmetrics.registerFont(TTFont("MonoUnicode", path))
        CODE_FONT = "MonoUnicode"
        break
```

### Two Normalizer Functions (CRITICAL)

You MUST maintain two separate text normalizers. Using the wrong one causes either black boxes or degraded ASCII art.

```python
import re

def normalize_text(text: str) -> str:
    """For body text (Helvetica). Strips Markdown formatting AND replaces Unicode."""
    text = replace_unicode(text)
    text = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', text)  # Bold
    text = re.sub(r'\*(.+?)\*', r'<i>\1</i>', text)        # Italic
    text = re.sub(r'`(.+?)`', r'<font name="Courier" size="9">\1</font>', text)  # Inline code
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    # Re-apply HTML tags that we just escaped (bold, italic, font)
    # ... or apply escaping BEFORE markdown conversion
    return text

def normalize_code_text(text: str) -> str:
    """For code blocks (Menlo/TTF). HTML-escapes ONLY, preserves Unicode."""
    text = text.replace("&", "&amp;")
    text = text.replace("<", "&lt;")
    text = text.replace(">", "&gt;")
    return text
```

**Rules:**
- `normalize_text()` → ALL body paragraphs, bullet points, table cells
- `normalize_code_text()` → ALL fenced code blocks (triple backtick)
- NEVER apply `replace_unicode()` to code blocks
- NEVER skip `replace_unicode()` on body text

## Subscripts and Superscripts

**NEVER** use Unicode subscript/superscript characters in ReportLab:
- Subscript digits: `₀₁₂₃₄₅₆₇₈₉`
- Superscript digits: `⁰¹²³⁴⁵⁶⁷⁸⁹`

These render as solid black boxes even in TrueType fonts.

Use ReportLab's XML markup tags in Paragraph objects instead:

```python
from reportlab.platypus import Paragraph
from reportlab.lib.styles import getSampleStyleSheet

styles = getSampleStyleSheet()

# Subscripts: use <sub> tag
chemical = Paragraph("H<sub>2</sub>O", styles['Normal'])

# Superscripts: use <super> tag
squared = Paragraph("x<super>2</super> + y<super>2</super>", styles['Normal'])
```

For canvas-drawn text (not Paragraph objects), manually adjust the font size and position.

## ASCII Art & Box-Drawing Rendering (CRITICAL)

**Problem**: ReportLab's `Paragraph` (used in Platypus code blocks) reflows text to fit column width. This **destroys horizontal alignment** of side-by-side boxes, connectors, and any content where character position matters — box-drawing diagrams collapse into broken single-line text.

**Solution**: Bypass Platypus entirely. Use `canvas.beginText()` to place each line at exact coordinates with a guaranteed fixed-width font.

```python
def draw_ascii_art(canvas, x, y, art_text, font_size=10, leading=12):
    """
    Render ASCII art / box-drawing diagrams with exact spatial alignment.

    Uses canvas text object (NOT Paragraph) to preserve character positions.
    Courier is a Core 14 font — guaranteed available, no registration needed.

    Args:
        canvas: ReportLab canvas object
        x: Left edge x-coordinate (points)
        y: TOP of first line y-coordinate (points) — text draws downward
        art_text: Multi-line string with the ASCII art
        font_size: Font size in points (default 10)
        leading: Line spacing in points (default 12)
    """
    textobject = canvas.beginText(x, y)
    textobject.setFont("Courier", font_size)
    textobject.setCharSpace(0)  # Critical: no extra spacing between characters
    textobject.setLeading(leading)
    for line in art_text.split('\n'):
        textobject.textLine(line)
    canvas.drawText(textobject)
```

**Key rules:**
- **ALWAYS** use `Courier` for ASCII art — Core 14 font, guaranteed fixed-width, zero registration
- **ALWAYS** set `setCharSpace(0)` — prevents extra inter-character spacing
- **NEVER** use `Paragraph` for content where character position matters
- **NEVER** apply `normalize_text()` to ASCII art — use `normalize_code_text()` or no normalization

For background boxes, Platypus integration (spacer reservations), and the full diagram rendering decision tree, see `reference/diagrams-and-charts.md`.

## Quick Reference

| Text Type | Font | Normalizer | Unicode Handling | Rendering |
|-----------|------|------------|------------------|-----------|
| Body paragraphs | Helvetica | `normalize_text()` | Replace with ASCII | `Paragraph` |
| Bullet points | Helvetica | `normalize_text()` | Replace with ASCII | `Paragraph` |
| Table cells | Helvetica | `normalize_text()` | Replace with ASCII | `Paragraph` |
| Headings | Helvetica-Bold | `normalize_text()` | Replace with ASCII | `Paragraph` |
| Code blocks | Menlo/TTF | `normalize_code_text()` | Preserve Unicode | `Paragraph` |
| ASCII art / diagrams | Courier | `normalize_code_text()` or none | Preserve Unicode | `canvas.beginText()` |
| Inline code | Courier (in Paragraph) | Parent normalizer | Inherited | `Paragraph` |

## Troubleshooting

### Black Boxes in Body Text
**Cause**: Unicode characters passed to Helvetica/Courier without replacement.
**Fix**: Ensure `replace_unicode()` runs on ALL body text paths. Check table cells and bullet points — these are commonly missed.

### Degraded ASCII Art in Code Blocks
**Cause**: `replace_unicode()` was applied to code blocks, converting `┌─┐│` to `+--|`.
**Fix**: Ensure code blocks use `normalize_code_text()` (NOT `normalize_text()`). Register a Unicode-capable TTF font for code.

### ASCII Art / Box-Drawing Alignment Broken
**Cause**: ASCII art rendered via `Paragraph` which reflows text to fit column width.
**Fix**: Use `canvas.beginText()` with `Courier` font and `setCharSpace(0)`. See the ASCII Art section above and `reference/diagrams-and-charts.md` for the full pattern.

### Menlo Font Not Found
**Cause**: Running on Linux or font path changed.
**Fix**: Fall back to DejaVu Sans Mono or Courier. On Linux, check `/usr/share/fonts/` for TTF monospace fonts with Unicode coverage.

### PDF File Size Increased
**Cause**: TTF font subset embedded in PDF (expected).
**Impact**: Typically 10-20KB increase. Acceptable tradeoff for correct rendering.
