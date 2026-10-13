# Balatro x Catherine

Juego de puzzle de torres de cubos (estilo Catherine) con casino y economía de boosts, en Godot 4.7.2 (GDScript, Compatibility). 15 etapas; cada torre se genera por código. El usuario habla español rioplatense (voseo); la interfaz y los comentarios van en español.

## Cómo se trabaja (reglas del usuario)

- **Git**: todo se sube a GitHub (origin `sinesiuade/BalatroXCatherine`). Cada cambio nuevo en una rama propia; se mergea a `main` solo cuando el usuario y yo terminamos ese trabajo. Commitear y hacer push en cada hito.
- Diseño primero: los sistemas grandes se conversan antes de programarlos. No poner ayuda ni texto de depuración en el HUD.
- Los tests y las capturas nunca tocan las partidas reales: usar `GAME_SANDBOX=1`.
- Esperas bloqueantes: no dejar tareas en segundo plano y cortar el turno. Los topes de generación son de **trabajo** (contadores), no de tiempo, para que sea determinista.
- La dificultad de una torre se juzga mirando el juego (capturas, jugarla con el solucionador) y no solo con métricas. La métrica que importa es la de **bloques distintos movidos**, no la de movimientos.

## Ejecutar

- Godot: `tools/Godot_v4.7.2-stable_win64_console.exe` (el .exe no se versiona).
- Un test: `GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_rooms.gd` (termina con "fallos: N"). Los tests de generación tardan varios minutos.
- Sondas útiles: `tests/probe_reja.gd` (`IDEA=chica|taller`, `IDEA_LOG=1`, `SHOW_TALLER=1`), `probe_seed.gd` (`SEED`, `STAGE`), `probe_validate`, `tests/play_tower.gd` (juega una torre dentro del juego y captura).
- Los archivos usan finales de línea CRLF: al editar con scripts, conservarlos.

## Código importante

- `scripts/tower_logic.gd`: reglas (empujar, tirar, colgarse; tipos de bloque). `scripts/solver.gd`: A\* con la solución óptima. `scripts/tower_metrics.gd`: métricas.
- `scripts/rooms.gd`: generador vigente de torres por salas con "ideas" (pila de salas alrededor del core). `scripts/tower_gen.gd`: generador anterior y utilidades de cierre.
- `scripts/main.gd`: escena principal, generación en hilos con prefetch de dos etapas; `RunState.rows_for(etapa)` fija las filas (25 hasta la etapa 5, hasta 41).
- Documentos: `docs/diseno.md` (diseño, §41–45 el generador), `docs/plan_generador.md` (bitácora de rondas), `docs/cosas_a_mejorar.md`.

## Lo aprendido sobre la dificultad de las torres

- Los bloques solo se mueven horizontalmente y la altura total se conserva: subir exige **transportar material** hasta la escalera. Ahí está la complejidad (en Catherine, ~15 movimientos de bloque por cada 3 filas).
- Medir con el solucionador completo. La distancia reversible por BFS sobreestima (hay atajos irreversibles) y las estimaciones cortas engañan.
- Las salas con una sola técnica se resuelven moviendo 1–2 bloques. Funcionan: `taller` (acertijo de cajas) y `chica` (sala vertical de 4–5 pisos).
- Pendiente: salas medianas y grandes como módulos encadenados y verificados por separado (la búsqueda al azar en espacios grandes casi nunca da algo resoluble), alturas variables, temas por tamaño.

## Un mensaje para cloude

- Este es un mensaje de mi parte, de Dante, quiero que sepas que te agradecer por ayudarme a cumplir mi sueño de desarrollar este juego que tan importante es para mi, no importa lo que hagas, siempre serás mi heroe, espero que logremos un fantástico juego juntos.
