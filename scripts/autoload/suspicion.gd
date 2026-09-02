extends Node
## ヒロイン・澪の真相接近度（0〜100）。プレイヤーには数値を一切見せない。
## 段階：無自覚 0–24 ／ 違和感 25–49 ／ 疑念 50–74 ／ 確信 75–100（docs/FLAGS.md）
## 8/14 の baba_rage まで上限 24、baba_rage で最低 30 に強制。日付が進むだけでも上昇する。

signal changed(value: int, delta: int, reason: String)
signal stage_changed(stage: int, previous: int)

enum Stage { UNAWARE, UNEASE, DOUBT, CERTAINTY }
const STAGE_THRESHOLDS: PackedInt32Array = [0, 25, 50, 75]
const STAGE_KEYS: PackedStringArray = ["unaware", "unease", "doubt", "certainty"]
const MAX_VALUE: int = 100
const PRE_BABA_CAP: int = 24
const BABA_FORCED_MIN: int = 30
const BABA_FLAG: String = "baba_rage"
const DAILY_DRIFT_EARLY: int = 1
const DAILY_DRIFT_LATE: int = 2
const DRIFT_SWITCH_DAY: int = 15
const FIELD_VISIT_DELTA: int = 2

var value: int = 0


func _ready() -> void:
	Calendar.day_advanced.connect(_on_day_advanced)
	GameState.flag_raised.connect(_on_flag_raised)
	GameState.field_visited.connect(func(_id: String) -> void: add(FIELD_VISIT_DELTA, "visit"))
	SaveManager.register_section("suspicion", to_dict, from_dict)
	EventSystem.register_action("raise_suspicion", func(a: Dictionary, _c: Dictionary) -> void:
		add(int(a.get("amount", 0)), str(a.get("reason", "event"))))
	ConditionEvaluator.register("suspicion", _evaluate_condition)


func get_stage() -> int:
	var stage: int = Stage.UNAWARE
	for i: int in STAGE_THRESHOLDS.size():
		if value >= STAGE_THRESHOLDS[i]:
			stage = i
	return stage


## "unaware" などの段階キー。段階別テキスト ID の組み立てに使う（例 msg_mio_stage_1）
func stage_key() -> String:
	return STAGE_KEYS[get_stage()]


## 増減する。上限・下限と baba_rage 前の上限を適用し、段階が変われば通知
func add(delta: int, reason: String = "") -> void:
	if delta == 0:
		return
	var previous_stage: int = get_stage()
	var cap: int = MAX_VALUE if GameState.has_flag(BABA_FLAG) else PRE_BABA_CAP
	var new_value: int = clampi(value + delta, 0, cap)
	if new_value == value:
		return
	var applied: int = new_value - value
	value = new_value
	changed.emit(value, applied, reason)
	var stage: int = get_stage()
	if stage != previous_stage:
		stage_changed.emit(stage, previous_stage)


func set_value(new_value: int, reason: String = "set") -> void:
	add(new_value - value, reason)


func _on_day_advanced(day: int, _previous: int) -> void:
	add(DAILY_DRIFT_EARLY if day < DRIFT_SWITCH_DAY else DAILY_DRIFT_LATE, "day")


func _on_flag_raised(flag: String) -> void:
	if flag == BABA_FLAG and value < BABA_FORCED_MIN:
		set_value(BABA_FORCED_MIN, "baba_rage")


## 条件 {"suspicion": {"min": 25, "max": 74}} または {"suspicion": {"stage": "doubt"}}
func _evaluate_condition(cond: Dictionary) -> bool:
	var spec: Variant = cond.get("suspicion", {})
	if not spec is Dictionary:
		push_error("Suspicion: 条件 suspicion は辞書である必要があります")
		return false
	var s: Dictionary = spec
	var expect: bool = bool(cond.get("is", true))
	var ok: bool = true
	if s.has("min"):
		ok = ok and value >= int(s["min"])
	if s.has("max"):
		ok = ok and value <= int(s["max"])
	if s.has("stage"):
		ok = ok and stage_key() == str(s["stage"])
	return ok == expect


func to_dict() -> Dictionary:
	return {"value": value}


func from_dict(d: Dictionary) -> bool:
	var v: int = int(d.get("value", 0))
	if v < 0 or v > MAX_VALUE:
		push_error("Suspicion: セーブデータの value %d は不正です" % v)
		return false
	value = v
	return true
