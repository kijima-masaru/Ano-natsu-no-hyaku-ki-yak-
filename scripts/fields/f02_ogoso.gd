extends FieldBase
## F02 於御所住宅地。昭和の建売と古い浄土宗の庵。**親友・日向蓮の家がここにある。**
## 生活感の残留を表現する主戦場。死の場面は一切描かず、事後の空白としてのみ扱う（docs/CONTENT_NOTICE.md）。
## 出口：S→F01 (10,31)、S→F06 (36,31)、E→F03 (47,20)

const GROUND_LEGEND: Dictionary = {
	"r": "生活道路アスファルト（細）",
	"-": "旧街道アスファルト（狭）",
	"g": "側溝",
	"a": "生活道路アスファルト（細）",
	"n": "公園の砂地",
}
const OBJECT_LEGEND: Dictionary = {
	"w": "ブロック塀",
	"=": "建売住宅の壁・屋根（瓦）",
	"H": "旧校舎 外壁（下見板）",
	"d": "店舗の木製戸",
	"W": "窓（消灯・点灯）",
	"Y": "物干し",
	"F": "門扉",
	"~": "法面コンクリート（格子）",
	"A": "庵の板壁と瓦",
	"R": "瓦屋根（連続）",
	"h": "生垣",
	"b": "ブランコ・砂場",
	"N": "ゴミ集積所ネット",
	"K": "掲示板",
	"L": "街灯（柱・光源）",
	"e": "電柱・電線",
	"M": "集合ポスト",
}
## 夜：蓮の部屋の窓だけが点いている（誰もいないのに）。8/8 以降は消える
const REN_WINDOW: Vector2i = Vector2i(19, 13)
const INTERACTABLES: Array = [
	{"id": "ren_door", "name": "蓮の家", "tile": Vector2i(17, 13), "kind": "object"},
	{"id": "ren_window", "name": "蓮の部屋の窓", "tile": Vector2i(19, 13), "kind": "object"},
	{"id": "laundry", "name": "物干し", "tile": Vector2i(22, 7), "kind": "object"},
	{"id": "mailbox_ren", "name": "郵便受け", "tile": Vector2i(16, 13), "kind": "object"},
	{"id": "nameplate", "name": "表札", "tile": Vector2i(5, 13), "kind": "object"},
	{"id": "mailbox_a", "name": "郵便受け", "tile": Vector2i(3, 13), "kind": "object"},
	{"id": "hermitage", "name": "庵", "tile": Vector2i(42, 12), "kind": "object"},
	{"id": "park_swing", "name": "ブランコ", "tile": Vector2i(15, 20), "kind": "object"},
	{"id": "trash_net", "name": "ゴミ集積所", "tile": Vector2i(24, 17), "kind": "object"},
	{"id": "kairanban", "name": "回覧板", "tile": Vector2i(12, 17), "kind": "sign"},
	{"id": "slope", "name": "高速の法面", "tile": Vector2i(39, 3), "kind": "object"},
]
## 物体タイルの下地
const DEFAULT_GROUND: String = "生活道路アスファルト（細）"
const MAP_ROWS: PackedStringArray = [
	"wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
	"w========rrr=======================---a~~~~~~~~w",
	"w========rrr=======================---a~~~~~~~~w",
	"w========rrr=======================---a~~~~~~~~w",
	"w========rrr=========aa============---aRRRRRRRaw",
	"w========rrr=========aa============---aAAAAAAAaw",
	"w========rrr=========aa============---aAAAAAAAaw",
	"w========rrr=========aY============---aAAAAAAAaw",
	"w========rrr=========aa============---aAAAAAAAaw",
	"w========rrr=========aa============---aAAAAAAAaw",
	"w========rrr=========aa============---aAAAAAAAaw",
	"w========rrr=========aa============---aAAAAAAAaw",
	"w========rrr=========aa============---aAAAdAAAaw",
	"wwwMwFwwwrrr=HHHMdHWHaa=wwwwwwwwww=---aaaaaaaaaw",
	"wgeggggggggggggggggggggggeggggggggggggggggggeggw",
	"wrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr---rrrrrrrrrw",
	"wrrrLrrrrrrrrrrrrrrrLrrrrrrrrrLrrrr---rrrrLrrrrw",
	"wwwwwwwwwrrrKhhhhnhhhh==N=wwwwwwww=---=========w",
	"w========rrr=hnnnnnnnh=============---=========w",
	"w========rrr=hnnnnnnnh=============---=========w",
	"w========rrr=hnbnnbnnh=============---rrrrrrrrrr",
	"w========rrr=hnnnnnnnh=============---=========w",
	"w========rrr=hnnnnnnnh=============---=========w",
	"w========rrr=hhhhhhhhh=============---=========w",
	"wrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr---rrrrrrrrrw",
	"wrrrrrrLrrrrrrrrrrrrrrrrrrrrLrrrrrr---rrrrrrrrrw",
	"wggggggggggggggggggggggggggggggggggggggggggggggw",
	"wwwwwwwwwrrr=wwwwwwwwwwwwwwwwwwwww=---=wwwwwwwww",
	"w========rrr=======================---=========w",
	"w========rrr=======================---=========w",
	"w========rrr=======================---=========w",
	"wwwwwwwwwwrwwwwwwwwwwwwwwwwwwwwwwwww-wwwwwwwwwww",
]


## 夜、蓮の部屋の窓だけが点く。初七日（8/8）を過ぎると点かなくなる
func _apply_time_of_day(time_of_day: String) -> void:
	var night: bool = time_of_day == Calendar.TIME_NIGHT or time_of_day == Calendar.TIME_EVENING
	var lit: bool = night and Calendar.day < 8
	set_tile(objects, REN_WINDOW, "階段室（点灯・消灯）" if lit else OBJECT_LEGEND["W"])


func _apply_day(_day: int) -> void:
	_apply_time_of_day(Calendar.time_of_day)
