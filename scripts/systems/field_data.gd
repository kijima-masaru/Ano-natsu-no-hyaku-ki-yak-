class_name FieldData
extends RefCounted
## fields.json の 1 フィールド分を型付きで保持する不変データ。
## Dictionary のままゲームロジックに流さないための境界（docs/CONVENTIONS.md §3）。

## JSON に必須のキー。欠落は FieldRegistry が起動時にエラーとして報告する
const REQUIRED_KEYS: PackedStringArray = [
	"id", "name", "reading", "scene_path", "world_pos", "size_tiles", "elevation", "biome",
	"palette_accent", "ambience", "exits", "landmarks", "interactables", "required_tiles",
	"story_role", "horror_beat", "unlock_flag",
]

var id: String = ""
var name: String = ""
var reading: String = ""
var scene_path: String = ""
## 6×6 のワールドグリッド上の位置と占有セル数
var world_pos: Rect2i = Rect2i()
## フィールドの寸法（タイル数）
var size_tiles: Vector2i = Vector2i.ZERO
var elevation: int = 0
var biome: String = ""
var palette_accent: String = ""
var palette_accent_idx: PackedInt32Array = PackedInt32Array()
var ambience: String = ""
var exits: Array[ExitData] = []
var landmarks: PackedStringArray = PackedStringArray()
var interactables: PackedStringArray = PackedStringArray()
var required_tiles: PackedStringArray = PackedStringArray()
var story_role: String = ""
var horror_beat: String = ""
## 進入に必要なフラグ名。空文字なら常に進入可
var unlock_flag: String = ""
## 環境音トラック ID（data/audio.json）。空なら無音
var ambience_track: String = ""


## フィールドの寸法（ピクセル）
func size_px() -> Vector2i:
	return size_tiles * GameConstants.TILE_SIZE


## 指定タイルがフィールド内か
func contains_tile(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < size_tiles.x and tile.y < size_tiles.y


## to_id へ向かう出口。無ければ null
func find_exit_to(to_id: String) -> ExitData:
	for e: ExitData in exits:
		if e.to_id == to_id:
			return e
	return null


## Dictionary から生成する。不備は errors に追記し、可能な限り値を埋めて返す
static func from_dict(d: Dictionary, errors: PackedStringArray) -> FieldData:
	var f: FieldData = FieldData.new()
	f.id = str(d.get("id", ""))
	var label: String = f.id if not f.id.is_empty() else "(id 無し)"
	for key: String in REQUIRED_KEYS:
		if not d.has(key):
			errors.append("%s: 必須キー '%s' がありません" % [label, key])
	f.name = str(d.get("name", ""))
	f.reading = str(d.get("reading", ""))
	f.scene_path = str(d.get("scene_path", ""))
	f.elevation = int(d.get("elevation", 0))
	f.biome = str(d.get("biome", ""))
	f.palette_accent = str(d.get("palette_accent", ""))
	f.ambience = str(d.get("ambience", ""))
	f.story_role = str(d.get("story_role", ""))
	f.horror_beat = str(d.get("horror_beat", ""))
	var unlock: Variant = d.get("unlock_flag", null)
	f.unlock_flag = "" if unlock == null else str(unlock)
	f.ambience_track = str(d.get("ambience_track", ""))

	var wp: Variant = d.get("world_pos", {})
	if wp is Dictionary:
		var w: Dictionary = wp
		f.world_pos = Rect2i(int(w.get("col", 0)), int(w.get("row", 0)), int(w.get("w", 1)), int(w.get("h", 1)))
	else:
		errors.append("%s: world_pos は {col,row,w,h} の辞書である必要があります" % label)
	var st: Variant = d.get("size_tiles", {})
	if st is Dictionary:
		var s: Dictionary = st
		f.size_tiles = Vector2i(int(s.get("w", 0)), int(s.get("h", 0)))
	else:
		errors.append("%s: size_tiles は {w,h} の辞書である必要があります" % label)

	f.palette_accent_idx = _to_int_array(d.get("palette_accent_idx", []))
	f.landmarks = _to_string_array(d.get("landmarks", []))
	f.interactables = _to_string_array(d.get("interactables", []))
	f.required_tiles = _to_string_array(d.get("required_tiles", []))

	var exits_value: Variant = d.get("exits", [])
	if exits_value is Array:
		for item: Variant in exits_value as Array:
			if item is Dictionary:
				f.exits.append(ExitData.from_dict(f.id, item, errors))
			else:
				errors.append("%s: exits の要素が辞書ではありません" % label)
	else:
		errors.append("%s: exits は配列である必要があります" % label)
	return f


static func _to_string_array(value: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if value is Array:
		for v: Variant in value as Array:
			out.append(str(v))
	return out


static func _to_int_array(value: Variant) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if value is Array:
		for v: Variant in value as Array:
			out.append(int(v))
	return out
