# El panel de información

Propuesta de diseño (nada está programado). Idea de Dante: una **ventana lateral**, como en Payday, que aparece por la izquierda al **mantener apretado Tab** y trae toda la información de la partida. Con eso el HUD queda simple y la pausa vuelve a ser un menú de botones.

## El problema

- **La pausa ya no tiene lugar:** lleva el título, seis botones, la etapa y el peaje a la izquierda, los contratos a la derecha y el cartel de la prueba abajo. A 1280 x 720 el título se corta arriba, el último botón pisa el cartel y la descripción de la prueba choca con la guía de controles.
- **La información está repartida** entre la pausa, el HUD y el cartel de la prueba, y la mayoría solo se ve pausando.

## Las decisiones

| Tema | Decisión |
|---|---|
| Qué es | Un **panel por la izquierda**, con el marco de cubitos del juego, que se desliza al mantener Tab |
| Qué queda en el HUD | **Vidas, consumibles y boosts** (la columna de la derecha). Nada más |
| Qué se va del HUD | La **claridad** y los **movimientos** pasan al panel |
| Qué se va de la pausa | La etapa, el peaje, los contratos y el cartel de la prueba: todo pasa al panel. La pausa queda **solo con el título y los botones**, centrada |
| Tab | Abre el panel. La **vista de toda la torre**, que hoy usa Tab, pasa a **V** |
| V hoy | Hoy V cambia la **ayuda de profundidad** (ninguna, más claro lo cercano, o eso con transparencia). Esa elección pasa a **Opciones**, y V queda libre |
| Mantener o alternar | **Opciones → General → "Panel de información"**: mantener (apretado se ve, soltado se va) o alternar (un toque lo abre y otro lo cierra) |
| El cartel de la prueba | Queda **solo al empezar la torre** (como hoy). Ya no se repite al pausar: la prueba se lee en el panel |

## Cómo se vería

El boceto de la derecha es el mismo juego con Tab apretado: el HUD sigue ahí y el panel tapa solo el lado izquierdo.

## Qué lleva el panel

De arriba abajo:

1. **El escenario y la dificultad** ("La Pesadilla - Medio").
2. **Etapa y sala:** "Etapa 3 / 15 · Sala 2 / 7".
3. **Claridad:** la que juntaste (y la racha, si hay).
4. **Movimientos:** "12 / 20" de la sala (en Fácil, sin límite).
5. **Peaje** de la etapa, en rojo si no alcanza.
6. **La prueba** (si hay): nombre y la descripción completa, sin límite de ancho ni de líneas.
7. **Los contratos activos,** con su título y su condición completos. Ya no hace falta pasar el mouse por encima de cada ícono, como hoy en la pausa.
8. **Las reglas del escenario** que lo piden (por ejemplo los movimientos en falso de El camino corto).

Los boosts siguen en el HUD (los íconos de la derecha); más adelante el panel podría listar su nombre y su descripción.

## En el casino

El panel también se abre en el casino, con lo que sirve ahí: claridad, etapa, peaje, contratos y la prueba que viene. Así el tablón y las mesas no necesitan ese texto aparte.

## Los controles

| Acción | Teclado | Mando |
|---|---|---|
| **Panel de información** (nueva) | **Tab** | **Select** (se propone; ver abajo) |
| **Vista de toda la torre** (hoy Tab, fija) | **V**, **reasignable** | sin botón (se puede asignar) |
| **Pausa** | Esc | Start (como ahora) |

- **Select hoy** reintenta la torre. Eso pasa a hacerse **solo desde la pausa** (ya está ahí), lo que además evita reintentar sin querer apretando un botón del centro del mando.
- **Por qué no un gatillo o hombro:** todos están usados. LB y RB giran la vista (Q y E), LT es empujar, RT usa el consumible, y los clics de los sticks son el zoom.
- **El problema de Select con el mando:** con el pulgar en el stick no se puede mantener apretado a la vez. Para el mando conviene el modo **alternar**; por eso la opción es configurable. (Si más adelante se prefiere otro botón, se reasigna desde Opciones → Controles.)
- Las acciones nuevas son **reasignables** (`panel_info` y `vista_torre`) como las demás.

## Opciones

- **Panel de información:** mantener o alternar (por omisión, **mantener**).
- **Ayuda de profundidad:** las tres opciones que hoy cambia V, ahora como un selector en Opciones (junto a la transparencia del personaje).

## Lo que se aprende

El tabernero enseña la tecla (y cada ayuda de teclas, `H`) en el tutorial, porque el HUD no lleva texto de ayuda. No hay carteles en pantalla recordando Tab.

## Cómo se haría

1. **Una pantalla nueva** (`scripts/ui/panel_info.gd`): marco de cubitos, entra y sale deslizándose por la izquierda (unos 0,15 s), con los datos que le pasa `main.gd`.
2. **Controles:** acciones `panel_info` y `vista_torre` en `controls.gd`; la que usaba Tab fijo en la torre pasa a ser reasignable; Select deja de reintentar.
3. **HUD:** se sacan la claridad y los movimientos del marco de arriba a la izquierda.
4. **Pausa:** se saca la columna de la izquierda, el cartel fijado y el corrimiento del menú; queda el título y los botones.
5. **Opciones:** el selector de la ayuda de profundidad y el del modo del panel.
6. **Cartel de la prueba:** solo al empezar.
7. **Textos** en español neutro y en inglés; pruebas del panel, de los controles y de la pausa; `docs/interfaz_mando.md`.

Cada paso se puede probar por separado, y la pausa se puede arreglar antes de sacar nada del HUD.

## Preguntas abiertas

1. **Claridad ganada:** al pisar un bloque sale el cartel de ganancia (por ejemplo "+10"), que se queda en el HUD. ¿Alcanza para ver cuánta claridad se junta, o quieres también un número chico fijo?
2. **Movimientos cerca del límite:** hoy, con 5 o menos, el número aparece sobre el personaje; se mantiene.
3. **Boosts en el panel:** ¿lo dejamos para más adelante o va ya, con el nombre y la descripción de cada uno?

## Panel de boosts y consumibles

Se abre junto con el de información con la misma tecla (Tab, o Select en el mando), por la derecha: lista cada boost y consumible con su ícono y su descripción. Con cualquiera de los dos abiertos la torre no se juega (sólo se mueve la cámara). El HUD de la torre queda con vidas, consumibles y boosts.
