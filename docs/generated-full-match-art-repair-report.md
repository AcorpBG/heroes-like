# Approved full-match art repairs

Parent: `quality-generated-full-match-20260906`; selected child:
`ux-generated-full-match-presentation-20260906`. Status: in progress.

## Approval and boundaries

On 2026-09-07 the owner approved resuming with scene-matched per-faction Town
building layers and Overworld cutout repairs. Requirements:
`docs/generated-full-match-quality-requirements.md` (approved-art continuation)
and `docs/town-integrated-building-progression-requirements.md` (visual/interaction
invariants). Original game assets only; no rules, masks, placement, save schema,
native generation or unrelated cleanup changes. Runtime exports stay below
250000000 bytes on both platforms. Reverting the coherent art/code commit restores
prior rendering without save migration.

## First production briefs

- Wreck Quay: exact `object_wreck_quay` -> `mapobj_wreck_quay` mapping in
  `art/overworld/map_object_sprites.json` and `art/overworld/manifest.json`.
  The standalone runtime PNG contains a white/magenta sheet frame and edge matte.
  Repair transparency while preserving painted salvage-quay identity and framing.
  Keep original source master; record edited master, trimmed/runtime derivatives,
  exact prompt, processing and hashes before adoption. No sampler workaround.
- Bellwake: `faction_veilmourn` Bell Harbor and Wayfarers Hall currently use
  square isometric catalog icons against a low-angle moonlit harbor. Generate
  dedicated scene layers with matching camera/materials/illumination and grounded
  plots. Keep catalog/info icons separate and exact built-id/upgrade authority.
  First two structures are a bounded checkpoint, not all-faction completion.

Art direction sources: `docs/worldbuilding-foundation.md` World Premise, Tone,
and Veil Coast; `docs/factions-content-bible.md` Veilmourn Home Region and Town
Feel, Visual Language, Object Hooks and Town Building Identity. Preserve black
lacquered timber, tarnished metal, salt stone, rope, bell/mast silhouettes and
small amber lamps. No pirate/undead stereotypes or copied game imagery.

## Validated Wreck Quay checkpoint

The corrected runtime remains the same manifest-backed asset at (39,30,level 0)
in the actual Medium11 Day43 native-map save. Placement
`native_h3maped_93c0f05a_object_0961` retains source `object_wreck_quay`, adopted
as resource site `site_wreck_quay` with a native two-way-portal record and its
one-cell native block mask. The renderer resolves the exact object sprite through
that adopted identity, not a generic resource-site icon. Its 3x2 **visual**
footprint is separate from the native pathing mask. Both, its interaction and
all saved state remain unchanged. This is an art-processing
correction, not native generation or placement work.

The built-in imagegen workflow was attempted first: candidate one retained
colored edge contamination; candidates two and three baked a checkerboard into
RGB output. All were visually inspected and rejected, never imported. Exact
prompts and rejection records are retained beside the processing manifest.
The accepted production repair instead uses the approved original-raster
processing scope: preserve the exact 512x512 source canvas; remove 1238 known
sheet-divider pixels outside the complete painted structure; analytically
unmatte the magenta contamination and recover partial alpha. No replacement
shapes or new building pixels were drawn. More than 40000 uncontaminated painted
pixels remain byte-identical. Original input and original generated atlas are
retained; runtime/trimmed outputs are byte-identical, SHA256
`30683c62a83d442fcdf999f39a6d49a3b7d97221e3131e8779bc99e1b8b7c377`.

`tests/overworld_wreck_quay_repair_regression.py` fails on the original live
renderer texture with 1238 divider pixels and 6122 contaminated pixels, without
runtime errors. After processing **and a fresh editor import**, the same test
passes 11 checks at each of 1280x720 and 1920x1080: zero divider/magenta pixels,
47995 painted pixels, exact asset resolution, no procedural fallback, unchanged
complete session and input save. All three before/after gameplay screenshots
were inspected. An intermediate post-edit run still loaded the old imported
texture and failed correctly; that attempt is excluded from acceptance.

The final extended runs (`wreck_quay_final_720` / `wreck_quay_final_1080`) add
three explicit native-placement/resource-site/transit and visual-footprint checks:
14 checks pass per resolution. The native one-cell mask must not be confused with
the 3x2 art footprint. The final repository log is `wreck_quay_final_repo.log`.

Five Python tests cover failing-before defects, deterministic/idempotent repair,
format rejection, exact preserved pixels and manifest/hash/identity provenance.
Repository validation now also fails specifically if the Wreck Quay border,
matte, approved runtime hash or processing-manifest ownership regresses.

Evidence under `.artifacts/generated_full_match_quality_20260906/`:
`wreck_quay_before/report.json`, `wreck_quay_imported_720/report.json`,
`wreck_quay_imported_1080/report.json`, corresponding `wreck_quay_gameplay.png`
captures, `wreck_quay_import.log` and `wreck_quay_repo.log`.

Both original distinct-map-object and decorative-sprite reports pass, alongside
existing movement ownership, full-route and permanent-fog regressions. Fresh
Linux and Windows package/export/startup/generated-map-to-Town checks pass via
the established RAM-backed packaging wrapper; reports are `wreck_quay_linux_release`
and `wreck_quay_windows_release`, both with 248468784-byte PCKs (1531216 bytes
below the limit). Windows execution is Wine, not physical Windows certification.
Source masters are excluded from both packages. This checkpoint
does not certify other sprites' edge quality or complete Town integration.

Reproduction commands:

```sh
python3 -B tools/repair_wreck_quay_cutout.py --check art/overworld/source/generated/full_match_art_repairs/mapobj_wreck_quay_before.png # expected failure
python3 -B tools/repair_wreck_quay_cutout.py --write
godot4 --headless --editor --path . --quit
python3 -B -m unittest discover -s tests -p test_wreck_quay_cutout.py
python3 -B tests/overworld_wreck_quay_repair_regression.py --label <fresh> --save <Medium11-slot2.json> --resolution 1280x720
python3 -B tests/overworld_wreck_quay_repair_regression.py --label <fresh> --save <Medium11-slot2.json> --resolution 1920x1080
python3 -B tests/validate_repo.py
git diff --check
```

## Remaining Town integration and broader sprite work

Bell Harbor and faction-specific Wayfarers Hall scene-layer candidates have been
generated with the built-in tool and inspected in isolation. They match the
moon's cooler timber/metal palette more closely than the existing catalog icons,
but remain unaccepted pending in-scene ground/depth/hotspot and transparency
checks. Candidate rasters, exact prompts and review are retained under
`.artifacts/generated_full_match_quality_20260906/town_scene_candidates_20260907/`.
They are not registered as runtime assets. All-faction, per-building
integration and other reproduced prop-edge defects remain part of the full goal.

## Remaining acceptance

Failing-before edge/identity coverage and actual rendered before/after cases;
visually inspected 1280x720 and 1920x1080 gameplay; unchanged complete state/save,
footprint and interactions; existing sprite, fog, movement, Town construction,
information/hotspot/input checks; repository/diff checks; Linux/Windows exports,
startup and generated-map/Town entry. The Wreck Quay evidence above is bounded
to that exact asset, not acceptance of the remaining Town/Overworld art scope.
