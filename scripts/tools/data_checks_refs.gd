class_name DataChecksRefs
extends RefCounted
## data/*.json の相互参照の検査（validate_data から呼ぶ）。autoload を参照しない純関数群。
## 各関数は report（DataReport）へ error / warn を追記する。

## EventActions と各 autoload が register_action する種別（新アクションを足したらここも更新する）
const KNOWN_ACTIONS: PackedStringArray = [
	"message", "set_flag", "clear_flag", "give_item", "remove_item", "unlock_field", "move_player", "advance_day",
	"set_time", "add_points", "wait", "run_event", "end_game", "choice", "autosave", "set_companion", "start_stalker",
	"sleep", "give_evidence", "conceal_evidence", "show_concealment_reveal", "raise_suspicion", "play_sound",
	"play_bgm", "stop_bgm", "entity_speak", "entity_comfort", "entity_pulse", "switch_floor",
]
const KNOWN_CONDITIONS: PackedStringArray = [
	"flag", "has_item", "field_visited", "day", "day_range", "time_of_day", "not", "any", "all", "suspicion", "can_sleep", "floor",
]
## コードが規約的に立てるフラグの接頭辞
const FLAG_PREFIXES: PackedStringArray = ["hid_", "hid_fail_", "ev_", "ev_done_", "day_", "seen_", "visited_", "luck_", "an_done_", "ev_day_"]
const FLAGS_DOC: String = "res://docs/FLAGS.md"
const ANOMALY_TRIGGERS: PackedStringArray = ["on_enter", "on_interact", "on_condition"]
const ANOMALY_MODES: PackedStringArray = ["once", "repeat", "escalate"]
const COMFORT_CONTEXTS: PackedStringArray = ["after_anomaly", "after_stalker", "night_walk", "yakushi_gate", "heroine_near"]


## ドキュメント・イベント・日程で定義されているフラグの集合
static func collect_defined_flags(events: Array, schedule: Array) -> Dictionary:
	var flags: Dictionary = {}
	for e: Dictionary in events:
		for a: Dictionary in e.get("actions", []):
			if a.get("type") == "set_flag" or a.get("type") == "clear_flag":
				flags[str(a.get("flag", ""))] = true
			if a.get("type") == "choice":
				for o: Dictionary in a.get("options", []):
					if o.has("set_flag"):
						flags[str(o["set_flag"])] = true
	for d: Dictionary in schedule:
		for key: String in ["set_flags_on_start", "set_flags_on_end", "clear_flags_on_start"]:
			for f: Variant in d.get(key, []):
				flags[str(f)] = true
	var doc: FileAccess = FileAccess.open(FLAGS_DOC, FileAccess.READ)
	if doc != null:
		var re: RegEx = RegEx.new()
		re.compile("^\\| `([A-Za-z0-9_<>]+)`")
		for line: String in doc.get_as_text().split("\n"):
			var m: RegExMatch = re.search(line)
			if m != null:
				flags[m.get_string(1)] = true
	return flags


static func flag_is_known(flag: String, defined: Dictionary) -> bool:
	if defined.has(flag):
		return true
	for p: String in FLAG_PREFIXES:
		if flag.begins_with(p):
			return true
	return false


static func check_events(report: DataReport, events: Array, ctx: Dictionary) -> void:
	var event_ids: Dictionary = {}
	for e: Dictionary in events:
		event_ids[str(e.get("id", ""))] = true
	for e: Dictionary in events:
		var id: String = str(e.get("id", ""))
		var field: String = str(e.get("field", ""))
		if not field.is_empty() and not ctx["fields"].has(field):
			report.error("events", "%s: field '%s' は存在しません" % [id, field])
		if e.get("trigger") == "on_day_start" and not e.has("day_range"):
			report.error("events", "%s: on_day_start には day_range が必要です" % id)
		for c: Variant in e.get("conditions", []):
			_check_condition(report, id, c, ctx)
		for a: Dictionary in e.get("actions", []):
			_check_action(report, id, a, ctx, event_ids)


static func _check_condition(report: DataReport, id: String, cond: Variant, ctx: Dictionary) -> void:
	if not cond is Dictionary:
		report.error("events", "%s: 条件は Dictionary である必要があります" % id)
		return
	var c: Dictionary = cond
	for key: String in c.keys():
		if key == "is":
			continue
		if not KNOWN_CONDITIONS.has(key):
			report.error("events", "%s: 条件キー '%s' は未定義です" % [id, key])
	if c.has("flag") and not flag_is_known(str(c["flag"]), ctx["flags"]):
		report.error("events", "%s: 条件のフラグ '%s' はどこにも定義されていません（FLAGS.md か set_flag）" % [id, str(c["flag"])])
	if c.has("has_item") and not ctx["items"].has(str(c["has_item"])):
		report.error("events", "%s: アイテム '%s' は items.json にありません" % [id, str(c["has_item"])])
	if c.has("field_visited") and not ctx["fields"].has(str(c["field_visited"])):
		report.error("events", "%s: フィールド '%s' は存在しません" % [id, str(c["field_visited"])])
	if c.has("not"):
		_check_condition(report, id, c["not"], ctx)
	for key: String in ["any", "all"]:
		if c.has(key):
			for sub: Variant in c[key]:
				_check_condition(report, id, sub, ctx)


static func _check_action(report: DataReport, id: String, a: Dictionary, ctx: Dictionary, event_ids: Dictionary) -> void:
	var type: String = str(a.get("type", ""))
	if not KNOWN_ACTIONS.has(type):
		report.error("events", "%s: アクション種別 '%s' は未登録です" % [id, type])
	match type:
		"message", "entity_speak":
			_need_message(report, id, str(a.get("id", "")), ctx)
		"entity_comfort":
			_need_message(report, id, "msg_natsu_comfort_%s" % str(a.get("context", "")), ctx)
		"give_item", "remove_item":
			if not ctx["items"].has(str(a.get("item", ""))):
				report.error("events", "%s: アイテム '%s' は items.json にありません" % [id, str(a.get("item", ""))])
		"move_player", "unlock_field":
			var f: String = str(a.get("field", ""))
			if not f.is_empty() and not ctx["fields"].has(f):
				report.error("events", "%s: フィールド '%s' は存在しません" % [id, f])
		"run_event":
			if not event_ids.has(str(a.get("id", ""))):
				report.error("events", "%s: run_event の '%s' は存在しません" % [id, str(a.get("id", ""))])
		"give_evidence", "conceal_evidence":
			if not ctx["evidence"].has(str(a.get("evidence", ""))):
				report.error("events", "%s: 証拠 '%s' は evidence.json にありません" % [id, str(a.get("evidence", ""))])
		"play_sound", "play_bgm":
			if not ctx["tracks"].has(str(a.get("id", ""))):
				report.error("events", "%s: 音 '%s' は audio.json にありません" % [id, str(a.get("id", ""))])
		"choice":
			if a.has("prompt_id"):
				_need_message(report, id, str(a["prompt_id"]), ctx)
			for o: Dictionary in a.get("options", []):
				_need_message(report, id, str(o.get("text_id", "")), ctx)
				if o.has("run_event") and not event_ids.has(str(o["run_event"])):
					report.error("events", "%s: 選択肢の run_event '%s' は存在しません" % [id, str(o["run_event"])])


static func _need_message(report: DataReport, id: String, msg_id: String, ctx: Dictionary) -> void:
	if not ctx["messages"].has(msg_id):
		report.error("events", "%s: メッセージ '%s' は messages.json にありません" % [id, msg_id])


## 二層テキストの片側欠落と話者
static func check_messages(report: DataReport, messages: Array, speakers: Dictionary) -> void:
	var ids: Dictionary = {}
	for m: Dictionary in messages:
		ids[str(m.get("id", ""))] = m
	for m: Dictionary in messages:
		var id: String = str(m.get("id", ""))
		if m.has("truth_id") and not ids.has(str(m["truth_id"])):
			report.error("messages", "%s: truth_id '%s' が存在しません" % [id, str(m["truth_id"])])
		if id.ends_with("_t"):
			var base: String = id.substr(0, id.length() - 2)
			if ids.has(base) and str((ids[base] as Dictionary).get("truth_id", "")) != id:
				report.error("messages", "%s: 真相版があるのに '%s' に truth_id が付いていません" % [id, base])
		if not speakers.has(str(m.get("speaker", ""))):
			report.error("messages", "%s: 話者 '%s' は meta.speakers にありません" % [id, str(m.get("speaker", ""))])


## 日程：opening_event の存在、available_fields のフィールド存在と実装状況、到達不能フィールド
static func check_schedule(report: DataReport, schedule: Array, ctx: Dictionary, event_ids: Dictionary, strict: bool) -> void:
	var reachable: Dictionary = {}
	var unimplemented_days: Dictionary = {}
	for d: Dictionary in schedule:
		var day: int = int(d.get("day", 0))
		var op: Variant = d.get("opening_event", null)
		if op != null and not str(op).is_empty() and not event_ids.has(str(op)):
			report.error("schedule", "day %d: opening_event '%s' は存在しません" % [day, str(op)])
		for f: Variant in d.get("available_fields", []):
			var fid: String = str(f)
			reachable[fid] = true
			if not ctx["fields"].has(fid):
				report.error("schedule", "day %d: available_fields の '%s' は存在しません" % [day, fid])
			elif not ctx["implemented"].has(fid):
				var days: Array = unimplemented_days.get(fid, [])
				days.append(day)
				unimplemented_days[fid] = days
	var keys: Array = unimplemented_days.keys()
	keys.sort()
	for fid: String in keys:
		var days: Array = unimplemented_days[fid]
		var msg: String = "%s は未実装（シーン無し）ですが day %d〜%d の available_fields に含まれます" % [fid, days.min(), days.max()]
		if strict:
			report.error("schedule", msg)
		else:
			report.warn("schedule", msg)
	for fid: String in ctx["fields"].keys():
		if not reachable.has(fid):
			report.error("schedule", "%s はどの日の available_fields にも含まれず到達できません" % fid)


static func check_evidence(report: DataReport, evidence: Array, ctx: Dictionary) -> void:
	for e: Dictionary in evidence:
		var id: String = str(e.get("id", ""))
		var f: String = str(e.get("field", ""))
		if not f.is_empty() and not ctx["fields"].has(f):
			report.error("evidence", "%s: field '%s' は存在しません" % [id, f])
		for key: String in ["title_id", "surface_id", "truth_id", "shown_id", "action_id"]:
			if e.has(key) and not ctx["messages"].has(str(e[key])):
				report.error("evidence", "%s: %s '%s' は messages.json にありません" % [id, key, str(e[key])])


## anomalies.json：field・trigger・mode・comfort と、events と同じアクション／条件の参照
static func check_anomalies(report: DataReport, anomalies: Array, ctx: Dictionary, event_ids: Dictionary, targets: Dictionary) -> void:
	for a: Dictionary in anomalies:
		var id: String = str(a.get("id", ""))
		var field: String = str(a.get("field", ""))
		if not ctx["fields"].has(field):
			report.error("anomalies", "%s: field '%s' は存在しません" % [id, field])
		var trigger: String = str(a.get("trigger", "on_enter"))
		if not ANOMALY_TRIGGERS.has(trigger):
			report.error("anomalies", "%s: trigger '%s' は %s のいずれか" % [id, trigger, ", ".join(ANOMALY_TRIGGERS)])
		if trigger == "on_interact" and targets.has(field) and not (targets[field] as Dictionary).has(str(a.get("target", ""))):
			report.error("anomalies", "%s: target '%s' は %s の調べ物にありません" % [id, str(a.get("target", "")), field])
		var mode: String = str(a.get("mode", "once"))
		if not ANOMALY_MODES.has(mode):
			report.error("anomalies", "%s: mode '%s' は %s のいずれか" % [id, mode, ", ".join(ANOMALY_MODES)])
		var comfort: String = str(a.get("comfort", ""))
		if not comfort.is_empty() and not COMFORT_CONTEXTS.has(comfort):
			report.error("anomalies", "%s: comfort '%s' は未定義です" % [id, comfort])
		for c: Variant in a.get("conditions", []):
			_check_condition(report, id, c, ctx)
		var lists: Array = [a.get("actions", [])]
		if mode == "escalate":
			lists = []
			if (a.get("stages", []) as Array).is_empty():
				report.error("anomalies", "%s: escalate には stages が必要です" % id)
			for st: Dictionary in a.get("stages", []):
				lists.append(st.get("actions", []))
		for acts: Array in lists:
			if acts.is_empty():
				report.error("anomalies", "%s: actions が空です" % id)
			for act: Dictionary in acts:
				_check_action(report, id, act, ctx, event_ids)
