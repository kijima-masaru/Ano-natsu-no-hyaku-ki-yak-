# フィールド実装ガイド

F01・F02・F05・F06・F12 で固まった手順。Step 4 の 11 フィールドはこの手順に従う（Step 4 タスク 0 で `field_scaffold` と `validate_data` に置き換える予定。置き換え後もこの文書を正とし、ツールは手順を自動化するだけにする）。

## 0. 読むもの

- `data/fields.json` の当該エントリ：`size_tiles`・`exits`・`landmarks`・`interactables`・`required_tiles`・`story_role`・`horror_beat`・`ambience_track`
- `docs/SCENARIO.md` の当該フィールドの日程、`docs/CONCEALMENT_LIST.md` と `docs/DECEPTION_MAP.md` でそのフィールドに置く隠蔽・二層テキスト
- `docs/field_build_order.md` の「なぜこの順か」（共有タイルの確定状況）

## 1. ブランチ

`feat/fXX-<slug>`（例 `feat/f12-kihira`）。main から切る。1 フィールド 1 PR。

## 2. ファイル

| ファイル | 役割 |
|---|---|
| `scripts/fields/fXX_<slug>.gd` | `extends FieldBase`。地図・凡例・調べ物の座標・時間帯／日付の差し替え **だけ** を書く |
| `scenes/fields/fXX_<slug>.tscn` | ルート Node2D（script 付き、`default_spawn_tile`）＋ 子 `Ground` `Objects` `Overhead`（TileMapLayer）、`Actors` `Triggers`（Node2D） |
| `data/events.json` | 調べ物のテキスト・フラグ・隠蔽・P（`on_interact`, `field`, `target`） |
| `data/messages.json` | 日本語テキスト。二層は `truth_id` |
| `data/evidence.json` | 隠蔽・証拠の定義（既にあるものは `field` を確認） |

`scene_path` は `fields.json` に既に書かれている。名前を合わせれば `SceneRouter` がプレースホルダから自動で切り替わる。

## 3. 地図（MAP_ROWS）

1. 凡例を決める。`GROUND_LEGEND`（通行可）と `OBJECT_LEGEND`（通行不可）に **1 文字 → `TileCatalog` の種別名**。種別名は `fields.json` の `required_tiles` と同じ日本語。無い種別は `tile_catalog.gd` に追加し、`docs/TILESET_PIPELINE.md`「新しい種別を追加する」に従う。
2. Python で地図を組む（`rect()` `put()` の小さなスクリプト。過去の例はセッションの scratchpad、Step 4 では `field_scaffold` が生成）。
   - 外周 1 マスは壁。出口タイル（`exits[].tile`）だけを通行可で開ける。
   - 建物は「屋根／ベランダ 1 行 ＋ 壁 2〜3 行」。戸・窓・階段室は壁の **通り側** に置く。
   - 調べ物（`INTERACTABLES`）は通行不可タイルの上に置き、通行可タイルに隣接させる。
3. `python3 docs/tools/check_field_map.py scripts/fields/fXX_<slug>.gd` で寸法・外周・出口到達性・調べ物の隣接を確認。「注意」は意図したものか読む（境内のように入れない領域は可）。
4. `_build()` は凡例を引いて `set_tile()` するだけ。物体タイルの下地は `_ground_under()` のような小関数で決める（F12 参照）。

## 4. 調べ物と NPC

- `INTERACTABLES` は `{"id", "name", "tile", "kind"}`。`kind` は `object` / `sign` / `save_point` / `npc`。テキストは GDScript に書かない。
- NPC は `Interactable.create(..., "npc")` に `set_actor_sprite(kind, facing)`（`ActorSpriteGenerator` の種別 `toki` `heroine` など）。時間帯で出し入れするなら F05 の `_update_toki()` の形。
- `name` は見出し。日本語だが「題字・ラベル」扱いで許容している（`docs/CONVENTIONS.md` §10 の例外に準ずる）。長い文は必ず `messages.json`。

## 5. イベント（`data/events.json`）

- 1 調べ物につき最低 1 件の `on_interact`。同じ `target` に複数あるときは `priority` が高いものが 1 件だけ走る。日付・時間帯は `day_range` / `time_of_day`、状態は `conditions`。
- **調査 P の付け方**：P を与えるイベントは必ず `once: true`（無限取得を防ぐ）。再訪用に `priority: 0` の表示だけのイベントを分ける（`ev_f06_library` / `ev_f06_library_again`）。自由日は 1 日 3 P 必要。**その日に初めて開く供給源が 3 つ以上**あるか `docs/PLAYTEST_LOG.md` の要領で数える。
- **隠蔽**：`conceal_evidence` を持つイベントは `once: true` ＋ `add_points`、再表示用の `_after` イベントを `priority: 0` で置く（`conceal_evidence` は隠蔽済みなら `shown_id` を再表示する）。
- **二層テキスト**：`messages.json` に `truth_id` を付け、`docs/DECEPTION_MAP.md` の表に行を追加する。GDScript で `truth_revealed` を見ない。
- **就寝**：自宅フィールドだけ。`{"can_sleep": true}` 条件 → `sleep` アクション（F12 参照）。
- 追加したフラグは `docs/FLAGS.md` に行を足す。

## 6. 時間帯・日付

- `_apply_time_of_day(tod)`：灯り（`階段室（点灯・消灯）` ↔ `階段室（消灯）`、`ガラス扉（点灯）` ↔ `窓（消灯・点灯）`）、門の開閉、NPC の出し入れ。`Calendar.TIME_*` 定数で比較する。
- `_apply_day(day)`：日替わりの配置（F02 の洗濯物、F12 の点灯階の表 `LIT_FLOORS_BY_DAY`）。マジックナンバーは `const` に。
- 両方とも `_ready()` 直後と `Calendar` のシグナルで呼ばれる。`_apply_day` の最後で `_apply_time_of_day(Calendar.time_of_day)` を呼ぶと整合しやすい。

## 7. 環境音

`fields.json` の `ambience_track` が `data/audio.json` にあることを確認。無ければ `audio.json` に追加し、`docs/ASSETS_NEEDED.md` の表に行を足す（発注書）。

## 8. PR

- 本文は `## 概要` / `## 変更点` / `## 動作確認方法` / `## 未対応・既知の課題`。変更点に **二層テキスト・隠蔽の一覧表**（ID／表層／真相層／隠蔽 ID）を必ず載せる。
- 200 行を超えるファイルは理由を書く（地図 32 行＋凡例で 150 行前後が目安。超えるなら凡例や日替わり表を別ファイルに）。
- Godot 実機で確認できなかった項目は「動作確認方法」に番号付きで残す。

## 9. チェックリスト

- [ ] `MAP_ROWS` の寸法 ＝ `size_tiles`、`check_field_map.py` が OK
- [ ] 出口 4 方向すべてが `fields.json` と一致し、相手フィールドの受け口の座標も確認した
- [ ] `required_tiles` の種別がすべて `TileCatalog` にある（`tile_preview.tscn` で赤枠なし）
- [ ] 調べ物すべてに `on_interact` イベントがある（無いものは `msg_nothing_here` が出る）
- [ ] その日に開く P 供給源が 3 つ以上
- [ ] 二層テキスト・隠蔽を `DECEPTION_MAP.md` / `CONCEALMENT_LIST.md` に反映
- [ ] 新フラグを `FLAGS.md` に反映
- [ ] `docs/CONTENT_NOTICE.md` の描写原則（自死の方法・手段・場所・状態に触れない、死は常に事後）に反していない
- [ ] `.godot/` をコミットしていない
