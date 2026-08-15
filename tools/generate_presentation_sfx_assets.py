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
MANIFEST_PATH = ROOT / "content" / "presentation_sfx_manifest.json"
SAMPLE_RATE = 44100
CHANNEL_COUNT = 2
SAMPLE_WIDTH_BYTES = 2

SPECS = {
    "audio_placeholder_artifact_claim": {
        "kind": "relic_reveal",
        "fundamental": 392.0,
        "metal": 1176.0,
        "peak": 0.64,
        "pan": 0.08,
    },
    "audio_placeholder_artifact_equip": {
        "kind": "buckle_lock",
        "fundamental": 246.0,
        "metal": 1320.0,
        "peak": 0.55,
        "pan": -0.08,
    },
    "audio_placeholder_artifact_stow": {
        "kind": "satchel_stow",
        "fundamental": 164.0,
        "metal": 620.0,
        "peak": 0.52,
        "pan": 0.06,
    },
    "audio_placeholder_resource_tick": {
        "kind": "coin_tick",
        "fundamental": 880.0,
        "metal": 1760.0,
        "peak": 0.50,
        "pan": 0.12,
    },
    "audio_placeholder_spell_school_soft": {
        "kind": "arcane_swell",
        "fundamental": 294.0,
        "metal": 882.0,
        "peak": 0.58,
        "pan": -0.03,
    },
    "audio_placeholder_save_confirm": {
        "kind": "ledger_seal",
        "fundamental": 523.0,
        "metal": 1046.0,
        "peak": 0.54,
        "pan": 0.04,
    },
    "audio_placeholder_load_resume": {
        "kind": "continuity_chime",
        "fundamental": 330.0,
        "metal": 990.0,
        "peak": 0.58,
        "pan": -0.05,
    },
    "audio_placeholder_town_build": {
        "kind": "masonry_seal",
        "fundamental": 118.0,
        "metal": 760.0,
        "peak": 0.68,
        "pan": -0.06,
    },
    "audio_placeholder_recruit": {
        "kind": "muster_call",
        "fundamental": 92.0,
        "metal": 510.0,
        "peak": 0.64,
        "pan": 0.07,
    },
}


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge0 == edge1:
        return 0.0
    x = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return x * x * (3.0 - 2.0 * x)


def envelope(progress: float) -> float:
    return smoothstep(0.0, 0.018, progress) * (1.0 - smoothstep(0.72, 1.0, progress))


def layered_sample(kind: str, fundamental: float, metal: float, t: float, progress: float, noise: float, phase: float) -> float:
    transient = math.exp(-progress * 26.0)
    if kind == "masonry_seal":
        impact = math.sin(math.tau * fundamental * t + phase) * 0.44
        hammer = math.sin(math.tau * metal * t - phase * 0.6) * 0.24
        dust = noise * (0.42 * transient + 0.08 * (1.0 - progress))
        completion = math.sin(math.tau * metal * 1.49 * t + phase * 1.2) * max(0.0, 1.0 - abs(progress - 0.47) / 0.34) * 0.25
        return (impact + hammer + dust + completion) * envelope(progress)
    if kind == "muster_call":
        drum = math.sin(math.tau * fundamental * t + phase) * (0.42 + transient * 0.18)
        horn = math.sin(math.tau * metal * t - phase * 0.8) * 0.24
        overtone = math.sin(math.tau * metal * 1.5 * t + phase) * 0.14
        second_beat = max(0.0, 1.0 - abs(progress - 0.43) / 0.11) * (drum * 0.46 + noise * 0.18)
        return (drum + horn + overtone + second_beat + noise * transient * 0.13) * envelope(progress)
    if kind == "relic_reveal":
        shimmer = math.sin(math.tau * metal * t + phase) * 0.24
        octave = math.sin(math.tau * metal * 1.5 * t - phase) * 0.16
        body = math.sin(math.tau * fundamental * t + phase * 0.4) * 0.32
        reveal = smoothstep(0.08, 0.38, progress) * (1.0 - smoothstep(0.64, 1.0, progress))
        return (body + shimmer + octave + noise * transient * 0.10 + shimmer * reveal * 0.35) * envelope(progress)
    if kind == "buckle_lock":
        clasp = math.sin(math.tau * fundamental * t + phase) * 0.30
        click = math.sin(math.tau * metal * t - phase) * 0.25 + noise * transient * 0.30
        second = max(0.0, 1.0 - abs(progress - 0.31) / 0.08) * (clasp + click) * 0.42
        return (clasp + click + second) * envelope(progress)
    if kind == "satchel_stow":
        cloth = noise * (0.30 * transient + 0.18 * (1.0 - progress))
        close = math.sin(math.tau * fundamental * t + phase) * 0.34
        latch = math.sin(math.tau * metal * t - phase) * max(0.0, 1.0 - abs(progress - 0.62) / 0.18) * 0.24
        return (cloth + close + latch) * envelope(progress)
    if kind == "coin_tick":
        bright = math.sin(math.tau * fundamental * t + phase) * 0.34
        edge = math.sin(math.tau * metal * t - phase) * 0.25
        cascade = max(0.0, 1.0 - abs(progress - 0.36) / 0.16) * math.sin(math.tau * metal * 1.26 * t + phase) * 0.24
        return (bright + edge + cascade + noise * transient * 0.08) * envelope(progress)
    if kind == "arcane_swell":
        body = math.sin(math.tau * fundamental * (0.86 + progress * 0.18) * t + phase) * 0.30
        harmonic = math.sin(math.tau * metal * t - phase * 0.7) * 0.20
        air = noise * (0.08 + max(0.0, math.sin(math.pi * progress)) * 0.14)
        pulse = math.sin(math.tau * 5.0 * progress) * harmonic * 0.28
        return (body + harmonic + air + pulse) * envelope(progress)
    if kind == "ledger_seal":
        stamp = math.sin(math.tau * fundamental * t + phase) * 0.32
        rim = math.sin(math.tau * metal * t - phase) * 0.22
        confirmation = max(0.0, 1.0 - abs(progress - 0.38) / 0.14) * math.sin(math.tau * metal * 1.5 * t) * 0.20
        return (stamp + rim + confirmation + noise * transient * 0.12) * envelope(progress)
    if kind == "continuity_chime":
        root = math.sin(math.tau * fundamental * t + phase) * 0.30
        bell = math.sin(math.tau * metal * t - phase) * 0.22
        rise = smoothstep(0.0, 0.48, progress) * (1.0 - smoothstep(0.62, 1.0, progress))
        return (root + bell + bell * rise * 0.38 + noise * transient * 0.08) * envelope(progress)
    raise ValueError(f"Unsupported presentation sound kind: {kind}")


def render_stereo(cue_id: str, duration_msec: int) -> list[tuple[float, float]]:
    spec = SPECS[cue_id]
    frame_count = max(1, int(SAMPLE_RATE * duration_msec / 1000.0))
    left_rng = random.Random(f"{cue_id}:left:presentation-production-v1")
    right_rng = random.Random(f"{cue_id}:right:presentation-production-v1")
    pan = float(spec["pan"])
    angle = (pan + 1.0) * math.pi * 0.25
    frames: list[tuple[float, float]] = []
    for index in range(frame_count):
        progress = index / max(1, frame_count - 1)
        t = index / SAMPLE_RATE
        left = layered_sample(str(spec["kind"]), float(spec["fundamental"]), float(spec["metal"]), t, progress, left_rng.random() * 2.0 - 1.0, -0.19)
        right = layered_sample(str(spec["kind"]), float(spec["fundamental"]), float(spec["metal"]), t, progress, right_rng.random() * 2.0 - 1.0, 0.21)
        frames.append((left * math.cos(angle), right * math.sin(angle)))
    mean_left = sum(frame[0] for frame in frames) / len(frames)
    mean_right = sum(frame[1] for frame in frames) / len(frames)
    dc_free = [(left - mean_left, right - mean_right) for left, right in frames]
    peak = max(max(abs(left), abs(right)) for left, right in dc_free)
    if peak <= 1.0e-8:
        raise ValueError(f"Rendered silent presentation cue: {cue_id}")
    scale = float(spec["peak"]) / peak
    fade_frames = max(8, int(SAMPLE_RATE * 0.004))
    result: list[tuple[float, float]] = []
    for index, (left, right) in enumerate(dc_free):
        edge_gain = 1.0
        if index < fade_frames:
            edge_gain *= smoothstep(0.0, float(fade_frames), float(index))
        remaining = frame_count - 1 - index
        if remaining < fade_frames:
            edge_gain *= smoothstep(0.0, float(fade_frames), float(remaining))
        result.append((left * scale * edge_gain, right * scale * edge_gain))
    return result


def write_wav(path: Path, cue_id: str, duration_msec: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = bytearray()
    for left, right in render_stereo(cue_id, duration_msec):
        payload.extend(struct.pack("<hh", int(max(-1.0, min(1.0, left)) * 32767.0), int(max(-1.0, min(1.0, right)) * 32767.0)))
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(CHANNEL_COUNT)
        handle.setsampwidth(SAMPLE_WIDTH_BYTES)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(bytes(payload))


def main() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    cues = manifest.get("cues", {})
    if set(cues) != set(SPECS):
        raise SystemExit(f"Manifest/spec cue mismatch: manifest={sorted(cues)} specs={sorted(SPECS)}")
    if int(manifest.get("sample_rate_hz", 0)) != SAMPLE_RATE or int(manifest.get("channel_count", 0)) != CHANNEL_COUNT or int(manifest.get("sample_width_bits", 0)) != SAMPLE_WIDTH_BYTES * 8:
        raise SystemExit("Manifest audio format does not match production generator")
    hashes: list[str] = []
    for cue_id, cue in sorted(cues.items()):
        output_path = ROOT / str(cue["path"]).removeprefix("res://")
        write_wav(output_path, cue_id, int(cue["duration_msec"]))
        hashes.append(hashlib.sha256(output_path.read_bytes()).hexdigest())
    print(json.dumps({
        "asset_tier": "production_layered_v1",
        "channel_count": CHANNEL_COUNT,
        "cue_count": len(cues),
        "pack_signature": hashlib.sha256("\n".join(hashes).encode("utf-8")).hexdigest(),
        "sample_rate_hz": SAMPLE_RATE,
        "sample_width_bits": SAMPLE_WIDTH_BYTES * 8,
        "unique_hash_count": len(set(hashes)),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
