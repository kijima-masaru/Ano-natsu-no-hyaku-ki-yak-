class_name FieldScaffold
extends RefCounted
## フィールド雛形の生成。data/fields.json の ID から
##   scripts/fields/fXX_<slug>.gd（凡例・空地図・調べ物の雛形）
##   scenes/fields/fXX_<slug>.tscn（field_base.tscn を継承）
##   data/skeletons/fXX_<slug>.json（events.json / messages.json に貼り込むスケルトン）
## を書き出す。既存ファイルは上書きしない（force=true で上書き）。
## ゲームロジック（autoload）を参照しない（docs/CONVENTIONS.md §1）。JSON は直接読む。

const FIELDS_PATH: String = "res://data/fields.json"
const SCRIPT_DIR: String = "res://scripts/fields/"
const SKELETON_DIR: String = "res://data/skeletons/"
const BASE_SCENE: String = "res://scenes/fields/field_base.tscn"
const WALL_CHAR: String = "w"
const GROUND_CHAR: String = "."
const DEFAULT_GROUND_TYPE: String = "アスファルト"
const DEFAULT_WALL_TYPE: String = "ブロック塀"


## 生成して書き出したパスを返す。失敗時は空配列（理由は push_error）
static func generate(field_id: String, force: bool = false) -> PackedStringArray:
	var def: Dictionary = _load_field(field_id)
	if def.is_empty():
		return PackedStringArray()
	var scene_path: String = str(def.get("scene_path", ""))
	var slug: String = scene_path.get_file().get_basename()  # fXX_<slug>
	if slug.is_empty():
		push_error("FieldScaffold: %s の scene_path が空です" % field_id)
		return PackedStringArray()
	var script_path: String = SCRIPT_DIR + slug + ".gd"
	var skeleton_path: String = SKELETON_DIR + slug + ".json"
	var written: PackedStringArray = PackedStringArray()
	for pair: Array in [[script_path, _script_text(def, slug)], [scene_path, _scene_text(def, slug, script_path)], [skeleton_path, _skeleton_text(def)]]:
		var path: String = pair[0]
		if FileAccess.file_exists(path) and not force:
			push_warning("FieldScaffold: %s は既に存在するため書き出しません（force で上書き）" % path)
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			push_error("FieldScaffold: %s を開けません（%s）" % [path, error_string(FileAccess.get_open_error())])
			continue
		f.store_string(pair[1])
		written.append(path)
	return written


static func _load_field(field_id: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(FIELDS_PATH, FileAccess.READ)
	if f == null:
		push_error("FieldScaffold: %s を開けません" % FIELDS_PATH)
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		push_error("FieldScaffold: fields.json の形式が不正です")
		return {}
	for entry: Variant in (data as Dictionary).get("fields", []):
		if str((entry as Dictionary).get("id", "")) == field_id:
			return entry
	push_error("FieldScaffold: フィールド '%s' は fields.json にありません" % field_id)
	return {}


## 外周を壁、内側を地面、出口タイルだけ開けた空地図
static func _map_rows(def: Dictionary) -> PackedStringArray:
	var size: Dictionary = def.get("size_tiles", {})
	var w: int = int(size.get("w", 0))
	var h: int = int(size.get("h", 0))
	var exits: Dictionary = {}
	for e: Variant in def.get("exits", []):
		var t: Array = (e as Dictionary).get("tile", [])
		if t.size() == 2:
			exits[Vector2i(int(t[0]), int(t[1]))] = true
	var rows: PackedStringArray = PackedStringArray()
	for y: int in h:
		var row: String = ""
		for x: int in w:
			var edge: bool = x == 0 or y == 0 or x == w - 1 or y == h - 1
			row += GROUND_CHAR if (not edge or exits.has(Vector2i(x, y))) else WALL_CHAR
		rows.append(row)
	return rows


static func _exit_summary(def: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for e: Variant in def.get("exits", []):
		var d: Dictionary = e
		var t: Array = d.get("tile", [0, 0])
		parts.append("%s→%s (%d,%d)" % [str(d.get("side", "")), str(d.get("to", "")), int(t[0]), int(t[1])])
	return "、".join(parts)


static func _script_text(def: Dictionary, slug: String) -> String:
	var id: String = str(def.get("id", ""))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("extends FieldBase")
	lines.append("## %s %s。%s" % [id, str(def.get("name", "")), str(def.get("story_role", ""))])
	lines.append("## 怪異の兆し：%s" % str(def.get("horror_beat", "")))
	lines.append("## 出口：%s。環境音 %s" % [_exit_summary(def), str(def.get("ambience_track", ""))])
	lines.append("## TODO(step-4): 雛形（field_scaffold）。地図・凡例・調べ物の座標を埋める。required_tiles：")
	for t: Variant in def.get("required_tiles", []):
		lines.append("##   - %s" % str(t))
	lines.append("")
	lines.append("const GROUND_LEGEND: Dictionary = {")
	lines.append('\t"%s": "%s",' % [GROUND_CHAR, DEFAULT_GROUND_TYPE])
	lines.append("}")
	lines.append("const OBJECT_LEGEND: Dictionary = {")
	lines.append('\t"%s": "%s",' % [WALL_CHAR, DEFAULT_WALL_TYPE])
	lines.append("}")
	lines.append("## 調べ物。テキストとフラグ操作は data/events.json（on_interact, target=id）。tile は要設定")
	lines.append("const INTERACTABLES: Array = [")
	var i: int = 0
	for label: Variant in def.get("interactables", []):
		i += 1
		lines.append('\t{"id": "poi_%02d", "name": "%s", "tile": Vector2i(-1, -1), "kind": "object"},' % [i, str(label)])
	lines.append("]")
	lines.append("## 物体タイルの下地")
	lines.append('const DEFAULT_GROUND: String = "%s"' % DEFAULT_GROUND_TYPE)
	lines.append("const MAP_ROWS: PackedStringArray = [")
	for row: String in _map_rows(def):
		lines.append('\t"%s",' % row)
	lines.append("]")
	lines.append("")
	lines.append("")
	lines.append("## 時間帯（Calendar.TIME_*）で灯り・門・NPC を差し替える")
	lines.append("func _apply_time_of_day(_time_of_day: String) -> void:")
	lines.append("\tpass")
	lines.append("")
	lines.append("")
	lines.append("## 日付で配置を差し替える。最後に _apply_time_of_day(Calendar.time_of_day) を呼ぶと整合しやすい")
	lines.append("func _apply_day(_day: int) -> void:")
	lines.append("\tpass")
	lines.append("")
	return "\n".join(lines)


static func _scene_text(def: Dictionary, slug: String, script_path: String) -> String:
	var node_name: String = slug.to_pascal_case()
	var spawn: String = ""
	var exits: Array = def.get("exits", [])
	if not exits.is_empty():
		var e: Dictionary = exits[0]
		var t: Array = e.get("tile", [0, 0])
		var inward: Vector2i = Vector2i(int(t[0]), int(t[1])) + _inward(str(e.get("side", "")))
		spawn = "default_spawn_tile = Vector2i(%d, %d)\n" % [inward.x, inward.y]
	return ("[gd_scene load_steps=3 format=3]\n\n"
		+ '[ext_resource type="PackedScene" path="%s" id="1_base"]\n' % BASE_SCENE
		+ '[ext_resource type="Script" path="%s" id="2_script"]\n\n' % script_path
		+ '[node name="%s" instance=ExtResource("1_base")]\n' % node_name
		+ 'script = ExtResource("2_script")\n' + spawn)


static func _inward(side: String) -> Vector2i:
	match side:
		"N": return Vector2i.DOWN
		"S": return Vector2i.UP
		"E": return Vector2i.LEFT
		"W": return Vector2i.RIGHT
	return Vector2i.ZERO


## events.json / messages.json へ貼り込むスケルトン（調べ物ごとに 1 イベント・1 メッセージ）
static func _skeleton_text(def: Dictionary) -> String:
	var id: String = str(def.get("id", ""))
	var lower: String = id.to_lower()
	var events: Array = []
	var messages: Array = []
	var i: int = 0
	for label: Variant in def.get("interactables", []):
		i += 1
		var poi: String = "poi_%02d" % i
		var msg_id: String = "msg_%s_%s" % [lower, poi]
		events.append({"id": "ev_%s_%s" % [lower, poi], "field": id, "trigger": "on_interact", "target": poi,
			"conditions": [], "actions": [{"type": "message", "id": msg_id}], "once": false, "priority": 0})
		messages.append({"id": msg_id, "speaker": "yu", "text": "TODO: %s" % str(label)})
	events.append({"id": "ev_%s_enter" % lower, "field": id, "trigger": "on_enter", "day_range": [1, 31],
		"conditions": [], "actions": [{"type": "message", "id": "msg_%s_enter" % lower}], "once": true, "priority": 0})
	messages.append({"id": "msg_%s_enter" % lower, "speaker": "yu", "text": "TODO: 初回進入の地の文（二層なら truth_id を付ける）"})
	return JSON.stringify({"note": "events を data/events.json の events に、messages を data/messages.json の messages に貼り込み、この文書は削除する",
		"events": events, "messages": messages}, "  ", false)
