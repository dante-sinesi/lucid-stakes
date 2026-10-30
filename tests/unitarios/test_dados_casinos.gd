extends SceneTree
## Los dados y la mesa de cada casino: el estilo de cada nivel, y el dado de cristal (minicubos translúcidos) que, igual que el hielo, va en dos mallas (caras de atrás dibujadas antes) y no en una sola.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_dados_casinos.gd

const Dice3D := preload("res://scripts/casino/dice_3d.gd")

var fallos := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fallos += 1
		print("FAIL: ", label)


func _init() -> void:
	var d = Dice3D.new()
	root.add_child(d)
	await process_frame
	for t in 4:
		var n: int = (Dice3D.ALTERNATIVAS[t] as Array).size() if Dice3D.ALTERNATIVAS.has(t) else 1
		for alt in n:
			d.set_tier(t, alt)
			check(d.dice.size() == 5 and d._table_mi != null and d._table_mi.mesh != null, "casino %d, alternativa %d: se arman los cinco dados y la mesa" % [t, alt])
			var vox := Dice3D._die_voxels(t, alt)
			check(vox.size() > 250, "casino %d, alternativa %d: el dado tiene sus minicubos (%d)" % [t, alt, vox.size()])
			var ventanas := bool(Dice3D.estilo(t, alt).get("ventanas", false))
			var cuerpo: MeshInstance3D = d.dice[0].get_child(0)
			check(d.vidrio_atras[0].visible == ventanas and d.vidrio_delante[0].visible == ventanas, "casino %d, alternativa %d: el vidrio sólo se usa en el dado de ventanas" % [t, alt])
			if ventanas:
				check(cuerpo.material_override is StandardMaterial3D, "la cáscara es opaca")
				check(d.vidrio_delante[0].material_override is ShaderMaterial and d.vidrio_atras[0].material_override is ShaderMaterial, "el vidrio usa los dos materiales translúcidos")
				check(d.vidrio_atras[0].material_override.render_priority < d.vidrio_delante[0].material_override.render_priority, "las caras de atrás del vidrio se dibujan antes que las de adelante (si no, parpadea al girar)")
				check(d.vidrio_atras[0].mesh == d.vidrio_delante[0].mesh, "las dos mallas del vidrio son la misma")
				var uv: PackedVector2Array = d.vidrio_delante[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
				var translucidos := 0
				for v in uv:
					if v.x < 0.95:
						translucidos += 1
				check(translucidos == uv.size() and uv.size() > 200, "todo el vidrio es translúcido: el número y el núcleo (%d vértices)" % uv.size())
				var celdas := Dice3D._celdas_de_puntos()
				var abiertas := 0
				for celda in celdas:
					if not vox.has(celda[0]) and not vox.has(celda[0] - celda[1]):
						abiertas += 1
				check(abiertas == celdas.size(), "los puntos son ventanas de la cáscara hasta el núcleo (%d de %d)" % [abiertas, celdas.size()])
				check(not vox.has(Vector3i(3, 3, 3)), "la cáscara está hueca donde va el núcleo")
	check(Dice3D.estilo(2, 0).cuerpo != Color(0.70, 0.10, 0.14), "ya no hay dado rojo")
	d.queue_free()
	print("tests de los dados por casino terminados, fallos: ", fallos)
	quit(1 if fallos > 0 else 0)
