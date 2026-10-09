"""Arma el Excel del catálogo (docs/catalogo.xlsx) a partir del JSON que escribe tests/export_catalog.gd.
Uso: python tests/build_catalog_xlsx.py ruta.json docs/catalogo.xlsx"""
import json
import sys

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill

src, dst = sys.argv[1], sys.argv[2]
sheets = json.load(open(src, encoding="utf-8"))
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
wb.save(dst)
print("listo:", dst, [ (n, len(r)) for n, r in sheets.items()])
