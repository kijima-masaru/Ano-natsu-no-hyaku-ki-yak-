"""タイトル背景（resources/ui/title_bg.png、640×360）を自由な色数で描く。

題材：国道 281 号と高架、夜（docs/ASSETS_NEEDED.md §6f）。文字は入れない。
構図：画面の右下へ抜ける国道、上を横切る高速の高架、右手前に自販機の灯り、街灯が奥へ並ぶ。
左上〜中央左（題字とメニューが載る。x<420）には橋脚も自販機も置かず暗く保つ。
色は tools/tiles/px32.py の色域（夜の町）。光のにじみは実行時の ScreenFx が足すので、絵の中では控えめ。決定論的。

使い方: python3 tools/ui/paint_title_bg.py [--out resources/ui/title_bg.png] [--preview build/title_x2.png]
"""
import argparse
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "tools", "tiles"))
from px32 import C, Canvas, mix, rgb, shade  # noqa: E402

W, H = 640, 360
SUMI, NIGHT, DEEP, DUSK, FOG, CONC = C["sumi"], C["night"], C["deep"], C["dusk"], C["fog"], C["conc"]
BONE, GLOW, RED, FLUO, OCHRE = C["bone"], C["glow"], C["red"], C["fluo"], C["ochre"]
SKY_TOP = rgb("#0a0c16")
SKY_LOW = rgb("#1b2540")
SODIUM = rgb("#e9b86a")


def glow(c: Canvas, cx, cy, r, col, strength=0.5, squash=1.5, k=0):
    """光のにじみ。中心ほど強く色を混ぜる。少しだけ粒を散らして均一にしない"""
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            d = math.hypot(x - cx, (y - cy) * squash) / r
            if d >= 1.0:
                continue
            v = (1.0 - d) ** 1.7 * strength
            v *= 0.85 + 0.3 * c.rand(x, y, k)
            c.blend(x, y, col, min(1.0, v))


def paint() -> Canvas:
    c = Canvas(W, H)
    c.fill(NIGHT)
    # ── 空 ──
    c.gradient_v(0, 0, W, 190, SKY_TOP, SKY_LOW)
    for y in range(0, 190):
        for x in range(W):
            if c.rand(x, y, 1) < 0.02:
                c.blend(x, y, DEEP, 0.4)
    for i in range(110):
        x = int(c.rand(i, 3, 2) * W)
        y = int(c.rand(i, 5, 2) * 95)
        if x > 300 or y < 30:
            c.px(x, y, mix(FOG, BONE, c.rand(i, 7, 2) * 0.6))
            if c.rand(i, 8, 2) < 0.25:
                c.px(x + 1, y, FOG)
    # 月：右上、薄い雲がかかる
    mx, my = 530, 50
    glow(c, mx, my, 60, mix(FOG, BONE, 0.3), 0.35, 1.0, 9)
    c.disc(mx, my, 15, mix(BONE, GLOW, 0.3))
    c.disc(mx - 2, my - 2, 12, mix(BONE, GLOW, 0.15))
    for y in range(my - 16, my + 17):
        for x in range(mx - 16, mx + 17):
            if (x - mx) ** 2 + (y - my) ** 2 <= 225 and c.rand(x, y, 9) < 0.12:
                c.blend(x, y, CONC, 0.5)
    # 雲（細長い、月の前を横切る）
    for (cx, cy, w, h, k) in [(540, 62, 150, 9, 4), (420, 86, 110, 6, 5), (200, 100, 120, 6, 6), (60, 70, 90, 5, 7)]:
        for y in range(cy - h, cy + h + 1):
            for x in range(cx - w, cx + w + 1):
                d = ((x - cx) / w) ** 2 + ((y - cy) / h) ** 2
                n = c.noise2(x, y, 14.0, k)
                if d <= 1.0 and n > 0.35 + d * 0.4:
                    c.blend(x, y, DUSK if y > cy else mix(DUSK, FOG, 0.4), 0.7)

    # ── 遠景：山と町の稜線（左が高い） ──
    for x in range(W):
        ridge = 160 + int(16 * math.sin(x / 68.0) + 9 * math.sin(x / 29.0 + 1.0) + x * 0.06)
        for y in range(ridge, 208):
            t = (y - ridge) / 48.0
            c.px(x, y, mix(DEEP, NIGHT, min(1.0, 0.3 + t)))
        c.px(x, ridge, mix(DEEP, DUSK, 0.5))
        # 町の窓明かり（右寄りに多い）
        if x > 120 and c.rand(x, 0, 5) < 0.07 * (0.4 + x / W):
            wy = ridge + 8 + int(c.rand(x, 1, 5) * 26)
            col = GLOW if c.rand(x, 2, 5) < 0.65 else FLUO
            c.px(x, wy, col)
            c.px(x + 1, wy, mix(col, DEEP, 0.5))
    # 遠い防音壁：地平線に沿う灰藍の帯
    c.gradient_v(0, 196, W, 10, DUSK, DEEP)
    c.hline(196, 0, W - 1, FOG)
    for x in range(0, W, 40):
        c.vline(x, 196, 205, DEEP)

    # ── 地面：道路の外は暗い草地・法面 ──
    for y in range(206, H):
        for x in range(W):
            n = c.noise2(x, y, 7.0, 40)
            col = mix(C["grass_dd"], C["grass_d"], n * 0.5)
            col = mix(col, NIGHT, 0.55)
            if c.rand(x, y, 41) < 0.05:
                col = shade(col, 0.12)
            c.px(x, y, col)

    # ── 国道：右下へ向かって消失点へ収束する台形 ──
    vx, vy = 416, 206
    left_bottom, right_bottom = -70, 550

    def road_x(t, y):
        f = (y - vy) / (H - vy)
        lx = (vx - 12) + (left_bottom - (vx - 12)) * f
        rx = (vx + 12) + (right_bottom - (vx + 12)) * f
        return lx + (rx - lx) * t

    c.poly([(vx - 12, vy), (vx + 12, vy), (right_bottom, H), (left_bottom, H)], DUSK)
    for y in range(vy, H):
        f = (y - vy) / (H - vy)
        for x in range(int(road_x(0.0, y)) - 1, int(road_x(1.0, y)) + 2):
            if c.get(x, y) == DUSK:
                n = c.noise2(x, y, 9.0, 6)
                col = mix(C["asphalt_d"], C["asphalt_l"], n * 0.7)
                col = mix(col, DEEP, 0.35 * (1 - f))     # 奥は暗い
                if c.rand(x, y, 7) < 0.05:
                    col = shade(col, 0.18)
                c.px(x, y, col)
    # 中央線（破線）と外側線
    for y in range(vy + 6, H):
        f = (y - vy) / (H - vy)
        period = 4 + f * 18
        if int(y / period) % 2 == 0:
            xm = road_x(0.5, y)
            c.hline(y, int(xm), int(xm + 1 + f * 4), mix(BONE, DUSK, 0.25 + 0.4 * (1 - f)))
        c.px(int(road_x(0.03, y)), y, mix(CONC, DUSK, 0.4))
        c.px(int(road_x(0.97, y)), y, mix(CONC, DUSK, 0.4))
    # 歩道（左）と縁石
    for y in range(vy + 8, H):
        lx = int(road_x(0.0, y))
        f = (y - vy) / (H - vy)
        for x in range(max(0, lx - int(30 + f * 60)), lx):
            n = c.noise2(x, y, 6.0, 8)
            c.px(x, y, mix(mix(FOG, DUSK, 0.5), CONC, n * 0.4))
        c.px(lx - 1, y, CONC)
        c.px(lx - 2, y, mix(CONC, FOG, 0.5))
        if int(y / (3 + f * 10)) % 2 == 0:
            c.px(lx - int(6 + f * 24), y, mix(FOG, CONC, 0.3))   # 歩道の目地
    # ガードレール（右）
    for y in range(vy + 10, H):
        rx = int(road_x(1.0, y))
        f = (y - vy) / (H - vy)
        top = y - int(3 + f * 10)
        c.px(rx + 3, top, CONC); c.px(rx + 4, top, mix(CONC, BONE, 0.3)); c.px(rx + 3, top + 1, FOG)
        if y % max(3, int(6 + f * 16)) == 0:
            c.vline(rx + 3, top, y, FOG)

    # ── 高架：画面上部を横切る。橋脚は右側の道路脇 ──
    c.gradient_v(0, 82, W, 22, mix(FOG, CONC, 0.3), DUSK)   # 床版
    c.hline(82, 0, W - 1, mix(CONC, BONE, 0.2))
    c.rect(0, 104, W, 5, DEEP)                                # 影
    for x in range(0, W, 80):
        c.rect(x + 32, 84, 3, 22, DEEP)                       # 桁の継ぎ目
    for x in range(0, W, 10):                                 # 防音壁のパネル
        c.rect(x, 62, 9, 20, mix(DUSK, FOG, 0.35))
        c.vline(x + 9, 62, 81, DEEP)
        c.hline(62, x, x + 8, FOG)
    c.hline(61, 0, W - 1, mix(FOG, CONC, 0.5))
    for (px0, w) in [(436, 34), (576, 36)]:                   # 橋脚
        c.gradient_h(px0, 108, w, 100, mix(FOG, CONC, 0.4), DEEP)
        c.vline(px0, 108, 207, CONC)
        c.vline(px0 + w - 1, 108, 207, NIGHT)
        for y in range(108, 208):
            if c.rand(px0, y, 8) < 0.6:
                c.px(px0 + 4 + int(c.rand(y, px0, 8) * (w - 8)), y, DUSK)
        c.rect(px0 - 3, 200, w + 6, 8, mix(FOG, CONC, 0.3))
        c.hline(200, px0 - 3, px0 + w + 2, CONC)
    # 高架の照明（ナトリウム灯）
    for x in range(50, W, 160):
        c.rect(x, 52, 3, 10, FOG)
        c.rect(x - 4, 49, 11, 4, SODIUM)
        c.hline(48, x - 3, x + 6, mix(SODIUM, BONE, 0.4))
        glow(c, x + 1, 56, 26, SODIUM, 0.45, 1.3, 3)

    # ── 街灯：手前から奥へ、道路の左側 ──
    for i, y in enumerate([344, 302, 270, 246, 230]):
        f = (y - vy) / (H - vy)
        x = int(road_x(0.0, y)) - 10
        h = int(20 + f * 72)
        top = y - h
        glow(c, x + 2, top + 4, int(14 + f * 40), GLOW, 0.42, 1.4, 10 + i)
        c.vline(x, top, y, mix(CONC, FOG, 0.3))
        c.vline(x + 1, top, y, DUSK)
        c.rect(x - 3, top - 2, 9, 3, GLOW)
        c.hline(top - 3, x - 2, x + 4, mix(GLOW, BONE, 0.5))
        c.px(x - 4, top - 1, OCHRE); c.px(x + 6, top - 1, OCHRE)
        c.rect(x - 2, y, 6, 3, SUMI)
        # 街灯の光が歩道に落ちる
        for yy in range(y - 4, y + 10):
            for xx in range(x - 16, x + 18):
                d = math.hypot((xx - x) / 1.8, yy - y - 2) / 12.0
                if d < 1.0 and 0 <= yy < H:
                    c.blend(xx, yy, OCHRE, (1 - d) * 0.35)

    # ── 自販機：右手前、歩道の上。唯一の「安全な明かり」 ──
    vxm, vym = 492, 214
    glow(c, vxm + 20, vym + 40, 64, mix(GLOW, BONE, 0.3), 0.4, 1.4, 20)
    c.gradient_h(vxm, vym, 40, 74, mix(CONC, BONE, 0.2), FOG)
    c.vline(vxm, vym, vym + 73, mix(CONC, BONE, 0.3))
    c.vline(vxm + 39, vym, vym + 73, DEEP)
    c.rect(vxm + 4, vym + 5, 22, 30, GLOW)
    c.rect(vxm + 6, vym + 7, 18, 26, mix(BONE, GLOW, 0.3))
    for row in range(4):
        for col in range(4):
            colr = [RED, FLUO, OCHRE, C["water_ll"], C["leaf_l"], RED][(row * 4 + col) % 6]
            c.rect(vxm + 7 + col * 4, vym + 8 + row * 6, 3, 4, colr)
            c.px(vxm + 7 + col * 4, vym + 8 + row * 6, shade(colr, 0.4))
            c.hline(vym + 12 + row * 6, vxm + 7 + col * 4, vxm + 9 + col * 4, mix(BONE, DUSK, 0.5))
    c.rect(vxm + 28, vym + 5, 8, 54, RED)
    c.gradient_h(vxm + 28, vym + 5, 8, 54, shade(RED, 0.25), shade(RED, -0.3))
    for y in range(vym + 10, vym + 30, 6):
        c.rect(vxm + 31, y, 3, 3, BONE)
    c.rect(vxm + 30, vym + 40, 5, 7, NIGHT); c.px(vxm + 32, vym + 42, FLUO)
    c.rect(vxm + 4, vym + 38, 22, 3, DUSK)
    c.rect(vxm + 4, vym + 41, 22, 12, SUMI)
    c.hline(vym + 42, vxm + 5, vxm + 24, NIGHT)
    c.rect(vxm + 3, vym + 62, 34, 6, DUSK); c.hline(vym + 68, vxm + 3, vxm + 36, SUMI)
    c.rect(vxm - 3, vym + 74, 46, 3, SUMI)
    # 自販機の光が歩道と道路に落ちる
    for y in range(vym + 30, H):
        for x in range(vxm - 40, vxm + 110):
            d = math.hypot((x - vxm - 20) / 1.7, y - vym - 70) / 60.0
            fade_in = min(1.0, max(0.0, (y - vym - 30) / 40.0))      # 自販機の足元から徐々に
            if d < 1.0 and 0 <= x < W and not (vxm <= x < vxm + 40 and y < vym + 74):
                c.blend(x, y, mix(GLOW, OCHRE, 0.4), (1 - d) ** 1.4 * 0.45 * fade_in)

    # ── 手前の人影は置かない。道路に長い影を一本 ──
    for y in range(282, H):
        x0 = int(road_x(0.28, y))
        for x in range(x0, x0 + int(3 + (y - 282) * 0.2)):
            c.blend(x, y, DEEP, 0.55)

    # ── 霧：地平線近くを薄く白ませる ──
    for y in range(150, 240):
        for x in range(W):
            n = c.noise2(x, y, 40.0, 31)
            t = (1 - abs(y - 200) / 50.0) * 0.28 * (0.5 + n)
            if t > 0:
                c.blend(x, y, FOG, t)

    # ── 左上をさらに落とす（題字の可読性） ──
    for y in range(0, 230):
        for x in range(0, 420):
            f = max(0.0, 1.0 - x / 420.0) * max(0.0, 1.0 - y / 230.0)
            c.blend(x, y, SUMI, f * 0.7)
    # 周辺減光は実行時（ScreenFx）が足すので、ここでは軽く
    for y in range(H):
        for x in range(W):
            v = ((x - W / 2) / (W / 2)) ** 2 + ((y - H / 2) / (H / 2)) ** 2
            if v > 0.5:
                c.blend(x, y, SUMI, (v - 0.5) * 0.35)
    return c


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "resources", "ui", "title_bg.png"))
    ap.add_argument("--preview", default="")
    a = ap.parse_args()
    img = paint().to_image().convert("RGB")
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    img.save(a.out)
    print(a.out, img.size)
    if a.preview:
        img.resize((W * 2, H * 2), Image.NEAREST).save(a.preview)
    return 0


if __name__ == "__main__":
    sys.exit(main())
