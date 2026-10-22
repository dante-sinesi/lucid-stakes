"""Salas con VARIOS especiales mezclados, según la altura: cada sala base de la biblioteca recibe una cadena de especializaciones
(`salas_nuevas.exe --especializar rol=...`, una tras otra sobre el resultado de la anterior; puede repetirse un tipo) y al final `--revisar` comprueba que
cada especial siga siendo necesario. Cuántos entran lo fija la altura: unidades = 1 + (pisos - 3) // 9 (3x3 de 5 a 9 pisos: 1; 5x3 de 12 a 15: 2; 8x3 de 21 a 24: 3).
Uso: python herramientas/mixtas_biblioteca.py [objetivo=40] [entrada=bibliotecas/salas_nuevas_final.jsonl] [salida=bibliotecas/salas_mixtas.jsonl]
                                              [hilos=7] [tope=100000] [pmin=5] [pmax=24] [tipo=3x3|5x3|8x3] [semilla=11]"""
import json, os, random, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor
RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
o = {'objetivo': '40', 'entrada': 'bibliotecas/salas_nuevas_final.jsonl', 'salida': 'bibliotecas/salas_mixtas.jsonl', 'hilos': '7', 'tope': '100000',
     'pmin': '5', 'pmax': '24', 'tipo': '', 'semilla': '11', 'espera': '120', 'exe': 'tools/salas_nuevas.exe'}
for a in sys.argv[1:]:
    if '=' in a:
        k, v = a.split('=', 1); o[k] = v
exe = os.path.join(RAIZ, o['exe'])
ROLES = ['pinchos', 'pesado', 'agrietado', 'hielo', 'trampolin', 'bomba']
LETRA = {'pesado': 'h', 'pinchos': 's', 'agrietado': 'c', 'hielo': 'i', 'trampolin': 'k', 'bomba': 'b'}
MAX_POR_ROL = {'trampolin': 1, 'bomba': 1}


def unidades_para(pisos):
    return max(1, min(4, 1 + (pisos - 3) // 9))


def texto(d):
    col = d.get('colgado', [0, 0])
    t = 'meta %d\njugador %d %d %d\ncolgado %d 0 %d\ntope 1500000\n' % (d['meta'], *d['jugador'], col[0], col[1])
    for b in d['bloques']:
        t += 'b %d %d %d %s\n' % tuple(b)
    return t


def correr(args, d, espera=600):
    r = subprocess.run([exe] + args, input=texto(d), capture_output=True, text=True, timeout=espera)
    if not r.stdout.strip() and os.environ.get('MIX_DUMP'):
        n = len(os.listdir(os.environ['MIX_DUMP']))
        open(os.path.join(os.environ['MIX_DUMP'], 'caida_%d.txt' % n), 'w').write(' '.join(args) + chr(10) + 'rc=%s' % r.returncode + chr(10) + texto(d))
    return json.loads(r.stdout.strip().splitlines()[-1])


def contar(d):
    c = {}
    for b in d['bloques']:
        k = b[3][0]
        if k in 'hsciktb' or k == 'b':
            c[k] = c.get(k, 0) + 1
    return c


def procesar(base, rng):
    pisos = int(base['meta']) - 1
    nmax = unidades_para(pisos)
    k = nmax if (nmax == 1 or rng.random() < 0.65) else rng.randint(2, nmax)
    actual = base
    usados = []
    intentos = 0
    while len(usados) < k and intentos < 3 * k + 3:
        intentos += 1
        opciones = [r for r in ROLES if usados.count(r) < MAX_POR_ROL.get(r, 99)]
        rol = rng.choice(opciones)
        t_paso = time.time()
        try:
            j = correr(['--especializar', 'rol=' + rol, 'tipo=' + base['tipo'], 'tope=' + o['tope'], 'max=1', 'ganancia=2', 'seed=%d' % rng.randint(1, 10 ** 6)], actual, int(o['espera']))
        except Exception as e:
            if os.environ.get('MIX_LOG'):
                print('   paso', rol, 'FALLO', repr(e)[:60], round(time.time() - t_paso, 1), file=sys.stderr, flush=True)
            continue
        if os.environ.get('MIX_LOG'):
            print('   paso', rol, base['tipo'], pisos, round(time.time() - t_paso, 1), 'ok' if j.get('ok') is not False else j.get('error'), file=sys.stderr, flush=True)
        if j.get('ok') is False:
            continue
        j['colgado'] = j.get('colgado', [0, 0])
        actual = j
        usados.append(rol)
    if not usados or (len(usados) < 2 and nmax >= 2):
        return None
    try:
        rv = correr(['--revisar', 'tope=' + o['tope']], actual, int(o['espera']))
    except Exception:
        return None
    if not rv.get('ok') or rv['necesarias'] < rv['unidades']:
        return None
    actual['roles'] = usados
    actual['especiales'] = contar(actual)
    actual['nivel_base'] = base.get('nivel')
    actual['pasos_sin_especiales'] = base['pasos']
    actual.pop('rol', None)
    return actual


def main():
    salas = [json.loads(l) for l in open(os.path.join(RAIZ, o['entrada']), encoding='utf-8') if l.strip()]
    pmin, pmax = int(o['pmin']), int(o['pmax'])
    cand = [d for d in salas if pmin <= d['meta'] - 1 <= pmax and d.get('camino') and not any(b[3] not in 'pnf' for b in d['bloques'])
            and (not o['tipo'] or d['tipo'] == o['tipo'])]
    rng0 = random.Random(int(o['semilla']))
    rng0.shuffle(cand)
    objetivo = int(o['objetivo'])
    out = []
    probadas = 0
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=int(o['hilos'])) as ex:
        it = iter(cand)
        pendientes = set()

        def lanzar():
            try:
                d = next(it)
            except StopIteration:
                return False
            pendientes.add(ex.submit(procesar, d, random.Random(rng0.randint(1, 10 ** 9))))
            return True

        for _ in range(int(o['hilos'])):
            lanzar()
        while pendientes and len(out) < objetivo:
            hechos = [f for f in list(pendientes) if f.done()]
            if not hechos:
                time.sleep(0.5)
                continue
            for f in hechos:
                pendientes.discard(f)
                probadas += 1
                try:
                    j = f.result()
                except Exception as e:
                    print('   error:', repr(e)[:80], file=sys.stderr, flush=True)
                    j = None
                if j is not None:
                    out.append(j)
                    with open(os.path.join(RAIZ, o['salida'] + '.parcial'), 'a', encoding='ascii') as fp:
                        fp.write(json.dumps(j) + chr(10))
                    print('  [%3d] %s %d pisos: %s, pasos %d -> %d, complejidad %.0f (%d probadas, %.0f s)' % (len(out), j['tipo'], j['meta'] - 1, '+'.join(j['roles']), j['pasos_sin_especiales'], j['pasos'], j.get('complejidad', 0), probadas, time.time() - t0), flush=True)
                if len(out) < objetivo:
                    lanzar()
        for f in pendientes:
            f.cancel()
    with open(os.path.join(RAIZ, o['salida']), 'w', encoding='ascii') as f:
        for j in out:
            f.write(json.dumps(j) + '\n')
    print('mixtas: %d salas de %d probadas (%.0f s) -> %s' % (len(out), probadas, time.time() - t0, o['salida']))


main()
