extends SceneTree
const Torre := preload("res://salas_nuevas/torre.gd")
func _init() -> void:
	var p := Torre.cargar_paquete(ProjectSettings.globalize_path("res://bibliotecas/paquete_salas.jsonl"))
	var cnt := {}
	for d in p:
		var e := Torre.entrada_xz(d)
		var x := Torre.salida_xz(d)
		for s in 8:
			var k := str(Torre.xz_sim(e.x, e.y, s))
			cnt[k] = cnt.get(k, 0) + 1
	print("entradas posibles tras simetrias: ", cnt.size())
	var ks := cnt.keys()
	ks.sort()
	var ex := {}
	for d in p:
		var x := Torre.salida_xz(d)
		ex[str(x)] = ex.get(str(x), 0) + 1
	print("salidas distintas: ", ex.size(), " ", ex)
	var en := {}
	for d in p:
		var e := Torre.entrada_xz(d)
		en[str(e)] = en.get(str(e), 0) + 1
	print("entradas distintas: ", en.size(), " ", en)
	for semilla in range(1, 21):
		var t = Torre.armar(p, semilla, 6)
		if t.salas.size() < 6:
			print("semilla ", semilla, " salas ", t.salas.size(), " ultima salida ", Torre.salida_xz(t.salas[t.salas.size()-1].d))
	quit(0)
