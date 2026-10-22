"""Segundo paso: toma salas ya generadas (con el mínimo demostrado y de hasta 10 pisos, sin especiales) y les pone un especial POR PROPÓSITO con
`salas_nuevas.exe --especializar rol=...`. Sólo se queda con las salas donde cada especial cumplió su papel y es necesario (ver docs/plan_generador_especiales.md).
Roles: pesado, pinchos, agrietado, hielo, trampolin.
Uso: python herramientas/especializar_biblioteca.py rol=pesado [objetivo=40] [entrada=bibliotecas/salas_nuevas_final.jsonl] [salida=bibliotecas/salas_especiales_<rol>.jsonl]
                                                   [exe=tools/salas_nuevas.exe] [hilos=6] [tope=200000] [max=4] [ganancia=2] [niveles=media,dificil]"""
import json, os, random, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor, as_completed
RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
LETRA = {'pesado': 'h', 'pinchos': 's', 'agrietado': 'c', 'hielo': 'i', 'trampolin': 'k'}
o = {'rol': 'pesado', 'objetivo': '40', 'entrada': 'bibliotecas/salas_nuevas_final.jsonl', 'exe': 'tools/salas_nuevas.exe', 'hilos': '6', 'tope': '200000', 'max': '4', 'ganancia': '2', 'niveles': '', 'tipos': '', 'largo': ''}
for a in sys.argv[1:]:
    if '=' in a:
        k, v = a.split('=', 1); o[k] = v
rol = o['rol']
salida = o.get('salida', 'bibliotecas/salas_especiales_%s.jsonl' % rol)
exe = os.path.join(RAIZ, o['exe'])
salas = [json.loads(l) for l in open(os.path.join(RAIZ, o['entrada']), encoding='utf-8') if l.strip()]
niv = [x for x in o['niveles'].split(',') if x]
cand = [d for d in salas if d.get('exacto') and d['meta'] <= 10 and not any(b[3] not in 'pnf' for b in d['bloques']) and (not niv or d.get('nivel') in niv) and (not o['tipos'] or d['tipo'] in o['tipos'].split(','))]
random.seed(11)
random.shuffle(cand)


def procesar(d):
    t = 'meta %d\njugador %d %d %d\ncolgado 0 0 0\ntope 1500000\n' % (d['meta'], *d['jugador'])
    for b in d['bloques']:
        t += 'b %d %d %d %s\n' % tuple(b)
    try:
        r = subprocess.run([exe, '--especializar', 'rol=' + rol, 'tipo=' + d['tipo'], 'tope=' + o['tope'], 'max=' + o['max'], 'ganancia=' + o['ganancia'], 'seed=%d' % random.randint(1, 10**6)],
                           input=t, capture_output=True, text=True, timeout=900,
                           env=dict(os.environ, **({'SN_LARGO': str(random.randint(*[int(x) for x in o['largo'].split('-')]))} if o['largo'] else {})))
        j = json.loads(r.stdout.strip().splitlines()[-1])
    except Exception:
        return None
    if j.get('ok') is False:
        return None
    j['nivel_base'] = d.get('nivel')
    j['pasos_sin_especiales'] = d['pasos']
    return j


out = []
vistas = 0
t0 = time.time()
objetivo = int(o['objetivo'])
with ThreadPoolExecutor(max_workers=int(o['hilos'])) as ex:
    futuros = []
    it = iter(cand)
    pendientes = set()
    def lanzar():
        try:
            d = next(it)
        except StopIteration:
            return False
        pendientes.add(ex.submit(procesar, d))
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
            vistas += 1
            j = f.result()
            if j is not None:
                out.append(j)
                print('  [%3d] %s h=%d: pasos %d -> %d, complejidad %.0f (%d salas probadas, %.0f s)' % (len(out), j['tipo'], j['meta'], j['pasos_sin_especiales'], j['pasos'], j.get('complejidad', 0), vistas, time.time() - t0), flush=True)
            if len(out) < objetivo:
                lanzar()
    for f in pendientes:
        f.cancel()
with open(os.path.join(RAIZ, salida), 'w', encoding='ascii') as f:
    for j in out:
        f.write(json.dumps(j) + '\n')
print('%s: %d salas con especiales de %d probadas (%.0f s) -> %s' % (rol, len(out), vistas, time.time() - t0, salida))
