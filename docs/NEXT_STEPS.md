# ステップ4への申し送り（v0.2.0 時点）

ステップ3「探索コアループの完成とプロローグの実装」の完了時点でのまとめ（PR #9〜#24）。
ステップ4は残り 11 フィールド、光源、怪異演出、第一幕・第二幕の日程、v0.3.0。**タスク 0（`chore/field-pipeline`）は設計を提示して確認を得てから実装する**（ステップ4の指示）。

## 現状（何が動くか）

| 領域 | 状態 |
|---|---|
| 日程 | `Calendar` ＋ `data/schedule.json`（8/1〜8/31、固定／自由／圧縮）。自由日は 3 P で就寝可、P で時間帯が進む。自宅 F12 |
| セーブ | `SaveManager`（セクション登録方式、`user://saves/slot_NN.json`、0 はオート、`system.json` に設定）。`SaveMigrator` schema 2 |
| イベント | `EventSystem` ＋ `data/events.json`（99 件）。トリガ 4 種、条件（flag/has_item/field_visited/day/day_range/time_of_day/not/any/all/suspicion/can_sleep）、アクション 27 種。`EventValidator` が起動時に参照を検証 |
| テキスト | `MessageResolver` ＋ `data/messages.json`（320 件、二層 38 対）。分岐は `resolve()` の中だけ。`DialogueWindow`（話者色・速度・選択肢） |
| 証拠・接近度 | `EvidenceRegistry`（13 件、隠蔽 9・証拠 4）、`Suspicion`（0〜100、4 段階、目撃 +20）。ノート UI（N）、8/30 の提示画面 |
| 音 | `AudioManager` ＋ `SoundSynth`（合成 WAV）＋ `data/audio.json`。フィールドごとの環境音、夜変奏、蝉の減衰 |
| アクター | `Player`、`Heroine`（追従・段階で距離と視線）、`Stalker`（FSM・聴覚・視野・捕獲→押し戻し）、`AttachedEntity`（ナツ、声と気配だけ） |
| フィールド | **F01・F02・F05・F06・F12 実装**（序盤の環状ルート完成）。残り 11 はプレースホルダ |
| UI | タイトル、スロット、設定、コンテンツ警告、日付 HUD、ミニマップ（M / Tab / Y）、デバッグオーバーレイ |
| 進行 | タイトル → 8/1 → 8/4（第一幕の入口）まで机上で通る（`docs/PLAYTEST_LOG.md`） |

## 未検証事項（最優先）

この環境には Godot 4.7 の実行ファイルが無く、**ステップ2・3 の全コードは目視レビューのみ**。ステップ4の最初に Godot エディタで以下を確認し、問題は `fix/` ブランチで直す。

1. プロジェクトが開き、autoload 13 個・`EventValidator`・`FieldSchemaValidator` の起動時検証が通る
2. `docs/PLAYTEST_LOG.md`「実機で確認すること」の 7 項目
3. `sleep` アクションの `event_finished` 遅延接続：就寝 → 翌日の開始メッセージ → `opening_event` の順に表示され、入力ロックが戻る
4. `Heroine` の追従と `EvidenceRegistry.set_witness_check`（64px）の実距離感
5. `Stalker` は呼び出すイベントがまだ無い。`scenes/actors/stalker.tscn` を任意のフィールドに置いて FSM を単体確認する
6. `SoundSynth` の生成音量（`AudioManager` の各バス既定値）と `PixelMplus12` 不在時の代替フォント
7. `untyped_declaration=2` での型注釈エラー、`Object.CONNECT_ONE_SHOT | Object.CONNECT_DEFERRED` の記法

## 既知の設計判断（変えるなら早めに）

- **フィールドは ASCII 地図 ＋ `data/events.json`**。共通処理は `FieldBase` / `FieldMapBuilder` / `scenes/fields/field_base.tscn`。雛形は `scripts/tools/field_scaffold.gd`、検証は `scripts/tools/validate_data.gd`（Godot 無しなら `docs/tools/validate_data.py`。CI もこれ）。手順は `docs/FIELD_IMPLEMENTATION_GUIDE.md`（タスク 0 で整備済み）。
- **調査 P**：P を与えるイベントは `once: true`。自由日は「その日に初めて開く供給源が 3 つ以上」を保証する（8/3・8/4 は確認済み）。初訪問 +1 P は `Main` に直書き → `GameConstants` へ。
- **就寝**：`can_sleep` 条件 ＋ `sleep` アクション。プレースホルダの仮寝床は旧方式（`Calendar.try_sleep` 直呼び）のまま残っている。
- **隠蔽イベントの形**：`conceal_evidence` ＋ `add_points` の `once` イベントと、再表示用 `_after` イベントの 2 本。
- **F01 の 8/1 用 `mio_npc`** は 8/3 以降の夕方にも立つ。`companion_on` のとき出さない修正を F01 側で（ステップ4）。
- **支所の週末**：8/1・8/2 だけ「閉庁」文。曜日条件（`weekday`）を `ConditionEvaluator` に足すと 8/8・8/9 以降も揃う。
- **200 行超**：`stalker.gd`(297) `scene_router.gd`(283) `audio_manager.gd`(282) `tile_painters_ground.gd`(257) `event_system.gd`(254) `calendar.gd`(248) `field_base.gd`(240) `tile_painters_objects.gd`(229) `save_manager.gd`(219) `tile_catalog.gd`(215) `tile_painters_built.gd`(211) `game_state.gd`(211)。理由は各 PR。`tile_catalog.gd` はステップ4で種別が増えるため分割候補。

## フラグの棚卸し

`docs/FLAGS.md` に定義済みで **まだどのイベントも立てていない** もの（ステップ4で立てる）：
`saw_first_missing`（8/5 F06 掲示板）、`stalker_met`（8/12 F03）、`baba_told_seal` `baba_rage`（8/14 F14 シゲ）、`obon_done`、`learned_seal`、`entered_yakushi`、`flag_yakushi_open`（8/28 schedule の `set_flags_on_end` で立つ）、`seal_restored`、`truth_revealed`（8/30）、`truth_partial_walk` `truth_partial_entity`、`ending_reached` `ending_a`、`entity_intro_done`、`luck_<n>`、`key_old_school`（F11）、`old_school_opened`、`bridge_steps`。
`companion_on` `notebook_unlocked` は schedule の `set_flags_on_start` で立つ。`slept_at_home` は `sleep` アクション、`hid_*` `hid_fail_*` `ev_*` は `EvidenceRegistry`、`seen_*` は `MessageResolver`。

## 二層テキストの棚卸し（38 対）

ナツ 17（`msg_natsu_001`〜`012`、`comfort_*` 5）、回想 3（`msg_recall_0731_a/b/c`）、F01 3（`msg_f01_vending` `msg_f01_trash` `msg_f01_bridge`）、F02 6（`msg_f02_door` `msg_f02_smell` `msg_f02_room_desk` `msg_f02_mother` `msg_f02_laundry` `msg_mio_001`）、F05 3（`msg_f05_storefront` `msg_f05_toki_testimony_3` `msg_f05_signpost`）、F06 1（`msg_f06_board`）、F12 4（`msg_f12_home` `msg_f12_shoes` `msg_f12_slide` `msg_f12_bike`）、その他 1（`msg_d01_mio_4`）。
`docs/DECEPTION_MAP.md` の 37 対のうち未実装：`msg_mio_002`〜`005`、`msg_f04_journal`、`msg_natsu_010`〜`012` を流すイベント（台詞自体は定義済み）。

## ステップ4で作るもの（指示の要約）

0. `chore/field-pipeline`：済（PR #25）。`FieldMapBuilder` への共通化、`field_scaffold`、`validate_data`（GDScript ＋ Python）、ガイドの全面改訂
1. フィールド 11（Step 4 指示の順）：F03（済 PR #28）→ F13（済 PR #29）→ F10（済 PR #30）→ F07（済 PR #31）→ F08（済 PR #32）→ F09（済 PR #33）→ F14 → F15 → F04 → F11 → F16。各 1 PR、`FIELD_IMPLEMENTATION_GUIDE.md` に従う
2. `feat/lighting-and-night`：済（PR #26）。`Lighting` autoload（CanvasModulate の時間帯色調・明るさ設定・タイル光源・月光・懐中電灯）、Stalker の暗所ボーナスと照明下の視認距離
3. `feat/anomaly-encounters`：済（PR #27）。`AnomalySystem` ＋ `data/anomalies.json`（once / repeat / escalate、接近度、憑いた怪異の介入）。既存 5 フィールドに各 1 件
4. `feat/schedule-act1` `feat/schedule-act2`：8/5〜8/31 のイベント、中盤の老婆（F14 シゲ）の激昂、8/30 の提示画面と `truth_revealed`、終幕の澪操作
5. `chore/act2-playtest`：通しの机上／実機確認、v0.3.0

## 手作業が必要な項目（環境の制約で未実施）

- タグ `v0.1.0` `v0.2.0` のプッシュ：`git push origin v0.1.0 v0.2.0`（この環境からは HTTP 403）
- GitHub の既定ブランチを `main` に切り替える（現在は `claude/iwato-field-design-vfrev4`）
- マージ済みリモートブランチの削除（`git push origin --delete <branch>`。PR #1〜#24 の各ブランチ）

## 運用

- main 直接コミット禁止、`feat/` `fix/` `chore/` `docs/` ブランチ → PR → squash マージ
- コミットは Conventional Commits（本文は日本語）。`.godot/` は絶対にコミットしない
- 200 行超は分割を検討し、理由を PR に書く
- 日本語テキストは `data/messages.json`、ゲーム内容は `data/events.json`、GDScript はシステムだけ
- 自死の方法・手段・場所・状態は書かない。死は常に事後。`docs/CONTENT_NOTICE.md`
