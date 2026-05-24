#!/usr/bin/env python3
from __future__ import annotations

import json
import math
import random
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "content" / "music_runtime_manifest.json"
SAMPLE_RATE = 22050

SPECS = {
    "music_menu_theme": {"root": 196.0, "interval": 1.0, "motion": 0.30, "pulse": 0.35, "amp": 0.24},
    "music_menu_theme_harmony": {"root": 246.94, "interval": 1.0, "motion": 0.24, "pulse": 0.18, "amp": 0.18},
    "music_menu_theme_motion": {"root": 294.0, "interval": 1.0, "motion": 0.58, "pulse": 1.35, "amp": 0.15},
    "music_overworld_theme": {"root": 174.0, "interval": 1.0, "motion": 0.36, "pulse": 0.45, "amp": 0.22},
    "music_overworld_theme_harmony": {"root": 206.9, "interval": 1.0, "motion": 0.26, "pulse": 0.22, "amp": 0.17},
    "music_overworld_theme_motion": {"root": 274.0, "interval": 1.0, "motion": 0.74, "pulse": 1.45, "amp": 0.14},
    "music_battle_theme": {"root": 110.0, "interval": 1.0, "motion": 0.68, "pulse": 1.75, "amp": 0.30},
    "music_battle_theme_harmony": {"root": 130.8, "interval": 1.0, "motion": 0.48, "pulse": 0.88, "amp": 0.22},
    "music_battle_theme_motion": {"root": 237.0, "interval": 1.0, "motion": 1.10, "pulse": 2.55, "amp": 0.16},
    "music_outcome_theme": {"root": 220.0, "interval": 1.0, "motion": 0.24, "pulse": 0.28, "amp": 0.20},
    "music_outcome_theme_harmony": {"root": 277.18, "interval": 1.0, "motion": 0.18, "pulse": 0.14, "amp": 0.16},
    "music_outcome_theme_motion": {"root": 330.0, "interval": 1.0, "motion": 0.42, "pulse": 0.95, "amp": 0.13},
}


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge0 == edge1:
        return 0.0
    x = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return x * x * (3.0 - 2.0 * x)


def envelope(progress: float) -> float:
    return smoothstep(0.0, 0.16, progress) * (1.0 - smoothstep(0.78, 1.0, progress))


def sample_value(spec: dict[str, float], index: int, frame_count: int, rng: random.Random) -> float:
    progress = index / max(1, frame_count - 1)
    t = index / SAMPLE_RATE
    root = float(spec["root"])
    pulse = 0.74 + (0.26 * math.sin(math.tau * float(spec["pulse"]) * t))
    wobble = math.sin(math.tau * float(spec["motion"]) * t) * 0.16
    tone = math.sin(math.tau * root * (t + wobble * 0.002)) * 0.50
    tone += math.sin(math.tau * root * 2.0 * t) * 0.18
    tone += math.sin(math.tau * root * 0.5 * t) * 0.22
    texture = (rng.random() * 2.0 - 1.0) * 0.018
    value = (tone * pulse + texture) * float(spec["amp"]) * envelope(progress)
    return max(-0.92, min(0.92, value))


def write_wav(path: Path, cue_id: str, duration_msec: int) -> None:
    spec = SPECS[cue_id]
    path.parent.mkdir(parents=True, exist_ok=True)
    rng = random.Random(cue_id)
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
    for cue_id, cue in sorted(cues.items()):
        rel_path = str(cue["path"]).removeprefix("res://")
        write_wav(ROOT / rel_path, cue_id, int(cue["duration_msec"]))
    print(f"generated {len(cues)} runtime music WAV assets from {MANIFEST_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
