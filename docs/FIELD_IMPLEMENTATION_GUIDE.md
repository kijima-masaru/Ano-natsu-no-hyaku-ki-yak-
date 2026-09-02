# フィールド実装ガイド（雛形生成 → タイル配置 → イベント記述 → 検証 → PR）

Step 4 の 11 フィールドはこの手順で量産する。共通処理はすべて `scripts/systems/field_base.gd`（`FieldMapBuilder`）と `scenes/fields/field_base.tscn` にある。**フィールド側のスクリプトに書くのは、地図・凡例・調べ物の座標・時間帯／日付の差し替えだけ**。同じコードを 2 回書いたら `FieldBase` に上げる。

## 0. 読むもの

- [ ] `data/fields.json` の当該エントリ：`size_tiles` `exits` `landmarks` `interactables` `required_tiles` `story_role` `horror_beat` `ambience_track`
- [ ] `docs/SCENARIO.md` の日程表でそのフィールドが使われる日、`docs/CONCEALMENT_LIST.md` と `docs/DECEPTION_MAP.md` でそこに置く隠蔽・二層テキスト
- [ ] `docs/field_build_order.md`（共有タイルの確定状況）、`docs/CONTENT_NOTICE.md`（描写の原則）

## 1. ブランチと雛形生成

- [ ] `git checkout main && git pull && git checkout -b feat/fXX-<slug>`（1 フィールド 1 PR）
- [ ] 雛形を生成する。どちらか一方。

```
# CLI（プロジェクトルート）
godot --headless --path . -s scripts/tools/field_scaffold.gd -- F03
# エディタ：scripts/tools/field_scaffold_editor.gd の FIELD_ID を書き換えて File > Run
```

生成されるもの（既存ファイルは上書きしない。`--force` / `FORCE` で上書き）：

| ファイル | 内容 |
|---|---|
| `scripts/fields/fXX_<slug>.gd` | 凡例の雛形、外周壁＋出口だけ開いた空地図、`interactables` から起こした調べ物の雛形（`tile` は `(-1, -1)` で要設定）、`_apply_time_of_day` / `_apply_day` の空実装、`required_tiles` のコメント一覧 |
| `scenes/fields/fXX_<slug>.tscn` | `field_base.tscn` を継承し、スクリプトと `default_spawn_tile`（最初の出口の内側）だけを持つ |
| `data/skeletons/fXX_<slug>.json` | `events.json` / `messages.json` に貼り込むイベントとメッセージのスケルトン（git 管理外） |

## 2. タイル配置（地図と凡例）

- [ ] `GROUND_LEGEND`（通行可）と `OBJECT_LEGEND`（通行不可）に **1 文字 → `TileCatalog` の種別名**。種別名は `fields.json` の `required_tiles` と同じ日本語。無い種別は `scripts/tools/tile_catalog.gd` に追加し、`docs/TILESET_PIPELINE.md`「新しい種別を追加する」に従う。
- [ ] `DEFAULT_GROUND` に物体タイルの下地を書く。場所で下地を変えるなら `_ground_under(x, y)` を上書き（F05 は街道／境内、F12 は区画表 `GROUND_ZONES`）。
- [ ] `MAP_ROWS` を描く。行が y、列が x。Python の `rect()` / `put()` で組んでから貼るのが速い。
  - 外周 1 マスは壁、出口タイルだけ通行可で開ける。
  - 建物は「屋根／ベランダ 1 行 ＋ 壁 2〜3 行」。戸・窓・階段室は壁の **通り側**。
  - 調べ物は通行不可タイルの上に置き、通行可タイルに隣接させる。
- [ ] Overhead（プレイヤーより手前）に描くものは `OVERHEAD_TILES: Array = [[Vector2i, 種別名], …]`。
- [ ] **光源は自動**。`LightCatalog` に載っている種別（街灯・自販機・蛍光灯・点灯した窓や扉・階段室・赤色灯）を Objects / Overhead に置くと `PointLight2D` が付く。消灯タイルへ差し替えれば消える。新しい光る種別は `scripts/tools/light_catalog.gd` に登録する。
- [ ] `INTERACTABLES` の `tile` と `name` を埋める。`kind` は `object` / `sign` / `save_point` / `npc`。テキストは書かない。
- [ ] 時間帯・日付で出し入れする NPC は `set_npc_present(id, present, tile, sprite_kind, facing)`（F01 澪、F05 トキ）。
- [ ] `_apply_time_of_day(tod)`：灯り（`階段室（点灯・消灯）` ↔ `階段室（消灯）`、`ガラス扉（点灯）` ↔ `窓（消灯・点灯）`）、門、NPC。`Calendar.TIME_*` で比較。
- [ ] `_apply_day(day)`：日替わりの配置。表は `const`（F12 `LIT_FLOORS_BY_DAY`）。最後に `_apply_time_of_day(Calendar.time_of_day)` を呼ぶ。

### 屋内の階（複数フロア）

- [ ] 屋内を持つフィールドは `FLOORS: Dictionary = {"1f": {"rows": ROWS_1F, "ground": …, "objects": …, "default_ground": …, "interactables": POI_1F}, …}` を定義する（F11 参照）。屋外は `outside`。
- [ ] 階の移動はイベントの `switch_floor` アクション（`floor`, `tile`, `facing`）。階段や戸口の調べ物に付ける。屋内の調べ物イベントには条件 `{"floor": "1f"}` を付ける（id は全階で一意にする）。
- [ ] 屋内は時間帯と独立に暗い（`FieldFloors.INDOOR_DARKNESS`。階ごとに `"darkness"` で上書き可）。非常灯など `LightCatalog` の光源を廊下に置く。
- [ ] 出口トリガーは屋外でだけ働く。追跡者は階の切替で消える（必要なら `on_enter` ＋ `floor` 条件で再配置）。
- [ ] `validate_data` は屋外の `MAP_ROWS` だけを検査する。階の地図は Python の生成スクリプトで到達性を確認する。

## 3. イベント記述（`data/events.json` / `data/messages.json`）

- [ ] `data/skeletons/fXX_<slug>.json` の `events` と `messages` を貼り込み、スケルトンを削除する。
- [ ] 調べ物ごとに最低 1 件の `on_interact`。同じ `target` に複数あるときは `priority` の高い 1 件だけ走る。日付・時間帯は `day_range` / `time_of_day`、状態は `conditions`（`docs/EVENT_SCHEMA.md`）。
- [ ] **調査 P**：`add_points` を持つイベントは必ず `once: true`。再訪用に表示だけの `priority: 0` イベントを分ける。自由日は「その日に初めて開く供給源が 3 つ以上」。
- [ ] **隠蔽**：`conceal_evidence` ＋ `add_points` の `once` イベントと、再表示用 `_after` イベント（`priority: 0`）。`data/evidence.json` に定義、`docs/CONCEALMENT_LIST.md` に行を追加。
- [ ] **二層テキスト**：`truth_id` を付け、`docs/DECEPTION_MAP.md` に行を追加。GDScript で `truth_revealed` を見ない。**最低 2 箇所**。
- [ ] **怪異**：`data/anomalies.json` にそのフィールド固有のものを最低 1 つ（`docs/ANOMALY_SCHEMA.md`。once / repeat / escalate）。
- [ ] 新しいフラグは `docs/FLAGS.md` に行を足す（検証ツールは FLAGS.md に無いフラグへの条件参照をエラーにする）。
- [ ] 環境音：`fields.json` の `ambience_track` が `data/audio.json` にあること。無ければ追加し `docs/ASSETS_NEEDED.md` に発注行を足す。
- [ ] 描写の原則：自死の方法・手段・場所・状態に触れない、死は常に事後、実在の固有名詞なし（`docs/CONTENT_NOTICE.md`）。

## 4. 検証

- [ ] `godot --headless --path . -s scripts/tools/validate_data.gd`（エディタなら `validate_data_editor.gd` を File > Run）。Godot が無い環境では `python3 docs/tools/validate_data.py`（同じ検査。CI もこれ）。
- [ ] **エラー 0 件** を確認する。注意は読んで意図どおりか判断する（境内など入れない領域の「孤立」は可）。
- [ ] Godot で起動し、出口 4 方向の遷移・調べ物・時間帯の見た目・環境音を確かめる。実機で確認できない項目は PR に番号付きで残す。

検証ツールが見るもの：出口の双方向性、シーンの実装状況、`MAP_ROWS` の寸法・外周・出口到達性・孤立領域、調べ物の隣接と `on_interact` の対応、events/evidence/schedule/audio からの ID 参照（フィールド・フラグ・アイテム・メッセージ・イベント・証拠・音）、二層テキストの片側欠落、話者、`on_day_start` の `day_range`、到達不能なフィールド、自由日の調査 P 供給と `once: false` の `add_points`。

## 5. PR

- [ ] コミットは意味のある単位（地図／イベント／日替わり…）で複数に分ける。
- [ ] 本文は `## 概要` / `## 変更点` / `## 動作確認方法` / `## 未対応・既知の課題`。変更点に **二層テキスト・隠蔽の一覧表**（ID／表層／真相層／隠蔽 ID）と、`validate_data` の結果（エラー 0、注意の内訳）を載せる。
- [ ] 200 行超のファイルは理由を書く（地図 32 行＋凡例で 150 行前後が目安）。
- [ ] `.godot/` をコミットしていない。

## 付録：FieldBase が提供するもの

| API | 用途 |
|---|---|
| 定数 `MAP_ROWS` `GROUND_LEGEND` `OBJECT_LEGEND` `DEFAULT_GROUND` `OVERHEAD_TILES` `INTERACTABLES` | `FieldMapBuilder` が `_build()` で読む。`_build` を書かない |
| `_ground_under(x, y) -> String` | 物体タイルの下地を場所で変える |
| `_apply_time_of_day(tod)` / `_apply_day(day)` | ツリー投入直後と `Calendar` のシグナルで呼ばれる |
| `set_tile(layer, tile, 種別名)` / `fill_rect` / `get_tile_type_at` | タイル操作。Objects / Overhead への配置は `LightCatalog` に従って光源も同期する |
| `add_interactable` / `get_interactable(id)` / `set_npc_present(...)` | 調べ物・NPC |
| `spawn_stalker` / `remove_stalker` / `get_stalker` | `start_stalker` アクションから使われる |
| `get_spawn_tile(from_id)` / `get_spawn_facing(from_id)` | 出口の内側への出現 |
| シグナル `exit_reached` / `interaction_started` | SceneRouter / Main が受ける。フィールド側で接続しない |

環境音の切替（`AudioManager`）、`on_enter` / `on_interact` の発火（`Main`）、カメラ境界とプレイヤー配置（`SceneRouter`）はフィールド側に一切書かない。
