# Native RMG Authored Object Pool Adoption (#10223)

## Scope

This owner-directed slice answers whether every authored Overworld object is in the random-map pool. The answer is now explicit and machine-checked: every one of the 422 authored map-object ids has exactly one eligibility decision. Compatible objects are selectable through a data-driven post-projection pool; scenario-owned, metadata-only, or currently unsafe objects carry a concrete exclusion reason.

This work does not modify recovered H3MapEd generation. Native phases, source object order, coordinates, body/action masks, passability, topology, RNG calls, and final payload bytes remain authoritative and unchanged. Original Aurelion content selection occurs only after the recovered final payload has been hashed and projected.

## Baseline finding

The previous proxy catalog had 43 rows (42 live) and referenced 26 distinct authored map-object ids. That did not mean the other authored objects lacked art: all 422 definitions already had distinct original raster assignments. It meant the native package projection could only attach a narrow set of original gameplay identities. Representative native maps still contained visitable raw `h3m_object` records, including source arenas, markets, cartographers, banks, creature generators, monoliths, schools, and huts.

Decorative blockers were a separate renderer-owned category. All 200 authored decorative definitions were manifest-mapped, and the native blocker renderer already selected from the 154 blocking members; the 46 passable scenic decorations cannot be injected without a new nonblocking native placement pass, which would change topology.

## Implementation

`content/random_map_object_eligibility.json` is the authoritative registry. Its eight pools cover:

- 154 renderer-owned decorative blockers;
- 8 live resource pickups;
- 27 persistent economy sites;
- 69 neutral dwellings;
- 16 live guarded rewards;
- 35 interactable sites and faction landmarks;
- 27 live transit/route objects; and
- all 69 artifact definitions for artifact-bearing source records.

Of the 422 map objects, 336 are eligible and 86 are intentionally excluded: 46 passable scenic decorations, 16 metadata-only guarded rewards, 4 pickups without a live resource-site surface, and 20 scenario-owned objectives/encounters.

`MapPackageService` now loads the registry and original content catalogs after native final-payload projection. Existing exact type/subtype proxy rows retain their established identities. Previously unmapped supported source types select from a compatible sorted authored pool using the stable map id, serialized source ordinal, type, subtype, and pool id. Each projected record carries its pool, candidate count/id, selection mode/token, and unchanged-placement/final-payload boundary.

Normal visitable source records are fail-closed. A missing registry, empty mapped pool, explicit unsupported source type, or unclassified visitable type blocks package generation with its type id, subtype, DEF provenance name, serialized ordinal, and visit-tile count. Native towns and guards remain explicit runtime passthroughs. Nonvisitable native bodies remain owned by the original raster blocker renderer.

## Validation evidence

The focused report covers Small, Medium, Large, and Extra Large native workflows, validates all registry decisions and deterministic candidate selection, converts every generated payload to package documents, and reports zero unclassified visitable records.

| Size | Runtime objects | Pool-mapped | Passthrough | Renderer-owned nonvisitable | Unclassified visitable |
| --- | ---: | ---: | ---: | ---: | ---: |
| Small | 310 | 61 | 16 | 233 | 0 |
| Medium | 1,256 | 327 | 53 | 876 | 0 |
| Large | 2,841 | 745 | 110 | 1,986 | 0 |
| Extra Large | 5,059 | 1,316 | 239 | 3,504 | 0 |

Across the matrix, 2,449 records resolved through authored pools, 418 remained authoritative town/guard passthroughs, 6,599 nonvisitable bodies stayed with the raster renderer, and 166 distinct original candidate identities appeared. Package object counts matched native runtime object counts in every case.

Focused commands:

```text
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 600 --scene res://tests/native_random_map_homm3_re_object_table_proxy_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 180 --scene res://tests/random_map_object_pool_value_weighting_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 180 --scene res://tests/overworld_map_object_sprite_asset_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 180 --scene res://tests/overworld_decorative_sprite_asset_report.tscn
python3 tests/validate_repo.py
git diff --check
python3 tests/packaging_linux_export_smoke.py
python3 tests/packaging_windows_export_smoke.py
```

The authored sprite reports retain all 422 distinct original map-object assignments and all 200 decorative assignments with procedural fallback disabled in their tested runtime presentations. Linux and Windows release exports both passed with the same 244,974,124-byte PCK, 5,025,876 bytes below the unchanged 250 MB ceiling. Linux headless boot passed. The Windows fresh-Wine gate passed Boot, Main Menu, native-DLL loading, generated setup, generated Overworld entry, and generated Town entry.

This is original-content adoption over recovered native placement, not a claim that Aurelion implements the copyrighted source game's object effects. It does not claim new RMG placement categories, exact foreign object semantics, save-schema changes, balance changes, native Windows hardware certification, signing, publication, whole-game validation, or release readiness.
