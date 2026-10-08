#!/usr/bin/env python3
"""Author The Charterless Compact campaign and its exact art provenance."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
SOURCE_ROOT = ROOT / "art/campaigns/source/generated"
RUNTIME_ROOT = ROOT / "art/campaigns/runtime"
SOURCE_DIR = SOURCE_ROOT / "charterless_compact"
CAMPAIGN_ID = "campaign_charterless_compact"
SLICE_ID = "content-charterless-compact-campaign-10184"

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
        "scenario_id": "tidehook-reedwake-commission",
        "hero_id": "hero_veilmourn_olan_tidehook",
        "witness_flag": "charterless_reedwake_noted",
        "witness_objective_id": "tidehook_record",
        "hook_id": "charterless_reedwake_witness",
        "seal_stem": "reedwake_blank_slate",
        "seal_id": "campaign_chapter_seal_tidehook_reedwake_commission",
        "label": "Chapter I: Lift the Blank Slate",
        "chapter_title": "Record a Command Without Patronage",
        "description": "Olan Tidehook opens a field ledger that no court has signed by breaking Reedwake's commission line and taking its hostile mooring.",
        "status_hint": "Break the Reedwake commission, claim the opposing town, and record the first charterless witness.",
        "carryover_summary": "Exports only a capped share of common stores and Olan's blank-slate witness; his army, growth, spellbook, artifacts, and rare stores remain local.",
        "briefing": "A waterlogged slate reaches Olan with every patron's seal scraped away. Reedwake's collectors call it invalid. He must defeat their commission, take the hostile mooring, and prove a command can enter the record without inheriting a court's authority.",
        "intel": "Three field fronts protect the commission road; the central writ must fall before the blank slate can be entered into the ledger.",
        "stakes": "If the first witness is bought by a patron, every later chapter will be another private order disguised as common law.",
        "aftermath_victory": "Olan lifts the first blank slate from Reedwake and sends it inland with no patron's mark attached.",
        "aftermath_defeat": "The collectors sink the unsigned slate and restore Reedwake's old chain of custody.",
        "journal_victory": "Olan entered Reedwake as the first charterless witness.",
        "journal_defeat": "Olan failed to establish an unsigned field record.",
        "alt": "A crescent tide hook carries a blank slate above one sharply curling dark wave.",
    },
    {
        "scenario_id": "blackgauge-double-assay",
        "hero_id": "hero_brasshollow_kestra_blackgauge",
        "witness_flag": "charterless_double_assay_proven",
        "witness_objective_id": "gaugevigil_survive_day_twelve",
        "hook_id": "charterless_double_assay_witness",
        "seal_stem": "double_assay_witness",
        "seal_id": "campaign_chapter_seal_blackgauge_double_assay",
        "label": "Chapter II: Hold the Double Assay",
        "chapter_title": "Make the Record Survive Pressure",
        "description": "Kestra Blackgauge subjects the unsigned witness to two defended holds and twelve days of measured pressure.",
        "status_hint": "Keep both assay holds, break all three fronts, and survive through Day 12.",
        "carryover_summary": "Imports only Olan's witness and capped common stores, then exports Kestra's pressure proof without transferring either commander.",
        "briefing": "An unsigned record is easy to dismiss as soft metal. Kestra must hold both assay towns, break the three pressure fronts, and keep the slate intact until the twelfth-day reading proves it cannot be bent by siege or debt.",
        "intel": "The assay is a timed defense: both holds and all three hostile fronts must remain settled when the final gauge is read.",
        "stakes": "A witness that fails under pressure will be rewritten by the first court rich enough to squeeze it.",
        "aftermath_victory": "Both gauges return true, and Kestra stamps the blank slate with a pressure proof rather than a proprietor's seal.",
        "aftermath_defeat": "One assay buckles, letting the old ledgers call the charterless witness counterfeit.",
        "journal_victory": "Kestra proved the second witness across the Double Assay.",
        "journal_defeat": "Kestra failed to keep the unsigned record true under pressure.",
        "alt": "A double assay gauge balances between two unequal angular anvils on one central iron standard.",
    },
    {
        "scenario_id": "sevenfold-meridian-three-prism-garrison-warrant",
        "hero_id": "hero_sunvault_aven_sevenfold",
        "witness_flag": "charterless_meridian_garrison_recorded",
        "witness_objective_id": "meridianwarrant_stock_garrison",
        "hook_id": "charterless_meridian_garrison_witness",
        "seal_stem": "three_prism_warrant",
        "seal_id": "campaign_chapter_seal_sevenfold_meridian_three_prism_garrison_warrant",
        "label": "Chapter III: Staff the Three Prisms",
        "chapter_title": "Turn Proof Into a Defensible Order",
        "description": "Aven Sevenfold converts the pressure-tested slate into an exact garrison warrant and deliberately staffs Meridian's three companies.",
        "status_hint": "Recover all three warrant companies, transfer the exact required stacks into Meridian, and clear their guards.",
        "carryover_summary": "Imports capped stores and Kestra's proof, then exports only Aven's exact garrison measure; no army or personal state crosses chapters.",
        "briefing": "Proof alone cannot hold a gate. Aven must recover three separated warrant companies, carry them home, and place their exact strengths into Meridian's garrison so the common record becomes an order that can be checked and defended.",
        "intel": "The warrant recruits enter Aven's field army first; victory requires deliberate town-stack transfers into the specified home garrison.",
        "stakes": "If the compact cannot name who holds the wall and in what strength, its independence will collapse at the first night alarm.",
        "aftermath_victory": "Three prisms agree on the same garrison measure, giving the charterless record an exact defensive clause.",
        "aftermath_defeat": "The companies remain scattered and the unsigned record proves unable to hold a single gate.",
        "journal_victory": "Aven entered the Three-Prism garrison measure as the third witness.",
        "journal_defeat": "Aven failed to turn the compact's proof into a defensible order.",
        "alt": "Three differently sized pale prisms rise behind a compact iron-banded wooden gate bar.",
    },
    {
        "scenario_id": "reedcaller-fenhound-pursuit-assembly",
        "hero_id": "hero_mireclaw_rhask_reedcaller",
        "witness_flag": "charterless_fenhound_regalia_witnessed",
        "witness_objective_id": "fenhoundassembly_equip_set",
        "hook_id": "charterless_fenhound_regalia_witness",
        "seal_stem": "fenhound_regalia",
        "seal_id": "campaign_chapter_seal_reedcaller_fenhound_pursuit_assembly",
        "label": "Chapter IV: Wear the Fenhound Witness",
        "chapter_title": "Bind Authority to a Responsible Bearer",
        "description": "Rhask Reedcaller recovers and equips the complete Fenhound Pursuit regalia without allowing the inherited pieces to replace his own command.",
        "status_hint": "Win the three guardian battles, recover all set pieces, and equip the complete Fenhound Pursuit regalia.",
        "carryover_summary": "Imports only Aven's measure and capped stores, then exports Rhask's regalia witness while every equipped piece remains in its home chapter.",
        "briefing": "A defensible order still needs a bearer the frontier can recognize. Rhask must recover the Fenhound Pursuit pieces, equip the complete regalia, and show that visible authority can answer to the compact without becoming inherited ownership.",
        "intel": "Two pieces lie behind field guards and the last comes from the guarded reliquary; inventory possession is insufficient until the full set is equipped.",
        "stakes": "If regalia owns the bearer instead of identifying responsibility, the compact will become another hereditary chain.",
        "aftermath_victory": "Rhask wears all three pieces, gives the compact a visible witness, then leaves the regalia with Fenhound rather than carrying it onward.",
        "aftermath_defeat": "The scattered regalia becomes proof that the compact cannot bind authority to accountable command.",
        "journal_victory": "Rhask added the equipped Fenhound witness without exporting its power.",
        "journal_defeat": "Rhask failed to assemble a responsible bearer for the compact.",
        "alt": "A long-eared fenhound mask grips three materially different regalia tokens in an open jaw ring.",
    },
    {
        "scenario_id": "boltroot-briarwheel-border-oath-seizure",
        "hero_id": "hero_thornwake_bryn_boltroot",
        "witness_flag": "charterless_briarwheel_standards_entered",
        "witness_objective_id": "threeseed_three_standard_oath",
        "hook_id": "charterless_briarwheel_standard_witness",
        "seal_stem": "rooted_standard",
        "seal_id": "campaign_chapter_seal_boltroot_briarwheel_border_oath_seizure",
        "label": "Chapter V: Root the Border Standards",
        "chapter_title": "Give the Compact Ground Without Giving It a Master",
        "description": "Bryn Boltroot clears three cordons and turns three separated standards into one rooted frontier witness.",
        "status_hint": "Break all three border cordons, control the three standards, and keep Briarwheel under player command.",
        "carryover_summary": "Imports Rhask's witness and capped stores, then exports only Bryn's rooted standard record; all heroes, armies, artifacts, and rare stores remain isolated.",
        "briefing": "Four witnesses can still be dismissed as traveling words. Bryn must clear the three cordons, hold Briarwheel, and root three standards far enough apart that no single banner can pretend to own the ground between them.",
        "intel": "Each standard is guarded by a distinct cordon and all three control positions are required alongside the home-town hold.",
        "stakes": "Without ground, the compact can be honored in every hall and ignored on every road.",
        "aftermath_victory": "Three standards take root without merging into one crown, and Bryn sends their common bearing toward the Tollmoon road.",
        "aftermath_defeat": "The cordons close and the compact remains a promise with nowhere to stand.",
        "journal_victory": "Bryn rooted the fifth charterless witness across Briarwheel's border.",
        "journal_defeat": "Bryn failed to give the compact independent ground.",
        "alt": "A rooted crossbow bolt supports a forked cloth standard whose two unequal wings remain visibly separate.",
    },
    {
        "scenario_id": "powderwrit-tollreaver-rival-banner-challenge",
        "hero_id": "hero_embercourt_maela_powderwrit",
        "witness_flag": "charterless_tollmoon_charter_sealed",
        "witness_objective_id": "tollmoon_defeat_named_rival",
        "hook_id": "charterless_tollmoon_final_witness",
        "seal_stem": "tollmoon_final_charter",
        "seal_id": "campaign_chapter_seal_powderwrit_tollreaver_rival_banner_challenge",
        "label": "Chapter VI: Seal the Tollmoon Compact",
        "chapter_title": "Defend the Common Record Against a Named Claim",
        "description": "Maela Powderwrit carries five witnesses into Orrik Tollreaver's command line, turns all three banners, and defeats the rival claimant in person.",
        "status_hint": "Break the approach companies, control all three command banners, capture the rival town, and defeat Orrik Tollreaver.",
        "carryover_summary": "Imports only Bryn's witness and capped common stores; no prior commander power enters Maela's final company.",
        "briefing": "The five witnesses reach Tollmoon just as Orrik Tollreaver names the entire compact an unpaid claim. Maela must break his approach companies, turn all three command banners, take the rival town, and defeat the named claimant without borrowing authority from any earlier hero.",
        "intel": "The final route combines three persistent control positions, an enemy-town capture, two approach battles, and Orrik's roster-backed rival company.",
        "stakes": "If a named claimant can seize the ledger at its final hearing, six independent proofs will become one more toll schedule.",
        "aftermath_victory": "Maela crosses powder quill and Tollmoon hook over six independent witnesses, sealing a compact no patron owns.",
        "aftermath_defeat": "Orrik enters the six witnesses as collateral and closes the frontier ledger under his own name.",
        "journal_victory": "Maela defeated Orrik and sealed The Charterless Compact.",
        "journal_defeat": "Maela failed to defend the common record against its final named claim.",
        "alt": "A dark powder quill crosses a crescent toll hook beneath one narrow two-tailed field pennant.",
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
    row = {
        "scenario_id": chapter["scenario_id"],
        "seal_id": chapter["seal_id"],
        "seal_path": f"res://art/campaigns/runtime/chapter_seals/{chapter['seal_stem']}.png",
        "seal_source_path": f"res://art/campaigns/source/generated/chapter_seals/{chapter['seal_stem']}_source.png",
        "seal_alt_text": chapter["alt"],
        "seal_source_sha256": digest(SOURCE_ROOT / "chapter_seals" / f"{chapter['seal_stem']}_source.png"),
        "seal_runtime_sha256": digest(RUNTIME_ROOT / "chapter_seals" / f"{chapter['seal_stem']}.png"),
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

    for chapter in CHAPTERS:
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
        scenario["charterless_compact"] = {
            "campaign_id": CAMPAIGN_ID,
            "chapter_index": CHAPTERS.index(chapter) + 1,
            "witness_flag": chapter["witness_flag"],
            "mechanic_objective_id": chapter["witness_objective_id"],
        }

    emblem_source = SOURCE_ROOT / "emblems/charterless_compact_source.png"
    emblem_runtime = RUNTIME_ROOT / "emblems/charterless_compact.png"
    campaign = {
        "id": CAMPAIGN_ID,
        "name": "The Charterless Compact",
        "description": "Six commanders excluded from every patron's field charter pass one unsigned ledger through six different trials until it can stand as common frontier law.",
        "summary": "A six-chapter anthology campaign joining six factions and six production mechanics through bounded witness handoff and isolated command.",
        "region": "The Unsigned Frontier Circuit",
        "emblem_id": "campaign_emblem_charterless_compact",
        "emblem_path": "res://art/campaigns/runtime/emblems/charterless_compact.png",
        "emblem_source_path": "res://art/campaigns/source/generated/emblems/charterless_compact_source.png",
        "emblem_alt_text": "An open weathered field ledger is encircled by six materially different witness tabs while its center remains deliberately unsigned.",
        "emblem_source_sha256": digest(emblem_source),
        "emblem_runtime_sha256": digest(emblem_runtime),
        "arc_goal": "Prove an unsigned frontier record through commission, defense, garrison, regalia, territorial control, and named opposition without transferring personal command between its six witnesses.",
        "completion_title": "The Ledger Answers to No Patron",
        "completion_summary": "Six commanders have entered six independent proofs into one field compact whose resources can be shared but whose heroes, armies, artifacts, spells, and rare claims remain their own.",
        "starting_scenario_id": CHAPTERS[0]["scenario_id"],
        "scenarios": [campaign_chapter(index, chapter) for index, chapter in enumerate(CHAPTERS)],
        "content_batch_id": SLICE_ID,
        "content_status": "charterless_compact_campaign_live",
    }
    upsert(campaigns_payload["items"], campaign)
    campaigns_payload["player_facing_active_campaign_count"] = len(campaigns_payload["items"])
    campaigns_payload["reactivation_reason"] = "charterless_compact_campaign_2026_08_31"

    emblem_art = {
        "id": "campaign_emblem_charterless_compact",
        "role": "campaign_emblem",
        "source_path": "res://art/campaigns/source/generated/emblems/charterless_compact_source.png",
        "runtime_path": "res://art/campaigns/runtime/emblems/charterless_compact.png",
        "source_sha256": digest(emblem_source),
        "runtime_sha256": digest(emblem_runtime),
        "non_color_identity": campaign["emblem_alt_text"],
    }
    source_manifest = {
        "schema_id": "charterless_compact_campaign_art_v1",
        "content_batch_id": SLICE_ID,
        "generator_mode": "built_in_image_gen",
        "generated_at": "2026-08-31",
        "campaign_id": CAMPAIGN_ID,
        "identity_sheet": "res://art/campaigns/source/generated/charterless_compact/charterless_compact_identity_sheet.png",
        "identity_sheet_sha256": digest(SOURCE_DIR / "charterless_compact_identity_sheet.png"),
        "final_prompt": "Original seven-insignia identity sheet for The Charterless Compact: an open field ledger with six witness tabs, tide hook and blank slate, double assay and anvils, three-prism gate warrant, fenhound mask with regalia, rooted bolt standard, and powder quill crossing a Tollmoon hook; exact 3x3 layout with two empty cells, distinct non-color silhouettes, no text or franchise symbols, genuine transparency.",
        "runtime_pipeline": "The exact 1275x1233 transparent sheet is divided into seven occupied 425x411 cells; the emblem is trimmed, Lanczos-downscaled, and centered on a 128px RGBA canvas, while six chapter seals are centered on 64px RGBA canvases. Source masters remain outside release packages.",
        "generated_original": "/root/.codex/generated_images/019fe72a-30b1-76f3-b911-385c4444bd16/exec-a4126a00-be5e-4bb5-9099-6dfa5d082957.png",
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
