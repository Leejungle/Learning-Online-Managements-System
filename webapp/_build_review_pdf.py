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


def read_text(path):
    for enc in ("utf-8-sig", "utf-8", "cp1252"):
        try:
            with open(path, encoding=enc) as f:
                return f.read()
        except UnicodeDecodeError:
            continue
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


# ---- 1. Load review markdown as-is (the .md file is the single source of truth) ----
# NOTE: This script no longer injects an "SQL focus" callout or rebuilds an
# "Phụ lục A — Mã nguồn SQL" appendix. The full SQL source lives in sql/ and is
# intentionally NOT reprinted in the report. Edit PROJECT_REVIEW.md directly.
md = read_text(MD)

# ---- 2. Render markdown -> HTML (with SQL syntax highlighting) ----
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
