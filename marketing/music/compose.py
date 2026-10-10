"""此生清单 · 宣传片配乐（程序合成）
D 大调，84 BPM，约 60 秒。五段：沉思 → 加速 → 发问 → 主题 → 尾声。
"""
import json
import numpy as np
from scipy.signal import fftconvolve, butter, sosfilt

SR = 44100
BPM = 84
BEAT = 60 / BPM
BAR = 4 * BEAT
TOTAL = 21 * BAR + 3.0           # 21 小节 + 混响尾巴
N = int(TOTAL * SR)
rng = np.random.default_rng(20261010)

BUF = {'A': [np.zeros(N), np.zeros(N)], 'B': [np.zeros(N), np.zeros(N)]}
CUR = ['A']


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def add(sig, t0, pan=0.0, gain=1.0):
    i = int(t0 * SR)
    if i >= N:
        return
    sig = sig[: N - i] * gain
    l = np.cos((pan + 1) * np.pi / 4)
    r = np.sin((pan + 1) * np.pi / 4)
    Lb, Rb = BUF[CUR[0]]
    Lb[i:i + len(sig)] += sig * l
    Rb[i:i + len(sig)] += sig * r


def lowpass(x, fc, order=2):
    return sosfilt(butter(order, fc, 'low', fs=SR, output='sos'), x)


def highpass(x, fc, order=2):
    return sosfilt(butter(order, fc, 'high', fs=SR, output='sos'), x)


def bandpass(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], 'band', fs=SR, output='sos'), x)


# ---------- 音色 ----------

def piano(m, dur, vel=0.6):
    """柔和的毡头钢琴：带非谐性的加法合成，高次谐波衰减更快"""
    f = hz(m)
    length = dur + 2.6
    t = np.arange(int(length * SR)) / SR
    base_tau = 2.4 * (261.6 / f) ** 0.4
    soft = 1.25 - vel
    out = np.zeros_like(t)
    B = 0.00035
    for n in range(1, 13):
        fn = n * f * np.sqrt(1 + B * n * n)
        if fn > 12000:
            break
        a = (1 / n ** 1.25) * np.exp(-(n - 1) * soft * 0.55)
        tau = base_tau / (1 + 0.45 * (n - 1))
        det = 1 + rng.normal(0, 0.0004)
        out += a * np.sin(2 * np.pi * fn * det * t + rng.uniform(0, 6.28)) * np.exp(-t / tau)
    att = np.minimum(1, t / 0.004)
    rel = np.where(t > dur, np.exp(-(t - dur) / 0.35), 1.0)
    out *= att * rel
    hammer = lowpass(rng.normal(0, 1, int(0.012 * SR)), 2500) * np.exp(-np.arange(int(0.012 * SR)) / (0.003 * SR))
    out[: len(hammer)] += hammer * 0.06 * vel
    return out * vel * 0.32


def bell(m, dur, vel=0.5):
    """钟琴般的高音点缀"""
    f = hz(m)
    t = np.arange(int((dur + 3) * SR)) / SR
    out = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t / 0.4)
           + 0.15 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t / 0.15))
    return out * np.exp(-t / 1.6) * np.minimum(1, t / 0.002) * vel * 0.18


def pad(ms, dur, vel=0.5, attack=1.4, release=1.6):
    """弦乐铺底：三个微失谐的锯齿波，低通，缓起缓收"""
    length = dur + release
    t = np.arange(int(length * SR)) / SR
    out = np.zeros_like(t)
    for m in ms:
        for cents in (-7, 0, 6):
            f = hz(m) * 2 ** (cents / 1200)
            vib = 1 + 0.0025 * np.sin(2 * np.pi * 4.6 * t + rng.uniform(0, 6.28))
            ph = 2 * np.pi * f * np.cumsum(vib) / SR
            for n in range(1, 9):
                out += np.sin(n * ph) / n * 0.33
    out = lowpass(out, 1800)
    env = np.minimum(1, t / attack) * np.where(t > dur, np.exp(-(t - dur) / (release / 3)), 1)
    return out * env * vel * 0.045


def bass(m, dur, vel=0.6):
    f = hz(m)
    t = np.arange(int((dur + 0.6) * SR)) / SR
    out = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t)
    env = np.minimum(1, t / 0.01) * np.exp(-t / 1.4) * np.where(t > dur, np.exp(-(t - dur) / 0.12), 1)
    return out * env * vel * 0.22


def kick(vel=0.6):
    t = np.arange(int(0.5 * SR)) / SR
    f = 48 + 70 * np.exp(-t / 0.035)
    out = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.18)
    return lowpass(out, 900) * vel * 0.55


def shaker(vel=0.4):
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    out = bandpass(rng.normal(0, 1, n), 5500, 11000) * np.exp(-t / 0.025) * np.minimum(1, t / 0.006)
    return out * vel * 0.10


# ---------- 和声与旋律 ----------
CH = {
    'D': [50, 57, 61, 66],   # Dmaj7
    'Bm': [47, 54, 57, 62],  # Bm7
    'G': [43, 50, 54, 59],   # Gmaj7
    'A': [45, 52, 57, 61],   # A
    'Asus': [45, 52, 57, 62],
}
ROOT = {'D': 38, 'Bm': 35, 'G': 31, 'A': 33, 'Asus': 33}
PROG = ['D', 'Bm', 'G', 'Asus']
markers = []


def bar_t(b, beat=0.0):        # b 从 1 开始
    return (b - 1) * BAR + beat * BEAT


# 第一段：沉思（1–4 小节）
markers.append({'t': 0.0, 'name': '引子·沉思'})
sparse = [(1, 0, 81, 2), (1, 2, 78, 2), (2, 0, 74, 2), (2, 2, 76, 2),
          (3, 0, 71, 2), (3, 2, 74, 1), (3, 3, 78, 1), (4, 0, 76, 3)]
for b, bt, m, d in sparse:
    add(piano(m, d * BEAT, 0.42), bar_t(b, bt), pan=0.25)
for b in range(1, 5):
    c = PROG[b - 1]
    add(pad(CH[c], BAR, 0.55), bar_t(b), pan=0)
    add(piano(ROOT[c] + 12, BAR, 0.38), bar_t(b), pan=-0.3)

# 第二段：加速（5–8 小节）：四分 → 八分 → 十六分，渐强，最后一刻戛然而止
markers.append({'t': bar_t(5), 'name': '加速'})
arp_bars = [
    (5, 'D', 1.0, [62, 66, 69, 73]),
    (6, 'Bm', 0.5, [59, 62, 66, 69, 71, 74, 78, 81]),
    (7, 'G', 0.25, [55, 59, 62, 66, 67, 71, 74, 78, 79, 78, 74, 71, 67, 66, 62, 59]),
    (8, 'A', 0.25, [57, 61, 64, 69, 73, 76, 81, 85, 69, 73, 76, 81, 85, 88, 93, 97]),
]
for b, c, step, notes in arp_bars:
    n = int(4 / step)
    for k in range(n):
        m = notes[k % len(notes)]
        prog = ((b - 5) * 4 + k * step) / 16
        add(piano(m, step * BEAT * 1.6, 0.35 + 0.4 * prog), bar_t(b, k * step), pan=-0.4 + 0.8 * (k / n))
    add(pad(CH[c], BAR, 0.55 + 0.25 * (b - 5)), bar_t(b))
    add(bass(ROOT[c], BAR * 0.9, 0.35 + 0.1 * (b - 5)), bar_t(b))
# 上升的气声，在第 8 小节末尾截断
rs = int(2 * BAR * SR)
t = np.arange(rs) / SR
noise = rng.normal(0, 1, rs)
riser = np.zeros(rs)
for i in range(0, rs, 2048):
    seg = noise[i:i + 2048]
    lo = 300 + 5000 * (i / rs) ** 2
    riser[i:i + len(seg)] = bandpass(seg, lo, min(lo * 3, 18000))
riser *= (t / t[-1]) ** 2.2 * 0.09
add(riser, bar_t(7))

CUT = bar_t(9)                      # 戛然而止
markers.append({'t': CUT, 'name': '静默·发问「我们，要做到什么？」'})

CUR[0] = 'B'
# 第三段：发问（9–10 小节）：一拍半静默后，一个低音和一声钟
add(piano(38, 2 * BAR, 0.5), CUT + 1.5 * BEAT, pan=-0.2)
add(piano(45, 2 * BAR, 0.4), CUT + 1.5 * BEAT, pan=0.1)
add(bell(86, 2.0, 0.55), CUT + 3.5 * BEAT, pan=0.3)
add(pad([50, 57, 62, 66], 1.6 * BAR, 0.35, attack=2.5), CUT + 2 * BEAT)

# 第四段：主题（11–18 小节）
markers.append({'t': bar_t(11), 'name': '主题·演示开始'})
main_prog = ['D', 'Bm', 'G', 'A', 'D', 'Bm', 'G', 'A']
melody = [
    (11, 0, 78, 1), (11, 1, 81, 1), (11, 2, 76, 2),
    (12, 0, 74, 2), (12, 2, 73, 1), (12, 3, 74, 1),
    (13, 0, 71, 1), (13, 1, 74, 1), (13, 2, 78, 2),
    (14, 0, 76, 1), (14, 1, 74, 1), (14, 2, 73, 2),
    (15, 0, 78, 1), (15, 1, 81, 1), (15, 2, 86, 2),
    (16, 0, 85, 1), (16, 1, 83, 1), (16, 2, 81, 2),
    (17, 0, 83, 1), (17, 1, 81, 1), (17, 2, 78, 1), (17, 3, 76, 1),
    (18, 0, 76, 2), (18, 2, 73, 1), (18, 3, 76, 1),
]
for b, bt, m, d in melody:
    add(piano(m, d * BEAT * 0.95, 0.66), bar_t(b, bt), pan=0.15)
for i, c in enumerate(main_prog):
    b = 11 + i
    ch = CH[c]
    patt = [ch[0], ch[1], ch[2], ch[3], ch[2], ch[1], ch[2], ch[3]]
    for k, m in enumerate(patt):
        add(piano(m, 0.5 * BEAT * 1.5, 0.36), bar_t(b, k * 0.5), pan=-0.35)
    add(pad(ch, BAR, 0.5), bar_t(b))
    add(bass(ROOT[c], BAR * 0.95, 0.55), bar_t(b))
    if b >= 13:
        for bt in (0, 2):
            add(kick(0.55), bar_t(b, bt))
        for k in range(8):
            add(shaker(0.5 if k % 2 else 0.3), bar_t(b, k * 0.5), pan=0.4)
    if b in (15, 17):
        add(bell(86 if b == 15 else 83, 1.5, 0.35), bar_t(b, 2), pan=0.35)

# 第五段：尾声（19–21 小节）
markers.append({'t': bar_t(19), 'name': '尾声·结尾字幕'})
outro = [('D', [(0, 74, 4)]), ('G', [(0, 78, 2), (2, 76, 2)]), ('D', [(0, 74, 4)])]
for i, (c, notes) in enumerate(outro):
    b = 19 + i
    for bt, m, d in notes:
        add(piano(m, d * BEAT, 0.55 - 0.08 * i), bar_t(b, bt), pan=0.15)
    ch = CH[c] if c != 'D' else [50, 57, 64, 66]   # 最后落在 D(add9)
    for k, m in enumerate(ch):
        add(piano(m, BAR * 1.2, 0.34 - 0.05 * i), bar_t(b, k * 0.25), pan=-0.3 + 0.2 * k)
    add(pad(ch, BAR * (1.6 if i == 2 else 1), 0.45 - 0.08 * i), bar_t(b))
    add(bass(ROOT[c], BAR, 0.4 - 0.08 * i), bar_t(b))
add(bell(93, 2.5, 0.3), bar_t(21, 2), pan=0.3)
markers.append({'t': bar_t(22), 'name': '结束'})

# ---------- 混响与母带 ----------
ir_len = int(2.6 * SR)
ti = np.arange(ir_len) / SR
irL = lowpass(rng.normal(0, 1, ir_len), 6000) * np.exp(-ti / 0.75)
irR = lowpass(rng.normal(0, 1, ir_len), 6000) * np.exp(-ti / 0.75)
irL[0] = irR[0] = 0
irL /= np.sqrt((irL ** 2).sum()); irR /= np.sqrt((irR ** 2).sum())
# 加速段在第 9 小节起点干声截断，只留一点混响尾巴，制造「戛然而止」
c0 = int(CUT * SR)
fade = int(0.025 * SR)
gate = np.ones(N); gate[c0:c0 + fade] = np.linspace(1, 0, fade); gate[c0 + fade:] = 0
AL, AR = BUF['A'][0] * gate, BUF['A'][1] * gate
BL, BR = BUF['B']
# 截断后，加速段的混响也在 0.45 秒内收掉，留出真正的静默
tail = np.ones(N); tf = int(0.45 * SR); tail[c0:c0 + tf] = np.linspace(1, 0, tf) ** 2; tail[c0 + tf:] = 0
wetAL = fftconvolve(AL, irL)[:N] * tail
wetAR = fftconvolve(AR, irR)[:N] * tail
wetBL = fftconvolve(BL, irL)[:N]
wetBR = fftconvolve(BR, irR)[:N]
mixL = 0.78 * (AL + BL) + 0.42 * (wetAL + wetBL)
mixR = 0.78 * (AR + BR) + 0.42 * (wetAR + wetBR)

mix = np.stack([mixL, mixR], axis=1)
mix = highpass(mix.T, 35).T
peak = np.max(np.abs(mix))
mix = mix / peak * 0.89
mix = np.tanh(mix * 1.15) / np.tanh(1.15)          # 柔和限幅
end = int((bar_t(22) + 2.6) * SR)
mix = mix[:end]
fo = int(2.0 * SR)
mix[-fo:] *= np.linspace(1, 0, fo)[:, None]

from scipy.io import wavfile
wavfile.write('lifewall-theme.wav', SR, (mix * 32767).astype(np.int16))
beats = [round(i * BEAT, 4) for i in range(int(len(mix) / SR / BEAT) + 1)]
json.dump({'bpm': BPM, 'beat': BEAT, 'bar': BAR, 'sections': markers, 'downbeats': [round((b - 1) * BAR, 3) for b in range(1, 23)]},
          open('beatmap.json', 'w'), ensure_ascii=False, indent=1)
print('length', len(mix) / SR)
print(json.dumps(markers, ensure_ascii=False))
