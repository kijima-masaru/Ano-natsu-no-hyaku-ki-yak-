extends Node
## 使い方：godot --headless --path . res://scenes/debug/playtest_driver.tscn -- --runner=res://scripts/tools/playtest/driver_stalker.gd [引数]
## ゲーム本体からは参照しない（実機検証専用。docs/PLAYTEST_LOG.md）
## 追跡者の捕獲 → 幸運（最大 3 回）→ 押し戻し を確かめる
var _log: PackedStringArray = []

func _ready() -> void:
	SaveManager.set_setting("instant_text", true)
	Engine.time_scale = 4.0
	await get_tree().process_frame
	GameState.reset()
	Calendar.set_day(12)
	Calendar.ignore_availability = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	var main: Node = get_tree().current_scene
	var w: Control = main.get("_message_window")
	await _settle(w)
	SceneRouter.go_to("F03")
	await _settle(w)
	print("field=%s day=%d flags_before=%d" % [SceneRouter.current_field_id, Calendar.day, GameState.flags.size()])
	for round: int in 4:
		if round == 2:
			AttachedEntity.luck_count = AttachedEntity.MAX_LUCK_EVENTS
		var field: FieldBase = SceneRouter.current_field
		if SceneRouter.current_field_id != "F03":
			SceneRouter.go_to("F03"); await _settle(w); field = SceneRouter.current_field
		var ptile: Vector2i = SceneRouter.player.get_tile()
		var stalker: Node2D = field.spawn_stalker(ptile + (Vector2i(1, 0) if round < 2 else Vector2i(0, -2)), "F06")
		var captured: Array = [false]
		stalker.captured.connect(func(t: Node2D) -> void: captured[0] = true)
		var start_field: String = SceneRouter.current_field_id
		var frames: int = 0
		var luck0: int = AttachedEntity.luck_count
		while frames < 1200 and not captured[0] and AttachedEntity.luck_count == luck0 and SceneRouter.current_field_id == start_field:
			frames += 1
			await get_tree().process_frame
		await _settle(w)
		print("round %d: frames=%d captured=%s luck=%d state=%s field_now=%s luck_flags=%s" % [round, frames, captured[0], AttachedEntity.luck_count, stalker.get("state") if is_instance_valid(stalker) else "freed", SceneRouter.current_field_id, [GameState.has_flag("luck_1"), GameState.has_flag("luck_2"), GameState.has_flag("luck_3")]])
		if is_instance_valid(stalker) and SceneRouter.current_field != null:
			SceneRouter.current_field.remove_stalker()
			await get_tree().process_frame
	get_tree().quit(0)


func _settle(w: Control) -> void:
	var idle: int = 0
	for i: int in 2000:
		await get_tree().process_frame
		var busy: bool = SceneRouter.is_transitioning or EventSystem.is_running
		if bool(w.get("is_choosing")):
			busy = true; w.call("_on_choice_activated", 0, "0")
		elif bool(w.get("is_open")):
			busy = true
			var ev: InputEventAction = InputEventAction.new(); ev.action = "interact"; ev.pressed = true
			w.call("_unhandled_input", ev)
		idle = 0 if busy else idle + 1
		if idle >= 3:
			return
