import base64
import os
import re
import time

import markdown
from markdown.extensions.codehilite import CodeHiliteExtension
from selenium import webdriver
from selenium.webdriver.edge.options import Options

HERE = os.path.dirname(os.path.abspath(__file__))

LABS = [
    "lab1_data_models.md",
    "lab2_entities_fds_keys.md",
    "lab3_anomalies_and_normalization.md",
    "lab4_relational_design_process.md",
    "lab5_sql_programming.md",
]

CSS = """
@page { size: A4; margin: 14mm 13mm; }
* { box-sizing: border-box; }
body { font-family: 'Segoe UI','Arial',sans-serif; font-size: 11.5px; line-height: 1.55; color:#1f2937; margin:0; }
h1 { font-size: 22px; color:#1d4ed8; border-bottom:3px solid #1d4ed8; padding-bottom:6px; }
h2 { font-size: 16px; color:#1e40af; margin-top:20px; border-bottom:1px solid #cbd5e1; padding-bottom:4px; page-break-after: avoid; }
h3 { font-size: 13px; color:#334155; margin-top:13px; page-break-after: avoid; }
h4 { font-size: 12px; color:#334155; margin-top:11px; page-break-after: avoid; }
blockquote { border-left:4px solid #93c5fd; background:#eff6ff; margin:10px 0; padding:6px 12px; color:#334155; }
table { border-collapse: collapse; width:100%; margin:10px 0; font-size:10px; }
th,td { border:1px solid #cbd5e1; padding:4px 7px; text-align:left; vertical-align:top; }
th { background:#e0e7ff; color:#1e3a8a; }
tr:nth-child(even) td { background:#f8fafc; }
:not(pre) > code { background:#eef2ff; padding:1px 5px; border-radius:4px; font-size:10px; color:#be123c; }
pre { background:#f8fafc; border:1px solid #e2e8f0; border-left:4px solid #2563eb; border-radius:6px;
      padding:9px 11px; margin:8px 0; font-size:9.4px; line-height:1.42;
      white-space:pre-wrap; word-break:break-word; overflow-wrap:anywhere;
      font-family:'Cascadia Mono','Consolas','Courier New',monospace; }
pre code { background:transparent; padding:0; font-size:inherit; }
.codehilite { background:#f8fafc !important; }
img { max-width:100%; height:auto; display:block; margin:10px auto; border:1px solid #e2e8f0; border-radius:6px; }
hr { border:none; border-top:1px solid #e2e8f0; margin:16px 0; }
a { color:#2563eb; text-decoration:none; }
ul,ol { margin:6px 0 6px 4px; } li { margin:2px 0; }
"""


def read_text(path):
    for enc in ("utf-8-sig", "utf-8", "cp1252"):
        try:
            with open(path, encoding=enc) as f:
                return f.read()
        except UnicodeDecodeError:
            continue
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def md_to_html(text):
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
    return f"""<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><style>{CSS}</style></head>
<body>{body}</body></html>"""


def main():
    opts = Options()
    opts.add_argument("--headless=new")
    opts.add_argument("--hide-scrollbars")
    d = webdriver.Edge(options=opts)
    tmp_html = os.path.join(HERE, "_print.html")
    try:
        for md_name in LABS:
            md_path = os.path.join(HERE, md_name)
            pdf_path = md_path[:-3] + ".pdf"
            html = md_to_html(read_text(md_path))
            with open(tmp_html, "w", encoding="utf-8") as f:
                f.write(html)
            d.get("file:///" + tmp_html.replace("\\", "/"))
            time.sleep(1.6)
            result = d.execute_cdp_cmd(
                "Page.printToPDF",
                {
                    "printBackground": True,
                    "paperWidth": 8.27,
                    "paperHeight": 11.69,
                    "marginTop": 0.4,
                    "marginBottom": 0.4,
                    "marginLeft": 0.35,
                    "marginRight": 0.35,
                    "preferCSSPageSize": True,
                },
            )
            with open(pdf_path, "wb") as f:
                f.write(base64.b64decode(result["data"]))
            print("PDF:", os.path.basename(pdf_path), os.path.getsize(pdf_path), "bytes")
    finally:
        d.quit()
        if os.path.exists(tmp_html):
            os.remove(tmp_html)


if __name__ == "__main__":
    main()
