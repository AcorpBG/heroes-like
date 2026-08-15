#!/usr/bin/env python3
from __future__ import annotations

import json
import math
import random
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "content" / "battle_sfx_manifest.json"
SAMPLE_RATE = 44100
CHANNEL_COUNT = 2
SAMPLE_WIDTH_BYTES = 2

# Each cue keeps the existing runtime identity and duration while owning a
# distinct layered synthesis profile. Peak is a post-render normalization
# target, not a mixer-volume replacement; manifest volume_db remains authority.
SPECS = {
    "audio_placeholder_ranged_release": {"kind": "pluck", "f1": 760.0, "f2": 1320.0, "f3": 2180.0, "noise": 0.18, "peak": 0.66, "pan": -0.16, "width": 0.11},
    "audio_placeholder_status_apply": {"kind": "shimmer", "f1": 310.0, "f2": 492.0, "f3": 740.0, "noise": 0.10, "peak": 0.54, "pan": 0.18, "width": 0.18},
    "audio_placeholder_melee_release": {"kind": "whoosh", "f1": 145.0, "f2": 410.0, "f3": 890.0, "noise": 0.54, "peak": 0.72, "pan": -0.12, "width": 0.22},
    "audio_placeholder_hit": {"kind": "thud", "f1": 82.0, "f2": 156.0, "f3": 570.0, "noise": 0.48, "peak": 0.74, "pan": 0.10, "width": 0.08},
    "audio_placeholder_unit_rout": {"kind": "fall", "f1": 255.0, "f2": 172.0, "f3": 92.0, "noise": 0.22, "peak": 0.58, "pan": 0.22, "width": 0.16},
    "audio_placeholder_cast": {"kind": "rise", "f1": 280.0, "f2": 560.0, "f3": 980.0, "noise": 0.08, "peak": 0.58, "pan": -0.20, "width": 0.20},
    "audio_placeholder_unit_step": {"kind": "step", "f1": 74.0, "f2": 132.0, "f3": 330.0, "noise": 0.42, "peak": 0.45, "pan": -0.08, "width": 0.06},
    "audio_placeholder_defend": {"kind": "brace", "f1": 190.0, "f2": 460.0, "f3": 1110.0, "noise": 0.16, "peak": 0.55, "pan": 0.06, "width": 0.14},
    "audio_placeholder_retaliation": {"kind": "counter", "f1": 220.0, "f2": 610.0, "f3": 1480.0, "noise": 0.30, "peak": 0.70, "pan": 0.18, "width": 0.24},
    "audio_placeholder_retreat_order": {"kind": "horn_down", "f1": 330.0, "f2": 247.0, "f3": 165.0, "noise": 0.035, "peak": 0.54, "pan": -0.22, "width": 0.13},
    "audio_placeholder_surrender_order": {"kind": "horn_soft", "f1": 294.0, "f2": 220.0, "f3": 147.0, "noise": 0.025, "peak": 0.48, "pan": 0.22, "width": 0.10},
    "audio_placeholder_turn_ready": {"kind": "ready", "f1": 620.0, "f2": 930.0, "f3": 1550.0, "noise": 0.025, "peak": 0.48, "pan": 0.0, "width": 0.20},
    "audio_placeholder_status_clear": {"kind": "clear", "f1": 390.0, "f2": 780.0, "f3": 1320.0, "noise": 0.055, "peak": 0.50, "pan": -0.18, "width": 0.23},
    "audio_placeholder_idle_soft": {"kind": "soft", "f1": 164.0, "f2": 246.0, "f3": 328.0, "noise": 0.018, "peak": 0.28, "pan": 0.0, "width": 0.09},
    "audio_spell_cinder_burst": {"kind": "burst", "f1": 92.0, "f2": 330.0, "f3": 1260.0, "noise": 0.46, "peak": 0.76, "pan": -0.24, "width": 0.26},
    "audio_spell_coal_rain": {"kind": "rain", "f1": 120.0, "f2": 470.0, "f3": 1740.0, "noise": 0.62, "peak": 0.68, "pan": 0.20, "width": 0.30},
    "audio_spell_sunlance_arc": {"kind": "lance", "f1": 540.0, "f2": 1180.0, "f3": 2360.0, "noise": 0.08, "peak": 0.74, "pan": 0.26, "width": 0.28},
    "audio_spell_briar_bind": {"kind": "bind", "f1": 105.0, "f2": 285.0, "f3": 660.0, "noise": 0.34, "peak": 0.62, "pan": -0.20, "width": 0.25},
    "audio_spell_graft_mend": {"kind": "mend", "f1": 260.0, "f2": 520.0, "f3": 1040.0, "noise": 0.055, "peak": 0.54, "pan": 0.14, "width": 0.24},
    "audio_spell_prism_bastion": {"kind": "prism", "f1": 420.0, "f2": 840.0, "f3": 1680.0, "noise": 0.035, "peak": 0.58, "pan": -0.10, "width": 0.34},
    "audio_spell_command_ward": {"kind": "ward", "f1": 165.0, "f2": 330.0, "f3": 660.0, "noise": 0.045, "peak": 0.56, "pan": 0.12, "width": 0.18},
}


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge0 == edge1:
        return 0.0
    x = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return x * x * (3.0 - 2.0 * x)


def triangle(phase: float) -> float:
    wrapped = phase - math.floor(phase)
    return 4.0 * abs(wrapped - 0.5) - 1.0


def saw(phase: float) -> float:
    return 2.0 * (phase - math.floor(phase + 0.5))


def cue_envelope(progress: float, kind: str) -> float:
    fast_attack = {"hit", "step", "brace", "burst", "ready", "counter"}
    slow_attack = {"rise", "shimmer", "mend", "prism", "ward", "rain"}
    attack_end = 0.018 if kind in fast_attack else (0.11 if kind in slow_attack else 0.055)
    release_start = {
        "hit": 0.18,
        "step": 0.16,
        "brace": 0.34,
        "pluck": 0.28,
        "ready": 0.38,
        "counter": 0.44,
        "burst": 0.42,
        "whoosh": 0.56,
        "fall": 0.64,
        "horn_down": 0.72,
        "horn_soft": 0.74,
        "soft": 0.66,
    }.get(kind, 0.68)
    attack = smoothstep(0.0, attack_end, progress)
    release = 1.0 - smoothstep(release_start, 1.0, progress)
    return max(0.0, min(1.0, attack * release))


def pitch_curve(kind: str, progress: float) -> float:
    if kind in {"rise", "ready", "lance", "clear", "mend"}:
        return 0.72 + progress * 0.70
    if kind in {"fall", "horn_down", "horn_soft", "thud"}:
        return 1.10 - progress * 0.48
    if kind == "whoosh":
        return 0.45 + progress * 1.35
    if kind == "counter":
        return 1.35 - progress * 0.70
    if kind == "burst":
        return 1.0 - progress * 0.22
    if kind == "bind":
        return 0.92 + math.sin(progress * math.pi) * 0.18
    return 1.0


def layered_sample(
    spec: dict[str, float | str],
    progress: float,
    time_sec: float,
    channel_phase: float,
    white_noise: float,
    smooth_noise: float,
) -> float:
    kind = str(spec["kind"])
    curve = pitch_curve(kind, progress)
    f1 = float(spec["f1"]) * curve
    f2 = float(spec["f2"]) * (0.94 + 0.06 * curve)
    f3 = float(spec["f3"]) * (0.90 + 0.10 * curve)
    phase1 = f1 * time_sec + channel_phase
    phase2 = f2 * time_sec - channel_phase * 0.62
    phase3 = f3 * time_sec + channel_phase * 1.47
    sine1 = math.sin(math.tau * phase1)
    sine2 = math.sin(math.tau * phase2)
    sine3 = math.sin(math.tau * phase3)
    transient = math.exp(-progress * 24.0)
    sparkle = math.sin(math.tau * (f3 * 1.73) * time_sec + channel_phase) * math.exp(-progress * 5.2)

    if kind == "pluck":
        body = sine1 * 0.48 + sine2 * 0.25 + sparkle * 0.22 + white_noise * transient * 0.22
    elif kind == "shimmer":
        tremolo = 0.78 + 0.22 * math.sin(math.tau * 7.0 * time_sec + channel_phase)
        body = (sine1 * 0.36 + sine2 * 0.30 + sine3 * 0.22) * tremolo + smooth_noise * 0.12
    elif kind == "whoosh":
        body = smooth_noise * 0.76 + sine1 * 0.20 + saw(phase2) * 0.12
    elif kind == "thud":
        body = sine1 * 0.62 + triangle(phase2) * 0.20 + white_noise * transient * 0.42
    elif kind == "fall":
        body = sine1 * 0.46 + sine2 * 0.26 + smooth_noise * 0.20 + saw(phase3) * 0.08
    elif kind == "rise":
        body = sine1 * 0.34 + sine2 * 0.30 + sine3 * 0.18 + sparkle * 0.18
    elif kind == "step":
        body = sine1 * 0.58 + white_noise * transient * 0.38 + smooth_noise * 0.16
    elif kind == "brace":
        body = triangle(phase1) * 0.32 + sine2 * 0.38 + sine3 * transient * 0.25 + white_noise * transient * 0.14
    elif kind == "counter":
        body = smooth_noise * 0.44 + saw(phase1) * 0.20 + sine2 * 0.28 + sine3 * transient * 0.22
    elif kind in {"horn_down", "horn_soft"}:
        breath = smooth_noise * (0.10 if kind == "horn_down" else 0.07)
        body = sine1 * 0.54 + sine2 * 0.26 + sine3 * 0.12 + breath
    elif kind == "ready":
        body = sine1 * 0.32 + sine2 * 0.34 + sine3 * 0.20 + sparkle * 0.18
    elif kind == "clear":
        body = sine1 * 0.22 + sine2 * 0.34 + sine3 * 0.24 + sparkle * 0.28 + smooth_noise * 0.05
    elif kind == "soft":
        body = sine1 * 0.52 + sine2 * 0.24 + sine3 * 0.10 + smooth_noise * 0.05
    elif kind == "burst":
        body = sine1 * 0.42 + triangle(phase2) * 0.20 + white_noise * transient * 0.62 + smooth_noise * 0.22 + sparkle * 0.12
    elif kind == "rain":
        droplets = max(0.0, math.sin(math.tau * (17.0 + channel_phase) * time_sec)) ** 8
        body = smooth_noise * 0.54 + white_noise * droplets * 0.34 + sine1 * 0.18 + sine2 * 0.14
    elif kind == "lance":
        body = sine1 * 0.30 + sine2 * 0.34 + sine3 * 0.24 + sparkle * 0.24 + white_noise * transient * 0.08
    elif kind == "bind":
        pulse = 0.70 + 0.30 * math.sin(math.tau * 9.0 * time_sec + channel_phase)
        body = (saw(phase1) * 0.26 + triangle(phase2) * 0.24 + sine3 * 0.18) * pulse + smooth_noise * 0.34
    elif kind == "mend":
        body = sine1 * 0.28 + sine2 * 0.34 + sine3 * 0.20 + sparkle * 0.24 + smooth_noise * 0.04
    elif kind == "prism":
        chorus = math.sin(math.tau * (f2 * 1.006) * time_sec - channel_phase)
        body = sine1 * 0.22 + sine2 * 0.25 + chorus * 0.22 + sine3 * 0.20 + sparkle * 0.16
    elif kind == "ward":
        pulse = 0.78 + 0.22 * math.sin(math.tau * 5.0 * time_sec + channel_phase)
        body = (sine1 * 0.42 + sine2 * 0.28 + sine3 * 0.16) * pulse + smooth_noise * 0.06
    else:
        raise ValueError(f"Unsupported sound-design kind: {kind}")

    noise_amount = float(spec["noise"])
    mixed = body * (1.0 - noise_amount * 0.26) + smooth_noise * noise_amount * 0.20
    return mixed * cue_envelope(progress, kind)


def render_stereo(audio_id: str, duration_msec: int) -> list[tuple[float, float]]:
    spec = SPECS[audio_id]
    frame_count = max(1, int(SAMPLE_RATE * duration_msec / 1000.0))
    rng_left = random.Random(f"{audio_id}:left:production-layered-v1")
    rng_right = random.Random(f"{audio_id}:right:production-layered-v1")
    smooth_left = 0.0
    smooth_right = 0.0
    width = float(spec["width"])
    pan = max(-0.9, min(0.9, float(spec["pan"])))
    pan_angle = (pan + 1.0) * math.pi * 0.25
    gain_left = math.cos(pan_angle)
    gain_right = math.sin(pan_angle)
    frames: list[tuple[float, float]] = []
    for index in range(frame_count):
        progress = index / max(1, frame_count - 1)
        time_sec = index / SAMPLE_RATE
        white_left = rng_left.random() * 2.0 - 1.0
        white_right = rng_right.random() * 2.0 - 1.0
        smooth_left = smooth_left * 0.84 + white_left * 0.16
        smooth_right = smooth_right * 0.84 + white_right * 0.16
        left = layered_sample(spec, progress, time_sec, -width, white_left, smooth_left) * gain_left
        right = layered_sample(spec, progress, time_sec, width, white_right, smooth_right) * gain_right
        frames.append((left, right))

    mean_left = sum(frame[0] for frame in frames) / len(frames)
    mean_right = sum(frame[1] for frame in frames) / len(frames)
    dc_free = [(left - mean_left, right - mean_right) for left, right in frames]
    peak = max(max(abs(left), abs(right)) for left, right in dc_free)
    if peak <= 1.0e-8:
        raise ValueError(f"Rendered silent cue: {audio_id}")
    target_peak = float(spec["peak"])
    scale = target_peak / peak
    fade_frames = min(max(8, int(SAMPLE_RATE * 0.004)), max(8, frame_count // 8))
    result: list[tuple[float, float]] = []
    for index, (left, right) in enumerate(dc_free):
        edge_gain = 1.0
        if index < fade_frames:
            edge_gain *= smoothstep(0.0, float(fade_frames), float(index))
        tail_index = frame_count - 1 - index
        if tail_index < fade_frames:
            edge_gain *= smoothstep(0.0, float(fade_frames), float(tail_index))
        result.append((left * scale * edge_gain, right * scale * edge_gain))
    return result


def write_wav(path: Path, audio_id: str, duration_msec: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    frames = render_stereo(audio_id, duration_msec)
    payload = bytearray()
    for left, right in frames:
        payload.extend(struct.pack("<hh", int(max(-1.0, min(1.0, left)) * 32767.0), int(max(-1.0, min(1.0, right)) * 32767.0)))
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(CHANNEL_COUNT)
        handle.setsampwidth(SAMPLE_WIDTH_BYTES)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(bytes(payload))


def main() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    cues = manifest.get("cues", {})
    missing = sorted(set(SPECS) - set(cues))
    extra = sorted(set(cues) - set(SPECS))
    if missing or extra:
        raise SystemExit(f"Manifest/spec cue mismatch: missing={missing} extra={extra}")
    if int(manifest.get("sample_rate_hz", 0)) != SAMPLE_RATE:
        raise SystemExit("Manifest sample_rate_hz does not match production generator")
    if int(manifest.get("channel_count", 0)) != CHANNEL_COUNT:
        raise SystemExit("Manifest channel_count does not match production generator")
    for audio_id, cue in sorted(cues.items()):
        rel_path = str(cue["path"]).removeprefix("res://")
        write_wav(ROOT / rel_path, audio_id, int(cue["duration_msec"]))
    print(
        json.dumps(
            {
                "cue_count": len(cues),
                "sample_rate_hz": SAMPLE_RATE,
                "channel_count": CHANNEL_COUNT,
                "sample_width_bits": SAMPLE_WIDTH_BYTES * 8,
                "asset_tier": "production_layered_v1",
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
