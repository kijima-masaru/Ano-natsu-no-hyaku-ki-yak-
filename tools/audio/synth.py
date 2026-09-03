"""合成の基本関数群（波形は float32、44.1 kHz、モノは shape (n,)、ステレオは (n, 2)）。

方針（docs/AUDIO_SPEC.md）：
- 発生源：正弦・倍音・FM・パルス列・ノイズ（白／ピンク／ブラウン）
- 整形：包絡（ADSR・指数減衰）、フィルタ（Butterworth の LPF/HPF/BPF/notch、共鳴 biquad、時間変化 LPF）
- 群れ：粒状合成（蝉・虫・雨・砂利）。ループ長を指定すると境界をまたぐ粒を折り返して撒く
- 空間：合成 IR の畳み込み残響、定位、非相関化
すべて numpy / scipy のみ。乱数は呼び出し側が numpy.random.Generator を渡す。
"""
from __future__ import annotations

import numpy as np
from scipy import signal

SR = 44100


# ── 基本 ──

def seconds(n: int) -> float:
    return n / SR


def n_samples(sec: float) -> int:
    return int(round(sec * SR))


def t_axis(sec: float) -> np.ndarray:
    return np.arange(n_samples(sec), dtype=np.float64) / SR


def db(x: float) -> float:
    """dB → 線形倍率"""
    return float(10.0 ** (x / 20.0))


def silence(sec: float, stereo: bool = False) -> np.ndarray:
    n = n_samples(sec)
    return np.zeros((n, 2), np.float32) if stereo else np.zeros(n, np.float32)


def to_stereo(x: np.ndarray) -> np.ndarray:
    if x.ndim == 2:
        return x
    return np.stack([x, x], axis=1)


def to_mono(x: np.ndarray) -> np.ndarray:
    return x if x.ndim == 1 else x.mean(axis=1)


def fit(x: np.ndarray, n: int) -> np.ndarray:
    """長さ n に切り詰め／ゼロ詰め"""
    if len(x) >= n:
        return x[:n]
    pad = n - len(x)
    return np.concatenate([x, np.zeros((pad,) + x.shape[1:], x.dtype)])


def mix(*parts: np.ndarray, length: int | None = None) -> np.ndarray:
    """複数の波形を加算。長さは最長（または指定）に合わせ、モノとステレオが混ざればステレオ"""
    if length is None:
        length = max(len(p) for p in parts)
    stereo = any(p.ndim == 2 for p in parts)
    out = np.zeros((length, 2) if stereo else (length,), np.float64)
    for p in parts:
        q = to_stereo(p) if stereo else p
        out += fit(q.astype(np.float64), length)
    return out.astype(np.float32)


def place(base: np.ndarray, part: np.ndarray, at_sec: float, gain: float = 1.0) -> np.ndarray:
    """base の at_sec 秒の位置に part を加算（はみ出しは切る）。base を書き換えて返す"""
    start = n_samples(at_sec)
    if start >= len(base) or start < 0:
        return base
    stereo = base.ndim == 2
    q = to_stereo(part) if stereo else to_mono(part)
    end = min(len(base), start + len(q))
    base[start:end] += (q[: end - start] * gain).astype(base.dtype)
    return base


# ── 発生源 ──

def sine(freq: float, sec: float, phase: float = 0.0) -> np.ndarray:
    return np.sin(2 * np.pi * freq * t_axis(sec) + phase).astype(np.float32)


def sine_fm(freq: float, sec: float, mod_hz: float, depth_hz: float, phase: float = 0.0) -> np.ndarray:
    """ゆっくりした周波数変調つき正弦（ドローンの揺れ）"""
    t = t_axis(sec)
    inst = freq + depth_hz * np.sin(2 * np.pi * mod_hz * t)
    ph = 2 * np.pi * np.cumsum(inst) / SR + phase
    return np.sin(ph).astype(np.float32)


def harmonics(freq: float, sec: float, amps: list[float], detune_cents: float = 0.0, rng: np.random.Generator | None = None) -> np.ndarray:
    """倍音列。amps[k] は (k+1) 倍音の振幅。detune_cents で各倍音をわずかに散らす"""
    t = t_axis(sec)
    out = np.zeros_like(t)
    for k, a in enumerate(amps):
        if a == 0:
            continue
        cents = 0.0 if rng is None or detune_cents == 0 else rng.uniform(-detune_cents, detune_cents)
        f = freq * (k + 1) * (2 ** (cents / 1200.0))
        ph = 0.0 if rng is None else rng.uniform(0, 2 * np.pi)
        out += a * np.sin(2 * np.pi * f * t + ph)
    return out.astype(np.float32)


def fm(carrier: float, sec: float, ratio: float, index: float, index_decay: float = 0.0) -> np.ndarray:
    """FM 合成。index_decay > 0 で変調指数が指数減衰（金属的なアタック）"""
    t = t_axis(sec)
    idx = index * (np.exp(-index_decay * t) if index_decay > 0 else 1.0)
    return np.sin(2 * np.pi * carrier * t + idx * np.sin(2 * np.pi * carrier * ratio * t)).astype(np.float32)


def pulse_train(rate_hz: float, sec: float, width: float = 0.5) -> np.ndarray:
    t = t_axis(sec)
    return np.where((t * rate_hz) % 1.0 < width, 1.0, -1.0).astype(np.float32)


def white(sec: float, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n_samples(sec)).astype(np.float32)


def pink(sec: float, rng: np.random.Generator) -> np.ndarray:
    """Voss-McCartney 近似ではなく、白色を 1/f に整形する IIR 近似（Paul Kellet）"""
    w = rng.standard_normal(n_samples(sec))
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    a = [1, -2.494956002, 2.017265875, -0.522189400]
    return (signal.lfilter(b, a, w) * 3.5).astype(np.float32)


def brown(sec: float, rng: np.random.Generator) -> np.ndarray:
    w = rng.standard_normal(n_samples(sec))
    x = np.cumsum(w)
    x = x - np.convolve(x, np.ones(2048) / 2048, mode="same")  # ふらつきを除く
    return (x / (np.abs(x).max() + 1e-9)).astype(np.float32)


# ── 包絡 ──

def adsr(sec: float, a: float, d: float, s: float, r: float) -> np.ndarray:
    n = n_samples(sec)
    na, nd, nr = n_samples(a), n_samples(d), n_samples(r)
    ns = max(0, n - na - nd - nr)
    env = np.concatenate([
        np.linspace(0, 1, max(na, 1)),
        np.linspace(1, s, max(nd, 1)),
        np.full(ns, s),
        np.linspace(s, 0, max(nr, 1)),
    ])
    return fit(env.astype(np.float32), n)


def exp_decay(sec: float, rate: float, attack: float = 0.002) -> np.ndarray:
    """アタック後に指数減衰（rate は 1/秒）"""
    t = t_axis(sec)
    env = np.exp(-rate * t)
    na = n_samples(attack)
    if na > 0:
        env[:na] *= np.linspace(0, 1, na)
    return env.astype(np.float32)


def fade(x: np.ndarray, fade_in: float = 0.0, fade_out: float = 0.0) -> np.ndarray:
    y = x.astype(np.float32).copy()
    ni, no = n_samples(fade_in), n_samples(fade_out)
    if ni > 0:
        ramp = np.linspace(0, 1, ni, dtype=np.float32)
        y[:ni] = (y[:ni].T * ramp).T
    if no > 0:
        ramp = np.linspace(1, 0, no, dtype=np.float32)
        y[-no:] = (y[-no:].T * ramp).T
    return y


def slow_lfo(sec: float, hz: float, rng: np.random.Generator | None = None, depth: float = 1.0, offset: float = 0.0) -> np.ndarray:
    """0〜1 のゆっくりした揺れ（正弦の位相をランダムに）"""
    ph = 0.0 if rng is None else rng.uniform(0, 2 * np.pi)
    return (offset + depth * 0.5 * (1 + np.sin(2 * np.pi * hz * t_axis(sec) + ph))).astype(np.float32)


def wander(sec: float, rng: np.random.Generator, rate_hz: float = 0.2, depth: float = 1.0) -> np.ndarray:
    """ランダムウォークを平滑化した 0〜1 の揺れ（風の強弱など、周期性の無い変化）"""
    n = n_samples(sec)
    steps = max(4, int(sec * rate_hz * 4))
    knots = rng.random(steps + 1)
    coarse = max(64, int(sec * 200))  # 200 Hz の粗い格子で平滑化してから補間（全サンプルで平滑化すると重い）
    x = np.interp(np.linspace(0, steps, coarse), np.arange(steps + 1), knots)
    win = min(coarse // 2 * 2 - 1, 401)
    x = signal.savgol_filter(x, win, 3) if win >= 5 else x
    x = np.interp(np.linspace(0, coarse - 1, n), np.arange(coarse), x)
    x = (x - x.min()) / (x.max() - x.min() + 1e-9)
    return (x * depth).astype(np.float32)


# ── フィルタ ──

def _sos(kind: str, cutoff, order: int = 4):
    return signal.butter(order, cutoff, btype=kind, fs=SR, output="sos")


def lpf(x: np.ndarray, cutoff: float, order: int = 4) -> np.ndarray:
    return signal.sosfiltfilt(_sos("low", min(cutoff, SR / 2 - 1), order), x, axis=0).astype(np.float32)


def hpf(x: np.ndarray, cutoff: float, order: int = 4) -> np.ndarray:
    return signal.sosfiltfilt(_sos("high", max(cutoff, 1.0), order), x, axis=0).astype(np.float32)


def bpf(x: np.ndarray, low: float, high: float, order: int = 4) -> np.ndarray:
    return signal.sosfiltfilt(_sos("band", [max(low, 1.0), min(high, SR / 2 - 1)], order), x, axis=0).astype(np.float32)


def notch(x: np.ndarray, freq: float, q: float = 30.0) -> np.ndarray:
    b, a = signal.iirnotch(freq, q, fs=SR)
    return signal.filtfilt(b, a, x, axis=0).astype(np.float32)


def resonator(x: np.ndarray, freq: float, q: float, gain: float = 1.0) -> np.ndarray:
    """鋭いバンドパス（共鳴体）。金属・木・管の共鳴を作る"""
    b, a = signal.iirpeak(min(freq, SR / 2 - 1), q, fs=SR)
    return (signal.lfilter(b, a, x, axis=0) * gain).astype(np.float32)


def resonant_body(x: np.ndarray, modes: list[tuple[float, float, float]]) -> np.ndarray:
    """複数の共鳴モード (freq, q, gain) を並列に掛けて足す"""
    out = np.zeros_like(x, dtype=np.float32)
    for f, q, g in modes:
        out += resonator(x, f, q, g)
    return out


def lpf_sweep(x: np.ndarray, cutoff_curve: np.ndarray, order: int = 2, block: int = 1024) -> np.ndarray:
    """カットオフを時間で変える LPF（ブロックごとに係数を更新、状態を引き継ぐ）"""
    x = to_mono(x) if x.ndim == 2 else x
    y = np.zeros_like(x, dtype=np.float64)
    zi = None
    for s in range(0, len(x), block):
        c = float(np.clip(cutoff_curve[min(s, len(cutoff_curve) - 1)], 20.0, SR / 2 - 100))
        sos = signal.butter(order, c, btype="low", fs=SR, output="sos")
        if zi is None:
            zi = signal.sosfilt_zi(sos) * x[s]
        y[s:s + block], zi = signal.sosfilt(sos, x[s:s + block], zi=zi)
    return y.astype(np.float32)


def tilt(x: np.ndarray, low_gain_db: float, high_gain_db: float, pivot: float = 1000.0) -> np.ndarray:
    """低域と高域の傾き（簡易シェルフ 2 段）"""
    lo = lpf(x, pivot, 2) * db(low_gain_db)
    hi = hpf(x, pivot, 2) * db(high_gain_db)
    return (lo + hi).astype(np.float32)


# ── 粒状合成 ──

def grain(sec: float, freq: float, rng: np.random.Generator, kind: str = "sine", noise_band: tuple[float, float] | None = None, attack: float = 0.3) -> np.ndarray:
    """1 粒。kind: sine / fm / noise。attack は粒長に対する立ち上がりの割合"""
    n = n_samples(sec)
    if kind == "noise":
        g = rng.standard_normal(n).astype(np.float32)
        if noise_band:
            g = bpf(g, noise_band[0], noise_band[1], 2)
    elif kind == "fm":
        g = fm(freq, sec, 1.5 + rng.random(), 2.0 + rng.random() * 3, 20.0)
    else:
        g = sine(freq, sec, rng.uniform(0, 2 * np.pi))
    env = np.ones(n, np.float32)
    na = max(1, int(n * attack))
    env[:na] = np.linspace(0, 1, na)
    env[na:] = np.linspace(1, 0, n - na) ** 1.5 if n > na else env[na:]
    return g * env


def swarm(sec: float, rng: np.random.Generator, density: float, grain_sec: tuple[float, float], freq: tuple[float, float],
          kind: str = "sine", noise_band: tuple[float, float] | None = None, pan_spread: float = 0.8,
          loop: bool = True, gain_jitter_db: float = 6.0, envelope: np.ndarray | None = None, rate_curve: np.ndarray | None = None) -> np.ndarray:
    """粒を撒いて群れを作る（ステレオ）。density は 1 秒あたりの粒数。
    loop=True なら末尾をまたぐ粒を先頭に折り返し、継ぎ目で密度が落ちない。
    envelope（0〜1、長さ n）で全体の強弱、rate_curve（0〜1）で密度の時間変化を掛ける"""
    n = n_samples(sec)
    out = np.zeros((n, 2), np.float64)
    count = int(density * sec)
    times = rng.random(count) * sec
    if rate_curve is not None:
        keep = rng.random(count) < np.interp(times, np.linspace(0, sec, len(rate_curve)), rate_curve)
        times = times[keep]
    for t0 in times:
        gs = rng.uniform(*grain_sec)
        f = np.exp(rng.uniform(np.log(freq[0]), np.log(freq[1])))
        g = grain(gs, f, rng, kind, noise_band)
        g *= db(rng.uniform(-gain_jitter_db, 0))
        pan = rng.uniform(-pan_spread, pan_spread)
        l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        s = int(t0 * SR)
        idx = (np.arange(len(g)) + s)
        if loop:
            idx = idx % n
        else:
            m = idx < n
            idx, g = idx[m], g[m]
        np.add.at(out[:, 0], idx, g * l)
        np.add.at(out[:, 1], idx, g * r)
    if envelope is not None:
        out *= fit(envelope.astype(np.float64), n)[:, None]
    return out.astype(np.float32)


# ── 空間 ──

def make_ir(rng: np.random.Generator, rt60: float, size: str = "room", damp_hz: float = 4000.0, early: bool = True, predelay_ms: float = 5.0) -> np.ndarray:
    """合成インパルス応答（ステレオ）。rt60 秒で -60 dB。size: room / hall / tunnel / outdoor（初期反射の並びが変わる）"""
    sec = max(0.3, rt60 * 1.2)
    n = n_samples(sec)
    t = np.arange(n) / SR
    decay = np.exp(-6.9078 * t / max(rt60, 0.05))
    ir = np.zeros((n, 2), np.float64)
    for ch in range(2):
        late = rng.standard_normal(n) * decay
        late = lpf(late.astype(np.float32), damp_hz, 2).astype(np.float64)
        ir[:, ch] = late
    if early:
        taps = {"room": [(7, 0.6), (11, 0.5), (17, 0.4), (23, 0.3)],
                "hall": [(15, 0.5), (27, 0.45), (41, 0.35), (63, 0.3), (89, 0.2)],
                "tunnel": [(21, 0.7), (42, 0.55), (63, 0.45), (84, 0.35), (105, 0.28), (126, 0.2)],
                "outdoor": [(30, 0.25), (70, 0.12)]}[size]
        for ms, g in taps:
            i = n_samples(ms / 1000.0)
            if i < n:
                ir[i, 0] += g * rng.uniform(0.8, 1.2)
                ir[i + n_samples(0.0007) if i + 31 < n else i, 1] += g * rng.uniform(0.8, 1.2)
    pd = n_samples(predelay_ms / 1000.0)
    ir = np.concatenate([np.zeros((pd, 2)), ir])
    ir[0, :] += 1.0  # 直接音
    ir /= np.abs(ir).max() + 1e-9
    return ir.astype(np.float32)


def convolve(x: np.ndarray, ir: np.ndarray, wet: float = 0.3, dry: float = 1.0) -> np.ndarray:
    """畳み込み残響。x はモノまたはステレオ。出力はステレオ。ir[0] に直接音が入っているので wet だけで良い場合は dry=0"""
    xs = to_stereo(x).astype(np.float64)
    out = np.zeros((len(xs) + len(ir) - 1, 2))
    for ch in range(2):
        out[:, ch] = signal.fftconvolve(xs[:, ch], ir[:, ch].astype(np.float64))
    out = out[: len(xs)] * wet
    if dry:
        out += xs * dry
    peak = np.abs(out).max()
    if peak > 0.999:
        out = out / peak * 0.999
    return out.astype(np.float32)


def pan(x: np.ndarray, position: float) -> np.ndarray:
    """モノを定位 -1〜1 に置く（等パワー）"""
    m = to_mono(x)
    a = (position + 1) * np.pi / 4
    return np.stack([m * np.cos(a), m * np.sin(a)], axis=1).astype(np.float32)


def widen(x: np.ndarray, amount: float = 0.5) -> np.ndarray:
    """M/S で幅を広げる（amount 0 で変化なし、1 で最大）"""
    s = to_stereo(x).astype(np.float64)
    m = (s[:, 0] + s[:, 1]) * 0.5
    d = (s[:, 0] - s[:, 1]) * 0.5 * (1 + amount)
    return np.stack([m + d, m - d], axis=1).astype(np.float32)


def decorrelate(mono: np.ndarray, rng: np.random.Generator, ms: float = 12.0) -> np.ndarray:
    """モノを左右で位相の異なるステレオにする（短い全域通過的な遅延の散らし）"""
    m = to_mono(mono).astype(np.float64)
    n = n_samples(ms / 1000.0)
    taps = np.zeros(n)
    taps[0] = 0.7
    for _ in range(6):
        taps[rng.integers(1, n)] += rng.uniform(-0.25, 0.25)
    r = signal.fftconvolve(m, taps)[: len(m)]
    r /= (np.abs(r).max() + 1e-9) / (np.abs(m).max() + 1e-9)
    return np.stack([m, r], axis=1).astype(np.float32)


def soft_clip(x: np.ndarray, drive: float = 1.0) -> np.ndarray:
    return np.tanh(x * drive).astype(np.float32) / np.tanh(drive)
