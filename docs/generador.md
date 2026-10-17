# Generador nativo de salas (versión final)

Un solo programa en C++ (`native/generador.cpp` → `tools/generador.exe`, se arma con `native\construir.bat`) hace todo el trabajo de buscar salas, sin GDScript en el camino:
escalera → excavar (grafo de estados) → solución exacta (A\*, camino más corto con menos agarres) → comprobación de que no se resuelve caminando → auditoría de especiales
(un especial sólo queda si al cambiarlo por comunes cambia el camino óptimo) → paso de tipos (inserta hielo, pinchos, bombas, catapultas, trampas, agrietados guiado por el camino)
→ paso de mutación. Guarda élites por celda (forma, altura) y prefiere las que llegan alto (`reach` ≥ 0.5).

Las reglas de los bloques y los movimientos están cerradas: el generador usa el mismo motor que `solver_nativo.cpp` (todos los tipos, bombas con zona esférica de radio² 5).
Las bombas tienen la mecha mínima que obliga a usarlas (bisección) y `RoomLib.tune_fuse` hace lo mismo del lado de GDScript.

## Flujo de un comando

```
herramientas\generador.bat            :: mina (varias partes en paralelo) y cierra
```

1. `tools\generador.exe mina --out=bibliotecas\generador\gen_X_N.txt --steps=N --shapes=3x3,3x5,3x8,L,U --hlo=5 --hhi=10 --seed=S --part=P --parts=K --nodes=500000 --eval=16`
   (determinista por semilla y parte; los topes son de trabajo, no de tiempo).
2. Cierre: `Godot --headless --path . res://scenes/generador.tscn -- --in=bibliotecas/generador --old=bibliotecas/minero --lib=data/salas.rooms --out=data/salas.rooms --min-reach=0.5`
   (`scripts/generador_main.gd`): vuelve a comprobar cada sala con las reglas reales del juego (estructura, repetir el camino, hashes), mezcla con la biblioteca que ya había
   (deja `.bak`) y audita nativamente las salas del minero viejo.
3. `tools\generador.exe auditar --in=... --out=... --min-reach=0.5` audita salas existentes.

Formato de línea: `R|forma|h|mecha|pasos|agarres|reach|especiales|camino|x,z:col;...|origen`.

## Pruebas

`tests/test_generador.gd`: el generador es determinista, todo lo que saca pasa las reglas del juego, la auditoría nativa coincide con la de GDScript y el cierre escribe una biblioteca legible.
