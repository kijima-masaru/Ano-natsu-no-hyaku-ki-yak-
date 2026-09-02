extends Node
## GodotSteam（GDExtension 版）への空実装インターフェース。
## 実績・統計・クラウドセーブのフックだけを定義し、本実装は最終ステップで行う。
## Steam が無い環境（開発中・非 Steam ビルド）でも呼び出し側が分岐しなくて済むよう、常に安全に no-op する。

signal achievement_unlocked(achievement_id: String)
signal cloud_sync_finished(success: bool)

## GodotSteam の GDExtension が読み込まれているか（クラス "Steam" の存在で判定）
var is_available: bool = false

var _warned: Dictionary = {}


func _ready() -> void:
	is_available = ClassDB.class_exists("Steam")
	if is_available:
		push_warning("SteamBridge: GodotSteam を検出しましたが初期化は未実装です（最終ステップで実装）")


## 実績を解除する。TODO(step-final): Steam.setAchievement + storeStats
func unlock_achievement(achievement_id: String) -> void:
	if not _ready_or_warn("unlock_achievement"):
		return
	achievement_unlocked.emit(achievement_id)


## 統計値を加算する。TODO(step-final): Steam.setStatInt
func add_stat(stat_name: String, amount: int = 1) -> void:
	if not _ready_or_warn("add_stat"):
		return
	push_warning("SteamBridge.add_stat(%s, %d) は未実装です" % [stat_name, amount])


## クラウドへ保存する。TODO(step-final): Steam.fileWrite
func cloud_save(slot: int, data: PackedByteArray) -> Error:
	if not _ready_or_warn("cloud_save"):
		return ERR_UNAVAILABLE
	push_warning("SteamBridge.cloud_save(%d, %d bytes) は未実装です" % [slot, data.size()])
	return ERR_UNAVAILABLE


## クラウドから読み込む。無ければ空配列。TODO(step-final): Steam.fileRead
func cloud_load(slot: int) -> PackedByteArray:
	if not _ready_or_warn("cloud_load"):
		return PackedByteArray()
	push_warning("SteamBridge.cloud_load(%d) は未実装です" % slot)
	return PackedByteArray()


## Steam Deck 上で動いているか。TODO(step-final): Steam.isSteamRunningOnSteamDeck
func is_steam_deck() -> bool:
	return false


## 未接続時は機能ごとに 1 回だけ警告して false
func _ready_or_warn(feature: String) -> bool:
	if is_available:
		return true
	if not _warned.has(feature):
		_warned[feature] = true
		push_warning("SteamBridge: Steam 未接続のため %s は無効です（開発環境では正常）" % feature)
	return false
