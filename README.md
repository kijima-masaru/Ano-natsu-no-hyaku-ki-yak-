# 磐戸町奇譚（仮）

2Dドット絵・見下ろし型ホラーアドベンチャー。
舞台は架空の町「神代市 磐戸町」。16のフィールド（F01〜F16）を自由に探索し、調べる／持ち帰る／条件を満たすことで物語が進む。戦闘はなく、回避と隠密が基本。
実在の地名・人物・団体・宗教施設は一切登場しない。

## 必要環境

| 項目 | 内容 |
|---|---|
| エンジン | **Godot 4.7**（GDScript）。4.3 未満では `TileMapLayer` が無いため開けない |
| レンダラ | GL Compatibility（`project.godot` で固定） |
| 配信先 | Steam（Windows / Linux / Steam Deck）。Steam 連携は GodotSteam（GDExtension）を前提とし、現時点では空実装 |
| 補助ツール | Python 3（`docs/tools/build_minimap.py` の実行にのみ使用） |

## 起動方法

1. Godot 4.7 のプロジェクトマネージャで「インポート」→ このリポジトリの `project.godot` を選ぶ。
2. F5（プロジェクトを実行）。`res://scenes/main.tscn` が起動する。
3. CLI から起動する場合：

```
godot --path . 
godot --path . --editor      # エディタを開く
```

起動すると F06「磐戸市民センター・交番前広場」から始まる。他のフィールドは未実装のプレースホルダで表示される。
操作：WASD / 矢印で移動、Shift で忍び足、Z / Space / Enter で調べる、X / Esc でキャンセル（ゲームパッド：左スティック / D-pad、LB、A、B）。

## 描画仕様（厳守）

- タイル 16×16 px、基準解像度 384×216 px（16:9）。整数倍スケールで最大 4 倍（1536×864）
- Stretch Mode = `canvas_items`、Aspect = `keep`、Scale Mode = `integer`
- Default Texture Filter = Nearest。2D 変換と頂点はピクセルにスナップ
- パレットは 16 色固定。全描画は `Palette` autoload の配列からのみ色を参照する（`data/fields.json` → `meta.palette` と同一）
- フォントは PixelMplus12。テキストは整数座標に配置し、アンチエイリアスは無効
- マップは `TileMapLayer` で構成する。`TileMap` ノードは使用しない
- ドット絵 PNG は現時点で存在しない。タイルは `Image` / `ImageTexture` によるプロシージャル生成で暫定的に作る

## ディレクトリ構成

```
project.godot
data/                    静的データ（fields.json など）
scenes/
  main.tscn              エントリポイント
  fields/                各フィールドの .tscn（F01〜F16）と未実装プレースホルダ
  actors/                プレイヤー等
  ui/                    メッセージウィンドウ等の UI
  debug/                 確認用シーン（パレット・タイル一覧）
scripts/
  autoload/              シングルトン（Palette, GameState, FieldRegistry, SceneRouter, SteamBridge）
  actors/                アクターのスクリプト
  fields/                各フィールド固有のスクリプト（FieldBase を継承）
  systems/               共通システム（FieldBase, FieldData, Interactable, GameConstants …）
  ui/                    UI のスクリプト
  tools/                 タイル・スプライト生成（ゲームロジックから隔離）
  debug/                 確認用シーンのスクリプト
resources/
  tilesets/              生成・保存された TileSet
  fonts/                 PixelMplus12（後から配置）
docs/
  CONVENTIONS.md         コーディング規約
  field_build_order.md   フィールド作成の推奨順序（ステップ1 成果物C）
  tools/                 設計確認用ミニマップ（HTML）とそのビルドスクリプト
```

## 設計資料（ステップ1の成果物）

| 成果物 | パス | 内容 |
|---|---|---|
| A | `docs/tools/world_minimap.html` | 町全体を俯瞰する設計確認用ミニマップ（単一 HTML。ゲーム本体ではない） |
| B | `data/fields.json` | 16 フィールドの定義。`res://data/fields.json` としてそのまま読み込む |
| C | `docs/field_build_order.md` | `.tscn` 化の推奨順序と共有／固有タイル種別の切り分け |

`fields.json` を変更したら `python3 docs/tools/build_minimap.py` でミニマップを再生成する。

## Git 運用ルール（要約）

- `main` は常にビルド可能。直接コミット禁止。force push 禁止
- タスクごとに `main` から作業ブランチを切る：`feat/…` `fix/…` `chore/…` `docs/…`。1 ブランチ 1 タスク
- コミットは Conventional Commits 形式（`feat(player): …`、`chore(repo): …`）。本文は日本語可。意味のある単位で細かく分ける
- `.godot/` とインポートキャッシュは絶対にコミットしない（`.gitignore` 済み）
- PR は `main` 宛。本文に「概要／変更点／動作確認方法／未対応・既知の課題」を必ず書く
- レビュー承認後に squash マージし、ブランチを削除する。コンフリクトは自己判断で解決せず報告する

詳細な規約は `docs/CONVENTIONS.md` を参照。
