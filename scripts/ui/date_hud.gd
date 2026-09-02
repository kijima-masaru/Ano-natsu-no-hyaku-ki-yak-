extends Control
## 画面右上の日付 HUD。「8月1日（土）　朝」を 384×216 で邪魔にならない大きさで表示する。
## 文言は Calendar の短い表記を使う（正式な文言は messages.json へ移す予定）。

const FONT_SIZE: int = 12
const MARGIN: Vector2i = Vector2i(4, 4)
const PADDING: Vector2i = Vector2i(4, 1)

@onready var _panel: ColorRect = $Panel
@onready var _label: Label = $Panel/Label


func _ready() -> void:
	_panel.color = Palette.with_alpha(Palette.UI_PANEL, 0.8)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT))
	Calendar.day_advanced.connect(_on_day_advanced)
	Calendar.time_of_day_changed.connect(_on_time_changed)
	refresh()


func refresh() -> void:
	_label.text = "%s　%s" % [Calendar.format_date(), Calendar.time_label()]
	# 右上に整数座標で配置する
	var text_size: Vector2 = _label.get_theme_font("font").get_string_size(
		_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var w: int = ceili(text_size.x) + PADDING.x * 2
	var h: int = ceili(text_size.y) + PADDING.y * 2
	_panel.size = Vector2(w, h)
	_panel.position = Vector2(GameConstants.VIEWPORT_WIDTH - MARGIN.x - w, MARGIN.y)
	_label.position = Vector2(PADDING)
	_label.size = Vector2(w - PADDING.x * 2, h - PADDING.y * 2)


func _on_day_advanced(_day: int, _previous: int) -> void:
	refresh()


func _on_time_changed(_tod: String, _previous: String) -> void:
	refresh()
