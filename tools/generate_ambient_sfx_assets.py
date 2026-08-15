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
MANIFEST_PATH = ROOT / "content" / "ambient_sfx_manifest.json"
SAMPLE_RATE = 44100
CHANNEL_COUNT = 2
SAMPLE_WIDTH_BYTES = 2
SEGMENT_DURATION_MSEC = 12000
SEGMENT_DURATION_SEC = SEGMENT_DURATION_MSEC / 1000.0

# The eleven production layers retain the established cue identities and mix
# policy while giving every live Overworld context its own deterministic sound
# body. All oscillators and texture partials are quantized to whole cycles per
# segment, so the source is intrinsically periodic before the final sub-frame
# boundary correction is applied.
SPECS: dict[str, dict[str, object]] = {
    "overworld_ambient_grass": {
        "kind": "air",
        "base": 176.0,
        "motion": 0.25,
        "air": 0.32,
        "peak": 0.42,
        "pan": -0.05,
        "width": 0.21,
        "events": (0.18, 0.57, 0.82),
    },
    "overworld_ambient_water": {
        "kind": "wash",
        "base": 132.0,
        "motion": 0.34,
        "air": 0.38,
        "peak": 0.44,
        "pan": 0.08,
        "width": 0.28,
        "events": (0.11, 0.46, 0.74),
    },
    "overworld_ambient_mire": {
        "kind": "drone",
        "base": 118.0,
        "motion": 0.19,
        "air": 0.26,
        "peak": 0.46,
        "pan": -0.09,
        "width": 0.24,
        "events": (0.24, 0.52, 0.88),
    },
    "overworld_ambient_dirt": {
        "kind": "dry",
        "base": 154.0,
        "motion": 0.28,
        "air": 0.25,
        "peak": 0.39,
        "pan": 0.04,
        "width": 0.19,
        "events": (0.16, 0.39, 0.71, 0.91),
    },
    "overworld_ambient_rough": {
        "kind": "wind",
        "base": 96.0,
        "motion": 0.31,
        "air": 0.36,
        "peak": 0.45,
        "pan": -0.12,
        "width": 0.30,
        "events": (0.29, 0.66),
    },
    "overworld_ambient_sand": {
        "kind": "sand",
        "base": 142.0,
        "motion": 0.38,
        "air": 0.44,
        "peak": 0.38,
        "pan": 0.13,
        "width": 0.34,
        "events": (0.20, 0.61, 0.84),
    },
    "overworld_ambient_snow": {
        "kind": "snow",
        "base": 88.0,
        "motion": 0.17,
        "air": 0.30,
        "peak": 0.36,
        "pan": -0.03,
        "width": 0.38,
        "events": (0.13, 0.49, 0.78),
    },
    "overworld_ambient_lava": {
        "kind": "rumble",
        "base": 74.0,
        "motion": 0.33,
        "air": 0.35,
        "peak": 0.50,
        "pan": -0.07,
        "width": 0.25,
        "events": (0.09, 0.31, 0.58, 0.87),
    },
    "overworld_ambient_underground": {
        "kind": "hall",
        "base": 64.0,
        "motion": 0.16,
        "air": 0.22,
        "peak": 0.43,
        "pan": 0.02,
        "width": 0.32,
        "events": (0.27, 0.69),
    },
    "overworld_ambient_pressure": {
        "kind": "pressure",
        "base": 107.0,
        "motion": 0.42,
        "air": 0.18,
        "peak": 0.52,
        "pan": -0.02,
        "width": 0.23,
        "events": (0.04, 0.17, 0.30, 0.43, 0.56, 0.69, 0.82, 0.95),
    },
    "overworld_ambient_day_pulse": {
        "kind": "pulse",
        "base": 248.0,
        "motion": 0.15,
        "air": 0.16,
        "peak": 0.35,
        "pan": 0.06,
        "width": 0.40,
        "events": (0.08, 0.33, 0.58, 0.83),
    },
}


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge0 == edge1:
        return 0.0
    x = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return x * x * (3.0 - 2.0 * x)


def periodic_frequency(frequency: float) -> float:
    return round(frequency * SEGMENT_DURATION_SEC) / SEGMENT_DURATION_SEC


def oscillator(frequency: float, time_sec: float, phase: float = 0.0) -> float:
    return math.sin(math.tau * (frequency * time_sec + phase))


def triangle(phase: float) -> float:
    wrapped = phase - math.floor(phase)
    return 4.0 * abs(wrapped - 0.5) - 1.0


def circular_distance(progress: float, center: float) -> float:
    distance = abs(progress - center)
    return min(distance, 1.0 - distance)


def circular_event(progress: float, center: float, radius: float) -> float:
    distance = circular_distance(progress, center)
    return 1.0 - smoothstep(radius * 0.16, radius, distance)


def texture_bank(cue_id: str, channel: str, low: float, high: float, count: int) -> list[tuple[float, float, float]]:
    rng = random.Random(f"{cue_id}:{channel}:production-ambient-loop-v1")
    weights = [1.0 / (1.0 + index * 0.32) for index in range(count)]
    weight_total = sum(weights)
    bank: list[tuple[float, float, float]] = []
    for index, weight in enumerate(weights):
        frequency = periodic_frequency(rng.uniform(low, high))
        phase = rng.random()
        signed_weight = (weight / weight_total) * (-1.0 if index % 3 == 1 else 1.0)
        bank.append((frequency, phase, signed_weight))
    return bank


def texture_value(bank: list[tuple[float, float, float]], time_sec: float) -> float:
    return sum(oscillator(frequency, time_sec, phase) * weight for frequency, phase, weight in bank)


def event_sum(
    progress: float,
    time_sec: float,
    events: tuple[float, ...],
    frequency: float,
    phase: float,
    radius: float,
) -> float:
    value = 0.0
    for event_index, center in enumerate(events):
        envelope = circular_event(progress, center, radius)
        event_frequency = periodic_frequency(frequency * (1.0 + event_index * 0.073))
        value += oscillator(event_frequency, time_sec, phase + event_index * 0.17) * envelope
    return value / max(1, len(events))


def ambient_voice(
    cue_id: str,
    spec: dict[str, object],
    progress: float,
    time_sec: float,
    channel_phase: float,
    low_texture: float,
    high_texture: float,
) -> float:
    kind = str(spec["kind"])
    base = periodic_frequency(float(spec["base"]))
    motion = float(spec["motion"])
    air = float(spec["air"])
    events = tuple(float(value) for value in spec["events"])
    slow = 0.70 + 0.30 * oscillator(periodic_frequency(1.0 / 12.0), time_sec, channel_phase)
    gust = 0.62 + 0.38 * oscillator(periodic_frequency(1.0 / 6.0), time_sec, -channel_phase * 0.7)
    sub = oscillator(periodic_frequency(base * 0.5), time_sec, channel_phase * 0.31)
    body = oscillator(base, time_sec, channel_phase) * 0.48
    body += oscillator(periodic_frequency(base * 1.5), time_sec, -channel_phase * 0.63) * 0.22
    body += oscillator(periodic_frequency(base * 2.0), time_sec, channel_phase * 1.27) * 0.10

    if kind == "air":
        birds = event_sum(progress, time_sec, events, 910.0, channel_phase, 0.032)
        birds += event_sum(progress, time_sec, events, 1320.0, -channel_phase, 0.018) * 0.42
        return body * 0.20 * slow + high_texture * air * gust + birds * 0.18
    if kind == "wash":
        wave = oscillator(periodic_frequency(base * 0.25), time_sec, channel_phase) * 0.42
        wave += oscillator(periodic_frequency(base * 0.375), time_sec, -channel_phase) * 0.28
        droplets = event_sum(progress, time_sec, events, 1160.0, channel_phase, 0.024)
        return wave * gust * 0.42 + low_texture * 0.18 + high_texture * air * 0.34 + droplets * 0.16
    if kind == "drone":
        bubbles = event_sum(progress, time_sec, events, 184.0, channel_phase, 0.040)
        bubbles += event_sum(progress, time_sec, events, 431.0, -channel_phase, 0.022) * 0.35
        return (sub * 0.30 + body * 0.34) * slow + low_texture * 0.20 + high_texture * air * 0.18 + bubbles * 0.22
    if kind == "dry":
        creaks = event_sum(progress, time_sec, events, 386.0, channel_phase, 0.022)
        clicks = event_sum(progress, time_sec, events, 1710.0, -channel_phase, 0.010)
        return body * 0.23 * slow + high_texture * air * gust + creaks * 0.18 + clicks * 0.08
    if kind == "wind":
        stone = oscillator(periodic_frequency(base * 2.5), time_sec, channel_phase) * 0.16
        stone += oscillator(periodic_frequency(base * 3.25), time_sec, -channel_phase) * 0.11
        resonance = event_sum(progress, time_sec, events, 292.0, channel_phase, 0.085)
        return sub * 0.20 + body * 0.24 * slow + high_texture * air * gust + stone + resonance * 0.16
    if kind == "sand":
        sweep = triangle(periodic_frequency(0.25) * time_sec + channel_phase) * 0.16
        whisper = event_sum(progress, time_sec, events, 742.0, channel_phase, 0.075)
        return body * 0.14 + high_texture * air * (0.72 + 0.28 * sweep) + low_texture * 0.12 + whisper * 0.12
    if kind == "snow":
        chime = event_sum(progress, time_sec, events, 1216.0, channel_phase, 0.030)
        chime += event_sum(progress, time_sec, events, 1824.0, -channel_phase, 0.018) * 0.46
        return body * 0.12 * slow + high_texture * air * 0.62 + low_texture * 0.10 + chime * 0.19
    if kind == "rumble":
        crackle = event_sum(progress, time_sec, events, 1380.0, channel_phase, 0.018)
        crackle += event_sum(progress, time_sec, events, 2310.0, -channel_phase, 0.009) * 0.35
        return sub * 0.46 + body * 0.31 * slow + low_texture * 0.26 + high_texture * air * 0.22 + crackle * 0.20
    if kind == "hall":
        drip = event_sum(progress, time_sec, events, 978.0, channel_phase, 0.025)
        echo = event_sum(progress, time_sec, events, 489.0, -channel_phase, 0.090)
        return sub * 0.34 + body * 0.35 * slow + low_texture * 0.18 + drip * 0.17 + echo * 0.11
    if kind == "pressure":
        drum = 0.0
        for event_index, center in enumerate(events):
            envelope = circular_event(progress, center, 0.035)
            transient = envelope * envelope
            drum_frequency = periodic_frequency(52.0 + (event_index % 3) * 7.0)
            drum += oscillator(drum_frequency, time_sec, channel_phase + event_index * 0.08) * transient
        drum /= max(1, len(events))
        horn = event_sum(progress, time_sec, (0.27, 0.73), base * 1.5, channel_phase, 0.13)
        return sub * 0.28 + body * 0.18 + drum * 1.55 + horn * 0.23 + low_texture * 0.12
    if kind == "pulse":
        bell = event_sum(progress, time_sec, events, base, channel_phase, 0.055)
        bell += event_sum(progress, time_sec, events, base * 2.01, -channel_phase, 0.040) * 0.48
        bell += event_sum(progress, time_sec, events, base * 3.04, channel_phase * 1.3, 0.025) * 0.24
        return body * 0.09 + high_texture * air * 0.18 + bell * 0.50
    raise ValueError(f"Unsupported ambient kind: {kind} ({cue_id})")


def render_stereo(cue_id: str, duration_msec: int) -> list[tuple[float, float]]:
    if duration_msec != SEGMENT_DURATION_MSEC:
        raise ValueError(f"Ambient cue {cue_id} must use the shared {SEGMENT_DURATION_MSEC} ms loop")
    spec = SPECS[cue_id]
    frame_count = int(SAMPLE_RATE * duration_msec / 1000.0)
    pan = max(-0.9, min(0.9, float(spec["pan"])))
    width = float(spec["width"])
    pan_angle = (pan + 1.0) * math.pi * 0.25
    gain_left = math.cos(pan_angle)
    gain_right = math.sin(pan_angle)
    low_left = texture_bank(cue_id, "low-left", 11.0, 91.0, 7)
    low_right = texture_bank(cue_id, "low-right", 13.0, 97.0, 7)
    high_left = texture_bank(cue_id, "high-left", 510.0, 4860.0, 11)
    high_right = texture_bank(cue_id, "high-right", 540.0, 4920.0, 11)
    frames: list[tuple[float, float]] = []
    for index in range(frame_count):
        progress = index / frame_count
        time_sec = index / SAMPLE_RATE
        left = ambient_voice(
            cue_id,
            spec,
            progress,
            time_sec,
            -width,
            texture_value(low_left, time_sec),
            texture_value(high_left, time_sec),
        ) * gain_left
        right = ambient_voice(
            cue_id,
            spec,
            progress,
            time_sec,
            width,
            texture_value(low_right, time_sec),
            texture_value(high_right, time_sec),
        ) * gain_right
        frames.append((left, right))

    mean_left = sum(frame[0] for frame in frames) / len(frames)
    mean_right = sum(frame[1] for frame in frames) / len(frames)
    dc_free = [(left - mean_left, right - mean_right) for left, right in frames]
    peak = max(max(abs(left), abs(right)) for left, right in dc_free)
    if peak <= 1.0e-8:
        raise ValueError(f"Rendered silent ambient cue: {cue_id}")
    scale = float(spec["peak"]) / peak
    normalized = [(left * scale, right * scale) for left, right in dc_free]

    # A periodic source is already close at the wrap. Distribute the remaining
    # sub-frame difference over 24 ms and make the exact stereo endpoints equal
    # so LOOP_FORWARD cannot expose a one-sample click.
    correction_frames = max(2, int(SAMPLE_RATE * 0.024))
    first_left, first_right = normalized[0]
    last_left, last_right = normalized[-1]
    left_delta = first_left - last_left
    right_delta = first_right - last_right
    for offset in range(correction_frames):
        index = frame_count - correction_frames + offset
        blend = smoothstep(0.0, 1.0, (offset + 1) / correction_frames)
        left, right = normalized[index]
        normalized[index] = (left + left_delta * blend, right + right_delta * blend)
    normalized[-1] = normalized[0]
    return normalized


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
    required_manifest = {
        "sample_rate_hz": SAMPLE_RATE,
        "channel_count": CHANNEL_COUNT,
        "sample_width_bits": SAMPLE_WIDTH_BYTES * 8,
        "segment_duration_msec": SEGMENT_DURATION_MSEC,
        "loop_mode": "forward",
        "asset_tier": "production_ambient_loop_v1",
    }
    for key, expected in required_manifest.items():
        if manifest.get(key) != expected:
            raise SystemExit(f"Manifest {key} must equal {expected!r}")
    hashes: dict[str, str] = {}
    for cue_id, cue in sorted(cues.items()):
        rel_path = str(cue["path"]).removeprefix("res://")
        output_path = ROOT / rel_path
        write_wav(output_path, cue_id, int(cue["duration_msec"]))
        hashes[cue_id] = hashlib.sha256(output_path.read_bytes()).hexdigest()
    pack_signature = hashlib.sha256(
        "\n".join(f"{cue_id}:{hashes[cue_id]}" for cue_id in sorted(hashes)).encode("utf-8")
    ).hexdigest()
    print(
        json.dumps(
            {
                "asset_tier": "production_ambient_loop_v1",
                "channel_count": CHANNEL_COUNT,
                "cue_count": len(cues),
                "duration_msec": SEGMENT_DURATION_MSEC,
                "pack_signature": pack_signature,
                "sample_rate_hz": SAMPLE_RATE,
                "sample_width_bits": SAMPLE_WIDTH_BYTES * 8,
                "unique_hash_count": len(set(hashes.values())),
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
