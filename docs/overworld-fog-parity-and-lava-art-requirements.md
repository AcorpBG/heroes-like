# Overworld Fog Parity And Lava Art Requirements

Task: #10233
Parent: Phase 6 - Production Alpha Layer
Status: implemented and validated 2026-09-04

## Problem

The latest generated-map evidence was captured through a reveal-all art fixture, so neither the main map nor minimap demonstrated the production permanent-exploration fog contract. Separately, the lava/ash blocker palette uses bright, repeated motifs that sit on top of the terrain instead of reading as one harsh natural mass.

## Required behavior

- Normal generated play must derive both the main-map shroud and minimap concealment from the same authoritative `session.overworld.fog.explored_tiles` state.
- Unexplored tiles must be visibly concealed on both surfaces; permanently explored terrain must remain visible. `visible_tiles` remains compatibility/cache data and must not create a second stale-information rule.
- Deterministic movement must update both presentations from the same explored-state mutation. Reveal-all behavior may exist only through an explicit test/debug path and must be labeled as such in evidence.
- Lava/ash generated blocker cells must resolve original manifest-backed transparent raster art with a cohesive top-down perspective, dark basalt/ash palette, restrained ember accents, organic silhouettes, and landscape-grounded edges.
- The art pipeline must preserve source provenance, runtime imports, alpha, deterministic biome selection, and Linux/Windows package parity below 250,000,000 bytes.

## Preserved authority

This slice does not change exploration radius or rules, hidden-information policy, map topology, terrain ids, roads, package placements, blocker bodies, collision, pathing, interactions, rewards, AI, deterministic generation, Native RMG output, save schema/version, camera controls, or input semantics.

## Validation

- A focused Godot report compares authoritative fog coordinates/counts with both presentation surfaces before and after movement and captures 1920x1080 plus 1280x720 normal-play screenshots.
- Focused art validation proves every affected lava body uses loadable registered raster art, contains no procedural fallback, retains transparent corners, and preserves exact body/session/package authority.
- Existing movement/save and generated object-art reports, `python3 tests/validate_repo.py`, `git diff --check`, and established Linux/Windows export/package startup and generated-entry checks pass.
- Final screenshots are visually inspected before delivery through Proca on Discord.

## Non-goals

No RMG tuning, placement/density changes, gameplay or balance changes, new fog mechanics, art from copyrighted Heroes sources, Town/Battle UI work, signing, publication, whole-game certification, or release-readiness claim.
