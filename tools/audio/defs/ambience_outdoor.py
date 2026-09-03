"""屋外の環境音：F01 F02 F03 F04 F05 F09 F10 F12 F13 F14 F15 × 時間帯 4（morning / noon / evening / night）。
ID：昼は既存の amb_<name>（そのまま）、他は amb_<name>_morning / _evening / _night。夜は蝉が止み、虫に入れ替わる。
蝉はここには入れない（defs/ambience_cicada.py の独立トラックを AudioManager 側で重ねる。docs/AUDIO_SPEC.md）。
各 40 秒ループ。音量は build が -28 LUFS に揃えるので、部品の比率だけを設計する。
"""
import numpy as np

import scenes as sc
import synth as s

SEC = 40.0
TODS = ("morning", "noon", "evening", "night")


def _mix(sec, *parts):
    return s.mix(*parts, length=s.n_samples(sec))


# ── フィールドごとの設計 ──

def road(tod, rng):
    """F01 国道。町で唯一「うるさい」場所。車の床＋通過＋自販機のコンプレッサ＋換気扇。夜は車が疎らで、自販機の灯りの唸りが残る"""
    p = {"morning": dict(bed=0.45, dist=0.3, passes=5, near=0.5, comp=0.5, fan=0.3, wind=0.2),
         "noon": dict(bed=0.7, dist=0.2, passes=10, near=0.7, comp=0.6, fan=0.45, wind=0.25),
         "evening": dict(bed=0.6, dist=0.25, passes=7, near=0.6, comp=0.6, fan=0.4, wind=0.3),
         "night": dict(bed=0.25, dist=0.45, passes=2, near=0.5, comp=0.6, fan=0.2, wind=0.2)}[tod]
    parts = [sc.traffic_bed(SEC, rng, p["bed"], p["dist"]), sc.car_passes(SEC, rng, p["passes"], p["near"]),
             sc.compressor_cycle(SEC, rng, 11, 7) * p["comp"], sc.fan(SEC, rng) * p["fan"], sc.wind(SEC, rng, p["wind"], 500)]
    if tod == "night":
        parts += [sc.fluorescent(SEC, rng, 0.35), sc.crickets(SEC, rng, 3)]
    return _mix(SEC, *parts)


def road_still(rng):
    """F01 の「静まり返る」版（8/15 以降の夜の怪異 an_f01_silence 用）。車が一台も来ない。自販機と灯りだけが働いている"""
    return _mix(SEC, sc.compressor_cycle(SEC, rng, 11, 7) * 0.6, sc.fluorescent(SEC, rng, 0.4), sc.room_tone(SEC, rng, 0.2, 250), sc.wind(SEC, rng, 0.1, 400))


def residential(tod, rng):
    """F02 住宅地。犬も車も無い。遠い国道が壁に吸われる。夜はほぼ風だけ"""
    p = {"morning": dict(wind=0.3, bed=0.15, leaves=10), "noon": dict(wind=0.35, bed=0.2, leaves=16),
         "evening": dict(wind=0.3, bed=0.15, leaves=10), "night": dict(wind=0.15, bed=0.07, leaves=4)}[tod]
    gust = s.wander(SEC, rng, 0.12, 1.0)
    parts = [sc.wind(SEC, rng, p["wind"], 550), sc.traffic_bed(SEC, rng, p["bed"], 0.9), sc.leaves(SEC, rng, p["leaves"], gust) * 0.5]
    if tod == "night":
        parts.append(sc.crickets(SEC, rng, 4))
    return _mix(SEC, *parts)


def underpass(tod, rng):
    """F03 高架下。上を走る車の音が遠く降ってくる。防音壁が唸る。地上に人の気配が無い"""
    p = {"morning": dict(passes=5, bed=0.35), "noon": dict(passes=8, bed=0.45), "evening": dict(passes=6, bed=0.4), "night": dict(passes=2, bed=0.2)}[tod]
    overhead = sc.car_passes(SEC, rng, p["passes"], 0.3, 0.9)
    overhead = s.lpf(overhead, 650, 2)  # 床版越し
    ir = s.make_ir(rng, 1.1, "tunnel", 2500, True, 12)
    overhead = s.convolve(overhead, ir, wet=0.35, dry=1.0)
    wall = s.resonator(s.to_mono(sc.traffic_bed(SEC, rng, p["bed"], 0.5)), 63, 6, 0.8)
    parts = [sc.distant_rumble(SEC, rng, 0.5), sc.traffic_bed(SEC, rng, p["bed"], 0.6), overhead, s.pan(wall, 0.0) * 0.4, sc.wind(SEC, rng, 0.15, 300)]
    if tod == "night":
        parts += [sc.fluorescent(SEC, rng, 0.3), sc.crickets(SEC, rng, 2)]
    return _mix(SEC, *parts)


def orchard(tod, rng):
    """F04 谷戸。国道の音はもう届かない。風で葉とトタンが鳴る。夜は虫が最も多い（蝉は独立トラック）"""
    p = {"morning": dict(wind=0.35, leaves=30, tin=4, grass=8), "noon": dict(wind=0.4, leaves=40, tin=5, grass=10),
         "evening": dict(wind=0.45, leaves=35, tin=6, grass=10), "night": dict(wind=0.25, leaves=14, tin=3, grass=5)}[tod]
    gust = s.wander(SEC, rng, 0.12, 1.0)
    parts = [sc.wind(SEC, rng, p["wind"], 900, 0.12, 0.7), sc.leaves(SEC, rng, p["leaves"], gust) * 0.7, sc.tin_rattle(SEC, rng, p["tin"]) * 0.6,
             sc.grass(SEC, rng, p["grass"], gust) * 0.5]
    if tod == "night":
        parts.append(sc.crickets(SEC, rng, 14))
    return _mix(SEC, *parts)


def shopping_street(tod, rng):
    """F05 旧街道。F01 との落差が最重要。ほぼ無音。狭い通りを抜ける風と、シャッターの内側の軋み。自分の足音だけが響く空間"""
    p = {"morning": dict(wind=0.14, creak=2), "noon": dict(wind=0.16, creak=2), "evening": dict(wind=0.14, creak=2), "night": dict(wind=0.1, creak=1)}[tod]
    narrow = s.bpf(s.to_mono(sc.wind(SEC, rng, p["wind"], 700)), 250, 1800, 2)
    parts = [sc.room_tone(SEC, rng, 0.3, 400), s.decorrelate(narrow, rng, 10) * 0.8, sc.shutter_creak(SEC, rng, p["creak"]) * 0.7]
    if tod == "night":
        parts.append(sc.crickets(SEC, rng, 1) * 0.5)
    return _mix(SEC, *parts)


def castle(tod, rng):
    """F09 城址。高速の走行音が防音壁越しに低く続く。土塁の上は風、空堀の底は無音（無音側は AudioManager が音量で作る）"""
    p = {"morning": dict(wind=0.45, rumble=0.4, grass=15), "noon": dict(wind=0.5, rumble=0.45, grass=20),
         "evening": dict(wind=0.5, rumble=0.45, grass=18), "night": dict(wind=0.35, rumble=0.3, grass=8)}[tod]
    gust = s.wander(SEC, rng, 0.1, 1.0)
    parts = [sc.distant_rumble(SEC, rng, p["rumble"]), sc.wind(SEC, rng, p["wind"], 600, 0.1, 0.8), sc.grass(SEC, rng, p["grass"], gust) * 0.5]
    if tod == "night":
        parts.append(sc.crickets(SEC, rng, 8))
    return _mix(SEC, *parts)


def ground(tod, rng):
    """F10 河川敷。開けている。遮蔽物が無い不安。川は遠く、風と草擦れ、バックネットの金網"""
    p = {"morning": dict(wind=0.5, grass=30, fence=4), "noon": dict(wind=0.6, grass=35, fence=5), "evening": dict(wind=0.6, grass=35, fence=5), "night": dict(wind=0.4, grass=15, fence=3)}[tod]
    gust = s.wander(SEC, rng, 0.1, 1.0)
    parts = [sc.water(SEC, rng, 0.22, 0.3), sc.wind(SEC, rng, p["wind"], 800, 0.1, 0.9), sc.grass(SEC, rng, p["grass"], gust) * 0.6, sc.fence_clink(SEC, rng, p["fence"]) * 0.5]
    if tod == "night":
        parts.append(sc.crickets(SEC, rng, 10))
    return _mix(SEC, *parts)


def estate(tod, rng):
    """F12 団地。国道の音が壁に反射して届く。給水塔のモーター。集合ポストの蓋。夜は階段室の灯りの唸り"""
    p = {"morning": dict(bed=0.22, hum=0.3, lid=2, wind=0.25), "noon": dict(bed=0.28, hum=0.3, lid=3, wind=0.25),
         "evening": dict(bed=0.25, hum=0.3, lid=3, wind=0.28), "night": dict(bed=0.1, hum=0.35, lid=2, wind=0.18)}[tod]
    reflected = s.convolve(sc.traffic_bed(SEC, rng, p["bed"], 0.7), s.make_ir(rng, 0.7, "hall", 1500, True, 20), wet=0.5, dry=0.8)
    parts = [reflected, sc.machine_hum(SEC, rng, 50, (1.0, 0.4, 0.2), 0.02, 0.3) * p["hum"], sc.post_lid(SEC, rng, p["lid"]) * 0.6, sc.wind(SEC, rng, p["wind"], 500)]
    if tod == "night":
        parts += [sc.fluorescent(SEC, rng, 0.2), sc.crickets(SEC, rng, 3)]
    return _mix(SEC, *parts)


def newtown(tod, rng):
    """F13 ニュータウン。均質な無音。街灯の微かなハム。同じ形の家の間（足音の二重化は怪異側の SE）"""
    p = {"morning": dict(wind=0.12, hum=0.08), "noon": dict(wind=0.14, hum=0.08), "evening": dict(wind=0.12, hum=0.15), "night": dict(wind=0.08, hum=0.3)}[tod]
    parts = [sc.room_tone(SEC, rng, 0.28, 350), sc.wind(SEC, rng, p["wind"], 450), sc.fluorescent(SEC, rng, p["hum"])]
    if tod == "night":
        parts.append(sc.crickets(SEC, rng, 2) * 0.6)
    return _mix(SEC, *parts)


def paddy(tod, rng):
    """F14 朝和。水路の水音と風。夜は蛙の合唱（止む版は amb_paddy_still）。古墳の上は風だけ（音量で作る）"""
    p = {"morning": dict(trickle=0.4, wind=0.3, grass=12), "noon": dict(trickle=0.4, wind=0.35, grass=15), "evening": dict(trickle=0.4, wind=0.35, grass=14), "night": dict(trickle=0.35, wind=0.2, grass=5)}[tod]
    gust = s.wander(SEC, rng, 0.1, 1.0)
    parts = [sc.trickle(SEC, rng, p["trickle"]), sc.wind(SEC, rng, p["wind"], 700, 0.1, 0.8), sc.grass(SEC, rng, p["grass"], gust) * 0.5]
    if tod == "night":
        parts.append(sc.frogs(SEC, rng, 34) * 0.9)
    return _mix(SEC, *parts)


def paddy_still(rng):
    """F14 夜、蛙が止んだあと（怪異 an_f14_frogs と 8/30 以降）。水路と風だけ。蛙が居た空白が残る"""
    return _mix(SEC, sc.trickle(SEC, rng, 0.35), sc.wind(SEC, rng, 0.2, 700), sc.room_tone(SEC, rng, 0.15, 300))


def river(tod, rng):
    """F15 蒼籠川。川の音が全てを覆う。町の境界。対岸は霧で見えない。夜は橋灯の唸りが微かに"""
    p = {"morning": dict(water=0.9, bright=0.55, wind=0.3), "noon": dict(water=0.95, bright=0.6, wind=0.3), "evening": dict(water=0.9, bright=0.5, wind=0.35), "night": dict(water=0.9, bright=0.4, wind=0.25)}[tod]
    parts = [sc.water(SEC, rng, p["water"], p["bright"], 0.35), sc.wind(SEC, rng, p["wind"], 600)]
    if tod == "night":
        parts += [sc.fluorescent(SEC, rng, 0.08), sc.crickets(SEC, rng, 3) * 0.5]
    return _mix(SEC, *parts)


# 系統の目標（-28 LUFS）からの意図的なずれ。国道と川を基準 0 とし、静かな場所ほど負にする。
# 「F01 だけはうるさく、F05 はほぼ無音」という落差をここで作る（docs/AUDIO_SPEC.md「音量設計」）
OFFSET = {"road": 0, "residential": -5, "underpass": -2, "orchard": -3, "shopping_street": -9, "castle": -4, "ground": -3,
          "estate": -4, "newtown": -10, "paddy": -4, "river": 0}
NIGHT_EXTRA = {"road": -3, "residential": -2, "underpass": -2, "orchard": 0, "shopping_street": -2, "castle": -1, "ground": -1,
               "estate": -2, "newtown": -2, "paddy": 0, "river": 0}

FIELDS = {
    "road": ("F01", road, "国道281号。車の床・通過・自販機のコンプレッサ・換気扇。町で唯一うるさい"),
    "residential": ("F02", residential, "住宅地。遠い国道が壁に吸われ、風と葉だけ"),
    "underpass": ("F03", underpass, "高架下。上から降ってくる走行音、防音壁の唸り"),
    "orchard": ("F04", orchard, "谷戸。風・葉擦れ・トタン。夜は虫が最も多い"),
    "shopping_street": ("F05", shopping_street, "旧街道。ほぼ無音。狭い通りの風とシャッターの軋み"),
    "castle": ("F09", castle, "城址。防音壁越しの高速の低音と土塁の風"),
    "ground": ("F10", ground, "河川敷。遠い川、風、草擦れ、金網"),
    "estate": ("F12", estate, "団地。反射した国道、給水塔のモーター、ポストの蓋"),
    "newtown": ("F13", newtown, "ニュータウン。均質な無音と街灯のハム"),
    "paddy": ("F14", paddy, "朝和。水路と風。夜は蛙の合唱"),
    "river": ("F15", river, "蒼籠川。川の音が全てを覆う"),
}

DEFS = []
for name, (field, fn, note) in FIELDS.items():
    for tod in TODS:
        ident = f"amb_{name}" if tod == "noon" else f"amb_{name}_{tod}"
        DEFS.append({"id": ident, "kind": "ambience", "loop": True, "stereo": True, "seconds": SEC - 0.5, "crossfade": 0.5,
                     "lufs_offset": OFFSET[name] + (NIGHT_EXTRA[name] if tod == "night" else 0),
                     "render": (lambda t, f: (lambda rng: f(t, rng)))(tod, fn), "field": field, "time_of_day": tod,
                     "note": note, "use": f"{field} の {tod}（蝉は独立トラックを重ねる）"})
DEFS += [
    {"id": "amb_road_still", "kind": "ambience", "loop": True, "stereo": True, "seconds": SEC - 0.5, "render": road_still, "field": "F01", "time_of_day": "night", "lufs_offset": -8,
     "note": "国道が静まり返る（車が一台も来ない）。自販機と灯りだけ", "use": "8/15 以降の夜、怪異 an_f01_silence"},
    {"id": "amb_paddy_still", "kind": "ambience", "loop": True, "stereo": True, "seconds": SEC - 0.5, "render": paddy_still, "field": "F14", "time_of_day": "night", "lufs_offset": -8,
     "note": "蛙が止んだ夜。水路と風だけ", "use": "怪異 an_f14_frogs の後、8/30 以降の夜"},
]

# 生成済みファイルを変えないため旧シード方式を維持（build.seed_of 参照）
for _d in DEFS:
    _d.setdefault("seed_scheme", 1)
