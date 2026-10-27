# Escenarios: propuestas para repensarlos

Borrador para conversar: nada de esto está programado. Hoy se juegan tres (Tutorial, La Pesadilla y Sin piedad) y cinco dicen "Próximamente" con descripciones de antes de la torre actual (`scripts/datos/scenarios.gd`, `catalogo.md`).

## Qué es un escenario

Como un mazo de Balatro: **un cambio que se sienta distinto** al jugar, que se paga con Luz para entrar y que da una habilidad persistente al escapar. Cada uno define: entrada en Luz, multiplicador de Luz, qué pruebas pueden salir (`pool`), qué habilidades se pueden ganar y, opcionalmente, vidas, ficha, casino, errores permitidos o si se puede deshacer.

Tres familias de cambio (cada escenario cambia **una**, a lo sumo dos):

- **Salas:** qué especiales aparecen y cuáles abundan. Se apoya en la biblioteca de 2855 salas.
- **Reglas del run:** vidas, movimientos, errores, deshacer.
- **Economía:** ficha, casino, contratos.

## Qué cambió desde que se escribieron

1. **La dificultad ya es un selector aparte** (Fácil, Medio, Difícil, Pesadilla) dentro de La Pesadilla. Un escenario no puede ser "lo mismo, más difícil": tiene que ser distinto.
2. **La biblioteca ya viene por tema.** Salas con cada especial, por nivel:

| Especial | Salas | Fácil | Media | Difícil | Pesadilla |
|---|---|---|---|---|---|
| Hielo | 402 (229 con línea de 3 o más) | 108 | 117 | 126 | 51 |
| Bomba | 272 | 73 | 76 | 76 | 47 |
| Agrietado | 287 | 108 | 64 | 79 | 36 |
| Pinchos | 161 | 33 | 33 | 53 | 42 |
| Pesado | 121 | 26 | 31 | 39 | 25 |
| Trampolín | 168 | 84 | 48 | 30 | 6 |
| Sin especiales | 1664 | | | | |

   Por eso un escenario de salas puede elegir de su categoría sin quedarse corto: el único flojo es **Trampolín en Pesadilla** (6 salas) y **Pesado** en general (121).
3. **Hay sistemas nuevos con los que jugar:** contratos y tablón, la ficha chica, los cuatro casinos y el Taller.
4. **Trampa en pausa:** no hay salas con trampa, así que ningún escenario puede depender de ella.

## Las propuestas

Las entradas y los multiplicadores de Luz siguen el rango actual (de 15 a 35 de entrada y de ×1,4 a ×2,2); son de partida y se calibran jugando.

### Ya jugables

**La Pesadilla** (gratis, ×1). Sin cambios: es el juego base. Habilidades: Mente despejada, Ojos de gato, Racha firme.

**Sin piedad** (25 de Luz, ×2). Sin cambios: 2 movimientos en falso por sala, no se deshace. Habilidad: Margen de error.

### Escenarios de salas

**Polvorín** (20 de Luz, ×1,6). Las bombas dominan: cada sala del escenario es una de las 272 salas con bomba (y algunas mixtas con bomba). Desde la etapa 1, sin esperar a la 7 (la bomba se explica ahí con el tabernero). Pruebas: Sin ayudas. Habilidad propuesta: **Mecha larga** (las bombas empiezan con una mecha más). *Falta en el código:* que `Torre.armar` pueda forzar salas con un especial y saltarse `ETAPA_ESPECIAL`; la habilidad.

**Ruinas** (15 de Luz, ×1,5). Dominan el agrietado y el pesado: casi nada se puede pisar dos veces. Salas con agrietado (287) y pesado (121). Pruebas: Sin ayudas, Todo o nada, Sin racha. Habilidad propuesta: **Pies ligeros** (un bloque agrietado aguanta un paso más una vez por sala). *Falta:* el mismo mecanismo de salas por especial, y la habilidad.

**Glaciar** *(nuevo)* (20 de Luz, ×1,6). Hielo: las 402 salas con hielo, con preferencia por las líneas largas (229). Resbalar es el tema: lo que se aprende en el escenario sirve para leer las salas de hielo de los demás. Pruebas: Sin ayudas, Sin racha. Habilidad propuesta: **Suela de hielo** (un resbalón se detiene un bloque antes, una vez por sala). *Falta:* mecanismo de salas y habilidad.

**Cima** *(nuevo)* (25 de Luz, ×1,8). Catapultas y torres más altas: las 168 salas con trampolín. Poco hielo y poco pesado. Es el escenario "vertical". *Riesgo:* en Pesadilla hay solo 6 salas con trampolín; habría que generar más antes de abrirlo. Habilidad propuesta: **Salto largo** (la catapulta sube una celda más).

### Escenarios de reglas

**Relojería** (25 de Luz, ×1,8). Cada sala da menos movimientos (el margen baja), pero la ficha de la ruleta es más barata (×0,75). Ya está en el código con `price_mult`; falta el recorte de movimientos (por ejemplo, un `MARGEN_ESCENARIO` junto a `MARGEN_DIFICULTAD`). Habilidad propuesta: **Tictac** (cada sala empieza con 2 movimientos más). Pruebas: Todo o nada, Sin racha.

**Compromiso** (35 de Luz, ×2,2). Una sola vida; sin Tótem ni Vidas extra. Es el más duro y el más cercano al "permadeath": ya está en el código (`lives`, `permadeath`, `no_totem`, `no_extra_life`). Habilidad propuesta: **Corazón extra** (se empieza con una vida más *solo en los demás escenarios*: no puede ganar en el que no tiene vidas). Pruebas: Sin ayudas, Sin racha.

### Escenarios de economía

**Gran Casino** (30 de Luz, ×1,4). Los casinos de lujo desde el principio (`casino_tier: 3`) y la ficha más barata (×0,8), pero con torres más difíciles. Ya está casi todo en el código. Habilidades propuestas: **Bolsillo de soñador** y **Segunda oportunidad**, a definir.

**Contratista** *(nuevo)* (20 de Luz, ×1,5). El tablón manda: más contratos activos, fianzas más altas y recompensas mayores; el casino pone el foco en el tablón y no en las mesas. Habilidad propuesta: **Buena letra** (un contrato fallido devuelve la fianza una vez por run). *Falta:* parámetros de contratos por escenario.

## Resumen

| Escenario | Familia | Estado | Falta |
|---|---|---|---|
| La Pesadilla | base | jugable | |
| Sin piedad | reglas | jugable | |
| Polvorín | salas | definido | forzar salas por especial; habilidad |
| Ruinas | salas | definido | lo mismo; habilidad |
| Glaciar | salas | nuevo | lo mismo; habilidad |
| Cima | salas | nuevo | más salas de trampolín altas; habilidad |
| Relojería | reglas | casi | recorte de movimientos; habilidad |
| Compromiso | reglas | casi | habilidad y revisar texto |
| Gran Casino | economía | casi | habilidades |
| Contratista | economía | nuevo | contratos por escenario; habilidad |

## Decisiones tuyas

1. **¿Cuántos?** Son 10 con los dos actuales. Se pueden quedar 6 o 7 y dejar el resto para después.
2. **¿Las salas por tema son la línea principal?** (Polvorín, Ruinas, Glaciar, Cima.) Es lo que más aprovecha lo que ya generamos.
3. **¿Cómo se desbloquean?** Hoy se pagan con Luz y se pueden jugar todos. Alternativa: escapar en uno abre el siguiente.
4. **¿Las habilidades propuestas te cierran?** Las cinco pendientes hoy (Mecha larga, Pies ligeros, Corazón extra, Bolsillo de soñador, Segunda oportunidad) se reparten así o se redefinen.
5. **¿Un escenario puede tener su propia prueba?** Ahora las pruebas se sortean de un pool.
6. **Orden de construcción:** lo más barato es Compromiso, Gran Casino y Relojería (casi todo en el código); lo que más cambia la sensación es Polvorín y Glaciar (requieren el mecanismo de salas por especial, que sirve para los cuatro de salas).
