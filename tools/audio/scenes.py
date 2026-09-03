"""環境音の部品（風・車・機械・水・草・虫・蛙・物音）。defs から組み合わせて使う。
すべて (n, 2) のステレオ float32 を返し、絶対音量は「風＝1.0 前後」を基準に相対で揃える（最終音量は build が LUFS で決める）。
方針：音を足すより「無いこと」で不安を作る。ここにある部品は、それぞれ単体で長時間鳴っても耳障りにならない密度を既定にしている。
"""
from __future__ import annotations

import numpy as np
from scipy import signal

import synth as s

SR = s.SR


# ── 風 ──

def wind(sec: float, rng, strength: float = 0.5, color: float = 700.0, gust_rate: float = 0.12, width: float = 0.6) -> np.ndarray:
    """ピンクノイズを LPF で削り、ゆっくり強弱を付ける。strength 0〜1、color は LPF カットオフ（低いほど遠く・重く）"""
    n = s.n_samples(sec)
    g = s.wander(sec, rng, gust_rate, 1.0)
    env = (0.25 + 0.75 * g) * strength
    cut = color * (0.6 + 0.8 * g)
    base = s.lpf_sweep(s.pink(sec, rng), cut, 2)
    base = s.hpf(base, 30, 2)
    st = s.decorrelate(base, rng, 15.0)
    st = s.widen(st, width)
    return (st * env[:, None]).astype(np.float32)


def leaves(sec: float, rng, density: float = 40.0, gust: np.ndarray | None = None) -> np.ndarray:
    """葉擦れ。高めのノイズ粒を風の強弱に合わせて撒く"""
    curve = gust if gust is not None else s.wander(sec, rng, 0.12, 1.0)
    return s.swarm(sec, rng, density, (0.03, 0.12), (2500, 6000), kind="noise", noise_band=(1800, 7000),
                   pan_spread=0.9, rate_curve=curve, gain_jitter_db=10)


def grass(sec: float, rng, density: float = 25.0, gust: np.ndarray | None = None) -> np.ndarray:
    """草が寝る音。葉擦れより低く長い粒"""
    curve = gust if gust is not None else s.wander(sec, rng, 0.1, 1.0)
    return s.swarm(sec, rng, density, (0.08, 0.3), (600, 2500), kind="noise", noise_band=(500, 3500),
                   pan_spread=0.9, rate_curve=curve, gain_jitter_db=9)


# ── 車・機械 ──

def traffic_bed(sec: float, rng, level: float = 0.5, distance: float = 0.5) -> np.ndarray:
    """遠くの走行音の床（連続）。distance 0 で近く（帯域が広い）、1 で遠く（低域だけ）"""
    cut = 1400 * (1 - distance) + 180
    x = s.lpf(s.brown(sec, rng) * 0.6 + s.pink(sec, rng) * 0.4, cut, 2)
    x = s.hpf(x, 25, 2)
    st = s.decorrelate(x, rng, 20)
    mod = 0.7 + 0.3 * s.wander(sec, rng, 0.25, 1.0)
    return (st * (mod * level)[:, None]).astype(np.float32)


def car_passes(sec: float, rng, count: int, near: float = 0.6, speed: float = 1.0, loop: bool = True) -> np.ndarray:
    """車が通り過ぎる（左→右／右→左）。ノイズの膨らみ＋定位の移動＋わずかな音程の下降（ドップラー）"""
    n = s.n_samples(sec)
    out = np.zeros((n, 2), np.float64)
    for _ in range(count):
        dur = rng.uniform(3.5, 6.5) / speed
        m = s.n_samples(dur)
        t = np.linspace(-1, 1, m)
        env = np.exp(-(t * 2.2) ** 2)
        cut = 900 + 1800 * near * env
        noise = s.lpf_sweep(s.pink(dur, rng), cut, 2)
        tone = s.sine_fm(60 * (1 + 0.15 * near), dur, 0.08, 4.0)
        body = (noise * 1.0 + tone * 0.25 * env) * env
        direction = rng.choice([-1, 1])
        pan = np.clip(t * direction * 0.9, -1, 1)
        a = (pan + 1) * np.pi / 4
        st = np.stack([body * np.cos(a), body * np.sin(a)], axis=1) * (0.6 + 0.6 * near)
        start = int(rng.random() * n)
        idx = (np.arange(m) + start) % n if loop else np.arange(m) + start
        keep = idx < n
        np.add.at(out, idx[keep], st[keep])
    return out.astype(np.float32)


def machine_hum(sec: float, rng, freq: float = 50.0, harmonics=(1.0, 0.5, 0.25, 0.12), flutter: float = 0.02, width: float = 0.3) -> np.ndarray:
    """モーター・コンプレッサ・変圧器の唸り。倍音とわずかな揺れ"""
    t = s.t_axis(sec)
    x = np.zeros_like(t)
    for k, a in enumerate(harmonics):
        f = freq * (k + 1)
        x += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi)) * (1 + flutter * np.sin(2 * np.pi * rng.uniform(0.1, 0.5) * t))
    x += s.lpf(s.white(sec, rng), 400, 2) * 0.05
    return s.widen(s.decorrelate(x.astype(np.float32), rng, 8), width)


def compressor_cycle(sec: float, rng, on_sec: float = 9.0, off_sec: float = 6.0, freq: float = 55.0) -> np.ndarray:
    """自販機のコンプレッサ。数秒回って止まる周期。ループ長で割り切れる周期に丸める"""
    n = s.n_samples(sec)
    period = on_sec + off_sec
    cycles = max(1, round(sec / period))
    period = sec / cycles
    on = on_sec / (on_sec + off_sec) * period
    gate = np.zeros(n)
    for c in range(cycles):
        a, b = s.n_samples(c * period), s.n_samples(c * period + on)
        gate[a:b] = 1
    gate = s.lpf(gate.astype(np.float32), 6, 1)
    hum = machine_hum(sec, rng, freq, (1.0, 0.6, 0.2), 0.03, 0.2)
    click = np.zeros(n, np.float32)
    for c in range(cycles):
        for pos in (c * period, c * period + on):
            i = s.n_samples(pos) % n
            click[i:i + 800] += s.exp_decay(800 / SR, 120)[: min(800, n - i)] * rng.uniform(0.3, 0.5)
    click = s.bpf(click, 300, 3000, 2)
    return (hum * np.clip(gate, 0, 1)[:, None] + s.to_stereo(click) * 0.3).astype(np.float32)


def fan(sec: float, rng, freq: float = 38.0) -> np.ndarray:
    """換気扇。低い回転音とブレードのノイズ"""
    x = machine_hum(sec, rng, freq, (0.8, 0.5, 0.3, 0.2, 0.1), 0.01, 0.2)
    blade = s.bpf(s.white(sec, rng), 200, 1200, 2) * (0.5 + 0.5 * s.slow_lfo(sec, freq / 4, rng))
    return (x + s.to_stereo(blade) * 0.35).astype(np.float32)


def fluorescent(sec: float, rng, level: float = 1.0) -> np.ndarray:
    """蛍光灯・街灯の安定器のハム（100 Hz 系、細い）"""
    x = machine_hum(sec, rng, 100.0, (1.0, 0.35, 0.5, 0.2, 0.3), 0.005, 0.15)
    return s.hpf(x, 80, 2) * level


# ── 水 ──

def water(sec: float, rng, level: float = 0.6, brightness: float = 0.5, movement: float = 0.3) -> np.ndarray:
    """川・水路。帯域の広いノイズを複数の帯で揺らす。brightness で細かい飛沫の量"""
    bands = [(80, 400, 1.0), (400, 1600, 0.7), (1600, 5000, 0.35 + 0.5 * brightness), (5000, 12000, 0.15 + 0.4 * brightness)]
    out = np.zeros((s.n_samples(sec), 2), np.float64)
    for lo, hi, g in bands:
        for ch in range(2):
            b = s.bpf(s.white(sec, rng), lo, hi, 2)
            mod = 1 + movement * (s.wander(sec, rng, 0.3 + rng.random(), 1.0) - 0.5)
            out[:, ch] += b * g * mod
    return (out / (np.abs(out).max() + 1e-9) * level).astype(np.float32)


def trickle(sec: float, rng, level: float = 0.4) -> np.ndarray:
    """用水路・湧水の細い流れ。細かい粒と細い帯"""
    base = s.bpf(s.white(sec, rng), 1200, 6000, 2) * 0.4 * (0.7 + 0.3 * s.wander(sec, rng, 0.5, 1.0))
    drops = s.swarm(sec, rng, 12, (0.01, 0.03), (1500, 4500), kind="sine", pan_spread=0.5, gain_jitter_db=12)
    return (s.decorrelate(base, rng, 6) * 0.6 + drops * 0.5).astype(np.float32) * level


def drip(sec: float, rng, rate: float = 0.5, ir: np.ndarray | None = None) -> np.ndarray:
    """水滴。まばらに落ちる。ir があれば残響を掛ける"""
    n = s.n_samples(sec)
    out = np.zeros(n, np.float32)
    count = max(1, int(rate * sec))
    for _ in range(count):
        f = rng.uniform(1800, 3200)
        d = s.sine(f, 0.05) * s.exp_decay(0.05, 90, 0.001)
        hi = s.sine(f * 2.3, 0.02) * s.exp_decay(0.02, 200, 0.0005) * 0.3
        d[: len(hi)] += hi
        i = int(rng.random() * n)
        end = min(n, i + len(d))
        out[i:end] += d[: end - i] * rng.uniform(0.4, 1.0)
    st = s.pan(out, 0.0)
    return s.convolve(st, ir, wet=0.8, dry=0.6) if ir is not None else st


# ── 虫・蛙 ──

def cicada_rasp(sec: float, rng, density: float = 120.0, center: float = 4300.0, spread: float = 0.35) -> np.ndarray:
    """アブラゼミ系。ざらついた粒を密に撒く。center 周辺の帯域、spread は広がり（対数比）"""
    lo, hi = center / (1 + spread), center * (1 + spread)
    body = s.swarm(sec, rng, density, (0.02, 0.05), (lo, hi), kind="fm", pan_spread=0.9, gain_jitter_db=8)
    # 数匹の「鳴き続け」を足す：帯域ノイズに 40〜60 Hz の振幅変調
    n = s.n_samples(sec)
    cont = np.zeros((n, 2), np.float32)
    for _ in range(3):
        f = rng.uniform(lo, hi)
        am = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * rng.uniform(40, 60) * s.t_axis(sec)))
        tone = s.bpf(s.white(sec, rng), f * 0.9, f * 1.1, 2) * am
        env = s.wander(sec, rng, 0.08, 1.0)
        cont += s.pan(tone * env, rng.uniform(-0.8, 0.8)) * 0.6
    return (body + cont).astype(np.float32)


def cicada_tonal(sec: float, rng, count: int = 4, base: float = 5200.0) -> np.ndarray:
    """ミンミンゼミ系。うねる音程の連続音を数匹、位相をずらして"""
    n = s.n_samples(sec)
    out = np.zeros((n, 2), np.float32)
    for _ in range(count):
        cycle = rng.uniform(2.2, 3.4)
        t = s.t_axis(sec)
        wob = 0.5 + 0.5 * np.sin(2 * np.pi * (1 / cycle) * t + rng.uniform(0, 6.28))
        f = base * (0.92 + 0.16 * wob) * rng.uniform(0.95, 1.05)
        ph = 2 * np.pi * np.cumsum(f) / SR
        tone = np.sin(ph) * (0.6 + 0.4 * np.sin(2 * np.pi * 120 * t))
        tone = s.bpf(tone.astype(np.float32), 2500, 9000, 2)
        env = np.clip(s.wander(sec, rng, 0.06, 1.0) * 1.6 - 0.3, 0, 1)
        out += s.pan(tone * env, rng.uniform(-0.9, 0.9)) * 0.5
    return out


def higurashi(sec: float, rng, count: int = 3) -> np.ndarray:
    """ヒグラシ（夕）。カナカナ…と加速して収まる、澄んだ音程の連なり"""
    n = s.n_samples(sec)
    out = np.zeros((n, 2), np.float32)
    for _ in range(count):
        start = rng.random() * sec
        calls = int(rng.uniform(18, 30))
        t0 = start
        gap = 0.32
        f0 = rng.uniform(3300, 3900)
        pos = rng.uniform(-0.9, 0.9)
        for k in range(calls):
            g = s.grain(0.07, f0 * (1 + 0.04 * np.sin(k * 0.9)), rng, "sine", attack=0.15)
            g = s.bpf(g, 2200, 7000, 2)
            lvl = np.sin(np.pi * (k + 1) / (calls + 1)) ** 0.7
            st = s.pan(g * lvl, pos)
            i = int((t0 % sec) * SR)
            idx = (np.arange(len(st)) + i) % n
            np.add.at(out, idx, st)
            gap = max(0.13, gap * 0.985)
            t0 += gap
    return out


def crickets(sec: float, rng, density: float = 10.0, freq: tuple = (3800, 5200)) -> np.ndarray:
    """夜の虫。短い音程の粒がリズミカルに続く。density は 1 秒あたりの鳴き"""
    n = s.n_samples(sec)
    out = np.zeros((n, 2), np.float32)
    voices = max(1, int(density / 3))
    for _ in range(voices):
        f = rng.uniform(*freq)
        rate = rng.uniform(3.0, 7.0)
        pos = rng.uniform(-0.9, 0.9)
        t = rng.random() * sec
        # 鳴いたり止んだりの門は、ループ長で割り切れる周期の正弦にする（継ぎ目で状態が一致する）
        cycles = int(rng.integers(2, 5))
        phase = rng.uniform(0, 2 * np.pi)
        onoff = 0.5 + 0.5 * np.sin(2 * np.pi * cycles * np.linspace(0, 1, n) + phase)
        while t < sec + 2:
            if rng.random() < np.interp(t % sec, np.linspace(0, sec, n), onoff) * 1.3:
                g = s.grain(0.035, f, rng, "sine", attack=0.2)
                g *= (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 45 * s.t_axis(0.035))))
                st = s.pan(s.bpf(g, 2500, 8000, 2), pos) * rng.uniform(0.3, 0.7)
                i = int((t % sec) * SR)
                idx = (np.arange(len(st)) + i) % n
                np.add.at(out, idx, st)
            t += 1.0 / rate
    return out


def frogs(sec: float, rng, density: float = 30.0) -> np.ndarray:
    """蛙の合唱。低めの短い粒がたくさん。密度で「止む」も作れる"""
    body = s.swarm(sec, rng, density, (0.05, 0.11), (500, 1100), kind="fm", pan_spread=0.9, gain_jitter_db=8)
    return s.lpf(body, 3500, 2)


# ── 物音（まばら） ──

def _scatter(sec: float, rng, count: int, make, pan_spread: float = 0.8, loop: bool = True) -> np.ndarray:
    n = s.n_samples(sec)
    out = np.zeros((n, 2), np.float32)
    for _ in range(count):
        g = make()
        st = s.pan(g, rng.uniform(-pan_spread, pan_spread)) if g.ndim == 1 else g
        i = int(rng.random() * n)
        idx = (np.arange(len(st)) + i) % n if loop else np.arange(len(st)) + i
        keep = idx < n
        np.add.at(out, idx[keep], st[keep])
    return out


def tin_rattle(sec: float, rng, count: int = 6) -> np.ndarray:
    """トタンが風で鳴る。共鳴した金属のガタつき"""
    def make():
        d = rng.uniform(0.15, 0.5)
        x = s.white(d, rng) * s.exp_decay(d, rng.uniform(6, 14), 0.005)
        x = s.resonant_body(x, [(rng.uniform(180, 260), 12, 1.0), (rng.uniform(600, 900), 18, 0.5), (rng.uniform(1800, 2600), 25, 0.25)])
        return x * rng.uniform(0.3, 1.0)
    return _scatter(sec, rng, count, make)


def fence_clink(sec: float, rng, count: int = 5) -> np.ndarray:
    """金網が鳴る。細く高い金属の粒がぱらつく"""
    def make():
        d = rng.uniform(0.2, 0.6)
        x = s.white(d, rng) * s.exp_decay(d, rng.uniform(10, 20), 0.002)
        return s.resonant_body(x, [(rng.uniform(1400, 2200), 30, 0.8), (rng.uniform(3200, 4800), 40, 0.5)]) * rng.uniform(0.2, 0.7)
    return _scatter(sec, rng, count, make)


def paper_flutter(sec: float, rng, count: int = 4) -> np.ndarray:
    """掲示板の紙が風で鳴る。乾いた短い粒の連なり"""
    def make():
        d = rng.uniform(0.3, 0.9)
        flaps = s.swarm(d, rng, 25, (0.01, 0.03), (1500, 5000), kind="noise", noise_band=(1200, 6500), pan_spread=0.2, loop=False, gain_jitter_db=6)
        return (flaps.mean(axis=1) * s.exp_decay(d, 3, 0.05)).astype(np.float32) * rng.uniform(0.3, 0.8)
    return _scatter(sec, rng, count, make)


def shutter_creak(sec: float, rng, count: int = 2) -> np.ndarray:
    """シャッターの内側の軋み。低くゆっくり、遠い"""
    def make():
        d = rng.uniform(0.6, 1.4)
        x = s.fm(rng.uniform(90, 140), d, 1.01, 1.5, 0.0) * s.adsr(d, 0.2, 0.2, 0.5, 0.4)
        x = s.resonator(x, rng.uniform(300, 500), 8, 0.6) + x * 0.4
        return s.lpf(x, 1200, 2) * rng.uniform(0.2, 0.5)
    return _scatter(sec, rng, count, make, 0.6)


def post_lid(sec: float, rng, count: int = 3) -> np.ndarray:
    """集合ポストの蓋が風で開閉する。薄い金属の二連打"""
    def make():
        d = 0.35
        n = s.n_samples(d)
        x = np.zeros(n, np.float32)
        for at, g in ((0.0, 1.0), (rng.uniform(0.08, 0.16), 0.6)):
            i = s.n_samples(at)
            h = s.white(0.08, rng) * s.exp_decay(0.08, 60, 0.001)
            x[i:i + len(h)] += h[: n - i] * g
        return s.resonant_body(x, [(rng.uniform(900, 1300), 20, 1.0), (rng.uniform(2400, 3200), 30, 0.4)]) * rng.uniform(0.2, 0.5)
    return _scatter(sec, rng, count, make, 0.5)


def wood_creak(sec: float, rng, count: int = 3, low: float = 60.0) -> np.ndarray:
    """木の軋み（山門・堂・古木）。ごく低く、短い"""
    def make():
        d = rng.uniform(0.25, 0.7)
        x = s.pulse_train(rng.uniform(low, low * 1.6), d, 0.15) * s.adsr(d, 0.05, 0.1, 0.6, 0.3)
        x = s.lpf(x, 900, 2)
        return s.resonator(x, rng.uniform(120, 220), 6, 0.8) * rng.uniform(0.15, 0.4)
    return _scatter(sec, rng, count, make, 0.6)


def distant_rumble(sec: float, rng, level: float = 0.3) -> np.ndarray:
    """遠い低音（高速道路、街のうねり）。ブラウンノイズの最低域"""
    x = s.lpf(s.brown(sec, rng), 120, 2)
    mod = 0.6 + 0.4 * s.wander(sec, rng, 0.2, 1.0)
    return (s.decorrelate(x, rng, 30) * (mod * level)[:, None]).astype(np.float32)


def room_tone(sec: float, rng, level: float = 0.15, cut: float = 300.0) -> np.ndarray:
    """ほぼ無音の「空気」。何も無い場所の床。これが無いと本当の無音になり、再生機器のノイズが目立つ"""
    x = s.lpf(s.pink(sec, rng), cut, 2)
    return (s.decorrelate(x, rng, 25) * level).astype(np.float32)
