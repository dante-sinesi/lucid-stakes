# La fuente para la web

La fuente de cubitos del juego (`scripts/ui/voxel_font.gd`: grillas de 5 x 7 celdas, con acentos y colas) como fuente de verdad para una página web.

- **Generarla:** `python herramientas/generar_fuente_web.py` (hace falta `pip install fonttools brotli skia-pathops`). Corre Godot para volcar las celdas de cada carácter (`herramientas/exportar_glifos.gd`) y arma los contornos. Deja todo en `web_fuente/`: `fonts/` (`.ttf` y `.woff2`), `lucid-stakes.css` (los `@font-face`) y `demo.html`. Cuando se agregue un glifo al juego, se vuelve a correr.
- **Pesos y cursiva:** 200 (cubitos chicos y separados), 400 (cubitos con una rendija, como en el juego) y 700 (cubitos que se juntan en trazos sólidos); cada uno en redonda y en cursiva (la grilla inclinada 12 grados). Seis archivos en total, una sola familia: `font-family: 'Lucid Stakes'` con `font-weight: 200 | 400 | 700` y `font-style: italic`.
- **Uso:** copiar `fonts/` y `lucid-stakes.css` a la web, enlazar el `.css` y usar la clase `.lucid` (texto) o `.lucid-titulo` (el título dorado con la sombra dura). Se ve más nítida en tamaños múltiplos de 11 px.
- **Lo que no pasa a la fuente:** el relieve y la sombra de cada cubito. La clase `.lucid-titulo` imita la sombra y el brillo con CSS.
- La carpeta `web_fuente/` no viaja con el juego (está en el filtro de exclusión de la exportación).
