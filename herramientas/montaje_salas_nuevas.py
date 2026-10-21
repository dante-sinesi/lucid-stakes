"""Arma una hoja con los cuadros de capturas de una sala nueva (cuadros de tests/shot_salas_nuevas.gd).
Uso: python herramientas/montaje_salas_nuevas.py SALIDA.png PREFIJO INDICE_SALA CUADROS "titulo" """
import sys
from PIL import Image, ImageDraw, ImageFont

salida, prefijo, idx, n, titulo = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5]
W, H = 640, 360
cols = 3
filas = (n + cols - 1) // cols
img = Image.new('RGB', (W * cols, H * filas + 36), (24, 22, 34))
d = ImageDraw.Draw(img)
try:
    f = ImageFont.truetype('arial.ttf', 15)
except Exception:
    f = ImageFont.load_default()
d.text((10, 9), titulo, fill=(255, 235, 160), font=f)
for k in range(n):
    im = None
    for nombre in ('%s_%s_%d_vista.png' % (prefijo, idx, k), '%s_%s_%d.png' % (prefijo, idx, k)):
        try:
            im = Image.open(nombre).convert('RGB').resize((W, H))
            break
        except Exception:
            pass
    if im is None:
        continue
    img.paste(im, ((k % cols) * W, 36 + (k // cols) * H))
    d.text(((k % cols) * W + 8, 40 + (k // cols) * H), 'cuadro %d' % (k + 1), fill=(220, 220, 235), font=f)
img.save(salida)
print('ok', salida)
