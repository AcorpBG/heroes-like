#!/usr/bin/env python3
"""Focused H3M lower-right object-anchor parser regression."""

from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import rmg_fast_audit  # noqa: E402


MAP_SIZE = 72
LEVEL_COUNT = 1


def object_record(x: int, y: int, *, z: int = 0, template_index: int = 0, reserved: bytes = b"\x00" * 5) -> bytes:
    if len(reserved) != 5:
        raise ValueError("object instance reserved field must contain exactly five bytes")
    return bytes((x, y, z)) + template_index.to_bytes(4, "little") + reserved


def assert_start(record: bytes, expected: bool, *, template_count: int = 1) -> None:
    actual = rmg_fast_audit.is_h3m_object_instance_start(record, 0, template_count, MAP_SIZE, LEVEL_COUNT)
    if actual != expected:
        raise AssertionError(f"object start expectation mismatch: expected={expected} actual={actual} bytes={record.hex()}")


def main() -> int:
    maximum_x = MAP_SIZE + rmg_fast_audit.H3M_OBJECT_ANCHOR_X_OVERHANG
    maximum_y = MAP_SIZE + rmg_fast_audit.H3M_OBJECT_ANCHOR_Y_OVERHANG
    if maximum_x != 78 or maximum_y != 76:
        raise AssertionError(f"unexpected 8x6 anchor envelope: x={maximum_x} y={maximum_y}")

    assert_start(object_record(0, 0), True)
    assert_start(object_record(maximum_x, maximum_y), True)
    assert_start(object_record(maximum_x + 1, maximum_y), False)
    assert_start(object_record(maximum_x, maximum_y + 1), False)
    assert_start(object_record(0, 0, z=LEVEL_COUNT), False)
    assert_start(object_record(0, 0, template_index=1), False)
    assert_start(object_record(0, 0, reserved=b"\x00\x00\x01\x00\x00"), False)

    town_template = {
        "template_index": 0,
        "def_name": "anchor-town-test.def",
        "passability_mask": b"\x00" * 6,
        "action_mask": b"\x00" * 6,
        "type_id": 98,
        "type_name": "town",
        "subtype": 0,
    }
    simple_template = {
        "template_index": 1,
        "def_name": "anchor-simple-test.def",
        "passability_mask": b"\x00" * 6,
        "action_mask": b"\x00" * 6,
        "type_id": 101,
        "type_name": "treasure_chest",
        "subtype": 0,
    }
    false_embedded_start = object_record(0, 0, template_index=0)
    town_record = object_record(4, 5, template_index=0) + false_embedded_start + b"\x00" * 24
    expected_coordinates = [(4, 5), (7, 8), (maximum_x, maximum_y)]
    payload = (
        len(expected_coordinates).to_bytes(4, "little")
        + town_record
        + object_record(7, 8, template_index=1)
        + object_record(maximum_x, maximum_y, template_index=1)
    )
    parsed = rmg_fast_audit.parse_h3m_object_instances(
        payload,
        0,
        [town_template, simple_template],
        MAP_SIZE,
        LEVEL_COUNT,
    )
    actual_coordinates = [(int(row["x"]), int(row["y"])) for row in parsed.get("records", [])]
    if parsed.get("status") != "parsed" or parsed.get("parse_quality") != "complete":
        raise AssertionError(f"synthetic stream did not parse completely: {parsed}")
    if int(parsed.get("declared_object_count", -1)) != 3 or int(parsed.get("parsed_object_count", -1)) != 3:
        raise AssertionError(f"synthetic stream object count drifted: {parsed}")
    if actual_coordinates != expected_coordinates:
        raise AssertionError(f"synthetic stream lost order: expected={expected_coordinates} actual={actual_coordinates}")
    identity_rows = [
        {
            "index": index,
            "x": int(row["x"]),
            "y": int(row["y"]),
            "level": int(row["level"]),
            "definition_index": int(row["template_index"]),
            "type_id": int(row["type_id"]),
            "subtype": int(row["subtype"]),
            "def_name": str(row["def_name"]),
        }
        for index, row in enumerate(parsed["records"])
    ]
    identity_sha256 = rmg_fast_audit.object_identity_sha256(identity_rows)
    if len(identity_sha256) != 64:
        raise AssertionError(f"synthetic stream identity hash is invalid: {identity_sha256}")

    print(
        "RMG_FAST_AUDIT_H3M_ANCHOR_REGRESSION "
        + json.dumps(
            {
                "ok": True,
                "map_size": MAP_SIZE,
                "maximum_anchor": [maximum_x, maximum_y],
                "parsed_object_count": int(parsed["parsed_object_count"]),
                "coordinates": actual_coordinates,
                "identity_sha256": identity_sha256,
            },
            sort_keys=True,
            separators=(",", ":"),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
