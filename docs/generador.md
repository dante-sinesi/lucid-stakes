# El generador de salas

Las salas se buscan con `native/salas.cpp` (se arma con `native\construir.bat` → `tools/salas.exe`, g++ de MSYS2; el .exe no se versiona). El motor de reglas vive en tres lugares que deben coincidir: `torre/motor.gd` + `torre/reglas.gd` (GDScript, el del juego), `torre/solucionador.gd` (A* de referencia en GDScript) y el propio `native/salas.cpp`. Pruebas: `torre/test_especiales.gd`, `tests/unitarios/test_paquete_salas.gd` y `test_nativo*.gd`.

## Cómo se genera una sala (`salas.exe --gen`)

1. **Sala resuelta:** una escalera de un bloque por piso dentro de la huella (3x3, 5x3 u 8x3 del anillo de 11x11), con el bloque de entrada (nivel 1) y el de salida (nivel h) como checkpoints, un bloque fijo pegado a la salida y `extras` bloques más (~1,3 por piso en 3x3, ~2,3 en 5x3 y 8x3). El jugador parado sobre la salida.
2. **Contra-movimientos con haz:** cada paso hacia atrás es un estado desde el cual UNA acción del motor lleva al actual (se comprueba simulando), así que se resuelve por construcción. El haz se guía con la distancia exacta del solucionador.
3. **Variante con el jugador sobre el bloque de entrada** (el estado con el que se arrancaría), resuelta con el solucionador exacto.
4. **Escalada local:** mover, agregar o sacar un bloque; se acepta si la sala sigue resolviéndose y el valor (pasos + 3·agarres + `wd`·bloques distintos movidos) no baja. Sin esta escalada las salas salen fáciles.

Hasta 9 pisos el solucionador es exacto; más alto se usan lonjas de 3 pisos (válidas, no necesariamente las más cortas) y el mínimo real se calcula después (`--minimo`, `torre/refinar_biblioteca.gd`).

## Bloques especiales por propósito (`--especializar`)

Un especial no se agrega por cantidad: cambia cómo se juega la sala. Cada rol se coloca donde le rompe el paso más barato a la solución, se vuelve a resolver con el solucionador exacto y se acepta sólo si cumple su papel. Al final cada especial pasa la **prueba de necesidad**: volverlo común cambia el resultado (el largo, el valor, o cuánto pesa cada decisión).

| Rol | Papel |
|---|---|
| Pesado | limita: no se puede mover |
| Pinchos | celdas prohibidas |
| Agrietado | cada decisión pesa (se pisa una vez) |
| Hielo | resbalar, pero también transporte |
| Trampolín (catapulta) | salto en vez de escalera (acorta mucho la sala) |
| Bomba | apura: la mecha baja con cada acción dentro de su zona; se busca por bisección la **mecha mínima con solución** (≥ 3) y que la solución pase al menos 3 movimientos dentro de la zona |

Las **salas mixtas** son una cadena de especializaciones sobre una sala base (cantidad por altura: 1 + (pisos − 3) // 9); `--revisar` comprueba que cada especial siga siendo necesario.

## Métrica de complejidad (`--medir`)

Se toma UN camino más corto exacto y, en cada estado, se prueban todos los movimientos legales resolviendo cada hijo con el solucionador exacto: `legales`, `optimos` (siguen un camino más corto) y `letales` (matan en el acto o dejan la sala sin solución).

- **bits de decisión** = Σ log2(legales / optimos); **bits de peligro** = Σ −log2(1 − letales / legales); **complejidad** = suma de ambos (pesos 1 y 1, provisorios).
- También se guardan pasos, agarres, **bloques distintos movidos** (la que importa), pasos críticos y los hijos sin resolver (si hay, la métrica es aproximada).
- Bandas de nivel: fácil < 60, media 60–110, difícil 110–180, pesadilla > 180 bits.
- Se calibró con salas reales: las 3x3 de 5 a 8 pisos dan 1,2 a 2,4 bloques distintos movidos por piso (los puzzles de torres clásicos piden ~1) y el riesgo medido (movimientos legales que matan o dejan sin solución) va del 10 al 25 %.

## Mínimo real de las salas altas (`--minimo ub=N tope=M`)

A* exacto con poda por la cota superior `ub` (el largo de un camino conocido). Si el tope de nodos alcanza, el resultado es el mínimo demostrado; si no, la salida trae `cota_inferior` (una cota inferior demostrada) y el mínimo queda entre las dos. Una 5x3 de 11 pisos pasó de 117 pasos (lonjas) a 103 exactos en 78 mil nodos. Hoy hay mínimo demostrado en todas las 3x3, las 5x3 hasta 8 pisos y las 8x3 hasta 9; las más altas tienen cota inferior y camino por lonjas.

## Producción

1. `python herramientas/generador_salas.py [--hasta HH:MM | --minutos N] [--procesos N] [--tipos 3x3,5x3,8x3] [--hmax N] [--nivel 1-5] [--base 45] [--roles hielo=60,bomba=40]`: genera sin parar salas base (niveles y tamaños en la proporción de siempre) y salas con especiales (los seis roles y mixtas de dos o tres), con varios procesos de `salas.exe` a la vez. Sin `--hasta` ni `--minutos` no tiene límite horario: se lo corta cerrando la ventana o creando `parar.txt` en la carpeta de salida (sirve cuando corre oculto: mata las salas en curso). Con `--tipos`, `--nivel`, `--hmax` y `--roles` se pueden pedir salas de un tipo (por ejemplo, más bombas o más hielo). Las salas quedan en `bibliotecas/generadas/` y el avance en `registro.txt` (resumen por categoría cada 10 minutos).
2. `herramientas/armar_portable.bat` arma `bibliotecas/generador_portable/` (`generador_salas.exe` sin Python, `salas.exe`, las bases del juego, `iniciar_generador.bat` y `parar_generador.bat`) para correrlo en otra computadora.
3. `python herramientas/sumar_salas.py carpeta [carpeta ...]` suma a `data/salas_torre.jsonl`, sin repetidas y sin cambiar los ids viejos, lo generado (con id, nivel por complejidad, pisos y marca de giro). `herramientas/revisar_forma_salas.py` comprueba la forma y `tests/unitarios/test_paquete_salas.gd` juega el camino de cada sala en el motor de GDScript (0 fallos). `data/salas_torre.jsonl` es la biblioteca que viaja con el juego. Para ver las salas con bombas en el Estudio: `herramientaser_salas_bomba.bat [arriba]`; todas las del juego: `herramientaser_salas_del_juego.bat`.

`bibliotecas/` no se versiona. El paquete vigente tiene 2855 salas de 4 a 23 pisos.

## Variantes del gatito travieso (`--variantes`)

La prueba "Travesuras" (`docs/gatito_travieso.md`) mueve de lugar unos bloques comunes de la sala al entrar. Para que el juego no dependa del solucionador compilado (no se puede llevar a otras plataformas), **los cambios seguros se calculan antes** y viajan en `data/variantes_gato.jsonl`: una línea por sala, `{"id", "variantes": [{"k", "mov": [[x, y, z, nx, nz], ...], "pasos", "agarres", "distintos", "camino"}]}`. `mov` son los bloques que mueve el gato, en orden (cada uno, una celda hacia una celda libre de la huella); `camino` es la solución de la sala ya cambiada en un texto compacto (una letra por acción: `'a' + modo * 4 + índice` de este, oeste, sur y norte).

- **Cuántos bloques mueve:** según los pisos: de 4 a 7, uno o dos; de 8 a 11, dos; de 12 a 15, tres; de 16 a 19, cuatro; de 20 en adelante, cinco.
- **Cómo se acepta una variante** (`tools/salas.exe --variantes tipo=3x3 [n=3] [intentos=30] [conocido=camino]`): solo bloques comunes; la sala queda apoyada y el jugador sigue sobre su checkpoint; **tiene solución**; **no se vuelve trivial** (si la original no se podía pasar sin mover bloques, la variante tampoco: se prueba resolviéndola con la acción de agarrar apagada; y la solución sigue moviendo al menos el 70 % de los bloques distintos de la original); el camino queda entre el 75 % y el 160 % del original; y **se nota**: el camino de la sala original (el del solucionador y el que trae la biblioteca) deja de servir.
- **Generarlas:** `python herramientas/variantes_gato.py [--procesos 7] [--n 3] [--minutos 8]`: es reanudable (no repite las salas que ya están en el archivo) y sin hora límite hasta terminar. Con la biblioteca de 2855 salas tarda unos 40 minutos y deja unas 7.600 variantes en 1,2 MB (el 93 % de las salas tiene al menos una; las que no, no cambian). Cuando se suman salas nuevas a la biblioteca, se vuelve a correr y calcula solo las nuevas.
- **Probarlas:** `tests/unitarios/test_variantes_gato.gd` aplica cada variante, comprueba el apoyo, juega su camino en el motor de GDScript (que coincide con el solucionador en las 7.641) y que se note.

## Estudio de salas

`herramientas\estudio_salas.bat [archivo.jsonl]` abre `torre/estudio.tscn`: lista de salas, reproducción desde atrás del jugador, edición, resolver con el nativo y guardar. `herramientas\torre_prototipo.bat [semilla] [salas]` abre una torre jugable aislada del juego. Capturas del Estudio: `tests/capturas/shot_estudio.gd` + `herramientas/montaje_salas.py` (siempre desde detrás del jugador).

## Pendiente

- Heurística admisible más fuerte (el techo del A* son unos 25 a 30 pasos con muchos bloques) para certificar las salas altas.
- Calibrar los pesos de la métrica y las bandas con salas jugadas por personas.
- Salas con trampa (todavía no hay) y más salas mixtas altas.
- Salas de la comunidad (Steam Workshop): pulir el Estudio hasta hacerlo fácil de usar y publicarlo como herramienta aparte.
