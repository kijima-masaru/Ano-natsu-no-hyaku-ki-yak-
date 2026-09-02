extends Control
## コンテンツ警告と相談窓口案内。初回起動時にタイトルの前に表示し、設定から再表示できる。
## 文言は messages.json（ui_notice_*）。相談窓口の具体的な連絡先はプレースホルダで、配信地域確定後にローカライズデータで差し込む（docs/CONTENT_NOTICE.md）。

signal acknowledged()

const FONT_SIZE: int = 12

@onready var _bg: ColorRect = $Background
@onready var _title: Label = $Title
@onready var _body: Label = $Body
@onready var _hint: Label = $Hint


func _ready() -> void:
	_bg.color = Palette.get_color(Palette.SUMI)
	for label: Label in [_title, _body, _hint]:
		label.add_theme_font_size_override("font_size", FONT_SIZE)
	_title.add_theme_color_override("font_color", Palette.get_color(Palette.UI_ACCENT))
	_body.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT))
	_hint.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT_DIM))
	_title.text = MessageResolver.text("ui_notice_title")
	_body.text = MessageResolver.text("ui_notice_body")
	_hint.text = MessageResolver.text("ui_hint_close")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") \
			or event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		SaveManager.mark_content_notice_seen()
		acknowledged.emit()
		queue_free()
