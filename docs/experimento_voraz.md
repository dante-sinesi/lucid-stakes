# Experimento: búsqueda voraz y "salas en límite" (14/10)

Script: `tests/exp_voraz.gd` (variables N, SEED, POP, WEIGHTS, CAPMULT, BIG). Toma cambios de salas del archivo del minero (alturas 5 a 8, las 5 formas) y mira los que el A* normal no resuelve dentro de su tope ("límite", alrededor del 20 al 30 % de los cambios válidos).

## 1. ¿Una búsqueda voraz los resuelve? No.
A* con la heurística pesada (pesos 2, 5 y 20, que se acerca a una búsqueda voraz) y un tope 4 veces mayor: **0 de 21** salas resueltas. La heurística actual sólo mide cuánto falta para subir, y en estas salas hay que **empujar antes de subir**: la búsqueda voraz se va a trepar y se mete en callejones sin salida.

## 2. ¿Esas salas son imposibles? La mayoría no.
Con 400 000 estados y 100 s, de 6 salas en límite: **3 se resolvieron** (15, 18 y 23 pasos, con 9 153, 67 915 y 80 888 estados) y 3 siguieron sin resolverse. Con el tope normal (unos 5 000 estados) no llegaban. O sea que son salas **difíciles pero resolubles**, y justo las que interesan.

## 3. Una condición necesaria barata
"Para subir h pisos hace falta, en cada nivel L, al menos h - L bloques sueltos de ese nivel o de más arriba" (un bloque no sube nunca). Es correcta (0 salas resueltas la violan) pero **casi no filtra**: la violan 3 a 4 de cada 70 a 130 cambios.

## Conclusión
El techo de empujes lo pone la **velocidad del solucionador** (unos 3 000 estados por segundo en GDScript: 80 000 estados son 27 s): sin tope sí aparecen salas más difíciles. Las salas de 9 000 a 80 000 estados serían rutina en C++ (0,03 a 0,3 s). La búsqueda voraz no ayuda con esta heurística; una heurística que mida el trabajo de acomodar los bloques (no sólo la subida) y descartar estados muertos sí cambiaría el panorama.
