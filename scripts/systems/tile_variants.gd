class_name TileVariants
extends RefCounted
## 地図を組み立てた後に、TileSet の meta（variants / tall）を使ってタイルを差し替える後処理。
## - オートタイル：同じ種別の 4 近傍（N=1 E=2 S=4 W=8）のビットで変種 "<種別>#m<mask>" を選ぶ。壁・屋根・生け垣の角と端がつながる
## - 背の高い部品：本体以外のマス "<種別>#part"（相対位置 offset 付き）を Overhead 層に置く（アクターより前に描かれ、木の梢が人物を隠す）。
##   木は幅 3 × 高さ 3〜4 マス、電柱は高さ 5 マスなど、縮尺（1 マス ≈ 1.7 m）に合わせた大きさ。先に置かれた部品が優先
## meta が無い TileSet（生成モード）では何もしない。種別名・通行可否はタイルのカスタムデータに残るので、ゲーム側の判定は変わらない。

const META_VARIANTS: StringName = &"tile_variants"
const META_TALL: StringName = &"tile_tall"


static func apply(field: FieldBase) -> void:
	var tile_set: TileSet = field.ground.tile_set
	if tile_set == null:
		return
	var variants: Dictionary = tile_set.get_meta(META_VARIANTS, {})
	var tall: Dictionary = tile_set.get_meta(META_TALL, {})
	if variants.is_empty() and tall.is_empty():
		return
	for layer: TileMapLayer in [field.ground, field.objects]:
		_apply_layer(field, layer, variants, tall)


static func _apply_layer(field: FieldBase, layer: TileMapLayer, variants: Dictionary, tall: Dictionary) -> void:
	var cells: Array[Vector2i] = layer.get_used_cells()
	var types: Dictionary = {}
	for cell: Vector2i in cells:
		types[cell] = field.get_tile_type_at(layer, cell)
	for cell: Vector2i in cells:
		var type_name: String = types[cell]
		if type_name.is_empty():
			continue
		if variants.has(type_name):
			var mask: int = 0
			if _same(types, cell + Vector2i.UP, type_name, layer):
				mask |= 1
			if _same(types, cell + Vector2i.RIGHT, type_name, layer):
				mask |= 2
			if _same(types, cell + Vector2i.DOWN, type_name, layer):
				mask |= 4
			if _same(types, cell + Vector2i.LEFT, type_name, layer):
				mask |= 8
			var table: Dictionary = variants[type_name]
			if table.has(mask):
				layer.set_cell(cell, TileGenerator.SOURCE_ID, table[mask])
		if tall.has(type_name) and not _same(types, cell + Vector2i.UP, type_name, layer):
			# 上に同じ種別が続く（杉林などの林の内側）なら部品を置かない。内側は本体の絵（梢を上から見た繁み）だけになり、
			# 林の上端の列だけが背の高い木として立ち上がる
			for item: Variant in tall[type_name] as Array:
				var piece: Dictionary = item
				var target: Vector2i = cell + (piece["offset"] as Vector2i)
				if field.overhead.get_cell_source_id(target) == -1:
					field.overhead.set_cell(target, TileGenerator.SOURCE_ID, piece["coords"])


## 隣が同じ種別か。地図の外は「同じ」とみなし、端で切れ目を出さない（林は地図の外へ続く）
static func _same(types: Dictionary, cell: Vector2i, type_name: String, layer: TileMapLayer) -> bool:
	if types.has(cell):
		return str(types[cell]) == type_name
	var rect: Rect2i = layer.get_used_rect()
	return not rect.has_point(cell)
