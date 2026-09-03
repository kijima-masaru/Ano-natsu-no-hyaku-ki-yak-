extends Node
## data/evidence.json を読み込み、証拠の入手と隠蔽を司る autoload。
## 隠蔽の成否は「澪が近くにいるか」で決まる。判定関数は Heroine が set_witness_check で登録する（未登録なら目撃なし）。
## プレイヤーには成否も数値も見せない。表示は shown_id（成功）か msg_conceal_witnessed（失敗）だけ。

signal evidence_gained(evidence_id: String)
signal evidence_concealed(evidence_id: String, witnessed: bool)
signal load_failed(errors: PackedStringArray)

const EVIDENCE_PATH: String = "res://data/evidence.json"

var is_loaded: bool = false
var load_errors: PackedStringArray = PackedStringArray()

var _entries: Dictionary = {}
var _witness_check: Callable = Callable()
## 表示中の提示画面（hold のとき close まで残る）
var _reveal: Control = null


func _ready() -> void:
	load_file(EVIDENCE_PATH)
	EventSystem.register_action("give_evidence", _act_give_evidence)
	EventSystem.register_action("conceal_evidence", _act_conceal_evidence)
	EventSystem.register_action("show_concealment_reveal", _act_show_reveal)
	EventSystem.register_action("close_concealment_reveal", _act_close_reveal)


func load_file(path: String) -> bool:
	_entries.clear()
	load_errors.clear()
	is_loaded = false
	var read_errors: PackedStringArray = PackedStringArray()
	var root: Dictionary = JsonFile.read_dict(path, read_errors)
	if root.is_empty():
		return _fail(read_errors[0])
	if not root.get("evidence", null) is Array:
		return _fail("%s: 'evidence' 配列がありません" % path)
	for item: Variant in root["evidence"] as Array:
		if not item is Dictionary:
			load_errors.append("evidence の要素が辞書ではありません")
			continue
		var e: EvidenceData = EvidenceData.from_dict(item, load_errors)
		if e.id.is_empty():
			continue
		if _entries.has(e.id):
			load_errors.append("証拠 ID '%s' が重複しています" % e.id)
		_entries[e.id] = e
		for mid: String in [e.title_id, e.surface_id, e.truth_id, e.shown_id, e.action_id]:
			if not mid.is_empty() and not MessageResolver.has_message(mid):
				load_errors.append("%s: メッセージ '%s' が存在しません" % [e.id, mid])
		if not e.field.is_empty() and not FieldRegistry.has_field(e.field):
			load_errors.append("%s: フィールド '%s' が存在しません" % [e.id, e.field])
	for msg: String in load_errors:
		push_error("EvidenceRegistry: " + msg)
	is_loaded = not _entries.is_empty()
	return is_loaded


func _fail(msg: String) -> bool:
	load_errors.append(msg)
	push_error("EvidenceRegistry: " + msg)
	load_failed.emit(load_errors)
	return false


func has(id: String) -> bool:
	return _entries.has(id)


func get_evidence(id: String) -> EvidenceData:
	if not _entries.has(id):
		push_error("EvidenceRegistry: 証拠 '%s' は存在しません" % id)
		return null
	return _entries[id]


func get_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k: String in _entries.keys():
		out.append(k)
	return out


## Heroine が登録する。callable(position: Vector2) -> bool（近くにいれば true）
func set_witness_check(check: Callable) -> void:
	_witness_check = check


## 証拠をノートへ記録する。初回なら接近度を上げる
func gain(id: String) -> bool:
	var e: EvidenceData = get_evidence(id)
	if e == null:
		return false
	if not GameState.add_evidence(id):
		return false
	if e.suspicion_on_gain != 0:
		Suspicion.add(e.suspicion_on_gain, "evidence:%s" % id)
	evidence_gained.emit(id)
	return true


## 隠蔽を試みる。澪が近ければ失敗（澪が拾い、ノートに載り、接近度が大きく上がる）。戻り値は witnessed
func conceal(id: String) -> bool:
	var e: EvidenceData = get_evidence(id)
	if e == null or not e.is_concealable():
		push_error("EvidenceRegistry: '%s' は隠蔽対象ではありません" % id)
		return false
	var witnessed: bool = false
	if _witness_check.is_valid() and SceneRouter.player != null:
		witnessed = bool(_witness_check.call(SceneRouter.player.global_position))
	GameState.record_concealment(id, witnessed)
	if witnessed:
		GameState.add_evidence(id)
		Suspicion.add(e.suspicion_on_witness, "witnessed:%s" % id)
	evidence_concealed.emit(id, witnessed)
	return witnessed


func _act_give_evidence(a: Dictionary, _c: Dictionary) -> void:
	gain(str(a.get("evidence", "")))


## conceal_evidence: {evidence}。成功なら shown_id、失敗なら msg_conceal_witnessed を表示
func _act_conceal_evidence(a: Dictionary, _c: Dictionary) -> void:
	var id: String = str(a.get("evidence", ""))
	var e: EvidenceData = get_evidence(id)
	if e == null:
		return
	if GameState.concealed_evidence.has(id) or GameState.witnessed_concealments.has(id):
		await EventSystem.show_entry(MessageResolver.resolve(e.shown_id))
		return
	var witnessed: bool = conceal(id)
	await EventSystem.show_entry(MessageResolver.resolve("msg_conceal_witnessed" if witnessed else e.shown_id))


## show_concealment_reveal: {hold?}。hold（既定 true）なら最後の件の後も黒のまま残り、
## close_concealment_reveal アクションで消える（黒地のままナツの台詞を出すため）
func _act_show_reveal(a: Dictionary, _c: Dictionary) -> void:
	if _reveal != null and is_instance_valid(_reveal):
		push_error("EvidenceRegistry: 提示画面は既に出ています")
		return
	var scene: PackedScene = load("res://scenes/ui/concealment_reveal.tscn") as PackedScene
	_reveal = scene.instantiate() as Control
	_reveal.set("hold_after_last", bool(a.get("hold", true)))
	# ワールドはカメラに従うので、画面固定の UI 層（メッセージウィンドウの下）に置く。会話は提示画面の上に出る
	var ui: Node = EventSystem.get_ui_root()
	if ui != null:
		ui.add_child(_reveal)
		EventSystem.raise_message_window()
	else:
		push_error("EvidenceRegistry: UI 層が無いため提示画面をルートに置きます（カメラの影響を受ける）")
		get_tree().root.add_child(_reveal)
	await Signal(_reveal, "finished")
	if not bool(a.get("hold", true)):
		_reveal = null


func _act_close_reveal(_a: Dictionary, _c: Dictionary) -> void:
	if _reveal == null or not is_instance_valid(_reveal):
		return
	await _reveal.call("close")
	_reveal = null
