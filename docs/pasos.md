# Pasos (15/10)

Un **paso** es una pieza chica de sala que se diseña aparte, se resuelve sola con el solucionador exacto y, más adelante, el generador la va a poder meter en salas. Ejemplos: una fila de pinchos que hay que cruzar colgado del borde, un camino de hielo que se patina. Código: `scripts/step_lib.gd` (formato, armado, solución, medición), `scripts/step_studio.gd` + `scenes/step_studio.tscn` (la interfaz). Tests: `tests/test_step_lib.gd`, `tests/test_step_studio.gd`.

## Cómo se usa

- Desde el Estudio de salas: botón **Diseñar pasos…**. O `herramientas\pasos.bat [archivo.jsonl]` (por defecto `pasos\pasos.jsonl`; si no existe se muestran dos ejemplos). Los pasos se guardan en un `.jsonl` con **Guardar**. "Volver al Estudio de salas" vuelve.
- **Ventana**: largo (x), ancho (z) y alto del paso. El piso es fijo; el jugador empieza parado en la **entrada** y tiene que quedar parado en la **salida** (una plataforma fija con aro magenta).
- **Herramientas** (botón izquierdo): agregar un bloque pegado a la cara que tocás (se puede en el aire), borrar, cambiar tipo (común, hielo, agrietado, catapulta, trampa, pinchos, bomba, pesado), mover la entrada, mover la salida, **pozo** en el piso (alternar una celda del piso: se cruza colgado o saltando) y **tramo repetible**. Botón derecho: girar la cámara; rueda: acercar; botón del medio: mover. Ctrl+Z / Ctrl+Y deshacen y rehacen, Ctrl+S guarda, Tab muestra solo el paso (hay botones para ver "desde atrás del personaje" y en diagonal).
- **Tramo repetible**: marcás unas columnas (dos clics en el piso, o las cajas "columnas desde / hasta" con el eje x o z) y el rango de repeticiones ("se repite de 1 a 5 veces"). El paso diseñado tiene el tramo una vez; con r repeticiones se copian esas columnas r veces y todo lo de más allá (la salida, por ejemplo) se corre. Las puertas no pueden estar dentro del tramo. **Ver con N repeticiones** muestra cualquier largo (con otro que no sea 1 no se edita).
- **Resolver este largo**: el camino más corto demostrado (A* exacto, entre los más cortos el de menos empujes), que se reproduce con la barra y los botones, y lo que hace: pasos, empujes/tirones, colgadas, patinazos, saltos de catapulta, y qué tipos de bloque son **necesarios** (si cambiar ese tipo por común no cambia el camino más corto, dice "de adorno").
- **Probar todos los largos**: resuelve cada largo del rango por separado y muestra una línea por largo (✓ con sus números, o ✗ con el motivo: sin solución, o más de 400 mil estados sin resolver). El resultado queda en la lista de la izquierda (`[5/5 ✓]`).

## Los dos ejemplos

- **Fila de pinchos (colgarse)**: una cornisa de bloques con una columna de pinchos y un pozo al lado. Pisar los pinchos es perder, así que la solución es colgarse del borde antes de los pinchos, avanzar por debajo y trepar del otro lado. Con 1 a 5 pinchos seguidos se resuelve en 7 a 11 pasos.
- **Camino de hielo**: bloques de hielo hasta una plataforma; se patina todo el camino de una vez.

## Lo que falta

- El **generador** todavía no usa los pasos: la idea es colocarlos en una sala (girados, espejados, con un largo del rango) conectando la salida de uno con la entrada del siguiente y verificar la sala entera. Para que la dificultad total sea la suma de las de cada paso conviene que cada paso tenga su zona propia (sin compartir bloques).
- Los pasos se resuelven aislados (ventana con piso fijo); dentro de una sala el entorno cambia lo que se puede hacer, por eso la sala completa se vuelve a verificar.
- Reglas del juego que importan al diseñar: colgado, no se avanza por el borde si hay un bloque encima del bloque del que te agarrás (los pinchos sobre la cornisa lo impiden); estando colgado los pinchos no hacen daño.
