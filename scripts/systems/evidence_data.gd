class_name EvidenceData
extends RefCounted
## data/evidence.json の 1 件。表層／真相の二層はメッセージ ID で持ち、解決は MessageResolver に任せる。

const KIND_EVIDENCE: String = "evidence"
const KIND_CONCEALABLE: String = "concealable"

var id: String = ""
var kind: String = KIND_EVIDENCE
var field: String = ""
var day_min: int = 0
var title_id: String = ""
var surface_id: String = ""
var truth_id: String = ""
## 隠蔽対象のみ：プレイヤーへの表示文と、真相到達時に明かす実際の行動
var shown_id: String = ""
var action_id: String = ""
var suspicion_on_gain: int = 0
var suspicion_on_witness: int = 20


func is_concealable() -> bool:
	return kind == KIND_CONCEALABLE


static func from_dict(d: Dictionary, errors: PackedStringArray) -> EvidenceData:
	var e: EvidenceData = EvidenceData.new()
	e.id = str(d.get("id", ""))
	var label: String = e.id if not e.id.is_empty() else "(id 無し)"
	if e.id.is_empty():
		errors.append("id の無い証拠があります")
	e.kind = str(d.get("kind", KIND_EVIDENCE))
	if e.kind != KIND_EVIDENCE and e.kind != KIND_CONCEALABLE:
		errors.append("%s: kind '%s' は evidence / concealable のいずれか" % [label, e.kind])
	e.field = str(d.get("field", ""))
	e.day_min = int(d.get("day_min", 0))
	e.title_id = str(d.get("title_id", ""))
	e.surface_id = str(d.get("surface_id", ""))
	e.truth_id = str(d.get("truth_id", ""))
	e.shown_id = str(d.get("shown_id", ""))
	e.action_id = str(d.get("action_id", ""))
	e.suspicion_on_gain = int(d.get("suspicion_on_gain", 0))
	e.suspicion_on_witness = int(d.get("suspicion_on_witness", 20))
	for key: String in ["title_id", "surface_id", "truth_id"]:
		if str(d.get(key, "")).is_empty():
			errors.append("%s: %s が必要です" % [label, key])
	if e.is_concealable() and (e.shown_id.is_empty() or e.action_id.is_empty()):
		errors.append("%s: 隠蔽対象には shown_id と action_id が必要です" % label)
	return e
