#!/usr/bin/env python3
"""Repository content check.

Checks only what breaks the game when it is wrong and keeps its shape when content grows:

- every content/*.json file parses and its items have unique ids;
- every id reference (fields named <domain>_id or <domain>_ids) points at an existing record;
- every unit, hero, spell, building and faction has its art manifest entry;
- every runtime res:// path in content, art manifests, game scripts and scenes exists;
- project.godot's main scene and autoloads exist, scenes reference existing resources,
  and connected signal methods exist on the scene script;
- owner economy rule: units cost gold only, tier 7 adds the faction's main rare resource;
- the shipped godot-cpp notice matches the vendored license.

Runs in a few seconds on Windows and Linux and is part of tools/core_suite.py.
Do not add checks that pin source text, UI strings, layout, file sizes or tuned numbers
(AGENTS.md "Validation budget"). Source art under art/*/source/ lives in external archives
and is not checked.
"""
from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTENT_DIR = ROOT / "content"

# Content domain -> file whose "items" define its ids.
DOMAIN_FILES = {
    "unit": "units.json",
    "hero": "heroes.json",
    "spell": "spells.json",
    "artifact": "artifacts.json",
    "building": "buildings.json",
    "town": "towns.json",
    "encounter": "encounters.json",
    "army_group": "army_groups.json",
    "faction": "factions.json",
    "biome": "biomes.json",
    "resource_site": "resource_sites.json",
    "site": "resource_sites.json",
    "map_object": "map_objects.json",
    "resource": "resources.json",
    "neutral_dwelling_family": "neutral_dwellings.json",
}
# Fields named like "unit_id", "guard_army_group_id" or "starting_spell_ids" reference that domain.
REFERENCE_KEY = re.compile(r"(?:^|_)(" + "|".join(sorted(DOMAIN_FILES, key=len, reverse=True)) + r")_ids?$")
# Values that mean "no owner" rather than a faction id.
NO_FACTION = {"", "neutral"}
# Every record of the domain needs an entry (by id or <domain>_id) in this manifest.
ART_COVERAGE = {
    "unit": ("unit_art_manifest.json", "unit_animation_manifest.json"),
    "hero": ("hero_art_manifest.json",),
    "spell": ("spell_icons.json",),
    "building": ("building_art_manifest.json",),
    "faction": ("faction_crests.json",),
}
COMMON_RESOURCES = {"gold", "wood", "ore"}


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def walk_strings(value, key: str = ""):
    """Yield (key, string) for every string in a JSON value; list items keep their parent key."""
    if isinstance(value, dict):
        for child_key, child in value.items():
            yield from walk_strings(child, str(child_key))
    elif isinstance(value, list):
        for child in value:
            yield from walk_strings(child, key)
    elif isinstance(value, str):
        yield key, value


def res_path_exists(res_path: str) -> bool:
    return (ROOT / res_path.removeprefix("res://")).exists()


def is_checked_res_path(res_path: str) -> bool:
    """Runtime paths only: source art is archived outside Git, the HoMM3 prototype art is
    local-only, and templates or directories are not single files."""
    return not (
        "/source/" in res_path
        or "homm3_local_prototype" in res_path
        or res_path.endswith("/")
        or any(char in res_path for char in "%{}*")
        or Path(res_path).name.startswith("missing_")
    )


def check_content(errors: list[str]) -> dict:
    content: dict[str, object] = {}
    for path in sorted(CONTENT_DIR.rglob("*.json")):
        name = path.relative_to(CONTENT_DIR).as_posix()
        try:
            content[name] = load_json(path)
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"content/{name} does not parse: {exc}")

    domain_ids: dict[str, set[str]] = {}
    for domain, file_name in DOMAIN_FILES.items():
        payload = content.get(file_name)
        items = payload.get("items") if isinstance(payload, dict) else None
        if not isinstance(items, list):
            errors.append(f"content/{file_name} must have an items list")
            domain_ids[domain] = set()
            continue
        ids = [item.get("id") for item in items if isinstance(item, dict)]
        missing = len(items) - sum(1 for item_id in ids if isinstance(item_id, str) and item_id)
        if missing:
            errors.append(f"content/{file_name}: {missing} items have no id")
        duplicates = sorted(item_id for item_id, count in Counter(ids).items() if count > 1 and item_id)
        if duplicates:
            errors.append(f"content/{file_name}: duplicate ids {duplicates[:10]}")
        domain_ids[domain] = {item_id for item_id in ids if isinstance(item_id, str)}

    # Generated neutral companies define their own encounter ids.
    companies = content.get("generated_neutral_companies.json", {})
    company_encounters = {
        str(company.get("encounter_id"))
        for company in (companies.get("companies", []) if isinstance(companies, dict) else [])
        if isinstance(company, dict)
    }
    domain_ids["encounter"] |= company_encounters

    for name, payload in content.items():
        dangling: Counter[str] = Counter()
        for key, value in walk_strings(payload):
            if value.startswith("res://"):
                if is_checked_res_path(value) and not res_path_exists(value):
                    errors.append(f"content/{name}: missing file {value}")
                continue
            match = REFERENCE_KEY.search(key)
            if match is None:
                continue
            domain = match.group(1)
            if domain == "faction" and value in NO_FACTION:
                continue
            if value not in domain_ids[domain]:
                dangling[f"{key}={value}"] += 1
        for reference, count in sorted(dangling.items()):
            errors.append(f"content/{name}: unknown {reference}" + (f" ({count}x)" if count > 1 else ""))

    for domain, manifests in ART_COVERAGE.items():
        for manifest in manifests:
            payload = content.get(manifest, {})
            covered: set[str] = set()
            for item in payload.get("items", []) if isinstance(payload, dict) else []:
                if isinstance(item, dict):
                    covered.update(str(item.get(field, "")) for field in ("id", f"{domain}_id"))
            missing = sorted(domain_ids[domain] - covered)
            if missing:
                errors.append(f"content/{manifest} has no entry for {len(missing)} {domain}s: {missing[:10]}")
    return content


def check_unit_costs(content: dict, errors: list[str]) -> None:
    """Owner rule content-gold-only-unit-costs-20261006."""
    factions = {item["id"]: item for item in content.get("factions.json", {}).get("items", []) if isinstance(item, dict) and "id" in item}
    resources = {item["id"] for item in content.get("resources.json", {}).get("items", []) if isinstance(item, dict) and "id" in item}
    rare_resources = resources - COMMON_RESOURCES
    for unit in content.get("units.json", {}).get("items", []):
        if not isinstance(unit, dict):
            continue
        unit_id = unit.get("id")
        cost = unit.get("cost", {})
        if not isinstance(cost, dict) or int(cost.get("gold", 0)) <= 0:
            errors.append(f"{unit_id} must have a positive gold cost")
            continue
        extra = sorted(str(key) for key in cost if key != "gold")
        if int(unit.get("tier", 0)) < 7:
            if extra:
                errors.append(f"{unit_id} is tier {unit.get('tier')} and must cost gold only, not {extra}")
            continue
        main_rare = str(factions.get(str(unit.get("faction_id", "")), {}).get("town_resources", {}).get("main", ""))
        expected = [main_rare] if main_rare else extra[:1]
        if extra != expected or not expected or expected[0] not in rare_resources or int(cost[expected[0]]) <= 0:
            errors.append(f"{unit_id} is tier 7 and must cost gold plus one rare ({main_rare or 'any'}), not {extra}")


def check_art_manifests(errors: list[str]) -> None:
    for path in sorted((ROOT / "art").rglob("*.json")):
        relative = path.relative_to(ROOT).as_posix()
        if "/source/" in relative or "homm3_local_prototype" in relative:
            continue
        try:
            payload = load_json(path)
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"{relative} does not parse: {exc}")
            continue
        missing = sorted({value for _key, value in walk_strings(payload) if value.startswith("res://") and is_checked_res_path(value) and not res_path_exists(value)})
        for res_path in missing[:20]:
            errors.append(f"{relative}: missing file {res_path}")
        if len(missing) > 20:
            errors.append(f"{relative}: {len(missing) - 20} more missing files")


def check_scripts(errors: list[str]) -> None:
    for root in ("scripts", "scenes"):
        for path in sorted((ROOT / root).rglob("*.gd")):
            text = path.read_text(encoding="utf-8")
            for res_path in sorted(set(re.findall(r'"(res://[^"]+)"', text))):
                if is_checked_res_path(res_path) and not res_path_exists(res_path):
                    errors.append(f"{path.relative_to(ROOT).as_posix()} references missing {res_path}")


def check_project_and_scenes(errors: list[str]) -> None:
    project_text = (ROOT / "project.godot").read_text(encoding="utf-8")
    main_scene = re.search(r'run/main_scene="([^"]+)"', project_text)
    if main_scene is None or not res_path_exists(main_scene.group(1)):
        errors.append("project.godot run/main_scene is missing or points at a missing scene")
    for name, res_path in re.findall(r'^([A-Za-z0-9_]+)="\*?(res://[^"]+)"', project_text, flags=re.MULTILINE):
        if not res_path_exists(res_path):
            errors.append(f"Autoload {name} points at missing {res_path}")

    for scene_path in sorted((ROOT / "scenes").rglob("*.tscn")):
        text = scene_path.read_text(encoding="utf-8")
        relative = scene_path.relative_to(ROOT).as_posix()
        for res_path in re.findall(r'path="(res://[^"]+)"', text):
            if not res_path_exists(res_path):
                errors.append(f"{relative} references missing {res_path}")
        script = re.search(r'\[ext_resource type="Script" path="(res://[^"]+)"', text)
        if script is None or not res_path_exists(script.group(1)):
            continue
        script_text = (ROOT / script.group(1).removeprefix("res://")).read_text(encoding="utf-8")
        for method in sorted(set(re.findall(r'method="([^"]+)"', text))):
            if re.search(rf"func\s+{re.escape(method)}\s*\(", script_text) is None:
                errors.append(f"{relative} connects missing method {method} in {script.group(1)}")


def check_third_party_notices(content: dict, errors: list[str]) -> None:
    license_path = ROOT / "third_party" / "godot-cpp" / "LICENSE.md"
    if not license_path.exists():
        return  # godot-cpp submodule not checked out here
    vendored = license_path.read_text(encoding="utf-8").removeprefix("# MIT License\n\n").strip()
    items = content.get("third_party_notices.json", {}).get("items", [])
    godot_cpp = next((item for item in items if isinstance(item, dict) and item.get("id") == "godot_cpp"), None)
    if godot_cpp is None:
        errors.append("content/third_party_notices.json must list godot_cpp")
    elif str(godot_cpp.get("license_text", "")).strip() != vendored:
        errors.append("content/third_party_notices.json godot_cpp license text must match third_party/godot-cpp/LICENSE.md")


def main() -> int:
    errors: list[str] = []
    content = check_content(errors)
    check_unit_costs(content, errors)
    check_art_manifests(errors)
    check_scripts(errors)
    check_project_and_scenes(errors)
    check_third_party_notices(content, errors)
    if errors:
        print("VALIDATION FAILED")
        for error in errors:
            print(f"- {error}")
        return 1
    print("VALIDATION PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
