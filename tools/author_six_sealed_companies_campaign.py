#!/usr/bin/env python3
"""Author The Six Sealed Companies campaign and exact art provenance."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
SOURCE_ROOT = ROOT / "art/campaigns/source/generated"
RUNTIME_ROOT = ROOT / "art/campaigns/runtime"
SOURCE_DIR = SOURCE_ROOT / "six_sealed_companies"
CAMPAIGN_ID = "campaign_six_sealed_companies"
SLICE_ID = "content-six-sealed-companies-campaign-10184"

COMMON_CAPS = {
    "gold": 500,
    "wood": 2,
    "ore": 2,
    "aetherglass": 0,
    "embergrain": 0,
    "peatwax": 0,
    "verdant_grafts": 0,
    "brass_scrip": 0,
    "memory_salt": 0,
}

CHAPTERS = [
    {
        "scenario_id": "pikeward-ashcharter-veteran-muster",
        "hero_id": "hero_torren",
        "prefix": "ashcharter",
        "witness_flag": "sealed_companies_ashcharter_roll_entered",
        "witness_objective_id": "ashcharter_assemble_veterans",
        "hook_id": "sealed_companies_ashcharter_witness",
        "seal_stem": "ashcharter_seal",
        "seal_id": "campaign_chapter_seal_pikeward_ashcharter_veteran_muster",
        "label": "Chapter I: Raise the Ash-Charter Roll",
        "chapter_title": "Call the First Company Home",
        "description": "Torren reopens the rain-black rollhouse and enters Embercourt's recovered veteran grades as the first sealed company.",
        "status_hint": "Break the three screens, claim Ash-Charter Rollhouse, and assemble every required Embercourt veteran.",
        "carryover_summary": "Exports only Torren's muster-seal witness and a capped share of common stores; his company, growth, spells, artifacts, and embergrain remain local.",
        "briefing": "Six veteran rolls have been struck from the frontier ledger at once. Torren must force open Ash-Charter Rollhouse, recall its scattered companies, and send the first independently witnessed seal down the circuit before the erased rolls become accepted law.",
        "intel": "Three hostile companies cover the western road, southern approach, and rollhouse gate. The seal is entered only after the exact veteran company is assembled.",
        "stakes": "Without the first recovered roll, every later muster can be dismissed as an isolated local claim.",
        "aftermath_victory": "Torren raises the forked ash pennant and sends the first sealed company roll into the frontier circuit.",
        "aftermath_defeat": "The rollhouse remains shuttered and the first missing company is written off as already lost.",
        "journal_victory": "Torren entered the Ash-Charter veteran roll as the first sealed witness.",
        "journal_defeat": "Torren failed to recall the first sealed company.",
        "alt": "A forked ember charter pennant rises above a compact iron rollhouse brazier.",
    },
    {
        "scenario_id": "chainboom-gorefen-veteran-muster",
        "hero_id": "hero_mireclaw_kessa_chainboom",
        "prefix": "gorefenring",
        "witness_flag": "sealed_companies_gorefen_chain_bound",
        "witness_objective_id": "gorefenring_assemble_veterans",
        "hook_id": "sealed_companies_gorefen_witness",
        "seal_stem": "gorefen_ring_seal",
        "seal_id": "campaign_chapter_seal_chainboom_gorefen_veteran_muster",
        "label": "Chapter II: Bind the Gorefen Chain",
        "chapter_title": "Make the Second Roll Answer",
        "description": "Kessa Chainboom binds ferry lashers and Gorefen shock companies into a second muster seal that cannot be separated from its living roster.",
        "status_hint": "Clear the ring approaches, claim Gorefen Chain Ring, and assemble both missing Mireclaw veteran grades.",
        "carryover_summary": "Imports only Torren's witness and capped common stores, then exports Kessa's chain-bound seal without transferring either commander.",
        "briefing": "The first seal reaches the fen with its clasp cut but its witness intact. Kessa must tighten Gorefen's slack chain ring, recover the ferry and shock companies named on it, and prove the circuit records living formations rather than empty heraldry.",
        "intel": "Sunvault screens hold the dry approaches. The chain ring remains blocked until its guard falls and both missing companies answer Kessa's field roll.",
        "stakes": "A ledger of symbols without soldiers would let any court claim the recovered companies exist only on paper.",
        "aftermath_victory": "The hide drum sounds through a taut chain ring, carrying the second sealed company onward.",
        "aftermath_defeat": "The chain stays slack and Gorefen's erased veterans remain scattered among the channels.",
        "journal_victory": "Kessa bound the Gorefen chain as the second sealed witness.",
        "journal_defeat": "Kessa failed to make the second company roll answer.",
        "alt": "A taut fen chain ring encloses one hide drum and a small marsh lantern.",
    },
    {
        "scenario_id": "glassmarshal-daybreak-veteran-muster",
        "hero_id": "hero_sunvault_ilyr_glassmarshal",
        "prefix": "daybreakprism",
        "witness_flag": "sealed_companies_daybreak_prism_aligned",
        "witness_objective_id": "daybreakprism_assemble_veterans",
        "hook_id": "sealed_companies_daybreak_witness",
        "seal_stem": "daybreak_prism_seal",
        "seal_id": "campaign_chapter_seal_glassmarshal_daybreak_veteran_muster",
        "label": "Chapter III: Align the Daybreak Prism",
        "chapter_title": "Prove the Roll in Two Reflections",
        "description": "Ilyr Glassmarshal aligns mirror duelists and a Daybreak colossus under one split prism so neither reflection can counterfeit the roster.",
        "status_hint": "Defeat the three Thornwake screens, open the drill prism, and assemble both exact Sunvault veteran identities.",
        "carryover_summary": "Imports only Kessa's chain witness and capped common stores, then exports Ilyr's aligned seal while all personal state remains local.",
        "briefing": "Two recovered seals can still be called mutually convenient stories. Ilyr must open the split Daybreak drill prism and align its missing duelists and colossus in two independent reflections before adding a third witness to the circuit.",
        "intel": "Thornwake cordons occupy both approaches and the prism court. Victory requires the exact companies, not substitute strength or a captured landmark alone.",
        "stakes": "If the third roll cannot survive mirrored inspection, the whole circuit can be broken by one forged roster.",
        "aftermath_victory": "Both mirror fins agree on the assembled company, and Ilyr dispatches the third seal without a disputed line.",
        "aftermath_defeat": "The prism remains folded and the veteran roll fractures into incompatible reflections.",
        "journal_victory": "Ilyr aligned the Daybreak company as the third sealed witness.",
        "journal_defeat": "Ilyr failed to prove the veteran roll in both reflections.",
        "alt": "A split ivory drill prism stands between asymmetric mirror fins above a small sun dial.",
    },
    {
        "scenario_id": "bramblehound-worldroot-veteran-muster",
        "hero_id": "hero_thornwake_silsa_bramblehound",
        "prefix": "fivebough",
        "witness_flag": "sealed_companies_five_bough_rooted",
        "witness_objective_id": "fivebough_assemble_veterans",
        "hook_id": "sealed_companies_five_bough_witness",
        "seal_stem": "five_bough_seal",
        "seal_id": "campaign_chapter_seal_bramblehound_worldroot_veteran_muster",
        "label": "Chapter IV: Root the Five Boughs",
        "chapter_title": "Recall Every Grade of the Living Roll",
        "description": "Silsa Bramblehound wakes five muster boughs and recalls Thornwake's complete missing company span from scouts to Worldroot Bastion.",
        "status_hint": "Clear all three foundry screens, claim the grove, and assemble all five required Thornwake veteran grades.",
        "carryover_summary": "Imports Ilyr's aligned witness and capped stores, then exports only Silsa's rooted seal; no army, growth, spell, artifact, or rare graft crosses chapters.",
        "briefing": "The circuit reaches a grove whose roll was not erased with ink but put to sleep at the roots. Silsa must wake all five boughs and call every missing grade, from the smallest pollenhook company to the Worldroot Bastion itself.",
        "intel": "Brasshollow interdictors have divided the grove from its outer companies. The fourth witness is valid only when all five identities stand in Silsa's field army.",
        "stakes": "A compact that records only its largest formations will abandon the scouts and tenders who make every veteran line possible.",
        "aftermath_victory": "Five boughs flower around one living roll, and Silsa sends the rooted fourth seal toward the foundry road.",
        "aftermath_defeat": "The grove stays dormant and Thornwake's missing grades remain separate, nameless roots.",
        "journal_victory": "Silsa rooted all five company grades as the fourth sealed witness.",
        "journal_defeat": "Silsa failed to wake the complete living roll.",
        "alt": "Five living boughs curl around a seed shield and a glowing root heart.",
    },
    {
        "scenario_id": "pitmarshal-foundry-veteran-muster",
        "hero_id": "hero_brasshollow_selka_pitmarshal",
        "prefix": "threegauge",
        "witness_flag": "sealed_companies_three_gauges_certified",
        "witness_objective_id": "threegauge_assemble_veterans",
        "hook_id": "sealed_companies_three_gauge_witness",
        "seal_stem": "three_gauge_seal",
        "seal_id": "campaign_chapter_seal_pitmarshal_foundry_veteran_muster",
        "label": "Chapter V: Certify the Three Gauges",
        "chapter_title": "Measure the Company Under Pressure",
        "description": "Selka Pitmarshal restores three independent assay gauges and certifies the recovered Brasshollow company under field pressure.",
        "status_hint": "Break the charter screens, open Three-Gauge Chapter Foundry, and assemble all three missing Brasshollow veterans.",
        "carryover_summary": "Imports Silsa's rooted witness and capped stores, then exports Selka's pressure certificate while every commander's personal state stays isolated.",
        "briefing": "Four seals name companies; the fifth must prove they can still meet a hard measure. Selka must relight Three-Gauge Chapter Foundry, restore its erased veteran grades, and obtain three independent readings before the final sounding.",
        "intel": "Embercourt companies hold the assay roads and foundry gate. The gauges certify only the exact quenchspool, gaugefire, and Foundry Saint roll.",
        "stakes": "Without a measured field strength, the compact could preserve proud names while sending hollow companies to the wall.",
        "aftermath_victory": "Three unequal gauges return one true reading, and Selka stamps the fifth company seal under pressure.",
        "aftermath_defeat": "The foundry stays cold and the recovered roster fails its first common assay.",
        "journal_victory": "Selka certified the Three-Gauge company as the fifth sealed witness.",
        "journal_defeat": "Selka failed to measure the recovered roll under pressure.",
        "alt": "Three unequal brass pressure gauges rise above a black foundry bell hammer.",
    },
    {
        "scenario_id": "keelwarden-fogkeel-veteran-muster",
        "hero_id": "hero_veilmourn_jessa_keelwarden",
        "prefix": "fogkeel",
        "witness_flag": "sealed_companies_lastwatch_sounded",
        "witness_objective_id": "fogkeel_assemble_veterans",
        "hook_id": "sealed_companies_fogkeel_witness",
        "seal_stem": "fogkeel_bell_seal",
        "seal_id": "campaign_chapter_seal_keelwarden_fogkeel_veteran_muster",
        "rival_hero_id": "hero_mireclaw_edda_rotlamp",
        "label": "Chapter VI: Sound the Fog-Keel Lastwatch",
        "chapter_title": "Enter Six Companies in One Open Ledger",
        "description": "Jessa Keelwarden reopens Lastwatch Mooring, recalls its missing crews, and sounds the final bell over all six independently witnessed company seals.",
        "status_hint": "Defeat the three Mireclaw screens, claim Lastwatch Mooring, and assemble every required Veilmourn veteran before the final sounding.",
        "carryover_summary": "Imports only Selka's certificate and capped common stores; no prior commander, army, progression, spellbook, artifact, or rare claim enters Jessa's company.",
        "briefing": "Five seals reach the pale harbor while the last roll is being lowered into fog. Jessa must clear Fog-Keel Lastwatch, recall its boarders, reavers, and leviathan, then sound a bell that enters all six witnesses into one open ledger without making any company property of another.",
        "intel": "Mireclaw screens cover both harbor roads and the mooring guard. The final sounding requires the exact Veilmourn company and control of Lastwatch itself.",
        "stakes": "If the sixth roll vanishes, the circuit remains an unfinished chain that every hostile court can contest one seal at a time.",
        "aftermath_victory": "The pale bell sounds over six distinct seals, restoring every erased veteran company to the common frontier ledger.",
        "aftermath_defeat": "Lastwatch falls silent and the five recovered seals scatter without a final common entry.",
        "journal_victory": "Jessa sounded Fog-Keel Lastwatch and completed The Six Sealed Companies.",
        "journal_defeat": "Jessa failed to enter the six company seals into one open ledger.",
        "alt": "A pale sounding bell hangs above a hooked fog keel and torn white-blue sailcloth.",
    },
]


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_compact(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, separators=(",", ":")) + "\n", encoding="utf-8")


def write_pretty(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def upsert(items: list[dict], row: dict) -> None:
    for index, existing in enumerate(items):
        if existing.get("id") == row["id"]:
            items[index] = row
            return
    items.append(row)


def art_row(chapter: dict) -> dict:
    stem = chapter["seal_stem"]
    source_path = SOURCE_ROOT / "chapter_seals" / f"{stem}_source.png"
    runtime_path = RUNTIME_ROOT / "chapter_seals" / f"{stem}.png"
    return {
        "id": chapter["seal_id"],
        "role": "chapter_seal",
        "source_path": f"res://art/campaigns/source/generated/chapter_seals/{stem}_source.png",
        "runtime_path": f"res://art/campaigns/runtime/chapter_seals/{stem}.png",
        "source_sha256": digest(source_path),
        "runtime_sha256": digest(runtime_path),
        "non_color_identity": chapter["alt"],
    }


def campaign_chapter(index: int, chapter: dict) -> dict:
    stem = chapter["seal_stem"]
    row = {
        "scenario_id": chapter["scenario_id"],
        "seal_id": chapter["seal_id"],
        "seal_path": f"res://art/campaigns/runtime/chapter_seals/{stem}.png",
        "seal_source_path": f"res://art/campaigns/source/generated/chapter_seals/{stem}_source.png",
        "seal_alt_text": chapter["alt"],
        "seal_source_sha256": digest(SOURCE_ROOT / "chapter_seals" / f"{stem}_source.png"),
        "seal_runtime_sha256": digest(RUNTIME_ROOT / "chapter_seals" / f"{stem}.png"),
        "label": chapter["label"],
        "description": chapter["description"],
        "chapter_index": index + 1,
        "chapter_title": chapter["chapter_title"],
        "status_hint": chapter["status_hint"],
        "carryover_summary": chapter["carryover_summary"],
        "briefing": chapter["briefing"],
        "intel": chapter["intel"],
        "stakes": chapter["stakes"],
        "aftermath_victory": chapter["aftermath_victory"],
        "aftermath_defeat": chapter["aftermath_defeat"],
        "journal_victory": chapter["journal_victory"],
        "journal_defeat": chapter["journal_defeat"],
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
            "from_scenario_id": previous["scenario_id"],
            "resources": True,
            "hero_progression": False,
            "spells": False,
            "artifacts": False,
            "flags_prefix": "carryover_",
        }
    if index < len(CHAPTERS) - 1:
        row["carryover_export"] = {
            "retain_hero_progression": False,
            "retain_spells": False,
            "retain_artifacts": False,
            "resource_fraction": 0.12,
            "resource_caps": COMMON_CAPS,
            "flag_ids": [chapter["witness_flag"]],
        }
    return row


def main() -> None:
    campaigns_payload = load(CONTENT / "campaigns.json")
    scenarios_payload = load(CONTENT / "scenarios.json")
    scenarios = {row["id"]: row for row in scenarios_payload["items"]}

    for index, chapter in enumerate(CHAPTERS):
        scenario = scenarios[chapter["scenario_id"]]
        scenario["selection"]["availability"] = {"campaign": True, "skirmish": True}
        hooks = [row for row in scenario.get("script_hooks", []) if row.get("id") != chapter["hook_id"]]
        hooks.append({
            "id": chapter["hook_id"],
            "priority": 35,
            "conditions": [{"type": "objective_met", "objective_id": chapter["witness_objective_id"]}],
            "effects": [
                {"type": "set_flag", "flag": chapter["witness_flag"], "value": True},
                {"type": "message", "text": chapter["aftermath_victory"]},
            ],
        })
        scenario["script_hooks"] = hooks
        scenario["six_sealed_companies"] = {
            "campaign_id": CAMPAIGN_ID,
            "chapter_index": index + 1,
            "witness_flag": chapter["witness_flag"],
            "mechanic_objective_id": chapter["witness_objective_id"],
        }
        if chapter.get("rival_hero_id"):
            finale = next(row for row in scenario.get("encounters", []) if row.get("placement_id") == f"{chapter['prefix']}_muster_guard")
            finale["encounter_id"] = "encounter_rotlamp_spoor_court"
            finale["spawned_by_faction_id"] = "faction_mireclaw"
            finale["enemy_commander_state"] = {
                "roster_hero_id": chapter["rival_hero_id"],
                "faction_id": "faction_mireclaw",
            }

    emblem_source = SOURCE_ROOT / "emblems/six_sealed_companies_source.png"
    emblem_runtime = RUNTIME_ROOT / "emblems/six_sealed_companies.png"
    emblem_alt = "An open iron-bound muster ledger carries six materially distinct frontier seals around a deliberately empty central clasp."
    campaign = {
        "id": CAMPAIGN_ID,
        "name": "The Six Sealed Companies",
        "description": "Six commanders reopen six erased veteran rolls and pass their independently witnessed company seals around the frontier until one open ledger can recognize them all without owning any of them.",
        "summary": "A six-chapter cross-faction campaign about restoring every missing veteran company through guarded musters, exact rosters, and bounded witness handoff.",
        "region": "The Lastwatch Muster Circuit",
        "emblem_id": "campaign_emblem_six_sealed_companies",
        "emblem_path": "res://art/campaigns/runtime/emblems/six_sealed_companies.png",
        "emblem_source_path": "res://art/campaigns/source/generated/emblems/six_sealed_companies_source.png",
        "emblem_alt_text": emblem_alt,
        "emblem_source_sha256": digest(emblem_source),
        "emblem_runtime_sha256": digest(emblem_runtime),
        "arc_goal": "Recover six guarded veteran grounds, assemble every erased production company, and enter six independent muster seals into one common ledger without carrying commander power between chapters.",
        "completion_title": "Every Company Answers the Roll",
        "completion_summary": "The Lastwatch bell has entered six independently recovered companies into one open frontier ledger; all eighteen missing veteran identities now have both a live muster and a shared campaign history.",
        "starting_scenario_id": CHAPTERS[0]["scenario_id"],
        "scenarios": [campaign_chapter(index, chapter) for index, chapter in enumerate(CHAPTERS)],
        "content_batch_id": SLICE_ID,
        "content_status": "six_sealed_companies_campaign_live",
    }
    upsert(campaigns_payload["items"], campaign)
    campaigns_payload["player_facing_active_campaign_count"] = len(campaigns_payload["items"])
    campaigns_payload["reactivation_reason"] = "six_sealed_companies_campaign_2026_08_31"

    emblem_art = {
        "id": "campaign_emblem_six_sealed_companies",
        "role": "campaign_emblem",
        "source_path": "res://art/campaigns/source/generated/emblems/six_sealed_companies_source.png",
        "runtime_path": "res://art/campaigns/runtime/emblems/six_sealed_companies.png",
        "source_sha256": digest(emblem_source),
        "runtime_sha256": digest(emblem_runtime),
        "non_color_identity": emblem_alt,
    }
    source_manifest = {
        "schema_id": "six_sealed_companies_campaign_art_v1",
        "content_batch_id": SLICE_ID,
        "generator_mode": "built_in_image_gen",
        "generated_at": "2026-08-31",
        "campaign_id": CAMPAIGN_ID,
        "identity_sheet": "res://art/campaigns/source/generated/six_sealed_companies/six_sealed_companies_identity_sheet.png",
        "identity_sheet_sha256": digest(SOURCE_DIR / "six_sealed_companies_identity_sheet.png"),
        "final_prompt": "Original transparent identity sheet for The Six Sealed Companies: an open iron-bound muster ledger encircled by six materially distinct seals, plus isolated ash-charter, fen-chain, daybreak-prism, five-bough, three-gauge, and fog-keel chapter motifs; strong non-color silhouettes, no text, logos, franchise symbols, or scenery.",
        "runtime_pipeline": "The transparent 1536x1024 source sheet is cropped into one 512px emblem master and six 384px chapter masters, then Lanczos-downscaled to one 128px emblem and six 64px seals. Generated source masters remain outside release packages.",
        "generated_original": "/root/.codex/generated_images/019fe72a-30b1-76f3-b911-385c4444bd16/exec-c8d7979e-fde1-4f2b-8300-8d2c2ec171e7.png",
        "assets": [emblem_art, *[art_row(chapter) for chapter in CHAPTERS]],
    }

    write_compact(CONTENT / "campaigns.json", campaigns_payload)
    write_compact(CONTENT / "scenarios.json", scenarios_payload)
    write_pretty(SOURCE_DIR / "manifest.json", source_manifest)
    print(json.dumps({
        "campaign_id": CAMPAIGN_ID,
        "campaign_count": len(campaigns_payload["items"]),
        "chapter_count": len(CHAPTERS),
        "campaign_enabled_scenario_count": sum(1 for row in scenarios_payload["items"] if row.get("selection", {}).get("availability", {}).get("campaign") is True),
        "art_identity_count": len(source_manifest["assets"]),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
