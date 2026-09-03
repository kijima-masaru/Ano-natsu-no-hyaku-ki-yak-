class_name ScheduleLoader
extends RefCounted
## data/schedule.json を読み込んで DaySchedule の辞書に変換し、整合性を検証する。
## Calendar autoload からのみ使う。結果は {"days": Dictionary[int→DaySchedule], "meta": Dictionary, "errors": PackedStringArray}

const KEY_DAYS: String = "days"
const KEY_META: String = "meta"
const KEY_ERRORS: String = "errors"


static func load_file(path: String) -> Dictionary:
	var result: Dictionary = {KEY_DAYS: {}, KEY_META: {}, KEY_ERRORS: PackedStringArray()}
	var errors: PackedStringArray = result[KEY_ERRORS]
	var root: Dictionary = JsonFile.read_dict(path, errors, true)
	if root.is_empty():
		return result
	if root.get(KEY_META, {}) is Dictionary:
		result[KEY_META] = root.get(KEY_META, {})
	var entries: Variant = root.get(KEY_DAYS, null)
	if not entries is Array:
		errors.append("%s: 'days' 配列がありません" % path)
		return result
	var days: Dictionary = result[KEY_DAYS]
	for item: Variant in entries as Array:
		if not item is Dictionary:
			errors.append("days の要素が辞書ではありません")
			continue
		var s: DaySchedule = DaySchedule.from_dict(item, errors)
		if days.has(s.day):
			errors.append("day %d が重複しています" % s.day)
		days[s.day] = s
	var meta: Dictionary = result[KEY_META]
	var first_day: int = int(meta.get("first_day", 1))
	var last_day: int = int(meta.get("last_day", 31))
	for d: int in range(first_day, last_day + 1):
		if not days.has(d):
			errors.append("day %d の定義がありません" % d)
	validate_fields(days, errors)
	return result


## available_fields の参照先と到達可能性、skip_to の存在を検証する
static func validate_fields(days: Dictionary, errors: PackedStringArray) -> void:
	if not FieldRegistry.is_loaded:
		errors.append("FieldRegistry が未読込のためフィールド参照を検証できません")
		return
	var ever_available: Dictionary = {}
	for d: int in days.keys():
		var s: DaySchedule = days[d]
		for fid: String in s.available_fields:
			ever_available[fid] = true
			if not FieldRegistry.has_field(fid):
				errors.append("day %d: available_fields の '%s' は存在しないフィールドです" % [d, fid])
		if s.skip_to > 0 and not days.has(s.skip_to):
			errors.append("day %d: skip_to %d の定義がありません" % [d, s.skip_to])
	for fid: String in FieldRegistry.get_field_ids():
		if not ever_available.has(fid):
			errors.append("フィールド %s はどの日にも available_fields に含まれていません（到達不能）" % fid)
