"""Genera los sonidos de la mesa de tarot (especificacion §7).

Reproduce la sintesis del prototipo elegido por Samuel el 07-oct (version
«para altavoz de movil», con sus mejoras y Bastos en bronce): mismas notas,
envolventes y sala, sin muestras de terceros. Escribe OGG mono en
`arcanum_app/assets/sounds/mesa/`.

Lo que en el prototipo era aleatorio y aqui no puede serlo queda fijo: el ruido
del papel y la sala usan una semilla. La variacion de cada disparo (tono ±5 %,
volumen ±3 dB) la pone la app al reproducir (`TableSound`).

Uso:  python tools/build_mesa_sonidos.py
Necesita numpy y ffmpeg con libvorbis.
"""
from __future__ import annotations

import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

SR = 24000  # el armonico mas alto (5,4 x 1174 Hz) es 6,3 kHz: sobra margen
OUT = Path(__file__).resolve().parents[1] / 'arcanum_app' / 'assets' / 'sounds' / 'mesa'

# re dorico pentatonico (D F G A C D F G A D F), como el prototipo
SCALE = [293.66, 349.23, 392, 440, 523.25, 587.33, 698.46, 783.99, 880, 1046.5, 1174.66]
ROOM_SECONDS = 1.6
ROOM_WET = .3

# grados que puede dar una carta menor al desvelarse: 2..7 (ver TableSound)
REVEAL_DEGREES = range(2, 8)
# grados del acorde: la tonica (0), los Mayores (0 y 5), los menores (2..7) y
# el acorde sin cartas desveladas (0, 3, 5, 6, 8)
CHORD_DEGREES = range(0, 9)
SLOT_BELLS = range(0, len(SCALE))
VEILED = .25

rng = np.random.default_rng(7)


def note(i: int) -> float:
    return SCALE[max(0, min(len(SCALE) - 1, i))]


class Mix:
    """Un sonido: pista seca y envio a la sala, como el bus del prototipo."""

    def __init__(self, seconds: float):
        n = int(SR * seconds)
        self.dry = np.zeros(n)
        self.wet = np.zeros(n)

    def _place(self, sig: np.ndarray, t0: float, wet: float):
        i = int(t0 * SR)
        j = min(len(self.dry), i + len(sig))
        self.dry[i:j] += sig[:j - i]
        self.wet[i:j] += sig[:j - i] * wet

    @staticmethod
    def _env(a: float, d: float, peak: float) -> np.ndarray:
        # rampas exponenciales de .0001 a peak y de vuelta, como WebAudio
        na, nd = max(1, int(a * SR)), max(1, int(d * SR))
        up = .0001 * (peak / .0001) ** (np.arange(na) / na)
        down = peak * (.0001 / peak) ** (np.arange(nd) / nd)
        return np.concatenate([up, down, np.zeros(int(.1 * SR))])

    def osc(self, t0, f, a, d, peak, wet=1., kind='sine', glide=None):
        env = self._env(a, d, peak)
        n = len(env)
        if glide:
            m = int((a + d) * SR)
            freq = np.full(n, glide, dtype=float)
            freq[:m] = f * (glide / f) ** (np.arange(m) / m)
        else:
            freq = np.full(n, f, dtype=float)
        phase = 2 * np.pi * np.cumsum(freq) / SR
        wave_ = np.sin(phase) if kind == 'sine' else (2 / np.pi) * np.arcsin(np.sin(phase))
        self._place(wave_ * env, t0, wet)

    def bell(self, t0, f, d, peak, bright=1.):
        self.osc(t0, f, .004, d, peak)
        self.osc(t0, f * 2.76, .004, d * .45, peak * .32 * bright)
        self.osc(t0, f * 5.4, .004, d * .2, peak * .12 * bright)

    def brush(self, t0, d, peak, f=1400.):
        n = int(SR * (d + .1))
        x = rng.uniform(-1, 1, n)
        x = biquad(biquad(x, 'highpass', 260), 'lowpass', f)
        env = self._env(d * .35, d * .65, peak)[:n]
        self._place(x[:len(env)] * env, t0, .25)

    def wood(self, t0, f, peak):
        self.osc(t0, f, .002, .09, peak, .2, 'triangle', f * .8)
        self.brush(t0, .03, peak * .6, 2600)

    def render(self, room: np.ndarray) -> np.ndarray:
        # convolucion por FFT: la directa son miles de millones de operaciones
        n = len(self.wet) + len(room) - 1
        size = 1 << (n - 1).bit_length()
        wet = np.fft.irfft(np.fft.rfft(self.wet, size) * np.fft.rfft(room, size), size)
        return self.dry + wet[:len(self.dry)] * ROOM_WET


def biquad(x: np.ndarray, kind: str, f0: float, q: float = 1.12) -> np.ndarray:
    """Filtro RBJ de segundo orden (el BiquadFilter de WebAudio)."""
    w = 2 * np.pi * f0 / SR
    alpha = np.sin(w) / (2 * q)
    c = np.cos(w)
    if kind == 'lowpass':
        b = [(1 - c) / 2, 1 - c, (1 - c) / 2]
    else:
        b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]
    a = [1 + alpha, -2 * c, 1 - alpha]
    b = [v / a[0] for v in b]
    a1, a2 = a[1] / a[0], a[2] / a[0]
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.
    for i, xi in enumerate(x):
        yi = b[0] * xi + b[1] * x1 + b[2] * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, xi, y1, yi
        y[i] = yi
    return y


def room() -> np.ndarray:
    # respuesta al impulso generada, normalizada como el ConvolverNode
    n = int(SR * ROOM_SECONDS)
    ir = rng.uniform(-1, 1, n) * (1 - np.arange(n) / n) ** 3.2
    rms = np.sqrt(np.mean(ir ** 2))
    return ir * (.00125 / rms) * (44100 / SR)


# ---------- los sonidos ----------

def bronze(m: Mix, f: float, bright: float):
    m.osc(0, f, .002, 1.1, .035)
    m.osc(0, f * 2.32, .002, .6, .016 * bright)
    m.osc(0, f * 4.25, .002, .25, .008 * bright)


def cups(m: Mix, f: float, bright: float):
    m.osc(0, f, .02, 2.2, .03, 1)
    m.osc(0, f * 1.006, .02, 2.2, .022 * (.5 if bright < 1 else 1), 1)


def swords(m: Mix, f: float, bright: float, deg: int):
    m.bell(0, note(deg + 2), 1.1, .04, bright)


def coins(m: Mix, f: float, bright: float):
    m.osc(0, f, .002, .55, .05, .4)
    m.osc(0, f * 3.9, .002, .12, .015 * bright, .2)


def build() -> dict[str, np.ndarray]:
    ir = room()
    out: dict[str, np.ndarray] = {}

    def make(name: str, seconds: float, fill):
        m = Mix(seconds + ROOM_SECONDS)
        fill(m)
        out[name] = m.render(ir)

    for deg in REVEAL_DEGREES:
        f = note(deg)
        for veiled in (False, True):
            br, sfx = (VEILED, '_v') if veiled else (1., '')
            make(f'bastos_{deg}{sfx}', 1.2, lambda m: bronze(m, f, br))
            make(f'copas_{deg}{sfx}', 2.3, lambda m: cups(m, f, br))
            make(f'espadas_{deg}{sfx}', 1.2, lambda m: swords(m, f, br, deg))
            make(f'oros_{deg}{sfx}', .7, lambda m: coins(m, f, br))

    def bowl(m: Mix, rev: bool):
        br = VEILED if rev else 1.
        for f in (293.66, 295.8):
            m.osc(0, f, .06, 3.6, .05)
        m.osc(0, 293.66 * 2.71, .08, 3, .02)
        m.bell(.3, note(2 if rev else 4), 2.5, .02, br)

    make('mayor', 3.8, lambda m: bowl(m, False))
    make('mayor_v', 3.8, lambda m: bowl(m, True))

    for deg in SLOT_BELLS:
        make(f'campana_{deg}', 1.1, lambda m: m.bell(0, note(deg), 1, .014))
    for deg in CHORD_DEGREES:
        def pad(m: Mix, f=note(deg)):
            m.osc(0, f, .9, 2.6, .022)
            m.osc(0, f * 1.004, .9, 2.6, .016)
        make(f'acorde_{deg}', 3.6, pad)

    make('encajar', .2, lambda m: m.wood(0, 392, .07))
    make('sacar', .35, lambda m: m.brush(0, .24, .05))

    def cut(m: Mix):
        m.brush(0, .22, .05)
        m.bell(.06, note(1), 1.4, .02)
    make('cortar', 1.5, cut)

    def riffle(m: Mix):
        # cascada: 24 roces cada vez mas juntos (de 70 a 18 ms) y tres campanitas
        at = 0.
        for i in range(24):
            m.brush(at, .05, .026 * (1 - i / 40), 1600 + i * 30)
            at += .07 - .052 * (i / 23)
        for i, n in enumerate((0, 2, 4)):
            m.bell(at + .08 + i * .09, note(4 + n), 1.1, .013)
    make('barajar', 2.6, riffle)

    def seal(m: Mix):
        m.osc(0, 220, .02, .6, .06, .4)
        m.osc(0, 440, .02, .4, .025, .4)
    make('sellar', .7, seal)

    def crack(m: Mix):
        m.osc(0, 900, .002, .08, .05, .2, 'sine', 240)
        for i, n in enumerate((8, 6, 4, 2)):
            m.bell(.1 + i * .08, note(n), 1.2, .018)
    make('romper', 1.6, crack)
    return out


def trim(x: np.ndarray, floor_db: float = -54) -> np.ndarray:
    """Corta la cola por debajo del suelo y la apaga en 20 ms."""
    floor = 10 ** (floor_db / 20)
    loud = np.nonzero(np.abs(x) > floor)[0]
    end = min(len(x), (loud[-1] if len(loud) else 0) + int(.02 * SR))
    y = x[:end].copy()
    fade = min(len(y), int(.02 * SR))
    y[-fade:] *= np.linspace(1, 0, fade)
    return y


def main() -> int:
    sounds = build()
    # una sola ganancia para todos: se conserva el equilibrio del prototipo y
    # el mas fuerte queda a -3 dBFS (sitio para que suenen varios a la vez)
    gain = 10 ** (-3 / 20) / max(np.max(np.abs(s)) for s in sounds.values())
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob('*.ogg'):
        old.unlink()
    total = 0
    with tempfile.TemporaryDirectory() as tmp:
        for name, s in sorted(sounds.items()):
            pcm = (np.clip(trim(s * gain), -1, 1) * 32767).astype('<i2')
            src = Path(tmp) / f'{name}.wav'
            with wave.open(str(src), 'wb') as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(SR)
                w.writeframes(pcm.tobytes())
            dst = OUT / f'{name}.ogg'
            subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(src), '-c:a', 'libvorbis',
                            '-q:a', '4', str(dst)], check=True)
            total += dst.stat().st_size
    print(f'{len(sounds)} sonidos, {total / 1024:.0f} KB en {OUT}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
