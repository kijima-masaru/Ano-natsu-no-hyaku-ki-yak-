"""蝉の独立トラック。フィールドの環境音には蝉を入れず、AudioManager が日付と時間帯でこれを重ねる（docs/AUDIO_SPEC.md「蝉」）。
- amb_cicada_rasp：アブラゼミ系の密な群れ（昼の主役）。8 月前半の密度
- amb_cicada_rasp_thin：同じ群れの疎な版（8 月後半）。減衰は音量ではなく密度で作る
- amb_cicada_tonal：ミンミンゼミ系の数匹（朝〜昼に薄く重ねる）
- amb_cicada_evening：ヒグラシ（夕のみ）。カナカナと加速して収まる
各 30 秒ループ。
"""
import scenes as sc
import synth as s

SEC = 30.0


def rasp(rng):
    return sc.cicada_rasp(SEC, rng, 140, 4300, 0.35)


def rasp_thin(rng):
    return sc.cicada_rasp(SEC, rng, 35, 4300, 0.35)


def tonal(rng):
    return sc.cicada_tonal(SEC, rng, 4, 5200)


def evening(rng):
    return s.mix(sc.higurashi(SEC, rng, 4), sc.room_tone(SEC, rng, 0.05, 200), length=s.n_samples(SEC))


DEFS = [
    {"id": "amb_cicada_rasp", "kind": "ambience", "loop": True, "stereo": True, "seconds": SEC - 0.5, "render": rasp, "layer": "cicada", "lufs_offset": -2,
     "note": "アブラゼミ系の密な群れ。8 月前半の昼", "use": "屋外の昼（morning / noon / evening）に重ねる。日付で thin に切り替え"},
    {"id": "amb_cicada_rasp_thin", "kind": "ambience", "loop": True, "stereo": True, "seconds": SEC - 0.5, "render": rasp_thin, "layer": "cicada", "lufs_offset": -7,
     "note": "同じ群れの疎な版。8 月後半", "use": "8/16 以降の昼"},
    {"id": "amb_cicada_tonal", "kind": "ambience", "loop": True, "stereo": True, "seconds": SEC - 0.5, "render": tonal, "layer": "cicada", "lufs_offset": -8,
     "note": "ミンミンゼミ系の数匹。うねる音程", "use": "朝〜昼に薄く。8/20 以降は鳴らさない"},
    {"id": "amb_cicada_evening", "kind": "ambience", "loop": True, "stereo": True, "seconds": SEC - 0.5, "render": evening, "layer": "cicada", "lufs_offset": -6,
     "note": "ヒグラシ。夕だけ。8 月末まで残る唯一の蝉", "use": "evening に重ねる"},
]
