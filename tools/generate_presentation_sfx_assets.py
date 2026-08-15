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
    "audio_placeholder_map_step": {
        "kind": "travel_step",
        "fundamental": 196.0,
        "metal": 420.0,
        "peak": 0.48,
        "pan": -0.10,
    },
    "audio_placeholder_object_focus": {
        "kind": "compass_focus",
        "fundamental": 523.0,
        "metal": 1046.0,
        "peak": 0.48,
        "pan": 0.04,
    },
    "audio_placeholder_invalid_route": {
        "kind": "route_denial",
        "fundamental": 146.0,
        "metal": 292.0,
        "peak": 0.60,
        "pan": 0.0,
    },
    "audio_placeholder_blocked_object": {
        "kind": "object_obstruction",
        "fundamental": 110.0,
        "metal": 660.0,
        "peak": 0.62,
        "pan": -0.02,
    },
    "audio_placeholder_route_open": {
        "kind": "threshold_open",
        "fundamental": 392.0,
        "metal": 988.0,
        "peak": 0.66,
        "pan": 0.02,
    },
    "audio_placeholder_route_closed": {
        "kind": "threshold_close",
        "fundamental": 174.0,
        "metal": 522.0,
        "peak": 0.66,
        "pan": -0.02,
    },
    "audio_placeholder_object_visit": {
        "kind": "waypoint_acknowledge", "fundamental": 440.0, "metal": 880.0, "peak": 0.52, "pan": 0.08,
    },
    "audio_placeholder_capture": {
        "kind": "banner_claim", "fundamental": 262.0, "metal": 786.0, "peak": 0.65, "pan": -0.04,
    },
    "audio_placeholder_collect": {
        "kind": "cache_lift", "fundamental": 698.0, "metal": 1396.0, "peak": 0.56, "pan": 0.12,
    },
    "audio_placeholder_guard_warning": {
        "kind": "sentinel_warning", "fundamental": 196.0, "metal": 588.0, "peak": 0.62, "pan": -0.10,
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
    if kind == "travel_step":
        tread = math.sin(math.tau * fundamental * t + phase) * 0.28
        grit = noise * (0.24 * transient + 0.08 * (1.0 - progress))
        follow = max(0.0, 1.0 - abs(progress - 0.42) / 0.16) * math.sin(math.tau * metal * t - phase) * 0.20
        return (tread + grit + follow) * envelope(progress)
    if kind == "compass_focus":
        point = math.sin(math.tau * fundamental * t + phase) * 0.30
        rim = math.sin(math.tau * metal * t - phase) * 0.20
        answer = max(0.0, 1.0 - abs(progress - 0.36) / 0.14) * math.sin(math.tau * metal * 1.25 * t + phase) * 0.22
        return (point + rim + answer + noise * transient * 0.07) * envelope(progress)
    if kind == "route_denial":
        knock = math.sin(math.tau * fundamental * t + phase) * 0.34
        dissonance = math.sin(math.tau * metal * 1.06 * t - phase) * 0.24
        stop = max(0.0, 1.0 - abs(progress - 0.30) / 0.12) * (knock - dissonance) * 0.30
        return (knock + dissonance + stop + noise * transient * 0.14) * envelope(progress)
    if kind == "object_obstruction":
        impact = math.sin(math.tau * fundamental * t + phase) * 0.38
        iron = math.sin(math.tau * metal * t - phase) * 0.24
        latch = max(0.0, 1.0 - abs(progress - 0.34) / 0.10) * math.sin(math.tau * metal * 1.47 * t + phase) * 0.28
        return (impact + iron + latch + noise * transient * 0.18) * envelope(progress)
    if kind == "threshold_open":
        gate = math.sin(math.tau * fundamental * (0.88 + progress * 0.18) * t + phase) * 0.30
        chime = math.sin(math.tau * metal * t - phase) * 0.22
        horizon = smoothstep(0.08, 0.52, progress) * (1.0 - smoothstep(0.76, 1.0, progress))
        answer = math.sin(math.tau * metal * 1.5 * t + phase * 0.7) * horizon * 0.28
        return (gate + chime + answer + noise * transient * 0.08) * envelope(progress)
    if kind == "threshold_close":
        gate = math.sin(math.tau * fundamental * (1.10 - progress * 0.18) * t + phase) * 0.34
        iron = math.sin(math.tau * metal * t - phase) * 0.24
        slam = max(0.0, 1.0 - abs(progress - 0.46) / 0.10) * (gate + iron + noise * 0.34)
        warning = math.sin(math.tau * fundamental * 0.5 * t + phase * 0.6) * smoothstep(0.38, 0.62, progress) * 0.22
        return (gate + iron + slam * 0.58 + warning + noise * transient * 0.12) * envelope(progress)
    if kind == "waypoint_acknowledge":
        note = math.sin(math.tau * fundamental * t + phase) * 0.30
        answer = max(0.0, 1.0 - abs(progress - 0.46) / 0.18) * math.sin(math.tau * metal * t - phase) * 0.24
        return (note + answer + noise * transient * 0.08) * envelope(progress)
    if kind == "banner_claim":
        body = math.sin(math.tau * fundamental * t + phase) * 0.34
        flare = math.sin(math.tau * metal * t - phase) * 0.22
        lift = smoothstep(0.10, 0.48, progress) * (1.0 - smoothstep(0.70, 1.0, progress))
        return (body + flare + flare * lift * 0.42 + noise * transient * 0.10) * envelope(progress)
    if kind == "cache_lift":
        bright = math.sin(math.tau * fundamental * t + phase) * 0.30
        sparkle = math.sin(math.tau * metal * t - phase) * 0.22
        second = max(0.0, 1.0 - abs(progress - 0.34) / 0.14) * sparkle * 0.36
        return (bright + sparkle + second + noise * transient * 0.10) * envelope(progress)
    if kind == "sentinel_warning":
        low = math.sin(math.tau * fundamental * t + phase) * 0.34
        warning = math.sin(math.tau * metal * t - phase) * 0.22
        repeat = max(0.0, 1.0 - abs(progress - 0.48) / 0.18) * warning * 0.42
        return (low + warning + repeat + noise * transient * 0.12) * envelope(progress)
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
