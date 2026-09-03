class_name EventLoader
extends RefCounted
## data/events.json と data/items.json を読み、EventData の辞書とトリガー別の一覧に変換する。
## EventSystem autoload からのみ使う。結果は {"events": Dictionary[id→EventData], "by_trigger": Dictionary[trigger→Array], "errors": PackedStringArray}

const KEY_EVENTS: String = "events"
const KEY_BY_TRIGGER: String = "by_trigger"
const KEY_ERRORS: String = "errors"


static func load_file(path: String) -> Dictionary:
	var result: Dictionary = {KEY_EVENTS: {}, KEY_BY_TRIGGER: {}, KEY_ERRORS: PackedStringArray()}
	var errors: PackedStringArray = result[KEY_ERRORS]
	var root: Dictionary = JsonFile.read_dict(path, errors)
	if root.is_empty():
		return result
	var list: Variant = root.get("events", null)
	if not list is Array:
		errors.append("%s: 'events' 配列がありません" % path)
		return result
	var events: Dictionary = result[KEY_EVENTS]
	var by_trigger: Dictionary = result[KEY_BY_TRIGGER]
	for item: Variant in list as Array:
		if not item is Dictionary:
			errors.append("events の要素が辞書ではありません")
			continue
		var e: EventData = EventData.from_dict(item, errors)
		if e.id.is_empty():
			continue
		if events.has(e.id):
			errors.append("イベント ID '%s' が重複しています" % e.id)
			continue
		events[e.id] = e
		if not by_trigger.has(e.trigger):
			by_trigger[e.trigger] = []
		(by_trigger[e.trigger] as Array).append(e)
	return result


## items.json の ID 一覧（give_item / has_item の参照検証用）
static func load_item_ids(path: String, errors: PackedStringArray) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	var root: Dictionary = JsonFile.read_dict(path, errors)
	var list: Variant = root.get("items", [])
	if list is Array:
		for item: Variant in list as Array:
			if item is Dictionary:
				ids.append(str((item as Dictionary).get("id", "")))
	return ids
