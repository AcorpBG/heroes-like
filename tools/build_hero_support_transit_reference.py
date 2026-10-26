"""Build the owner's illustrated, offline support/transit comparison.

This is reference tooling, not a second runtime resolver. Mapping identities are
read from GeneratedRewardRules; original-game descriptions are explicitly curated.
No game content, native generator data, assets or saved games are modified.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import io
import json
import re
import subprocess
from collections import Counter
from datetime import date
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PORT = ROOT / "src/gdextension/rules/core/port"
REF = ROOT / "docs/reference/hero-support-transit-h3.json"
OUTPUT = ROOT / "docs/reference/hero-support-transit.html"
FAMILIES = {
    "visit_building", "scouting_structure", "transit_object", "faction_landmark",
    "faction_outpost", "frontier_shrine", "shrine", "sign_waypoint", "support_producer",
}
LABELS = {
    "visit_building": "Hero visits", "scouting_structure": "Scouting",
    "transit_object": "Travel & gates", "faction_landmark": "Faction landmarks",
    "faction_outpost": "Outposts", "frontier_shrine": "Frontier shrines",
    "shrine": "Shrines", "sign_waypoint": "Information", "support_producer": "Weekly supplies",
}
CADENCES = {
    "once_per_hero": "Once per hero", "weekly_per_hero": "Once per hero per week",
    "daily_per_hero": "Once per hero per day", "once_per_side": "Once per player",
    "weekly_site": "One use per site per week", "always": "Repeatable",
}


def read(path: Path | str):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args]).decode("utf-8").strip()


def array_sites(source: str, name: str) -> list[str]:
    match = re.search(r"\b" + re.escape(name) + r"\[\]\s*=\s*\{(.*?)\};", source, re.S)
    if not match:
        raise ValueError("Missing live mapping table: " + name)
    return list(dict.fromkeys(re.findall(r"key::(site_\w+)", match.group(1))))


def mapping_tables(source: str):
    visits = dict(
        (int(n), s) for n, s in re.findall(
            r"\{(\d+),\s*key::(site_\w+)\}", re.search(
                r"kVisitSites\[\]\s*=\s*\{(.*?)\};", source, re.S
            ).group(1)
        )
    )
    shrines = dict(
        (int(n), s) for n, s, _ in re.findall(
            r"\{(\d+),\s*key::(site_\w+),\s*(\d+)\}", re.search(
                r"kSpellShrines\[\]\s*=\s*\{(.*?)\};", source, re.S
            ).group(1)
        )
    )
    pools = {name: array_sites(source, name) for name in [
        "kScoutingSites", "kSignSites", "kLandmarkSites", "kGrowthSites",
        "kGateSites", "kWaterWheelSites", "kWindmillSites",
    ]}
    fallback = sorted(set(visits.values()) | set(shrines.values()))
    return visits, shrines, pools, fallback


def resources(value: dict) -> str:
    return ", ".join(f"{int(n):,} {k.replace('_', ' ')}" for k, n in value.items() if n) or "free"


def effect_lines(effect: dict) -> list[str]:
    result = []
    stats = effect.get("stats", {})
    if stats:
        result.append("Permanent " + ", ".join(f"+{n} {k}" for k, n in stats.items()) + ".")
    if effect.get("experience"):
        result.append(f"Gain {effect['experience']:,} experience.")
    if effect.get("levels"):
        result.append(f"Advance {effect['levels']} hero level.")
    if effect.get("movement"):
        result.append(f"+{effect['movement']} movement now (our movement units).")
    if effect.get("week_movement"):
        result.append(f"+{effect['week_movement']} daily movement allowance until week end; "
                      "also restore that much movement now, up to the new maximum.")
    if effect.get("mana") == "refill":
        result.append("Refill mana to the hero's current maximum, including any active weekly bonus.")
    if effect.get("mana") == "week_double":
        result.append("Double maximum mana until week end and refill to that maximum; "
                      "repeated springs do not keep multiplying the bonus.")
    if effect.get("reveal") == "level":
        result.append("Reveal the current map level for the player.")
    if effect.get("reveal_radius"):
        result.append(f"Reveal a local radius of {effect['reveal_radius']} tiles.")
    if effect.get("spell_tier"):
        result.append(f"Teach a compatible tier-{effect['spell_tier']} spell from our spell content.")
    for key, text in [("battle_boosts", "Next-battle support"),
                      ("day7_battle_boosts", "Additional support on day seven")]:
        if effect.get(key):
            result.append(text + ": " + ", ".join(
                f"+{n} {k}" for k, n in effect[key].items()) + ".")
    if effect.get("resources"):
        result.append("Receive " + resources(effect["resources"]) + ".")
    if effect.get("build_boat"):
        result.append("Launch a boat at a valid adjacent water tile; the dock must be usable.")
    if effect.get("whirlpool"):
        result.append("A sailing hero transfers to another usable whirlpool. Lose half the count "
                      "of the lowest-total-HP stack, keeping at least one creature overall.")
    return result


def describe_site(site: dict) -> tuple[list[str], str, dict]:
    """Use live fields, not marketing/contract summaries, for the visible facts."""
    family = site.get("family", "")
    details = []
    visit = site.get("visit", {})
    cadence = CADENCES.get(visit.get("cadence"), "Persistent control" if site.get("persistent_control") else "")
    response = site.get("response_profile", {})
    if visit:
        details += effect_lines(visit.get("effects", {}))
        if visit.get("cost") and not visit.get("choices"):
            details.append("Visit cost: " + resources(visit["cost"]) + ".")
        if visit.get("required_level"):
            details.append(f"Requires hero level {visit['required_level']}.")
        for choice in visit.get("choices", []):
            price = choice.get("cost", visit.get("cost", {}))
            effects = " ".join(effect_lines(choice.get("effects", {})))
            details.append("Choice: " + effects + (" Cost: " + resources(price) + "." if price else ""))
    elif family == "scouting_structure":
        radius = site.get("vision_radius", 0)
        details.append(f"Held vision: radius {radius} on the site's level, while controlled.")
        support = site.get("town_support")
        if support:
            details.append("Linked-town support (explicit override): " + ", ".join(
                f"+{value} {key.replace('_bonus', '').replace('_', ' ')}"
                for key, value in support.items() if value and key != "disruption_pressure") + ".")
        else:
            details.append(f"Linked-town support: +{max(1, radius)} readiness and +1 pressure rating.")
    elif family == "faction_landmark":
        details.append(f"Held vision: radius {site.get('vision_radius', 0)} on the site's level.")
        details.append("Any faction may claim it; its faction identity is a theme, not an eligibility restriction.")
    elif family == "faction_outpost":
        details.append(f"Held vision: radius {site.get('vision_radius', 0)}.")
        support = site.get("town_support") or {
            "readiness_bonus": max(2, 2 * site.get("vision_radius", 0)),
            "pressure_bonus": site.get("pressure_bonus", 0), "recovery_relief": 1,
        }
        details.append("Linked-town support: " + ", ".join(
            f"+{value} {key.replace('_bonus', '').replace('_', ' ')}"
            for key, value in support.items() if value and key != "disruption_pressure") + ".")
    elif family in {"frontier_shrine", "shrine"}:
        details.append("A persistent shrine; configured claim rewards/spells are listed below.")
        if family == "frontier_shrine":
            details.append("Held linked-town support: +2 quality, +1 pressure, +6% growth and +1 recovery relief.")
    elif family == "support_producer":
        cadence = f"{site.get('visit_cooldown_days', 7)} days after the previous collection"
        details.append("Collect " + resources(site.get("claim_rewards", site.get("rewards", {}))) + ".")
    elif family == "sign_waypoint":
        cadence = "Read again"
        details.append("Read the themed route-hint/sign text. No troop or resource reward.")
    elif family == "transit_object":
        profile = site.get("transit_profile", {})
        mode = profile.get("mode", "route")
        if site["id"] in {"site_wayring", "site_waygate", "site_wayfall"}:
            details.append(site.get("public_text", "Native portal network."))
            details.append("Native destination/channel rules take precedence; not a capturable income or dispatch site.")
            cadence = "Native travel"
        elif site["id"] == "site_basalt_undergate":
            details.append("On generated maps: cross to the exact native paired gate on the other level.")
            details.append("Native visits bypass claiming, repair charges and generic local-route rewards.")
            cadence = "Native paired travel"
        elif site.get("opens_route_on_claim"):
            details.append("Claim to open the blocked route body.")
            details.append("Opening cost: " + resources(site.get("service_cost", {})) + ".")
            details.append("While controlled and linked to a town: +1 readiness and +1 recovery relief.")
        elif site.get("sign_contract"):
            details.append("Route information marker. Its transit profile is metadata-only; do not read it as a working teleport.")
        else:
            details.append("Content-defined route mode: " + mode.replace("_", " ") + ".")
            if profile.get("paired_link_required"):
                details.append("Needs a configured linked endpoint; a matching painted structure alone does not establish a native connection.")
            if profile.get("requires_repair"):
                details.append("Requires an active repair/response before the local route can be used.")
            if profile.get("one_way"):
                details.append("Configured as one-way.")
            if profile.get("metadata_only"):
                details.append("Transit profile is metadata-only.")
        if site.get("vision_radius") and cadence != "Native paired travel":
            details.append(f"Configured held vision: radius {site['vision_radius']}.")
    if not visit and family not in {"support_producer"}:
        reward = site.get("claim_rewards", site.get("rewards", {}))
        if reward:
            details.append("Claim reward: " + resources(reward) + ".")
        spells = site.get("learn_spell_ids", [])
        if site.get("learn_spell_id"):
            spells = spells + [site["learn_spell_id"]]
        if spells:
            details.append("Claim spell: " + ", ".join(spells) + ".")
    if response.get("watch_days", 0) > 0:
        details.append(f"Optional {response['action_label']}: {resources(response.get('resource_cost', {}))}; "
                       f"{response.get('movement_cost', 0)} hero movement; {response['watch_days']} days.")
        bonuses = []
        for key, label in [("quality_bonus", "quality"), ("readiness_bonus", "readiness"),
                           ("pressure_bonus", "pressure"), ("recovery_relief", "recovery relief")]:
            if response.get(key):
                bonuses.append(f"+{response[key]} {label}")
        if bonuses:
            details.append("Temporary linked-town ratings: " + ", ".join(bonuses) + ".")
        details.append("Uses the shared reserve-dispatch action: unrecruited town stock can become "
                       "delivered army/garrison troops without their normal hiring cost. "
                       "Follow-up shipments can queue while active; eligibility and stock limit dispatch.")
        if response.get("pressure_guard_bonus"):
            details.append("Pressure-guard value is calculated/displayed; no applying gameplay consumer was found.")
    return details or ["No direct visit effect configured."], cadence, response


def make_art(site_id: str, objects: dict, world: dict, object_sprites: dict) -> dict:
    site_skin = world.get("resource_site_sprites", {}).get(site_id)
    skin = site_skin if isinstance(site_skin, dict) else {"asset_id": site_skin}
    object_row = objects.get(site_id, {})
    mapping = object_sprites.get(object_row.get("id"), {})
    if isinstance(mapping, str):
        mapping = {"asset_id": mapping}
    candidates = [skin.get("unclaimed_asset_id"), mapping.get("asset_id"), skin.get("asset_id")]
    for asset_id in candidates:
        row = world["object_assets"].get(asset_id, {})
        path = row.get("path", "").removeprefix("res://")
        if not path or not (ROOT / path).is_file():
            continue
        with Image.open(ROOT / path) as source:
            image = source.convert("RGBA")
        region = row.get("atlas_region") or row.get("region")
        if isinstance(region, dict):
            region = [region[k] for k in ("x", "y", "width", "height")]
        if region:
            x, y, width, height = map(int, region)
            image = image.crop((x, y, x + width, y + height))
        bounds = image.getbbox()
        if bounds:
            image = image.crop(bounds)
        image.thumbnail((200, 170), Image.Resampling.LANCZOS)
        stream = io.BytesIO()
        image.save(stream, "WEBP", quality=87, method=5)
        return {"asset": asset_id, "path": path, "region": region,
                "image": "data:image/webp;base64," + base64.b64encode(stream.getvalue()).decode("ascii"),
                "width": image.width, "height": image.height}
    raise ValueError("No real game art resolved for " + site_id)


def build() -> dict:
    reference = read(REF)
    revision = git("rev-parse", "HEAD")
    source = (PORT / "generated_reward_rules.cpp").read_text(encoding="utf-8")
    visits, shrines, pools, fallback = mapping_tables(source)
    eligibility = read("content/random_map_object_eligibility.json")["source_type_pools"]
    original = []
    by_site: dict[str, list[dict]] = {}
    for row in reference["original_types"]:
        row = dict(row)
        n = row["id"]
        mapped, kind = [], "No support-site mapping"
        if n in visits:
            mapped, kind = [visits[n]], "Direct"
        elif n in shrines:
            mapped, kind = [shrines[n]], "Direct"
        elif n in {42, 58, 60}:
            mapped, kind = pools["kScoutingSites"], "Scouting pool"
        elif n in {59, 91}:
            mapped, kind = pools["kSignSites"], "Sign pool"
        elif n == 57:
            mapped, kind = pools["kLandmarkSites"], "Landmark pool"
        elif n in {81, 104, 113}:
            mapped, kind = pools["kGrowthSites"], "Learning pool"
        elif n in {9, 33, 212, 215, 219}:
            mapped, kind = pools["kGateSites"], "Terrain-selected gate pool"
        elif n in {43, 44, 45, 103}:
            mapped = [{43: "site_waygate", 44: "site_wayfall", 45: "site_wayring",
                       103: "site_basalt_undergate"}[n]]
            kind = "Native route"
        elif n in {87, 111}:
            mapped, kind = [{87: "site_shipyard", 111: "site_whirlpool"}[n]], "Direct"
        elif n == 109:
            mapped, kind = pools["kWaterWheelSites"], "Producer pool"
        elif n == 112:
            mapped, kind = pools["kWindmillSites"], "Producer pool"
        elif n == 55:
            mapped, kind = ["site_orchard_levy_post"], "Direct"
        elif eligibility.get(str(n)) == "interactable_site" and n not in {8, 10}:
            mapped, kind = fallback, "Generic fallback"
        row["sites"], row["mapping"] = mapped, kind
        row["reference_url"] = (reference["manual_url"] if row["source"] == "manual" else
            reference["reference_repository"] + "/blob/" + reference["reference_commit"] + "/" + row["source"])
        if row["status"] == "Fallback" and kind != "Generic fallback":
            raise ValueError("Fallback source changed: " + str(n))
        original.append(row)
        for sid in mapped:
            by_site.setdefault(sid, []).append({"id": n, "name": row["name"], "mapping": kind})
    objects = {x.get("resource_site_id"): x for x in read("content/map_objects.json")["items"] if x.get("resource_site_id")}
    world = read("art/overworld/manifest.json")
    sprites = read("art/overworld/map_object_sprites.json")["object_sprite_mappings"]
    sites = []
    text = (ROOT / "content/resource_sites.json").read_text(encoding="utf-8")
    for site in json.loads(text)["items"]:
        batch = site.get("content_batch_id", "")
        if site.get("family") not in FAMILIES or (batch and not batch.startswith("overworld-object-")):
            continue
        sid = site["id"]
        details, cadence, response = describe_site(site)
        line = text[:text.index('"id": "' + sid + '"')].count("\n") + 1
        site_originals = by_site.get(sid, [])
        native = sid in {"site_wayring", "site_waygate", "site_wayfall", "site_basalt_undergate"}
        sites.append({
            "id": sid, "name": site["name"], "family": site["family"],
            "category": LABELS[site["family"]], "details": details, "cadence": cadence,
            "response": response, "raw": site, "originals": site_originals,
            "mapped": bool(site_originals), "native": native,
            "art": make_art(sid, objects, world, sprites),
            "source_path": "content/resource_sites.json", "source_line": line,
        })
    for site in sites:
        sid = site["id"]
        if sid == visits.get(30):
            site["details"].append("Generated Fountain of Fortune (#30) overrides the base +1 "
                                   "with a placement-fixed +1 to +3 momentum.")
        if sid == visits.get(102):
            site["details"].append("Generated Tree of Knowledge (#102) has a placement-fixed price: "
                                   "free, 2,000 gold, or 10 of one selected rare resource "
                                   "(one third each).")
        if sid == "site_wind_press":
            site["details"].append("Generated Windmill (#112) overrides this base reward with "
                                   "3–6 of one selected rare resource per collection.")
    known = {s["id"] for s in sites}
    assert set(by_site).issubset(known), "A current mapping escaped the declared catalogue scope"
    assert len(known) == len(sites) and all(s["art"]["image"] for s in sites)
    for s in sites:
        s["source_url"] = "https://github.com/AcorpBG/heroes-like/blob/" + revision + "/" + s["source_path"] + "#L" + str(s["source_line"])
    inputs = ["content/resource_sites.json", "content/map_objects.json",
              "content/random_map_object_eligibility.json",
              "art/overworld/manifest.json", "art/overworld/map_object_sprites.json",
              "src/gdextension/rules/core/port/generated_reward_rules.cpp"]
    payload = {
        "title": reference["title"], "scope": reference["scope"],
        "boundary": reference["evidence_boundary"], "revision": revision,
        "date": date.today().isoformat(), "originals": original,
        "sites": sorted(sites, key=lambda s: (s["category"], s["name"])),
        "referenceCommit": reference["reference_commit"], "manual": reference["manual_url"],
        "fingerprints": {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in inputs},
        "implementationSources": [{"label": label, "url":
            "https://github.com/AcorpBG/heroes-like/blob/" + revision + "/" + path}
            for label, path in [
                ("Generated object mapping", "src/gdextension/rules/core/port/generated_reward_rules.cpp"),
                ("Native transit", "src/gdextension/rules/core/port/native_transit_rules.cpp"),
                ("Visit effects", "src/gdextension/rules/core/port/overworld_rules_site_effects.cpp"),
                ("Held town-support ratings", "src/gdextension/rules/core/port/overworld_rules_ai_sites.cpp"),
                ("Town support and response", "src/gdextension/rules/core/port/overworld_rules_site_response.cpp"),
                ("Follow-up reserve deliveries", "src/gdextension/rules/core/port/day_economy.cpp"),
            ]],
        "counts": {"originals": len(original), "sites": len(sites),
                   "mapped_sites": sum(s["mapped"] for s in sites),
                   "content_only_sites": sum(not s["mapped"] for s in sites),
                   "art": len(sites)},
    }
    return payload


TEMPLATE = r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Hero support & transit — Aurelion Reach reference</title>
<style>
:root{color-scheme:light;--paper:#f4f1e9;--ink:#252e30;--muted:#66716e;--line:#dadfd6;--accent:#26615b;--warm:#87633a;--danger:#92452c}
*{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font:15px/1.5 system-ui,-apple-system,Segoe UI,sans-serif}
main{max-width:1800px;margin:auto;padding:30px 34px 60px}header{margin-bottom:20px}.kicker{font-size:11px;letter-spacing:2px;text-transform:uppercase;color:var(--accent);font-weight:750}
h1{font-family:Georgia,serif;font-weight:500;font-size:39px;letter-spacing:-1px;line-height:1.15;margin:8px 0 10px}header p{max-width:960px;margin:4px 0;color:var(--muted)}
a{color:var(--accent);text-underline-offset:3px}button,input,select{font:inherit}button{cursor:pointer}button:focus-visible,a:focus-visible,input:focus-visible,select:focus-visible{outline:3px solid #b4b97c;outline-offset:3px}
.toolbar{position:sticky;top:0;z-index:4;background:var(--paper);display:flex;gap:10px;flex-wrap:wrap;align-items:center;padding:12px 0;border-top:1px solid var(--line);border-bottom:1px solid var(--line)}
.views{display:flex;background:#e6e9df;border-radius:6px;padding:3px}.views button{border:0;background:none;color:var(--muted);padding:7px 12px;border-radius:4px}.views button.active{background:#fff;color:var(--ink);box-shadow:0 1px 3px #0001}
input,select{background:#fff;border:1px solid #ccd3ca;border-radius:5px;padding:8px 10px;color:var(--ink)}input{flex:1;min-width:180px}select{max-width:200px}
.count{font-size:12px;color:var(--muted);white-space:nowrap;margin-left:auto}.notice{margin:13px 0 20px;font-size:13px;color:var(--muted)}
table{border-collapse:collapse;width:100%;table-layout:fixed;background:#fff9}th{text-align:left;vertical-align:bottom;font-size:11px;letter-spacing:1px;text-transform:uppercase;color:var(--muted);padding:14px 15px;border-bottom:2px solid #b9c5ba}td{vertical-align:top;padding:20px 15px;border-bottom:1px solid var(--line);overflow-wrap:anywhere}
th:nth-child(1){width:18%}th:nth-child(2){width:23%}th:nth-child(3){width:25%}th:nth-child(4){width:34%}
.ours th:nth-child(1){width:23%}.ours th:nth-child(2){width:25%}.ours th:nth-child(3){width:35%}.ours th:nth-child(4){width:17%}
.name{font-weight:700;font-size:16px;line-height:1.3;margin:0 0 7px}.sub{color:var(--muted);font-size:12px}.id{font:11px/1.5 ui-monospace,Consolas,monospace;color:var(--muted)}
.tag{display:inline-block;border-radius:3px;background:#e8eee7;color:#31574e;padding:2px 6px;font-size:11px;margin:4px 0 8px}.tag.warn{color:var(--danger);background:#f4e7dd}.tag.native{color:#345c7a;background:#e2ecf2}.tag.unmapped{background:#eceae3;color:#6e6a5e}
p{margin:0 0 8px}ul{margin:0;padding-left:18px}li{margin:0 0 6px}.sources{margin-top:10px;font-size:12px}.art-grid{display:flex;gap:7px;flex-wrap:wrap}.art-item{width:105px;border:0;background:none;padding:0;text-align:left;color:var(--ink)}.art-frame{height:98px;width:105px;display:flex;align-items:center;justify-content:center;background:radial-gradient(ellipse at center,#415650,#253d3a);border-radius:5px}
.art-frame img{width:96px;height:91px;object-fit:contain;filter:drop-shadow(0 4px 4px #0004)}.art-title{font-size:11px;line-height:1.3;padding-top:5px;display:block}.art-item:hover .art-frame{background:#4b6558}
.single-art{display:flex;gap:11px;align-items:flex-start}.single-art .art-item{flex-shrink:0}.single-art .name{font-size:16px}.pool{border:0;padding:4px 0;margin:9px 0 0;background:none;color:var(--accent);font-size:12px;text-decoration:underline;text-underline-offset:3px}
.effect{font-size:13px}.cadence{font-size:12px;font-weight:650;color:var(--accent);margin-bottom:8px}.effect li{margin-bottom:7px}
details{font-size:12px;margin-top:9px}summary{cursor:pointer;color:var(--accent)}pre{font:11px/1.5 ui-monospace,monospace;white-space:pre-wrap;background:#edf0e9;padding:12px;border-radius:4px;max-height:340px;overflow:auto}
.section-notes{margin-top:25px;padding-top:15px;border-top:1px solid var(--line);max-width:1100px}.section-notes summary{font-size:14px}.section-notes p{margin-top:10px}.empty{padding:50px;text-align:center;color:var(--muted)}footer{margin-top:26px;color:var(--muted);font-size:11px}
dialog{border:1px solid #bac5b7;border-radius:9px;background:var(--paper);color:var(--ink);max-width:1050px;width:90vw;max-height:88vh;padding:23px}dialog::backdrop{background:#13252199}.dialog-top{display:flex;align-items:center;justify-content:space-between;gap:20px;margin-bottom:16px}.dialog-top h2{font:28px/1.1 Georgia,serif;margin:0}.close{border:1px solid #bac5b7;border-radius:4px;background:#fff;padding:5px 11px}.dialog-body .site-detail{display:grid;grid-template-columns:150px 1fr;gap:20px;padding:15px 0;border-bottom:1px solid var(--line)}.large-art{height:155px;background:#29423d;border-radius:5px;display:flex;align-items:center;justify-content:center}.large-art img{width:140px;height:145px;object-fit:contain}.site-detail .name{margin-top:3px}.evidence{font-size:12px;color:var(--muted)}
@media(min-width:1500px){td{padding:24px 20px}.art-frame{height:110px;width:116px}.art-item{width:116px}.art-frame img{width:108px;height:103px}}
@media(max-width:900px){main{padding:22px 16px}h1{font-size:31px}.toolbar{position:static}.count{width:100%}table,thead,tbody,tr,td{display:block}thead{display:none}tr{padding:14px 0;border-bottom:2px solid #b9c5ba}td{border:0;padding:8px 12px}td:before{content:attr(data-label);display:block;font-size:10px;text-transform:uppercase;letter-spacing:1px;color:var(--muted);margin-bottom:7px}.dialog-body .site-detail{grid-template-columns:110px 1fr;gap:12px}.large-art{height:130px}.large-art img{width:100px;height:120px}}
@media print{.toolbar,.pool,.views,dialog{display:none}main{padding:0}body{background:#fff}table{font-size:10px}.art-frame{print-color-adjust:exact}a{color:inherit}.section-notes{break-before:page}}
</style></head><body><main>
<header><div class="kicker">Aurelion Reach / illustrated rules reference</div><h1>Hero support &amp; transit</h1>
<p>What HoMM3 places, what the original object does, and what our current implementation gives you.</p>
<p id="overview"></p></header>
<div class="toolbar" aria-label="Reference filters">
<div class="views"><button id="viewH3" class="active" type="button">HoMM3 → ours</button><button id="viewOurs" type="button">Our structures &amp; art</button></div>
<input type="search" id="search" aria-label="Search names, effects or IDs" placeholder="Search wells, mana, gates, Sunvault…">
<select id="category" aria-label="Category"><option value="">All categories</option></select>
<select id="status" aria-label="Mapping status"><option value="">All mappings</option></select>
<span id="count" class="count" aria-live="polite"></span></div>
<div class="notice" id="viewNote"></div><div id="tableWrap"></div>
<details class="section-notes"><summary>How to read this reference · scope, evidence and known pitfalls</summary>
<p id="scope"></p><p id="boundary"></p>
<ul><li><strong>Analogue</strong> means a recognisable visit role, not proof of full HoMM3 rule parity. Our movement units, spells and morale-like systems differ.</li>
<li><strong>Pool</strong> means the adapter deterministically picks a themed variant from several sites. A painted well can therefore come from an observatory object type.</li>
<li><strong>Fallback</strong> marks a generic replacement. The original object's special interface/effect should not be assumed present.</li>
<li><strong>Native route</strong> uses recovered peer/channel/level data. Generic claim, repair, income and old local-offset profiles do not override these generated routes.</li>
<li><strong>Content only</strong> means a general live definition/art entry with no source-type mapping found in this adapter. It is not a promise that the native generator places it.</li>
<li><strong>Town ratings:</strong> quality/readiness alter strategic scores and convoy allowance; each response point adds two convoy-capacity points. Recovery relief reduces town-recovery penalties through rating thresholds; it does not heal army HP.</li>
<li><strong>Reserve dispatch:</strong> an authored timed response can withdraw unrecruited town stock, choose a friendly destination and deliver real troops without normal hiring prices. Its flat response fee is charged; this is not a troop-stat buff.</li>
<li><strong>Pressure guard:</strong> the response value is computed and displayed, but no applying gameplay consumer was found. Do not count it as working protection.</li>
<li>Descriptions below come from the active visit/effect fields and inspected native code, not merely the older service-contract or public-summary text. Configured fields remain inspectable under each structure.</li></ul>
<p id="implementationSources"></p>
<p>Original-game references: <a id="manual" target="_blank" rel="noreferrer">1999 publisher-hosted manual</a> and <a id="vcmi" target="_blank" rel="noreferrer">pinned VCMI compatibility source</a>. All displayed pictures are our existing game art; thumbnails do not modify original assets.</p>
</details>
<footer id="footer"></footer></main>
<dialog id="detail"><div class="dialog-top"><h2 id="detailTitle"></h2><button class="close" id="close" type="button">Close</button></div><div class="dialog-body" id="detailBody"></div></dialog>
<script id="reference-data" type="application/json">__DATA__</script>
<script>
'use strict';
const D=JSON.parse(document.getElementById('reference-data').textContent);
const S=new Map(D.sites.map(s=>[s.id,s])); let view='h3';
const esc=x=>String(x==null?'':x).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const byId=id=>document.getElementById(id);
function tag(text){const cls=['Changed','Fallback','Skipped'].includes(text)?' warn':text==='Native route'?' native':text==='Content only'?' unmapped':'';return '<span class="tag'+cls+'">'+esc(text)+'</span>';}
function art(s){return '<button type="button" class="art-item" data-site="'+esc(s.id)+'" aria-label="Inspect '+esc(s.name)+'"><span class="art-frame"><img loading="lazy" src="'+s.art.image+'" alt="'+esc(s.name)+' game art" width="100" height="95"></span><span class="art-title">'+esc(s.name)+'</span></button>';}
function effects(s){return '<div class="cadence">'+esc(s.cadence)+'</div><ul class="effect">'+s.details.map(t=>'<li>'+esc(t)+'</li>').join('')+'</ul>';}
function structureDetail(s){return '<section class="site-detail"><div class="large-art"><img src="'+s.art.image+'" alt="'+esc(s.name)+'"></div><div><div class="name">'+esc(s.name)+'</div><div class="id">'+esc(s.id)+'</div>'+effects(s)+'<p class="sources"><a href="'+esc(s.source_url)+'" target="_blank" rel="noreferrer">Live content definition · line '+s.source_line+'</a></p><p class="evidence">Art: '+esc(s.art.path)+(s.art.region?' · atlas crop '+esc(s.art.region.join(', ')):'')+'</p><details><summary>Configured fields</summary><pre>'+esc(JSON.stringify(s.raw,null,2))+'</pre></details></div></section>';}
function openSite(id){const s=S.get(id);if(!s)return;byId('detailTitle').textContent=s.name;byId('detailBody').innerHTML=structureDetail(s);byId('detail').showModal();}
function openPool(id){const r=D.originals.find(x=>x.id===Number(id));if(!r)return;byId('detailTitle').textContent=r.name+' → '+r.sites.length+' possible structures';byId('detailBody').innerHTML='<p>'+esc(r.difference)+'</p>'+r.sites.map(s=>structureDetail(S.get(s))).join('');byId('detail').showModal();}
function populate(){const cats=view==='h3'?[...new Set(D.originals.map(x=>x.category))]:[...new Set(D.sites.map(x=>x.category))];const statuses=view==='h3'?[...new Set(D.originals.map(x=>x.status))]:['Generated mapping','Content only','Native route'];byId('category').innerHTML='<option value="">All categories</option>'+cats.sort().map(x=>'<option>'+esc(x)+'</option>').join('');byId('status').innerHTML='<option value="">All mappings</option>'+statuses.map(x=>'<option>'+esc(x)+'</option>').join('');}
function render(){const q=byId('search').value.trim().toLowerCase(),cat=byId('category').value,status=byId('status').value;let rows='';
 if(view==='h3'){const filtered=D.originals.filter(r=>(!cat||r.category===cat)&&(!status||r.status===status)&&(!q||JSON.stringify([r.name,r.id,r.effect,r.difference,r.sites.map(id=>{const s=S.get(id);return[s.id,s.name,s.details];})]).toLowerCase().includes(q)));
 rows=filtered.map(r=>{const sites=r.sites.map(id=>S.get(id)),visible=[...sites].sort((a,b)=>Number(q&&JSON.stringify([b.id,b.name,b.details]).toLowerCase().includes(q))-Number(q&&JSON.stringify([a.id,a.name,a.details]).toLowerCase().includes(q))).slice(0,3);const mapping=sites.length?'<div class="art-grid">'+visible.map(art).join('')+'</div>'+(sites.length>3?'<button class="pool" type="button" data-pool="'+r.id+'">Inspect all '+sites.length+' possible structures →</button>':''):'<span class="sub">'+esc(r.id===8?'Separate sailing vehicle; no support-site entry.':'No adopted support-site artwork/mapping.')+'</span>';const ours=sites.length===1?effects(sites[0]):'<p class="effect">'+esc(r.difference)+'</p>'+(sites.length?'<p class="sub">Each outcome has its own costs and effects. Open an artwork to inspect that structure.</p>':'');return '<tr><td data-label="Original object"><div class="name">'+esc(r.name)+'</div><div class="id">H3 type '+r.id+'</div>'+tag(r.status)+'<div class="sub">'+esc(r.category)+'</div></td><td data-label="Original effect"><p>'+esc(r.effect)+'</p><a class="sources" href="'+esc(r.reference_url)+'" target="_blank" rel="noreferrer">Original-rule reference ↗</a></td><td data-label="Our art & mapping"><div class="sub" style="margin-bottom:10px">'+esc(r.mapping)+(sites.length?' · '+sites.length+' outcome'+(sites.length===1?'':'s'):'')+'</div>'+mapping+'</td><td data-label="Current implementation">'+ours+(sites.length===1?'<p class="sub" style="margin-top:10px">'+esc(r.difference)+'</p>':'')+'</td></tr>';}).join('');
 byId('tableWrap').innerHTML='<table><thead><tr><th>HoMM3 object</th><th>Original effect</th><th>Our art & mapping</th><th>Current implementation</th></tr></thead><tbody>'+rows+'</tbody></table>';
 byId('count').textContent=filtered.length+' / '+D.originals.length+' original object types';byId('viewNote').textContent='Mapping comes from the native adapter. Pool outcomes are deterministic per placement; open an artwork for full live fields.';
 }else{const filtered=D.sites.filter(s=>(!cat||s.category===cat)&&(!status||(status==='Content only'?!s.mapped:status==='Native route'?s.native:s.mapped))&&(!q||JSON.stringify([s.name,s.id,s.details,s.originals]).toLowerCase().includes(q)));
 rows=filtered.map(s=>{const direct=s.originals.filter(x=>x.mapping!=='Generic fallback'),fallback=s.originals.filter(x=>x.mapping==='Generic fallback');let originals=direct.map(r=>'<p class="sub"><strong>'+esc(r.name)+'</strong> · #'+r.id+'<br>'+esc(r.mapping)+'</p>').join('');if(fallback.length)originals+='<details><summary>Also eligible for '+fallback.length+' generic fallback types</summary><p>'+esc(fallback.map(r=>r.name+' #'+r.id).join('; '))+'</p></details>';if(!s.originals.length)originals='<p class="sub">No generated source-type mapping found. Definition and art exist as general content; may remain relevant to older saves or editor placements.</p>';return '<tr><td data-label="Structure & art"><div class="single-art">'+art(s)+'<div><div class="name">'+esc(s.name)+'</div><div class="sub">'+esc(s.category)+'</div>'+tag(s.native?'Native route':s.mapped?'Generated mapping':'Content only')+'</div></div></td><td data-label="H3 origin">'+originals+'</td><td data-label="Our function">'+effects(s)+'</td><td data-label="Definition"><div class="id">'+esc(s.id)+'</div><p class="sources"><a href="'+esc(s.source_url)+'" target="_blank" rel="noreferrer">Content definition ↗</a></p><button class="pool" type="button" data-site="'+esc(s.id)+'">Inspect fields & art</button></td></tr>';}).join('');
 byId('tableWrap').innerHTML='<table class="ours"><thead><tr><th>Our structure & art</th><th>Original source mapping</th><th>Our function & conditions</th><th>Definition</th></tr></thead><tbody>'+rows+'</tbody></table>';byId('count').textContent=filtered.length+' / '+D.sites.length+' structures';byId('viewNote').textContent='One row per general structure. “Content only” entries are not attributed to H3 generation merely because they have art.';
 }if(!rows)byId('tableWrap').innerHTML='<div class="empty">No matching structures. Try another name, effect or mapping filter.</div>';}
function setView(v){view=v;byId('viewH3').classList.toggle('active',v==='h3');byId('viewOurs').classList.toggle('active',v==='ours');byId('viewH3').setAttribute('aria-pressed',String(v==='h3'));byId('viewOurs').setAttribute('aria-pressed',String(v==='ours'));populate();render();}
byId('viewH3').addEventListener('click',()=>setView('h3'));byId('viewOurs').addEventListener('click',()=>setView('ours'));byId('search').addEventListener('input',render);byId('category').addEventListener('change',render);byId('status').addEventListener('change',render);
document.addEventListener('click',e=>{const a=e.target.closest('[data-site]'),b=e.target.closest('[data-pool]');if(a)openSite(a.dataset.site);else if(b)openPool(b.dataset.pool);});
byId('close').addEventListener('click',()=>byId('detail').close());byId('detail').addEventListener('click',e=>{if(e.target===byId('detail'))byId('detail').close();});
byId('overview').textContent=D.counts.originals+' original object types · '+D.counts.sites+' illustrated structures · '+D.counts.mapped_sites+' structures mapped · '+D.counts.content_only_sites+' content-only entries';
byId('implementationSources').innerHTML='Our implementation: '+D.implementationSources.map(x=>'<a href="'+esc(x.url)+'" target="_blank" rel="noreferrer">'+esc(x.label)+'</a>').join(' · ');
byId('scope').textContent=D.scope;byId('boundary').textContent=D.boundary;byId('manual').href=D.manual;byId('vcmi').href='https://github.com/vcmi/vcmi/tree/'+D.referenceCommit+'/config/objects';
byId('footer').textContent='Source snapshot '+D.revision.slice(0,9)+' · Built '+D.date+' · Pinned compatibility reference '+D.referenceCommit.slice(0,9)+' · Existing art embedded as offline thumbnails. This is an inspection reference, not a gameplay or generator change.';
setView('h3');window.referenceReady=true;
</script></body></html>
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    payload = build()
    encoded = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(TEMPLATE.replace("__DATA__", encoded), encoding="utf-8")
    print(json.dumps({"output": str(args.output.resolve()), "bytes": args.output.stat().st_size,
                      **payload["counts"], "source_revision": payload["revision"][:9]}))


if __name__ == "__main__":
    main()
