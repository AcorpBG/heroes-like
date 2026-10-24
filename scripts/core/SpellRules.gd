class_name SpellRules
extends RefCounted

const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const BattleEngine = preload("res://scripts/core/BattleEngine.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")
static var _human_engine_mode: int = HumanEngine.mode
const CONTEXT_OVERWORLD := "overworld"
const CONTEXT_BATTLE := "battle"
const COMMON_RESOURCE_IDS := ["gold", "wood", "ore"]
const RARE_RESOURCE_IDS := ["aetherglass", "embergrain", "peatwax", "verdant_grafts", "brass_scrip", "memory_salt"]
const SPELL_SCHOOL_IDS := ["beacon", "mire", "lens", "root", "furnace", "veil", "old_measure"]
const MAX_SPELL_RESISTANCE_PCT := 75
# Hero field: the day of the hero's last overworld spell.
const OVERWORLD_SPELL_CAST_DAY_KEY := "overworld_spell_cast_day"
const MAX_CONTROL_RESISTANCE_PCT := 80
const SPELL_ROLE_CATEGORIES := ["damage", "buff", "debuff", "control", "recovery", "summon_terrain", "economy_map_utility", "countermagic"]
const SPELL_PRIMARY_ROLES := [
	"movement_support",
	"scouting_support",
	"priority_damage",
	"harry_damage",
	"control_damage",
	"control_enemy",
	"isolation_damage",
	"ally_defense",
	"ally_recovery",
	"countermagic_ward",
	"tempo_buff",
	"assault_buff",
]

static func spell_id_for_action(action_id: String) -> String:
	var spell_id := ""
	if action_id.begins_with("cast_spell:"):
		spell_id = action_id.trim_prefix("cast_spell:")
	elif action_id.begins_with("learn_spell:"):
		spell_id = action_id.trim_prefix("learn_spell:")
	return spell_id if not ContentService.get_spell(spell_id).is_empty() else ""

static func spell_school_icon_path(spell_id: String) -> String:
	var spell := ContentService.get_spell(spell_id)
	var school_id := String(spell.get("school_id", "")).strip_edges()
	if school_id not in SPELL_SCHOOL_IDS:
		return ""
	var icon := ContentService.get_spell_school_icon(school_id)
	var icon_path := String(icon.get("icon_path", "")).strip_edges()
	if String(icon.get("id", "")) != school_id:
		return ""
	if String(icon.get("icon_id", "")) != "spell_school_sigil_%s" % school_id:
		return ""
	if not icon_path.begins_with("res://art/magic/runtime/schools/") or not ResourceLoader.exists(icon_path, "Texture2D"):
		return ""
	return icon_path

static func spell_icon_path(spell_id: String) -> String:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return spell_icon_path__gd(spell_id)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native(&"SpellRules.spell_icon_path", [spell_id])
	var result = spell_icon_path__gd(spell_id)
	HumanEngine.check(&"SpellRules.spell_icon_path", [spell_id], result)
	return result

static func spell_icon_path__gd(spell_id: String) -> String:
	var spell := ContentService.get_spell(spell_id)
	if spell.is_empty():
		return ""
	var icon := ContentService.get_spell_icon(spell_id)
	var icon_path := String(icon.get("icon_path", "")).strip_edges()
	var school_id := String(spell.get("school_id", "")).strip_edges()
	if (
		String(icon.get("id", "")) == spell_id
		and String(icon.get("spell_id", "")) == spell_id
		and String(icon.get("school_id", "")) == school_id
		and String(icon.get("icon_id", "")) == "spell_signature_icon_%s" % spell_id.trim_prefix("spell_")
		and icon_path.begins_with("res://art/magic/runtime/spells/")
		and ResourceLoader.exists(icon_path, "Texture2D")
	):
		return icon_path
	return spell_school_icon_path(spell_id)

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
	return BattleEngine.native_writing(&"SpellRules.ensure_hero_spellbook", [hero_state, hero_template])

static func mana_max_from_hero(hero_state: Dictionary) -> int:
	return BattleEngine.native_writing(&"SpellRules.mana_max_from_hero", [hero_state])

static func mana_max_from_command(command: Variant) -> int:
	return BattleEngine.native(&"SpellRules.mana_max_from_command", [command])

## A hero casts at most one overworld spell per day.
static func cast_overworld_spell_on_day(hero: Dictionary, day: int) -> bool:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return cast_overworld_spell_on_day__gd(hero, day)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"SpellRules.cast_overworld_spell_on_day", [hero, day])
	var before := HumanEngine.before_writing(&"SpellRules.cast_overworld_spell_on_day", [hero, day])
	var result = cast_overworld_spell_on_day__gd(hero, day)
	HumanEngine.check_writing(&"SpellRules.cast_overworld_spell_on_day", before, [hero, day], result)
	return result

static func cast_overworld_spell_on_day__gd(hero: Dictionary, day: int) -> bool:
	return day > 0 and int(hero.get(OVERWORLD_SPELL_CAST_DAY_KEY, 0)) == day

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

static func adjusted_spell_mana_cost(hero_state: Dictionary, spell: Variant) -> int:
	return BattleEngine.native_writing(&"SpellRules.adjusted_spell_mana_cost", [hero_state, spell])

static func knows_spell(hero_state: Dictionary, spell_id: String) -> bool:
	# The list ensure_hero_spellbook gives a copy of the hero, read in place:
	# without a template it is the stored list, normalized, or none.
	var spellbook = hero_state.get("spellbook", {})
	if not (spellbook is Dictionary) or not spellbook.has("known_spell_ids"):
		return false
	return _normalize_spell_ids(spellbook["known_spell_ids"]).has(spell_id)

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
	return BattleEngine.native_writing(&"SpellRules.known_spells", [hero_state, context_filter])

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
		var mana_cost: int = adjusted_spell_mana_cost(hero, spell)
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
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return spell_category_label__gd(spell)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"SpellRules.spell_category_label", [spell])
	var before := HumanEngine.before_writing(&"SpellRules.spell_category_label", [spell])
	var result = spell_category_label__gd(spell)
	HumanEngine.check_writing(&"SpellRules.spell_category_label", before, [spell], result)
	return result

static func spell_category_label__gd(spell: Dictionary) -> String:
	var context := String(spell.get("context", ""))
	var effect = spell.get("effect", {})
	var effect_type := String(effect.get("type", ""))
	if context == CONTEXT_OVERWORLD:
		match effect_type:
			"restore_movement":
				return "Field Route"
			"reveal_radius":
				return "Field Survey"
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
	return BattleEngine.native(&"SpellRules.spell_school_id", [spell])

static func spell_tier(spell: Dictionary) -> int:
	return BattleEngine.native(&"SpellRules.spell_tier", [spell])

static func spell_primary_role(spell: Dictionary) -> String:
	return BattleEngine.native(&"SpellRules.spell_primary_role", [spell])

static func spell_role_categories(spell: Dictionary) -> Array:
	return BattleEngine.native(&"SpellRules.spell_role_categories", [spell])

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

static func adventure_spell_behavior(spell: Dictionary) -> Dictionary:
	if spell.is_empty() or String(spell.get("context", "")) != CONTEXT_OVERWORLD:
		return {}
	var effect = spell.get("effect", {})
	if not (effect is Dictionary):
		return {}
	var effect_type := String(effect.get("type", ""))
	var hooks := []
	var resolution_type := ""
	var target_policy := ""
	var public_effect := ""
	match effect_type:
		"restore_movement":
			resolution_type = "movement_restore"
			target_policy = "self_hero_movement_gap"
			hooks.append("overworld_movement_restore")
			hooks.append("mana_spend")
			hooks.append("movement_clamp")
			public_effect = "active hero movement recovery"
		"reveal_radius":
			resolution_type = "fog_reveal"
			target_policy = "self_hero_reveal_radius"
			hooks.append("overworld_fog_reveal")
			hooks.append("mana_spend")
			hooks.append("exploration_clamp")
			public_effect = "active hero scouting reveal"
		_:
			resolution_type = "unsupported"
			target_policy = "unsupported"
			public_effect = "unsupported adventure effect"
	return {
		"spell_id": String(spell.get("id", "")),
		"name": String(spell.get("name", "")),
		"school_id": spell_school_id(spell),
		"tier": spell_tier(spell),
		"primary_role": spell_primary_role(spell),
		"role_categories": spell_role_categories(spell),
		"effect_type": effect_type,
		"target_mode": String(spell.get("target_mode", "")),
		"target_policy": target_policy,
		"resolution_type": resolution_type,
		"runtime_hooks": hooks,
		"public_effect": public_effect,
		"map_mutation": "movement_only" if effect_type == "restore_movement" else ("fog_exploration" if effect_type == "reveal_radius" else "none"),
	}

static func adventure_spell_target_contract(hero_state: Dictionary, movement_state: Dictionary, spell: Variant) -> Dictionary:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	var spell_dict: Dictionary = spell if spell is Dictionary else ContentService.get_spell(String(spell))
	if spell_dict.is_empty():
		return {
			"ok": false,
			"spell_id": String(spell),
			"spell_name": "Unknown spell",
			"target_kind": "none",
			"target_requirement": "Known overworld spell",
			"selectable": false,
			"blocked_reason": "That spell is not known.",
			"public_text": "That spell is not known.",
		}
	var mana_cost: int = adjusted_spell_mana_cost(hero, spell_dict)
	var validation := validate_overworld_spell(hero, movement_state, spell_dict)
	var target_requirement := _overworld_target_requirement(spell_dict)
	var public_text := "%s targets the active hero; %s." % [
		String(spell_dict.get("name", "Spell")),
		target_requirement,
	]
	return {
		"ok": bool(validation.get("ok", false)),
		"spell_id": String(spell_dict.get("id", "")),
		"spell_name": String(spell_dict.get("name", "Spell")),
		"target_kind": "self_hero" if String(spell_dict.get("target_mode", "self")) == "self" else "unsupported",
		"target_mode": String(spell_dict.get("target_mode", "")),
		"target_requirement": target_requirement,
		"selectable": bool(validation.get("ok", false)),
		"blocked_reason": "" if bool(validation.get("ok", false)) else String(validation.get("message", "cannot cast now")),
		"mana_cost": mana_cost,
		"movement_current": int(movement_state.get("current", 0)),
		"movement_max": int(movement_state.get("max", 0)),
		"public_text": public_text,
	}

static func adventure_spell_consequence_preview(hero_state: Dictionary, movement_state: Dictionary, spell: Variant) -> Dictionary:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return adventure_spell_consequence_preview__gd(hero_state, movement_state, spell)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"SpellRules.adventure_spell_consequence_preview", [hero_state, movement_state, spell])
	var before := HumanEngine.before_writing(&"SpellRules.adventure_spell_consequence_preview", [hero_state, movement_state, spell])
	var result = adventure_spell_consequence_preview__gd(hero_state, movement_state, spell)
	HumanEngine.check_writing(&"SpellRules.adventure_spell_consequence_preview", before, [hero_state, movement_state, spell], result)
	return result

static func adventure_spell_consequence_preview__gd(hero_state: Dictionary, movement_state: Dictionary, spell: Variant) -> Dictionary:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	var spell_dict: Dictionary = spell if spell is Dictionary else ContentService.get_spell(String(spell))
	if spell_dict.is_empty():
		return {
			"ok": false,
			"spell_id": String(spell),
			"spell_name": "Unknown spell",
			"public_text": "That spell has no supported adventure consequence.",
		}
	var mana_cost: int = adjusted_spell_mana_cost(hero, spell_dict)
	var effect = spell_dict.get("effect", {})
	var effect_type := String(effect.get("type", "")) if effect is Dictionary else ""
	var preview := _movement_restore_preview(movement_state, spell_dict, hero)
	var supported := String(spell_dict.get("context", "")) == CONTEXT_OVERWORLD and effect_type in ["restore_movement", "reveal_radius"]
	var public_text := ""
	if supported and effect_type == "restore_movement":
		public_text = "%s restores %d movement now, capped at %d, and spends %d mana." % [
			String(spell_dict.get("name", "Spell")),
			int(preview.get("restored", 0)),
			int(preview.get("movement_max", 0)),
			mana_cost,
		]
	elif supported and effect_type == "reveal_radius":
		public_text = "%s reveals a scouting ring of radius %d around the active hero and spends %d mana." % [
			String(spell_dict.get("name", "Spell")),
			max(1, int(effect.get("amount", effect.get("radius", 0)))),
			mana_cost,
		]
	else:
		public_text = "That spell has no supported adventure consequence."
	return {
		"ok": supported,
		"spell_id": String(spell_dict.get("id", "")),
		"spell_name": String(spell_dict.get("name", "Spell")),
		"effect_type": effect_type,
		"movement_before": int(preview.get("movement_before", int(movement_state.get("current", 0)))),
		"movement_after": int(preview.get("movement_after", int(movement_state.get("current", 0)))),
		"movement_restored": int(preview.get("restored", 0)),
		"movement_max": int(preview.get("movement_max", int(movement_state.get("max", 0)))),
		"reveal_radius": max(0, int(effect.get("amount", effect.get("radius", 0)))) if effect_type == "reveal_radius" else 0,
		"mana_cost": mana_cost,
		"public_text": public_text,
		"changes_fog": effect_type == "reveal_radius",
		"changes_site_state": false,
		"changes_resources": false,
	}

static func adventure_spell_behavior_report(spells: Array) -> Dictionary:
	var errors := []
	var records := []
	var effect_type_counts := {}
	var hook_counts := {}
	var target_policy_counts := {}
	for spell_value in spells:
		if not (spell_value is Dictionary):
			continue
		var spell: Dictionary = spell_value
		if String(spell.get("context", "")) != CONTEXT_OVERWORLD:
			continue
		var record := adventure_spell_behavior(spell)
		if record.is_empty():
			errors.append("Adventure spell %s did not produce behavior metadata." % String(spell.get("id", "")))
			continue
		records.append(record)
		_increment_count(effect_type_counts, String(record.get("effect_type", "")))
		_increment_count(target_policy_counts, String(record.get("target_policy", "")))
		for hook in record.get("runtime_hooks", []):
			_increment_count(hook_counts, String(hook))
		if String(record.get("resolution_type", "")) == "unsupported":
			errors.append("Adventure spell %s has unsupported behavior." % String(record.get("spell_id", "")))
		if String(record.get("target_mode", "")) != "self":
			errors.append("Adventure spell %s uses an unsupported target mode." % String(record.get("spell_id", "")))
	for required_hook in ["overworld_movement_restore", "mana_spend", "movement_clamp"]:
		if int(hook_counts.get(required_hook, 0)) <= 0:
			errors.append("Missing adventure spell runtime hook %s." % required_hook)
	if int(effect_type_counts.get("restore_movement", 0)) <= 0:
		errors.append("Missing adventure spell restore_movement behavior.")
	if int(target_policy_counts.get("self_hero_movement_gap", 0)) <= 0:
		errors.append("Missing self-hero movement-gap target policy.")
	if int(effect_type_counts.get("reveal_radius", 0)) <= 0:
		errors.append("Missing adventure spell reveal_radius behavior.")
	if int(target_policy_counts.get("self_hero_reveal_radius", 0)) <= 0:
		errors.append("Missing self-hero reveal-radius target policy.")
	for record in records:
		var encoded := JSON.stringify(record).to_lower()
		for leak_token in ["debug", "score", "internal"]:
			if encoded.contains(leak_token):
				errors.append("Adventure spell behavior record for %s leaks %s." % [String(record.get("spell_id", "")), leak_token])
	return {
		"ok": errors.is_empty(),
		"schema_status": "adventure_spell_behavior_hooks_loaded",
		"adventure_spell_count": records.size(),
		"effect_type_counts": effect_type_counts,
		"target_policy_counts": target_policy_counts,
		"runtime_hook_counts": hook_counts,
		"errors": errors,
		"records": records,
	}

static func magic_artifact_economy_integration_report(
	hero_state: Dictionary,
	movement_state: Dictionary,
	spells: Array
) -> Dictionary:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	var errors := []
	var records := []
	var artifact_income = ArtifactRulesScript.aggregate_bonuses(hero).get("daily_income", {})
	var common_income := _common_resource_delta(artifact_income)
	var rare_income := _rare_resource_delta(artifact_income)
	var active_resource_costs := []
	var matching_artifact_records := []
	for spell_value in spells:
		if not (spell_value is Dictionary):
			continue
		var spell: Dictionary = spell_value
		var spell_id := String(spell.get("id", ""))
		if spell_id == "":
			continue
		var base_mana_cost := int(spell.get("mana_cost", 0))
		var final_mana_cost := adjusted_spell_mana_cost(hero, spell)
		var preview := adventure_spell_consequence_preview(hero, movement_state, spell)
		var affinity_records := ArtifactRulesScript.spell_affinity_records(hero, spell)
		if not affinity_records.is_empty():
			matching_artifact_records.append_array(affinity_records)
		var resource_cost = spell.get("resource_cost", spell.get("resource_costs", {}))
		var public_resource_cost := _common_resource_delta(resource_cost)
		if not _rare_resource_delta(resource_cost).is_empty():
			errors.append("Spell %s activated rare-resource costs." % spell_id)
		if not public_resource_cost.is_empty():
			active_resource_costs.append(
				{
					"spell_id": spell_id,
					"resources": public_resource_cost,
				}
			)
		records.append(
			{
				"spell_id": spell_id,
				"spell_name": String(spell.get("name", spell_id)),
				"school_id": spell_school_id(spell),
				"context": String(spell.get("context", "")),
				"effect_type": String(spell.get("effect", {}).get("type", "")) if spell.get("effect", {}) is Dictionary else "",
				"base_mana_cost": base_mana_cost,
				"final_mana_cost": final_mana_cost,
				"artifact_mana_delta": final_mana_cost - HeroProgressionRulesScript.adjusted_mana_cost(hero, base_mana_cost),
				"movement_after": int(preview.get("movement_after", int(movement_state.get("current", 0)))),
				"movement_restored": int(preview.get("movement_restored", 0)),
				"artifact_spell_hooks": affinity_records,
				"resource_costs": public_resource_cost,
			}
		)
	if matching_artifact_records.is_empty():
		errors.append("No equipped artifact spell-affinity metadata matched the spell fixture.")
	for record in records:
		var encoded := JSON.stringify(record).to_lower()
		for leak_token in ["debug", "score", "internal"]:
			if encoded.contains(leak_token):
				errors.append("Magic artifact economy record for %s leaks %s." % [String(record.get("spell_id", "")), leak_token])
	return {
		"ok": errors.is_empty(),
		"schema_status": "magic_artifact_economy_bridge_loaded",
		"record_count": records.size(),
		"artifact_spell_hook_count": matching_artifact_records.size(),
		"common_artifact_income": common_income,
		"rare_artifact_income": rare_income,
		"active_spell_resource_costs": active_resource_costs,
		"resource_policy": {
			"live_cost_mode": "mana_only",
			"common_resources_reported": ["gold", "wood", "ore"],
			"rare_artifact_income_active": not rare_income.is_empty(),
			"rare_resource_costs_active": false,
		},
		"errors": errors,
		"records": records,
	}

static func describe_spell_inspection_line(hero_state: Dictionary, spell: Dictionary, context_state: Dictionary = {}) -> String:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return describe_spell_inspection_line__gd(hero_state, spell, context_state)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"SpellRules.describe_spell_inspection_line", [hero_state, spell, context_state])
	var before := HumanEngine.before_writing(&"SpellRules.describe_spell_inspection_line", [hero_state, spell, context_state])
	var result = describe_spell_inspection_line__gd(hero_state, spell, context_state)
	HumanEngine.check_writing(&"SpellRules.describe_spell_inspection_line", before, [hero_state, spell, context_state], result)
	return result

static func describe_spell_inspection_line__gd(hero_state: Dictionary, spell: Dictionary, context_state: Dictionary = {}) -> String:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	var mana_cost: int = adjusted_spell_mana_cost(hero, spell)
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
			_overworld_spell_effect_summary(spell, movement, hero),
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
		var mana_cost: int = adjusted_spell_mana_cost(hero, spell)
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
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return _mana_readiness_label__gd(hero_state, mana_cost)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"SpellRules._mana_readiness_label", [hero_state, mana_cost])
	var before := HumanEngine.before_writing(&"SpellRules._mana_readiness_label", [hero_state, mana_cost])
	var result = _mana_readiness_label__gd(hero_state, mana_cost)
	HumanEngine.check_writing(&"SpellRules._mana_readiness_label", before, [hero_state, mana_cost], result)
	return result

static func _mana_readiness_label__gd(hero_state: Dictionary, mana_cost: int) -> String:
	var current_mana := int(hero_state.get("spellbook", {}).get("mana", {}).get("current", 0))
	if current_mana >= max(0, mana_cost):
		return "Ready mana"
	return "Need %d mana" % max(0, mana_cost - current_mana)

static func _spell_effect_summary(spell: Dictionary, hero_state: Dictionary) -> String:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return _spell_effect_summary__gd(spell, hero_state)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"SpellRules._spell_effect_summary", [spell, hero_state])
	var before := HumanEngine.before_writing(&"SpellRules._spell_effect_summary", [spell, hero_state])
	var result = _spell_effect_summary__gd(spell, hero_state)
	HumanEngine.check_writing(&"SpellRules._spell_effect_summary", before, [spell, hero_state], result)
	return result

static func _spell_effect_summary__gd(spell: Dictionary, hero_state: Dictionary) -> String:
	match String(spell.get("context", "")):
		CONTEXT_OVERWORLD:
			return _overworld_spell_effect_summary(spell, {})
		CONTEXT_BATTLE:
			return _battle_spell_effect_summary(hero_state, spell, {}, {}, {})
		_:
			return "No supported effect"

static func _battle_spell_effect_summary(hero_state: Dictionary, spell: Dictionary, battle: Dictionary = {}, active_stack: Dictionary = {}, target_stack: Dictionary = {}) -> String:
	return BattleEngine.native_writing(&"SpellRules._battle_spell_effect_summary", [hero_state, spell, battle, active_stack, target_stack])

static func _best_use_line(spell: Dictionary, context: Dictionary = {}, active_stack: Dictionary = {}, target_stack: Dictionary = {}) -> String:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return _best_use_line__gd(spell, context, active_stack, target_stack)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"SpellRules._best_use_line", [spell, context, active_stack, target_stack])
	var before := HumanEngine.before_writing(&"SpellRules._best_use_line", [spell, context, active_stack, target_stack])
	var result = _best_use_line__gd(spell, context, active_stack, target_stack)
	HumanEngine.check_writing(&"SpellRules._best_use_line", before, [spell, context, active_stack, target_stack], result)
	return result

static func _best_use_line__gd(
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
		"reveal_radius":
			return "open nearby fog before committing movement or choosing a guarded route"
		"damage_enemy":
			var damage_timing := battle_spell_timing_summary({}, context, active_stack, target_stack, spell)
			return damage_timing.trim_prefix("Best ").trim_suffix(".") if damage_timing != "" else "soften the selected enemy before a trade"
		"control_enemy":
			return "pin the selected enemy before it can convert tempo"
		"recover_ally":
			return "stabilize a wounded active stack before the next exchange"
		"cleanse_ally":
			return "clear harry or stagger pressure before committing the stack"
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

## `today` > 0 applies the one-overworld-spell-per-day limit for that day.
static func get_overworld_actions(hero_state: Dictionary, movement_state: Dictionary, today: int = 0) -> Array:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return get_overworld_actions__gd(hero_state, movement_state, today)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"SpellRules.get_overworld_actions", [hero_state, movement_state, today])
	var before := HumanEngine.before_writing(&"SpellRules.get_overworld_actions", [hero_state, movement_state, today])
	var result = get_overworld_actions__gd(hero_state, movement_state, today)
	HumanEngine.check_writing(&"SpellRules.get_overworld_actions", before, [hero_state, movement_state, today], result)
	return result

static func get_overworld_actions__gd(hero_state: Dictionary, movement_state: Dictionary, today: int = 0) -> Array:
	var actions := []
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	for spell in known_spells(hero, CONTEXT_OVERWORLD):
		var validation := validate_overworld_spell(hero, movement_state, spell, today)
		var mana_cost: int = adjusted_spell_mana_cost(hero, spell)
		var summary := _overworld_spell_action_summary(hero, movement_state, spell, validation, mana_cost)
		var category := spell_category_label(spell)
		var effect_summary := _overworld_spell_effect_summary(spell, movement_state, hero)
		var target_contract := adventure_spell_target_contract(hero, movement_state, spell)
		var consequence_preview := adventure_spell_consequence_preview(hero, movement_state, spell)
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
				"target_contract": target_contract,
				"mana_state": "Mana %d/%d, need %d" % [
					mana_current,
					int(hero.get("spellbook", {}).get("mana", {}).get("max", mana_current)),
					mana_cost,
				],
				"mana_ready": mana_shortfall <= 0,
				"mana_shortfall": mana_shortfall,
				"consequence": effect_summary,
				"consequence_preview": consequence_preview,
				"why_cast": why_cast,
				"availability": "ready" if bool(validation.get("ok", false)) else "blocked",
				"invalid_reason": String(validation.get("message", "")) if not bool(validation.get("ok", false)) else "",
			}
		)
	return actions

static func cast_overworld_spell(hero_state: Dictionary, movement_state: Dictionary, spell_id: String, today: int = 0) -> Dictionary:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	var movement := movement_state.duplicate(true)
	if not _knows_spell(hero, spell_id):
		return {"ok": false, "hero": hero, "movement": movement, "message": "That spell is not in the spellbook."}
	var spell := ContentService.get_spell(spell_id)
	if spell.is_empty():
		return {"ok": false, "hero": hero, "movement": movement, "message": "That spell is not known."}
	var mana_cost: int = adjusted_spell_mana_cost(hero, spell)

	var validation := validate_overworld_spell(hero, movement, spell, today)
	if not bool(validation.get("ok", false)):
		return {"ok": false, "hero": hero, "movement": movement, "message": String(validation.get("message", "That spell cannot be cast now."))}
	if today > 0:
		hero[OVERWORLD_SPELL_CAST_DAY_KEY] = today

	var effect = spell.get("effect", {})
	match String(effect.get("type", "")):
		"restore_movement":
			var preview := adventure_spell_consequence_preview(hero, movement, spell)
			var target_contract := adventure_spell_target_contract(hero, movement, spell)
			var current := int(preview.get("movement_before", movement.get("current", 0)))
			var restored := int(preview.get("movement_restored", 0))
			movement["current"] = int(preview.get("movement_after", movement.get("current", 0)))
			hero = _consume_mana(hero, mana_cost)
			return {
				"ok": true,
				"hero": hero,
				"movement": movement,
				"spell_id": spell_id,
				"spell_name": String(spell.get("name", spell_id)),
				"target_contract": target_contract,
				"consequence_preview": preview,
				"message": "%s restores %d movement (%d -> %d) and spends %d mana." % [
					String(spell.get("name", spell_id)),
					restored,
					current,
					int(movement.get("current", 0)),
					mana_cost,
				],
			}
		"reveal_radius":
			var preview := adventure_spell_consequence_preview(hero, movement, spell)
			var target_contract := adventure_spell_target_contract(hero, movement, spell)
			hero = _consume_mana(hero, mana_cost)
			return {
				"ok": true,
				"hero": hero,
				"movement": movement,
				"spell_id": spell_id,
				"spell_name": String(spell.get("name", spell_id)),
				"fog_reveal_radius": int(preview.get("reveal_radius", 0)),
				"target_contract": target_contract,
				"consequence_preview": preview,
				"message": "%s reveals a scouting ring of radius %d and spends %d mana." % [
					String(spell.get("name", spell_id)),
					int(preview.get("reveal_radius", 0)),
					mana_cost,
				],
			}
		_:
			return {"ok": false, "hero": hero, "movement": movement, "message": "That overworld spell has no supported effect."}

static func get_battle_actions(hero_state: Dictionary, battle: Dictionary, active_stack: Dictionary, target_stack: Dictionary) -> Array:
	var actions := []
	for spell in known_spells(hero_state, CONTEXT_BATTLE):
		var validation := validate_battle_spell(hero_state, battle, active_stack, target_stack, spell)
		var mana_cost: int = adjusted_spell_mana_cost(hero_state, spell)
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

static func resolve_battle_spell(hero_state: Dictionary, battle: Dictionary, active_stack: Dictionary, target_stack: Dictionary, spell_id: String, acting_side: String = "player") -> Dictionary:
	return BattleEngine.native_writing(&"SpellRules.resolve_battle_spell", [hero_state, battle, active_stack, target_stack, spell_id, acting_side])

static func validate_overworld_spell(hero_state: Dictionary, movement_state: Dictionary, spell: Variant, today: int = 0) -> Dictionary:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return validate_overworld_spell__gd(hero_state, movement_state, spell, today)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"SpellRules.validate_overworld_spell", [hero_state, movement_state, spell, today])
	var before := HumanEngine.before_writing(&"SpellRules.validate_overworld_spell", [hero_state, movement_state, spell, today])
	var result = validate_overworld_spell__gd(hero_state, movement_state, spell, today)
	HumanEngine.check_writing(&"SpellRules.validate_overworld_spell", before, [hero_state, movement_state, spell, today], result)
	return result

static func validate_overworld_spell__gd(hero_state: Dictionary, movement_state: Dictionary, spell: Variant, today: int = 0) -> Dictionary:
	var hero := ensure_hero_spellbook(hero_state.duplicate(true))
	var spell_dict: Dictionary = spell if spell is Dictionary else ContentService.get_spell(String(spell))
	if spell_dict.is_empty():
		return {"ok": false, "message": "That spell is not known."}
	if String(spell_dict.get("context", "")) != CONTEXT_OVERWORLD:
		return {"ok": false, "message": "That spell cannot be used on the overworld."}
	if cast_overworld_spell_on_day(hero, today):
		return {"ok": false, "message": "%s has already cast an overworld spell today." % String(hero.get("name", "This hero"))}
	var mana_cost: int = adjusted_spell_mana_cost(hero, spell_dict)
	if not _has_mana(hero, mana_cost):
		var current_mana := int(hero.get("spellbook", {}).get("mana", {}).get("current", 0))
		return {"ok": false, "message": "Need %d mana; only %d available." % [mana_cost, current_mana]}

	var effect = spell_dict.get("effect", {})
	match String(effect.get("type", "")):
		"restore_movement":
			if String(spell_dict.get("target_mode", "self")) != "self":
				return {"ok": false, "message": "That field spell target is not supported yet."}
			if int(movement_state.get("current", 0)) >= int(movement_state.get("max", 0)):
				return {"ok": false, "message": "Movement is already full."}
			return {"ok": true}
		"reveal_radius":
			if String(spell_dict.get("target_mode", "self")) != "self":
				return {"ok": false, "message": "That field spell target is not supported yet."}
			if max(0, int(effect.get("amount", effect.get("radius", 0)))) <= 0:
				return {"ok": false, "message": "That scouting spell has no reveal radius."}
			return {"ok": true}
		_:
			return {"ok": false, "message": "That overworld spell effect is unsupported."}

static func validate_battle_spell(hero_state: Dictionary, battle: Dictionary, active_stack: Dictionary, target_stack: Dictionary, spell: Variant, acting_side: String = "player") -> Dictionary:
	return BattleEngine.native_writing(&"SpellRules.validate_battle_spell", [hero_state, battle, active_stack, target_stack, spell, acting_side])

static func effect_bonus_for_kind(stack: Dictionary, battle: Dictionary, kind: String) -> int:
	return BattleEngine.native(&"SpellRules.effect_bonus_for_kind", [stack, battle, kind])

static func has_effect_id(stack: Dictionary, battle: Dictionary, effect_id: String) -> bool:
	return BattleEngine.native(&"SpellRules.has_effect_id", [stack, battle, effect_id])

static func has_any_effect_ids(stack: Dictionary, battle: Dictionary, effect_ids: Variant) -> bool:
	return BattleEngine.native(&"SpellRules.has_any_effect_ids", [stack, battle, effect_ids])

static func normalize_status_immunity_ids(value: Variant) -> Array:
	return BattleEngine.native(&"SpellRules.normalize_status_immunity_ids", [value])

static func normalize_school_resistance(value: Variant) -> Dictionary:
	return BattleEngine.native(&"SpellRules.normalize_school_resistance", [value])

static func target_is_immune_to_status(target_stack: Dictionary, battle: Dictionary, status_id: String) -> bool:
	return BattleEngine.native(&"SpellRules.target_is_immune_to_status", [target_stack, battle, status_id])

static func spell_damage_resistance_pct(battle: Dictionary, target_stack: Dictionary, spell: Dictionary) -> int:
	return BattleEngine.native(&"SpellRules.spell_damage_resistance_pct", [battle, target_stack, spell])

static func control_resistance_pct(battle: Dictionary, target_stack: Dictionary, spell: Dictionary) -> int:
	return BattleEngine.native(&"SpellRules.control_resistance_pct", [battle, target_stack, spell])

static func battle_spell_damage_projection(hero_state: Dictionary, battle: Dictionary, target_stack: Dictionary, spell: Dictionary) -> Dictionary:
	return BattleEngine.native_writing(&"SpellRules.battle_spell_damage_projection", [hero_state, battle, target_stack, spell])

static func active_effects_for_round(stack: Dictionary, round_number: int) -> Array:
	return BattleEngine.native(&"SpellRules.active_effects_for_round", [stack, round_number])

static func effect_summary(stack: Dictionary, battle: Dictionary) -> String:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return effect_summary__gd(stack, battle)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"SpellRules.effect_summary", [stack, battle])
	var before := HumanEngine.before_writing(&"SpellRules.effect_summary", [stack, battle])
	var result = effect_summary__gd(stack, battle)
	HumanEngine.check_writing(&"SpellRules.effect_summary", before, [stack, battle], result)
	return result

static func effect_summary__gd(stack: Dictionary, battle: Dictionary) -> String:
	var tags := []
	var current_round := int(battle.get("round", 1))
	for effect in active_effects_for_round(stack, current_round):
		var label := String(effect.get("label", effect.get("kind", "Effect")))
		var rules := status_rules_text(String(effect.get("effect_id", "")))
		if rules != "":
			label += " (%s)" % rules
		if effect.has("turns_left"):
			var turns := int(effect.get("turns_left", 1))
			tags.append("%s, %d turn%s" % [label, turns, "" if turns == 1 else "s"])
		else:
			var rounds_left := int(effect.get("expires_after_round", current_round)) - current_round + 1
			tags.append("%s %dr" % [label, max(1, rounds_left)])
	return ", ".join(tags)

static func build_battle_effect(effect_id: String, label: String, modifiers: Variant, duration_rounds: int, battle: Dictionary, source_type: String = "status", source_id: String = "", status_immunity_ids: Variant = []) -> Dictionary:
	return BattleEngine.native(&"SpellRules.build_battle_effect", [effect_id, label, modifiers, duration_rounds, battle, source_type, source_id, status_immunity_ids])

## A battle spell effect's rounds: its own, the power bonus, and the caster's
## specialties (Lingering Weave for buffs or debuffs, the spell's school
## mastery). `kind` is "buff" for effects on allies, "debuff" for control
## effects and damage riders.
static func spell_duration_rounds(hero_state: Dictionary, base_rounds: Variant, spell: Dictionary = {}, kind: String = "buff") -> int:
	return BattleEngine.native_writing(&"SpellRules.spell_duration_rounds", [hero_state, base_rounds, spell, kind])

## The caster's spell power: command power plus specialty spell power.
static func spell_power(hero_state: Dictionary) -> int:
	return BattleEngine.native_writing(&"SpellRules.spell_power", [hero_state])

## A status's rules beyond its numbers, for summaries and tooltips.
static func status_rules_text(status_id: String) -> String:
	return BattleEngine.native(&"SpellRules.status_rules_text", [status_id])

static func _turns_label(turns: int) -> String:
	return BattleEngine.native(&"SpellRules._turns_label", [turns])

static func battle_spell_modifiers(spell: Dictionary) -> Dictionary:
	return BattleEngine.native(&"SpellRules.battle_spell_modifiers", [spell])

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
			var damage_projection := battle_spell_damage_projection(hero_state, battle, target_stack, spell)
			var summary := "Projected %d damage to %s." % [
				int(damage_projection.get("final_damage", 0)),
				String(target_stack.get("name", "the selected enemy")),
			]
			if int(damage_projection.get("resistance_pct", 0)) > 0:
				summary += " Resistance reduces raw %d by %d%%." % [
					int(damage_projection.get("raw_damage", 0)),
					int(damage_projection.get("resistance_pct", 0)),
				]
			var status_effect: Dictionary = effect.get("status_effect", {})
			if status_effect is Dictionary and not status_effect.is_empty():
				var status_payload := _status_effect_from_spell_effect(spell, battle, hero_state)
				var control_pct := control_resistance_pct(battle, target_stack, spell)
				summary += " Leaves it %s (%s) for %s." % [
					String(status_effect.get("label", "a battle effect")),
					_status_terms(status_effect),
					_turns_label(spell_duration_rounds(hero_state, status_effect.get("duration_rounds", 1), spell, "debuff")),
				]
				if target_is_immune_to_status(target_stack, battle, String(status_payload.get("effect_id", ""))):
					summary += " Target is immune to that rider."
				elif control_pct > 0:
					summary += " Rider success chance %d%%." % max(0, 100 - control_pct)
			if timing_hint != "":
				summary += " Timing: %s" % timing_hint
			return summary
		"control_enemy":
			var control_effect: Dictionary = effect.get("status_effect", {})
			var summary := "Leave %s %s (%s) for %s." % [
				String(target_stack.get("name", "the selected enemy")),
				String(control_effect.get("label", "control")),
				_status_terms(control_effect),
				_turns_label(spell_duration_rounds(hero_state, control_effect.get("duration_rounds", 1), spell, "debuff")),
			]
			var control_payload := _status_effect_from_spell_effect(spell, battle, hero_state)
			var control_pct := control_resistance_pct(battle, target_stack, spell)
			if target_is_immune_to_status(target_stack, battle, String(control_payload.get("effect_id", ""))):
				summary += " Target is immune."
			elif control_pct > 0:
				summary += " Success chance %d%%." % max(0, 100 - control_pct)
			if timing_hint != "":
				summary += " Timing: %s" % timing_hint
			return summary
		"recover_ally":
			var recovery_summary := "Restore up to %d health to surviving creatures in %s; fallen creatures are not restored." % [
				_battle_spell_recovery_amount(hero_state, spell),
				String(active_stack.get("name", "the active stack")),
			]
			var recovery_modifiers := battle_spell_modifiers(spell)
			if not recovery_modifiers.is_empty():
				recovery_summary += " Grant %s for %s." % [
					_modifier_summary(recovery_modifiers),
					_turns_label(spell_duration_rounds(hero_state, effect.get("duration_rounds", 1), spell, "buff")),
				]
			if timing_hint != "":
				recovery_summary += " Timing: %s" % timing_hint
			return recovery_summary
		"cleanse_ally":
			var cleanse_summary := "Cleanse %s from %s." % [
				", ".join(_cleanse_labels(effect)),
				String(active_stack.get("name", "the active stack")),
			]
			var cleanse_modifiers := battle_spell_modifiers(spell)
			if not cleanse_modifiers.is_empty():
				cleanse_summary += " Grant %s for %s." % [
					_modifier_summary(cleanse_modifiers),
					_turns_label(spell_duration_rounds(hero_state, effect.get("duration_rounds", 1), spell, "buff")),
				]
			if timing_hint != "":
				cleanse_summary += " Timing: %s" % timing_hint
			return cleanse_summary
		"defense_buff":
			var summary := "Grant %s to %s for %s." % [
				_modifier_summary(battle_spell_modifiers(spell)),
				String(active_stack.get("name", "the active stack")),
				_turns_label(spell_duration_rounds(hero_state, effect.get("duration_rounds", 1), spell, "buff")),
			]
			if timing_hint != "":
				summary += " Timing: %s" % timing_hint
			return summary
		"initiative_buff", "attack_buff":
			var summary := "Grant %s to %s for %s." % [
				_modifier_summary(battle_spell_modifiers(spell)),
				String(active_stack.get("name", "the active stack")),
				_turns_label(spell_duration_rounds(hero_state, effect.get("duration_rounds", 1), spell, "buff")),
			]
			if timing_hint != "":
				summary += " Timing: %s" % timing_hint
			return summary
		_:
			return "No authored battle summary is available for this spell."

static func battle_spell_timing_summary(hero_state: Dictionary, battle: Dictionary, active_stack: Dictionary, target_stack: Dictionary, spell: Dictionary) -> String:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return battle_spell_timing_summary__gd(hero_state, battle, active_stack, target_stack, spell)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"SpellRules.battle_spell_timing_summary", [hero_state, battle, active_stack, target_stack, spell])
	var before := HumanEngine.before_writing(&"SpellRules.battle_spell_timing_summary", [hero_state, battle, active_stack, target_stack, spell])
	var result = battle_spell_timing_summary__gd(hero_state, battle, active_stack, target_stack, spell)
	HumanEngine.check_writing(&"SpellRules.battle_spell_timing_summary", before, [hero_state, battle, active_stack, target_stack, spell], result)
	return result

static func battle_spell_timing_summary__gd(
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
		"control_enemy":
			if not target_stack.is_empty() and _health_ratio(target_stack) > 0.5:
				return "Best before a healthy threat converts its next action."
			return "Best to pin the selected enemy before a follow-up trade."
		"recover_ally":
			if _health_ratio(active_stack) <= 0.65:
				return "Best when the acting stack is wounded enough to lose bodies next exchange."
			return "Best when the stack must hold while keeping its current bodies alive."
		"cleanse_ally":
			if has_any_effect_ids(active_stack, battle, _normalize_string_array(effect.get("cleanse_effect_ids", []))):
				return "Best before the cleansed stack spends its next attack or defense window."
			return "Best when harry or stagger pressure would waste the active stack's order."
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
	hero_state: Dictionary,
	movement_state: Dictionary,
	spell: Dictionary,
	validation: Dictionary,
	mana_cost: int
) -> String:
	var target_label := _target_mode_label(String(spell.get("target_mode", "self")))
	var availability := "Ready now." if bool(validation.get("ok", false)) else "Blocked: %s" % String(validation.get("message", "cannot cast now"))
	var description := String(spell.get("description", "")).strip_edges()
	var consequence := _overworld_spell_effect_summary(spell, movement_state, hero_state)
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
		_overworld_spell_effect_summary(spell, movement_state, hero),
		_best_use_line(spell, movement_state),
	]

static func _movement_restore_preview(movement_state: Dictionary, spell: Dictionary, hero_state: Dictionary = {}) -> Dictionary:
	var effect = spell.get("effect", {})
	if not (effect is Dictionary) or String(effect.get("type", "")) != "restore_movement":
		return {
			"movement_before": int(movement_state.get("current", 0)),
			"movement_after": int(movement_state.get("current", 0)),
			"movement_max": int(movement_state.get("max", 0)),
			"restored": 0,
		}
	var amount: int = max(1, int(effect.get("amount", 0)) + ArtifactRulesScript.spell_effect_amount_delta(hero_state, spell))
	var current := int(movement_state.get("current", 0))
	var max_movement := int(movement_state.get("max", 0))
	var restored: int = min(amount, max(0, max_movement - current))
	return {
		"movement_before": current,
		"movement_after": min(max_movement, current + restored),
		"movement_max": max_movement,
		"restored": restored,
	}

static func _overworld_spell_effect_summary(spell: Dictionary, movement_state: Dictionary, hero_state: Dictionary = {}) -> String:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return _overworld_spell_effect_summary__gd(spell, movement_state, hero_state)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"SpellRules._overworld_spell_effect_summary", [spell, movement_state, hero_state])
	var before := HumanEngine.before_writing(&"SpellRules._overworld_spell_effect_summary", [spell, movement_state, hero_state])
	var result = _overworld_spell_effect_summary__gd(spell, movement_state, hero_state)
	HumanEngine.check_writing(&"SpellRules._overworld_spell_effect_summary", before, [spell, movement_state, hero_state], result)
	return result

static func _overworld_spell_effect_summary__gd(spell: Dictionary, movement_state: Dictionary, hero_state: Dictionary = {}) -> String:
	var effect = spell.get("effect", {})
	match String(effect.get("type", "")):
		"restore_movement":
			var preview := _movement_restore_preview(movement_state, spell, hero_state)
			var amount: int = max(1, int(effect.get("amount", 0)) + ArtifactRulesScript.spell_effect_amount_delta(hero_state, spell))
			if int(preview.get("restored", 0)) > 0:
				return "Restores up to %d movement; %d can fit now" % [amount, int(preview.get("restored", 0))]
			return "Restores up to %d movement" % amount
		"reveal_radius":
			return "Reveals unexplored tiles in radius %d around the active hero" % max(1, int(effect.get("amount", effect.get("radius", 0))))
		_:
			return "No supported overworld effect"

static func _overworld_target_requirement(spell: Dictionary) -> String:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return _overworld_target_requirement__gd(spell)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"SpellRules._overworld_target_requirement", [spell])
	var before := HumanEngine.before_writing(&"SpellRules._overworld_target_requirement", [spell])
	var result = _overworld_target_requirement__gd(spell)
	HumanEngine.check_writing(&"SpellRules._overworld_target_requirement", before, [spell], result)
	return result

static func _overworld_target_requirement__gd(spell: Dictionary) -> String:
	match String(spell.get("target_mode", "self")):
		"self":
			return "No map target; affects active hero"
		_:
			return "Choose %s before casting" % _target_mode_label(String(spell.get("target_mode", "")))

static func _target_mode_label(target_mode: String) -> String:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return _target_mode_label__gd(target_mode)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native(&"SpellRules._target_mode_label", [target_mode])
	var result = _target_mode_label__gd(target_mode)
	HumanEngine.check(&"SpellRules._target_mode_label", [target_mode], result)
	return result

static func _target_mode_label__gd(target_mode: String) -> String:
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
	elif String(effect_type) == "reveal_radius":
		if context != CONTEXT_OVERWORLD:
			errors.append("Spell %s reveal_radius metadata must use overworld context." % spell_id)
		if primary_role != "scouting_support":
			errors.append("Spell %s reveal_radius metadata must use scouting_support primary_role." % spell_id)
		if "economy_map_utility" not in role_categories:
			errors.append("Spell %s reveal_radius metadata must include economy_map_utility." % spell_id)
	elif String(effect_type) == "damage_enemy":
		if context != CONTEXT_BATTLE:
			errors.append("Spell %s damage metadata must use battle context." % spell_id)
		if "damage" not in role_categories:
			errors.append("Spell %s damage metadata must include damage role category." % spell_id)
	elif String(effect_type) == "control_enemy":
		if context != CONTEXT_BATTLE:
			errors.append("Spell %s control metadata must use battle context." % spell_id)
		if "control" not in role_categories:
			errors.append("Spell %s control metadata must include control role category." % spell_id)
	elif String(effect_type) == "recover_ally":
		if context != CONTEXT_BATTLE:
			errors.append("Spell %s recovery metadata must use battle context." % spell_id)
		if "recovery" not in role_categories:
			errors.append("Spell %s recovery metadata must include recovery role category." % spell_id)
	elif String(effect_type) == "cleanse_ally":
		if context != CONTEXT_BATTLE:
			errors.append("Spell %s cleanse metadata must use battle context." % spell_id)
		if "countermagic" not in role_categories:
			errors.append("Spell %s cleanse metadata must include countermagic role category." % spell_id)
	elif String(effect_type) in ["defense_buff", "initiative_buff", "attack_buff"]:
		if context != CONTEXT_BATTLE:
			errors.append("Spell %s buff metadata must use battle context." % spell_id)
		if "buff" not in role_categories and "recovery" not in role_categories:
			errors.append("Spell %s buff metadata must include buff or recovery role category." % spell_id)

static func _increment_count(counts: Dictionary, key: String) -> void:
	var normalized_key := key if key != "" else "missing"
	counts[normalized_key] = int(counts.get(normalized_key, 0)) + 1

static func _normalize_string_array(value: Variant) -> Array:
	return BattleEngine.native(&"SpellRules._normalize_string_array", [value])

static func _common_resource_delta(value: Variant) -> Dictionary:
	return _filtered_resource_delta(value, COMMON_RESOURCE_IDS)

static func _rare_resource_delta(value: Variant) -> Dictionary:
	return _filtered_resource_delta(value, RARE_RESOURCE_IDS)

static func _filtered_resource_delta(value: Variant, allowed_ids: Array) -> Dictionary:
	var result := {}
	if not (value is Dictionary):
		return result
	for key in value.keys():
		var resource_id := String(key)
		var amount := int(value[key])
		if amount <= 0 or resource_id not in allowed_ids:
			continue
		result[resource_id] = amount
	return result

static func _normalize_spell_ids(value: Variant) -> Array:
	var ids := []
	if value is Array:
		for spell_id_value in value:
			var spell_id := String(spell_id_value)
			if spell_id != "":
				ids.append(spell_id)
	return ids

static func _status_effect_from_spell_effect(spell: Dictionary, battle: Dictionary, hero_state: Dictionary = {}) -> Dictionary:
	return BattleEngine.native_writing(&"SpellRules._status_effect_from_spell_effect", [spell, battle, hero_state])

static func _battle_spell_recovery_amount(hero_state: Dictionary, spell: Dictionary) -> int:
	return BattleEngine.native_writing(&"SpellRules._battle_spell_recovery_amount", [hero_state, spell])

static func _cleanse_labels(effect: Dictionary) -> Array:
	return BattleEngine.native(&"SpellRules._cleanse_labels", [effect])

## A status's numbers and rules: "-1 defense, cannot move".
static func _status_terms(status_effect: Dictionary) -> String:
	return BattleEngine.native(&"SpellRules._status_terms", [status_effect])

static func _modifier_summary(modifiers: Dictionary) -> String:
	return BattleEngine.native(&"SpellRules._modifier_summary", [modifiers])

static func _has_mana(hero_state: Dictionary, cost: int) -> bool:
	return BattleEngine.native(&"SpellRules._has_mana", [hero_state, cost])

static func _consume_mana(hero_state: Dictionary, cost: int) -> Dictionary:
	return BattleEngine.native_writing(&"SpellRules._consume_mana", [hero_state, cost])

static func _knows_spell(hero_state: Dictionary, spell_id: String) -> bool:
	return BattleEngine.native(&"SpellRules._knows_spell", [hero_state, spell_id])

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
		if _alive_count(stack) <= 0:
			continue
		stacks.append(stack)
	return stacks

## Living creatures in a battle stack, as BattleRules._alive_count: battle
## stacks keep base_count, unit_hp and total_health, not an army "count".
static func _alive_count(stack: Dictionary) -> int:
	return BattleEngine.native(&"SpellRules._alive_count", [stack])

static func _side_has_any_ability(battle: Dictionary, side: String, ability_ids: Array) -> bool:
	for stack in _alive_stacks_for_side(battle, side):
		for ability_id_value in ability_ids:
			if _has_ability(stack, String(ability_id_value)):
				return true
	return false

static func _health_ratio(stack: Dictionary) -> float:
	return BattleEngine.native(&"SpellRules._health_ratio", [stack])
