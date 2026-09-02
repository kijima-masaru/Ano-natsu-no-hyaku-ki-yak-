class_name FieldFloors
extends RefCounted
## 屋内の階層移動（F11 旧校舎など）。フィールドスクリプトの定数 FLOORS に階ごとの地図を持たせ、
## FieldBase.switch_floor() がタイル・光源・調べ物を組み替えてプレイヤーを移す。
##   FLOORS: Dictionary = { "1f": {"rows": ROWS_1F, "ground": GROUND_1F, "objects": OBJECTS_1F,
##                                 "default_ground": "…", "interactables": POI_1F, "overhead": [] }, … }
## 屋外（fields.json の地図）は floor id "outside"。出口トリガーは屋外にいるときだけ有効。
## 屋内は時間帯と独立に暗い（Lighting.set_darkness_override）。

const OUTSIDE: String = "outside"
const KEY_FLOORS: String = "FLOORS"
## 屋内の暗さ（0 明るい〜1 暗い）。時間帯に関係なく適用する
const INDOOR_DARKNESS: float = 0.8


## 定義済みの階か
static func has_floor(field: FieldBase, floor_id: String) -> bool:
	if floor_id == OUTSIDE:
		return true
	var floors: Dictionary = _floors_of(field)
	return floors.has(floor_id)


## 階を切り替える。タイル・光源・調べ物を組み替え、プレイヤー（と澪）を spawn_tile へ
static func switch(field: FieldBase, floor_id: String, spawn_tile: Vector2i, facing: Vector2i) -> bool:
	if not has_floor(field, floor_id):
		push_error("FieldFloors(%s): 階 '%s' は定義されていません" % [field.field_id, floor_id])
		return false
	_clear(field)
	if floor_id == OUTSIDE:
		FieldMapBuilder.build(field, field.field_def)
		field.set_floor_size(Vector2i.ZERO)
		Lighting.set_darkness_override(-1.0)
	else:
		var spec: Dictionary = _floors_of(field)[floor_id]
		var rows: PackedStringArray = spec.get("rows", PackedStringArray())
		FieldMapBuilder.build_from(field, rows, spec.get("ground", {}), spec.get("objects", {}),
			str(spec.get("default_ground", "")), spec.get("overhead", []), spec.get("interactables", []))
		field.set_floor_size(Vector2i(rows[0].length() if not rows.is_empty() else 0, rows.size()))
		Lighting.set_darkness_override(float(spec.get("darkness", INDOOR_DARKNESS)))
	field.current_floor = floor_id
	_set_exit_triggers_enabled(field, floor_id == OUTSIDE)
	var player: Node = SceneRouter.player
	if player != null and player.has_method("place_at_tile"):
		player.call("place_at_tile", spawn_tile, facing)
		if SceneRouter.heroine != null and SceneRouter.heroine.is_inside_tree() and SceneRouter.heroine.has_method("snap_behind"):
			SceneRouter.heroine.call("snap_behind", player, facing)
	SceneRouter.refresh_camera_limits()
	field.remove_stalker()
	Lighting.refresh()
	field.floor_changed.emit(floor_id)
	return true


static func _floors_of(field: FieldBase) -> Dictionary:
	var script: Script = field.get_script() as Script
	while script != null:
		var consts: Dictionary = script.get_script_constant_map()
		if consts.has(KEY_FLOORS):
			return consts[KEY_FLOORS]
		script = script.get_base_script()
	return {}


## タイル・光源・調べ物（出口トリガー以外）を消す
static func _clear(field: FieldBase) -> void:
	field.ground.clear()
	field.objects.clear()
	field.overhead.clear()
	for light: Node in field.lights.get_children():
		light.queue_free()
	for node: Node in field.triggers.get_children():
		if node is Interactable:
			field.triggers.remove_child(node)
			node.queue_free()


static func _set_exit_triggers_enabled(field: FieldBase, enabled: bool) -> void:
	for node: Node in field.triggers.get_children():
		var area: Area2D = node as Area2D
		if area != null and not node is Interactable:
			area.monitoring = enabled
