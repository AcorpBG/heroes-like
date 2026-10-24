extends RefCounted
## What an overworld action gave the player, for the floating gain text above
## the hero (OverworldGainFloaters). The shell takes a snapshot before an
## action and compares it with the state after, so every source counts
## (pickups, chests, mines, dwellings, visit buildings, reward choices, hires)
## without each rule reporting it. Read-only; presentation only.

const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")
static var _human_engine_mode: int = HumanEngine.mode

const STAT_NAMES := {"attack": "Attack", "defense": "Defense", "power": "Spell power", "knowledge": "Knowledge"}
const BOOST_NAMES := {"cohesion": "Cohesion", "momentum": "Momentum"}

## The parts of the session an overworld gain can change.
static func snapshot(session) -> Dictionary:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return snapshot__gd(session)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"OverworldGainFeed.snapshot", [session])
	var before := HumanEngine.before_writing(&"OverworldGainFeed.snapshot", [session])
	var result = snapshot__gd(session)
	HumanEngine.check_writing(&"OverworldGainFeed.snapshot", before, [session], result)
	return result

static func snapshot__gd(session) -> Dictionary:
	if session == null:
		return {}
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	var army := {}
	var stacks = hero.get("army", {}).get("stacks", []) if hero.get("army", {}) is Dictionary else []
	for stack in stacks if stacks is Array else []:
		if stack is Dictionary:
			var unit_id := String(stack.get("unit_id", ""))
			army[unit_id] = int(army.get(unit_id, 0)) + int(stack.get("count", 0))
	var owned := {}
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("collected_by_faction_id", "")) == "player":
			owned[String(node.get("placement_id", ""))] = String(node.get("site_id", ""))
	var spellbook: Dictionary = hero.get("spellbook", {}) if hero.get("spellbook", {}) is Dictionary else {}
	var mana: Dictionary = spellbook.get("mana", {}) if spellbook.get("mana", {}) is Dictionary else {}
	var movement: Dictionary = hero.get("movement", {}) if hero.get("movement", {}) is Dictionary else {}
	var boosts = hero.get("battle_boosts", {})
	return {
		"resources": (session.overworld.get("resources", {}) as Dictionary).duplicate(true) if session.overworld.get("resources", {}) is Dictionary else {},
		"hero_id": String(hero.get("id", "")),
		"experience": int(hero.get("experience", 0)),
		"command": (hero.get("command", {}) as Dictionary).duplicate(true) if hero.get("command", {}) is Dictionary else {},
		"artifacts": ArtifactRulesScript.owned_artifact_ids(hero),
		"spells": (spellbook.get("known_spell_ids", []) as Array).duplicate() if spellbook.get("known_spell_ids", []) is Array else [],
		"mana": int(mana.get("current", 0)),
		"movement": int(movement.get("current", 0)),
		"army": army,
		"boosts": boosts.duplicate(true) if boosts is Dictionary else {},
		"owned_sites": owned,
	}

## One line per gain, in the order they float: sites claimed, artifacts,
## resources gained, troops, command, spells, experience, mana, movement,
## battle boosts, then resources spent. Each line is {text, icon, tone}.
## `movement_walked` is the movement the action's walk spent, so a stable at
## the end of a route shows what it restored rather than the net change.
static func gains(before: Dictionary, after: Dictionary, movement_walked: int = 0) -> Array:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return gains__gd(before, after, movement_walked)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"OverworldGainFeed.gains", [before, after, movement_walked])
	var switch_before := HumanEngine.before_writing(&"OverworldGainFeed.gains", [before, after, movement_walked])
	var result = gains__gd(before, after, movement_walked)
	HumanEngine.check_writing(&"OverworldGainFeed.gains", switch_before, [before, after, movement_walked], result)
	return result

static func gains__gd(before: Dictionary, after: Dictionary, movement_walked: int = 0) -> Array:
	var lines := []
	if before.is_empty() or after.is_empty():
		return lines
	var owned_before: Dictionary = before.get("owned_sites", {})
	for placement_id in after.get("owned_sites", {}):
		if not owned_before.has(placement_id):
			var site := ContentService.get_resource_site(String(after.owned_sites[placement_id]))
			# Collected pickups are marked too; only sites the player keeps
			# (mines, dwellings, outposts) are claimed.
			if bool(site.get("persistent_control", false)):
				lines.append({"text": "%s claimed" % String(site.get("name", "Site")), "icon": "", "tone": "claim"})
	var same_hero := String(before.get("hero_id", "")) != "" and String(before.get("hero_id", "")) == String(after.get("hero_id", ""))
	if same_hero:
		for artifact_id in after.get("artifacts", []):
			if not (artifact_id in before.get("artifacts", [])):
				var artifact := ContentService.get_artifact(String(artifact_id))
				lines.append({"text": String(artifact.get("name", artifact_id)), "icon": ArtifactRulesScript.artifact_icon_path(String(artifact_id)), "tone": "artifact"})
	var spent := []
	var before_resources: Dictionary = before.get("resources", {})
	var after_resources: Dictionary = after.get("resources", {})
	for resource_id in _resource_order(before_resources, after_resources):
		var delta := int(after_resources.get(resource_id, 0)) - int(before_resources.get(resource_id, 0))
		if delta == 0:
			continue
		var line := {
			"text": "%s%d %s" % ["+" if delta > 0 else "-", absi(delta), OverworldRulesScript._resource_display_name(resource_id)],
			"icon": OverworldRulesScript.resource_icon_path(resource_id),
			"tone": "gain" if delta > 0 else "cost",
		}
		if delta > 0:
			lines.append(line)
		else:
			spent.append(line)
	if same_hero:
		var army_before: Dictionary = before.get("army", {})
		for unit_id in after.get("army", {}):
			var joined := int(after.army[unit_id]) - int(army_before.get(unit_id, 0))
			if joined > 0:
				var unit := ContentService.get_unit(String(unit_id))
				lines.append({"text": "+%d %s" % [joined, String(unit.get("name", unit_id))], "icon": String(ContentService.get_unit_art(String(unit_id)).get("portrait", "")), "tone": "gain"})
		for stat in STAT_NAMES:
			var raised := int(after.get("command", {}).get(stat, 0)) - int(before.get("command", {}).get(stat, 0))
			if raised > 0:
				lines.append({"text": "+%d %s" % [raised, STAT_NAMES[stat]], "icon": "", "tone": "gain"})
		for spell_id in after.get("spells", []):
			if not (spell_id in before.get("spells", [])):
				var spell := ContentService.get_spell(String(spell_id))
				lines.append({"text": "Learned %s" % String(spell.get("name", spell_id)), "icon": SpellRulesScript.spell_icon_path(String(spell_id)), "tone": "artifact"})
		for entry in [["experience", "Experience"], ["mana", "Mana"], ["movement", "Movement"]]:
			var raised := int(after.get(entry[0], 0)) - int(before.get(entry[0], 0))
			if entry[0] == "movement":
				raised += maxi(0, movement_walked)
			if raised > 0:
				lines.append({"text": "+%d %s" % [raised, entry[1]], "icon": "", "tone": "gain"})
		for boost in BOOST_NAMES:
			var raised := int(after.get("boosts", {}).get(boost, 0)) - int(before.get("boosts", {}).get(boost, 0))
			if raised > 0:
				lines.append({"text": "+%d %s next battle" % [raised, BOOST_NAMES[boost]], "icon": "", "tone": "gain"})
	lines.append_array(spent)
	return lines

## Gold, wood and ore first, then the rare resources, in stockpile order.
static func _resource_order(before: Dictionary, after: Dictionary) -> Array:
	var order := []
	for resource_id in OverworldRulesScript.LIVE_STOCKPILE_RESOURCE_KEYS:
		order.append(String(resource_id))
	for source in [before, after]:
		for resource_id in source:
			if String(resource_id) not in order and String(resource_id) != "experience":
				order.append(String(resource_id))
	return order
