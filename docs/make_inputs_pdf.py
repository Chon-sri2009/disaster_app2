"""Builds INPUTS_NEEDED.pdf (fillable AcroForm) from INPUTS_NEEDED.md.

Each line containing '>>' becomes a text field prefilled with the text after '>>'.
Table rows with '>>' cells get one field per '>>' cell, labelled by the first cell.
"""
import re
import textwrap
from pathlib import Path

from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas

here = Path(__file__).parent
lines = (here / "INPUTS_NEEDED.md").read_text(encoding="utf-8").splitlines()

W, H = A4
M = 40
c = canvas.Canvas(str(here / "INPUTS_NEEDED.pdf"), pagesize=A4)
c.setTitle("Inputs needed from the owner")
y = H - M
n = 0


def room(need):
    global y
    if y - need < M:
        c.showPage()
        y = H - M


def text(s, font="Helvetica", size=9, indent=0, leading=12):
    global y
    # Non-Latin characters cannot be drawn with the built-in fonts; replace them.
    s = s.encode("latin-1", "replace").decode("latin-1")
    for part in textwrap.wrap(s, int((W - 2 * M - indent) / (size * 0.5))) or [""]:
        room(leading)
        c.setFont(font, size)
        c.drawString(M + indent, y, part)
        y -= leading


def field(label, value):
    global y, n
    n += 1
    text(label, size=8, leading=11)
    room(24)
    c.acroForm.textfield(
        name=f"f{n}",
        value=value,
        x=M,
        y=y - 20,
        width=W - 2 * M,
        height=20,
        borderStyle="inset",
        fontSize=10,
        fieldFlags="",
    )
    y -= 28


for raw in lines:
    s = raw.strip()
    if not s or s.startswith("|---"):
        continue
    if s.startswith("# "):
        text(s[2:], "Helvetica-Bold", 16, leading=22)
    elif s.startswith("## "):
        y -= 8
        text(s[3:], "Helvetica-Bold", 12, leading=16)
    elif s.startswith("|"):
        cells = [x.strip() for x in s.strip("|").split("|")]
        if any(">>" in x for x in cells):
            for i, cell in enumerate(cells):
                if ">>" in cell:
                    label = f"{cells[0]}  [{cell and 'column ' + str(i + 1)}]"
                    field(label, cell.replace(">>", "").strip())
        else:
            text("  |  ".join(cells), "Helvetica-Bold", 8)
    elif ">>" in s:
        label, _, value = s.partition(">>")
        field(label.lstrip("- ").rstrip(": ").strip() or "Notes", value.strip())
    else:
        text(re.sub(r"[`*]", "", s))

c.save()
print("fields:", n)
