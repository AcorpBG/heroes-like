#!/usr/bin/env python3
"""Verify stronger Godot lossless imports without changing source art or pixels.

Godot 4.6.2's texture import fingerprint omits WebP compression strength.
Stage ordinary editor imports in a disposable project at identical res:// paths,
compare every decoded mip byte, then atomically publish only verified cache files.
No image encoder, custom texture writer, lossy options or source edits live here.
"""
from __future__ import annotations

import argparse
import configparser
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
FACTOR = "textures/webp_compression/lossless_compression_factor"
SCHEMA = 1
SCRIPT = '''extends SceneTree
func _initialize() -> void:
 var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("HEROES_LOSSLESS_CONFIG")))
 var rows: Dictionary = {}
 for path in config.paths:
  var texture = ResourceLoader.load(path, "CompressedTexture2D", ResourceLoader.CACHE_MODE_IGNORE)
  if not texture is CompressedTexture2D:
   push_error("Not a compressed texture: " + path)
   quit(1)
   return
  var pixels: Image = texture.get_image()
  if pixels == null or pixels.is_empty() or pixels.is_compressed():
   push_error("Missing decoded pixels: " + path)
   quit(1)
   return
  var hash := HashingContext.new()
  hash.start(HashingContext.HASH_SHA256)
  hash.update(pixels.get_data())
  rows[path] = {"width":pixels.get_width(), "height":pixels.get_height(), "format":pixels.get_format(), "mipmaps":pixels.get_mipmap_count(), "decoded_bytes":pixels.get_data().size(), "sha256":hash.finish().hex_encode()}
  texture = null
 var output := FileAccess.open(config.output, FileAccess.WRITE)
 output.store_string(JSON.stringify(rows))
 output.close()
 quit()
'''


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def field(text: str, name: str, default=None):
    match = re.search(r"^" + re.escape(name) + r"=(.*)$", text, re.M)
    return match[1].strip() if match else default


def safe_path(root: Path, relative: str) -> Path:
    if not relative or "\\" in relative or any(p in ("", ".", "..") for p in relative.split("/")):
        raise ValueError("Unsafe resource path: " + relative)
    path = root / relative
    if not path.resolve().is_relative_to(root.resolve()) or path.is_symlink():
        raise ValueError("Resource escapes project or is a symlink: " + relative)
    return path


def exported_pngs(root: Path) -> list[Path]:
    presets = configparser.ConfigParser(interpolation=None)
    presets.read(root / "export_presets.cfg")
    filters = []
    for section in ("preset.0", "preset.1"):
        if presets[section]["export_filter"] != '"all_resources"':
            raise ValueError("Only the shared all-resources release presets are supported")
        filters.append(json.loads(presets[section]["exclude_filter"]).split(","))
    if filters[0] != filters[1]:
        raise ValueError("Linux/Windows resource exclusion parity changed")
    return [path for path in sorted((root / "art").rglob("*.png"))
            if not any(fnmatch.fnmatchcase(path.relative_to(root).as_posix(), pattern) for pattern in filters[0])]


def discover(root: Path) -> list[dict]:
    rows = []
    for source in exported_pngs(root):
        relative = source.relative_to(root).as_posix()
        options = Path(str(source) + ".import")
        if not options.is_file():
            raise ValueError("Run the normal editor import before resolving this new raster: " + relative)
        text = options.read_text()
        if field(text, "importer") != '"texture"' or field(text, "compress/mode") != "0":
            continue  # Other importers and lossy/VRAM textures are not modified.
        source = safe_path(root, relative)
        safe_path(root, relative + ".import")
        dest = json.loads(field(text, "path", '""'))
        if not re.fullmatch(r"res://\.godot/imported/[^/]+\.ctex", dest):
            raise ValueError("Unsupported lossless texture destination: " + relative)
        if field(text, "source_file") != json.dumps("res://" + relative):
            raise ValueError("Import source mismatch: " + relative)
        cache = safe_path(root, dest[6:])
        md5_file = safe_path(root, dest[6:-5] + ".md5")
        rows.append({"source": relative, "cache": dest[6:], "source_sha256": sha(source),
                     "import_sha256": sha(options), "cache_sha256": sha(cache) if cache.exists() else None,
                     "md5_sha256": sha(md5_file) if md5_file.exists() else None})
    if not rows:
        raise ValueError("No exported lossless raster textures found")
    if len({r["cache"] for r in rows}) != len(rows):
        raise ValueError("Duplicate imported texture destination")
    return rows


def stamp(row: dict, version: str) -> dict:
    return {k: row[k] for k in ("source_sha256", "import_sha256", "cache_sha256", "md5_sha256")} | {
        "version": version, "factor": 100, "schema": SCHEMA}


def verified_hit(row: dict, version: str, entry: dict) -> bool:
    proof = entry.get("proof", {})
    decoded = proof.get("decoded", {})
    return (entry.get("stamp") == stamp(row, version)
            and proof.get("cache") == row["cache"] and proof.get("source") == row["source"]
            and proof.get("after_sha256") == row["cache_sha256"]
            and set(decoded) == {"width", "height", "format", "mipmaps", "decoded_bytes", "sha256"}
            and all(isinstance(decoded[k], int) for k in ("width", "height", "format", "mipmaps", "decoded_bytes"))
            and decoded["width"] > 0 and decoded["height"] > 0 and decoded["decoded_bytes"] > 0
            and isinstance(decoded["sha256"], str) and re.fullmatch("[0-9a-f]{64}", decoded["sha256"]) is not None)


def run_engine(godot: str, project: Path, arguments: list[str], log: Path, env=None):
    with log.open("w") as output:
        result = subprocess.run([godot, "--headless", "--path", str(project), *arguments],
                                env=dict(os.environ, GODOT_SILENCE_ROOT_WARNING="1", **(env or {})),
                                stdout=output, stderr=subprocess.STDOUT, timeout=1800)
    text = log.read_text()
    errors = [line for line in text.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:")) or "leaked" in line]
    if result.returncode or errors:
        raise ValueError(f"Godot import/decode failed ({result.returncode}): {errors[:5]}; {log}")


def import_candidate(root: Path, rows: list[dict], work: Path, factor: int, godot: str, log: Path):
    work.mkdir()
    (work / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Verified lossless import"\n[rendering]\n' + FACTOR + f"={float(factor)}\n")
    for row in rows:
        target = work / row["source"]
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root / row["source"], target)
        shutil.copyfile(root / (row["source"] + ".import"), Path(str(target) + ".import"))
    run_engine(godot, work, ["--editor", "--import"], log)
    for row in rows:
        # Godot must use exactly the original import options/UID/remap, not silently migrate them.
        if sha(work / (row["source"] + ".import")) != row["import_sha256"]:
            raise ValueError("Importer rewrote original options: " + row["source"])


def decode(paths: list[Path], work: Path, godot: str, log: Path) -> dict:
    (work / "decode.gd").write_text(SCRIPT)
    config = work / "decode.json"
    output = work / "decoded.json"
    config.write_text(json.dumps({"paths": [p.as_posix() for p in paths], "output": output.as_posix()}))
    run_engine(godot, work, ["--script", (work / "decode.gd").as_posix()], log,
               {"HEROES_LOSSLESS_CONFIG": config.as_posix()})
    rows = json.loads(output.read_text())
    if set(rows) != {p.as_posix() for p in paths}:
        raise ValueError("Decoded coverage mismatch")
    return rows


def atomic_write(path: Path, data: bytes):
    temporary = None
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=path.name + ".verified-", delete=False) as output:
            temporary = Path(output.name)
            output.write(data)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
        temporary = None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def publish(root: Path, replacements: dict[str, bytes], expected: dict[str, str | None]):
    originals = {}
    for relative in replacements:
        path = safe_path(root, relative)
        old = path.read_bytes() if path.exists() else None
        if (hashlib.sha256(old).hexdigest() if old is not None else None) != expected[relative]:
            raise ValueError("Cache changed during verification: " + relative)
        originals[relative] = old
    written = []
    try:
        for relative, data in replacements.items():
            atomic_write(root / relative, data)
            written.append(relative)
    except BaseException:
        for relative in reversed(written):
            old = originals[relative]
            if old is None:
                (root / relative).unlink()  # Only the just-created, failed transaction output.
            else:
                atomic_write(root / relative, old)
        raise


def prepare(root=ROOT, godot="godot", report: Path | None = None, only: list[str] | None = None) -> dict:
    start = time.monotonic()
    root = root.resolve()
    settings = (root / "project.godot").read_text()
    if float(field(settings, FACTOR, "25")) != 100:
        raise ValueError("Project lossless compression factor must be 100")
    if field(settings, "textures/webp_compression/compression_method", "2") != "2" or field(settings, "textures/lossless_compression/force_png", "false") != "false":
        raise ValueError("Shared lossy method / PNG override changed; outside this lossless-only contract")
    version = subprocess.check_output([godot, "--version"], text=True).strip()
    if not version.startswith("4.6.2.stable."):
        raise ValueError("Revalidate lossless import semantics before changing the Godot 4.6.2 engine")
    cache = root / ".godot"
    cache.mkdir(exist_ok=True)
    lock = cache / "lossless-import.lock"
    lock.mkdir()  # Atomic, cross-platform single-writer guard; never steal a lock.
    try:
        return _prepare_locked(root, godot, version, report, only, start)
    finally:
        lock.rmdir()


def _prepare_locked(root, godot, version, report, only, start):
    destination = report or root / ".godot/lossless-import-report.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    unimported = [p for p in exported_pngs(root) if not Path(str(p) + ".import").is_file()]
    if unimported:
        run_engine(godot, root, ["--editor", "--import"], destination.with_suffix(".initialize.log"))
    memo_path = root / ".godot/lossless-imports.json"
    memo = json.loads(memo_path.read_text()) if memo_path.exists() else {}
    all_rows = discover(root)
    if only and not set(only).issubset({r["source"] for r in all_rows}):
        raise ValueError("Requested texture is not an exported lossless PNG")
    selected = [r for r in all_rows if not only or r["source"] in only]
    pending = [r for r in selected if not verified_hit(r, version, memo.get(r["source"], {}))]
    result = {"ok": False, "version": version, "eligible": len(all_rows), "selected": len(selected),
              "reimported": len(pending), "cache_hits": len(selected) - len(pending), "rows": [], "saved_bytes": 0}
    try:
        if pending:
            # Keep logs/evidence outside the disposable import staging tree.
            with tempfile.TemporaryDirectory(prefix="heroes-lossless-") as directory:
                work = Path(directory)
                candidate = work / "candidate"
                baseline = work / "baseline"
                fresh = []
                for row in pending:
                    previous = memo.get(row["source"], {}).get("stamp", {})
                    md5_file = root / (row["cache"][:-5] + ".md5")
                    source_md5 = hashlib.md5((root / row["source"]).read_bytes(), usedforsecurity=False).hexdigest()
                    cache_current = row["cache_sha256"] and md5_file.exists() and field(md5_file.read_text(), "source_md5") == json.dumps(source_md5)
                    inputs_changed = bool(previous) and any(previous.get(k) != row[k] for k in ("source_sha256", "import_sha256"))
                    # A bootstrap editor scan can also import other missing/stale
                    # caches, so none of its new outputs is an old-strength oracle.
                    if not cache_current or inputs_changed or unimported:
                        fresh.append(row)
                if fresh:
                    import_candidate(root, fresh, baseline, 25, godot, destination.with_suffix(".baseline.log"))
                import_candidate(root, pending, candidate, 100, godot, destination.with_suffix(".import.log"))
                fresh_ids = {r["source"] for r in fresh}
                before_paths = [(baseline if row["source"] in fresh_ids else root) / row["cache"] for row in pending]
                after_paths = [candidate / row["cache"] for row in pending]
                decoded = decode(before_paths + after_paths, candidate, godot, destination.with_suffix(".decode.log"))
                replacements, expected = {}, {}
                for row, before, after in zip(pending, before_paths, after_paths):
                    old, new = before.read_bytes(), after.read_bytes()
                    if old[:8] != b"GST2\x01\x00\x00\x00" or old[:52] != new[:52] or decoded[before.as_posix()] != decoded[after.as_posix()]:
                        raise ValueError("Lossless texture header/pixels/mipmaps changed: " + row["source"])
                    detail = {"source": row["source"], "cache": row["cache"], "baseline": "fresh_default_import" if row["source"] in fresh_ids else "existing_cache",
                              "before_bytes": len(old), "after_bytes": len(new), "decoded": decoded[after.as_posix()],
                              "before_sha256": hashlib.sha256(old).hexdigest(), "after_sha256": sha(after)}
                    result["rows"].append(detail)
                    result["saved_bytes"] += len(old) - len(new)
                    for relative in (row["cache"], row["cache"][:-5] + ".md5"):
                        replacements[relative] = (candidate / relative).read_bytes()
                        expected[relative] = row["cache_sha256"] if relative.endswith(".ctex") else row["md5_sha256"]
                # Check the whole input set again immediately before publishing any output.
                for row in pending:
                    if sha(root / row["source"]) != row["source_sha256"] or sha(root / (row["source"] + ".import")) != row["import_sha256"] or (sha(root / row["cache"]) if (root / row["cache"]).exists() else None) != row["cache_sha256"]:
                        raise ValueError("Input changed during verification: " + row["source"])
                publish(root, replacements, expected)
                for row, detail in zip(pending, result["rows"]):
                    row["cache_sha256"] = detail["after_sha256"]
                    row["md5_sha256"] = sha(root / (row["cache"][:-5] + ".md5"))
                    memo[row["source"]] = {"stamp": stamp(row, version), "proof": detail}
                atomic_write(memo_path, (json.dumps(memo, indent=2) + "\n").encode())
        result.update(ok=True, seconds=round(time.monotonic() - start, 3))
    except BaseException as exc:
        result.update(error=str(exc), seconds=round(time.monotonic() - start, 3))
        destination.write_text(json.dumps(result, indent=2) + "\n")
        raise
    destination.write_text(json.dumps(result, indent=2) + "\n")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--report", type=Path)
    parser.add_argument("--only", action="append", help="explicit representative experiment; not full release preparation")
    args = parser.parse_args()
    result = prepare(godot=args.godot, report=args.report, only=args.only)
    print(json.dumps({k: v for k, v in result.items() if k != "rows"}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
