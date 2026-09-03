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
| 補助ツール | Python 3（`docs/tools/validate_data.py` によるデータ検証、`docs/tools/flag_usage.py`、`docs/tools/build_minimap.py`） |

## 起動方法

1. Godot 4.7 のプロジェクトマネージャで「インポート」→ このリポジトリの `project.godot` を選ぶ。
2. F5（プロジェクトを実行）。タイトル `res://scenes/ui/title.tscn` が起動する。ゲーム本体は `res://scenes/main.tscn`。
3. CLI から起動する場合：

```
godot --path . 
godot --path . --editor      # エディタを開く
```

タイトルの「はじめる」で 8 月 1 日の自宅（F12）から始まる。セーブは `user://saves/slot_NN.json`（0 はオートセーブ）、設定・既読・クリア記録は `user://system.json`。16 フィールドと 8/1〜8/31 の全日程、エンディング 3 種、周回「裏面から」まで実装済み（v0.4.0）。画像・音声は差し替え待ちの生成素材で動く（`docs/ASSETS_NEEDED.md`）。
操作：WASD / 矢印で移動、Shift で忍び足、Z / Space / Enter で調べる、X / Esc でキャンセル、F で懐中電灯（ゲームパッド：左スティック / D-pad、LB、A、B、LT）。

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
data/                    静的データ（fields / schedule / events / messages / evidence / anomalies / items / audio）
  locale/ja/support.json 相談窓口（docs/CONTENT_NOTICE.md §5）
scenes/
  main.tscn              エントリポイント
  fields/                各フィールドの .tscn（F01〜F16）
  actors/                プレイヤー等
  ui/                    メッセージウィンドウ等の UI
  debug/                 確認用シーン（パレット・タイル一覧・検証ドライバの土台 playtest_driver.tscn）
scripts/
  autoload/              シングルトン 16 個（docs/CONVENTIONS.md §5 の表）
  actors/                アクターのスクリプト
  fields/                各フィールド固有のスクリプト（FieldBase を継承）
  systems/               共通システム（FieldBase, FieldData, Interactable, GameConstants …）
  ui/                    UI のスクリプト
  tools/                 タイル・スプライト・音の生成、データ検証（ゲームロジックから隔離）
    playtest/            実機検証ドライバ（docs/PLAYTEST_LOG.md）
  debug/                 確認用シーンのスクリプト
resources/
  tilesets/              生成・保存された TileSet
  fonts/                 PixelMplus12（後から配置）
docs/                    設計・運用資料（下表）
  tools/                 データ検証 validate_data.py、フラグ棚卸し flag_usage.py、ミニマップ生成
```

## 設計・運用資料

| 資料 | 内容 |
|---|---|
| `docs/NEXT_STEPS.md` | **最初に読む。** 現状と申し送り（ステップ6 の作業一覧、決定事項、手作業が要る項目） |
| `docs/SCENARIO.md` | 登場人物・世界設定・日程表・8/30〜31 の構成 |
| `docs/FLAGS.md` | フラグ一覧と接近度の閾値・加算 |
| `docs/EVENT_SCHEMA.md` / `docs/ANOMALY_SCHEMA.md` | `events.json` / `anomalies.json` の書式（トリガー・条件・アクション） |
| `docs/DECEPTION_MAP.md` / `docs/CONCEALMENT_LIST.md` | 二層テキスト 118 対、隠蔽 17 件 |
| `docs/CONTENT_NOTICE.md` | 描写制約、コンテンツ警告、相談窓口の掲載手順 |
| `docs/STORE_PAGE.md` | Steam ストアページ文案 |
| `docs/PLAYTEST_LOG.md` | 実機検証の記録（通しプレイ、閾値の確定、問題一覧） |
| `docs/ASSETS_NEEDED.md` | 素材の発注書 |
| `docs/CONVENTIONS.md` | コーディング規約と autoload の一覧 |
| `docs/FIELD_IMPLEMENTATION_GUIDE.md` / `docs/TILESET_PIPELINE.md` / `docs/field_build_order.md` | フィールドとタイルの作り方 |

## 検証（Godot が使える環境で）

```
python3 docs/tools/validate_data.py                                  # データ検証（CI と同じ）
godot --headless --path . -s scripts/tools/validate_data.gd           # 同じ検査の GDScript 版
godot --headless --path . res://scenes/debug/playtest_driver.tscn -- --runner=res://scripts/tools/playtest/driver_smoke.gd
godot --headless --path . res://scenes/debug/playtest_driver.tscn -- --runner=res://scripts/tools/playtest/driver_play.gd --stop-day=30
```

`godot` コマンドが無い環境では GitHub Releases の公式バイナリ（`Godot_v4.7-stable_linux.x86_64.zip`）を取得して使う（`docs/NEXT_STEPS.md`「Godot の用意」）。描画確認は `xvfb-run` で `driver_shots`。

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
