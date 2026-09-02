extends FieldBase
## F07 光明院 門前。室町期創建の寺。本堂は戦国期に焼け、観音堂一棟だけが残っている。古い墓域。
## 「焼け残った一棟」を本作の主題（残されたもの）と響かせる。F08（天神社）への唯一の石段がここにある。
## 8/15 盆：観音堂の灯明。澪が初めて単独行動（同行 OFF）。ナツ「ひとりのほうが、楽だね」。
## 出口：W→F05 (0,20)、N→F06 (12,0)、S→F11 (22,35)、E→F08 (47,12 石段の登り口)。環境音 amb_temple

const GROUND_LEGEND: Dictionary = {
	"p": "石畳",
	"-": "生活道路アスファルト（細）",
	"g": "苔",
	"j": "境内の砂利",
	"f": "礎石",
	"S": "石段（登り口）",
}
const OBJECT_LEGEND: Dictionary = {
	"w": "杉林（暗）",
	"k": "杉林（暗）",
	"W": "土塀（漆喰・崩れ）",
	"G": "山門（木・瓦）",
	"K": "観音堂の板壁・格子・屋根",
	"X": "観音堂の板壁・格子・屋根",
	"L": "石柱",
	"n": "案内板",
	"h": "苔むした石",
	"r": "苔むした石",
	"m": "墓石（複数形）",
	"u": "苔むした石",
	"I": "イチョウ（大木）",
}
## 灯明：8/15 以降の夕・夜だけ常夜灯が点く（誰が点けたのかは語らない）
const LAMP_TILES: Array = [Vector2i(31, 11), Vector2i(31, 16)]
const LAMP_LIT: String = "常夜灯"
const LAMP_DAY_FIRST: int = 15
## 調べ物。テキストとフラグ操作は data/events.json（on_interact, target=id）
const INTERACTABLES: Array = [
	{"id": "kannon_lattice", "name": "観音堂の格子", "tile": Vector2i(33, 14), "kind": "object"},
	{"id": "foundation", "name": "本堂の礎石", "tile": Vector2i(23, 16), "kind": "object"},
	{"id": "muen_grave", "name": "無縁墓", "tile": Vector2i(10, 24), "kind": "object"},
	{"id": "history_board", "name": "寺の由来書き", "tile": Vector2i(9, 10), "kind": "sign"},
	{"id": "basin", "name": "手水鉢", "tile": Vector2i(15, 11), "kind": "object"},
	{"id": "ginkgo", "name": "イチョウの幹", "tile": Vector2i(30, 25), "kind": "object"},
]
## 物体タイルの下地
const DEFAULT_GROUND: String = "境内の砂利"
const MAP_ROWS: PackedStringArray = [
	"wwwwwwwwwwwwpwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
	"wg------------kkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkw",
	"wg---gkkkkkpppkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkw",
	"wg---gkkkkkpppkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkw",
	"wg---gkkkkkpppkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkw",
	"wg---gkkkkkpppkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkw",
	"wg---gkkkkkpppkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkw",
	"wg---gkkkkkpppkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkw",
	"wg---gWWWWWGpGWWWWWWWWWWWWWWWWWWWWWWWWWWWWkkkkkw",
	"wg---gWjjjjjpjjjjjjjjjjjjjjjjjjjjjjjjjjjjWkkkkkw",
	"wg---gWjjnjjpjjjjjjjjjjjjjjjjjjjjjjjjjjjjWkkkkkw",
	"wg---gWjjjjjpjjhjjjjjjjjjjjjjjjLjKKKKKKjjWkkkkkw",
	"wg---gWjjjjjpjjjjjjjjjjjjjjjjjjppKKKKKKjjpSSSSSS",
	"wg---gWjjjjjpjjjjjffffffffffffjpjKKKKKKjjWkkkkkw",
	"wg---gWjjjjjpjjjjjffffffffffffjppXKKKKKjjWkkkkkw",
	"wg---gWjjjjjpjjjjjffffffffffffjpjKKKKKKjjWkkkkkw",
	"wg---gWjjjjjpjjjjjfffffrrfffffjLjKKKKKKjjWkkkkkw",
	"wg---gWjjjjjpjjjujffffffffffffjjjjjjjjjjjWkkkkkw",
	"wg---gWjjjjjpjjjjjffffffffffffjjjjjjjjjjjWkkkkkw",
	"w-----WjjjjjpjjjjjffffffffffffjjjjjjjjjjjWkkkkkw",
	"------WjjjjjppppppppppppppppppppjjjjjjjjjWkkkkkw",
	"w-----WjjjjjjjjjjjjjjjpjjjjjjjjjjjjjjjjjjWkkkkkw",
	"wkkkkkWjjjjjjjjjjjjjjjpjjjjjjjjjjjjjujjjjWkkkkkw",
	"wkkkkkWjjmjmjmjmjjjjjjpjjjjjjjjjjjjjjjjjjWkkkkkw",
	"wkkkkkWjjjujjjjjjjjjjjpjjjjjjjIIjjjjjjjjjWkkkkkw",
	"wkkkkkWjjmjmjmjmjjjjjjpjjjjjjjIIjjjjjjjjjWkkkkkw",
	"wkkkkkWjjjjjjjjjjjjjjjpjjjjjjjjjjjjjjjujjWkkkkkw",
	"wkkkkkWjjmjmjmjmjjjjjjpjjjjjjjjjjjjjjjjjjWkkkkkw",
	"wkkkkkWjjjjjjjjjjjjjjjpjjjjjjjjjjjjjjjjjjWkkkkkw",
	"wkkkkkWjjjjjjjjjjjjjjjpjjjjjjjjjjjjjjjjjjWkkkkkw",
	"wkkkkkWWWWWWWWWWWWWWWWpWWWWWWWWWWWWWWWWWWWkkkkkw",
	"wkkkkkkkkkkkkkkkkkkkkpppkkkkkkkkkkkkkkkkkkkkkkkw",
	"wkkkkkkkkkkkkkkkkkkkkpppkkkkkkkkkkkkkkkkkkkkkkkw",
	"wkkkkkkkkkkkkkkkkkkkkpppkkkkkkkkkkkkkkkkkkkkkkkw",
	"wkkkkkkkkkkkkkkkkkkkkpppkkkkkkkkkkkkkkkkkkkkkkkw",
	"wwwwwwwwwwwwwwwwwwwwwwpwwwwwwwwwwwwwwwwwwwwwwwww",
]


## 杉林の下地は苔、山門の下地は石畳
func _ground_under(x: int, y: int) -> String:
	var ch: String = MAP_ROWS[y][x]
	if ch == "k" or ch == "w":
		return GROUND_LEGEND["g"]
	if ch == "G":
		return GROUND_LEGEND["p"]
	return ""


## 灯明は盆（8/15）以降の夕・夜だけ点く
func _apply_time_of_day(time_of_day: String) -> void:
	var dusk: bool = time_of_day == Calendar.TIME_EVENING or time_of_day == Calendar.TIME_NIGHT
	var lit: bool = dusk and Calendar.day >= LAMP_DAY_FIRST
	for tile: Vector2i in LAMP_TILES:
		set_tile(objects, tile, LAMP_LIT if lit else OBJECT_LEGEND["L"])


func _apply_day(_day: int) -> void:
	_apply_time_of_day(Calendar.time_of_day)
