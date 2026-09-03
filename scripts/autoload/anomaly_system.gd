extends Node
## フィールド固有の単発怪異。data/anomalies.json を読み、進入・調べる・条件成立で発火する。
## アクションは EventSystem.run_actions で実行する（別系統を作らない）。
## 発火の直後に接近度の増減と、憑いた怪異の労わり（entity_comfort）を差し込める。
## 発生回数と最後に起きた日は SaveManager のセクション "anomalies" に保存する。

signal anomaly_triggered(anomaly_id: String, stage_index: int)
signal load_failed(errors: PackedStringArray)

const ANOMALIES_PATH: String = "res://data/anomalies.json"
const TRIGGER_ENTER: String = "on_enter"
const TRIGGER_INTERACT: String = "on_interact"
const TRIGGER_CONDITION: String = "on_condition"

var load_errors: PackedStringArray = PackedStringArray()
var last_triggered_id: String = ""

var _anomalies: Dictionary = {}
var _by_trigger: Dictionary = {}
## id → 発生回数
var _counts: Dictionary = {}
## id → 最後に起きた日
var _last_day: Dictionary = {}


func _ready() -> void:
	load_file(ANOMALIES_PATH)
	SaveManager.register_section("anomalies", to_dict, from_dict)
	# はじめから（周回を含む）では前の周の発生回数を持ち越さない
	GameState.state_reset.connect(func() -> void:
		_counts.clear()
		_last_day.clear()
		last_triggered_id = "")
	SceneRouter.field_entered.connect(func(_id: String, _from: String) -> void: _recheck_conditions())
	Calendar.time_of_day_changed.connect(func(_t: String, _p: String) -> void: _recheck_conditions())
	Calendar.day_advanced.connect(func(_d: int, _p: int) -> void: _recheck_conditions())
	EventSystem.event_finished.connect(func(_id: String) -> void: _recheck_conditions())
	EventSystem.register_defined_flags(_defined_flags())
	validate.call_deferred()


func load_file(path: String) -> bool:
	_anomalies.clear()
	_by_trigger.clear()
	load_errors.clear()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("%s を開けません" % path)
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or not (data as Dictionary).get("anomalies", null) is Array:
		return _fail("%s: 'anomalies' 配列がありません" % path)
	for item: Variant in (data as Dictionary)["anomalies"]:
		if not item is Dictionary:
			continue
		var a: AnomalyData = AnomalyData.from_dict(item, load_errors)
		if a.id.is_empty():
			continue
		if _anomalies.has(a.id):
			load_errors.append("怪異 ID '%s' が重複しています" % a.id)
			continue
		_anomalies[a.id] = a
		if not _by_trigger.has(a.trigger):
			_by_trigger[a.trigger] = []
		(_by_trigger[a.trigger] as Array).append(a)
	for msg: String in load_errors:
		push_error("AnomalySystem: " + msg)
	return load_errors.is_empty()


func _fail(msg: String) -> bool:
	load_errors.append(msg)
	push_error("AnomalySystem: " + msg)
	load_failed.emit(load_errors)
	return false


## 参照検証。各段階のアクション列を EventData に見せかけて EventValidator に通す
func validate() -> void:
	var pseudo: Dictionary = {}
	for a: AnomalyData in _anomalies.values():
		var lists: Array = [a.actions] if a.mode != "escalate" else []
		for s: Dictionary in a.stages:
			lists.append(s.get("actions", []))
		for i: int in lists.size():
			var d: Dictionary = {"id": "%s#%d" % [a.id, i], "field": a.field, "trigger": "manual", "conditions": a.conditions, "actions": lists[i], "once": false}
			var e: EventData = EventData.from_dict(d, load_errors)
			pseudo[e.id] = e
		if not a.comfort.is_empty() and not AttachedEntity.COMFORT_CONTEXTS.has(a.comfort):
			push_error("AnomalySystem: %s の comfort '%s' は未定義です" % [a.id, a.comfort])
	for msg: String in EventValidator.validate(pseudo, EventSystem.known_actions(), EventSystem.get_item_ids(), EventSystem.defined_flags()):
		push_error("AnomalySystem: " + msg)


## 怪異が立てるフラグ（全段階の set_flag）。EventSystem の検証に渡す
func _defined_flags() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for a: AnomalyData in _anomalies.values():
		var lists: Array = [a.actions]
		for s: Dictionary in a.stages:
			lists.append(s.get("actions", []))
		for actions: Variant in lists:
			for action: Variant in actions as Array:
				if action is Dictionary and str((action as Dictionary).get("type", "")) == "set_flag":
					out.append(str((action as Dictionary).get("flag", "")))
	return out


func has_anomaly(id: String) -> bool:
	return _anomalies.has(id)


func count_of(id: String) -> int:
	return int(_counts.get(id, 0))


## トリガーに一致する怪異を起こす。起こしたものがあれば true。Main が EventSystem.fire の後に呼ぶ
func fire(trigger: String, field_id: String, target: String = "") -> bool:
	var fired: bool = false
	for a: AnomalyData in _by_trigger.get(trigger, []):
		if a.field != field_id:
			continue
		if trigger == TRIGGER_INTERACT and a.target != target:
			continue
		if _can_fire(a):
			_run(a)
			fired = true
	return fired


func _can_fire(a: AnomalyData) -> bool:
	if not a.matches_day(Calendar.day) or not a.matches_time(Calendar.time_of_day):
		return false
	if a.mode == "once" and GameState.has_flag(a.done_flag()):
		return false
	if a.mode != "once" and a.once_per_day and int(_last_day.get(a.id, -1)) == Calendar.day:
		return false
	return ConditionEvaluator.evaluate_all(a.conditions)


func _run(a: AnomalyData) -> void:
	var count: int = count_of(a.id)
	var actions: Array[Dictionary] = a.actions_for(count, Calendar.day).duplicate()
	# 接近度は初回の発生だけ上げる（繰り返しで積み上がると ED-B/C に届かない。docs/PLAYTEST_LOG.md「閾値の確定」）
	if a.suspicion_delta != 0 and count == 0:
		actions.append({"type": "raise_suspicion", "amount": a.suspicion_delta, "reason": "anomaly:%s" % a.id})
	if not a.comfort.is_empty():
		actions.append({"type": "entity_comfort", "context": a.comfort})
	_counts[a.id] = count + 1
	_last_day[a.id] = Calendar.day
	if a.mode == "once":
		GameState.raise_flag(a.done_flag())
	last_triggered_id = a.id
	EventSystem.run_actions("anomaly:%s" % a.id, actions)
	anomaly_triggered.emit(a.id, mini(count, maxi(a.stages.size() - 1, 0)))


## on_condition の怪異を現在のフィールドで評価する。イベント実行中は次の event_finished で再評価される
func _recheck_conditions() -> void:
	if EventSystem.is_running or SceneRouter.is_transitioning or SceneRouter.current_field_id.is_empty():
		return
	fire(TRIGGER_CONDITION, SceneRouter.current_field_id)


# ── シリアライズ ──

func to_dict() -> Dictionary:
	return {"counts": _counts.duplicate(), "last_day": _last_day.duplicate()}


func from_dict(d: Dictionary) -> bool:
	_counts.clear()
	_last_day.clear()
	var counts: Variant = d.get("counts", {})
	var last: Variant = d.get("last_day", {})
	if counts is Dictionary:
		for k: String in (counts as Dictionary).keys():
			_counts[k] = int((counts as Dictionary)[k])
	if last is Dictionary:
		for k: String in (last as Dictionary).keys():
			_last_day[k] = int((last as Dictionary)[k])
	return true
