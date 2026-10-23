# El bot que juega el juego

Sirve para sacar estadísticas de balance (economía, boosts, curva de Farolín) sin jugar a mano. Usa las reglas reales (`TowerLogic`, `RunState`, `Roulette`, `Showcase`) sin ventanas ni animaciones.

## Piezas
- `scripts/bot.gd`: la lógica. `play_tower` sube una torre siguiendo el camino mínimo que trae el generador, con **titubeos** (ida y vuelta que gasta tiempo de la caída y corta la racha) y **muertes** al azar según su habilidad; usa los consumibles de ganancia a su hora (Poción al empezar, Baraja/Lluvia/Imán a la mitad, Reloj de arena cuando la caída está cerca). `casino` hace una visita: usa Vida extra y Soborno, compra en la tienda y juega la ruleta buscando premios de una lista de deseos (`WISHLIST`: primero los multiplicadores), rotando la vitrina hasta `max_rotations` veces, y deja apartado lo de Farolín. `pay_toll` le paga a Farolín. `run_one` juega un run entero (vidas, reintentos de la misma torre al morir o no llegar a pagar).
- `tests/bot_banco.gd`: arma el banco de torres (cada una tarda de 5 a 45 s de generar): `GAME_SANDBOX=1 STAGES=1,2,... COUNT=8 SEED0=1000 godot --headless --path . -s tests/bot_banco.gd` escribe `bibliotecas/torres/torres_<proceso>.jsonl`. Conviene correr varios procesos con etapas distintas. (`bibliotecas/` no se versiona.)
- `tests/bot_runs.gd`: juega muchos runs y muestra las estadísticas. Variables: `RUNS`, `SEED`, `SKILL` (1,0 = el jugador medio), `SPEND` (fracción de lo que sobra que se juega en el casino), `FREE` (jugadas gratis por visita: el diseño de las monedas), `ROT` (rotaciones de la vitrina), `OUT` (archivo con cada run), y los parámetros de balance: `WALL_GROWTH`, `WALL_MARGIN`, `PRE_FROM`, `PRE_TO`, `INCOME_BASE`, `INCOME_SLOPE`, `INCOME_CEIL`, `FICHA_BASE`, `FICHA_STEP`, `DIE_FIRST`, `DIE_LAST`.

## Qué muestra
Porcentaje de runs que ganan, vidas perdidas, qué porcentaje pasa cada etapa, y por etapa: ingreso medio de la torre, boosts que tiene, claridad con la que llega, precio de Farolín, intentos y qué porcentaje pasa a la primera; y los boosts más comunes al final.

## Cuidado al leer los números
- La **tasa de muerte** y los titubeos son supuestos (3 % a 20 % por torre, dividido por la habilidad): hay que calibrarlos con partidas reales.
- El bot sólo sube por el camino mínimo (no junta lo que se junta de más dando vueltas) y no juega tragamonedas ni blackjack.
- 30 runs dan ±8 puntos de ruido; para comparar dos configuraciones conviene más de 100 runs por habilidad.
- Un run tarda 12 a 17 s: se corre en varios procesos en paralelo (ver `herramientas\bot.bat` si existe, o lanzar a mano).

## Configuración de balance elegida
`Roulette.base_price` 75 y `price_step` 6; `RunState.pre_wall_from` 0,60 y `pre_wall_to` 1,00; `wall_growth` 1,20; ingreso de referencia `income_base` 340 + `income_slope` 25 por etapa. Con eso el bot gana el 3 al 7 % de los runs (ver `docs/diseno.md` §48).

## El bot con la torre nueva (por omisión)
- `Bot.arm_bank(paquete, rng, por_etapa)` arma torres nuevas por etapa (`Torre.armar`); `Bot.play_tower_nueva` juega cada sala siguiendo su camino mínimo (el motor real, `Torre.actuar`), con titubeos (2 movimientos que gastan el temporizador y cortan la racha) y una probabilidad de perder cada sala (`die_first`..`die_last` según la etapa, repartida por el peso del nivel `PESO_NIVEL`). Perder una sala cuesta una vida y vuelve a su checkpoint (`reintentar_sala`). Usa los consumibles con `Torre.usar_item`. `run_one_nueva` hace el run entero.
- `tests/bot_runs.gd`: por omisión la torre nueva. `VIEJA=1` usa el banco viejo; `TOWERS` = torres por etapa; `CLARIDAD` = multiplicador global de claridad (`Cosecha.mult_global`, sólo para balance). Al final muestra, por nivel de sala, el porcentaje perdido y los movimientos usados sobre el mínimo y sobre el máximo.
- Supuestos: la muerte por sala es un supuesto (con los valores actuales casi no se pierden salas: unas 3 cada 40 torres); calibrarla con la telemetría de partidas reales (`herramientas/resumen_telemetria.py` resume los eventos `sala` y `torre`).

## Hallazgo de balance (60 runs, habilidad 1,0, 6 torres por etapa)
Con la torre nueva el ingreso por torre ronda las **300** de claridad, contra el peaje de Farolín de 219 / 260 / 304 / 386 / 537 en las primeras etapas.

| Multiplicador de claridad | Victorias |
|---|---|
| ×1,0 | 0 % (los runs se traban en las etapas 3 a 5) |
| ×1,5 | 1,7 % |
| ×2,0 | 1,7 % |
| ×3,0 | 15 % (pasa a la primera 93–98 % hasta la etapa 5; cae en la 6 y 7) |

El objetivo de diseño era 3 a 7 %. Falta decidir cómo calibrar (valor de la claridad por bloque, curva del peaje o ingreso por etapa).
