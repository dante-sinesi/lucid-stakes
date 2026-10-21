# Progreso del cilindro (rama `experimento/cilindro`)

Bitácora de la noche del 2026-10-21 (desde la 01:50 hasta las 08:00). Las imágenes están en `capturas/progreso/` (no se versiona). Cada entrada: qué se probó, parámetros, resultados y qué se aprendió.

## Punto de partida (00:00)
- Cilindro 6x6 con pozo 2x2 vacío, anillo de piso de 1 bloque (28 celdas), sin nada debajo. La salida es un bloque fijo en el borde de arriba; todo lo demás cuelga de ella (cadena de vecinos).
- Primeros resultados (escalada de 100 s por sala, bloques comunes): pared plana 20-39 pasos y 6-10 empujes (1,2-2,0 por piso); cilindro de 1 salida 23-28 pasos y 7-11 empujes; cilindro de 4 salidas costos de 11 a 31 pasos con algunas caras sin solución. Imágenes: `00_*`, `01a_*`, `01b_*`, `01c_*`.

## 01:50 — Movimiento nuevo de Catherine: colgado, avanzar hacia bloques que tienen otro encima
- `TowerLogic._act_hanging` y su copia en `native/solver_nativo.cpp`: colgado ya se puede avanzar por el borde (tramo recto y esquina hacia adentro) hacia un bloque aunque tenga otro encima, agarrado de su costado; lo que sigue sin poderse es trepar ahí. Solucionador y generador nativos recompilados e instalados.
- Pruebas: `test_logic` (se actualizó la expectativa vieja de la esquina y se agregaron dos chequeos nuevos), `test_colgado`, `test_native`: 0 fallos.
