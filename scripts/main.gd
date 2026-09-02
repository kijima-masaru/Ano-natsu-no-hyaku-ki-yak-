extends Node
## エントリポイント。ワールドのルートを SceneRouter に登録し、GameState の現在フィールドを開く。
## メッセージウィンドウを UI 層に載せ、フィールドの調べ物と施錠通知を表示する。

const MESSAGE_WINDOW_SCENE: PackedScene = preload("res://scenes/ui/message_window.tscn")

@onready var world: Node2D = $World
@onready var ui: CanvasLayer = $UI

var _message_window: Control = null


func _ready() -> void:
	_message_window = MESSAGE_WINDOW_SCENE.instantiate() as Control
	ui.add_child(_message_window)
	_message_window.closed.connect(_on_message_closed)
	SceneRouter.register_world(world)
	SceneRouter.passage_blocked.connect(_on_passage_blocked)
	SceneRouter.field_entered.connect(_on_field_entered)
	SceneRouter.start()


func _on_field_entered(field_id: String, from_id: String) -> void:
	print("Main: フィールド %s に入りました（from %s）" % [field_id, from_id if not from_id.is_empty() else "起動"])
	var field: FieldBase = SceneRouter.current_field
	if field != null and not field.interaction_started.is_connected(_on_interaction_started):
		field.interaction_started.connect(_on_interaction_started)


func _on_interaction_started(target: Interactable) -> void:
	_show_message(target.display_name, target.message)


func _on_passage_blocked(exit: ExitData) -> void:
	var description: String = FieldRegistry.get_lock_description(exit.lock)
	var text: String = "施錠されていて通れない。"
	if not description.is_empty():
		text += "\n" + description
	_show_message("", text)


func _show_message(title: String, text: String) -> void:
	if SceneRouter.player != null:
		SceneRouter.player.input_enabled = false
	_message_window.show_message(title, text)


func _on_message_closed() -> void:
	if SceneRouter.player != null and not SceneRouter.is_transitioning:
		SceneRouter.player.input_enabled = true
