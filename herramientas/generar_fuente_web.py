"""Genera la fuente de cubitos del juego (scripts/ui/voxel_font.gd) como fuente de verdad para la web: .ttf y .woff2 en tres pesos (200, 400 y 700) y en redonda y cursiva, más un .css con los @font-face y una página de prueba.

Cada celda encendida de la grilla es un cuadrado de la fuente. El peso es qué tanto de la celda llena el cubito: 200 deja cubitos chicos y separados (liviana), 400 cubitos con una rendija entre sí (como en el juego) y 700 cubitos que se juntan en trazos sólidos (negrita).
La cursiva es la misma grilla inclinada 12 grados. Los glifos salen del propio juego: `herramientas/exportar_glifos.gd` vuelca las celdas de cada carácter (con sus acentos) y de ahí se arman los contornos.

Uso: python herramientas/generar_fuente_web.py [--salida web_fuente] [--glifos archivo.json]
Hace falta: pip install fonttools brotli skia-pathops (brotli para el .woff2 y skia-pathops para juntar los cubitos del peso 700).
Sin --glifos corre Godot (tools/Godot_v4.7.2-stable_win64_console.exe) para volcar las celdas."""
import argparse
import json
import math
import os
import subprocess
import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont
from fontTools.ttLib.removeOverlaps import removeOverlaps

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
FAMILIA = 'Lucid Stakes'
CELDA = 100                  # lado de una celda en unidades de la fuente (1000 por em)
LLENADO = {200: 0.58, 400: 0.82, 700: 1.0}   # qué fracción de la celda ocupa el cubito en cada peso
NOMBRE_PESO = {200: 'ExtraLight', 400: 'Regular', 700: 'Bold'}
INCLINACION = math.tan(math.radians(12.0))
ASCENDENTE = 900             # arriba de todo (los acentos)
DESCENDENTE = -200           # abajo de todo (las colas)


def cargar_glifos(ruta):
    if not os.path.exists(ruta):
        godot = os.path.join(RAIZ, 'tools', 'Godot_v4.7.2-stable_win64_console.exe')
        if not os.path.exists(godot):
            sys.exit('No está %s y no hay Godot en tools/ para volcarlos.' % ruta)
        env = dict(os.environ)
        env['GAME_SANDBOX'] = '1'
        subprocess.run([godot, '--headless', '--path', RAIZ, '-s', 'herramientas/exportar_glifos.gd', '--', os.path.abspath(ruta)], check=True, env=env)
    with open(ruta, encoding='utf-8') as f:
        return json.load(f)


def punto(x, y, cursiva):
    """Un punto (x, y) de la fuente, inclinado si la fuente es cursiva (la inclinación sale de la línea de base)."""
    return (int(round(x + (y * INCLINACION if cursiva else 0.0))), int(round(y)))


def dibujar_glifo(celdas, peso, cursiva):
    """El glifo `celdas` ([[x, fila], ...], fila 0 arriba de todo) en un TTGlyphPen. La línea de base queda abajo de la fila 8 (el cuerpo son las filas 2 a 8)."""
    pen = TTGlyphPen(None)
    lado = CELDA * LLENADO[peso]
    margen = (CELDA - lado) / 2.0
    for x, fila in celdas:
        x0 = x * CELDA + margen
        x1 = x0 + lado
        y0 = (8 - fila) * CELDA + margen
        y1 = y0 + lado
        pen.moveTo(punto(x0, y0, cursiva))
        pen.lineTo(punto(x0, y1, cursiva))
        pen.lineTo(punto(x1, y1, cursiva))
        pen.lineTo(punto(x1, y0, cursiva))
        pen.closePath()
    return pen.glyph()


def glifo_vacio():
    return TTGlyphPen(None).glyph()


def glifo_notdef(cursiva):
    """El rectángulo hueco de los caracteres que la fuente no tiene."""
    pen = TTGlyphPen(None)
    for pts in ([(50, -100), (50, 800), (500, 800), (500, -100)], [(130, -20), (420, -20), (420, 720), (130, 720)]):
        pts = [punto(x, y, cursiva) for x, y in pts]
        pen.moveTo(pts[0])
        for p in pts[1:]:
            pen.lineTo(p)
        pen.closePath()
    return pen.glyph()


def construir(datos, peso, cursiva):
    glifos = datos['glifos']
    avance = datos['avance'] * CELDA
    orden = ['.notdef', 'space']
    glyphs = {'.notdef': glifo_notdef(cursiva), 'space': glifo_vacio()}
    anchos = {'.notdef': (avance, 0), 'space': (avance, 0)}
    cmap = {0x20: 'space', 0xA0: 'space'}
    for ch in sorted(glifos, key=ord):
        if ch == ' ':
            continue
        nombre = 'uni%04X' % ord(ch)
        celdas = glifos[ch]
        orden.append(nombre)
        glyphs[nombre] = dibujar_glifo(celdas, peso, cursiva)
        ancho = max([c[0] for c in celdas] + [datos['ancho'] - 1]) + 1   # (el infinito es más ancho que los demás)
        anchos[nombre] = ((ancho + 1) * CELDA if ancho > datos['ancho'] else avance, 0)
        cmap[ord(ch)] = nombre
    fb = FontBuilder(1000, isTTF=True)
    fb.setupGlyphOrder(orden)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics({n: (a, 0) for n, (a, _) in anchos.items()})
    estilo = NOMBRE_PESO[peso] + (' Italic' if cursiva else '')
    if peso == 400:
        estilo = 'Italic' if cursiva else 'Regular'
    familia = FAMILIA if peso in (400, 700) else '%s %s' % (FAMILIA, NOMBRE_PESO[peso])
    sub = ('Bold Italic' if cursiva else 'Bold') if peso == 700 else ('Italic' if cursiva else 'Regular')
    nombres = {'familyName': familia, 'styleName': sub, 'uniqueFontIdentifier': '%s %s 1.0' % (FAMILIA, estilo), 'fullName': '%s %s' % (FAMILIA, estilo),
               'psName': '%s-%s' % (FAMILIA.replace(' ', ''), estilo.replace(' ', '')), 'version': 'Version 1.0'}
    if peso == 200:   # (la liviana es un estilo de la familia, no la redonda de otra)
        nombres['typographicFamily'] = FAMILIA
        nombres['typographicSubfamily'] = estilo
    fb.setupNameTable(nombres)
    fs = 0x80 | (0x01 if cursiva else 0) | (0x20 if peso == 700 else 0) | (0x40 if peso == 400 and not cursiva else 0)
    fb.setupOS2(version=4, sTypoAscender=ASCENDENTE, sTypoDescender=DESCENDENTE - 100, sTypoLineGap=100, usWinAscent=ASCENDENTE + 100, usWinDescent=-DESCENDENTE + 100,
                usWeightClass=peso, fsType=0, fsSelection=fs, xAvgCharWidth=avance)
    fb.setupHorizontalHeader(ascent=ASCENDENTE, descent=DESCENDENTE - 100, lineGap=100)
    fb.setupPost(italicAngle=-12.0 if cursiva else 0.0, isFixedPitch=0)
    font = fb.font
    font['head'].macStyle = (1 if peso == 700 else 0) | (2 if cursiva else 0)
    if peso == 700:
        removeOverlaps(font)   # (los cubitos se tocan: un solo contorno por trazo)
    return font


def css():
    bloques = []
    for peso in (200, 400, 700):
        for cursiva in (False, True):
            archivo = 'lucid-stakes-%d%s' % (peso, '-italic' if cursiva else '')
            bloques.append("""@font-face {
  font-family: 'Lucid Stakes';
  font-weight: %d;
  font-style: %s;
  font-display: swap;
  src: url('fonts/%s.woff2') format('woff2'), url('fonts/%s.ttf') format('truetype');
}
""" % (peso, 'italic' if cursiva else 'normal', archivo, archivo))
    return '\n'.join(bloques) + """
/* La fuente de cubitos del juego. Pesos: 200 (cubitos chicos), 400 (con rendija) y 700 (cubitos que se juntan). Cursiva: font-style: italic.
   Se ve mejor en tamaños que sean múltiplos de 11 px (cada celda de la grilla mide 1/11 del tamaño). */
.lucid { font-family: 'Lucid Stakes', monospace; font-weight: 400; letter-spacing: 0.02em; -webkit-font-smoothing: none; }

/* El título dorado con la sombra dura que lleva en el juego. */
.lucid-titulo {
  font-family: 'Lucid Stakes', monospace;
  font-weight: 700;
  color: #f6dc8a;
  background: linear-gradient(#fff2b8, #e9bd4a 70%, #c58f24);
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
  filter: drop-shadow(0.06em 0.08em 0 #1a0d2b) drop-shadow(0 0 0.01em #1a0d2b);
}
"""


def demo():
    return """<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Lucid Stakes - la fuente</title>
<link rel="stylesheet" href="lucid-stakes.css">
<style>
  body { margin: 0; padding: 32px 16px 64px; background: #120a22; color: #efe6ff; font-family: system-ui, sans-serif; }
  main { max-width: 900px; margin: 0 auto; }
  h1 { font-size: 88px; line-height: 1.1; margin: 0 0 8px; }
  .nota { color: #a99cc9; font-size: 15px; margin: 0 0 32px; }
  .fila { border-top: 1px solid #2a1c47; padding: 18px 0; }
  .fila small { display: block; color: #a99cc9; font: 13px system-ui, sans-serif; margin-bottom: 6px; }
  .muestra { font-size: 33px; line-height: 1.35; }
  .parrafo { font-size: 22px; line-height: 1.6; }
</style>
</head>
<body>
<main>
  <h1 class="lucid-titulo">Lucid Stakes</h1>
  <p class="nota">La fuente de cubitos del juego, como texto de verdad: se selecciona, se busca y escala sin pixelarse.</p>
  <div class="fila"><small>200 · liviana</small><div class="lucid muestra" style="font-weight:200">Escapa de la pesadilla, una torre a la vez 0123456789</div></div>
  <div class="fila"><small>200 · liviana cursiva</small><div class="lucid muestra" style="font-weight:200;font-style:italic">Escapa de la pesadilla, una torre a la vez 0123456789</div></div>
  <div class="fila"><small>400 · normal</small><div class="lucid muestra">Escapa de la pesadilla, una torre a la vez 0123456789</div></div>
  <div class="fila"><small>400 · cursiva</small><div class="lucid muestra" style="font-style:italic">Escapa de la pesadilla, una torre a la vez 0123456789</div></div>
  <div class="fila"><small>700 · negrita</small><div class="lucid muestra" style="font-weight:700">Escapa de la pesadilla, una torre a la vez 0123456789</div></div>
  <div class="fila"><small>700 · negrita cursiva</small><div class="lucid muestra" style="font-weight:700;font-style:italic">Escapa de la pesadilla, una torre a la vez 0123456789</div></div>
  <div class="fila"><small>Acentos, signos y símbolos</small><div class="lucid muestra">ÁÉÍÓÚ ÑÜ áéíóúñü ¿Quieres más? ¡Hola! (1/3) 50 % ∞ ✓ × +</div></div>
  <div class="fila"><small>Símbolos</small><div class="lucid muestra">$ — • … ★ ☆ ‹ › ▸ ← → ♥</div></div>
  <div class="fila"><small>Párrafo (22 px)</small><p class="lucid parrafo">Cada ficha es un pedazo de despertar. El peaje de Farolín se paga con claridad: mira el precio arriba a la izquierda, se pone azul cuando te alcanza.</p></div>
</main>
</body>
</html>
"""


def principal():
    ap = argparse.ArgumentParser()
    ap.add_argument('--salida', default=os.path.join(RAIZ, 'web_fuente'))
    ap.add_argument('--glifos', default='')
    a = ap.parse_args()
    carpeta = os.path.abspath(a.salida)
    fuentes = os.path.join(carpeta, 'fonts')
    os.makedirs(fuentes, exist_ok=True)
    ruta_glifos = a.glifos or os.path.join(carpeta, '_glifos.json')
    datos = cargar_glifos(ruta_glifos)
    for peso in (200, 400, 700):
        for cursiva in (False, True):
            base = os.path.join(fuentes, 'lucid-stakes-%d%s' % (peso, '-italic' if cursiva else ''))
            font = construir(datos, peso, cursiva)
            font.save(base + '.ttf')
            woff = TTFont(base + '.ttf')
            woff.flavor = 'woff2'
            woff.save(base + '.woff2')
            print('%s.ttf y .woff2 (%d bytes el woff2)' % (os.path.basename(base), os.path.getsize(base + '.woff2')))
    with open(os.path.join(carpeta, 'lucid-stakes.css'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(css())
    with open(os.path.join(carpeta, 'demo.html'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(demo())
    if not a.glifos and os.path.exists(ruta_glifos):
        os.remove(ruta_glifos)   # (el volcado de celdas es sólo un paso intermedio)
    print('listo: %s' % carpeta)


if __name__ == '__main__':
    principal()
