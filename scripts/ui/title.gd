extends Control
## タイトル画面。はじめる／つづきから／設定／おわる。エントリポイント。
## 初回起動時はコンテンツに関するお知らせを先に表示する（system.json に既読を記録）。
## 周回プレイ：クリア済みエンディングの数だけ、題字の横に「面」の印を並べる（ステップ5で本実装）。

const GAME_SCENE: String = "res://scenes/main.tscn"
const FONT_SIZE: int = 12
const TITLE_FONT_SIZE: int = 20
const BACKDROP_PATH: String = "res://resources/ui/title_bg.png"

const SLOT_MENU_SCENE: PackedScene = preload("res://scenes/ui/slot_menu.tscn")
const SETTINGS_SCENE: PackedScene = preload("res://scenes/ui/settings_menu.tscn")
const NOTICE_SCENE: PackedScene = preload("res://scenes/ui/content_notice.tscn")

@onready var _bg: ColorRect = $Background
@onready var _title: Label = $Title
@onready var _sub: Label = $Subtitle
@onready var _list: MenuList = $Menu
@onready var _footer: Label = $Footer


func _ready() -> void:
	_bg.color = Palette.get_color(Palette.NIGHT_SKY)
	_setup_backdrop()
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title.add_theme_color_override("font_color", Palette.get_color(Palette.BONE_WHITE))
	_title.text = "磐戸町奇譚"  # 題字は固有名詞として直書きを許容
	_sub.add_theme_font_size_override("font_size", FONT_SIZE)
	_sub.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT_DIM))
	_sub.text = _cleared_marks()
	_footer.add_theme_font_size_override("font_size", FONT_SIZE)
	_footer.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT_DIM))
	_footer.text = InputDevice.hint("ui_hint_confirm_back")
	InputDevice.device_changed.connect(func(_pad: bool) -> void: _footer.text = InputDevice.hint("ui_hint_confirm_back"))
	_list.activated.connect(_on_activated)
	_build_menu()
	AudioManager.play_bgm("bgm_title")
	if not bool(SaveManager.system.get("content_notice_seen", false)):
		_show_notice()


## 背景絵（resources/ui/title_bg.png、384×216）があれば Background の上に敷く。無ければ単色のまま
func _setup_backdrop() -> void:
	if not ResourceLoader.exists(BACKDROP_PATH):
		return
	var tex: Texture2D = load(BACKDROP_PATH) as Texture2D
	if tex == null:
		return
	var rect: TextureRect = TextureRect.new()
	rect.name = "Backdrop"
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # 640×360 の絵に描き直すまでの暫定
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rect)
	move_child(rect, _bg.get_index() + 1)


func _build_menu() -> void:
	var has_any: bool = false
	for slot: int in SavePaths.SLOT_COUNT:
		if SaveManager.has_save(slot):
			has_any = true
	var items: Array[Dictionary] = [
		{"id": "new", "text": MessageResolver.text("ui_title_new")},
		{"id": "continue", "text": MessageResolver.text("ui_title_continue"), "disabled": not has_any},]
	if SaveManager.has_cleared():
		# 周回：初回から truth_revealed を立てて始める「裏面」（docs/SCENARIO.md §7）
		items.append({"id": "ura", "text": MessageResolver.text("ui_title_ura")})
	items.append_array([
		{"id": "settings", "text": MessageResolver.text("ui_title_settings")},
		{"id": "quit", "text": MessageResolver.text("ui_title_quit")},
	])
	_list.set_items(items)


func _cleared_marks() -> String:
	var cleared: Array = SaveManager.system.get("cleared_endings", [])
	return (MessageResolver.text("ui_cleared_mark") + " ").repeat(cleared.size()).strip_edges() if not cleared.is_empty() else ""


func _on_activated(_index: int, id: String) -> void:
	match id:
		"new":
			_start_new_game(false)
		"ura":
			_start_new_game(true)
		"continue":
			_open_slots()
		"settings":
			_open_settings()
		"quit":
			get_tree().quit()


## 裏面（ura）は真相版のテキストで最初から。警告は裏面でも省略しない（docs/CONTENT_NOTICE.md §3）
func _start_new_game(ura: bool) -> void:
	if ura:
		var notice: Control = NOTICE_SCENE.instantiate() as Control
		notice.set("mode", "replay")
		add_child(notice)
		_list.visible = false
		await Signal(notice, "acknowledged")
	GameState.reset()
	if ura:
		GameState.raise_flag(MessageResolver.TRUTH_FLAG)
	Calendar.set_day(1)
	_change_to_game()


func _open_slots() -> void:
	var menu: Control = SLOT_MENU_SCENE.instantiate() as Control
	menu.set("mode", "load")
	add_child(menu)
	_list.visible = false
	menu.finished.connect(func(success: bool, _slot: int) -> void:
		menu.queue_free()
		if success:
			_change_to_game()
		else:
			_list.visible = true)


func _open_settings() -> void:
	var menu: Control = SETTINGS_SCENE.instantiate() as Control
	add_child(menu)
	_list.visible = false
	menu.closed.connect(func() -> void:
		menu.queue_free()
		_list.visible = true)


func _show_notice() -> void:
	var notice: Control = NOTICE_SCENE.instantiate() as Control
	add_child(notice)
	_list.visible = false
	notice.acknowledged.connect(func() -> void: _list.visible = true)


func _change_to_game() -> void:
	AudioManager.stop_bgm()
	var err: Error = get_tree().change_scene_to_file(GAME_SCENE)
	if err != OK:
		push_error("Title: ゲームシーンへ遷移できません（%s）" % error_string(err))
