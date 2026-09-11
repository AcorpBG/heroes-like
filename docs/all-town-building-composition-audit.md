# All-town building composition inspection

Owner-directed Phase 6 audit `audit-all-town-building-composition-20260911`, completed inspection, 2026-09-11. **Further composition fixes are needed in every faction; none were implemented in this audit.**

This is an inspection, not authorization to regenerate art or change layouts/gameplay. Validation is exhaustive capture/identity accounting plus visual inspection; existing shipping packages are unchanged and no new platform export is necessary for a read-only audit. Temporary capture tooling belongs under the task artifact directory and must leave runtime content and saves unchanged. Preserve final evidence, caches and pre-existing unrelated files during cleanup.

## Coverage and evidence

Evidence root: `.artifacts/all_town_composition_20260911/`. Current runtime baseline: `60957259` (including the five Embercourt placement repairs).

- All **32 authored towns**: starting and developed composition captured and visually inspected at 1280x720 (64 views).
- All **173 exact faction/building raster layers**, plus six embedded faction Town Halls: 179 individual views, including base/upgrade variants that disappear in developed scenes. Cropped captures include 100 pixels of surrounding scenery; 32 labeled faction contact sheets were visually inspected, plus 12 starting/developed town sheets.
- Six representative faction towns additionally captured at 2048x1079; all six developed views visually inspected at full resolution. Wide report `towns:32` denotes catalog size, not wide coverage: its rows contain six towns/12 captures. Small report contains all 32 towns/243 captures.
- `small/report.json`: 518 capture/identity/session-integrity checks pass; `wide/report.json`: 30 pass. **These prove capture completeness and unchanged session state, not acceptable art.**
- `occlusion-candidates.json`: painted-alpha coverage under later-drawn layers in each town's actual developed catalog, using manifest depth ordering. Percentages below are source-space mask estimates, exclude UI/background overlap and are not an automatic defect threshold. Images were inspected separately.
- `capture.py`, `sheets.py`, `occlusion.py` retained with the evidence for reproduction. Contact sheets arrange renderer screenshots; they do not alter game assets.

`TownStageView._resolve_scenic_backdrop` deliberately uses the faction's village panorama first. Thus 32 town identities currently share **six scenic bases**, with different catalogs. `_town_building_scene_entries` resolves exact art-manifest rectangles/anchors and plot upgrade visibility; `_project_normalized_source_rect` projects them through the common cover crop. The problems below are inappropriate authored placement/depth/composition and fixed UI overlap, not missing textures. Manifest prose claiming a terrace or shore connection does not establish that the painted background actually provides one there.

Fixtures expose starting inventories, all individually reachable catalog layers and fully populated catalogs, not every possible intermediate combination or a paid-build campaign playthrough. Individual layers deliberately omit prerequisites to reveal their background contact; crowded-scene findings also use developed compositions with all prerequisites present. The strongest occlusion pairs are separate live plots, not upgrades incorrectly shown together. Linux software-rendered inspection only; no new Windows/GPU certification, save-load playthrough or repository-wide runtime regression is claimed for this report-only task.

## Findings requiring correction

Each individual image is `small/<faction_id>--<building_id>.png`; each whole-town image is `small/<town_id>--developed.png`, or `wide/` for the six representative towns. These names and the complete visible inventories are recorded in `small/report.json`.

### Embercourt — more rear-bank and foreground issues remain

- `building_lantern_archive`, `building_starseer_annex`, `building_embercourt_granary_lock_exchange`, `building_embercourt_beaconline_charter_house`: foundations sit over the painted upstream river rather than the claimed left-bank terrace. Individual views expose the unsupported water contact; developed granary roofs conceal it rather than creating ground. See Embercourt sheets 01, 02 and 04, and Cinderlock developed.
- `building_embercourt_rainwrit_stormseal_treasury` and `building_embercourt_amberweir_counterweight_foundry`: lower frontage is covered by bottom navigation at 1280x720. `building_embercourt_lockhouse_tally` also has a cramped footer contact. Sheet 04/05 and Rainwrit/Amberweir developed.
- Further cluster-review candidates: `building_charter_bastion` loses about 49% of painted area in Highwater, and `building_embercourt_relief_quay` about 53% in Rainwrit. Some foreground overlap is legitimate; review shoreline connections and distinct entrances rather than simply enforcing non-overlapping rectangles.
- The previously corrected Bowyer/Beacon, Court, Store and Depot placements remain clear of the civic hall and upstream channel in the inspected views. That narrow fix did **not** establish acceptance for all Embercourt buildings.

### Mireclaw — unsupported rear buildings and small-screen obstruction

- `building_mireclaw_hollowreed_moonwax_ossuary` and `building_mireclaw_moonbite_votive_drum_court`: appear suspended against distant trees/reeds, with insufficient visible shoreline/platform support. Sheet 04/05 and Hollowreed/Moonbite developed confirm the mismatch with their manifest's claimed rear shoreline.
- `building_slingers_post` / `building_rot_warren`: the right side of the building/range sits under the small-screen command/icon cluster. Sheet 01; considerably clearer in the wide view.
- `building_gorefen_ring` and `building_mireclaw_antler_pit`: lower foreground/frontage collides with the footer or viewport crop. Individual sheets 01/03 and Duskfen developed. Other low-foreground rings/halls merit the same responsive-layout review.
- Most docks, pens and swamp houses have intentional piles in water. Do not treat water beneath Mireclaw stilts as a defect by itself, or remove them to pass a land-overlap check.

### Sunvault — buildings stacked into existing roofs and heavy crowding

- `building_prism_range` / `building_lens_gallery`: their platform/front steps lie over an existing blue-domed pavilion in the village painting. This reads as a building placed on another roof, not an integrated addition. Sheet 01, and Halo Spire/Dawnmirror starting views.
- `building_sunvault_zenith_observatory`: about **81%** hidden in Prismhearth's developed scene, primarily by `building_duel_circle` (69% alone) and `building_resonant_exchange`. The telescope survives as a fragment of a crowded cluster, not a distinct building. Wide Prismhearth.
- `building_sunvault_lens_gallery`: about **70%** hidden, mainly by `building_sunvault_harmonic_cloister`. `building_wayfarers_hall` also loses about 58% in the lower-right cluster. Wide Prismhearth shows interleaved roofs/entrances requiring a coordinated composition pass.
- `building_sunvault_zenith_relay_hall`: right facade/roof obscured by the command icon row at 1280x720 (sheet 04; Dawnmirror developed).
- Review `building_sunvault_splitprism_parallax_duel_hall` separately: it straddles painted canal/bridge geometry and needs a deliberate bridge foundation/connection, not a generic clear-land rule.

### Thornwake — overlapping painted village structures

- `building_thornwake_sporeglass_hothouse`, `building_thornwake_worldroot_gate`, `building_thornwake_verdant_concord_seat`: foundations/open arch overlap the existing left glass-nursery dome. The contact reads as piled-on buildings, particularly in isolated views and the developed left cluster. Sheets 02–04, wide Graftroot.
- `building_thornwake_loam_ledger`: sits over the roof of the existing far-right village dwelling; the manifest's "above" placement is not a convincing terrain connection. Sheet 00.
- `building_thornwake_root_cairn_watch`: about **69%** hidden by Verdant Concord Seat in the developed view. `building_wayfarers_hall`, Pollen Litany and Graftworks also crowd the right cluster; retain distinct doors and silhouettes when revising these sites.
- `building_thornwake_spore_oath_chantry`: right side covered by the command/icon cluster at 1280x720; visible at wide resolution. Sheet 01.
- Foreground tree limbs legitimately obscure some ground. Do not flatten all depth, remove the nursery painting or mistake a properly trunk-mounted watch for a floating ground building.

### Brasshollow — severe mutual occlusion, ledge contact and UI

- `building_brasshollow_foreman_clausehouse`: about **85%** hidden in Orevein developed, mainly by `building_brasshollow_boiler_cathedral` (84% alone).
- `building_brasshollow_caliper_sanctum`: about **71%** hidden by the Heatwright/Foreman/Boiler cluster. Boiler Cathedral itself loses about **62%** behind lower buildings. Wide Orevein demonstrates a pile of intersecting buildings rather than readable separate lots.
- `building_brasshollow_redline_charter_bay`: most of the building is behind command controls at 1280x720; a particularly clear UI-placement failure (sheet 03). `building_wayfarers_hall` also loses roof area to the icons (sheet 00).
- `building_brasshollow_rail_tax_office` and `building_brasshollow_whitegauge_datum_railhouse`: insufficient support where the facade/platform projects into a painted chasm or vertical rock face. Sheets 02/04. Ledge-support review also needed for `building_brasshollow_blackbell_grand_assay_bell` and `building_brasshollow_whitegauge_breach_pressure_foundry`; do not infer a walkable terrace solely from the manifest text.

### Veilmourn — suspended joins and buildings lost in the harbor cluster

- `building_veilmourn_drowned_map_room`: appears suspended between the original foreground warehouse and main bell tower; its foundation/shore connection is unconvincing in both the individual and developed view. Sheet 02 and wide Bellwake.
- `building_veilmourn_bell_chain_watch`: about **70%** hidden in developed Bellwake, mainly behind `building_market_square`; the surviving bell/tower fragment is not a clearly separate building.
- Further developed-cluster candidates: Market Square loses about 60% in Dreamwake, Mourner Pilot Guild about 51% in Bellwake, and Wakeglass Chart House about 51% in Gloamwake. Review their individual identity and entrances, not just texture loading.
- `building_veilmourn_memory_rite_court`, `building_veilmourn_leviathan_sounding`, `building_veilmourn_wakeglass_chart_house`: review the apparent pile-end/water contact and shore connections. Water placement is intentional, so these are grounding-review candidates, **not** a finding that the structures should move onto dry land. Likewise keep valid harbor docks, buoys and drydock infrastructure.

## Recommended correction scope

Treat this as a coordinated six-faction composition pass: reserve main-building/doorway and UI clear zones; map real ground, bank, cliff and dock surfaces; then place buildings in coherent districts with separate readable entrances and controlled depth. Keep base/upgrade variants on compatible sites. Check both isolated/minimal-prerequisite and coexisting developed states at small and wide sizes. If the original base painting already occupies the needed site, a scene-matched art edit may be needed; repositioning every layer blindly cannot solve that.

This report does not claim that every visual concern can be corrected with coordinates, that all possible build orders have been tested, or that any of the newly found defects are fixed. Original rasters, content, gameplay and shipping packages remain untouched.

Final integrity check: all 173 manifest-backed layers and six embedded halls accounted for, all 32 town IDs represented, and all 255 capture files present; `git diff --exit-code -- content scenes scripts art` and `git diff --check` pass. No exports or disposable Wine profiles were created. Capture runner automatically removed its temporary Godot probes and user profiles. Cleanup inspection found no further safely disposable files: the approximately 242 MB retained are the report's screenshots/contact sheets and reproducible capture evidence, not redundant export packages. Caches and the four pre-existing unrelated untracked paths remain untouched. This audit does not require another full repository/export run because production files are unchanged.
