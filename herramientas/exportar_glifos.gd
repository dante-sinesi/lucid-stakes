extends SceneTree
## Vuelca las celdas de cada glifo de la fuente de cubitos (`scripts/ui/voxel_font.gd`) a un JSON: {"caracter": [[x, fila], ...]}. Las filas van de 0 (arriba de todo, donde caen los acentos) a 10 (la cola de g, j, p, q, y).
## Lo usa `herramientas/generar_fuente_web.py`. Uso: godot --headless --path . -s herramientas/exportar_glifos.gd -- SALIDA.json
const VFont := preload("res://scripts/ui/voxel_font.gd")


func _init() -> void:
	var salida: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "glifos.json"
	var chars: Array = []
	for k in VFont.G:
		chars.append(str(k))
	for k in VFont.ACCENTED:
		chars.append(str(k))
	var out := {}
	for ch in chars:
		var cells: Array = []
		for c in VFont.glyph_cells(ch):
			cells.append([c.x, c.y])
		out[ch] = cells
	var f := FileAccess.open(salida, FileAccess.WRITE)
	f.store_string(JSON.stringify({"ancho": VFont.W, "avance": VFont.ADVANCE, "filas_acento": VFont.ACCENT_ROWS, "filas_cuerpo": VFont.BODY_ROWS, "filas_cola": VFont.TAIL_ROWS, "glifos": out}))
	f.close()
	print("glifos: ", out.size())
	quit(0)
