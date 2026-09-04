"""アクターのスプライトシート（枠 32×48、4 方向 × 2 フレーム）を自由な色数で描く。

縮尺：1 マス（32 px）≈ 1.7 m ＝ 人の身長。人物は枠の下 32 px に収め（頭頂 y≈15、足元 y=46）、幅は 14 px ほど。
追跡者だけ一回り大きい（36 px）。木・電柱・建物との比率が現実に近くなる。

出力：resources/actors/<kind>.png（64×192。列＝フレーム 0/1、行＝下・上・左・右）。
ActorSpriteGenerator がこの PNG を優先して読み、無ければ従来の生成に戻る。
種別：player（篝悠）、heroine（澪）、stalker（追跡者。顔を描かない）、toki（駄菓子屋の老婆）、shige（朝和の老婆）。
光は左上、輪郭は墨。Sprite の offset (-16,-44) で原点＝足元。決定論的。

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
FOOT = 46            # 足元の y
CX = 16              # 体の中心 x

SUMI = C["sumi"]
SKIN = rgb("#d8b89a")
SKIN_D = rgb("#a8846a")
SKIN_OLD = rgb("#c9ad92")


def outline(c: Canvas):
    c.outline(lambda x, y: c.get(x, y) is not None, SUMI)


def shadow(c: Canvas, rx=7):
    for y in range(FOOT - 2, FOOT + 2):
        for x in range(CX - rx - 1, CX + rx + 1):
            d = ((x + 0.5 - CX) / rx) ** 2 + ((y + 0.5 - FOOT) / 1.6) ** 2
            if d <= 1.0:
                c.px(x, y, SUMI, int(110 * (1 - d * 0.6)))


def side(facing):
    return facing in ("left", "right")


def legs(c: Canvas, frame, color, dark, y0, h, facing, gap=1, w=3, shoe=None):
    """脚。frame 1 は片足を前へ。横向きは前後にずらす"""
    xl, xr = CX - gap - w, CX + gap
    if side(facing):
        back, front = (xl, xr) if facing == "right" else (xr, xl)
        c.rect(back, y0, w, h - (1 if frame else 0), dark)
        fx = front + ((1 if facing == "right" else -1) if frame else 0)
        c.rect(fx, y0, w, h, color)
        c.hline(y0 + h - 1, fx, fx + w - 1, dark)
        if shoe is not None:
            c.rect(fx - (0 if facing == "right" else 1), y0 + h - 2, w + 1, 2, shoe)
            c.rect(back, y0 + h - 3 + (0 if frame else 1), w, 2, shoe)
    else:
        dl, dr = (0, 0) if not frame else (-1, 1)
        c.rect(xl, y0, w, h + dl, color)
        c.rect(xr, y0, w, h + dr, color)
        c.vline(xl + w - 1, y0, y0 + h + dl - 1, dark)
        c.vline(xr + w - 1, y0, y0 + h + dr - 1, dark)
        if shoe is not None:
            c.rect(xl, y0 + h + dl - 2, w, 2, shoe)
            c.rect(xr, y0 + h + dr - 2, w, 2, shoe)


def head(c: Canvas, facing, skin, hair, hair_d, y0, w=8, h=8, long_hair=False, bangs=True, eyes=True, cap=None):
    """頭。y0 は頭頂（髪込み）。w×h の顔に髪をかぶせ、向きで髪・目の見え方を変える"""
    x0 = CX - w // 2
    c.rect(x0, y0 + 1, w, h, skin)
    c.gradient_h(x0, y0 + 1, 2, h, shade(skin, 0.12), skin)
    c.vline(x0 + w - 1, y0 + 2, y0 + h, shade(skin, -0.25))
    cap_col = hair if cap is None else cap
    c.rect(x0 - 1, y0, w + 2, 3, cap_col)               # 髪の帽子部
    c.hline(y0, x0, x0 + w - 1, shade(cap_col, 0.25))
    tail = 5 if not long_hair else h + 3
    c.rect(x0 - 1, y0 + 1, 1, tail, hair)
    c.rect(x0 + w, y0 + 1, 1, tail, hair)
    if facing == "up":
        c.rect(x0 - 1, y0, w + 2, h + 1, hair)
        c.hline(y0, x0, x0 + w - 1, shade(hair, 0.25))
        c.vline(x0 - 1, y0 + 1, y0 + h - 1, shade(hair, 0.12))
        c.vline(x0 + w, y0 + 1, y0 + h - 1, hair_d)
        if long_hair:
            c.rect(x0 - 1, y0 + h, w + 2, 5, hair)
            c.rect(x0 + 1, y0 + h + 3, w - 2, 2, hair_d)
        if cap is not None:
            c.rect(x0 - 1, y0, w + 2, 3, cap_col)
        return
    if facing == "down":
        if bangs:
            for i, x in enumerate(range(x0, x0 + w, 2)):
                c.rect(x, y0 + 3, 1, 1 + (i % 2), hair)
        if eyes:
            c.px(x0 + 2, y0 + 5, SUMI)
            c.px(x0 + w - 3, y0 + 5, SUMI)
        c.hline(y0 + h - 1, x0 + 3, x0 + w - 4, shade(skin, -0.3))   # 口
        return
    # 横向き：後ろ側が髪、前側に目
    if facing == "left":
        c.rect(x0 + 3, y0, w - 2, h - 1, hair)
        c.vline(x0 + w, y0 + 1, y0 + h - 1, hair_d)
        if long_hair:
            c.rect(x0 + 4, y0 + h - 1, w - 3, 4, hair)
        if bangs:
            c.rect(x0, y0 + 3, 2, 1, hair)
        if eyes:
            c.px(x0 + 1, y0 + 5, SUMI)
        c.px(x0 - 1, y0 + 6, shade(skin, -0.2))                      # 鼻
    else:
        c.rect(x0 - 1, y0, w - 2, h - 1, hair)
        c.vline(x0 - 1, y0 + 1, y0 + h - 1, shade(hair, 0.12))
        if long_hair:
            c.rect(x0 - 1, y0 + h - 1, w - 3, 4, hair)
        if bangs:
            c.rect(x0 + w - 2, y0 + 3, 2, 1, hair)
        if eyes:
            c.px(x0 + w - 2, y0 + 5, SUMI)
        c.px(x0 + w, y0 + 6, shade(skin, -0.2))
    if cap is not None:
        c.rect(x0 - 1, y0, w + 2, 3, cap_col)
        c.hline(y0, x0, x0 + w - 1, shade(cap_col, 0.25))


# ─────────────── 各キャラクター ───────────────

def player(c: Canvas, facing, frame):
    """篝悠：暗いコート、肩掛けの鞄。顔は青白い。身長 ≈ 1 マス"""
    coat = rgb("#2f3f5f"); coat_d = rgb("#1c2740"); coat_l = rgb("#46587c")
    hair = rgb("#141622"); hair_d = rgb("#0b0d14")
    bag = rgb("#5a3a26"); bag_l = rgb("#7a5236")
    pants = rgb("#232a3f")
    shadow(c)
    legs(c, frame, pants, shade(pants, -0.4), 36, 10, facing, 1, 3, shade(pants, -0.6))
    # 胴（コート、裾がやや広がる）
    c.poly([(CX - 5, 24), (CX + 5, 24), (CX + 6, 37), (CX - 6, 37)], coat)
    c.gradient_h(CX - 5, 24, 3, 13, coat_l, coat)
    c.vline(CX + 5, 26, 36, coat_d)
    c.hline(36, CX - 5, CX + 5, coat_d)
    if facing == "down":
        c.rect(CX - 8, 25, 2, 9, coat); c.vline(CX - 8, 25, 33, coat_l); c.rect(CX - 8, 34, 2, 2, SKIN_D)
        c.rect(CX + 6, 25, 2, 9, coat_d); c.rect(CX + 6, 34, 2, 2, SKIN_D)
        c.vline(CX, 25, 36, coat_d)                                 # 前立て
        c.rect(CX - 2, 24, 4, 1, shade(coat_l, 0.2))                # 襟
        c.line(CX - 4, 24, CX + 4, 33, bag_l)                       # 鞄のベルト
    elif facing == "up":
        c.rect(CX - 8, 25, 2, 9, coat_d); c.rect(CX + 6, 25, 2, 9, coat)
        c.rect(CX - 4, 27, 8, 7, bag); c.rect(CX - 4, 27, 8, 1, bag_l); c.frame(CX - 4, 27, 8, 7, shade(bag, -0.4))
    elif facing == "left":
        c.rect(CX - 2, 26, 3, 9, coat_d if frame else coat); c.rect(CX - 2, 35, 3, 1, SKIN_D)
        c.rect(CX + 2, 27, 4, 7, bag); c.rect(CX + 2, 27, 4, 1, bag_l); c.frame(CX + 2, 27, 4, 7, shade(bag, -0.4))
    else:
        c.rect(CX - 1, 26, 3, 9, coat_d if frame else coat); c.rect(CX - 1, 35, 3, 1, SKIN_D)
        c.rect(CX - 6, 27, 4, 7, bag); c.rect(CX - 6, 27, 4, 1, bag_l); c.frame(CX - 6, 27, 4, 7, shade(bag, -0.4))
    c.rect(CX - 2, 23, 4, 2, SKIN_D)                                # 首
    head(c, facing, SKIN, hair, hair_d, 15, 8, 8)
    outline(c)


def heroine(c: Canvas, facing, frame):
    """澪：枯れ黄土のカーディガン、暗いスカート、赤茶の長い髪、ノート。悠よりわずかに小柄"""
    top = rgb("#b58d5a"); top_d = rgb("#7e6140"); top_l = rgb("#d0ac78")
    skirt = rgb("#2b3550"); skirt_d = rgb("#1a2138")
    hair = rgb("#5a3428"); hair_d = rgb("#3a2019")
    book = rgb("#d9d2c0")
    shadow(c, 6)
    legs(c, frame, SKIN, SKIN_D, 38, 8, facing, 1, 3, rgb("#3a2a22"))
    c.poly([(CX - 5, 31), (CX + 5, 31), (CX + 6, 39), (CX - 6, 39)], skirt)   # スカート
    for x in range(CX - 4, CX + 5, 3):
        c.vline(x, 33, 38, skirt_d)
    c.hline(38, CX - 5, CX + 5, skirt_d)
    c.rect(CX - 5, 25, 10, 7, top)                                  # カーディガン
    c.gradient_h(CX - 5, 25, 3, 7, top_l, top)
    c.vline(CX + 4, 26, 31, top_d)
    if facing == "down":
        c.rect(CX - 7, 26, 2, 7, top); c.vline(CX - 7, 26, 32, top_l); c.rect(CX - 7, 33, 2, 1, SKIN)
        c.rect(CX + 5, 26, 2, 7, top_d); c.rect(CX + 5, 33, 2, 1, SKIN)
        c.rect(CX - 1, 25, 2, 1, C["bone"])                          # 襟元
        c.rect(CX - 3, 29, 6, 4, book); c.frame(CX - 3, 29, 6, 4, shade(book, -0.4))
    elif facing == "up":
        c.rect(CX - 7, 26, 2, 7, top_d); c.rect(CX + 5, 26, 2, 7, top)
    elif facing == "left":
        c.rect(CX - 2, 27, 3, 6, top_d if frame else top); c.rect(CX - 2, 33, 3, 1, SKIN)
        c.rect(CX - 5, 29, 4, 4, book); c.frame(CX - 5, 29, 4, 4, shade(book, -0.4))
    else:
        c.rect(CX - 1, 27, 3, 6, top_d if frame else top); c.rect(CX - 1, 33, 3, 1, SKIN)
        c.rect(CX + 1, 29, 4, 4, book); c.frame(CX + 1, 29, 4, 4, shade(book, -0.4))
    c.rect(CX - 2, 24, 4, 1, SKIN_D)
    head(c, facing, SKIN, hair, hair_d, 16, 8, 8, long_hair=True)
    outline(c)


def stalker(c: Canvas, frame_facing, frame):
    """追跡者：顔の無い暗い人影。人より一回り大きい（36 px）。輪郭だけ僅かに明るく、血や傷は描かない"""
    facing = frame_facing
    body = rgb("#0b0d14"); edge = rgb("#1f2a44"); edge_l = rgb("#2b3856")
    shadow(c, 8)
    if side(facing):
        fx = CX + (1 if facing == "right" else -1)
        c.rect(fx - 4, 33, 3, 13 - (1 if frame else 0), body)
        c.rect(fx + (2 if frame else 1), 33, 3, 13, body)
    else:
        c.rect(CX - 5, 33, 4, 13 + (1 if frame else 0), body)
        c.rect(CX + 1, 33, 4, 13 - (1 if frame else 0), body)
    c.poly([(CX - 8, 20), (CX + 8, 20), (CX + 7, 34), (CX - 7, 34)], body)   # 胴（肩が広い）
    tilt = {"down": 0, "up": 0, "left": -1, "right": 1}[facing]
    c.hline(20, CX - 8 + max(0, tilt), CX + 7 + min(0, tilt), edge)
    if facing == "down":
        c.vline(CX - 8, 21, 31, edge); c.vline(CX + 7, 21, 31, edge)
        c.vline(CX - 10, 23, 36, body); c.vline(CX + 9, 23, 36, body)     # 長い腕
    elif facing == "up":
        c.vline(CX - 8, 21, 32, edge); c.vline(CX + 7, 21, 32, edge)
        c.rect(CX - 7, 22, 14, 2, edge)
    elif facing == "left":
        c.vline(CX - 8, 21, 34, edge_l); c.vline(CX + 7, 24, 31, edge)
        c.rect(CX - 11, 23, 2, 12, body)
    else:
        c.vline(CX + 7, 21, 34, edge_l); c.vline(CX - 8, 24, 31, edge)
        c.rect(CX + 9, 23, 2, 12, body)
    c.rect(CX - 4, 10, 8, 11, body)                                  # 頭（首が無い）
    c.hline(10, CX - 3, CX + 2, edge)
    if facing == "left":
        c.vline(CX - 4, 11, 18, edge)
    elif facing == "right":
        c.vline(CX + 3, 11, 18, edge)
    elif facing == "up":
        c.rect(CX - 3, 11, 6, 7, mix(body, edge, 0.5))
    c.outline(lambda x, y: c.get(x, y) is not None, mix(body, edge, 0.45))


def toki(c: Canvas, facing, frame):
    """トキ：小柄（28 px）、白髪をまとめ、藍の着物に白い前掛け"""
    kimono = rgb("#2b3550"); kimono_d = rgb("#1a2138"); kimono_l = rgb("#3c4a6c")
    apron = rgb("#d9d2c0"); apron_d = rgb("#a9a290")
    hair = rgb("#c8c4bc"); hair_d = rgb("#8f8b84")
    shadow(c, 6)
    sway = 1 if frame else 0
    c.poly([(CX - 5, 27), (CX + 5, 27), (CX + 6, 45), (CX - 6, 45)], kimono)      # 着物
    c.gradient_h(CX - 5, 27, 2, 18, kimono_l, kimono)
    c.vline(CX + 5, 29, 44, kimono_d)
    c.hline(44, CX - 5, CX + 5, kimono_d)
    c.rect(CX - 4, 45, 3, 1, SKIN_D); c.rect(CX + 1, 45, 3, 1, SKIN_D)              # 足袋
    if facing != "up":
        c.rect(CX - 3, 32, 7, 11, apron)
        c.vline(CX + 3, 33, 42, apron_d); c.hline(42, CX - 3, CX + 3, apron_d)
        c.rect(CX - 4, 30, 8, 2, rgb("#8a4a3a"))                                     # 帯
    else:
        c.rect(CX - 4, 30, 8, 2, rgb("#8a4a3a")); c.rect(CX - 2, 29, 4, 5, rgb("#6e3a2e"))   # 帯結び
    if facing == "down":
        c.rect(CX - 8, 29, 3, 7, kimono_l); c.rect(CX + 5, 29, 3, 7, kimono_d)      # 袖
        c.rect(CX - 2, 35, 4, 2, SKIN_OLD)                                            # 組んだ手
    elif facing == "up":
        c.rect(CX - 8, 29, 3, 7, kimono_d); c.rect(CX + 5, 29, 3, 7, kimono)
    elif facing == "left":
        c.rect(CX - 4, 29, 4, 7, kimono_l); c.rect(CX - 4, 36, 3, 1, SKIN_OLD)
    else:
        c.rect(CX, 29, 4, 7, kimono_d); c.rect(CX + 1, 36, 3, 1, SKIN_OLD)
    c.rect(CX - 2, 26, 4, 1, shade(SKIN_OLD, -0.2))
    head(c, facing, SKIN_OLD, hair, hair_d, 18, 8, 7, bangs=False)
    if facing != "down":
        c.disc(CX + sway, 18, 2, hair); c.px(CX + sway - 1, 17, shade(hair, 0.3))   # まとめ髪
    if facing == "down":
        c.px(CX - 3 + sway, 23, shade(SKIN_OLD, -0.25)); c.px(CX + 2 + sway, 23, shade(SKIN_OLD, -0.25))   # しわ
    outline(c)


def shige(c: Canvas, facing, frame):
    """シゲ：朝和の老婆（28 px）。濃い野良着（絣）ともんぺ、手拭いを被る。前かがみ。トキと色で見分ける"""
    cloth = rgb("#3a4a3a"); cloth_d = rgb("#243024"); cloth_l = rgb("#526552")
    monpe = rgb("#2a2e3a"); monpe_d = rgb("#1a1d26")
    towel = rgb("#c9c3b0"); towel_d = rgb("#948f80"); towel_pat = rgb("#4a5a78")
    shadow(c, 6)
    sway = 1 if frame else 0
    c.rect(CX - 6, 36, 5, 9, monpe); c.rect(CX + 1, 36, 5, 9, monpe)               # もんぺ（太い脚）
    c.vline(CX - 2, 36, 44, monpe_d); c.vline(CX + 5, 36, 44, monpe_d)
    c.rect(CX - 6, 45, 4, 1, rgb("#3a2a22")); c.rect(CX + 2, 45, 4, 1, rgb("#3a2a22"))
    c.poly([(CX - 6, 27), (CX + 6, 27), (CX + 7, 37), (CX - 7, 37)], cloth)        # 上着
    c.gradient_h(CX - 6, 27, 3, 10, cloth_l, cloth)
    c.vline(CX + 6, 28, 36, cloth_d)
    c.hline(36, CX - 6, CX + 6, cloth_d)
    for y in range(29, 36, 3):                                                      # 絣の点
        for x in range(CX - 5, CX + 6, 3):
            c.px(x + (y % 2), y, cloth_d)
    if facing == "down":
        c.rect(CX - 9, 28, 3, 8, cloth_l); c.rect(CX + 6, 28, 3, 8, cloth_d)
        c.rect(CX - 9, 36, 3, 1, SKIN_OLD); c.rect(CX + 6, 36, 3, 1, SKIN_OLD)
        c.vline(CX, 27, 35, cloth_d)
        c.rect(CX - 2, 27, 4, 1, towel)
    elif facing == "up":
        c.rect(CX - 9, 28, 3, 8, cloth_d); c.rect(CX + 6, 28, 3, 8, cloth)
        c.rect(CX - 3, 27, 6, 4, towel_d)                                           # 手拭いの垂れ
    elif facing == "left":
        c.rect(CX - 3, 29, 3, 7, cloth_d if frame else cloth); c.rect(CX - 3, 36, 3, 1, SKIN_OLD)
    else:
        c.rect(CX, 29, 3, 7, cloth_d if frame else cloth); c.rect(CX, 36, 3, 1, SKIN_OLD)
    c.rect(CX - 2, 26, 4, 1, shade(SKIN_OLD, -0.2))
    head(c, facing, SKIN_OLD, towel, towel_d, 18, 8, 7, bangs=False, cap=towel)   # 頭（前かがみで低い）
    for x in range(CX - 4 + sway, CX + 4 + sway, 3):                                # 手拭いの柄
        c.px(x, 19, towel_pat)
    if side(facing):
        tx = CX - 5 + sway if facing == "left" else CX + 4 + sway
        c.rect(tx, 21, 2, 5, towel); c.vline(tx + (1 if facing == "left" else 0), 21, 25, towel_d)   # 結び目の垂れ
    if facing == "down":
        c.px(CX - 3 + sway, 24, shade(SKIN_OLD, -0.25)); c.px(CX + 2 + sway, 24, shade(SKIN_OLD, -0.25))
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
