class_name FieldNpcs
extends RefCounted
## フィールド上の調べ物・NPC の出し入れ。FieldBase の add_interactable / add_point_of_interest / get_interactable /
## set_npc_present から呼ぶ（各フィールドの GDScript は FieldBase のメソッドを使い、ここを直接呼ばない）。


static func add_interactable(field: FieldBase, node: Interactable) -> void:
	field.triggers.add_child(node)
	node.interacted.connect(func(_by: Node, target: Interactable) -> void: field.interaction_started.emit(target))


## 日付やフラグで後から現れる調べ物を置く（見た目は set_tile で別に置く）。既にあればそれを返す
static func add_point_of_interest(field: FieldBase, id: String, label: String, tile: Vector2i, kind: String) -> Interactable:
	var existing: Interactable = get_interactable(field, id)
	if existing != null:
		return existing
	var node: Interactable = Interactable.create(id, label, "", tile, Vector2i.ONE, kind)
	add_interactable(field, node)
	return node


## interaction_id で調べ物を探す。無ければ null
static func get_interactable(field: FieldBase, id: String) -> Interactable:
	for node: Node in field.triggers.get_children():
		var it: Interactable = node as Interactable
		if it != null and it.interaction_id == id:
			return it
	return null


## 時間帯・日付で出し入れする NPC（見た目付きの調べ物）。present に合わせて生成／削除し、現在のノードを返す
static func set_npc_present(field: FieldBase, id: String, present: bool, tile: Vector2i, sprite_kind: String, facing: Vector2i) -> Interactable:
	var existing: Interactable = get_interactable(field, id)
	if present and existing == null:
		var npc: Interactable = Interactable.create(id, "", "", tile, Vector2i.ONE, "npc")
		npc.set_actor_sprite(sprite_kind, facing)
		add_interactable(field, npc)
		return npc
	if not present and existing != null:
		field.triggers.remove_child(existing)
		existing.queue_free()
		return null
	return existing
