# Diagrams, Flowcharts & Charts in PDF

Render visual content — flowcharts, architecture diagrams, data charts, and ASCII art — as proper graphical elements in generated PDFs.

## Decision Tree: Which Rendering Approach?

```
Is the visual content ASCII art / box-drawing text?
├─ YES → Tier 1: Canvas Text Object (preserves spatial alignment)
└─ NO → Is it a flowchart or architecture diagram?
    ├─ YES → How many nodes?
    │   ├─ ≤5 nodes → Tier 2: ReportLab Drawing Primitives
    │   └─ >5 nodes → Tier 3: Mermaid → SVG → PDF
    └─ NO → Is it a data chart (pie, bar, line)?
        ├─ YES → ReportLab Charts (see Charts section)
        └─ NO → Embed as Image (Matplotlib, diagrams library, etc.)
```

| Content Type | Approach | Complexity | Quality |
|---|---|---|---|
| ASCII art / box-drawing | Canvas `beginText()` + Courier | Low | Exact reproduction |
| Simple flowchart (≤5 nodes) | ReportLab `Drawing` + shapes | Medium | Native vector |
| Complex flowchart (>5 nodes) | Mermaid → SVG → `svglib` embed | Medium | Scalable vector |
| Data chart (pie/bar/line) | `reportlab.graphics.charts` | Medium | Native vector |
| Architecture diagram | `diagrams` library → PNG embed | Low | Raster (high-res) |
| Custom/scientific plot | Matplotlib → PNG/SVG embed | Medium | Publication quality |

---

## Tier 1: ASCII Art & Box-Drawing (Canvas Text Object)

**When**: The source content uses box-drawing characters (┌─┐│└┘), ASCII pipes/dashes, or any monospaced spatial layout that must preserve exact character alignment.

**Why not Paragraph?** ReportLab's `Paragraph` (used in Platypus story flow) reflows text to fit column width. This destroys horizontal alignment of side-by-side boxes, connectors, and any content where character position matters.

**The fix**: Bypass Platypus entirely. Use `canvas.beginText()` to place each line at exact coordinates with a guaranteed fixed-width font.

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

### Adding a Background Box

For code-block-style presentation with a background fill:

```python
def draw_ascii_art_with_background(canvas, x, y, art_text, font_size=10,
                                     leading=12, padding=8,
                                     bg_color=HexColor("#F3F4F6"),
                                     text_color=HexColor("#1F2937")):
    """Render ASCII art with a light background box, matching code block style."""
    lines = art_text.split('\n')
    max_width = max(len(line) for line in lines) * font_size * 0.6 + 2 * padding
    total_height = len(lines) * leading + 2 * padding

    # Draw background
    canvas.saveState()
    canvas.setFillColor(bg_color)
    canvas.roundRect(x - padding, y - total_height + padding,
                     max_width, total_height, radius=4, fill=1, stroke=0)
    canvas.restoreState()

    # Draw text
    canvas.saveState()
    canvas.setFillColor(text_color)
    textobject = canvas.beginText(x, y - leading)
    textobject.setFont("Courier", font_size)
    textobject.setCharSpace(0)
    textobject.setLeading(leading)
    for line in lines:
        textobject.textLine(line)
    canvas.drawText(textobject)
    canvas.restoreState()
```

### Calculating Space in Platypus Flow

When mixing ASCII art (canvas-drawn) with Platypus story elements, reserve vertical space:

```python
from reportlab.platypus import Spacer

def ascii_art_spacer(art_text, leading=12, padding=8):
    """Return a Spacer that reserves vertical space for canvas-drawn ASCII art."""
    line_count = art_text.count('\n') + 1
    height = line_count * leading + 2 * padding
    return Spacer(1, height)
```

In the `build_story()` pipeline, insert the spacer where the ASCII art should appear, then draw the actual art in a `canvasmaker` callback or `afterPage` hook.

### Key Rules

- **ALWAYS** use `Courier` for ASCII art — it's a PDF Core 14 font, guaranteed fixed-width, zero registration
- **ALWAYS** set `setCharSpace(0)` — prevents extra inter-character spacing
- **NEVER** use `Paragraph` for content where character position matters
- **NEVER** apply `normalize_text()` (Unicode→ASCII replacement) to ASCII art — use `normalize_code_text()` or no normalization

---

## Tier 2: ReportLab Drawing Primitives (Simple Flowcharts)

**When**: ≤5 nodes, simple topology (linear, tree, or single-loop). Native vector output, no external dependencies.

```python
from reportlab.graphics.shapes import Drawing, Rect, String, Line, Circle, Group
from reportlab.graphics import renderPDF
from reportlab.lib.colors import HexColor

# Professional palette — neutral, print-safe
COLORS = {
    "node_fill": HexColor("#F8FAFC"),       # Slate 50
    "node_stroke": HexColor("#64748B"),      # Slate 500
    "node_text": HexColor("#1E293B"),        # Slate 800
    "arrow": HexColor("#475569"),            # Slate 600
    "highlight_fill": HexColor("#EFF6FF"),   # Blue 50
    "highlight_stroke": HexColor("#3B82F6"), # Blue 500
    "label": HexColor("#94A3B8"),            # Slate 400
}

def create_flowchart_node(x, y, width, height, label, highlighted=False):
    """Create a single rounded-rectangle node with centered label."""
    g = Group()

    fill = COLORS["highlight_fill"] if highlighted else COLORS["node_fill"]
    stroke = COLORS["highlight_stroke"] if highlighted else COLORS["node_stroke"]

    # Rounded rectangle
    r = Rect(x, y, width, height, rx=6, ry=6,
             fillColor=fill, strokeColor=stroke, strokeWidth=1)
    g.add(r)

    # Centered label
    s = String(x + width / 2, y + height / 2 - 4, label,
               fontName="Helvetica", fontSize=10,
               fillColor=COLORS["node_text"], textAnchor="middle")
    g.add(s)

    return g

def create_arrow(x1, y1, x2, y2, label=None):
    """Create a connecting line with optional label. Add arrowhead manually."""
    g = Group()

    line = Line(x1, y1, x2, y2,
                strokeColor=COLORS["arrow"], strokeWidth=1.5)
    g.add(line)

    # Simple arrowhead (triangle at endpoint)
    import math
    angle = math.atan2(y2 - y1, x2 - x1)
    arrow_len = 8
    ax1 = x2 - arrow_len * math.cos(angle - 0.4)
    ay1 = y2 - arrow_len * math.sin(angle - 0.4)
    ax2 = x2 - arrow_len * math.cos(angle + 0.4)
    ay2 = y2 - arrow_len * math.sin(angle + 0.4)

    from reportlab.graphics.shapes import Polygon
    arrow = Polygon([x2, y2, ax1, ay1, ax2, ay2],
                    fillColor=COLORS["arrow"], strokeColor=COLORS["arrow"])
    g.add(arrow)

    if label:
        mid_x = (x1 + x2) / 2
        mid_y = (y1 + y2) / 2
        s = String(mid_x + 5, mid_y + 5, label,
                   fontName="Helvetica", fontSize=8,
                   fillColor=COLORS["label"])
        g.add(s)

    return g
```

### Example: 3-Node Linear Flow

```python
def build_simple_flow(nodes, width=500, node_w=120, node_h=40, spacing=60):
    """
    Build a left-to-right linear flowchart.

    Args:
        nodes: List of label strings, e.g. ["Input", "Process", "Output"]
    """
    total_w = len(nodes) * node_w + (len(nodes) - 1) * spacing
    d = Drawing(width, node_h + 40)

    x_start = (width - total_w) / 2
    y = 20

    for i, label in enumerate(nodes):
        x = x_start + i * (node_w + spacing)
        d.add(create_flowchart_node(x, y, node_w, node_h, label))

        if i < len(nodes) - 1:
            arrow_x1 = x + node_w
            arrow_x2 = x + node_w + spacing
            arrow_y = y + node_h / 2
            d.add(create_arrow(arrow_x1, arrow_y, arrow_x2, arrow_y))

    return d
```

### Embedding a Drawing in a Platypus Story

```python
from reportlab.platypus import SimpleDocTemplate, Spacer

story = []
# ... other story elements ...
flow_drawing = build_simple_flow(["Request", "Validate", "Process", "Response"])
story.append(flow_drawing)  # Drawing is a Flowable — drops right into story
story.append(Spacer(1, 12))
```

### Key Rules

- **≤5 nodes only** — beyond that, use Mermaid (Tier 3) for maintainability
- `Drawing` objects are Flowables — they integrate directly into Platypus story flow
- Use the neutral color palette above for professional output; override for branded reports
- `rx`/`ry` on `Rect` creates rounded corners — use 4–8pt for modern look

---

## Tier 3: Mermaid → SVG → PDF (Complex Diagrams)

**When**: >5 nodes, sequence diagrams, complex flowcharts, Gantt charts, ER diagrams — anything where hand-coding shapes is impractical.

### Pipeline

```
Mermaid code → mermaid-cli (mmdc) → SVG file → svglib → ReportLab Drawing → PDF
```

### Step 1: Generate Mermaid Code

Write the diagram in Mermaid syntax. For Markdown sources, detect ```` ```mermaid ```` fenced blocks.

```python
mermaid_code = """
graph TD
    A[Client Request] --> B{Auth Check}
    B -->|Valid| C[Load Balancer]
    B -->|Invalid| D[401 Response]
    C --> E[Service A]
    C --> F[Service B]
    E --> G[Aggregate]
    F --> G
    G --> H[Response]
"""
```

### Step 2: Convert to SVG

```python
import subprocess
import tempfile
from pathlib import Path

def mermaid_to_svg(mermaid_code, output_path=None):
    """
    Convert Mermaid diagram code to SVG using mermaid-cli.

    Requires: npm install -g @mermaid-js/mermaid-cli
    Or use: npx @mermaid-js/mermaid-cli (no global install)
    """
    if output_path is None:
        output_path = tempfile.mktemp(suffix=".svg")

    input_path = tempfile.mktemp(suffix=".mmd")
    Path(input_path).write_text(mermaid_code)

    subprocess.run(
        ["mmdc", "-i", input_path, "-o", output_path,
         "-t", "neutral", "-b", "transparent", "--scale", "2"],
        check=True,
        capture_output=True,
    )

    Path(input_path).unlink()  # Clean up temp input
    return output_path
```

**Theme options**: `default`, `neutral` (recommended for reports), `dark`, `forest`

### Step 3: Embed SVG in ReportLab

```python
from svglib.svglib import svg2rlg
from reportlab.graphics import renderPDF

def embed_svg_in_story(svg_path, max_width=450):
    """
    Convert SVG to a ReportLab Drawing Flowable for Platypus story insertion.

    Returns a Drawing object scaled to fit within max_width while preserving
    aspect ratio.
    """
    drawing = svg2rlg(svg_path)
    if drawing is None:
        raise ValueError(f"Failed to parse SVG: {svg_path}")

    # Scale to fit page width
    if drawing.width > max_width:
        scale = max_width / drawing.width
        drawing.width = max_width
        drawing.height *= scale
        drawing.scale(scale, scale)

    return drawing
```

### Full Pipeline Helper

```python
def render_mermaid_to_flowable(mermaid_code, max_width=450):
    """One-call pipeline: Mermaid code → ReportLab Drawing Flowable."""
    svg_path = mermaid_to_svg(mermaid_code)
    try:
        return embed_svg_in_story(svg_path, max_width)
    finally:
        Path(svg_path).unlink(missing_ok=True)
```

### Key Rules

- **Use `neutral` theme** for professional reports — avoids garish default colors
- **Scale to fit** — always constrain to page content width (typ. 450pt for letter with 1" margins)
- **Clean up temp files** — SVGs are intermediaries, delete after embedding
- `svglib` converts SVG to native ReportLab Drawing objects — output is vector, not raster
- If `mmdc` is unavailable, fall back to a note: "Diagram rendering requires mermaid-cli"

---

## Data Charts (ReportLab Graphics)

For pie charts, bar charts, and line plots using ReportLab's built-in charting.

### Pie Chart

```python
from reportlab.graphics.shapes import Drawing, String
from reportlab.graphics.charts.piecharts import Pie
from reportlab.lib.colors import HexColor

def create_pie_chart(data, labels, title=None, width=300, height=200):
    """
    Create a pie chart with professional color palette.

    Args:
        data: List of numeric values, e.g. [40, 30, 20, 10]
        labels: List of label strings, e.g. ["A", "B", "C", "D"]
    """
    d = Drawing(width, height)

    PALETTE = [
        HexColor("#3B82F6"),  # Blue 500
        HexColor("#10B981"),  # Emerald 500
        HexColor("#F59E0B"),  # Amber 500
        HexColor("#EF4444"),  # Red 500
        HexColor("#8B5CF6"),  # Violet 500
        HexColor("#EC4899"),  # Pink 500
        HexColor("#06B6D4"),  # Cyan 500
        HexColor("#84CC16"),  # Lime 500
    ]

    pie = Pie()
    pie.x = 50
    pie.y = 25
    pie.width = 120
    pie.height = 120
    pie.data = data
    pie.labels = labels
    pie.sideLabels = True
    pie.slices.strokeWidth = 0.5
    pie.slices.strokeColor = HexColor("#FFFFFF")

    for i in range(len(data)):
        pie.slices[i].fillColor = PALETTE[i % len(PALETTE)]

    d.add(pie)

    if title:
        d.add(String(width / 2, height - 15, title,
                      fontName="Helvetica-Bold", fontSize=11,
                      fillColor=HexColor("#1E293B"), textAnchor="middle"))

    return d
```

### Bar Chart

```python
from reportlab.graphics.charts.barcharts import VerticalBarChart

def create_bar_chart(data, categories, series_names=None,
                     title=None, width=400, height=250):
    """
    Create a vertical bar chart.

    Args:
        data: List of series, e.g. [[10, 20, 30], [15, 25, 35]]
        categories: X-axis labels, e.g. ["Q1", "Q2", "Q3"]
        series_names: Legend labels, e.g. ["2024", "2025"]
    """
    d = Drawing(width, height)

    PALETTE = [
        HexColor("#3B82F6"),
        HexColor("#10B981"),
        HexColor("#F59E0B"),
        HexColor("#EF4444"),
    ]

    bc = VerticalBarChart()
    bc.x = 60
    bc.y = 40
    bc.width = width - 100
    bc.height = height - 80
    bc.data = data
    bc.categoryAxis.categoryNames = categories
    bc.categoryAxis.labels.fontName = "Helvetica"
    bc.categoryAxis.labels.fontSize = 9
    bc.valueAxis.labels.fontName = "Helvetica"
    bc.valueAxis.labels.fontSize = 9
    bc.valueAxis.valueMin = 0
    bc.barWidth = 12
    bc.groupSpacing = 15

    for i in range(len(data)):
        bc.bars[i].fillColor = PALETTE[i % len(PALETTE)]
        bc.bars[i].strokeWidth = 0

    d.add(bc)

    if title:
        d.add(String(width / 2, height - 15, title,
                      fontName="Helvetica-Bold", fontSize=11,
                      fillColor=HexColor("#1E293B"), textAnchor="middle"))

    return d
```

### Line Plot

```python
from reportlab.graphics.charts.lineplots import LinePlot
from reportlab.graphics.widgets.markers import makeMarker

def create_line_chart(data, title=None, width=400, height=250):
    """
    Create a line chart with markers.

    Args:
        data: List of series, each a list of (x, y) tuples
              e.g. [[(1,10), (2,20), (3,15)], [(1,12), (2,18), (3,22)]]
    """
    d = Drawing(width, height)

    PALETTE = [
        HexColor("#3B82F6"),
        HexColor("#10B981"),
        HexColor("#F59E0B"),
        HexColor("#EF4444"),
    ]

    lp = LinePlot()
    lp.x = 60
    lp.y = 40
    lp.width = width - 100
    lp.height = height - 80
    lp.data = data
    lp.xValueAxis.labels.fontName = "Helvetica"
    lp.xValueAxis.labels.fontSize = 9
    lp.yValueAxis.labels.fontName = "Helvetica"
    lp.yValueAxis.labels.fontSize = 9

    for i in range(len(data)):
        lp.lines[i].strokeColor = PALETTE[i % len(PALETTE)]
        lp.lines[i].strokeWidth = 2
        lp.lines[i].symbol = makeMarker("Circle")
        lp.lines[i].symbol.size = 4
        lp.lines[i].symbol.fillColor = PALETTE[i % len(PALETTE)]

    d.add(lp)

    if title:
        d.add(String(width / 2, height - 15, title,
                      fontName="Helvetica-Bold", fontSize=11,
                      fillColor=HexColor("#1E293B"), textAnchor="middle"))

    return d
```

### Key Rules for Charts

- **ALWAYS** use `HexColor` with a defined palette — never use ReportLab's default colors
- **ALWAYS** set `fontName="Helvetica"` on axis labels — matches document body font
- Charts are `Drawing` objects (Flowables) — insert directly into Platypus story
- For >8 data series, consider a table instead of a chart (too many colors = unreadable)

---

## Image Embedding (Matplotlib, diagrams, External)

For content generated by external tools — save as high-resolution image, embed in PDF.

### Matplotlib → PDF

```python
import matplotlib
matplotlib.use("Agg")  # Non-interactive backend — required for headless
import matplotlib.pyplot as plt
from reportlab.platypus import Image
import tempfile

def matplotlib_to_flowable(fig, max_width=450, dpi=200):
    """
    Save a Matplotlib figure and return a ReportLab Image Flowable.

    Args:
        fig: Matplotlib figure object
        max_width: Maximum width in points
        dpi: Resolution (200 for reports, 300 for print)
    """
    tmp = tempfile.mktemp(suffix=".png")
    fig.savefig(tmp, dpi=dpi, bbox_inches="tight",
                facecolor="white", edgecolor="none")
    plt.close(fig)

    img = Image(tmp, width=max_width)
    # Preserve aspect ratio
    from reportlab.lib.utils import ImageReader
    orig_w, orig_h = ImageReader(tmp).getSize()
    scale = max_width / orig_w
    img.drawHeight = orig_h * scale
    img.drawWidth = max_width

    return img
```

### diagrams Library (Architecture Diagrams)

The `diagrams` library (diagrams.mingrammer.com) generates cloud architecture diagrams via Graphviz.

```python
# Generate the diagram (creates a PNG file)
from diagrams import Diagram, Cluster
from diagrams.aws.compute import EC2
from diagrams.aws.network import ELB
from diagrams.aws.database import RDS

with Diagram("Web Service", filename="/tmp/arch", show=False, outformat="png"):
    lb = ELB("Load Balancer")
    with Cluster("Web Tier"):
        servers = [EC2("web1"), EC2("web2"), EC2("web3")]
    db = RDS("Database")
    lb >> servers >> db

# Embed in ReportLab
from reportlab.platypus import Image
img = Image("/tmp/arch.png", width=400)
# Calculate proportional height as shown in Matplotlib section
story.append(img)
```

### Key Rules for Image Embedding

- **ALWAYS** use `dpi=200` minimum for reports, `dpi=300` for print
- **ALWAYS** set `matplotlib.use("Agg")` before importing pyplot (headless rendering)
- **ALWAYS** clean up temp files after PDF generation
- Prefer SVG → `svglib` over PNG when available (vector scales better)
- Set `facecolor="white"` on Matplotlib saves — transparent backgrounds look broken in PDF

---

## Inline Annotations

Add callout labels, margin notes, or inline annotations to diagrams and content.

### Annotation Styles

```python
from reportlab.lib.colors import HexColor

ANNOTATION_STYLES = {
    "note": {
        "bg": HexColor("#FEF9C3"),      # Yellow 100
        "border": HexColor("#F59E0B"),   # Amber 500
        "text": HexColor("#92400E"),     # Amber 800
        "icon": "\u2139",               # ℹ
    },
    "warning": {
        "bg": HexColor("#FEF2F2"),      # Red 50
        "border": HexColor("#EF4444"),   # Red 500
        "text": HexColor("#991B1B"),     # Red 800
        "icon": "\u26A0",               # ⚠
    },
    "tip": {
        "bg": HexColor("#ECFDF5"),      # Emerald 50
        "border": HexColor("#10B981"),   # Emerald 500
        "text": HexColor("#065F46"),     # Emerald 800
        "icon": "\u2714",               # ✔
    },
    "callout": {
        "bg": HexColor("#EFF6FF"),      # Blue 50
        "border": HexColor("#3B82F6"),   # Blue 500
        "text": HexColor("#1E40AF"),     # Blue 800
        "icon": "\u279C",               # ➜
    },
}
```

### Drawing Annotation Boxes

```python
from reportlab.platypus import Paragraph, Table, TableStyle
from reportlab.lib.styles import ParagraphStyle

def create_annotation(text, style_name="note", full_width=450):
    """
    Create an annotation box as a Platypus Flowable (Table-based).

    Returns a Table that can be inserted into a Platypus story.
    """
    style = ANNOTATION_STYLES[style_name]

    text_style = ParagraphStyle(
        f"Annotation_{style_name}",
        fontName="Helvetica",
        fontSize=9,
        leading=12,
        textColor=style["text"],
    )

    content = Paragraph(f"{style['icon']}  {text}", text_style)

    table = Table([[content]], colWidths=[full_width - 16])
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), style["bg"]),
        ("BOX", (0, 0), (-1, -1), 1, style["border"]),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
        ("LEFTPADDING", (0, 0), (-1, -1), 12),
        ("RIGHTPADDING", (0, 0), (-1, -1), 12),
        ("ROUNDEDCORNERS", [4, 4, 4, 4]),
    ]))

    return table
```

### Usage in Story

```python
story.append(create_annotation(
    "This endpoint requires authentication. See Section 3.2 for token format.",
    style_name="note"
))
story.append(Spacer(1, 8))
story.append(create_annotation(
    "Rate limit: 100 requests/minute. Exceeding this returns 429.",
    style_name="warning"
))
```

---

## Cross-Reference: Related Docs

| Topic | Reference |
|---|---|
| Font selection for code vs. body text | [unicode-and-fonts.md](unicode-and-fonts.md) |
| Markdown → PDF pipeline integration | [markdown-to-pdf.md](markdown-to-pdf.md) |
| Anchor links and TOC generation | [cross-references.md](cross-references.md) |
| Adobe-branded report styling | [adobe-internal.md](adobe-internal.md) |
