# ステップ5の進捗と申し送り（v0.3.0 → タスク0 実機検証まで）

ステップ4「残り 11 フィールド、光源と夜、怪異演出、第一幕・第二幕の日程」の完了時点（PR #25〜#42）に、ステップ5 タスク0（実機検証）の結果を追記したもの。

## ステップ5の進捗

| # | ブランチ | 状態 |
|---|---|---|
| 0 | fix/runtime-verification | **済（PR #43）**。Godot 4.7.stable で起動〜8/29 を通し、不具合 7 件を修正（docs/PLAYTEST_LOG.md「実機検証」） |
| 1 | feat/d29-shige | **済（PR #44）**。8/29 F14 でシゲが澪に封石の戻し方を教える（`baba_told_seal`、任意到達） |
| 2 | feat/d30-seal | **済（PR #45）**。8/30 の封印：F16 奥の裂け目の口（落石が崩れる）、面を一枚ずつ四つの台座へ戻す配置パズル、封石を二人で押して `seal_restored`、`msg_natsu_008`、環境音の差し替え（`set_ambience`）、F01 の静まり返り |
| 3 | feat/truth-reveal | **済（PR #46）**。8/30 夜：帰路の余韻 → F12 自宅前で澪が事実を並べる（選択肢 2 回、結末不変）→ 提示画面（1 件ずつ、暗転と無音、初回スキップ不可）→ `truth_revealed` → ナツ `msg_natsu_009` → 澪が去る → 真相版の町を歩き F01 で 8/30 が終わる |
| 4 | feat/d31-endings | **済（PR #47）**。8/31 は澪を操作（`pov_mio`）。F05 → F01 → F12 → F13 → F15。橋の悠に「行かせない」。ED-A/B/C の分岐（FLAGS の条件）、暗転、翌朝の事後（新しいバリケード、揃えられた靴、トキの言葉）、`end_game` |
| 5 | feat/natsu-final | **済（PR #48）**。13 台詞＋労わり 5 件の通し読み（表層は一貫して優しく、真相は一貫して最悪）、真相版の話者色、8/5 の 003 流用を気配に変更、`entity_intro_done` の確認 |
| 6 | feat/end-game-flow | **済（PR #49）**。`end_game` の本実装：`user://system.json` にクリア記録（到達 ED 一覧・回数・初回日時・最後の ED・ED 別回数）→ 相談窓口案内 → スタッフロール → タイトル。周回「裏面から」（下記）。はじめから時に接近度と怪異回数を初期化 |
| 7 | feat/content-notice | **済（PR #50）**。起動時警告の文言確定（必須表示・決定で閉じる・0.8 秒の入力待ち）、相談窓口の読み込み口（`data/locale/ja/support.json`、案内画面の下段に最大 3 件）、`docs/STORE_PAGE.md`。**窓口の掲載は確認待ち**（`docs/CONTENT_NOTICE.md` §5） |
| 8 | chore/full-playtest | **済（PR #51）**。全 ED 到達・validate 0 件・セーブ復元・二層 118 件・隠蔽 17 件の提示・フラグ棚卸し・操作系・可読性・起動時間・推定プレイ時間を docs/PLAYTEST_LOG.md「通しプレイ」に記録。問題 10 件を一覧化（修正はタスク9） |
| 9 | fix/playtest-issues | **済（PR #52）**。問題 10 件の対処：修正 3 件（全体図の視認性、操作案内の装置別表記 `InputDevice`、検証スロットの後始末）、誤報 1 件（棚卸しスクリプト）、仕様確認 1 件、タスク10 へ 2 件（接近度、屋内の暗さ）、タスク12 へ 1 件（未参照フラグ）、素材待ち 1 件、保留 1 件 |
| 10 | chore/balance-tuning | **PR 済・承認待ち**。目標 2 時間〜3 時間半で合意。接近度 A 案（日付経過 0・初訪問 +1・怪異は初回のみ）→ 最短 52／全消費 75／目撃 100。歩行 64 px/s、8/16〜28 の P 5 → 4、屋内の暗さと明るさ既定 0.5、文字送り 0.7、`rotate` で daily の日替わり文 |
| 11〜13 | refactor/file-splitting 以降 | 未着手 |

### 次に何をすべきか
- タスク10 の PR をレビュー・マージ → `refactor/file-splitting`（200 行超 16 ファイルの整理。動作不変。`field_base` → `FieldNpcs` 切り出し、`Main` の初訪問 +1 P を `GameConstants` へ。機械的分割はしない）。
- 相談窓口：候補の一覧を提示済み。確認が取れたものだけ `data/locale/ja/support.json` に記入し、`meta.verified_at` を書く。
- **タスク6 の判断**：
  - 2 周目は軽い形で実装した。クリア後にタイトルへ「裏面から」が増え、8/1 から `truth_revealed` を立てて始める（二層 118 対がすべて真相版。イベント・日程・ED 条件は表と同じ）。題字の下にクリア数だけ「面」を並べる。追加テキストや新イベントは作らない（重ければ「裏面から」をメニューから外すだけで戻せる）。
  - セーブスロット：クリア後のセーブは作らない。オートセーブ枠（スロット 0）は 8/31 朝（`ev_d31_open` 直後）のままにし、「つづきから」で終幕をやり直せる。手動スロット 1〜3 も触らない。クリア記録はセーブとは別の `system.json` に持つ。
  - 終幕の案内とスタッフロールは `Main` の UI 層に載せる（`end_game` の直前の `fade` で黒になっているので、幕を上げてから読ませ、終わったら再び黒にしてタイトルへ）。
- **判断済み**（ユーザー委任）：イベント中は澪を止め目撃半径を追従距離より短くした（#43）／検証ドライバと `.gd.uid` は残す。**未解決**：接近度の加算・閾値（最短経路でも 8/21 に 100。ED-B・C に届かない）と屋内の暗さはタスク10で扱う。
- **実機で判明した不具合の一覧**：docs/PLAYTEST_LOG.md「見つかった不具合と対処」6 件（すべて修正済み）。未修正はフォント代替時の `content_notice` の行重なり、全体図の凡例の暗さ、終了時のリーク警告 2 件。

## Godot の用意（この環境）

`godot` コマンドは無いが、GitHub Releases から公式バイナリを取得して実行できる（プロキシ経由で 75 MB）。エクスポートテンプレート（タスク13）は同様に `Godot_v4.7-stable_export_templates.tpz` を取得する。
```
curl -sSL -o godot.zip https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip
unzip godot.zip && ./Godot_v4.7-stable_linux.x86_64 --headless --path . --import
```
描画確認は `xvfb-run -a -s "-screen 0 1152x648x24" ./Godot_v4.7-stable_linux.x86_64 --path . ...`（Mesa llvmpipe）。音声デバイスは無く dummy driver になる。

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
| セーブ | セクション：game_state / calendar / suspicion / anomalies / attached_entity。オートセーブ 9 箇所＋8/30・8/31 朝。位置は保存しない（ロードは屋外の既定位置）。クリア記録は `user://system.json`（`cleared_endings` `clear_count` `first_clear_at` `last_ending` `clears_by_ending`） |
| 進行 | タイトル → 8/1 → 8/31 → ED-A/B/C → 案内 → スタッフロール → タイトル（「裏面から」）まで実機（ドライバ）で通る |

## 実機検証の状況

タスク0 で Godot 4.7.stable により以下を確認済み（docs/PLAYTEST_LOG.md「実機検証」）：autoload 15 個の起動、16 フィールドの組み立てと F11 の階切替、8/1 → 8/29 の通し（最短・全消費の 2 経路）、daily の再発生、switch_floor 後の on_enter、sleep の遅延日送り、追跡者の捕獲と庇護、二層 102 対の切り替え、セーブ／ロードの往復、描画（Xvfb）。
**未実測**：人手によるプレイ時間（推定 2 時間 20 分〜3 時間 40 分）、GPU での描画負荷、ゲームパッド操作、Steam Deck。

## ステップ5で作るもの（想定。指示で上書きする）

- 8/30：`ev_d30_open` の本実装。封印の場（F16）、`seal_restored`、`show_concealment_reveal`、`truth_revealed` → 以後の二層テキストが真相版に切り替わる
- 8/31：`ev_d31_open`、御渡橋（F15）、`ending_reached` と分岐（`ending_a` ほか。`truth_partial_walk` `truth_partial_entity` は接近度と `baba_told_seal` で決まる。`docs/FLAGS.md`）、`end_game` アクションの本実装（クリア記録 → タイトル）
- ナツの残り：済（8/30 封印 008、提示画面直後 009、8/31 ED-A 010。`entity_intro_done` は 8/1 で立つ）
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

- **タスク1〜4 で立つようになった**：`baba_told_seal`（8/29）、`seal_restored`（8/30）、`truth_revealed` `truth_partial_walk` `truth_partial_entity`（8/30 夜）、`ending_reached` `ending_a/b/c`（8/31）、`pov_mio`（8/31）。`entity_intro_done` は 8/1 で立つ。定義済みで立たないフラグは無い。
- **立つが参照されない**：`d01_told` `found_odd_house` `saw_notifications`（振り返り用に残す。消すなら `docs/FLAGS.md` も）。
- **動的接頭辞**：`visited_ ev_done_ ev_day_ hid_ hid_fail_ seen_ day_ luck_ an_done_`。`luck_<n>` は追跡者に捕まった回数で立つ（最大 3。日付固定ではない）。
- `investigation_points_today` は `docs/FLAGS.md` に載っているが数値（`Calendar`）であってフラグではない。

## 既知の設計判断（変えるなら早めに）

- **タスク0 で見つかった設計上の論点**（判断待ち）：イベント中も澪が歩き続けるため同行中の隠蔽がほぼ失敗する／接近度が 8/21 までに 100 に達し ED-B・C に届かない／屋内の暗さが夜より明るい。docs/PLAYTEST_LOG.md 参照。
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
