# ステップ5への申し送り（v0.3.0 時点）

ステップ4「残り 11 フィールド、光源と夜、怪異演出、第一幕・第二幕の日程」の完了時点でのまとめ（PR #25〜#42）。
ステップ5は終幕（8/30〜31：封印・提示画面・`truth_revealed`・エンディング分岐・タイトルへの帰還）と仕上げが中心になる想定。指示が来るまで着手しない。

## 現状（何が動くか）

| 領域 | 状態 |
|---|---|
| フィールド | **16 フィールドすべて実装**（`docs/FIELD_IMPLEMENTATION_GUIDE.md` の手順、`FieldMapBuilder` ＋ ASCII 地図 ＋ `data/events.json`）。屋内の階は `FieldFloors`（F11 旧校舎 1 階） |
| 日程 | `data/schedule.json` 8/1〜8/31。**8/1〜8/29 は通しで机上確認済み**（`docs/PLAYTEST_LOG.md`）。8/30〜31 は `opening_event` がプレースホルダ |
| イベント | `data/events.json` 310 件。トリガ 4 種、`once` / `daily` / 優先度。条件 12 種、アクション 29 種。`EventValidator` ＋ `validate_data`（GDScript / Python、CI）で参照・地図・供給を検証 |
| テキスト | `data/messages.json` 639 件、**二層 102 対**（`docs/DECEPTION_MAP.md`）。分岐は `MessageResolver.resolve()` の中だけ |
| 証拠・隠蔽 | `data/evidence.json` 25 件（隠蔽 17・証拠 8）。**隠蔽 17 件すべてにイベントあり**（`docs/CONCEALMENT_LIST.md`）。提示画面 `ConcealmentReveal` は実装済み、8/30 への接続が未 |
| 怪異 | `AnomalySystem` ＋ `data/anomalies.json` 27 件（once 12・repeat 6・escalate 9）。全フィールドに 1 件以上。接近度への加算とナツの労わり |
| 光源 | `Lighting`：時間帯の色調、タイル光源（`LightCatalog` 16 種）、月光、懐中電灯（F）。追跡者の暗所ボーナスと照明下の視認距離 |
| 追跡者 | 8/12 F03（必須）、8/19 F11 1 階（必須）、8/13〜 F03/F04、8/19〜 F10、8/20〜 F11 の夜（任意）。捕獲は押し戻し、主人公は最大 3 回 `luck_<n>` で逃れる |
| セーブ | セクション：game_state / calendar / suspicion / anomalies / attached_entity。オートセーブ 9 箇所。位置は保存しない（ロードは屋外の既定位置） |
| 進行 | タイトル → 8/1 → 8/29 終了まで机上で通る。実機は未確認 |

## 未検証事項（最優先）

この環境には Godot 4.7 の実行ファイルが無く、**ステップ2〜4 の全コードは目視レビューのみ**。ステップ5の最初に Godot エディタで `docs/PLAYTEST_LOG.md`「実機で確認すること」の 8 項目を確認し、問題は `fix/` ブランチで直す。特に：

1. autoload 15 個の起動順と `_ready` の相互参照（`Lighting` → `AnomalySystem` → `AttachedEntity`）
2. `FieldMapBuilder.build()` が 16 フィールドの `get_script_constant_map()` を読めること（`FLOORS` を持つ F11 を含む）
3. `daily` イベントの翌日再発生、`switch_floor` 後の `on_enter` 再発火、`sleep` の遅延日送り
4. `PointLight2D` の枚数（F01・F13 で街灯が多い）と GL Compatibility での描画負荷
5. プレイ時間の実測（机上見積もり 1 時間 50 分〜2 時間 30 分）と閾値の確定

## ステップ5で作るもの（想定。指示で上書きする）

- 8/30：`ev_d30_open` の本実装。封印の場（F16）、`seal_restored`、`show_concealment_reveal`、`truth_revealed` → 以後の二層テキストが真相版に切り替わる
- 8/31：`ev_d31_open`、御渡橋（F15）、`ending_reached` と分岐（`ending_a` ほか。`truth_partial_walk` `truth_partial_entity` は接近度と `baba_told_seal` で決まる。`docs/FLAGS.md`）、`end_game` アクションの本実装（クリア記録 → タイトル）
- ナツの残り：`msg_natsu_008`（8/30 前夜）`msg_natsu_009`（提示画面の末尾、真相版）`msg_natsu_010`（8/31）を流すイベント。`entity_intro_done` を 8/1 の初台詞で立てる
- コンテンツ警告と相談窓口案内（`docs/CONTENT_NOTICE.md`）をタイトルとエンディング後に出す
- 素材差し替え（`docs/ASSETS_NEEDED.md` の優先順位どおり）と Steam 向けの設定（`SteamBridge` は空実装）

## 隠蔽リストの実装状況

17 件すべて実装済み。ID・イベント・場所・PR は `docs/CONCEALMENT_LIST.md` の「実装状況（v0.3.0）」表を正とする。
形は「`conceal_evidence` ＋ `add_points` の `once`（優先度 5〜10）」＋「`_after`（優先度 0）」＋ 日付前の `_early`。例外：C-01 は 8/1 の選択肢から、C-02 / C-05 は 8/8 の部屋メニューから、C-09 は `once: false` 単独、C-08 は再訪が `daily` の図書室イベント。
ステップ5で触るのは提示画面への接続のみ。**表示文と「実際にしたこと」は `data/evidence.json` の `shown_id` / `action_id`** で、`docs/CONCEALMENT_LIST.md` の文言と一致させてある。

## 二層テキストの棚卸し（102 対）

`docs/DECEPTION_MAP.md` を正とする。内訳（`truth_id` を持つ表層の数）：

| 区分 | 対数 | 備考 |
|---|---|---|
| ナツ（`msg_natsu_001`〜`013`、労わり 5） | 18 | **`msg_natsu_008` `009` `010` を流すイベントが無い**（8/30〜31、ステップ5）。労わり 5 は `entity_comfort` から |
| 悠の独白（`msg_yu_stage_1`〜`3`） | 3 | `Main` が接近度の段階上昇で出す（コード側で ID を組み立てる） |
| 回想（7/31 3 枚、六月 2 枚） | 5 | 8/1・8/23 |
| 澪（`msg_mio_001`〜`004`、`msg_d01_mio_4`） | 5 | 8/2・8/12・8/19・8/26 の on_day_start と 8/1 |
| 日の導入（`msg_d20_open` `msg_d22_open` `msg_d29_night_1`） | 3 | 8/20・8/22・8/29 |
| 怪異の地の文（`msg_an_*`） | 8 | F01 F03 F04 F06 F09 F11 F14 F15 |
| フィールドの地の文・看板・物（`msg_fNN_*`） | 60 | F01 3、F02 5、F03 4、F04 4、F05 3、F06 2、F07 4、F08 4、F09 3、F10 2、F11 7、F12 4、F13 3、F14 4、F15 4、F16 4 |

`truth_revealed` は 8/30 まで立たないので、真相版は現状どこにも表示されない。切り替わりの実機確認はステップ5の最初に `truth_revealed` を手で立てて行う。

## フラグの棚卸し

- **定義済みでまだ立たない**（ステップ5で立てる）：`seal_restored`（8/30 封印）、`truth_revealed`（8/30）、`truth_partial_walk` `truth_partial_entity`、`ending_reached` `ending_a`、`baba_told_seal`（8/29 シゲが澪に封石の戻し方を教える。現状の 8/29 は F16 のみで F14 のイベントが無い）、`entity_intro_done`（8/1 の初台詞で立てる予定だったが未使用）。
- **立つが参照されない**：`d01_told` `found_odd_house` `saw_notifications`（振り返り用に残す。消すなら `docs/FLAGS.md` も）。
- **動的接頭辞**：`visited_ ev_done_ ev_day_ hid_ hid_fail_ seen_ day_ luck_ an_done_`。`luck_<n>` は追跡者に捕まった回数で立つ（最大 3。日付固定ではない）。
- `investigation_points_today` は `docs/FLAGS.md` に載っているが数値（`Calendar`）であってフラグではない。

## 既知の設計判断（変えるなら早めに）

- 位置はセーブしない（ロードは常に屋外の既定位置）。屋内でのオートセーブ後にロードすると屋外に出る。位置を保存するなら `SceneRouter` にセクションを足し、`current_floor` も含める。
- 初訪問 +1 P は `Main` に直書き（`GameConstants` へ移す候補）。
- 支所の「閉庁」文は 8/1・8/2 のみ。曜日条件（`weekday`）は未実装。
- シゲ（F14）はトキの絵を流用（`set_npc_present(..., "toki", ...)`）。素材が来たら種別を `shige` に。
- 8/11・8/17・8/21〜22・8/27〜28 は `daily` だけで P を満たす日。daily 文が単調なら日ごとの一行に分ける。
- **200 行超**：`stalker.gd`(305) `field_base.gd`(293) `scene_router.gd`(289) `audio_manager.gd`(282) `event_system.gd`(276) `tile_painters_ground.gd`(257) `calendar.gd`(248) `data_checks_fields.gd`(242) `data_checks_refs.gd`(230) `tile_painters_objects.gd`(229) `save_manager.gd`(219) `tile_catalog.gd`(215) `tile_painters_built.gd`(211) `game_state.gd`(211) `main.gd`(209) `lighting.gd`(202)。理由は各 PR。`field_base.gd` は `set_npc_present` / `add_point_of_interest` を `FieldNpcs` へ切り出す候補。

## 手作業が必要な項目（環境の制約で未実施）

- タグのプッシュ：`git push origin v0.1.0 v0.2.0 v0.3.0`（この環境からはプロキシに落とされ、リモートにタグが 0 件）
- GitHub の既定ブランチを `main` に切り替える（現在は `claude/iwato-field-design-vfrev4`）
- マージ済みリモートブランチの削除（PR #1〜#42 の各ブランチ。`git push origin --delete <branch>` は 403）
- Godot 4.7 での実機確認（上記）

## 運用

- main 直接コミット禁止、`feat/` `fix/` `chore/` `docs/` ブランチ → PR → squash マージ。PR 本文は 概要／変更点／動作確認方法／未対応・既知の課題
- コミットは Conventional Commits（本文は日本語）。`.godot/` は絶対にコミットしない
- 200 行超は分割を検討し、理由を PR に書く
- 日本語テキストは `data/messages.json`、ゲーム内容は `data/events.json`、GDScript はシステムだけ。二層の分岐は `MessageResolver.resolve` の中だけ
- 自死の方法・手段・場所・状態は書かない。死は常に事後。怪異の正体は説明しきらない。実在の固有名詞を使わない。`docs/CONTENT_NOTICE.md`
