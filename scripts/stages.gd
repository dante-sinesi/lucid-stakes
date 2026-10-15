extends RefCounted
## Las etapas del juego: un run dura FINAL etapas (15) en todos los escenarios. Acá está lo que depende de cuántas son: la dificultad, el nivel de la sala del
## casino (taberna, salón, casino y gran casino) y las pruebas (cada 3 etapas).

const FINAL := 15
const TIER_LAST := [3, 7, 11]   # última etapa de la taberna, del salón y del casino (el gran casino va hasta FINAL)


## 0 en la primera etapa, 1 en la última: la dificultad y el tono (luz, colores) de la etapa.
static func ratio(stage: int) -> float:
	return clampf(float(stage - 1) / float(FINAL - 1), 0.0, 1.0)


## Nivel de la sala (0 taberna, 1 salón, 2 casino, 3 gran casino) según la etapa.
static func tier_of(stage: int) -> int:
	for i in TIER_LAST.size():
		if stage <= TIER_LAST[i]:
			return i
	return TIER_LAST.size()
