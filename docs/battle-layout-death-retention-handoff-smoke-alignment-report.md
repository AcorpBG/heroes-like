# Battle Layout Death Retention Handoff Smoke Alignment

Date: 2026-05-24

## Summary

This slice realigns `battle_layout_smoke` with the current battle presentation model after death-animation retention and routed outcome/menu save semantics changed.

Implemented changes:

- Killed target cells may remain visible during death playback only when they are zero-health, non-selected, non-legal, and absent from occupied-hex ownership.
- Routed final-kill save/menu assertions now use the real latest loadable summary when the main menu save browser is closed.
- Non-battle save recaps no longer fall back to stale battle action recaps or battle aftermath copy.
- BattleShell now uses compact banner labels and collapses secondary battle rail/header/footer surfaces on short or narrow viewports while preserving full text in tooltips and validation snapshots.
- BattleBoardView outer-ring validation now reports geometry coverage and samples a denser ring before declaring that no token-miss point exists.
- `battle_layout_smoke` can run a single viewport through `BATTLE_LAYOUT_SMOKE_VIEWPORT_INDEX` for focused regression isolation.

## Validation

Passed:

- `timeout 900s env GODOT_SILENCE_ROOT_WARNING=1 BATTLE_LAYOUT_SMOKE_VIEWPORT_INDEX=0 godot --headless --log-file /tmp/heroes-like-battle-layout-0.log --path . --scene res://tests/battle_layout_smoke.tscn`
- `timeout 900s env GODOT_SILENCE_ROOT_WARNING=1 BATTLE_LAYOUT_SMOKE_VIEWPORT_INDEX=1 godot --headless --log-file /tmp/heroes-like-battle-layout-1.log --path . --scene res://tests/battle_layout_smoke.tscn`
- `timeout 900s env GODOT_SILENCE_ROOT_WARNING=1 BATTLE_LAYOUT_SMOKE_VIEWPORT_INDEX=2 godot --headless --log-file /tmp/heroes-like-battle-layout-2.log --path . --scene res://tests/battle_layout_smoke.tscn`
- `timeout 2700s env GODOT_SILENCE_ROOT_WARNING=1 godot --headless --log-file /tmp/heroes-like-battle-layout-full.log --path . --scene res://tests/battle_layout_smoke.tscn`
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --log-file /tmp/heroes-like-battle-event.log --path . --quit-after 180 --scene res://tests/battle_event_animation_state_report.tscn`
- `python3 tests/validate_repo.py`
- `python3 -m py_compile tests/validate_repo.py`
- `jq empty ops/progress.json`
- `git diff --check`

## Non-Claims

This is not final battle UI art direction, final animation timing, broad combat balance, or a full battle UX redesign. It is a focused regression fix for death-retention presentation, routed save/menu truthfulness, compact battle layout framing, and occupied-hex click validation.
