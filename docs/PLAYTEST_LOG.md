# プレイテスト記録（v0.2.0 プロローグ 8/1〜8/4）

**方式：机上確認（デスクチェック）。** この環境には Godot 4.7 の実行ファイルが無いため、`data/schedule.json`・`data/events.json`・`data/messages.json`・各フィールドスクリプトを突き合わせて進行を追った。実機での確認項目は末尾の「実機で確認すること」にまとめた。

対象コミット：`main` の v0.2.0 タグ（PR #9〜#24）。

## 進行の前提

- 開始：タイトル →「はじめる」→ `SceneRouter.start()` が `GameState.INITIAL_FIELD_ID` のフィールドを出し、`Main._run_opening_event_if_needed()` が day 1 の `opening_event` を流す。
- 就寝：自宅 F12 の `home_door` を調べ、`can_sleep`（自宅にいる かつ 当日の進行条件を満たす）で `sleep` アクション → `Calendar.try_sleep()` → 翌日。
- 調査 P：自由日（day 3・4）は 3 P で就寝可。P はフィールド初訪問（`Main` が `field_visited` に +1）と `add_points` アクションで得る。日をまたぐと 0 に戻る。

## 8/1（土・固定）報せ

| # | 操作 | 期待する結果 | 判定 |
|---|---|---|---|
| 1 | 開始 | `ev_d01_open`：7/31 の回想 3 枚（表層版）→ ナツ `msg_natsu_001` → 目覚め → 母の報せ → 「行く、と答えた」→ `d01_told` | ○ |
| 2 | F12 自宅前（8,28）に出現。自宅（C 棟 1 階の消灯した階段室）を調べる | `ev_f12_home_d1_choice`：玄関の靴 → 選択肢「靴を揃える／やめる」 | ○ |
| 3 | 「靴を揃える」 | `ev_f12_shoes`：`msg_f12_shoes`（表層：雨の泥）→ C-01 `shoe_mud` 隠蔽 →「靴を揃えた。」。澪不在のため目撃なし。`hid_shoe_mud` | ○ |
| 4 | もう一度自宅を調べる | `ev_f12_home_d1_morning`：母「行くなら、早くね」→ 今は戻れない | ○ |
| 5 | 支所・集合ポスト・滑り台・給水塔・掲示板を調べる | 週末文（支所閉庁、ポストはチラシのみ）。階段室は A=1F B=2F C=3F D=1F が点灯 | ○ |
| 6 | 北出口 (8,0) → F01 | F01 (13,47) の内側に出現。F02/F05/F06 への出口は `passage_closed_today`（8/1 は F12・F01 のみ） | ○ |
| 7 | F01 店の戸 | `ev_f01_shift`：シフト → 時間帯 evening → `d01_shift_done`。店先に澪（夕・夜のみ立つ） | ○ |
| 8 | 澪を調べる | `ev_f01_meet_mio`：初対面 4 枚（`msg_d01_mio_4` は二層）→ `met_heroine` `prologue_done` → ナツ `msg_natsu_003` | ○ |
| 9 | レシート箱 | C-09 `store_receipt` 隠蔽 →「レシートの控えを整理した。」 | ○ |
| 10 | F12 へ戻り自宅を調べる | `ev_f12_home_sleep_d1`：`msg_f12_home`（二層）→ ナツ `msg_natsu_002` →「眠った。」→ 8/2 へ | ○（※1） |

※1 `sleep` は `event_finished` の遅延接続で日送りするため、8/2 の開始メッセージが「眠った。」の後に出る設計。実機で順序を確認する。

## 8/2（日・固定）通夜

| # | 操作 | 期待する結果 | 判定 |
|---|---|---|---|
| 1 | 起床 | `msg_day_start`「8月2日（日）、朝。」→ `ev_d02_open` `msg_d02_open`。F02・F05・F06 が開く | ○ |
| 2 | F02 蓮の家の玄関 | `ev_f02_wake`：通夜（事後のみ・死の場面なし）→ 澪の証言 `msg_mio_001`（二層）→ `heard_testimony` → 時間帯 evening、+1 P | ○ |
| 3 | 居間の匂い・物干し・窓 | `msg_f02_smell`（二層）ほか。部屋（机・端末）は 8/8 まで入れない | ○ |
| 4 | F05 たちばな屋の日めくり | `ev_f05_calendar_early`：「日めくりは 8 月になっていた」（C-04 は 8/3 から） | ○ |
| 5 | F06 公衆電話 | セーブメニュー（スロット 1〜）。地図看板で `flag_minimap_unlocked` → M でミニマップ | ○ |
| 6 | 自宅で就寝 | `can_sleep`（`heard_testimony`）→ 8/3 へ。`companion_on` `notebook_unlocked` が立つ | ○ |

## 8/3（月・自由）調査 1 日目

| # | 操作 | 期待する結果 | 判定 |
|---|---|---|---|
| 1 | 起床 | `ev_d03_open`。澪が同行（`Heroine` が後方追従）。N でノート | ○ |
| 2 | F12 支所（平日・朝） | ガラス扉点灯。`ev_f12_office_first`：届出用紙の束 → +1 P、`saw_notifications` | ○ |
| 3 | F12 集合ポスト | `ev_f12_mailbox_letters`：B-201 の未回収の手紙 → +1 P | ○ |
| 4 | F05 トキ | `ev_f05_toki_testimony`：証言 → 証拠 `testimony_walking`（ノートに載る）→ +1 P（※2） | ○ |
| 5 | F05 日めくり | `ev_f05_calendar_conceal`：C-04 隠蔽。澪が 64px 以内なら失敗 → `msg_conceal_witnessed`、接近度 +20。+1 P（※2） | ○ |
| 6 | F06 図書室 | `ev_f06_library`：+1 P（初回のみ。※2） | ○ |
| 7 | 3 P 到達 | `sleep_available`。時間帯は P に応じて noon → evening → night と進む | ○ |
| 8 | 自宅で就寝 | 8/4 へ | ○ |

※2 机上確認で見つけた問題（下記「見つかった問題と対処」1・2）を本 PR で修正した結果。

## 8/4（火・自由）調査 2 日目 ＝ 第一幕の入口

| # | 操作 | 期待する結果 | 判定 |
|---|---|---|---|
| 1 | 起床 | `opening_event` なし。`msg_day_start` のみ | ○ |
| 2 | F12 に入る | `ev_f12_enter_aligned`：四棟の階段室が全て 3 階で点灯 → 地の文 → `entity_pulse` | ○ |
| 3 | F12 支所・ポスト | `ev_f12_office_d4` `ev_f12_mailbox_d4`：各 +1 P（8/4 限定） | ○（※3） |
| 4 | F06 北端 (27,0〜3) 法面階段の張り紙 | `ev_f06_slope_notice`：C-03 `timetable_pass` 隠蔽 → +1 P。澪が近いと失敗し `heroine_remark_timetable_pass` 相当の記録が残る | ○ |
| 5 | F01 掲示板 | `ev_f01_bulletin_d4`：夏祭り中止 → +1 P | ○（※3） |
| 6 | 3 P 到達 → 就寝 | 8/5（固定・`saw_first_missing`）へ。以降は Step 4 の範囲 | ○ |

※3 「見つかった問題と対処」3 の追加分。

## 見つかった問題と対処

| # | 問題 | 対処（本 PR） |
|---|---|---|
| 1 | F06 図書室 `ev_f06_library` が `once: false` のまま `add_points` を持ち、連打で無限に P が得られた | `once: true` にし、再訪用 `ev_f06_library_again` を追加 |
| 2 | 8/3 に得られる P の供給源を数えると、初訪問ボーナスを除くと 3 未満になり得た（図書室・ポスト・支所のみ） | トキの証言、日めくり（C-04）、蓮の家の再訪 `ev_f02_door_revisit` に +1 P を付けた。C-04・C-03 の隠蔽イベントは `once: true` にし、再表示用 `_after` イベントを分けた |
| 3 | 8/3 に全ての供給源を使い切ると 8/4 に 3 P へ届かず、進行が止まる | 8/4 限定の `ev_f12_office_d4` `ev_f12_mailbox_d4` と 8/4 以降の `ev_f01_bulletin_d4` を追加（各 +1 P）。8/4 単独で 4 P 得られる |
| 4 | `docs/FLAGS.md` に `d01_told` `d01_shift_done` `heard_testimony_direct` が無かった | 追記 |
| 5 | `docs/SCENARIO.md` §8・`docs/CONCEALMENT_LIST.md` の実装範囲が古かった | 更新 |
| 6 | フィールド地図の検証を毎回その場しのぎの Python で行っていた | `docs/tools/check_field_map.py` を追加。5 フィールドすべて OK（F01 の橋の看板が通行可タイル上、F05 の境内が孤立領域として「注意」） |

## 既知の問題（本 PR では対処しない）

- 支所の「閉庁」文は 8/1・8/2 のみ。8/8・8/9 以降の週末は扉の見た目だけ閉まる（曜日条件は Step 4 で追加）。
- フィールド初訪問の +1 P は `Main` に直書き（`GameConstants` へ移す）。
- 8/3 の澪同行中に F01 の店先へ行くと、8/1 用の `mio_npc`（立ち姿の Interactable）が夕方以降に再出現する。`ev_f01_meet_mio` は `once` なので会話は起きないが、同行中の澪と二人になる。F01 側で `companion_on` のとき出さないようにする（Step 4）。
- 追跡者は F03 実装前のため、`start_stalker` を呼ぶイベントがまだ無い。
- ナツの台詞 `msg_natsu_004`（8/3 以降の夜の探索）を流すイベントが未配置。

## 実機で確認すること（Godot 4.7 が使える環境で最初に）

1. プロジェクトが開き、autoload 13 個と `EventValidator` の起動時検証がエラーなしで通る（出力パネル）。
2. `tile_preview.tscn` で「階段室（消灯）」を含む全種別にフォールバック（赤枠）が無い。
3. 上記の 8/1〜8/4 を通しで遊び、各表の期待結果と一致する。特に ※1 の就寝→翌日の表示順、`choice` の選択肢 UI、隠蔽の目撃判定（澪との距離 64px）。
4. F12 の階段室の点灯階が day 1〜4 で表どおりに変わる（デバッグオーバーレイで day を変える）。
5. セーブ（F06 公衆電話）→ タイトル → ロードで、日付・時間帯・フラグ・隠蔽記録・接近度・ナツの状態が戻る。
6. `truth_revealed` を立てたときの二層テキスト 38 対（`docs/DECEPTION_MAP.md`）の切り替わりと、ノートの「真相版」表示。
7. 200 行超のファイルで型注釈エラー（`untyped_declaration=2`）が出ないこと。
