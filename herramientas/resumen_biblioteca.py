"""Resumen de una biblioteca de salas nuevas: composición por nivel y tipo, y métricas medias por celda.
Uso: python herramientas/resumen_biblioteca.py [archivo.jsonl]   (por defecto bibliotecas/salas_nuevas_final.jsonl)"""
import json, os, sys, collections, statistics as st
ruta = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'bibliotecas', 'salas_nuevas_final.jsonl')
salas = [json.loads(l) for l in open(ruta, encoding='utf-8') if l.strip()]
NIV = ['facil', 'media', 'dificil', 'pesadilla']
TIP = ['3x3', '5x3', '8x3']
n = len(salas)
print('%d salas en %s' % (n, ruta))
print('\nComposición (porcentaje del total):')
print('%-10s %6s %6s %6s %8s' % ('nivel', *TIP, 'total'))
for niv in NIV:
    fila = [sum(1 for d in salas if d.get('nivel') == niv and d['tipo'] == t) for t in TIP]
    print('%-10s %6d %6d %6d %6d (%.0f%%)' % (niv, *fila, sum(fila), 100.0 * sum(fila) / n))
tot = [sum(1 for d in salas if d['tipo'] == t) for t in TIP]
print('%-10s %6d %6d %6d %6d' % ('total', *tot, n))
print('porcentaje por tipo: ' + ', '.join('%s %.0f%%' % (t, 100.0 * c / n) for t, c in zip(TIP, tot)))
print('\nMétricas por nivel y tipo (pasos mín-med-máx | pisos | distintos/piso | complejidad | mínimo demostrado):')
for niv in NIV:
    for t in TIP:
        g = [d for d in salas if d.get('nivel') == niv and d['tipo'] == t]
        if not g:
            continue
        pas = [d['pasos'] for d in g]; pis = [d['meta'] - 1 for d in g]
        cx = [d.get('complejidad', 0) for d in g if d.get('complejidad', 0) > 0]
        prob = sum(1 for d in g if d.get('exacto'))
        print('%-10s %s n=%3d | pasos %d-%d-%d | pisos %d-%d | %.2f | %s | %d de %d demostrado' % (
            niv, t, len(g), min(pas), st.median(pas), max(pas), min(pis), max(pis),
            st.mean(d['distintos'] / (d['meta'] - 1) for d in g),
            ('%.0f-%.0f-%.0f bits' % (min(cx), st.median(cx), max(cx))) if cx else 'estimada',
            prob, len(g)))
print('\nSalas con el mínimo demostrado: %d de %d; con complejidad estimada (no medida): %d' % (
    sum(1 for d in salas if d.get('exacto')), n, sum(1 for d in salas if d.get('complejidad_estimada'))))
