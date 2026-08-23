#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
UNITS_PATH = ROOT / "content" / "units.json"
MANIFEST_PATH = ROOT / "content" / "unit_art_manifest.json"
ANIMATION_MANIFEST_PATH = ROOT / "content" / "unit_animation_manifest.json"
ART_ROOT = ROOT / "art" / "units"
ANIMATION_ROOT = ROOT / "art" / "animation" / "runtime" / "units"
CURATED_SOURCE_ROOT = ART_ROOT / "source" / "curated"
CURATED_CHARACTER_SOURCE_IDS = {
    "unit_aurora_ballista",
    "unit_blackbranch_cutthroat",
    "unit_bog_brute",
    "unit_brasshollow_boiler_rivetcasters",
    "unit_brasshollow_crucible_crawlers",
    "unit_brasshollow_debt_engine_exactors",
    "unit_brasshollow_foundry_saint",
    "unit_brasshollow_furnace_pavis_teams",
    "unit_brasshollow_rivet_hounds",
    "unit_brasshollow_scrip_haulers",
    "unit_citadel_pikeward",
    "unit_ember_archer",
    "unit_embercourt_ash_oath_bailiffs",
    "unit_embercourt_bargebow_crews",
    "unit_embercourt_beacon_lectors",
    "unit_embercourt_charter_colossus",
    "unit_embercourt_fordhook_cadets",
    "unit_embercourt_lantern_sappers",
    "unit_embercourt_sluicefire_lindworms",
    "unit_gorefen_ripper",
    "unit_mire_slinger",
    "unit_mireclaw_bogplate_maulers",
    "unit_mireclaw_drowned_antler_sovereign",
    "unit_mireclaw_ferrychain_lashers",
    "unit_mireclaw_gorefen_rippers",
    "unit_mireclaw_mudglass_slingers",
    "unit_mireclaw_reedsnare_kin",
    "unit_mireclaw_sporewake_chanters",
    "unit_mirror_duelist",
    "unit_neutral_ashdart_stalkers",
    "unit_neutral_basalt_wardens",
    "unit_neutral_bogbell_mauls",
    "unit_neutral_cairnshield_porters",
    "unit_neutral_charcoal_mauls",
    "unit_neutral_cinderpot_hurlers",
    "unit_neutral_cliffhawk_wardens",
    "unit_neutral_dustjack_blades",
    "unit_neutral_echodart_casts",
    "unit_neutral_emberpack_lobbers",
    "unit_neutral_fenhound_runners",
    "unit_neutral_frostbeacon_pikes",
    "unit_neutral_glimmercap_needlers",
    "unit_neutral_glowcap_bulwarks",
    "unit_neutral_greenbranch_cudgels",
    "unit_neutral_hearthbow_carriers",
    "unit_neutral_hedgehook_watch",
    "unit_neutral_icehook_trappers",
    "unit_neutral_kitehook_runners",
    "unit_neutral_kilnward_mallets",
    "unit_neutral_lanternet_throwers",
    "unit_neutral_millstone_slingers",
    "unit_neutral_mossglass_sentinels",
    "unit_neutral_orchard_halberds",
    "unit_neutral_peatflare_jarriers",
    "unit_neutral_reedbarge_poles",
    "unit_neutral_reefbolt_crews",
    "unit_neutral_ridgeflare_shots",
    "unit_neutral_roadwardens",
    "unit_neutral_saltpan_bucklers",
    "unit_neutral_scarshield_veterans",
    "unit_neutral_sapwhistle_callers",
    "unit_neutral_scrapbow_teams",
    "unit_neutral_snowglass_markers",
    "unit_neutral_sporelamp_tossers",
    "unit_neutral_switchback_pikes",
    "unit_neutral_sumpstone_guards",
    "unit_neutral_suncrack_throwers",
    "unit_neutral_thornbow_scouts",
    "unit_neutral_tidepool_cutters",
    "unit_neutral_tunnel_lanterns",
    "unit_neutral_tunnelmark_bolters",
    "unit_neutral_whitepike_keepers",
    "unit_neutral_windglass_slingers",
    "unit_prism_adept",
    "unit_river_guard",
    "unit_shard_guard",
    "unit_sunvault_aurora_ballistae",
    "unit_sunvault_daybreak_colossus",
    "unit_sunvault_mirror_duelists",
    "unit_sunvault_prism_adepts",
    "unit_sunvault_resonant_choristers",
    "unit_sunvault_shard_wardens",
    "unit_sunvault_solar_array_striders",
    "unit_thornwake_barkmantle_rams",
    "unit_thornwake_graft_matriarchs",
    "unit_thornwake_seedcutters",
    "unit_thornwake_sporeglass_menders",
    "unit_thornwake_stagknot_runners",
    "unit_thornwake_thornwhip_carriers",
    "unit_thornwake_worldroot_bastion",
    "unit_veilmourn_bellwake_oars",
    "unit_veilmourn_fogbound_leviathan",
    "unit_veilmourn_maskglass_corsairs",
    "unit_veilmourn_mirrorkeel_reavers",
    "unit_veilmourn_mourning_lanterns",
    "unit_veilmourn_obituary_scribes",
    "unit_veilmourn_undertow_harpooners",
}
PRESERVED_AUTHORED_ASSET_SHA256 = {}

PORTRAIT_SIZE = (384, 512)
BATTLE_ICON_SIZE = (160, 160)
OVERWORLD_ICON_SIZE = (96, 96)
ANIMATION_FRAME_SIZE = (64, 64)
ANIMATION_FRAMES_PER_STATE = 4
BATTLE_TROOP_ANIMATION_STATES = [
    {"event_id": "battle_stack_idle", "family": "idle", "state": "idle_hold"},
    {"event_id": "battle_stack_ready", "family": "ready", "state": "ready_active"},
    {"event_id": "battle_unit_move", "family": "move", "state": "move_path_step"},
    {"event_id": "battle_unit_melee_attack", "family": "attack", "state": "melee_windup_release"},
    {"event_id": "battle_unit_ranged_attack", "family": "attack", "state": "ranged_aim_release"},
    {"event_id": "battle_unit_hit", "family": "hit", "state": "hit_stagger"},
    {"event_id": "battle_unit_death", "family": "death", "state": "death_rout_remove"},
    {"event_id": "battle_unit_cast", "family": "cast", "state": "cast_support_anchor"},
    {"event_id": "battle_status_applied", "family": "status", "state": "status_applied"},
    {"event_id": "battle_status_expired", "family": "status", "state": "status_expired"},
    {"event_id": "battle_unit_defend", "family": "defend", "state": "defend_brace"},
    {"event_id": "battle_retaliation", "family": "attack", "state": "retaliation_release"},
    {"event_id": "battle_unit_retreat", "family": "retreat", "state": "retreat_withdraw_column"},
    {"event_id": "battle_unit_surrender", "family": "surrender", "state": "surrender_stand_down"},
]

PALETTES = {
    "faction_embercourt": {
        "primary": (191, 73, 40),
        "secondary": (239, 164, 65),
        "shadow": (57, 32, 24),
        "metal": (238, 203, 129),
    },
    "faction_mireclaw": {
        "primary": (69, 121, 62),
        "secondary": (151, 105, 54),
        "shadow": (22, 44, 35),
        "metal": (168, 202, 145),
    },
    "faction_sunvault": {
        "primary": (213, 180, 66),
        "secondary": (109, 139, 219),
        "shadow": (43, 45, 75),
        "metal": (245, 235, 165),
    },
    "faction_thornwake": {
        "primary": (74, 129, 67),
        "secondary": (146, 92, 55),
        "shadow": (25, 50, 29),
        "metal": (179, 214, 134),
    },
    "faction_brasshollow": {
        "primary": (184, 128, 54),
        "secondary": (106, 112, 116),
        "shadow": (45, 36, 31),
        "metal": (228, 185, 94),
    },
    "faction_veilmourn": {
        "primary": (73, 102, 135),
        "secondary": (81, 151, 160),
        "shadow": (24, 31, 48),
        "metal": (177, 204, 211),
    },
    "neutral": {
        "primary": (130, 141, 122),
        "secondary": (184, 145, 83),
        "shadow": (42, 45, 41),
        "metal": (210, 197, 151),
    },
}


def main() -> int:
    units = json.loads(UNITS_PATH.read_text(encoding="utf-8")).get("items", [])
    for subdir in ("portraits", "battle_icons", "overworld_icons"):
        (ART_ROOT / subdir).mkdir(parents=True, exist_ok=True)
    ANIMATION_ROOT.mkdir(parents=True, exist_ok=True)

    manifest = {
        "schema_version": 1,
        "generator": "deterministic_unit_art_assets_v1",
        "source": "content/units.json",
        "surface_sizes": {
            "portrait": {"width": PORTRAIT_SIZE[0], "height": PORTRAIT_SIZE[1]},
            "battle_icon": {"width": BATTLE_ICON_SIZE[0], "height": BATTLE_ICON_SIZE[1]},
            "overworld_icon": {"width": OVERWORLD_ICON_SIZE[0], "height": OVERWORLD_ICON_SIZE[1]},
        },
        "items": [],
    }
    animation_manifest = {
        "schema_id": "unit_animation_manifest_v1",
        "generator": "deterministic_unit_animation_assets_v1",
        "source": "content/units.json",
        "surface": "battle_troop_sprite_sheet",
        "frame_size": {"width": ANIMATION_FRAME_SIZE[0], "height": ANIMATION_FRAME_SIZE[1]},
        "frames_per_state": ANIMATION_FRAMES_PER_STATE,
        "sheet_size": {
            "width": ANIMATION_FRAME_SIZE[0] * ANIMATION_FRAMES_PER_STATE,
            "height": ANIMATION_FRAME_SIZE[1] * len(BATTLE_TROOP_ANIMATION_STATES),
        },
        "states": BATTLE_TROOP_ANIMATION_STATES,
        "items": [],
    }

    for unit in units:
        unit_id = str(unit["id"])
        faction_key = str(unit.get("faction_id") or unit.get("affiliation") or "neutral")
        if faction_key == "":
            faction_key = "neutral"
        palette = PALETTES.get(faction_key, PALETTES["neutral"])
        motif = motif_for_unit(unit)
        initials = initials_for(str(unit.get("name", unit_id)))
        portrait_path = ART_ROOT / "portraits" / f"{unit_id}.png"
        battle_path = ART_ROOT / "battle_icons" / f"{unit_id}.png"
        overworld_path = ART_ROOT / "overworld_icons" / f"{unit_id}.png"
        animation_path = ANIMATION_ROOT / f"{unit_id}.png"

        curated_source = load_curated_character_source(unit_id)
        if not preserve_authored_asset(unit_id, "portrait", portrait_path):
            if curated_source is None:
                draw_portrait(unit, palette, motif, initials, portrait_path)
            else:
                draw_curated_portrait(unit, palette, curated_source, portrait_path)
        if not preserve_authored_asset(unit_id, "battle_icon", battle_path):
            if curated_source is None:
                draw_battle_icon(unit, palette, motif, initials, battle_path)
            else:
                draw_curated_battle_icon(unit, palette, curated_source, battle_path)
        if not preserve_authored_asset(unit_id, "overworld_icon", overworld_path):
            if curated_source is None:
                draw_overworld_icon(unit, palette, motif, initials, overworld_path)
            else:
                draw_curated_overworld_icon(unit, palette, curated_source, overworld_path)
        if not preserve_authored_asset(unit_id, "battle_animation_sheet", animation_path):
            if curated_source is None:
                draw_battle_troop_animation_sheet(unit, palette, motif, initials, animation_path)
            else:
                draw_curated_battle_troop_animation_sheet(unit, palette, curated_source, animation_path)

        art_record = {
            "id": unit_id,
            "unit_id": unit_id,
            "name": str(unit.get("name", unit_id)),
            "faction_id": faction_key,
            "tier": int(unit.get("tier", 1)),
            "role": str(unit.get("role", "")),
            "motif": motif,
            "portrait": to_res_path(portrait_path),
            "battle_icon": to_res_path(battle_path),
            "overworld_icon": to_res_path(overworld_path),
        }
        animation_record = {
            "id": unit_id,
            "unit_id": unit_id,
            "name": str(unit.get("name", unit_id)),
            "faction_id": faction_key,
            "tier": int(unit.get("tier", 1)),
            "role": str(unit.get("role", "")),
            "motif": motif,
            "sprite_sheet": to_res_path(animation_path),
            "states": [state["state"] for state in BATTLE_TROOP_ANIMATION_STATES],
        }
        provenance = curated_source_provenance(unit_id)
        if provenance:
            art_record.update(provenance)
            animation_record.update(provenance)
        manifest["items"].append(art_record)
        animation_manifest["items"].append(animation_record)

    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2, sort_keys=False) + "\n", encoding="utf-8")
    ANIMATION_MANIFEST_PATH.write_text(json.dumps(animation_manifest, indent=2, sort_keys=False) + "\n", encoding="utf-8")
    print(f"generated {len(units)} unit art records into {ART_ROOT.relative_to(ROOT)}")
    print(f"generated {len(units)} unit animation records into {ANIMATION_ROOT.relative_to(ROOT)}")
    return 0


def to_res_path(path: Path) -> str:
    return "res://" + path.relative_to(ROOT).as_posix()


def curated_character_source_path(unit_id: str) -> Path | None:
    if unit_id not in CURATED_CHARACTER_SOURCE_IDS:
        return None
    return CURATED_SOURCE_ROOT / f"{unit_id}.png"


def load_curated_character_source(unit_id: str) -> Image.Image | None:
    source_path = curated_character_source_path(unit_id)
    if source_path is None:
        return None
    if not source_path.exists():
        raise FileNotFoundError(f"Curated character source is missing for {unit_id}: {source_path}")
    source = Image.open(source_path).convert("RGBA")
    if source.size != (512, 512):
        raise ValueError(f"Curated character source for {unit_id} must be 512x512, got {source.size}")
    alpha = source.getchannel("A")
    if alpha.getbbox() is None or alpha.getextrema() != (0, 255):
        raise ValueError(f"Curated character source for {unit_id} must contain transparent and opaque pixels")
    return source


def curated_source_provenance(unit_id: str) -> dict[str, str]:
    source_path = curated_character_source_path(unit_id)
    if source_path is None:
        return {}
    return {
        "art_source_kind": "curated_original_character_v1",
        "curated_source": to_res_path(source_path),
        "curated_source_sha256": hashlib.sha256(source_path.read_bytes()).hexdigest(),
    }


def preserve_authored_asset(unit_id: str, surface: str, destination: Path) -> bool:
    expected_hash = PRESERVED_AUTHORED_ASSET_SHA256.get((unit_id, surface), "")
    if expected_hash == "":
        return False
    source = runtime_asset_path(unit_id, surface)
    if not source.exists():
        raise FileNotFoundError(f"Preserved authored asset is missing for {unit_id} {surface}: {source}")
    payload = source.read_bytes()
    actual_hash = hashlib.sha256(payload).hexdigest()
    if actual_hash != expected_hash:
        raise ValueError(
            f"Preserved authored asset hash drifted for {unit_id} {surface}: "
            f"expected {expected_hash}, got {actual_hash}"
        )
    if destination.resolve() != source.resolve():
        destination.write_bytes(payload)
    return True


def runtime_asset_path(unit_id: str, surface: str) -> Path:
    if surface == "portrait":
        return ART_ROOT / "portraits" / f"{unit_id}.png"
    if surface == "battle_icon":
        return ART_ROOT / "battle_icons" / f"{unit_id}.png"
    if surface == "overworld_icon":
        return ART_ROOT / "overworld_icons" / f"{unit_id}.png"
    if surface == "battle_animation_sheet":
        return ANIMATION_ROOT / f"{unit_id}.png"
    raise ValueError(f"Unknown unit art surface: {surface}")


def motif_for_unit(unit: dict) -> str:
    name = f"{unit.get('id', '')} {unit.get('name', '')}".lower()
    role = str(unit.get("role", "")).lower()
    ranged = bool(unit.get("ranged", False)) or role == "ranged"
    if any(token in name for token in ("ballista", "engine", "colossus", "crawler", "array")):
        return "engine"
    if any(token in name for token in ("hound", "runner", "lindworm", "leviathan", "antler", "ripper")):
        return "beast"
    if any(token in name for token in ("adept", "lector", "chanter", "scribe", "mender", "caller", "sovereign", "saint")):
        return "caster"
    if ranged or any(token in name for token in ("archer", "slinger", "bow", "bolt", "thrower", "shot", "dart", "hurl")):
        return "ranged"
    if any(token in name for token in ("guard", "warden", "pike", "pole", "halberd", "shield", "pavis", "buckler")):
        return "shield"
    if any(token in name for token in ("duelist", "blade", "cutter", "corsair", "cutthroat", "lash")):
        return "blade"
    return "melee"


def initials_for(name: str) -> str:
    parts = [part for part in name.replace("-", " ").split() if part]
    if not parts:
        return "U"
    if len(parts) == 1:
        return parts[0][:2].upper()
    return (parts[0][0] + parts[-1][0]).upper()


def hash_int(value: str) -> int:
    return int(hashlib.sha256(value.encode("utf-8")).hexdigest()[:12], 16)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
    ]
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size=size)
    return ImageFont.load_default()


def scale_color(color: tuple[int, int, int], factor: float) -> tuple[int, int, int]:
    return tuple(max(0, min(255, int(channel * factor))) for channel in color)


def with_alpha(color: tuple[int, int, int], alpha: int) -> tuple[int, int, int, int]:
    return (color[0], color[1], color[2], alpha)


def canvas(size: tuple[int, int]) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    return image, ImageDraw.Draw(image, "RGBA")


def draw_gradient(draw: ImageDraw.ImageDraw, size: tuple[int, int], top: tuple[int, int, int], bottom: tuple[int, int, int]) -> None:
    width, height = size
    for y in range(height):
        t = y / max(1, height - 1)
        color = tuple(int(top[index] * (1.0 - t) + bottom[index] * t) for index in range(3))
        draw.line([(0, y), (width, y)], fill=(*color, 255))


def draw_hash_marks(draw: ImageDraw.ImageDraw, unit_id: str, size: tuple[int, int], color: tuple[int, int, int], alpha: int) -> None:
    seed = hash_int(unit_id)
    width, height = size
    for index in range(10):
        x = (seed >> (index * 5)) % width
        y = (seed >> (index * 7 + 3)) % height
        length = 18 + ((seed >> (index * 3)) % 38)
        draw.line([(x, y), (x + length, y - length * 0.45)], fill=with_alpha(color, alpha), width=2)


def draw_unit_signature(
    draw: ImageDraw.ImageDraw,
    unit_id: str,
    size: tuple[int, int],
    color: tuple[int, int, int],
    anchor: tuple[int, int],
    scale: int,
) -> None:
    seed = hash_int(f"{unit_id}:signature")
    for index in range(8):
        bit_pair = (seed >> (index * 6)) & 0x3F
        x = anchor[0] + (index % 4) * scale + (bit_pair % 3)
        y = anchor[1] + (index // 4) * scale + ((bit_pair // 3) % 3)
        radius = max(1, scale // 5 + (bit_pair % 2))
        alpha = 125 + ((bit_pair >> 1) % 95)
        draw.ellipse(
            [x - radius, y - radius, x + radius, y + radius],
            fill=with_alpha(color, alpha),
            outline=with_alpha((18, 20, 22), min(220, alpha + 20)),
        )
    slash_offset = seed % max(1, size[0] // 5)
    draw.line(
        [
            (max(2, anchor[0] - scale // 2 + slash_offset), min(size[1] - 3, anchor[1] + scale * 3)),
            (min(size[0] - 3, anchor[0] + scale * 4 + slash_offset), max(2, anchor[1] - scale)),
        ],
        fill=with_alpha(color, 54),
        width=max(1, scale // 5),
    )


def draw_tier_pips(draw: ImageDraw.ImageDraw, tier: int, origin: tuple[int, int], color: tuple[int, int, int], radius: int = 5) -> None:
    for index in range(max(1, min(7, tier))):
        x = origin[0] + (index % 4) * (radius * 3)
        y = origin[1] + (index // 4) * (radius * 3)
        draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=with_alpha(color, 225), outline=(18, 20, 22, 210), width=1)


def draw_centered_text(draw: ImageDraw.ImageDraw, text: str, box: tuple[int, int, int, int], text_font, fill: tuple[int, int, int, int]) -> None:
    bbox = draw.textbbox((0, 0), text, font=text_font)
    x = box[0] + ((box[2] - box[0]) - (bbox[2] - bbox[0])) / 2
    y = box[1] + ((box[3] - box[1]) - (bbox[3] - bbox[1])) / 2 - 2
    draw.text((x, y), text, font=text_font, fill=fill)


def draw_portrait(unit: dict, palette: dict, motif: str, initials: str, path: Path) -> None:
    image, draw = canvas(PORTRAIT_SIZE)
    primary = palette["primary"]
    secondary = palette["secondary"]
    shadow = palette["shadow"]
    metal = palette["metal"]
    draw_gradient(draw, PORTRAIT_SIZE, scale_color(primary, 0.48), scale_color(shadow, 0.86))
    draw_hash_marks(draw, str(unit["id"]), PORTRAIT_SIZE, metal, 38)
    draw.rectangle([20, 20, 364, 492], outline=with_alpha(metal, 235), width=5)
    draw.rectangle([30, 30, 354, 482], outline=with_alpha(scale_color(shadow, 0.72), 235), width=3)
    draw.polygon([(42, 92), (192, 42), (342, 92), (322, 122), (62, 122)], fill=with_alpha(secondary, 120))
    draw_motif(draw, motif, (192, 246), 112, palette, str(unit["id"]))
    draw.rectangle([42, 392, 342, 460], fill=with_alpha(scale_color(shadow, 0.72), 215), outline=with_alpha(metal, 180), width=2)
    draw_centered_text(draw, str(unit.get("name", unit["id"]))[:28], (48, 400, 336, 430), font(24, True), (245, 238, 218, 245))
    subtitle = f"T{int(unit.get('tier', 1))} {str(unit.get('role', '')).upper()}"
    draw_centered_text(draw, subtitle, (48, 430, 336, 458), font(17), (218, 224, 219, 230))
    draw_tier_pips(draw, int(unit.get("tier", 1)), (54, 62), metal, 5)
    draw_centered_text(draw, initials, (272, 48, 336, 92), font(30, True), with_alpha(metal, 238))
    image.save(path)


def draw_curated_portrait(unit: dict, palette: dict, source: Image.Image, path: Path) -> None:
    image, draw = canvas(PORTRAIT_SIZE)
    primary = palette["primary"]
    shadow = palette["shadow"]
    metal = palette["metal"]
    draw_gradient(draw, PORTRAIT_SIZE, scale_color(primary, 0.42), scale_color(shadow, 0.74))
    draw_hash_marks(draw, str(unit["id"]), PORTRAIT_SIZE, metal, 30)
    draw.rectangle([20, 20, 364, 492], outline=with_alpha(metal, 235), width=5)
    draw.rectangle([30, 30, 354, 482], outline=with_alpha(scale_color(shadow, 0.72), 235), width=3)
    draw.ellipse([54, 306, 330, 390], fill=with_alpha(scale_color(shadow, 0.48), 105))
    figure = _fit_curated_source(source, (314, 342))
    image.alpha_composite(figure, ((PORTRAIT_SIZE[0] - figure.width) // 2, 382 - figure.height))
    draw.rectangle([42, 392, 342, 460], fill=with_alpha(scale_color(shadow, 0.72), 225), outline=with_alpha(metal, 190), width=2)
    draw_centered_text(draw, str(unit.get("name", unit["id"]))[:28], (48, 400, 336, 430), font(24, True), (245, 238, 218, 245))
    subtitle = f"T{int(unit.get('tier', 1))} {str(unit.get('role', '')).upper()}"
    draw_centered_text(draw, subtitle, (48, 430, 336, 458), font(17), (218, 224, 219, 230))
    draw_tier_pips(draw, int(unit.get("tier", 1)), (54, 62), metal, 5)
    image.save(path)


def draw_battle_icon(unit: dict, palette: dict, motif: str, initials: str, path: Path) -> None:
    image, draw = canvas(BATTLE_ICON_SIZE)
    primary = palette["primary"]
    secondary = palette["secondary"]
    shadow = palette["shadow"]
    metal = palette["metal"]
    center = (80, 80)
    draw.ellipse([10, 10, 150, 150], fill=with_alpha(scale_color(shadow, 0.84), 245), outline=with_alpha(metal, 235), width=5)
    draw.ellipse([22, 22, 138, 138], fill=with_alpha(primary, 225), outline=with_alpha(scale_color(secondary, 1.12), 210), width=3)
    draw_hash_marks(draw, str(unit["id"]), BATTLE_ICON_SIZE, metal, 28)
    draw_motif(draw, motif, center, 43, palette, str(unit["id"]))
    draw_unit_signature(draw, str(unit["id"]), BATTLE_ICON_SIZE, metal, (22, 25), 12)
    draw_tier_pips(draw, int(unit.get("tier", 1)), (36, 130), metal, 3)
    draw_centered_text(draw, initials, (51, 114, 109, 144), font(18, True), (20, 22, 24, 220))
    image.save(path)


def draw_curated_battle_icon(unit: dict, palette: dict, source: Image.Image, path: Path) -> None:
    image, draw = canvas(BATTLE_ICON_SIZE)
    primary = palette["primary"]
    shadow = palette["shadow"]
    metal = palette["metal"]
    draw.ellipse(
        [7, 7, 153, 153],
        fill=with_alpha(scale_color(shadow, 0.78), 232),
        outline=with_alpha(metal, 238),
        width=4,
    )
    draw.ellipse([16, 16, 144, 144], fill=with_alpha(scale_color(primary, 0.72), 165))
    draw.ellipse([31, 132, 129, 151], fill=with_alpha(scale_color(shadow, 0.48), 105))
    figure = _fit_curated_source(source, (146, 146))
    image.alpha_composite(figure, ((160 - figure.width) // 2, 7 + (146 - figure.height)))
    draw_tier_pips(draw, int(unit.get("tier", 1)), (22, 142), metal, 3)
    image.save(path)


def draw_overworld_icon(unit: dict, palette: dict, motif: str, initials: str, path: Path) -> None:
    image, draw = canvas(OVERWORLD_ICON_SIZE)
    primary = palette["primary"]
    secondary = palette["secondary"]
    shadow = palette["shadow"]
    metal = palette["metal"]
    draw.polygon([(48, 4), (88, 30), (80, 86), (16, 86), (8, 30)], fill=with_alpha(scale_color(shadow, 0.78), 245), outline=with_alpha(metal, 230))
    draw.polygon([(48, 12), (78, 34), (72, 76), (24, 76), (18, 34)], fill=with_alpha(primary, 225), outline=with_alpha(secondary, 180))
    draw_hash_marks(draw, str(unit["id"]), OVERWORLD_ICON_SIZE, metal, 24)
    draw_motif(draw, motif, (48, 44), 24, palette, str(unit["id"]))
    draw_unit_signature(draw, str(unit["id"]), OVERWORLD_ICON_SIZE, metal, (16, 18), 8)
    draw_centered_text(draw, initials, (20, 66, 76, 90), font(12, True), (20, 22, 24, 230))
    image.save(path)


def draw_curated_overworld_icon(unit: dict, palette: dict, source: Image.Image, path: Path) -> None:
    image, draw = canvas(OVERWORLD_ICON_SIZE)
    primary = palette["primary"]
    shadow = palette["shadow"]
    metal = palette["metal"]
    draw.polygon(
        [(48, 3), (90, 27), (83, 89), (13, 89), (6, 27)],
        fill=with_alpha(scale_color(shadow, 0.72), 244),
        outline=with_alpha(metal, 235),
    )
    draw.polygon([(48, 10), (82, 31), (76, 80), (20, 80), (14, 31)], fill=with_alpha(scale_color(primary, 0.72), 205))
    draw.ellipse([16, 68, 80, 86], fill=with_alpha(scale_color(shadow, 0.45), 98))
    figure = _fit_curated_source(source, (82, 76))
    image.alpha_composite(figure, ((OVERWORLD_ICON_SIZE[0] - figure.width) // 2, 85 - figure.height))
    draw_tier_pips(draw, int(unit.get("tier", 1)), (17, 84), metal, 2)
    image.save(path)


def draw_battle_troop_animation_sheet(unit: dict, palette: dict, motif: str, initials: str, path: Path) -> None:
    sheet_size = (
        ANIMATION_FRAME_SIZE[0] * ANIMATION_FRAMES_PER_STATE,
        ANIMATION_FRAME_SIZE[1] * len(BATTLE_TROOP_ANIMATION_STATES),
    )
    sheet = Image.new("RGBA", sheet_size, (0, 0, 0, 0))
    for state_index, state in enumerate(BATTLE_TROOP_ANIMATION_STATES):
        for frame_index in range(ANIMATION_FRAMES_PER_STATE):
            render_state = state
            if str(state.get("state", "")) == "surrender_stand_down":
                # Existing generated sheets predate the manifest's semantic
                # surrender-family correction and use retreat motion for this
                # row. Preserve those bytes for non-curated units; the runtime
                # manifest still owns the state as the surrender family.
                render_state = dict(state)
                render_state["family"] = "retreat"
            frame = draw_animation_frame(unit, palette, motif, initials, render_state, state_index, frame_index)
            sheet.alpha_composite(
                frame,
                (
                    frame_index * ANIMATION_FRAME_SIZE[0],
                    state_index * ANIMATION_FRAME_SIZE[1],
                ),
            )
    sheet.save(path)


def draw_curated_battle_troop_animation_sheet(unit: dict, palette: dict, source: Image.Image, path: Path) -> None:
    sheet_size = (
        ANIMATION_FRAME_SIZE[0] * ANIMATION_FRAMES_PER_STATE,
        ANIMATION_FRAME_SIZE[1] * len(BATTLE_TROOP_ANIMATION_STATES),
    )
    sheet = Image.new("RGBA", sheet_size, (0, 0, 0, 0))
    for state_index, state in enumerate(BATTLE_TROOP_ANIMATION_STATES):
        for frame_index in range(ANIMATION_FRAMES_PER_STATE):
            frame = draw_curated_animation_frame(unit, palette, source, state, state_index, frame_index)
            sheet.alpha_composite(
                frame,
                (
                    frame_index * ANIMATION_FRAME_SIZE[0],
                    state_index * ANIMATION_FRAME_SIZE[1],
                ),
            )
    sheet.save(path)


def draw_curated_animation_frame(
    unit: dict,
    palette: dict,
    source: Image.Image,
    state: dict,
    state_index: int,
    frame_index: int,
) -> Image.Image:
    image, draw = canvas(ANIMATION_FRAME_SIZE)
    unit_id = str(unit["id"])
    family = str(state["family"])
    state_name = str(state["state"])
    seed = hash_int(f"{unit_id}:{state_name}:{frame_index}")
    shadow = palette["shadow"]
    metal = palette["metal"]
    draw.ellipse([8, 50, 56, 61], fill=with_alpha(scale_color(shadow, 0.50), 92))
    draw_animation_state_accent(draw, state, frame_index, palette, seed)

    height = 58
    angle = 0.0
    opacity = 255
    if family == "move":
        height = [55, 58, 56, 59][frame_index]
        angle = [-2.0, 1.0, -1.0, 2.0][frame_index]
    elif state_name == "melee_windup_release":
        angle = [-8.0, -3.0, 8.0, 2.0][frame_index]
    elif state_name == "ranged_aim_release":
        angle = [-3.0, -1.0, 2.0, 4.0][frame_index]
    elif family == "hit":
        angle = [-6.0, 8.0, -4.0, 2.0][frame_index]
    elif family == "death":
        height = [54, 50, 46, 42][frame_index]
        angle = [8.0, 31.0, 58.0, 82.0][frame_index]
        opacity = [255, 230, 195, 155][frame_index]
    elif family == "retreat":
        opacity = [255, 235, 210, 180][frame_index]
        angle = [2.0, 1.0, -2.0, -4.0][frame_index]
    elif state_name == "surrender_stand_down":
        height = [57, 55, 53, 51][frame_index]
        angle = [0.0, 2.0, 4.0, 6.0][frame_index]
    elif family == "cast":
        height = [55, 57, 60, 58][frame_index]
        angle = [-2.0, 0.0, 3.0, 1.0][frame_index]
    elif family == "defend":
        angle = [0.0, -2.0, -3.0, -1.0][frame_index]
    else:
        height = [57, 58, 57, 56][frame_index]
        angle = [-1.0, 0.0, 1.0, 0.0][frame_index]

    figure = _fit_curated_source(source, (60, height))
    if angle != 0.0:
        figure = figure.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    if opacity < 255:
        alpha = figure.getchannel("A").point(lambda value: (value * opacity) // 255)
        figure.putalpha(alpha)

    offset_x = animation_offset_x(family, state_name, frame_index, seed)
    offset_y = animation_offset_y(family, state_name, frame_index, seed)
    if family == "death":
        offset_y += 3 + frame_index * 2
    if state_name == "surrender_stand_down":
        offset_y += frame_index
    destination = (
        (ANIMATION_FRAME_SIZE[0] - figure.width) // 2 + offset_x,
        ANIMATION_FRAME_SIZE[1] - figure.height - 2 + offset_y,
    )
    image.alpha_composite(figure, destination)
    draw_animation_frame_signature(draw, unit_id, state_index, frame_index, metal)
    draw_animation_palette_marks(draw, palette, seed, frame_index)
    return image


def _fit_curated_source(source: Image.Image, bounds: tuple[int, int]) -> Image.Image:
    alpha = source.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("Curated character source has no visible pixels")
    figure = source.crop(bbox)
    scale = min(bounds[0] / figure.width, bounds[1] / figure.height)
    size = (max(1, round(figure.width * scale)), max(1, round(figure.height * scale)))
    return figure.resize(size, Image.Resampling.LANCZOS)


def draw_animation_frame(
    unit: dict,
    palette: dict,
    motif: str,
    initials: str,
    state: dict,
    state_index: int,
    frame_index: int,
) -> Image.Image:
    image, draw = canvas(ANIMATION_FRAME_SIZE)
    unit_id = str(unit["id"])
    primary = palette["primary"]
    secondary = palette["secondary"]
    shadow = palette["shadow"]
    metal = palette["metal"]
    family = str(state["family"])
    state_name = str(state["state"])
    seed = hash_int(f"{unit_id}:{state_name}:{frame_index}")
    phase = frame_index / max(1, ANIMATION_FRAMES_PER_STATE - 1)
    center_x = 32 + animation_offset_x(family, state_name, frame_index, seed)
    center_y = 34 + animation_offset_y(family, state_name, frame_index, seed)
    size = 19 + ((seed >> 4) % 3)
    alpha = 220
    if family == "death":
        center_y += 4 + frame_index * 2
        size = max(12, size - frame_index * 2)
        alpha = 230 - frame_index * 28
    elif state_name == "surrender_stand_down":
        center_y += frame_index
        size = max(14, size - 2)
    elif family == "retreat":
        alpha = 230 - frame_index * 18

    draw.ellipse([9, 49, 55, 60], fill=with_alpha(scale_color(shadow, 0.55), 92))
    draw_animation_state_accent(draw, state, frame_index, palette, seed)
    draw_motif(draw, motif, (center_x, center_y), size, palette, f"{unit_id}:{state_name}:{frame_index}")
    draw_unit_signature(draw, unit_id, ANIMATION_FRAME_SIZE, metal, (4 + (seed % 4), 5 + ((seed >> 3) % 4)), 5)
    draw_animation_frame_signature(draw, unit_id, state_index, frame_index, metal)
    draw_animation_palette_marks(draw, palette, seed, frame_index)
    if family == "ready":
        draw.ellipse([6, 6, 58, 58], outline=with_alpha(metal, 120 + frame_index * 28), width=2)
    if family == "hit":
        draw.line([(16, 18 + frame_index * 3), (48, 46 - frame_index * 4)], fill=with_alpha((245, 238, 218), 180), width=2)
    if family == "death":
        draw.line([(16, 47), (50, 54)], fill=with_alpha(primary, 115), width=3)
    if state_name == "surrender_stand_down":
        draw.line([(14, 19), (14, 48)], fill=with_alpha(metal, 210), width=2)
        draw.polygon([(14, 19), (31, 23), (14, 29)], fill=with_alpha((236, 232, 210), 190))
    draw_centered_text(draw, initials[:2], (3, 46, 25, 62), font(8, True), with_alpha(scale_color(shadow, 0.65), alpha))
    if alpha < 220:
        fade = Image.new("RGBA", ANIMATION_FRAME_SIZE, (0, 0, 0, 255 - alpha))
        image = Image.alpha_composite(image, fade)
    _ = phase
    return image


def animation_offset_x(family: str, state_name: str, frame_index: int, seed: int) -> int:
    if family == "move":
        return [-7, -2, 3, 8][frame_index]
    if state_name == "melee_windup_release":
        return [-3, 2, 8, 1][frame_index]
    if state_name == "ranged_aim_release":
        return [-2, -1, 0, 2][frame_index]
    if family == "hit":
        return [-3, 4, -2, 2][frame_index]
    if family == "retreat":
        return [4, 0, -5, -10][frame_index]
    if state_name == "retaliation_release":
        return [3, -2, -7, -1][frame_index]
    return ((seed >> 5) % 3) - 1


def animation_offset_y(family: str, state_name: str, frame_index: int, seed: int) -> int:
    if family == "idle":
        return [0, -1, 0, 1][frame_index]
    if family == "ready":
        return [1, 0, -2, 0][frame_index]
    if family == "move":
        return [2, -1, 1, -2][frame_index]
    if family == "cast":
        return [2, 0, -3, -1][frame_index]
    if family == "defend":
        return [1, 0, 0, 1][frame_index]
    return ((seed >> 8) % 3) - 1


def draw_animation_state_accent(draw: ImageDraw.ImageDraw, state: dict, frame_index: int, palette: dict, seed: int) -> None:
    family = str(state["family"])
    state_name = str(state["state"])
    primary = palette["primary"]
    secondary = palette["secondary"]
    metal = palette["metal"]
    shadow = palette["shadow"]
    pulse = 80 + frame_index * 34
    if family == "move":
        draw.line([(14 + frame_index * 4, 54), (28 + frame_index * 4, 54)], fill=with_alpha(metal, 145), width=2)
        draw.line([(8 + frame_index * 5, 58), (18 + frame_index * 5, 58)], fill=with_alpha(metal, 95), width=1)
    elif state_name == "melee_windup_release":
        draw.arc([8, 10, 58, 58], 205 - frame_index * 14, 292 + frame_index * 18, fill=with_alpha(metal, 135 + frame_index * 22), width=2)
    elif state_name == "ranged_aim_release":
        draw.line([(13, 31), (51 + frame_index * 2, 25 - frame_index * 2)], fill=with_alpha(metal, 125 + frame_index * 28), width=2)
        draw.ellipse([49 + frame_index * 2, 22 - frame_index * 2, 55 + frame_index * 2, 28 - frame_index * 2], fill=with_alpha(secondary, 150))
    elif family == "cast":
        for index in range(5):
            angle = math.radians(index * 72 + frame_index * 18 + seed % 9)
            x = 32 + math.cos(angle) * (18 + frame_index * 2)
            y = 30 + math.sin(angle) * (18 + frame_index * 2)
            draw.ellipse([x - 2, y - 2, x + 2, y + 2], fill=with_alpha(metal, 150))
    elif family == "status":
        for index in range(3):
            y = 13 + ((index * 11 + frame_index * 3) % 32)
            draw.ellipse([49, y, 55, y + 6], outline=with_alpha(secondary, 140), width=1)
    elif family == "defend":
        draw.polygon([(12, 16), (26, 9), (28, 47), (13, 52)], fill=with_alpha(scale_color(shadow, 0.75), 160), outline=with_alpha(metal, 170))
    elif state_name == "retaliation_release":
        draw.line([(50, 18), (18 - frame_index * 2, 39 + frame_index)], fill=with_alpha(metal, 160), width=2)
    elif family == "retreat":
        draw.line([(49 - frame_index * 7, 16), (55 - frame_index * 7, 16)], fill=with_alpha(primary, 110), width=2)
    elif family == "death":
        draw.arc([18, 36, 48, 64], 180, 350, fill=with_alpha(primary, 90 + frame_index * 20), width=2)
    else:
        draw.ellipse([12 - frame_index, 12 - frame_index, 52 + frame_index, 52 + frame_index], outline=with_alpha(secondary, pulse), width=1)


def draw_animation_frame_signature(
    draw: ImageDraw.ImageDraw,
    unit_id: str,
    state_index: int,
    frame_index: int,
    color: tuple[int, int, int],
) -> None:
    seed = hash_int(f"{unit_id}:animation:{state_index}:{frame_index}")
    for index in range(4):
        x = 49 + index * 3
        y = 5 + ((seed >> (index * 4)) & 0x07)
        draw.rectangle([x, y, x + 1, y + 1], fill=with_alpha(color, 160 + frame_index * 18))
    draw.point((3 + (state_index % 10), 3 + frame_index), fill=with_alpha(color, 210))


def draw_animation_palette_marks(draw: ImageDraw.ImageDraw, palette: dict, seed: int, frame_index: int) -> None:
    colors = [
        palette["primary"],
        palette["secondary"],
        palette["metal"],
        palette["shadow"],
        scale_color(palette["secondary"], 1.18),
    ]
    for index, color in enumerate(colors):
        x = 5 + index * 4
        y = 6 + ((seed >> (index * 3)) & 0x03) + frame_index
        draw.rectangle([x, y, x + 2, y + 2], fill=with_alpha(color, 180))


def draw_motif(draw: ImageDraw.ImageDraw, motif: str, center: tuple[int, int], size: int, palette: dict, unit_id: str) -> None:
    primary = palette["primary"]
    secondary = palette["secondary"]
    shadow = palette["shadow"]
    metal = palette["metal"]
    x, y = center
    seed = hash_int(unit_id)
    accent_shift = ((seed % 17) - 8) / 100.0
    accent = scale_color(secondary, 1.0 + accent_shift)
    dark = scale_color(shadow, 0.72)

    if motif == "ranged":
        draw.arc([x - size, y - size, x + size * 0.35, y + size], 288, 75, fill=with_alpha(metal, 235), width=max(3, size // 15))
        draw.line([(x - size * 0.54, y - size * 0.62), (x + size * 0.70, y + size * 0.42)], fill=with_alpha(dark, 245), width=max(3, size // 14))
        draw.polygon([(x + size * 0.70, y + size * 0.42), (x + size * 0.42, y + size * 0.32), (x + size * 0.54, y + size * 0.58)], fill=with_alpha(metal, 245))
    elif motif == "shield":
        points = [(x, y - size), (x + size * 0.66, y - size * 0.48), (x + size * 0.50, y + size * 0.54), (x, y + size), (x - size * 0.50, y + size * 0.54), (x - size * 0.66, y - size * 0.48)]
        draw.polygon(points, fill=with_alpha(accent, 232), outline=with_alpha(dark, 245))
        draw.line([(x, y - size * 0.74), (x, y + size * 0.70)], fill=with_alpha(metal, 225), width=max(2, size // 16))
    elif motif == "blade":
        draw.polygon([(x - size * 0.10, y - size), (x + size * 0.30, y - size * 0.14), (x + size * 0.02, y + size * 0.92), (x - size * 0.24, y - size * 0.12)], fill=with_alpha(metal, 240), outline=with_alpha(dark, 245))
        draw.line([(x - size * 0.54, y + size * 0.44), (x + size * 0.52, y + size * 0.18)], fill=with_alpha(accent, 230), width=max(4, size // 12))
    elif motif == "caster":
        for index in range(6):
            angle = math.radians(index * 60 + (seed % 19))
            point = (x + math.cos(angle) * size * 0.78, y + math.sin(angle) * size * 0.78)
            draw.line([center, point], fill=with_alpha(metal, 120), width=max(2, size // 22))
            draw.ellipse([point[0] - size * 0.10, point[1] - size * 0.10, point[0] + size * 0.10, point[1] + size * 0.10], fill=with_alpha(accent, 215))
        draw.ellipse([x - size * 0.38, y - size * 0.38, x + size * 0.38, y + size * 0.38], fill=with_alpha(primary, 230), outline=with_alpha(metal, 235), width=max(2, size // 20))
    elif motif == "beast":
        draw.ellipse([x - size * 0.76, y - size * 0.42, x + size * 0.70, y + size * 0.58], fill=with_alpha(accent, 235), outline=with_alpha(dark, 245), width=max(2, size // 18))
        draw.polygon([(x - size * 0.50, y - size * 0.38), (x - size * 0.82, y - size * 0.86), (x - size * 0.14, y - size * 0.52)], fill=with_alpha(metal, 220))
        draw.polygon([(x + size * 0.42, y - size * 0.36), (x + size * 0.80, y - size * 0.72), (x + size * 0.62, y - size * 0.10)], fill=with_alpha(metal, 220))
        draw.ellipse([x + size * 0.26, y - size * 0.08, x + size * 0.40, y + size * 0.06], fill=with_alpha(dark, 255))
    elif motif == "engine":
        draw.rectangle([x - size * 0.76, y - size * 0.34, x + size * 0.72, y + size * 0.42], fill=with_alpha(accent, 230), outline=with_alpha(dark, 245), width=max(2, size // 18))
        draw.line([(x - size * 0.94, y - size * 0.70), (x + size * 0.94, y + size * 0.72)], fill=with_alpha(metal, 230), width=max(3, size // 12))
        draw.ellipse([x - size * 0.62, y + size * 0.28, x - size * 0.22, y + size * 0.68], fill=with_alpha(dark, 235), outline=with_alpha(metal, 210))
        draw.ellipse([x + size * 0.22, y + size * 0.28, x + size * 0.62, y + size * 0.68], fill=with_alpha(dark, 235), outline=with_alpha(metal, 210))
    else:
        draw.line([(x - size * 0.52, y + size * 0.54), (x + size * 0.48, y - size * 0.58)], fill=with_alpha(metal, 240), width=max(5, size // 9))
        draw.line([(x - size * 0.18, y + size * 0.10), (x + size * 0.30, y + size * 0.58)], fill=with_alpha(dark, 245), width=max(3, size // 13))
        draw.ellipse([x - size * 0.40, y - size * 0.18, x + size * 0.30, y + size * 0.50], outline=with_alpha(accent, 230), width=max(3, size // 15))


if __name__ == "__main__":
    raise SystemExit(main())
