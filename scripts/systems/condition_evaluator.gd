class_name ConditionEvaluator
extends RefCounted
## events.json / anomalies.json の条件辞書を評価する。
## 組み込み：flag / has_item / field_visited / day / day_range / time_of_day / not / any / all
## 拡張：register() で他の autoload（Suspicion 等）が条件キーを追加できる。

static var _extra: Dictionary = {}


## 追加の条件キーを登録する。callable(cond: Dictionary) -> bool
static func register(key: String, evaluator: Callable) -> void:
	_extra[key] = evaluator


static func known_keys() -> PackedStringArray:
	var keys: PackedStringArray = ["flag", "has_item", "field_visited", "day", "day_range", "time_of_day", "not", "any", "all"]
	for k: String in _extra.keys():
		keys.append(k)
	return keys


## 条件の配列をすべて満たすか（空なら true）
static func evaluate_all(conditions: Array[Dictionary]) -> bool:
	for cond: Dictionary in conditions:
		if not evaluate(cond):
			return false
	return true


static func evaluate(cond: Dictionary) -> bool:
	var expect: bool = bool(cond.get("is", true))
	if cond.has("flag"):
		return GameState.has_flag(str(cond["flag"])) == expect
	if cond.has("has_item"):
		return GameState.has_item(str(cond["has_item"])) == expect
	if cond.has("field_visited"):
		return GameState.has_visited(str(cond["field_visited"])) == expect
	if cond.has("day"):
		return (Calendar.day == int(cond["day"])) == expect
	if cond.has("day_range"):
		var r: Variant = cond["day_range"]
		if r is Array and (r as Array).size() == 2:
			var inside: bool = Calendar.day >= int((r as Array)[0]) and Calendar.day <= int((r as Array)[1])
			return inside == expect
		push_error("ConditionEvaluator: day_range は [min, max] である必要があります")
		return false
	if cond.has("time_of_day"):
		var t: Variant = cond["time_of_day"]
		var hit: bool = (t is Array and (t as Array).has(Calendar.time_of_day)) or (t is String and str(t) == Calendar.time_of_day)
		return hit == expect
	if cond.has("not"):
		return not evaluate(cond["not"]) if cond["not"] is Dictionary else false
	if cond.has("any"):
		for c: Variant in cond["any"] as Array:
			if c is Dictionary and evaluate(c):
				return true
		return false
	if cond.has("all"):
		for c: Variant in cond["all"] as Array:
			if not (c is Dictionary and evaluate(c)):
				return false
		return true
	for key: String in _extra.keys():
		if cond.has(key):
			var callable: Callable = _extra[key]
			return bool(callable.call(cond))
	push_error("ConditionEvaluator: 未知の条件 %s" % JSON.stringify(cond))
	return false


## 条件が参照するフラグ・アイテム・フィールドを収集する（検証用）
static func collect_refs(cond: Dictionary, flags: PackedStringArray, items: PackedStringArray, fields: PackedStringArray) -> void:
	if cond.has("flag"):
		flags.append(str(cond["flag"]))
	if cond.has("has_item"):
		items.append(str(cond["has_item"]))
	if cond.has("field_visited"):
		fields.append(str(cond["field_visited"]))
	if cond.has("not") and cond["not"] is Dictionary:
		collect_refs(cond["not"], flags, items, fields)
	for key: String in ["any", "all"]:
		if cond.has(key) and cond[key] is Array:
			for c: Variant in cond[key] as Array:
				if c is Dictionary:
					collect_refs(c, flags, items, fields)
