# Lucid Stakes — resumen del proyecto (para brainstorming)

> Contexto para otro asistente de IA. Estado a noviembre de 2026. El autor habla español rioplatense; **la interfaz y los diálogos del juego están en español neutro** (tuteo, sin voseo) y hay traducción al inglés. Los comentarios del código van en español. La carpeta local se llama "Balatro x Catherine" (de ahí salieron las inspiraciones: el casino con boosts de *Balatro* y los puzzles de torres de bloques de *Catherine*); el juego se llama **Lucid Stakes** y el repositorio es `sinesiuade/LucidStakes`.

## 1. Nombre y propósito

**Lucid Stakes** es un juego de **puzzle de torres de cubos con casino y economía de boosts**, para un jugador, en 3D isométrico con estética de cubitos (voxels) y una interfaz hecha con una fuente de cubitos propia.

- **Premisa:** el jugador está en una pesadilla hecha de recuerdos corruptos y la "claridad" (la moneda) es lo que todavía no se corrompió. Sube torres, y entre torre y torre pasa por un casino y le paga un peaje en claridad a Farolín (un farol que cuida la salida).
- **Bucle:** 15 etapas. Cada etapa = **torre** (puzzle) → **casino** (gastar/ganar claridad en ruleta, tragamonedas, blackjack, dados, tienda, contratos, taller) → **peaje de Farolín** para pasar a la siguiente. Se gana al escapar de la torre 15; se pierde al quedarse sin vidas.
- **Objetivo de diseño:** que el puzzle sea la parte central (resolver cada sala moviendo bloques) y que la economía del casino dé decisiones (boosts y consumibles que cambian cómo se juega y cuánta claridad se junta), sin que la suerte reemplace a la habilidad. La dificultad se juzga jugando, no solo con métricas.
- **Estado comercial:** hay una **demo** (llega hasta el casino de la etapa 6) pensada para Steam; el lanzamiento en Steam está bloqueado hasta tener la página.

## 2. Stack tecnológico

| Capa | Tecnología |
|---|---|
| Motor | **Godot 4.7.2**, **GDScript**, renderer **GL Compatibility**, canvas 1280x720 (`stretch=canvas_items`) |
| Solucionador nativo | **C++** (`native/salas.cpp` → `tools/salas.exe`, g++ de MSYS2): A* exacto, generador y métricas de salas. También como **GDExtension** (`native/extension/`, godot-cpp, `extension/solver.gdextension`) que usa el juego en vivo y viaja en la exportación |
| Herramientas | **Python** (generador de salas, fusión de bibliotecas, variantes de la gata, catálogo xlsx, generación de la fuente web con fontTools), `.bat`/`.ps1` para armar y exportar |
| Datos | **JSONL** (`data/salas_torre.jsonl` biblioteca de salas, `variantes_gato.jsonl`, `data/modelos/*.jsonl` de personajes y ropa); guardado, perfil y opciones en JSON propio |
| Plataforma | Exportación a **Windows** (presets "Windows Desktop" y "Windows Demo"); sin firma de código |
| Pruebas | Scripts GDScript headless (74 pruebas unitarias que terminan con `fallos: N`), sondas, capturas con ventana |
| Control de versiones | Git, rama por cambio, merge a `main` solo cuando el autor lo aprueba |

No hay servidor ni red: la telemetría es local (`user://telemetria.jsonl`, nada se envía).

## 3. Estructura del proyecto

```
CLAUDE.md             reglas de trabajo y datos clave (léelo primero)
project.godot         config del motor; main scene = scenes/main.tscn
scenes/               escena principal
scripts/
  main.gd             ESCENA PRINCIPAL: menús, torre, casino, peaje, tutorial, guardado, consola de desarrollo
  ui/ (55)            menús, HUD, pantallas, diálogo del tabernero, ayudas, botoneras, fuente de cubitos (voxel_font.gd, voxel_label.gd, voxel_draw.gd)
  casino/ (22)        sala del casino, ruleta, tragamonedas, blackjack, dados, vitrina/tienda, servicios, eventos
  datos/ (17)         RunState (estado del run), Profile (progreso), ítems, escenarios, pruebas, habilidades, tutorial, historia, demo, ajustes, telemetría, guardado atómico
  personajes/ (11)    personajes, ropa, Farolín, modelos y arte de bloques
  idioma/ (10)        Loc + tablas en inglés (la clave de Loc.t es la frase en español)
  entrada/, sonido/, herramientas/   controles y mando, audio, bot de balance y consola
torre/ (19)           MOTOR del puzzle: reglas.gd + motor.gd (sostén, movimientos), torre.gd (armado de la torre), torre_juego.gd (escena jugable), cosecha.gd (claridad), solucionador.gd (A* de referencia), nativo.gd (puente al C++), vista/escena/efectos (dibujo), estudio.gd (editor de salas)
native/, extension/   solucionador en C++ y su GDExtension
data/                 biblioteca de salas (11505), variantes de la gata (32087), modelos
shaders/              fondo, portal, bloques de cristal/hielo, silueta, filtro de daltonismo
audio/                música y efectos
herramientas/         scripts de uso diario (jugar, demo, catálogo, generar/juntar salas, construir, editor de modelos, fuente web)
tests/                unitarios/ (74), sondas/ (18), capturas/ (66 scripts que sacan imágenes)
docs/ (23)            diseno.md (el juego hoy), reglas_torre.md, economia.md, catalogo.md/.xlsx (generado), generador.md, demo.md, pruebas.md, plan_casinos.md, pendientes.md…
web_fuente/           la fuente de cubitos exportada como fuente web (ttf/woff2, 3 pesos x cursiva)
build/, bibliotecas/, capturas/   salidas generadas (no versionadas)
```

## 4. Arquitectura y lógica central

**La torre (el puzzle).** Es un anillo de 11x11 con un vacío de 5x5 en el centro. Cada torre se **arma en el momento** con salas de una biblioteca (3x3 / 5x3 / 8x3 de base) apiladas en espiral. Cada sala tiene un único bloque fijo (el de salida), checkpoints entre salas, sin suelo, y un **temporizador de movimientos por sala** calculado con el solucionador (el mínimo de movimientos más un margen según la dificultad). El personaje camina, **empuja, tira, se cuelga de cornisas y se suelta**; hay bloques especiales (pesado, hielo, agrietado, trampa, pinchos, catapulta, bomba). Perder una sala cuesta una vida y vuelve al checkpoint. Las torres son **deterministas por semilla** (`Torre.armar`). La métrica de dificultad que importa es la cantidad de **bloques distintos movidos**, no de movimientos.

**Biblioteca de salas.** 11505 salas generadas offline por un generador (C++/Python) que verifica cada una con el solucionador exacto y la clasifica por dificultad. Un filtro en tiempo de armado descarta salas demasiado simples según la dificultad; hay una variante "gata" por sala para la prueba Travesuras.

**Economía.** La claridad se junta al purificar bloques (con multiplicadores, rachas y boosts), se gasta en el casino y se paga como peaje a Farolín. Piezas clave: peaje por etapa (curva con colina y pared en la etapa 8, multiplicado por 1,3 y por la dificultad), precio de la ficha de la ruleta (`Roulette.base_price` = 50 + 4 por etapa), precios de tienda por múltiplos de la ficha, interés con tope. Un **bot** (`scripts/herramientas/bot.gd`, `tests/sondas/bot_runs.gd`) juega runs completos para calibrar números; es casi perfecto, así que **la calibración final necesita partidas reales**.

**Contenido (números del catálogo generado).** 37 boosts, 21 consumibles, 15 pruebas (reglas especiales cada 3 etapas: Sin ayudas, Todo o nada, Sin racha, Travesuras, Mareo, Terremoto, A oscuras…, y el jefe final), 5 personajes, 13 cosméticos (salen de los dados), 10 habilidades persistentes (se ganan por escenario), 8 escenarios jugables más el tutorial (La Pesadilla y siete que cambian reglas: El camino corto, Compromiso, Gran Casino, Relojería, Contratista, Mundo abierto, Usurero). Cuatro dificultades: Fácil (movimientos ilimitados, modo pista, menos Luz), Medio, Difícil, Pesadilla. La **Luz** es una moneda de meta-progreso entre partidas.

**El casino.** Cuatro niveles visuales (taberna, salón, casino, gran casino) hechos enteros de cubitos finos. Estaciones: ruleta de premios (todas las casillas dan premio), tragamonedas con retener, blackjack, dados del tabernero, tablón de contratos, Taller (vender/cambiar), tienda (se abre hablando con el tabernero) y Farolín en la puerta (diálogo con decisiones). Eventos aleatorios (casino torcido, peaje por adelantado).

**Flujo de datos.** `main.gd` orquesta: crea un `RunState` (claridad, vidas, boosts, consumibles, etapa, dificultad, escenario), arma la torre con `Torre.armar`, la juega con `TorreJuego` (que usa `Motor` y `Reglas`), al ganar entra en `CasinoScene`, que lee/escribe el `RunState`, y después viene el peaje. `Profile` guarda lo persistente (Luz, habilidades, personajes, logros); `SaveGame` guarda el run en cada checkpoint y tras cada movimiento (archivos atómicos con copia `.bak`). `Settings` guarda opciones y ajustes gráficos (el primer arranque elige la calidad según la tarjeta de video). `Loc` traduce.

**Convenciones importantes.**
- Texto de interfaz: español neutro (lo vigila `tests/unitarios/test_neutro.gd`); toda frase nueva necesita su entrada en `scripts/idioma/loc_en*.gd` (`test_loc.gd` falla si falta).
- No hay carteles de texto flotantes: se usan diálogos del tabernero, señales sin palabras, el ítem que vuela o ventanas de resumen.
- La ayuda de teclas y los botones del mando comparten un diseño único; Espacio confirma, Shift es la decisión secundaria, Esc vuelve.
- Tests y capturas siempre con `GAME_SANDBOX=1` (perfil y partidas aparte). `GAME_DEMO=1` prende la demo.

## 5. Estado actual y puntos clave

**Funciona y está probado (74/74 pruebas verdes sobre `main`).** Juego completo de punta a punta (15 etapas), 9 escenarios, 4 dificultades, 15 pruebas, casino con todas las estaciones, tutorial rehecho (se aprende a caminar en la taberna; lecciones de cámara, empujar, tirar, colgarse, soltarse y una torre real), guardado atómico y a mitad de sala, demo con guardado aparte, daltonismo (filtro de pantalla que lleva los verdes al azul + símbolos), ajustes gráficos automáticos, mando (Xbox/PlayStation), inglés y español. La fuente de cubitos existe también como fuente web (`web_fuente/`). Los builds de Windows (juego y demo) están recompilados.

**Dependencias críticas.**
- `tools/Godot_v4.7.2-stable_win64_console.exe` y `tools/salas.exe` no se versionan (los .exe de `tools/`).
- El solucionador nativo (DLL de la extensión, `libsolver.windows.template_release…`) es necesario para armar torres y medir movimientos; se construye con `native\construir_extension.bat` (g++ de MSYS2, SCons).
- Python con fontTools/brotli/skia-pathops solo para la fuente web; las plantillas de exportación de Godot 4.7.2 para generar los builds.

**Limitaciones y pendientes conocidos.**
- **Balance sin calibrar con jugadores reales:** el bot es casi perfecto; la economía y los márgenes de movimientos necesitan telemetría de testers. Ya hubo una ronda de testers (plan en `capturas/`, no versionado).
- **Sin probar en una máquina limpia** (hace falta que lo hagan terceros) ni en hardware distinto del del autor.
- **Terremoto** (una prueba) mueve menos bloques desde que la biblioteca creció (más salas con pocos bloques de sobra): en muchas salas no mueve ninguno.
- **Steam:** bloqueado (AppID, Steamworks/logros, depots, política de privacidad, cuestionario de edad —hay un casino simulado—, tráiler). Sin firma de código: SmartScreen avisará al abrir el exe.
- **Solo Windows** (el solucionador nativo aún no está armado para Linux/macOS/Android).
- El tutorial nuevo y el texto chico más grande se acaban de integrar: conviene una pasada de juego con jugadores nuevos.
- Una prueba (`test_save`) falló una vez de forma intermitente y parece depender del azar de la ruleta.

**Proyecto hermano (fuera de este repositorio).** Existe una carpeta aparte, `../Blackjack Web`, con una versión web y multijugador del blackjack (hasta 8 amigos por sala con enlace, Node.js sin dependencias, long polling, fichas, habilidades pasivas públicas, objetos secretos, tienda, misiones, eventos y bote). Usa la misma fuente y estética de cubitos y las reglas del blackjack del juego, pero tiene su propio código y no está versionado con git.

**Dónde leer más.** `CLAUDE.md` (reglas y datos clave), `docs/diseno.md` (cómo es el juego hoy), `docs/reglas_torre.md` (reglas exactas), `docs/economia.md`, `docs/generador.md`, `docs/catalogo.md` (todo el contenido), `docs/pendientes.md` (ideas y cosas quitadas).
