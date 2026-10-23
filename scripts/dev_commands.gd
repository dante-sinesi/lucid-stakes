extends RefCounted
## Comandos del modo dev (consola con F1). SOLO existen en compilaciones de desarrollo: `available()` es falso en las
## exportaciones "release" (la que se sube a Steam), así que ahí la consola ni se crea ni se puede abrir.
##
## Comandos:
##   help                       lista de comandos
##   tower <etapa> [escenario] [semilla]   una partida nueva con una torre de esa etapa (1-15) y escenario (por defecto pesadilla), sin pagar la entrada; se usa desde el menú principal
##   goto_end  (o win)          da por ganada la torre actual (y de ahí al casino)
##   goto_casino <etapa>        te lleva directo al casino de esa etapa (1-15: taberna 1-3, salón 4-7, casino 8-11, gran casino 12-15)
##   set_luz <n>                fija la Luz del perfil en n (sirve en el menú y en el juego; no baja de 0)
##   set_claridad <n>           fija la claridad en n (para restarla, un número menor); no baja de 0
##   give <id>                  te da un boost o consumible (por ejemplo: give freno, give mente_abierta)
##   items                      lista los ids de boosts y consumibles

const Items := preload("res://scripts/items.gd")


## ¿Se puede usar el modo dev? Sólo en el editor y en compilaciones de depuración; nunca en una exportación release.
## Sólo para las pruebas: simula una compilación release (el modo dev apagado).
static var disabled_for_tests := false


static func available() -> bool:
	return OS.is_debug_build() and not disabled_for_tests


static func help_text() -> String:
	return "Comandos: help | tower <etapa> [escenario] [semilla] | goto_end (o win) | goto_casino <1-15> | set_claridad <n> | set_luz <n> | give <id> | items"


## Ejecuta una línea de la consola. `game` es el nodo principal (main.gd). Devuelve el texto a mostrar ("" si no hay).
static func execute(line: String, game) -> String:
	if not available():
		return "El modo dev no está disponible en esta compilación"
	var parts := line.strip_edges().split(" ", false)
	if parts.is_empty():
		return ""
	var cmd := parts[0].to_lower()
	match cmd:
		"help", "?":
			return help_text()
		"tower", "torre":
			if parts.size() < 2 or not parts[1].is_valid_int() or int(parts[1]) < 1 or int(parts[1]) > 15:
				return "Uso: tower <etapa 1-15> [escenario] [semilla]   (por ejemplo: tower 7 sin_piedad 1234)"
			var seed := -1
			if parts.size() > 3:
				if not parts[3].is_valid_int():
					return "La semilla tiene que ser un número"
				seed = int(parts[3])
			return game.dev_tower(int(parts[1]), parts[2] if parts.size() > 2 else "", seed)
		"goto_end", "win":
			return game.dev_goto_end()
		"goto_casino", "casino":
			if parts.size() < 2 or not parts[1].is_valid_int() or int(parts[1]) < 1 or int(parts[1]) > 15:
				return "Uso: goto_casino <etapa 1-15>   (taberna 1-3, salón 4-7, casino 8-11, gran casino 12-15)"
			return game.dev_goto_casino(int(parts[1]))
		"set_luz":
			if parts.size() < 2 or not parts[1].is_valid_int():
				return "Uso: set_luz <número>   (por ejemplo: set_luz 100)"
			return game.dev_set_luz(int(parts[1]))
		"set_claridad":
			if parts.size() < 2 or not parts[1].is_valid_int():
				return "Uso: set_claridad <número>   (por ejemplo: set_claridad 1000)"
			return game.dev_set_claridad(int(parts[1]))
		"give":
			if parts.size() < 2:
				return "Uso: give <id>   (mira los ids con: items)"
			return game.dev_give(parts[1])
		"items":
			var ids: Array[String] = []
			for it in Items.ALL:
				if it.type != Items.Type.CLARITY:
					ids.append(it.id)
			return "Ids: " + ", ".join(ids)
	return "Comando desconocido: %s (escribe help)" % cmd
