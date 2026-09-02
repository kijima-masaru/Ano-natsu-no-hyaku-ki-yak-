extends FieldBase
## F15 蒼籠川 河畔・御渡橋。町の南限。ここから先へは出られない。
## 「出られない」ことを超常ではなく生活の理屈で示す（工事中・台風・終バス・親の心配）。理由は日ごとに変わる。
## 橋の中ほどまで行くと、向こう岸から自分と同じ歩調の足音が近づく。対岸は常に霧。終幕（8/30〜31）の場。
## 出口：N→F13 (5,0)、N→F10 (53,0)。環境音 amb_river

const GROUND_LEGEND: Dictionary = {
	"r": "堤防道路",
	"s": "堤防斜面（草）",
	"c": "河原の石",
	"B": "橋（桁・欄干・橋灯）",
}
const OBJECT_LEGEND: Dictionary = {
	"w": "樹林（暗）",
	"~": "水面（流れ）",
	"X": "バリケード",
	"T": "桜（葉・裸）",
	"b": "ベンチ",
	"L": "街灯（柱・光源）",
	"m": "石碑",
	"v": "水位標",
	"R": "苔むした石",
}
const FOG_TYPE: String = "霧（半透明オーバーレイ）"
## 対岸の霧：常に橋の向こう（y ≥ FOG_FROM_Y）を覆う。夜と 8/26 以降は手前まで来る
const FOG_FROM_Y: int = 18
const FOG_NEAR_Y: int = 14
const FOG_NEAR_DAY: int = 26
## 調べ物。テキストとフラグ操作は data/events.json（on_interact, target=id）
const INTERACTABLES: Array = [
	{"id": "stele", "name": "渡し場跡の石碑", "tile": Vector2i(12, 8), "kind": "sign"},
	{"id": "barricade", "name": "橋のバリケード", "tile": Vector2i(31, 16), "kind": "object"},
	{"id": "gauge", "name": "水位標", "tile": Vector2i(40, 12), "kind": "sign"},
	{"id": "driftwood", "name": "流れ着いた物", "tile": Vector2i(48, 11), "kind": "object"},
	{"id": "bench", "name": "桜並木のベンチ", "tile": Vector2i(20, 2), "kind": "object"},
]
## 物体タイルの下地
const DEFAULT_GROUND: String = "河原の石"
const MAP_ROWS: PackedStringArray = [
	"wwwwwrwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwrwwwwwwwwww",
	"wrrTrrrTrrrTrrrTrrrTrrrTrrrTrrBBBBrTrrrTrrrTrrrTrrrTrrrTrrrTrrrw",
	"wrrrrrrrrrrrrrrrrrrrbrrrrrrrrrBBBBrrrrrrrrrrrrrrrrrrrrrrrrrrrrrw",
	"wrrrrrrrrrrrrrrrrrrrrrrrrrrrrrBBBBrrrrrrrrrrrrrrrrrrrrrrrrrrrrrw",
	"wsssssssssssssssssssssssssssssBBBBsssssssssssssssssssssssssssssw",
	"wsssssssssssssssssssssssssssssBBBBsssssssssssssssssssssssssssssw",
	"wsssssssssssssssssssssssssssssBBBBsssssssssssssssssssssssssssssw",
	"wcccccccccccccccccccccccccccccBBBBcccccccccccccccccccccccccccccw",
	"wcccccccccccmcccccccccccccccccBBBBcccccccccccccccccccccccccccccw",
	"wcccccccccccccccccccccccccccccBBBBcccccccccccccccccccccccccccccw",
	"wccccccccccccccccccccccccccccLBBBBLccccccccccccccccccccccccccccw",
	"wcccccccccccccccccccccccccccccBBBBccccccccccccccRccccccccccccccw",
	"wcccccccccccccccccccccccccccccBBBBccccccvccccccccccccccccccccccw",
	"w~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBB~~~~~~~~~~~~~~~~~~~~~~~~~~~~~w",
	"w~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBB~~~~~~~~~~~~~~~~~~~~~~~~~~~~~w",
	"w~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBB~~~~~~~~~~~~~~~~~~~~~~~~~~~~~w",
	"w~~~~~~~~~~~~~~~~~~~~~~~~~~~~~XXXX~~~~~~~~~~~~~~~~~~~~~~~~~~~~~w",
	"w~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBB~~~~~~~~~~~~~~~~~~~~~~~~~~~~~w",
	"w~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBB~~~~~~~~~~~~~~~~~~~~~~~~~~~~~w",
	"w~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBB~~~~~~~~~~~~~~~~~~~~~~~~~~~~~w",
	"w~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBB~~~~~~~~~~~~~~~~~~~~~~~~~~~~~w",
	"w~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBB~~~~~~~~~~~~~~~~~~~~~~~~~~~~~w",
	"w~~~~~~~~~~~~~~~~~~~~~~~~~~~~~BBBB~~~~~~~~~~~~~~~~~~~~~~~~~~~~~w",
	"wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
]


## 水面と柵の下地は水面ではなく橋・河原。桜とベンチは堤防道路、水位標と岩は河原
func _ground_under(x: int, y: int) -> String:
	var ch: String = MAP_ROWS[y][x]
	if ch == "X":
		return GROUND_LEGEND["B"]
	if ch == "T" or ch == "b" or ch == "w":
		return GROUND_LEGEND["r"]
	return ""


## 霧：対岸は常に。夜と 8/26 以降は橋の中ほどまで来る
func _apply_time_of_day(time_of_day: String) -> void:
	var near: bool = time_of_day == Calendar.TIME_NIGHT or Calendar.day >= FOG_NEAR_DAY
	var from_y: int = FOG_NEAR_Y if near else FOG_FROM_Y
	for y: int in MAP_ROWS.size():
		for x: int in MAP_ROWS[y].length():
			var ch: String = MAP_ROWS[y][x]
			if ch != "~" and ch != "B" and ch != "X":
				continue
			if y >= from_y:
				set_tile(overhead, Vector2i(x, y), FOG_TYPE)
			else:
				overhead.erase_cell(Vector2i(x, y))


func _apply_day(_day: int) -> void:
	_apply_time_of_day(Calendar.time_of_day)
