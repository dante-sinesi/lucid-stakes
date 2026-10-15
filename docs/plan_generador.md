# Plan del generador de torres

## Lo que se quiere (de lo que dijo el usuario)
- Torres que cuesten de verdad: que haya que mover bloques en todas las salas, no sólo caminar.
- Nada de trucos injustos (un clic de más en un escalón de arenisca no tiene que arruinar la partida).
- Calidad sobre variedad; salas orgánicas, no siempre la misma sala.
- Más adelante: salas tipo dibujadas por el usuario (marcar inicio, fin y bloques) que el generador generaliza.

## Métrica de desafío (`scripts/tower_metrics.gd`, `tests/probe_metrics.gd`)
Puntaje 0–100 por torre, promedio ponderado de: salas donde hay que mover bloques, agarres totales, bloques distintos movidos, castigo al error (fracción de
equivocaciones sin salida), ritmo de caída justo, variedad de ideas y búsqueda del solucionador. Las metas suben con la dificultad. Se mide con
`probe_metrics.gd` (por etapa y semilla) y el promedio es el número a subir sin que el tiempo de generación pase de ~30 s ni haya fallos.

## Estructuras tipo
Cada sala es una idea con giros. Para que "haya que mover bloques" en todas, las ideas que se resuelven caminando (trampas, pista de hielo, bomba) ganan un
obstáculo propio (escalón que falta, puerta de bloques, etc.), y las demás ganan capas y más agarres con la dificultad.

## Bucle de trabajo
1. Medir (línea base). 2. Cambiar una cosa del generador. 3. Medir de nuevo (misma semilla). 4. Quedarse con el cambio si sube el puntaje sin romper tiempo ni
tests (`test_rooms`); si no, revertirlo. 5. Anotar acá el resultado.

## Registro
- Línea base (antes de las rondas): promedio ~67 pts (etapas 3 a 15), castigo al error ≈ 0,06 (medido como fracción), etapas altas con 48–63 pts.
- Ronda 1: la primera sala ya no es de respiro desde dificultad 0,3; las ideas que se resuelven caminando salen a lo sumo una vez por torre. Etapas altas ~75.
- Ronda 2: métrica de castigo en movimientos de más (en vez de fracción de equivocaciones sin salida); campo de trampas con puerta de bloque (desde 0,25 hay que empujar un bloque
  para llegar al primer escalón); caída más justa (holgura según n_min, piso de 1,3). Promedio ~85 pts (etapas 2–15), etapas altas 73–98.
- Pendiente: pista de hielo y bomba siguen resolviéndose caminando; generación de 15–30 s en las etapas altas; salas dibujadas por el usuario (ver conversación).
- Ronda 3 (el usuario llegó a la etapa 13 sin pisar un casino ni usar nada): la métrica de "titubeos" mostró que la caída no apretaba (la torre aguantaba 12+ ida-y-vueltas, 24 movimientos
  de más). Ahora, al cerrar la torre, el ritmo de caída se aprieta hasta que sólo aguante 12 titubeos a dificultad baja y 4 a dificultad 1 (`Metrics.tightest_n`): en las etapas altas N queda en 4–7
  (antes 9–13). Además se elige la mejor de 2–3 salas válidas (búsqueda + agarres + costo del error), la primera sala ya es una idea, y las salas de muros llevan capas extra. Generación 20–45 s.
- Probado y descartado: salas de 3 pisos y de 2 pisos para ideas de pared (muchas salas caían a respiro y tardaba 60–100 s).
- Idea abierta: las salas de 4 pisos tienen el acertijo sólo en el piso de abajo; los otros 3 son escalera. Mover el desafío a lo vertical (cornisas, huecos) sería el próximo salto.
- Ronda 4 (el usuario pasó la etapa 5, 10 y 14 "moviendo uno o dos bloques"; en Catherine hay ~15 movimientos de bloques para subir 3 filas): la caída apretada no resuelve nada, el problema
  es la complejidad del acertijo. Lo que se aprendió midiendo con el solucionador (no con la métrica de arriba, que no veía esto):
  * Un muro denso de cubos desordenado con movimientos reversibles ("reja", desordenar una sala resuelta) PARECE largo (60–120 movimientos) pero el solucionador lo resuelve en 6–11:
    la meta (llegar arriba) se alcanza de muchas maneras y el desorden no la obliga a restaurar nada. Se dejó el código (`_c_reja`, `_scramble`) pero fuera del catálogo (`REJA=1` lo activa).
  * Los bloques no se pueden subir (sólo se mueven en horizontal), así que no se puede "armar" altura: el desafío vertical sale de huecos y alturas que ya están.
  * Lo que sí da acertijos largos de verdad es la búsqueda exhaustiva sobre una arena chica (como los generadores de Sokoban): `taller`.
- `taller` (sala de 2 pisos): arena de 12 a 25 celdas (con un pasillo de hasta 4 celdas desde la llegada), muros pesados de 3 de alto, 1 a 4 cajas, y un pilar de 2 (la salida) que sólo se sube
  con una caja en su única celda libre `T` (el tope del pilar es fijo). Se arma el estado resuelto, se exploran TODOS los estados que se alcanzan con movimientos reversibles (6000 como máximo)
  y se elige el comienzo con el camino más corto más largo (Dijkstra exacto dentro de esos estados). El camino queda guardado (no se vuelve a buscar) y se comprueba rejugándolo en la torre
  real. Salen acertijos de 20 a 35 movimientos con 6 a 13 agarres por sala; una torre de 12 salas tarda ~55 s en generarse y ronda los 330 movimientos.
- Los topes de la generación pasaron de tiempo a trabajo (resoluciones y candidatos): la misma semilla da siempre la misma torre (antes dependía de la velocidad de la máquina).
- Bug que apareció y se arregló: con una "gracia" de caída menor a 2 que no se verificaba, algunas torres no se podían ganar; ahora se vuelve al ritmo comprobado.
- Pendiente: más formas de arena (hoy 4x3 y 3x4 casi siempre), mezclar bloques especiales dentro de los acertijos de cajas, cuántas salas de cajas por torre (hoy ~65 % a dificultad alta).
- Ronda 5 (comentarios tras jugar las etapas 5, 6 y 10): "difícil en dos o tres situaciones, no mucho más". Lo que se descubrió: la búsqueda por estados reversibles SOBREESTIMA los acertijos de cajas (hay atajos
  irreversibles y, con el mundo ampliado, colgarse). Se pasó a medir con el **solucionador completo** (todas las acciones) y con **bloques movidos** (agarres) en lugar de movimientos. Medido así, en arenas de 4x3 los
  acertijos tienen 2 a 5 agarres; en tiras largas de 8x3 salen 7 a 8 (Sokoban real). Por eso se agregaron formas de arena (3x3, 6x3, 3x6, 7x3, 8x3...) y se pide un mínimo de agarres verdaderos según la dificultad.
  Cuesta ~20–30 s por sala; tope de 5 salas de cajas por torre (hasta 2 seguidas).
- Pendiente (propuesta del usuario): salas de altura variable (hasta 15) combinando varios niveles de arena con pilares, y más formas de arena (esquina, centro, medio, ring alrededor del core).
- Idea del usuario (salas por tamaño: chicas 3x3/3x4/3x5 de 5 de alto, medianas 3x6..3x8 y alguna L de 5x5 de 5 a 10 de alto, grandes; con temas: hielo en las grandes, bombas en las chicas). Experimento `tests/exp_vert.gd`:
  una arena de 3x3 con columnas de altura 0 a 3 al azar y una meta alta en la esquina se resuelve (60 %) con hasta 7 bloques movidos en el mejor de 150; una de 3x4 de 5 de alto, hasta 6. Es mejor que las
  arenas planas de 4x3 (2 a 5), porque la altura permite armar escalones redistribuyendo columnas (un bloque de arriba que se empuja sobre una columna baja la sube). Es el próximo paso.
