"""Las Cuatro Estaciones de Vivaldi (dominio público) transcriptas nota por nota —desde las partituras en MIDI de Mutopia Project, ver fuentes/— y tocadas con el sintetizador
chiptune del juego: el solista es un pulso con vibrato y eco, los violines y la viola son pulsos finos y el violonchelo (el bajo) un triángulo.
Uso:  python herramientas/musica/render_estaciones.py [carpeta_juego] [carpeta_mp3]
  - carpeta_juego (por defecto audio/music): menu.ogg (Primavera), torre.ogg (Verano), casino.ogg (Otoño) y pruebas.ogg (Invierno): los tres movimientos de cada una, en bucle
  - carpeta_mp3 (por defecto audio_prueba): lo mismo en .mp3 para escuchar
Necesita ffmpeg en el PATH. La partitura de cada movimiento se identifica por su contenido (ver MOVIMIENTOS)."""
import os
import subprocess
import sys
import wave

import numpy as np

from midi_leer import leer

SR = 44100
AQUI = os.path.dirname(os.path.abspath(__file__))

# estación -> (pista del juego, [archivos de los tres movimientos en orden])
MOVIMIENTOS = {
    'primavera': ('menu', ['spring/spring-score.mid', 'spring/spring-score-1.mid', 'spring/spring-score-2.mid']),
    'verano': ('torre', ['summer/summer-score.mid', 'summer/summer-score-1.mid', 'summer/summer-score-2.mid']),
    'otono': ('casino', ['autumn/autumn-score.mid', 'autumn/autumn-score-1.mid', 'autumn/autumn-score-2.mid']),
    'invierno': ('pruebas', ['winter/winter-score.mid', 'winter/winter-score-1.mid', 'winter/winter-score-2.mid']),
}
PAUSA = 2.5   # segundos de silencio entre movimientos
VELOCIDAD = 1.0   # 1 = el tempo del MIDI; 0,8 = un 20 % más lento (sólo estira el tiempo, la afinación no cambia)


def hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def fase(f):
    return np.cumsum(f) / SR


def pulso(f, duty):
    return np.where((fase(f) % 1.0) < duty, 1.0, -1.0)


def triangulo(f):
    return 2.0 * np.abs(2.0 * (fase(f) % 1.0) - 1.0) - 1.0


def envolvente(n, ataque=0.005, rel=0.04, decae=2.5):
    t = np.arange(n) / SR
    e = (0.78 + 0.22 * np.exp(-t * decae))
    a = max(1, int(ataque * SR))
    r = max(1, min(int(rel * SR), n // 2))
    e[:a] *= np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e


VOCES = {
    # rol: (onda, ancho de pulso, volumen, vibrato)
    'solo': ('pulso', 0.25, 0.30, True),
    'violin1': ('pulso', 0.125, 0.11, False),
    'violin2': ('pulso', 0.5, 0.09, False),
    'viola': ('pulso', 0.25, 0.09, False),
    'cello': ('triangulo', 0.0, 0.26, False),
}


def tocar(nota, voz, buf):
    onda, ancho, vol, vibrato = VOCES[voz]
    n = int(nota['d'] * SR * 0.97)
    s = int(nota['t'] * SR)
    if n < 16 or s >= len(buf):
        return
    f = np.full(n, hz(nota['n']))
    if vibrato:
        k = np.minimum(1.0, np.arange(n) / (0.15 * SR))
        f = f * (1 + 0.0045 * np.sin(2 * np.pi * 5.6 * np.arange(n) / SR) * k)
    if onda == 'pulso':
        w = pulso(f, ancho)
        if voz == 'solo':
            w = w * 0.8 + pulso(f * 1.004, 0.5) * 0.2
    else:
        w = triangulo(f)
    v = (0.55 + 0.45 * nota['v'] / 127.0) * vol
    fin = min(len(buf), s + n)
    buf[s:fin] += (w * envolvente(n, decae=(1.2 if voz == 'cello' else 2.5)) * v)[:fin - s]


def eco(x, delay=0.19, fb=0.30, mezcla=0.30):
    d = int(delay * SR)
    y = x.copy()
    for k in range(1, 4):
        if d * k < len(x):
            y[d * k:] += x[:-d * k] * (fb ** k) * mezcla
    return y


def render_movimiento(path):
    m = leer(path)
    notas = m['notas']
    for n in notas:
        n['t'] /= VELOCIDAD
        n['d'] /= VELOCIDAD
    total = max(n['t'] + n['d'] for n in notas) + 1.5
    nombres = {i: nm.strip().lower() for i, nm in enumerate(m['pistas'])}
    capas = {k: np.zeros(int(total * SR) + 1) for k in VOCES}
    for n in notas:
        voz = {'solo': 'solo', 'violinone': 'violin1', 'violintwo': 'violin2', 'viola': 'viola', 'cello': 'cello'}.get(nombres.get(n['pista'], ''))
        if voz:
            tocar(n, voz, capas[voz])
    capas['solo'] = eco(capas['solo'])
    capas['violin1'] = eco(capas['violin1'], 0.23, 0.2, 0.15)
    return sum(capas.values()), total


def a_wav(path, x):
    st = np.stack([x, np.roll(x, 110)], axis=1)
    data = (np.clip(st, -1, 1) * 32767).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def main():
    global VELOCIDAD
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    opciones = [a for a in sys.argv[1:] if a.startswith('--')]
    solo_previa = '--solo-previa' in opciones
    sufijo = ''
    for o in opciones:
        if o.startswith('--tempo='):
            VELOCIDAD = float(o.split('=')[1])
            sufijo = '_tempo%d' % round(VELOCIDAD * 100)
    juego = args[0] if len(args) > 0 else 'audio/music'
    previa = args[1] if len(args) > 1 else 'audio_prueba'
    os.makedirs(juego, exist_ok=True)
    os.makedirs(previa, exist_ok=True)
    for estacion, (pista, archivos) in MOVIMIENTOS.items():
        partes = []
        for a in archivos:
            x, dur = render_movimiento(os.path.join(AQUI, 'fuentes', a))
            partes.append(x)
            print('   %s: %.0f s' % (a, dur))
        silencio = np.zeros(int(PAUSA * SR))
        todo = np.concatenate([np.concatenate([p, silencio]) for p in partes])
        # un solo volumen para toda la pista: el pico real (percentil alto) a 0,85 y un límite suave
        escala = 0.85 / max(1e-6, np.percentile(np.abs(todo), 99.7))
        todo = np.tanh(todo * escala * 0.9) / np.tanh(0.9)
        todo *= 0.5 / max(1e-6, np.max(np.abs(todo)))   # fondo: el pico queda a -6 dB (la música del juego no tiene que tapar los efectos)
        wav = os.path.join(previa, 'tmp_%s.wav' % estacion)
        a_wav(wav, todo)
        nombre_mp3 = {'primavera': '1_primavera', 'verano': '2_verano', 'otono': '3_otono', 'invierno': '4_invierno'}[estacion]
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-b:a', '192k', os.path.join(previa, nombre_mp3 + sufijo + '_completa.mp3')], check=True)
        if not solo_previa:
            subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '3', os.path.join(juego, pista + '.ogg')], check=True)
        os.remove(wav)
        print('%s -> %s.ogg  (%.1f min)' % (estacion, pista, len(todo) / SR / 60))


if __name__ == '__main__':
    main()
