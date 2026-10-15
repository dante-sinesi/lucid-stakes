# Experimento: escalones sueltos (14/10)

Script: `tests/exp_escalones.gd` (variables N, SEED, CONFIGS, GRABS, EXACT_H). No toca el formato de la biblioteca ni el minero.

## Qué se probó
Una sala sin columnas: una **rampa de h - 1 bloques sueltos**, uno por piso, cada uno un piso más arriba y pegado al anterior, que el motor sostiene por apoyo de arista (comprobado: nada se cae y se sube caminando; para 10 pisos son 9 bloques en lugar de unos 45 con columnas). Se la **desordena con movimientos reales y reversibles** (empujar, tirar, caminar; prefiriendo empujar) hasta que no se pueda subir caminando; la solución es el desorden al revés, verificada repitiéndola, y después se le sacan las vueltas.

## Resultados (12 intentos por configuración, desorden de hasta 400 acciones)

| Forma y pisos | Bloques | Salas válidas | Empujes y tirones (media / máx) | Pasos | Dificultad (media / máx) |
|---|---|---|---|---|---|
| 3x8, 6 pisos | 5 | 10 de 12 | 1,0 / 1 | 12 | 8 % / 8 % |
| 3x8, 10 pisos | 9 | 2 de 12 (y 3 de 8 en otra corrida) | 2,0 / 3 | 20 | 9 % / 13 % |
| L, 12 pisos | 11 | 0 de 12 (0 de 8) | 0 | – | – |
| U, 14 pisos | 13 | 0 de 12 | 0 | – | – |

En las 4 salas chicas verificadas con el solucionador exacto, el camino plantado ya era el mínimo (1 empuje de 12 pasos). Las rampas altas ni siquiera llegan a quedar "sin poder subirse caminando": los intentos fallidos hicieron entre 2 y 12 empujes reversibles en 400 acciones, pero todos inofensivos.

## Por qué no funciona
1. **Una rampa de bloques sueltos es frágil.** Mover un escalón le saca el apoyo a los de arriba (que caen) o lo deja sin apoyo a él mismo: una caída **no se puede deshacer**. El desorden por movimientos reversibles sólo puede tocar lo que no importa.
2. **Un bloque sin columna no puede viajar lejos.** Para trasladarse sin caer necesita apoyo en cada celda (otra columna, o un vecino a su nivel o un nivel más abajo). Un camino de apoyo a nivel k es masa. La dificultad de Catherine (transportar material lejos) y la poca masa se oponen.

## Conclusión
Con este método **el aire y el transporte lejano no se pueden tener a la vez**: la rampa suelta no se puede dispersar reversiblemente, así que no sirve para plantar soluciones. Quedan descartadas las salas de escalones sueltos *como punto de partida del desorden*. Siguen abiertos: (a) cadenas de movimientos con terreno decidido a medida (ver `experimento_cadenas.md`) en arenas grandes (L, U, 3x8), donde cada empuje es necesario por construcción; (b) un solucionador más potente (C++) para que la evolución llegue a salas de muchos empujes; (c) terreno fijo que haga de camino de apoyo.
