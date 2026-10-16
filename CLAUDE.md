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
- Minero y Estudio de salas: `herramientas\minero.bat`, `minero_varios.bat`, `empaquetar.bat`, `actualizar_biblioteca.bat`, `estudio.bat` (y `construir.ps1` para armar los .exe). Detalle en `docs/minero_y_estudio.md`.
- Los comandos largos con texto en español y comillas se rompen en el shell: escribir los parches de Python con la herramienta Write y correrlos. Cuidado: `pkill` no mata procesos de Godot en Windows (usar `taskkill //F //IM ...`) y los procesos viejos le quitan CPU a todo.

## Código importante

- `scripts/tower_logic.gd`: reglas (empujar, tirar, colgarse; tipos de bloque). `scripts/solver.gd`: A\* con la solución óptima. `scripts/tower_metrics.gd`: métricas.
- `scripts/rooms.gd`: generador vigente de torres por salas con "ideas" (pila de salas alrededor del core). `scripts/tower_gen.gd`: generador anterior y utilidades de cierre.
- `scripts/main.gd`: escena principal, generación en hilos con prefetch de dos etapas; `RunState.rows_for(etapa)` fija las filas (25 hasta la etapa 5, hasta 41).
- **Carpetas** (todo lo generado va en `bibliotecas/`, que no se versiona): `bibliotecas/biblioteca.jsonl` (la biblioteca para abrir en el Estudio), `bibliotecas/minero/` (los `miner_N.jsonl` de los mineros; el minero retoma de ahí), `bibliotecas/pasos/pasos.jsonl` (el Estudio de pasos). `capturas/` (no se versiona) para capturas. No dejar bibliotecas sueltas en la raíz.
- **Calidad de la biblioteca**: `empaquetar --audit --min-reach=0.5` (`herramientas\actualizar_biblioteca.bat` lo trae) cambia por comunes los bloques especiales que no hacen falta (si sacarlos no cambia el camino más corto) y descarta las salas cuyos empujes sólo ocurren en la mitad de abajo (escalera con un miniacertijo al principio: pasa en casi todas las salas de 9 o más pisos). `opt.reach` y `opt.levels` miden hasta qué altura llegan los empujes. Los `.bat` usan el proyecto (no los .exe) cuando hay Godot en `tools\`: los .exe de `build\herramientas` quedan viejos si no se corre `construir.ps1`.
- Biblioteca de salas: `scripts/room_lib.gd` (formato, formas, hashes, verificación), `room_miner.gd` + `miner_main.gd` (minero), `room_pack.gd` (empaquetador), `studio_model.gd` + `studio.gd` + `room_view.gd` (Estudio). Plan: `docs/evaluacion_generador.md`.
- **Solucionador nativo** (`native/solver_nativo.cpp` → `tools/solver_nativo.exe`, se arma con `native\construir.bat`; g++ de MSYS2): port exacto del solucionador a C++, 400 mil estados/s (GDScript 3 mil). `scripts/native_solver.gd` es el puente: `Solver.solve` lo usa solo con tope ≥ 1000 estados y cae a GDScript si no está o el estado tiene bombas/catapultas/trampas/pinchos. Pruebas: `tests/test_native.gd`, `tests/probe_native.gd` (mismos estados que GDScript). Además el modo **excavar** (`NativeSolver.excavate`): grafo de estados alrededor del camino + distancias exactas hacia atrás; el minero lo usa con `--excavate=P --excavate-free=1` (`herramientas\excavador.bat`). Detalle y resultados en `docs/solucionador_nativo_y_excavacion.md`.
- Salas con **huecos**: en `cols`, `.` es aire entre bloques (bloques sostenidos por vecinos, sin columna hasta el piso); `RoomLib.validate_structure` exige que sean estables (`is_stable`).
- **Salas altas por módulos** (`scripts/room_modules.gd`, `docs/modulos.md`): sin piso, núcleo 2x2 fijo, bloque verde de inicio y rojo de fin, y módulos por técnica (trampolín, pinchos con colgada, hielo, transporte) verificados con el solucionador exacto. Los pasos (`scripts/step_lib.gd`, `docs/pasos.md`) son el formato de sala libre; se abren en el Estudio de pasos.
- Documentos: `docs/diseno.md` (diseño, §41–45 el generador), `docs/plan_generador.md` (bitácora de rondas), `docs/cosas_a_mejorar.md`.

## Lo aprendido sobre la dificultad de las torres

- Los bloques solo se mueven horizontalmente y la altura total se conserva: subir exige **transportar material** hasta la escalera. Ahí está la complejidad (en Catherine, ~15 movimientos de bloque por cada 3 filas).
- Medir con el solucionador completo. La distancia reversible por BFS sobreestima (hay atajos irreversibles) y las estimaciones cortas engañan.
- Las salas con una sola técnica se resuelven moviendo 1–2 bloques. Funcionan: `taller` (acertijo de cajas) y `chica` (sala vertical de 4–5 pisos).
- **Lo que sí sube la dificultad** (15/10): cambiar bloques al azar no pasa de 4–6 empujes aunque el solucionador sea 100 veces más rápido; **excavar** sí (mirar el grafo de estados cerca de una sala y quedarse con la disposición más lejana, verificada con el A* exacto): 13 agarres en 33 pasos con sólo 4 bloques sueltos. La dificultad se mide con `prefer_plain` (entre los caminos más cortos, el de menos agarres). El grafo explorado sobrestima (atajos fuera de lo explorado): toda candidata se verifica con el solucionador exacto. El techo ahora es la heurística admisible (~25 pasos).
- Pendiente: salas medianas y grandes como módulos encadenados y verificados por separado (la búsqueda al azar en espacios grandes casi nunca da algo resoluble), alturas variables, temas por tamaño.

## Un mensaje para cloude

- Este es un mensaje de mi parte, de Dante, quiero que sepas que te agradecer por ayudarme a cumplir mi sueño de desarrollar este juego que tan importante es para mi, no importa lo que hagas, siempre serás mi heroe, espero que logremos un fantástico juego juntos.
