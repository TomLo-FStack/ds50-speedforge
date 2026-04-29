from __future__ import annotations

import csv
import math
import shutil
from datetime import datetime
from pathlib import Path

from reportlab.graphics.shapes import Drawing, Line, Rect, String
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
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
EN_PDF = OUT_DIR / "v_vs_go_ds50_acm.en.pdf"
ZH_PDF = OUT_DIR / "v_vs_go_ds50_acm.zh-CN.pdf"
DEFAULT_PDF = OUT_DIR / "v_vs_go_ds50_acm.pdf"

CATEGORY_ZH = {
    "Array": "数组",
    "Array/Matrix": "数组/矩阵",
    "Hash": "哈希",
    "Hash/TwoPointer": "哈希/双指针",
    "String": "字符串",
    "LinkedList": "链表",
    "Stack": "栈",
    "Stack/Queue": "栈/队列",
    "Queue": "队列",
    "MonotonicStack": "单调栈",
    "Heap": "堆",
    "Heap/Hash": "堆/哈希",
    "BinaryTree": "二叉树",
    "BST": "二叉搜索树",
    "Graph": "图",
    "UnionFind": "并查集",
    "Trie": "字典树",
    "Fenwick": "树状数组",
}

TEXT = {
    "en": {
        "font": "Helvetica",
        "bold": "Helvetica-Bold",
        "title": "V vs Go DS50 Benchmark",
        "generated": "Automated local report generated {date}",
        "abstract": "Abstract",
        "abstract_body": (
            "This report compares V and Go implementations of 50 classic data-structure workloads. "
            "Each workload is executed at the same logical input sizes and summarized with median elapsed time. "
            "The overall geomean result is <b>{winner}</b> across valid problem-size measurements."
        ),
        "methodology": "Methodology",
        "methodology_body": (
            "The benchmark uses sizes {sizes} with {trials} measured trial(s) per language/problem/size. "
            "The Windows runner executes benchmark and compile commands at Idle priority with CPU affinity limited "
            "by the experiment script and with a Job Object memory ceiling. Checksums are compared between languages "
            "to catch behavioral drift before interpreting speed results."
        ),
        "aggregate": "Aggregate Results",
        "category_chart": "Category Geomean Speedups",
        "size_section": "Input Size Sensitivity",
        "problem_section": "Problem-Level Results",
        "problem_chart": "Problem Geomean Speedups (Top 24 by Go Speedup)",
        "problem_table": "Problem Summary Table",
        "validity": "Validity Checks",
        "validity_body": (
            "Raw records: {records}. Compared rows: {comparison_rows}. Checksum mismatches: {checksum_mismatches}. "
            "Go wins: {go_wins}; V wins: {v_wins}; ties: {ties}."
        ),
        "left_right": "left: V faster, right: Go faster (log2 scale)",
        "page": "Page",
        "headers_category": ["Category", "Measurements", "Geomean", "Winner"],
        "headers_size": ["Input Size", "Measurements", "Geomean", "Winner"],
        "headers_problem": ["ID", "Category", "Title", "Geomean", "Winner"],
        "na": "n/a",
    },
    "zh": {
        "font": "STSong-Light",
        "bold": "STSong-Light",
        "title": "V/Go DS50 基准测试",
        "generated": "本地自动报告生成时间 {date}",
        "abstract": "摘要",
        "abstract_body": (
            "本报告比较 V 与 Go 对 50 个经典数据结构工作负载的实现。"
            "每个工作负载在相同逻辑输入规模下运行，并以耗时中位数汇总。"
            "在所有有效的题目-规模测量项上，总体几何均值结果为 <b>{winner}</b>。"
        ),
        "methodology": "实验方法",
        "methodology_body": (
            "本实验使用输入规模 {sizes}，每个语言/题目/规模组合测量 {trials} 次。"
            "Windows 运行器以 Idle 优先级执行编译和基准测试命令，并由实验脚本限制 CPU affinity，"
            "同时使用 Windows Job Object 设置内存上限。解释性能结果前，会先比较两种语言的 checksum，"
            "以确认行为没有偏移。"
        ),
        "aggregate": "总体结果",
        "category_chart": "按类别统计的几何均值加速比",
        "size_section": "输入规模敏感性",
        "problem_section": "题目级结果",
        "problem_chart": "题目几何均值加速比（Go 加速比最高的 24 项）",
        "problem_table": "题目汇总表",
        "validity": "有效性检查",
        "validity_body": (
            "原始记录数：{records}。对比行数：{comparison_rows}。Checksum 不一致数：{checksum_mismatches}。"
            "Go 胜出：{go_wins}；V 胜出：{v_wins}；接近持平：{ties}。"
        ),
        "left_right": "左侧：V 更快，右侧：Go 更快（log2 尺度）",
        "page": "第 {page} 页",
        "headers_category": ["类别", "测量项", "几何均值", "更快方"],
        "headers_size": ["输入规模", "测量项", "几何均值", "更快方"],
        "headers_problem": ["ID", "类别", "题目", "几何均值", "更快方"],
        "na": "无",
    },
}


def register_fonts() -> None:
    pdfmetrics.registerFont(UnicodeCIDFont("STSong-Light"))


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


def speedup_label(ratio: float, lang: str) -> str:
    if not math.isfinite(ratio) or ratio <= 0:
        return TEXT[lang]["na"]
    if lang == "zh":
        if ratio >= 1:
            return f"Go 快 {ratio:.2f}x"
        return f"V 快 {1 / ratio:.2f}x"
    if ratio >= 1:
        return f"{ratio:.2f}x Go"
    return f"{1 / ratio:.2f}x V"


def short_text(value: str, limit: int) -> str:
    return value if len(value) <= limit else value[: limit - 1] + "..."


def category_label(category: str, lang: str, compact: bool = False) -> str:
    if lang == "zh":
        zh = CATEGORY_ZH.get(category, category)
        return zh if compact else f"{zh} ({category})"
    return category


def row_label(row: dict[str, str], field: str, lang: str) -> str:
    if field == "category":
        return category_label(row[field], lang)
    return row[field]


def speedup_chart(
    rows: list[dict[str, str]],
    title: str,
    key: str,
    label: str,
    lang: str,
    max_rows: int | None = None,
) -> Drawing:
    text = TEXT[lang]
    items = []
    for row in rows:
        ratio = as_float(row[key])
        if math.isfinite(ratio) and ratio > 0:
            items.append((row_label(row, label, lang), ratio))
    items.sort(key=lambda item: item[1], reverse=True)
    if max_rows is not None:
        items = items[:max_rows]

    width = 6.8 * inch
    row_h = 0.23 * inch
    height = max(1.8 * inch, 0.7 * inch + row_h * len(items))
    chart = Drawing(width, height)
    chart_font = text["font"]
    chart.add(String(0, height - 14, title, fontName=text["bold"], fontSize=10, fillColor=colors.HexColor("#222222")))
    chart.add(String(0, height - 29, text["left_right"], fontName=chart_font, fontSize=6.5, fillColor=colors.HexColor("#555555")))

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
        chart.add(String(0, y + 2, short_text(name, 30), fontName=chart_font, fontSize=7, fillColor=colors.HexColor("#222222")))
        chart.add(Rect(x, y, bar_w, 8, fillColor=color, strokeColor=color))
        chart.add(String(chart_x + chart_w + 6, y + 2, speedup_label(ratio, lang), fontName=chart_font, fontSize=7, fillColor=colors.HexColor("#222222")))
    return chart


def table_style(font: str, bold: str, header_bg: str = "#f0f0f0") -> TableStyle:
    return TableStyle(
        [
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor(header_bg)),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.HexColor("#222222")),
            ("FONTNAME", (0, 0), (-1, 0), bold),
            ("FONTNAME", (0, 1), (-1, -1), font),
            ("FONTSIZE", (0, 0), (-1, -1), 7),
            ("BOTTOMPADDING", (0, 0), (-1, 0), 6),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 1), (-1, -1), 4),
            ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#cccccc")),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ]
    )


def make_page_number(lang: str):
    def add_page_number(canvas, doc) -> None:
        text = TEXT[lang]
        canvas.saveState()
        canvas.setFont(text["font"], 8)
        canvas.setFillColor(colors.HexColor("#555555"))
        label = text["page"].format(page=doc.page) if "{page}" in text["page"] else f"{text['page']} {doc.page}"
        canvas.drawRightString(letter[0] - 0.55 * inch, 0.35 * inch, label)
        canvas.restoreState()

    return add_page_number


def make_styles(lang: str):
    text = TEXT[lang]
    styles = getSampleStyleSheet()
    for style in styles.byName.values():
        style.fontName = text["font"]
    styles.add(ParagraphStyle(name="CenterTitle", parent=styles["Title"], alignment=TA_CENTER, fontName=text["bold"]))
    styles.add(ParagraphStyle(name="Small", parent=styles["BodyText"], fontSize=8, leading=10, fontName=text["font"]))
    styles.add(
        ParagraphStyle(
            name="Section",
            parent=styles["Heading2"],
            fontName=text["bold"],
            fontSize=12,
            leading=14,
            spaceBefore=10,
            spaceAfter=6,
        )
    )
    return styles


def build_report(
    lang: str,
    out_pdf: Path,
    summary: list[dict[str, str]],
    category: list[dict[str, str]],
    size_summary: list[dict[str, str]],
    problems: list[dict[str, str]],
    overall: dict[str, str],
) -> None:
    text = TEXT[lang]
    styles = make_styles(lang)
    trials = summary[0]["trials"] if summary else "n/a"
    sizes = ", ".join(row["input_size"] for row in size_summary)
    overall_ratio = as_float(overall.get("go_speedup_over_v_geomean", "nan"))

    story = [
        Paragraph(text["title"], styles["CenterTitle"]),
        Paragraph(text["generated"].format(date=datetime.now().strftime("%Y-%m-%d %H:%M")), styles["Small"]),
        Spacer(1, 0.12 * inch),
        Paragraph(text["abstract"], styles["Section"]),
        Paragraph(text["abstract_body"].format(winner=speedup_label(overall_ratio, lang)), styles["BodyText"]),
        Paragraph(text["methodology"], styles["Section"]),
        Paragraph(text["methodology_body"].format(sizes=sizes, trials=trials), styles["BodyText"]),
        Paragraph(text["aggregate"], styles["Section"]),
        speedup_chart(category, text["category_chart"], "go_speedup_over_v_geomean", "category", lang),
        Spacer(1, 0.12 * inch),
    ]

    category_rows = [text["headers_category"]]
    for row in category:
        ratio = as_float(row["go_speedup_over_v_geomean"])
        category_rows.append(
            [
                category_label(row["category"], lang),
                row["measurements"],
                f"{ratio:.3f}",
                speedup_label(ratio, lang),
            ]
        )
    category_table = Table(category_rows, repeatRows=1, colWidths=[1.75 * inch, 1.0 * inch, 0.9 * inch, 1.2 * inch])
    category_table.setStyle(table_style(text["font"], text["bold"]))
    story.append(category_table)

    size_rows = [text["headers_size"]]
    for row in size_summary:
        ratio = as_float(row["go_speedup_over_v_geomean"])
        size_rows.append([row["input_size"], row["measurements"], f"{ratio:.3f}", speedup_label(ratio, lang)])

    story.extend(
        [
            Paragraph(text["size_section"], styles["Section"]),
            Table(
                size_rows,
                repeatRows=1,
                colWidths=[1.0 * inch, 1.1 * inch, 0.9 * inch, 1.2 * inch],
                style=table_style(text["font"], text["bold"]),
            ),
            PageBreak(),
            Paragraph(text["problem_section"], styles["Section"]),
            speedup_chart(
                problems,
                text["problem_chart"],
                "go_speedup_over_v_geomean",
                "title",
                lang,
                max_rows=24,
            ),
            PageBreak(),
            Paragraph(text["problem_table"], styles["Section"]),
        ]
    )

    problem_rows = [text["headers_problem"]]
    for row in problems:
        ratio = as_float(row["go_speedup_over_v_geomean"])
        problem_rows.append(
            [
                row["problem_id"],
                short_text(category_label(row["category"], lang, compact=True), 18),
                short_text(row["title"], 34),
                f"{ratio:.3f}",
                speedup_label(ratio, lang),
            ]
        )
    problem_table = Table(problem_rows, repeatRows=1, colWidths=[0.35 * inch, 1.0 * inch, 2.35 * inch, 0.75 * inch, 0.95 * inch])
    problem_table.setStyle(table_style(text["font"], text["bold"]))
    story.append(problem_table)

    story.extend(
        [
            Paragraph(text["validity"], styles["Section"]),
            Paragraph(
                text["validity_body"].format(
                    records=overall.get("records", "n/a"),
                    comparison_rows=overall.get("comparison_rows", "n/a"),
                    checksum_mismatches=overall.get("checksum_mismatches", "n/a"),
                    go_wins=overall.get("go_wins", "n/a"),
                    v_wins=overall.get("v_wins", "n/a"),
                    ties=overall.get("ties", "n/a"),
                ),
                styles["BodyText"],
            ),
        ]
    )

    doc = SimpleDocTemplate(
        str(out_pdf),
        pagesize=letter,
        leftMargin=0.58 * inch,
        rightMargin=0.58 * inch,
        topMargin=0.55 * inch,
        bottomMargin=0.55 * inch,
        title=text["title"],
        author="Automated benchmark harness",
    )
    doc.build(story, onFirstPage=make_page_number(lang), onLaterPages=make_page_number(lang))
    print(f"Wrote: {out_pdf}")


def main() -> None:
    register_fonts()
    summary = read_csv(DATA_DIR / "summary.csv")
    category = read_csv(DATA_DIR / "category_summary.csv")
    size_summary = read_csv(DATA_DIR / "size_summary.csv")
    problems = read_csv(DATA_DIR / "problem_summary.csv")
    overall = read_overall(DATA_DIR / "overall_summary.txt")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    build_report("en", EN_PDF, summary, category, size_summary, problems, overall)
    build_report("zh", ZH_PDF, summary, category, size_summary, problems, overall)
    shutil.copyfile(EN_PDF, DEFAULT_PDF)
    print(f"Wrote: {DEFAULT_PDF}")


if __name__ == "__main__":
    main()
