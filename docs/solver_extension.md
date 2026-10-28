# El solucionador como extensión de Godot

El solucionador A* exacto de las salas (`native/salas.cpp`) existe de dos formas, con la misma respuesta:

| Forma | Qué es | Para qué se usa |
|---|---|---|
| **Extensión de Godot** (`SolverNativo`) | Una biblioteca (`extension/bin/libsolver.windows.template_*.x86_64.dll`) que carga el juego (`extension/solver.gdextension`). Se llama directo, sin lanzar un proceso. | Lo que viaja con el juego: **El camino corto** (movimientos en falso, `torre/falsos.gd`) y el **modo pista** de Fácil (`torre_juego.gd`). |
| **Ejecutable** (`tools/salas.exe`) | El programa de línea de comandos (`native\construir.bat`). | Las herramientas de desarrollo: el generador de salas, el Estudio, `refinar_biblioteca.gd`, `variantes_gato.py`. Y es el respaldo de `resolver` si no está la extensión. |

`torre/nativo.gd` es el puente: `Nat.resolver(motor, tope)` usa la extensión si está cargada (`Nat.extension()`) y, si no, el ejecutable (`Nat.disponible()` dice si hay alguna de las dos). Si no hay ninguna, la pista usa el solucionador de GDScript (unas 90 veces más lento, con un tope de 20.000 estados) y El camino corto no castiga (ver más abajo).

## Qué hay

- `native/salas.cpp`: el solucionador de siempre. `resolver_texto(istream&)` es lo que antes hacía `resolver_main()` (lee una sala en el formato de texto de `nativo.gd` y devuelve las líneas `RESULT` y `PATH`); el `main` queda fuera si se define `SALAS_BIBLIOTECA`.
- `native/extension/`: la extensión. `src/salas_biblioteca.cpp` incluye `salas.cpp` como biblioteca (arma las tablas una sola vez y atrapa los errores de memoria), `src/solver_nativo.cpp` es la clase `SolverNativo` (un método, `resolver_texto(sala: String) -> String`) y `src/register_types.cpp` la registra. `SConstruct` la arma con [godot-cpp](https://github.com/godotengine/godot-cpp).
- `extension/solver.gdextension`: le dice a Godot qué biblioteca cargar en cada plataforma (hoy, Windows de 64 bits).
- `native/construir_extension.bat`: arma la de debug (el editor y las partidas de desarrollo) y la de release (la exportación). Hace falta g++ de MSYS2, Python con SCons (`pip install scons`) y git; la primera vez baja godot-cpp a `native/godot-cpp` (no se versiona, igual que `extension/bin/` y `tools/*.exe`). Se arma con `api_version` 4.7, la de este Godot (4.7.2).
- Prueba: `tests/unitarios/test_solver_extension.gd` (la misma respuesta que `salas.exe` en salas de los cuatro niveles, la solución se juega y gana, y no es más lenta que el ejecutable; si la extensión no está armada, no prueba nada).

## Cargarla

Godot carga las extensiones que figuran en `.godot/extension_list.cfg`, que se genera al abrir el editor o con `godot --headless --path . --import`; en un clon nuevo hay que hacer una de las dos cosas una vez después de armar la biblioteca (si no, `Nat.extension()` es falso y el juego usa el ejecutable).

## Rendimiento

El cálculo es el mismo código con `-O3`, así que rinde igual; la extensión se ahorra lo que cuesta cada llamada del ejecutable (escribir un archivo temporal, lanzar `cmd` y el programa, leer la salida), que pesa en **El camino corto**, que mide después de cada movimiento.

## Exportar

La extensión se incluye sola en la exportación (el `.gdextension` es parte del proyecto); la exportación sigue excluyendo `tools/*`, así que el juego exportado ya no necesita `salas.exe` para El camino corto ni para la pista. Hay que armar antes la biblioteca **release** (`construir_extension.bat` arma las dos).

## Otras plataformas (todavía no)

Con la misma extensión se puede llegar a Linux, macOS, Android (arm64; con el NDK) y, con más cuidado, la web: hay que agregar su línea en `solver.gdextension`, armar la biblioteca en una máquina con ese compilador (`scons platform=linux|macos|android ...`) y, en celulares, bajar los topes de estados (`falsos.gd`, `torre_juego.gd`) por la memoria. Solo se usa la biblioteca estándar de C++ (nada de Windows), así que el código no cambia. `nativo.gd` ya no depende de `cmd` para `resolver`; el resto de sus funciones (`minimo`, `medir`, `conocido`) siguen siendo del ejecutable y solo para desarrollo.
