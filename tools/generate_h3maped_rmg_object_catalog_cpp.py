#!/usr/bin/env python3
"""Generate recovered H3MapEd RMG object source-record C++ tables.

The input CSV is the recovered `0x49da08` object table surface: `objects.txt`
rows and the rand_trn-backed terrain/object annotations. The generated C++
preserves source-record identity for the shared native RMG core; it is not a
map-output heuristic or density tuning surface.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
from collections import defaultdict
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CATALOG = Path("/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-catalog-by-type.csv")
DEFAULT_METADATA = Path("/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-metadata-by-type.csv")
DEFAULT_OUT = ROOT / "src/gdextension/src/h3maped_rmg_object_catalog.cpp"
DEFAULT_MSK_DIRS = [
    Path("/root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/output/h3sprite/raw"),
    Path("/root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/output/h3ab_spr/raw"),
]


def i32(value: Any, default: int = 0) -> int:
    text = str(value if value is not None else "").strip()
    if not text:
        return default
    try:
        return int(text)
    except ValueError:
        return default


def bool_text(value: bool) -> str:
    return "true" if value else "false"


def cpp_string(value: Any) -> str:
    text = str(value if value is not None else "")
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def terrain_mask(value: Any) -> int:
    text = str(value if value is not None else "").strip()
    if len(text) != 9 or any(ch not in "01" for ch in text):
        return 0
    mask = 0
    for index, ch in enumerate(text):
        if ch == "1":
            mask |= 1 << index
    return mask


def row_has_rand_trn(row: dict[str, str]) -> bool:
    return bool(row.get("rand_trn_obstacles", "").strip() or row.get("rand_trn_terrain_matches", "").strip())


def read_msk_fields(def_name: str, msk_dirs: list[Path]) -> dict[str, Any]:
    stem = Path(def_name).stem.lower()
    for candidate, exact in ((f"{stem}.msk", True), ("default.msk", False)):
        for msk_dir in msk_dirs:
            path = msk_dir / candidate
            if not path.exists():
                continue
            blob = path.read_bytes()
            if len(blob) != 14:
                raise ValueError(f"{path}: expected 14-byte .msk record, got {len(blob)}")
            return {
                "known": True,
                "exact": exact,
                "width": blob[0],
                "height": blob[1],
                "mask_a": int.from_bytes(blob[2:8], "little"),
                "mask_b": int.from_bytes(blob[8:14], "little"),
            }
    return {
        "known": False,
        "exact": False,
        "width": 0,
        "height": 0,
        "mask_a": 0,
        "mask_b": 0,
    }


def render(catalog_path: Path, metadata_path: Path, msk_dirs: list[Path], rows: list[dict[str, str]], metadata_bucket_by_type: dict[int, int]) -> str:
    digest = hashlib.sha256(catalog_path.read_bytes()).hexdigest()
    metadata_digest = hashlib.sha256(metadata_path.read_bytes()).hexdigest()
    msk_inputs = [path for path in msk_dirs if path.exists()]
    msk_digest = hashlib.sha256(
        "\n".join(
            f"{path}:{path.stat().st_mtime_ns}:{path.stat().st_size}"
            for path in msk_inputs
        ).encode("utf-8")
    ).hexdigest()
    data_rows: list[str] = []
    type53_by_subtype: dict[int, int] = defaultdict(int)
    msk_known_count = 0
    msk_exact_count = 0
    msk_default_count = 0
    for row in rows:
        type_id = i32(row.get("type_id"))
        metadata_bucket = metadata_bucket_by_type.get(type_id, 0)
        subtype = i32(row.get("subtype"))
        msk = read_msk_fields(str(row.get("def_name", "")), msk_dirs)
        if msk["known"]:
            msk_known_count += 1
            if msk["exact"]:
                msk_exact_count += 1
            else:
                msk_default_count += 1
        if type_id == 53:
            type53_by_subtype[subtype] += 1
        data_rows.append(
            "\t{ "
            f"{i32(row.get('source_row'), -1)}, "
            f"{cpp_string(row.get('source'))}, "
            f"{cpp_string(row.get('def_name'))}, "
            f"{type_id}, "
            f"{cpp_string(row.get('type_name'))}, "
            f"{metadata_bucket}, "
            f"{subtype}, "
            f"{i32(row.get('group'))}, "
            f"{i32(row.get('last_flag'))}, "
            f"{i32(row.get('pass_count'))}, "
            f"{i32(row.get('action_count'))}, "
            f"uint16_t({terrain_mask(row.get('terrain_mask_a'))}), "
            f"uint16_t({terrain_mask(row.get('terrain_mask_b'))}), "
            f"{bool_text(msk['known'])}, "
            f"{bool_text(msk['exact'])}, "
            f"{int(msk['width'])}, "
            f"{int(msk['height'])}, "
            f"uint64_t(0x{int(msk['mask_a']):012x}), "
            f"uint64_t(0x{int(msk['mask_b']):012x}), "
            f"{cpp_string(row.get('terrain_a_names'))}, "
            f"{cpp_string(row.get('terrain_b_names'))}, "
            f"{bool_text(row_has_rand_trn(row))} "
            "},"
        )

    ambiguous_type53_subtypes = sum(1 for count in type53_by_subtype.values() if count > 1)
    return f"""// Generated by tools/generate_h3maped_rmg_object_catalog_cpp.py
// Source: {catalog_path}
// Source sha256: {digest}
// Metadata source: {metadata_path}
// Metadata sha256: {metadata_digest}
// MSK directories: {", ".join(str(path) for path in msk_dirs)}
// MSK source digest: {msk_digest}
// Recovered H3MapEd anchor: 0x49da08 object table loader, copied 0x4c source records.
// Recovered bucket anchor: object metadata entry +0x08 routes wrappers into generator bucket lanes.
// Recovered descriptor-mask anchor: 0x4903e8 copies .msk width/height/mask fields into descriptor +0x34..+0x48.

#include "h3maped_rmg_core.hpp"

#include <algorithm>
#include <iterator>
#include <map>
#include <vector>

namespace aurelion::h3maped_rmg_core {{
namespace {{

struct CatalogSourceObjectRecord0x4c {{
\tint32_t source_row;
\tconst char *source;
\tconst char *def_name;
\tint32_t type_id_0x1c;
\tconst char *type_name;
\tint32_t metadata_bucket_index_0x08;
\tint32_t subtype_0x20;
\tint32_t group_0x24;
\tint32_t last_flag_0x28;
\tint32_t pass_count;
\tint32_t action_count;
\tuint16_t terrain_mask_a_0x14;
\tuint16_t terrain_mask_b_0x18;
\tbool descriptor_mask_fields_0x34_0x48_known;
\tbool descriptor_mask_fields_exact_def_msk;
\tint32_t descriptor_width_0x34;
\tint32_t descriptor_height_0x38;
\tuint64_t descriptor_mask_a_0x3c_0x40;
\tuint64_t descriptor_mask_b_0x44_0x48;
\tconst char *terrain_a_names;
\tconst char *terrain_b_names;
\tbool rand_trn_backed;
}};

static const CatalogSourceObjectRecord0x4c OBJECT_SOURCE_RECORDS_0X49DA08[] = {{
{chr(10).join(data_rows)}
}};

SourceObjectRecord0x4c to_public_record(const CatalogSourceObjectRecord0x4c &row) {{
\tSourceObjectRecord0x4c out;
\tout.source_row = row.source_row;
\tout.source = row.source;
\tout.def_name = row.def_name;
\tout.type_id_0x1c = row.type_id_0x1c;
\tout.type_name = row.type_name;
\tout.metadata_bucket_index_0x08 = row.metadata_bucket_index_0x08;
\tout.subtype_0x20 = row.subtype_0x20;
\tout.group_0x24 = row.group_0x24;
\tout.last_flag_0x28 = row.last_flag_0x28;
\tout.pass_count = row.pass_count;
\tout.action_count = row.action_count;
\tout.terrain_mask_a_0x14 = row.terrain_mask_a_0x14;
\tout.terrain_mask_b_0x18 = row.terrain_mask_b_0x18;
\tout.descriptor_mask_fields_0x34_0x48_known = row.descriptor_mask_fields_0x34_0x48_known;
\tout.descriptor_mask_fields_exact_def_msk = row.descriptor_mask_fields_exact_def_msk;
\tout.descriptor_width_0x34 = row.descriptor_width_0x34;
\tout.descriptor_height_0x38 = row.descriptor_height_0x38;
\tout.descriptor_mask_a_0x3c_0x40 = row.descriptor_mask_a_0x3c_0x40;
\tout.descriptor_mask_b_0x44_0x48 = row.descriptor_mask_b_0x44_0x48;
\tout.terrain_a_names = row.terrain_a_names;
\tout.terrain_b_names = row.terrain_b_names;
\tout.rand_trn_backed = row.rand_trn_backed;
\treturn out;
}}

std::vector<SourceObjectRecord0x4c> build_source_object_catalog() {{
\tstd::vector<SourceObjectRecord0x4c> records;
\trecords.reserve(sizeof(OBJECT_SOURCE_RECORDS_0X49DA08) / sizeof(OBJECT_SOURCE_RECORDS_0X49DA08[0]));
\tfor (const CatalogSourceObjectRecord0x4c &row : OBJECT_SOURCE_RECORDS_0X49DA08) {{
\t\trecords.push_back(to_public_record(row));
\t}}
\treturn records;
}}

std::vector<SourceObjectWrapperBucket0xe8> build_source_object_wrapper_buckets() {{
\tstd::vector<SourceObjectWrapperBucket0xe8> buckets;
\tbuckets.resize(SOURCE_OBJECT_WRAPPER_BUCKET_COUNT_0XE8);
\tfor (int32_t bucket_index = 0; bucket_index < SOURCE_OBJECT_WRAPPER_BUCKET_COUNT_0XE8; ++bucket_index) {{
\t\tSourceObjectWrapperBucket0xe8 &bucket = buckets[size_t(bucket_index)];
\t\tbucket.bucket_index_0x08 = bucket_index;
\t\tbucket.initialized_by_0x49db76 = true;
\t}}
\tconst std::vector<SourceObjectRecord0x4c> &records = source_object_catalog_0x49da08();
\tfor (int32_t index = 0; index < int32_t(records.size()); ++index) {{
\t\tconst SourceObjectRecord0x4c &record = records[size_t(index)];
\t\tif (record.metadata_bucket_index_0x08 < 0 || record.metadata_bucket_index_0x08 >= SOURCE_OBJECT_WRAPPER_BUCKET_COUNT_0XE8) {{
\t\t\tcontinue;
\t\t}}
\t\tSourceObjectWrapperBucket0xe8 &bucket = buckets[size_t(record.metadata_bucket_index_0x08)];
\t\tif (bucket.record_count == 0) {{
\t\t\tbucket.first_source_record_index = index;
\t\t\tbucket.first_type_id_0x1c = record.type_id_0x1c;
\t\t\tbucket.first_type_name = record.type_name;
\t\t}}
\t\tbucket.last_source_record_index = index;
\t\tbucket.record_count += 1;
\t\tbucket.source_record_indices.push_back(index);
\t}}
\treturn buckets;
}}

}} // namespace

const std::vector<SourceObjectRecord0x4c> &source_object_catalog_0x49da08() {{
\tstatic const std::vector<SourceObjectRecord0x4c> records = build_source_object_catalog();
\treturn records;
}}

SourceObjectCatalogSummary0x49da08 source_object_catalog_summary_0x49da08() {{
\tconst std::vector<SourceObjectRecord0x4c> &records = source_object_catalog_0x49da08();
\tSourceObjectCatalogSummary0x49da08 summary;
\tsummary.record_count = int32_t(records.size());
\tsummary.source_record_copy_size_bytes = SOURCE_OBJECT_RECORD_COPY_SIZE_BYTES_0X4C;
\tsummary.descriptor_mask_field_record_count = {msk_known_count};
\tsummary.descriptor_mask_exact_def_msk_count = {msk_exact_count};
\tsummary.descriptor_mask_default_msk_fallback_count = {msk_default_count};
\tstd::map<int32_t, int32_t> mine_subtype_counts;
\tfor (const SourceObjectRecord0x4c &record : records) {{
\t\tif (record.source == "objects.txt") {{
\t\t\tsummary.objects_txt_record_count += 1;
\t\t}}
\t\tif (record.rand_trn_backed) {{
\t\t\tsummary.rand_trn_backed_record_count += 1;
\t\t}}
\t\tif (record.type_id_0x1c == 53) {{
\t\t\tsummary.mine_type53_record_count += 1;
\t\t\tmine_subtype_counts[record.subtype_0x20] += 1;
\t\t}}
\t}}
\tfor (const auto &entry : mine_subtype_counts) {{
\t\tif (entry.second > 1) {{
\t\t\tsummary.mine_type53_ambiguous_subtype_count += 1;
\t\t}}
\t}}
\tsummary.descriptor_only_mine_identity_ambiguous = summary.mine_type53_ambiguous_subtype_count > 0;
\treturn summary;
}}

std::vector<SourceObjectRecord0x4c> source_object_records_by_type_0x49da08(int32_t type_id) {{
\tstd::vector<SourceObjectRecord0x4c> matches;
\tconst std::vector<SourceObjectRecord0x4c> &records = source_object_catalog_0x49da08();
\tstd::copy_if(records.begin(), records.end(), std::back_inserter(matches), [type_id](const SourceObjectRecord0x4c &record) {{
\t\treturn record.type_id_0x1c == type_id;
\t}});
\treturn matches;
}}

std::vector<SourceObjectRecord0x4c> source_object_records_by_type_subtype_0x49da08(int32_t type_id, int32_t subtype) {{
\tstd::vector<SourceObjectRecord0x4c> matches;
\tconst std::vector<SourceObjectRecord0x4c> &records = source_object_catalog_0x49da08();
\tstd::copy_if(records.begin(), records.end(), std::back_inserter(matches), [type_id, subtype](const SourceObjectRecord0x4c &record) {{
\t\treturn record.type_id_0x1c == type_id && record.subtype_0x20 == subtype;
\t}});
\treturn matches;
}}

const std::vector<SourceObjectWrapperBucket0xe8> &source_object_wrapper_buckets_0x49db76() {{
\tstatic const std::vector<SourceObjectWrapperBucket0xe8> buckets = build_source_object_wrapper_buckets();
\treturn buckets;
}}

SourceObjectWrapperBucketSummary0xe8 source_object_wrapper_bucket_summary_0x49db76() {{
\tconst std::vector<SourceObjectRecord0x4c> &records = source_object_catalog_0x49da08();
\tconst std::vector<SourceObjectWrapperBucket0xe8> &buckets = source_object_wrapper_buckets_0x49db76();
\tSourceObjectWrapperBucketSummary0xe8 summary;
\tsummary.bucket_count = int32_t(buckets.size());
\tfor (const SourceObjectWrapperBucket0xe8 &bucket : buckets) {{
\t\tif (bucket.initialized_by_0x49db76) {{
\t\t\tsummary.initialized_bucket_count += 1;
\t\t}}
\t\tif (bucket.record_count > 0) {{
\t\t\tsummary.non_empty_bucket_count += 1;
\t\t\tsummary.total_source_record_references += bucket.record_count;
\t\t\tif (bucket.record_count > summary.max_bucket_record_count) {{
\t\t\t\tsummary.max_bucket_record_count = bucket.record_count;
\t\t\t\tsummary.max_bucket_index_0x08 = bucket.bucket_index_0x08;
\t\t\t}}
\t\t}}
\t}}
\tfor (const SourceObjectRecord0x4c &record : records) {{
\t\tif (record.metadata_bucket_index_0x08 < 0 || record.metadata_bucket_index_0x08 >= SOURCE_OBJECT_WRAPPER_BUCKET_COUNT_0XE8) {{
\t\t\tsummary.out_of_range_source_record_count += 1;
\t\t}}
\t}}
\treturn summary;
}}

bool source_object_wrapper_bucket_by_index_0x49db76(int32_t bucket_index, SourceObjectWrapperBucket0xe8 &out_bucket) {{
\tconst std::vector<SourceObjectWrapperBucket0xe8> &buckets = source_object_wrapper_buckets_0x49db76();
\tif (bucket_index < 0 || bucket_index >= int32_t(buckets.size())) {{
\t\treturn false;
\t}}
\tout_bucket = buckets[size_t(bucket_index)];
\treturn true;
}}

}} // namespace aurelion::h3maped_rmg_core
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--metadata", type=Path, default=DEFAULT_METADATA)
    parser.add_argument("--msk-dir", type=Path, action="append", default=[])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    msk_dirs = [path.resolve() for path in (args.msk_dir or DEFAULT_MSK_DIRS)]
    missing_dirs = [str(path) for path in msk_dirs if not path.exists()]
    if missing_dirs:
        raise FileNotFoundError(f"missing .msk directories: {missing_dirs}")

    with args.catalog.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    with args.metadata.open(newline="", encoding="utf-8") as handle:
        metadata_bucket_by_type = {
            i32(row.get("type_id"), -1): i32(row.get("bucket_index"))
            for row in csv.DictReader(handle)
            if i32(row.get("type_id"), -1) >= 0
        }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(render(args.catalog, args.metadata, msk_dirs, rows, metadata_bucket_by_type), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
