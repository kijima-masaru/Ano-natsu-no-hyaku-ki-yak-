"""仕上げ：ラウドネス（ITU-R BS.1770 K 特性、ゲート付き）、ピーク制限、フェード、シームレスループ、DC 除去、OGG 書き出し。

系統ごとの目標（docs/AUDIO_SPEC.md）：環境音 -28 LUFS、BGM -20 LUFS、SE -16 LUFS、ピーク -3 dBFS 以下。
"""
from __future__ import annotations

import os
import subprocess

import numpy as np
import soundfile as sf
from scipy import signal

from synth import soft_clip, SR, n_samples, to_stereo

TARGET_LUFS = {"ambience": -28.0, "bgm": -20.0, "se": -16.0}
PEAK_DBFS = -3.0
CODEC_MARGIN_DB = 0.5  # Vorbis 復号後にピークが僅かに膨らむ分の余裕（クリック的な音で 0.4 dB 程度膨らむのを確認）
LEAD_PAD_SEC = 0.01  # 単発音の先頭無音。Vorbis のプリエコーが先頭サンプルに乗ってクリックになるのを避ける
OGG_QUALITY = {"ambience": 0.4, "bgm": 0.5, "se": 0.5}


# ── ラウドネス（BS.1770-4） ──

def _k_weighting():
    """K 特性の 2 段 biquad（高域シェルフ ＋ ハイパス）。係数はサンプリングレートから設計する（pyloudnorm と同じ設計式）"""
    def shelf(fc, gain_db, q):
        a = 10 ** (gain_db / 40)
        w0 = 2 * np.pi * fc / SR
        alpha = np.sin(w0) / (2 * q)
        cosw = np.cos(w0)
        b0 = a * ((a + 1) + (a - 1) * cosw + 2 * np.sqrt(a) * alpha)
        b1 = -2 * a * ((a - 1) + (a + 1) * cosw)
        b2 = a * ((a + 1) + (a - 1) * cosw - 2 * np.sqrt(a) * alpha)
        a0 = (a + 1) - (a - 1) * cosw + 2 * np.sqrt(a) * alpha
        a1 = 2 * ((a - 1) - (a + 1) * cosw)
        a2 = (a + 1) - (a - 1) * cosw - 2 * np.sqrt(a) * alpha
        return np.array([b0, b1, b2]) / a0, np.array([a0, a1, a2]) / a0

    def highpass(fc, q):
        w0 = 2 * np.pi * fc / SR
        alpha = np.sin(w0) / (2 * q)
        cosw = np.cos(w0)
        b = np.array([(1 + cosw) / 2, -(1 + cosw), (1 + cosw) / 2])
        a = np.array([1 + alpha, -2 * cosw, 1 - alpha])
        return b / a[0], a / a[0]

    return shelf(1681.974450955533, 3.999843853973347, 0.7071752369554196), highpass(38.13547087602444, 0.5003270373238773)


def loudness_lufs(x: np.ndarray) -> float:
    """統合ラウドネス（LUFS）。モノは左右同一のステレオとして測る（-3 dB の扱いは BS.1770 のチャンネル重みに従う）"""
    s = to_stereo(x).astype(np.float64)
    (b1, a1), (b2, a2) = _k_weighting()
    y = signal.lfilter(b1, a1, s, axis=0)
    y = signal.lfilter(b2, a2, y, axis=0)
    block = n_samples(0.4)
    hop = n_samples(0.1)
    if len(y) < block:
        y = np.concatenate([y, np.zeros((block - len(y), 2))])
    powers = []
    for s0 in range(0, len(y) - block + 1, hop):
        seg = y[s0:s0 + block]
        powers.append(np.mean(seg ** 2, axis=0).sum())
    powers = np.array(powers)
    with np.errstate(divide="ignore"):
        lk = -0.691 + 10 * np.log10(powers + 1e-20)
    gated = powers[lk > -70]
    if gated.size == 0:
        return -np.inf
    rel = -0.691 + 10 * np.log10(gated.mean()) - 10
    gated = gated[(-0.691 + 10 * np.log10(gated)) > rel]
    if gated.size == 0:
        return -np.inf
    return float(-0.691 + 10 * np.log10(gated.mean()))


def peak_dbfs(x: np.ndarray) -> float:
    p = float(np.abs(x).max()) if x.size else 0.0
    return -np.inf if p <= 0 else float(20 * np.log10(p))


# ── 仕上げ ──

def remove_dc(x: np.ndarray) -> np.ndarray:
    sos = signal.butter(2, 8.0, btype="high", fs=SR, output="sos")
    return signal.sosfiltfilt(sos, x, axis=0).astype(np.float32)


def normalize_lufs(x: np.ndarray, target: float) -> np.ndarray:
    cur = loudness_lufs(x)
    if not np.isfinite(cur):
        return x
    return (x * (10 ** ((target - cur) / 20))).astype(np.float32)


def limit_peak(x: np.ndarray, ceiling_db: float = PEAK_DBFS) -> tuple[np.ndarray, float]:
    """超過分だけ全体のゲインを下げる（音色を変えない）。戻り値は (波形, 下げた dB)"""
    p = peak_dbfs(x)
    if p <= ceiling_db:
        return x, 0.0
    g = 10 ** ((ceiling_db - p) / 20)
    return (x * g).astype(np.float32), float(p - ceiling_db)


def seamless_loop(x: np.ndarray, crossfade_sec: float = 0.5) -> np.ndarray:
    """末尾 crossfade_sec を先頭に等パワーで重ねて短くする。ループ再生で継ぎ目が出ない"""
    n = n_samples(crossfade_sec)
    if n <= 0 or len(x) < 3 * n:
        return x
    head = x[:n].astype(np.float64)
    tail = x[-n:].astype(np.float64)
    t = np.linspace(0, 1, n)
    fi = np.sin(t * np.pi / 2)
    fo = np.cos(t * np.pi / 2)
    if x.ndim == 2:
        fi, fo = fi[:, None], fo[:, None]
    blended = head * fi + tail * fo
    return np.concatenate([blended, x[n:-n].astype(np.float64)]).astype(np.float32)


def fade_edges(x: np.ndarray, fade_in: float, fade_out: float) -> np.ndarray:
    from synth import fade
    return fade(x, fade_in, fade_out)


def finalize(x: np.ndarray, kind: str, loop: bool, stereo: bool, fade_in: float = 0.0, fade_out: float = 0.0, crossfade_sec: float = 0.5,
             lufs_offset: float = 0.0) -> tuple[np.ndarray, dict]:
    """共通の仕上げ。戻り値は (波形, 記録用の辞書)。lufs_offset は系統の目標からの意図的なずれ（静かな場所は負）"""
    y = to_stereo(x) if stereo else (x if x.ndim == 1 else x.mean(axis=1)).astype(np.float32)
    if len(y) >= SR:
        y = remove_dc(y)
    # 1 秒未満の単発音に 8 Hz の HPF をかけると、短い信号の平均を打ち消そうとして両端に緩やかなオフセット（クリック）が生じるので掛けない
    if loop:
        y = seamless_loop(y, crossfade_sec)
    else:
        # 先頭が非ゼロだとクリックになるので最低 0.5 ms のフェードインを保証し、プリエコー用の無音を前置する
        y = fade_edges(y, max(fade_in, 0.0005), fade_out)
        y = np.concatenate([np.zeros((n_samples(LEAD_PAD_SEC),) + y.shape[1:], np.float32), y])
    target = TARGET_LUFS[kind] + lufs_offset
    ceiling = PEAK_DBFS - CODEC_MARGIN_DB
    y = normalize_lufs(y, target)
    y, reduced = limit_peak(y, ceiling)
    drive = 0.0
    if kind == "se" and not loop and reduced > 0.5:
        # 波高率が高い（クリック的な）単発音は、ピーク制限だけでは目標ラウドネスに届かない。
        # 最上部のピークだけを tanh で丸めて（アタックを鈍らせる方針に沿う）再正規化する。最大 3 段。
        for drive in (1.5, 2.5, 4.0):
            z = soft_clip(y, drive)
            z = normalize_lufs(z, target)
            z, reduced = limit_peak(z, ceiling)
            y = z
            if reduced <= 0.5:
                break
    info = {"lufs": loudness_lufs(y), "peak_dbfs": peak_dbfs(y), "gain_reduced_db": reduced, "soft_clip_drive": drive, "seconds": len(y) / SR, "target_lufs": target}
    return y, info


# ── 書き出し ──

def ffmpeg_exe() -> str | None:
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return None


def write_ogg(path: str, x: np.ndarray, kind: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    q = OGG_QUALITY[kind]
    try:
        sf.write(path, x, SR, format="OGG", subtype="VORBIS", compression_level=1.0 - q)
    except TypeError:
        sf.write(path, x, SR, format="OGG", subtype="VORBIS")


def write_wav(path: str, x: np.ndarray) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sf.write(path, x, SR, subtype="PCM_16")


def probe_with_ffmpeg(path: str) -> str:
    exe = ffmpeg_exe()
    if not exe:
        return "ffmpeg 無し"
    r = subprocess.run([exe, "-v", "error", "-i", path, "-f", "null", "-"], capture_output=True, text=True)
    return "ok" if r.returncode == 0 and not r.stderr.strip() else r.stderr.strip()[:200]
