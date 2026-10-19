# Casinos

Entre torre y torre se pasa por un casino. Hay cuatro niveles de sala según la etapa (o fijo, con el escenario Gran Casino): **Taberna** (etapas 1-6), **Salón** (7-13), **Casino** (14-20) y **Gran casino** (21-27). Cada nivel tiene una **regla de la casa** (cambia cómo pagan los juegos) y, salvo la taberna, un **servicio** (una estación que no es un juego). Al salir se ve el balance de la visita.

# Salas

## 0 - Taberna
- etapas: 1 a 6
- tamaño_celdas: 7 x 6
- tragamonedas: 1
- mesas_de_cartas: 0
- servicio: (ninguno)
- regla: (ninguna)

## 1 - Salón
- etapas: 7 a 13
- tamaño_celdas: 9 x 7
- tragamonedas: 2
- mesas_de_cartas: 1
- servicio: taller
- regla: racha

## 2 - Casino
- etapas: 14 a 20
- tamaño_celdas: 11 x 9
- tragamonedas: 3
- mesas_de_cartas: 1
- servicio: caja
- regla: libre

## 3 - Gran casino
- etapas: 21 a 27
- tamaño_celdas: 13 x 11
- tragamonedas: 3
- mesas_de_cartas: 2
- servicio: (ninguno)
- regla: jackpot

# Reglas de la casa

Constantes: extra de racha 0.1 por victoria seguida (hasta 5 pasos) · fichas que se pueden apostar con Apuesta libre: 1, 2, 3, 5 · parte de lo perdido que va al pozo del jackpot: 0.5.

## racha - Racha
- descripción: Cada apuesta ganada seguida suma +10 % al pago de la siguiente (hasta +50 %). Perder la corta.

## libre - Apuesta libre
- descripción: En las tragamonedas y el blackjack podés apostar 1, 2, 3 o 5 fichas juntas.

## jackpot - Jackpot
- descripción: Lo que perdés en la sala va a un pozo, y el premio mayor (tres coronas, blackjack o pleno) se lo lleva.

# Servicios

Constantes: el taller paga 0.4 del valor de un ítem y cambiar cuesta 0.3 de la ficha · la caja fuerte da 0.15 de interés por casino.

## taller - Taller
- descripción: Vendé un boost o un consumible por claridad, o cambialo por otro del mismo nivel.

## caja - Caja fuerte
- descripción: Guardá claridad y cobrala con interés en el próximo casino. Mientras tanto no podés usarla.

# Ruleta

13 casillas (la 0 es de la casa). Ficha: 50 en la etapa 1 y +2 por etapa. Cada apuesta cubre una cantidad de casillas y da premios de un nivel (ver boosts_y_consumibles.md).

## pleno
- casillas: 1
- nivel_del_premio: épico

## terna
- casillas: 3
- nivel_del_premio: raro

## mitad
- casillas: 6
- nivel_del_premio: común

## rango
- casillas: 9
- nivel_del_premio: consumible (barato)

# Tragamonedas

Tres rodillos; se puede una vez retener rodillos y volver a girar los otros por 0.5 de la ficha. Pagos en múltiplos de la ficha. Tres coronas dan además un boost épico.

## cubo
- nombre: Cubo
- peso: 7
- pago_tres_iguales: 2.0
- pago_dos_iguales: 0.3

## hielo
- nombre: Hielo
- peso: 5
- pago_tres_iguales: 4.0
- pago_dos_iguales: 0.5

## bomba
- nombre: Bomba
- peso: 3
- pago_tres_iguales: 9.0
- pago_dos_iguales: 0.9

## sol
- nombre: Sol
- peso: 2
- pago_tres_iguales: 20.0
- pago_dos_iguales: 1.4

## corona
- nombre: Corona
- peso: 1
- pago_tres_iguales: 50.0
- pago_dos_iguales: 2.5

# Blackjack

Mazo de 52, apuesta de una ficha (o más con Apuesta libre); el crupier pide hasta 17; blackjack paga 3 a 2, ganar 1 a 1, empate devuelve; se puede doblar con las dos primeras cartas; sin dividir ni seguro. (Las reglas están en blackjack.gd.)

# Dados del tabernero (pantalla de carga)

Una predicción de 5 dados y 3 tiradas para cumplirla: los acertados quedan retenidos y sólo se vuelven a tirar los que fallaron (gratis). El premio se cobra una vez, al final, según los aciertos. `chance_cosmético` = probabilidad de que el premio traiga un cosmético (con las probabilidades de rareza de `cosmético`). La claridad de los dados tiene un tope de 150 por partida.

## 0 aciertos
- claridad: 0
- luz: 0
- cosmético: (ninguno)
- chance_cosmético: 0.0

## 1 aciertos
- claridad: 0
- luz: 0
- cosmético: (ninguno)
- chance_cosmético: 0.0

## 2 aciertos
- claridad: 8
- luz: 0
- cosmético: (ninguno)
- chance_cosmético: 0.0

## 3 aciertos
- claridad: 25
- luz: 1
- cosmético: (ninguno)
- chance_cosmético: 0.0

## 4 aciertos
- claridad: 80
- luz: 2
- cosmético: comun 85 %, raro 15 %
- chance_cosmético: 0.15

## 5 aciertos
- claridad: 150
- luz: 5
- cosmético: raro 70 %, epico 30 %
- chance_cosmético: 1.0
