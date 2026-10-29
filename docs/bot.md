# El bot que juega el juego

Sirve para sacar estadísticas de balance (economía, boosts, curva de Farolín) sin jugar a mano. Usa las reglas reales (`Torre`, `Motor`, `Cosecha`, `RunState`, `Roulette`, `Showcase`) sin ventanas ni animaciones.

## Piezas
- `scripts/herramientas/bot.gd`: la lógica. `arm_bank` arma torres por etapa con `Torre.armar` y el paquete de salas; `play_tower` juega cada sala siguiendo su camino mínimo con el motor real (`Torre.actuar`), con **titubeos** (movimientos que gastan el temporizador y cortan la racha) y una probabilidad de **perder cada sala** que crece con su complejidad (`die_k × (bits / 100) ^ die_exp`: una sala de 100 bits se pierde el 2,3 % de las veces y una de 190, el 8 %); perder una sala cuesta una vida y vuelve a su checkpoint. Usa los consumibles de ganancia a su hora. `casino` hace una visita: usa Vida extra y Soborno, compra en la tienda y juega la ruleta buscando premios de una lista de deseos (primero los multiplicadores), rotando la vitrina hasta `max_rotations` veces, y deja apartado lo de Farolín. `pay_toll` le paga a Farolín. `run_one` juega un run entero (vidas, reintentos).
- `tests/sondas/bot_runs.gd`: juega muchos runs y muestra las estadísticas. Variables de entorno: `RUNS` (200), `SEED`, `SKILL` (1,0 = el jugador medio), `SPEND` (fracción de lo que sobra que se juega en el casino), `FREE` (jugadas gratis por visita), `ROT` (rotaciones de la vitrina), `TOWERS` (torres armadas por etapa), `DIF` (facil, media, dificil o pesadilla: la dificultad de las torres del banco; en las difíciles armar el banco tarda más, conviene `TOWERS=6`), `MISTAKES` (falsos por sala: Sin piedad), `HES` (probabilidad de titubear), `CLARIDAD` (`Cosecha.mult_global`), y los parámetros de balance `WALL_GROWTH`, `WALL_MARGIN`, `PRE_FROM`, `PRE_TO`, `INCOME_SCALE` (escala la tabla del ingreso medido), `FICHA_BASE`, `FICHA_STEP`, `DIE_K`, `DIE_EXP`, `TOLL_MULT` (el multiplicador del peaje de la dificultad `DIF`) y `TOLL_SWEEP` (varios multiplicadores con el mismo banco de torres).
- Se corre con `GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/sondas/bot_runs.gd`. Un run tarda unos segundos; para muestras grandes conviene varios procesos en paralelo con semillas distintas.

## Qué muestra
Porcentaje de runs que ganan, vidas perdidas, qué porcentaje pasa cada etapa, y por etapa: ingreso medio de la torre, boosts, claridad con la que llega, precio de Farolín, intentos y porcentaje que pasa a la primera; los boosts más comunes al final; y por nivel de sala, el porcentaje perdido y los movimientos usados sobre el mínimo y sobre el máximo.

## Cuidado al leer los números
- El bot es un jugador casi perfecto: la **tasa de muerte** y los titubeos son supuestos (con los valores actuales casi no se pierden salas) y hay que calibrarlos con la telemetría de partidas reales (`herramientas/resumen_telemetria.py` resume los eventos `sala` y `torre`).
- Sólo sube por el camino mínimo y no juega tragamonedas ni blackjack.
- 30 runs dan ±8 puntos de ruido; para comparar dos configuraciones conviene más de 100 runs por habilidad.

## Calibración adoptada
Con ingreso de ~300 por torre contra un peaje de 219 / 260 / 304 en las primeras etapas, los runs se trababan en las etapas 3 a 5 (×1,0: 0 % de victorias; ×3,0: 15 %). Se fijó `Cosecha.mult_global` = **2,25** y `RunState.pre_wall_from` = **0,35** (el peaje de la etapa 1 baja de 219 a 128 y sube hasta la pared). Con eso el bot de habilidad media (120 runs) gana el 5 % y pasa la etapa 1 sin reintentos; el objetivo de diseño es 3 a 7 % (ver `economia.md`).
