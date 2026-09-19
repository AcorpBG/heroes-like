# Unified common mines

Owner direction: 2026-09-19. Implementation is in progress; final artwork requires owner selection from the proposals.

Delivered in the proposal stage: all 12 common-site definitions now use the requested production in both `control_income` and `resource_outputs`. Focused content comparison confirms that ownership, cadence, capture rewards, rare sites and supporting producers are unchanged. Three original proposal sheets and their full generation prompts are retained in `art/overworld/source/generated/mines/unified_proposals_20260919/`. Final single-art routing, six-tile footprints and animation clips remain pending selection; no runtime art or collision change is claimed.

| Resource | Daily production while controlled | Final visual identity |
| --- | ---: | --- |
| Wood | 2 | One sawmill asset |
| Ore | 2 | One ore mine asset |
| Gold | 1,000 | One gold mine asset |

All three final mines occupy a three-column, two-row ground footprint. The south-facing entrance must stay readable and reachable. Final footprint integration must cover both authored maps and generated runtime footprints; changing only `content/map_objects.json` would not satisfy this requirement because generated footprints override authored rendering profiles.

Use original hand-painted oblique overworld art with neutral timber, stone and metal, a small irregular contact edge and transparent surroundings. Avoid grass mats, snow, sand plates, swamp reeds, required rivers and terrain-colored rock masses. Mines should remain readable on every ground material.

Animation must show working machinery with stationary buildings and foundations: visible saw/crank motion for wood, a short cart or hoist cycle for ore, and a winch/bucket or lift cycle for gold. Use seamless authored frames, independent presentation timing and a static reduced-motion pose. Subtle lantern or dust accents may complement the machinery.

Prepare three coherent proposal sets: A timber workyards, B masonry works, C excavated mine fronts. The owner may mix choices by resource. Proposal paintings are selection material, not shipped sprites or finished animation clips.

Retain existing site IDs so maps and saves do not lose references. At final integration, resolve all common-site variants to the selected resource artwork. Keep supporting producers and rare-resource production separate. In generated maps, `_live_rare_site_id_for_h3m_mine` translates four historical common object IDs into rare sites; those objects must retain their live rare resource identities.

Native generator phase behavior and recovered source masks are not changed by the proposal stage. Final six-tile occupancy needs an explicit game-level placement/adoption implementation and focused approach/pathing checks, rather than claiming that enlarged artwork changes collision.
