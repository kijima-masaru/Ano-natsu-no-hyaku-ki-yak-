# 磐戸町奇譚（仮）

2Dドット絵・見下ろし型ホラーアドベンチャー。Godot 4.7 / GDScript / Steam 配信を前提とする。
舞台は架空の町「神代市 磐戸町」。地名・施設名はすべて架空。

## ステップ1：ミニマップとフィールド定義（このリポジトリの現状）

| 成果物 | パス | 内容 |
|---|---|---|
| A | `docs/tools/world_minimap.html` | 町全体を俯瞰する設計確認用インタラクティブミニマップ（単一HTML・ゲーム本体ではない） |
| B | `data/fields.json` | 16フィールドの定義データ。Godot 側で `res://data/fields.json` として読み込む。16色パレット・骨格線・鍵の定義も `meta` に含む |
| C | `docs/field_build_order.md` | `.tscn` 化の推奨順序と、共有／固有タイル種別の切り分け |

`docs/tools/world_minimap.html` は `data/fields.json` を `docs/tools/world_minimap.template.html` に埋め込んで生成する。
JSON を変更したら次を実行して再生成する。

```
python3 docs/tools/build_minimap.py
```

## 技術仕様（要点）
- タイル 16×16 px、基準解像度 384×216（16:9）、整数倍スケール最大4倍
- 1フィールド = 1 `.tscn`、`TileMapLayer` 構成（`TileMap` ノードは使わない）
- パレット16色固定（`data/fields.json` → `meta.palette`）
- フォント PixelMplus12、テキストは整数座標・アンチエイリアス無効
