"""プレイヤーの SE。足音（材質 8 × 通常 5・忍び足 3）、階段、扉 4 種、調べる・取得・ノート・懐中電灯。モノ。
足音は本作で最も再生回数が多い。耳障りにならないよう、アタックを鈍らせ、高域を削り、変化は「材質」と「ばらつき」で作る。
既存 ID（se_footstep / se_footstep_sneak / se_door / se_interact）は互換のために残し、材質別は se_step_<mat>_<n>（統合案：材質で選び、n を乱択）。
"""
import numpy as np

import synth as s

MATERIALS = ("asphalt", "soil", "grass", "gravel", "boards", "tatami", "stone", "puddle")
MAT_NOTE = {"asphalt": "アスファルト。乾いた短い打面、微かな擦れ", "soil": "土。低く鈍い", "grass": "草。短い擦れが主", "gravel": "砂利。細かい粒が複数",
            "boards": "板張り。空洞の共鳴、ときどき軋む", "tatami": "畳。最も柔らかい", "stone": "石段。硬い打面と短い反射", "puddle": "水たまり。飛沫と低い音"}


def _impact(rng, sec=0.12, attack=0.002, decay=50.0, band=(200, 2500)):
    x = s.white(sec, rng) * s.exp_decay(sec, decay, attack)
    return s.bpf(x, band[0], band[1], 2)


def _thump(rng, freq=110.0, sec=0.1, decay=40.0):
    return s.sine(freq * rng.uniform(0.95, 1.05), sec) * s.exp_decay(sec, decay, 0.001)


def footstep(mat: str, sneak: bool, rng) -> np.ndarray:
    v = rng.uniform(0.9, 1.1)
    if mat == "asphalt":
        x = s.mix(_impact(rng, 0.11, 0.0015, 70 * v, (250, 2600)), _thump(rng, 120, 0.07, 60) * 0.5)
        x = s.fit(x, s.n_samples(0.16)) + s.fit(s.bpf(s.white(0.16, rng), 2500, 6000, 2) * s.exp_decay(0.16, 30, 0.02) * 0.06, s.n_samples(0.16))
    elif mat == "soil":
        x = s.mix(s.lpf(_impact(rng, 0.13, 0.003, 45 * v, (120, 1400)), 900, 2), _thump(rng, 85, 0.1, 35) * 0.7)
        crunch = s.swarm(0.13, rng, 60, (0.004, 0.012), (800, 2500), kind="noise", noise_band=(600, 3000), pan_spread=0.0, loop=False, gain_jitter_db=8).mean(axis=1)
        x = s.mix(x, crunch * 0.25 * s.exp_decay(0.13, 30, 0.005))
    elif mat == "grass":
        brush = s.bpf(s.white(0.2, rng), 1500, 6500, 2) * s.adsr(0.2, 0.015, 0.05, 0.4, 0.1) * 0.6
        x = s.mix(brush, _thump(rng, 95, 0.08, 45) * 0.35, s.lpf(_impact(rng, 0.08, 0.004, 60, (200, 1200)), 1000, 2) * 0.3)
    elif mat == "gravel":
        grains = s.swarm(0.22, rng, 90, (0.005, 0.02), (1200, 5000), kind="noise", noise_band=(900, 6000), pan_spread=0.0, loop=False, gain_jitter_db=10).mean(axis=1)
        x = s.mix(grains * s.exp_decay(0.22, 14, 0.003), _thump(rng, 100, 0.08, 50) * 0.4, _impact(rng, 0.06, 0.002, 90, (300, 2000)) * 0.4)
    elif mat == "boards":
        hollow = s.resonant_body(_impact(rng, 0.18, 0.002, 30, (80, 1500)), [(rng.uniform(95, 140), 8, 1.0), (rng.uniform(260, 340), 10, 0.4)])
        x = s.mix(hollow, _impact(rng, 0.06, 0.001, 90, (400, 3000)) * 0.35)
        if rng.random() < 0.35:
            creak = s.pulse_train(rng.uniform(70, 110), 0.14, 0.15) * s.adsr(0.14, 0.02, 0.04, 0.5, 0.06)
            creak = s.resonator(s.lpf(creak, 1500, 2), rng.uniform(180, 260), 7, 0.5)
            x = s.mix(x, s.fit(creak, len(x)) * 0.25)
    elif mat == "tatami":
        x = s.mix(s.lpf(_impact(rng, 0.1, 0.005, 55 * v, (100, 900)), 650, 2) * 0.9, _thump(rng, 75, 0.09, 40) * 0.5)
        x = s.mix(x, s.bpf(s.white(0.1, rng), 1200, 3000, 2) * s.exp_decay(0.1, 60, 0.005) * 0.08)
    elif mat == "stone":
        click = s.resonant_body(_impact(rng, 0.09, 0.001, 110, (500, 6000)), [(rng.uniform(2000, 3200), 18, 1.0), (rng.uniform(4200, 6000), 22, 0.4)])
        x = s.mix(click, _impact(rng, 0.05, 0.001, 140, (300, 2500)) * 0.6, _thump(rng, 140, 0.05, 70) * 0.3)
        slap = np.zeros(s.n_samples(0.14), np.float32)
        d = s.n_samples(rng.uniform(0.025, 0.04))
        slap[d:] += s.fit(click, len(slap) - d) * 0.25
        x = s.mix(x, s.lpf(slap, 3000, 2))
    else:  # puddle
        splash = s.bpf(s.white(0.2, rng), 2000, 9000, 2) * s.adsr(0.2, 0.004, 0.06, 0.3, 0.12) * 0.7
        drops = s.swarm(0.22, rng, 40, (0.006, 0.02), (1800, 4500), kind="sine", pan_spread=0.0, loop=False, gain_jitter_db=10).mean(axis=1)
        plop = s.sine_fm(rng.uniform(220, 300), 0.09, 8, 60) * s.exp_decay(0.09, 40, 0.002)
        x = s.mix(splash, drops * 0.35, plop * 0.45, _thump(rng, 90, 0.07, 50) * 0.3)
    x = s.hpf(x, 60, 2)
    if sneak:
        # 忍び足：アタックを鈍らせ、高域を落とし、打面より擦れを残す
        x = s.lpf(x, 1400, 2) * s.adsr(len(x) / s.SR, 0.012, 0.02, 0.7, 0.02)
    return x.astype(np.float32)


def stairs(rng, up: bool) -> np.ndarray:
    """階段（木）。2 歩分の板の音を短い間隔で。上りは 2 歩目が少し高く、下りは低く重い"""
    n = s.n_samples(0.5)
    out = np.zeros(n, np.float32)
    for k, at in enumerate((0.0, rng.uniform(0.22, 0.28))):
        st = footstep("boards", False, rng)
        st = s.resonator(st, (120 if up else 95) * (1.08 if (k == 1 and up) else 1.0), 6, 0.6) + st * 0.6
        i = s.n_samples(at)
        out[i:i + len(st)] += st[: n - i] * (1.0 if k == 0 else 0.85)
    return out


def door_wood(rng) -> np.ndarray:
    """木戸。取っ手の金属、蝶番の短い軋み、枠に当たる鈍い音"""
    n = s.n_samples(0.6)
    out = np.zeros(n, np.float32)
    latch = s.resonant_body(_impact(rng, 0.05, 0.001, 120, (800, 5000)), [(2400, 25, 1.0), (3900, 30, 0.4)]) * 0.5
    hinge = s.resonator(s.lpf(s.pulse_train(rng.uniform(60, 90), 0.25, 0.2) * s.adsr(0.25, 0.03, 0.05, 0.6, 0.1), 1800, 2), rng.uniform(300, 420), 9, 0.5)
    frame = s.resonant_body(_impact(rng, 0.2, 0.002, 28, (60, 1200)), [(rng.uniform(110, 150), 7, 1.0), (rng.uniform(380, 460), 9, 0.3)])
    for at, part, g in ((0.0, latch, 1.0), (0.05, hinge, 0.5), (0.34, frame, 0.9)):
        i = s.n_samples(at)
        out[i:i + len(part)] += part[: n - i] * g
    return out


def door_sliding(rng) -> np.ndarray:
    """引き戸。溝を滑る持続音と、端に当たる軽い木の音"""
    n = s.n_samples(0.7)
    slide = s.bpf(s.white(0.5, rng), 400, 2200, 2) * s.adsr(0.5, 0.05, 0.1, 0.6, 0.15) * 0.5
    slide = s.mix(slide, s.resonator(slide, rng.uniform(700, 900), 12, 0.4))
    stop = s.resonant_body(_impact(rng, 0.15, 0.002, 40, (100, 1500)), [(rng.uniform(140, 190), 8, 1.0), (rng.uniform(520, 640), 10, 0.3)])
    out = np.zeros(n, np.float32)
    out[: len(slide)] += slide
    i = s.n_samples(0.46)
    out[i:i + len(stop)] += stop[: n - i] * 0.8
    return out


def door_metal(rng) -> np.ndarray:
    """金属戸（校舎の昇降口）。重い蝶番のうなりと、閉まるときの箱鳴り"""
    n = s.n_samples(0.9)
    groan = s.fm(rng.uniform(70, 95), 0.45, 1.003, 2.5, 3.0) * s.adsr(0.45, 0.05, 0.1, 0.6, 0.2)
    groan = s.resonant_body(s.lpf(groan, 2500, 2), [(rng.uniform(210, 280), 10, 0.8), (rng.uniform(900, 1200), 14, 0.3)])
    slam = s.resonant_body(_impact(rng, 0.35, 0.001, 18, (60, 3000)), [(rng.uniform(85, 110), 6, 1.0), (rng.uniform(300, 380), 8, 0.5), (rng.uniform(1500, 2100), 20, 0.3)])
    out = np.zeros(n, np.float32)
    out[: len(groan)] += groan * 0.6
    i = s.n_samples(0.5)
    out[i:i + len(slam)] += slam[: n - i]
    return out


def shutter(rng) -> np.ndarray:
    """シャッター（半開きを押し上げる／下ろす）。波板が連続して鳴る"""
    n = s.n_samples(1.2)
    slats = s.swarm(1.0, rng, 40, (0.02, 0.05), (600, 1800), kind="noise", noise_band=(400, 2600), pan_spread=0.0, loop=False, gain_jitter_db=6).mean(axis=1)
    slats = s.resonant_body(slats, [(rng.uniform(180, 240), 9, 1.0), (rng.uniform(1100, 1500), 14, 0.4)]) * s.adsr(1.0, 0.1, 0.2, 0.7, 0.3)
    rattle = s.fm(rng.uniform(45, 60), 1.0, 1.0, 3.0, 0.0) * s.adsr(1.0, 0.1, 0.2, 0.5, 0.3) * 0.3
    stop = s.resonant_body(_impact(rng, 0.2, 0.002, 30, (80, 2000)), [(rng.uniform(150, 200), 7, 1.0)])
    out = np.zeros(n, np.float32)
    out[: s.n_samples(1.0)] += s.lpf(s.mix(slats, rattle), 3000, 2)
    i = s.n_samples(0.95)
    out[i:i + len(stop)] += stop[: n - i] * 0.7
    return out


def interact(rng) -> np.ndarray:
    """調べる。小さな、硬すぎない合図。木片を指で弾いたような 1 音"""
    x = s.resonant_body(_impact(rng, 0.09, 0.001, 70, (400, 4000)), [(1320, 20, 1.0), (2640, 28, 0.3)])
    return s.mix(x, _thump(rng, 220, 0.05, 90) * 0.3)


def item_get(rng) -> np.ndarray:
    """アイテム取得。紙か布を手に取る擦れと、ポケットに入れる鈍い音。合図としての音程は付けない"""
    rustle = s.bpf(s.white(0.25, rng), 1200, 6000, 2) * s.adsr(0.25, 0.02, 0.05, 0.5, 0.12) * 0.5
    pat = s.lpf(_impact(rng, 0.1, 0.003, 50, (100, 900)), 700, 2) * 0.7
    out = np.zeros(s.n_samples(0.42), np.float32)
    out[: len(rustle)] += rustle
    i = s.n_samples(0.26)
    out[i:i + len(pat)] += pat[: len(out) - i]
    return out


def notebook(rng, open_: bool) -> np.ndarray:
    """ノートを開く／閉じる。厚紙の表紙と紙。開くは軽く、閉じるは少し鈍い"""
    flip = s.bpf(s.white(0.18, rng), 900, 5000, 2) * s.adsr(0.18, 0.01, 0.04, 0.5, 0.1) * 0.5
    cover = s.lpf(_impact(rng, 0.12, 0.003, 45, (120, 1400)), 1000, 2) * (0.5 if open_ else 0.9)
    out = np.zeros(s.n_samples(0.3), np.float32)
    if open_:
        out[: len(cover)] += cover
        i = s.n_samples(0.06)
        out[i:i + len(flip)] += flip[: len(out) - i]
    else:
        out[: len(flip)] += flip * 0.7
        i = s.n_samples(0.12)
        out[i:i + len(cover)] += cover[: len(out) - i]
    return out


def flashlight(rng, on: bool) -> np.ndarray:
    """懐中電灯のスイッチ。小さなプラスチックのクリック。オンは 2 段、オフは 1 段"""
    click = s.resonant_body(_impact(rng, 0.03, 0.0005, 300, (1500, 8000)), [(3600, 25, 1.0), (5400, 30, 0.5)])
    out = np.zeros(s.n_samples(0.09), np.float32)
    out[: len(click)] += click
    if on:
        i = s.n_samples(0.035)
        out[i:i + len(click)] += click[: len(out) - i] * 0.7
    return out


DEFS = []
for mat in MATERIALS:
    for k in range(1, 6):
        DEFS.append({"id": f"se_step_{mat}_{k}", "kind": "se", "loop": False, "stereo": False, "fade_out": 0.01, "lufs_offset": -6,
                     "render": (lambda m: (lambda rng: footstep(m, False, rng)))(mat), "material": mat, "note": MAT_NOTE[mat], "use": "足音（材質で選び、1〜5 を乱択）"})
    for k in range(1, 4):
        DEFS.append({"id": f"se_step_{mat}_sneak_{k}", "kind": "se", "loop": False, "stereo": False, "fade_out": 0.01, "lufs_offset": -14,
                     "render": (lambda m: (lambda rng: footstep(m, True, rng)))(mat), "material": mat, "note": "忍び足。" + MAT_NOTE[mat], "use": "忍び足（材質で選び、1〜3 を乱択）"})
DEFS += [
    {"id": "se_footstep", "kind": "se", "loop": False, "stereo": False, "fade_out": 0.01, "lufs_offset": -6, "render": lambda rng: footstep("asphalt", False, rng), "material": "asphalt",
     "note": "既存 ID。アスファルトの 1 種（材質別に置き換えるまでの互換）", "use": "Player の歩行（現行コード）"},
    {"id": "se_footstep_sneak", "kind": "se", "loop": False, "stereo": False, "fade_out": 0.01, "lufs_offset": -14, "render": lambda rng: footstep("asphalt", True, rng), "material": "asphalt",
     "note": "既存 ID。忍び足の互換", "use": "Player の忍び足（現行コード）"},
    {"id": "se_stairs_up", "kind": "se", "loop": False, "stereo": False, "fade_out": 0.02, "lufs_offset": -6, "render": lambda rng: stairs(rng, True), "note": "木の階段を上る 2 歩", "use": "F11 の階の切替（統合案）"},
    {"id": "se_stairs_down", "kind": "se", "loop": False, "stereo": False, "fade_out": 0.02, "lufs_offset": -6, "render": lambda rng: stairs(rng, False), "note": "木の階段を下りる 2 歩", "use": "同上"},
    {"id": "se_door", "kind": "se", "loop": False, "stereo": False, "fade_out": 0.03, "lufs_offset": -2, "render": door_wood, "note": "既存 ID。木戸（取っ手・蝶番・枠）", "use": "events の play_sound se_door"},
    {"id": "se_door_sliding", "kind": "se", "loop": False, "stereo": False, "fade_out": 0.03, "lufs_offset": -4, "render": door_sliding, "note": "引き戸。溝を滑って端に当たる", "use": "自宅・商店の戸（統合案）"},
    {"id": "se_door_metal", "kind": "se", "loop": False, "stereo": False, "fade_out": 0.04, "lufs_offset": 0, "render": door_metal, "note": "金属戸。重い蝶番と箱鳴り", "use": "旧校舎の昇降口・校門（統合案）"},
    {"id": "se_shutter", "kind": "se", "loop": False, "stereo": False, "fade_out": 0.05, "lufs_offset": -2, "render": shutter, "note": "シャッター。波板が連続して鳴る", "use": "F05 の半開きのシャッター（統合案）"},
    {"id": "se_interact", "kind": "se", "loop": False, "stereo": False, "fade_out": 0.01, "lufs_offset": -8, "render": interact, "note": "既存 ID。調べる。木片を弾いたような 1 音", "use": "Interactable（統合案：現行は未使用）"},
    {"id": "se_item_get", "kind": "se", "loop": False, "stereo": False, "fade_out": 0.02, "lufs_offset": -6, "render": item_get, "note": "取得。紙を手に取りポケットへ。音程を付けない", "use": "give_item（統合案）"},
    {"id": "se_notebook_open", "kind": "se", "loop": False, "stereo": False, "fade_out": 0.02, "lufs_offset": -8, "render": lambda rng: notebook(rng, True), "note": "ノートを開く", "use": "Notebook（統合案）"},
    {"id": "se_notebook_close", "kind": "se", "loop": False, "stereo": False, "fade_out": 0.02, "lufs_offset": -8, "render": lambda rng: notebook(rng, False), "note": "ノートを閉じる", "use": "同上"},
    {"id": "se_flashlight_on", "kind": "se", "loop": False, "stereo": False, "fade_out": 0.005, "lufs_offset": -10, "render": lambda rng: flashlight(rng, True), "note": "懐中電灯オン。2 段のクリック", "use": "Lighting.set_flashlight（統合案）"},
    {"id": "se_flashlight_off", "kind": "se", "loop": False, "stereo": False, "fade_out": 0.005, "lufs_offset": -10, "render": lambda rng: flashlight(rng, False), "note": "懐中電灯オフ", "use": "同上"},
]
