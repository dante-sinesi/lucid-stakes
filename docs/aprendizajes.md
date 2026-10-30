# Lo que se aprendió (y por qué lo viejo se borró)

El juego pasó por varias torres y generadores antes de llegar a la actual (`torre/`, ver `reglas_torre.md` y `generador.md`). Este documento guarda lo que sirve de esos experimentos; el código y los informes originales se borraron en la limpieza (están en el historial de git: etiqueta `antes-de-la-limpieza`).

## La torre vieja (núcleo sólido, piso y fila que cae)

- Torre en una cuadrícula con un núcleo 2x2 fijo y salas apiladas alrededor, con piso, y una fila de abajo que caía cada N movimientos. Los bloques solo se mueven en horizontal y la altura total se conserva: **subir exige transportar material hasta la escalera**. Ahí está la complejidad (en los puzzles de torres clásicos hay unos 15 movimientos de bloque por cada 3 filas).
- Generadores que existieron: por situaciones (`rooms.gd`), por módulos (trampolín, pinchos con colgada, hielo, transporte), por pasos (salas libres), minero 24/7 con empaquetador y Estudio, y una biblioteca de salas viajando con el juego. Se retiraron cuando la torre nueva demostró ser mejor en dificultad, rapidez (generar una torre es instantáneo) y variedad.
- También se archivaron el experimento del **cilindro** (torre circular) y el escenario **Glaciar** (piso y bloques de hielo): no lograron una complejidad buena.

## Qué hace difícil a una sala (lo que sí funcionó)

- **Medir con el solucionador completo.** La distancia reversible por BFS sobreestima (hay atajos irreversibles) y las estimaciones cortas engañan. La métrica que importa es la de **bloques distintos movidos**, no la de movimientos ni la de agarres.
- Las salas con una sola técnica se resuelven moviendo 1 o 2 bloques; cambiar bloques al azar no pasa de 4 a 6 empujes aunque el solucionador sea cien veces más rápido.
- **Construir hacia atrás y escalar.** Armar una sala ya resuelta, desordenarla con contra-movimientos reales (cada paso comprobado con las reglas del juego) y mejorarla con escalada local sobre el valor exacto (`pasos + 3·agarres + w·bloques distintos`) es lo que funciona hoy. Sin la escalada las salas salen fáciles: el solucionador encuentra atajos (demasiado material).
- **Excavar** (generadores de "estados más lejanos" de Rush Hour y Sokoban): mirar el grafo de estados alrededor del camino de una sala y quedarse con la disposición más lejana, verificada con el A* exacto. Dio salas de 13 agarres en 33 pasos con solo 4 bloques sueltos. El grafo explorado sobrestima (hay atajos fuera de lo explorado), así que toda candidata se verifica con el solucionador exacto.
- **Un especial es un verbo, no una cantidad.** Pesado limita, pinchos prohíben celdas, agrietado obliga a decidir (se pisa una vez), hielo resbala y transporta, trampolín salta, bomba apura. Cada uno se coloca donde le rompe el paso más barato a la solución y se acepta solo si pasa la prueba de necesidad (volverlo común cambia el resultado).
- **Las bombas llevan la mecha mínima que obliga a usarlas** (bisección sobre la cuenta).

## Callejones sin salida (no repetir)

- **Búsqueda voraz** (A* con heurística pesada): no resuelve las salas "en el límite" porque hay que empujar antes de subir y la voraz se va a trepar.
- **Rampa de escalones sueltos como punto de partida del desorden:** una rampa suelta es frágil (mover un escalón tira los de arriba y una caída no se deshace) y un bloque sin columna no puede viajar lejos. El aire y el transporte lejano no se tienen a la vez con ese método.
- **Cadenas de movimientos con terreno a medida:** generan terrenos resolubles, pero casi todas tienen un atajo más corto que la cadena plantada (89 a 98 %) y la tasa de éxito baja con el tamaño de la arena (6,4 % a 1,2 %). La dificultad la pone el filtro del solucionador, no la cadena.
- **Una condición necesaria barata** ("para subir h pisos hacen falta h - L bloques sueltos en cada nivel L") es correcta pero casi no filtra.
- **Heurística:** el techo del A* admisible son unos 25 a 30 pasos con muchos bloques (crece unas 1,6 veces por paso). Las salas altas se resuelven por lonjas de 3 pisos (válidas, no necesariamente las más cortas) y su mínimo se certifica aparte con la cota superior del camino conocido.

## El solucionador nativo

- Port exacto a C++ (400 mil estados por segundo contra 3 mil de GDScript), hoy dentro de `native/salas.cpp`. La fidelidad se comprobó acción por acción y con los mismos estados generados sobre cientos de salas.
- Lo que más ahorró: un único estado de trabajo con deshacer (en lugar de copiar la grilla), la lista de celdas ocupadas en vez de recorrer toda la grilla y el hash de Zobrist.
- **Causa de los trabes en torres altas:** el solucionador nativo tenía una grilla de 44 capas y por encima fallaba sin avisar. Si algún día hay torres más altas, hay que subir el tamaño de la grilla.
- El tope de generación es de **trabajo** (contadores de estados), no de tiempo: así la misma semilla da siempre la misma torre.

## Calibrar el balance

- Hace falta un jugador real: el bot juega casi perfecto, así que los números salen optimistas. Ver `economia.md`.
- La dificultad de una torre se juzga mirando el juego (capturas, jugarla con el solucionador) y no solo con métricas.

## Costos de trabajo

- Los comandos largos con texto en español y comillas se rompen en el shell: escribir los parches con la herramienta de escritura y correrlos. `pkill` no mata procesos de Godot en Windows (`taskkill //F //IM`); los procesos viejos le quitan CPU a todo.
- Las esperas bloqueantes no se dejan en segundo plano cortando el turno.
