"""Suma a la biblioteca del juego (data/salas_torre.jsonl) las salas que dejó `generador_salas.py` (o el .exe portable) en una o más carpetas.
Las salas que ya estaban no se tocan ni cambian de id; las nuevas se agregan al final (sin repetidas: mismos bloques y mismo jugador), con id, nivel por complejidad y pisos.
Las salas nuevas que mueven pocos bloques distintos se dejan afuera (filtro de salas sencillas, docs/generador.md): `filtro=A` (por omisión: menos de 2 bloques distintos), `filtro=B` (menos de 2 o de un tercio de los pisos) o `filtro=ninguno`.
Uso: python herramientas/sumar_salas.py carpeta [carpeta ...] [salida=data/salas_torre.jsonl] [filtro=A|B|ninguno]
Después: herramientas/revisar_forma_salas.py y tests/unitarios/test_paquete_salas.gd sobre el resultado (ver docs/generador.md)."""
import glob, json, os, sys
RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
salida = 'data/salas_torre.jsonl'
filtro = 'A'
carpetas = []
for a in sys.argv[1:]:
    if a.startswith('salida='):
        salida = a[7:]
    elif a.startswith('filtro='):
        filtro = a[7:]
    else:
        carpetas.append(a)
NIVELES = ['facil', 'media', 'dificil', 'pesadilla']


def nivel_de(c):
    return 'facil' if c < 60 else 'media' if c < 110 else 'dificil' if c < 180 else 'pesadilla'


HUELLA = {'3x3': (0, 0, 3, 3), '5x3': (3, 0, 5, 3), '8x3': (0, 0, 8, 3)}


def giro_de(d):
    """1 si la salida no está en la punta contraria a la entrada (las salas con giro, que salen de las bases de `sn_corridas/giro_*`; el generador las marca 0 al especializarlas)."""
    if d['tipo'] == '3x3':
        return int(d.get('giro', 0))
    x0, _, w, _ = HUELLA[d['tipo']]
    e = [b for b in d['bloques'] if b[3] == 'p'][0]
    s = [b for b in d['bloques'] if b[3] == 'f'][0]
    return 0 if abs(e[0] - s[0]) == w - 1 else 1


def sencilla(d):
    """¿Se descarta por mover pocos bloques distintos? (igual que `Torre.minimo_distintos`: A = 2; B = el mayor entre 2 y un tercio de los pisos)"""
    pisos = int(d['meta']) - 1
    minimo = 2 if filtro == 'A' else max(2, int(pisos / 3.0 + 0.5)) if filtro == 'B' else 0
    return int(d.get('distintos', 99)) < minimo


def clave(d):
    return (d['tipo'], tuple(int(v) for v in d['jugador']), tuple(sorted((int(b[0]), int(b[1]), int(b[2]), b[3]) for b in d['bloques'])))


ruta = os.path.join(RAIZ, salida)
actuales = [json.loads(l) for l in open(ruta, encoding='utf-8') if l.strip()]
vistas = {clave(d) for d in actuales}
siguiente = max(d['id'] for d in actuales) + 1
nuevas = []
sencillas = 0
for car in carpetas:
    for f in sorted(glob.glob(os.path.join(car, '*.jsonl'))):
        for l in open(f, encoding='ascii'):
            if not l.strip():
                continue
            d = json.loads(l)
            k = clave(d)
            if k in vistas:
                continue
            vistas.add(k)
            if sencilla(d):
                sencillas += 1
                continue
            d['nivel'] = nivel_de(d.get('complejidad', 0))
            d['pisos'] = int(d['meta']) - 1
            d['giro'] = giro_de(d)
            d['id'] = siguiente
            siguiente += 1
            nuevas.append(d)
with open(ruta, 'w', encoding='ascii', newline='\n') as f:   # (finales de línea LF: lo pide .gitattributes)
    for d in actuales + nuevas:
        f.write(json.dumps(d) + '\n')
print('antes: %d salas, nuevas: %d (dejadas afuera por sencillas, filtro %s: %d), ahora: %d -> %s' % (len(actuales), len(nuevas), filtro, sencillas, len(actuales) + len(nuevas), salida))
cats = ['base', 'pinchos', 'pesado', 'agrietado', 'hielo', 'trampolin', 'bomba', 'mixta']
todas = actuales + nuevas
print('%-10s %5s | %s' % ('categoria', 'total', '  '.join('%-9s' % n for n in NIVELES)))
for c in cats:
    sub = [d for d in todas if d['categoria'] == c]
    print('%-10s %5d | %s' % (c, len(sub), '  '.join('%-9d' % sum(1 for d in sub if d['nivel'] == n) for n in NIVELES)))
