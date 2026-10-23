# La torre: reglas

Descripción exacta de lo que hace el juego con la torre (`torre/`). Cada regla dice dónde vive en el código. Lo que es provisorio va marcado como **(provisorio)** o **(pendiente)**.

## 1. La torre

- Un **anillo de 11 x 11 celdas con un vacío de 5 x 5** en el medio (celdas 3 a 7 en x y en z). Sin piso y sin núcleo: lo que cae por debajo del nivel 1 se pierde. `Torre.es_anillo`, `LADO = 11`.
- La torre es una **pila de salas**, cada una en su propio tramo de altura, que **da vueltas al anillo** siempre hacia el mismo lado. Una sala mide 3x3 (esquina), 5x3 (lado) o 8x3 (lado más una esquina) y su altura máxima es la cantidad de celdas de su huella: 9, 15 y 24. `Torre.armar`.
- **Encadenado:** la salida de una sala (un bloque "f", el ancla) es la misma celda que la entrada de la siguiente (un bloque "p", un nivel más arriba de ella). Para que eso pase, cada sala se **gira o espeja** (las 8 simetrías del cuadrado: el motor es simétrico) y se **desliza** por el anillo hasta que su entrada cae en la salida de la anterior. La huella tiene que quedar dentro del anillo, sin pisar el vacío. `Torre.girar`, `Torre.mover`, `_extender`.
- **Espiral:** cada sala nueva tiene que avanzar, alrededor del centro del anillo, entre 12° y 150° en el mismo sentido que la anterior (el sentido se sortea al armar la torre). Si no hay manera, se arma sin esa condición.
- **La sala de arriba cuenta:** al elegir una sala, el camino de la sala de abajo se vuelve a comprobar con los bloques de la nueva (hasta 6 niveles por encima de la salida) como obstáculos fijos. Si taparían el camino, esa colocación se descarta. Mientras se juega, esos bloques están en el motor (tipo "f", no se dibujan dos veces). `Torre.obstaculos_de`, `Motor.agregar_obstaculos`.
- Nunca se repite una sala en la misma torre. Las dos primeras salas son de bloques comunes.

## 2. Sostén

- Dos bloques se tocan por **cara o por arista horizontal** (14 vecinos); la propagación es simétrica. `Reglas.VECINOS`.
- **En toda sala hay un único bloque fijo: su salida ("f").** Está anclado y no se mueve. Todo lo demás está anclado sólo si toca, en cadena, a un bloque anclado.
- Lo que no está anclado **cae en línea recta** hasta apoyarse en algo sostenido; si no hay nada, se pierde (desaparece). Un bloque que cae sobre el jugador se queda ahí hasta que éste se mueva. `Reglas.asentar`.
- Mientras se juega una sala, las salas de arriba son decorado anclado: nada de lo que pasa en la actual las toca. Al llegar a la salida, **la sala anterior cae**.

## 3. Movimientos (`torre/motor.gd`)

Todos gastan **un movimiento** (si salen bien); los que no salen bien no gastan nada y avisan por qué.

- **Caminar:** a la celda de al lado si hay bloque debajo; baja un escalón si el siguiente escalón está apoyado; sube un bloque si hay uno adelante y hay lugar arriba (de la celda y de donde estás). Sin bloque debajo ni a un escalón: "Borde".
- **Empujar y tirar (mantener la tecla de empujar):** empuja el bloque de adelante (una fila de hasta **3 bloques** siempre que la celda de más allá esté libre y ninguno sea fijo ni pesado). Un bloque de **hielo** empujado solo se desliza hasta chocar o salir de la huella. Tira del bloque de atrás hacia donde estabas; si adelante hay un escalón más abajo, se baja; si adelante no hay piso, el bloque viene y el jugador queda **colgado** del bloque donde estaba parado. Empujar sin nada que empujar ni tirar es un paso común.
- **Colgarse (mantener la tecla de colgarse y una dirección):** hacia un borde sin piso; no se puede si se está sobre hielo.
- **Colgado:** la dirección hacia el bloque trepa; la contraria no hace nada: **la única forma de soltarse es la tecla de colgarse (la barra)**; las demás avanzan por el borde y doblan esquinas (hacia adentro, también hacia bloques que tienen otro encima, y hacia afuera). No se puede agarrar de un bloque de hielo.
- **Deshacer:** deshace el último movimiento de la sala (con la claridad que se había juntado y la cuenta de movimientos). Lo que hizo un consumible no se deshace. No se puede en los escenarios sin deshacer (Sin piedad). `Torre.deshacer`.

## 4. Bloques

| Letra | Bloque | Qué hace |
|---|---|---|
| n | Común | Se pisa, se empuja, se tira |
| p / f | Checkpoint de entrada / de salida | Dorados. El de salida es el ancla fijo de la sala (se gana parado sobre él, un nivel más arriba) |
| h | Pesado | De hierro: no se empuja ni se tira, pero se trepa |
| i | Hielo | Al llegar parado sobre él se sigue resbalando en la dirección del movimiento (hasta 40 celdas); si se sale de la huella se pierde la sala; no se agarra uno de su borde |
| c | Agrietado | De arenisca: se rompe al bajarse de él |
| t | Trampa | Parece común; al quedar parado encima se desarma y cae (con el jugador si abajo hay otro bloque) |
| s | Pinchos | Quedar parado encima pierde la sala; se empuja y se tira como uno común |
| k | Catapulta (trampolín) | Al llegar parado encima, sube 4 celdas (más hasta 2 buscando agarre) y queda colgado del costado de un bloque que tenga el borde de arriba libre; sólo hacia arriba |
| b7 / d | Bomba con mecha / desactivada | La mecha (el número) baja **1 por acción mientras el jugador está dentro de su zona** (celdas con dx²+dy²+dz² ≤ 5); fuera se congela. Al llegar a 0 explota y se pierde la sala. Pararse encima la desactiva ("d", queda como un común); si cae fuera de la huella se pierde. Ganar en el mismo movimiento gana a la explosión |

Una sala tiene 1 a 3 especiales según su altura (1 + (pisos − 3) // 9). Cada especial está en la sala por un propósito comprobado: si se lo cambia por un bloque común, cambia el camino o cuánto pesa cada movimiento (`docs/generador.md`).

## 5. Temporizador, muerte y vidas

- **Temporizador de movimientos por sala:** el mínimo conocido de la sala × 1,9 / 1,6 / 1,4 / 1,25 + 10 / 8 / 6 / 5 movimientos, según su nivel (fácil / media / difícil / pesadilla); el margen (lo que pasa de ×1 y los movimientos extra) vale la mitad en la etapa 1 y crece hasta completo en la etapa 8, y además se multiplica por la dificultad elegida (`MARGEN_DIFICULTAD`: Fácil ×1,25, Medio ×1, Difícil ×0,85, Pesadilla ×0,7). **(provisorio)** `Torre.max_movimientos`.
  - Madrugada lo multiplica por 1,25; Aire extra suma 4; Freno suma 5 y Reloj de arena 10 (sólo a la sala actual); Pies ligeros y Aire de más suman 1 por mejora; Paso firme hace que trepar y bajar un piso no gaste. `Torre.max_mov`.
  - Los últimos 5 movimientos se ven como un número sobre el personaje (rojo con 3 o menos). Ganar en el último movimiento gana al temporizador.
- **Perder una sala:** caer al vacío, quedar sobre pinchos, explotar una bomba, agotar los movimientos o (Sin piedad) pasarse del último movimiento en falso. El personaje se cae dando vueltas (con toda la sala si se acabaron los movimientos) y aparece la **pantalla de derrota** con *Reintentar (−1 vida)* y *Salir al menú principal* (Espacio reintenta, Shift sale al menú). Reintentar vuelve al **checkpoint** de la sala con la sala **virgen**, y recién entonces cuesta la vida (el Tótem lo hace gratis). La claridad que se juntó en ese intento se pierde. Sin vidas, el run termina. `Torre._morir`, `main._torre_murio`, `request_restart`.
- **Segundo aliento:** una vez por torre vuelve a empezar la sala sin perder la vida.
- **Reintentar la torre entera** (tecla de reintentar o desde la pausa): vuelve a la primera sala y cuesta una vida. Guardar y continuar también empieza la torre desde la primera sala (si se había muerto y no reintentado, cuenta como reintento).
- Cada torre empieza con la pantalla de **dados** del tabernero (con "Empezar" ya habilitado).

## 6. Checkpoints y Farolín

- Al llegar a la salida de una sala, el bloque queda como entrada de la siguiente y la sala anterior cae. **Farolín está sentado, apoyado en un tronquito, en una esquina del próximo checkpoint**, mirando al centro del cubo (la esquina con menos bloques al lado). Al llegar dice cuántos checkpoints faltan, contando el portal ("Buen comienzo, faltan 6", "Ya casi: la siguiente es la última").
- El último checkpoint es el **cubo-portal** luminoso del juego. Llegar a él termina la torre: la claridad pasa al run y sigue el casino (o el final del juego en la etapa 15).

## 7. Claridad (`torre/cosecha.gd`)

- Pisar un bloque o colgarse de él lo **purifica** y da su claridad: común 1, hielo 2, agrietado 2, pesado 2, trampa 2, pinchos 3, catapulta 3, bomba 5, checkpoint 1.
- **Racha:** cada acción que purifica algo nuevo sube la racha; una que no purifica nada la corta. Multiplicador = 1 + 0,5 × (racha − 1), con tope ×4 (Racha larga ×6, Racha imparable ×8; Mano de oro de a 1,0).
- **Cosecha:** Cosecha ×1,5, Cosecha doble ×2 y la Poción de cosecha ×2 se multiplican. Pies de luz +1, Pies de oro +2 y Midas +3 por bloque; Buen ojo duplica los especiales; Escalador +2 por piso nuevo; Empuje rentable +1 por bloque movido.
- La claridad de una sala queda **asegurada** al llegar a su checkpoint; si se pierde la sala, se pierde la del intento. Farolín cobra el peaje en la puerta del casino, como siempre.

## 8. Etapas

- **Largo:** 5 salas en la etapa 1 hasta 14 en la 15 (`Torre.salas_de_etapa`).
- **Dificultad:** `p = 0,6 × (etapa − 1)/14 + 0,4 × (sala/(n − 1))`, corrida por la dificultad elegida (`PENDIENTE_DIFICULTAD`); <0,2 fácil · <0,4 fácil o media · <0,6 media · <0,75 media o difícil · <0,9 difícil · el resto difícil o pesadilla. Si no hay sala del nivel que toca se acepta de otro.
- **Aprendizaje (`Torre.limites_aprendizaje`):** las primeras torres usan salas bajas, cortas y con pocos bloques que mover. Etapa 1: las dos primeras salas de hasta 5 pisos, 10 pasos mínimos y 1 bloque distinto movido; las dos siguientes hasta 6 pisos, 12 pasos y 1 bloque; la última hasta 7 pisos, 15 pasos y 2 bloques. Etapa 2: 8 pisos, 16 pasos, 2 bloques. Etapa 3: 11 pisos, 20 pasos, 3 bloques. Etapa 4: 15 pisos, 28 pasos, 4 bloques. Desde la 5 manda sólo la curva de dificultad.
- **Especiales habilitados:** hielo en la etapa 2, pesado 3, agrietado 4, trampa 5, pinchos 6, bomba 7, trampolín 8. (Todavía no hay salas con trampa.)
- Las salas salen del paquete `data/salas_torre.jsonl` (`herramientas/armar_paquete.py`): 1208 salas de 4 a 23 pisos. Las de más de 10 pisos se resolvieron por lonjas: su camino es válido pero puede no ser el más corto.

## 9. Escenarios y pruebas

- **Sin piedad:** cada sala permite 2 movimientos en falso (3 con Margen de error). Un movimiento es "en falso" si después faltan **más** pasos para salir de la sala (lo mide el solucionador nativo en un hilo). El siguiente pierde la sala. No se puede deshacer.
- **Pruebas** (cada 3 etapas): hoy son Sin ayudas, Todo o nada y Sin racha, más el multiplicador de claridad de la etapa. **(pendiente)** repensar más pruebas (ver `pendientes.md`).
- **Tutorial:** todas las lecciones se juegan con este motor: las de movimiento son salas dibujadas por capas (`Tutorial.sala_de_capas`) y la última, "Una torre de verdad", es una torre de 2 salas.

## 10. Controles

Los del juego (`Controls`): movimiento, empujar, colgarse, deshacer, reintentar, consumibles, cámara, vista isométrica, zoom, profundidad y pausa, con teclado, mando y reasignaciones. Tab muestra la torre entera. La **ayuda de profundidad** (tecla "profundidad") aclara lo que está más cerca de la cámara que el personaje y oscurece lo lejano; en su tercer modo, además, los bloques que tapan al personaje se vuelven una malla calada.
