"""基盤の動作確認用。素材ではない（タスク1 で削除する）。ピンクノイズを風に整形した 20 秒ループ"""
import numpy as np
import synth as s


def render_test_wind(rng: np.random.Generator) -> np.ndarray:
    sec = 20.0
    n = s.n_samples(sec)
    gust = s.wander(sec, rng, rate_hz=0.15, depth=0.7) + 0.3
    l = s.lpf(s.pink(sec, rng), 900, 2) * gust
    r = s.lpf(s.pink(sec, rng), 900, 2) * np.roll(gust, s.n_samples(0.4))
    out = np.stack([l, r], axis=1)
    return s.hpf(out, 40, 2)


DEFS = [
    {"id": "test_wind", "kind": "ambience", "loop": True, "stereo": True, "seconds": 20.0, "render": render_test_wind,
     "note": "動作確認用の風（削除予定）"},
]
