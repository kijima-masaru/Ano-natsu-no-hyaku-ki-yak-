class_name LightTextureGenerator
extends RefCounted
## PointLight2D 用の減衰テクスチャをプロシージャルに生成する（画像素材が無いための暫定。差し替え境界はここだけ）。
## radial: 中心が最も明るい円形。cone: +X 方向へ開く扇形（Player の懐中電灯。向きはノード側の rotation で回す）。
## 白のグレースケールで描き、色は PointLight2D.color（Palette の光源色）で付ける。

static var _cache: Dictionary = {}


## 直径 size_px の円形減衰。falloff が大きいほど中心に光が集まる
static func radial(size_px: int, falloff: float = 1.6) -> ImageTexture:
	var key: String = "radial:%d:%.2f" % [size_px, falloff]
	if _cache.has(key):
		return _cache[key]
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
static func cone(size_px: int, half_angle_deg: float, falloff: float = 1.2) -> ImageTexture:
	var key: String = "cone:%d:%.1f:%.2f" % [size_px, half_angle_deg, falloff]
	if _cache.has(key):
		return _cache[key]
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


static func clear_cache() -> void:
	_cache.clear()
