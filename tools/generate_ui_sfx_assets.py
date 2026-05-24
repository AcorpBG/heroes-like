#!/usr/bin/env python3
from __future__ import annotations

import json
import math
import random
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "content" / "ui_sfx_manifest.json"
SAMPLE_RATE = 22050

SPECS = {
    "ui_click": {"kind": "tick", "freq": 620.0, "freq2": 930.0, "noise": 0.05, "amp": 0.23},
    "ui_select": {"kind": "chime", "freq": 720.0, "freq2": 1080.0, "noise": 0.04, "amp": 0.21},
    "ui_adjust": {"kind": "nudge", "freq": 460.0, "freq2": 690.0, "noise": 0.04, "amp": 0.17},
    "ui_tab": {"kind": "page", "freq": 540.0, "freq2": 810.0, "noise": 0.06, "amp": 0.20},
    "ui_confirm": {"kind": "confirm", "freq": 760.0, "freq2": 1140.0, "noise": 0.03, "amp": 0.25},
    "ui_invalid": {"kind": "deny", "freq": 210.0, "freq2": 155.0, "noise": 0.08, "amp": 0.24},
}


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge0 == edge1:
        return 0.0
    x = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return x * x * (3.0 - 2.0 * x)


def envelope(progress: float, kind: str) -> float:
    attack = min(1.0, progress / 0.08)
    if kind in {"tick", "nudge"}:
        release = max(0.0, 1.0 - progress) ** 2.8
    elif kind == "deny":
        release = 1.0 - smoothstep(0.55, 1.0, progress)
    else:
        release = 1.0 - smoothstep(0.68, 1.0, progress)
    return max(0.0, min(1.0, attack * release))


def triangle(phase: float) -> float:
    wrapped = phase - math.floor(phase)
    return 4.0 * abs(wrapped - 0.5) - 1.0


def sample_value(spec: dict[str, float | str], index: int, frame_count: int, rng: random.Random) -> float:
    progress = index / max(1, frame_count - 1)
    t = index / SAMPLE_RATE
    kind = str(spec["kind"])
    freq = float(spec["freq"])
    freq2 = float(spec["freq2"])
    if kind == "confirm":
        freq *= 1.0 + progress * 0.22
        freq2 *= 1.0 + progress * 0.12
    elif kind == "deny":
        freq *= 1.0 - progress * 0.18
        freq2 *= 1.0 - progress * 0.10
    base = math.sin(math.tau * freq * t) * 0.58 + triangle(freq2 * t) * 0.26
    if kind == "page":
        base += math.sin(math.tau * (freq * 0.5) * t) * 0.12
    elif kind == "deny":
        base = triangle(freq * t) * 0.44 + math.sin(math.tau * freq2 * t) * 0.22
    noise = (rng.random() * 2.0 - 1.0) * float(spec["noise"])
    value = (base * (1.0 - float(spec["noise"])) + noise) * float(spec["amp"]) * envelope(progress, kind)
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
    print(f"generated {len(cues)} UI SFX WAV assets from {MANIFEST_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
