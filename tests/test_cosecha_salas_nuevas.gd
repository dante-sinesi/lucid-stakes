extends SceneTree
## La claridad de la torre nueva (salas_nuevas/cosecha.gd y su uso en torre.gd). Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/test_cosecha_salas_nuevas.gd
const Torre := preload("res://salas_nuevas/torre.gd")
const Cosecha := preload("res://salas_nuevas/cosecha.gd")
var fallos := 0
func _ok(c: bool, m: String) -> void:
	print(("ok  " if c else "FALLA ") + m)
	if not c:
		fallos += 1
func _init() -> void:
	# reglas puras
	var c = Cosecha.new()
	c.despues_de_accion(["n"], false, 2)
	_ok(c.sala == 1 and c.streak == 1, "un bloque común da 1 y arranca la racha")
	c.despues_de_accion(["n", "i"], false, 3)   # racha 2 -> x1,5 ; base 1 + 2
	_ok(c.sala == 1 + int(round(3 * 1.5)), "dos bloques con racha 2: 3 x 1,5 (%d)" % c.sala)
	c.despues_de_accion([], false, 3)
	_ok(c.streak == 0, "una acción sin nada nuevo corta la racha")
	c.asegurar()
	_ok(c.banco > 0 and c.sala == 0, "al llegar al checkpoint se asegura")
	c.despues_de_accion(["n"], false, 4)
	c.perder_intento()
	_ok(c.sala == 0 and c.streak == 0, "al morir se pierde la claridad del intento")
	var p = Cosecha.new()
	p.aplicar_boosts(["cosecha_doble", "pies_de_luz", "mano_de_oro", "buen_ojo"])
	p.despues_de_accion(["i"], false, 2)   # 2 x2 (buen ojo) + 1 (pies de luz) = 5, racha 1 x1, cosecha x2 = 10
	_ok(p.sala == 10, "boosts de cosecha: hielo con buen ojo, pies de luz y cosecha doble = 10 (%d)" % p.sala)
	var r = Cosecha.new()
	r.aplicar_boosts(["racha_imparable"])
	r.despues_de_accion(["n"], false, 2)
	r.despues_de_accion([], true, 2)
	_ok(r.streak == 1, "Racha imparable: empujar o tirar no corta la racha")
	# en la torre: jugar las salas con su camino acumula claridad y no se pierde
	var paquete := Torre.cargar_paquete(ProjectSettings.globalize_path("res://bibliotecas/paquete_salas.jsonl"))
	var t = Torre.armar(paquete, 3, 4)
	for k in t.salas.size():
		for a in t.salas[k].d.camino:
			t.actuar(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
	_ok(t.terminada and t.cosecha.claridad() > t.salas.size() * 3, "una torre completa da claridad (%d)" % t.cosecha.claridad())
	_ok(t.cosecha.sala == 0 and t.cosecha.banco == t.cosecha.claridad(), "todo queda asegurado al llegar al portal")
	var t2 = Torre.armar(paquete, 3, 4)
	var cam: Array = t2.salas[0].d.camino
	for i in mini(5, cam.size() - 1):
		t2.actuar(Vector3i(int(cam[i][0]), 0, int(cam[i][1])), int(cam[i][2]))
	var antes: int = t2.cosecha.claridad()
	_ok(antes > 0, "a mitad de la sala ya se juntó claridad (%d)" % antes)
	t2.salas[0].max_mov = t2.movs + 1
	t2.actuar(Vector3i(int(cam[5][0]), 0, int(cam[5][1])), int(cam[5][2]))   # se acaban los movimientos: muerte
	_ok(t2.cosecha.claridad() == 0 and t2.vidas == 2, "morir pierde la claridad del intento (%d)" % t2.cosecha.claridad())
	print("fallos: ", fallos)
	quit(1 if fallos > 0 else 0)
