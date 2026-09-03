"""タイトル背景（resources/ui/title_bg.png、384×216）をパレット 16 色で描く。

題材：国道 281 号と高架、夜（docs/ASSETS_NEEDED.md §6f）。文字は入れない。
構図：画面の右下へ抜ける国道、上を横切る高速の高架、左に自販機の灯り、街灯が奥へ並ぶ。
左上〜中央左（題字とメニューが載る）は暗く保つ。決定論的。

使い方: python3 tools/ui/paint_title_bg.py [--out resources/ui/title_bg.png] [--preview build/title_x3.png]
"""
import argparse
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
W, H = 384, 216

PALETTE = [
    (0x0B, 0x0D, 0x14), (0x14, 0x1A, 0x2B), (0x1F, 0x2A, 0x44), (0x2F, 0x3F, 0x5F), (0x4A, 0x5A, 0x78), (0x85, 0x90, 0xA3),
    (0x1B, 0x2A, 0x24), (0x37, 0x53, 0x3F), (0x6B, 0x8A, 0x5E), (0x3A, 0x2A, 0x22), (0x7A, 0x4A, 0x2E), (0xB0, 0x8A, 0x5C),
    (0xD9, 0xD2, 0xC0), (0xF2, 0xE9, 0xA8), (0xD8, 0x4A, 0x3A), (0x5F, 0xD0, 0xC8),
]
SUMI, NIGHT, DEEP, DUSK, FOG, CONC, MOSS, GREEN, GREEN_L, RUST_D, RUST, OCHRE, BONE, GLOW, RED, FLUO = range(16)


class Canvas:
    def __init__(self):
        self.p = [[NIGHT] * W for _ in range(H)]

    def rand(self, x, y, k=0):
        h = (x * 374761393 + y * 668265263 + (k + 1) * 1442695041) & 0x7FFFFFFF
        h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
        return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0

    def px(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.p[int(y)][int(x)] = c

    def get(self, x, y):
        if 0 <= x < W and 0 <= y < H:
            return self.p[int(y)][int(x)]
        return None

    def rect(self, x, y, w, h, c):
        for yy in range(max(0, y), min(H, y + h)):
            for xx in range(max(0, x), min(W, x + w)):
                self.p[yy][xx] = c

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

    def poly(self, pts, c):
        """凸多角形の塗り（走査線）"""
        ys = [p[1] for p in pts]
        for y in range(max(0, int(min(ys))), min(H, int(max(ys)) + 1)):
            xs = []
            n = len(pts)
            for i in range(n):
                (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % n]
                if (y0 <= y < y1) or (y1 <= y < y0):
                    xs.append(x0 + (y - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                self.hline(y, int(math.ceil(xs[i])), int(math.floor(xs[i + 1])), c)

    def disc(self, cx, cy, r, c):
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    self.px(x, y, c)

    def glow(self, cx, cy, r, colors=None, k=0):
        """光のにじみ：周囲の画素を一段明るくする（中心ほど確率が高い）。芯だけ街灯の色。茶色の円にしない"""
        lighter = {SUMI: NIGHT, NIGHT: DEEP, DEEP: DUSK, DUSK: FOG, FOG: CONC, MOSS: GREEN, GREEN: GREEN_L, RUST_D: RUST, RUST: OCHRE}
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                d = math.hypot(x - cx, (y - cy) * 1.5) / r
                if d >= 1.0:
                    continue
                v = (1.0 - d) ** 1.6
                cur = self.get(x, y)
                if cur is None:
                    continue
                if v > 0.72 and self.rand(x, y, k) < (v - 0.72) / 0.28 * 0.9:
                    self.px(x, y, OCHRE if cur in (NIGHT, DEEP, DUSK, FOG, SUMI) else cur)
                elif cur in lighter and self.rand(x, y, k + 1) < v * 0.75:
                    self.px(x, y, lighter[cur])

    def to_image(self):
        img = Image.new("RGB", (W, H))
        px = img.load()
        for y in range(H):
            for x in range(W):
                px[x, y] = PALETTE[self.p[y][x]]
        return img


def paint() -> Canvas:
    c = Canvas()
    # ── 空：上が深く、地平線へ向けてわずかに明るく。星は少なく ──
    c.rect(0, 0, W, H, NIGHT)
    for y in range(0, 110):
        for x in range(W):
            if y > 70 and c.rand(x, y, 1) < (y - 70) / 60.0 * 0.5:
                c.px(x, y, DEEP)
    for i in range(70):
        x = int(c.rand(i, 3, 2) * W)
        y = int(c.rand(i, 5, 2) * 60)
        if x > 170 or y < 20:
            c.px(x, y, FOG if c.rand(i, 7, 2) < 0.7 else CONC)
    # 月：右上、雲に半分隠れる
    c.disc(318, 30, 9, BONE)
    c.disc(315, 29, 7, BONE)
    c.disc(320, 27, 2, CONC)
    for y in range(18, 44):
        for x in range(300, 340):
            if (x - 318) ** 2 + (y - 30) ** 2 <= 81 and c.rand(x, y, 9) < 0.15:
                c.px(x, y, CONC)
    # 雲（低い、細長い）
    for (cx, cy, w, h) in [(330, 40, 90, 6), (250, 52, 60, 4), (120, 60, 70, 4)]:
        for y in range(cy - h, cy + h):
            for x in range(cx - w, cx + w):
                d = ((x - cx) / w) ** 2 + ((y - cy) / h) ** 2
                if d <= 1.0 and c.rand(x, y, 4) < 0.85 - d * 0.6:
                    c.px(x, y, DEEP if y > cy else DUSK)

    # ── 遠景：山と町の稜線（左が高い） ──
    for x in range(W):
        ridge = 96 + int(10 * math.sin(x / 41.0) + 6 * math.sin(x / 17.0 + 1.0) + x * 0.06)
        for y in range(ridge, 125):
            c.px(x, y, NIGHT if y > ridge + 2 else DEEP)
        if c.rand(x, 0, 5) < 0.1 and x > 40:
            c.px(x, ridge + 6 + int(c.rand(x, 1, 5) * 14), GLOW if c.rand(x, 2, 5) < 0.6 else FLUO)  # 町の窓明かり
    # 防音壁（遠い高速の壁）：地平線に沿う灰藍の帯
    c.rect(0, 118, W, 6, DUSK)
    c.hline(118, 0, W - 1, FOG)
    for x in range(0, W, 24):
        c.vline(x, 118, 123, DEEP)

    # ── 国道：右下へ向かって消失点（x=250, y=124）へ収束する台形 ──
    vx, vy = 250, 124
    left_bottom, right_bottom = -40, 330
    road = [(vx - 8, vy), (vx + 8, vy), (right_bottom, H), (left_bottom, H)]
    c.poly(road, DUSK)
    # アスファルトの質感
    for y in range(vy, H):
        for x in range(W):
            if c.get(x, y) == DUSK and c.rand(x, y, 6) < 0.06:
                c.px(x, y, FOG if c.rand(x, y, 7) < 0.5 else DEEP)
    # 中央線（破線）と外側線
    def road_x(t, y):
        # t: 0=左端 1=右端 の位置を y で補間
        f = (y - vy) / (H - vy)
        lx = (vx - 8) + (left_bottom - (vx - 8)) * f
        rx = (vx + 8) + (right_bottom - (vx + 8)) * f
        return lx + (rx - lx) * t
    for y in range(vy + 4, H):
        f = (y - vy) / (H - vy)
        if int(y / max(1.0, 3 + f * 9)) % 2 == 0:
            xm = road_x(0.5, y)
            c.hline(y, int(xm), int(xm + f * 3), BONE)
        c.px(int(road_x(0.04, y)), y, CONC)
        c.px(int(road_x(0.96, y)), y, CONC)
    # 歩道（左）と縁石
    for y in range(vy + 6, H):
        lx = int(road_x(0.0, y))
        c.hline(y, max(0, lx - 40), lx - 1, FOG if y % 3 else DUSK)
        c.px(lx - 1, y, CONC)
    # ガードレール（右）
    for y in range(vy + 8, H, 1):
        rx = int(road_x(1.0, y))
        f = (y - vy) / (H - vy)
        c.px(rx + 2, y - int(2 + f * 6), CONC)
        c.px(rx + 3, y - int(2 + f * 6), FOG)
        if y % max(2, int(4 + f * 10)) == 0:
            c.vline(rx + 2, y - int(2 + f * 6), y, FOG)

    # ── 高架：画面上部を横切る。橋脚が道路の脇に ──
    c.rect(0, 62, W, 3, FOG)     # 床版の上縁
    c.rect(0, 65, W, 14, DUSK)   # 床版
    c.rect(0, 79, W, 3, DEEP)    # 影
    c.hline(62, 0, W - 1, CONC)
    for x in range(0, W, 48):
        c.rect(x + 20, 65, 2, 14, DEEP)  # 桁の継ぎ目
    for x in range(0, W, 6):     # 防音壁のパネル
        c.rect(x, 50, 5, 12, DUSK)
        c.vline(x + 5, 50, 61, DEEP)
    c.hline(50, 0, W - 1, FOG)
    # 橋脚
    for (px0, w) in [(60, 22), (196, 20), (300, 22)]:
        c.rect(px0, 82, w, 60, FOG)
        c.vline(px0, 82, 141, CONC)
        c.vline(px0 + w - 1, 82, 141, DEEP)
        for y in range(82, 142):
            if c.rand(px0, y, 8) < 0.5:
                c.px(px0 + 3 + int(c.rand(y, px0, 8) * (w - 6)), y, DUSK)
        c.rect(px0 - 2, 138, w + 4, 4, FOG)
    # 高架の照明（オレンジのナトリウム灯）を等間隔に
    for x in range(30, W, 96):
        c.rect(x, 44, 2, 6, FOG)
        c.rect(x - 2, 42, 6, 3, GLOW)
        c.glow(x + 1, 46, 11, k=3)

    # ── 街灯：手前から奥へ、道路の左側 ──
    for i, y in enumerate([206, 182, 162, 148, 138]):
        f = (y - vy) / (H - vy)
        x = int(road_x(0.0, y)) - 6
        h = int(12 + f * 42)
        top = y - h
        c.glow(x, top + 2, int(8 + f * 22), k=10 + i)
        c.vline(x, top, y, FOG)
        c.vline(x + 1, top, y, DUSK)
        c.rect(x - 2, top - 1, 6, 2, GLOW)
        c.px(x - 3, top, OCHRE)
        c.px(x + 4, top, OCHRE)
        c.rect(x - 1, y, 4, 2, SUMI)

    # ── 自販機：左下、歩道の上。唯一の「安全な明かり」 ──
    vxm, vym = 46, 150
    c.glow(vxm + 12, vym + 22, 34, k=20)
    c.rect(vxm, vym, 24, 44, FOG)
    c.vline(vxm, vym, vym + 43, CONC)
    c.vline(vxm + 23, vym, vym + 43, DEEP)
    c.rect(vxm + 3, vym + 3, 13, 18, GLOW)
    c.rect(vxm + 4, vym + 4, 11, 16, BONE)
    for row in range(3):
        for col in range(4):
            c.rect(vxm + 5 + col * 3, vym + 5 + row * 5, 2, 3, [RED, FLUO, OCHRE, RED][(row + col) % 4])
    c.rect(vxm + 17, vym + 3, 4, 34, RED)
    c.vline(vxm + 17, vym + 3, vym + 36, GLOW)
    c.rect(vxm + 3, vym + 24, 13, 10, DUSK)
    c.rect(vxm + 4, vym + 26, 11, 6, SUMI)
    c.rect(vxm + 3, vym + 38, 18, 4, SUMI)
    c.rect(vxm - 2, vym + 44, 28, 2, SUMI)
    # 自販機の光が歩道と道路に落ちる
    for y in range(vym + 30, H):
        for x in range(vxm - 20, vxm + 60):
            d = math.hypot((x - vxm - 12) / 1.6, y - vym - 40) / 34.0
            if d < 1.0 and c.get(x, y) in (FOG, DUSK, DEEP) and c.rand(x, y, 21) < (1.0 - d) * 0.9:
                c.px(x, y, OCHRE if d < 0.45 else (FOG if c.get(x, y) == DUSK else CONC))

    # ── 手前の人影は置かない。代わりに道路に長い影を一本 ──
    for y in range(170, H):
        x0 = int(road_x(0.25, y))
        c.hline(y, x0, x0 + int(2 + (y - 170) * 0.15), DEEP)

    # ── 左上をさらに落とす（題字の可読性） ──
    for y in range(0, 125):
        for x in range(0, 200):
            f = max(0.0, 1.0 - (x / 200.0)) * max(0.0, 1.0 - y / 125.0)
            if c.get(x, y) in (DEEP, DUSK) and c.rand(x, y, 30) < f * 0.9:
                c.px(x, y, NIGHT if c.get(x, y) == DEEP else DEEP)
    return c


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "resources", "ui", "title_bg.png"))
    ap.add_argument("--preview", default="")
    a = ap.parse_args()
    img = paint().to_image()
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    img.save(a.out)
    print(a.out, img.size)
    if a.preview:
        img.resize((W * 3, H * 3), Image.NEAREST).save(a.preview)
    return 0


if __name__ == "__main__":
    sys.exit(main())
