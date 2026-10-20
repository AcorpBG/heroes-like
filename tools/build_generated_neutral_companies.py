#!/usr/bin/env python3
"""Build the generated-guard company catalog from the unit roster.

A company is a lead tier and power shares per unit. At adoption,
GeneratedNeutralEncounterRules turns a native guard's budget into battle power
and divides it by these shares, so the shares, not fixed counts, decide how
many of each unit a guard fields.

Sources: content/units.json (faction upgrade lines, neutral units),
content/generated_neutral_encounter_profiles.json and content/army_groups.json
(the 51 authored companies, kept as they are), and the vocabulary below.
Writes content/generated_neutral_companies.json; --check only compares.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "content" / "generated_neutral_companies.json"

# Faction company names: "<lead> <suffix>". Several suffixes per kind so a
# faction's companies do not all share one word; the unit id picks one.
FACTION_WORDS = {
    "faction_embercourt": {
        "levy": ["Charter Levy", "Lock Picket", "Ferry Watch"],
        "seasoned": ["Lockward Company", "Beacon Company", "Crossing Guard"],
        "cadre": ["Beacon Cadre", "Charter Cadre", "Weir Sergeants"],
        "elite": ["Court Honor Guard", "Charter Wardens"],
        "combined": ["Relief Line", "Braced Line", "Counterfire Line"],
        "warband": ["Charter Host", "Beacon Muster"],
        "free": "Embercourt Deserters",
    },
    "faction_mireclaw": {
        "levy": ["Fen Pack", "Reed Raiders", "Bog Skulk"],
        "seasoned": ["Drum-Oath Band", "Chain Crew", "Ferry Raiders"],
        "cadre": ["Bloodsworn", "Drum Cadre", "Chainblood Cadre"],
        "elite": ["Drowned Elect", "Antler Guard"],
        "combined": ["Ambush Party", "Ferry Ambush", "Prey Hunt"],
        "warband": ["Bog Warband", "Drum Host"],
        "free": "Mireclaw Outcasts",
    },
    "faction_sunvault": {
        "levy": ["Relay Picket", "Lens Watch", "Facet Patrol"],
        "seasoned": ["Lens Cohort", "Array Company", "Relay Company"],
        "cadre": ["Zenith Cadre", "Meridian Cadre", "Prism Cadre"],
        "elite": ["Dawnguard", "Corona Guard"],
        "combined": ["Prism Lance", "Lane Battery", "Resonance Line"],
        "warband": ["Array Host", "Sunline Column"],
        "free": "Sunvault Exiles",
    },
    "faction_thornwake": {
        "levy": ["Seed Band", "Pilgrim Band", "Hedge Patrol"],
        "seasoned": ["Graft Pilgrims", "Orchard Company", "Root-Law Wardens"],
        "cadre": ["Heartwood Cadre", "Grafted Cadre", "Bloom Cadre"],
        "elite": ["Orchard Wardens", "Evergraft Guard"],
        "combined": ["Bramble Toll", "Thicket Line", "Rootbind Line"],
        "warband": ["Grove Procession", "Migrant Orchard"],
        "free": "Thornwake Strays",
    },
    "faction_brasshollow": {
        "levy": ["Contract Crew", "Rail Gang", "Shift Crew"],
        "seasoned": ["Foundry Detail", "Bonded Company", "Rivet Gang"],
        "cadre": ["Audit Cadre", "Warrant Cadre", "Gauge Cadre"],
        "elite": ["Warrant Guard", "Furnace Elect"],
        "combined": ["Collection Column", "Pressure Battery", "Siege Detail"],
        "warband": ["Foreclosure Train", "Debt Convoy"],
        "free": "Brasshollow Defaulters",
    },
    "faction_veilmourn": {
        "levy": ["Fog Crew", "Oar Gang", "Wake Picket"],
        "seasoned": ["Wake Watch", "Salvage Crew", "Bell Watch"],
        "cadre": ["Mourning Cadre", "Knell Cadre", "Tide Cadre"],
        "elite": ["Last Rite Guard", "Requiem Guard"],
        "combined": ["Salvage Party", "Boarding Party", "Fog Ambush"],
        "warband": ["Funeral Fleet", "Mourning Procession"],
        "free": "Veilmourn Castaways",
    },
}

# Neutral themes. A unit may belong to several; supports for a neutral lead
# come from its theme mates and its partners in the authored companies.
NEUTRAL_THEMES = {
    "road": {
        "place": ["Waystation", "Toll Road", "Milestone"],
        "units": ["roadwardens", "hearthbow_carriers", "milestone_bucklers", "cartbow_tenders", "switchback_pikes",
                  "cairnshield_porters", "windglass_slingers", "dustjack_blades", "scrapbow_teams", "orchard_halberds"],
    },
    "harbor": {
        "place": ["Harbor", "Skiffyard", "Tide Pier"],
        "units": ["harbor_polearms", "flaremast_crews", "tidepool_cutters", "reefbolt_crews", "saltpan_bucklers",
                  "suncrack_throwers", "tideglass_skyrays", "saltwake_bellwhales", "gloambell_wake_mantas",
                  "lanternskate_throwers", "frostwharf_cutters", "reedbarge_poles"],
    },
    "frost": {
        "place": ["Rimefield", "Snowline", "Icebound"],
        "units": ["frostbeacon_pikes", "snowglass_markers", "icehook_trappers", "whitepike_keepers",
                  "frostwharf_cutters", "lanternskate_throwers", "rimebell_skyrakers"],
    },
    "fen": {
        "place": ["Reedmere", "Bogland", "Fenmire"],
        "units": ["reedbarge_poles", "lanternet_throwers", "fenhound_runners", "mossglass_sentinels", "bogbell_mauls",
                  "peatflare_jarriers", "mireglass_belltoads", "miremoon_crownmaws", "fenmirror_gallowshells"],
    },
    "orchard": {
        "place": ["Orchard", "Hedgerow", "Greenwood"],
        "units": ["orchard_halberds", "millstone_slingers", "greenbranch_cudgels", "sapwhistle_callers",
                  "hedgehook_watch", "thornbow_scouts", "brambleback_knucklebears", "rootcrown_knotstags",
                  "rootvault_barkhulks"],
    },
    "cinder": {
        "place": ["Kilnyard", "Ashfield", "Cinderreach"],
        "units": ["kilnward_mallets", "cinderpot_hurlers", "charcoal_mauls", "emberpack_lobbers", "cinderwake_aurochs",
                  "cindervane_censerwings", "ashcrown_kilnelk", "scarshield_veterans", "ashdart_stalkers"],
    },
    "deep": {
        "place": ["Deepway", "Lantern Tunnel", "Sumpstone"],
        "units": ["tunnel_lanterns", "glimmercap_needlers", "glowcap_bulwarks", "sporelamp_tossers", "sumpstone_guards",
                  "echodart_casts", "basalt_wardens", "tunnelmark_bolters", "deepforge_vaultwyrms",
                  "quenchbell_ironbacks", "gaugecoil_orewyrms"],
    },
    "sky": {
        "place": ["Ridgeline", "High Eyrie", "Windcrest"],
        "units": ["cliffhawk_wardens", "kitehook_runners", "ridgeflare_shots", "galehorn_striders",
                  "sunscale_lanternmoths", "prismwake_raylings", "noonshard_prism_kites", "windglass_slingers"],
    },
}

# Battle setup for the generated encounter definitions: the commander's title,
# the battle terrain and the field's character, by faction or neutral theme.
BATTLE_STYLE = {
    "faction_embercourt": {"titles": ["Charter Captain", "Lock Sergeant", "Beacon Marshal"], "terrain": "grass",
                           "tags": ["fortified_line", "chokepoint"], "traits": ["linekeeper"], "resource": "embergrain"},
    "faction_mireclaw": {"titles": ["Drum-Chief", "Ferry Reaver", "Fen Matriarch"], "terrain": "mire",
                         "tags": ["bog_channels", "ambush_cover"], "traits": ["bogwise", "ambusher"], "resource": "peatwax"},
    "faction_sunvault": {"titles": ["Relay Marshal", "Lens Prefect", "Array Warden"], "terrain": "sand",
                         "tags": ["elevated_fire", "battery_nest"], "traits": ["artillerist"], "resource": "aetherglass"},
    "faction_thornwake": {"titles": ["Grove Elder", "Graft Warden", "Root Steward"], "terrain": "forest",
                          "tags": ["ambush_cover", "chokepoint"], "traits": ["linekeeper", "bogwise"], "resource": "verdant_grafts"},
    "faction_brasshollow": {"titles": ["Foreman-Bailiff", "Contract Auditor", "Pressure Marshal"], "terrain": "rough",
                            "tags": ["fortress_lane", "wall_pressure"], "traits": ["artillerist", "vanguard"], "resource": "brass_scrip"},
    "faction_veilmourn": {"titles": ["Wake Bosun", "Fog Pilot", "Knell Captain"], "terrain": "coast",
                          "tags": ["fog_bank", "ambush_cover"], "traits": ["ambusher"], "resource": "memory_salt"},
    "road": {"titles": ["Toll Captain", "Waymaster"], "terrain": "road", "tags": ["open_lane", "chokepoint"],
             "traits": ["linekeeper"], "resource": "ore"},
    "harbor": {"titles": ["Harbormaster", "Pier Boss"], "terrain": "coast", "tags": ["fog_bank", "open_lane"],
               "traits": ["vanguard"], "resource": "memory_salt"},
    "frost": {"titles": ["Rime Warden", "Snowline Captain"], "terrain": "snow", "tags": ["open_lane", "elevated_fire"],
              "traits": ["linekeeper"], "resource": "memory_salt"},
    "fen": {"titles": ["Fen Reeve", "Bog Warden"], "terrain": "mire", "tags": ["bog_channels", "fog_bank"],
            "traits": ["bogwise"], "resource": "peatwax"},
    "orchard": {"titles": ["Orchard Steward", "Hedge Warden"], "terrain": "forest", "tags": ["ambush_cover", "chokepoint"],
                "traits": ["linekeeper"], "resource": "verdant_grafts"},
    "cinder": {"titles": ["Kiln Boss", "Ash Warden"], "terrain": "lava", "tags": ["battery_nest", "wall_pressure"],
               "traits": ["vanguard"], "resource": "embergrain"},
    "deep": {"titles": ["Tunnel Marshal", "Sump Warden"], "terrain": "underground", "tags": ["fortress_lane", "chokepoint"],
             "traits": ["linekeeper"], "resource": "ore"},
    "sky": {"titles": ["Eyrie Warden", "Ridge Captain"], "terrain": "rough", "tags": ["elevated_fire", "open_lane"],
            "traits": ["packhunter"], "resource": "aetherglass"},
}
# Medians of the authored generated guards by tier: commander command, round
# limit and listed rewards (paid as a share scaled by the strength beaten).
TIER_BATTLE = {
    1: {"command": (1, 1), "rounds": 13, "gold": 120, "experience": 140},
    2: {"command": (1, 1), "rounds": 13, "gold": 120, "experience": 140},
    3: {"command": (1, 2), "rounds": 14, "gold": 120, "experience": 150},
    4: {"command": (2, 2), "rounds": 14, "gold": 630, "experience": 460},
    5: {"command": (2, 3), "rounds": 14, "gold": 680, "experience": 500},
    6: {"command": (3, 2), "rounds": 15, "gold": 760, "experience": 565},
    7: {"command": (3, 3), "rounds": 16, "gold": 1020, "experience": 720},
}
KIND_TRAIT = {"warband": "vanguard", "elite": "vanguard", "cadre": "linekeeper", "pack": "packhunter",
              "host": "vanguard", "free_company": "ambusher"}

NEUTRAL_GROUP_WORDS = {
    "small_melee": ["Band", "Patrol", "Muster", "Company"],
    "small_ranged": ["Skirmishers", "Volley", "Picket"],
    "large_melee": ["Lair", "Herd", "Den"],
    "large_ranged": ["Roost", "Drift", "Swarm"],
}

# Power shares per company kind. The first slot leads (its unit's tier is the
# company tier); the rest are its veterans, recruits, support and escorts.
SHARES = {
    "levy": [1.0],
    "seasoned": [0.75, 0.25],      # recruits with a few upgraded veterans
    "cadre": [0.6, 0.4],           # upgraded core filled out with recruits
    "elite": [1.0],
    "combined": [0.45, 0.15, 0.40],
    "warband": [0.35, 0.2, 0.25, 0.2],
    "single_combined": [0.6, 0.4],
    "single_warband": [0.55, 0.25, 0.2],
    "pack": [1.0],
    "pair": [0.7, 0.3],
    "beast_pair": [0.6, 0.4],
    "host": [0.55, 0.25, 0.2],
    "free_company": [0.65, 0.35],
}


def power(unit):
    """Per-creature fighting value; mirrors AiHeroRules.army_power without a commander."""
    damage = (float(unit.get("min_damage", 1)) + float(unit.get("max_damage", 1))) * 0.5
    # AiHeroRules' strength terms (content/ai_hero_weights.json, "army_power").
    value = 0.7 * max(1.0, float(unit.get("hp", 1))) ** 0.3 * max(0.5, damage) ** 0.6
    value *= math.exp(0.075 * int(unit.get("defense", 0)) + 0.06 * int(unit.get("speed", 0)) + 0.045 * int(unit.get("initiative", 0)))
    return value * (1.65 if unit.get("ranged") else 1.0)


def pick(options, key):
    digest = hashlib.sha256(key.encode("utf-8")).hexdigest()
    return options[int(digest[:8], 16) % len(options)]


def short(unit_id):
    return unit_id.removeprefix("unit_").removeprefix("neutral_")


def slots(unit_ids, kind):
    shares = SHARES[kind]
    assert len(unit_ids) == len(shares), (unit_ids, kind)
    assert len(set(unit_ids)) == len(unit_ids), unit_ids
    return [{"unit_id": unit_id, "share": share} for unit_id, share in zip(unit_ids, shares)]


def opposite_role_support(units, faction_id, lead, exclude):
    """A same-faction unit of the other role, at the lead's tier or up to two below."""
    want_ranged = not bool(lead.get("ranged"))
    for drop in (0, 1, 2):
        tier = int(lead["tier"]) - drop
        pool = sorted(u["id"] for u in units.values()
                      if u.get("faction_id") == faction_id and not u.get("upgrade_from")
                      and int(u["tier"]) == tier and bool(u.get("ranged")) == want_ranged and u["id"] not in exclude)
        if pool:
            return pick(pool, "support:" + lead["id"])
    return ""


def lower_tier_escorts(units, faction_id, lead, exclude):
    """Two lower-tier faction lines, one melee and one ranged when the roster allows."""
    pool = sorted((u for u in units.values()
                   if u.get("faction_id") == faction_id and not u.get("upgrade_from")
                   and 1 <= int(lead["tier"]) - int(u["tier"]) <= 3 and u["id"] not in exclude),
                  key=lambda u: u["id"])
    melee = [u["id"] for u in pool if not u.get("ranged")]
    ranged = [u["id"] for u in pool if u.get("ranged")]
    escorts = []
    if melee:
        escorts.append(pick(melee, "escort_melee:" + lead["id"]))
    if ranged:
        escorts.append(pick(ranged, "escort_ranged:" + lead["id"]))
    rest = [u["id"] for u in pool if u["id"] not in escorts]
    while len(escorts) < 2 and rest:
        escorts.append(rest.pop(0))
    return escorts if len(escorts) == 2 else []


def faction_companies(units):
    companies = []
    for faction_id, words in FACTION_WORDS.items():
        bases = sorted((u for u in units.values() if u.get("faction_id") == faction_id and not u.get("upgrade_from")),
                       key=lambda u: (int(u["tier"]), u["id"]))
        for base in bases:
            tier = int(base["tier"])
            upgrade = units.get(base.get("upgrade_to", ""), {})
            family = "line:" + base["id"]
            stem = "company_%s" % short(base["id"])

            def add(kind, lead_name, word_kind, unit_ids, share_kind=None):
                companies.append({
                    "id": "%s_%s" % (stem, kind),
                    "name": "%s %s" % (lead_name, pick(words[word_kind], "%s:%s" % (word_kind, base["id"]))),
                    "tier": tier,
                    "pool": "faction",
                    "faction_id": faction_id,
                    "family": family,
                    "kind": kind,
                    "style": faction_id,
                    "slots": slots(unit_ids, share_kind or kind),
                })

            add("levy", base["name"], "levy", [base["id"]])
            if upgrade:
                add("seasoned", base["name"], "seasoned", [base["id"], upgrade["id"]])
                add("cadre", upgrade["name"], "cadre", [upgrade["id"], base["id"]])
                add("elite", upgrade["name"], "elite", [upgrade["id"]])
                support = opposite_role_support(units, faction_id, base, {base["id"]})
                if support:
                    add("combined", base["name"], "combined", [base["id"], upgrade["id"], support])
                escorts = lower_tier_escorts(units, faction_id, base, {base["id"]}) if tier >= 3 else []
                if escorts:
                    add("warband", base["name"], "warband", [base["id"], upgrade["id"]] + escorts)
            else:
                support = opposite_role_support(units, faction_id, base, {base["id"]})
                if support:
                    add("combined", base["name"], "combined", [base["id"], support], "single_combined")
                escorts = lower_tier_escorts(units, faction_id, base, {base["id"]}) if tier >= 3 else []
                if escorts:
                    add("warband", base["name"], "warband", [base["id"]] + escorts, "single_warband")
    return companies


def neutral_companies(units, authored_partners, actor_assets):
    companies = []
    neutrals = sorted((u for u in units.values() if not u.get("faction_id")), key=lambda u: (int(u["tier"]), u["id"]))
    themes_of = {}
    for theme, row in NEUTRAL_THEMES.items():
        for name in row["units"]:
            themes_of.setdefault("unit_neutral_" + name, []).append(theme)
    for lead in neutrals:
        assert lead["id"] in themes_of, "neutral unit without a theme: " + lead["id"]
    for lead in neutrals:
        tier = int(lead["tier"])
        large = tier >= 4
        word_kind = ("large_" if large else "small_") + ("ranged" if lead.get("ranged") else "melee")
        family = "neutral:" + lead["id"]
        stem = "company_%s" % short(lead["id"])
        asset = actor_assets.get(lead["id"], "")
        theme = themes_of[lead["id"]][0]
        place = pick(NEUTRAL_THEMES[theme]["place"], "place:" + lead["id"])

        def add(kind, name, unit_ids, share_kind=None):
            row = {
                "id": "%s_%s" % (stem, kind),
                "name": name,
                "tier": tier,
                "pool": "neutral",
                "faction_id": "",
                "family": family,
                "kind": kind,
                "style": theme,
                "slots": slots(unit_ids, share_kind or kind),
            }
            if asset:
                row["asset_id"] = asset
            companies.append(row)

        add("pack", "%s %s" % (lead["name"], pick(NEUTRAL_GROUP_WORDS[word_kind], "group:" + lead["id"])), [lead["id"]])
        mates = set(authored_partners.get(lead["id"], set()))
        for t in themes_of[lead["id"]]:
            mates.update("unit_neutral_" + name for name in NEUTRAL_THEMES[t]["units"])
        mates.discard(lead["id"])
        # Supports never outrank the lead.
        supports = sorted(m for m in mates if int(units[m]["tier"]) <= tier)
        # Prefer the other role, then the authored partners, for the pair.
        def support_order(unit_id):
            other_role = bool(units[unit_id].get("ranged")) != bool(lead.get("ranged"))
            authored = unit_id in authored_partners.get(lead["id"], set())
            digest = hashlib.sha256(("order:%s:%s" % (lead["id"], unit_id)).encode()).hexdigest()
            return (not other_role, not authored, digest)
        supports.sort(key=support_order)
        for index, support in enumerate(supports[:2]):
            add("pair_%d" % (index + 1), "%s and %s" % (lead["name"], units[support]["name"]),
                [lead["id"], support], "beast_pair" if large else "pair")
        if tier >= 3 and len(supports) >= 3:
            host = [lead["id"], supports[0], supports[2]]
            add("host", "%s %s Host" % (place, lead["name"]), host)
    return companies


def neutral_theme(unit_id):
    for theme, row in NEUTRAL_THEMES.items():
        if unit_id.removeprefix("unit_neutral_") in row["units"]:
            return theme
    raise AssertionError("neutral unit without a theme: " + unit_id)


def free_companies(units):
    """Neutral fighters hired out with faction deserters of the other role."""
    companies = []
    for lead in sorted((u for u in units.values() if not u.get("faction_id") and int(u["tier"]) <= 3),
                       key=lambda u: u["id"]):
        want_ranged = not bool(lead.get("ranged"))
        pool = sorted(u["id"] for u in units.values()
                      if u.get("faction_id") and not u.get("upgrade_from")
                      and int(u["tier"]) <= int(lead["tier"]) and bool(u.get("ranged")) == want_ranged)
        if not pool:
            continue
        support = units[pick(pool, "free:" + lead["id"])]
        companies.append({
            "id": "company_%s_free_company" % short(lead["id"]),
            "name": "%s with %s" % (lead["name"], FACTION_WORDS[support["faction_id"]]["free"]),
            "tier": int(lead["tier"]),
            "pool": "free",
            "faction_id": "",
            "family": "neutral:" + lead["id"],
            "kind": "free_company",
            "style": neutral_theme(lead["id"]),
            "slots": slots([lead["id"], support["id"]], "free_company"),
        })
    return companies


def encounter_definition(company, units):
    """The battle setup and listed rewards a generated company fights with."""
    style = BATTLE_STYLE[company["style"]]
    tier = int(company["tier"])
    tier_battle = TIER_BATTLE[tier]
    ranged_share = sum(s["share"] for s in company["slots"] if units[s["unit_id"]].get("ranged"))
    tags = list(style["tags"])
    if company["kind"] in ("warband", "host"):
        tags[-1] = "reserve_wave"
    elif ranged_share >= 0.5 and "elevated_fire" not in tags:
        tags[-1] = "elevated_fire"
    traits = list(style["traits"][:1])
    for trait in (KIND_TRAIT.get(company["kind"].split("_pair")[0], ""), "artillerist" if ranged_share >= 0.5 else ""):
        if trait and trait not in traits:
            traits.append(trait)
    attack, defense = tier_battle["command"]
    rewards = {"gold": tier_battle["gold"], "experience": tier_battle["experience"]}
    if tier >= 4:
        rewards[style["resource"]] = 1 if tier < 6 else 2
    return {
        "id": company["encounter_id"],
        "name": company["name"],
        "enemy_group_id": "",
        "affiliation": "neutral",
        "terrain": style["terrain"],
        "battlefield_tags": tags,
        "max_rounds": tier_battle["rounds"],
        "enemy_commander": {
            "name": pick(style["titles"], "title:" + company["id"]),
            "command": {"attack": attack, "defense": defense, "power": 0, "knowledge": 0},
            "starting_spell_ids": [],
            "battle_traits": traits[:2],
        },
        "rewards": rewards,
        "content_status": "generated_company_v1",
    }


def authored_companies(units, catalog, armies, encounters):
    """The 51 authored companies keep their names, art and proportions."""
    companies = []
    for profile in catalog["profiles"]:
        army = armies[profile["army_group_id"]]
        weights = [(stack["unit_id"], int(stack["count"]) * power(units[stack["unit_id"]])) for stack in army["stacks"]]
        total = sum(weight for _, weight in weights)
        lead = weights[0][0]
        companies.append({
            "id": "company_" + profile["encounter_id"].removeprefix("encounter_"),
            "name": encounters[profile["encounter_id"]]["name"],
            "tier": int(profile["tier"]),
            "pool": "neutral",
            "faction_id": "",
            "family": "neutral:" + lead,
            "kind": "authored",
            "encounter_id": profile["encounter_id"],
            "asset_id": profile["asset_id"],
            "slots": [{"unit_id": unit_id, "share": round(weight / total, 4)} for unit_id, weight in weights],
        })
    return companies


def build():
    load = lambda path: json.loads((ROOT / path).read_text(encoding="utf-8"))
    units = {u["id"]: u for u in load("content/units.json")["items"]}
    catalog = load("content/generated_neutral_encounter_profiles.json")
    armies = {a["id"]: a for a in load("content/army_groups.json")["items"]}
    encounters = {e["id"]: e for e in load("content/encounters.json")["items"]}
    authored_partners = {}
    actor_assets = {}
    for profile in catalog["profiles"]:
        stack_ids = [stack["unit_id"] for stack in armies[profile["army_group_id"]]["stacks"]]
        actor_assets.setdefault(stack_ids[0], profile["asset_id"])
        for a in stack_ids:
            authored_partners.setdefault(a, set()).update(b for b in stack_ids if b != a)
    companies = (authored_companies(units, catalog, armies, encounters)
                 + neutral_companies(units, authored_partners, actor_assets)
                 + faction_companies(units)
                 + free_companies(units))
    definitions = []
    for company in companies:
        if company["kind"] != "authored":
            company["encounter_id"] = "encounter_" + company["id"]
            definitions.append(encounter_definition(company, units))
    ids = [c["id"] for c in companies]
    assert len(ids) == len(set(ids)), "duplicate company ids"
    names = [c["name"] for c in companies]
    assert len(names) == len(set(names)), sorted(n for n in names if names.count(n) > 1)
    for company in companies:
        lead = units[company["slots"][0]["unit_id"]]
        assert int(lead["tier"]) == company["tier"], company["id"]
        assert abs(sum(s["share"] for s in company["slots"]) - 1.0) < 0.002, company["id"]
        assert all(s["unit_id"] in units for s in company["slots"]), company["id"]
        if company["kind"] != "authored":
            assert all(int(units[s["unit_id"]]["tier"]) <= company["tier"] for s in company["slots"]), company["id"]
    return {
        "schema_id": "aurelion_generated_neutral_companies_v1",
        "schema_version": 1,
        "generator": "tools/build_generated_neutral_companies.py",
        "policy": "Each native guard's budget (native quantity x native value) becomes battle power at "
                  "power_per_native_value; the company's slot shares divide that power, and each slot's headcount is "
                  "its power divided by its unit's AiHeroRules.army_power.",
        # Our battle power (AiHeroRules.army_power) per point of native guard value.
        # Three anchors agree on about 0.045 (same fighting value as the native
        # creatures, same gold cost, same multiple of a starting army); owner
        # playtests (2026-10-09, Large Veilmourn days 18-25: beaten guards at a
        # median 0.2x the hero's army) asked for stronger guards, so a third more.
        "power_per_native_value": 0.06,
        "companies": companies,
        # Read by ContentService.get_encounter for encounter_company_* ids.
        "encounters": definitions,
    }


def serialize(catalog):
    """One company or definition per line keeps the file small and its diffs readable."""
    lines = ["{"]
    keys = list(catalog)
    for index, key in enumerate(keys):
        value = catalog[key]
        tail = "," if index < len(keys) - 1 else ""
        if isinstance(value, list):
            lines.append(" %s: [" % json.dumps(key))
            for row_index, row in enumerate(value):
                comma = "," if row_index < len(value) - 1 else ""
                lines.append("  " + json.dumps(row, ensure_ascii=False, separators=(",", ":")) + comma)
            lines.append(" ]" + tail)
        else:
            lines.append(" %s: %s%s" % (json.dumps(key), json.dumps(value, ensure_ascii=False), tail))
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail if the committed catalog differs from a fresh build")
    args = parser.parse_args()
    text = serialize(build())
    if args.check:
        current = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else ""
        if current != text:
            raise SystemExit("content/generated_neutral_companies.json is stale; run tools/build_generated_neutral_companies.py")
        print("generated_neutral_companies.json is current")
        return
    OUTPUT.write_text(text, encoding="utf-8", newline="\n")
    catalog = json.loads(text)
    from collections import Counter
    print(json.dumps({
        "companies": len(catalog["companies"]),
        "by_pool": Counter(c["pool"] for c in catalog["companies"]),
        "by_tier": dict(sorted(Counter(c["tier"] for c in catalog["companies"]).items())),
        "by_kind": Counter(c["kind"].split("_")[0] for c in catalog["companies"]),
        "families": len({c["family"] for c in catalog["companies"]}),
    }))


if __name__ == "__main__":
    main()
