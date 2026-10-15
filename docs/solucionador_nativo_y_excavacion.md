# Solucionador nativo y excavación (15/10)

Rama `feature/solucionador-nativo`. Objetivo: salas de verdad complejas (muchos empujes y tirones), con la dificultad medida con el camino más corto **demostrado**, y salas **sin columnas hasta el piso**.

## El problema

Las salas del minero pedían como mucho 4–6 empujes o tirones (el 95 % pedía 1 o 2). No era un tope de tiempo: el solucionador de GDScript hace unos 3 000 estados por segundo y el minero le daba entre 2 500 y 6 000 estados por sala; con ese presupuesto sólo se resuelven salas de unos 17 pasos. Una búsqueda más voraz tampoco ayudaba (`experimento_voraz.md`), y con 10 veces más tope en GDScript se ganaba poco. Hacían falta **dos cosas distintas**: un solucionador mucho más rápido y una manera de *encontrar* salas difíciles que no fuera cambiar bloques al azar.

## 1. Solucionador nativo (`native/solver_nativo.cpp`)

Un port a C++ de las reglas de `tower_logic.gd` (caminar, empujar, tirar, colgarse, hielo, agrietado, pesado, gravedad con apoyo por vecinos y aristas) y del A* de `solver.gd` (mismas cubetas de f, mismo hash de Zobrist, mismas heurísticas: de producción y admisible). Con bombas, catapultas, trampas o pinchos contesta "unsupported" y se usa GDScript.

- Compilar: `native\construir.bat` (hace falta g++, por ejemplo el de MSYS2) → `tools\solver_nativo.exe`. `herramientas\construir.ps1` lo copia a `build\herramientas`. El .exe no se versiona.
- Puente: `scripts/native_solver.gd`. `Solver.solve` lo usa solo cuando el tope de estados es de 1 000 o más (lanzar el programa cuesta decenas de milisegundos) y `opts.native` no es `false`; si no está o no entiende el estado, sigue con GDScript. Variable de entorno `SIN_NATIVO=1` lo apaga.
- **Fiel a GDScript**: `tests/test_native.gd` compara acción por acción (posición, colgado, perdió, ganó, hash de Zobrist) sobre secuencias al azar en salas con hielo, pesados y agrietados, y `tests/probe_native.gd` compara la búsqueda sobre salas de la biblioteca: mismos pasos y **exactamente los mismos estados generados** en las 150 salas comparadas (incluidas 87 salas con huecos). Para llegar a eso hubo que guardar con cada estado las banderas de "apoyado" (cambian cómo caen los bloques).
- Velocidad: 400 000 estados por segundo por núcleo (GDScript: 3 000), unas 19 veces menos tiempo en las comparaciones reales (incluye lanzar el programa). Un estado de trabajo único con deshacer en lugar de copiar la grilla, y la gravedad con semillas precalculadas (lo que sostiene un bloque fijo) ahorraron la mitad del tiempo.
- Un tope de 1,5 millones de estados (4 s) resuelve salas de hasta unos 25 pasos con la heurística admisible. Más allá, el A* con esa heurística (la subida que falta y la distancia al bloque meta) crece unas 1,6 veces por paso: el cuello de botella ahora es la heurística, no la velocidad.

## 2. Excavar

`NativeSolver.excavate` (modo `excavate` del programa). Idea (la de los "estados más lejanos" de los generadores de Rush Hour y Sokoban): en vez de cambiar bloques al azar y esperar que la sala salga difícil, se **mira todo el grafo de estados cerca de una sala**:

1. Explora a lo ancho (hasta 1–1,5 millones de estados) los estados alrededor de **todo el camino solución conocido** (un "tubo": así hasta las salas difíciles llegan a la meta dentro de lo explorado).
2. Guarda todas las aristas y calcula **hacia atrás, desde los estados ganadores**, cuántas acciones y cuántos agarres faltan desde cada estado.
3. Cada disposición de bloques alcanzable (con el jugador donde mejor le queda) es una **sala candidata**; se ordenan por agarres y pasos.

El grafo explorado sólo da una cota superior: muchas candidatas tienen atajos que el grafo no ve (en una muestra, el grafo decía 14 agarres y 37 pasos para salas cuyo mínimo real era 5 agarres y 24 pasos). Por eso cada candidata se **resuelve con el solucionador exacto** (A* admisible: camino más corto garantizado), se comprueba que no se pueda resolver caminando y recién entonces entra al archivo con `proof = exacta`. El minero lo usa con `--excavate=P` (probabilidad por paso): elige una sala del archivo con la elección de padres de siempre (favorece los casilleros con más agarres), la excava, evalúa las 20–24 mejores candidatas (más algunas al azar, porque el ranking sobrestima) y guarda las que sirven. Repetido, es una escalada: cada sala difícil es el padre de otras más difíciles.

`tests/exp_excavar.gd` (la escalada con haz de 3) y `tests/probe_excavar_h.gd` (grafo contra exacto) son los experimentos.

## 3. Salas sin columnas hasta el piso

El formato de sala guarda cada columna como un texto de abajo hacia arriba (`n`, `h`, `i`, `c`). Ahora un **hueco** (`.`) es aire entre bloques: `"n.n"` es un bloque sobre el piso, aire, y otro bloque arriba, que se sostiene de un vecino (las reglas de apoyo del juego: pegado a un bloque sostenido, o sobre la arista de uno más bajo). Cambios:

- `RoomLib.validate_structure` acepta huecos (no al final de la columna) y exige que **la sala sea estable** (`is_stable`: ningún bloque cae al empezar). `block_count`, `block_char`, `has_gaps`, `room_from_layout`.
- Hashes, canónico, distancia y descriptor ignoran los huecos. El archivo guarda el texto con el punto; las bibliotecas viejas siguen sirviendo.
- La poda ahora tiene una tercera fase: sacar **cualquier** bloque (no sólo el de arriba) si la sala sigue siendo estable, se sigue resolviendo con el mismo camino y no se puede resolver caminando.
- Estudio: cuenta bloques sin contar huecos; `delete_block(cell, y, keep_gap)` deja los de arriba donde están si se sostienen solos.
- La excavación con `--excavate-free=1` (`COLUMNS 0` en el programa nativo) no exige columnas: propone cualquier disposición que alcance el juego empujando y tirando, y esas son justamente las que tienen **aire y pocos bloques bien puestos**.

## Resultados

Antes (biblioteca de la corrida larga, ya podada): empujes y tirones por sala, 1: 545, 2: 206, 3: 87, 4: 27, 5: 6, 6: 1; máximo 7 (y sin prueba exacta en las difíciles).

Con la excavación (corridas cortas, 6–7 copias, 10–25 minutos, alturas 5–14, **todo con prueba exacta**):

| | |
|---|---|
| Salas con 6 o más agarres | cientos (antes, 1) |
| Máximo, columnas | 11 agarres (21–24 pasos) |
| Máximo, con huecos | **13 agarres en 33 pasos** (3x8 de 5 pisos con **sólo 4 bloques sueltos**, 39 % de dificultad) |
| Salas altas (9–14 pisos) con prueba exacta | hasta 7 agarres en 26 pasos (antes ninguna tenía prueba) |

La sala de 13 agarres: un pasillo de 3x8 casi vacío (3 bloques en el aire más el último apoyado en el pilar) cuya solución es un ir y venir de dos bloques "saltando" uno sobre el otro (empujar, tirar, empujar, tirar...). Es lo de Catherine: mucho aire, pocas piezas, todas necesarias.

### Corrida larga (7 copias, 60 minutos, alturas 5 a 12, salas libres, sembrada con lo anterior)

4 546 evaluaciones exactas por copia; la biblioteca resultante (`biblioteca_final`, tras volver a calcular con el desempate de menos agarres, `empaquetar --rerate=4`): **10 972 salas, 10 970 con prueba exacta**, 0 fallos en `check_library` (caminos, hashes, métricas y que ninguna se resuelva caminando).

| Agarres por sala | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Salas | 917 | 1 822 | 2 916 | 2 335 | 1 510 | 1 017 | 289 | 88 | 44 | 18 | 8 | 1 | 4 | 1 | 2 |

Bloques distintos que hay que mover: hasta 10. Dificultad (agarres sobre pasos): 10–19 %: 5 264 salas, 20–29 %: 3 725, 30–39 %: 623, 40–49 %: 58, 50–59 %: 4. La mejor: **15 agarres en 35 pasos (43 %)**, 3x8 de 5 pisos con 4 bloques sueltos en total (captura: `docs/img/sala_15_agarres.png`). De las 10 972 salas, **9 854 tienen huecos** (bloques sin columna hasta el piso). El desempate importa: al elegir entre los caminos más cortos el de menos agarres, 581 de 1 048 salas recalculadas bajaron su cantidad de agarres (en promedio unos 0,55; hasta 4), y esa es la medida conservadora que guarda la biblioteca.

Faltan las alturas 13 a 20 (la corrida se limitó a 12; las salas altas siguen con el método de solución plantada y sin prueba exacta).

## Cómo se usa

- `herramientas\excavador.bat [numero] [carpeta]`: el minero con excavación y salas libres prendidas (mismos archivos `miner_N.jsonl`; se puede seguir una biblioteca del minero copiando sus archivos). Para el programa nativo, `native\construir.bat` antes (o el `.exe` de `build\herramientas`).
- Argumentos nuevos del minero: `--excavate=P --excavate-free=1 --excavate-nodes=N --excavate-eval=N`.
- `tests/show_room.gd` (la sala en texto), `tests/shot_room.gd` (captura del Estudio con una sala), `tests/bench_native.gd`, `tests/probe_native.gd`, `tests/test_native.gd`.

## Lo que no se logró / lo que sigue

- **El techo de la prueba exacta** (~25 pasos con la heurística admisible): para salas más largas hace falta una heurística más fuerte (por ejemplo una cota del material que falta transportar) o una búsqueda en el espacio de agarres con la caminata como paso libre.
- El camino que guarda la sala es *uno* de los más cortos; la cantidad de agarres puede variar de uno a otro con el mismo largo (visto: 3 a 13 agarres en 23 pasos para salas distintas, y el desempate entre caminos del mismo largo no está definido). Conviene definir el desempate (el de menos agarres, para ser conservadores).
- Ensamblar salas en torres (el ensamblador del juego) todavía no existe; las salas libres necesitan que el ensamblador respete sus apoyos (cada bloque en el aire se sostiene de un vecino).
- Estudio: faltan herramientas para *agregar* bloques en el aire (hoy sólo se apilan encima de una columna) y ver los huecos al editar.
