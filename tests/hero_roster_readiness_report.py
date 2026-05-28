#!/usr/bin/env python3
from __future__ import annotations

import json
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"

SUPPORTED_BATTLE_TRAITS = {
    "ambusher",
    "artillerist",
    "bogwise",
    "linekeeper",
    "packhunter",
    "vanguard",
}


def load_items(filename: str) -> dict[str, dict]:
    with (CONTENT / filename).open(encoding="utf-8") as handle:
        payload = json.load(handle)
    return {str(item["id"]): item for item in payload.get("items", [])}


def main() -> int:
    factions = load_items("factions.json")
    heroes = load_items("heroes.json")
    spells = load_items("spells.json")
    errors: list[str] = []
    rows: list[dict] = []

    specialty_ids = {
        "armsmaster",
        "borderwarden",
        "drillmaster",
        "ledgerkeeper",
        "mustercaptain",
        "spellwright",
        "wayfinder",
    }
    heroes_by_faction: dict[str, list[dict]] = defaultdict(list)
    for hero in heroes.values():
        heroes_by_faction[str(hero.get("faction_id", ""))].append(hero)

    for faction_id in sorted(factions):
        faction_heroes = sorted(heroes_by_faction.get(faction_id, []), key=lambda item: str(item.get("id", "")))
        live_heroes = [hero for hero in faction_heroes if str(hero.get("roster_state", "")) == "live"]
        if len(faction_heroes) != 10:
            errors.append(f"{faction_id} expected 10 heroes, found {len(faction_heroes)}")
        if len(live_heroes) != 10:
            errors.append(f"{faction_id} expected 10 live heroes, found {len(live_heroes)}")

        path_counts = Counter(str(hero.get("command_path", "")) for hero in faction_heroes)
        if path_counts.get("might", 0) < 5 or path_counts.get("magic", 0) < 5:
            errors.append(f"{faction_id} must keep at least five might and five magic heroes")

        command_signatures = set()
        trait_signatures = set()
        primary_specialties = Counter()
        for hero in faction_heroes:
            hero_id = str(hero.get("id", ""))
            if not str(hero.get("identity_summary", "")).strip():
                errors.append(f"{hero_id} missing identity_summary")
            command = hero.get("command", {})
            if not isinstance(command, dict):
                errors.append(f"{hero_id} command must be a dictionary")
                command = {}
            command_tuple = tuple(int(command.get(key, 0)) for key in ["attack", "defense", "power", "knowledge"])
            command_signatures.add(command_tuple)
            if sum(command_tuple) <= 0:
                errors.append(f"{hero_id} command stats must have a live gameplay value")

            traits = [str(value) for value in hero.get("battle_traits", [])]
            if not traits:
                errors.append(f"{hero_id} must have at least one battle trait")
            for trait in traits:
                if trait not in SUPPORTED_BATTLE_TRAITS:
                    errors.append(f"{hero_id} has unsupported battle trait {trait}")
            trait_signatures.add(tuple(sorted(traits)))

            starting_specialties = [str(value) for value in hero.get("starting_specialties", [])]
            focus_specialties = [str(value) for value in hero.get("specialty_focus_ids", [])]
            if not starting_specialties:
                errors.append(f"{hero_id} must have a starting specialty")
            else:
                primary_specialties[starting_specialties[0]] += 1
            for specialty_id in starting_specialties + focus_specialties:
                if specialty_id not in specialty_ids:
                    errors.append(f"{hero_id} has unsupported specialty {specialty_id}")

            spell_ids = [str(value) for value in hero.get("starting_spell_ids", [])]
            if len(spell_ids) < 3:
                errors.append(f"{hero_id} must start with at least three spells")
            for spell_id in spell_ids:
                if spell_id not in spells:
                    errors.append(f"{hero_id} references missing spell {spell_id}")

        if len(command_signatures) < 6:
            errors.append(f"{faction_id} needs at least six distinct command profiles, found {len(command_signatures)}")
        if len(trait_signatures) < 5:
            errors.append(f"{faction_id} needs at least five distinct battle trait profiles, found {len(trait_signatures)}")
        if len(primary_specialties) < 5:
            errors.append(f"{faction_id} needs at least five starting specialty lanes, found {len(primary_specialties)}")

        rows.append(
            {
                "faction_id": faction_id,
                "hero_count": len(faction_heroes),
                "live_count": len(live_heroes),
                "might_count": path_counts.get("might", 0),
                "magic_count": path_counts.get("magic", 0),
                "command_profile_count": len(command_signatures),
                "battle_trait_profile_count": len(trait_signatures),
                "starting_specialty_lane_count": len(primary_specialties),
            }
        )

    report = {"ok": not errors, "errors": errors, "rows": rows}
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
