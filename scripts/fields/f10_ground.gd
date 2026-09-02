extends FieldBase
## F10 磐戸運動広場・河川敷。草の伸びたグラウンド、朽ちたバックネット、ナイター照明塔、堤防道路。
## 開けているが遮蔽物がなく、追跡者との相性が最も悪い（隠れられない）フィールドとして設計する。
## 8/20 以降、誰も引いていない白線がグラウンドを横切り、日ごとに堤防の向こうへ伸びる（_apply_day）。
## 出口：W→F13 (0,14)、N→F11 (10,0)、N→F14 (40,0)、S→F15 (12,31)。環境音 amb_ground

const GROUND_LEGEND: Dictionary = {
	"g": "草地（丈高・低）",
	".": "土のグラウンド",
	"s": "堤防斜面（草）",
	"r": "堤防道路",
	"c": "河原の石",
}
const OBJECT_LEGEND: Dictionary = {
	"w": "樹林（暗）",
	"k": "樹林（暗）",
	"B": "バックネット（金網）",
	"T": "照明塔",
	"W": "倉庫（トタン）",
	"d": "倉庫（トタン）",
	"D": "ダッグアウト",
	"b": "ベンチ",
	"p": "百葉箱",
	"q": "石柱",
	"m": "水位標",
}
const LINE_TYPE: String = "白線（土用）"
const LINE_X: int = 24
## 白線が伸びる段階：[day_min, y_from, y_to]。日が進むほど堤防の向こうへ続く
const LINE_STAGES: Array = [
	[20, 6, 21],   # グラウンドを横切る
	[21, 22, 25],  # 草地と堤防斜面へ
	[22, 26, 30],  # 堤防道路を越えて河原へ
]
## 夜に追跡者が現れる位置（グラウンド中央）
const STALKER_SPAWN_TILE: Vector2i = Vector2i(24, 14)
## 調べ物。テキストとフラグ操作は data/events.json（on_interact, target=id）
const INTERACTABLES: Array = [
	{"id": "shed", "name": "用具倉庫", "tile": Vector2i(44, 10), "kind": "object"},
	{"id": "dugout", "name": "ダッグアウト", "tile": Vector2i(11, 22), "kind": "object"},
	{"id": "panel", "name": "照明塔の配電盤", "tile": Vector2i(5, 23), "kind": "object"},
	{"id": "line_stake", "name": "白線の起点", "tile": Vector2i(24, 5), "kind": "object"},
	{"id": "marker", "name": "堤防の距離標", "tile": Vector2i(30, 26), "kind": "sign"},
	{"id": "backnet", "name": "バックネット", "tile": Vector2i(8, 6), "kind": "object"},
]
## 物体タイルの下地
const DEFAULT_GROUND: String = "草地（丈高・低）"
const MAP_ROWS: PackedStringArray = [
	"wwwwwwwwwwgwwwwwwwwwwwwwwwwwwwwwwwwwwwwwgwwwwwww",
	"wkkkkkkkkkgkkkkkkkkkkkkkkkkkkkkkkkkkkkkkgkkkkkkw",
	"wggggggggggggggggggggggggggggggggggggggggggggggw",
	"wggggggggggggggggggggggggggggggggggggggggggggggw",
	"wggggggggggggggggggggggggggggggggggggggggggggggw",
	"wgggTgggggggggggggggggggqggggggggggggggggggTgggw",
	"wgggggBBBBBB..............................gggggw",
	"wgggggB...................................gggggw",
	"wgggggB...................................gWWWWw",
	"wgggggB...................................gWWWWw",
	"wgggggB...................................ggdggw",
	"wgggggB...................................gggggw",
	"wggggg....................................gggggw",
	"wggggg....................................gggggw",
	"gggggg....................................gggggw",
	"wggggg....................................gggggw",
	"wggggg....................................gggggw",
	"wggggg....................................gggggw",
	"wggggg....................................gggggw",
	"wggggg....................................gggggw",
	"wggggg....................................gggggw",
	"wggggg....................................gggggw",
	"wgggTgggggDDDDgbbggggggggggggggggggggggggggTgggw",
	"wggggpgggggggggggggggggggggggggggggggggggggggggw",
	"wssssssssssssssssssssssssssssssssssssssssssssssw",
	"wssssssssssssssssssssssssssssssssssssssssssssssw",
	"wrrrrrrrrrrrrrrrrrrrrrrrrrrrrrmrrrrrrrrrrrrrrrrw",
	"wrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrw",
	"wccccccccccccccccccccccccccccccccccccccccccccccw",
	"wccccccccccccccccccccccccccccccccccccccccccccccw",
	"wccccccccccccccccccccccccccccccccccccccccccccccw",
	"wwwwwwwwwwwwcwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
]


## 倉庫・バックネットの下地はグラウンドの土、距離標は堤防道路
func _ground_under(x: int, y: int) -> String:
	var ch: String = MAP_ROWS[y][x]
	if ch == "B":
		return GROUND_LEGEND["."]
	if ch == "m":
		return GROUND_LEGEND["r"]
	return ""


## 8/20 以降、白線が日ごとに伸びる。土の上の白線は「白線（土用）」、草・斜面・河原の上は下地を変えず線だけ引く
func _apply_day(day: int) -> void:
	for stage: Array in LINE_STAGES:
		if day < int(stage[0]):
			continue
		for y: int in range(int(stage[1]), int(stage[2]) + 1):
			set_tile(ground, Vector2i(LINE_X, y), LINE_TYPE)
