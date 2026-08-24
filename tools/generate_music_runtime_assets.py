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
MANIFEST_PATH = ROOT / "content" / "music_runtime_manifest.json"
SAMPLE_RATE = 44100
CHANNEL_COUNT = 2
SAMPLE_WIDTH_BYTES = 2
SEGMENT_DURATION_MSEC = 8000
SEGMENT_DURATION_SEC = SEGMENT_DURATION_MSEC / 1000.0

# Each context owns one four-chord phrase. The three cue stems share the exact
# phrase boundary so runtime can layer them without drift. Frequencies are
# quantized to whole cycles per eight-second segment before synthesis, keeping
# the generated source intrinsically loopable rather than relying on silence at
# the boundary.
CONTEXTS = {
    "menu": {
        "base": 196.0,
        "progression": [0, 5, 7, 3],
        "minor": False,
        "pulse_steps": 16,
        "color": 0.34,
    },
    "overworld": {
        "base": 174.0,
        "progression": [0, 3, 7, 5],
        "minor": True,
        "pulse_steps": 16,
        "color": 0.48,
    },
    "town": {
        "base": 146.0,
        "progression": [0, 4, 7, 5],
        "minor": False,
        "pulse_steps": 16,
        "color": 0.41,
    },
    "battle": {
        "base": 110.0,
        "progression": [0, 1, 5, 7],
        "minor": True,
        "pulse_steps": 32,
        "color": 0.72,
    },
    "outcome": {
        "base": 220.0,
        "progression": [0, 5, 2, 7],
        "minor": False,
        "pulse_steps": 16,
        "color": 0.26,
    },
}

SPECS = {
    "music_menu_theme": {"context": "menu", "stem": "root", "peak": 0.52, "pan": -0.08, "width": 0.07},
    "music_menu_theme_harmony": {"context": "menu", "stem": "harmony", "peak": 0.45, "pan": 0.10, "width": 0.18},
    "music_menu_theme_motion": {"context": "menu", "stem": "motion", "peak": 0.40, "pan": -0.14, "width": 0.26},
    "music_overworld_theme": {"context": "overworld", "stem": "root", "peak": 0.54, "pan": -0.10, "width": 0.08},
    "music_overworld_theme_harmony": {"context": "overworld", "stem": "harmony", "peak": 0.46, "pan": 0.12, "width": 0.20},
    "music_overworld_theme_motion": {"context": "overworld", "stem": "motion", "peak": 0.42, "pan": 0.16, "width": 0.28},
    "music_town_theme": {"context": "town", "stem": "root", "peak": 0.50, "pan": -0.09, "width": 0.08},
    "music_town_theme_harmony": {"context": "town", "stem": "harmony", "peak": 0.44, "pan": 0.11, "width": 0.20},
    "music_town_theme_motion": {"context": "town", "stem": "motion", "peak": 0.40, "pan": -0.15, "width": 0.25},
    "music_battle_theme": {"context": "battle", "stem": "root", "peak": 0.62, "pan": -0.06, "width": 0.09},
    "music_battle_theme_harmony": {"context": "battle", "stem": "harmony", "peak": 0.54, "pan": 0.08, "width": 0.19},
    "music_battle_theme_motion": {"context": "battle", "stem": "motion", "peak": 0.58, "pan": -0.12, "width": 0.30},
    "music_outcome_theme": {"context": "outcome", "stem": "root", "peak": 0.48, "pan": -0.08, "width": 0.08},
    "music_outcome_theme_harmony": {"context": "outcome", "stem": "harmony", "peak": 0.43, "pan": 0.10, "width": 0.22},
    "music_outcome_theme_motion": {"context": "outcome", "stem": "motion", "peak": 0.38, "pan": 0.15, "width": 0.27},
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


def periodic_frequency(frequency: float) -> float:
    return round(frequency * SEGMENT_DURATION_SEC) / SEGMENT_DURATION_SEC


def frequency_from_semitones(base: float, semitones: int, octave: int = 0) -> float:
    return periodic_frequency(base * (2.0 ** ((semitones + octave * 12) / 12.0)))


def chord_tones(context: dict[str, object], chord_index: int) -> tuple[float, float, float]:
    progression = context["progression"]
    assert isinstance(progression, list)
    root_semitones = int(progression[chord_index % len(progression)])
    base = float(context["base"])
    third = 3 if bool(context["minor"]) else 4
    return (
        frequency_from_semitones(base, root_semitones),
        frequency_from_semitones(base, root_semitones + third),
        frequency_from_semitones(base, root_semitones + 7),
    )


def chord_weights(progress: float) -> list[tuple[int, float]]:
    position = progress * 4.0
    chord_index = min(3, int(position))
    local = position - chord_index
    if local <= 0.78:
        return [(chord_index, 1.0)]
    blend = smoothstep(0.78, 1.0, local)
    return [(chord_index, 1.0 - blend), ((chord_index + 1) % 4, blend)]


def oscillator(frequency: float, time_sec: float, phase: float = 0.0) -> float:
    return math.sin(math.tau * (frequency * time_sec + phase))


def root_voice(context_id: str, context: dict[str, object], progress: float, time_sec: float, phase: float) -> float:
    value = 0.0
    color = float(context["color"])
    for chord_index, weight in chord_weights(progress):
        root, _, fifth = chord_tones(context, chord_index)
        sub = periodic_frequency(root * 0.5)
        body = oscillator(sub, time_sec, phase * 0.35) * 0.46
        body += oscillator(root, time_sec, phase) * 0.34
        body += triangle(fifth * time_sec + phase * 0.6) * (0.07 + color * 0.04)
        if context_id == "battle":
            body += saw(periodic_frequency(root * 0.25) * time_sec + phase) * 0.13
        elif context_id == "menu":
            body += oscillator(periodic_frequency(root * 2.0), time_sec, -phase) * 0.08
        value += body * weight
    breathe = 0.88 + 0.12 * oscillator(periodic_frequency(0.25), time_sec, phase)
    return value * breathe


def harmony_voice(context_id: str, context: dict[str, object], progress: float, time_sec: float, phase: float) -> float:
    value = 0.0
    for chord_index, weight in chord_weights(progress):
        root, third, fifth = chord_tones(context, chord_index)
        octave = periodic_frequency(root * 2.0)
        body = oscillator(third, time_sec, phase) * 0.36
        body += oscillator(fifth, time_sec, -phase * 0.72) * 0.31
        body += oscillator(octave, time_sec, phase * 1.3) * 0.18
        body += oscillator(periodic_frequency(third * 2.0), time_sec, -phase * 1.6) * 0.09
        if context_id == "outcome":
            bell = oscillator(periodic_frequency(fifth * 3.0), time_sec, phase) * 0.08
            body += bell * (0.55 + 0.45 * oscillator(periodic_frequency(0.5), time_sec))
        elif context_id == "overworld":
            body += triangle(periodic_frequency(root * 1.5) * time_sec + phase) * 0.06
        value += body * weight
    shimmer = 0.84 + 0.16 * oscillator(periodic_frequency(0.375), time_sec, phase * 0.5)
    return value * shimmer


def motion_voice(
    cue_id: str,
    context_id: str,
    context: dict[str, object],
    progress: float,
    time_sec: float,
    phase: float,
    texture: float,
) -> float:
    step_count = int(context["pulse_steps"])
    step_position = progress * step_count
    step_index = min(step_count - 1, int(step_position))
    local = step_position - step_index
    attack = smoothstep(0.0, 0.08, local)
    release = 1.0 - smoothstep(0.48 if context_id == "battle" else 0.62, 1.0, local)
    gate = attack * release
    chord_index = min(3, int(progress * 4.0))
    tones = chord_tones(context, chord_index)
    sequence = [0, 2, 1, 2, 0, 1, 2, 1]
    note = tones[sequence[step_index % len(sequence)]]
    octave = 2.0 if context_id in {"menu", "outcome"} else 1.0
    note = periodic_frequency(note * octave)
    pluck = oscillator(note, time_sec, phase) * 0.44
    pluck += triangle(periodic_frequency(note * 2.0) * time_sec - phase) * 0.20
    pluck += oscillator(periodic_frequency(note * 3.0), time_sec, phase * 1.7) * 0.10
    transient = math.exp(-local * (16.0 if context_id == "battle" else 11.0))
    percussion = texture * transient * (0.32 if context_id == "battle" else 0.18)
    if context_id == "battle":
        low = periodic_frequency(float(context["base"]) * 0.5)
        percussion += oscillator(low, time_sec, phase) * transient * 0.22
    elif context_id == "overworld":
        percussion += saw(periodic_frequency(note * 0.5) * time_sec + phase) * transient * 0.08
    elif context_id == "menu":
        percussion += oscillator(periodic_frequency(note * 4.0), time_sec, -phase) * transient * 0.12
    elif context_id == "outcome":
        percussion += oscillator(periodic_frequency(note * 3.0), time_sec, phase) * transient * 0.10
    accent = 1.18 if step_index % 4 == 0 else 0.88
    return (pluck + percussion) * gate * accent


def sample_stem(
    cue_id: str,
    spec: dict[str, object],
    progress: float,
    time_sec: float,
    channel_phase: float,
    texture: float,
) -> float:
    context_id = str(spec["context"])
    context = CONTEXTS[context_id]
    stem = str(spec["stem"])
    if stem == "root":
        return root_voice(context_id, context, progress, time_sec, channel_phase)
    if stem == "harmony":
        return harmony_voice(context_id, context, progress, time_sec, channel_phase)
    if stem == "motion":
        return motion_voice(cue_id, context_id, context, progress, time_sec, channel_phase, texture)
    raise ValueError(f"Unsupported music stem: {stem}")


def render_stereo(cue_id: str, duration_msec: int) -> list[tuple[float, float]]:
    if duration_msec != SEGMENT_DURATION_MSEC:
        raise ValueError(f"Music cue {cue_id} must use the shared {SEGMENT_DURATION_MSEC} ms loop")
    spec = SPECS[cue_id]
    frame_count = int(SAMPLE_RATE * duration_msec / 1000.0)
    rng_left = random.Random(f"{cue_id}:left:production-layered-loop-v1")
    rng_right = random.Random(f"{cue_id}:right:production-layered-loop-v1")
    width = float(spec["width"])
    pan = max(-0.9, min(0.9, float(spec["pan"])))
    pan_angle = (pan + 1.0) * math.pi * 0.25
    gain_left = math.cos(pan_angle)
    gain_right = math.sin(pan_angle)
    frames: list[tuple[float, float]] = []
    for index in range(frame_count):
        progress = index / frame_count
        time_sec = index / SAMPLE_RATE
        texture_left = (
            oscillator(periodic_frequency(3187.0), time_sec, rng_left.random() * 0.04)
            + oscillator(periodic_frequency(4721.0), time_sec, 0.17)
        ) * 0.5
        texture_right = (
            oscillator(periodic_frequency(3251.0), time_sec, rng_right.random() * 0.04)
            + oscillator(periodic_frequency(4657.0), time_sec, -0.13)
        ) * 0.5
        left = sample_stem(cue_id, spec, progress, time_sec, -width, texture_left) * gain_left
        right = sample_stem(cue_id, spec, progress, time_sec, width, texture_right) * gain_right
        frames.append((left, right))

    mean_left = sum(frame[0] for frame in frames) / len(frames)
    mean_right = sum(frame[1] for frame in frames) / len(frames)
    dc_free = [(left - mean_left, right - mean_right) for left, right in frames]
    peak = max(max(abs(left), abs(right)) for left, right in dc_free)
    if peak <= 1.0e-8:
        raise ValueError(f"Rendered silent music cue: {cue_id}")
    scale = float(spec["peak"]) / peak
    normalized = [(left * scale, right * scale) for left, right in dc_free]

    # Preserve the musical body while making the exact wrap sample continuous.
    # The tiny tail correction is distributed over 20 ms and ends exactly on
    # the first stereo frame, eliminating the click that a one-shot WAV import
    # would otherwise expose when LOOP_FORWARD wraps.
    correction_frames = max(2, int(SAMPLE_RATE * 0.020))
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
        "asset_tier": "production_layered_loop_v1",
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
                "asset_tier": "production_layered_loop_v1",
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
