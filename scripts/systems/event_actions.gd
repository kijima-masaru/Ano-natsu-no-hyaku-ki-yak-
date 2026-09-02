class_name EventActions
extends RefCounted
## EventSystem の組み込みアクション。register_all(es) で登録する。
## handler(action: Dictionary, ctx: Dictionary) -> void（コルーチン可）。他 autoload のアクションは各 autoload が register_action する。


static func register_all(es: Node) -> void:
	es.register_action("message", func(a: Dictionary, _c: Dictionary) -> void:
		var args: Array = a.get("args", []) if a.get("args", []) is Array else []
		await es.show_entry(MessageResolver.resolve(str(a.get("id", "")), args)))
	es.register_action("set_flag", func(a: Dictionary, _c: Dictionary) -> void:
		if bool(a.get("value", true)):
			GameState.raise_flag(str(a.get("flag", "")))
		else:
			GameState.clear_flag(str(a.get("flag", ""))))
	es.register_action("clear_flag", func(a: Dictionary, _c: Dictionary) -> void: GameState.clear_flag(str(a.get("flag", ""))))
	es.register_action("give_item", func(a: Dictionary, _c: Dictionary) -> void: GameState.add_item(str(a.get("item", ""))))
	es.register_action("remove_item", func(a: Dictionary, _c: Dictionary) -> void: GameState.remove_item(str(a.get("item", ""))))
	es.register_action("unlock_field", func(a: Dictionary, c: Dictionary) -> void: _unlock_field(es, a, c))
	es.register_action("move_player", func(a: Dictionary, _c: Dictionary) -> void: await _move_player(a))
	es.register_action("advance_day", func(_a: Dictionary, _c: Dictionary) -> void: Calendar.advance_day())
	es.register_action("set_time", func(a: Dictionary, _c: Dictionary) -> void: Calendar.set_time_of_day(str(a.get("time_of_day", ""))))
	es.register_action("add_points", func(a: Dictionary, _c: Dictionary) -> void: Calendar.add_investigation_points(int(a.get("amount", 1))))
	es.register_action("wait", func(a: Dictionary, _c: Dictionary) -> void:
		await es.get_tree().create_timer(maxf(0.0, float(a.get("seconds", 0.5)))).timeout)
	es.register_action("run_event", func(a: Dictionary, _c: Dictionary) -> void: es.run_event(str(a.get("id", ""))))
	es.register_action("end_game", func(a: Dictionary, _c: Dictionary) -> void: _end_game(es, a))
	es.register_action("choice", func(a: Dictionary, c: Dictionary) -> void: await _choice(es, a, c))
	es.register_action("autosave", func(_a: Dictionary, _c: Dictionary) -> void: SaveManager.autosave())
	es.register_action("set_companion", func(a: Dictionary, _c: Dictionary) -> void: SceneRouter.set_companion(bool(a.get("on", true))))


static func _unlock_field(es: Node, a: Dictionary, c: Dictionary) -> void:
	var def: FieldData = FieldRegistry.get_field(str(a.get("field", "")))
	if def == null:
		es.emit_action_failed(str(c["event_id"]), a, "unknown field")
		return
	if def.unlock_flag.is_empty():
		push_warning("EventActions: %s に unlock_flag が無いため unlock_field は何もしません" % def.id)
		return
	GameState.raise_flag(def.unlock_flag)


static func _move_player(a: Dictionary) -> void:
	var field: String = str(a.get("field", ""))
	if not field.is_empty() and field != SceneRouter.current_field_id:
		SceneRouter.go_to(field)
		await SceneRouter.transition_finished
	var tile: Variant = a.get("tile", null)
	if tile is Array and (tile as Array).size() == 2 and SceneRouter.player != null:
		var facing: Vector2i = Vector2i.ZERO
		var f: Variant = a.get("facing", null)
		if f is Array and (f as Array).size() == 2:
			facing = Vector2i(int((f as Array)[0]), int((f as Array)[1]))
		SceneRouter.player.place_at_tile(Vector2i(int((tile as Array)[0]), int((tile as Array)[1])), facing)


## choice: {prompt_id?, options:[{text_id, set_flag?, run_event?}]}
static func _choice(es: Node, a: Dictionary, c: Dictionary) -> void:
	var options: Variant = a.get("options", [])
	if not options is Array or (options as Array).is_empty():
		es.emit_action_failed(str(c["event_id"]), a, "options が空")
		return
	var labels: PackedStringArray = PackedStringArray()
	for opt: Variant in options as Array:
		labels.append(MessageResolver.text(str((opt as Dictionary).get("text_id", ""))))
	if a.has("prompt_id"):
		es.call("show_prompt", MessageResolver.resolve(str(a["prompt_id"])))
	var index: int = await es.show_choice(labels)
	if index < 0 or index >= (options as Array).size():
		return
	var chosen: Dictionary = (options as Array)[index]
	if chosen.has("set_flag"):
		GameState.raise_flag(str(chosen["set_flag"]))
	if chosen.has("run_event"):
		es.run_event(str(chosen["run_event"]))


## end_game: {ending}。クリア記録を残しタイトルへ（本実装はステップ5）
static func _end_game(es: Node, a: Dictionary) -> void:
	var ending: String = str(a.get("ending", ""))
	if not ending.is_empty():
		SaveManager.record_cleared_ending(ending)
		GameState.raise_flag("ending_reached")
	es.get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
