extends FieldBase
## F08 臥牛山 天神社。長い石段、約 400 本の梅林（8 月なので裸。迷路として使う）、撫で牛、拝殿と本殿、
## 節分の鬼の神事の面掛け所、町を見下ろす展望所。町の最高所（elevation 5）。
## 展望所から見る町に、実際には無い明かりが一つ点いている。鬼の面が一枚足りない（証拠 oni_masks）。
## 出口：W→F07 (0,16) のみ。環境音 amb_shrine

const GROUND_LEGEND: Dictionary = {
	"S": "石段（長・手すり）",
	"s": "境内の砂利",
	"u": "獣道（踏み分け）",
	"v": "石畳",
}
const OBJECT_LEGEND: Dictionary = {
	"w": "山の斜面（樹林）",
	"k": "山の斜面（樹林）",
	"T": "鳥居",
	"H": "社殿の壁・屋根（檜皮）",
	"Y": "玉垣",
	"C": "石像（牛）",
	"E": "絵馬掛け",
	"B": "百葉箱",
	"M": "厨子",
	"L": "常夜灯",
	"U": "梅の木（開花・裸）",
	"h": "式内社の社殿・鳥居",
	"F": "展望所の柵",
}
## 展望所の灯り：夜だけ現れる常夜灯（昼は無い。誰が点けたのかは語らない）
const LOOKOUT_LAMP_TILE: Vector2i = Vector2i(31, 45)
## 調べ物。テキストとフラグ操作は data/events.json（on_interact, target=id）
const INTERACTABLES: Array = [
	{"id": "cow", "name": "撫で牛", "tile": Vector2i(9, 4), "kind": "object"},
	{"id": "ema", "name": "絵馬掛け", "tile": Vector2i(19, 4), "kind": "object"},
	{"id": "haiden", "name": "拝殿", "tile": Vector2i(14, 6), "kind": "object"},
	{"id": "basin", "name": "手水舎", "tile": Vector2i(10, 9), "kind": "object"},
	{"id": "mask_box", "name": "面掛け所の保管箱", "tile": Vector2i(19, 9), "kind": "object"},
	{"id": "small_shrine", "name": "梅林の祠", "tile": Vector2i(24, 27), "kind": "object"},
	{"id": "lookout", "name": "展望所", "tile": Vector2i(33, 46), "kind": "sign"},
]
## 物体タイルの下地
const DEFAULT_GROUND: String = "境内の砂利"
const MAP_ROWS: PackedStringArray = [
	"wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkw",
	"wkkssssssssssHHHHsssskkkkkkkkkkkkkkkkkkw",
	"wkkksTSsssssssssssssskkkkkkkkkkkkkkkkkkw",
	"wkkkkSSksCssHHHHHHsEskkkkkkkkkkkkkkkkkkw",
	"wkkkkSSkssssHHHHHHssskkkkkkkkkkkkkkkkkkw",
	"wkkkkSSkssssHHHHHHssskkkkkkkkkkkkkkkkkkw",
	"wkkkkSSkssYYssssssYYskkkkkkkkkkkkkkkkkkw",
	"wkkkkSSkssssLssssLssskkkkkkkkkkkkkkkkkkw",
	"wkkkkSSkssBssssssssMskkkkkkkkkkkkkkkkkkw",
	"wkkkkSSkssssssssssssskkkkkkkkkkkkkkkkkkw",
	"wkkkkSSkkukkkkkkkkkkkkkkkkkkkkkkkkkkkkkw",
	"wkkkkSSkUuUUUUUUUUUUUUUUUUUUUUUUUUUUUUkw",
	"wkkkkSSkUuuuUuuuUuuuuuuuuuUuuuuuuuuuUUkw",
	"wkkkkSSkUUUuUuUuUuUUUUUuUuUuUUUUUuUuUUkw",
	"wSSSSSSkUuuuUuUuuuUuuuUuUuuuuuUuuuUuUUkw",
	"SSSSSSSkUuUUUUUUUUUuUuUUUUUUUUUuUUUuUUkw",
	"wSSSSSSkUuuuuuuuuuuuUuuuUuuuuuUuuuUuUUkw",
	"wkkkkkkkUUUUUUUUUUUUUUUuUuUUUuUUUuUuUUkw",
	"wkkkkkkkUuuuuuuuuuuuUuuuUuUuUuUuuuUuUUkw",
	"wkkkkkkkUUuUUuUUuuUUUuuUUuUuuuUuUUuuUUkw",
	"wkkkkkkkUuuuuuUuuuUuuuuuuuUuuuUuUuuuUUkw",
	"wkkkkkkkUuUUUUUuUuUuUUUuUUUuUUUuUUUUUUkw",
	"wkkkkkkkUuuuUuuuUuUuUuuuUuuuUuuuuuuuUUkw",
	"wkkkkkkkUUUuUuUUUuUuUUUuUUUuUUUUUUUuUUkw",
	"wkkkkkkkUuuuUuuuuuUuuuUuuuUuuuUuuuUuUUkw",
	"wkkkkkkkUuUUUuUUUUUUUuUUUuUUUuUuUuUuUUkw",
	"wkkkkkkkUuUuUuUuuuuuUuuuhuuuUuuuUuuuUUkw",
	"wkkkkkkkUuUuUuUUUuUuUUUuUUUuUUUUUUUuUUkw",
	"wkkkkkkkUuUuuuuuUuUuuuUuuuuuUuUuuuuuUUkw",
	"wkkkkkkkUuUUUUUuUuUUUUUUUUUUUuUuUUUUUUkw",
	"wkkkkkkkUuuuUuuuUuUuuuuuUuuuuuUuUuuuUUkw",
	"wkkkkkkkUUUuUuUUUuUuUuUuUuUUUUUuUUUuUUkw",
	"wkkkkkkkUuuuUuUuuuUuUuUuuuUuuuUuuuuuUUkw",
	"wkkkkkkkUuuUUuUUuuUuUuuuUUUuuuUUUUuuUUkw",
	"wkkkkkkkUuuuUuuuuuUuUuuuUuuuuuuuuuuuUUkw",
	"wkkkkkkkUuUuUUUUUuUuUuUUUuUUUUUUUuUuUUkw",
	"wkkkkkkkUuUuuuuuuuUuUuuuUuUuuuUuuuUuUUkw",
	"wkkkkkkkUuUUUUUUUuUuUUUuUuUuUuUuUUUuUUkw",
	"wkkkkkkkUuuuuuuuUuUuUuUuuuUuUuUuuuuuUUkw",
	"wkkkkkkkUuUUUUUuUUUuUuUUUUUUUuUUUUUUUUkw",
	"wkkkkkkkUuuuuuUuuuuuUuuuuuuuUuuuuuUuUUkw",
	"wkkkkkkkUUUUUuUUUUUUUUUuUUUuUuUUUuUuUUkw",
	"wkkkkkkkUuuuuuuuuuuuuuuuUuuuuuUuuuuuUUkw",
	"wkkkkkkkUUUUUUUUUUUUUUUUUUUUUUUUUuUUUUkw",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkvvvvvvvvkw",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkFFFFFFFFkw",
	"wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
]


## 梅林と祠の下地は獣道、樹林の下地は砂利、展望所の柵は石畳
func _ground_under(x: int, y: int) -> String:
	var ch: String = MAP_ROWS[y][x]
	if ch == "U" or ch == "h":
		return GROUND_LEGEND["u"]
	if ch == "F":
		return GROUND_LEGEND["v"]
	return ""


## 夜だけ展望所に灯りが現れる
func _apply_time_of_day(time_of_day: String) -> void:
	if time_of_day == Calendar.TIME_NIGHT:
		set_tile(objects, LOOKOUT_LAMP_TILE, OBJECT_LEGEND["L"])
	else:
		objects.erase_cell(LOOKOUT_LAMP_TILE)
		Lighting.sync_tile_light(lights, LOOKOUT_LAMP_TILE, "")
