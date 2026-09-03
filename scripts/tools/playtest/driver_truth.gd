extends Node
## 使い方：godot --headless --path . res://scenes/debug/playtest_driver.tscn -- --runner=res://scripts/tools/playtest/driver_truth.gd [--low]
## 8/30 の夜：帰路 → 自宅前の対決 → 提示画面 → truth_revealed → 澪が去る → F01 で日が終わる、を確かめる。
## --low は接近度が低く証拠の無い経路（truth_partial_* が立たない）。--all は隠蔽 17 件すべてを成功させ、提示画面に全件出ることを確かめる

var _w: Control = null

func _ready() -> void:
	var low: bool = OS.get_cmdline_user_args().has("--low")
	SaveManager.set_setting("instant_text", true)
	Engine.time_scale = 8.0
	await get_tree().process_frame
	GameState.reset()
	Calendar.ignore_availability = true
	for f: String in ["companion_on", "seal_restored", "baba_told_seal", "entered_yakushi"]:
		GameState.raise_flag(f)
	# 隠蔽の履歴を作る：成功 5 件・目撃 2 件（--all なら evidence.json の隠蔽をすべて成功）
	if OS.get_cmdline_user_args().has("--all"):
		var all_ids: PackedStringArray = PackedStringArray()
		for id: String in EvidenceRegistry.get_ids():
			if EvidenceRegistry.get_evidence(id).kind == "concealable":
				all_ids.append(id)
				GameState.record_concealment(id, false)
		print("conceal all: %d 件" % all_ids.size())
	else:
		for id: String in ["shoe_mud", "store_receipt", "storefront_note", "journal_page", "capsule_letter"]:
			GameState.record_concealment(id, false)
		for id: String in ["ren_memo", "timetable_pass"]:
			GameState.record_concealment(id, true)
			GameState.add_evidence(id)
	if not low:
		GameState.raise_flag("baba_rage")
		Suspicion.add(80, "probe")
	AudioManager.connect("ambience_changed", func(id: String) -> void: print("  ambience -> '%s'" % id)) if AudioManager.has_signal("ambience_changed") else null
	Calendar.set_day(30)
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	_w = get_tree().current_scene.get("_message_window")
	await _settle()
	SceneRouter.go_to("F12")
	await _settle()
	print("F12 return: tod=%s ambience='%s' override=%s return_done=%s suspicion=%d" % [Calendar.time_of_day, AudioManager.get("_current_ambience_id"), AudioManager.get("_ambience_override_active"), GameState.has_flag("ev_done_ev_f12_d30_return"), Suspicion.value])
	var t0: int = Time.get_ticks_msec()
	await _it("home_door")
	print("confront: truth=%s partial_walk=%s partial_entity=%s companion=%s reveal_pages=%d elapsed=%.1fs(x8)" % [GameState.has_flag("truth_revealed"), GameState.has_flag("truth_partial_walk"), GameState.has_flag("truth_partial_entity"), GameState.has_flag("companion_on"), _reveal_pages, (Time.get_ticks_msec() - t0) / 1000.0])
	print("resolve check: natsu_009 is_truth=%s color=%d(ochre=%d) recall_a is_truth=%s yu color=%d" % [MessageResolver.resolve("msg_natsu_009").is_truth, MessageResolver.resolve("msg_natsu_009").color_index, Palette.OCHRE, MessageResolver.resolve("msg_recall_0731_a").is_truth, MessageResolver.resolve("msg_recall_0731_a").color_index])
	await _it("home_door")
	print("door again: day=%d" % Calendar.day)
	SceneRouter.go_to("F01")
	await _settle()
	for i: int in 120:
		await get_tree().process_frame
	await _settle()
	print("F01 end: day=%d end_done=%s" % [Calendar.day, GameState.has_flag("ev_done_ev_f01_d30_end")])
	get_tree().quit(0)


var _reveal_pages: int = 0

func _it(id: String) -> void:
	var field: FieldBase = SceneRouter.current_field
	var it: Interactable = field.get_interactable(id)
	if it == null:
		print("  MISSING %s" % id); return
	SceneRouter.player.global_position = it.global_position + Vector2(0, GameConstants.TILE_SIZE)
	it.interact(SceneRouter.player)
	await _settle()


func _settle() -> void:
	var idle: int = 0
	for i: int in 20000:
		await get_tree().process_frame
		var busy: bool = SceneRouter.is_transitioning or EventSystem.is_running
		var reveal: Node = get_tree().root.find_child("ConcealmentReveal", true, false)
		if _w != null and bool(_w.get("is_choosing")):
			busy = true; _w.call("_on_choice_activated", 1, "1")
		elif _w != null and bool(_w.get("is_open")):
			busy = true
			var ev: InputEventAction = InputEventAction.new(); ev.action = "interact"; ev.pressed = true
			_w.call("_unhandled_input", ev)
		elif reveal != null and bool(reveal.get("_can_advance")):
			busy = true
			_reveal_pages += 1
			if _reveal_pages == 1 and OS.get_cmdline_user_args().has("--shot"):
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("user://shot_reveal.png")
			var ev2: InputEventAction = InputEventAction.new(); ev2.action = "interact"; ev2.pressed = true
			reveal.call("_unhandled_input", ev2)
		idle = 0 if busy else idle + 1
		if idle >= 3:
			return
	print("  WARN settle timeout")
