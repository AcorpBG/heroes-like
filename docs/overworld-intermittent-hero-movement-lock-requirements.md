# Intermittent Overworld Hero Movement Lock Requirements

Task: #10227
Slice: `bugfix-overworld-intermittent-hero-movement-lock-10227`
Phase: Phase 6 - Production Alpha Layer

## Problem

An otherwise movable active hero can appear frozen because persistent F3 path profiling and F4 placement inspection overlays are classified as exclusive gameplay input owners. These overlays are non-modal, mouse-filter-ignoring observation layers and are documented to remain usable during normal movement, yet the shared keyboard/controller gate returns `debug_active` whenever either overlay is visible.

Legitimate refusal states must remain distinct: no movement points, blocked terrain or corner cuts, unresolved interaction constraints, open command drawers or modal dialogs, an active End Turn commit, and the short interval while a profiled path command is actually executing.

## Required behavior

- F3 and F4 may remain visible while keyboard, controller, pointer selection, and route execution operate normally.
- Only the transient `_debug_command_in_progress` state may claim debug input ownership; it must release after each command path.
- Existing drawers, settings, save confirmation, End Turn confirmation/commit, and presentation blockers remain authoritative input owners.
- A refused movement command must retain an actionable reason and must not mutate hero position, movement points, day, battle state, or save authority.
- Closing a real owner must not release a queued controller repeat or require reopening the Overworld.
- Movement budgets, path computation, blocked tiles, object interactions, and encounter/Town routing are unchanged.

## Validation

- Focused Godot runtime regression for separate and combined F3/F4 overlay movement using physical keyboard, left-stick movement, pointer route selection, and route commitment.
- Existing Overworld gameplay movement input-ownership regression updated to distinguish non-modal overlays from exclusive owners and to retain all modal/race assertions.
- Representative authored-session and generated-map movement coverage.
- Godot parse/load check, `python3 tests/validate_repo.py`, and `git diff --check`.
- Linux and Windows release export/package startup checks under the unchanged 250 MB PCK ceiling.

## Non-goals

No pathing topology, movement economy, map generation, object placement, interaction, AI, combat, Town, save schema, art, package ceiling, or unrelated cleanup changes.
