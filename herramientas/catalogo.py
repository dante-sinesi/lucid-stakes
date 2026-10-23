r"""Arma el catálogo del juego a partir del JSON que escribe herramientas/catalogo.gd: docs/catalogo.md (una tabla por hoja) y docs/catalogo.xlsx.
Uso: python herramientas/catalogo.py ruta.json   (o herramientas\catalogo.bat, que corre las dos cosas)"""
import json
import sys

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill

src = sys.argv[1]
sheets = json.load(open(src, encoding="utf-8"))

# --- Markdown
md = ["# Catálogo del juego", "",
      "Generado con `herramientas/catalogo.bat` a partir del código (no se edita a mano: se vuelve a generar cuando cambia el contenido).", ""]
for name, rows in sheets.items():
    md.append("## " + name)
    md.append("")
    has_extra = any(r[2] for r in rows)
    md.append("| Nombre | Descripción |" + (" Más datos |" if has_extra else ""))
    md.append("|---|---|" + ("---|" if has_extra else ""))
    for r in rows:
        celdas = [str(c).replace("|", "\\|").replace("\n", " ") for c in r[:3 if has_extra else 2]]
        md.append("| " + " | ".join(celdas) + " |")
    md.append("")
open("docs/catalogo.md", "w", encoding="utf-8", newline="\n").write("\n".join(md))

# --- Excel
wb = Workbook()
wb.remove(wb.active)
head_fill = PatternFill("solid", fgColor="2B1B4A")
for name, rows in sheets.items():
    ws = wb.create_sheet(name[:31])
    has_extra = any(r[2] for r in rows)
    ws.append(["Nombre", "Descripción"] + (["Más datos"] if has_extra else []))
    for r in rows:
        ws.append(r[:3] if has_extra else r[:2])
    for c in ws[1]:
        c.font = Font(bold=True, color="FFFFFF")
        c.fill = head_fill
    ws.column_dimensions["A"].width = 30
    ws.column_dimensions["B"].width = 95
    if has_extra:
        ws.column_dimensions["C"].width = 42
    for row in ws.iter_rows(min_row=2):
        for c in row:
            c.alignment = Alignment(wrap_text=True, vertical="top")
        row[0].font = Font(bold=True)
    ws.freeze_panes = "A2"
wb.save("docs/catalogo.xlsx")
print("listo: docs/catalogo.md y docs/catalogo.xlsx", [(n, len(r)) for n, r in sheets.items()])
