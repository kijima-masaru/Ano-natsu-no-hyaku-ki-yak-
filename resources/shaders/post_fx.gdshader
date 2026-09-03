// 画面効果（ScreenFx が最前面の CanvasLayer に敷く矩形に付ける）。
// - にじみ（ブルーム）：粗い LOD から明るい部分だけ取り出して足す。街灯・自販機・窓の光がにじむ
// - 上下端のぼかし（被写界深度風）：画面中央の帯は鮮明、上下端に向けてぼかす
// - 周辺減光：四隅を暗く。夜ほど強い
// 整数倍拡大した画素を崩さないよう、ぼかしの単位は元絵の 1 px（scale = 窓の高さ / 基準の高さ）。
shader_type canvas_item;
render_mode blend_disabled, unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float scale = 3.0;
uniform float bloom_strength : hint_range(0.0, 1.0) = 0.35;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.55;
uniform float blur_strength : hint_range(0.0, 2.0) = 1.0;
uniform float blur_band : hint_range(0.0, 1.0) = 0.25;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float darkness : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float base_lod = log2(max(scale, 1.0));
	vec3 col = texture(screen_tex, uv).rgb;
	// 上下端のぼかし
	float d = abs(uv.y - 0.5) * 2.0;
	float t = smoothstep(blur_band, 1.0, d) * blur_strength;
	if (t > 0.001) {
		vec3 blurred = textureLod(screen_tex, uv, base_lod + 1.0 + t * 1.5).rgb;
		col = mix(col, blurred, clamp(t, 0.0, 1.0) * 0.85);
	}
	// にじみ
	vec3 b1 = textureLod(screen_tex, uv, base_lod + 2.0).rgb;
	vec3 b2 = textureLod(screen_tex, uv, base_lod + 3.5).rgb;
	vec3 bright = max(b1 * 0.5 + b2 * 0.5 - vec3(bloom_threshold), vec3(0.0)) / max(1.0 - bloom_threshold, 0.01);
	col += bright * bloom_strength * (0.6 + 0.4 * darkness);
	// 周辺減光
	vec2 v = uv - vec2(0.5);
	float r = dot(v, v) * 4.0;
	col *= 1.0 - vignette * smoothstep(0.35, 1.6, r) * (0.7 + 0.3 * darkness);
	COLOR = vec4(col, 1.0);
}
