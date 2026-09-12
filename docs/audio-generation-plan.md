# Aurelion Reach: complete audio generation plan

Owner-requested inspection and production list, 2026-09-13. Planning slice: `planning-production-audio-generation-20260913`. **This is a documentation-only deliverable. No new game audio has been generated, installed or approved by listening. ComfyUI remains stopped.**

## The list

- [Complete generation checklist](audio-generation/generation-checklist.md): every proposed batch, priority, edited duration and deliverable count.
- [Generation queue CSV](audio-generation/generation-queue.csv): filterable briefs with target IDs, model, variations, loop requirements, current coverage and integration dependencies.
- [Current cue inventory CSV](audio-generation/current-cue-inventory.csv): every existing cue, file, exact duration, format, volume, checksum and catalog event association.
- [Content coverage CSV](audio-generation/content-coverage.csv): one disposition for every current faction, unit, spell, town, building, map object, resource site, resource, artifact, hero, biome, campaign and authored scenario. Shared mappings are proposed, not shipped bindings.
- [Catalog routing gaps](audio-generation/catalog-routing-gaps.csv): catalog names without a corresponding audio-manifest entry.
- [Audit summary](audio-generation/audit-summary.json): counts, inspected source revision and technical checks.

The queue contains **298 briefs / 758 proposed edited deliverable files** across all priorities. This is a production planning estimate, not a command to generate everything or a count of model calls. Rejected takes, source recordings and editing sessions are additional. P2 includes optional breadth that should be cut or reused when it adds little value.

## What is present now

Inspected checkout: `3d296d166e64f03fcf98f9b8d0a57c7e69ed6506`. Live source and manifests take precedence over historical reports; some old reports still describe WAV music and smaller catalogs.

| Existing category | Cue entries | Unique files | Current duration | Disposition |
| --- | ---: | ---: | --- | --- |
| UI | 6 | 6 | 60–150 ms | Replace synthetic material gestures with curated, quiet tactile sounds. |
| Adventure / town / artifact / system actions | 27 | 26 additional | 120–480 ms | Replace shared gestures; confirmation aliases the UI file. |
| Battle, including eight spell/effect sounds | 22 | 22 | 70–300 ms | Replace generic combat and seven named spell sounds plus shared ward. |
| Overworld ambience | 11 | 11 | 12 s loops | Replace terrain beds and two contextual texture layers. |
| Music | 75 | 75 | 8 s per layer | 25 compositions, each split into root / harmony / motion. |
| **Total** | **141** | **140** | | **All declared nonfinal.** |

All 140 files decode, contain finite non-silent audio, and are 44.1 kHz stereo. They occupy 10,093,588 bytes (about 9.63 MiB): 54 WAV one-shots and 86 OGG loops. There are no unreferenced audio files under `art/audio` among WAV/OGG/FLAC/MP3. `ui_confirm` and `audio_placeholder_ui_confirm` share `art/audio/runtime/ui/confirm.wav` and need one replacement, not two.

The current five generators synthesize layered waveforms from deterministic profiles. The manifests explicitly set `final_sound_design: false` or `final_composition: false`. This supports treating them as a functional baseline awaiting production curation; it is not a claim that every current sound is artistically bad. This inspection checked files and source routing, not a fresh complete-match listening session.

Current content comprises six factions, 160 units, 119 spells (97 battle, 22 field; seven schools), 32 towns, 160 buildings, 422 map objects, 377 resource sites, nine resources, 69 artifacts, 66 heroes, nine biomes, 25 campaigns and 299 scenarios. The coverage table accounts for all **1,753 records** in these domains. A catalog entry does not by itself prove that content is reachable in every game configuration.

## Generation priorities

| Priority | Meaning | Briefs | Edited files |
| --- | --- | ---: | ---: |
| **P0** | Replace every currently referenced nonfinal asset through the existing audio routes. | **90** | **140** |
| **P1** | Add material, creature, school and faction variety plus meaningful event notifications. These require runtime work. | **125** | **430** |
| **P2** | Defer location texture, extended music, site accents and optional ability/campaign identity until the core mix is approved. | **83** | **188** |

P0 is the minimum complete replacement set, with one curated take per SFX cue and one composition per music context. P1 expands variation; the game currently does not select a randomized bank of alternatives. Do not export many variants and call them integrated before that selection exists.

Recommended working order inside P0:

1. Calibrate a small listening batch: melee release, hit, ranged release, footstep, cast, Cinder Burst, UI click, guard warning, grass/water/mire beds and one Embercourt battle/adventure composition. Compare at actual gameplay volumes before mass generation.
2. Complete all 22 battle sounds, six UI files and 26 adventure/town/system files. Keep action-release and impact on separate events.
3. Complete menu, generic adventure/town/battle and victory/defeat music, then all six faction trios and generic outcome fallback.
4. Finish all terrain ambience and contextual textures. Check a full Small match with Effects alone, Music alone, both, fast mode and reduced repetitive sounds.

## Music: all 25 existing compositions

Each row below needs **one coherent composition with three synchronized stems**, not three independently generated songs. P0 preserves all 75 current cue slots.

| Composition set | Themes | Proposed edited loop per theme | Direction |
| --- | ---: | --- | --- |
| Main menu | 1 | 120–180 s | Inviting original identity, wonder and a memorable motif. |
| Generic adventure fallback | 1 | 120–180 s | Patient exploration; unobtrusive across long decision pauses. |
| Generic town fallback | 1 | 120–180 s | Warm, settled and quietly productive. |
| Generic battle fallback | 1 | 90–150 s | Clear tension and rhythmic purpose with space for SFX. |
| Generic outcome fallback | 1 | 30–60 s | Neutral aftermath when terminal status is absent or unknown. |
| Victory and defeat outcome loops | 2 | 30–60 s | Earned success / dignified loss; avoid a repeated bombastic fanfare. |
| Embercourt: adventure, town, battle | 3 | 120–180 / 120–180 / 90–150 s | River law and civic fire: warm horns, strings, field drums, small bells. |
| Mireclaw: adventure, town, battle | 3 | Same | Predatory bog clans: low drums, breathy reeds, bowed bass, uneasy rhythm. |
| Sunvault: adventure, town, battle | 3 | Same | Crystal infrastructure: glass harmonics, mallets, bright strings, precise rhythm. |
| Thornwake: adventure, town, battle | 3 | Same | Living orchards: flute, plucked wood, soft strings, seed rattles. |
| Brasshollow: adventure, town, battle | 3 | Same | Foundries and pressure: low brass, struck iron, measured mechanical pulse. |
| Veilmourn: adventure, town, battle | 3 | Same | Fog and memory: distant funeral bells, low winds, bowed strings, muted drums. |

These instrumental palettes are proposed original direction derived from `content/factions.json`, not established recordings. Do not use Heroes music, melodies or artist imitation prompts. No lyrical vocals or dialogue are needed for this soundtrack scope.

`MusicAudio._cue_id_for_context` currently chooses adventure/battle by player faction, town by the viewed town faction, and outcome by status. Menu submenus share menu music. There is no per-campaign, biome, enemy-faction, hero, map-size or RMG-seed music route. The 299 scenarios therefore reuse these contexts; they do not require 299 songs.

P1 adds six **one-shot stingers**: battle entry, battle win, battle loss, chapter transition, campaign completion and major discovery. These need a stinger lifecycle and ducking; do not place them in a permanently looping outcome slot. P2 proposes nine biome exploration variations and 25 optional campaign motif suites; their exact names appear in the checklist. Faction-theme reuse is acceptable until these prove worthwhile.

### Music production constraint

The installed Stable Audio Medium workflow produces a stereo audio result. It does **not** provide three independently controllable, aligned instrument stems. Generate and curate a coherent sketch, then arrange/edit or separate and repair it in an audio editor/DAW; verify that the three final stems share the exact tempo, key, sample count and musical loop point. Stem separation may introduce artifacts and requires listening. Alternatively, explicitly implement and validate a single-track playback contract in a later slice. Never silently put unrelated full mixes into the three current layers.

Root should carry the essential piece; harmony adds support; motion adds rhythmic activity without masking action cues. Keep a full-mix reference alongside the three delivery stems. The current 360 ms context crossfade is not bar synchronization, so inspect transitions for cut chords, phase cancellation and abrupt loudness changes.

## SFX and ambience scope

The complete named replacement checklist has every existing cue. The expansion budget is:

| P1 category | Exact bank scope | Edited files |
| --- | --- | ---: |
| Movement | Grass, dirt, stone, wood, mud, sand, snow, shallow water, underground; four steps each. | 36 |
| Weapon releases | Blade, polearm, blunt, bow, sling, bolt, chain/harpoon, thrown object, siege, arcane; four each. | 40 |
| Material impacts | Cloth/equipment, metal, wood, stone/crystal, wet hide, machine; four each. | 24 |
| Unit bodies | Humanoid, bog brute, hound, antlered beast, bear, amphibian, winged creature, insect, wyrm, living wood, machine, crystal, spectral, leviathan, ray; twelve each. | 180 |
| Magic | 56 school/gesture banks based on actual school/effect combinations; two variants each. | 112 |
| Town ambience | One continuous bed per faction, shared by its towns. | 6 |
| Resource material pickups | Gold, wood, ore and all six rare materials by their exact registry IDs; two each. | 18 |
| Notifications | New day, new week, player turn, objective update, objective completion, hero level, town threat, resource shortfall. | 8 |
| Musical stingers | Six short event accents listed above. | 6 |

Each body bank is move ×4, attack exertion ×4, hit reaction ×2, defeat/fall ×2. Body sounds complement weapon/material sounds. The unit coverage table proposes a bank per unit from its identity; equipment, species and material must be confirmed against the existing artwork before generating. Examples: a pressure cannon is not a bow just because both have `role: ranged`; a living tree must not receive human pain sounds. Default idle should usually remain silent. Spoken unit acknowledgements, narrator lines and 66 hero voice packs are not required by the inspected audio scope.

The seven magic schools are Beacon, Furnace, Root, Veil, Old Measure, Mire and Lens. Generate only their currently authored effect combinations. Separate cast, damage impact, empower, ward, haste, bind, cleanse, heal, field march/reveal and status-expiry gestures as applicable. An expiry candidate is not permission to play expiry for instantaneous spells. Preserve the seven exact named spell cues: Cinder Burst, Coal Rain, Sunlance Arc, Briar Bind, Graft Mend, Prism Bastion and Resonant Chorus. Command Ward is currently the shared `effect` resolution sound, not an eighth exclusive spell identity. School-bank additions must avoid stacking redundant sounds over the exact cues.

P0 ambience consists of grass, water, mire, dirt, rough, sand, snow, lava and underground plus pressure and day-pulse textures. The latter is currently enabled after day one; it is not a day/night system. The pressure layer must not imply a precise hidden enemy location. P2 local beds cover forest, river, windmill, sawmill, mine, forge, shrine, portal, market, harbor, ruins and camp.

P2 additionally lists 15 site-interaction families and 22 optional ability accents. Generic capture, visit, recruit, reward and status sounds remain valid reuse. The 160 buildings share construction completion rather than each needing a new sound. The 69 artifacts share claim/equip/stow unless a later signature need is established. Blockers and decorations remain silent by default; no per-object loop should turn the map into constant noise. Weather, naval boarding, unique boss music and voiced campaigns are not assumed to exist just because the fiction mentions them.

## Concrete integration gaps before generation becomes game content

1. **Four catalog IDs have no manifest mapping:** `audio_placeholder_object_ambient_soft`, `audio_placeholder_spell_school`, `audio_placeholder_spell_impact`, `audio_placeholder_ui_invalid`. They occur across five catalog event rows. Actual battle playback uses generic/exact battle cues and UI uses `ui_invalid`; object ambience has no matching `PresentationAudio` support. Reconcile ownership or aliases before treating these as four new mandatory recordings. See the exact gap table.
2. **Unit and material variety is not selected.** `BattleBoardView` routes event cues and seven explicit spell identities; there is no authored per-unit/per-weapon bank selection. Add data-driven mappings and repeat avoidance while retaining safe generic fallbacks.
3. **Field spells share one cue.** School/effect routing and exact identity review are needed for the 22 field spells and broader battle catalog. The coverage table is a planning map, not an implemented resolver.
4. **Ambience currently keys from the surface map terrain.** `AmbientAudio._overworld_context` reads `overworld.map`, hero x/y, pressure and day; it does not read the active spatial level or authored biome identity. Deep Forest shares grass; the authored Mire/Fen biome uses dirt. Verify actual terrain routing, underground level and scene transitions before declaring dedicated biome/underground ambience operational.
5. **Town and object-local ambience need lifecycle/routing.** Current ambience is an Overworld service. Town beds, proximity selection, falloff, fog ownership and bounded voice counts require implementation. Do not reveal unvisited objects or off-level activity by sound.
6. **Longer loops change a tested content contract.** The generators and `tests/validate_repo.py` currently enforce exactly 8-second music and 12-second ambient segments. Longer curated loops require a deliberate manifest, duration/lifetime and validation update. Do not run the existing deterministic generators over approved replacement assets.
7. **One-shot timing is very short.** Current battle files are 70–300 ms. Generate several seconds of clean source, then extract the required gesture with an immediate onset. Longer natural tails need playback-lifetime and animation-timing review; simply overwriting a short file with a long clip is not acceptance.
8. **Notifications/stingers need committed-event ownership.** Trigger once on a real transition, not every UI refresh; coalesce multiple rewards, honor mute/reduced repetition and avoid double-playing automatic button clicks plus completion cues.

## Delivery and acceptance

Use the already installed Small-SFX workflow for isolated effects and Medium for music/continuous ambience. Keep ComfyUI stopped until generation is explicitly started. Short effect requests should produce a clean source take long enough to edit, not a final 70 ms model output. A model's requested duration or the prompt word “seamless” does not establish an edit-ready loop.

- Retain the source WAV/FLAC at 44.1 kHz stereo and a 24-bit edited WAV master; preserve prompts, model revision/hash, workflow, seed, settings, source hash, edit notes and reviewer decision. These are production sources, not disposable probes.
- Deliver one-shot runtime files as WAV and looping music/ambience as OGG Vorbis through the existing Windows/Linux import pipeline. Preserve stable cue IDs; any changed path/metadata belongs in its manifest. Source master bit depth and engine runtime import settings are separate decisions.
- Measure decoded peaks and audition in the game. Start with headroom (the local workflow currently uses −6 dB); do not normalize every sound to maximum level. Select final bus-relative volume by function and repeated listening, preserving quiet UI and readable combat.
- Check for clipping, clicks, DC offset, leading silence, cut tails, unintended speech/music, stereo phase problems and obvious repeated AI artifacts. Mono compatibility matters for centered effects. Listen to loops over several repetitions and across runtime transitions; exact first/last sample equality alone does not prove a musical loop.
- Audition layered music stems together and separately. Confirm no timing drift, clipping or destructive cancellation. Match all stem loop boundaries at the sample and musical-phrase level.
- Verify exact trigger identity, fast/reduced-motion timing, Effects/Music/Master controls, reduced repetitive sounds, cooldowns, voice budgets, save/resume and scene exit. Keep music and ambience from leaking across screens.
- Run relevant source checks and Windows/Linux import/export/startup checks for the eventual content change, then complete a real Small match listening pass. This document does not claim those future integration checks have passed.

No game assets, audio manifests or runtime code were changed by this planning slice. The local ComfyUI validation samples remain separate experiments; they are not production game content.

## Planning validation

All 140 original audio files decoded and their SHA256 hashes remained unchanged. CSV checks passed for 141 cue rows, 298 unique generation briefs, 758 estimated deliverable files and all 1753 exact content IDs. Every coverage target, local document link and source-file reference resolves. PLAN/progress changes are confined to this documentation-only slice. No engine/runtime tests were needed for these documentation changes; future audio integration acceptance is listed above.
