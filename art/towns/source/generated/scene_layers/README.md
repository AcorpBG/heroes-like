# Approved Town scene layers

Owner approval: 2026-09-07 full-match presentation continuation. Parent/slice:
`quality-generated-full-match-20260906` /
`ux-generated-full-match-presentation-20260906`.

The production-named PNGs preserve the original generated RGBA masters.
Adjacent `.prompt.txt` files preserve the exact built-in image_gen prompts;
the tool did not expose a model/version. The reviewed studies and generation
identities remain in the concept-review packet under
`.artifacts/generated_full_match_quality_20260906/town_scene_candidates_20260907/`.
No external game art was supplied to generation. References were the original
`town_veilmourn_village.png` panorama and each existing exact building catalog
icon, with the panorama authoritative for camera, materials and lighting.

Scene owner: `content/town_building_scene_art_manifest.json` records every
source/trimmed/runtime hash, alpha crop, normalized scenic bounds, depth anchor,
runtime dimensions and prompt path. `tools/prepare_town_scene_layers.py` crops
only transparent outer pixels and downsamples with Lanczos to maximum 512px,
stripping derivative timestamps/metadata for reproducibility. No geometry,
painted replacement scenery, recoloring, traced pixels or generated placeholders
are introduced by processing. Generated alpha, including fine ropes and smoke,
is retained. Source masters and trimmed intermediates are excluded from both
platform packages; only runtime derivatives, their imports and manifest ship.

Curation against the actual Large08 starting Bellwake scene: Bell Harbor's left
gangway joins the main quay, with pilings in the central harbor. Wayfarers Hall
occupies the right middle-distance shore behind the existing foreground gate.
The initial Hall placement overlapping the gate was rejected. Full-resolution
unfiltered downsampling shimmer was also rejected; runtime derivatives use
mipmaps. Catalog/info icons and the original village panorama remain unchanged.

Applicable review rubric (1–5): game-scale readability 4, faction material and
silhouette 4, building/scene consistency 4, production feasibility 4, originality
5. These are curation judgments, not automatic quality or all-faction acceptance.
This packet has no unit-tier or animation-completion claim. The two structures
are starting buildings in Bellwake, not newly added construction options.

Rollback: revert the coherent art/manifest/renderer/hotspot change together.
No save migration or gameplay/data rollback is needed. Remaining Town buildings
and other factions require their own inspected scene-matched art; this first
packet does not accept the old catalog-icon placement of those structures.
