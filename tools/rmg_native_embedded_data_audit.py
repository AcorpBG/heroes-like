#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ACTIVE_FILES = [
    ROOT / "src/gdextension/src/archived_h3maped_small_rmg_legacy_proxy_20260618.cpp",
    ROOT / "src/gdextension/src/archived_h3maped_small_rmg_embedded_data.hpp",
    ROOT / "src/gdextension/src/archived_h3maped_small_rmg_embedded_data_legacy_proxy_20260618.cpp",
    ROOT / "src/gdextension/CMakeLists.txt",
]

FORBIDDEN_ACTIVE_STRINGS = [
    "/root/",
    "res://content/random_map_template_catalog.json",
    "res://content/homm3_re_obstacle_proxy_catalog.json",
    "res://content/homm3_re_reward_object_proxy_catalog.json",
    "BINARY_PATH",
    "RMG_TEMPLATE_CATALOG_SOURCE_PATH",
    "OBJECT_CATALOG_SOURCE_PATH",
    "OBJECT_DECORATION_OBSTACLES_CSV_PATH",
    "CRTRAITS_SOURCE_PATH",
    "REWARD_PROXY_CATALOG_PATH",
    "OBJECT_DECORATION_OBSTACLE_PROXY_CATALOG_PATH",
    "external_h3maped",
    "AURELION_H3MAPED_DISABLE_EXTERNAL_EVIDENCE",
    "fallback_path",
    "reward_fallback",
    "FileAccess::open(",
    "FileAccess::file_exists(",
]

REQUIRED_ACTIVE_STRINGS = [
    "archived_h3maped_small_rmg_embedded_data.hpp",
    "load_compiled_template_catalog",
    "load_compiled_object_catalog",
    "load_compiled_reward_proxy_catalog",
    "COMPILED_DECORATION_OBSTACLES_SOURCE",
    "COMPILED_MONSTER_CANDIDATE_SOURCE",
]


def main() -> int:
    failures: list[str] = []
    combined = ""
    for path in ACTIVE_FILES:
        text = path.read_text(encoding="utf-8")
        combined += text
        for forbidden in FORBIDDEN_ACTIVE_STRINGS:
            if forbidden in text:
                failures.append(f"{path.relative_to(ROOT)} contains forbidden runtime evidence marker: {forbidden}")
    for required in REQUIRED_ACTIVE_STRINGS:
        if required not in combined:
            failures.append(f"missing required compiled-data marker: {required}")
    if failures:
        for failure in failures:
            print(failure)
        return 1
    print("native RMG compiled-data audit passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
