extends Control
## ミニマップ。全体図（16 フィールドの俯瞰、ステップ1の HTML の情報設計を移植）と、現在フィールドの簡易図の 2 種。
## - 未訪問フィールドは描かない（探索が進むほど地図が埋まる）
## - その日入れないフィールドは、存在は示すが斜線で「入れない」と分かる表現にする
## - 全体図は flag_minimap_unlocked（F06 の地図看板）で解放。簡易図は常に見られる
## - 384×216 で判読できることを優先し、パレット 16 色のみを使う。文字は 12px、地名は現在地だけ

signal closed()

const FONT_SIZE: int = 12
const CELL: Vector2i = Vector2i(66, 43)
const GRID_ORIGIN: Vector2i = Vector2i(120, 43)
const GRID_COLS: int = 6
const GRID_ROWS: int = 6
## 凡例は下段右側（左側は現在地の名前）
const LEGEND_X: float = 367.0
const LEGEND_SPACING: float = 127.0
const LOCAL_SCALE: int = 3
const LOCAL_ORIGIN: Vector2i = Vector2i(107, 50)
## 局所地図の描画領域（LOCAL_ORIGIN からの幅・高さ）
const LOCAL_AREA: Vector2i = Vector2i(427, 233)
## 標高 0〜5 → 塗り（西＝低く明るい、東＝高く暗い）
const ELEVATION_FILL: PackedInt32Array = [Palette.CONCRETE, Palette.FOG_INDIGO, Palette.DUSK_INDIGO, Palette.DEEP_INDIGO, Palette.NIGHT_SKY, Palette.SUMI]

enum View { WORLD, LOCAL }
var view: int = View.LOCAL

@onready var _bg: ColorRect = $Background
@onready var _title: Label = $Title
@onready var _hint: Label = $Hint
@onready var _caption: Label = $Caption


func _ready() -> void:
	_bg.color = Palette.get_color(Palette.UI_PANEL)
	# 地図は自分の _draw で描くので、子の背景は自分より後ろに描かせる（前に出ると地図が隠れる）
	_bg.show_behind_parent = true
	for label: Label in [_title, _hint, _caption]:
		label.add_theme_font_size_override("font_size", FONT_SIZE)
	_title.add_theme_color_override("font_color", Palette.get_color(Palette.UI_ACCENT))
	_hint.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT_DIM))
	_caption.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT))
	view = View.WORLD if GameState.has_flag("flag_minimap_unlocked") else View.LOCAL
	_refresh_labels()


func _refresh_labels() -> void:
	_title.text = MessageResolver.text("ui_map_world" if view == View.WORLD else "ui_map_local")
	_hint.text = InputDevice.hint("ui_map_hint")
	InputDevice.device_changed.connect(func(_pad: bool) -> void: _hint.text = InputDevice.hint("ui_map_hint"))
	var f: FieldData = FieldRegistry.get_field(SceneRouter.current_field_id) if FieldRegistry.has_field(SceneRouter.current_field_id) else null
	_caption.text = "%s %s" % [f.id, f.name] if f != null else ""
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_map"):
		get_viewport().set_input_as_handled()
		closed.emit()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") \
			or event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		get_viewport().set_input_as_handled()
		if GameState.has_flag("flag_minimap_unlocked"):
			view = View.LOCAL if view == View.WORLD else View.WORLD
			_refresh_labels()


func _draw() -> void:
	if view == View.WORLD:
		_draw_world()
	else:
		_draw_local()


## 全体図：world_pos（6×6 グリッド）に従って訪問済みフィールドを描く
func _draw_world() -> void:
	var grid_rect: Rect2 = Rect2(Vector2(GRID_ORIGIN), Vector2(CELL * Vector2i(GRID_COLS, GRID_ROWS)))
	draw_rect(grid_rect, Palette.get_color(Palette.NIGHT_SKY))
	for f: FieldData in FieldRegistry.get_all_fields():
		if not GameState.has_visited(f.id):
			continue
		var r: Rect2 = Rect2(Vector2(GRID_ORIGIN + f.world_pos.position * CELL) + Vector2.ONE,
			Vector2(f.world_pos.size * CELL) - Vector2(2, 2))
		draw_rect(r, Palette.get_color(ELEVATION_FILL[clampi(f.elevation, 0, 5)]))
		var available: bool = Calendar.is_field_available(f.id)
		var unlocked: bool = FieldRegistry.is_unlocked(f.id)
		if not available or not unlocked:
			_hatch(r, Palette.get_color(Palette.RUST_DARK if not unlocked else Palette.CONCRETE))
		var current: bool = f.id == SceneRouter.current_field_id
		draw_rect(r, Palette.get_color(Palette.UI_ACCENT if current else Palette.CONCRETE), false, 1.0)
		draw_string(ThemeDB.fallback_font, r.position + Vector2(3, 11), f.id, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 2,
			Palette.get_color(Palette.UI_ACCENT if current else Palette.UI_TEXT))
		if current:
			draw_rect(Rect2(r.get_center() - Vector2(2, 2), Vector2(4, 4)), Palette.get_color(Palette.STREETLAMP_GLOW))
	_draw_legend()


func _hatch(r: Rect2, color: Color) -> void:
	# 斜線 x + y = k を矩形内で切り出す
	var step: int = 6
	var w: float = r.size.x
	var h: float = r.size.y
	var k: float = 0.0
	while k < w + h:
		var a: Vector2 = r.position + Vector2(maxf(0.0, k - h), minf(k, h))
		var b: Vector2 = r.position + Vector2(minf(k, w), maxf(0.0, k - w))
		draw_line(a, b, color, 1.0)
		k += step


func _draw_legend() -> void:
	var y: float = GRID_ORIGIN.y + CELL.y * GRID_ROWS + 6
	var x: float = LEGEND_X
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(x, y, 8, 8), Palette.get_color(Palette.FOG_INDIGO))
	draw_string(font, Vector2(x + 11, y + 8), MessageResolver.text("ui_map_legend_visited"), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 2, Palette.get_color(Palette.UI_TEXT))
	x += LEGEND_SPACING
	var r: Rect2 = Rect2(x, y, 8, 8)
	draw_rect(r, Palette.get_color(Palette.FOG_INDIGO))
	_hatch(r, Palette.get_color(Palette.CONCRETE))
	draw_string(font, Vector2(x + 11, y + 8), MessageResolver.text("ui_map_legend_closed"), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 2, Palette.get_color(Palette.UI_TEXT))


## 簡易図：現在フィールドの通行可否・出口・調べ物・自分の位置を 1 タイル = 2px で描く
func _draw_local() -> void:
	var field: FieldBase = SceneRouter.current_field
	if field == null:
		return
	var size: Vector2i = field.get_size_tiles()
	var origin: Vector2 = Vector2(LOCAL_ORIGIN) + Vector2((LOCAL_AREA.x - size.x * LOCAL_SCALE) / 2.0, (LOCAL_AREA.y - size.y * LOCAL_SCALE) / 2.0).floor()
	draw_rect(Rect2(origin - Vector2.ONE, Vector2(size * LOCAL_SCALE) + Vector2(2, 2)), Palette.get_color(Palette.CONCRETE), false, 1.0)
	for y: int in size.y:
		for x: int in size.x:
			var tile: Vector2i = Vector2i(x, y)
			var ground_type: String = field.get_tile_type_at(field.ground, tile)
			var object_type: String = field.get_tile_type_at(field.objects, tile)
			var color_index: int = Palette.NIGHT_SKY
			if not object_type.is_empty() and not TileGenerator.is_walkable(object_type):
				color_index = Palette.DUSK_INDIGO
			elif not ground_type.is_empty() and TileGenerator.is_walkable(ground_type):
				color_index = Palette.FOG_INDIGO
			draw_rect(Rect2(origin + Vector2(tile * LOCAL_SCALE), Vector2(LOCAL_SCALE, LOCAL_SCALE)), Palette.get_color(color_index))
	if field.field_def != null:
		for e: ExitData in field.field_def.exits:
			var open: bool = FieldRegistry.is_exit_open(e) and Calendar.is_field_available(e.to_id)
			draw_rect(Rect2(origin + Vector2(e.tile * LOCAL_SCALE), Vector2(LOCAL_SCALE, LOCAL_SCALE)),
				Palette.get_color(Palette.BONE_WHITE if open else Palette.VENDING_RED))
	for node: Node in field.triggers.get_children():
		if node is Interactable:
			var t: Vector2i = GameConstants.world_to_tile((node as Node2D).global_position)
			draw_rect(Rect2(origin + Vector2(t * LOCAL_SCALE), Vector2(LOCAL_SCALE, LOCAL_SCALE)), Palette.get_color(Palette.FLUORESCENT))
	if SceneRouter.player != null:
		var p: Vector2i = SceneRouter.player.get_tile()
		draw_rect(Rect2(origin + Vector2(p * LOCAL_SCALE) - Vector2.ONE, Vector2(LOCAL_SCALE + 2, LOCAL_SCALE + 2)), Palette.get_color(Palette.STREETLAMP_GLOW))
