"""Junta todo lo generado en UN paquete de salas para probar en el juego: las salas base (sin especiales), las de cada rol y las mixtas.
Sin repetidas (mismos bloques, mismo jugador), con un id, la categoría (base, pinchos, ..., mixta) y el nivel por complejidad (fácil <60, media 60-110, difícil 110-180, pesadilla >180).
Uso: python herramientas/armar_paquete.py [salida=bibliotecas/paquete_salas.jsonl]
Imprime una tabla con la cantidad por categoría, tamaño y nivel."""
import glob, json, os, sys
RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
salida = 'bibliotecas/paquete_salas.jsonl'
for a in sys.argv[1:]:
    if a.startswith('salida='): salida = a[7:]
NIVELES = ['facil', 'media', 'dificil', 'pesadilla']


def nivel_de(c):
    return 'facil' if c < 60 else 'media' if c < 110 else 'dificil' if c < 180 else 'pesadilla'


def leer(ruta):
    if not os.path.exists(os.path.join(RAIZ, ruta)):
        return []
    return [json.loads(l) for l in open(os.path.join(RAIZ, ruta), encoding='utf-8') if l.strip()]


fuentes = [('base', 'bibliotecas/salas_base.jsonl')]
for f in sorted(glob.glob(os.path.join(RAIZ, 'bibliotecas', 'sn_corridas', 'giro_*.jsonl'))):   # (salas 5x3 y 8x3 con la salida a 90 grados de la entrada)
    fuentes.append(('base', os.path.relpath(f, RAIZ)))
for rol in ['pinchos', 'pesado', 'agrietado', 'hielo', 'trampolin', 'bomba']:
    fuentes.append((rol, 'bibliotecas/salas_especiales_%s.jsonl' % rol))
for f in sorted(glob.glob(os.path.join(RAIZ, 'bibliotecas', 'salas_mixtas*.jsonl*'))):
    fuentes.append(('mixta', os.path.relpath(f, RAIZ)))
vistas = set()
paquete = []
for cat, ruta in fuentes:
    for d in leer(ruta):
        clave = (d['tipo'], tuple(d['jugador']), tuple(sorted((b[0], b[1], b[2], b[3]) for b in d['bloques'])))
        if clave in vistas:
            continue
        vistas.add(clave)
        d['categoria'] = cat
        if cat != 'base' or 'nivel' not in d:
            d['nivel'] = nivel_de(d.get('complejidad', 0))
        d['pisos'] = int(d['meta']) - 1
        paquete.append(d)
for i, d in enumerate(paquete):
    d['id'] = i + 1
with open(os.path.join(RAIZ, salida), 'w', encoding='ascii') as f:
    for d in paquete:
        f.write(json.dumps(d) + '\n')
print('paquete: %d salas -> %s' % (len(paquete), salida))
cats = ['base', 'pinchos', 'pesado', 'agrietado', 'hielo', 'trampolin', 'bomba', 'mixta']
print('%-10s %5s | %s | %s' % ('categoria', 'total', '  '.join('%-9s' % n for n in NIVELES), '3x3 5x3 8x3'))
for c in cats:
    sub = [d for d in paquete if d['categoria'] == c]
    if not sub:
        continue
    print('%-10s %5d | %s | %3d %3d %3d' % (c, len(sub), '  '.join('%-9d' % sum(1 for d in sub if d['nivel'] == n) for n in NIVELES), *[sum(1 for d in sub if d['tipo'] == t) for t in ('3x3', '5x3', '8x3')]))
alt = {}
for d in paquete:
    alt[d['pisos']] = alt.get(d['pisos'], 0) + 1
print('pisos:', ' '.join('%d:%d' % (k, alt[k]) for k in sorted(alt)))
mix = {}
for d in paquete:
    if d['categoria'] == 'mixta':
        k = len(d.get('roles', []))
        mix[k] = mix.get(k, 0) + 1
print('mixtas por cantidad de especiales:', mix)
