extends FieldBase
## F05 旧鹿之尾街道 商店街。シャッター街。生きた駄菓子屋「たちばな屋」が一軒。圓照寺の門前がここに面する（境内には入らない）。
## F01 との明暗の落差が最重要。環境音は薄く、足音が響く（amb_shopping_street）。
## 証言者トキ（澪の大叔母）はここにいる。出口：W→F01 (0,15)、N→F06 (8,0)、E→F07 (31,22)、S→F12 (8,39)

const GROUND_LEGEND: Dictionary = {
	"-": "旧街道アスファルト（狭）",
	"t": "狭い歩道（縁石）",
	"a": "生活道路アスファルト（細）",
	"j": "境内の砂利",
}
const OBJECT_LEGEND: Dictionary = {
	"w": "ブロック塀",
	"=": "瓦屋根（連続）",
	"#": "旧校舎 外壁（下見板）",
	"K": "商店の看板（褪せ）",
	"s": "シャッター（下・半開き）",
	"d": "店舗の木製戸",
	"D": "駄菓子屋の店先（点灯）",
	"C": "商店の看板（褪せ）",
	"M": "寺の山門",
	"R": "瓦屋根（連続）",
	"m": "墓石（複数形）",
	"B": "掲示板",
	"q": "石の道標",
	"p": "石の道標",
	"e": "電柱・電線",
	"L": "街灯（柱・光源）",
}
const GATE_TILES: Array = [Vector2i(22, 19), Vector2i(23, 19)]
const TOKI_TILE: Vector2i = Vector2i(6, 19)
const INTERACTABLES: Array = [
	{"id": "toki_shop", "name": "たちばな屋", "tile": Vector2i(5, 20), "kind": "object"},
	{"id": "calendar", "name": "日めくり", "tile": Vector2i(5, 21), "kind": "object"},
	{"id": "temple_gate", "name": "圓照寺 山門", "tile": Vector2i(22, 19), "kind": "object"},
	{"id": "temple_board", "name": "圓照寺の掲示板", "tile": Vector2i(19, 19), "kind": "sign"},
	{"id": "water", "name": "共同水道の跡", "tile": Vector2i(11, 24), "kind": "object"},
	{"id": "signpost", "name": "道標", "tile": Vector2i(10, 38), "kind": "sign"},
	{"id": "shutter_a", "name": "呉服店（閉店）", "tile": Vector2i(5, 4), "kind": "object"},
	{"id": "shutter_b", "name": "時計店（閉店）", "tile": Vector2i(11, 4), "kind": "object"},
	{"id": "wooden_door", "name": "薬屋（閉店）", "tile": Vector2i(11, 15), "kind": "object"},
]
const MAP_ROWS: PackedStringArray = [
	"wwwwwwww-wwwwwwwwwwwwwwwwwwwwwww",
	"w=====t---t====================w",
	"w====Kt---tK===================w",
	"w====#t---t#===================w",
	"w====st---ts=====wwwwwwwwwwwwwww",
	"w====#e---t#=====wjjjjjjjjjjjjww",
	"w====#t---t#=====wjRRRRRRRRRRjww",
	"w=====t---t======wj##########jww",
	"w====Kt---tK=====wj##########jww",
	"w====#t---t#=====wj##########jww",
	"w====st---ts=====wj####d#####jww",
	"w====#t---t#=====wjjjjjjjjjjjjww",
	"w====#t---L#=====wjjjjjjjjjjjjww",
	"w====Kt---tK=====wjmjmjjjjmjmjww",
	"w====#t---t#=====wjjjjjjjjjjjjww",
	"aaaaaaa---td=====wjmjmjjjjmjmjww",
	"w====#t---t#=====wjjjjjjjjjjjjww",
	"w====#t---t#=====wjjjjjjjjjjjjww",
	"w====Kt---t======wjjjjjjjjjjjjww",
	"w====#t---t======wwBwwMMwwwwwwww",
	"w====Dt---aaaaaaaaaaaaaaaaaaaaaw",
	"w====Ct---aaaaaaaaaaaaaaaaaaaaaw",
	"w====#t---aaaaaaaaaaaaaaaaaaaaaa",
	"w=====t---t====================w",
	"w=====e---tq===================w",
	"w====Kt---tK===================w",
	"w====#t---t#===================w",
	"w====st---ts===================w",
	"w====#t---L#===================w",
	"w====#t---t#===================w",
	"w====Kt---tK===================w",
	"w====#t---t#===================w",
	"w====st---ts===================w",
	"w====#t---t#===================w",
	"w====#e---t#===================w",
	"w=====t---tK===================w",
	"w=====t---t#===================w",
	"w=====t---ts===================w",
	"w=====t---p#===================w",
	"wwwwwwww-wwwwwwwwwwwwwwwwwwwwwww",
]

var _toki: Interactable = null


func _build(def: FieldData) -> void:
	if def != null and def.size_tiles != Vector2i(MAP_ROWS[0].length(), MAP_ROWS.size()):
		push_error("F05: MAP_ROWS の寸法が fields.json と一致しません")
	for y: int in MAP_ROWS.size():
		var row: String = MAP_ROWS[y]
		for x: int in row.length():
			var ch: String = row[x]
			var tile: Vector2i = Vector2i(x, y)
			if GROUND_LEGEND.has(ch):
				set_tile(ground, tile, GROUND_LEGEND[ch])
			elif OBJECT_LEGEND.has(ch):
				set_tile(ground, tile, GROUND_LEGEND["-"] if x <= 10 else GROUND_LEGEND["j"])
				set_tile(objects, tile, OBJECT_LEGEND[ch])
			else:
				push_error("F05: 凡例に無い文字 '%s'（%s）" % [ch, tile])
	for data: Dictionary in INTERACTABLES:
		add_interactable(Interactable.create(str(data["id"]), str(data["name"]), "", data["tile"], Vector2i.ONE, str(data["kind"])))


## 夜：圓照寺の山門が閉まり、トキは店の奥へ引く（店先の灯だけが残る）
func _apply_time_of_day(time_of_day: String) -> void:
	var night: bool = time_of_day == Calendar.TIME_NIGHT
	for tile: Vector2i in GATE_TILES:
		set_tile(objects, tile, "門扉" if night else OBJECT_LEGEND["M"])
	_update_toki(not night)


func _apply_day(_day: int) -> void:
	_update_toki(Calendar.time_of_day != Calendar.TIME_NIGHT)


func _update_toki(present: bool) -> void:
	if present and _toki == null:
		_toki = Interactable.create("toki_npc", "", "", TOKI_TILE, Vector2i.ONE, "npc")
		_toki.set_actor_sprite("toki", Vector2i.RIGHT)
		add_interactable(_toki)
	elif not present and _toki != null:
		_toki.queue_free()
		_toki = null
