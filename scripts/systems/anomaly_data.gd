class_name AnomalyData
extends RefCounted
## data/anomalies.json の 1 件分。フィールド固有の「その場で起きる異常」（追跡者とは別系統）。
## アクション語彙は events.json と同じ（EventSystem.run_actions で実行する）。
## mode: once（一度きり）/ repeat（条件を満たすと毎回。既定で 1 日 1 回）/ escalate（stages を回数または日で進める）

const TRIGGERS: PackedStringArray = ["on_enter", "on_interact", "on_condition"]
const MODES: PackedStringArray = ["once", "repeat", "escalate"]

var id: String = ""
var field: String = ""
var trigger: String = "on_enter"
var target: String = ""
var day_min: int = 0
var day_max: int = 0
var time_of_day: PackedStringArray = PackedStringArray()
var conditions: Array[Dictionary] = []
var mode: String = "once"
## repeat のとき同じ日に二度起こさない（既定 true）
var once_per_day: bool = true
## once / repeat のアクション列
var actions: Array[Dictionary] = []
## escalate の段階。各要素 {day_range?: [a,b], actions: [...]}。day_range があれば日で、無ければ発生回数で段階を選ぶ
var stages: Array[Dictionary] = []
var suspicion_delta: int = 0
## 直後に憑いた怪異が差し込む労わりの状況（AttachedEntity.COMFORT_CONTEXTS）。空なら無し
var comfort: String = ""


func done_flag() -> String:
	return "an_done_%s" % id


func matches_day(day: int) -> bool:
	return (day_min == 0 and day_max == 0) or (day >= day_min and day <= day_max)


func matches_time(tod: String) -> bool:
	return time_of_day.is_empty() or time_of_day.has(tod)


## 実行するアクション列。escalate は count（これまでの発生回数）と day から段階を選ぶ
func actions_for(count: int, day: int) -> Array[Dictionary]:
	if mode != "escalate" or stages.is_empty():
		return actions
	var by_day: bool = false
	for s: Dictionary in stages:
		if s.has("day_range"):
			by_day = true
	var chosen: Dictionary = stages[mini(count, stages.size() - 1)]
	if by_day:
		for s: Dictionary in stages:
			var r: Variant = s.get("day_range", null)
			if r is Array and (r as Array).size() == 2 and day >= int((r as Array)[0]) and day <= int((r as Array)[1]):
				chosen = s
	var out: Array[Dictionary] = []
	for a: Variant in chosen.get("actions", []):
		if a is Dictionary:
			out.append(a)
	return out


static func from_dict(d: Dictionary, errors: PackedStringArray) -> AnomalyData:
	var a: AnomalyData = AnomalyData.new()
	a.id = str(d.get("id", ""))
	var label: String = a.id if not a.id.is_empty() else "(id 無し)"
	if a.id.is_empty():
		errors.append("id の無い怪異があります")
	a.field = str(d.get("field", ""))
	if a.field.is_empty():
		errors.append("%s: field は必須です" % label)
	a.trigger = str(d.get("trigger", "on_enter"))
	if not TRIGGERS.has(a.trigger):
		errors.append("%s: trigger '%s' は %s のいずれか" % [label, a.trigger, ", ".join(TRIGGERS)])
	a.target = str(d.get("target", ""))
	if a.trigger == "on_interact" and a.target.is_empty():
		errors.append("%s: on_interact には target が必要です" % label)
	var r: Variant = d.get("day_range", null)
	if r is Array and (r as Array).size() == 2:
		a.day_min = int((r as Array)[0])
		a.day_max = int((r as Array)[1])
	elif r != null:
		errors.append("%s: day_range は [min, max]" % label)
	var tod: Variant = d.get("time_of_day", [])
	if tod is Array:
		for v: Variant in tod as Array:
			a.time_of_day.append(str(v))
	elif tod is String:
		a.time_of_day.append(str(tod))
	for c: Variant in d.get("conditions", []):
		if c is Dictionary:
			a.conditions.append(c)
	a.mode = str(d.get("mode", "repeat" if bool(d.get("repeatable", false)) else "once"))
	if not MODES.has(a.mode):
		errors.append("%s: mode '%s' は %s のいずれか" % [label, a.mode, ", ".join(MODES)])
	a.once_per_day = bool(d.get("once_per_day", true))
	for v: Variant in d.get("actions", []):
		if v is Dictionary:
			a.actions.append(v)
	for v: Variant in d.get("stages", []):
		if v is Dictionary:
			a.stages.append(v)
	if a.mode == "escalate" and a.stages.is_empty():
		errors.append("%s: escalate には stages が必要です" % label)
	if a.mode != "escalate" and a.actions.is_empty():
		errors.append("%s: actions が空です" % label)
	a.suspicion_delta = int(d.get("suspicion_delta", 0))
	a.comfort = str(d.get("comfort", ""))
	return a
