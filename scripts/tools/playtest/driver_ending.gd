extends Node
## 使い方：godot --headless --path . res://scenes/debug/playtest_driver.tscn -- --runner=res://scripts/tools/playtest/driver_ending.gd [--ed=a|b|c]
## 8/31：澪の操作で F05 → F01 → F12 → F13 → F15、橋の悠との対決、ED 分岐、事後、end_game でタイトルへ

var _w: Control = null
## 描画ありで実行したとき、案内とスタッフロールの画面を PNG で書き出す先（空なら書き出さない）
var _shot_dir: String = ""

func _ready() -> void:
	var ed: String = "a"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--ed="):
			ed = a.trim_prefix("--ed=")
		elif a.begins_with("--shot="):
			_shot_dir = a.trim_prefix("--shot=")
	SaveManager.set_setting("instant_text", true)
	SaveManager.mark_content_notice_seen()
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
	var before_count: int = int(SaveManager.system.get("clear_count", 0))
	await _it("yu_npc")
	# 事後 → 相談窓口案内（決定で閉じる）→ スタッフロール（最低秒数の後に決定で終える）→ タイトル
	var seen_notice: bool = false
	var seen_roll: bool = false
	var roll_wait: int = 0
	for i: int in 3000:
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene.name != scene_before:
			break
		var ui: Node = EventSystem.get_ui_root()
		if ui == null:
			continue
		var notice: Node = ui.get_node_or_null("ContentNotice")
		var roll: Node = ui.get_node_or_null("StaffRoll")
		if notice != null:
			if not seen_notice:
				seen_notice = true
				print("  notice: mode=%s title=%s" % [notice.get("mode"), (notice.get_node("Title") as Label).text])
				await _shot("ending_notice")
			notice.call("_unhandled_input", _press("interact"))
		elif roll != null:
			seen_roll = true
			roll_wait += 1
			if roll_wait == 1:
				print("  staff roll: lines=%d" % roll.get_node("Lines").get_child_count())
			if roll_wait == 5:
				await _shot("ending_staff_roll")
			roll.call("_unhandled_input", _press("interact"))
	var sys: Dictionary = SaveManager.system
	print("ending: a=%s b=%s c=%s reached=%s scene=%s day=%d" % [GameState.has_flag("ending_a"), GameState.has_flag("ending_b"), GameState.has_flag("ending_c"), GameState.has_flag("ending_reached"), get_tree().current_scene.name if get_tree().current_scene != null else "null", Calendar.day])
	print("system: cleared=%s clear_count=%d(+%d) first_clear_at=%s last_ending=%s by=%s" % [sys.get("cleared_endings", []), int(sys.get("clear_count", 0)), int(sys.get("clear_count", 0)) - before_count, sys.get("first_clear_at", ""), sys.get("last_ending", ""), sys.get("clears_by_ending", {})])
	print("flow: notice=%s staff_roll=%s roll_frames=%d" % [seen_notice, seen_roll, roll_wait])
	# system.json を読み直して永続化を確認
	SaveManager.load_system()
	print("reloaded: clear_count=%d last_ending=%s has_cleared=%s" % [int(SaveManager.system.get("clear_count", 0)), SaveManager.system.get("last_ending", ""), SaveManager.has_cleared()])
	# タイトルの「裏面から」→ 1 日目から truth_revealed で開始できるか
	await get_tree().process_frame
	await get_tree().process_frame
	var title: Node = get_tree().current_scene
	var list: Node = title.get("_list")
	var ids: Array = Array(list.get("_ids") as PackedStringArray)
	print("title: items=%s" % [ids])
	await _shot("title_after_clear")
	if ids.has("ura"):
		title.call("_on_activated", ids.find("ura"), "ura")
		for i: int in 120:
			await get_tree().process_frame
			var n: Node = _find_scene(title, "content_notice.tscn")
			if n != null:
				print("  replay notice: mode=%s" % n.get("mode"))
				n.call("_unhandled_input", _press("interact"))
			if get_tree().current_scene != title:
				break
		await get_tree().process_frame
		await get_tree().process_frame
		print("ura: scene=%s day=%d truth=%s field=%s suspicion=%d" % [get_tree().current_scene.name, Calendar.day, GameState.has_flag(MessageResolver.TRUTH_FLAG), SceneRouter.current_field_id, Suspicion.value])
		var w: Control = get_tree().current_scene.get("_message_window")
		var shown: String = ""
		for i: int in 300:
			await get_tree().process_frame
			if is_instance_valid(w) and bool(w.get("is_open")):
				var pages: PackedStringArray = w.get("_pages")
				shown = pages[0] if pages.size() > 0 else "(open)"
				break
		print("ura first message: %s" % shown.left(40))
	get_tree().quit(0)


func _shot(name: String) -> void:
	if _shot_dir.is_empty():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _shot_dir.path_join(name + ".png")
	if img.save_png(path) != OK:
		print("  WARN shot failed: %s" % path)


## 同名ノードは追加時に改名されるので、シーンファイル名で探す
func _find_scene(parent: Node, suffix: String) -> Node:
	for child: Node in parent.get_children():
		if child.scene_file_path.ends_with(suffix):
			return child
	return null


func _press(action: String) -> InputEventAction:
	var ev: InputEventAction = InputEventAction.new(); ev.action = action; ev.pressed = true
	return ev


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
		var ui: Node = EventSystem.get_ui_root()
		if ui != null and (ui.get_node_or_null("ContentNotice") != null or ui.get_node_or_null("StaffRoll") != null):
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
