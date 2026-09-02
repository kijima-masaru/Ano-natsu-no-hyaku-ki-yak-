class_name TileCatalog
extends RefCounted
## タイル種別名（data/fields.json の required_tiles と同じ日本語）→ ペインタと属性の対応表。
## キーは JSON の表記をそのまま使う。括弧付きの表記は normalize() で基本名にも解決できる。
## 属性: painter（描き方）, args（パレットインデックス等）, walkable（通行可）, interactable（調べられる）
##
## ※ Palette は autoload のため const 式から参照できない。そのため対応表は静的関数で一度だけ構築してキャッシュする。

static var _entries: Dictionary = {}


## 全エントリ。初回呼び出しで構築する
static func entries() -> Dictionary:
	if _entries.is_empty():
		_entries = _build()
	return _entries


## 登録されている全種別名
static func all_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for key: String in entries().keys():
		names.append(key)
	names.sort()
	return names


## 「白線（実線・破線）」→「白線」のように括弧以降と前後の空白を取り除く
static func normalize(raw: String) -> String:
	var cut: int = raw.find("（")
	var base: String = raw if cut < 0 else raw.substr(0, cut)
	return base.strip_edges()


static func _t(painter: String, walkable: bool, args: Dictionary = {}, interactable: bool = false) -> Dictionary:
	return {"painter": painter, "args": args, "walkable": walkable, "interactable": interactable}


static func _build() -> Dictionary:
	var e: Dictionary = {}
	# ── 道路・舗装 ──
	e["アスファルト"] = _t("ground", true, {"base": Palette.DUSK_INDIGO, "speck": Palette.FOG_INDIGO})
	e["生活道路アスファルト（細）"] = _t("ground", true, {"base": Palette.DUSK_INDIGO, "speck": Palette.FOG_INDIGO, "density": 0.05})
	e["旧街道アスファルト（狭）"] = _t("ground", true, {"base": Palette.DUSK_INDIGO, "speck": Palette.RUST_DARK, "density": 0.1})
	e["区画道路アスファルト"] = _t("ground", true, {"base": Palette.DUSK_INDIGO, "speck": Palette.CONCRETE, "density": 0.04})
	e["堤防道路"] = _t("ground", true, {"base": Palette.DUSK_INDIGO, "speck": Palette.CONCRETE, "density": 0.06})
	e["高架床版（影）"] = _t("ground", true, {"base": Palette.NIGHT_SKY, "speck": Palette.SUMI, "density": 0.1})
	e["土橋"] = _t("ground", true, {"base": Palette.RUST, "speck": Palette.OCHRE, "density": 0.1})
	e["白線（実線・破線）"] = _t("line_h", true, {"base": Palette.DUSK_INDIGO, "line": Palette.BONE_WHITE, "thick": 2})
	e["白線（土用）"] = _t("line_h", true, {"base": Palette.RUST_DARK, "speck": Palette.RUST, "line": Palette.BONE_WHITE, "thick": 1})
	e["白線（停止線）"] = _t("line_h", true, {"base": Palette.DUSK_INDIGO, "line": Palette.BONE_WHITE, "thick": 3, "pos": 6})
	e["駐車場ライン"] = _t("line_v", true, {"base": Palette.DUSK_INDIGO, "line": Palette.BONE_WHITE, "thick": 1, "pos": 0})
	e["側溝・グレーチング"] = _t("grating", true, {"base": Palette.FOG_INDIGO})
	e["側溝"] = _t("grating", true, {"base": Palette.DUSK_INDIGO})
	e["歩道タイル"] = _t("interlock", true, {"a": Palette.CONCRETE, "b": Palette.FOG_INDIGO})
	e["狭い歩道（縁石）"] = _t("curb", true)
	e["広場の敷石（インターロッキング）"] = _t("interlock", true, {"a": Palette.CONCRETE, "b": Palette.FOG_INDIGO, "gap": Palette.DUSK_INDIGO})
	e["石畳"] = _t("paving", true, {"stone": Palette.CONCRETE, "gap": Palette.DUSK_INDIGO})
	e["礎石"] = _t("paving", true, {"stone": Palette.FOG_INDIGO, "gap": Palette.MOSS_DARK, "moss": 0.15}, true)
	e["境内の砂利"] = _t("gravel", true, {"base": Palette.FOG_INDIGO})
	e["農道の砂利"] = _t("gravel", true, {"base": Palette.RUST_DARK, "light": Palette.OCHRE, "dark": Palette.RUST})
	e["林道の砂利"] = _t("gravel", true, {"base": Palette.RUST_DARK, "light": Palette.OCHRE, "dark": Palette.RUST})
	e["河原の石"] = _t("gravel", true, {"base": Palette.FOG_INDIGO, "light": Palette.CONCRETE, "dark": Palette.DUSK_INDIGO})
	e["縞鋼板の歩道橋"] = _t("mesh", true, {"ground": Palette.FOG_INDIGO, "wire": Palette.CONCRETE})
	e["橋（桁・欄干・橋灯）"] = _t("bridge", true, {"glow": Palette.STREETLAMP_GLOW})
	# ── 土・草・田畑 ──
	e["畑の土（畝）"] = _t("soil_rows", true)
	e["校庭の土"] = _t("ground", true, {"base": Palette.RUST, "speck": Palette.OCHRE, "density": 0.1})
	e["土のグラウンド"] = _t("ground", true, {"base": Palette.RUST, "speck": Palette.OCHRE, "density": 0.08})
	e["公園の砂地"] = _t("ground", true, {"base": Palette.OCHRE, "speck": Palette.CONCRETE, "density": 0.08})
	e["草地（丈高・低）"] = _t("grass", true)
	e["下草"] = _t("grass", true, {"base": Palette.MOSS_DARK, "blade": Palette.FADED_GREEN})
	e["下草（丈高）"] = _t("grass", true, {"base": Palette.MOSS_DARK, "blade": Palette.FADED_GREEN, "tall": true})
	e["売地の草"] = _t("grass", true, {"base": Palette.FADED_GREEN, "blade": Palette.OCHRE, "tall": true})
	e["生垣"] = _t("grass", false, {"base": Palette.MOSS_DARK, "blade": Palette.FADED_GREEN_LIGHT, "tall": true})
	e["獣道"] = _t("path", true, {"grass": Palette.MOSS_DARK, "dirt": Palette.RUST_DARK})
	e["獣道（踏み分け）"] = _t("path", true, {"grass": Palette.MOSS_DARK, "dirt": Palette.RUST_DARK})
	e["畦道"] = _t("path", true, {"grass": Palette.FADED_GREEN, "dirt": Palette.OCHRE, "vertical": false})
	e["苔"] = _t("ground", true, {"base": Palette.MOSS_DARK, "speck": Palette.FADED_GREEN_LIGHT, "density": 0.15})
	e["土塁（斜面・上面）"] = _t("slope", true, {"base": Palette.FADED_GREEN, "line": Palette.RUST_DARK})
	e["堤防斜面"] = _t("slope", true, {"base": Palette.FADED_GREEN, "line": Palette.MOSS_DARK})
	e["堤防斜面（草）"] = _t("slope", true, {"base": Palette.FADED_GREEN, "line": Palette.MOSS_DARK})
	e["法面コンクリート（格子）"] = _t("slope", false, {"concrete": true})
	e["空堀（底・壁）"] = _t("moat", true)
	e["古墳（盛土・石室口）"] = _t("mound", false, {}, true)
	e["霧（半透明オーバーレイ）"] = _t("fog", true)
	# ── 水 ──
	e["水田（水面・稲）"] = _t("paddy", false)
	e["用水路（水面・コンクリート）"] = _t("water", false, {"ripple": Palette.FOG_INDIGO, "flow": true})
	e["水面（流れ）"] = _t("water", false, {"flow": true})
	e["調整池（水面・柵）"] = _t("water", false, {"ripple": Palette.DUSK_INDIGO})
	e["湧水（水面・小）"] = _t("spring", false, {}, true)
	# ── 木・林 ──
	e["柿の木（実あり）"] = _t("tree", false, {"fruit": Palette.RUST}, true)
	e["栗の木"] = _t("tree", false, {"canopy": Palette.MOSS_DARK, "shade": Palette.NIGHT_SKY, "fruit": Palette.OCHRE})
	e["梅の木（開花・裸）"] = _t("bare_tree", false, {"blossom": Palette.BONE_WHITE})
	e["桜（葉・裸）"] = _t("bare_tree", false, {"ground": Palette.DUSK_INDIGO})
	e["イチョウ（大木）"] = _t("tree", false, {"canopy": Palette.OCHRE, "shade": Palette.RUST, "trunk": Palette.RUST_DARK}, true)
	e["杉林"] = _t("conifer", false)
	e["杉林（暗）"] = _t("conifer", false, {"leaf": Palette.MOSS_DARK, "hi": Palette.MOSS_DARK, "ground": Palette.SUMI})
	e["樹林（暗）"] = _t("conifer", false, {"leaf": Palette.MOSS_DARK, "hi": Palette.FADED_GREEN})
	e["谷の斜面（暗い樹林）"] = _t("conifer", false, {"leaf": Palette.MOSS_DARK, "hi": Palette.FADED_GREEN, "ground": Palette.NIGHT_SKY})
	e["山の斜面（樹林）"] = _t("conifer", false, {"leaf": Palette.FADED_GREEN, "hi": Palette.FADED_GREEN_LIGHT, "ground": Palette.MOSS_DARK})
	e["植栽"] = _t("tree", false, {"ground": Palette.CONCRETE, "canopy": Palette.FADED_GREEN})
	e["植栽（低木）"] = _t("tree", false, {"ground": Palette.CONCRETE, "canopy": Palette.FADED_GREEN})
	# ── 岩・崖・段 ──
	e["落石（岩）"] = _t("rock", false, {}, true)
	e["苔むした石"] = _t("rock", false, {"ground": Palette.MOSS_DARK, "base": Palette.FADED_GREEN, "hi": Palette.FADED_GREEN_LIGHT, "shade": Palette.MOSS_DARK})
	e["谷の岩壁"] = _t("cliff", false)
	e["崖（通行不能）"] = _t("cliff", false, {"base": Palette.RUST_DARK, "dark": Palette.SUMI, "hi": Palette.RUST})
	e["裂け目（暗）"] = _t("crack", false, {}, true)
	e["法面階段"] = _t("stairs", true, {"base": Palette.CONCRETE})
	e["石段（登り口）"] = _t("stairs", true, {"base": Palette.CONCRETE, "hi": Palette.BONE_WHITE})
	e["石段（長・手すり）"] = _t("stairs", true, {"base": Palette.CONCRETE, "rail": true})
	e["崩れた石段"] = _t("stairs", true, {"base": Palette.FOG_INDIGO, "broken": true})
	# ── 壁・屋根・窓・戸 ──
	e["ブロック塀"] = _t("block_wall", false, {"base": Palette.FOG_INDIGO, "mortar": Palette.DUSK_INDIGO})
	e["土塀（漆喰・崩れ）"] = _t("block_wall", false, {"base": Palette.OCHRE, "mortar": Palette.RUST_DARK, "bw": 16, "bh": 5, "stain": Palette.RUST_DARK, "stain_density": 0.15})
	e["公共建築の壁（タイル）"] = _t("tile_wall", false)
	e["新校舎 外壁（タイル）"] = _t("tile_wall", false, {"base": Palette.CONCRETE, "grout": Palette.DUSK_INDIGO})
	e["支所の壁（タイル）"] = _t("tile_wall", false, {"base": Palette.FOG_INDIGO, "grout": Palette.DUSK_INDIGO})
	e["防音壁"] = _t("concrete_wall", false, {"base": Palette.FOG_INDIGO, "stain": 0.2})
	e["防音壁（遠景）"] = _t("concrete_wall", false, {"base": Palette.DUSK_INDIGO, "stain": 0.2})
	e["高架橋脚"] = _t("concrete_wall", false, {"base": Palette.CONCRETE, "stain": 0.4})
	e["隧道内壁（湿）"] = _t("concrete_wall", false, {"base": Palette.DUSK_INDIGO, "stain": 0.6})
	e["体育館の壁"] = _t("concrete_wall", false, {"base": Palette.FOG_INDIGO, "stain": 0.15})
	e["団地 外壁（コンクリート・雨染み）"] = _t("concrete_wall", false, {"stain": 0.5})
	e["庵の板壁と瓦"] = _t("plank_v", false, {"base": Palette.RUST_DARK, "gap": Palette.SUMI})
	e["観音堂の板壁・格子・屋根"] = _t("plank_v", false, {"base": Palette.RUST_DARK, "gap": Palette.SUMI, "width": 2}, true)
	e["廃寺の壁・屋根（崩落）"] = _t("plank_v", false, {"base": Palette.RUST_DARK, "gap": Palette.SUMI, "worn": true})
	e["農機具小屋（トタン・板）"] = _t("plank_h", false, {"base": Palette.RUST, "gap": Palette.RUST_DARK, "width": 3}, true)
	e["倉庫（トタン）"] = _t("plank_h", false, {"base": Palette.FOG_INDIGO, "gap": Palette.DUSK_INDIGO, "width": 3}, true)
	e["旧校舎 外壁（下見板）"] = _t("plank_h", false, {"base": Palette.RUST, "gap": Palette.RUST_DARK, "worn": true})
	e["旧校舎 廊下床（板）"] = _t("plank_h", true, {"base": Palette.OCHRE, "gap": Palette.RUST, "width": 4, "worn": true})
	e["建売住宅の壁・屋根（瓦）"] = _t("roof", false)
	e["瓦屋根（連続）"] = _t("roof", false)
	e["同型住宅の壁・屋根（3色差分）"] = _t("roof", false, {"base": Palette.DUSK_INDIGO, "dark": Palette.NIGHT_SKY, "hi": Palette.CONCRETE})
	e["農家の壁・瓦"] = _t("roof", false, {"base": Palette.RUST_DARK, "dark": Palette.SUMI, "hi": Palette.RUST})
	e["社殿の壁・屋根（檜皮）"] = _t("roof", false, {"bark": true, "base": Palette.RUST_DARK, "dark": Palette.SUMI})
	e["駐輪場の屋根"] = _t("roof", false, {"base": Palette.FOG_INDIGO, "dark": Palette.DUSK_INDIGO, "hi": Palette.CONCRETE})
	e["カーポート"] = _t("roof", false, {"base": Palette.FOG_INDIGO, "dark": Palette.DUSK_INDIGO, "hi": Palette.CONCRETE})
	e["窓（消灯・点灯）"] = _t("window", false)
	e["旧校舎 窓（木枠）"] = _t("window", false, {"wall": Palette.RUST, "frame": Palette.RUST_DARK}, true)
	e["階段室（点灯・消灯）"] = _t("window", false, {"wall": Palette.CONCRETE, "lit": true, "glow": Palette.FLUORESCENT}, true)
	e["駄菓子屋の店先（点灯）"] = _t("window", false, {"wall": Palette.RUST, "lit": true, "glow": Palette.STREETLAMP_GLOW}, true)
	e["店舗ガラス面（点灯）"] = _t("glass", false, {"lit": true})
	e["ガラス扉（点灯）"] = _t("glass", false, {"lit": true, "glow": Palette.STREETLAMP_GLOW})
	e["店舗の木製戸"] = _t("door", false)
	e["シャッター（下・半開き）"] = _t("shutter", false, {"half": true})
	# ── 柵・網・線状の設備 ──
	e["ガードレール"] = _t("rail", false, {"bar": Palette.CONCRETE, "double": false})
	e["物干し"] = _t("rail", false, {"bar": Palette.CONCRETE, "double": false, "post": Palette.FOG_INDIGO}, true)
	e["自転車置き場"] = _t("rail", false, {"bar": Palette.FOG_INDIGO})
	e["絵馬掛け"] = _t("rail", false, {"bar": Palette.RUST, "post": Palette.RUST_DARK}, true)
	e["玉垣"] = _t("rail", false, {"bar": Palette.CONCRETE, "post": Palette.CONCRETE, "ground": Palette.FADED_GREEN})
	e["展望所の柵"] = _t("rail", false, {"bar": Palette.FOG_INDIGO, "ground": Palette.NIGHT_SKY}, true)
	e["ベランダ"] = _t("rail", false, {"bar": Palette.CONCRETE, "ground": Palette.FOG_INDIGO})
	e["ブランコ・砂場"] = _t("rail", false, {"bar": Palette.FOG_INDIGO, "double": false, "ground": Palette.OCHRE}, true)
	e["フェンス（施錠）"] = _t("fence", false, {"locked": true}, true)
	e["ゴミ集積所ネット"] = _t("mesh", false, {"ground": Palette.CONCRETE, "wire": Palette.FADED_GREEN})
	e["バックネット（金網）"] = _t("mesh", false, {"ground": Palette.RUST, "wire": Palette.CONCRETE})
	e["飼育小屋（金網）"] = _t("mesh", false, {"ground": Palette.RUST_DARK, "wire": Palette.CONCRETE}, true)
	e["バリケード"] = _t("barricade", false, {}, true)
	e["電柱・電線"] = _t("pole", false)
	e["電気柵ポール"] = _t("pole", false, {"pole": Palette.RUST_DARK, "ground": Palette.FADED_GREEN}, true)
	# ── 光源 ──
	e["街灯（柱・光源）"] = _t("lamp", false)
	e["街灯（均等）"] = _t("lamp", false)
	e["常夜灯"] = _t("lamp", false, {"stone": true})
	e["蛍光灯（バス停）"] = _t("light_bar", false)
	e["蛍光灯"] = _t("light_bar", false)
	e["非常灯"] = _t("light_bar", false, {"small": true, "glow": Palette.FLUORESCENT})
	e["交番の赤色灯"] = _t("light_bar", false, {"small": true, "glow": Palette.VENDING_RED})
	e["自販機正面"] = _t("vending", false, {}, true)
	# ── 看板・箱型設備 ──
	e["店舗看板（無地）"] = _t("sign", false, {"board": Palette.CONCRETE, "ink": Palette.FOG_INDIGO})
	e["商店の看板（褪せ）"] = _t("sign", false, {"board": Palette.OCHRE, "ink": Palette.RUST_DARK})
	e["時刻表看板"] = _t("sign", false, {"board": Palette.BONE_WHITE, "ink": Palette.SUMI}, true)
	e["掲示板"] = _t("sign", false, {"board": Palette.OCHRE, "ink": Palette.SUMI}, true)
	e["看板（地図）"] = _t("sign", false, {"board": Palette.BONE_WHITE, "ink": Palette.DUSK_INDIGO}, true)
	e["案内板"] = _t("sign", false, {"board": Palette.CONCRETE, "ink": Palette.SUMI}, true)
	e["公衆電話ボックス"] = _t("box", false, {"body": Palette.FOG_INDIGO, "accent": Palette.FLUORESCENT, "accent_h": 6}, true)
	e["集合ポスト"] = _t("box", false, {"body": Palette.FOG_INDIGO, "slots": true}, true)
	e["百葉箱"] = _t("box", false, {"ground": Palette.FADED_GREEN, "body": Palette.BONE_WHITE, "slots": true, "x": 4, "y": 2, "w": 8, "h": 10}, true)
	e["ダッグアウト"] = _t("box", false, {"body": Palette.DUSK_INDIGO, "hi": Palette.FOG_INDIGO, "x": 1, "y": 1, "w": 14, "h": 14}, true)
	e["朝礼台"] = _t("box", false, {"ground": Palette.RUST, "body": Palette.CONCRETE, "x": 2, "y": 6, "w": 12, "h": 8})
	e["教室の机・椅子"] = _t("box", false, {"ground": Palette.OCHRE, "body": Palette.RUST_DARK, "hi": Palette.OCHRE, "x": 2, "y": 3, "w": 12, "h": 6}, true)
	e["黒板"] = _t("box", false, {"ground": Palette.RUST, "body": Palette.MOSS_DARK, "edge": Palette.RUST_DARK, "hi": Palette.FADED_GREEN, "x": 1, "y": 2, "w": 14, "h": 9}, true)
	e["厨子"] = _t("box", false, {"ground": Palette.NIGHT_SKY, "body": Palette.RUST_DARK, "accent": Palette.OCHRE, "hi": Palette.RUST}, true)
	e["ベンチ"] = _t("bench", false, {}, true)
	e["待合ベンチ"] = _t("bench", false, {"wood": Palette.FOG_INDIGO}, true)
	e["駐車車両（暗）"] = _t("car", false, {}, true)
	e["象の滑り台"] = _t("slide", false, {}, true)
	e["積まれた面"] = _t("masks", false, {}, true)
	# ── 塔・門・鳥居・石造物 ──
	e["時計塔"] = _t("tower", false, {"top": Palette.CONCRETE, "glow": Palette.STREETLAMP_GLOW})
	e["給水塔"] = _t("tower", false, {"top": Palette.CONCRETE}, true)
	e["照明塔"] = _t("tower", false, {"glow": Palette.STREETLAMP_GLOW}, true)
	e["火の見櫓"] = _t("tower", false, {"frame": Palette.RUST_DARK, "top": Palette.RUST}, true)
	e["寺の山門"] = _t("gate", false)
	e["山門（木・瓦）"] = _t("gate", false)
	e["隧道アーチ"] = _t("gate", false, {"ground": Palette.SUMI, "post": Palette.CONCRETE, "roof_color": Palette.FOG_INDIGO})
	e["校門（鉄）"] = _t("gate", false, {"roof": false, "post": Palette.FOG_INDIGO, "bar": Palette.CONCRETE})
	e["門扉"] = _t("gate", false, {"roof": false})
	e["鳥居"] = _t("torii", false)
	e["式内社の社殿・鳥居"] = _t("torii", false, {"wood": Palette.RUST_DARK}, true)
	e["石像（牛）"] = _t("slab", false, {"cow": true, "stone": Palette.FOG_INDIGO, "marks": false}, true)
	e["石柱"] = _t("slab", false, {"w": 4, "stone": Palette.FOG_INDIGO}, true)
	e["石の道標"] = _t("slab", false, {"w": 4}, true)
	e["墓石（複数形）"] = _t("slab", false, {"w": 4, "moss_density": 0.1})
	e["記念碑"] = _t("slab", false, {"w": 8}, true)
	e["石碑"] = _t("slab", false, {"w": 6}, true)
	e["水位標"] = _t("slab", false, {"w": 3, "stone": Palette.BONE_WHITE}, true)
	return e
