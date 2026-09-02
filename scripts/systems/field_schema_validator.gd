class_name FieldSchemaValidator
extends RefCounted
## fields.json の意味的な整合性を検証する。構文エラーは FieldRegistry が先に弾く。
## 検出対象：ID 形式、重複、シーンパス、寸法範囲、グリッド範囲、標高範囲、
## 出口の参照先・側面・タイル範囲・鍵名、双方向性と鍵の対称性、unlock_flag の存在、パレットの一致。

const ID_REGEX_PATTERN: String = "^F(0[1-9]|1[0-6])$"
const GRID_COLS: int = 6
const GRID_ROWS: int = 6
const MIN_TILES: Vector2i = Vector2i(24, 24)
const MAX_TILES: Vector2i = Vector2i(64, 48)
const MIN_ELEVATION: int = 0
const MAX_ELEVATION: int = 5


## fields: id → FieldData。locks: 鍵名 → 説明。palette_hex: meta.palette の hex 配列
static func validate(fields: Dictionary, locks: Dictionary, palette_hex: PackedStringArray) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var id_regex: RegEx = RegEx.new()
	id_regex.compile(ID_REGEX_PATTERN)
	var occupied: Dictionary = {}
	for id: String in fields.keys():
		var f: FieldData = fields[id]
		_validate_field(f, id_regex, occupied, errors)
		for e: ExitData in f.exits:
			_validate_exit(f, e, fields, locks, errors)
		if not f.unlock_flag.is_empty() and not locks.has(f.unlock_flag):
			errors.append("%s: unlock_flag '%s' が meta.locks に定義されていません" % [f.id, f.unlock_flag])
	_validate_palette(palette_hex, errors)
	return errors


static func _validate_field(f: FieldData, id_regex: RegEx, occupied: Dictionary, errors: PackedStringArray) -> void:
	if id_regex.search(f.id) == null:
		errors.append("'%s': id は F01〜F16 の形式である必要があります" % f.id)
	if not f.scene_path.begins_with("res://scenes/fields/") or not f.scene_path.ends_with(".tscn"):
		errors.append("%s: scene_path '%s' は res://scenes/fields/*.tscn である必要があります" % [f.id, f.scene_path])
	if f.size_tiles.x < MIN_TILES.x or f.size_tiles.x > MAX_TILES.x \
			or f.size_tiles.y < MIN_TILES.y or f.size_tiles.y > MAX_TILES.y:
		errors.append("%s: size_tiles %s は幅 %d〜%d・高さ %d〜%d の範囲外です"
			% [f.id, f.size_tiles, MIN_TILES.x, MAX_TILES.x, MIN_TILES.y, MAX_TILES.y])
	if f.elevation < MIN_ELEVATION or f.elevation > MAX_ELEVATION:
		errors.append("%s: elevation %d は %d〜%d の範囲外です" % [f.id, f.elevation, MIN_ELEVATION, MAX_ELEVATION])
	var wp: Rect2i = f.world_pos
	if wp.position.x < 0 or wp.position.y < 0 or wp.end.x > GRID_COLS or wp.end.y > GRID_ROWS or wp.size.x < 1 or wp.size.y < 1:
		errors.append("%s: world_pos %s は %d×%d グリッドに収まりません" % [f.id, wp, GRID_COLS, GRID_ROWS])
	for cx: int in range(wp.position.x, wp.end.x):
		for cy: int in range(wp.position.y, wp.end.y):
			var cell: Vector2i = Vector2i(cx, cy)
			if occupied.has(cell):
				errors.append("%s: world_pos のセル %s が %s と重なっています" % [f.id, cell, occupied[cell]])
			occupied[cell] = f.id
	for i: int in f.palette_accent_idx.size():
		var idx: int = f.palette_accent_idx[i]
		if idx < 0 or idx >= Palette.SIZE:
			errors.append("%s: palette_accent_idx %d は 0〜%d の範囲外です" % [f.id, idx, Palette.SIZE - 1])


static func _validate_exit(f: FieldData, e: ExitData, fields: Dictionary, locks: Dictionary, errors: PackedStringArray) -> void:
	if not fields.has(e.to_id):
		errors.append("%s: 出口の接続先 '%s' は存在しないフィールドです" % [f.id, e.to_id])
		return
	if e.to_id == f.id:
		errors.append("%s: 自分自身への出口があります" % f.id)
	if not f.contains_tile(e.tile):
		errors.append("%s→%s: tile %s がフィールド寸法 %s の外です" % [f.id, e.to_id, e.tile, f.size_tiles])
	if e.is_locked() and not locks.has(e.lock):
		errors.append("%s→%s: lock '%s' が meta.locks に定義されていません" % [f.id, e.to_id, e.lock])
	var target: FieldData = fields[e.to_id]
	var back: ExitData = target.find_exit_to(f.id)
	if back == null:
		errors.append("%s→%s: 逆方向の出口 %s→%s がありません（双方向でない接続）" % [f.id, e.to_id, e.to_id, f.id])
	elif back.lock != e.lock:
		errors.append("%s⇄%s: lock が対称ではありません（'%s' と '%s'）" % [f.id, e.to_id, e.lock, back.lock])


## meta.palette が Palette.COLORS と完全に一致するか
static func _validate_palette(palette_hex: PackedStringArray, errors: PackedStringArray) -> void:
	if palette_hex.size() != Palette.SIZE:
		errors.append("meta.palette は %d 色である必要があります（%d 色）" % [Palette.SIZE, palette_hex.size()])
		return
	for i: int in Palette.SIZE:
		var expected: String = Palette.COLORS[i].to_html(false).to_lower()
		var actual: String = palette_hex[i].trim_prefix("#").to_lower()
		if expected != actual:
			errors.append("meta.palette[%d] '#%s' が Palette.COLORS[%d] '#%s' と一致しません" % [i, actual, i, expected])
