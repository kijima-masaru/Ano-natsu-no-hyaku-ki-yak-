# フラグ一覧

`GameState.flags`（`Dictionary[String, bool]`）で管理する真偽フラグの正本。
接近度などの数値は `Suspicion` autoload、日付は `Calendar` autoload が持ち、ここには「参照される閾値」だけを書く。
命名：`snake_case`。接頭辞 `truth_`＝真相系、`day_`＝日付進行、`ev_`＝イベント消化、`seen_`＝閲覧済み、`key_`＝鍵、`flag_`＝旧ステップ互換。
既存（ステップ2）のフラグは互換のため名前を変えない。

## 真相系（最重要）

| flag_id | 意味 | 立つ条件 | 参照箇所 |
|---|---|---|---|
| `truth_revealed` | 真相到達。**全テキストの二層分岐を切り替える唯一のフラグ** | 8/30 夜、澪との対決会話の終端（`ev_d30_confront`）。周回の「裏面」モード開始時 | `MessageResolver.resolve()`（単一の解決関数）、隠蔽リスト提示、ナツの話者色 |
| `truth_partial_walk` | 澪が「7/31 に隣を歩いたのは悠」と確定した | 接近度 ≥ 50 かつ証拠 `ev_timetable_pass` または `ev_shoe_mud` を澪が把握 | ED 判定、澪の独自発言 |
| `truth_partial_entity` | 澪がナツの存在に至った | 接近度 ≥ 75 かつ `baba_told_seal` | ED 判定（ED-A） |
| `ending_reached` | エンディング到達 | 8/31 御渡橋イベント終端 | タイトル復帰、システム保存 |
| `ending_a` / `ending_b` / `ending_c` | 到達した ED（排他） | §7 の条件で `ev_d31_bridge` が判定 | システム保存（周回）、タイトルの面の数 |

## 進行系（固定日）

| flag_id | 意味 | 立つ条件 | 参照箇所 |
|---|---|---|---|
| `prologue_done` | 8/1 の固定イベント完了 | F01 店先で澪と初対面の会話終端 | `schedule.json` day 1 `advance_condition` |
| `met_heroine` | 澪と名乗り合った | 8/1 夕方 | 多数のイベント条件 |
| `heard_testimony` | 「並んで歩いていた」証言を聞いた | 8/2 通夜の帰路、澪の話 | day 2 進行、F05 トキの会話分岐 |
| `companion_on` | 澪が同行中 | 8/3 朝に true。8/15 で一時 false、16 日に true | `Heroine` 追従、隠蔽の目撃判定 |
| `notebook_unlocked` | 証拠ノートが使える | 8/3 朝 | ノート UI |
| `saw_first_missing` | 掲示板の尋ね人が増えたのを見た | 8/5 F06 掲示板 | day 5 進行 |
| `entered_ren_room` | 蓮の部屋に入った | 8/8 初七日 | day 8 進行、F02 部屋の配置 |
| `key_tunnel_fence` | 隧道フェンスの鍵（既存） | F06 遺失物箱 | F03→F09 出口 lock |
| `stalker_met` | 追跡者と初遭遇 | 8/12 F03 | day 12 進行、`start_stalker` 以降の出現許可 |
| `baba_rage` | シゲが激昂した | 8/14 F14、悠合流時 | day 14 進行、**接近度を最低 30 に強制**、澪の段階テキスト |
| `obon_done` | 盆の灯明イベント | 8/15 F07 | day 15 進行、F08 開放 |
| `key_old_school` | 旧校舎の鍵（既存） | F11 職員室 | F11 旧校舎の扉 |
| `old_school_opened` | 旧校舎に入った | 8/19 | day 19 進行、F11 段階解放 |
| `learned_seal` | 封石の話を知った | 8/23 F04 日誌 | day 23 進行、F16 の目的提示 |
| `bridge_steps` | 御渡橋の足音イベント | 8/26 F15 | day 26 進行 |
| `flag_yakushi_open` | 薬師谷の落石が崩れた（既存） | 8/28 夕、自由日終了時に自動 | F14→F16 出口 lock |
| `baba_told_seal` | シゲが澪に封石の戻し方を教えた | 8/29 | day 29、`truth_partial_entity` |
| `entered_yakushi` | F16 に入った | 8/29 | day 29 進行 |
| `seal_restored` | 封石を戻した | 8/30 封印パズル完了 | 町の怪異停止、F01 静まり返り演出 |
| `flag_minimap_unlocked` | 全体マップ解放（既存） | F06 地図看板 | ミニマップ UI |

## 日付・探索系

| flag_id | 意味 | 立つ条件 | 参照箇所 |
|---|---|---|---|
| `day_<n>_started` | n 日目の開始イベントを消化した | `Calendar.advance_day()` 後の `opening_event` 終端 | 二重実行防止 |
| `day_<n>_done` | n 日目を終えた（就寝または固定イベント終端） | `Calendar` | 進行検証 |
| `visited_F<nn>` | フィールド初訪問 | `SceneRouter.field_entered` | ミニマップの表示、調査 P |
| `slept_at_home` | 一度でも就寝した | 初回就寝 | チュートリアル文の抑制 |

## 証拠・隠蔽系（`docs/CONCEALMENT_LIST.md` と対応）

| flag_id | 意味 | 立つ条件 | 参照箇所 |
|---|---|---|---|
| `ev_<evidence_id>` | 証拠 `<evidence_id>` をノートに記録した | `give_evidence` アクション | ノート、接近度 |
| `hid_<evidence_id>` | 証拠 `<evidence_id>` を隠蔽した（成功） | `conceal_evidence` アクション、澪が近くにいない | 隠蔽リスト提示、ED 判定 |
| `hid_fail_<evidence_id>` | 隠蔽が澪に目撃された | `conceal_evidence`、澪が半径 `HEROINE_WITNESS_RADIUS` 内 | 接近度 +20、ED-A 条件 |
| `seen_<message_id>` | 二層テキストの表層版を一度見た | `MessageResolver` | 真相到達時の「あなたが読んだ嘘」一覧 |

## 憑いた怪異（ナツ）系

| flag_id | 意味 | 立つ条件 | 参照箇所 |
|---|---|---|---|
| `entity_intro_done` | ナツが初めて話した | 8/1 回想直後 | 話者色の初出制御 |
| `luck_<n>` | 不自然な幸運 n 回目（1: 8/12 追跡者が悠を避ける、2: 8/19 校内、3: 8/26 橋） | 各イベント | 真相到達時の振り返り一覧 |

## 接近度の閾値（`Suspicion`、数値は非表示）

| 段階 | 範囲 | 澪の態度 | 悠の独白の調子 |
|---|---|---|---|
| 無自覚 | 0–24 | 相棒。悠を頼る | 淡々。ナツに「大丈夫」と言われて安心 |
| 違和感 | 25–49 | 質問が増える。悠の足音を数える | 「まだ、その必要はない」 |
| 疑念 | 50–74 | 距離を取る。先回りする。単独行動が増える | 「澪は、どこまで」 |
| 確信 | 75–100 | 悠を見る頻度が最大。会話が短い | 「終わらせ方を、考えておく」 |

- 8/14 `baba_rage` で最低 30 へ強制。以前は上限 24（無自覚を超えない）。
- 時間経過：日付が 1 進むごとに +1（8/14 以前）、+2（8/15 以降）。
- 証拠入手 +3〜+8、隠蔽失敗 +20、特定フィールド初訪問 +2、会話選択 −3〜+5。

## 数値・その他（`GameState`）

| 項目 | 型 | 意味 |
|---|---|---|
| `concealed_evidence` | `PackedStringArray` | 隠蔽成功した証拠 ID の列（順序保持） |
| `witnessed_concealments` | `PackedStringArray` | 隠蔽失敗した証拠 ID |
| `visited_fields` | `PackedStringArray` | 訪問済みフィールド |
| `investigation_points_today` | `int` | 当日の調査 P |
| `suspicion` | `int` | 接近度（`Suspicion` が所有し、セーブ時に GameState 経由で保存） |
| `day` / `time_of_day` | `int` / `String` | `Calendar` が所有 |
