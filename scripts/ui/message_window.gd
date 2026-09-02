extends Control
## 画面下部の簡易メッセージウィンドウ。PixelMplus12 を想定した固定幅レイアウト。
## 1 ページ 2 行、1 行は全角 28 文字で手動改行する（等幅前提）。
## interact / cancel で「全文表示 → 次ページ → 閉じる」。開いている間はプレイヤー入力を止める（Main が制御）。
## フォントファイルが未配置なら警告し、代替フォントで動作しつつ画面右上に [代替フォント] と示す。

signal opened
signal closed

const FONT_PATH: String = "res://resources/fonts/PixelMplus12-Regular.ttf"
const FONT_SIZE: int = 12
const LINE_CHARS: int = 28
const LINES_PER_PAGE: int = 2
const CHARS_PER_SECOND: float = 40.0

var is_open: bool = false
var _pages: PackedStringArray = PackedStringArray()
var _page_index: int = 0
var _visible_chars: float = 0.0
var _font: Font = null
var _using_fallback_font: bool = false

@onready var _panel: Panel = $Panel
@onready var _title: Label = $Panel/Title
@onready var _body: Label = $Panel/Body
@onready var _hint: Label = $Panel/Hint
@onready var _font_note: Label = $Panel/FontNote


func _ready() -> void:
	_setup_font()
	_apply_theme()
	hide()
	set_process(false)


## メッセージを表示する。title は空でもよい
func show_message(title: String, text: String) -> void:
	_pages = _paginate(text)
	if _pages.is_empty():
		_pages.append("")
	_page_index = 0
	_title.text = title
	_title.visible = not title.is_empty()
	_show_page()
	is_open = true
	show()
	set_process(true)
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	set_process(false)
	closed.emit()


func _process(delta: float) -> void:
	if _body.visible_characters < 0:
		return
	_visible_chars += CHARS_PER_SECOND * delta
	_body.visible_characters = mini(int(_visible_chars), _body.text.length())
	if _body.visible_characters >= _body.text.length():
		_body.visible_characters = -1
		_hint.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if not (event.is_action_pressed("interact") or event.is_action_pressed("cancel")):
		return
	get_viewport().set_input_as_handled()
	if _body.visible_characters >= 0:
		_body.visible_characters = -1
		_hint.visible = true
	elif _page_index < _pages.size() - 1:
		_page_index += 1
		_show_page()
	else:
		close()


func _show_page() -> void:
	_body.text = _pages[_page_index]
	_body.visible_characters = 0
	_visible_chars = 0.0
	_hint.visible = false
	_hint.text = "▼" if _page_index < _pages.size() - 1 else "■"


## 改行で分け、長い行は LINE_CHARS 文字ごとに折り、LINES_PER_PAGE 行ずつページにする
func _paginate(text: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for raw: String in text.split("\n"):
		var line: String = raw
		while line.length() > LINE_CHARS:
			lines.append(line.substr(0, LINE_CHARS))
			line = line.substr(LINE_CHARS)
		lines.append(line)
	var pages: PackedStringArray = PackedStringArray()
	var i: int = 0
	while i < lines.size():
		var chunk: PackedStringArray = lines.slice(i, mini(i + LINES_PER_PAGE, lines.size()))
		pages.append("\n".join(chunk))
		i += LINES_PER_PAGE
	return pages


func _setup_font() -> void:
	if ResourceLoader.exists(FONT_PATH):
		var font_file: FontFile = load(FONT_PATH) as FontFile
		if font_file != null:
			font_file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			font_file.hinting = TextServer.HINTING_NONE
			font_file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			_font = font_file
			return
		push_error("MessageWindow: %s を FontFile として読み込めません" % FONT_PATH)
	else:
		push_warning("MessageWindow: PixelMplus12 が %s に無いため代替フォントで表示します（resources/fonts/README.md 参照）" % FONT_PATH)
	_font = ThemeDB.fallback_font
	_using_fallback_font = true


## 色・フォントは Palette と _font からだけ与える（.tscn に色を書かない）
func _apply_theme() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.get_color(Palette.UI_PANEL)
	style.border_color = Palette.get_color(Palette.UI_BORDER)
	style.set_border_width_all(1)
	_panel.add_theme_stylebox_override("panel", style)
	for label: Label in [_title, _body, _hint, _font_note]:
		label.add_theme_font_override("font", _font)
		label.add_theme_font_size_override("font_size", FONT_SIZE)
	_title.add_theme_color_override("font_color", Palette.get_color(Palette.UI_ACCENT))
	_body.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT))
	_hint.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT_DIM))
	_font_note.add_theme_color_override("font_color", Palette.get_color(Palette.UI_ALERT))
	_font_note.visible = _using_fallback_font
	_font_note.text = "[代替フォント]" if _using_fallback_font else ""
