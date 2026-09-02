extends Node
## 主人公に取り憑いた怪異「ナツ」。autoload（AttachedEntity）。
## 姿は見せない。声（テキスト）と環境の微細な変化（presence_pulse）としてのみ存在する。
## **主人公に一度も敵対しない。** 常に労わり、庇い、助言する。プレイヤーを安心させる方向にだけ働く。
## 全台詞は二層テキスト（表層＝優しい励まし／真相＝同じ言葉が最悪の意味を帯びる）。分岐は MessageResolver に任せる。
## 「何をするのか」は結果と噂話としてのみ示す。過程・手順を描く API はここに存在しない。

## 環境の微細な変化（自販機の光が一瞬強くなる、足音が一組増える）を演出側に通知する
signal presence_pulse(strength: float)
## 不自然な幸運が働いた（プレイヤーが後から振り返る種）
signal luck_triggered(index: int, context: String)
signal spoke(message_id: String)

const SPEAKER: String = "natsu"
const INTRO_FLAG: String = "entity_intro_done"
## 追跡者が主人公を狙う重み（ヒロインを 1.0 としたとき）。数値としてだけ存在し、プレイヤーには示さない
const PLAYER_TARGET_WEIGHT: float = 0.7
## 主人公だけが助かる確率の上乗せ（危険判定を行う側が参照する）
const PROTECTION_BONUS: float = 0.35
const MAX_LUCK_EVENTS: int = 3
## 状況別の労わりの文言 ID（msg_natsu_comfort_<context>）
const COMFORT_CONTEXTS: PackedStringArray = ["after_anomaly", "after_stalker", "night_walk", "yakushi_gate", "heroine_near"]

var luck_count: int = 0


func _ready() -> void:
	EventSystem.register_action("entity_speak", func(a: Dictionary, _c: Dictionary) -> void:
		await speak(str(a.get("id", ""))))
	EventSystem.register_action("entity_comfort", func(a: Dictionary, _c: Dictionary) -> void:
		await comfort(str(a.get("context", "after_anomaly"))))
	EventSystem.register_action("entity_pulse", func(a: Dictionary, _c: Dictionary) -> void:
		pulse(float(a.get("strength", 0.5))))
	SaveManager.register_section("attached_entity", to_dict, from_dict)


## 任意のタイミングで介入する。話者は常にナツ。初回で entity_intro_done を立てる
func speak(message_id: String) -> void:
	if not MessageResolver.has_message(message_id):
		push_error("AttachedEntity: メッセージ '%s' が存在しません" % message_id)
		return
	var entry: MessageEntry = MessageResolver.resolve(message_id)
	if entry.speaker != SPEAKER:
		push_warning("AttachedEntity: '%s' の話者は '%s' です（ナツの台詞として表示します）" % [message_id, entry.speaker])
		entry.speaker = SPEAKER
		var sp: Dictionary = MessageResolver.get_speaker(SPEAKER)
		entry.speaker_name = str(sp.get("name", ""))
	GameState.raise_flag(INTRO_FLAG)
	pulse(0.3)
	await EventSystem.show_entry(entry)
	spoke.emit(message_id)


## 怪異遭遇・追跡の直後などに、主人公を庇う／労わる台詞を差し込む
func comfort(context: String) -> void:
	if not COMFORT_CONTEXTS.has(context):
		push_error("AttachedEntity: 未知の状況 '%s'（%s）" % [context, ", ".join(COMFORT_CONTEXTS)])
		return
	await speak("msg_natsu_comfort_%s" % context)


## 環境の微細な変化を起こす（光源の明滅などは受け手が実装）
func pulse(strength: float) -> void:
	presence_pulse.emit(clampf(strength, 0.0, 1.0))


# ── 不自然な幸運のフック（危険判定を行う側が呼ぶ。追跡者・怪異遭遇） ──

## 追跡者が主人公を狙う重み。ヒロインは 1.0
func player_target_weight() -> float:
	return PLAYER_TARGET_WEIGHT


## 主人公だけが助かるべきか。回数を数え、luck_<n> フラグと通知を残す（振り返りの種）
func try_protect(context: String) -> bool:
	if luck_count >= MAX_LUCK_EVENTS:
		return false
	luck_count += 1
	GameState.raise_flag("luck_%d" % luck_count)
	luck_triggered.emit(luck_count, context)
	return true


func to_dict() -> Dictionary:
	return {"luck_count": luck_count}


func from_dict(d: Dictionary) -> bool:
	luck_count = clampi(int(d.get("luck_count", 0)), 0, MAX_LUCK_EVENTS)
	return true
