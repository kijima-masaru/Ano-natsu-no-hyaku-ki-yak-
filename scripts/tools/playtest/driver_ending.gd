extends Node
## 使い方：godot --headless --path . res://scenes/debug/playtest_driver.tscn -- --runner=res://scripts/tools/playtest/driver_ending.gd [--ed=a|b|c]
## 8/31：澪の操作で F05 → F01 → F12 → F13 → F15、橋の悠との対決、ED 分岐、事後、end_game でタイトルへ

var _w: Control = null

func _ready() -> void:
	var ed: String = "a"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--ed="):
			ed = a.trim_prefix("--ed=")
	SaveManager.set_setting("instant_text", true)
	Engine.time_scale = 8.0
	await get_tree().process_frame
	GameState.reset()
	Calendar.ignore_availability = false
	for f: String in ["seal_restored", "truth_revealed", "entered_yakushi", "baba_rage"]:
		GameState.raise_flag(f)
	match ed:
		"a":
			GameState.raise_flag("baba_told_seal")
			GameState.raise_flag("truth_partial_entity")
			GameState.record_concealment("ren_memo", true)
			Suspicion.add(90, "probe")
		"b":
			GameState.raise_flag("truth_partial_walk")
			Suspicion.add(60, "probe")
		_:
			Suspicion.add(10, "probe")
	Calendar.set_day(31)
	# set_day は日数分の接近度の加算を伴うので、経路ごとの値に戻す
	match ed:
		"a": Suspicion.add(100 - Suspicion.value, "probe")
		"b": Suspicion.add(60 - Suspicion.value, "probe")
		_: Suspicion.add(10 - Suspicion.value, "probe")
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	_w = get_tree().current_scene.get("_message_window")
	await _settle()
	print("open: field=%s pov=%s sprite=%s companion=%s suspicion=%d" % [SceneRouter.current_field_id, GameState.has_flag("pov_mio"), SceneRouter.player.get("sprite_kind"), GameState.has_flag("companion_on"), Suspicion.value])
	for fid: String in ["F01", "F12", "F13", "F15"]:
		SceneRouter.go_to(fid)
		await _settle()
	var f: FieldBase = SceneRouter.current_field
	print("F15: yu_npc=%s barricade=%s ambience=%s" % [f.get_interactable("yu_npc") != null, f.get_tile_type_at(f.objects, Vector2i(31, 16)), AudioManager.get("_current_ambience_id")])
	var scene_before: String = get_tree().current_scene.name
	await _it("yu_npc")
	for i: int in 600:
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene.name != scene_before:
			break
	print("ending: a=%s b=%s c=%s reached=%s cleared=%s scene=%s day=%d" % [GameState.has_flag("ending_a"), GameState.has_flag("ending_b"), GameState.has_flag("ending_c"), GameState.has_flag("ending_reached"), SaveManager.system.get("cleared_endings", []), get_tree().current_scene.name if get_tree().current_scene != null else "null", Calendar.day])
	get_tree().quit(0)


func _it(id: String) -> void:
	var field: FieldBase = SceneRouter.current_field
	var it: Interactable = field.get_interactable(id)
	if it == null:
		print("  MISSING %s" % id); return
	SceneRouter.player.global_position = it.global_position + Vector2(0, -GameConstants.TILE_SIZE)
	it.interact(SceneRouter.player)
	await _settle()


func _settle() -> void:
	var idle: int = 0
	for i: int in 20000:
		await get_tree().process_frame
		if not is_instance_valid(_w):
			return
		var busy: bool = SceneRouter.is_transitioning or EventSystem.is_running
		if bool(_w.get("is_choosing")):
			busy = true; _w.call("_on_choice_activated", 0, "0")
		elif bool(_w.get("is_open")):
			busy = true
			var ev: InputEventAction = InputEventAction.new(); ev.action = "interact"; ev.pressed = true
			_w.call("_unhandled_input", ev)
		idle = 0 if busy else idle + 1
		if idle >= 3:
			return
	print("  WARN settle timeout")
