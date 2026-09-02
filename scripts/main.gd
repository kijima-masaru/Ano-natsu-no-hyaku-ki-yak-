extends Node
## エントリポイント。ワールドのルートを SceneRouter に登録し、GameState の現在フィールドを開く。
## UI 層（メッセージウィンドウ等）はこのシーンの UI CanvasLayer に載せる。

@onready var world: Node2D = $World
@onready var ui: CanvasLayer = $UI


func _ready() -> void:
	SceneRouter.register_world(world)
	SceneRouter.passage_blocked.connect(_on_passage_blocked)
	SceneRouter.field_entered.connect(_on_field_entered)
	SceneRouter.start()


func _on_field_entered(field_id: String, from_id: String) -> void:
	print("Main: フィールド %s に入りました（from %s）" % [field_id, from_id if not from_id.is_empty() else "起動"])


func _on_passage_blocked(exit: ExitData) -> void:
	# TODO(step-2 task-7): メッセージウィンドウで「鍵がかかっている」等を表示する
	print("Main: %s は通れません（%s）" % [exit.describe(), FieldRegistry.get_lock_description(exit.lock)])
