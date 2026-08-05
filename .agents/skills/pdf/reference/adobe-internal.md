# Adobe Internal PDF Report Standards

**WHEN TO USE**: Apply these rules whenever producing PDF documents for Adobe internal use. Trigger phrases: "Adobe internal", "Adobe confidential", "internal report", "Adobe-branded", or any context where the document is intended for Adobe employees or internal distribution.

These rules are MANDATORY and override default styling when an Adobe internal document is being produced.

## Adobe Brand Colors

| Element | Hex | Usage |
|---------|-----|-------|
| **Adobe Red** | `#EB1000` | Accent bars, cover elements, confidential text |
| **CRITICAL severity** | `#CC0000` | Dark red for critical findings |
| **HIGH severity** | `#CC6600` | Dark orange for high findings |
| **MEDIUM severity** | `#CC9900` | Dark yellow for medium findings |
| **LOW severity** | `#336699` | Steel blue for low findings |
| **Cross-ref link** | `#1565C0` | Blue for internal hyperlinks |
| **Cover notice** | `#6B7280` | Gray for italic notices |

## Cover Page (MANDATORY)

Every Adobe internal PDF MUST have a cover page with these 6 elements:

1. **Title**: Large bold text (Helvetica-Bold, 28pt)
2. **Subtitle**: Descriptive subtitle below title (16pt, gray)
3. **Author**: Full name (e.g., "Author: Zhongjie Shen")
4. **Generation timestamp**: `datetime.now().strftime("%Y-%m-%d %H:%M:%S %Z")`
5. **Git branch**: Via `git rev-parse --abbrev-ref HEAD` (shows document provenance)
6. **AI-Generated notice**: If AI-generated, display italic gray text: "This report was generated with AI assistance. All findings have been verified against the source code."
7. **Confidential marking**: "ADOBE CONFIDENTIAL" in Adobe Red at the bottom of the cover page

### Cover Page Layout

```python
def add_cover(story, styles):
    # Red accent bar at top
    d = Drawing(page_width, 4)
    d.add(Rect(0, 0, page_width, 4, fillColor=HexColor("#EB1000"), strokeColor=None))
    story.append(d)
    story.append(Spacer(1, 80))

    # Title
    story.append(Paragraph("Report Title", styles["CoverTitle"]))
    story.append(Spacer(1, 12))

    # Subtitle
    story.append(Paragraph("Subtitle description", styles["CoverSubtitle"]))
    story.append(Spacer(1, 40))

    # Thin divider
    d = Drawing(page_width, 1)
    d.add(Rect(0, 0, 200, 1, fillColor=HexColor("#D1D5DB"), strokeColor=None))
    story.append(d)
    story.append(Spacer(1, 20))

    # Metadata
    story.append(Paragraph("Author: Name", styles["CoverMeta"]))
    story.append(Paragraph("Generated: 2026-03-10 ...", styles["CoverMeta"]))
    story.append(Paragraph("Branch: feature/...", styles["CoverMeta"]))
    story.append(Spacer(1, 20))

    # AI notice (italic gray)
    story.append(Paragraph("AI-generated notice...", styles["CoverNotice"]))
    story.append(Spacer(1, 40))

    # Confidential
    story.append(Paragraph("ADOBE CONFIDENTIAL", styles["Confidential"]))
    story.append(PageBreak())
```

### Cover Page Styles

```python
styles.add(ParagraphStyle(name="CoverTitle", fontName="Helvetica-Bold", fontSize=28,
                          leading=34, textColor=HexColor("#111827")))
styles.add(ParagraphStyle(name="CoverSubtitle", fontName="Helvetica", fontSize=16,
                          leading=22, textColor=HexColor("#4B5563")))
styles.add(ParagraphStyle(name="CoverMeta", fontName="Helvetica", fontSize=11,
                          leading=16, textColor=HexColor("#374151")))
styles.add(ParagraphStyle(name="CoverNotice", fontName="Helvetica-Oblique", fontSize=9,
                          leading=13, textColor=HexColor("#6B7280")))
styles.add(ParagraphStyle(name="Confidential", fontName="Helvetica-Bold", fontSize=12,
                          textColor=HexColor("#EB1000")))
```

## Headers and Footers (MANDATORY)

Every page (except cover) MUST have:

- **Header left**: Report title (Helvetica, 8pt, gray)
- **Header right**: "ADOBE CONFIDENTIAL" (Helvetica-Bold, 8pt, Adobe Red)
- **Footer center**: Page number "Page X" (8pt)
- **Footer right**: "Adobe - Internal Use Only" (7pt, gray)

### Implementation

```python
def header_footer(canvas, doc):
    canvas.saveState()
    page_num = canvas.getPageNumber()
    if page_num == 1:
        canvas.restoreState()
        return  # Skip cover page

    width, height = letter

    # Header
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(HexColor("#6B7280"))
    canvas.drawString(54, height - 40, "Report Title Here")
    canvas.setFont("Helvetica-Bold", 8)
    canvas.setFillColor(HexColor("#EB1000"))
    canvas.drawRightString(width - 54, height - 40, "ADOBE CONFIDENTIAL")

    # Header line
    canvas.setStrokeColor(HexColor("#E5E7EB"))
    canvas.line(54, height - 45, width - 54, height - 45)

    # Footer
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(HexColor("#6B7280"))
    canvas.drawCentredString(width / 2, 35, f"Page {page_num}")
    canvas.setFont("Helvetica", 7)
    canvas.drawRightString(width - 54, 35, "Adobe - Internal Use Only")

    canvas.restoreState()
```

Wire into `SimpleDocTemplate.build()`:
```python
doc.build(story, onFirstPage=header_footer, onLaterPages=header_footer)
```

## Page Layout

| Setting | Value |
|---------|-------|
| Page size | US Letter (8.5" x 11") |
| Top margin | 0.75" (54pt) |
| Bottom margin | 0.75" (54pt) |
| Left margin | 0.75" (54pt) |
| Right margin | 0.75" (54pt) |

## Score Bars (for Audit Reports)

When rendering `X / 10` or `X/10` scores in headings, display a visual bar:

```python
def make_score_bar(score, max_score=10, width=180, height=10):
    d = Drawing(width + 40, height + 4)
    # Background
    d.add(Rect(0, 2, width, height, fillColor=HexColor("#E5E7EB"), strokeColor=None))
    # Filled portion — color gradient from red (low) to green (high)
    ratio = score / max_score
    if ratio >= 0.7:
        color = HexColor("#22C55E")  # Green
    elif ratio >= 0.5:
        color = HexColor("#F59E0B")  # Amber
    else:
        color = HexColor("#EF4444")  # Red
    d.add(Rect(0, 2, width * ratio, height, fillColor=color, strokeColor=None))
    # Score label
    d.add(String(width + 8, 2, f"{score}/{max_score}",
                 fontName="Helvetica-Bold", fontSize=9, fillColor=HexColor("#374151")))
    return d
```

## Severity Color Coding

When table cells or headings contain severity keywords, apply the corresponding color:

```python
SEVERITY_COLORS = {
    "CRITICAL": "#CC0000",
    "HIGH":     "#CC6600",
    "MEDIUM":   "#CC9900",
    "LOW":      "#336699",
}

def apply_severity_color(text):
    for severity, color in SEVERITY_COLORS.items():
        if severity in text.upper():
            return f'<font color="{color}"><b>{text}</b></font>'
    return text
```

## Finding ID Anchors (for Audit Reports)

In audit tables, the first column often contains finding IDs like `A1`, `S3`, `Q7`, `T2`, `M1`. Add anchors for cross-referencing:

```python
import re

def maybe_add_finding_anchor(cell_text):
    """Add anchor if cell contains a finding ID pattern."""
    if re.match(r'^[A-Z]\d+$', cell_text.strip()):
        fid = cell_text.strip()
        return f'<a name="finding_{fid}"/>{cell_text}'
    return cell_text
```

## Environment Setup

```bash
VENV_PATH="/tmp/pdf-venv"
if [ ! -f "$VENV_PATH/bin/python3" ]; then
    python3 -m venv "$VENV_PATH"
    "$VENV_PATH/bin/pip" install reportlab==4.4.10 pdfplumber
fi
```

## Verification Checklist

After generating an Adobe internal PDF, verify with the `look_at` tool:

1. Cover page has all 6 elements (title, author, timestamp, branch, AI notice, confidential)
2. TOC is on page 2 with all section entries as clickable links
3. Each major section starts on its own page
4. No black boxes anywhere (see `reference/unicode-and-fonts.md`)
5. Cross-reference links are blue and functional (see `reference/cross-references.md`)
6. Tables render with proper formatting and severity colors
7. Code blocks use monospace font with Unicode characters preserved
8. ASCII art / box-drawing diagrams preserve spatial alignment (see `reference/diagrams-and-charts.md`)
9. Charts and diagrams render as proper graphical elements (see `reference/diagrams-and-charts.md`)
10. Headers show "ADOBE CONFIDENTIAL" on every page (except cover)
11. Footers show page numbers and "Adobe - Internal Use Only"

## Diagrams in Adobe Reports

Use the standard diagram rendering approaches from `reference/diagrams-and-charts.md`, but apply Adobe brand colors:

```python
# Override the neutral palette with Adobe brand colors for internal reports
ADOBE_DIAGRAM_COLORS = {
    "node_fill": HexColor("#FFF5F5"),       # Light red tint
    "node_stroke": HexColor("#EB1000"),      # Adobe Red
    "node_text": HexColor("#111827"),        # Near-black
    "arrow": HexColor("#374151"),            # Gray 700
    "highlight_fill": HexColor("#FEE2E2"),   # Red 100
    "highlight_stroke": HexColor("#EB1000"), # Adobe Red
    "label": HexColor("#6B7280"),            # Gray 500
}
```

For score bars and accent bars, continue using the `Drawing`/`Rect`/`String` patterns defined in this file. For flowcharts, architecture diagrams, and data charts, follow the tiered approach in `reference/diagrams-and-charts.md`.
