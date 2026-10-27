# Logros de Steam (propuesta)

Borrador para conversar: todavía no hay nada programado. La idea es una lista corta de **48 logros** (más algunos secretos), repartidos en cinco familias, donde el jugador que prueba la demo puede ganar **18 logros básicos** y el juego completo tiene la lista entera.

## Reglas de diseño

1. **Un logro, una cosa que se sienta.** Nada de "juega 50 horas" ni contadores enormes: los números grandes se reservan para un par de logros de largo plazo.
2. **Se reparten por dificultad percibida:** más o menos la mitad son de descubrimiento y progreso (los gana casi cualquiera que juegue un rato), un tercio piden habilidad o decisiones y el resto son de maestría o secretos.
3. **Los logros no dan ventaja en el juego.** Ni habilidades ni Luz: son reconocimiento. Eso permite que se puedan falsificar sin consecuencias (ver "La demo").
4. **Cada logro se puede ganar en cualquier dificultad**, salvo los que dicen lo contrario. Fácil (movimientos ilimitados y pista) cuenta para los de descubrimiento y progreso, pero no para los de maestría (los marcados con **M**).
5. **Los bloques de la trampa quedan fuera** mientras el bloque esté en pausa (ver `pendientes.md`).
6. **Nombres cortos y en español neutro (tuteo)**, con la frase en inglés en `scripts/idioma/loc_en*.gd` como el resto del texto del juego. La descripción dice qué hay que hacer, sin spoilers en los secretos.

## La demo

La demo llega hasta el casino de la etapa 6 (tutorial, La Pesadilla, las dos primeras pruebas, la taberna y el salón con la ruleta, el Taller y el tablón). No tiene bombas ni catapultas, ni tragamonedas ni blackjack, ni los otros escenarios. Los logros marcados **D** se pueden ganar en la demo (18 de 48).

**Decisión tomada:** los logros de la demo **no se transfieren** al juego completo. Una demo de Steam es una app aparte con su propio App ID y sus logros no pasan al comprar; los logros de la demo son básicos y se vuelven a ganar en los primeros minutos, así que no vale una solución propia por ahora. Los logros **D** existen también en el juego completo, con el mismo nombre y condición, para que el que compra los recupere enseguida. Si más adelante la lista de la demo se hace larga o difícil, se puede hacer que la demo guarde en su archivo qué logros ganó y que el juego completo lo lea al abrirse (anotado en `pendientes.md`).

## Progreso (14)

| Logro | Condición | |
|---|---|---|
| Despertar | Terminar el tutorial. | D |
| El primer peaje | Pagarle a Farolín por primera vez. | D |
| Tres pisos de pesadilla | Superar la etapa 3. | D |
| Más allá del salón | Superar la etapa 6. | D |
| A mitad del camino | Superar la etapa 8. | |
| La última puerta | Llegar a la etapa 15. | |
| Escapar | Escapar de La Pesadilla (completar las 15 etapas). | |
| Escapar sin miedo | Escapar en Fácil. | |
| Escapar con cabeza | Escapar en Medio. | |
| Escapar con agallas | Escapar en Difícil. | M |
| Escapar de verdad | Escapar en Pesadilla. | M |
| El camino corto | Escapar en El camino corto (antes Sin piedad). | M |
| Sin una raya | Escapar sin perder ninguna vida. | M |
| Dar la vuelta | Escapar en cada dificultad. | M |

## Habilidad en la torre (14)

| Logro | Condición | |
|---|---|---|
| Camino corto | Superar una sala en exactamente el mínimo de movimientos. | D |
| Camino corto, diez veces | Diez salas seguidas en el mínimo, en la misma torre. | M |
| Sin tocar nada | Superar una sala sin empujar ni tirar de ningún bloque. | D |
| Todo limpio | Purificar todos los bloques de una sala. | M |
| Racha de cuatro | Llegar al tope de racha (×4). | D |
| Racha de seis | Llegar a ×6 (con Racha firme). | |
| Justo a tiempo | Superar una sala con 0 movimientos restantes. | D |
| Sin marcha atrás | Superar una etapa entera sin deshacer. | D |
| Por un tic | Ganar una sala en el mismo movimiento en que una bomba llega a 0. | |
| Desarmador | Desactivar tres bombas en una sala. | |
| Salto de fe | Saltar con una catapulta y agarrarte. | |
| Patinaje | Resbalar seis celdas seguidas por el hielo. | D |
| Roca firme | Superar una sala con bloques pesados sin empujar nada. | D |
| Hasta el último escalón | Terminar una torre sin perder ni una sala. | M |

## Casino y contratos (10)

| Logro | Condición | |
|---|---|---|
| A la ruleta | Jugar a la ruleta por primera vez. | D |
| Pleno | Acertar un número pleno en la ruleta. | D |
| Manos arriba | Jugar blackjack por primera vez. | |
| Veintiuno | Sacar blackjack de entrada. | |
| Tres iguales | Ganar con un premio mayor en las tragamonedas. | |
| Taller | Vender o cambiar un ítem en el Taller. | D |
| Primer contrato | Cumplir un contrato. | D |
| Con fianza | Cumplir un contrato que pidió fianza. | |
| Sello negro | Cumplir un contrato de sello negro. | M |
| Papeleo | Cumplir tres contratos en la misma torre. | |

## Colección y metaprogreso (6)

| Logro | Condición | |
|---|---|---|
| Conejito | Desbloquear a Conejito (llegar a la etapa 10). | |
| Con estilo | Equiparle a un personaje un gorro y una prenda de rareza épica. | |
| De pies a cabeza | Tener todos los cosméticos comunes. | |
| Un talento por escenario | Ganar una habilidad persistente en cada escenario jugable. | |
| Mochila llena | Tener ocupados todos los lugares de boosts. | |
| Luz de sobra | Juntar 1000 de Luz en total. | |

## Pruebas y dados (4)

| Logro | Condición | |
|---|---|---|
| Prueba superada | Superar una prueba. | D |
| Tres reglas | Superar cada una de las tres pruebas, aunque sea en torres distintas. | |
| Cinco de cinco | Acertar los cinco dados en la pantalla de carga. | D |
| Lluvia de dados | Ganar un cosmético en los dados. | D |

## Secretos (ejemplos)

Se ven en Steam con el nombre y la descripción ocultos hasta ganarlos. Los dejo abiertos a lo que se te ocurra; estos son ejemplos que no dependen de código nuevo:

| Logro | Condición |
|---|---|
| Caída libre | Caer al vacío 50 veces. |
| Cenizas | Que exploten 10 bombas en total. |
| Farol a farol | Hablar con Farolín en los cuatro casinos. |
| Cabeza fría | Perder una sala sobre pinchos y salir de ahí con una vida. |
| Última chance | Superar una sala con el Segundo aliento después de perder la anterior. |

## Cantidades

- **Total:** 48 logros + secretos (53 con los cinco de arriba).
- **En la demo (D):** 18 de los 48 se pueden ganar en la demo. Si se decide que la demo tenga logros propios (pregunta 4), esta es la lista candidata; si no, son los que el que compra gana en los primeros minutos del juego completo.
- **Maestría (M):** 9.

## Cómo se programaría

- **API:** GodotSteam (extensión de Godot) con `setAchievement` y `storeStats`; sin Steam abierto, el juego sigue funcionando y los logros quedan en cola.
- **Dónde se dispara cada uno:** ya hay eventos para casi todos. `torre_juego.gd` emite `contrato_evento` con la racha, la claridad, los saltos, los bloques movidos, las bombas desactivadas y los especiales purificados; el resto sale de `telemetry.gd` (sala, torre, casino, peaje, fin del run).
- **Contadores:** los de "veces" (50 caídas, 10 bombas) y los de "en total" (Luz) se guardan en `profile.gd` y se sincronizan como estadística de Steam.
- **Un módulo nuevo** (`scripts/datos/logros.gd`) con la lista, sus condiciones y el desbloqueo; una prueba (`test_logros.gd`) que recorre la lista y comprueba que cada condición se puede cumplir.
- **Sin Steam:** el perfil guarda los logros ganados, así que se pueden ver también en una pantalla propia del juego (opcional) y se entregan a Steam la próxima vez que haya conexión.

## Preguntas abiertas

1. ¿Los logros de dificultad Fácil cuentan para todo, o solo para los de progreso?
2. ¿Cuántos secretos? Valve recomienda que no sean la mayoría.
3. ¿Una pantalla propia con la lista de logros dentro del juego, o solo Steam?
4. ¿La demo tiene sus propios logros, o ninguno?
