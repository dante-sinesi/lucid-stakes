# Diseño — Balatro x Catherine (título provisional)

Estado: borrador v0. Lo marcado **[ABIERTO]** está sin decidir; **[CERRADO]** lo definió Dante.

## 1. Fantasía
- **[CERRADO]** El personaje intenta despertar de una pesadilla escalando una torre de bloques.
- **[CERRADO]** Progresión visual: el fondo empieza oscuro y tenebroso y se aclara a medida que sube. Despertar = luz.
- **[ABIERTO]** Quién es el personaje, qué hay en la pesadilla, tono (¿culpa/terror como Catherine, o absurdo/casino como Balatro?). Lore pendiente de volcar.

## 2. Estructura
- **[CERRADO]** Un nivel = **27 etapas** de **50 bloques de altura** cada una.
- **[CERRADO]** Cada etapa tiene un fondo de oscuridad propio y constante dentro de la etapa; cambia al pasar a la siguiente. Etapa 1 = la más oscura, etapa 27 = la más clara.
- **[CERRADO]** Al completar una etapa se llega a una zona checkpoint con tienda (trampas / objetos), y luego se sale a la siguiente etapa.
- **[ABIERTO]** ¿Un "nivel" es todo el run, o hay varios niveles/mundos de 27 etapas? ¿Qué pasa al perder (todo se pierde, metaprogresión)?
- **[ABIERTO]** Duración del run. 27 × 50 = 1350 filas; con ~3 movimientos/fila al inicio y 30 al final, un run completo son horas. Revisar alcance.

## 3. Sin tiempo ni tope de movimientos: el vacío que sube
- **[CERRADO]** No hay máximo de movimientos ni cronómetro.
- **[CERRADO]** Cada N movimientos, la **fila más baja de la torre cae al vacío**. Si el jugador estaba apoyado/sostenido en esa fila, cae y pierde.
- Consecuencia de diseño: el reloj es el propio movimiento; el jugador tiene que ganar altura a un ritmo de ~1 fila cada N movimientos.
- **[CERRADO]** N sube con el mínimo de movimientos por fila de la etapa: siempre hay un margen sobre el mínimo, así la presión existe en todas las etapas y ninguna es imposible. **[ABIERTO]** la fórmula exacta (ej. N = mínimo × holgura, con la holgura bajando en etapas avanzadas).
- **[ABIERTO]** Avisos al jugador: contador visible, fila que se agrieta antes de caer.
- **[ABIERTO]** Zona checkpoint: se asume segura (el vacío no sube ahí).

## 3b. Forma de la torre (decidido con Dante, reemplaza el 4x5)
- **[CERRADO]** La torre tiene un **core sólido e inmóvil** de 2x2 (o 3x3) en el centro. No se puede empujar ni tirar; sí sostiene a sus vecinos y es trepable.
- **[CERRADO]** Alrededor del core hay **3 cubos de espesor hacia todos los lados**: huella total 8x8 con core 2x2 (9x9 con core 3x3). El tope de 4x5 queda descartado.
- **[CERRADO]** Ese anillo es solo el espacio disponible: el **generador llena parte** con plataformas, salientes y obstáculos; el resto queda vacío. Los bloques deben tocar al core o a otros para sostenerse.
- **[CERRADO]** La ruta sube **por afuera, rodeando el core**, de cara en cara (sin interior hueco). Girar la cámara sirve para ver lo que el core tapa.
- **[CERRADO]** Se acepta el truco de la catapulta (poner uno, empujarlo hacia afuera y saltar): forma parte de la gracia.
- Implicación: la heurística de altura del solucionador deja de ser exacta cuando haya catapultas (hay que revisarla), y la ventana del solucionador deberá recortarse también en horizontal.

## 5b. Criterio de dificultad (revisado tras probar el juego)
Dante probó el nivel y le resultó fácil: ganar a base de "más movimientos mínimos por fila" y con un margen holgado antes de la caída no alcanza. Decidido (Dante): buscar la dificultad en **puzzles que engañan**, en **combinar mecánicas** y en un **ritmo de caída variable por etapa**.
- **[IMPLEMENTADO] Ritmo variable por etapa** (`Gen.profile_for_stage`, `PACES`): cada etapa (1–27) tiene una dificultad, un ritmo (**rápido / normal / lento**), una probabilidad de mezclar mecánicas y las mecánicas activas. Las dos primeras etapas son de ritmo normal; después el ritmo cambia de una etapa a otra. Rápido: margen de la caída ×0,55 (la fila de abajo cae cerca, ≈2,2× el costo medio de una fila) y banda objetivo corrida −1. Normal: ≈4×. Lento: margen ×1,25 (≈5×) y banda objetivo +2. **El margen sí sigue el ritmo de forma confiable (2,2× / 4,0× / 5,0× medido); el largo real de las filas solo lo sigue de forma ruidosa** (con una muestra salió 5,2 lento contra 3,6 rápido, con otra al revés), así que la diferencia que se siente entre ritmos es sobre todo cuánta presión pone la caída. En el juego, las teclas `[` y `]` cambian de etapa para probarlo.
- **[IMPLEMENTADO] Puzzles que engañan**: el solucionador cuenta cuántos estados tuvo que explorar para resolver cada fila; ese "esfuerzo" mide cuántos caminos tentadores sin salida hay. Una fase de **enriquecimiento** muta los obstáculos de una fila ya válida mientras siga dentro de la banda y suba su esfuerzo. Medido (4 torres de 6 filas, dificultad 0,6): esfuerzo medio por fila 105 con enriquecimiento contra 79 sin él (+33 %); muestra chica, es una tendencia.
- **[IMPLEMENTADO] Combinar mecánicas**: desde la dificultad 0,4 (etapa ≈12) crece la probabilidad de que, entre las filas válidas, se prefiera la que mezcla hielo y bomba, y el enriquecimiento la busca. Medido: filas con ≥2 mecánicas 4 de 24 contra 2 de 24 sin la preferencia (tendencia, muestra chica).
- **[ABIERTO]** Falta probarlo jugando: ajustar los valores (`PACES`, ratio, umbrales) con la experiencia de Dante, y decidir si la caída debe además depender de cómo se juega (idea descartada por ahora: ligarla a la altura).

## 4. Reglas de bloques (estilo Catherine)
- **[CERRADO]** La estabilidad se decide por contacto en los ejes: un cubo que no toca a ningún otro cubo cae al vacío (en vez de gravedad simple "apoyado abajo").
- **[CERRADO]** El jugador empuja y tira bloques para armar la ruta. **Tirar sin piso atrás** (decisión de Dante, como en Catherine): el jugador da el paso igual y queda **colgado del borde** de donde estaba parado, y el bloque viene a ese lugar (queda justo encima del agarre: para trepar hay que correrse por el borde). Si atrás hay un escalón más bajo, baja en vez de colgarse. No se puede sobre hielo ni hacia fuera de la huella.
- **[CERRADO]** **Empujar hacia afuera de la huella** (decisión de Dante): el límite de 3 celdas alrededor del core solo restringe dónde se **generan** bloques. Un bloque empujado puede salir de la huella; el jugador no se mueve al empujar. Fuera queda como cualquier bloque: se sostiene si toca otro (por ejemplo, queda pegado al costado de la base, un nivel más abajo) y si no, cae al vacío. El hielo se desliza hasta chocar o hasta la primera celda fuera de la huella. El jugador sí sigue sin poder caminar fuera de la huella. (El solucionador codifica las celdas con desplazamiento para soportar coordenadas negativas.)
- **[CERRADO]** Regla de soporte: un cubo se queda si tiene al menos un vecino en cualquiera de los 6 ejes. Sin vecinos, cae. (Sin concepto de "ancla": dos cubos que se tocan se sostienen entre sí. Revisar si da exploits al probar.)
- **[CERRADO]** El jugador puede colgarse de bordes (hang) como en Catherine. Colgado puede avanzar por el borde y **doblar esquinas**: hacia afuera (el borde del bloque termina y se lo rodea, quedando agarrado de la otra cara del mismo bloque) y hacia adentro (la pared gira hacia el jugador y se agarra de ella sin moverse). No se dobla si el borde no está libre arriba o es de hielo. Complica la lógica del jugador y del solucionador; hay que definir estados: de pie / colgado, y qué cuenta como "sostenido" cuando cae la fila de abajo.
- Nota técnica: el prototipo actual usa gravedad simple (cae si no hay bloque debajo). Hay que reescribir `_settle()` en `scripts/tower_logic.gd` con la regla nueva.

## 5. Dificultad
- **[CERRADO]** La dificultad NO sube por menos movimientos disponibles, sino por la **cantidad de movimientos mínimos necesarios para pasar cada fila**.
  - Etapas iniciales: uno o dos bloques por fila, sin complejidad.
  - Etapas finales: pueden hacer falta muchos movimientos solo para pasar a la fila siguiente.
- Implicación: N (§3) tiene que ser ≥ el mínimo por fila de la etapa, o la etapa es imposible. Opciones: N crece con la etapa, o N fijo y se limita el mínimo por fila.
- Implicación técnica: generador de torres con **solucionador** que calcule el mínimo de movimientos por fila. Push y pull son inversos, así que se puede generar "desordenando" una fila resuelta con movimientos inversos y verificar con el solver.

## 6. Capa Balatro

### Trampas
- **[CERRADO]** Las trampas son consecuencia de los actos del propio jugador (como el hielo en Catherine), no peligros arbitrarios.
- **[CERRADO]** Ejemplo: **bloque bomba**. Se activa tras X movimientos; si explota, se cae toda la torre y se pierde.
- **[CERRADO]** La bomba se desactiva empujándola al vacío o purificándola.
- **[CERRADO]** La cuenta regresiva de la bomba se ve siempre.
- **[CERRADO]** Tipos de bloque por ahora: normal, **hielo**, **bomba**, **catapulta**. Más adelante se pueden sumar.
- **[CERRADO]** **Hielo**: al empujarlo se desliza hasta chocar contra algo. Si el jugador se desplaza sobre él es resbaladizo y no se puede agarrar del borde.
- **[CERRADO — CAMBIADO]** **Catapulta** (antes "trampolín"): una sola variante que **sube 4 bloques en vertical y no se mueve nada hacia los costados** (decisión de Dante). Arriba se **agarra del lateral** de un bloque vecino y queda colgado (no parado encima). Se descartaron las variantes diagonal y horizontal, y se quitó la flecha de la etiqueta.
- **[IMPLEMENTADO — reglas que fijé yo, revisar]** (`scripts/tower_logic.gd`, tests en `tests/test_logic.gd`):
  - **Hielo**: empujado, se desliza hasta chocar con otro bloque o el borde de la huella. El jugador que llega a una celda apoyada en hielo (caminando, trepando o tirando) sigue deslizándose en la dirección del movimiento hasta salir del hielo o chocar con un bloque; si se desliza fuera del borde, cae. No se puede colgar del borde de un bloque de hielo ni avanzar colgado hacia un agarre de hielo.
  - **Bomba**: cuenta un movimiento por acción **solo mientras el jugador está en su misma fila** (player.y == y del bloque). Al llegar a 0 explota: se cae toda la torre y se pierde. En otra fila la cuenta queda congelada; si la bomba cae al vacío queda desactivada. Ganar en el mismo movimiento tiene prioridad sobre la explosión. La cuenta se ve siempre (roja si está contando, gris si está congelada).
  - **Catapulta** (se activa al llegar a una celda apoyada en ella): dispara **hacia arriba** `CATAPULT_RISE` = 4 celdas (un techo corta el ascenso; si hay un techo pegado no despega). Arriba se agarra del lateral de un bloque vecino que tenga el borde de arriba libre y no sea de hielo (primero hacia donde miraba, después los costados y atrás) y queda colgado; trepar desde ahí cuesta otro movimiento. Si no hay de dónde agarrarse, vuelve a caer sobre la catapulta. Nunca avanza hacia los costados. Es el truco: empujar una catapulta contra una pared alta y subirla.
  - Estas cifras (`TRAMP_JUMPS`) y la regla de la bomba son fáciles de cambiar si no son lo que imaginabas.
- Nota técnica: los bloques con temporizador son estado extra para el solucionador/generador (hay que garantizar que la ruta mínima llega antes de la explosión).

### Economía: purificación y claridad
- **[CERRADO]** Todos los bloques empiezan **corruptos** (estética oscura, partículas de corrupción). Al **pasar sobre ellos**, el jugador los **purifica** (estética clara, partículas/efecto de luz).
- **[CERRADO]** La moneda se llama **claridad**. Cada bloque purificado da X claridad según su tipo.
- **[CERRADO]** Habrá un sistema de **racha de purificación** y similares.
- **[IMPLEMENTADO — reglas que fijé yo, revisar]** (`scripts/tower_logic.gd`, tests en `tests/test_logic.gd` y `tests/test_view.gd`):
  - **Qué purifica**: todo bloque sobre el que el jugador estuvo durante la acción (parado, trepando, resbalando por hielo, o el bloque del que se cuelga). Volar en un salto de catapulta no purifica lo que se sobrevuela (no hay contacto). La purificación acompaña al bloque (empujarlo no lo corrompe de nuevo); si cae al vacío se pierde.
  - **Claridad por bloque**: normal 1, hielo 2, catapulta 3, bomba 5, core 1 (`CLARITY`).
  - **Racha**: cada acción seguida que purifica algo nuevo suma 1 a la racha; el multiplicador es 1 + 0,5 × (racha − 1), con tope ×4. Una acción que no purifica nada nuevo (o volver por lo ya purificado) la corta a 0; se recuerda la mejor racha. Ganancia por acción = suma de bloques nuevos × multiplicador (redondeado). Las acciones fallidas no tocan nada.
  - **Bomba**: purificarla (pararse encima) la **desactiva**: deja de contar y no explota. Se ve con una tilde.
  - **Aspecto**: los bloques empiezan oscuros y violáceos con partículas oscuras; al purificarse recuperan su color, emiten luz suave, sueltan partículas de luz y dan un destello. El HUD muestra claridad, racha (con multiplicador), mejor racha y purificados; cada ganancia muestra un aviso dorado.
  - El solucionador y el generador **no optimizan claridad** (no cambia el juego); solo tienen en cuenta que purificar desactiva bombas.
- **[ABIERTO]** "Cosas del estilo" de la racha (bonus por combos, claridad por altura o etapa, objetos de la tienda que modifiquen el multiplicador); cómo se acumula la claridad entre etapas (el run todavía no existe).
- Tensión de diseño a aprovechar: purificar más bloques suele significar rodeos, y cada movimiento acerca la caída de la fila de abajo. Ruta mínima = seguro; rodeo = claridad pero riesgo.

### Azar
- **[CERRADO]** El azar entra en la **generación de la torre**, la **tienda** y los **eventos**. Eventos queda para más adelante (con lore y personajes).

### Tienda: casino
- **[CERRADO]** La tienda es un casino. No se compran cosas concretas: se **apuesta** en juegos con probabilidades de dar **boosts** o **herramientas**.
- **[CERRADO]** Hay dos categorías de premios:
  - **Boosts**: se compran/ganan y mejoran una habilidad de forma duradera (algunos con contrapartida, tipo trampa). Ejemplos: +1 al límite de movimientos por fila (retrasa la caída de la fila de abajo), que los movimientos de subir/bajar no descuenten.
  - **Consumibles**: efectos temporales o con usos limitados que se agotan. Ejemplo: convertir un bloque cualquiera en catapulta.
- **[ABIERTO]** Qué juegos (tragamonedas, cartas, dados…), probabilidades, cuánto se puede perder, límite de espacios para boosts y consumibles, si los boosts duran todo el run.
- Principio propuesto: la torre debe ser siempre resoluble sin boosts; los boosts dan margen, no son obligatorios.

## 6b. Casino (fase 6)
Decidido con Dante: **sala caminable más pantalla de apuesta** (se camina hasta la máquina y se abre una pantalla tipo Balatro); los tres juegos son **ruleta, tragamonedas y cartas/póker**, **empezando por la ruleta**; el riesgo **depende del juego**. La moneda es la **claridad**. Se arrancó por el casino antes que por las torres altas.

**Qué hay hecho** (todo con tests: `tests/test_casino.gd`, `tests/test_roulette_screen.gd`, `tests/test_casino_room.gd`):
- `scripts/items.gd`: catálogo de premios (solo datos; los efectos todavía no están conectados al juego): 4 épicos, 4 raros, 6 comunes y 3 baratos.
- `scripts/run_state.gd`: estado del run (claridad, boosts, consumibles, etapa). Máximo 5 boosts (únicos) y 3 consumibles.
- `scripts/roulette.gd`: reglas de la **Ruleta de la Luz**.
- `scripts/roulette_screen.gd` y `roulette_wheel.gd`: pantalla de apuesta.
- `scripts/casino_room.gd` y `voxel_mesh.gd`: distribución y modelo de minibloques de la sala.

**Ruleta de la Luz (reglas v0.1, las fijé yo, revisar)**
- 13 casillas: la **0 es la Pesadilla** (la casa: nunca se puede cubrir) y la 1–12 son de Luz.
- El jugador elige una apuesta, que fija cuántas casillas cubre, y las casillas: **Pleno** (1 casilla, 7,7 %, premio épico), **Terna** (3, 23,1 %, raro), **Mitad** (6, 46,2 %, común), **Rango** (9, 69,2 %, consumible). Cuanto menos cubre, mejor el premio.
- **Precio de la ficha fijo y el mismo para las cuatro**: 50 en la etapa 1, +15 % del precio base por etapa (65 en la etapa 3, 125 en la 11). No se elige el monto: con monto libre, los premios de valor fijo harían muy buenas las apuestas chicas o muy malas las grandes. Con precio fijo las cuatro rinden casi lo mismo (esperado 0,92–0,97 por ficha) y la decisión es cuánto riesgo querés.
- Gira: si cae una casilla cubierta se gana un premio del nivel de esa apuesta; si no, **se pierde la ficha** (la ruleta es el juego de riesgo: sin red).
- Los boosts duran el run y son únicos. Si no hay lugar (o ya lo tenés), el premio **se convierte en claridad: la mitad de su valor**. La **Bolsa de luz** (nivel consumible) paga 1,4 veces la ficha en claridad.
- La pantalla decide el resultado primero y la rueda gira para mostrarlo (la casilla ganadora queda bajo la bola, comprobado para las 13).

**Premios (borrador)**: épicos (boosts): Segundo aliento (una vez por etapa, si caés al vacío volvés a la última plataforma firme), Madrugada (la fila de abajo cae al doble de lento en toda la etapa), Luz propia (al pisar se purifican los vecinos), Mano de oro (la racha sube de a 1,0). Raros (boosts): Pies de luz (+1 de claridad por purificar), Paso firme (trepar y bajar no cuenta para la caída), Reflejos (+3 a las cuentas de las bombas), Racha larga (tope ×6). Comunes: Aire extra (la caída llega 1 movimiento más tarde), Ojo de hielo, Ahorro (+20 de claridad al empezar cada etapa) y los consumibles Freno (pausa la caída 5 movimientos), **Catapulta de bolsillo** (convierte el bloque de enfrente en catapulta), Desarmar (desactiva una bomba). Baratos: Bolsa de luz, Hielo a roca, Ancla chica.

**Sala del casino** (11 × 9 celdas, a la escala del personaje; zona segura: no sube el vacío ni hay corrupción): plataforma de llegada de luz al sudeste, mesa de la ruleta (3×2 celdas) con rueda de 13 sectores en el paño, **el crupier** de galera detrás de la mesa (gancho para el lore), tres tragamonedas tapadas con un cartel "?" contra la pared oeste, una mesa de cartas tapada, y una **escalera de luz** que sube hasta un portal en la pared norte (salida a la etapa siguiente). Se juega a la ruleta parado en una celda que toca la mesa (6 lugares). La distribución en celdas es la única fuente de verdad del dibujo y de las celdas caminables.

**Pendiente del casino**: (a) escena jugable (caminar por la sala con el movimiento existente, interactuar con la mesa, abrir la pantalla y salir por la escalera); (b) ocultar o atenuar las paredes que quedan del lado de la cámara al rotarla; (c) conectar los efectos de los premios al juego; (d) tragamonedas y cartas/póker; (e) diálogo y lore del crupier; (f) balancear contra la claridad real que se junta en una etapa de 50 filas (hoy el precio de la ficha es un valor inicial sin esa medición).

## 7. Visual
- **[CERRADO]** 3D, vista isométrica, cámara rotable de a 90°, estilo voxel de cubos simples.
- **[ABIERTO]** Cámara que sigue al jugador (la torre mide 50 filas: se ve una ventana de altura, no entera).

## 7b. Aspecto de los bloques
- **[CERRADO]** Los bloques deben distinguirse por **dibujo propio** y no solo por color (con la claridad, corrupto/purificado cambia el color y ya no alcanzaba).
- **[CERRADO — IMPLEMENTADO]** Cada bloque se modela con **minibloques** (voxels de 5x5x5; `scripts/block_models.gd`, shader `shaders/voxel_block.gdshader`). Es solo visual: la lógica sigue en cubos. Cada tipo y estado tiene un modelo que se construye una vez y comparten todos los bloques de ese tipo (sin costo por bloque).
  - **Normal**: cubo con esquinas cortadas, aristas oscuras y panel claro arriba; al purificarse toma el color de su altura. **Hielo**: cristal astillado con vetas blancas y azules (arriba queda plano). **Bomba**: bola oscura con mecha y chispa; desactivada se vuelve gris verdosa. **Catapulta**: placa de abajo, cuatro resortes plateados y plato naranja. **Core**: piedra gris con esquinas rotas.
  - **Corrupto vs purificado**: el corrupto es **irregular** (le faltan minibloques sueltos) y oscuro, con un toque violeta pero conservando algo del tono de su tipo; el purificado está completo y con su color. Al purificarse cambia de modelo con un rebote y un destello. La cara de arriba (la que se pisa) se conserva casi completa en todos los estados.
  - Pruebas: `tests/test_models.gd` (forma, caras hacia afuera, tamaño, determinismo, cara de arriba) y `tests/test_view.gd`. Maqueta previa en `docs/maquetas/`.
- **[DESCARTADO]** El dibujo por shader sobre cubos planos (`block.gdshader`) se reemplazó por los minibloques.

## 8. Tecnología
- **[CERRADO]** Godot 4 (MIT) + GodotSteam (MIT). Sin Unity. Publicación en Steam.

## 8b. Ideas que podrían no aplicarse
- **Deshacer / reintentar fila** (como en Catherine): descartado por ahora por decisión de Dante. Queda como idea abierta; sin él, un empuje o tirón malo puede dejar la torre sin salida.

## 9. Plan técnico por fases (propuesto)
Cada fase termina con algo jugable y testeado.
1. **Reglas núcleo** — HECHO (`scripts/tower_logic.gd`, tests en `tests/test_logic.gd`): soporte por vecinos en 6 ejes, hang, empujar/tirar, caída de la fila de abajo cada N movimientos.
2. **Solucionador** — HECHO (`scripts/solver.gd`, tests en `tests/test_solver.gd`): A* con heurística de altura; opcionalmente simula la caída de la fila base. `solve_rows` da el perfil de movimientos por fila a partir de un camino óptimo global; `solve_rows_greedy` es una aproximación barata que sobrestima (el óptimo de una fila puede dejar mal parado para la siguiente).
   - **Rendimiento medido**: ~4–5 mil estados/segundo en GDScript. En terrenos abiertos con muchos bloques movibles (5x5 a 6x6, alturas hasta 3) el solucionador llega a 15 mil estados sin resolver subir 3–4 niveles. Conclusión: el solucionador NO puede validar torres de 50 filas enteras ni terrenos con muchos bloques sueltos. El generador de la fase 3 tiene que construir filas con pocos bloques movibles y validar cada fila en una ventana local (más el contexto necesario), y la dificultad por fila debe venir de la construcción (movimientos inversos desde una fila resuelta), no de buscar a ciegas.
   - Posibles mejoras si hace falta: poda de bloques irrelevantes, solver sobre ventana de filas, o llevarlo a C# / GDExtension.
3. **Generador de filas** — HECHO v3 (`scripts/tower_gen.gd`, tests en `tests/test_gen.gd`).
   - Estructura: core fijo 2x2 (opción 3x3) en una huella de 8x8 (9x9); capa 0 = base completa; el core llega una capa sobre la meta.
   - **Formas de plataforma** (variedad): mancha, barra, L y arco que sigue el anillo alrededor del core (los arcos largos obligan a caminar mucho). Sesgadas a rodear el core y a tocarlo.
   - **Tipos de bloque**: las celdas de la plataforma pueden ser de hielo o catapulta (es el piso de la fila siguiente); los obstáculos pueden ser normales, de hielo, bombas (cuenta 3–8) o catapultas, y a veces pilares de 2. Las probabilidades suben con la dificultad.
   - **Dificultad**: se valida cada candidato con el solucionador (ventana de 4 capas, más arriba si hay catapultas) y se busca que el mínimo caiga en `band_for(d)` (d=0 → 2–4, d=1 → 10–12). Después de generar candidatos hay un **ascenso por mutaciones** (suma, mueve o cambia obstáculos, o pone hielo en la plataforma) que mantiene la resolubilidad y empuja el mínimo hacia arriba. La plataforma se pide lejos de donde llega el jugador (distancia que crece con la dificultad; se relaja si no hay candidatos).
   - **Resolubilidad**: se avanza fila a fila ejecutando el camino óptimo; todo lo que pisa el jugador (rastro, con deslizamientos y saltos) y la celda de arriba quedan reservados en 3D para que nada posterior lo invalide; al final se reproduce el camino completo con la caída activa y las bombas vivas, y si falla se reintenta con otra semilla derivada (hasta 4 veces). Una ronda final con dificultad 0 garantiza que cada fila produzca algo.
   - **N** (cada cuántos movimientos cae la fila base) = **margen constante sobre el costo medio de una fila**: ratio 4,5 en dificultad 0 y 2,6 en dificultad 1, y nunca menos que 1,6 × el mínimo que exige el propio camino. La **primera caída llega a los 2N movimientos** (tiempo para explorar). Así dos torres de la misma dificultad presionan igual. (Antes N salía del peor momento de cada torre y el margen iba de 2,1× a 5,1× el costo medio: unas torres eran muy justas y otras casi no presionaban.)
   - **Sin filas triviales**: ninguna fila se resuelve en menos de max(2, banda−1) movimientos ni en más de banda+4. Cada plataforma tiene un tamaño mínimo (es el espacio de juego de la fila siguiente). Un bloque suelto de una capa es un escalón, no un obstáculo: los obstáculos normales son pilares de 2 en el 60 % de los casos, y como la parte de arriba de un pilar cae en la capa de la fila siguiente, el generador **mira una fila hacia adelante** y descarta los candidatos que le regalan un escalón (también se evalúa la variante sin la parte de arriba).
   - **Mecánicas de a una**: hielo desde dificultad 0,05, catapulta desde 0,25, bomba desde 0,4; tope de bloques especiales por fila (1 + 3·d) y de celdas de hielo por plataforma (2 + 2·d). Se prefiere una forma de plataforma distinta a la de la fila anterior.
   - **Medido** (10 torres de 8 filas, dificultad 0,3; banda 4–6): media 4,25 movimientos por fila, desvío 1,3 (antes 2,6), filas de 1 movimiento 2 de 64 (antes 11 de 80), margen de la caída 4,0–4,1 × el costo medio en todas las torres (antes 2,1–5,1). Dificultad 0: media 2,6, desvío 1,0. Dificultad 0,7: media 6,8. Dificultad máxima (2 torres de 4 filas): media 6,6–8,6.
   - **Pendiente de la dificultad alta**: con dificultad ≥ 0,7 todavía aparecen filas de 1 movimiento (≈ 2 de 18 con 0,8) y algo de dispersión; la banda 10–12 de la dificultad 1 casi no se alcanza. Sigue haciendo falta más búsqueda por fila o un solucionador más rápido.
   - **Tiempo** (medido tras agregar hang con esquinas): generación completa ≈ 7 s (d=0) a 15–60 s (d≥0,3) por torre de 6–8 filas; una etapa de 50 filas a dificultad media/alta tarda varios minutos, así que hay que generarla fuera de línea. Colgarse y doblar esquinas multiplica las posiciones que explora el solucionador (≈2,4× más lento).
   - **Generación al jugar**: corre en un **hilo aparte** (el juego no se congela y muestra los segundos transcurridos), con una búsqueda más liviana (`GEN_OPTS`: 6 candidatos por fila, ascenso por mutaciones a la mitad): ≈3,8 s de media (peor caso ≈8 s) a dificultad 0,3 con 8 filas, con algo más de filas triviales (≈10 % contra ≈3 %). Si una semilla no sale, prueba con otras (hasta 4).
   - **Robustez** (corregido tras detectar que una etapa difícil no se generaba con la búsqueda completa): al agregar plataformas más arriba, un bloque nuevo puede sostener uno que en la simulación caía (la parte de arriba de un pilar) o frenar uno que se deslizaba, y entonces el camino de una fila anterior se desviaba. Reservar de antemano el entorno de todo lo que se mueve dejaba sin lugar para las plataformas; lo que funcionó fue **validar**: antes de aceptar un candidato se repite sobre la torre completa todo el camino anterior más el de la fila nueva (`_path_consistent`), y si se desvía se descarta ese candidato. Además se reservan las celdas sobre el bloque del que se agarra el jugador. Medido con la búsqueda liviana, 6 filas: 12 de 12 torres se generan (dificultades 0,3 / 0,6 / 1,0); a dificultad media/alta a veces hace falta un segundo intento (a la primera: 4/4, 2/4, 3/4).
   - **Pruebas del generador**: `tests/test_gen.gd` (≈1,5–2 min, búsqueda liviana) y `tests/test_gen_quality.gd` (búsqueda completa, ≈10 min, a mano). El de calidad dio, antes de esta corrección, 3 de 24 filas triviales (12,5 % contra el 10 % buscado) y una etapa difícil que no se generaba; **no se volvió a correr tras la corrección**.
   - **Catapultas**: ya no se generan en las torres (`CATAPULTS_IN_TOWERS = false`): suben 4 en vertical y se agarran de un borde, y en una torre generada casi nunca hay una pared alta con el borde libre al lado; no aportaban a la solución y encarecían la búsqueda. El bloque sigue disponible (reglas, solucionador, vista, tests) para la tienda (consumible "convertir un bloque en catapulta") y para el truco.
   - Limitaciones: (a) la dificultad máxima sigue sin llegar a la banda 10–12 en la mayoría de las filas; (b) el jugador puede dejar la torre sin salida si empuja o tira mal (el deshacer queda como idea que podría no aplicarse); (c) la ventana del solucionador no recorta en horizontal; (d) el truco de la catapulta (poner uno y saltar) lo permite el juego pero el generador no lo busca ni lo evita; (e) la claridad no entra todavía en la generación ni en la dificultad.
   - Visibilidad: la torre se ve entera (desde arriba, con la cámara muy inclinada, se ocultan las capas que tapan al personaje); silueta del personaje solo donde algo lo tapa (`shaders/silhouette.gdshader`).
4. **Tipos de bloque** — HECHO: hielo, bomba (cuenta) y catapulta (única, horizontal) en las reglas, el solucionador (clave de estado con tipos y cuentas; heurística ajustada a los catapultas), el generador y la vista.
5. **Purificación y claridad** — HECHO: bloques corruptos/purificados (aspecto y partículas), claridad por tipo, racha con multiplicador, bombas desactivables al purificarlas. Falta que la claridad se acumule entre etapas (depende del run, fase 6).
6. **Zona checkpoint y casino** — EN CURSO: economía y ruleta (reglas + pantalla) y sala dibujada y probada; falta la escena jugable, los efectos de los premios y los otros dos juegos (ver §6b).
7. **Etapas y fondos**: progresión 27 etapas, fondo por etapa, cámara que sigue al jugador.
8. **Pulido, lore y eventos, Steam** (GodotSteam).
La demo para Steam puede ser fases 1–7 con pocas etapas.

## 5c. Meta = portal
Ganar la torre exige estar **parado** sobre el bloque-portal (`goal_block` en `TowerLogic`), marcado con una baldosa dorada y un haz de luz que siguen al bloque si se lo mueve; llegar a la altura de la meta sobre otro bloque (o colgado) no gana. El generador fija el portal en el bloque donde termina el camino de referencia (si termina colgado suma el paso de trepar). Idea de historia: el portal lleva al casino, y el portal del casino lleva a la torre siguiente. Sin `goal_block` (torres de prueba) vale cualquier bloque de la capa superior.

## 6c. Casino jugable
`scripts/casino_scene.gd`: la sala de `casino_room.gd` con el personaje caminando por celdas (WASD, siguiendo la diagonal de la pantalla, Q/E giran la cámara y ocultan la pared que tapa). Flujo del run: pisar el portal de la torre → la claridad de la torre pasa al `RunState` → casino (se aparece frente a la puerta de llegada, sólo estética) → chocar con la mesa (o Espacio/Enter mirándola) abre la ruleta → empujar la puerta de salida (pared norte) lleva a la torre de la etapa siguiente. Las dos puertas llevan un portal en espiral (estilo Minecraft); se aclaran con las etapas y la de salida es algo más clara (`Room.portal_color`). En la torre, el rayo de luz del portal sólo se ve cuando se ve el bloque-portal. Tragamonedas y mesa de cartas avisan "próximamente". Pendientes: efectos de los premios, balance ficha vs. claridad real, tragamonedas y cartas.

## 3c. Etapas de 25 pisos, menús y aclarado por etapa
- Una **etapa** es una torre de 25 pisos; al llegar al bloque-portal de la cima se entra al casino y al salir empieza la etapa siguiente, algo más difícil. Son 27 etapas (la última no tiene casino: termina el juego y se vuelve al menú).
- Toda torre se genera en el momento y es **nueva** (nada pregenerado): mientras se juega la etapa N, otro hilo genera la N+1 (`_prefetch_next_stage`); si todavía no está lista al salir del casino se muestra "Generando la torre...". La generación se aborta con `TowerGen.cancel` al volver al menú.
- Fondo y bloques se aclaran **de una etapa a la siguiente**, no dentro de una misma (`stage_tone`: color de fondo, tono de los bloques normales purificados y tinte de los corruptos).
- Menú principal (Nueva partida / Cómo jugar / Salir) y menú de pausa con Esc (Continuar / Reintentar la torre / Cómo jugar / Volver al menú principal / Salir del juego): `scripts/main_menu.gd`, `scripts/pause_menu.gd`.
- Cámara: en torres de más de 16 de alto sigue al personaje en altura.
- Pendiente: rendimiento con 25 capas visibles, tiempos de generación en las etapas altas (con `budget_ms` como tope del afinado).

## 2b. Reglas de movimiento: solo lo que existe en Catherine
Criterio: el juego implementa únicamente mecánicas de Catherine (fuentes: [Catherine Wiki – Puzzle Mechanics](https://catherine.fandom.com/wiki/Puzzle_Mechanics), [Samurai Gamers – técnicas de Full Body](https://samurai-gamers.com/catherine-full-body/techniques-locations-list/) y reseñas del juego). Lo que confirman esas fuentes:
- Vincent **no salta**: trepa de a un bloque. Corre por encima de los bloques, empuja y tira en 4 direcciones.
- Si no hay bloque abajo al caminar hacia un borde se cuelga de él (en el juego, a propósito: Espacio + dirección). Colgado: se desplaza de costado, dobla esquinas y trepa solo si hay lugar arriba.
- **Regla de la arista**: un bloque sin nada debajo se queda en el aire mientras una de sus aristas toque la arista de otro bloque; si un bloque se empuja a un lugar sin contacto, cae junto con lo que sostenía.
- Bloques especiales: hielo (resbala), bomba y resorte (nuestra catapulta).

Decisiones de nuestro juego:
- **Tirar de un bloque sin piso atrás no se permite**: el bloque tirado quedaría sobre el borde del que te agarrarías (no hay borde que agarrar entre dos cubos). Se cuelga solo a propósito (Espacio + dirección). Se quitó además el "bajar al piso del costado desde colgado", que no es una mecánica de Catherine.
- Se mantienen: empujar fuera de la huella (el bloque queda por la regla de la arista o cae), colgarse una celda por fuera de la huella, bajar de a un escalón.
- No implementado todavía (existe en Catherine): empujar varios bloques en fila de una vez; bloques pesados, trampas de pinchos y bloques que se desmoronan.

## 3d. Modo entrenamiento
Se entra desde el menú principal y se elige la etapa (1–27, la dificultad). Es una torre de la etapa elegida sin casino ni etapa siguiente; al llegar a la cima se avisa y con N se genera otra. (La pista con P y `hint.gd` se eliminaron: ya no hay pistas.)

## 6d. Boosts, consumibles y economía (efectos conectados)
- **Boosts** (duran todo el run; `TowerLogic.apply_perks` al empezar o reintentar cada etapa): Aire extra (+1 a la caída), Madrugada (la caída al doble), Paso firme (trepar/bajar no cuenta para la caída), Pies de luz (+1 por bloque purificado), Luz propia (purifica los vecinos), Mano de oro (racha de a 1,0), Racha larga (tope ×6), Reflejos (bombas +3), Ojo de hielo (frena una celda antes), Ahorro (+20 de claridad por etapa), Segundo aliento (una vez por etapa, si caés volvés a la última celda firme).
- **Consumibles** (teclas 1/2/3, no gastan movimiento; `TowerLogic.use_item`): Freno (5 movimientos sin que se acerque la caída), Desarmar (bomba más cercana), Hielo a roca (hielo cercano), Catapulta de bolsillo (el bloque de enfrente), Ancla chica (el bloque de enfrente o el de abajo no cae esta etapa).
- **Economía**: una torre da entre ~190 (etapa 1) y ~390 (etapas altas) de claridad siguiendo el camino mínimo. La ficha de la ruleta sube `PRICE_STEP` = 2 por etapa (50 → 102, ≈ un cuarto de lo que se junta) y el valor de los premios escala con la ficha (`Items.value_of`), así el rendimiento esperado se mantiene entre 0,90 y 1,00 en todas las etapas.

## 7. Interfaz de cubitos (estilo Balatro)
Todo el texto, los botones, los menús, la pantalla de la ruleta (incluida la rueda) y el HUD están hechos de cubitos con relieve, vistos **de frente** (sin perspectiva): el volumen sale de los niveles (placa, borde, letras), de las sombras duras y de la inclinación de las cartas. Estilo híbrido: algo limpio (mármol y dorado) que se va corrompiendo (cubitos violetas, huecos y chorreras oscuras que crecen hacia abajo).
- `voxel_font.gd`: fuente propia de 5 x 11 celdas (ASCII, números, acentos, ñ, ¡ ¿ × « »). Un carácter sin glifo se dibuja como "?".
- `voxel_draw.gd`: cubitos con luz y sombra (`cube`), texto con sombra dura (`text_cells`) y cartas (`card`: sombra dura, placa lisa, borde de cubitos y franja de brillo).
- `voxel_label.gd` (reemplaza a Label: alineación, corte por ancho, placa oscura para leer sobre la escena 3D, `dance` para que cada letra baile en los títulos) y `voxel_button.gd` (botón-carta: flota, se inclina hacia el mouse, crece al pasar por encima y se hunde al apretarlo; su tamaño sale del texto con margen de sobra, así nunca queda chico; cambiar el texto con `set_label`).
- `swirl_bg.gd`: fondo en remolino de cubitos (menús y ruleta).
- `menu_ui.gd`, `main_menu.gd`, `pause_menu.gd`, `roulette_screen.gd`, `roulette_wheel.gd` (mosaico de cubitos que gira), HUD de la torre (`main.gd`) y del casino (`casino_scene.gd`).

## 6e. Barras de ítems
- **Izquierda: consumibles** (4 casilleros de base, teclas 1 a 4 o clic) y **derecha: boosts** (5 de base). Los casilleros **no son fijos**: dependen de los boosts del run (`RunState.consumable_capacity` / `boost_capacity`). **Bolsillo hondo** suma 1 casillero de consumibles y **Mente abierta** suma 2 de boosts (ocupa uno, neto +1); los dos son acumulables (`stack`). Si los casilleros están llenos, el premio se convierte en claridad.
- Cada ítem tiene su ícono de 9 x 9 cubitos (`scripts/item_icons.gd`); los casilleros (`item_slot.gd`) son cartas que se inclinan hacia el mouse, y pasar por encima muestra el nombre y la descripción. Con muchos casilleros acumulados se achican para entrar en la pantalla. El casino muestra las mismas barras (de sólo lectura).

## 6f. Pantalla de la ruleta (rediseño) e ícono de claridad
- Rueda grande y centrada: **las fichas se ponen tocando la rueda** (lo que ves es lo que tocás: el clic usa la rotación actual de la rueda, que gira despacio mientras se elige). Las casillas elegidas se oscurecen y llevan una pila de fichas doradas, así resaltan; al pasar el mouse se aclara la casilla.
- Debajo, las cuatro apuestas como cartas, el precio de la ficha y GIRAR. Un mensaje corto reemplaza los párrafos ("Tocá 2 casillas en la rueda"). **Premios** abre una ventana (`prizes_window.gd`) con los premios de cada apuesta: ícono, descripción y probabilidad (probabilidad de acertar x peso del premio en su nivel).
- **Ícono de la claridad** (`clarity_icon.gd`, `clarity_counter.gd`): una barra vertical atravesada por tres cruces horizontales, de cubitos en isométrico y girando, en colores cálidos de rayo (blanco amarillento y dorado). Se usa en vez del texto "Claridad: N" en la ruleta, el casino y el HUD de la torre.

## 8. Modo dev (consola)
- **F1** abre y cierra una consola arriba de la pantalla (Esc también la cierra; flechas arriba y abajo recorren el historial). Con la consola abierta el juego ignora el teclado.
- Comandos (`scripts/dev_commands.gd`): `help`, `goto_end` (o `win`: te lleva al portal de la torre actual, o sea al casino), `set_claridad <n>` (deja la claridad total en n; para restar, un número menor; no baja de 0), `give <id>` (un boost o consumible; `items` lista los ids).
- **No existe en Steam**: `DevCommands.available()` es `OS.is_debug_build()`, que es falso en las exportaciones con plantilla **release**; ahí la consola ni se crea y los comandos no hacen nada. Al exportar para Steam hay que usar la plantilla release (no marcar "Export With Debug"). Las pruebas lo verifican simulando una compilación release (`tests/test_dev.gd`).

## 9. Reintentos, fin de run, cámara libre y guardado
- **Reintentar la torre cuesta claridad** (`RunState.restart_cost`): la mitad de la ficha de la ruleta de la etapa (25 en la etapa 1, 51 en la 27), multiplicado por 1 + los reintentos que ya hiciste en esa misma torre. Se paga de la claridad del run; la que juntaste en el intento que abandonás se pierde. Si no alcanza, el run termina. En el entrenamiento es gratis. La pausa muestra el costo y tiene "Abandonar el run".
- **Pantalla de fin de run** (`run_end_screen.gd`): victoria (etapa 27 superada) o fin (abandono o sin claridad para reintentar), con etapa alcanzada, torres superadas, claridad juntada, gastada y ganada en la ruleta, reintentos, movimientos y los boosts; botones Nueva partida y Menú principal.
- **Cámara libre**: arrastrar con el mouse gira e inclina, la rueda hace zoom; Q y E vuelven al ángulo isométrico (inclinación y zoom incluidos) girando 90 grados. Se quitaron C y Z. Desde arriba (inclinación ≥ 52°) se ocultan las capas que tapan al personaje.
- **Guardar y continuar** (`save_game.gd`, `user://save.json`): autoguardado cuando la torre está lista, al primer movimiento o consumible, al entrar al casino, al cobrar cada tirada de la ruleta y al salir al menú o cerrar. Continuar vuelve al casino donde estabas o al comienzo de la misma torre; si el intento ya había empezado, continuar cuenta como un reintento (así salir y volver no reinicia gratis). Terminar el run borra el guardado; el entrenamiento no guarda.

## 10. Más mecánicas de Catherine

- **Agrietado** (`Kind.CRACKED`, arenisca con grietas): se pisa y se puede empujar como uno normal, pero se rompe y cae al vacío apenas el jugador se mueve estando parado sobre él. Lo que sólo se sostenía de él cae también. Aparece desde la dificultad 0,25 (etapa 8).
- **Pesado** (`Kind.HEAVY`, hierro con remaches): no se empuja ni se tira, pero se puede trepar; cae si se queda sin apoyo. Aparece desde la dificultad 0,15 (etapa 5).
- Ambos salen como obstáculos sueltos del generador (no en plataformas), cuentan para el tope de bloques especiales por fila y el solucionador los valida igual que el resto. `BlockModels.CORE` pasó a valer 9 para dejar lugar a los tipos nuevos.
- La torre se ve entera (ya no se oculta lo que está por encima de la altura alcanzada).
- La pantalla de inicio de Godot está apagada (`boot_splash/show_image=false`). La licencia MIT de Godot pide conservar su aviso de copyright en algún lugar (créditos o archivo de licencias), no mostrar el logo.
- **Créditos** (botón "Créditos" abajo a la izquierda del menú principal, `UI.make_credits_panel`): los créditos del juego (`UI.CREDITS_GAME`, con nombres por completar), el aviso de copyright y la licencia MIT de Godot, y la lista de componentes de terceros del motor. El texto sale de `Engine.get_license_text()` y `Engine.get_copyright_info()`, así se mantiene al día con la versión de Godot usada.

## 11. Tutorial y cámara con flechas

- El **modo entrenamiento se quitó**; en su lugar el menú principal tiene **Tutorial** (`scripts/tutorial.gd`): 10 lecciones, cada una una torre chica armada a mano que enseña una sola cosa: moverse (y la rosa de los vientos), trepar, empujar (un hueco que sólo se cruza empujando un bloque encima), tirar (se completa dejando el bloque en la casilla dorada), colgarse (una torre alta que no se baja caminando), hielo, pesado, agrietado, bomba, y una torre generada de verdad de 4 pisos. `tests/test_tutorial.gd` comprueba con el solucionador que cada lección se puede ganar y que empujar y colgarse son imprescindibles donde se enseñan.
- Dentro del tutorial: cartel con la lección arriba, reintento gratis (R), al completar una lección aparece un "¡Bien!" y a los ~1,3 s pasa sola a la siguiente (Enter o N la adelantan o saltan) y Esc pausa. No hay casino ni claridad en juego y no se guarda. La última lección vuelve al menú.
- **Las flechas ahora giran la cámara** (izquierda y derecha giran, arriba y abajo inclinan, igual que arrastrar con el mouse); ya no mueven al personaje: el movimiento es sólo WASD.
- `N` (torre nueva) y `[` `]` (cambiar de etapa) quedaron **sólo para compilaciones de desarrollo** (donde existe la consola F1): antes funcionaban en una partida normal y eran un truco.
- Curva de mecánicas por etapa (según la dificultad `(etapa-1)/26`): 1 y 2 sólo bloques normales; hielo desde la 3; pesado desde la 5; agrietado desde la 8; bomba desde la 12.

## 12. El casino se aclara con las etapas

- `Room.look(stage)` (casino_room.gd) da la paleta de la sala según la etapa: de un sótano sucio y casi sin luz (etapa 1: piso y paredes oscuros, bronce en vez de dorado, mugre violeta y minibloques rotos en paredes y piso, lámparas rojizas) a un salón de mármol claro (etapa 27: piso blanco y celeste pálido, dorado brillante, sin corrupción y con pilastras de mármol: una desde la etapa ~10 y tres por pared desde la ~19). El cambio es suave en los extremos (curva smoothstep).
- La luz ambiente del casino también sube con la etapa (`AMBIENT_TOWER` 0,7 → `AMBIENT_CASINO_LATE` 1,5 en `main._apply_casino_light`); en las torres vuelve a 0,7. El fondo ya seguía el tono de la etapa.
- La distribución (celdas, mesa, puertas) no cambia con la etapa: sólo el aspecto. Que la sala "crezca" de tamaño quedó descartado por ahora porque toca la caminata, las puertas y las pruebas.
- **Actualización: el casino cambia de diseño, no sólo de color.** `Room.layout(stage)` define 4 niveles de sala: **taberna** (etapas 1-6: 7×6 celdas, tablas rústicas, barriles, chimenea, sin tragamonedas), **salón** (7-13: 9×7, piedra y ladrillo con zócalo de madera, estantes con botellas, plantas, 2 tragamonedas), **casino** (14-20: 11×9, la distribución clásica con alfombra, cuadros y pilastras) y **gran casino** (21-27: 13×11, mármol, paredes más altas, pilastras acanaladas, columnas libres de mármol, 3 tragamonedas, 2 mesas de cartas y la ruleta sobre una tarima de dos escalones; el personaje sube con ellos). El piso, las paredes y los muebles se modelan distinto en cada nivel (el material se afina). La escena (`casino_scene.gd`) usa `lay` (la distribución de su etapa) y el zoom de la cámara crece con la sala. `tests/test_casino_room.gd` comprueba para varias etapas que todo es alcanzable, que hay lugares de ruleta y que el piso y las puertas están completos.

## 13. Generación adelantada, comando goto_casino y registro de partidas perdidas

- La torre de la etapa siguiente ya se generaba en un hilo mientras se jugaba la actual; ahora además se asegura al **entrar al casino** (`enter_casino` llama a `_prefetch_next_stage`, que no duplica) y, con el menú abierto y sin partida guardada, se va generando la **etapa 1** (para que "Nueva partida" arranque casi sin espera). Continuar y Tutorial cancelan esa generación del menú.
- Consola dev: **`goto_casino <1-27>`** abre directamente el casino de esa etapa (taberna 1-6, salón 7-13, casino 14-20, gran casino 21-27) sin pasar por las torres; al salir sigue con la torre siguiente.
- **Registro de partidas perdidas**: al perder, el juego imprime en el log de Godot (`%APPDATA%\Godot\app_userdata\Balatro x Catherine\logs\godot.log`) una línea `PERDIDA (motivo): semilla=... etapa=... acciones=dx,dz,modo;...` con todas las acciones del intento. Con la semilla y las acciones se puede regenerar la torre y reproducir el caso exacto (generar con esa semilla, etapa y 25 filas, y aplicar las acciones en orden).

## 14. HUD del jugador

- **El jugador no ve textos de controles ni de depuración.** Se quitaron las líneas de ayuda ("Esc: pausa, Mouse o flechas...") de la torre y del casino; los controles se explican en "Cómo jugar" y en el tutorial.
- **HUD de la torre** (arriba a la izquierda): `Etapa N/27` y `Piso N/M`, la claridad (ícono más grande y placa oscura para leerla también en las etapas claras), `Cae en N` (cuántos movimientos faltan para que caiga la fila de abajo; roja con 2 o menos; no aparece en las lecciones sin caída) y `Racha ×N` (sólo con racha). Los consumibles de la izquierda bajan para no pisar esos textos. Arriba a la derecha, la rosa de los vientos.
- **HUD del casino:** sólo los contadores de claridad y de la ficha (con placa) y la frase del crupier; sin título ni ayuda.
- **Textos de depuración** (etapa con ritmo, caída, altura, movimientos, racha, purificados, semilla): `main.hud`, ocultos; **F2** los muestra y oculta, y sólo en compilaciones de desarrollo (en la release F2 no hace nada).
- El aviso al perder queda como `R: reintentar (−N de claridad)`.

## 15. Escenarios, pruebas y habilidades persistentes (meta-progresión)

- **Escenarios** (`scenarios.gd`): son como los mazos de Balatro. **La Pesadilla** (el juego de siempre) es gratis; los demás cuestan **Luz** *por partida* (la entrada se gasta cada vez que se juega) y pagan más Luz (multiplicador `luz_mult`). Cada uno cambia reglas: **Glaciar** (torres llenas de hielo), **Ruinas** (agrietados y pesados), **Polvorín** (bombas), **Relojería** (ritmo rápido siempre y ficha 25 % más barata) y **Gran Casino** (casino de lujo desde la etapa 1, ficha 20 % más barata, torres algo más difíciles). Si no alcanza la Luz se juega La Pesadilla. Quedó pendiente un escenario "Sprint" de pocas etapas (hace falta que el largo del run no sea fijo en 27).
- **Selector de escenario** (`scenario_screen.gd`, `scenario_card.gd`): "Nueva partida" (y la del fin de run) abre una fila de **tarjetas** que se desplaza en horizontal (flechas, rueda del mouse o teclas izquierda y derecha). Cada tarjeta tiene el nombre, una ilustración de cubitos (`scenario_art.gd`), cuánto multiplica la Luz, un botón **?** arriba a la derecha (reglas, pruebas que pueden salir y habilidades que se pueden ganar) y abajo al centro el botón de entrada con el costo y el sol (el gratuito dice Jugar). Los de pago se bloquean sin Luz.
- **Pruebas** (`trials.gd`): caen en las etapas **3, 6, 9... 27** (múltiplos de 3). Al empezar cada partida se **sortea** cuál toca en cada una (con el conjunto de pruebas de ese escenario, sin repetir la misma dos veces seguidas), y **se ve desde el principio**: en las etapas comunes el HUD dice "Próxima prueba: X (en N etapas)" (también en el casino) y en la prueba muestra su nombre y su efecto. Pruebas: Niebla, Oscuridad, Prisa, Sin ayudas, Todo o nada, Sin racha, Hielo total, Quebradizo y Polvorín (las tres últimas sesgan el generador). Las últimas pagan más claridad (×1,5 la primera, ×2,7 la última). Al superarlas dan claridad extra y un boost de regalo.
- **Habilidades persistentes** (`abilities.gd`): **no se compran** y desde la sección 31 **tampoco se ganan con las pruebas, sino por escenario** (las descripciones de abajo son de lo que hace cada una; la prueba con la que antes se ganaba ya no cuenta):  (Hielo total → *Garras de hielo*, poder colgarse de bloques de hielo; Quebradizo → *Fuerza bruta*, empujar pesados; Polvorín → *Mecha larga*; Niebla → *Mente despejada*, +25 de claridad al empezar; Oscuridad → *Ojos de gato*; Prisa → *Pies ligeros*; Sin ayudas → *Bolsillo de soñador*; Todo o nada → *Segunda oportunidad*, reintentos 15 % más baratos; Sin racha → *Racha firme*). Valen en todos los escenarios. La pantalla **Habilidades** del menú las lista (las que faltan dicen con qué prueba se consiguen).
- **Luz** (`profile.gd`, `user://profile.json`): al terminar un run se gana 3 por torre superada, 12 por prueba y 100 por escapar, multiplicado por el escenario. Una sola moneda: sirve sólo para entrar a los escenarios de pago.
- Generador: `opts.bias` ({kinds, plat_ice, cap_bonus}) viaja en el propio `RandomNumberGenerator` (meta) para no depender de estado global entre hilos.
- Los premios "bloqueados" de la primera versión del Despertar se quitaron (ya no hay tienda de mejoras).

- **La Luz es un ícono, no una palabra** (`luz_icon.gd`, `luz_counter.gd`): una esfera sombreada, como un sol en miniatura, que late y suelta partículas que salen disparadas y se apagan. Se usa en los contadores (selector de escenario, fin de run, habilidades), en el costo de las tarjetas y en el multiplicador; no hay texto que nombre la Luz en esas pantallas (hay un test que lo comprueba).

## 16. Tutorial narrativo: el tabernero

- **Inicio en la taberna**: "Tutorial" lleva a la taberna (la sala de las etapas 1 a 6, en modo historia). El tabernero (el crupier) cuenta el lore de la pesadilla (la torre hecha de recuerdos corruptos, la claridad, que él también subió y se quedó a cuidar la taberna, las 27 torres) y manda a la puerta de atrás. No se camina mientras habla; al terminar, la puerta de salida se marca con una flecha dorada que sube y baja. Chocar con la mesa no abre la ruleta (el tabernero avisa que primero la puerta). Al empujar la puerta empiezan las lecciones.
- **Cuadro de diálogo** (`dialogue_box.gd`): abajo, de cubitos, con la cara del tabernero a la izquierda, su nombre y el texto que se escribe letra por letra. Modo bloqueante (historias: Enter, Espacio, E o clic avanzan; Esc salta) y modo consejo (las lecciones: el texto se escribe solo, se queda mientras jugás y no pide nada). Una línea puede llevar un ícono (el sol o el rayo de la claridad) para hablar de la moneda sin escribir su nombre.
- **Lecciones en su voz** (`story.gd`): cada lección la dice el tabernero en el cuadro (ya no hay cartel arriba); la torre se sube un poco en la pantalla para que el cuadro no la tape.
- **Cierre en el salón de piedra** (etapa 7): al terminar la última lección el tabernero te recibe y explica la claridad y la ruleta, las pruebas cada 3 torres, las habilidades que se aprenden superándolas, la Luz (con su ícono) y los escenarios; después se vuelve al menú.
- Los textos de la historia están en `story.gd` (todo entra en 4 renglones del cuadro; hay un test que lo comprueba). `start_tutorial(index, skip_intro)` permite saltar la escena de la taberna.

## 17. Pantalla de Habilidades con íconos

- Cada habilidad persistente tiene su **ícono de cubitos 3D** (`ability_art.gd`): una figura de 9 × 9 que se extruye en profundidad (el borde 3 cubitos de espesor, el centro hasta 5) y se dibuja en isométrico **girando despacio**, como la Luz y la claridad: lamparita (Mente despejada), ojo de gato (Ojos de gato), bota alada (Pies ligeros), bolsita (Bolsillo de soñador), flecha que da la vuelta (Segunda oportunidad), llama (Racha firme), garras de hielo (Garras de hielo), bloque de hierro con flecha (Fuerza bruta) y bomba de mecha larga (Mecha larga).
- La pantalla (`meta_screen.gd`) es una grilla de casilleros con los íconos: las que no tenés se ven **grises y quietas**; las que ganaste, **a todo color, girando despacio, flotando, con un brillo que las cruza y chispas** (las grises también son 3D, pero no giran), sobre un marco dorado.
- Tocar un ícono abre su **descripción**: el nombre, si la tenés o no, qué hace, **cómo la conseguiste** (o cómo conseguirla: qué prueba la enseña) y **en qué escenarios sale esa prueba** (con el costo de entrada como sol). Funciona igual para las que no tenés.
- Consola dev: `set_luz <n>` fija la Luz del perfil (sirve en el menú y en el juego, y actualiza las pantallas abiertas).

## 18. Pantalla de carga con dados y cosméticos

- **Dados del tabernero** (`dice_game.gd`): en **toda** pantalla de carga (mientras se genera la torre y la espera pasa de ~0,8 s; si la torre ya estaba lista, ni se ve) aparece un minijuego de dados. Cada carga empieza con **3 tiros**, y cada tiro es una tirada nueva de **5 dados**: elegís qué cara va a salir en cada uno (clic en el dado o en sus flechas, rueda del mouse, o con el teclado izquierda/derecha para elegir el dado, arriba/abajo para cambiar la cara, 1 a 6 para fijarla y Enter para tirar), y al tirar ruedan y **se revelan de a uno** (verde si acertaste, rojo si no) con una frase del tabernero.
- **Premios**: 0 aciertos nada · 1: +2 de claridad · 2: +8 · 3: +25 · **4: +80 de claridad y 1 de Luz** · **5: un cosmético** (1 chance en 7.776 por tiro). El promedio es ~3 de claridad por tiro. La claridad que dan los dados tiene un **tope de 150 por partida** (`RunState.DICE_CAP`); la Luz no tiene tope. Si ya se tienen todos los cosméticos, los 5 aciertos dan 100 de claridad.
- **No bloquea nunca**: cuando la torre está lista, el tiro en curso termina (unos segundos como mucho) y el minijuego se cierra solo. Volver al menú lo cierra.
- **Cosméticos** (`cosmetics.gd`, `cosmetics_screen.gd`): 6 aspectos del personaje (Azul noche, Verde bosque, Dorado, Fantasma, Sombrero de copa y Corona) además del Clásico. Se eligen en el menú **Cosméticos** (casilleros con el personaje en 3D, gris con "?" los que no se tienen) y se ven en la torre y en el casino. Se guardan en el perfil.
- Para que entraran los 7 botones del menú principal se achicó un poco su tamaño.

## 19. Dados con caída y Empezar, y menú sin "Cómo jugar"

- **Los dados caen desde arriba**: al tirar, los 5 dados bajan desde arriba de la pantalla acelerando (cada uno aterriza un poco después que el anterior), pegan con un aplastón, **rebotan cada vez menos y se frenan**, deslizándose; mientras caen giran (cambian de cara cada vez más lento). Los dados son **todos blancos**, con un relieve redondeado en cada cara y los **puntos en las tres caras que se ven** (una orientación real de dado: las opuestas suman 7), con su sombra en la mesa. Al revelarse salta un poquito, y los aciertos sueltan chispas doradas.
- **Se juega con WASD** además de con las flechas y el mouse: A y D eligen el dado, W y S cambian la cara (1 a 6 las fijan, Enter tira) y **E** empieza cuando la torre está lista.
- **Botón "Empezar"** (a la derecha): la pantalla de carga ya no se cierra sola. Mientras la torre se genera, el botón está gris con una espiral de carga; cuando está lista se habilita y se puede seguir tirando hasta apretarlo (si hay un tiro en curso, termina antes de cerrarse). En las pruebas (`auto_start`) se cierra solo.
- **Menú principal**: se quitó "Cómo jugar" (de este menú y de la pausa): para eso está el tutorial, que ahora es **la primera tarjeta de "Nueva partida"** (gratis, con su "?"). Ya no hay un botón Tutorial suelto.

## 20. Generación con varios hilos y pantalla de carga directa

- La torre se genera con **varias semillas a la vez** (la mitad de los procesadores, de 1 a 4 hilos, `MAX_GEN_THREADS`): como el tiempo de una torre varía mucho de una semilla a otra, la primera que sale gana y frena a las demás con un testigo de cancelación propio de cada trabajo (`cancel_token`; la bandera global `Gen.cancel` sigue sirviendo para cancelar todo). Cada hilo usa `s + k * 7919`; la torre trae `seed_used` para poder reproducirla.
- Al entrar a la partida ya no aparece el cartel "Generando la torre...": si hay que esperar, **se abre directo la pantalla de los dados** (sin demora y sin ningún texto antes). Si la torre ya estaba generada de antemano, no se ve nada.
- No se agrega un aviso de "sin salida": si te quedás sin camino, es parte del juego tirarte al vacío o reiniciar.

## 21. Cosméticos con rareza y la trampa de los dados

- **Rareza de los cosméticos** (`cosmetics.gd`): común, raro y épico (13 en total). Comunes (6, sólo cambian el color): Azul noche, Verde bosque, Brasa, Turquesa, Rosa y Plateado. Raros (4): Dorado, Fantasma, Sombrero de copa y Gorro de brujo. Épicos (3): Corona, Halo y Obsidiana. Hay sombreros nuevos (gorro de brujo y halo flotante). La pantalla de Cosméticos muestra una barra con el color de la rareza en cada casillero, cuántos tenés de cada una y el nombre del elegido con su rareza.
- **Premios de los dados** (`dice_game.gd`): 0 aciertos nada · 1: +2 de claridad · 2: +8 · **3: +25 de claridad y 1 de Luz** · **4: +80, 2 de Luz y un cosmético común (85 %) o raro (15 %)** · **5: +150, 5 de Luz y un cosmético raro (70 %) o épico (30 %)**. Si de la rareza que toca ya los tenés todos, sale de otra; si ya tenés todos, 100 de claridad. La claridad de los dados sigue con tope de 150 por partida; la Luz y los cosméticos no.
- **La trampa**: con los dados ya revelados, si algo falló y te alcanza la Luz, se abre una pausa (botón "Cobrar") en la que cada dado que falló muestra cuánto cuesta amañarlo (con el sol): **2 el primero, 3 el segundo, 4 el tercero...** (sube con cada uno y vuelve a empezar en cada tiro). Un clic (o W, o Espacio, con A y D para elegir) lo cambia por la cara que habías pedido y se vuelve violeta. Con Luz de sobra se compran los cinco (2 + 3 + 4 + 5 + 6 = 20). Si amañás todos, se cobra solo; con Enter o "Cobrar" se cobra lo que hay, y "Empezar" también cobra y cierra. Arriba a la derecha se ve cuánta Luz tenés. Si no te alcanza para el primero, el tiro se cobra enseguida sin pausa.

## 22. Opciones, idiomas y semillas reproducibles

- **Pantalla de Opciones** (`options_screen.gd`, desde el menú principal y desde la pausa): idioma (Español / English), ventana o pantalla completa, resolución (1280x720 hasta la que entre en el monitor; en pantalla completa se apaga), sincronía vertical y volumen general (10 pasos). Cada cambio se aplica y se guarda al instante en `user://settings.json` (`settings.gd`). La primera vez el idioma sale del sistema. El proyecto estira la interfaz (`canvas_items`, `expand`) para que se vea igual en cualquier resolución.
- **Tabla de idiomas** (`loc.gd`, `loc_en*.gd`): la CLAVE es la frase en español. `Loc.t("Nueva partida")` la traduce; los textos con datos van como patrón (`Loc.f("Etapa %d/%d", [n, total])`). Las etiquetas y botones de cubitos traducen solos lo que reciben (`Loc.auto`), así que los textos fijos no hay que tocarlos. Lo que falta traducir se muestra en español. Para sumar un idioma: un archivo `loc_xx.gd` con su tabla y una línea en `Loc.LANGS`.
- `tests/test_loc.gd` revisa que cada frase pedida con `Loc.t/f`, cada nombre/descripción del catálogo, la historia y el tutorial estén en la tabla, y recorre las pantallas en inglés sin que quede nada sin traducir (con `LOC_PRINT=1` imprime lo que falta).
- **Semillas reproducibles**: antes el tope de tiempo del generador (ms) cortaba la búsqueda según la velocidad de la máquina, y la misma semilla daba torres distintas. Ahora el tope se mide en trabajo del solucionador (`budget_states`), así que la misma semilla (con la misma etapa, escenario y prueba) da siempre la misma torre. `tests/check_seed.gd` genera una semilla y reproduce su camino.

## 23. Cámara libre en el casino y mecánicas nuevas (fila, trampa, pinchos)

- **Casino**: la cámara gira e inclina igual que en la torre: arrastrar con el mouse, flechas (izquierda y derecha giran, arriba y abajo inclinan; ya no mueven al personaje: W A S D), rueda para el zoom. Q y E vuelven a la diagonal isométrica y giran 90 grados.
- **Empujar una fila** (`TowerLogic._push_row`): si detrás del bloque que empujás hay otros pegados, se mueve toda la fila (hasta 3) siempre que la celda de más allá esté libre y ninguno sea fijo ni pesado. Una fila no resbala (el hielo sólo se desliza si va solo). Tirar sigue siendo de a un bloque.
- **Trampa** (`Kind.TRAP`): parece un bloque común pero tiene una cruz roja hundida arriba (siempre visible, también corrupta). Al quedar parado sobre ella se desarma y el jugador cae con ella (sobre otro bloque, o al vacío si abajo no hay nada). Empujarla, tirarla o colgarse de su borde no la activa. En las torres aparece como celda de plataforma (hasta 2 por plataforma) desde la dificultad 0,30 (etapa ~9).
- **Pinchos** (`Kind.SPIKES`): bloque de acero con cinco púas plateadas; quedar parado encima (trepando, bajando o cayendo sobre él) pierde ("Caíste sobre los pinchos"). Se pueden empujar y tirar como un bloque común. En las torres aparecen como celda de plataforma (1 por plataforma) y como obstáculo desde la dificultad 0,35 (etapa ~10). El solucionador sigue garantizando que cada fila tenga camino.
- El tutorial suma tres lecciones (Fila de bloques, Trampa, Pinchos) antes de "Una torre de verdad", cada una con su texto del tabernero y su traducción.

## 24. Tragamonedas, blackjack y sonido

- **Tragamonedas con retener** (`slots.gd`, `slots_screen.gd`): se choca contra una máquina del casino. Se paga una ficha (la misma de la ruleta) y giran tres rodillos con cinco símbolos (cubo, hielo, bomba, sol y corona; pesos 7/5/3/2/1). Después se puede, **una vez**, retener los rodillos que se quieran (teclas 1, 2, 3) y volver a girar los otros por **media ficha**, o cobrar lo que hay (Enter). Pagan dos iguales (cubo ×0,3 · hielo ×0,5 · bomba ×0,9 · sol ×1,4 · corona ×2,5) y tres iguales (×2 · ×4 · ×9 · ×20 · ×50, y tres coronas dan además un boost épico). Rendimiento con la mejor estrategia ≈ 0,915 (lo vigila `tests/test_games.gd`). Los pagos son en claridad y cuentan en las estadísticas del casino.
- **Blackjack** (`blackjack.gd`, `blackjack_screen.gd`): mesa de cartas de los casinos grandes. Un mazo de 52 (palos = cubo, hielo, bomba, sol) que se baraja en cada mano; apuesta de una ficha; Pedir (Espacio), Plantarse (Enter), Doblar (D, con las dos primeras cartas). El crupier pide hasta 17 y se planta en todos los 17. Blackjack paga 3 a 2, ganar 1 a 1, empate devuelve la apuesta. Sin dividir ni seguro. Con una estrategia simple rinde ≈ 0,99. En el tutorial las mesas y máquinas siguen cerradas (el tabernero lo avisa).
- Las máquinas y la mesa del casino ya no están tapadas: las máquinas tienen sus tres ventanitas de rodillo y la mesa, el fieltro con cartas y fichas.
- **Sonido y música, todo sintetizado por código** (`synth.gd`, `sfx.gd`, `music.gd`, `audio_hub.gd`): `Sfx.play("nombre")` con ~30 efectos (pasos, empujar, tirar, trepar, colgarse, purificar con tono que sube con la racha, resbalar, catapulta, trampa, pinchos, caída, explosión, ruleta, dados, rodillos, cartas, monedas, clics de menú, el "blip" del tabernero al hablar...). Tres pistas de música en bucle armadas en un hilo la primera vez (menú, torre, casino) con fundido al cambiar. Buses "Musica" y "Efectos" con sus volúmenes en Opciones (más el general). Sin pantalla (pruebas) no suena nada. Para reemplazar cualquier sonido por un archivo real basta ponerlo en `res://audio/sfx/<nombre>.ogg|wav` o `res://audio/music/<pista>.ogg|wav`.

## 25. Personajes animalitos y ropa

- **Personajes** (`characters.gd`): el cubo con nariz se reemplaza por cuatro animalitos de voxels (cabeza grande, torso chico, patitas y bracitos que se balancean al caminar, cola): **Gatito** (el de siempre), **Perrito**, **Conejito** y **Pingüino**. Todos juegan igual; sólo cambia el aspecto. El modelo mide ~0,75 con los pies en el origen y mira hacia +Z; tiene una copia de silueta (se ve a través de las plataformas).
- **Desbloqueos**: el Perrito al superar tu primera prueba; el Conejito al llegar a la etapa 10; el Pingüino al superar la prueba del Hielo total (la de la habilidad Garras de hielo). Al desbloquear uno el juego avisa ("¡Personaje nuevo: ...!"). Los desbloqueos y el personaje elegido se guardan en el perfil (`Profile.on_trial_cleared / on_ability / on_stage_reached`).
- **Ropa** (`cosmetics.gd`): dos huecos, **gorro** y **prenda**, que se combinan con cualquier animalito. 13 piezas, con las mismas rarezas y los mismos premios de los dados: comunes (6): Gorra, Gorro de lana, Cinta, Bufanda, Remera, Mochila; raros (4): Sombrero de copa, Gorro de brujo, Capa, Chaleco dorado; épicos (3): Corona, Halo, Armadura de obsidiana. Los cosméticos viejos (colores del cubo) se pasan solos a su equivalente (el perfil guardado se migra al cargarlo).
- **Pantalla Personaje** (antes Cosméticos): el animalito grande girando a la izquierda y, a la derecha, solapas Personajes / Gorros / Ropa con casilleros con miniatura 3D (en gris con "?" lo que no se tiene; al pasar el mouse dice cómo conseguirlo). Un clic elige un personaje o pone/saca una pieza.

## 26. Ajustes de la bomba, la catapulta y el casino

- **Lección de la bomba**: la bomba está sobre el piso, a la altura del jugador (así su cuenta baja con cada movimiento), a exactamente 3 movimientos (dos pasos y subirse encima) y con cuenta 3: perder un solo movimiento o retroceder la hace explotar. Subirse encima la desactiva. Si explota hay animación (destello naranja que crece, llamas y escombros que salen disparados, sacudón y destello de pantalla) además de la caída de la torre.
- **Sonidos de la bomba**: al desactivarse suena una mecha que se apaga (`defuse`), y mientras haya una bomba con cuenta a la vista suena un tic-tac (`tic`/`tac`) que se acelera cuanto menos le queda.
- **Catapulta**: además de las 4 celdas que sube, busca de dónde agarrarse hasta 2 celdas más arriba (si el camino está libre) y se agarra del borde más alto que alcanza (antes sólo miraba a la altura exacta del punto más alto y, si no había borde, volvía a caer).
- **Casino**: tiene la misma rosa de los vientos que la torre (arriba a la derecha): al girar la cámara las letras W A S D cambian de eje, así no hay que adivinar para dónde va cada tecla.

## 27. Dados: retener y volver a tirar (reemplaza a la trampa)

- Después de ver un tiro, con Luz y re-tiradas disponibles se abre una pausa: los dados que acertaron quedan **retenidos** y de los que fallaron se elige cuáles **volver a tirar** (por defecto todos los que alcanza la Luz; tocar uno lo retiene, con un candado). Cada dado que se vuelve a tirar cuesta **1 de Luz** y acierta con probabilidad 1/6: no hay garantía. Hasta **2 re-tiradas por tiro**. Botones "Tirar de nuevo (−N Luz)" y "Cobrar"; teclas: A/D eligen, W o Espacio marcan, Enter vuelve a tirar, C cobra. Constantes: `DiceGame.REROLL_COST` y `MAX_REROLLS`.
- Los dados que ruedan de nuevo caen otra vez con la animación; los retenidos siguen quietos a la vista. Si se llega a los cinco se cobra solo; si se acaban las re-tiradas o la Luz, también.

## 28. El laboratorio (modo dev)

- Sólo en compilaciones de desarrollo (nunca en la exportación release). Comandos de la consola (F1): `lab [n|id]` entra al laboratorio o salta a otra estación, `labs` las lista, `spawn <tipo> [cuenta]` pone un bloque delante del personaje (normal, hielo, bomba, catapulta, agrietado, pesado, trampa, pinchos, fijo), `perk <id>` activa o saca un boost o habilidad (por ejemplo `perk fuerza_bruta`), `collapse on|off` enciende o apaga la caída de la fila de abajo. R reinicia la estación, gratis, con los perks activos. Salir: Esc, menú.
- Hay una **estación por bloque o mecánica** (`lab.gd`): común (empujar, tirar, filas de 2, 3 y 4), hielo, bomba, catapulta (paredes de 5, 7 y 10), agrietado, pesado, trampa, pinchos, fila de bloques, colgarse, bloque fijo y combinaciones. Cada una tiene su cartel 3D que dice qué probar. Se carga **una estación a la vez**: las bombas cuentan en todo el mundo cuando estás a su altura, así que varias juntas se pisarían.
- `tests/test_lab.gd` comprueba que cada estación se arma bien (sin bloques fantasma, dentro de su franja, con piso bajo el arranque) y que se comporta como dice su cartel; así cualquier cambio en las reglas que rompa un bloque se nota.
- **Boosts, habilidades y consumibles en el laboratorio**: `give <id>` da un consumible (hay casilleros de sobra; se usa con las teclas 1-4) o un boost (se aplica enseguida: reinicia la estación). `perk <id>` prende o apaga un boost sin gastar casillero (por ejemplo `perk reflejos`, `perk aire_extra`) y también reinicia la estación, porque varios boosts cambian números al armar la torre. `ability [id]` prende o apaga una habilidad persistente (`ability garras_de_hielo`, `ability mente_despejada`...; sin id las lista con una marca en las prendidas). En el laboratorio no valen las habilidades del perfil real, sólo las que prendas a mano: así lo que probás no depende de qué hayas ganado jugando.

## 29. Opciones: pestañas, controles y gráficos

- **Pantalla de Opciones** (menú principal y pausa): cuatro pestañas **General** (idioma), **Gráficos**, **Sonido** y **Controles** (Q/E o LB/RB cambian de pestaña). Cada una se desplaza con la rueda si no entra, y tiene su botón **Restablecer** (menos General). Todo se aplica y se guarda al instante en `user://settings.json`.
- **Gráficos** (`graphics.gd`): arriba, pantalla (ventana o completa), resolución y sincronía vertical; después **Calidad** con preajustes Alta / Media / Baja y ajustes sueltos: sombras (no, duras, suaves), partículas de los bloques (no, pocas, todas), escala de render (50-100 %), suavizado de bordes (no, 2x, 4x), silueta del personaje tras las paredes, destellos y temblores, límite de FPS (30, 60, 144, sin límite). Tocar un ajuste suelto pasa a "Personalizada" (si los valores vuelven a coincidir con un preajuste, se lo nombra). "Baja": sin sombras, sin partículas, escala 70 %, sin suavizado. En pantalla completa la **resolución** es la del render (el juego se dibuja a esa altura y se estira a la pantalla).
- **Controles** (`controls.gd`): todas las acciones del juego tienen nombre, tecla y entrada del mando, y se reasignan. Si la tecla o el botón ya los usaba otra acción, se **intercambian** y se avisa. Los cambios se guardan en la clave `bindings`. Mando de fábrica: stick izquierdo mueve (relativo a la cámara, como WASD), stick derecho gira e inclina la cámara, LT empujar/tirar, X colgarse, RB/LB vista, Start pausa, Select reintentar; A confirma y B vuelve en los menús.
- **Mando** (`pad_bridge.gd`): cada botón o eje del mando se traduce a la tecla de la acción que tiene asignada y se inyecta como evento de teclado; así todas las pantallas (torre, casino, dados, tragamonedas, blackjack, menús) funcionan igual con teclado y con mando. En menús y juegos del casino el stick izquierdo y la cruceta mueven con las flechas.
- Limitación conocida: los textos de ayuda del tutorial todavía nombran las teclas por defecto (W, A, S, D...), no los botones del mando.
- Medición (`tests/bench_graphics.gd`): en la máquina de desarrollo el juego va a la frecuencia de la pantalla en cualquier preajuste (la escena es liviana); lo que sí baja son las llamadas de dibujo (302 → 123 en Baja). Los preajustes están pensados para GPUs integradas, que no se pudieron medir todavía.

## 30. Dados: una predicción y 3 tiradas (reemplaza a la sección 27)

- Cada carga es **una sola predicción** (la cara que va a salir en cada uno de los 5 dados) y **3 tiradas** para cumplirla. La primera tirada rueda los 5 dados; los que acertaron quedan **retenidos** (verdes, con un candado) y las siguientes tiradas sólo vuelven a rodar los que **fallaron** (Enter, Espacio o el botón "Tirar de nuevo"). No cuesta Luz: la Luz sólo es premio. Si se acierta todo antes, se cobra enseguida; si se acaban las tiradas, se cobra con los aciertos que haya. Pedir Empezar con una tirada pendiente cobra lo que hay.
- Cada dado se acierta con probabilidad 1/6 por tirada, así que en 3 tiradas con 42 %. Aciertos: 0: 6,5 % · 1: 23,6 % · 2: 34,4 % · 3: 25,0 % · 4: 9,1 % · 5: 1,3 %.
- **Premios** (se cobran una vez, al final): 0 o 1 acierto, nada · 2: +8 claridad · 3: +25 y 1 Luz · 4: +80, 2 Luz y un cosmético común (o raro) **con 15 % de chance** (`cosmetic_chance`) · 5: +150, 5 Luz y un cosmético raro o épico seguro. Un cosmético sale en ~2,7 % de las cargas y la claridad promedio es ~18. La claridad de los dados sigue con tope de 150 por partida.


## 31. Los casinos se diferencian: reglas, servicios, balance y habilidades por escenario

- **Las mesas por nivel** (`Room.layout`): la taberna (primer casino) sólo tiene la ruleta y una tragamonedas, sin mesa de cartas ni estación de servicio; el salón suma una segunda tragamonedas y una mesa de blackjack; el casino y el gran casino, más.
- **Reglas de la casa** (`casino_rules.gd`, estado en `run.casino_visit`, uno por visita): **Taberna: Fiado** (la primera pérdida de la visita devuelve la mitad) · **Salón: Racha** (+10 % por cada victoria seguida sobre la anterior, tope +50 %) · **Casino: Apuesta libre** (1, 2, 3 o 5 fichas juntas en tragamonedas y blackjack; la ruleta sigue con una) · **Gran casino: Jackpot** (la mitad de lo perdido va a un pozo que se lleva el premio mayor: pleno, tres coronas o blackjack). Cada pantalla de juego muestra el renglón de la regla y los avisos de lo que pagó (`casino_rule_ui.gd`).
- **Servicios** (`casino_services.gd`, pantallas en `casino_service_screens.gd`; una estación-mueble por sala, salvo en la taberna; se choca como con las mesas): **Taller** (salón: vende un ítem por 40 % de su valor, o lo cambia por otro del mismo nivel por 30 % de la ficha; no deja vender un boost que agranda las barras si lo demás ya no entraría) · **Caja fuerte** (casino: se guarda claridad y se cobra con 15 % de interés en el casino siguiente; no sirve para reintentar mientras está guardada; se puede retirar sin interés) · **Seguro** (gran casino: 60 % del primer reintento de la próxima torre, que sale gratis; expira al llegar al casino siguiente). `run.vault`, `run.vault_stage` y `run.insurance` se guardan con el run. En el tutorial las estaciones están cerradas.
- **Balance del casino** (`casino_balance_screen.gd`): al salir, antes de la torre siguiente (mientras se genera), tabla por mesa con partidas, ganadas, perdidas, gastado, ganado y neto, más entrada y salida de claridad, mejor jugada, datos de la regla (mejor racha, pozo sin cobrar, fiado), la caja fuerte y el seguro. Las estadísticas se anotan en `CasinoRules.settle(..., game)`.
- **El HUD del casino** tiene un solo contador (la claridad que tenés); ya no muestra el precio de la ficha.
- **Habilidades persistentes por escenario** (`Scenarios.abilities`): se ganan **al escapar de la pesadilla** (terminar las 27 etapas) en ese escenario, una por vez y al azar entre las que todavía no tenés; cuando no quedan, da **Luz** (`Profile.ABILITY_LUZ` = 30 × el multiplicador del escenario). La Pesadilla: Mente despejada, Ojos de gato, Racha firme · Glaciar: Garras de hielo · Ruinas: Fuerza bruta · Polvorín: Mecha larga · Relojería: Pies ligeros · Gran Casino: Bolsillo de soñador, Segunda oportunidad. Las pruebas siguen dando claridad extra y un boost, pero ya no habilidades.
- **Los dados van siempre** (`main.dice_always`): aparecen en toda pantalla de carga, también cuando la torre ya estaba generada (con Empezar habilitado desde el primer momento): son parte del juego, no un relleno de la espera. Las pruebas lo apagan.

## 32. Generación más rápida y tamaño de interfaz

- **Medición** (etapa 24, una semilla a la vez en un procesador de 8 núcleos): 80-210 s por semilla antes; el solucionador era el 92 % del tiempo. Dos cambios, sin alterar el resultado (misma semilla, mismos estados: se comprobó): (1) `TowerLogic.clone()` ya no copia los diccionarios de bloques; se comparten hasta que una copia escribe (`_own_maps`); (2) `lazy_settle`: el solucionador y el generador sólo revisan qué bloques caen cuando algún bloque se movió o se sacó (caminar, trepar y colgarse no mueven bloques), con el cuidado de los bloques que sólo se sostienen sobre el jugador. Resultado: 60 s y 34 s para dos semillas que tardaban 138 s y 83 s (≈ 2,3 veces más rápido). `Solver.total_usec` mide el tiempo del solucionador.
- **Tamaño de la interfaz** (Opciones > General): 80, 90, 100, 110 o 125 %, aplicado con `content_scale_factor` a todo lo 2D. Las Opciones se adaptan al espacio disponible y la pestaña se desplaza.

## 33. Las mesas se purifican con los casinos (estética por nivel)

- `casino_theme.gd` define un estilo por nivel de sala, con suciedad (`corruption`), decoración fija (`ornament` 0-3), animación (`shine` 0-3) y los colores de cada pieza. Las tres mesas lo leen según el nivel donde se juega (`CasinoTheme.for_run`; también con el escenario Gran Casino). Todo con cubitos, sin assets nuevos.
- **Taberna**: lo de siempre (bordes rotos, chorreras violetas, bronce opaco; cartas manoseadas con manchas, paño verde turbio con manchas y quemaduras). **Salón**: madera barnizada y latón, tachuelas sueltas, suciedad media-baja. **Casino**: madera oscura pulida, filetes dorados, gemas rojas en las esquinas, luces que corren por los marcos y chispas al ganar, rombos dorados en el dorso de las cartas. **Gran casino**: aro de marfil con tachas y gemas azules, casillas marfil y carmesí, corona de cubitos en el centro de la rueda, marcos de oro con luces que corren, brillo que cruza las ventanillas y las cartas, cartas con borde dorado, filete interior y rombos, paño esmeralda con guarda dorada, y una lluvia de chispas más grande al ganar.
- **Ruleta**: aro, casillas, separadores, marcador, bola y fichas con el material del nivel; titilan cubitos del aro y las fichas desde el casino. **Tragamonedas**: marco de cada rodillo recoloreado y ornamentado (`CasinoTheme.frame`), ventanillas más limpias. **Blackjack**: paño propio (`_Felt`), frente y dorso de las cartas por nivel.
- **Interfaz del casino**: mientras se está en una sala (menos en el tutorial) los botones y textos de cubitos se limpian con la misma escala (`CasinoTheme.apply_ui`; se restablece al salir): también se nota en el balance y en las estaciones de servicio. La regla de la casa de la ruleta ahora está al lado de la claridad, arriba.
- La animación extra se redibuja ~8-12 veces por segundo y sólo en los niveles altos; en la taberna y el salón no hay nada animado de más.

## 34. Casino y gran casino: mármol cálido

- El casino (nivel 2) y el gran casino (nivel 3) tenían una paleta que se aclaraba hasta casi blanco más una luz ambiente de 1,5: se quemaban y los detalles desaparecían. Ahora cada uno tiene una paleta propia de **mármol cálido** (`Room._warm_look`): paredes arena y crema, piso en damero marfil y pizarra (casino: arena y chocolate) con mucho contraste, columnas marfil, oro más oscuro, felpa verde o turquesa y alfombra terracota; dentro de cada nivel sólo hay un cambio mínimo de etapa a etapa (±4 %). La taberna y el salón no cambian.
- **Luz**: en el casino y el gran casino la luz ambiente es 1,0 y cálida, el sol baja a 0,6 y el fondo es casi negro (`CASINO_AMBIENT_WARM`, `CASINO_SUN_WARM` en `main.gd`); se restablece al volver a la torre. `Room.look(stage, tier)` toma el nivel de la sala (también con el escenario Gran Casino).


## 35. Consumibles nuevos, vidas, Dante y Gaby, Compromiso

- **Consumibles**: 8 conversores (uno por tipo de bloque), Tótem (revive gratis), Escudo (absorbe la próxima bomba), Doble salto (sube un pilar de 2), Teletransporte (se elige con el mouse un cubo a ≤5 de distancia) y Vida extra. Se tiran con clic derecho (sin recuperar dinero).
- **Vidas**: 3 corazones 3D abajo a la derecha; cada muerte con reintento gasta uno (4 con la habilidad *Corazón extra*). Vida extra sólo sirve si falta alguna.
- **Personajes**: Dante y Gaby vienen desde el principio; el gatito (etapa 4) y el conejito (etapa 10) se desbloquean.
- **Compromiso** (escenario): una sola vida, morir termina la partida, sin Tótems ni Vidas extra. Recompensa: la habilidad persistente *Corazón extra*.

## 36. Prueba «Lluvia de meteoritos»

- Cada movimiento del jugador destruye el bloque que estaba **marcado** (parpadea en rojo) y marca el siguiente; el meteorito se ve caer y chocar (`main._meteor_impact`).
- **Camino garantizado** (`meteors.gd`): se repite la solución de la torre y se protegen los bloques que usa (donde pisa, de donde cuelga, los que mueve, los que se rompen y los que miran los deslizamientos). Además un bloque sólo se elige si, al caer, no mueve al jugador ni a un bloque protegido (`TowerLogic._meteor_safe`). La solución se guarda con la partida.
- Está en los sorteos de La Pesadilla, Relojería, Compromiso y Gran Casino. Test: `tests/test_meteors.gd`.

## 37. Modo de lectura y alto contraste

- Opciones → General → *Modo de lectura*: letras sin corrupción, más claras y con contorno oscuro; no cambia el tamaño de la interfaz, que es otra opción (`VoxelDraw.reading`, `Settings.reading_mode`).
- *Alto contraste* (aparte): cartas más oscuras con borde claro y sin ruido, y la escena con más contraste y saturación (`VoxelDraw.high_contrast`, `Settings.high_contrast`, `Main.apply_graphics`).

## 38. Tutorial reducido a las mecánicas

- **Flujo de cada lección**: el tabernero cuenta sólo lore (sin hablar de teclas; cualquier tecla cierra su ventana) y entonces aparece arriba, en su lugar, la **ayuda**: una frase simple con las teclas dibujadas adentro (`key_hint.gd`), por ejemplo «Mantené [Shift] y pulsá [W] [A] [S] [D]». Las teclas están grises y se doran al usarse bien (los nombres son los de los controles del jugador). Si se llega a la meta sin haber usado las teclas obligatorias no se avanza: la lección se reinicia conservando las doradas.
- **Lecciones** (7, sólo mecánicas, sin hablar de tipos de bloque): 1 moverse (sendero en S que obliga a las 4 teclas), 2 cámara (flechas; la escalera tapa al personaje), 3 empujar (escalera armada empujando bloques), 4 tirar (un bloque suelto: alcanza con tirar de él una vez; empujarlo no cuenta, el tutorial distingue empujar de tirar con `TowerLogic.last_grab`), 2 cámara pasa a ser el personaje solo sobre un bloque que se completa al tocar las 4 flechas, 5 cornisa (S de columnas de hierro de 2 de alto que sólo se tocan en diagonal: hay que colgarse y desplazarse; plataforma de salida ancha para probar Espacio + cualquier dirección), 6 soltarse (la torre alta; se suelta con Espacio), 7 torre generada (el tabernero explica los dados mientras se genera).
- **Colgado**: ir en la dirección contraria al bloque ya no suelta (sólo gira hacia el bloque); se suelta apretando Espacio (`TowerLogic.release_hang`, `release_with_opposite`). El solucionador conserva la regla vieja.
- **Dados**: jugar es obligatorio; «Empezar» aparece al terminar las tiradas. Se eliminó el texto «Elegí qué cara…» (lo explica el tabernero en el tutorial).
- **Guardado**: al morir se guarda al instante y al continuar cuenta como reintento después de morir (gasta una vida); Alt + F4 también guarda.

## 39. Guía de bloques y descubrimiento

- Como el tutorial ya no enseña tipos de bloque, hay una **guía de bloques** (menú principal y menú de pausa; `block_guide.gd`, `block_guide_screen.gd`) con el bloque en 3D girando (el mismo modelo de minibloques y el mismo shader que en la partida), nombre y descripción por tipo: bloque corrupto, hielo, pesado, agrietado, bomba, trampa, pinchos y catapulta.
- **Descubrimiento**: un bloque se descubre la primera vez que el jugador llega a la altura de una fila que lo contiene (que exista en la torre no alcanza: `BlockGuide.newly_reached`). En ese momento el juego frena (cuadro de diálogo bloqueante) y el tabernero explica sus características; después se sigue. Se guarda en el perfil (`blocks_seen`) y vale para siempre; no se descubre nada en el tutorial ni en el laboratorio.
- En la guía los bloques sin descubrir salen en gris y sin nombre ni descripción: sólo dicen «Por descubrir».

## 40. Balanceo: 15 etapas, escalera de bloques y situaciones

- **15 etapas** en todos los escenarios (`stages.gd`): salas 1-3 taberna, 4-7 salón, 8-11 casino, 12-15 gran casino; pruebas en 3, 6, 9, 12 y 15. Economía reescalada: ficha de la ruleta 50 → 106 (`PRICE_STEP` 4), reintento 25 + 2 por etapa, Luz 5 por torre y 20 por prueba, recompensa en claridad 40 + 18 por etapa.
- **Escalera de bloques** (por dificultad `(etapa-1)/14`): hielo en la etapa 2, pesado 3, agrietado 4, trampa 5, pinchos 6, bomba 7 (`ICE_FROM`... `BOMB_FROM` en `tower_gen.gd`).
- **Situaciones** (`_feature_plan`, `_seed_featured`, `_kind_matters`): cada tipo desbloqueado tiene 1 a 2 filas donde tiene que importar; el más nuevo debuta en las primeras filas. Una fila «situación» siembra ese bloque (en la plataforma o en los accesos) y el generador sólo la acepta si el camino que se obtiene tratando ese bloque como común falla sobre la fila de verdad. Respeta el tope de especiales por fila. `opts.situations = false` las apaga.
- **Comando de desarrollo** `tower <etapa 1-15> [escenario] [semilla]` (consola F1, también desde el menú principal): una partida nueva en esa etapa y escenario, sin pagar la entrada; con semilla se genera con un solo hilo y es reproducible. Sirve para probar el generador.

## 41. Torres por situaciones (rooms.gd)

- **`scripts/rooms.gd`** genera las torres del juego (el generador fila a fila, `tower_gen.gd`, queda para sus tests y utilidades: `_close_tower`, `_window`, perfiles de etapa). Una torre de `rows` pisos son `(rows - 1) / 4` **salas de 4 pisos** alrededor del core (fijo, de arriba a abajo), una atrás de la otra, más un tramo corto (1 a 4 pisos) hasta el portal (bloque fijo). Cada sala es una **idea** escrita a mano (una situación con premisa, técnica y giros) sobre su propia plataforma, con vacío alrededor: la torre sigue siendo una columna de bloques y plataformas.
- **Orden tipo Spelunky**: primero se decide la secuencia de salas (`Rooms.plan`) y después se arma cada una (`place_room`): se sortea un candidato de la idea y su variante, se arma la plataforma que necesita (`_footprint`: lo que la idea usa, un margen para pararse y empujar y un camino a la llegada) y se lo verifica con el solucionador.
- **Catálogo** (`Rooms.IDEAS`): muro simple (etapa 1, sólo bloques comunes), hielo y freno, pista de hielo (resbalones que terminan en precipicio), hielo y billar, pared pesada, cruce agrietado, pared de pinchos, campo de trampas, cuenta de bomba y trampolín. Cada una declara `tier`, bloque que la desbloquea (los mismos de la escalera de bloques), movimientos base, si exige empujar, si tiene que castigar el error y sus `twists` (giros).
- **Escenarios**: cada escenario tiene su catálogo (`Rooms.SCENARIO_IDEAS`; el Glaciar usa sólo las de hielo desde la primera etapa). Los que no tienen uno propio (la Pesadilla, por ahora todos los demás) usan todas las ideas con la escalera de bloques: hielo en la etapa 2, pesado 3, agrietado 4, trampa 5, pinchos 6, bomba 7, catapulta 8. Para copiar la fórmula a otro escenario alcanza con agregarle su lista (y, si hace falta, ideas nuevas).
- **Plan**: la primera sala es un respiro corto; las ideas suben de tier con la dificultad y con la altura en la torre; no se repite la idea de la sala anterior ni el mismo giro de una idea dos veces seguidas; si una idea no entra se prueban las otras (primero las que menos salieron) y, al final, un respiro.
- **Filtro de calidad** (`_commit`): se resuelve en el rango de movimientos (`base + 3 * dificultad + sala / 4`, ancho 25); la solución usa lo que la idea promete (`_uses_idea`: mueve los pinchos, gasta el agrietado, mueve el freno y resbala, resbala el hielo contra los topes, dispara la catapulta, desactiva la bomba, mueve un bloque suelto del muro...); sin empujar ni tirar no se pasa (en las ideas que exigen mover); desde la dificultad 0,2 las ideas que castigan tienen que tener errores sin salida (`_error_cost`: de las alternativas en pasos repartidos de la solución, qué fracción pierde o queda sin salida); casi todo el recorrido se ve desde alguna diagonal de la cámara (`_visible_fraction`, nada de jaulas); nada de lo armado cae solo; el camino anterior sigue valiendo y la salida deja lugar para la sala que sigue.
- Detalles de las ideas: la pista de hielo se arma de adelante para atrás siguiendo una secuencia de resbalones (con los topes que la hacen posible), así siempre tiene solución; la cuenta de la bomba se fija con lo que tarda el camino más corto por el laberinto (+2 o +3: la acción con que se llega ya cuenta una vez); el hielo y freno tiene el pasillo hundido en el piso, con paredes de 3 de alto (si no, parado sobre el freno se caminaría por arriba).
- Medido (un hilo): torres de 25 pisos de 1 a 30 s; en el juego corren varias semillas y gana la primera.
- **Pendiente**: reequilibrar la claridad, el contador de pisos (hay una plataforma por sala), el sesgo de bloques de otros escenarios y de las pruebas, ideas para los demás escenarios, y salas grandes (6 a 7 pisos).

## 42. Portal de salida y peaje del duende

- La salida de cada torre es un portal de ondas (`shaders/portal.gdshader`, dos paños cruzados) con un duende voxel (`scripts/goblin.gd`) al lado. Ya no hay rayo.
- El duende cobra `RunState.toll_for(etapa)` (`40 + 4 × etapa`, ~¼ de lo que rinde el camino óptimo) para encender el portal. Se paga con la claridad que traés más la que juntaste en la torre (`TowerLogic.wallet + claridad`).
- Si llegás al portal sin poder pagar, el portal sigue apagado (`toll_blocked`), un aviso dice cuánto falta y la torre sigue: hay que volver a juntar claridad o el suelo cae.
- Al salir se descuenta el peaje de la claridad del run (`_bank_claridad`). El costo se ve en la ventana de la partida (torre) y, en el casino, el de la próxima torre.
- En el tutorial, el laboratorio y las pruebas automáticas (`test_mode`) no se cobra (salvo `toll_in_tests`).
- El hielo que sigue hasta el borde del tablero o hasta un hueco sin apoyo hace caer al jugador (`_slide`, `_settle_player`).

## 43. Salas de cajas (taller)
- Sala de **2 pisos** (`taller` en `scripts/rooms.gd`), desde dificultad 0,25. Una arena de 12 a 25 celdas (rectángulo de 4x3 a 5x5, a veces unido a la llegada por un pasillo de hasta 4 celdas)
  con **muros pesados de 3 de alto** (no se trepan ni se mueven), **cajas** comunes (1 a 4) y un **pilar de 2** que es la salida: sólo se sube si hay una caja en su única celda libre `T`
  (el tope del pilar es un bloque fijo). Hay que traer una caja hasta `T` empujando y tirando entre muros, sabiendo qué caja usar y en qué orden.
- Se genera **mirando todo**: se arma la arena resuelta (caja en `T`, jugador en la cima del pilar), se exploran todos los estados que se alcanzan con movimientos que se pueden deshacer (hasta 6000)
  y se elige el comienzo con el camino más corto más largo, con más agarres (Dijkstra exacto dentro de esos estados). Entre 12 disposiciones de muros/cajas se queda la mejor.
  El camino se guarda (no se vuelve a buscar) y se comprueba rejugándolo en la torre real. Salen acertijos de 17 a 35 movimientos con 5 a 13 agarres por sala.
- La arena se simula sola (`_taller_mini`) pero copiando lo que ya hay alrededor en la torre (el core, las salas de abajo) como paredes fijas; si no, el acertijo se arma sobre un mundo que no es el real.
- Una torre a dificultad alta es ~65 % salas de cajas (hasta 12 seguidas, cada una distinta) y el resto las ideas de antes como respiro; 150–300 movimientos y 40–80 agarres en total.
- Los topes de la generación son de trabajo (resoluciones, candidatos, estados), no de tiempo: la misma semilla da siempre la misma torre.
- Herramientas: `tests/probe_validate.gd` (genera torres como en el juego y comprueba que el camino gana), `tests/probe_quality.gd`, `tests/probe_reja.gd` (capas en texto; `SHOW_TALLER=1` dibuja cada acertijo),
  `tests/play_tower.gd` (juega la solución dentro del juego con capturas; `IDEA=taller|mix`).

## 44. Tirar sin piso atrás, mundo más grande que la huella, deshacer
- **Tirar sin piso atrás** (de Catherine): de pie al borde con un bloque en frente, tirar hacia atrás trae el bloque a donde estabas y te deja **colgado del bloque en el que estabas parado** (un piso más abajo), sin poder
  trepar de vuelta (el bloque tirado quedó encima del borde): hay que moverse de costado por el borde. En hielo no hay de dónde agarrarse. Antes ese tirón fallaba ("no hay piso atrás").
- **El mundo es más grande que la huella de 8x8** (`TowerLogic.OUTSIDE`, 5 celdas): se puede caminar y colgarse hasta donde llegan los bloques que se empujaron afuera. El hielo sigue deslizándose sólo hasta salir de la
  huella y quien resbala fuera de ella se cae (`in_footprint`).
- **Deshacer** (tecla Z, reasignable en Opciones): vuelve el estado de la torre antes del último movimiento (con la cuenta de la caída y la claridad juntada) y rehace la vista; hasta 600 pasos, se vacía al reintentar.
- **Caída del suelo más permisiva** en las torres de acertijos: se elige el ritmo más apretado que todavía deja pasar un 33 % de movimientos de más repartidos y mucho titubeo concentrado al principio (donde hay menos colchón),
  y la primera caída tarda el doble.

## 45. Salas chicas con altura (`chica`)
- Sala de **4 o 5 pisos** con una arena de 3x3 a 3x5 (más un pasillo de hasta 4 celdas desde la llegada): cada celda es una columna de bloques de altura distinta (0 a 3 o 4), a veces con una columna
  pesada, y la salida es una columna fija alta en una esquina. Para subir hay que armar una escalera redistribuyendo bloques: uno de arriba que se empuja sobre una columna más baja la sube; también se
  pueden tirar o dejar caer desde arriba. Todo con la mecánica de siempre (empujar, tirar, colgarse).
- Se busca con el **solucionador completo** (todas las acciones) y se mide en **bloques movidos**: se parte de varias disposiciones al azar que se puedan resolver y se mejora la mejor pasando un bloque de una
  columna a otra mientras pida más agarres. Salen acertijos de 14 a 32 movimientos con 5 a 9 agarres; cuesta ~20 s por sala.
- Entra en el plan junto con las salas de cajas (cuentan juntas: hasta 2 seguidas y 5 por torre). Un acertijo sin colgarse no es lo mismo que uno con colgarse: el camino guardado puede usar Espacio para
  soltarse (en el juego se suelta con Espacio).

## 46. Casino y torre como un solo sistema: el duende al final del casino (diseño acordado, a implementar)

Decidido con Dante el 2026-10-16; todavía **no está implementado el ciclo nuevo** (sí lo de morir sin costo de claridad, ver más abajo). La simulación es `tests/sim_economia.gd` y las mediciones, `tests/sim_ingresos.gd` y `tests/probe_rtp.gd`.

### El ciclo
1. **Torre** (puzzle): da claridad por purificar y, en el piso, **monedas** sueltas por tipo de juego (ruleta, tragamonedas, blackjack). El HUD de la torre muestra el precio que cobrará el duende al final del casino.
2. **Casino**: el jugador tiene un **mínimo fijo de jugadas por visita** (3 de partida) que se pagan con monedas, no con claridad, más las monedas extra que juntó. Las jugadas de más se pagan con claridad. Mesas de distinta varianza con las probabilidades visibles, tienda de boosts y consumibles.
3. **Puerta trasera, el duende**: cobra de verdad el precio de la etapa (se descuenta la claridad). El peaje que hoy cobra el duende en el portal de la torre (§42) se muda acá.
4. **Torre siguiente.**

### Cuando no se llega a pagar
- Se pierde **una vida** y se vuelve a subir **la misma torre** (no se genera otra).
- La claridad juntada en el intento fallido **se conserva**.
- Sin vidas termina el run.
- **La deuda o fiado está descartada** (hay que quitar o replantear la regla "Fiado" de la taberna).

### Vidas y reintentos
- Las vidas se recuperan con el consumible **Vida extra** de la ruleta. Ese consumible tiene que poder usarse **también dentro del casino**; hoy sólo se puede usar en la torre. *(pendiente)*
- **Morir en la torre ya no cuesta claridad**: el costo es la vida que se pierde (`RunState.restart_cost(dead)` da 0). Reiniciar por voluntad (menú de pausa) sigue costando `25 + 2 por etapa` por reintento de la misma torre. El Tótem sigue sirviendo (salva la vida). **El Seguro** del gran casino (60 % del primer reintento) sólo cubre ya los reinicios por voluntad: conviene replantear su sentido. *(hecho en el código; falta repensar el Seguro)*
- Los boosts deberían **multiplicar** (no sólo sumar) para seguir la curva: hoy ninguno multiplica el ingreso de la torre (el que más se acerca es Mano de oro, que sube el paso de la racha).

### La economía, medida
- **Ingreso de una torre** siguiendo el camino mínimo (claridad, 2 torres por etapa): etapa 1: 193 · 3: 292 · 5: 156 · 8: 215 · 10: 260 · 12: 198 · 15: 404. Es muy irregular y **no crece con la dificultad**: las salas difíciles empujan más y un empuje no purifica ningún bloque, así que corta la racha. Una recta lo ajusta (`179 + 8,7 × etapa`: 187 en la 1 y 310 en la 15).
- **Ficha**: 50 en la etapa 1 y 106 en la 15. **Rendimiento de las mesas** (premio medio sobre el precio): ruleta 0,91 a 0,96, tragamonedas 0,915 (reteniendo bien), blackjack 0,979. Las mesas devuelven valor sobre todo en ítems, no en claridad (sólo la bolsa de luz devuelve claridad).
- **Peaje de hoy**: `40 + 4 × etapa` (44 a 100): del 23 % al 32 % del ingreso. No aprieta.

### Curvas del precio del duende que se compararon
| Etapa | Ingreso (recta) | actual | lineal | por ingreso | suave | exp (la de la charla) |
|---|---|---|---|---|---|---|
| 1 | 188 | 44 | 45 | 47 | 50 | 50 |
| 5 | 223 | 60 | 83 | 91 | 79 | 122 |
| 10 | 267 | 80 | 131 | 161 | 139 | 373 |
| 15 | 310 | 100 | 178 | 248 | 244 | 1137 |

(lineal: `45 + 9,5 × (etapa−1)` · por ingreso: 25 % del ingreso en la etapa 1, subiendo a 80 % en la 15 · suave: `50 × 1,12^(etapa−1)` · exp: `50 × 1,25^(etapa−1)`.)

**Resultado de la simulación** (4000 runs por curva y por habilidad; modelo en el encabezado de `sim_economia.gd`, con supuestos señalados): todas las curvas menos la exponencial dan casi lo mismo, porque el precio nunca supera el ingreso y lo que decide el run es morir en la torre. En cambio **la exponencial es una pared**: en la etapa 15 el duende cobraría 1137, unas 3,7 veces el ingreso; con todos los boosts de claridad que el modelo supone (+14 % cada uno) sólo se llega a ×1,8, y gana el 7 al 12 % de los jugadores.
- La conclusión es que **el precio y el ingreso hay que pensarlos juntos**: o el precio sigue al ingreso (curva *por ingreso*, de ~47 a ~250: sobra siempre algo para jugar de más y el final aprieta sin ser imposible), o se hacen **boosts que multipliquen de verdad el ingreso** (×1,5 a ×3) y entonces se puede usar una curva más empinada.
- Lo que sobra después de pagar (claridad para jugadas extra) es de ~75 por visita al principio a ~500 al final con la curva por ingreso; con la actual, ~700. Es lo que hay que balancear con el tamaño de las recompensas de las mesas.

### Propuesta de arranque (a confirmar)
Curva **por ingreso**: `precio(etapa) = (179 + 8,75 × etapa) × (0,25 + 0,55 × (etapa−1)/14)`, redondeado, y revisarla después de medir más torres (el ingreso real es irregular). Jugadas mínimas por visita: 3 con monedas.

### Pendiente
- Monedas en la torre (ítems recogibles por tipo de juego), contador en el HUD y el precio del duende visible desde el casino anterior.
- Mover el duende y el peaje a la puerta trasera del casino (hoy está en el portal de la torre).
- Usar la Vida extra dentro del casino; quitar o replantear la regla de la taberna ("Fiado") y el Seguro.
- Boosts multiplicativos y su efecto en la curva; más mediciones de ingreso (con las torres de la biblioteca, que cambian el ingreso).
- Lore: los bloques y mesas son recuerdos que se reescriben al apostar certeza (claridad); el tabernero subió, apostó y se quedó.
