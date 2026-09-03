class_name AudioMixer
extends RefCounted
## バス・プレイヤー・音量・クロスフェードの配線。AudioManager が「何を鳴らすか」を決め、ここが「どう鳴らすか」を担う。


## 無ければバスを作り Master へ送る
static func ensure_buses(names: PackedStringArray) -> void:
	for name: String in names:
		if AudioServer.get_bus_index(name) < 0:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, name)
			AudioServer.set_bus_send(idx, "Master")


static func make_player(owner: Node, bus: String, name: String) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = name
	p.bus = bus
	owner.add_child(p)
	return p


## 0〜1 の音量をバスへ。0 なら無音の dB
static func set_bus_volume(bus: String, linear: float, silent_db: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, silent_db if linear <= 0.0 else linear_to_db(clampf(linear, 0.0, 1.0)))


## to_player で stream を鳴らし始め、from_player を同じ時間で消す
static func crossfade(owner: Node, from_player: AudioStreamPlayer, to_player: AudioStreamPlayer, stream: AudioStream, target_db: float, fade: float, silent_db: float) -> void:
	to_player.stream = stream
	to_player.volume_db = silent_db
	to_player.play()
	var tween: Tween = owner.create_tween().set_parallel(true)
	tween.tween_property(to_player, "volume_db", target_db, fade)
	if from_player.playing:
		tween.tween_property(from_player, "volume_db", silent_db, fade)
		tween.chain().tween_callback(from_player.stop)


static func fade_out(owner: Node, player: AudioStreamPlayer, fade: float, silent_db: float) -> void:
	if not player.playing:
		return
	var tween: Tween = owner.create_tween()
	tween.tween_property(player, "volume_db", silent_db, fade)
	tween.tween_callback(player.stop)
