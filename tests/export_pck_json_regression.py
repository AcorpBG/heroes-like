#!/usr/bin/env python3
"""Compare every JSON member through the real Godot parser in both PCKs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from compact_export_pck import eligible, read_directory, verify_payloads

SCRIPT = '''extends SceneTree
func _initialize() -> void:
 var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("PCK_JSON_CONFIG")))
 var errors: Array = []
 var original: Dictionary = {}
 var rows: Array = []
 for pass_index in range(2):
  if not ProjectSettings.load_resource_pack(config.packs[pass_index], true):
   errors.append("Could not load pack " + str(pass_index))
   break
  for path in config.paths:
   var parser := JSON.new()
   var text := FileAccess.get_file_as_string("res://" + path)
   if parser.parse(text) != OK:
    errors.append("Godot parse failed: " + path)
    continue
   var canonical := JSON.stringify(parser.data, "", true, true)
   if pass_index == 0:
    original[path] = canonical
   else:
    var equal: bool = original.has(path) and original[path] == canonical
    if not equal: errors.append("Godot parsed content changed: " + path)
    rows.append({"path":path,"parsed_equal":equal,"parsed_sha256":canonical.sha256_text()})
 print("PCK_JSON_EQUIVALENCE " + JSON.stringify({"ok":errors.is_empty() and rows.size()==config.paths.size(),"errors":errors,"rows":rows}))
 quit(0 if errors.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    packs = [p.resolve(strict=True) for p in (args.before, args.after)]
    hashes = [hashlib.sha256(p.read_bytes()).hexdigest() for p in packs]
    preservation = verify_payloads(packs[0].read_bytes(), packs[1].read_bytes())
    _, entries = read_directory(packs[0].read_bytes())
    paths = [e.path for e in entries if eligible(e.path)]
    args.output.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix="heroes-pck-json-") as directory:
        work = Path(directory)
        (work / "project.godot").write_text('config_version=5\n[application]\nconfig/name="PCK JSON probe"\n')
        (work / "probe.gd").write_text(SCRIPT)
        (work / "config.json").write_text(json.dumps({"packs": [str(p) for p in packs], "paths": paths}))
        result = subprocess.run(["godot4", "--headless", "--path", str(work), "--script", str(work / "probe.gd")],
                                env=dict(os.environ, PCK_JSON_CONFIG=str(work / "config.json"), GODOT_SILENCE_ROOT_WARNING="1"),
                                capture_output=True, text=True, timeout=60)
    log = result.stdout + result.stderr
    (args.output / "runtime.log").write_text(log)
    prefix = "PCK_JSON_EQUIVALENCE "
    reports = [json.loads(line[len(prefix):]) for line in log.splitlines() if line.startswith(prefix)]
    report = reports[-1] if reports else {"ok": False, "errors": ["Missing Godot report"]}
    report.update(returncode=result.returncode, preservation=preservation, source_pack_sha256=hashes,
                  packs_unchanged=hashes == [hashlib.sha256(p.read_bytes()).hexdigest() for p in packs],
                  runtime_errors=[line for line in log.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:")) or "leaked" in line])
    report["ok"] = bool(report["ok"] and not report["runtime_errors"] and result.returncode == 0 and report["packs_unchanged"])
    (args.output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"ok": report["ok"], "parsed_members": len(report.get("rows", [])), "entries_verified": preservation["entries_verified"], "errors": report["errors"], "runtime_errors": report["runtime_errors"]}))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
