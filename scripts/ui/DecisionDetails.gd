extends RefCounted
## Read-only decision summaries. Rule simulations operate on deep copies only.
const Artifacts := preload("res://scripts/core/ArtifactRules.gd")

static func resource_shortfall(cost: Dictionary, stock: Dictionary) -> Dictionary:
	var missing := {}
	for key in cost:
		var amount := maxi(0, int(cost[key]) - int(stock.get(key, 0)))
		if amount > 0: missing[key] = amount
	return missing

static func artifact_comparison(hero: Dictionary, artifact_id: String) -> String:
	var baseline := hero.duplicate(true)
	var result := Artifacts.equip_artifact(baseline.duplicate(true), artifact_id)
	if not bool(result.get("ok", false)): return String(result.get("message", "Cannot compare this artifact."))
	var before := Artifacts.aggregate_bonuses(baseline)
	var after := Artifacts.aggregate_bonuses(result.hero.duplicate(true))
	var lines: Array[String] = ["Preview only · " + Artifacts.artifact_decision_summary(hero.duplicate(true), artifact_id)]
	var keys: Array = after.keys()
	keys.sort()
	for key in keys:
		if not (after[key] is int or after[key] is float): continue
		var change := float(after[key]) - float(before.get(key, 0))
		if is_zero_approx(change): continue
		lines.append("%s: %s%s" % [String(key).replace("battle_", "").replace("_", " ").capitalize(), "+" if change > 0 else "", str(change)])
	var income_before: Dictionary = before.get("daily_income", {})
	var income_after: Dictionary = after.get("daily_income", {})
	var resources: Array = income_before.keys()
	for key in income_after:
		if key not in resources: resources.append(key)
	resources.sort()
	for resource in resources:
		var change := int(income_after.get(resource, 0)) - int(income_before.get(resource, 0))
		if change != 0: lines.append("Daily %s: %s%d" % [String(resource).replace("_", " "), "+" if change > 0 else "", change])
	if before.get("active_sets", []) != after.get("active_sets", []):
		lines.append("Set effects after replacement: " + Artifacts.describe_set_bonus_summary(result.hero.duplicate(true)))
	if lines.size() == 1: lines.append("No change to aggregate numeric bonuses; inspect the artifact's special effects.")
	lines.append("Special effects: " + Artifacts.artifact_effect_summary(artifact_id))
	return "\n".join(lines)
