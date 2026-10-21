# Métrica de complejidad de una sala (propuesta, para calibrar)

Objetivo: un número que diga con exactitud cuánta complejidad lleva una sala, calculado por el solucionador y no a ojo. Está en `native/salas_nuevas.cpp` (`salas_nuevas.exe --medir`) y se guarda en cada sala de la biblioteca.

## Qué se mide
Se toma UN camino más corto exacto de la sala (A*, con la cota del camino conocido: ver "Fase 2"). En cada estado de ese camino se prueban TODOS los movimientos legales y se resuelve cada hijo con el solucionador exacto:

- `legales_i`: movimientos que el motor acepta (incluye los que matan en el acto).
- `optimos_i`: los que dejan al jugador a (pasos que faltan - 1) de ganar, o sea los que siguen un camino más corto.
- `letales_i`: los que matan en el acto o dejan la sala sin solución.

## Los números
- **bits de decisión** = Σ log2(legales_i / optimos_i): la información que hay que "acertar" para seguir un camino más corto entre todos los movimientos legales. Si todos los legales fueran óptimos valdría 0.
- **bits de peligro** = Σ -log2(1 - letales_i / legales_i): lo peligroso que es moverse al azar. Crece cada vez que hay trampas a mano (un movimiento en falso que tira todo).
- **complejidad** = bits de decisión + bits de peligro (pesos 1 y 1, PROVISORIOS hasta calibrarlos con las opiniones del jugador sobre salas reales).
- Además se guardan: pasos, agarres, bloques distintos movidos, **pasos críticos** (en los que un solo movimiento sigue un camino más corto y hay otros legales) y cuántos hijos quedaron sin resolver (si hay, la métrica es aproximada).

## Por qué esta métrica
- No depende del solucionador usado: sólo de las reglas y de la sala (cuántos movimientos hay y cuántos sirven, cuántos matan).
- Una sala larga pero con un solo camino obvio (poca decisión, poco peligro) puntúa poco; una corta con muchas trampas y pocos movimientos que sirven puntúa mucho.
- Es aditiva por paso: dos tramos que se juegan seguidos suman sus bits.

## Qué falta
- Calibrar los pesos y definir bandas (fácil, media, difícil, pesadilla) con salas jugadas por el usuario (modo de jugar del Estudio).
- Una cota demostrada del mínimo para las salas altas (Fase 2, más abajo).

# Fase 2: el camino más corto REAL de las salas altas

`salas_nuevas.exe --minimo ub=N tope=M`: A* exacto con poda por la cota superior `ub` (el largo de un camino conocido: los de lonjas son válidos pero no óptimos). Si el tope de nodos alcanza, el resultado es el mínimo demostrado; si no, la salida trae `cota_inferior` (el menor f que quedaba abierto en el A*), una cota inferior DEMOSTRADA, de modo que el mínimo queda entre las dos.
- `salas_nuevas/refinar_biblioteca.gd` lo aplica a una biblioteca entera (reparte el trabajo en procesos con PARTE y PARTES) y calcula las métricas.
- Primeras pruebas: una 5x3 de 11 pisos pasó de 117 pasos (lonjas) a 103 exactos en 78 mil nodos; otra de 8 pisos de 148 a 95; una 8x3 de 78 a 76. La poda por cota superior hace que el A* llegue sin búsquedas gigantes.
