class_name SpellRules
extends RefCounted

const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")

const CONTEXT_OVERWORLD := "overworld"
const CONTEXT_BATTLE := "battle"
const SPELL_SCHOOL_IDS := ["beacon", "mire", "lens", "root", "furnace", "veil", "old_measure"]
const SPELL_ROLE_CATEGORIES := ["damage", "buff", "debuff", "control", "recovery", "summon_terrain", "economy_map_utility", "countermagic"]
const SPELL_PRIMARY_ROLES := [
	"movement_support",
	"priority_damage",
	"harry_damage",
	"control_damage",
	"isolation_damage",
	"ally_defense",
	"tempo_buff",
	"assault_buff",
]

static func build_spellbook(hero_template: Dictionary) -> Dictionary:
	var mana_max := mana_max_from_command(hero_template.get("command", {}))
	return {
		"known_spell_ids": _normalize_spell_ids(hero_template.get("starting_spell_ids", [])),
		"mana": {
			"current": mana_max,
			"max": mana_max,
		},
	}

static func ensure_hero_spellbook(hero_state: Dictionary, hero_template: Dictionary = {}) -> Dictionary:
	var max_mana := mana_max_from_hero(hero_state)
	var default_known_spells := _normalize_spell_ids(hero_template.get("starting_spell_ids", []))
	var spellbook = hero_state.get("spellbook", {})
	if not (spellbook is Dictionary):
		spellbook = {}

	var known_spell_ids: Array = _normalize_spell_ids(spellbook.get("known_spell_ids", default_known_spells))
	if known_spell_ids.is_empty() and not default_known_spells.is_empty():
		known_spell_ids = default_known_spells

	var mana: Dictionary = spellbook.get("mana", {})
	var current_mana := max_mana
	if mana is Dictionary and not mana.is_empty():
		current_mana = clamp(int(mana.get("current", max_mana)), 0, max_mana)

	hero_state["spellbook"] = {
		"known_spell_ids": known_spell_ids,
		"mana": {
			"current": current_mana,
			"max": max_mana,
		},
	}
	return hero_state

static func mana_max_from_hero(hero_state: Dictionary) -> int:
	return mana_max_from_command(hero_state.get("command", {})) + HeroProgressionRulesScript.mana_max_bonus(hero_state)

static func mana_max_from_command(command: Variant) -> int:
	if not (command is Dictionary):
		return 8
	return max(8, 8 + (max(0, int(command.get("knowledge", 0))) * 4))

static func refresh_daily_mana(hero_state: Dictionary) -> Dictionary:
	var hero: Dictionary = ensure_hero_spellbook(hero_state.duplicate(true))
	var spellbook = hero.get("spellbook", {})
	var mana = spellbook.get("mana", {})
	mana["current"] = int(mana.get("max", 0))
	spellbook["mana"] = mana
	hero["spellbook"] = spellbook
	return hero

static func mana_state(hero_state: Dictionary) -> Dictionary:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	return hero.get("spellbook", {}).get("mana", {})

static func knows_spell(hero_state: Dictionary, spell_id: String) -> bool:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	return _knows_spell(hero, spell_id)

static func learn_spell(hero_state: Dictionary, spell_id: String) -> Dictionary:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	var spell := ContentService.get_spell(spell_id)
	if spell.is_empty():
		return {"ok": false, "hero": hero, "message": "That spell is not known to the archives."}
	if _knows_spell(hero, spell_id):
		return {"ok": false, "hero": hero, "message": "%s already knows %s." % [String(hero.get("name", "The hero")), String(spell.get("name", spell_id))]}

	var spellbook = hero.get("spellbook", {})
	var known_spell_ids: Array = spellbook.get("known_spell_ids", [])
	if not (known_spell_ids is Array):
		known_spell_ids = []
	known_spell_ids.append(spell_id)
	spellbook["known_spell_ids"] = _normalize_spell_ids(known_spell_ids)
	hero["spellbook"] = spellbook
	return {
		"ok": true,
		"hero": hero,
		"message": "%s learns %s." % [String(hero.get("name", "The hero")), String(spell.get("name", spell_id))],
	}

static func known_spells(hero_state: Dictionary, context_filter: String = "") -> Array:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	var results := []
	for spell_id_value in hero.get("spellbook", {}).get("known_spell_ids", []):
		var spell_id := String(spell_id_value)
		if spell_id == "":
			continue
		var spell := ContentService.get_spell(spell_id)
		if spell.is_empty():
			continue
		if context_filter != "" and String(spell.get("context", "")) != context_filter:
			continue
		results.append(spell)
	return results

static func describe_spellbook(hero_state: Dictionary, context_filter: String = "") -> String:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	var mana: Dictionary = hero.get("spellbook", {}).get("mana", {})
	var label := "Spellbook"
	if context_filter == CONTEXT_OVERWORLD:
		label = "Field Spells"
	elif context_filter == CONTEXT_BATTLE:
		label = "Battle Spells"
	var lines := [
		"%s | Mana %d/%d" % [
			label,
			int(mana.get("current", 0)),
			int(mana.get("max", 0)),
		]
	]
	var spell_lines := []
	for spell in known_spells(hero, context_filter):
		var mana_cost: int = HeroProgressionRulesScript.adjusted_mana_cost(hero, int(spell.get("mana_cost", 0)))
		spell_lines.append(
			"- %s | %s | Cost %d | %s | %s | Use: %s" % [
				String(spell.get("name", spell.get("id", "Spell"))),
				spell_category_label(spell),
				mana_cost,
				_mana_readiness_label(hero, mana_cost),
				_spell_effect_summary(spell, hero),
				_best_use_line(spell),
			]
		)
	if spell_lines.is_empty():
		lines.append("- No known spells")
	else:
		lines.append_array(spell_lines)
	return "\n".join(lines)

static func spell_category_label(spell: Dictionary) -> String:
	var context := String(spell.get("context", ""))
	var effect = spell.get("effect", {})
	var effect_type := String(effect.get("type", ""))
	if context == CONTEXT_OVERWORLD:
		match effect_type:
			"restore_movement":
				return "Field Route"
			_:
				return "Field Utility"
	if context == CONTEXT_BATTLE:
		match effect_type:
			"damage_enemy":
				return "Battle Strike"
			"defense_buff":
				return "Battle Ward"
			"initiative_buff":
				return "Battle Tempo"
			"attack_buff":
				return "Battle Assault"
			_:
				return "Battle Utility"
	return "Unsorted Magic"

static func spell_school_id(spell: Dictionary) -> String:
	return String(spell.get("school_id", ""))

static func spell_tier(spell: Dictionary) -> int:
	return int(spell.get("tier", 0))

static func spell_primary_role(spell: Dictionary) -> String:
	return String(spell.get("primary_role", ""))

static func spell_role_categories(spell: Dictionary) -> Array:
	return _normalize_string_array(spell.get("role_categories", []))

static func spell_metadata_summary(spell: Dictionary) -> String:
	var school := spell_school_id(spell)
	var tier := spell_tier(spell)
	var primary_role := spell_primary_role(spell)
	var role_categories := spell_role_categories(spell)
	return "%s T%d | %s | %s" % [
		_school_label(school),
		tier,
		primary_role.replace("_", " ") if primary_role != "" else "unassigned role",
		", ".join(role_categories) if not role_categories.is_empty() else "no categories",
	]

static func spell_schema_report(spells: Array) -> Dictionary:
	var errors := []
	var school_counts := {}
	var tier_counts := {}
	var context_counts := {}
	var role_category_counts := {}
	var records := []
	for spell_value in spells:
		if not (spell_value is Dictionary):
			errors.append("Spell catalog contains a non-dictionary entry.")
			continue
		var spell: Dictionary = spell_value
		var spell_id := String(spell.get("id", ""))
		var school := spell_school_id(spell)
		var tier := spell_tier(spell)
		var primary_role := spell_primary_role(spell)
		var role_categories := spell_role_categories(spell)
		var context := String(spell.get("context", ""))
		var effect = spell.get("effect", {})
		var effect_type := String(effect.get("type", "")) if effect is Dictionary else ""
		_increment_count(school_counts, school)
		_increment_count(tier_counts, str(tier))
		_increment_count(context_counts, context)
		for role_category in role_categories:
			_increment_count(role_category_counts, String(role_category))
		_validate_spell_schema_record(errors, spell_id, school, tier, primary_role, role_categories, context, effect_type)
		records.append(
			{
				"id": spell_id,
				"school_id": school,
				"tier": tier,
				"context": context,
				"accord_family": String(spell.get("accord_family", "")),
				"primary_role": primary_role,
				"role_categories": role_categories,
				"metadata_summary": spell_metadata_summary(spell),
			}
		)
	return {
		"ok": errors.is_empty(),
		"schema_status": "loaded_spell_school_category_tier_metadata",
		"spell_count": records.size(),
		"school_counts": school_counts,
		"tier_counts": tier_counts,
		"context_counts": context_counts,
		"role_category_counts": role_category_counts,
		"errors": errors,
		"records": records,
	}

static func describe_spell_inspection_line(hero_state: Dictionary, spell: Dictionary, context_state: Dictionary = {}) -> String:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	var mana_cost: int = HeroProgressionRulesScript.adjusted_mana_cost(hero, int(spell.get("mana_cost", 0)))
	var readiness := _mana_readiness_label(hero, mana_cost)
	var context := String(spell.get("context", ""))
	if context == CONTEXT_OVERWORLD:
		var movement: Dictionary = context_state.get("movement", {})
		if not movement.is_empty():
			var validation := validate_overworld_spell(hero, movement, spell)
			readiness = "Ready" if bool(validation.get("ok", false)) else "Blocked: %s" % String(validation.get("message", "cannot cast now"))
		return "%s | %s | Cost %d | %s | %s | Use: %s" % [
			String(spell.get("name", "Spell")),
			spell_category_label(spell),
			mana_cost,
			readiness,
			_overworld_spell_effect_summary(spell, movement),
			_best_use_line(spell, movement),
		]
	if context == CONTEXT_BATTLE:
		var battle: Dictionary = context_state.get("battle", {})
		var active_stack: Dictionary = context_state.get("active_stack", {})
		var target_stack: Dictionary = context_state.get("target_stack", {})
		if not battle.is_empty():
			var validation := validate_battle_spell(hero, battle, active_stack, target_stack, spell)
			readiness = "Ready" if bool(validation.get("ok", false)) else "Blocked: %s" % String(validation.get("message", "cannot cast now"))
		return "%s | %s | Cost %d | %s | %s | Use: %s" % [
			String(spell.get("name", "Spell")),
			spell_category_label(spell),
			mana_cost,
			readiness,
			_battle_spell_effect_summary(hero, spell, battle, active_stack, target_stack),
			_best_use_line(spell, battle, active_stack, target_stack),
		]
	return "%s | %s | Cost %d | %s | %s | Use: %s" % [
		String(spell.get("name", "Spell")),
		spell_category_label(spell),
		mana_cost,
		readiness,
		_spell_effect_summary(spell, hero),
		_best_use_line(spell),
	]

static func describe_battle_spellbook(hero_state: Dictionary, battle: Dictionary, active_stack: Dictionary, target_stack: Dictionary) -> String:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	var mana: Dictionary = hero.get("spellbook", {}).get("mana", {})
	var lines := [
		"Battle Spells | Mana %d/%d" % [
			int(mana.get("current", 0)),
			int(mana.get("max", 0)),
		]
	]
	var spell_lines := []
	for spell in known_spells(hero, CONTEXT_BATTLE):
		spell_lines.append(
			"- %s" % describe_spell_inspection_line(
				hero,
				spell,
				{
					"battle": battle,
					"active_stack": active_stack,
					"target_stack": target_stack,
				}
			)
		)
	if spell_lines.is_empty():
		lines.append("- No battle spells known")
	else:
		lines.append_array(spell_lines)
	return "\n".join(lines)

static func describe_overworld_spellbook(hero_state: Dictionary, movement_state: Dictionary) -> String:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	var mana: Dictionary = hero.get("spellbook", {}).get("mana", {})
	var lines := [
		"Field Spells | Mana %d/%d" % [
			int(mana.get("current", 0)),
			int(mana.get("max", 0)),
		]
	]
	var spell_lines := []
	for spell in known_spells(hero, CONTEXT_OVERWORLD):
		var validation := validate_overworld_spell(hero, movement_state, spell)
		var mana_cost: int = HeroProgressionRulesScript.adjusted_mana_cost(hero, int(spell.get("mana_cost", 0)))
		spell_lines.append("- %s" % _overworld_spell_readability_line(hero, movement_state, spell, validation, mana_cost))
	if spell_lines.is_empty():
		lines.append("- No field spells known")
	else:
		lines.append_array(spell_lines)
	return "\n".join(lines)

static func describe_overworld_spell_rail(hero_state: Dictionary, movement_state: Dictionary) -> String:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	var mana: Dictionary = hero.get("spellbook", {}).get("mana", {})
	var actions := get_overworld_actions(hero, movement_state)
	if actions.is_empty():
		return "Field Magic | Mana %d/%d | No field spells known" % [
			int(mana.get("current", 0)),
			int(mana.get("max", 0)),
		]
	var focus: Dictionary = {}
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if not bool(action.get("disabled", false)):
			focus = action
			break
	if focus.is_empty():
		focus = actions[0]
	var state := "Ready" if not bool(focus.get("disabled", false)) else "Blocked"
	return "Field Magic | Mana %d/%d | %s: %s | %s | %s" % [
		int(mana.get("current", 0)),
		int(mana.get("max", 0)),
		state,
		String(focus.get("spell_name", focus.get("label", "Spell"))),
		String(focus.get("target_requirement", focus.get("target", ""))),
		String(focus.get("consequence", focus.get("effect", ""))),
	]

static func _mana_readiness_label(hero_state: Dictionary, mana_cost: int) -> String:
	var current_mana := int(hero_state.get("spellbook", {}).get("mana", {}).get("current", 0))
	if current_mana >= max(0, mana_cost):
		return "Ready mana"
	return "Need %d mana" % max(0, mana_cost - current_mana)

static func _spell_effect_summary(spell: Dictionary, hero_state: Dictionary) -> String:
	match String(spell.get("context", "")):
		CONTEXT_OVERWORLD:
			return _overworld_spell_effect_summary(spell, {})
		CONTEXT_BATTLE:
			return _battle_spell_effect_summary(hero_state, spell, {}, {}, {})
		_:
			return "No supported effect"

static func _battle_spell_effect_summary(
	hero_state: Dictionary,
	spell: Dictionary,
	battle: Dictionary = {},
	active_stack: Dictionary = {},
	target_stack: Dictionary = {}
) -> String:
	var effect = spell.get("effect", {})
	match String(effect.get("type", "")):
		"damage_enemy":
			var power := int(hero_state.get("command", {}).get("power", 0))
			var damage := int(max(1, int(effect.get("base_damage", 0)) + (max(0, power) * int(effect.get("power_scale", 0)))))
			var target_label := String(target_stack.get("name", "selected enemy"))
			var summary := "%d damage to %s" % [damage, target_label]
			var status_effect: Dictionary = effect.get("status_effect", {})
			if status_effect is Dictionary and not status_effect.is_empty():
				summary += "; applies %s %dr" % [
					String(status_effect.get("label", "effect")),
					max(1, int(status_effect.get("duration_rounds", 1))),
				]
			return summary
		"defense_buff", "initiative_buff", "attack_buff":
			var target_label := String(active_stack.get("name", "active stack"))
			return "%s to %s for %d rounds" % [
				_modifier_summary(battle_spell_modifiers(spell)),
				target_label,
				max(1, int(effect.get("duration_rounds", 1))),
			]
		_:
			return "No supported battle effect"

static func _best_use_line(
	spell: Dictionary,
	context: Dictionary = {},
	active_stack: Dictionary = {},
	target_stack: Dictionary = {}
) -> String:
	var effect = spell.get("effect", {})
	match String(effect.get("type", "")):
		"restore_movement":
			if not context.is_empty():
				var current := int(context.get("current", 0))
				var max_movement := int(context.get("max", 0))
				if current >= max_movement:
					return "save until movement has room"
			return "recover route tempo after spending movement"
		"damage_enemy":
			var damage_timing := battle_spell_timing_summary({}, context, active_stack, target_stack, spell)
			return damage_timing.trim_prefix("Best ").trim_suffix(".") if damage_timing != "" else "soften the selected enemy before a trade"
		"defense_buff":
			var defense_timing := battle_spell_timing_summary({}, context, active_stack, target_stack, spell)
			return defense_timing.trim_prefix("Best ").trim_suffix(".") if defense_timing != "" else "hold the stack that must absorb the reply"
		"initiative_buff":
			var initiative_timing := battle_spell_timing_summary({}, context, active_stack, target_stack, spell)
			return initiative_timing.trim_prefix("Best ").trim_suffix(".") if initiative_timing != "" else "win a contested activation window"
		"attack_buff":
			var attack_timing := battle_spell_timing_summary({}, context, active_stack, target_stack, spell)
			return attack_timing.trim_prefix("Best ").trim_suffix(".") if attack_timing != "" else "cast before an immediate damage order"
		_:
			var description := String(spell.get("description", "")).strip_edges()
			return description if description != "" else "use when the current board state supports it"

static func _legacy_spellbook_summary(hero_state: Dictionary, context_filter: String = "") -> String:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	var mana: Dictionary = hero.get("spellbook", {}).get("mana", {})
	var names := []
	for spell in known_spells(hero, context_filter):
		names.append(String(spell.get("name", spell.get("id", "Spell"))))
	var label := "Spellbook"
	if context_filter == CONTEXT_OVERWORLD:
		label = "Field Spells"
	elif context_filter == CONTEXT_BATTLE:
		label = "Battle Spells"
	return "%s | Mana %d/%d | %s" % [
		label,
		int(mana.get("current", 0)),
		int(mana.get("max", 0)),
		", ".join(names) if not names.is_empty() else "No known spells",
	]

static func get_overworld_actions(hero_state: Dictionary, movement_state: Dictionary) -> Array:
	var actions := []
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	for spell in known_spells(hero, CONTEXT_OVERWORLD):
		var validation := validate_overworld_spell(hero, movement_state, spell)
		var mana_cost: int = HeroProgressionRulesScript.adjusted_mana_cost(hero, int(spell.get("mana_cost", 0)))
		var summary := _overworld_spell_action_summary(movement_state, spell, validation, mana_cost)
		var category := spell_category_label(spell)
		var effect_summary := _overworld_spell_effect_summary(spell, movement_state)
		var readiness := "Ready" if bool(validation.get("ok", false)) else "Blocked: %s" % String(validation.get("message", "cannot cast now"))
		var mana_current := int(hero.get("spellbook", {}).get("mana", {}).get("current", 0))
		var mana_shortfall: int = max(0, mana_cost - mana_current)
		var why_cast := _best_use_line(spell, movement_state)
		actions.append(
			{
				"id": "cast_spell:%s" % String(spell.get("id", "")),
				"label": "Cast %s (%d mana)" % [String(spell.get("name", "Spell")), mana_cost],
				"spell_name": String(spell.get("name", "Spell")),
				"disabled": not bool(validation.get("ok", false)),
				"summary": summary,
				"cost": mana_cost,
				"category": category,
				"effect": effect_summary,
				"readiness": readiness,
				"best_use": why_cast,
				"target": _target_mode_label(String(spell.get("target_mode", "self"))),
				"target_requirement": _overworld_target_requirement(spell),
				"mana_state": "Mana %d/%d, need %d" % [
					mana_current,
					int(hero.get("spellbook", {}).get("mana", {}).get("max", mana_current)),
					mana_cost,
				],
				"mana_ready": mana_shortfall <= 0,
				"mana_shortfall": mana_shortfall,
				"consequence": effect_summary,
				"why_cast": why_cast,
				"availability": "ready" if bool(validation.get("ok", false)) else "blocked",
				"invalid_reason": String(validation.get("message", "")) if not bool(validation.get("ok", false)) else "",
			}
		)
	return actions

static func cast_overworld_spell(hero_state: Dictionary, movement_state: Dictionary, spell_id: String) -> Dictionary:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	var movement := movement_state.duplicate(true)
	if not _knows_spell(hero, spell_id):
		return {"ok": false, "hero": hero, "movement": movement, "message": "That spell is not in the spellbook."}
	var spell := ContentService.get_spell(spell_id)
	if spell.is_empty():
		return {"ok": false, "hero": hero, "movement": movement, "message": "That spell is not known."}
	var mana_cost: int = HeroProgressionRulesScript.adjusted_mana_cost(hero, int(spell.get("mana_cost", 0)))

	var validation := validate_overworld_spell(hero, movement, spell)
	if not bool(validation.get("ok", false)):
		return {"ok": false, "hero": hero, "movement": movement, "message": String(validation.get("message", "That spell cannot be cast now."))}

	var effect = spell.get("effect", {})
	match String(effect.get("type", "")):
		"restore_movement":
			var amount := int(max(1, int(effect.get("amount", 0))))
			var current := int(movement.get("current", 0))
			var max_movement := int(movement.get("max", 0))
			var restored: int = min(amount, max(0, max_movement - current))
			movement["current"] = min(max_movement, current + restored)
			hero = _consume_mana(hero, mana_cost)
			return {
				"ok": true,
				"hero": hero,
				"movement": movement,
				"message": "%s restores %d movement (%d -> %d) and spends %d mana." % [
					String(spell.get("name", spell_id)),
					restored,
					current,
					int(movement.get("current", 0)),
					mana_cost,
				],
			}
		_:
			return {"ok": false, "hero": hero, "movement": movement, "message": "That overworld spell has no supported effect."}

static func get_battle_actions(hero_state: Dictionary, battle: Dictionary, active_stack: Dictionary, target_stack: Dictionary) -> Array:
	var actions := []
	for spell in known_spells(hero_state, CONTEXT_BATTLE):
		var validation := validate_battle_spell(hero_state, battle, active_stack, target_stack, spell)
		var mana_cost: int = HeroProgressionRulesScript.adjusted_mana_cost(hero_state, int(spell.get("mana_cost", 0)))
		var summary := _battle_spell_action_summary(hero_state, battle, active_stack, target_stack, spell)
		var validation_message := String(validation.get("message", ""))
		if validation_message != "":
			summary = "%s Blocked: %s" % [summary, validation_message]
		summary = "%s | Cost %d mana | Target %s | %s %s" % [
			spell_category_label(spell),
			mana_cost,
			_target_mode_label(String(spell.get("target_mode", "self"))),
			"Ready." if bool(validation.get("ok", false)) else "",
			summary.strip_edges(),
		]
		actions.append(
			{
				"id": "cast_spell:%s" % String(spell.get("id", "")),
				"label": "Cast %s (%d)" % [String(spell.get("name", "Spell")), mana_cost],
				"disabled": not bool(validation.get("ok", false)),
				"summary": summary.strip_edges(),
				"cost": mana_cost,
				"category": spell_category_label(spell),
				"effect": _battle_spell_effect_summary(hero_state, spell, battle, active_stack, target_stack),
				"readiness": "Ready" if bool(validation.get("ok", false)) else "Blocked: %s" % validation_message,
				"target": _target_mode_label(String(spell.get("target_mode", "self"))),
				"best_use": _best_use_line(spell, battle, active_stack, target_stack),
			}
		)
	return actions

static func resolve_battle_spell(
	hero_state: Dictionary,
	battle: Dictionary,
	active_stack: Dictionary,
	target_stack: Dictionary,
	spell_id: String,
	acting_side: String = "player"
) -> Dictionary:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	if not _knows_spell(hero, spell_id):
		return {"ok": false, "hero": hero, "message": "That spell is not in the spellbook."}
	var spell := ContentService.get_spell(spell_id)
	if spell.is_empty():
		return {"ok": false, "hero": hero, "message": "That spell is not known."}
	var mana_cost: int = HeroProgressionRulesScript.adjusted_mana_cost(hero, int(spell.get("mana_cost", 0)))

	var validation := validate_battle_spell(hero, battle, active_stack, target_stack, spell, acting_side)
	if not bool(validation.get("ok", false)):
		return {"ok": false, "hero": hero, "message": String(validation.get("message", "That spell cannot be cast now."))}

	var effect = spell.get("effect", {})
	var effect_type := String(effect.get("type", ""))
	hero = _consume_mana(hero, mana_cost)
	var caster_name := String(hero.get("name", "The hero"))
	match effect_type:
		"damage_enemy":
			var power := int(hero.get("command", {}).get("power", 0))
			var damage := int(max(1, int(effect.get("base_damage", 0)) + (max(0, power) * int(effect.get("power_scale", 0)))))
			return {
				"ok": true,
				"hero": hero,
				"resolution_type": "damage",
				"target_battle_id": String(target_stack.get("battle_id", "")),
				"damage": damage,
				"post_damage_effect": _status_effect_from_spell_effect(spell, battle),
				"message": "%s casts %s on %s for %d damage." % [
					caster_name,
					String(spell.get("name", spell_id)),
					String(target_stack.get("name", "the enemy")),
					damage,
				],
			}
		"defense_buff":
			return {
				"ok": true,
				"hero": hero,
				"resolution_type": "effect",
				"target_battle_id": String(active_stack.get("battle_id", "")),
				"effect": _effect_payload(spell, effect, battle),
				"message": "%s casts %s on %s." % [caster_name, String(spell.get("name", spell_id)), String(active_stack.get("name", "the line"))],
			}
		"initiative_buff", "attack_buff":
			return {
				"ok": true,
				"hero": hero,
				"resolution_type": "effect",
				"target_battle_id": String(active_stack.get("battle_id", "")),
				"effect": _effect_payload(spell, effect, battle),
				"message": "%s casts %s on %s." % [caster_name, String(spell.get("name", spell_id)), String(active_stack.get("name", "the line"))],
			}
		_:
			return {"ok": false, "hero": hero, "message": "That battle spell has no supported effect."}

static func validate_overworld_spell(hero_state: Dictionary, movement_state: Dictionary, spell: Variant) -> Dictionary:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	var spell_dict: Dictionary = spell if spell is Dictionary else ContentService.get_spell(String(spell))
	if spell_dict.is_empty():
		return {"ok": false, "message": "That spell is not known."}
	if String(spell_dict.get("context", "")) != CONTEXT_OVERWORLD:
		return {"ok": false, "message": "That spell cannot be used on the overworld."}
	var mana_cost: int = HeroProgressionRulesScript.adjusted_mana_cost(hero, int(spell_dict.get("mana_cost", 0)))
	if not _has_mana(hero, mana_cost):
		var current_mana := int(hero.get("spellbook", {}).get("mana", {}).get("current", 0))
		return {"ok": false, "message": "Need %d mana; only %d available." % [mana_cost, current_mana]}

	var effect = spell_dict.get("effect", {})
	match String(effect.get("type", "")):
		"restore_movement":
			if int(movement_state.get("current", 0)) >= int(movement_state.get("max", 0)):
				return {"ok": false, "message": "Movement is already full."}
			return {"ok": true}
		_:
			return {"ok": false, "message": "That overworld spell effect is unsupported."}

static func validate_battle_spell(
	hero_state: Dictionary,
	battle: Dictionary,
	active_stack: Dictionary,
	target_stack: Dictionary,
	spell: Variant,
	acting_side: String = "player"
) -> Dictionary:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	var spell_dict: Dictionary = spell if spell is Dictionary else ContentService.get_spell(String(spell))
	if spell_dict.is_empty():
		return {"ok": false, "message": "That spell is not known."}
	if String(spell_dict.get("context", "")) != CONTEXT_BATTLE:
		return {"ok": false, "message": "That spell cannot be used in battle."}
	if active_stack.is_empty() or String(active_stack.get("side", "")) != acting_side:
		return {"ok": false, "message": "It is not this side's turn."}
	if not _has_mana(hero, HeroProgressionRulesScript.adjusted_mana_cost(hero, int(spell_dict.get("mana_cost", 0)))):
		return {"ok": false, "message": "Insufficient mana."}

	var effect = spell_dict.get("effect", {})
	match String(effect.get("type", "")):
		"damage_enemy":
			if target_stack.is_empty() or String(target_stack.get("side", "")) == acting_side:
				return {"ok": false, "message": "Select an enemy target first."}
			return {"ok": true}
		"defense_buff", "initiative_buff", "attack_buff":
			return {"ok": true}
		_:
			return {"ok": false, "message": "That battle spell effect is unsupported."}

static func effect_bonus_for_kind(stack: Dictionary, battle: Dictionary, kind: String) -> int:
	var total := 0
	var current_round := int(battle.get("round", 1))
	for effect in active_effects_for_round(stack, current_round):
		var modifiers = effect.get("modifiers", {})
		if modifiers is Dictionary:
			total += int(modifiers.get(kind, 0))
	return total

static func has_effect_id(stack: Dictionary, battle: Dictionary, effect_id: String) -> bool:
	if effect_id == "":
		return false
	var current_round := int(battle.get("round", 1))
	for effect in active_effects_for_round(stack, current_round):
		if String(effect.get("effect_id", "")) == effect_id:
			return true
	return false

static func has_any_effect_ids(stack: Dictionary, battle: Dictionary, effect_ids: Variant) -> bool:
	if not (effect_ids is Array):
		return false
	for effect_id_value in effect_ids:
		if has_effect_id(stack, battle, String(effect_id_value)):
			return true
	return false

static func active_effects_for_round(stack: Dictionary, round_number: int) -> Array:
	var results := []
	for effect in _normalize_effects(stack.get("effects", [])):
		if int(effect.get("expires_after_round", 0)) >= round_number:
			results.append(effect)
	return results

static func effect_summary(stack: Dictionary, battle: Dictionary) -> String:
	var tags := []
	var current_round := int(battle.get("round", 1))
	for effect in active_effects_for_round(stack, current_round):
		var rounds_left := int(effect.get("expires_after_round", current_round)) - current_round + 1
		tags.append("%s %dr" % [String(effect.get("label", effect.get("kind", "Effect"))), max(1, rounds_left)])
	return ", ".join(tags)

static func normalize_stack_effects(stack: Dictionary) -> Dictionary:
	stack["effects"] = _normalize_effects(stack.get("effects", []))
	return stack

static func purge_expired_stack_effects(stack: Dictionary, round_number: int) -> Dictionary:
	var active := []
	for effect in _normalize_effects(stack.get("effects", [])):
		if int(effect.get("expires_after_round", 0)) >= round_number:
			active.append(effect)
	stack["effects"] = active
	return stack

static func build_battle_effect(
	effect_id: String,
	label: String,
	modifiers: Variant,
	duration_rounds: int,
	battle: Dictionary,
	source_type: String = "status",
	source_id: String = ""
) -> Dictionary:
	var normalized_modifiers := _normalize_effect_modifiers(modifiers)
	var fallback_kind := ""
	var fallback_amount := 0
	for key in normalized_modifiers.keys():
		fallback_kind = String(key)
		fallback_amount = int(normalized_modifiers[key])
		break
	return {
		"effect_id": effect_id,
		"source_type": source_type,
		"source_id": source_id,
		"spell_id": source_id if source_type == "spell" else "",
		"label": label if label != "" else fallback_kind.capitalize(),
		"kind": fallback_kind,
		"amount": fallback_amount,
		"modifiers": normalized_modifiers,
		"expires_after_round": max(1, int(battle.get("round", 1))) + max(1, duration_rounds) - 1,
	}

static func battle_spell_modifiers(spell: Dictionary) -> Dictionary:
	var effect = spell.get("effect", {})
	match String(effect.get("type", "")):
		"defense_buff":
			return _spell_effect_modifiers(effect, "defense", int(effect.get("amount", 0)))
		"initiative_buff":
			return _spell_effect_modifiers(effect, "initiative", int(effect.get("amount", 0)))
		"attack_buff":
			return _spell_effect_modifiers(effect, "attack", int(effect.get("amount", 0)))
		_:
			return {}

static func _effect_payload(spell: Dictionary, effect: Dictionary, battle: Dictionary) -> Dictionary:
	var modifiers := battle_spell_modifiers(spell)
	return build_battle_effect(
		"spell:%s:%s" % [String(spell.get("id", "")), String(effect.get("type", ""))],
		String(spell.get("name", "Spell")),
		modifiers,
		int(effect.get("duration_rounds", 1)),
		battle,
		"spell",
		String(spell.get("id", ""))
	)

static func _battle_spell_action_summary(
	hero_state: Dictionary,
	battle: Dictionary,
	active_stack: Dictionary,
	target_stack: Dictionary,
	spell: Dictionary
) -> String:
	var timing_hint := battle_spell_timing_summary(hero_state, battle, active_stack, target_stack, spell)
	var effect = spell.get("effect", {})
	match String(effect.get("type", "")):
		"damage_enemy":
			var power := int(hero_state.get("command", {}).get("power", 0))
			var damage := int(max(1, int(effect.get("base_damage", 0)) + (max(0, power) * int(effect.get("power_scale", 0)))))
			var summary := "Projected %d damage to %s." % [
				damage,
				String(target_stack.get("name", "the selected enemy")),
			]
			var status_effect: Dictionary = effect.get("status_effect", {})
			if status_effect is Dictionary and not status_effect.is_empty():
				summary += " Applies %s for %d rounds." % [
					String(status_effect.get("label", "a battle effect")),
					max(1, int(status_effect.get("duration_rounds", 1))),
				]
			if timing_hint != "":
				summary += " Timing: %s" % timing_hint
			return summary
		"defense_buff":
			var summary := "Grant %s to %s for %d rounds." % [
				_modifier_summary(battle_spell_modifiers(spell)),
				String(active_stack.get("name", "the active stack")),
				max(1, int(effect.get("duration_rounds", 1))),
			]
			if timing_hint != "":
				summary += " Timing: %s" % timing_hint
			return summary
		"initiative_buff", "attack_buff":
			var summary := "Grant %s to %s for %d rounds." % [
				_modifier_summary(battle_spell_modifiers(spell)),
				String(active_stack.get("name", "the active stack")),
				max(1, int(effect.get("duration_rounds", 1))),
			]
			if timing_hint != "":
				summary += " Timing: %s" % timing_hint
			return summary
		_:
			return "No authored battle summary is available for this spell."

static func battle_spell_timing_summary(
	hero_state: Dictionary,
	battle: Dictionary,
	active_stack: Dictionary,
	target_stack: Dictionary,
	spell: Dictionary
) -> String:
	if spell.is_empty() or active_stack.is_empty():
		return ""
	var effect = spell.get("effect", {})
	match String(effect.get("type", "")):
		"damage_enemy":
			var status_effect = effect.get("status_effect", {})
			var effect_id := String(status_effect.get("effect_id", status_effect.get("status_id", "")))
			if effect_id == "status_harried":
				if _side_has_any_ability(battle, String(active_stack.get("side", "")), ["backstab", "bloodrush", "shielding"]):
					return "Best before your finisher stacks close on the marked target."
				if int(battle.get("distance", 1)) > 0:
					return "Best while the firing lane stays open and the mark can carry into melee."
			elif effect_id == "status_staggered":
				if _side_has_any_ability(battle, String(active_stack.get("side", "")), ["formation_guard", "reach", "brace"]):
					return "Best on a fast anchor before the grounded trade starts."
				return "Best on the next high-initiative threat before it can seize tempo."
			if bool(active_stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0:
				return "Best while range still buys a clean spell strike."
			return "Best when the selected target must lose tempo immediately."
		"defense_buff":
			if has_any_effect_ids(active_stack, battle, ["status_harried", "status_staggered"]):
				return "Best when the acting stack is already pressured and has to survive the reply."
			if _health_ratio(active_stack) <= 0.65:
				return "Best when the acting stack is wounded enough that the next trade could crack it."
			if int(battle.get("distance", 1)) <= 0:
				return "Best once contact is live and the front stack must hold."
			return "Best on turns where this stack must absorb the enemy reply."
		"initiative_buff":
			if bool(active_stack.get("ranged", false)) and int(active_stack.get("shots_remaining", 0)) > 0:
				return "Best before the next volley or before the lane closes."
			if not bool(active_stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0:
				return "Best before the close so this stack wins the contact race."
			return "Best before a contested activation window swings away."
		"attack_buff":
			if bool(active_stack.get("ranged", false)) and int(active_stack.get("shots_remaining", 0)) > 0:
				return "Best before spending the next volley."
			if not target_stack.is_empty() and _health_ratio(target_stack) <= 0.75:
				return "Best while the selected target is wounded enough to break."
			if int(battle.get("distance", 1)) <= 0:
				return "Best once contact is open and the stack can cash the buff immediately."
			return "Best immediately before a damage trade."
		_:
			return ""

static func _overworld_spell_action_summary(
	movement_state: Dictionary,
	spell: Dictionary,
	validation: Dictionary,
	mana_cost: int
) -> String:
	var target_label := _target_mode_label(String(spell.get("target_mode", "self")))
	var availability := "Ready now." if bool(validation.get("ok", false)) else "Blocked: %s" % String(validation.get("message", "cannot cast now"))
	var description := String(spell.get("description", "")).strip_edges()
	var consequence := _overworld_spell_effect_summary(spell, movement_state)
	var why_cast := _best_use_line(spell, movement_state)
	var pieces := [
		"%s | Consequence: %s." % [String(spell_category_label(spell)), consequence],
		"Cost %d mana; target %s; %s." % [mana_cost, target_label, _overworld_target_requirement(spell)],
		availability,
		"Why cast: %s." % why_cast,
	]
	if description != "":
		pieces.append(description)
	return " ".join(pieces)

static func _overworld_spell_readability_line(
	hero_state: Dictionary,
	movement_state: Dictionary,
	spell: Dictionary,
	validation: Dictionary,
	mana_cost: int
) -> String:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	var mana: Dictionary = hero.get("spellbook", {}).get("mana", {})
	var readiness := "Ready" if bool(validation.get("ok", false)) else "Blocked: %s" % String(validation.get("message", "cannot cast now"))
	return "%s | %s | %s | Mana %d/%d, need %d | %s | Consequence: %s | Why: %s" % [
		String(spell.get("name", "Spell")),
		spell_category_label(spell),
		readiness,
		int(mana.get("current", 0)),
		int(mana.get("max", 0)),
		mana_cost,
		_overworld_target_requirement(spell),
		_overworld_spell_effect_summary(spell, movement_state),
		_best_use_line(spell, movement_state),
	]

static func _overworld_spell_effect_summary(spell: Dictionary, movement_state: Dictionary) -> String:
	var effect = spell.get("effect", {})
	match String(effect.get("type", "")):
		"restore_movement":
			var amount: int = max(1, int(effect.get("amount", 0)))
			var current := int(movement_state.get("current", 0))
			var max_movement := int(movement_state.get("max", 0))
			var available_room: int = max(0, max_movement - current)
			if available_room > 0:
				return "Restores up to %d movement; %d can fit now" % [amount, min(amount, available_room)]
			return "Restores up to %d movement" % amount
		_:
			return "No supported overworld effect"

static func _overworld_target_requirement(spell: Dictionary) -> String:
	match String(spell.get("target_mode", "self")):
		"self":
			return "No map target; affects active hero"
		_:
			return "Choose %s before casting" % _target_mode_label(String(spell.get("target_mode", "")))

static func _target_mode_label(target_mode: String) -> String:
	match target_mode:
		"self":
			return "active hero"
		"ally_active":
			return "active allied stack"
		"enemy_selected":
			return "selected enemy"
		_:
			return target_mode.replace("_", " ")

static func _school_label(school_id: String) -> String:
	match school_id:
		"beacon":
			return "Beacon"
		"mire":
			return "Mire"
		"lens":
			return "Lens"
		"root":
			return "Root"
		"furnace":
			return "Furnace"
		"veil":
			return "Veil"
		"old_measure":
			return "Old Measure"
		_:
			return "Unassigned"

static func _validate_spell_schema_record(
	errors: Array,
	spell_id: String,
	school: String,
	tier: int,
	primary_role: String,
	role_categories: Array,
	context: String,
	effect_type: String
) -> void:
	if spell_id == "":
		errors.append("Spell record must define id.")
	if school not in SPELL_SCHOOL_IDS:
		errors.append("Spell %s uses unsupported school_id %s." % [spell_id, school])
	if tier < 1 or tier > 5:
		errors.append("Spell %s tier must be between 1 and 5." % spell_id)
	if primary_role not in SPELL_PRIMARY_ROLES:
		errors.append("Spell %s uses unsupported primary_role %s." % [spell_id, primary_role])
	if role_categories.is_empty():
		errors.append("Spell %s must define at least one role category." % spell_id)
	for role_category in role_categories:
		if String(role_category) not in SPELL_ROLE_CATEGORIES:
			errors.append("Spell %s uses unsupported role category %s." % [spell_id, role_category])
	if String(effect_type) == "restore_movement":
		if context != CONTEXT_OVERWORLD:
			errors.append("Spell %s restore_movement metadata must use overworld context." % spell_id)
		if primary_role != "movement_support":
			errors.append("Spell %s restore_movement metadata must use movement_support primary_role." % spell_id)
		if "economy_map_utility" not in role_categories:
			errors.append("Spell %s restore_movement metadata must include economy_map_utility." % spell_id)
	elif String(effect_type) == "damage_enemy":
		if context != CONTEXT_BATTLE:
			errors.append("Spell %s damage metadata must use battle context." % spell_id)
		if "damage" not in role_categories:
			errors.append("Spell %s damage metadata must include damage role category." % spell_id)
	elif String(effect_type) in ["defense_buff", "initiative_buff", "attack_buff"]:
		if context != CONTEXT_BATTLE:
			errors.append("Spell %s buff metadata must use battle context." % spell_id)
		if "buff" not in role_categories and "recovery" not in role_categories:
			errors.append("Spell %s buff metadata must include buff or recovery role category." % spell_id)

static func _increment_count(counts: Dictionary, key: String) -> void:
	var normalized_key := key if key != "" else "missing"
	counts[normalized_key] = int(counts.get(normalized_key, 0)) + 1

static func _normalize_string_array(value: Variant) -> Array:
	var results := []
	if value is Array:
		for entry in value:
			var normalized := String(entry).strip_edges()
			if normalized != "" and normalized not in results:
				results.append(normalized)
	return results

static func _normalize_spell_ids(value: Variant) -> Array:
	var ids := []
	if value is Array:
		for spell_id_value in value:
			var spell_id := String(spell_id_value)
			if spell_id != "":
				ids.append(spell_id)
	return ids

static func _normalize_effects(value: Variant) -> Array:
	var effects := []
	if value is Array:
		for effect in value:
			if not (effect is Dictionary):
				continue
			var modifiers = effect.get("modifiers", {})
			if not (modifiers is Dictionary):
				modifiers = {}
				var legacy_kind := String(effect.get("kind", ""))
				if legacy_kind != "":
					modifiers[legacy_kind] = int(effect.get("amount", 0))
			effects.append(
				{
					"effect_id": String(effect.get("effect_id", String(effect.get("spell_id", effect.get("kind", ""))))),
					"source_type": String(effect.get("source_type", "spell" if String(effect.get("spell_id", "")) != "" else "status")),
					"source_id": String(effect.get("source_id", effect.get("spell_id", ""))),
					"spell_id": String(effect.get("spell_id", "")),
					"label": String(effect.get("label", effect.get("kind", "Effect"))),
					"kind": String(effect.get("kind", "")),
					"amount": int(effect.get("amount", 0)),
					"modifiers": _normalize_effect_modifiers(modifiers),
					"expires_after_round": int(effect.get("expires_after_round", 0)),
				}
			)
	return effects

static func _normalize_effect_modifiers(value: Variant) -> Dictionary:
	var modifiers := {}
	if value is Dictionary:
		for key in value.keys():
			var modifier_key := String(key)
			if modifier_key == "":
				continue
			modifiers[modifier_key] = int(value[key])
	return modifiers

static func _spell_effect_modifiers(effect: Dictionary, default_kind: String, default_amount: int) -> Dictionary:
	var modifiers = effect.get("modifiers", {})
	if modifiers is Dictionary and not modifiers.is_empty():
		return _normalize_effect_modifiers(modifiers)
	return _normalize_effect_modifiers({default_kind: max(1, default_amount)})

static func _status_effect_from_spell_effect(spell: Dictionary, battle: Dictionary) -> Dictionary:
	var status_effect = spell.get("effect", {}).get("status_effect", {})
	if not (status_effect is Dictionary) or status_effect.is_empty():
		return {}
	var effect_id := String(status_effect.get("effect_id", status_effect.get("status_id", "")))
	if effect_id == "":
		return {}
	return build_battle_effect(
		effect_id,
		String(status_effect.get("label", effect_id.capitalize())),
		status_effect.get("modifiers", {}),
		int(status_effect.get("duration_rounds", 1)),
		battle,
		"spell",
		String(spell.get("id", ""))
	)

static func _modifier_summary(modifiers: Dictionary) -> String:
	if modifiers.is_empty():
		return "no battlefield bonus"
	var parts := []
	var ordered_keys := ["attack", "defense", "initiative", "cohesion", "momentum"]
	for key in ordered_keys:
		if modifiers.has(key):
			parts.append("%s %s" % [_signed_modifier_label(int(modifiers[key])), key])
	for modifier_key in modifiers.keys():
		var key := String(modifier_key)
		if ordered_keys.has(key):
			continue
		parts.append("%s %s" % [_signed_modifier_label(int(modifiers[key])), key])
	return ", ".join(parts)

static func _signed_modifier_label(amount: int) -> String:
	if amount > 0:
		return "+%d" % amount
	return "%d" % amount

static func _has_mana(hero_state: Dictionary, cost: int) -> bool:
	return int(hero_state.get("spellbook", {}).get("mana", {}).get("current", 0)) >= max(0, cost)

static func _consume_mana(hero_state: Dictionary, cost: int) -> Dictionary:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	var spellbook = hero.get("spellbook", {})
	var mana = spellbook.get("mana", {})
	mana["current"] = max(0, int(mana.get("current", 0)) - max(0, cost))
	spellbook["mana"] = mana
	hero["spellbook"] = spellbook
	return hero

static func _knows_spell(hero_state: Dictionary, spell_id: String) -> bool:
	for known_spell_id in hero_state.get("spellbook", {}).get("known_spell_ids", []):
		if String(known_spell_id) == spell_id:
			return true
	return false

static func _ability_by_id(stack: Dictionary, ability_id: String) -> Dictionary:
	if ability_id == "":
		return {}
	for ability in stack.get("abilities", []):
		if ability is Dictionary and String(ability.get("id", "")) == ability_id:
			return ability
	return {}

static func _has_ability(stack: Dictionary, ability_id: String) -> bool:
	return not _ability_by_id(stack, ability_id).is_empty()

static func _alive_stacks_for_side(battle: Dictionary, side: String) -> Array:
	var stacks := []
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary):
			continue
		if String(stack.get("side", "")) != side:
			continue
		if int(stack.get("total_health", 0)) <= 0 or int(stack.get("count", 0)) <= 0:
			continue
		stacks.append(stack)
	return stacks

static func _side_has_any_ability(battle: Dictionary, side: String, ability_ids: Array) -> bool:
	for stack in _alive_stacks_for_side(battle, side):
		for ability_id_value in ability_ids:
			if _has_ability(stack, String(ability_id_value)):
				return true
	return false

static func _health_ratio(stack: Dictionary) -> float:
	if stack.is_empty():
		return 0.0
	var count := int(max(1, int(stack.get("count", 0))))
	var max_health := int(max(1, int(stack.get("unit_hp", 1)) * count))
	return clampf(float(int(stack.get("total_health", 0))) / float(max_health), 0.0, 1.0)
