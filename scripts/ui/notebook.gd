extends Control
## 証拠ノート。集めた証拠（GameState.evidence）を一覧し、選択で記述を表示する。
## 記述は MessageResolver.resolve(surface_id) を通すため、真相到達後は自動で真相版になる。
## 隠蔽に成功した証拠はここに載らない（それが本作の仕掛け）。

signal closed()

const FONT_SIZE: int = 12
const DETAIL_CHARS: int = 26

@onready var _panel: ColorRect = $Panel
@onready var _title: Label = $Panel/Title
@onready var _list: MenuList = $Panel/List
@onready var _detail: Label = $Panel/Detail
@onready var _hint: Label = $Panel/Hint


func _ready() -> void:
	_panel.color = Palette.with_alpha(Palette.UI_PANEL, 0.96)
	for label: Label in [_title, _detail, _hint]:
		label.add_theme_font_size_override("font_size", FONT_SIZE)
	_title.add_theme_color_override("font_color", Palette.get_color(Palette.UI_ACCENT))
	_detail.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT))
	_hint.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT_DIM))
	_title.text = MessageResolver.text("ui_notebook_title")
	_hint.text = MessageResolver.text("ui_notebook_hint")
	_list.selection_changed.connect(func(_i: int, id: String) -> void: _show_detail(id))
	_list.cancelled.connect(func() -> void: closed.emit())
	_list.activated.connect(func(_i: int, id: String) -> void: _show_detail(id))
	_rebuild()


func _rebuild() -> void:
	var items: Array[Dictionary] = []
	for id: String in GameState.evidence:
		var e: EvidenceData = EvidenceRegistry.get_evidence(id)
		if e != null:
			items.append({"id": id, "text": MessageResolver.text(e.title_id)})
	if items.is_empty():
		_detail.text = MessageResolver.text("ui_notebook_empty")
		_list.set_items([])
		return
	_list.set_items(items)
	_show_detail(_list.get_selected_id())


func _show_detail(id: String) -> void:
	var e: EvidenceData = EvidenceRegistry.get_evidence(id)
	if e == null:
		_detail.text = ""
		return
	var entry: MessageEntry = MessageResolver.resolve(e.surface_id)
	_detail.text = "\n".join(TextLayout.paginate(entry.text, DETAIL_CHARS, 6))


func _unhandled_input(event: InputEvent) -> void:
	# 一覧が空のときは MenuList が入力を受けないため、ここで閉じる
	if GameState.evidence.is_empty() and (event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel") \
			or event.is_action_pressed("open_notebook")):
		get_viewport().set_input_as_handled()
		closed.emit()
