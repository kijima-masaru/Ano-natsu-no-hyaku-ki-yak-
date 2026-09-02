extends FieldBase
## F01 国道281号 沿道商業地区。序盤拠点。町で唯一「明るい」場所。
## 光源（自販機・街灯・コンビニ）だけがパレットの彩度ある色を使う。ここでの安心感が後半の反転に効く。
## 出口：N→F02 (13,0)、E→F06 (31,10)、E→F05 (31,34)、S→F12 (13,47)

const GROUND_LEGEND: Dictionary = {
	".": "アスファルト",
	",": "アスファルト",
	"|": "白線（実線・破線）",
	"t": "歩道タイル",
	"g": "側溝・グレーチング",
	"P": "駐車場ライン",
	"a": "生活道路アスファルト（細）",
	"b": "草地（丈高・低）",
	"S": "法面階段",
}
const OBJECT_LEGEND: Dictionary = {
	"w": "ガードレール",
	"#": "公共建築の壁（タイル）",
	"K": "店舗看板（無地）",
	"G": "店舗ガラス面（点灯）",
	"D": "ガラス扉（点灯）",
	"V": "自販機正面",
	"c": "駐車車両（暗）",
	"h": "生垣",
	"=": "瓦屋根（連続）",
	"L": "街灯（柱・光源）",
	"e": "電柱・電線",
	"B": "掲示板",
	"k": "自転車置き場",
	"r": "集合ポスト",
	"z": "集合ポスト",
}
## 歩道橋（縞鋼板）は道路の上を渡る Overhead
const OVERHEAD_TILES: Array = [
	[Vector2i(10, 21), "縞鋼板の歩道橋"], [Vector2i(11, 21), "縞鋼板の歩道橋"], [Vector2i(12, 21), "縞鋼板の歩道橋"],
	[Vector2i(13, 21), "縞鋼板の歩道橋"], [Vector2i(14, 21), "縞鋼板の歩道橋"], [Vector2i(15, 21), "縞鋼板の歩道橋"],
	[Vector2i(16, 21), "縞鋼板の歩道橋"], [Vector2i(17, 21), "縞鋼板の歩道橋"],
]
## 夜に消える駐車車両と、夜にシャッターへ替わるドラッグストアの扉
const NIGHT_REMOVED_CARS: Array = [Vector2i(2, 17), Vector2i(3, 17), Vector2i(5, 25), Vector2i(6, 25), Vector2i(26, 16), Vector2i(27, 16)]
const DRUG_DOOR_TILE: Vector2i = Vector2i(4, 45)
const MIO_TILE: Vector2i = Vector2i(21, 10)
## 調べ物。テキストは events.json
const INTERACTABLES: Array = [
	{"id": "store_door", "name": "コンビニ", "tile": Vector2i(23, 8), "kind": "object"},
	{"id": "vending_w", "name": "自販機", "tile": Vector2i(19, 9), "kind": "object"},
	{"id": "vending_e", "name": "自販機", "tile": Vector2i(29, 9), "kind": "object"},
	{"id": "bulletin", "name": "店先の掲示板", "tile": Vector2i(19, 7), "kind": "sign"},
	{"id": "receipt_box", "name": "レシート箱", "tile": Vector2i(25, 9), "kind": "object"},
	{"id": "trash", "name": "ゴミ箱", "tile": Vector2i(22, 9), "kind": "object"},
	{"id": "car_lot", "name": "駐車場の車", "tile": Vector2i(2, 21), "kind": "object"},
	{"id": "cart", "name": "カート置き場", "tile": Vector2i(8, 14), "kind": "object"},
	{"id": "bridge_w", "name": "歩道橋", "tile": Vector2i(10, 22), "kind": "object"},
	{"id": "super_door", "name": "スーパー", "tile": Vector2i(6, 10), "kind": "object"},
	{"id": "sushi_door", "name": "回転寿司", "tile": Vector2i(4, 38), "kind": "object"},
	{"id": "drug_door", "name": "ドラッグストア", "tile": Vector2i(4, 45), "kind": "object"},
]
## 物体タイルの下地
const DEFAULT_GROUND: String = "アスファルト"
const MAP_ROWS: PackedStringArray = [
	"wwwwwwwwwwwww,wwwwwwwwwwwwwwwwww",
	"wKKKKKKKKgtt,|,,ttg.KKKKKKKKK..w",
	"w########gtt,,,,ttg.#########..w",
	"w########gtt,,,,ttg.#########..w",
	"w########gLt,|,,tLg.#########..w",
	"w########gtt,|,,ttg.#########..w",
	"w########gtt,,,,ttg.#########..w",
	"w########gtt,,,,ttgB#########..w",
	"w########ett,|,,ttg.###GG####..w",
	"w########gtt,|,,ttgV..z..r...V.w",
	"w#####GG#gtt,,,,ttgaaaaaaaaaaaaa",
	"wPPPPPPPPgtt,,,,ttg............w",
	"wPPPPPPPPgLt,|,,tLgPPPPPPPPPPPPw",
	"wPPPPPPPPgtt,|,,ttgPPPPPPPPPPPPw",
	"w.......kgtt,,,,ttgPPccPPPPPPPPw",
	"wPPPPPPPPgtt,,,,ttgPPPPPPPPPPPPw",
	"wPPPPPPPPgtt,|,,ttgPPPPPPPccPPPw",
	"wPccPccPPgtt,|,,ttgPPPPPPPPPPPPw",
	"wPPPPPPPPgtt,,,,ttgPPPPPPPPPPPPw",
	"wPPPPPPPPgtt,,,,ttg............w",
	"wPPPPPPPPgLt,|,,tLghhhhhhhhhhhhw",
	"wPccPccPPgtt,|,,ttgbbbbbbbbbbbbw",
	"wPPPPPPPPgSS,,,,SSgbbbbbbbbbbbbw",
	"wPPPPPPPPgtt,,,,ttgbbbbbbbbbbbbw",
	"wPPPPPPPPett,|,,ttgbbbbbbbbbbbbw",
	"wPccPccPPgtt,|,,ttgbbbbbbbbbbbbw",
	"wPPPPPPPPgtt,,,,ttgbbbbbbbbbbbbw",
	"wPPPPPPPPgtt,,,,ttgbbbbbbbbbbbbw",
	"wPPPPPPPPgLt,|,,tLgbbbbbbbbbbbbw",
	"wPccPPPPPgtt,|,,ttgbbbbbbbbbbbbw",
	"wPPPPPPPPgtt,,,,ttgbbbbbbbbbbbbw",
	"wKKKKKKKKgtt,,,,ttgbbbbbbbbbbbbw",
	"w########gtt,|,,ttghhhhhhhhhhhhw",
	"w########gtt,|,,ttg............w",
	"w########gtt,,,,ttgaaaaaaaaaaaaa",
	"w########gtt,,,,ttg............w",
	"w########gLt,|,,tLghhhhhhhhhhhhw",
	"w########gtt,|,,ttg============w",
	"w###G####gtt,,,,ttg============w",
	"w........gtt,,,,ttg============w",
	"wKKKKKKKKett,|,,ttg============w",
	"w########gtt,|,,ttg============w",
	"w########gtt,,,,ttg============w",
	"w########gtt,,,,ttg============w",
	"w########gLt,|,,tLg============w",
	"w###D####gtt,|,,ttg============w",
	"w........gtt,,,,ttg============w",
	"wwwwwwwwwwwww,wwwwwwwwwwwwwwwwww",
]



## 夜：駐車場の車が減り、ドラッグストアはシャッターを下ろす。8/1 の夕方以降は店先に澪が立つ
func _apply_time_of_day(time_of_day: String) -> void:
	var night: bool = time_of_day == Calendar.TIME_NIGHT or time_of_day == Calendar.TIME_EVENING
	for tile: Vector2i in NIGHT_REMOVED_CARS:
		if night:
			objects.erase_cell(tile)
		else:
			set_tile(objects, tile, OBJECT_LEGEND["c"])
	set_tile(objects, DRUG_DOOR_TILE, "シャッター（下・半開き）" if night else OBJECT_LEGEND["D"])
	_update_mio(night)


func _apply_day(_day: int) -> void:
	_update_mio(Calendar.time_of_day == Calendar.TIME_NIGHT or Calendar.time_of_day == Calendar.TIME_EVENING)


## 8/1 の夕方、店先に澪が立っている（初対面）。met_heroine が立てば消える
func _update_mio(night: bool) -> void:
	var should_stand: bool = Calendar.day == 1 and night and not GameState.has_flag("met_heroine")
	set_npc_present("mio_npc", should_stand, MIO_TILE, "heroine", Vector2i.LEFT)
