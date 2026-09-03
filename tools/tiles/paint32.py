"""32×32・自由な色数のタイルアトラスを描く（高精細化 2/4）。

- 種別名・引数・並びは tools/tiles/catalog.json（TileCatalog の写し）
- 出力：resources/tilesets/common_atlas.png と resources/tilesets/atlas_layout.json（種別名 → 座標、変種、背の高い部品）。
  common.tres は driver_tileset_export が layout から組む
- オートタイル：AUTOTILE に挙げた種別は 4 近傍の同種ビット（N=1 E=2 S=4 W=8）ごとに 16 変種を描く。
  ゲーム側（TileVariants）が隣接から変種を選ぶ
- 背の高い部品：TALL に挙げた種別は 32×64 で描き、上半分を Overhead 層用の別タイル（<name>#top）として登録する

使い方: python3 tools/tiles/paint32.py [--preview build/atlas32_x3.png]
"""
import argparse
import json
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from px32 import C, Canvas, S, mix, rgb, sat, seed_of, shade  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
COLUMNS = 16

N, E, SO, W = 1, 2, 4, 8


# ═══════════════════════════ 地面 ═══════════════════════════

def asphalt(c: Canvas, p, tone=None, warm=False, wet=False):
    """アスファルト：粒の細かいむら、ひび、補修の帯。tone で明るさ"""
    base = C["asphalt"] if tone is None else tone
    c.texture(0, 0, S, S, base, 0.10, 7.0, k=1)
    for y in range(S):
        for x in range(S):
            r = c.rand(x, y, 2)
            if r < 0.06:
                c.px(x, y, shade(base, 0.18))
            elif r < 0.11:
                c.px(x, y, shade(base, -0.22))
            elif warm and r < 0.13:
                c.px(x, y, mix(base, C["rust_d"], 0.5))
    # 補修の帯（まれ）
    if c.rand(1, 1, 3) < 0.35:
        y0 = int(c.rand(2, 2, 3) * S)
        for y in range(y0, min(S, y0 + 4 + int(c.rand(3, 3, 3) * 6))):
            for x in range(S):
                if c.noise2(x, y, 5.0, 4) < 0.6:
                    c.blend(x, y, shade(base, -0.12), 0.7)
    # ひび
    if c.rand(4, 4, 5) < 0.6:
        x, y = int(c.rand(5, 5, 5) * S), 0
        while y < S:
            c.px(x, y, shade(base, -0.4))
            if c.rand(x, y, 6) < 0.3:
                c.px(x + 1, y, shade(base, -0.3))
            x = max(0, min(S - 1, x + (1 if c.rand(x, y, 7) > 0.6 else (-1 if c.rand(y, x, 7) > 0.6 else 0))))
            y += 1
            if c.rand(x, y, 8) < 0.06:
                break
    if wet:
        for y in range(S):
            for x in range(S):
                if c.noise2(x, y, 9.0, 9) > 0.62:
                    c.blend(x, y, C["water_ll"], 0.18)


def concrete(c: Canvas, p, tone=None, stain=0.3):
    base = C["conc"] if tone is None else tone
    c.texture(0, 0, S, S, base, 0.08, 9.0, k=1)
    c.noise(shade(base, 0.12), 0.05, k=2)
    c.noise(shade(base, -0.15), 0.04, k=3)
    for x in range(S):
        if c.rand(x, 0, 4) < stain:
            length = int(c.rand(x, 1, 4) * S)
            for y in range(0, length):
                c.blend(x, y, shade(base, -0.25), 0.6 * (1 - y / max(1, length)))


def soil(c: Canvas, p, tone=None, pebbles=0.05):
    base = C["soil"] if tone is None else tone
    c.texture(0, 0, S, S, base, 0.14, 6.0, k=1)
    for y in range(S):
        for x in range(S):
            r = c.rand(x, y, 2)
            if r < pebbles:
                c.px(x, y, shade(base, 0.3))
                c.px(x + 1, y + 1, shade(base, -0.3))
            elif r < pebbles + 0.08:
                c.px(x, y, shade(base, -0.2))
    # 踏み跡（大きな明暗）
    for y in range(S):
        for x in range(S):
            v = c.noise2(x, y, 12.0, 5)
            if v > 0.65:
                c.blend(x, y, shade(base, 0.1), 0.5)


def sand(c: Canvas, p):
    base = mix(C["ochre"], C["conc"], 0.35)
    c.texture(0, 0, S, S, base, 0.08, 8.0, k=1)
    c.noise(shade(base, 0.15), 0.06, k=2)
    c.noise(shade(base, -0.15), 0.05, k=3)


def gravel(c: Canvas, p, base=None, light=None, dark=None):
    base = C["fog"] if base is None else base
    light = shade(base, 0.3) if light is None else light
    dark = shade(base, -0.3) if dark is None else dark
    c.texture(0, 0, S, S, base, 0.08, 5.0, k=1)
    for y in range(0, S, 2):
        for x in range(0, S, 2):
            r = c.rand(x, y, 2)
            ox, oy = int(c.rand(x, y, 3) * 2), int(c.rand(x, y, 4) * 2)
            if r < 0.35:
                c.px(x + ox, y + oy, light)
                c.px(x + ox + 1, y + oy + 1, dark)
            elif r < 0.55:
                c.px(x + ox, y + oy, dark)
            elif r < 0.62:
                c.rect(x + ox, y + oy, 2, 2, light)
                c.px(x + ox + 1, y + oy + 1, dark)
                c.px(x + ox + 2, y + oy + 2, dark)


def grass(c: Canvas, p, base=None, blade=None, tall=False, dry=False):
    base = C["grass"] if base is None else base
    blade = C["grass_l"] if blade is None else blade
    c.texture(0, 0, S, S, base, 0.12, 6.0, k=1, dark=shade(base, -0.25), light=shade(base, 0.05))
    step = 3 if tall else 4
    for gy in range(-2, S, step):
        for gx in range(-2, S, step):
            if c.rand(gx, gy, 2) < (0.9 if tall else 0.65):
                x = gx + int(c.rand(gx, gy, 3) * step)
                y = gy + int(c.rand(gx, gy, 4) * step)
                h = 4 if tall else 3
                col = mix(blade, C["straw"], 0.5) if dry and c.rand(gx, gy, 9) < 0.5 else blade
                c.vline(x, y - h + 1, y, col)
                c.px(x - 1, y - h + 2, shade(col, -0.15))
                c.px(x + 1, y - h + 1, shade(col, 0.1))
                c.px(x, y - h, shade(col, 0.2))
                if tall:
                    c.px(x + 1, y + 1, shade(base, -0.35))
                    c.px(x, y + 1, shade(base, -0.35))
    for i in range(3):
        if c.rand(i, 30, 5) < 0.3:
            c.px(int(c.rand(i, 31, 5) * S), int(c.rand(i, 32, 5) * S), C["bone"] if not dry else C["straw_l"])


def moss(c: Canvas, p):
    grass(c, p, base=C["grass_d"], blade=C["grass"], tall=False)
    for y in range(S):
        for x in range(S):
            if c.noise2(x, y, 5.0, 7) > 0.6:
                c.blend(x, y, C["grass_l"], 0.4)


def water(c: Canvas, p, flow=False, ripple=None):
    base = C["water"]
    c.texture(0, 0, S, S, base, 0.12, 8.0, k=1, dark=C["water_d"], light=C["water_l"])
    for y in range(2, S, 6):
        off = int(c.rand(0, y, 2) * 12)
        for x in range(off - 12, S + 12, 14):
            c.hline(y, x, x + 6, C["water_l"])
            c.px(x + 7, y + 1, C["water_l"])
            c.px(x - 1, y - 1, C["water_l"])
            c.px(x + 2, y, C["water_ll"])
    if flow:
        for y in range(S):
            for x in range(S):
                if (x + y * 3) % 13 == 0 and c.rand(x, y, 4) < 0.7:
                    c.px(x, y, mix(C["water_l"], C["water_ll"], 0.5))
    for y in range(S):
        for x in range(S):
            if c.rand(x, y, 6) < 0.012:
                c.px(x, y, C["water_ll"])


def paddy(c: Canvas, p):
    water(c, p)
    for y in range(6, S, 8):
        for x in range(4, S, 8):
            c.px(x + 1, y + 1, C["water_d"])
            c.px(x, y + 1, C["water_d"])
            for dx, dy, col in [(0, 0, C["grass"]), (0, -1, C["grass"]), (0, -2, C["grass_l"]), (-1, -3, C["grass_l"]), (1, -3, C["grass"]), (0, -4, C["grass_ll"]), (-2, -1, C["grass"]), (2, -2, C["grass_l"])]:
                c.px(x + dx, y + dy, col)


def paving(c: Canvas, p, stone=None, gap=None, moss_amount=0.0):
    stone = C["stone"] if stone is None else stone
    gap = C["stone_d"] if gap is None else gap
    c.fill(shade(gap, -0.2))
    for y in range(0, S, 16):
        for x in range(0, S, 16):
            w = 14 - int(c.rand(x, y, 1) * 3)
            h = 14 - int(c.rand(x, y, 2) * 3)
            ox, oy = int(c.rand(x, y, 3) * 2), int(c.rand(x, y, 4) * 2)
            c.texture(x + ox, y + oy, w, h, stone, 0.08, 5.0, k=x * 7 + y)
            c.hline(y + oy, x + ox, x + ox + w - 1, shade(stone, 0.2))
            c.vline(x + ox, y + oy, y + oy + h - 1, shade(stone, 0.15))
            c.hline(y + oy + h - 1, x + ox, x + ox + w - 1, shade(stone, -0.3))
            c.vline(x + ox + w - 1, y + oy, y + oy + h - 1, shade(stone, -0.25))
    if moss_amount > 0:
        for y in range(S):
            for x in range(S):
                if c.get(x, y) == shade(gap, -0.2) and c.rand(x, y, 7) < moss_amount * 3:
                    c.px(x, y, C["grass_d"])
        c.noise(C["grass"], moss_amount * 0.5, k=8)


def interlock(c: Canvas, p, a=None, b=None, gap=None):
    a = C["stone"] if a is None else a
    b = C["fog"] if b is None else b
    gap = shade(C["fog"], -0.3) if gap is None else gap
    c.fill(gap)
    for row, y in enumerate(range(0, S, 8)):
        shift = 8 if row % 2 else 0
        for x in range(-8 + shift, S, 16):
            col = b if ((x // 16) + row) % 2 else a
            c.texture(x + 1, y + 1, 15, 7, col, 0.06, 4.0, k=row * 3 + x)
            c.hline(y + 1, x + 1, x + 15, shade(col, 0.18))
            c.vline(x + 15, y + 1, y + 7, shade(col, -0.25))
            c.hline(y + 7, x + 2, x + 15, shade(col, -0.25))


def soil_rows(c: Canvas, p):
    base = C["soil"]
    c.fill(base)
    for y in range(0, S, 8):
        c.gradient_v(0, y, S, 4, shade(base, 0.25), base)
        c.gradient_v(0, y + 4, S, 4, shade(base, -0.15), shade(base, -0.45))
        for x in range(S):
            if c.rand(x, y, 1) < 0.25:
                c.px(x, y + int(c.rand(x, y, 2) * 3), shade(base, 0.35))
            if c.rand(x, y, 3) < 0.15:
                c.px(x, y + 5 + int(c.rand(x, y, 4) * 2), C["sumi"])
    c.noise(C["straw"], 0.02, k=5)


def path(c: Canvas, p, g=None, dirt=None, vertical=True):
    g = C["grass"] if g is None else g
    dirt = C["soil"] if dirt is None else dirt
    grass(c, p, base=g)
    for i in range(S):
        a = 10 + int(c.rand(i, 0, 3) * 3)
        b = 22 - int(c.rand(i, 1, 3) * 3)
        for j in range(a, b + 1):
            t = 1.0 - abs((j - (a + b) / 2) / ((b - a) / 2 + 0.01))
            col = mix(dirt, shade(dirt, 0.2), t * 0.7)
            if c.rand(i, j, 4) < 0.12:
                col = shade(dirt, -0.25)
            if vertical:
                c.px(j, i, col)
            else:
                c.px(i, j, col)


def slope(c: Canvas, p, base=None, line=None, concrete_=False):
    if concrete_:
        c.texture(0, 0, S, S, C["fog"], 0.06, 7.0, k=1)
        for y in range(0, S, 8):
            c.hline(y, 0, S - 1, shade(C["fog"], -0.35))
            c.hline(y + 1, 0, S - 1, shade(C["fog"], 0.15))
        for x in range(0, S, 8):
            c.vline(x, 0, S - 1, shade(C["fog"], -0.35))
            c.vline(x + 1, 0, S - 1, shade(C["fog"], 0.15))
        for y in range(0, S, 8):
            for x in range(0, S, 8):
                c.texture(x + 2, y + 2, 6, 6, C["fog"], 0.1, 3.0, k=x + y * 7)
        return
    base = C["grass"] if base is None else base
    line = C["grass_d"] if line is None else line
    grass(c, p, base=base)
    for y in range(S):
        for x in range(S):
            d = (x + y) % 10
            if d == 0:
                c.px(x, y, line)
            elif d == 1:
                c.blend(x, y, line, 0.5)
            elif d == 5 and c.rand(x, y, 3) < 0.5:
                c.px(x, y, shade(base, 0.2))


def stairs(c: Canvas, p, base=None, broken=False, rail=False):
    base = C["stone"] if base is None else base
    for y in range(0, S, 8):
        c.gradient_v(0, y, S, 5, shade(base, 0.2), base)
        c.hline(y, 0, S - 1, shade(base, 0.35))
        c.gradient_v(0, y + 5, S, 3, shade(base, -0.3), shade(base, -0.55))
        c.noise(shade(base, -0.15), 0.1, 0, y + 1, S, 4, k=y)
    if broken:
        for y in range(S):
            for x in range(S):
                r = c.rand(x, y, 5)
                if r < 0.10:
                    c.px(x, y, C["sumi"])
                elif r < 0.17:
                    c.px(x, y, C["grass_d"])
    if rail:
        for x in (0, 1, 30, 31):
            c.vline(x, 0, S - 1, C["wood_d"] if x in (1, 30) else C["wood"])
        for y in range(0, S, 8):
            c.px(1, y, C["wood_l"])
            c.px(30, y, C["wood_l"])


def cliff(c: Canvas, p, base=None, dark=None, hi=None):
    base = C["deep"] if base is None else base
    dark = C["night"] if dark is None else dark
    hi = C["fog"] if hi is None else hi
    c.texture(0, 0, S, S, base, 0.15, 6.0, k=1)
    for y in range(S):
        band = (y // 6) % 3
        for x in range(S):
            if band == 2 and c.rand(x, y, 2) < 0.5:
                c.blend(x, y, dark, 0.6)
    for col in (0, 11, 22):
        for y in range(S):
            xx = col + int(c.noise2(col, y, 4.0, 3) * 4)
            c.px(xx, y, dark)
            c.px(xx + 1, y, shade(base, -0.2))
            if c.rand(xx, y, 4) < 0.6:
                c.px(xx - 1, y, hi)
    for y in (4, 15, 26):
        x0 = int(c.rand(0, y, 5) * 10)
        c.hline(y, x0, x0 + 10 + int(c.rand(1, y, 5) * 12), C["sumi"])
        c.hline(y + 1, x0 + 2, x0 + 8, hi)
    c.noise(C["grass_d"], 0.04, k=6)


def moat(c: Canvas, p):
    grass(c, p, base=C["grass"])
    for i in range(8):
        t = i / 7.0
        col = mix(C["grass_d"], C["sumi"], t)
        c.rect(i, i, S - 2 * i, S - 2 * i, col)
        for x in range(i, S - i):
            if c.rand(x, i, 2) < 0.3:
                c.px(x, i, mix(col, C["grass"], 0.4))
    c.dither(10, 10, 12, 12, C["night"], 0.5)


def fog_tile(c: Canvas, p):
    for y in range(S):
        for x in range(S):
            v = c.noise2(x, y, 7.0, 1)
            a = int(80 + 90 * v)
            c.px(x, y, mix(C["fog"], C["conc"], v * 0.6), a)


# ═══════════════════════════ 壁・屋根（オートタイル） ═══════════════════════════

def block_wall(c: Canvas, p, mask=0, base=None, mortar=None, bw=16, bh=8):
    """ブロック塀。mask：同種の隣接（N E S W）。上端が空いていれば笠木、左右端が空いていれば柱"""
    base = C["conc"] if base is None else base
    mortar = shade(base, -0.4) if mortar is None else mortar
    c.fill(mortar)
    row = 0
    y = 0
    while y < S:
        shift = bw // 2 if row % 2 else 0
        x = shift - bw
        while x < S:
            c.texture(x + 1, y + 1, bw - 1, bh - 1, base, 0.07, 4.0, k=row * 5 + x)
            c.hline(y + 1, x + 1, x + bw - 1, shade(base, 0.15))
            c.vline(x + 1, y + 1, y + bh - 1, shade(base, 0.1))
            c.hline(y + bh - 1, x + 2, x + bw - 1, shade(base, -0.25))
            c.vline(x + bw - 1, y + 2, y + bh - 1, shade(base, -0.25))
            x += bw
        y += bh
        row += 1
    c.noise(shade(base, -0.3), 0.03, k=9)
    if not (mask & N):
        c.gradient_v(0, 0, S, 4, shade(base, 0.35), shade(base, 0.1))
        c.hline(4, 0, S - 1, shade(base, -0.4))
    if not (mask & SO):
        c.hline(S - 1, 0, S - 1, C["sumi"])
        c.hline(S - 2, 0, S - 1, shade(base, -0.5))
    if not (mask & W):
        c.rect(0, 0, 3, S, shade(base, 0.05))
        c.vline(0, 0, S - 1, shade(base, 0.25))
        c.vline(3, 0, S - 1, shade(base, -0.4))
    if not (mask & E):
        c.rect(S - 3, 0, 3, S, shade(base, -0.1))
        c.vline(S - 1, 0, S - 1, shade(base, -0.45))
        c.vline(S - 4, 0, S - 1, shade(base, -0.35))


def concrete_wall(c: Canvas, p, mask=0, base=None, stain=0.3):
    base = C["conc"] if base is None else base
    concrete(c, p, base, stain)
    if not (mask & N):
        c.gradient_v(0, 0, S, 3, shade(base, 0.3), shade(base, 0.05))
        c.hline(3, 0, S - 1, shade(base, -0.3))
    if not (mask & SO):
        c.hline(S - 1, 0, S - 1, C["sumi"])
        c.hline(S - 2, 0, S - 1, shade(base, -0.4))
    if not (mask & W):
        c.vline(0, 0, S - 1, shade(base, 0.2))
        c.vline(1, 0, S - 1, shade(base, 0.08))
    if not (mask & E):
        c.vline(S - 1, 0, S - 1, shade(base, -0.4))
        c.vline(S - 2, 0, S - 1, shade(base, -0.2))
    # 打ち継ぎ目（2 マスごと）
    if mask & N and c.seed % 2 == 0:
        c.hline(0, 0, S - 1, shade(base, -0.2))


def tile_wall(c: Canvas, p, mask=0, base=None, grout=None):
    base = C["conc"] if base is None else base
    grout = shade(base, -0.35) if grout is None else grout
    c.fill(grout)
    for y in range(0, S, 8):
        for x in range(0, S, 8):
            col = shade(base, (c.rand(x, y, 1) - 0.5) * 0.12)
            c.rect(x + 1, y + 1, 6, 6, col)
            c.hline(y + 1, x + 1, x + 6, shade(col, 0.2))
            c.vline(x + 1, y + 1, y + 6, shade(col, 0.1))
            c.hline(y + 6, x + 2, x + 6, shade(col, -0.25))
            c.vline(x + 6, y + 2, y + 6, shade(col, -0.2))
    if not (mask & N):
        c.gradient_v(0, 0, S, 3, shade(base, 0.3), shade(base, 0.05))
    if not (mask & SO):
        c.hline(S - 1, 0, S - 1, C["sumi"])
    if not (mask & W):
        c.vline(0, 0, S - 1, shade(base, 0.2))
    if not (mask & E):
        c.vline(S - 1, 0, S - 1, shade(base, -0.4))


def planks(c: Canvas, p, mask=0, base=None, gap=None, width=8, vertical=False, worn=False):
    base = C["wood"] if base is None else base
    gap = shade(base, -0.5) if gap is None else gap
    c.fill(base)
    n = S // width
    for i in range(n):
        o = i * width
        col = shade(base, (c.rand(i, 0, 1) - 0.5) * 0.16)
        if vertical:
            c.texture(o, 0, width, S, col, 0.08, 5.0, k=i)
            c.vline(o, 0, S - 1, gap)
            c.vline(o + 1, 0, S - 1, shade(col, 0.18))
            c.vline(o + width - 1, 0, S - 1, shade(col, -0.2))
            for j in range(4):
                y0 = int(c.rand(i, j + 10, 2) * S)
                c.vline(o + 2 + int(c.rand(i, j + 20, 2) * (width - 3)), y0, y0 + 3 + int(c.rand(i, j, 3) * 8), shade(col, -0.22))
        else:
            c.texture(0, o, S, width, col, 0.08, 5.0, k=i)
            c.hline(o, 0, S - 1, gap)
            c.hline(o + 1, 0, S - 1, shade(col, 0.18))
            c.hline(o + width - 1, 0, S - 1, shade(col, -0.2))
            for j in range(4):
                x0 = int(c.rand(i, j + 10, 2) * S)
                c.hline(o + 2 + int(c.rand(i, j + 20, 2) * (width - 3)), x0, x0 + 3 + int(c.rand(i, j, 3) * 8), shade(col, -0.22))
            # 釘
            if c.rand(i, 40, 4) < 0.7:
                c.px(3, o + width // 2, shade(col, -0.45))
                c.px(S - 4, o + width // 2, shade(col, -0.45))
    if worn:
        c.noise(C["ochre"], 0.03, k=7)
        c.noise(C["sumi"], 0.02, k=8)
    if not vertical and not (mask & N):
        c.hline(0, 0, S - 1, C["sumi"])
    if not (mask & SO):
        c.hline(S - 1, 0, S - 1, C["sumi"])
    if not (mask & W):
        c.vline(0, 0, S - 1, shade(base, -0.5))
    if not (mask & E):
        c.vline(S - 1, 0, S - 1, C["sumi"])


def roof(c: Canvas, p, mask=0, base=None, dark=None, hi=None, bark=False):
    """瓦屋根：丸瓦の列を段違いに。上端が空いていれば棟、下端が空いていれば軒"""
    base = C["tile_roof"] if base is None else base
    dark = C["tile_roof_d"] if dark is None else dark
    hi = C["tile_roof_l"] if hi is None else hi
    c.fill(base)
    if bark:
        for y in range(S):
            k = y % 4
            col = (dark, shade(base, 0.05), hi, base)[k]
            c.hline(y, 0, S - 1, col)
            for x in range(S):
                if c.rand(x, y, 2) < 0.15:
                    c.px(x, y, dark if k != 0 else base)
    else:
        for row, y in enumerate(range(0, S, 8)):
            off = 0 if row % 2 == 0 else 4
            for x in range(off - 8, S, 8):
                # 1 枚の瓦 8×8：上に丸み、下に影
                c.gradient_v(x + 1, y + 1, 6, 5, hi, base)
                c.px(x + 1, y + 1, base)
                c.px(x + 6, y + 1, base)
                c.px(x + 2, y + 2, shade(hi, 0.25))
                c.px(x + 3, y + 2, shade(hi, 0.25))
                c.hline(y + 6, x + 1, x + 6, dark)
                c.hline(y + 7, x, x + 7, shade(dark, -0.3))
                c.vline(x, y, y + 6, dark)
                c.vline(x + 7, y + 1, y + 6, shade(base, -0.2))
    if not (mask & N):
        c.rect(0, 0, S, 3, shade(dark, -0.2))
        c.hline(0, 0, S - 1, shade(hi, 0.1))
        c.hline(3, 0, S - 1, C["sumi"])
    if not (mask & SO):
        c.rect(0, S - 3, S, 3, shade(dark, -0.1))
        c.hline(S - 3, 0, S - 1, hi)
        c.hline(S - 1, 0, S - 1, C["sumi"])
    if not (mask & W):
        c.vline(0, 0, S - 1, shade(dark, -0.2))
        c.vline(1, 0, S - 1, hi)
    if not (mask & E):
        c.vline(S - 1, 0, S - 1, C["sumi"])
        c.vline(S - 2, 0, S - 1, dark)


def hedge(c: Canvas, p, mask=0):
    base = C["leaf_d"]
    c.texture(0, 0, S, S, base, 0.15, 4.0, k=1, dark=C["leaf_dd"], light=C["leaf"])
    for y in range(S):
        for x in range(S):
            r = c.rand(x, y, 2)
            if r < 0.14:
                c.px(x, y, C["leaf_l"])
            elif r < 0.2:
                c.px(x, y, C["leaf"])
    if not (mask & N):
        c.gradient_v(0, 0, S, 8, C["leaf_l"], C["leaf"])
        c.noise(C["leaf_ll"], 0.2, 0, 0, S, 6, k=3)
        c.noise(C["leaf_d"], 0.15, 0, 2, S, 6, k=4)
    if not (mask & SO):
        c.gradient_v(0, S - 8, S, 8, C["leaf_d"], C["leaf_dd"])
        c.noise(C["leaf"], 0.12, 0, S - 8, S, 6, k=5)
        c.hline(S - 1, 0, S - 1, C["sumi"])
    if not (mask & W):
        c.vline(0, 0, S - 1, C["leaf_dd"])
        c.noise(C["leaf_l"], 0.3, 1, 0, 3, S, k=6)
    if not (mask & E):
        c.vline(S - 1, 0, S - 1, C["sumi"])
        c.noise(C["leaf_dd"], 0.4, S - 4, 0, 3, S, k=7)
    for i in range(2):
        if c.rand(i, 50, 8) < 0.5:
            c.px(int(c.rand(i, 51, 8) * S), int(c.rand(i, 52, 8) * S), C["ochre"])


def fence_wood(c: Canvas, p, mask=0, ground=None):
    """木の柵（横桟 2 本と支柱）。左右がつながる"""
    ground_tile(c, p, ground)
    for x in (4, 20):
        c.rect(x, 6, 3, 24, C["wood"])
        c.vline(x, 6, 29, C["wood_l"])
        c.vline(x + 2, 6, 29, C["wood_d"])
        c.rect(x, 5, 3, 1, C["wood_l"])
        c.rect(x - 1, 30, 5, 2, C["sumi"])
    for y in (10, 20):
        c.rect(0, y, S, 4, C["wood"])
        c.hline(y, 0, S - 1, C["wood_l"])
        c.hline(y + 3, 0, S - 1, C["wood_d"])
        c.noise(C["wood_d"], 0.08, 0, y + 1, S, 2, k=y)
    if not (mask & W):
        c.rect(0, 4, 3, 26, C["wood"])
        c.vline(0, 4, 29, C["wood_l"])
    if not (mask & E):
        c.rect(S - 3, 4, 3, 26, C["wood"])
        c.vline(S - 1, 4, 29, C["wood_d"])


def ground_tile(c: Canvas, p, ground=None):
    """物の足元の地面。引数 ground（旧パレット番号か色名）から選ぶ"""
    g = ground
    if isinstance(g, int):
        g = PALETTE_TO_GROUND.get(g, "asphalt")
    if g in (None, "asphalt", "dusk"):
        asphalt(c, p)
    elif g == "soil":
        soil(c, p)
    elif g == "grass":
        grass(c, p)
    elif g == "moss":
        moss(c, p)
    elif g == "gravel":
        gravel(c, p)
    elif g == "conc":
        concrete(c, p, C["conc"], 0.15)
    elif g == "sand":
        sand(c, p)
    elif g == "night":
        c.texture(0, 0, S, S, C["night"], 0.1, 7.0, k=1)
    elif g == "stone":
        paving(c, p)
    else:
        asphalt(c, p)


PALETTE_TO_GROUND = {0: "night", 1: "night", 2: "asphalt", 3: "asphalt", 4: "conc", 5: "conc", 6: "moss", 7: "grass", 8: "grass",
                     9: "soil", 10: "soil", 11: "sand", 12: "conc", 13: "asphalt", 14: "asphalt", 15: "asphalt"}


# ═══════════════════════════ 背の高い部品（幅 w × 高さ h マス） ═══════════════════════════
# 縮尺：1 マス ≈ 1.7 m（人の身長 ≈ 1 マス）。木 5〜7 m（3〜4 マス）、街灯 5 m（3）、電柱 8.5 m（5）、塔 8〜10 m（5〜6）。
# 底辺の中央のマスが本体（種別名・当たり）。それ以外のマスは Overhead 層の部品（<種別>#part）になる。
# 底辺の行では中央のマス以外に描かない（隣のマスの地面に物がはみ出さない）。

def tall_ground(c: Canvas, p, ground, w: int, h: int):
    """底辺の中央のマスに地面を敷く。戻り値 (g, bx, by)：地面キャンバスと、そのマスの左上"""
    bx, by = (w // 2) * S, (h - 1) * S
    g = Canvas(S, S, c.seed)
    ground_tile(g, p, ground)
    c.paste(g, bx, by)
    return g, bx, by


def outline_tall(c: Canvas, g: Canvas, bx: int, by: int, color=None):
    """地面と違う画素（＝物）の外側に輪郭。底辺のマスの外は描いた画素すべてが物"""
    color = C["sumi"] if color is None else color

    def is_obj(x, y):
        v = c.get(x, y)
        if v is None:
            return False
        if bx <= x < bx + S and by <= y < by + S:
            return v != g.get(x - bx, y - by)
        return True
    c.outline(is_obj, color)


def leaf_noise(c: Canvas, g: Canvas, bx: int, by: int, y_to: int, colors, amount=0.22, k=3):
    for y in range(0, y_to):
        for x in range(c.w):
            col = c.get(x, y)
            if col is None or col not in colors:
                continue
            if c.rand(x, y, k) < amount:
                c.px(x, y, shade(col, (c.rand(x, y, k + 1) - 0.5) * 0.5))


def tree_round(c: Canvas, p, ground=None, canopy=None, fruit=None, blossom=None, w=3, h=3):
    """広葉樹。幹は底辺の中央、樹冠は上の行に w マス幅で広がる"""
    g, bx, by = tall_ground(c, p, ground, w, h)
    canopy = C["leaf"] if canopy is None else canopy
    cx = c.w // 2
    trunk_top = by - S // 2
    c.shadow_ellipse(cx, by + 27, 13, 4, 0.5)
    # 幹（根元が広がる）
    c.gradient_h(cx - 4, trunk_top, 8, by + 28 - trunk_top, C["wood_l"], C["wood_d"])
    c.vline(cx - 4, trunk_top, by + 27, C["wood_d"])
    c.vline(cx + 3, trunk_top, by + 27, C["wood_dd"])
    c.line(cx - 5, by + 24, cx - 8, by + 29, C["wood_d"])
    c.line(cx + 4, by + 24, cx + 7, by + 29, C["wood_d"])
    c.line(cx, trunk_top + 10, cx - 12, trunk_top - 6, C["wood_d"])     # 枝
    c.line(cx + 1, trunk_top + 8, cx + 13, trunk_top - 8, C["wood_d"])
    # 樹冠：楕円の房を重ねる。全体の楕円は幅 w マスの 90%、高さ h-1 マス
    rx, ry = int(c.w * 0.45), int((by + 6) * 0.5)
    cy = ry + 2
    lumps = []
    for i in range(14):
        ang = i * 2.399
        rr = 0.35 + 0.55 * c.rand(i, 0, 11)
        lx = cx + int(math.cos(ang) * rx * 0.62 * rr)
        ly = cy + int(math.sin(ang) * ry * 0.62 * rr)
        r = int(min(rx, ry) * (0.42 + 0.2 * c.rand(i, 1, 11)))
        lumps.append((lx, ly, r, (ly - cy) / max(1, ry) * -0.28))
    lumps.sort(key=lambda t: t[1], reverse=True)
    for (lx, ly, r, k) in lumps:
        c.disc(lx, ly, r, shade(canopy, k - 0.35))
    for (lx, ly, r, k) in lumps:
        c.disc(lx - 1, ly - 1, r - 2, shade(canopy, k))
        c.disc(lx - r // 3, ly - r // 2, max(1, r - 5), shade(canopy, k + 0.25))
    leaf_noise(c, g, bx, by, by + 4, {shade(canopy, k + d) for (_, _, _, k) in lumps for d in (-0.35, 0.0, 0.25)})
    if fruit is not None:
        for i in range(10):
            fx = cx + int((c.rand(i, 5, 12) - 0.5) * rx * 1.4)
            fy = cy + int((c.rand(i, 6, 12) - 0.5) * ry * 1.3)
            if c.get(fx, fy) is not None:
                c.disc(fx, fy, 1.6, fruit)
                c.px(fx - 1, fy - 1, shade(fruit, 0.4))
    if blossom is not None:
        for y in range(0, by + 4):
            for x in range(c.w):
                if c.get(x, y) is not None and c.rand(x, y, 9) < 0.3:
                    c.px(x, y, mix(blossom, canopy, c.rand(x, y, 10) * 0.4))
    outline_tall(c, g, bx, by)


def small_tree(c: Canvas, p, ground=None, canopy=None):
    """植栽：1 マス幅、2 マス高の若木"""
    g, bx, by = tall_ground(c, p, ground, 1, 2)
    canopy = C["leaf"] if canopy is None else canopy
    c.shadow_ellipse(16, by + 27, 9, 3, 0.45)
    c.gradient_h(14, by - 2, 5, 30, C["wood_l"], C["wood_d"])
    c.vline(18, by - 2, by + 27, C["wood_dd"])
    for (lx, ly, r, k) in [(16, 20, 12, -0.3), (11, 22, 8, -0.05), (21, 21, 8, -0.1), (16, 12, 9, 0.1), (12, 14, 6, 0.25)]:
        c.disc(lx, ly, r, shade(canopy, k))
    leaf_noise(c, g, bx, by, by + 2, {shade(canopy, k) for k in (-0.3, -0.05, -0.1, 0.1, 0.25)})
    outline_tall(c, g, bx, by)


def bush(c: Canvas, p, ground=None, canopy=None):
    """植栽（低木）：1 マス。丸い刈り込み"""
    g = Canvas(S, S, c.seed)
    ground_tile(g, p, ground)
    c.paste(g, 0, 0)
    canopy = C["leaf"] if canopy is None else canopy
    c.shadow_ellipse(16, 27, 13, 4, 0.4)
    for (lx, ly, rx, ry, k) in [(16, 17, 13, 9, -0.3), (14, 15, 10, 7, 0.0), (11, 12, 5, 4, 0.25)]:
        c.ellipse(lx, ly, rx, ry, shade(canopy, k))
    leaf_noise(c, g, 0, 0, S, {shade(canopy, k) for k in (-0.3, 0.0, 0.25)})
    outline_tall(c, g, 0, 0)


def tree_conifer(c: Canvas, p, ground=None, leaf=None, hi=None, h=3):
    """針葉樹（杉）。1 マス幅、h マス高。林の中では上の木の梢が下の木に重なる"""
    g, bx, by = tall_ground(c, p, ground, 1, h)
    leaf = C["pine"] if leaf is None else leaf
    hi = C["pine_l"] if hi is None else hi
    c.shadow_ellipse(16, by + 27, 10, 3, 0.5)
    c.rect(14, by + 12, 4, 16, C["wood_d"])
    c.vline(14, by + 12, by + 27, C["wood"])
    total = by + 14
    tiers = 6 + (h - 3) * 2
    for tier in range(tiers):
        y = int(total * tier / tiers)
        y1 = int(total * (tier + 1) / tiers) + 3
        half0 = 1 + int(7 * tier / max(1, tiers - 1))
        for yy in range(y, y1):
            w = half0 + int((yy - y) * 0.55)
            w = min(w, 13)
            c.hline(yy, 16 - w, 15 + w, leaf)
            c.px(16 - w, yy, hi)
            c.px(16 - w + 1, yy, shade(hi, -0.1))
            c.px(15 + w, yy, C["pine_d"])
            c.px(14 + w, yy, C["pine_d"])
        c.hline(y1 - 1, 16 - half0 - 6, 15 + half0 + 6, C["pine_d"])   # 段の下端の影
    leaf_noise(c, g, bx, by, by + 12, {leaf, hi, C["pine_d"]}, 0.2)
    outline_tall(c, g, bx, by)


def conifer_mass(c: Canvas, p, mask=0, ground=None, leaf=None, hi=None):
    """林の 1 マス（オートタイル）。上に同じ林が続く内側のマスは梢を上から見た繁み、林の上端のマスは幹のある木の根元
    （その上に TALL の梢が 2 マス立ち上がる）。下端（南に林が無い）は幹の影で暗く落とす"""
    leaf = C["pine"] if leaf is None else leaf
    hi = C["pine_l"] if hi is None else hi
    if not (mask & N):
        tmp = Canvas(S, S * 3, c.seed)
        tree_conifer(tmp, p, ground, leaf, hi, 3)
        for y in range(S):
            for x in range(S):
                c.p[y][x] = tmp.p[S * 2 + y][x]
        return
    dark = C["pine_d"]
    c.texture(0, 0, S, S, leaf, 0.14, 5.0, k=1, dark=shade(dark, -0.15), light=shade(leaf, 0.05))
    # 梢の房：小さな三角の重なり
    for i in range(9):
        x = int(c.rand(i, 0, 21) * S)
        y = int(c.rand(i, 1, 21) * S)
        r = 4 + int(c.rand(i, 2, 21) * 4)
        for yy in range(y - r, y + r):
            w = max(0, r - abs(yy - y) // 1)
            c.hline(yy, x - w // 2, x + w // 2, shade(leaf, -0.2 if yy > y else 0.05))
        c.px(x, y - r + 1, hi)
        c.px(x - 1, y - r + 2, shade(hi, -0.1))
    c.noise(shade(dark, -0.2), 0.12, k=3)
    c.noise(hi, 0.05, k=4)
    if not (mask & SO):
        c.gradient_v(0, S - 8, S, 8, shade(dark, -0.1), shade(C["sumi"], 0.1))
        for x in range(2, S, 8):
            c.rect(x + int(c.rand(x, 0, 5) * 3), S - 6, 2, 6, C["wood_dd"])
    if not (mask & W):
        c.vline(0, 0, S - 1, shade(dark, -0.3))
    if not (mask & E):
        c.vline(S - 1, 0, S - 1, shade(dark, -0.3))


def tree_bare(c: Canvas, p, ground=None, blossom=None, w=3, h=3):
    """落葉した木（桜・梅）。枝が w マス幅に広がる"""
    g, bx, by = tall_ground(c, p, ground, w, h)
    cx = c.w // 2
    c.shadow_ellipse(cx, by + 27, 10, 3, 0.45)
    wood, wood_d = C["wood"], C["wood_d"]
    top = by - 6
    c.gradient_h(cx - 3, top, 6, by + 28 - top, C["wood_l"], wood_d)
    c.vline(cx + 2, top, by + 27, C["wood_dd"])
    sx, sy = c.w / 32.0, (by + 8) / 32.0
    branches = [(16, 30, 8, 14), (16, 30, 24, 12), (15, 22, 6, 6), (17, 22, 26, 4), (8, 14, 3, 6), (24, 12, 29, 4), (16, 24, 16, 6), (10, 18, 12, 9), (22, 16, 20, 8),
                (12, 14, 4, 12), (20, 12, 30, 9), (8, 8, 2, 3), (26, 8, 31, 5), (14, 10, 10, 2), (18, 9, 22, 1)]
    for (x0, y0, x1, y1) in branches:
        X0, Y0, X1, Y1 = int(x0 * sx), int(y0 * sy), int(x1 * sx), int(y1 * sy)
        c.line(X0, Y0, X1, Y1, wood)
        c.line(X0 + 1, Y0, X1 + 1, Y1, wood_d)
        if abs(X1 - X0) + abs(Y1 - Y0) > 20:
            c.line(X0, Y0 + 1, X1, Y1 + 1, wood_d)
    outline_tall(c, g, bx, by)
    if blossom is not None:
        for y in range(0, by + 6):
            for x in range(c.w):
                if c.rand(x, y, 5) < 0.14 and c.noise2(x, y, 7.0, 6) > 0.42 and (c.get(x, y) is not None or c.noise2(x, y, 4.0, 8) > 0.55):
                    c.px(x, y, mix(blossom, C["conc"], c.rand(x, y, 7) * 0.3))
                    c.px(x + 1, y, shade(blossom, -0.15))


def streetlamp(c: Canvas, p, ground=None, glow=None, h=3):
    """街灯：h マス高。長い柱、腕、傘。灯の周囲ににじみ"""
    g, bx, by = tall_ground(c, p, ground, 1, h)
    glow = C["glow"] if glow is None else glow
    for y in range(0, S):
        for x in range(S):
            d = math.hypot((x - 19) * 1.0, (y - 8) * 1.4)
            if d < 15:
                c.blend(x, y, mix(glow, C["ochre"], 0.5), (1 - d / 15) ** 1.8 * 0.55)
    for y in range(by, by + S):
        for x in range(S):
            d = math.hypot((x - 19) * 1.2, (y - by - 26) * 1.0)
            if d < 13:
                c.blend(x, y, C["ochre"], (1 - d / 13) ** 1.6 * 0.35)
    c.gradient_h(13, 12, 4, by + 16, C["metal_l"], C["metal_d"])
    c.rect(11, by + 28, 8, 3, C["metal_d"])
    c.hline(by + 28, 11, 18, C["metal"])
    c.rect(10, by + 31, 10, 1, C["sumi"])
    c.rect(15, 8, 8, 2, C["metal"])          # 腕
    c.line(16, 12, 20, 10, C["metal_d"])
    c.rect(17, 3, 10, 5, glow)               # 傘と灯
    c.hline(2, 16, 27, C["metal_l"])
    c.hline(1, 18, 25, C["metal"])
    c.rect(18, 8, 8, 1, C["bone"])
    c.px(17, 5, C["ochre"])
    c.px(26, 5, C["ochre"])
    for y in range(by + 4, by + 26, 8):     # 柱の継ぎ目
        c.hline(y, 13, 16, C["metal_d"])
    c.outline(lambda x, y: c.get(x, y) in (C["metal_l"], C["metal"], C["metal_d"], glow, C["bone"]) and y < by + 30, C["sumi"])


def utility_pole(c: Canvas, p, ground=None, h=5):
    """電柱：h マス高。腕金と碍子、電線は最上段を横切る"""
    g, bx, by = tall_ground(c, p, ground, 1, h)
    c.hline(0, 0, S - 1, C["sumi"])
    c.hline(3, 0, S - 1, C["sumi"])
    c.hline(6, 0, S - 1, C["night"])
    c.gradient_h(14, 0, 5, by + 30, C["conc"], C["fog"])
    c.vline(14, 0, by + 29, C["stone_l"])
    c.vline(18, 0, by + 29, C["stone_d"])
    c.rect(12, by + 30, 9, 2, C["sumi"])
    c.rect(4, 6, 24, 2, C["metal_d"])         # 腕金
    c.hline(6, 4, 27, C["metal"])
    for x in (6, 12, 20, 26):
        c.rect(x, 3, 2, 3, C["bone"])
        c.px(x, 3, C["conc"])
    c.rect(4, 20, 24, 2, C["metal_d"])        # 2 段目の腕金（通信線）
    c.hline(20, 0, S - 1, C["night"])
    c.rect(10, 34, 12, 3, C["metal_d"])       # 変圧器
    c.rect(11, 30, 10, 12, C["metal"]); c.frame(11, 30, 10, 12, C["metal_d"])
    for y in range(by - 14, by + 20, 8):      # 足場ボルト
        c.rect(12, y, 8, 2, C["metal_d"])
    c.rect(13, by + 6, 6, 4, C["ochre"])      # 番号札
    c.px(15, by + 7, C["sumi"])
    c.px(16, by + 8, C["sumi"])
    outline_tall(c, g, bx, by)


# ═══════════════════════════ 登録 ═══════════════════════════

# オートタイル：種別名 → 描画関数（mask を受ける）
AUTOTILE = {
    "ブロック塀": lambda c, p, m: block_wall(c, p, m, C["conc"]),
    "土塀（漆喰・崩れ）": lambda c, p, m: block_wall(c, p, m, C["plaster"], C["plaster_d"], 32, 10),
    "団地 外壁（コンクリート・雨染み）": lambda c, p, m: concrete_wall(c, p, m, C["conc"], 0.5),
    "体育館の壁": lambda c, p, m: concrete_wall(c, p, m, C["fog"], 0.15),
    "防音壁": lambda c, p, m: concrete_wall(c, p, m, C["fog"], 0.2),
    "防音壁（遠景）": lambda c, p, m: concrete_wall(c, p, m, C["dusk"], 0.2),
    "隧道内壁（湿）": lambda c, p, m: concrete_wall(c, p, m, C["dusk"], 0.6),
    "高架橋脚": lambda c, p, m: concrete_wall(c, p, m, C["conc"], 0.4),
    "公共建築の壁（タイル）": lambda c, p, m: tile_wall(c, p, m, C["conc"]),
    "支所の壁（タイル）": lambda c, p, m: tile_wall(c, p, m, C["fog"]),
    "新校舎 外壁（タイル）": lambda c, p, m: tile_wall(c, p, m, C["stone"]),
    "旧校舎 外壁（下見板）": lambda c, p, m: planks(c, p, m, C["wood"], None, 8, False, True),
    "庵の板壁と瓦": lambda c, p, m: planks(c, p, m, C["wood_d"], C["sumi"], 8, True),
    "廃寺の壁・屋根（崩落）": lambda c, p, m: planks(c, p, m, C["wood_d"], C["sumi"], 8, True, True),
    "観音堂の板壁・格子・屋根": lambda c, p, m: planks(c, p, m, C["wood_d"], C["sumi"], 4, True),
    "倉庫（トタン）": lambda c, p, m: planks(c, p, m, C["metal"], C["metal_d"], 4, True),
    "農機具小屋（トタン・板）": lambda c, p, m: planks(c, p, m, C["wood"], C["wood_d"], 6, False),
    "建売住宅の壁・屋根（瓦）": lambda c, p, m: roof(c, p, m),
    "瓦屋根（連続）": lambda c, p, m: roof(c, p, m),
    "同型住宅の壁・屋根（3色差分）": lambda c, p, m: roof(c, p, m, C["dusk"], C["night"], C["fog"]),
    "農家の壁・瓦": lambda c, p, m: roof(c, p, m, C["wood_d"], C["wood_dd"], C["wood"]),
    "社殿の壁・屋根（檜皮）": lambda c, p, m: roof(c, p, m, C["wood_d"], C["wood_dd"], C["wood"], True),
    "カーポート": lambda c, p, m: roof(c, p, m, C["fog"], C["dusk"], C["conc"]),
    "駐輪場の屋根": lambda c, p, m: roof(c, p, m, C["fog"], C["dusk"], C["conc"]),
    "生垣": lambda c, p, m: hedge(c, p, m),
    "ゴミ集積所ネット": lambda c, p, m: hedge(c, p, m),
    "展望所の柵": lambda c, p, m: fence_wood(c, p, m, "grass"),
    "玉垣": lambda c, p, m: fence_wood(c, p, m, "grass"),
    # 林（TALL と併用：内側は繁み、上端の木だけ梢が立ち上がる）
    "杉林": lambda c, p, m: conifer_mass(c, p, m, "moss"),
    "杉林（暗）": lambda c, p, m: conifer_mass(c, p, m, "night", C["pine_d"], C["pine"]),
    "山の斜面（樹林）": lambda c, p, m: conifer_mass(c, p, m, "moss", C["pine"], C["leaf_l"]),
    "樹林（暗）": lambda c, p, m: conifer_mass(c, p, m, "moss", C["pine_d"], C["pine"]),
    "谷の斜面（暗い樹林）": lambda c, p, m: conifer_mass(c, p, m, "night", C["pine_d"], C["pine"]),
}

# 背の高い部品：種別名 → (描画関数, 幅マス, 高さマス)
TALL = {
    "イチョウ（大木）": (lambda c, p: tree_round(c, p, "asphalt", C["straw"], None, None, 3, 4), 3, 4),
    "柿の木（実あり）": (lambda c, p: tree_round(c, p, "soil", C["leaf"], C["rust_l"], None, 3, 3), 3, 3),
    "栗の木": (lambda c, p: tree_round(c, p, "moss", C["leaf_d"], None, None, 3, 3), 3, 3),
    "植栽": (lambda c, p: small_tree(c, p, "conc", C["leaf"]), 1, 2),
    "杉林": (lambda c, p: tree_conifer(c, p, "moss"), 1, 3),
    "杉林（暗）": (lambda c, p: tree_conifer(c, p, "night", C["pine_d"], C["pine"]), 1, 3),
    "山の斜面（樹林）": (lambda c, p: tree_conifer(c, p, "moss", C["pine"], C["leaf_l"]), 1, 3),
    "樹林（暗）": (lambda c, p: tree_conifer(c, p, "moss", C["pine_d"], C["pine"]), 1, 3),
    "谷の斜面（暗い樹林）": (lambda c, p: tree_conifer(c, p, "night", C["pine_d"], C["pine"]), 1, 3),
    "桜（葉・裸）": (lambda c, p: tree_bare(c, p, "asphalt", None, 3, 3), 3, 3),
    "梅の木（開花・裸）": (lambda c, p: tree_bare(c, p, "grass", C["bone"], 3, 3), 3, 3),
    "街灯（柱・光源）": (lambda c, p: streetlamp(c, p, "asphalt"), 1, 3),
    "街灯（均等）": (lambda c, p: streetlamp(c, p, "asphalt"), 1, 3),
    "電柱・電線": (lambda c, p: utility_pole(c, p, "asphalt"), 1, 5),
}

# 1 マスの地面・面：種別名 → 描画関数（引数は catalog の args）
FLAT = {
    "アスファルト": lambda c, p: asphalt(c, p),
    "生活道路アスファルト（細）": lambda c, p: asphalt(c, p, shade(C["asphalt"], 0.05)),
    "旧街道アスファルト（狭）": lambda c, p: asphalt(c, p, shade(C["asphalt"], -0.05), True),
    "区画道路アスファルト": lambda c, p: asphalt(c, p, shade(C["asphalt"], 0.08)),
    "堤防道路": lambda c, p: asphalt(c, p, shade(C["asphalt"], 0.03)),
    "高架床版（影）": lambda c, p: asphalt(c, p, C["night"], False, True),
    "校庭の土": lambda c, p: soil(c, p, C["soil"], 0.03),
    "土のグラウンド": lambda c, p: soil(c, p, shade(C["soil"], 0.05), 0.02),
    "土橋": lambda c, p: soil(c, p, C["soil"], 0.08),
    "公園の砂地": lambda c, p: sand(c, p),
    "苔": lambda c, p: moss(c, p),
    "境内の砂利": lambda c, p: gravel(c, p, C["fog"]),
    "農道の砂利": lambda c, p: gravel(c, p, C["soil_d"], C["ochre"], C["wood_dd"]),
    "林道の砂利": lambda c, p: gravel(c, p, C["soil_d"], C["ochre"], C["wood_dd"]),
    "河原の石": lambda c, p: gravel(c, p, C["fog"], C["conc"], C["dusk"]),
    "草地（丈高・低）": lambda c, p: grass(c, p),
    "下草": lambda c, p: grass(c, p, C["grass_d"], C["grass"]),
    "下草（丈高）": lambda c, p: grass(c, p, C["grass_d"], C["grass"], True),
    "売地の草": lambda c, p: grass(c, p, C["grass"], C["grass_l"], True, True),
    "畑の土（畝）": lambda c, p: soil_rows(c, p),
    "獣道": lambda c, p: path(c, p, C["grass_d"], C["soil_d"]),
    "獣道（踏み分け）": lambda c, p: path(c, p, C["grass_d"], C["soil_d"]),
    "畦道": lambda c, p: path(c, p, C["grass"], C["ochre_d"], False),
    "水面（流れ）": lambda c, p: water(c, p, True),
    "用水路（水面・コンクリート）": lambda c, p: water(c, p, True),
    "調整池（水面・柵）": lambda c, p: water(c, p, False),
    "水田（水面・稲）": lambda c, p: paddy(c, p),
    "石畳": lambda c, p: paving(c, p),
    "礎石": lambda c, p: paving(c, p, C["fog"], C["dusk"], 0.15),
    "歩道タイル": lambda c, p: interlock(c, p),
    "広場の敷石（インターロッキング）": lambda c, p: interlock(c, p, C["stone"], C["fog"]),
    "土塁（斜面・上面）": lambda c, p: slope(c, p, C["grass"], C["soil_d"]),
    "堤防斜面": lambda c, p: slope(c, p),
    "堤防斜面（草）": lambda c, p: slope(c, p),
    "法面コンクリート（格子）": lambda c, p: slope(c, p, None, None, True),
    "法面階段": lambda c, p: stairs(c, p, C["conc"]),
    "石段（登り口）": lambda c, p: stairs(c, p, C["stone"]),
    "石段（長・手すり）": lambda c, p: stairs(c, p, C["stone"], False, True),
    "崩れた石段": lambda c, p: stairs(c, p, C["fog"], True),
    "谷の岩壁": lambda c, p: cliff(c, p),
    "崖（通行不能）": lambda c, p: cliff(c, p, C["soil_d"], C["wood_dd"], C["soil"]),
    "空堀（底・壁）": lambda c, p: moat(c, p),
    "霧（半透明オーバーレイ）": lambda c, p: fog_tile(c, p),
    "植栽（低木）": lambda c, p: bush(c, p, "conc", C["leaf"]),
}


_EXTRA_LOADED = False


def load_extra() -> None:
    """部品ペインタ（props32a/props32b）を遅延で取り込む。これらは本モジュールの地面関数を使うので、
    import の循環を避けるため呼び出し時に読む"""
    global _EXTRA_LOADED
    if _EXTRA_LOADED:
        return
    _EXTRA_LOADED = True
    import props32a
    import props32b
    FLAT.update(props32a.FLAT2)
    FLAT.update(props32b.FLAT3)
    TALL.update(props32a.TALL2)
    TALL.update(props32b.TALL3)


def paint(name: str, entry: dict, mask: int | None = None):
    """種別名を描く。オートタイルは mask 付き。背の高い部品は 32×64 を返す"""
    load_extra()
    seed = seed_of(name)
    if mask is not None and name in AUTOTILE:
        c = Canvas(S, S, seed)
        AUTOTILE[name](c, entry.get("args", {}), mask)
        return c
    if name in TALL:
        fn, w, h = TALL[name]
        c = Canvas(S * w, S * h, seed)
        fn(c, entry.get("args", {}))
        # 底辺の行は中央のマスだけ（影や輪郭が隣の地面にはみ出さない）
        for y in range((h - 1) * S, h * S):
            for x in range(c.w):
                if not ((w // 2) * S <= x < (w // 2 + 1) * S):
                    c.p[y][x] = None
        return c
    c = Canvas(S, S, seed)
    if name in AUTOTILE:
        AUTOTILE[name](c, entry.get("args", {}), 15 if mask is None else mask)
        return c
    if name in FLAT:
        FLAT[name](c, entry.get("args", {}))
        return c
    return None


def legacy_upscaled(name: str, entry: dict):
    """まだ 32 px で描いていない種別：16 px 版を 2 倍に拡大して使う（移行中の穴埋め）"""
    import paint_atlas as pa
    img = pa.paint_tile(name, entry).to_rgba().resize((S, S), Image.NEAREST)
    c = Canvas(S, S, seed_of(name))
    px = img.load()
    for y in range(S):
        for x in range(S):
            r, g, b, a = px[x, y]
            if a > 0:
                c.px(x, y, (r, g, b), a)
    return c


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--catalog", default=os.path.join(HERE, "catalog.json"))
    ap.add_argument("--out", default=os.path.join(ROOT, "resources", "tilesets", "common_atlas.png"))
    ap.add_argument("--layout", default=os.path.join(ROOT, "resources", "tilesets", "atlas_layout.json"))
    ap.add_argument("--preview", default="")
    ap.add_argument("--scale", type=int, default=3)
    a = ap.parse_args()
    catalog = json.load(open(a.catalog, encoding="utf-8"))
    names = list(catalog.keys())
    load_extra()
    # 配置：まず 1 マスの種別（元の並び順で 16 列）、次にオートタイルの変種、最後に背の高い部品（2 段使う）
    entries = []   # {name, variant, x, y, w, h}
    tiles = []     # (canvas, x, y)
    col = row = 0

    def place(canvas, name, variant, w, h):
        nonlocal col, row
        if col + w > COLUMNS:
            col = 0
            row += 1
        entries.append({"name": name, "variant": variant, "x": col, "y": row, "w": w, "h": h})
        tiles.append((canvas, col, row))
        col += w

    legacy = []
    for name in names:
        if name in TALL:
            continue
        c = paint(name, catalog[name])
        if c is None:
            c = legacy_upscaled(name, catalog[name])
            legacy.append(name)
        place(c, name, "", 1, 1)
    row += 1
    col = 0
    for name in names:
        if name in AUTOTILE:
            for m in range(16):
                if m == 15 and name not in TALL:
                    continue   # 四方が同じ（m15）は本体と同じ絵。林は本体が木の根元なので m15（繁み）も別に持つ
                place(paint(name, catalog[name], m), name, "m%d" % m, 1, 1)
    row += 1
    col = 0
    for name in names:
        if name in TALL:
            c = paint(name, catalog[name])
            _, w, h = TALL[name]
            cx = w // 2
            # マスごとに切り出す。底辺の中央が本体（種別名）、それ以外は Overhead 用の部品（<name>#part、dx/dy 付き）
            for ty in range(h):
                for tx in range(w):
                    piece = Canvas(S, S, c.seed)
                    used = False
                    for y in range(S):
                        for x in range(S):
                            v = c.p[ty * S + y][tx * S + x]
                            piece.p[y][x] = v
                            used = used or (v is not None and v[1] > 0)
                    is_base = (tx == cx and ty == h - 1)
                    if not used and not is_base:
                        continue
                    if ty == h - 1 and not is_base:
                        print(f"警告: {name} の底辺の行で中央以外のマス (dx={tx - cx}) に描かれている。隣の地面にはみ出すので無視する")
                        continue
                    if col + 1 > COLUMNS:
                        col = 0
                        row += 1
                    entries.append({"name": name, "variant": "" if is_base else "part", "x": col, "y": row, "w": 1, "h": 1,
                                    "dx": tx - cx, "dy": ty - (h - 1)})
                    tiles.append((piece, col, row))
                    col += 1
    rows = row + 1
    atlas = Image.new("RGBA", (COLUMNS * S, rows * S), (0, 0, 0, 0))
    for canvas, x, y in tiles:
        atlas.paste(canvas.to_image(), (x * S, y * S))
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    atlas.save(a.out)
    layout = {"tile_size": S, "columns": COLUMNS, "rows": rows, "entries": entries,
              "autotile": sorted(AUTOTILE.keys()), "tall": {k: {"w": v[1], "h": v[2]} for k, v in sorted(TALL.items())}, "legacy": legacy}
    json.dump(layout, open(a.layout, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"{a.out}: {atlas.width}x{atlas.height}, entries={len(entries)}, autotile={len(AUTOTILE)}, tall={len(TALL)}, legacy(16px 拡大)={len(legacy)}")
    if a.preview:
        bg = Image.new("RGBA", atlas.size, (30, 30, 30, 255))
        bg.alpha_composite(atlas)
        bg.resize((atlas.width * a.scale, atlas.height * a.scale), Image.NEAREST).save(a.preview)
        print("preview:", a.preview)
    return 0


if __name__ == "__main__":
    sys.exit(main())
