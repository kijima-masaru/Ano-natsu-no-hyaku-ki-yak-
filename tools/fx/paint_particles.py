"""粒子のテクスチャ（葉・埃・蛍）を描く。ScreenFx の CPUParticles2D が使う。決定的。

python3 tools/fx/paint_particles.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "tools", "tiles"))
from px32 import C, Canvas, mix, shade  # noqa: E402

OUT = os.path.join(ROOT, "resources", "fx")


def leaf():
    c = Canvas(8, 8)
    body = C["leaf_l"]
    c.poly([(1, 5), (3, 1), (6, 1), (6, 4), (3, 7)], body)
    c.px(2, 4, shade(body, -0.35))
    c.px(5, 2, shade(body, 0.35))
    c.line(2, 5, 5, 2, shade(body, -0.25))
    c.px(1, 6, C["wood_d"])
    return c


def leaf_dry():
    c = Canvas(8, 8)
    body = C["ochre"]
    c.poly([(1, 5), (3, 1), (6, 1), (6, 4), (3, 7)], body)
    c.px(2, 4, shade(body, -0.35))
    c.px(5, 2, shade(body, 0.3))
    c.line(2, 5, 5, 2, C["rust_d"])
    return c


def dust():
    c = Canvas(4, 4)
    c.px(1, 1, C["bone"], 200)
    c.px(2, 1, C["bone"], 120)
    c.px(1, 2, C["bone"], 120)
    c.px(2, 2, C["bone"], 60)
    return c


def firefly():
    c = Canvas(8, 8)
    for y in range(8):
        for x in range(8):
            d = ((x - 3.5) ** 2 + (y - 3.5) ** 2) ** 0.5
            if d < 3.6:
                a = int(255 * max(0.0, 1.0 - d / 3.6) ** 1.6)
                c.px(x, y, mix(C["glow"], C["fluo"], 0.15), a)
    c.px(3, 3, C["bone"]); c.px(4, 3, C["bone"]); c.px(3, 4, C["bone"]); c.px(4, 4, C["bone"])
    return c


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    for name, fn in (("leaf", leaf), ("leaf_dry", leaf_dry), ("dust", dust), ("firefly", firefly)):
        path = os.path.join(OUT, name + ".png")
        fn().to_image().save(path)
        print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
