# Illustrated hero-support and transit reference

Open `hero-support-transit.html` in a browser. It is a self-contained offline page:
all 97 structure thumbnails, the comparison data, filters and detail views are embedded.

The two views compare 69 original HoMM3 object types with our generated-map adapter,
and list each general structure individually. Direct mappings, shared pools, generic
fallbacks, native connections and content with no generated mapping are distinguished.
Archived campaign/scenario sites, mines, dwellings, treasure and creature banks are
outside this reference.

Rebuild from the repository root with Python 3 and Pillow installed:

```powershell
python tools/build_hero_support_transit_reference.py
```

`hero-support-transit-h3.json` contains the curated original-game descriptions and
pinned references. The builder reads the current C++ mapping tables, eligibility,
content definitions and art manifests. Native visit/support explanations are inspected
summaries in the builder; review them when those rules change. Source revision and input
hashes are embedded in the page data. The original 1999 manual and VCMI compatibility
implementation are references for gameplay effects, not recovered H3MapEd source or
proof of generator parity. This reference changes no game rules or assets.
