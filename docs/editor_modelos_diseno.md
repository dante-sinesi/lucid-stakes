# Editor de modelos 2.0: diseño (brainstorming con Dante)

Estado: **diseño acordado, sin programar**. Reemplaza al editor actual (`scripts/herramientas/model_editor*.gd`, tres columnas fijas y botones de texto). Sigue siendo una herramienta de desarrollo (no va en el juego exportado). El formato de datos (`data/modelos/*.jsonl`, `model_lib.gd`) se amplía y migra: los modelos actuales tienen que seguir abriéndose.

## Decisiones tomadas
- **Organización:** paneles acoplables en **zonas fijas con pestañas** (izquierda, derecha, abajo y centro). Los paneles se agrupan en pestañas, se mueven entre zonas arrastrando su título, se colapsan y se redimensionan, y el diseño se guarda.
- **Estilo:** oscuro profesional (estilo AutoCAD/Blender), íconos vectoriales nítidos, tipografía legible, pensado para trabajar horas.
- **Interfaz:** menú superior (Archivo / Editar / Ver / Modelo / Herramientas / Ayuda), **barra de herramientas con íconos** a un lado, **barra de opciones** contextual bajo el menú (opciones de la herramienta activa) y **panel de propiedades** que cambia según lo elegido (herramienta, modelo, parte, selección, animación). Sin línea de comandos por ahora.
- **Área 3D:** vista 3D grande y **minivistas ortogonales** (Frente, Lado, Arriba) a un costado; se puede dibujar en cualquiera.
- **Herramientas:** dibujo básico (poner, sacar, cuentagotas, pincel de tamaño ajustable, rellenar, borrador); formas y selección (línea, rectángulo, caja, esfera, cilindro; selección por región o por color; mover, rotar, escalar, copiar y pegar lo seleccionado); transformación y simetría (espejar por ejes, rotar 90°, desplazar, simetría en vivo con plano visible); medir y verificar (regla, contador de minibloques, resaltado de caras que fallan la verificación, comparación lado a lado).
- **Estructura de un modelo:** **árbol de partes con capas** (cuerpo > brazo > mano), con visibilidad, bloqueo y pivote por parte y capas de minibloques dentro de cada parte. Es la base de la animación.
- **Animación:** **poses clave y ciclos con línea de tiempo** (rotación y posición por parte, interpolación, prueba en bucle). El juego usa esos ciclos (caminar, empujar, colgarse, caer...).
- **Biblioteca:** miniaturas, búsqueda y etiquetas; **historial de versiones** por modelo; **paletas guardadas y plantillas** de inicio (gorro, prenda, bloque, personaje).
- **Vista previa en el juego:** ver el modelo con la luz y la cámara reales de la torre y el casino, según la etapa.
- **Registro:** el editor **genera** el modelo y su ficha; yo lo registro en el código (`Cosmetics.ALL`, `Characters.ALL`) cuando Dante lo pide, como hoy.
- **Fuera de alcance por ahora:** línea de comandos, importar y exportar .vox/.obj, imagen de referencia, libertad total de acople.

## Distribución
```
┌──────────────────────────────────────────────────────────────────────────┐
│ Archivo  Editar  Ver  Modelo  Herramientas  Ayuda                        │
├──────────────────────────────────────────────────────────────────────────┤
│ [Barra de opciones: herramienta activa, tamaño, forma, relleno, simetría]│
├────┬──────────────────────────────────────────────────┬──────────────────┤
│ ▢  │                                                  │ Propiedades      │
│ ✎  │              Vista 3D (grande)                   │  (según lo que   │
│ ⌫  │                                      ┌─────────┐ │   esté elegido)  │
│ ◧  │                                      │ Frente  │ ├──────────────────┤
│ ○  │                                      ├─────────┤ │ Partes y capas   │
│ ⬚  │                                      │ Lado    │ │ (árbol)          │
│ ⇄  │                                      ├─────────┤ ├──────────────────┤
│ ⟲  │                                      │ Arriba  │ │ Paleta / Modelos │
│ 📏 │                                      └─────────┘ │ (pestañas)       │
├────┴──────────────────────────────────────────────────┴──────────────────┤
│ Línea de tiempo / Verificación / Historial (pestañas)                    │
├──────────────────────────────────────────────────────────────────────────┤
│ Barra de estado: herramienta, celda bajo el cursor, minibloques, aviso   │
└──────────────────────────────────────────────────────────────────────────┘
```

## Paneles
1. **Modelos** (biblioteca): lista con miniaturas, filtro por tipo (bloque, cosmético, personaje), búsqueda, etiquetas; Nuevo (desde plantilla) / Duplicar / Borrar / Importar del código.
2. **Partes y capas:** árbol del modelo, visibilidad, bloqueo, pivote; capas dentro de cada parte.
3. **Propiedades:** ficha del modelo (id, nombre, tipo, rareza, hueco), parte elegida (pivote, posición, rotación), selección (tamaño, posición), herramienta.
4. **Paleta:** colores del modelo y paletas guardadas con nombre; cambiar un color cambia todos los minibloques que lo usan (como hoy).
5. **Verificación:** las reglas actuales (cara de arriba completa, partes y pivotes, cantidad de minibloques) con lista de problemas y salto a la celda.
6. **Historial:** versiones por modelo con vista previa y restauración, además de deshacer y rehacer.
7. **Línea de tiempo:** poses y ciclos, reproducir en bucle, velocidad.
8. **Vista previa del juego:** el modelo con la iluminación real y la etapa elegida.

## Fases (de a una, en su propia rama, con pruebas y capturas)
1. **Marco:** zonas con pestañas, tema oscuro, menú, barra de herramientas con íconos, barra de opciones, barra de estado y diseño guardado. Se migran los paneles actuales sin perder funciones.
2. **Herramientas:** dibujo, formas, selección y transformación, medir y verificar.
3. **Árbol de partes y capas:** nuevo formato de modelo con migración de los actuales.
4. **Minivistas ortogonales** y cubo de orientación.
5. **Biblioteca:** miniaturas, búsqueda, etiquetas, plantillas, paletas guardadas e historial de versiones.
6. **Animación:** poses clave, ciclos y línea de tiempo, y que el juego los use.
7. **Vista previa en el juego.**

## Riesgos y cosas a decidir más adelante
- Los íconos: hay que dibujarlos (SVG propios o dibujados por código); decidir el set al empezar la fase 1.
- Migrar el formato de modelos sin romper lo que ya existe; las animaciones cambian cómo el juego mueve personajes (hoy: balanceo paramétrico de patas y brazos).
- El sistema de acople propio en Godot es la parte más delicada de la fase 1.
