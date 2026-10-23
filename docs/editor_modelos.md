# Editor de modelos (cubos, cosméticos y personajes)

Herramienta de desarrollo, como el Estudio de salas, pero para el arte del juego. La usa Dante para hacer los diseños; después se integran al juego. No es para jugadores: no está en el menú ni se exporta con el juego.

- Abrir: `herramientas\editor_modelos.bat` (o `godot --path . res://scenes/model_editor.tscn`).
- Los modelos viven en `data/modelos/*.jsonl` (versionados: es arte del juego). Formato y lectura: `scripts/personajes/model_lib.gd`. Lógica del editor: `scripts/herramientas/model_editor_model.gd`. Pantalla: `scripts/herramientas/model_editor.gd`.
- Pruebas: `tests/unitarios/test_modelos.gd` (variantes, formato, lógica, importar, reemplazo) y `tests/unitarios/test_editor_modelos.gd` (la pantalla).

## Qué se puede hacer
- **Bloques con variantes**: cada tipo de bloque (normal, hielo, bomba, catapulta, agrietado, pesado, trampa, pinchos y núcleo) tiene 4 diseños automáticos (`BlockModels.VARIANTS`; el 0 es el de siempre) y puede tener más hechos con el editor. Cada bloque de la torre usa uno según su identidad (`BlockModels.variant_for(id, semilla, tipo)`): estable dentro de una torre y distinto de una torre a otra. Es sólo visual; la cara de arriba se lee igual en todas (los bloques se verifican: centro de arriba completo salvo bomba y pinchos). El estado corrupto se deriva solo del modelo completo (`BlockModels.state_view`); la bomba desactivada tiene su propio modelo (o se grisea el normal).
- **Cosméticos** (gorros y prendas) y **personajes**: minibloques de 0,04 en una caja de 24×32×24 con el origen en los pies. Un modelo con el id de uno que ya existe **reemplaza** su diseño de código; los personajes conservan las partes que giran al caminar (`pata_i`, `pata_d`, `brazo_i`, `brazo_d`, `cola`) con su pivote. Para agregar un cosmético o personaje **nuevo** al juego hay que registrarlo en `Cosmetics.ALL` / `Characters.ALL` (eso lo hace Claude cuando Dante lo pide).
- **Importar del código**: pasa los diseños actuales (bloques y sus variantes, personajes, cosméticos) al formato del editor para retocarlos (cada caja se voxeliza).

## Cómo se usa
- Izquierda: lista de modelos con filtro; Nuevo / Duplicar / Borrar; Importar del código; Guardar todo.
- Centro: Poner (en la cara que se toca, como en Minecraft), Sacar, Cuentagotas, Rellenar capa, Simetría X/Z, Deshacer/Rehacer (Ctrl+Z / Ctrl+Y), Guardar (Ctrl+S); capa visible (Q/E); bloques: ver el modelo corrupto, purificado o desactivado; cosméticos: se ven sobre el personaje de referencia. Mouse: derecho gira, medio mueve, rueda acerca.
- Derecha: id, nombre, tipo/variante/estado (bloques), hueco y rareza (cosméticos), partes y pivotes (personajes), tamaño de la caja, paleta (cambiar un color cambia todos los minibloques que lo usan), espejar/mover la parte y **verificación** (cara de arriba, partes y pivotes completos, cantidad de minibloques).
- Guardar escribe en `data/modelos/bloques.jsonl`, `cosmeticos.jsonl` o `personajes.jsonl`; no deja guardar lo que no pasa la verificación.
