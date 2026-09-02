extends Node2D
## 全タイル種別を一覧表示する確認用シーン。
## 矢印キー（ui_*）でカーソル移動、下部に種別名・通行可否・調べ可否・ペインタ名を表示。
## Enter（ui_accept）で生成 TileSet を resources/tilesets/common.tres に保存する。
## 起動時に data/fields.json の required_tiles と対応表を照合し、未対応があれば警告する。

const COLUMNS: int = 20
const FIELDS_JSON: String = "res://data/fields.json"
const INFO_FONT_SIZE: int = 12

var _names: PackedStringArray
var _layer: TileMapLayer
var _info: Label
var _cursor: Vector2i = Vector2i.ZERO


func _ready() -> void:
	_names = TileCatalog.all_names()
	var tile_set: TileSet = TileSetProvider.get_tileset()
	_layer = TileMapLayer.new()
	_layer.tile_set = tile_set
	_layer.position = Vector2(GameConstants.TILE_SIZE, GameConstants.TILE_SIZE)
	add_child(_layer)
	for i: int in _names.size():
		_layer.set_cell(_index_to_cell(i), TileGenerator.SOURCE_ID, TileSetProvider.get_atlas_coords(_names[i]))
	_build_info_label()
	_check_coverage()
	_update_info()


func _index_to_cell(index: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(index % COLUMNS, index / COLUMNS)


func _build_info_label() -> void:
	var ui: CanvasLayer = CanvasLayer.new()
	add_child(ui)
	var panel: ColorRect = ColorRect.new()
	panel.color = Palette.get_color(Palette.UI_PANEL)
	panel.position = Vector2(0, GameConstants.VIEWPORT_HEIGHT - 40)
	panel.size = Vector2(GameConstants.VIEWPORT_WIDTH, 40)
	ui.add_child(panel)
	_info = Label.new()
	_info.position = Vector2(8, GameConstants.VIEWPORT_HEIGHT - 38)
	_info.size = Vector2(GameConstants.VIEWPORT_WIDTH - 16, 36)
	_info.add_theme_font_size_override("font_size", INFO_FONT_SIZE)
	_info.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT))
	ui.add_child(_info)


func _unhandled_input(event: InputEvent) -> void:
	var delta: Vector2i = Vector2i.ZERO
	if event.is_action_pressed("ui_left"):
		delta.x = -1
	elif event.is_action_pressed("ui_right"):
		delta.x = 1
	elif event.is_action_pressed("ui_up"):
		delta.y = -1
	elif event.is_action_pressed("ui_down"):
		delta.y = 1
	elif event.is_action_pressed("ui_accept"):
		TileSetProvider.save_generated()
		return
	if delta == Vector2i.ZERO:
		return
	var index: int = clampi(_cursor.y * COLUMNS + _cursor.x + delta.x + delta.y * COLUMNS, 0, _names.size() - 1)
	_cursor = _index_to_cell(index)
	_update_info()
	queue_redraw()


func _update_info() -> void:
	var name: String = _names[_cursor.y * COLUMNS + _cursor.x]
	var entry: Dictionary = TileGenerator.resolve_entry(name)
	_info.text = "%s\n通行:%s  調べる:%s  painter:%s  [%d/%d]  Enter=保存" % [
		name,
		"可" if TileGenerator.is_walkable(name) else "不可",
		"可" if TileGenerator.is_interactable(name) else "－",
		str(entry.get("painter", "?")),
		_cursor.y * COLUMNS + _cursor.x + 1, _names.size(),
	]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(GameConstants.VIEWPORT_SIZE)), Palette.get_color(Palette.NIGHT_SKY))
	var origin: Vector2 = Vector2(GameConstants.TILE_SIZE, GameConstants.TILE_SIZE)
	var pos: Vector2 = origin + Vector2(_cursor * GameConstants.TILE_SIZE)
	draw_rect(Rect2(pos - Vector2.ONE, Vector2(GameConstants.TILE_VECTOR) + Vector2(2, 2)),
		Palette.get_color(Palette.UI_ACCENT), false, 1.0)


## fields.json の required_tiles が全て対応表にあるか確認する（デバッグ専用の直接読み込み）
func _check_coverage() -> void:
	var file: FileAccess = FileAccess.open(FIELDS_JSON, FileAccess.READ)
	if file == null:
		push_warning("tile_preview: %s を開けません（%s）" % [FIELDS_JSON, error_string(FileAccess.get_open_error())])
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("tile_preview: fields.json の解析に失敗しました")
		return
	var root: Dictionary = parsed
	var fields: Array = root.get("fields", [])
	var missing: PackedStringArray = PackedStringArray()
	var total: int = 0
	for f: Variant in fields:
		var field: Dictionary = f
		for t: Variant in field.get("required_tiles", []):
			total += 1
			var type_name: String = str(t)
			if not TileGenerator.is_known(type_name) and not missing.has(type_name):
				missing.append(type_name)
	if missing.is_empty():
		print("tile_preview: required_tiles %d 件はすべて対応表にあります" % total)
	else:
		push_warning("tile_preview: 対応表に無い種別 %d 件（フォールバック描画）: %s" % [missing.size(), ", ".join(missing)])
