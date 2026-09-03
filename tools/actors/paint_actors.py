"""アクターのスプライトシート（32×48、4 方向 × 2 フレーム）を自由な色数で描く。

出力：resources/actors/<kind>.png（64×192。列＝フレーム 0/1、行＝下・上・左・右）。
ActorSpriteGenerator がこの PNG を優先して読み、無ければ従来の生成に戻る。
種別：player（篝悠）、heroine（澪）、stalker（追跡者。顔を描かない）、toki（駄菓子屋の老婆）、shige（朝和の老婆）。
光は左上、輪郭は墨。足元は y=44〜46（Sprite の offset (-16,-44) で原点＝足元）。決定論的。

使い方: python3 tools/actors/paint_actors.py [--preview build/actors_x4.png]
"""
import argparse
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "tools", "tiles"))
from px32 import C, Canvas, mix, rgb, shade  # noqa: E402

W, H = 32, 48
DIRS = ["down", "up", "left", "right"]
OUT_DIR = os.path.join(ROOT, "resources", "actors")

SUMI = C["sumi"]
SKIN = rgb("#d8b89a")
SKIN_D = rgb("#a8846a")
SKIN_OLD = rgb("#c9ad92")


def outline(c: Canvas):
    c.outline(lambda x, y: c.get(x, y) is not None, SUMI)


def shadow(c: Canvas):
    for y in range(43, 47):
        for x in range(6, 26):
            d = ((x - 15.5) / 10.0) ** 2 + ((y - 45) / 2.0) ** 2
            if d <= 1.0:
                c.px(x, y, SUMI, int(120 * (1 - d * 0.6)))


def legs(c: Canvas, frame, color, dark, y0=32, x_l=10, x_r=18, w=4, h=12, facing="down"):
    """脚。frame 1 は片足を前へ（横向きは前後にずらす）"""
    if facing in ("left", "right"):
        back, front = (x_l, x_r) if facing == "right" else (x_r, x_l)
        off = 2 if frame else 0
        c.rect(back, y0, w, h - off, dark)
        c.rect(front, y0, w, h, color)
        if frame:
            c.rect(front + (2 if facing == "right" else -2), y0 + 4, w, h - 4, color)
        c.hline(y0 + h - 1, front, front + w - 1, dark)
    else:
        lo = (0, 0) if not frame else (-1, 1)
        c.rect(x_l, y0, w, h + lo[0], color)
        c.rect(x_r, y0, w, h + lo[1], color)
        c.vline(x_l + w - 1, y0, y0 + h + lo[0] - 1, dark)
        c.vline(x_r + w - 1, y0, y0 + h + lo[1] - 1, dark)
        c.hline(y0 + h + lo[0] - 1, x_l, x_l + w - 1, dark)
        c.hline(y0 + h + lo[1] - 1, x_r, x_r + w - 1, dark)


def head(c: Canvas, facing, skin, hair, hair_d, x0=10, y0=6, w=12, h=12, long_hair=False, bangs=True, eyes=True):
    """頭。向きで髪と目の見え方を変える"""
    c.rect(x0, y0, w, h, skin)
    c.gradient_h(x0, y0, 3, h, shade(skin, 0.12), skin)
    c.vline(x0 + w - 1, y0 + 2, y0 + h - 1, SKIN_D if skin != SKIN_OLD else shade(skin, -0.25))
    # 髪の帽子部
    c.rect(x0 - 1, y0 - 2, w + 2, 5, hair)
    c.hline(y0 - 2, x0, x0 + w - 1, shade(hair, 0.25))
    c.rect(x0 - 1, y0 - 1, 2, 7 if not long_hair else 14, hair)
    c.rect(x0 + w - 1, y0 - 1, 2, 7 if not long_hair else 14, hair)
    if facing == "up":
        c.rect(x0 - 1, y0 - 2, w + 2, h + 1, hair)
        c.hline(y0 - 2, x0, x0 + w - 1, shade(hair, 0.25))
        c.vline(x0 - 1, y0 - 1, y0 + h - 2, shade(hair, 0.12))
        c.vline(x0 + w, y0 - 1, y0 + h - 2, hair_d)
        if long_hair:
            c.rect(x0 - 1, y0 + h - 1, w + 2, 8, hair)
            c.rect(x0 + 1, y0 + h + 3, w - 2, 4, hair_d)
        return
    if facing == "down":
        if bangs:
            for i, x in enumerate(range(x0, x0 + w, 3)):
                c.rect(x, y0 + 3, 2, 2 + (i % 2), hair)
        if eyes:
            c.rect(x0 + 3, y0 + 7, 2, 2, SUMI)
            c.rect(x0 + w - 5, y0 + 7, 2, 2, SUMI)
            c.px(x0 + 3, y0 + 7, mix(SUMI, C["bone"], 0.35))
            c.px(x0 + w - 5, y0 + 7, mix(SUMI, C["bone"], 0.35))
        c.hline(y0 + h - 2, x0 + 4, x0 + w - 5, shade(skin, -0.3))  # 口
        return
    # 横向き：片側が髪
    if facing == "left":
        c.rect(x0 + 5, y0 - 2, w - 4, h - 1, hair)
        c.vline(x0 + w, y0 - 1, y0 + h - 2, hair_d)
        if long_hair:
            c.rect(x0 + 6, y0 + h - 2, 6, 6, hair)
            c.vline(x0 + 11, y0 + h - 2, y0 + h + 3, hair_d)
        if bangs:
            c.rect(x0, y0 + 3, 3, 2, hair)
        if eyes:
            c.rect(x0 + 2, y0 + 7, 2, 2, SUMI)
            c.px(x0 + 2, y0 + 7, mix(SUMI, C["bone"], 0.35))
        c.px(x0, y0 + 9, shade(skin, -0.3))
    else:
        c.rect(x0 - 1, y0 - 2, w - 4, h - 1, hair)
        c.vline(x0 - 1, y0 - 1, y0 + h - 2, shade(hair, 0.12))
        if long_hair:
            c.rect(x0, y0 + h - 2, 6, 6, hair)
            c.vline(x0, y0 + h - 2, y0 + h + 3, shade(hair, 0.1))
        if bangs:
            c.rect(x0 + w - 3, y0 + 3, 3, 2, hair)
        if eyes:
            c.rect(x0 + w - 4, y0 + 7, 2, 2, SUMI)
            c.px(x0 + w - 4, y0 + 7, mix(SUMI, C["bone"], 0.35))
        c.px(x0 + w - 1, y0 + 9, shade(skin, -0.3))


# ─────────────── 各キャラクター ───────────────

def player(c: Canvas, facing, frame):
    """篝悠：暗いコート、肩掛けの鞄。顔は青白い"""
    coat = rgb("#2f3f5f"); coat_d = rgb("#1c2740"); coat_l = rgb("#46587c")
    hair = rgb("#141622"); hair_d = rgb("#0b0d14")
    bag = rgb("#5a3a26"); bag_l = rgb("#7a5236")
    pants = rgb("#232a3f")
    shadow(c)
    legs(c, frame, pants, shade(pants, -0.4), 34, 10, 18, 4, 10, facing)
    # 胴（コート、裾がやや広がる）
    c.poly([(8, 18), (23, 18), (25, 35), (6, 35)], coat)
    c.gradient_h(8, 18, 4, 17, coat_l, coat)
    c.vline(24, 20, 34, coat_d)
    c.hline(34, 7, 24, coat_d)
    # 腕
    if facing == "down":
        c.rect(5, 19, 3, 12, coat); c.vline(5, 19, 30, coat_l); c.rect(5, 31, 3, 2, SKIN_D)
        c.rect(24, 19, 3, 12, coat_d); c.rect(24, 31, 3, 2, SKIN_D)
        c.vline(15, 19, 33, coat_d)                                 # 前立て
        c.rect(12, 18, 8, 2, shade(coat_l, 0.2))                    # 襟
        c.line(9, 18, 21, 30, bag_l); c.line(10, 18, 22, 30, bag)   # 鞄のベルト
    elif facing == "up":
        c.rect(5, 19, 3, 12, coat_d); c.rect(24, 19, 3, 12, coat)
        c.rect(12, 18, 8, 2, coat_d)
        c.rect(9, 22, 11, 9, bag); c.rect(9, 22, 11, 2, bag_l); c.frame(9, 22, 11, 9, shade(bag, -0.4))
    elif facing == "left":
        c.rect(12, 20, 4, 12, coat_d if frame else coat)            # 腕（前）
        c.rect(12, 32, 4, 2, SKIN_D)
        c.rect(19, 21, 6, 10, bag); c.rect(19, 21, 6, 2, bag_l); c.frame(19, 21, 6, 10, shade(bag, -0.4))
        c.line(19, 19, 17, 21, bag_l)
    else:
        c.rect(16, 20, 4, 12, coat_d if frame else coat)
        c.rect(16, 32, 4, 2, SKIN_D)
        c.rect(7, 21, 6, 10, bag); c.rect(7, 21, 6, 2, bag_l); c.frame(7, 21, 6, 10, shade(bag, -0.4))
        c.line(12, 19, 14, 21, bag_l)
    c.rect(13, 17, 6, 3, SKIN_D)                                    # 首
    head(c, facing, SKIN, hair, hair_d, 10, 6, 12, 12)
    outline(c)


def heroine(c: Canvas, facing, frame):
    """澪：枯れ黄土のカーディガン、暗いスカート、赤茶の長い髪、ノート"""
    top = rgb("#b58d5a"); top_d = rgb("#7e6140"); top_l = rgb("#d0ac78")
    skirt = rgb("#2b3550"); skirt_d = rgb("#1a2138")
    hair = rgb("#5a3428"); hair_d = rgb("#3a2019")
    book = rgb("#d9d2c0")
    shadow(c)
    legs(c, frame, SKIN, SKIN_D, 36, 11, 17, 4, 8, facing)
    c.rect(11, 42 if not frame else 41, 4, 3, rgb("#3a2a22")); c.rect(17, 42, 4, 3, rgb("#3a2a22"))   # 靴
    # スカート
    c.poly([(9, 28), (22, 28), (25, 38), (6, 38)], skirt)
    for x in range(8, 24, 3):
        c.vline(x, 30, 37, skirt_d)
    c.hline(37, 7, 24, skirt_d)
    # カーディガン
    c.rect(8, 18, 16, 11, top)
    c.gradient_h(8, 18, 4, 11, top_l, top)
    c.vline(23, 19, 28, top_d)
    if facing == "down":
        c.rect(5, 19, 3, 11, top); c.vline(5, 19, 29, top_l); c.rect(5, 30, 3, 2, SKIN)
        c.rect(24, 19, 3, 11, top_d); c.rect(24, 30, 3, 2, SKIN)
        c.rect(13, 18, 6, 2, C["bone"])                            # 襟元のブラウス
        c.vline(15, 20, 27, top_d)
        c.rect(11, 24, 10, 6, book); c.frame(11, 24, 10, 6, shade(book, -0.4)); c.hline(26, 12, 19, C["fog"])
    elif facing == "up":
        c.rect(5, 19, 3, 11, top_d); c.rect(24, 19, 3, 11, top)
    elif facing == "left":
        c.rect(11, 20, 4, 10, top_d if frame else top); c.rect(11, 30, 4, 2, SKIN)
        c.rect(6, 23, 7, 6, book); c.frame(6, 23, 7, 6, shade(book, -0.4))
    else:
        c.rect(17, 20, 4, 10, top_d if frame else top); c.rect(17, 30, 4, 2, SKIN)
        c.rect(19, 23, 7, 6, book); c.frame(19, 23, 7, 6, shade(book, -0.4))
    c.rect(13, 17, 6, 2, SKIN_D)
    head(c, facing, SKIN, hair, hair_d, 10, 5, 12, 12, long_hair=True)
    outline(c)


def stalker(c: Canvas, facing, frame):
    """追跡者：顔の無い暗い人影。輪郭だけ僅かに明るく、向きは肩の傾きと歩幅で示す。血や傷は描かない"""
    body = rgb("#0b0d14"); edge = rgb("#1f2a44"); edge_l = rgb("#2b3856")
    shadow(c)
    # 脚（長め）
    if facing in ("left", "right"):
        fx = 15 if facing == "right" else 13
        c.rect(fx - 3, 32, 4, 12 - (2 if frame else 0), body)
        c.rect(fx + (3 if frame else 1), 32, 4, 12, body)
    else:
        c.rect(10, 32, 4, 12 + (1 if frame else 0), body)
        c.rect(18, 32, 4, 12 - (1 if frame else 0), body)
    # 胴（肩が広く、頭が低い）
    c.poly([(6, 16), (26, 16), (25, 34), (7, 34)], body)
    tilt = {"down": 0, "up": 0, "left": -1, "right": 1}[facing]
    c.hline(16, 6 + max(0, tilt), 25 + min(0, tilt), edge)
    c.px(6, 16, edge_l if tilt <= 0 else body); c.px(25, 16, edge_l if tilt >= 0 else body)
    if facing == "down":
        c.vline(6, 17, 30, edge); c.vline(25, 17, 30, edge)
        c.vline(4, 20, 33, body); c.vline(27, 20, 33, body)     # 長い腕
    elif facing == "up":
        c.vline(6, 17, 31, edge); c.vline(25, 17, 31, edge)
        c.rect(6, 18, 20, 3, edge)
    elif facing == "left":
        c.vline(6, 17, 33, edge_l); c.vline(25, 20, 30, edge)
        c.rect(3, 20, 3, 14, body)
    else:
        c.vline(25, 17, 33, edge_l); c.vline(6, 20, 30, edge)
        c.rect(26, 20, 3, 14, body)
    # 頭（首が無い）
    c.rect(11, 4, 10, 13, body)
    c.hline(4, 12, 19, edge)
    if facing == "left":
        c.vline(11, 5, 14, edge)
    elif facing == "right":
        c.vline(20, 5, 14, edge)
    elif facing == "up":
        c.rect(12, 5, 8, 9, mix(body, edge, 0.5))
    # 輪郭は本体より僅かに明るい（暗所に溶ける）
    c.outline(lambda x, y: c.get(x, y) is not None, mix(body, edge, 0.45))


def toki(c: Canvas, facing, frame):
    """トキ：小柄、白髪をまとめ、藍の着物に白い前掛け"""
    kimono = rgb("#2b3550"); kimono_d = rgb("#1a2138"); kimono_l = rgb("#3c4a6c")
    apron = rgb("#d9d2c0"); apron_d = rgb("#a9a290")
    hair = rgb("#c8c4bc"); hair_d = rgb("#8f8b84")
    shadow(c)
    sway = 1 if frame else 0
    # 着物（足元まで）
    c.poly([(9, 20), (23, 20), (25, 44), (7, 44)], kimono)
    c.gradient_h(9, 20, 3, 24, kimono_l, kimono)
    c.vline(24, 22, 43, kimono_d)
    c.hline(43, 8, 24, kimono_d)
    c.rect(10, 44, 4, 2, SKIN_D); c.rect(18, 44, 4, 2, SKIN_D)     # 足袋
    if facing != "up":
        c.rect(11, 26, 11, 15, apron)
        c.gradient_v(11, 26, 11, 3, shade(apron, 0.1), apron)
        c.vline(21, 27, 40, apron_d); c.hline(40, 12, 21, apron_d)
        c.rect(12, 24, 9, 2, rgb("#8a4a3a"))                        # 帯
    else:
        c.rect(12, 24, 9, 3, rgb("#8a4a3a")); c.rect(14, 22, 5, 6, rgb("#6e3a2e"))   # 帯結び
    # 袖（手を前で組む）
    if facing == "down":
        c.rect(6, 22, 4, 10, kimono_l); c.rect(22, 22, 4, 10, kimono_d)
        c.rect(12, 30, 8, 3, SKIN_OLD)
    elif facing == "up":
        c.rect(6, 22, 4, 10, kimono_d); c.rect(22, 22, 4, 10, kimono)
    elif facing == "left":
        c.rect(9, 22, 5, 10, kimono_l); c.rect(9, 31, 4, 2, SKIN_OLD)
    else:
        c.rect(18, 22, 5, 10, kimono_d); c.rect(19, 31, 4, 2, SKIN_OLD)
    c.rect(13, 19, 6, 2, shade(SKIN_OLD, -0.2))
    head(c, facing, SKIN_OLD, hair, hair_d, 10 + sway, 8, 12, 11, bangs=False)
    # まとめ髪
    if facing != "down":
        c.disc(16 + sway, 8, 3, hair); c.px(15 + sway, 7, shade(hair, 0.3))
    # しわ
    if facing == "down":
        c.hline(13, 12 + sway, 14 + sway, shade(SKIN_OLD, -0.25)); c.hline(13, 18 + sway, 20 + sway, shade(SKIN_OLD, -0.25))
    outline(c)


def shige(c: Canvas, facing, frame):
    """シゲ：朝和の老婆。濃い野良着（もんぺ）、手拭いを被る。前かがみ。トキと色で見分ける"""
    cloth = rgb("#3a4a3a"); cloth_d = rgb("#243024"); cloth_l = rgb("#526552")
    monpe = rgb("#2a2e3a"); monpe_d = rgb("#1a1d26")
    towel = rgb("#c9c3b0"); towel_d = rgb("#948f80"); towel_pat = rgb("#4a5a78")
    shadow(c)
    sway = 1 if frame else 0
    # もんぺ（太い脚）
    c.rect(9, 32, 6, 12, monpe); c.rect(17, 32, 6, 12, monpe)
    c.vline(14, 32, 43, monpe_d); c.vline(22, 32, 43, monpe_d)
    c.rect(9, 44, 5, 2, rgb("#3a2a22")); c.rect(18, 44, 5, 2, rgb("#3a2a22"))
    # 上着（前かがみで胴が前へ）
    c.poly([(8, 20), (24, 20), (25, 33), (7, 33)], cloth)
    c.gradient_h(8, 20, 4, 13, cloth_l, cloth)
    c.vline(24, 21, 32, cloth_d)
    c.hline(32, 8, 24, cloth_d)
    for y in range(22, 32, 3):                                    # 絣の点
        for x in range(10, 24, 4):
            c.px(x + (y % 2), y, cloth_d)
    if facing == "down":
        c.rect(5, 21, 3, 11, cloth_l); c.rect(24, 21, 3, 11, cloth_d)
        c.rect(5, 31, 3, 2, SKIN_OLD); c.rect(24, 31, 3, 2, SKIN_OLD)
        c.vline(16, 20, 31, cloth_d)
        c.rect(13, 20, 6, 2, towel)                                 # 襟元
        c.rect(6, 33, 4, 4, rgb("#5a3a26"))                         # 手にした鎌の柄（刃は描かない）
    elif facing == "up":
        c.rect(5, 21, 3, 11, cloth_d); c.rect(24, 21, 3, 11, cloth)
        c.rect(12, 21, 8, 6, towel_d)                               # 手拭いの垂れ
    elif facing == "left":
        c.rect(10, 22, 4, 10, cloth_d if frame else cloth); c.rect(10, 32, 4, 2, SKIN_OLD)
    else:
        c.rect(18, 22, 4, 10, cloth_d if frame else cloth); c.rect(18, 32, 4, 2, SKIN_OLD)
    c.rect(13, 19, 6, 2, shade(SKIN_OLD, -0.2))
    # 頭（前かがみで低い）
    head(c, facing, SKIN_OLD, towel, towel_d, 10 + sway, 9, 12, 11, bangs=False)
    # 手拭い（頭を覆う）
    c.rect(9 + sway, 6, 14, 6, towel)
    c.hline(6, 10 + sway, 22 + sway, shade(towel, 0.25))
    c.hline(11, 9 + sway, 22 + sway, towel_d)
    for x in range(10 + sway, 22 + sway, 3):
        c.px(x, 8, towel_pat); c.px(x + 1, 9, towel_pat)
    if facing in ("left", "right"):
        tx = 9 + sway if facing == "left" else 21 + sway
        c.rect(tx, 10, 2, 8, towel); c.vline(tx + (1 if facing == "left" else 0), 10, 17, towel_d)   # 結び目の垂れ
    if facing == "down":
        c.hline(14, 12 + sway, 14 + sway, shade(SKIN_OLD, -0.25)); c.hline(14, 18 + sway, 20 + sway, shade(SKIN_OLD, -0.25))
    outline(c)


KINDS = {"player": player, "heroine": heroine, "stalker": stalker, "toki": toki, "shige": shige}


def paint_sheet(kind: str) -> Image.Image:
    sheet = Image.new("RGBA", (W * 2, H * len(DIRS)), (0, 0, 0, 0))
    for row, facing in enumerate(DIRS):
        for frame in range(2):
            c = Canvas(W, H, seed=row * 2 + frame)
            KINDS[kind](c, facing, frame)
            sheet.alpha_composite(c.to_image(), (frame * W, row * H))
    return sheet


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default=OUT_DIR)
    ap.add_argument("--preview", default="")
    ap.add_argument("--scale", type=int, default=4)
    a = ap.parse_args()
    os.makedirs(a.out_dir, exist_ok=True)
    sheets = {}
    for kind in KINDS:
        img = paint_sheet(kind)
        path = os.path.join(a.out_dir, kind + ".png")
        img.save(path)
        sheets[kind] = img
        print(path, img.size)
    if a.preview:
        pv = Image.new("RGBA", (W * 2 * len(KINDS) + 8 * (len(KINDS) - 1), H * len(DIRS)), (40, 40, 40, 255))
        for i, kind in enumerate(KINDS):
            pv.alpha_composite(sheets[kind], (i * (W * 2 + 8), 0))
        pv.resize((pv.width * a.scale, pv.height * a.scale), Image.NEAREST).save(a.preview)
        print("preview:", a.preview)
    return 0


if __name__ == "__main__":
    sys.exit(main())
