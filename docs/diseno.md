# Diseño del juego (estado vigente)

Balatro x Catherine: puzzle de torres de bloques (estilo Catherine) con casino y economía de boosts (estilo Balatro), en Godot 4.7.2. Este documento describe cómo es el juego hoy; los números de balance están en `economia.md`, los premios en `catalogo.md`, las reglas exactas de la torre en `reglas_torre.md` y lo aprendido en el camino en `aprendizajes.md`.

## Estructura de una partida

- 15 etapas. Cada etapa: una **torre**, un **casino** y el peaje de **Farolín**. Cada 3 etapas hay una **prueba** (reglas especiales que se ven desde el principio).
- **Vidas** (3): perder una sala no cuesta claridad, cuesta una vida; sin vidas termina el run. Reintentar desde la pausa cuesta 1 vida.
- **Escenarios** (`scripts/datos/scenarios.gd`): se juegan el tutorial, **La Pesadilla** (con cuatro dificultades: Fácil, Medio, Difícil y Pesadilla) y **Sin piedad**; los demás dicen "Próximamente". Los de pago cuestan **Luz**.
- **Sin piedad** (`torre/falsos.gd`): cada sala permite 2 movimientos en falso (el que deja más pasos para salir de la sala, medido con el solucionador nativo sobre el estado recortado, en un hilo); al tercero se pierde una vida; no se puede deshacer. Un movimiento que no se alcanza a medir nunca se castiga.

## La torre

Resumen (detalle en `reglas_torre.md`): un anillo de 11x11 alrededor de un vacío de 5x5, salas de 3x3, 5x3 u 8x3 apiladas en espiral, sin suelo, con un único bloque fijo por sala. Cada sala tiene un **bloque de entrada y uno de salida (checkpoints)** y un **temporizador de movimientos**: el mínimo lo da el solucionador y el margen baja con la etapa y la dificultad (`Torre.max_movimientos`); al agotarse o caer se pierde la sala (vuelve al checkpoint con la torre virgen). Los últimos 5 movimientos se ven como un número sobre el personaje; no hay texto de depuración en el HUD.

- **Dificultad** (`Torre.niveles_para`): la curva de niveles de las salas sube por etapa; `PENDIENTE_DIFICULTAD` la corre según la dificultad elegida, `limites_aprendizaje` limita altura y largo en las primeras etapas (sobre todo en Fácil y Medio) y `MARGEN_DIFICULTAD` cambia el margen de movimientos. Los bloques especiales se habilitan de a poco (`ETAPA_ESPECIAL`: hielo, pesado, agrietado, trampa, pinchos, bomba, catapulta) y el tabernero avisa al descubrir uno nuevo.
- **Claridad** (`torre/cosecha.gd`): valor por bloque purificado, racha y boosts de cosecha; se asegura en cada checkpoint y se pierde la del intento al morir.
- **Biblioteca de salas:** `data/salas_torre.jsonl` (1208 salas), generada con `native/salas.cpp` (`generador.md`). El juego arma cada torre en el momento (`Torre.armar`, determinista por semilla); la demo también.
- Las pruebas con reglas propias (Niebla, Oscuridad, Lluvia de meteoritos, Prisa, Hielo total, Quebradizo…) y varios premios y escenarios se retiraron junto con la torre vieja: hoy hay tres pruebas (Sin ayudas, Todo o nada, Sin racha). Las ideas pendientes están en `pendientes.md`.

## Casino

- Cuatro casinos por nivel (taberna, salón, casino, gran casino), con mesas que se suman por nivel: ruleta, tragamonedas con retener, blackjack. Mármol cálido en los grandes; las mesas se "purifican" con el nivel.
- **Regla de la casa** por nivel (`casino_rules.gd`): ninguna en la taberna; Racha en el salón; Apuesta libre en el casino; Jackpot en el gran casino. **Servicio** por nivel (`casino_services.gd`): Taller en el salón, Caja fuerte en el casino.
- **Balance del casino** (`casino_balance_screen.gd`): al salir se ve una tabla por mesa de lo jugado, ganado y perdido.
- **Farolín** (`scripts/personajes/farolin.gd`): farol con patas junto a la puerta de salida (celda libre de muebles en los cuatro casinos). Al llegar a la puerta o caminar hacia él se abre su diálogo con las decisiones (cada opción muestra su tecla —1, 2, 3— o su botón del mando); después dice una frase (`Farolin.REACTIONS`).
- **Dados de la pantalla de carga** (`dice_game.gd`): una predicción de 5 dados y 3 tiradas; los aciertos quedan retenidos. Premios: claridad y, con 4 o 5 aciertos, cosméticos. Van siempre (también cuando la torre ya está lista).
- **Tabernero** (cuadro de diálogo de cubitos, `dialogue_box.gd`): toda voz de un personaje usa ese cuadro; los avisos chicos (`_flash`) quedan para lo que no tiene voz.

## Meta-progresión

- **Luz** (`profile.gd`): moneda única que sirve para entrar a escenarios de pago; premia escapar (ver `economia.md`).
- **Habilidades persistentes** (`abilities.gd`): se ganan al escapar de la pesadilla en un escenario; valen en todos.
- **Personajes** (Dante, Gaby, gatito, perrito, conejito) y **ropa** (gorro y prenda, tres rarezas), elegibles en la pantalla Personaje. Modelos reemplazables desde el editor de modelos (`editor_modelos.md`).

## Interfaz

- **Teclas** (`interfaz_mando.md`): Espacio confirma, Shift es la decisión secundaria, C la tercera, Esc vuelve; menús con flechas o WASD. Con mando A=Espacio, X=Shift, Y=C, B=Esc. Botoneras abajo en cada pantalla, cuadro de confirmación para abandonar o empezar otra partida sobre una sin terminar.
- **En la torre:** controles reasignables (`Controls`); Shift + dirección sin nada que empujar ni tirar es un paso común; con un bloque trabado no camina. Deshacer cuesta claridad. Cámara isométrica que sigue al personaje y se puede rotar por debajo del horizonte; rosa de los vientos opcional.
- **HUD** (`hud_panel.gd`): marco de cubitos con vidas, etapa, claridad y movimientos; **cartel de la prueba** (`trial_banner.gd`) grande abajo, sin fondo, que se desvanece y se muestra entero al pausar. Números grandes con `NumberFormat` (mil, M, B…).
- **Idiomas** (`scripts/idioma/loc.gd`): español neutro (tuteo, sin voseo; lo vigila `test_neutro.gd`) e inglés. La clave es la frase en español: `Loc.t("Nueva partida")`; patrones con datos con `Loc.f`. `test_loc.gd` recorre las pantallas en inglés y falla si queda algo sin traducir.
- **Opciones:** idioma, ventana o pantalla completa, resolución, sincronía vertical, volúmenes (general, música y efectos), controles y estilo de botones, modo de lectura y alto contraste.
- **Música** (`musica.md`): Las Cuatro Estaciones de Vivaldi en chiptune (menú, torre, casino, pruebas); los efectos están sintetizados por código (`synth.gd`, `sfx.gd`).

## Tutorial

Taberna con el tabernero que cuenta el lore (la torre hecha de recuerdos corruptos, la claridad) y manda al portal de atrás. Las lecciones son salas dibujadas por capas con `Tutorial.sala_de_capas`, verificadas con el solucionador, que se juegan con el motor real de la torre; la ayuda de teclas (`key_hint.gd`) se dibuja con botones del mando cuando se juega con mando. El cierre explica la claridad, el casino, las pruebas, las habilidades y la Luz.

## Demo de Steam

El mismo código con un interruptor (`Demo.on()`); ver `demo.md`.

## Telemetría

Local (`telemetry.gd`, `user://telemetria.jsonl`, nada se envía): eventos de sala, torre, casino, peaje y fin del run, para calibrar el balance con jugadores reales.

## Reglas de trabajo del diseño

- Los sistemas grandes se conversan antes de programarlos.
- No poner ayuda ni texto de depuración en el HUD.
- La dificultad de una torre se juzga mirando el juego y con la métrica de **bloques distintos movidos**.
