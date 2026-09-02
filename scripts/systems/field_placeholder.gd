extends FieldBase
## 未実装フィールド用のプレースホルダ。
## fields.json の寸法どおりに平らな地面と外周の壁を敷き、出口タイルだけ開ける。
## 中央に「未実装」とフィールド名を表示する。FieldRegistry が読めなかった場合もこのシーンで理由を表示する。

const GROUND_TYPE: String = "アスファルト"
const WALL_TYPE: String = "ブロック塀"
const MARK_TYPE: String = "白線（停止線）"
const LABEL_FONT_SIZE: int = 12

## FieldRegistry が失敗したときに表示する理由
var failure_reason: String = ""


func _build(def: FieldData) -> void:
	var size: Vector2i = get_size_tiles()
	fill_rect(ground, Rect2i(Vector2i.ZERO, size), GROUND_TYPE)
	# 外周の壁（出口タイルは開ける）
	var exit_tiles: Array[Vector2i] = []
	if def != null:
		for e: ExitData in def.exits:
			exit_tiles.append(e.tile)
			set_tile(ground, e.inward_tile(), MARK_TYPE)
	for x: int in size.x:
		for y: int in size.y:
			var on_edge: bool = x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1
			if on_edge and not exit_tiles.has(Vector2i(x, y)):
				set_tile(objects, Vector2i(x, y), WALL_TYPE)
	_build_label(def)
	if def != null and def.id == Calendar.get_home_field_id():
		_build_placeholder_bed()


## 自宅フィールドのプレースホルダに仮の寝床を置き、就寝で翌日へ進めるようにする
func _build_placeholder_bed() -> void:
	var size: Vector2i = get_size_tiles()
	@warning_ignore("integer_division")
	var tile: Vector2i = Vector2i(size.x / 2 + 3, size.y / 2)
	set_tile(objects, tile, "ベンチ")
	var bed: Interactable = Interactable.create("placeholder_bed", MessageResolver.text("ui_placeholder_bed"), "", tile, Vector2i.ONE, "bed")
	bed.interacted.connect(_on_bed_interacted)
	add_interactable(bed)


func _on_bed_interacted(_by: Node, target: Interactable) -> void:
	if Calendar.can_sleep(field_id):
		target.message = MessageResolver.text("msg_bed_sleep")
		Calendar.try_sleep(field_id)
	else:
		target.message = MessageResolver.text("msg_bed_not_yet")


func _build_label(def: FieldData) -> void:
	var ui: CanvasLayer = CanvasLayer.new()
	ui.name = "PlaceholderUI"
	add_child(ui)
	var panel: ColorRect = ColorRect.new()
	panel.color = Palette.with_alpha(Palette.UI_PANEL, 0.85)
	panel.position = Vector2(8, 8)
	panel.size = Vector2(GameConstants.VIEWPORT_WIDTH - 16, 44)
	ui.add_child(panel)
	var label: Label = Label.new()
	label.position = Vector2(12, 10)
	label.size = Vector2(GameConstants.VIEWPORT_WIDTH - 24, 40)
	label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	label.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT))
	if not failure_reason.is_empty():
		label.text = MessageResolver.text("ui_placeholder_load_failed", [failure_reason])
	elif def != null:
		label.text = MessageResolver.text("ui_placeholder_unimplemented", [def.id, def.name, def.ambience])
	else:
		label.text = MessageResolver.text("ui_placeholder_unknown")
	ui.add_child(label)
