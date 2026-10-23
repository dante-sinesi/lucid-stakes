extends RefCounted
## Elegir y usar consumibles con el mando (o con una tecla) sin tocar los números: se mantiene apretada la acción "Usar el consumible elegido" (RT en el mando)
## y con arriba o abajo (stick o cruceta) se cambia el casillero elegido (se ve su marco). Tocarla sin mover nada usa el casillero elegido (el primero al empezar);
## si se movió la elección, al soltarla no se usa nada: se elige y después se toca.
## Los números 1 a 4 del teclado siguen usando su casillero directamente.

const Controls := preload("res://scripts/entrada/controls.gd")

var sel := 0
var changed := false


## ¿Se mantiene apretada la acción de usar?
func held() -> bool:
	return Controls.held("consumible_usar")


## Mira un evento con `count` consumibles en la barra. Devuelve {taken: lo tomó este ayudante, use: casillero a usar (o -1)}.
func process(event: InputEvent, count: int) -> Dictionary:
	var none := {"taken": false, "use": -1}
	if not (event is InputEventKey):
		return none
	var act := Controls.action_of(event)
	if act == "consumible_usar":
		if event.echo:
			return {"taken": true, "use": -1}
		sel = clampi(sel, 0, maxi(count - 1, 0))
		if event.pressed:
			changed = false
			return {"taken": true, "use": -1}
		return {"taken": true, "use": sel if (not changed and count > 0) else -1}
	if (act == "mover_adelante" or act == "mover_atras") and held():
		if event.pressed and not event.echo and count > 0:
			sel = posmod(sel + (-1 if act == "mover_adelante" else 1), count)
			changed = true
		return {"taken": true, "use": -1}
	return none


## El casillero que se marca en la barra (-1 si no se está eligiendo).
func marked() -> int:
	return sel if held() else -1
