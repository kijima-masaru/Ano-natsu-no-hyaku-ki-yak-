extends Node
## BGM（クロスフェード）／環境音（ループ）／SE の 3 系統を司る autoload。
## 音声素材が無い間は SoundSynth の合成音か無音で動く。resources/audio/<id>.ogg があればそれを優先する（差し替え境界）。
## フィールドごとの環境音は fields.json の ambience_track、夜は <id>_night があれば差し替え。
## seasonal=cicada の音量は Calendar.day で減衰し、8 月末に近づくほど蝉が減る。
## プレイヤーの noise_emitted を受け取り「直近の音源位置と強度」を保持して追跡者 AI に供給する。

signal noise_reported(position: Vector2, radius: float)

const AUDIO_PATH: String = "res://data/audio.json"
const OGG_DIR: String = "res://resources/audio"
const BUS_BGM: String = "BGM"
const BUS_SE: String = "SE"
const BUS_AMBIENCE: String = "Ambience"
const CROSSFADE_SEC: float = 1.2
const SE_POOL_SIZE: int = 6
const SILENT_DB: float = -80.0
## 蝉の減衰：day 1 で 1.0、LAST_CICADA_DAY で 0.0
const LAST_CICADA_DAY: int = 29
## 直近の音が「新しい」とみなされる時間
const NOISE_MEMORY_SEC: float = 4.0

var is_loaded: bool = false
var last_noise_position: Vector2 = Vector2.ZERO
var last_noise_radius: float = 0.0
var last_noise_time_msec: int = -100000
var tension_active: bool = false

var _tracks: Dictionary = {}
var _bgm: Array[AudioStreamPlayer] = []
var _bgm_active: int = 0
var _ambience: Array[AudioStreamPlayer] = []
var _ambience_active: int = 0
var _current_ambience_id: String = ""
var _heartbeat: AudioStreamPlayer
var _se_pool: Array[AudioStreamPlayer] = []


func _ready() -> void:
	_setup_buses()
	_setup_players()
	_load_tracks(AUDIO_PATH)
	_apply_volumes()
	SaveManager.setting_changed.connect(func(_k: String, _v: Variant) -> void: _apply_volumes())
	SceneRouter.field_entered.connect(_on_field_entered)
	SceneRouter.player_spawned.connect(_on_player_spawned)
	Calendar.time_of_day_changed.connect(func(_t: String, _p: String) -> void: _refresh_field_ambience())
	Calendar.day_advanced.connect(func(_d: int, _p: int) -> void: _refresh_field_ambience())
	EventSystem.register_action("play_sound", func(a: Dictionary, _c: Dictionary) -> void: play_se(str(a.get("id", ""))))
	EventSystem.register_action("play_bgm", func(a: Dictionary, _c: Dictionary) -> void: play_bgm(str(a.get("id", ""))))
	EventSystem.register_action("stop_bgm", func(_a: Dictionary, _c: Dictionary) -> void: stop_bgm())


# ── 初期化 ──

func _setup_buses() -> void:
	for name: String in [BUS_BGM, BUS_SE, BUS_AMBIENCE]:
		if AudioServer.get_bus_index(name) < 0:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, name)
			AudioServer.set_bus_send(idx, "Master")


func _setup_players() -> void:
	for i: int in 2:
		_bgm.append(_make_player(BUS_BGM, "Bgm%d" % i))
		_ambience.append(_make_player(BUS_AMBIENCE, "Ambience%d" % i))
	_heartbeat = _make_player(BUS_SE, "Heartbeat")
	for i: int in SE_POOL_SIZE:
		_se_pool.append(_make_player(BUS_SE, "Se%d" % i))


func _make_player(bus: String, name: String) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = name
	p.bus = bus
	add_child(p)
	return p


func _load_tracks(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("AudioManager: %s を開けません" % path)
		return
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		push_error("AudioManager: %s の解析に失敗（行 %d: %s）" % [path, json.get_error_line(), json.get_error_message()])
		return
	for item: Variant in (json.data as Dictionary).get("tracks", []) as Array:
		if item is Dictionary and (item as Dictionary).has("id"):
			_tracks[str((item as Dictionary)["id"])] = item
	for f: FieldData in FieldRegistry.get_all_fields():
		if not f.ambience_track.is_empty() and not _tracks.has(f.ambience_track):
			push_error("AudioManager: %s の ambience_track '%s' が audio.json に無い" % [f.id, f.ambience_track])
	is_loaded = not _tracks.is_empty()


func has_track(id: String) -> bool:
	return _tracks.has(id)


## OGG があればそれを、無ければ合成音を返す
func _get_stream(id: String) -> AudioStream:
	if not _tracks.has(id):
		push_error("AudioManager: トラック '%s' は audio.json に無い" % id)
		return null
	var ogg_path: String = "%s/%s.ogg" % [OGG_DIR, id]
	if ResourceLoader.exists(ogg_path):
		return load(ogg_path) as AudioStream
	var spec: Dictionary = (_tracks[id] as Dictionary).get("synth", {})
	return SoundSynth.build(id, spec)


func _track_db(id: String) -> float:
	var t: Dictionary = _tracks.get(id, {})
	var db: float = float(t.get("base_volume_db", 0.0))
	if str(t.get("seasonal", "")) == "cicada":
		db += linear_to_db(maxf(0.02, cicada_gain(Calendar.day)))
	return db


## 蝉の残り具合（1.0 → 0.0）
func cicada_gain(day: int) -> float:
	return clampf(1.0 - float(day - 1) / float(LAST_CICADA_DAY - 1), 0.0, 1.0)


# ── BGM ──

func play_bgm(id: String, fade: float = CROSSFADE_SEC) -> void:
	var stream: AudioStream = _get_stream(id)
	if stream == null:
		return
	var next: int = 1 - _bgm_active
	_crossfade(_bgm[_bgm_active], _bgm[next], stream, _track_db(id), fade)
	_bgm_active = next


func stop_bgm(fade: float = CROSSFADE_SEC) -> void:
	_fade_out(_bgm[_bgm_active], fade)


# ── 環境音 ──

func play_ambience(id: String, fade: float = CROSSFADE_SEC) -> void:
	if id == _current_ambience_id:
		return
	var stream: AudioStream = _get_stream(id)
	if stream == null:
		return
	var next: int = 1 - _ambience_active
	_crossfade(_ambience[_ambience_active], _ambience[next], stream, _track_db(id), fade)
	_ambience_active = next
	_current_ambience_id = id


func stop_ambience(fade: float = CROSSFADE_SEC) -> void:
	_fade_out(_ambience[_ambience_active], fade)
	_current_ambience_id = ""


## フィールドと時間帯から環境音 ID を決める（夜は <id>_night があれば優先）
func ambience_for(field_id: String, time_of_day: String) -> String:
	var f: FieldData = FieldRegistry.get_field(field_id) if FieldRegistry.has_field(field_id) else null
	if f == null or f.ambience_track.is_empty():
		return ""
	if time_of_day == Calendar.TIME_NIGHT or time_of_day == Calendar.TIME_EVENING:
		var night: String = f.ambience_track + "_night"
		if _tracks.has(night):
			return night
	return f.ambience_track


func _on_field_entered(field_id: String, _from: String) -> void:
	var id: String = ambience_for(field_id, Calendar.time_of_day)
	if id.is_empty():
		stop_ambience()
	else:
		play_ambience(id)


func _refresh_field_ambience() -> void:
	if SceneRouter.current_field_id.is_empty():
		return
	var id: String = ambience_for(SceneRouter.current_field_id, Calendar.time_of_day)
	if id != _current_ambience_id and not id.is_empty():
		play_ambience(id)
	elif not id.is_empty():
		# 日付が進んで蝉の量が変わった場合は音量だけ更新
		_ambience[_ambience_active].volume_db = _track_db(id)


# ── SE ──

func play_se(id: String) -> void:
	var stream: AudioStream = _get_stream(id)
	if stream == null:
		return
	for p: AudioStreamPlayer in _se_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = _track_db(id)
			p.play()
			return
	_se_pool[0].stream = stream
	_se_pool[0].play()


## 追跡中の心拍のような低音を重ねる／止める
func set_tension(active: bool) -> void:
	if active == tension_active:
		return
	tension_active = active
	if active:
		_heartbeat.stream = _get_stream("se_heartbeat")
		_heartbeat.volume_db = _track_db("se_heartbeat")
		_heartbeat.play()
	else:
		_fade_out(_heartbeat, 0.8)


# ── 音源の記録（追跡者 AI 用） ──

func _on_player_spawned(player: Node) -> void:
	if player.has_signal("noise_emitted") and not player.noise_emitted.is_connected(_on_player_noise):
		player.noise_emitted.connect(_on_player_noise)


func _on_player_noise(radius: float) -> void:
	if SceneRouter.player == null:
		return
	report_noise(SceneRouter.player.global_position, radius)
	play_se("se_footstep_sneak" if SceneRouter.player.is_sneaking else "se_footstep")


## 任意の音源を記録する（ヒロインの足音、物音イベントなど）
func report_noise(position: Vector2, radius: float) -> void:
	last_noise_position = position
	last_noise_radius = radius
	last_noise_time_msec = Time.get_ticks_msec()
	noise_reported.emit(position, radius)


## 直近の音がまだ「新しい」か
func has_recent_noise() -> bool:
	return Time.get_ticks_msec() - last_noise_time_msec < int(NOISE_MEMORY_SEC * 1000.0)


# ── 音量 ──

func _apply_volumes() -> void:
	_set_bus_volume("Master", float(SaveManager.get_setting("master_volume")))
	_set_bus_volume(BUS_BGM, float(SaveManager.get_setting("bgm_volume")))
	_set_bus_volume(BUS_SE, float(SaveManager.get_setting("se_volume")))
	_set_bus_volume(BUS_AMBIENCE, float(SaveManager.get_setting("ambience_volume")))


func _set_bus_volume(bus: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, SILENT_DB if linear <= 0.0 else linear_to_db(clampf(linear, 0.0, 1.0)))


func _crossfade(from_player: AudioStreamPlayer, to_player: AudioStreamPlayer, stream: AudioStream, target_db: float, fade: float) -> void:
	to_player.stream = stream
	to_player.volume_db = SILENT_DB
	to_player.play()
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(to_player, "volume_db", target_db, fade)
	if from_player.playing:
		tween.tween_property(from_player, "volume_db", SILENT_DB, fade)
		tween.chain().tween_callback(from_player.stop)


func _fade_out(player: AudioStreamPlayer, fade: float) -> void:
	if not player.playing:
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", SILENT_DB, fade)
	tween.tween_callback(player.stop)
