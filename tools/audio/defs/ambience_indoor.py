"""屋内・特殊空間の環境音。残響の設計が命：部屋の大きさ・天井高・材質を IR で描き分ける。
- F06 市民センター前（amb_town × 4）と 図書室内（amb_town_library）
- F07 光明院 門前（amb_temple × 4）と 堂内（amb_temple_hall）
- F08 天神社（amb_shrine × 4）
- F11 小学校 校庭（amb_school × 4）と 旧校舎 1 階（amb_school_1f）
- F16 薬師谷（amb_valley：谷全体、amb_valley_inner：裂け目の口）
- F03 隧道内（amb_underpass_tunnel）
"""
import numpy as np

import scenes as sc
import synth as s

SEC = 40.0
TODS = ("morning", "noon", "evening", "night")


def _mix(sec, *parts):
    return s.mix(*parts, length=s.n_samples(sec))


def _night_bits(tod, rng, insects, lamp=0.0):
    parts = []
    if tod == "night":
        parts.append(sc.crickets(SEC, rng, insects))
        if lamp:
            parts.append(sc.fluorescent(SEC, rng, lamp))
    return parts


# ── F06 市民センター・交番前広場 ──

def town(tod, rng):
    """広場。掲示板の紙が風で鳴る。遠い国道。交番の赤灯は点いているが人はいない（灯りの唸りだけ）"""
    p = {"morning": dict(wind=0.3, paper=4, bed=0.18), "noon": dict(wind=0.35, paper=5, bed=0.22), "evening": dict(wind=0.3, paper=5, bed=0.18), "night": dict(wind=0.18, paper=2, bed=0.08)}[tod]
    parts = [sc.wind(SEC, rng, p["wind"], 600), sc.paper_flutter(SEC, rng, p["paper"]) * 0.7, sc.traffic_bed(SEC, rng, p["bed"], 0.8)]
    parts += _night_bits(tod, rng, 3, 0.2)
    return _mix(SEC, *parts)


def town_library(rng):
    """図書室。空調の低い風と、蛍光灯の唸り。外の音は硬い壁に遮られてほとんど届かない。天井の低いコンクリートの残響"""
    ac = s.lpf(s.pink(SEC, rng), 350, 2) * (0.8 + 0.2 * s.wander(SEC, rng, 0.2, 1.0))
    ac = s.decorrelate(ac, rng, 10) * 0.6
    vent = s.bpf(s.white(SEC, rng), 700, 2500, 2) * 0.05
    outside = s.lpf(s.to_mono(sc.traffic_bed(SEC, rng, 0.1, 0.9)), 150, 2)
    ir = s.make_ir(rng, 0.7, "room", 5000, True, 4)
    dry = _mix(SEC, ac, s.decorrelate(vent, rng, 6), s.pan(outside, 0.0), sc.fluorescent(SEC, rng, 0.35))
    return s.convolve(dry, ir, wet=0.25, dry=1.0)


# ── F07 光明院 ──

def temple(tod, rng):
    """門前。砂利を踏む音だけが大きい場所（足音は SE）。墓域では風が止む。木の軋み。町の音は遠い"""
    p = {"morning": dict(wind=0.25, creak=3), "noon": dict(wind=0.28, creak=3), "evening": dict(wind=0.3, creak=4), "night": dict(wind=0.15, creak=3)}[tod]
    gust = s.wander(SEC, rng, 0.08, 1.0)
    parts = [sc.wind(SEC, rng, p["wind"], 500, 0.08, 0.7), sc.leaves(SEC, rng, 8, gust) * 0.4, sc.wood_creak(SEC, rng, p["creak"], 55) * 0.8, sc.room_tone(SEC, rng, 0.12, 300)]
    parts += _night_bits(tod, rng, 5)
    return _mix(SEC, *parts)


def temple_hall(rng):
    """堂内。木造の高い天井。外の風が板壁越しに遠く、床と柱がときどき鳴る。長い残響に自分の気配が返る"""
    outside = s.lpf(s.to_mono(sc.wind(SEC, rng, 0.25, 400)), 500, 2) * 0.5
    creaks = sc.wood_creak(SEC, rng, 5, 45) * 0.9
    air = sc.room_tone(SEC, rng, 0.2, 250)
    ir = s.make_ir(rng, 2.2, "hall", 2200, True, 18)
    dry = _mix(SEC, s.pan(outside, 0.0), creaks, air)
    return s.convolve(dry, ir, wet=0.55, dry=0.8)


# ── F08 臥牛山 天神社 ──

def shrine(tod, rng):
    """町の音が完全に消える。枯れた梅林の枝が触れ合う。石段は自分の足音だけ（SE）"""
    p = {"morning": dict(wind=0.3, twigs=6), "noon": dict(wind=0.32, twigs=7), "evening": dict(wind=0.35, twigs=8), "night": dict(wind=0.2, twigs=4)}[tod]
    gust = s.wander(SEC, rng, 0.08, 1.0)
    twigs = s.swarm(SEC, rng, p["twigs"], (0.01, 0.03), (900, 2600), kind="noise", noise_band=(700, 3200), pan_spread=0.9, rate_curve=gust, gain_jitter_db=10)
    twigs = s.resonant_body(twigs.mean(axis=1), [(1400, 12, 0.6), (2600, 16, 0.3)])
    parts = [sc.wind(SEC, rng, p["wind"], 550, 0.08, 0.8), s.decorrelate(twigs, rng, 8) * 0.6, sc.leaves(SEC, rng, 6, gust) * 0.3, sc.room_tone(SEC, rng, 0.1, 250)]
    parts += _night_bits(tod, rng, 4)
    return _mix(SEC, *parts)


# ── F11 磐戸第一小学校 ──

def school(tod, rng):
    """校庭。無音に近い。風と、校旗の綱が支柱に当たる音がまばらに。新校舎の非常灯（夜）"""
    p = {"morning": dict(wind=0.22, rope=3), "noon": dict(wind=0.25, rope=4), "evening": dict(wind=0.25, rope=4), "night": dict(wind=0.15, rope=2)}[tod]
    rope = sc.fence_clink(SEC, rng, p["rope"]) * 0.35
    parts = [sc.wind(SEC, rng, p["wind"], 500, 0.1, 0.8), rope, sc.room_tone(SEC, rng, 0.15, 300)]
    parts += _night_bits(tod, rng, 3, 0.15)
    return _mix(SEC, *parts)


def school_1f(rng):
    """旧校舎 1 階。板張りの廊下。床板が鳴り、蛍光灯が不規則に唸り、遠くでチャイムのような残響が消えかける。
    木造の中くらいの残響。外の風は板壁と窓のすき間からわずかに"""
    n = s.n_samples(SEC)
    floor = sc.wood_creak(SEC, rng, 7, 70) * 1.0
    lamp = sc.fluorescent(SEC, rng, 0.25)
    flick = (0.7 + 0.3 * np.clip(s.wander(SEC, rng, 0.6, 1.0) * 1.5 - 0.25, 0, 1))[:, None]
    lamp = lamp * flick
    # チャイムの残骸：4 音の下降を極めて遠く、途中で切れる。1 回だけ、ループの中で 1 度
    chime = np.zeros(n, np.float32)
    start = rng.uniform(8, 25)
    for k, f in enumerate([880.0, 698.5, 784.0, 523.3]):
        d = 1.2
        tone = s.harmonics(f, d, [1.0, 0.3, 0.12], 4, rng) * s.exp_decay(d, 2.2, 0.01)
        i = s.n_samples(start + k * 0.55)
        chime[i:i + len(tone)] += tone[: n - i]
    chime = s.lpf(chime, 1800, 2) * 0.06
    draft = s.bpf(s.to_mono(sc.wind(SEC, rng, 0.15, 400)), 300, 1200, 2) * 0.5
    ir = s.make_ir(rng, 0.9, "hall", 3200, True, 10)
    dry = _mix(SEC, floor, lamp, s.pan(chime, 0.3), s.decorrelate(draft, rng, 8), sc.room_tone(SEC, rng, 0.18, 250))
    return s.convolve(dry, ir, wet=0.4, dry=1.0)


# ── F16 薬師谷 ──

def valley(rng):
    """谷全体。水音も風も無い。音が吸われる。ごく低い圧の揺れだけが、耳ではなく胸で分かる程度に残る。
    高域を完全に落とした空気。蝉も虫も鳴かない"""
    press = s.sine_fm(31.0, SEC, 0.05, 1.5) * (0.5 + 0.5 * s.slow_lfo(SEC, 0.025, rng))
    press = press.astype(np.float32) * 0.8
    air = s.lpf(s.pink(SEC, rng), 140, 3) * 0.25
    return _mix(SEC, s.decorrelate(press, rng, 20), s.decorrelate(air, rng, 25))


def valley_inner(rng):
    """裂け目の口（8/30、封石を戻すまで）。耳の奥で鳴るような極低音のハム。不協和な部分音がゆっくり干渉し、
    数秒ごとに一段深く沈む。封印の瞬間に止まる（set_ambience）"""
    n = s.n_samples(SEC)
    t = s.t_axis(SEC)
    base = 55.0
    partials = [(1.0, 1.0), (1.498, 0.45), (2.03, 0.3), (2.77, 0.18), (4.19, 0.08)]
    x = np.zeros(n, np.float64)
    for ratio, a in partials:
        beat = 1 + 0.004 * np.sin(2 * np.pi * rng.uniform(0.03, 0.09) * t + rng.uniform(0, 6.28))
        x += a * np.sin(2 * np.pi * base * ratio * beat * t)
    sink = 0.55 + 0.45 * (0.5 + 0.5 * np.sin(2 * np.pi * (1 / 8.0) * t))
    x = x * sink
    body = s.lpf(x.astype(np.float32), 400, 2)
    hiss = s.bpf(s.white(SEC, rng), 3000, 6000, 2) * 0.012 * (0.5 + 0.5 * s.slow_lfo(SEC, 0.11, rng))
    return _mix(SEC, s.decorrelate(body, rng, 30), s.decorrelate(hiss, rng, 5))


# ── F03 隧道内 ──

def underpass_tunnel(rng):
    """隧道内。最も暗い場所。上を走る車が壁の中で鳴る。水滴が落ち、残響が長い。
    聞こえるはずのない反響：水滴の一部が、遅れて別の方向から返ってくる"""
    ir = s.make_ir(rng, 2.6, "tunnel", 1800, True, 25)
    overhead = s.lpf(sc.car_passes(SEC, rng, 4, 0.25, 0.8), 350, 2)
    standing = s.resonator(s.to_mono(sc.traffic_bed(SEC, rng, 0.3, 0.7)), 92, 9, 0.9)
    drips = sc.drip(SEC, rng, 0.45)
    # 遅れた反響：同じ水滴を 0.7〜1.1 秒遅らせ、逆の定位で小さく
    n = s.n_samples(SEC)
    late = np.zeros_like(drips)
    d = s.n_samples(rng.uniform(0.7, 1.1))
    late[d:] = drips[: n - d][:, ::-1] * 0.35
    late = s.lpf(late, 2000, 2)
    dry = _mix(SEC, overhead, s.pan(standing, 0.0) * 0.5, drips * 0.8, late, sc.room_tone(SEC, rng, 0.2, 200))
    return s.convolve(dry, ir, wet=0.6, dry=0.8)


FIELDS = {
    "town": ("F06", town, "市民センター前。掲示板の紙、遠い国道、交番の灯り", -3, -2),
    "temple": ("F07", temple, "光明院 門前。風が止む墓域、木の軋み", -6, -2),
    "shrine": ("F08", shrine, "天神社。町の音が消え、枯れた梅の枝だけ", -7, -2),
    "school": ("F11", school, "校庭。無音に近い。校旗の綱", -8, -2),
}

DEFS = []
for name, (field, fn, note, off, night_extra) in FIELDS.items():
    for tod in TODS:
        ident = f"amb_{name}" if tod == "noon" else f"amb_{name}_{tod}"
        DEFS.append({"id": ident, "kind": "ambience", "loop": True, "stereo": True, "seconds": SEC - 0.5, "lufs_offset": off + (night_extra if tod == "night" else 0),
                     "render": (lambda t, f: (lambda rng: f(t, rng)))(tod, fn), "field": field, "time_of_day": tod, "note": note, "use": f"{field} の {tod}"})
DEFS += [
    {"id": "amb_town_library", "kind": "ambience", "loop": True, "stereo": True, "seconds": SEC - 0.5, "lufs_offset": -6, "render": town_library, "field": "F06",
     "note": "図書室。空調と蛍光灯、コンクリートの短い残響", "use": "F06 図書室に入っている間（統合案）"},
    {"id": "amb_temple_hall", "kind": "ambience", "loop": True, "stereo": True, "seconds": SEC - 0.5, "lufs_offset": -8, "render": temple_hall, "field": "F07",
     "note": "堂内。木造の高い天井の長い残響、板壁越しの風", "use": "F07 観音堂の中（統合案）"},
    {"id": "amb_school_1f", "kind": "ambience", "loop": True, "stereo": True, "seconds": SEC - 0.5, "lufs_offset": -7, "render": school_1f, "field": "F11",
     "note": "旧校舎 1 階。床板、不規則な蛍光灯、遠いチャイムの残骸", "use": "F11 の階 1f（FieldFloors）"},
    {"id": "amb_valley", "kind": "ambience", "loop": True, "stereo": True, "seconds": SEC - 0.5, "lufs_offset": -14, "render": valley, "field": "F16",
     "note": "薬師谷。水も風も無く、音が吸われる。31 Hz の圧の揺れだけ", "use": "F16 全体（既存 ID。無音から差し替え）"},
    {"id": "amb_valley_inner", "kind": "ambience", "loop": True, "stereo": True, "seconds": SEC - 0.5, "lufs_offset": -4, "render": valley_inner, "field": "F16",
     "note": "裂け目の口。55 Hz の不協和な部分音が干渉し、8 秒ごとに沈む", "use": "8/30 封石まで（set_ambience、既存 ID）"},
    {"id": "amb_underpass_tunnel", "kind": "ambience", "loop": True, "stereo": True, "seconds": SEC - 0.5, "lufs_offset": -3, "render": underpass_tunnel, "field": "F03",
     "note": "隧道内。長い残響、水滴、遅れて逆から返る反響", "use": "F03 隧道の中（統合案）"},
]

# 生成済みファイルを変えないため旧シード方式を維持（build.seed_of 参照）
for _d in DEFS:
    _d.setdefault("seed_scheme", 1)
