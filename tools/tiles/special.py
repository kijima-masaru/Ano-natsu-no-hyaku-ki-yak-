"""種別名ごとの専用描画（paint_atlas.py から使う）。汎用ペインタより優先される。

汎用ペインタは「箱」「看板」「柵」などを引数で使い回すため、物ごとの特徴（時計塔の文字盤、電話ボックスの受話器、
墓石の高さの違い）が出ない。ここでは目立つ物を 1 種ずつ描く。16×16、パレット 16 色、光は左上、物は墨の輪郭。
"""
from paint_atlas import (BONE, CONC, DEEP, DUSK, FLUO, FOG, GLOW, GREEN, GREEN_L, MOSS, NIGHT, OCHRE, RED, RUST, RUST_D, S, SUMI,
                         Tile, dk, lt, ground, grass, gravel, interlock, planks, roof, water, P, PB, PF)


def base(t: Tile, p, default=DUSK, density=0.06):
    g = P(p, "ground", default)
    ground(t, {"base": g, "speck": lt(g) if g != BONE else g, "density": density})
    return g


def shadow(t: Tile, cx, cy, rx, ry, c=None):
    """物の足元の落ち影（楕円）。地面色の一段暗い色"""
    for y in range(S):
        for x in range(S):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                cur = t.get(x, y)
                t.px(x, y, c if c is not None else (dk(cur) if cur is not None else SUMI))


def line(t: Tile, x0, y0, x1, y1, c):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        t.px(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)


# ─────────────── 道路まわり ───────────────

def guardrail(t, p):
    """ガードレール：路肩の白い W ビームと支柱。奥は道路"""
    base(t, p, DUSK)
    t.rect(0, 0, S, 4, FOG)  # 歩道側
    t.hline(4, 0, S - 1, CONC)
    for x in (3, 11):
        t.rect(x, 5, 2, 10, FOG)
        t.vline(x, 5, 14, CONC)
        t.px(x, 15, SUMI)
        t.px(x + 1, 15, SUMI)
    t.rect(0, 6, S, 5, BONE)
    t.hline(8, 0, S - 1, CONC)  # ビームの谷
    t.hline(6, 0, S - 1, BONE)
    t.hline(10, 0, S - 1, FOG)
    t.hline(11, 0, S - 1, SUMI)
    t.hline(5, 0, S - 1, SUMI)
    t.noise(CONC, 0.08, 0, 6, S, 5, k=2)


def barricade(t, p):
    """バリケード：A 型の脚に縞の板。手前に落ち影"""
    base(t, p, DUSK)
    shadow(t, 8, 15, 7, 1.5)
    for x in (2, 12):
        line(t, x, 6, x - 1, 14, FOG)
        line(t, x + 1, 6, x + 2, 14, FOG)
        t.hline(14, x - 1, x + 2, DUSK)
    t.rect(0, 5, S, 6, BONE)
    for y in range(5, 11):
        for x in range(S):
            if ((x + y) // 3) % 2 == 0:
                t.px(x, y, RED)
    t.hline(10, 0, S - 1, dk(RED))
    t.frame(0, 5, S, 6, SUMI)
    t.px(7, 3, GLOW)  # 上の点滅灯
    t.rect(6, 4, 4, 1, SUMI)


def fence_locked(t, p):
    """フェンス（施錠）：金網の門扉、閉じた鎖と赤い南京錠"""
    base(t, p, DUSK)
    for y in range(S):
        for x in range(S):
            if (x + y) % 3 == 0 or (x - y) % 3 == 0:
                t.px(x, y, FOG)
    t.frame(0, 0, S, S, CONC)
    t.vline(7, 0, S - 1, CONC)
    t.vline(8, 0, S - 1, FOG)
    t.hline(0, 0, S - 1, BONE)
    t.rect(6, 6, 4, 2, CONC)   # 鎖
    t.rect(6, 8, 4, 4, RED)
    t.px(6, 8, lt(RED))
    t.px(8, 10, SUMI)
    t.rect(6, 12, 4, 1, SUMI)


def drain(t, p):
    """側溝：路面に埋まる溝と縁。グレーチングは別"""
    b = P(p, "base", DUSK)
    ground(t, {"base": b, "speck": lt(b), "density": 0.05})
    t.rect(0, 5, S, 6, CONC)
    t.hline(5, 0, S - 1, BONE)
    t.rect(0, 7, S, 2, SUMI)
    t.hline(9, 0, S - 1, DEEP)
    t.hline(10, 0, S - 1, DUSK)
    t.noise(FOG, 0.15, 0, 6, S, 1, k=2)


def grating(t, p):
    """グレーチング：格子の蓋"""
    b = P(p, "base", FOG)
    ground(t, {"base": b, "speck": lt(b), "density": 0.05})
    t.rect(0, 4, S, 8, CONC)
    t.hline(4, 0, S - 1, BONE)
    t.hline(11, 0, S - 1, DUSK)
    for x in range(1, S, 3):
        t.rect(x, 5, 1, 6, SUMI)
        t.px(x + 1, 5, BONE)
    t.hline(8, 0, S - 1, FOG)


def parking_car(t, p):
    """駐車車両（暗）：上から見た車体。屋根の反射、窓、灯火"""
    base(t, p, DUSK)
    shadow(t, 8, 8, 7.5, 7)
    t.rect(2, 1, 12, 14, DEEP)          # 車体
    t.rect(3, 4, 10, 3, NIGHT)          # 前ガラス
    t.rect(3, 11, 10, 2, NIGHT)         # 後ガラス
    t.rect(4, 7, 8, 4, DUSK)            # 屋根
    t.hline(7, 4, 11, FOG)              # 屋根の反射
    t.px(4, 4, FOG)
    t.px(5, 4, DUSK)
    t.px(3, 1, DUSK)
    t.px(12, 1, DUSK)
    t.rect(3, 1, 10, 1, DUSK)
    t.px(2, 2, OCHRE)                   # ヘッドライト（消灯、反射）
    t.px(13, 2, OCHRE)
    t.px(2, 14, RED)                    # テールランプ
    t.px(13, 14, RED)
    t.vline(1, 5, 12, SUMI)             # タイヤ
    t.vline(14, 5, 12, SUMI)
    t.outline([DEEP, NIGHT, DUSK, FOG, OCHRE, RED], SUMI)


def vending(t, p):
    """自販機正面：3 段の商品、ボタン、赤の帯、取り出し口。前面が発光"""
    t.fill(FOG)
    t.frame(0, 0, S, S, SUMI)
    t.vline(1, 1, 14, CONC)
    t.hline(1, 1, 14, CONC)
    t.rect(2, 2, 9, 8, GLOW)
    t.rect(3, 3, 7, 6, BONE)
    for row, y in enumerate((3, 6)):
        for i, x in enumerate((3, 5, 7, 9)):
            t.px(x, y, (RED, FLUO, OCHRE, RED, DUSK)[(i + row) % 5])
            t.px(x, y + 1, (RUST, DEEP, RUST, RUST_D, NIGHT)[(i + row) % 5])
            t.px(x + 1, y + 1, dk(BONE))
    t.rect(11, 2, 3, 12, RED)
    t.vline(11, 2, 13, lt(RED))
    t.vline(13, 2, 13, dk(RED))
    for y in (4, 6, 8):
        t.px(12, y, BONE)
    t.rect(2, 10, 8, 1, DEEP)
    t.rect(2, 11, 8, 3, SUMI)
    t.hline(12, 3, 8, NIGHT)
    t.px(12, 11, FLUO)   # 硬貨投入口の光
    t.rect(1, 14, 14, 1, DUSK)
    t.hline(15, 1, 14, SUMI)


def streetlamp(t, p):
    """街灯：柱・アーム・傘と灯。地面に光の輪"""
    g = base(t, p, DUSK)
    for y in range(S):
        for x in range(S):
            d = abs(x - 9) * 1.2 + abs(y - 13) * 0.9
            if d <= 6 and t.rand(x, y, 3) < 0.65 - d * 0.1:
                t.px(x, y, lt(g) if d > 3 else OCHRE)
    t.rect(6, 4, 2, 12, FOG)
    t.vline(6, 4, 15, CONC)
    t.vline(7, 4, 15, DUSK)
    t.rect(5, 15, 4, 1, SUMI)
    t.hline(3, 6, 10, FOG)          # アーム
    t.rect(8, 1, 5, 3, GLOW)        # 傘と灯
    t.hline(0, 8, 12, CONC)
    t.hline(1, 8, 12, BONE)
    t.hline(4, 9, 12, BONE)
    t.px(7, 2, OCHRE)
    t.px(13, 2, OCHRE)
    t.px(9, 5, OCHRE)
    t.px(11, 5, OCHRE)


def stone_lantern(t, p):
    """常夜灯：石の笠・火袋・竿・台。火袋に灯"""
    base(t, p, DUSK)
    shadow(t, 8, 15, 5, 1.2)
    t.rect(4, 13, 8, 3, FOG)
    t.hline(13, 4, 11, CONC)
    t.rect(6, 9, 4, 4, CONC)
    t.vline(6, 9, 12, BONE)
    t.vline(9, 9, 12, DUSK)
    t.rect(5, 8, 6, 1, FOG)
    t.rect(4, 4, 8, 4, FOG)          # 火袋
    t.rect(5, 5, 6, 2, GLOW)
    t.px(5, 5, BONE)
    t.px(7, 4, SUMI)
    t.px(9, 4, SUMI)
    t.rect(3, 3, 10, 1, CONC)        # 笠
    t.hline(2, 4, 11, FOG)
    t.hline(1, 6, 9, FOG)
    t.px(7, 0, CONC)
    t.px(8, 0, CONC)
    t.rect(2, 8, 12, 1, DUSK)
    t.outline([FOG, CONC, GLOW, BONE], SUMI)


def fluorescent(t, p):
    """蛍光灯：暗い天井に白い管、両端の口金、下に光"""
    t.fill(NIGHT)
    for y in range(S):
        for x in range(S):
            if abs(y - 7) <= 4 and t.rand(x, y, 2) < 0.45 - abs(y - 7) * 0.08:
                t.px(x, y, DEEP)
    t.rect(1, 5, 14, 5, DUSK)        # 器具
    t.rect(2, 6, 12, 3, FLUO)
    t.rect(3, 7, 10, 1, BONE)
    t.px(2, 6, dk(FLUO))
    t.px(13, 8, dk(FLUO))
    t.rect(0, 6, 1, 3, FOG)          # 口金
    t.rect(15, 6, 1, 3, FOG)
    t.hline(4, 1, 14, FOG)
    t.hline(10, 1, 14, SUMI)


def emergency_light(t, p):
    """非常灯：緑白の小さな箱。周囲に淡い光"""
    t.fill(NIGHT)
    for y in range(S):
        for x in range(S):
            if abs(x - 8) + abs(y - 7) < 7 and t.rand(x, y, 2) < 0.4:
                t.px(x, y, DEEP)
    t.rect(4, 4, 8, 7, FOG)
    t.rect(5, 5, 6, 5, FLUO)
    t.rect(6, 6, 4, 1, BONE)
    t.px(6, 8, BONE)                 # 走る人の記号（点）
    t.px(7, 8, BONE)
    t.frame(4, 4, 8, 7, SUMI)
    t.px(4, 4, CONC)


def police_light(t, p):
    """交番の赤色灯：柱の上の赤いランプ、赤いにじみ"""
    base(t, p, DUSK)
    for y in range(S):
        for x in range(S):
            if abs(x - 8) * 1.3 + abs(y - 4) < 6 and t.rand(x, y, 2) < 0.4:
                t.px(x, y, RUST_D if t.get(x, y) == DUSK else t.get(x, y))
    t.rect(7, 6, 2, 10, FOG)
    t.vline(7, 6, 15, CONC)
    t.rect(6, 15, 4, 1, SUMI)
    t.rect(6, 3, 4, 3, RED)
    t.rect(7, 2, 2, 1, RED)
    t.px(7, 3, GLOW)
    t.rect(5, 6, 6, 1, DUSK)
    t.hline(1, 7, 8, dk(RED))
    t.outline([RED, GLOW], SUMI)


def phone_booth(t, p):
    """公衆電話ボックス：ガラスの箱、青白い灯、受話器"""
    base(t, p, DUSK)
    shadow(t, 8, 15, 6, 1.2)
    t.rect(3, 1, 10, 14, FLUO)
    t.dither_sparse(4, 2, 8, 12, BONE, 0)
    t.frame(3, 1, 10, 14, CONC)
    t.rect(3, 0, 10, 2, FOG)         # 屋根
    t.hline(0, 3, 12, CONC)
    t.vline(7, 2, 14, CONC)          # 桟
    t.vline(8, 2, 14, CONC)
    t.rect(9, 5, 3, 4, DEEP)         # 電話機
    t.px(10, 5, FOG)
    t.rect(4, 6, 2, 3, DEEP)         # 受話器
    t.px(4, 6, CONC)
    t.rect(3, 14, 10, 1, DUSK)
    t.outline([FLUO, BONE, CONC, FOG, DEEP], SUMI)


def bus_bench(t, p):
    """待合ベンチ：バス停の屋根の下、背もたれのあるベンチ"""
    base(t, p, DUSK)
    t.rect(0, 0, S, 3, FOG)          # 屋根
    t.hline(0, 0, S - 1, CONC)
    t.hline(3, 0, S - 1, SUMI)
    t.rect(0, 4, 2, 12, FOG)         # 支柱
    t.vline(0, 4, 15, CONC)
    shadow(t, 9, 14, 6, 1.2)
    t.rect(3, 5, 12, 3, FOG)         # 背
    t.hline(5, 3, 14, CONC)
    t.rect(3, 9, 12, 3, FOG)         # 座
    t.hline(9, 3, 14, CONC)
    t.rect(4, 12, 1, 3, DUSK)
    t.rect(13, 12, 1, 3, DUSK)
    t.outline([FOG, CONC], SUMI)


def timetable(t, p):
    """時刻表看板：バス停の丸い標識と柱、時刻表"""
    base(t, p, DUSK)
    t.rect(7, 6, 2, 10, FOG)
    t.vline(7, 6, 15, CONC)
    t.rect(6, 15, 4, 1, SUMI)
    t.disc(8, 3, 3, BONE)            # 丸い標識
    t.disc(8, 3, 2, FOG)
    t.px(8, 3, BONE)
    t.rect(3, 8, 10, 5, BONE)        # 時刻表
    for y in (9, 11):
        t.hline(y, 4, 11, DUSK)
    t.px(5, 10, DUSK)
    t.px(9, 10, DUSK)
    t.outline([BONE, FOG, CONC], SUMI)


def shop_sign(t, p):
    """商店の看板（褪せ）：色の抜けた板に薄い文字の痕、錆の垂れ"""
    base(t, p, DUSK)
    t.rect(1, 1, 14, 9, OCHRE)
    t.rect(1, 1, 14, 1, BONE)
    t.rect(1, 9, 14, 1, RUST)
    t.frame(0, 0, S, 11, RUST_D)
    t.hline(3, 3, 11, RUST)          # 文字の痕
    t.hline(5, 3, 8, RUST)
    t.hline(7, 3, 12, RUST)
    t.noise(BONE, 0.12, 2, 2, 12, 7, k=3)
    t.vline(12, 4, 9, RUST_D)        # 錆の垂れ
    t.vline(5, 6, 9, RUST_D)
    t.rect(3, 11, 2, 5, FOG)         # 脚
    t.rect(11, 11, 2, 5, FOG)
    t.rect(2, 15, 12, 1, SUMI)


def plain_sign(t, p):
    """店舗看板（無地）：暗い看板箱、消えた照明"""
    base(t, p, DUSK)
    t.rect(1, 2, 14, 8, CONC)
    t.rect(2, 3, 12, 6, FOG)
    t.frame(1, 2, 14, 8, SUMI)
    t.hline(3, 2, 13, CONC)
    t.noise(DUSK, 0.1, 2, 3, 12, 6, k=2)
    t.rect(4, 0, 8, 1, FOG)          # 照明のアーム（消灯）
    t.px(5, 1, DUSK)
    t.px(10, 1, DUSK)
    t.rect(7, 10, 2, 6, FOG)
    t.vline(7, 10, 15, CONC)


def bulletin(t, p):
    """掲示板：屋根付きの板に貼り紙が数枚、画鋲"""
    base(t, p, DUSK)
    t.rect(0, 0, S, 2, RUST_D)       # 屋根
    t.hline(0, 0, S - 1, RUST)
    t.rect(1, 2, 14, 11, OCHRE)
    t.frame(1, 2, 14, 11, RUST_D)
    for (x, y, w, h) in [(2, 3, 5, 5), (8, 3, 5, 4), (3, 8, 4, 4), (9, 8, 4, 4)]:
        t.rect(x, y, w, h, BONE)
        t.hline(y + 1, x + 1, x + w - 2, DUSK)
        if h > 3:
            t.hline(y + 3, x + 1, x + w - 3, DUSK)
        t.px(x + w // 2, y, RED)
    t.rect(6, 13, 4, 3, FOG)
    t.vline(6, 13, 15, CONC)
    t.rect(5, 15, 6, 1, SUMI)


def map_board(t, p):
    """看板（地図）・案内板：白い板に地図の線"""
    base(t, p, DUSK)
    t.rect(1, 1, 14, 10, BONE)
    t.frame(1, 1, 14, 10, FOG)
    t.frame(0, 0, S, 12, SUMI)
    line(t, 3, 8, 6, 3, DUSK)        # 道
    line(t, 6, 3, 12, 5, DUSK)
    line(t, 7, 9, 12, 5, DUSK)
    t.rect(4, 5, 2, 2, GREEN)        # 緑地
    t.rect(9, 7, 2, 2, GREEN)
    t.px(8, 4, RED)                  # 現在地
    t.rect(3, 12, 2, 4, FOG)
    t.rect(11, 12, 2, 4, FOG)
    t.rect(2, 15, 12, 1, SUMI)


def info_board(t, p):
    """案内板（城址）：木枠に黄土の板、縄張図の線"""
    base(t, p, MOSS)
    t.rect(1, 1, 14, 10, OCHRE)
    t.frame(1, 1, 14, 10, RUST_D)
    t.frame(0, 0, S, 12, RUST_D)
    t.rect(0, 0, S, 1, RUST)
    for (x, y, w, h) in [(3, 3, 5, 3), (6, 5, 6, 4), (9, 2, 4, 3)]:
        t.frame(x, y, w, h, RUST_D)
    t.px(7, 6, SUMI)
    t.rect(3, 12, 2, 4, RUST_D)
    t.rect(11, 12, 2, 4, RUST_D)
    t.rect(2, 15, 12, 1, SUMI)


def utility_pole(t, p):
    """電柱・電線：コンクリート柱、腕金、碍子、電線 3 本"""
    base(t, p, DUSK)
    t.hline(0, 0, S - 1, SUMI)
    t.hline(2, 0, S - 1, SUMI)
    t.hline(4, 0, S - 1, NIGHT)
    t.rect(7, 0, 2, S, FOG)
    t.vline(7, 0, 15, CONC)
    t.vline(8, 0, 15, DUSK)
    t.hline(3, 2, 13, CONC)          # 腕金
    t.hline(4, 3, 12, DUSK)
    for x in (3, 6, 10, 13):
        t.px(x, 2, BONE)             # 碍子
        t.px(x, 1, CONC)
    t.rect(6, 6, 4, 1, FOG)          # 足場ボルト
    t.rect(6, 9, 4, 1, FOG)
    t.rect(6, 14, 4, 2, SUMI)
    t.px(6, 12, OCHRE)               # 番号札
    t.px(9, 12, OCHRE)


def fence_pole(t, p):
    """電気柵ポール：畑の縁の細い杭と 2 本の線、碍子"""
    base(t, p, GREEN)
    t.rect(7, 4, 2, 12, RUST_D)
    t.vline(7, 4, 15, RUST)
    t.rect(6, 15, 4, 1, SUMI)
    t.hline(6, 0, S - 1, CONC)
    t.hline(10, 0, S - 1, CONC)
    t.px(6, 6, GLOW)
    t.px(9, 6, GLOW)
    t.px(6, 10, GLOW)
    t.px(9, 10, GLOW)
    t.rect(6, 1, 4, 2, GLOW)         # 注意札
    t.px(7, 1, RED)
    t.px(8, 1, RED)


def clock_tower(t, p):
    """時計塔：文字盤のある柱時計。上部に灯"""
    base(t, p, DUSK)
    shadow(t, 8, 15, 5, 1.2)
    t.rect(6, 8, 4, 8, FOG)          # 柱
    t.vline(6, 8, 15, CONC)
    t.vline(9, 8, 15, DUSK)
    t.rect(4, 14, 8, 2, CONC)        # 台座
    t.hline(15, 4, 11, SUMI)
    t.rect(3, 1, 10, 8, CONC)        # 時計の箱
    t.rect(4, 2, 8, 6, BONE)         # 文字盤
    t.disc(7.5, 4.5, 3, BONE)
    t.px(7, 2, SUMI)
    t.px(7, 7, SUMI)
    t.px(4, 4, SUMI)
    t.px(11, 4, SUMI)
    t.hline(4, 7, 9, SUMI)           # 針（分）
    t.vline(7, 4, 6, SUMI)           # 針（時）
    t.rect(3, 0, 10, 1, FOG)
    t.px(7, 0, GLOW)
    t.px(8, 0, GLOW)
    t.outline([CONC, BONE, FOG], SUMI)


def water_tower(t, p):
    """給水塔：団地の丸い高架水槽と脚"""
    base(t, p, DUSK)
    shadow(t, 8, 15, 6, 1.2)
    t.rect(3, 9, 2, 7, FOG)          # 脚
    t.rect(11, 9, 2, 7, FOG)
    t.vline(3, 9, 15, CONC)
    t.vline(11, 9, 15, CONC)
    t.hline(12, 5, 10, FOG)          # 筋交い
    t.ellipse(7.5, 4.5, 6, 4, CONC)  # 水槽（円筒を斜め上から）
    t.rect(2, 4, 12, 4, CONC)
    t.ellipse(7.5, 8, 6, 1.5, FOG)
    t.hline(2, 4, 11, BONE)
    t.px(3, 3, BONE)
    t.vline(13, 4, 7, FOG)
    t.hline(9, 3, 12, DUSK)
    for y in range(3, 7):
        if t.rand(0, y) < 0.5:
            t.vline(4 + int(t.rand(1, y) * 8), y, 8, FOG)  # 雨染み
    t.px(7, 5, RED)                  # 航空障害灯ではなく、社名の赤
    t.outline([CONC, FOG, BONE], SUMI)


def fire_tower(t, p):
    """火の見櫓：鉄骨のやぐら、上に半鐘と屋根"""
    base(t, p, DUSK)
    t.rect(4, 15, 8, 1, SUMI)
    for y in range(3, 15):
        w = 2 + (y - 3) // 3
        t.px(8 - w, y, RUST)
        t.px(7 + w, y, RUST)
        t.px(8 - w, y, RUST if y % 2 else RUST_D)
    for y in (5, 8, 11, 14):
        w = 2 + (y - 3) // 3
        t.hline(y, 8 - w, 7 + w, RUST_D)
    line(t, 6, 6, 9, 8, RUST_D)      # 筋交い
    line(t, 9, 9, 5, 11, RUST_D)
    t.rect(4, 2, 8, 1, RUST_D)       # 屋根
    t.rect(5, 1, 6, 1, RUST)
    t.rect(6, 0, 4, 1, RUST)
    t.px(7, 3, OCHRE)                # 半鐘
    t.px(8, 3, OCHRE)
    t.px(8, 4, RUST)
    t.outline([RUST, RUST_D, OCHRE], SUMI)


def flood_light(t, p):
    """照明塔：河川敷の高い鉄柱と、上の 2 灯（点灯）"""
    base(t, p, GREEN)
    for y in range(S):
        for x in range(S):
            if abs(x - 8) * 0.8 + abs(y - 3) < 6 and t.rand(x, y, 2) < 0.35:
                t.px(x, y, GREEN_L)
    t.rect(7, 4, 2, 12, FOG)
    t.vline(7, 4, 15, CONC)
    t.rect(6, 15, 4, 1, SUMI)
    t.rect(3, 2, 10, 2, DUSK)        # 灯具の枠
    t.rect(3, 1, 4, 2, GLOW)
    t.rect(9, 1, 4, 2, GLOW)
    t.px(4, 1, BONE)
    t.px(10, 1, BONE)
    t.hline(0, 3, 12, FOG)
    t.hline(4, 3, 12, OCHRE)
    t.hline(6, 6, 9, FOG)            # 梯子の段
    t.hline(9, 6, 9, FOG)
    t.hline(12, 6, 9, FOG)


def postboxes(t, p):
    """集合ポスト：6 口のステンレスの箱、投入口と名札"""
    base(t, p, DUSK)
    t.rect(1, 2, 14, 12, CONC)
    t.hline(2, 1, 14, BONE)
    t.vline(1, 2, 13, BONE)
    for row in range(2):
        for col in range(3):
            x = 2 + col * 4
            y = 3 + row * 5
            t.rect(x, y, 4, 5, FOG)
            t.rect(x, y, 4, 1, CONC)
            t.hline(y + 2, x + 1, x + 2, SUMI)      # 投入口
            t.px(x + 1, y + 4, BONE if (row + col) % 2 else OCHRE)  # 名札
    t.hline(13, 1, 14, DUSK)
    t.frame(1, 2, 14, 12, SUMI)
    t.rect(2, 14, 12, 1, SUMI)


def zushi(t, p):
    """厨子：黒漆の小さな仏壇、金具、内側は暗い"""
    base(t, p, NIGHT)
    t.rect(3, 1, 10, 13, RUST_D)
    t.rect(2, 0, 12, 2, RUST_D)      # 屋根
    t.hline(0, 3, 12, RUST)
    t.rect(4, 3, 8, 9, SUMI)         # 内側
    t.rect(6, 6, 4, 4, OCHRE)        # 像（面だけ見える）
    t.px(7, 7, SUMI)
    t.px(8, 7, SUMI)
    t.vline(4, 3, 11, RUST)          # 開いた扉
    t.vline(11, 3, 11, RUST)
    t.px(5, 5, OCHRE)                # 金具
    t.px(10, 5, OCHRE)
    t.rect(3, 13, 10, 2, RUST_D)
    t.hline(14, 3, 12, SUMI)
    t.outline([RUST_D, RUST, SUMI, OCHRE], SUMI)


def desk_chair(t, p):
    """教室の机・椅子：上から見た木の机と椅子"""
    base(t, p, OCHRE, 0.1)
    t.rect(2, 3, 12, 7, RUST)        # 天板
    t.hline(3, 2, 13, OCHRE)
    t.vline(2, 3, 9, OCHRE)
    t.hline(9, 2, 13, RUST_D)
    t.vline(13, 3, 9, RUST_D)
    t.noise(RUST_D, 0.1, 3, 4, 10, 5, k=2)
    t.px(3, 10, SUMI)                # 脚
    t.px(12, 10, SUMI)
    t.rect(5, 11, 6, 4, RUST_D)      # 椅子
    t.hline(11, 5, 10, RUST)
    t.rect(6, 12, 4, 2, RUST)
    t.px(5, 15, SUMI)
    t.px(10, 15, SUMI)
    t.outline([RUST, RUST_D, OCHRE], SUMI)


def blackboard(t, p):
    """黒板：木枠の緑の板、チョークの文字の痕、粉受け"""
    base(t, p, RUST, 0.06)
    t.rect(1, 1, 14, 11, MOSS)
    t.frame(0, 0, S, 13, RUST_D)
    t.hline(0, 0, S - 1, RUST)
    t.noise(GREEN, 0.15, 1, 1, 14, 11, k=2)
    t.hline(3, 3, 9, BONE)           # 文字の痕（消し残し）
    t.hline(5, 3, 6, CONC)
    t.hline(7, 4, 11, CONC)
    t.hline(9, 3, 7, BONE)
    t.rect(1, 13, 14, 1, RUST)       # 粉受け
    t.px(3, 13, BONE)
    t.px(4, 13, BONE)
    t.hline(14, 1, 14, SUMI)


def weather_box(t, p):
    """百葉箱：白い鎧戸の箱と脚"""
    base(t, p, GREEN)
    shadow(t, 8, 15, 4, 1.2)
    t.rect(4, 12, 1, 4, FOG)         # 脚
    t.rect(11, 12, 1, 4, FOG)
    t.rect(3, 2, 10, 10, BONE)
    t.rect(3, 1, 10, 1, CONC)        # 屋根
    t.rect(2, 0, 12, 1, FOG)
    for y in range(4, 11, 2):
        t.hline(y, 4, 11, CONC)      # 鎧戸
    t.vline(3, 2, 11, BONE)
    t.vline(12, 2, 11, CONC)
    t.hline(11, 3, 12, FOG)
    t.outline([BONE, CONC, FOG], SUMI)


def platform(t, p):
    """朝礼台：コンクリートの段と手すり"""
    base(t, p, RUST, 0.1)
    shadow(t, 8, 14, 7, 1.5)
    t.rect(2, 5, 12, 8, CONC)
    t.hline(5, 2, 13, BONE)
    t.vline(2, 5, 12, BONE)
    t.rect(2, 11, 12, 2, FOG)        # 段
    t.hline(12, 2, 13, DUSK)
    t.rect(2, 13, 12, 1, DUSK)
    t.vline(12, 2, 5, FOG)           # 手すり
    t.vline(3, 2, 5, FOG)
    t.hline(2, 3, 12, CONC)
    t.outline([CONC, FOG, BONE], SUMI)


def dugout(t, p):
    """ダッグアウト：屋根の下のベンチ、内側は暗い"""
    base(t, p, DUSK)
    t.rect(0, 0, S, 3, FOG)          # 屋根
    t.hline(0, 0, S - 1, CONC)
    t.hline(3, 0, S - 1, SUMI)
    t.rect(1, 4, 14, 8, NIGHT)       # 内側
    t.rect(2, 7, 12, 2, RUST_D)      # ベンチ
    t.hline(7, 2, 13, RUST)
    t.rect(0, 4, 1, 12, FOG)         # 側壁
    t.rect(15, 4, 1, 12, FOG)
    t.rect(1, 12, 14, 1, CONC)       # 段
    t.hline(13, 1, 14, DUSK)
    t.rect(1, 14, 14, 2, DUSK)


def bike_shed(t, p):
    """自転車置き場：屋根の下に自転車の車輪が並ぶ"""
    base(t, p, DUSK)
    t.rect(0, 0, S, 3, FOG)
    t.hline(0, 0, S - 1, CONC)
    t.hline(3, 0, S - 1, SUMI)
    for x in (1, 6, 11):
        t.disc(x + 1.5, 9.5, 2, CONC)
        t.disc(x + 1.5, 9.5, 1, DUSK)
        t.px(x + 2, 6, FOG)
        t.vline(x + 2, 6, 7, FOG)
        t.hline(6, x + 1, x + 3, FOG)
    t.hline(13, 0, S - 1, SUMI)
    t.rect(0, 14, S, 2, DUSK)


def carport(t, p):
    """カーポート：波板の屋根を上から。柱と車の影"""
    base(t, p, DUSK)
    t.rect(1, 1, 14, 13, FOG)
    for x in range(1, 15, 2):
        t.vline(x, 1, 13, CONC)      # 波板
    t.rect(1, 1, 14, 1, CONC)
    t.rect(1, 13, 14, 1, DUSK)
    t.frame(0, 0, S, 15, SUMI)
    t.rect(4, 5, 8, 6, FOG)          # 下の車の影が透ける
    t.dither_sparse(4, 5, 8, 6, DUSK)
    t.rect(0, 15, S, 1, DUSK)


def veranda(t, p):
    """ベランダ：手すり壁と物干し、室外機"""
    base(t, p, FOG, 0.04)
    t.rect(0, 0, S, 6, CONC)         # 壁（上階）
    t.hline(6, 0, S - 1, DUSK)
    t.rect(0, 7, S, 2, FOG)          # 手すり
    t.hline(7, 0, S - 1, BONE)
    t.rect(0, 9, S, 6, DUSK)         # 手すり壁
    for x in range(1, S, 3):
        t.vline(x, 9, 14, FOG)
    t.rect(11, 2, 4, 4, CONC)        # 室外機
    t.frame(11, 2, 4, 4, DUSK)
    t.px(12, 3, DUSK)
    t.hline(4, 1, 9, CONC)           # 物干し竿
    t.px(3, 5, BONE)                 # 洗濯物
    t.px(6, 5, BONE)
    t.hline(15, 0, S - 1, SUMI)


def laundry(t, p):
    """物干し：T 字の物干し台と竿、干したままの布"""
    base(t, p, OCHRE, 0.05)
    for x in (2, 13):
        t.rect(x, 5, 1, 11, FOG)
        t.px(x, 15, SUMI)
        t.hline(5, x - 1, x + 1, FOG)
    t.hline(6, 1, 14, CONC)          # 竿
    t.hline(9, 1, 14, CONC)
    for (x, w, c) in [(4, 3, BONE), (8, 2, FOG), (11, 2, BONE)]:
        t.rect(x, 7, w, 4, c)
        t.px(x + w - 1, 10, dk(c))
    t.px(5, 12, BONE)                # 落ちた洗濯ばさみ


def sandbox_swing(t, p):
    """ブランコ・砂場：鉄の門型フレームと 2 つの座板、砂場の縁"""
    base(t, p, OCHRE, 0.08)
    t.frame(0, 10, S, 6, FOG)        # 砂場の縁
    t.hline(10, 0, S - 1, CONC)
    t.rect(1, 1, 14, 1, FOG)         # 上桁
    t.hline(0, 1, 14, CONC)
    line(t, 2, 2, 1, 9, FOG)
    line(t, 13, 2, 14, 9, FOG)
    for x in (5, 10):
        t.vline(x, 2, 6, CONC)       # 鎖
        t.rect(x - 1, 7, 3, 1, RUST_D)  # 座板
    t.px(7, 13, RUST)                # 忘れられたスコップ


def viewpoint_fence(t, p):
    """展望所の柵：丸太の柵。向こうは夜の谷"""
    t.fill(NIGHT)
    t.noise(DEEP, 0.15, 0, 0, S, 8, k=1)
    for i in range(6):
        x = int(t.rand(i, 0) * S)
        t.px(x, int(t.rand(i, 1) * 6), GLOW if i % 2 else FLUO)  # 谷の灯り
    t.rect(0, 8, S, 8, MOSS)         # 足元の草
    t.noise(GREEN, 0.2, 0, 8, S, 8, k=2)
    for x in (1, 8, 14):
        t.rect(x, 4, 2, 12, RUST_D)
        t.vline(x, 4, 15, RUST)
    t.rect(0, 6, S, 2, RUST_D)
    t.hline(6, 0, S - 1, RUST)
    t.rect(0, 11, S, 2, RUST_D)
    t.hline(11, 0, S - 1, RUST)


def tamagaki(t, p):
    """玉垣：石の柵。柱と貫"""
    base(t, p, GREEN)
    for x in range(0, S, 5):
        t.rect(x, 3, 2, 13, CONC)
        t.vline(x, 3, 15, BONE)
        t.px(x, 2, CONC)
        t.px(x + 1, 2, CONC)
    t.rect(0, 6, S, 2, CONC)
    t.hline(6, 0, S - 1, BONE)
    t.rect(0, 11, S, 2, CONC)
    t.hline(11, 0, S - 1, BONE)
    t.hline(8, 0, S - 1, FOG)
    t.hline(13, 0, S - 1, FOG)
    t.noise(MOSS, 0.06, 0, 8, S, 8, k=3)


def ema(t, p):
    """絵馬掛け：木の枠に絵馬が並ぶ"""
    base(t, p, FOG)
    t.rect(1, 1, 14, 1, RUST_D)
    t.rect(0, 0, S, 1, RUST)
    t.rect(1, 2, 1, 14, RUST_D)
    t.rect(14, 2, 1, 14, RUST_D)
    t.hline(4, 2, 13, RUST)
    t.hline(9, 2, 13, RUST)
    for row, y in enumerate((5, 10)):
        for x in range(2 + row, 13, 4):
            t.rect(x, y, 3, 3, OCHRE)
            t.px(x + 1, y, RUST_D)
            t.px(x, y, BONE)
            t.px(x + 1, y + 2, RUST_D if (x + row) % 2 else RED)
    t.hline(15, 1, 14, SUMI)


def gravestones(t, p):
    """墓石：高さの違う 3 基、台座、花立て"""
    base(t, p, DUSK)
    shadow(t, 8, 15, 7, 1.3)
    for (x, top, w) in [(1, 5, 4), (6, 2, 4), (11, 6, 4)]:
        t.rect(x, top, w, 14 - top, CONC)
        t.vline(x, top, 13, BONE)
        t.vline(x + w - 1, top + 1, 13, FOG)
        t.hline(top, x, x + w - 1, BONE)
        for y in range(top + 2, 12, 3):
            t.px(x + 1, y, SUMI)
            t.px(x + 2, y, SUMI)
        t.rect(x - 1, 13, w + 2, 2, FOG)
        t.hline(15, x - 1, x + w, SUMI)
        t.noise(MOSS, PF(p, "moss_density", 0.1), x, 8, w, 6, k=x)
    t.px(5, 12, GREEN)               # 花立ての緑
    t.px(10, 12, GREEN)


def stone_marker(t, p):
    """石の道標：古い石柱に彫り文字"""
    base(t, p, DUSK)
    shadow(t, 8, 15, 4, 1.2)
    t.rect(6, 1, 4, 13, CONC)
    t.vline(6, 1, 13, BONE)
    t.vline(9, 2, 13, FOG)
    t.hline(1, 6, 9, BONE)
    t.px(6, 0, CONC)
    t.px(9, 0, CONC)
    for y in (3, 5, 7, 9, 11):
        t.px(7, y, SUMI)
        t.px(8, y + 1 if y < 11 else y, SUMI)
    t.rect(4, 14, 8, 2, FOG)
    t.hline(15, 4, 11, SUMI)
    t.noise(MOSS, 0.12, 6, 8, 4, 6, k=2)
    t.outline([CONC, BONE, FOG], SUMI)


def stone_pillar(t, p):
    """石柱：畑の境の四角い石柱"""
    base(t, p, GREEN)
    shadow(t, 8, 15, 4, 1.2)
    t.rect(5, 2, 6, 12, FOG)
    t.vline(5, 2, 13, CONC)
    t.hline(2, 5, 10, CONC)
    t.vline(10, 3, 13, DUSK)
    t.rect(4, 14, 8, 2, DUSK)
    t.noise(MOSS, 0.1, 5, 9, 6, 5, k=2)
    t.outline([FOG, CONC, DUSK], SUMI)


def monument(t, p):
    """記念碑：黒い御影石の碑と台座、金の文字"""
    base(t, p, CONC, 0.04)
    shadow(t, 8, 15, 7, 1.3)
    t.rect(2, 12, 12, 3, FOG)
    t.hline(12, 2, 13, BONE)
    t.hline(15, 2, 13, SUMI)
    t.rect(3, 2, 10, 10, DEEP)
    t.vline(3, 2, 11, DUSK)
    t.hline(2, 3, 12, DUSK)
    t.rect(4, 1, 8, 1, DEEP)
    for y in range(4, 10, 2):
        t.hline(y, 5, 5 + int(t.rand(y, 0) * 5) + 2, OCHRE)
    t.outline([DEEP, DUSK, OCHRE], SUMI)


def stele(t, p):
    """石碑：自然石の碑、彫り文字"""
    base(t, p, GREEN)
    shadow(t, 8, 15, 6, 1.3)
    t.ellipse(8, 8, 5.5, 7, CONC)
    t.ellipse(6.5, 6, 3, 4, lt(CONC))
    t.rect(4, 3, 8, 1, CONC)
    for y in range(4, 12, 2):
        t.px(7, y, SUMI)
        t.px(9, y + 1, SUMI)
    t.rect(3, 14, 10, 2, FOG)
    t.noise(MOSS, 0.12, 3, 9, 10, 5, k=2)
    t.outline([CONC, BONE, FOG], SUMI)


def water_gauge(t, p):
    """水位標：河岸の白い量水標、赤の目盛と数字"""
    base(t, p, FOG)
    t.rect(6, 0, 4, 15, BONE)
    t.vline(6, 0, 14, CONC)
    for y in range(1, 15, 2):
        t.hline(y, 7, 8 if y % 4 == 1 else 9, RED)
    t.px(7, 4, SUMI)
    t.px(7, 10, SUMI)
    t.rect(5, 15, 6, 1, DUSK)
    t.outline([BONE, CONC, RED], SUMI)


def cow_statue(t, p):
    """石像（牛）：臥牛の石像と台座"""
    base(t, p, DUSK)
    shadow(t, 8, 15, 7, 1.3)
    t.rect(1, 12, 14, 3, FOG)
    t.hline(12, 1, 14, CONC)
    t.hline(15, 1, 14, SUMI)
    t.ellipse(8.5, 8.5, 6, 3.5, CONC)      # 胴
    t.ellipse(3.5, 6.5, 2.5, 2.5, CONC)    # 頭
    t.ellipse(8, 7, 4, 2, lt(CONC))
    t.px(2, 5, SUMI)                       # 目
    t.px(1, 4, FOG)                        # 角
    t.px(5, 4, FOG)
    t.rect(4, 11, 9, 1, FOG)               # 脚の折り
    t.outline([CONC, BONE, FOG], SUMI)
    t.px(3, 9, RED)                        # 赤い前掛け


def elephant_slide(t, p):
    """象の滑り台：コンクリートの象。鼻が滑り台"""
    base(t, p, OCHRE, 0.08)
    shadow(t, 8, 15, 7, 1.3)
    t.ellipse(6, 7, 5, 4, CONC)            # 胴
    t.ellipse(4, 4, 2.5, 2.5, CONC)        # 頭
    t.rect(8, 8, 7, 2, CONC)               # 鼻（滑り台）
    t.rect(13, 10, 2, 5, CONC)
    t.hline(8, 8, 14, BONE)
    t.rect(2, 11, 2, 4, CONC)              # 脚
    t.rect(7, 11, 2, 4, CONC)
    t.px(3, 3, SUMI)                       # 目
    t.px(1, 5, FOG)                        # 耳
    t.rect(8, 4, 2, 3, FOG)                # 階段（背中）
    t.outline([CONC, BONE, FOG], SUMI)


def masks(t, p):
    """積まれた面：古い面が 3 つ重なる。黄土の顔、暗い目"""
    base(t, p, NIGHT)
    for i, (x, y) in enumerate([(3, 9), (7, 5), (2, 1)]):
        t.ellipse(x + 4, y + 2.5, 4.5, 2.8, OCHRE)
        t.hline(y, x + 2, x + 6, BONE)
        t.px(x + 1, y + 1, BONE)
        t.px(x + 2, y + 2, SUMI)
        t.px(x + 3, y + 2, SUMI)
        t.px(x + 5, y + 2, SUMI)
        t.px(x + 6, y + 2, SUMI)
        t.hline(y + 4, x + 2, x + 6, RUST)
        t.px(x + 4, y + 3, RUST)
        t.outline([OCHRE, BONE], SUMI)


def torii(t, p):
    """鳥居：朱（錆色）の柱と笠木、貫、額束"""
    base(t, p, P(p, "ground", DUSK))
    wood = P(p, "wood", RUST)
    t.rect(3, 4, 2, 12, wood)
    t.rect(11, 4, 2, 12, wood)
    t.vline(3, 4, 15, lt(wood))
    t.vline(12, 4, 15, dk(wood))
    t.rect(0, 1, S, 2, wood)         # 笠木
    t.hline(0, 1, 14, lt(wood))
    t.hline(2, 0, 15, dk(wood))
    t.rect(1, 5, 14, 1, wood)        # 貫
    t.hline(6, 1, 14, dk(wood))
    t.rect(7, 3, 2, 2, BONE)         # 額
    t.px(7, 3, wood)
    t.rect(2, 15, 4, 1, SUMI)
    t.rect(10, 15, 4, 1, SUMI)
    t.outline([wood, lt(wood), dk(wood), BONE], SUMI)


def shrine(t, p):
    """式内社の社殿・鳥居：小さな社殿を正面から。屋根、扉、賽銭箱"""
    base(t, p, FOG)
    t.rect(0, 0, S, 4, RUST_D)       # 屋根
    t.hline(0, 1, 14, RUST)
    t.hline(3, 0, S - 1, SUMI)
    t.px(7, 0, OCHRE)
    t.px(8, 0, OCHRE)
    t.rect(2, 4, 12, 8, RUST)        # 壁
    t.vline(2, 4, 11, OCHRE)
    t.vline(13, 4, 11, RUST_D)
    t.rect(6, 5, 4, 7, RUST_D)       # 扉
    t.vline(8, 5, 11, SUMI)
    t.px(7, 8, OCHRE)
    t.rect(4, 5, 1, 6, RUST_D)       # 格子
    t.rect(11, 5, 1, 6, RUST_D)
    t.rect(1, 12, 14, 1, CONC)       # 縁
    t.rect(5, 13, 6, 2, RUST_D)      # 賽銭箱
    t.hline(13, 5, 10, RUST)
    t.hline(15, 0, S - 1, DUSK)


def temple_gate(t, p):
    """山門：二本の太い柱と瓦屋根、奥は暗い。柱に扁額"""
    base(t, p, DUSK)
    t.rect(4, 4, 8, 12, NIGHT)       # 門の内側
    t.dither_sparse(4, 6, 8, 10, DEEP)
    t.rect(0, 4, 3, 12, RUST_D)      # 柱
    t.rect(13, 4, 3, 12, RUST_D)
    t.vline(0, 4, 15, RUST)
    t.vline(13, 4, 15, RUST)
    t.vline(2, 4, 15, SUMI)
    t.vline(15, 4, 15, SUMI)
    t.rect(0, 0, S, 4, NIGHT)        # 瓦屋根
    for y in range(0, 4, 2):
        t.hline(y, 0, S - 1, DEEP)
        for x in range(0, S, 4):
            t.px(x + (y // 2) * 2, y + 1, FOG)
    t.hline(4, 0, S - 1, FOG)
    t.rect(6, 5, 4, 2, OCHRE)        # 扁額
    t.px(7, 6, SUMI)
    t.px(8, 6, SUMI)
    t.rect(3, 14, 10, 1, CONC)       # 敷居
    t.hline(15, 3, 12, SUMI)


def school_gate(t, p):
    """校門（鉄）：石の門柱と鉄の門扉（閉）"""
    base(t, p, DUSK)
    t.rect(0, 1, 3, 15, CONC)        # 門柱
    t.rect(13, 1, 3, 15, CONC)
    t.vline(0, 1, 15, BONE)
    t.vline(13, 1, 15, BONE)
    t.vline(2, 1, 15, FOG)
    t.vline(15, 1, 15, FOG)
    t.rect(0, 0, 3, 1, FOG)
    t.rect(13, 0, 3, 1, FOG)
    t.px(1, 3, OCHRE)                # 表札
    t.px(1, 4, OCHRE)
    for x in range(4, 12, 2):
        t.vline(x, 3, 13, FOG)       # 鉄の縦棒
        t.px(x, 3, CONC)
    t.hline(5, 3, 12, CONC)          # 横桟
    t.hline(11, 3, 12, CONC)
    t.rect(7, 7, 2, 2, SUMI)         # 錠
    t.hline(15, 3, 12, SUMI)


def iron_gate(t, p):
    """門扉：住宅の低い門扉と門柱、表札と灯"""
    base(t, p, DUSK)
    t.rect(0, 2, 3, 14, FOG)
    t.rect(13, 2, 3, 14, FOG)
    t.vline(0, 2, 15, CONC)
    t.vline(13, 2, 15, CONC)
    t.rect(0, 1, 3, 1, CONC)
    t.rect(13, 1, 3, 1, CONC)
    t.px(14, 3, GLOW)                # 門灯
    t.px(1, 4, BONE)                 # 表札
    t.px(1, 5, BONE)
    for x in range(4, 12, 2):
        t.vline(x, 6, 13, CONC)
        t.px(x, 5, FOG)
    t.hline(8, 3, 12, FOG)
    t.hline(13, 3, 12, FOG)
    t.rect(7, 9, 2, 2, SUMI)
    t.hline(15, 3, 12, SUMI)


def tunnel_arch(t, p):
    """隧道アーチ：石積みの坑口、中は真っ暗"""
    t.fill(FOG)
    for y in range(S):
        for x in range(S):
            if (x + (y // 2) * 2) % 4 == 0 and y % 2 == 0:
                t.px(x, y, DUSK)
    t.noise(DUSK, 0.1, k=2)
    for y in range(3, S):
        w = 5 if y > 6 else (2 + y - 3 + 1)
        t.hline(y, 8 - w, 7 + w, SUMI)
    for y in range(2, S):            # アーチ縁石
        w = 5 if y > 6 else (2 + y - 3 + 1)
        t.px(8 - w - 1, y, CONC)
        t.px(7 + w + 1, y, CONC)
    t.hline(2, 5, 10, CONC)
    t.rect(5, 12, 6, 4, NIGHT)       # 奥に僅かに床
    t.px(7, 0, OCHRE)                # 扁額
    t.px(8, 0, OCHRE)


def hen_house(t, p):
    """飼育小屋（金網）：金網の小屋、中に止まり木と餌箱"""
    base(t, p, RUST_D, 0.08)
    t.rect(0, 0, S, 3, FOG)          # 屋根
    t.hline(0, 0, S - 1, CONC)
    t.hline(3, 0, S - 1, SUMI)
    t.rect(1, 4, 14, 11, RUST_D)
    for y in range(4, 15):
        for x in range(1, 15):
            if (x + y) % 3 == 0 or (x - y) % 3 == 0:
                t.px(x, y, CONC)
    t.rect(3, 9, 10, 1, RUST)        # 止まり木
    t.rect(2, 12, 4, 2, OCHRE)       # 餌箱
    t.frame(1, 4, 14, 11, FOG)
    t.vline(8, 4, 14, FOG)
    t.hline(15, 0, S - 1, SUMI)


def garbage_net(t, p):
    """ゴミ集積所ネット：緑のネットの下にゴミ袋"""
    base(t, p, CONC, 0.04)
    for (x, y, r) in [(4, 10, 3), (9, 9, 3), (7, 12, 2.5), (12, 12, 2)]:
        t.disc(x, y, r, FOG)
        t.px(x - 1, y - 1, CONC)
    for y in range(3, S):
        for x in range(S):
            if (x + y) % 3 == 0 or (x - y) % 3 == 0:
                t.px(x, y, GREEN)
    t.hline(3, 0, S - 1, GREEN)
    t.hline(2, 0, S - 1, GREEN_L)
    t.rect(6, 0, 4, 2, OCHRE)        # 収集日の札
    t.px(7, 1, SUMI)


def backnet(t, p):
    """バックネット（金網）：高い金網と鉄柱、土のグラウンド"""
    ground(t, {"base": RUST, "speck": OCHRE, "density": 0.1})
    for y in range(S):
        for x in range(S):
            if (x + y) % 3 == 0 or (x - y) % 3 == 0:
                t.px(x, y, CONC)
    for x in (0, 8, 15):
        t.vline(x, 0, S - 1, FOG)
        t.px(x, 0, BONE)
    t.hline(0, 0, S - 1, FOG)
    t.hline(15, 0, S - 1, DUSK)


def footbridge(t, p):
    """縞鋼板の歩道橋：滑り止めの縞、手すり"""
    t.fill(FOG)
    for y in range(S):
        for x in range(S):
            if (x + y) % 4 == 0:
                t.px(x, y, CONC)
            elif (x + y) % 4 == 2:
                t.px(x, y, DUSK)
    t.rect(0, 0, 2, S, CONC)
    t.rect(14, 0, 2, S, CONC)
    t.vline(0, 0, S - 1, BONE)
    t.vline(15, 0, S - 1, DUSK)
    t.noise(RUST, 0.04, 2, 0, 12, S, k=2)


def shop_door(t, p):
    """店舗の木製戸：格子ガラスの引き戸、暖簾の痕"""
    t.fill(RUST_D)
    for x in range(0, S, 4):
        t.vline(x, 0, S - 1, SUMI)
        t.vline(x + 1, 0, S - 1, RUST)
    t.rect(1, 1, 14, 9, RUST_D)      # 上部
    for col in range(2):
        for row in range(2):
            x, y = 2 + col * 7, 2 + row * 4
            t.rect(x, y, 5, 3, DEEP)
            t.px(x, y, DUSK)
            t.px(x + 1, y, DUSK)
    t.vline(8, 1, 15, SUMI)          # 戸の合わせ
    t.rect(1, 10, 14, 5, RUST)
    t.hline(10, 1, 14, OCHRE)
    t.px(6, 12, OCHRE)               # 引手
    t.px(9, 12, OCHRE)
    t.hline(15, 0, S - 1, SUMI)
    t.frame(0, 0, S, S, SUMI)


def shop_glass(t, p):
    """店舗ガラス面（点灯）：ガラス越しに棚と商品"""
    t.fill(GLOW)
    t.rect(1, 1, 14, 14, BONE)
    for y in (4, 8, 12):
        t.hline(y, 2, 13, OCHRE)     # 棚板
        for x in range(2, 14, 3):
            t.rect(x, y - 2, 2, 2, (RED, FLUO, RUST, DUSK)[(x + y) % 4])
    t.frame(0, 0, S, S, SUMI)
    t.vline(7, 1, 14, CONC)          # 桟
    t.hline(1, 1, 14, GLOW)
    t.px(2, 2, GLOW)                 # 反射
    t.px(3, 2, GLOW)


def glass_door(t, p):
    """ガラス扉（点灯）：公共建築の両開きガラス扉、押し棒"""
    t.fill(GLOW)
    t.checker(1, 1, 14, 14, BONE, 0)
    t.frame(0, 0, S, S, SUMI)
    t.vline(7, 0, S - 1, SUMI)
    t.vline(8, 0, S - 1, SUMI)
    t.hline(9, 1, 6, FOG)            # 押し棒
    t.hline(9, 9, 14, FOG)
    t.rect(1, 1, 6, 1, BONE)
    t.rect(9, 1, 6, 1, BONE)
    t.rect(1, 13, 6, 2, CONC)        # 下枠
    t.rect(9, 13, 6, 2, CONC)


def shutter(t, p):
    """シャッター：スラット。half で下が開き、暗い店内と落書き"""
    t.fill(FOG)
    half = PB(p, "half", False)
    bottom = 9 if half else S
    for y in range(0, bottom, 2):
        t.hline(y, 0, S - 1, DUSK)
        t.hline(y + 1, 0, S - 1, CONC)
    t.noise(RUST, 0.06, 0, 0, S, bottom, k=2)
    t.noise(RUST_D, 0.04, 0, 0, S, bottom, k=3)
    t.vline(0, 0, S - 1, DUSK)
    t.vline(S - 1, 0, S - 1, DUSK)
    if half:
        t.rect(1, bottom, 14, S - bottom, SUMI)
        t.hline(bottom, 1, 14, DUSK)
        t.rect(3, 12, 4, 3, NIGHT)   # 店内の段ボール
        t.rect(9, 13, 3, 2, NIGHT)
        t.px(5, 11, DEEP)
    else:
        t.hline(15, 0, S - 1, SUMI)
        t.px(4, 6, RED)              # 落書き
        t.px(5, 6, RED)
        t.px(5, 7, RED)


def old_window(t, p):
    """旧校舎 窓（木枠）：下見板の壁に木枠の上げ下げ窓、暗いガラス"""
    planks(t, {"base": RUST, "gap": RUST_D, "worn": True}, False)
    t.rect(2, 2, 12, 12, RUST_D)
    t.rect(3, 3, 10, 10, DEEP)
    t.dither_sparse(3, 3, 10, 10, NIGHT)
    t.vline(7, 3, 12, RUST_D)
    t.vline(8, 3, 12, RUST_D)
    t.hline(7, 3, 12, RUST_D)
    t.px(3, 3, DUSK)                 # 反射
    t.px(4, 3, DUSK)
    t.px(9, 8, FOG)
    t.hline(2, 2, 13, OCHRE)
    t.hline(14, 2, 13, SUMI)
    t.rect(1, 14, 14, 1, RUST_D)


def stairwell(t, p, lit):
    """階段室：団地の階段室の窓（縦長）と手すりの影"""
    t.fill(CONC)
    t.noise(FOG, 0.05, k=1)
    for x in range(S):
        if t.rand(x, 0, 2) < 0.3:
            t.vline(x, 0, int(t.rand(x, 1, 2) * 10), FOG)
    t.rect(4, 1, 8, 14, SUMI)
    inner = FLUO if lit else DEEP
    t.rect(5, 2, 6, 12, inner)
    if lit:
        t.rect(5, 2, 3, 3, BONE)
        t.dither_sparse(5, 2, 6, 12, BONE, 1)
        t.vline(5, 5, 13, lt(FLUO))
        line(t, 6, 12, 10, 6, DEEP)  # 階段の影
    else:
        t.dither_sparse(5, 2, 6, 12, NIGHT)
        line(t, 6, 12, 10, 6, DUSK)
    t.hline(7, 5, 10, SUMI)          # 桟
    t.hline(1, 4, 11, FOG)
    t.hline(15, 4, 11, DUSK)


def dagashiya(t, p):
    """駄菓子屋の店先（点灯）：暖簾、ガラス棚の中の色、裸電球"""
    t.fill(RUST)
    t.noise(RUST_D, 0.08, k=1)
    t.rect(0, 0, S, 3, RUST_D)       # 庇
    t.hline(0, 0, S - 1, RUST)
    t.rect(2, 3, 12, 3, OCHRE)       # 暖簾
    t.vline(6, 3, 5, RUST_D)
    t.vline(10, 3, 5, RUST_D)
    t.px(8, 4, GLOW)                 # 裸電球
    t.rect(1, 6, 14, 9, GLOW)        # 店内
    t.rect(2, 7, 12, 7, BONE)
    for y in (8, 11):
        t.hline(y + 1, 3, 12, OCHRE)
        for x in range(3, 13, 2):
            t.px(x, y, (RED, FLUO, RUST, DUSK, GREEN)[(x + y) % 5])
    t.frame(1, 6, 14, 9, SUMI)
    t.hline(15, 0, S - 1, SUMI)


def window_generic(t, p):
    """窓（消灯・点灯）：住宅の壁に引き違い窓。片方が点灯"""
    wall = P(p, "wall", CONC)
    t.fill(wall)
    t.noise(dk(wall), 0.05, k=1)
    t.rect(2, 3, 12, 10, SUMI)
    t.rect(3, 4, 5, 8, GLOW)         # 点灯側
    t.rect(8, 4, 5, 8, DEEP)         # 消灯側
    t.rect(3, 4, 2, 2, BONE)
    t.noise(OCHRE, 0.15, 3, 4, 5, 8, k=2)
    t.dither_sparse(8, 4, 5, 8, NIGHT)
    t.px(8, 4, DUSK)
    t.vline(7, 4, 11, SUMI)
    t.hline(8, 3, 12, SUMI)
    t.hline(2, 2, 13, lt(wall) if wall != BONE else wall)
    t.hline(13, 2, 13, dk(wall))
    t.rect(2, 14, 12, 1, dk(wall))   # 庇の影


def bridge(t, p):
    """橋（桁・欄干・橋灯）：コンクリートの床版と欄干、橋灯（点灯）"""
    t.fill(CONC)
    t.noise(FOG, 0.08, k=1)
    for x in range(0, S, 8):
        t.vline(x, 3, S - 1, FOG)    # 継ぎ目
    t.rect(0, 0, S, 3, FOG)          # 欄干
    t.hline(0, 0, S - 1, BONE)
    t.hline(2, 0, S - 1, DUSK)
    for x in range(1, S, 4):
        t.vline(x, 0, 2, CONC)
    if "glow" in p:
        t.rect(6, 0, 4, 2, GLOW)
        t.px(7, 0, BONE)
        t.px(8, 0, BONE)
        t.px(5, 1, OCHRE)
        t.px(10, 1, OCHRE)
        t.noise(OCHRE, 0.2, 4, 3, 8, 3, k=3)
    t.hline(15, 0, S - 1, DUSK)


def rock(t, p):
    """落石（岩）：ごつごつした岩塊。面の分割と輪郭"""
    base(t, p, P(p, "ground", DUSK))
    shadow(t, 8, 14, 6.5, 1.8)
    t.ellipse(8, 8, 6, 4.5, FOG)
    t.rect(4, 3, 8, 3, FOG)
    t.rect(3, 4, 3, 2, FOG)
    t.ellipse(6, 5.5, 3, 2, CONC)
    t.px(4, 4, BONE)
    line(t, 8, 4, 11, 9, DUSK)       # 割れ目
    line(t, 5, 8, 8, 12, DUSK)
    for y in range(8, 13):
        for x in range(8, 14):
            if t.get(x, y) == FOG and (x + y) % 2 == 0:
                t.px(x, y, DUSK)
    t.rect(10, 11, 4, 2, DEEP)
    t.outline([FOG, CONC, BONE, DUSK, DEEP], SUMI)


def mossy_rock(t, p):
    """苔むした石：苔に覆われた丸い石"""
    base(t, p, MOSS)
    shadow(t, 8, 14, 6, 1.6)
    t.ellipse(8, 8, 6, 4.5, GREEN)
    t.rect(4, 3, 8, 3, GREEN)
    t.ellipse(6, 5.5, 3, 2, GREEN_L)
    t.px(4, 4, OCHRE)
    for y in range(3, 13):
        for x in range(2, 14):
            if t.get(x, y) in (GREEN, GREEN_L) and t.rand(x, y, 3) < 0.15:
                t.px(x, y, FOG)       # 苔の切れ目から石
    t.rect(9, 10, 5, 2, MOSS)
    t.outline([GREEN, GREEN_L, FOG, OCHRE, MOSS], SUMI)


def spring(t, p):
    """湧水：岩の間から湧く小さな水面、波紋、光"""
    base(t, p, MOSS)
    for (x, y, r) in [(3, 3, 2.5), (13, 4, 2.5), (2, 12, 2), (13, 13, 2.5)]:
        t.disc(x, y, r, DUSK)
        t.px(x - 1, y - 1, FOG)
    t.ellipse(8, 8.5, 5, 3.5, DEEP)
    t.ellipse(8, 8.5, 3, 2, DUSK)
    t.px(7, 8, FOG)
    t.px(8, 8, FOG)
    t.px(9, 9, DEEP)
    t.px(6, 7, BONE)
    t.hline(11, 5, 10, DUSK)
    t.outline([DEEP, DUSK], NIGHT)
    t.noise(GREEN, 0.1, k=4)


def crack(t, p):
    """裂け目（暗）：岩壁の黒い縦の亀裂。縁の岩の面"""
    from paint_atlas import cliff
    cliff(t, {"base": DEEP, "dark": NIGHT, "hi": FOG})
    x = 6
    for y in range(S):
        r = t.rand(x, y)
        x = max(3, min(10, x + (1 if r > 0.66 else (-1 if r < 0.33 else 0))))
        w = 2 + (2 if 4 < y < 12 else 0)
        t.rect(x, y, w, 1, SUMI)
        t.px(x - 1, y, FOG)
        t.px(x + w, y, NIGHT)
        if 6 < y < 10:
            t.px(x + 1, y, NIGHT if t.rand(y, x, 2) < 0.5 else SUMI)


def cliff_wall(t, p):
    """谷の岩壁：層になった岩、割れ目、湿った暗さ"""
    t.fill(DEEP)
    for y in range(S):
        band = (y // 3) % 3
        c = (DEEP, DUSK, NIGHT)[band]
        t.hline(y, 0, S - 1, c)
        for x in range(S):
            if t.rand(x, y, 1) < 0.12:
                t.px(x, y, lt(c) if lt(c) != BONE else c)
    for x in [0, 6, 11]:
        for y in range(S):
            if t.rand(x, y, 2) < 0.6:
                t.px(x + int(t.rand(y, x, 3) * 2), y, NIGHT)
    for y in (2, 8, 13):
        x0 = int(t.rand(0, y) * 5)
        t.hline(y, x0, x0 + 5 + int(t.rand(1, y) * 6), SUMI)
        t.hline(y + 1, x0 + 1, x0 + 3, FOG)
    t.noise(MOSS, 0.05, k=5)


def cliff_impassable(t, p):
    """崖（通行不能）：土の崖、根がむき出し"""
    t.fill(RUST_D)
    for y in range(S):
        c = (RUST_D, RUST, RUST_D, SUMI)[(y // 2) % 4]
        for x in range(S):
            if t.rand(x, y, 1) < 0.5:
                t.px(x, y, c)
    for x in (2, 7, 12):
        t.vline(x, 0, S - 1, SUMI)
        t.vline(x + 1, 2, 12, RUST)  # 根
    t.hline(0, 0, S - 1, GREEN)      # 上の草
    t.noise(GREEN_L, 0.4, 0, 0, S, 1, k=2)
    t.noise(OCHRE, 0.06, k=3)


def moat(t, p):
    """空堀（底・壁）：草の斜面が落ち込む深い堀"""
    t.fill(GREEN)
    t.noise(MOSS, 0.15, k=1)
    for i in range(5):
        c = (GREEN, MOSS, DUSK, DEEP, NIGHT)[i]
        t.rect(i, i, S - 2 * i, S - 2 * i, c)
        for x in range(i, S - i):
            if t.rand(x, i, 2) < 0.3:
                t.px(x, i, (GREEN_L, GREEN, FOG, DUSK, DEEP)[i])
    t.rect(5, 5, 6, 6, SUMI)
    t.dither_sparse(5, 5, 6, 6, NIGHT)


def mound(t, p):
    """古墳（盛土・石室口）：草に覆われた円墳、石組みの入口"""
    grass(t, {"base": GREEN, "blade": GREEN_L})
    t.ellipse(8, 8, 7.5, 6, GREEN)
    t.ellipse(8, 7, 6, 4.5, GREEN_L)
    t.ellipse(7, 5.5, 3.5, 2.2, lt(GREEN_L))
    for y in range(S):
        for x in range(S):
            if t.get(x, y) in (GREEN_L, OCHRE) and t.rand(x, y, 3) < 0.2:
                t.px(x, y, GREEN)
    t.outline([GREEN_L, OCHRE], MOSS)
    t.rect(5, 9, 6, 6, FOG)          # 石組み
    t.rect(6, 10, 4, 5, SUMI)
    t.hline(9, 5, 10, CONC)
    t.px(5, 10, CONC)
    t.px(10, 12, DUSK)


def tin_warehouse(t, p):
    """倉庫（トタン）：波板の壁、錆の垂れ、引き戸"""
    t.fill(FOG)
    for x in range(0, S, 2):
        t.vline(x, 0, S - 1, CONC)
    t.rect(0, 0, S, 2, DUSK)         # 軒
    t.hline(0, 0, S - 1, FOG)
    for x in (3, 9, 13):
        length = 3 + int(t.rand(x, 0) * 8)
        t.vline(x, 2, 2 + length, RUST)
        t.vline(x + 1, 2, 2 + length // 2, RUST_D)
    t.rect(5, 8, 6, 8, DUSK)         # 引き戸
    t.frame(5, 8, 6, 8, RUST_D)
    t.vline(8, 9, 14, RUST_D)
    t.px(7, 12, OCHRE)
    t.hline(15, 0, S - 1, SUMI)


def farm_shed(t, p):
    """農機具小屋（トタン・板）：板壁とトタン屋根、開いた戸口"""
    planks(t, {"base": RUST, "gap": RUST_D, "width": 3}, False)
    t.rect(0, 0, S, 4, FOG)          # トタン屋根
    for x in range(0, S, 2):
        t.vline(x, 0, 3, CONC)
    t.hline(4, 0, S - 1, SUMI)
    t.noise(RUST, 0.15, 0, 0, S, 4, k=2)
    t.rect(6, 7, 5, 9, SUMI)         # 戸口
    t.vline(6, 7, 15, RUST_D)
    t.rect(7, 12, 3, 3, NIGHT)
    t.px(9, 9, OCHRE)                # 中の道具
    t.rect(12, 7, 3, 3, DEEP)        # 小窓
    t.hline(15, 0, S - 1, SUMI)


def gym_wall(t, p):
    """体育館の壁：大きなコンクリートパネルと高窓の列"""
    t.fill(FOG)
    t.noise(CONC, 0.04, k=1)
    for y in (5, 11):
        t.hline(y, 0, S - 1, DUSK)
    for x in range(0, S, 8):
        t.vline(x, 0, S - 1, DUSK)
    for x in range(1, S, 4):
        t.rect(x, 1, 3, 3, DEEP)     # 高窓
        t.px(x, 1, DUSK)
    t.hline(15, 0, S - 1, DUSK)


def underpass_pier(t, p):
    """高架橋脚：太いコンクリートの脚、雨染み、番号"""
    t.fill(CONC)
    t.noise(FOG, 0.05, k=1)
    t.vline(0, 0, S - 1, BONE)
    t.vline(15, 0, S - 1, DUSK)
    t.vline(14, 0, S - 1, FOG)
    for x in (2, 5, 9, 12):
        t.vline(x, 0, 2 + int(t.rand(x, 0) * 12), FOG)
    t.hline(3, 1, 14, FOG)           # 打ち継ぎ目
    t.hline(11, 1, 14, FOG)
    t.px(7, 7, RED)                  # 番号札
    t.px(8, 7, BONE)
    t.rect(7, 7, 2, 1, BONE)
    t.hline(15, 0, S - 1, DUSK)


def sound_wall(t, p, far=False):
    """防音壁：パネルの継ぎ目、上端の吸音材、汚れ"""
    b = DUSK if far else FOG
    t.fill(b)
    t.noise(lt(b), 0.04, k=1)
    for x in range(0, S, 4):
        t.vline(x, 0, S - 1, dk(b))
    t.rect(0, 0, S, 2, dk(b))
    t.hline(0, 0, S - 1, lt(b))
    for x in range(1, S, 4):
        t.vline(x, 3, 3 + int(t.rand(x, 0) * 10), dk(b))
    t.hline(15, 0, S - 1, dk(dk(b)) if dk(b) != SUMI else SUMI)


def wet_tunnel_wall(t, p):
    """隧道内壁（湿）：濡れたコンクリートの壁、水の筋、光の反射"""
    t.fill(DUSK)
    t.noise(DEEP, 0.15, k=1)
    for x in range(S):
        if t.rand(x, 0, 2) < 0.5:
            t.vline(x, 0, S - 1, DEEP)
    for x in (3, 8, 12):
        t.vline(x, int(t.rand(x, 1) * 6), S - 1, NIGHT)
        t.px(x + 1, 14, FOG)
    for i in range(6):
        x = int(t.rand(i, 5) * S)
        y = int(t.rand(i, 6) * S)
        t.px(x, y, FOG)              # 水滴の反射
    t.hline(15, 0, S - 1, SUMI)


def bicycle_roof(t, p):
    """駐輪場の屋根：上から見た波板の屋根（青灰）"""
    t.fill(FOG)
    for y in range(0, S, 2):
        t.hline(y, 0, S - 1, CONC)
    t.noise(DUSK, 0.08, k=1)
    t.rect(0, 0, S, 1, BONE)
    t.rect(0, 15, S, 1, DUSK)
    t.vline(0, 0, S - 1, DUSK)
    t.vline(15, 0, S - 1, SUMI)
    t.vline(7, 0, S - 1, DUSK)       # 継ぎ目


def bench(t, p):
    """ベンチ：公園の木のベンチ（上から）。背もたれ、座板 3 枚、脚"""
    base(t, p, P(p, "ground", DUSK))
    wood = P(p, "wood", RUST)
    shadow(t, 8, 14, 7, 1.3)
    t.rect(1, 3, 14, 2, wood)        # 背
    t.hline(3, 1, 14, lt(wood))
    t.hline(5, 1, 14, dk(wood))
    for y in (7, 9, 11):
        t.rect(1, y, 14, 1, wood)
        t.hline(y, 1, 14, wood if y > 7 else lt(wood))
        t.hline(y + 1, 1, 14, dk(wood))
    t.rect(2, 12, 2, 3, DUSK)
    t.rect(12, 12, 2, 3, DUSK)
    t.outline([wood, lt(wood), dk(wood)], SUMI)


SPECIAL = {
    "ガードレール": guardrail, "バリケード": barricade, "フェンス（施錠）": fence_locked, "側溝": drain, "側溝・グレーチング": grating,
    "駐車車両（暗）": parking_car, "自販機正面": vending, "街灯（柱・光源）": streetlamp, "街灯（均等）": streetlamp, "常夜灯": stone_lantern,
    "蛍光灯": fluorescent, "蛍光灯（バス停）": fluorescent, "非常灯": emergency_light, "交番の赤色灯": police_light,
    "公衆電話ボックス": phone_booth, "待合ベンチ": bus_bench, "時刻表看板": timetable, "商店の看板（褪せ）": shop_sign, "店舗看板（無地）": plain_sign,
    "掲示板": bulletin, "看板（地図）": map_board, "案内板": info_board, "電柱・電線": utility_pole, "電気柵ポール": fence_pole,
    "時計塔": clock_tower, "給水塔": water_tower, "火の見櫓": fire_tower, "照明塔": flood_light, "集合ポスト": postboxes, "厨子": zushi,
    "教室の机・椅子": desk_chair, "黒板": blackboard, "百葉箱": weather_box, "朝礼台": platform, "ダッグアウト": dugout,
    "自転車置き場": bike_shed, "カーポート": carport, "ベランダ": veranda, "物干し": laundry, "ブランコ・砂場": sandbox_swing,
    "展望所の柵": viewpoint_fence, "玉垣": tamagaki, "絵馬掛け": ema, "墓石（複数形）": gravestones, "石の道標": stone_marker,
    "石柱": stone_pillar, "記念碑": monument, "石碑": stele, "水位標": water_gauge, "石像（牛）": cow_statue, "象の滑り台": elephant_slide,
    "積まれた面": masks, "鳥居": torii, "式内社の社殿・鳥居": shrine, "山門（木・瓦）": temple_gate, "寺の山門": temple_gate,
    "校門（鉄）": school_gate, "門扉": iron_gate, "隧道アーチ": tunnel_arch, "飼育小屋（金網）": hen_house, "ゴミ集積所ネット": garbage_net,
    "バックネット（金網）": backnet, "縞鋼板の歩道橋": footbridge, "店舗の木製戸": shop_door, "店舗ガラス面（点灯）": shop_glass,
    "ガラス扉（点灯）": glass_door, "シャッター（下・半開き）": shutter, "旧校舎 窓（木枠）": old_window,
    "階段室（点灯・消灯）": lambda t, p: stairwell(t, p, True), "階段室（消灯）": lambda t, p: stairwell(t, p, False),
    "駄菓子屋の店先（点灯）": dagashiya, "窓（消灯・点灯）": window_generic, "橋（桁・欄干・橋灯）": bridge, "落石（岩）": rock,
    "苔むした石": mossy_rock, "湧水（水面・小）": spring, "裂け目（暗）": crack, "谷の岩壁": cliff_wall, "崖（通行不能）": cliff_impassable,
    "空堀（底・壁）": moat, "古墳（盛土・石室口）": mound, "倉庫（トタン）": tin_warehouse, "農機具小屋（トタン・板）": farm_shed,
    "体育館の壁": gym_wall, "高架橋脚": underpass_pier, "防音壁": lambda t, p: sound_wall(t, p, False), "防音壁（遠景）": lambda t, p: sound_wall(t, p, True),
    "隧道内壁（湿）": wet_tunnel_wall, "駐輪場の屋根": bicycle_roof, "ベンチ": bench,
}


def shrub(t, p):
    """植栽（低木）：刈り込んだ丸い低木が 2 つ。幹は見えない。並べると生け垣の列になる"""
    base(t, p, P(p, "ground", CONC), 0.04)
    for (cx, cy, r) in [(4.5, 9, 4.2), (11.5, 7, 4.5)]:
        shadow(t, cx + 1, cy + r - 0.5, r, 1.5)
    for (cx, cy, r) in [(4.5, 9, 4.2), (11.5, 7, 4.5)]:
        t.disc(cx, cy, r, MOSS)
        t.disc(cx - 0.5, cy - 0.8, r - 1.2, GREEN)
        t.disc(cx - 1.5, cy - 2, r - 2.6, GREEN_L)
    for y in range(S):
        for x in range(S):
            c = t.get(x, y)
            if c in (GREEN, GREEN_L, MOSS) and t.rand(x, y, 3) < 0.2:
                t.px(x, y, {GREEN: MOSS, GREEN_L: GREEN, MOSS: GREEN}[c])
    t.outline([MOSS, GREEN, GREEN_L], SUMI)


def hedge(t, p):
    """生垣：四角く刈った生け垣を上から。上面が明るく側面が暗い。左右に続く"""
    t.fill(MOSS)
    t.rect(0, 2, S, 9, GREEN)        # 上面
    t.rect(0, 11, S, 4, MOSS)        # 側面
    t.hline(15, 0, S - 1, SUMI)
    t.hline(2, 0, S - 1, GREEN_L)
    t.hline(1, 0, S - 1, SUMI)
    t.hline(0, 0, S - 1, MOSS)
    for y in range(2, 11):
        for x in range(S):
            r = t.rand(x, y, 2)
            if r < 0.18:
                t.px(x, y, GREEN_L)
            elif r < 0.30:
                t.px(x, y, MOSS)
    for y in range(11, 15):
        for x in range(S):
            if t.rand(x, y, 4) < 0.15:
                t.px(x, y, GREEN)
    t.px(3, 6, OCHRE)                # 枯れ葉
    t.px(12, 8, OCHRE)


SPECIAL["植栽"] = shrub
SPECIAL["植栽（低木）"] = shrub
SPECIAL["生垣"] = hedge
