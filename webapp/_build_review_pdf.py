import base64
import os
import re
import time

import markdown
from selenium import webdriver
from selenium.webdriver.edge.options import Options

ROOT = r"g:\Summer_2026\DBI202\Learning-Online-Managements-System"
DOCS = os.path.join(ROOT, "docs")
SQLDIR = os.path.join(ROOT, "sql")
MD = os.path.join(DOCS, "PROJECT_REVIEW.md")
TMP_HTML = os.path.join(DOCS, "_print.html")
PDF = os.path.join(DOCS, "PROJECT_REVIEW.pdf")

FOCUS_START = "<!-- SQL_FOCUS_START -->"
FOCUS_END = "<!-- SQL_FOCUS_END -->"
APX_START = "<!-- SQL_APPENDIX_START -->"
APX_END = "<!-- SQL_APPENDIX_END -->"


def read_text(path):
    for enc in ("utf-8-sig", "utf-8", "cp1252"):
        try:
            with open(path, encoding=enc) as f:
                return f.read()
        except UnicodeDecodeError:
            continue
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


# ---- 1. Load review markdown, strip previously injected blocks (idempotent) ----
md = read_text(MD)
md = re.sub(re.escape(FOCUS_START) + r".*?" + re.escape(FOCUS_END) + r"\n*", "", md, flags=re.DOTALL)
md = re.sub(re.escape(APX_START) + r".*?" + re.escape(APX_END) + r"\n*", "", md, flags=re.DOTALL)
md = md.rstrip() + "\n"

# ---- 2. Build the "SQL focus" callout and inject before "## 1. Tổng quan" ----
focus = f"""{FOCUS_START}
> ### Trọng tâm chấm điểm: MÃ NGUỒN SQL
> Lõi của đồ án là **database (T-SQL)** — mọi quy tắc nghiệp vụ đều nằm ở đây. **Toàn bộ mã nguồn chính** (schema
> + ràng buộc, **7 trigger**, **5 function**, **2 view**, **6 stored procedure**, **6 truy vấn báo cáo**,
> **12 negative test** và **smoke test luồng hợp lệ**) được **in đầy đủ trong _Phụ lục A — Mã nguồn SQL_** ở cuối
> tài liệu. Riêng hai script **dữ liệu mẫu** (`05_sample_data.sql`, `08_more_sample_data.sql`) chỉ gồm câu lệnh
> `INSERT`, **nằm trong repository** và **không in** ở đây để tài liệu gọn. Phần demo web (Mục 8) chỉ minh họa
> DB chạy trong ứng dụng thật.

{FOCUS_END}

"""
anchor = "## 1. Tổng quan"
md = md.replace(anchor, focus + anchor, 1)

# ---- 3. Build Appendix A from the real SQL files ----
files = [
    ("A.1. Schema & ràng buộc (PK/FK/UNIQUE/CHECK)", "01_schema.sql"),
    ("A.2. Trigger — nơi thực thi quy tắc nghiệp vụ", "02_triggers.sql"),
    ("A.3. Function & View", "03_functions_views.sql"),
    ("A.4. Stored Procedure (có transaction & xử lý lỗi)", "04_procedures.sql"),
    ("A.5. Truy vấn báo cáo / thống kê", "06_reports.sql"),
    ("A.6. Kiểm thử quy tắc nghiệp vụ (negative test, 12/12 PASS)", "07_business_rule_tests.sql"),
    ("A.7. Smoke test luồng hợp lệ (positive, transaction + ROLLBACK)", "09_positive_smoke_tests.sql"),
]

parts = [
    APX_START,
    "---",
    "",
    "## Phụ lục A — Mã nguồn SQL đầy đủ",
    "",
    "> Phần này in **nguyên văn các file mã nguồn chính** trong thư mục `sql/` (schema, trigger, "
    "function/view, stored procedure, truy vấn báo cáo, negative test, smoke test) — là phần chính để "
    "mentor chấm điểm. Hai script **dữ liệu mẫu** `05_sample_data.sql` và `08_more_sample_data.sql` "
    "(chỉ gồm `INSERT`) **nằm trong repository, không in ở đây** để tránh dài. "
    "Thứ tự chạy đầy đủ: `01 → 02 → 03 → 04 → 05 → 06 → 07 → 08 → 09`.",
    "",
]
for title, fname in files:
    code = read_text(os.path.join(SQLDIR, fname)).rstrip()
    nlines = code.count("\n") + 1
    parts.append(f"### {title} — `{fname}` ({nlines} dòng)")
    parts.append("")
    parts.append("```sql")
    parts.append(code)
    parts.append("```")
    parts.append("")
parts.append(APX_END)
appendix = "\n".join(parts) + "\n"

md = md.rstrip() + "\n\n" + appendix

with open(MD, "w", encoding="utf-8") as f:
    f.write(md)
print("Updated", MD)

# ---- 4. Render markdown -> HTML (with SQL syntax highlighting) ----
text = md
text = re.sub(r"^(\s*)- \[x\] ", r"\1- &#9989; ", text, flags=re.MULTILINE)
text = re.sub(r"^(\s*)- \[ \] ", r"\1- &#11036; ", text, flags=re.MULTILINE)

from markdown.extensions.codehilite import CodeHiliteExtension

body = markdown.markdown(
    text,
    extensions=[
        "tables",
        "fenced_code",
        "sane_lists",
        "toc",
        CodeHiliteExtension(noclasses=True, pygments_style="friendly", guess_lang=False),
    ],
)

CSS = """
@page { size: A4; margin: 13mm 12mm; }
* { box-sizing: border-box; }
body { font-family: 'Segoe UI','Arial',sans-serif; font-size: 11.5px; line-height: 1.5; color:#1f2937; margin:0; }
h1 { font-size: 22px; color:#1d4ed8; border-bottom:3px solid #1d4ed8; padding-bottom:6px; }
h2 { font-size: 17px; color:#1e40af; margin-top:22px; border-bottom:1px solid #cbd5e1; padding-bottom:4px; page-break-after: avoid; }
h3 { font-size: 13px; color:#334155; margin-top:14px; page-break-after: avoid; }
blockquote { border-left:4px solid #93c5fd; background:#eff6ff; margin:10px 0; padding:6px 12px; color:#334155; }
blockquote h3 { margin-top:2px; color:#1d4ed8; }
table { border-collapse: collapse; width:100%; margin:10px 0; font-size:10.5px; }
th,td { border:1px solid #cbd5e1; padding:5px 8px; text-align:left; vertical-align:top; }
th { background:#e0e7ff; color:#1e3a8a; }
tr:nth-child(even) td { background:#f8fafc; }
:not(pre) > code { background:#eef2ff; padding:1px 5px; border-radius:4px; font-size:10.5px; color:#be123c; }
pre { background:#f8fafc; border:1px solid #e2e8f0; border-left:4px solid #2563eb; border-radius:6px;
      padding:9px 11px; margin:8px 0; font-size:9.3px; line-height:1.42;
      white-space:pre-wrap; word-break:break-word; overflow-wrap:anywhere;
      font-family:'Cascadia Mono','Consolas','Courier New',monospace; }
pre code { background:transparent; padding:0; font-size:inherit; }
.codehilite { background:#f8fafc !important; }
img { max-width:100%; height:auto; display:block; margin:10px auto; border:1px solid #e2e8f0; border-radius:6px; }
hr { border:none; border-top:1px solid #e2e8f0; margin:16px 0; }
a { color:#2563eb; text-decoration:none; }
ul,ol { margin:6px 0 6px 4px; } li { margin:2px 0; }
"""

html = f"""<!DOCTYPE html><html lang="vi"><head><meta charset="utf-8"><style>{CSS}</style></head>
<body>{body}</body></html>"""
with open(TMP_HTML, "w", encoding="utf-8") as f:
    f.write(html)

# ---- 5. Print to PDF via headless Edge ----
opts = Options()
opts.add_argument("--headless=new")
opts.add_argument("--hide-scrollbars")
d = webdriver.Edge(options=opts)
try:
    d.get("file:///" + TMP_HTML.replace("\\", "/"))
    time.sleep(2.2)
    result = d.execute_cdp_cmd(
        "Page.printToPDF",
        {
            "printBackground": True,
            "paperWidth": 8.27,
            "paperHeight": 11.69,
            "marginTop": 0.35,
            "marginBottom": 0.35,
            "marginLeft": 0.3,
            "marginRight": 0.3,
            "preferCSSPageSize": True,
        },
    )
    with open(PDF, "wb") as f:
        f.write(base64.b64decode(result["data"]))
    print("PDF saved:", PDF, os.path.getsize(PDF), "bytes")
finally:
    d.quit()
    if os.path.exists(TMP_HTML):
        os.remove(TMP_HTML)
