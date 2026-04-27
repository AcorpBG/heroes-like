# Overworld Object Content Batch 002 Report

Task: #10184  
Slice: `overworld-object-content-batch-002-mines-resource-fronts-10184`  
Status: implemented content batch, pending final validation at time of writing

## Scope

Batch 002 adds or normalizes 28 mine, resource-front, and support-producer object definitions:

- 12 common live-resource mine/front records covering `gold`, `wood`, and `ore`.
- 9 staged rare-resource front records covering `aetherglass`, `embergrain`, `peatwax`, `verdant_grafts`, `brass_scrip`, and `memory_salt`.
- 6 permanent support producer records: Wind Press, Saw Chain, Tide Kiln, Orchard Levy Post, Smelter Annex, and Charter Countinghouse.
- 1 additional normalized resource object, Market Caravanserai, with explicit footprint/body/approach metadata.

Map object count after the batch: 281.

## Authoring Contracts

Every Batch 002 object links to a resource-site record and authors:

- visual `footprint` with `anchor` and `tier`;
- explicit blocking `body_tiles`;
- explicit `approach.visit_offsets`;
- `passability_class: blocking_visitable`;
- interaction cadence metadata;
- editor placement and AI hint metadata.

Footprint coverage includes `2x1`, `2x2`, `2x3`, `3x2`, and `3x3`, with all nine authored biomes represented.

## Rare-Resource Boundary

Rare-resource fronts use `staged_resource_front` object metadata and `staged_resource_outputs` site metadata only. They do not add rare ids to live `rewards`, `claim_rewards`, `control_income`, `service_cost`, response costs, market rules, save payloads, or scenario grants.

The live common-resource boundary remains `gold`, `wood`, and `ore`; `wood` remains canonical.

## Validation Coverage

`tests/validate_repo.py` now reports Batch 002 in the overworld object report and staged rare-resource fronts in the economy resource report. The Batch 002 checks cover object count, role counts, linked sites, live common resources, staged rare-resource ids, shape contracts, footprint variety, biome spread, and rare-resource report-only safety.
