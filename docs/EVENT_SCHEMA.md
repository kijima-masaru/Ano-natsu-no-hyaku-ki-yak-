# イベントスキーマ（data/events.json）

ゲーム内容は JSON に寄せ、GDScript にはシステムだけを書く。フィールド固有の会話・フラグ操作・入手はすべてここに定義する。
読み込みと実行は `EventSystem` autoload、条件評価は `ConditionEvaluator`、参照検証は `EventValidator`。

## ファイル構造

```json
{
  "meta": {"schema_version": 1},
  "events": [ { …イベント… } ]
}
```

## イベント

| キー | 型 | 必須 | 意味 |
|---|---|---|---|
| `id` | String | ○ | 一意。`ev_<日 or フィールド>_<内容>`。例 `ev_d01_open`, `ev_f06_lost_found_take` |
| `field` | String | | 対象フィールド ID。空なら全フィールド |
| `trigger` | String | ○ | `on_enter`（フィールド進入）／`on_interact`（調べる）／`on_day_start`（日の開始。`day_range` 必須）／`manual`（`run_event` や schedule の `opening_event` から ID 指定） |
| `target` | String | on_interact で○ | `Interactable.interaction_id` |
| `day_range` | [int, int] | | 発生する日の範囲（両端含む） |
| `time_of_day` | String / [String] | | `morning` / `noon` / `evening` / `night` |
| `conditions` | [Condition] | | すべて満たすと発生（空なら常時） |
| `actions` | [Action] | ○ | 順に実行。メッセージは閉じるまで待つ |
| `once` | bool | | 既定 true。一度実行すると `ev_done_<id>` が立ち、以後発生しない |
| `priority` | int | | `on_interact` で複数候補があるとき最大のものだけ実行。他のトリガーは全件を優先度順に実行 |

## 条件（Condition）

`"is": false` を付けると否定になる（既定 true）。

| 形 | 意味 |
|---|---|
| `{"flag": "met_heroine"}` | フラグが立っている |
| `{"has_item": "key_tunnel_fence"}` | 所持している |
| `{"field_visited": "F03"}` | 訪問済み |
| `{"day": 8}` | 当日 |
| `{"day_range": [3, 12]}` | 期間内 |
| `{"time_of_day": "night"}` / `["evening","night"]` | 時間帯 |
| `{"not": {…}}` / `{"any": […]}` / `{"all": […]}` | 論理 |
| `{"suspicion": {"min": 25, "max": 74}}` / `{"suspicion": {"stage": "doubt"}}` | 接近度（Suspicion が登録。stage は unaware / unease / doubt / certainty） |
| `{"can_sleep": true}` | 現在地が自宅で、その日の進行条件を満たしている（EventActions が登録。`false` で「まだ眠れない」分岐） |
| `{"floor": "1f"}` | 現在のフィールドの階（`FieldFloors`。屋外は `outside`。EventActions が登録） |

## アクション（Action）

組み込み（EventSystem）：

| type | 引数 | 意味 |
|---|---|---|
| `message` | `id`, `args?` | `MessageResolver.resolve(id)` で表層／真相を解決して表示し、閉じるまで待つ。**二層分岐はここ以外に置かない** |
| `set_flag` | `flag`, `value?` | フラグを立てる（`value:false` で下ろす） |
| `clear_flag` | `flag` | 下ろす |
| `give_item` / `remove_item` | `item` | 所持品（`items.json` に定義が必要） |
| `unlock_field` | `field` | そのフィールドの `unlock_flag` を立てる |
| `move_player` | `field?`, `tile`, `facing?` | 別フィールドなら遷移してから配置 |
| `advance_day` | | 日送り（進行条件を満たしている必要あり） |
| `set_time` | `time_of_day` | 時間帯 |
| `add_points` | `amount` | 調査ポイント |
| `wait` | `seconds` | 待機 |
| `run_event` | `id` | 別イベントを待ち行列に追加 |
| `end_game` | `ending` | クリア記録してタイトルへ（ステップ5で本実装） |

他 autoload が `EventSystem.register_action(type, handler)` で追加するもの（予定）：

| type | 追加元 | 引数 |
|---|---|---|
| `raise_suspicion` | Suspicion | `amount`, `reason?` |
| `give_evidence` | EvidenceRegistry | `evidence`（ノートに記録、`suspicion_on_gain` を加算） |
| `conceal_evidence` | EvidenceRegistry | `evidence`（澪が近ければ失敗。表示は `shown_id` か `msg_conceal_witnessed`） |
| `show_concealment_reveal` | EvidenceRegistry | なし（8/30 の提示画面） |
| `autosave` | EventActions | なし |
| `play_sound` | AudioManager（タスク6） | `id` |
| `set_companion` | EventActions → SceneRouter | `on`（ヒロインの同行 ON/OFF。`companion_on` フラグと同期） |
| `entity_speak` | AttachedEntity | `id`（ナツの台詞。二層は messages.json の truth_id） |
| `entity_comfort` | AttachedEntity | `context`（after_anomaly / after_stalker / night_walk / yakushi_gate / heroine_near） |
| `entity_pulse` | AttachedEntity | `strength`（環境の微細な変化の通知） |
| `start_stalker` | EventActions → FieldBase | `active`, `spawn_tile?`, `retreat_to?`（現在フィールドに追跡者を出す／消す。出したら `stalker_met`） |
| `choice` | Dialogue（タスク4） | `options` |
| `sleep` | EventActions → Calendar | なし（自宅で就寝して翌日へ。眠れなければ `msg_bed_not_yet`。日送りはイベント終了後に行う） |
| `switch_floor` | EventActions → FieldBase | `floor`, `tile`, `facing?`（屋内の階へ移る／`outside` で屋外へ。階は各フィールドの `FLOORS` 定数。切替後に `on_enter` が再発火する） |

## 二層テキスト

`messages.json` の各 entry は `{id, speaker, text, truth_id?}`。`truth_id` があり `truth_revealed` が立っていれば `MessageResolver.resolve()` が真相版を返す。
表層版を返した時点で `seen_<id>` が立つ。**テキストの取得は必ず `MessageResolver.resolve / text` を通す。** GDScript に日本語を直書きしない。

## 検証（起動時、全 autoload の `_ready` 後）

`EventValidator.validate` が以下を全件列挙して `push_error` する：

- 未登録のアクション種別
- 存在しないメッセージ ID（`message.id` / `truth_id` / `entity_speak.id`）
- `items.json` に無いアイテム
- 存在しないフィールド
- 存在しない `run_event` 先
- **どこでも立てられないフラグ**（`set_flag`・schedule のフラグ操作・鍵・コード既知フラグ・動的接頭辞 `visited_ ev_ hid_ seen_ day_ luck_` 以外）
- `on_day_start` に `day_range` が無い

`MessageResolver` は別途、`truth_id` の片側欠落と未定義話者を検証する。

## 日の開始との接続

`schedule.json` の `opening_event` は `manual` イベントの ID。Main が日の開始で 圧縮テキスト → `msg_day_start` → `opening_event` → `on_day_start` の発火（自由日の導入、接近度の段階ごとの朝の澪の様子）の順に実行する。接近度の段階が上がったときは Main が `msg_yu_stage_<n>` を出す（数値は見せない）。
`schedule.json` の `set_flags_on_start` 等は Calendar が直接処理する（イベントを介さない）。

## 実行の規則

- 実行中はプレイヤー入力を止め、終了後に戻す。イベント中に `run_event` されたものは待ち行列で順に実行
- `EventSystem.run_actions(label, actions)` で events.json に無いアクション列も同じ待ち行列で実行できる（`AnomalySystem` が使う。`docs/ANOMALY_SCHEMA.md`）
- アクションが未登録・参照先不在のときは `push_error` と `action_failed` を出し、そのアクションを飛ばして続行する
- 日本語テキストの表示は `EventSystem.show_entry(entry)` に一本化（他 autoload も使う）
