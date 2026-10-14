# Experimento: cadenas de movimientos (paso 2 de `brainstorming_generador.md`)

Script: `tests/exp_cadenas.gd` (variables N, PH, W, D, EPS, WALL, WALK_UP, SEED, SHOW; corre en segundos con `GAME_SANDBOX=1`). No toca `rooms.gd`.

## Qué se probó
Una sala vertical chica (arena de W x D, pilar de PH pisos en una esquina, llegada afuera) cuyo terreno empieza **sin decidir**. Una cadena de movimientos con nombre se ejecuta en el simulador real y cada movimiento decide, en el momento, la altura de las columnas que necesita:

- **PASO:** caminar, trepar o bajar un escalón. No se deciden escalones nuevos hacia arriba (subir se gana moviendo bloques); una columna que ya existe sí se trepa.
- **EMPUJAR:** un bloque de la pared de al lado (a la altura del jugador) pasa a la columna siguiente, que mide lo mismo que donde se está parado.
- **TRAER:** tiro de un bloque de la columna de atrás hacia los pies y avance.

La cadena se elige por una cuenta de progreso (altura del jugador y de la columna más alta pegada al pilar), con un 10 % de pasos al azar. Termina cuando el jugador está en una columna pegada al pilar a un escalón de la cima. Después se rellena lo que la cadena no tocó ("vacío" o al azar), se **repite la cadena sobre el terreno inicial** como seguro y el **solucionador completo** mide el camino más corto de verdad.

## Resultados (EPS 0,1; relleno "vacío"; con "azar" fue casi igual)

| | 4x4, pilar 4 | 5x4, pilar 5 |
|---|---|---|
| Cadenas intentadas | 20 000 (206 s) | 20 000 (254 s) |
| Llegan a la meta | 1281 (6,4 %) | 236 (1,2 %) |
| Se repiten bien sobre el terreno inicial | 1075 | 184 |
| El solucionador las resuelve (tope 20 000 estados) | 1016 | 148 |
| **Óptimo más corto que la cadena plantada (atajo)** | **904 (89 %)** | **145 (98 %)** |
| Camino más corto promedio / cadena plantada | 10,5 / 16,6 pasos | 12,0 / 20,2 pasos |
| En el camino más corto: agarres / bloques distintos (promedio) | 2,7 / 2,5 | 2,9 / 2,9 |
| Se resuelven sin tocar bloques | 57 | 10 |
| Sin atajo caminando y 4+ bloques distintos | 141 | 50 |
| ... 5+ bloques distintos | 35 | 9 |
| ... 6+ bloques distintos | 10 | 3 |
| ... 5+ agarres / 7+ agarres | 25 / 3 | 4 / 0 |

## Lectura
1. **El riesgo de los atajos se confirma, y es mayor de lo esperado.** Casi todas las cadenas tienen un camino más corto que el plantado. Pero no es "otro camino": la cadena lleva pasos de más (los pasos al azar, ir y volver). La cadena **no transporta la dificultad**: sirve para generar terrenos resolubles con transferencias de bloques; la dificultad la pone el filtro del solucionador.
2. **El filtro sale barato** (el solucionador resuelve estas salas en pocos estados), así que como generador de candidatos es mucho más eficiente que el método actual de `chica`: unas 1 sala por cada 1,5 s con 4+ bloques distintos movidos, 1 cada ~6 s con 5+, 1 cada ~20 s con 6+ (4x4). El método actual tarda 40–70 s por sala y da 4–7 agarres.
3. **El techo es bajo en arenas chicas:** 7+ agarres casi no aparecen (3 de 20 000). Para salas más exigentes hay que mejorar la construcción (la cadena tiene que ser ajustada: cada movimiento necesario) o usar arenas más grandes y varios pilares, no solo muestrear más.
4. **La tasa de éxito baja con el tamaño** (6,4 % → 1,2 %): la búsqueda por progreso no escala; hace falta una búsqueda mejor para las medianas.

## Limitaciones
Solo tres movimientos y modelo de columnas (sin colgarse, hielo ni bombas); una sola arena sin pasillo; una semilla por configuración. No se comparó contra el generador actual en la misma torre.

## Siguientes pasos posibles
- Usar este muestreo como **proveedor de candidatos** de `_vert_module` en lugar de columnas al azar y exploración (ganancia de tiempo grande en las salas de 4–5 bloques).
- Hacer la construcción "ajustada": después de plantar la cadena, probar quitar movimientos y conservar solo los necesarios; o escalar con mutaciones sobre las mejores (como los *climb* de `taller`).
- Sumar movimientos (colgarse y soltar, puente, hielo) y arenas con varios pilares para subir el techo.
