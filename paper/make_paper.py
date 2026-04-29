from __future__ import annotations

import csv
import math
from datetime import datetime
from pathlib import Path

from reportlab.graphics.shapes import Drawing, Line, Rect, String
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
OUT_DIR = ROOT / "output" / "pdf"
OUT_PDF = OUT_DIR / "v_vs_go_ds50_acm.pdf"


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        raise FileNotFoundError(f"missing input: {path}")
    with path.open(newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def read_overall(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            values[key] = value
    return values


def as_float(value: str) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return math.nan


def speedup_label(ratio: float) -> str:
    if not math.isfinite(ratio) or ratio <= 0:
        return "n/a"
    if ratio >= 1:
        return f"{ratio:.2f}x Go"
    return f"{1 / ratio:.2f}x V"


def short_text(value: str, limit: int) -> str:
    return value if len(value) <= limit else value[: limit - 1] + "..."


def speedup_chart(rows: list[dict[str, str]], title: str, key: str, label: str, max_rows: int | None = None) -> Drawing:
    items = []
    for row in rows:
        ratio = as_float(row[key])
        if math.isfinite(ratio) and ratio > 0:
            items.append((row[label], ratio))
    items.sort(key=lambda item: item[1], reverse=True)
    if max_rows is not None:
        items = items[:max_rows]

    width = 6.8 * inch
    row_h = 0.23 * inch
    height = max(1.8 * inch, 0.7 * inch + row_h * len(items))
    chart = Drawing(width, height)
    chart.add(String(0, height - 14, title, fontName="Helvetica-Bold", fontSize=10, fillColor=colors.HexColor("#222222")))

    label_w = 1.85 * inch
    chart_x = label_w + 0.15 * inch
    chart_w = width - chart_x - 1.0 * inch
    center = chart_x + chart_w / 2
    half = chart_w / 2
    max_abs = max([0.25] + [abs(math.log2(ratio)) for _, ratio in items])

    y_top = height - 0.55 * inch
    chart.add(Line(center, 0.25 * inch, center, y_top + 4, strokeColor=colors.HexColor("#555555"), strokeWidth=0.6))
    chart.add(String(center + 3, y_top + 7, "1.00x", fontName="Helvetica", fontSize=6.5, fillColor=colors.HexColor("#555555")))

    for index, (name, ratio) in enumerate(items):
        y = y_top - index * row_h
        value = math.log2(ratio)
        bar_w = abs(value) / max_abs * half
        if value >= 0:
            x = center
            color = colors.HexColor("#2b6cb0")
        else:
            x = center - bar_w
            color = colors.HexColor("#c05621")
        chart.add(String(0, y + 2, short_text(name, 30), fontName="Helvetica", fontSize=7, fillColor=colors.HexColor("#222222")))
        chart.add(Rect(x, y, bar_w, 8, fillColor=color, strokeColor=color))
        chart.add(String(chart_x + chart_w + 6, y + 2, speedup_label(ratio), fontName="Helvetica", fontSize=7, fillColor=colors.HexColor("#222222")))
    return chart


def table_style(header_bg: str = "#f0f0f0") -> TableStyle:
    return TableStyle(
        [
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor(header_bg)),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.HexColor("#222222")),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTNAME", (0, 1), (-1, -1), "Helvetica"),
            ("FONTSIZE", (0, 0), (-1, -1), 7),
            ("BOTTOMPADDING", (0, 0), (-1, 0), 6),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 1), (-1, -1), 4),
            ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#cccccc")),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ]
    )


def add_page_number(canvas, doc) -> None:
    canvas.saveState()
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(colors.HexColor("#555555"))
    canvas.drawRightString(letter[0] - 0.55 * inch, 0.35 * inch, f"Page {doc.page}")
    canvas.restoreState()


def main() -> None:
    summary = read_csv(DATA_DIR / "summary.csv")
    category = read_csv(DATA_DIR / "category_summary.csv")
    size_summary = read_csv(DATA_DIR / "size_summary.csv")
    problems = read_csv(DATA_DIR / "problem_summary.csv")
    overall = read_overall(DATA_DIR / "overall_summary.txt")

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(name="CenterTitle", parent=styles["Title"], alignment=TA_CENTER, fontName="Helvetica-Bold"))
    styles.add(ParagraphStyle(name="Small", parent=styles["BodyText"], fontSize=8, leading=10))
    styles.add(ParagraphStyle(name="Section", parent=styles["Heading2"], fontName="Helvetica-Bold", fontSize=12, leading=14, spaceBefore=10, spaceAfter=6))

    trials = summary[0]["trials"] if summary else "n/a"
    sizes = ", ".join(row["input_size"] for row in size_summary)
    overall_ratio = as_float(overall.get("go_speedup_over_v_geomean", "nan"))

    story = [
        Paragraph("V vs Go DS50 Benchmark", styles["CenterTitle"]),
        Paragraph(
            f"Automated local report generated {datetime.now().strftime('%Y-%m-%d %H:%M')}",
            styles["Small"],
        ),
        Spacer(1, 0.12 * inch),
        Paragraph("Abstract", styles["Section"]),
        Paragraph(
            "This report compares V and Go implementations of 50 classic data-structure workloads. "
            "Each workload is executed at the same logical input sizes and summarized with median elapsed time. "
            f"The overall geomean result is <b>{speedup_label(overall_ratio)}</b> across valid problem-size measurements.",
            styles["BodyText"],
        ),
        Paragraph("Methodology", styles["Section"]),
        Paragraph(
            f"The benchmark uses sizes {sizes} with {trials} measured trial(s) per language/problem/size. "
            "The Windows runner executes benchmark and compile commands at Idle priority with CPU affinity limited "
            "by the experiment script and with a Job Object memory ceiling. Checksums are compared between languages "
            "to catch behavioral drift before interpreting speed results.",
            styles["BodyText"],
        ),
        Paragraph("Aggregate Results", styles["Section"]),
        speedup_chart(category, "Category Geomean Speedups", "go_speedup_over_v_geomean", "category"),
        Spacer(1, 0.12 * inch),
    ]

    category_rows = [["Category", "Measurements", "Geomean", "Winner"]]
    for row in category:
        category_rows.append(
            [
                row["category"],
                row["measurements"],
                f'{as_float(row["go_speedup_over_v_geomean"]):.3f}',
                row["winner"],
            ]
        )
    table = Table(category_rows, repeatRows=1, colWidths=[1.75 * inch, 1.0 * inch, 0.9 * inch, 1.2 * inch])
    table.setStyle(table_style())
    story.append(table)

    story.extend(
        [
            Paragraph("Input Size Sensitivity", styles["Section"]),
            Table(
                [["Input Size", "Measurements", "Geomean", "Winner"]]
                + [
                    [
                        row["input_size"],
                        row["measurements"],
                        f'{as_float(row["go_speedup_over_v_geomean"]):.3f}',
                        row["winner"],
                    ]
                    for row in size_summary
                ],
                repeatRows=1,
                colWidths=[1.0 * inch, 1.1 * inch, 0.9 * inch, 1.2 * inch],
                style=table_style(),
            ),
            PageBreak(),
            Paragraph("Problem-Level Results", styles["Section"]),
            speedup_chart(problems, "Problem Geomean Speedups (Top 24 by Go Speedup)", "go_speedup_over_v_geomean", "title", max_rows=24),
            PageBreak(),
            Paragraph("Problem Summary Table", styles["Section"]),
        ]
    )

    problem_rows = [["ID", "Category", "Title", "Geomean", "Winner"]]
    for row in problems:
        problem_rows.append(
            [
                row["problem_id"],
                short_text(row["category"], 18),
                short_text(row["title"], 34),
                f'{as_float(row["go_speedup_over_v_geomean"]):.3f}',
                row["winner"],
            ]
        )
    problem_table = Table(problem_rows, repeatRows=1, colWidths=[0.35 * inch, 1.0 * inch, 2.35 * inch, 0.75 * inch, 0.95 * inch])
    problem_table.setStyle(table_style())
    story.append(problem_table)

    story.extend(
        [
            Paragraph("Validity Checks", styles["Section"]),
            Paragraph(
                f"Raw records: {overall.get('records', 'n/a')}. "
                f"Compared rows: {overall.get('comparison_rows', 'n/a')}. "
                f"Checksum mismatches: {overall.get('checksum_mismatches', 'n/a')}. "
                f"Go wins: {overall.get('go_wins', 'n/a')}; V wins: {overall.get('v_wins', 'n/a')}; ties: {overall.get('ties', 'n/a')}.",
                styles["BodyText"],
            ),
        ]
    )

    doc = SimpleDocTemplate(
        str(OUT_PDF),
        pagesize=letter,
        leftMargin=0.58 * inch,
        rightMargin=0.58 * inch,
        topMargin=0.55 * inch,
        bottomMargin=0.55 * inch,
        title="V vs Go DS50 Benchmark",
        author="Automated benchmark harness",
    )
    doc.build(story, onFirstPage=add_page_number, onLaterPages=add_page_number)
    print(f"Wrote: {OUT_PDF}")


if __name__ == "__main__":
    main()
