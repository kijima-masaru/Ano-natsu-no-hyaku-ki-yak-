# 怪異スキーマ（data/anomalies.json）

フィールド固有の「その場で起きる異常」。追跡者（`Stalker`、`start_stalker`）とは別系統で、**アクション語彙は `events.json` と同じ**。
読み込みと発火は `AnomalySystem` autoload、実行は `EventSystem.run_actions()`（イベントと同じ待ち行列）、条件評価は `ConditionEvaluator`、参照検証は起動時の `EventValidator` と `validate_data`。

怪異の正体・理屈は説明しない。「見てはいけない方向を見た」「同じ場所を通ると数が増えている」「いないはずの音がする」のように、結果と違和感だけを書く。人が死に至る過程は描かない（`docs/CONTENT_NOTICE.md`）。

## ファイル構造

```json
{
  "meta": {"schema_version": 1},
  "anomalies": [ { …怪異… } ]
}
```

## 怪異

| キー | 型 | 必須 | 意味 |
|---|---|---|---|
| `id` | String | ○ | 一意。`an_<フィールド>_<内容>`。例 `an_f07_kannon` |
| `field` | String | ○ | 対象フィールド ID |
| `trigger` | String | ○ | `on_enter`（進入）／`on_interact`（調べる。`target` 必須）／`on_condition`（進入・時間帯変化・日送り・イベント終了のたびに条件を評価） |
| `target` | String | on_interact で○ | `Interactable.interaction_id` |
| `day_range` | [int, int] | | 発生する日の範囲 |
| `time_of_day` | [String] | | `morning` / `noon` / `evening` / `night` |
| `conditions` | [Condition] | | `docs/EVENT_SCHEMA.md` と同じ |
| `mode` | String | | `once`（一度きり。`an_done_<id>` が立つ）／`repeat`（条件を満たすと毎回。`once_per_day` 既定 true で 1 日 1 回）／`escalate`（`stages` を進める） |
| `once_per_day` | bool | | repeat / escalate で同じ日に二度起こさない（既定 true） |
| `actions` | [Action] | once / repeat で○ | `events.json` と同じアクション |
| `stages` | [Stage] | escalate で○ | `{ "day_range"?: [a, b], "actions": [...] }`。**いずれかの段階に `day_range` があれば日で選ぶ**（日が進むと変化する）。無ければ発生回数で 0, 1, 2… と進み最後で止まる |
| `suspicion_delta` | int | | **初回の発火だけ** `raise_suspicion`（澪の接近度）。2 回目以降の repeat / escalate では加算しない（タスク10）。0 なら無し |
| `comfort` | String | | 発火後に憑いた怪異が差し込む労わり（`entity_comfort` の context：`after_anomaly` / `after_stalker` / `night_walk` / `yakushi_gate` / `heroine_near`）。表層では主人公を安心させ、真相版で意味が反転する二層の台詞 |

`repeatable: true` は `mode: "repeat"` の旧表記として読める。

## 3 つの型

| 型 | 書き方 | 例 |
|---|---|---|
| 一度きり | `mode: "once"` | F01 `an_f01_silence`：8/15 以降の夜に一度だけ国道の音が消える |
| 条件を満たすと毎回 | `mode: "repeat"` | F05 `an_f05_fresh_goods`：トキの証言後、店先を調べると商品が新しい（1 日 1 回） |
| 日が進むと変化する | `mode: "escalate"` ＋ `stages[].day_range` | F02 `an_f02_laundry`：乾かない → 一枚増える → 物干しが空 |
| 見るたびに進む | `mode: "escalate"`（`day_range` 無し） | F06 `an_f06_board_night`：夜の掲示板を調べるたびに尋ね人が増え、3 回目は誰かに似ている |

## 発火の順序

`Main` は `on_enter` / `on_interact` で **イベント → 怪異** の順に発火し、両方が同じ待ち行列に入る。`on_condition` は `AnomalySystem` がフィールド進入・時間帯変化・日送り・イベント終了のたびに再評価する（イベント実行中は次の終了時に評価）。

発火すると、発生回数と最後の日を記録し（セーブ対象）、`once` なら `an_done_<id>` を立て、アクション列の末尾に `raise_suspicion`（`suspicion_delta`）と `entity_comfort`（`comfort`）を付けて実行する。

## 検証

起動時：`AnomalySystem.validate()` が各段階のアクション列を `EventValidator` に通す。`comfort` の context も確認する。
PR 前：`validate_data`（GDScript / Python）が field・trigger・target・mode・comfort・条件・アクションの参照を検査する。

## 書くときの指針

- 1 フィールド最低 1 つ。`docs/SCENARIO.md` §と `fields.json` の `horror_beat` を元にする。
- 「静けさ・違和感・生活感の残留」で作る。ジャンプスケアの連打、流血・遺体の描写、死の場面は置かない。
- 主人公の地の文は二層にできる（`truth_id`）。真相版は「主人公はこの異常の理由を知っている」側から書く。
- `comfort` は多用しない。怪異のあとに憑いた怪異が優しくする、という並びが後から効く。
