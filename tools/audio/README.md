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
- `lufs_offset`（dB）で系統の基準からの意図的なずれを指定する（静かな場所・忍び足は負）
- シードは ID から SHA-256 で決める（`build.seed_of`）。環境音の 3 モジュールは生成済みファイルを変えないため旧方式（`seed_scheme: 1`、ID 先頭 4 文字しか効かない偏りがあった）を明示して維持している。新しいモジュールでは指定しない

### 1 秒未満の単発音（SE）の仕上げ

- 8 Hz の DC 除去フィルタは掛けない（短い信号の平均を打ち消そうとして両端にオフセット＝クリックが出る）。低域は定義側の HPF で切る
- 先頭に 10 ms の無音を前置し、最低 0.5 ms のフェードインを保証する（Vorbis のプリエコーが先頭サンプルに乗るのを避ける）
- ピークの上限は -3.5 dBFS（復号後に 0.4 dB ほど膨らむ分の余裕）
- クリック的で波高率が高い音（石段・板張りの足音など）は、ピーク制限だけでは目標ラウドネスに届かない。その場合だけ tanh で最上部を丸めて再正規化する（manifest の `soft_clip_drive`）。「アタックを鈍らせる」方針に沿った処理で、丸めていない音は 0
- ラウドネスは 400 ms ブロックのゲート付き測定なので、それより短い音は無音で 400 ms に埋めて測る。短い音ほど同じ数値でも小さく聞こえるが、系統内で基準が揃うことを優先している

### 書き出し

環境音・SE は libsndfile（soundfile）で OGG Vorbis を書く。BGM（60 秒超のステレオ）は libsndfile 1.2.2 がセグメンテーション違反を起こすため、ffmpeg（imageio-ffmpeg 同梱、libvorbis）で書く。`master.write_ogg` が kind で切り替える。

## Git での扱い

`*.ogg` は **通常の git で管理** する（`.gitattributes` で binary 指定）。Git LFS は、開発環境から `lfs.github.com` に到達できず push が通らないため有効化していない。LFS へ移す場合は到達できる環境で `.gitattributes` の LFS 行を有効にし、`git lfs migrate import --include="*.ogg"` で移行する（履歴の書き換えを伴うので合意の上で 1 回だけ）。

## 方針（要約）

恐怖は静けさで作る。生活音の残留。蝉は日ごとに減る。安心の音が終盤で最も不吉に響く。ジャンプスケア・悲鳴・苦痛の音・自死を想起させる物音は作らない。生楽器の模倣はしない（減衰する共鳴体として抽象化する）。詳細は `docs/AUDIO_SPEC.md`。
