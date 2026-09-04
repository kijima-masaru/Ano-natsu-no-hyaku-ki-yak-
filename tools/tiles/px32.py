"""32×32 のタイルを自由な色数で描くための土台（キャンバス・色・プリミティブ）。

paint_atlas.py（16 px・16 色）の後継。色は RGB を直接扱い、パレットに縛られない。
生成は決定的（座標ハッシュ乱数）。光は左上から。物は暗い輪郭で地面から切り離す。
"""
import math

from PIL import Image

S = 32


# ─────────────── 色 ───────────────

def rgb(h: str):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def shade(c, k):
    """k<0 で暗く、k>0 で明るく（-1..1）。暗くするときは少し青へ、明るくするときは少し黄へ寄せる（夜の色）"""
    if k < 0:
        return mix(c, (8, 10, 22), -k)
    return mix(c, (250, 240, 200), k)


def sat(c, k):
    """彩度を上げ下げ（k: -1..1）"""
    g = (c[0] * 299 + c[1] * 587 + c[2] * 114) // 1000
    return tuple(max(0, min(255, int(round(g + (c[i] - g) * (1 + k))))) for i in range(3))


# 夜の町の基本色（参考画像の色域に寄せる）
C = {
    "sumi": rgb("#0b0d14"), "night": rgb("#141a2b"), "deep": rgb("#1f2a44"), "dusk": rgb("#2f3f5f"), "fog": rgb("#4a5a78"), "conc": rgb("#8590a3"),
    "bone": rgb("#d9d2c0"), "glow": rgb("#f2e9a8"), "red": rgb("#d84a3a"), "fluo": rgb("#5fd0c8"),
    "asphalt": rgb("#3a4560"), "asphalt_l": rgb("#4b5875"), "asphalt_d": rgb("#2c364f"),
    "stone": rgb("#7d8698"), "stone_l": rgb("#a2aabb"), "stone_d": rgb("#565e70"),
    "brick": rgb("#8a5b47"), "brick_l": rgb("#a87560"), "brick_d": rgb("#5e3c2f"), "mortar": rgb("#3e3a40"),
    "wood": rgb("#7a4a2e"), "wood_l": rgb("#a06a44"), "wood_d": rgb("#4a2c1c"), "wood_dd": rgb("#2c1a10"),
    "plaster": rgb("#cfc4ad"), "plaster_d": rgb("#9e957f"),
    "tile_roof": rgb("#4b5069"), "tile_roof_l": rgb("#6a7089"), "tile_roof_d": rgb("#2f3347"),
    "grass": rgb("#3c5a3a"), "grass_l": rgb("#5d7d4a"), "grass_ll": rgb("#8aa05a"), "grass_d": rgb("#26402a"), "grass_dd": rgb("#172a1c"),
    "soil": rgb("#6a4a30"), "soil_l": rgb("#8a6542"), "soil_d": rgb("#46301f"),
    "water": rgb("#1d2b4a"), "water_l": rgb("#2d4370"), "water_ll": rgb("#5b7cae"), "water_d": rgb("#121a31"),
    "leaf": rgb("#3f6a3c"), "leaf_l": rgb("#63914d"), "leaf_ll": rgb("#93b565"), "leaf_d": rgb("#264a2c"), "leaf_dd": rgb("#152d1b"),
    "pine": rgb("#2c4d3a"), "pine_l": rgb("#457057"), "pine_d": rgb("#1b3226"),
    "metal": rgb("#6f7787"), "metal_l": rgb("#9aa2b1"), "metal_d": rgb("#454b58"),
    "rust": rgb("#8b4e2e"), "rust_l": rgb("#b06e3e"), "rust_d": rgb("#5b3320"),
    "ochre": rgb("#b08a5c"), "ochre_l": rgb("#d0ac78"), "ochre_d": rgb("#7e6140"),
    "straw": rgb("#c6a45a"), "straw_l": rgb("#e0c47a"), "straw_d": rgb("#8b7238"),
}


class Canvas:
    def __init__(self, w=S, h=S, seed=0):
        self.w, self.h = w, h
        self.p = [[None] * w for _ in range(h)]
        self.seed = seed

    # ── 乱数 ──
    def rand(self, x, y, k=0):
        h = (x * 374761393 + y * 668265263 + (self.seed + k * 97) * 1442695041) & 0x7FFFFFFF
        h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
        return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0

    def noise2(self, x, y, scale=8.0, k=0):
        """滑らかなノイズ（格子の乱数を双線形補間）0..1"""
        gx, gy = x / scale, y / scale
        x0, y0 = math.floor(gx), math.floor(gy)
        fx, fy = gx - x0, gy - y0
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        v00, v10 = self.rand(x0, y0, k), self.rand(x0 + 1, y0, k)
        v01, v11 = self.rand(x0, y0 + 1, k), self.rand(x0 + 1, y0 + 1, k)
        return (v00 * (1 - fx) + v10 * fx) * (1 - fy) + (v01 * (1 - fx) + v11 * fx) * fy

    # ── 画素 ──
    def px(self, x, y, c, a=255):
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            self.p[int(y)][int(x)] = (tuple(c), a)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h and self.p[int(y)][int(x)] is not None:
            return self.p[int(y)][int(x)][0]
        return None

    def blend(self, x, y, c, t):
        cur = self.get(x, y)
        if cur is None:
            self.px(x, y, c)
        else:
            self.px(x, y, mix(cur, c, t))

    def fill(self, c, a=255):
        for y in range(self.h):
            for x in range(self.w):
                self.p[y][x] = (tuple(c), a)

    def rect(self, x, y, w, h, c):
        for yy in range(max(y, 0), min(y + h, self.h)):
            for xx in range(max(x, 0), min(x + w, self.w)):
                self.p[yy][xx] = (tuple(c), 255)

    def frame(self, x, y, w, h, c):
        self.hline(y, x, x + w - 1, c)
        self.hline(y + h - 1, x, x + w - 1, c)
        self.vline(x, y, y + h - 1, c)
        self.vline(x + w - 1, y, y + h - 1, c)

    def hline(self, y, x0, x1, c):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.px(x, y, c)

    def vline(self, x, y0, y1, c):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.px(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            self.px(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)

    def disc(self, cx, cy, r, c):
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                    self.px(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.px(x, y, c)

    def poly(self, pts, c):
        ys = [p[1] for p in pts]
        for y in range(max(0, int(min(ys))), min(self.h, int(max(ys)) + 1)):
            xs = []
            n = len(pts)
            for i in range(n):
                (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % n]
                if (y0 <= y < y1) or (y1 <= y < y0):
                    xs.append(x0 + (y - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                self.hline(y, int(math.ceil(xs[i])), int(math.floor(xs[i + 1])), c)

    def noise(self, c, density, x0=0, y0=0, w=None, h=None, k=0, t=1.0):
        w = self.w if w is None else w
        h = self.h if h is None else h
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                if self.rand(x, y, k) < density:
                    if t >= 1.0:
                        self.px(x, y, c)
                    else:
                        self.blend(x, y, c, t)

    def texture(self, x0, y0, w, h, base, amp=0.12, scale=6.0, k=0, dark=None, light=None):
        """滑らかなノイズで明暗のむらを付ける。dark/light を指定すると 2 色の間で補間"""
        dark = shade(base, -amp) if dark is None else dark
        light = shade(base, amp) if light is None else light
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                v = self.noise2(x, y, scale, k)
                self.px(x, y, mix(dark, light, v))

    def gradient_v(self, x0, y0, w, h, top, bottom):
        for y in range(y0, y0 + h):
            t = (y - y0) / max(1, h - 1)
            self.hline(y, x0, x0 + w - 1, mix(top, bottom, t))

    def gradient_h(self, x0, y0, w, h, left, right):
        for x in range(x0, x0 + w):
            t = (x - x0) / max(1, w - 1)
            self.vline(x, y0, y0 + h - 1, mix(left, right, t))

    def dither(self, x0, y0, w, h, c, density=0.5, k=0):
        """規則ディザ（Bayer 4×4）で c を混ぜる"""
        bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                if bayer[y % 4][x % 4] / 16.0 < density:
                    self.px(x, y, c)

    def outline(self, is_target, c, diagonal=False):
        """is_target(x,y) が真の領域の外側に 1px の輪郭"""
        marks = []
        for y in range(self.h):
            for x in range(self.w):
                if is_target(x, y):
                    continue
                nb = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
                if diagonal:
                    nb += [(x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1), (x + 1, y + 1)]
                if any(0 <= nx < self.w and 0 <= ny < self.h and is_target(nx, ny) for nx, ny in nb):
                    marks.append((x, y))
        for x, y in marks:
            self.px(x, y, c)

    def shadow_ellipse(self, cx, cy, rx, ry, strength=0.45):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
                if d <= 1.0:
                    self.blend(x, y, C["sumi"], strength * (1.0 - d * 0.5))

    def paste(self, other, x0, y0):
        for y in range(other.h):
            for x in range(other.w):
                v = other.p[y][x]
                if v is not None and v[1] > 0:
                    if v[1] >= 255:
                        self.px(x0 + x, y0 + y, v[0])
                    else:
                        self.blend(x0 + x, y0 + y, v[0], v[1] / 255.0)

    def to_image(self):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        px = img.load()
        for y in range(self.h):
            for x in range(self.w):
                v = self.p[y][x]
                if v is not None:
                    px[x, y] = v[0] + (v[1],)
        return img


def seed_of(name: str) -> int:
    h = 0
    for ch in name:
        h = (h * 31 + ord(ch)) & 0x7FFFFFFF
    return h
