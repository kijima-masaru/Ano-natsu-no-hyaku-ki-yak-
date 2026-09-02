extends FieldBase
## F09 磐戸城址。土塁・空堀・土橋・馬出しが残る中世山城。高速道路で山から切り離された「聖域」。
## 迷路は複雑にしすぎない。見通しの悪さ（樹林・崖）で不安を作る。
## 縄張図と実際の地形が合わない。主郭に至って戻ると、入ったはずの土橋が無い（崖になる）。
## 代わりに馬出しの隠し口が開き、空堀の底を通って外へ出られる（フラグ f09_bridge_gone）。
## 出口：W→F03 (0,6 施錠 key_tunnel_fence) のみ。環境音 amb_castle

const GROUND_LEGEND: Dictionary = {
	"u": "獣道",
	"d": "土塁（斜面・上面）",
	"m": "空堀（底・壁）",
	"g": "下草（丈高）",
	"t": "土橋",
	"f": "礎石",
}
const OBJECT_LEGEND: Dictionary = {
	"w": "樹林（暗）",
	"k": "樹林（暗）",
	"c": "崖（通行不能）",
	"B": "防音壁（遠景）",
	"n": "案内板",
	"q": "石柱",
	"r": "苔むした石",
	"R": "落石（岩）",
}
const FOG_TYPE: String = "霧（半透明オーバーレイ）"
const BRIDGE_GONE_FLAG: String = "f09_bridge_gone"
## 土橋のタイル（消えると崖になる）
const BRIDGE_TILES: Array = [
	Vector2i(10, 20), Vector2i(11, 20), Vector2i(12, 20), Vector2i(13, 20),
	Vector2i(10, 21), Vector2i(11, 21), Vector2i(12, 21), Vector2i(13, 21),
]
## 隠し道（土橋が消えると獣道になる）。主郭南端 → 崖の切り通し → 空堀 → 南の樹林を西へ → 北へ搦手口
const HIDDEN_PATH: Array = [
	Vector2i(28, 30), Vector2i(28, 31), Vector2i(28, 32), Vector2i(28, 35), Vector2i(28, 36), Vector2i(28, 37),
	Vector2i(28, 38), Vector2i(3, 38), Vector2i(4, 38), Vector2i(5, 38), Vector2i(6, 38), Vector2i(7, 38),
	Vector2i(8, 38), Vector2i(9, 38), Vector2i(10, 38), Vector2i(11, 38), Vector2i(12, 38), Vector2i(13, 38),
	Vector2i(14, 38), Vector2i(15, 38), Vector2i(16, 38), Vector2i(17, 38), Vector2i(18, 38), Vector2i(19, 38),
	Vector2i(20, 38), Vector2i(21, 38), Vector2i(22, 38), Vector2i(23, 38), Vector2i(24, 38), Vector2i(25, 38),
	Vector2i(26, 38), Vector2i(27, 38), Vector2i(3, 8), Vector2i(3, 9), Vector2i(3, 10), Vector2i(3, 11),
	Vector2i(3, 12), Vector2i(3, 13), Vector2i(3, 14), Vector2i(3, 15), Vector2i(3, 16), Vector2i(3, 17),
	Vector2i(3, 18), Vector2i(3, 19), Vector2i(3, 20), Vector2i(3, 21), Vector2i(3, 22), Vector2i(3, 23),
	Vector2i(3, 24), Vector2i(3, 25), Vector2i(3, 26), Vector2i(3, 27), Vector2i(3, 28), Vector2i(3, 29),
	Vector2i(3, 30), Vector2i(3, 31), Vector2i(3, 32), Vector2i(3, 33), Vector2i(3, 34), Vector2i(3, 35),
	Vector2i(3, 36), Vector2i(3, 37),
]
## 調べ物。テキストとフラグ操作は data/events.json（on_interact, target=id）
const INTERACTABLES: Array = [
	{"id": "map_board", "name": "崩れた案内板", "tile": Vector2i(6, 17), "kind": "sign"},
	{"id": "bridge_marker", "name": "土橋の目印", "tile": Vector2i(12, 19), "kind": "object"},
	{"id": "keep_stones", "name": "主郭の礎石", "tile": Vector2i(27, 22), "kind": "object"},
	{"id": "moat_item", "name": "空堀の底の落とし物", "tile": Vector2i(20, 33), "kind": "object"},
	{"id": "hidden_exit", "name": "馬出しの隠し口", "tile": Vector2i(28, 30), "kind": "object"},
]
## 物体タイルの下地
const DEFAULT_GROUND: String = "下草（丈高）"
const MAP_ROWS: PackedStringArray = [
	"wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkcccw",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkcccw",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkcccw",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkcccw",
	"wuuuuuuuukkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkcccw",
	"uuuuuuuuukkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkcccw",
	"wuuuuuuuukkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkcccw",
	"wkkkkkuukkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkcccw",
	"wkkkkkuukkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkcccw",
	"wkkkkkuukkmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmkkkkkkcccw",
	"wkkkkkuukkmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmkkkkkkcccw",
	"wkkkkkuukkmmccccccccccccccccccccccccccccccccmmkkkkkkcccw",
	"wkkkkkuukkmmccccccccccccccccccccccccccccccccmmkkkkkkcccw",
	"wkkkkkuukkmmccddddddddddddddddddddddddddddccmmkkkkkkcccw",
	"wkkkkkuukkmmccddddddddddddddddddddddddddddccmmkkkkkkcccw",
	"wkkkkkuukkmmccddggggggggggggggggggggggggddccmmkkkkkkcccw",
	"wkkkkknukkmmccddggggkgggggggggggggggggggddccmmkkkkkkcccw",
	"wkkkddddddmmccddggggkgggggggggggggggggggddccmmkkkkkkcccw",
	"wkkkddddddmmqcddggggkgggggggggggggggggggddccmmkkkkkkcccw",
	"wkkkddddddttttddggggkgggffffffffggggggggddccmmkkkkkkcccw",
	"wkkkddddddttttddggggkgggffffffffggggggggddccmmkkkkkkcccw",
	"wkkkddddddmmccddggggggggfffrffffggggggggddccmmkkkkkkcccw",
	"wkkkddddddmmccddggggggggffffffffgggkggggddccmmkkkkkkcccw",
	"wkkkkkkkkkmmccddggggggggffffffffgggkggggddccmmkkkkkkcccw",
	"wkkkkkkkkkmmccddgggggggggggggggggggkggggddccmmkkkkkkcccw",
	"wkkkkkkkkkmmccddggggggkkkkkkkkkggggkggggddccmmkkkkkkcccw",
	"wkkkkkkkkkmmccddgggggggggggggggggggkggggddccmmkkkkkkcccw",
	"wkkkkkkkkkmmccddggggggggggggggggggggggggddccmmkkkkkkcccw",
	"wkkkkkkkkkmmccddddddddddddddgdddddddddddddccmmkkkkkkcccw",
	"wkkkkkkkkkmmccddddddddddddddkdddddddddddddccmmkkkkkkcccw",
	"wkkkkkkkkkmmccccccccccccccccccccccccccccccccmmkkkkkkcccw",
	"wkkkkkkkkkmmccccccccccccccccccccccccccccccccmmkkkkkkcccw",
	"wkkkkkkkkkmmmmmmmmmmRmmmmmmmmmmmmmmmmmmmmmmmmmkkkkkkcccw",
	"wkkkkkkkkkmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmkkkkkkcccw",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkcccw",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkcccw",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkcccw",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkcccw",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkcccw",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkcccw",
	"wBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBw",
	"wBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBw",
	"wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
]


func _ready() -> void:
	super()
	if not GameState.flag_raised.is_connected(_on_flag_raised):
		GameState.flag_raised.connect(_on_flag_raised)


## 崖と岩の下地は空堀、案内板・石柱は土塁、樹林は獣道
func _ground_under(x: int, y: int) -> String:
	var ch: String = MAP_ROWS[y][x]
	if ch == "c" or ch == "R":
		return GROUND_LEGEND["m"]
	if ch == "n" or ch == "q":
		return GROUND_LEGEND["d"]
	return GROUND_LEGEND["u"]


## 夜は空堀に霧が溜まる（Overhead 層）
func _apply_time_of_day(time_of_day: String) -> void:
	var foggy: bool = time_of_day == Calendar.TIME_NIGHT or time_of_day == Calendar.TIME_EVENING
	for y: int in MAP_ROWS.size():
		for x: int in MAP_ROWS[y].length():
			if MAP_ROWS[y][x] != "m":
				continue
			if foggy:
				set_tile(overhead, Vector2i(x, y), FOG_TYPE)
			else:
				overhead.erase_cell(Vector2i(x, y))


func _apply_day(_day: int) -> void:
	_update_bridge()
	_apply_time_of_day(Calendar.time_of_day)


func _on_flag_raised(flag: String) -> void:
	if flag == BRIDGE_GONE_FLAG:
		_update_bridge()


## 土橋が消えたら崖に、隠し道は獣道に。一度消えたら戻らない
func _update_bridge() -> void:
	if not GameState.has_flag(BRIDGE_GONE_FLAG):
		return
	for tile: Vector2i in BRIDGE_TILES:
		set_tile(ground, tile, GROUND_LEGEND["m"])
		set_tile(objects, tile, OBJECT_LEGEND["c"])
	for tile: Vector2i in HIDDEN_PATH:
		objects.erase_cell(tile)
		set_tile(ground, tile, GROUND_LEGEND["u"])
