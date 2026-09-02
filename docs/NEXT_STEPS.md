# ステップ3への申し送り（v0.1.0 時点）

ステップ2「Godot プロジェクト基盤とコアシステム」の完了時点でのまとめ。
ステップ3は残り 15 フィールドの実装。着手順は `docs/field_build_order.md` に従う。

## 現状（何が動くか）

| 領域 | 状態 |
|---|---|
| プロジェクト設定 | 384×216 / canvas_items / keep / integer / Nearest / GL Compatibility。入力アクション 7 種（KB＋パッド） |
| パレット | `Palette` autoload に 16 色。`palette_preview.tscn` で確認 |
| タイル | `TileGenerator` が `fields.json` の 163 種別すべてを生成。`TileSetProvider` で生成／`.tres` 読込を切替。`tile_preview.tscn` で一覧 |
| データ | `FieldRegistry` が `fields.json` を検証付きで読込。`GameState` がフラグ・所持品・現在地を保持 |
| プレイヤー | 4 方向・加減速・忍び足・足音シグナル・前方の調べ判定。16×24 の生成スプライト |
| 遷移 | `SceneRouter` が出口タイルで暗転遷移、鍵判定、未実装フィールドはプレースホルダ |
| フィールド | **F06 のみ実装**。他 15 は `field_placeholder.tscn` |
| UI | `MessageWindow`（固定幅、逐次表示、代替フォント対応） |
| Steam | `SteamBridge` は空実装 |

## 未検証事項（最優先で確認すること）

この環境には Godot 4.7 の実行ファイルが無く、**全コードは目視レビューのみで実機起動していない**。
ステップ3の最初に、以下を Godot エディタで確認し、出た問題は `fix/` ブランチで直す。

1. プロジェクトが開き、autoload 5 つとインポートが通る（`.godot/` が生成される。コミットしない）
2. `scenes/debug/palette_preview.tscn`、`tile_preview.tscn` が動く。`const COLORS: PackedColorArray = [Color("#…")]` の定数畳み込み
3. `tile_preview` の起動ログに「required_tiles 163 件はすべて対応表にあります」。フォールバック（赤枠）が無い
4. F5 で F06 が表示され、5 出口の遷移・施錠メッセージ・調べ物が動く（PR #7 の手順）
5. `project.godot` の `[input]` 直書き書式がエディタの入力マップに正しく表示される
6. `[debug]` の `untyped_declaration=2` により型注釈漏れがエラーになっていないか（出たら直す）
7. `Camera2D` の current 化とフィールド境界の limit
8. `Dictionary[String, bool]`（GameState.flags）、`match facing: Vector2i.DOWN:` の記法

## 既知の設計判断（変えるなら早めに）

- **フィールドの組み立て方**：F06 は ASCII 地図（`MAP_ROWS`）から `_build()` で組む。エディタで描くなら `TileSetProvider.save_generated()` で `.tres` を作り `iwato/tileset/source="resource"` にしてから TileMapLayer を直接編集し、`_build()` を空にする。混在させないこと
- **初期フィールド**：`GameState.INITIAL_FIELD_ID = "F06"`。F01 実装後に `"F01"` へ変更（TODO 記載済み）
- **鍵の入手場所**：`key_tunnel_fence` は F06 遺失物箱、`key_old_school` は F11 職員室（未実装）、`flag_yakushi_open` は終盤イベント（未実装）
- **autoload 依存方向**：`Palette ← GameState ← FieldRegistry ← SceneRouter`。`SteamBridge` は独立
- **200 行超のファイル**：`tile_painters_ground.gd`(257) `tile_painters_objects.gd`(229) `tile_painters_built.gd`(211) `tile_catalog.gd`(215) `scene_router.gd`(210)。理由は各 PR に記載。ペインタ追加時はさらに分割を検討

## ステップ3で作るもの

### フィールド（`docs/field_build_order.md` の順）
F01 → F05 → F02 → F12（序盤の環状ルート完成）→ F07 → F11 → F13 → F10 → F15 → F03 → F08 → F14 → F04 → F09 → F16

各フィールドの雛形：
1. `scripts/fields/fXX_<slug>.gd`（`extends FieldBase`）と `scenes/fields/fXX_<slug>.tscn`（ルート Node2D、子に Ground / Objects / Actors / Overhead / Triggers）
2. `MAP_ROWS` を `fields.json` の `size_tiles` と一致させ、`exits[].tile` を通行可にし、外周は出口以外を閉じる
3. `interactables` を `Interactable.create()` で置き、フラグ操作は `interacted` に接続
4. `fields.json` の `required_tiles` に無い種別を使ったら JSON にも追加する
5. `default_spawn_tile` を設定（出口以外からの出現位置）

### システム
- **NPC と会話**：F05 駄菓子屋の店主。`Interactable` の `kind="npc"` と会話データの形式
- **室内**：F06 図書室、F11 旧校舎など。同一フィールド内のサブシーン切替か別フィールド扱いかを決める
- **光源**：`PointLight2D`＋パレット光源 4 色。GL Compatibility での 2D ライトの挙動確認
- **聴覚**：`Player.noise_emitted(radius)` を受ける敵／気配システム
- **セーブ**：`GameState.save_game/load_game` の I/O（`user://saves/slot_XX.json`）と `SteamBridge.cloud_save`
- **ミニマップ UI**：`flag_minimap_unlocked` で解放。`docs/tools/world_minimap.html` の配置を流用
- **フォント**：`resources/fonts/PixelMplus12-Regular.ttf` を配置（README 参照）

### 素材差し替えの準備
- `TileSetProvider.save_generated()` で `common.tres` を作り、`docs/TILESET_PIPELINE.md` の手順で PNG に差し替える
- アクタースプライトは `ActorSpriteGenerator.get_texture` の返却先を `SpriteFrames` に置き換える

## 運用
- main 直接コミット禁止、`feat/` `fix/` `chore/` `docs/` ブランチ → PR → squash マージ
- コミットは Conventional Commits。`.godot/` は絶対にコミットしない
- 200 行超は分割を検討し、理由を PR に書く
