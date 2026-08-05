# Markdown-to-PDF Conversion with ReportLab

## Overview

Patterns for converting Markdown documents to professional PDFs using ReportLab's Platypus framework. These patterns handle headings, tables, code blocks, bullet lists, and section page breaks.

## Document Structure

```python
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate

doc = SimpleDocTemplate(
    "output.pdf",
    pagesize=letter,
    topMargin=54,      # 0.75 inch
    bottomMargin=54,
    leftMargin=54,
    rightMargin=54,
)

story = []
# ... add flowables to story ...
doc.build(story)
```

## Section Page Breaks

Insert a `PageBreak` before each major heading so every section starts on its own page.

```python
from reportlab.platypus import PageBreak

first_heading_seen = False

for line in markdown_lines:
    if line.startswith("## "):
        if first_heading_seen:
            story.append(PageBreak())
        first_heading_seen = True
        # ... render heading ...
```

**Why `first_heading_seen`**: The first heading typically follows a cover page or TOC that already ends with a `PageBreak`. Without this guard, you get a blank page between the TOC and the first section.

## Heading Detection and Rendering

```python
import re

def detect_heading(line: str) -> tuple[int, str] | None:
    """Detect Markdown heading level and text.

    Returns (level, text) or None.
    """
    m = re.match(r'^(#{1,6})\s+(.+)$', line)
    if m:
        level = len(m.group(1))
        text = m.group(2).strip()
        return level, text
    return None
```

### Heading Styles

```python
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.colors import HexColor

styles.add(ParagraphStyle(name="H1", fontName="Helvetica-Bold", fontSize=20,
                          leading=26, spaceBefore=20, spaceAfter=10,
                          textColor=HexColor("#111827")))
styles.add(ParagraphStyle(name="H2", fontName="Helvetica-Bold", fontSize=16,
                          leading=22, spaceBefore=16, spaceAfter=8,
                          textColor=HexColor("#1F2937")))
styles.add(ParagraphStyle(name="H3", fontName="Helvetica-Bold", fontSize=13,
                          leading=18, spaceBefore=12, spaceAfter=6,
                          textColor=HexColor("#374151")))
```

## Markdown Table Parsing

Parse pipe-delimited Markdown tables with separator row detection:

```python
def parse_markdown_table(lines: list[str]) -> list[list[str]] | None:
    """Parse consecutive Markdown table lines into a 2D list.

    Expects: | Header | ... |
             |--------|-----|
             | Cell   | ... |

    Returns list of rows (each row is a list of cell strings), or None if not a table.
    """
    if len(lines) < 2:
        return None

    rows = []
    for i, line in enumerate(lines):
        line = line.strip()
        if not line.startswith("|"):
            break

        # Skip separator row (|---|---|)
        if re.match(r'^\|[\s\-:|]+\|$', line):
            continue

        cells = [cell.strip() for cell in line.split("|")[1:-1]]
        rows.append(cells)

    return rows if len(rows) >= 2 else None
```

### Table Rendering

```python
from reportlab.platypus import Table, TableStyle
from reportlab.lib import colors

def render_table(rows: list[list[str]], page_width: float) -> Table:
    """Render a parsed Markdown table as a ReportLab Table."""
    num_cols = len(rows[0])
    col_width = (page_width - 108) / num_cols  # 108 = left + right margin

    table = Table(rows, colWidths=[col_width] * num_cols)

    style_commands = [
        # Header row
        ('BACKGROUND', (0, 0), (-1, 0), HexColor("#E5E7EB")),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('LEADING', (0, 0), (-1, -1), 13),
        ('TEXTCOLOR', (0, 0), (-1, -1), HexColor("#111827")),
        # Grid
        ('GRID', (0, 0), (-1, -1), 0.5, HexColor("#D1D5DB")),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
    ]

    # Alternating row shading
    for row_idx in range(1, len(rows)):
        if row_idx % 2 == 0:
            style_commands.append(
                ('BACKGROUND', (0, row_idx), (-1, row_idx), HexColor("#F9FAFB"))
            )

    table.setStyle(TableStyle(style_commands))
    return table
```

**Important**: Wrap cell text in Paragraph objects if cells may contain HTML markup (bold, links, severity colors). Plain strings work for simple text.

```python
from reportlab.platypus import Paragraph

# For cells with possible markup
cell_style = ParagraphStyle(name="TableCell", fontName="Helvetica", fontSize=9, leading=13)
paragraph_rows = []
for i, row in enumerate(rows):
    paragraph_row = []
    for cell in row:
        processed = normalize_text(cell)
        if i > 0:  # Skip header row for cross-ref linking
            processed = linkify_cross_refs(processed)
        paragraph_row.append(Paragraph(processed, cell_style))
    paragraph_rows.append(paragraph_row)
```

## Code Block Rendering

Detect fenced code blocks (triple backtick) and render with monospace font on a light background:

```python
def render_code_block(code_lines: list[str], styles) -> list:
    """Render a fenced code block as a styled Paragraph."""
    # Use normalize_code_text — NOT normalize_text
    escaped_lines = [normalize_code_text(line) for line in code_lines]
    code_text = "<br/>".join(escaped_lines)

    # Wrap in a Paragraph with Code style
    return Paragraph(code_text, styles["Code"])
```

### Code Block Style

```python
styles.add(ParagraphStyle(
    name="Code",
    fontName=CODE_FONT,   # Menlo on macOS, Courier fallback
    fontSize=8,
    leading=11,
    leftIndent=10,
    rightIndent=10,
    spaceBefore=6,
    spaceAfter=6,
    backColor=HexColor("#F3F4F6"),  # Light gray background
    borderPadding=8,
    # Note: borderPadding adds internal padding within the background
))
```

### Code Block Detection State Machine

```python
import re

in_code_block = False
code_lines = []
code_lang = None  # Track language hint from opening fence

for line in markdown_lines:
    if line.strip().startswith("```"):
        if in_code_block:
            # End of code block — route based on content type
            story.extend(render_code_or_diagram(code_lines, code_lang, styles))
            code_lines = []
            code_lang = None
            in_code_block = False
        else:
            # Extract language hint: ```python, ```mermaid, etc.
            fence_match = re.match(r'^```(\w+)?', line.strip())
            code_lang = fence_match.group(1) if fence_match and fence_match.group(1) else None
            in_code_block = True
        continue

    if in_code_block:
        code_lines.append(line.rstrip("\n"))
        continue

    # ... handle other Markdown elements ...
```

### Diagram-Aware Code Block Routing

Detect Mermaid blocks and ASCII art, routing them to appropriate renderers instead of treating all fenced blocks as plain code.

```python
def is_ascii_art(lines):
    """Detect if code block contains ASCII art / box-drawing characters."""
    BOX_CHARS = set("┌┐└┘├┤┬┴┼─│═║╔╗╚╝╠╣╦╩╬")
    ASCII_ART_CHARS = set("+|\\/-")
    total_chars = sum(len(line) for line in lines)
    if total_chars == 0:
        return False
    box_count = sum(1 for line in lines for ch in line if ch in BOX_CHARS)
    ascii_art_count = sum(1 for line in lines for ch in line if ch in ASCII_ART_CHARS)
    # Heuristic: >10% box-drawing chars, or >20% ASCII art chars with alignment patterns
    if box_count / max(total_chars, 1) > 0.10:
        return True
    if ascii_art_count / max(total_chars, 1) > 0.20:
        # Check for alignment patterns (multiple lines with chars at same column positions)
        return any(line.count('+') >= 2 or line.count('|') >= 2 for line in lines)
    return False

def render_code_or_diagram(code_lines, lang, styles):
    """
    Route a fenced code block to the appropriate renderer.

    Returns a list of Flowables.
    """
    from reportlab.platypus import Spacer

    # Mermaid diagrams → SVG → embedded Drawing
    if lang == "mermaid":
        # See reference/diagrams-and-charts.md for render_mermaid_to_flowable()
        try:
            from diagrams_and_charts import render_mermaid_to_flowable
            mermaid_code = "\n".join(code_lines)
            drawing = render_mermaid_to_flowable(mermaid_code)
            return [drawing, Spacer(1, 8)]
        except Exception:
            # Fallback: render as plain code block with a note
            fallback = render_code_block(code_lines, styles)
            return [fallback]

    # ASCII art → canvas text object (spatial alignment preserved)
    if is_ascii_art(code_lines):
        # See reference/diagrams-and-charts.md for draw_ascii_art_with_background()
        # In Platypus flow, reserve space with a Spacer and draw in afterPage hook
        # Simplified: render as code block with Courier font forced
        return [render_code_block(code_lines, styles)]
        # NOTE: For perfect alignment, use canvas.beginText() approach from
        # reference/diagrams-and-charts.md Tier 1 and reference/unicode-and-fonts.md

    # Regular code → standard code block rendering
    return [render_code_block(code_lines, styles)]
```

**Important**: The ASCII art detection is a heuristic. For guaranteed alignment, use the `canvas.beginText()` approach from `reference/diagrams-and-charts.md` (Tier 1) when building the PDF directly (not through the Markdown pipeline). The Markdown pipeline provides best-effort detection and routing.

## Bullet List Rendering

```python
def render_bullet(text: str, level: int, styles) -> Paragraph:
    """Render a Markdown bullet point."""
    indent = 20 + (level * 15)
    bullet_char = "\u2022" if level == 0 else "-"  # Use replace_unicode for body

    style = ParagraphStyle(
        name=f"Bullet_{level}",
        parent=styles["Normal"],
        leftIndent=indent,
        firstLineIndent=-10,
        spaceBefore=2,
        spaceAfter=2,
    )

    processed = normalize_text(text)
    return Paragraph(f"{bullet_char} {processed}", style)
```

### Bullet Detection

```python
def detect_bullet(line: str) -> tuple[int, str] | None:
    """Detect bullet point level and text.

    Returns (indent_level, text) or None.
    """
    m = re.match(r'^(\s*)[*\-+]\s+(.+)$', line)
    if m:
        spaces = len(m.group(1))
        level = spaces // 2  # 2 spaces per indent level
        return level, m.group(2)
    return None
```

## Full Markdown-to-Story Pipeline

```python
def build_story(markdown_text: str, styles) -> list:
    """Convert Markdown text to a list of ReportLab flowables."""
    story = []
    lines = markdown_text.splitlines()
    i = 0
    in_code_block = False
    code_lines = []
    code_lang = None
    first_heading_seen = False

    while i < len(lines):
        line = lines[i]

        # Code block toggle (with language detection)
        if line.strip().startswith("```"):
            if in_code_block:
                # Route based on content type (mermaid, ASCII art, or plain code)
                story.extend(render_code_or_diagram(code_lines, code_lang, styles))
                code_lines = []
                code_lang = None
                in_code_block = False
            else:
                fence_match = re.match(r'^```(\w+)?', line.strip())
                code_lang = fence_match.group(1) if fence_match and fence_match.group(1) else None
                in_code_block = True
            i += 1
            continue

        if in_code_block:
            code_lines.append(line.rstrip("\n"))
            i += 1
            continue

        # Heading
        heading = detect_heading(line)
        if heading:
            level, text = heading
            if level <= 2 and first_heading_seen:
                story.append(PageBreak())
            first_heading_seen = True
            style_name = "H1" if level == 1 else "H2" if level == 2 else "H3"
            story.append(Paragraph(normalize_text(text), styles[style_name]))
            i += 1
            continue

        # Table (look ahead for pipe-delimited block)
        if line.strip().startswith("|"):
            table_lines = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                table_lines.append(lines[i])
                i += 1
            rows = parse_markdown_table(table_lines)
            if rows:
                story.append(render_table(rows, letter[0]))
            continue

        # Bullet
        bullet = detect_bullet(line)
        if bullet:
            level, text = bullet
            story.append(render_bullet(text, level, styles))
            i += 1
            continue

        # Body paragraph
        text = line.strip()
        if text:
            processed = linkify_cross_refs(normalize_text(text))
            story.append(Paragraph(processed, styles["Normal"]))

        i += 1

    return story
```

## Troubleshooting

### Blank Pages Between Sections
**Cause**: Double `PageBreak` — one from TOC/cover and one from the heading handler.
**Fix**: Use `first_heading_seen` flag to skip the first `PageBreak`.

### Table Overflows Page Width
**Cause**: Too many columns or fixed column widths exceed available space.
**Fix**: Calculate `col_width = available_width / num_cols`. For tables with many columns, reduce font size to 8pt.

### Code Block Background Not Showing
**Cause**: Using `Canvas.drawString()` instead of `Paragraph` with `backColor`.
**Fix**: Always use Platypus `Paragraph` objects for code blocks. The `backColor` style property handles the background.

### ASCII Art / Flowchart Alignment Broken in Code Block
**Cause**: `Paragraph`-based code blocks reflow text to fit column width, destroying spatial alignment.
**Fix**: Use `canvas.beginText()` with `Courier` and `setCharSpace(0)` for ASCII art. See `reference/diagrams-and-charts.md` (Tier 1) and `reference/unicode-and-fonts.md` (ASCII Art section) for the full pattern.

### Mermaid Block Not Rendering as Diagram
**Cause**: Missing mermaid-cli (`mmdc`) or `svglib` not installed.
**Fix**: Install `@mermaid-js/mermaid-cli` (npm) and `svglib` (pip). The pipeline falls back to rendering Mermaid as a plain code block when tools are unavailable. See `reference/diagrams-and-charts.md` (Tier 3).

### Bullet Points Misaligned
**Cause**: `firstLineIndent` not set or wrong sign.
**Fix**: Use negative `firstLineIndent` (e.g., `-10`) to hang the bullet character, with `leftIndent` providing the overall indent.
