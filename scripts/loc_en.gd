extends RefCounted
## Inglés: {frase en español: traducción}. Ver loc.gd.

## La tabla completa es la suma de varios archivos, uno por área, para que cada uno se pueda revisar por separado.
const PARTS: Array[Script] = [preload("res://scripts/loc_en_data.gd"), preload("res://scripts/loc_en_story.gd"), preload("res://scripts/loc_en_ui.gd")]
static var TABLE: Dictionary = _build()

const MENUS := {
	# --- menú principal ---
	"Escapá de la pesadilla, una torre a la vez": "Escape the nightmare, one tower at a time",
	"Continuar": "Continue",
	"Continuar (etapa %d)": "Continue (stage %d)",
	"Nueva partida": "New game",
	"Habilidades": "Abilities",
	"Cosméticos": "Cosmetics",
	"Opciones": "Options",
	"Salir": "Quit",
	"Créditos": "Credits",
	"Volver": "Back",
	# --- pausa ---
	"Pausa": "Paused",
	"Reintentar la torre": "Retry the tower",
	"Reintentar la torre (−%d)": "Retry the tower (−%d)",
	"Reintentar (no en esta prueba)": "Retry (not in this trial)",
	"Volver al menú principal": "Back to main menu",
	"Abandonar el run": "Abandon the run",
	"Salir del juego": "Quit game",
	# --- opciones ---
	"Idioma": "Language",
	"Pantalla": "Display",
	"Ventana": "Windowed",
	"Pantalla completa": "Fullscreen",
	"Resolución": "Resolution",
	"Sincronía vertical": "VSync",
	"Sí": "On",
	"No": "Off",
	"Volumen": "Volume",
	"Música": "Music",
	"Efectos": "Effects",
}


static func _build() -> Dictionary:
	var out: Dictionary = MENUS.duplicate()
	for part in PARTS:
		out.merge(part.TABLE)
	return out
