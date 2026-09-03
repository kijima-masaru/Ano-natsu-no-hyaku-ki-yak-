class_name EventValidator
extends RefCounted
## events.json の参照整合性を検証する。存在しないフラグ・アイテム・フィールド・メッセージ・イベント・アクション種別を全件列挙する。
## フラグは「どこかで立てられる名前」か「動的に生成される接頭辞」を既知とみなす。

const DYNAMIC_FLAG_PREFIXES: PackedStringArray = ["visited_", "ev_", "hid_", "hid_fail_", "seen_", "day_", "ev_done_", "luck_", "an_done_", "ev_day_"]
## コードや他システムが立てる、データに現れないフラグ
const CODE_FLAGS: PackedStringArray = ["truth_revealed", "ending_reached", "ending_a", "ending_b", "ending_c",
	"truth_partial_walk", "truth_partial_entity", "companion_on", "notebook_unlocked", "flag_minimap_unlocked",
	"key_tunnel_fence", "key_old_school", "flag_yakushi_open", "entity_intro_done", "slept_at_home",
	"stalker_met"]


## extra_defined は他のデータ（怪異など）が立てるフラグ。EventSystem と AnomalySystem が互いの分を渡す
static func validate(events: Dictionary, known_actions: PackedStringArray, item_ids: PackedStringArray, extra_defined: Dictionary = {}) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var defined_flags: Dictionary = defined_flags_of(events)
	defined_flags.merge(extra_defined)
	for id: String in events.keys():
		var e: EventData = events[id]
		var flags: PackedStringArray = PackedStringArray()
		var items: PackedStringArray = PackedStringArray()
		var fields: PackedStringArray = PackedStringArray()
		for cond: Dictionary in e.conditions:
			ConditionEvaluator.collect_refs(cond, flags, items, fields)
		if not e.field.is_empty():
			fields.append(e.field)
		for action: Dictionary in e.actions:
			var type: String = str(action.get("type", ""))
			if not known_actions.has(type):
				errors.append("%s: アクション種別 '%s' は未登録です" % [id, type])
			match type:
				"message", "entity_speak":
					for key: String in ["id", "truth_id"]:
						if action.has(key) and not MessageResolver.has_message(str(action[key])):
							errors.append("%s: メッセージ '%s' が存在しません" % [id, str(action[key])])
				"entity_comfort":
					var ctx: String = str(action.get("context", ""))
					if not MessageResolver.has_message("msg_natsu_comfort_%s" % ctx):
						errors.append("%s: entity_comfort の context '%s' に対応する台詞がありません" % [id, ctx])
				"give_item", "remove_item":
					items.append(str(action.get("item", "")))
				"move_player", "unlock_field":
					if action.has("field"):
						fields.append(str(action["field"]))
				"run_event":
					if not events.has(str(action.get("id", ""))):
						errors.append("%s: run_event の '%s' が存在しません" % [id, str(action.get("id", ""))])
				"choice":
					if action.has("prompt_id") and not MessageResolver.has_message(str(action["prompt_id"])):
						errors.append("%s: prompt_id '%s' が存在しません" % [id, str(action["prompt_id"])])
					for opt: Variant in action.get("options", []) as Array:
						if not opt is Dictionary:
							continue
						var o: Dictionary = opt
						if not MessageResolver.has_message(str(o.get("text_id", ""))):
							errors.append("%s: 選択肢のテキスト '%s' が存在しません" % [id, str(o.get("text_id", ""))])
						if o.has("run_event") and not events.has(str(o["run_event"])):
							errors.append("%s: 選択肢の run_event '%s' が存在しません" % [id, str(o["run_event"])])
		for f: String in flags:
			if not _is_known_flag(f, defined_flags):
				errors.append("%s: フラグ '%s' はどこでも立てられません" % [id, f])
		for it: String in items:
			if not item_ids.has(it):
				errors.append("%s: アイテム '%s' は items.json に無い" % [id, it])
		for fid: String in fields:
			if not FieldRegistry.has_field(fid):
				errors.append("%s: フィールド '%s' が存在しません" % [id, fid])
		if e.trigger == "on_day_start" and e.day_min == 0:
			errors.append("%s: on_day_start には day_range が必要です" % id)
	return errors


## events が立てるフラグ（set_flag / clear_flag / 選択肢の set_flag）＋ schedule ＋ 鍵 ＋ コード既知
static func defined_flags_of(events: Dictionary) -> Dictionary:
	var defined: Dictionary = {}
	for f: String in CODE_FLAGS:
		defined[f] = true
	for id: String in events.keys():
		var e: EventData = events[id]
		for action: Dictionary in e.actions:
			if str(action.get("type", "")) in ["set_flag", "clear_flag"]:
				defined[str(action.get("flag", ""))] = true
			if str(action.get("type", "")) == "choice":
				for opt: Variant in action.get("options", []) as Array:
					if opt is Dictionary and (opt as Dictionary).has("set_flag"):
						defined[str((opt as Dictionary)["set_flag"])] = true
	for day: int in range(1, 32):
		var s: DaySchedule = Calendar.get_schedule(day) if Calendar.is_valid_day(day) else null
		if s == null:
			continue
		for f: String in s.set_flags_on_start:
			defined[f] = true
		for f: String in s.set_flags_on_end:
			defined[f] = true
		for f: String in s.clear_flags_on_start:
			defined[f] = true
	for lock: String in FieldRegistry.get_lock_names():
		defined[lock] = true
	return defined


static func _is_known_flag(flag: String, defined: Dictionary) -> bool:
	if defined.has(flag):
		return true
	for prefix: String in DYNAMIC_FLAG_PREFIXES:
		if flag.begins_with(prefix):
			return true
	return false
