class_name DaySchedule
extends RefCounted
## data/schedule.json の 1 日分を型付きで保持する。

const TYPE_FIXED: String = "fixed"
const TYPE_FREE: String = "free"
const TYPE_COMPRESSED: String = "compressed"
const TYPES: PackedStringArray = [TYPE_FIXED, TYPE_FREE, TYPE_COMPRESSED]

var day: int = 0
var type: String = TYPE_FREE
var title: String = ""
## 固定日・自由日の朝に実行するイベント ID（空なら無し）
var opening_event: String = ""
## 進行条件。fixed: {"flag": String, "is": bool}、free: {"points": int}
var condition_flag: String = ""
var condition_flag_value: bool = true
var required_points: int = 0
## 圧縮日：飛ばし先の日と説明テキスト
var skip_to: int = 0
var compressed_text_id: String = ""
var available_fields: PackedStringArray = PackedStringArray()
var set_flags_on_start: PackedStringArray = PackedStringArray()
var clear_flags_on_start: PackedStringArray = PackedStringArray()
var set_flags_on_end: PackedStringArray = PackedStringArray()


func is_fixed() -> bool:
	return type == TYPE_FIXED


func is_free() -> bool:
	return type == TYPE_FREE


func is_compressed() -> bool:
	return type == TYPE_COMPRESSED


static func from_dict(d: Dictionary, errors: PackedStringArray) -> DaySchedule:
	var s: DaySchedule = DaySchedule.new()
	s.day = int(d.get("day", 0))
	var label: String = "day %d" % s.day
	s.type = str(d.get("type", ""))
	if not TYPES.has(s.type):
		errors.append("%s: type '%s' は fixed / free / compressed のいずれかである必要があります" % [label, s.type])
	s.title = str(d.get("title", ""))
	var ev: Variant = d.get("opening_event", null)
	s.opening_event = "" if ev == null else str(ev)
	var cond: Variant = d.get("advance_condition", null)
	if cond is Dictionary:
		var c: Dictionary = cond
		if c.has("flag"):
			s.condition_flag = str(c["flag"])
			s.condition_flag_value = bool(c.get("is", true))
		if c.has("points"):
			s.required_points = int(c["points"])
	if s.is_fixed() and s.condition_flag.is_empty():
		errors.append("%s: 固定日には advance_condition.flag が必要です" % label)
	if s.is_free() and s.required_points <= 0:
		errors.append("%s: 自由日には advance_condition.points（1 以上）が必要です" % label)
	var skip: Variant = d.get("skip_to", null)
	s.skip_to = 0 if skip == null else int(skip)
	var ctext: Variant = d.get("compressed_text_id", null)
	s.compressed_text_id = "" if ctext == null else str(ctext)
	if s.is_compressed() and (s.skip_to <= s.day or s.compressed_text_id.is_empty()):
		errors.append("%s: 圧縮日には skip_to（当日より後）と compressed_text_id が必要です" % label)
	s.available_fields = _strings(d.get("available_fields", []))
	s.set_flags_on_start = _strings(d.get("set_flags_on_start", []))
	s.clear_flags_on_start = _strings(d.get("clear_flags_on_start", []))
	s.set_flags_on_end = _strings(d.get("set_flags_on_end", []))
	return s


static func _strings(value: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if value is Array:
		for v: Variant in value as Array:
			out.append(str(v))
	return out
