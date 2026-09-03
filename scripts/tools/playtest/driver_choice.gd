extends Node
## 使い方：godot --headless --path . res://scenes/debug/playtest_driver.tscn -- --runner=res://scripts/tools/playtest/driver_choice.gd [引数]
## ゲーム本体からは参照しない（実機検証専用。docs/PLAYTEST_LOG.md）
## 選択肢の表示状態を調べる
func _ready() -> void:
	SaveManager.set_setting("instant_text", true)
	await get_tree().process_frame
	GameState.reset()
	Calendar.set_day(1)
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	var main: Node = get_tree().current_scene
	var w: Control = main.get("_message_window")
	# 日の開始メッセージと opening_event を送る
	for i: int in 400:
		await get_tree().process_frame
		if bool(w.get("is_open")) and not bool(w.get("is_choosing")):
			var ev: InputEventAction = InputEventAction.new(); ev.action = "interact"; ev.pressed = true
			w.call("_unhandled_input", ev)
		elif not EventSystem.is_running and not bool(w.get("is_open")):
			break
	print("after opening: running=%s open=%s prologue flags=%s" % [EventSystem.is_running, w.get("is_open"), GameState.flags.keys()])
	var field: FieldBase = SceneRouter.current_field
	var door: Interactable = field.get_interactable("home_door")
	door.interact(SceneRouter.player)
	for i: int in 200:
		await get_tree().process_frame
		if bool(w.get("is_open")) and not bool(w.get("is_choosing")):
			var ev: InputEventAction = InputEventAction.new(); ev.action = "interact"; ev.pressed = true
			w.call("_unhandled_input", ev)
		if bool(w.get("is_choosing")):
			break
	var panel: Control = w.get_node("ChoicePanel")
	print("choice state: running=%s is_open=%s is_choosing=%s window.visible=%s panel.visible=%s panel.is_visible_in_tree=%s" % [EventSystem.is_running, w.get("is_open"), w.get("is_choosing"), w.visible, panel.visible, panel.is_visible_in_tree()])
	get_tree().quit(0)
