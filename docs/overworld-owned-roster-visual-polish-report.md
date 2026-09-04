# Overworld Owned Roster Visual Polish Report

Task: #10235
Slice: `ux-overworld-owned-roster-visual-polish-10235`

## Result

The owner-visible problem had two causes. The live Town column already filtered current `owner == "player"` placements and the hero action source already came from `player_heroes`, but the #10234 screenshot was captured from its synthetic overflow fixture after that fixture promoted three enemy towns and injected three reserve heroes. Separately, each 103x40 button rendered portrait or scenic art against a long horizontal button skin, making the images look like tiny placeholders.

The live roster now additionally intersects hero switch actions with the authoritative current `player_heroes` id set and marks every rendered hero/town card as player-owned. Towns retain the direct current-owner filter. The section is titled `Your Realm`; its headings report the visible owned counts. Existing original hero portraits and town scenic images are centered in fixed 86x66 ornamental cards using the original Overworld frame asset, with gold active/selected treatment, subdued inactive treatment, hover/focus feedback, tooltips, accessibility labels, keyboard/controller focus, scrolling, and unchanged authoritative routing.

## Ownership and visual evidence

The normal capture fixture is an untouched `ninefold-confluence` skirmish session. It contains exactly:

- player hero: `hero_mira`;
- player towns: `ninefold_embercourt_survey_camp`, `ninefold_rainwrit_bastion`;
- excluded non-player towns: the ten remaining Ninefold placements recorded in the focused JSON report.

No hero or town is injected, captured, or ownership-mutated before either normal screenshot. The separately labelled `synthetic_overflow_only_no_visual_evidence` fixture adds only explicit player-owned test records, produces no screenshots, and proves five heroes/five towns remain reachable through the bounded shared scroll.

Visually inspected evidence:

- `.artifacts/overworld_owned_roster_visual_polish_10235/owned_roster_normal_1920x1080.png`
- `.artifacts/overworld_owned_roster_visual_polish_10235/owned_roster_normal_1280x720.png`
- `.artifacts/overworld_owned_roster_visual_polish_10235/report.json`

Both captures keep the map dominant, the minimap and footer bounded, the owned counts readable, and the card controls free of overlap. The smaller layout intentionally scrolls the second town card rather than expanding the rail over the map or lower command controls.

## Validation

- `python3 tests/overworld_town_vision_command_roster_report.py`: pass; radius 5, one authoritative player hero, two authoritative player towns, ten non-player towns excluded, two untouched captures, and separated five-by-five overflow proof.
- `python3 tests/overworld_map_first_command_rail_report.py`: pass; two responsive rows/captures and session-exact layout evidence.
- `python3 tests/validate_repo.py`: pass.
- `git diff --check`: pass.
- `python3 tests/packaging_linux_export_smoke.py`: pass; boot succeeds, no fatal export/runtime matches, PCK 248218364 bytes.
- `python3 tests/packaging_windows_export_smoke.py`: export, PE/DLL/content checks, size ceiling, and baseline Godot/native-DLL/Boot/Main Menu markers pass with no fatal runtime match; the established verbose Wine wrapper retains its process handle and times out before starting the generated subflow.
- Direct execution of that same packaged Windows build with a fresh Wine prefix: pass in 15210 ms through `generated_map_setup`, `generated_overworld_entered`, and `generated_player_town_entered`, with no errors. Evidence: `.artifacts/packaging_windows_manual_owned_roster_10235/live_validation_report.json`.

Linux and Windows PCKs both measure 248218364 bytes, leaving 1781636 bytes below the unchanged 250000000-byte ceiling. No ownership/capture rule, fog rule, RMG output, content record, movement/pathing behavior, save schema, or package limit changed.
