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

## The same body as cells() (width() inlined), read without building it: fits
## and distance run for every hex of every walk and strike the battle weighs.
static func fits(stack: Dictionary, anchor: Dictionary, occupied: Dictionary, columns: int, rows: int) -> bool:
	var origin: Variant = stack.get("hex", {}) if anchor.is_empty() else anchor
	var q := -1
	var r := -1
	if origin is Vector2i:
		q = origin.x
		r = origin.y
	elif origin is Dictionary and not origin.is_empty():
		q = int(origin.get("q", origin.get("x", -1)))
		r = int(origin.get("r", origin.get("y", -1)))
	if q < 0 or r < 0: return false
	var wide := int(stack.get("battle_footprint", 1)) == 2
	var identity := String(stack.get("battle_id", ""))
	if q >= columns or r >= rows: return false
	var key := "%d,%d" % [q, r]
	if occupied.has(key) and (identity.is_empty() or String(occupied[key]) != identity): return false
	if wide:
		var tail_q := q + (1 if String(stack.get("side", "player")) == "enemy" else -1)
		if tail_q < 0 or tail_q >= columns: return false
		key = "%d,%d" % [tail_q, r]
		if occupied.has(key) and (identity.is_empty() or String(occupied[key]) != identity): return false
	return true

static func distance(lhs: Dictionary, rhs: Dictionary, lhs_anchor: Dictionary = {}) -> int:
	var origin: Variant = lhs.get("hex", {}) if lhs_anchor.is_empty() else lhs_anchor
	var a_q := -1
	var a_r := -1
	if origin is Vector2i:
		a_q = origin.x
		a_r = origin.y
	elif origin is Dictionary and not origin.is_empty():
		a_q = int(origin.get("q", origin.get("x", -1)))
		a_r = int(origin.get("r", origin.get("y", -1)))
	if a_q < 0 or a_r < 0: return 999
	var a_tail := a_q
	if int(lhs.get("battle_footprint", 1)) == 2:
		a_tail = a_q + (1 if String(lhs.get("side", "player")) == "enemy" else -1)
	origin = rhs.get("hex", {})
	var b_q := -1
	var b_r := -1
	if origin is Vector2i:
		b_q = origin.x
		b_r = origin.y
	elif origin is Dictionary and not origin.is_empty():
		b_q = int(origin.get("q", origin.get("x", -1)))
		b_r = int(origin.get("r", origin.get("y", -1)))
	if b_q < 0 or b_r < 0: return 999
	var b_tail := b_q
	if int(rhs.get("battle_footprint", 1)) == 2:
		b_tail = b_q + (1 if String(rhs.get("side", "player")) == "enemy" else -1)
	# Cube distance between every body cell pair; both cells of a body share
	# its row, so the row shift and the odd-row offsets are shared too.
	var a_shift := int((a_r - a_r % 2) / 2)
	var b_shift := int((b_r - b_r % 2) / 2)
	var dz := a_r - b_r
	var dx := (a_q - a_shift) - (b_q - b_shift)
	var nearest := mini(999, int((absi(dx) + absi(dz) + absi(dx + dz)) / 2))
	if b_tail != b_q:
		dx = (a_q - a_shift) - (b_tail - b_shift)
		nearest = mini(nearest, int((absi(dx) + absi(dz) + absi(dx + dz)) / 2))
	if a_tail != a_q:
		dx = (a_tail - a_shift) - (b_q - b_shift)
		nearest = mini(nearest, int((absi(dx) + absi(dz) + absi(dx + dz)) / 2))
		if b_tail != b_q:
			dx = (a_tail - a_shift) - (b_tail - b_shift)
			nearest = mini(nearest, int((absi(dx) + absi(dz) + absi(dx + dz)) / 2))
	return nearest
