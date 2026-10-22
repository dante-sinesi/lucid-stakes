"""Segundo paso: toma salas ya generadas (con el mínimo demostrado y de hasta 9 pisos) y les pone especiales POR PROPÓSITO con `salas_nuevas.exe --especializar`.
Sólo se queda con las salas donde cada especial resultó necesario (cambiarlo por un común cambia el resultado).
Uso: python herramientas/especializar_biblioteca.py rol=pesado [entrada=bibliotecas/salas_nuevas_final.jsonl] [salida=bibliotecas/salas_especiales_<rol>.jsonl] [niveles=media,dificil,pesadilla] [max_salas=60] [exe=tools/salas_nuevas.exe]"""
import json, os, subprocess, sys, time
RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
o = {'rol': 'pesado', 'entrada': 'bibliotecas/salas_nuevas_final.jsonl', 'niveles': 'media,dificil,pesadilla', 'max_salas': '60', 'exe': 'tools/salas_nuevas.exe', 'tope': '200000'}
for a in sys.argv[1:]:
    if '=' in a:
        k, v = a.split('=', 1); o[k] = v
salida = o.get('salida', 'bibliotecas/salas_especiales_%s.jsonl' % o['rol'])
exe = os.path.join(RAIZ, o['exe'])
niveles = o['niveles'].split(',')
salas = [json.loads(l) for l in open(os.path.join(RAIZ, o['entrada']), encoding='utf-8') if l.strip()]
cand = [d for d in salas if d.get('exacto') and d['meta'] <= 10 and d.get('nivel') in niveles and not any(b[3] not in 'pnf' for b in d['bloques'])]
cand = cand[:int(o['max_salas'])]
out = []
t0 = time.time()
for d in cand:
    t = 'meta %d\njugador %d %d %d\ncolgado 0 0 0\ntope 1500000\n' % (d['meta'], *d['jugador'])
    for b in d['bloques']:
        t += 'b %d %d %d %s\n' % tuple(b)
    r = subprocess.run([exe, '--especializar', 'rol=' + o['rol'], 'tipo=' + d['tipo'], 'tope=' + o['tope']], input=t, capture_output=True, text=True, timeout=600)
    try:
        j = json.loads(r.stdout.strip().splitlines()[-1])
    except Exception:
        continue
    if j.get('ok') is False:
        continue
    n = j.get('especiales', {}).get('h', 0)
    if n >= 1 and j.get('necesarios') == n:
        j['nivel_base'] = d['nivel']
        j['pasos_sin_especiales'] = d['pasos']
        out.append(j)
with open(os.path.join(RAIZ, salida), 'w', encoding='ascii') as f:
    for j in out:
        f.write(json.dumps(j) + '\n')
print('%d salas procesadas, %d con especiales necesarios (%.0f s)' % (len(cand), len(out), time.time() - t0))
for j in out[:12]:
    print('  %s h=%d: %d pesados, pasos %d -> %d (sin especiales %d), ganancias %s, complejidad %.0f' % (j['tipo'], j['meta'], j['especiales']['h'], j['pasos_sin_especiales'], j['pasos'], j['pasos_sin_especiales'], j['ganancias'], j.get('complejidad', 0)))
