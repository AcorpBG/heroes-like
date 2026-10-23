extends RefCounted
## Shared odd-row hex body geometry. No content lookup, RNG or state mutation.
## Saved stacks without footprint metadata retain their original one-cell body.

const BattleEngine = preload("res://scripts/core/BattleEngine.gd")

static func width(stack: Dictionary) -> int:
	return BattleEngine.native(&"BattleFootprint.width", [stack])

static func cells(stack: Dictionary, anchor: Dictionary = {}) -> Array:
	return BattleEngine.native(&"BattleFootprint.cells", [stack, anchor])

## The same body as cells() (width() inlined), read without building it: fits
## and distance run for every hex of every walk and strike the battle weighs.
static func fits(stack: Dictionary, anchor: Dictionary, occupied: Dictionary, columns: int, rows: int) -> bool:
	return BattleEngine.native(&"BattleFootprint.fits", [stack, anchor, occupied, columns, rows])

static func distance(lhs: Dictionary, rhs: Dictionary, lhs_anchor: Dictionary = {}) -> int:
	return BattleEngine.native(&"BattleFootprint.distance", [lhs, rhs, lhs_anchor])
