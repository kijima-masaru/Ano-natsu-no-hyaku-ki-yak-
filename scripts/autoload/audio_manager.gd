extends Node
## BGM（クロスフェード）／環境音（ループ）／蝉レイヤー／SE の系統を司る autoload。
## 音声素材は assets/audio/<kind>/<id>.ogg（tools/audio で合成。docs/AUDIO_SPEC.md）。無ければ SoundSynth の合成音か無音で動く。
## フィールドごとの環境音は fields.json の ambience_track に時間帯の接尾辞（_morning / _evening / _night）を付けたもの。無ければ無印。
## 蝉は環境音本体に含めず、日付と時間帯で選んだ独立トラック（amb_cicada_*）を重ねる（AUDIO_SPEC §4）。
## プレイヤーの noise_emitted を受け取り「直近の音源位置と強度」を保持して追跡者 AI に供給する。足音は足元のタイル種別で材質を選ぶ。

signal noise_reported(position: Vector2, radius: float)

const AUDIO_PATH: String = "res://data/audio.json"
const OGG_DIR: String = "res://assets/audio"
const BUS_BGM: String = "BGM"
const BUS_SE: String = "SE"
const BUS_AMBIENCE: String = "Ambience"
const CROSSFADE_SEC: float = 1.2
const SE_POOL_SIZE: int = 8
const SILENT_DB: float = -80.0
## 蝉の減衰：密度は素材側（rasp → rasp_thin）で落とし、音量は day 1 → 31 で緩やかに下げるだけ
const CICADA_END_GAIN: float = 0.5
const LAST_CICADA_DAY: int = 31
## 直近の音が「新しい」とみなされる時間
const NOISE_MEMORY_SEC: float = 4.0
const TIME_SUFFIX: Dictionary = {"morning": "_morning", "evening": "_evening", "night": "_night"}
## 日付以降、夕夜の環境音を「止んだ版」に固定する（蛙が止む。AUDIO_SPEC §12.5）
const STILL_AFTER_DAY: Dictionary = {"amb_paddy": {"day": 30, "id": "amb_paddy_still"}}
## 蝉を重ねないフィールド（谷）と、屋内の階（outside 以外）では重ねない
const NO_CICADA_FIELDS: PackedStringArray = ["F16"]
## 足元のタイル種別（TileCatalog.normalize 後）→ 足音の材質。無ければ asphalt
const MATERIAL_BY_TILE: Dictionary = {
	"歩道タイル": "stone", "狭い歩道": "stone", "広場の敷石": "stone", "石畳": "stone", "礎石": "stone",
	"法面階段": "stone", "石段": "stone", "崩れた石段": "stone",
	"境内の砂利": "gravel", "農道の砂利": "gravel", "林道の砂利": "gravel", "河原の石": "gravel",
	"畑の土": "soil", "校庭の土": "soil", "土のグラウンド": "soil", "公園の砂地": "soil", "土橋": "soil",
	"土塁": "soil", "堤防斜面": "soil", "空堀": "soil", "苔": "soil",
	"草地": "grass", "下草": "grass", "売地の草": "grass", "獣道": "grass", "畦道": "grass",
	"旧校舎 廊下床": "boards", "橋": "boards",
}
const STEP_VARIANTS: int = 5
const SNEAK_VARIANTS: int = 3
const NATSU_PULSE_MID: float = 0.45
const NATSU_PULSE_STRONG: float = 0.75

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
## 蝉レイヤー：2 枠 × クロスフェード用 2 プレイヤー
var _cicada: Array = []
var _cicada_active: Array[int] = [0, 0]
var _cicada_ids: Array[String] = ["", ""]
var _heartbeat: AudioStreamPlayer
var _chase: AudioStreamPlayer
## set_ambience で差し替え中（フィールドに入ると解除）
var _ambience_override_active: bool = false
var _se_pool: Array[AudioStreamPlayer] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _missing_reported: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	_setup_buses()
	_setup_players()
	_load_tracks(AUDIO_PATH)
	_apply_volumes()
	SaveManager.setting_changed.connect(func(_k: String, _v: Variant) -> void: _apply_volumes())
	SceneRouter.field_entered.connect(_on_field_entered)
	SceneRouter.player_spawned.connect(_on_player_spawned)
	Calendar.time_of_day_changed.connect(func(_t: String, _p: String) -> void: _refresh_field_ambience())
	Calendar.day_advanced.connect(_on_day_advanced)
	EventSystem.register_action("play_sound", func(a: Dictionary, _c: Dictionary) -> void: play_se(str(a.get("id", ""))))
	EventSystem.register_action("play_bgm", func(a: Dictionary, _c: Dictionary) -> void: play_bgm(str(a.get("id", ""))))
	EventSystem.register_action("stop_bgm", func(_a: Dictionary, _c: Dictionary) -> void: stop_bgm())
	EventSystem.register_action("set_ambience", func(a: Dictionary, _c: Dictionary) -> void: set_ambience(str(a.get("id", ""))))
	# ナツ：気配・話し始め・幸運（AUDIO_SPEC §10。残響は掛けない）
	AttachedEntity.presence_pulse.connect(_on_presence_pulse)
	AttachedEntity.speaking.connect(func(_id: String) -> void: play_se("se_natsu_speak"))
	AttachedEntity.luck_triggered.connect(func(_n: int, _ctx: String) -> void: play_se("se_natsu_luck"))
	GameState.evidence_added.connect(func(_id: String) -> void: play_se("se_evidence_add"))
	GameState.item_added.connect(func(_id: String) -> void: play_se("se_item_get"))


## 終了時に再生を止め、static の合成音キャッシュを空にする（残すと AudioStreamWAV と再生が終了時にリークする。Godot 4.7 で実機確認）
func _exit_tree() -> void:
	for p: AudioStreamPlayer in _all_players():
		if p != null:
			p.stop()
			p.stream = null
	SoundSynth.clear_cache()


# ── 初期化 ──

func _setup_buses() -> void:
	AudioMixer.ensure_buses(PackedStringArray([BUS_BGM, BUS_SE, BUS_AMBIENCE]))


func _setup_players() -> void:
	for i: int in 2:
		_bgm.append(_make_player(BUS_BGM, "Bgm%d" % i))
		_ambience.append(_make_player(BUS_AMBIENCE, "Ambience%d" % i))
	for slot: int in 2:
		var pair: Array[AudioStreamPlayer] = []
		for i: int in 2:
			pair.append(_make_player(BUS_AMBIENCE, "Cicada%d_%d" % [slot, i]))
		_cicada.append(pair)
	_heartbeat = _make_player(BUS_SE, "Heartbeat")
	_chase = _make_player(BUS_AMBIENCE, "Chase")
	for i: int in SE_POOL_SIZE:
		_se_pool.append(_make_player(BUS_SE, "Se%d" % i))


func _all_players() -> Array[AudioStreamPlayer]:
	var all: Array[AudioStreamPlayer] = []
	all.append_array(_bgm)
	all.append_array(_ambience)
	for pair: Array in _cicada:
		for p: AudioStreamPlayer in pair:
			all.append(p)
	all.append_array(_se_pool)
	all.append(_heartbeat)
	all.append(_chase)
	return all


func _make_player(bus: String, name: String) -> AudioStreamPlayer:
	return AudioMixer.make_player(self, bus, name)


func _load_tracks(path: String) -> void:
	var errors: PackedStringArray = PackedStringArray()
	var root: Dictionary = JsonFile.read_dict(path, errors)
	if root.is_empty():
		push_error("AudioManager: " + (errors[0] if not errors.is_empty() else "%s に tracks がありません" % path))
		return
	for item: Variant in root.get("tracks", []) as Array:
		if item is Dictionary and (item as Dictionary).has("id"):
			_tracks[str((item as Dictionary)["id"])] = item
	for f: FieldData in FieldRegistry.get_all_fields():
		if not f.ambience_track.is_empty() and not _tracks.has(f.ambience_track):
			push_error("AudioManager: %s の ambience_track '%s' が audio.json に無い" % [f.id, f.ambience_track])
	is_loaded = not _tracks.is_empty()


func has_track(id: String) -> bool:
	return _tracks.has(id)


## assets/audio/<kind>/<id>.ogg があればそれを、無ければ合成音を返す。
## 取り込み済み（.import）なら load、未取り込み（エディタを開いていない環境）でも生の OGG から読む
func _get_stream(id: String) -> AudioStream:
	if not _tracks.has(id):
		push_error("AudioManager: トラック '%s' は audio.json に無い" % id)
		return null
	var track: Dictionary = _tracks[id]
	var ogg_path: String = "%s/%s/%s.ogg" % [OGG_DIR, str(track.get("kind", "se")), id]
	var loop: bool = bool(track.get("loop", false))
	if ResourceLoader.exists(ogg_path):
		var stream: AudioStream = load(ogg_path) as AudioStream
		# ループは audio.json を正とし、取り込み設定（.import の loop。コミットしない）に依存しない
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = loop
		return stream
	if FileAccess.file_exists(ogg_path):
		var raw: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_file(ogg_path)
		if raw != null:
			raw.loop = loop
			return raw
	var spec: Dictionary = track.get("synth", {})
	if spec.is_empty():
		if not _missing_reported.has(id):
			_missing_reported[id] = true
			push_warning("AudioManager: '%s' の OGG が無く合成の定義も無い（無音）" % id)
		return null
	return SoundSynth.build(id, spec)


func _track_db(id: String) -> float:
	var t: Dictionary = _tracks.get(id, {})
	var db: float = float(t.get("base_volume_db", 0.0))
	if str(t.get("seasonal", "")) == "cicada":
		db += linear_to_db(maxf(0.02, cicada_gain(Calendar.day)))
	return db


## 蝉の残り具合（1.0 → CICADA_END_GAIN）。密度の減少は素材側（rasp → rasp_thin）
func cicada_gain(day: int) -> float:
	return lerpf(1.0, CICADA_END_GAIN, clampf(float(day - 1) / float(LAST_CICADA_DAY - 1), 0.0, 1.0))


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


## フィールドと時間帯から環境音 ID を決める。時間帯の接尾辞付きがあれば優先し、無ければ無印。
## 日付以降の「止んだ版」（STILL_AFTER_DAY）は夕夜に固定する
func ambience_for(field_id: String, time_of_day: String, day: int = -1) -> String:
	var f: FieldData = FieldRegistry.get_field(field_id) if FieldRegistry.has_field(field_id) else null
	if f == null or f.ambience_track.is_empty():
		return ""
	var base: String = f.ambience_track
	if day < 0:
		day = Calendar.day
	if STILL_AFTER_DAY.has(base) and (time_of_day == Calendar.TIME_NIGHT or time_of_day == Calendar.TIME_EVENING):
		var still: Dictionary = STILL_AFTER_DAY[base]
		if day >= int(still["day"]) and _tracks.has(str(still["id"])):
			return str(still["id"])
	var suffix: String = str(TIME_SUFFIX.get(time_of_day, ""))
	if not suffix.is_empty() and _tracks.has(base + suffix):
		return base + suffix
	return base


## 日付と時間帯で重ねる蝉のトラック（AUDIO_SPEC §4）。夜は無し
func cicada_layers_for(day: int, time_of_day: String) -> Array[String]:
	var layers: Array[String] = []
	if time_of_day == Calendar.TIME_NIGHT:
		return layers
	if time_of_day == Calendar.TIME_EVENING:
		layers.append("amb_cicada_evening")
	layers.append("amb_cicada_rasp" if day <= 15 else "amb_cicada_rasp_thin")
	if day <= 19 and time_of_day != Calendar.TIME_EVENING:
		layers.append("amb_cicada_tonal")
	return layers


## 蝉を重ねる場所か（屋外の地図で、谷でなく、set_ambience で差し替え中でない）
func _cicada_allowed(field_id: String) -> bool:
	if field_id.is_empty() or NO_CICADA_FIELDS.has(field_id) or _ambience_override_active:
		return false
	var field: FieldBase = SceneRouter.current_field
	if field != null and field.current_floor != FieldFloors.OUTSIDE:
		return false
	return true


func _apply_cicada(field_id: String) -> void:
	var wanted: Array[String] = []
	if _cicada_allowed(field_id):
		wanted = cicada_layers_for(Calendar.day, Calendar.time_of_day)
	for slot: int in 2:
		var id: String = wanted[slot] if slot < wanted.size() else ""
		if id == _cicada_ids[slot]:
			if not id.is_empty():
				(_cicada[slot] as Array)[_cicada_active[slot]].volume_db = _track_db(id)
			continue
		var pair: Array = _cicada[slot]
		if id.is_empty():
			_fade_out(pair[_cicada_active[slot]], CROSSFADE_SEC)
		else:
			var stream: AudioStream = _get_stream(id)
			if stream == null:
				continue
			var next: int = 1 - _cicada_active[slot]
			_crossfade(pair[_cicada_active[slot]], pair[next], stream, _track_db(id), CROSSFADE_SEC)
			_cicada_active[slot] = next
		_cicada_ids[slot] = id


## イベントが環境音を差し替える（set_ambience アクション）。空文字で無音。次のフィールドに入るまで有効。蝉も止める
func set_ambience(id: String) -> void:
	_ambience_override_active = true
	if id.is_empty():
		stop_ambience()
	elif _tracks.has(id):
		play_ambience(id)
	else:
		push_error("AudioManager: set_ambience の '%s' は audio.json に無い" % id)
	_apply_cicada(SceneRouter.current_field_id)


func _on_field_entered(field_id: String, _from: String) -> void:
	_ambience_override_active = false
	var id: String = ambience_for(field_id, Calendar.time_of_day)
	if id.is_empty():
		stop_ambience()
	else:
		play_ambience(id)
	_apply_cicada(field_id)
	var field: FieldBase = SceneRouter.current_field
	if field != null and not field.floor_changed.is_connected(_on_floor_changed):
		field.floor_changed.connect(_on_floor_changed)


func _on_floor_changed(_floor_id: String) -> void:
	_apply_cicada(SceneRouter.current_field_id)


func _refresh_field_ambience() -> void:
	if SceneRouter.current_field_id.is_empty():
		return
	if not _ambience_override_active:
		var id: String = ambience_for(SceneRouter.current_field_id, Calendar.time_of_day)
		if id != _current_ambience_id and not id.is_empty():
			play_ambience(id)
	_apply_cicada(SceneRouter.current_field_id)


func _on_day_advanced(_day: int, _previous: int) -> void:
	_refresh_field_ambience()


# ── SE ──

func play_se(id: String) -> void:
	if id.is_empty():
		return
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
	_se_pool[0].volume_db = _track_db(id)
	_se_pool[0].play()


## <prefix>_<1..count> から 1 本を選んで鳴らす。無ければ fallback
func play_se_variant(prefix: String, count: int, fallback: String = "") -> void:
	var id: String = "%s_%d" % [prefix, _rng.randi_range(1, maxi(1, count))]
	if _tracks.has(id):
		play_se(id)
	elif not fallback.is_empty():
		play_se(fallback)


## 足元のタイル種別から足音の材質を決める（AUDIO_SPEC §12.6）
func footstep_material(world_position: Vector2) -> String:
	var field: FieldBase = SceneRouter.current_field
	if field == null:
		return "asphalt"
	if field.current_floor != FieldFloors.OUTSIDE:
		return "boards"
	if field.ground == null:
		return "asphalt"
	var raw: String = field.get_tile_type_at(field.ground, GameConstants.world_to_tile(world_position))
	if raw.is_empty():
		return "asphalt"
	return str(MATERIAL_BY_TILE.get(TileCatalog.normalize(raw), "asphalt"))


## 主人公の足音。材質 × 乱択
func play_player_footstep(position: Vector2, sneaking: bool) -> void:
	var mat: String = footstep_material(position)
	if sneaking:
		play_se_variant("se_step_%s_sneak" % mat, SNEAK_VARIANTS, "se_footstep_sneak")
	else:
		play_se_variant("se_step_%s" % mat, STEP_VARIANTS, "se_footstep")


## 追跡者の足音（砂利／板）。主人公より遅く重い
func play_stalker_footstep(position: Vector2) -> void:
	var mat: String = footstep_material(position)
	play_se_variant("se_stalker_step_%s" % ("boards" if mat == "boards" else "gravel"), 2)


## 澪の足音。主人公より軽い
func play_heroine_footstep() -> void:
	play_se_variant("se_heroine_step", 3)


## 追跡中の心拍と低いうねりを重ねる／止める
func set_tension(active: bool) -> void:
	if active == tension_active:
		return
	tension_active = active
	if active:
		_start_loop(_heartbeat, "se_heartbeat")
		_start_loop(_chase, "se_stalker_chase_loop")
	else:
		_fade_out(_heartbeat, 0.8)
		_fade_out(_chase, 1.5)


func _start_loop(player: AudioStreamPlayer, id: String) -> void:
	var stream: AudioStream = _get_stream(id)
	if stream == null:
		return
	player.stream = stream
	player.volume_db = _track_db(id)
	player.play()


## ナツの気配（AttachedEntity.presence_pulse）。強さで 3 段
func _on_presence_pulse(strength: float) -> void:
	if strength >= NATSU_PULSE_STRONG:
		play_se("se_natsu_pulse_strong")
	elif strength >= NATSU_PULSE_MID:
		play_se("se_natsu_pulse_mid")
	else:
		play_se("se_natsu_pulse_weak")


# ── 音源の記録（追跡者 AI 用） ──

func _on_player_spawned(player: Node) -> void:
	if player.has_signal("noise_emitted") and not player.noise_emitted.is_connected(_on_player_noise):
		player.noise_emitted.connect(_on_player_noise)


func _on_player_noise(radius: float) -> void:
	if SceneRouter.player == null:
		return
	report_noise(SceneRouter.player.global_position, radius)
	play_player_footstep(SceneRouter.player.global_position, SceneRouter.player.is_sneaking)


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
	AudioMixer.set_bus_volume(bus, linear, SILENT_DB)


func _crossfade(from_player: AudioStreamPlayer, to_player: AudioStreamPlayer, stream: AudioStream, target_db: float, fade: float) -> void:
	AudioMixer.crossfade(self, from_player, to_player, stream, target_db, fade, SILENT_DB)


func _fade_out(player: AudioStreamPlayer, fade: float) -> void:
	AudioMixer.fade_out(self, player, fade, SILENT_DB)
