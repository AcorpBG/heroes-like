# Aurelion Reach wiki

Owner-authorized documentation and web tooling slice, 2026-09-13. Status: completed.

Build a game-themed HTML, JavaScript and CSS wiki in `docs/wiki/`. The website must work locally without a package manager, external service, or game process. A generated JavaScript catalog provides authored content and asset references without browser fetch restrictions on local files.

Scope: all authored factions, heroes, units, towns, buildings, spells, artifacts, resources, resource sites, map objects, neutral dwellings, army groups, encounters, biomes, scenarios and campaigns; all artwork and audio in the repository asset library, including source material. Explain gameplay entities using authored descriptions and actual fields. Explain media by its manifest associations, presentation role, and archive status; do not invent gameplay effects for decorative files. Clearly distinguish source/archival assets from runtime presentations and authored metadata from demonstrated availability.

Provide searchable/filterable browsing, stable entry links, cross-references, responsive layouts, keyboard access, bookmarks, unit comparison, image previews and user-initiated audio playback. Large catalogs must paginate and load images lazily. The home page should lead with the game's scenery and faction identities.

Keep original assets in place; relative links resolve within the checkout or a static host serving its root. The catalog builder lives with the wiki and only writes wiki data. No game scripts, content or asset originals change. Preserve unrelated local work.

Acceptance is inspection of the wiki itself: navigation, search/filtering, representative entity detail, image/audio browsing, responsive layout, keyboard controls, and absence of browser errors. Per explicit owner instruction, do not run repository validation, game tests or game builds for this slice.

## Delivered and reviewed

The committed catalog contains 3,139 authored entries and 8,852 media files (7,059 artwork and 1,793 audio), with 5,653 source/reference/archive files clearly separated. Content includes linked gameplay stats, abilities, costs, rewards, campaign chapters, sound roles and media provenance. The site includes search, filters, pagination, bookmarks, three-unit comparison, image enlargement, native audio controls and source links.

Website-only browser review on 2026-09-13 covered desktop and 390px mobile layouts, faction and text filtering, exact-name and empty searches, pagination, unit/spell/campaign details, associated media, persisted bookmarks, comparison, image enlargement/Escape and skip-link keyboard focus. The reviewed wiki pages reported no JavaScript console warnings or errors. Temporary review bookmarks and comparison selections were cleared.

Review limitations: starting native WAV playback crashed the Codex in-app browser. The same failure occurred on an isolated HTML page containing only an audio element and no JavaScript, so playback could not be confirmed in that browser. Original audio files and the previously accepted game audio were unchanged. Direct file-URL review was blocked by the browser tool's URL policy; the site is designed for local-file use through a bundled JavaScript catalog and relative media paths. HTTP-served navigation was reviewed successfully.

No repository validators, game tests, game builds or game processes were run. The temporary preview server was stopped and the disposable 275-byte isolation page was removed. Original assets, sources, provenance and unrelated local work were retained.
