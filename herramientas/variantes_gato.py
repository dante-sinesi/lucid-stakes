"""Calcula las variantes del gatito travieso de cada sala de la biblioteca (docs/pruebas.md): para cada sala, unos cambios seguros (el gato mueve de 1 a 5 bloques comunes una celda,
según la altura) con el mínimo y el camino de cada uno, ya comprobados con el solucionador (`tools/salas.exe --variantes`, ver native/salas.cpp).
Escribe data/variantes_gato.jsonl, una línea por sala: {"id": N, "variantes": [{"k", "mov": [[x, y, z, nx, nz], ...], "pasos", "agarres", "distintos", "camino"}]}.
Es reanudable: las salas que ya están en el archivo no se vuelven a calcular. Varios procesos a la vez; Ctrl+C corta sin perder lo ya escrito.
Uso: python herramientas/variantes_gato.py [--procesos 7] [--n 3] [--intentos 30] [--ids 1,2,3 | --muestra 20] [--hasta 08:00 | --minutos 30] [--salida data/variantes_gato.jsonl]
Resumen al final: cuántas salas tienen variantes y cuántas no."""
import argparse, datetime, json, os, random, subprocess, sys, time
from multiprocessing import Pool

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
EXE = os.path.join(RAIZ, 'tools', 'salas.exe')
BIBLIOTECA = os.path.join(RAIZ, 'data', 'salas_torre.jsonl')
ESPERA = 300   # segundos por sala (si se pasa, la sala queda marcada como agotada)


def a_texto(d):
    """Una sala (jsonl) en el texto que lee `leer_sala` del ejecutable."""
    lineas = ['meta %d' % d['meta'], 'jugador %d %d %d' % tuple(int(v) for v in d['jugador']), 'colgado %d 0 %d' % (int(d['colgado'][0]), int(d['colgado'][1])), 'tope 200000']
    for b in d['bloques']:
        lineas.append('b %d %d %d %s' % (int(b[0]), int(b[1]), int(b[2]), b[3]))
    return '\n'.join(lineas) + '\n'


DIRS = [(1, 0), (-1, 0), (0, 1), (0, -1)]


def camino_texto(camino):
    """El camino de una sala ([[dx, dz, modo], ...]) en el texto compacto de las variantes: una letra por acción ('a' + modo * 4 + índice de DIRS)."""
    return ''.join(chr(97 + int(m) * 4 + DIRS.index((int(dx), int(dz)))) for dx, dz, m in camino)


def calcular(args):
    d, n, intentos, exe, fin_ts = args
    if fin_ts and time.time() > fin_ts:   # (se acabó la hora: las salas que faltan quedan para la próxima vez)
        return None
    try:
        r = subprocess.run([exe, '--variantes', 'tipo=' + d['tipo'], 'n=%d' % n, 'intentos=%d' % intentos, 'seed=%d' % (int(d['id']) * 7 + 1), 'conocido=' + camino_texto(d.get('camino', []))],
                           input=a_texto(d), capture_output=True, text=True, timeout=ESPERA, cwd=RAIZ)
    except subprocess.TimeoutExpired:
        return {'id': int(d['id']), 'variantes': [], 'agotada': True}
    for l in r.stdout.splitlines():
        if l.strip().startswith('{'):
            try:
                j = json.loads(l)
            except ValueError:
                continue
            if j.get('ok'):
                return {'id': int(d['id']), 'variantes': j['variantes']}
    return {'id': int(d['id']), 'variantes': [], 'error': True}


def principal():
    ap = argparse.ArgumentParser()
    ap.add_argument('--procesos', type=int, default=max(os.cpu_count() - 1, 1))
    ap.add_argument('--n', type=int, default=3, help='variantes por sala')
    ap.add_argument('--intentos', type=int, default=30, help='soluciones que se prueban por variante, como mucho')
    ap.add_argument('--ids', default='')
    ap.add_argument('--muestra', type=int, default=0, help='solo una muestra al azar de tantas salas (para probar)')
    ap.add_argument('--hasta', default='')
    ap.add_argument('--minutos', type=float, default=0)
    ap.add_argument('--salida', default=os.path.join('data', 'variantes_gato.jsonl'))
    a = ap.parse_args()
    salida = os.path.join(RAIZ, a.salida)
    fin = None
    if a.minutos > 0:
        fin = datetime.datetime.now() + datetime.timedelta(minutes=a.minutos)
    elif a.hasta:
        h, m = [int(v) for v in a.hasta.split(':')]
        fin = datetime.datetime.now().replace(hour=h, minute=m, second=0, microsecond=0)
        if fin <= datetime.datetime.now():
            fin += datetime.timedelta(days=1)
    salas = [json.loads(l) for l in open(BIBLIOTECA, encoding='utf-8') if l.strip()]
    hechas = set()
    if os.path.exists(salida):
        for l in open(salida, encoding='utf-8'):
            if l.strip():
                hechas.add(int(json.loads(l)['id']))
    if a.ids:
        quiero = {int(v) for v in a.ids.split(',')}
        salas = [d for d in salas if int(d['id']) in quiero]
    pendientes = [d for d in salas if int(d['id']) not in hechas]
    if a.muestra:
        random.Random(1).shuffle(pendientes)
        pendientes = pendientes[:a.muestra]
    print('%d salas en la biblioteca, %d ya calculadas, %d por calcular' % (len(salas), len(hechas), len(pendientes)), flush=True)
    fin_ts = fin.timestamp() if fin is not None else None
    tareas = [(d, a.n, a.intentos, EXE, fin_ts) for d in pendientes]
    con, sin, hechas_ahora = 0, 0, 0
    t0 = time.time()
    with Pool(a.procesos) as pool, open(salida, 'a', encoding='ascii') as f:
        for r in pool.imap_unordered(calcular, tareas):
            if r is None:
                continue
            f.write(json.dumps(r) + '\n')
            f.flush()
            hechas_ahora += 1
            if r['variantes']:
                con += 1
            else:
                sin += 1
            if hechas_ahora % 25 == 0:
                print('%d/%d (con variantes %d, sin %d) %.0f s' % (hechas_ahora, len(tareas), con, sin, time.time() - t0), flush=True)
    print('listo: %d salas calculadas, %d con variantes y %d sin (%.0f s)' % (hechas_ahora, con, sin, time.time() - t0))


if __name__ == '__main__':
    principal()
