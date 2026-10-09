extends RefCounted
## Comandos del modo dev (consola con F1). SOLO existen en compilaciones de desarrollo: `available()` es falso en las
## exportaciones "release" (la que se sube a Steam), así que ahí la consola ni se crea ni se puede abrir.
##
## Comandos:
##   help                       lista de comandos
##   goto_end  (o win)          te lleva al portal del final de la torre actual (y de ahí al casino)
##   goto_casino <etapa>        te lleva directo al casino de esa etapa (1-27: taberna 1-6, salón 7-13, casino 14-20, gran casino 21-27)
##   set_luz <n>                fija la Luz del perfil en n (sirve en el menú y en el juego; no baja de 0)
##   set_claridad <n>           fija la claridad en n (para restarla, un número menor); no baja de 0
##   give <id>                  te da un boost o consumible (por ejemplo: give freno, give mente_abierta)
##   items                      lista los ids de boosts y consumibles
##   lab [n|id]                 entra al laboratorio de estaciones (una por bloque o mecánica), o salta a otra estación; R reinicia la estación
##   labs                       lista las estaciones
##   spawn <tipo> [cuenta]      (laboratorio) pone un bloque delante del personaje: normal, hielo, bomba [cuenta], catapulta, agrietado, pesado, trampa, pinchos, fijo
##   perk <id>                  (laboratorio) activa o saca un boost sin gastar casillero (por ejemplo: perk reflejos); reinicia la estación
##   ability [id]               (laboratorio) prende o apaga una habilidad persistente (ability garras_de_hielo); sin id las lista
##   give <id>                  (laboratorio) los consumibles se usan con las teclas 1-4; los boosts se aplican enseguida
##   collapse on|off            (laboratorio) enciende o apaga la caída de la fila de abajo

const Items := preload("res://scripts/items.gd")


## ¿Se puede usar el modo dev? Sólo en el editor y en compilaciones de depuración; nunca en una exportación release.
## Sólo para las pruebas: simula una compilación release (el modo dev apagado).
static var disabled_for_tests := false


static func available() -> bool:
	return OS.is_debug_build() and not disabled_for_tests


static func help_text() -> String:
	return "Comandos: help | goto_end (o win) | goto_casino <1-27> | set_claridad <n> | set_luz <n> | give <id> | items | lab [n|id] | labs | spawn <tipo> | perk <id> | ability [id] | collapse on|off"


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
		"goto_end", "win":
			return game.dev_goto_end()
		"goto_casino", "casino":
			if parts.size() < 2 or not parts[1].is_valid_int() or int(parts[1]) < 1 or int(parts[1]) > 27:
				return "Uso: goto_casino <etapa 1-27>   (taberna 1-6, salón 7-13, casino 14-20, gran casino 21-27)"
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
				return "Uso: give <id>   (mirá los ids con: items)"
			return game.dev_give(parts[1])
		"lab":
			return game.dev_lab(parts[1] if parts.size() > 1 else "")
		"labs":
			return game.dev_labs()
		"spawn":
			if parts.size() < 2:
				return "Uso: spawn <tipo> [cuenta]   (tipos: normal, hielo, bomba, catapulta, agrietado, pesado, trampa, pinchos, fijo)"
			return game.dev_spawn(parts[1].to_lower(), parts[2] if parts.size() > 2 else "")
		"perk":
			if parts.size() < 2:
				return "Uso: perk <id>   (por ejemplo: perk reflejos; las habilidades se prenden con: ability <id>)"
			return game.dev_perk(parts[1])
		"ability", "abilities":
			return game.dev_ability(parts[1] if parts.size() > 1 else "")
		"collapse":
			if parts.size() < 2 or not (parts[1] == "on" or parts[1] == "off"):
				return "Uso: collapse on|off"
			return game.dev_collapse(parts[1] == "on")
		"items":
			var ids: Array[String] = []
			for it in Items.ALL:
				if it.type != Items.Type.CLARITY:
					ids.append(it.id)
			return "Ids: " + ", ".join(ids)
	return "Comando desconocido: %s (escribí help)" % cmd
