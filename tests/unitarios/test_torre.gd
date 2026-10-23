extends SceneTree
## La torre de salas nuevas (torre/torre.gd): armado encadenado, partida completa con el camino de cada sala, temporizador, muertes y fin.
## Uso: GAME_SANDBOX=1 [SALAS_PAQUETE=archivo.jsonl] godot --headless --path . -s tests/unitarios/test_torre.gd
const Torre := preload("res://torre/torre.gd")

var fallos := 0


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("ok  ", msg)
	else:
		print("FALLA ", msg)
		fallos += 1


func _jugar_camino(t, sala: int) -> Dictionary:
	var ultimo := {}
	for a in t.salas[sala].d.camino:
		ultimo = t.actuar(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
		if not ultimo.ok:
			return {"ok": false, "evento": "no se pudo: " + str(ultimo.msg)}
		if str(ultimo.evento) != "" and str(ultimo.evento) != "checkpoint" and str(ultimo.evento) != "torre":
			return ultimo
	return ultimo


func _init() -> void:
	var ruta := OS.get_environment("SALAS_PAQUETE")
	if ruta == "":
		ruta = ProjectSettings.globalize_path("res://bibliotecas/paquete_salas.jsonl")
	var paquete := Torre.cargar_paquete(ruta)
	_ok(paquete.size() > 100, "el paquete tiene salas (%d)" % paquete.size())
	# simetrías: las salas girar dos veces con la misma simetría vuelven a ser la misma (son involuciones salvo los giros de 90 grados)
	var d0: Dictionary = paquete[0]
	var g := Torre.girar(Torre.girar(d0, 1), 1)
	var igual: bool = g.bloques.size() == d0.bloques.size()
	for i in g.bloques.size():
		for q in 3:
			if int(g.bloques[i][q]) != int(d0.bloques[i][q]):
				igual = false
		if str(g.bloques[i][3]) != str(d0.bloques[i][3]):
			igual = false
	_ok(igual and int(g.jugador[0]) == int(d0.jugador[0]) and int(g.jugador[2]) == int(d0.jugador[2]), "espejar dos veces devuelve la sala original")
	var jugadas := 0
	var cortas := 0
	for semilla in range(1, 21):
		var t = Torre.armar(paquete, semilla, 6)
		if t.salas.size() < 6:
			cortas += 1
		# encadenado: la salida de cada sala es la entrada de la siguiente y los desplazamientos son consecutivos
		var enc := true
		for k in range(t.salas.size() - 1):
			if Torre.salida_xz(t.salas[k].d) != Torre.entrada_xz(t.salas[k + 1].d):
				enc = false
			if int(t.salas[k + 1].off) != int(t.salas[k].off) + int(t.salas[k].d.meta) - 1:
				enc = false
		_ok(enc, "torre %d encadenada (%d salas, %d pisos)" % [semilla, t.salas.size(), t.total_pisos()])
		# partida completa con el camino de cada sala
		var r := {}
		for k in t.salas.size():
			r = _jugar_camino(t, k)
			if not r.ok or (str(r.evento) != "checkpoint" and str(r.evento) != "torre"):
				break
		_ok(t.terminada and t.vidas == 3 and t.muertes == 0, "torre %d: se completa con los caminos (vidas %d, muertes %d)" % [semilla, t.vidas, t.muertes])
		if t.terminada:
			jugadas += 1
	_ok(cortas == 0, "todas las torres salieron de 6 salas (%d cortas)" % cortas)
	# la torre da vueltas al anillo: con 8 salas, al menos media vuelta (y las huellas caen dentro del anillo)
	var dan_vuelta := 0
	var en_anillo := true
	for semilla in range(1, 11):
		var t3 = Torre.armar(paquete, semilla, 8)
		if t3.salas.size() == 8 and Torre.vueltas(t3) >= 0.4:
			dan_vuelta += 1
		for sala in t3.salas:
			if not Torre.huella_valida(Torre.huella(sala.d)):
				en_anillo = false
	_ok(dan_vuelta >= 9, "las torres de 8 salas dan al menos media vuelta al anillo (%d de 10)" % dan_vuelta)
	_ok(en_anillo, "todas las salas caen dentro del anillo, sin pisar el vacío")
	# temporizador: con 3 movimientos de máximo, se muere al tercero y la sala vuelve a empezar
	var t2 = Torre.armar(paquete, 5, 6)
	t2.salas[0].max_mov = 3
	var cam: Array = t2.salas[0].d.camino
	var evento := ""
	for i in 3:
		var r2: Dictionary = t2.actuar(Vector3i(int(cam[i][0]), 0, int(cam[i][1])), int(cam[i][2]))
		evento = str(r2.evento)
	_ok(evento == "muerte", "al agotarse los movimientos se pierde una vida")
	_ok(t2.vidas == 2 and t2.movs == 0 and t2.indice == 0, "queda en la misma sala, con 2 vidas y el contador en 0")
	var j0: Array = t2.salas[0].d.jugador
	_ok(t2.motor.jugador == Vector3i(int(j0[0]), int(j0[1]), int(j0[2])), "el jugador vuelve a la entrada con la sala virgen")
	# sin vidas: fin
	for i in 2:
		for k in 3:
			var r3: Dictionary = t2.actuar(Vector3i(int(cam[k][0]), 0, int(cam[k][1])), int(cam[k][2]))
			evento = str(r3.evento)
	_ok(evento == "fin" and t2.perdida, "tras la tercera muerte se acaba la partida")
	var r4: Dictionary = t2.actuar(Vector3i(1, 0, 0), 0)
	_ok(not r4.ok, "terminada la partida no se puede seguir")
	print("fallos: ", fallos)
	quit(1 if fallos > 0 else 0)
