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
- `Dictionary` を構造体代わりに使うのは JSON 読み込み直後の境界だけに限り、内部では専用クラス（`FieldDef` など）に変換する。
- 静的型チェックの警告（`UNTYPED_DECLARATION`, `INFERRED_DECLARATION` 以外）を **エラー扱い**にする設定を後続タスクで `project.godot` に追加する。

```gdscript
# 良い
var speed: float = 48.0
var field: FieldDef = FieldRegistry.get_field("F06")
func find_exit(to_id: String) -> ExitDef:

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
- 追加できるのは **横断的な状態・サービス**のみ。現時点で予定しているもの：

| 名前 | 役割 |
|---|---|
| `Palette` | 16 色パレットの唯一の定義 |
| `FieldRegistry` | `data/fields.json` の読み込みと `FieldDef` の提供 |
| `SceneRouter` | フィールド遷移とプレイヤー配置 |
| `GameState` | フラグ・所持品・セーブデータ |
| `SteamBridge` | GodotSteam への空実装インターフェース（実績・クラウドセーブのフック） |

- autoload はシーンツリーのノードを **保持しない**（参照は遷移で無効になる）。必要ならシグナルで受け渡す。
- autoload 同士の依存は一方向にする：`Palette` ← `FieldRegistry` ← `SceneRouter` ← `GameState`。逆方向の参照は禁止。
- `get_node("/root/Xxx")` で autoload を取らない。登録名で直接参照する。

## 6. 色とパレット

- **コード中で `Color("#xxxxxx")` や `Color(r, g, b)` による直接指定を行わない。**
  色は必ず `Palette.COLORS[Palette.<名前付き定数>]`（または `Palette.get_color(<定数>)`）から取得する。
- `.tscn` / `.tres` 内の `modulate` や `color` プロパティも同様。エディタで色を置いた場合は、対応する定数を `_ready()` で適用するか、テーマリソースに寄せる。
- 例外は「透明」`Color.TRANSPARENT` と「乗算で無変化」`Color.WHITE`（modulate の初期値）だけ。
- 光源の彩度を持つ色（自販機・街灯・蛍光灯・月）以外を発光表現に使わない。

## 7. ピクセル・座標

- `TILE_SIZE = 16` を定数として一箇所（後続の `Palette` と同格の共通定数）に定義し、マジックナンバー `16` を書かない。
- テキスト・UI ノードの座標は整数にする。`position = position.round()` を移動後に必ず行う。
- Sprite・TileMapLayer の `texture_filter` はプロジェクト既定（Nearest）に任せ、個別に変えない。
- `TileMap` ノードは使わない。`TileMapLayer` を層ごとに分ける（地面／建物・壁／装飾／光源／衝突）。

## 8. データ

- 静的データは `data/*.json`。読み込みは対応する autoload に集約し、他所で `FileAccess` を直接開かない。
- JSON のキーは snake_case。フィールド定義のスキーマは `data/fields.json` を正とし、変更時は `docs/tools/build_minimap.py` でミニマップを再生成する。

## 9. コメント・ドキュメント

- コメントは日本語で書いてよい。「何をしているか」より「なぜそうしているか」を書く。
- 公開関数には `##` ドキュメントコメントを付ける（エディタのヘルプに反映される）。
- TODO は `# TODO(step-N): …` の形式で、どのステップで解消する予定かを書く。

## 10. 禁止事項（まとめ）

1. `Color("#…")` 等の直接色指定
2. `TileMap` ノードの使用
3. `.godot/` とインポートキャッシュのコミット
4. `scripts/tools/` からゲームロジックへの依存
5. 兄弟ノードの直接参照
6. 型注釈の省略
7. 画像ファイル（PNG / SVG / base64）の生成やコミット（手描き素材が用意されるまで）
