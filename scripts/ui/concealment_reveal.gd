extends Control
## 真相到達時の提示画面。プレイヤーが「調べた」だけだったものの一覧と、実際に悠がしたことを重ねて示す。
## 本作最大の一撃なので、この画面だけは文字送りをスキップできない（ページ送りは可）。
## 構成は docs/CONCEALMENT_LIST.md「提示画面」に従う。

signal finished()

const FONT_SIZE: int = 12
const CHARS_PER_SECOND: float = 18.0
const LINE_CHARS: int = 28
const PAUSE_BETWEEN: float = 0.6

var _pages: Array[PackedStringArray] = []
var _page_index: int = 0
var _line_index: int = 0
var _visible: float = 0.0
var _current_line_done: bool = true

@onready var _bg: ColorRect = $Background
@onready var _title: Label = $Title
@onready var _body: Label = $Body
@onready var _hint: Label = $Hint


func _ready() -> void:
	_bg.color = Palette.get_color(Palette.SUMI)
	for label: Label in [_title, _body, _hint]:
		label.add_theme_font_size_override("font_size", FONT_SIZE)
	_title.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT_DIM))
	_body.add_theme_color_override("font_color", Palette.get_color(Palette.BONE_WHITE))
	_hint.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT_DIM))
	_title.text = MessageResolver.text("ui_reveal_title")
	_hint.text = MessageResolver.text("ui_reveal_hint")
	_hint.visible = false
	_build_pages()
	_start_page()


## 各証拠を 1 ページに：表示文 → 空行 → 実際の行動（目撃されたものは澪の行）
func _build_pages() -> void:
	var ids: PackedStringArray = GameState.concealed_evidence.duplicate()
	ids.append_array(GameState.witnessed_concealments)
	if ids.is_empty():
		_pages.append(PackedStringArray([MessageResolver.text("ui_reveal_empty")]))
		return
	for id: String in ids:
		var e: EvidenceData = EvidenceRegistry.get_evidence(id)
		if e == null:
			continue
		var lines: PackedStringArray = PackedStringArray()
		lines.append_array(TextLayout.wrap_line(MessageResolver.text(e.shown_id), LINE_CHARS))
		lines.append("")
		if GameState.witnessed_concealments.has(id):
			lines.append_array(TextLayout.wrap_line(MessageResolver.text("msg_conceal_witnessed"), LINE_CHARS))
			lines.append_array(TextLayout.wrap_line(MessageResolver.text("ui_reveal_witnessed"), LINE_CHARS))
		else:
			lines.append_array(TextLayout.wrap_line(MessageResolver.text(e.action_id), LINE_CHARS))
		_pages.append(lines)


func _start_page() -> void:
	_line_index = 0
	_body.text = ""
	_hint.visible = false
	_start_line()


func _start_line() -> void:
	var lines: PackedStringArray = _pages[_page_index]
	if _line_index >= lines.size():
		_hint.visible = true
		return
	_visible = 0.0
	_current_line_done = false


func _process(delta: float) -> void:
	if _current_line_done:
		return
	var lines: PackedStringArray = _pages[_page_index]
	var line: String = lines[_line_index]
	_visible += CHARS_PER_SECOND * delta
	var shown: String = line.substr(0, mini(int(_visible), line.length()))
	var prefix: PackedStringArray = lines.slice(0, _line_index)
	_body.text = "\n".join(prefix) + ("\n" if not prefix.is_empty() else "") + shown
	if int(_visible) >= line.length():
		_current_line_done = true
		_line_index += 1
		await get_tree().create_timer(PAUSE_BETWEEN).timeout
		_start_line()


func _unhandled_input(event: InputEvent) -> void:
	if not _hint.visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_page_index += 1
		if _page_index >= _pages.size():
			finished.emit()
			queue_free()
		else:
			_start_page()
