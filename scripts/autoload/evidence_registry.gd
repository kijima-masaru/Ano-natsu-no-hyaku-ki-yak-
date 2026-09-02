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


func _ready() -> void:
	load_file(EVIDENCE_PATH)
	EventSystem.register_action("give_evidence", _act_give_evidence)
	EventSystem.register_action("conceal_evidence", _act_conceal_evidence)
	EventSystem.register_action("show_concealment_reveal", _act_show_reveal)


func load_file(path: String) -> bool:
	_entries.clear()
	load_errors.clear()
	is_loaded = false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("%s を開けません（%s）" % [path, error_string(FileAccess.get_open_error())])
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return _fail("%s: JSON 構文エラー 行 %d: %s" % [path, json.get_error_line(), json.get_error_message()])
	if not json.data is Dictionary or not (json.data as Dictionary).get("evidence", null) is Array:
		return _fail("%s: 'evidence' 配列がありません" % path)
	for item: Variant in (json.data as Dictionary)["evidence"] as Array:
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


func _act_show_reveal(_a: Dictionary, _c: Dictionary) -> void:
	var scene: PackedScene = load("res://scenes/ui/concealment_reveal.tscn") as PackedScene
	var reveal: Control = scene.instantiate() as Control
	get_tree().root.add_child(reveal)
	await Signal(reveal, "finished")
