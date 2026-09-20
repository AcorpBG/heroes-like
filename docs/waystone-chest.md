# Waystone treasure chest

The stable `site_waystone_cache` / `object_waystone_cache` identities now represent
an oak-and-iron chest containing coins and scrolls. Visiting offers exactly one
reward: **2,000 gold** or **1,000 experience for the visiting hero**. These explicit
choice amounts are fixed across difficulties, matching the buttons. The AI takes
the default 2,000-gold content reward when it collects the chest.

Opening or dismissing the dialog grants nothing and leaves the chest available.
Selection rechecks the visiting hero, location, guard and collection state before
using the normal pickup transaction. The chest then disappears, records its choice,
and cannot be claimed again, including after saving and loading. Experience uses
the existing hero progression and specialization flow.

Existing uncollected authored/native-map/save placements use the new content and
art through the same IDs. Collected chests stay collected. Map regeneration is not
required; loaded games need a restart to reload changed content and textures.
Native generation, footprints, collision masks and placements remain authoritative.

`tools/pack_waystone_chest.py` packs the original transparent generated source and
registers measured coin/scroll regions. The cached map shader animates traveling
gold reflections, three coin glints and warm parchment light. The lid/body and
alpha remain stationary. Existing scenery order, fog clipping and reduced motion
apply; the animation does not change game state or rebuild the map each frame.

Validation owner: `tests/waystone_chest_regression.py`, a bounded Python-owned
runtime/GPU check. No full repository test suite is required for this slice.
