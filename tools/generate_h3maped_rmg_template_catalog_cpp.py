#!/usr/bin/env python3
"""Generate recovered H3MapEd RMG template catalog C++ tables.

The source catalog is the recovered H3MapEd template catalog artifact. The
generated C++ is static data plus selection/feed logic for the shared native
RMG core; it is not a final-map tuning surface.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CATALOG = Path("/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json")
DEFAULT_OUT = ROOT / "src/gdextension/src/h3maped_rmg_template_catalog.cpp"


def i32(value: Any, default: int = 0) -> int:
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, (int, float)):
        return int(value)
    return default


def filter_payload(payload: Any) -> dict[str, int]:
    data = payload if isinstance(payload, dict) else {}
    return {
        "min_human": i32(data.get("min_human"), 0),
        "max_human": i32(data.get("max_human"), 8),
        "min_total": i32(data.get("min_total"), 0),
        "max_total": i32(data.get("max_total"), 8),
    }


def cpp_string(value: Any) -> str:
    text = str(value if value is not None else "")
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def role_code(zone_type: str) -> int:
    if zone_type == "human_start":
        return 1
    if zone_type == "computer_start":
        return 2
    return 0


H3_TOWN_INDEX_BY_NAME = {
    "castle": 0,
    "rampart": 1,
    "tower": 2,
    "inferno": 3,
    "necropolis": 4,
    "dungeon": 5,
    "stronghold": 6,
    "fortress": 7,
    "elemental": 8,
}


H3_TERRAIN_INDEX_BY_NAME = {
    "dirt": 0,
    "sand": 1,
    "grass": 2,
    "snow": 3,
    "swamp": 4,
    "rough": 5,
    "cave": 6,
    "lava": 7,
}

H3_MONSTER_TOWN_INDEX_BY_NAME = {
    "neutral": 0,
    "castle": 1,
    "rampart": 2,
    "tower": 3,
    "inferno": 4,
    "necropolis": 5,
    "dungeon": 6,
    "stronghold": 7,
    "fortress": 8,
    "forge": 9,
}

SOURCE_ZONE_TYPE_CODE = {
    "human_start": 1,
    "computer_start": 2,
    "treasure": 3,
    "junction": 4,
}

H3_RESOURCE_KEYS = ("wood", "mercury", "ore", "sulfur", "crystal", "gems", "gold")


def monster_strength_mode(value: Any) -> int:
    text = str(value if value is not None else "avg").strip().lower()
    if text.startswith("n"):
        return 0
    if text.startswith("w"):
        return 2
    if text.startswith("s"):
        return 4
    return 3


def mask_from_names(values: Any, mapping: dict[str, int], max_slots: int) -> int:
    mask = 0
    if not isinstance(values, list):
        return mask
    for value in values:
        index = mapping.get(str(value))
        if index is not None and 0 <= index < max_slots:
            mask |= 1 << index
    return mask


def int_dict_values(payload: Any, keys: tuple[str, ...]) -> list[int]:
    data = payload if isinstance(payload, dict) else {}
    return [i32(data.get(key), 0) for key in keys]


def source_town_rules(payload: Any) -> str:
    values = int_dict_values(payload, ("min_towns", "min_castles", "town_density", "castle_density"))
    return "{ " + ", ".join(str(value) for value in values) + " }"


def source_mine_rules(minimum_payload: Any, density_payload: Any) -> str:
    values = int_dict_values(minimum_payload, H3_RESOURCE_KEYS) + int_dict_values(density_payload, H3_RESOURCE_KEYS)
    return "{ " + ", ".join(str(value) for value in values) + " }"


def source_treasure_band(payload: Any) -> str:
    data = payload if isinstance(payload, dict) else {}
    return "{ " + ", ".join(str(i32(data.get(key), 0)) for key in ("density", "low", "high")) + " }"


def source_zone_payload(zone: dict[str, Any]) -> str:
    bands = zone.get("treasure_bands", [])
    if not isinstance(bands, list):
        bands = []
    band_values = [source_treasure_band(bands[index] if index < len(bands) else {}) for index in range(3)]
    allowed_monster_mask = mask_from_names(zone.get("allowed_monster_towns", []), H3_MONSTER_TOWN_INDEX_BY_NAME, 10)
    return (
        "{ "
        f"{i32(zone.get('row'), -1)}, "
        f"{SOURCE_ZONE_TYPE_CODE.get(str(zone.get('type', '')), 0)}, "
        f"{i32(zone.get('ownership'), -1)}, "
        f"{'true' if bool(zone.get('same_town_type', False)) else 'false'}, "
        f"{'true' if bool(zone.get('monster_match_to_town', False)) else 'false'}, "
        f"{monster_strength_mode(zone.get('monster_strength', 'avg'))}, "
        f"uint16_t({allowed_monster_mask}), "
        f"{source_town_rules(zone.get('player_towns', {}))}, "
        f"{source_town_rules(zone.get('neutral_towns', {}))}, "
        f"{source_mine_rules(zone.get('minimum_mines', {}), zone.get('mine_density', {}))}, "
        f"{band_values[0]}, {band_values[1]}, {band_values[2]} "
        "}"
    )


def render(catalog_path: Path, payload: dict[str, Any]) -> str:
    raw_bytes = catalog_path.read_bytes()
    digest = hashlib.sha256(raw_bytes).hexdigest()
    templates = payload.get("templates", [])
    if not isinstance(templates, list):
        raise ValueError("catalog templates must be a list")

    template_rows: list[str] = []
    zone_rows: list[str] = []
    link_rows: list[str] = []

    zone_begin = 0
    link_begin = 0
    for template_index, template in enumerate(templates):
        if not isinstance(template, dict):
            continue
        zones = template.get("zones", [])
        links = template.get("connections", [])
        if not isinstance(zones, list):
            zones = []
        if not isinstance(links, list):
            links = []
        human_range = template.get("supported_human_range", [0, 0])
        total_range = template.get("supported_total_player_range", [0, 0])
        min_human = i32(human_range[0] if isinstance(human_range, list) and len(human_range) >= 1 else 0)
        max_human = i32(human_range[1] if isinstance(human_range, list) and len(human_range) >= 2 else 0)
        min_total = i32(total_range[0] if isinstance(total_range, list) and len(total_range) >= 1 else 0)
        max_total = i32(total_range[1] if isinstance(total_range, list) and len(total_range) >= 2 else 0)
        template_rows.append(
            "\t{ "
            f"{template_index}, {cpp_string(template.get('name', ''))}, "
            f"{i32(template.get('min_size'))}, {i32(template.get('max_size'))}, "
            f"{min_human}, {max_human}, {min_total}, {max_total}, "
            f"{zone_begin}, {len(zones)}, {link_begin}, {len(links)} "
            "},"
        )
        for zone_position, zone in enumerate(zones):
            if not isinstance(zone, dict):
                continue
            player_filter = filter_payload(zone.get("player_filter", {}))
            source_zone_id = i32(zone.get("id"), zone_position + 1)
            source_index = source_zone_id - 1 if source_zone_id > 0 else zone_position
            ownership = zone.get("ownership", -1)
            source_owner = i32(ownership, -1) if isinstance(ownership, (int, float)) else -1
            allowed_town_mask = mask_from_names(zone.get("allowed_towns", []), H3_TOWN_INDEX_BY_NAME, 9)
            allowed_terrain_mask = mask_from_names(zone.get("allowed_terrains", []), H3_TERRAIN_INDEX_BY_NAME, 8)
            zone_rows.append(
                "\t{ "
                "{ "
                f"{source_zone_id}, {source_index}, {source_index}, {i32(zone.get('bucket'), -1)}, "
                f"{source_owner}, {i32(zone.get('base_size'))}, "
                f"{player_filter['min_human']}, {player_filter['max_human']}, "
                f"{player_filter['min_total']}, {player_filter['max_total']}, "
                f"uint16_t({allowed_town_mask}), "
                f"{'true' if bool(zone.get('terrain_match_to_town', False)) else 'false'}, "
                f"uint16_t({allowed_terrain_mask}), "
                f"{source_zone_payload(zone)} "
                "}, "
                f"{role_code(str(zone.get('type', '')))} "
                "},"
            )
        for link in links:
            if not isinstance(link, dict):
                continue
            player_filter = filter_payload(link.get("player_filter", {}))
            source_endpoints = link.get("source_endpoints", {})
            if not isinstance(source_endpoints, dict):
                source_endpoints = {}
            link_rows.append(
                "\t{ "
                f"{i32(link.get('zone1'), -1)}, {i32(link.get('zone2'), -1)}, "
                f"{i32(link.get('value'))}, "
                f"{'true' if bool(link.get('wide', False)) else 'false'}, "
                f"{'true' if bool(link.get('border_guard', False)) else 'false'}, "
                f"{player_filter['min_human']}, {player_filter['max_human']}, "
                f"{player_filter['min_total']}, {player_filter['max_total']}, "
                f"{i32(source_endpoints.get('zone1'), -1)}, {i32(source_endpoints.get('zone2'), -1)} "
                "},"
            )
        zone_begin += len(zones)
        link_begin += len(links)

    return f"""// Generated by tools/generate_h3maped_rmg_template_catalog_cpp.py.
// Source: {catalog_path}
// Source sha256: {digest}

#include \"h3maped_rmg_core.hpp\"

#include <algorithm>
#include <array>
#include <cstdint>
#include <vector>

namespace aurelion::h3maped_rmg_core {{
namespace {{

enum TemplateZoneRole4ac552 : int32_t {{
\tTEMPLATE_ZONE_ROLE_OTHER = 0,
\tTEMPLATE_ZONE_ROLE_HUMAN_START = 1,
\tTEMPLATE_ZONE_ROLE_COMPUTER_START = 2,
}};

struct CatalogTemplateRecord4ac552 {{
\tint32_t source_catalog_index = -1;
\tconst char *name = \"\";
\tint32_t min_size = 0;
\tint32_t max_size = 0;
\tint32_t min_human = 0;
\tint32_t max_human = 0;
\tint32_t min_total = 0;
\tint32_t max_total = 0;
\tint32_t zone_begin = 0;
\tint32_t zone_count = 0;
\tint32_t link_begin = 0;
\tint32_t link_count = 0;
}};

struct CatalogZoneRecord4ac552 {{
\tTemplateZoneRecord4a218c zone;
\tint32_t role = TEMPLATE_ZONE_ROLE_OTHER;
}};

static const CatalogTemplateRecord4ac552 CATALOG_TEMPLATES_4AC552[] = {{
{chr(10).join(template_rows)}
}};

static const CatalogZoneRecord4ac552 CATALOG_ZONES_4AC552[] = {{
{chr(10).join(zone_rows)}
}};

static const TemplateLinkRecord4a1f3b CATALOG_LINKS_4A1F3B[] = {{
{chr(10).join(link_rows)}
}};

bool template_range_allows_4ac552(const CatalogTemplateRecord4ac552 &template_record, int32_t size_score, int32_t human_count, int32_t player_count) {{
\treturn size_score >= template_record.min_size
\t\t\t&& size_score <= template_record.max_size
\t\t\t&& human_count >= template_record.min_human
\t\t\t&& human_count <= template_record.max_human
\t\t\t&& player_count >= template_record.min_total
\t\t\t&& player_count <= template_record.max_total
\t\t\t&& player_count >= human_count;
}}

void template_owner_masks_4ac552(const CatalogTemplateRecord4ac552 &template_record, int32_t human_count, int32_t player_count, uint8_t &human_mask, uint8_t &player_mask) {{
\thuman_mask = 0U;
\tplayer_mask = 0U;
\tfor (int32_t offset = 0; offset < template_record.zone_count; ++offset) {{
\t\tconst CatalogZoneRecord4ac552 &record = CATALOG_ZONES_4AC552[template_record.zone_begin + offset];
\t\tconst TemplateZoneRecord4a218c &zone = record.zone;
\t\tif (!player_filter_allows_4a218c(
\t\t\t\t\tzone.player_filter_min_human,
\t\t\t\t\tzone.player_filter_max_human,
\t\t\t\t\tzone.player_filter_min_total,
\t\t\t\t\tzone.player_filter_max_total,
\t\t\t\t\thuman_count,
\t\t\t\t\tplayer_count)) {{
\t\t\tcontinue;
\t\t}}
\t\tif (zone.source_owner_index < 0 || zone.source_owner_index >= 8) {{
\t\t\tcontinue;
\t\t}}
\t\tconst uint8_t bit = uint8_t(1U) << zone.source_owner_index;
\t\tif (record.role == TEMPLATE_ZONE_ROLE_HUMAN_START) {{
\t\t\thuman_mask |= bit;
\t\t\tplayer_mask |= bit;
\t\t}} else if (record.role == TEMPLATE_ZONE_ROLE_COMPUTER_START) {{
\t\t\tplayer_mask |= bit;
\t\t}}
\t}}
}}

}} // namespace

TemplateSelectionRuntimeResult4ac552 template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b(uint32_t seed, int32_t size_score, int32_t human_count, int32_t player_count, uint8_t selected_color_mask) {{
\tTemplateSelectionRuntimeResult4ac552 result;
\tresult.size_score = size_score;
\tresult.human_count = std::max<int32_t>(0, human_count);
\tresult.player_count = std::max<int32_t>(result.human_count, player_count);
\tresult.rng_state_before_template_selection = seed;

\tresult.accepted_candidate_containers_10d4_10d8.reserve(sizeof(CATALOG_TEMPLATES_4AC552) / sizeof(CATALOG_TEMPLATES_4AC552[0]));
\tfor (int32_t index = 0; index < int32_t(sizeof(CATALOG_TEMPLATES_4AC552) / sizeof(CATALOG_TEMPLATES_4AC552[0])); ++index) {{
\t\tconst CatalogTemplateRecord4ac552 &template_record = CATALOG_TEMPLATES_4AC552[index];
\t\tif (!template_range_allows_4ac552(template_record, size_score, result.human_count, result.player_count)) {{
\t\t\tcontinue;
\t\t}}
\t\tTemplateCandidateContainerRecord4ac552 candidate;
\t\tcandidate.vector_index = int32_t(result.accepted_candidate_containers_10d4_10d8.size());
\t\tcandidate.source_catalog_index = template_record.source_catalog_index;
\t\tcandidate.template_name = template_record.name;
\t\tcandidate.zone_count = template_record.zone_count;
\t\tcandidate.link_count = template_record.link_count;
\t\tresult.accepted_candidate_containers_10d4_10d8.push_back(candidate);
\t}}
\tresult.accepted_template_count = int32_t(result.accepted_candidate_containers_10d4_10d8.size());
\tif (result.accepted_candidate_containers_10d4_10d8.empty()) {{
\t\tresult.blocked = true;
\t\treturn result;
\t}}

\tH3MapedRng rng;
\trng.state = seed;
\tresult.rng_value = rng.next();
\tresult.rng_state_after_template_selection = rng.state;
\tresult.selected_vector_index = result.rng_value % result.accepted_template_count;
\tconst TemplateCandidateContainerRecord4ac552 &selected_candidate = result.accepted_candidate_containers_10d4_10d8[size_t(result.selected_vector_index)];
\tconst CatalogTemplateRecord4ac552 &selected_template = CATALOG_TEMPLATES_4AC552[selected_candidate.source_catalog_index];
\tresult.selected_source_catalog_index = selected_template.source_catalog_index;
\tresult.selected_template_name = selected_template.name;
\tresult.source_zone_record_count = selected_template.zone_count;
\tresult.source_link_record_count = selected_template.link_count;
\ttemplate_owner_masks_4ac552(selected_template, result.human_count, result.player_count, result.human_capable_source_owner_mask, result.player_capable_source_owner_mask);
\tresult.player_assignment = player_slot_assignment_4ac62a_4ac6ec(
\t\t\tresult.human_count,
\t\t\tresult.player_count,
\t\t\tresult.human_capable_source_owner_mask,
\t\t\tresult.player_capable_source_owner_mask,
\t\t\tselected_color_mask);

\tstd::vector<TemplateZoneRecord4a218c> zones;
\tzones.reserve(size_t(selected_template.zone_count));
\tfor (int32_t offset = 0; offset < selected_template.zone_count; ++offset) {{
\t\tzones.push_back(CATALOG_ZONES_4AC552[selected_template.zone_begin + offset].zone);
\t}}
\tstd::vector<TemplateLinkRecord4a1f3b> links;
\tlinks.reserve(size_t(selected_template.link_count));
\tfor (int32_t offset = 0; offset < selected_template.link_count; ++offset) {{
\t\tlinks.push_back(CATALOG_LINKS_4A1F3B[selected_template.link_begin + offset]);
\t}}
\tresult.runtime_seed = runtime_seed_inputs_from_template_records_4a218c_4a1f3b(zones, links, result.player_assignment, result.human_count, result.player_count);
\tresult.blocked = !result.player_assignment.complete || result.runtime_seed.blocked || result.runtime_seed.runtime_zone_seeds.empty();
\treturn result;
}}

}} // namespace aurelion::h3maped_rmg_core
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    payload = json.loads(args.catalog.read_text(encoding="utf-8"))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(render(args.catalog, payload), encoding="utf-8")
    print(f"generated {args.out} from {args.catalog}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
