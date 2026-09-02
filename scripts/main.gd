extends Node
## エントリポイント。ワールドのルートを SceneRouter に登録し、GameState の現在フィールドを開く。
## メッセージウィンドウを UI 層に載せ、フィールドの調べ物と施錠通知を表示する。

const MESSAGE_WINDOW_SCENE: PackedScene = preload("res://scenes/ui/message_window.tscn")
const DATE_HUD_SCENE: PackedScene = preload("res://scenes/ui/date_hud.tscn")
const SLOT_MENU_SCENE: PackedScene = preload("res://scenes/ui/slot_menu.tscn")
const TITLE_SCENE: String = "res://scenes/ui/title.tscn"

@onready var world: Node2D = $World
@onready var ui: CanvasLayer = $UI

var _message_window: Control = null


func _ready() -> void:
	_message_window = MESSAGE_WINDOW_SCENE.instantiate() as Control
	ui.add_child(_message_window)
	_message_window.closed.connect(_on_message_closed)
	ui.add_child(DATE_HUD_SCENE.instantiate())
	SceneRouter.register_world(world)
	SceneRouter.passage_blocked.connect(_on_passage_blocked)
	SceneRouter.passage_closed_today.connect(_on_passage_closed_today)
	Calendar.days_compressed.connect(_on_days_compressed)
	Calendar.day_advanced.connect(_on_day_advanced)
	SceneRouter.field_entered.connect(_on_field_entered)
	SceneRouter.start()


func _on_field_entered(field_id: String, from_id: String) -> void:
	print("Main: フィールド %s に入りました（from %s）" % [field_id, from_id if not from_id.is_empty() else "起動"])
	var field: FieldBase = SceneRouter.current_field
	if field != null and not field.interaction_started.is_connected(_on_interaction_started):
		field.interaction_started.connect(_on_interaction_started)


func _on_interaction_started(target: Interactable) -> void:
	if target.kind == "save_point":
		_open_save_menu()
		return
	_show_message(target.display_name, target.message)


func _open_save_menu() -> void:
	if SceneRouter.player != null:
		SceneRouter.player.input_enabled = false
	var menu: Control = SLOT_MENU_SCENE.instantiate() as Control
	menu.set("mode", "save")
	ui.add_child(menu)
	menu.finished.connect(func(success: bool, slot: int) -> void:
		menu.queue_free()
		if success:
			_show_message("", "記録した。（%s）" % SavePaths.slot_label(slot))
		else:
			_on_message_closed())


func _exit_tree() -> void:
	SceneRouter.reset()


func _unhandled_input(event: InputEvent) -> void:
	# 暫定：X 長押し等のメニューは未実装。Esc でタイトルへ（オートセーブ済み）。TODO(step-3 task-4): ポーズメニュー
	if event.is_action_pressed("cancel") and not _message_window.is_open and SceneRouter.player != null \
			and SceneRouter.player.input_enabled:
		get_viewport().set_input_as_handled()
		SaveManager.autosave()
		get_tree().change_scene_to_file(TITLE_SCENE)


func _on_passage_blocked(exit: ExitData) -> void:
	var description: String = FieldRegistry.get_lock_description(exit.lock)
	var text: String = "施錠されていて通れない。"
	if not description.is_empty():
		text += "\n" + description
	_show_message("", text)


## TODO(step-3 task-4): 以下の文言は messages.json へ移す
func _on_passage_closed_today(exit: ExitData) -> void:
	var target: FieldData = FieldRegistry.get_field(exit.to_id)
	var label: String = target.name if target != null else exit.to_id
	_show_message("", "今日は %s へ行く用事がない。" % label)


func _on_days_compressed(from_day: int, to_day: int, text_id: String) -> void:
	print("Main: day %d〜%d を圧縮（%s）" % [from_day, to_day - 1, text_id])


func _on_day_advanced(day: int, previous: int) -> void:
	print("Main: %s になった（day %d → %d）" % [Calendar.format_date(day), previous, day])
	if SceneRouter.current_field_id != GameState.HOME_FIELD_ID:
		return
	# 自宅で目覚める：位置を再配置して暗転演出は省略（演出はタスク3のイベントで）
	_show_message("", "%s、%s。" % [Calendar.format_date(day), Calendar.time_label()])


func _show_message(title: String, text: String) -> void:
	if SceneRouter.player != null:
		SceneRouter.player.input_enabled = false
	_message_window.show_message(title, text)


func _on_message_closed() -> void:
	if SceneRouter.player != null and not SceneRouter.is_transitioning:
		SceneRouter.player.input_enabled = true
