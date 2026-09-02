extends FieldBase
## F06 磐戸市民センター・交番前広場。最初の実フィールド。セーブ／情報ハブ。
## レイアウトは ASCII の地図（MAP_ROWS、40×32）と凡例から _build() で組み立てる。
## エディタで .tscn に焼き込むより差分レビューがしやすいため、ステップ2ではこの方式を採る。
## 出口タイルは data/fields.json の F06.exits と一致させている（W:0,13 N:10,0 N:27,0 S:5,31 S:30,31）。

const FIELD_ID: String = "F06"

## 地面（通行可）の凡例
const GROUND_LEGEND: Dictionary = {
	".": "広場の敷石（インターロッキング）",
	",": "アスファルト",
	"-": "旧街道アスファルト（狭）",
	"S": "法面階段",
	"g": "側溝",
}
## Objects 層（通行不可）の凡例。地面は既定で広場の敷石（DEFAULT_GROUND）
const OBJECT_LEGEND: Dictionary = {
	"w": "ブロック塀",
	"h": "生垣",
	"~": "法面コンクリート（格子）",
	"#": "公共建築の壁（タイル）",
	"G": "ガラス扉（点灯）",
	"=": "瓦屋根（連続）",
	"C": "時計塔",
	"B": "掲示板",
	"M": "看板（地図）",
	"T": "公衆電話ボックス",
	"b": "ベンチ",
	"p": "植栽（低木）",
	"c": "自転車置き場",
	"L": "街灯（柱・光源）",
	"e": "電柱・電線",
}
## Overhead 層（プレイヤーより手前）：[タイル座標, 種別]
const OVERHEAD_TILES: Array = [
	[Vector2i(20, 15), "時計塔"],
	[Vector2i(30, 5), "交番の赤色灯"],
]
## 調べ物：id, 表示名, タイル, 種類。テキストとフラグ操作は data/events.json（on_interact, target=id）
const INTERACTABLES: Array = [
	{"id": "library", "name": "図書室", "tile": Vector2i(18, 10), "kind": "object"},
	{"id": "lost_and_found", "name": "遺失物箱", "tile": Vector2i(22, 10), "kind": "object"},
	{"id": "police_log", "name": "交番", "tile": Vector2i(30, 10), "kind": "object"},
	{"id": "bulletin", "name": "掲示板", "tile": Vector2i(14, 12), "kind": "sign"},
	{"id": "map_sign", "name": "町の地図", "tile": Vector2i(8, 15), "kind": "sign"},
	{"id": "phone", "name": "公衆電話", "tile": Vector2i(34, 12), "kind": "save_point"},
	{"id": "clock", "name": "時計塔", "tile": Vector2i(20, 16), "kind": "object"},
	{"id": "slope_notice", "name": "法面階段の張り紙", "tile": Vector2i(28, 2), "kind": "sign"},
]
## 40 列 × 32 行。行が y、列が x
## 物体タイルの下地
const DEFAULT_GROUND: String = "広場の敷石（インターロッキング）"
const MAP_ROWS: PackedStringArray = [
	"wwwwwwwwww-wwwwwwwww~~~~~~~S~~~~~~~~~~~~",
	"whhhhhhhg--g========~~~~~~~S~~~~~~~~~~~~",
	"w=======g--ghhhhhhhhhhhhh~~S~~~~~~~~~~~~",
	"w=======g--g#############hhShhhhhhhhhhhh",
	"w=======e--g#############...===========w",
	"w=======g--g#############...===========w",
	"w=======g--g#############...#####======w",
	"w=======g--g#############...#####======w",
	"w=======e--g#############...#####======w",
	"w=======g--g#############...#####======w",
	"w=======g--g######G###G##...##G##======w",
	"wgggggg.............................===w",
	"w,L,,,,....L.pB...........p...L...T.===w",
	",,,,,,,.............................===w",
	"wgggggg.............................===w",
	"whhhhhh.M...........................===w",
	"w======.............C...............===w",
	"w======..........................p..===w",
	"w======.............................===w",
	"w======.....p...b.......b...p.......===w",
	"w======.............b............ccc===w",
	"w======....Lp...............p.L.....===w",
	"whhh=--.......................,,....===w",
	"whheg--ghhhhhhhhhhhhhhhhhhhhhw,,whhhehhw",
	"whhhg--g=====================w,,w======w",
	"whhhg-Lg=====================w,,w======w",
	"whhhg--g=====================w,Lw======w",
	"whhhg--g=====================w,,w======w",
	"whhhg--g=====================w,,w======w",
	"whhhg--g=====================w,,w======w",
	"whhhg--g=====================w,,w======w",
	"wwwww-wwwwwwwwwwwwwwwwwwwwwwww,wwwwwwwww",
]
