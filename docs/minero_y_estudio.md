# Minero y Estudio de salas

Las dos herramientas de la biblioteca de salas (ver `evaluacion_generador.md`, §13): un **minero** que se deja corriendo 24/7 y descubre salas nuevas, y un **Estudio** para mirarlas, corregirlas y anotarlas. Las dos usan el motor, las reglas y el solucionador del propio juego.

## El flujo

```
 Minero (una o varias copias)  ->  carpeta biblioteca/miner_N.jsonl  ->  Empaquetador  ->  biblioteca.jsonl / .rooms  ->  Estudio
```

1. **Minero** (`herramientas\minero.bat`, `minero_varios.bat`): genera salas y las escribe en `miner_N.jsonl` (una línea por sala; N = número de la copia).
2. **Empaquetador** (`herramientas\empaquetar.bat`): junta los `.jsonl` de todas las copias, deja el mejor registro de cada sala, revalida con las reglas actuales (repite el camino de cada una y recalcula sus hashes), descarta lo que ya no sirve y escribe un archivo. Si la salida termina en `.rooms`, va comprimida (zstd): es la que viajaría con el juego.
3. **Estudio** (`herramientas\estudio.bat [archivo]`): abre la biblioteca.

## Cómo se arma todo

- **Con el Godot de `tools\`** (no hace falta construir nada): los `.bat` usan el proyecto tal cual. En la otra PC: copiar la carpeta del proyecto y el ejecutable de Godot a `tools\`.
- **Como `.exe` propios**: `powershell -ExecutionPolicy Bypass -File herramientas\construir.ps1` arma en `build\herramientas` `Minero.exe`, `Estudio.exe` y `Empaquetador.exe` (cada uno con su `.pck` y su `.console.exe` para ver el texto). Se copia esa carpeta entera. Los `.bat` usan estos `.exe` si existen. Hacen falta las plantillas de exportación de Godot (4.7.2) en la PC donde se construye.

Los argumentos del minero (después de `--`): `--id=N --out=CARPETA --minutes=M (0 = siempre) --seed --shapes=3x3,3x5,3x8,L,U --hlo=5 --hhi=20 --keep=6 --verify=0.1 --max-evals=N`. Se detiene solo cuando aparece un archivo llamado **STOP** en la carpeta de salida. Si se corta (luz, error), el `.bat` lo vuelve a lanzar y **retoma** desde su propio `.jsonl`. El minero escribe también `stats_N.json` (informe) cada minuto y el `.bat` guarda el texto en `minero_N.log`.

## Las salas

| Forma | Arena | Entrada → salida | Alturas (pisos) |
|---|---|---|---|
| 3x3 | 3 x 3 | un extremo → la esquina opuesta | 5 a 7 |
| 3x5 | 3 x 5 | idem | 5 a 8 |
| 3x8 | 3 x 8 (un lado completo de la torre) | idem | 5 a 20 |
| L | 8 x 3 más un tramo de 2 x 3 en perpendicular | la punta del tramo corto → el otro extremo del lado largo | 5 a 20 |
| U | dos brazos de 5 x 3 unidos por un tramo de 2 x 3 (ancho total 8) | la punta de un brazo → la punta del otro | 5 a 20 |

La O no se hace (por lo que implica subir). Las arenas chicas no admiten cualquier altura: una escalera a pie hasta la salida necesita una columna distinta por cada piso y casi no queda lugar para desordenarla (3x3 llega a 7 y 3x5 a 8 en lo que se midió).

**Una sala** (`scripts/room_lib.gd`): la forma, la altura `h` (el jugador sube `h` pisos y queda parado sobre el tope de la salida), las columnas (de abajo hacia arriba: `n` común, `h` pesado, `i` hielo, `c` agrietado), el camino más corto conocido y sus métricas, y tres hashes: `id` (exacto, igual para giros y espejos), `family` (sin tipos de bloque) y `pattern` (la familia más el camino normalizado: lo que reconoce el jugador). Más el origen (`minero`, `manual`, `autor`), el estado (`nuevo`, `buena`, `mala`, `mejorable`), una nota y las variantes marcadas.

## Cómo se descubren (minero)

- **Alturas bajas (hasta 8)**: salas de partida (terrenos al azar o la escalera con bloques cambiados de lugar) que el solucionador resuelve; después **cambios chicos** (poner, sacar, mover o cambiar de tipo un bloque, cruzar dos salas). Una sala entra si se resuelve, **no se puede resolver caminando** (esa búsqueda es exacta y chica) y pide mover bloques. Cada casillero (forma, altura, bloques distintos que hay que mover, tipos especiales) guarda varias salas, no sólo la mejor.
- **Alturas altas (9 a 20)**: el solucionador no llega ni a resolver las salas de partida, así que se construyen con **la solución plantada**: se parte de la escalera resuelta, se la desordena con acciones reales del juego que se pueden deshacer y la solución es el desorden al revés (verificada repitiéndola). Sobre una sala alta se puede seguir desordenando.
- **Verificación exacta** (`verify_exact`): cada tanto el minero toma una sala sin probar y busca su camino más corto garantizado (A* con la heurística demostrable que nunca sobrestima: distancia de subida y distancia al bloque meta). `prueba`: **exacta** (es el mínimo), **cota** (se acabó el presupuesto: se guarda una cota inferior) o **sin_probar**. Las salas altas quedan como cota superior (`opt.source = "plantada"`): su dificultad real puede ser menor.

## Lo medido

- El solucionador de producción **no garantiza el mínimo** (su heurística de guía puede sobrestimar): en una sala dio 16 pasos con 12 de mínimo real. Por eso existe la verificación exacta. `tests\test_solver_exact.gd`: el modo admisible coincide con la búsqueda sin heurística en todas las salas comparadas y usa unas 19 veces menos estados.
- **Corrida de comprobación final** (3 copias del minero, 9 minutos, en esta PC, como `.exe` exportados): 1 554 líneas escritas, 1 048 salas distintas tras empaquetar (0 líneas malas, 0 inválidas), 54 de las 55 combinaciones forma-altura con salas (falta 3x8 de 20 pisos), 502 con prueba exacta. `tests\check_library.gd` sobre esa biblioteca: **0 fallos** (todas las salas se resuelven con su camino, los hashes y las métricas coinciden, ninguna de las 131 revisadas se resuelve caminando).
- **Dificultad todavía baja**: bloques distintos que hay que mover (cantidad de salas): 1: 388, 2: 442, 3: 182, 4: 35, 5: 1. Es lo esperable de 27 minutos de minería: los casilleros difíciles se llenan con tiempo (la elección de padres favorece los casilleros con más bloques movidos). Hay que dejar corriendo la PC y mirar cómo avanza `stats_N.json` (campo `max_moved_by_shape`).
- Velocidad: de 1 a 5 evaluaciones por segundo por copia según las alturas; las salas altas rinden unas 20 por minuto por copia.
- De las verificaciones exactas de salas altas, casi todas encuentran un camino más corto que el plantado (esperable: el plantado incluye el desorden y su deshacer).

## El Estudio

Izquierda: la biblioteca (filtros por forma, pisos, bloques movidos, estado, origen, prueba y búsqueda por id/familia/patrón; orden por bloques movidos, pasos, altura o recientes) y **Sala nueva**. Centro: la sala dibujada con los minibloques y el shader del juego. Derecha: datos de la sala, herramientas y salas parecidas con su miniatura.

- **Mouse**: botón izquierdo = usar la herramienta sobre el bloque; derecho (arrastrar) = girar; medio = mover; rueda = acercar. **Teclas**: Ctrl+Z, Ctrl+Y, Ctrl+S, Supr, Esc.
- **Herramientas**: Seleccionar, Agregar bloque arriba, Borrar bloque (los de arriba bajan), Cambiar tipo, Mover a otra columna.
- **Verificación continua**: después de cada cambio se vuelve a resolver la sala (se conserva el camino si todavía sirve); si ya no se resuelve, no se puede guardar. **Verificar a fondo** busca el mínimo exacto.
- **Variantes**: se selecciona un bloque y se tildan los otros tipos que puede tener; **Probar variantes** cambia el tipo, vuelve a resolver y dice cuáles sirven; **Crear variantes** guarda cada una como sala nueva (`variant_of`).
- **Parecidas**: la distancia mezcla los bloques (comparados en las 8 orientaciones) y los descriptores; muestra las 5 más cercanas con miniatura (se guardan en `thumbs\` junto a la biblioteca).
- **Camino más corto**: reproducir paso a paso, adelante y atrás.
- **Estado y nota**: buena / mala / mejorable, con una nota. **Guardar** reemplaza la original (queda `origen: manual` y `parent`); **Como nueva** agrega una; no se guardan salas repetidas ni sin solución.

## Pruebas

`tests\test_room_lib.gd`, `test_solver_exact.gd`, `test_miner.gd` (incluye ejecutar la escena del minero como proceso y el archivo STOP), `test_pack.gd`, `test_studio_model.gd`, `test_studio.gd`. Se corren con `GAME_SANDBOX=1 tools\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests\ARCHIVO.gd`.

## Pendiente

- Integrar la biblioteca en el juego (el ensamblador que elige, gira y apila salas).
- Más tipos de bloque en el minero (bombas, trampas, catapultas), más formas y las salas que bajan.
- Salas de autor (carga por texto) y modo "conservador" del minero que sólo toca lo que no es esencial.
- Mejorar el rendimiento de las salas altas (el desorden produce una sala válida de cada 15 a 30 intentos) y de la verificación exacta (portar el solucionador a C++).
