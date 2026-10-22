"""Capturas de las salas con especiales: por cada rol, una de dificultad media (60 a 110 bits) y una de pesadilla (más de 180); si no hay en el rango, la más cercana (y lo dice en el título).
Uso: python herramientas/capturas_especiales.py [salida=capturas/progreso_sn] [roles=pinchos,pesado,hielo,trampolin,agrietado]"""
import json, os, subprocess, sys
RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
salida = os.path.join(RAIZ, 'capturas', 'progreso_sn')
roles = 'pinchos,pesado,hielo,trampolin,agrietado'.split(',')
for a in sys.argv[1:]:
    if a.startswith('salida='): salida = a[7:]
    if a.startswith('roles='): roles = a[6:].split(',')
OBJ = {'media': (85, 60, 110), 'pesadilla': (230, 180, 10 ** 6)}
elegidas = []
resumen = []
for rol in roles:
    ruta = os.path.join(RAIZ, 'bibliotecas', 'salas_especiales_%s.jsonl' % rol)
    if not os.path.exists(ruta): continue
    salas = [json.loads(l) for l in open(ruta, encoding='utf-8') if l.strip()]
    cx = lambda d: d.get('complejidad', 0)
    resumen.append('%s: %d salas; complejidad %s' % (rol, len(salas), ('%.0f-%.0f' % (min(cx(d) for d in salas), max(cx(d) for d in salas))) if salas else '-'))
    for niv, (centro, lo, hi) in OBJ.items():
        en = [d for d in salas if lo <= cx(d) < hi] or salas
        if not en: continue
        en.sort(key=lambda d: abs(cx(d) - centro))
        d = en[0]
        d['_rol'] = rol; d['_niv'] = niv; d['_en_rango'] = lo <= cx(d) < hi
        elegidas.append(d)
os.makedirs(os.path.join(RAIZ, 'capturas', 'sn'), exist_ok=True)
sel = os.path.join(RAIZ, 'capturas', 'sn', 'sel_especiales.jsonl')
with open(sel, 'w') as f:
    for d in elegidas: f.write(json.dumps(d) + '\n')
env = dict(os.environ, GAME_SANDBOX='1', SN_LIB=sel)
subprocess.run([os.path.join(RAIZ, 'tools', 'Godot_v4.7.2-stable_win64_console.exe'), '--path', RAIZ, '--rendering-driver', 'opengl3', '--resolution', '1600x900', '-s', 'tests/shot_estudio_salas_nuevas.gd', '--', os.path.join(RAIZ, 'capturas', 'sn', 'esp'), ','.join(str(i) for i in range(len(elegidas))), '6'], env=env, cwd=RAIZ, stdout=subprocess.DEVNULL)
os.makedirs(salida, exist_ok=True)
NOM = {'pesado': 'PESADOS (oscuros)', 'pinchos': 'PINCHOS', 'agrietado': 'AGRIETADOS', 'hielo': 'HIELO', 'trampolin': 'TRAMPOLIN'}
for i, d in enumerate(elegidas):
    esp = d.get('especiales', {})
    n = sum(esp.values())
    t = '%s, nivel %s%s: %s, %d pisos, %d especial(es), %d pasos (la sala sin especiales: %d), %d bloques distintos, complejidad %.0f bits' % (
        NOM[d['_rol']], d['_niv'].upper(), '' if d['_en_rango'] else ' (la mas cercana que hay)', d['tipo'], d['meta'] - 1, n, d['pasos'], d.get('pasos_sin_especiales', 0), d['distintos'], d.get('complejidad', 0))
    out = os.path.join(salida, 'esp_%s_%s.png' % (d['_rol'], d['_niv']))
    subprocess.run(['python', os.path.join(RAIZ, 'herramientas', 'montaje_salas_nuevas.py'), out, os.path.join(RAIZ, 'capturas', 'sn', 'esp'), str(i), '6', t], cwd=RAIZ)
print('\n'.join(resumen))
print('listo', len(elegidas))
