# Progreso del cilindro (rama `experimento/cilindro`)

Bitácora de la noche del 2026-10-21 (desde la 01:50 hasta las 08:00). Las imágenes están en `capturas/progreso/` (no se versiona). Cada entrada: qué se probó, parámetros, resultados y qué se aprendió.

## Punto de partida (00:00)
- Cilindro 6x6 con pozo 2x2 vacío, anillo de piso de 1 bloque (28 celdas), sin nada debajo. La salida es un bloque fijo en el borde de arriba; todo lo demás cuelga de ella (cadena de vecinos).
- Primeros resultados (escalada de 100 s por sala, bloques comunes): pared plana 20-39 pasos y 6-10 empujes (1,2-2,0 por piso); cilindro de 1 salida 23-28 pasos y 7-11 empujes; cilindro de 4 salidas costos de 11 a 31 pasos con algunas caras sin solución. Imágenes: `00_*`, `01a_*`, `01b_*`, `01c_*`.

## 01:50 — Movimiento nuevo de Catherine: colgado, avanzar hacia bloques que tienen otro encima
- `TowerLogic._act_hanging` y su copia en `native/solver_nativo.cpp`: colgado ya se puede avanzar por el borde (tramo recto y esquina hacia adentro) hacia un bloque aunque tenga otro encima, agarrado de su costado; lo que sigue sin poderse es trepar ahí. Solucionador y generador nativos recompilados e instalados.
- Pruebas: `test_logic` (se actualizó la expectativa vieja de la esquina y se agregaron dos chequeos nuevos), `test_colgado`, `test_native`: 0 fallos.

## 02:05 a 02:40 — Paredes colgantes: material, salidas y especiales (imágenes `02_*` a `05_*`)
- **Más material** (pared plana de 6 pisos, 16 vs 24 bloques, 120 s de escalada): 20-26 pasos y 6-10 empujes en los dos casos. Más bloques no suben la dificultad por sí solos (`02_*`).
- **Cantidad de salidas** (cilindro de 6 pisos, pedidas 1 a 4): el puntaje por cara es parecido (alrededor de 100 por cara) con 1, 2 o 3 salidas; con 4 siempre queda una sin alcanzar y se poda. Los costos por cara quedan parecidos (25/27, 32/31/30): más salidas no dan por sí solas rutas de dificultad distinta, hay que pedirlo en el puntaje. Evaluar cada cara multiplica el costo por la cantidad de salidas (350 a 2000 pruebas por sala según cuántas). Conclusión provisoria: dejar la cantidad de salidas variable de 1 a 3, sólo alcanzables (`03_*`).
- **Especiales, primer intento** (meterlos al azar y quedarse con los que cambian el camino sin bajar el puntaje): 0 de ~4.000 intentos se quedaron. Diagnóstico con una sala: de 22 bloques, entre 12 y 18 por tipo no cambian el camino y entre 3 y 17 dejan la sala sin solución; los pocos que lo cambian lo acortan (puntaje menor).
- **Especiales dentro de la escalada** (mover bloques conservando el tipo, cambiar un bloque a especial o a común, y un puntaje que suma 30 por cada especial que hace falta, es decir que al cambiarlo por común cambia el camino, y resta 15 por cada uno que sobra): ahora sí quedan de 1 a 4 especiales por sala y todos hacen falta (`04_*`, `05_*`). Con especiales los empujes bajan (4-7 contra 8-10): el especial sustituye trabajo (la catapulta salta pisos, el hielo desliza).
