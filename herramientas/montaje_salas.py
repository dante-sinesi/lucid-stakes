"""Arma una hoja con los cuadros de capturas de una sala nueva (cuadros de tests/shot_salas_nuevas.gd).
La cámara es fija, así que se recorta a la caja que contiene la sala en TODOS los cuadros (la misma para todos): las salas altas, que son angostas, se
muestran en columnas verticales y las bajas en una grilla de 3 columnas, siempre lo más grandes que entran.
Uso: python herramientas/montaje_salas.py SALIDA.png PREFIJO INDICE_SALA CUADROS "titulo" """
import sys
from PIL import Image, ImageDraw, ImageFont, ImageChops

salida, prefijo, idx, n, titulo = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5]
frames = []
for k in range(n):
    for nombre in ('%s_%s_%d_vista.png' % (prefijo, idx, k), '%s_%s_%d.png' % (prefijo, idx, k)):
        try:
            frames.append(Image.open(nombre).convert('RGB'))
            break
        except Exception:
            pass
    else:
        frames.append(None)
ok = [f for f in frames if f is not None]
fondo = Image.new('RGB', ok[0].size, ok[0].getpixel((0, 0)))
caja = None
for f in ok:
    # (se ignora la grilla de referencia, muy tenue: sólo cuenta lo que se aparta bastante del fondo)
    dif = ImageChops.difference(f, fondo).convert('L').point(lambda v: 255 if v > 60 else 0)
    b = dif.getbbox()
    if b:
        caja = b if caja is None else (min(caja[0], b[0]), min(caja[1], b[1]), max(caja[2], b[2]), max(caja[3], b[3]))
if caja is None:
    caja = (0, 0) + ok[0].size
m = 24
caja = (max(caja[0] - m, 0), max(caja[1] - m, 0), min(caja[2] + m, ok[0].size[0]), min(caja[3] + m, ok[0].size[1]))
bw, bh = caja[2] - caja[0], caja[3] - caja[1]
aspecto = bw / bh
if aspecto < 0.75:   # sala alta y angosta: todos los cuadros en una fila
    cols = min(n, 6)
    W = 1920 // cols
    H = min(int(W / aspecto), 1000)
else:
    cols = 3
    W = 640
    H = min(int(W / aspecto), 520)
filas = (n + cols - 1) // cols
img = Image.new('RGB', (W * cols, H * filas + 36), (24, 22, 34))
d = ImageDraw.Draw(img)
try:
    fnt = ImageFont.truetype('arial.ttf', 15)
except Exception:
    fnt = ImageFont.load_default()
d.text((10, 9), titulo, fill=(255, 235, 160), font=fnt)
for k, f in enumerate(frames):
    if f is None:
        continue
    c = f.crop(caja)
    esc = min(W / c.size[0], H / c.size[1])
    c = c.resize((max(int(c.size[0] * esc), 1), max(int(c.size[1] * esc), 1)), Image.LANCZOS)
    x0 = (k % cols) * W + (W - c.size[0]) // 2
    y0 = 36 + (k // cols) * H + (H - c.size[1]) // 2
    img.paste(c, (x0, y0))
    d.text(((k % cols) * W + 8, 40 + (k // cols) * H), 'cuadro %d' % (k + 1), fill=(220, 220, 235), font=fnt)
img.save(salida)
print('ok', salida)
