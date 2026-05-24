#!/usr/bin/env python3
from __future__ import annotations

import json
import math
import random
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "content" / "ambient_sfx_manifest.json"
SAMPLE_RATE = 22050

SPECS = {
    "overworld_ambient_grass": {"kind": "air", "freq": 176.0, "freq2": 31.0, "noise": 0.18, "amp": 0.22},
    "overworld_ambient_water": {"kind": "wash", "freq": 132.0, "freq2": 44.0, "noise": 0.26, "amp": 0.23},
    "overworld_ambient_mire": {"kind": "drone", "freq": 118.0, "freq2": 27.0, "noise": 0.24, "amp": 0.25},
    "overworld_ambient_dirt": {"kind": "dry", "freq": 154.0, "freq2": 36.0, "noise": 0.16, "amp": 0.20},
    "overworld_ambient_rough": {"kind": "wind", "freq": 96.0, "freq2": 21.0, "noise": 0.20, "amp": 0.23},
    "overworld_ambient_sand": {"kind": "hush", "freq": 142.0, "freq2": 24.0, "noise": 0.22, "amp": 0.19},
    "overworld_ambient_snow": {"kind": "hush", "freq": 88.0, "freq2": 19.0, "noise": 0.12, "amp": 0.18},
    "overworld_ambient_lava": {"kind": "rumble", "freq": 74.0, "freq2": 17.0, "noise": 0.30, "amp": 0.27},
    "overworld_ambient_underground": {"kind": "hall", "freq": 64.0, "freq2": 15.0, "noise": 0.14, "amp": 0.24},
    "overworld_ambient_pressure": {"kind": "pressure", "freq": 214.0, "freq2": 53.0, "noise": 0.10, "amp": 0.23},
    "overworld_ambient_day_pulse": {"kind": "pulse", "freq": 248.0, "freq2": 124.0, "noise": 0.04, "amp": 0.15},
}


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge0 == edge1:
        return 0.0
    x = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return x * x * (3.0 - 2.0 * x)


def envelope(progress: float) -> float:
    return smoothstep(0.0, 0.20, progress) * (1.0 - smoothstep(0.76, 1.0, progress))


def sample_value(spec: dict[str, float | str], index: int, frame_count: int, rng: random.Random) -> float:
    progress = index / max(1, frame_count - 1)
    t = index / SAMPLE_RATE
    kind = str(spec["kind"])
    freq = float(spec["freq"])
    freq2 = float(spec["freq2"])
    slow = math.sin(math.tau * freq2 * t) * 0.33
    base = math.sin(math.tau * freq * t + slow) * 0.42
    if kind == "pressure":
        beat = 1.0 if math.sin(math.tau * 2.0 * t) > 0.66 else 0.42
        base = math.sin(math.tau * freq * t) * 0.36 * beat
    elif kind == "pulse":
        pulse = max(0.0, math.sin(math.tau * 1.65 * t)) ** 2.8
        base = math.sin(math.tau * freq * t) * 0.42 * pulse
    elif kind in {"wash", "rumble"}:
        base += math.sin(math.tau * (freq * 0.5) * t) * 0.22
    noise = (rng.random() * 2.0 - 1.0) * float(spec["noise"])
    value = (base * (1.0 - float(spec["noise"])) + noise) * float(spec["amp"]) * envelope(progress)
    return max(-0.90, min(0.90, value))


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
    print(f"generated {len(cues)} overworld ambient WAV assets from {MANIFEST_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
