class_name ExitData
extends RefCounted
## fields.json の exits 1 件分。フィールド境界の出入口を表す不変データ。

const SIDES: PackedStringArray = ["N", "E", "S", "W"]

var from_id: String = ""
var to_id: String = ""
var side: String = ""
var tile: Vector2i = Vector2i.ZERO
## 鍵・フラグ名。空文字なら施錠なし
var lock: String = ""
var note: String = ""


func is_locked() -> bool:
	return lock != ""


## 出口の向き（フィールドの外側へ向かう単位ベクトル）
func side_vector() -> Vector2i:
	match side:
		"N":
			return Vector2i.UP
		"S":
			return Vector2i.DOWN
		"E":
			return Vector2i.RIGHT
		"W":
			return Vector2i.LEFT
	return Vector2i.ZERO


## 出口タイルの 1 タイル内側（遷移先での出現位置に使う）
func inward_tile() -> Vector2i:
	return tile - side_vector()


func describe() -> String:
	return "%s→%s (%s, tile %s%s)" % [from_id, to_id, side, tile, ", lock=" + lock if is_locked() else ""]


## Dictionary から生成する。不備は errors に追記し、可能な限り値を埋めて返す
static func from_dict(owner_id: String, d: Dictionary, errors: PackedStringArray) -> ExitData:
	var e: ExitData = ExitData.new()
	e.from_id = owner_id
	e.to_id = str(d.get("to", ""))
	e.side = str(d.get("side", ""))
	e.note = str(d.get("note", ""))
	var lock_value: Variant = d.get("lock", null)
	e.lock = "" if lock_value == null else str(lock_value)
	if e.to_id.is_empty():
		errors.append("%s: exits に 'to' が無い出口があります" % owner_id)
	if not SIDES.has(e.side):
		errors.append("%s→%s: side '%s' は N/E/S/W のいずれかである必要があります" % [owner_id, e.to_id, e.side])
	var tile_value: Variant = d.get("tile", null)
	if tile_value is Array and (tile_value as Array).size() == 2:
		var arr: Array = tile_value
		e.tile = Vector2i(int(arr[0]), int(arr[1]))
	else:
		errors.append("%s→%s: tile は [x, y] の 2 要素配列である必要があります" % [owner_id, e.to_id])
	return e
