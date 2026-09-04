# コーディング規約（GDScript / Godot 4.7）

このドキュメントは『磐戸町奇譚』の全 GDScript・シーン・リソースに適用する。
迷ったら Godot 公式の GDScript スタイルガイドに従い、ここに書かれた項目はそれより優先する。

## 1. ファイルとディレクトリ

| 種別 | 命名 | 例 |
|---|---|---|
| スクリプト `.gd` | snake_case | `scripts/actors/player.gd` |
| シーン `.tscn` | snake_case。フィールドは `fXX_<slug>.tscn` | `scenes/fields/f06_civic_center.tscn` |
| リソース `.tres` | snake_case | `resources/tilesets/common.tres` |
| autoload | 対応する `.gd` と同じ名前を PascalCase に | `scripts/autoload/palette.gd` → `Palette` |

- 1 ファイル 1 クラス。`class_name` はシーンに紐付かない再利用クラス（データ型・ユーティリティ）にだけ付ける。
- スクリプトは対応するディレクトリに置く。`scripts/tools/` はゲームロジックから参照されてよいが、`scripts/tools/` からゲームロジック（autoload を含む `Palette` 以外）を参照してはならない（素材生成の隔離）。

## 2. 命名

| 対象 | 規則 | 例 |
|---|---|---|
| クラス / ノード名 | PascalCase | `FieldRegistry`, `PlayerController` |
| 変数・関数・引数 | snake_case | `current_field_id`, `load_field()` |
| 定数 | UPPER_SNAKE_CASE | `TILE_SIZE`, `NIGHT_SKY` |
| enum 型 | PascalCase、値は UPPER_SNAKE_CASE | `enum Facing { NORTH, EAST, SOUTH, WEST }` |
| プライベート | 先頭 `_` | `_rebuild_cache()`, `_velocity` |
| シグナル | 過去形・snake_case（下記 §4） | `field_entered` |
| 真偽値 | `is_` / `has_` / `can_` で始める | `is_hidden`, `can_interact` |
| フィールド ID | 常に文字列 `"F01"`〜`"F16"`。整数に変換しない | `"F06"` |

## 3. 型注釈

- **すべて**の変数・引数・戻り値に型を付ける。推論に任せる `:=` は右辺の型が一目で分かる場合（リテラル、コンストラクタ、`as` キャスト）のみ許可。
- `Variant` を返す API（`JSON.parse_string` など）は受け取った直後に型を確定させる。
- 配列は要素型を明示する：`var exits: Array[Dictionary]`、`PackedStringArray` 等の Packed 型を優先。
- `Dictionary` を構造体代わりに使うのは JSON 読み込み直後の境界だけに限り、内部では専用クラス（`FieldData` / `ExitData` など）に変換する。
- 静的型チェックの警告（`UNTYPED_DECLARATION`, `INFERRED_DECLARATION` 以外）を **エラー扱い**にする設定を後続タスクで `project.godot` に追加する。

```gdscript
# 良い
var speed: float = 48.0
var field: FieldData = FieldRegistry.get_field("F06")
func find_exit(to_id: String) -> ExitData:

# 悪い
var speed = 48
var field = FieldRegistry.get_field("F06")
func find_exit(to_id):
```

## 4. シグナル

- 名前は **「何が起きたか」を過去形**で表す：`field_entered`, `interaction_started`, `flag_raised`。
  「〜してほしい」という命令形（`load_field`）はシグナルではなく関数にする。
- 引数は必ず型付きで宣言する：`signal field_entered(field_id: String, from_id: String)`
- 接続はコードで行う場合 `Callable` 構文を使う：`SceneRouter.field_entered.connect(_on_field_entered)`
- ハンドラ名は `_on_<送信元>_<シグナル名>`。送信元が自分自身なら `_on_<シグナル名>`。
- 子 → 親は **シグナルで上へ**、親 → 子は **関数呼び出しで下へ**。兄弟間の直接参照は禁止（autoload か親を経由）。

## 5. autoload（シングルトン）

- autoload は `scripts/autoload/` に置き、`project.godot` の `[autoload]` に登録する。登録名は PascalCase。
- 追加できるのは **横断的な状態・サービス**のみ。現在の 16 個（`project.godot` の順）：

| 名前 | 役割 |
|---|---|
| `Palette` | 16 色パレットの唯一の定義 |
| `GameState` | フラグ・所持品・証拠・隠蔽の記録・訪問・プレイ時間。`reset()` で `state_reset` を出し、各 autoload が周の値を初期化する |
| `MessageResolver` | `data/messages.json` と相談窓口。**二層テキストの分岐はここだけ**（`resolve`） |
| `InputDevice` | 最後に使った入力装置（キーボード／ゲームパッド）と、操作案内 `ui_hint_*` の装置別の文言（`hint(id)`） |
| `FieldRegistry` | `data/fields.json` の読み込み・スキーマ検証と `FieldData` / `ExitData` の提供 |
| `Calendar` | 日付・時間帯・調査ポイント・就寝・日程（`ScheduleLoader`） |
| `SceneRouter` | フィールド遷移・プレイヤーと澪の配置・暗転（`ScreenFade`） |
| `SaveManager` | スロット保存とシステム保存（設定・既読・クリア記録）。各 autoload の `register_section` |
| `EventSystem` | `data/events.json` の待ち行列と実行（読み込みは `EventLoader`、組み込みアクションは `EventActions`） |
| `Suspicion` | 澪の接近度（数値は非表示） |
| `EvidenceRegistry` | 証拠と隠蔽（`data/evidence.json`）、8/30 の提示画面 |
| `AudioManager` | BGM・環境音・SE と直近の音源（配線は `AudioMixer`、合成音は `SoundSynth`） |
| `Lighting` | 時間帯の色調・タイル光源・月光・懐中電灯 |
| `ScreenFx` | 画面効果（にじみ・上下端のぼかし・周辺減光のシェーダ、舞う葉・埃・蛍の粒子）。設定 `screen_fx` で切れる。判定には関わらない |
| `AttachedEntity` | ナツ（憑いた怪異）。労わり・幸運・気配 |
| `AnomalySystem` | 怪異（`data/anomalies.json`） |
| `SteamBridge` | GodotSteam への空実装インターフェース（実績・クラウドセーブのフック） |

- autoload はシーンツリーのノードを **保持しない**（参照は遷移で無効になる）。必要ならシグナルで受け渡す。
- autoload 同士の依存は一方向にする：`Palette` ← `GameState` ← `FieldRegistry` ← `SceneRouter`。逆方向の参照は禁止。
  `SteamBridge` は他の autoload に依存せず、`GameState` のセーブ処理からだけ呼ばれる。
  読み込み順（project.godot の `[autoload]`）もこの順に並べる。
- `get_node("/root/Xxx")` で autoload を取らない。登録名で直接参照する。

## 6. 色とパレット

- 色の唯一の定義は `scripts/autoload/palette.gd`（autoload 名 `Palette`）の `COLORS` である。
- **`palette.gd` 以外の場所で `Color("#xxxxxx")`、`Color(r, g, b)`、`Color.RED` などの直接指定を行わない。**
  色は必ず `Palette.get_color(Palette.<名前付き定数>)`（または `Palette.COLORS[Palette.<定数>]`）から取得する。
  透明度が必要なら `Palette.with_alpha(<定数>, alpha)` を使う。
- 名前付き定数は **用途で選ぶ**。`Palette.get_color(13)` のように番号を直接書かない。
- `.tscn` / `.tres` 内の `modulate` や `color` プロパティも同様。エディタで色を置いた場合は、対応する定数を `_ready()` で適用するか、テーマリソースに寄せる。
- 例外は「透明」`Color.TRANSPARENT` と「乗算で無変化」`Color.WHITE`（modulate の初期値）だけ。
- 発光・加算合成に使えるのは `Palette.LIGHT_SOURCES`（骨白・街灯の黄・自販機の赤・蛍光灯の青白）だけ。
- 光源は `PointLight2D` で表現し、色は `LightCatalog`（`scripts/tools/light_catalog.gd`）に種別名ごとに登録する。全体色調は `Lighting.tint_for()` がパレット色と `Color.WHITE` の補間で作る。フィールドや UI で `CanvasModulate` / `Light2D` を個別に置かない。
- 見え方は `scenes/debug/palette_preview.tscn` で確認する。パレットを変更する場合は `data/fields.json` の `meta.palette` も同時に更新する。
- 例外は描き込んだ PNG 素材（タイル・アクター・タイトル背景・光源テクスチャ）。これらは `tools/` の Python が自由な色数で描く。GDScript 側の色（UI・ライト・色調）は引き続き `Palette` から取る。

## 7. ピクセル・座標

- `TILE_SIZE = 16` を定数として一箇所（後続の `Palette` と同格の共通定数）に定義し、マジックナンバー `16` を書かない。
- テキスト・UI ノードの座標は整数にする。`position = position.round()` を移動後に必ず行う。
- Sprite・TileMapLayer の `texture_filter` はプロジェクト既定（Nearest）に任せ、個別に変えない。
- `TileMap` ノードは使わない。`TileMapLayer` を層ごとに分ける（地面／建物・壁／装飾／光源／衝突）。

## 8. データ

- 静的データは `data/*.json`。読み込みは対応する autoload に集約し、JSON の開閉・解析は `JsonFile.read_dict` / `write_dict`（`scripts/systems/json_file.gd`）に任せる。他所で `FileAccess` を直接開かない（例外：`scripts/tools/` の開発ツール `field_scaffold` / `validate_data` は autoload を使えないため JSON を直接読む）。
- フィールドの地図・凡例・調べ物は `const`（`MAP_ROWS` ほか）で宣言し、組み立ては `FieldMapBuilder` に任せる。フィールドスクリプトに `_build` や `Interactable.create` を書かない（`docs/FIELD_IMPLEMENTATION_GUIDE.md`）。
- JSON のキーは snake_case。フィールド定義のスキーマは `data/fields.json` を正とし、変更時は `docs/tools/build_minimap.py` でミニマップを再生成する。

## 9. コメント・ドキュメント

- コメントは日本語で書いてよい。「何をしているか」より「なぜそうしているか」を書く。
- 公開関数には `##` ドキュメントコメントを付ける（エディタのヘルプに反映される）。
- TODO は `# TODO(step-N): …` の形式で、どのステップで解消する予定かを書く。

## 10. テキストとイベント

- 日本語テキストは **すべて `data/messages.json`** に置き、`MessageResolver.text(id)` / `resolve(id)` で取得する。GDScript に日本語リテラルを書かない（例外：題字「磐戸町奇譚」、ログ・エラーメッセージ、コメント）。
- 二層テキスト（表層版／真相版）の分岐は `MessageResolver.resolve()` の中だけで行う。他の場所で `truth_revealed` を見てテキストを選ばない。
- ゲーム内容（会話・フラグ操作・入手・分岐）は `data/events.json` に書く。GDScript にはシステムだけを書く。
- 会話 UI は `scenes/ui/dialogue_window.tscn`。行分割は `TextLayout`（禁則処理）に任せ、手で改行位置を調整しない。

## 11. 禁止事項（まとめ）

1. `Color("#…")` 等の直接色指定
2. `TileMap` ノードの使用
3. `.godot/` とインポートキャッシュのコミット
4. `scripts/tools/` からゲームロジックへの依存
5. 兄弟ノードの直接参照
6. 型注釈の省略
7. 画像ファイル（PNG / SVG / base64）のゲーム内での実行時生成（`tools/` の Python が描いた PNG を `resources/` に置くのは可。PNG 素材は `Palette` の 16 色に縛られない）
8. GDScript への日本語テキスト直書き、`MessageResolver` を通さないテキスト取得
