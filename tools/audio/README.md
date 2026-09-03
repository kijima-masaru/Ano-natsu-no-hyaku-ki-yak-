# tools/audio — 音声素材の合成基盤

すべての音声素材（`assets/audio/`）は、ここにある Python だけで **ゼロから合成** する。既存の音源・素材集は使わない。同じコマンドで同じ音が再生成できる（乱数は ID ごとに固定シード）。

## 使い方

```
pip install numpy scipy soundfile imageio-ffmpeg      # 依存（ffmpeg は imageio-ffmpeg 同梱のバイナリを使う）
python3 tools/audio/build.py                          # 全素材を生成 → assets/audio/<kind>/<id>.ogg と manifest.json
python3 tools/audio/build.py --only amb_road --check  # 1 件だけ。--check で 3 周連結した WAV を build/audio_check/ に出す（ループ確認用）
python3 tools/audio/build.py --list                   # 定義の一覧
python3 tools/audio/verify.py                         # 生成物の検証（下表）。問題があれば終了コード 1
python3 tools/audio/verify.py --json build/audio_verify.json
```

## 構成

| ファイル | 役割 |
|---|---|
| `synth.py` | 発生源（正弦・倍音・FM・パルス・白／ピンク／ブラウンノイズ）、包絡（ADSR・指数減衰・ゆらぎ）、フィルタ（LPF/HPF/BPF/notch・共鳴・時間変化 LPF）、粒状合成（`swarm`）、合成 IR の畳み込み残響（`make_ir` / `convolve`）、定位・非相関化 |
| `master.py` | ラウドネス（BS.1770 K 特性、ゲート付き。外部ライブラリなし）、目標 LUFS への正規化、ピーク制限（超過分だけゲインを下げる）、シームレスループ（末尾を先頭へ等パワーでクロスフェード）、DC 除去、OGG Vorbis 書き出し、ffmpeg での復号確認 |
| `build.py` | `defs/*.py` の `DEFS` を集めて一括生成。`manifest.json` に ID・パス・長さ・LUFS・ピーク・用途を記録 |
| `verify.py` | ピーク（-3 dBFS 以下）、ラウドネス（系統の目標 ±1.5）、長さ、DC、無音混入、ループの継ぎ目（3 周連結の前後 20 ms の段差）、チャンネル数・レート、サイズ、ffmpeg 復号 |
| `defs/` | 音の定義。1 モジュール 1 系統（屋外環境音、屋内、足音…）。各定義は `{"id", "kind", "loop", "stereo", "seconds", "render": fn(rng) -> ndarray, "note", "use"}` |

## 規格

| 項目 | 値 |
|---|---|
| 形式 | OGG Vorbis、44.1 kHz。BGM・環境音はステレオ、SE はモノ |
| ラウドネス | 環境音 -28 LUFS、BGM -20 LUFS、SE -16 LUFS（`master.TARGET_LUFS`） |
| ピーク | -3 dBFS 以下 |
| ループ | 末尾 0.5 秒（定義で変更可）を先頭へクロスフェード。粒状合成は境界をまたぐ粒を折り返して撒く |
| サイズ | BGM 2 MB、環境音 1 MB、SE 100 KB 以下（超えたら verify が注意） |
| 命名 | `assets/audio/bgm/bgm_<name>.ogg`、`assets/audio/ambience/amb_<field_or_context>.ogg`、`assets/audio/se/se_<name>.ogg` |

## 定義の書き方

```python
import synth as s

def render(rng):
    sec = 30.0
    wind = s.lpf(s.pink(sec, rng), 800, 2) * (s.wander(sec, rng, 0.15, 0.7) + 0.3)
    return s.decorrelate(wind, rng)      # (n, 2) を返す。ラウドネスは build 側で揃えるので絶対値は気にしない

DEFS = [{"id": "amb_example", "kind": "ambience", "loop": True, "stereo": True, "seconds": 30.0, "render": render,
         "note": "何を狙ったか", "use": "どこで鳴るか"}]
```

- `render` は無加工の波形を返す。正規化・ループ化・書き出しは `build.py` が行う
- 単発の SE は `loop: False`、`fade_out` 秒を指定できる
- 意図した無音が多い音は `allow_silence: True` を付ける（verify の無音検査を緩める）

## 方針（要約）

恐怖は静けさで作る。生活音の残留。蝉は日ごとに減る。安心の音が終盤で最も不吉に響く。ジャンプスケア・悲鳴・苦痛の音・自死を想起させる物音は作らない。生楽器の模倣はしない（減衰する共鳴体として抽象化する）。詳細は `docs/AUDIO_SPEC.md`。
