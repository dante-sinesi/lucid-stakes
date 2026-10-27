extends RefCounted
## Poses y movimientos del gatito travieso (`gatito_travieso.gd`). Una pose es un diccionario {parte: {pos, rot (grados), esc}}; las que no se nombran quedan en reposo. `aplicar` la pone de golpe
## y `mezclar` va de una a otra (para los cambios suaves). Las poses de ESPERA (junto a Farolín, en el checkpoint) salen de las fotos de Ama: `sentada` (atenta, de reojo), `esfinge` (el "pan de carne"
## con las patitas metidas), `estirada` (con las patas delanteras estiradas, dormitando) y `bollito` (hecha un ovillo, durmiendo al sol con una patita estirada).
## Los movimientos (`trotar`, `saltar`, `empujar`, `esperar`) se llaman cada cuadro con una fase y suman al reposo.
## Giros (x): un ángulo POSITIVO manda hacia atrás lo que cuelga hacia abajo, uno NEGATIVO lo manda hacia adelante.

const PARTES := ["cuerpo", "cabeza", "pata_di", "pata_dd", "pata_ti", "pata_td", "cola_1", "cola_2", "oreja_i", "oreja_d"]

const REPOSO := {
	"cuerpo": {"pos": Vector3(0, 0.24, -0.02), "rot": Vector3.ZERO, "esc": Vector3.ONE},
	"cabeza": {"pos": Vector3(0, 0.355, 0.235), "rot": Vector3.ZERO, "esc": Vector3.ONE},
	"pata_di": {"pos": Vector3(-0.07, 0.15, 0.15), "rot": Vector3.ZERO, "esc": Vector3.ONE},
	"pata_dd": {"pos": Vector3(0.07, 0.15, 0.15), "rot": Vector3.ZERO, "esc": Vector3.ONE},
	"pata_ti": {"pos": Vector3(-0.07, 0.15, -0.17), "rot": Vector3.ZERO, "esc": Vector3.ONE},
	"pata_td": {"pos": Vector3(0.07, 0.15, -0.17), "rot": Vector3.ZERO, "esc": Vector3.ONE},
	"cola_1": {"pos": Vector3(0, 0.28, -0.26), "rot": Vector3.ZERO, "esc": Vector3.ONE},
	"cola_2": {"pos": Vector3(0, 0, -0.18), "rot": Vector3.ZERO, "esc": Vector3.ONE},
	"oreja_i": {"pos": Vector3(-0.085, 0.1, 0.03), "rot": Vector3.ZERO, "esc": Vector3.ONE},
	"oreja_d": {"pos": Vector3(0.085, 0.1, 0.03), "rot": Vector3.ZERO, "esc": Vector3.ONE},
}

## Las poses de espera, de la más despierta a la más dormida.
const ESPERAS := ["sentada", "esfinge", "estirada", "bollito"]

## Cada pose: sólo lo que cambia del reposo ("ojos": cuánto abiertos, de 0 cerrados a 1 muy abiertos).
const POSES := {
	"reposo": {},
	# sentada y atenta: el torso inclinado hacia arriba, las ancas en el piso, la cabeza girada hacia un costado y los ojos a medio cerrar (la foto del retrato)
	"sentada": {
		"cuerpo": {"pos": Vector3(0, 0.2, -0.1), "rot": Vector3(-38, 0, 0)},
		"cabeza": {"pos": Vector3(0.02, 0.46, 0.07), "rot": Vector3(8, 28, 0)},
		"pata_di": {"pos": Vector3(-0.07, 0.25, 0.06), "esc": Vector3(1, 1.55, 1)},
		"pata_dd": {"pos": Vector3(0.07, 0.25, 0.06), "esc": Vector3(1, 1.55, 1)},
		"pata_ti": {"pos": Vector3(-0.1, 0.07, -0.15), "rot": Vector3(-82, 0, 0), "esc": Vector3(1, 0.85, 1)},
		"pata_td": {"pos": Vector3(0.1, 0.07, -0.15), "rot": Vector3(-82, 0, 0), "esc": Vector3(1, 0.85, 1)},
		"cola_1": {"pos": Vector3(0.0, 0.08, -0.3), "rot": Vector3(25, -30, 0)},
		"cola_2": {"rot": Vector3(-65, 0, 0)},
		"ojos": 0.62,
	},
	# esfinge ("pan de carne"): echada, las patas delanteras metidas hacia adelante y las traseras escondidas, atenta
	"esfinge": {
		"cuerpo": {"pos": Vector3(0, 0.125, -0.03)},
		"cabeza": {"pos": Vector3(0, 0.27, 0.23), "rot": Vector3(4, -12, 0)},
		"pata_di": {"pos": Vector3(-0.07, 0.075, 0.1), "rot": Vector3(-90, 0, 0), "esc": Vector3(1, 0.85, 1)},
		"pata_dd": {"pos": Vector3(0.07, 0.075, 0.1), "rot": Vector3(-90, 0, 0), "esc": Vector3(1, 0.85, 1)},
		"pata_ti": {"pos": Vector3(-0.09, 0.05, -0.17), "esc": Vector3(1, 0.35, 1)},
		"pata_td": {"pos": Vector3(0.09, 0.05, -0.17), "esc": Vector3(1, 0.35, 1)},
		"cola_1": {"pos": Vector3(0, 0.14, -0.27), "rot": Vector3(0, 20, 0)},
		"cola_2": {"rot": Vector3(-90, 0, 0)},
		"ojos": 0.8,
	},
	# estirada: las patas delanteras estiradas hacia adelante, la cabeza baja y los ojos cerrados (dormitando)
	"estirada": {
		"cuerpo": {"pos": Vector3(0, 0.115, -0.03)},
		"cabeza": {"pos": Vector3(0, 0.215, 0.27), "rot": Vector3(14, 10, 4)},
		"pata_di": {"pos": Vector3(-0.065, 0.065, 0.12), "rot": Vector3(-92, 0, 0), "esc": Vector3(1, 1.25, 1)},
		"pata_dd": {"pos": Vector3(0.065, 0.065, 0.12), "rot": Vector3(-92, 0, 0), "esc": Vector3(1, 1.25, 1)},
		"pata_ti": {"pos": Vector3(-0.09, 0.05, -0.17), "esc": Vector3(1, 0.35, 1)},
		"pata_td": {"pos": Vector3(0.09, 0.05, -0.17), "esc": Vector3(1, 0.35, 1)},
		"cola_1": {"pos": Vector3(0, 0.12, -0.27), "rot": Vector3(0, -35, 0)},
		"cola_2": {"rot": Vector3(-90, 0, 0)},
		"oreja_i": {"rot": Vector3(0, 0, 18)},
		"oreja_d": {"rot": Vector3(0, 0, -18)},
		"ojos": 0.12,
	},
	# bollito: hecha un ovillo, durmiendo, con una patita delantera estirada y la cola alrededor
	"bollito": {
		"cuerpo": {"pos": Vector3(0, 0.135, -0.02), "esc": Vector3(1.05, 0.85, 0.82)},
		"cabeza": {"pos": Vector3(-0.05, 0.235, 0.2), "rot": Vector3(18, -28, -8)},
		"pata_di": {"pos": Vector3(-0.07, 0.075, 0.1), "rot": Vector3(-92, 8, 0), "esc": Vector3(1, 1.2, 1)},
		"pata_dd": {"pos": Vector3(0.07, 0.07, 0.12), "esc": Vector3(1, 0.4, 1)},
		"pata_ti": {"pos": Vector3(-0.09, 0.06, -0.12), "esc": Vector3(1, 0.4, 1)},
		"pata_td": {"pos": Vector3(0.09, 0.06, -0.12), "esc": Vector3(1, 0.4, 1)},
		"cola_1": {"pos": Vector3(0.08, 0.13, -0.2), "rot": Vector3(0, -80, 0)},
		"cola_2": {"rot": Vector3(-90, -35, 0)},
		"oreja_i": {"rot": Vector3(0, 0, 20)},
		"oreja_d": {"rot": Vector3(0, 0, -14)},
		"ojos": 0.1,
	},
}


## La pose `nombre` completa (reposo más lo que cambia): {parte: {pos, rot, esc}, "ojos": n}.
static func pose(nombre: String) -> Dictionary:
	var cambios: Dictionary = POSES.get(nombre, {})
	var out := {}
	for p in PARTES:
		var base: Dictionary = REPOSO[p]
		var c: Dictionary = cambios.get(p, {})
		out[p] = {"pos": c.get("pos", base.pos), "rot": c.get("rot", base.rot), "esc": c.get("esc", base.esc)}
	out["ojos"] = float(cambios.get("ojos", 1.0))
	return out


## Pone la pose de golpe.
static func aplicar(modelo: Node3D, p: Dictionary) -> void:
	for nombre in PARTES:
		var n := modelo.get_node_or_null(NodePath(_ruta(nombre))) as Node3D
		if n == null:
			continue
		var v: Dictionary = p[nombre]
		n.position = v.pos
		n.rotation_degrees = v.rot
		n.scale = v.esc
	ojos(modelo, float(p.get("ojos", 1.0)))


## Una pose entre la `a` y la `b` (k de 0 a 1).
static func mezclar(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	for nombre in PARTES:
		var va: Dictionary = a[nombre]
		var vb: Dictionary = b[nombre]
		out[nombre] = {"pos": (va.pos as Vector3).lerp(vb.pos, k), "rot": (va.rot as Vector3).lerp(vb.rot, k), "esc": (va.esc as Vector3).lerp(vb.esc, k)}
	out["ojos"] = lerpf(float(a.get("ojos", 1.0)), float(b.get("ojos", 1.0)), k)
	return out


## Los ojos: 1 = como siempre (a medio cerrar, pícaros), más de 1 = bien abiertos, cerca de 0 = cerrados (una rayita).
static func ojos(modelo: Node3D, abiertos: float) -> void:
	for nombre in ["ojo_i", "ojo_d"]:
		var o := modelo.find_child(nombre, true, false) as Node3D
		if o != null:
			o.scale = Vector3(1.0, clampf(abiertos, 0.1, 1.5), 1.0)


static func _ruta(nombre: String) -> String:
	if nombre == "cola_2":
		return "cola_1/cola_2"
	if nombre.begins_with("oreja"):
		return "cabeza/" + nombre
	return nombre


# --- movimientos (se llaman cada cuadro; `t` es la fase) ----------------------------------------------------------------------------------

## Trotar: las patas en diagonal, el cuerpo rebota un poco, la cola en alto se balancea y el cascabel suena. `t` en radianes (un paso = TAU).
static func trotar(modelo: Node3D, t: float) -> void:
	var p := pose("reposo")
	var s := sin(t)
	var oscilar := 38.0
	p["pata_di"].rot = Vector3(oscilar * s, 0, 0)
	p["pata_td"].rot = Vector3(oscilar * s, 0, 0)
	p["pata_dd"].rot = Vector3(-oscilar * s, 0, 0)
	p["pata_ti"].rot = Vector3(-oscilar * s, 0, 0)
	p["cuerpo"].pos = Vector3(0, 0.24 + absf(s) * 0.014, -0.02)
	p["cola_1"].rot = Vector3(-18, sin(t * 0.5) * 14.0, 0)
	p["cola_2"].rot = Vector3(-24 + sin(t) * 10.0, 0, 0)
	p["cabeza"].rot = Vector3(sin(t * 2.0) * 3.0, 0, 0)
	aplicar(modelo, p)


## Saltar: en el aire estira las patas (las de adelante hacia adelante y las de atrás hacia atrás) y se inclina; `k` de 0 a 1 es todo el salto.
static func saltar(modelo: Node3D, k: float) -> void:
	var p := pose("reposo")
	var a := sin(clampf(k, 0.0, 1.0) * PI)
	p["pata_di"].rot = Vector3(-55.0 * a, 0, 0)
	p["pata_dd"].rot = Vector3(-55.0 * a, 0, 0)
	p["pata_ti"].rot = Vector3(60.0 * a, 0, 0)
	p["pata_td"].rot = Vector3(60.0 * a, 0, 0)
	p["cuerpo"].rot = Vector3(-14.0 * a, 0, 0)
	p["cuerpo"].pos = Vector3(0, 0.24 - 0.05 * (1.0 - a) * (1.0 if k < 0.15 or k > 0.85 else 0.0), -0.02)
	p["cola_1"].rot = Vector3(-10.0 * a, 0, 0)
	p["cola_2"].rot = Vector3(-30.0 * a, 0, 0)
	p["oreja_i"].rot = Vector3(0, 0, 25.0 * a)
	p["oreja_d"].rot = Vector3(0, 0, -25.0 * a)
	aplicar(modelo, p)


## Empujar un bloque: mira al jugador de reojo y da golpecitos con la patita derecha; `k` de 0 a 1 son tres golpecitos. `mira` es hacia dónde gira la cabeza (grados).
static func empujar(modelo: Node3D, k: float, mira := 25.0) -> void:
	var p := pose("reposo")
	var golpe := maxf(0.0, sin(k * TAU * 1.5))
	p["pata_dd"].rot = Vector3(-70.0 * golpe, 0, 0)
	p["pata_dd"].pos = Vector3(0.07, 0.15, 0.15 + 0.02 * golpe)
	p["cuerpo"].rot = Vector3(6.0 * golpe, 0, 0)
	p["cabeza"].rot = Vector3(4, mira, 0)
	p["cola_1"].rot = Vector3(-12, sin(k * TAU * 3.0) * 25.0, 0)
	p["oreja_i"].rot = Vector3(0, 0, -10)
	p["oreja_d"].rot = Vector3(0, 0, 10)
	aplicar(modelo, p)


## Esperar en una pose (una de `ESPERAS`): la cola se balancea despacio, las orejas se mueven de vez en cuando y parpadea (más lento cuanto más dormida). `t` en segundos.
static func esperar(modelo: Node3D, nombre: String, t: float) -> void:
	var p := pose(nombre)
	var dormida := nombre == "estirada" or nombre == "bollito"
	var vel := 0.8 if dormida else 1.6
	var cola: Dictionary = p["cola_1"]
	cola.rot = (cola.rot as Vector3) + Vector3(0, sin(t * vel) * (6.0 if dormida else 16.0), 0)
	if not dormida:
		var twitch := maxf(0.0, sin(t * 0.9 + 1.0)) ** 14.0   # una orejita que se mueve de golpe
		(p["oreja_i"] as Dictionary).rot = Vector3(0, 0, -22.0 * twitch)
		var parpadeo := 1.0 - maxf(0.0, sin(t * 0.6)) ** 40.0
		p["ojos"] = float(p["ojos"]) * parpadeo + 0.1 * (1.0 - parpadeo)
	aplicar(modelo, p)
