class_name MenuList
extends VBoxContainer
## キーボード／ゲームパッド両対応の縦メニュー。項目は Label で、選択中は先頭に「▶」を付ける。
## ui_up / ui_down / move_up / move_down で移動、interact / ui_accept で決定、cancel / ui_cancel で戻る。

signal activated(index: int, id: String)
signal cancelled()
signal selection_changed(index: int, id: String)

const FONT_SIZE: int = 12
const CURSOR: String = "▶ "
const BLANK: String = "　 "

var _ids: PackedStringArray = PackedStringArray()
var _labels: Array[Label] = []
var _index: int = 0
var _disabled: Dictionary = {}


func set_items(items: Array[Dictionary]) -> void:
	for child: Node in get_children():
		child.queue_free()
	_ids.clear()
	_labels.clear()
	_disabled.clear()
	for item: Dictionary in items:
		var id: String = str(item.get("id", ""))
		var label: Label = Label.new()
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		label.text = BLANK + str(item.get("text", id))
		add_child(label)
		_ids.append(id)
		_labels.append(label)
		if bool(item.get("disabled", false)):
			_disabled[id] = true
	_index = 0
	_skip_disabled(1)
	_refresh()


func set_item_text(id: String, text: String) -> void:
	var i: int = _ids.find(id)
	if i >= 0:
		_labels[i].text = (CURSOR if i == _index else BLANK) + text


func get_selected_id() -> String:
	return _ids[_index] if _index >= 0 and _index < _ids.size() else ""


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _ids.is_empty():
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_move(1)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_move(-1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if not _disabled.has(get_selected_id()):
			AudioManager.play_se("se_menu_ok")
			activated.emit(_index, get_selected_id())
		else:
			AudioManager.play_se("se_menu_error")
	elif event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel"):
		AudioManager.play_se("se_menu_cancel")
		cancelled.emit()
	else:
		return
	# 決定でシーンが切り替わると自分ごと木から外れ、viewport が無くなることがある（タイトル → ゲーム開始）
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _move(delta: int) -> void:
	AudioManager.play_se("se_menu_move")
	_index = wrapi(_index + delta, 0, _ids.size())
	_skip_disabled(delta)
	_refresh()
	selection_changed.emit(_index, get_selected_id())


func _skip_disabled(delta: int) -> void:
	var guard: int = 0
	while _disabled.has(get_selected_id()) and guard < _ids.size():
		_index = wrapi(_index + (1 if delta >= 0 else -1), 0, _ids.size())
		guard += 1


func _refresh() -> void:
	for i: int in _labels.size():
		var text: String = _labels[i].text.substr(BLANK.length())
		_labels[i].text = (CURSOR if i == _index else BLANK) + text
		var dim: bool = _disabled.has(_ids[i])
		_labels[i].add_theme_color_override("font_color",
			Palette.get_color(Palette.UI_TEXT_DIM if dim else (Palette.UI_ACCENT if i == _index else Palette.UI_TEXT)))
