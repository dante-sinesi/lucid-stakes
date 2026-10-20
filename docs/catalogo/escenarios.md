# Escenarios

Los escenarios son como los mazos de Balatro: cada uno cambia las reglas de la partida. La Pesadilla es gratis; los demás cuestan Luz *por partida*. Al **escapar de la pesadilla** (terminar las 27 etapas) en un escenario se gana una de sus habilidades persistentes (una por vez, al azar, entre las que todavía no tenés); cuando ya las tenés todas se da Luz (30 × multiplicador del escenario).

Campos: `entrada` = Luz que cuesta jugarlo · `multiplicador_luz` = cuánto más Luz paga al terminar · `pruebas` = ids del sorteo de pruebas (ver pruebas.md) · `habilidades` = ids de habilidades que se pueden ganar (ver habilidades_persistentes.md) · `ritmo` = ritmo de caída fijo (vacío = el de cada etapa) · `dificultad_extra` = se suma a la dificultad de las torres · `casino` = nivel de sala desde la etapa 1 (-1 = el de cada etapa) · `precio_ficha` = multiplicador del precio de la ficha · `sesgo` = bloques que abundan.

## pesadilla - La Pesadilla
- descripción: El juego de siempre: torres de bloques corruptos que se aclaran etapa a etapa. Gratis.
- entrada: 0
- multiplicador_luz: 1.0
- pruebas: niebla, oscuridad, prisa, sin_ayudas, todo_o_nada, sin_racha
- habilidades: mente_despejada, ojos_de_gato, racha_firme
- ritmo: 
- dificultad_extra: 0.0
- casino: -1
- precio_ficha: 1.0
- sesgo: (ninguno)

## ruinas - Ruinas
- descripción: Dominan los bloques agrietados y los pesados: casi nada se puede pisar dos veces.
- entrada: 15
- multiplicador_luz: 1.5
- pruebas: quebradizo, oscuridad, sin_ayudas, todo_o_nada, sin_racha
- habilidades: fuerza_bruta
- ritmo: 
- dificultad_extra: 0.0
- casino: -1
- precio_ficha: 1.0
- sesgo: agrietado +0.7, pesado +0.5, tope de especiales +1

## polvorin - Polvorín
- descripción: Bombas por todos lados. La presión no para.
- entrada: 20
- multiplicador_luz: 1.6
- pruebas: polvorin, prisa, niebla, sin_ayudas
- habilidades: mecha_larga
- ritmo: 
- dificultad_extra: 0.0
- casino: -1
- precio_ficha: 1.0
- sesgo: bomba +0.8, tope de especiales +1

## relojeria - Relojería
- descripción: La fila de abajo siempre cae rápido, pero la ficha de la ruleta es más barata.
- entrada: 25
- multiplicador_luz: 1.8
- pruebas: prisa, niebla, oscuridad, todo_o_nada, sin_racha
- habilidades: pies_ligeros
- ritmo: fast
- dificultad_extra: 0.0
- casino: -1
- precio_ficha: 0.75
- sesgo: (ninguno)

## gran_casino - Gran Casino
- descripción: El casino es de lujo desde el principio y la ficha es más barata, pero las torres son más difíciles.
- entrada: 30
- multiplicador_luz: 1.4
- pruebas: niebla, oscuridad, prisa, sin_ayudas, todo_o_nada, sin_racha
- habilidades: bolsillo_sonador, segunda_oportunidad
- ritmo: 
- dificultad_extra: 0.15
- casino: 3
- precio_ficha: 0.8
- sesgo: (ninguno)
