---
name: pdf
description: Use this skill whenever the user wants to do anything with PDF files. This includes reading or extracting text/tables from PDFs, combining or merging multiple PDFs into one, splitting PDFs apart, rotating pages, adding watermarks, creating new PDFs, filling PDF forms, encrypting/decrypting PDFs, extracting images, and OCR on scanned PDFs to make them searchable. If the user mentions a .pdf file or asks to produce one, use this skill.
upstream: "https://github.com/anthropics/skills/tree/main/skills/pdf"
---

# PDF Processing Guide

## Overview

This guide covers essential PDF processing operations using Python libraries and command-line tools. For advanced features, JavaScript libraries, and detailed examples, see `reference/advanced.md`. If you need to fill out a PDF form, read FORMS.md and follow its instructions.

## Quick Start

```python
from pypdf import PdfReader, PdfWriter

# Read a PDF
reader = PdfReader("document.pdf")
print(f"Pages: {len(reader.pages)}")

# Extract text
text = ""
for page in reader.pages:
    text += page.extract_text()
```

## Python Libraries

### pypdf - Basic Operations

#### Merge PDFs
```python
from pypdf import PdfWriter, PdfReader

writer = PdfWriter()
for pdf_file in ["doc1.pdf", "doc2.pdf", "doc3.pdf"]:
    reader = PdfReader(pdf_file)
    for page in reader.pages:
        writer.add_page(page)

with open("merged.pdf", "wb") as output:
    writer.write(output)
```

#### Split PDF
```python
reader = PdfReader("input.pdf")
for i, page in enumerate(reader.pages):
    writer = PdfWriter()
    writer.add_page(page)
    with open(f"page_{i+1}.pdf", "wb") as output:
        writer.write(output)
```

#### Extract Metadata
```python
reader = PdfReader("document.pdf")
meta = reader.metadata
print(f"Title: {meta.title}")
print(f"Author: {meta.author}")
print(f"Subject: {meta.subject}")
print(f"Creator: {meta.creator}")
```

#### Rotate Pages
```python
reader = PdfReader("input.pdf")
writer = PdfWriter()

page = reader.pages[0]
page.rotate(90)  # Rotate 90 degrees clockwise
writer.add_page(page)

with open("rotated.pdf", "wb") as output:
    writer.write(output)
```

### pdfplumber - Text and Table Extraction

#### Extract Text with Layout
```python
import pdfplumber

with pdfplumber.open("document.pdf") as pdf:
    for page in pdf.pages:
        text = page.extract_text()
        print(text)
```

#### Extract Tables
```python
with pdfplumber.open("document.pdf") as pdf:
    for i, page in enumerate(pdf.pages):
        tables = page.extract_tables()
        for j, table in enumerate(tables):
            print(f"Table {j+1} on page {i+1}:")
            for row in table:
                print(row)
```

#### Advanced Table Extraction
```python
import pandas as pd

with pdfplumber.open("document.pdf") as pdf:
    all_tables = []
    for page in pdf.pages:
        tables = page.extract_tables()
        for table in tables:
            if table:  # Check if table is not empty
                df = pd.DataFrame(table[1:], columns=table[0])
                all_tables.append(df)

# Combine all tables
if all_tables:
    combined_df = pd.concat(all_tables, ignore_index=True)
    combined_df.to_excel("extracted_tables.xlsx", index=False)
```

### reportlab - Create PDFs

#### Basic PDF Creation
```python
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas

c = canvas.Canvas("hello.pdf", pagesize=letter)
width, height = letter

# Add text
c.drawString(100, height - 100, "Hello World!")
c.drawString(100, height - 120, "This is a PDF created with reportlab")

# Add a line
c.line(100, height - 140, 400, height - 140)

# Save
c.save()
```

#### Create PDF with Multiple Pages
```python
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.styles import getSampleStyleSheet

doc = SimpleDocTemplate("report.pdf", pagesize=letter)
styles = getSampleStyleSheet()
story = []

# Add content
title = Paragraph("Report Title", styles['Title'])
story.append(title)
story.append(Spacer(1, 12))

body = Paragraph("This is the body of the report. " * 20, styles['Normal'])
story.append(body)
story.append(PageBreak())

# Page 2
story.append(Paragraph("Page 2", styles['Heading1']))
story.append(Paragraph("Content for page 2", styles['Normal']))

# Build PDF
doc.build(story)
```

#### Unicode & Font Rendering (CRITICAL)

ReportLab's built-in fonts (Helvetica, Courier) **cannot render** most Unicode characters — box-drawing (`┌─┐│`), arrows (`→←`), dashes (`—–`), smart quotes (`''""`), block elements (`█▓`), and subscript/superscript digits (`₀¹²³`) all render as **solid black boxes**.

**Two-track solution:**
- **Body text** (Helvetica): Replace all Unicode with ASCII equivalents before rendering
- **Code blocks**: Register a TrueType font (Menlo on macOS, DejaVu Sans Mono on Linux) that supports Unicode glyphs

**You MUST maintain two separate normalizer functions** — one for body text (replaces Unicode) and one for code blocks (preserves Unicode). Using the wrong one causes either black boxes or degraded ASCII art.

For the full Unicode replacement map, font registration code, and normalizer implementations, see `reference/unicode-and-fonts.md`.

**Subscripts/Superscripts**: Never use Unicode sub/superscript characters. Use ReportLab's XML tags instead:
```python
# Subscripts: use <sub> tag
chemical = Paragraph("H<sub>2</sub>O", styles['Normal'])

# Superscripts: use <super> tag
squared = Paragraph("x<super>2</super> + y<super>2</super>", styles['Normal'])
```

### Professional Styling Defaults

Apply these defaults to ALL generated PDFs for consistent, professional output:

| Setting | Value | Notes |
|---------|-------|-------|
| **Page size** | US Letter (8.5" × 11") | `letter` from `reportlab.lib.pagesizes` |
| **Margins** | 1" (72pt) all sides | Or 0.75" (54pt) for dense content |
| **Body font** | Helvetica, 10–11pt | `leading` = font size × 1.2 |
| **H1** | Helvetica-Bold, 18pt | `spaceBefore=20, spaceAfter=10` |
| **H2** | Helvetica-Bold, 14pt | `spaceBefore=16, spaceAfter=8` |
| **H3** | Helvetica-Bold, 12pt | `spaceBefore=12, spaceAfter=6` |
| **Code font** | Menlo/Courier, 8–9pt | See `reference/unicode-and-fonts.md` |
| **Body text color** | `#333333` (dark gray) | Avoid pure black — easier on eyes |
| **Heading color** | `#111827` (near-black) | Slightly darker than body |
| **Separator lines** | 0.5pt, `#D1D5DB` | Subtle, not distracting |
| **Link color** | `#1565C0` (blue) | Consistent with cross-references |

```python
from reportlab.lib.colors import HexColor

# Professional color palette
COLORS = {
    "body_text":   HexColor("#333333"),
    "heading":     HexColor("#111827"),
    "separator":   HexColor("#D1D5DB"),
    "link":        HexColor("#1565C0"),
    "code_bg":     HexColor("#F3F4F6"),
    "code_text":   HexColor("#1F2937"),
    "table_header_bg": HexColor("#E5E7EB"),
    "table_alt_row":   HexColor("#F9FAFB"),
    "table_grid":      HexColor("#D1D5DB"),
}
```

### Diagrams, Flowcharts & Charts

Use the right rendering approach based on content type:

| Content | Approach | When |
|---------|----------|------|
| ASCII art / box-drawing | `canvas.beginText()` + Courier | Preserve spatial alignment |
| Simple flowchart (≤5 nodes) | ReportLab `Drawing` + shapes | Native vector, no deps |
| Complex diagram (>5 nodes) | Mermaid → SVG → `svglib` | Scalable vector |
| Data charts (pie/bar/line) | `reportlab.graphics.charts` | Native vector |
| Architecture diagrams | `diagrams` library → PNG | Cloud/infra diagrams |
| Custom plots | Matplotlib → PNG/SVG | Scientific/custom |

**Critical**: Never use `Paragraph` for ASCII art or box-drawing diagrams — it reflows text and destroys alignment. Use `canvas.beginText()` with `Courier` font and `setCharSpace(0)`.

For complete code patterns, decision tree, and examples, see `reference/diagrams-and-charts.md`.

### Inline Annotations

Add styled callout boxes (note, warning, tip, callout) to highlight important information in generated PDFs. Each style has a distinct background color, border, and icon. See `reference/diagrams-and-charts.md` for the `create_annotation()` function and `ANNOTATION_STYLES` palette.

## Command-Line Tools

### pdftotext (poppler-utils)
```bash
# Extract text
pdftotext input.pdf output.txt

# Extract text preserving layout
pdftotext -layout input.pdf output.txt

# Extract specific pages
pdftotext -f 1 -l 5 input.pdf output.txt  # Pages 1-5
```

### qpdf
```bash
# Merge PDFs
qpdf --empty --pages file1.pdf file2.pdf -- merged.pdf

# Split pages
qpdf input.pdf --pages . 1-5 -- pages1-5.pdf
qpdf input.pdf --pages . 6-10 -- pages6-10.pdf

# Rotate pages
qpdf input.pdf output.pdf --rotate=+90:1  # Rotate page 1 by 90 degrees

# Remove password
qpdf --password=mypassword --decrypt encrypted.pdf decrypted.pdf
```

### pdftk (if available)
```bash
# Merge
pdftk file1.pdf file2.pdf cat output merged.pdf

# Split
pdftk input.pdf burst

# Rotate
pdftk input.pdf rotate 1east output rotated.pdf
```

## Common Tasks

### Extract Text from Scanned PDFs
```python
# Requires: pip install pytesseract pdf2image
import pytesseract
from pdf2image import convert_from_path

# Convert PDF to images
images = convert_from_path('scanned.pdf')

# OCR each page
text = ""
for i, image in enumerate(images):
    text += f"Page {i+1}:\n"
    text += pytesseract.image_to_string(image)
    text += "\n\n"

print(text)
```

### Add Watermark
```python
from pypdf import PdfReader, PdfWriter

# Create watermark (or load existing)
watermark = PdfReader("watermark.pdf").pages[0]

# Apply to all pages
reader = PdfReader("document.pdf")
writer = PdfWriter()

for page in reader.pages:
    page.merge_page(watermark)
    writer.add_page(page)

with open("watermarked.pdf", "wb") as output:
    writer.write(output)
```

### Extract Images
```bash
# Using pdfimages (poppler-utils)
pdfimages -j input.pdf output_prefix

# This extracts all images as output_prefix-000.jpg, output_prefix-001.jpg, etc.
```

### Password Protection
```python
from pypdf import PdfReader, PdfWriter

reader = PdfReader("input.pdf")
writer = PdfWriter()

for page in reader.pages:
    writer.add_page(page)

# Add password
writer.encrypt("userpassword", "ownerpassword")

with open("encrypted.pdf", "wb") as output:
    writer.write(output)
```

## Quick Reference

| Task | Best Tool | Command/Code |
|------|-----------|--------------|
| Merge PDFs | pypdf | `writer.add_page(page)` |
| Split PDFs | pypdf | One page per file |
| Extract text | pdfplumber | `page.extract_text()` |
| Extract tables | pdfplumber | `page.extract_tables()` |
| Create PDFs | reportlab | Canvas or Platypus |
| Diagrams & charts | reportlab.graphics | Shapes, Drawing, charts |
| Mermaid diagrams | mermaid-cli + svglib | `mmdc` → SVG → embed |
| ASCII art in PDF | canvas.beginText() | Courier + setCharSpace(0) |
| Command line merge | qpdf | `qpdf --empty --pages ...` |
| OCR scanned PDFs | pytesseract | Convert to image first |
| Fill PDF forms | pdf-lib or pypdf (see FORMS.md) | See FORMS.md |

## Next Steps

- For advanced pypdfium2 usage and JavaScript libraries, see `reference/advanced.md`
- If you need to fill out a PDF form, follow the instructions in FORMS.md
- For Unicode/font rendering details and the full replacement map, see `reference/unicode-and-fonts.md`
- For diagrams, flowcharts, charts, and inline annotations, see `reference/diagrams-and-charts.md`
- For internal cross-references and bookmarks in PDFs, see `reference/cross-references.md`
- For Markdown-to-PDF conversion (tables, code blocks, page breaks, TOC), see `reference/markdown-to-pdf.md`
- For Adobe-branded internal reports, see `reference/adobe-internal.md`
