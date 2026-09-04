class_name TileGenerator
extends RefCounted
## プロシージャルなタイル生成の唯一の入口。
## 種別名 → Image / ImageTexture を生成し、TileSet（物理レイヤー＋カスタムデータ）を組み立てる。
## 生成結果はキャッシュし、同一種別を作り直さない。
## ゲームロジックからは TileSetProvider 経由で使い、このクラスを直接触らないこと（PNG 差し替え時の境界）。

const SOURCE_ID: int = 0
const ATLAS_COLUMNS: int = 16
## TileSet の meta に保存する「種別名 → アトラス座標」の辞書キー
const META_COORDS: StringName = &"tile_coords"
const CUSTOM_TILE_TYPE: String = "tile_type"
const CUSTOM_INTERACTABLE: String = "is_interactable"
const FALLBACK_PAINTER: String = "fallback"

static var _image_cache: Dictionary = {}
static var _texture_cache: Dictionary = {}
static var _fallback_reported: Dictionary = {}


## 種別名を対応表のエントリに解決する。完全一致 → 括弧を除いた基本名 → 空辞書
static func resolve_entry(type_name: String) -> Dictionary:
	var catalog: Dictionary = TileCatalog.entries()
	if catalog.has(type_name):
		return catalog[type_name]
	var base: String = TileCatalog.normalize(type_name)
	if catalog.has(base):
		return catalog[base]
	return {}


static func is_known(type_name: String) -> bool:
	return not resolve_entry(type_name).is_empty()


static func is_walkable(type_name: String) -> bool:
	var entry: Dictionary = resolve_entry(type_name)
	return bool(entry.get("walkable", false))


static func is_interactable(type_name: String) -> bool:
	var entry: Dictionary = resolve_entry(type_name)
	return bool(entry.get("interactable", false))


## 16×16 の Image を返す。キャッシュ済みなら同じインスタンス
static func get_tile_image(type_name: String) -> Image:
	if _image_cache.has(type_name):
		return _image_cache[type_name]
	var brush: TileBrush = TileBrush.new(type_name.hash())
	var entry: Dictionary = resolve_entry(type_name)
	if entry.is_empty():
		if not _fallback_reported.has(type_name):
			push_warning("TileGenerator: 種別 '%s' は対応表に無いためフォールバックで描きます" % type_name)
			_fallback_reported[type_name] = true
		TilePaintersObjects.paint(FALLBACK_PAINTER, brush, {"name": type_name})
	else:
		var painter: String = str(entry["painter"])
		var args: Dictionary = entry["args"]
		if not _dispatch(painter, brush, args):
			push_error("TileGenerator: ペインタ '%s' が見つかりません（種別 '%s'）" % [painter, type_name])
			TilePaintersObjects.paint(FALLBACK_PAINTER, brush, {"name": type_name})
	var image: Image = brush.image
	if GameConstants.ART_SCALE > 1:
		image = image.duplicate()
		image.resize(GameConstants.TILE_SIZE, GameConstants.TILE_SIZE, Image.INTERPOLATE_NEAREST)
	_image_cache[type_name] = image
	return image


static func _dispatch(painter: String, brush: TileBrush, args: Dictionary) -> bool:
	if TilePaintersGround.paint(painter, brush, args):
		return true
	if TilePaintersBuilt.paint(painter, brush, args):
		return true
	return TilePaintersObjects.paint(painter, brush, args)


## 単体の ImageTexture（Sprite2D 等で 1 枚だけ使いたいとき）
static func get_tile_texture(type_name: String) -> ImageTexture:
	if _texture_cache.has(type_name):
		return _texture_cache[type_name]
	var texture: ImageTexture = ImageTexture.create_from_image(get_tile_image(type_name))
	_texture_cache[type_name] = texture
	return texture


static func clear_cache() -> void:
	_image_cache.clear()
	_texture_cache.clear()
	_fallback_reported.clear()


## 種別名の配列から TileSet を組み立てる。
## 物理レイヤー 0（通行不可タイルに全面の衝突形状）、カスタムデータ tile_type / is_interactable を持つ。
static func build_tileset(type_names: PackedStringArray) -> TileSet:
	var names: PackedStringArray = PackedStringArray()
	for n: String in type_names:
		if not names.has(n):
			names.append(n)
	var count: int = maxi(names.size(), 1)
	var rows: int = ceili(float(count) / ATLAS_COLUMNS)
	var ts: int = GameConstants.TILE_SIZE
	var atlas: Image = Image.create_empty(ATLAS_COLUMNS * ts, rows * ts, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var coords_by_name: Dictionary = {}
	for i: int in names.size():
		@warning_ignore("integer_division")
		var coords: Vector2i = Vector2i(i % ATLAS_COLUMNS, i / ATLAS_COLUMNS)
		atlas.blit_rect(get_tile_image(names[i]), Rect2i(Vector2i.ZERO, GameConstants.TILE_VECTOR), coords * ts)
		coords_by_name[names[i]] = coords

	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = GameConstants.TILE_VECTOR
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 1)
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(0, CUSTOM_TILE_TYPE)
	tile_set.set_custom_data_layer_type(0, TYPE_STRING)
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(1, CUSTOM_INTERACTABLE)
	tile_set.set_custom_data_layer_type(1, TYPE_BOOL)

	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.resource_name = "generated_atlas"
	source.texture = ImageTexture.create_from_image(atlas)
	source.texture_region_size = GameConstants.TILE_VECTOR
	tile_set.add_source(source, SOURCE_ID)

	for type_name: String in coords_by_name.keys():
		var coords: Vector2i = coords_by_name[type_name]
		source.create_tile(coords)
		var data: TileData = source.get_tile_data(coords, 0)
		data.set_custom_data(CUSTOM_TILE_TYPE, type_name)
		data.set_custom_data(CUSTOM_INTERACTABLE, is_interactable(type_name))
		if not is_walkable(type_name):
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, _full_square())
	tile_set.set_meta(META_COORDS, coords_by_name)
	return tile_set


## タイル中心を原点とした全面の矩形
static func _full_square() -> PackedVector2Array:
	var h: float = GameConstants.TILE_SIZE * 0.5
	return PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])


## TileSet 内の種別名 → アトラス座標。無ければ (-1,-1) を返しエラーを出す
static func get_atlas_coords(tile_set: TileSet, type_name: String) -> Vector2i:
	if tile_set == null or not tile_set.has_meta(META_COORDS):
		push_error("TileGenerator: TileSet に %s メタがありません" % META_COORDS)
		return Vector2i(-1, -1)
	var coords_by_name: Dictionary = tile_set.get_meta(META_COORDS)
	if coords_by_name.has(type_name):
		return coords_by_name[type_name]
	var base: String = TileCatalog.normalize(type_name)
	if coords_by_name.has(base):
		return coords_by_name[base]
	push_error("TileGenerator: 種別 '%s' は TileSet に含まれていません" % type_name)
	return Vector2i(-1, -1)


## TileData から種別名を読む（TileMapLayer.get_cell_tile_data の結果に使う）
static func get_tile_type(data: TileData) -> String:
	if data == null:
		return ""
	return str(data.get_custom_data(CUSTOM_TILE_TYPE))
