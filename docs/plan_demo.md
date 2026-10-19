# Plan para cerrar la demo

Fecha: 2026-10-16. Rama base: `feature/juego-completo` (une la biblioteca de salas, el colgado, las bombas por zona, el casino con el duende, los boosts, las torres altas y el bot). Este documento ordena todo lo que falta para tener una demo que se pueda dar a jugar a gente de afuera, y lo organiza para desarrollarlo de corrido. Lo marcado **(a confirmar)** es una decisión de Dante.

## ESTADO DE IMPLEMENTACIÓN (2026-10-17)

Todo se hizo en ramas propias (`fix/abandonar-run`, `feature/quitar-guia-bloques`, `feature/shift-camina`, `feature/farolin-dialogos`, `feature/numeros-grandes`, `feature/telemetria`, `feature/editor-modelos`, `feature/demo-bloqueos`, `feature/tutorial-farolin`) mezcladas en `feature/demo`; nada está en `main` todavía. Detalle de lo que hay y cómo se construye: `docs/demo.md`.

| Punto | Estado |
|---|---|
| 0. "Abandonar el run" colgaba el juego | Hecho. Causa real: los hilos de generación de torres altas no miraban la cancelación (42 a 70 s); ahora `end_run` vuelve en milisegundos (`gen_abort.gd`, hilos zombis). `tests/test_abandonar.gd`. |
| Guía de bloques eliminada | Hecho (quedan los avisos del tabernero al descubrir un bloque). |
| Shift sin bloque = caminar | Hecho (`tests/test_logic.gd`). |
| Farolín, diálogo con decisiones, 4 casinos sin colisiones, personaje saliendo del portal | Hecho (`tests/test_farolin.gd`, `test_toll.gd`). |
| Cartel de la prueba, HUD con marco, avisos | Hecho. Los `_flash` quedan sólo para avisos sin voz. |
| Gatito por defecto, perrito libre | Hecho. |
| A. Cierre de lo hecho | Documentación al día (CLAUDE.md, diseno.md §50, docs/demo.md, docs/editor_modelos.md); batería completa corrida. Pendiente de Dante: mezclar a `main`. |
| B. Tutorial | El cierre del tutorial explica Farolín, las vidas, la vitrina, la tienda y los boosts (no se agregó una lección de bombas: el aviso del tabernero al descubrir una bomba ya explica la zona roja). |
| C. Banco de torres | Hecho: 24 torres para las etapas 1 y 2, instantáneas (`tests/test_banco.gd`). |
| D. Fin de la demo | Hecho (`demo_end_screen.gd`, `tests/test_demo.gd`). Falta poner la dirección real de Steam en `Demo.WISHLIST_URL`. |
| E. Números grandes y juice | Hecho (`NumberFormat`, cartel de ganancia con peso). |
| F. Robustez y opciones | Hecho: registro de archivos del motor activado, botón "Abrir la carpeta" en Opciones, "reducir efectos" ya existía en Gráficos, tamaño de la interfaz y mando ya existían. Pendiente: probar en una máquina vieja (rendimiento) y una máquina limpia (exportación). |
| G. Prueba con gente / H. Arreglos | Telemetría local lista; falta la gente (Dante). |
| I. Editor de modelos y variantes de cubos | Hecho: variantes automáticas en el juego (4 por tipo), editor, formato `data/modelos/*.jsonl`, importar del código, reemplazo de personajes y cosméticos. Los personajes nuevos y cosméticos nuevos se registran en `Characters.ALL` / `Cosmetics.ALL` cuando Dante los pida. |
| J. Contenido de salas | No se corrió el minero: la demo no usa bombas (empiezan en la etapa 6) y las etapas 1 y 2 salen del banco. Pendiente para el juego completo. |
| K. Localización y créditos | Hecho (test_loc en verde, créditos "Dante y Claude"; revisar el texto si Dante quiere otro). |
| L. Exportación | Preset "Windows Demo" listo y probado (arranca sin errores); falta probarlo en una máquina limpia. |

## PRIMER PUNTO A RESOLVER (antes que cualquier otro): "Abandonar el run" cuelga el juego

- **Síntoma (Dante):** al pulsar "Abandonar el run" en el menú de pausa el juego se congela.
- **Dónde:** `pause_menu.gd:43` emite `abandon_run` → `main.gd:1929` hace `resume_game()` y `end_run(false, "Abandonaste el run.")` (`main.gd:2105`).
- **Hipótesis principal (a verificar, no confirmada):** `end_run` llama a `_cancel_jobs()` y a `_close_balance()`; si `_cancel_jobs` espera (`wait_to_finish`) a los hilos de generación de la torre actual y de la siguiente (prefetch de dos etapas, con torres de 50 a 100 pisos y el solucionador), la espera dura minutos o nunca termina (la generación de una torre de la etapa 14 llegó a más de un minuto) y el hilo principal queda bloqueado. Otras sospechas: `casino.queue_free()` con hilos vivos, `run_end.show_summary` con datos de una torre sin terminar, o `Profile.record_run` con un run sin torre.
- **Cómo se resuelve:** reproducirlo primero (prueba que arma un run, deja generando la etapa siguiente, abandona y exige que `end_run` vuelva en pocos cuadros); cancelar la generación **sin esperar** (bandera de cancelación revisada por los hilos y por el puente al solucionador, y los hilos se juntan más tarde, en segundo plano o al salir) y que `end_run` nunca bloquee el hilo principal. Si el problema es otro, se corrige la causa real.
- **También revisar los demás caminos que cancelan generación:** "Volver al menú principal", "Reintentar la torre", salir del juego, perder la última vida, y el nuevo "Abandonar" de Farolín. Todos deben volver al instante.
- **Cierre:** `tests/test_abandonar.gd` (abandona en la torre, en el casino, durante la generación y en el tutorial) y se agrega a la batería. Va en su propia rama (`fix/abandonar-run`) y se mezcla antes de seguir.

## Decisiones de Dante (2026-10-16) — mandan sobre el resto del documento

1. **Alcance (corregido por Dante):** la demo llega **hasta alcanzar el segundo casino**, es decir las etapas necesarias para eso. Como cada etapa (torre) termina en su casino, el segundo casino se alcanza al terminar la **torre 2**: tutorial + torre 1 + casino 1 (+ duende) + torre 2 + casino 2. Dante aclaró que no recuerda en qué etapa aparece; en el código cada etapa termina en un casino, así que es la etapa 2. **Pendiente de decidir:** si el fin de la demo se muestra al *entrar* al casino 2 (se juega la ruleta/vitrina/tienda una vez) o al pagarle al duende de ese casino. Propuesta: se puede jugar el casino 2 completo y la pantalla de cierre sale al pagar su duende (o fallar). Donde más abajo dice "etapas 1 a 7", leer "etapas 1 y 2" (banco de torres: 12 por etapa para esas dos; la colina, las bombas y la prueba de la etapa 3 quedan fuera).
2. **El editor de modelos es una herramienta de desarrollo** (como el Estudio de salas): lo usa Dante para crear cubos, personajes y cosméticos, y después Claude los integra al juego. No es para que los jugadores hagan los suyos: no va en el menú del juego ni en la exportación; se abre con su propio `.bat`. Se descartan los botones "probar en el juego" para jugadores y todo lo de compartir/importar de usuarios.
3. **Fuera de la demo:** monedas dentro de la torre y jugadas mínimas. **Blackjack y tragamonedas** quedan en el casino pero bloqueados: al elegirlos muestran un cartel "Disponible en el juego completo" (en español y en inglés). La ruleta, la vitrina y la tienda sí están.
4. **Mando desde el día 1:** toda pantalla nueva y vieja se diseña con mando (movimiento, empujar, colgarse, deshacer, cámara, navegación de menús con foco visible, casino, tienda, tutorial con los botones del mando). Sube a requisito de todos los bloques, no es opcional (ver F).
5. **Mecánica nueva (todo el juego): Shift sin nada que mover = caminar.** Si se mantiene Shift (la acción "empujar", también el gatillo del mando) y se pulsa una dirección, pero no hay bloque para empujar ni tirar, el movimiento se interpreta como un paso simple (el mismo que sin Shift). Hoy `main.gd` (`_unhandled_input`, ~línea 1090) pasa `Mode.GRAB` cuando el modificador está apretado y `TowerLogic` decide el resultado; hay que ver qué devuelve GRAB sin bloque (probablemente movimiento bloqueado o nada). Plan: la regla va **en `TowerLogic`** (no sólo en la entrada), para que valga igual en la torre, el casino, el tutorial, el solucionador, el bot y el solucionador nativo: `GRAB` sin bloque empujable ni tirable en esa dirección ⇒ se resuelve como `MOVE`. Cuidados: (a) el solucionador sigue generando sus acciones con modos explícitos, así que no cambian las salas ni la biblioteca; (b) si Shift + dirección contraria a un bloque que no se puede tirar (queda trabado), ¿se camina o no? Propuesta: se camina sólo si no existe ninguna acción de empujar/tirar posible (para no mover al jugador cuando el bloque estaba apenas trabado por algo que el jugador ve); a confirmar con Dante; (c) en el casino (sin bloques) Shift + WASD simplemente camina; (d) el cartel de ayuda "Bloqueado (Shift: empujar)" y las lecciones del tutorial se ajustan; (e) pruebas: `test_logic.gd`, `test_view.gd`, tutorial y mando (gatillo + stick).
   - Respuestas de Dante: el fin de la demo se muestra al pagarle (o fallarle) al duende del casino 2; y Shift + dirección con un bloque trabado camina sólo si no existe ninguna acción posible de empujar o tirar (la propuesta de arriba).
6. **Cómo se trabaja la demo sin romper el juego completo:** la demo **no es una copia ni una rama larga del proyecto**: es el mismo código con un interruptor. Un único `scripts/demo.gd` (`Demo.ON`) que se activa con una *característica personalizada* del preset de exportación (`OS.has_feature("demo")`) o, para probar en el editor, con la variable de entorno `GAME_DEMO=1`. Sin el interruptor el juego completo se comporta exactamente como hoy. Reglas:
   - **Todo recorte pasa por `Demo`** (`Demo.ON`, `Demo.stage_limit()`, `Demo.locked(id)`, `Demo.soon_text()`): nada de borrar contenido ni de `if` sueltos por el código. Lo que la demo esconde sigue existiendo, sólo no se puede abrir.
   - **Dos presets de exportación:** "Completo" y "Demo" (el segundo con la característica `demo` y su lista de archivos: sólo el banco de torres de las etapas 1 y 2, la biblioteca de salas necesaria y los modelos permitidos; sin escenas bloqueadas ni habilidades). Dos carpetas de guardado (`user://demo/` y `user://`) para que la demo y el juego no se pisen los guardados ni el perfil.
   - **Rama de trabajo:** el desarrollo de la demo va en una rama propia (`feature/demo`) cortada de `feature/juego-completo`; los cambios que valen para ambos (mecánica de Shift, mando, número grandes, banco, editor de modelos, eliminar la guía de bloques) se hacen **primero** como cambios del juego base y se mezclan igual, así no hay divergencia. Lo exclusivo de la demo queda sólo en `demo.gd` y en las pantallas "Próximamente".
   - **Pruebas en las dos configuraciones:** la batería corre con `GAME_DEMO=0` y con `GAME_DEMO=1`; hay una prueba nueva `test_demo.gd` que recorre cada recorte (escenas, habilidades, cosméticos, juegos del casino, fin de la demo) y otra que comprueba que con `Demo.ON` falso no cambia nada.
   - **Mismo cuidado para el banco de torres:** el banco sólo se usa cuando `Demo.ON`; el juego completo sigue generando en vivo.
7. **Recortes de la demo (Dante):**
   - **Escenas** (Glaciar, Ruinas, Polvorín, Relojería, Gran Casino, Compromiso, etc.): no aparecen como opciones jugables. En la demo sólo se ve el **tutorial** y **la pesadilla** (el run simplificado hasta el segundo casino). Los demás modos se muestran con el cartel **"Próximamente"** y el botón no abre nada.
   - **Habilidades persistentes:** el botón existe, pero en vez de la pantalla de habilidades muestra el mensaje **"Disponible en la versión completa"**.
   - **Cosméticos:** quedan disponibles **2 gorros, 2 prendas** y los personajes **Dante, Gaby, gatito y perrito**. Todo lo demás se muestra como casillero con **"?"**, y al pasar el mouse dice **"Disponible en la versión completa"** (no se pueden equipar, no salen en los dados, no se guardan como desbloqueados). Qué 2 gorros y qué 2 prendas: **a elegir por Dante** (propuesta: los dos más vistosos de rareza común para que la demo no regale los raros).
   - **Guía de bloques:** se **elimina del juego base y de la demo** (`block_guide.gd`, su botón en el menú y en la pausa, sus textos en `loc_en_*`, su prueba y las referencias en `docs`). No es un recorte de la demo: es un cambio del juego base, en su propia rama (`feature/quitar-guia-bloques`), antes de todo lo demás.
   - **Casino:** blackjack y tragamonedas con "Disponible en el juego completo" (ya decidido).
8. **Cosméticos elegidos (Dante):** gorros **Corona** (`corona`, hoy épica) y **Gorro de lana** (`gorro_lana`); prendas **Remera** (`remera`) y **Capa** (`capa`, hoy rara). Consecuencias: (a) la demo regala Corona y Capa aunque sean épico/raro, así que no salen de los dados ni de premios: vienen desbloqueados de fábrica, y la rareza de la demo se muestra sin cambiar el catálogo del juego completo; (b) el resto va con "?" y "Disponible en la versión completa".
9. **Personaje predeterminado: el gatito** (`gato`), en el juego base y en la demo. Hoy `Characters.DEFAULT = "dante"` y el gatito se desbloquea al llegar a la etapa 2 (`Profile.on_stage_reached`); el perrito se desbloquea al superar una prueba (`Profile.on_trial_cleared`), pero la demo no tiene pruebas (la primera es en la etapa 3). Cambios: `DEFAULT = "gato"`; el gatito siempre está desbloqueado; la demo desbloquea **Dante, Gaby, gatito y perrito** de fábrica (el perrito ya no se gana con la primera prueba: queda libre desde el principio también en el juego completo, por decisión de Dante). Perfiles ya guardados: si el personaje elegido era `dante` por ser el predeterminado de antes, se deja (no se pisa la elección del jugador); sólo el perfil nuevo arranca con el gatito. Tutorial, historias, caras de diálogo y capturas que asumen a Dante se revisan.
10. **Rediseño del HUD y de cómo se presentan los textos (juego base y demo; Dante):**
    - **Todo lo que sea diálogo usa el cuadro del tabernero** (`dialogue_box.gd`: cuadro de cubitos abajo, cara de quien habla a la izquierda, nombre y texto letra por letra). Regla permanente a partir de ahora: nada del tipo diálogo se presenta de otra forma.
      - **El duende** (`goblin.gd`, `casino_scene.gd`): hoy sus frases salen como avisos (`_flash`: "El duende pide %d de claridad: te faltan %d...", "El duende te cobra un 30 % menos..."). Pasan a ser líneas del cuadro de diálogo con la **cara del duende** (nueva cara de cubitos, 12×13 como la del tabernero, con su paleta; sale del editor de modelos cuando esté) y su nombre. Casos: saludo y precio al acercarse a la puerta, falta de claridad (con la advertencia de perder una vida), soborno, descuento, "ya pagaste", y fin de la demo.
      - **El crupier y otros personajes** del casino: se revisan todas las frases (`casino_scene.gd`, pantallas de juego, tienda, vitrina) y las que son voz de un personaje pasan al cuadro con su cara; los avisos que no son voz de nadie (saldo insuficiente, "no se puede usar ahora") siguen como avisos chicos pero con el estilo del juego (ver más abajo).
      - Cuadro en modo **bloqueante** (hay que avanzar) para lo importante (duende, historia) y de **consejo** (se escribe solo y no pide nada) para lo breve; con mando: A avanza.
    - **Las pruebas** (`main.gd` `trial_label`, `run_state.gd` textos de "Próxima prueba"): hoy aparecen como el texto plano "* Prueba: Niebla\n<descripción>" arriba al centro. Pasan a mostrarse **con la letra del juego (la fuente de cubitos, `VoxelLabel`) en la parte inferior de la pantalla**, con una entrada animada (aparece, se queda unos segundos y se atenúa; vuelve a mostrarse al pausar o pulsar una tecla de consulta, p. ej. Tab o un botón del mando) y colores propios de la prueba. Sin asterisco. El tabernero sigue contando cuál viene.
    - **La ventana de datos de arriba a la izquierda** (`hud_panel.gd`: corazones, etapa, claridad, precio del duende): hoy es una caja que no pega con el diseño. Se rediseña con el lenguaje del juego: marco de **cubitos** (el mismo que el cuadro de diálogo y las pantallas de ruleta, con bordes dorados y fondo oscuro translúcido) o, mejor aún, sin caja: los datos como **placas de cubitos sueltas** (corazones, "Etapa 3", el contador de claridad y la placa del duende) con el espaciado y los colores de la etapa. Se resuelve con **dos maquetas en captura** para que Dante elija antes de integrarlo: (A) un marco único de cubitos; (B) placas sueltas sin marco. El mismo componente se usa en la torre, el casino y la taberna, y respeta la zona segura para mando/pantallas chicas.
    - **Avisos cortos** (los `_flash`/toasts): estilo de cubitos y misma letra, abajo y centrados, con una animación de entrada y salida.
    - **Pruebas:** `test_hud.gd`/`test_view.gd` ajustados; capturas antes y después (torre, casino, duende, prueba, tutorial); una prueba que revisa que las frases del duende lleguen por el cuadro y no por `_flash`; traducción al inglés de todo lo nuevo.
10b. **Diseño elegido tras las maquetas (Dante; capturas en `capturas/propuestas/p_final_*.png`, script `tests/mock_propuestas.gd`, rama `feature/maquetas-ui`):**
    - **Farolín reemplaza al duende** (se llamaba "Farolero" en la maqueta; el nombre definitivo es **Farolín**): un farol con piernas y brazos. Hay que **rehacer su modelo 3D** (`scripts/goblin.gd` → `farolin.gd`: farol de hierro con asa, llama con ojos y sonrisa dentro del vidrio, bracitos y patitas; la llama titila y emite luz, y la expresión cambia si pagás o fallás) y su cara de diálogo (12×13, la de la maqueta). Todo texto, comentario, prueba, documento y el catálogo que diga "duende" pasa a "Farolín" (los ids internos, p. ej. `descuento_duende`, pueden quedar; cambia lo que se ve y el inglés). Nombres de ítems y mensajes del soborno y los descuentos se revisan.
    - **Revisar los 4 casinos** (taberna, salón, casino y gran casino; `casino_room.gd`, `Room.look`): Farolín tiene que estar junto a la puerta de salida **sin colisionar con ningún otro componente** (hoy en la taberna/cantina se pisa con otro objeto). Comprobación automática: una prueba que arma la sala de cada tipo y etapa, ubica a Farolín y verifica que su celda y las vecinas necesarias estén libres, que se llegue a la puerta y que ningún mueble o máquina lo toque; más una captura de cada casino.
    - **El personaje aparece de frente en el casino** (mirando a la cámara, no de costado) al entrar, y al salir de la torre: orientar `casino_scene.gd` según la vista isométrica por defecto.
    - **Elegir en las decisiones de texto con las flechas izquierda y derecha** (y confirmar con Enter/Espacio o clic; mando: cruceta o stick izquierda/derecha y A; el botón B no es "rehacer", cancela si hay algo que cancelar). Las dos opciones van lado a lado como en la maqueta, la elegida resaltada en dorado; no hay teclas 1 y 2. **Corrección de Dante:** no se dibujan las flechas ni las teclas/botones (nada de ◄ ► ni "Enter" ni el stick ni la A en pantalla): sólo las dos opciones, con la elegida resaltada; se cambia con las flechas izquierda/derecha y se confirma con Espacio o Enter (mando: izquierda/derecha y A, sin dibujarlos). Las capturas `p_v3_*` de la última maqueta todavía los muestran: esa parte queda descartada. **Cuidado:** en el casino las flechas izquierda/derecha giran la cámara, así que mientras hay una decisión abierta la cámara no responde a las flechas (sólo al mouse y a Q/E). Regla general para todo diálogo con opciones del juego.
    - **Opciones del Farolín:** con vidas, "Pagar N" o "Rehacer la torre (−1 vida)"; sin vidas, "Pagar N" o "Abandonar" (se pierde el run). Si no alcanza la claridad, "Pagar" aparece apagado y no se puede elegir. Insistir ya no manda a la torre: ese camino del código (`failed_to_pay` desde la puerta) se reemplaza por la decisión del diálogo.
    - **Cartel de la prueba:** letras grandes abajo, sin fondo ("Prueba" chico arriba, el nombre grande y bailando, la descripción abajo); aparece, se queda unos segundos y se desvanece lento. **Al pausar se muestra otra vez completo**, igual que al principio (no hay tecla extra para volver a verlo).
    - **HUD de arriba a la izquierda:** por ahora el marco único de cubitos, igual al cuadro de diálogo (opción A de las maquetas); queda abierto repensarlo más adelante.
    - **Avisos `_flash`:** se revisan todos los casos; se mantienen sólo los avisos chicos tipo "no alcanza".
    - **Perrito:** libre desde el principio también en el juego completo (además del gatito por defecto).
11. **No se arranca nada hasta que Dante lo diga explícitamente.** Este documento es sólo planificación.

## 0. Qué es la demo

- **Contenido (propuesta):** el tutorial, las etapas **1 a 7** (la taberna, el salón y el comienzo de la colina del duende), las pruebas de las etapas 3 y 6, el casino completo (ruleta, tragamonedas, blackjack, vitrina, tienda y los premios de ganancia y de casino), vidas, reintentos, los dados de la pantalla de carga, cosméticos y los personajes desbloqueables dentro de esas etapas (el gatito en la 4 y el perrito con la primera prueba).
- **Fin de la demo:** al superar la etapa 7 y pagarle al duende, una pantalla de cierre: resumen del run, mensaje de "esto es la demo", y un botón de lista de deseos (una dirección configurable; la conexión con Steam queda afuera).
- **Fuera de la demo:** las etapas 8 a 15, la pared de las builds, los escenarios (Glaciar, Ruinas, Polvorín, Relojería, Gran Casino, Compromiso), las habilidades persistentes de fin de pesadilla.
- **Criterios para darla por cerrada:** (1) un jugador nuevo termina el tutorial y entiende el bucle torre → casino → duende sin explicación externa; (2) 10 partidas completas seguidas sin un solo error ni torre que no se genere; (3) arranca la etapa 1 en menos de 5 segundos y cualquier etapa de la demo en menos de 10; (4) todas las pruebas automáticas en verde; (5) la exportación funciona en una máquina limpia; (6) al menos 5 personas de afuera la jugaron y los problemas que marcaron más de una vez están arreglados.

## 1. Orden y dependencias

**Orden de arranque acordado:** (0) arreglar "Abandonar el run" (ver arriba); (1) quitar la guía de bloques; (2) la regla de Shift sin bloque; (3) Farolín, decisiones con flechas, cartel de la prueba, HUD y avisos; luego A, C y B del esquema de abajo.

```
A. Cierre de lo hecho ─┬─ B. Tutorial nuevo ──────────────┐
                       ├─ C. Banco de torres + carga ─────┤
                       ├─ D. Fin de la demo ──────────────┤
                       ├─ E. Números grandes y juice ─────┼─ G. Prueba con gente ─ H. Arreglos ─ L. Exportación
                       ├─ F. Robustez y opciones ─────────┤
                       ├─ I. Cubos con variantes + Editor de modelos
                       └─ J. Contenido (salas con bomba, variedad) [minado en segundo plano]
K. Localización y créditos (se cierra al final de B, D, E)
```
Lo que va primero: A, y enseguida C (el banco de torres) y B (el tutorial), porque definen la primera impresión. I (editor de modelos) es lo más grande y puede avanzar en paralelo con todo lo demás; J corre en segundo plano (minero).

## A. Cierre de lo ya hecho

1. Batería de pruebas completa en verde (hoy sólo falla `test_loc` por el texto de créditos con relleno).
2. Revisión de `feature/juego-completo` y merge a `main` cuando Dante lo diga (una rama por cambio, regla del proyecto).
3. Limpiar: sacar el diagnóstico de `rooms.gd` (`lib_stats`, `prof`, `IDEA_LOG`) o dejarlo bajo variable de entorno; quitar `GOAL_*` sin uso.
4. Actualizar `docs/diseno.md` (§46 a §49 ya están) y la memoria.

## B. Tutorial nuevo

El tutorial actual enseña moverse, empujar, tirar y colgarse, la cámara, deshacer, los dados y una torre de verdad. Falta lo nuevo.
- **Lección de las bombas:** una torre chica con una bomba y su zona roja titilando: "mientras estés dentro de la zona roja, la cuenta baja; salí o apagala pisándola".
- **Lección del casino y el duende:** al terminar la torre, el tabernero explica que el duende de la puerta cobra, dónde se ve el precio (arriba a la izquierda, en rojo si falta), y qué pasa si no se alcanza (se pierde una vida y se vuelve a subir la misma torre). Práctica: pagar el primer peaje de verdad.
- **Lección de la ruleta con vitrina:** mostrar los premios de la visita, probar *Rotar vitrina*, comprar algo en la *Tienda*.
- **Lección de las builds:** el primer boost de ganancia (regalado: *Pies de luz* o *Midas*) y cómo cambia lo que se junta, con el cartel de ganancia y la racha.
- **Vidas y reintentos:** morir no cuesta claridad, cuesta una vida.
- **Guion:** el tabernero en español rioplatense, mismo tono; traducción al inglés en `loc_en_story.gd`. Se puede saltear con una tecla después de la primera vez.
- **Pruebas:** `test_tutorial.gd` ampliado (cada lección se resuelve con el camino que trae, el texto no se corta, todo traducido).

## C. Banco de torres y tiempos de carga

- **Qué:** un banco de torres ya generadas para las etapas de la demo (12 por etapa, 84 en total), empaquetado y comprimido en `data/torres_demo.torres`, con una herramienta que lo arma con el generador del juego (`tests/bot_banco.gd` ya genera las torres; falta el empaquetador y un verificador que repite cada camino).
- **Cómo se usa:** al arrancar una etapa de la demo se elige una torre del banco (sin repetir en el run); la generación en vivo queda para el juego final y como respaldo si el banco no alcanza. Ventaja: carga instantánea y torres ya probadas.
- **Resiliencia:** si falla la generación o el banco, reintentar con otra torre del banco y nunca dejar al jugador en una pantalla de carga infinita; mensaje claro si pasa algo raro.
- **Tareas:** formato `.torres` y `TowerBank` (carga única, mutex, lectura comprimida desde `res://`); integración en `main.gd` (`_start_job`); incluir `data/*.torres` en el preset de exportación; prueba de que cada torre del banco se gana con su camino, que no hay dos iguales y que cada etapa tiene al menos 12.
- **Tiempo de carga objetivo:** etapa 1 en menos de 5 s, cualquier etapa en menos de 10 s.

## D. Fin de la demo

- Pantalla de cierre al superar la etapa 7: resumen del run (etapa alcanzada, torres, claridad, vidas, boosts y cosméticos), mensaje "gracias por jugar la demo", botón de lista de deseos (dirección en una constante), botón de jugar de nuevo y de volver al menú.
- Modo demo (`Demo.ENABLED`): limita a 7 etapas, esconde lo que no entra (escenarios bloqueados con un cartel "en el juego completo"), y ajusta el tabernero final. Una constante, para que el juego final no se rompa.
- Pruebas: terminar el run de la demo con el bot y ver que sale la pantalla; el modo demo apagado no cambia nada.

## E. Números grandes y juice

El juego tiene que poder romperse con los puntos sin romper la pantalla.
- **Formato de números:** un `NumberFormat` (1,2 mil; 3,4 M; 5,6 B) usado por el contador de claridad, el cartel de ganancia, el precio del duende, las fichas, las pantallas del casino y el resumen; ancho de los contadores a prueba de 9 dígitos. Prueba: ningún número rompe el diseño con 10^9.
- **Cartel de ganancia con peso:** la claridad ganada se anima según su tamaño (más grande, más tiempo y más fuerte), con sonido que sube con la racha y las multiplicaciones; mostrar el multiplicador completo (×3 de cosecha y ×4 de racha).
- **Casino:** premios grandes con un golpe de pantalla; la pantalla de ganaste/perdiste ya existe, falta darle escala al premio mayor.
- **Pruebas:** capturas con 10^3, 10^6 y 10^9.

## F. Robustez y opciones

- **Guardado:** probar continuar un run guardado en medio de la torre, en el casino y en la pantalla de carga; migración de guardados viejos (formato con `showcase`, `toll_bribe`).
- **Errores:** nunca cerrar el juego por una torre mala; registro (`user://registro.log`) con la semilla y las acciones cuando algo falla; botón "reportar" que abre la carpeta.
- **Opciones:** revisar video (resolución, pantalla completa, calidad), audio (música, efectos), idioma, controles reasignables, rosa de los vientos; sumar opción de "reducir efectos" (sin temblor de pantalla ni destellos) y de tamaño de texto.
- **Mando:** movimiento y acciones con mando (stick, A para empujar, B para colgarse, etc.) y navegación de menús. Es opcional para la demo; se hace si hay tiempo (decisión de Dante).
- **Rendimiento:** medir en una máquina vieja (cuadros por segundo con una torre de 70 pisos, tiempo de carga del casino, memoria en una hora de juego).

## G. Prueba con gente de afuera

- **Protocolo:** 5 a 10 personas, una sola sesión de 45 minutos cada una, sin explicarles nada; se anota dónde se traban, qué no entienden, cuándo se aburren.
- **Telemetría local:** el juego anota en `user://telemetria.jsonl` (sólo en la máquina) por cada torre: etapa, intentos, muertes y causa, claridad ganada, tiempo; por cada visita al casino: qué compró, cuántas veces jugó, cuánto sobró; y cómo termina el run. Un botón en el menú de opciones abre la carpeta para que me la manden.
- **Uso:** con esos datos se calibra la tasa de muerte del bot (hoy 3 % a 20 %, inventada) y la curva de la colina; se vuelve a correr el bot y se ajusta.
- **Entregable:** un informe con los 10 problemas principales y cuáles se arreglan antes de lanzar.

## H. Arreglos de la prueba

Lo que salga de G (se estima 1 a 2 días de arreglos). Se deja un margen explícito en el cronograma porque es donde más sorpresas hay.

## I. Cubos con variantes y editor de modelos

Pedido de Dante: que los cubos no tengan un solo diseño (variantes para darle variedad a las torres) y un editor de cubos, personajes y cosméticos, como el de las salas.

### I.1 Formato de modelo
Hoy todo se arma por código: los bloques en `block_models.gd` (5×5×5 minibloques por tipo y estado, con colores en los vértices), los personajes en `characters.gd` (cajas con colores) y los cosméticos en `cosmetics.gd` (cajas encima de un punto de anclaje del personaje). El editor necesita un formato de datos:
- **Modelo voxel** (JSON, una línea por modelo): `{id, tipo ("bloque" | "cosmetico" | "personaje"), nombre, tamaño [x,y,z], paleta [colores], voxeles [[x,y,z,índice]], anclas, estado, variante_de, notas, version}`.
- **Bloques:** 5×5×5 (o 8×8×8 más adelante) por `tipo` de bloque (común, hielo, bomba, catapulta, agrietado, pesado, trampa, pinchos, núcleo) y `estado` (corrupto, purificado, desactivado). Cada tipo y estado tiene una **lista de variantes**; la variante de cada cubo en la torre se elige por un número que sale de su celda inicial (estable: el mismo cubo siempre se ve igual en la misma torre, y la torre se ve distinta a la siguiente).
- **Cosméticos:** un modelo con un ancla (`gorro` sobre la cabeza, `prenda` sobre el torso, y luego `cara` y `espalda`); tamaño libre dentro de una caja (por ejemplo 12×12×12 minibloques para el gorro).
- **Personajes:** un conjunto de partes con voxeles (cabeza, torso, brazo izquierdo y derecho, pierna izquierda y derecha) cada una con su pivote, porque la animación de pasos y el estirar y aplastar mueven partes. Los humanos (Dante y Gaby) y los animalitos pasan al formato de datos.
- **Carpeta:** `data/modelos/*.jsonl`, versionada (es arte del juego, no datos generados), cargada por un `ModelLib` (como `RoomLib`).

### I.2 Variantes de cubos
- Primero sin editor: generar automáticamente 3 a 4 variantes por tipo y estado a partir del diseño actual (otras semillas de desorden, voxeles sueltos en otros lugares, bordes distintos) para que las torres ya se vean con variedad.
- `BlockModels.mesh_for(tipo, estado, variante)`; `main.gd` elige la variante por celda (`_make_block`) y la mantiene al moverse el bloque.
- La lógica del juego no cambia (sólo es visual); se mantiene la regla de que la cara de arriba esté cubierta (`top_coverage`) para que se vea que se puede pisar.
- Pruebas: todas las variantes tienen la cara de arriba cubierta, se parecen entre sí lo suficiente para leerse como el mismo tipo (mismo color base), y el tiempo de armar los modelos no sube.

### I.3 Editor de modelos
Escena `editor_modelos.tscn` y `scripts/editor_modelos.gd` (más `modelo_vista.gd` y `modelo_datos.gd`), con el mismo estilo del Estudio de salas:
- **Pintar en 3D:** clic para poner un minibloque en la cara tocada (como el editor de salas, estilo Minecraft), clic derecho para sacarlo, selección de color de la paleta, cuentagotas, relleno de una capa, **simetría** (espejo en x y z), rotar el modelo y cámara libre (arriba y abajo del horizonte).
- **Capas:** ver una capa a la vez para pintar con precisión; deshacer y rehacer (Ctrl+Z, Ctrl+Y).
- **Paleta:** colores editables, paletas guardadas (la del juego por etapa), y un modo "tinte de la etapa" para ver cómo queda a distintas alturas (el bloque normal purificado toma el color de su altura).
- **Lista de modelos** a la izquierda con filtro por tipo (bloque, cosmético, personaje), por estado y por rareza; **variantes** de cada bloque en una tira para elegir cuál se edita; botones de duplicar, borrar y marcar como "versión del juego".
- **Vista previa:** al lado, el modelo en la escena real (iluminación del juego, sobre una torre chica, o puesto en el personaje que se elija); para personajes, una animación de caminar y de saltar.
- **Verificación a pedido:** cara de arriba cubierta (bloques), tamaño dentro de la caja (cosméticos), partes completas (personajes), cantidad de minibloques (para vigilar el costo de dibujo).
- **Guardado:** a `data/modelos/` (JSONL), con un botón "probar en el juego" que abre una torre y deja el modelo puesto.
- **Importar de código:** un botón "pasar al editor" para cada diseño actual (los bloques, personajes y cosméticos que hoy están en código), así se parte de lo que ya hay.

### I.4 Integración en el juego
- `BlockModels`, `Characters` y `Cosmetics` leen primero `ModelLib` (si hay un modelo del id, lo usan) y caen al diseño por código si no (así lo viejo no se rompe).
- El menú de Personaje muestra los cosméticos creados con el editor con su rareza (la rareza se edita en el editor).
- Los dados de la pantalla de carga entregan también los cosméticos nuevos (ya sortean entre `Cosmetics.ALL`).

### I.5 Pruebas y documentos
`tests/test_modelos.gd` (formato, carga, variantes estables, ida y vuelta guardar y leer), pruebas del editor como las del Estudio (pintar, deshacer, simetría, guardar), capturas, y `docs/editor_modelos.md`.

### I.6 Tamaño
Es lo más grande del plan. Orden interno: formato y `ModelLib` → variantes automáticas en el juego → editor básico (pintar, paleta, guardar) → vista previa y verificación → personajes con partes y animación → cosméticos con anclas. Si el tiempo aprieta para la demo, se entrega hasta las variantes automáticas y el editor de bloques y cosméticos, y el editor de personajes queda para después.

## J. Contenido de salas

- **Salas con bomba:** hoy la biblioteca no tiene ninguna que necesite la bomba (se vuelven comunes con la regla de zona esférica). Hay que minerar con el foco en bombas (`--types=b`, `--focus=bomba` con la cuenta afinada) para tener al menos 60 salas con bomba verificadas; la bomba aparece en la etapa 7, última de la demo, pero conviene tener variedad.
- **Variedad:** meta de la demo: al menos 300 salas distintas (por familia) en las dificultades de las etapas 1 a 7 y las cuatro formas con alturas variadas. Hoy hay 3755; lo que falta es revisar que haya suficiente de cada dificultad y forma en esas etapas.
- **Calidad:** una pasada por el Estudio con las salas que más salen (revisar visualmente, descartar las feas o confusas, marcar las buenas).
- Corre en segundo plano (minero), sin bloquear el resto.

## K. Localización y créditos

- Inglés completo (los tests de traducciones dejan de fallar), créditos reales (nombres), textos nuevos del tutorial, del fin de la demo y del editor.
- `test_loc.gd` en verde.

## L. Exportación

- **macOS (consulta de Dante):** dificultad baja a media. Godot exporta el `.app` desde Windows (hacen falta las plantillas de exportación de macOS, universales Intel/Apple Silicon); el renderizador Compatibility (OpenGL) funciona en Mac. El solucionador nativo (`solver_nativo.exe`) es sólo de Windows, pero la demo no lo necesita (banco de torres precalculado y el resto cae a GDScript). Lo difícil: firmar y notarizar (hace falta una Mac y una cuenta de Apple Developer, ~99 USD al año; sin eso Gatekeeper avisa, aunque lo que se baja por Steam normalmente no se bloquea) y probarlo en una Mac real (shaders, fuentes, mando, rutas de guardado). Se deja como un preset más y una prueba manual; no bloquea la demo de Windows.
- Presets de Windows (y, si se quiere, Linux): iconos, versión, `data/*.rooms`, `data/*.torres` y `data/modelos/*` incluidos; sin el solucionador nativo (cae a GDScript sólo para los tramos de respiro).
- Script de construcción (`construir_demo.ps1`): exporta, copia, comprime y calcula el tamaño.
- Prueba en una máquina limpia: instalar, abrir, jugar la demo entera, cerrar, volver a abrir y continuar.
- Registro de cambios y número de versión.

## Cronograma estimado (trabajo en una sola sesión de desarrollo, en orden)

| Orden | Bloque | Tamaño |
|---|---|---|
| 1 | A. Cierre de lo hecho | chico |
| 2 | C. Banco de torres y carga | mediano |
| 3 | B. Tutorial nuevo | mediano |
| 4 | E. Números grandes y juice | mediano |
| 5 | D. Fin de la demo | chico |
| 6 | F. Robustez y opciones (sin mando) | mediano |
| 7 | I.1 a I.2 Formato y variantes de cubos | mediano |
| 8 | I.3 a I.5 Editor de modelos | **grande** |
| 9 | J. Contenido (en segundo plano desde el paso 2) | mediano |
| 10 | K. Localización y créditos | chico |
| 11 | G. Prueba con gente | depende de Dante (coordinar) |
| 12 | H. Arreglos | mediano |
| 13 | L. Exportación | chico |

## Riesgos

- **El balance depende de gente real:** la tasa de muerte y lo que se entiende del duende son suposiciones; por eso G y H tienen un margen aparte.
- **El editor de modelos puede comerse todo el tiempo:** conviene fijar un alcance mínimo (bloques y cosméticos) y dejar personajes para después si hace falta.
- **Generación en vivo en el juego final:** el banco resuelve la demo; para el juego final hay que seguir optimizando la generación o armar bancos grandes.
- **Rendimiento con modelos más detallados:** más minibloques por cubo cuestan más al dibujar; hay que medirlo (el límite es de 5×5×5 por bloque).

## Decisiones a confirmar

1. Qué etapas entran en la demo (propuesta: 1 a 7).
2. Alcance del editor de modelos para la demo (propuesta: bloques con variantes + cosméticos; personajes si hay tiempo).
3. Si la demo incluye las monedas y las jugadas mínimas del casino o no (propuesta: no, se dejan para el juego final).
4. Si entra el mando en la demo (propuesta: no).
