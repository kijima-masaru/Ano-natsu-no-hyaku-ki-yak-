extends SceneTree
## データ整合性の一括検証（ヘッドレス）。全フィールド実装の PR 前に必ず実行する。
##   godot --headless --path . -s scripts/tools/validate_data.gd [-- --strict]
## エディタからは scripts/tools/validate_data_editor.gd（File > Run）。
## Godot が無い環境では docs/tools/validate_data.py が同じ検査を行う。
## エラーがあれば終了コード 1。--strict で「日程に未実装フィールドが含まれる」も エラーにする。

const PATHS: Dictionary = {
	"fields": "res://data/fields.json", "events": "res://data/events.json", "messages": "res://data/messages.json",
	"schedule": "res://data/schedule.json", "evidence": "res://data/evidence.json", "items": "res://data/items.json",
	"audio": "res://data/audio.json",
}


func _initialize() -> void:
	var strict: bool = OS.get_cmdline_user_args().has("--strict")
	var report: DataReport = DataReport.new()
	var ok: bool = run(report, strict)
	report.print_all()
	quit(0 if ok else 1)


## 検査を実行し、エラーが無ければ true
static func run(report: DataReport, strict: bool) -> bool:
	var data: Dictionary = {}
	for key: String in PATHS.keys():
		var parsed: Variant = _read_json(str(PATHS[key]))
		if not parsed is Dictionary:
			report.error("io", "%s を読めません" % str(PATHS[key]))
			return false
		data[key] = parsed
	var fields: Array = data["fields"].get("fields", [])
	var events: Array = data["events"].get("events", [])
	var messages: Array = data["messages"].get("messages", [])
	var schedule: Array = data["schedule"].get("days", [])
	var evidence: Array = data["evidence"].get("evidence", [])
	var ctx: Dictionary = {
		"fields": _id_set(fields), "messages": _id_set(messages), "items": _id_set(data["items"].get("items", [])),
		"evidence": _id_set(evidence), "tracks": _id_set(data["audio"].get("tracks", [])),
		"flags": DataChecksRefs.collect_defined_flags(events, schedule),
	}
	ctx["implemented"] = DataChecksFields.check_fields(report, fields)
	DataChecksRefs.check_events(report, events, ctx)
	DataChecksRefs.check_messages(report, messages, data["messages"].get("meta", {}).get("speakers", {}))
	DataChecksRefs.check_schedule(report, schedule, ctx, _id_set(events), strict)
	DataChecksRefs.check_evidence(report, evidence, ctx)
	var targets: Dictionary = DataChecksFields.check_maps(report, fields, ctx["implemented"])
	DataChecksFields.check_targets(report, events, targets)
	DataChecksFields.check_points(report, schedule, events)
	for f: Dictionary in fields:
		var track: String = str(f.get("ambience_track", ""))
		if not track.is_empty() and not ctx["tracks"].has(track):
			report.error("audio", "%s: ambience_track '%s' は audio.json にありません" % [str(f.get("id", "")), track])
	return report.errors.is_empty()


static func _read_json(path: String) -> Variant:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


static func _id_set(items: Array) -> Dictionary:
	var out: Dictionary = {}
	for it: Variant in items:
		if it is Dictionary:
			out[str((it as Dictionary).get("id", ""))] = true
	return out
