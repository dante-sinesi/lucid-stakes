"""Capturas de muestra de la biblioteca final: una sala por celda (nivel x tipo) elegida cerca de la mediana de su complejidad, desde detrás del jugador (6 cuadros del camino).
Uso: python herramientas/capturas_biblioteca.py [salida=capturas/progreso_sn] [celdas=facil:3x3,facil:5x3,...]"""
import json, os, subprocess, sys, statistics as st
RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
salida = os.path.join(RAIZ, 'capturas', 'progreso_sn')
celdas = ['facil:3x3', 'facil:5x3', 'facil:8x3', 'media:5x3', 'dificil:8x3', 'pesadilla:3x3', 'pesadilla:5x3', 'pesadilla:8x3']
for a in sys.argv[1:]:
    if a.startswith('salida='): salida = a[7:]
    if a.startswith('celdas='): celdas = a[7:].split(',')
salas = [json.loads(l) for l in open(os.path.join(RAIZ, 'bibliotecas', 'salas_nuevas_final.jsonl'), encoding='utf-8') if l.strip()]
elegidas = []
for c in celdas:
    niv, tipo = c.split(':')
    g = [d for d in salas if d['nivel'] == niv and d['tipo'] == tipo]
    if not g: continue
    pref = [d for d in g if d.get('exacto')] or g
    med = st.median([d.get('complejidad', d['pasos']) for d in pref])
    pref.sort(key=lambda d: abs(d.get('complejidad', d['pasos']) - med))
    elegidas.append(pref[0])
os.makedirs(os.path.join(RAIZ, 'capturas', 'sn'), exist_ok=True)
sel = os.path.join(RAIZ, 'capturas', 'sn', 'sel_final.jsonl')
with open(sel, 'w') as f:
    for d in elegidas: f.write(json.dumps(d) + '\n')
env = dict(os.environ, GAME_SANDBOX='1', SN_LIB=sel)
indices = ','.join(str(i) for i in range(len(elegidas)))
subprocess.run([os.path.join(RAIZ, 'tools', 'Godot_v4.7.2-stable_win64_console.exe'), '--path', RAIZ, '--rendering-driver', 'opengl3', '--resolution', '1600x900', '-s', 'tests/shot_estudio_salas_nuevas.gd', '--', os.path.join(RAIZ, 'capturas', 'sn', 'fin'), indices, '6'], env=env, cwd=RAIZ, stdout=subprocess.DEVNULL)
os.makedirs(salida, exist_ok=True)
for i, d in enumerate(elegidas):
    est = 'minimo exacto %d' % d['pasos'] if d.get('exacto') else 'camino de %d pasos (el minimo esta entre %d y %d)' % (d['pasos'], d.get('cota_inferior', 0), d['pasos'])
    cx = ('complejidad %.0f bits' % d['complejidad']) if d.get('complejidad', 0) > 0 else 'complejidad estimada %s' % ('' )
    t = 'Nivel %s: %s, %d pisos, %s, %d agarres, %d bloques distintos, %s' % (d['nivel'].upper(), d['tipo'], d['meta'] - 1, est, d['agarres'], d['distintos'], cx)
    out = os.path.join(salida, 'final_%d_%s_%s.png' % (i, d['nivel'], d['tipo']))
    subprocess.run(['python', os.path.join(RAIZ, 'herramientas', 'montaje_salas_nuevas.py'), out, os.path.join(RAIZ, 'capturas', 'sn', 'fin'), str(i), '6', t], cwd=RAIZ)
print('listo', len(elegidas))
