# Salas altas por módulos (15/10, prototipo)

El generador de salas por búsqueda (minero y excavación) parte siempre de una escalera y la desordena, así que las salas altas salen como "escalera con un miniacertijo al principio". Esto es un generador distinto: la sala se **diseña de abajo hacia arriba, técnica por técnica**. Código: `scripts/room_modules.gd`; pruebas: `tests/test_room_modules.gd`, `tests/exp_modulos.gd` (genera y guarda en `bibliotecas/pasos/generadas.jsonl`, que se abre en el Estudio de pasos).

## La sala

- **Sin piso.** Caerse es perder. El jugador empieza parado sobre un **bloque verde fijo** y la sala termina en un **bloque rojo fijo**.
- **El núcleo 2x2** de la torre (celdas 3 y 4) sube hasta arriba. Los bloques pegados a un bloque fijo se sostienen siempre, así que todo lo demás cuelga del núcleo o de lo que ya está armado. En la 3x8, la 3x5, la L y la U la arena toca el núcleo; la **3x3 es una esquina y no lo toca**: se sostiene sólo de los bloques fijos de inicio y de fin (que representan la sala anterior y la siguiente).
- Hoy sólo se probó con la 3x8 (la ventana es la planta de 8x8 de la torre; las formas salen de `RoomLib.shape_info`).

## Cómo se arma

1. Se elige dónde está el bloque verde (pegado al núcleo si lo hay).
2. Se agrega un **módulo** por vez, hasta llegar a la altura pedida. Cada módulo es una técnica con parámetros al azar:
   - **trampolín**: una catapult a tu nivel y, más arriba, un borde al costado de la columna de lanzamiento donde el jugador queda colgado y trepa (sube de 3 a 6 pisos);
   - **pinchos**: una cornisa de bloques con pinchos adentro que no se puede cruzar por arriba: hay que colgarse del costado, avanzar por debajo y trepar del otro lado a unos escalones;
   - **hielo**: una fila de hielo que se patina de una vez hasta un bloque común, y unos escalones;
   - **transporte**: una fila con un hueco y un bloque suelto delante tuyo que hay que empujar hasta el hueco (cae y lo tapa);
   - **escalera**: unos escalones seguidos (último recurso).
3. **Cada módulo se acepta sólo si**: la sala sigue siendo estable (ningún bloque se cae), se resuelve con el solucionador exacto en el contexto de todo lo ya armado, **el bloque especial hace falta** (cambiarlo por común cambia el camino más corto) y, repitiendo el camino completo desde el inicio, se llega al final.
4. Se prueban las técnicas variando (las menos usadas primero, sin repetir la anterior, a lo sumo dos veces cada una).
5. Al final se guarda un **paso** (`StepLib`) con el núcleo en `fixed`, sin piso (todos pozos), los bloques, la entrada y la salida. Se abre en el Estudio de pasos y el solucionador exacto lo resuelve entero.

## Qué se logró y qué no

- Salen salas de 10 a 12 pisos de verdad distintas a una escalera: trampolines, cornisas de pinchos que se cruzan colgado, caminos de hielo, huecos que se tapan empujando, con el solucionador exacto demostrando el camino más corto de la sala entera (en la muestra, de 4 a 22 pasos).
- **Todavía son salas fáciles**: los módulos son chicos (el trampolín son 2 pasos). Hace falta que cada módulo pida más: pinchos con dos tramos y puntos de agarre, hielo con topes que hay que empujar, transporte de varios bloques, y combinaciones dentro de un mismo piso.
- La independencia entre pisos (lo que pasa en un piso no cambia los de arriba) vale para los empujes; los bloques que se caen (sin apoyo) sí pueden cruzar niveles. Por eso cada módulo se apoya en el núcleo o en lo ya armado, la estabilidad se verifica en cada paso y la sala entera se vuelve a resolver con el solucionador exacto (hasta unos 25 pasos).
- Falta: que las salas entren a la biblioteca (formato de sala libre con núcleo), más formas (L, U, 3x5), el módulo de arenisca y el de bombas, y que el generador tome decisiones más ricas (por ejemplo elegir las técnicas según lo que se pidió).

## Dificultad ≥ 50 % y las cinco técnicas (16/10)

**Objetivo pedido:** que la dificultad llegue al 50 % como mínimo para todos los tipos de sala, y que existan salas con trampolín, cornisa de pinchos con colgada, camino de hielo, puente de arenisca y transporte de bloques.

**Técnicas.** Las cinco están implementadas como módulos (`room_modules.gd`) y además el minero las usa (`--types`, `--focus`): trampolín, pinchos (cornisa que se cruza colgado), hielo (se patina), arenisca (puente que se rompe al bajarte; el módulo sólo vale si sin esos bloques la sala no se resuelve igual) y transporte (llevar bloques sueltos hasta un hueco o hasta el pie de un escalón alto, con varios empujes y tirones).

**Dificultad, definida como empujes y tirones sobre pasos del camino más corto** (con desempate de menos agarres), sobre la biblioteca con los especiales de adorno ya sacados (`--audit`):

| Forma | Salas ≥ 50 % | Máximo |
|---|---|---|
| 3x3 | 14 | 50 % |
| 3x5 | 14 | 52 % |
| 3x8 | 8 | 61 % |
| L | 27 | 53 % |
| U | 9 | 54 % |

72 salas en `bibliotecas/biblioteca_50.jsonl`. Con bloque especial necesario: trampolín 24, trampa 14, bomba 12, pinchos 7, arenisca 6, hielo 5. Cómo se llegó: el minero ahora elige y excava según la dificultad (`--diff-weight`; la excavación ordena sus candidatas por agarres sobre pasos), y la 3x5, que se estancaba en 46-47 %, salió de **sembrarla con las 3x3 difíciles corridas dos columnas** (`tests/exp_sembrar_3x5.gd`).

**Lo que no se logró del todo:** las técnicas que son caminar (colgarse, patinar) diluyen el porcentaje de empujes, y las salas de la biblioteca que **de verdad usan** su técnica llegan a: pinchos con colgada 43,5 %, hielo patinando 44,4 %, arenisca 47,6 %, trampa 52,6 % (sí), trampolín ≥ 50 % (sí, 24 salas). Con la definición de dificultad de técnica (empujar, tirar, colgarse, patinar y saltar con catapulta sobre pasos) las salas por módulos con las cinco técnicas pasan el 50 %: de 12 intentos salieron 5 con 51 a 71 % (la más larga: 35 pasos, 9 pisos, pinchos con colgada, escalera, arenisca, hielo y arenisca con 6 empujes).

Herramientas nuevas: `tests/probe_tecnicas.gd` (qué hace de verdad el camino), `tests/probe_mejor_tecnica.gd` (la mejor sala por técnica usada), `RoomLib.technique_counts` y `uses_technique`, `StepLib.evaluate` mide ahora `diff` y `diff_tec`, `scripts/step_excavator.gd` (excavar salas libres, sin piso ni pilar), y el solucionador nativo acepta `NOFLOOR`, `ARENA` y `KEEPSPECIALS` al excavar.
