"""タイルアトラス（resources/tilesets/common_atlas.png）をパレット 16 色で描く。

- 種別名・ペインタ名・引数・並び順は tools/tiles/catalog.json（driver_tileset_export が TileCatalog から書き出す）を正とする
- 並びは 16 列、TileCatalog.all_names() のソート順。TileSet 側（common.tres）の座標・物理・カスタムデータと一致する
- 色は scripts/autoload/palette.gd の 16 色だけを使う（インデックスで指定）。霧だけ半透明
- 生成は決定的（座標ハッシュ乱数）。同じ種別は常に同じ絵になる
- 見え方はクォータービュー寄り（RPG 風）。物は 1px の墨の輪郭、光は左上から

使い方: python3 tools/tiles/paint_atlas.py [--out resources/tilesets/common_atlas.png] [--preview build/atlas_x4.png]
"""
import argparse
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
S = 16
COLUMNS = 16

PALETTE = [
    (0x0B, 0x0D, 0x14), (0x14, 0x1A, 0x2B), (0x1F, 0x2A, 0x44), (0x2F, 0x3F, 0x5F), (0x4A, 0x5A, 0x78), (0x85, 0x90, 0xA3),
    (0x1B, 0x2A, 0x24), (0x37, 0x53, 0x3F), (0x6B, 0x8A, 0x5E), (0x3A, 0x2A, 0x22), (0x7A, 0x4A, 0x2E), (0xB0, 0x8A, 0x5C),
    (0xD9, 0xD2, 0xC0), (0xF2, 0xE9, 0xA8), (0xD8, 0x4A, 0x3A), (0x5F, 0xD0, 0xC8),
]
SUMI, NIGHT, DEEP, DUSK, FOG, CONC, MOSS, GREEN, GREEN_L, RUST_D, RUST, OCHRE, BONE, GLOW, RED, FLUO = range(16)

# 各色の「一段暗い／明るい」隣接色（陰影用）
DARKER = {SUMI: SUMI, NIGHT: SUMI, DEEP: NIGHT, DUSK: DEEP, FOG: DUSK, CONC: FOG, MOSS: SUMI, GREEN: MOSS, GREEN_L: GREEN,
          RUST_D: SUMI, RUST: RUST_D, OCHRE: RUST, BONE: CONC, GLOW: OCHRE, RED: RUST_D, FLUO: DEEP}
LIGHTER = {SUMI: NIGHT, NIGHT: DEEP, DEEP: DUSK, DUSK: FOG, FOG: CONC, CONC: BONE, MOSS: GREEN, GREEN: GREEN_L, GREEN_L: OCHRE,
           RUST_D: RUST, RUST: OCHRE, OCHRE: BONE, BONE: BONE, GLOW: BONE, RED: GLOW, FLUO: BONE}


def dk(c):
    return DARKER[c]


def lt(c):
    return LIGHTER[c]


class Tile:
    """16×16 の 1 枚。px は (色インデックス, alpha) を持つ"""

    def __init__(self, seed: int):
        self.p = [[None] * S for _ in range(S)]
        self.seed = seed

    # ── 乱数（座標ハッシュ。決定的） ──
    def rand(self, x, y, k=0):
        h = (x * 374761393 + y * 668265263 + (self.seed + k * 97) * 1442695041) & 0x7FFFFFFF
        h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
        return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0

    # ── プリミティブ ──
    def px(self, x, y, c, a=255):
        if 0 <= x < S and 0 <= y < S and c is not None:
            self.p[y][x] = (c, a)

    def get(self, x, y):
        if 0 <= x < S and 0 <= y < S and self.p[y][x] is not None:
            return self.p[y][x][0]
        return None

    def fill(self, c, a=255):
        for y in range(S):
            for x in range(S):
                self.p[y][x] = (c, a)

    def rect(self, x, y, w, h, c):
        for yy in range(max(y, 0), min(y + h, S)):
            for xx in range(max(x, 0), min(x + w, S)):
                self.p[yy][xx] = (c, 255)

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

    def noise(self, c, density, x0=0, y0=0, w=S, h=S, k=0):
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                if self.rand(x, y, k) < density:
                    self.px(x, y, c)

    def checker(self, x0, y0, w, h, c, phase=0):
        """市松ディザ（半分の画素を c に）"""
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                if (x + y + phase) % 2 == 0:
                    self.px(x, y, c)

    def dither_sparse(self, x0, y0, w, h, c, phase=0):
        """4 画素に 1 つのディザ"""
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                if (x + 2 * y + phase) % 4 == 0:
                    self.px(x, y, c)

    def disc(self, cx, cy, r, c):
        for y in range(S):
            for x in range(S):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    self.px(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(S):
            for x in range(S):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.px(x, y, c)

    def outline(self, target_colors, c, diagonal=False):
        """target_colors に含まれる画素の外側に 1px の輪郭"""
        marks = []
        targets = set(target_colors)
        for y in range(S):
            for x in range(S):
                if self.get(x, y) in targets:
                    continue
                nb = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
                if diagonal:
                    nb += [(x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1), (x + 1, y + 1)]
                if any(self.get(*n) in targets for n in nb):
                    marks.append((x, y))
        for x, y in marks:
            self.px(x, y, c)

    def bevel_rect(self, x, y, w, h, body, hi, sh):
        """箱：本体、上と左が明、下と右が暗"""
        self.rect(x, y, w, h, body)
        self.hline(y, x, x + w - 1, hi)
        self.vline(x, y, y + h - 1, hi)
        self.hline(y + h - 1, x, x + w - 1, sh)
        self.vline(x + w - 1, y, y + h - 1, sh)

    def to_rgba(self):
        img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        for y in range(S):
            for x in range(S):
                v = self.p[y][x]
                if v is not None:
                    c, a = v
                    img.putpixel((x, y), PALETTE[c] + (a,))
        return img


def P(p, k, d):
    return int(p.get(k, d))


def PF(p, k, d):
    return float(p.get(k, d))


def PB(p, k, d):
    return bool(p.get(k, d))


# ─────────────────────────── 地面 ───────────────────────────

def ground(t: Tile, p):
    """平らな地面。粒は散らばりでなく、小さな塊で置く（アスファルトの荒れ、土の凹凸）"""
    base = P(p, "base", DUSK)
    speck = P(p, "speck", FOG)
    density = PF(p, "density", 0.08)
    t.fill(base)
    # 塊：2〜3px の横並び
    for y in range(S):
        for x in range(S):
            r = t.rand(x, y)
            if r < density * 0.6:
                t.px(x, y, speck)
                if t.rand(x, y, 1) < 0.5:
                    t.px(x + 1, y, speck)
    # 影側の粒（少しだけ暗い色）
    t.noise(dk(base), density * 0.35, k=2)


def gravel(t: Tile, p):
    """砂利：2px の小石に明と影"""
    base = P(p, "base", FOG)
    light = P(p, "light", CONC)
    dark = P(p, "dark", DUSK)
    t.fill(base)
    for y in range(0, S, 2):
        for x in range(0, S, 2):
            r = t.rand(x, y)
            ox = 1 if t.rand(x, y, 1) < 0.5 else 0
            if r < 0.30:
                t.px(x + ox, y, light)
                t.px(x + ox + 1, y + 1, dark)
            elif r < 0.55:
                t.px(x + ox, y + 1, dark)
            elif r < 0.62:
                t.px(x + ox, y, light)
                t.px(x + ox + 1, y, light)
                t.px(x + ox, y + 1, dark)
                t.px(x + ox + 1, y + 1, dark)


def grass(t: Tile, p):
    """草地：房ごとに「小さな V」。tall で背が高く影が付く"""
    base = P(p, "base", GREEN)
    blade = P(p, "blade", GREEN_L)
    tall = PB(p, "tall", False)
    shadow = P(p, "shadow", MOSS)
    t.fill(base)
    # 影の斑（地面の凹凸）
    t.noise(dk(base), 0.08, k=3)
    step = 3 if tall else 4
    for gy in range(0, S, step):
        for gx in range(0, S, step):
            if t.rand(gx, gy) < (0.85 if tall else 0.6):
                x = gx + int(t.rand(gx, gy, 1) * step)
                y = gy + int(t.rand(gx, gy, 2) * step)
                hgt = 3 if tall else 2
                t.vline(x, y - hgt + 1, y, blade)
                t.px(x - 1, y - hgt + 2, blade if tall else base)
                t.px(x + 1, y - hgt + 1, blade)
                if tall:
                    t.px(x, y + 1, shadow)
                    t.px(x + 1, y + 1, shadow)


def soil_rows(t: Tile, p):
    """畝：盛り土の山と谷。上面が明るく、谷が暗い"""
    base = P(p, "base", RUST_D)
    ridge = P(p, "ridge", RUST)
    t.fill(base)
    for y in range(0, S, 4):
        t.hline(y, 0, S - 1, ridge)
        t.hline(y + 1, 0, S - 1, ridge)
        t.hline(y + 2, 0, S - 1, dk(base))
        t.hline(y + 3, 0, S - 1, SUMI)
        for x in range(S):
            if t.rand(x, y) < 0.25:
                t.px(x, y, OCHRE)
            if t.rand(x, y, 1) < 0.2:
                t.px(x, y + 1, base)


def path(t: Tile, p):
    """踏み分け道・畦：草の中に土の帯。縁が不揃いで、踏み固められた中央が明るい"""
    g = P(p, "grass", GREEN)
    dirt = P(p, "dirt", RUST_D)
    vertical = PB(p, "vertical", True)
    grass(t, {"base": g, "blade": lt(g)})
    for i in range(S):
        wobble = int(t.rand(i, 0) * 2)
        a, b = 5 + wobble - 1, 10 + int(t.rand(i, 1) * 2)
        for j in range(a, b + 1):
            c = lt(dirt) if (a + 2 <= j <= b - 2 and t.rand(i, j, 2) < 0.55) else dirt
            if vertical:
                t.px(j, i, c)
            else:
                t.px(i, j, c)
    t.noise(OCHRE, 0.04, k=5)


def water(t: Tile, p):
    """水面：横に伸びる波の稜線。flow で流れの筋"""
    base = P(p, "base", DEEP)
    ripple = P(p, "ripple", DUSK)
    glint = P(p, "glint", CONC)
    t.fill(base)
    for y in range(1, S, 4):
        off = int(t.rand(0, y) * 8)
        for x in range(off, S + 8, 9):
            t.hline(y, x, x + 4, ripple)
            t.px(x + 5, y + 1, ripple)
            t.px(x - 1, y - 1, ripple)
    if PB(p, "flow", False):
        for y in range(S):
            for x in range(S):
                if (x + y * 2) % 9 == 0 and t.rand(x, y, 4) < 0.7:
                    t.px(x, y, FOG)
    for y in range(S):
        for x in range(S):
            if t.rand(x, y, 6) < 0.02:
                t.px(x, y, glint)


def paddy(t: Tile, p):
    """水田：水面の上に稲の株（4×4 の格子、株は 3px の房）"""
    water(t, {"base": DEEP, "ripple": DUSK})
    rice = P(p, "rice", GREEN)
    for y in range(3, S, 4):
        for x in range(2, S, 4):
            t.px(x, y, rice)
            t.px(x, y - 1, rice)
            t.px(x - 1, y - 2, GREEN_L)
            t.px(x + 1, y - 2, rice)
            t.px(x, y - 3, GREEN_L)
            t.px(x + 1, y + 1, NIGHT)  # 水に映る影


def paving(t: Tile, p):
    """石畳：不揃いな石に面取り。moss で目地に苔"""
    gap = P(p, "gap", DUSK)
    stone = P(p, "stone", CONC)
    moss = PF(p, "moss", 0.0)
    t.fill(gap)
    for y in range(0, S, 8):
        for x in range(0, S, 8):
            w = 7 - int(t.rand(x, y) * 2)
            h = 7 - int(t.rand(x, y, 1) * 2)
            t.bevel_rect(x, y, w, h, stone, lt(stone) if stone != BONE else BONE, dk(stone))
            t.noise(dk(stone), 0.12, x + 1, y + 1, w - 2, h - 2, k=2)
    if moss > 0:
        for y in range(S):
            for x in range(S):
                if t.get(x, y) == gap and t.rand(x, y, 7) < moss * 3:
                    t.px(x, y, MOSS)
        t.noise(GREEN, moss * 0.6, k=8)


def interlock(t: Tile, p):
    """インターロッキング：2 色のレンガを互い違いに、面取り付き"""
    a = P(p, "a", CONC)
    b = P(p, "b", FOG)
    gap = P(p, "gap", FOG if b != FOG else DUSK)
    t.fill(gap)
    for row, y in enumerate(range(0, S, 4)):
        shift = 4 if row % 2 else 0
        for x in range(-4 + shift, S, 8):
            c = b if ((x // 8) + row) % 2 else a
            t.rect(x + 1, y + 1, 7, 3, c)
            t.hline(y + 1, x + 1, x + 7, lt(c) if c != BONE else c)
            t.vline(x + 7, y + 1, y + 3, dk(c))
            t.hline(y + 3, x + 2, x + 7, dk(c))


# ─────────────────────────── 自然物 ───────────────────────────

def tree(t: Tile, p):
    """広葉樹（クォータービュー）：丸い樹冠を 3 段の明暗で、幹と落ちる影"""
    g = P(p, "ground", MOSS)
    canopy = P(p, "canopy", GREEN)
    shade = P(p, "shade", MOSS)
    trunk = P(p, "trunk", RUST_D)
    t.fill(g)
    t.noise(dk(g), 0.1, k=1)
    # 落ちる影
    t.ellipse(8.0, 13.0, 5.0, 2.0, dk(g) if dk(g) != g else SUMI)
    # 幹
    t.rect(7, 9, 2, 6, trunk)
    t.vline(8, 9, 14, dk(trunk))
    # 樹冠：下段（影）→ 中段 → 上段（光）
    t.ellipse(8.0, 6.0, 6.5, 5.0, shade)
    t.ellipse(7.5, 5.0, 5.5, 4.0, canopy)
    if canopy == OCHRE:
        # イチョウ：明部は骨白を点で（面で塗ると白飛びする）
        t.noise(BONE, 0.3, 3, 2, 7, 4, k=11)
    else:
        t.ellipse(6.5, 4.0, 3.5, 2.5, lt(canopy))
    # 葉のむら
    for y in range(0, 11):
        for x in range(1, 15):
            c = t.get(x, y)
            if c in (canopy, shade) and t.rand(x, y, 2) < 0.18:
                t.px(x, y, shade if c == canopy else canopy)
    # 輪郭
    t.outline([canopy, shade, lt(canopy), BONE], SUMI)
    if "fruit" in p:
        fruit = P(p, "fruit", RUST)
        for i, (x, y) in enumerate([(4, 5), (9, 3), (11, 7), (6, 8), (12, 4)]):
            if t.get(x, y) in (canopy, shade):
                t.px(x, y, fruit)
                t.px(x + 1, y, lt(fruit))
    if "blossom" in p:
        bl = P(p, "blossom", BONE)
        for y in range(0, 11):
            for x in range(1, 15):
                if t.get(x, y) in (canopy, shade, lt(canopy)) and t.rand(x, y, 9) < 0.3:
                    t.px(x, y, bl)


def conifer(t: Tile, p):
    """針葉樹：3 段の三角、右側が影、左に光の縁"""
    g = P(p, "ground", NIGHT)
    leaf = P(p, "leaf", MOSS)
    hi = P(p, "hi", GREEN)
    t.fill(g)
    t.noise(dk(g), 0.1, k=1)
    t.ellipse(8.0, 14.0, 4.0, 1.5, SUMI)
    t.rect(7, 12, 2, 3, RUST_D)
    for row, (y, half) in enumerate([(0, 1), (3, 3), (6, 5), (9, 6)]):
        for yy in range(y, y + 4):
            w = half + (yy - y)
            t.hline(yy, 8 - w, 8 + w - 1, leaf)
            t.px(8 - w, yy, hi)
            t.px(8 + w - 1, yy, dk(leaf))
            t.px(8 + w - 2, yy, dk(leaf))
    t.noise(hi, 0.08, 3, 2, 8, 10, k=4)
    t.outline([leaf, hi, dk(leaf)], SUMI)


def bare_tree(t: Tile, p):
    """裸木：幹から分かれる枝。blossom で枝先に花"""
    g = P(p, "ground", NIGHT)
    wood = P(p, "wood", RUST_D)
    t.fill(g)
    t.noise(dk(g), 0.08, k=1)
    t.ellipse(8.0, 14.0, 4.0, 1.5, SUMI)
    t.rect(7, 8, 2, 7, wood)
    t.vline(8, 8, 14, dk(wood))
    # 枝
    for (x0, y0, x1, y1) in [(7, 8, 4, 4), (8, 8, 11, 3), (7, 6, 5, 2), (9, 6, 12, 5), (5, 4, 3, 1), (11, 3, 13, 1), (8, 5, 8, 2)]:
        n = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(n + 1):
            t.px(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), wood)
    t.outline([wood, dk(wood)], SUMI)
    if "blossom" in p:
        bl = P(p, "blossom", BONE)
        for (x, y) in [(3, 1), (5, 2), (4, 4), (12, 1), (13, 2), (11, 4), (8, 2), (7, 3), (9, 4), (2, 2), (14, 3), (6, 5), (10, 6)]:
            t.px(x, y, bl)
        t.noise(lt(wood), 0.25, 2, 0, 12, 7, k=6)


def rock(t: Tile, p):
    """岩：塊に面と輪郭。左上が明るい"""
    g = P(p, "ground", DUSK)
    base = P(p, "base", FOG)
    hi = P(p, "hi", CONC)
    shade = P(p, "shade", DEEP)
    t.fill(g)
    t.noise(dk(g), 0.1, k=1)
    t.ellipse(8.0, 13.5, 6.0, 1.8, SUMI)
    t.ellipse(8.0, 8.0, 6.0, 4.5, base)
    t.rect(4, 3, 8, 3, base)
    t.ellipse(6.0, 6.0, 3.0, 2.0, hi)
    t.px(4, 4, lt(hi) if hi != BONE else BONE)
    for y in range(8, 13):
        for x in range(6, 14):
            if t.get(x, y) == base and (x + y) % 2 == 0:
                t.px(x, y, shade)
    t.rect(9, 10, 5, 2, shade)
    t.outline([base, hi, shade, lt(hi)], SUMI)


def cliff(t: Tile, p):
    """崖・岩壁：縦の岩の柱、割れ目、ハイライトの縁"""
    base = P(p, "base", DEEP)
    dark = P(p, "dark", NIGHT)
    hi = P(p, "hi", FOG)
    t.fill(base)
    for x in [0, 5, 10, 15]:
        t.vline(x, 0, S - 1, dark)
    for col, (x0, x1) in enumerate([(1, 4), (6, 9), (11, 14)]):
        t.vline(x0, 0, S - 1, hi)
        for y in range(S):
            if t.rand(x0, y, col) < 0.25:
                t.px(x1, y, dark)
    for y in [3, 9, 14]:
        x = int(t.rand(0, y) * 6)
        t.hline(y, x, x + 4 + int(t.rand(1, y) * 5), SUMI)
        t.px(x + 2, y + 1, SUMI)
    t.noise(hi, 0.05, k=3)


def slope(t: Tile, p):
    """斜面：等高線のような斜めの筋。concrete で法面の格子"""
    if PB(p, "concrete", False):
        t.fill(FOG)
        for y in range(0, S, 4):
            t.hline(y, 0, S - 1, DUSK)
        for x in range(0, S, 4):
            t.vline(x, 0, S - 1, DUSK)
        for y in range(0, S, 4):
            for x in range(0, S, 4):
                t.px(x + 1, y + 1, CONC)
                t.noise(dk(FOG), 0.15, x + 1, y + 1, 3, 3, k=x * 16 + y)
        return
    base = P(p, "base", GREEN)
    line = P(p, "line", MOSS)
    t.fill(base)
    t.noise(dk(base), 0.1, k=1)
    for y in range(S):
        for x in range(S):
            if (x + y) % 5 == 0:
                t.px(x, y, line)
            elif (x + y) % 5 == 1 and t.rand(x, y, 2) < 0.4:
                t.px(x, y, lt(base))


def moat(t: Tile, p):
    """空堀：壁が内側へ落ち込み、底は最も暗い"""
    wall = P(p, "wall", RUST_D)
    bottom = P(p, "bottom", SUMI)
    t.fill(wall)
    for i in range(4):
        c = [lt(wall), wall, dk(wall) if dk(wall) != SUMI else NIGHT, bottom][i]
        t.rect(i, i, S - 2 * i, S - 2 * i, c)
    t.rect(4, 4, 8, 8, bottom)
    t.noise(MOSS, 0.12, 0, 0, S, 3, k=2)
    t.noise(MOSS, 0.12, 0, 13, S, 3, k=3)


def stairs(t: Tile, p):
    """石段：踏面と蹴上げ。上から見た段の影"""
    base = P(p, "base", CONC)
    hi = P(p, "hi", BONE)
    sh = P(p, "shade", DUSK)
    t.fill(base)
    for y in range(0, S, 4):
        t.hline(y, 0, S - 1, hi)
        t.hline(y + 1, 0, S - 1, base)
        t.hline(y + 2, 0, S - 1, dk(base))
        t.hline(y + 3, 0, S - 1, sh)
        t.noise(dk(base), 0.12, 0, y + 1, S, 1, k=y)
    if PB(p, "broken", False):
        for y in range(S):
            for x in range(S):
                if t.rand(x, y, 5) < 0.12:
                    t.px(x, y, SUMI)
                elif t.rand(x, y, 6) < 0.08:
                    t.px(x, y, MOSS)
    if PB(p, "rail", False):
        for x in (0, S - 1):
            t.vline(x, 0, S - 1, RUST_D)
        t.vline(1, 0, S - 1, RUST)
        t.vline(S - 2, 0, S - 1, SUMI)


def mound(t: Tile, p):
    """古墳：草の盛土の等高線と石室の口"""
    grass(t, {"base": GREEN, "blade": GREEN_L})
    t.ellipse(8.0, 9.0, 7.5, 6.0, GREEN)
    t.ellipse(8.0, 8.0, 6.0, 4.5, GREEN_L)
    t.ellipse(7.0, 6.0, 3.5, 2.5, lt(GREEN_L))
    for y in range(S):
        for x in range(S):
            if t.get(x, y) in (GREEN_L, OCHRE) and t.rand(x, y, 3) < 0.2:
                t.px(x, y, GREEN)
    t.outline([GREEN_L, OCHRE], MOSS)
    if PB(p, "opening", True):
        t.rect(5, 9, 6, 6, FOG)
        t.rect(6, 10, 4, 5, SUMI)
        t.hline(9, 5, 10, CONC)
        t.px(5, 10, CONC)


def fog(t: Tile, p):
    """霧：半透明。唯一の非不透明タイル"""
    base = P(p, "base", FOG)
    alpha = int(PF(p, "alpha", 0.45) * 255)
    t.fill(base, alpha)
    for y in range(S):
        for x in range(S):
            r = t.rand(x, y)
            if r < 0.15:
                t.px(x, y, CONC, 110)
            elif r < 0.25:
                t.px(x, y, base, alpha - 40)


def crack(t: Tile, p):
    """裂け目：岩壁を縦に走る黒い亀裂。縁にだけ光"""
    cliff(t, p)
    x = 6
    for y in range(S):
        r = t.rand(x, y)
        x = max(3, min(11, x + (1 if r > 0.66 else (-1 if r < 0.33 else 0))))
        w = 2 + (1 if 5 < y < 11 else 0)
        t.rect(x, y, w, 1, SUMI)
        t.px(x - 1, y, FOG)
        t.px(x + w, y, NIGHT)


def spring(t: Tile, p):
    """湧水：岩に囲まれた小さな水面と光"""
    rock(t, {"ground": MOSS, "base": DUSK, "hi": FOG, "shade": DEEP})
    t.ellipse(8.0, 9.0, 4.0, 2.5, DEEP)
    t.hline(8, 6, 9, FOG)
    t.px(7, 7, BONE)
    t.px(10, 9, DUSK)
    t.outline([DEEP], NIGHT)


# ─────────────────────────── 人工物：面 ───────────────────────────

def line_h(t: Tile, p, horizontal=True):
    ground(t, p)
    line = P(p, "line", BONE)
    thick = P(p, "thick", 2)
    pos = P(p, "pos", 7)
    dashed = PB(p, "dashed", False)
    for i in range(S):
        if dashed and (i % 8) >= 5:
            continue
        for k in range(thick):
            x, y = (i, pos + k) if horizontal else (pos + k, i)
            c = CONC if t.rand(x, y, 3) < 0.18 else line  # 擦れ
            t.px(x, y, c)


def line_v(t: Tile, p):
    line_h(t, p, False)


def grating(t: Tile, p):
    base = P(p, "base", FOG)
    ground(t, {"base": base, "speck": lt(base), "density": 0.05})
    t.rect(0, 5, S, 6, CONC)
    t.hline(5, 0, S - 1, BONE)
    t.hline(10, 0, S - 1, DUSK)
    for x in range(1, S, 3):
        t.rect(x, 6, 1, 4, SUMI)
        t.px(x + 1, 6, FOG)


def curb(t: Tile, p):
    walk = P(p, "walk", CONC)
    road = P(p, "road", DUSK)
    interlock(t, {"a": walk, "b": FOG, "gap": FOG})
    t.rect(0, 8, S, 8, road)
    ground_noise = Tile(t.seed)
    ground(ground_noise, {"base": road, "speck": FOG, "density": 0.06})
    for y in range(9, S):
        for x in range(S):
            t.px(x, y, ground_noise.get(x, y))
    t.hline(7, 0, S - 1, BONE)
    t.hline(8, 0, S - 1, FOG)
    t.hline(9, 0, S - 1, SUMI)


def block_wall(t: Tile, p):
    base = P(p, "base", CONC)
    mortar = P(p, "mortar", FOG)
    bw = P(p, "bw", 8)
    bh = P(p, "bh", 4)
    t.fill(base)
    row = 0
    y = 0
    while y < S:
        shift = bw // 2 if row % 2 else 0
        t.hline(y, 0, S - 1, mortar)
        x = shift - bw
        while x < S:
            t.vline(x, y, min(y + bh - 1, S - 1), mortar)
            t.hline(y + 1, x + 1, x + bw - 1, lt(base) if base != BONE else base)
            t.vline(x + bw - 1, y + 1, min(y + bh - 1, S - 1), dk(base))
            x += bw
        y += bh
        row += 1
    t.noise(P(p, "stain", DUSK), PF(p, "stain_density", 0.05), k=4)


def tile_wall(t: Tile, p):
    base = P(p, "base", CONC)
    grout = P(p, "grout", FOG)
    t.fill(grout)
    for y in range(0, S, 4):
        for x in range(0, S, 4):
            t.rect(x + 1, y + 1, 3, 3, base)
            t.px(x + 1, y + 1, lt(base) if base != BONE else base)
            t.px(x + 3, y + 3, dk(base))
            if t.rand(x, y, 2) < 0.15:
                t.px(x + 2, y + 2, dk(base))


def concrete_wall(t: Tile, p):
    base = P(p, "base", CONC)
    stain = PF(p, "stain", 0.3)
    t.fill(base)
    t.noise(lt(base) if base != BONE else base, 0.04, k=1)
    for x in range(S):
        r = t.rand(x, 0)
        if r < stain:
            length = int(t.rand(x, 1) * S)
            t.vline(x, 0, length, dk(base))
            if t.rand(x, 2) < 0.4:
                t.vline(x, 0, max(0, length - 4), dk(dk(base)))
    t.hline(0, 0, S - 1, lt(base) if base != BONE else base)
    t.hline(S - 1, 0, S - 1, dk(dk(base)))
    if stain >= 0.5:
        t.noise(MOSS, 0.06, 0, 8, S, 8, k=5)


def planks(t: Tile, p, vertical):
    base = P(p, "base", RUST)
    gap = P(p, "gap", RUST_D)
    width = P(p, "width", 4)
    worn = PB(p, "worn", False)
    t.fill(base)
    for i in range(0, S, width):
        if vertical:
            t.vline(i, 0, S - 1, gap)
            t.vline(i + 1, 0, S - 1, lt(base) if base != BONE else base)
        else:
            t.hline(i, 0, S - 1, gap)
            t.hline(i + 1, 0, S - 1, lt(base) if base != BONE else base)
    # 木目：板ごとに数本の短い筋
    for i in range(0, S, width):
        for j in range(3):
            pos = int(t.rand(i, j) * S)
            length = 2 + int(t.rand(i, j + 10) * 4)
            off = 2 + int(t.rand(i, j + 20) * max(1, width - 2))
            if vertical:
                t.vline(min(i + off, S - 1), pos, pos + length, dk(base))
            else:
                t.hline(min(i + off, S - 1), pos, pos + length, dk(base))
    if worn:
        t.noise(OCHRE, 0.05, k=7)
        t.noise(SUMI, 0.03, k=8)


def plank_v(t: Tile, p):
    planks(t, p, True)


def plank_h(t: Tile, p):
    planks(t, p, False)


def roof(t: Tile, p):
    """瓦屋根：丸瓦の列（半円の並び）。bark で檜皮葺き"""
    base = P(p, "base", DUSK)
    dark = P(p, "dark", NIGHT)
    hi = P(p, "hi", FOG)
    t.fill(base)
    if PB(p, "bark", False):
        for y in range(S):
            c = dark if y % 3 == 0 else (hi if y % 3 == 1 and t.rand(0, y) < 0.4 else base)
            t.hline(y, 0, S - 1, c)
            for x in range(S):
                if t.rand(x, y, 2) < 0.12:
                    t.px(x, y, dark if c != dark else base)
        return
    for row, y in enumerate(range(0, S, 4)):
        off = 0 if row % 2 == 0 else 2
        t.hline(y, 0, S - 1, dark)
        for x in range(off - 4, S, 4):
            t.px(x + 1, y + 1, hi)
            t.px(x + 2, y + 1, hi)
            t.px(x, y + 1, dark)
            t.px(x + 3, y + 1, dark)
            t.px(x, y + 2, dark)
            t.px(x + 3, y + 2, dark)
            t.px(x + 1, y + 3, base)
            t.hline(y + 3, x, x + 3, dark)
            t.px(x + 1, y + 3, dk(base) if dk(base) != dark else base)


def window(t: Tile, p):
    wall = P(p, "wall", CONC)
    frame = P(p, "frame", SUMI)
    lit = PB(p, "lit", False)
    glow = P(p, "glow", GLOW)
    concrete_wall(t, {"base": wall, "stain": 0.15})
    t.rect(3, 3, 10, 10, frame)
    inner = glow if lit else DEEP
    t.rect(4, 4, 8, 8, inner)
    if lit:
        t.rect(4, 4, 3, 3, BONE)
        t.px(9, 8, lt(glow))
        t.noise(OCHRE, 0.12, 4, 4, 8, 8, k=3)
    else:
        t.px(4, 4, DUSK)
        t.px(5, 4, DUSK)
        t.px(4, 5, DUSK)
        t.dither_sparse(5, 5, 6, 6, NIGHT)
    t.vline(7, 4, 11, frame)
    t.hline(7, 4, 11, frame)
    t.hline(2, 3, 12, lt(wall) if wall != BONE else wall)
    t.hline(13, 3, 12, dk(wall))


def glass(t: Tile, p):
    lit = PB(p, "lit", True)
    glow = P(p, "glow", FLUO)
    t.fill(glow if lit else DEEP)
    if lit:
        t.checker(0, 0, S, S, lt(glow) if glow != BONE else glow, 0)
        t.rect(2, 2, 5, 12, BONE)
        t.rect(9, 3, 5, 10, glow)
        t.noise(glow, 0.3, 2, 2, 5, 12, k=2)
    else:
        t.dither_sparse(0, 0, S, S, DUSK)
        t.vline(2, 1, 14, FOG)
    t.frame(0, 0, S, S, SUMI)
    t.vline(7, 0, S - 1, SUMI)
    t.vline(8, 0, S - 1, SUMI)
    t.hline(1, 1, 6, lt(glow) if lit else DUSK)


def door(t: Tile, p):
    base = P(p, "base", RUST_D)
    knob = P(p, "knob", OCHRE)
    planks(t, {"base": base, "gap": SUMI, "width": 5}, True)
    t.frame(0, 0, S, S, SUMI)
    t.frame(1, 1, S - 2, S - 2, lt(base))
    t.rect(11, 8, 2, 2, knob)
    t.px(12, 9, dk(knob))
    t.hline(14, 2, 13, SUMI)


def shutter(t: Tile, p):
    base = P(p, "base", FOG)
    half = PB(p, "half", False)
    t.fill(base)
    bottom = 10 if half else S
    for y in range(0, bottom, 2):
        t.hline(y, 0, S - 1, DUSK)
        t.hline(y + 1, 0, S - 1, lt(base))
        t.px(0, y + 1, DUSK)
        t.px(S - 1, y + 1, DUSK)
    t.noise(RUST, 0.06, 0, 0, S, bottom, k=2)
    t.noise(RUST_D, 0.03, 0, 0, S, bottom, k=3)
    if half:
        t.rect(0, bottom, S, S - bottom, SUMI)
        t.hline(bottom, 0, S - 1, DUSK)
        t.hline(bottom + 1, 0, S - 1, NIGHT)
        t.px(4, 13, NIGHT)
        t.px(10, 12, NIGHT)
    t.vline(0, 0, S - 1, DUSK)
    t.vline(S - 1, 0, S - 1, DUSK)


def fence(t: Tile, p):
    g = P(p, "ground", DUSK)
    wire = P(p, "wire", CONC)
    ground(t, {"base": g, "speck": lt(g), "density": 0.05})
    for y in range(S):
        for x in range(S):
            if (x + y) % 4 == 0 or (x - y) % 4 == 0:
                t.px(x, y, wire)
    t.rect(0, 0, 2, S, FOG)
    t.vline(0, 0, S - 1, CONC)
    t.hline(0, 0, S - 1, CONC)
    t.hline(1, 2, S - 1, FOG)
    if PB(p, "locked", False):
        t.rect(6, 6, 4, 4, RED)
        t.px(6, 6, lt(RED))
        t.hline(5, 7, 8, CONC)
        t.px(7, 4, CONC)
        t.px(8, 4, CONC)
        t.px(8, 8, SUMI)


def rail(t: Tile, p):
    g = P(p, "ground", DUSK)
    bar = P(p, "bar", CONC)
    post = P(p, "post", FOG)
    double = PB(p, "double", True)
    ground(t, {"base": g, "speck": lt(g), "density": 0.05})
    for x in range(2, S, 6):
        t.vline(x, 3, 14, post)
        t.vline(x + 1, 3, 14, dk(post))
        t.px(x, 15, SUMI)
        t.px(x + 1, 15, SUMI)
    t.rect(0, 5, S, 2, bar)
    t.hline(5, 0, S - 1, lt(bar) if bar != BONE else bar)
    t.hline(7, 0, S - 1, dk(bar))
    if double:
        t.rect(0, 10, S, 2, bar)
        t.hline(10, 0, S - 1, lt(bar) if bar != BONE else bar)
        t.hline(12, 0, S - 1, dk(bar))


def mesh(t: Tile, p):
    g = P(p, "ground", DUSK)
    wire = P(p, "wire", CONC)
    ground(t, {"base": g, "speck": lt(g), "density": 0.06})
    for i in range(0, S, 4):
        t.hline(i, 0, S - 1, wire)
        t.vline(i, 0, S - 1, wire)
    for i in range(0, S, 4):
        for j in range(0, S, 4):
            t.px(i, j, lt(wire) if wire != BONE else wire)
            t.px(i + 1, j + 1, dk(g))


def barricade(t: Tile, p):
    g = P(p, "ground", DUSK)
    ground(t, {"base": g, "speck": lt(g), "density": 0.06})
    t.rect(2, 11, 2, 4, FOG)
    t.rect(12, 11, 2, 4, FOG)
    t.px(3, 15, SUMI)
    t.px(13, 15, SUMI)
    t.rect(0, 4, S, 7, BONE)
    for y in range(4, 11):
        for x in range(S):
            if ((x + y) // 3) % 2 == 0:
                t.px(x, y, RED)
    t.hline(4, 0, S - 1, BONE)
    t.hline(10, 0, S - 1, dk(RED))
    t.frame(0, 4, S, 7, SUMI)


def bridge(t: Tile, p):
    planks(t, {"base": CONC, "gap": FOG, "width": 4}, False)
    t.rect(0, 0, S, 3, FOG)
    t.hline(0, 0, S - 1, BONE)
    t.hline(2, 0, S - 1, DUSK)
    for x in range(1, S, 5):
        t.vline(x, 0, 2, CONC)
    if "glow" in p:
        glow = P(p, "glow", GLOW)
        t.rect(6, 0, 4, 2, glow)
        t.px(7, 0, BONE)
        t.px(8, 0, BONE)
        t.px(5, 1, OCHRE)
        t.px(10, 1, OCHRE)


# ─────────────────────────── 人工物：物 ───────────────────────────

def sign(t: Tile, p):
    wall = P(p, "wall", DUSK)
    board = P(p, "board", OCHRE)
    ink = P(p, "ink", SUMI)
    frame_c = P(p, "frame", RUST_D)
    ground(t, {"base": wall, "speck": lt(wall), "density": 0.05})
    t.rect(6, 13, 4, 2, SUMI)  # 影
    t.rect(7, 12, 2, 4, FOG)
    t.px(8, 12, DUSK)
    t.bevel_rect(1, 2, 14, 11, board, lt(board) if board != BONE else board, dk(board))
    t.frame(1, 2, 14, 11, frame_c)
    for y in range(4, 12, 2):
        w = 3 + int(t.rand(y, 0) * 8)
        t.hline(y, 3, 3 + w, ink)
        if t.rand(y, 1) < 0.4:
            t.px(3 + w + 1, y, ink)
    if "glow" in p:
        t.hline(0, 2, 13, P(p, "glow", GLOW))
        t.hline(1, 3, 12, OCHRE)


def pole(t: Tile, p):
    g = P(p, "ground", DUSK)
    pole_c = P(p, "pole", FOG)
    ground(t, {"base": g, "speck": lt(g), "density": 0.05})
    t.hline(0, 0, S - 1, SUMI)
    t.hline(1, 0, S - 1, SUMI)
    t.hline(2, 0, S - 1, NIGHT)
    t.rect(7, 0, 2, S, pole_c)
    t.vline(7, 0, S - 1, lt(pole_c) if pole_c != BONE else pole_c)
    t.vline(8, 0, S - 1, dk(pole_c))
    t.hline(3, 2, 13, CONC)
    t.hline(4, 3, 12, dk(pole_c))
    for x in (3, 6, 9, 12):
        t.px(x, 2, BONE)
    t.rect(6, 14, 4, 2, SUMI)


def lamp(t: Tile, p):
    g = P(p, "ground", DUSK)
    glow = P(p, "glow", GLOW)
    pole_c = P(p, "pole", FOG)
    ground(t, {"base": g, "speck": lt(g), "density": 0.05})
    if PB(p, "stone", False):
        # 常夜灯：石の台、火袋、笠
        t.rect(5, 13, 6, 3, FOG)
        t.hline(13, 4, 11, CONC)
        t.rect(6, 8, 4, 5, CONC)
        t.vline(6, 8, 12, BONE)
        t.vline(9, 8, 12, DUSK)
        t.rect(4, 3, 8, 4, FOG)
        t.rect(5, 4, 6, 3, glow)
        t.px(6, 4, BONE)
        t.rect(3, 2, 10, 1, CONC)
        t.hline(1, 5, 10, FOG)
        t.px(7, 0, CONC)
        t.px(8, 0, CONC)
        t.rect(2, 7, 12, 1, DUSK)
        t.outline([FOG, CONC, glow, BONE], SUMI)
        return
    # 街灯：光のにじみを地面に
    for y in range(S):
        for x in range(S):
            d = abs(x - 8) + abs(y - 3)
            if d <= 4 and t.rand(x, y, 3) < 0.5 - d * 0.1:
                t.px(x, y, OCHRE if d > 2 else glow)
    t.rect(7, 4, 2, 12, pole_c)
    t.vline(7, 4, 15, lt(pole_c) if pole_c != BONE else pole_c)
    t.vline(8, 4, 15, dk(pole_c))
    t.rect(6, 15, 4, 1, SUMI)
    t.rect(5, 1, 6, 3, glow)
    t.hline(0, 6, 9, CONC)
    t.hline(4, 5, 10, BONE)
    t.px(4, 2, glow)
    t.px(11, 2, glow)
    t.px(6, 1, BONE)
    t.px(7, 1, BONE)


def light_bar(t: Tile, p):
    base = P(p, "base", NIGHT)
    glow = P(p, "glow", FLUO)
    t.fill(base)
    if PB(p, "small", False):
        t.rect(4, 4, 8, 7, SUMI)
        t.rect(5, 5, 6, 5, glow)
        t.rect(6, 6, 4, 2, BONE)
        for y in range(S):
            for x in range(S):
                if t.get(x, y) == base and abs(x - 8) + abs(y - 7) < 7 and t.rand(x, y, 2) < 0.35:
                    t.px(x, y, dk(glow) if dk(glow) != SUMI else DEEP)
        t.frame(4, 4, 8, 7, FOG)
        return
    for y in range(S):
        for x in range(S):
            if abs(y - 7) <= 3 and t.rand(x, y, 2) < 0.5:
                t.px(x, y, DEEP)
    t.rect(1, 6, 14, 3, glow)
    t.rect(2, 7, 12, 1, BONE)
    t.px(1, 6, dk(glow) if dk(glow) != SUMI else DEEP)
    t.px(14, 8, dk(glow) if dk(glow) != SUMI else DEEP)
    t.hline(5, 1, 14, FOG)
    t.hline(9, 1, 14, DUSK)


def vending(t: Tile, p):
    body = P(p, "body", FOG)
    glow = P(p, "glow", GLOW)
    accent = P(p, "accent", RED)
    t.fill(body)
    t.frame(0, 0, S, S, SUMI)
    t.hline(1, 1, 14, CONC)
    t.vline(1, 1, 14, CONC)
    t.rect(2, 2, 9, 7, glow)
    t.rect(3, 3, 7, 5, BONE)
    for row, y in enumerate((3, 6)):
        for x in range(3, 10, 2):
            t.px(x, y, RED if (x + row) % 3 == 0 else (FLUO if (x + row) % 3 == 1 else OCHRE))
            t.px(x, y + 1, dk(BONE))
    t.rect(11, 2, 3, 12, accent)
    t.vline(11, 2, 13, lt(accent))
    t.px(12, 4, BONE)
    t.rect(2, 10, 8, 1, DUSK)
    t.rect(2, 11, 8, 3, SUMI)
    t.hline(11, 3, 8, DUSK)
    t.px(12, 9, SUMI)
    t.px(12, 11, FLUO)
    if PB(p, "broken", False):
        t.rect(2, 2, 9, 7, DEEP)


def box(t: Tile, p):
    g = P(p, "ground", DUSK)
    body = P(p, "body", CONC)
    x, y, w, h = P(p, "x", 3), P(p, "y", 2), P(p, "w", 10), P(p, "h", 12)
    edge = P(p, "edge", SUMI)
    hi = P(p, "hi", BONE)
    ground(t, {"base": g, "speck": lt(g), "density": 0.06})
    t.rect(x + 1, y + h, w, 1, SUMI)  # 落ちる影
    t.rect(x, y, w, h, body)
    t.hline(y + 1, x + 1, x + w - 2, hi)
    t.vline(x + 1, y + 1, y + h - 2, lt(body) if body != BONE else body)
    t.vline(x + w - 2, y + 2, y + h - 2, dk(body))
    t.hline(y + h - 2, x + 2, x + w - 2, dk(body))
    t.frame(x, y, w, h, edge)
    if "accent" in p:
        ah = P(p, "accent_h", 3)
        t.rect(x + 2, y + 3, w - 4, ah, P(p, "accent", FLUO))
        t.hline(y + 3, x + 2, x + w - 3, lt(P(p, "accent", FLUO)))
    if PB(p, "slots", False):
        for yy in range(y + 4, y + h - 2, 3):
            t.hline(yy, x + 2, x + w - 3, SUMI)
            t.hline(yy + 1, x + 2, x + w - 3, lt(body) if body != BONE else body)


def bench(t: Tile, p):
    g = P(p, "ground", DUSK)
    wood = P(p, "wood", RUST)
    ground(t, {"base": g, "speck": lt(g), "density": 0.06})
    t.rect(2, 14, 12, 1, SUMI)
    t.rect(1, 3, 14, 2, wood)
    t.hline(3, 1, 14, lt(wood))
    t.hline(5, 1, 14, dk(wood))
    t.rect(1, 7, 14, 3, wood)
    t.hline(7, 1, 14, lt(wood))
    t.hline(9, 1, 14, dk(wood))
    t.rect(2, 10, 2, 4, dk(wood))
    t.rect(12, 10, 2, 4, dk(wood))
    t.vline(2, 10, 13, wood)
    t.vline(12, 10, 13, wood)
    t.outline([wood, lt(wood), dk(wood)], SUMI)


def tower(t: Tile, p):
    g = P(p, "ground", NIGHT)
    frame_c = P(p, "frame", FOG)
    ground(t, {"base": g, "speck": lt(g), "density": 0.05})
    t.vline(4, 0, S - 1, frame_c)
    t.vline(5, 0, S - 1, dk(frame_c))
    t.vline(10, 0, S - 1, frame_c)
    t.vline(11, 0, S - 1, dk(frame_c))
    for y in range(2, S, 4):
        t.hline(y, 4, 11, frame_c)
        for i in range(4):
            t.px(6 + i, y + 1 + i % 3, dk(frame_c))
            t.px(9 - i, y + 1 + i % 3, dk(frame_c))
    t.rect(3, 14, 10, 2, SUMI)
    if "top" in p:
        top = P(p, "top", CONC)
        t.rect(2, 0, 12, 4, top)
        t.hline(0, 2, 13, lt(top) if top != BONE else top)
        t.hline(3, 2, 13, dk(top))
        t.vline(13, 0, 3, dk(top))
        t.frame(2, 0, 12, 4, SUMI)
    if "glow" in p:
        glow = P(p, "glow", GLOW)
        t.rect(5, 1, 6, 2, glow)
        t.px(6, 1, BONE)
        t.px(9, 1, BONE)
        t.px(4, 3, OCHRE)
        t.px(11, 3, OCHRE)


def car(t: Tile, p):
    g = P(p, "ground", DUSK)
    body = P(p, "body", DEEP)
    ground(t, {"base": g, "speck": lt(g), "density": 0.06})
    t.rect(1, 13, 14, 2, SUMI)
    t.rect(1, 5, 14, 8, body)
    t.rect(3, 2, 10, 3, body)
    t.rect(4, 3, 8, 2, NIGHT)
    t.px(4, 3, FOG)
    t.px(5, 3, DUSK)
    t.hline(5, 1, 14, lt(body))
    t.hline(2, 3, 12, lt(body))
    t.hline(12, 1, 14, NIGHT)
    t.rect(1, 12, 3, 3, SUMI)
    t.rect(12, 12, 3, 3, SUMI)
    t.px(2, 13, FOG)
    t.px(13, 13, FOG)
    t.px(2, 9, OCHRE)
    t.px(13, 9, RED)
    t.outline([body, lt(body), NIGHT], SUMI)


def slab(t: Tile, p):
    g = P(p, "ground", DUSK)
    stone = P(p, "stone", CONC)
    w = P(p, "w", 6)
    base = P(p, "base", FOG)
    x = (S - w) // 2
    ground(t, {"base": g, "speck": lt(g), "density": 0.06})
    t.rect(x - 1, 13, w + 2, 3, base)
    t.hline(13, x - 1, x + w, lt(base) if base != BONE else base)
    t.hline(15, x - 1, x + w, SUMI)
    t.rect(x, 2, w, 12, stone)
    t.vline(x, 2, 13, lt(stone) if stone != BONE else BONE)
    t.hline(2, x, x + w - 1, lt(stone) if stone != BONE else BONE)
    t.vline(x + w - 1, 3, 13, dk(stone))
    t.noise(dk(stone), 0.1, x + 1, 3, max(1, w - 2), 10, k=2)
    if PB(p, "marks", True):
        for y in range(4, 12, 3):
            t.hline(y, x + 2, x + w - 3, SUMI)
    if PB(p, "cow", False):
        t.rect(2, 7, 12, 6, stone)
        t.rect(1, 5, 4, 4, stone)
        t.hline(7, 2, 13, lt(stone))
        t.hline(5, 1, 4, lt(stone))
        t.px(2, 6, SUMI)
        t.px(0, 5, dk(stone))
        t.rect(3, 13, 2, 2, dk(stone))
        t.rect(11, 13, 2, 2, dk(stone))
        t.outline([stone, lt(stone), dk(stone)], SUMI)
    else:
        t.outline([stone, lt(stone), dk(stone)], SUMI)
    t.noise(P(p, "moss", MOSS), PF(p, "moss_density", 0.0), x, 6, w, 8, k=5)


def torii(t: Tile, p):
    g = P(p, "ground", DUSK)
    wood = P(p, "wood", RUST)
    ground(t, {"base": g, "speck": lt(g), "density": 0.06})
    t.rect(3, 4, 2, 12, wood)
    t.rect(11, 4, 2, 12, wood)
    t.vline(3, 4, 15, lt(wood))
    t.vline(12, 4, 15, dk(wood))
    t.rect(1, 1, 14, 2, wood)
    t.hline(0, 1, 14, lt(wood))
    t.px(0, 1, wood)
    t.px(15, 1, wood)
    t.hline(2, 1, 14, dk(wood))
    t.rect(2, 5, 12, 1, wood)
    t.hline(6, 2, 13, dk(wood))
    t.rect(7, 3, 2, 2, wood)
    t.rect(2, 15, 4, 1, SUMI)
    t.rect(10, 15, 4, 1, SUMI)
    t.outline([wood, lt(wood), dk(wood)], SUMI)


def gate(t: Tile, p):
    g = P(p, "ground", DUSK)
    post = P(p, "post", RUST_D)
    ground(t, {"base": g, "speck": lt(g), "density": 0.06})
    t.rect(1, 2, 3, 14, post)
    t.rect(12, 2, 3, 14, post)
    t.vline(1, 2, 15, lt(post))
    t.vline(12, 2, 15, lt(post))
    t.vline(3, 2, 15, dk(post) if dk(post) != SUMI else NIGHT)
    t.vline(14, 2, 15, dk(post) if dk(post) != SUMI else NIGHT)
    if PB(p, "roof", True):
        rc = P(p, "roof_color", NIGHT)
        t.rect(0, 0, S, 3, rc)
        t.hline(0, 0, S - 1, lt(rc))
        t.hline(2, 0, S - 1, dk(rc) if dk(rc) != rc else SUMI)
        t.hline(3, 0, S - 1, FOG)
        for x in range(1, S, 3):
            t.px(x, 1, lt(rc))
        t.rect(4, 4, 8, 12, NIGHT)  # 門の内側の闇
        t.dither_sparse(4, 4, 8, 12, DEEP)
    else:
        bar = P(p, "bar", FOG)
        for y in range(5, 14, 3):
            t.hline(y, 4, 11, bar)
            t.hline(y + 1, 4, 11, dk(bar))
        t.vline(7, 5, 13, bar)
        t.vline(8, 5, 13, dk(bar))
    t.outline([post, lt(post)], SUMI)


def masks(t: Tile, p):
    g = P(p, "ground", NIGHT)
    ground(t, {"base": g, "speck": lt(g), "density": 0.05})
    for i in range(3):
        y = 1 + i * 5
        x = 2 + (i % 2) * 3
        t.ellipse(x + 4.0, y + 2.5, 4.5, 2.7, OCHRE)
        t.hline(y, x + 2, x + 6, BONE)
        t.px(x + 1, y + 1, BONE)
        t.px(x + 2, y + 2, SUMI)
        t.px(x + 3, y + 2, SUMI)
        t.px(x + 5, y + 2, SUMI)
        t.px(x + 6, y + 2, SUMI)
        t.hline(y + 4, x + 2, x + 6, RUST)
        t.px(x + 4, y + 3, RUST)
        t.outline([OCHRE, BONE], SUMI)


def slide(t: Tile, p):
    ground(t, {"base": OCHRE, "speck": RUST, "density": 0.08})
    t.rect(1, 14, 8, 2, dk(OCHRE))
    t.rect(1, 6, 8, 8, CONC)
    t.rect(2, 3, 5, 4, CONC)
    t.rect(9, 8, 6, 2, CONC)
    t.rect(13, 10, 2, 5, CONC)
    t.hline(6, 1, 8, BONE)
    t.hline(3, 2, 6, BONE)
    t.hline(8, 9, 14, BONE)
    t.vline(8, 7, 13, FOG)
    t.vline(14, 10, 14, FOG)
    t.px(3, 4, SUMI)
    t.px(1, 5, CONC)
    t.px(0, 6, CONC)
    t.outline([CONC, BONE, FOG], SUMI)


def fallback(t: Tile, p):
    t.fill(DEEP)
    t.frame(0, 0, S, S, RED)
    t.rect(5, 5, 6, 6, SUMI)


PAINTERS = {
    "ground": ground, "gravel": gravel, "grass": grass, "soil_rows": soil_rows, "path": path, "water": water, "paddy": paddy,
    "paving": paving, "interlock": interlock, "tree": tree, "conifer": conifer, "bare_tree": bare_tree, "rock": rock, "cliff": cliff,
    "slope": slope, "moat": moat, "stairs": stairs, "mound": mound, "fog": fog, "crack": crack, "spring": spring,
    "line_h": line_h, "line_v": line_v, "grating": grating, "curb": curb, "block_wall": block_wall, "tile_wall": tile_wall,
    "concrete_wall": concrete_wall, "plank_v": plank_v, "plank_h": plank_h, "roof": roof, "window": window, "glass": glass,
    "door": door, "shutter": shutter, "fence": fence, "rail": rail, "mesh": mesh, "barricade": barricade, "bridge": bridge,
    "sign": sign, "pole": pole, "lamp": lamp, "light_bar": light_bar, "vending": vending, "box": box, "bench": bench, "tower": tower,
    "car": car, "slab": slab, "torii": torii, "gate": gate, "masks": masks, "slide": slide, "fallback": fallback,
}


def seed_of(name: str) -> int:
    h = 0
    for ch in name:
        h = (h * 31 + ord(ch)) & 0x7FFFFFFF
    return h


def paint_tile(name: str, entry: dict) -> Tile:
    t = Tile(seed_of(name))
    painter = PAINTERS.get(entry.get("painter", "fallback"), fallback)
    painter(t, entry.get("args", {}))
    return t


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--catalog", default=os.path.join(HERE, "catalog.json"))
    ap.add_argument("--out", default=os.path.join(ROOT, "resources", "tilesets", "common_atlas.png"))
    ap.add_argument("--preview", default="")
    ap.add_argument("--scale", type=int, default=4)
    a = ap.parse_args()
    catalog = json.load(open(a.catalog, encoding="utf-8"))
    names = list(catalog.keys())
    assert names == sorted(names), "catalog.json の並びが TileCatalog.all_names() のソート順と違う"
    rows = (len(names) + COLUMNS - 1) // COLUMNS
    atlas = Image.new("RGBA", (COLUMNS * S, rows * S), (0, 0, 0, 0))
    for i, name in enumerate(names):
        tile = paint_tile(name, catalog[name])
        atlas.paste(tile.to_rgba(), ((i % COLUMNS) * S, (i // COLUMNS) * S))
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    atlas.save(a.out)
    print(f"{a.out}: {len(names)} tiles, {atlas.width}x{atlas.height}")
    if a.preview:
        bg = Image.new("RGBA", atlas.size, (30, 30, 30, 255))
        bg.alpha_composite(atlas)
        bg.resize((atlas.width * a.scale, atlas.height * a.scale), Image.NEAREST).save(a.preview)
        print("preview:", a.preview)
    return 0


if __name__ == "__main__":
    sys.exit(main())
