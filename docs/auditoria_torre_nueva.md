# Auditoría: qué se perdió al pasar el juego a la torre nueva

Rama `feature/torre-nueva-en-el-juego`. Se comparó, función por función, lo que hacía `scripts/main.gd` con la torre vieja (`TowerLogic`) contra lo que hace hoy la torre nueva (`salas_nuevas/torre_juego.gd`, `torre.gd`, `cosecha.gd`, `falsos.gd`).
**Cómo leer las marcas:** *(leído)* = lo comprobé leyendo el código, no jugando; *(probado)* = hay una prueba automática; *(sin probar)* = no lo pude comprobar.

## 1. Cambios de reglas que ya estaban decididos (no son errores, pero cambian el juego)

| Antes | Ahora |
|---|---|
| La fila de abajo caía cada N movimientos | Cada sala tiene un temporizador de movimientos; al agotarse cae la sala entera |
| La torre era una pila de salas alrededor de un núcleo con piso | Anillo de 11x11 con vacío de 5x5, sin piso, salas apiladas en espiral |
| Las pruebas (cada 3 etapas) cambiaban las reglas | Ver 2.4: la mayoría no hace nada |

## 2. Lo que se perdió o no funciona

### 2.1 Cosas del juego que desaparecieron (las más importantes)

1. **Los dados de la pantalla de carga** *(leído)*. El minijuego de dados se abría mientras se generaba la torre (`_await_job` abre `dice.open()` sólo mientras `generating` es verdadero). La torre nueva se arma al instante, así que esa pantalla ya no aparece y se pierden sus premios (Luz y cosméticos) y el `_claim_dice_rewards`. Es lo más grave de la lista, porque es parte del ciclo del juego.
2. **Los avisos del tabernero de bloque nuevo** (`BlockGuide`) *(leído)*. Antes, al llegar a la altura de un bloque nunca visto, el juego frenaba y el tabernero lo explicaba. Con la torre nueva nunca se llama (depende de `logic`). Como los especiales se habilitan por etapa (hielo en la 2, pesado en la 3...), el jugador los encuentra sin explicación.
3. **Todos los sonidos de las acciones** *(leído)*: pisada, empujar, tirar, trepar, colgarse, resbalar, salto de catapulta, trampa que se rompe, pinchos, caída, explosión, desactivar bomba, portal, y el tic-tac de las bombas. La torre nueva sólo suena en el checkpoint ("item") y al perder.
4. **Los efectos visuales de las acciones** *(leído)*: estirar y aplastar al pisar y aterrizar, los bloques que se asientan, los bloques que caen al vacío girando, las partículas al purificar, el cartel "+N claridad / racha ×N / cosecha ×N", la animación de explosión de una bomba, el destello dorado y el golpe de zoom al ganar, y las partículas de la cara de arriba de cada bloque. Hoy los bloques que caen simplemente desaparecen.
5. **El cubo-portal del final de la torre** *(leído)*: el cubo luminoso con bordes dorados y las ondas, que además se apagaba y se encendía según si alcanzaba para pagar el peaje. En la torre nueva el último checkpoint es un bloque dorado común.
6. **El aspecto por etapa** *(corregido)*: el fondo y la luz se aclaraban con la etapa (`_apply_stage_look`); la torre nueva no lo llamaba. Ya está llamado. El tinte de los bloques por etapa sigue sin estar: los bloques purificados son siempre azules.
7. **La ayuda de profundidad** (tecla "profundidad" y el foco de profundidad) *(leído)*: sigue calculándose con el personaje y la cámara de la torre vieja, así que con la torre nueva el foco está desfasado. La tecla no hace nada en la torre nueva (V muestra la torre entera).

### 2.2 Estadísticas y registros

- **Telemetría local** (`telemetria.jsonl`, evento "torre") *(leído)*: no se anota nada de las torres nuevas (sí el casino, el peaje y el fin del run). Se pierde la calibración con jugadores reales.
- **"Movimientos" del resumen final del run** *(corregido)*: no sumaba. Ahora suma.
- **Guardar y continuar con la sala perdida** *(corregido)*: no guardaba que se había muerto, así que salir y volver no costaba la vida.

### 2.3 Boosts, consumibles y habilidades de la torre

Funcionan *(probado o leído)*: Cosecha, Cosecha doble, Pies de luz, Pies de oro, Midas, Buen ojo, Mano de oro, Racha larga, Racha imparable, Luz propia, Escalador, Empuje rentable, Ahorro, Bolsillo de luz, Reflejos, Paso firme, Madrugada, Aire extra, Segundo aliento; y los consumibles Poción de cosecha, Baraja de racha, Freno, Reloj de arena, Imán de luz, Lluvia de luz, Desarmar, Vida extra, Tótem y Soborno.

**No funcionan** (el consumible avisa y no se gasta; los boosts quedan sin efecto):

| Qué | Por qué |
|---|---|
| Ojo de hielo | No está implementado en el motor nuevo |
| Escudo | La bomba que explota sigue perdiendo la sala; el escudo no la absorbe |
| Doble salto, Teletransporte, Ancla chica | Sin implementar |
| Los 8 conversores (roca, hielo, agrietado, trampa, pinchos, pesado, bomba, catapulta) | Piden elegir un bloque con el mouse (la elección de bloque está atada a la torre vieja) |
| Habilidad "Pies ligeros" y la mejora permanente "Aire de más" | Sumaban a la caída de la fila; no se tradujeron al temporizador |
| Habilidad "Fuerza bruta" | El motor nuevo no deja empujar bloques pesados |

**Con la descripción desactualizada** *(leído)*: las descripciones del catálogo todavía hablan de la caída de la fila ("La fila de abajo cae al doble de lento", "Trepar y bajar... no cuenta para la caída", "Pausa la caída de la fila base 5 movimientos", "Una vez por etapa, si caes al vacío vuelves a la última plataforma firme"...). Hoy esos efectos actúan sobre los movimientos de la sala (y Segundo aliento es una vez por torre y reinicia la sala).

### 2.4 Pruebas y escenarios

- **Pruebas con reglas propias** *(leído)*: Niebla, Oscuridad y Lluvia de meteoritos aparecen en el cartel pero no hacen nada. Sí funcionan Sin ayudas, Todo o nada, Sin racha y el multiplicador de claridad.
- **Ritmo de la etapa y sesgo de bloques de cada escenario** *(leído)*: Relojería ("rápido") o los sesgos del generador no se aplican a la torre nueva. Hoy sólo se pueden elegir La Pesadilla y Sin piedad, así que casi no se nota.

### 2.5 Herramientas y modos que siguen con la torre vieja o no la conocen

- **El bot de balance** (`bot.gd`, `bot_runs.gd`) no juega la torre nueva: las estadísticas de balance que sacaba ya no valen.
- **El laboratorio** y **las 6 primeras lecciones del tutorial** siguen con la torre vieja (la última lección sí es nueva).
- **La demo** juega torres armadas del paquete: se perdió el banco de torres curadas (`torres_demo.torres`) *(leído, sin probar en una demo exportada)*. El paquete de salas viaja en `data/salas_torre.jsonl`, que el filtro de exportación ya incluye.
- **Consola de desarrollo**: los comandos que tocan `logic` (ganar, perder, etc.) no hacen nada con la torre nueva; cambiar de etapa sí funciona *(leído, sin probar)*.

## 3. Lo que sí se conserva *(probado salvo que diga lo contrario)*

Claridad con racha y cosecha (mismas reglas), peaje de Farolín y el casino, vidas del run, pantalla de derrota con Reintentar (−1 vida) y salir al menú (nueva), deshacer, Sin piedad con sus movimientos en falso, mando y controles reasignables (el mando entra como teclas; no probé un mando físico), personaje y cosméticos del perfil, música por etapa, HUD del juego, guardado, Farolín en cada checkpoint, la última lección del tutorial.

## 4. Orden en que conviene recuperarlo (propuesta)

1. Dados de la pantalla de carga (decidir cómo: una pantalla corta de dados al empezar cada torre).
2. Avisos del tabernero de bloque nuevo.
3. Sonidos de las acciones y de las bombas.
4. Efectos visuales (los bloques que caen, purificar, el cartel de claridad, explosión) y el cubo-portal.
5. Escudo, Ojo de hielo y los conversores (con la elección de bloque).
6. Textos de las descripciones y las habilidades "Pies ligeros" / "Fuerza bruta".
7. Telemetría de la torre nueva y reescribir el bot para la torre nueva.
8. Pruebas con reglas propias (niebla, oscuridad, meteoritos).
