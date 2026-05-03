# Map/Scenario GDExtension Persistence Foundation

Status: specification source plus native generated-package startup evidence; minimal package save/load is implemented for the generated RMG startup path.
Date: 2026-05-03.
Slice: map-scenario-gdextension-persistence-foundation-10184.

## Purpose

Maps and scenarios need durable structure before broad authored-scenario, generated-skirmish, editor-export, or save/load production work depends on the current loose JSON and Dictionary payloads.

This document specifies the target map/scenario document model, package format, Godot GDExtension API, migration lifecycle, RMG bridge, validation gates, and implementation staging. The 2026-05-03 owner-directed generated-startup slice implements only the narrow native RMG package save/load/start path; it does not complete authored content migration, save-schema replacement, broad package migration, renderer/fog/pathing redesign, or campaign adoption.

The selected direction is a C++ Godot GDExtension that owns typed map package parsing, validation, serialization, migration, deterministic identity, and corruption checks, while existing GDScript services remain the first integration layer until implementation slices deliberately move responsibilities.

## Source Evidence

Current inspected code paths:

- `scripts/core/RandomMapGeneratorRules.gd`
- `scripts/core/ScenarioSelectRules.gd`
- `scripts/core/ScenarioFactory.gd`
- `scripts/core/SessionStateStore.gd`
- `scripts/autoload/ContentService.gd`
- `scripts/autoload/SaveService.gd`
- `content/scenarios.json`
- `tests/random_map_generated_overworld_profile_report.tscn`

Current RMG reality:

- `RandomMapGeneratorRules.generate(input_config)` returns a `Dictionary` with `ok`, `generated_map`, and `report`.
- `generated_map` is a nested Dictionary, not a typed document. It currently includes `schema_id`, `source`, `write_policy`, `metadata`, `phase_pipeline`, `staging`, `scenario_record`, `terrain_layers_record`, `runtime_materialization`, `generated_export`, and a `stable_signature`.
- The generator builds useful structured staging data, including template/profile metadata, zone graph/layout, terrain rows, object placements, constraints, validation, route proofs, fairness reports, roads/rivers writeout, generated export records, and runtime materialization identity.
- That staging structure is valuable, but it is not a durable package boundary. It mixes authoring/debug/provenance data with runtime scenario data in one large in-memory payload.

Current generated skirmish/session reality:

- As of the owner-directed generated-package startup slice, `ScenarioSelectRules.gd` requires native `MapPackageService` for the player-facing generated skirmish setup.
- `build_random_map_skirmish_setup` calls native `generate_random_map`, converts the native output to map/scenario documents, saves `.amap` and `.ascenario` packages under the active maps directory, then loads those packages back before launch.
- A valid generated setup carries package refs, validation, retry status, provenance, replay metadata, and explicit `campaign_adoption: false`; it does not carry the old giant `scenario_record`/`terrain_layers_record` generated payload as the active startup handoff.
- `start_random_map_skirmish_session_from_setup` launches through `NativeRandomMapPackageSessionBridge.build_session_from_loaded_packages(...)`.
- The launch boundary intentionally preserves `authored_content_writeback: false`, `campaign_adoption: false`, `skirmish_browser_authored_listing: false`, `content_service_generated_draft: false`, and `legacy_json_scenario_record: false`.
- Generated provenance and replay metadata are copied into both `session.flags` and `session.overworld`.
- `ScenarioFactory.gd` and `ContentService.register_generated_scenario_draft(...)` remain available only as legacy/dev/test compatibility paths. They are not the active player-facing generated skirmish startup path.
- `ContentService.register_generated_scenario_draft(...)` rejects authored id collisions, requires `generated=true`, and returns `write_policy: memory_only_no_authored_json_write`.
- `SaveService._ensure_generated_random_map_scenario_registered(...)` restores a missing generated scenario by regenerating from saved seed/config provenance and comparing stable/materialized/export signatures before re-registering a transient draft.

Current authored scenario reality:

- `content/scenarios.json` is one large authored scenario domain. At inspection it is about 244 KB with 16 scenario records.
- Each scenario record mixes scenario metadata and launch selection with tile rows and gameplay placements. Representative keys include `id`, `name`, `selection`, `map`, `map_size`, `start`, `hero_id`, `hero_starts`, `player_faction_id`, `player_army_id`, `starting_resources`, `towns`, `resource_nodes`, `artifact_nodes`, `encounters`, `objectives`, `script_hooks`, and `enemy_factions`.
- `ContentService.get_authored_scenario(id)` loads records from `content/scenarios.json`; `get_scenario(id)` prefers authored content and then falls back to in-memory generated drafts.
- `ContentService.validate_all_content()` indexes `content/scenarios.json` and validates scenario fields, terrain-layer links, object references, objectives, script hooks, and campaign membership.

Current save/load reality:

- `SessionStateStore.SessionData.to_dict()` serializes `save_version`, `session_id`, `scenario_id`, `hero_id`, `day`, `difficulty`, `launch_mode`, `game_state`, `scenario_status`, `scenario_summary`, `overworld`, `battle`, and `flags`.
- `SaveService._save_raw_dictionary()` calls `JSON.stringify(payload, "\t")`, opens a `FileAccess.WRITE` handle, writes the raw JSON string, and records stringify/write timing in an optional profile bucket.
- Existing generated-map save compatibility relies on storing enough provenance to regenerate and re-register a transient generated scenario, not on loading a durable map asset.
- Existing profile evidence from `tests/random_map_generated_overworld_profile_report.tscn` shows a Small 36x36 generated-map save writing about 6.95 MB JSON and taking roughly 202-219 ms in the save path. This is already too expensive for a full-payload rewrite model and will scale poorly for larger maps, richer object state, editor metadata, and future campaigns.

## Current Structural Risks

The main risk is not that JSON exists. The risk is that map identity, map content, scenario rules, generated staging, transient session state, and mutable save data are not separated enough.

Specific risks:

- A generated map has no typed map object with enforced ownership, schema, ids, bounds, layers, object indexes, route metadata, and validation state.
- Authored scenarios and generated scenarios use similar loose Dictionary shapes, but generated scenarios need stronger provenance, package identity, and no-writeback guarantees.
- Saves can balloon because mutable runtime state may carry generated-map materialization, provenance, and large nested dictionaries that are closer to full map content than compact deltas.
- Existing JSON payloads are costly to stringify, write, diff, validate, and migrate as generated-map size and object density increase.
- `content/scenarios.json` is a single edit and merge hotspot. It cannot scale cleanly to production map packages, generated packages, editor exports, or mod-style content packs.
- Dictionary payloads make invalid states easy: out-of-bounds coordinates, duplicate placement ids, inconsistent map dimensions, stale terrain-layer ids, missing object content ids, and mismatched generated signatures can survive until a late load or gameplay path.
- Deterministic identity is currently produced by GDScript stable stringification/hash helpers. Future package identity needs a canonical cross-language algorithm so C++, GDScript, CI, and tools agree.
- Generated provenance currently restores by regeneration. That remains useful, but durable generated packages should not require generator code to produce identical output forever just to load an existing save.

## Maps Directory Semantics

The generated package startup path uses `ScenarioSelectRules.generated_map_package_directory_policy()`.

- In editor/dev/headless runs, the active maps directory is `res://maps`, which resolves to the repository-root `maps/` directory. This makes generated packages inspectable during development and keeps the owner-directed path explicit.
- In exported/runtime builds, the policy target is `user://maps`, because exported `res://` content is not a reliable writable package location.
- Generated startup writes one `.amap` map package and one `.ascenario` scenario package. The game then loads those files back from disk and builds the session from the loaded documents.
- Generated package filenames use a shared deterministic lowercase kebab stem for the paired `.amap`/`.ascenario` files. The stem shape is `size-creative-name-seed`: the size token, a deterministic creative name derived from normalized seed/config, and the normalized seed. Template/profile/player-count/water-mode/dimensions/hash details stay in package metadata and refs instead of the filename.
- These generated packages are not authored content and are not written into `content/scenarios.json`.
- `content/scenarios.json` remains archived/dev compatibility content unless a later migration slice replaces it with a manifest/package catalog.
- Native package save/load currently serializes a compact package document envelope sufficient for generated startup. `migrate_*` and full authored-package migration remain intentionally minimal/not implemented and must not be claimed as complete.

## Target Ownership Model

Separate four document/state layers:

1. `MapDocument`: immutable terrain/layer/object/topology package for one map.
2. `ScenarioDocument`: immutable scenario rules and launch metadata that reference a map package.
3. `SessionDelta`: mutable runtime state for a playthrough of one scenario on one map package.
4. `ContentManifest`: stable index that maps ids to package paths, hashes, schema versions, content-pack ids, and migration status.

Ownership rules:

- Authored and generated map packages are immutable once referenced by a save.
- Runtime saves reference immutable packages by `map_id`, `map_hash`, `map_schema_version`, and optional `package_uri`, then store only mutable deltas where practical.
- Generated drafts may remain memory-only during the first bridge, but once exported as a package, package identity becomes authoritative for load.
- GDScript services own user-facing orchestration, content catalog integration, save-slot UI, and adapter calls.
- The C++ GDExtension owns map/scenario package parsing, validation, canonical serialization, hashing, migration, and package save/load.
- Gameplay rules continue to consume GDScript-friendly dictionaries until deliberate runtime adoption slices replace specific call sites with typed resources or adapters.

## Document Boundaries

### MapDocument

`MapDocument` is terrain and map-object structure, not a full play session and not a campaign chapter.

Required identity fields:

- `schema_id`: `aurelion_map_document`
- `schema_version`: integer, starting at `1`
- `map_id`: stable lowercase id unique within the content manifest
- `source_kind`: `authored`, `generated`, `editor_draft`, `imported_legacy_json`, or `test_fixture`
- `content_pack_id`: stable pack id, default `base`
- `display_name`: author-facing title
- `created_with`: tool/generator/editor id and version
- `map_hash`: canonical package hash computed over immutable chunks
- `content_manifest_hash`: hash of referenced content ids and versions, when available
- `generator_identity`: present only for generated maps

Required geometry fields:

- `width`
- `height`
- `level_count`
- `coordinate_system`: `tile_xy_level0_origin_top_left`
- `tile_count`: width times height times level count
- `size_class`: current RMG size class where applicable
- `water_mode`: current RMG water mode where applicable

Required map content:

- terrain base layer
- terrain overlay layers, including road/river/coast/special overlays as separate encoded streams
- optional biome/region/zone ids
- object placements with stable `placement_id`, `content_id`, coordinates, level, body/visit metadata, ownership metadata, and authored/generated source metadata
- town placements
- resource site placements
- encounter/guard placements
- artifact/reward placements
- scenario-objective location anchors
- optional route graph and required reachability proof
- validation report summary
- provenance and audit chunks

`MapDocument` must not store:

- current day, active hero movement points, discovered fog state, depleted pickups, captured owner state, battle-in-progress state, or UI state
- campaign unlocks or progression
- generated-map temporary staging that is not needed for durable validation, package migration, or regeneration/replay proof

### ScenarioDocument

`ScenarioDocument` references one `MapDocument` and stores scenario rules, setup, and launch metadata.

Required identity fields:

- `schema_id`: `aurelion_scenario_document`
- `schema_version`: integer, starting at `1`
- `scenario_id`
- `scenario_hash`
- `map_ref`: `{map_id, map_hash, map_schema_version, package_uri}`
- `content_pack_id`
- `source_kind`
- `display_name`
- `selection`: launch metadata equivalent to current selection records

Required scenario content:

- launch mode availability
- recommended difficulty and player summary
- player slots, factions, teams, AI flags
- starting hero contracts and starting resources
- objective definitions
- supported script hooks
- enemy faction pressure definitions
- campaign linkage only by ids/references
- authoring/provenance metadata

`ScenarioDocument` must not inline the full map terrain or full generated staging payload. It may include small anchor references into the map such as placement ids, region ids, or objective anchor ids.

### SessionDelta

`SessionDelta` is the future save payload shape. It can live in JSON first, but its contract must be reference/delta based.

Required fields:

- `save_version`
- `session_id`
- `scenario_ref`: `{scenario_id, scenario_hash, scenario_schema_version, package_uri}`
- `map_ref`: `{map_id, map_hash, map_schema_version, package_uri}`
- `content_manifest_ref`: `{manifest_id, manifest_hash}`
- current hero/town/player/day/game-state data
- mutable map deltas only: visited/picked/captured/depleted/owned state, fog explored tiles, spawned/removed objects, mutable town/resource/encounter state, battle handoff state
- generated provenance pointer for generated maps, not a full generated map payload
- compatibility block for old save fields until migration completes

`SessionDelta` must not copy immutable terrain rows, full object catalog definitions, or authored scenario definitions once package references are authoritative.

### ContentManifest

The manifest is the future replacement for treating `content/scenarios.json` as the authoritative scenario universe.

Recommended shape:

```json
{
  "schema_id": "aurelion_content_manifest",
  "schema_version": 1,
  "content_pack_id": "base",
  "maps": [
    {
      "map_id": "river-pass",
      "map_hash": "sha256:...",
      "schema_version": 1,
      "package_uri": "res://content/maps/river-pass.amap",
      "source_kind": "authored"
    }
  ],
  "scenarios": [
    {
      "scenario_id": "river-pass",
      "scenario_hash": "sha256:...",
      "schema_version": 1,
      "package_uri": "res://content/scenarios/river-pass.ascenario",
      "map_id": "river-pass",
      "map_hash": "sha256:..."
    }
  ]
}
```

Initial implementation may use JSON manifests and binary map packages. The manifest is an index, not the map payload.

## GDScript And C++ Ownership

### GDScript Keeps

- `ContentService.gd`: content catalog, manifest lookup, legacy JSON fallback, generated draft registry during bridge phases.
- `SaveService.gd`: save-slot UI and compatibility orchestration, old-save migration handoff, package-reference validation before loading.
- `SessionStateStore.gd`: session data normalization until a later save-state refactor.
- `ScenarioFactory.gd`: scenario bootstrap adapters.
- `ScenarioSelectRules.gd`: generated skirmish setup and UX-facing provenance until package-backed generation is adopted.
- `RandomMapGeneratorRules.gd`: current GDScript generator until the bridge is stable and a separate generator rewrite is selected.

### C++ GDExtension Owns

- `MapDocument` typed model.
- `ScenarioDocument` typed model.
- `MapPackageReader` and `MapPackageWriter`.
- Package validation and validation reports.
- Deterministic canonical serialization and hashing.
- Legacy scenario JSON to document conversion helpers.
- JSON save legacy map-reference migration helpers.
- Package migration between schema versions.
- Binary chunk corruption checks.
- Optional async load/save jobs with immutable result handoff.

### Adapter Principle

Early implementation should return GDScript dictionaries at the boundary for compatibility, but those dictionaries must be produced from typed documents and must be explicitly lossy or compatibility-shaped.

Example adapter names:

- `MapDocument.to_legacy_scenario_map_rows()`
- `MapDocument.to_legacy_terrain_layers_record()`
- `ScenarioDocument.to_legacy_scenario_record()`
- `MapPackageService.load_scenario_legacy_record(scenario_ref)`
- `MapPackageService.export_generated_payload(generated_map_dictionary, options)`

The adapter must never make old Dictionary shapes the authoritative storage format.

## Proposed GDExtension API

Class names are design-level names. Implementation may choose exact C++ filenames and binding macro layout later, but the GDScript-visible API should preserve these responsibilities.

### `MapDocument`

Godot type: `Resource` or `RefCounted`; prefer `Resource` if editor inspector/file references become useful, otherwise `RefCounted` for immutable runtime handles.

Design-level methods:

```gdscript
func get_schema_version() -> int
func get_map_id() -> String
func get_map_hash() -> String
func get_source_kind() -> String
func get_width() -> int
func get_height() -> int
func get_level_count() -> int
func get_tile_count() -> int
func get_metadata() -> Dictionary
func get_terrain_layer_ids() -> PackedStringArray
func get_tile_layer_u16(layer_id: String, level: int = 0) -> PackedInt32Array
func get_object_count() -> int
func get_object_by_index(index: int) -> Dictionary
func get_object_by_placement_id(placement_id: String) -> Dictionary
func get_objects_in_rect(rect: Rect2i, level: int = 0) -> Array[Dictionary]
func get_route_graph() -> Dictionary
func get_validation_summary() -> Dictionary
func to_legacy_scenario_record_patch() -> Dictionary
func to_legacy_terrain_layers_record() -> Dictionary
```

Data ownership:

- Terrain/layer data is stored internally in typed contiguous arrays.
- Returned `Packed*Array` values are copies or immutable snapshots. GDScript must not mutate the source document.
- Object records returned as dictionaries are compatibility snapshots.
- Full object arrays should be avoided in hot runtime paths; spatial query methods should exist before renderer/pathing adoption.

### `ScenarioDocument`

Godot type: `Resource` or `RefCounted`.

Design-level methods:

```gdscript
func get_schema_version() -> int
func get_scenario_id() -> String
func get_scenario_hash() -> String
func get_map_ref() -> Dictionary
func get_selection() -> Dictionary
func get_player_slots() -> Array[Dictionary]
func get_objectives() -> Dictionary
func get_script_hooks() -> Array[Dictionary]
func get_enemy_factions() -> Array[Dictionary]
func get_start_contract() -> Dictionary
func to_legacy_scenario_record(map_document: MapDocument) -> Dictionary
```

Scenario validation must verify that every map placement id referenced by objectives, hooks, starts, towns, resources, encounters, and artifacts exists in the referenced `MapDocument`.

### `MapPackageService`

Godot type: singleton-like `Object` exposed by GDExtension, or autoload wrapper around a `RefCounted` service instance.

Design-level methods:

```gdscript
func load_map_package(path: String, options: Dictionary = {}) -> Dictionary
func load_scenario_package(path: String, options: Dictionary = {}) -> Dictionary
func validate_map_document(map_document: MapDocument, options: Dictionary = {}) -> Dictionary
func validate_scenario_document(scenario_document: ScenarioDocument, map_document: MapDocument, options: Dictionary = {}) -> Dictionary
func save_map_package(map_document: MapDocument, path: String, options: Dictionary = {}) -> Dictionary
func save_scenario_package(scenario_document: ScenarioDocument, path: String, options: Dictionary = {}) -> Dictionary
func migrate_map_package(source_path: String, target_path: String, target_version: int, options: Dictionary = {}) -> Dictionary
func migrate_scenario_package(source_path: String, target_path: String, target_version: int, options: Dictionary = {}) -> Dictionary
func convert_legacy_scenario_record(scenario_record: Dictionary, terrain_layers_record: Dictionary, options: Dictionary = {}) -> Dictionary
func convert_generated_payload(generated_map: Dictionary, options: Dictionary = {}) -> Dictionary
func compute_document_hash(document: Variant, options: Dictionary = {}) -> Dictionary
func inspect_package(path: String, options: Dictionary = {}) -> Dictionary
func normalize_random_map_config(config: Dictionary) -> Dictionary
func random_map_config_identity(config: Dictionary) -> Dictionary
func generate_random_map(config: Dictionary, options: Dictionary = {}) -> Dictionary
```

Return shape:

```gdscript
{
  "ok": true,
  "status": "pass",
  "map_document": MapDocument,
  "scenario_document": ScenarioDocument,
  "report": {},
  "warnings": [],
  "errors": []
}
```

Failure shape:

```gdscript
{
  "ok": false,
  "status": "fail",
  "error_code": "checksum_mismatch",
  "message": "Map package checksum did not match manifest.",
  "report": {
    "schema_id": "aurelion_map_validation_report",
    "schema_version": 1,
    "failures": []
  },
  "recoverable": false
}
```

### Native RMG Foundation Slice

The first native RMG slice is deliberately smaller than a generator port. It may add
`MapPackageService.generate_random_map(config)` as a design-level API surface, but
only for deterministic foundation behavior:

- normalize the minimal config fields `seed`, `width`, `height`, `level_count`,
  `template_id`, `profile_id`, `size_class_id`, and `water_mode`;
- compute a stable foundation identity from canonical normalized config data;
- return an empty generated `MapDocument` stub with dimensions, source kind,
  generated metadata, and the deterministic identity;
- report `status: partial_foundation` and `full_generation_status: not_implemented`.

This slice must not place terrain, objects, roads, towns, encounters, rewards, or
validation parity data. `RandomMapGeneratorRules.gd` remains authoritative for live
generated skirmish gameplay until later parity and adoption slices explicitly move
call sites.

### Native RMG Terrain/Grid Child Slice

The first real native parity child adds deterministic terrain/grid generation while
still preserving the broader `partial_foundation` status. The C++ API may return a
typed terrain-grid `Dictionary` with dimensions, tile count, terrain code table,
packed terrain codes, biome mapping, deterministic terrain seed records, terrain
counts, and stable signatures. This is structural parity scaffolding for the
GDScript generator's terrain rows and zone-seeded terrain/biome phase only.

This child still must not place objects, roads, rivers, towns, guards, validation
parity, package conversion data, session adoption data, save migrations, or any
claim that native RMG has full parity. Linux and Windows helper/docs remain in
sync because the existing cross-platform GDExtension build and manifest paths are
unchanged; only C++ service behavior and focused smoke coverage are extended.

### Native RMG Zone/Player-Start Child Slice

The next native parity child adds a practical foundation for deterministic zones
and player starts. The C++ API now extends `generate_random_map(config)` with
normalized player constraints, profile faction/town assignment, team metadata,
fallback runtime zones, zone seed anchors, weighted owner-grid assignment, zone
bounds/cell counts/terrain association, player start coordinates, minimum spacing
metadata, and stable zone/start signatures.

This is still structural scaffolding, not full template parity. It does not consume
the full template catalog, place towns/objects/roads/rivers/guards, validate
GDScript parity, write packages, change saves, or replace
`RandomMapGeneratorRules.gd` call sites. The result and report explicitly expose
`zone_generation_status: zones_generated_foundation` and
`player_start_generation_status: player_starts_generated_foundation` while keeping
top-level `status: partial_foundation` and
`full_generation_status: not_implemented`.

Linux and Windows build expectations remain synchronized through the existing
cross-platform GDExtension manifest/build outputs. No helper-script change is
required for this slice; the generic native build path plus focused Godot smokes
exercise the same native service entry points on both platforms.

### Native RMG Road/River Network Child Slice

The road/river child extends the native foundation with deterministic route
records over the existing terrain, zones, and player starts. The C++ API now
returns a route graph, route nodes, route edges, staged road overlay segments,
route cell records, required player-start coverage, and a reachability proof. It
also returns bounded river/waterline feature records with explicit metadata-only
materialization state so the native result exposes route feature structure without
mutating terrain tiles or adopting gameplay behavior.

This remains a foundation slice. It does not place towns, guards, resources,
encounters, objects, validate full GDScript parity, write packages, change saves,
replace `RandomMapGeneratorRules.gd` call sites, or claim full generation parity.
The result and report expose `road_generation_status:
roads_generated_foundation`, `river_generation_status:
rivers_generated_foundation`, road/route/river signatures, counts, and
reachability status while preserving top-level `status: partial_foundation` and
`full_generation_status: not_implemented`.

Linux and Windows expectations remain synchronized: the same GDExtension service
entry point is exercised by the Linux smoke and the Windows helper now includes
the focused native road/river report alongside the earlier native RMG reports.

### Native RMG Object Placement Foundation Child Slice

The object placement foundation child extends the native result with deterministic
non-town staged object records. The C++ API now returns resource pickup sites,
reward references, mine placeholders, neutral dwellings, and decorative obstacle
anchors with stable placement ids, family/type/object/category fields, zone and
terrain associations, road proximity metadata, 1x1 runtime body tiles,
footprints, occupancy indexes, category counts, and placement/occupancy
signatures. `MapDocument` stubs can expose the staged object records through
object count and placement lookup methods for API smoke coverage.

This remains a foundation slice. It does not place primary or neutral towns,
route guards, border guards, materialized encounters, gameplay rewards, package
writeout, save deltas, renderer/pathing/fog changes, GDScript RMG call-site
replacement, or any full-parity claim. The result and report expose
`object_generation_status: objects_generated_foundation`,
`object_placement_signature`, `object_occupancy_signature`, and object category
counts while preserving top-level `status: partial_foundation` and
`full_generation_status: not_implemented`.

Linux and Windows expectations remain synchronized because this slice only
extends the same GDExtension service surface and focused Godot smoke pattern; no
manifest, helper, or platform-specific build contract changes are required.

### `MapValidationReport`

Can be a Dictionary return first. A typed class may follow once report consumers stabilize.

Required report fields:

- `schema_id`: `aurelion_map_validation_report` or `aurelion_scenario_validation_report`
- `schema_version`
- `document_id`
- `document_hash`
- `status`: `pass`, `warning`, or `fail`
- `failure_count`
- `warning_count`
- `failures`: array of structured records
- `warnings`: array of structured records
- `metrics`: dimensions, tile counts, layer counts, object counts, route counts, package byte counts
- `content_ref_status`: missing/stale/mismatched referenced content ids
- `migration_status`: if converted or migrated
- `determinism`: canonical hash and serialization identity

Structured issue record:

```json
{
  "code": "object_out_of_bounds",
  "severity": "fail",
  "path": "objects[42]",
  "message": "Object placement is outside map bounds.",
  "context": {
    "placement_id": "..."
  }
}
```

### Async And Threading Assumptions

Default API must be synchronous and deterministic for tests, CLI tools, and migration scripts.

Async can be added as an implementation option:

- Package parsing, compression, hashing, and validation may run off the main thread.
- Godot `Object` creation and signal emission must return to the main thread.
- `MapDocument` and `ScenarioDocument` must be immutable after construction, so read-only handles can be safely shared after load completion.
- Async APIs must expose cancellation and a final result dictionary. They must not mutate global content registries from worker threads.

Possible async methods:

```gdscript
func load_map_package_async(path: String, options: Dictionary = {}) -> int
signal package_job_completed(job_id: int, result: Dictionary)
func cancel_package_job(job_id: int) -> Dictionary
```

## Error Model

Use stable error codes. Human messages may change; codes are testable.

Required initial codes:

- `file_not_found`
- `unsupported_schema_version`
- `invalid_magic`
- `invalid_header`
- `invalid_chunk_table`
- `missing_required_chunk`
- `unknown_required_chunk`
- `checksum_mismatch`
- `hash_mismatch`
- `compression_failed`
- `decompression_failed`
- `json_parse_failed`
- `invalid_legacy_record`
- `invalid_dimensions`
- `invalid_layer_length`
- `invalid_terrain_id`
- `object_out_of_bounds`
- `duplicate_placement_id`
- `missing_content_ref`
- `scenario_map_ref_mismatch`
- `migration_required`
- `migration_failed`
- `write_failed`
- `permission_denied`

Errors must classify `recoverable`:

- Recoverable: migration required, missing optional chunk, validation warnings, legacy compatibility fallback.
- Nonrecoverable: checksum mismatch, invalid magic/header, required chunk missing, hash mismatch against manifest, unsupported future schema without fallback.

## Deterministic Hashing

Package identity must not depend on Dictionary iteration order, locale, filesystem order, write timestamp, memory address, compression timestamp, or debug/profiling fields.

Hash rules:

- Use SHA-256 for package and document hashes. Current 32-bit signatures can remain compatibility metadata, not authority.
- Hash canonical uncompressed chunk payloads plus required chunk metadata, not raw compressed file bytes.
- Exclude package header write timestamp and optional debug/profiling chunks from authoritative document hash.
- Sort map object records by stable `placement_id` for canonical serialization unless package chunk encoding preserves explicit canonical order.
- Sort dictionary keys lexicographically when hashing JSON-compatible metadata.
- Normalize floats, if any appear, to a documented decimal representation. Prefer integers and fixed-point values for map package data.
- Include schema version and content reference versions in document hash.
- Store both `map_hash` and per-chunk hashes for corruption diagnosis.

## Durable Package Format

Recommended extension names:

- `.amap` for map packages.
- `.ascenario` for scenario packages.
- `.amanifest.json` for manifest/index files.

Use a binary chunked package for `.amap` and `.ascenario`, with JSON only for manifest/index files and optional human-readable debug exports. Binary chunks are preferred because terrain/layer arrays, object indexes, and route metadata should not pay JSON stringify/parse cost or indentation bloat on every save.

Binary-vs-JSON tradeoff:

- JSON is good for manifests, reviewable small scenario metadata, old-save compatibility, and debug exports.
- JSON is poor for large repeated terrain rows, dense objects, route indexes, and frequent saves because it inflates size and parse/stringify time.
- Binary chunks provide compact arrays, streaming reads, per-chunk hashes, optional compression, and versioned skip/required semantics.
- The implementation must still provide deterministic JSON debug export for validation and review, but debug export is not authoritative storage.

### Header

Header fields:

- magic: `AMAP` or `ASCN`
- package_version
- endian marker
- header_size
- chunk_table_offset
- chunk_count
- schema_id
- schema_version
- package_flags
- canonical_hash_algorithm: `sha256`
- package_hash
- required_feature_flags
- optional_feature_flags

### Chunk Table

Each chunk table entry:

- chunk_id: four-character or stable string id
- schema_version
- required: bool
- compression: `none`, `zstd`, or `deflate`
- uncompressed_size
- compressed_size
- offset
- chunk_hash
- semantic_hash_included: bool

Unknown optional chunks may be skipped. Unknown required chunks must fail with `unknown_required_chunk`.

### Map Package Chunks

Required initial map chunks:

- `META`: canonical JSON/CBOR metadata with map id, dimensions, source, content pack, display name, schema versions.
- `DICT`: string/id tables for terrain ids, overlay ids, object content ids, faction ids, region ids, and custom tags.
- `TERR`: base terrain tile stream encoded as `uint16` ids into `DICT`.
- `LAYR`: overlay/layer table and tile streams. Empty layers may be omitted only if the metadata declares absence.
- `OBJS`: object placement table.
- `SPAT`: object spatial index or index seed data for rebuild.
- `ROUT`: optional but recommended route graph, roads, path anchors, reachability classes.
- `VALD`: validation summary and validation hash.
- `PROV`: provenance/audit record.

Optional map chunks:

- `ZONE`: generated or authored regions/zone graph.
- `BIOM`: biome ownership/weights.
- `ROAD`: separate road network stream if not encoded in `LAYR`.
- `RIVR`: river/coast/water-transit stream.
- `FOOT`: expanded body/visit tile index.
- `DBGJ`: compressed debug JSON export, excluded from document hash.
- `RMGP`: full generated RMG provenance, if selected.
- `RMGD`: generated staging excerpts needed for diagnostics, excluded from runtime adapter by default.

### Scenario Package Chunks

Required initial scenario chunks:

- `META`: scenario id, display name, source, content pack, schema version.
- `MREF`: map reference `{map_id, map_hash, map_schema_version, package_uri}`.
- `SELC`: selection/launch metadata.
- `SLOT`: player slots, factions, teams, AI flags.
- `STRT`: start contracts, starting resources, starting heroes.
- `OBJT`: objectives.
- `HOOK`: supported script hooks.
- `ENMY`: enemy faction pressure definitions.
- `VALD`: validation summary.
- `PROV`: authoring/provenance record.

Optional scenario chunks:

- `CAMP`: campaign linkage metadata.
- `DBGJ`: debug JSON export, excluded from document hash.

### Terrain Encoding

Initial terrain encoding:

- Store base terrain as row-major `uint16` ids into the terrain dictionary.
- Store each overlay as sparse records if density is low, or dense `uint16` stream if density is high. The writer can choose based on byte estimate, but the chosen encoding must be recorded in chunk metadata.
- Store level-major order for multi-level maps: level 0 full stream, then level 1, and so on.
- Store bounds once in `META`; every dense layer must have exactly `width * height * level_count` entries.
- Store road/river/coast overlays separately from base terrain to preserve editing and validation semantics.

### Object Placement Encoding

Object placement fields:

- `placement_id`
- `content_domain`: map object, resource site, town, encounter, artifact, objective anchor, decorative
- `content_id`
- `x`, `y`, `level`
- `owner_id`
- `faction_id`
- `team_id`
- `body_tiles_ref` or explicit body local offsets
- `visit_tiles_ref` or explicit visit local offsets
- `state_seed` for deterministic generated defaults
- `source_tag`: authored/generated/editor
- `purpose_tags`: start support, expansion, contest, route control, reward pocket, objective, scenery
- `metadata_ref` for optional extra dictionary metadata

Indexes:

- placement id index
- content id index
- rect/spatial tile occupancy index
- visit tile index
- route/object anchor index

Indexes may be stored in package or rebuilt deterministically on load. If rebuilt, validation must prove rebuild identity.

### Compression

Recommended:

- Start with no compression for development packages and `zstd` for large terrain/layer/object chunks if dependency and build policy accept it.
- If zstd is too heavy for the first GDExtension slice, use Godot-compatible deflate or leave compression off while preserving chunk metadata fields.
- Compression must be per chunk, not whole file, so metadata and chunk table remain inspectable and corruption can be isolated.
- Compressed chunks must store uncompressed size and chunk hash over uncompressed canonical bytes.

### Corruption And Tamper Checks

Required checks:

- header magic and version
- chunk table bounds and overlap checks
- required chunk presence
- per-chunk hash validation
- document hash validation
- manifest hash match when loaded from manifest
- scenario `map_ref.map_hash` match
- optional user-save map hash match

Tamper handling:

- Authored content hash mismatch should fail load unless a developer override is explicitly passed.
- User generated packages may show a recoverable load warning only if package hash changes but internal chunk hashes validate and the save did not require the old hash. For normal saves, hash mismatch should block to prevent loading the wrong map under an old save.
- Debug chunks must not affect authoritative hash.

## Lifecycle

### Authored Maps

Initial authored lifecycle:

1. Convert one legacy scenario record and terrain-layer record into `MapDocument` and `ScenarioDocument` in a tool-only implementation slice.
2. Validate the documents against current `ContentService` reference checks.
3. Save packages beside current JSON as artifacts, not authority.
4. Load packages back and export legacy records.
5. Compare legacy-exported scenario behavior to the original scenario through focused scenario-load, save/load, and smoke tests.
6. Only after a later adoption slice, point the manifest at package files and keep JSON fallback.

Authored map packages must preserve provenance:

- source JSON file and original scenario id
- conversion tool version
- conversion timestamp excluded from document hash
- source hash of legacy JSON record
- validation report hash

### Generated Maps

Initial generated lifecycle:

1. Current GDScript RMG generates the existing Dictionary payload.
2. C++ `convert_generated_payload(...)` imports `scenario_record`, `terrain_layers_record`, `generated_export`, selected `staging`, validation, and provenance into typed documents.
3. GDExtension validates and writes `.amap` plus `.ascenario` into a generated draft cache when explicitly requested.
4. Generated skirmish setup stores package refs and provenance instead of the full generated payload once the bridge is adopted.
5. Save/load first tries package ref; if missing and allowed, it falls back to current regeneration from provenance.

Generated package policy:

- Generated packages are immutable once referenced by a save.
- Package path should include scenario id plus hash, for example `user://generated_maps/<scenario_id>/<map_hash>.amap`.
- The generator config and replay metadata remain in provenance, but durable load must not require generator replay when package exists.
- No generated package enters authored campaign or production content without a separate provenance/rollback/validation slice.

### Old `content/scenarios.json`

Migration plan:

- Phase A: keep `content/scenarios.json` authoritative. Add package conversion tools and reports only.
- Phase B: add `content/scenarios.manifest.json` or equivalent index that can list both legacy JSON scenarios and package-backed scenarios.
- Phase C: migrate a single test fixture or non-production scenario to package authority with JSON fallback.
- Phase D: migrate selected authored scenarios one at a time with rollback.
- Phase E: shrink `content/scenarios.json` to manifest-like metadata only after all live consumers use package/adapters.

Rollback:

- Every migrated scenario keeps its original JSON record until at least one release/test cycle passes.
- The manifest can flip a scenario back to `legacy_json` authority without changing scenario id.
- Conversion reports must include source and package hashes.

### Existing JSON Saves

Compatibility rules:

- Existing saves with `save_version <= 9` must continue to load through the current path until an explicit migration slice changes save version.
- Old saves that reference authored scenarios load via legacy scenario id first.
- Old generated-map saves keep regeneration fallback from provenance. Once package-backed generated saves exist, loader order is package ref, then provenance regeneration if policy permits.
- Save migration must be explicit and reversible: write migrated save to a new file or keep backup, never destructively rewrite the only copy.
- A save should not be considered migrated until it validates scenario/map package hash references and mutable deltas.

### Generated Draft Sessions

Generated draft sessions stay useful during the bridge:

- Memory-only drafts remain supported for test scenes and quick skirmish setup.
- Package export must be opt-in until load/save adapters are validated.
- Draft registration should eventually accept a `ScenarioDocument` plus `MapDocument` adapter, but it may keep storing legacy dictionaries internally until consumers are updated.

### Migrations

Migration requirements:

- C++ package migrators must be pure functions from source package bytes to target package bytes plus report.
- Migrations must validate before and after.
- Migration reports must name source version, target version, source hash, target hash, warnings, and irreversible fields if any.
- Migration code must support dry-run mode.
- Migration must reject unknown required chunks unless a registered migrator handles them.

## RMG Bridge Plan

Do not rewrite the generator first. Use the existing GDScript generator as the producer and the GDExtension as the typed package boundary.

Stage 1: export contract audit.

- Define which parts of current `generated_map` become authoritative package chunks.
- Keep `scenario_record`, `terrain_layers_record`, `generated_export`, `runtime_materialization`, validation summary, and stable identity.
- Move debug-heavy `staging` data into optional `RMGD`/`DBGJ` chunks or omit by policy.

Stage 2: importer.

- Implement `convert_generated_payload(generated_map, options)` in C++.
- Validate map dimensions, terrain rows, terrain layers, generated export tile streams, object writeout records, object placements, route graph, and provenance.
- Return typed documents and a report without writing files by default.

Stage 3: package write/read round trip.

- Save generated map/scenario packages under `user://generated_maps/`.
- Reload them and export legacy dictionaries.
- Compare `scenario_id`, dimensions, terrain rows, terrain layer signatures, object writeout signature, materialized map signature, route summary, and validation status.

Stage 4: session reference adoption.

- Generated skirmish setup includes package refs and hashes.
- Session flags keep provenance and replay metadata, but no longer need the full map payload when package ref is present.
- `SaveService` stores map/scenario refs plus deltas.

Stage 5: optional generator migration.

- Only after the package bridge is stable, decide whether to rewrite selected generator stages in C++ or keep GDScript generation with C++ package validation.

Bridge non-goals:

- No full C++ RMG rewrite.
- No campaign adoption.
- No authored content writeback.
- No renderer/pathing/fog semantic change.
- No package-backed saves until old-save compatibility and fallback are tested.

## Runtime Save Redesign

Future save payload should move from full dictionary snapshots toward reference plus delta.

Target top-level shape:

```json
{
  "save_version": 10,
  "session_id": "...",
  "scenario_ref": {
    "scenario_id": "...",
    "scenario_hash": "sha256:...",
    "schema_version": 1,
    "package_uri": "..."
  },
  "map_ref": {
    "map_id": "...",
    "map_hash": "sha256:...",
    "schema_version": 1,
    "package_uri": "..."
  },
  "content_manifest_ref": {
    "manifest_id": "base",
    "manifest_hash": "sha256:..."
  },
  "state": {
    "day": 1,
    "game_state": "overworld",
    "scenario_status": "in_progress",
    "heroes": {},
    "towns": {},
    "players": {},
    "fog": {},
    "map_deltas": {}
  },
  "generated_provenance_ref": {
    "schema_id": "generated_random_map_skirmish_provenance_v2",
    "generator_config_hash": "sha256:...",
    "package_hash": "sha256:..."
  },
  "compat": {
    "legacy_save_version": 9
  }
}
```

Delta examples:

- collected pickup placement ids
- captured resource/town placement ids and owners
- depleted/recharged visitable sites
- spawned or removed runtime objects
- mutable road/gate/unlock state if future gameplay adds it
- fog explored tile bitset or compressed tile runs
- battle state only while battle is active

Performance acceptance for the future save migration:

- Small 36x36 generated map save should be far below the observed 6.95 MB full JSON payload. Target less than 1 MB for normal post-launch save with no debug payloads.
- Save path wall time for a normal generated Small map should target less than 50 ms on the current development machine for stringify/write equivalent work, excluding first-time package export.
- Larger maps should scale primarily with mutable deltas and fog, not full terrain/object package size.
- Package export is allowed to be more expensive than a save, but it must be explicit and profiled.

## Staged Implementation Plan

Future slices should stay small and individually validated.

### Slice 1: Package/API Skeleton

Purpose: create the GDExtension module with empty typed classes, binding smoke, and no package adoption.

Targets:

- `src/gdextension` or selected native extension folder
- build files
- `MapDocument`, `ScenarioDocument`, `MapPackageService` binding stubs
- Godot smoke that instantiates service and returns version metadata

Gates:

- native build passes
- Godot headless binding smoke passes
- no content/save behavior changes

Implementation evidence:

- 2026-05-03 owner-correction follow-up vendors `godot-cpp` as a git submodule pinned to upstream tag `10.0.0-rc1` commit `58d1de720b8ffe9f8ffcdfe3a85148582cfd2e74`, whose `gdextension/extension_api.json` targets Godot 4.6 stable for the repo's Godot 4.6.2 runtime.
- Build command: `cmake -S src/gdextension -B .artifacts/map_persistence_native_build -DCMAKE_BUILD_TYPE=Debug` then `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- The focused smoke `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . tests/map_package_api_skeleton_report.tscn` passes with `binding_kind: native_gdextension` and `native_extension_loaded: true`.
- This evidence only completes the native inert API skeleton/build/load step. It does not implement package format behavior, package adoption, save migration, content migration, RMG rewrite, renderer/fog/pathing/gameplay changes, or asset ingestion.
- 2026-05-03 Windows x86_64 follow-up makes the native CMake target platform-aware while preserving the Linux output names. Linux writes `libaurelion_map_persistence.linux.template_debug.x86_64.so` / `libaurelion_map_persistence.linux.template_release.x86_64.so`; Windows writes `aurelion_map_persistence.windows.template_debug.x86_64.dll` / `aurelion_map_persistence.windows.template_release.x86_64.dll`.
- `src/gdextension/map_persistence.gdextension` now lists Linux and Windows `editor.x86_64` entries pointing at the Debug library for editor/headless smokes, while keeping `debug.x86_64` and `release.x86_64` entries for export/template builds. Windows build commands are documented in `src/gdextension/README.md` for MSVC, MinGW, and Linux-hosted mingw-w64 cross-compilation.

### Slice 2: Legacy Scenario Converter Design Probe

Purpose: convert one legacy scenario record in memory and validate typed dimensions/placements.

Targets:

- `convert_legacy_scenario_record(...)`
- validation report for one fixture scenario
- no package files authoritative

Gates:

- `tests/validate_repo.py`
- focused scenario conversion report
- legacy export matches core fields from original record

### Slice 3: Map Package Round Trip

Purpose: write and read `.amap` for one fixture map.

Targets:

- header/chunk table
- `META`, `DICT`, `TERR`, `LAYR`, `OBJS`, `VALD`, `PROV`
- inspect command/report

Gates:

- load/save round-trip hash stable
- corruption tests for bad header and checksum mismatch
- no runtime content adoption

### Slice 4: Scenario Package Round Trip

Purpose: write and read `.ascenario` referencing an `.amap`.

Targets:

- `MREF`, `SELC`, `SLOT`, `STRT`, `OBJT`, `HOOK`, `ENMY`
- scenario-map reference validation

Gates:

- scenario package rejects wrong map hash
- legacy scenario adapter produces current launch-compatible shape

### Slice 5: Generated Payload Importer

Purpose: import existing GDScript RMG payload into typed documents.

Targets:

- `convert_generated_payload(...)`
- generated export signature preservation
- generated package debug report

Gates:

- fixed-seed Small generated payload imports
- typed package round trip preserves scenario id, dimensions, terrain signature, object writeout signature, materialized signature, and validation status

### Slice 6: Manifest And ContentService Adapter

Purpose: add package-aware manifest lookup with legacy fallback.

Targets:

- manifest schema
- `ContentService` adapter path
- package load disabled by default or fixture-only

Gates:

- authored scenarios still load
- package fixture loads through adapter
- fallback to `content/scenarios.json` works

### Slice 7: Generated Package Cache

Purpose: allow generated skirmish setup to export package refs while preserving old transient draft path.

Targets:

- generated package cache under `user://generated_maps`
- package ref in setup/session flags
- no full save migration yet

Gates:

- generated skirmish starts from package-backed adapter
- generated save/load still supports old provenance fallback
- no authored content writeback

### Slice 8: Save Reference/Delta Migration

Purpose: introduce new save version with map/scenario refs plus compact deltas.

Targets:

- `SessionDelta` shape
- old-save loader and migration report
- package ref validation before load

Gates:

- old authored save loads
- old generated save loads through provenance fallback
- new generated package-backed save stays under performance/size targets
- migration backup/rollback works

### Slice 9: Authored Scenario Migration Pilot

Purpose: migrate one authored scenario behind manifest flag and rollback.

Targets:

- one selected low-risk scenario
- package authority with JSON fallback
- conversion report and smoke

Gates:

- launch/save/resume smoke passes both package and rollback paths
- manifest flip restores legacy JSON authority

## Validation Gates

## Native RMG Parity Slice Evidence

`native-rmg-town-guard-placement-10184` extends the C++ GDExtension RMG
foundation with staged town and guard placement records. The native result now
exposes `town_generation_status`, `guard_generation_status`,
`town_guard_placement`, `town_placement`, `guard_placement`, town records,
guard records, category counts, stable signatures, and a combined primary-tile
occupancy index across existing object records, towns, and guards.

The slice remains a foundation-only parity step: generated towns and guards are
not authoritative gameplay objects, are not written back to authored content,
do not replace `RandomMapGeneratorRules.gd`, and keep `status:
partial_foundation` plus `full_generation_status: not_implemented`.

`native-rmg-validation-provenance-parity-10184` adds the native
validation/provenance foundation around the current staged C++ RMG output. The
native result now exposes `validation_status`, `validation_report`,
`provenance`, `component_summaries`, `component_signatures`,
`component_counts`, `phase_pipeline`, and `full_output_signature`.

The native validation report checks structural dimensions and tile counts,
terrain count totals, zone/player-start bounds, road start coverage and bounded
road cells, bounded river cells, object/town/guard occupancy uniqueness,
object/town/guard zone references, protected guard target references, and
no-authored-writeback policy boundaries. Provenance records preserve generator
version, normalized seed, deterministic config identity, component signatures,
validation/report signatures, and explicit false values for authored writeback,
save-schema write, runtime call-site adoption, package/session adoption, and
full-parity claim boundaries.

This remains a foundation-only parity step. Native generated output is not
authoritative gameplay content, is not written back to authored JSON or tile
streams, does not replace `RandomMapGeneratorRules.gd`, does not adopt package
or session flow, and keeps `status: partial_foundation` plus
`full_generation_status: not_implemented`.

`native-rmg-gdscript-comparison-harness-10184` adds a fixture-driven headless
comparison harness between the current GDScript runtime setup path and native
`MapPackageService.generate_random_map(config)` output. The harness builds
GDScript configs through `ScenarioSelectRules.build_random_map_player_config`
and `build_random_map_skirmish_setup`, then passes the same deterministic config
to native generation.

The comparison report is deliberately not byte-for-byte parity. It compares
structural dimensions, player counts and starts, terrain coverage/categories,
road and river counts, object/town/guard counts and categories, validation and
provenance status, and explicit known gaps. It also proves that native reports
all implemented foundation phase components and that GDScript remains the source
of truth.

The harness initially kept package/session adoption and full parity gated. After
the package/session adoption slice, its readiness section now allows only the
feature-gated package/session bridge while keeping native runtime authority and
the full parity claim false.

`native-rmg-package-session-adoption-10184` adds the controlled native output
bridge for package/session records without making native RMG authoritative. The
native `MapPackageService.convert_generated_payload(...)` path now accepts the
native RMG result after validation/provenance passes and returns typed
`MapDocument`/`ScenarioDocument` handles, generated map/scenario package records,
stable package/session refs, and a session boundary report. The GDScript shim
mirrors the shape, and `NativeRandomMapPackageSessionBridge.gd` can build a
generated-draft `SessionData` from those refs for focused smoke validation only.

The bridge is intentionally feature-gated. Package records are memory/session
records with `memory_only_no_authored_writeback`; no `.amap`/`.ascenario` files
are written by default, no authored JSON or generated draft registry writeback
occurs, and `RandomMapGeneratorRules.gd` remains the live source-of-truth
fallback. The adoption report marks package/session adoption ready for the smoke
path while keeping native runtime authority, runtime call-site adoption, save
version bump, campaign/skirmish browser adoption, and full parity claim false.
The comparison harness now verifies this adoption conversion for its native
fixtures and advances the readiness blocker to the final full-parity gate only.

`native-rmg-full-parity-gate-10184` closes the tracked native/GDScript parity
gate for the current comparison fixture scope: 36x36 `homm3_small` maps using
the compact border-gate and translated RMG profile/template configurations,
specifically compact three-player land, translated four-player islands, and
translated four-player underground land coverage.
For those supported profiles, native C++ output now reports
`status: full_parity_supported`,
`full_generation_status: implemented_for_supported_profile`,
`native_runtime_authoritative: true`, and `full_parity_claim: true` while
preserving the feature gate and leaving runtime call-site adoption false.

The parity gate checks structural equality against
`scripts/core/RandomMapGeneratorRules.gd` for dimensions/tile counts, terrain
categories/counts, road and river summary counts, object categories/counts,
towns, guards, validation/provenance, and package/session bridge readiness. It
also keeps unsupported native configurations explicit: they remain
`partial_foundation` with `full_generation_status: not_implemented` instead of
claiming broad parity. The GDScript generator remains the live generated
skirmish source of truth until a later runtime adoption slice changes call
sites. Linux and Windows native build expectations stay in sync through the
existing GDExtension manifest/helper paths; no save version bump or authored
content writeback is introduced.

Planning/doc gates for this slice:

- `python3 -m json.tool ops/progress.json`
- `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py sync-plan /root/dev/heroes-like --dry-run`
- `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py status /root/dev/heroes-like`
- `git diff --check`
- `python3 tests/validate_repo.py` if runtime/content validators are not excessive for the environment

Future implementation gates:

- native extension build
- headless Godot binding smoke
- legacy scenario conversion report
- map package round-trip report
- scenario package round-trip report
- generated payload import/round-trip report
- corruption and checksum negative tests
- old-save compatibility tests
- generated skirmish save/load replay/provenance tests
- `tests/validate_repo.py`
- `git diff --check`

Acceptance criteria for package implementation:

- Canonical hash is stable across repeated writes.
- Unknown optional chunks are skipped.
- Unknown required chunks fail.
- Corrupt chunk hash fails.
- Scenario package rejects mismatched map hash.
- Legacy adapter can produce the current scenario Dictionary shape for selected fixtures.
- Generated package import preserves existing generated identity/export/materialization signatures.

Performance acceptance criteria:

- Package load for Small map fixture is comfortably below current full JSON save path cost.
- Normal save after package adoption stores package refs and mutable deltas, not full map payloads.
- Generated Small save target: less than 1 MB and less than 50 ms save-path time for ordinary post-launch saves on the current development machine, excluding first package export.
- Package export and migration reports must include file sizes, parse/write/hash/compress timings, and validation timings.

## Explicit Boundaries

This specification does not authorize:

- runtime code implementation in this documentation slice
- save version bump
- deleting or shrinking `content/scenarios.json`
- moving production content to packages
- generated-map campaign adoption
- writing generated maps into authored content
- renderer changes
- fog-of-war changes
- pathing, occupancy, or movement semantic changes
- gameplay objective/script semantic changes
- full C++ RMG rewrite
- asset ingestion
- breaking existing saves without migration and rollback

Implementation workers must preserve these rules unless a later AcOrP-approved slice explicitly changes scope with validation gates.

## Open Decisions For Implementation Kickoff

Decisions that should be made in the first implementation slice:

- Exact GDExtension folder and build system layout.
- `Resource` versus `RefCounted` for document handles.
- Whether first package writer uses no compression or a built-in compression mode before adding zstd.
- Exact manifest filename and whether it sits beside `content/scenarios.json` or under `content/maps/`.
- Initial fixture scenario for conversion. Prefer a small authored scenario with representative towns, resource nodes, encounters, objectives, script hooks, and terrain layers.
- Whether package debug export uses canonical JSON, CBOR-like binary metadata, or both.

Decisions intentionally deferred:

- Rewriting RMG in C++.
- Making package files authoritative for production scenarios.
- Save version 10 details beyond reference/delta contract.
- Editor writeback UX and production content migration cadence.
- Pathing/renderer direct consumption of typed spatial indexes.
