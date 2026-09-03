"""怪異 27 件（1 件 1 音）、追跡者（遠くの気配・気付き・足音・追跡ループ・見失う）、心拍ループ、澪の足音、封石。モノ。

怪異の音の原則：
- 起きたことを「音で説明」しない。生活音が一つ欠ける・一つ増える・一つ遅れる、だけで作る
- 大きくしない（多くは -26〜-32 LUFS）。ジャンプスケア、叫び、呻きは使わない
- 環境音の切替（amb_road_still / amb_paddy_still）で表す怪異は、音はごく短い「切れ目」だけ
- 具体的な事故・自死を思わせる物音は使わない（落下音、水没音、ロープ、椅子は一切作らない）
"""
import numpy as np

import scenes
import synth as s
from defs.se_player import footstep


def _z(sec):
    return np.zeros(s.n_samples(sec), np.float32)


def _noise_hit(rng, sec, decay, band, attack=0.002):
    return s.bpf(s.white(sec, rng) * s.exp_decay(sec, decay, attack), band[0], band[1], 2)


def _far(x, rng, cutoff=1800.0, rt60=1.2, size="outdoor", wet=0.5, gain=0.5):
    """遠くの音：ローパスして残響の湿り分を増やす"""
    ir = s.make_ir(rng, rt60, size, damp_hz=cutoff, early=True, predelay_ms=12)
    y = s.convolve(s.lpf(x, cutoff, 2), ir, wet, 1.0)
    return s.to_mono(y) * gain


def _mono(x):
    return s.to_mono(x).astype(np.float32)


# ── 怪異 ─────────────────────────────────────────────

def an_f01_silence(rng):
    """国道の音が消える。走行音が 1.2 秒で閉じ、自販機のハムだけが残って消える"""
    out = _z(3.0)
    traffic = s.lpf(s.pink(1.4, rng), 500, 2) * np.linspace(1, 0, s.n_samples(1.4)) ** 2 * 0.8
    s.place(out, traffic, 0.0)
    hum = scenes.machine_hum(2.2, rng, 60.0, (1.0, 0.3, 0.15), 0.01, 0.0)
    s.place(out, _mono(hum) * s.adsr(2.2, 0.3, 0.2, 0.8, 1.2) * 0.25, 0.8)
    return out


def an_f02_laundry(rng):
    """竿だけが揺れている。竿がフックに当たる乾いた 2 打と、湿った布の重い翻り"""
    out = _z(2.0)
    for at in (0.0, 0.9):
        knock = s.resonant_body(_noise_hit(rng, 0.25, 22, (200, 3000)), [(rng.uniform(420, 520), 14, 1.0), (rng.uniform(1300, 1600), 18, 0.35)])
        s.place(out, knock * 0.6, at)
    cloth = s.lpf(s.white(0.8, rng), 900, 2) * s.adsr(0.8, 0.12, 0.1, 0.5, 0.4) * 0.35
    s.place(out, cloth, 0.3)
    return out


def an_f05_fresh_goods(rng):
    """昨日より新しい駄菓子。セロファンの袋が一度だけ鳴る。ごく小さく"""
    out = _z(1.0)
    crinkle = s.swarm(0.7, rng, 120, (0.003, 0.012), (3000, 9000), kind="noise", noise_band=(2500, 10000), pan_spread=0.0, loop=False, gain_jitter_db=8).mean(axis=1)
    s.place(out, crinkle * s.adsr(0.7, 0.05, 0.1, 0.5, 0.3) * 0.5, 0.1)
    return out


def an_f06_board_night(rng):
    """尋ね人の紙が一枚多い。紙が一枚だけ風で鳴り、画鋲が板を打つ"""
    out = _z(1.6)
    s.place(out, _mono(scenes.paper_flutter(1.0, rng, 2)) * 0.6, 0.0)
    pin = s.resonant_body(_noise_hit(rng, 0.08, 90, (800, 6000)), [(rng.uniform(1800, 2300), 20, 1.0)])
    s.place(out, pin * 0.35, 1.05)
    return out


def an_f12_stairwell_blink(rng):
    """階段室の灯りが同時に消え、数秒おいて三階だけが点く。リレーの音、ハムの停止、安定器の点き始め。階段室の反響"""
    out = _z(4.0)
    hum = _mono(scenes.fluorescent(0.6, rng, 1.0)) * np.linspace(1, 0, s.n_samples(0.6)) ** 4
    s.place(out, hum * 0.4, 0.0)
    relay = s.resonant_body(_noise_hit(rng, 0.06, 120, (400, 4000)), [(rng.uniform(900, 1200), 12, 1.0)])
    s.place(out, relay * 0.5, 0.05)
    start = _mono(scenes.fluorescent(1.6, rng, 1.0)) * (s.pulse_train(rng.uniform(9, 13), 1.6, 0.4) * 0.7 + 0.3) * s.adsr(1.6, 0.4, 0.3, 0.6, 0.5)
    s.place(out, start * 0.3, 2.3)
    ir = s.make_ir(rng, 1.4, "hall", damp_hz=2500, predelay_ms=8)
    return _mono(s.convolve(out, ir, 0.35, 1.0))


def an_f03_bus_nobody(rng):
    """バスが来て、扉が開いて閉まる。誰も降りない。アイドリング、エアの抜ける音、折戸の 2 段、エア。チャイムは鳴らさない"""
    out = _z(4.5)
    idle = _mono(scenes.machine_hum(4.5, rng, 27.0, (1.0, 0.6, 0.35, 0.2, 0.1), 0.03, 0.0)) * s.adsr(4.5, 0.6, 0.2, 0.8, 1.0)
    s.place(out, s.lpf(idle, 300, 2) * 0.5, 0.0)
    for at, sec in ((0.8, 0.5), (3.1, 0.6)):
        air = s.bpf(s.white(sec, rng), 1500, 7000, 2) * s.adsr(sec, 0.02, 0.1, 0.4, 0.3)
        s.place(out, air * 0.3, at)
        fold = s.resonant_body(_noise_hit(rng, 0.3, 20, (150, 2500)), [(rng.uniform(220, 300), 9, 1.0), (rng.uniform(700, 900), 12, 0.4)])
        s.place(out, fold * 0.5, at + 0.35)
    return out


def an_f03_tunnel_light(rng):
    """隧道を抜けると明るさが違う。隧道の反響が開ける「圧の抜け」。逆向きのローパス開き"""
    sec = 1.8
    n = s.n_samples(sec)
    x = s.pink(sec, rng)
    curve = 300 + (4000 - 300) * (np.linspace(0, 1, n) ** 2)
    x = s.lpf_sweep(x, curve.astype(np.float32), 2) * s.adsr(sec, 0.6, 0.2, 0.6, 0.8)
    ir = s.make_ir(rng, 2.4, "tunnel", damp_hz=1500, predelay_ms=20)
    return _mono(s.convolve(x, ir, 0.5, 0.6)) * 0.5


def an_f13_house_count(rng):
    """家が一軒増えている。ニュータウンの均質な静けさの中で、遠くの玄関扉が一度だけ閉まる"""
    out = _z(2.5)
    door = s.resonant_body(_noise_hit(rng, 0.35, 16, (80, 1500)), [(rng.uniform(95, 120), 8, 1.0), (rng.uniform(320, 400), 10, 0.3)])
    s.place(out, _far(door, rng, 900, 0.8, "outdoor", 0.4, 0.5), 0.6)
    lamp = _mono(scenes.fluorescent(2.5, rng, 1.0)) * 0.08
    return s.mix(out, lamp)


def an_f10_line(rng):
    """白線が堤防を越えて河原へ続く。堤防の風と、河原の石が一つ転がる乾いた音"""
    out = _z(2.5)
    wind = s.lpf(s.pink(2.5, rng), 700, 2) * s.adsr(2.5, 0.8, 0.3, 0.6, 1.0) * 0.3
    s.place(out, wind, 0.0)
    for at in (1.2, 1.32, 1.5):
        stone = s.resonant_body(_noise_hit(rng, 0.12, 40, (600, 6000)), [(rng.uniform(2200, 3200), 16, 1.0), (rng.uniform(4500, 6500), 20, 0.3)])
        s.place(out, stone * rng.uniform(0.25, 0.45), at)
    return out


def an_f10_light(rng):
    """照明塔が一灯だけ点く。ブレーカーは落ちている。遮断器の重い音 → 放電灯の点火の唸りが立ち上がって安定"""
    out = _z(4.0)
    clunk = s.resonant_body(_noise_hit(rng, 0.3, 18, (60, 1200)), [(rng.uniform(110, 140), 7, 1.0), (rng.uniform(400, 480), 9, 0.3)])
    s.place(out, _far(clunk, rng, 1200, 1.0, "outdoor", 0.4, 0.6), 0.2)
    sec = 3.2
    n = s.n_samples(sec)
    ignite = s.fm(100.0, sec, 2.0, 1.5, 0.8) * (0.5 + 0.5 * s.wander(sec, rng, 6.0, 1.0)) * s.adsr(sec, 1.2, 0.5, 0.6, 1.0)
    ignite = s.bpf(ignite, 200, 3000, 2)
    hum = _mono(scenes.machine_hum(sec, rng, 100.0, (1.0, 0.4, 0.2), 0.01, 0.0)) * np.linspace(0, 1, n) ** 2 * s.adsr(sec, 0.1, 0.1, 1.0, 0.8)
    s.place(out, (ignite * 0.25 + hum * 0.2), 0.7)
    return out


def an_f07_gaze(rng):
    """格子の内側で何かが動いた。木の格子が軽く鳴り、布のようなものがゆっくり擦れる。堂内の反響"""
    out = _z(2.2)
    lattice = s.resonant_body(_noise_hit(rng, 0.2, 25, (300, 3500)), [(rng.uniform(600, 760), 12, 1.0), (rng.uniform(1500, 1900), 16, 0.4)])
    s.place(out, lattice * 0.4, 0.3)
    cloth = s.lpf(s.white(1.2, rng), 1200, 2) * s.adsr(1.2, 0.3, 0.2, 0.5, 0.6) * 0.25
    s.place(out, cloth, 0.6)
    ir = s.make_ir(rng, 2.0, "hall", damp_hz=2000, predelay_ms=15)
    return _mono(s.convolve(out, ir, 0.5, 0.8))


def an_f07_lamps(rng):
    """灯明が増えている。炎が空気を揺らす微かな音と、芯の小さな弾け"""
    sec = 2.5
    flame = s.bpf(s.white(sec, rng), 300, 1500, 2) * (0.5 + 0.5 * s.wander(sec, rng, 5.0, 1.0)) * s.adsr(sec, 0.4, 0.2, 0.7, 0.8) * 0.2
    pops = s.swarm(sec, rng, 3.0, (0.004, 0.01), (2000, 5000), kind="noise", noise_band=(1500, 6000), pan_spread=0.0, loop=False, gain_jitter_db=10).mean(axis=1) * 0.25
    return s.mix(flame, pops)


def an_f08_plum_steps(rng):
    """梅林の奥で枝が鳴り、鳴る場所が近づいてくる。小枝の折れる音 3 回、次第に近く（ローパスが開き、残響が減る）"""
    out = _z(4.0)
    for k, at in enumerate((0.0, 1.3, 2.7)):
        snap = s.resonant_body(_noise_hit(rng, 0.09, 60, (500, 6000), 0.001), [(rng.uniform(1500, 2200), 14, 1.0), (rng.uniform(3500, 5000), 18, 0.4)])
        cutoff = (1200, 2500, 5000)[k]
        wet = (0.6, 0.4, 0.2)[k]
        s.place(out, _far(snap, rng, cutoff, 1.0, "outdoor", wet, (0.35, 0.5, 0.7)[k]), at)
    return out


def an_f08_lookout_lights(rng):
    """無いはずの光が増えている。音源のない光なので、遠くの電気的な唸りが微かに膨らむだけ"""
    sec = 2.5
    buzz = _mono(scenes.machine_hum(sec, rng, 100.0, (1.0, 0.5, 0.3, 0.2), 0.02, 0.0))
    return s.bpf(buzz, 150, 2500, 2) * s.adsr(sec, 1.0, 0.3, 0.6, 1.0) * 0.3


def an_f09_bridge_gone(rng):
    """土橋が無い。空堀へ乾いた土がこぼれ落ちる音と、樹林の風"""
    out = _z(3.0)
    wind = _mono(scenes.leaves(3.0, rng, 25)) * s.adsr(3.0, 0.8, 0.4, 0.5, 1.2) * 0.3
    s.place(out, wind, 0.0)
    soil = s.swarm(1.2, rng, 200, (0.004, 0.015), (500, 2500), kind="noise", noise_band=(300, 3000), pan_spread=0.0, loop=False, gain_jitter_db=8).mean(axis=1)
    s.place(out, s.lpf(soil, 2000, 2) * s.adsr(1.2, 0.1, 0.2, 0.5, 0.6) * 0.5, 0.8)
    return out


def an_f09_map_drift(rng):
    """縄張図の曲輪が増えている。案内板のアクリル板が風で軋み、枠に当たる"""
    out = _z(2.0)
    creak = s.resonator(s.lpf(s.pulse_train(rng.uniform(40, 60), 0.5, 0.2) * s.adsr(0.5, 0.05, 0.1, 0.6, 0.2), 2500, 2), rng.uniform(900, 1200), 10, 0.5)
    s.place(out, creak * 0.35, 0.2)
    tap = s.resonant_body(_noise_hit(rng, 0.12, 40, (300, 3000)), [(rng.uniform(500, 650), 12, 1.0), (rng.uniform(1400, 1800), 16, 0.3)])
    s.place(out, tap * 0.5, 0.95)
    return out


def an_f14_moon(rng):
    """水田に月が一つ多い。水面が一度だけ小さく鳴り、あとは静か"""
    out = _z(2.5)
    plip = s.sine_fm(rng.uniform(600, 800), 0.12, 12, 250) * s.exp_decay(0.12, 30, 0.002)
    ring = s.lpf(s.white(0.4, rng), 1500, 2) * s.exp_decay(0.4, 10, 0.01) * 0.3
    s.place(out, s.lpf(plip, 2500, 2) * 0.4, 0.4)
    s.place(out, ring, 0.42)
    return out


def an_f14_frogs(rng):
    """蛙が一斉に止み、足音のない何かが畦を渡る。草が順に倒れていく音だけ 5 回"""
    out = _z(4.0)
    for k in range(5):
        g = _mono(scenes.grass(0.5, rng, 40)) * s.adsr(0.5, 0.05, 0.1, 0.5, 0.25)
        s.place(out, s.lpf(g, 3000 - k * 300, 2) * rng.uniform(0.5, 0.8), 0.4 + k * 0.7)
    return out


def an_f15_footsteps(rng):
    """向こう岸から足音が、俺と同じ歩調で来る。橋の板の足音 4 歩を残響越しに。止まると止まる"""
    out = _z(3.5)
    for k in range(4):
        st = footstep("boards", False, rng)
        s.place(out, _far(st, rng, 2200 + k * 400, 1.6, "outdoor", 0.5, 0.5 + k * 0.08), 0.2 + k * 0.62)
    return out


def an_f15_fog(rng):
    """霧が橋の中ほどまで来る。川の音が閉じていく（ローパスが 3 秒かけて下がる）"""
    sec = 3.5
    n = s.n_samples(sec)
    river = _mono(scenes.water(sec, rng, 0.6, 0.5, 0.2))
    curve = 5000 - (5000 - 250) * (np.linspace(0, 1, n) ** 0.7)
    return s.lpf_sweep(river, curve.astype(np.float32), 2) * s.adsr(sec, 0.3, 0.2, 0.9, 1.5) * 0.5


def an_f04_loop(rng):
    """獣道が小屋の裏へ戻る。方向感の失われる短い圧の揺れと、トタンが一度鳴る"""
    out = _z(2.5)
    sway = s.lpf(s.pink(1.5, rng), 250, 2) * s.sine(0.7, 1.5) * s.adsr(1.5, 0.3, 0.2, 0.6, 0.6) * 0.6
    s.place(out, sway, 0.0)
    s.place(out, _mono(scenes.tin_rattle(1.2, rng, 1)) * 0.5, 1.0)
    return out


def an_f04_bulb(rng):
    """配線の切れた小屋の電球が点く。フィラメントの小さな「チン」と、あるはずのない 100 Hz の細いハム"""
    out = _z(3.0)
    tink = s.resonant_body(_noise_hit(rng, 0.15, 30, (2000, 9000), 0.0005), [(rng.uniform(4200, 5200), 40, 1.0), (rng.uniform(7000, 8500), 45, 0.4)])
    s.place(out, tink * 0.3, 0.3)
    hum = _mono(scenes.fluorescent(2.5, rng, 1.0)) * s.adsr(2.5, 0.05, 0.2, 0.8, 1.0) * 0.15
    s.place(out, hum, 0.4)
    return out


def an_f11_desks(rng):
    """机が減っている。誰もいない教室で、机の脚が一度だけ床に当たる。教室の反響"""
    out = _z(2.0)
    leg = s.resonant_body(_noise_hit(rng, 0.2, 30, (300, 4000)), [(rng.uniform(1100, 1400), 14, 1.0), (rng.uniform(2600, 3200), 18, 0.4)])
    s.place(out, leg * 0.5, 0.4)
    ir = s.make_ir(rng, 1.1, "room", damp_hz=3000, predelay_ms=10)
    return _mono(s.convolve(out, ir, 0.45, 1.0))


def an_f11_chime(rng):
    """誰もいない学校でチャイムが鳴り、途中で止まる。
    既存の学校チャイム（ウェストミンスター）は再現しない。4 音の鐘状の FM 音を独自の並びで、スピーカー越し（300–3000 Hz）に遠く、3 音目の途中で切れる"""
    out = _z(5.0)
    notes = (392.0, 494.0, 440.0, 294.0)  # 独自の並び
    for k, f in enumerate(notes):
        sec = 1.4
        tone = s.fm(f, sec, 1.41, 1.2, 1.5) * s.exp_decay(sec, 1.6, 0.01)
        tone = s.mix(tone, s.sine(f * 2.76, sec) * s.exp_decay(sec, 4.0, 0.01) * 0.15)
        if k == 2:
            tone = tone[: s.n_samples(0.35)] * s.fade(np.ones(s.n_samples(0.35), np.float32), 0.0, 0.004)
        s.place(out, s.bpf(tone, 300, 3000, 2) * 0.4, 0.3 + k * 0.7)
        if k == 2:
            cut = s.resonant_body(_noise_hit(rng, 0.05, 150, (500, 3000)), [(1000, 10, 1.0)])
            s.place(out, cut * 0.15, 0.3 + k * 0.7 + 0.35)
            break
    return _far(out, rng, 2500, 1.8, "outdoor", 0.5, 1.0)


def an_f11_upstairs(rng):
    """二階から机を引きずる音。一つ、間を置いて、もう一つ。天井越しに低くこもる"""
    out = _z(5.0)
    for at, sec in ((0.3, 1.1), (2.9, 1.4)):
        drag = s.lpf(s.white(sec, rng), 700, 2) * (0.6 + 0.4 * s.wander(sec, rng, 8.0, 1.0)) * s.adsr(sec, 0.1, 0.2, 0.7, 0.3)
        drag = s.resonant_body(drag, [(rng.uniform(70, 90), 6, 1.0), (rng.uniform(160, 200), 8, 0.5)])
        s.place(out, drag * 0.5, at)
    return s.lpf(out, 500, 2)


def an_f16_nothing(rng):
    """何も起こらない。それが続いている。4 秒のほぼ無音：微かな風と、小石が一度だけ鳴る"""
    out = _z(4.0)
    wind = s.lpf(s.pink(4.0, rng), 300, 2) * s.adsr(4.0, 1.5, 0.5, 0.6, 1.5) * 0.15
    s.place(out, wind, 0.0)
    tick = s.resonant_body(_noise_hit(rng, 0.06, 80, (1500, 7000)), [(rng.uniform(3000, 4000), 20, 1.0)])
    s.place(out, tick * 0.12, 2.6)
    return out


def an_f16_count(rng):
    """霧の向こうで何かが数えている。声は使わない。石を石に当てるような鈍い打音が 1 秒間隔で三つ、三つ目で止まる"""
    out = _z(4.5)
    for k in range(3):
        knock = s.resonant_body(_noise_hit(rng, 0.25, 20, (150, 2500)), [(rng.uniform(260, 320), 9, 1.0), (rng.uniform(900, 1100), 12, 0.3)])
        s.place(out, _far(knock, rng, 1000, 2.0, "outdoor", 0.6, 0.6), 0.4 + k * 1.0)
    return out


# ── 追跡者・心拍・澪・封石 ───────────────────────────

def stalker_step(rng, mat):
    """追跡者の足音。主人公より遅く重い。低域を足し、アタックを鈍らせる"""
    st = footstep(mat, False, rng)
    heavy = s.sine(rng.uniform(55, 65), 0.16) * s.exp_decay(0.16, 30, 0.004) * 0.5
    x = s.mix(s.lpf(st, 2500, 2), heavy)
    return x * s.adsr(len(x) / s.SR, 0.008, 0.02, 0.8, 0.02)


def stalker_far(rng):
    """遠くの気配。砂利を踏む足音 2 歩が、遠く、ローパス越しに。何も起きない"""
    out = _z(2.0)
    for k, at in enumerate((0.2, 0.95)):
        s.place(out, _far(stalker_step(rng, "gravel"), rng, 900, 1.2, "outdoor", 0.6, 0.5), at)
    return out


def stalker_notice(rng):
    """気付かれた。低い圧がゆっくり膨らんで抜ける。叫びも刺す音も無い"""
    sec = 2.0
    n = s.n_samples(sec)
    swell = s.lpf(s.brown(sec, rng), 90, 2) * s.adsr(sec, 0.7, 0.3, 0.6, 0.9) * 1.0
    air = s.lpf(s.pink(sec, rng), 600, 2) * s.adsr(sec, 0.5, 0.3, 0.4, 0.9) * 0.3
    return s.mix(swell, air)


def stalker_chase_loop(rng):
    """追跡中に環境へ重ねる 8 秒ループ。呼吸の速さ（0.55 Hz）でうねる低いノイズと、40 Hz 付近の圧。心拍の帯域（60–110 Hz）は避ける"""
    sec = 8.0 + 0.5  # ループ長 8.0 秒 + クロスフェード分。うねりは 8 秒で整数周期（0.5 Hz = 4 周期、0.25 Hz = 2 周期）
    t = s.t_axis(sec)
    breath = 0.55 + 0.45 * np.sin(2 * np.pi * 0.5 * t - np.pi / 2)
    noise = s.bpf(s.pink(sec, rng), 250, 900, 2) * breath * 0.5
    pressure = s.lpf(s.brown(sec, rng), 45, 2) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.25 * t)) * 0.8
    return s.mix(noise, pressure)


def stalker_lost(rng):
    """見失った（追跡者が主人公を）。圧が抜けて、環境が戻る。長い呼気のようなノイズの減衰"""
    sec = 2.5
    n = s.n_samples(sec)
    rel = s.lpf(s.pink(sec, rng), 800, 2) * np.linspace(1, 0, n) ** 1.5 * 0.5
    low = s.lpf(s.brown(sec, rng), 80, 2) * np.linspace(1, 0, n) ** 3 * 0.6
    return s.mix(rel, low)


def heartbeat(rng):
    """心拍。62 bpm、4 秒に 4 拍ちょうど（ループ）。各拍は「ドッ・ク」の 2 打。60–110 Hz。遠くから聞くように鈍く"""
    beat = 60.0 / 62.0
    sec = 4 * beat + 0.05  # ループ長 3.871 s（4 拍ちょうど）+ クロスフェード分。拍は 0.1 s から始め、末尾は無音にして継ぎ目に拍が掛からないようにする
    out = _z(sec)
    for k in range(4):
        for j, (d, f, g) in enumerate(((0.0, 62.0, 1.0), (0.17, 78.0, 0.6))):
            th = s.sine(f, 0.22) * s.exp_decay(0.22, 22, 0.006) * g
            th = s.mix(th, s.lpf(s.white(0.1, rng), 200, 2) * s.exp_decay(0.1, 60, 0.003) * 0.25 * g)
            s.place(out, th, 0.1 + k * beat + d)
    return s.lpf(out, 160, 2)


def heroine_step(rng):
    """澪の足音。主人公より軽く、少し高い。アスファルトの音を短く、低域を減らす"""
    st = footstep("asphalt", False, rng)
    x = s.hpf(st, 180, 2) * s.exp_decay(len(st) / s.SR, 8, 0.001)
    return x[: s.n_samples(0.12)]


def seal_stone(rng):
    """封石を押し戻す。石が石の上を擦れて動き、最後に低く据わって止まる。2.4 秒。裂け目の口のハム（amb_valley_inner）はここで止まる想定"""
    sec = 2.4
    n = s.n_samples(sec)
    grind = s.bpf(s.white(1.8, rng), 150, 2500, 2) * (0.6 + 0.4 * s.wander(1.8, rng, 10.0, 1.0)) * s.adsr(1.8, 0.25, 0.3, 0.7, 0.4)
    grind = s.resonant_body(grind, [(rng.uniform(160, 200), 6, 1.0), (rng.uniform(480, 560), 9, 0.4)])
    out = _z(sec)
    s.place(out, grind * 0.6, 0.0)
    settle = s.resonant_body(_noise_hit(rng, 0.5, 10, (40, 800)), [(rng.uniform(48, 56), 8, 1.0), (rng.uniform(130, 150), 9, 0.3)])
    s.place(out, settle * 0.8, 1.75)
    return out


def _d(id_, render, note, use, off, fade_out=0.05, **kw):
    d = {"id": id_, "kind": "se", "loop": False, "stereo": False, "fade_out": fade_out, "lufs_offset": off, "render": render, "note": note, "use": use}
    d.update(kw)
    return d


ANOMALIES = [
    ("an_f01_silence", an_f01_silence, "国道の音が消える。走行音が閉じ、自販機のハムだけ残る", -12),
    ("an_f02_laundry", an_f02_laundry, "竿だけが揺れている。竿の 2 打と湿った布", -12),
    ("an_f05_fresh_goods", an_f05_fresh_goods, "新しい駄菓子。セロファンが一度鳴る", -16),
    ("an_f06_board_night", an_f06_board_night, "紙が一枚だけ風で鳴り、画鋲が板を打つ", -12),
    ("an_f12_stairwell_blink", an_f12_stairwell_blink, "灯りが消え、三階だけ点く。リレー・ハム停止・安定器の点き始め", -10),
    ("an_f03_bus_nobody", an_f03_bus_nobody, "バスが来て扉が開閉、誰も降りない。チャイム無し", -8),
    ("an_f03_tunnel_light", an_f03_tunnel_light, "隧道を抜ける圧の抜け。ローパスが開く", -12),
    ("an_f13_house_count", an_f13_house_count, "遠くの玄関扉が一度だけ閉まる。街灯のハム", -14),
    ("an_f10_line", an_f10_line, "堤防の風と、河原の石が転がる", -12),
    ("an_f10_light", an_f10_light, "照明塔が一灯点く。遮断器と放電灯の点火", -8),
    ("an_f07_gaze", an_f07_gaze, "格子が鳴り、布が擦れる。堂内の反響", -12),
    ("an_f07_lamps", an_f07_lamps, "灯明の炎と芯の弾け", -16),
    ("an_f08_plum_steps", an_f08_plum_steps, "枝の折れる音が 3 回、近づく", -10),
    ("an_f08_lookout_lights", an_f08_lookout_lights, "遠くの電気的な唸りが膨らむだけ", -18),
    ("an_f09_bridge_gone", an_f09_bridge_gone, "土が空堀へこぼれる。樹林の風", -12),
    ("an_f09_map_drift", an_f09_map_drift, "案内板のアクリルが軋み、枠に当たる", -14),
    ("an_f14_moon", an_f14_moon, "水面が一度だけ鳴る", -14),
    ("an_f14_frogs", an_f14_frogs, "草が順に倒れていく 5 回。足音は無い", -10),
    ("an_f15_footsteps", an_f15_footsteps, "向こう岸から橋の板の足音 4 歩、同じ歩調で", -8),
    ("an_f15_fog", an_f15_fog, "川の音が霧に閉じていく", -12),
    ("an_f04_loop", an_f04_loop, "方向感の失われる圧の揺れとトタン", -12),
    ("an_f04_bulb", an_f04_bulb, "フィラメントの「チン」と細いハム", -14),
    ("an_f11_desks", an_f11_desks, "机の脚が一度床に当たる。教室の反響", -12),
    ("an_f11_chime", an_f11_chime, "独自の 4 音の鐘状の音、遠く、3 音目で切れる", -6),
    ("an_f11_upstairs", an_f11_upstairs, "二階で机を引きずる音、二回", -10),
    ("an_f16_nothing", an_f16_nothing, "ほぼ無音。微かな風と小石一つ", -22),
    ("an_f16_count", an_f16_count, "石の鈍い打音が三つ、三つ目で止まる。声は無い", -8),
]

DEFS = [_d(f"se_{aid}", fn, note, f"怪異 {aid}（統合案：actions の play_sound）", off, allow_silence=True) for aid, fn, note, off in ANOMALIES]
DEFS += [
    _d("se_stalker_far", stalker_far, "遠くの気配。砂利の足音 2 歩が遠く", "Stalker SUSPICIOUS への遷移（統合案）", -16, allow_silence=True),
    _d("se_stalker_notice", stalker_notice, "気付かれた。低い圧が膨らんで抜ける", "Stalker CHASE への遷移（統合案）", -10),
    _d("se_stalker_step_gravel_1", lambda rng: stalker_step(rng, "gravel"), "追跡者の足音（砂利）", "Stalker の歩行（統合案：材質で選び乱択）", -4, 0.01),
    _d("se_stalker_step_gravel_2", lambda rng: stalker_step(rng, "gravel"), "追跡者の足音（砂利）", "同上", -4, 0.01),
    _d("se_stalker_step_boards_1", lambda rng: stalker_step(rng, "boards"), "追跡者の足音（板）", "同上", -4, 0.01),
    _d("se_stalker_step_boards_2", lambda rng: stalker_step(rng, "boards"), "追跡者の足音（板）", "同上", -4, 0.01),
    {"id": "se_stalker_chase_loop", "kind": "se", "loop": True, "stereo": False, "crossfade": 0.5, "lufs_offset": -12, "render": stalker_chase_loop, "allow_silence": True,
     "note": "追跡中の 8 秒ループ。呼吸の速さでうねる低いノイズと 40 Hz の圧。心拍の帯域を避ける", "use": "Stalker CHASE 中（統合案：bgm_tension の代替または併用）"},
    _d("se_stalker_lost", stalker_lost, "見失った。圧が抜けて環境が戻る", "Stalker SEARCH → RETREAT（統合案）", -14, 0.1),
    {"id": "se_heartbeat", "kind": "se", "loop": True, "stereo": False, "crossfade": 0.05, "lufs_offset": -8, "render": heartbeat, "allow_silence": True,
     "note": "既存 ID。心拍 62 bpm、4 拍ちょうどのループ。60–110 Hz、鈍く", "use": "AudioManager.set_tension（現行コード）"},
    _d("se_heroine_step_1", heroine_step, "澪の足音。軽く高い", "Heroine の歩行（統合案：乱択）", -8, 0.01),
    _d("se_heroine_step_2", heroine_step, "澪の足音", "同上", -8, 0.01),
    _d("se_heroine_step_3", heroine_step, "澪の足音", "同上", -8, 0.01),
    _d("se_seal_stone", seal_stone, "封石を押し戻す。石が擦れて動き、低く据わって止まる", "8/30 封印（統合案：amb_valley_inner をここで止める）", -4, 0.1),
]
