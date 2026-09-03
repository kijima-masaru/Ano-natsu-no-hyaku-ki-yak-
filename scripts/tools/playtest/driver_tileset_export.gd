extends Node
## 使い方：godot --headless --path . res://scenes/debug/playtest_driver.tscn -- --runner=res://scripts/tools/playtest/driver_tileset_export.gd [--png] [--catalog]
## TileSet リソース（resources/tilesets/common.tres）を書き出す（docs/TILESET_PIPELINE.md）。
## - 既定：resources/tilesets/atlas_layout.json（tools/tiles/paint32.py が書く。種別名 → 座標、変種、背の高い部品）と
##   アトラス PNG（common_atlas.png）から TileSet を組む。物理・カスタムデータは TileCatalog から
## - layout が無ければ生成ペインタの並び（TileGenerator.build_tileset）で組む
## - --png：生成ペインタのアトラスを PNG に書き出す（既存の PNG を上書きするので注意）
## - --catalog：tools/tiles/catalog.json（種別名 → ペインタ・引数・通行可否。paint32.py の入力）を書き出す

const ATLAS_PNG: String = "res://resources/tilesets/common_atlas.png"
const LAYOUT_JSON: String = "res://resources/tilesets/atlas_layout.json"
const TRES: String = "res://resources/tilesets/common.tres"
const CATALOG_JSON: String = "res://tools/tiles/catalog.json"
## 光を遮るペインタ（TileCatalog の painter 名）。マス全体を遮る物と、幹・柱だけ遮る物。
## 光源になる種別（LightCatalog）は光が内側から出るので遮らない。柵・金網・水・看板は遮らない
const OCCLUDE_FULL: PackedStringArray = ["block_wall", "concrete_wall", "tile_wall", "plank_h", "plank_v", "roof", "box", "door",
	"shutter", "fence", "cliff", "conifer", "gate", "mound", "rock", "car", "window", "grass", "vending", "glass"]
const OCCLUDE_TRUNK: PackedStringArray = ["tree", "bare_tree", "pole", "slab", "tower", "lamp"]


func _ready() -> void:
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var names: PackedStringArray = TileCatalog.all_names()
	if args.has("--catalog"):
		var out: Dictionary = {}
		for n: String in names:
			out[n] = TileCatalog.entries()[n]
		var f: FileAccess = FileAccess.open(CATALOG_JSON, FileAccess.WRITE)
		f.store_string(JSON.stringify(out, "  ") + "\n")
		f.close()
		print("catalog: %s (%d)" % [CATALOG_JSON, out.size()])
	if args.has("--png") or not FileAccess.file_exists(ATLAS_PNG):
		var generated: TileSet = TileGenerator.build_tileset(names)
		var image: Image = (generated.get_source(TileGenerator.SOURCE_ID) as TileSetAtlasSource).texture.get_image()
		print("atlas png: %s %dx%d -> %s" % [ATLAS_PNG, image.get_width(), image.get_height(), error_string(image.save_png(ATLAS_PNG))])
	var tile_set: TileSet = null
	if FileAccess.file_exists(LAYOUT_JSON) and ResourceLoader.exists(ATLAS_PNG):
		tile_set = _build_from_layout(names)
	if tile_set == null:
		tile_set = TileGenerator.build_tileset(names)
		var source: TileSetAtlasSource = tile_set.get_source(TileGenerator.SOURCE_ID) as TileSetAtlasSource
		if ResourceLoader.exists(ATLAS_PNG):
			var tex: Texture2D = load(ATLAS_PNG) as Texture2D
			if tex != null and tex.get_width() == source.texture.get_width() and tex.get_height() == source.texture.get_height():
				source.texture = tex
				print("atlas texture: 取り込み済み PNG を参照（生成の並び）")
	var err: Error = ResourceSaver.save(tile_set, TRES)
	var src: TileSetAtlasSource = tile_set.get_source(TileGenerator.SOURCE_ID) as TileSetAtlasSource
	print("tileset: %s -> %s (tiles=%d, names=%d)" % [TRES, error_string(err), src.get_tiles_count(), names.size()])
	get_tree().quit(0)


## layout（paint32.py の出力）から TileSet を組む。並びは layout が正
func _build_from_layout(names: PackedStringArray) -> TileSet:
	var errors: PackedStringArray = PackedStringArray()
	var layout: Dictionary = JsonFile.read_dict(LAYOUT_JSON, errors)
	if layout.is_empty():
		push_error("layout を読めません: " + (errors[0] if not errors.is_empty() else LAYOUT_JSON))
		return null
	var tex: Texture2D = load(ATLAS_PNG) as Texture2D
	if tex == null:
		push_error("アトラス PNG を読めません: " + ATLAS_PNG)
		return null
	var ts: int = int(layout.get("tile_size", GameConstants.TILE_SIZE))
	if ts != GameConstants.TILE_SIZE:
		push_error("layout の tile_size %d が TILE_SIZE %d と違う" % [ts, GameConstants.TILE_SIZE])
		return null
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = GameConstants.TILE_VECTOR
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 1)
	tile_set.add_occlusion_layer()
	tile_set.set_occlusion_layer_light_mask(0, 1)
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(0, TileGenerator.CUSTOM_TILE_TYPE)
	tile_set.set_custom_data_layer_type(0, TYPE_STRING)
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(1, TileGenerator.CUSTOM_INTERACTABLE)
	tile_set.set_custom_data_layer_type(1, TYPE_BOOL)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.resource_name = "painted_atlas"
	source.texture = tex
	source.texture_region_size = GameConstants.TILE_VECTOR
	tile_set.add_source(source, TileGenerator.SOURCE_ID)
	var coords_by_name: Dictionary = {}
	var variants: Dictionary = {}
	var tall: Dictionary = {}
	var missing: PackedStringArray = PackedStringArray()
	for item: Variant in layout.get("entries", []) as Array:
		var e: Dictionary = item
		var name: String = str(e["name"])
		var variant: String = str(e.get("variant", ""))
		var coords: Vector2i = Vector2i(int(e["x"]), int(e["y"]))
		if not TileCatalog.entries().has(name):
			if not missing.has(name):
				missing.append(name)
			continue
		source.create_tile(coords)
		var data: TileData = source.get_tile_data(coords, 0)
		if variant == "part":
			# 木の梢・電柱の上部など。Overhead 層に置く。通行判定に関わらないよう種別名は空、当たりも無し
			data.set_custom_data(TileGenerator.CUSTOM_TILE_TYPE, "")
			data.set_custom_data(TileGenerator.CUSTOM_INTERACTABLE, false)
			if not tall.has(name):
				tall[name] = []
			(tall[name] as Array).append({"offset": Vector2i(int(e.get("dx", 0)), int(e.get("dy", -1))), "coords": coords})
			continue
		data.set_custom_data(TileGenerator.CUSTOM_TILE_TYPE, name)
		data.set_custom_data(TileGenerator.CUSTOM_INTERACTABLE, TileGenerator.is_interactable(name))
		if not TileGenerator.is_walkable(name):
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, _full_square())
			var occluder: OccluderPolygon2D = _occluder_for(name)
			if occluder != null:
				data.set_occluder_polygons_count(0, 1)
				data.set_occluder_polygon(0, 0, occluder)
		if variant.is_empty():
			coords_by_name[name] = coords
		elif variant.begins_with("m"):
			if not variants.has(name):
				variants[name] = {}
			(variants[name] as Dictionary)[int(variant.substr(1))] = coords
	for n: String in names:
		if not coords_by_name.has(n):
			push_error("layout に種別 '%s' が無い（paint32.py を実行し直す）" % n)
	if not missing.is_empty():
		push_warning("layout にあるが TileCatalog に無い種別: " + ", ".join(missing))
	tile_set.set_meta(TileGenerator.META_COORDS, coords_by_name)
	tile_set.set_meta(TileVariants.META_VARIANTS, variants)
	tile_set.set_meta(TileVariants.META_TALL, tall)
	print("layout: 種別 %d、オートタイル %d、背の高い部品 %d" % [coords_by_name.size(), variants.size(), tall.size()])
	return tile_set


## 種別の遮蔽ポリゴン。光源の種別と、遮らないペインタは null
func _occluder_for(name: String) -> OccluderPolygon2D:
	if not LightCatalog.get_light(name).is_empty():
		return null
	var painter: String = str((TileCatalog.entries()[name] as Dictionary).get("painter", ""))
	var poly: OccluderPolygon2D = OccluderPolygon2D.new()
	poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
	if OCCLUDE_FULL.has(painter):
		poly.polygon = _full_square()
		return poly
	if OCCLUDE_TRUNK.has(painter):
		var h: float = GameConstants.TILE_SIZE * 0.5
		var w: float = GameConstants.TILE_SIZE * 0.125
		poly.polygon = PackedVector2Array([Vector2(-w, -h * 0.25), Vector2(w, -h * 0.25), Vector2(w, h), Vector2(-w, h)])
		return poly
	return null


func _full_square() -> PackedVector2Array:
	var h: float = GameConstants.TILE_SIZE * 0.5
	return PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
