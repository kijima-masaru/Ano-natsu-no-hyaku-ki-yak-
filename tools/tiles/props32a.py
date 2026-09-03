"""32 px の部品（その 1）：道路まわり・看板・灯り・設備。paint32.py の FLAT / TALL に登録する。"""
import math

from px32 import C, Canvas, S, mix, shade
from paint32 import asphalt, concrete, ground_tile, grass, soil, interlock, planks, gravel, sand

M, ML, MD = C["metal"], C["metal_l"], C["metal_d"]
SUMI = C["sumi"]


def outline_non_ground(c: Canvas, g: Canvas, y_from=0, y_to=None, dy=0):
    """地面キャンバス g と違う画素（＝物）の外側に輪郭。dy は c 内での g の縦位置"""
    y_to = c.h if y_to is None else y_to

    def is_obj(x, y):
        if not (y_from <= y < y_to):
            return False
        v = c.get(x, y)
        gy = y - dy
        gv = g.get(x, gy) if 0 <= gy < g.h else None
        return v is not None and v != gv
    c.outline(is_obj, SUMI)


def with_ground(c: Canvas, p, ground):
    g = Canvas(S, S, c.seed)
    ground_tile(g, p, ground)
    c.paste(g, 0, c.h - S)
    return g


def glow_spot(c: Canvas, cx, cy, r, col, strength=0.5, squash=1.4):
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            d = math.hypot((x - cx), (y - cy) * squash) / r
            if d < 1.0 and c.get(x, y) is not None:
                c.blend(x, y, col, (1 - d) ** 1.7 * strength)


# ─────────────── 道路 ───────────────

def line_paint(c: Canvas, p, horizontal=True, thick=4, pos=14, dashed=False, base=None, warm=False):
    asphalt(c, p, base, warm)
    for i in range(S):
        if dashed and (i % 16) >= 10:
            continue
        for k in range(thick):
            x, y = (i, pos + k) if horizontal else (pos + k, i)
            col = C["bone"] if c.rand(x, y, 3) > 0.22 else mix(C["bone"], C["conc"], 0.6)
            c.px(x, y, col)
    # 縁のかすれ
    for i in range(S):
        if c.rand(i, 90, 4) < 0.3:
            x, y = (i, pos - 1) if horizontal else (pos - 1, i)
            c.px(x, y, mix(C["bone"], C["asphalt"], 0.6))


def curb(c: Canvas, p):
    interlock(c, p, C["stone"], C["fog"])
    g = Canvas(S, S, c.seed)
    asphalt(g, p)
    for y in range(16, S):
        for x in range(S):
            c.px(x, y, g.get(x, y))
    c.gradient_v(0, 13, S, 3, C["stone_l"], C["stone"])
    c.hline(16, 0, S - 1, C["stone_d"])
    c.hline(17, 0, S - 1, shade(C["asphalt"], -0.4))
    for x in range(0, S, 11):
        c.vline(x, 13, 15, C["stone_d"])


def drain(c: Canvas, p, tone=None):
    asphalt(c, p, tone)
    c.gradient_v(0, 10, S, 4, C["stone_l"], C["stone"])
    c.rect(0, 14, S, 4, shade(C["night"], -0.3))
    c.hline(14, 0, S - 1, SUMI)
    c.gradient_v(0, 18, S, 3, C["stone_d"], C["stone"])
    c.hline(21, 0, S - 1, shade(C["asphalt"], -0.3))
    for x in range(0, S, 12):
        c.vline(x, 10, 13, C["stone_d"])


def grating(c: Canvas, p):
    asphalt(c, p, C["fog"])
    c.rect(0, 8, S, 16, C["stone"])
    c.hline(8, 0, S - 1, C["stone_l"])
    c.hline(23, 0, S - 1, C["stone_d"])
    for x in range(2, S, 5):
        c.rect(x, 10, 2, 12, SUMI)
        c.px(x + 2, 10, C["stone_l"])
    c.hline(16, 0, S - 1, C["stone_d"])
    c.noise(C["rust_d"], 0.04, 0, 8, S, 16, k=5)


def guardrail(c: Canvas, p):
    with_ground(c, p, "asphalt")
    c.gradient_v(0, 0, S, 8, C["fog"], C["stone"])   # 歩道側
    c.hline(8, 0, S - 1, C["stone_d"])
    for x in (6, 22):
        c.gradient_h(x, 9, 4, 21, ML, MD)
        c.rect(x - 1, 30, 6, 2, SUMI)
    c.gradient_v(0, 12, S, 10, C["bone"], mix(C["bone"], C["conc"], 0.35))
    c.hline(16, 0, S - 1, C["conc"])                 # ビームの谷
    c.hline(17, 0, S - 1, mix(C["bone"], C["conc"], 0.5))
    c.hline(12, 0, S - 1, shade(C["bone"], 0.1))
    c.hline(21, 0, S - 1, C["fog"])
    c.hline(22, 0, S - 1, SUMI)
    c.hline(11, 0, S - 1, SUMI)
    c.noise(C["conc"], 0.05, 0, 12, S, 10, k=2)
    for x in (7, 23):
        c.rect(x, 14, 2, 2, MD)  # ボルト


def barricade(c: Canvas, p):
    with_ground(c, p, "asphalt")
    c.shadow_ellipse(16, 30, 14, 3, 0.45)
    for x in (5, 25):
        c.line(x, 12, x - 2, 28, ML)
        c.line(x + 1, 12, x - 1, 28, MD)
        c.line(x + 2, 12, x + 4, 28, ML)
        c.line(x + 3, 12, x + 5, 28, MD)
        c.hline(28, x - 3, x + 5, MD)
    c.rect(0, 10, S, 12, C["bone"])
    for y in range(10, 22):
        for x in range(S):
            if ((x + y) // 5) % 2 == 0:
                c.px(x, y, C["red"])
    c.gradient_v(0, 10, S, 3, shade(C["bone"], 0.15), C["bone"])
    for y in range(10, 13):
        for x in range(S):
            if ((x + y) // 5) % 2 == 0:
                c.px(x, y, shade(C["red"], 0.15))
    c.hline(21, 0, S - 1, shade(C["red"], -0.4))
    c.frame(0, 10, S, 12, SUMI)
    c.rect(14, 6, 4, 3, SUMI)
    c.rect(15, 5, 2, 2, C["glow"])
    glow_spot(c, 16, 6, 6, C["glow"], 0.5)


def fence_locked(c: Canvas, p):
    with_ground(c, p, "asphalt")
    for y in range(S):
        for x in range(S):
            if (x + y) % 5 == 0 or (x - y) % 5 == 0:
                c.px(x, y, C["conc"])
            elif (x + y) % 5 == 1 or (x - y) % 5 == 1:
                c.px(x, y, C["fog"])
    c.frame(0, 0, S, S, ML)
    c.frame(1, 1, S - 2, S - 2, M)
    c.rect(15, 0, 2, S, ML)
    c.hline(0, 0, S - 1, shade(ML, 0.2))
    c.rect(12, 12, 8, 4, M)                 # 鎖
    for x in range(12, 20, 2):
        c.px(x, 13, ML)
    c.rect(12, 16, 8, 8, C["red"])
    c.hline(16, 12, 19, shade(C["red"], 0.3))
    c.vline(12, 16, 23, shade(C["red"], 0.15))
    c.px(16, 20, SUMI)
    c.px(16, 21, SUMI)
    c.rect(12, 24, 8, 1, SUMI)


def parking_car(c: Canvas, p):
    """駐車車両：1 マス幅、2 マス長（3.4 m）。上のマスは Overhead に載る"""
    from paint32 import tall_ground, outline_tall
    g, bx, by = tall_ground(c, p, "asphalt", 1, 2)
    c.shadow_ellipse(16, 34, 15, 30, 0.45)
    body = C["deep"]
    c.rect(4, 6, 24, 54, body)
    c.gradient_h(4, 6, 24, 54, shade(body, 0.12), shade(body, -0.15))
    c.rect(6, 6, 20, 5, shade(body, 0.15))   # ボンネット
    c.gradient_v(6, 7, 20, 8, shade(body, 0.2), body)
    c.rect(6, 16, 20, 9, C["night"])          # 前ガラス
    c.gradient_v(6, 16, 20, 9, shade(C["night"], 0.35), C["night"])
    c.rect(7, 25, 18, 18, shade(body, 0.06))  # 屋根
    c.gradient_v(7, 25, 18, 4, shade(body, 0.28), shade(body, 0.06))
    c.rect(6, 43, 20, 7, C["night"])          # 後ガラス
    c.gradient_v(6, 43, 20, 7, C["night"], shade(C["night"], 0.2))
    c.rect(6, 52, 20, 6, shade(body, -0.05))  # トランク
    c.px(5, 8, C["ochre"]); c.px(6, 8, C["ochre"]); c.px(25, 8, C["ochre"]); c.px(26, 8, C["ochre"])   # ヘッドライト
    c.rect(5, 56, 3, 2, C["red"]); c.rect(24, 56, 3, 2, C["red"])                                     # テールランプ
    for y in (12, 44):                          # タイヤ
        c.rect(2, y, 2, 10, SUMI); c.rect(28, y, 2, 10, SUMI)
    c.rect(6, 25, 1, 18, ML); c.rect(25, 25, 1, 18, MD)    # ドア線
    c.hline(34, 7, 24, shade(body, -0.25))                   # 前後ドアの境
    c.rect(3, 22, 2, 3, ML); c.rect(27, 22, 2, 3, MD)        # ミラー
    c.frame(4, 6, 24, 54, SUMI)


def bike_shed(c: Canvas, p):
    with_ground(c, p, "asphalt")
    c.gradient_v(0, 0, S, 7, C["stone_l"], C["fog"])
    c.hline(0, 0, S - 1, C["conc"])
    c.hline(7, 0, S - 1, SUMI)
    for x in (2, 13, 24):
        c.disc(x + 3, 20, 5, C["conc"])
        c.disc(x + 3, 20, 4, C["asphalt"])
        c.disc(x + 3, 20, 1.5, C["conc"])
        for a in range(0, 360, 45):
            c.line(x + 3, 20, x + 3 + int(3.5 * math.cos(math.radians(a))), 20 + int(3.5 * math.sin(math.radians(a))), C["fog"])
        c.line(x + 3, 15, x + 5, 11, ML)
        c.hline(11, x + 3, x + 7, ML)
    c.hline(27, 0, S - 1, SUMI)
    c.rect(0, 28, S, 4, shade(C["asphalt"], -0.1))


def carport_flat(c: Canvas, p):
    c.fill(C["fog"])
    for x in range(0, S, 4):
        c.gradient_h(x, 0, 4, S, C["stone_l"], C["fog"])
    c.rect(0, 0, S, 2, C["conc"])
    c.rect(0, S - 2, S, 2, C["dusk"])
    c.frame(0, 0, S, S, SUMI)
    c.rect(8, 10, 16, 12, C["fog"])
    c.dither(8, 10, 16, 12, C["dusk"], 0.5)


# ─────────────── 看板・掲示 ───────────────

def signboard(c: Canvas, p, board, ink, frame_col, lines, paper=False, legs=True, ground="asphalt", top=None):
    with_ground(c, p, ground)
    if legs:
        c.rect(6, 22, 3, 9, MD); c.rect(23, 22, 3, 9, MD)
        c.vline(6, 22, 30, M); c.vline(23, 22, 30, M)
        c.rect(4, 30, 24, 2, SUMI)
    c.rect(2, 3, 28, 19, board)
    c.gradient_v(2, 3, 28, 4, shade(board, 0.15), board)
    c.gradient_v(2, 18, 28, 4, board, shade(board, -0.15))
    c.frame(1, 2, 30, 21, frame_col)
    c.frame(0, 1, S, 23, SUMI)
    if top is not None:
        c.rect(0, 0, S, 2, top)
    if paper:
        for (x, y, w, h) in [(4, 5, 10, 8), (16, 5, 11, 6), (5, 14, 8, 6), (15, 12, 12, 8)]:
            c.rect(x, y, w, h, C["bone"])
            c.hline(y + 2, x + 1, x + w - 3, C["fog"])
            c.hline(y + 4, x + 1, x + w - 4, C["fog"])
            c.px(x + w // 2, y, C["red"])
            c.hline(y + h, x + 1, x + w, shade(board, -0.35))
    else:
        for i, (x, y, w) in enumerate(lines):
            c.hline(y, x, x + w, ink)
            c.hline(y + 1, x, x + w - 3, shade(ink, 0.2))


def bulletin(c: Canvas, p):
    signboard(c, p, C["ochre"], SUMI, C["wood_d"], [], True, True, "asphalt", C["wood_d"])


def map_board(c: Canvas, p):
    signboard(c, p, C["bone"], C["dusk"], C["stone_d"], [], False, True, "stone")
    c.line(6, 18, 12, 7, C["dusk"]); c.line(12, 7, 26, 10, C["dusk"]); c.line(14, 19, 26, 10, C["dusk"])
    c.rect(8, 10, 4, 4, C["leaf_l"]); c.rect(19, 14, 4, 4, C["leaf_l"])
    c.rect(11, 11, 3, 3, C["water_l"])
    c.disc(16, 8, 1.5, C["red"])


def info_board(c: Canvas, p):
    signboard(c, p, C["ochre_d"], C["wood_dd"], C["wood_d"], [], False, True, "moss", C["wood"])
    for (x, y, w, h) in [(6, 7, 10, 6), (12, 11, 12, 8), (18, 5, 8, 5)]:
        c.frame(x, y, w, h, C["wood_dd"])
    c.disc(15, 14, 1, SUMI)
    c.hline(19, 5, 26, C["wood_dd"])


def shop_sign(c: Canvas, p):
    signboard(c, p, C["ochre"], C["rust_d"], C["rust_d"], [(6, 8, 18), (6, 12, 10), (6, 16, 20)], False, True, "asphalt")
    c.noise(C["bone"], 0.08, 3, 4, 26, 17, k=3)
    c.vline(24, 6, 20, C["rust_d"]); c.vline(10, 12, 20, C["rust_d"])
    c.noise(C["rust"], 0.06, 3, 4, 26, 17, k=4)


def plain_sign(c: Canvas, p):
    with_ground(c, p, "asphalt")
    c.rect(14, 22, 4, 9, MD); c.vline(14, 22, 30, M)
    c.rect(2, 4, 28, 17, C["stone"])
    c.gradient_v(3, 5, 26, 15, C["fog"], shade(C["fog"], -0.2))
    c.frame(2, 4, 28, 17, SUMI)
    c.hline(5, 3, 28, C["stone_l"])
    c.noise(C["dusk"], 0.06, 3, 5, 26, 15, k=2)
    c.rect(8, 0, 16, 2, M); c.px(10, 2, MD); c.px(21, 2, MD)   # 消えた照明のアーム


def timetable(c: Canvas, p):
    with_ground(c, p, "asphalt")
    c.gradient_h(14, 12, 4, 19, ML, MD)
    c.rect(12, 30, 8, 2, SUMI)
    c.disc(16, 7, 7, C["bone"]); c.disc(16, 7, 5.5, C["fog"]); c.disc(16, 7, 2, C["bone"])
    c.hline(4, 13, 19, C["bone"])
    c.rect(6, 16, 20, 11, C["bone"])
    for y in (18, 21, 24):
        c.hline(y, 8, 23, C["dusk"])
    for x in (10, 15, 20):
        c.px(x, 19, C["dusk"]); c.px(x, 22, C["dusk"]); c.px(x, 25, C["dusk"])
    c.frame(6, 16, 20, 11, SUMI)
    c.outline(lambda x, y: c.get(x, y) in (C["bone"], C["fog"]) and y < 16, SUMI)


# ─────────────── 灯り ───────────────

def fluorescent(c: Canvas, p):
    c.texture(0, 0, S, S, C["night"], 0.08, 7.0, k=1)
    glow_spot(c, 16, 15, 18, C["fluo"], 0.35, 1.8)
    c.rect(2, 11, 28, 9, C["dusk"])
    c.gradient_v(2, 11, 28, 2, C["fog"], C["dusk"])
    c.rect(4, 13, 24, 5, C["fluo"])
    c.rect(5, 14, 22, 2, C["bone"])
    c.rect(0, 12, 2, 7, C["fog"]); c.rect(30, 12, 2, 7, C["fog"])
    c.hline(20, 2, 29, SUMI)
    c.frame(2, 11, 28, 9, shade(C["dusk"], -0.3))


def emergency_light(c: Canvas, p):
    c.texture(0, 0, S, S, C["night"], 0.08, 7.0, k=1)
    glow_spot(c, 16, 14, 14, C["fluo"], 0.35, 1.2)
    c.rect(8, 8, 16, 13, C["fog"])
    c.rect(10, 10, 12, 9, C["fluo"])
    c.rect(11, 11, 10, 3, C["bone"])
    c.rect(13, 15, 2, 3, C["bone"]); c.rect(16, 15, 3, 1, C["bone"]); c.px(17, 16, C["bone"])   # 走る人
    c.frame(8, 8, 16, 13, SUMI)
    c.hline(9, 9, 22, C["conc"])


def police_light(c: Canvas, p):
    g = with_ground(c, p, "asphalt")
    glow_spot(c, 16, 8, 14, C["red"], 0.45, 1.4)
    c.gradient_h(14, 12, 4, 19, ML, MD)
    c.rect(12, 30, 8, 2, SUMI)
    c.rect(11, 4, 10, 7, C["red"])
    c.rect(12, 3, 8, 1, C["red"])
    c.gradient_v(12, 4, 8, 3, shade(C["red"], 0.4), C["red"])
    c.px(13, 5, C["glow"]); c.px(14, 5, C["glow"])
    c.rect(10, 11, 12, 2, MD)
    c.hline(1, 13, 18, shade(C["red"], -0.3))
    outline_non_ground(c, g, 0, 30)


def streetlamp_uniform(c: Canvas, p):
    from paint32 import streetlamp
    streetlamp(c, p, "asphalt")


# ─────────────── 設備 ───────────────

def vending(c: Canvas, p):
    c.gradient_v(0, 0, S, S, C["stone_l"], C["fog"])
    c.frame(0, 0, S, S, SUMI)
    c.vline(1, 1, 30, C["stone_l"]); c.hline(1, 1, 30, C["stone_l"])
    c.rect(3, 3, 19, 16, C["glow"])
    c.rect(4, 4, 17, 14, C["bone"])
    for row, y in enumerate((5, 10, 15)):
        for i, x in enumerate(range(5, 21, 4)):
            col = (C["red"], C["fluo"], C["ochre"], C["red"], C["water_ll"], C["leaf_l"])[(i + row) % 6]
            c.rect(x, y, 3, 3, col)
            c.px(x, y, shade(col, 0.4))
            c.hline(y + 3, x, x + 2, shade(C["bone"], -0.35))
    c.rect(23, 3, 6, 25, C["red"])
    c.gradient_h(23, 3, 6, 25, shade(C["red"], 0.25), shade(C["red"], -0.25))
    for y in (7, 11, 15):
        c.rect(25, y, 2, 2, C["bone"])
    c.rect(24, 20, 4, 5, C["night"]); c.px(25, 21, C["fluo"])   # 硬貨投入
    c.rect(3, 20, 19, 2, C["dusk"])
    c.rect(3, 22, 19, 6, SUMI)
    c.hline(23, 4, 20, C["night"])
    c.rect(2, 28, 28, 2, C["dusk"]); c.hline(30, 2, 29, SUMI)
    glow_spot(c, 12, 11, 12, C["glow"], 0.15)


def phone_booth(c: Canvas, p):
    g = with_ground(c, p, "asphalt")
    c.shadow_ellipse(16, 30, 12, 3, 0.4)
    c.rect(6, 2, 20, 28, C["fluo"])
    c.gradient_v(6, 2, 20, 28, shade(C["fluo"], 0.1), shade(C["fluo"], -0.2))
    c.dither(7, 3, 18, 26, C["bone"], 0.25)
    c.frame(6, 2, 20, 28, C["conc"])
    c.rect(6, 0, 20, 3, C["fog"]); c.hline(0, 6, 25, C["conc"])
    c.rect(15, 3, 2, 27, C["conc"])
    c.rect(18, 10, 6, 8, C["deep"]); c.px(20, 11, C["fog"]); c.rect(19, 15, 4, 1, C["bone"])
    c.rect(8, 12, 4, 6, C["deep"]); c.rect(8, 12, 4, 1, C["conc"])
    c.rect(6, 28, 20, 2, C["dusk"])
    outline_non_ground(c, g, 0, 30)


def postboxes(c: Canvas, p):
    g = with_ground(c, p, "asphalt")
    c.rect(2, 4, 28, 24, C["conc"])
    c.hline(4, 2, 29, C["stone_l"]); c.vline(2, 4, 27, C["stone_l"])
    for row in range(2):
        for col in range(3):
            x, y = 3 + col * 9, 5 + row * 11
            c.gradient_v(x, y, 8, 10, C["stone_l"], C["fog"])
            c.rect(x + 1, y + 3, 6, 1, SUMI)
            c.rect(x + 1, y + 7, 4, 2, C["bone"] if (row + col) % 2 else C["ochre"])
            c.px(x + 7, y + 5, C["dusk"])
    c.hline(27, 2, 29, C["stone_d"])
    c.frame(2, 4, 28, 24, SUMI)
    c.rect(3, 28, 26, 1, SUMI)


def desk_chair(c: Canvas, p):
    planks(c, p, 15, C["ochre_d"], shade(C["ochre_d"], -0.4), 8, False, True)
    c.shadow_ellipse(16, 20, 13, 5, 0.35)
    c.rect(4, 6, 24, 14, C["wood"])
    c.gradient_v(4, 6, 24, 14, C["wood_l"], C["wood"])
    c.hline(6, 4, 27, shade(C["wood_l"], 0.2)); c.vline(4, 6, 19, C["wood_l"])
    c.hline(19, 4, 27, C["wood_d"]); c.vline(27, 6, 19, C["wood_d"])
    c.noise(C["wood_d"], 0.06, 5, 7, 22, 12, k=2)
    c.rect(5, 20, 2, 3, C["wood_dd"]); c.rect(25, 20, 2, 3, C["wood_dd"])
    c.rect(10, 22, 12, 8, C["wood_d"]); c.hline(22, 10, 21, C["wood"])
    c.rect(12, 24, 8, 4, C["wood"])
    c.rect(10, 30, 2, 2, SUMI); c.rect(20, 30, 2, 2, SUMI)
    c.frame(4, 6, 24, 14, SUMI)


def blackboard(c: Canvas, p):
    planks(c, p, 15, C["wood"], C["wood_d"], 8, False, True)
    c.rect(2, 2, 28, 22, C["pine_d"])
    c.texture(2, 2, 28, 22, C["pine_d"], 0.1, 6.0, k=3)
    c.frame(1, 1, 30, 24, C["wood_d"]); c.frame(0, 0, S, 26, SUMI)
    c.hline(1, 1, 30, C["wood_l"])
    for (x, y, w) in [(5, 6, 14), (5, 10, 8), (7, 14, 18), (5, 18, 10)]:
        c.hline(y, x, x + w, C["bone"]); c.hline(y + 1, x + 1, x + w - 4, C["conc"])
    c.rect(2, 26, 28, 2, C["wood"]); c.rect(5, 26, 4, 1, C["bone"])
    c.hline(28, 2, 29, SUMI)


def weather_box(c: Canvas, p):
    g = with_ground(c, p, "grass")
    c.shadow_ellipse(16, 30, 8, 2, 0.4)
    c.rect(8, 24, 2, 8, C["fog"]); c.rect(22, 24, 2, 8, C["fog"])
    c.rect(6, 4, 20, 20, C["bone"])
    for y in range(8, 22, 4):
        c.hline(y, 8, 23, C["conc"]); c.hline(y + 1, 8, 23, C["stone_l"])
    c.rect(6, 2, 20, 2, C["conc"]); c.rect(4, 0, 24, 2, C["fog"])
    c.vline(25, 4, 23, C["conc"]); c.hline(23, 6, 25, C["fog"])
    outline_non_ground(c, g, 0, 30)


def platform(c: Canvas, p):
    g = with_ground(c, p, "soil")
    c.shadow_ellipse(16, 28, 14, 3, 0.4)
    c.rect(4, 10, 24, 16, C["conc"])
    c.gradient_v(4, 10, 24, 4, C["stone_l"], C["conc"])
    c.rect(4, 22, 24, 4, C["fog"]); c.hline(25, 4, 27, C["stone_d"])
    c.rect(4, 26, 24, 2, C["dusk"])
    c.vline(6, 4, 10, ML); c.vline(25, 4, 10, ML); c.hline(4, 6, 25, ML)
    c.hline(5, 7, 24, MD)
    outline_non_ground(c, g, 0, 30)


def dugout(c: Canvas, p):
    with_ground(c, p, "asphalt")
    c.gradient_v(0, 0, S, 6, C["stone_l"], C["fog"]); c.hline(6, 0, S - 1, SUMI)
    c.rect(2, 7, 28, 16, C["night"])
    c.gradient_v(2, 7, 28, 6, C["deep"], C["night"])
    c.rect(4, 14, 24, 3, C["wood_d"]); c.hline(14, 4, 27, C["wood"])
    c.rect(0, 7, 2, 25, C["fog"]); c.rect(30, 7, 2, 25, C["fog"])
    c.rect(2, 23, 28, 2, C["conc"]); c.hline(25, 2, 29, C["dusk"])


def veranda(c: Canvas, p):
    c.texture(0, 0, S, S, C["conc"], 0.06, 8.0, k=1)
    c.gradient_v(0, 0, S, 12, C["conc"], C["fog"])
    c.hline(12, 0, S - 1, C["dusk"])
    c.rect(0, 13, S, 3, C["stone_l"]); c.hline(13, 0, S - 1, C["bone"])
    c.rect(0, 16, S, 14, C["dusk"])
    for x in range(2, S, 5):
        c.vline(x, 16, 29, C["fog"])
    c.hline(30, 0, S - 1, SUMI)
    c.rect(22, 4, 8, 8, C["stone_l"]); c.frame(22, 4, 8, 8, C["fog"]); c.rect(24, 6, 4, 4, C["dusk"])
    c.hline(8, 2, 18, C["conc"])
    c.rect(5, 9, 3, 4, C["bone"]); c.rect(12, 9, 4, 4, C["fog"])


def laundry(c: Canvas, p):
    with_ground(c, p, "sand")
    for x in (4, 27):
        c.gradient_h(x, 10, 2, 22, ML, MD); c.rect(x - 1, 31, 4, 1, SUMI)
        c.hline(10, x - 2, x + 3, ML)
    c.hline(12, 2, 29, C["conc"]); c.hline(18, 2, 29, C["conc"])
    for (x, w, col) in [(8, 6, C["bone"]), (16, 4, C["fog"]), (22, 4, C["bone"])]:
        c.gradient_v(x, 13, w, 8, col, shade(col, -0.2))
        c.px(x + w - 1, 20, shade(col, -0.3))
    c.px(10, 24, C["bone"])


def sandbox_swing(c: Canvas, p):
    with_ground(c, p, "sand")
    c.frame(0, 20, S, 12, C["fog"]); c.hline(20, 0, S - 1, C["stone_l"])
    c.rect(2, 2, 28, 2, ML); c.hline(1, 2, 29, shade(ML, 0.2))
    c.line(4, 4, 2, 19, ML); c.line(5, 4, 3, 19, MD)
    c.line(27, 4, 29, 19, ML); c.line(26, 4, 28, 19, MD)
    for x in (10, 20):
        c.vline(x, 4, 13, C["conc"]); c.vline(x + 1, 4, 13, C["fog"])
        c.rect(x - 2, 14, 6, 2, C["wood_d"]); c.hline(14, x - 2, x + 3, C["wood"])
    c.rect(14, 26, 3, 1, C["rust"]); c.px(16, 25, C["rust"])


def hen_house(c: Canvas, p):
    with_ground(c, p, "soil")
    c.gradient_v(0, 0, S, 6, C["stone_l"], C["fog"]); c.hline(6, 0, S - 1, SUMI)
    c.rect(2, 7, 28, 22, C["wood_dd"])
    for y in range(7, 29):
        for x in range(2, 30):
            if (x + y) % 4 == 0 or (x - y) % 4 == 0:
                c.px(x, y, C["conc"])
    c.rect(6, 18, 20, 2, C["wood"]); c.hline(18, 6, 25, C["wood_l"])
    c.rect(4, 24, 8, 4, C["ochre"]); c.hline(24, 4, 11, C["ochre_l"])
    c.frame(2, 7, 28, 22, C["fog"]); c.vline(16, 7, 28, C["fog"])
    c.hline(30, 0, S - 1, SUMI)


def garbage_net(c: Canvas, p):
    with_ground(c, p, "conc")
    for (x, y, r) in [(8, 20, 6), (18, 18, 6), (14, 24, 5), (24, 24, 4)]:
        c.disc(x, y, r, C["fog"]); c.disc(x - 1, y - 1, r - 2, C["stone"])
    for y in range(6, S):
        for x in range(S):
            if (x + y) % 4 == 0 or (x - y) % 4 == 0:
                c.px(x, y, C["leaf"])
    c.hline(6, 0, S - 1, C["leaf"]); c.hline(5, 0, S - 1, C["leaf_l"])
    c.rect(12, 0, 8, 4, C["ochre"]); c.px(14, 2, SUMI); c.px(17, 2, SUMI)


def backnet(c: Canvas, p):
    soil(c, p, C["soil"], 0.03)
    for y in range(S):
        for x in range(S):
            if (x + y) % 4 == 0 or (x - y) % 4 == 0:
                c.px(x, y, C["conc"])
    for x in (0, 16, 31):
        c.vline(x, 0, S - 1, ML); c.px(x, 0, C["bone"])
    c.hline(0, 0, S - 1, ML); c.hline(31, 0, S - 1, MD)


def footbridge(c: Canvas, p):
    c.texture(0, 0, S, S, C["fog"], 0.05, 6.0, k=1)
    for y in range(S):
        for x in range(S):
            if (x + y) % 6 == 0:
                c.px(x, y, C["stone_l"])
            elif (x + y) % 6 == 3:
                c.px(x, y, C["dusk"])
    c.rect(0, 0, 4, S, C["conc"]); c.rect(28, 0, 4, S, C["conc"])
    c.vline(0, 0, S - 1, C["bone"]); c.vline(31, 0, S - 1, C["dusk"])
    c.noise(C["rust"], 0.03, 4, 0, 24, S, k=2)


FLAT2 = {
    "白線（実線・破線）": lambda c, p: line_paint(c, p, True, 4, 14),
    "白線（土用）": lambda c, p: line_paint(c, p, True, 2, 15, False, C["soil"]),
    "白線（停止線）": lambda c, p: line_paint(c, p, True, 6, 12),
    "駐車場ライン": lambda c, p: line_paint(c, p, False, 2, 0),
    "狭い歩道（縁石）": curb, "側溝": lambda c, p: drain(c, p), "側溝・グレーチング": grating,
    "ガードレール": guardrail, "バリケード": barricade, "フェンス（施錠）": fence_locked,
    "自転車置き場": bike_shed, "掲示板": bulletin, "看板（地図）": map_board, "案内板": info_board,
    "商店の看板（褪せ）": shop_sign, "店舗看板（無地）": plain_sign, "時刻表看板": timetable,
    "蛍光灯": fluorescent, "蛍光灯（バス停）": fluorescent, "非常灯": emergency_light, "交番の赤色灯": police_light,
    "自販機正面": vending, "公衆電話ボックス": phone_booth, "集合ポスト": postboxes, "教室の机・椅子": desk_chair, "黒板": blackboard,
    "百葉箱": weather_box, "朝礼台": platform, "ダッグアウト": dugout, "ベランダ": veranda, "物干し": laundry, "ブランコ・砂場": sandbox_swing,
    "飼育小屋（金網）": hen_house, "ゴミ集積所ネット": garbage_net, "バックネット（金網）": backnet, "縞鋼板の歩道橋": footbridge,
}

TALL2 = {
    "駐車車両（暗）": (parking_car, 1, 2),
}
