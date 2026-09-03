"""ナツの音。主人公に取り憑いた怪異。姿は見せず、声（テキスト）と環境の微細な変化（presence_pulse）としてのみ存在する。モノ。

設計（docs/AUDIO_SPEC.md §10）：
- 本作の他の音はすべて「遠く・反響の中」にある。ナツだけは **乾いて近い**（残響を一切掛けない）。隣にいる音
- 音色は 7/31 の夜に主人公が唯一「安全だ」と感じた自販機の灯りのハムから作る。96 Hz とその上の部分音が 0.4 Hz でゆっくり
  うねる、温かい低いトーンと、声にならない僅かな息（400–1200 Hz のノイズ）。旋律も和声も持たない
- ただし部分音の比は薬師谷の「裂け目の口」（amb_valley_inner）と同じ **不協和な比（1 : 1.498 : 2.03 : 2.77）** を、
  4 倍の音域で小さく重ねてある。序盤は温かさの「厚み」としてしか聞こえない。8/30 に谷でその比を大音量で聞いたあと、
  同じ音が同じ比を持っていたことに気づく。ファイルは 1 つで、切り替えはしない。意味だけが反転する
- 強さ（strength）に応じて 3 段。弱＝灯りが一瞬強まる程度／中＝足音が一組増える（ごく柔らかい二連の置き音）／
  強＝谷の比が聞き取れる長さまで伸びる
- 叫び、囁き声、笑い声、呼吸のリズムは使わない
"""
import numpy as np

import synth as s

BASE = 96.0
VALLEY_RATIOS = ((1.0, 1.0), (1.498, 0.45), (2.03, 0.3), (2.77, 0.18))


def _warm(sec, rng, valley_gain=0.12):
    """温かい低いトーン。96 Hz の 2 本がわずかにずれて 0.4 Hz でうねる。上に谷の比の部分音を 4 倍音域で小さく"""
    t = s.t_axis(sec)
    x = np.sin(2 * np.pi * BASE * t) + np.sin(2 * np.pi * (BASE + 0.4) * t + 1.0)
    x += 0.35 * np.sin(2 * np.pi * BASE * 2.0 * t + 0.5)
    for ratio, a in VALLEY_RATIOS:
        beat = 1 + 0.003 * np.sin(2 * np.pi * rng.uniform(0.05, 0.1) * t + rng.uniform(0, 6.28))
        x += a * valley_gain * np.sin(2 * np.pi * BASE * 4.0 * ratio * beat * t)
    return s.lpf(x.astype(np.float32) / 3.0, 900, 2)


def _air(sec, rng, level=0.12):
    """声にならない息。リズムは付けない"""
    return s.bpf(s.pink(sec, rng), 400, 1200, 2) * (0.7 + 0.3 * s.wander(sec, rng, 0.8, 1.0)) * level


def pulse(rng, strength):
    if strength == "weak":
        sec = 0.9
        env = s.adsr(sec, 0.25, 0.1, 0.8, 0.5)
        return s.mix(_warm(sec, rng, 0.08) * env, _air(sec, rng, 0.05) * env)
    if strength == "mid":
        sec = 1.6
        env = s.adsr(sec, 0.35, 0.2, 0.7, 0.8)
        out = s.mix(_warm(sec, rng, 0.12) * env, _air(sec, rng, 0.08) * env)
        # 足音が一組増える：ごく柔らかい二連の置き音（主人公の足音とは別物。打面を持たない）
        for at in (0.55, 0.95):
            soft = s.lpf(s.white(0.09, rng), 350, 2) * s.exp_decay(0.09, 40, 0.008)
            s.place(out, soft, at, 0.35)
        return out
    sec = 2.6
    env = s.adsr(sec, 0.5, 0.3, 0.75, 1.3)
    return s.mix(_warm(sec, rng, 0.2) * env, _air(sec, rng, 0.1) * env)


def speak(rng):
    """ナツが話し始める。息を一つ吸うような 0.6 秒。トーンはほとんど聞こえない大きさで下に敷く"""
    sec = 0.6
    intake = s.bpf(s.pink(sec, rng), 500, 1500, 2) * s.adsr(sec, 0.2, 0.1, 0.5, 0.25) * 0.2
    return s.mix(intake, _warm(sec, rng, 0.1) * s.adsr(sec, 0.15, 0.1, 0.6, 0.3) * 0.3)


def text_tick(rng):
    """ナツの文字送り。通常の文字送り（se_text_tick）より低く柔らかい。18 ms"""
    x = s.lpf(s.white(0.02, rng), 1200, 2) * s.exp_decay(0.02, 220, 0.001)
    return s.mix(x, s.sine(BASE * 2, 0.02) * s.exp_decay(0.02, 150, 0.001) * 0.5)


def luck(rng):
    """不自然な幸運（追跡者が主人公を避ける、主人公だけ助かる）。強いパルスを逆向きに：急に現れ、ゆっくり消える。「何かが逸れた」"""
    sec = 2.2
    n = s.n_samples(sec)
    env = np.concatenate([np.linspace(0, 1, s.n_samples(0.04)), np.linspace(1, 0, n - s.n_samples(0.04)) ** 2]).astype(np.float32)
    return s.mix(_warm(sec, rng, 0.2) * env, _air(sec, rng, 0.12) * env)


def _d(id_, render, note, use, off, fade_out=0.05):
    return {"id": id_, "kind": "se", "loop": False, "stereo": False, "fade_out": fade_out, "lufs_offset": off, "render": render, "note": note, "use": use}


DEFS = [
    _d("se_natsu_pulse_weak", lambda rng: pulse(rng, "weak"), "気配・弱。灯りが一瞬強まる程度の温かいトーン 0.9 秒", "presence_pulse strength < 0.45（統合案）", -16),
    _d("se_natsu_pulse_mid", lambda rng: pulse(rng, "mid"), "気配・中。トーンに、柔らかい二連の置き音（足音が一組増える）", "presence_pulse 0.45〜0.75（統合案）", -14),
    _d("se_natsu_pulse_strong", lambda rng: pulse(rng, "strong"), "気配・強。谷の比の部分音が聞き取れる長さ 2.6 秒", "presence_pulse ≥ 0.75（統合案）", -12),
    _d("se_natsu_speak", speak, "ナツが話し始める。息を一つ吸う 0.6 秒", "AttachedEntity.speak の吹き出し表示時（統合案）", -18),
    _d("se_natsu_text_tick", text_tick, "ナツの文字送り。低く柔らかい 18 ms", "話者 natsu の文字送り（統合案）", -22, 0.004),
    _d("se_natsu_luck", luck, "不自然な幸運。急に現れゆっくり消える", "AttachedEntity.luck_triggered（統合案）", -12, 0.1),
]
