extends SceneTree
## Los contratos (scripts/datos/contratos.gd): el tablón persistente, aceptar, rechazar, rotar, la fianza, el seguimiento en la torre y el cobro (con Contratista y Sello de oro).
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_contratos.gd
const Contratos := preload("res://scripts/datos/contratos.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const Roulette := preload("res://scripts/casino/roulette.gd")
const Items := preload("res://scripts/datos/items.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_catalogo()
	test_cartelera()
	test_aceptar_y_limite()
	test_fianza()
	test_rotar()
	test_seguimiento()
	test_cobro()
	test_anulados()
	test_guardado()
	print("tests de los contratos terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func make_run(stage := 1, claridad := 1000) -> RunState:
	var run := RunState.new()
	run.stage = stage
	run.claridad = claridad
	return run


func rng_con(semilla: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = semilla
	return r


func papel(obj: String, r: int, n: int, pct := 0.2) -> Dictionary:
	return {"id": 99, "obj": obj, "r": r, "n": n, "pct": pct, "monto": 0, "fianza": 0}


func test_catalogo() -> void:
	for id in Contratos.OBJETIVOS:
		var d: Dictionary = Contratos.OBJETIVOS[id]
		check(preload("res://scripts/ui/contract_art.gd").tiene_objetivo(str(d.icono)), "el objetivo %s tiene su ícono" % id)
		check(d.ns.size() == 4 and (d.ns[0] != null or d.ns[1] != null), "el objetivo %s tiene sus cuatro rarezas" % id)
		check(str(d.titulo) != "" and str(d.condicion) != "", "el objetivo %s tiene título y condición" % id)
	check(Contratos.capacidad(0) == 3 and Contratos.capacidad(1) == 4 and Contratos.capacidad(2) == 5 and Contratos.capacidad(3) == 6, "la cartelera tiene 3, 4, 5 y 6 lugares")
	check(Contratos.PESOS_RAREZA[0][3] == 0.0 and Contratos.PESOS_RAREZA[3][3] > 0.0, "los imposibles no salen en la taberna")
	for it in ["caza_recompensas", "contratista", "sello_de_oro"]:
		check(not Items.get_item(it).is_empty() and preload("res://scripts/ui/item_icons.gd").has_icon(it), "%s está en el catálogo con su ícono" % it)
	check(Items.CASINO_USABLE.has("sello_de_oro") and Items.get_item("contratista").tier == Items.Tier.EPICO, "el Sello de oro se usa en el casino y Contratista es épico")


func test_cartelera() -> void:
	var run := make_run(1)
	var n := Contratos.entrar(run, rng_con(1), 0)
	check(n == 3 and Contratos.cartelera(run).size() == 3 and Contratos.cartelera(run).count(null) == 0, "la primera visita llena los 3 lugares de la taberna")
	var primeros: Array = Contratos.cartelera(run).duplicate(true)
	n = Contratos.entrar(run, rng_con(2), 0)
	check(n == 0 and Contratos.cartelera(run) == primeros, "si no hay huecos no aparece nada y los papeles son los mismos")
	Contratos.rechazar(run, 1)
	Contratos.rechazar(run, 2)
	n = Contratos.entrar(run, rng_con(3), 1)
	check(n == 2 and Contratos.cartelera(run).size() == 4, "el salón agrega un lugar y llegan 2 papeles nuevos (de 3 huecos)")
	check(Contratos.cartelera(run)[0] == primeros[0], "el papel que quedó colgado sigue ahí")
	for i in 4:
		Contratos.rechazar(run, i)
	n = Contratos.entrar(run, rng_con(4), 1)
	check(n == 2, "con todos los huecos libres igual aparecen sólo 2")
	var imposibles := 0
	for i in 40:
		var corrida := make_run(12)
		Contratos.entrar(corrida, rng_con(100 + i), 3)
		var cuenta := 0
		for p in Contratos.cartelera(corrida):
			if p != null and int(p.r) == Contratos.Rareza.IMPOSIBLE:
				cuenta += 1
		check(cuenta <= 1, "a lo sumo un imposible colgado (%d)" % cuenta)
		imposibles += cuenta
	check(imposibles > 0, "en el gran casino salen imposibles de vez en cuando")
	var tempranos := make_run(1)
	for i in 30:
		for k in 3:
			Contratos.rechazar(tempranos, k)
		Contratos.entrar(tempranos, rng_con(200 + i), 0)
		for p in Contratos.cartelera(tempranos):
			if p != null:
				check(int(p.r) <= 1 and int(Contratos.OBJETIVOS[p.obj].desde) <= 2, "la taberna sólo da comunes y raros de los objetivos que ya existen (%s r%d)" % [p.obj, p.r])


func test_aceptar_y_limite() -> void:
	var run := make_run(5)
	Contratos.entrar(run, rng_con(5), 1)
	var antes := Contratos.cartelera(run).duplicate(true)
	check(Contratos.limite(run) == 2, "se pueden tener 2 contratos activos")
	var r := Contratos.aceptar(run, 0, false, 1)
	check(r.ok and Contratos.activos(run).size() == 1 and Contratos.cartelera(run)[0] == null, "aceptar pasa el papel de la cartelera a los activos")
	check(int(Contratos.activos(run)[0].monto) == Contratos.recompensa(antes[0], 5) and int(Contratos.activos(run)[0].monto) > 0, "la recompensa se calcula al aceptar")
	check(not Contratos.aceptar(run, 0, false, 1).ok, "no se acepta un lugar vacío")
	check(Contratos.aceptar(run, 1, false, 1).ok and Contratos.activos(run).size() == 2, "se acepta un segundo")
	var tercero := Contratos.aceptar(run, 2, false, 1)
	check(not tercero.ok and Contratos.activos(run).size() == 2 and Contratos.cartelera(run)[2] != null, "el tercero no entra (límite) y el papel sigue colgado")
	run.boosts.append("caza_recompensas")
	check(Contratos.limite(run) == 3 and Contratos.aceptar(run, 2, false, 1).ok, "con Caza recompensas entra un tercero")
	run.boosts.append("caza_recompensas")
	check(Contratos.limite(run) == 4, "y se acumula")
	check(not Contratos.rechazar(run, 0).ok, "rechazar un hueco no hace nada")


func test_fianza() -> void:
	var run := make_run(9, 1000)
	Contratos.entrar(run, rng_con(6), 2)
	var p: Dictionary = Contratos.cartelera(run)[0]
	var f := Contratos.fianza(p, 9)
	check(f == maxi(int(round(Contratos.recompensa(p, 9) * 0.5)), 1), "la fianza es la mitad de la recompensa")
	check(not Contratos.permite_fianza(1) and Contratos.permite_fianza(2) and Contratos.permite_fianza(3), "la fianza sólo está en el casino y el gran casino")
	check(not Contratos.aceptar(run, 0, true, 1).ok and run.claridad == 1000, "en el salón no se acepta con fianza")
	var pobre := make_run(9, 0)
	Contratos.entrar(pobre, rng_con(6), 2)
	check(not Contratos.aceptar(pobre, 0, true, 2).ok and Contratos.activos(pobre).is_empty(), "sin claridad no se paga la fianza")
	var r := Contratos.aceptar(run, 0, true, 2)
	check(r.ok and run.claridad == 1000 - f and int(Contratos.activos(run)[0].fianza) == f, "con fianza se paga ahora y queda anotada")


func test_rotar() -> void:
	var run := make_run(5, 1000)
	Contratos.entrar(run, rng_con(7), 1)
	var ficha := Roulette.run_price(run)
	check(Contratos.costo_rotar(run) == int(round(ficha * 0.5)), "rotar cuesta la mitad de la ficha")
	var ids_antes: Array = Contratos.cartelera(run).map(func(p): return p.id)
	var r := Contratos.rotar(run, rng_con(8), 1)
	check(r.ok and run.claridad == 1000 - int(round(ficha * 0.5)), "se cobra lo que cuesta")
	check(Contratos.cartelera(run).map(func(p): return p.id) != ids_antes and Contratos.cartelera(run).count(null) == 0, "los papeles son otros y siguen ocupando todos los lugares")
	check(Contratos.costo_rotar(run) == int(round(ficha * 0.5 * 2.0)), "la siguiente rotación cuesta el doble (sube de forma lineal)")
	Contratos.rotar(run, rng_con(9), 1)
	check(Contratos.costo_rotar(run) == int(round(ficha * 0.5 * 3.0)), "y la otra el triple")
	Contratos.entrar(run, rng_con(10), 1)
	check(Contratos.costo_rotar(run) == int(round(ficha * 0.5)), "al entrar a otro casino se reinicia la cuenta")
	Contratos.aceptar(run, 0, false, 1)
	var activo: Dictionary = Contratos.activos(run)[0]
	Contratos.rotar(run, rng_con(11), 1)
	check(Contratos.activos(run)[0] == activo, "rotar no toca los activos")
	check(Contratos.cartelera(run)[0] == null, "y el hueco de lo aceptado sigue vacío")
	var llave := make_run(5, 1000)
	llave.boosts.append("llave_de_la_vitrina")
	Contratos.entrar(llave, rng_con(12), 1)
	check(Contratos.costo_rotar(llave) == 0, "con la Llave de la vitrina la primera rotación es gratis")
	Contratos.rotar(llave, rng_con(13), 1)
	check(llave.claridad == 1000 and Contratos.costo_rotar(llave) > 0, "y no cuesta nada, pero la segunda sí")
	var sin := make_run(5, 0)
	Contratos.entrar(sin, rng_con(14), 1)
	check(not Contratos.rotar(sin, rng_con(15), 1).ok, "sin claridad no se rota")


func test_seguimiento() -> void:
	var run := make_run(5)
	run.contratos = {"cartelera": [], "activos": [papel("racha", 0, 6), papel("sin_deshacer", 0, 0), papel("especiales", 0, 4), papel("movimientos", 0, 20), papel("sin_vidas", 1, 0), papel("claridad", 0, 300), papel("sin_empujar", 0, 2), papel("bombas", 0, 1), papel("catapulta", 0, 1)], "iniciada": true, "rotaciones": 0, "torre": {}, "siguiente_id": 100}
	for p in run.contratos.activos:
		p["monto"] = 100
	Contratos.empezar_torre(run)
	var res := Contratos.registrar(run, "accion", {"racha": 3, "claridad": 100, "especiales": 2, "bombas": 0, "agarro": true})
	check(res.is_empty(), "todavía no se cumple nada")
	res = Contratos.registrar(run, "accion", {"racha": 6, "claridad": 120, "especiales": 3})
	check(res.size() == 1 and res[0].cumplido and res[0].papel.obj == "racha", "llegar a la racha cobra el contrato en el momento")
	check(Contratos.activos(run).size() == 8, "y sale de los activos")
	res = Contratos.registrar(run, "sala", {"movs": 10, "max_mov": 20, "especiales": 3, "bombas": 0})
	check(res.is_empty() and Contratos.activos(run).size() == 8, "se superó una sala pero se había empujado: no cuenta como limpia")
	res = Contratos.registrar(run, "accion", {"racha": 0, "claridad": 130, "especiales": 1, "agarro": false})
	check(res.size() == 1 and res[0].papel.obj == "especiales" and res[0].cumplido, "4 especiales entre las salas hechas y la actual")
	res = Contratos.registrar(run, "accion", {"salto": true, "bombas": 1})
	var objs: Array = res.map(func(x): return x.papel.obj)
	check(objs.has("bombas") and objs.has("catapulta"), "una bomba desactivada y un salto cumplen sus contratos")
	res = Contratos.registrar(run, "sala", {"movs": 5, "max_mov": 20, "especiales": 0, "bombas": 0})
	res = Contratos.registrar(run, "sala", {"movs": 5, "max_mov": 20})
	check(res.any(func(x): return x.papel.obj == "sin_empujar" and x.cumplido), "dos salas sin empujar cumplen Manos limpias (la primera, con empuje, no cuenta)")
	res = Contratos.registrar(run, "deshacer")
	check(res.size() == 1 and res[0].papel.obj == "sin_deshacer" and not res[0].cumplido, "deshacer pierde Sin marcha atrás en el acto")
	res = Contratos.registrar(run, "vida")
	check(res.size() == 1 and res[0].papel.obj == "sin_vidas" and not res[0].cumplido, "perder una vida pierde Intocable")
	res = Contratos.registrar(run, "torre")
	var por: Dictionary = {}
	for x in res:
		por[x.papel.obj] = x.cumplido
	check(por.get("movimientos", false), "al terminar la torre sobraron más del 20 % de los movimientos (30 de 60 sin gastar)")
	check(not por.get("claridad", true), "la claridad no llegó a 300 y falla al terminar")
	check(Contratos.activos(run).is_empty(), "al terminar la torre no queda nada activo")
	run.contratos.activos.append(papel("sin_deshacer", 0, 0))
	run.contratos.activos[0]["monto"] = 50
	Contratos.empezar_torre(run)
	res = Contratos.registrar(run, "torre")
	check(res.size() == 1 and res[0].cumplido, "sin deshacer en la torre nueva se cumple")


func test_cobro() -> void:
	var run := make_run(5, 0)
	var p := papel("racha", 0, 2)
	p["monto"] = 100
	run.contratos = {"cartelera": [], "activos": [p.duplicate()], "iniciada": true, "rotaciones": 0, "torre": {}, "siguiente_id": 1}
	var res := Contratos.registrar(run, "accion", {"racha": 5})
	check(res[0].monto == 100 and run.claridad == 100, "un contrato común paga su recompensa")
	var f := p.duplicate()
	f["fianza"] = 50
	run.contratos.activos = [f]
	run.claridad = 0
	res = Contratos.registrar(run, "accion", {"racha": 5})
	check(res[0].monto == 200 and run.claridad == 200, "con fianza paga ×1,5 y devuelve la fianza (150 + 50)")
	run.boosts.append("contratista")
	run.contratos.activos = [p.duplicate()]
	run.claridad = 0
	Contratos.registrar(run, "accion", {"racha": 5})
	check(run.claridad == 200, "Contratista duplica lo que paga")
	run.sello_oro = true
	run.contratos.activos = [p.duplicate()]
	run.claridad = 0
	Contratos.registrar(run, "accion", {"racha": 5})
	check(run.claridad == 1000 and not run.sello_oro, "el Sello de oro lo multiplica por 5 (con Contratista: ×10) y se gasta")
	run.contratos.activos = [p.duplicate()]
	run.claridad = 0
	Contratos.registrar(run, "accion", {"racha": 5})
	check(run.claridad == 200, "el siguiente contrato vuelve a pagar lo de siempre")
	var g := p.duplicate()
	g["fianza"] = 40
	run.contratos.activos = [g]
	Contratos.empezar_torre(run)
	run.claridad = 500
	res = Contratos.registrar(run, "torre")
	check(not res[0].cumplido and res[0].monto == -40 and run.claridad == 500, "un contrato fallido con fianza muestra la fianza perdida y no cobra nada")
	run.contratos.activos = [p.duplicate()]
	Contratos.empezar_torre(run)
	res = Contratos.registrar(run, "torre")
	check(not res[0].cumplido and res[0].monto == 0, "uno fallido sin fianza no pierde nada")


func test_anulados() -> void:
	var run := make_run(9, 100)
	var bombas := papel("bombas", 0, 3)
	bombas["fianza"] = 30
	run.contratos = {"cartelera": [], "activos": [bombas, papel("racha", 0, 5), papel("especiales", 1, 6), papel("catapulta", 0, 2)], "iniciada": true, "rotaciones": 0, "torre": {}, "siguiente_id": 1}
	var anulados := Contratos.empezar_torre(run, {"especiales": 8, "bombas": 2, "catapultas": 3, "salas": 9})
	check(anulados.size() == 1 and anulados[0].obj == "bombas" and run.claridad == 130, "un contrato de 3 bombas en una torre con 2 se anula y devuelve su fianza")
	check(Contratos.activos(run).size() == 3, "los demás siguen")
	var cap := Contratos.capacidad_de(_Falsa.new())
	check(cap.salas == 2 and cap.especiales == 3 and cap.bombas == 1 and cap.catapultas == 1, "se cuentan los bloques especiales, las bombas y las catapultas de la torre (%s)" % str(cap))


## Lo mínimo de un Torre para contar bloques.
class _Falsa:
	var salas: Array = [{"d": {"bloques": [[0, 1, 0, "p"], [1, 1, 0, "n"], [2, 1, 0, "b7"], [3, 1, 0, "f"]]}}, {"d": {"bloques": [[0, 1, 0, "p"], [1, 1, 0, "k"], [2, 1, 0, "i"], [3, 1, 0, "n"], [4, 1, 0, "f"]]}}]


func test_guardado() -> void:
	var run := make_run(5)
	Contratos.entrar(run, rng_con(20), 1)
	Contratos.aceptar(run, 0, false, 1)
	run.sello_oro = true
	var vuelta := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	check(Contratos.activos(vuelta).size() == 1 and Contratos.cartelera(vuelta).size() == 4 and vuelta.sello_oro, "el tablón, los activos y el Sello de oro se guardan con el run")
	check(int(Contratos.activos(vuelta)[0].n) == int(Contratos.activos(run)[0].n) and int(Contratos.activos(vuelta)[0].monto) == int(Contratos.activos(run)[0].monto), "con sus números")
	check(RunState.from_dict({}).contratos.is_empty(), "un guardado viejo no trae contratos")
	var pausa := Contratos.para_pausa(vuelta)
	check(pausa.size() == 1 and pausa[0].has("objetivo") and pausa[0].has("rareza"), "los íconos para el menú de pausa")
