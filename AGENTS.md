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

## Process rules
- Update `PLAN.md` when scope, sequencing, or decisions change.
- Update `ops/progress.json` whenever a step starts, completes, or is blocked.
- If you make a major architectural choice, record it clearly in `project.md`.
- Prefer clear folder structure and production-minded tooling over clever hacks.

## Completion marker
When finished with a run, print:
`FINAL: <what changed>; TESTS: <result>; STATUS: <done|blocked>`
