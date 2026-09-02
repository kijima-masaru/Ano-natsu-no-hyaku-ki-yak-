class_name SaveMigrator
extends RefCounted
## セーブデータのスキーマ移行。version が CURRENT より古ければ順に上げる。
## 現時点では移行対象が無いため導線のみ。新しい version に上げるときは _migrate_N_to_N1 を追加する。

const CURRENT_VERSION: int = 2


## 成功なら移行後の辞書、失敗なら空辞書（理由は errors）
static func migrate(data: Dictionary, errors: PackedStringArray) -> Dictionary:
	var version: int = int(data.get("schema_version", -1))
	if version < 0:
		errors.append("schema_version がありません")
		return {}
	if version > CURRENT_VERSION:
		errors.append("schema_version %d はこのビルド（%d）より新しく読めません" % [version, CURRENT_VERSION])
		return {}
	var migrated: Dictionary = data.duplicate(true)
	while version < CURRENT_VERSION:
		match version:
			1:
				migrated = _migrate_1_to_2(migrated)
			_:
				errors.append("schema_version %d からの移行手順がありません" % version)
				return {}
		version += 1
		migrated["schema_version"] = version
	return migrated


## v1（ステップ2の GameState.to_dict 単体）→ v2（セクション構造）
static func _migrate_1_to_2(old: Dictionary) -> Dictionary:
	return {
		"schema_version": 2,
		"saved_at": old.get("saved_at", ""),
		"sections": {"game_state": old},
	}
