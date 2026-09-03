class_name EventData
extends RefCounted
## data/events.json の 1 イベント分。

const TRIGGERS: PackedStringArray = ["on_enter", "on_interact", "on_day_start", "manual"]

var id: String = ""
## 対象フィールド。空なら全フィールド
var field: String = ""
var trigger: String = "manual"
## on_interact の対象 interaction_id
var target: String = ""
## 発生する日の範囲 [min, max]。空なら常時
var day_min: int = 0
var day_max: int = 0
var time_of_day: PackedStringArray = PackedStringArray()
var conditions: Array[Dictionary] = []
var actions: Array[Dictionary] = []
## true なら一度だけ（ev_done_<id> フラグで管理）
var once: bool = true
## true なら 1 日 1 回（ev_day_<id>_<day> フラグで管理）。自由日の調査 P を毎日得られる観察点に使う
var daily: bool = false
## 同じトリガーで複数候補があるとき、大きい方を優先
var priority: int = 0


func done_flag() -> String:
	return "ev_done_%s" % id


func daily_flag(day: int) -> String:
	return "ev_day_%s_%d" % [id, day]


func matches_day(day: int) -> bool:
	if day_min == 0 and day_max == 0:
		return true
	return day >= day_min and day <= day_max


func matches_time(tod: String) -> bool:
	return time_of_day.is_empty() or time_of_day.has(tod)


static func from_dict(d: Dictionary, errors: PackedStringArray) -> EventData:
	var e: EventData = EventData.new()
	e.id = str(d.get("id", ""))
	var label: String = e.id if not e.id.is_empty() else "(id 無し)"
	if e.id.is_empty():
		errors.append("id の無いイベントがあります")
	e.field = str(d.get("field", ""))
	e.trigger = str(d.get("trigger", "manual"))
	if not TRIGGERS.has(e.trigger):
		errors.append("%s: trigger '%s' は %s のいずれかである必要があります" % [label, e.trigger, ", ".join(TRIGGERS)])
	e.target = str(d.get("target", ""))
	if e.trigger == "on_interact" and e.target.is_empty():
		errors.append("%s: on_interact には target が必要です" % label)
	var range_value: Variant = d.get("day_range", null)
	if range_value is Array and (range_value as Array).size() == 2:
		e.day_min = int((range_value as Array)[0])
		e.day_max = int((range_value as Array)[1])
	elif range_value != null:
		errors.append("%s: day_range は [min, max] である必要があります" % label)
	var tod: Variant = d.get("time_of_day", [])
	if tod is Array:
		for v: Variant in tod as Array:
			e.time_of_day.append(str(v))
	elif tod is String:
		e.time_of_day.append(str(tod))
	e.conditions = _dicts(d.get("conditions", []), label, "conditions", errors)
	e.actions = _dicts(d.get("actions", []), label, "actions", errors)
	if e.actions.is_empty():
		errors.append("%s: actions が空です" % label)
	e.once = bool(d.get("once", true))
	e.daily = bool(d.get("daily", false))
	if e.once and e.daily:
		errors.append("%s: once と daily は同時に指定できません" % label)
	e.priority = int(d.get("priority", 0))
	return e


static func _dicts(value: Variant, label: String, key: String, errors: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not value is Array:
		errors.append("%s: %s は配列である必要があります" % [label, key])
		return out
	for v: Variant in value as Array:
		if v is Dictionary:
			out.append(v)
		else:
			errors.append("%s: %s の要素が辞書ではありません" % [label, key])
	return out
