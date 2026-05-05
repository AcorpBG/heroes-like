# Native RMG HoMM3 Validation Adoption Gate Report

Date: 2026-05-05
Slice: `native-rmg-homm3-validation-adoption-gates-10184`
Phase: `phase-3-homm3-style-rmg-rework`

## Scope

This gate closes the Phase 3 native random-map generator rework against the recovered HoMM3-style RMG structure using original game content only. It is not a feature rewrite, not a broad rebalance, not a HoMM3 asset/name/text import, and not an alpha readiness claim.

The gate validates the completed Phase 3 generator slices across:

- template filtering and supported-profile detection
- runtime zone graph connectivity
- required towns, mines, resources, guards, rewards, roads, rivers, and connection payload placements
- object definition references, footprints, body/block/visit occupancy, and road conflict policy
- road/river range and connection semantics
- guard semantics, monster mask metadata, value bands, protected reward links, and special guard gates
- performance budget records for compact supported profiles and medium translated fixtures
- save/replay/package boundaries

## Gate Result

Result: pass for Phase 3 closure.

Supported compact profile output now reports `full_parity_supported` for the implemented native generator surface. Medium translated profiles remain `partial_foundation` where exact full generation is intentionally unsupported. This distinction is explicit in the validator and report output.

Package/session adoption remains `ready_feature_gated_not_authoritative`. The package bridge can materialize structurally acceptable generated map, scenario, guard, reward, visual, and session records for supported profiles, but authoritative package/session adoption remains gated.

No alpha readiness claim is made by this gate.

## Evidence

Native build:

```sh
cmake --build .artifacts/map_persistence_native_build --parallel 2
```

Primary gate report:

```sh
GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 180 tests/native_random_map_homm3_validation_adoption_gates_report.tscn
```

Observed gate summary:

- `ok=true`
- supported compact case: `status=full_parity_supported`
- medium translated case: `status=partial_foundation`
- `package_session_adoption_ready=true`
- `native_runtime_authoritative=false`
- `full_parity_claim=false`
- `adoption_status=ready_feature_gated_not_authoritative`
- `deterministic_config_identity_stable=true`
- `changed_seed_identity_changes=true`
- `full_output_signature_stable=true`

Package/session bridge report:

```sh
GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 180 tests/native_random_map_package_session_adoption_report.tscn
```

Observed result: `ok=true`, with active disk package startup proving the feature-gated bridge works while `native_runtime_authoritative=false` and `full_parity_claim=false`.

Selected Phase 3 fixture/profile/report scenes were rerun for runtime graph, zone-aware terrain, roads/rivers/connections, object placement, mines/resources, and guards/rewards/monsters.

Repository validation:

```sh
python3 -m json.tool ops/progress.json >/dev/null
python3 tests/validate_repo.py
git diff --check
```

## Adoption Boundary

The supported package/session bridge is structurally acceptable but not authoritative because runtime call sites still do not adopt the generated package/session as authoritative state, and medium translated profiles remain partial foundations. The stable replay boundary proven by this gate now includes seed/config identity and full generated-output signature stability for validated components.

The gate therefore keeps:

- `native_runtime_authoritative=false`
- `runtime_call_site_adoption=false` in the validation/adoption gate report
- `full_parity_claim=false`
- no save-version bump
- no authored content writeback
- no campaign browser authored-listing adoption
- no skirmish browser authored-listing adoption

The follow-up for authoritative use is `native-rmg-package-session-authoritative-replay-gate-10184`: adopt native generated package/session records at runtime, expand exact full-generation coverage for translated profiles, and decide whether runtime call sites can move from GDScript/source-of-truth guarded usage to native generated package/session authority.

## Phase 3 Status

The Phase 3 RMG rework can close because all child implementation slices are complete and this final gate passes with the adoption boundary explicit. The generator is validated for the implemented HoMM3-style structural surface, while unsupported exact byte/art/private-toolkit parity and authoritative runtime package/session adoption remain outside this phase.
