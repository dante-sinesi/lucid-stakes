# Boosts y consumibles

Son los premios del casino. **Boosts**: mejoras que duran el run (hay 5 lugares, algunos boosts suman más). **Consumibles**: se gastan (4 lugares). **Bolsas de claridad**: devuelven claridad. `nivel` es el nivel de apuesta de la ruleta que lo da (cuanto más difícil la apuesta, mejor el nivel); `peso` = probabilidad relativa dentro de su nivel; `valor` = valor en claridad para una ficha de 50 (sirve para balancear la ruleta, vender en el taller y convertir cuando no hay lugar); `se_acumula` = se puede tener más de uno; `mult` = (bolsas) veces lo que costó la ficha.

# Nivel épico

## segundo_aliento
- nombre: Segundo aliento
- tipo: boost
- descripción: Una vez por etapa, si caés al vacío volvés a la última plataforma firme.
- peso: 1
- valor: 640

## madrugada
- nombre: Madrugada
- tipo: boost
- descripción: La fila de abajo cae al doble de lento durante toda la etapa.
- peso: 1
- valor: 620

## luz_propia
- nombre: Luz propia
- tipo: boost
- descripción: Al pisar un bloque también se purifican los vecinos.
- peso: 1
- valor: 600

## mano_de_oro
- nombre: Mano de oro
- tipo: boost
- descripción: La racha sube el multiplicador de a 1,0 en vez de 0,5.
- peso: 1
- valor: 620

# Nivel raro

## pies_de_luz
- nombre: Pies de luz
- tipo: boost
- descripción: Purificar un bloque da +1 de claridad.
- peso: 1
- valor: 200

## paso_firme
- nombre: Paso firme
- tipo: boost
- descripción: Trepar y bajar escalones no cuenta para la caída de la fila base.
- peso: 1
- valor: 220

## reflejos
- nombre: Reflejos
- tipo: boost
- descripción: Las cuentas de las bombas empiezan 3 movimientos más altas.
- peso: 1
- valor: 200

## bolsillo_hondo
- nombre: Bolsillo hondo
- tipo: boost
- descripción: Suma 1 lugar de consumibles. Se acumula.
- peso: 1
- valor: 200
- se_acumula: true

## mente_abierta
- nombre: Mente abierta
- tipo: boost
- descripción: Suma 2 lugares de boosts (ocupa uno). Se acumula.
- peso: 1
- valor: 220
- se_acumula: true

## racha_larga
- nombre: Racha larga
- tipo: boost
- descripción: El tope del multiplicador de racha sube de ×4 a ×6.
- peso: 1
- valor: 220

# Nivel común

## aire_extra
- nombre: Aire extra
- tipo: boost
- descripción: La fila de abajo cae 1 movimiento más tarde.
- peso: 1
- valor: 100

## ojo_de_hielo
- nombre: Ojo de hielo
- tipo: boost
- descripción: Al resbalar por el hielo te frenás una celda antes.
- peso: 1
- valor: 90

## ahorro
- nombre: Ahorro
- tipo: boost
- descripción: Cada etapa arrancás con 20 de claridad.
- peso: 1
- valor: 110

## freno
- nombre: Freno
- tipo: consumible
- descripción: Pausa la caída de la fila base durante 5 movimientos.
- peso: 1
- valor: 100

## catapulta_de_bolsillo
- nombre: Catapulta de bolsillo
- tipo: consumible
- descripción: Convierte el bloque que tenés enfrente en una catapulta.
- peso: 1
- valor: 110

## desarmar
- nombre: Desarmar
- tipo: consumible
- descripción: Desactiva una bomba a la vista.
- peso: 1
- valor: 90

# Nivel consumible (barato)

## bolsa_de_luz
- nombre: Bolsa de luz
- tipo: bolsa de claridad
- descripción: Devuelve 1,4 veces lo que pagaste por la ficha, en claridad.
- peso: 6
- mult: 1.4

## hielo_a_roca
- nombre: Hielo a roca
- tipo: consumible
- descripción: Convierte un bloque de hielo cercano en un bloque normal.
- peso: 2
- valor: 70

## ancla_chica
- nombre: Ancla chica
- tipo: consumible
- descripción: Un bloque de tu elección no cae aunque pierda sus vecinos (una etapa).
- peso: 2
- valor: 70
