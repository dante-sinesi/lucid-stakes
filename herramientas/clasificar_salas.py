"""Clasifica las salas nuevas por nivel de dificultad y tipo, y dice qué falta para llegar a la composición objetivo.

Niveles por complejidad (bits): fácil < 60, media 60-110, difícil 110-180, pesadilla > 180.
Composición objetivo (por defecto): 40% fácil, 30% media, 20% difícil, 10% pesadilla; y 40% 3x3, 35% 5x3, 25% 8x3.
Las salas altas que todavía no tienen el mínimo demostrado no tienen complejidad medida: se estima con una regresión sobre las que sí la tienen (pasos, agarres y bloques distintos).

Uso:
  python herramientas/clasificar_salas.py estado [TOTAL=600]     -> tabla de lo que hay y lo que falta; escribe bibliotecas/sn_demanda.json
  python herramientas/clasificar_salas.py final [TOTAL=600]      -> arma bibliotecas/salas_base.jsonl con la composición objetivo
"""
import glob, json, os, random, sys, collections

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
NIVELES = ['facil', 'media', 'dificil', 'pesadilla']
PORC_NIVEL = {'facil': 0.40, 'media': 0.30, 'dificil': 0.20, 'pesadilla': 0.10}
PORC_TIPO = {'3x3': 0.40, '5x3': 0.35, '8x3': 0.25}


def nivel_de(c):
    return 'facil' if c < 60 else 'media' if c < 110 else 'dificil' if c < 180 else 'pesadilla'


def cargar_todas():
    vistas = {}
    for f in sorted(glob.glob(os.path.join(RAIZ, 'bibliotecas', 'sn_corridas', '*.jsonl'))):
        for l in open(f, encoding='utf-8', errors='ignore'):
            l = l.strip()
            if not l:
                continue
            try:
                d = json.loads(l)
                clave = d['tipo'] + '|' + str(d['meta']) + '|' + ';'.join(sorted('%d,%d,%d,%s' % tuple(b) for b in d['bloques']))
            except Exception:
                continue
            previa = vistas.get(clave)
            # se queda con la versión más completa (con complejidad medida y mínimo demostrado)
            if previa is None or (d.get('complejidad', 0) > 0 and previa.get('complejidad', 0) <= 0) or (d.get('exacto') and not previa.get('exacto')):
                vistas[clave] = d
    return list(vistas.values())


def ajustar_modelo(salas):
    """Mínimos cuadrados de complejidad ~ a*pasos + b*distintos sobre las salas medidas (dos coeficientes, para que no salgan negativos)."""
    medidas = [d for d in salas if d.get('complejidad', 0) > 0]
    if len(medidas) < 10:
        return (1.5, 0.0, 2.0)
    sxx = sum(d['pasos'] ** 2 for d in medidas); sxy = sum(d['pasos'] * d['distintos'] for d in medidas); syy = sum(d['distintos'] ** 2 for d in medidas)
    sxc = sum(d['pasos'] * d['complejidad'] for d in medidas); syc = sum(d['distintos'] * d['complejidad'] for d in medidas)
    det = sxx * syy - sxy * sxy
    if abs(det) < 1e-9:
        return (1.5, 0.0, 2.0)
    a = (sxc * syy - syc * sxy) / det
    c = (syc * sxx - sxc * sxy) / det
    return (max(a, 0.0), 0.0, max(c, 0.0))


def complejidad(d, modelo):
    if d.get('complejidad', 0) > 0:
        return d['complejidad'], True
    return max(0.0, modelo[0] * d['pasos'] + modelo[1] * d['agarres'] + modelo[2] * d['distintos']), False


def tabla(salas, modelo):
    t = collections.Counter()
    for d in salas:
        c, _ = complejidad(d, modelo)
        t[(nivel_de(c), d['tipo'])] += 1
    return t


def objetivo(total):
    return {(n, ty): round(total * PORC_NIVEL[n] * PORC_TIPO[ty]) for n in NIVELES for ty in PORC_TIPO}


def estado(total):
    salas = cargar_todas()
    modelo = ajustar_modelo(salas)
    t = tabla(salas, modelo)
    obj = objetivo(total)
    print('salas distintas: %d (con complejidad medida: %d); modelo para estimar: %.2f*pasos + %.2f*agarres + %.2f*distintos' % (len(salas), sum(1 for d in salas if d.get('complejidad', 0) > 0), *modelo))
    print('%-10s %s' % ('nivel', '   '.join('%s hay/falta' % ty for ty in PORC_TIPO)))
    demanda = []
    for n in NIVELES:
        fila = []
        for ty in PORC_TIPO:
            hay, quiero = t[(n, ty)], obj[(n, ty)]
            falta = max(0, quiero - hay)
            fila.append('%3d/%3d' % (hay, falta))
            if falta > 0:
                demanda.append({'nivel': n, 'tipo': ty, 'falta': falta})
        print('%-10s %s' % (n, '        '.join(fila)))
    json.dump(demanda, open(os.path.join(RAIZ, 'bibliotecas', 'sn_demanda.json'), 'w'))
    return len(demanda)


def final(total):
    salas = cargar_todas()
    modelo = ajustar_modelo(salas)
    obj = objetivo(total)
    celdas = collections.defaultdict(list)
    for d in salas:
        c, medida = complejidad(d, modelo)
        d['_cx'] = c; d['_medida'] = medida
        celdas[(nivel_de(c), d['tipo'])].append(d)
    elegidas = []
    random.seed(7)
    for (n, ty), quiero in obj.items():
        cand = celdas.get((n, ty), [])
        # primero las que tienen el mínimo demostrado; dentro de cada grupo se reparten las alturas
        cand.sort(key=lambda d: (not d.get('exacto'), random.random()))
        por_altura = collections.defaultdict(list)
        for d in cand: por_altura[d['meta']].append(d)
        elegidas_celda = []
        alturas = sorted(por_altura)
        while len(elegidas_celda) < quiero and any(por_altura[h] for h in alturas):
            for h in alturas:
                if por_altura[h] and len(elegidas_celda) < quiero:
                    elegidas_celda.append(por_altura[h].pop(0))
        elegidas += elegidas_celda
        print('%-10s %s: %d de %d' % (n, ty, len(elegidas_celda), quiero))
    ruta = os.path.join(RAIZ, 'bibliotecas', 'salas_base.jsonl')
    with open(ruta, 'w', encoding='ascii') as f:
        for d in elegidas:
            nivel = nivel_de(d['_cx'])
            d['nivel'] = nivel
            d['complejidad_estimada'] = not d['_medida']
            d.pop('_cx'); d.pop('_medida')
            f.write(json.dumps(d) + '\n')
    print('biblioteca final: %d salas en %s' % (len(elegidas), ruta))


if __name__ == '__main__':
    total = 600
    for a in sys.argv[2:]:
        if a.startswith('TOTAL='): total = int(a[6:])
    if len(sys.argv) > 1 and sys.argv[1] == 'final':
        final(total)
    else:
        estado(total)
