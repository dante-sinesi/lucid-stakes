# Economía: torre, casino y Farolín

Todo el balance vive en variables (`static var`) para poder probarlo con el bot (`bot.md`). Los valores de abajo son los vigentes; los catálogos de premios están en `catalogo.md`.

## El ciclo

1. **Torre** (puzzle): da *claridad* por purificar bloques (valor por bloque, racha y cosecha: `torre/cosecha.gd`, con `Cosecha.mult_global` = 2,25 por calibración). Morir en la torre no cuesta claridad del run, cuesta una vida.
2. **Casino**: se gasta claridad en las mesas (ruleta, tragamonedas, blackjack), en la vitrina y en la tienda. Los ahorros (Caja fuerte, Alcancía) se cobran al entrar al casino y el Taller del salón vende o cambia ítems (ver `diseno.md`).
3. **Farolín**, en la puerta de salida del casino, cobra el peaje de la etapa (`RunState.toll_for`). Opciones: pagar, rehacer la torre (−1 vida) o, sin vidas, abandonar el run.
4. **Torre siguiente.** Si no se llega a pagar se pierde una vida y se vuelve a subir la misma torre.

## El peaje: una colina y una pared

- `RunState.INGRESO_MEDIDO` (tabla por etapa: de 232 en la etapa 1 a unos 430-490 desde la 4, con torres de 7 salas; medida con `tests/sondas/medir_ingresos.gd` por la ruta óptima de cada sala, sin boosts; `income_fit`, escalable con `income_scale`) es lo que rinde una torre sin boosts (referencia). Como la torre ya no crece con las etapas, **el ingreso base es casi parejo: el crecimiento lo ponen los boosts**.
- Antes de la pared el precio va del 35 % (`pre_wall_from`) al 100 % (`pre_wall_to`) de lo que rinde una torre. La etapa 8 (`WALL_STAGE`) es la **pared**: su precio (`wall_toll()`) es la fracción `wall_frac` (0,53) de lo máximo que se puede juntar sin boosts hasta ahí (1,5 veces lo medido, sin gastar nada), más `wall_margin`: **desde la etapa 8 el precio supera lo que rinde una torre y hace falta un build (o ahorro)**; después crece un 15 % por etapa (`wall_growth`). Precios con la calibración vigente: 81 en la etapa 1, 214 en la 3, 621 en la 8 y 1638 en la 15.
- Espíritu de Balatro (decisión de Dante): después de la pared el juego puede romperse de forma absurda con los puntos, pero no al principio, y **superar el run completo no tiene que ser fácil**. Objetivo (decisión de Dante, 2026-10): que escape de la pesadilla el **15 % de los runs en Medio** de un jugador medio (bot de habilidad 1,0).
- Descuentos: *Descuento de Farolín* 15 % (hasta 2), *Soborno* 30 %; *Interés* hace crecer 25 % la claridad que queda al salir (tope 150).

## La ficha de la ruleta

75 en la etapa 1 y +6 por etapa (`Roulette.base_price`, `price_step`), **menos en las tres primeras etapas** (la taberna): `Roulette.chica_mult` = ×0,45, ×0,70 y ×0,72 (34, 57 y 63), para que después del peaje alcance para jugar. Una torre rinde, por la ruta mínima y sin boosts (medido con el bot): 167, 283, 315, 439 y 463 en las etapas 1 a 5 y 927 en la 15; la ficha ronda un 20 % de eso. (La curva del peaje, `RunState.income_fit`, se ajustó con la torre vieja y está por recalibrarse: ver `plan_casinos.md`.) Subirla retrasa la bola de nieve del principio: con ficha 50 el ingreso con build ya era ×3 en la etapa 5; con ficha 100 + 8 el bot casi no gana (el casino se come las builds).

## Boosts y consumibles

- Los de ganancia (Cosecha doble, Racha imparable, Midas, Pies de oro, Buen ojo, Escalador, Empuje rentable, Interés, bolsas grandes…) son los que permiten pasar la pared; los de movimientos actúan sobre el temporizador de la sala (`Torre.max_mov`).
- Constantes de los bonos fijos: `Cosecha.CLIMB_BONUS` (2 por piso nuevo), `PUSH_BONUS` (1 por bloque empujado o tirado), `POCKET_START` (60), `RunState.INTEREST_CAP` (150).
- Los de casino (Mano de 23, Mesa caliente, Blackjack de oro, Ficha barata, Casilla de regalo, Red de seguridad, Giro de cortesía, Llave de la vitrina, Doble o nada, Ficha gratis, Rayos X) están en el catálogo con sus niveles; los valores de la ruleta se mantienen dentro de la media de su nivel (épicos ~640, raros ~210, comunes ~100). Cuidado: la *Ficha barata* acelera la bola de nieve del principio.
- Vitrina y tienda: `scripts/casino/showcase.gd` (rotar la vitrina en la ruleta, tienda en las estaciones).

## La Luz (meta-progresión)

- Se gana al terminar un run: avance = 5 por torre superada + 20 por prueba superada. Con victoria (escapar de la pesadilla): (avance + 100) × el multiplicador del escenario; sin victoria, el 20 % del avance × el multiplicador (`Profile.luz_for_run`, `LUZ_FAIL_SHARE`). Sirve para entrar a los escenarios de pago.
- Fácil multiplica la Luz del run por 0,25 (`Profile.LUZ_POR_DIFICULTAD`): tiene movimientos ilimitados y pistas.
- Los dados (al entrar al casino, sobre la claridad ya cobrada) dan claridad como un porcentaje de la que tienes (2 aciertos 5 %, 3 aciertos 10 %, 4 aciertos 20 %, 5 aciertos 50 %, con 8, 25, 80 y 150 como mínimo; `DiceGame.PRIZES` y `claridad_para`; sin tope por partida: el valor esperado ronda +13 % de la claridad por carga, a vigilar con partidas reales) y una ventana de premios (C) y, con 4 o 5 aciertos, a veces un cosmético (rarezas según la dificultad, ver `diseno.md`; Fácil no da); la Luz y los cosméticos de los dados quedan pendientes en el run (`run.dice_pending`) y pasan al perfil al superar una torre.
- Habilidades persistentes: se ganan por escenario al escapar (una por vez, al azar entre las que faltan; cuando no quedan, Luz).

## Calibración con el bot

- Calibración vigente (400 runs, habilidad 1,0, Medio): `INGRESO_MEDIDO` nuevo, `wall_frac` 0,53 y `wall_growth` 1,15 → gana el **14,8 %**; pasa la etapa 8 el 93 %, la 10 el 53 %, la 12 el 27 % y la 15 el 15 %. Con habilidad 0,7: 12 %; 1,3: 18,5 %; 2,0: 17 %. **La habilidad casi no cambia el resultado**: el bot sube por el camino mínimo y su probabilidad de perder una sala es una suposición (`die_k` y `die_exp`, ver `bot.md`); la economía y la suerte con los boosts mandan. Calibrar con partidas reales.
- Boosts por bloque (Pies de luz +50 %, Pies de oro +75 %, Midas +200 % de la claridad del bloque): no se suman entre sí, vale el mayor (`Cosecha.POR_BLOQUE`). El Taller cobra cada cambio de una visita más que el anterior (`Services.swap_price`).
- **Peaje por dificultad** (`RunState.toll_dif`, decisión de Dante, 2026-10): las torres difíciles dan más claridad (salas más grandes, con más especiales), así que el peaje de Farolín se multiplica: Fácil ×0,63, Medio ×1, Difícil ×1,6 y Pesadilla ×1,95. Objetivo de escape del bot de habilidad media: **Fácil 35 %, Medio 15 %, Difícil 8 % y Pesadilla 3 %**. Resultado (400 partidas): Fácil ~31-35 %, Medio 15,8 %, Difícil 7,3 %, Pesadilla 4,0 % (±2-4 puntos de ruido). Antes de este ajuste el bot ganaba más cuanto más difícil era la dificultad (7,8 / 14,8 / 29,7 / 24,7 %).
- El bot pierde una sala con probabilidad `die_k × (bits / 100) ^ die_exp` (0,0226 y 2: una sala de 100 bits se pierde el 2,3 %, una de 190 el 8 %). Para calibrar otra dificultad: `DIF=pesadilla TOWERS=6 TOLL_SWEEP=1.8,2.1,2.4 RUNS=250` prueba varios multiplicadores del peaje con el mismo banco de torres.
- Configuraciones probadas con la torre anterior (para entender la sensibilidad): crecimiento 1,15 y ficha 50 → 15 a 45 %; 1,20 y ficha 50 → 20 a 30 %; ficha 75 + 6 → 7 a 17 %; ficha 75 + 6 con precio previo del 60 al 100 % → 3 a 7 %.
- **Pendiente:** calibrar con partidas reales (telemetría local, `herramientas/resumen_telemetria.py`). El bot es un jugador casi perfecto; la dificultad elegida no cambia la economía.
