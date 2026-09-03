extends Control
## セーブスロットの一覧。mode = "save" なら選択で保存、"load" なら選択で読み込み。
## 破損スロットは「読めません」と表示し選択不可にする（クラッシュさせない）。

signal finished(success: bool, slot: int)

const FONT_SIZE: int = 12

var mode: String = "load"

@onready var _panel: ColorRect = $Panel
@onready var _title: Label = $Panel/Title
@onready var _list: MenuList = $Panel/List
@onready var _hint: Label = $Panel/Hint


func _ready() -> void:
	_panel.color = Palette.with_alpha(Palette.UI_PANEL, 0.95)
	for label: Label in [_title, _hint]:
		label.add_theme_font_size_override("font_size", FONT_SIZE)
	_title.add_theme_color_override("font_color", Palette.get_color(Palette.UI_ACCENT))
	_hint.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT_DIM))
	_list.activated.connect(_on_activated)
	_list.cancelled.connect(func() -> void: finished.emit(false, -1))
	open(mode)


func open(new_mode: String) -> void:
	mode = new_mode
	_title.text = MessageResolver.text("ui_slot_save_title" if mode == "save" else "ui_slot_load_title")
	_hint.text = InputDevice.hint("ui_hint_confirm_back")
	InputDevice.device_changed.connect(func(_pad: bool) -> void: _hint.text = InputDevice.hint("ui_hint_confirm_back"))
	var items: Array[Dictionary] = []
	for slot: int in SavePaths.SLOT_COUNT:
		if mode == "save" and slot == SavePaths.AUTOSAVE_SLOT:
			continue
		items.append({"id": str(slot), "text": _describe(slot), "disabled": mode == "load" and not SaveManager.has_save(slot)})
	_list.set_items(items)


func _describe(slot: int) -> String:
	var label: String = MessageResolver.text("ui_slot_autosave") if slot == SavePaths.AUTOSAVE_SLOT \
		else MessageResolver.text("ui_slot_n", [str(slot)])
	if not SaveManager.has_save(slot):
		return MessageResolver.text("ui_slot_empty", [label])
	var info: Dictionary = SaveManager.peek(slot)
	if info.is_empty():
		return MessageResolver.text("ui_slot_corrupt", [label])
	return MessageResolver.text("ui_slot_entry", [label, Calendar.format_date(int(info["day"])),
		Calendar.time_label(str(info["time_of_day"])), str(info["field_id"])])


func _on_activated(_index: int, id: String) -> void:
	var slot: int = int(id)
	var err: Error = SaveManager.save_game(slot) if mode == "save" else SaveManager.load_game(slot)
	if err != OK:
		_hint.text = MessageResolver.text("ui_slot_save_failed" if mode == "save" else "ui_slot_load_failed")
		_hint.add_theme_color_override("font_color", Palette.get_color(Palette.UI_ALERT))
		_list.set_item_text(id, _describe(slot))
		return
	finished.emit(true, slot)
