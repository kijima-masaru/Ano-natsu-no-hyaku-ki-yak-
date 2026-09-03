class_name LightTextureGenerator
extends RefCounted
## PointLight2D 用の減衰テクスチャをプロシージャルに生成する（画像素材が無いための暫定。差し替え境界はここだけ）。
## radial: 中心が最も明るい円形。cone: +X 方向へ開く扇形（Player の懐中電灯。向きはノード側の rotation で回す）。
## 白のグレースケールで描き、色は PointLight2D.color（Palette の光源色）で付ける。

## 画像素材（resources/lights/）。あればこちらを使い、無ければ生成する
const RADIAL_PNG: String = "res://resources/lights/radial.png"
const CONE_PNG: String = "res://resources/lights/cone.png"

static var _cache: Dictionary = {}


## 直径 size_px の円形減衰。falloff が大きいほど中心に光が集まる。既定の引数なら画像素材を優先する
static func radial(size_px: int, falloff: float = 1.6) -> Texture2D:
	var key: String = "radial:%d:%.2f" % [size_px, falloff]
	if _cache.has(key):
		return _cache[key]
	var asset: Texture2D = _load_asset(RADIAL_PNG, size_px)
	if asset != null:
		_cache[key] = asset
		return asset
	var image: Image = Image.create_empty(size_px, size_px, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(size_px, size_px) * 0.5
	var radius: float = size_px * 0.5
	for y: int in size_px:
		for x: int in size_px:
			var d: float = (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(center) / radius
			var a: float = pow(clampf(1.0 - d, 0.0, 1.0), falloff)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


## 直径 size_px の正方形に、中心から +X へ開く半角 half_angle_deg の扇形。縁は少しぼかす
static func cone(size_px: int, half_angle_deg: float, falloff: float = 1.2) -> Texture2D:
	var key: String = "cone:%d:%.1f:%.2f" % [size_px, half_angle_deg, falloff]
	if _cache.has(key):
		return _cache[key]
	var asset: Texture2D = _load_asset(CONE_PNG, size_px)
	if asset != null:
		_cache[key] = asset
		return asset
	var image: Image = Image.create_empty(size_px, size_px, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(size_px, size_px) * 0.5
	var radius: float = size_px * 0.5
	var half: float = deg_to_rad(half_angle_deg)
	var soft: float = deg_to_rad(6.0)
	for y: int in size_px:
		for x: int in size_px:
			var v: Vector2 = Vector2(x, y) + Vector2(0.5, 0.5) - center
			var d: float = v.length() / radius
			var ang: float = absf(v.angle())
			var edge: float = clampf((half - ang) / soft, 0.0, 1.0)
			var a: float = pow(clampf(1.0 - d, 0.0, 1.0), falloff) * edge
			if d < 0.08:
				a = 1.0
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


## 画像素材を読む。大きさが size_px と違えば使わない（texture_scale の計算が狂うため）
static func _load_asset(path: String, size_px: int) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return null
	if tex.get_width() != size_px or tex.get_height() != size_px:
		push_warning("LightTextureGenerator: %s は %dx%d（期待 %dx%d）。生成に切り替えます" % [path, tex.get_width(), tex.get_height(), size_px, size_px])
		return null
	return tex


static func clear_cache() -> void:
	_cache.clear()
