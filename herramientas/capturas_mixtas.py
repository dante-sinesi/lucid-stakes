"""Capturas de salas mixtas (varios especiales): las que más especiales tienen (y, entre ésas, las más complejas).
Uso: python herramientas/capturas_mixtas.py [cuantas=4] [archivos=bibliotecas/salas_mixtas.jsonl.parcial,bibliotecas/salas_mixtas_altas.jsonl.parcial]"""
import json, os, subprocess, sys
RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
cuantas = 4
archivos = ['bibliotecas/salas_mixtas.jsonl.parcial', 'bibliotecas/salas_mixtas_altas.jsonl.parcial']
for a in sys.argv[1:]:
    if a.startswith('cuantas='): cuantas = int(a[8:])
    if a.startswith('archivos='): archivos = a[9:].split(',')
salas = []
for f in archivos:
    ruta = os.path.join(RAIZ, f)
    if os.path.exists(ruta):
        salas += [json.loads(l) for l in open(ruta, encoding='utf-8') if l.strip()]
salas = [d for d in salas if len(d.get('roles', [])) >= 2] or salas
salas.sort(key=lambda d: (-len(d.get('roles', [])), -d.get('complejidad', 0)))
elegidas = salas[:cuantas]
os.makedirs(os.path.join(RAIZ, 'capturas', 'sn'), exist_ok=True)
sel = os.path.join(RAIZ, 'capturas', 'sn', 'sel_mixtas.jsonl')
with open(sel, 'w') as f:
    for d in elegidas: f.write(json.dumps(d) + '\n')
env = dict(os.environ, GAME_SANDBOX='1', SN_LIB=sel, SN_SALA='1')
subprocess.run([os.path.join(RAIZ, 'tools', 'Godot_v4.7.2-stable_win64_console.exe'), '--path', RAIZ, '--rendering-driver', 'opengl3', '--resolution', '1600x900', '-s', 'tests/shot_estudio_salas_nuevas.gd', '--', os.path.join(RAIZ, 'capturas', 'sn', 'mix'), ','.join(str(i) for i in range(len(elegidas))), '6'], env=env, cwd=RAIZ, stdout=subprocess.DEVNULL)
salida = os.path.join(RAIZ, 'capturas', 'progreso_sn')
for i, d in enumerate(elegidas):
    t = 'MIXTA %s, %d pisos: %s, %d pasos (sin especiales %d), %d bloques distintos, complejidad %.0f bits' % (d['tipo'], d['meta'] - 1, ' + '.join(d['roles']), d['pasos'], d.get('pasos_sin_especiales', 0), d['distintos'], d.get('complejidad', 0))
    out = os.path.join(salida, 'mixta_%d.png' % (i + 1))
    subprocess.run(['python', os.path.join(RAIZ, 'herramientas', 'montaje_salas_nuevas.py'), out, os.path.join(RAIZ, 'capturas', 'sn', 'mix'), str(i), '6', t], cwd=RAIZ)
