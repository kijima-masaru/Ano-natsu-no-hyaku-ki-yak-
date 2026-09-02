extends FieldBase
## F11 磐戸第一小学校。中核ダンジョン。木造の旧校舎が一棟だけ取り壊されずに残っている。
## 屋外（校庭・新校舎・体育館・飼育小屋・百葉箱）と、旧校舎の 1 階・2 階（FLOORS）の 3 つの地図を持つ。
## 主人公と親友とヒロインの共通の記憶の場所。ここに置かれた思い出は、真相版ですべて意味が反転する。
## 本作最大の隠蔽対象（C-17 タイムカプセルの手紙）は 2 階ではなく 1 階の図工室にある。
## 8/19：新校舎の職員室で鍵 → 旧校舎 1 階（old_school_opened）。追跡者が校内に。8/21 以降に 2 階が開く。
## 出口：N→F07 (22,0)、W→F12 (0,18)、S→F13 (12,39)、S→F10 (34,39)、E→F14 (47,20)。環境音 amb_school

const GROUND_LEGEND: Dictionary = {
	".": "校庭の土",
	"l": "白線（土用）",
}
const OBJECT_LEGEND: Dictionary = {
	"w": "生垣",
	"G": "校門（鉄）",
	"T": "新校舎 外壁（タイル）",
	"D": "ガラス扉（点灯）",
	"F": "蛍光灯",
	"p": "石柱",
	"A": "朝礼台",
	"B": "体育館の壁",
	"d": "店舗の木製戸",
	"O": "旧校舎 外壁（下見板）",
	"X": "旧校舎 窓（木枠）",
	"E": "店舗の木製戸",
	"k": "飼育小屋（金網）",
	"b": "百葉箱",
	"t": "植栽（低木）",
}
## 屋内の凡例（旧校舎 1 階・2 階で共通）
const INDOOR_GROUND: Dictionary = {
	"=": "旧校舎 廊下床（板）",
	"-": "旧校舎 廊下床（板）",
	"S": "石段（長・手すり）",
}
const INDOOR_OBJECTS: Dictionary = {
	"#": "旧校舎 外壁（下見板）",
	"W": "旧校舎 窓（木枠）",
	"K": "黒板",
	"M": "教室の机・椅子",
	"E": "店舗の木製戸",
	"L": "非常灯",
}
const INDOOR_DEFAULT_GROUND: String = "旧校舎 廊下床（板）"
## 旧校舎 1 階：保健室・一年教室・図工室・宿直室。昇降口 (2,10)、階段 (36..37, 9..10)
const ROWS_1F: PackedStringArray = [
	"########################################",
	"##WWWWWWWW#WWWWWWWW#WWWWWWWWWW#WWWWWWWW#",
	"##-K------#-K------#-K--------#-K------#",
	"##--------#--------#----------#--------#",
	"##--M-M---#--M-M---#--M-M-M---#--M-M---#",
	"##--------#--------#----------#--------#",
	"##--M-M---#--M-M---#--M-M-M---#--M-M---#",
	"#====-========-=========-=========-====#",
	"#======================================#",
	"##=###W###W###W###W#L#W###W###W###W#SS##",
	"##E#################################SS##",
	"########################################",
]
const POI_1F: Array = [
	{"id": "entrance_in", "name": "昇降口", "tile": Vector2i(2, 10), "kind": "object"},
	{"id": "health_bed", "name": "保健室のベッド", "tile": Vector2i(4, 4), "kind": "object"},
	{"id": "class1_board", "name": "一年教室の黒板", "tile": Vector2i(12, 2), "kind": "object"},
	{"id": "art_shelf", "name": "図工室の作品棚", "tile": Vector2i(22, 4), "kind": "object"},
	{"id": "night_journal", "name": "宿直室の日誌", "tile": Vector2i(33, 4), "kind": "object"},
	{"id": "stairs_up_1f", "name": "階段（二階へ）", "tile": Vector2i(36, 9), "kind": "object"},
]
## 旧校舎 2 階：四年・五年・六年教室・図書室。階段 (36..37, 9..10)
const ROWS_2F: PackedStringArray = [
	"########################################",
	"##WWWWWWWW#WWWWWWWW#WWWWWWWWWW#WWWWWWWW#",
	"##-K------#-K------#-K--------#-K------#",
	"##--------#--------#----------#--------#",
	"##--M-M---#--M-M---#--M-M-M---#--M-M---#",
	"##--------#--------#----------#--------#",
	"##--M-M---#--M-M---#--M-M-M---#--M-M---#",
	"#====-========-=========-=========-====#",
	"#======================================#",
	"##W###W###W###W###W#L#W###W###W###W#SS##",
	"####################################SS##",
	"########################################",
]
const POI_2F: Array = [
	{"id": "class4_board", "name": "四年教室の黒板", "tile": Vector2i(3, 2), "kind": "object"},
	{"id": "class5_board", "name": "五年教室の黒板", "tile": Vector2i(12, 2), "kind": "object"},
	{"id": "class6_board", "name": "六年教室の黒板", "tile": Vector2i(21, 2), "kind": "object"},
	{"id": "class6_desk", "name": "六年教室の机", "tile": Vector2i(23, 4), "kind": "object"},
	{"id": "library_shelf", "name": "図書室の棚", "tile": Vector2i(33, 4), "kind": "object"},
	{"id": "stairs_down_2f", "name": "階段（一階へ）", "tile": Vector2i(36, 9), "kind": "object"},
]
## 屋内の階（FieldFloors）
const FLOORS: Dictionary = {
	"1f": {"rows": ROWS_1F, "ground": INDOOR_GROUND, "objects": INDOOR_OBJECTS, "default_ground": INDOOR_DEFAULT_GROUND, "interactables": POI_1F},
	"2f": {"rows": ROWS_2F, "ground": INDOOR_GROUND, "objects": INDOOR_OBJECTS, "default_ground": INDOOR_DEFAULT_GROUND, "interactables": POI_2F},
}
## 屋外の調べ物。テキストとフラグ操作は data/events.json（on_interact, target=id）
const INTERACTABLES: Array = [
	{"id": "staff_room", "name": "新校舎 職員室", "tile": Vector2i(24, 8), "kind": "object"},
	{"id": "old_entrance", "name": "旧校舎の昇降口", "tile": Vector2i(36, 20), "kind": "object"},
	{"id": "pedestal", "name": "像の台座", "tile": Vector2i(14, 11), "kind": "object"},
	{"id": "platform", "name": "朝礼台", "tile": Vector2i(24, 14), "kind": "object"},
	{"id": "gym_door", "name": "体育館", "tile": Vector2i(7, 24), "kind": "object"},
	{"id": "hutch", "name": "飼育小屋", "tile": Vector2i(5, 13), "kind": "object"},
	{"id": "weather_box", "name": "百葉箱", "tile": Vector2i(9, 14), "kind": "object"},
]
## 物体タイルの下地（屋外）
const DEFAULT_GROUND: String = "校庭の土"
const MAP_ROWS: PackedStringArray = [
	"wwwwwwwwwwwwwwwwwwwwww.wwwwwwwwwwwwwwwwwwwwwwwww",
	"wGGGGGGGGGGGGGGGGGGGGG.GGGGGGGGGGGGGGGGGGGGGGGGw",
	"wG............................................Gw",
	"wG......TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT.....Gw",
	"wG......TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT.....Gw",
	"wG......TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT.....Gw",
	"wG......TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT.....Gw",
	"wG......TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT.....Gw",
	"wG......TTTTTTTTFTTTTTTTDTTTTTTTFTTTTTTTT.....Gw",
	"wG............................................Gw",
	"wG............................................Gw",
	"wG............p...............................Gw",
	"wG..kkk.......................................Gw",
	"wG..kkk.......................................Gw",
	"wG.......b..............A...........OOOOOOOOO.Gw",
	"wG..................................OOOOOOOOO.Gw",
	"wG..................................XOOOOOOOO.Gw",
	"wG..................................OOOOOOOOO.Gw",
	"..............lllllllllllllllll.....XOOOOOOOO.Gw",
	"wG..................................OOOOOOOOO.Gw",
	"wG..................................EOOOOOOOO...",
	"wG..................................OOOOOOOOO.Gw",
	"wG..................................XOOOOOOOO.Gw",
	"wG..................................OOOOOOOOO.Gw",
	"wG.BBBBdBBBB........................XOOOOOOOO.Gw",
	"wG.BBBBBBBBB........................OOOOOOOOO.Gw",
	"wG.BBBBBBBBB........................OOOOOOOOO.Gw",
	"wG.BBBBBBBBB..................................Gw",
	"wG.BBBBBBBBB..................................Gw",
	"wG.BBBBBBBBB..................................Gw",
	"wG.BBBBBBBBB..lllllllllllllllll...............Gw",
	"wG.BBBBBBBBB..................................Gw",
	"wG.BBBBBBBBB..................................Gw",
	"wG.BBBBBBBBB..................................Gw",
	"wG............................................Gw",
	"wG............................................Gw",
	"wG..........t.....t.....t.....t...............Gw",
	"wG............................................Gw",
	"wGGGGGGGGGGG.GGGGGGGGGGGGGGGGGGGGG.GGGGGGGGGGGGw",
	"wwwwwwwwwwww.wwwwwwwwwwwwwwwwwwwww.wwwwwwwwwwwww",
]
## 新校舎の窓明かり（ガラス扉・蛍光灯）は平日の昼だけ。夏休みなので職員室だけが点く
const OFFICE_LIGHT_TILES: Array = [Vector2i(24, 8)]
const OFFICE_LIGHT_OFF: String = "窓（消灯・点灯）"


## 屋内では廊下床、屋外では校庭の土
func _ground_under(_x: int, _y: int) -> String:
	if current_floor != FieldFloors.OUTSIDE:
		return INDOOR_DEFAULT_GROUND
	return ""


## 職員室の灯りは朝・昼だけ。夜の校舎は非常灯以外が消える
func _apply_time_of_day(time_of_day: String) -> void:
	if current_floor != FieldFloors.OUTSIDE:
		return
	var daytime: bool = time_of_day == Calendar.TIME_MORNING or time_of_day == Calendar.TIME_NOON
	for tile: Vector2i in OFFICE_LIGHT_TILES:
		set_tile(objects, tile, OBJECT_LEGEND["D"] if daytime else OFFICE_LIGHT_OFF)
