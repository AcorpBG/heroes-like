# Archived authored scenarios and campaigns

Owner decision, 2026-10-08: the authored scenarios and campaigns are archived. They had been obsolete since 2026-10-05 (`docs/authored-scenarios-obsolete.md`) and will be redone completely; this folder keeps them out of the game until then.

## What is here

- `scenarios.json`: the 299 authored scenarios with their embedded maps. `domain_status` is `archived_authored_scenarios_2026_10_08` and the player-facing count is 0.
- `campaigns.json`: the 25 campaigns that chained them. `domain_status` is `archived_authored_campaigns_2026_10_08`.
- `terrain_layers.json`: terrain layers of the two hand-painted maps (`river-pass`, `ninefold-confluence`).
- `tools/`: the 20 `author_*.py` scripts that wrote them. Do not run them.

## How the game treats it

- Nothing here is offered for play: the Skirmish list has no authored fronts, building a skirmish setup refuses them, and the main menu shows Campaign as "Coming soon".
- `ContentService` still reads these files from here (`AUTHORED_ARCHIVE_DIR`), so a scenario loads by id. Tests use them as hidden setups (`ScenarioFactory.create_session("river-pass")`), and an old save from an authored scenario still loads.
- Shipped builds may leave this folder out; the catalogs then read as empty. The folder has a `.gdignore`, so the editor does not import it.

## Rules

- Do not add, fix, retune or re-validate this content, and do not run the tools. New work that needs a map uses a generated map.
- `tests/validate_repo.py` still checks that the archived rosters are intact (tests rely on them) and that none of it is player-facing.

## Restoring

To bring the content back for its rework: move the three JSON files back to `content/`, point `ContentService` at them, set `domain_status` to `""` and restore the player-facing counts. The rework will more likely replace them.
