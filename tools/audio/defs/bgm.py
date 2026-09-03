"""BGM。7 本、ステレオ、ループ（クロスフェード 1 秒）。暫定＝差し替え可能な設計（docs/AUDIO_SPEC.md §11）。

方針：
- 音楽を鳴らし続けない。タイトル・追跡・8/30 の封印と真相・8/31・スタッフロールにだけ曲がある。フィールドは環境音だけ
- 低周波ドローンと、ごく短い旋律の断片（3 音）だけ。和声を積まない。生楽器の模倣をしない。過度な残響をかけない
- 追跡曲は心拍（60–110 Hz）の帯域を避ける
- 真相の曲が最も強い。ナツの音色（96 Hz の温かいトーン）と谷の不協和比（1 : 1.498 : 2.03 : 2.77）を、ここで初めて同じ音として大きく鳴らす
"""
import numpy as np

import scenes as sc
import synth as s

XF = 1.0
VALLEY = ((1.0, 1.0), (1.498, 0.45), (2.03, 0.3), (2.77, 0.18))
MOTIF = ((220.0, 0.0), (261.63, 1.6), (196.0, 3.4))  # A3 → C4 → G3。下降して終わらない断片


def _drone(sec, rng, base, partials, lpf_hz=500.0, beat_hz=0.06, depth=0.004):
    t = s.t_axis(sec)
    x = np.zeros(len(t), np.float64)
    for ratio, a in partials:
        beat = 1 + depth * np.sin(2 * np.pi * rng.uniform(beat_hz * 0.7, beat_hz * 1.3) * t + rng.uniform(0, 6.28))
        x += a * np.sin(2 * np.pi * base * ratio * beat * t)
    return s.lpf((x / max(1.0, sum(a for _, a in partials))).astype(np.float32), lpf_hz, 2)


def _note(freq, sec, rng, bright=0.6):
    """3 音の断片に使う 1 音。正弦に僅かな FM と 2 倍音。アタックは遅く、減衰は長い"""
    x = s.sine_fm(freq, sec, 5.0, freq * 0.004) + s.sine(freq * 2, sec, 0.3) * 0.18 * bright + s.sine(freq * 3.01, sec) * 0.05 * bright
    return x * s.adsr(sec, 0.25, 0.5, 0.5, sec * 0.55) / 1.3


def _motif(out, rng, at, gain=1.0, notes=MOTIF, note_sec=4.5, pan_l=0.45):
    for k, (f, off) in enumerate(notes):
        n = _note(f, note_sec, rng)
        s.place(out, s.pan(n, pan_l if k % 2 == 0 else 1 - pan_l), at + off, gain)


def _loop(sec):
    n = s.n_samples(sec + XF)
    return np.zeros((n, 2), np.float32)


def title(rng):
    """タイトル。70 秒ループ。低いドローン、遠い蝉の残響、旋律の断片が 1 回だけ。8 月の夕方"""
    sec = 70.0
    out = _loop(sec)
    d = _drone(sec + XF, rng, 55.0, ((1.0, 1.0), (2.0, 0.4), (3.0, 0.15), (1.5, 0.12)), 400, 0.05)
    s.place(out, s.decorrelate(d * (0.7 + 0.3 * s.wander(sec + XF, rng, 0.03, 1.0)), rng, 25), 0.0, 0.5)
    cic = sc.cicada_rasp(sec + XF, rng, 40, 4000, 0.4)
    cic = s.lpf(s.to_mono(cic), 2500, 2) * (0.4 + 0.6 * s.wander(sec + XF, rng, 0.04, 1.0))
    ir = s.make_ir(rng, 2.5, "outdoor", 2000, True, 30)
    s.place(out, s.convolve(s.decorrelate(cic, rng, 15), ir, 0.7, 0.3), 0.0, 0.08)
    _motif(out, rng, 22.0, 0.22)
    high = s.sine(660.0, 30.0) * s.adsr(30.0, 8.0, 4.0, 0.6, 12.0) * 0.03
    s.place(out, s.pan(high, 0.6), 38.0)
    return out


def tension(rng):
    """追跡。32 秒ループ。35–50 Hz の圧と、200–600 Hz のノイズの脈（心拍の帯域を空ける）。8 秒周期のうねり。旋律なし"""
    sec = 32.0
    n = s.n_samples(sec + XF)
    t = s.t_axis(sec + XF)
    out = _loop(sec)
    sub = s.lpf(s.brown(sec + XF, rng), 48, 2) * (0.6 + 0.4 * np.sin(2 * np.pi * t / 8.0 - np.pi / 2))
    s.place(out, s.to_stereo(sub), 0.0, 0.55)
    pulse = s.bpf(s.pink(sec + XF, rng), 200, 600, 2)
    gate = 0.5 + 0.5 * np.sin(2 * np.pi * t / 2.0)  # 2 秒周期 = 32 秒で 16 周期ちょうど
    gate = gate ** 3
    s.place(out, s.decorrelate((pulse * gate).astype(np.float32), rng, 8), 0.0, 0.25)
    thin = s.bpf(s.white(sec + XF, rng), 2500, 5000, 2) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 8.0)) ** 2
    s.place(out, s.decorrelate(thin, rng, 3), 0.0, 0.03)
    return out


def seal(rng):
    """8/30 封印。60 秒ループ。谷の不協和比のドローンを 55 Hz で、面を戻す木の小さな置き音が遠くに。旋律なし"""
    sec = 60.0
    out = _loop(sec)
    d = _drone(sec + XF, rng, 55.0, VALLEY, 350, 0.06)
    sink = 0.6 + 0.4 * (0.5 + 0.5 * np.sin(2 * np.pi * s.t_axis(sec + XF) / 12.0))
    s.place(out, s.decorrelate(d * sink.astype(np.float32), rng, 30), 0.0, 0.6)
    taps = np.zeros(s.n_samples(sec + XF), np.float32)
    for at in sorted(rng.uniform(2, sec - 2, 7)):
        tap = s.resonant_body(s.bpf(s.white(0.3, rng) * s.exp_decay(0.3, 18, 0.002), 200, 2500, 2), [(rng.uniform(380, 460), 10, 1.0), (rng.uniform(1100, 1300), 14, 0.3)])
        s.place(taps, tap, at, rng.uniform(0.3, 0.6))
    ir = s.make_ir(rng, 1.8, "outdoor", 1800, True, 20)
    s.place(out, s.convolve(s.decorrelate(s.lpf(taps, 1500, 2), rng, 12), ir, 0.6, 0.5), 0.0, 0.12)
    return out


def truth(rng):
    """8/30 真相。60 秒ループ。本作で最も強い曲。ナツの 96 Hz の温かいトーンと谷の不協和比を、同じ音として大きく。
    0.4 Hz のうねり、上の部分音（2.77 倍）が 30 秒かけて前に出て、また沈む。打楽器なし"""
    sec = 60.0
    n = s.n_samples(sec + XF)
    t = s.t_axis(sec + XF)
    out = _loop(sec)
    warm = np.sin(2 * np.pi * 96.0 * t) + np.sin(2 * np.pi * 96.4 * t + 1.0) + 0.35 * np.sin(2 * np.pi * 192.0 * t)
    warm = s.lpf((warm / 2.35).astype(np.float32), 600, 2)
    s.place(out, s.decorrelate(warm, rng, 20), 0.0, 0.5)
    rise = 0.5 + 0.5 * np.sin(2 * np.pi * t / 30.0 - np.pi / 2)  # 30 秒で 1 周期 = 60 秒で 2 周期
    for ratio, a in VALLEY:
        beat = 1 + 0.003 * np.sin(2 * np.pi * rng.uniform(0.05, 0.1) * t + rng.uniform(0, 6.28))
        p = np.sin(2 * np.pi * 96.0 * 4.0 * ratio * beat * t) * a
        g = (0.35 + 0.65 * rise) if ratio > 2.5 else (0.6 + 0.4 * rise)
        s.place(out, s.pan(s.lpf((p * g).astype(np.float32), 2500, 2), 0.5 + 0.3 * np.sin(ratio)), 0.0, 0.16)
    air = s.bpf(s.pink(sec + XF, rng), 400, 1200, 2) * (0.6 + 0.4 * s.wander(sec + XF, rng, 0.5, 1.0))
    s.place(out, s.decorrelate(air, rng, 6), 0.0, 0.05)
    return out


def ending(rng, variant):
    """8/31 御渡橋。60 秒ループ。澪の視点、昼の光、怪異は無い。川の音を薄く、高く細い持続音、旋律の断片。
    A：ナツの 96 Hz のトーンが下に小さく残る（ナツが澪に返事をした）。B：基本。C：旋律を鳴らさない（最も短い事後）"""
    sec = 60.0
    out = _loop(sec)
    river = s.to_mono(sc.water(sec + XF, rng, 0.5, 0.4, 0.15))
    s.place(out, s.decorrelate(s.lpf(river, 1800, 2), rng, 10), 0.0, 0.25)
    d = _drone(sec + XF, rng, 110.0, ((1.0, 1.0), (2.0, 0.3), (3.0, 0.1)), 700, 0.04)
    s.place(out, s.decorrelate(d * (0.6 + 0.4 * s.wander(sec + XF, rng, 0.03, 1.0)), rng, 25), 0.0, 0.3)
    high = s.sine(880.0, sec + XF) * (0.4 + 0.6 * s.wander(sec + XF, rng, 0.05, 1.0)) * 0.04
    s.place(out, s.pan(high, 0.55), 0.0)
    if variant != "c":
        _motif(out, rng, 18.0, 0.2, note_sec=5.5)
    if variant == "a":
        t = s.t_axis(sec + XF)
        warm = (np.sin(2 * np.pi * 96.0 * t) + np.sin(2 * np.pi * 96.4 * t + 1.0)) / 2
        s.place(out, s.decorrelate(s.lpf(warm.astype(np.float32), 400, 2), rng, 20), 0.0, 0.12)
    return out


def credits(rng):
    """スタッフロール。90 秒ループ。タイトルのドローンから蝉を抜き（8 月は終わった）、断片を 5 音に伸ばして 1 回だけ"""
    sec = 90.0
    out = _loop(sec)
    d = _drone(sec + XF, rng, 55.0, ((1.0, 1.0), (2.0, 0.4), (3.0, 0.15), (1.5, 0.12)), 400, 0.05)
    s.place(out, s.decorrelate(d * (0.7 + 0.3 * s.wander(sec + XF, rng, 0.03, 1.0)), rng, 25), 0.0, 0.45)
    wind = s.lpf(s.pink(sec + XF, rng), 500, 2) * (0.3 + 0.7 * s.wander(sec + XF, rng, 0.05, 1.0))
    s.place(out, s.decorrelate(wind, rng, 12), 0.0, 0.06)
    notes = MOTIF + ((220.0, 6.0), (174.61, 8.4))  # A3 C4 G3 A3 F3
    _motif(out, rng, 30.0, 0.2, notes=notes, note_sec=5.0)
    return out


def _d(id_, render, sec, note, use, off):
    return {"id": id_, "kind": "bgm", "loop": True, "stereo": True, "crossfade": XF, "seconds": sec, "lufs_offset": off, "render": render, "note": note, "use": use}


DEFS = [
    _d("bgm_title", title, 70.0, "既存 ID。タイトル。低いドローン、遠い蝉の残響、3 音の断片が 1 回", "Title（現行コード）", -4),
    _d("bgm_tension", tension, 32.0, "既存 ID。追跡。35–50 Hz の圧と 200–600 Hz の脈。心拍の帯域を空ける。旋律なし", "events の play_bgm bgm_tension（現行コード）", -2),
    _d("bgm_seal", seal, 60.0, "8/30 封印。谷の不協和比のドローンと、面を戻す木の置き音", "8/30 封印の配置パズル（統合案）", -4),
    _d("bgm_truth", truth, 60.0, "8/30 真相。最も強い。ナツのトーンと谷の比を同じ音として大きく", "truth_revealed 前後の対決会話〜提示画面（統合案）", 0),
    _d("bgm_ending", ending_b := (lambda rng: ending(rng, "b")), 60.0, "8/31 御渡橋。基本（エンド B）。川、細い持続音、断片", "8/31 の F15（統合案）", -4),
    _d("bgm_ending_a", lambda rng: ending(rng, "a"), 60.0, "8/31 エンド A。下にナツのトーンが小さく残る", "エンド A（統合案）", -4),
    _d("bgm_ending_c", lambda rng: ending(rng, "c"), 60.0, "8/31 エンド C。旋律を鳴らさない", "エンド C（統合案）", -6),
    _d("bgm_credits", credits, 90.0, "スタッフロール。蝉を抜いたタイトルのドローン、断片を 5 音に", "StaffRoll（統合案）", -5),
]
