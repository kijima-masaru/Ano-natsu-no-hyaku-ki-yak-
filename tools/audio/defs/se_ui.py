"""UI の SE。主張しない。音程のある「ピッ」は使わず、木・紙・布を触るような短い実音で作る。モノ。
既存 ID（se_menu_move / se_menu_ok / se_menu_cancel）は同名。それ以外は統合案で参照する新 ID。
"""
import numpy as np

import synth as s


def _tap(rng, sec=0.06, attack=0.001, decay=90.0, band=(600, 4000)):
    x = s.white(sec, rng) * s.exp_decay(sec, decay, attack)
    return s.bpf(x, band[0], band[1], 2)


def _wood(rng, sec, f1, f2, q=14, decay=80.0, band=(500, 5000)):
    """乾いた木片を軽く当てたような 1 音。共鳴 2 モード"""
    return s.resonant_body(_tap(rng, sec, 0.0008, decay, band), [(f1, q, 1.0), (f2, q + 6, 0.35)])


def _paper(rng, sec, attack, hold, rel, band=(900, 6000), gain=1.0):
    return s.bpf(s.white(sec, rng), band[0], band[1], 2) * s.adsr(sec, attack, hold, 0.5, rel) * gain


def menu_move(rng):
    """カーソル移動。木片を指で軽く弾いた程度。40 ms"""
    return _wood(rng, 0.05, 1900, 3300, 16, 140, (900, 6000)) * 0.8


def menu_ok(rng):
    """決定。移動の音より少し低く、僅かに長い。2 打ではなく 1 打で「置く」"""
    x = _wood(rng, 0.09, 1300, 2500, 12, 70, (500, 5000))
    return s.mix(x, s.sine(180 * rng.uniform(0.98, 1.02), 0.05) * s.exp_decay(0.05, 90, 0.001) * 0.25)


def menu_cancel(rng):
    """キャンセル。決定より鈍く低い。「戻す」感じ。ローパスで丸める"""
    x = s.lpf(_wood(rng, 0.1, 700, 1400, 9, 55, (250, 3000)), 2200, 2)
    return s.mix(x, s.sine(120 * rng.uniform(0.98, 1.02), 0.07) * s.exp_decay(0.07, 70, 0.001) * 0.3)


def menu_error(rng):
    """無効操作。鈍い 2 打（70 ms 間隔）。音程を付けず「引っかかった」だけを伝える"""
    n = s.n_samples(0.2)
    out = np.zeros(n, np.float32)
    for k, at in enumerate((0.0, 0.07)):
        p = s.lpf(_wood(rng, 0.09, 380, 760, 7, 60, (150, 2000)), 1500, 2) * (1.0 if k == 0 else 0.8)
        i = s.n_samples(at)
        out[i:i + len(p)] += p[: n - i]
    return out


def text_tick(rng):
    """文字送り。極めて控えめな 12 ms のクリック。連打されるので高域を削り、目標も -34 LUFS"""
    x = s.bpf(s.white(0.015, rng), 1500, 4500, 2) * s.exp_decay(0.015, 300, 0.0005)
    return s.lpf(x, 3500, 2)


def save(rng):
    """セーブ。鉛筆で短く 2 画書き留める。報酬感を出さない"""
    n = s.n_samples(0.4)
    out = np.zeros(n, np.float32)
    for at, sec in ((0.0, 0.14), (0.17, 0.2)):
        stroke = s.bpf(s.white(sec, rng), 1800, 7000, 2) * s.adsr(sec, 0.02, 0.05, 0.6, 0.06)
        stroke = s.mix(stroke, s.resonator(stroke, rng.uniform(2400, 3000), 10, 0.3)) * 0.6
        i = s.n_samples(at)
        out[i:i + len(stroke)] += stroke[: n - i]
    return s.mix(out, _tap(rng, 0.03, 0.001, 200, (400, 2500)) * 0.25)


def load(rng):
    """ロード。畳んだ紙を開く。擦れ 2 回と紙の張り"""
    n = s.n_samples(0.5)
    out = np.zeros(n, np.float32)
    for at, sec, g in ((0.0, 0.22, 0.8), (0.24, 0.26, 0.6)):
        p = _paper(rng, sec, 0.03, 0.06, 0.12, (700, 5500), g)
        i = s.n_samples(at)
        out[i:i + len(p)] += p[: n - i]
    snap = s.resonant_body(_tap(rng, 0.06, 0.001, 120, (300, 2500)), [(rng.uniform(420, 520), 8, 1.0)]) * 0.35
    i = s.n_samples(0.4)
    out[i:i + len(snap)] += snap[: n - i]
    return out


def evidence_add(rng):
    """証拠が増える。ノートに紙を挟む 1 動作。擦れ → 軽く押さえる"""
    slip = _paper(rng, 0.25, 0.02, 0.05, 0.1, (900, 6000), 0.6)
    press = s.lpf(_tap(rng, 0.1, 0.004, 40, (100, 900)), 800, 2) * 0.6
    n = s.n_samples(0.35)
    out = np.zeros(n, np.float32)
    out[: len(slip)] += slip
    i = s.n_samples(0.2)
    out[i:i + len(press)] += press[: n - i]
    return out


def page_turn(rng):
    """ノートのページ送り。1 枚の紙がめくれて落ちる"""
    lift = _paper(rng, 0.18, 0.04, 0.04, 0.08, (1200, 7000), 0.5)
    fall = _paper(rng, 0.14, 0.005, 0.03, 0.08, (600, 4000), 0.7)
    n = s.n_samples(0.36)
    out = np.zeros(n, np.float32)
    out[: len(lift)] += lift
    i = s.n_samples(0.2)
    out[i:i + len(fall)] += fall[: n - i]
    return out


def sleep(rng):
    """就寝。長い息を吐くような低いノイズの膨らみと減衰。1.8 秒。音程を持たない"""
    sec = 1.8
    env = s.adsr(sec, 0.5, 0.2, 0.7, 1.0)
    breath = s.lpf(s.pink(sec, rng), 600, 2) * env
    body = s.lpf(s.brown(sec, rng), 120, 2) * env * 0.6
    return s.mix(breath, body)


def day_advance(rng):
    """日付が進む（朝）。遠くで 1 回だけ鳴る低い鈍い音（何かを閉じた音）と、それに続く短い静けさ。
    鐘や旋律は使わない。8 月が減っていくことを「区切り」としてだけ示す"""
    sec = 1.6
    hit = s.resonant_body(s.lpf(s.white(0.4, rng) * s.exp_decay(0.4, 12, 0.003), 500, 2), [(rng.uniform(52, 58), 12, 1.0), (rng.uniform(140, 160), 10, 0.3)])
    hit = s.fit(hit, s.n_samples(sec))
    hush = s.lpf(s.pink(sec, rng), 400, 2) * s.adsr(sec, 0.3, 0.2, 0.5, 0.9) * 0.12
    return s.mix(hit, hush)


def _d(id_, render, note, use, off, fade_out=0.01):
    return {"id": id_, "kind": "se", "loop": False, "stereo": False, "fade_out": fade_out, "lufs_offset": off, "render": render, "note": note, "use": use}


DEFS = [
    _d("se_menu_move", menu_move, "既存 ID。カーソル移動。木片を指で弾く程度", "SettingsMenu / MenuList（現行コード）", -12),
    _d("se_menu_ok", menu_ok, "既存 ID。決定。1 打で置く", "SettingsMenu / events の play_sound（現行コード）", -10),
    _d("se_menu_cancel", menu_cancel, "既存 ID。キャンセル。鈍く低い", "SettingsMenu（現行コード）", -12),
    _d("se_menu_error", menu_error, "無効操作。鈍い 2 打、音程なし", "MenuList の無効項目（統合案）", -12),
    _d("se_text_tick", text_tick, "文字送り。12 ms、極めて控えめ", "DialogueWindow の文字送り（統合案。2〜3 文字に 1 回）", -18, 0.003),
    _d("se_save", save, "セーブ。鉛筆で 2 画書き留める", "SlotMenu の保存（統合案）", -10, 0.02),
    _d("se_load", load, "ロード。畳んだ紙を開く", "SlotMenu の読込（統合案）", -10, 0.02),
    _d("se_evidence_add", evidence_add, "証拠が増える。ノートに紙を挟む", "GameState.add_evidence（統合案）", -10, 0.02),
    _d("se_notebook_page", page_turn, "ノートのページ送り", "Notebook のページ切替（統合案）", -12, 0.02),
    _d("se_sleep", sleep, "就寝。長い息のような低いノイズ", "advance_day の前（統合案）", -8, 0.1),
    _d("se_day_advance", day_advance, "日付が進む。遠くの低い 1 打と短い静けさ", "advance_day の日付表示（統合案）", -6, 0.1),
]
