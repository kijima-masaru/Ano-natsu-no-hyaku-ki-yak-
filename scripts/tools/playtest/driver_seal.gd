extends Node
## 使い方：godot --headless --path . res://scenes/debug/playtest_driver.tscn -- --runner=res://scripts/tools/playtest/driver_seal.gd [--untold]
## 8/30 の封印：落石の開放 → 面を一枚ずつ台座へ → 封石 → seal_restored → F01 の静まり返り を確かめる

var _w: Control = null
var _amb: PackedStringArray = []

func _ready() -> void:
	var untold: bool = OS.get_cmdline_user_args().has("--untold")
	SaveManager.set_setting("instant_text", true)
	Engine.time_scale = 4.0
	await get_tree().process_frame
	GameState.reset()
	Calendar.ignore_availability = true
	GameState.raise_flag("companion_on")
	if not untold:
		GameState.raise_flag("baba_told_seal")
	Calendar.set_day(30)
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	_w = get_tree().current_scene.get("_message_window")
	await _settle()
	print("day30 open done: told=%s natsu=%s" % [not untold, GameState.has_flag("ev_done_ev_d30_start_told")])
	SceneRouter.go_to("F16")
	await _settle()
	var f: FieldBase = SceneRouter.current_field
	print("F16: rocks=%s stone@%s pedestals=%s" % [[f.get_tile_type_at(f.objects, Vector2i(16, 15))], f.get_tile_type_at(f.objects, Vector2i(17, 9)), [f.get_interactable("pedestal_e") != null, f.get_interactable("pedestal_n") != null]])
	await _it("inner_gate")
	await _it("seal_stone")
	if OS.get_cmdline_user_args().has("--shot"):
		SceneRouter.player.global_position = GameConstants.tile_to_world(Vector2i(16, 12))
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://shot_seal_inner.png")
	print("ambience after stone_first: %s" % AudioManager.get("_current_ambience_id"))
	await _it("seal_stone")
	# 面を順に取り、まず違う台座、次に正しい台座へ
	var order: Array = [["okina", "pedestal_e", "pedestal_s"], ["uba", "pedestal_w", "pedestal_n"], ["oni", "pedestal_s", "pedestal_e"], ["warabe", "pedestal_n", "pedestal_w"]]
	for step: Array in order:
		await _it("masks")
		print("  took %s: has=%s" % [step[0], GameState.has_item("mask_%s" % step[0])])
		await _it("masks")
		await _it(step[2])
		print("  wrong pedestal: still has=%s placed=%s" % [GameState.has_item("mask_%s" % step[0]), GameState.has_flag("seal_placed_%s" % step[0])])
		await _it(step[1])
		print("  right pedestal: has=%s placed=%s" % [GameState.has_item("mask_%s" % step[0]), GameState.has_flag("seal_placed_%s" % step[0])])
	await _it("masks")
	await _it("seal_stone")
	print("seal_restored=%s ambience=%s stone@16,9=%s fog@16,10=%s" % [GameState.has_flag("seal_restored"), AudioManager.get("_current_ambience_id"), f.get_tile_type_at(f.objects, Vector2i(16, 9)), f.get_tile_type_at(f.overhead, Vector2i(16, 10))])
	await _it("seal_stone")
	SceneRouter.go_to("F01")
	await _settle()
	print("F01: ambience=%s silence_done=%s can_advance=%s" % [AudioManager.get("_current_ambience_id"), GameState.has_flag("ev_done_ev_f01_d30_silence"), Calendar.can_advance()])
	get_tree().quit(0)


func _it(id: String) -> void:
	var field: FieldBase = SceneRouter.current_field
	var it: Interactable = field.get_interactable(id)
	if it == null:
		print("  MISSING interactable %s" % id); return
	SceneRouter.player.global_position = it.global_position + Vector2(0, GameConstants.TILE_SIZE)
	if SceneRouter.heroine != null and SceneRouter.heroine.is_inside_tree():
		SceneRouter.heroine.global_position = SceneRouter.player.global_position + Vector2(GameConstants.TILE_SIZE * 3, 0)
	it.interact(SceneRouter.player)
	await _settle()


func _settle() -> void:
	var idle: int = 0
	for i: int in 3000:
		await get_tree().process_frame
		var busy: bool = SceneRouter.is_transitioning or EventSystem.is_running
		if _w != null and bool(_w.get("is_choosing")):
			busy = true; _w.call("_on_choice_activated", 0, "0")
		elif _w != null and bool(_w.get("is_open")):
			busy = true
			var ev: InputEventAction = InputEventAction.new(); ev.action = "interact"; ev.pressed = true
			_w.call("_unhandled_input", ev)
		idle = 0 if busy else idle + 1
		if idle >= 3:
			return
