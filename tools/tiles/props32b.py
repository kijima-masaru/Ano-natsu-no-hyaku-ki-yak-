"""32 px の部品（その 2）：石物・社寺・門・窓・塔。paint32.py の FLAT / TALL に登録する。

背の高い部品（TALL3）は幅 w × 高さ h マスで描き、底辺の中央が本体（通行不可）、それ以外のマスが Overhead 層に載る（paint32.tall_ground / outline_tall）。
"""
import math

from px32 import C, Canvas, S, mix, shade
from paint32 import concrete, ground_tile, grass, moss, outline_tall, planks, tall_ground, water
from props32a import glow_spot, outline_non_ground, with_ground

SUMI = C["sumi"]
STONE, STONE_L, STONE_D = C["stone"], C["stone_l"], C["stone_d"]
WOOD, WOOD_L, WOOD_D, WOOD_DD = C["wood"], C["wood_l"], C["wood_d"], C["wood_dd"]
M, ML, MD = C["metal"], C["metal_l"], C["metal_d"]
VERMILION = (176, 62, 44)


def stone_block(c: Canvas, x, y, w, h, base=None, mossy=0.0, k=0):
    """石の直方体：面の明暗、粒、苔"""
    base = STONE if base is None else base
    c.texture(x, y, w, h, base, 0.1, 4.0, k=k)
    c.hline(y, x, x + w - 1, shade(base, 0.3))
    c.vline(x, y, y + h - 1, shade(base, 0.18))
    c.hline(y + h - 1, x + 1, x + w - 1, shade(base, -0.35))
    c.vline(x + w - 1, y + 1, y + h - 1, shade(base, -0.3))
    c.noise(shade(base, -0.25), 0.05, x + 1, y + 1, w - 2, h - 2, k=k + 1)
    c.noise(shade(base, 0.2), 0.04, x + 1, y + 1, w - 2, h - 2, k=k + 2)
    if mossy > 0:
        for yy in range(y + h // 2, y + h - 1):
            for xx in range(x + 1, x + w - 1):
                if c.rand(xx, yy, k + 3) < mossy * (yy - y) / h:
                    c.px(xx, yy, mix(C["leaf_d"], base, 0.3))


def outline_all(c: Canvas, g: Canvas, dy=0):
    outline_non_ground(c, g, 0, c.h, dy)


# ─────────────── 石物 ───────────────

def slab(c: Canvas, p, w=4, ground="gravel", base=None, mossy=0.0, text=True, top_cap=False):
    """石碑・道標・石柱：幅 w（旧 16 px 単位）を 2 倍にして台座付きで立てる"""
    base = STONE if base is None else base
    g = with_ground(c, p, ground)
    bw = max(6, min(26, w * 2 + 2))
    x0 = (S - bw) // 2
    c.shadow_ellipse(16, 29, bw // 2 + 3, 3, 0.45)
    # 台座
    stone_block(c, x0 - 3, 24, bw + 6, 5, shade(base, -0.1), 0.4, 1)
    # 本体
    stone_block(c, x0, 4, bw, 21, base, mossy, 2)
    if top_cap:
        c.hline(3, x0 - 1, x0 + bw, shade(base, 0.35))
        c.hline(2, x0, x0 + bw - 1, shade(base, 0.15))
    if text:
        ink = shade(base, -0.5)
        cx = S // 2
        for y in range(7, 22, 2):
            if c.rand(cx, y, 5) < 0.85:
                c.px(cx, y, ink)
                if c.rand(cx, y, 6) < 0.5:
                    c.px(cx - 1, y, ink)
                else:
                    c.px(cx + 1, y, ink)
    outline_all(c, g)


def gravestones(c: Canvas, p):
    g = with_ground(c, p, "gravel")
    for (x, y, w, h, k) in [(2, 10, 8, 18, 1), (12, 6, 8, 22, 2), (22, 12, 8, 16, 3)]:
        c.shadow_ellipse(x + w // 2, y + h + 1, w // 2 + 2, 2, 0.4)
        stone_block(c, x - 1, y + h - 3, w + 2, 4, shade(STONE, -0.15), 0.4, k + 10)
        stone_block(c, x, y, w, h - 3, STONE, 0.12, k)
        c.hline(y - 1, x + 1, x + w - 2, shade(STONE, 0.3))
        ink = shade(STONE, -0.5)
        for yy in range(y + 3, y + h - 5, 2):
            c.px(x + w // 2, yy, ink)
    # 花立て・線香
    c.rect(11, 26, 2, 3, C["fluo"])
    c.px(11, 25, C["leaf_l"]); c.px(12, 24, C["red"])
    outline_all(c, g)


def water_gauge(c: Canvas, p):
    g = with_ground(c, p, "conc")
    c.shadow_ellipse(16, 29, 6, 2, 0.4)
    stone_block(c, 11, 26, 10, 4, C["conc"], 0, 1)
    c.gradient_v(13, 2, 6, 25, C["bone"], shade(C["bone"], -0.2))
    c.frame(12, 1, 8, 27, SUMI)
    for i, y in enumerate(range(4, 26, 3)):
        c.hline(y, 14, 17 if i % 2 else 15, SUMI)
        if i % 2 == 0:
            c.px(18, y, SUMI)
    c.rect(13, 16, 6, 11, mix(C["water_l"], C["bone"], 0.5))   # 過去の水位の汚れ
    c.hline(16, 13, 18, C["water_d"])
    outline_all(c, g)


def signpost_stone(c: Canvas, p):
    slab(c, p, 4, "soil", shade(STONE, -0.05), 0.35, True, True)
    c.rect(12, 2, 8, 2, shade(STONE, 0.2))     # 上に手の形の彫り込み代わりの角
    c.line(4, 12, 9, 12, shade(STONE, -0.5))    # 指さす矢印
    c.line(4, 12, 6, 10, shade(STONE, -0.5))
    c.line(4, 12, 6, 14, shade(STONE, -0.5))


def stone_pillar(c: Canvas, p):
    slab(c, p, 4, "conc", C["conc"], 0.1, False, True)
    c.vline(15, 6, 22, shade(C["conc"], 0.28))
    c.vline(19, 6, 22, shade(C["conc"], -0.3))


def stele(c: Canvas, p):
    slab(c, p, 6, "gravel", STONE, 0.2, True, False)
    # 上を丸く
    for x in range(9, 23):
        d = abs(x - 15.5)
        top = 4 + int(d * d / 12)
        for y in range(3, top):
            c.px(x, y, c.get(x, 31))
    c.line(9, 6, 12, 4, shade(STONE, 0.3)); c.line(12, 4, 19, 3, shade(STONE, 0.3)); c.line(19, 3, 22, 6, shade(STONE, 0.1))
    outline_all(c, Canvas(S, S))


def monument(c: Canvas, p):
    g = with_ground(c, p, "stone")
    c.shadow_ellipse(16, 30, 14, 2, 0.4)
    stone_block(c, 1, 25, 30, 5, shade(C["conc"], -0.15), 0.2, 1)
    stone_block(c, 4, 20, 24, 6, shade(C["conc"], -0.05), 0.1, 2)
    stone_block(c, 8, 2, 16, 19, C["conc"], 0.0, 3)
    c.gradient_h(9, 3, 3, 17, shade(C["conc"], 0.3), C["conc"])
    ink = shade(C["conc"], -0.55)
    for y in range(6, 18, 2):
        c.hline(y, 13, 18, ink)
    c.rect(12, 4, 8, 1, C["ochre"])          # 金属の銘板の縁
    outline_all(c, g)


def cow_statue(c: Canvas, p):
    g = with_ground(c, p, "gravel")
    base = shade(C["conc"], -0.1)
    c.shadow_ellipse(16, 29, 12, 3, 0.45)
    stone_block(c, 3, 24, 26, 5, shade(base, -0.15), 0.4, 1)
    # 伏せた牛
    c.ellipse(16, 17, 11, 6, base)
    c.ellipse(15, 15, 9, 4, shade(base, 0.15))
    c.disc(24, 12, 4, base)                        # 頭
    c.disc(23, 11, 3, shade(base, 0.15))
    c.rect(26, 13, 3, 2, shade(base, -0.1))        # 鼻先
    c.line(20, 9, 18, 6, shade(base, 0.25)); c.line(26, 9, 28, 6, shade(base, 0.25))   # 角
    c.px(24, 11, SUMI)
    c.rect(6, 19, 20, 4, shade(base, -0.25))       # 脚の折り目
    c.line(6, 13, 4, 18, shade(base, -0.2))
    c.noise(mix(C["leaf_d"], base, 0.4), 0.06, 4, 10, 24, 14, k=5)   # 苔
    c.rect(12, 6, 8, 3, C["red"])                  # 赤い前掛け（撫で牛）
    c.hline(6, 12, 19, shade(C["red"], 0.3))
    outline_all(c, g)


def mossy_rock(c: Canvas, p):
    g = Canvas(S, S, c.seed)
    moss(g, p)
    c.paste(g, 0, 0)
    c.shadow_ellipse(16, 28, 13, 4, 0.4)
    base = shade(STONE, -0.1)
    for (x, y, rx, ry, k) in [(15, 18, 13, 9, -0.25), (13, 16, 10, 7, 0.0), (11, 13, 6, 4, 0.2)]:
        c.ellipse(x, y, rx, ry, shade(base, k))
    c.texture(3, 9, 26, 18, base, 0.08, 3.0, k=2)
    for y in range(9, 28):
        for x in range(2, 30):
            v = c.get(x, y)
            if v is None or v == g.get(x, y):
                continue
            d = math.hypot((x - 15) / 13, (y - 18) / 9)
            if d > 1.0:
                c.px(x, y, g.get(x, y))
                continue
            t = 0.35 - 0.6 * d + (0.25 if y < 14 and x < 14 else 0)
            c.px(x, y, shade(base, t))
            if c.rand(x, y, 7) < 0.45 - (0.5 * (1 - d)) * 0.4 + (0.4 if y > 20 else 0):
                c.px(x, y, mix(C["leaf_d"], base, 0.25 + 0.3 * c.rand(x, y, 8)))
    c.outline(lambda x, y: c.get(x, y) is not None and c.get(x, y) != g.get(x, y), SUMI)


def fallen_rock(c: Canvas, p):
    g = with_ground(c, p, "gravel")
    base = C["soil_d"]
    c.shadow_ellipse(16, 27, 12, 4, 0.45)
    pts = [(4, 26), (2, 18), (8, 9), (17, 5), (26, 8), (30, 17), (27, 27)]
    c.poly(pts, base)
    c.poly([(6, 24), (5, 18), (10, 11), (17, 8), (23, 10), (24, 18), (20, 24)], shade(base, 0.12))
    c.poly([(9, 18), (11, 12), (17, 10), (19, 15), (14, 20)], shade(base, 0.3))
    c.line(17, 8, 24, 18, shade(base, -0.35)); c.line(24, 18, 22, 26, shade(base, -0.35))
    c.line(10, 11, 9, 18, shade(base, -0.25))
    c.noise(shade(base, -0.3), 0.06, 4, 8, 24, 18, k=3)
    for (x, y) in [(3, 27), (29, 25), (10, 28), (24, 29)]:
        c.disc(x, y, 1.5, shade(base, 0.05))
    outline_all(c, g)


def crack(c: Canvas, p):
    ground_tile(c, p, "stone")
    pts = [(2, 4), (7, 9), (9, 15), (14, 18), (17, 25), (22, 28), (27, 31)]
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        for w in range(-2, 3):
            c.line(x0 + w, y0, x1 + w, y1, shade(SUMI, -0.2 if abs(w) < 2 else 0.0))
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        c.line(x0 - 3, y0, x1 - 3, y1, shade(STONE_D, -0.2))
        c.line(x0 + 3, y0 + 1, x1 + 3, y1 + 1, shade(STONE_L, -0.1))
    c.line(9, 15, 4, 20, SUMI); c.line(14, 18, 20, 14, SUMI); c.line(20, 14, 24, 12, shade(SUMI, 0.1))
    c.noise(SUMI, 0.03, k=4)
    # 中心の暗さ（奥行き）
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        c.line(x0, y0, x1, y1, (3, 3, 8))


def masks_pile(c: Canvas, p):
    g = with_ground(c, p, "night")
    c.shadow_ellipse(16, 27, 13, 4, 0.5)
    faces = [(6, 20, 0.0), (16, 22, 0.1), (25, 19, -0.05), (10, 12, 0.15), (21, 12, 0.05), (16, 5, 0.2)]
    for (x, y, k) in faces:
        col = shade(C["bone"], k)
        c.ellipse(x, y, 5, 6, col)
        c.ellipse(x - 1, y - 1, 3, 4, shade(col, 0.15))
        c.px(x - 2, y - 1, SUMI); c.px(x + 2, y - 1, SUMI)   # 目の穴
        c.hline(y + 2, x - 1, x + 1, C["red"])
        c.vline(x + 5, y - 3, y + 3, shade(col, -0.4))
    c.px(6, 18, shade(C["bone"], -0.3))
    outline_all(c, g)


def spring(c: Canvas, p):
    g = Canvas(S, S, c.seed)
    moss(g, p)
    c.paste(g, 0, 0)
    for r, col in ((13, STONE_D), (11, C["water_d"]), (9, C["water"]), (6, C["water_l"])):
        c.ellipse(16, 17, r, r * 0.75, col)
    c.ellipse(14, 15, 3, 2, C["water_ll"])
    c.px(13, 14, C["bone"])
    for i in range(6):
        ang = i * 1.05
        x, y = 16 + int(math.cos(ang) * 12.5), 17 + int(math.sin(ang) * 9.5)
        c.disc(x, y, 2, STONE)
        c.px(x - 1, y - 1, STONE_L)
    for y in range(8, 27):
        for x in range(4, 29):
            v = c.get(x, y)
            if v in (C["water"], C["water_l"]) and c.rand(x, y, 3) < 0.12:
                c.px(x, y, C["water_ll"])
    c.outline(lambda x, y: c.get(x, y) in (STONE, STONE_L, STONE_D, C["water_d"]), SUMI)


def mound(c: Canvas, p):
    g = Canvas(S, S, c.seed)
    grass(g, p, C["grass_d"], C["grass"])
    c.paste(g, 0, 0)
    for r, k in ((15, -0.25), (13, -0.05), (10, 0.12), (6, 0.25)):
        c.ellipse(16, 17, r, r * 0.7, shade(C["grass"], k))
    c.noise(C["grass_l"], 0.12, 2, 5, 28, 22, k=4)
    c.noise(C["grass_dd"], 0.08, 2, 8, 28, 20, k=5)
    # 石室口
    c.rect(11, 16, 10, 10, SUMI)
    c.rect(12, 17, 8, 8, (4, 5, 12))
    c.rect(9, 14, 14, 3, STONE_D)
    c.hline(14, 9, 22, STONE)
    c.rect(9, 16, 2, 10, STONE_D); c.rect(21, 16, 2, 10, STONE_D)
    c.vline(9, 16, 25, STONE); c.vline(21, 16, 25, STONE)
    c.outline(lambda x, y: c.get(x, y) in (STONE, STONE_D), SUMI)


def zushi(c: Canvas, p):
    """厨子：黒漆の小さな仏龕。夜の床の上"""
    g = with_ground(c, p, "night")
    c.shadow_ellipse(16, 29, 10, 3, 0.5)
    body = C["wood_dd"]
    c.rect(8, 27, 16, 3, shade(body, -0.2))
    c.rect(7, 8, 18, 19, body)
    c.gradient_h(7, 8, 4, 19, shade(body, 0.25), body)
    c.rect(5, 6, 22, 3, shade(body, 0.1))
    c.hline(5, 6, 25, C["ochre"])
    c.rect(9, 10, 14, 16, (26, 18, 12))
    c.frame(9, 10, 14, 16, C["ochre"])
    c.vline(16, 10, 25, C["ochre"])            # 観音開きの合わせ目
    c.px(15, 18, C["glow"]); c.px(17, 18, C["glow"])
    c.rect(12, 13, 8, 9, (40, 30, 18))          # 内側（開いている）
    c.disc(16, 17, 2.5, C["ochre_l"])            # 仏像の金
    c.disc(16, 14, 1.5, C["ochre"])
    c.px(15, 14, C["glow"])
    outline_all(c, g)


# ─────────────── 社寺・門 ───────────────

def torii_flat(c: Canvas, p, wood=None, shrine=False):
    """1 マス版の鳥居（式内社の社殿・鳥居）。背の高い鳥居は TALL3"""
    col = VERMILION if wood is None else wood
    g = with_ground(c, p, "gravel")
    if shrine:
        # 奥に社殿
        c.rect(6, 6, 20, 14, C["plaster_d"])
        c.poly([(3, 8), (16, 1), (29, 8)], C["tile_roof_d"])
        c.poly([(5, 8), (16, 3), (27, 8)], C["tile_roof"])
        c.hline(8, 3, 28, C["tile_roof_l"])
        c.rect(12, 10, 8, 10, WOOD_DD)
        c.rect(13, 11, 6, 9, WOOD_D)
        c.rect(15, 12, 1, 3, C["glow"])
        c.rect(7, 19, 18, 2, STONE)
    c.shadow_ellipse(16, 29, 12, 3, 0.4)
    for x in (5, 24):
        c.gradient_h(x, 8, 3, 21, shade(col, 0.2), shade(col, -0.25))
        c.rect(x - 1, 27, 5, 2, STONE_D)
        c.hline(27, x - 1, x + 3, STONE)
    c.rect(2, 3, 28, 3, shade(col, -0.1))           # 笠木
    c.hline(2, 3, 28, shade(col, 0.2))
    c.hline(3, 2, 29, shade(SUMI, 0.1))
    c.rect(4, 9, 24, 2, shade(col, -0.05))            # 貫
    c.rect(14, 6, 4, 3, shade(C["bone"], -0.1))       # 額束
    outline_all(c, g)


def torii_tall(c: Canvas, p):
    """鳥居：幅 3 × 高さ 3 マス（5 m）。柱は底辺の中央のマスに、笠木と貫は上の行で左右のマスへ広がる"""
    g, bx, by = tall_ground(c, p, "gravel", 3, 3)
    col = VERMILION
    cx = bx + 16
    c.shadow_ellipse(cx, by + 29, 13, 3, 0.4)
    for x in (bx + 4, bx + 25):                         # 柱
        c.gradient_h(x, 14, 3, by + 16, shade(col, 0.2), shade(col, -0.25))
        c.vline(x, 14, by + 29, shade(col, 0.15))
        c.rect(x - 1, by + 27, 5, 3, STONE_D)
        c.hline(by + 27, x - 1, x + 3, STONE)
        for y in range(by - 10, by + 24, 12):
            c.hline(y, x, x + 2, shade(col, -0.3))
    c.rect(cx - 30, 4, 60, 5, shade(col, -0.1))           # 笠木（反り）
    c.line(cx - 33, 6, cx - 30, 3, shade(col, -0.1)); c.line(cx + 32, 6, cx + 29, 3, shade(col, -0.1))
    c.hline(4, cx - 29, cx + 28, shade(col, 0.2))
    c.rect(cx - 28, 9, 56, 3, SUMI)                       # 島木
    c.rect(cx - 24, 20, 48, 4, shade(col, -0.05))         # 貫
    c.rect(cx - 3, 12, 7, 8, shade(C["bone"], -0.1))      # 額束
    c.frame(cx - 3, 12, 7, 8, SUMI)
    c.px(cx, 15, SUMI)
    c.rect(bx + 4, 27, 24, 2, C["straw"])                 # 注連縄
    for x in range(bx + 6, bx + 26, 5):
        c.rect(x, 29, 1, 3, C["bone"])
    outline_tall(c, g, bx, by)


def temple_gate(c: Canvas, p, wooden=False):
    """山門：幅 3 × 高さ 3 マス。瓦屋根が上の行で左右へ張り出し、柱と扉は中央のマス"""
    g, bx, by = tall_ground(c, p, "stone", 3, 3)
    cx = bx + 16
    c.shadow_ellipse(cx, by + 29, 14, 3, 0.45)
    roof, roof_l, roof_d = C["tile_roof"], C["tile_roof_l"], C["tile_roof_d"]
    # 屋根（反り）
    c.poly([(cx - 46, 30), (cx - 20, 6), (cx + 19, 6), (cx + 45, 30)], roof_d)
    c.poly([(cx - 42, 29), (cx - 19, 8), (cx + 18, 8), (cx + 41, 29)], roof)
    for y in range(9, 29, 2):
        half = 19 + int((y - 8) * 1.1)
        c.hline(y, cx - half, cx + half - 1, shade(roof, 0.12) if (y // 2) % 2 else shade(roof, -0.1))
    c.hline(30, cx - 46, cx + 45, roof_l)
    c.hline(31, cx - 46, cx + 45, roof_d)
    c.rect(cx - 20, 5, 40, 2, roof_l)                     # 棟
    c.rect(cx - 22, 3, 4, 3, roof_d); c.rect(cx + 17, 3, 4, 3, roof_d)   # 鬼瓦
    c.rect(cx - 40, 32, 80, 3, C["plaster_d"])             # 軒下
    c.rect(cx - 40, 35, 80, 2, WOOD_DD)                    # 梁
    for x in range(cx - 36, cx + 36, 12):                  # 垂木
        c.rect(x, 32, 2, 3, WOOD_D)
    # 柱（中央のマスの中に 2 本）
    pole = WOOD_D if wooden else WOOD
    for x in (bx + 2, bx + 27):
        c.gradient_h(x, 36, 3, by + 24 - 36, shade(pole, 0.25), shade(pole, -0.25))
        c.rect(x - 1, by + 27, 5, 3, STONE_D)
    for x in (bx + 9, bx + 21):
        c.gradient_h(x, 37, 2, by + 22 - 37, shade(pole, 0.15), shade(pole, -0.3))
    # 扉と奥
    c.rect(bx + 11, 37, 10, by + 22 - 37, (14, 16, 26))
    c.gradient_v(bx + 11, 37, 10, by + 22 - 37, (14, 16, 26), shade(C["conc"], -0.3))
    c.rect(bx + 11, by + 14, 10, 8, mix(STONE, (14, 16, 26), 0.5))
    c.rect(bx + 5, 40, 4, by + 16 - 40, shade(WOOD_D, -0.1)); c.rect(bx + 23, 40, 4, by + 16 - 40, shade(WOOD_D, -0.1))
    for y in range(44, by + 14, 8):
        c.hline(y, bx + 5, bx + 8, WOOD_DD); c.hline(y, bx + 23, bx + 26, WOOD_DD)
    c.px(bx + 7, by, C["ochre"]); c.px(bx + 24, by, C["ochre"])
    c.rect(bx + 11, 37, 10, 6, C["bone"])                  # 扁額
    c.frame(bx + 11, 37, 10, 6, WOOD_DD)
    c.px(bx + 15, 39, SUMI); c.px(bx + 16, 40, SUMI)
    outline_tall(c, g, bx, by)


def iron_gate(c: Canvas, p, school=True):
    g = with_ground(c, p, "asphalt")
    c.shadow_ellipse(16, 29, 14, 2, 0.4)
    post = C["conc"] if school else STONE
    for x in (0, 27):
        stone_block(c, x, 2, 5, 28, post, 0.1, 1)
        c.hline(1, x, x + 4, shade(post, 0.3))
    if school:
        c.rect(1, 3, 3, 4, C["bone"])                # 表札
        c.px(2, 4, SUMI)
    bar = M
    c.rect(5, 6, 22, 2, MD); c.rect(5, 24, 22, 2, MD)
    for x in range(6, 27, 3):
        c.vline(x, 6, 27, bar)
        c.px(x, 5, ML)
        c.vline(x + 1, 8, 24, shade(bar, -0.35))
    c.rect(5, 15, 22, 1, MD)
    c.vline(16, 5, 28, MD)                          # 合わせ目
    c.rect(14, 12, 5, 4, ML)                         # 鎖・南京錠
    c.rect(15, 14, 3, 3, C["ochre"])
    outline_all(c, g)


def tunnel_arch(c: Canvas, p):
    ground_tile(c, p, "asphalt")
    conc = C["conc"]
    c.texture(0, 0, S, S, shade(conc, -0.15), 0.1, 5.0, k=2)
    # アーチの暗がり
    for y in range(0, S):
        for x in range(4, 28):
            d = math.hypot((x - 15.5) / 12, (y - 14) / 14)
            if y >= 14 or d <= 1.0:
                if 4 <= x < 28:
                    c.px(x, y, mix((6, 7, 14), (16, 20, 34), max(0.0, y / 32)))
    # 縁石とライン
    for y in range(0, 15):
        for x in range(0, S):
            d = math.hypot((x - 15.5) / 12, (y - 14) / 14)
            d2 = math.hypot((x - 15.5) / 14, (y - 14) / 16)
            if d > 1.0 and d2 <= 1.0:
                c.px(x, y, shade(conc, 0.15) if y < 8 else conc)
    c.rect(0, 14, 4, 18, shade(conc, 0.05)); c.rect(28, 14, 4, 18, shade(conc, -0.15))
    c.vline(3, 14, 31, SUMI); c.vline(28, 14, 31, SUMI)
    c.noise(shade(conc, -0.4), 0.05, k=6)
    c.noise(C["sumi"], 0.04, 0, 0, 4, 32, k=7)
    c.rect(14, 4, 4, 2, C["glow"])                  # 奥のトンネル灯
    glow_spot(c, 16, 6, 8, C["glow"], 0.35)
    c.hline(29, 6, 25, shade(C["bone"], -0.3))       # 白線の始まり


# ─────────────── 建物の面 ───────────────

def window_wall(c: Canvas, p, wall=None, frame=None, lit=False, glow=None, wooden=False, wide=False, rows=1):
    wall = C["conc"] if wall is None else wall
    frame = MD if frame is None else frame
    glow = C["glow"] if glow is None else glow
    c.texture(0, 0, S, S, wall, 0.08, 6.0, k=1)
    c.noise(shade(wall, -0.3), 0.04, k=2)
    c.hline(0, 0, S - 1, shade(wall, 0.25))
    c.hline(S - 1, 0, S - 1, shade(wall, -0.4))
    x0, y0, w, h = (3, 6, 26, 20) if wide else (6, 6, 20, 20)
    c.rect(x0 - 1, y0 + h, w + 2, 2, shade(wall, 0.2))   # 窓台
    c.hline(y0 + h + 2, x0 - 1, x0 + w, shade(wall, -0.35))
    if lit:
        c.gradient_v(x0, y0, w, h, glow, mix(glow, C["ochre"], 0.35))
        c.rect(x0 + 2, y0 + 3, w // 2 - 4, h - 8, mix(glow, C["bone"], 0.5))     # カーテンの明るい部分
    else:
        c.gradient_v(x0, y0, w, h, (22, 28, 46), (14, 18, 30))
        c.line(x0 + 2, y0 + h - 2, x0 + w - 3, y0 + 1, mix((22, 28, 46), C["conc"], 0.35))   # 反射
    c.frame(x0 - 1, y0 - 1, w + 2, h + 2, frame if not wooden else WOOD_D)
    c.vline(x0 + w // 2, y0, y0 + h - 1, frame if not wooden else WOOD_D)
    c.hline(y0 + h // 2, x0, x0 + w - 1, frame if not wooden else WOOD_D)
    c.frame(x0 - 2, y0 - 2, w + 4, h + 4, SUMI)
    if lit:
        glow_spot(c, 16, 16, 15, glow, 0.2)


def stairwell(c: Canvas, p, lit=False):
    wall = C["conc"]
    c.texture(0, 0, S, S, shade(wall, -0.05), 0.08, 6.0, k=1)
    c.hline(0, 0, S - 1, shade(wall, 0.25))
    c.hline(S - 1, 0, S - 1, shade(wall, -0.4))
    inner = C["fluo"] if lit else (16, 20, 34)
    c.rect(9, 2, 14, 28, mix(inner, (10, 12, 22), 0.0 if lit else 0.3))
    if lit:
        c.gradient_v(9, 2, 14, 28, mix(C["fluo"], C["bone"], 0.5), C["fluo"])
        c.rect(12, 4, 8, 1, C["bone"])            # 蛍光灯
    for y in range(6, 30, 4):                        # 段
        c.hline(y, 10, 22, shade(inner, -0.3))
        c.hline(y + 1, 10, 22, shade(inner, 0.15) if lit else shade(inner, -0.1))
    c.rect(8, 1, 16, 1, MD); c.rect(8, 30, 16, 1, MD)
    c.vline(8, 1, 30, MD); c.vline(23, 1, 30, MD)
    c.vline(16, 2, 29, shade(MD, 0.2))
    c.frame(7, 0, 18, 32, SUMI)
    c.rect(2, 12, 4, 5, C["bone"]); c.px(3, 14, SUMI)    # 号棟の札
    if lit:
        glow_spot(c, 16, 14, 16, C["fluo"], 0.25)


def shop_front(c: Canvas, p):
    """駄菓子屋の店先（点灯）：木の壁に開いた店の間口、商品の色"""
    wall = C["plaster"]
    c.texture(0, 0, S, S, wall, 0.08, 5.0, k=1)
    c.hline(0, 0, S - 1, shade(wall, 0.2))
    c.rect(0, 0, S, 4, WOOD_D); c.hline(4, 0, 31, WOOD_DD)   # 軒
    c.rect(2, 4, 28, 26, mix(C["glow"], C["ochre"], 0.3))
    c.gradient_v(2, 4, 28, 26, C["glow"], mix(C["glow"], C["ochre"], 0.5))
    # 棚の商品
    for row, y in enumerate((8, 14, 20)):
        c.hline(y + 4, 3, 28, WOOD_D)
        for i, x in enumerate(range(4, 28, 4)):
            col = (C["red"], C["fluo"], C["water_ll"], C["leaf_l"], C["ochre"], C["bone"])[(i * 2 + row) % 6]
            c.rect(x, y, 3, 4, col)
            c.px(x, y, shade(col, 0.4))
    c.rect(2, 26, 28, 4, WOOD)                       # 台
    c.hline(26, 2, 29, WOOD_L)
    c.vline(2, 4, 29, WOOD_D); c.vline(29, 4, 29, WOOD_DD)
    c.rect(11, 5, 10, 3, C["red"])                   # のれん代わりの色布
    c.hline(5, 11, 20, shade(C["red"], 0.3))
    c.frame(1, 3, 30, 28, SUMI)
    glow_spot(c, 16, 16, 16, C["glow"], 0.25)


def glass_door(c: Canvas, p, lit=True):
    wall = C["conc"]
    c.texture(0, 0, S, S, shade(wall, -0.1), 0.08, 6.0, k=1)
    c.hline(0, 0, S - 1, shade(wall, 0.25))
    inner = mix(C["fluo"], C["bone"], 0.5) if lit else (20, 26, 42)
    c.gradient_v(4, 2, 24, 28, inner, shade(inner, -0.35 if lit else -0.2))
    c.rect(4, 22, 24, 8, shade(inner, -0.2))          # 中の床
    c.vline(16, 2, 29, ML)                           # 中桟
    c.rect(12, 14, 2, 6, MD); c.rect(18, 14, 2, 6, MD)  # 取っ手
    c.line(6, 26, 14, 4, mix(inner, C["bone"], 0.5))  # 反射
    c.frame(3, 1, 26, 30, ML)
    c.frame(2, 0, 28, 32, SUMI)
    if lit:
        c.rect(6, 4, 20, 1, C["bone"])
        glow_spot(c, 16, 12, 16, C["fluo"], 0.25)


def shop_glass(c: Canvas, p):
    wall = C["conc"]
    c.texture(0, 0, S, S, shade(wall, -0.05), 0.08, 6.0, k=1)
    c.rect(0, 0, S, 3, C["ochre_d"]); c.hline(3, 0, 31, SUMI)    # 看板下端
    inner = mix(C["glow"], C["bone"], 0.4)
    c.gradient_v(2, 4, 28, 24, inner, mix(C["glow"], C["ochre"], 0.6))
    for i, x in enumerate(range(5, 27, 6)):          # 陳列
        col = (C["red"], C["leaf_l"], C["water_ll"], C["ochre"])[i % 4]
        c.rect(x, 16, 4, 6, col)
        c.px(x, 16, shade(col, 0.35))
    c.hline(22, 3, 28, WOOD_D)
    c.rect(2, 28, 28, 2, C["conc"]); c.hline(30, 2, 29, SUMI)
    c.vline(16, 4, 27, ML)
    c.line(4, 24, 12, 6, mix(inner, C["bone"], 0.6))
    c.frame(1, 3, 30, 26, ML)
    c.frame(0, 2, 32, 28, SUMI)
    glow_spot(c, 16, 14, 17, C["glow"], 0.25)


def wooden_door(c: Canvas, p):
    wall = C["plaster_d"]
    c.texture(0, 0, S, S, wall, 0.08, 5.0, k=1)
    c.hline(0, 0, S - 1, shade(wall, 0.2))
    c.rect(6, 3, 20, 27, WOOD_D)
    for x in range(7, 25, 3):
        c.vline(x, 4, 29, shade(WOOD_D, 0.15 if x % 2 else -0.15))
    c.rect(7, 4, 18, 8, WOOD)                        # 上部の板
    c.hline(4, 7, 24, WOOD_L)
    c.rect(9, 6, 14, 4, (30, 38, 60))                # 小窓
    c.hline(6, 9, 22, shade((30, 38, 60), 0.4))
    c.hline(12, 7, 24, WOOD_DD); c.hline(20, 7, 24, WOOD_DD)
    c.rect(20, 16, 2, 4, C["ochre"])                 # 取っ手
    c.frame(5, 2, 22, 29, WOOD_DD)
    c.frame(4, 1, 24, 31, SUMI)
    c.rect(2, 30, 28, 2, STONE_D)                    # 敷居


def shutter(c: Canvas, p):
    wall = C["conc"]
    c.texture(0, 0, S, S, shade(wall, -0.05), 0.08, 6.0, k=1)
    c.rect(0, 0, S, 4, MD); c.hline(4, 0, 31, SUMI)   # シャッターボックス
    c.hline(1, 0, 31, M)
    for y in range(5, 20, 2):
        c.hline(y, 2, 29, ML if y % 4 == 1 else M)
        c.hline(y + 1, 2, 29, MD)
    c.rect(2, 19, 28, 2, MD); c.hline(20, 2, 29, SUMI)
    c.rect(2, 21, 28, 10, (12, 14, 24))              # 半開きの中
    c.gradient_v(2, 21, 28, 10, (12, 14, 24), (20, 24, 40))
    c.rect(4, 27, 24, 3, shade(C["conc"], -0.35))     # 中の床
    c.noise(C["rust"], 0.04, 2, 5, 28, 15, k=5)
    c.vline(1, 4, 31, MD); c.vline(30, 4, 31, MD)
    c.frame(0, 4, 32, 28, SUMI)


def plank_floor_worn(c: Canvas, p):
    planks(c, p, 15, C["ochre_d"], shade(C["ochre_d"], -0.5), 8, False, True)
    c.noise(shade(C["ochre_d"], 0.25), 0.05, k=11)
    c.noise(SUMI, 0.02, k=12)
    c.hline(0, 0, S - 1, shade(C["ochre_d"], 0.1))


def bench(c: Canvas, p, wood=None, ground="asphalt"):
    wood = WOOD if wood is None else wood
    g = with_ground(c, p, ground)
    c.shadow_ellipse(16, 27, 14, 3, 0.4)
    # 背もたれ
    c.rect(3, 8, 26, 3, wood); c.hline(8, 3, 28, shade(wood, 0.25))
    c.rect(3, 12, 26, 3, wood); c.hline(12, 3, 28, shade(wood, 0.25))
    # 座面
    c.rect(2, 17, 28, 3, shade(wood, 0.1)); c.hline(17, 2, 29, shade(wood, 0.3))
    c.rect(2, 21, 28, 3, shade(wood, 0.05)); c.hline(21, 2, 29, shade(wood, 0.25))
    for x in (5, 25):
        c.rect(x, 7, 2, 18, MD)                      # フレーム
        c.rect(x - 1, 24, 4, 4, MD)
        c.px(x, 7, ML)
    c.noise(shade(wood, -0.3), 0.05, 2, 8, 28, 16, k=3)
    outline_all(c, g)


def ema_rack(c: Canvas, p):
    g = with_ground(c, p, "gravel")
    c.shadow_ellipse(16, 29, 13, 2, 0.4)
    c.rect(3, 4, 26, 3, WOOD_D); c.hline(4, 3, 28, WOOD_L)
    c.rect(2, 9, 28, 2, WOOD)
    c.rect(2, 19, 28, 2, WOOD)
    for x in (3, 27):
        c.rect(x, 4, 2, 25, WOOD_D)
        c.px(x, 4, WOOD_L)
    for i, (x, y) in enumerate([(6, 11), (13, 11), (20, 11), (9, 21), (17, 21), (24, 21)]):
        col = shade(C["ochre_l"], (i % 3) * 0.1 - 0.1)
        c.poly([(x, y + 2), (x + 3, y), (x + 6, y + 2), (x + 6, y + 7), (x, y + 7)], col)
        c.hline(y + 2, x, x + 6, shade(col, -0.35))
        c.px(x + 3, y, SUMI)
        c.px(x + 2, y + 4, C["red"] if i % 2 else SUMI)
        c.px(x + 4, y + 5, SUMI)
    outline_all(c, g)


def lantern_stone(c: Canvas, p):
    g = with_ground(c, p, "gravel")
    c.shadow_ellipse(16, 30, 8, 2, 0.45)
    base = STONE
    stone_block(c, 9, 26, 14, 4, shade(base, -0.1), 0.4, 1)
    c.gradient_h(14, 14, 5, 12, shade(base, 0.2), shade(base, -0.25))    # 竿
    stone_block(c, 10, 12, 12, 3, base, 0, 2)                            # 中台
    c.rect(11, 6, 10, 6, C["glow"])                                        # 火袋
    c.gradient_v(11, 6, 10, 6, mix(C["glow"], C["bone"], 0.4), C["ochre"])
    c.vline(13, 6, 11, shade(base, -0.4)); c.vline(18, 6, 11, shade(base, -0.4))
    c.poly([(7, 6), (16, 1), (25, 6)], shade(base, 0.05))                  # 笠
    c.hline(6, 7, 24, shade(base, -0.3))
    c.px(16, 0, shade(base, 0.2))
    c.noise(mix(C["leaf_d"], base, 0.4), 0.05, 9, 12, 14, 18, k=6)
    outline_all(c, g)
    glow_spot(c, 16, 9, 11, C["glow"], 0.35)


def elephant_slide(c: Canvas, p):
    g = with_ground(c, p, "sand")
    c.shadow_ellipse(16, 28, 13, 4, 0.4)
    body = (150, 160, 178)
    c.ellipse(11, 16, 9, 8, body)                     # 胴
    c.disc(7, 11, 5, shade(body, 0.05))                # 頭
    c.rect(2, 12, 4, 10, shade(body, -0.05))           # 鼻（階段側）
    c.line(1, 18, 2, 25, shade(body, -0.1))
    c.px(6, 10, SUMI)                                 # 目
    c.disc(9, 12, 3, shade(body, -0.15))               # 耳
    # 滑り台（背中から右へ）
    c.poly([(14, 10), (20, 10), (31, 26), (25, 28)], shade(body, 0.25))
    c.line(14, 10, 25, 28, shade(body, -0.2)); c.line(20, 10, 31, 26, shade(body, -0.2))
    c.gradient_v(16, 11, 4, 3, shade(body, 0.4), shade(body, 0.25))
    for x in (5, 10, 15):
        c.rect(x, 22, 3, 6, shade(body, -0.2))          # 脚
    c.noise(shade(body, -0.35), 0.06, 2, 8, 20, 18, k=3)
    c.rect(2, 13, 4, 1, shade(body, 0.2)); c.rect(2, 16, 4, 1, shade(body, 0.2)); c.rect(2, 19, 4, 1, shade(body, 0.2))
    outline_all(c, g)


def electric_pole(c: Canvas, p):
    g = with_ground(c, p, "grass")
    c.shadow_ellipse(16, 28, 4, 2, 0.35)
    c.gradient_h(14, 4, 4, 24, WOOD_L, WOOD_D)
    c.rect(13, 27, 6, 2, WOOD_DD)
    for y in (8, 14, 20):
        c.rect(11, y, 3, 2, C["bone"]); c.rect(18, y, 3, 2, C["bone"])   # 碍子
        c.px(11, y, C["ochre"]); c.px(18, y, C["ochre"])
        c.hline(y, 0, 10, MD); c.hline(y, 21, 31, MD)                   # 電線
    c.rect(12, 2, 8, 3, C["ochre"])                   # 注意札
    c.px(15, 3, SUMI); c.px(16, 3, SUMI)
    outline_all(c, g)


def bridge(c: Canvas, p):
    """橋（桁・欄干・橋灯）：通行可。板張りの床、両端に欄干と灯"""
    planks(c, p, 15, shade(C["conc"], -0.1), shade(C["conc"], -0.5), 8, False, False)
    c.noise(shade(C["conc"], -0.3), 0.05, k=5)
    for x in (0, 29):
        c.rect(x, 0, 3, S, MD)
        c.vline(x, 0, 31, M)
        c.vline(x + 2, 0, 31, shade(MD, -0.3))
        for y in range(2, 32, 8):
            c.rect(x - 1 if x else x, y, 5 if x else 4, 2, ML)
    c.rect(1, 2, 3, 4, C["glow"])                   # 橋灯
    c.rect(28, 2, 3, 4, C["glow"])
    c.hline(1, 1, 3, C["bone"]); c.hline(1, 28, 30, C["bone"])
    glow_spot(c, 2, 4, 9, C["glow"], 0.3)
    glow_spot(c, 29, 4, 9, C["glow"], 0.3)
    c.hline(31, 0, 31, SUMI)


# ─────────────── 塔（32×64） ───────────────

def tower_base(c: Canvas, p, ground="conc", w=1, h=5):
    g, bx, by = tall_ground(c, p, ground, w, h)
    c.shadow_ellipse(bx + 16, by + 29, 12, 3, 0.45)
    return g, bx, by


def clock_tower(c: Canvas, p):
    """時計塔：高さ 5 マス（8.5 m）"""
    g, bx, by = tower_base(c, p, "conc", 1, 5)
    body = C["plaster"]
    c.gradient_h(8, 16, 16, by + 12, shade(body, 0.1), shade(body, -0.25))
    c.rect(6, by + 26, 20, 4, STONE_D); c.hline(by + 26, 6, 25, STONE)
    c.hline(16, 8, 23, shade(body, 0.3))
    for y in range(22, by + 24, 8):
        c.hline(y, 9, 22, shade(body, -0.15))
    for y in range(48, by + 12, 28):                         # 窓
        c.rect(13, y, 6, 10, (24, 30, 48)); c.frame(12, y - 1, 8, 12, MD)
    c.rect(11, by + 10, 10, 16, WOOD_DD); c.rect(12, by + 11, 8, 15, WOOD_D)   # 扉
    c.poly([(4, 16), (16, 4), (28, 16)], C["tile_roof_d"])
    c.poly([(6, 16), (16, 6), (26, 16)], C["tile_roof"])
    c.hline(16, 4, 27, C["tile_roof_l"])
    c.vline(16, 0, 4, M); c.px(16, 0, ML)
    c.disc(16, 30, 7, C["glow"])                              # 時計盤
    c.disc(16, 30, 6, mix(C["glow"], C["bone"], 0.6))
    c.line(16, 30, 16, 25, SUMI); c.line(16, 30, 20, 31, SUMI)
    for (x, y) in [(16, 24), (22, 30), (16, 36), (10, 30)]:
        c.px(x, y, SUMI)
    c.outline(lambda x, y: (x - 16) ** 2 + (y - 30) ** 2 <= 49, MD)
    outline_tall(c, g, bx, by)
    glow_spot(c, 16, 30, 13, C["glow"], 0.3)


def fire_tower(c: Canvas, p):
    """火の見櫓：高さ 5 マス。鉄骨の脚が末広がり"""
    g, bx, by = tower_base(c, p, "asphalt", 1, 5)
    steel = MD
    bottom = by + 30
    for x in (4, 27):
        c.line(x, bottom, 10 if x < 16 else 21, 16, steel)
        c.line(x + 1, bottom, 11 if x < 16 else 22, 16, ML if x < 16 else shade(steel, -0.3))
    for y in range(22, bottom, 12):
        k = (y - 16) / (bottom - 16)
        xl, xr = int(10 - 6 * k), int(21 + 6 * k)
        c.hline(y, xl, xr, steel)
        c.line(xl, y, xr, y + 12, shade(steel, -0.2))
        c.line(xr, y, xl, y + 12, shade(steel, -0.2))
    c.rect(8, 6, 16, 3, ML); c.hline(6, 8, 23, C["stone_l"])      # 屋根
    c.rect(9, 9, 14, 7, STONE_D)                                   # 見張り台
    c.hline(9, 9, 22, STONE)
    c.rect(10, 10, 12, 5, (24, 30, 48))
    c.rect(13, 5, 6, 1, M)
    c.rect(15, 1, 2, 5, C["red"]); c.px(15, 1, shade(C["red"], 0.4))    # 半鐘
    c.rect(6, 16, 20, 2, steel); c.hline(16, 6, 25, ML)
    outline_tall(c, g, bx, by)


def light_tower(c: Canvas, p):
    """照明塔：高さ 6 マス（10 m）"""
    g, bx, by = tower_base(c, p, "soil", 1, 6)
    c.gradient_h(14, 12, 4, by + 18, ML, MD)
    c.rect(12, by + 28, 8, 3, MD)
    for y in range(20, by + 26, 12):
        c.hline(y, 13, 18, shade(MD, -0.2))
    c.rect(4, 4, 24, 10, MD); c.frame(4, 4, 24, 10, M)
    for x in range(6, 26, 4):
        c.rect(x, 5, 3, 4, C["glow"])
        c.rect(x, 10, 3, 3, mix(C["glow"], C["bone"], 0.5))
        c.px(x, 5, C["bone"])
    c.rect(14, 14, 4, 2, M)
    outline_tall(c, g, bx, by)
    for x in range(6, 26, 4):
        glow_spot(c, x + 1, 8, 11, C["glow"], 0.25)
    for y in range(by, by + 32):
        for x in range(S):
            d = math.hypot((x - 16) / 16, (y - by - 28) / 20)
            if d < 1.0:
                c.blend(x, y, C["glow"], (1 - d) * 0.15)


def water_tower(c: Canvas, p):
    """給水塔：幅 3 × 高さ 5 マス。タンクが上の 2 段で左右へ張り出す"""
    g, bx, by = tower_base(c, p, "conc", 3, 5)
    cx = bx + 16
    steel = MD
    for x in (bx + 6, bx + 24):
        c.rect(x, 62, 2, by + 30 - 62, steel)
        c.vline(x, 62, by + 29, ML if x < cx else shade(steel, -0.3))
    for y in range(68, by + 24, 14):
        c.line(bx + 7, y, bx + 25, y + 14, shade(steel, -0.2)); c.line(bx + 25, y, bx + 7, y + 14, shade(steel, -0.2))
    c.rect(bx + 4, 60, 24, 3, steel)
    body = C["conc"]
    c.rect(cx - 30, 14, 60, 44, body)                          # タンク
    c.gradient_h(cx - 30, 14, 60, 44, shade(body, 0.2), shade(body, -0.35))
    c.ellipse(cx, 14, 30, 6, shade(body, 0.3))
    c.ellipse(cx, 58, 30, 6, shade(body, -0.25))
    for y in (26, 40):
        c.hline(y, cx - 30, cx + 29, shade(body, -0.3))
    c.noise(C["rust"], 0.05, cx - 30, 20, 60, 36, k=4)
    c.rect(cx - 1, 4, 2, 10, MD); c.px(cx - 1, 3, C["red"]); c.px(cx, 3, C["red"])   # 航空障害灯
    c.rect(cx - 1, 62, 2, by + 30 - 62, mix(steel, C["water_l"], 0.4))              # 配管
    outline_tall(c, g, bx, by)


# ─────────────── 登録 ───────────────

FLAT3 = {
    "ガラス扉（点灯）": lambda c, p: glass_door(c, p, True),
    "シャッター（下・半開き）": shutter,
    "ベンチ": lambda c, p: bench(c, p),
    "待合ベンチ": lambda c, p: bench(c, p, C["ochre_d"], "conc"),
    "厨子": zushi,
    "古墳（盛土・石室口）": mound,
    "墓石（複数形）": gravestones,
    "常夜灯": lantern_stone,
    "店舗の木製戸": wooden_door,
    "店舗ガラス面（点灯）": shop_glass,
    "式内社の社殿・鳥居": lambda c, p: torii_flat(c, p, C["wood"], True),
    "旧校舎 廊下床（板）": plank_floor_worn,
    "旧校舎 窓（木枠）": lambda c, p: window_wall(c, p, C["plaster_d"], WOOD_D, False, None, True),
    "校門（鉄）": lambda c, p: iron_gate(c, p, True),
    "門扉": lambda c, p: iron_gate(c, p, False),
    "橋（桁・欄干・橋灯）": bridge,
    "水位標": water_gauge,
    "湧水（水面・小）": spring,
    "石の道標": signpost_stone,
    "石像（牛）": cow_statue,
    "石柱": stone_pillar,
    "石碑": stele,
    "記念碑": monument,
    "積まれた面": masks_pile,
    "窓（消灯・点灯）": lambda c, p: window_wall(c, p, None, None, False),
    "階段室（消灯）": lambda c, p: stairwell(c, p, False),
    "階段室（点灯・消灯）": lambda c, p: stairwell(c, p, True),
    "駄菓子屋の店先（点灯）": shop_front,
    "絵馬掛け": ema_rack,
    "苔むした石": mossy_rock,
    "落石（岩）": fallen_rock,
    "裂け目（暗）": crack,
    "象の滑り台": elephant_slide,
    "隧道アーチ": tunnel_arch,
    "電気柵ポール": electric_pole,
}

TALL3 = {
    "寺の山門": (lambda c, p: temple_gate(c, p, False), 3, 3),
    "山門（木・瓦）": (lambda c, p: temple_gate(c, p, True), 3, 3),
    "時計塔": (clock_tower, 1, 5),
    "火の見櫓": (fire_tower, 1, 5),
    "照明塔": (light_tower, 1, 6),
    "給水塔": (water_tower, 3, 5),
    "鳥居": (torii_tall, 3, 3),
}
