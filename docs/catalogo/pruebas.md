# Pruebas

Las pruebas son etapas especiales (como los jefes de Balatro): caen en las etapas 3, 6, 9, 12, 15, 18, 21, 24, 27. Al empezar cada partida se sortea cuál toca en cada una (del sorteo del escenario, sin repetir la misma dos veces seguidas) y se ve desde el principio. Cada prueba cambia una regla de la torre, paga más claridad (×1,5 la primera hasta ×2,7 la última: `1,5 + 0,15 × número de prueba`) y al superarla regala un boost raro (épico en las últimas). **No dan habilidades persistentes** (esas se ganan por escenario).

Reglas posibles: `niebla` (sólo se ven 3 pisos por encima), `oscuridad` (sólo los bloques a 4.5 celdas), `ritmo` (ritmo de caída fijo), `sin_consumibles`, `sin_reintentos`, `sin_racha`, `sesgo` (bloques que abundan en la torre).

## niebla - Niebla
- descripción: Sólo ves unos pocos pisos por encima de vos.
- niebla: true
- oscuridad: false
- ritmo: 
- sin_consumibles: false
- sin_reintentos: false
- sin_racha: false
- sesgo: (ninguno)

## oscuridad - Oscuridad
- descripción: Sólo ves los bloques que tenés cerca.
- niebla: false
- oscuridad: true
- ritmo: 
- sin_consumibles: false
- sin_reintentos: false
- sin_racha: false
- sesgo: (ninguno)

## prisa - Prisa
- descripción: La fila de abajo cae mucho más rápido.
- niebla: false
- oscuridad: false
- ritmo: fast
- sin_consumibles: false
- sin_reintentos: false
- sin_racha: false
- sesgo: (ninguno)

## sin_ayudas - Sin ayudas
- descripción: No se pueden usar consumibles.
- niebla: false
- oscuridad: false
- ritmo: 
- sin_consumibles: true
- sin_reintentos: false
- sin_racha: false
- sesgo: (ninguno)

## todo_o_nada - Todo o nada
- descripción: No hay reintentos: si caés, se termina el run.
- niebla: false
- oscuridad: false
- ritmo: 
- sin_consumibles: false
- sin_reintentos: true
- sin_racha: false
- sesgo: (ninguno)

## sin_racha - Sin racha
- descripción: La racha no sube el multiplicador de claridad.
- niebla: false
- oscuridad: false
- ritmo: 
- sin_consumibles: false
- sin_reintentos: false
- sin_racha: true
- sesgo: (ninguno)

## hielo_total - Hielo total
- descripción: La torre está llena de hielo.
- niebla: false
- oscuridad: false
- ritmo: 
- sin_consumibles: false
- sin_reintentos: false
- sin_racha: false
- sesgo: hielo +1.6, plataformas con hielo 0.35, tope de especiales +3

## quebradizo - Quebradizo
- descripción: Casi todo se rompe al pisarlo o no se mueve.
- niebla: false
- oscuridad: false
- ritmo: 
- sin_consumibles: false
- sin_reintentos: false
- sin_racha: false
- sesgo: agrietado +1.2, pesado +0.8, tope de especiales +3

## polvorin - Polvorín
- descripción: La torre está llena de bombas.
- niebla: false
- oscuridad: false
- ritmo: 
- sin_consumibles: false
- sin_reintentos: false
- sin_racha: false
- sesgo: bomba +1.2, tope de especiales +2
