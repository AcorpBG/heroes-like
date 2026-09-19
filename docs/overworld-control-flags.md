# Town and mine control flags

Slice: `art-control-flags-20260920`

Towns show two small flags flanking their existing entrance, replacing the large ownership pennant above the roof. The entrance and footprint from [Town landmark scale](overworld-town-scale.md) remain unchanged. Decorative banners painted into the town artwork remain part of that artwork.

Mines show one smaller flag beside their entrance. Uncontrolled mines use neutral grey; captured mines use the controlling player's colour until captured by someone else or released. This includes the common wood/ore/gold buildings and generated rare-resource mines. Loose reward pickups do not receive control flags.

The flags reuse the original neutral cloth painting. A shared shader colours the cloth while preserving its folds and the pole. Town flags use a 0.76-tile canvas and mine flags a 0.58-tile canvas; the transparent source margin makes the painted flags smaller. Existing accessibility marks remain optional. Flags clip against explored cells.

Generated players use a stable colour by player slot, independent of faction. Legacy authored scenarios use their existing player/enemy semantic colours. Towns read `controlling_player_id`; mines read `collected_by_player_id`, with the existing faction fallback for old saves. Both render-cache signatures include the controller ID so a capture between players of the same faction changes the flag immediately.

Ownership, income, capture rules, native placement, collision and saved data are unchanged. Reloading the updated game applies the flags to existing maps and held mines; map regeneration is unnecessary.

## Focused verification

`tests/overworld_control_flags_regression.py` renders a town, all three common mines and a rare mine. Its 48 checks pass for entrance placement, smaller mine scale, grey/uncontrolled state, player capture, same-faction recapture, release, actual pixel changes, fog clipping, legacy colour compatibility and unchanged presentation/save state. Neutral, captured and recaptured renders were visually reviewed. The existing town-pennant report passes at 1280×720 and 1920×1080, and the focused flag source contract passes. Both now describe entrance pairs instead of the retired roof flag. The full repository, native RMG and package suites were not run for this presentation change.

```powershell
python -B tests/overworld_control_flags_regression.py --godot D:\Games\godot\Godot_v4.6.2-stable_win64_console.exe --output .artifacts/control-flags-review
```

The helper uses a disposable profile, an offscreen window on Windows and Xvfb on Linux. Review images and logs can be rebuilt and should be removed after inspection.
