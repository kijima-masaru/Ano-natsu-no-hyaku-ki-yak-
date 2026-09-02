extends Control
## コンテンツ警告と相談窓口案内。初回起動時にタイトルの前に表示し、設定から再表示できる。
## 文言は暫定（TODO(step-3 task-4): messages.json と data/locale/<lang>/support.json へ移す）。
## 相談窓口の具体的な連絡先はプレースホルダ。配信地域確定後にローカライズデータで差し込む（docs/CONTENT_NOTICE.md）。

signal acknowledged()

const FONT_SIZE: int = 12
const BODY: String = "本作には、自死とその喪失を扱う描写、追跡される恐怖、\n心理的な操作の描写が含まれます。\n具体的な方法は描写しません。\n\nつらいときは、話せる場所があります。\n［お住まいの地域の相談窓口をここに表示します］\n\nこのお知らせは「設定」からいつでも見直せます。"

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
	_title.text = "はじめに"
	_body.text = BODY
	_hint.text = "Z で閉じる"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") \
			or event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		SaveManager.mark_content_notice_seen()
		acknowledged.emit()
		queue_free()
