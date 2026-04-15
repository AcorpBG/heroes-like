# AGENTS.md

This repository is for a full-production, release-bound fantasy strategy game inspired by the feel of Heroes of Might and Magic II.

## Read first
- `project.md`
- `PLAN.md`
- `ops/progress.json`

## Product rule
- This is not a toy prototype and not a fake MVP. Build toward a shippable product from day one.
- Still work in staged slices. Each slice should strengthen the final architecture, not create throwaway code.

## Engineering rules
- Default engine assumption: Godot 4 unless a documented decision in `project.md` changes it.
- Prefer data-driven content for factions, heroes, units, spells, map objects, resources, towns, and campaign metadata.
- Keep core systems modular: overworld, combat, AI, economy, save/load, UI, content pipeline.
- Avoid direct cloning of copyrighted names, assets, maps, factions, unit art, music, or text.
- Use original placeholder content where needed.
- No temporary git worktrees. Work directly in this repo.
- Local commits are fine when they are coherent. Do not push anywhere.

## Screen composition hard rules
- Do not cover the dominant screen surface with large text panels, stacked report boxes, or generic geometry just to expose existing data.
- If information does not fit in compact edge rails, a command spine, a footer pocket, tabs, or contextual popouts, hide it, collapse it, or move it off the main surface instead of laying more panels over the art.
- Scenic screens, especially the main menu, must stay scenery-first. The art or play surface is primary. Text is secondary.
- If a screen starts reading like a text dashboard, panel farm, or placeholder geometry mockup, stop and redesign the composition instead of polishing the same mistake.
- Preserve negative space. Do not spend the whole screen budget on labels, boxes, and explanatory text.
- Main-menu top-level buttons should open secondary menus or overlays for detailed options and selection flows. Do not dump all campaign, skirmish, save, guide, and settings detail directly onto the main menu surface.
- Keep the first-view main menu clean: a few obvious top-level commands on the main screen, deeper selection and configuration only after entering the relevant submenu.

## Process rules
- Update `PLAN.md` when scope, sequencing, or decisions change.
- Update `ops/progress.json` whenever a step starts, completes, or is blocked.
- If you make a major architectural choice, record it clearly in `project.md`.
- Prefer clear folder structure and production-minded tooling over clever hacks.

## Completion marker
When finished with a run, print:
`FINAL: <what changed>; TESTS: <result>; STATUS: <done|blocked>`
