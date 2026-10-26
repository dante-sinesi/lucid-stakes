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

- La curva del peaje (`RunState.income_fit`: `income_base` 340 + `income_slope` 25 × etapa = 365 en la etapa 1) se ajustó con la torre vieja. Con la torre nueva sobreestima las primeras etapas unas 2,2 veces y subestima las últimas.
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
- **Riesgo conocido:** los boosts valen una cantidad fija de claridad (épico ~640, raro ~210, común ~100), mientras que las bolsas escalan con la ficha. Con una ficha chica y premios grandes la ruleta rendiría de más. Por eso **la vitrina de la taberna lleva solo premios comunes y consumibles**, sin raros ni épicos (`Showcase`). Es el primer paso de "los premios dependen del casino".
- Interacciones a revisar: *Ficha barata* (−20 %, se acumula), *Ficha gratis*, y los consumibles tipo "devuelve N veces la ficha".

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

- Cada visita sortea sus papeles; los aceptados quedan marcados.

### Rareza: el sello del papel
- La rareza se ve en un **sello** sobre la hoja que cambia de color: **gris** (común), **azul** (raro), **violeta** (épico).
- La dificultad de la tarea y la recompensa suben con la rareza y con la etapa.

### Límite
- **2 contratos activos** a la vez. El boost **"Caza recompensas"** da **+1** a la cantidad de contratos que se pueden aceptar.

### Cobro y animación
- Se cobra **en cuanto se cumple**, dentro de la torre. Aviso corto sin texto de depuración en el HUD.
- **Animación del cobro:** un sello baja sobre el papel y deja un "COBRADO" en el centro.
- Los contratos activos se ven en el **menú de pausa**; en el HUD solo una marquita al cumplirse.

### Fianza (solo en los dos últimos casinos)
- En el **casino** y el **gran casino** se puede aceptar un contrato **con fianza**: pagas claridad al aceptar y, si cumples, recibes la fianza de vuelta más una recompensa mayor; si no cumples, la pierdes.
- La fianza queda apartada mientras el contrato esté activo (no se puede gastar).
- *Falta definir:* tamaño de la fianza respecto a la recompensa y cuánto multiplica el premio (son constantes de balance).

### Recompensa (balance, para más adelante)
Porcentaje de lo que rinde una torre en esa etapa (tabla de la sección 1): común ~10 %, raro ~20 %, épico ~35 %. A modo de ejemplo, en la etapa 1: 17 / 33 / 58. Que sea un porcentaje del ingreso medido (y **no** del peaje) evita que los contratos rompan la pared. Los de rareza alta pueden pagar también un consumible o un boost. Todo esto son constantes.

### Objetivos posibles (a pulir)
Se apoyan en cosas que el juego ya mide: sobrar movimientos, no deshacer, llegar a una racha, desarmar una bomba, purificar N bloques especiales, no empujar ni tirar en una sala, no perder vidas, usar una catapulta.

## 5. Cómo queda cada casino

| | Taberna | Salón | Casino | Gran casino |
|---|---|---|---|---|
| Etapas | 1 a 3 | 4 a 7 | 8 a 11 | 12 a 15 |
| Mesas | ruleta con ficha chica | ruleta, tragamonedas, blackjack | ídem | ídem |
| Premios de la ruleta | solo comunes y consumibles | por definir | por definir | por definir |
| Tablón | 3 papeles | 4 | 5 (fianza) | 6 (fianza) |
| Estación | — | Taller | — | — |

Ideas para diferenciar más, **sin decidir**: premios por rareza según el casino (épicos solo desde cierto casino, boosts exclusivos del gran casino), un servicio propio del gran casino (fundir dos boosts en uno mejor), una mesa VIP, vista previa de lo que vende el casino siguiente, y un crupier con personalidad en cada casino.

## 6. Reglas de implementación a respetar

- Textos en español neutro (tuteo); toda frase nueva con su entrada en `scripts/idioma/loc_en*.gd`.
- Al cambiar premios o servicios, regenerar el catálogo (`herramientas\catalogo.bat`).
- Pruebas y capturas con `GAME_SANDBOX=1`; limpiar tests que dependan de las reglas, la apuesta de varias fichas o la Caja (`test_casino*`, `test_scenarios`, etc.).
- Guardado: los runs viejos con `vault` o `casino_visit` deben cargar sin romperse.
- Nada viejo en el repositorio: lo que se quita se borra de verdad.

## 7. Orden de trabajo propuesto

1. **Taberna y ficha chica:** sacar la tragamonedas de la taberna, multiplicador de ficha de las etapas 1 a 3, vitrina de la taberna con premios chicos.
2. **Reglas y Caja fuerte → boosts y consumibles:** quitar `casino_rules`, la regla aceptada con el tabernero, la apuesta de varias fichas y la Caja; agregar los ítems nuevos (Racha, Jackpot, Caja fuerte, Alcancía, Caza recompensas).
3. **Contratos, versión mínima:** modelo de datos, sorteo por casino, estación del tablón con su pantalla, 2 activos, cobro al cumplirse.
4. **Presentación:** sello de rareza, animación del sello "COBRADO", pausa con los contratos activos.
5. **Fianza** en los dos últimos casinos.
6. **Diferenciar los casinos** (premios y estaciones por casino).
7. **Balance:** recalibrar la curva del peaje con el ingreso medido (`income_base` / `income_slope`) y repetir el bot de runs completos (`bot.md`).

## 8. Pendientes de decisión

- Fianza: cuánto cuesta (el "tamaño") y cuánto más paga (el "premio"). Ejemplo para discutirlo: contrato raro de la etapa 12, recompensa base 145. Con fianza de 145, si se cumple se recibe la fianza de vuelta más el doble de la recompensa (290), neto +290 en vez de +145; si no se cumple se pierden los 145. Con esos números conviene tomarla si la probabilidad de cumplir supera el 50 %.
- Porcentajes de Racha, Caja fuerte y Alcancía; rareza de cada ítem nuevo; si Caza recompensas es raro y si se acumula (y hasta cuántas veces).
- Premios por rareza según el casino.
- Si el casino y el gran casino llevan alguna estación (hoy, sin la Caja fuerte, no tienen ninguna).
- Cuándo recalibrar el peaje (hoy es el 77 % de lo que rinde la torre en la etapa 1).
