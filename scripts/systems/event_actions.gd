class_name EventActions
extends RefCounted
## EventSystem の組み込みアクション。register_all(es) で登録する。
## handler(action: Dictionary, ctx: Dictionary) -> void（コルーチン可）。他 autoload のアクションは各 autoload が register_action する。

## 終幕の案内・スタッフロール・タイトル帰還の前後の暗転秒数
const END_FADE_SECONDS: float = 1.0


static func register_all(es: Node) -> void:
	es.register_action("message", func(a: Dictionary, _c: Dictionary) -> void:
		var args: Array = a.get("args", []) if a.get("args", []) is Array else []
		await es.show_entry(MessageResolver.resolve(_message_id(a), args)))
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
	es.register_action("advance_day", func(_a: Dictionary, _c: Dictionary) -> void: _advance_day_deferred(es))
	es.register_action("branch", func(a: Dictionary, c: Dictionary) -> void: await _branch(es, a, c))
	es.register_action("fade", func(a: Dictionary, _c: Dictionary) -> void:
		await SceneRouter.fade_screen(float(a.get("to", 1.0)), float(a.get("seconds", 0.7))))
	es.register_action("set_time", func(a: Dictionary, _c: Dictionary) -> void: Calendar.set_time_of_day(str(a.get("time_of_day", ""))))
	es.register_action("add_points", func(a: Dictionary, _c: Dictionary) -> void: Calendar.add_investigation_points(int(a.get("amount", 1))))
	es.register_action("wait", func(a: Dictionary, _c: Dictionary) -> void:
		await es.get_tree().create_timer(maxf(0.0, float(a.get("seconds", 0.5)))).timeout)
	es.register_action("run_event", func(a: Dictionary, _c: Dictionary) -> void: es.run_event(str(a.get("id", ""))))
	es.register_action("end_game", func(a: Dictionary, _c: Dictionary) -> void: await _end_game(es, a))
	es.register_action("choice", func(a: Dictionary, c: Dictionary) -> void: await _choice(es, a, c))
	es.register_action("autosave", func(_a: Dictionary, _c: Dictionary) -> void: SaveManager.autosave())
	es.register_action("set_companion", func(a: Dictionary, _c: Dictionary) -> void: SceneRouter.set_companion(bool(a.get("on", true))))
	es.register_action("start_stalker", func(a: Dictionary, c: Dictionary) -> void: _start_stalker(es, a, c))
	es.register_action("sleep", func(_a: Dictionary, _c: Dictionary) -> void: await _sleep(es))
	es.register_action("switch_floor", func(a: Dictionary, c: Dictionary) -> void: _switch_floor(es, a, c))
	ConditionEvaluator.register("floor", func(cond: Dictionary) -> bool:
		var field: FieldBase = SceneRouter.current_field
		return field != null and (field.current_floor == str(cond.get("floor", ""))) == bool(cond.get("is", true)))
	ConditionEvaluator.register("can_sleep", func(cond: Dictionary) -> bool:
		return Calendar.can_sleep(SceneRouter.current_field_id) == bool(cond.get("can_sleep", true)))


## message の id。rotate（ID の配列）があれば日付で順繰りに選ぶ（daily の文が毎日同じにならないように）
static func _message_id(a: Dictionary) -> String:
	var rotate: Variant = a.get("rotate", null)
	if rotate is Array and not (rotate as Array).is_empty():
		return str((rotate as Array)[Calendar.day % (rotate as Array).size()])
	return str(a.get("id", ""))


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


## choice: {prompt_id?, options:[{text_id, set_flag?, actions?, run_event?}]}。
## actions はその場で順に実行する（返答など）。run_event は待ち行列に入るので、現在のイベントの後に走る
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
	if chosen.get("actions", null) is Array:
		await es.run_actions_inline(str(c["event_id"]), chosen["actions"])
	if chosen.has("run_event"):
		es.run_event(str(chosen["run_event"]))


## start_stalker: {active, spawn_tile?, retreat_to?}。現在フィールドに追跡者を出す／消す
static func _start_stalker(es: Node, a: Dictionary, c: Dictionary) -> void:
	var field: FieldBase = SceneRouter.current_field
	if field == null:
		es.emit_action_failed(str(c["event_id"]), a, "フィールド未読込")
		return
	if not bool(a.get("active", true)):
		field.remove_stalker()
		return
	var tile_value: Variant = a.get("spawn_tile", null)
	var tile: Vector2i = field.get_size_tiles() / 2
	if tile_value is Array and (tile_value as Array).size() == 2:
		tile = Vector2i(int((tile_value as Array)[0]), int((tile_value as Array)[1]))
	field.spawn_stalker(tile, str(a.get("retreat_to", "F01")))
	GameState.raise_flag("stalker_met")


## advance_day: 自宅以外で日を送る（8/30 の夜など）。sleep と同じく、日送りはイベント終了後に行い
## 翌日の開始メッセージと現在のイベントの表示が重ならないようにする
static func _advance_day_deferred(es: Node) -> void:
	if not Calendar.can_advance():
		es.emit_action_failed("advance_day", {}, "進行条件未達")
		return
	AudioManager.play_se("se_sleep")
	es.event_finished.connect(func(_id: String) -> void: Calendar.advance_day(), Object.CONNECT_ONE_SHOT | Object.CONNECT_DEFERRED)


## branch: {conditions, then:[actions], else:[actions]}。条件をすべて満たせば then、さもなくば else をその場で実行する。
## run_event は条件を見ないので、イベントの途中で状態により分かれる箇所（真相の部分到達など）はこれを使う
static func _branch(es: Node, a: Dictionary, c: Dictionary) -> void:
	var conditions: Array[Dictionary] = []
	for v: Variant in a.get("conditions", []) as Array:
		if v is Dictionary:
			conditions.append(v)
	var taken: Variant = a.get("then", []) if ConditionEvaluator.evaluate_all(conditions) else a.get("else", [])
	if taken is Array:
		await es.run_actions_inline(str(c["event_id"]), taken)


## end_game: {ending}。クリア記録（到達 ED・回数・初回日時）→ 相談窓口案内 → スタッフロール → タイトル。
## クリア後の状態はスロットに保存しない（8/31 朝のオートセーブが残るので、ロードすると橋の前からやり直せる）
static func _end_game(es: Node, a: Dictionary) -> void:
	var ending: String = str(a.get("ending", ""))
	if ending.is_empty():
		es.emit_action_failed("end_game", a, "ending が必要")
		return
	SaveManager.record_cleared_ending(ending)
	GameState.raise_flag("ending_reached")
	GameState.raise_flag(ending)
	var ui: Node = es.call("get_ui_root")
	if ui != null:
		# 事後は暗転で終わっている。案内は自前の黒地を持つので、幕を上げてから読ませる
		var notice: Control = _mount_fullscreen(es, ui, "res://scenes/ui/content_notice.tscn", {"mode": "after_ending"})
		await SceneRouter.fade_screen(0.0, END_FADE_SECONDS)
		if notice != null:
			await Signal(notice, "acknowledged")
		var roll: Control = _mount_fullscreen(es, ui, "res://scenes/ui/staff_roll.tscn", {})
		if roll != null:
			await Signal(roll, "finished")
		AudioManager.stop_bgm(END_FADE_SECONDS)
		await SceneRouter.fade_screen(1.0, END_FADE_SECONDS)
	else:
		push_error("EventActions: UI 層が無いため案内とスタッフロールを飛ばします")
	var tree: SceneTree = es.get_tree()
	tree.change_scene_to_file("res://scenes/ui/title.tscn")
	await tree.process_frame
	SceneRouter.fade_screen(0.0, END_FADE_SECONDS)


## 全画面の UI を UI 層（対話窓の下）に載せて返す。読み込めなければ null
static func _mount_fullscreen(es: Node, ui: Node, scene_path: String, props: Dictionary) -> Control:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("EventActions: %s を読み込めません" % scene_path)
		return null
	var node: Control = packed.instantiate() as Control
	for key: String in props.keys():
		node.set(key, props[key])
	ui.add_child(node)
	es.call("raise_message_window")
	return node


## sleep: 自宅で就寝して翌日へ。眠れないときは msg_bed_not_yet を表示する。
## 日送りはイベント終了後（event_finished の遅延接続）に行い、翌日の開始メッセージと現在のイベントの表示が重ならないようにする
static func _sleep(es: Node) -> void:
	var field_id: String = SceneRouter.current_field_id
	if not Calendar.can_sleep(field_id):
		await es.show_entry(MessageResolver.resolve("msg_bed_not_yet"))
		return
	GameState.raise_flag("slept_at_home")
	await es.show_entry(MessageResolver.resolve("msg_bed_sleep"))
	AudioManager.play_se("se_sleep")
	es.event_finished.connect(func(_id: String) -> void: Calendar.try_sleep(field_id), Object.CONNECT_ONE_SHOT | Object.CONNECT_DEFERRED)


## switch_floor: {floor, tile, facing?}。現在フィールドの屋内の階へ移る／屋外（"outside"）へ戻る
static func _switch_floor(es: Node, a: Dictionary, c: Dictionary) -> void:
	var field: FieldBase = SceneRouter.current_field
	if field == null:
		es.emit_action_failed(str(c["event_id"]), a, "フィールド未読込")
		return
	var tile_value: Variant = a.get("tile", null)
	if not (tile_value is Array and (tile_value as Array).size() == 2):
		es.emit_action_failed(str(c["event_id"]), a, "tile が必要")
		return
	var tile: Vector2i = Vector2i(int((tile_value as Array)[0]), int((tile_value as Array)[1]))
	var facing: Vector2i = Vector2i.DOWN
	var f: Variant = a.get("facing", null)
	if f is Array and (f as Array).size() == 2:
		facing = Vector2i(int((f as Array)[0]), int((f as Array)[1]))
	if not field.switch_floor(str(a.get("floor", "outside")), tile, facing):
		es.emit_action_failed(str(c["event_id"]), a, "階の切替に失敗")
