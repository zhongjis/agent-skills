# ReportLab Internal Cross-References

## Overview

ReportLab Platypus Paragraph objects support HTML-like `<a>` tags for both anchor definitions and hyperlinks. This enables clickable internal cross-references within a PDF — table of contents links, section references, and finding ID links.

## Anchor Definitions

Place anchors on elements you want to link TO:

```python
# Anchor on a heading
heading_text = '<a name="section_3"/>3. Architecture Assessment'
story.append(Paragraph(heading_text, styles["H2"]))

# Anchor on a finding ID in a table cell
cell_text = '<a name="finding_Q1"/>Q1'
```

### Anchor Naming Convention

Use a consistent naming scheme so anchors and links always match:

```python
import re

def make_anchor_key(heading_text: str) -> str:
    """Convert heading text to anchor key.

    '3. Architecture Assessment' -> 'section_3'
    'Executive Summary'          -> 'executive_summary'
    'Appendix A: Finding Index'  -> 'appendix_a'
    """
    text = heading_text.strip()

    # Numbered sections: "N. Title" -> section_N
    m = re.match(r'^(\d+)\.', text)
    if m:
        return f"section_{m.group(1)}"

    # Appendices: "Appendix A" -> appendix_a
    m = re.match(r'^Appendix\s+([A-Z])', text, re.IGNORECASE)
    if m:
        return f"appendix_{m.group(1).lower()}"

    # Named sections: "Executive Summary" -> executive_summary
    return re.sub(r'[^a-z0-9]+', '_', text.lower()).strip('_')
```

## Hyperlinks

Link FROM text TO an anchor:

```python
# Link in body text
text = 'This violates the convention (see <a href="#finding_Q1" color="#1565C0">Q1</a>)'
story.append(Paragraph(text, styles["Normal"]))

# Link in TOC
toc_entry = '<a href="#section_3" color="#1565C0">3. Architecture Assessment</a>'
```

**Important**: The `color` attribute on the `<a>` tag sets the link text color. Without it, links render in the paragraph's default color (usually black) and are visually indistinguishable from normal text.

## Automatic Cross-Reference Linking

For documents with many cross-references, apply regex substitution to auto-link patterns:

```python
import re

LINK_COLOR = "#1565C0"

def linkify_cross_refs(text: str) -> str:
    """Replace cross-reference patterns with clickable links."""

    # "see section N" / "See section N"
    text = re.sub(
        r'([Ss]ee\s+)(?:section|Section|§)\s*(\d+)',
        rf'\1<a href="#section_\2" color="{LINK_COLOR}">§\2</a>',
        text
    )

    # "(see Q1)" / "(see A2)" / "(see S3)" etc.
    text = re.sub(
        r'\(see\s+([A-Z]\d+)\)',
        rf'(see <a href="#finding_\1" color="{LINK_COLOR}">\1</a>)',
        text
    )

    # "see Appendix A" / "See Appendix B"
    text = re.sub(
        r'([Ss]ee\s+)[Aa]ppendix\s+([A-Z])',
        lambda m: f'{m.group(1)}<a href="#appendix_{m.group(2).lower()}" color="{LINK_COLOR}">Appendix {m.group(2)}</a>',
        text
    )

    return text
```

### Where to Apply

Apply `linkify_cross_refs()` to:
- Body paragraphs
- Bullet point text
- Table cells (row > 0 only — skip header row to avoid linking column headers)

Do NOT apply to:
- Headings (they contain anchors, not links)
- Code blocks (literal text, no linking)
- Table header rows

## Table of Contents with Links

Generate a TOC page with clickable entries that jump to section anchors:

```python
from reportlab.platypus import Paragraph, Spacer, PageBreak
from reportlab.graphics.shapes import Drawing, Rect
from reportlab.lib.colors import HexColor

def extract_toc_entries(markdown_text: str) -> list[tuple[str, str, bool]]:
    """Extract TOC entries from Markdown headings.

    Returns: [(display_text, anchor_key, is_appendix), ...]
    """
    entries = []
    for line in markdown_text.splitlines():
        if line.startswith("## "):
            heading = line[3:].strip()
            anchor = make_anchor_key(heading)
            is_appendix = heading.lower().startswith("appendix")
            entries.append((heading, anchor, is_appendix))
    return entries

def add_toc(story, styles, toc_entries):
    """Add a Table of Contents page with clickable links."""
    # TOC title
    story.append(Paragraph("Table of Contents", styles["TocTitle"]))
    story.append(Spacer(1, 20))

    for display, anchor, is_appendix in toc_entries:
        style = styles["TocEntryAppendix"] if is_appendix else styles["TocEntry"]
        link_text = f'<a href="#{anchor}" color="#1565C0">{display}</a>'
        story.append(Paragraph(link_text, style))

    story.append(PageBreak())
```

### TOC Styles

```python
from reportlab.lib.styles import ParagraphStyle

styles.add(ParagraphStyle(
    name="TocTitle", fontName="Helvetica-Bold", fontSize=22,
    leading=28, spaceAfter=12, textColor=HexColor("#111827")
))
styles.add(ParagraphStyle(
    name="TocEntry", fontName="Helvetica", fontSize=11,
    leading=18, leftIndent=10, textColor=HexColor("#1565C0"),
    spaceBefore=4
))
styles.add(ParagraphStyle(
    name="TocEntryAppendix", fontName="Helvetica", fontSize=10,
    leading=16, leftIndent=10, textColor=HexColor("#1565C0"),
    spaceBefore=8  # Extra space before appendix section
))
```

## Troubleshooting

### Links Not Clickable
**Cause**: Anchor name mismatch between `<a name="..."/>` and `<a href="#...">`.
**Fix**: Use the same `make_anchor_key()` function for both anchor creation and link generation. Print both values during debugging to verify they match.

### Links Visually Invisible
**Cause**: Missing `color` attribute on `<a href>` tag.
**Fix**: Always include `color="#1565C0"` (or your chosen link color) in the `<a>` tag.

### Anchor on Wrong Page
**Cause**: Anchor attached to a flowable that got pushed to the next page by ReportLab's layout engine.
**Fix**: Attach anchors to the heading Paragraph itself (not a Spacer before it). The anchor travels with its parent flowable.
