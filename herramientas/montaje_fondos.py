"""Junta los cuadros de tests/capturas/shot_fondo_animado.gd en un GIF por fondo.
Uso: python herramientas/montaje_fondos.py CARPETA [milisegundos_por_cuadro]"""
import glob, os, sys
from PIL import Image
carpeta = sys.argv[1]
ms = int(sys.argv[2]) if len(sys.argv) > 2 else 300
modos = sorted({os.path.basename(f).split("_")[0] for f in glob.glob(os.path.join(carpeta, "m*_*.png"))})
for m in modos:
    cuadros = [Image.open(f).convert("RGB") for f in sorted(glob.glob(os.path.join(carpeta, m + "_*.png")))]
    cuadros = [c.quantize(colors=160, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for c in cuadros]
    salida = os.path.join(carpeta, "fondo_%s.gif" % m[1:])
    cuadros[0].save(salida, save_all=True, append_images=cuadros[1:], duration=ms, loop=0, optimize=False)
    print(salida, len(cuadros), "cuadros")
