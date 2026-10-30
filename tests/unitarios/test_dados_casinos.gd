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
			check(vox.size() > 300, "casino %d, alternativa %d: el dado tiene sus minicubos (%d)" % [t, alt, vox.size()])
			var cristal := bool(Dice3D.estilo(t, alt).get("cristal", false))
			var delante: MeshInstance3D = d.dice[0].get_child(0)
			check(d.nucleos[0].visible == cristal, "casino %d, alternativa %d: el núcleo sólo se usa con el cristal" % [t, alt])
			check(d.atras[0].visible == cristal, "casino %d, alternativa %d: la malla de atrás sólo se usa con el cristal" % [t, alt])
			if cristal:
				check(delante.material_override is ShaderMaterial and d.atras[0].material_override is ShaderMaterial, "el cristal usa los dos materiales translúcidos")
				check(d.atras[0].material_override.render_priority < delante.material_override.render_priority, "las caras de atrás se dibujan antes que las de adelante (si no, el vidrio parpadea al girar)")
				check(d.atras[0].mesh == delante.mesh, "las dos mallas son la misma")
				check(d.nucleos[0].visible and d.nucleos[0].mesh != null and d.nucleos[0].mesh.get_aabb().size.x > 0.2, "el cristal lleva un núcleo opaco que tapa los puntos de atrás")
				var uv: PackedVector2Array = delante.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
				var translucidos := 0
				var opacos := 0
				for v in uv:
					if v.x < 0.9:
						translucidos += 1
					elif v.x >= 0.99:
						opacos += 1
				check(translucidos > 100 and opacos > 20, "el cristal lleva la opacidad por minicubo (%d translúcidos, %d opacos: los puntos)" % [translucidos, opacos])
	check(Dice3D.estilo(2, 0).cuerpo != Color(0.70, 0.10, 0.14), "ya no hay dado rojo")
	d.queue_free()
	print("tests de los dados por casino terminados, fallos: ", fallos)
	quit(1 if fallos > 0 else 0)
