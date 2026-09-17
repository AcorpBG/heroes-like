# Shared Spellbook and Automatic Town Learning

Owner-directed Phase 6 slice: `ui-shared-spellbook-and-town-learning-20260917`.
Strategy: `project.md`; execution: `PLAN.md`.

## Requirements

- Town, Battle and Hero screens expose a coherent shared spellbook, with original
  manifest-backed spell/school icons, names, actual effect descriptions on hover
  and keyboard focus, mana costs and clear unavailable/known states.
- Combine context filters (All / Battle / Overworld) with role filters (All /
  Damage / Buff / Debuff). Multi-role spells match each authored relevant role;
  utility/recovery/control spells remain reachable through All.
- Battle selection uses the existing target-preview/confirmation path. Browsing,
  filtering and hover must not cast spells or mutate gameplay. Other-context,
  insufficient-mana and wrong-turn spells remain inspectable without bypasses.
- Town visits teach every unknown spell currently offered by the town's built
  archive tier and school access. The existing rules have no hero-tier/mastery
  prerequisite and learning is free: do not invent one or spend mana/resources.
  Learning must be idempotent, local to the eligible visiting hero, preserve
  roster mirrors and save schema, and never teach an absent hero from remote
  town management. New archive tiers while a hero is present use the same rule.
- Reuse current original icon assets and bounded contextual-help conventions.
  Keep scenic surfaces clear when the book is closed; responsive scrolling,
  keyboard/controller focus, Escape/back and focus restoration must work.

## Scope and verification

Targets: shared spellbook UI/read model, `TownShell`, `BattleShell`, `HeroSheet`,
and the authoritative spell-learning/town-arrival boundaries in the core rules.
No new spell catalog, school mastery, balance, AI scoring, native RMG, art
generation, save-schema migration or unrelated UI overhaul.

Add a Python-owned runtime regression for all three entry points, icons/names,
combined filters, hover/focus inspection and selection/cancel behavior, town
arrival/revisit/building unlock, absent/uncontrolled/wrong-level heroes,
multiple hero identity isolation and save/load. Inspect 1280x720 and 1920x1080
captures. Run relevant current spell/hero/town/battle tests,
`python3 -B tests/validate_repo.py`, `git diff --check`, official Linux/Windows
exports and focused isolated package gameplay. Report package sizes/parity.
Remove task-created disposable captures/logs/packages after recording results;
preserve original art/provenance, caches, saves, RMG recovery and unrelated files.

## Implementation

`scenes/shared/SpellbookView.gd` is the shared, read-only catalogue. It resolves
art through `SpellRules.spell_icon_path`, describes actual rule effects and
matches authored `role_categories` (including multi-role spells). Town's Spells
icon opens it inside the existing archive overlay; HeroSheet adds a Spellbook
tab. Battle's compact Spellbook button replaces the unbounded individual-spell
footer. Prepare revalidates legal targets and calls `_on_spell_action_pressed`;
target selection and Confirm order remain authoritative. The battle book uses
the battle's actual commander, not an unrelated remotely selected hero.

`TownRules.teach_visiting_heroes` shares existing archive-tier/school eligibility
and `SpellRules.learn_spell`. The existing town entrance/level predicate selects
owned stationed heroes; active and roster copies stay synchronized. Explicit
arrival paths, ownership capture, archive construction, local hero hire/switch
and town-screen entry invoke it. Read-only catalogue queries do not teach.
Manual study also rejects absent heroes. No spell effects, RNG, resources,
mana costs, art, native generation or save-version-9 schema changed.

## Verification results (2026-09-17)

- Source rendered 1280x720: **4,633 checks pass**, covering all 119 spell icons,
  combined filters, actual hover card, keyboard/controller navigation, all
  three entry points and town learning boundaries across authored towns.
- Isolated Linux release, rendered 1920x1080: **4,629 checks pass**. This run
  preceded the four additional source hover/focus/capture assertions. All
  Town/Hero/Battle captures at both sizes were visually inspected: fixed
  controls stay in bounds, cards scroll and descriptions remain readable.
- Isolated Windows release under headless Wine: **4,627 checks pass**, including
  the final focus assertion; rendering-only checks are explicitly skipped.
  Both package probes verify compiled shared-view, scene and core-rule owners.
- Existing hero sheet: **528 checks pass**; existing targeting/commit regression:
  **95 checks pass**. Spell schema, battle behavior, resistance/countercontrol,
  artifact/economy and field-rendezvous sharing reports pass. Town layout report
  passes five dialog routes at both resolutions and all 18 faction/build-state
  main-building hotspot cases.
- Official Linux and Windows export/startup smokes pass, including Windows
  generated-map gameplay. PCKs are **646,646,424 bytes each**, **8,863 entries**;
  payloads are byte-identical except platform-specific `project.binary`.
- Final repository validation: **VALIDATION PASSED, exit 0**. The first full run
  identified two obsolete source-shape assertions (old footer spell buttons
  and confirmation-dialog owner count); their replacements validate the new
  book launcher, selected-spell targeting route and styled dialog, and pass
  focused validator checks. Runtime code/packages did not change afterward.
  The 26 absent historical non-RMG smoke reports are explicitly **not run**,
  not reported as passes; their absence follows the owner retention policy.
- Cleanup removed **33 task-owned targets / 1,522,750,220 logical bytes** after
  checking exact paths and process references. Disposable screenshots, reports,
  probes and test exports are rebuildable. The three Wine prefixes were also
  lifecycle-cleaned; their user data and source-test user data were preserved,
  as were caches, originals/provenance, saves, RMG material and unrelated files.

One broader legacy check is **not a pass**: the adventure-spell report expects
Survey Chain to reveal additional River Pass tiles, but reports 24 explored
tiles both before and after. Re-running the unchanged report against
`OverworldRules.gd` from pre-slice HEAD `39aa6e0a` reproduces the identical
failure; the spell succeeds and spends mana in both. This slice does not alter
fog/reveal rules or weaken that assertion. Historical manual-study/footer-icon
UI reports are not used to claim the new automatic-learning/book flow passes;
the Python-owned spellbook regression covers their replacement interaction.

Reproduction (fresh labels; Linux/Windows package locations are task-owned):

```sh
python3 -B tests/spellbook_regression.py --label source --render --resolution 1280x720 --timeout-seconds 240
python3 -B tests/hero_sheet_regression.py --label spellbook --render --resolution 1280x720 --timeout-seconds 240
python3 -B tests/targeting_commit_regression.py --label spellbook --render --resolution 1280x720 --timeout-seconds 240
python3 -B tests/validate_repo.py
HEROES_PACKAGING_LINUX_ARTIFACT_DIR=/root/dev/heroes-like/.artifacts/spellbook-linux python3 -B tests/packaging_linux_export_smoke.py
HEROES_PACKAGING_WINDOWS_ARTIFACT_DIR=/root/dev/heroes-like/.artifacts/spellbook-windows python3 -B tests/packaging_windows_export_smoke.py
python3 -B tests/spellbook_regression.py --platform linux --binary /root/dev/heroes-like/.artifacts/spellbook-linux/export/heroes-like.x86_64 --pack /root/dev/heroes-like/.artifacts/spellbook-linux/export/heroes-like.pck --label release-linux --render --resolution 1920x1080 --timeout-seconds 360
python3 -B tests/spellbook_regression.py --platform windows --binary /root/dev/heroes-like/.artifacts/spellbook-windows/export/heroes-like.exe --pack /root/dev/heroes-like/.artifacts/spellbook-windows/export/heroes-like.pck --wine-prefix /root/dev/heroes-like/.artifacts/spellbook-windows/book-prefix --label release-windows --resolution 1280x720 --timeout-seconds 360
git diff --check
```

Windows evidence is headless Wine, not physical Windows GPU certification.
Generated evidence/test packages are disposable under the owner cleanup policy;
this source report and reproducible probes are retained, not historical PNGs.
