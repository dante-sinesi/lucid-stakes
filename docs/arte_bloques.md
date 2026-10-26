# Arte de los bloques (10 x 10 x 10 minibloques)

Código: `scripts/personajes/block_art.gd`. Los bloques de siempre (`block_models.gd`) son de 5 x 5 x 5; el arte nuevo se va haciendo tipo por tipo. Hoy están la **piedra común** (`n`), la **trampa** (`t`: piedra gris azulada que se desvanece de arriba hacia abajo: la cara de arriba es opaca y hacia la base se vuelve translúcida y con huecos, como si se desvaneciera; lleva una X de juntas en cada costado; se dibuja en dos mallas como el hielo), el **agrietado** (`c`, arenisca: arena cálida con fisuras hondas al azar (de cuatro a seis por cara, cortas o largas, casi todas en diagonal, de uno a tres minibloques de profundidad, algunas anchas) que se ven siempre; marrón tierra con magma cuando está corrupto), el **hielo** (`i`: una fusión en manchas de hielo escarchado (opaco, blanquecino y granuloso) y hielo claro (translúcido: la opacidad de cada minibloque viaja en UV.x y `voxel_hielo.gdshader` la usa; se ve el canto de atrás), con franja de reflejo y destellos, azul verdoso oscuro cuando está corrupto) y el **bloque pesado** (`h`, hierro: acero azulado, marco oscuro en las aristas, esquinas y remaches dorados por los bordes y cuatro tornillos arriba; el corrupto es azul oscuro, no negro, para no confundirse con la piedra; no se desgasta), que se dibujan con el arte nuevo en la torre del juego (`Vista.poblar` con `aspecto_juego`); el resto de los tipos y el Estudio de salas siguen con el arte viejo.

## Diseño
- La **corrupción son las grietas con magma violeta** y la piedra oscura y desgastada. Hay una sola escala de corrupción (`BlockArt.corrupcion`, de 0 limpio a 1 muy corrupto) para los dos estados: el corrupto de la última etapa parece el purificado de la primera.
- Cinco niveles, **uno cada tres etapas** (como las pruebas; `BlockArt.nivel_de_etapa`). Constantes `CORRUPCION_CORRUPTO` = 1,0 / 0,83 / 0,70 / 0,60 / 0,50 y `CORRUPCION_PURIFICADO` = 0,50 / 0,33 / 0,20 / 0,10 / 0,0 (pasos parejos; el purificado baja más rápido al principio).
- A más corrupción: la piedra pasa de lavanda a obsidiana (rampa lineal entre 0,5 y 1), la forma se desgasta (esquinas, aristas y mordiscos), y las grietas se hunden y se llenan de magma que brilla. A menos: las grietas se cortan en tramos, se apagan y se cicatrizan, y la piedra se aclara y alisa.
- Las grietas son las mismas para una semilla en cualquier nivel (un bloque que se limpia conserva sus grietas). Cada bloque de la torre usa una de 8 semillas según su celda (`Vista.VARIANTES_ARTE`).
- El centro de la cara de arriba (8 x 8) queda siempre completo y plano: es lo que se pisa.
- Los minibloques que brillan llevan el alfa menor que 1 en el color del vértice; `voxel_block.gdshader` lo usa como emisión (`COLOR.rgb * (1 - COLOR.a)`).

## Ver los bloques
`herramientas\galeria_bloques.bat` abre la galería (`scenes/galeria_bloques.tscn`): cada tipo con arte nuevo, corrupto y purificado, en los cinco niveles, con la luz y el fondo del juego. Mouse: arrastrar gira e inclina, rueda acerca; Q/E giran 45°; 1 a 5 ponen el fondo de esa etapa; F apaga el remolino; R vuelve la cámara. Los tipos nuevos se suman a `TIPOS` en `scripts/herramientas/galeria_bloques.gd`.

## Cómo seguir con otros bloques
Cada tipo necesita su versión corrupta y su versión purificada sobre la misma escala. Se agregan a `block_art.gd` (o a un módulo hermano) y se enganchan en `Vista.poblar`. Capturas de revisión: `tests/capturas/shot_bloque.gd` (`niveles` muestra las cinco etapas lado a lado). Pruebas: `tests/unitarios/test_block_art.gd`.

## Pinchos (`pinchos`)

Una base de acero oscuro de seis minibloques de alto (`TOPE_PINCHOS`) con cinco púas encima (cuatro en las esquinas y una en el centro; 2x2 en la base, 2x2 en el medio y un minibloque de punta, hasta el piso 8). Limpios: púas plateadas con la punta casi blanca. Corruptos: base casi negra, púas de obsidiana y puntas de magma que brillan. Las púas no se agrietan; las grietas y el magma van en la base. Se usa en la torre con la letra `s`.
