"""Resume la telemetría local del juego (telemetria.jsonl): cómo les fue a los jugadores en cada nivel de sala, qué las pierde y cuánto del temporizador usan.
Uso: python herramientas/resumen_telemetria.py [archivo.jsonl]   (por omisión, el de la carpeta de datos del juego en %APPDATA%/Godot/app_userdata/*/telemetria.jsonl)"""
import glob, json, os, sys
from collections import Counter, defaultdict

def buscar():
    if len(sys.argv) > 1:
        return sys.argv[1]
    base = os.path.join(os.environ.get('APPDATA', ''), 'Godot', 'app_userdata')
    c = glob.glob(os.path.join(base, '*', 'telemetria.jsonl'))
    return c[0] if c else ''

ruta = buscar()
if not ruta or not os.path.exists(ruta):
    print('no encontré la telemetría:', ruta)
    sys.exit(1)
ev = [json.loads(l) for l in open(ruta, encoding='utf-8') if l.strip()]
salas = [e for e in ev if e['kind'] == 'sala']
torres = [e for e in ev if e['kind'] == 'torre' and e.get('torre_nueva')]
print('eventos: %d · salas: %d · intentos de torre: %d' % (len(ev), len(salas), len(torres)))
por_nivel = defaultdict(lambda: {'n': 0, 'perdidas': 0, 'movs': 0, 'max': 0, 'pasos': 0, 'seg': 0})
causas = Counter()
for s in salas:
    p = por_nivel[s['nivel']]
    p['n'] += 1
    p['perdidas'] += 1 if s['resultado'] == 'perdida' else 0
    p['movs'] += s['movs']; p['max'] += s['max_mov']; p['pasos'] += s['pasos_minimos']; p['seg'] += s['segundos']
    if s['resultado'] == 'perdida':
        causas[s['causa']] += 1
print('nivel       salas  perdidas  movs/mínimo  movs/máximo  segundos')
for n in ['facil', 'media', 'dificil', 'pesadilla']:
    if n in por_nivel:
        p = por_nivel[n]
        print('%-10s %6d %8.0f%% %12.2f %12.2f %9.0f' % (n, p['n'], 100 * p['perdidas'] / p['n'], p['movs'] / max(p['pasos'], 1), p['movs'] / max(p['max'], 1), p['seg'] / p['n']))
print('causas de las salas perdidas:', dict(causas))
por_etapa = defaultdict(lambda: Counter())
for t in torres:
    por_etapa[t['stage']][t['outcome']] += 1
print('por etapa (torres):', {k: dict(v) for k, v in sorted(por_etapa.items())})
