extends Control
## 設定画面。項目は SaveManager.DEFAULT_SETTINGS のキーに対応し、変更は即 system.json に保存する。
## 左右キーで値を変える。項目の増減はこの ITEMS だけを編集する。

signal closed()

const FONT_SIZE: int = 12
## id / 種別（"slider" 0〜1 を 10 段階、"toggle"、"action"）。表示名は messages.json の ui_setting_<id>
const ITEMS: Array[Dictionary] = [
	{"id": "master_volume", "kind": "slider"},
	{"id": "bgm_volume", "kind": "slider"},
	{"id": "se_volume", "kind": "slider"},
	{"id": "ambience_volume", "kind": "slider"},
	{"id": "text_speed", "kind": "slider"},
	{"id": "instant_text", "kind": "toggle"},
	{"id": "brightness", "kind": "slider"},
	{"id": "debug_overlay", "kind": "toggle"},
	{"id": "content_notice", "kind": "action"},
	{"id": "back", "kind": "action"},
]
const SLIDER_STEP: float = 0.1

@onready var _panel: ColorRect = $Panel
@onready var _title: Label = $Panel/Title
@onready var _list: MenuList = $Panel/List

var _notice_scene: PackedScene = preload("res://scenes/ui/content_notice.tscn")


func _ready() -> void:
	_panel.color = Palette.with_alpha(Palette.UI_PANEL, 0.95)
	_title.add_theme_font_size_override("font_size", FONT_SIZE)
	_title.add_theme_color_override("font_color", Palette.get_color(Palette.UI_ACCENT))
	_title.text = MessageResolver.text("ui_settings_title")
	_list.activated.connect(_on_activated)
	_list.cancelled.connect(func() -> void: closed.emit())
	_rebuild()


func _rebuild() -> void:
	var items: Array[Dictionary] = []
	for item: Dictionary in ITEMS:
		items.append({"id": item["id"], "text": _format(item)})
	_list.set_items(items)


func _format(item: Dictionary) -> String:
	var id: String = str(item["id"])
	var label: String = MessageResolver.text("ui_setting_%s" % id)
	match str(item["kind"]):
		"slider":
			var v: float = float(SaveManager.get_setting(id))
			var filled: int = roundi(v / SLIDER_STEP)
			return "%s　%s%s" % [label, "■".repeat(filled), "□".repeat(10 - filled)]
		"toggle":
			return "%s　%s" % [label, MessageResolver.text("ui_on" if bool(SaveManager.get_setting(id)) else "ui_off")]
	return label


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var delta: float = 0.0
	if event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		delta = SLIDER_STEP
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		delta = -SLIDER_STEP
	else:
		return
	_adjust(_list.get_selected_id(), delta)
	get_viewport().set_input_as_handled()


func _adjust(id: String, delta: float) -> void:
	var item: Dictionary = _find(id)
	if item.is_empty():
		return
	match str(item["kind"]):
		"slider":
			var v: float = clampf(float(SaveManager.get_setting(id)) + delta, 0.0, 1.0)
			SaveManager.set_setting(id, snappedf(v, SLIDER_STEP))
		"toggle":
			SaveManager.set_setting(id, not bool(SaveManager.get_setting(id)))
		_:
			return
	_list.set_item_text(id, _format(item))


func _on_activated(_index: int, id: String) -> void:
	match id:
		"back":
			closed.emit()
		"content_notice":
			var notice: Control = _notice_scene.instantiate() as Control
			add_child(notice)
			_list.visible = false
			notice.tree_exited.connect(func() -> void: _list.visible = true)
		_:
			var item: Dictionary = _find(id)
			if str(item.get("kind", "")) == "toggle":
				_adjust(id, 0.0)


func _find(id: String) -> Dictionary:
	for item: Dictionary in ITEMS:
		if str(item["id"]) == id:
			return item
	return {}
