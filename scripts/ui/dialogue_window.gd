extends Control
## 会話ウィンドウ（本実装）。ステップ2の簡易メッセージウィンドウを置き換える。
## - 1 文字ずつ表示、送り、全文即時表示（interact で全文→次頁→閉じる、cancel で全文）
## - 禁則処理付きの自動ページング（TextLayout）
## - 話者名の表示枠。話者なしのモノローグは名前枠を隠す
## - 話者ごとの文字色・文字送り速度（MessageEntry の color_index / speed）
## - 選択肢（show_choice）と結果通知。キーボード／ゲームパッド両対応
## - 文字送り速度と一括表示は SaveManager の設定から読む
## 互換 API：show_message(title, text) / signal closed（旧 MessageWindow と同じ）

signal opened
signal closed
signal choice_made(index: int)

const FONT_PATH: String = "res://resources/fonts/PixelMplus12-Regular.ttf"
const FONT_SIZE: int = 12
const LINE_CHARS: int = 28
const LINES_PER_PAGE: int = 2
const BASE_CHARS_PER_SECOND: float = 30.0
## 設定 text_speed（0〜1）を倍率に変換する範囲
const SPEED_MIN: float = 0.5
const SPEED_MAX: float = 2.5

var is_open: bool = false
var is_choosing: bool = false

var _pages: PackedStringArray = PackedStringArray()
var _page_index: int = 0
var _visible_chars: float = 0.0
## 文字送りの音：TICK_EVERY 文字ごとに 1 回。話者がナツなら低く柔らかい方
const TICK_EVERY: int = 3
var _speaker_id: String = ""
var _tick_at: int = 0
var _cps: float = BASE_CHARS_PER_SECOND
var _font: Font = null
var _using_fallback_font: bool = false
var _pending_choices: PackedStringArray = PackedStringArray()

@onready var _panel: Panel = $Panel
@onready var _name_box: Panel = $NameBox
@onready var _name_label: Label = $NameBox/Name
@onready var _body: Label = $Panel/Body
@onready var _hint: Label = $Panel/Hint
@onready var _font_note: Label = $Panel/FontNote
@onready var _choice_panel: Panel = $ChoicePanel
@onready var _choices: MenuList = $ChoicePanel/List


func _ready() -> void:
	_setup_font()
	_apply_theme()
	_choices.activated.connect(_on_choice_activated)
	hide()
	_choice_panel.hide()
	set_process(false)


## 旧 API。話者名と本文を直接渡す（既定の色・速度）
func show_message(title: String, text: String) -> void:
	_speaker_id = ""
	_open(title, text, Palette.UI_TEXT, 1.0)


## 解決済みメッセージを話者の色・速度で表示する
func show_entry(entry: MessageEntry) -> void:
	_speaker_id = entry.speaker
	_open(entry.speaker_name, entry.text, entry.color_index, entry.speed)


## 選択肢を出す。閉じると choice_made(index) を発火（本文が開いていれば先に読み終えてから）。
## 本文が閉じているときは空の本文でウィンドウを開いてから出す（閉じたままだと選択肢パネルが見えず、入力待ちで止まる）
func show_choice(options: PackedStringArray) -> void:
	_pending_choices = options.duplicate()
	if not is_open:
		_open_empty()
		_present_choices()


## 本文なしでウィンドウを開く（選択肢だけを出すとき）
func _open_empty() -> void:
	_pages = PackedStringArray([""])
	_page_index = 0
	_name_box.visible = false
	_body.text = ""
	_body.visible_characters = -1
	_hint.visible = false
	is_open = true
	show()
	set_process(false)
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	set_process(false)
	closed.emit()


func _open(speaker_name: String, text: String, color_index: int, speed: float) -> void:
	_pages = TextLayout.paginate(text, LINE_CHARS, LINES_PER_PAGE)
	_page_index = 0
	_name_label.text = speaker_name
	_name_box.visible = not speaker_name.is_empty()
	_body.add_theme_color_override("font_color", Palette.get_color(color_index))
	var setting: float = clampf(float(SaveManager.get_setting("text_speed")), 0.0, 1.0)
	_cps = BASE_CHARS_PER_SECOND * speed * lerpf(SPEED_MIN, SPEED_MAX, setting)
	_show_page()
	is_open = true
	show()
	set_process(true)
	opened.emit()


func _show_page() -> void:
	_body.text = _pages[_page_index]
	_visible_chars = 0.0
	_tick_at = 0
	if bool(SaveManager.get_setting("instant_text")):
		_reveal_all()
	else:
		_body.visible_characters = 0
		_hint.visible = false
	_hint.text = "▼" if _page_index < _pages.size() - 1 else "■"


func _reveal_all() -> void:
	_body.visible_characters = -1
	_hint.visible = true


func _process(delta: float) -> void:
	if _body.visible_characters < 0:
		return
	_visible_chars += _cps * delta
	_body.visible_characters = mini(int(_visible_chars), _body.text.length())
	if _body.visible_characters - _tick_at >= TICK_EVERY:
		_tick_at = _body.visible_characters
		AudioManager.play_se("se_natsu_text_tick" if _speaker_id == AttachedEntity.SPEAKER else "se_text_tick")
	if _body.visible_characters >= _body.text.length():
		_reveal_all()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or is_choosing:
		return
	var advance: bool = event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
	var skip: bool = event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel")
	if not (advance or skip):
		return
	get_viewport().set_input_as_handled()
	if _body.visible_characters >= 0:
		_reveal_all()
		return
	if skip:
		# 残りページを全文表示で送る
		_page_index = _pages.size() - 1
		_body.text = _pages[_page_index]
		_reveal_all()
		return
	if _page_index < _pages.size() - 1:
		_page_index += 1
		_show_page()
	elif not _pending_choices.is_empty():
		_present_choices()
	else:
		close()


func _present_choices() -> void:
	is_choosing = true
	var items: Array[Dictionary] = []
	for i: int in _pending_choices.size():
		items.append({"id": str(i), "text": _pending_choices[i]})
	_choices.set_items(items)
	_choice_panel.visible = true
	_hint.visible = false


func _on_choice_activated(index: int, _id: String) -> void:
	_pending_choices.clear()
	_choice_panel.visible = false
	is_choosing = false
	choice_made.emit(index)
	close()


func _setup_font() -> void:
	if UiFont.font != null:
		_font = UiFont.font
		return
	if ResourceLoader.exists(FONT_PATH):
		push_error("DialogueWindow: %s を FontFile として読み込めません" % FONT_PATH)
	else:
		push_warning("DialogueWindow: PixelMplus12 が %s に無いため代替フォントで表示します（resources/fonts/README.md）" % FONT_PATH)
	_font = ThemeDB.fallback_font
	_using_fallback_font = true


func _apply_theme() -> void:
	for panel: Panel in [_panel, _name_box, _choice_panel]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Palette.get_color(Palette.UI_PANEL)
		style.border_color = Palette.get_color(Palette.UI_BORDER)
		style.set_border_width_all(1)
		panel.add_theme_stylebox_override("panel", style)
	for label: Label in [_name_label, _body, _hint, _font_note]:
		label.add_theme_font_override("font", _font)
		label.add_theme_font_size_override("font_size", FONT_SIZE)
	_name_label.add_theme_color_override("font_color", Palette.get_color(Palette.UI_ACCENT))
	_hint.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT_DIM))
	_font_note.add_theme_color_override("font_color", Palette.get_color(Palette.UI_ALERT))
	_font_note.visible = _using_fallback_font
	_font_note.text = "[代替フォント]" if _using_fallback_font else ""
