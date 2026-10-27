# Plan: rehacer el contenido de los casinos

Estado: **diseño acordado, sin programar**. Este documento junta lo conversado con Dante; cuando una parte se implemente se pasa a `diseno.md` / `economia.md` y se marca aquí como hecha. El balance (números) es lo último: primero tiene que encajar y funcionar, después se mueven constantes.

## 1. Por qué

Dos problemas:

1. **La taberna no sirve.** Con lo que se gana en una torre no alcanza para una tirada de ruleta después del peaje.
2. **No hay razón para querer llegar al casino siguiente.** Los cuatro casinos (taberna, salón, casino, gran casino) tienen las mismas mesas, los mismos premios (la rareza no depende del casino) y solo cambian el aspecto, una regla modesta y una estación.

### Lo que se midió

Bot que juega cada sala por su **ruta mínima**, sin titubeos, sin muertes y sin boosts; 10 torres por etapa, dificultad media, claridad ×2,25 (`Cosecha.mult_global`). Coincide con la telemetría de partidas reales (143 / 261 / 311 en las etapas 1 a 3).

| Etapa | Rinde una torre (mediana) | Peaje actual | Peaje / ingreso | Ficha actual | Ficha / ingreso | Sobra tras el peaje |
|---|---|---|---|---|---|---|
| 1 | 167 | 128 | 77 % | 75 | 45 % | 39 |
| 2 | 283 | 179 | 63 % | 81 | 29 % | 104 |
| 3 | 315 | 235 | 75 % | 87 | 28 % | 80 |
| 4 | 439 | 316 | 72 % | 93 | 21 % | 123 |
| 5 | 463 | 475 | 103 % | 99 | 21 % | −12 |
| 6 | 546 | 755 | 138 % | 105 | 19 % | −209 |
| 8 | 621 | 2141 | 345 % | 117 | 19 % | — |
| 15 | 927 | 7673 | — | 159 | 17 % | — |

Conclusiones:

- La curva del peaje se ajustó con la torre vieja y sobreestimaba las primeras etapas; ya se reemplazó por el ingreso medido (`RunState.INGRESO_MEDIDO`).
- El peaje de la etapa 1 es el 77 % de lo que rinde la torre, cuando el diseño decía 35 %. La "pared" llega en la etapa 5, no en la 8.
- La ficha ya es ~20 % del ingreso desde la etapa 4; el problema de la ficha es solo de las etapas 1 a 3.
- El comentario de `Roulette` sobre cuánto rinde una torre también está desactualizado.

## 2. Cambios a lo que existe

### Taberna: solo la ruleta
- Se saca la tragamonedas de la taberna (queda solo la ruleta). El salón en adelante conserva sus mesas.

### Las reglas de la casa se van
- Se eliminan las reglas (`casino_rules.gd`: Racha, Apuesta libre, Jackpot) y todo lo que depende de "aceptar la regla con el tabernero". **Racha** y **Jackpot** pasan a boosts y/o consumibles, con distinto porcentaje de aparición; **Apuesta libre desaparece del todo**, sin boost ni consumible (decisión de Dante: quien quiera ganar cinco veces, juega cinco veces). Con ella se va la apuesta de 1, 2, 3 o 5 fichas juntas de las tragamonedas y el blackjack (`stake`).

| Regla | Qué hacía | Consumible (esta visita) | Boost (siempre) |
|---|---|---|---|
| Racha | cada apuesta ganada seguida suma +10 % al pago de la siguiente, hasta +50 %; perder la corta | común | raro |
| Jackpot | parte de lo que se pierde va a un pozo; el premio mayor (tres coronas, blackjack o pleno) se lo lleva | — | épico |
| Apuesta libre | — | se elimina | se elimina |

### La Caja fuerte se va
- Se saca el servicio `caja` (`casino_services.gd`, `run.vault`, `vault_stage`, el guardado y la pantalla). Ya no se guarda ni se retira claridad: nada queda "apartado".
- Lo absorbe un efecto simple: **al terminar la torre y entrar al casino se acredita un porcentaje de la claridad con la que se entró a esa torre** (hoy la Caja pagaba 15 % de interés, `VAULT_INTEREST`). Se anota la claridad al empezar la torre y se acredita al entrar al casino, con un aviso corto de lo cobrado.
  - **Boost "Caja fuerte"**: en cada casino.
  - **Consumible "Alcancía"**: una sola vez, con un porcentaje mayor.
- Distinto del boost **Interés** que ya existe (la claridad que sobra *al salir* del casino crece 25 %, con tope): momento y base distintos. Los dos conviven.
- **Cuidado:** reintentar ya **no cuesta claridad** (`restart_cost(true)` devuelve 0; cuesta una vida). Los textos de la Caja fuerte que dicen "mientras tanto no sirve para reintentar" ya no valen y no se copian.

### El Taller
- Se queda **solo en el segundo casino (el salón)**, como hasta ahora.

## 3. Ficha chica

- Regla: la ficha es ~**20 % del ingreso medido de la torre**. Desde la etapa 4 la fórmula actual (`75 + 6 × (etapa − 1)`) ya cae ahí; solo cambian las etapas 1 a 3 con un multiplicador:

| Etapa | Multiplicador | Ficha |
|---|---|---|
| 1 | ×0,45 | 33 |
| 2 | ×0,70 | 57 |
| 3 | ×0,72 | 63 |
| 4 en adelante | ×1 | 93 en adelante |

- Es continua: no hay salto al pasar de la taberna al salón.
- **Los premios no se limitan en la taberna** (decisión de Dante): la ruleta de la taberna sortea entre todo, como las demás. No hace falta limitarlos porque el modelo ya escala con la ficha: `Items.value_of` da a cada premio un valor proporcional al precio (`value × ficha / 50`) y las bolsas de claridad pagan un múltiplo de la ficha (×1,4, ×3, ×6, ×15, ×40), de modo que el rendimiento esperado de la ruleta (`Roulette.expected_ratio`) es el mismo con cualquier ficha. Con la ficha al ~20 % del ingreso, un épico cuesta en promedio unas 2,6 torres de ingreso en cualquier etapa; hoy en la etapa 1 cuesta unas 5,8.
- **Lo que sí cambia (y es de balance):** el *efecto* de un boost no escala con la ficha. Con la ficha chica los boosts llegan antes en claridad, y los que multiplican la ganancia (Cosecha doble, Midas…) arrancan la bola de nieve más temprano. Es el mismo efecto que ya tiene *Ficha barata*. Se corrige después con constantes (la ficha de la etapa 1, el peaje) midiendo con el bot, no con una regla nueva.
- Interacciones a revisar: *Ficha barata* (−20 %, se acumula), *Ficha gratis* y los consumibles tipo "devuelve N veces la ficha".

## 4. Contratos

### Idea
Un contrato es una tarea para **la próxima torre** (la que se sube después de ese casino). Se acepta gratis en un **tablón** del casino y se cobra al cumplirla. Da a la taberna una función que no depende de la claridad que se trae, y hace que cada casino ofrezca más ingreso que el anterior.

### El tablón (estación del casino)
- Una estación como el Taller (`lay.station`): un panel en la pared con **papeles colgados**. Te acercas, se abre su pantalla, eliges un papel y lo aceptas.
- Cantidad de papeles según el casino (máximo 6):

| Casino | Papeles |
|---|---|
| Taberna | 3 |
| Salón | 4 |
| Casino | 5 |
| Gran casino | 6 |

### La cartelera es persistente
- El tablón es **uno solo por partida** (se guarda con el run) y **sus papeles pasan de un casino al siguiente**: si dejas los 6 colgados y no haces hueco, en el próximo casino están **los mismos 6**.
- Cada papel está en uno de estos estados: **colgado** (se ofrece), **activo** (aceptado: sale de la cartelera y cuenta para el límite de 2, o 3 con Caza recompensas) o **cobrado/fallido** (se va).
- En cada casino aparecen **a lo sumo 2 papeles nuevos por torre**, y solo en los **huecos** de la cartelera (por haber aceptado, rechazado o cobrado alguno). Si no hay huecos, no aparece nada.
- **Rechazar** un papel (gratis) lo descuelga y deja el hueco. Eso obliga a decidir en cada visita: aceptar, rechazar para hacer lugar, o dejarlo colgado para tomarlo en la próxima torre.
- Cuando un casino tiene más lugares que el anterior (3 → 4 → 5 → 6), los lugares nuevos arrancan vacíos y se llenan con los 2 papeles nuevos por torre, igual que los demás huecos. Para el primer casino se llenan los 3 lugares de entrada (por confirmar).
- Un papel guarda **qué se pide** (el objetivo) y su recompensa **en porcentaje** de lo que rinde una torre; el monto se calcula **al aceptar**, con la etapa de ese casino. Así un contrato difícil que se dejó colgado no se desvaloriza ni se aprovecha de una etapa más barata, y la rareza del sello (que sale de ese porcentaje) no cambia.
- La cartelera se reinicia al empezar un run nuevo.

### Rotar los papeles
- La pantalla del tablón tiene un botón **"Rotar"**, como la vitrina de la ruleta (`showcase.gd`): vuelve a sortear los papeles **colgados** (los activos no se tocan) y cada rotación de la visita cuesta más que la anterior. El contador se reinicia al entrar a cada casino.
- Rotar es la única forma de ver más de 2 papeles nuevos por torre, y **tira también los que se estaban guardando**: antes de rotar conviene aceptar los que se quieran conservar. Es parte de la decisión.
- Costo de partida: **la mitad de la ficha × (1 + rotaciones)** (`ROTAR_CONTRATOS`), **lineal**, igual que la vitrina. Con la ficha de la etapa 1 (33): 16, 33, 49… Se cobra en claridad. Es una constante: la mitad porque un contrato común de la etapa 1 paga unos 17 y rotar al precio de una ficha entera nunca valdría la pena.
- La cantidad de papeles de la cartelera no cambia al rotar (3, 4, 5 o 6) y la rareza de los nuevos se sortea de nuevo.
- **Llave de la vitrina** ("la primera rotación de la vitrina de cada visita es gratis") también hace **gratis (costo cero) la primera rotación del tablón** de cada visita.

### Rareza: el sello del papel
- La rareza se ve en un **sello** sobre la hoja que cambia de color: **gris** (común), **azul** (raro), **violeta** (épico).
- La rareza no se elige: sale de lo que paga el objetivo (ver "Recompensa y dificultad de la tarea"). Cuanto más difícil la tarea, más paga y más raro el sello; y todo escala con la etapa.
- Hay una cuarta rareza, **imposible**: un contrato con un objetivo que **sin multiplicadores no se alcanza** (o es casi inalcanzable). Ejemplo: "obtener 2000 de claridad purificando en la siguiente torre" es muy difícil sin un consumible y un boost que multipliquen la claridad al purificar. **No hay que tener una build para aceptarlo ni para que aparezca**: lo ve cualquiera y decide si se anima (o si lo deja colgado hasta tener los multiplicadores, o lo rechaza). Su sello es **negro** (decisión de Dante), que se distingue del gris, el azul y el violeta.
- Cómo se define: los objetivos con un número de claridad se escriben como un **múltiplo de lo que rinde una torre en esa etapa por la ruta óptima** (tabla de la sección 1), para que escalen solos con la etapa. Como jugar la ruta óptima rinde 1×, algo ~1× ya es de los difíciles y un múltiplo grande (del orden de 3× o más; los 2000 del ejemplo son unas 4× en la etapa 5, donde rinde 463) pasa a ser imposible sin multiplicar. Lo que cuenta como imposible es una marca del objetivo, no una regla de la etapa.
- Reglas de los imposibles: a lo sumo **uno colgado a la vez**, con poco peso en el sorteo, y pagan mucho más que cualquier otro (100 % a 150 % de lo que rinde una torre, antes de Contratista o Sello de oro; más si el umbral es mayor). Pueden tomarse también con fianza en los casinos donde la hay.
- Cada objetivo imposible se prueba con el bot jugando con una build de ejemplo (por ejemplo, Cosecha doble, Midas y Poción de cosecha) para comprobar que **es alcanzable**: imposible sin multiplicadores no quiere decir imposible del todo.

### Límite
- **2 contratos activos** a la vez. El boost **"Caza recompensas"** da **+1** a la cantidad de contratos que se pueden aceptar.

### Cobro y animación (pantalla del contrato resuelto)
- Cuando un contrato se resuelve (cumplido o fallido) aparece una **pantalla completa** (`scripts/ui/contrato_resuelto.gd`, con la torre en pausa): el **papel del contrato en el medio** (el mismo arte de la cartelera: ícono del objetivo, renglones de "texto escrito" que no dicen nada y el sello de rareza), con a su izquierda el **título** del contrato en grande y debajo las **condiciones** que había que cumplir (un guion por renglón; la lista de `{titulo, condiciones}` la arma cada contrato); por la **derecha entra un sello de mano hecho de minibloques**, se deja caer sobre el papel y deja **"CUMPLIDO"** (verde) o **"FALLIDO"** (rojo), con un temblor de pantalla y una salpicadura de tinta; el sello se levanta y se va por la derecha, y **en ese mismo lado sale un contador grande** que sube hasta el valor total cobrado, con un rótulo ("Cobrado"). Cuando todo está a la vista pide **"Presiona Espacio para continuar la torre"**.
- Una primera pulsación durante la animación la salta; la siguiente continúa. Los tiempos son constantes (`T_*`).
- Si se falló: con fianza el contador muestra en rojo la fianza perdida ("Fianza perdida", `-N`); sin fianza, "Sin recompensa" y un 0.
- Se cobra **en cuanto se cumple**, dentro de la torre; la pantalla aparece al terminar la sala o la torre (por decidir en la integración, para no interrumpir un puzzle en marcha).
- `monto` es lo cobrado: positivo al cumplir, negativo (fianza perdida) o 0 al fallar.
- Arte: el sello de texto (`dibujar_sello_texto`) y el sello de mano (`dibujar_sello_mano`) están en `contract_art.gd`; el papel grande es `dibujar_papel` con `PAPEL_ROWS_GRANDE`.

### Recompensa y dificultad de la tarea
- Cada objetivo del catálogo trae su propia **`recompensa`**: un porcentaje de lo que rinde una torre en esa etapa (tabla de la sección 1; **no** del peaje, para no romper la pared). Es el dato que expresa **cuánto cuesta cumplirlo**: "sobrar movimientos" puede valer 10 %, "no empujar en ninguna sala" 20 %, y algo muy duro como "terminar la torre sin movimientos de escalada" 60 % o más, bastante por encima de cualquier otro.
- La **rareza del sello** sale de ese valor: gris por debajo de ~15 %, azul hasta ~30 %, violeta desde ahí (los muy altos son violetas y listo; no hace falta un cuarto color).
- Los números concretos son constantes de balance y se mueven al final. Lo que sí queda fijo en el diseño: la recompensa es un campo de cada objetivo, nunca una función de la rareza.
- Ejemplo (etapa 12, la torre rinde ~727): común 10 % = 73, raro 20 % = 145, épico 35 % = 254, "sin escalar" 60 % = 436.

### Fianza (solo en los dos últimos casinos)
- Se puede aceptar un contrato **con fianza** en el **casino** y el **gran casino**. Pagas claridad al aceptar; si cumples, recibes la fianza de vuelta y la recompensa multiplicada; si no cumples, pierdes la fianza.
- **Tamaño:** por ahora una constante: `FIANZA_FRACCION` = **50 % de la recompensa del contrato**. Como la recompensa ya depende de la dificultad de la tarea, **la fianza sube sola con ella** (la de "sin escalar" es mucho más cara que la de "sobrar movimientos") sin tocar nada más. Si más adelante se quiere otra relación, se cambia la función `fianza(contrato)` y listo.
- **Premio:** constante `FIANZA_MULT` (empieza en **×1,5**: se recibe una vez y media la recompensa más la fianza de vuelta). Con fianza f (como fracción de la recompensa) y multiplicador m, conviene aceptarla si la probabilidad de cumplir supera f / (m − 1 + f):

| Fianza | Multiplicador | Conviene si cumples más del |
|---|---|---|
| 50 % | ×1,5 | 50 % |
| 50 % | ×2 | 33 % |
| 50 % | ×2,5 | 25 % |

  El ajuste fino es la constante, no el código.
- La fianza queda apartada mientras el contrato esté activo (no se puede gastar) y se resuelve al cumplir o al terminar la torre.
- **La explosividad no la pone la fianza**: la ponen la dificultad de la tarea (los objetivos muy duros pagan mucho de por sí) y los ítems:
  - **Boost "Contratista"** (nombre provisorio, épico): cada contrato paga el doble, también el premio de la fianza.
  - **Consumible "Sello de oro"** (nombre provisorio): el **próximo contrato que se cobre después de usarlo paga ×5**. Se puede usar en la torre o en el casino; queda preparado hasta que se cobre un contrato (si el contrato falla, sigue esperando al siguiente). Multiplica la recompensa; la fianza devuelta no se multiplica. Solo uno a la vez.
  - Con todos los factores juntos (tarea dura × fianza × Contratista × Sello de oro) un contrato puede pagar varias veces lo que rinde una torre. Es lo que se busca en las etapas altas (el "se rompe" de Balatro), contenido por el límite de contratos activos (2, o 3 con Caza recompensas).

### Objetivos posibles (a pulir)
Se apoyan en cosas que el juego ya mide: sobrar movimientos, no deshacer, llegar a una racha, desarmar una bomba, purificar N bloques especiales, no empujar ni tirar en una sala, no perder vidas, usar una catapulta.

### Arte (hecho, rama `arte/casinos`)
- `scripts/ui/contract_art.gd`: el papel de la cartelera (con chinche si está colgado, sin ella si está activo), el sello de cera de las cuatro rarezas (gris, azul, violeta, negro con marca dorada), el sello de texto "CUMPLIDO"/"FALLIDO" y el sello de mano de minibloques y diez íconos de objetivo de 9 x 9 (movimientos, deshacer, racha, bomba, especiales, sin empujar, vidas, catapulta, escalada, claridad). La lista de objetivos se puede ampliar.
- `scripts/ui/item_icons.gd`: íconos de los ítems nuevos (nombres de id provisorios): `racha_de_la_casa`, `racha_de_visita`, `pozo_del_jackpot`, `caja_fuerte`, `alcancia`, `caza_recompensas`, `contratista`, `sello_de_oro`.
- `scripts/casino/casino_room.gd`: la estación `tablon` (`_tablon`), de **dos celdas de ancho** (10 minibloques) y 14 de alto, con un diseño distinto para cada casino: en la **taberna** tablas con postes toscos, juntas y una vela en cada punta; en el **salón** madera pulida con tachas doradas y una repisa con libro, tintero y pluma; en el **casino** paño verde con marco dorado y dos lámparas; en el **gran casino** marco de mármol con pilastras, paño violeta, base y un frontón dorado. Los papeles cuelgan (hasta seis: tres por fila, los de abajo corridos y los del medio un poco adelante) y están hechos con **minibloques de un tercio de tamaño** (`_papel_fino`, un segundo diccionario `fino` que devuelve `build_voxels` y que la escena dibuja con `VOXEL / 3`): chinche, renglón de texto, **el ícono entero del objetivo (9 x 9)** y el sello de su rareza al pie. Al sumar la estación al diseño de cada casino hay que reservar las dos celdas de ancho.
- `scripts/ui/contratos_columna.gd`: la columna de contratos activos del menú de pausa (`PauseMenu.set_contratos(lista)`); sin contratos no se ve.
- Capturas: `tests/capturas/shot_arte_contratos.gd` (papeles, sellos, íconos) y `shot_tablon.gd` (el tablón de cada casino).

### Casinos con más detalle (propuesta, por decidir)
- Al ver el tablón ancho con las hojas en detalle dentro de la sala, queda grande: la sala está hecha con minibloques de 0,2 (una celda = 5 minibloques = 1 unidad) y la mesa de la ruleta mide 3 x 2 celdas, mientras que el tablón ancho mide 2 unidades y sus hojas están hechas con minibloques de un tercio. Los personajes y los bloques ya tienen mucho más detalle; los casinos se quedaron atrás.
- Propuesta: **duplicar la resolución de los casinos** (`VOXEL` 0,1 y `CELL_VOX` 10, una celda sigue midiendo 1 unidad). El tablón de 10 minibloques mediría 1 unidad, que es la proporción buena, y las hojas con su ícono entero se mantienen. Se hace en pasos: (1) infraestructura: un factor `ESCALA` en `_box` y en las constantes para que todo siga viéndose igual con el doble de minibloques; (2) el tablón nuevo a su tamaño; (3) refinar pieza por pieza con la nueva resolución (mesa y crupier, tragamonedas, mesas de cartas, paredes, puertas y piso, lámparas y obstáculos, Taller), con capturas de antes y después de cada una.
- **Hecho en la rama `arte/casinos-detalle`:** `Room.build_detalle` (pasos 1 y 2). Parte del modelo de siempre (`build_voxels`, que no cambia: las pruebas de la sala siguen valiendo) y lo pasa al doble de resolución (`ESCALA` 2, `VOXEL_FINO` 0,1): cada minibloque se parte en 8 con un tono apenas distinto, las esquinas salientes quedan biseladas y el damero del casino y el gran casino tiene juntas finas entre celdas. La escena del casino ya dibuja con eso. El tablón se arma directo en la resolución nueva (1 unidad de ancho, hojas de un tercio de minibloque) y se pone con `build_detalle(stage, tier, {cell, papeles})`; todavía no está en el diseño de cada casino. Costo medido: entre 32 mil y 126 mil minibloques según el casino, de 50 a 210 ms armarlos y de 80 a 280 ms la malla (hasta 360 mil vértices en el gran casino).
- **Rediseño de las salas (hecho en la rama `arte/casinos-rediseno`):** los cuatro casinos tienen la distribución de los planos aprobados: el **tablón siempre en la pared oeste** (`TABLON`, celda (0, 1), junto a la esquina del norte; en la taberna, donde estaba la tragaperras), las **tragamonedas contra las paredes del fondo** (oeste mirando al este, norte mirando al sur; `_frente_de_maquina`), el Taller en la pared oeste del salón, la taberna sin tragamonedas, **sin Caja fuerte** en la sala del casino, y las decoraciones de las paredes (cuadros, apliques, pilastras, estantes) reubicadas para no pisar los muebles. La textura fina bajó (`_ampliar`, de 0,07 a 0,02): antes parecía sucia. El tablón todavía no tiene interacción: bloquea su celda y cuelga vacío hasta que existan los contratos. Pruebas: `test_rediseno` y `test_detalle` en `test_casino_room.gd`.
- **Paredes y luces ordenadas (rama `arte/casinos-paredes`):** `Room.paredes(lay, tardio)` lista, para cada pared del fondo, lo que la ocupa (tragamonedas, tablón, Taller, puertas con su marco, lo que está en la fila de la pared) y lo que se le cuelga (chimenea, cartel, estante, cuadros, apliques y pilastras), cada cosa con su tramo; `build_voxels` dibuja desde esa lista (`_decorar`) y `test_paredes` comprueba que ninguna decoración pisa a otra ni a un mueble o una puerta. Los faroles de pie ya no están en posiciones fijas: son `lamps` de la distribución (una celda libre junto a las puertas, que bloquea su celda). En el gran casino los faroles van arriba de las pilastras y se sacaron las cuatro columnas que tocaban las paredes del fondo (cerraban el paso).
- **Muebles finos (hecho):** `casino_muebles.gd` arma con 10 minibloques por celda la mesa de la ruleta (rueda con 13 casilleros, cuadro de apuestas, fichas), el crupier, las tragamonedas, las mesas de cartas, el Taller (fragua), barriles, cajas, plantas, columnas y faroles; el modelo base (`build_voxels(…, false)`) queda solo con la sala. Las paredes y las puertas también se arman finas (`casino_paredes.gd`): relieve por material (tablas, ladrillo con mezcla, paneles con molduras, bloques de mármol), cornisas, puertas con jambas, dintel, piedra clave y gemas, y las decoraciones (chimenea, cartel, estante, cuadros con su luna, apliques, pilastras).
- Lo que tocaría: `casino_room.gd` (733 líneas, 109 llamadas a `_box`, 49 usos de las constantes), `casino_scene.gd` (6) y las pruebas `test_casino_room`/`test_casino_scene`. Las unidades del mundo (celdas, Farolín, personaje, cámara) no cambian.

## 5. Cómo queda cada casino

| | Taberna | Salón | Casino | Gran casino |
|---|---|---|---|---|
| Etapas | 1 a 3 | 4 a 7 | 8 a 11 | 12 a 15 |
| Mesas | ruleta con ficha chica | ruleta, tragamonedas, blackjack | ídem | ídem |
| Premios de la ruleta | todos | todos | todos | todos |
| Tablón | 3 papeles | 4 | 5 (fianza) | 6 (fianza) |
| Estación | — | Taller | — | — |

Ideas para diferenciar más, **sin decidir**: boosts exclusivos del gran casino, un servicio propio del gran casino (fundir dos boosts en uno mejor), una mesa VIP, vista previa de lo que vende el casino siguiente, y un crupier con personalidad en cada casino.

## 6. Reglas de implementación a respetar

- Textos en español neutro (tuteo); toda frase nueva con su entrada en `scripts/idioma/loc_en*.gd`.
- Al cambiar premios o servicios, regenerar el catálogo (`herramientas\catalogo.bat`).
- Pruebas y capturas con `GAME_SANDBOX=1`; limpiar tests que dependan de las reglas, la apuesta de varias fichas o la Caja (`test_casino*`, `test_scenarios`, etc.).
- Guardado: los runs viejos con `vault` o `casino_visit` deben cargar sin romperse.
- Nada viejo en el repositorio: lo que se quita se borra de verdad.

## 7. Orden de trabajo propuesto

1. **Taberna y ficha chica:** sacar la tragamonedas de la taberna y poner el multiplicador de ficha de las etapas 1 a 3 (sin limitar los premios).
2. **Reglas y Caja fuerte → boosts y consumibles:** quitar `casino_rules`, la regla aceptada con el tabernero, la apuesta de varias fichas y la Caja; agregar los ítems nuevos (Racha, Jackpot, Caja fuerte, Alcancía, Caza recompensas).
3. **Contratos, versión mínima:** modelo de datos, sorteo por casino, estación del tablón con su pantalla, 2 activos, cobro al cumplirse.
4. **Presentación:** sello de rareza, pantalla del contrato resuelto (sello CUMPLIDO o FALLIDO y contador), pausa con los contratos activos.
5. **Fianza** en los dos últimos casinos.
6. **Diferenciar los casinos** (premios y estaciones por casino).
7. **Balance (hecho):** el peaje usa el ingreso medido (`RunState.INGRESO_MEDIDO`) y `wall_growth` 1,25; el bot de runs completos gana el 4,7 a 5,3 %. Falta calibrar con partidas reales.

## 8. Pendientes de decisión

- Los porcentajes de cada objetivo (la recompensa), y qué objetivos cuentan como "muy duros".
- `FIANZA_MULT` (×1,5 de partida) y si `FIANZA_FRACCION` (50 %) se queda fijo o pasa a depender de algo.
- Rareza y nombre del consumible "Sello de oro" (×5), y si se puede acumular más de uno.
- Si rotar tiene que respetar a los papeles guardados o los tira (por ahora los tira) y si el primer casino arranca con la cartelera llena o con 2 papeles.
- Lista de objetivos imposibles y el múltiplo de claridad que los vuelve imposibles; la build de ejemplo con la que se prueba que son alcanzables.
- Que el boost "Contratista" (cada contrato paga el doble) exista, su nombre y su rareza.
- Porcentajes de Racha, Caja fuerte y Alcancía; rareza de cada ítem nuevo; si Caza recompensas es raro y si se acumula (y hasta cuántas veces).
- Si algún boost debería ser exclusivo de un casino (sin limitar lo que sale en los demás).
- ~~Si el casino y el gran casino llevan alguna estación~~: decidido que no; solo el salón tiene el Taller.
- Cuándo recalibrar el peaje (hoy es el 77 % de lo que rinde la torre en la etapa 1).
