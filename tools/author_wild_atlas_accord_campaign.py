#!/usr/bin/env python3
"""Author The Wild Atlas Accord campaign and its seven generated art identities."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
SOURCE_ROOT = ROOT / "art/campaigns/source/generated"
RUNTIME_ROOT = ROOT / "art/campaigns/runtime"
SOURCE_DIR = SOURCE_ROOT / "wild_atlas_accord"
GENERATOR_ROOT = Path("/root/.codex/generated_images/019fe72a-30b1-76f3-b911-385c4444bd16")
CAMPAIGN_ID = "campaign_wild_atlas_accord"
SLICE_ID = "content-wild-atlas-accord-campaign-10184"

COMMON_CAPS = {
    "gold": 500, "wood": 2, "ore": 2, "aetherglass": 0,
    "embergrain": 0, "peatwax": 0, "verdant_grafts": 0,
    "brass_scrip": 0, "memory_salt": 0,
}

EMBLEM = {
    "stem": "wild_atlas_accord",
    "original": "exec-5a35253d-7108-4939-9d04-63cdc1c4d31f.png",
    "prompt": "Original transparent campaign emblem: an open asymmetrical brass field atlas with six irregular clasps orbiting a pale compass-seed flame; the clasps suggest ember vanes, crescent shell, prism lens, root antlers, pressure rings, and a drowned bell; hand-painted fantasy strategy UI heraldry, strong non-color silhouette, no characters, text, logo, watermark, franchise design, scenery, or border.",
    "alt": "An open asymmetrical field atlas carries six materially distinct clasps around a pale compass-seed flame.",
}

CHAPTERS = [
    {
        "scenario_id": "emberwell-censerwing-updraft", "stem": "cindervane_updraft_roost",
        "seal_stem": "censerwing_updraft_seal", "original": "exec-389bcc5e-7bae-48fd-96ec-7056baac2232.png",
        "hero_id": "hero_lyra", "objective_id": "cindervane_updraft_roost_recruit",
        "witness_flag": "wild_atlas_censerwing_bearing_entered",
        "label": "Chapter I: Enter the Censerwing Bearing", "title": "Open the Atlas in Rising Ash",
        "description": "Lyra clears Censerwing Updraft Roost and records the atlas's first living bearing in ember and wind.",
        "status_hint": "Break all three watches, claim the roost, recruit Cindervane Censerwings, and capture the opposing seat.",
        "briefing": "A field atlas with six empty clasps has surfaced on the frontier. Lyra must prove its first route is more than an old survey by securing the updraft roost and entering a living Censerwing bearing.",
        "intel": "Three habitat watches divide the road from the roost. The witness is entered only when a Censerwing joins Lyra's company.",
        "stakes": "Without a living first bearing, the remaining pages are only decorative guesses.",
        "victory": "Ember vanes turn above the open atlas, fixing its first bearing in living flight.",
        "defeat": "The ash route closes and the atlas keeps its first clasp empty.",
        "alt": "A split basalt chimney and four ember vanes curve around an empty bronze censer.",
        "prompt": "Original transparent chapter seal: split basalt chimney, four ember vanes, curved bronze cage ribs, empty censer; hand-painted fantasy strategy UI heraldry, strong non-color silhouette, no creature, character, text, logo, watermark, franchise design, scenery, or border.",
    },
    {
        "scenario_id": "fenhook-fenmirror-muster", "stem": "fenmirror_shell_basin",
        "seal_stem": "fenmirror_basin_seal", "original": "exec-3f30ef28-3310-4f66-8582-ae7307c3ab9d.png",
        "hero_id": "hero_tarn", "objective_id": "fenmirror_shell_basin_recruit",
        "witness_flag": "wild_atlas_fenmirror_bearing_entered",
        "label": "Chapter II: Read the Fenmirror Bearing", "title": "Find a Route in Dark Water",
        "description": "Tarn secures Fenmirror Shell Basin and reads the second bearing where no dry road survives.",
        "status_hint": "Clear the three watches, claim the basin, recruit Fenmirror Gallowshells, and take the frontier seat.",
        "briefing": "The first clasp points into water that reflects no reliable sky. Tarn must reach the shell basin, muster its Gallowshells, and teach the atlas to hold a route that shifts with the fen.",
        "intel": "The mirror basin remains guarded after the outer watches fall. A living Gallowshell witness is the only stable measure.",
        "stakes": "An atlas that records only dry roads abandons half the frontier before the accord begins.",
        "victory": "Two unequal shells hold one dark reflection, and the fen route settles into the atlas.",
        "defeat": "The basin clouds over and the second bearing dissolves among the reeds.",
        "alt": "Two unequal crescent shells rise around a dark mirror basin rooted into a reed-wrapped landing.",
        "prompt": "Original transparent chapter seal: unequal crescent shells, dark mirror basin, reed chain and root lip; hand-painted fantasy strategy UI heraldry, strong non-color silhouette, no creature, character, text, logo, watermark, franchise design, scenery, or border.",
    },
    {
        "scenario_id": "glasswind-prismwake-crossing", "stem": "prismwake_refraction_shelf",
        "seal_stem": "prismwake_crossing_seal", "original": "exec-376bd759-07b3-48b7-a033-4f1c971d7079.png",
        "hero_id": "hero_neral", "objective_id": "prismwake_refraction_shelf_recruit",
        "witness_flag": "wild_atlas_prismwake_bearing_entered",
        "label": "Chapter III: Align the Prismwake Bearing", "title": "Carry the Road Through Broken Light",
        "description": "Neral aligns Prismwake Refraction Shelf and fixes a third route through glare, mirage, and divided light.",
        "status_hint": "Defeat all three watches, claim the shelf, recruit Prismwake Raylings, and capture the opposing seat.",
        "briefing": "The wet bearing reaches a crossing that appears in three places at once. Neral must open the refraction shelf and use its Raylings to align a route no single reflection can counterfeit.",
        "intel": "The last watch blocks both the habitat and the true line through the glasswind. Recruitment completes the alignment.",
        "stakes": "If glare can invent a road, every later atlas entry can be disputed as illusion.",
        "victory": "Two prism sails agree around one offset lens, and the third bearing holds through broken light.",
        "defeat": "The crossing fractures into mirages and the atlas loses its eastern line.",
        "alt": "Two asymmetric prism sails and three crystal keels frame an offset oval lens.",
        "prompt": "Original transparent chapter seal: offset oval lens, two asymmetric prism sails, three crystal keels; hand-painted fantasy strategy UI heraldry, strong non-color silhouette, no creature, character, text, logo, watermark, franchise design, scenery, or border.",
    },
    {
        "scenario_id": "boltroot-knotstag-circuit", "stem": "knotstag_root_court",
        "seal_stem": "rootcrown_circuit_seal", "original": "exec-7c95de3c-6580-476d-a18d-48e8030e92ab.png",
        "hero_id": "hero_thornwake_bryn_boltroot", "objective_id": "knotstag_root_court_recruit",
        "witness_flag": "wild_atlas_rootcrown_bearing_entered",
        "label": "Chapter IV: Root the Knotstag Bearing", "title": "Let the Atlas Remember Living Ground",
        "description": "Bryn Boltroot secures Knotstag Root-Court and gives the atlas a fourth bearing that grows with the land.",
        "status_hint": "Clear the watches, claim the root-court, recruit Rootcrown Knotstags, and capture the hostile seat.",
        "briefing": "Three fixed bearings cannot describe a road whose soil moves. Bryn must open the root-court, muster its Knotstags, and root a living circuit into the atlas without pinning the grove in place.",
        "intel": "The court lies behind three hostile fronts. Its antler gates answer only when a Rootcrown company accepts the route.",
        "stakes": "A map that kills change to preserve accuracy becomes obsolete the moment it is sealed.",
        "victory": "Unequal root antlers flower around the fourth clasp, and the atlas learns to remember change.",
        "defeat": "The living road closes beneath old growth and the fourth page remains rootless.",
        "alt": "Unequal living-root antlers surround a hollow seed dais and three hanging seed lanterns.",
        "prompt": "Original transparent chapter seal: unequal living-root antlers, hollow seed dais, three seed lanterns; hand-painted fantasy strategy UI heraldry, strong non-color silhouette, no creature, character, text, logo, watermark, franchise design, scenery, or border.",
    },
    {
        "scenario_id": "debtrune-gaugecoil-burrow", "stem": "gaugecoil_pressure_burrow",
        "seal_stem": "gaugecoil_burrow_seal", "original": "exec-0471343b-dbf8-4cb6-8dcb-664187bb93c1.png",
        "hero_id": "hero_brasshollow_harro_debtrune", "objective_id": "gaugecoil_pressure_burrow_recruit",
        "witness_flag": "wild_atlas_gaugecoil_bearing_entered",
        "label": "Chapter V: Measure the Gaugecoil Bearing", "title": "Cut a Road Beneath the Surface",
        "description": "Harro Debtrune opens Gaugecoil Pressure Burrow and measures a fifth route through stone and pressure.",
        "status_hint": "Break three burrow watches, claim the habitat, recruit Gaugecoil Orewyrms, and seize the opposing seat.",
        "briefing": "The rooted page ends at bare rock, but pressure marks a road beneath it. Harro must open the burrow, recruit its Orewyrms, and certify a route by three unequal gauges instead of inherited claims.",
        "intel": "The final watch guards the drill line and habitat together. The gauges settle only after a living Orewyrm joins the expedition.",
        "stakes": "Without a measured under-road, the accord can be cut wherever mountains hide the surface.",
        "victory": "Three pressure rings settle around the fifth clasp, fixing a road beneath the visible world.",
        "defeat": "The gauges climb into danger and the under-road collapses outside the atlas.",
        "alt": "Three brass pressure rings carry a diagonal drill rail, two blank gauges, and a red relief valve.",
        "prompt": "Original transparent chapter seal: three brass pressure rings, diagonal wedge drill rail, two blank gauges, red relief valve; hand-painted fantasy strategy UI heraldry, strong non-color silhouette, no creature, character, text, logo, watermark, franchise design, scenery, or border.",
    },
    {
        "scenario_id": "mistcorsair-gloambell-sounding", "stem": "gloambell_sounding_deep",
        "seal_stem": "gloambell_sounding_seal", "original": "exec-ae1655b3-ecaf-4c72-9ec8-ed460b3619b6.png",
        "hero_id": "hero_veilmourn_cela_mistcorsair", "objective_id": "gloambell_sounding_deep_recruit",
        "witness_flag": "wild_atlas_gloambell_bearing_entered", "rival_hero_id": "hero_thornwake_tova_rootwright",
        "label": "Chapter VI: Sound the Gloambell Bearing", "title": "Leave the Atlas Open to Every Horizon",
        "description": "Cela Mist-Corsair secures Gloambell Sounding Deep and sounds all six bearings as an open frontier accord.",
        "status_hint": "Defeat Tova Rootwright's three watches, claim the deep, recruit Gloambell Wake-Mantas, and capture the final seat.",
        "briefing": "Five bearings reach the coast but none can name the road beyond sight. Cela must pass Tova Rootwright's living cordon, open Gloambell Sounding Deep, and let its Wake-Mantas carry the atlas beyond every fixed horizon.",
        "intel": "Tova commands the final habitat watch from the rootward road. The drowned bell sounds only for a living Wake-Manta witness.",
        "stakes": "A closed atlas becomes a border. An open atlas can remain an accord between travelers who refuse to own one another's roads.",
        "victory": "The drowned bell sounds through six unequal clasps, leaving the completed atlas open to every frontier horizon.",
        "defeat": "The last sounding fails and five hard-won routes close into separate claims.",
        "alt": "A drowned bell hangs beneath a tilted whalebone arch above two tideglass pools and a hooked keel stair.",
        "prompt": "Original transparent chapter seal: tilted whalebone arch, drowned bell, hooked keel stair, four sounding rods, two tideglass pools; hand-painted fantasy strategy UI heraldry, strong non-color silhouette, no creature, character, text, logo, watermark, franchise design, scenery, or border.",
    },
]


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_compact(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, separators=(",", ":")) + "\n", encoding="utf-8")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def upsert(items: list[dict], row: dict) -> None:
    for index, current in enumerate(items):
        if current.get("id") == row["id"]:
            items[index] = row
            return
    items.append(row)


def curate(original_name: str, source_path: Path, runtime_path: Path, runtime_size: int) -> None:
    image = Image.open(GENERATOR_ROOT / original_name).convert("RGBA")
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError(f"Generated source has no visible pixels: {original_name}")
    cropped = image.crop(bbox)
    maximum = 1080
    scale = min(maximum / cropped.width, maximum / cropped.height)
    resized = cropped.resize((max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale))), Image.Resampling.LANCZOS)
    master = Image.new("RGBA", (1254, 1254), (0, 0, 0, 0))
    master.alpha_composite(resized, ((1254 - resized.width) // 2, (1254 - resized.height) // 2))
    source_path.parent.mkdir(parents=True, exist_ok=True)
    runtime_path.parent.mkdir(parents=True, exist_ok=True)
    master.save(source_path, optimize=True)
    master.resize((runtime_size, runtime_size), Image.Resampling.LANCZOS).save(runtime_path, optimize=True)


def art_row(chapter: dict) -> dict:
    source = SOURCE_ROOT / "chapter_seals" / f"{chapter['seal_stem']}_source.png"
    runtime = RUNTIME_ROOT / "chapter_seals" / f"{chapter['seal_stem']}.png"
    return {
        "id": f"campaign_chapter_seal_{chapter['scenario_id'].replace('-', '_')}", "role": "chapter_seal",
        "source_path": f"res://art/campaigns/source/generated/chapter_seals/{chapter['seal_stem']}_source.png",
        "runtime_path": f"res://art/campaigns/runtime/chapter_seals/{chapter['seal_stem']}.png",
        "source_sha256": digest(source), "runtime_sha256": digest(runtime),
        "non_color_identity": chapter["alt"],
    }


def campaign_chapter(index: int, chapter: dict) -> dict:
    row = {
        "scenario_id": chapter["scenario_id"],
        "seal_id": f"campaign_chapter_seal_{chapter['scenario_id'].replace('-', '_')}",
        "seal_path": f"res://art/campaigns/runtime/chapter_seals/{chapter['seal_stem']}.png",
        "seal_source_path": f"res://art/campaigns/source/generated/chapter_seals/{chapter['seal_stem']}_source.png",
        "seal_alt_text": chapter["alt"],
        "seal_source_sha256": digest(SOURCE_ROOT / "chapter_seals" / f"{chapter['seal_stem']}_source.png"),
        "seal_runtime_sha256": digest(RUNTIME_ROOT / "chapter_seals" / f"{chapter['seal_stem']}.png"),
        "label": chapter["label"], "description": chapter["description"], "chapter_index": index + 1,
        "chapter_title": chapter["title"], "status_hint": chapter["status_hint"],
        "carryover_summary": "Only the chapter witness and capped common stores cross this handoff; commander growth, army stacks, spells, artifacts, and rare resources remain local.",
        "briefing": chapter["briefing"], "intel": chapter["intel"], "stakes": chapter["stakes"],
        "aftermath_victory": chapter["victory"], "aftermath_defeat": chapter["defeat"],
        "journal_victory": chapter["victory"], "journal_defeat": chapter["defeat"],
    }
    if index == 0:
        row["starts_unlocked"] = True
    else:
        previous = CHAPTERS[index - 1]
        row["unlock_requirements"] = [
            {"type": "scenario_status", "scenario_id": previous["scenario_id"], "status": "victory"},
            {"type": "scenario_flag_true", "scenario_id": previous["scenario_id"], "flag": previous["witness_flag"]},
        ]
        row["carryover_import"] = {
            "from_scenario_id": previous["scenario_id"], "resources": True,
            "hero_progression": False, "spells": False, "artifacts": False,
            "flags_prefix": "carryover_",
        }
    if index < len(CHAPTERS) - 1:
        row["carryover_export"] = {
            "retain_hero_progression": False, "retain_spells": False,
            "retain_artifacts": False, "resource_fraction": 0.12,
            "resource_caps": COMMON_CAPS, "flag_ids": [chapter["witness_flag"]],
        }
    return row


def main() -> None:
    emblem_source = SOURCE_ROOT / "emblems/wild_atlas_accord_source.png"
    emblem_runtime = RUNTIME_ROOT / "emblems/wild_atlas_accord.png"
    curate(EMBLEM["original"], emblem_source, emblem_runtime, 128)
    for chapter in CHAPTERS:
        curate(
            chapter["original"],
            SOURCE_ROOT / "chapter_seals" / f"{chapter['seal_stem']}_source.png",
            RUNTIME_ROOT / "chapter_seals" / f"{chapter['seal_stem']}.png",
            64,
        )

    campaigns_payload = load(CONTENT / "campaigns.json")
    scenarios_payload = load(CONTENT / "scenarios.json")
    scenarios = {row["id"]: row for row in scenarios_payload["items"]}
    for index, chapter in enumerate(CHAPTERS):
        scenario = scenarios[chapter["scenario_id"]]
        scenario["selection"]["availability"] = {"campaign": True, "skirmish": True}
        hook_id = f"wild_atlas_{chapter['stem']}_witness"
        hooks = [hook for hook in scenario.get("script_hooks", []) if hook.get("id") != hook_id]
        hooks.append({
            "id": hook_id, "priority": 35,
            "conditions": [{"type": "objective_met", "objective_id": chapter["objective_id"]}],
            "effects": [
                {"type": "set_flag", "flag": chapter["witness_flag"], "value": True},
                {"type": "message", "text": chapter["victory"]},
            ],
        })
        scenario["script_hooks"] = hooks
        scenario["wild_atlas_accord"] = {
            "campaign_id": CAMPAIGN_ID, "chapter_index": index + 1,
            "witness_flag": chapter["witness_flag"], "mechanic_objective_id": chapter["objective_id"],
        }
        if chapter.get("rival_hero_id"):
            finale = next(row for row in scenario["encounters"] if row.get("placement_id") == "gloambell_sounding_deep_front_3")
            finale["enemy_commander_state"] = {
                "roster_hero_id": chapter["rival_hero_id"], "faction_id": "faction_thornwake",
            }

    campaign = {
        "id": CAMPAIGN_ID, "name": "The Wild Atlas Accord",
        "description": "Six commanders carry one open field atlas through six living habitats, proving routes in ash, fen, broken light, moving roots, buried pressure, and the sounding deep without turning any road into ownership.",
        "summary": "A six-chapter cross-faction campaign that turns six frontier habitat expeditions into one bounded witness chain.",
        "region": "The Six Living Bearings",
        "emblem_id": "campaign_emblem_wild_atlas_accord",
        "emblem_path": "res://art/campaigns/runtime/emblems/wild_atlas_accord.png",
        "emblem_source_path": "res://art/campaigns/source/generated/emblems/wild_atlas_accord_source.png",
        "emblem_alt_text": EMBLEM["alt"], "emblem_source_sha256": digest(emblem_source),
        "emblem_runtime_sha256": digest(emblem_runtime),
        "arc_goal": "Secure six living habitats, recruit each exact frontier creature, and pass only its witnessed bearing plus capped common stores to the next independent commander.",
        "completion_title": "Six Bearings, One Open Atlas",
        "completion_summary": "The Gloambell sounds through six distinct clasps. Every route remains open to future correction and none becomes the property of the commander who witnessed it.",
        "starting_scenario_id": CHAPTERS[0]["scenario_id"],
        "scenarios": [campaign_chapter(index, chapter) for index, chapter in enumerate(CHAPTERS)],
        "content_batch_id": SLICE_ID, "content_status": "wild_atlas_accord_campaign_live",
    }
    upsert(campaigns_payload["items"], campaign)
    campaigns_payload["player_facing_active_campaign_count"] = len(campaigns_payload["items"])
    campaigns_payload["reactivation_reason"] = "wild_atlas_accord_campaign_2026_09_01"

    assets = [{
        "id": "campaign_emblem_wild_atlas_accord", "role": "campaign_emblem",
        "source_path": "res://art/campaigns/source/generated/emblems/wild_atlas_accord_source.png",
        "runtime_path": "res://art/campaigns/runtime/emblems/wild_atlas_accord.png",
        "source_sha256": digest(emblem_source), "runtime_sha256": digest(emblem_runtime),
        "non_color_identity": EMBLEM["alt"],
    }, *[art_row(chapter) for chapter in CHAPTERS]]
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    manifest = {
        "schema_id": "wild_atlas_accord_campaign_art_v1", "content_batch_id": SLICE_ID,
        "generator_mode": "built_in_image_gen", "generated_at": "2026-09-01",
        "campaign_id": CAMPAIGN_ID,
        "runtime_pipeline": "Seven separately generated transparent originals are alpha-trimmed onto 1254px source masters and Lanczos-downscaled to one 128px emblem and six 64px chapter seals. Source masters are excluded from release packages.",
        "generated_originals": [str(GENERATOR_ROOT / EMBLEM["original"]), *[str(GENERATOR_ROOT / chapter["original"]) for chapter in CHAPTERS]],
        "prompts": [EMBLEM["prompt"], *[chapter["prompt"] for chapter in CHAPTERS]],
        "assets": assets,
    }
    write_compact(CONTENT / "campaigns.json", campaigns_payload)
    write_compact(CONTENT / "scenarios.json", scenarios_payload)
    (SOURCE_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "campaign_id": CAMPAIGN_ID, "campaign_count": len(campaigns_payload["items"]),
        "chapter_count": len(CHAPTERS),
        "campaign_enabled_scenario_count": sum(row.get("selection", {}).get("availability", {}).get("campaign") is True for row in scenarios_payload["items"]),
        "art_identity_count": len(assets),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
