"""EL generador de salas: genera sin parar (o hasta una hora) salas base y salas con especiales (pinchos, pesado, agrietado, hielo -con líneas largas-, trampolín, bomba y mixtas que
encadenan dos o tres), especializando salas base con `tools/salas.exe --especializar` (ver docs/generador.md). Varios procesos a la vez.
Lo generado va a bibliotecas/generadas/<categoria>_<n>.jsonl y el avance a bibliotecas/generadas/registro.txt (nada toca data/: después se suma con sumar_salas.py).
Uso: python herramientas/generador_salas.py [--hasta 08:00 | --minutos 30] [--procesos 7] [--tipos 3x3,5x3,8x3] [--hmax N] [--nivel 1-5] [--base 45] [--roles hielo=60,bomba=40]
Sin --hasta ni --minutos no tiene límite: se corta creando `parar.txt` en la carpeta de salida (mata las salas en curso) o cerrando la ventana.
Portable: herramientas/armar_portable.bat arma bibliotecas/generador_portable/ (generador_salas.exe + salas.exe + paquete_salas.jsonl) para correrlo en otra computadora sin instalar nada."""
import argparse, glob, json, os, random, subprocess, sys, time, datetime, math

if getattr(sys, 'frozen', False):   # el .exe portable (herramientas/armar_portable.bat): salas.exe y lo que genera viven al lado
    RAIZ = os.path.dirname(os.path.abspath(sys.executable))
    EXE = os.path.join(RAIZ, 'salas.exe')
    SALIDA = os.path.join(RAIZ, 'salida')
    BASES = os.path.join(RAIZ, 'paquete_salas.jsonl')
else:
    RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    EXE = os.path.join(RAIZ, 'tools', 'salas.exe')
    SALIDA = os.path.join(RAIZ, 'bibliotecas', 'generadas')
    BASES = os.path.join(RAIZ, 'bibliotecas', 'paquete_salas.jsonl')
ALTURAS = {'3x3': [5, 6, 7, 8, 9], '5x3': [6, 8, 9, 10, 12, 13, 15], '8x3': [8, 10, 12, 14, 16, 18, 20, 22, 24]}
NIVELES = [1, 2, 1, 3, 2, 4, 3, 5]   # (se reparte entre los cinco niveles: más fáciles que difíciles)
# los roles con su peso (el hielo pesa más: pidió líneas largas) y el tope del largo de la línea de hielo por tamaño
ROLES = [('hielo', 28), ('pinchos', 12), ('pesado', 12), ('agrietado', 14), ('trampolin', 14), ('bomba', 14)]
PARAR = os.path.join(SALIDA, 'parar.txt')   # si existe, cada proceso termina la sala que está generando y para
TOPE_HIELO = {'3x3': 3, '5x3': 5, '8x3': 6}


def config_base(tipo, h, nivel):
    """La configuración del generador de una sala base según su tamaño, altura y nivel (1 muy fácil a 5 pesadilla)."""
    grande = tipo != '3x3'
    extras_base = 2.3 * h if grande else 1.3 * h + 1
    f = {1: 0.15, 2: 0.4, 3: 0.7, 4: 0.9, 5: 1.0}[nivel]
    extras = int(max(1, math.ceil(extras_base * f)))
    prof = {1: 8, 2: 20, 3: 40, 4: 60, 5: 80}[nivel]
    climb = {1: 0, 2: 20, 3: 100, 4: 250, 5: 500}[nivel]
    exacto = 1 if h <= 9 else 0
    tope = 200000 if h <= 9 else 60000
    ef = 1 if (nivel <= 2 or grande) else 2
    dist = 1 if nivel <= 2 else int(math.floor(0.6 * (h - 1)))
    refinar = 0 if h <= 9 else 3000000
    return ['tipo=%s' % tipo, 'h=%d' % h, 'extras=%d' % extras, 'ef=%d' % ef, 'dist=1', 'dist_exactos=%d' % dist, 'climb=%d' % climb, 'tope_climb=%d' % tope,
            'tope_eval=%d' % tope, 'tope_nivel=%d' % tope, 'prof=%d' % prof, 'cand=300', 'ancho=12', 'pre=30', 'exacto=%d' % exacto, 'refinar=%d' % refinar, 'riesgo=1']


def a_texto(d):
    """Una sala (jsonl) en el texto que lee `leer_sala` del ejecutable."""
    lineas = ['meta %d' % d['meta'], 'jugador %d %d %d' % tuple(int(v) for v in d['jugador']), 'colgado %d 0 %d' % (int(d['colgado'][0]), int(d['colgado'][1])), 'tope 200000']
    for b in d['bloques']:
        lineas.append('b %d %d %d %s' % (int(b[0]), int(b[1]), int(b[2]), b[3]))
    return '\n'.join(lineas) + '\n'


def nivel_de(c):
    return 'facil' if c < 60 else 'media' if c < 110 else 'dificil' if c < 180 else 'pesadilla'


def correr(args, entrada=None, env=None, espera=900):
    """Corre salas.exe y devuelve su salida; si pasa `espera` segundos o aparece `parar.txt`, lo mata y devuelve ''."""
    pr = subprocess.Popen([EXE] + args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env, cwd=RAIZ)
    inicio = time.time()
    primera = True
    while True:
        try:
            salida, _ = pr.communicate(input=entrada if primera else None, timeout=2)
            return salida
        except subprocess.TimeoutExpired:
            primera = False
            if time.time() - inicio > espera or os.path.exists(PARAR):
                pr.kill()
                pr.communicate()
                return ''


def guardar(archivo, d):
    with open(archivo, 'a', encoding='ascii') as f:
        f.write(json.dumps(d) + '\n')


def trabajar(idx, fin, base_inicial, cont, cfg):
    rng = random.Random(time.time_ns() ^ (idx * 7919))
    k = idx * 3
    semilla = 5000 + idx * 100000 + int(time.time()) % 90000
    tipos = cfg['tipos']
    pool = [d for d in base_inicial if d['tipo'] in tipos]   # (con --tipos, también las especiales se arman solo sobre esos tamaños)
    pesos_tipo = [{'3x3': 40, '5x3': 35, '8x3': 25}[t] for t in tipos]
    pesos_rol = cfg['roles']
    while datetime.datetime.now() < fin and not os.path.exists(PARAR):
        if rng.random() < cfg['base'] / 100.0 or not pool:   # una sala base nueva
            tipo = rng.choices(tipos, weights=pesos_tipo)[0]
            alturas = [a for a in ALTURAS[tipo] if a <= min(cfg['hmax'], 20 if tipo == '8x3' else 15)] or [min(ALTURAS[tipo])]
            h = rng.choice(alturas)
            nivel = cfg['nivel'] or NIVELES[k % 8]
            k += 1
            semilla += 1
            args_gen = config_base(tipo, h, nivel) + ['wd=12', 'evaluar=16', 'temp=3', 'salto=3', 'n=1', 'seed=%d' % semilla]
            salida = correr(['--gen'] + args_gen)
            for l in salida.splitlines():
                if l.strip().startswith('{'):
                    try:
                        d = json.loads(l)
                    except ValueError:
                        continue
                    d['nivel'] = nivel_de(d.get('complejidad', 0))
                    d['categoria'] = 'base'
                    guardar(os.path.join(SALIDA, 'base_%d.jsonl' % idx), d)
                    pool.append(d)
                    cont['base'] = cont.get('base', 0) + 1
            continue
        # una sala con especiales: una base (o una ya especializada, para las mixtas) y uno a tres roles encadenados
        d = rng.choice(pool)
        n_roles = rng.choices([1, 2, 3], weights=[62, 28, 10])[0]
        roles = []
        actual = d
        for paso in range(n_roles):
            rol = rng.choices([r for r, _ in pesos_rol], weights=[w for _, w in pesos_rol])[0]
            if rol in roles and rol != 'hielo':
                continue
            env = dict(os.environ)
            tipo = actual['tipo']
            if rol == 'hielo' and rng.random() < 0.75:   # (casi siempre una línea larga: de 3 hasta el tope del tamaño)
                env['SALAS_LARGO'] = str(rng.randint(3, TOPE_HIELO[tipo]))
            semilla += 1
            salida = correr(['--especializar', 'rol=' + rol, 'tipo=' + tipo, 'max=4', 'ganancia=2', 'tope=200000', 'wd=12', 'seed=%d' % semilla], a_texto(actual), env, 600)
            nueva = None
            for l in salida.splitlines():
                if l.strip().startswith('{'):
                    try:
                        j = json.loads(l)
                    except ValueError:
                        continue
                    if j.get('ok', True) is not False and 'bloques' in j:
                        nueva = j
            if nueva is None:
                break
            roles.append(rol)
            nueva['nivel_base'] = d.get('nivel', 'facil')
            nueva['roles'] = roles[:]
            nueva['nivel'] = nivel_de(nueva.get('complejidad', 0))
            actual = nueva
            cat = roles[0] if len(roles) == 1 else 'mixta'
            nueva['categoria'] = cat
            guardar(os.path.join(SALIDA, '%s_%d.jsonl' % (cat, idx)), nueva)
            cont[cat] = cont.get(cat, 0) + 1
            if rol == 'hielo':
                cont['hielo_largo'] = cont.get('hielo_largo', 0) + (1 if int(nueva.get('especiales', {}).get('i', 0)) >= 3 else 0)
    return cont


def principal():
    ap = argparse.ArgumentParser()
    ap.add_argument('--hasta', default='')
    ap.add_argument('--minutos', type=float, default=0)
    ap.add_argument('--procesos', type=int, default=7)
    ap.add_argument('--tipos', default='3x3,5x3,8x3', help='tamaños a generar, separados por coma')
    ap.add_argument('--hmax', type=int, default=99, help='altura máxima de las salas base (en niveles)')
    ap.add_argument('--nivel', type=int, default=0, help='un nivel fijo para las salas base (1 muy fácil a 5 pesadilla); 0 las reparte')
    ap.add_argument('--base', type=int, default=45, help='porcentaje de salas base nuevas (el resto son salas con especiales)')
    ap.add_argument('--roles', default='', help='pesos de los especiales, por ejemplo hielo=60,bomba=40 (los que no se nombran no salen); por omisión, el reparto de siempre')
    a = ap.parse_args()
    roles = ROLES
    if a.roles:
        roles = [(x.split('=')[0], int(x.split('=')[1]) if '=' in x else 1) for x in a.roles.split(',') if x]
        desconocidos = [r for r, _ in roles if r not in dict(ROLES)]
        if desconocidos:
            sys.exit('rol desconocido: %s (los que hay: %s)' % (', '.join(desconocidos), ', '.join(r for r, _ in ROLES)))
    tipos = [t for t in a.tipos.split(',') if t in ALTURAS]
    if not tipos:
        sys.exit('tipos desconocidos: hay 3x3, 5x3 y 8x3')
    cfg = {'tipos': tipos, 'hmax': a.hmax, 'nivel': a.nivel, 'base': a.base, 'roles': roles}
    ahora = datetime.datetime.now()
    if a.minutos > 0:
        fin = ahora + datetime.timedelta(minutes=a.minutos)
    elif a.hasta:
        h, m = [int(v) for v in a.hasta.split(':')]
        fin = ahora.replace(hour=h, minute=m, second=0, microsecond=0)
        if fin <= ahora:
            fin += datetime.timedelta(days=1)
    else:
        fin = datetime.datetime.max   # sin límite horario
    os.makedirs(SALIDA, exist_ok=True)
    base = []
    ruta = BASES
    if os.path.exists(ruta):
        for l in open(ruta, encoding='utf-8'):
            if l.strip():
                d = json.loads(l)
                if d.get('categoria') == 'base':
                    base.append(d)
    registro = os.path.join(SALIDA, 'registro.txt')
    if os.path.exists(PARAR):
        os.remove(PARAR)
    hasta = 'hasta las %s' % fin.strftime('%H:%M') if fin != datetime.datetime.max else 'sin límite horario (parar.txt para cortar)'
    with open(registro, 'a', encoding='utf-8') as f:
        f.write('%s: arranca con %d procesos %s (%d salas base de partida)\n' % (ahora.strftime('%d/%m %H:%M'), a.procesos, hasta, len(base)))
    import multiprocessing as mp
    procs = []
    for i in range(a.procesos):
        p = mp.Process(target=_proceso, args=(i, fin, base, cfg))
        p.start()
        procs.append(p)
    ultimo = 0.0
    espera = 60 if a.minutos and a.minutos < 20 else 600
    while any(p.is_alive() for p in procs):
        time.sleep(5)
        if time.time() - ultimo >= espera:
            ultimo = time.time()
            with open(registro, 'a', encoding='utf-8') as f:
                f.write('%s: %s\n' % (datetime.datetime.now().strftime('%H:%M'), _resumen()))
    with open(registro, 'a', encoding='utf-8') as f:
        f.write('%s: terminó. %s\n' % (datetime.datetime.now().strftime('%d/%m %H:%M'), _resumen()))


def _proceso(idx, fin, base, cfg):
    trabajar(idx, fin, base, {}, cfg)   # (el resumen se saca de los archivos)


def _resumen():
    partes = []
    for cat in ['base', 'hielo', 'pinchos', 'pesado', 'agrietado', 'trampolin', 'bomba', 'mixta']:
        n = 0
        largo = 0
        for f in glob.glob(os.path.join(SALIDA, cat + '_*.jsonl')):
            for l in open(f, encoding='ascii'):
                if l.strip():
                    n += 1
                    if cat == 'hielo' and '"i": 3' in l or cat == 'hielo' and any('"i": %d' % q in l for q in (4, 5, 6)):
                        largo += 1
        partes.append('%s %d%s' % (cat, n, (' (%d con línea de 3 o más)' % largo) if cat == 'hielo' else ''))
    return ', '.join(partes)


if __name__ == '__main__':
    import multiprocessing
    multiprocessing.freeze_support()
    principal()
