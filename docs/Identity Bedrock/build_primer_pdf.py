"""Convert the Identity Concepts Primer markdown into a PDF (pure-Python, no native deps)."""
import os
import markdown
from xhtml2pdf import pisa

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "Identity-Concepts-Primer.md")
OUT = os.path.join(HERE, "Identity-Concepts-Primer.pdf")

CSS = """
@page { size: A4; margin: 1.6cm 1.4cm; }
body { font-family: Helvetica, Arial, sans-serif; font-size: 10pt; color: #1a1a1a; line-height: 1.4; }
h1 { font-size: 20pt; color: #16325c; border-bottom: 2px solid #16325c; padding-bottom: 4px; }
h2 { font-size: 14pt; color: #16325c; margin-top: 18px; border-bottom: 1px solid #c9d5e5; padding-bottom: 2px; }
h3 { font-size: 11.5pt; color: #2a4b7c; margin-top: 12px; }
h4 { font-size: 10.5pt; color: #3a3a3a; margin-top: 10px; }
p { margin: 5px 0; }
strong { color: #10233f; }
blockquote { background: #f4f7fb; border-left: 3px solid #3B6FD4; margin: 8px 0; padding: 6px 10px; color: #33475b; }
code { background: #f0f2f5; font-family: Courier, monospace; font-size: 9pt; padding: 1px 3px; }
ul, ol { margin: 4px 0 8px 0; }
li { margin: 2px 0; }
table { width: 100%; border: 1px solid #c9d5e5; margin: 8px 0; }
th { background-color: #16325c; color: #ffffff; text-align: left; padding: 5px; font-size: 9pt; }
td { border: 1px solid #d5dde8; padding: 5px; font-size: 9pt; vertical-align: top; }
tr:nth-child(even) td { background-color: #f6f8fb; }
hr { border: 0; border-top: 1px solid #d5dde8; margin: 14px 0; }
"""

# Characters the built-in PDF font (WinAnsi) can't render -> ASCII fallbacks.
REPLACEMENTS = {
    "\u27f6": "->",  # long right arrow
    "\u2192": "->",  # right arrow
    "\u2190": "<-",  # left arrow
    "\u21c4": "<->", # left-right arrows
}

def main():
    with open(SRC, "r", encoding="utf-8") as f:
        text = f.read()
    for bad, good in REPLACEMENTS.items():
        text = text.replace(bad, good)

    body = markdown.markdown(text, extensions=["tables", "fenced_code", "sane_lists"])
    html = f"<html><head><meta charset='utf-8'><style>{CSS}</style></head><body>{body}</body></html>"

    with open(OUT, "wb") as out_file:
        result = pisa.CreatePDF(src=html, dest=out_file, encoding="utf-8")

    if result.err:
        raise SystemExit(f"PDF generation reported {result.err} error(s)")
    print(f"Wrote {OUT}")

if __name__ == "__main__":
    main()
