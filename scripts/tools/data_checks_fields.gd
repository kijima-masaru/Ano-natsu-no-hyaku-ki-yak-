class_name DataChecksFields
extends RefCounted
## フィールド定義と ASCII 地図の検査（validate_data から呼ぶ）。
## 出口の双方向性、シーンの実装状況、MAP_ROWS の寸法・外周・到達性、調べ物とイベントの対応、自由日の調査 P 供給。

const SCRIPT_DIR: String = "res://scripts/fields/"
const NEIGHBORS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]


## 出口の双方向性とシーンの存在
static func check_fields(report: DataReport, fields: Array) -> Dictionary:
	var by_id: Dictionary = {}
	for f: Dictionary in fields:
		by_id[str(f.get("id", ""))] = f
	var implemented: Dictionary = {}
	for f: Dictionary in fields:
		var id: String = str(f.get("id", ""))
		var scene: String = str(f.get("scene_path", ""))
		if FileAccess.file_exists(scene):
			implemented[id] = true
		for e: Dictionary in f.get("exits", []):
			var to: String = str(e.get("to", ""))
			if not by_id.has(to):
				report.error("fields", "%s: 出口の接続先 '%s' は存在しません" % [id, to])
				continue
			var back: bool = false
			for e2: Dictionary in (by_id[to] as Dictionary).get("exits", []):
				if str(e2.get("to", "")) == id:
					back = true
			if not back:
				report.error("fields", "%s→%s があるのに %s→%s がありません（双方向でない）" % [id, to, to, id])
	return implemented


## 実装済みフィールドの .gd を読み、MAP_ROWS と調べ物を検査する。戻り値は field_id → 調べ物 id の集合
static func check_maps(report: DataReport, fields: Array, implemented: Dictionary) -> Dictionary:
	var targets: Dictionary = {}
	for f: Dictionary in fields:
		var id: String = str(f.get("id", ""))
		if not implemented.has(id):
			continue
		var script_path: String = SCRIPT_DIR + str(f.get("scene_path", "")).get_file().get_basename() + ".gd"
		var src: FileAccess = FileAccess.open(script_path, FileAccess.READ)
		if src == null:
			report.warn("map", "%s: %s が無いため地図の検査を飛ばします" % [id, script_path])
			continue
		var text: String = src.get_as_text()
		var ids: Dictionary = _interactable_ids(text)
		targets[id] = ids
		_check_map(report, f, text, ids)
	return targets


## 調べ物 id → kind。動的に出す NPC は kind を npc とする
static func _interactable_ids(text: String) -> Dictionary:
	var ids: Dictionary = {}
	var poi_re: RegEx = RegEx.new()
	poi_re.compile('"id": "([a-z_0-9]+)"[^\\n]*?"kind": "([a-z_]+)"')
	for m: RegExMatch in poi_re.search_all(text):
		ids[m.get_string(1)] = m.get_string(2)
	for pattern: String in ['set_npc_present\\("([a-z_0-9]+)"', 'Interactable\\.create\\("([a-z_0-9]+)"', 'add_point_of_interest\\("([a-z_0-9]+)"']:
		var re: RegEx = RegEx.new()
		re.compile(pattern)
		for m: RegExMatch in re.search_all(text):
			if not ids.has(m.get_string(1)):
				ids[m.get_string(1)] = "npc"
	return ids


static func _check_map(report: DataReport, f: Dictionary, text: String, _ids: Dictionary) -> void:
	var id: String = str(f.get("id", ""))
	var rows_re: RegEx = RegEx.new()
	rows_re.compile("MAP_ROWS: PackedStringArray = \\[([\\s\\S]*?)\\n\\]")
	var rows_m: RegExMatch = rows_re.search(text)
	if rows_m == null:
		report.warn("map", "%s: MAP_ROWS が見つかりません（独自の _build なら問題なし）" % id)
		return
	var str_re: RegEx = RegEx.new()
	str_re.compile('"([^"]+)"')
	var rows: PackedStringArray = PackedStringArray()
	for m: RegExMatch in str_re.search_all(rows_m.get_string(1)):
		rows.append(m.get_string(1))
	var ground_re: RegEx = RegEx.new()
	ground_re.compile("GROUND_LEGEND: Dictionary = \\{([\\s\\S]*?)\\n\\}")
	var g_m: RegExMatch = ground_re.search(text)
	var walk: Dictionary = {}
	if g_m != null:
		var key_re: RegEx = RegEx.new()
		key_re.compile('"(.)":')
		for m: RegExMatch in key_re.search_all(g_m.get_string(1)):
			walk[m.get_string(1)] = true
	var size: Dictionary = f.get("size_tiles", {})
	var w: int = int(size.get("w", 0))
	var h: int = int(size.get("h", 0))
	if rows.size() != h or rows.is_empty() or rows[0].length() != w:
		report.error("map", "%s: MAP_ROWS %d×%d が size_tiles %d×%d と一致しません" % [id, rows[0].length() if not rows.is_empty() else 0, rows.size(), w, h])
		return
	var exits: Dictionary = {}
	for e: Dictionary in f.get("exits", []):
		var t: Array = e.get("tile", [0, 0])
		exits[Vector2i(int(t[0]), int(t[1]))] = true
	var start: Vector2i = Vector2i(-1, -1)
	for y: int in h:
		for x: int in w:
			var ch: String = rows[y][x]
			var edge: bool = x == 0 or y == 0 or x == w - 1 or y == h - 1
			if walk.has(ch) and start.x < 0:
				start = Vector2i(x, y)
			if edge and walk.has(ch) and not exits.has(Vector2i(x, y)):
				report.error("map", "%s: 外周 (%d, %d) '%s' が開いています" % [id, x, y, ch])
	for ex: Vector2i in exits.keys():
		if not walk.has(rows[ex.y][ex.x]):
			report.error("map", "%s: 出口 %s が通行不可です" % [id, ex])
	var seen: Dictionary = _flood(rows, walk, start, w, h)
	for ex: Vector2i in exits.keys():
		if not seen.has(ex):
			report.error("map", "%s: 出口 %s に到達できません" % [id, ex])
	var isolated: int = 0
	for y: int in h:
		for x: int in w:
			if walk.has(rows[y][x]) and not seen.has(Vector2i(x, y)):
				isolated += 1
	if isolated > 0:
		report.warn("map", "%s: 孤立した通行可タイル %d 個（意図した閉域なら可）" % [id, isolated])
	var poi_re: RegEx = RegEx.new()
	poi_re.compile('"id": "([a-z_0-9]+)"[^\\n]*?"tile": Vector2i\\((-?\\d+), (-?\\d+)\\)')
	for m: RegExMatch in poi_re.search_all(text):
		var p: Vector2i = Vector2i(int(m.get_string(2)), int(m.get_string(3)))
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			report.error("map", "%s: 調べ物 %s の座標 %s がフィールド外です（雛形の未設定値も含む）" % [id, m.get_string(1), p])
			continue
		if walk.has(rows[p.y][p.x]):
			report.warn("map", "%s: 調べ物 %s %s が通行可タイルの上にあります" % [id, m.get_string(1), p])
		var adjacent: bool = false
		for n: Vector2i in NEIGHBORS:
			if seen.has(p + n):
				adjacent = true
		if not adjacent:
			report.error("map", "%s: 調べ物 %s %s に隣接する通行可タイルがありません" % [id, m.get_string(1), p])


static func _flood(rows: PackedStringArray, walk: Dictionary, start: Vector2i, w: int, h: int) -> Dictionary:
	var seen: Dictionary = {}
	if start.x < 0:
		return seen
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for n: Vector2i in NEIGHBORS:
			var q: Vector2i = p + n
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or seen.has(q):
				continue
			if walk.has(rows[q.y][q.x]):
				seen[q] = true
				queue.append(q)
	return seen


## on_interact の target が調べ物にあるか、調べ物にイベントがあるか
static func check_targets(report: DataReport, events: Array, targets: Dictionary) -> void:
	var used: Dictionary = {}
	for e: Dictionary in events:
		if e.get("trigger") != "on_interact":
			continue
		var field: String = str(e.get("field", ""))
		var target: String = str(e.get("target", ""))
		if field.is_empty() or not targets.has(field):
			continue
		used["%s/%s" % [field, target]] = true
		if not (targets[field] as Dictionary).has(target):
			report.error("events", "%s: target '%s' は %s の調べ物にありません" % [str(e.get("id", "")), target, field])
	for field: String in targets.keys():
		var pois: Dictionary = targets[field]
		for poi: String in pois.keys():
			if str(pois[poi]) == "save_point":  # セーブ地点は Main が直接扱う
				continue
			if not used.has("%s/%s" % [field, poi]):
				report.warn("events", "%s: 調べ物 '%s' に on_interact イベントがありません（msg_nothing_here が出ます）" % [field, poi])


## 自由日ごとに、その日に使える once の add_points イベントが required に足りるか
static func check_points(report: DataReport, schedule: Array, events: Array) -> void:
	for d: Dictionary in schedule:
		if str(d.get("type", "")) != "free":
			continue
		var day: int = int(d.get("day", 0))
		var required: int = int((d.get("advance_condition", {}) as Dictionary).get("points", 0))
		var avail: Array = d.get("available_fields", [])
		var supply: int = 0
		var repeatable: PackedStringArray = PackedStringArray()
		for e: Dictionary in events:
			var gives: bool = false
			for a: Dictionary in e.get("actions", []):
				if a.get("type") == "add_points":
					gives = true
			if not gives:
				continue
			var field: String = str(e.get("field", ""))
			if not field.is_empty() and not avail.has(field):
				continue
			var r: Array = e.get("day_range", [])
			if r.size() == 2 and (day < int(r[0]) or day > int(r[1])):
				continue
			if not bool(e.get("once", false)):
				repeatable.append(str(e.get("id", "")))
			supply += 1
		for rid: String in repeatable:
			report.error("points", "%s は once=false なのに add_points を持ち、無限に P を得られます" % rid)
		if supply < required:
			report.warn("points", "day %d: 調査 P の供給源 %d < 必要 %d（初訪問ボーナスを除く）" % [day, supply, required])
