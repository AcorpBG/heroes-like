# The Aurelion Codex

Open **index.html** in a browser from this checkout. The site uses only HTML,
CSS and JavaScript and works without a package manager, a game process or an
internet connection. JavaScript must be enabled. Bookmarks use browser storage;
audio plays only on request.

Keep the wiki at `docs/wiki/`: artwork and audio link to `../../art/`, and
authored references link to `../../content/`. Original media is not duplicated.
For HTTP hosting, serve the repository root and open `/docs/wiki/`. Uploading
only this directory will omit the original media; a static deployment must also
include the referenced `art/`, `content/`, `scenes/` and `scripts/` paths.

To refresh the catalog after content changes, run:

```text
python docs/wiki/build_catalog.py
```

Python 3.10+ is sufficient; no dependencies are needed. This documentation build
reads authored content, media manifests and literal scene references. It writes
only `docs/wiki/catalog.js` and does not launch Godot or run any game/repository
tests. The committed catalog means readers do not need Python.

The compendium covers factions, heroes, units, towns, buildings, spells,
artifacts and sets, resources, sites, map objects, neutral dwellings, armies,
encounters, biomes, terrain, campaigns, scenarios, sound cues and visual effects.
The asset library includes every image/audio file under `art/` and the game
icon, including source and archive material. Import sidecars, cache files and
provenance JSON are supporting records, not extra creative assets; original
references are linked where available.

Gameplay explanations use authored public descriptions and values. Media
associations come from manifests and literal references; absence of such a
reference is not proof a dynamically selected file is unused. Source/reference
material is labelled. Base stats are not final battle forecasts. Availability
depends on the scenario and applicable runtime rules.

Keyboard: `/` for search, Tab for navigation, Enter to submit, Escape to close
the artwork viewer. Hash links support browser history, bookmarks and direct
entry URLs. Unit comparison accepts up to three troops.

All wiki files are excluded from Godot imports by `.gdignore`; `docs/` is already
excluded by the game's export presets. No game files need to change.
