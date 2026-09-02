extends Node
## 作中日付（8/1〜8/31）・曜日・時間帯・当日の調査ポイントを管理する autoload。本作の骨格。
## 日程は data/schedule.json から読み、固定日／自由日／圧縮日を区別する。
## 依存：GameState（フラグ）、FieldRegistry（開放フィールドの存在検証）。SceneRouter はこれを参照して遮断する。

signal day_advanced(day: int, previous_day: int)
signal time_of_day_changed(time_of_day: String, previous: String)
signal investigation_progressed(points: int, required: int)
signal sleep_available()
signal days_compressed(from_day: int, to_day: int, text_id: String)
signal schedule_load_failed(errors: PackedStringArray)

const SCHEDULE_PATH: String = "res://data/schedule.json"
const MONTH: int = 8
const TIME_MORNING: String = "morning"
const TIME_NOON: String = "noon"
const TIME_EVENING: String = "evening"
const TIME_NIGHT: String = "night"
const TIMES: PackedStringArray = [TIME_MORNING, TIME_NOON, TIME_EVENING, TIME_NIGHT]
## HUD 用の短い表記。正式な文言は messages.json（タスク4）へ移す
const TIME_LABELS_JA: PackedStringArray = ["朝", "昼", "夕", "夜"]
const WEEKDAYS_JA: PackedStringArray = ["日", "月", "火", "水", "木", "金", "土"]
## 圧縮日の連鎖の安全弁
const MAX_COMPRESS_CHAIN: int = 7

var day: int = 1
var time_of_day: String = TIME_MORNING
var investigation_points: int = 0
var is_loaded: bool = false
var load_errors: PackedStringArray = PackedStringArray()
## デバッグ用：true なら開放フィールドの遮断を無効化
var ignore_availability: bool = false

var _days: Dictionary = {}
var _first_day: int = 1
var _last_day: int = 31
var _first_weekday: int = 6
var _home_field: String = "F12"


func _ready() -> void:
	load_schedule(SCHEDULE_PATH)


# ── 読み込み ──

func load_schedule(path: String) -> bool:
	_days.clear()
	load_errors.clear()
	is_loaded = false
	var result: Dictionary = ScheduleLoader.load_file(path)
	load_errors = result[ScheduleLoader.KEY_ERRORS]
	_days = result[ScheduleLoader.KEY_DAYS]
	var meta: Dictionary = result[ScheduleLoader.KEY_META]
	_first_day = int(meta.get("first_day", 1))
	_last_day = int(meta.get("last_day", 31))
	_first_weekday = int(meta.get("first_weekday", 6))
	_home_field = str(meta.get("home_field", "F12"))
	for msg: String in load_errors:
		push_error("Calendar: " + msg)
	if _days.is_empty():
		schedule_load_failed.emit(load_errors)
		return false
	is_loaded = true
	return true


# ── 参照 ──

func get_schedule(target_day: int = day) -> DaySchedule:
	if not _days.has(target_day):
		push_error("Calendar: day %d の定義がありません" % target_day)
		return null
	return _days[target_day]


func is_valid_day(target_day: int) -> bool:
	return target_day >= _first_day and target_day <= _last_day and _days.has(target_day)


func weekday_index(target_day: int = day) -> int:
	return (_first_weekday + (target_day - _first_day)) % WEEKDAYS_JA.size()


## "8月1日（土）"
func format_date(target_day: int = day) -> String:
	return "%d月%d日（%s）" % [MONTH, target_day, WEEKDAYS_JA[weekday_index(target_day)]]


func time_label(tod: String = time_of_day) -> String:
	var i: int = TIMES.find(tod)
	return TIME_LABELS_JA[i] if i >= 0 else "?"


func get_home_field_id() -> String:
	return _home_field


## その日に入れるフィールドか
func is_field_available(field_id: String, target_day: int = day) -> bool:
	if ignore_availability:
		return true
	var s: DaySchedule = get_schedule(target_day)
	return s != null and s.available_fields.has(field_id)


func get_available_fields(target_day: int = day) -> PackedStringArray:
	var s: DaySchedule = get_schedule(target_day)
	return s.available_fields.duplicate() if s != null else PackedStringArray()


## 進行条件を満たしているか
func can_advance() -> bool:
	var s: DaySchedule = get_schedule()
	if s == null:
		return false
	if s.is_compressed():
		return true
	if s.is_free():
		return investigation_points >= s.required_points
	return GameState.has_flag(s.condition_flag) == s.condition_flag_value


## 就寝できるか（自宅にいて、条件を満たしている）
func can_sleep(current_field_id: String) -> bool:
	return current_field_id == _home_field and can_advance()


# ── 進行 ──

## 調査ポイントを加算し、時間帯を進める（自由日）
func add_investigation_points(amount: int = 1) -> void:
	if amount <= 0:
		return
	var s: DaySchedule = get_schedule()
	investigation_points += amount
	var required: int = s.required_points if s != null and s.is_free() else 0
	investigation_progressed.emit(investigation_points, required)
	if required > 0:
		_update_time_by_points(required)
		if investigation_points >= required:
			sleep_available.emit()


func _update_time_by_points(required: int) -> void:
	var ratio: float = float(investigation_points) / float(required)
	var index: int = clampi(floori(ratio * (TIMES.size() - 1)), 0, TIMES.size() - 1)
	var target: String = TIMES[index]
	if TIMES.find(target) > TIMES.find(time_of_day):
		set_time_of_day(target)


func set_time_of_day(tod: String) -> void:
	if not TIMES.has(tod):
		push_error("Calendar: 時間帯 '%s' は不正です（%s）" % [tod, ", ".join(TIMES)])
		return
	if tod == time_of_day:
		return
	var previous: String = time_of_day
	time_of_day = tod
	time_of_day_changed.emit(time_of_day, previous)


## 就寝して翌日へ。自宅以外・条件未達はエラー
func try_sleep(current_field_id: String) -> bool:
	if current_field_id != _home_field:
		push_error("Calendar: 就寝は自宅（%s）でのみ可能です（現在 %s）" % [_home_field, current_field_id])
		return false
	if not can_advance():
		push_error("Calendar: day %d の進行条件を満たしていません" % day)
		return false
	return advance_day() == OK


## 翌日へ進む。圧縮日は skip_to まで自動で飛ばす。条件未達・範囲外はエラーで拒否
func advance_day() -> Error:
	if not can_advance():
		push_error("Calendar: day %d の進行条件未達のため日送りを拒否しました" % day)
		return ERR_UNCONFIGURED
	var current: DaySchedule = get_schedule()
	if current == null:
		return ERR_DOES_NOT_EXIST
	for flag: String in current.set_flags_on_end:
		GameState.raise_flag(flag)
	GameState.raise_flag("day_%d_done" % day)
	var next: int = day + 1
	var chain: int = 0
	while _days.has(next) and (_days[next] as DaySchedule).is_compressed() and chain < MAX_COMPRESS_CHAIN:
		var c: DaySchedule = _days[next]
		days_compressed.emit(next, c.skip_to, c.compressed_text_id)
		next = c.skip_to
		chain += 1
	if not is_valid_day(next):
		push_error("Calendar: day %d は存在しません（最終日 %d）" % [next, _last_day])
		return ERR_DOES_NOT_EXIST
	return _enter_day(next)


## 指定日へ直接移動（ロード・デバッグ用）。存在しない日はエラー
func set_day(target_day: int, keep_points: bool = false) -> Error:
	if not is_valid_day(target_day):
		push_error("Calendar: day %d は存在しません" % target_day)
		return ERR_DOES_NOT_EXIST
	var previous: int = day
	day = target_day
	if not keep_points:
		investigation_points = 0
	time_of_day = TIME_MORNING
	day_advanced.emit(day, previous)
	return OK


func _enter_day(next: int) -> Error:
	var previous: int = day
	day = next
	investigation_points = 0
	var s: DaySchedule = get_schedule()
	for flag: String in s.clear_flags_on_start:
		GameState.clear_flag(flag)
	for flag: String in s.set_flags_on_start:
		GameState.raise_flag(flag)
	var previous_tod: String = time_of_day
	time_of_day = TIME_MORNING
	day_advanced.emit(day, previous)
	if previous_tod != time_of_day:
		time_of_day_changed.emit(time_of_day, previous_tod)
	return OK


# ── シリアライズ（セーブはタスク2） ──

func to_dict() -> Dictionary:
	return {"day": day, "time_of_day": time_of_day, "investigation_points": investigation_points}


func from_dict(d: Dictionary) -> bool:
	var target_day: int = int(d.get("day", 1))
	if not is_valid_day(target_day):
		push_error("Calendar: セーブデータの day %d は不正です" % target_day)
		return false
	var tod: String = str(d.get("time_of_day", TIME_MORNING))
	if not TIMES.has(tod):
		push_error("Calendar: セーブデータの time_of_day '%s' は不正です" % tod)
		return false
	set_day(target_day)
	investigation_points = int(d.get("investigation_points", 0))
	set_time_of_day(tod)
	return true
