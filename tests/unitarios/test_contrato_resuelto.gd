extends SceneTree
## La pantalla del contrato resuelto (scripts/ui/contrato_resuelto.gd): la animación llega hasta el final, la primera pulsación la salta, la segunda continúa y emite `terminado`.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/unitarios/test_contrato_resuelto.gd
const Pantalla := preload("res://scripts/ui/contrato_resuelto.gd")
const Arte := preload("res://scripts/ui/contract_art.gd")

var fails := 0
var terminados := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	var p = Pantalla.new()
	root.add_child(p)
	p.terminado.connect(func(): terminados += 1)
	check(not p.visible, "empieza oculta")
	var c := {"objetivo": "racha", "rareza": Arte.Rareza.RARA, "titulo": "Racha larga", "condiciones": ["Llega a una racha de 4"]}
	p.mostrar(c, true, 120)
	check(p.visible and not p.listo, "al mostrarla se ve y todavía no está lista")
	p.ir_a(Pantalla.T_IMPACTO - 0.1)
	check(not p.listo, "antes del impacto no está lista")
	p._pulsar()
	check(p.visible and p.listo and terminados == 0, "la primera pulsación salta la animación y no continúa")
	p._pulsar()
	check(not p.visible and terminados == 1, "la segunda continúa y emite terminado")
	p._pulsar()
	check(terminados == 1, "oculta no emite otra vez")
	# fallido, con la fianza perdida, y sin recompensa
	for monto in [-80, 0]:
		p.mostrar(c, false, monto)
		p.ir_a(Pantalla.T_LISTO + 0.1)
		check(p.listo, "fallido (%d): llega a estar lista" % monto)
		p._pulsar()
	check(terminados == 3, "fallido: también emite terminado")
	# la línea de tiempo está en orden
	check(Pantalla.T_PAPEL < Pantalla.T_SELLO_ENTRA and Pantalla.T_SELLO_ENTRA < Pantalla.T_BAJA and Pantalla.T_BAJA < Pantalla.T_IMPACTO and Pantalla.T_IMPACTO < Pantalla.T_SUBE and Pantalla.T_SUBE < Pantalla.T_SALE, "la línea de tiempo está en orden")
	check(Pantalla.T_LISTO > Pantalla.T_CONTEO, "se puede continuar cuando el contador terminó")
	print("tests del contrato resuelto terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
