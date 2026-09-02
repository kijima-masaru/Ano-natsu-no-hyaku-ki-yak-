class_name FieldExitTriggers
extends RefCounted
## fields.json の exits ごとに境界タイルへ Area2D を置く（FieldBase から呼ぶ）。
## 当たりはタイルより少し小さくして隣接タイルから誤発火しないようにする。

const EXIT_TRIGGER_SIZE: Vector2 = Vector2(14, 14)


static func build(field: FieldBase, def: FieldData, on_body_entered: Callable) -> void:
	if def == null:
		return
	for exit: ExitData in def.exits:
		if not def.contains_tile(exit.tile):
			push_error("FieldBase(%s): 出口 %s のタイルがフィールド外です" % [field.field_id, exit.describe()])
			continue
		var area: Area2D = Area2D.new()
		area.name = "ExitTrigger_%s" % exit.to_id
		area.collision_layer = 0
		area.collision_mask = 1
		area.monitorable = false
		area.position = GameConstants.tile_to_world(exit.tile)
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = EXIT_TRIGGER_SIZE
		shape.shape = rect
		area.add_child(shape)
		area.body_entered.connect(on_body_entered.bind(exit))
		field.triggers.add_child(area)
