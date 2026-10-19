"""Prueba de las Cuatro Estaciones de Vivaldi (dominio público) en el estilo chiptune del juego: onda de pulso para el violín, arpegios de pulso fino, triángulo para el bajo
y percusión de ruido. Es un ARREGLO de los temas principales, escrito a mano (no una transcripción nota por nota): sirve para escuchar cómo quedaría el estilo.
Uso:  python herramientas/musica/vivaldi_prueba.py [carpeta_salida]     (genera primavera, verano, otono e invierno en .wav y .mp3 si hay ffmpeg)
"""
import os
import re
import subprocess
import sys
import wave

import numpy as np

SR = 44100
NOTE = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def midi(name):
    m = re.match(r'([A-G])([#b]?)(-?\d)', name)
    n = NOTE[m.group(1)] + (1 if m.group(2) == '#' else -1 if m.group(2) == 'b' else 0)
    return 12 * (int(m.group(3)) + 1) + n


def freq(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def parse(text):
    """'E5:1 G#5:.5 r:.5 @v0.6' -> [(midi|None, beats, vol)]"""
    out = []
    vol = 1.0
    for tok in text.split():
        if tok.startswith('@v'):
            vol = float(tok[2:])
            continue
        name, dur = tok.split(':')
        out.append((None if name == 'r' else midi(name), float(dur), vol))
    return out


def beats_of(notes):
    return sum(d for _, d, _ in notes)


def chord_notes(name):
    """'Gm' 'D7' 'Bb' 'F#dim' -> [raíz, tercera, quinta(, séptima)] en semitonos sobre la raíz y el pitch de la raíz (octava 0)."""
    m = re.match(r'([A-G][#b]?)(m|dim)?(7)?', name)
    root = NOTE[m.group(1)[0]] + (1 if '#' in m.group(1) else -1 if 'b' in m.group(1) else 0)
    q = m.group(2)
    third = 3 if q in ('m', 'dim') else 4
    fifth = 6 if q == 'dim' else 7
    tones = [0, third, fifth] + ([10] if m.group(3) else [])
    return root, tones


# ---------- síntesis ----------
def phase_of(f):
    return np.cumsum(f) / SR


def pulse(f, duty):
    return np.where((phase_of(f) % 1.0) < duty, 1.0, -1.0)


def tri(f):
    return 2.0 * np.abs(2.0 * (phase_of(f) % 1.0) - 1.0) - 1.0


def env(n, att=0.004, rel=0.03, sus=0.85):
    e = np.ones(n) * sus
    a = max(1, int(att * SR))
    r = max(1, min(int(rel * SR), n // 2))
    e[:a] = np.linspace(0, sus, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e


def render(notes, bpm, voice, total):
    spb = 60.0 / bpm
    buf = np.zeros(int(total * spb * SR) + SR)
    t = 0.0
    for m, d, v in notes:
        if m is not None:
            n = int(d * spb * SR * (0.96 if voice != 'bass' else 0.9))
            if n > 8:
                f = np.full(n, freq(m))
                if voice == 'lead':
                    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * np.arange(n) / SR) * np.minimum(1, np.arange(n) / (0.12 * SR))
                    w = pulse(f * vib, 0.25) * 0.8 + pulse(f * vib * 1.005, 0.5) * 0.2
                    amp = 0.30
                elif voice == 'harm':
                    w = pulse(f, 0.125)
                    amp = 0.13
                else:
                    w = tri(f)
                    amp = 0.34
                s = int(t * spb * SR)
                buf[s:s + n] += w * env(n) * amp * v
        t += d
    return buf


def arps(chords_per_bar, beats_per_bar, step, octave=4, pattern='updown'):
    """Arpegio de pulso fino: cada compás con su acorde (o dos acordes separados por coma)."""
    out = []
    for bar in chords_per_bar:
        chs = bar.split(',')
        per = beats_per_bar / len(chs)
        for ch in chs:
            root, tones = chord_notes(ch)
            base = 12 * (octave + 1) + root
            ladder = [base + t for t in tones] + [base + 12 + tones[0]]
            seq = ladder + ladder[-2:0:-1] if pattern == 'updown' else ladder
            k = 0
            for _ in range(int(per / step)):
                out.append((seq[k % len(seq)], step, 1.0))
                k += 1
    return out


def bass(chords_per_bar, beats_per_bar, pattern):
    """pattern: lista de (desplazamiento_en_beats, duración, 'r'|'5'|'8') dentro del compás."""
    out = []
    for bar in chords_per_bar:
        chs = bar.split(',')
        per = beats_per_bar / len(chs)
        for ci, ch in enumerate(chs):
            root, tones = chord_notes(ch)
            base = 12 * 3 + root
            t = 0.0
            for off, dur, kind in pattern:
                if off >= per:
                    continue
                pitch = base + (7 if kind == '5' else 12 if kind == '8' else 0)
                if off > t:
                    out.append((None, off - t, 1.0))
                out.append((pitch, min(dur, per - off), 1.0))
                t = off + min(dur, per - off)
            if t < per:
                out.append((None, per - t, 1.0))
    return out


def drums(bars, beats_per_bar, pattern, bpm, total):
    """pattern: cadena por corchea, 'K' bombo, 'S' redoblante, 'h' hi-hat, '.' nada."""
    spb = 60.0 / bpm
    buf = np.zeros(int(total * spb * SR) + SR)
    step = 0.5
    rng = np.random.default_rng(3)
    for b in range(bars):
        for i, ch in enumerate(pattern):
            if ch == '.':
                continue
            s = int(((b * beats_per_bar) + i * step) * spb * SR)
            if ch == 'K':
                n = int(0.16 * SR)
                tt = np.arange(n) / SR
                f = 130 * np.exp(-tt * 18) + 40
                w = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 20) * 0.55
            elif ch == 'S':
                n = int(0.13 * SR)
                tt = np.arange(n) / SR
                w = rng.uniform(-1, 1, n) * np.exp(-tt * 28) * 0.28
            else:
                n = int(0.04 * SR)
                tt = np.arange(n) / SR
                w = np.diff(rng.uniform(-1, 1, n + 1)) * np.exp(-tt * 90) * 0.18
            buf[s:s + n] += w[:max(0, len(buf) - s)][:n]
    return buf


def echo(x, delay=0.19, fb=0.28, mix=0.35):
    d = int(delay * SR)
    y = x.copy()
    for k in range(1, 4):
        if d * k < len(x):
            y[d * k:] += x[:-d * k] * (fb ** k) * mix
    return y


def mix(parts, total_len):
    out = np.zeros(total_len)
    for p in parts:
        out[:min(len(p), total_len)] += p[:total_len]
    peak = np.max(np.abs(out)) or 1.0
    return out / peak * 0.89


def write(path, x):
    st = np.stack([x, np.roll(x, 90)], axis=1)   # un poquito de ancho estéreo
    data = (np.clip(st, -1, 1) * 32767).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# ---------- utilidades de composición ----------
def ladder(names):
    return names


def run(scale, i0, i1, dur=0.25):
    idx = range(i0, i1 + 1) if i1 >= i0 else range(i0, i1 - 1, -1)
    return ' '.join('%s:%g' % (scale[i], dur) for i in idx)


def trill(a, b, beats, dur=0.125):
    n = int(beats / dur)
    return ' '.join('%s:%g' % (a if i % 2 == 0 else b, dur) for i in range(n))


def build(name, bpm, bpb, lead_text, chords, drum_pattern, bass_pattern, harm_step):
    lead = parse(lead_text)
    total = beats_of(lead)
    bars = int(round(total / bpb))
    assert len(chords) == bars, '%s: %d compases de melodía y %d acordes' % (name, bars, len(chords))
    harm = arps(chords, bpb, harm_step)
    bs = bass(chords, bpb, bass_pattern)
    parts = [echo(render(lead, bpm, 'lead', total)), render(harm, bpm, 'harm', total), render(bs, bpm, 'bass', total), drums(bars, bpb, drum_pattern, bpm, total)]
    n = int(total * 60.0 / bpm * SR) + int(1.2 * SR)
    return mix(parts, n)


# ---------- las cuatro ----------
def primavera():
    E = ['E4', 'F#4', 'G#4', 'A4', 'B4', 'C#5', 'D#5', 'E5', 'F#5', 'G#5', 'A5', 'B5', 'C#6', 'D#6', 'E6']
    th = 'E5:1 G#5:.5 G#5:.5 G#5:1 A5:.5 G#5:.5 F#5:1 G#5:.5 F#5:.5 E5:2'
    rit = '@v1 ' + th + ' @v.55 ' + th + ' @v1 ' + (run(E, 7, 14) + ' ' + run(E, 14, 7)) + ' ' + (run(E, 7, 14) + ' ' + run(E, 14, 7)) + ' ' + trill('B5', 'C#6', 4, .25) + ' E6:.5 D#6:.5 E6:.5 B5:.5 G#5:1 E5:1'
    rit_c = ['E', 'B', 'E', 'B', 'E', 'E', 'B', 'E']
    birds = []
    for bar in range(4):
        hi, lo = [('B6', 'A6'), ('C#7', 'B6'), ('B6', 'A6'), ('D#7', 'C#7')][bar]
        birds.append('%s r:.5 C#7:.25 B6:.25 r:1 %s' % (trill(hi, lo, 1), trill(lo, hi, 1)))
    B = ['B4', 'C#5', 'D#5', 'E5', 'F#5', 'G#5', 'A#5', 'B5']
    descend = ' '.join(['%s:.25' % n for n in ['B5', 'A5', 'G#5', 'F#5', 'E5', 'D#5', 'C#5', 'B4']])
    ep_text = ' '.join(birds) + ' ' + ' '.join([descend + ' ' + descend] * 4)
    ep_c = ['B', 'B', 'E', 'B', 'B', 'F#', 'B', 'E']
    storm = '@v.8 ' + ' '.join(['G#4:.125'] * 32) * 1 + ' ' + ' '.join(['G#4:.125'] * 32) + ' ' + ' '.join(['G#4:.125'] * 32) + ' ' + ' '.join('%s:.125' % n for n in ['G#4', 'B4', 'E5', 'G#5', 'B5', 'E6', 'G#6', 'E6'] * 4)
    storm_c = ['C#m', 'C#m', 'G#', 'E']
    text = rit + ' ' + ep_text + ' ' + storm + ' @v1 ' + rit + ' E5:4'
    chords = rit_c + ep_c + storm_c + rit_c + ['E']
    return build('primavera', 132, 4, text, chords, 'K.hhShhK.', [(0, 1, 'r'), (1, 1, '5'), (2, 1, 'r'), (3, 1, '5')], 0.5)


def verano():
    G = ['G4', 'A4', 'Bb4', 'C5', 'D5', 'Eb5', 'F5', 'G5', 'A5', 'Bb5', 'C6', 'D6', 'Eb6', 'F6', 'G6']
    GD = [n.replace('F5', 'F#5').replace('F6', 'F#6') for n in G]

    def storm_bar(ch):
        root, tones = chord_notes(ch)
        base = 12 * 5 + root - 12
        lad = [base + tones[0], base + tones[1], base + tones[2], base + 12, base + 12 + tones[1], base + 12 + tones[2], base + 24]
        seq = [0, 1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1, 0, 1, 2, 3]
        names = ['%s:.25' % note_name(lad[i]) for i in seq]
        return ' '.join(names)
    a_c = ['Gm', 'Gm', 'D', 'D', 'Gm', 'Cm', 'D', 'Gm']
    a_text = ' '.join(storm_bar(c) for c in a_c)
    b_c = ['Cm', 'D', 'Gm', 'Eb', 'Cm', 'D', 'D', 'Gm']
    b_text = []
    for i, c in enumerate(b_c):
        sc = GD if c == 'D' else G
        seq = list(range(14, -1, -1)) + [0] if i % 2 == 0 else list(range(0, 15)) + [14]
        b_text.append(' '.join('%s:.25' % sc[k] for k in seq))
    pound = ' '.join(['G4:.5 G5:.5'] * 8)
    c_c = ['Gm', 'Gm', 'D', 'Gm', 'Gm']
    c_text = pound + ' ' + ' '.join(['D5:.5 D6:.5'] * 4) + ' ' + ' '.join(['G4:.5 G5:.5'] * 4) + ' G5:4'
    text = a_text + ' ' + ' '.join(b_text) + ' ' + c_text + ' ' + a_text + ' ' + c_text
    chords = a_c + b_c + c_c + a_c + c_c
    return build('verano', 150, 4, text, chords, 'KhShKhSh', [(0, .5, 'r'), (.5, .5, 'r'), (1, .5, '5'), (1.5, .5, '5'), (2, .5, 'r'), (2.5, .5, 'r'), (3, .5, '5'), (3.5, .5, '8')], 0.25)


def note_name(m):
    names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    return '%s%d' % (names[m % 12], m // 12 - 1)


def otono():
    F = ['F4', 'G4', 'A4', 'Bb4', 'C5', 'D5', 'E5', 'F5', 'G5', 'A5', 'Bb5', 'C6']
    th = 'C5:1 C5:.5 A4:.5 F4:1 C5:1 C5:.5 A4:.5 F4:1 D5:1 D5:.5 Bb4:.5 G4:1 C5:2 r:1'
    th2 = 'A4:.5 Bb4:.5 C5:.5 D5:.5 E5:.5 F5:.5 G5:1 E5:.5 C5:.5 F5:1 C5:.5 A4:.5 Bb4:.5 A4:.5 G4:.5 F4:.5 G4:1 C5:1 F5:2 r:1'
    chords = ['F', 'F', 'Bb,C', 'F', 'F', 'Bb', 'C', 'F']
    text = th + ' ' + th + ' ' + th2 + ' ' + th2.replace('G5:1', 'A5:1') + ' ' + ' '.join(['%s:.25' % n for n in ['F5', 'E5', 'D5', 'C5', 'Bb4', 'A4', 'G4', 'F4']]) + ' F5:2 r:1 F5:3'
    # compases: cada bloque de 3 pulsos
    total = beats_of(parse(text))
    bars = int(round(total / 3))
    chords = (['F', 'F', 'Bb', 'C'] * 2 + ['F', 'Bb', 'C', 'F'] * 2 + ['F', 'C', 'F'])[:bars]
    while len(chords) < bars:
        chords.append('F')
    return build('otono', 138, 3, text, chords, 'K.hhh.', [(0, 1, 'r'), (1, 1, '5'), (2, 1, '5')], 0.5)


def invierno():
    shiver = ' '.join(['F4:.25'] * 16)
    jag = 'C5:.75 Db5:.25 C5:.5 Bb4:.5 Ab4:.5 G4:.5 F4:1 F4:.25 G4:.25 Ab4:.25 Bb4:.25 C5:1 Db5:.5 C5:.5 Bb4:1 Ab4:1 G4:.5 Ab4:.5 Bb4:.5 C5:.5 Db5:2'
    Fm = ['F4', 'G4', 'Ab4', 'Bb4', 'C5', 'Db5', 'Eb5', 'F5', 'G5', 'Ab5', 'Bb5', 'C6', 'Db6', 'Eb6', 'F6']
    runs = run(Fm, 0, 14, .25) + ' ' + run(Fm, 14, 0, .25) + ' ' + run(Fm, 0, 14, .25) + ' ' + run(Fm, 14, 7, .25) + ' C6:.5 Db6:.5 C6:.5 Ab5:.5 F5:2 C6:4'
    text = shiver + ' ' + shiver + ' ' + jag + ' ' + shiver + ' ' + runs + ' ' + shiver + ' ' + jag + ' F5:4'
    total = beats_of(parse(text))
    bars = int(round(total / 4))
    base = ['Fm', 'Fm', 'Fm', 'Cm', 'Db', 'C', 'Fm', 'Fm']
    chords = []
    for i in range(bars):
        chords.append(base[i % len(base)])
    return build('invierno', 124, 4, text, chords, 'K.hhS.h.', [(0, 1, 'r'), (1, 1, 'r'), (2, 1, '5'), (3, 1, 'r')], 0.25)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else 'audio_prueba'
    os.makedirs(out, exist_ok=True)
    for name, fn in [('1_primavera', primavera), ('2_verano', verano), ('3_otono', otono), ('4_invierno', invierno)]:
        x = fn()
        wav = os.path.join(out, name + '.wav')
        write(wav, x)
        mp3 = os.path.join(out, name + '.mp3')
        try:
            subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-b:a', '192k', mp3], check=True)
            os.remove(wav)
            print(mp3, '%.0f s' % (len(x) / SR))
        except Exception:
            print(wav, '%.0f s' % (len(x) / SR))


if __name__ == '__main__':
    main()
