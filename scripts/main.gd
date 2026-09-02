extends Node
## エントリポイント。ワールドのルートを SceneRouter に登録し、GameState の現在フィールドを開く。
## メッセージウィンドウを UI 層に載せ、フィールドの調べ物と施錠通知を表示する。

const MESSAGE_WINDOW_SCENE: PackedScene = preload("res://scenes/ui/dialogue_window.tscn")
const DATE_HUD_SCENE: PackedScene = preload("res://scenes/ui/date_hud.tscn")
const SLOT_MENU_SCENE: PackedScene = preload("res://scenes/ui/slot_menu.tscn")
const TITLE_SCENE: String = "res://scenes/ui/title.tscn"
const NOTEBOOK_SCENE: PackedScene = preload("res://scenes/ui/notebook.tscn")
const MINIMAP_SCENE: PackedScene = preload("res://scenes/ui/minimap.tscn")
const DEBUG_OVERLAY_SCENE: PackedScene = preload("res://scenes/debug/debug_overlay.tscn")

@onready var world: Node2D = $World
@onready var ui: CanvasLayer = $UI

var _message_window: Control = null


func _ready() -> void:
	_message_window = MESSAGE_WINDOW_SCENE.instantiate() as Control
	ui.add_child(_message_window)
	_message_window.closed.connect(_on_message_closed)
	EventSystem.register_message_window(_message_window)
	GameState.field_visited.connect(func(_id: String) -> void: Calendar.add_investigation_points(1))
	ui.add_child(DATE_HUD_SCENE.instantiate())
	add_child(DEBUG_OVERLAY_SCENE.instantiate())
	SceneRouter.register_world(world)
	SceneRouter.passage_blocked.connect(_on_passage_blocked)
	SceneRouter.passage_closed_today.connect(_on_passage_closed_today)
	Calendar.days_compressed.connect(_on_days_compressed)
	Calendar.day_advanced.connect(_on_day_advanced)
	SceneRouter.field_entered.connect(_on_field_entered)
	SceneRouter.start()
	_run_opening_event_if_needed()


func _on_field_entered(field_id: String, from_id: String) -> void:
	print("Main: フィールド %s に入りました（from %s）" % [field_id, from_id if not from_id.is_empty() else "起動"])
	var field: FieldBase = SceneRouter.current_field
	if field != null and not field.interaction_started.is_connected(_on_interaction_started):
		field.interaction_started.connect(_on_interaction_started)
	EventSystem.fire(EventSystem.TRIGGER_ENTER, field_id)


func _on_interaction_started(target: Interactable) -> void:
	if target.kind == "save_point":
		_open_save_menu()
		return
	if EventSystem.fire(EventSystem.TRIGGER_INTERACT, SceneRouter.current_field_id, target.interaction_id):
		return
	# イベント未定義の対象：Interactable 自身のテキストか「特に何もない」
	var text: String = target.message if not target.message.is_empty() else MessageResolver.text("msg_nothing_here")
	_show_message(target.display_name, text)


func _open_save_menu() -> void:
	if SceneRouter.player != null:
		SceneRouter.player.input_enabled = false
	var menu: Control = SLOT_MENU_SCENE.instantiate() as Control
	menu.set("mode", "save")
	ui.add_child(menu)
	menu.finished.connect(func(success: bool, slot: int) -> void:
		menu.queue_free()
		if success:
			_show_message("", MessageResolver.text("msg_saved", [SavePaths.slot_label(slot)]))
		else:
			_on_message_closed())


func _exit_tree() -> void:
	SceneRouter.reset()


var _notebook: Control = null


func _unhandled_input(event: InputEvent) -> void:
	if _message_window.is_open or SceneRouter.player == null or not SceneRouter.player.input_enabled:
		return
	if event.is_action_pressed("open_notebook"):
		get_viewport().set_input_as_handled()
		_open_notebook()
	elif event.is_action_pressed("open_map"):
		get_viewport().set_input_as_handled()
		_open_overlay(MINIMAP_SCENE)
	elif event.is_action_pressed("cancel"):
		# 暫定：ポーズメニューは未実装。Esc でオートセーブしてタイトルへ
		get_viewport().set_input_as_handled()
		SaveManager.autosave()
		get_tree().change_scene_to_file(TITLE_SCENE)


## 全画面オーバーレイ（ミニマップ等）。closed で閉じてプレイヤー入力を戻す
func _open_overlay(scene: PackedScene) -> void:
	SceneRouter.player.input_enabled = false
	var overlay: Control = scene.instantiate() as Control
	ui.add_child(overlay)
	overlay.closed.connect(func() -> void:
		overlay.queue_free()
		_on_message_closed())


func _open_notebook() -> void:
	if not GameState.has_flag("notebook_unlocked"):
		_show_message("", MessageResolver.text("msg_notebook_locked"))
		return
	SceneRouter.player.input_enabled = false
	_notebook = NOTEBOOK_SCENE.instantiate() as Control
	ui.add_child(_notebook)
	_notebook.closed.connect(func() -> void:
		_notebook.queue_free()
		_notebook = null
		_on_message_closed())


func _on_passage_blocked(exit: ExitData) -> void:
	var description: String = FieldRegistry.get_lock_description(exit.lock)
	var text: String = MessageResolver.text("msg_locked")
	if not description.is_empty():
		text = MessageResolver.text("msg_locked_with_hint", [description])
	_show_message("", text)


func _on_passage_closed_today(exit: ExitData) -> void:
	var target: FieldData = FieldRegistry.get_field(exit.to_id)
	var label: String = target.name if target != null else exit.to_id
	_show_message("", MessageResolver.text("msg_closed_today", [label]))


func _on_days_compressed(from_day: int, to_day: int, text_id: String) -> void:
	print("Main: day %d〜%d を圧縮（%s）" % [from_day, to_day - 1, text_id])
	_pending_compressed_text = text_id


var _pending_compressed_text: String = ""


func _on_day_advanced(day: int, previous: int) -> void:
	print("Main: %s になった（day %d → %d）" % [Calendar.format_date(day), previous, day])
	_run_day_start(day)


## 日の開始：圧縮テキスト → 日付の告知 → schedule の opening_event
func _run_day_start(day: int) -> void:
	if GameState.has_flag("day_%d_started" % day):
		return
	GameState.raise_flag("day_%d_started" % day)
	if not _pending_compressed_text.is_empty():
		await EventSystem.show_entry(MessageResolver.resolve(_pending_compressed_text))
		_pending_compressed_text = ""
	await EventSystem.show_entry(MessageResolver.resolve("msg_day_start", [Calendar.format_date(day), Calendar.time_label()]))
	var schedule: DaySchedule = Calendar.get_schedule(day)
	if schedule != null and not schedule.opening_event.is_empty():
		EventSystem.run_event(schedule.opening_event)


func _run_opening_event_if_needed() -> void:
	_run_day_start(Calendar.day)


func _show_message(title: String, text: String) -> void:
	if SceneRouter.player != null:
		SceneRouter.player.input_enabled = false
	_message_window.show_message(title, text)


func _on_message_closed() -> void:
	if SceneRouter.player != null and not SceneRouter.is_transitioning and not EventSystem.is_running:
		SceneRouter.player.input_enabled = true
