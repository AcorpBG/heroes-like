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
SAMPLE_RATE = 22050

SPECS = {
    "audio_placeholder_ranged_release": {"kind": "pluck", "freq": 830.0, "freq2": 1240.0, "noise": 0.08, "amp": 0.34},
    "audio_placeholder_status_apply": {"kind": "shimmer", "freq": 420.0, "freq2": 650.0, "noise": 0.10, "amp": 0.28},
    "audio_placeholder_melee_release": {"kind": "whoosh", "freq": 230.0, "freq2": 520.0, "noise": 0.32, "amp": 0.38},
    "audio_placeholder_hit": {"kind": "thud", "freq": 130.0, "freq2": 84.0, "noise": 0.46, "amp": 0.44},
    "audio_placeholder_unit_rout": {"kind": "fall", "freq": 210.0, "freq2": 110.0, "noise": 0.22, "amp": 0.30},
    "audio_placeholder_cast": {"kind": "rise", "freq": 520.0, "freq2": 790.0, "noise": 0.07, "amp": 0.30},
    "audio_placeholder_unit_step": {"kind": "step", "freq": 180.0, "freq2": 95.0, "noise": 0.36, "amp": 0.22},
    "audio_placeholder_defend": {"kind": "brace", "freq": 285.0, "freq2": 430.0, "noise": 0.12, "amp": 0.24},
    "audio_placeholder_retaliation": {"kind": "counter", "freq": 350.0, "freq2": 175.0, "noise": 0.18, "amp": 0.34},
    "audio_placeholder_retreat_order": {"kind": "horn_down", "freq": 330.0, "freq2": 248.0, "noise": 0.04, "amp": 0.26},
    "audio_placeholder_surrender_order": {"kind": "horn_soft", "freq": 300.0, "freq2": 245.0, "noise": 0.04, "amp": 0.24},
    "audio_placeholder_turn_ready": {"kind": "ready", "freq": 640.0, "freq2": 960.0, "noise": 0.04, "amp": 0.21},
    "audio_placeholder_status_clear": {"kind": "clear", "freq": 360.0, "freq2": 540.0, "noise": 0.06, "amp": 0.22},
    "audio_placeholder_idle_soft": {"kind": "soft", "freq": 180.0, "freq2": 225.0, "noise": 0.02, "amp": 0.12},
}


def envelope(progress: float, kind: str) -> float:
    attack = min(1.0, progress / 0.08)
    if kind in {"hit", "step", "brace"}:
        release = max(0.0, 1.0 - progress) ** 2.6
    elif kind in {"rise", "shimmer", "clear"}:
        release = 1.0 - smoothstep(0.70, 1.0, progress)
    elif kind == "fall":
        release = 1.0 - smoothstep(0.58, 1.0, progress)
    else:
        release = 1.0 - smoothstep(0.62, 1.0, progress)
    return max(0.0, min(1.0, attack * release))


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge0 == edge1:
        return 0.0
    x = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return x * x * (3.0 - 2.0 * x)


def triangle(phase: float) -> float:
    wrapped = phase - math.floor(phase)
    return 4.0 * abs(wrapped - 0.5) - 1.0


def sample_value(spec: dict[str, float | str], index: int, frame_count: int, rng: random.Random) -> float:
    progress = index / max(1, frame_count - 1)
    t = index / SAMPLE_RATE
    kind = str(spec["kind"])
    freq = float(spec["freq"])
    freq2 = float(spec["freq2"])
    if kind in {"rise", "ready"}:
        freq *= 1.0 + progress * 0.32
        freq2 *= 1.0 + progress * 0.18
    elif kind in {"fall", "horn_down"}:
        freq *= 1.0 - progress * 0.34
        freq2 *= 1.0 - progress * 0.22
    elif kind == "whoosh":
        freq *= 0.72 + progress * 1.18
    base = math.sin(math.tau * freq * t) * 0.62 + triangle(freq2 * t) * 0.28
    if kind in {"hit", "step"}:
        base = triangle(freq * t) * 0.46 + math.sin(math.tau * freq2 * t) * 0.24
    elif kind in {"shimmer", "clear"}:
        base += math.sin(math.tau * (freq2 * 1.53) * t) * 0.18
    elif kind == "soft":
        base = math.sin(math.tau * freq * t) * 0.78
    noise = (rng.random() * 2.0 - 1.0) * float(spec["noise"])
    value = (base * (1.0 - float(spec["noise"])) + noise) * float(spec["amp"]) * envelope(progress, kind)
    return max(-0.94, min(0.94, value))


def write_wav(path: Path, audio_id: str, duration_msec: int) -> None:
    spec = SPECS[audio_id]
    path.parent.mkdir(parents=True, exist_ok=True)
    rng = random.Random(audio_id)
    frame_count = max(1, int(SAMPLE_RATE * duration_msec / 1000.0))
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for index in range(frame_count):
            value = sample_value(spec, index, frame_count, rng)
            frames.extend(struct.pack("<h", int(value * 32767.0)))
        handle.writeframes(bytes(frames))


def main() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    cues = manifest.get("cues", {})
    missing = sorted(set(SPECS) - set(cues))
    extra = sorted(set(cues) - set(SPECS))
    if missing or extra:
        raise SystemExit(f"Manifest/spec cue mismatch: missing={missing} extra={extra}")
    for audio_id, cue in sorted(cues.items()):
        rel_path = str(cue["path"]).removeprefix("res://")
        write_wav(ROOT / rel_path, audio_id, int(cue["duration_msec"]))
    print(f"generated {len(cues)} battle SFX WAV assets from {MANIFEST_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
