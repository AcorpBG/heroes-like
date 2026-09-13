extends RefCounted
## Shared odd-row hex body geometry. No content lookup, RNG or state mutation.
## Saved stacks without footprint metadata retain their original one-cell body.

static func width(stack: Dictionary) -> int:
	return 2 if int(stack.get("battle_footprint", 1)) == 2 else 1

static func cells(stack: Dictionary, anchor: Dictionary = {}) -> Array:
	var origin: Variant = stack.get("hex", {}) if anchor.is_empty() else anchor
	# Match the legacy rule boundary's accepted Vector2i and x/y forms.
	if origin is Vector2i: origin = {"q":origin.x,"r":origin.y}
	if not origin is Dictionary or origin.is_empty(): return []
	var q := int(origin.get("q", origin.get("x", -1)))
	var r := int(origin.get("r", origin.get("y", -1)))
	if q < 0 or r < 0: return []
	var result := [{"q":q,"r":r}]
	if width(stack) == 2:
		result.append({"q":q + (1 if String(stack.get("side", "player")) == "enemy" else -1),"r":r})
	return result

static func fits(stack: Dictionary, anchor: Dictionary, occupied: Dictionary, columns: int, rows: int) -> bool:
	var body := cells(stack, anchor)
	if body.is_empty(): return false
	var identity := String(stack.get("battle_id", ""))
	for cell in body:
		if cell.q < 0 or cell.r < 0 or cell.q >= columns or cell.r >= rows: return false
		var key := "%d,%d" % [cell.q, cell.r]
		if occupied.has(key) and (identity.is_empty() or String(occupied[key]) != identity): return false
	return true

static func distance(lhs: Dictionary, rhs: Dictionary, lhs_anchor: Dictionary = {}) -> int:
	var nearest := 999
	for a in cells(lhs, lhs_anchor):
		for b in cells(rhs):
			var ax := int(a.q) - int((int(a.r) - int(a.r) % 2) / 2)
			var bx := int(b.q) - int((int(b.r) - int(b.r) % 2) / 2)
			var dx := ax - bx
			var dz := int(a.r) - int(b.r)
			nearest = mini(nearest, int((absi(dx) + absi(dz) + absi(dx + dz)) / 2))
	return nearest
