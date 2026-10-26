# Economía: torre, casino y Farolín

Todo el balance vive en variables (`static var`) para poder probarlo con el bot (`bot.md`). Los valores de abajo son los vigentes; los catálogos de premios están en `catalogo.md`.

## El ciclo

1. **Torre** (puzzle): da *claridad* por purificar bloques (valor por bloque, racha y cosecha: `torre/cosecha.gd`, con `Cosecha.mult_global` = 2,25 por calibración). Morir en la torre no cuesta claridad del run, cuesta una vida.
2. **Casino**: se gasta claridad en las mesas (ruleta, tragamonedas, blackjack), en la vitrina y en la tienda. Los ahorros (Caja fuerte, Alcancía) se cobran al entrar al casino y el Taller del salón vende o cambia ítems (ver `diseno.md`).
3. **Farolín**, en la puerta de salida del casino, cobra el peaje de la etapa (`RunState.toll_for`). Opciones: pagar, rehacer la torre (−1 vida) o, sin vidas, abandonar el run.
4. **Torre siguiente.** Si no se llega a pagar se pierde una vida y se vuelve a subir la misma torre.

## El peaje: una colina y una pared

- `RunState.INGRESO_MEDIDO` (tabla por etapa, de 167 a 927, medida con el bot por la ruta óptima de cada sala; `income_fit`, escalable con `income_scale`) es lo que rinde una torre sin boosts (referencia); `wall_growth` es 1,25 y con eso el bot de runs completos gana el 4,7 a 5,3 % (objetivo 3 a 7 %); el máximo que se puede juntar sin boosts es 1,5 veces esa recta (`income_ceil`).
- Antes de la pared el precio va del 35 % (`pre_wall_from`) al 100 % (`pre_wall_to`) de lo que rinde una torre. La etapa 8 (`WALL_STAGE`) es la **pared**: su precio (`wall_toll()`) es lo que no se puede pagar sin boosts aunque se junte el máximo en cada torre y no se gaste nada; de la etapa 4 a la 8 sube en colina (`hill_power` 1,25, más tarde cuanto mayor), y después de la pared crece 20 % por etapa (`wall_growth`).
- Espíritu de Balatro (decisión de Dante): después de la pared el juego puede romperse de forma absurda con los puntos, pero no al principio, y **superar el run completo no tiene que ser fácil**. Objetivo: que gane el 3 a 7 % de los runs de un bot casi perfecto.
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
- Los dados dan claridad (tope de 150 por partida, `RunState.DICE_CAP`) y, con 4 o 5 aciertos, a veces un cosmético (rarezas según la dificultad, ver `diseno.md`; Fácil no da); la Luz y los cosméticos de los dados quedan pendientes en el run (`run.dice_pending`) y pasan al perfil al superar una torre.
- Habilidades persistentes: se ganan por escenario al escapar (una por vez, al azar entre las que faltan; cuando no quedan, Luz).

## Calibración con el bot

- Resultados con la torre actual (120 runs, habilidad media): claridad ×2,25 y `pre_wall_from` 0,35 → gana ~5 % y pasa la etapa 1 sin reintentos. Con ×1 los runs se traban en las etapas 3 a 5.
- Configuraciones probadas con la torre anterior (para entender la sensibilidad): crecimiento 1,15 y ficha 50 → 15 a 45 %; 1,20 y ficha 50 → 20 a 30 %; ficha 75 + 6 → 7 a 17 %; ficha 75 + 6 con precio previo del 60 al 100 % → 3 a 7 %.
- **Pendiente:** calibrar con partidas reales (telemetría local, `herramientas/resumen_telemetria.py`). El bot es un jugador casi perfecto; la dificultad elegida no cambia la economía.
