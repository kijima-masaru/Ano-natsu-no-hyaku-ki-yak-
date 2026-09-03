extends Control
## コンテンツ警告と相談窓口案内。初回起動時にタイトルの前に表示し、設定から再表示できる。エンディング後にも出す。
## 文言は messages.json（ui_notice_*）。相談窓口は data/locale/<lang>/support.json（MessageResolver.support_entries）。
## 一覧が空のあいだは「配信地域が決まってから掲載する」旨の一行を出す（docs/CONTENT_NOTICE.md §5）。
## 題・本文・窓口・脚注は VBoxContainer に縦積みし、フォントの行高が変わっても重ならないようにする（余白があれば脚注は下端）。
## 脅かさず淡々と。表示直後の誤操作で閉じないよう、MIN_VISIBLE_SECONDS の間は入力を受けない。

signal acknowledged()

const FONT_SIZE: int = 12
const MIN_VISIBLE_SECONDS: float = 0.8
const MAX_SUPPORT_ENTRIES: int = 3
## "startup"：初回起動（既読を記録）／"after_ending"：エンディング後の相談窓口案内（記録しない）／"replay"：設定・裏面（記録しない）
var mode: String = "startup"

@onready var _bg: ColorRect = $Background
@onready var _title: Label = $Column/Title
@onready var _body: Label = $Column/Body
@onready var _support: Label = $Column/Support
@onready var _note: Label = $Column/Note
@onready var _hint: Label = $Column/Hint

var _elapsed: float = 0.0


func _ready() -> void:
	_bg.color = Palette.get_color(Palette.SUMI)
	for label: Label in [_title, _body, _support, _note, _hint]:
		label.add_theme_font_size_override("font_size", FONT_SIZE)
	_title.add_theme_color_override("font_color", Palette.get_color(Palette.UI_ACCENT))
	_body.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT))
	_support.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT))
	_support.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_note.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT_DIM))
	_hint.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT_DIM))
	var suffix: String = "_after_ending" if mode == "after_ending" else ""
	_title.text = MessageResolver.text("ui_notice_title" + suffix)
	_body.text = MessageResolver.text("ui_notice_body" + suffix)
	_support.text = _support_text()
	# 「設定から見直せる」はエンディング後には出さない（そこから設定へは戻れない）
	_note.text = MessageResolver.text("ui_notice_note_settings")
	_note.visible = mode != "after_ending"
	_hint.text = InputDevice.hint("ui_hint_close")
	InputDevice.device_changed.connect(func(_pad: bool) -> void: _hint.text = InputDevice.hint("ui_hint_close"))


## 「話せる場所があります」＋窓口の一覧（最大 MAX_SUPPORT_ENTRIES 件）。一覧が空なら未掲載の一行
func _support_text() -> String:
	var lines: PackedStringArray = PackedStringArray([MessageResolver.text("ui_notice_support_lead")])
	var entries: Array[Dictionary] = MessageResolver.support_entries()
	if entries.is_empty():
		lines.append(MessageResolver.text("ui_notice_support_pending"))
	for i: int in mini(entries.size(), MAX_SUPPORT_ENTRIES):
		var e: Dictionary = entries[i]
		lines.append(MessageResolver.text("ui_notice_support_entry", [str(e.get("name", "")), str(e.get("contact", "")), str(e.get("hours", ""))]).strip_edges(false, true))
	return "\n".join(lines)


func _process(delta: float) -> void:
	_elapsed += delta


func _unhandled_input(event: InputEvent) -> void:
	if _elapsed < MIN_VISIBLE_SECONDS:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") \
			or event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if mode == "startup":
			SaveManager.mark_content_notice_seen()
		acknowledged.emit()
		queue_free()
