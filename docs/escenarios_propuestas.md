# Escenarios: propuesta (los escenarios cambian reglas, no temas de salas)

**Implementado** (rama `escenarios/reglas`; pruebas en `tests/unitarios/test_escenarios_reglas.gd`). Los números son de partida y se calibran jugando. Hoy se juegan tres (Tutorial, La Pesadilla y Sin piedad, que acá pasa a llamarse **El camino corto**) y cinco dicen "Próximamente" con descripciones de antes de la torre actual (`scripts/datos/scenarios.gd`, `catalogo.md`).

## La decisión: los escenarios cambian las reglas del juego, no los temas de salas

Se descartó que un escenario elija salas por tema (Polvorín solo con bombas, Glaciar con hielo...). Con la biblioteca actual no alcanza para que las torres sigan pareciendo aleatorias:

- Una partida usa unas **140 salas** (de 5 en la etapa 1 a 14 en la 15; las dos primeras de cada torre son comunes y cada sala tiene que encajar con la anterior).
- Hay 272 salas con bomba (47 de Pesadilla), 402 con hielo, 287 con agrietado, 121 con pesado, 161 con pinchos y 168 con trampolín (6 de Pesadilla). Una torre solo de un tema gastaría más de la mitad del grupo en una partida y se repetiría enseguida.

Por eso **ningún escenario elige un tema de salas**: la elección sigue siendo la de `Torre.armar` (curva de dificultad y especiales que se habilitan por etapa) y cada escenario cambia **cómo se juega**: vidas, movimientos, economía, contratos, y en un caso qué tan temprano llegan los especiales y con qué frecuencia (Mundo abierto, sin favorecer ningún especial en particular). Así la aleatoriedad de las torres se conserva y los escenarios no dependen de generar más salas.

## Qué es un escenario

Como un mazo de Balatro: un cambio de reglas que se siente al jugar, que se paga con Luz para entrar y que da una **habilidad persistente** al escapar (valen en todos los escenarios). Cada uno define su entrada en Luz, el multiplicador de Luz, qué pruebas pueden salir (`pool`) y, si hace falta, parámetros de reglas (hoy: `lives`, `permadeath`, `no_totem`, `no_extra_life`, `mistakes`, `no_undo`, `price_mult`, `casino_tier`).

Las entradas y los multiplicadores de Luz siguen el rango actual (de 15 a 35 de entrada y de ×1,4 a ×2,2); son de partida y se calibran jugando.

## Dificultades

**La Pesadilla** tiene las cuatro (Fácil, Medio, Difícil y Pesadilla), como hoy. **Los demás escenarios tienen solo Medio, Difícil y Pesadilla**: sin Fácil. Fácil es el modo de práctica de La Pesadilla (movimientos ilimitados y modo pista) y con eso las reglas propias de un escenario perderían sentido (Relojería no recorta movimientos que no se cuentan, y los movimientos en falso de El camino corto no pesan con una pista a mano).

Los tres niveles usan la misma curva de niveles de las salas (`PENDIENTE_DIFICULTAD`) y los mismos márgenes de movimientos (`MARGEN_DIFICULTAD`) que en La Pesadilla. La dificultad se elige al empezar, después del escenario.

## Los siete escenarios

| Escenario | Regla | Entrada | Luz | Habilidad | Estado |
|---|---|---|---|---|---|
| El camino corto | 2 movimientos en falso por sala (Sin piedad, con otro nombre); no se deshace | 25 | ×2,0 | Margen de error | implementado |
| Compromiso | una sola vida; sin Tótem ni Vidas extra | 35 | ×2,2 | Corazón extra | implementado |
| Gran Casino | casino de lujo desde el principio y ficha más barata; torres más difíciles | 30 | ×1,4 | Bolsillo de soñador, Segunda oportunidad | implementado |
| Relojería | menos movimientos por sala; ficha más barata | 25 | ×1,8 | Pies ligeros | implementado |
| Contratista | el tablón manda: más contratos, fianzas y recompensas mayores | 20 | ×1,5 | Buena letra | implementado |
| Mundo abierto | todos los especiales se habilitan desde la etapa 1 | 30 | ×2,0 | Mecha larga | implementado |
| Usurero | Farolín cobra más, pero el casino paga más | 20 | ×1,5 | Buen regateo | implementado |

### El camino corto (ya jugable como Sin piedad)
Es el escenario de la **precisión**: el mejor camino de cada sala es el que mide el solucionador, y alejarte de él se paga. Se le cambia el nombre (Sin piedad sonaba a castigo, y Compromiso ya es el escenario de la supervivencia: una sola vida). Cada sala permite 2 movimientos en falso (el que deja más pasos para salir); al tercero se pierde una vida. No se puede deshacer. Pruebas: Sin ayudas, Sin racha. Habilidad: **Margen de error** (3 movimientos en falso en lugar de 2). Solo cambia el nombre que se ve (en el código puede quedar el id `sin_piedad` para no romper partidas guardadas ni el perfil), y el texto en español, en inglés y en el catálogo.

### Compromiso
Una sola vida y no valen el Tótem ni las Vidas extra: perder una sala termina el run. Es el más duro y el más cercano a la muerte permanente. Ya está en el código (`lives: 1`, `permadeath`, `no_totem`, `no_extra_life`). Pruebas: Sin ayudas, Sin racha. Habilidad: **Corazón extra** (una vida más en todas las partidas, 4 corazones; no cuenta en Compromiso). *Falta:* la habilidad (`Abilities.PENDING`) y reescribir el texto del escenario.

### Gran Casino
El casino es de lujo desde el principio (`casino_tier: 3`) y la ficha cuesta un 20 % menos (`price_mult: 0.8`), pero las torres son más difíciles: toda la curva de niveles corre un escalón por encima de la dificultad elegida (con tope en Pesadilla). Pruebas: Sin ayudas, Todo o nada, Sin racha. Habilidades: **Bolsillo de soñador** (un lugar más para consumibles) y **Segunda oportunidad** (reintentar la torre cuesta un 15 % menos). *Falta:* el corrimiento de dificultad por escenario y las dos habilidades.

### Relojería
Cada sala da menos movimientos: el margen por sobre el mínimo (el factor y los movimientos extra de `Torre.max_movimientos`) se reduce a la mitad, a la manera de `MARGEN_DIFICULTAD`. A cambio, la ficha de la ruleta es más barata (×0,75, ya soportado). Pruebas: Todo o nada, Sin racha. Habilidad: **Pies ligeros** (cada sala tiene un movimiento más). *Falta:* un `MARGEN_ESCENARIO` junto a `MARGEN_DIFICULTAD`, y la habilidad.

### Contratista
El tablón de contratos pasa al centro. Hay **4 contratos activos a la vez** en lugar de 2, el tablón cuelga más papeles por visita, las fianzas son un 50 % más altas y las recompensas un 50 % mayores: más para ganar, más para perder. El casino y los contratos ya existen; el escenario ajusta sus números. Pruebas: Sin ayudas, Sin racha. Habilidad nueva: **Buena letra** (un contrato fallido por run devuelve su fianza). *Falta:* parámetros de contratos por escenario (activos, fianza y recompensa) y la habilidad.

### Mundo abierto
Los bloques especiales pueden salir en cualquier etapa (en todos los escenarios). La selección de salas sigue siendo aleatoria, entre un grupo mucho más ancho. Además **aparecen más salas con especiales**: hoy salen en proporción al grupo (el 42 % de las 2855 salas tiene algún especial) y en este escenario sube a más o menos el **60 %**, de cualquier clase (no de un tema: hielo, bomba, agrietado... salen todos mezclados como siempre). Son unas 85 salas con especiales por partida de las 1.191 que hay, así que no se repite. El peso es un empujón y no una regla: si no hay salas del nivel que toca, se cae a las comunes. Los límites de aprendizaje de las primeras etapas (altura, pasos y bloques distintos) se mantienen, y las dos primeras salas de cada torre siguen siendo comunes. El tabernero avisa de cada bloque la primera vez que aparece, aunque sea en la etapa 1. Es el de más aprendizaje: la Luz es alta (×2,0). Pruebas: Sin ayudas, Todo o nada. Habilidad: **Mecha larga** (las cuentas de las bombas empiezan 3 movimientos más altas): tiene sentido acá porque las bombas llegan antes. *Falta:* que el escenario pueda cambiar la etapa de habilitación de los especiales, un peso de salas con especiales en `Torre.armar` (el orden de candidatas hoy no mira la categoría) y la habilidad. El bloque trampa queda fuera (en pausa).

### Usurero
Farolín cobra un 40 % más en cada peaje, pero el casino paga más: la ficha cuesta un 30 % menos y los premios de las mesas valen un 25 % más. Para quien disfruta el casino y se anima a jugarlo. Pruebas: Sin ayudas, Todo o nada. Habilidad nueva: **Buen regateo** (el peaje de Farolín cuesta un 10 % menos). *Falta:* un multiplicador de peaje y uno de premios por escenario (el precio de la ficha ya existe) y la habilidad.

## Habilidades

| Habilidad | Efecto | Escenario |
|---|---|---|
| Margen de error | un movimiento en falso más en El camino corto (3 en lugar de 2) | El camino corto (ya existe) |
| Corazón extra | una vida más en todas las partidas | Compromiso |
| Bolsillo de soñador | un lugar más para consumibles | Gran Casino |
| Segunda oportunidad | reintentar la torre cuesta un 15 % menos | Gran Casino |
| Pies ligeros | cada sala tiene un movimiento más | Relojería |
| Buena letra | un contrato fallido por run devuelve su fianza | Contratista (nueva) |
| Mecha larga | las cuentas de las bombas empiezan 3 movimientos más altas | Mundo abierto |
| Buen regateo | el peaje de Farolín cuesta un 10 % menos | Usurero (nueva) |

Las cinco habilidades que estaban pendientes (`Abilities.PENDING`) se reparten así, y se agregan dos nuevas. Las de La Pesadilla (Mente despejada, Ojos de gato, Racha firme) no cambian.

## Qué se hizo en el código (resumen)

| Pieza | La usan |
|---|---|
| Corrimiento de dificultad por escenario | Gran Casino |
| `MARGEN_ESCENARIO` (recorte de movimientos) | Relojería |
| Parámetros de contratos por escenario | Contratista |
| Etapa de habilitación de los especiales por escenario y peso de las salas con especiales en `Torre.armar` | Mundo abierto |
| Selector de dificultad (Medio, Difícil y Pesadilla) en los escenarios que no son La Pesadilla | todos |
| Cambiar el nombre de Sin piedad a El camino corto (texto, inglés, catálogo) | El camino corto |
| Multiplicador de peaje y de premios | Usurero |
| Las siete habilidades nuevas | todos menos El camino corto |

Las piezas están en `Scenarios`, `RunState`, `Torre`, `Contratos`, `CasinoVisit` y `Abilities`; el catálogo se regeneró y las frases tienen su traducción al inglés.

## Ideas para después

- **Hemorragia:** la claridad que no está asegurada en un checkpoint baja con cada movimiento. Obliga a ir rápido.
- **Racha o nada:** la claridad solo se gana con racha, con un multiplicador mayor, y se corta con cualquier retroceso.
- **Doble o nada:** purificar da el doble de claridad, pero pisar un bloque ya purificado resta.
- **Sin red:** sin checkpoints entre salas. Toca la estructura de la torre, así que hay que pensarlo con cuidado.

## Preguntas abiertas

1. **Desbloqueo:** hoy se pagan con Luz y están todos disponibles. Alternativa: escapar en uno abre el siguiente.
2. **Pruebas:** los escenarios eligen su pool de un grupo de tres (Sin ayudas, Todo o nada, Sin racha). ¿Hace falta alguna prueba propia de un escenario?
3. **Números:** las entradas y los multiplicadores de Luz son de partida; se calibran jugando, no con el bot.
4. **Orden de construcción:** lo más barato es Compromiso (solo la habilidad), seguido de Relojería, Contratista y Usurero. Mundo abierto y Gran Casino piden más piezas nuevas.
