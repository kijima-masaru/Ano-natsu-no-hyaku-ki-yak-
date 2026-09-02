extends Control
## 設定画面。項目は SaveManager.DEFAULT_SETTINGS のキーに対応し、変更は即 system.json に保存する。
## 左右キーで値を変える。項目の増減はこの ITEMS だけを編集する。

signal closed()

const FONT_SIZE: int = 12
## id / 表示名 / 種別（"slider" 0〜1 を 10 段階、"toggle"）
const ITEMS: Array[Dictionary] = [
	{"id": "master_volume", "text": "全体の音量", "kind": "slider"},
	{"id": "bgm_volume", "text": "音楽", "kind": "slider"},
	{"id": "se_volume", "text": "効果音", "kind": "slider"},
	{"id": "ambience_volume", "text": "環境音", "kind": "slider"},
	{"id": "text_speed", "text": "文字送りの速さ", "kind": "slider"},
	{"id": "instant_text", "text": "文字を一括表示", "kind": "toggle"},
	{"id": "brightness", "text": "明るさ", "kind": "slider"},
	{"id": "debug_overlay", "text": "デバッグ表示", "kind": "toggle"},
	{"id": "content_notice", "text": "コンテンツに関するお知らせを見る", "kind": "action"},
	{"id": "back", "text": "もどる", "kind": "action"},
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
	_title.text = "設定"
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
	match str(item["kind"]):
		"slider":
			var v: float = float(SaveManager.get_setting(id))
			var filled: int = roundi(v / SLIDER_STEP)
			return "%s　%s%s" % [item["text"], "■".repeat(filled), "□".repeat(10 - filled)]
		"toggle":
			return "%s　%s" % [item["text"], "オン" if bool(SaveManager.get_setting(id)) else "オフ"]
	return str(item["text"])


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
