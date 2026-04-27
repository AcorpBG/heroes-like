#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"

FACTION_IDS = {
    "faction_embercourt",
    "faction_mireclaw",
    "faction_sunvault",
    "faction_thornwake",
    "faction_brasshollow",
    "faction_veilmourn",
}


def load_index(filename: str) -> dict[str, dict[str, Any]]:
    with (CONTENT / filename).open(encoding="utf-8") as handle:
        payload = json.load(handle)
    return {str(item["id"]): item for item in payload.get("items", [])}


def require(condition: bool, errors: list[str], message: str) -> None:
    if not condition:
        errors.append(message)


def resource_fingerprint(value: Any) -> tuple[tuple[str, int], ...]:
    if not isinstance(value, dict):
        return ()
    return tuple(sorted((str(key), int(amount)) for key, amount in value.items()))


def unit_ability_ids(unit: dict[str, Any]) -> tuple[str, ...]:
    abilities = unit.get("abilities", [])
    if not isinstance(abilities, list):
        return ()
    return tuple(str(ability.get("id", "")) for ability in abilities if isinstance(ability, dict))


def main() -> int:
    factions = load_index("factions.json")
    towns = load_index("towns.json")
    units = load_index("units.json")
    heroes = load_index("heroes.json")
    buildings = load_index("buildings.json")

    errors: list[str] = []
    report: dict[str, Any] = {"factions": {}, "unique_fingerprints": {}}
    unit_fingerprints: dict[tuple[Any, ...], str] = {}
    building_fingerprints: dict[tuple[Any, ...], str] = {}
    hero_fingerprints: dict[tuple[Any, ...], str] = {}
    town_economy_fingerprints: dict[tuple[Any, ...], str] = {}

    require(FACTION_IDS.issubset(factions.keys()), errors, "All six bible faction ids must exist")

    for faction_id in sorted(FACTION_IDS):
        faction = factions.get(faction_id, {})
        ladder_ids = [str(value) for value in faction.get("unit_ladder_ids", [])]
        signature_building_ids = [str(value) for value in faction.get("signature_building_ids", [])]
        hero_ids = [str(value) for value in faction.get("bible_hero_ids", [])]
        seed_town_id = str(faction.get("seed_town_id", ""))
        seed_town = towns.get(seed_town_id, {})

        require(len(ladder_ids) == 7 and len(set(ladder_ids)) == 7, errors, f"{faction_id} must keep seven unique ladder units")
        require(len(signature_building_ids) == 7 and len(set(signature_building_ids)) == 7, errors, f"{faction_id} must keep seven unique signature buildings")
        require(len(hero_ids) >= 10 and len(set(hero_ids)) == len(hero_ids), errors, f"{faction_id} must keep at least ten unique hero concepts")
        require(bool(seed_town), errors, f"{faction_id} seed town {seed_town_id} must exist")
        require(str(seed_town.get("faction_id", "")) == faction_id, errors, f"{seed_town_id} must belong to {faction_id}")

        town_building_ids = [
            str(value)
            for value in seed_town.get("starting_building_ids", []) + seed_town.get("buildable_building_ids", [])
        ]
        missing_signature_buildings = sorted(set(signature_building_ids) - set(town_building_ids))
        require(
            not missing_signature_buildings,
            errors,
            f"{seed_town_id} must expose all {faction_id} signature buildings: {missing_signature_buildings}",
        )

        unlocked_ladder_ids: list[str] = []
        building_categories: list[str] = []
        for building_id in signature_building_ids:
            building = buildings.get(building_id, {})
            require(bool(building), errors, f"{faction_id} signature building {building_id} must exist")
            unlock_unit_id = str(building.get("unlock_unit_id", ""))
            require(unlock_unit_id in ladder_ids, errors, f"{building_id} must unlock a {faction_id} ladder unit")
            if unlock_unit_id:
                unlocked_ladder_ids.append(unlock_unit_id)
            growth_bonus = building.get("growth_bonus", {})
            discount = building.get("recruitment_discount_percent", {})
            require(isinstance(growth_bonus, dict) and int(growth_bonus.get(unlock_unit_id, 0)) > 0, errors, f"{building_id} must grow its unlocked unit")
            require(isinstance(discount, dict) and int(discount.get(unlock_unit_id, 0)) > 0, errors, f"{building_id} must discount its unlocked unit")
            building_categories.append(str(building.get("category", "")))

        require(
            set(unlocked_ladder_ids) == set(ladder_ids),
            errors,
            f"{faction_id} signature buildings must unlock exactly the faction ladder",
        )

        town_growth = seed_town.get("recruitment", {}).get("growth_bonus", {})
        town_discount = seed_town.get("recruitment", {}).get("cost_discount_percent", {})
        ladder_growth_hooks = sorted(set(town_growth.keys()) & set(ladder_ids)) if isinstance(town_growth, dict) else []
        ladder_discount_hooks = sorted(set(town_discount.keys()) & set(ladder_ids)) if isinstance(town_discount, dict) else []
        require(len(ladder_growth_hooks) >= 2, errors, f"{seed_town_id} must directly grow at least two {faction_id} ladder units")
        require(len(ladder_discount_hooks) >= 2, errors, f"{seed_town_id} must directly discount at least two {faction_id} ladder units")

        unit_signature = []
        for expected_tier, unit_id in enumerate(ladder_ids, start=1):
            unit = units.get(unit_id, {})
            require(bool(unit), errors, f"{faction_id} ladder unit {unit_id} must exist")
            require(str(unit.get("faction_id", "")) == faction_id, errors, f"{unit_id} must belong to {faction_id}")
            require(int(unit.get("tier", 0)) == expected_tier, errors, f"{unit_id} must occupy ladder tier {expected_tier}")
            unit_signature.append(
                (
                    str(unit.get("role", "")),
                    unit_ability_ids(unit),
                    int(unit.get("speed", 0)),
                    int(unit.get("initiative", 0)),
                    resource_fingerprint(unit.get("cost", {})),
                )
            )

        might_count = 0
        magic_count = 0
        hero_archetypes = []
        for hero_id in hero_ids:
            hero = heroes.get(hero_id, {})
            require(bool(hero), errors, f"{faction_id} hero {hero_id} must exist")
            require(str(hero.get("faction_id", "")) == faction_id, errors, f"{hero_id} must belong to {faction_id}")
            command_path = str(hero.get("command_path", ""))
            if command_path == "might":
                might_count += 1
            elif command_path == "magic":
                magic_count += 1
            else:
                errors.append(f"{hero_id} must declare command_path might or magic")
            require(bool(str(hero.get("identity_summary", ""))), errors, f"{hero_id} must keep an identity_summary")
            hero_archetypes.append(str(hero.get("archetype", "")))
        require(might_count >= 5 and magic_count >= 5, errors, f"{faction_id} must keep at least five might and five magic hero concepts")

        unit_fingerprint = tuple(unit_signature)
        building_fingerprint = tuple(building_categories)
        hero_fingerprint = tuple(sorted(hero_archetypes))
        economy = seed_town.get("economy", {})
        town_economy_fingerprint = (
            resource_fingerprint(economy.get("base_income", {})),
            tuple(sorted(str(key) for key in economy.get("per_category_income", {}).keys()))
            if isinstance(economy.get("per_category_income", {}), dict)
            else (),
            int(economy.get("pressure_bonus", 0)),
        )

        for registry, fingerprint, label in (
            (unit_fingerprints, unit_fingerprint, "unit ladder"),
            (building_fingerprints, building_fingerprint, "signature building category"),
            (hero_fingerprints, hero_fingerprint, "hero archetype"),
            (town_economy_fingerprints, town_economy_fingerprint, "seed town economy"),
        ):
            previous = registry.get(fingerprint)
            require(previous is None, errors, f"{faction_id} shares {label} fingerprint with {previous}")
            registry[fingerprint] = faction_id

        report["factions"][faction_id] = {
            "seed_town_id": seed_town_id,
            "signature_building_count": len(signature_building_ids),
            "signature_building_categories": building_categories,
            "ladder_units_unlocked_by_signature_buildings": unlocked_ladder_ids,
            "town_ladder_growth_hooks": ladder_growth_hooks,
            "town_ladder_discount_hooks": ladder_discount_hooks,
            "hero_roster": {"might": might_count, "magic": magic_count},
            "unit_role_sequence": [signature[0] for signature in unit_signature],
        }

    report["ok"] = not errors
    report["errors"] = errors
    report["unique_fingerprints"] = {
        "unit_ladders": len(unit_fingerprints),
        "signature_building_categories": len(building_fingerprints),
        "hero_archetype_sets": len(hero_fingerprints),
        "seed_town_economies": len(town_economy_fingerprints),
    }
    print("FACTION_TOWN_UNIT_ASYMMETRY_REPORT " + json.dumps(report, sort_keys=True))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
