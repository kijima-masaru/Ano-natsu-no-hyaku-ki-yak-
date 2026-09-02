class_name FieldMapBuilder
extends RefCounted
## ASCII 地図（MAP_ROWS）と凡例からフィールドのタイルと調べ物を組み立てる共通処理。
## FieldBase._build() の既定実装から呼ばれる。サブクラス側は次の const を定義するだけでよい：
##   MAP_ROWS: PackedStringArray  … 行が y、列が x。寸法は fields.json の size_tiles と一致させる
##   GROUND_LEGEND: Dictionary     … 1 文字 → 地面（通行可）の種別名
##   OBJECT_LEGEND: Dictionary     … 1 文字 → 物体（通行不可）の種別名
##   DEFAULT_GROUND: String        … 物体タイルの下地。省略時は GROUND_LEGEND の最初の値
##   OVERHEAD_TILES: Array         … [[Vector2i, 種別名], …]（任意）
##   INTERACTABLES: Array          … [{id, name, tile, kind}, …]（任意）
## 定数はスクリプトの定数表から読むため、フィールドごとの組み立てコードは不要になる。

const KEY_MAP_ROWS: String = "MAP_ROWS"
const KEY_GROUND: String = "GROUND_LEGEND"
const KEY_OBJECTS: String = "OBJECT_LEGEND"
const KEY_DEFAULT_GROUND: String = "DEFAULT_GROUND"
const KEY_OVERHEAD: String = "OVERHEAD_TILES"
const KEY_INTERACTABLES: String = "INTERACTABLES"


## field のスクリプト定数を読み、地図があれば組み立てる。地図が無ければ false
static func build(field: FieldBase, def: FieldData) -> bool:
	var consts: Dictionary = _constants_of(field)
	if not consts.has(KEY_MAP_ROWS):
		return false
	var rows: PackedStringArray = consts[KEY_MAP_ROWS]
	var ground_legend: Dictionary = consts.get(KEY_GROUND, {})
	var object_legend: Dictionary = consts.get(KEY_OBJECTS, {})
	if rows.is_empty() or ground_legend.is_empty():
		push_error("%s: MAP_ROWS と GROUND_LEGEND は空にできません" % field.field_id)
		return false
	var size: Vector2i = Vector2i(rows[0].length(), rows.size())
	if def != null and def.size_tiles != size:
		push_error("%s: MAP_ROWS の寸法 %s が fields.json の size_tiles %s と一致しません" % [field.field_id, size, def.size_tiles])
	var fallback_ground: String = str(consts.get(KEY_DEFAULT_GROUND, str(ground_legend.values()[0])))
	for y: int in rows.size():
		var row: String = rows[y]
		if row.length() != size.x:
			push_error("%s: MAP_ROWS の %d 行目の長さ %d が 1 行目 %d と異なります" % [field.field_id, y, row.length(), size.x])
		for x: int in row.length():
			var ch: String = row[x]
			var tile: Vector2i = Vector2i(x, y)
			if ground_legend.has(ch):
				field.set_tile(field.ground, tile, str(ground_legend[ch]))
			elif object_legend.has(ch):
				var under: String = field._ground_under(x, y)
				field.set_tile(field.ground, tile, under if not under.is_empty() else fallback_ground)
				field.set_tile(field.objects, tile, str(object_legend[ch]))
			else:
				push_error("%s: 凡例に無い文字 '%s'（%s）" % [field.field_id, ch, tile])
				field.set_tile(field.ground, tile, fallback_ground)
	for entry: Variant in consts.get(KEY_OVERHEAD, []):
		var pair: Array = entry
		field.set_tile(field.overhead, pair[0], str(pair[1]))
	for data: Variant in consts.get(KEY_INTERACTABLES, []):
		var d: Dictionary = data
		field.add_interactable(Interactable.create(
			str(d["id"]), str(d.get("name", "")), "", d["tile"], d.get("size", Vector2i.ONE), str(d.get("kind", "object"))))
	return true


## 継承チェーンをたどって定数を集める（サブクラスの定義が優先）
static func _constants_of(node: Node) -> Dictionary:
	var merged: Dictionary = {}
	var script: Script = node.get_script() as Script
	var chain: Array[Script] = []
	while script != null:
		chain.append(script)
		script = script.get_base_script()
	chain.reverse()
	for s: Script in chain:
		merged.merge(s.get_script_constant_map(), true)
	return merged
