#!/usr/bin/env python3
"""Compare content lookups with the original ordered scan and check invalidation."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / ".artifacts/full_play_runtime_20260905/content_lookup"
MARKER = "CONTENT_LOOKUP_REGRESSION "
SCRIPT = r'''
extends Node
var errors := []
var checked := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)

func scan(service, path: String, id: String, list_key: String = "items", id_field: String = "id") -> Dictionary:
	var raw: Dictionary = service.load_json(path)
	for item in service._items_from_raw(raw, list_key):
		if String(item.get(id_field, item.get("id", ""))) == id:
			return item
	return {}

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var service = load("res://scripts/autoload/ContentService.gd").new()
	for path in [service.FACTIONS_PATH, service.HEROES_PATH, service.UNITS_PATH, service.ARMY_GROUPS_PATH, service.TOWNS_PATH, service.BUILDINGS_PATH, service.RESOURCES_PATH, service.RESOURCE_SITES_PATH, service.BIOMES_PATH, service.MAP_OBJECTS_PATH, service.NEUTRAL_DWELLINGS_PATH, service.ARTIFACTS_PATH, service.SPELLS_PATH, service.CAMPAIGNS_PATH, service.ENCOUNTERS_PATH, service.SCENARIOS_PATH]:
		for row in service._items_from_raw(service.load_json(path)):
			var id := String(row.get("id", ""))
			var expected := scan(service, path, id)
			var actual: Dictionary = service.get_content_by_id(path, id)
			check(is_same(expected, actual), "lookup changed identity: " + path + ":" + id)
			checked += 1
		check(service.get_content_by_id(path, "missing_content_lookup_fixture").is_empty(), "missing id did not remain missing")
	for spec in [[service.HERO_ART_PATH, "hero_id", "get_hero_art"], [service.UNIT_ART_PATH, "unit_id", "get_unit_art"], [service.UNIT_ANIMATION_PATH, "unit_id", "get_unit_animation"]]:
		for row in service._items_from_raw(service.load_json(spec[0])):
			var id := String(row.get(spec[1], row.get("id", "")))
			check(is_same(scan(service, spec[0], id, "items", spec[1]), service.call(spec[2], id)), "art lookup changed identity: " + id)
			checked += 1
		check(service.call(spec[2], "missing_content_lookup_fixture").is_empty(), "missing art must not return a fallback")
	var fixture := "res://content/lookup_test_only.json"
	service._cache[fixture] = {"items": [{"id": "repeat", "value": 1}, {"id": "repeat", "value": 2}, {"value": 3}], "other": [{"id": "repeat", "value": 4}]}
	check(service.get_content_by_id(fixture, "repeat").value == 1, "first duplicate wins")
	check(service.get_content_by_id(fixture, "").value == 3, "missing id keeps empty-string lookup semantics")
	check(service.get_content_by_id(fixture, "repeat", "other").value == 4, "list keys must not collide")
	check(service._indexed_content_row(fixture, "repeat", "items", "hero_id").value == 1, "alternate id field retains id fallback")
	service._cache[fixture].items[0].value = 7
	check(service.get_content_by_id(fixture, "repeat").value == 7, "lookup copied a live borrowed row")
	service._cache[fixture].items.append({"id": "appended", "value": 6})
	check(service.get_content_by_id(fixture, "appended").value == 6, "array size growth must rebuild the index")
	service._cache[fixture].items.pop_back()
	check(service.get_content_by_id(fixture, "appended").is_empty(), "array size reduction must remove stale ids")
	service._cache[fixture] = {"entries": [{"id": "repeat", "value": 8}]}
	check(service.get_content_by_id(fixture, "repeat").value == 8, "replacement source/entries fallback stale")
	service.clear_cache()
	service._cache[fixture] = {"items": [{"id": "repeat", "value": 9}]}
	check(service.get_content_by_id(fixture, "repeat").value == 9, "clear_cache retained an index")
	var paths := [service.UNITS_PATH, service.BUILDINGS_PATH, service.RESOURCE_SITES_PATH, service.SCENARIOS_PATH]
	var timings := []
	for path in paths:
		var items: Array = service._items_from_raw(service.load_json(path))
		var id := String(items[-1].id)
		scan(service, path, id)
		service.get_content_by_id(path, id)
		var legacy_samples := []
		var current_samples := []
		for repeat in range(5):
			var started := Time.get_ticks_usec()
			for i in range(2000):
				scan(service, path, id)
			legacy_samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
			started = Time.get_ticks_usec()
			for i in range(2000):
				service.get_content_by_id(path, id)
			current_samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
		legacy_samples.sort()
		current_samples.sort()
		timings.append({"path": path, "rows": items.size(), "calls_per_sample": 2000, "scan_samples_ms": legacy_samples, "current_samples_ms": current_samples, "scan_ms": legacy_samples[2], "current_ms": current_samples[2], "ratio": current_samples[2] / maxf(legacy_samples[2], 0.001)})
	print("CONTENT_LOOKUP_REGRESSION " + JSON.stringify({"ok": errors.is_empty(), "errors": errors, "checked_rows": checked, "timings": timings}))
	service.free()
	get_tree().quit(0 if errors.is_empty() else 1)
'''


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", default="current")
    parser.add_argument("--require-improvement", action="store_true")
    args = parser.parse_args()
    if not args.label or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in args.label):
        parser.error("invalid label")
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix="probe-", dir=OUTPUT) as temporary:
        work = Path(temporary)
        script = work / "probe.gd"
        script.write_text(SCRIPT)
        scene = work / "probe.tscn"
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Probe" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        env = dict(os.environ, XDG_DATA_HOME=str(work / "data"))
        with (out / "runtime.log").open("w") as log:
            result = subprocess.run(["godot4", "--headless", "--path", str(ROOT), "--audio-driver", "Dummy", "res://" + str(scene.relative_to(ROOT))], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=120)
    lines = (out / "runtime.log").read_text().splitlines()
    markers = [line[len(MARKER):] for line in lines if line.startswith(MARKER)]
    report = json.loads(markers[-1]) if markers else {"ok": False, "errors": lines[-20:]}
    report["runtime_errors"] = [line for line in lines if line.startswith(("SCRIPT ERROR:", "ERROR:")) or "leaked" in line]
    if report["runtime_errors"] or result.returncode:
        report["ok"] = False
    if args.require_improvement and (len(report.get("timings", [])) != 4 or any(row["ratio"] > .25 for row in report.get("timings", []))):
        report["ok"] = False
        report["errors"].append("indexed lookup did not beat the ordered scan budget")
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))
    return result.returncode or (0 if report["ok"] else 1)


if __name__ == "__main__":
    raise SystemExit(main())
