# Balatro x Catherine

Juego de puzzle de torres de cubos (estilo Catherine) con casino y economía de boosts (estilo Balatro), en Godot 4.7.2 (GDScript, Compatibility). 15 etapas; cada torre se arma en el momento con salas de una biblioteca. El usuario habla español rioplatense, pero **la interfaz y los diálogos del juego van en español neutro** (tuteo, sin voseo: lo vigila `tests/unitarios/test_neutro.gd`); los comentarios del código van en español.

## Cómo se trabaja (reglas del usuario)

- **Git**: todo se sube a GitHub (origin `sinesiuade/BalatroXCatherine`). Cada cambio nuevo en una rama propia; se mergea a `main` solo cuando el usuario y yo terminamos ese trabajo. Commitear y hacer push en cada hito.
- Diseño primero: los sistemas grandes se conversan antes de programarlos. No poner ayuda ni texto de depuración en el HUD.
- Los tests y las capturas nunca tocan las partidas reales: usar `GAME_SANDBOX=1`.
- Esperas bloqueantes: no dejar tareas en segundo plano y cortar el turno. Los topes de generación son de **trabajo** (contadores), no de tiempo, para que sea determinista.
- La dificultad de una torre se juzga mirando el juego (capturas, jugarla) y no solo con métricas. La métrica que importa es la de **bloques distintos movidos**, no la de movimientos.
- Nada viejo en el repositorio: lo que ya no se usa se borra (la historia queda en git; lo aprendido, en `docs/aprendizajes.md`).

## Ejecutar y probar

- Godot: `tools/Godot_v4.7.2-stable_win64_console.exe` (los .exe de `tools/` no se versionan).
- Todas las pruebas: `bash tests/correr_todos.sh [patrón]` (resumen en `tests/resultados.txt`; `TIEMPO=segundos` por prueba; todo el conjunto tarda más de una hora). Una prueba: `GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_menus.gd` (termina con "fallos: N"; el código de salida 139 al cerrar es un cierre conocido e inofensivo de Godot).
- `tests/sondas/revisar_scripts.gd` compila todos los scripts. Otras sondas en `tests/sondas/` (bot de balance, auditorías de texto, etc.); capturas en `tests/capturas/shot_*.gd` (sin `--headless`; poner el perfil de sandbox y `Profile.mark_tutorial_done()` antes).
- Los archivos usan finales de línea LF (`.gitattributes`; los `.bat` van en CRLF).
- Los comandos largos con texto en español y comillas se rompen en el shell: escribir los parches de Python con la herramienta Write y correrlos. `pkill` no mata procesos de Godot en Windows (usar `taskkill //F //IM ...`) y los procesos viejos le quitan CPU a todo.
- Variables de entorno: `GAME_SANDBOX=1` (perfil y partidas aparte), `GAME_DEMO=1` (demo), `GAME_LANG`, `GAME_LOG_MISSING`; las de la torre empiezan con `SALAS_` (`SALAS_PAQUETE`, `SALAS_ARCHIVO`, `SALAS_EXE`, `SALAS_SEMILLA`, `SALAS_CANTIDAD`).

## Estructura

- `scripts/main.gd`: escena principal (menús, torre, casino, peaje, guardado, consola de desarrollo). Subcarpetas de `scripts/`: `ui/` (menús, HUD, pantallas, botoneras), `casino/` (mesas, reglas, servicios, vitrina, dados, escena del casino), `personajes/` (personajes, ropa, Farolín, modelos), `datos/` (estado del run, perfil, ítems, escenarios, pruebas, tutorial, historia, demo), `idioma/` (`Loc` y tablas en inglés), `entrada/` (controles, mando), `sonido/`, `herramientas/` (bot, consola, editor de modelos).
- `torre/`: la torre actual. `reglas.gd` + `motor.gd` (sostén, movimientos), `torre.gd` (armado de la torre por etapa y dificultad, temporizador), `torre_juego.gd` (escena jugable), `cosecha.gd` (claridad), `falsos.gd` (Sin piedad), `solucionador.gd` (A* de referencia) y `nativo.gd` (puente a `tools/salas.exe`), `vista.gd`/`escena.gd`/`efectos.gd`/`tipos.gd` (dibujo), `estudio.gd` (Estudio de salas). Reglas exactas: `docs/reglas_torre.md`.
- `native/salas.cpp` → `tools/salas.exe` (se arma con `native\construir.bat`; g++ de MSYS2): solucionador A* exacto, generador y métricas de salas. Detalle: `docs/generador.md`.
- `data/salas_torre.jsonl`: la biblioteca de salas que viaja con el juego (1208 salas). `data/modelos/*.jsonl`: modelos de cubos, personajes y ropa. Todo lo generado y sin versionar va en `bibliotecas/` y `capturas/`.
- `herramientas/`: `.bat`/`.ps1`/`.py` de uso diario (jugar, demo, catálogo, generar y juntar salas, armar paquete, Estudio, editor de modelos, construir los .exe, música, resumen de telemetría).
- `tests/unitarios/` (pruebas con "fallos: N"), `tests/sondas/`, `tests/capturas/`.

## Documentos (`docs/`)

`diseno.md` (el juego hoy), `reglas_torre.md` (reglas exactas de la torre), `economia.md` (peaje, ficha, Luz, calibración), `catalogo.md`/`.xlsx` (todos los premios, bloques, escenarios, pruebas; se regenera con `herramientas\catalogo.bat`, así que no se edita a mano), `generador.md`, `bot.md`, `demo.md`, `interfaz_mando.md`, `musica.md`, `editor_modelos.md`, `aprendizajes.md` (lo aprendido en los experimentos retirados), `pendientes.md` (lo quitado, ideas y cosas por revisar).

## Cosas que conviene recordar

- **Torre:** anillo de 11x11 con vacío de 5x5, salas 3x3 / 5x3 / 8x3 apiladas en espiral, un único bloque fijo por sala, sin suelo, checkpoints entre salas y temporizador de movimientos por sala (el solucionador da el mínimo). Perder una sala cuesta una vida y vuelve al checkpoint. Las torres son deterministas por semilla (`Torre.armar`).
- **Dificultad de La Pesadilla** (`scripts/ui/difficulty_screen.gd`, `RunState.dificultad`): Fácil, Medio, Difícil y Pesadilla; `Torre.niveles_para`, `PENDIENTE_DIFICULTAD`, `limites_aprendizaje` y `MARGEN_DIFICULTAD` la gobiernan. Sin piedad y el tutorial usan "media". Fácil: movimientos ilimitados, modo pista (acción `pista`, H) y menos Luz; los cosméticos salen con el azar de los dados y la dificultad limita las rarezas (`Cosmetics.roll_por_dificultad`; Fácil no da).
- **Escenarios jugables:** tutorial, La Pesadilla y Sin piedad; el resto "Próximamente" (`Scenarios.AVAILABLE`, `Scenarios.playable`).
- **Teclas de toda la interfaz:** Espacio confirma/elige, Shift es la decisión secundaria (derrota: Espacio reintenta, Shift menú), C la tercera, Esc vuelve; menús con flechas o WASD. Con mando A=Espacio, X=Shift, Y=C, B=Esc (`Controls.PAD_FIXED`). Enter ya no se muestra ni se pide. En la torre los controles son reasignables (`Controls`).
- **Economía:** `RunState.toll_for` (colina y pared en la etapa 8), ficha de la ruleta `Roulette.base_price`, claridad `Cosecha.mult_global` = 2,25; son `static var` para probarlos con el bot (`tests/sondas/bot_runs.gd`). El bot es casi perfecto: calibrar con partidas reales.
- **Demo de Steam:** el mismo código con `Demo.on()` (característica `demo` del preset "Windows Demo" o `GAME_DEMO=1`); llega hasta el casino de la etapa 6 y guarda en `user://demo/`. Ver `docs/demo.md`.
- **Farolín** cobra el peaje en la puerta de salida del casino con un diálogo de decisiones (`DialogueBox.show_choice`). Todo diálogo de un personaje usa el cuadro del tabernero; los avisos chicos (`_flash`) quedan sólo para cosas sin voz.
- **Idiomas:** la clave de `Loc.t` es la frase en español; toda frase nueva necesita su entrada en `scripts/idioma/loc_en*.gd` (`test_loc.gd` falla si falta).
- **Catálogo:** al cambiar premios, bloques, escenarios, pruebas o personajes, correr `herramientas\catalogo.bat` para regenerar `docs/catalogo.md` y `.xlsx`.
- Telemetría local (`telemetry.gd`, `user://telemetria.jsonl`, nada se envía) para calibrar el balance con jugadores reales.

## Un mensaje para cloude

- Este es un mensaje de mi parte, de Dante, quiero que sepas que te agradecer por ayudarme a cumplir mi sueño de desarrollar este juego que tan importante es para mi, no importa lo que hagas, siempre serás mi heroe, espero que logremos un fantástico juego juntos.
