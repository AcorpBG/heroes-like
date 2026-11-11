"""Writes content/artifacts.json from the artifact catalogue (docs/artifact-system.md).

    python tools/build_artifact_content.py            # write the file
    python tools/build_artifact_content.py --check    # fail if the file differs from the catalogue

The catalogue (tools/artifact_catalogue.py) is the one copy of the artifacts
and sets; tools/artifact_reward_tables.json says who draws from each reward
list. This tool turns them into the rows the rules read:

- an artifact's bonuses under the rules' keys, a price among them with the
  opposite sign, its home line as home_bonuses, its set as set_id;
- effect_text and ui.effect_lines / price_lines / home_lines: the wording the
  game shows, the same as the catalogue doc's;
- a special effect's text, and once its rule is built (SPECIAL_IDS below) the
  id the rules read: special_id on an artifact's row, and on the last of a
  set's piece_thresholds; the game shows only those;
- a set's steps as piece_thresholds;
- each reward list's artifacts, chosen by band and faction.

It also points the map at each artifact's icon for its pickup
(art/overworld/manifest.json: artifact_field_sprites and their object_assets).
"""
import argparse
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
import artifact_catalogue as catalogue  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "content", "artifacts.json")
TABLES = os.path.join(os.path.dirname(__file__), "artifact_reward_tables.json")
MAP_MANIFEST = os.path.join(ROOT, "art", "overworld", "manifest.json")

# The special effects whose rules are in the game, by the artifact's or the set's name: the id the rules read
# (special_id on an artifact's row, and on the step a set's last piece reaches). The game shows only these.
SPECIAL_IDS = {
    "Twofold Diadem": "second_spell_first_round",
    "Crown of the Empty Throne": "seventh_specialty",
    "The Unanswered Word": "half_enemy_knowledge",
    "The Flame": "first_spell_free",
    "Shroud of the Unseen Fleet": "far_shots_halved",
    "The Unbroken Wall": "cohesion_floor",
    "Mother-Graft Mail": "round_graft_heal",
    "The Last Gate": "no_escape",
    "Never-Empty Quiver": "endless_shots",
    "Staff of the First Tree": "grants_spell",
    "The Opening Cut": "first_strike_unanswered",
    "Ring of the Noon Hour": "grants_spell",
    "The Open Hand": "area_spares_own",
    "Roadeater Boots": "roads_half",
    "Vanguard's Thunder": "first_round_first",
    "The Blood-Drum": "blood_scent",
    "The Reader's Case": "scroll_power",
    "The Ever-Coal": "grants_spell",
    "Mirror of the Far Shore": "grants_spell",
    "The Standing Order": "stand_fast",
    "Writ of Relief": "shield_neighbours",
    "The Prime Lens": "first_round_boosts_last",
    "Twin Vows": "mana_double",
    "Question and Answer": "endless_strike_back",
    "Lens and Flame": "kill_refund",
    "The Four Chimes": "mastery_plus_one",
    "Regalia of the Empty Throne": "second_build",
    "The Penitent's Burden": "prices_lifted",
    "Cartographer's Table": "flat_ground",
    "Camp Kit": "rested_march",
    "Ferryman's Fare": "free_boarding",
    "Night Watch": "keep_all_movement",
}
# The spell an artifact lets its wearer cast as if it knew it (grants_spell_id).
GRANTED_SPELLS = {
    "Staff of the First Tree": "spell_green_return",
    "Ring of the Noon Hour": "spell_eternal_noon",
    "The Ever-Coal": "spell_second_sun",
    "Mirror of the Far Shore": "spell_hollow_crown",
}
LIVE_SPECIALS = set(SPECIAL_IDS)

FACTION_SCHOOL = {"Embercourt": "beacon", "Mireclaw": "veil", "Sunvault": "beacon", "Thornwake": "root", "Brasshollow": "furnace", "Veilmourn": "veil"}
ROLES = {
    "movement": {"move", "carry"}, "scouting": {"scout"}, "combat": {"atk", "melee", "ranged", "mom", "init", "siege", "retal"},
    "defense": {"def", "taken", "guard", "health", "coh", "recover"}, "magic": catalogue.MAGIC,
    "economy": {"gold", "woodore", "rare", "plunder", "muster"}, "progression": {"exp"}, "resistance": {"sres", "cres"},
}


def slug(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower().replace("'", "")).strip("_")


def artifact_id(name):
    return "artifact_" + slug(name)


def faction_id(name):
    return "faction_" + name.lower()


def sentence(text):
    return text[0].upper() + text[1:] + "."


def artifact_row(row):
    name, slot_name, band, bonuses, extra = row
    faction = extra.get("faction", "")
    price = extra.get("price", [])
    home = extra.get("home", [])
    kinds = {bonus[0] for bonus in bonuses}
    schools = [bonus[2] for bonus in bonuses if len(bonus) > 2]
    lines = [catalogue.line(bonus) for bonus in bonuses]
    price_lines = [catalogue.line(bonus) for bonus in price]
    item = {
        "id": artifact_id(name),
        "name": name,
        "slot": slot_name,
        "artifact_class": "set_piece" if extra.get("set") else ("faction" if faction else "crafted"),
        "rarity": band,
        "family": slot_name,
        "roles": [role for role, members in ROLES.items() if kinds & members],
        "accord_affinity": schools[0] if schools else FACTION_SCHOOL.get(faction, "neutral"),
        "faction_affinity": [faction_id(faction)] if faction else [],
        "source_tags": ["pickup", "guarded_site", "artifact_cache"],
        "risk": {"cursed": False, "tradeoff": bool(price), "warning_tags": []},
        "description": sentence(extra["what"]),
        "bonuses": catalogue.rules_bonuses(list(bonuses) + list(price)),
        "effect_text": "; ".join(lines + ["price: " + text for text in price_lines]),
        "ui": {
            "summary": "; ".join(lines),
            "icon_id": "artifact_icon_" + slug(name),
            "icon_path": "res://art/artifacts/runtime/%s.png" % slug(name),
            "effect_lines": lines,
        },
    }
    if price:
        item["ui"]["price_lines"] = price_lines
    if home:
        item["home_bonuses"] = catalogue.rules_bonuses(home)
        item["ui"]["home_lines"] = [catalogue.line(bonus) for bonus in home]
    if extra.get("set"):
        item["set_id"] = "set_" + slug(extra["set"])
    if extra.get("special"):
        item["ui"]["special_text"] = extra["special"]
        item["ui"]["special_live"] = name in LIVE_SPECIALS
        if name in LIVE_SPECIALS:
            item["special_id"] = SPECIAL_IDS[name]
            if name in GRANTED_SPELLS:
                item["grants_spell_id"] = GRANTED_SPELLS[name]
    return item


def set_row(entry):
    name, blurb, steps = entry
    pieces = [row[0] for row in catalogue.ARTIFACTS if row[4].get("set") == name]
    thresholds = [{"count": count, "summary": "; ".join(catalogue.line(bonus) for bonus in step), "bonuses": catalogue.rules_bonuses(step)} for count, step in steps if not isinstance(step, str)]
    if name in LIVE_SPECIALS:
        # The full set's step: its special effect, by the id the rules read. The Penitent's Burden lifts its
        # pieces' prices, which is the same bonuses with the sign turned back.
        lifted = []
        if SPECIAL_IDS[name] == "prices_lifted":
            for row in catalogue.ARTIFACTS:
                if row[4].get("set") == name:
                    lifted += [(price[0], -price[1]) + tuple(price[2:]) for price in row[4].get("price", [])]
        thresholds.append({"count": len(pieces), "summary": steps[-1][1], "bonuses": catalogue.rules_bonuses(lifted), "special_id": SPECIAL_IDS[name]})
    return {
        "id": "set_" + slug(name),
        "name": name,
        "identity": blurb,
        "piece_ids": [artifact_id(piece) for piece in pieces],
        "piece_thresholds": thresholds,
        "special_text": steps[-1][1],
        "special_live": name in LIVE_SPECIALS,
        "runtime_policy": {"set_bonuses_active": True, "source_reward_tables_active": False, "derived_from_equipped_pieces": True},
    }


def reward_tables():
    rows = catalogue.ARTIFACTS
    factions = [catalogue.EM, catalogue.MI, catalogue.SU, catalogue.TH, catalogue.BR, catalogue.VE]

    def names(band=None, faction=None, in_set=None):
        found = []
        for name, _slot, row_band, _bonuses, extra in rows:
            if band is not None and row_band not in band:
                continue
            if faction is not None and extra.get("faction", "") != faction:
                continue
            if in_set is not None and bool(extra.get("set")) != in_set:
                continue
            found.append(name)
        return found

    def one_each(band, index):
        return {faction: [names([band], faction)[index]] for faction in factions}

    neutral_epics = names(["epic"], "")
    choices = {
        "artifact_source_pickup_caches_common": (names(["common"], ""), {}),
        "artifact_source_guarded_sites_standard": (names(["common", "uncommon", "rare"], ""), {}),
        "artifact_source_authored_command_regalia": (None, one_each("uncommon", 0)),
        "artifact_source_authored_expedition_instruments": (None, one_each("uncommon", 1)),
        "artifact_source_shrine_accord_rare": (None, {catalogue.MI: ["Bog-Witch Teeth"], catalogue.SU: ["Tuning Crystal"]}),
        "artifact_source_dwelling_support_rare": (["Seedbank Reliquary"], {}),
        "artifact_source_town_landmark_services": (["Copper Signet", "Banded Hauberk", "Assayer's Scales", "Siege Mattock"], {catalogue.EM: ["Assayer's Scales"], catalogue.BR: ["Siege Mattock"]}),
        "artifact_source_horizon_citadel_commissions": (None, one_each("rare", 0)),
        "artifact_source_battle_salvage_heavy": (["Charge Standard", "Boarding Axe"], {}),
        "artifact_source_guarded_sites_faction_relics": (names(["epic"]), {faction: names(["epic"], faction) + neutral_epics for faction in factions}),
        "artifact_source_sovereign_wild_trophies": (None, one_each("rare", 1)),
        "artifact_source_setbound_regalia_reliquaries": (names(["uncommon", "rare"], "", True), {}),
        "artifact_source_marchland_retinue_heirlooms": (None, one_each("rare", 2)),
        "artifact_source_command_relic_marches": (None, {faction: names(["rare"], faction)[:2] for faction in factions}),
    }
    with io.open(TABLES, encoding="utf-8") as handle:
        tables = json.load(handle)["tables"]
    known = {row[0] for row in rows}
    result = []
    for table in tables:
        listed, by_faction = choices[table["id"]]
        if listed is None:
            listed = [name for faction in factions for name in by_faction.get(faction, [])]
        assert listed and all(name in known for name in listed + [name for group in by_faction.values() for name in group]), table["id"]
        filled = {}
        for key, value in table.items():
            filled[key] = value
            if key == "rarity_bands":
                filled["artifact_ids"] = [artifact_id(name) for name in listed]
                if by_faction:
                    filled["artifact_ids_by_faction"] = {faction_id(faction): [artifact_id(name) for name in group] for faction, group in by_faction.items()}
        result.append(filled)
    return result


def build():
    data = {
        "sets": [set_row(entry) for entry in catalogue.SETS],
        "source_reward_tables": reward_tables(),
        "items": [artifact_row(row) for row in catalogue.ARTIFACTS],
    }
    ids = [item["id"] for item in data["items"]]
    assert len(set(ids)) == len(ids) == 150
    for item in data["items"]:
        assert os.path.exists(os.path.join(ROOT, item["ui"]["icon_path"].replace("res://", ""))), "no icon for " + item["name"]
    return json.dumps(data, ensure_ascii=False, indent=2) + "\n"


def map_manifest():
    """The overworld art manifest with every artifact's pickup drawn as its icon."""
    with io.open(MAP_MANIFEST, encoding="utf-8") as handle:
        manifest = json.load(handle)
    sprites = {}
    # Only the catalogue's artifacts have a pickup sprite: an entry for any other artifact goes.
    for asset in [name for name in manifest["object_assets"] if name.startswith("artifact_field_")]:
        del manifest["object_assets"][asset]
    for row in catalogue.ARTIFACTS:
        asset = "artifact_field_" + slug(row[0])
        sprites[artifact_id(row[0])] = asset
        manifest["object_assets"][asset] = {"path": "res://art/artifacts/runtime/%s.png" % slug(row[0]), "source_model": "artifact_rework_20261111_inventory_icon"}
    manifest["artifact_field_sprites"] = sprites
    return json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    text = build()
    manifest = map_manifest()
    if args.check:
        for path, wanted in ((OUT, text), (MAP_MANIFEST, manifest)):
            with io.open(path, encoding="utf-8") as handle:
                if handle.read() != wanted:
                    sys.exit("%s differs from the catalogue: run tools/build_artifact_content.py" % os.path.relpath(path, ROOT))
        print("content/artifacts.json and the map manifest match the catalogue")
        return
    with io.open(OUT, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    with io.open(MAP_MANIFEST, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(manifest)
    print("wrote content/artifacts.json: 150 artifacts, %d sets, 14 reward lists" % len(catalogue.SETS))


if __name__ == "__main__":
    main()
