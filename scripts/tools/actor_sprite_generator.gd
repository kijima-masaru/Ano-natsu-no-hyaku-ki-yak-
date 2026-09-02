class_name ActorSpriteGenerator
extends RefCounted
## アクター用 16×24 の仮スプライトをプロシージャル生成する。
## tile_generator と同じ方針で scripts/tools/ に隔離し、将来は PNG のスプライトシートに差し替える。
## 4 方向 × 2 フレーム（立ち／歩き）。向きの判別ができれば十分な描き込みに留める。

const W: int = GameConstants.ACTOR_SPRITE_SIZE.x
const H: int = GameConstants.ACTOR_SPRITE_SIZE.y
const FRAME_COUNT: int = 2

static var _cache: Dictionary = {}


## 種別・向き・フレームからテクスチャを返す（キャッシュ済みなら同じインスタンス）
static func get_texture(kind: String, facing: Vector2i, frame: int = 0) -> ImageTexture:
	var key: String = "%s|%d,%d|%d" % [kind, facing.x, facing.y, frame % FRAME_COUNT]
	if _cache.has(key):
		return _cache[key]
	var image: Image = Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	match kind:
		"player":
			_draw_player(image, facing, frame % FRAME_COUNT)
		"heroine":
			_draw_heroine(image, facing, frame % FRAME_COUNT)
		"stalker":
			_draw_stalker(image, facing, frame % FRAME_COUNT)
		"toki":
			_draw_toki(image, facing, frame % FRAME_COUNT)
		_:
			push_warning("ActorSpriteGenerator: 種別 '%s' は未定義のためプレイヤーの絵を使います" % kind)
			_draw_player(image, facing, frame % FRAME_COUNT)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


static func clear_cache() -> void:
	_cache.clear()


static func _rect(image: Image, x: int, y: int, w: int, h: int, index: int) -> void:
	for yy: int in range(maxi(y, 0), mini(y + h, H)):
		for xx: int in range(maxi(x, 0), mini(x + w, W)):
			image.set_pixel(xx, yy, Palette.get_color(index))


## 主人公：暗いコート、灰藍の顔、墨の髪。肩掛けの鞄で左右の向きを補強する
static func _draw_player(image: Image, facing: Vector2i, frame: int) -> void:
	var coat: int = Palette.DUSK_INDIGO
	var coat_dark: int = Palette.NIGHT_SKY
	var skin: int = Palette.CONCRETE
	var hair: int = Palette.SUMI
	var bag: int = Palette.RUST_DARK
	# 足元の影
	_rect(image, 4, 22, 8, 2, coat_dark)
	# 脚（frame 1 は片足を前に）
	if frame == 0:
		_rect(image, 5, 17, 2, 5, coat_dark)
		_rect(image, 9, 17, 2, 5, coat_dark)
	else:
		_rect(image, 5, 16, 2, 4, coat_dark)
		_rect(image, 9, 18, 2, 4, coat_dark)
	# 胴（コート）
	_rect(image, 4, 9, 8, 9, coat)
	_rect(image, 3, 10, 1, 7, coat_dark)
	_rect(image, 12, 10, 1, 7, coat_dark)
	# 頭
	_rect(image, 4, 1, 8, 8, skin)
	_rect(image, 4, 1, 8, 3, hair)
	_rect(image, 4, 1, 1, 5, hair)
	_rect(image, 11, 1, 1, 5, hair)
	match facing:
		Vector2i.DOWN:
			_rect(image, 6, 5, 1, 1, hair)
			_rect(image, 9, 5, 1, 1, hair)
			_rect(image, 7, 11, 2, 5, coat_dark)
		Vector2i.UP:
			_rect(image, 4, 1, 8, 8, hair)
			_rect(image, 5, 10, 6, 1, bag)
		Vector2i.LEFT:
			_rect(image, 8, 1, 4, 8, hair)
			_rect(image, 5, 5, 1, 1, hair)
			_rect(image, 11, 10, 2, 7, bag)
			_rect(image, 5, 11, 1, 6, coat_dark)
		Vector2i.RIGHT:
			_rect(image, 4, 1, 4, 8, hair)
			_rect(image, 10, 5, 1, 1, hair)
			_rect(image, 3, 10, 2, 7, bag)
			_rect(image, 10, 11, 1, 6, coat_dark)
		_:
			push_error("ActorSpriteGenerator: facing %s は上下左右の単位ベクトルである必要があります" % facing)


## ヒロイン・澪：枯れ黄土のカーディガン、長めの髪、ノートを抱える。主人公より一段明るい配色で見分ける
static func _draw_heroine(image: Image, facing: Vector2i, frame: int) -> void:
	var top: int = Palette.OCHRE
	var top_dark: int = Palette.RUST
	var skirt: int = Palette.DUSK_INDIGO
	var skin: int = Palette.CONCRETE
	var hair: int = Palette.RUST_DARK
	var book: int = Palette.BONE_WHITE
	_rect(image, 4, 22, 8, 2, Palette.NIGHT_SKY)
	if frame == 0:
		_rect(image, 5, 18, 2, 4, skin)
		_rect(image, 9, 18, 2, 4, skin)
	else:
		_rect(image, 5, 17, 2, 4, skin)
		_rect(image, 9, 19, 2, 3, skin)
	_rect(image, 4, 14, 8, 5, skirt)
	_rect(image, 4, 9, 8, 5, top)
	_rect(image, 3, 10, 1, 5, top_dark)
	_rect(image, 12, 10, 1, 5, top_dark)
	_rect(image, 4, 1, 8, 8, skin)
	_rect(image, 4, 1, 8, 3, hair)
	_rect(image, 3, 2, 1, 9, hair)
	_rect(image, 12, 2, 1, 9, hair)
	match facing:
		Vector2i.DOWN:
			_rect(image, 6, 5, 1, 1, hair)
			_rect(image, 9, 5, 1, 1, hair)
			_rect(image, 6, 11, 4, 3, book)
		Vector2i.UP:
			_rect(image, 4, 1, 8, 8, hair)
			_rect(image, 3, 9, 10, 2, hair)
		Vector2i.LEFT:
			_rect(image, 8, 1, 5, 9, hair)
			_rect(image, 5, 5, 1, 1, hair)
			_rect(image, 3, 11, 3, 3, book)
		Vector2i.RIGHT:
			_rect(image, 3, 1, 5, 9, hair)
			_rect(image, 10, 5, 1, 1, hair)
			_rect(image, 10, 11, 3, 3, book)
		_:
			push_error("ActorSpriteGenerator: facing %s は上下左右の単位ベクトルである必要があります" % facing)


## 追跡者：顔の無い暗い人影。輪郭だけ僅かに明るく、向きは肩の傾きと歩幅で示す。血や傷は描かない
static func _draw_stalker(image: Image, facing: Vector2i, frame: int) -> void:
	var body: int = Palette.SUMI
	var edge: int = Palette.NIGHT_SKY
	_rect(image, 3, 22, 10, 2, Palette.NIGHT_SKY)
	if frame == 0:
		_rect(image, 5, 16, 2, 6, body)
		_rect(image, 9, 16, 2, 6, body)
	else:
		_rect(image, 4, 15, 2, 7, body)
		_rect(image, 10, 17, 2, 5, body)
	_rect(image, 3, 7, 10, 10, body)
	_rect(image, 5, 0, 6, 8, body)
	_rect(image, 3, 7, 10, 1, edge)
	_rect(image, 5, 0, 6, 1, edge)
	match facing:
		Vector2i.DOWN:
			_rect(image, 2, 9, 1, 6, edge)
			_rect(image, 13, 9, 1, 6, edge)
		Vector2i.UP:
			_rect(image, 2, 8, 1, 7, edge)
			_rect(image, 13, 8, 1, 7, edge)
			_rect(image, 5, 1, 6, 6, edge)
		Vector2i.LEFT:
			_rect(image, 2, 8, 1, 9, edge)
			_rect(image, 4, 1, 1, 6, edge)
		Vector2i.RIGHT:
			_rect(image, 13, 8, 1, 9, edge)
			_rect(image, 11, 1, 1, 6, edge)
		_:
			push_error("ActorSpriteGenerator: facing %s は上下左右の単位ベクトルである必要があります" % facing)


## 駄菓子屋の店主トキ：小柄、白髪、前掛け。動かない NPC なので歩行フレームは同じ
static func _draw_toki(image: Image, facing: Vector2i, _frame: int) -> void:
	var apron: int = Palette.BONE_WHITE
	var kimono: int = Palette.DUSK_INDIGO
	var skin: int = Palette.CONCRETE
	var hair: int = Palette.CONCRETE
	_rect(image, 4, 22, 8, 2, Palette.NIGHT_SKY)
	_rect(image, 5, 18, 2, 4, kimono)
	_rect(image, 9, 18, 2, 4, kimono)
	_rect(image, 4, 11, 8, 8, kimono)
	_rect(image, 5, 12, 6, 6, apron)
	_rect(image, 4, 4, 8, 7, skin)
	_rect(image, 4, 3, 8, 3, hair)
	_rect(image, 4, 3, 1, 5, hair)
	_rect(image, 11, 3, 1, 5, hair)
	match facing:
		Vector2i.DOWN:
			_rect(image, 6, 7, 1, 1, Palette.SUMI)
			_rect(image, 9, 7, 1, 1, Palette.SUMI)
		Vector2i.UP:
			_rect(image, 4, 4, 8, 6, hair)
		Vector2i.LEFT:
			_rect(image, 8, 3, 4, 8, hair)
			_rect(image, 5, 7, 1, 1, Palette.SUMI)
		Vector2i.RIGHT:
			_rect(image, 4, 3, 4, 8, hair)
			_rect(image, 10, 7, 1, 1, Palette.SUMI)
		_:
			push_error("ActorSpriteGenerator: facing %s は上下左右の単位ベクトルである必要があります" % facing)
