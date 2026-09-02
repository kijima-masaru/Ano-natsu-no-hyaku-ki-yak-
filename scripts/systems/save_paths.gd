class_name SavePaths
extends RefCounted
## セーブ関連の保存先を 1 箇所に集約する。Steam Cloud 対応時はここだけを差し替える。

const SAVE_DIR: String = "user://saves"
const SLOT_FILE_FORMAT: String = "slot_%02d.json"
const SYSTEM_FILE: String = "user://system.json"
## スロット 0 はオートセーブ。1〜3 が手動スロット
const AUTOSAVE_SLOT: int = 0
const MANUAL_SLOT_COUNT: int = 3
const SLOT_COUNT: int = MANUAL_SLOT_COUNT + 1


static func slot_path(slot: int) -> String:
	return "%s/%s" % [SAVE_DIR, SLOT_FILE_FORMAT % slot]


static func is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT


static func slot_label(slot: int) -> String:
	return "オートセーブ" if slot == AUTOSAVE_SLOT else "スロット %d" % slot


static func ensure_dir() -> Error:
	var err: Error = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_error("SavePaths: %s を作成できません（%s）" % [SAVE_DIR, error_string(err)])
	return OK if err == ERR_ALREADY_EXISTS else err
