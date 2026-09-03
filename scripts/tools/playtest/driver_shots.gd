extends Node
## 使い方：godot --headless --path . res://scenes/debug/playtest_driver.tscn -- --runner=res://scripts/tools/playtest/driver_shots.gd [引数]
## ゲーム本体からは参照しない（実機検証専用。docs/PLAYTEST_LOG.md）
## 描画確認：各画面のスクリーンショットと、夜のフィールドの描画負荷（フレーム時間）を記録する
## 出力先。--out=<dir> で変更できる（既定 user://shots/）
var _out: String = "user://shots/"

var _w: Control = null

func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out) if _out.begins_with("user://") else _out)
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await _wait(0.5)
	await _shot("01_title_notice")
	# お知らせを閉じる
	var notice: Node = get_tree().current_scene.get_node_or_null("ContentNotice")
	if notice == null:
		for c: Node in get_tree().current_scene.get_children():
			if c.has_signal("acknowledged"):
				notice = c
	if notice != null:
		var ev: InputEventAction = InputEventAction.new(); ev.action = "interact"; ev.pressed = true
		notice.call("_unhandled_input", ev)
		await _wait(0.3)
	await _shot("02_title")
	GameState.reset()
	Calendar.set_day(1)
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	var main: Node = get_tree().current_scene
	_w = main.get("_message_window")
	await _wait(0.6)
	await _shot("03_day1_dialogue")
	await _settle()
	await _shot("04_f12_morning")
	main.call("_open_notebook")
	await _wait(0.3)
	await _shot("05_notebook_locked_msg")
	await _settle()
	GameState.raise_flag("notebook_unlocked")
	GameState.raise_flag("flag_minimap_unlocked")
	main.call("_open_notebook")
	await _wait(0.3)
	await _shot("06_notebook")
	var nb: Node = main.get("_notebook")
	if nb != null:
		nb.call("emit_signal", "closed")
	await _wait(0.2)
	main.call("_open_overlay", load("res://scenes/ui/minimap.tscn"))
	await _wait(0.3)
	await _shot("07_minimap")
	for c: Node in (main.get("ui") as Node).get_children():
		if c.has_signal("closed") and c != _w and c.has_method("_unhandled_input"):
			c.call("emit_signal", "closed")
	await _wait(0.2)
	Calendar.ignore_availability = true
	Calendar.set_day(20)
	await _settle()
	for fid: String in ["F01", "F13", "F06", "F11", "F16"]:
		SceneRouter.go_to(fid)
		await _settle()
		Calendar.set_time_of_day("night")
		Lighting.set_flashlight(fid == "F01")
		await _wait(0.3)
		var ms: float = await _measure(90)
		print("frame-time %s night: avg %.2f ms (lights=%d)" % [fid, ms, _count(SceneRouter.current_field, "PointLight2D")])
		await _shot("10_%s_night" % fid)
		if fid == "F11":
			SceneRouter.current_field.switch_floor("1f", Vector2i(4, 6))
			await _settle()
			await _wait(0.3)
			print("1f lighting: override=%.2f darkness=%.2f modulate=%s tint=%s" % [Lighting.darkness_override, Lighting.darkness, str(Lighting.get("_modulate").color) if Lighting.get("_modulate") != null else "null", str(Lighting.tint_for_darkness(0.8))])
			await _shot("11_F11_1f")
			SceneRouter.current_field.switch_floor("outside", Vector2i(4, 6))
			await _settle()
		Calendar.set_time_of_day("noon")
		await _wait(0.2)
		await _shot("12_%s_noon" % fid)
	get_tree().quit(0)


func _measure(frames: int) -> float:
	var t0: int = Time.get_ticks_usec()
	for i: int in frames:
		await get_tree().process_frame
	return (Time.get_ticks_usec() - t0) / 1000.0 / frames


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out + name + ".png")
	print("shot %s %dx%d" % [name, img.get_width(), img.get_height()])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


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


func _count(node: Node, cls: String) -> int:
	if node == null: return 0
	var n: int = 1 if node.get_class() == cls else 0
	for c: Node in node.get_children():
		n += _count(c, cls)
	return n
