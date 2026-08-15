#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import math
import random
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "content" / "ui_sfx_manifest.json"
SAMPLE_RATE = 44100
CHANNEL_COUNT = 2
SAMPLE_WIDTH_BYTES = 2

# The six cues keep their existing identity, duration, volume, and runtime role.
# Each profile supplies a distinct material gesture instead of a pitched beep:
# latch, glass pluck, ratchet, page turn, seal chime, and wooden denial knock.
SPECS = {
    "ui_click": {"kind": "latch", "f1": 1180.0, "f2": 2420.0, "f3": 410.0, "noise": 0.32, "peak": 0.46, "pan": -0.08, "width": 0.14},
    "ui_select": {"kind": "glass_pluck", "f1": 840.0, "f2": 1390.0, "f3": 2220.0, "noise": 0.07, "peak": 0.42, "pan": 0.10, "width": 0.25},
    "ui_adjust": {"kind": "ratchet", "f1": 690.0, "f2": 1720.0, "f3": 320.0, "noise": 0.28, "peak": 0.35, "pan": -0.14, "width": 0.12},
    "ui_tab": {"kind": "page_turn", "f1": 240.0, "f2": 930.0, "f3": 2460.0, "noise": 0.58, "peak": 0.39, "pan": 0.16, "width": 0.33},
    "ui_confirm": {"kind": "seal_chime", "f1": 620.0, "f2": 930.0, "f3": 1395.0, "noise": 0.035, "peak": 0.49, "pan": 0.02, "width": 0.29},
    "ui_invalid": {"kind": "wood_denial", "f1": 142.0, "f2": 218.0, "f3": 465.0, "noise": 0.26, "peak": 0.51, "pan": -0.04, "width": 0.10},
}


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge0 == edge1:
        return 0.0
    x = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return x * x * (3.0 - 2.0 * x)


def triangle(phase: float) -> float:
    wrapped = phase - math.floor(phase)
    return 4.0 * abs(wrapped - 0.5) - 1.0


def cue_envelope(progress: float, kind: str) -> float:
    attack_end = {
        "latch": 0.018,
        "ratchet": 0.014,
        "wood_denial": 0.024,
        "page_turn": 0.045,
        "glass_pluck": 0.028,
        "seal_chime": 0.055,
    }[kind]
    release_start = {
        "latch": 0.22,
        "ratchet": 0.25,
        "wood_denial": 0.34,
        "page_turn": 0.48,
        "glass_pluck": 0.36,
        "seal_chime": 0.58,
    }[kind]
    attack = smoothstep(0.0, attack_end, progress)
    release = 1.0 - smoothstep(release_start, 1.0, progress)
    return max(0.0, min(1.0, attack * release))


def pitch_curve(kind: str, progress: float) -> float:
    if kind == "seal_chime":
        return 0.86 + progress * 0.24
    if kind == "wood_denial":
        return 1.05 - progress * 0.18
    if kind == "page_turn":
        return 0.70 + progress * 0.80
    if kind == "ratchet":
        return 1.06 - progress * 0.10
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
    f2 = float(spec["f2"]) * (0.96 + curve * 0.04)
    f3 = float(spec["f3"]) * (0.92 + curve * 0.08)
    phase1 = f1 * time_sec + channel_phase
    phase2 = f2 * time_sec - channel_phase * 0.71
    phase3 = f3 * time_sec + channel_phase * 1.33
    sine1 = math.sin(math.tau * phase1)
    sine2 = math.sin(math.tau * phase2)
    sine3 = math.sin(math.tau * phase3)
    transient = math.exp(-progress * 28.0)
    sparkle = math.sin(math.tau * (f2 * 1.91) * time_sec + channel_phase) * math.exp(-progress * 7.5)

    if kind == "latch":
        body = triangle(phase1) * 0.30 + sine2 * 0.22 + sine3 * 0.18 + white_noise * transient * 0.46
    elif kind == "glass_pluck":
        body = sine1 * 0.40 + sine2 * 0.28 + sine3 * 0.18 + sparkle * 0.26 + white_noise * transient * 0.08
    elif kind == "ratchet":
        tooth = max(0.0, math.sin(math.tau * 4.0 * progress)) ** 10
        body = triangle(phase1) * 0.27 + sine2 * 0.19 + white_noise * transient * 0.34 + smooth_noise * tooth * 0.30
    elif kind == "page_turn":
        sweep = smooth_noise * (0.52 + progress * 0.24)
        fibers = white_noise * (0.12 + max(0.0, math.sin(math.pi * progress)) * 0.32)
        body = sweep + fibers + sine1 * 0.12 + sine2 * 0.08 + sparkle * 0.06
    elif kind == "seal_chime":
        overtone = math.sin(math.tau * (f3 * 1.49) * time_sec - channel_phase)
        body = sine1 * 0.34 + sine2 * 0.31 + sine3 * 0.22 + overtone * 0.12 + sparkle * 0.15
    elif kind == "wood_denial":
        knock = sine1 * 0.54 + triangle(phase2) * 0.18 + white_noise * transient * 0.36
        second_knock = max(0.0, 1.0 - abs(progress - 0.36) / 0.12) * (sine1 * 0.28 + sine3 * 0.14)
        body = knock + second_knock + smooth_noise * 0.10
    else:
        raise ValueError(f"Unsupported UI sound-design kind: {kind}")

    noise_amount = float(spec["noise"])
    mixed = body * (1.0 - noise_amount * 0.20) + smooth_noise * noise_amount * 0.18
    return mixed * cue_envelope(progress, kind)


def render_stereo(cue_id: str, duration_msec: int) -> list[tuple[float, float]]:
    spec = SPECS[cue_id]
    frame_count = max(1, int(SAMPLE_RATE * duration_msec / 1000.0))
    rng_left = random.Random(f"{cue_id}:left:production-ui-v1")
    rng_right = random.Random(f"{cue_id}:right:production-ui-v1")
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
        smooth_left = smooth_left * 0.80 + white_left * 0.20
        smooth_right = smooth_right * 0.80 + white_right * 0.20
        left = layered_sample(spec, progress, time_sec, -width, white_left, smooth_left) * gain_left
        right = layered_sample(spec, progress, time_sec, width, white_right, smooth_right) * gain_right
        frames.append((left, right))

    mean_left = sum(frame[0] for frame in frames) / len(frames)
    mean_right = sum(frame[1] for frame in frames) / len(frames)
    dc_free = [(left - mean_left, right - mean_right) for left, right in frames]
    peak = max(max(abs(left), abs(right)) for left, right in dc_free)
    if peak <= 1.0e-8:
        raise ValueError(f"Rendered silent UI cue: {cue_id}")
    scale = float(spec["peak"]) / peak
    fade_frames = min(max(8, int(SAMPLE_RATE * 0.002)), max(8, frame_count // 10))
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


def write_wav(path: Path, cue_id: str, duration_msec: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    frames = render_stereo(cue_id, duration_msec)
    payload = bytearray()
    for left, right in frames:
        payload.extend(
            struct.pack(
                "<hh",
                int(max(-1.0, min(1.0, left)) * 32767.0),
                int(max(-1.0, min(1.0, right)) * 32767.0),
            )
        )
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
    if int(manifest.get("sample_width_bits", 0)) != SAMPLE_WIDTH_BYTES * 8:
        raise SystemExit("Manifest sample_width_bits does not match production generator")
    asset_hashes: list[str] = []
    for cue_id, cue in sorted(cues.items()):
        rel_path = str(cue["path"]).removeprefix("res://")
        output_path = ROOT / rel_path
        write_wav(output_path, cue_id, int(cue["duration_msec"]))
        asset_hashes.append(hashlib.sha256(output_path.read_bytes()).hexdigest())
    pack_signature = hashlib.sha256("\n".join(asset_hashes).encode("utf-8")).hexdigest()
    print(
        json.dumps(
            {
                "cue_count": len(cues),
                "sample_rate_hz": SAMPLE_RATE,
                "channel_count": CHANNEL_COUNT,
                "sample_width_bits": SAMPLE_WIDTH_BYTES * 8,
                "asset_tier": "production_layered_v1",
                "unique_hash_count": len(set(asset_hashes)),
                "pack_signature": pack_signature,
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
