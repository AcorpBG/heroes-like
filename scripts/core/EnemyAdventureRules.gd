class_name EnemyAdventureRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const DifficultyRulesScript = preload("res://scripts/core/DifficultyRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
static var OverworldRulesScript: Variant = load("res://scripts/core/OverworldRules.gd")

const COMMANDER_STATUS_AVAILABLE := "available"
const COMMANDER_STATUS_ACTIVE := "active"
const COMMANDER_STATUS_RECOVERING := "recovering"
const COMMANDER_OUTCOME_DEFEATED := "defeated"
const COMMANDER_OUTCOME_ASSAULT_VICTORY := "assault_victory"
const COMMANDER_OUTCOME_DEPLOYED := "deployed"
const COMMANDER_OUTCOME_FIELD_VICTORY := "field_victory"
const COMMANDER_OUTCOME_PURSUIT_VICTORY := "pursuit_victory"
const COMMANDER_OUTCOME_CAPITULATION := "capitulation"
const COMMANDER_OUTCOME_ROUT_VICTORY := "rout_victory"
const COMMANDER_OUTCOME_STALEMATE := "stalemate"
const COMMANDER_OUTCOME_RESOURCE_SECURED := "resource_secured"
const COMMANDER_OUTCOME_ARTIFACT_SECURED := "artifact_secured"
const COMMANDER_OUTCOME_OBJECTIVE_SECURED := "objective_secured"
const COMMANDER_OUTCOME_TOWN_CAPTURED := "town_captured"
const COMMANDER_OUTCOME_SITE_DEFENDED := "site_defended"
const COMMANDER_OUTCOME_TOWN_DEFENDED := "town_defended"
const COMMANDER_RECOVERY_DAYS_DEFEATED := 3
const COMMANDER_RECOVERY_DAYS_ASSAULT_VICTORY := 1
const COMMANDER_EXPERIENCE_DEPLOYED := 90
const COMMANDER_EXPERIENCE_FIELD_VICTORY := 180
const COMMANDER_EXPERIENCE_PURSUIT_VICTORY := 205
const COMMANDER_EXPERIENCE_CAPITULATION := 150
const COMMANDER_EXPERIENCE_ROUT_VICTORY := 230
const COMMANDER_EXPERIENCE_ASSAULT_VICTORY := 210
const COMMANDER_EXPERIENCE_DEFEATED := 45
const COMMANDER_EXPERIENCE_STALEMATE := 30
const COMMANDER_EXPERIENCE_RESOURCE_SECURED := 70
const COMMANDER_EXPERIENCE_ARTIFACT_SECURED := 100
const COMMANDER_EXPERIENCE_OBJECTIVE_SECURED := 90
const COMMANDER_EXPERIENCE_SITE_DEFENDED := 45
const COMMANDER_EXPERIENCE_TOWN_DEFENDED := 65
const RAID_RISK_SUPPORT_STALL_DAYS := 3
const COMMANDER_VETERANCY_LABELS := ["", "Blooded", "Veteran", "War-hardened"]
const RAID_BASE_MOVEMENT_STEPS := 1
const RAID_ADVENTURE_SPELL_MAX_MOVEMENT_STEPS := 6
const RAID_ADVENTURE_SCOUTING_MEMORY_DAYS := 7
const RAID_ADVENTURE_SCOUTING_MAX_TARGET_RECORDS := 24
const RAID_ADVENTURE_SCOUTED_TARGET_PRIORITY_BONUS := 48
const LOGISTICS_SITE_FAMILIES := ["neutral_dwelling", "faction_outpost", "frontier_shrine"]
const COMMANDER_ROLE_RAIDER := "raider"
const COMMANDER_ROLE_DEFENDER := "defender"
const COMMANDER_ROLE_RETAKER := "retaker"
const COMMANDER_ROLE_STABILIZER := "stabilizer"
const COMMANDER_ROLE_RECOVERING := "recovering"
const COMMANDER_ROLE_RESERVE := "reserve"
const COMMANDER_ROLE_PUBLIC_EVENT_KEYS := [
	"event_id",
	"day",
	"sequence",
	"event_type",
	"faction_id",
	"faction_label",
	"actor_id",
	"actor_label",
	"target_kind",
	"target_id",
	"target_label",
	"target_x",
	"target_y",
	"from_x",
	"from_y",
	"to_x",
	"to_y",
	"phase_id",
	"visibility",
	"public_importance",
	"summary",
	"reason_codes",
	"public_reason",
	"debug_reason",
	"state_policy",
]
const AI_PUBLIC_EVENT_LOG_KEYS := [
	"day",
	"event_type",
	"faction_id",
	"faction_label",
	"actor_label",
	"target_kind",
	"target_id",
	"target_label",
	"visibility",
	"public_importance",
	"summary",
	"reason_codes",
	"public_reason",
]
const AI_PUBLIC_EVENT_LOG_TYPES := [
	"ai_target_assigned",
	"ai_pressure_summary",
	"ai_site_seized",
	"ai_site_contested",
	"ai_site_defended",
	"ai_town_captured",
	"ai_town_defended",
	"ai_town_built",
	"ai_town_recruited",
	"ai_garrison_reinforced",
	"ai_raid_reinforced",
	"ai_commander_rebuilt",
	"ai_commander_prepared",
	"ai_commander_role_observed",
	"ai_raid_moved",
	"ai_raid_arrived",
	"ai_raid_regrouped",
	"ai_raid_grouped",
	"ai_adventure_spell_cast",
	"ai_artifact_secured",
]
const COMMANDER_ROLE_BLOCKED_PUBLIC_TOKENS := [
	"base_value",
	"persistent_income_value",
	"recruit_value",
	"scarcity_value",
	"denial_value",
	"route_pressure_value",
	"town_enablement_value",
	"resource_affinity_value",
	"weighted_claim_value",
	"weighted_income_value",
	"objective_value",
	"faction_bias",
	"travel_cost",
	"guard_cost",
	"assignment_penalty",
	"object_metadata_value",
	"object_route_pressure_value",
	"priority_without_object_metadata",
	"priority_with_object_metadata",
	"final_priority",
	"final_score",
	"income_value",
	"growth_value",
	"pressure_value",
	"category_bonus",
	"garrison_score",
	"raid_score",
	"rebuild_score",
	"resource_score_breakdown",
	"target_memory",
	"commander_role_state",
	"fixture_state",
	"saved",
	"durable",
	"migration",
	"SAVE_VERSION",
	"focus_pressure_count",
	"rivalry_count",
	"fixture_previous_controller",
	"fixture_denial_only",
	"fixture_primary_target_covered",
	"fixture_threatened_by_player_front",
	"fixture_recently_secured",
	"fixture_recent_pressure_count",
]
const AI_PUBLIC_EVENT_LOG_BLOCKED_TOKENS := [
	"event_id",
	"sequence",
	"target_x",
	"target_y",
	"from_x",
	"from_y",
	"to_x",
	"to_y",
	"phase_id",
	"state_policy",
	"debug_reason",
	"target_debug_reason",
	"score_ref",
	"score",
	"base_value",
	"persistent_income_value",
	"recruit_value",
	"scarcity_value",
	"denial_value",
	"route_pressure_value",
	"town_enablement_value",
	"resource_affinity_value",
	"weighted_claim_value",
	"weighted_income_value",
	"objective_value",
	"faction_bias",
	"travel_cost",
	"guard_cost",
	"assignment_penalty",
	"object_metadata_value",
	"object_route_pressure_value",
	"priority_without_object_metadata",
	"priority_with_object_metadata",
	"final_priority",
	"final_score",
	"income_value",
	"growth_value",
	"pressure_value",
	"category_bonus",
	"garrison_score",
	"raid_score",
	"resource_score_breakdown",
	"resource_breakdown",
	"priority_table",
	"breakdown",
	"target_memory",
	"commander_role_state",
	"hero_task_state",
	"fixture_state",
	"internal",
	"saved",
	"durable",
	"migration",
	"SAVE_VERSION",
]
const COMMANDER_ROLE_TURN_NO_OP_REASONS := [
	"target_unchanged",
	"no_active_commander",
	"commander_recovering",
	"commander_rebuilding",
	"no_valid_target",
	"town_front_dominates_selector",
	"pressure_below_launch_threshold",
	"max_active_raids_reached",
	"no_open_spawn_point",
	"no_available_commander",
	"town_governor_only_turn",
	"battle_queued_before_spawn",
	"no_existing_raid_to_move",
	"report_fixture_not_configured_for_assignment",
]
const COMMANDER_ROLE_ADOPTION_PUBLIC_EVENT_KEYS := [
	"event_id",
	"day",
	"sequence",
	"event_type",
	"faction_id",
	"faction_label",
	"actor_id",
	"actor_label",
	"target_kind",
	"target_id",
	"target_label",
	"visibility",
	"public_importance",
	"summary",
	"reason_codes",
	"public_reason",
	"state_policy",
]
const COMMANDER_ROLE_ADOPTION_BLOCKED_PUBLIC_TOKENS := [
	"commander_role_state",
	"hero_task_state",
	"SAVE_VERSION",
	"schema",
	"migration",
	"durable",
	"saved",
	"save",
	"live_behavior",
	"score",
	"breakdown",
	"debug",
	"fixture_",
	"target_memory",
	"focus_pressure_count",
	"rivalry_count",
	"task_id",
	"source_id",
	"route_policy",
	"body_tiles",
	"approach",
]
const ARTIFACT_AI_VALUATION_SCHEMA := "artifact_ai_valuation_v1"
const ARTIFACT_AI_BLOCKED_PUBLIC_TOKENS := [
	"base_value",
	"taxonomy_value",
	"runtime_value",
	"source_value",
	"affinity_value",
	"set_context_value",
	"objective_value",
	"faction_bias",
	"travel_cost",
	"assignment_penalty",
	"final_priority",
	"priority",
	"debug",
	"internal",
	"score",
	"breakdown",
]

static func adventure_spell_valuation_report(
	hero_state: Dictionary,
	movement_state: Dictionary,
	strategic_context: Dictionary = {}
) -> Dictionary:
	var hero := SpellRulesScript.ensure_hero_spellbook(hero_state.duplicate(true))
	var movement := movement_state.duplicate(true)
	var candidates := []
	var effect_type_counts := {}
	var hook_counts := {}
	for spell in SpellRulesScript.known_spells(hero, SpellRulesScript.CONTEXT_OVERWORLD):
		if not (spell is Dictionary):
			continue
		var behavior := SpellRulesScript.adventure_spell_behavior(spell)
		if behavior.is_empty() or String(behavior.get("resolution_type", "")) == "unsupported":
			continue
		var validation := SpellRulesScript.validate_overworld_spell(hero, movement, spell)
		var consequence := SpellRulesScript.adventure_spell_consequence_preview(hero, movement, spell)
		var value := _adventure_spell_value(hero, movement, strategic_context, spell, behavior, validation, consequence)
		var public_candidate := _public_adventure_spell_candidate(spell, behavior, validation, consequence, strategic_context, value)
		candidates.append(public_candidate)
		_increment_count(effect_type_counts, String(public_candidate.get("effect_type", "")))
		for hook in public_candidate.get("runtime_hooks", []):
			_increment_count(hook_counts, String(hook))

	var selected := {}
	for candidate in candidates:
		if not (candidate is Dictionary):
			continue
		if String(candidate.get("recommendation", "")) != "cast":
			continue
		if selected.is_empty() or _adventure_band_rank(String(candidate.get("value_band", ""))) > _adventure_band_rank(String(selected.get("value_band", ""))):
			selected = candidate

	return {
		"ok": true,
		"report_status": "enemy_adventure_spell_behavior_metadata_valued",
		"actor_id": String(hero.get("id", hero.get("hero_id", ""))),
		"candidate_count": candidates.size(),
		"selected": selected,
		"effect_type_counts": effect_type_counts,
		"runtime_hook_counts": hook_counts,
		"candidates": candidates,
		"runtime_policy": "valuation_with_enemy_movement_and_scouting_spell_executors",
	}

static func artifact_reward_valuation_report(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	origin: Dictionary,
	faction_id: String = "",
	limit: int = 0
) -> Dictionary:
	var resolved_faction_id := faction_id
	if resolved_faction_id == "":
		resolved_faction_id = String(config.get("faction_id", ""))
	var origin_pos := Vector2i(int(origin.get("x", 0)), int(origin.get("y", 0)))
	var targets := []
	var role_bucket_counts := {}
	var runtime_surface_counts := {}
	var source_context_counts := {}
	var strategic_band_counts := {}
	var faction_fit_count := 0
	var set_piece_count := 0
	for node_value in session.overworld.get("artifact_nodes", []):
		if not (node_value is Dictionary):
			continue
		var breakdown := artifact_target_valuation_breakdown(
			session,
			config,
			node_value,
			origin_pos,
			resolved_faction_id
		)
		if breakdown.is_empty() or int(breakdown.get("final_priority", 0)) <= 0:
			continue
		targets.append(breakdown)
		for role_bucket in _normalize_string_array(breakdown.get("role_buckets", [])):
			_increment_count(role_bucket_counts, role_bucket)
		for surface in _normalize_string_array(breakdown.get("runtime_surfaces", [])):
			_increment_count(runtime_surface_counts, surface)
		for source_context in _normalize_string_array(breakdown.get("source_context_tags", [])):
			_increment_count(source_context_counts, source_context)
		_increment_count(strategic_band_counts, String(breakdown.get("strategic_band", "")))
		if bool(breakdown.get("faction_affinity_match", false)):
			faction_fit_count += 1
		if String(breakdown.get("set_id", "")) != "":
			set_piece_count += 1
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("final_priority", 0)) == int(b.get("final_priority", 0)):
			if int(a.get("travel_cost", 0)) == int(b.get("travel_cost", 0)):
				return String(a.get("placement_id", "")) < String(b.get("placement_id", ""))
			return int(a.get("travel_cost", 0)) < int(b.get("travel_cost", 0))
		return int(a.get("final_priority", 0)) > int(b.get("final_priority", 0))
	)
	if limit > 0 and targets.size() > limit:
		targets = targets.slice(0, limit)
	var public_targets := []
	for target in targets:
		public_targets.append(_public_artifact_target_payload(target))
	return {
		"ok": true,
		"schema": ARTIFACT_AI_VALUATION_SCHEMA,
		"report_status": "artifact_reward_metadata_valued",
		"scenario_id": String(session.scenario_id),
		"faction_id": resolved_faction_id,
		"origin": {"x": origin_pos.x, "y": origin_pos.y},
		"target_count": public_targets.size(),
		"public_targets": public_targets,
		"role_bucket_counts": role_bucket_counts,
		"runtime_surface_counts": runtime_surface_counts,
		"source_context_counts": source_context_counts,
		"strategic_band_counts": strategic_band_counts,
		"faction_fit_count": faction_fit_count,
		"set_piece_count": set_piece_count,
		"selection_policy": "report_only_metadata_bands_with_existing_artifact_targeting",
		"runtime_policy": {
			"live_drop_execution": false,
			"save_version_bump": false,
			"set_bonuses_active": false,
			"rare_resource_activation": false,
			"broad_ai_rewrite": false,
		},
	}

static func artifact_target_valuation_breakdown(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	node: Variant,
	origin_pos: Vector2i,
	faction_id: String = ""
) -> Dictionary:
	if not (node is Dictionary) or bool(node.get("collected", false)):
		return {}
	var placement_id := String(node.get("placement_id", ""))
	var artifact_id := String(node.get("artifact_id", ""))
	if placement_id == "" or artifact_id == "":
		return {}
	var artifact := ContentService.get_artifact(artifact_id)
	if artifact.is_empty():
		return {}
	var resolved_faction_id := faction_id
	if resolved_faction_id == "":
		resolved_faction_id = String(config.get("faction_id", ""))
	var target_tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	var goal_distance := _path_distance(session, origin_pos, [target_tile], "")
	if goal_distance >= 9999:
		return {}
	var roles := _normalize_string_array(artifact.get("roles", []))
	var role_buckets := _artifact_role_buckets(artifact)
	var runtime_surfaces := _artifact_runtime_surfaces(artifact)
	var source_contexts := _artifact_source_contexts(artifact_id)
	var source_context_tags := []
	for context_value in source_contexts:
		if not (context_value is Dictionary):
			continue
		var source_tag := String(context_value.get("source_tag", ""))
		if source_tag != "" and source_tag not in source_context_tags:
			source_context_tags.append(source_tag)
	for source_tag in _normalize_string_array(artifact.get("source_tags", [])):
		if source_tag not in source_context_tags:
			source_context_tags.append(source_tag)
	var faction_affinity := _normalize_string_array(artifact.get("faction_affinity", []))
	var ai_hints: Dictionary = artifact.get("ai_hints", {}) if artifact.get("ai_hints", {}) is Dictionary else {}
	var preferred_factions := _normalize_string_array(ai_hints.get("preferred_faction_ids", []))
	var faction_match := (
		resolved_faction_id != ""
		and (resolved_faction_id in faction_affinity or resolved_faction_id in preferred_factions)
	)
	var set_id := _artifact_set_id_from_record(artifact)
	var base_value := _artifact_target_priority(session, node)
	var taxonomy_value := _artifact_taxonomy_signal_value(artifact, role_buckets)
	var runtime_value := _artifact_runtime_signal_value(artifact, runtime_surfaces)
	var source_value: int = min(45, source_contexts.size() * 10 + source_context_tags.size() * 4)
	var affinity_value: int = 32 if faction_match else 0
	var set_context_value: int = 18 if set_id != "" else 0
	var objective_value: int = _objective_proximity_bonus(session, target_tile.x, target_tile.y)
	var faction_bias: int = priority_target_bonus(config, placement_id)
	var travel_cost: int = max(0, goal_distance - 1) * 3
	var assignment_penalty: int = _assignment_penalty(session, "artifact", placement_id)
	var final_priority: int = max(
		0,
		_weighted_priority(
			config,
			resolved_faction_id,
			"artifact",
			placement_id,
			base_value,
			"",
			false
		) - assignment_penalty
	)
	var reason_codes := _artifact_reason_codes(
		artifact,
		role_buckets,
		runtime_surfaces,
		source_context_tags,
		faction_match,
		set_id
	)
	return {
		"target_kind": "artifact",
		"placement_id": placement_id,
		"artifact_id": artifact_id,
		"artifact_label": String(artifact.get("name", artifact_id)),
		"target_label": ArtifactRulesScript.describe_artifact(artifact_id),
		"target_x": target_tile.x,
		"target_y": target_tile.y,
		"artifact_class": String(artifact.get("artifact_class", "")),
		"rarity": String(artifact.get("rarity", "")),
		"family": String(artifact.get("family", "")),
		"roles": roles,
		"role_buckets": role_buckets,
		"accord_affinity": String(artifact.get("accord_affinity", "")),
		"faction_affinity": faction_affinity,
		"faction_affinity_match": faction_match,
		"set_id": set_id,
		"source_tags": _normalize_string_array(artifact.get("source_tags", [])),
		"source_contexts": source_contexts,
		"source_context_tags": source_context_tags,
		"runtime_surfaces": runtime_surfaces,
		"strategic_band": _artifact_strategic_band(taxonomy_value + runtime_value + source_value + affinity_value + set_context_value),
		"base_value": base_value,
		"taxonomy_value": taxonomy_value,
		"runtime_value": runtime_value,
		"source_value": source_value,
		"affinity_value": affinity_value,
		"set_context_value": set_context_value,
		"objective_value": objective_value,
		"faction_bias": faction_bias,
		"travel_cost": travel_cost,
		"assignment_penalty": assignment_penalty,
		"final_priority": final_priority,
		"reason_codes": reason_codes,
		"public_reason": _artifact_public_reason(reason_codes),
		"public_importance": _artifact_public_importance(reason_codes, final_priority),
		"report_reason": "metadata valuation from taxonomy, runtime surfaces, source contexts, faction fit, and set context",
	}

static func artifact_ai_public_leak_check(public_surfaces: Variant) -> Dictionary:
	var stack := [public_surfaces]
	var checked_records := 0
	while not stack.is_empty():
		var value = stack.pop_back()
		if value is Array:
			for item in value:
				stack.append(item)
			continue
		if value is Dictionary:
			checked_records += 1
			var text := JSON.stringify(value)
			for token in ARTIFACT_AI_BLOCKED_PUBLIC_TOKENS:
				if text.contains(String(token)):
					return {"ok": false, "error": "public artifact valuation surface leaked token %s" % String(token)}
			for nested_key in value.keys():
				var nested = value[nested_key]
				if nested is Array or nested is Dictionary:
					stack.append(nested)
			continue
		var value_text := String(value)
		for token in ARTIFACT_AI_BLOCKED_PUBLIC_TOKENS:
			if value_text.contains(String(token)):
				return {"ok": false, "error": "public artifact valuation text leaked token %s" % String(token)}
	return {
		"ok": true,
		"checked_records": checked_records,
		"blocked_public_tokens": ARTIFACT_AI_BLOCKED_PUBLIC_TOKENS,
	}

const AI_HERO_TASK_REPORT_ID := "AI_HERO_TASK_STATE_BOUNDARY_REPORT"
const AI_HERO_TASK_STATE_POLICY := "report_only"
const AI_HERO_TASK_SOURCE_KIND := "commander_role_adapter"
const AI_HERO_TASK_CLASSES := [
	"raid_town",
	"retake_site",
	"contest_site",
	"stabilize_front",
	"defend_front",
	"recover_commander",
	"rebuild_host",
	"reserve",
]
const AI_HERO_TASK_EXCLUSIVE_CLASSES := ["retake_site", "contest_site", "defend_front", "raid_town"]
const AI_HERO_TASK_PUBLIC_EVENT_KEYS := [
	"event_id",
	"day",
	"sequence",
	"event_type",
	"faction_id",
	"faction_label",
	"actor_id",
	"actor_label",
	"task_class",
	"target_kind",
	"target_id",
	"target_label",
	"front_id",
	"visibility",
	"public_importance",
	"summary",
	"reason_codes",
	"public_reason",
	"state_policy",
]
const AI_HERO_TASK_BLOCKED_PUBLIC_TOKENS := [
	"resource_score_breakdown",
	"resource_affinity_value",
	"weighted_claim_value",
	"weighted_income_value",
	"final_priority",
	"debug_reason",
	"target_debug_reason",
	"fixture_",
	"score",
	"priority_table",
	"breakdown",
	"hero_task_state",
	"commander_role_state",
	"SAVE_VERSION",
	"body_tiles",
	"approach",
	"task_id",
	"source_id",
	"assignment_id_hint",
	"route_policy",
	"reservation_key",
	"invalidated_by_task_id",
]
const AI_HERO_TASK_LIVE_ADOPTION_GATE_REPORT_ID := "AI_HERO_TASK_LIVE_ADOPTION_GATE_REPORT"
const AI_HERO_TASK_LIVE_ADOPTION_GATE_EVENT_KEYS := [
	"event_id",
	"day",
	"sequence",
	"event_type",
	"faction_id",
	"faction_label",
	"actor_id",
	"actor_label",
	"target_kind",
	"target_id",
	"target_label",
	"visibility",
	"public_importance",
	"summary",
	"reason_codes",
	"public_reason",
	"state_policy",
]
const AI_HERO_TASK_LIVE_ADOPTION_BLOCKED_PUBLIC_TOKENS := [
	"resource_score_breakdown",
	"final_score",
	"debug_reason",
	"target_debug_reason",
	"fixture_",
	"score",
	"priority_table",
	"breakdown",
	"hero_task_state",
	"commander_role_state",
	"SAVE_VERSION",
	"schema_version",
	"planner_epoch",
	"body_tiles",
	"approach",
	"route_policy",
	"reservation_key",
	"task_id",
	"source_id",
	"assignment_id_hint",
	"invalidated_by_task_id",
]

static func assign_target(session: SessionStateStoreScript.SessionData, config: Dictionary, raid: Dictionary) -> Dictionary:
	var previous_target := _current_target_snapshot(raid)
	var had_memory := not commander_target_memory(raid.get("enemy_commander_state", {})).is_empty()
	var task_record_for_assignment := {}
	if _raid_target_valid(session, raid):
		raid = _refresh_target(session, raid)
	else:
		raid = _clear_delivery_intercept_target(raid)
		var plan = ai_live_town_retake_target_selection_plan(session, config, raid)
		if plan.is_empty():
			plan = ai_active_front_support_target_selection_plan(session, config, raid)
		if plan.is_empty():
			plan = ai_hero_task_saved_target_selection_plan(session, config, raid)
		if plan.is_empty():
			plan = ai_hero_task_live_target_selection_plan(session, config, raid)
		if plan.is_empty():
			plan = choose_target(
				session,
				config,
				{"x": int(raid.get("x", 0)), "y": int(raid.get("y", 0))},
				raid.get("enemy_commander_state", {})
			)
		if not plan.is_empty():
			if plan.get("hero_task_record", {}) is Dictionary:
				task_record_for_assignment = plan.get("hero_task_record", {}).duplicate(true)
			plan.erase("hero_task_record")
			plan.erase("hero_task_id")
			raid.merge(plan, true)
	raid.erase("hero_task_record")
	raid.erase("hero_task_id")
	var current_target := _current_target_snapshot(raid)
	if _target_signature(current_target) != "" and (
		_target_signature(previous_target) != _target_signature(current_target)
		or not had_memory
	):
		var commander_state = raid.get("enemy_commander_state", {})
		if commander_state is Dictionary and not commander_state.is_empty():
			raid["enemy_commander_state"] = record_target_assignment(
				commander_state,
				String(current_target.get("target_kind", "")),
				String(current_target.get("target_placement_id", "")),
				String(current_target.get("target_label", "")),
				int(current_target.get("target_x", 0)),
				int(current_target.get("target_y", 0))
			)
		_ai_hero_task_record_live_assignment(session, config, raid, current_target, task_record_for_assignment)
	return raid

static func ai_active_front_support_target_selection_plan(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary
) -> Dictionary:
	if session == null or raid.is_empty():
		return {}
	var faction_id := String(config.get("faction_id", raid.get("spawned_by_faction_id", "")))
	if faction_id == "":
		return {}
	var current_placement_id := String(raid.get("placement_id", ""))
	var origin_pos := Vector2i(int(raid.get("x", 0)), int(raid.get("y", 0)))
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	var best := {}
	for front_value in session.overworld.get("encounters", []):
		if not _is_active_raid(front_value, faction_id, resolved_encounters):
			continue
		var front: Dictionary = front_value
		if String(front.get("placement_id", "")) == current_placement_id:
			continue
		if not _active_front_needs_support(front):
			continue
		var candidate := _active_front_support_candidate(session, config, faction_id, front, origin_pos, current_placement_id)
		if candidate.is_empty():
			continue
		if best.is_empty() or _active_front_support_candidate_beats(candidate, best):
			best = candidate
	return best

static func _active_front_needs_support(front: Dictionary) -> bool:
	if front.is_empty():
		return false
	var reason_codes := _normalize_string_array(front.get("target_reason_codes", []))
	if "active_front_support" in reason_codes:
		return false
	for code in [
		"awaiting_support",
		"assault_risk_staging",
		"assault_risk_regroup",
		"encounter_risk_staging",
		"encounter_risk_regroup",
		"hero_hunt_risk_shadow",
		"hero_hunt_risk_regroup",
		"hero_hunt",
		"guard_clearance",
		"site_contested",
		"resource_risk_staging",
		"resource_risk_regroup",
		"objective_front",
	]:
		if code in reason_codes:
			return true
	if raid_regroup_needed(front):
		return true
	var desired := desired_raid_strength(front)
	var strength := raid_strength(front)
	return desired > 0 and strength < int(ceili(float(desired) * 0.90))

static func _active_front_support_candidate(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	front: Dictionary,
	origin_pos: Vector2i,
	current_placement_id: String
) -> Dictionary:
	var target_kind := String(front.get("target_kind", ""))
	var target_id := String(front.get("target_placement_id", ""))
	var front_reason_codes := _normalize_string_array(front.get("target_reason_codes", []))
	if target_kind == "regroup" and String(front.get("previous_target_kind", "")) in ["town", "encounter", "hero", "resource"]:
		target_kind = String(front.get("previous_target_kind", ""))
		target_id = String(front.get("previous_target_placement_id", ""))
	if target_kind not in ["town", "encounter", "hero", "resource"] or target_id == "":
		return {}
	var target_label := ""
	var target_x := 0
	var target_y := 0
	var goal_tiles := []
	var objective_anchor := false
	match target_kind:
		"town":
			var town_result := _find_town_by_placement(session, target_id)
			if int(town_result.get("index", -1)) < 0:
				return {}
			var town: Dictionary = town_result.get("town", {})
			var town_owner := String(town.get("owner", "neutral"))
			var neutral_expansion := town_owner == "neutral" and (
				"town_expansion" in front_reason_codes
				or "neutral_town_claim" in front_reason_codes
				or "neutral_town_siege" in front_reason_codes
			)
			if town_owner != "player" and not neutral_expansion:
				return {}
			target_label = _town_name(town)
			target_x = int(town.get("x", 0))
			target_y = int(town.get("y", 0))
			goal_tiles = _town_staging_tiles(session, town)
			objective_anchor = _town_is_objective_anchor(session, target_id)
		"encounter":
			var encounter_result := _find_encounter_by_placement(session, target_id)
			if int(encounter_result.get("index", -1)) < 0:
				return {}
			var encounter: Dictionary = encounter_result.get("encounter", {})
			if OverworldRulesScript.is_encounter_resolved(session, encounter):
				return {}
			var encounter_template := ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
			target_label = String(encounter_template.get("name", target_id))
			target_x = int(encounter.get("x", 0))
			target_y = int(encounter.get("y", 0))
			goal_tiles = _encounter_staging_tiles(session, encounter)
			objective_anchor = _encounter_is_objective_anchor(session, encounter)
		"hero":
			var hero := _player_hero_snapshot_for_task(session, target_id)
			if hero.is_empty():
				return {}
			var hero_tile := _player_hero_goal_tile(hero)
			target_label = String(hero.get("name", target_id))
			target_x = hero_tile.x
			target_y = hero_tile.y
			goal_tiles = _hero_target_goal_tiles(session, origin_pos, hero_tile, current_placement_id)
			objective_anchor = true
		"resource":
			var node_result := _find_resource_by_placement(session, target_id)
			if int(node_result.get("index", -1)) < 0:
				return {}
			var node: Dictionary = node_result.get("node", {})
			var site := ContentService.get_resource_site(String(node.get("site_id", "")))
			if not _resource_node_contestable_by_faction(node, site, faction_id):
				return {}
			target_label = String(site.get("name", target_id))
			target_x = int(node.get("x", 0))
			target_y = int(node.get("y", 0))
			goal_tiles = [Vector2i(target_x, target_y)]
			objective_anchor = _objective_proximity_bonus(session, target_x, target_y) > 0
	if goal_tiles.is_empty():
		return {}
	var goal_distance := _path_distance(session, origin_pos, goal_tiles, current_placement_id)
	if goal_distance >= 9999:
		return {}
	var goal_tile := _best_goal_tile(session, origin_pos, goal_tiles)
	var reason_codes := ["active_front_support", "army_consolidation"]
	for code in [
		"town_siege",
		"town_expansion",
		"neutral_town_claim",
		"neutral_town_siege",
		"objective_front",
		"guard_clearance",
		"site_contested",
		"hero_hunt",
		"hero_hunt_risk_shadow",
		"hero_hunt_risk_regroup",
		"resource_risk_staging",
		"resource_risk_regroup",
		"exposed_hero",
	]:
		if code in front_reason_codes and code not in reason_codes:
			reason_codes.append(code)
	if target_kind == "town" and "town_siege" not in reason_codes and "town_expansion" not in reason_codes:
		reason_codes.append("town_siege")
	if target_kind == "encounter" and "objective_front" not in reason_codes and objective_anchor:
		reason_codes.append("objective_front")
	if target_kind == "hero" and "hero_hunt" not in reason_codes:
		reason_codes.append("hero_hunt")
	if target_kind == "resource" and "site_contested" not in reason_codes:
		reason_codes.append("site_contested")
	var strength_gap: int = max(0, desired_raid_strength(front) - raid_strength(front))
	var committed_support_strength := _active_front_committed_support_strength(
		session,
		faction_id,
		target_kind,
		target_id,
		String(front.get("placement_id", "")),
		current_placement_id
	)
	var open_support_gap: int = max(0, strength_gap - committed_support_strength)
	if open_support_gap <= 0:
		return {}
	var support_priority_base := 180
	if target_kind == "hero":
		support_priority_base = 470
	var priority: int = int(max(
		0,
		_weighted_priority(
			config,
			faction_id,
			target_kind,
			target_id,
			support_priority_base + int(ceili(float(open_support_gap) / 4.0)) + priority_target_bonus(config, target_id),
			"",
			objective_anchor
		) - _assignment_penalty(session, target_kind, target_id)
	))
	return {
		"target_kind": target_kind,
		"target_placement_id": target_id,
		"target_label": target_label,
		"target_x": target_x,
		"target_y": target_y,
		"goal_x": goal_tile.x,
		"goal_y": goal_tile.y,
		"goal_distance": goal_distance,
		"priority": priority,
		"target_reason_codes": reason_codes,
		"target_public_reason": "reinforcing active front",
		"target_public_importance": "high",
		"target_debug_reason": "active front support for %s" % String(front.get("placement_id", "")),
		"supporting_front_placement_id": String(front.get("placement_id", "")),
		"supporting_front_target_kind": target_kind,
		"supporting_front_target_id": target_id,
		"support_strength_gap": open_support_gap,
		"support_committed_strength": committed_support_strength,
	}

static func _active_front_committed_support_strength(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	target_kind: String,
	target_id: String,
	front_placement_id: String,
	current_placement_id: String
) -> int:
	if session == null or faction_id == "" or target_kind == "" or target_id == "":
		return 0
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	var committed := 0
	for encounter_value in session.overworld.get("encounters", []):
		if not _is_active_raid(encounter_value, faction_id, resolved_encounters):
			continue
		var encounter: Dictionary = encounter_value
		var placement_id := String(encounter.get("placement_id", ""))
		if placement_id == "" or placement_id == front_placement_id or placement_id == current_placement_id:
			continue
		if String(encounter.get("target_kind", "")) != target_kind:
			continue
		if String(encounter.get("target_placement_id", "")) != target_id:
			continue
		var reason_codes := _normalize_string_array(encounter.get("target_reason_codes", []))
		if "active_front_support" not in reason_codes and String(encounter.get("supporting_front_placement_id", "")) != front_placement_id:
			continue
		committed += raid_strength(encounter)
	return committed

static func _active_front_support_candidate_beats(candidate: Dictionary, best: Dictionary) -> bool:
	if int(candidate.get("priority", 0)) == int(best.get("priority", 0)):
		if int(candidate.get("goal_distance", 9999)) == int(best.get("goal_distance", 9999)):
			return String(candidate.get("target_label", "")) < String(best.get("target_label", ""))
		return int(candidate.get("goal_distance", 9999)) < int(best.get("goal_distance", 9999))
	return int(candidate.get("priority", 0)) > int(best.get("priority", 0))

static func ai_live_town_retake_target_selection_plan(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary
) -> Dictionary:
	if session == null or raid.is_empty():
		return {}
	var faction_id := String(config.get("faction_id", raid.get("spawned_by_faction_id", "")))
	if faction_id == "":
		return {}
	var origin_pos := Vector2i(int(raid.get("x", 0)), int(raid.get("y", 0)))
	var current_placement_id := String(raid.get("placement_id", ""))
	var best := {}
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		if String(town.get("owner", "neutral")) != "player":
			continue
		var town_id := String(town.get("placement_id", ""))
		if town_id == "":
			continue
		var front_state: Dictionary = OverworldRulesScript.town_front_state(session, town)
		if not bool(front_state.get("active", false)):
			continue
		if String(front_state.get("faction_id", "")) != faction_id:
			continue
		if String(front_state.get("mode", "")) != "retake":
			continue
		if _ai_hero_task_live_target_reserved(session, faction_id, "town", town_id, current_placement_id, _ai_hero_task_actor_id_from_raid(raid), true):
			continue
		var staging_tiles := _town_staging_tiles(session, town)
		var goal_distance := _path_distance(session, origin_pos, staging_tiles, current_placement_id)
		if goal_distance >= 9999:
			continue
		var goal_tile := _best_goal_tile(session, origin_pos, staging_tiles)
		var objective_anchor := _town_is_objective_anchor(session, town_id)
		var reason_codes := ["town_siege", "retake_front"]
		if objective_anchor:
			reason_codes.append("objective_front")
		var candidate := {
			"target_kind": "town",
			"target_placement_id": town_id,
			"target_label": _town_name(town),
			"target_x": int(town.get("x", 0)),
			"target_y": int(town.get("y", 0)),
			"goal_x": goal_tile.x,
			"goal_y": goal_tile.y,
			"goal_distance": goal_distance,
			"priority": max(
				0,
				_weighted_priority(
					config,
					faction_id,
					"town",
					town_id,
					330 + _town_strategic_priority_bonus(session, town, faction_id, objective_anchor),
					"",
					objective_anchor
				) - _assignment_penalty(session, "town", town_id)
			),
			"target_reason_codes": reason_codes,
			"target_public_reason": "retaking captured town",
			"target_debug_reason": "live retake front town target selection",
			"target_public_importance": "critical",
		}
		if best.is_empty() or _candidate_beats(candidate, best):
			best = candidate
	return best

static func advance_raids(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	state: Dictionary = {}
) -> Dictionary:
	DifficultyRulesScript.normalize_session(session)
	var encounters = session.overworld.get("encounters", [])
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	var total_pillage = {}
	var marching_counts = {}
	var pressure_counts = {}
	var event_messages = []
	var event_records = []

	for index in range(encounters.size()):
		var encounter = encounters[index]
		if not _is_active_raid(encounter, faction_id, resolved_encounters):
			continue

		encounter = ensure_raid_army(encounter, session)
		var previous_target := _current_target_snapshot(encounter)
		encounter = _redirect_understrength_raid_to_regroup(session, config, encounter, faction_id)
		encounter = _redirect_raid_to_threatened_town_defense(session, config, encounter, faction_id)
		encounter = _redirect_raid_to_threatened_resource_defense(session, config, encounter, faction_id)
		if not _raid_target_valid(session, encounter):
			var scouting_result := _maybe_cast_raid_adventure_scouting_spell(session, config, encounter, faction_id)
			encounter = scouting_result.get("encounter", encounter)
			for scouting_event_value in scouting_result.get("events", []):
				if scouting_event_value is Dictionary and not scouting_event_value.is_empty():
					event_records.append(scouting_event_value)
		encounter = assign_target(session, config, encounter)
		encounter = _redirect_fragile_raid_for_known_target_risk(session, config, encounter, faction_id)
		encounter = _redirect_unreachable_raid_target(session, config, encounter, faction_id)
		var assignment_event := ai_target_assignment_event(session, config, encounter, previous_target)
		if not assignment_event.is_empty():
			event_records.append(assignment_event)
		var grouping_result := group_nearby_raids_for_town_assault(
			session,
			config,
			encounters,
			index,
			encounter,
			faction_id,
			resolved_encounters
		)
		encounter = grouping_result.get("encounter", encounter)
		if bool(grouping_result.get("grouped", false)):
			resolved_encounters = session.overworld.get("resolved_encounters", resolved_encounters)
			for event_value in grouping_result.get("events", []):
				if event_value is Dictionary and not event_value.is_empty():
					event_records.append(event_value)
		encounter["days_active"] = max(0, int(encounter.get("days_active", 0))) + 1

		var current = Vector2i(int(encounter.get("x", 0)), int(encounter.get("y", 0)))
		var goal_tiles = _goal_tiles_from_raid(session, encounter)
		var goal_distance = _path_distance(session, current, goal_tiles, String(encounter.get("placement_id", "")))
		var movement_steps := RAID_BASE_MOVEMENT_STEPS
		if goal_distance > RAID_BASE_MOVEMENT_STEPS and goal_distance < 9999:
			var spell_result := _maybe_cast_raid_adventure_movement_spell(
				session,
				config,
				encounter,
				goal_distance,
				faction_id
			)
			encounter = spell_result.get("encounter", encounter)
			movement_steps = max(movement_steps, int(spell_result.get("movement_steps", movement_steps)))
			for spell_event_value in spell_result.get("events", []):
				if spell_event_value is Dictionary and not spell_event_value.is_empty():
					event_records.append(spell_event_value)
		for step_index in range(max(0, movement_steps)):
			goal_tiles = _goal_tiles_from_raid(session, encounter)
			goal_distance = _path_distance(session, current, goal_tiles, String(encounter.get("placement_id", "")))
			if goal_distance <= 0 or goal_distance >= 9999:
				break
			var next_step = _next_step_toward(session, current, goal_tiles, String(encounter.get("placement_id", "")))
			if next_step == current:
				break
			encounter["x"] = next_step.x
			encounter["y"] = next_step.y
			current = next_step

		goal_tiles = _goal_tiles_from_raid(session, encounter)
		goal_distance = _path_distance(session, current, goal_tiles, String(encounter.get("placement_id", "")))
		encounter["goal_distance"] = 0 if goal_distance == 9999 and current in goal_tiles else goal_distance
		encounter["arrived"] = int(encounter.get("goal_distance", 9999)) == 0

		var post_move_grouping_result := group_nearby_raids_for_town_assault(
			session,
			config,
			encounters,
			index,
			encounter,
			faction_id,
			resolved_encounters
		)
		encounter = post_move_grouping_result.get("encounter", encounter)
		if bool(post_move_grouping_result.get("grouped", false)):
			resolved_encounters = session.overworld.get("resolved_encounters", resolved_encounters)
			for event_value in post_move_grouping_result.get("events", []):
				if event_value is Dictionary and not event_value.is_empty():
					event_records.append(event_value)

		if bool(encounter.get("arrived", false)):
			var arrival_result = _resolve_arrived_target(session, encounter, state, faction_id, config)
			encounter = arrival_result.get("encounter", encounter)
			state = arrival_result.get("state", state)
			var event_message = String(arrival_result.get("event_message", ""))
			if event_message != "":
				event_messages.append(event_message)
			var arrival_event: Dictionary = arrival_result.get("ai_event", {})
			if not arrival_event.is_empty():
				event_records.append(arrival_event)
			if bool(encounter.get("raid_retired_to_rebuild", false)):
				encounters[index] = encounter
				continue
		encounters[index] = encounter

		var target_label = String(encounter.get("target_label", "the frontier")).strip_edges()
		if target_label == "":
			target_label = "the frontier"
		if bool(encounter.get("arrived", false)):
			pressure_counts[target_label] = int(pressure_counts.get(target_label, 0)) + 1
			if int(encounter.get("days_active", 0)) >= max(1, int(config.get("raid_pillage_delay", 1))):
				total_pillage = _merge_resources(
					total_pillage,
					_scale_resources(config.get("raid_pillage", {}), raid_pillage_weight(encounter))
				)
		else:
			marching_counts[target_label] = int(marching_counts.get(target_label, 0)) + 1

	session.overworld["encounters"] = encounters

	var messages = []
	var marching_message = _describe_count_map("march on", marching_counts)
	if marching_message != "":
		messages.append("%s %s." % [String(config.get("label", faction_id)), marching_message])
	var pressure_message = _describe_count_map("press", pressure_counts)
	if pressure_message != "":
		messages.append("%s %s." % [String(config.get("label", faction_id)), pressure_message])
	if not event_messages.is_empty():
		messages.append(" ".join(event_messages))

	var actual_losses = _remove_resources(
		session,
		HeroProgressionRulesScript.scale_raid_pillage(
			session.overworld.get("hero", {}),
			DifficultyRulesScript.scale_raid_pillage(session, total_pillage)
		)
	)
	if not actual_losses.is_empty():
		messages.append("%s pillages %s." % [String(config.get("label", faction_id)), _describe_resource_set(actual_losses)])

	return {
		"message": " ".join(messages),
		"state": state,
		"events": event_records,
	}

static func group_nearby_raids_for_town_assault(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	encounters: Array,
	leader_index: int,
	leader: Dictionary,
	faction_id: String,
	resolved_encounters: Array
) -> Dictionary:
	if session == null or leader.is_empty() or leader_index < 0 or leader_index >= encounters.size():
		return {"encounter": leader, "grouped": false, "events": []}
	var target_kind := String(leader.get("target_kind", ""))
	if target_kind not in ["town", "encounter", "hero"]:
		return {"encounter": leader, "grouped": false, "events": []}
	if raid_regroup_needed(leader):
		return {"encounter": leader, "grouped": false, "events": []}
	var town_id := String(leader.get("target_placement_id", ""))
	var leader_id := String(leader.get("placement_id", ""))
	if town_id == "" or leader_id == "":
		return {"encounter": leader, "grouped": false, "events": []}
	var target_view := _raid_grouping_target_view(session, target_kind, town_id)
	if target_view.is_empty():
		return {"encounter": leader, "grouped": false, "events": []}
	var donor_index := _best_nearby_assault_support_raid_index(
		session,
		encounters,
		leader_index,
		leader,
		faction_id,
		resolved_encounters
	)
	if donor_index < 0:
		return {"encounter": leader, "grouped": false, "events": []}
	var donor: Dictionary = encounters[donor_index]
	var donor_id := String(donor.get("placement_id", ""))
	var donor_has_commander := _raid_has_commander(donor)
	var donor_strength := raid_strength(donor)
	var before_strength := raid_strength(leader)
	leader = ensure_raid_army(leader, session)
	leader["enemy_army"] = _merged_raid_army_payload(leader, donor)
	leader["grouped_support_count"] = max(0, int(leader.get("grouped_support_count", 0))) + 1
	leader["grouped_support_strength"] = max(0, int(leader.get("grouped_support_strength", 0))) + donor_strength
	if donor_has_commander:
		leader["grouped_commander_support_count"] = max(0, int(leader.get("grouped_commander_support_count", 0))) + 1
	leader["last_grouped_support_placement_id"] = donor_id
	leader["last_grouped_support_day"] = int(session.day)
	var reason_codes := _normalize_string_array(leader.get("target_reason_codes", []))
	for code in _raid_grouping_reason_codes(target_kind, reason_codes):
		if code not in reason_codes:
			reason_codes.append(code)
	leader["target_reason_codes"] = reason_codes
	leader["target_public_reason"] = "army consolidation"
	leader["target_public_importance"] = "high"
	leader["target_debug_reason"] = "nearby support host consolidated for %s" % target_kind
	var commander_state = leader.get("enemy_commander_state", {})
	if commander_state is Dictionary and not commander_state.is_empty():
		leader["enemy_commander_state"] = sync_commander_army_continuity(
			commander_state,
			leader.get("enemy_army", {}),
			String(leader.get("encounter_id", leader.get("id", "")))
		)
	donor["grouped_into_placement_id"] = leader_id
	donor["grouped_into_target_id"] = town_id
	donor["grouped_day"] = int(session.day)
	donor["arrived"] = true
	if donor_has_commander:
		donor = _release_grouped_support_commander_to_rebuild_roster(
			session,
			faction_id,
			donor,
			leader_id
		)
		_ai_hero_task_finish_live_assignment(session, faction_id, donor, "completed", "valid")
	encounters[donor_index] = donor
	if donor_id != "" and donor_id not in resolved_encounters:
		resolved_encounters.append(donor_id)
	session.overworld["resolved_encounters"] = resolved_encounters
	var event := build_ai_event_record(
		session,
		config,
		"ai_raid_grouped",
		leader,
		{
			"target_kind": target_kind,
			"target_placement_id": town_id,
			"target_label": String(target_view.get("target_label", "the front")),
			"target_x": int(target_view.get("target_x", 0)),
			"target_y": int(target_view.get("target_y", 0)),
			"target_reason_codes": _raid_grouping_reason_codes(target_kind, reason_codes),
			"target_public_reason": "army consolidation",
			"target_public_importance": "high",
		},
		{
			"summary": "%s folds %s into the push on %s." % [
				_raid_name(leader),
				_raid_name(donor),
				String(target_view.get("target_label", "the front")),
			],
			"state_policy": "durable_state_reference",
			"public_importance": "high",
		}
	)
	return {
		"encounter": leader,
		"grouped": true,
		"events": [event],
		"donor_placement_id": donor_id,
		"leader_strength_before": before_strength,
		"leader_strength_after": raid_strength(leader),
		"donor_strength": donor_strength,
	}

static func _raid_grouping_target_view(
	session: SessionStateStoreScript.SessionData,
	target_kind: String,
	target_id: String
) -> Dictionary:
	match target_kind:
		"town":
			var town_result := _find_town_by_placement(session, target_id)
			if int(town_result.get("index", -1)) < 0:
				return {}
			var town: Dictionary = town_result.get("town", {})
			if String(town.get("owner", "neutral")) != "player":
				return {}
			return {
				"target_label": _town_name(town),
				"target_x": int(town.get("x", 0)),
				"target_y": int(town.get("y", 0)),
			}
		"encounter":
			var encounter_result := _find_encounter_by_placement(session, target_id)
			if int(encounter_result.get("index", -1)) < 0:
				return {}
			var encounter: Dictionary = encounter_result.get("encounter", {})
			if OverworldRulesScript.is_encounter_resolved(session, encounter):
				return {}
			var encounter_template := ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
			return {
				"target_label": String(encounter_template.get("name", target_id)),
				"target_x": int(encounter.get("x", 0)),
				"target_y": int(encounter.get("y", 0)),
			}
		"hero":
			var hero := _player_hero_snapshot_for_task(session, target_id)
			if hero.is_empty():
				return {}
			var hero_tile := _player_hero_goal_tile(hero)
			return {
				"target_label": String(hero.get("name", target_id)),
				"target_x": hero_tile.x,
				"target_y": hero_tile.y,
			}
	return {}

static func _raid_grouping_reason_codes(target_kind: String, leader_reason_codes: Array) -> Array:
	var output := ["army_consolidation"]
	if target_kind == "town":
		output.append("town_siege")
	elif target_kind == "encounter":
		output.append("objective_front")
	elif target_kind == "hero":
		output.append("hero_hunt")
	for code in [
		"guard_clearance",
		"site_contested",
		"active_front_support",
		"exposed_hero",
		"hero_hunt_risk_shadow",
		"hero_hunt_risk_regroup",
		"resource_risk_staging",
		"resource_risk_regroup",
	]:
		if code in leader_reason_codes and code not in output:
			output.append(code)
	return output

static func _best_nearby_assault_support_raid_index(
	session: SessionStateStoreScript.SessionData,
	encounters: Array,
	leader_index: int,
	leader: Dictionary,
	faction_id: String,
	resolved_encounters: Array
) -> int:
	var town_id := String(leader.get("target_placement_id", ""))
	var best_index := -1
	var best_strength := -1
	var best_label := ""
	var leader_strength := raid_strength(leader)
	var leader_has_commander := _raid_has_commander(leader)
	for index in range(encounters.size()):
		if index == leader_index:
			continue
		var donor_value = encounters[index]
		if not _is_active_raid(donor_value, faction_id, resolved_encounters):
			continue
		var donor: Dictionary = donor_value
		if bool(donor.get("arrived", false)):
			continue
		if String(donor.get("target_kind", "")) != String(leader.get("target_kind", "")):
			continue
		if String(donor.get("target_placement_id", "")) != town_id:
			continue
		if _raid_tile_distance(leader, donor) > 1:
			continue
		var donor_strength := raid_strength(donor)
		if _raid_has_commander(donor):
			if not leader_has_commander:
				continue
			if donor_strength > leader_strength:
				continue
		var donor_label := _raid_name(donor)
		if donor_strength > best_strength or (donor_strength == best_strength and donor_label < best_label):
			best_index = index
			best_strength = donor_strength
			best_label = donor_label
	return best_index

static func _release_grouped_support_commander_to_rebuild_roster(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	donor: Dictionary,
	leader_placement_id: String
) -> Dictionary:
	var updated_donor := donor.duplicate(true)
	var commander_state = updated_donor.get("enemy_commander_state", {})
	if not (commander_state is Dictionary) or commander_state.is_empty():
		return updated_donor
	var donor_encounter_id := String(updated_donor.get("encounter_id", updated_donor.get("id", "")))
	var released_commander := sync_commander_army_continuity(
		commander_state,
		{"stacks": []},
		donor_encounter_id
	)
	released_commander["grouped_into_placement_id"] = leader_placement_id
	released_commander["last_outcome"] = String(commander_state.get("last_outcome", released_commander.get("last_outcome", "")))
	updated_donor["enemy_commander_state"] = released_commander
	sync_commander_state_to_roster(
		session,
		faction_id,
		released_commander,
		COMMANDER_STATUS_AVAILABLE,
		"",
		0
	)
	return updated_donor

static func _maybe_cast_raid_adventure_movement_spell(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary,
	goal_distance: int,
	faction_id: String
) -> Dictionary:
	if goal_distance <= RAID_BASE_MOVEMENT_STEPS or goal_distance >= 9999:
		return {"encounter": raid, "movement_steps": RAID_BASE_MOVEMENT_STEPS, "events": []}
	var commander_state = raid.get("enemy_commander_state", {})
	if not (commander_state is Dictionary) or commander_state.is_empty():
		return {"encounter": raid, "movement_steps": RAID_BASE_MOVEMENT_STEPS, "events": []}
	var movement := {
		"current": RAID_BASE_MOVEMENT_STEPS,
		"max": clampi(goal_distance, RAID_BASE_MOVEMENT_STEPS + 1, RAID_ADVENTURE_SPELL_MAX_MOVEMENT_STEPS),
	}
	var context := {
		"target_kind": String(raid.get("target_kind", "")),
		"target_label": String(raid.get("target_label", raid.get("target_placement_id", ""))),
		"objective_steps_remaining": goal_distance,
		"route_pressure": true,
	}
	var report := adventure_spell_valuation_report(commander_state, movement, context)
	var selected := _selected_adventure_spell_candidate(report, "restore_movement")
	if selected.is_empty() or String(selected.get("recommendation", "")) != "cast":
		return {"encounter": raid, "movement_steps": RAID_BASE_MOVEMENT_STEPS, "events": []}
	var spell_id := String(selected.get("spell_id", ""))
	var cast_result := SpellRulesScript.cast_overworld_spell(commander_state, movement, spell_id)
	if not bool(cast_result.get("ok", false)):
		return {"encounter": raid, "movement_steps": RAID_BASE_MOVEMENT_STEPS, "events": []}
	var updated_raid := raid.duplicate(true)
	updated_raid["enemy_commander_state"] = cast_result.get("hero", commander_state)
	updated_raid["last_adventure_spell_id"] = spell_id
	updated_raid["last_adventure_spell_day"] = int(session.day)
	updated_raid["last_adventure_spell_movement_steps"] = int(cast_result.get("movement", {}).get("current", RAID_BASE_MOVEMENT_STEPS))
	var steps: int = clampi(
		int(cast_result.get("movement", {}).get("current", RAID_BASE_MOVEMENT_STEPS)),
		RAID_BASE_MOVEMENT_STEPS,
		RAID_ADVENTURE_SPELL_MAX_MOVEMENT_STEPS
	)
	var event := build_ai_event_record(
		session,
		config,
		"ai_adventure_spell_cast",
		updated_raid,
		{
			"target_kind": "spell",
			"target_placement_id": spell_id,
			"target_label": String(cast_result.get("spell_name", selected.get("spell_name", spell_id))),
			"target_x": int(updated_raid.get("x", 0)),
			"target_y": int(updated_raid.get("y", 0)),
			"target_reason_codes": ["adventure_spell", "route_tempo"],
			"target_public_reason": "route tempo",
			"target_public_importance": "medium",
			"target_debug_reason": "enemy commander cast a movement spell because it changes objective reach",
		},
		{
			"summary": "%s casts %s to press toward %s." % [
				raid_commander_display_name(updated_raid),
				String(cast_result.get("spell_name", spell_id)),
				String(updated_raid.get("target_label", "the front")),
			],
			"state_policy": "derived",
			"faction_id": faction_id,
		}
	)
	return {"encounter": updated_raid, "movement_steps": steps, "events": [event]}

static func _maybe_cast_raid_adventure_scouting_spell(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary,
	faction_id: String
) -> Dictionary:
	if session == null or faction_id == "":
		return {"encounter": raid, "events": []}
	var commander_state = raid.get("enemy_commander_state", {})
	if not (commander_state is Dictionary) or commander_state.is_empty():
		return {"encounter": raid, "events": []}
	if int(raid.get("last_adventure_scout_spell_day", -9999)) == int(session.day):
		return {"encounter": raid, "events": []}
	var max_radius := _known_scouting_spell_max_radius(commander_state)
	if max_radius <= 0:
		return {"encounter": raid, "events": []}
	var origin := Vector2i(int(raid.get("x", 0)), int(raid.get("y", 0)))
	var scoutable_targets := _scoutable_target_candidates(session, config, faction_id, origin, max_radius)
	if scoutable_targets.is_empty():
		return {"encounter": raid, "events": []}
	var movement := {
		"current": RAID_BASE_MOVEMENT_STEPS,
		"max": RAID_BASE_MOVEMENT_STEPS,
	}
	var report := adventure_spell_valuation_report(
		commander_state,
		movement,
		{
			"target_kind": "scouting",
			"target_label": "nearby targets",
			"scouting_pressure": true,
			"hidden_site_reveal": true,
			"unscouted_target_count": scoutable_targets.size(),
		}
	)
	var selected := _selected_adventure_spell_candidate(report, "reveal_radius")
	if selected.is_empty():
		return {"encounter": raid, "events": []}
	var spell_id := String(selected.get("spell_id", ""))
	var reveal_radius: int = max(0, int(selected.get("reveal_radius", 0)))
	if reveal_radius <= 0:
		return {"encounter": raid, "events": []}
	var selected_radius_targets := _scoutable_target_candidates(session, config, faction_id, origin, reveal_radius)
	if selected_radius_targets.is_empty():
		return {"encounter": raid, "events": []}
	var cast_result := SpellRulesScript.cast_overworld_spell(commander_state, movement, spell_id)
	if not bool(cast_result.get("ok", false)):
		return {"encounter": raid, "events": []}
	reveal_radius = max(reveal_radius, int(cast_result.get("fog_reveal_radius", 0)))
	var scouted_records := _record_enemy_scouting_reveal(
		session,
		config,
		faction_id,
		raid,
		spell_id,
		String(cast_result.get("spell_name", selected.get("spell_name", spell_id))),
		reveal_radius
	)
	var updated_raid := raid.duplicate(true)
	updated_raid["enemy_commander_state"] = cast_result.get("hero", commander_state)
	updated_raid["last_adventure_scout_spell_id"] = spell_id
	updated_raid["last_adventure_scout_spell_day"] = int(session.day)
	updated_raid["last_adventure_scout_reveal_radius"] = reveal_radius
	updated_raid["last_adventure_scouted_target_count"] = scouted_records.size()
	var event := build_ai_event_record(
		session,
		config,
		"ai_adventure_spell_cast",
		updated_raid,
		{
			"target_kind": "spell",
			"target_placement_id": spell_id,
			"target_label": String(cast_result.get("spell_name", selected.get("spell_name", spell_id))),
			"target_x": int(updated_raid.get("x", 0)),
			"target_y": int(updated_raid.get("y", 0)),
			"target_reason_codes": ["adventure_spell", "enemy_scouting"],
			"target_public_reason": "route scouting",
			"target_public_importance": "medium",
			"target_debug_reason": "enemy commander cast a scouting spell to reveal actionable nearby targets",
		},
		{
			"summary": "%s casts %s to scout nearby targets." % [
				raid_commander_display_name(updated_raid),
				String(cast_result.get("spell_name", spell_id)),
			],
			"state_policy": "derived",
			"faction_id": faction_id,
		}
	)
	return {"encounter": updated_raid, "events": [event]}

static func _selected_adventure_spell_candidate(report: Dictionary, effect_type: String) -> Dictionary:
	var selected := {}
	for candidate_value in report.get("candidates", []):
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		if String(candidate.get("effect_type", "")) != effect_type:
			continue
		if String(candidate.get("recommendation", "")) != "cast":
			continue
		if selected.is_empty() or _adventure_band_rank(String(candidate.get("value_band", ""))) > _adventure_band_rank(String(selected.get("value_band", ""))):
			selected = candidate
	return selected

static func _known_scouting_spell_max_radius(commander_state: Dictionary) -> int:
	var hero := SpellRulesScript.ensure_hero_spellbook(commander_state.duplicate(true))
	var max_radius := 0
	for spell in SpellRulesScript.known_spells(hero, SpellRulesScript.CONTEXT_OVERWORLD):
		if not (spell is Dictionary):
			continue
		var effect = spell.get("effect", {})
		if not (effect is Dictionary) or String(effect.get("type", "")) != "reveal_radius":
			continue
		max_radius = max(max_radius, max(0, int(effect.get("amount", effect.get("radius", 0)))))
	return max_radius

static func _scoutable_target_candidates(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	origin: Vector2i,
	radius: int
) -> Array:
	if session == null or faction_id == "" or radius <= 0:
		return []
	var output := []
	for candidate_value in _target_candidates(session, config, origin):
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		var target_kind := String(candidate.get("target_kind", ""))
		var target_id := String(candidate.get("target_placement_id", ""))
		if target_kind == "" or target_id == "":
			continue
		if _enemy_target_scouted(session, faction_id, target_kind, target_id):
			continue
		var target := Vector2i(int(candidate.get("target_x", origin.x)), int(candidate.get("target_y", origin.y)))
		if abs(origin.x - target.x) + abs(origin.y - target.y) > radius:
			continue
		output.append(candidate)
	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("priority", 0)) == int(b.get("priority", 0)):
			return String(a.get("target_label", "")) < String(b.get("target_label", ""))
		return int(a.get("priority", 0)) > int(b.get("priority", 0))
	)
	return output

static func _record_enemy_scouting_reveal(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	raid: Dictionary,
	spell_id: String,
	spell_name: String,
	reveal_radius: int
) -> Array:
	var origin := Vector2i(int(raid.get("x", 0)), int(raid.get("y", 0)))
	var targets := _scoutable_target_candidates(session, config, faction_id, origin, reveal_radius)
	var records := []
	for target_value in targets:
		if not (target_value is Dictionary):
			continue
		var target: Dictionary = target_value
		records.append(
			{
				"target_kind": String(target.get("target_kind", "")),
				"target_id": String(target.get("target_placement_id", "")),
				"target_label": String(target.get("target_label", target.get("target_placement_id", ""))),
				"x": int(target.get("target_x", 0)),
				"y": int(target.get("target_y", 0)),
				"scouted_day": int(session.day),
				"expires_day": int(session.day) + RAID_ADVENTURE_SCOUTING_MEMORY_DAYS,
				"source_spell_id": spell_id,
				"source_spell_name": spell_name,
				"source_raid_id": String(raid.get("placement_id", "")),
				"state_policy": "ai_known_world_memory",
			}
		)
	return _merge_enemy_scouted_target_records(session, faction_id, records)

static func _merge_enemy_scouted_target_records(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	records: Array
) -> Array:
	if session == null or faction_id == "" or records.is_empty():
		return []
	var states: Array = session.overworld.get("enemy_states", []) if session.overworld.get("enemy_states", []) is Array else []
	var state_index := -1
	for index in range(states.size()):
		if states[index] is Dictionary and String(states[index].get("faction_id", "")) == faction_id:
			state_index = index
			break
	if state_index < 0:
		states.append({"faction_id": faction_id})
		state_index = states.size() - 1
	var state: Dictionary = states[state_index] if states[state_index] is Dictionary else {"faction_id": faction_id}
	var memory: Dictionary = state.get("known_world_memory", {}) if state.get("known_world_memory", {}) is Dictionary else {}
	var existing: Array = memory.get("scouted_targets", []) if memory.get("scouted_targets", []) is Array else []
	var by_key := {}
	for existing_value in existing:
		if not (existing_value is Dictionary):
			continue
		var existing_record: Dictionary = existing_value
		if int(existing_record.get("expires_day", 0)) < int(session.day):
			continue
		by_key[_enemy_scouted_target_key(String(existing_record.get("target_kind", "")), String(existing_record.get("target_id", "")))] = existing_record
	for record_value in records:
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		var key := _enemy_scouted_target_key(String(record.get("target_kind", "")), String(record.get("target_id", "")))
		if key == ":":
			continue
		by_key[key] = record
	var merged := []
	for key in by_key.keys():
		merged.append(by_key[key])
	merged.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("scouted_day", 0)) == int(b.get("scouted_day", 0)):
			return String(a.get("target_label", "")) < String(b.get("target_label", ""))
		return int(a.get("scouted_day", 0)) > int(b.get("scouted_day", 0))
	)
	while merged.size() > RAID_ADVENTURE_SCOUTING_MAX_TARGET_RECORDS:
		merged.pop_back()
	memory["schema_version"] = 1
	memory["last_scouted_day"] = int(session.day)
	memory["scouted_targets"] = merged
	state["known_world_memory"] = memory
	states[state_index] = state
	session.overworld["enemy_states"] = states
	return records

static func _enemy_target_scouted(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	target_kind: String,
	target_id: String
) -> bool:
	if session == null or faction_id == "" or target_kind == "" or target_id == "":
		return false
	var key := _enemy_scouted_target_key(target_kind, target_id)
	for state_value in session.overworld.get("enemy_states", []):
		if not (state_value is Dictionary) or String(state_value.get("faction_id", "")) != faction_id:
			continue
		var memory: Dictionary = state_value.get("known_world_memory", {}) if state_value.get("known_world_memory", {}) is Dictionary else {}
		for record_value in memory.get("scouted_targets", []):
			if not (record_value is Dictionary):
				continue
			var record: Dictionary = record_value
			if _enemy_scouted_target_key(String(record.get("target_kind", "")), String(record.get("target_id", ""))) != key:
				continue
			return int(record.get("expires_day", 0)) >= int(session.day)
	return false

static func _enemy_scouted_target_priority_bonus(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	target_kind: String,
	target_id: String
) -> int:
	if _enemy_target_scouted(session, faction_id, target_kind, target_id):
		return RAID_ADVENTURE_SCOUTED_TARGET_PRIORITY_BONUS
	return 0

static func _enemy_scouted_target_key(target_kind: String, target_id: String) -> String:
	return "%s:%s" % [target_kind, target_id]

static func _merged_raid_army_payload(leader: Dictionary, donor: Dictionary) -> Dictionary:
	var leader_army := _normalize_army_payload(leader.get("enemy_army", {}))
	var donor_army := _normalize_army_payload(donor.get("enemy_army", {}))
	if donor_army.is_empty():
		donor_army = _base_enemy_army(String(donor.get("encounter_id", donor.get("id", ""))))
	var merged_stacks: Array = leader_army.get("stacks", []).duplicate(true) if leader_army.has("stacks") else []
	for stack_value in donor_army.get("stacks", []):
		if not (stack_value is Dictionary):
			continue
		merged_stacks = _add_army_stack(
			merged_stacks,
			String(stack_value.get("unit_id", "")),
			max(0, int(stack_value.get("count", 0)))
		)
	return {
		"id": String(leader_army.get("id", leader.get("encounter_id", leader.get("id", "raid")))),
		"name": String(leader_army.get("name", "Raid Host")),
		"stacks": merged_stacks,
	}

static func _raid_has_commander(raid: Dictionary) -> bool:
	if bool(raid.get("commanderless_support_column", false)):
		return false
	var commander_state = raid.get("enemy_commander_state", {})
	return commander_state is Dictionary and String(commander_state.get("roster_hero_id", "")) != ""

static func _raid_tile_distance(a: Dictionary, b: Dictionary) -> int:
	return abs(int(a.get("x", 0)) - int(b.get("x", 0))) + abs(int(a.get("y", 0)) - int(b.get("y", 0)))

static func _redirect_understrength_raid_to_regroup(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary,
	faction_id: String
) -> Dictionary:
	if session == null or raid.is_empty() or faction_id == "":
		return raid
	if String(raid.get("target_kind", "")) == "regroup":
		return _refresh_target(session, raid)
	if not raid_regroup_needed(raid):
		return raid
	var regroup_town := _nearest_regroup_town(session, raid, faction_id)
	if regroup_town.is_empty():
		return raid
	raid["previous_target_kind"] = String(raid.get("target_kind", ""))
	raid["previous_target_placement_id"] = String(raid.get("target_placement_id", ""))
	raid["previous_target_label"] = String(raid.get("target_label", ""))
	raid["target_kind"] = "regroup"
	raid["target_placement_id"] = String(regroup_town.get("placement_id", ""))
	raid["target_label"] = "%s regroup" % _town_name(regroup_town)
	raid["target_public_reason"] = "regrouping understrength host"
	raid["target_reason_codes"] = ["regroup_understrength", "army_consolidation", "town_defense"]
	raid["target_public_importance"] = "high"
	raid["target_debug_reason"] = "raid strength below regroup floor"
	raid["arrived"] = false
	raid["regroup_started_day"] = int(session.day)
	return _refresh_target(session, raid)

static func _redirect_unreachable_raid_target(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary,
	faction_id: String
) -> Dictionary:
	if session == null or raid.is_empty() or faction_id == "":
		return raid
	if String(raid.get("target_kind", "")) == "" or String(raid.get("target_kind", "")) == "regroup":
		return raid
	if not _raid_target_valid(session, raid):
		return raid
	var current := Vector2i(int(raid.get("x", 0)), int(raid.get("y", 0)))
	var goal_tiles := _goal_tiles_from_raid(session, raid)
	var distance := _path_distance(session, current, goal_tiles, String(raid.get("placement_id", "")))
	if distance < 9999 or current in goal_tiles:
		return raid
	var regroup_town := _nearest_regroup_town(session, raid, faction_id)
	if regroup_town.is_empty():
		var waiting := raid.duplicate(true)
		waiting["route_unreachable_day"] = int(session.day)
		waiting["goal_distance"] = 9999
		var waiting_codes := _normalize_string_array(waiting.get("target_reason_codes", []))
		for code in ["route_unreachable", "awaiting_route"]:
			if code not in waiting_codes:
				waiting_codes.append(code)
		waiting["target_reason_codes"] = waiting_codes
		waiting["target_public_reason"] = "seeking reachable route"
		waiting["target_public_importance"] = "medium"
		waiting["target_debug_reason"] = "target exists but no passable route is currently available"
		return waiting
	_ai_hero_task_finish_live_assignment(session, faction_id, raid, "invalid", "invalid_route_unreachable")
	var redirected := raid.duplicate(true)
	redirected["previous_target_kind"] = String(raid.get("target_kind", ""))
	redirected["previous_target_placement_id"] = String(raid.get("target_placement_id", ""))
	redirected["previous_target_label"] = String(raid.get("target_label", ""))
	redirected["target_kind"] = "regroup"
	redirected["target_placement_id"] = String(regroup_town.get("placement_id", ""))
	redirected["target_label"] = "%s regroup" % _town_name(regroup_town)
	redirected["target_public_reason"] = "rerouting blocked host"
	redirected["target_reason_codes"] = ["route_unreachable", "army_consolidation", "regroup_route_recovery"]
	redirected["target_public_importance"] = "high"
	redirected["target_debug_reason"] = "current target exists but has no passable route"
	redirected["arrived"] = false
	redirected["route_recovery_started_day"] = int(session.day)
	redirected = _refresh_target(session, redirected)
	_ai_hero_task_record_live_assignment(
		session,
		config,
		redirected,
		_current_target_snapshot(redirected),
		{}
	)
	return redirected

static func _redirect_fragile_raid_for_known_target_risk(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary,
	faction_id: String
) -> Dictionary:
	if session == null or raid.is_empty() or faction_id == "":
		return raid
	if String(raid.get("target_kind", "")) == "" or String(raid.get("target_kind", "")) == "regroup":
		return raid
	if bool(raid.get("arrived", false)):
		return raid
	var reason_codes := _normalize_string_array(raid.get("target_reason_codes", []))
	if "town_defense" in reason_codes or "site_defense" in reason_codes or "defend_front" in reason_codes:
		return raid
	if "active_front_support" in reason_codes or "awaiting_support" in reason_codes or String(raid.get("supporting_front_placement_id", "")) != "":
		return raid
	match String(raid.get("target_kind", "")):
		"town":
			if int(raid.get("assault_delay_until_day", 0)) > int(session.day):
				return raid
			var town_result := _find_town_by_placement(session, String(raid.get("target_placement_id", "")))
			var town: Dictionary = town_result.get("town", {})
			if int(town_result.get("index", -1)) < 0 or town.is_empty() or String(town.get("owner", "neutral")) != "player":
				return raid
			var readiness_report := _town_assault_advance_risk_report(session, raid, town)
			if bool(readiness_report.get("ready", true)):
				return raid
			return redirect_town_assault_for_risk(session, config, raid, faction_id, readiness_report)
		"encounter":
			if int(raid.get("encounter_arrival_delay_until_day", 0)) > int(session.day):
				return raid
			var encounter_report := encounter_arrival_ready_report(session, raid, faction_id)
			if bool(encounter_report.get("ready", true)):
				return raid
			return redirect_encounter_objective_for_risk(session, config, raid, faction_id, encounter_report)
		"resource":
			if int(raid.get("resource_arrival_delay_until_day", 0)) > int(session.day):
				return raid
			var resource_report := resource_arrival_ready_report(session, raid, faction_id)
			if bool(resource_report.get("ready", true)):
				return raid
			return redirect_resource_objective_for_risk(session, config, raid, faction_id, resource_report)
		"hero":
			if int(raid.get("hero_intercept_delay_until_day", 0)) > int(session.day):
				return raid
			var hero := _player_hero_snapshot_for_task(session, String(raid.get("target_placement_id", "")))
			if hero.is_empty():
				return raid
			var hero_report := _hero_intercept_advance_risk_report(raid, hero)
			if bool(hero_report.get("ready", true)):
				return raid
			return redirect_hero_intercept_for_risk(session, config, raid, faction_id, hero_report)
	return raid

static func resource_arrival_ready_report(
	session: SessionStateStoreScript.SessionData,
	raid: Dictionary,
	faction_id: String
) -> Dictionary:
	if session == null or raid.is_empty() or faction_id == "":
		return {"ready": true, "reason": "no_live_context"}
	if String(raid.get("target_kind", "")) != "resource":
		return {"ready": true, "reason": "not_resource_target"}
	var node_result = _find_resource_by_placement(session, String(raid.get("target_placement_id", "")))
	var node: Dictionary = node_result.get("node", {})
	if int(node_result.get("index", -1)) < 0 or node.is_empty():
		return {"ready": true, "reason": "target_missing"}
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	if not _resource_node_contestable_by_faction(node, site, faction_id):
		return {"ready": true, "reason": "not_contestable"}
	var host_strength := raid_strength(raid)
	var desired_strength := desired_raid_strength(raid)
	var guard := _resource_guard_encounter_for_node(session, node, site)
	var guard_strength := _encounter_guard_strength(guard) if not guard.is_empty() else 0
	var required_strength: int = max(60, int(ceili(float(desired_strength) * 0.70)))
	if String(node.get("collected_by_faction_id", "")) == "player" and _resource_site_is_persistent(site):
		required_strength = max(required_strength, 70)
	if guard_strength > 0:
		required_strength = max(
			required_strength,
			int(ceili(float(guard_strength) * 0.90)),
			int(ceili(float(desired_strength) * 0.75))
		)
	var ready := host_strength >= required_strength
	return {
		"ready": ready,
		"host_strength": host_strength,
		"guard_strength": guard_strength,
		"desired_strength": desired_strength,
		"required_strength": required_strength,
		"target_placement_id": String(node.get("placement_id", "")),
		"target_site_id": String(node.get("site_id", "")),
		"target_is_player_controlled": String(node.get("collected_by_faction_id", "")) == "player",
		"target_has_guard": not guard.is_empty(),
		"reason": "ready" if ready else "resource_front_strength",
	}

static func redirect_resource_objective_for_risk(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary,
	faction_id: String,
	risk_report: Dictionary = {}
) -> Dictionary:
	if session == null or raid.is_empty() or faction_id == "":
		return raid
	if String(raid.get("target_kind", "")) != "resource":
		return raid
	var strength := int(risk_report.get("host_strength", raid_strength(raid)))
	var required := int(risk_report.get("required_strength", desired_raid_strength(raid)))
	var debug_reason := "resource front risk gate: strength %d below %d" % [strength, required]
	var regroup_town := _nearest_regroup_town(session, raid, faction_id)
	var started_day := _risk_started_day(raid, "resource_arrival_risk_started_day", int(session.day))
	if (
		regroup_town.is_empty()
		and _risk_support_wait_exceeded(session, started_day)
		and _risk_committed_support_strength(session, faction_id, raid) <= 0
	):
		return _retire_risk_stalled_raid_to_rebuild(
			session,
			raid,
			faction_id,
			"resource_risk_stalled",
			"site_contested",
			strength,
			required
		)
	raid["previous_target_kind"] = String(raid.get("target_kind", ""))
	raid["previous_target_placement_id"] = String(raid.get("target_placement_id", ""))
	raid["previous_target_label"] = String(raid.get("target_label", ""))
	raid["target_public_reason"] = "gathering strength for resource claim"
	raid["target_public_importance"] = "high"
	raid["target_debug_reason"] = debug_reason
	raid["resource_arrival_risk_started_day"] = started_day
	raid["resource_arrival_delay_until_day"] = int(session.day) + 1
	raid["arrived"] = false
	if not regroup_town.is_empty():
		raid["target_kind"] = "regroup"
		raid["target_placement_id"] = String(regroup_town.get("placement_id", ""))
		raid["target_label"] = "%s regroup" % _town_name(regroup_town)
		raid["target_reason_codes"] = ["resource_risk_regroup", "regroup_understrength", "army_consolidation", "site_contested"]
		raid["resource_regroup_started_day"] = int(session.day)
		return _refresh_target(session, raid)
	var reason_codes := _normalize_string_array(raid.get("target_reason_codes", []))
	for code in ["resource_risk_staging", "awaiting_support", "site_contested"]:
		if code not in reason_codes:
			reason_codes.append(code)
	raid["target_reason_codes"] = reason_codes
	raid["goal_distance"] = max(1, int(raid.get("goal_distance", 1)))
	return raid

static func _town_assault_advance_risk_report(
	session: SessionStateStoreScript.SessionData,
	raid: Dictionary,
	town: Dictionary
) -> Dictionary:
	var assault_strength := raid_strength(raid)
	var desired_strength := desired_raid_strength(raid)
	var garrison_strength := _town_garrison_strength(town)
	var readiness: int = OverworldRulesScript.town_battle_readiness(town, session)
	var desired_floor := int(round(float(desired_strength) * 0.68))
	var garrison_floor := int(round(float(garrison_strength) * 0.85))
	var readiness_floor: int = 60 + (readiness * 2)
	var required_strength: int = max(85, desired_floor, garrison_floor, readiness_floor)
	var ready := assault_strength >= required_strength
	return {
		"ready": ready,
		"assault_strength": assault_strength,
		"desired_strength": desired_strength,
		"garrison_strength": garrison_strength,
		"town_readiness": readiness,
		"required_strength": required_strength,
		"reason": "ready_for_town_assault" if ready else "assault_risk_regroup",
	}

static func _hero_intercept_advance_risk_report(raid: Dictionary, hero: Dictionary) -> Dictionary:
	var hunter_strength := raid_strength(raid)
	var desired_strength := desired_raid_strength(raid)
	var hero_strength := _army_strength(hero.get("army", {}).get("stacks", []))
	var desired_floor := int(round(float(desired_strength) * 0.65))
	var hero_floor := int(round(float(hero_strength) * 0.85))
	var required_strength: int = max(75, desired_floor, hero_floor)
	var ready := hunter_strength >= required_strength
	return {
		"ready": ready,
		"hunter_strength": hunter_strength,
		"desired_strength": desired_strength,
		"hero_strength": hero_strength,
		"required_strength": required_strength,
		"reason": "ready_for_hero_intercept" if ready else "hero_hunt_risk_regroup",
	}

static func redirect_town_assault_for_risk(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary,
	faction_id: String,
	risk_report: Dictionary = {}
) -> Dictionary:
	if session == null or raid.is_empty() or faction_id == "":
		return raid
	if String(raid.get("target_kind", "")) != "town":
		return raid
	var strength := int(risk_report.get("assault_strength", raid_strength(raid)))
	var required := int(risk_report.get("required_strength", desired_raid_strength(raid)))
	var debug_reason := "town assault risk gate: strength %d below %d" % [strength, required]
	var regroup_town := _nearest_regroup_town(session, raid, faction_id)
	var started_day := _risk_started_day(raid, "assault_risk_started_day", int(session.day))
	if (
		regroup_town.is_empty()
		and _risk_support_wait_exceeded(session, started_day)
		and _risk_committed_support_strength(session, faction_id, raid) <= 0
	):
		return _retire_risk_stalled_raid_to_rebuild(
			session,
			raid,
			faction_id,
			"assault_risk_stalled",
			"town_siege",
			strength,
			required
		)
	raid["previous_target_kind"] = String(raid.get("target_kind", ""))
	raid["previous_target_placement_id"] = String(raid.get("target_placement_id", ""))
	raid["previous_target_label"] = String(raid.get("target_label", ""))
	raid["target_public_reason"] = "staging stronger assault"
	raid["target_public_importance"] = "high"
	raid["target_debug_reason"] = debug_reason
	raid["assault_risk_started_day"] = started_day
	raid["assault_delay_until_day"] = int(session.day) + 1
	raid["arrived"] = false
	var preserved_town_codes := []
	for code in ["town_expansion", "neutral_town_claim", "neutral_town_siege"]:
		if code in _normalize_string_array(raid.get("target_reason_codes", [])) and code not in preserved_town_codes:
			preserved_town_codes.append(code)
	if not regroup_town.is_empty():
		raid["target_kind"] = "regroup"
		raid["target_placement_id"] = String(regroup_town.get("placement_id", ""))
		raid["target_label"] = "%s regroup" % _town_name(regroup_town)
		raid["target_reason_codes"] = ["assault_risk_regroup", "regroup_understrength", "army_consolidation", "town_siege"]
		for code in preserved_town_codes:
			if code not in raid["target_reason_codes"]:
				raid["target_reason_codes"].append(code)
		raid["assault_regroup_started_day"] = int(session.day)
		return _refresh_target(session, raid)
	var reason_codes := _normalize_string_array(raid.get("target_reason_codes", []))
	for code in ["assault_risk_staging", "awaiting_support", "town_siege"] + preserved_town_codes:
		if code not in reason_codes:
			reason_codes.append(code)
	raid["target_reason_codes"] = reason_codes
	raid["goal_distance"] = max(1, int(raid.get("goal_distance", 1)))
	return raid

static func redirect_hero_intercept_for_risk(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary,
	faction_id: String,
	risk_report: Dictionary = {}
) -> Dictionary:
	if session == null or raid.is_empty() or faction_id == "":
		return raid
	if String(raid.get("target_kind", "")) != "hero":
		return raid
	var strength := int(risk_report.get("hunter_strength", raid_strength(raid)))
	var required := int(risk_report.get("required_strength", desired_raid_strength(raid)))
	var debug_reason := "hero intercept risk gate: strength %d below %d" % [strength, required]
	var regroup_town := _nearest_regroup_town(session, raid, faction_id)
	var started_day := _risk_started_day(raid, "hero_intercept_risk_started_day", int(session.day))
	if (
		regroup_town.is_empty()
		and _risk_support_wait_exceeded(session, started_day)
		and _risk_committed_support_strength(session, faction_id, raid) <= 0
	):
		return _retire_risk_stalled_raid_to_rebuild(
			session,
			raid,
			faction_id,
			"hero_hunt_risk_stalled",
			"hero_hunt",
			strength,
			required
		)
	raid["previous_target_kind"] = String(raid.get("target_kind", ""))
	raid["previous_target_placement_id"] = String(raid.get("target_placement_id", ""))
	raid["previous_target_label"] = String(raid.get("target_label", ""))
	raid["target_public_reason"] = "stalking stronger hero"
	raid["target_public_importance"] = "high"
	raid["target_debug_reason"] = debug_reason
	raid["hero_intercept_risk_started_day"] = started_day
	raid["hero_intercept_delay_until_day"] = int(session.day) + 1
	raid["arrived"] = false
	if not regroup_town.is_empty():
		raid["target_kind"] = "regroup"
		raid["target_placement_id"] = String(regroup_town.get("placement_id", ""))
		raid["target_label"] = "%s regroup" % _town_name(regroup_town)
		raid["target_reason_codes"] = ["hero_hunt_risk_regroup", "regroup_understrength", "army_consolidation", "hero_hunt"]
		raid["hero_hunt_regroup_started_day"] = int(session.day)
		return _refresh_target(session, raid)
	var reason_codes := _normalize_string_array(raid.get("target_reason_codes", []))
	for code in ["hero_hunt_risk_shadow", "awaiting_support", "hero_hunt"]:
		if code not in reason_codes:
			reason_codes.append(code)
	raid["target_reason_codes"] = reason_codes
	raid["goal_distance"] = max(1, int(raid.get("goal_distance", 1)))
	return raid

static func encounter_arrival_ready_report(
	session: SessionStateStoreScript.SessionData,
	raid: Dictionary,
	faction_id: String
) -> Dictionary:
	if session == null or raid.is_empty() or faction_id == "":
		return {"ready": true, "reason": "no_live_context"}
	if String(raid.get("target_kind", "")) != "encounter":
		return {"ready": true, "reason": "not_encounter_target"}
	var encounter_result = _find_encounter_by_placement(session, String(raid.get("target_placement_id", "")))
	var encounter_state: Dictionary = encounter_result.get("encounter", {})
	if int(encounter_result.get("index", -1)) < 0 or encounter_state.is_empty():
		return {"ready": true, "reason": "target_missing"}
	if OverworldRulesScript.is_encounter_resolved(session, encounter_state):
		return {"ready": true, "reason": "target_resolved"}
	var guard_strength := _encounter_guard_strength(encounter_state)
	if guard_strength <= 0:
		return {"ready": true, "reason": "no_guard_strength"}
	var host_strength := raid_strength(raid)
	var desired_strength := desired_raid_strength(raid)
	var required_strength: int = max(
		60,
		max(
			int(ceili(float(guard_strength) * 0.90)),
			int(ceili(float(desired_strength) * 0.75))
		)
	)
	var ready := host_strength >= required_strength
	return {
		"ready": ready,
		"host_strength": host_strength,
		"guard_strength": guard_strength,
		"desired_strength": desired_strength,
		"required_strength": required_strength,
		"target_placement_id": String(encounter_state.get("placement_id", "")),
		"target_encounter_id": String(encounter_state.get("encounter_id", encounter_state.get("id", ""))),
		"target_is_objective_anchor": _encounter_is_objective_anchor(session, encounter_state),
		"reason": "ready" if ready else "encounter_guard_strength",
	}

static func redirect_encounter_objective_for_risk(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary,
	faction_id: String,
	risk_report: Dictionary = {}
) -> Dictionary:
	if session == null or raid.is_empty() or faction_id == "":
		return raid
	if String(raid.get("target_kind", "")) != "encounter":
		return raid
	var strength := int(risk_report.get("host_strength", raid_strength(raid)))
	var required := int(risk_report.get("required_strength", desired_raid_strength(raid)))
	var debug_reason := "encounter arrival risk gate: strength %d below %d" % [strength, required]
	var regroup_town := _nearest_regroup_town(session, raid, faction_id)
	var started_day := _risk_started_day(raid, "encounter_arrival_risk_started_day", int(session.day))
	if (
		regroup_town.is_empty()
		and _risk_support_wait_exceeded(session, started_day)
		and _risk_committed_support_strength(session, faction_id, raid) <= 0
	):
		return _retire_risk_stalled_raid_to_rebuild(
			session,
			raid,
			faction_id,
			"encounter_risk_stalled",
			"objective_front",
			strength,
			required
		)
	raid["previous_target_kind"] = String(raid.get("target_kind", ""))
	raid["previous_target_placement_id"] = String(raid.get("target_placement_id", ""))
	raid["previous_target_label"] = String(raid.get("target_label", ""))
	raid["target_public_reason"] = "gathering strength for guarded site"
	raid["target_public_importance"] = "high"
	raid["target_debug_reason"] = debug_reason
	raid["encounter_arrival_risk_started_day"] = started_day
	raid["encounter_arrival_delay_until_day"] = int(session.day) + 1
	raid["arrived"] = false
	if not regroup_town.is_empty():
		raid["target_kind"] = "regroup"
		raid["target_placement_id"] = String(regroup_town.get("placement_id", ""))
		raid["target_label"] = "%s regroup" % _town_name(regroup_town)
		raid["target_reason_codes"] = ["encounter_risk_regroup", "regroup_understrength", "army_consolidation", "objective_front"]
		raid["encounter_regroup_started_day"] = int(session.day)
		return _refresh_target(session, raid)
	var reason_codes := _normalize_string_array(raid.get("target_reason_codes", []))
	for code in ["encounter_risk_staging", "awaiting_support", "objective_front"]:
		if code not in reason_codes:
			reason_codes.append(code)
	raid["target_reason_codes"] = reason_codes
	raid["goal_distance"] = max(1, int(raid.get("goal_distance", 1)))
	return raid

static func _risk_started_day(raid: Dictionary, key: String, fallback_day: int) -> int:
	var started_day := int(raid.get(key, 0))
	return started_day if started_day > 0 else fallback_day

static func _risk_support_wait_exceeded(session: SessionStateStoreScript.SessionData, started_day: int) -> bool:
	if session == null or started_day <= 0:
		return false
	return int(session.day) - started_day >= RAID_RISK_SUPPORT_STALL_DAYS

static func _risk_committed_support_strength(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	raid: Dictionary
) -> int:
	if session == null or faction_id == "" or raid.is_empty():
		return 0
	return _active_front_committed_support_strength(
		session,
		faction_id,
		String(raid.get("target_kind", "")),
		String(raid.get("target_placement_id", "")),
		String(raid.get("placement_id", "")),
		""
	)

static func _retire_risk_stalled_raid_to_rebuild(
	session: SessionStateStoreScript.SessionData,
	raid: Dictionary,
	faction_id: String,
	stall_code: String,
	front_code: String,
	strength: int,
	required: int
) -> Dictionary:
	var retired := raid.duplicate(true)
	retired["risk_stalled_to_rebuild"] = true
	retired["risk_stall_code"] = stall_code
	retired["risk_stall_day"] = int(session.day)
	retired["risk_stall_strength"] = max(0, strength)
	retired["risk_stall_required_strength"] = max(0, required)
	retired["raid_retired_to_rebuild"] = true
	retired["retired_to_rebuild_day"] = int(session.day)
	retired["retired_to_rebuild_reason"] = "risk_support_timeout"
	retired["previous_target_kind"] = String(raid.get("target_kind", ""))
	retired["previous_target_placement_id"] = String(raid.get("target_placement_id", ""))
	retired["previous_target_label"] = String(raid.get("target_label", ""))
	var commander_state = retired.get("enemy_commander_state", {})
	var roster_hero_id := ""
	var commander_label := _raid_name(retired)
	if commander_state is Dictionary and not commander_state.is_empty():
		_ai_hero_task_finish_live_assignment(session, faction_id, retired, "suspended", "invalid_actor_rebuilding")
		var updated_commander := sync_commander_army_continuity(
			commander_state,
			retired.get("enemy_army", {}),
			String(retired.get("encounter_id", retired.get("id", "")))
		)
		roster_hero_id = String(updated_commander.get("roster_hero_id", ""))
		commander_label = String(updated_commander.get("name", commander_label))
		retired["enemy_commander_state"] = updated_commander
		sync_commander_state_to_roster(
			session,
			faction_id,
			updated_commander,
			COMMANDER_STATUS_AVAILABLE,
			"",
			0,
			String(updated_commander.get("last_outcome", ""))
		)
	var resolved = session.overworld.get("resolved_encounters", [])
	if not (resolved is Array):
		resolved = []
	var placement_id := String(retired.get("placement_id", ""))
	if placement_id != "" and placement_id not in resolved:
		resolved.append(placement_id)
		session.overworld["resolved_encounters"] = resolved
	retired["target_kind"] = "commander"
	retired["target_placement_id"] = roster_hero_id if roster_hero_id != "" else placement_id
	retired["target_label"] = commander_label
	retired["target_x"] = int(retired.get("x", 0))
	retired["target_y"] = int(retired.get("y", 0))
	retired["goal_x"] = int(retired.get("x", 0))
	retired["goal_y"] = int(retired.get("y", 0))
	retired["goal_distance"] = 9999
	retired["arrived"] = false
	var reason_codes := ["risk_support_timeout", "army_consolidation", stall_code]
	if front_code != "" and front_code not in reason_codes:
		reason_codes.append(front_code)
	retired["target_reason_codes"] = reason_codes
	retired["target_public_reason"] = "falling back to rebuild"
	retired["target_public_importance"] = "high"
	retired["target_debug_reason"] = "%s: strength %d below %d after waiting %d days without support" % [
		stall_code,
		max(0, strength),
		max(0, required),
		RAID_RISK_SUPPORT_STALL_DAYS,
	]
	return retired

static func _redirect_claim_to_guard_encounter(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary,
	state: Dictionary,
	faction_id: String,
	guard_encounter: Dictionary,
	claim_kind: String
) -> Dictionary:
	if session == null or raid.is_empty() or guard_encounter.is_empty():
		return {"encounter": raid, "state": state, "event_message": ""}
	var previous_target := _current_target_snapshot(raid)
	var redirected := raid.duplicate(true)
	var guard_id := String(guard_encounter.get("placement_id", ""))
	var guard_label := String(ContentService.get_encounter(String(guard_encounter.get("encounter_id", guard_encounter.get("id", "")))).get("name", "the guard"))
	redirected["previous_target_kind"] = String(raid.get("target_kind", ""))
	redirected["previous_target_placement_id"] = String(raid.get("target_placement_id", ""))
	redirected["previous_target_label"] = String(raid.get("target_label", ""))
	redirected["guarded_claim_kind"] = claim_kind
	redirected["guarded_claim_target_id"] = String(raid.get("target_placement_id", ""))
	redirected["guarded_claim_target_label"] = String(raid.get("target_label", ""))
	redirected["target_kind"] = "encounter"
	redirected["target_placement_id"] = guard_id
	redirected["target_label"] = guard_label
	redirected["target_x"] = int(guard_encounter.get("x", 0))
	redirected["target_y"] = int(guard_encounter.get("y", 0))
	redirected["target_public_reason"] = "clearing guard before claim"
	redirected["target_public_importance"] = "high"
	redirected["target_debug_reason"] = "guarded %s claim requires guard clearance" % claim_kind
	var reason_codes := ["guard_clearance", "guarded_%s_claim" % claim_kind]
	if claim_kind == "resource":
		reason_codes.append("site_contested")
	elif claim_kind == "artifact":
		reason_codes.append("artifact_pressure")
	redirected["target_reason_codes"] = reason_codes
	redirected["arrived"] = false
	redirected["guard_claim_redirect_day"] = int(session.day)
	redirected = _refresh_target(session, redirected)
	var retask_event := ai_target_assignment_event(session, config, redirected, previous_target)
	if retask_event.is_empty():
		retask_event = ai_target_assignment_event(session, config, redirected, {})
	return {
		"encounter": redirected,
		"state": state,
		"event_message": "",
		"ai_event": retask_event,
		"guard_redirected": true,
		"guard_placement_id": guard_id,
	}

static func _redirect_raid_to_threatened_town_defense(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary,
	faction_id: String
) -> Dictionary:
	if session == null or raid.is_empty() or faction_id == "":
		return raid
	if String(raid.get("target_kind", "")) == "regroup" or raid_regroup_needed(raid):
		return raid
	var active_reason_codes := _normalize_string_array(raid.get("target_reason_codes", []))
	if "active_front_support" in active_reason_codes or "awaiting_support" in active_reason_codes or String(raid.get("supporting_front_placement_id", "")) != "":
		return raid
	var defense_town := _best_threatened_defense_town(session, config, raid, faction_id)
	if defense_town.is_empty():
		return raid
	var town_id := String(defense_town.get("placement_id", ""))
	if town_id == "":
		return raid
	var current_kind := String(raid.get("target_kind", ""))
	var current_id := String(raid.get("target_placement_id", ""))
	var current_codes := _normalize_string_array(raid.get("target_reason_codes", []))
	if current_kind == "town" and current_id == town_id and "town_defense" in current_codes:
		return _refresh_target(session, raid)
	raid["previous_target_kind"] = current_kind
	raid["previous_target_placement_id"] = current_id
	raid["previous_target_label"] = String(raid.get("target_label", ""))
	raid["target_kind"] = "town"
	raid["target_placement_id"] = town_id
	raid["target_label"] = _town_name(defense_town)
	raid["target_public_reason"] = "defending threatened town"
	raid["target_reason_codes"] = ["town_defense", "front_stabilization"]
	raid["target_public_importance"] = "high"
	raid["target_debug_reason"] = "stabilizing owned town under player threat"
	raid["arrived"] = false
	raid["town_defense_started_day"] = int(session.day)
	raid["town_defense_front_id"] = commander_role_front_id(String(session.scenario_id), "town", town_id)
	return _refresh_target(session, raid)

static func _best_threatened_defense_town(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary,
	faction_id: String
) -> Dictionary:
	var current := Vector2i(int(raid.get("x", 0)), int(raid.get("y", 0)))
	var hero_position := _primary_player_position(session)
	var best := {}
	var best_score := -999999
	var best_distance := 9999
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		if String(town.get("owner", "neutral")) != "enemy":
			continue
		if _town_faction_id(town) != faction_id:
			continue
		var front_state: Dictionary = OverworldRulesScript.town_front_state(session, town)
		if not bool(front_state.get("active", false)):
			continue
		if String(front_state.get("faction_id", "")) != faction_id:
			continue
		if String(front_state.get("mode", "")) != "stabilizing":
			continue
		var staging_tiles := _town_staging_tiles(session, town)
		var distance := _path_distance(session, current, staging_tiles, String(raid.get("placement_id", "")))
		if distance >= 9999:
			continue
		var defense_need := _town_defense_commitment_need(town, front_state)
		var current_defense := _town_garrison_strength(town)
		var committed_defense := _committed_town_defense_strength(
			session,
			faction_id,
			String(town.get("placement_id", "")),
			String(raid.get("placement_id", ""))
		)
		var open_defense_gap: int = max(0, defense_need - current_defense - committed_defense)
		if open_defense_gap <= 0:
			continue
		var town_tile := Vector2i(int(town.get("x", 0)), int(town.get("y", 0)))
		var hero_distance: int = abs(hero_position.x - town_tile.x) + abs(hero_position.y - town_tile.y)
		var score := int(front_state.get("priority_bonus", 0))
		score += int(front_state.get("garrison_bonus", 0))
		score += int(ceili(float(open_defense_gap) / 4.0))
		score += max(0, 12 - hero_distance) * 18
		score += max(0, 14 - distance) * 8
		if String(config.get("siege_target_placement_id", "")) == String(town.get("placement_id", "")):
			score += 40
		if score > best_score or (score == best_score and (distance < best_distance or (distance == best_distance and String(town.get("placement_id", "")) < String(best.get("placement_id", ""))))):
			best_score = score
			best_distance = distance
			best = town
	return best

static func _redirect_raid_to_threatened_resource_defense(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary,
	faction_id: String
) -> Dictionary:
	if session == null or raid.is_empty() or faction_id == "":
		return raid
	if String(raid.get("target_kind", "")) == "regroup" or raid_regroup_needed(raid):
		return raid
	var active_reason_codes := _normalize_string_array(raid.get("target_reason_codes", []))
	if "active_front_support" in active_reason_codes or "awaiting_support" in active_reason_codes or String(raid.get("supporting_front_placement_id", "")) != "":
		return raid
	if String(raid.get("target_kind", "")) == "town" and "town_defense" in active_reason_codes:
		return _refresh_target(session, raid)
	var defense_node := _best_threatened_resource_defense(session, config, raid, faction_id)
	if defense_node.is_empty():
		return raid
	var resource_id := String(defense_node.get("placement_id", ""))
	if resource_id == "":
		return raid
	var current_kind := String(raid.get("target_kind", ""))
	var current_id := String(raid.get("target_placement_id", ""))
	var current_codes := _normalize_string_array(raid.get("target_reason_codes", []))
	if current_kind == "resource" and current_id == resource_id and _resource_defense_reason_active(current_codes):
		return _refresh_target(session, raid)
	var site := ContentService.get_resource_site(String(defense_node.get("site_id", "")))
	raid["previous_target_kind"] = current_kind
	raid["previous_target_placement_id"] = current_id
	raid["previous_target_label"] = String(raid.get("target_label", ""))
	raid["target_kind"] = "resource"
	raid["target_placement_id"] = resource_id
	raid["target_label"] = String(site.get("name", resource_id))
	raid["target_public_reason"] = "defending held site"
	raid["target_reason_codes"] = ["site_defense", "defend_front", "front_stabilization"]
	raid["target_public_importance"] = "medium"
	raid["target_debug_reason"] = "defending owned persistent resource under player threat"
	raid["arrived"] = false
	raid["site_defense_started_day"] = int(session.day)
	raid["site_defense_front_id"] = commander_role_front_id(String(session.scenario_id), "resource", resource_id)
	return _refresh_target(session, raid)

static func _best_threatened_resource_defense(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary,
	faction_id: String
) -> Dictionary:
	var current := Vector2i(int(raid.get("x", 0)), int(raid.get("y", 0)))
	var hero_position := _primary_player_position(session)
	var best := {}
	var best_score := -999999
	var best_distance := 9999
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not _resource_site_is_persistent(site):
			continue
		if String(node.get("collected_by_faction_id", "")) != faction_id:
			continue
		var front_state := _resource_defense_front_state(session, node, site, faction_id, hero_position)
		if not bool(front_state.get("active", false)):
			continue
		var target_tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
		var distance := _path_distance(session, current, [target_tile], String(raid.get("placement_id", "")))
		if distance >= 9999:
			continue
		var defense_need := _resource_defense_commitment_need(site, front_state)
		var committed_defense := _committed_resource_defense_strength(
			session,
			faction_id,
			String(node.get("placement_id", "")),
			String(raid.get("placement_id", ""))
		)
		var open_defense_gap: int = max(0, defense_need - committed_defense)
		if open_defense_gap <= 0:
			continue
		var hero_distance: int = abs(hero_position.x - target_tile.x) + abs(hero_position.y - target_tile.y)
		var score := int(front_state.get("priority_bonus", 0))
		score += int(min(80.0, float(_resource_site_strategic_value(site)) / 40.0))
		score += int(ceili(float(open_defense_gap) / 4.0))
		score += max(0, 12 - hero_distance) * 14
		score += max(0, 14 - distance) * 7
		if String(config.get("priority_resource_placement_id", "")) == String(node.get("placement_id", "")):
			score += 30
		if score > best_score or (score == best_score and (distance < best_distance or (distance == best_distance and String(node.get("placement_id", "")) < String(best.get("placement_id", ""))))):
			best_score = score
			best_distance = distance
			best = node
	return best

static func _resource_defense_front_state(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary,
	faction_id: String,
	hero_position: Vector2i
) -> Dictionary:
	var front: Dictionary = node.get("front", {}) if node.get("front", {}) is Dictionary else {}
	var explicit := false
	var priority_bonus := 0
	var mode := ""
	if String(front.get("faction_id", faction_id)) == faction_id:
		var state := String(front.get("state", ""))
		explicit = bool(front.get("threatened_by_player", false)) or state in ["defend", "stabilizing", "threatened"]
		explicit = explicit or int(front.get("defense_until_day", 0)) >= int(session.day)
		priority_bonus = int(front.get("priority_bonus", 0))
		mode = state
	var target_tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	var hero_distance: int = abs(hero_position.x - target_tile.x) + abs(hero_position.y - target_tile.y)
	var threat_radius: int = max(4, min(8, 3 + max(0, int(site.get("pressure_guard", 0)))))
	var derived_threat := hero_distance <= threat_radius
	return {
		"active": explicit or derived_threat,
		"mode": mode if mode != "" else "nearby_player_threat",
		"priority_bonus": priority_bonus,
		"hero_distance": hero_distance,
		"threat_radius": threat_radius,
		"explicit": explicit,
	}

static func _town_defense_commitment_need(town: Dictionary, front_state: Dictionary) -> int:
	return max(
		95,
		int(front_state.get("garrison_bonus", 0)) + 55,
		int(round(float(int(front_state.get("priority_bonus", 0))) * 0.75)),
		int(town.get("ai_defense_rating", 0))
	)

static func _resource_defense_commitment_need(site: Dictionary, front_state: Dictionary) -> int:
	return max(
		70,
		int(front_state.get("priority_bonus", 0)),
		int(round(float(_resource_site_strategic_value(site)) / 30.0))
	)

static func _committed_town_defense_strength(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	town_id: String,
	current_placement_id: String
) -> int:
	if session == null or faction_id == "" or town_id == "":
		return 0
	var total := 0
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter_value in session.overworld.get("encounters", []):
		if not _is_active_raid(encounter_value, faction_id, resolved_encounters):
			continue
		var encounter: Dictionary = encounter_value
		if String(encounter.get("placement_id", "")) == current_placement_id:
			continue
		if String(encounter.get("target_kind", "")) != "town":
			continue
		if String(encounter.get("target_placement_id", "")) != town_id:
			continue
		var reason_codes := _normalize_string_array(encounter.get("target_reason_codes", []))
		if "town_defense" not in reason_codes and "front_stabilization" not in reason_codes:
			continue
		total += raid_strength(encounter)
	return total

static func _committed_resource_defense_strength(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	resource_id: String,
	current_placement_id: String
) -> int:
	if session == null or faction_id == "" or resource_id == "":
		return 0
	var total := 0
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter_value in session.overworld.get("encounters", []):
		if not _is_active_raid(encounter_value, faction_id, resolved_encounters):
			continue
		var encounter: Dictionary = encounter_value
		if String(encounter.get("placement_id", "")) == current_placement_id:
			continue
		if String(encounter.get("target_kind", "")) != "resource":
			continue
		if String(encounter.get("target_placement_id", "")) != resource_id:
			continue
		if not _resource_defense_reason_active(_normalize_string_array(encounter.get("target_reason_codes", []))):
			continue
		total += raid_strength(encounter)
	return total

static func _primary_player_position(session: SessionStateStoreScript.SessionData) -> Vector2i:
	var hero_position = session.overworld.get("hero_position", {"x": 0, "y": 0})
	if hero_position is Dictionary:
		return Vector2i(int(hero_position.get("x", 0)), int(hero_position.get("y", 0)))
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	if active_hero_id != "":
		var hero := _find_player_hero(session, active_hero_id)
		if not hero.is_empty():
			return _hero_position_for_target(session, active_hero_id)
	return Vector2i(0, 0)

static func _nearest_regroup_town(
	session: SessionStateStoreScript.SessionData,
	raid: Dictionary,
	faction_id: String
) -> Dictionary:
	var current := Vector2i(int(raid.get("x", 0)), int(raid.get("y", 0)))
	var fallback := {}
	var fallback_distance := 9999
	var best_reinforcement := {}
	var best_reinforcement_distance := 9999
	var best_reinforcement_strength := 0
	var best_reinforcement_covers_need := false
	var strength_needed: int = max(0, desired_raid_strength(raid) - raid_strength(raid))
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		if String(town.get("owner", "neutral")) != "enemy":
			continue
		if _town_faction_id(town) != faction_id:
			continue
		var tile := Vector2i(int(town.get("x", 0)), int(town.get("y", 0)))
		var distance := _path_distance(session, current, [tile], String(raid.get("placement_id", "")))
		if distance >= 9999:
			continue
		if distance < fallback_distance or (distance == fallback_distance and String(town.get("placement_id", "")) < String(fallback.get("placement_id", ""))):
			fallback_distance = distance
			fallback = town
		var reinforcement_strength := _town_garrison_strength(town)
		if reinforcement_strength <= 0:
			continue
		var covers_need := strength_needed <= 0 or reinforcement_strength >= strength_needed
		var beats_current := best_reinforcement.is_empty()
		if not beats_current and covers_need != best_reinforcement_covers_need:
			beats_current = covers_need
		elif not beats_current and covers_need:
			beats_current = distance < best_reinforcement_distance or (
				distance == best_reinforcement_distance
				and String(town.get("placement_id", "")) < String(best_reinforcement.get("placement_id", ""))
			)
		elif not beats_current:
			beats_current = reinforcement_strength > best_reinforcement_strength or (
				reinforcement_strength == best_reinforcement_strength
				and (
					distance < best_reinforcement_distance
					or (
						distance == best_reinforcement_distance
						and String(town.get("placement_id", "")) < String(best_reinforcement.get("placement_id", ""))
					)
				)
			)
		if beats_current:
			best_reinforcement = town
			best_reinforcement_distance = distance
			best_reinforcement_strength = reinforcement_strength
			best_reinforcement_covers_need = covers_need
	if not best_reinforcement.is_empty():
		return best_reinforcement
	return fallback

static func _town_garrison_strength(town: Dictionary) -> int:
	var garrison = town.get("garrison", [])
	return _army_strength(garrison if garrison is Array else [])

static func normalize_raid_armies(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	var encounters = session.overworld.get("encounters", [])
	var normalized = []
	var changed = false
	var occupied_commander_ids: Dictionary = {}
	for encounter_value in encounters:
		if not (encounter_value is Dictionary):
			continue
		var existing_commander = encounter_value.get("enemy_commander_state", {})
		if not (existing_commander is Dictionary):
			continue
		var roster_hero_id := String(existing_commander.get("roster_hero_id", ""))
		if roster_hero_id != "":
			occupied_commander_ids[roster_hero_id] = true
	for encounter_value in encounters:
		if not (encounter_value is Dictionary):
			normalized.append(encounter_value)
			continue
		var encounter = encounter_value
		if String(encounter.get("spawned_by_faction_id", "")) != "":
			var previous_army = encounter.get("enemy_army", {})
			var previous_commander = encounter.get("enemy_commander_state", {})
			encounter = ensure_raid_army(encounter, session, occupied_commander_ids)
			var roster_hero_id := String(encounter.get("enemy_commander_state", {}).get("roster_hero_id", ""))
			if roster_hero_id != "":
				occupied_commander_ids[roster_hero_id] = true
			if encounter.get("enemy_army", {}) != previous_army or encounter.get("enemy_commander_state", {}) != previous_commander:
				changed = true
		normalized.append(encounter)
	if changed:
		session.overworld["encounters"] = normalized

static func normalize_all_commander_rosters(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	_normalize_town_defender_commander_states(session)
	var states = session.overworld.get("enemy_states", [])
	if not (states is Array):
		return
	var changed := false
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary):
			continue
		var faction_id := String(state.get("faction_id", ""))
		if faction_id == "":
			continue
		var normalized_roster = normalize_commander_roster(
			session,
			faction_id,
			state.get("commander_roster", [])
		)
		if state.get("commander_roster", []) != normalized_roster:
			state["commander_roster"] = normalized_roster
			states[index] = state
			changed = true
	if changed:
		session.overworld["enemy_states"] = states

static func normalize_commander_roster(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_value: Variant
) -> Array:
	var existing_map: Dictionary = {}
	if roster_value is Array:
		for entry_value in roster_value:
			if not (entry_value is Dictionary):
				continue
			var roster_hero_id := String(entry_value.get("roster_hero_id", ""))
			if roster_hero_id == "":
				continue
			existing_map[roster_hero_id] = entry_value
	var active_map = _active_commander_map(session, faction_id)
	var normalized := []
	var session_day := int(session.day) if session != null else 0
	for roster_hero_id in _faction_commander_ids(faction_id):
		var existing = existing_map.get(roster_hero_id, {})
		if not (existing is Dictionary):
			existing = {}
		var active_entry: Dictionary = active_map.get(roster_hero_id, {})
		var active_commander_state = active_entry.get("commander_state", {})
		if not (active_commander_state is Dictionary):
			active_commander_state = {}
		var commander_seed = (
			active_commander_state
			if not active_commander_state.is_empty()
			else existing.get("commander_state", {})
		)
		var record := _normalized_commander_record(existing, commander_seed)
		var target_memory := _normalized_commander_memory(existing, commander_seed)
		var army_continuity := _normalized_commander_army_continuity(existing, commander_seed)
		var commander_state = build_roster_commander_state(
			roster_hero_id,
			faction_id,
			commander_seed,
			{
				"record": record,
				"target_memory": target_memory,
				"army_continuity": army_continuity,
			}
		)
		var entry := {
			"roster_hero_id": roster_hero_id,
			"status": COMMANDER_STATUS_AVAILABLE,
			"active_placement_id": "",
			"recovery_day": 0,
			"last_outcome": String(existing.get("last_outcome", commander_state.get("last_outcome", ""))),
			"deployments": max(0, int(record.get("deployments", 0))),
			"battle_wins": max(0, int(record.get("battle_wins", 0))),
			"times_defeated": max(0, int(record.get("times_defeated", 0))),
			"strategic_successes": max(0, int(record.get("strategic_successes", 0))),
			"renown": max(0, int(record.get("renown", 0))),
			"target_memory": target_memory,
			"army_continuity": commander_army_continuity(commander_state),
			"commander_state": commander_state,
		}
		if active_map.has(roster_hero_id):
			entry["status"] = COMMANDER_STATUS_ACTIVE
			entry["active_placement_id"] = String(active_entry.get("placement_id", ""))
		else:
			var existing_status: String = _normalize_commander_status(
				existing.get("status", COMMANDER_STATUS_AVAILABLE)
			)
			var recovery_day: int = max(0, int(existing.get("recovery_day", 0)))
			if existing_status == COMMANDER_STATUS_RECOVERING and recovery_day > session_day:
				entry["status"] = COMMANDER_STATUS_RECOVERING
				entry["recovery_day"] = recovery_day
		normalized.append(entry)
	return normalized

static func commander_roster_for_faction(
	session: SessionStateStoreScript.SessionData,
	faction_id: String
) -> Array:
	if session == null or faction_id == "":
		return []
	for state in session.overworld.get("enemy_states", []):
		if not (state is Dictionary):
			continue
		if String(state.get("faction_id", "")) != faction_id:
			continue
		var roster = state.get("commander_roster", [])
		return roster if roster is Array else []
	return []

static func commander_renown(source: Variant) -> int:
	return max(0, int(_normalized_commander_record(source).get("renown", 0)))

static func commander_veterancy_label(source: Variant) -> String:
	return String(
		COMMANDER_VETERANCY_LABELS[
			clamp(_commander_veterancy_rank_from_record(_normalized_commander_record(source)), 0, COMMANDER_VETERANCY_LABELS.size() - 1)
		]
	)

static func commander_display_name(source: Variant, include_veterancy: bool = true) -> String:
	var commander_name := _commander_name_from_source(source)
	if commander_name == "":
		return ""
	var veterancy := commander_veterancy_label(source)
	if include_veterancy and veterancy != "":
		return "%s %s" % [veterancy, commander_name]
	return commander_name

static func commander_record_summary(source: Variant) -> String:
	var record := _normalized_commander_record(source)
	var deployments: int = max(0, int(record.get("deployments", 0)))
	var wins: int = max(0, int(record.get("battle_wins", 0)))
	var defeats: int = max(0, int(record.get("times_defeated", 0)))
	var strategic_successes: int = max(0, int(record.get("strategic_successes", 0)))
	if deployments <= 0 and wins <= 0 and defeats <= 0 and strategic_successes <= 0:
		return ""
	var parts := []
	var veterancy := commander_veterancy_label(record)
	if veterancy != "":
		parts.append(veterancy)
	parts.append("%d raid%s" % [deployments, "" if deployments == 1 else "s"])
	if wins > 0:
		parts.append("%d win%s" % [wins, "" if wins == 1 else "s"])
	if strategic_successes > 0:
		parts.append("%d objective%s" % [strategic_successes, "" if strategic_successes == 1 else "s"])
	if defeats > 0:
		parts.append("%d defeat%s" % [defeats, "" if defeats == 1 else "s"])
	elif wins > 0:
		parts.append("undefeated")
	return " | ".join(parts)

static func commander_target_memory(source: Variant) -> Dictionary:
	return _normalized_commander_memory(source)

static func commander_memory_brief(source: Variant) -> String:
	var memory := _normalized_commander_memory(source)
	if memory.is_empty():
		return ""
	var rival_label := String(memory.get("rival_label", ""))
	var rivalry_count: int = max(0, int(memory.get("rivalry_count", 0)))
	if rival_label != "" and rivalry_count >= 2:
		return "holds a grudge against %s" % rival_label
	var focus_label := String(memory.get("focus_target_label", ""))
	var focus_count: int = max(0, int(memory.get("focus_pressure_count", 0)))
	if focus_label != "" and focus_count >= 2:
		return "returns to %s" % focus_label
	return ""

static func commander_memory_summary(source: Variant) -> String:
	var memory := _normalized_commander_memory(source)
	if memory.is_empty():
		return ""
	var parts := []
	var focus_label := String(memory.get("focus_target_label", ""))
	var focus_count: int = max(0, int(memory.get("focus_pressure_count", 0)))
	if focus_label != "":
		var focus_summary := "Target %s" % focus_label
		if focus_count > 1:
			focus_summary += " (%d raids)" % focus_count
		parts.append(focus_summary)
	var rival_label := String(memory.get("rival_label", ""))
	var rivalry_count: int = max(0, int(memory.get("rivalry_count", 0)))
	if rival_label != "":
		var rival_summary := "Rival %s" % rival_label
		if rivalry_count > 1:
			rival_summary += " x%d" % rivalry_count
		parts.append(rival_summary)
	return " | ".join(parts)

static func commander_army_continuity(source: Variant) -> Dictionary:
	return _normalized_commander_army_continuity(source)

static func commander_army_status(source: Variant) -> String:
	return String(_normalized_commander_army_continuity(source).get("status", ""))

static func commander_army_brief(source: Variant) -> String:
	match commander_army_status(source):
		"shattered":
			return "shattered host"
		"rebuilding":
			return "rebuilding host"
		"scarred":
			return "scarred host"
	return ""

static func commander_recent_outcome_brief(source: Variant) -> String:
	match String(_normalized_commander_record(source).get("last_outcome", "")):
		COMMANDER_OUTCOME_ROUT_VICTORY:
			return "fresh from a rout"
		COMMANDER_OUTCOME_PURSUIT_VICTORY:
			return "driving a hard pursuit"
		COMMANDER_OUTCOME_CAPITULATION:
			return "flush with surrender terms"
		_:
			return ""

static func commander_army_summary(source: Variant) -> String:
	return String(_normalized_commander_army_continuity(source).get("summary", ""))

static func commander_can_deploy(source: Variant) -> bool:
	var continuity := _normalized_commander_army_continuity(source)
	if continuity.is_empty() or int(continuity.get("base_strength", 0)) <= 0:
		return true
	var current_strength: int = max(0, int(continuity.get("current_strength", 0)))
	if current_strength <= 0:
		return false
	var base_strength: int = max(1, int(continuity.get("base_strength", 0)))
	var deploy_floor: int = max(45, int(round(float(base_strength) * 0.55)))
	return current_strength >= deploy_floor

static func raid_commander_memory_summaries(encounters: Array, limit: int = 2) -> Array:
	var summaries: Array = []
	for encounter in encounters:
		if not (encounter is Dictionary):
			continue
		var commander_name := raid_commander_display_name(encounter)
		var memory_brief := commander_memory_brief(encounter.get("enemy_commander_state", {}))
		if commander_name == "" or memory_brief == "":
			continue
		var summary := "%s %s" % [commander_name, memory_brief]
		if summary in summaries:
			continue
		summaries.append(summary)
		if limit > 0 and summaries.size() >= limit:
			break
	return summaries

static func has_available_raid_commander(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_value: Variant = []
) -> bool:
	for entry_value in normalize_commander_roster(
		session,
		faction_id,
		roster_value if roster_value is Array else commander_roster_for_faction(session, faction_id)
	):
		if not (entry_value is Dictionary):
			continue
		if (
			_normalize_commander_status(entry_value.get("status", COMMANDER_STATUS_AVAILABLE)) == COMMANDER_STATUS_AVAILABLE
			and commander_can_deploy(entry_value)
		):
			return true
	return false

static func recovering_commander_count(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_value: Variant = []
) -> int:
	var count := 0
	for entry_value in normalize_commander_roster(
		session,
		faction_id,
		roster_value if roster_value is Array else commander_roster_for_faction(session, faction_id)
	):
		if not (entry_value is Dictionary):
			continue
		if _normalize_commander_status(entry_value.get("status", COMMANDER_STATUS_AVAILABLE)) == COMMANDER_STATUS_RECOVERING:
			count += 1
	return count

static func rebuilding_commander_count(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_value: Variant = []
) -> int:
	var count := 0
	for entry_value in normalize_commander_roster(
		session,
		faction_id,
		roster_value if roster_value is Array else commander_roster_for_faction(session, faction_id)
	):
		if not (entry_value is Dictionary):
			continue
		var status := _normalize_commander_status(entry_value.get("status", COMMANDER_STATUS_AVAILABLE))
		if status in [COMMANDER_STATUS_ACTIVE, COMMANDER_STATUS_RECOVERING]:
			continue
		var continuity := commander_army_continuity(entry_value)
		if continuity.is_empty() or int(continuity.get("base_strength", 0)) <= 0 or commander_can_deploy(entry_value):
			continue
		count += 1
	return count

static func public_commander_recovery_summary(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_value: Variant = []
) -> String:
	var session_day := int(session.day) if session != null else 0
	var recovering := []
	for entry_value in normalize_commander_roster(
		session,
		faction_id,
		roster_value if roster_value is Array else commander_roster_for_faction(session, faction_id)
	):
		if not (entry_value is Dictionary):
			continue
		if _normalize_commander_status(entry_value.get("status", COMMANDER_STATUS_AVAILABLE)) != COMMANDER_STATUS_RECOVERING:
			continue
		var recovery_day: int = max(0, int(entry_value.get("recovery_day", 0)))
		var remaining_days: int = max(1, recovery_day - session_day)
		var commander_name := commander_display_name(entry_value)
		if commander_name == "":
			continue
		var descriptor := "%dd" % remaining_days
		var army_brief := commander_army_brief(entry_value)
		if army_brief != "":
			descriptor += ", %s" % army_brief
		recovering.append("%s (%s)" % [commander_name, descriptor])
		if recovering.size() >= 2:
			break
	if recovering.is_empty():
		return ""
	var summary := "Command recovering %s" % ", ".join(recovering)
	var total_recovering := recovering_commander_count(
		session,
		faction_id,
		roster_value if roster_value is Array else commander_roster_for_faction(session, faction_id)
	)
	if total_recovering > recovering.size():
		summary += " (+%d more)" % (total_recovering - recovering.size())
	return summary

static func public_commander_rebuild_summary(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_value: Variant = []
) -> String:
	var rebuilding := []
	for entry_value in normalize_commander_roster(
		session,
		faction_id,
		roster_value if roster_value is Array else commander_roster_for_faction(session, faction_id)
	):
		if not (entry_value is Dictionary):
			continue
		var status := _normalize_commander_status(entry_value.get("status", COMMANDER_STATUS_AVAILABLE))
		if status in [COMMANDER_STATUS_ACTIVE, COMMANDER_STATUS_RECOVERING]:
			continue
		if commander_can_deploy(entry_value):
			continue
		var commander_name := commander_display_name(entry_value)
		var army_summary := commander_army_summary(entry_value)
		if commander_name == "" or army_summary == "":
			continue
		rebuilding.append("%s (%s)" % [commander_name, army_summary])
		if rebuilding.size() >= 2:
			break
	if rebuilding.is_empty():
		return ""
	var summary := "Command rebuilding %s" % ", ".join(rebuilding)
	var total_rebuilding := rebuilding_commander_count(
		session,
		faction_id,
		roster_value if roster_value is Array else commander_roster_for_faction(session, faction_id)
	)
	if total_rebuilding > rebuilding.size():
		summary += " (+%d more)" % (total_rebuilding - rebuilding.size())
	return summary

static func apply_resolved_commander_aftermath(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	commander_state: Variant,
	outcome_id: String
) -> String:
	if session == null or faction_id == "" or not (commander_state is Dictionary):
		return ""
	var roster_hero_id := String(commander_state.get("roster_hero_id", ""))
	if roster_hero_id == "":
		return ""
	var states = session.overworld.get("enemy_states", [])
	if not (states is Array):
		return ""
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary) or String(state.get("faction_id", "")) != faction_id:
			continue
		var roster = normalize_commander_roster(session, faction_id, state.get("commander_roster", []))
		for roster_index in range(roster.size()):
			var entry = roster[roster_index]
			if not (entry is Dictionary) or String(entry.get("roster_hero_id", "")) != roster_hero_id:
				continue
			var updated_state := advance_commander_record(commander_state, outcome_id)
			if outcome_id == COMMANDER_OUTCOME_DEFEATED:
				var continuity := commander_army_continuity(updated_state)
				var defeated_encounter_id := String(continuity.get("encounter_id", ""))
				if defeated_encounter_id == "":
					defeated_encounter_id = String(commander_army_continuity(commander_state).get("encounter_id", ""))
				updated_state = sync_commander_army_continuity(updated_state, {"stacks": []}, defeated_encounter_id)
			entry["status"] = COMMANDER_STATUS_RECOVERING
			entry["active_placement_id"] = ""
			entry["last_outcome"] = outcome_id
			entry["deployments"] = max(0, int(updated_state.get("deployments", entry.get("deployments", 0))))
			entry["battle_wins"] = max(0, int(updated_state.get("battle_wins", entry.get("battle_wins", 0))))
			entry["times_defeated"] = max(0, int(updated_state.get("times_defeated", entry.get("times_defeated", 0))))
			entry["strategic_successes"] = max(0, int(updated_state.get("strategic_successes", entry.get("strategic_successes", 0))))
			entry["renown"] = commander_renown(updated_state)
			entry["commander_state"] = build_roster_commander_state(
				roster_hero_id,
				faction_id,
				updated_state,
				entry
			)
			entry["target_memory"] = commander_target_memory(entry.get("commander_state", {}))
			entry["army_continuity"] = commander_army_continuity(entry.get("commander_state", {}))
			var recovery_days := 0
			var summary := ""
			match outcome_id:
				COMMANDER_OUTCOME_DEFEATED:
					recovery_days = COMMANDER_RECOVERY_DAYS_DEFEATED
					summary = "%s is routed and cannot lead another raid for %d day%s." % [
						commander_display_name(entry),
						recovery_days,
						"" if recovery_days == 1 else "s",
					]
				COMMANDER_OUTCOME_ASSAULT_VICTORY:
					recovery_days = COMMANDER_RECOVERY_DAYS_ASSAULT_VICTORY
					summary = "%s is consolidating the breach and will not return for %d day%s." % [
						commander_display_name(entry),
						recovery_days,
						"" if recovery_days == 1 else "s",
					]
				_:
					entry["status"] = COMMANDER_STATUS_AVAILABLE
			entry["recovery_day"] = int(session.day) + recovery_days if recovery_days > 0 else 0
			roster[roster_index] = entry
			state["commander_roster"] = roster
			states[index] = state
			session.overworld["enemy_states"] = states
			return summary
	return ""

static func build_roster_commander_state(
	roster_hero_id: String,
	faction_id: String,
	existing_state: Dictionary = {},
	record_source: Variant = {}
) -> Dictionary:
	var hero_template = ContentService.get_hero(roster_hero_id)
	var record_value: Variant = record_source.get("record", record_source) if record_source is Dictionary else record_source
	var record := _normalized_commander_record(record_value, existing_state)
	var target_memory := _normalized_commander_memory(record_source, existing_state)
	var army_continuity := _normalized_commander_army_continuity(record_source, existing_state)
	var existing_spellbook = existing_state.get("spellbook", {})
	if not (existing_spellbook is Dictionary):
		existing_spellbook = {}
	var command_source = existing_state.get("command", hero_template.get("command", {}))
	var battle_traits_source = _merge_unique_strings(
		existing_state.get("battle_traits", []),
		hero_template.get("battle_traits", [])
	)
	var existing_specialties = existing_state.get("specialties", [])
	var specialties_source = _normalized_specialty_ranks(
		existing_specialties if existing_specialties is Array and not existing_specialties.is_empty() else hero_template.get("starting_specialties", [])
	)
	var specialty_focus_source = _normalized_specialty_focus_ids(
		_merge_unique_strings(
			existing_state.get("specialty_focus_ids", []),
			hero_template.get("specialty_focus_ids", [])
		)
	)
	var spell_ids_source = _merge_unique_strings(
		existing_spellbook.get("known_spell_ids", []),
		_hero_starting_spell_ids(hero_template)
	)
	var artifacts_source = existing_state.get(
		"artifacts",
		record_source.get("artifacts", {}) if record_source is Dictionary else {}
	)
	var commander_state = {
		"id": String(existing_state.get("id", "enemy_commander:%s:%s" % [faction_id, roster_hero_id])),
		"roster_hero_id": roster_hero_id,
		"faction_id": faction_id,
		"name": String(existing_state.get("name", hero_template.get("name", "Enemy Commander"))),
		"archetype": String(existing_state.get("archetype", hero_template.get("archetype", ""))),
		"identity_summary": String(
			existing_state.get("identity_summary", hero_template.get("identity_summary", ""))
		),
		"command": _normalize_command_payload(command_source),
		"battle_traits": battle_traits_source,
		"specialties": specialties_source,
		"specialty_focus_ids": specialty_focus_source,
		"level": max(1, int(existing_state.get("level", 1))),
		"experience": max(0, int(existing_state.get("experience", 0))),
		"next_level_experience": max(250, int(existing_state.get("next_level_experience", 250))),
		"pending_specialty_choices": existing_state.get("pending_specialty_choices", []),
		"last_outcome": String(existing_state.get("last_outcome", record.get("last_outcome", ""))),
		"artifacts": ArtifactRulesScript.normalize_hero_artifacts(artifacts_source),
	}
	commander_state = _normalize_enemy_progression(commander_state)
	return _apply_commander_army_metadata(
		_apply_commander_record_metadata(
			_apply_commander_memory_metadata(
				SpellRulesScript.refresh_daily_mana(
					SpellRulesScript.ensure_hero_spellbook(
						commander_state,
						{
							"command": commander_state.get("command", {}),
							"starting_spell_ids": spell_ids_source,
						}
					)
				),
				target_memory
			),
			record
		),
		army_continuity
	)

static func advance_commander_record(commander_state: Dictionary, outcome_id: String) -> Dictionary:
	if commander_state.is_empty():
		return {}
	var updated := commander_state.duplicate(true)
	var record := _normalized_commander_record({}, updated)
	record["last_outcome"] = outcome_id
	match outcome_id:
		COMMANDER_OUTCOME_DEPLOYED:
			record["deployments"] = int(record.get("deployments", 0)) + 1
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_DEPLOYED)
		COMMANDER_OUTCOME_FIELD_VICTORY:
			record["battle_wins"] = int(record.get("battle_wins", 0)) + 1
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_FIELD_VICTORY)
		COMMANDER_OUTCOME_PURSUIT_VICTORY:
			record["battle_wins"] = int(record.get("battle_wins", 0)) + 1
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_PURSUIT_VICTORY)
		COMMANDER_OUTCOME_CAPITULATION:
			record["battle_wins"] = int(record.get("battle_wins", 0)) + 1
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_CAPITULATION)
		COMMANDER_OUTCOME_ROUT_VICTORY:
			record["battle_wins"] = int(record.get("battle_wins", 0)) + 1
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_ROUT_VICTORY)
		COMMANDER_OUTCOME_ASSAULT_VICTORY:
			record["battle_wins"] = int(record.get("battle_wins", 0)) + 1
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_ASSAULT_VICTORY)
		COMMANDER_OUTCOME_DEFEATED:
			record["times_defeated"] = int(record.get("times_defeated", 0)) + 1
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_DEFEATED)
		COMMANDER_OUTCOME_STALEMATE:
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_STALEMATE)
		COMMANDER_OUTCOME_RESOURCE_SECURED:
			record["strategic_successes"] = int(record.get("strategic_successes", 0)) + 1
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_RESOURCE_SECURED)
		COMMANDER_OUTCOME_ARTIFACT_SECURED:
			record["strategic_successes"] = int(record.get("strategic_successes", 0)) + 1
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_ARTIFACT_SECURED)
		COMMANDER_OUTCOME_OBJECTIVE_SECURED:
			record["strategic_successes"] = int(record.get("strategic_successes", 0)) + 1
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_OBJECTIVE_SECURED)
		COMMANDER_OUTCOME_TOWN_CAPTURED:
			record["strategic_successes"] = int(record.get("strategic_successes", 0)) + 1
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_OBJECTIVE_SECURED)
		COMMANDER_OUTCOME_SITE_DEFENDED:
			record["strategic_successes"] = int(record.get("strategic_successes", 0)) + 1
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_SITE_DEFENDED)
		COMMANDER_OUTCOME_TOWN_DEFENDED:
			record["strategic_successes"] = int(record.get("strategic_successes", 0)) + 1
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_TOWN_DEFENDED)
		_:
			updated = _normalize_enemy_progression(updated)
	updated["last_outcome"] = outcome_id
	var spellbook = updated.get("spellbook", {})
	if not (spellbook is Dictionary):
		spellbook = {}
	return _apply_commander_army_metadata(
		_apply_commander_record_metadata(
			_apply_commander_memory_metadata(
				SpellRulesScript.ensure_hero_spellbook(
					updated,
					{
						"command": updated.get("command", {}),
						"starting_spell_ids": spellbook.get("known_spell_ids", []),
					}
				),
				updated
			),
			record
		),
		updated
	)

static func record_commander_deployment(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_hero_id: String,
	roster_value: Variant = [],
	placement_id: String = ""
) -> Array:
	var roster = normalize_commander_roster(
		session,
		faction_id,
		roster_value if roster_value is Array else commander_roster_for_faction(session, faction_id)
	)
	for roster_index in range(roster.size()):
		var entry = roster[roster_index]
		if not (entry is Dictionary) or String(entry.get("roster_hero_id", "")) != roster_hero_id:
			continue
		var updated_state := advance_commander_record(
			entry.get("commander_state", {}),
			COMMANDER_OUTCOME_DEPLOYED
		)
		entry["status"] = COMMANDER_STATUS_ACTIVE if placement_id != "" else COMMANDER_STATUS_AVAILABLE
		entry["active_placement_id"] = placement_id
		entry["recovery_day"] = 0
		entry["last_outcome"] = COMMANDER_OUTCOME_DEPLOYED
		entry["deployments"] = max(0, int(updated_state.get("deployments", entry.get("deployments", 0))))
		entry["battle_wins"] = max(0, int(updated_state.get("battle_wins", entry.get("battle_wins", 0))))
		entry["times_defeated"] = max(0, int(updated_state.get("times_defeated", entry.get("times_defeated", 0))))
		entry["strategic_successes"] = max(0, int(updated_state.get("strategic_successes", entry.get("strategic_successes", 0))))
		entry["renown"] = commander_renown(updated_state)
		entry["commander_state"] = build_roster_commander_state(
			roster_hero_id,
			faction_id,
			updated_state,
			entry
		)
		entry["target_memory"] = commander_target_memory(entry.get("commander_state", {}))
		entry["army_continuity"] = commander_army_continuity(entry.get("commander_state", {}))
		roster[roster_index] = entry
		break
	return roster

static func sync_commander_state_to_roster(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	commander_state: Variant,
	status_override: String = "",
	active_placement_id: String = "",
	recovery_day: int = -1,
	last_outcome: String = ""
) -> void:
	if session == null or faction_id == "" or not (commander_state is Dictionary):
		return
	var roster_hero_id := String(commander_state.get("roster_hero_id", ""))
	if roster_hero_id == "":
		return
	var states = session.overworld.get("enemy_states", [])
	if not (states is Array):
		return
	for state_index in range(states.size()):
		var state = states[state_index]
		if not (state is Dictionary) or String(state.get("faction_id", "")) != faction_id:
			continue
		var roster = normalize_commander_roster(session, faction_id, state.get("commander_roster", []))
		for roster_index in range(roster.size()):
			var entry = roster[roster_index]
			if not (entry is Dictionary) or String(entry.get("roster_hero_id", "")) != roster_hero_id:
				continue
			var record := _normalized_commander_record(entry, commander_state)
			entry["deployments"] = max(0, int(record.get("deployments", 0)))
			entry["battle_wins"] = max(0, int(record.get("battle_wins", 0)))
			entry["times_defeated"] = max(0, int(record.get("times_defeated", 0)))
			entry["strategic_successes"] = max(0, int(record.get("strategic_successes", 0)))
			entry["renown"] = max(0, int(record.get("renown", 0)))
			if status_override != "":
				entry["status"] = _normalize_commander_status(status_override)
			if active_placement_id != "":
				entry["active_placement_id"] = active_placement_id
			elif status_override in [COMMANDER_STATUS_AVAILABLE, COMMANDER_STATUS_RECOVERING]:
				entry["active_placement_id"] = ""
			if status_override == COMMANDER_STATUS_ACTIVE and recovery_day < 0:
				entry["recovery_day"] = 0
			if recovery_day >= 0:
				entry["recovery_day"] = recovery_day
			if last_outcome != "":
				entry["last_outcome"] = last_outcome
			entry["commander_state"] = build_roster_commander_state(
				roster_hero_id,
				faction_id,
				commander_state,
				entry
			)
			entry["target_memory"] = commander_target_memory(entry.get("commander_state", {}))
			entry["army_continuity"] = commander_army_continuity(entry.get("commander_state", {}))
			roster[roster_index] = entry
			state["commander_roster"] = roster
			states[state_index] = state
			session.overworld["enemy_states"] = states
			return

static func _record_adventure_objective_success(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	raid: Dictionary,
	outcome_id: String,
	active_placement_id: String = ""
) -> Dictionary:
	var updated_raid := raid.duplicate(true)
	var commander_state = updated_raid.get("enemy_commander_state", {})
	if not (commander_state is Dictionary) or commander_state.is_empty():
		return updated_raid
	var updated_commander := advance_commander_record(commander_state, outcome_id)
	updated_raid["enemy_commander_state"] = updated_commander
	var placement_id := active_placement_id
	if placement_id == "":
		placement_id = String(updated_raid.get("placement_id", ""))
	sync_commander_state_to_roster(
		session,
		faction_id,
		updated_commander,
		COMMANDER_STATUS_ACTIVE,
		placement_id,
		-1,
		outcome_id
	)
	return updated_raid

static func reinforce_commander_roster_army(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_hero_id: String,
	unit_id: String,
	count: int,
	base_encounter_id: String = "",
	target_strength: int = 0
) -> int:
	if session == null or faction_id == "" or roster_hero_id == "" or unit_id == "" or count <= 0:
		return 0
	var states = session.overworld.get("enemy_states", [])
	if not (states is Array):
		return 0
	for state_index in range(states.size()):
		var state = states[state_index]
		if not (state is Dictionary) or String(state.get("faction_id", "")) != faction_id:
			continue
		var roster = normalize_commander_roster(session, faction_id, state.get("commander_roster", []))
		for roster_index in range(roster.size()):
			var entry = roster[roster_index]
			if not (entry is Dictionary) or String(entry.get("roster_hero_id", "")) != roster_hero_id:
				continue
			if _normalize_commander_status(entry.get("status", COMMANDER_STATUS_AVAILABLE)) == COMMANDER_STATUS_ACTIVE:
				return 0
			var commander_state = entry.get("commander_state", {})
			if not (commander_state is Dictionary) or commander_state.is_empty():
				return 0
			var continuity: Dictionary = _normalized_commander_army_continuity(entry, commander_state)
			var continuity_stacks: Array = continuity.get("stacks", []) if continuity.get("stacks", []) is Array else []
			var resolved_encounter_id := String(continuity.get("encounter_id", base_encounter_id))
			var base_strength: int = max(0, int(continuity.get("base_strength", 0)))
			if continuity_stacks.is_empty() and base_encounter_id != "":
				var base_army := _base_enemy_army(base_encounter_id)
				continuity_stacks = base_army.get("stacks", []) if base_army.get("stacks", []) is Array else []
				base_strength = max(base_strength, _army_strength(continuity_stacks))
				resolved_encounter_id = base_encounter_id
			var current_strength: int = _army_strength(continuity_stacks)
			var desired_strength: int = max(base_strength, int(target_strength))
			var rebuild_need: int = max(0, desired_strength - current_strength)
			if rebuild_need <= 0:
				return 0
			var per_unit_strength: int = max(1, _unit_strength_value(unit_id))
			var accepted: int = min(count, max(1, int(ceili(float(rebuild_need) / float(per_unit_strength)))))
			var reinforced_stacks: Array = _add_army_stack(continuity_stacks, unit_id, accepted)
			var updated_state := sync_commander_army_continuity(
				commander_state,
				{"stacks": reinforced_stacks},
				resolved_encounter_id
			)
			entry["commander_state"] = build_roster_commander_state(
				roster_hero_id,
				faction_id,
				updated_state,
				entry
			)
			entry["target_memory"] = commander_target_memory(entry.get("commander_state", {}))
			entry["army_continuity"] = commander_army_continuity(entry.get("commander_state", {}))
			roster[roster_index] = entry
			state["commander_roster"] = roster
			states[state_index] = state
			session.overworld["enemy_states"] = states
			return accepted
	return 0

static func ensure_raid_army(
	encounter: Dictionary,
	session: SessionStateStoreScript.SessionData = null,
	occupied_commander_ids: Dictionary = {}
) -> Dictionary:
	if encounter.is_empty():
		return encounter
	var encounter_id = String(encounter.get("encounter_id", encounter.get("id", "")))
	var commander_state := {}
	if String(encounter.get("spawned_by_faction_id", "")) != "" and not bool(encounter.get("commanderless_support_column", false)):
		commander_state = build_raid_commander_state(
			encounter,
			"",
			"",
			session,
			occupied_commander_ids,
			commander_roster_for_faction(session, String(encounter.get("spawned_by_faction_id", "")))
		)
	var normalized_army = _normalize_army_payload(encounter.get("enemy_army", {}))
	if normalized_army.is_empty():
		var continuity_army = _normalize_army_payload(
			{"stacks": commander_army_continuity(commander_state).get("stacks", [])}
		)
		if not continuity_army.is_empty():
			normalized_army = {
				"id": String(encounter.get("enemy_army", {}).get("id", encounter_id)),
				"name": String(encounter.get("enemy_army", {}).get("name", "Raid Host")),
				"stacks": continuity_army.get("stacks", []).duplicate(true),
			}
		else:
			normalized_army = _base_enemy_army(encounter_id)
	if not normalized_army.is_empty():
		normalized_army["id"] = String(normalized_army.get("id", encounter_id))
		normalized_army["name"] = String(normalized_army.get("name", "Raid Host"))
		encounter["enemy_army"] = normalized_army
	if not commander_state.is_empty():
		encounter["enemy_commander_state"] = sync_commander_army_continuity(
			commander_state,
			normalized_army,
			encounter_id
		)
	return encounter

static func occupied_raid_commander_ids(
	session: SessionStateStoreScript.SessionData,
	faction_id: String = "",
	exclude_placement_id: String = ""
) -> Dictionary:
	var occupied: Dictionary = {}
	if session == null:
		return occupied
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if resolved_encounters is Array and String(encounter.get("placement_id", "")) in resolved_encounters:
			continue
		if faction_id != "" and String(encounter.get("spawned_by_faction_id", "")) != faction_id:
			continue
		if exclude_placement_id != "" and String(encounter.get("placement_id", "")) == exclude_placement_id:
			continue
		var roster_hero_id := String(encounter.get("enemy_commander_state", {}).get("roster_hero_id", ""))
		if roster_hero_id != "":
			occupied[roster_hero_id] = true
	return occupied

static func select_raid_commander_roster_hero_id(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	preferred_index: int = 0,
	occupied_commander_ids: Dictionary = {},
	commander_roster: Variant = []
) -> String:
	if faction_id == "":
		return ""
	var hero_ids: Array = _faction_commander_ids(faction_id)
	if hero_ids.is_empty():
		return ""
	var occupied: Dictionary = occupied_commander_ids
	if occupied.is_empty():
		occupied = occupied_raid_commander_ids(session, faction_id)
	var normalized_roster = normalize_commander_roster(
		session,
		faction_id,
		commander_roster if commander_roster is Array else commander_roster_for_faction(session, faction_id)
	)
	var unavailable: Dictionary = {}
	for entry_value in normalized_roster:
		if not (entry_value is Dictionary):
			continue
		var roster_hero_id := String(entry_value.get("roster_hero_id", ""))
		if roster_hero_id == "":
			continue
		if (
			_normalize_commander_status(entry_value.get("status", COMMANDER_STATUS_AVAILABLE)) != COMMANDER_STATUS_AVAILABLE
			or not commander_can_deploy(entry_value)
		):
			unavailable[roster_hero_id] = true
	var start_index: int = posmod(preferred_index, hero_ids.size())
	for offset in range(hero_ids.size()):
		var candidate_id = String(hero_ids[(start_index + offset) % hero_ids.size()])
		if candidate_id == "" or occupied.has(candidate_id) or unavailable.has(candidate_id):
			continue
		return candidate_id
	return ""

static func select_raid_commander_roster_hero_id_for_spawn(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	spawn_point: Dictionary,
	preferred_index: int = 0,
	occupied_commander_ids: Dictionary = {},
	commander_roster: Variant = []
) -> String:
	var candidates := _raid_commander_spawn_candidates(
		session,
		faction_id,
		preferred_index,
		occupied_commander_ids,
		commander_roster
	)
	if candidates.is_empty():
		return ""
	var best_saved := {}
	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		var saved_plan := _ai_hero_task_spawn_saved_plan_for_actor(
			session,
			faction_id,
			String(candidate.get("roster_hero_id", "")),
			spawn_point
		)
		if saved_plan.is_empty():
			continue
		candidate["saved_task_priority"] = int(saved_plan.get("priority", 0))
		candidate["saved_task_goal_distance"] = int(saved_plan.get("goal_distance", 9999))
		candidate["saved_task_target_label"] = String(saved_plan.get("target_label", ""))
		if best_saved.is_empty() or _spawn_saved_task_commander_candidate_beats(candidate, best_saved):
			best_saved = candidate
	if not best_saved.is_empty():
		return String(best_saved.get("roster_hero_id", ""))
	return String(candidates[0].get("roster_hero_id", ""))

static func _raid_commander_spawn_candidates(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	preferred_index: int,
	occupied_commander_ids: Dictionary,
	commander_roster: Variant
) -> Array:
	var candidates := []
	if faction_id == "":
		return candidates
	var hero_ids: Array = _faction_commander_ids(faction_id)
	if hero_ids.is_empty():
		return candidates
	var occupied: Dictionary = occupied_commander_ids
	if occupied.is_empty():
		occupied = occupied_raid_commander_ids(session, faction_id)
	var normalized_roster = normalize_commander_roster(
		session,
		faction_id,
		commander_roster if commander_roster is Array else commander_roster_for_faction(session, faction_id)
	)
	var unavailable: Dictionary = {}
	for entry_value in normalized_roster:
		if not (entry_value is Dictionary):
			continue
		var roster_hero_id := String(entry_value.get("roster_hero_id", ""))
		if roster_hero_id == "":
			continue
		if (
			_normalize_commander_status(entry_value.get("status", COMMANDER_STATUS_AVAILABLE)) != COMMANDER_STATUS_AVAILABLE
			or not commander_can_deploy(entry_value)
		):
			unavailable[roster_hero_id] = true
	var start_index: int = posmod(preferred_index, hero_ids.size())
	for offset in range(hero_ids.size()):
		var candidate_id = String(hero_ids[(start_index + offset) % hero_ids.size()])
		if candidate_id == "" or occupied.has(candidate_id) or unavailable.has(candidate_id):
			continue
		candidates.append({"roster_hero_id": candidate_id, "rotation_order": offset})
	return candidates

static func _ai_hero_task_spawn_saved_plan_for_actor(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	actor_id: String,
	spawn_point: Dictionary
) -> Dictionary:
	if session == null or faction_id == "" or actor_id == "" or spawn_point.is_empty():
		return {}
	var probe_placement_id := "__spawn_saved_task_probe:%s" % actor_id
	var probe_raid := {
		"placement_id": probe_placement_id,
		"spawned_by_faction_id": faction_id,
		"x": int(spawn_point.get("x", 0)),
		"y": int(spawn_point.get("y", 0)),
		"enemy_commander_state": {"roster_hero_id": actor_id, "faction_id": faction_id},
	}
	var config := {"faction_id": faction_id}
	var origin_pos := Vector2i(int(spawn_point.get("x", 0)), int(spawn_point.get("y", 0)))
	var best := {}
	for task_value in _ai_hero_task_live_tasks_for_faction(session, faction_id):
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("actor_id", "")) != actor_id:
			continue
		if String(task.get("task_status", "")) not in ["planned", "reserved", "active"]:
			continue
		if int(task.get("expires_day", 0)) > 0 and int(task.get("expires_day", 0)) < int(session.day):
			continue
		var plan := _ai_hero_task_plan_from_saved_task(session, config, probe_raid, task, origin_pos, probe_placement_id)
		if plan.is_empty():
			continue
		if best.is_empty() or _saved_task_plan_beats(plan, best):
			best = plan
	return best

static func _spawn_saved_task_commander_candidate_beats(candidate: Dictionary, best: Dictionary) -> bool:
	if int(candidate.get("saved_task_priority", 0)) == int(best.get("saved_task_priority", 0)):
		if int(candidate.get("saved_task_goal_distance", 9999)) == int(best.get("saved_task_goal_distance", 9999)):
			if int(candidate.get("rotation_order", 9999)) == int(best.get("rotation_order", 9999)):
				return String(candidate.get("roster_hero_id", "")) < String(best.get("roster_hero_id", ""))
			return int(candidate.get("rotation_order", 9999)) < int(best.get("rotation_order", 9999))
		return int(candidate.get("saved_task_goal_distance", 9999)) < int(best.get("saved_task_goal_distance", 9999))
	return int(candidate.get("saved_task_priority", 0)) > int(best.get("saved_task_priority", 0))

static func build_raid_commander_state(
	encounter: Dictionary,
	roster_hero_id: String = "",
	faction_id: String = "",
	session: SessionStateStoreScript.SessionData = null,
	occupied_commander_ids: Dictionary = {},
	commander_roster: Variant = []
) -> Dictionary:
	if encounter.is_empty():
		return {}
	var existing_state = encounter.get("enemy_commander_state", {})
	if not (existing_state is Dictionary):
		existing_state = {}
	var resolved_faction_id: String = String(existing_state.get("faction_id", faction_id))
	if resolved_faction_id == "":
		resolved_faction_id = String(encounter.get("spawned_by_faction_id", faction_id))
	var resolved_roster_hero_id: String = String(existing_state.get("roster_hero_id", roster_hero_id))
	if resolved_roster_hero_id == "" and resolved_faction_id != "":
		resolved_roster_hero_id = select_raid_commander_roster_hero_id(
			session,
			resolved_faction_id,
			_preferred_commander_index_for_encounter(encounter),
			occupied_commander_ids,
			commander_roster
		)
	if resolved_roster_hero_id == "" and resolved_faction_id != "" and existing_state.is_empty():
		return {}
	var hero_template = ContentService.get_hero(resolved_roster_hero_id)
	var encounter_template = ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	var encounter_commander = encounter_template.get("enemy_commander", {})
	if not (encounter_commander is Dictionary):
		encounter_commander = {}
	var normalized_roster = normalize_commander_roster(
		session,
		resolved_faction_id,
		commander_roster if commander_roster is Array else commander_roster_for_faction(session, resolved_faction_id)
	)
	var roster_entry := _commander_roster_entry(normalized_roster, resolved_roster_hero_id)
	var roster_commander_state = roster_entry.get("commander_state", {})
	if not (roster_commander_state is Dictionary):
		roster_commander_state = {}
	var commander_seed := build_roster_commander_state(
		resolved_roster_hero_id,
		resolved_faction_id,
		roster_commander_state if not roster_commander_state.is_empty() else existing_state,
		roster_entry
	)
	var command_source = encounter_commander.get(
		"command",
		commander_seed.get("command", hero_template.get("command", {}))
	)
	var commander_state = existing_state.duplicate(true) if not existing_state.is_empty() else commander_seed.duplicate(true)
	commander_state["id"] = String(
		commander_state.get(
			"id",
			commander_seed.get(
				"id",
				"raid_commander:%s" % String(encounter.get("placement_id", encounter.get("encounter_id", "raid")))
			)
		)
	)
	commander_state["roster_hero_id"] = resolved_roster_hero_id
	commander_state["faction_id"] = resolved_faction_id
	commander_state["name"] = String(
		commander_state.get(
			"name",
			commander_seed.get("name", hero_template.get("name", encounter_commander.get("name", "Enemy Commander")))
		)
	)
	commander_state["archetype"] = String(
		commander_state.get("archetype", commander_seed.get("archetype", hero_template.get("archetype", "")))
	)
	commander_state["identity_summary"] = String(
		commander_state.get(
			"identity_summary",
			commander_seed.get("identity_summary", hero_template.get("identity_summary", ""))
		)
	)
	commander_state["command"] = _normalize_command_payload(commander_state.get("command", command_source))
	commander_state["battle_traits"] = _merge_unique_strings(
		commander_seed.get("battle_traits", hero_template.get("battle_traits", [])),
		commander_state.get("battle_traits", encounter_commander.get("battle_traits", []))
	)
	var resolved_specialties = commander_state.get("specialties", [])
	if not (resolved_specialties is Array) or resolved_specialties.is_empty():
		resolved_specialties = commander_seed.get("specialties", hero_template.get("starting_specialties", []))
	commander_state["specialties"] = _normalized_specialty_ranks(resolved_specialties)
	commander_state["specialty_focus_ids"] = _normalized_specialty_focus_ids(
		_merge_unique_strings(
			commander_state.get("specialty_focus_ids", []),
			commander_seed.get("specialty_focus_ids", hero_template.get("specialty_focus_ids", []))
		)
	)
	commander_state["level"] = max(1, int(commander_state.get("level", commander_seed.get("level", 1))))
	commander_state["experience"] = max(0, int(commander_state.get("experience", commander_seed.get("experience", 0))))
	commander_state["next_level_experience"] = max(
		250,
		int(commander_state.get("next_level_experience", commander_seed.get("next_level_experience", 250)))
	)
	commander_state["pending_specialty_choices"] = commander_state.get(
		"pending_specialty_choices",
		commander_seed.get("pending_specialty_choices", [])
	)
	commander_state["last_outcome"] = String(
		commander_state.get("last_outcome", commander_seed.get("last_outcome", ""))
	)
	commander_state["artifacts"] = ArtifactRulesScript.normalize_hero_artifacts(
		commander_state.get("artifacts", commander_seed.get("artifacts", {}))
	)
	commander_state = _normalize_enemy_progression(commander_state)
	var commander_spellbook = commander_state.get("spellbook", {})
	if not (commander_spellbook is Dictionary):
		commander_spellbook = {}
	return _apply_commander_army_metadata(
		_apply_commander_record_metadata(
			_apply_commander_memory_metadata(
				SpellRulesScript.ensure_hero_spellbook(
					commander_state,
					{
						"command": commander_state.get("command", {}),
						"starting_spell_ids": _merge_unique_strings(
							commander_spellbook.get("known_spell_ids", []),
							_merge_unique_strings(
								_hero_starting_spell_ids(hero_template),
								encounter_commander.get("starting_spell_ids", [])
							)
						),
					}
				),
				_normalized_commander_memory(roster_entry, commander_state)
			),
			_normalized_commander_record(roster_entry, commander_state)
		),
		_normalized_commander_army_continuity(
			roster_entry,
			commander_state,
			String(encounter.get("encounter_id", encounter.get("id", "")))
		)
	)

static func raid_commander_name(encounter: Dictionary) -> String:
	if encounter.is_empty():
		return ""
	var commander_state = encounter.get("enemy_commander_state", {})
	if commander_state is Dictionary:
		var commander_name := String(commander_state.get("name", ""))
		if commander_name != "":
			return commander_name
	var encounter_template = ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	return String(encounter_template.get("enemy_commander", {}).get("name", ""))

static func raid_commander_display_name(encounter: Dictionary) -> String:
	if encounter.is_empty():
		return ""
	var commander_state = encounter.get("enemy_commander_state", {})
	if commander_state is Dictionary and not commander_state.is_empty():
		return commander_display_name(commander_state)
	return raid_commander_name(encounter)

static func raid_display_name(encounter: Dictionary) -> String:
	if encounter.is_empty():
		return "Hostile contact"
	var encounter_template = ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	var encounter_name := String(encounter_template.get("name", encounter.get("placement_id", "Raid host")))
	var commander_name := raid_commander_display_name(encounter)
	if commander_name == "" or String(encounter.get("spawned_by_faction_id", "")) == "":
		return encounter_name
	return "%s's %s" % [commander_name, encounter_name]

static func raid_commander_summaries(encounters: Array, limit: int = 2) -> Array:
	var names: Array = []
	for encounter in encounters:
		if not (encounter is Dictionary):
			continue
		var commander_name := raid_commander_display_name(encounter)
		if commander_name == "" or commander_name in names:
			continue
		names.append(commander_name)
		if limit > 0 and names.size() >= limit:
			break
	return names

static func _faction_commander_ids(faction_id: String) -> Array:
	var hero_ids: Array = []
	if faction_id == "":
		return hero_ids
	var faction = ContentService.get_faction(faction_id)
	for hero_id_value in faction.get("hero_ids", []):
		var hero_id := String(hero_id_value)
		if hero_id != "" and hero_id not in hero_ids:
			hero_ids.append(hero_id)
	return hero_ids

static func _active_commander_map(
	session: SessionStateStoreScript.SessionData,
	faction_id: String = ""
) -> Dictionary:
	var active: Dictionary = {}
	if session == null:
		return active
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if resolved_encounters is Array and String(encounter.get("placement_id", "")) in resolved_encounters:
			continue
		if faction_id != "" and String(encounter.get("spawned_by_faction_id", "")) != faction_id:
			continue
		var commander_state = encounter.get("enemy_commander_state", {})
		if not (commander_state is Dictionary) or commander_state.is_empty():
			continue
		var roster_hero_id := String(commander_state.get("roster_hero_id", ""))
		if roster_hero_id == "":
			continue
		active[roster_hero_id] = {
			"placement_id": String(encounter.get("placement_id", "")),
			"commander_state": commander_state.duplicate(true),
		}
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary):
			continue
		var defender_entry := _active_town_defender_entry(session, town, faction_id)
		if defender_entry.is_empty():
			continue
		var defender_state: Dictionary = defender_entry.get("commander_state", {})
		var defender_roster_hero_id := String(defender_state.get("roster_hero_id", ""))
		if defender_roster_hero_id == "":
			continue
		active[defender_roster_hero_id] = defender_entry
	return active

static func _normalize_town_defender_commander_states(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	var towns = session.overworld.get("towns", [])
	if not (towns is Array):
		return
	var changed := false
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary):
			continue
		if not _town_has_ai_defender(town):
			continue
		if _active_town_defender_entry(session, town).is_empty():
			town = town.duplicate(true)
			_clear_town_defender_metadata(town)
			towns[index] = town
			changed = true
	if changed:
		session.overworld["towns"] = towns

static func _town_has_ai_defender(town: Dictionary) -> bool:
	return (
		town.has("ai_defender_commander_state")
		or String(town.get("ai_defender_roster_hero_id", "")) != ""
		or String(town.get("ai_defended_by_faction_id", "")) != ""
	)

static func _active_town_defender_entry(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	faction_filter: String = ""
) -> Dictionary:
	if session == null or town.is_empty():
		return {}
	var commander_state = town.get("ai_defender_commander_state", {})
	if not (commander_state is Dictionary) or commander_state.is_empty():
		return {}
	var roster_hero_id := String(commander_state.get("roster_hero_id", town.get("ai_defender_roster_hero_id", "")))
	if roster_hero_id == "":
		return {}
	var faction_id := String(town.get("ai_defended_by_faction_id", commander_state.get("faction_id", "")))
	if faction_id == "":
		faction_id = _town_faction_id(town)
	if faction_filter != "" and faction_id != faction_filter:
		return {}
	if String(town.get("owner", "neutral")) != "enemy" or _town_faction_id(town) != faction_id:
		return {}
	var front: Dictionary = town.get("front", {}) if town.get("front", {}) is Dictionary else {}
	var front_state: Dictionary = OverworldRulesScript.town_front_state(session, town)
	var raw_front_state := String(front.get("state", ""))
	if raw_front_state not in ["defend", "stabilizing"]:
		return {}
	if not bool(front_state.get("active", false)) or String(front_state.get("mode", "")) != "stabilizing":
		return {}
	if String(front_state.get("faction_id", "")) != "" and String(front_state.get("faction_id", "")) != faction_id:
		return {}
	var defense_until: int = max(
		int(town.get("ai_defense_until_day", 0)),
		int(front.get("defense_until_day", 0))
	)
	if defense_until < int(session.day):
		return {}
	var entry_state: Dictionary = commander_state.duplicate(true)
	entry_state["roster_hero_id"] = roster_hero_id
	entry_state["faction_id"] = faction_id
	return {
		"placement_id": "town_defense:%s" % String(town.get("placement_id", "")),
		"commander_state": entry_state,
	}

static func _clear_town_defender_metadata(town: Dictionary) -> void:
	town.erase("ai_defender_commander_state")
	town.erase("ai_defender_roster_hero_id")
	town.erase("ai_defended_by_faction_id")
	town.erase("ai_defended_day")
	town.erase("ai_defense_until_day")
	town.erase("ai_defense_rating")
	town.erase("ai_defense_reinforced_strength")

static func _normalize_commander_status(value: Variant) -> String:
	var status := String(value)
	if status in [COMMANDER_STATUS_AVAILABLE, COMMANDER_STATUS_ACTIVE, COMMANDER_STATUS_RECOVERING]:
		return status
	return COMMANDER_STATUS_AVAILABLE

static func _commander_entry_name(entry: Dictionary) -> String:
	var commander_state = entry.get("commander_state", {})
	if commander_state is Dictionary:
		var commander_name := String(commander_state.get("name", ""))
		if commander_name != "":
			return commander_name
	return String(ContentService.get_hero(String(entry.get("roster_hero_id", ""))).get("name", ""))

static func _commander_roster_entry(roster: Variant, roster_hero_id: String) -> Dictionary:
	if roster_hero_id == "" or not (roster is Array):
		return {}
	for entry_value in roster:
		if entry_value is Dictionary and String(entry_value.get("roster_hero_id", "")) == roster_hero_id:
			return entry_value
	return {}

static func _commander_name_from_source(source: Variant) -> String:
	if source is Dictionary:
		var commander_state = source.get("commander_state", {})
		if commander_state is Dictionary and String(commander_state.get("name", "")) != "":
			return String(commander_state.get("name", ""))
		if String(source.get("name", "")) != "":
			return String(source.get("name", ""))
		if String(source.get("roster_hero_id", "")) != "":
			return String(ContentService.get_hero(String(source.get("roster_hero_id", ""))).get("name", ""))
	return ""

static func record_target_assignment(
	commander_state: Dictionary,
	target_kind: String,
	target_id: String,
	target_label: String,
	target_x: int = 0,
	target_y: int = 0
) -> Dictionary:
	if commander_state.is_empty() or target_kind == "" or target_id == "":
		return _apply_commander_memory_metadata(commander_state, commander_state)
	var updated := commander_state.duplicate(true)
	var memory := _normalized_commander_memory(updated)
	var is_focus_match := (
		target_kind == String(memory.get("focus_target_kind", ""))
		and target_id == String(memory.get("focus_target_id", ""))
	)
	var is_last_match := (
		target_kind == String(memory.get("last_target_kind", ""))
		and target_id == String(memory.get("last_target_id", ""))
	)
	var next_focus_count := 1
	if is_focus_match:
		next_focus_count = max(1, int(memory.get("focus_pressure_count", 0))) + 1
	elif is_last_match:
		next_focus_count = max(2, int(memory.get("focus_pressure_count", 0)))
	memory["focus_target_kind"] = target_kind
	memory["focus_target_id"] = target_id
	memory["focus_target_label"] = target_label
	memory["focus_pressure_count"] = next_focus_count
	memory["last_target_kind"] = target_kind
	memory["last_target_id"] = target_id
	memory["last_target_label"] = target_label
	memory["front_label"] = target_label
	memory["front_x"] = target_x
	memory["front_y"] = target_y
	updated["target_memory"] = memory
	return _apply_commander_memory_metadata(updated, memory)

static func record_rivalry(
	commander_state: Dictionary,
	rival_kind: String,
	rival_id: String,
	rival_label: String
) -> Dictionary:
	if commander_state.is_empty() or rival_kind == "" or rival_id == "":
		return _apply_commander_memory_metadata(commander_state, commander_state)
	var updated := commander_state.duplicate(true)
	var memory := _normalized_commander_memory(updated)
	var rivalry_count := 1
	if rival_kind == String(memory.get("rival_kind", "")) and rival_id == String(memory.get("rival_id", "")):
		rivalry_count = max(1, int(memory.get("rivalry_count", 0))) + 1
	memory["rival_kind"] = rival_kind
	memory["rival_id"] = rival_id
	memory["rival_label"] = rival_label
	memory["rivalry_count"] = rivalry_count
	updated["target_memory"] = memory
	return _apply_commander_memory_metadata(updated, memory)

static func _normalized_commander_record(entry_value: Variant, commander_state_value: Variant = {}) -> Dictionary:
	var entry: Dictionary = entry_value if entry_value is Dictionary else {}
	var commander_state: Dictionary = commander_state_value if commander_state_value is Dictionary else {}
	var deployments: int = max(0, max(int(entry.get("deployments", 0)), int(commander_state.get("deployments", 0))))
	var battle_wins: int = max(0, max(int(entry.get("battle_wins", 0)), int(commander_state.get("battle_wins", 0))))
	var times_defeated: int = max(0, max(int(entry.get("times_defeated", 0)), int(commander_state.get("times_defeated", 0))))
	var strategic_successes: int = max(0, max(int(entry.get("strategic_successes", 0)), int(commander_state.get("strategic_successes", 0))))
	var last_outcome := String(commander_state.get("last_outcome", ""))
	if last_outcome == "":
		last_outcome = String(entry.get("last_outcome", ""))
	var record := {
		"deployments": deployments,
		"battle_wins": battle_wins,
		"times_defeated": times_defeated,
		"strategic_successes": strategic_successes,
		"last_outcome": last_outcome,
	}
	record["renown"] = _commander_renown_from_record(record)
	return record

static func _normalized_commander_memory(entry_value: Variant, commander_state_value: Variant = {}) -> Dictionary:
	var entry: Dictionary = entry_value if entry_value is Dictionary else {}
	var commander_state: Dictionary = commander_state_value if commander_state_value is Dictionary else {}
	var entry_commander_state = entry.get("commander_state", {})
	if not (entry_commander_state is Dictionary):
		entry_commander_state = {}
	var raw_memory: Dictionary = {}
	for key in [
		"focus_target_kind",
		"focus_target_id",
		"focus_target_label",
		"focus_pressure_count",
		"last_target_kind",
		"last_target_id",
		"last_target_label",
		"front_label",
		"front_x",
		"front_y",
		"rival_kind",
		"rival_id",
		"rival_label",
		"rivalry_count",
	]:
		if entry.has(key):
			raw_memory[String(key)] = entry[key]
	for source_value in [
		entry.get("target_memory", {}),
		entry_commander_state.get("target_memory", {}),
		commander_state.get("target_memory", {}),
	]:
		if not (source_value is Dictionary):
			continue
		var source: Dictionary = source_value
		for key in source.keys():
			raw_memory[String(key)] = source[key]
	var memory := {
		"focus_target_kind": String(raw_memory.get("focus_target_kind", "")),
		"focus_target_id": String(raw_memory.get("focus_target_id", "")),
		"focus_target_label": String(raw_memory.get("focus_target_label", "")),
		"focus_pressure_count": max(0, int(raw_memory.get("focus_pressure_count", 0))),
		"last_target_kind": String(raw_memory.get("last_target_kind", "")),
		"last_target_id": String(raw_memory.get("last_target_id", "")),
		"last_target_label": String(raw_memory.get("last_target_label", "")),
		"front_label": String(raw_memory.get("front_label", "")),
		"front_x": int(raw_memory.get("front_x", 0)),
		"front_y": int(raw_memory.get("front_y", 0)),
		"rival_kind": String(raw_memory.get("rival_kind", "")),
		"rival_id": String(raw_memory.get("rival_id", "")),
		"rival_label": String(raw_memory.get("rival_label", "")),
		"rivalry_count": max(0, int(raw_memory.get("rivalry_count", 0))),
	}
	if (
		String(memory.get("focus_target_id", "")) == ""
		and String(memory.get("last_target_id", "")) == ""
		and String(memory.get("rival_id", "")) == ""
		and String(memory.get("front_label", "")) == ""
		and int(memory.get("focus_pressure_count", 0)) <= 0
		and int(memory.get("rivalry_count", 0)) <= 0
	):
		return {}
	return memory

static func _commander_renown_from_record(record: Dictionary) -> int:
	var deployments: int = max(0, int(record.get("deployments", 0)))
	var battle_wins: int = max(0, int(record.get("battle_wins", 0)))
	var times_defeated: int = max(0, int(record.get("times_defeated", 0)))
	var strategic_successes: int = max(0, int(record.get("strategic_successes", 0)))
	return clamp((deployments + (battle_wins * 2) + int(floor(float(strategic_successes) / 2.0))) - times_defeated, 0, 9)

static func _commander_veterancy_rank_from_record(record: Dictionary) -> int:
	var deployments: int = max(0, int(record.get("deployments", 0)))
	var battle_wins: int = max(0, int(record.get("battle_wins", 0)))
	var renown: int = max(0, int(record.get("renown", _commander_renown_from_record(record))))
	if battle_wins >= 3 or renown >= 8:
		return 3
	if battle_wins >= 2 or renown >= 5:
		return 2
	if battle_wins >= 1 or deployments >= 2 or renown >= 2:
		return 1
	return 0

static func _apply_commander_record_metadata(commander_state: Dictionary, record_source: Variant) -> Dictionary:
	var commander := commander_state.duplicate(true)
	var record := _normalized_commander_record(record_source, commander)
	commander["deployments"] = max(0, int(record.get("deployments", 0)))
	commander["battle_wins"] = max(0, int(record.get("battle_wins", 0)))
	commander["times_defeated"] = max(0, int(record.get("times_defeated", 0)))
	commander["strategic_successes"] = max(0, int(record.get("strategic_successes", 0)))
	commander["renown"] = max(0, int(record.get("renown", 0)))
	commander["veterancy_rank"] = _commander_veterancy_rank_from_record(record)
	commander["veterancy_label"] = commander_veterancy_label(record)
	commander["record_summary"] = commander_record_summary(record)
	commander["last_outcome"] = String(record.get("last_outcome", commander.get("last_outcome", "")))
	return commander

static func _apply_commander_memory_metadata(commander_state: Dictionary, memory_source: Variant) -> Dictionary:
	if commander_state.is_empty():
		return {}
	var commander := commander_state.duplicate(true)
	var memory := _normalized_commander_memory(memory_source, commander)
	commander["target_memory"] = memory
	commander["memory_brief"] = commander_memory_brief(memory)
	commander["memory_summary"] = commander_memory_summary(memory)
	return commander

static func _normalized_commander_army_continuity(
	entry_value: Variant,
	commander_state_value: Variant = {},
	encounter_id: String = ""
) -> Dictionary:
	var entry: Dictionary = entry_value if entry_value is Dictionary else {}
	var commander_state: Dictionary = commander_state_value if commander_state_value is Dictionary else {}
	var entry_commander_state = entry.get("commander_state", {})
	if not (entry_commander_state is Dictionary):
		entry_commander_state = {}
	var raw_continuity: Dictionary = {}
	var continuity_sources := []
	if _is_army_continuity_payload(entry):
		continuity_sources.append(entry)
	continuity_sources.append(entry.get("army_continuity", {}))
	continuity_sources.append(entry_commander_state.get("army_continuity", {}))
	continuity_sources.append(commander_state.get("army_continuity", {}))
	for source_value in continuity_sources:
		if not (source_value is Dictionary):
			continue
		var source: Dictionary = source_value
		for key in source.keys():
			raw_continuity[String(key)] = source[key]
	var resolved_encounter_id := String(raw_continuity.get("encounter_id", encounter_id))
	var normalized_payload := _normalize_army_payload({"stacks": raw_continuity.get("stacks", [])})
	var stacks: Array = normalized_payload.get("stacks", [])
	var base_strength: int = max(0, int(raw_continuity.get("base_strength", 0)))
	if base_strength <= 0 and resolved_encounter_id != "":
		base_strength = _army_strength(_base_enemy_army(resolved_encounter_id).get("stacks", []))
	if base_strength <= 0 and stacks.is_empty():
		return {}
	if base_strength <= 0:
		base_strength = _army_strength(stacks)
	var current_strength: int = _army_strength(stacks)
	var status := String(raw_continuity.get("status", ""))
	if status == "":
		status = _army_continuity_status(current_strength, base_strength)
	var strength_percent := 100 if base_strength <= 0 else int(round((float(current_strength) * 100.0) / float(base_strength)))
	return {
		"encounter_id": resolved_encounter_id,
		"stacks": stacks.duplicate(true),
		"base_strength": base_strength,
		"current_strength": current_strength,
		"rebuild_need": max(0, base_strength - current_strength),
		"strength_percent": clamp(strength_percent, 0, 100),
		"status": status,
		"headcount": _army_headcount(stacks),
		"company_count": stacks.size(),
		"summary": _army_continuity_summary(status, current_strength, base_strength),
	}

static func _is_army_continuity_payload(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var payload: Dictionary = value
	return (
		payload.has("base_strength")
		or payload.has("current_strength")
		or payload.has("rebuild_need")
		or payload.has("strength_percent")
		or payload.has("stacks")
	)

static func sync_commander_army_continuity(
	commander_state: Dictionary,
	army_source: Variant,
	encounter_id: String = ""
) -> Dictionary:
	if commander_state.is_empty():
		return {}
	var updated := commander_state.duplicate(true)
	var continuity := _normalized_commander_army_continuity(updated, updated, encounter_id)
	var army_payload: Variant = army_source if army_source is Dictionary else {"stacks": army_source}
	var explicit_stacks: bool = (
		army_payload is Dictionary
		and army_payload.has("stacks")
		and army_payload.get("stacks", []) is Array
	)
	var normalized_army := _normalize_army_payload(army_payload)
	var stacks: Array = []
	if normalized_army.has("stacks"):
		stacks = normalized_army.get("stacks", [])
	elif explicit_stacks:
		stacks = []
	else:
		stacks = continuity.get("stacks", [])
	var resolved_encounter_id := encounter_id if encounter_id != "" else String(continuity.get("encounter_id", ""))
	var base_strength: int = max(
		int(continuity.get("base_strength", 0)),
		_army_strength(_base_enemy_army(resolved_encounter_id).get("stacks", [])),
		_army_strength(stacks)
	)
	if base_strength <= 0 and stacks.is_empty():
		return _apply_commander_army_metadata(updated, {})
	var current_strength: int = _army_strength(stacks)
	var status := _army_continuity_status(current_strength, base_strength)
	updated["army_continuity"] = {
		"encounter_id": resolved_encounter_id,
		"stacks": stacks.duplicate(true),
		"base_strength": base_strength,
		"current_strength": current_strength,
		"rebuild_need": max(0, base_strength - current_strength),
		"strength_percent": 100 if base_strength <= 0 else clamp(
			int(round((float(current_strength) * 100.0) / float(base_strength))),
			0,
			100
		),
		"status": status,
		"headcount": _army_headcount(stacks),
		"company_count": stacks.size(),
	}
	return _apply_commander_army_metadata(updated, updated)

static func _apply_commander_army_metadata(commander_state: Dictionary, army_source: Variant) -> Dictionary:
	if commander_state.is_empty():
		return {}
	var commander := commander_state.duplicate(true)
	var continuity := _normalized_commander_army_continuity(army_source, commander)
	commander["army_continuity"] = continuity
	commander["army_status"] = String(continuity.get("status", ""))
	commander["army_brief"] = commander_army_brief(continuity)
	commander["army_summary"] = commander_army_summary(continuity)
	commander["army_base_strength"] = max(0, int(continuity.get("base_strength", 0)))
	commander["army_current_strength"] = max(0, int(continuity.get("current_strength", 0)))
	commander["army_rebuild_need"] = max(0, int(continuity.get("rebuild_need", 0)))
	return commander

static func _army_continuity_status(current_strength: int, base_strength: int) -> String:
	if base_strength <= 0:
		return ""
	if current_strength <= 0:
		return "shattered"
	if current_strength >= base_strength:
		return "ready"
	if (float(current_strength) / float(base_strength)) >= 0.7:
		return "scarred"
	return "rebuilding"

static func _army_continuity_summary(status: String, current_strength: int, base_strength: int) -> String:
	if base_strength <= 0:
		return ""
	var prefix := "Battle-ready host"
	match status:
		"shattered":
			prefix = "Shattered host"
		"rebuilding":
			prefix = "Rebuilding host"
		"scarred":
			prefix = "Scarred host"
	return "%s %d/%d" % [prefix, max(0, current_strength), max(0, base_strength)]

static func _army_headcount(stacks: Variant) -> int:
	var count := 0
	if not (stacks is Array):
		return count
	for stack_value in stacks:
		if not (stack_value is Dictionary):
			continue
		count += max(0, int(stack_value.get("count", 0)))
	return count

static func _normalize_enemy_progression(commander_state: Dictionary) -> Dictionary:
	var commander := HeroProgressionRulesScript.ensure_hero_progression(commander_state.duplicate(true))
	var guard := 0
	while HeroProgressionRulesScript.pending_choices_remaining(commander) > 0 and guard < 8:
		var pending_choice := HeroProgressionRulesScript.current_pending_choice(commander)
		if pending_choice.is_empty():
			break
		var chosen_specialty := _preferred_enemy_specialty_id(commander, pending_choice)
		if chosen_specialty == "":
			break
		var choice_result := HeroProgressionRulesScript.choose_specialty(commander, chosen_specialty)
		commander = choice_result.get("hero", commander)
		guard += 1
	return HeroProgressionRulesScript.ensure_hero_progression(commander)

static func _award_enemy_commander_experience(commander_state: Dictionary, amount: int) -> Dictionary:
	if amount <= 0:
		return _normalize_enemy_progression(commander_state)
	var result := HeroProgressionRulesScript.add_experience(commander_state, amount)
	return _normalize_enemy_progression(result.get("hero", commander_state))

static func _preferred_enemy_specialty_id(commander_state: Dictionary, pending_choice: Dictionary) -> String:
	var options = pending_choice.get("options", [])
	if not (options is Array) or options.is_empty():
		return ""
	for specialty_id_value in commander_state.get("specialty_focus_ids", []):
		var specialty_id := String(specialty_id_value)
		if specialty_id in options:
			return specialty_id
	return String(options[0])

static func _normalized_specialty_ranks(primary: Variant, secondary: Variant = []) -> Array:
	var hero_stub := {"specialties": []}
	var normalized := []
	for source in [secondary, primary]:
		if not (source is Array):
			continue
		for specialty_value in source:
			var specialty_id := String(specialty_value)
			if HeroProgressionRulesScript.specialty_definition(specialty_id).is_empty():
				continue
			var trial := normalized.duplicate()
			trial.append(specialty_id)
			hero_stub["specialties"] = trial
			normalized = HeroProgressionRulesScript.ensure_hero_progression(hero_stub).get("specialties", normalized)
	return normalized

static func _normalized_specialty_focus_ids(value: Variant) -> Array:
	var normalized := []
	if not (value is Array):
		return normalized
	for specialty_value in value:
		var specialty_id := String(specialty_value)
		if specialty_id == "" or specialty_id in normalized:
			continue
		if HeroProgressionRulesScript.specialty_definition(specialty_id).is_empty():
			continue
		normalized.append(specialty_id)
	return normalized

static func _hero_starting_spell_ids(hero_template: Dictionary) -> Array:
	var spell_ids := []
	for spell_id_value in hero_template.get("starting_spell_ids", []):
		var spell_id := String(spell_id_value)
		if spell_id == "":
			continue
		if ContentService.get_spell(spell_id).is_empty():
			continue
		if spell_id not in spell_ids:
			spell_ids.append(spell_id)
	return spell_ids

static func _normalize_command_payload(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {"attack": 0, "defense": 0, "power": 0, "knowledge": 0}
	return {
		"attack": max(0, int(value.get("attack", 0))),
		"defense": max(0, int(value.get("defense", 0))),
		"power": max(0, int(value.get("power", 0))),
		"knowledge": max(0, int(value.get("knowledge", 0))),
	}

static func _merge_unique_strings(primary: Variant, secondary: Variant) -> Array:
	var merged := []
	for source in [primary, secondary]:
		if not (source is Array):
			continue
		for entry in source:
			var text := String(entry)
			if text != "" and text not in merged:
				merged.append(text)
	return merged

static func _preferred_commander_index_for_encounter(encounter: Dictionary) -> int:
	var placement_id := String(encounter.get("placement_id", encounter.get("encounter_id", "")))
	if placement_id == "":
		return 0
	return abs(int(hash(placement_id)))

static func _clear_delivery_intercept_target(raid: Dictionary) -> Dictionary:
	if raid.is_empty():
		return raid
	raid["delivery_intercept_node_placement_id"] = ""
	raid["delivery_intercept_target_kind"] = ""
	raid["delivery_intercept_target_id"] = ""
	raid["delivery_intercept_label"] = ""
	return raid

static func _current_target_snapshot(raid: Dictionary) -> Dictionary:
	if raid.is_empty():
		return {}
	return {
		"target_kind": String(raid.get("target_kind", "")),
		"target_placement_id": String(raid.get("target_placement_id", "")),
		"target_label": String(raid.get("target_label", "")),
		"target_x": int(raid.get("target_x", raid.get("goal_x", 0))),
		"target_y": int(raid.get("target_y", raid.get("goal_y", 0))),
	}

static func _target_signature(target: Dictionary) -> String:
	if target.is_empty():
		return ""
	return "%s:%s" % [String(target.get("target_kind", "")), String(target.get("target_placement_id", ""))]

static func choose_target(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	origin: Dictionary,
	commander_source: Variant = {}
) -> Dictionary:
	var origin_pos = Vector2i(int(origin.get("x", 0)), int(origin.get("y", 0)))
	var candidates = _target_candidates(session, config, origin_pos)
	if candidates.is_empty():
		var hero_position: Dictionary = session.overworld.get("hero_position", {"x": 0, "y": 0})
		var active_hero_id := String(session.overworld.get("active_hero_id", ""))
		return {
			"target_kind": "hero",
			"target_placement_id": active_hero_id,
			"target_label": String(session.overworld.get("hero", {}).get("name", "the hero")),
			"target_x": int(hero_position.get("x", 0)),
			"target_y": int(hero_position.get("y", 0)),
			"goal_x": int(hero_position.get("x", 0)),
			"goal_y": int(hero_position.get("y", 0)),
			"goal_distance": abs(origin_pos.x - int(hero_position.get("x", 0))) + abs(origin_pos.y - int(hero_position.get("y", 0))),
		}

	var repeated_rival_memory := _normalized_commander_memory(commander_source)
	var repeated_rival_kind := String(repeated_rival_memory.get("rival_kind", ""))
	var repeated_rival_id := String(repeated_rival_memory.get("rival_id", ""))
	var repeated_rival_count: int = max(0, int(repeated_rival_memory.get("rivalry_count", 0)))
	var repeated_rival_index: int = -1
	var best_priority: int = 0
	for index in range(candidates.size()):
		if not (candidates[index] is Dictionary):
			continue
		var candidate: Dictionary = candidates[index]
		candidate["priority"] = max(
			0,
			int(candidate.get("priority", 0)) + _commander_memory_priority_bonus(session, candidate, commander_source)
		)
		best_priority = max(best_priority, int(candidate.get("priority", 0)))
		if (
			repeated_rival_count >= 2
			and String(candidate.get("target_kind", "")) == repeated_rival_kind
			and String(candidate.get("target_placement_id", "")) == repeated_rival_id
		):
			repeated_rival_index = index
		candidates[index] = candidate
	if repeated_rival_index >= 0:
		var repeated_rival_candidate: Dictionary = candidates[repeated_rival_index]
		repeated_rival_candidate["priority"] = max(
			int(repeated_rival_candidate.get("priority", 0)),
			best_priority + 35 + (min(4, repeated_rival_count) * 10)
		)
		candidates[repeated_rival_index] = repeated_rival_candidate

	var best: Dictionary = candidates[0]
	for index in range(1, candidates.size()):
		var candidate = candidates[index]
		if _candidate_beats(candidate, best):
			best = candidate
	return best

static func ai_hero_task_live_target_selection_plan(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary
) -> Dictionary:
	if session == null or raid.is_empty():
		return {}
	var faction_id := String(config.get("faction_id", raid.get("spawned_by_faction_id", "")))
	if faction_id == "":
		return {}
	var commander_state = raid.get("enemy_commander_state", {})
	if not (commander_state is Dictionary):
		return {}
	var roster_hero_id := String(commander_state.get("roster_hero_id", ""))
	if roster_hero_id == "":
		return {}
	var roster := commander_roster_for_faction(session, faction_id)
	var commander_entry := _commander_roster_entry(roster, roster_hero_id)
	if commander_entry.is_empty():
		commander_entry = {
			"roster_hero_id": roster_hero_id,
			"status": COMMANDER_STATUS_AVAILABLE,
			"commander_state": commander_state,
			"army_continuity": commander_army_continuity(commander_state),
		}
	if not commander_can_deploy(commander_entry):
		return {}
	var origin := {"x": int(raid.get("x", 0)), "y": int(raid.get("y", 0))}
	var origin_pos := Vector2i(int(origin.get("x", 0)), int(origin.get("y", 0)))
	var candidates := _target_candidates(session, config, origin_pos)
	var plans := []
	var local_sequence := 1
	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		if String(candidate.get("target_kind", "")) != "resource":
			continue
		var target_id := String(candidate.get("target_placement_id", ""))
		if target_id == "" or _ai_hero_task_live_target_reserved(session, faction_id, "resource", target_id, String(raid.get("placement_id", "")), roster_hero_id):
			continue
		var target_view := commander_role_resource_target_view(session, config, faction_id, target_id, origin)
		if target_view.is_empty():
			continue
		var proposal := commander_role_proposal_for_resource_target(
			session,
			config,
			faction_id,
			commander_entry,
			target_view,
			_ai_hero_task_live_resource_context(session, faction_id, target_id)
		)
		var role_record := _turn_transcript_role_proposal(session, faction_id, commander_entry, target_view, proposal)
		role_record["timing"] = "live_target_selection"
		var task := ai_hero_task_candidate_from_role(
			session,
			config,
			faction_id,
			commander_entry,
			role_record,
			local_sequence,
			{"source_timing": "live_target_selection"}
		)
		local_sequence += 1
		if not _ai_hero_task_live_target_task_valid(task):
			continue
		var plan := _ai_hero_task_live_plan_from_task(session, raid, task, candidate, origin_pos)
		if not plan.is_empty():
			plans.append(plan)
	if plans.is_empty():
		return {}
	plans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("priority", 0)) == int(b.get("priority", 0)):
			if int(a.get("goal_distance", 9999)) == int(b.get("goal_distance", 9999)):
				return String(a.get("target_label", "")) < String(b.get("target_label", ""))
			return int(a.get("goal_distance", 9999)) < int(b.get("goal_distance", 9999))
		return int(a.get("priority", 0)) > int(b.get("priority", 0))
	)
	return plans[0]

static func plan_enemy_hero_task_board(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	state: Dictionary = {}
) -> Dictionary:
	if session == null or config.is_empty():
		return {"state": state, "planned_count": 0, "task_count": 0}
	var faction_id := String(config.get("faction_id", state.get("faction_id", "")))
	if faction_id == "":
		return {"state": state, "planned_count": 0, "task_count": 0}
	var working_state := state.duplicate(true) if not state.is_empty() else _ai_hero_task_enemy_state_for_faction(session, faction_id).duplicate(true)
	if working_state.is_empty():
		return {"state": state, "planned_count": 0, "task_count": 0}
	var origins := _ai_hero_task_planner_origins(session, config, faction_id)
	if origins.is_empty():
		return {"state": working_state, "planned_count": 0, "task_count": 0}

	_ai_hero_task_reconcile_live_tasks_for_faction(session, faction_id)
	var reconciled_state := _ai_hero_task_enemy_state_for_faction(session, faction_id)
	if reconciled_state.get("hero_task_state", {}) is Dictionary:
		working_state["hero_task_state"] = reconciled_state.get("hero_task_state", {}).duplicate(true)
	var roster := normalize_commander_roster(
		session,
		faction_id,
		working_state.get("commander_roster", commander_roster_for_faction(session, faction_id))
	)
	if roster.is_empty():
		return {"state": working_state, "planned_count": 0, "task_count": 0}
	working_state["commander_roster"] = roster

	var task_state: Dictionary = working_state.get("hero_task_state", {}) if working_state.get("hero_task_state", {}) is Dictionary else {}
	var existing_tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
	var next_tasks := []
	for task_value in existing_tasks:
		if task_value is Dictionary:
			next_tasks.append(task_value)

	var candidates := _ai_hero_task_planner_candidates_from_origins(session, config, origins)
	var target_claims := _ai_hero_task_planner_target_claims(next_tasks)
	var planned_count := 0
	var events := []
	for commander_value in roster:
		if not (commander_value is Dictionary):
			continue
		var commander: Dictionary = commander_value
		var actor_id := String(commander.get("roster_hero_id", ""))
		if actor_id == "":
			continue
		if _normalize_commander_status(commander.get("status", COMMANDER_STATUS_AVAILABLE)) != COMMANDER_STATUS_AVAILABLE:
			continue
		if not commander_can_deploy(commander):
			continue
		if _ai_hero_task_planner_actor_has_open_task(next_tasks, actor_id):
			continue
		var task := _ai_hero_task_planner_task_for_actor(
			session,
			config,
			faction_id,
			actor_id,
			origins[0],
			candidates,
			target_claims,
			next_tasks.size() + planned_count + 1
		)
		if task.is_empty():
			continue
		next_tasks.append(task)
		var event := _ai_hero_task_planner_event(session, config, task)
		if not event.is_empty():
			events.append(event)
		var reservation: Dictionary = task.get("reservation", {}) if task.get("reservation", {}) is Dictionary else {}
		var reservation_key := String(reservation.get("reservation_key", ""))
		if reservation_key != "":
			target_claims[reservation_key] = true
		planned_count += 1
	if planned_count <= 0:
		working_state["hero_task_state"] = {
			"schema_version": 1,
			"planner_epoch": max(0, int(task_state.get("planner_epoch", 0))),
			"tasks": _ai_hero_task_prune_live_tasks(next_tasks, int(session.day)),
		}
		_ai_hero_task_write_enemy_state_for_faction(session, faction_id, working_state)
		return {"state": working_state, "planned_count": 0, "task_count": next_tasks.size(), "events": []}
	working_state["hero_task_state"] = {
		"schema_version": 1,
		"planner_epoch": max(0, int(task_state.get("planner_epoch", 0))) + 1,
		"tasks": _ai_hero_task_prune_live_tasks(next_tasks, int(session.day)),
	}
	_ai_hero_task_write_enemy_state_for_faction(session, faction_id, working_state)
	return {
		"state": working_state,
		"planned_count": planned_count,
		"task_count": working_state.get("hero_task_state", {}).get("tasks", []).size() if working_state.get("hero_task_state", {}) is Dictionary else next_tasks.size(),
		"events": events,
	}

static func _ai_hero_task_planner_task_for_actor(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	actor_id: String,
	origin: Dictionary,
	candidates: Array,
	target_claims: Dictionary,
	sequence: int
) -> Dictionary:
	var fitted_candidates := _ai_hero_task_planner_candidates_for_commander(
		session,
		faction_id,
		actor_id,
		candidates
	)
	for candidate_value in fitted_candidates:
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		var candidate_origin: Dictionary = candidate.get("planner_origin", origin) if candidate.get("planner_origin", {}) is Dictionary else origin
		var target_kind := String(candidate.get("target_kind", ""))
		var target_id := String(candidate.get("target_placement_id", ""))
		if target_kind not in ["resource", "town", "artifact", "encounter", "hero"] or target_id == "":
			continue
		if int(candidate.get("priority", 0)) <= 0:
			continue
		var task_class := _ai_hero_task_planner_class_for_candidate(candidate)
		var reservation := _ai_hero_task_default_reservation(task_class, target_kind, target_id)
		var reservation_key := String(reservation.get("reservation_key", ""))
		if reservation_key != "" and target_claims.has(reservation_key):
			continue
		if _ai_hero_task_target_snapshot_for_plan(session, target_kind, target_id).is_empty():
			continue
		var reason_codes := _normalize_string_array(candidate.get("target_reason_codes", []))
		if reason_codes.is_empty():
			reason_codes = _default_reason_codes_for_target(target_kind, target_id, {})
		if "strategic_task_planner" not in reason_codes:
			reason_codes.append("strategic_task_planner")
		var assigned_day := int(session.day)
		var task_id := ai_hero_task_candidate_id(
			String(session.scenario_id),
			faction_id,
			actor_id,
			task_class,
			target_kind,
			target_id,
			assigned_day,
			max(1, sequence)
		)
		return {
			"task_id": task_id,
			"owner_faction_id": faction_id,
			"actor_kind": "commander_roster",
			"actor_id": actor_id,
			"source_kind": "commander_role_adapter",
			"source_id": _ai_hero_task_source_id(String(session.scenario_id), faction_id, actor_id, COMMANDER_ROLE_RAIDER, target_kind, target_id, assigned_day),
			"task_class": task_class,
			"task_status": "planned",
			"target_kind": target_kind,
			"target_id": target_id,
			"front_id": commander_role_front_id(String(session.scenario_id), target_kind, target_id),
			"origin_kind": String(candidate_origin.get("kind", "town")),
			"origin_id": String(candidate_origin.get("placement_id", commander_role_origin_id(String(session.scenario_id), faction_id))),
			"origin_x": int(candidate_origin.get("x", 0)),
			"origin_y": int(candidate_origin.get("y", 0)),
			"priority_reason_codes": reason_codes,
			"assigned_day": assigned_day,
			"expires_day": assigned_day + 10,
			"continuity_policy": "persist_until_invalid",
			"route_policy": "derive_route_on_turn",
			"last_validation": "valid",
			"reservation": reservation,
			"commander_fit_bonus": int(candidate.get("commander_fit_bonus", 0)),
			"commander_fit_profile": String(candidate.get("commander_fit_profile", "")),
		}
	return {}

static func _ai_hero_task_planner_candidates_for_commander(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	actor_id: String,
	candidates: Array
) -> Array:
	var output := []
	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value.duplicate(true)
		var fit_bonus := _ai_commander_task_fit_bonus(session, faction_id, actor_id, candidate)
		candidate["commander_fit_bonus"] = fit_bonus
		candidate["commander_fit_profile"] = _ai_commander_task_fit_profile(session, faction_id, actor_id)
		candidate["priority"] = max(0, int(candidate.get("priority", 0)) + fit_bonus)
		output.append(candidate)
	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _candidate_beats(a, b)
	)
	return output

static func _ai_commander_task_fit_profile(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	actor_id: String
) -> String:
	var template := ContentService.get_hero(actor_id)
	var entry := _commander_roster_entry(commander_roster_for_faction(session, faction_id), actor_id)
	var commander_state = entry.get("commander_state", {})
	if not (commander_state is Dictionary):
		commander_state = {}
	var archetype := String(commander_state.get("archetype", template.get("archetype", "")))
	var command_path := String(template.get("command_path", ""))
	if archetype == "":
		return command_path
	if command_path == "":
		return archetype
	return "%s/%s" % [archetype, command_path]

static func _ai_commander_task_fit_bonus(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	actor_id: String,
	candidate: Dictionary
) -> int:
	if actor_id == "" or candidate.is_empty():
		return 0
	var template := ContentService.get_hero(actor_id)
	var entry := _commander_roster_entry(commander_roster_for_faction(session, faction_id), actor_id)
	var commander_state = entry.get("commander_state", {})
	if not (commander_state is Dictionary):
		commander_state = {}
	var command := _normalize_command_payload(
		commander_state.get("command", template.get("command", {}))
	)
	var attack: int = max(0, int(command.get("attack", 0)))
	var defense: int = max(0, int(command.get("defense", 0)))
	var power: int = max(0, int(command.get("power", 0)))
	var knowledge: int = max(0, int(command.get("knowledge", 0)))
	var archetype := String(commander_state.get("archetype", template.get("archetype", "")))
	var command_path := String(template.get("command_path", ""))
	var focus_ids := _normalized_specialty_focus_ids(
		_merge_unique_strings(
			commander_state.get("specialty_focus_ids", []),
			template.get("specialty_focus_ids", [])
		)
	)
	var battle_traits := _normalize_string_array(
		_merge_unique_strings(
			commander_state.get("battle_traits", []),
			template.get("battle_traits", [])
		)
	)
	var target_kind := String(candidate.get("target_kind", ""))
	var reason_codes := _normalize_string_array(candidate.get("target_reason_codes", []))
	var site_family := String(candidate.get("site_family", target_site_family(session, target_kind, String(candidate.get("target_placement_id", "")))))
	var bonus := 0

	match target_kind:
		"town":
			bonus += attack * 12
			bonus += defense * 4
			if archetype in ["raider", "marshal"]:
				bonus += 28
			if archetype in ["castellan", "warden"]:
				bonus += 10
			if command_path == "might":
				bonus += 8
		"hero":
			bonus += attack * 16
			bonus += max(0, int(template.get("base_movement", 10)) - 10) * 6
			if archetype in ["raider", "pathfinder", "marshal"]:
				bonus += 34
			if "ambusher" in battle_traits:
				bonus += 18
			if "vanguard" in battle_traits:
				bonus += 12
		"resource":
			bonus += defense * 7
			if "persistent_income_denial" in reason_codes or "recruit_denial" in reason_codes:
				bonus += attack * 7
			if archetype in ["castellan", "warden"]:
				bonus += 22
			if "ledgerkeeper" in focus_ids:
				bonus += 24
			if "mustercaptain" in focus_ids and "recruit_denial" in reason_codes:
				bonus += 18
			if "ambusher" in battle_traits and ("route_pressure" in reason_codes or "route_vision" in reason_codes):
				bonus += 16
		"artifact":
			bonus += (power + knowledge) * 12
			if command_path == "magic":
				bonus += 22
			if archetype in ["hexcaller", "starseer", "pathfinder"]:
				bonus += 28
			if "spellwright" in focus_ids:
				bonus += 26
			if "wayfinder" in focus_ids and ("route_tempo" in reason_codes or "scouting_reach" in reason_codes):
				bonus += 16
		"encounter":
			bonus += attack * 8
			bonus += power * 8
			if archetype in ["raider", "marshal", "pathfinder", "hexcaller"]:
				bonus += 18
			if "armsmaster" in focus_ids or "drillmaster" in focus_ids:
				bonus += 12
			if "spellwright" in focus_ids and ("magic_support" in reason_codes or site_family == "frontier_shrine"):
				bonus += 18

	if "town_defense" in reason_codes or "site_defense" in reason_codes or "defend_front" in reason_codes or "front_stabilization" in reason_codes:
		bonus += defense * 18
		if archetype in ["warden", "castellan"]:
			bonus += 38
		if "borderwarden" in focus_ids:
			bonus += 24
		if "linekeeper" in battle_traits:
			bonus += 16
	if "objective_front" in reason_codes:
		bonus += 12
		if archetype in ["marshal", "raider", "warden"]:
			bonus += 12
	if "hero_hunt" in reason_codes:
		bonus += attack * 10
		if "packhunter" in battle_traits:
			bonus += 18
	if "enemy_scouting" in reason_codes or "scouting_reach" in reason_codes:
		if "wayfinder" in focus_ids or archetype == "pathfinder":
			bonus += 22
	if site_family == "neutral_dwelling" and "mustercaptain" in focus_ids:
		bonus += 16
	if site_family == "faction_outpost" and ("borderwarden" in focus_ids or archetype == "warden"):
		bonus += 16
	if site_family == "frontier_shrine" and ("spellwright" in focus_ids or command_path == "magic"):
		bonus += 18
	return clampi(bonus, -80, 120)

static func _ai_hero_task_planner_class_for_candidate(candidate: Dictionary) -> String:
	var target_kind := String(candidate.get("target_kind", ""))
	var reason_codes := _normalize_string_array(candidate.get("target_reason_codes", []))
	if target_kind == "town":
		return "raid_town"
	if "town_defense" in reason_codes or "site_defense" in reason_codes or "defend_front" in reason_codes:
		return "defend_front"
	if "retake_front" in reason_codes:
		return "retake_site"
	return "contest_site"

static func _ai_hero_task_planner_candidates_from_origins(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	origins: Array
) -> Array:
	var best_by_target := {}
	for origin_value in origins:
		if not (origin_value is Dictionary):
			continue
		var origin: Dictionary = origin_value
		var origin_pos := Vector2i(int(origin.get("x", 0)), int(origin.get("y", 0)))
		for candidate_value in _target_candidates(session, config, origin_pos):
			if not (candidate_value is Dictionary):
				continue
			var candidate: Dictionary = candidate_value
			var target_kind := String(candidate.get("target_kind", ""))
			var target_id := String(candidate.get("target_placement_id", ""))
			if target_kind == "" or target_id == "":
				continue
			var key := "%s:%s" % [target_kind, target_id]
			var candidate_with_origin := candidate.duplicate(true)
			candidate_with_origin["planner_origin"] = origin.duplicate(true)
			if (
				not best_by_target.has(key)
				or _candidate_beats(candidate_with_origin, best_by_target.get(key, {}))
			):
				best_by_target[key] = candidate_with_origin
	var output := []
	for candidate_value in best_by_target.values():
		if candidate_value is Dictionary:
			output.append(candidate_value)
	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _candidate_beats(a, b)
	)
	return output

static func _ai_hero_task_planner_origins(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String
) -> Array:
	var origins := []
	var seen_tiles := {}
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		if String(town.get("owner", "neutral")) != "enemy" or _town_faction_id(town) != faction_id:
			continue
		var x := int(town.get("x", 0))
		var y := int(town.get("y", 0))
		seen_tiles["%d:%d" % [x, y]] = true
		origins.append({
			"kind": "town",
			"placement_id": String(town.get("placement_id", "")),
			"x": x,
			"y": y,
			"priority": _town_strategic_priority_bonus(session, town, faction_id, _town_is_objective_anchor(session, String(town.get("placement_id", "")))),
		})
	var spawn_points: Variant = config.get("spawn_points", [])
	if spawn_points is Array:
		for index in range(spawn_points.size()):
			var spawn_value = spawn_points[index]
			if not (spawn_value is Dictionary):
				continue
			var spawn_point: Dictionary = spawn_value
			var x := int(spawn_point.get("x", 0))
			var y := int(spawn_point.get("y", 0))
			var tile_key := "%d:%d" % [x, y]
			if seen_tiles.has(tile_key):
				continue
			seen_tiles[tile_key] = true
			origins.append({
				"kind": "spawn",
				"placement_id": "spawn:%d:%d:%d" % [x, y, index],
				"x": x,
				"y": y,
				"priority": 0,
			})
	origins.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("priority", 0)) == int(b.get("priority", 0)):
			return String(a.get("placement_id", "")) < String(b.get("placement_id", ""))
		return int(a.get("priority", 0)) > int(b.get("priority", 0))
	)
	return origins

static func _ai_hero_task_planner_origin(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String
) -> Dictionary:
	var best := {}
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		if String(town.get("owner", "neutral")) != "enemy" or _town_faction_id(town) != faction_id:
			continue
		var candidate := {
			"placement_id": String(town.get("placement_id", "")),
			"x": int(town.get("x", 0)),
			"y": int(town.get("y", 0)),
			"priority": _town_strategic_priority_bonus(session, town, faction_id, _town_is_objective_anchor(session, String(town.get("placement_id", "")))),
		}
		if best.is_empty() or int(candidate.get("priority", 0)) > int(best.get("priority", 0)):
			best = candidate
	if not best.is_empty():
		return best
	var spawn_points: Variant = config.get("spawn_points", [])
	if spawn_points is Array and not spawn_points.is_empty() and spawn_points[0] is Dictionary:
		var spawn_point: Dictionary = spawn_points[0]
		return {
			"placement_id": "",
			"x": int(spawn_point.get("x", 0)),
			"y": int(spawn_point.get("y", 0)),
			"priority": 0,
		}
	return {}

static func _ai_hero_task_planner_target_claims(tasks: Array) -> Dictionary:
	var claims := {}
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("task_status", "")) not in ["planned", "reserved", "active"]:
			continue
		var reservation: Dictionary = task.get("reservation", {}) if task.get("reservation", {}) is Dictionary else {}
		if String(reservation.get("reservation_scope", "")) != "exclusive_target":
			continue
		var reservation_key := String(reservation.get("reservation_key", ""))
		if reservation_key != "":
			claims[reservation_key] = true
	return claims

static func _ai_hero_task_planner_actor_has_open_task(tasks: Array, actor_id: String) -> bool:
	if actor_id == "":
		return false
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("actor_id", "")) == actor_id and String(task.get("task_status", "")) in ["planned", "reserved", "active", "suspended"]:
			return true
	return false

static func _ai_hero_task_planner_event(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	task: Dictionary
) -> Dictionary:
	if session == null or task.is_empty():
		return {}
	var target_kind := String(task.get("target_kind", ""))
	var target_id := String(task.get("target_id", ""))
	var target := _ai_hero_task_target_snapshot_for_plan(session, target_kind, target_id)
	if target.is_empty():
		return {}
	var faction_id := String(task.get("owner_faction_id", config.get("faction_id", "")))
	var actor_id := String(task.get("actor_id", ""))
	var actor_label := actor_id
	var entry := _commander_roster_entry(commander_roster_for_faction(session, faction_id), actor_id)
	if not entry.is_empty():
		actor_label = commander_display_name(entry, false)
		if actor_label == "":
			actor_label = actor_id
	var reason_codes := _normalize_string_array(task.get("priority_reason_codes", []))
	return {
		"event_id": "%d:%s:ai_commander_task_planned:%s:%s:%s" % [int(session.day), faction_id, actor_id, target_kind, target_id],
		"day": int(session.day),
		"sequence": 0,
		"event_type": "ai_commander_task_planned",
		"faction_id": faction_id,
		"faction_label": String(config.get("label", faction_id)),
		"actor_id": actor_id,
		"actor_label": actor_label,
		"target_kind": target_kind,
		"target_id": target_id,
		"target_label": String(target.get("target_label", target_id)),
		"target_x": int(target.get("target_x", 0)),
		"target_y": int(target.get("target_y", 0)),
		"visibility": _event_visibility(session, int(target.get("target_x", 0)), int(target.get("target_y", 0)), _ai_hero_task_public_importance(task)),
		"public_importance": _ai_hero_task_public_importance(task),
		"summary": "%s plans pressure on %s." % [actor_label, String(target.get("target_label", target_id))],
		"reason_codes": reason_codes,
		"public_reason": _public_reason_from_codes(reason_codes),
		"debug_reason": "coordinated strategic task planner",
	}

static func _ai_hero_task_write_enemy_state_for_faction(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	replacement: Dictionary
) -> void:
	if session == null or faction_id == "" or replacement.is_empty():
		return
	var states: Array = session.overworld.get("enemy_states", []) if session.overworld.get("enemy_states", []) is Array else []
	for state_index in range(states.size()):
		var state = states[state_index]
		if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
			states[state_index] = replacement
			session.overworld["enemy_states"] = states
			return

static func enemy_strategy(config: Dictionary, faction_id: String) -> Dictionary:
	var strategy = _default_enemy_strategy()
	var faction = ContentService.get_faction(faction_id)
	if faction.get("enemy_strategy", {}) is Dictionary:
		strategy = _merge_strategy_dict(strategy, faction.get("enemy_strategy", {}))
	if config.get("strategy_overrides", {}) is Dictionary:
		strategy = _merge_strategy_dict(strategy, config.get("strategy_overrides", {}))
	return strategy

static func strategy_scalar(strategy: Dictionary, section: String, key: String, default_value: float = 1.0) -> float:
	var bucket = strategy.get(section, {})
	if not (bucket is Dictionary):
		return default_value
	return float(bucket.get(key, default_value))

static func strategy_int(strategy: Dictionary, section: String, key: String, default_value: int = 0) -> int:
	var bucket = strategy.get(section, {})
	if not (bucket is Dictionary):
		return default_value
	return int(bucket.get(key, default_value))

static func strategy_target_weight(
	config: Dictionary,
	faction_id: String,
	target_kind: String,
	placement_id: String,
	site_family: String = "",
	objective_anchor: bool = false
) -> float:
	var strategy = enemy_strategy(config, faction_id)
	var weight = strategy_scalar(strategy, "raid_target_weights", target_kind, 1.0)
	if target_kind == "town" and placement_id == String(config.get("siege_target_placement_id", "")):
		weight *= max(0.6, strategy_scalar(strategy, "raid", "town_siege_weight", 1.0))
	elif objective_anchor:
		weight *= max(0.6, strategy_scalar(strategy, "raid", "objective_weight", 1.0))
	if target_kind == "hero":
		weight *= max(0.6, strategy_scalar(strategy, "raid", "hero_hunt_weight", 1.0))
	if site_family != "":
		weight *= max(0.6, strategy_scalar(strategy, "site_family_weights", site_family, 1.0))
		if target_kind == "resource":
			weight *= max(0.6, strategy_scalar(strategy, "raid", "site_denial_weight", 1.0))
	return max(0.4, weight)

static func priority_target_bonus(config: Dictionary, placement_id: String) -> int:
	if placement_id == "":
		return 0
	var priority_targets = config.get("priority_target_placement_ids", [])
	if not (priority_targets is Array):
		return 0
	for priority_target in priority_targets:
		if String(priority_target) == placement_id:
			return max(0, int(config.get("priority_target_bonus", 95)))
	return 0

static func public_strategy_summary(config: Dictionary, faction_id: String) -> String:
	match faction_id:
		"faction_embercourt":
			if not (config.get("priority_target_placement_ids", []) is Array) or config.get("priority_target_placement_ids", []).is_empty():
				return "Priorities: hold towns, reinforce outposts, and grind forward on siege lanes"
			return "Priorities: stabilize the line, defend charter assets, and press key crossings"
		"faction_mireclaw":
			return "Priorities: cut logistics sites, chase exposed heroes, and keep raids rolling"
		"faction_sunvault":
			return "Priorities: secure relays and shrines, then align focused pushes on objectives"
		"faction_thornwake":
			return "Priorities: root roads, hold nurseries, and turn neutral lanes into recovery zones"
		"faction_brasshollow":
			return "Priorities: secure mines, stage siege engines, and exhaust resource fronts"
		"faction_veilmourn":
			return "Priorities: scout hidden routes, mark weak backs, and raid through fog lanes"
		_:
			return "Priorities: pressure objectives while contesting frontier assets"

static func target_site_family(session: SessionStateStoreScript.SessionData, target_kind: String, placement_id: String) -> String:
	if target_kind != "resource" or placement_id == "":
		return ""
	var resource_result = _find_resource_by_placement(session, placement_id)
	if int(resource_result.get("index", -1)) < 0:
		return ""
	return String(ContentService.get_resource_site(String(resource_result.get("node", {}).get("site_id", ""))).get("family", ""))

static func target_is_objective_anchor(session: SessionStateStoreScript.SessionData, target_kind: String, placement_id: String) -> bool:
	match target_kind:
		"town":
			return _town_is_objective_anchor(session, placement_id)
		"encounter":
			var encounter_result = _find_encounter_by_placement(session, placement_id)
			return int(encounter_result.get("index", -1)) >= 0 and _encounter_is_objective_anchor(session, encounter_result.get("encounter", {}))
		_:
			return false

static func pressuring_raid_count(session: SessionStateStoreScript.SessionData, faction_id: String, target_placement_id: String) -> int:
	var count = 0
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not _is_active_raid(encounter, faction_id, resolved_encounters):
			continue
		if String(encounter.get("target_placement_id", "")) != target_placement_id:
			continue
		if bool(encounter.get("arrived", false)) or int(encounter.get("goal_distance", 9999)) == 0:
			count += 1
	return count

static func describe_focus(session: SessionStateStoreScript.SessionData, faction_id: String, public_only: bool = false) -> String:
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	var marching_counts = {}
	var pressure_counts = {}
	for encounter in session.overworld.get("encounters", []):
		if not _is_active_raid(encounter, faction_id, resolved_encounters):
			continue
		if public_only and not _raid_is_public(session, encounter):
			continue
		var target_label = _raid_focus_label(encounter, public_only)
		if bool(encounter.get("arrived", false)) or int(encounter.get("goal_distance", 9999)) == 0:
			pressure_counts[target_label] = int(pressure_counts.get(target_label, 0)) + 1
		else:
			marching_counts[target_label] = int(marching_counts.get(target_label, 0)) + 1

	var parts = []
	var marching = _describe_count_map("march on", marching_counts)
	if marching != "":
		parts.append(marching)
	var pressuring = _describe_count_map("press", pressure_counts)
	if pressuring != "":
		parts.append(pressuring)
	return " | ".join(parts)

static func _raid_focus_label(encounter: Dictionary, public_only: bool = false) -> String:
	var label := String(encounter.get("target_label", "the frontier"))
	var reason := String(encounter.get("target_public_reason", ""))
	if reason == "":
		return label
	if public_only and String(encounter.get("target_public_importance", "low")) == "low":
		return label
	return "%s (%s)" % [label, reason]

static func describe_contestation(session: SessionStateStoreScript.SessionData, faction_id: String, public_only: bool = false) -> String:
	var secured_sites = 0
	var seized_relics = 0
	var contested_fronts = []
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		if String(node.get("collected_by_faction_id", "")) != faction_id:
			continue
		if public_only and not OverworldRulesScript.is_tile_visible(session, int(node.get("x", -1)), int(node.get("y", -1))):
			continue
		secured_sites += 1
	for node in session.overworld.get("artifact_nodes", []):
		if not (node is Dictionary):
			continue
		if String(node.get("collected_by_faction_id", "")) != faction_id:
			continue
		if public_only and not OverworldRulesScript.is_tile_visible(session, int(node.get("x", -1)), int(node.get("y", -1))):
			continue
		seized_relics += 1
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if OverworldRulesScript.is_encounter_resolved(session, encounter):
			continue
		if String(encounter.get("contested_by_faction_id", "")) != faction_id:
			continue
		if public_only and not OverworldRulesScript.is_tile_visible(session, int(encounter.get("x", -1)), int(encounter.get("y", -1))):
			continue
		var encounter_template = ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
		var label = String(encounter_template.get("name", encounter.get("placement_id", "frontier camp")))
		if label != "" and label not in contested_fronts:
			contested_fronts.append(label)

	var parts = []
	if secured_sites > 0:
		parts.append("%d secured site%s" % [secured_sites, "" if secured_sites == 1 else "s"])
	if seized_relics > 0:
		parts.append("%d seized relic%s" % [seized_relics, "" if seized_relics == 1 else "s"])
	if not contested_fronts.is_empty():
		parts.append("contests %s" % ", ".join(contested_fronts.slice(0, min(2, contested_fronts.size()))))
	return " | ".join(parts)

static func visible_raid_count(session: SessionStateStoreScript.SessionData, faction_id: String) -> int:
	var count = 0
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not _is_active_raid(encounter, faction_id, resolved_encounters):
			continue
		if _raid_is_public(session, encounter):
			count += 1
	return count

static func raid_strength(encounter: Dictionary) -> int:
	var normalized_army = _normalize_army_payload(encounter.get("enemy_army", {}))
	if normalized_army.is_empty():
		normalized_army = _base_enemy_army(String(encounter.get("encounter_id", encounter.get("id", ""))))
	return _army_strength(normalized_army.get("stacks", []))

static func desired_raid_strength(encounter: Dictionary) -> int:
	var base_strength: int = max(
		120,
		_army_strength(
			_base_enemy_army(String(encounter.get("encounter_id", encounter.get("id", "")))).get("stacks", [])
		)
	)
	var multiplier = 1.1
	match String(encounter.get("target_kind", "")):
		"town":
			multiplier = 1.45
		"hero":
			multiplier = 1.25
		"encounter":
			multiplier = 1.35
		"artifact":
			multiplier = 1.25
		"resource":
			multiplier = 1.15
	if String(encounter.get("delivery_intercept_node_placement_id", "")) != "":
		multiplier = max(multiplier, 1.4)
	if bool(encounter.get("arrived", false)):
		multiplier += 0.15
	var commander_state = encounter.get("enemy_commander_state", {})
	var commander_record := _normalized_commander_record(commander_state)
	var veterancy_bonus: int = (max(0, int(commander_record.get("renown", 0))) * 16) + (
		_commander_veterancy_rank_from_record(commander_record) * 12
	)
	match String(commander_record.get("last_outcome", "")):
		COMMANDER_OUTCOME_ROUT_VICTORY:
			multiplier += 0.18
		COMMANDER_OUTCOME_PURSUIT_VICTORY:
			multiplier += 0.1
		COMMANDER_OUTCOME_CAPITULATION:
			multiplier += 0.06
	return int(round(float(base_strength) * multiplier)) + veterancy_bonus

static func raid_regroup_needed(encounter: Dictionary) -> bool:
	if encounter.is_empty():
		return false
	if bool(encounter.get("arrived", false)) and String(encounter.get("target_kind", "")) != "regroup":
		return false
	var desired: int = max(1, desired_raid_strength(encounter))
	var current: int = max(0, raid_strength(encounter))
	var regroup_floor: int = max(45, int(round(float(desired) * 0.55)))
	return current > 0 and current < regroup_floor

static func raid_pillage_weight(encounter: Dictionary) -> int:
	var base_strength: int = max(
		1,
		_army_strength(
			_base_enemy_army(String(encounter.get("encounter_id", encounter.get("id", "")))).get("stacks", [])
		)
	)
	var current_strength: int = max(1, raid_strength(encounter))
	return clamp(int(ceili(float(current_strength) / float(base_strength))), 1, 3)

static func _target_candidates(session: SessionStateStoreScript.SessionData, config: Dictionary, origin_pos: Vector2i) -> Array:
	var seen = {}
	var candidates = []
	var faction_id = String(config.get("faction_id", ""))
	var scenario = ContentService.get_scenario(session.scenario_id)
	var siege_target_id = String(config.get("siege_target_placement_id", ""))
	if siege_target_id != "":
		_append_town_candidate(session, candidates, seen, siege_target_id, origin_pos, 320, config, faction_id)

	var objectives = scenario.get("objectives", {})
	if objectives is Dictionary:
		for objective in objectives.get("defeat", []):
			if objective is Dictionary and String(objective.get("type", "")) in ["town_owned_by_player", "town_not_owned_by_player"]:
				_append_town_candidate(session, candidates, seen, String(objective.get("placement_id", "")), origin_pos, 260, config, faction_id)
		for objective in objectives.get("victory", []):
			if objective is Dictionary and String(objective.get("type", "")) in ["town_owned_by_player", "town_not_owned_by_player"]:
				_append_town_candidate(session, candidates, seen, String(objective.get("placement_id", "")), origin_pos, 220, config, faction_id)

	for town in session.overworld.get("towns", []):
		if not (town is Dictionary):
			continue
		if String(town.get("owner", "neutral")) != "player":
			continue
		var base_priority = 180
		if _town_started_enemy(session, String(town.get("placement_id", ""))):
			base_priority += 50
		if _town_is_objective_anchor(session, String(town.get("placement_id", ""))):
			base_priority += 20
		_append_town_candidate(session, candidates, seen, String(town.get("placement_id", "")), origin_pos, base_priority, config, faction_id)
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary):
			continue
		if String(town.get("owner", "neutral")) != "neutral":
			continue
		var base_priority = 145
		if _town_garrison_strength(town) > 0:
			base_priority += 25
		if _town_is_objective_anchor(session, String(town.get("placement_id", ""))):
			base_priority += 45
		_append_town_candidate(session, candidates, seen, String(town.get("placement_id", "")), origin_pos, base_priority, config, faction_id)

	for node in session.overworld.get("resource_nodes", []):
		_append_resource_candidate(
			session,
			candidates,
			seen,
			node,
			origin_pos,
			config,
			faction_id
		)

	for node in session.overworld.get("artifact_nodes", []):
		_append_artifact_candidate(
			session,
			candidates,
			seen,
			node,
			origin_pos,
			_artifact_target_priority(session, node),
			config,
			faction_id
		)

	for encounter in session.overworld.get("encounters", []):
		_append_encounter_candidate(
			session,
			candidates,
			seen,
			encounter,
			origin_pos,
			_encounter_target_priority(session, encounter),
			config,
			faction_id
		)

	_append_delivery_interception_candidates(session, candidates, seen, origin_pos, config, faction_id)

	var hero_candidates = _hero_target_candidates(session, origin_pos, config, faction_id)
	for hero_candidate in hero_candidates:
		if hero_candidate is Dictionary and not hero_candidate.is_empty():
			candidates.append(hero_candidate)
	return candidates

static func _append_town_candidate(
	session: SessionStateStoreScript.SessionData,
	candidates: Array,
	seen: Dictionary,
	placement_id: String,
	origin_pos: Vector2i,
	priority: int,
	config: Dictionary,
	faction_id: String
) -> void:
	var seen_key = "town:%s" % placement_id
	if placement_id == "" or seen.has(seen_key):
		return
	var town_result = _find_town_by_placement(session, placement_id)
	if int(town_result.get("index", -1)) < 0:
		return
	var town = town_result.get("town", {})
	var owner := String(town.get("owner", "neutral"))
	var neutral_expansion := owner == "neutral"
	if owner != "player" and not neutral_expansion:
		return

	seen[seen_key] = true
	var staging_tiles = _town_staging_tiles(session, town)
	var goal_tile = _best_goal_tile(session, origin_pos, staging_tiles)
	var goal_distance = _path_distance(session, origin_pos, staging_tiles, "")
	if goal_distance >= 9999:
		return
	var objective_anchor = _town_is_objective_anchor(session, placement_id)
	var strategic_bonus = _town_strategic_priority_bonus(session, town, faction_id, objective_anchor)
	var reason_codes := ["town_expansion", "neutral_town_claim"] if neutral_expansion else ["town_siege"]
	if neutral_expansion and _town_garrison_strength(town) > 0:
		reason_codes.append("neutral_town_siege")
	if objective_anchor and "objective_front" not in reason_codes:
		reason_codes.append("objective_front")
	var scouting_bonus := _enemy_scouted_target_priority_bonus(session, faction_id, "town", placement_id)
	if scouting_bonus > 0 and "enemy_scouting" not in reason_codes:
		reason_codes.append("enemy_scouting")
	candidates.append(
		{
			"target_kind": "town",
			"target_placement_id": placement_id,
			"target_label": _town_name(town),
			"target_x": int(town.get("x", 0)),
			"target_y": int(town.get("y", 0)),
			"goal_x": goal_tile.x,
			"goal_y": goal_tile.y,
			"goal_distance": goal_distance,
			"priority": max(
				0,
				_weighted_priority(
					config,
					faction_id,
					"town",
					placement_id,
					priority + strategic_bonus + scouting_bonus,
					"",
					objective_anchor
				) - _assignment_penalty(session, "town", placement_id)
			),
			"target_reason_codes": reason_codes,
			"target_public_reason": (
				"neutral town expansion"
				if neutral_expansion
				else "town siege remains the main front" if placement_id == String(config.get("siege_target_placement_id", ""))
				else "town front pressure"
			),
			"target_debug_reason": (
				(
					"reachable defended neutral town expansion"
					if _town_garrison_strength(town) > 0
					else "reachable empty neutral town expansion"
				)
				if neutral_expansion
				else "town siege and objective pressure" if objective_anchor
				else "town siege pressure"
			),
			"target_public_importance": "high" if neutral_expansion else "critical" if objective_anchor or placement_id == String(config.get("siege_target_placement_id", "")) else "high",
		}
	)

static func _append_resource_candidate(
	session: SessionStateStoreScript.SessionData,
	candidates: Array,
	seen: Dictionary,
	node: Variant,
	origin_pos: Vector2i,
	config: Dictionary,
	faction_id: String
) -> void:
	if not (node is Dictionary):
		return
	var placement_id = String(node.get("placement_id", ""))
	var seen_key = "resource:%s" % placement_id
	var site = ContentService.get_resource_site(String(node.get("site_id", "")))
	if placement_id == "" or seen.has(seen_key) or not _resource_node_contestable_by_faction(node, site, faction_id):
		return
	seen[seen_key] = true
	var goal_tile = Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	var goal_distance = _path_distance(session, origin_pos, [goal_tile], "")
	if goal_distance >= 9999:
		return
	var breakdown := resource_target_score_breakdown(session, config, node, origin_pos, faction_id)
	var scouting_bonus := _enemy_scouted_target_priority_bonus(session, faction_id, "resource", placement_id)
	var priority := int(breakdown.get("final_priority", 0)) + scouting_bonus
	var reason_codes: Array = _normalize_string_array(breakdown.get("reason_codes", []))
	if scouting_bonus > 0 and "enemy_scouting" not in reason_codes:
		reason_codes.append("enemy_scouting")
	candidates.append(
		{
			"target_kind": "resource",
			"target_placement_id": placement_id,
			"target_label": String(site.get("name", "Resource Site")),
			"target_x": goal_tile.x,
			"target_y": goal_tile.y,
			"goal_x": goal_tile.x,
			"goal_y": goal_tile.y,
			"goal_distance": goal_distance,
			"priority": priority,
			"site_family": String(site.get("family", "")),
			"target_debug_reason": String(breakdown.get("debug_reason", "")),
			"target_reason_codes": reason_codes,
			"target_public_reason": String(breakdown.get("public_reason", "")),
			"target_public_importance": String(breakdown.get("public_importance", "low")),
		}
	)

static func _append_artifact_candidate(
	session: SessionStateStoreScript.SessionData,
	candidates: Array,
	seen: Dictionary,
	node: Variant,
	origin_pos: Vector2i,
	priority: int,
	config: Dictionary,
	faction_id: String
) -> void:
	if not (node is Dictionary):
		return
	var placement_id = String(node.get("placement_id", ""))
	var seen_key = "artifact:%s" % placement_id
	if placement_id == "" or seen.has(seen_key) or bool(node.get("collected", false)):
		return
	seen[seen_key] = true
	var goal_tile = Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	var goal_distance = _path_distance(session, origin_pos, [goal_tile], "")
	if goal_distance >= 9999:
		return
	var breakdown := artifact_target_valuation_breakdown(session, config, node, origin_pos, faction_id)
	var scouting_bonus := _enemy_scouted_target_priority_bonus(session, faction_id, "artifact", placement_id)
	var reason_codes: Array = _normalize_string_array(breakdown.get("reason_codes", []))
	if scouting_bonus > 0 and "enemy_scouting" not in reason_codes:
		reason_codes.append("enemy_scouting")
	candidates.append(
		{
			"target_kind": "artifact",
			"target_placement_id": placement_id,
			"target_label": ArtifactRulesScript.describe_artifact(String(node.get("artifact_id", ""))),
			"target_x": goal_tile.x,
			"target_y": goal_tile.y,
			"goal_x": goal_tile.x,
			"goal_y": goal_tile.y,
			"goal_distance": goal_distance,
			"priority": max(
				0,
				_weighted_priority(
					config,
					faction_id,
					"artifact",
					placement_id,
					priority + scouting_bonus,
					"",
					false
				) - _assignment_penalty(session, "artifact", placement_id)
			),
			"target_reason_codes": reason_codes,
			"target_public_reason": String(breakdown.get("public_reason", "")),
			"target_public_importance": String(breakdown.get("public_importance", "medium")),
		}
	)

static func _append_encounter_candidate(
	session: SessionStateStoreScript.SessionData,
	candidates: Array,
	seen: Dictionary,
	encounter: Variant,
	origin_pos: Vector2i,
	priority: int,
	config: Dictionary,
	faction_id: String
) -> void:
	if not (encounter is Dictionary):
		return
	if String(encounter.get("spawned_by_faction_id", "")) != "":
		return
	if OverworldRulesScript.is_encounter_resolved(session, encounter):
		return
	var placement_id = String(encounter.get("placement_id", ""))
	var seen_key = "encounter:%s" % placement_id
	if placement_id == "" or seen.has(seen_key):
		return
	seen[seen_key] = true
	var staging_tiles = _encounter_staging_tiles(session, encounter)
	var goal_distance = _path_distance(session, origin_pos, staging_tiles, "")
	var goal_tile = _best_goal_tile(session, origin_pos, staging_tiles)
	var priority_bonus := priority_target_bonus(config, placement_id)
	if goal_distance >= 9999 and priority_bonus > 0:
		var encounter_tile := Vector2i(int(encounter.get("x", 0)), int(encounter.get("y", 0)))
		var direct_distance: int = abs(origin_pos.x - encounter_tile.x) + abs(origin_pos.y - encounter_tile.y)
		if direct_distance <= 3:
			goal_distance = direct_distance
			goal_tile = encounter_tile
	if goal_distance >= 9999:
		return
	var encounter_template = ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	var objective_anchor = _encounter_is_objective_anchor(session, encounter)
	var object_breakdown := neutral_encounter_object_valuation_breakdown(session, config, encounter, origin_pos, faction_id)
	var reason_codes: Array = _normalize_string_array(object_breakdown.get("reason_codes", []))
	if reason_codes.is_empty():
		reason_codes = _default_reason_codes_for_target("encounter", placement_id, {"objective_anchor": objective_anchor})
	if priority_bonus > 0 and "objective_front" not in reason_codes:
		reason_codes.append("objective_front")
	var scouting_bonus := _enemy_scouted_target_priority_bonus(session, faction_id, "encounter", placement_id)
	if scouting_bonus > 0 and "enemy_scouting" not in reason_codes:
		reason_codes.append("enemy_scouting")
	var public_reason := String(object_breakdown.get("public_reason", ""))
	if public_reason == "":
		public_reason = _public_reason_from_codes(reason_codes)
	var public_importance := String(object_breakdown.get("public_importance", _default_public_importance("encounter", reason_codes)))
	var debug_reason := String(object_breakdown.get("debug_reason", "neutral encounter pressure"))
	var metadata_priority := int(object_breakdown.get("object_metadata_value", 0))
	candidates.append(
		{
			"target_kind": "encounter",
			"target_placement_id": placement_id,
			"target_label": String(encounter_template.get("name", "Frontier Camp")),
			"target_x": int(encounter.get("x", 0)),
			"target_y": int(encounter.get("y", 0)),
			"goal_x": goal_tile.x,
			"goal_y": goal_tile.y,
			"goal_distance": goal_distance,
			"priority": max(
				0,
				_weighted_priority(
					config,
					faction_id,
					"encounter",
					placement_id,
					priority + metadata_priority + scouting_bonus,
					"",
					objective_anchor
				) - _assignment_penalty(session, "encounter", placement_id)
			),
			"target_debug_reason": debug_reason,
			"target_reason_codes": reason_codes,
			"target_public_reason": public_reason,
			"target_public_importance": public_importance,
		}
	)

static func _append_delivery_interception_candidates(
	session: SessionStateStoreScript.SessionData,
	candidates: Array,
	seen: Dictionary,
	origin_pos: Vector2i,
	config: Dictionary,
	faction_id: String
) -> void:
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var placement_id := String(node.get("placement_id", ""))
		var seen_key := "delivery:%s" % placement_id
		if placement_id == "" or seen.has(seen_key):
			continue
		var site: Dictionary = ContentService.get_resource_site(String(node.get("site_id", "")))
		var delivery_state: Dictionary = OverworldRulesScript._resource_site_delivery_state(session, node, site)
		if not bool(delivery_state.get("active", false)) or String(delivery_state.get("controller_id", "")) != "player":
			continue
		seen[seen_key] = true
		match String(delivery_state.get("target_kind", "")):
			"town":
				var town_candidate: Dictionary = _delivery_town_candidate(session, origin_pos, config, faction_id, node, site, delivery_state)
				if not town_candidate.is_empty():
					candidates.append(town_candidate)
			"hero":
				var hero_candidate: Dictionary = _delivery_hero_candidate(session, origin_pos, config, faction_id, node, site, delivery_state)
				if not hero_candidate.is_empty():
					candidates.append(hero_candidate)

static func _delivery_town_candidate(
	session: SessionStateStoreScript.SessionData,
	origin_pos: Vector2i,
	config: Dictionary,
	faction_id: String,
	node: Dictionary,
	site: Dictionary,
	delivery_state: Dictionary
) -> Dictionary:
	var town_result = _find_town_by_placement(session, String(delivery_state.get("target_id", "")))
	if int(town_result.get("index", -1)) < 0:
		return {}
	var town: Dictionary = town_result.get("town", {})
	if String(town.get("owner", "neutral")) != "player":
		return {}
	var staging_tiles = _town_staging_tiles(session, town)
	var goal_distance = _path_distance(session, origin_pos, staging_tiles, "")
	if goal_distance >= 9999:
		return {}
	var goal_tile = _best_goal_tile(session, origin_pos, staging_tiles)
	var logistics: Dictionary = OverworldRulesScript.town_logistics_state(session, town)
	var recovery: Dictionary = OverworldRulesScript.town_recovery_state(session, town)
	var capital_project: Dictionary = OverworldRulesScript.town_capital_project_state(town, session)
	var objective_anchor := _town_is_objective_anchor(session, String(town.get("placement_id", "")))
	var priority = 210 + int(min(180.0, float(int(delivery_state.get("manifest_value", 0))) / 9.0))
	priority += int(max(0, 3 - int(delivery_state.get("days_remaining", 0)))) * 24
	priority += _town_strategic_priority_bonus(session, town, faction_id, objective_anchor)
	priority += int(logistics.get("support_gap", 0)) * 18
	priority += int(logistics.get("delivery_count", 0)) * 12
	priority += int(recovery.get("pressure", 0)) * 12
	if bool(capital_project.get("vulnerable", false)):
		priority += 26
	return {
		"target_kind": "town",
		"target_placement_id": String(town.get("placement_id", "")),
		"target_label": "%s relief lane" % _town_name(town),
		"target_x": int(town.get("x", 0)),
		"target_y": int(town.get("y", 0)),
		"goal_x": goal_tile.x,
		"goal_y": goal_tile.y,
		"goal_distance": goal_distance,
		"priority": max(
			0,
			_weighted_priority(
				config,
				faction_id,
				"town",
				String(town.get("placement_id", "")),
				priority,
				"",
				objective_anchor
			) - _assignment_penalty(session, "town", String(town.get("placement_id", "")))
		),
		"delivery_intercept_node_placement_id": String(node.get("placement_id", "")),
		"delivery_intercept_target_kind": "town",
		"delivery_intercept_target_id": String(town.get("placement_id", "")),
		"delivery_intercept_label": "%s convoy to %s" % [
			String(site.get("name", "Frontier route")),
			String(delivery_state.get("target_label", _town_name(town))),
		],
	}

static func _delivery_hero_candidate(
	session: SessionStateStoreScript.SessionData,
	origin_pos: Vector2i,
	config: Dictionary,
	faction_id: String,
	node: Dictionary,
	site: Dictionary,
	delivery_state: Dictionary
) -> Dictionary:
	var hero: Dictionary = _find_player_hero(session, String(delivery_state.get("target_id", "")))
	if hero.is_empty():
		return {}
	var goal_tile := _player_hero_goal_tile(hero)
	var goal_distance = _path_distance(session, origin_pos, [goal_tile], "")
	if goal_distance >= 9999:
		return {}
	var priority = 195 + int(min(170.0, float(int(delivery_state.get("manifest_value", 0))) / 10.0))
	priority += int(max(0, 3 - int(delivery_state.get("days_remaining", 0)))) * 22
	if String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
		priority += 28
	if bool(hero.get("is_primary", false)):
		priority += 20
	var hero_strength: int = _army_strength(hero.get("army", {}).get("stacks", []))
	if hero_strength <= 110:
		priority += 34
	elif hero_strength <= 180:
		priority += 18
	return {
		"target_kind": "hero",
		"target_placement_id": String(hero.get("id", "")),
		"target_label": "%s convoy" % String(hero.get("name", "the hero")),
		"target_x": goal_tile.x,
		"target_y": goal_tile.y,
		"goal_x": goal_tile.x,
		"goal_y": goal_tile.y,
		"goal_distance": goal_distance,
		"priority": max(
			0,
			_weighted_priority(
				config,
				faction_id,
				"hero",
				String(hero.get("id", "")),
				priority,
				"",
				false
			) - _assignment_penalty(session, "hero", String(hero.get("id", "")))
		),
		"delivery_intercept_node_placement_id": String(node.get("placement_id", "")),
		"delivery_intercept_target_kind": "hero",
		"delivery_intercept_target_id": String(hero.get("id", "")),
		"delivery_intercept_label": "%s convoy to %s" % [
			String(site.get("name", "Frontier route")),
			String(hero.get("name", "the hero")),
		],
	}

static func _hero_target_candidates(
	session: SessionStateStoreScript.SessionData,
	origin_pos: Vector2i,
	config: Dictionary,
	faction_id: String
) -> Array:
	var candidates := []
	var seen_hero_ids := {}
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	for hero_value in session.overworld.get("player_heroes", []):
		if not (hero_value is Dictionary):
			continue
		var hero: Dictionary = hero_value
		var hero_id := String(hero.get("id", ""))
		if hero_id == "":
			continue
		seen_hero_ids[hero_id] = true
		_append_hero_target_candidate(session, candidates, hero, origin_pos, config, faction_id, active_hero_id)
	if active_hero_id != "" and not seen_hero_ids.has(active_hero_id):
		var active_hero_value = session.overworld.get("hero", {})
		if active_hero_value is Dictionary:
			var active_hero: Dictionary = active_hero_value.duplicate(true)
			active_hero["id"] = active_hero_id
			var active_position = active_hero.get("position", {})
			if not (active_position is Dictionary) or active_position.is_empty():
				var position_source = session.overworld.get("hero_position", {"x": 0, "y": 0})
				if position_source is Dictionary:
					active_hero["position"] = position_source.duplicate(true)
			active_hero["is_primary"] = true
			_append_hero_target_candidate(session, candidates, active_hero, origin_pos, config, faction_id, active_hero_id)
	return candidates

static func _append_hero_target_candidate(
	session: SessionStateStoreScript.SessionData,
	candidates: Array,
	hero: Dictionary,
	origin_pos: Vector2i,
	config: Dictionary,
	faction_id: String,
	active_hero_id: String
) -> void:
	var hero_id := String(hero.get("id", ""))
	if hero_id == "":
		return
	var goal_tile := _player_hero_goal_tile(hero)
	var goal_distance: int = _hero_target_goal_distance(session, origin_pos, goal_tile)
	if goal_distance >= 9999:
		return
	var priority = 95
	if hero_id == active_hero_id:
		priority += 26
	if bool(hero.get("is_primary", false)):
		priority += 18
	var army_strength: int = _army_strength(hero.get("army", {}).get("stacks", []))
	if army_strength <= 110:
		priority += 26
	elif army_strength <= 180:
		priority += 14
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "enemy":
			continue
		var distance: int = abs(goal_tile.x - int(town.get("x", 0))) + abs(goal_tile.y - int(town.get("y", 0)))
		if distance > 6:
			continue
		var defense_priority: int = 120 + max(0, (6 - distance) * 10)
		match OverworldRulesScript.town_strategic_role(town):
			"capital":
				defense_priority += 44
			"stronghold":
				defense_priority += 24
		if int(OverworldRulesScript.town_capital_project_state(town, session).get("active", 0)) > 0:
			defense_priority += 24
		if _town_is_objective_anchor(session, String(town.get("placement_id", ""))):
			defense_priority += 28
		priority = max(priority, defense_priority)
	candidates.append(
		{
			"target_kind": "hero",
			"target_placement_id": hero_id,
			"target_label": String(hero.get("name", "the hero")),
			"target_x": goal_tile.x,
			"target_y": goal_tile.y,
			"goal_x": goal_tile.x,
			"goal_y": goal_tile.y,
			"goal_distance": goal_distance,
			"target_reason_codes": ["hero_hunt", "exposed_hero"],
			"target_public_reason": "exposed hero",
			"target_public_importance": "high",
			"priority": max(
				0,
				_weighted_priority(config, faction_id, "hero", hero_id, priority, "", false)
				- _assignment_penalty(session, "hero", hero_id)
			),
		}
	)

static func _hero_target_goal_distance(
	session: SessionStateStoreScript.SessionData,
	origin_pos: Vector2i,
	goal_tile: Vector2i
) -> int:
	var direct_distance: int = _path_distance(session, origin_pos, [goal_tile], "")
	if direct_distance < 9999:
		return direct_distance

	var occupied := _occupied_tiles(session, "")
	if not occupied.has(_pos_key(goal_tile)):
		return direct_distance

	var approach_tiles: Array = []
	var map_size: Vector2i = OverworldRulesScript.derive_map_size(session)
	for delta in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var approach_tile: Vector2i = goal_tile + delta
		if approach_tile.x < 0 or approach_tile.y < 0 or approach_tile.x >= map_size.x or approach_tile.y >= map_size.y:
			continue
		if OverworldRulesScript.tile_is_blocked(session, approach_tile.x, approach_tile.y):
			continue
		if approach_tile != origin_pos and occupied.has(_pos_key(approach_tile)):
			continue
		approach_tiles.append(approach_tile)

	var approach_distance: int = _path_distance(session, origin_pos, approach_tiles, "")
	if approach_distance >= 9999:
		return direct_distance
	return approach_distance + 1

static func _hero_target_goal_tiles(
	session: SessionStateStoreScript.SessionData,
	origin_pos: Vector2i,
	goal_tile: Vector2i,
	ignore_placement_id: String = ""
) -> Array:
	var occupied := _occupied_tiles(session, ignore_placement_id)
	if not occupied.has(_pos_key(goal_tile)):
		return [goal_tile]
	var approach_tiles: Array = []
	var map_size: Vector2i = OverworldRulesScript.derive_map_size(session)
	for delta in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var approach_tile: Vector2i = goal_tile + delta
		if approach_tile.x < 0 or approach_tile.y < 0 or approach_tile.x >= map_size.x or approach_tile.y >= map_size.y:
			continue
		if OverworldRulesScript.tile_is_blocked(session, approach_tile.x, approach_tile.y):
			continue
		if approach_tile != origin_pos and occupied.has(_pos_key(approach_tile)):
			continue
		approach_tiles.append(approach_tile)
	return approach_tiles

static func _find_player_hero(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	if session == null or hero_id == "":
		return {}
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary and String(hero.get("id", "")) == hero_id:
			return hero
	return {}

static func _player_hero_snapshot_for_task(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	if session == null or hero_id == "":
		return {}
	var hero := _find_player_hero(session, hero_id)
	if not hero.is_empty():
		return hero
	if hero_id != String(session.overworld.get("active_hero_id", "")):
		return {}
	var active_hero_value = session.overworld.get("hero", {})
	if not (active_hero_value is Dictionary) or active_hero_value.is_empty():
		return {}
	var active_hero: Dictionary = active_hero_value.duplicate(true)
	active_hero["id"] = hero_id
	var position_value = active_hero.get("position", {})
	if not (position_value is Dictionary) or position_value.is_empty():
		var position_source = session.overworld.get("hero_position", {"x": 0, "y": 0})
		if position_source is Dictionary:
			active_hero["position"] = position_source.duplicate(true)
	return active_hero

static func _player_hero_goal_tile(hero: Dictionary) -> Vector2i:
	var hero_position: Dictionary = hero.get("position", {})
	return Vector2i(int(hero_position.get("x", 0)), int(hero_position.get("y", 0)))

static func _hero_position_for_target(session: SessionStateStoreScript.SessionData, hero_id: String) -> Vector2i:
	if hero_id != "":
		var hero := _find_player_hero(session, hero_id)
		if not hero.is_empty():
			return _player_hero_goal_tile(hero)
	var hero_position: Dictionary = session.overworld.get("hero_position", {"x": 0, "y": 0})
	return Vector2i(int(hero_position.get("x", 0)), int(hero_position.get("y", 0)))

static func _hero_label_for_target(session: SessionStateStoreScript.SessionData, hero_id: String) -> String:
	if hero_id != "":
		var hero := _find_player_hero(session, hero_id)
		if not hero.is_empty():
			return String(hero.get("name", hero_id))
	return String(session.overworld.get("hero", {}).get("name", "the hero"))

static func _candidate_beats(candidate: Dictionary, best: Dictionary) -> bool:
	if int(candidate.get("priority", 0)) == int(best.get("priority", 0)):
		if int(candidate.get("goal_distance", 9999)) == int(best.get("goal_distance", 9999)):
			return String(candidate.get("target_label", "")) < String(best.get("target_label", ""))
		return int(candidate.get("goal_distance", 9999)) < int(best.get("goal_distance", 9999))
	return int(candidate.get("priority", 0)) > int(best.get("priority", 0))

static func resource_pressure_report(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	origin: Dictionary,
	faction_id: String = "",
	limit: int = 0
) -> Dictionary:
	var resolved_faction_id := faction_id
	if resolved_faction_id == "":
		resolved_faction_id = String(config.get("faction_id", ""))
	var origin_pos := Vector2i(int(origin.get("x", 0)), int(origin.get("y", 0)))
	var targets := []
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var breakdown := resource_target_score_breakdown(session, config, node_value, origin_pos, resolved_faction_id)
		if int(breakdown.get("final_priority", 0)) <= 0:
			continue
		targets.append(breakdown)
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("final_priority", 0)) == int(b.get("final_priority", 0)):
			if int(a.get("travel_cost", 0)) == int(b.get("travel_cost", 0)):
				return String(a.get("placement_id", "")) < String(b.get("placement_id", ""))
			return int(a.get("travel_cost", 0)) < int(b.get("travel_cost", 0))
		return int(a.get("final_priority", 0)) > int(b.get("final_priority", 0))
	)
	if limit > 0 and targets.size() > limit:
		targets = targets.slice(0, limit)
	return {
		"scenario_id": String(session.scenario_id),
		"faction_id": resolved_faction_id,
		"origin": {"x": origin_pos.x, "y": origin_pos.y},
		"target_count": targets.size(),
		"targets": targets,
	}

static func resource_pressure_target_report(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	origin: Dictionary,
	target_placement_id: String,
	faction_id: String = ""
) -> Dictionary:
	var resolved_faction_id := faction_id
	if resolved_faction_id == "":
		resolved_faction_id = String(config.get("faction_id", ""))
	var origin_pos := Vector2i(int(origin.get("x", 0)), int(origin.get("y", 0)))
	var node: Dictionary = {}
	for node_value in session.overworld.get("resource_nodes", []):
		if node_value is Dictionary and String(node_value.get("placement_id", "")) == target_placement_id:
			node = node_value
			break
	if node.is_empty():
		return {
			"scenario_id": String(session.scenario_id),
			"faction_id": resolved_faction_id,
			"origin": {"x": origin_pos.x, "y": origin_pos.y},
			"placement_id": target_placement_id,
			"target_found": false,
			"included_in_ranked_report": false,
			"reachable": false,
			"resource_rank": 0,
			"route_gate": {},
			"score_breakdown": {},
		}
	var breakdown := resource_target_score_breakdown(session, config, node, origin_pos, resolved_faction_id)
	var ranked_ids := []
	for target_value in resource_pressure_report(session, config, origin, resolved_faction_id, 0).get("targets", []):
		if target_value is Dictionary:
			ranked_ids.append(String(target_value.get("placement_id", "")))
	var ranked_index := ranked_ids.find(target_placement_id)
	return {
		"scenario_id": String(session.scenario_id),
		"faction_id": resolved_faction_id,
		"origin": {"x": origin_pos.x, "y": origin_pos.y},
		"placement_id": target_placement_id,
		"target_found": true,
		"included_in_ranked_report": ranked_index >= 0,
		"reachable": int(breakdown.get("final_priority", 0)) > 0,
		"resource_rank": ranked_index + 1 if ranked_index >= 0 else 0,
		"route_gate": _resource_target_route_gate(session, node),
		"score_breakdown": breakdown,
	}

static func neutral_encounter_object_route_pressure_report(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	origin: Dictionary,
	faction_id: String = "",
	limit: int = 0
) -> Dictionary:
	var resolved_faction_id := faction_id
	if resolved_faction_id == "":
		resolved_faction_id = String(config.get("faction_id", ""))
	var origin_pos := Vector2i(int(origin.get("x", 0)), int(origin.get("y", 0)))
	var targets := []
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var breakdown := neutral_encounter_object_valuation_breakdown(
			session,
			config,
			encounter_value,
			origin_pos,
			resolved_faction_id
		)
		if breakdown.is_empty() or not bool(breakdown.get("object_backed", false)):
			continue
		targets.append(breakdown)
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("priority_with_object_metadata", 0)) == int(b.get("priority_with_object_metadata", 0)):
			if int(a.get("travel_cost", 0)) == int(b.get("travel_cost", 0)):
				return String(a.get("placement_id", "")) < String(b.get("placement_id", ""))
			return int(a.get("travel_cost", 0)) < int(b.get("travel_cost", 0))
		return int(a.get("priority_with_object_metadata", 0)) > int(b.get("priority_with_object_metadata", 0))
	)
	if limit > 0 and targets.size() > limit:
		targets = targets.slice(0, limit)
	return {
		"schema": "neutral_encounter_object_route_pressure_report_v1",
		"mode": "tooling_report_internal_values_allowed",
		"scenario_id": String(session.scenario_id),
		"faction_id": resolved_faction_id,
		"origin": {"x": origin_pos.x, "y": origin_pos.y},
		"target_count": targets.size(),
		"targets": targets,
	}

static func neutral_encounter_object_valuation_breakdown(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	encounter: Variant,
	origin_pos: Vector2i,
	faction_id: String = ""
) -> Dictionary:
	if not (encounter is Dictionary):
		return {}
	var placement_id := String(encounter.get("placement_id", ""))
	var resolved_faction_id := faction_id
	if resolved_faction_id == "":
		resolved_faction_id = String(config.get("faction_id", ""))
	var object_id := String(encounter.get("object_id", ""))
	var object_record := ContentService.get_map_object(object_id) if object_id != "" else {}
	var object_backed := object_id != "" and not object_record.is_empty()
	var neutral_metadata: Dictionary = encounter.get("neutral_encounter", {}) if encounter.get("neutral_encounter", {}) is Dictionary else {}
	if neutral_metadata.is_empty() and object_record.get("neutral_encounter", {}) is Dictionary:
		neutral_metadata = object_record.get("neutral_encounter", {})
	var object_neutral_metadata: Dictionary = object_record.get("neutral_encounter", {}) if object_record.get("neutral_encounter", {}) is Dictionary else {}
	var guard_link: Dictionary = encounter.get("guard_link", {}) if encounter.get("guard_link", {}) is Dictionary else {}
	if guard_link.is_empty() and neutral_metadata.get("guard_link", {}) is Dictionary:
		guard_link = neutral_metadata.get("guard_link", {})
	var ai_hints: Dictionary = neutral_metadata.get("ai_hints", {}) if neutral_metadata.get("ai_hints", {}) is Dictionary else {}
	if ai_hints.is_empty() and object_neutral_metadata.get("ai_hints", {}) is Dictionary:
		ai_hints = object_neutral_metadata.get("ai_hints", {})
	if ai_hints.is_empty() and object_record.get("ai_hints", {}) is Dictionary:
		ai_hints = object_record.get("ai_hints", {})
	var passability: Dictionary = neutral_metadata.get("passability", {}) if neutral_metadata.get("passability", {}) is Dictionary else {}
	var passability_class := String(object_record.get("passability_class", passability.get("passability_class", "")))
	var secondary_tags := _normalize_string_array(object_record.get("secondary_tags", neutral_metadata.get("secondary_tags", [])))
	if secondary_tags.is_empty():
		secondary_tags = _normalize_string_array(neutral_metadata.get("secondary_tags", []))
	var representation: Dictionary = neutral_metadata.get("representation", {}) if neutral_metadata.get("representation", {}) is Dictionary else {}
	var target_tile := Vector2i(int(encounter.get("x", 0)), int(encounter.get("y", 0)))
	var staging_tiles := _encounter_staging_tiles(session, encounter)
	var goal_distance := _path_distance(session, origin_pos, staging_tiles, "")
	var objective_anchor := _encounter_is_objective_anchor(session, encounter)
	var baseline_priority := _encounter_target_priority(session, encounter)
	var route_pressure_value := 0
	var guard_target_value := 0
	var clearance_value := 0
	var passability_value := 0
	var shape_mask_value := 0
	var reason_codes := ["site_contested"]
	var debug_parts := []

	if bool(ai_hints.get("path_blocking", false)):
		route_pressure_value += 18
		debug_parts.append("path-blocking hint")
	clearance_value += max(0, int(ai_hints.get("neutral_clearance_value", 0))) * 10
	guard_target_value += max(0, int(ai_hints.get("guard_target_value_hint", 0))) * 14
	match String(ai_hints.get("avoid_until_strength", "")):
		"light_guard":
			clearance_value += 6
		"standard_guard":
			clearance_value += 14
		"heavy_guard":
			clearance_value += 26
		"elite_guard":
			clearance_value += 38

	for tag in secondary_tags:
		match String(tag):
			"route_block":
				route_pressure_value += 34
			"route_pressure":
				route_pressure_value += 22
			"scenario_objective_guard":
				guard_target_value += 38
			"guarded_reward":
				guard_target_value += 24
			"neutral_dwelling_watch":
				guard_target_value += 18
			"mire_pressure":
				route_pressure_value += 8
			"visible_army":
				route_pressure_value += 6

	if passability_class == "neutral_stack_blocking":
		passability_value += 20
	if bool(passability.get("blocks_route_until_cleared", false)):
		route_pressure_value += 20

	match String(guard_link.get("guard_role", "")):
		"route_block":
			route_pressure_value += 55
			debug_parts.append("route-block guard link")
		"guards_resource_node":
			guard_target_value += 48
			debug_parts.append("resource-node guard link")
		"guards_scenario_objective":
			guard_target_value += 58
			debug_parts.append("scenario-objective guard link")
		"guards_reward":
			guard_target_value += 34
		"guards_object":
			guard_target_value += 28
	if bool(guard_link.get("blocks_approach", false)):
		route_pressure_value += 14
	if bool(guard_link.get("clear_required_for_target", false)):
		guard_target_value += 18
	if String(guard_link.get("target_kind", "")) == "route":
		route_pressure_value += 20
	if objective_anchor or String(guard_link.get("target_kind", "")) == "scenario_objective":
		guard_target_value += 34
		if "objective_front" not in reason_codes:
			reason_codes.append("objective_front")
	if route_pressure_value > 0 and "route_pressure" not in reason_codes:
		reason_codes.append("route_pressure")

	var footprint: Dictionary = object_record.get("footprint", {}) if object_record.get("footprint", {}) is Dictionary else {}
	var body_tiles: Array = object_record.get("body_tiles", []) if object_record.get("body_tiles", []) is Array else []
	var approach: Dictionary = object_record.get("approach", {}) if object_record.get("approach", {}) is Dictionary else {}
	var visit_offsets: Array = approach.get("visit_offsets", []) if approach.get("visit_offsets", []) is Array else []
	if not body_tiles.is_empty() and not visit_offsets.is_empty():
		shape_mask_value += 8
	var object_metadata_value := int(min(175.0, float(route_pressure_value + guard_target_value + clearance_value + passability_value + shape_mask_value)))
	var priority_without_object_metadata: int = max(
		0,
		_weighted_priority(config, resolved_faction_id, "encounter", placement_id, baseline_priority, "", objective_anchor)
		- _assignment_penalty(session, "encounter", placement_id)
	)
	var priority_with_object_metadata: int = max(
		0,
		_weighted_priority(config, resolved_faction_id, "encounter", placement_id, baseline_priority + object_metadata_value, "", objective_anchor)
		- _assignment_penalty(session, "encounter", placement_id)
	)
	if debug_parts.is_empty() and object_backed:
		debug_parts.append("object-backed neutral encounter metadata")
	var public_reason := _public_reason_from_codes(reason_codes)
	var public_importance := _default_public_importance("encounter", reason_codes)
	if "objective_front" in reason_codes:
		public_importance = "high"
	return {
		"target_kind": "encounter",
		"placement_id": placement_id,
		"encounter_id": String(encounter.get("encounter_id", encounter.get("id", ""))),
		"object_id": object_id,
		"object_backed": object_backed,
		"object_placement_id": String(encounter.get("object_placement_id", "")),
		"authored_bundle_id": String(encounter.get("authored_metadata", {}).get("bundle_id", "")) if encounter.get("authored_metadata", {}) is Dictionary else "",
		"target_label": String(ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", "")))).get("name", placement_id)),
		"target_x": target_tile.x,
		"target_y": target_tile.y,
		"goal_distance": goal_distance,
		"travel_cost": max(0, goal_distance - 1),
		"representation_mode": String(representation.get("mode", "")),
		"passability_class": passability_class,
		"secondary_tags": secondary_tags,
		"guard_role": String(guard_link.get("guard_role", "")),
		"guard_target_kind": String(guard_link.get("target_kind", "")),
		"guard_target_id": String(guard_link.get("target_id", "")),
		"path_blocking": bool(ai_hints.get("path_blocking", false)),
		"avoid_until_strength": String(ai_hints.get("avoid_until_strength", "")),
		"route_effect_status": "report_only_object_metadata",
		"object_route_pressure_value": route_pressure_value,
		"guard_target_value": guard_target_value,
		"clearance_value": clearance_value,
		"passability_value": passability_value,
		"shape_mask_value": shape_mask_value,
		"object_metadata_value": object_metadata_value if object_backed else 0,
		"priority_without_object_metadata": priority_without_object_metadata,
		"priority_with_object_metadata": priority_with_object_metadata,
		"reason_codes": reason_codes,
		"public_reason": public_reason,
		"public_importance": public_importance,
		"debug_reason": "; ".join(debug_parts),
		"shape_mask_contract": {
			"visual_footprint": {
				"width": int(footprint.get("width", 0)),
				"height": int(footprint.get("height", 0)),
				"anchor": String(footprint.get("anchor", "")),
			},
			"body_tile_count": body_tiles.size(),
			"approach_visit_offset_count": visit_offsets.size(),
			"body_tiles_overlap_visit_offsets": not body_tiles.is_empty() and not visit_offsets.is_empty(),
			"inside_footprint_interaction_contract": "visit_offsets_overlap_body_tiles",
		},
	}

static func commander_role_front_id(scenario_id: String, target_kind: String, target_id: String) -> String:
	if scenario_id == "river-pass" and target_id in ["river_free_company", "river_signal_post", "riverwatch_hold", "duskfen_bastion"]:
		return "riverwatch_signal_yard"
	if scenario_id == "glassroad-sundering" and target_id in ["glassroad_watch_relay", "glassroad_starlens", "halo_spire_bridgehead", "riverwatch_market"]:
		return "glassroad_charter_front"
	if target_kind == "town" and target_id != "":
		return "town:%s" % target_id
	if target_kind == "resource" and target_id != "":
		return "%s:resource:%s" % [scenario_id, target_id]
	if target_kind != "" and target_id != "":
		return "%s:%s:%s" % [scenario_id, target_kind, target_id]
	return ""

static func commander_role_public_reason_from_codes(reason_codes: Array) -> String:
	return _public_reason_from_codes(reason_codes)

static func commander_role_active_encounter_link(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_hero_id: String
) -> Dictionary:
	if session == null or faction_id == "" or roster_hero_id == "":
		return {
			"linked": false,
			"placement_id": "",
			"target_kind": "",
			"target_id": "",
		}
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not _is_active_raid(encounter, faction_id, resolved_encounters):
			continue
		var commander_state = encounter.get("enemy_commander_state", {})
		if not (commander_state is Dictionary):
			continue
		if String(commander_state.get("roster_hero_id", "")) != roster_hero_id:
			continue
		return {
			"linked": true,
			"placement_id": String(encounter.get("placement_id", "")),
			"target_kind": String(encounter.get("target_kind", "")),
			"target_id": String(encounter.get("target_placement_id", "")),
			"target_label": String(encounter.get("target_label", "")),
		}
	return {
		"linked": false,
		"placement_id": "",
		"target_kind": "",
		"target_id": "",
	}

static func commander_role_state_view(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	commander_entry: Dictionary
) -> Dictionary:
	var roster_hero_id := String(commander_entry.get("roster_hero_id", ""))
	var active_link := commander_role_active_encounter_link(session, faction_id, roster_hero_id)
	var status := _normalize_commander_status(commander_entry.get("status", COMMANDER_STATUS_AVAILABLE))
	var recovery_day: int = max(0, int(commander_entry.get("recovery_day", 0)))
	var session_day := int(session.day) if session != null else 0
	var role := COMMANDER_ROLE_RESERVE
	var role_status := "available"
	var validation := "valid"
	if status == COMMANDER_STATUS_RECOVERING and recovery_day > session_day:
		role = COMMANDER_ROLE_RECOVERING
		role_status = "cooldown"
		validation = "blocked_recovery"
	elif status == COMMANDER_STATUS_ACTIVE or bool(active_link.get("linked", false)):
		role = COMMANDER_ROLE_RAIDER
		role_status = "active"
	elif not commander_can_deploy(commander_entry):
		role = COMMANDER_ROLE_RECOVERING
		role_status = "rebuilding"
		validation = "blocked_rebuild"
	return {
		"schema_status": "report_fixture_only",
		"roster_hero_id": roster_hero_id,
		"status": status,
		"active_placement_id": String(commander_entry.get("active_placement_id", active_link.get("placement_id", ""))),
		"recovery_day": recovery_day,
		"army_status": commander_army_status(commander_entry),
		"army_summary": commander_army_summary(commander_entry),
		"memory_summary": commander_memory_summary(commander_entry),
		"display_name": commander_display_name(commander_entry, false),
		"role": role,
		"role_status": role_status,
		"last_validation": validation,
	}

static func commander_role_resource_target_view(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	placement_id: String,
	origin: Dictionary
) -> Dictionary:
	if session == null or placement_id == "":
		return {}
	var node_result := _find_resource_by_placement(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	if int(node_result.get("index", -1)) < 0:
		return {}
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	var origin_pos := Vector2i(int(origin.get("x", 0)), int(origin.get("y", 0)))
	var breakdown := resource_target_score_breakdown(session, config, node, origin_pos, faction_id)
	var reason_codes: Array = _normalize_string_array(breakdown.get("reason_codes", []))
	if reason_codes.is_empty():
		reason_codes = _resource_target_reason_codes(
			site,
			String(node.get("collected_by_faction_id", "")) == "player",
			_resource_site_is_persistent(site),
			_target_resource_value(site.get("control_income", {})),
			_recruit_payload_value(site.get("claim_recruits", {})) + _recruit_payload_value(site.get("weekly_recruits", {})),
			_resource_route_pressure_value(site),
			_linked_player_town_bonus(session, node)
		)
	if _enemy_scouted_target_priority_bonus(session, faction_id, "resource", placement_id) > 0 and "enemy_scouting" not in reason_codes:
		reason_codes.append("enemy_scouting")
	var target_x := int(node.get("x", 0))
	var target_y := int(node.get("y", 0))
	return {
		"target_kind": "resource",
		"target_id": placement_id,
		"target_label": String(site.get("name", placement_id)),
		"target_x": target_x,
		"target_y": target_y,
		"front_id": commander_role_front_id(String(session.scenario_id), "resource", placement_id),
		"origin_kind": "town",
		"origin_id": commander_role_origin_id(String(session.scenario_id), faction_id),
		"controller_id": String(node.get("collected_by_faction_id", "")),
		"site_id": String(node.get("site_id", "")),
		"site_family": String(site.get("family", "")),
		"reason_codes": reason_codes,
		"public_reason": _public_reason_from_codes(reason_codes),
		"public_importance": String(breakdown.get("public_importance", _resource_target_public_importance(String(node.get("collected_by_faction_id", "")) == "player", _resource_site_is_persistent(site), reason_codes, int(breakdown.get("final_priority", 0))))),
		"debug_reason": String(breakdown.get("debug_reason", "")),
		"resource_breakdown": breakdown,
	}

static func commander_role_origin_id(scenario_id: String, faction_id: String) -> String:
	if scenario_id == "river-pass" and faction_id == "faction_mireclaw":
		return "duskfen_bastion"
	if scenario_id == "glassroad-sundering" and faction_id == "faction_embercourt":
		return "riverwatch_market"
	return ""

static func commander_role_proposal_for_resource_target(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	commander_entry: Dictionary,
	target_view: Dictionary,
	fixture_state: Dictionary = {}
) -> Dictionary:
	var state_view := commander_role_state_view(session, faction_id, commander_entry)
	var blocked_proposal := commander_role_proposal_for_recovery(session, faction_id, commander_entry)
	if not blocked_proposal.is_empty():
		return blocked_proposal
	if target_view.is_empty():
		return {
			"role": COMMANDER_ROLE_RESERVE,
			"role_status": "available",
			"validity": "invalid_target_missing",
			"assignment_id_hint": "",
			"priority_reason_codes": [],
			"public_reason": "",
			"report_debug_reason": "report-only target missing",
			"expected_next_transition": "wait_for_target",
		}
	var role := COMMANDER_ROLE_RAIDER
	if String(fixture_state.get("fixture_previous_controller", "")) == faction_id:
		role = COMMANDER_ROLE_RETAKER
	elif bool(fixture_state.get("fixture_threatened_by_player_front", false)):
		role = COMMANDER_ROLE_DEFENDER
	elif bool(fixture_state.get("fixture_recently_secured", false)):
		role = COMMANDER_ROLE_STABILIZER
	elif bool(fixture_state.get("fixture_denial_only", false)):
		role = COMMANDER_ROLE_RAIDER
	var reason_codes: Array = _normalize_string_array(target_view.get("reason_codes", []))
	if role in [COMMANDER_ROLE_RETAKER, COMMANDER_ROLE_RAIDER, COMMANDER_ROLE_DEFENDER]:
		var target_id := String(target_view.get("target_id", ""))
		if target_id in ["river_free_company", "glassroad_watch_relay"] and "persistent_income_denial" not in reason_codes:
			reason_codes.push_front("persistent_income_denial")
		if target_id == "river_free_company" and "recruit_denial" not in reason_codes:
			reason_codes.append("recruit_denial")
		if target_id in ["river_signal_post", "glassroad_watch_relay"] and "route_vision" not in reason_codes:
			reason_codes.append("route_vision")
		if target_id in ["river_free_company", "river_signal_post", "glassroad_watch_relay"] and "player_town_support" not in reason_codes:
			reason_codes.append("player_town_support")
	if role == COMMANDER_ROLE_STABILIZER:
		reason_codes = ["route_pressure"] if String(target_view.get("target_id", "")) == "glassroad_starlens" else reason_codes
	var report_reason := "report-only role proposal"
	if String(state_view.get("memory_summary", "")) != "":
		report_reason += "; target memory: %s" % String(state_view.get("memory_summary", ""))
	return {
		"role": role,
		"role_status": "assigned",
		"validity": "valid",
		"assignment_id_hint": _commander_role_assignment_id_hint(session, faction_id, String(commander_entry.get("roster_hero_id", "")), role, "resource", String(target_view.get("target_id", ""))),
		"priority_reason_codes": reason_codes,
		"public_reason": _public_reason_from_codes(reason_codes),
		"report_debug_reason": report_reason,
		"expected_next_transition": _commander_role_expected_transition(role),
	}

static func commander_role_proposal_for_recovery(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	commander_entry: Dictionary
) -> Dictionary:
	var state_view := commander_role_state_view(session, faction_id, commander_entry)
	match String(state_view.get("last_validation", "")):
		"blocked_recovery":
			return {
				"role": COMMANDER_ROLE_RECOVERING,
				"role_status": "cooldown",
				"validity": "blocked",
				"assignment_id_hint": "",
				"priority_reason_codes": ["commander_recovery"],
				"public_reason": "commander recovering",
				"report_debug_reason": "report-only recovery blocks active assignment until day %d" % int(state_view.get("recovery_day", 0)),
				"expected_next_transition": "wait_until_recovery_day",
			}
		"blocked_rebuild":
			return {
				"role": COMMANDER_ROLE_RECOVERING,
				"role_status": "rebuilding",
				"validity": "blocked",
				"assignment_id_hint": "",
				"priority_reason_codes": ["commander_rebuild"],
				"public_reason": "commander rebuilding",
				"report_debug_reason": "report-only rebuild blocks active assignment",
				"expected_next_transition": "rebuild_host_then_reserve",
			}
	return {}

static func commander_role_public_event(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	commander_entry: Dictionary,
	target_view: Dictionary,
	role_proposal: Dictionary
) -> Dictionary:
	var actor_id := String(commander_entry.get("roster_hero_id", ""))
	var actor_label := commander_display_name(commander_entry, false)
	if actor_label == "":
		actor_label = actor_id
	var target_kind := String(target_view.get("target_kind", ""))
	var target_id := String(target_view.get("target_id", ""))
	var target_label := String(target_view.get("target_label", target_id))
	if target_kind == "" or target_id == "":
		target_kind = "commander"
		target_id = actor_id
		target_label = actor_label
	var reason_codes: Array = _normalize_string_array(role_proposal.get("priority_reason_codes", []))
	var public_reason := String(role_proposal.get("public_reason", _public_reason_from_codes(reason_codes)))
	var summary := "%s assigned as %s for %s" % [
		actor_label,
		String(role_proposal.get("role", COMMANDER_ROLE_RESERVE)),
		target_label,
	]
	if public_reason != "":
		summary += " (%s)" % public_reason
	summary += "."
	return {
		"event_id": "%d:%s:ai_commander_role_assigned:%s:%s" % [int(session.day), faction_id, actor_id, target_id],
		"day": int(session.day),
		"sequence": 0,
		"event_type": "ai_commander_role_assigned",
		"faction_id": faction_id,
		"faction_label": String(config.get("label", faction_id)),
		"actor_id": actor_id,
		"actor_label": actor_label,
		"target_kind": target_kind,
		"target_id": target_id,
		"target_label": target_label,
		"target_x": int(target_view.get("target_x", 0)),
		"target_y": int(target_view.get("target_y", 0)),
		"visibility": _event_visibility(session, int(target_view.get("target_x", 0)), int(target_view.get("target_y", 0)), String(target_view.get("public_importance", "medium"))),
		"public_importance": String(target_view.get("public_importance", "medium")),
		"summary": summary,
		"reason_codes": reason_codes,
		"public_reason": public_reason,
		"debug_reason": "derived commander role",
		"state_policy": "derived",
	}

static func commander_role_public_leak_check(public_surfaces: Variant) -> Dictionary:
	var blocked := COMMANDER_ROLE_BLOCKED_PUBLIC_TOKENS
	var allowed := COMMANDER_ROLE_PUBLIC_EVENT_KEYS
	var stack := [public_surfaces]
	var checked_events := 0
	while not stack.is_empty():
		var value = stack.pop_back()
		if value is Array:
			for item in value:
				stack.append(item)
			continue
		if not (value is Dictionary):
			var value_text := String(value)
			for token in blocked:
				if value_text.contains(String(token)):
					return {"ok": false, "error": "public surface leaked token %s" % String(token)}
			continue
		if String(value.get("event_type", "")) != "":
			checked_events += 1
			for key in value.keys():
				if String(key) not in allowed:
					return {"ok": false, "error": "%s leaked non-compact key %s" % [value.get("event_type", "event"), key]}
		var text := JSON.stringify(value)
		for token in blocked:
			if text.contains(String(token)):
				return {"ok": false, "error": "%s leaked blocked token %s" % [value.get("event_type", "event"), token]}
		for nested_key in value.keys():
			var nested = value[nested_key]
			if nested is Array or nested is Dictionary:
				stack.append(nested)
	return {
		"ok": true,
		"checked_events": checked_events,
		"allowed_public_event_keys": allowed,
		"blocked_public_tokens": blocked,
	}

static func ai_public_event_log(events_value: Variant, limit: int = 6) -> Array:
	var public_events := []
	if not (events_value is Array):
		return public_events
	for event_value in events_value:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		var public_event := ai_public_event_log_entry(event)
		if public_event.is_empty():
			continue
		var leak_check := ai_public_event_log_leak_check([public_event])
		if not bool(leak_check.get("ok", false)):
			continue
		public_events.append(public_event)
		if public_events.size() >= max(1, limit):
			break
	return public_events

static func ai_public_event_log_entry(event: Dictionary) -> Dictionary:
	var event_type := String(event.get("event_type", ""))
	if event_type not in AI_PUBLIC_EVENT_LOG_TYPES:
		return {}
	var visibility := String(event.get("visibility", ""))
	if visibility == "hidden_debug":
		return {}
	var reason_codes: Array = _normalize_string_array(event.get("reason_codes", []))
	var public_reason := _public_event_log_text(String(event.get("public_reason", "")))
	if public_reason == "":
		public_reason = _public_event_log_text(_public_reason_from_codes(reason_codes))
	var faction_label := _public_event_log_text(String(event.get("faction_label", event.get("faction_id", ""))))
	var actor_label := _public_event_log_text(String(event.get("actor_label", "")))
	var target_label := _public_event_log_text(String(event.get("target_label", event.get("target_id", ""))))
	var summary := _public_event_log_text(String(event.get("summary", "")))
	if summary == "":
		summary = _public_event_log_text(
			_ai_event_summary(
				event_type,
				faction_label,
				actor_label,
				target_label,
				public_reason
			)
		)
	if summary == "" and target_label == "":
		return {}
	return {
		"day": int(event.get("day", 0)),
		"event_type": event_type,
		"faction_id": _public_event_log_text(String(event.get("faction_id", ""))),
		"faction_label": faction_label,
		"actor_label": actor_label,
		"target_kind": _public_event_log_text(String(event.get("target_kind", ""))),
		"target_id": _public_event_log_text(String(event.get("target_id", ""))),
		"target_label": target_label,
		"visibility": visibility,
		"public_importance": _public_event_log_text(String(event.get("public_importance", "low"))),
		"summary": summary,
		"reason_codes": reason_codes,
		"public_reason": public_reason,
	}

static func ai_public_event_log_boundary_report(events_value: Variant, limit: int = 6) -> Dictionary:
	var source_count := 0
	if events_value is Array:
		source_count = events_value.size()
	var public_events := ai_public_event_log(events_value, limit)
	var leak_check := ai_public_event_log_leak_check(public_events)
	var meaningful_count := 0
	for event_value in public_events:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		if String(event.get("event_type", "")) != "" and String(event.get("summary", "")) != "" and not _normalize_string_array(event.get("reason_codes", [])).is_empty():
			meaningful_count += 1
	return {
		"ok": bool(leak_check.get("ok", false)) and meaningful_count == public_events.size(),
		"boundary_id": "strategic-ai-public-event-log-boundary-10184",
		"source_event_count": source_count,
		"public_event_count": public_events.size(),
		"meaningful_public_event_count": meaningful_count,
		"limit": max(1, limit),
		"storage_policy": "derived_ephemeral_report_only",
		"durable_log_selected": false,
		"save_migration_required": false,
		"allowed_public_key_count": AI_PUBLIC_EVENT_LOG_KEYS.size(),
		"blocked_token_count": AI_PUBLIC_EVENT_LOG_BLOCKED_TOKENS.size(),
		"leak_check": leak_check,
		"public_events": public_events,
	}

static func ai_public_event_log_leak_check(public_surfaces: Variant) -> Dictionary:
	var stack := [public_surfaces]
	var checked_events := 0
	while not stack.is_empty():
		var value = stack.pop_back()
		if value is Array:
			for item in value:
				stack.append(item)
			continue
		if value is Dictionary:
			if String(value.get("event_type", "")) != "":
				checked_events += 1
				for key in value.keys():
					if String(key) not in AI_PUBLIC_EVENT_LOG_KEYS:
						return {"ok": false, "error": "%s leaked public-log key %s" % [value.get("event_type", "event"), key]}
			var text := JSON.stringify(value)
			for token in AI_PUBLIC_EVENT_LOG_BLOCKED_TOKENS:
				if text.contains(String(token)):
					return {"ok": false, "error": "%s leaked blocked public-log token %s" % [value.get("event_type", "event"), token]}
			for nested_key in value.keys():
				var nested = value[nested_key]
				if nested is Array or nested is Dictionary:
					stack.append(nested)
			continue
		var value_text := String(value)
		for token in AI_PUBLIC_EVENT_LOG_BLOCKED_TOKENS:
			if value_text.contains(String(token)):
				return {"ok": false, "error": "public log leaked token %s" % String(token)}
	return {
		"ok": true,
		"checked_events": checked_events,
		"allowed_public_key_count": AI_PUBLIC_EVENT_LOG_KEYS.size(),
		"blocked_token_count": AI_PUBLIC_EVENT_LOG_BLOCKED_TOKENS.size(),
	}

static func ai_target_assignment_event(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	actor: Dictionary,
	previous_target: Dictionary = {}
) -> Dictionary:
	var target_kind := String(actor.get("target_kind", ""))
	var target_id := String(actor.get("target_placement_id", ""))
	if target_kind == "" or target_id == "":
		return {}
	if not previous_target.is_empty() and _target_signature(previous_target) == _target_signature(_current_target_snapshot(actor)):
		return {}
	var target := {
		"target_kind": target_kind,
		"target_placement_id": target_id,
		"target_label": String(actor.get("target_label", target_id)),
		"target_x": int(actor.get("target_x", actor.get("goal_x", 0))),
		"target_y": int(actor.get("target_y", actor.get("goal_y", 0))),
		"target_public_reason": String(actor.get("target_public_reason", "")),
		"target_reason_codes": actor.get("target_reason_codes", []),
		"target_public_importance": String(actor.get("target_public_importance", "")),
		"target_debug_reason": String(actor.get("target_debug_reason", "")),
	}
	return build_ai_event_record(
		session,
		config,
		"ai_target_assigned",
		actor,
		target,
		{
			"state_policy": "derived",
			"summary_prefix": "targets",
		}
	)

static func ai_pressure_summary_event(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	target: Dictionary,
	state: Dictionary = {}
) -> Dictionary:
	if target.is_empty():
		return {}
	var summary_target := target.duplicate(true)
	if String(summary_target.get("target_public_reason", "")) == "":
		match String(summary_target.get("target_kind", "")):
			"town":
				summary_target["target_public_reason"] = "town siege remains the main front"
				summary_target["target_reason_codes"] = ["town_siege", "objective_front"]
				summary_target["target_public_importance"] = "critical"
			"resource":
				summary_target["target_public_reason"] = "site denial pressure"
				summary_target["target_reason_codes"] = ["persistent_income_denial"]
				summary_target["target_public_importance"] = "high"
	var actor := {
		"placement_id": String(config.get("faction_id", "")),
		"name": String(config.get("label", config.get("faction_id", "Enemy"))),
	}
	return build_ai_event_record(
		session,
		config,
		"ai_pressure_summary",
		actor,
		summary_target,
		{
			"public_importance": String(summary_target.get("target_public_importance", "medium")),
			"state_policy": "derived",
			"summary": "%s pressure centers on %s." % [
				String(config.get("label", config.get("faction_id", "Enemy"))),
				String(summary_target.get("target_label", summary_target.get("target_placement_id", "the frontier"))),
			],
			"debug_reason": String(summary_target.get("target_debug_reason", "")),
		}
	)

static func build_ai_event_record(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	event_type: String,
	actor: Dictionary,
	target: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var faction_id := String(options.get("faction_id", config.get("faction_id", actor.get("spawned_by_faction_id", ""))))
	var faction_label := String(options.get("faction_label", config.get("label", faction_id)))
	var actor_id := String(options.get("actor_id", actor.get("placement_id", actor.get("id", ""))))
	var actor_label := String(options.get("actor_label", _raid_name(actor) if actor.has("encounter_id") else actor.get("name", actor_id)))
	var target_kind := String(options.get("target_kind", target.get("target_kind", "")))
	var target_id := String(options.get("target_id", target.get("target_placement_id", target.get("placement_id", ""))))
	var target_label := String(options.get("target_label", target.get("target_label", target.get("name", target_id))))
	var target_x := int(options.get("target_x", target.get("target_x", target.get("x", 0))))
	var target_y := int(options.get("target_y", target.get("target_y", target.get("y", 0))))
	var reason_codes: Array = _normalize_string_array(options.get("reason_codes", target.get("target_reason_codes", [])))
	if reason_codes.is_empty():
		reason_codes = _default_reason_codes_for_target(target_kind, target_id, target)
	var public_reason := String(options.get("public_reason", target.get("target_public_reason", _public_reason_from_codes(reason_codes))))
	if public_reason == "":
		public_reason = _public_reason_from_codes(reason_codes)
	var debug_reason := String(options.get("debug_reason", target.get("target_debug_reason", public_reason)))
	var importance := String(options.get("public_importance", target.get("target_public_importance", _default_public_importance(target_kind, reason_codes))))
	var visibility := String(options.get("visibility", _event_visibility(session, target_x, target_y, importance)))
	var summary := String(options.get("summary", ""))
	if summary == "":
		summary = _ai_event_summary(event_type, faction_label, actor_label, target_label, public_reason, String(options.get("summary_prefix", "")))
	var event_id := "%d:%s:%s:%s:%s" % [int(session.day), faction_id, event_type, actor_id, target_id]
	return {
		"event_id": event_id,
		"day": int(session.day),
		"sequence": int(options.get("sequence", 0)),
		"event_type": event_type,
		"faction_id": faction_id,
		"faction_label": faction_label,
		"actor_id": actor_id,
		"actor_label": actor_label,
		"target_kind": target_kind,
		"target_id": target_id,
		"target_label": target_label,
		"target_x": target_x,
		"target_y": target_y,
		"visibility": visibility,
		"public_importance": importance,
		"summary": summary,
		"reason_codes": reason_codes,
		"public_reason": public_reason,
		"debug_reason": debug_reason,
		"state_policy": String(options.get("state_policy", "ephemeral")),
	}

static func resource_target_score_breakdown(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	node: Variant,
	origin_pos: Vector2i,
	faction_id: String = ""
) -> Dictionary:
	if not (node is Dictionary):
		return {}
	var resolved_faction_id := faction_id
	if resolved_faction_id == "":
		resolved_faction_id = String(config.get("faction_id", ""))
	var placement_id := String(node.get("placement_id", ""))
	var site_id := String(node.get("site_id", ""))
	var site := ContentService.get_resource_site(site_id)
	var site_family := String(site.get("family", ""))
	var label := String(site.get("name", "Resource Site"))
	var target_tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	var goal_distance := _path_distance(session, origin_pos, [target_tile], "")
	var claim_value := _target_resource_value(_resource_site_claim_rewards(site))
	var income_value := _target_resource_value(site.get("control_income", {}))
	var strategy := enemy_strategy(config, resolved_faction_id)
	var weighted_claim_value := _target_resource_value_for_strategy(_resource_site_claim_rewards(site), strategy)
	var weighted_income_value := _target_resource_value_for_strategy(site.get("control_income", {}), strategy)
	var claim_recruit_value := _recruit_payload_value(site.get("claim_recruits", {}))
	var weekly_recruit_value := _recruit_payload_value(site.get("weekly_recruits", {}))
	var recruit_payload_value := claim_recruit_value + weekly_recruit_value
	var persistent := _resource_site_is_persistent(site)
	var player_controlled := String(node.get("collected_by_faction_id", "")) == "player"
	var contestable := placement_id != "" and _resource_node_contestable_by_faction(node, site, resolved_faction_id)

	var base_value := 0
	var persistent_income_value := 0
	var recruit_value := 0
	var scarcity_value := 0
	var denial_value := 0
	var route_pressure_value := 0
	var town_enablement_value := 0
	var resource_affinity_value := 0
	var objective_value := 0
	var faction_bias := 0
	var travel_cost := 0
	var guard_cost := 0
	var assignment_penalty := 0
	var final_priority := 0
	var debug_reason := "not contestable"

	if contestable and goal_distance < 9999:
		base_value = 85 + int(min(45.0, float(weighted_claim_value) / 150.0))
		persistent_income_value = int(min(45.0, float(weighted_income_value * 4) / 8.0)) if persistent else 0
		recruit_value = int(min(70.0, float(recruit_payload_value) / 40.0))
		scarcity_value = _resource_scarcity_value(session, _resource_site_claim_rewards(site))
		if player_controlled and persistent:
			denial_value = 45 + int(min(35.0, float(weighted_income_value * 4) / 20.0)) + int(min(40.0, float(recruit_payload_value) / 80.0))
		if player_controlled and int(node.get("response_until_day", 0)) >= int(session.day):
			denial_value += 20 + (max(1, int(node.get("response_security_rating", 0))) * 6)
		var delivery_value := _recruit_payload_value(node.get("delivery_manifest", {}))
		if player_controlled and delivery_value > 0:
			denial_value += 28 + int(min(95.0, float(delivery_value) / 10.0))
		route_pressure_value = _resource_route_pressure_value(site)
		town_enablement_value = _linked_player_town_bonus(session, node)
		resource_affinity_value = _resource_affinity_value(claim_value, income_value, weighted_claim_value, weighted_income_value)
		objective_value = _objective_proximity_bonus(session, target_tile.x, target_tile.y)
		var target_weight := strategy_target_weight(config, resolved_faction_id, "resource", placement_id, site_family, false)
		faction_bias = priority_target_bonus(config, placement_id) + int(round(max(0.0, target_weight - 1.0) * 50.0))
		travel_cost = max(0, goal_distance - 1) * 3
		guard_cost = _resource_guard_cost(site)
		assignment_penalty = _assignment_penalty(session, "resource", placement_id)
		final_priority = max(
			0,
			base_value
			+ persistent_income_value
			+ recruit_value
			+ scarcity_value
			+ denial_value
			+ route_pressure_value
			+ town_enablement_value
			+ resource_affinity_value
			+ objective_value
			+ faction_bias
			- travel_cost
			- guard_cost
			- assignment_penalty
		)
		debug_reason = _resource_target_debug_reason(site, player_controlled, persistent, claim_value, income_value, recruit_payload_value, route_pressure_value, town_enablement_value)
	elif contestable:
		debug_reason = "unreachable from current raid origin"
	var reason_codes := _resource_target_reason_codes(site, player_controlled, persistent, income_value, recruit_payload_value, route_pressure_value, town_enablement_value)
	var public_reason := _public_reason_from_codes(reason_codes)
	var public_importance := _resource_target_public_importance(player_controlled, persistent, reason_codes, final_priority)

	return {
		"target_kind": "resource",
		"placement_id": placement_id,
		"site_id": site_id,
		"site_family": site_family,
		"target_label": label,
		"controller_id": String(node.get("collected_by_faction_id", "")),
		"player_controlled": player_controlled,
		"base_value": base_value,
		"persistent_income_value": persistent_income_value,
		"recruit_value": recruit_value,
		"scarcity_value": scarcity_value,
		"denial_value": denial_value,
		"route_pressure_value": route_pressure_value,
		"town_enablement_value": town_enablement_value,
		"resource_affinity_value": resource_affinity_value,
		"weighted_claim_value": weighted_claim_value,
		"weighted_income_value": weighted_income_value,
		"objective_value": objective_value,
		"faction_bias": faction_bias,
		"travel_cost": travel_cost,
		"guard_cost": guard_cost,
		"assignment_penalty": assignment_penalty,
		"final_priority": final_priority,
		"reason_codes": reason_codes,
		"public_reason": public_reason,
		"public_importance": public_importance,
		"debug_reason": debug_reason,
	}

static func _weighted_priority(
	config: Dictionary,
	faction_id: String,
	target_kind: String,
	placement_id: String,
	base_priority: int,
	site_family: String,
	objective_anchor: bool
) -> int:
	var weighted_priority = int(
		round(
			float(max(0, base_priority))
			* strategy_target_weight(config, faction_id, target_kind, placement_id, site_family, objective_anchor)
		)
	)
	return max(0, weighted_priority + priority_target_bonus(config, placement_id))

static func _commander_memory_priority_bonus(
	session: SessionStateStoreScript.SessionData,
	candidate: Dictionary,
	commander_source: Variant
) -> int:
	var memory := _normalized_commander_memory(commander_source)
	if memory.is_empty():
		return 0
	var target_kind := String(candidate.get("target_kind", ""))
	var target_id := String(candidate.get("target_placement_id", ""))
	var bonus := 0
	if target_kind != "" and target_id != "":
		if (
			target_kind == String(memory.get("focus_target_kind", ""))
			and target_id == String(memory.get("focus_target_id", ""))
		):
			bonus += 70 + (min(3, max(1, int(memory.get("focus_pressure_count", 0)))) * 22)
		if (
			target_kind == String(memory.get("rival_kind", ""))
			and target_id == String(memory.get("rival_id", ""))
		):
			bonus += 140 + (min(4, max(1, int(memory.get("rivalry_count", 0)))) * 40)
	if String(memory.get("front_label", "")) != "" or String(memory.get("focus_target_id", "")) != "":
		var target_x := int(candidate.get("target_x", candidate.get("goal_x", 0)))
		var target_y := int(candidate.get("target_y", candidate.get("goal_y", 0)))
		var front_distance: int = abs(target_x - int(memory.get("front_x", target_x))) + abs(
			target_y - int(memory.get("front_y", target_y))
		)
		if front_distance <= 1:
			bonus += 28
		elif front_distance <= 3:
			bonus += 16
		elif front_distance <= 5:
			bonus += 8
	return bonus

static func _town_strategic_priority_bonus(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	faction_id: String,
	objective_anchor: bool = false
) -> int:
	var bonus = _objective_proximity_bonus(session, int(town.get("x", 0)), int(town.get("y", 0)))
	match OverworldRulesScript.town_strategic_role(town):
		"capital":
			bonus += 80
		"stronghold":
			bonus += 45
	var logistics: Dictionary = OverworldRulesScript.town_logistics_state(session, town)
	var recovery: Dictionary = OverworldRulesScript.town_recovery_state(session, town)
	var capital_project: Dictionary = OverworldRulesScript.town_capital_project_state(town, session)
	if int(capital_project.get("active", 0)) > 0:
		bonus += 25 + (int(capital_project.get("pressure_bonus", 0)) * 12)
	elif int(capital_project.get("total", 0)) > 0:
		bonus += 15
	bonus += int(logistics.get("support_gap", 0)) * 16
	bonus += int(logistics.get("threatened_count", 0)) * 6
	bonus += int(recovery.get("pressure", 0)) * 10
	if bool(capital_project.get("vulnerable", false)):
		bonus += 30
	var front_state: Dictionary = OverworldRulesScript.town_front_state(session, town)
	if bool(front_state.get("active", false)) and String(front_state.get("faction_id", "")) == faction_id:
		bonus += int(front_state.get("priority_bonus", 0))
	var occupation_state: Dictionary = OverworldRulesScript.town_occupation_state(session, town)
	if bool(occupation_state.get("active", false)) and String(occupation_state.get("faction_id", "")) == faction_id:
		bonus += int(occupation_state.get("target_bonus", 0))
	if objective_anchor:
		bonus += 20
	return max(0, bonus)

static func _town_staging_tiles(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	var options = []
	var map_size: Vector2i = OverworldRulesScript.derive_map_size(session)
	var town_x = int(town.get("x", 0))
	var town_y = int(town.get("y", 0))
	for delta in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = town_x + delta.x
		var ny: int = town_y + delta.y
		if nx < 0 or ny < 0 or nx >= map_size.x or ny >= map_size.y:
			continue
		if OverworldRulesScript.tile_is_blocked(session, nx, ny):
			continue
		options.append(Vector2i(nx, ny))
	if options.is_empty():
		options.append(Vector2i(town_x, town_y))
	return options

static func _encounter_staging_tiles(session: SessionStateStoreScript.SessionData, encounter: Dictionary) -> Array:
	var options = []
	var map_size: Vector2i = OverworldRulesScript.derive_map_size(session)
	var encounter_x = int(encounter.get("x", 0))
	var encounter_y = int(encounter.get("y", 0))
	for delta in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = encounter_x + delta.x
		var ny: int = encounter_y + delta.y
		if nx < 0 or ny < 0 or nx >= map_size.x or ny >= map_size.y:
			continue
		if OverworldRulesScript.tile_is_blocked(session, nx, ny):
			continue
		options.append(Vector2i(nx, ny))
	if options.is_empty():
		options.append(Vector2i(encounter_x, encounter_y))
	return options

static func _resource_target_priority(session: SessionStateStoreScript.SessionData, node: Variant, faction_id: String) -> int:
	if not (node is Dictionary):
		return 0
	var site = ContentService.get_resource_site(String(node.get("site_id", "")))
	if not _resource_node_contestable_by_faction(node, site, faction_id):
		return 0
	var priority = 85 + int(min(110, _resource_site_strategic_value(site) / 120))
	if _resource_site_is_persistent(site) and String(node.get("collected_by_faction_id", "")) == "player":
		priority += 35
	if String(node.get("collected_by_faction_id", "")) == "player" and int(node.get("response_until_day", 0)) >= session.day:
		priority += 20 + (max(1, int(node.get("response_security_rating", 0))) * 6)
	var delivery_value := _recruit_payload_value(node.get("delivery_manifest", {}))
	if String(node.get("collected_by_faction_id", "")) == "player" and delivery_value > 0:
		priority += 28 + int(min(95, float(delivery_value) / 10.0))
	priority += _linked_player_town_bonus(session, node)
	priority += _objective_proximity_bonus(session, int(node.get("x", 0)), int(node.get("y", 0)))
	return priority

static func _resource_scarcity_value(session: SessionStateStoreScript.SessionData, rewards: Variant) -> int:
	if not (rewards is Dictionary):
		return 0
	var player_resources: Dictionary = session.overworld.get("resources", {})
	var value := 0
	for resource_key in ["wood", "ore", "aetherglass", "embergrain", "peatwax", "verdant_grafts", "brass_scrip", "memory_salt"]:
		var amount: int = max(0, int(rewards.get(resource_key, 0)))
		if amount <= 0:
			continue
		var current: int = max(0, int(player_resources.get(resource_key, 0)))
		if current < 4:
			value += amount * 16
		elif current < 7:
			value += amount * 11
		elif current < 10:
			value += amount * 6
	if max(0, int(player_resources.get("gold", 0))) < 1400:
		value += int(min(18.0, float(max(0, int(rewards.get("gold", 0)))) / 90.0))
	return clampi(value, 0, 42)

static func _resource_route_pressure_value(site: Dictionary) -> int:
	var value := 0
	value += max(0, int(site.get("vision_radius", 0))) * 8
	value += max(0, int(site.get("pressure_guard", 0))) * 12
	value += max(0, int(site.get("pressure_bonus", 0))) * 14
	if String(site.get("family", "")) in LOGISTICS_SITE_FAMILIES:
		value += 12
	value += int(min(30.0, float(_resource_site_support_value(site)) / 45.0))
	return value

static func _resource_guard_cost(site: Dictionary) -> int:
	var neutral_roster: Variant = site.get("neutral_roster", {})
	if not (neutral_roster is Dictionary):
		return 0
	if String(neutral_roster.get("guard_encounter_id", "")) == "" and String(neutral_roster.get("guard_army_group_id", "")) == "":
		return 0
	return 12

static func _resource_target_route_gate(session: SessionStateStoreScript.SessionData, node: Dictionary) -> Dictionary:
	var target_tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	var resolved = session.overworld.get("resolved_encounters", [])
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		if Vector2i(int(encounter.get("x", 0)), int(encounter.get("y", 0))) != target_tile:
			continue
		var placement_id := String(encounter.get("placement_id", ""))
		if resolved is Array and placement_id in resolved:
			continue
		return {
			"kind": "unresolved_encounter",
			"placement_id": placement_id,
			"encounter_id": String(encounter.get("encounter_id", "")),
			"target_placement_id": String(node.get("placement_id", "")),
		}
	return {}

static func _resource_target_debug_reason(
	site: Dictionary,
	player_controlled: bool,
	persistent: bool,
	claim_value: int,
	income_value: int,
	recruit_payload_value: int,
	route_pressure_value: int,
	town_enablement_value: int
) -> String:
	var parts := []
	if player_controlled and persistent:
		if income_value > 0:
			parts.append("denies %s daily" % _resource_payload_summary(site.get("control_income", {})))
		else:
			parts.append("denies persistent site control")
	if recruit_payload_value > 0:
		parts.append("recruit denial")
	if route_pressure_value > 0:
		if max(0, int(site.get("vision_radius", 0))) > 0:
			parts.append("route vision")
		elif max(0, int(site.get("pressure_guard", 0))) > 0 or max(0, int(site.get("pressure_bonus", 0))) > 0:
			parts.append("route pressure")
	if town_enablement_value > 0:
		parts.append("player-town support")
	if parts.is_empty() and claim_value > 0:
		parts.append("claims %s" % _resource_payload_summary(_resource_site_claim_rewards(site)))
	if parts.is_empty():
		parts.append("frontier denial")
	return ", ".join(parts)

static func _resource_target_reason_codes(
	site: Dictionary,
	player_controlled: bool,
	persistent: bool,
	income_value: int,
	recruit_payload_value: int,
	route_pressure_value: int,
	town_enablement_value: int
) -> Array:
	var codes := []
	if player_controlled and persistent and income_value > 0:
		codes.append("persistent_income_denial")
	if recruit_payload_value > 0:
		codes.append("recruit_denial")
	if route_pressure_value > 0:
		if max(0, int(site.get("vision_radius", 0))) > 0:
			codes.append("route_vision")
		else:
			codes.append("route_pressure")
	if town_enablement_value > 0:
		codes.append("player_town_support")
	if codes.is_empty():
		codes.append("route_pressure")
	return codes

static func _resource_target_public_importance(player_controlled: bool, persistent: bool, reason_codes: Array, final_priority: int) -> String:
	if player_controlled and persistent and ("persistent_income_denial" in reason_codes or "recruit_denial" in reason_codes):
		return "high"
	if final_priority >= 260:
		return "medium"
	return "low"

static func _public_reason_from_codes(reason_codes: Array) -> String:
	var codes := _normalize_string_array(reason_codes)
	if "regroup_understrength" in codes:
		return "regrouping understrength host"
	if "town_defense" in codes:
		return "defending threatened town"
	if "site_defense" in codes:
		return "defending held site"
	if "front_stabilization" in codes:
		return "front stabilization"
	if "retake_front" in codes:
		return "retaking captured town"
	if "town_expansion" in codes or "neutral_town_claim" in codes:
		return "neutral town expansion"
	if "resource_risk_staging" in codes or "resource_risk_regroup" in codes:
		return "gathering strength for resource claim"
	if "town_siege" in codes:
		return "town siege remains the main front"
	if "persistent_income_denial" in codes and "recruit_denial" in codes:
		return "recruit and income denial"
	if "persistent_income_denial" in codes and "route_vision" in codes:
		return "income and route vision denial"
	if "persistent_income_denial" in codes:
		return "income denial"
	if "recruit_denial" in codes:
		return "recruit denial"
	if "route_vision" in codes:
		return "route vision denial"
	if "route_pressure" in codes:
		return "route pressure"
	if "objective_front" in codes:
		return "objective front"
	if "site_seized" in codes:
		return "site seized"
	if "site_contested" in codes:
		return "site contested"
	if "artifact_secured" in codes:
		return "artifact secured"
	if "commander_memory" in codes:
		return "known commander focus"
	if "enemy_scouting" in codes:
		return "scouted target"
	return ""

static func _public_event_log_text(text: String) -> String:
	var output := text.strip_edges().replace("\n", " ")
	while output.find("  ") >= 0:
		output = output.replace("  ", " ")
	for token in AI_PUBLIC_EVENT_LOG_BLOCKED_TOKENS:
		if output.contains(String(token)):
			return ""
	return output

static func commander_role_turn_snapshot(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	options: Dictionary = {}
) -> Dictionary:
	if session == null:
		return {}
	normalize_all_commander_rosters(session)
	var roster := commander_roster_for_faction(session, faction_id)
	var role_assignments: Array = options.get("role_assignments", [])
	var origin: Dictionary = options.get("origin", {})
	var role_proposals := []
	for assignment_value in role_assignments:
		if not (assignment_value is Dictionary):
			continue
		var assignment: Dictionary = assignment_value
		var roster_hero_id := String(assignment.get("roster_hero_id", ""))
		var target_id := String(assignment.get("target_id", ""))
		var commander_entry := _commander_roster_entry(roster, roster_hero_id)
		if commander_entry.is_empty():
			continue
		var target_view := commander_role_resource_target_view(session, config, faction_id, target_id, origin)
		var proposal := commander_role_proposal_for_resource_target(
			session,
			config,
			faction_id,
			commander_entry,
			target_view,
			assignment.get("fixture_state", {})
		)
		role_proposals.append(_turn_transcript_role_proposal(session, faction_id, commander_entry, target_view, proposal))
	return {
		"schema_status": "derived_turn_transcript_report_only",
		"source_policy": "snapshot_derived",
		"scenario_id": String(session.scenario_id),
		"day": int(session.day),
		"faction_id": faction_id,
		"faction_label": String(config.get("label", faction_id)),
		"enemy_state": _turn_transcript_enemy_state_counts(session, faction_id),
		"active_raids": _turn_transcript_active_raid_snapshots(session, faction_id),
		"commander_links": _turn_transcript_commander_links(session, faction_id),
		"resource_controllers": _turn_transcript_resource_controller_map(session),
		"derived_role_proposals": role_proposals,
		"town_governor_supporting_event_refs": _turn_transcript_town_governor_refs(
			options.get("town_governor_reports", []),
			String(options.get("supporting_front_id", ""))
		),
		"battle_pending": not session.battle.is_empty(),
	}

static func commander_role_turn_transcript_report(
	before_snapshot: Dictionary,
	after_snapshot: Dictionary,
	config: Dictionary,
	turn_result: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var faction_id := String(after_snapshot.get("faction_id", before_snapshot.get("faction_id", config.get("faction_id", ""))))
	var scenario_id := String(after_snapshot.get("scenario_id", before_snapshot.get("scenario_id", "")))
	var case_id := String(options.get("case_id", "%s_%s_turn" % [scenario_id, faction_id]))
	var before_proposals := _turn_transcript_timed_proposals(before_snapshot.get("derived_role_proposals", []), "before_turn")
	var after_proposals := _turn_transcript_timed_proposals(after_snapshot.get("derived_role_proposals", []), "after_turn")
	var assignment_records := _turn_transcript_target_assignment_records(before_snapshot, after_snapshot)
	var no_op_records := _turn_transcript_target_no_op_records(before_snapshot, before_proposals, assignment_records)
	var movement_summary := _turn_transcript_raid_movement_summary(before_snapshot, after_snapshot)
	var arrival_summary := _turn_transcript_raid_arrival_summary(before_snapshot, after_snapshot)
	var town_refs := _turn_transcript_merge_town_refs(
		before_snapshot.get("town_governor_supporting_event_refs", []),
		after_snapshot.get("town_governor_supporting_event_refs", [])
	)
	var phase_records := _turn_transcript_phase_records(
		before_snapshot,
		after_snapshot,
		assignment_records,
		movement_summary,
		arrival_summary,
		town_refs
	)
	var public_events := _turn_transcript_public_events(
		before_snapshot,
		after_snapshot,
		before_proposals,
		assignment_records,
		movement_summary,
		arrival_summary,
		town_refs,
		phase_records
	)
	var leak_check := commander_role_public_leak_check(public_events)
	var source_marker_check := _turn_transcript_source_marker_check(
		[
			phase_records,
			before_snapshot.get("commander_links", []),
			after_snapshot.get("commander_links", []),
			before_proposals,
			after_proposals,
			assignment_records,
			no_op_records,
			movement_summary,
			arrival_summary,
			town_refs,
			public_events,
		]
	)
	var pass_criteria := [
		"Existing EnemyTurnRules.run_enemy_turn executed once for this fixture.",
		"Before/after commander links and role proposals are snapshot-derived only.",
		"Relevant commanders have either a target assignment record or a recognized no-op reason.",
		"Public transcript events pass compact leak checks.",
	]
	var ok := bool(turn_result.get("ok", false)) and bool(leak_check.get("ok", false)) and bool(source_marker_check.get("ok", false)) and _turn_transcript_no_ops_valid(no_op_records)
	return {
		"case_id": case_id,
		"scenario_id": scenario_id,
		"faction_id": faction_id,
		"day_before": int(before_snapshot.get("day", 0)),
		"day_after": int(after_snapshot.get("day", 0)),
		"fixture_setup": options.get("fixture_setup", {}),
		"turn_result": {
			"ok": bool(turn_result.get("ok", false)),
			"message_summary": String(turn_result.get("message", "")),
		},
		"phase_records": phase_records,
		"active_commander_links": {
			"before": before_snapshot.get("commander_links", []),
			"after": after_snapshot.get("commander_links", []),
		},
		"derived_role_proposals": {
			"before_turn": before_proposals,
			"after_turn": after_proposals,
		},
		"target_assignment_records": assignment_records,
		"target_no_op_records": no_op_records,
		"raid_movement_summary": movement_summary,
		"raid_arrival_summary": arrival_summary,
		"town_governor_supporting_event_refs": town_refs,
		"public_transcript_events": public_events,
		"public_leak_check": leak_check,
		"source_marker_check": source_marker_check,
		"case_pass_criteria": pass_criteria,
		"ok": ok,
	}

static func commander_role_turn_transcript_public_leak_check(public_surfaces: Variant) -> Dictionary:
	return commander_role_public_leak_check(public_surfaces)

static func commander_role_adoption_boundary_report(
	state_report: Dictionary,
	turn_report: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var day: int = max(0, int(options.get("day", turn_report.get("day_after", state_report.get("day", 0)))))
	var faction_id: String = String(options.get("faction_id", turn_report.get("faction_id", state_report.get("faction_id", ""))))
	var faction_label: String = String(options.get("faction_label", faction_id))
	var state_signal: Dictionary = _commander_role_state_report_signal(state_report)
	var turn_signal: Dictionary = _commander_role_turn_report_signal(turn_report)
	var records: Array = _commander_role_adoption_boundary_records(state_signal, turn_signal)
	var public_events: Array = []
	for index in range(records.size()):
		public_events.append(_commander_role_adoption_public_event(records[index], day, faction_id, faction_label, index))
	var leak_check: Dictionary = commander_role_adoption_boundary_public_leak_check(public_events)
	var report_only_ready: Array = []
	var deferred: Array = []
	var blocked: Array = []
	var live_selected: bool = false
	var save_write_selected: bool = false
	var migration_selected: bool = false
	for record in records:
		if not (record is Dictionary):
			continue
		match String(record.get("boundary_status", "")):
			"adopt_report_only":
				report_only_ready.append(String(record.get("surface_id", "")))
			"defer":
				deferred.append(String(record.get("surface_id", "")))
			_:
				blocked.append(String(record.get("surface_id", "")))
		live_selected = live_selected or bool(record.get("live_behavior_selected", false))
		save_write_selected = save_write_selected or bool(record.get("save_write_selected", false))
		migration_selected = migration_selected or bool(record.get("requires_save_migration", false))
	var ok: bool = (
		bool(state_signal.get("ok", false))
		and bool(turn_signal.get("ok", false))
		and bool(leak_check.get("ok", false))
		and blocked.is_empty()
		and not live_selected
		and not save_write_selected
		and not migration_selected
	)
	return {
		"ok": ok,
		"boundary_id": "strategic-ai-commander-role-adoption-boundary-10184",
		"schema_status": "commander_role_adoption_boundary_report_only",
		"behavior_policy": "no_live_commander_role_behavior_adoption",
		"save_policy": "no_commander_role_state_write",
		"event_log_policy": "no_durable_event_log",
		"source_reports": [state_signal, turn_signal],
		"boundary_records": records,
		"report_only_ready_surfaces": report_only_ready,
		"deferred_surfaces": deferred,
		"public_boundary_events": public_events,
		"public_leak_check": leak_check,
		"save_version_before": int(SessionStateStoreScript.SAVE_VERSION),
		"save_version_after": int(SessionStateStoreScript.SAVE_VERSION),
		"live_behavior_selected": live_selected,
		"save_write_selected": save_write_selected,
		"requires_save_migration": migration_selected,
		"completion_policy": "explicit_boundary_from_passed_reports_no_runtime_adoption",
	}

static func commander_role_adoption_boundary_public_leak_check(public_surfaces: Variant) -> Dictionary:
	var stack: Array = [public_surfaces]
	var checked_events: int = 0
	while not stack.is_empty():
		var value = stack.pop_back()
		if value is Array:
			for item in value:
				stack.append(item)
			continue
		if not (value is Dictionary):
			var value_text: String = String(value)
			for token in COMMANDER_ROLE_ADOPTION_BLOCKED_PUBLIC_TOKENS:
				if value_text.contains(String(token)):
					return {"ok": false, "error": "public adoption boundary surface leaked token %s" % String(token)}
			continue
		if String(value.get("event_type", "")) != "":
			checked_events += 1
			for key in value.keys():
				if String(key) not in COMMANDER_ROLE_ADOPTION_PUBLIC_EVENT_KEYS:
					return {"ok": false, "error": "%s leaked non-compact key %s" % [value.get("event_type", "event"), key]}
		var text: String = JSON.stringify(value)
		for token in COMMANDER_ROLE_ADOPTION_BLOCKED_PUBLIC_TOKENS:
			if text.contains(String(token)):
				return {"ok": false, "error": "%s leaked blocked token %s" % [value.get("event_type", "event"), token]}
		for nested_key in value.keys():
			var nested = value[nested_key]
			if nested is Array or nested is Dictionary:
				stack.append(nested)
	return {
		"ok": true,
		"checked_events": checked_events,
		"allowed_public_event_keys": COMMANDER_ROLE_ADOPTION_PUBLIC_EVENT_KEYS,
		"blocked_public_tokens": COMMANDER_ROLE_ADOPTION_BLOCKED_PUBLIC_TOKENS,
	}

static func _commander_role_state_report_signal(report: Dictionary) -> Dictionary:
	var leak_check: Dictionary = report.get("public_leak_check", {}) if report.get("public_leak_check", {}) is Dictionary else {}
	var cases: Array = report.get("cases", []) if report.get("cases", []) is Array else []
	return {
		"report_id": String(report.get("report_id", "AI_COMMANDER_ROLE_STATE_REPORT")),
		"ok": bool(report.get("ok", false)),
		"schema_status": String(report.get("schema_status", "")),
		"case_count": cases.size(),
		"public_leak_ok": bool(leak_check.get("ok", false)),
		"checked_public_events": int(leak_check.get("checked_events", 0)),
		"signal_policy": "report_fixture_only",
	}

static func _commander_role_turn_report_signal(report: Dictionary) -> Dictionary:
	var leak_check: Dictionary = report.get("public_leak_check", {}) if report.get("public_leak_check", {}) is Dictionary else {}
	var cases: Array = report.get("cases", []) if report.get("cases", []) is Array else []
	var phase_count: int = 0
	var arrival_count: int = 0
	var no_op_count: int = 0
	var town_ref_count: int = 0
	for case_value in cases:
		if not (case_value is Dictionary):
			continue
		var case_report: Dictionary = case_value
		phase_count += case_report.get("phase_records", []).size() if case_report.get("phase_records", []) is Array else 0
		arrival_count += case_report.get("raid_arrival_summary", []).size() if case_report.get("raid_arrival_summary", []) is Array else 0
		no_op_count += case_report.get("target_no_op_records", []).size() if case_report.get("target_no_op_records", []) is Array else 0
		town_ref_count += case_report.get("town_governor_supporting_event_refs", []).size() if case_report.get("town_governor_supporting_event_refs", []) is Array else 0
	return {
		"report_id": String(report.get("report_id", "AI_COMMANDER_ROLE_TURN_TRANSCRIPT_REPORT")),
		"ok": bool(report.get("ok", false)),
		"schema_status": String(report.get("schema_status", "")),
		"behavior_policy": String(report.get("behavior_policy", "")),
		"save_policy": String(report.get("save_policy", "")),
		"case_count": cases.size(),
		"phase_record_count": phase_count,
		"arrival_record_count": arrival_count,
		"no_op_record_count": no_op_count,
		"town_governor_ref_count": town_ref_count,
		"public_leak_ok": bool(leak_check.get("ok", false)),
		"checked_public_events": int(leak_check.get("checked_events", 0)),
		"signal_policy": "derived_turn_transcript_report_only",
	}

static func _commander_role_adoption_boundary_records(state_signal: Dictionary, turn_signal: Dictionary) -> Array:
	var state_ready: bool = (
		bool(state_signal.get("ok", false))
		and String(state_signal.get("schema_status", "")) == "report_fixture_only"
		and int(state_signal.get("case_count", 0)) > 0
		and bool(state_signal.get("public_leak_ok", false))
	)
	var turn_ready: bool = (
		bool(turn_signal.get("ok", false))
		and String(turn_signal.get("schema_status", "")) == "derived_turn_transcript_report_only"
		and String(turn_signal.get("behavior_policy", "")) == "observe_existing_enemy_turn_only"
		and String(turn_signal.get("save_policy", "")) == "no_commander_role_state_write"
		and int(turn_signal.get("case_count", 0)) > 0
		and int(turn_signal.get("phase_record_count", 0)) > 0
		and bool(turn_signal.get("public_leak_ok", false))
	)
	var records: Array = [
		_commander_role_adoption_record(
			"derived_role_proposals",
			"Derived role proposals",
			"adopt_report_only" if state_ready else "blocked",
			"Role labels, assignment hints, and public reasons can remain report evidence.",
			"report evidence only",
			["AI_COMMANDER_ROLE_STATE_REPORT"],
			"state_report_passed" if state_ready else "state_report_not_ready"
		),
		_commander_role_adoption_record(
			"turn_transcript",
			"Turn transcript",
			"adopt_report_only" if turn_ready else "blocked",
			"Before and after turn snapshots can remain behavior-neutral report evidence.",
			"report evidence only",
			["AI_COMMANDER_ROLE_TURN_TRANSCRIPT_REPORT"],
			"transcript_gate_passed" if turn_ready else "transcript_not_ready"
		),
		_commander_role_adoption_record(
			"compact_public_events",
			"Compact public events",
			"adopt_report_only" if state_ready and turn_ready else "blocked",
			"Compact events are safe for report fixtures after recursive leak checks.",
			"report evidence only",
			["AI_COMMANDER_ROLE_STATE_REPORT", "AI_COMMANDER_ROLE_TURN_TRANSCRIPT_REPORT"],
			"public_leak_checks_passed" if state_ready and turn_ready else "public_leak_checks_not_ready"
		),
		_commander_role_adoption_record(
			"town_governor_refs",
			"Town governor references",
			"adopt_report_only" if turn_ready and int(turn_signal.get("town_governor_ref_count", 0)) > 0 else "blocked",
			"Town governor refs can support reports without becoming event authority.",
			"supporting report evidence",
			["AI_COMMANDER_ROLE_TURN_TRANSCRIPT_REPORT"],
			"support_refs_present" if int(turn_signal.get("town_governor_ref_count", 0)) > 0 else "support_refs_missing"
		),
		_commander_role_adoption_record(
			"commander_role_state_write",
			"Role continuity field",
			"defer",
			"Passed reports explain current outcomes from existing roster and encounter state.",
			"needs later gate",
			["strategic-ai-commander-role-live-turn-transcript-report-gate-review"],
			"no_continuity_need_proven",
			false,
			false,
			true
		),
		_commander_role_adoption_record(
			"save_migration",
			"Compatibility migration",
			"defer",
			"Current evidence keeps compatibility unchanged and does not require migration.",
			"needs later gate",
			["strategic-ai-commander-role-live-turn-transcript-report-gate-review"],
			"no_migration_selected",
			false,
			false,
			true
		),
		_commander_role_adoption_record(
			"live_commander_role_behavior",
			"Live commander behavior",
			"defer",
			"The transcript observes existing enemy turns without selecting new behavior.",
			"needs later gate",
			["strategic-ai-commander-role-adoption-sequencing-plan"],
			"live_behavior_not_selected",
			true,
			false,
			false
		),
		_commander_role_adoption_record(
			"durable_event_log",
			"Persistent event history",
			"defer",
			"Compact report events are derived and do not need persistent history.",
			"needs later gate",
			["strategic-ai-commander-role-live-turn-transcript-report-gate-review"],
			"persistent_log_not_selected",
			false,
			false,
			false,
			true
		),
		_commander_role_adoption_record(
			"full_ai_hero_task_state",
			"Full AI hero tasks",
			"defer",
			"Task execution still needs its own route, invalidation, and ownership gates.",
			"needs later gate",
			["strategic-ai-hero-task-state-boundary-plan"],
			"task_execution_out_of_scope",
			true,
			false,
			false
		),
	]
	return records

static func _commander_role_adoption_record(
	surface_id: String,
	surface_label: String,
	boundary_status: String,
	internal_reason: String,
	public_reason: String,
	source_report_ids: Array,
	reason_code: String,
	live_behavior_risk: bool = false,
	save_write_risk: bool = false,
	schema_risk: bool = false,
	durable_log_risk: bool = false
) -> Dictionary:
	return {
		"surface_id": surface_id,
		"surface_label": surface_label,
		"boundary_status": boundary_status,
		"public_status": "ready_report_only" if boundary_status == "adopt_report_only" else boundary_status,
		"adoption_scope": "report_helper_only" if boundary_status == "adopt_report_only" else "deferred",
		"reason_code": reason_code,
		"reason": internal_reason,
		"public_reason": public_reason,
		"source_report_ids": source_report_ids,
		"live_behavior_selected": false,
		"save_write_selected": false,
		"requires_save_migration": false,
		"risk_flags": {
			"live_behavior_risk": live_behavior_risk,
			"save_write_risk": save_write_risk,
			"schema_risk": schema_risk,
			"durable_log_risk": durable_log_risk,
		},
		"state_policy": "report_only",
	}

static func _commander_role_adoption_public_event(
	record: Dictionary,
	day: int,
	faction_id: String,
	faction_label: String,
	sequence: int
) -> Dictionary:
	var status := String(record.get("public_status", "deferred"))
	var public_reason := String(record.get("public_reason", "needs later gate"))
	var surface_id := String(record.get("surface_id", ""))
	var target_id := _commander_role_adoption_public_target_id(surface_id)
	var surface_label := _commander_role_adoption_public_target_label(surface_id, String(record.get("surface_label", surface_id)))
	var public_reason_code := _commander_role_adoption_public_reason_code(String(record.get("reason_code", "")))
	var summary := "%s is %s (%s)." % [surface_label, status.replace("_", " "), public_reason]
	return {
		"event_id": "%d:%s:ai_commander_role_boundary:%s:%d" % [day, faction_id, target_id, sequence],
		"day": day,
		"sequence": sequence,
		"event_type": "ai_commander_role_boundary",
		"faction_id": faction_id,
		"faction_label": faction_label,
		"actor_id": "strategic_ai",
		"actor_label": "Strategic AI",
		"target_kind": "boundary",
		"target_id": target_id,
		"target_label": surface_label,
		"visibility": "hidden_report",
		"public_importance": "low",
		"summary": summary,
		"reason_codes": [public_reason_code],
		"public_reason": public_reason,
		"state_policy": "report_only",
	}

static func _commander_role_adoption_public_target_id(surface_id: String) -> String:
	match surface_id:
		"commander_role_state_write":
			return "continuity_field"
		"save_migration":
			return "compatibility_path"
		"live_commander_role_behavior":
			return "turn_behavior"
		"durable_event_log":
			return "event_history"
		"full_ai_hero_task_state":
			return "hero_tasks"
	return surface_id

static func _commander_role_adoption_public_target_label(surface_id: String, fallback: String) -> String:
	match surface_id:
		"commander_role_state_write":
			return "Continuity field"
		"save_migration":
			return "Compatibility path"
		"live_commander_role_behavior":
			return "Turn behavior"
		"durable_event_log":
			return "Event history"
		"full_ai_hero_task_state":
			return "Hero tasks"
	return fallback

static func _commander_role_adoption_public_reason_code(reason_code: String) -> String:
	match reason_code:
		"no_continuity_need_proven":
			return "later_continuity_gate"
		"no_migration_selected":
			return "later_compatibility_gate"
		"live_behavior_not_selected":
			return "later_behavior_gate"
		"persistent_log_not_selected":
			return "later_history_gate"
		"task_execution_out_of_scope":
			return "later_task_gate"
	return reason_code

static func ai_hero_task_candidate_from_role(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	commander_entry: Dictionary,
	role_record: Dictionary,
	local_sequence: int,
	options: Dictionary = {}
) -> Dictionary:
	var actor_id := String(role_record.get("roster_hero_id", commander_entry.get("roster_hero_id", "")))
	var actor_label := String(role_record.get("commander_label", commander_display_name(commander_entry, false)))
	if actor_label == "":
		actor_label = actor_id
	var source_role := String(role_record.get("role", COMMANDER_ROLE_RESERVE))
	var role_status := String(role_record.get("role_status", ""))
	var target_kind := String(role_record.get("target_kind", ""))
	var target_id := String(role_record.get("target_id", ""))
	var task_class := String(options.get("task_class", _ai_hero_task_class_for_role(source_role, target_kind, role_status)))
	if task_class in ["recover_commander", "rebuild_host", "reserve"]:
		target_kind = "commander"
		target_id = actor_id
	var assigned_day := int(options.get("assigned_day", int(session.day) if session != null else 0))
	var task_id := ai_hero_task_candidate_id(
		String(session.scenario_id) if session != null else "",
		faction_id,
		actor_id,
		task_class,
		target_kind,
		target_id,
		assigned_day,
		local_sequence
	)
	var source_id := String(role_record.get("assignment_id_hint", ""))
	if source_id == "":
		source_id = _ai_hero_task_source_id(
			String(session.scenario_id) if session != null else "",
			faction_id,
			actor_id,
			source_role,
			target_kind,
			target_id,
			assigned_day
		)
	var controller_before := String(role_record.get("target_controller_before", ""))
	var target_label := String(role_record.get("target_label", target_id))
	var target_x := int(role_record.get("target_x", 0))
	var target_y := int(role_record.get("target_y", 0))
	if target_kind == "resource":
		var target_view := ai_hero_task_resource_target_snapshot(session, target_id)
		if not target_view.is_empty():
			if controller_before == "":
				controller_before = String(target_view.get("controller_id", ""))
			target_label = String(target_view.get("target_label", target_label))
			target_x = int(target_view.get("x", target_x))
			target_y = int(target_view.get("y", target_y))
	var validation := "valid"
	var task_status := String(options.get("task_status", "candidate"))
	if task_class == "recover_commander":
		task_status = "blocked"
		validation = "invalid_actor_recovering"
	elif task_class == "rebuild_host":
		task_status = "blocked"
		validation = "invalid_actor_rebuilding"
	elif target_kind == "resource" and ai_hero_task_resource_target_snapshot(session, target_id).is_empty():
		task_status = "invalid"
		validation = "invalid_target_missing"
	validation = String(options.get("last_validation", validation))
	var reservation := _ai_hero_task_default_reservation(task_class, target_kind, target_id)
	var active_link := commander_role_active_encounter_link(session, faction_id, actor_id)
	return {
		"task_id": task_id,
		"task_status": task_status,
		"owner_faction_id": faction_id,
		"actor_kind": "commander_roster",
		"actor_id": actor_id,
		"actor_label": actor_label,
		"actor_active_linked": bool(active_link.get("linked", false)),
		"active_placement_id": String(active_link.get("placement_id", "")),
		"source_kind": AI_HERO_TASK_SOURCE_KIND,
		"source_id": source_id,
		"source_role": source_role,
		"source_timing": String(role_record.get("timing", options.get("source_timing", "before_turn"))),
		"source_policy": String(role_record.get("state_policy", "report_only")),
		"task_class": task_class,
		"target_kind": target_kind,
		"target_id": target_id,
		"target_label": target_label,
		"target_x": target_x,
		"target_y": target_y,
		"target_controller_before": controller_before,
		"target_controller_after": String(options.get("target_controller_after", controller_before)),
		"target_owner_expected": String(options.get("target_owner_expected", _ai_hero_task_target_owner_expected(task_class, controller_before, faction_id))),
		"front_id": String(role_record.get("front_id", commander_role_front_id(String(session.scenario_id) if session != null else "", target_kind, target_id))),
		"origin_kind": "town",
		"origin_id": String(options.get("origin_id", commander_role_origin_id(String(session.scenario_id) if session != null else "", faction_id))),
		"priority_reason_codes": _normalize_string_array(role_record.get("priority_reason_codes", [])),
		"assigned_day": assigned_day,
		"expires_day": assigned_day + 3,
		"continuity_policy": "persist_until_invalid",
		"route_policy": "derive_route_on_turn",
		"reservation": reservation,
		"claim_status": String(options.get("claim_status", "")),
		"last_validation": validation,
		"state_policy": AI_HERO_TASK_STATE_POLICY,
	}

static func ai_hero_task_candidate_id(
	scenario_id: String,
	faction_id: String,
	actor_id: String,
	task_class: String,
	target_kind: String,
	target_id: String,
	assigned_day: int,
	local_sequence: int
) -> String:
	return "task:%s:%s:%s:%s:%s:%s:day_%d:seq_%d" % [
		scenario_id,
		faction_id,
		actor_id,
		task_class,
		target_kind,
		target_id,
		assigned_day,
		max(1, local_sequence),
	]

static func ai_hero_task_resource_target_snapshot(
	session: SessionStateStoreScript.SessionData,
	target_id: String
) -> Dictionary:
	if session == null or target_id == "":
		return {}
	var node_result := _find_resource_by_placement(session, target_id)
	var node: Dictionary = node_result.get("node", {})
	if int(node_result.get("index", -1)) < 0:
		return {}
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	return {
		"target_kind": "resource",
		"target_id": target_id,
		"target_label": String(site.get("name", target_id)),
		"controller_id": String(node.get("collected_by_faction_id", "")),
		"site_id": String(node.get("site_id", "")),
		"x": int(node.get("x", 0)),
		"y": int(node.get("y", 0)),
		"state_policy": "derived",
	}

static func ai_hero_task_apply_reservations(tasks_value: Variant) -> Array:
	var tasks: Array = tasks_value.duplicate(true) if tasks_value is Array else []
	var exclusive_by_key := {}
	for index in range(tasks.size()):
		if not (tasks[index] is Dictionary):
			continue
		var task: Dictionary = tasks[index]
		var reservation: Dictionary = task.get("reservation", {})
		if String(reservation.get("reservation_scope", "")) != "exclusive_target":
			continue
		var key := String(reservation.get("reservation_key", ""))
		if key == "":
			continue
		if not exclusive_by_key.has(key):
			exclusive_by_key[key] = []
		exclusive_by_key[key].append(index)
	for key in exclusive_by_key.keys():
		var indexes: Array = exclusive_by_key[key]
		if indexes.size() <= 1:
			continue
		indexes.sort_custom(func(a: int, b: int) -> bool:
			return _ai_hero_task_reservation_sort_key(tasks[a]) < _ai_hero_task_reservation_sort_key(tasks[b])
		)
		var primary_index := int(indexes[0])
		var primary_task: Dictionary = tasks[primary_index]
		var primary_reservation: Dictionary = primary_task.get("reservation", {})
		primary_reservation["reservation_status"] = "primary"
		primary_task["reservation"] = primary_reservation
		if String(primary_task.get("last_validation", "")) == "invalid_target_reserved":
			primary_task["last_validation"] = "valid"
			primary_task["task_status"] = "candidate"
		tasks[primary_index] = primary_task
		for loser_position in range(1, indexes.size()):
			var loser_index := int(indexes[loser_position])
			var loser: Dictionary = tasks[loser_index]
			var loser_reservation: Dictionary = loser.get("reservation", {})
			loser_reservation["reservation_status"] = "rejected_duplicate"
			loser_reservation["reservation_scope"] = "exclusive_target"
			loser["reservation"] = loser_reservation
			loser["task_status"] = "invalid"
			loser["last_validation"] = "invalid_target_reserved"
			loser["invalidated_by_task_id"] = String(primary_task.get("task_id", ""))
			tasks[loser_index] = loser
	return tasks

static func ai_hero_task_transition_from_arrival(retake_task: Dictionary, arrival: Dictionary) -> Dictionary:
	var task_target := "%s:%s" % [String(retake_task.get("target_kind", "")), String(retake_task.get("target_id", ""))]
	var arrival_target := "%s:%s" % [String(arrival.get("target_kind", "")), String(arrival.get("target_id", ""))]
	var owner_faction_id := String(retake_task.get("owner_faction_id", ""))
	var controller_after := String(arrival.get("target_controller_after", ""))
	var completed := (
		String(retake_task.get("task_class", "")) == "retake_site"
		and task_target == arrival_target
		and owner_faction_id != ""
		and controller_after == owner_faction_id
	)
	var reservation: Dictionary = retake_task.get("reservation", {})
	return {
		"task_id": String(retake_task.get("task_id", "")),
		"target_kind": String(retake_task.get("target_kind", "")),
		"target_id": String(retake_task.get("target_id", "")),
		"arrival_placement_id": String(arrival.get("placement_id", "")),
		"target_controller_before": String(arrival.get("target_controller_before", "")),
		"target_controller_after": controller_after,
		"transition_result": "completed_by_controller_flip" if completed else "no_completion",
		"retake_open_after_arrival": not completed,
		"released_reservation_key": String(reservation.get("reservation_key", "")) if completed else "",
		"last_validation_after_arrival": "invalid_controller_changed" if completed else String(retake_task.get("last_validation", "")),
		"state_policy": "derived",
	}

static func ai_hero_task_old_save_absence_check(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var saved_present := false
	var saved_count := 0
	if session != null:
		for state_value in session.overworld.get("enemy_states", []):
			if not (state_value is Dictionary):
				continue
			var state: Dictionary = state_value
			if not state.has("hero_task_state"):
				continue
			saved_present = true
			var task_state = state.get("hero_task_state", {})
			if task_state is Dictionary:
				var tasks = task_state.get("tasks", [])
				if tasks is Array:
					saved_count += tasks.size()
	var save_version := int(SessionStateStoreScript.SAVE_VERSION)
	return {
		"ok": not saved_present and saved_count == 0,
		"saved_task_board_present": saved_present,
		"saved_task_count": saved_count,
		"derived_candidate_tasks_allowed": true,
		"save_version_before": save_version,
		"save_version_after": save_version,
		"normalization_policy": "missing_hero_task_state_means_no_saved_tasks",
		"write_check": "no_hero_task_state_write",
		"state_policy": "derived",
	}

static func ai_hero_task_public_event(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	candidate_task: Dictionary,
	sequence: int,
	event_type: String = "ai_hero_task_candidate"
) -> Dictionary:
	var reason_codes := _normalize_string_array(candidate_task.get("priority_reason_codes", []))
	var public_reason := _public_reason_from_codes(reason_codes)
	if public_reason == "" and String(candidate_task.get("task_class", "")) == "recover_commander":
		public_reason = "commander recovering"
	elif public_reason == "" and String(candidate_task.get("task_class", "")) == "rebuild_host":
		public_reason = "commander rebuilding"
	var actor_label := String(candidate_task.get("actor_label", candidate_task.get("actor_id", "")))
	var target_label := String(candidate_task.get("target_label", candidate_task.get("target_id", "")))
	var summary := "%s has %s intent for %s" % [
		actor_label,
		String(candidate_task.get("task_class", "front")),
		target_label,
	]
	if public_reason != "":
		summary += " (%s)" % public_reason
	summary += "."
	var day := int(candidate_task.get("assigned_day", int(session.day) if session != null else 0))
	var faction_id := String(candidate_task.get("owner_faction_id", config.get("faction_id", "")))
	var actor_id := String(candidate_task.get("actor_id", ""))
	var target_id := String(candidate_task.get("target_id", ""))
	return {
		"event_id": "%d:%s:%s:%s:%s:%d" % [day, faction_id, event_type, actor_id, target_id, sequence],
		"day": day,
		"sequence": sequence,
		"event_type": event_type,
		"faction_id": faction_id,
		"faction_label": String(config.get("label", faction_id)),
		"actor_id": actor_id,
		"actor_label": actor_label,
		"task_class": String(candidate_task.get("task_class", "")),
		"target_kind": String(candidate_task.get("target_kind", "")),
		"target_id": target_id,
		"target_label": target_label,
		"front_id": String(candidate_task.get("front_id", "")),
		"visibility": "hidden_debug",
		"public_importance": _ai_hero_task_public_importance(candidate_task),
		"summary": summary,
		"reason_codes": reason_codes,
		"public_reason": public_reason,
		"state_policy": AI_HERO_TASK_STATE_POLICY,
	}

static func ai_hero_task_public_leak_check(public_surfaces: Variant) -> Dictionary:
	var stack := [public_surfaces]
	var checked_events := 0
	while not stack.is_empty():
		var value = stack.pop_back()
		if value is Array:
			for item in value:
				stack.append(item)
			continue
		if not (value is Dictionary):
			var value_text := String(value)
			for token in AI_HERO_TASK_BLOCKED_PUBLIC_TOKENS:
				if value_text.contains(String(token)):
					return {"ok": false, "error": "public task surface leaked token %s" % String(token)}
			continue
		if String(value.get("event_type", "")) != "":
			checked_events += 1
			for key in value.keys():
				if String(key) not in AI_HERO_TASK_PUBLIC_EVENT_KEYS:
					return {"ok": false, "error": "%s leaked non-compact key %s" % [value.get("event_type", "event"), key]}
		var text := JSON.stringify(value)
		for token in AI_HERO_TASK_BLOCKED_PUBLIC_TOKENS:
			if text.contains(String(token)):
				return {"ok": false, "error": "%s leaked blocked token %s" % [value.get("event_type", "event"), token]}
		for nested_key in value.keys():
			var nested = value[nested_key]
			if nested is Array or nested is Dictionary:
				stack.append(nested)
	return {
		"ok": true,
		"checked_events": checked_events,
		"allowed_public_event_keys": AI_HERO_TASK_PUBLIC_EVENT_KEYS,
		"blocked_public_tokens": AI_HERO_TASK_BLOCKED_PUBLIC_TOKENS,
	}

static func ai_hero_task_candidate_task_id_check(tasks: Array) -> Dictionary:
	var ids := {}
	var checked := 0
	for task_value in tasks:
		if not (task_value is Dictionary):
			return {"ok": false, "error": "candidate task record is not a dictionary"}
		var task: Dictionary = task_value
		var task_id := String(task.get("task_id", ""))
		var source_id := String(task.get("source_id", ""))
		var parts := task_id.split(":")
		if parts.size() != 9 or parts[0] != "task":
			return {"ok": false, "error": "invalid candidate task id format %s" % task_id}
		if not String(parts[7]).begins_with("day_") or not String(parts[8]).begins_with("seq_"):
			return {"ok": false, "error": "candidate task id missing day/sequence %s" % task_id}
		if task_id.contains(" ") or task_id.contains("/") or task_id.contains("\\"):
			return {"ok": false, "error": "candidate task id contains display/path text %s" % task_id}
		if ids.has(task_id):
			return {"ok": false, "error": "duplicate candidate task id %s" % task_id}
		if source_id == "" or source_id == task_id:
			return {"ok": false, "error": "candidate task %s has invalid source id %s" % [task_id, source_id]}
		ids[task_id] = true
		checked += 1
	return {"ok": true, "checked_tasks": checked, "task_ids": ids.keys()}

static func ai_hero_task_actor_ownership_check(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	tasks: Array
) -> Dictionary:
	var roster := commander_roster_for_faction(session, faction_id)
	var checked := 0
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("owner_faction_id", "")) != faction_id:
			return {"ok": false, "error": "task owner mismatch for %s" % String(task.get("task_id", ""))}
		if String(task.get("actor_kind", "")) != "commander_roster":
			return {"ok": false, "error": "unsupported task actor kind %s" % String(task.get("actor_kind", ""))}
		var actor_id := String(task.get("actor_id", ""))
		if _commander_roster_entry(roster, actor_id).is_empty():
			return {"ok": false, "error": "task actor %s missing from %s roster" % [actor_id, faction_id]}
		checked += 1
	return {"ok": true, "checked_tasks": checked, "actor_kind": "commander_roster"}

static func ai_hero_task_target_ownership_check(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	tasks: Array
) -> Dictionary:
	var checked := 0
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		var target_kind := String(task.get("target_kind", ""))
		var task_class := String(task.get("task_class", ""))
		if target_kind == "resource":
			var target_snapshot := ai_hero_task_resource_target_snapshot(session, String(task.get("target_id", "")))
			if target_snapshot.is_empty():
				return {"ok": false, "error": "task target missing %s" % String(task.get("target_id", ""))}
			var before_controller := String(task.get("target_controller_before", ""))
			if task_class == "retake_site" and before_controller == faction_id:
				return {"ok": false, "error": "retake task target already controlled by owner %s" % String(task.get("target_id", ""))}
			if task_class in ["defend_front", "stabilize_front"] and before_controller != faction_id:
				return {"ok": false, "error": "%s target not owner-held %s" % [task_class, String(task.get("target_id", ""))]}
		elif target_kind == "commander":
			if String(task.get("target_id", "")) != String(task.get("actor_id", "")):
				return {"ok": false, "error": "commander task target must be its actor"}
		else:
			return {"ok": false, "error": "unsupported task target kind %s" % target_kind}
		checked += 1
	return {"ok": true, "checked_tasks": checked}

static func ai_hero_task_role_to_task_source_check(tasks: Array) -> Dictionary:
	var checked := 0
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("source_kind", "")) != AI_HERO_TASK_SOURCE_KIND:
			return {"ok": false, "error": "task source kind is not commander role adapter"}
		if String(task.get("state_policy", "")) != AI_HERO_TASK_STATE_POLICY:
			return {"ok": false, "error": "task state policy is not report-only"}
		if _ai_hero_task_class_for_role(String(task.get("source_role", "")), String(task.get("target_kind", "")), _ai_hero_task_role_status_from_task_class(String(task.get("task_class", "")))) != String(task.get("task_class", "")):
			return {"ok": false, "error": "source role %s did not map to task class %s" % [task.get("source_role", ""), task.get("task_class", "")]}
		if String(task.get("source_id", "")) == "" or String(task.get("source_id", "")) == String(task.get("task_id", "")):
			return {"ok": false, "error": "task source id is missing or reused"}
		checked += 1
	return {"ok": true, "checked_tasks": checked, "source_kind": AI_HERO_TASK_SOURCE_KIND}

static func ai_hero_task_target_reservation_check(tasks: Array) -> Dictionary:
	var primary_by_key := {}
	var checked := 0
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		var task_class := String(task.get("task_class", ""))
		var reservation: Dictionary = task.get("reservation", {})
		var scope := String(reservation.get("reservation_scope", ""))
		var status := String(reservation.get("reservation_status", ""))
		var key := String(reservation.get("reservation_key", ""))
		if task_class in AI_HERO_TASK_EXCLUSIVE_CLASSES:
			if String(task.get("task_status", "")) == "completed" and status == "released":
				checked += 1
				continue
			if scope != "exclusive_target" or key == "":
				return {"ok": false, "error": "%s task missing exclusive reservation" % task_class}
			if status == "primary":
				if primary_by_key.has(key):
					return {"ok": false, "error": "duplicate primary reservation for %s" % key}
				primary_by_key[key] = String(task.get("task_id", ""))
		elif task_class == "stabilize_front":
			if scope not in ["shared_front", "none"]:
				return {"ok": false, "error": "stabilizer used invalid reservation scope %s" % scope}
		elif task_class in ["recover_commander", "rebuild_host"]:
			if scope != "none":
				return {"ok": false, "error": "%s must not reserve map targets" % task_class}
		checked += 1
	return {
		"ok": true,
		"checked_tasks": checked,
		"primary_reservation_count": primary_by_key.keys().size(),
		"primary_reservations": primary_by_key,
	}

static func ai_hero_task_invalidation_check(tasks: Array, transitions: Array = []) -> Dictionary:
	var checked := 0
	var codes := {}
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		var validation := String(task.get("last_validation", ""))
		if validation == "":
			return {"ok": false, "error": "task missing validation %s" % String(task.get("task_id", ""))}
		codes[validation] = int(codes.get(validation, 0)) + 1
		if validation == "invalid_target_reserved" and String(task.get("invalidated_by_task_id", "")) == "":
			return {"ok": false, "error": "duplicate-reserved task missing invalidating task id"}
		if String(task.get("task_class", "")) in ["recover_commander", "rebuild_host"] and String(task.get("reservation", {}).get("reservation_scope", "")) != "none":
			return {"ok": false, "error": "blocked commander task reserved a map target"}
		checked += 1
	for transition_value in transitions:
		if not (transition_value is Dictionary):
			continue
		var transition: Dictionary = transition_value
		if String(transition.get("transition_result", "")) == "completed_by_controller_flip":
			if bool(transition.get("retake_open_after_arrival", true)):
				return {"ok": false, "error": "completed controller flip still leaves retake open"}
			if String(transition.get("last_validation_after_arrival", "")) != "invalid_controller_changed":
				return {"ok": false, "error": "controller flip transition missing invalid_controller_changed"}
			codes["invalid_controller_changed"] = int(codes.get("invalid_controller_changed", 0)) + 1
	return {"ok": true, "checked_tasks": checked, "validation_codes": codes}

static func ai_hero_task_live_adoption_gate_report(
	task_boundary_report: Dictionary,
	normalizer_report: Dictionary,
	commander_boundary_report: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	var day: int = max(0, int(options.get("day", task_boundary_report.get("day", 0))))
	var faction_id: String = String(options.get("faction_id", task_boundary_report.get("faction_id", "")))
	var faction_label: String = String(options.get("faction_label", faction_id))
	var task_signal := _ai_hero_task_boundary_signal(task_boundary_report)
	var normalizer_signal := _ai_hero_task_normalizer_signal(normalizer_report)
	var commander_signal := _ai_hero_task_commander_adoption_signal(commander_boundary_report)
	var records := _ai_hero_task_live_adoption_gate_records(task_signal, normalizer_signal, commander_signal)
	var public_events: Array = []
	for index in range(records.size()):
		public_events.append(_ai_hero_task_live_adoption_gate_event(records[index], day, faction_id, faction_label, index))
	var leak_check := ai_hero_task_live_adoption_gate_public_leak_check(public_events)
	var report_ready_surfaces: Array = []
	var deferred_surfaces: Array = []
	var blocked_surfaces: Array = []
	var live_selected := false
	var save_write_selected := false
	var migration_selected := false
	for record_value in records:
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		match String(record.get("gate_status", "")):
			"ready_report_only":
				report_ready_surfaces.append(String(record.get("surface_id", "")))
			"defer":
				deferred_surfaces.append(String(record.get("surface_id", "")))
			_:
				blocked_surfaces.append(String(record.get("surface_id", "")))
		live_selected = live_selected or bool(record.get("live_behavior_selected", false))
		save_write_selected = save_write_selected or bool(record.get("save_write_selected", false))
		migration_selected = migration_selected or bool(record.get("requires_save_migration", false))
	var ok := (
		bool(task_signal.get("ok", false))
		and bool(normalizer_signal.get("ok", false))
		and bool(commander_signal.get("ok", false))
		and bool(leak_check.get("ok", false))
		and blocked_surfaces.is_empty()
		and not deferred_surfaces.is_empty()
		and not live_selected
		and not save_write_selected
		and not migration_selected
	)
	return {
		"ok": ok,
		"report_id": AI_HERO_TASK_LIVE_ADOPTION_GATE_REPORT_ID,
		"gate_id": "strategic-ai-live-hero-task-adoption-10184",
		"schema_status": "live_hero_task_adoption_gate_report_only",
		"behavior_policy": "no_live_hero_task_behavior_adoption",
		"save_policy": "no_hero_task_state_write_no_save_migration",
		"event_log_policy": "no_durable_event_log",
		"source_reports": [task_signal, normalizer_signal, commander_signal],
		"gate_records": records,
		"report_only_ready_surfaces": report_ready_surfaces,
		"deferred_surfaces": deferred_surfaces,
		"public_gate_events": public_events,
		"public_leak_check": leak_check,
		"save_version_before": int(SessionStateStoreScript.SAVE_VERSION),
		"save_version_after": int(SessionStateStoreScript.SAVE_VERSION),
		"live_behavior_selected": live_selected,
		"schema_write_selected": save_write_selected,
		"requires_save_migration": migration_selected,
		"completion_policy": "explicit_live_adoption_gate_from_passed_report_boundaries_no_runtime_adoption",
	}

static func ai_hero_task_live_adoption_gate_public_leak_check(public_surfaces: Variant) -> Dictionary:
	var stack: Array = [public_surfaces]
	var checked_events := 0
	while not stack.is_empty():
		var value = stack.pop_back()
		if value is Array:
			for item in value:
				stack.append(item)
			continue
		if not (value is Dictionary):
			var value_text := String(value)
			for token in AI_HERO_TASK_LIVE_ADOPTION_BLOCKED_PUBLIC_TOKENS:
				if value_text.contains(String(token)):
					return {"ok": false, "error": "public live adoption gate surface leaked token %s" % String(token)}
			continue
		if String(value.get("event_type", "")) != "":
			checked_events += 1
			for key in value.keys():
				if String(key) not in AI_HERO_TASK_LIVE_ADOPTION_GATE_EVENT_KEYS:
					return {"ok": false, "error": "%s leaked non-compact key %s" % [value.get("event_type", "event"), key]}
		var text := JSON.stringify(value)
		for token in AI_HERO_TASK_LIVE_ADOPTION_BLOCKED_PUBLIC_TOKENS:
			if text.contains(String(token)):
				return {"ok": false, "error": "%s leaked blocked token %s" % [value.get("event_type", "event"), token]}
		for nested_key in value.keys():
			var nested = value[nested_key]
			if nested is Array or nested is Dictionary:
				stack.append(nested)
	return {
		"ok": true,
		"checked_events": checked_events,
		"allowed_public_event_keys": AI_HERO_TASK_LIVE_ADOPTION_GATE_EVENT_KEYS,
		"blocked_public_tokens": AI_HERO_TASK_LIVE_ADOPTION_BLOCKED_PUBLIC_TOKENS,
	}

static func _ai_hero_task_boundary_signal(report: Dictionary) -> Dictionary:
	var leak_check: Dictionary = report.get("public_leak_check", {}) if report.get("public_leak_check", {}) is Dictionary else {}
	var cases: Array = report.get("cases", []) if report.get("cases", []) is Array else []
	var id_check: Dictionary = report.get("candidate_task_id_check", {}) if report.get("candidate_task_id_check", {}) is Dictionary else {}
	var old_save_check: Dictionary = report.get("old_save_absence_check", {}) if report.get("old_save_absence_check", {}) is Dictionary else {}
	var ready := (
		bool(report.get("ok", false))
		and String(report.get("schema_status", "")) == "task_state_boundary_report_only"
		and String(report.get("behavior_policy", "")) == "derive_candidate_tasks_only"
		and String(report.get("save_policy", "")) == "no_hero_task_state_write"
		and cases.size() > 0
		and int(id_check.get("checked_tasks", 0)) > 0
		and bool(old_save_check.get("ok", false))
		and bool(leak_check.get("ok", false))
	)
	return {
		"report_id": String(report.get("report_id", AI_HERO_TASK_REPORT_ID)),
		"ok": ready,
		"schema_status": String(report.get("schema_status", "")),
		"behavior_policy": String(report.get("behavior_policy", "")),
		"save_policy": String(report.get("save_policy", "")),
		"case_count": cases.size(),
		"checked_candidate_tasks": int(id_check.get("checked_tasks", 0)),
		"old_save_absence_ok": bool(old_save_check.get("ok", false)),
		"public_leak_ok": bool(leak_check.get("ok", false)),
		"signal_policy": "candidate_tasks_report_only",
	}

static func _ai_hero_task_normalizer_signal(report: Dictionary) -> Dictionary:
	var save_version := int(SessionStateStoreScript.SAVE_VERSION)
	var ready := (
		bool(report.get("ok", false))
		and String(report.get("schema_status", "")) == "hero_task_state_normalizer_preservation_report_only"
		and String(report.get("behavior_policy", "")) == "observe_normalization_only"
		and String(report.get("save_policy", "")) == "no_hero_task_state_producer_no_disk_write"
		and String(report.get("save_service_policy", "")) == "payload_boundary_only_no_ai_task_semantics"
		and int(report.get("cases_reviewed", 0)) >= 9
		and int(report.get("save_version_before", save_version)) == save_version
		and int(report.get("save_version_after", save_version)) == save_version
	)
	return {
		"report_id": String(report.get("report_id", "AI_HERO_TASK_STATE_NORMALIZER_PRESERVATION_REPORT")),
		"ok": ready,
		"schema_status": String(report.get("schema_status", "")),
		"behavior_policy": String(report.get("behavior_policy", "")),
		"save_policy": String(report.get("save_policy", "")),
		"save_service_policy": String(report.get("save_service_policy", "")),
		"cases_reviewed": int(report.get("cases_reviewed", 0)),
		"save_version_unchanged": int(report.get("save_version_before", save_version)) == save_version and int(report.get("save_version_after", save_version)) == save_version,
		"signal_policy": "optional_state_preservation_report_only",
	}

static func _ai_hero_task_commander_adoption_signal(report: Dictionary) -> Dictionary:
	var leak_check: Dictionary = report.get("public_leak_check", {}) if report.get("public_leak_check", {}) is Dictionary else {}
	var ready := (
		bool(report.get("ok", false))
		and String(report.get("schema_status", "")) == "commander_role_adoption_boundary_report_only"
		and String(report.get("behavior_policy", "")) == "no_live_commander_role_behavior_adoption"
		and String(report.get("save_policy", "")) == "no_commander_role_state_write"
		and not bool(report.get("live_behavior_selected", true))
		and not bool(report.get("save_write_selected", true))
		and not bool(report.get("requires_save_migration", true))
		and bool(leak_check.get("ok", false))
	)
	return {
		"report_id": String(report.get("report_id", "AI_COMMANDER_ROLE_ADOPTION_BOUNDARY_REPORT")),
		"ok": ready,
		"schema_status": String(report.get("schema_status", "")),
		"behavior_policy": String(report.get("behavior_policy", "")),
		"save_policy": String(report.get("save_policy", "")),
		"public_leak_ok": bool(leak_check.get("ok", false)),
		"signal_policy": "commander_role_boundary_report_only",
	}

static func _ai_hero_task_live_adoption_gate_records(task_signal: Dictionary, normalizer_signal: Dictionary, commander_signal: Dictionary) -> Array:
	var report_ready := bool(task_signal.get("ok", false))
	var normalizer_ready := bool(normalizer_signal.get("ok", false))
	var commander_ready := bool(commander_signal.get("ok", false))
	return [
		_ai_hero_task_live_adoption_gate_record(
			"candidate_task_reports",
			"Candidate task reports",
			"ready_report_only" if report_ready else "blocked",
			"Derived candidate tasks remain diagnostic and do not drive target selection.",
			"report evidence only",
			["AI_HERO_TASK_STATE_BOUNDARY_REPORT"],
			"candidate_report_passed" if report_ready else "candidate_report_not_ready"
		),
		_ai_hero_task_live_adoption_gate_record(
			"optional_task_normalizer",
			"Optional task normalizer",
			"ready_report_only" if normalizer_ready else "blocked",
			"Explicit optional task boards can be sanitized when present, but no producer is approved.",
			"report evidence only",
			["AI_HERO_TASK_STATE_NORMALIZER_PRESERVATION_REPORT"],
			"normalizer_report_passed" if normalizer_ready else "normalizer_report_not_ready"
		),
		_ai_hero_task_live_adoption_gate_record(
			"commander_role_boundary",
			"Commander role boundary",
			"ready_report_only" if commander_ready else "blocked",
			"Commander role signals are ready as report evidence without live role adoption.",
			"report evidence only",
			["AI_COMMANDER_ROLE_ADOPTION_BOUNDARY_REPORT"],
			"commander_boundary_passed" if commander_ready else "commander_boundary_not_ready"
		),
		_ai_hero_task_live_adoption_gate_record(
			"task_schema_writer",
			"Task schema writer",
			"defer",
			"No minimal schema planning or writer gate has approved durable task records.",
			"needs later schema gate",
			["strategic-ai-hero-task-state-boundary-plan"],
			"schema_writer_not_selected",
			false,
			true,
			true
		),
		_ai_hero_task_live_adoption_gate_record(
			"save_migration",
			"Save migration",
			"defer",
			"Save migration and version changes require a separate approved migration slice.",
			"needs later compatibility gate",
			["strategic-ai-hero-task-state-adoption-sequencing-plan"],
			"save_migration_not_selected",
			false,
			true,
			true
		),
		_ai_hero_task_live_adoption_gate_record(
			"live_target_selection",
			"Live target selection",
			"defer",
			"Candidate tasks have not been approved as target-selection inputs.",
			"needs later behavior gate",
			["AI_HERO_TASK_STATE_BOUNDARY_REPORT"],
			"target_selection_not_selected",
			true,
			false,
			false
		),
		_ai_hero_task_live_adoption_gate_record(
			"route_actor_execution",
			"Route and actor execution",
			"defer",
			"Route ownership, actor ownership, and invalidation are not approved for live execution.",
			"needs later route gate",
			["strategic-ai-hero-task-state-boundary-plan"],
			"route_actor_execution_not_ready",
			true,
			false,
			false
		),
		_ai_hero_task_live_adoption_gate_record(
			"save_resume_live_tasks",
			"Save and resume live tasks",
			"defer",
			"No old-save fixture or resume proof exists for executable task state.",
			"needs later resume gate",
			["strategic-ai-hero-task-state-adoption-sequencing-plan"],
			"save_resume_not_proven",
			true,
			true,
			true
		),
		_ai_hero_task_live_adoption_gate_record(
			"manual_pacing_review",
			"Manual pacing review",
			"defer",
			"Live-client pacing and readability review is required before behavior adoption.",
			"needs later live-client gate",
			["strategic-ai-hero-task-state-adoption-sequencing-plan"],
			"manual_review_not_run",
			true,
			false,
			false
		),
		_ai_hero_task_live_adoption_gate_record(
			"durable_event_log",
			"Persistent event history",
			"defer",
			"Current public/report events are derived and do not require persistent history.",
			"needs later history gate",
			["strategic-ai-public-event-log-boundary-10184"],
			"durable_event_log_not_selected",
			false,
			false,
			false,
			true
		),
	]

static func _ai_hero_task_live_adoption_gate_record(
	surface_id: String,
	surface_label: String,
	gate_status: String,
	internal_reason: String,
	public_reason: String,
	source_report_ids: Array,
	reason_code: String,
	live_behavior_risk: bool = false,
	save_write_risk: bool = false,
	schema_risk: bool = false,
	durable_log_risk: bool = false
) -> Dictionary:
	return {
		"surface_id": surface_id,
		"surface_label": surface_label,
		"gate_status": gate_status,
		"adoption_scope": "report_helper_only" if gate_status == "ready_report_only" else "deferred",
		"reason_code": reason_code,
		"reason": internal_reason,
		"public_reason": public_reason,
		"source_report_ids": source_report_ids,
		"live_behavior_selected": false,
		"save_write_selected": false,
		"requires_save_migration": false,
		"risk_flags": {
			"live_behavior_risk": live_behavior_risk,
			"save_write_risk": save_write_risk,
			"schema_risk": schema_risk,
			"durable_log_risk": durable_log_risk,
		},
		"state_policy": AI_HERO_TASK_STATE_POLICY,
	}

static func _ai_hero_task_live_adoption_gate_event(
	record: Dictionary,
	day: int,
	faction_id: String,
	faction_label: String,
	sequence: int
) -> Dictionary:
	var surface_id := String(record.get("surface_id", ""))
	var target_id := _ai_hero_task_live_adoption_gate_public_target_id(surface_id)
	var label := _ai_hero_task_live_adoption_gate_public_label(surface_id, String(record.get("surface_label", surface_id)))
	var status := String(record.get("gate_status", "defer")).replace("_", " ")
	var public_reason := String(record.get("public_reason", "needs later gate"))
	return {
		"event_id": "%d:%s:ai_hero_task_live_gate:%s:%d" % [day, faction_id, target_id, sequence],
		"day": day,
		"sequence": sequence,
		"event_type": "ai_hero_task_live_gate",
		"faction_id": faction_id,
		"faction_label": faction_label,
		"actor_id": "strategic_ai",
		"actor_label": "Strategic AI",
		"target_kind": "gate",
		"target_id": target_id,
		"target_label": label,
		"visibility": "hidden_report",
		"public_importance": "low",
		"summary": "%s is %s (%s)." % [label, status, public_reason],
		"reason_codes": [_ai_hero_task_live_adoption_gate_public_reason_code(String(record.get("reason_code", "")))],
		"public_reason": public_reason,
		"state_policy": AI_HERO_TASK_STATE_POLICY,
	}

static func _ai_hero_task_live_adoption_gate_public_target_id(surface_id: String) -> String:
	match surface_id:
		"candidate_task_reports":
			return "candidate_reports"
		"optional_task_normalizer":
			return "optional_normalizer"
		"commander_role_boundary":
			return "commander_boundary"
		"task_schema_writer":
			return "task_schema_writer"
		"save_migration":
			return "compatibility_path"
		"live_target_selection":
			return "target_selection"
		"route_actor_execution":
			return "route_actor_execution"
		"save_resume_live_tasks":
			return "save_resume_live_tasks"
		"manual_pacing_review":
			return "manual_review"
		"durable_event_log":
			return "event_history"
	return surface_id

static func _ai_hero_task_live_adoption_gate_public_label(surface_id: String, fallback: String) -> String:
	match surface_id:
		"candidate_task_reports":
			return "Candidate reports"
		"optional_task_normalizer":
			return "Optional normalizer"
		"commander_role_boundary":
			return "Commander boundary"
		"task_schema_writer":
			return "Task schema writer"
		"save_migration":
			return "Compatibility path"
		"live_target_selection":
			return "Target selection"
		"route_actor_execution":
			return "Route and actor execution"
		"save_resume_live_tasks":
			return "Save and resume"
		"manual_pacing_review":
			return "Manual pacing review"
		"durable_event_log":
			return "Event history"
	return fallback

static func _ai_hero_task_live_adoption_gate_public_reason_code(reason_code: String) -> String:
	match reason_code:
		"schema_writer_not_selected":
			return "later_schema_gate"
		"save_migration_not_selected":
			return "later_compatibility_gate"
		"target_selection_not_selected":
			return "later_behavior_gate"
		"route_actor_execution_not_ready":
			return "later_route_gate"
		"save_resume_not_proven":
			return "later_resume_gate"
		"manual_review_not_run":
			return "later_live_client_gate"
		"durable_event_log_not_selected":
			return "later_history_gate"
	return reason_code

static func _ai_hero_task_live_resource_context(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	target_id: String
) -> Dictionary:
	var context := {}
	var node_result := _find_resource_by_placement(session, target_id)
	if int(node_result.get("index", -1)) < 0:
		return context
	var node: Dictionary = node_result.get("node", {})
	var controller_id := String(node.get("collected_by_faction_id", ""))
	if controller_id == "player":
		context["fixture_previous_controller"] = faction_id
		context["fixture_threatened_by_player_front"] = true
	elif controller_id != "" and controller_id != faction_id:
		context["fixture_denial_only"] = true
	return context

static func _ai_hero_task_live_target_reserved(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	target_kind: String,
	target_id: String,
	current_placement_id: String = "",
	current_actor_id: String = "",
	ignore_task_reservations: bool = false
) -> bool:
	if session == null or target_kind == "" or target_id == "":
		return false
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter_value in session.overworld.get("encounters", []):
		if not _is_active_raid(encounter_value, faction_id, resolved_encounters):
			continue
		var encounter: Dictionary = encounter_value
		if String(encounter.get("placement_id", "")) == current_placement_id:
			continue
		if String(encounter.get("target_kind", "")) != target_kind:
			continue
		if String(encounter.get("target_placement_id", "")) == target_id:
			var reason_codes := _normalize_string_array(encounter.get("target_reason_codes", []))
			if "active_front_support" in reason_codes or String(encounter.get("supporting_front_placement_id", "")) != "":
				continue
			return true
	if ignore_task_reservations:
		return false
	for task in _ai_hero_task_live_tasks_for_faction(session, faction_id):
		if not (task is Dictionary):
			continue
		var task_status := String(task.get("task_status", ""))
		if task_status not in ["planned", "reserved", "active"]:
			continue
		if current_actor_id != "" and String(task.get("actor_id", "")) == current_actor_id:
			continue
		if String(task.get("actor_active_placement_id", "")) == current_placement_id:
			continue
		if String(task.get("target_kind", "")) != target_kind:
			continue
		if String(task.get("target_id", "")) == target_id:
			var reservation: Dictionary = task.get("reservation", {}) if task.get("reservation", {}) is Dictionary else {}
			if String(reservation.get("reservation_scope", "")) == "exclusive_target":
				return true
	return false

static func ai_hero_task_saved_target_selection_plan(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary
) -> Dictionary:
	if session == null or raid.is_empty():
		return {}
	var faction_id := String(config.get("faction_id", raid.get("spawned_by_faction_id", "")))
	var actor_id := _ai_hero_task_actor_id_from_raid(raid)
	if faction_id == "" or actor_id == "":
		return {}
	var current_placement_id := String(raid.get("placement_id", ""))
	var origin_pos := Vector2i(int(raid.get("x", 0)), int(raid.get("y", 0)))
	var best := {}
	for task_value in _ai_hero_task_live_tasks_for_faction(session, faction_id):
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("actor_id", "")) != actor_id:
			continue
		if String(task.get("task_status", "")) not in ["planned", "reserved", "active"]:
			continue
		if int(task.get("expires_day", 0)) > 0 and int(task.get("expires_day", 0)) < int(session.day):
			continue
		var plan := _ai_hero_task_plan_from_saved_task(session, config, raid, task, origin_pos, current_placement_id)
		if plan.is_empty():
			continue
		if best.is_empty() or _saved_task_plan_beats(plan, best):
			best = plan
	return best

static func _ai_hero_task_plan_from_saved_task(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary,
	task: Dictionary,
	origin_pos: Vector2i,
	current_placement_id: String
) -> Dictionary:
	var faction_id := String(config.get("faction_id", raid.get("spawned_by_faction_id", "")))
	var target_kind := String(task.get("target_kind", ""))
	var target_id := String(task.get("target_id", ""))
	if target_kind == "" or target_id == "":
		return {}
	if _ai_hero_task_live_target_reserved(session, faction_id, target_kind, target_id, current_placement_id, String(task.get("actor_id", ""))):
		return {}
	var target := _ai_hero_task_target_snapshot_for_plan(session, target_kind, target_id)
	if target.is_empty():
		return {}
	var goal_tiles: Array = target.get("goal_tiles", []) if target.get("goal_tiles", []) is Array else []
	if goal_tiles.is_empty():
		return {}
	var goal_distance := _path_distance(session, origin_pos, goal_tiles, current_placement_id)
	if goal_distance >= 9999:
		return {}
	var goal_tile: Vector2i = _best_goal_tile(session, origin_pos, goal_tiles)
	var reason_codes := _normalize_string_array(task.get("priority_reason_codes", []))
	if "saved_hero_task" not in reason_codes:
		reason_codes.append("saved_hero_task")
	var task_class := String(task.get("task_class", ""))
	var priority: int = 35 + max(0, int(task.get("assigned_day", 0)))
	match task_class:
		"retake_site":
			priority += 85
		"raid_town":
			priority += 80
		"contest_site":
			priority += 55
		"defend_front":
			priority += 50
		"stabilize_front":
			priority += 35
		"rebuild_host":
			priority += 70
		"recover_commander":
			priority += 30
	return {
		"target_kind": target_kind,
		"target_placement_id": target_id,
		"target_label": String(target.get("target_label", target_id)),
		"target_x": int(target.get("target_x", 0)),
		"target_y": int(target.get("target_y", 0)),
		"goal_x": goal_tile.x,
		"goal_y": goal_tile.y,
		"goal_distance": goal_distance,
		"priority": priority,
		"target_reason_codes": reason_codes,
		"target_public_reason": _public_reason_from_codes(reason_codes),
		"target_public_importance": "high" if task_class in ["retake_site", "raid_town", "contest_site"] else "medium",
		"target_debug_reason": "saved strategic hero task %s" % task_class,
		"hero_task_id": String(task.get("task_id", "")),
		"hero_task_record": task,
	}

static func _ai_hero_task_target_snapshot_for_plan(
	session: SessionStateStoreScript.SessionData,
	target_kind: String,
	target_id: String
) -> Dictionary:
	match target_kind:
		"resource":
			var node_result := _find_resource_by_placement(session, target_id)
			if int(node_result.get("index", -1)) < 0:
				return {}
			var node: Dictionary = node_result.get("node", {})
			var tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
			var site := ContentService.get_resource_site(String(node.get("site_id", "")))
			return {
				"target_label": String(site.get("name", target_id)),
				"target_x": tile.x,
				"target_y": tile.y,
				"goal_tiles": [tile],
			}
		"town":
			var town_result := _find_town_by_placement(session, target_id)
			if int(town_result.get("index", -1)) < 0:
				return {}
			var town: Dictionary = town_result.get("town", {})
			return {
				"target_label": _town_name(town),
				"target_x": int(town.get("x", 0)),
				"target_y": int(town.get("y", 0)),
				"goal_tiles": _town_staging_tiles(session, town),
			}
		"artifact":
			var artifact_result := _find_artifact_by_placement(session, target_id)
			if int(artifact_result.get("index", -1)) < 0:
				return {}
			var node: Dictionary = artifact_result.get("node", {})
			if bool(node.get("collected", false)):
				return {}
			var tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
			return {
				"target_label": ArtifactRulesScript.describe_artifact(String(node.get("artifact_id", ""))),
				"target_x": tile.x,
				"target_y": tile.y,
				"goal_tiles": [tile],
			}
		"regroup":
			var town_result := _find_town_by_placement(session, target_id)
			if int(town_result.get("index", -1)) < 0:
				return {}
			var town: Dictionary = town_result.get("town", {})
			var tile := Vector2i(int(town.get("x", 0)), int(town.get("y", 0)))
			return {
				"target_label": "%s regroup" % _town_name(town),
				"target_x": tile.x,
				"target_y": tile.y,
				"goal_tiles": [tile],
			}
		"encounter":
			var encounter_result := _find_encounter_by_placement(session, target_id)
			if int(encounter_result.get("index", -1)) < 0:
				return {}
			var encounter: Dictionary = encounter_result.get("encounter", {})
			if OverworldRulesScript.is_encounter_resolved(session, encounter):
				return {}
			var encounter_template := ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
			return {
				"target_label": String(encounter_template.get("name", target_id)),
				"target_x": int(encounter.get("x", 0)),
				"target_y": int(encounter.get("y", 0)),
				"goal_tiles": _encounter_staging_tiles(session, encounter),
			}
		"hero":
			var hero := _player_hero_snapshot_for_task(session, target_id)
			if hero.is_empty():
				return {}
			var tile := _player_hero_goal_tile(hero)
			return {
				"target_label": String(hero.get("name", target_id)),
				"target_x": tile.x,
				"target_y": tile.y,
				"goal_tiles": [tile],
			}
	return {}

static func _saved_task_plan_beats(candidate: Dictionary, best: Dictionary) -> bool:
	if int(candidate.get("priority", 0)) == int(best.get("priority", 0)):
		if int(candidate.get("goal_distance", 9999)) == int(best.get("goal_distance", 9999)):
			return String(candidate.get("target_label", "")) < String(best.get("target_label", ""))
		return int(candidate.get("goal_distance", 9999)) < int(best.get("goal_distance", 9999))
	return int(candidate.get("priority", 0)) > int(best.get("priority", 0))

static func _ai_hero_task_live_target_task_valid(task: Dictionary) -> bool:
	if task.is_empty():
		return false
	if String(task.get("task_status", "")) not in ["candidate", "active"]:
		return false
	if String(task.get("last_validation", "")) != "valid":
		return false
	if String(task.get("target_kind", "")) != "resource":
		return false
	if String(task.get("target_id", "")) == "":
		return false
	return String(task.get("task_class", "")) in ["retake_site", "contest_site", "defend_front"]

static func _ai_hero_task_live_plan_from_task(
	session: SessionStateStoreScript.SessionData,
	raid: Dictionary,
	task: Dictionary,
	source_candidate: Dictionary,
	origin_pos: Vector2i
) -> Dictionary:
	var target_id := String(task.get("target_id", ""))
	var node_result := _find_resource_by_placement(session, target_id)
	if int(node_result.get("index", -1)) < 0:
		return {}
	var node: Dictionary = node_result.get("node", {})
	var goal_tile := Vector2i(int(node.get("x", task.get("target_x", 0))), int(node.get("y", task.get("target_y", 0))))
	var goal_distance := _path_distance(session, origin_pos, [goal_tile], String(raid.get("placement_id", "")))
	if goal_distance >= 9999:
		return {}
	var reason_codes := _normalize_string_array(task.get("priority_reason_codes", []))
	if "commander_memory" not in reason_codes:
		reason_codes.append("commander_memory")
	var task_class := String(task.get("task_class", ""))
	var class_bonus := 0
	match task_class:
		"retake_site":
			class_bonus = 75
		"contest_site":
			class_bonus = 45
		"defend_front":
			class_bonus = 30
	var public_reason := String(task.get("public_reason", ""))
	if public_reason == "":
		public_reason = _public_reason_from_codes(reason_codes)
	return {
		"target_kind": "resource",
		"target_placement_id": target_id,
		"target_label": String(task.get("target_label", target_id)),
		"target_x": goal_tile.x,
		"target_y": goal_tile.y,
		"goal_x": goal_tile.x,
		"goal_y": goal_tile.y,
		"goal_distance": goal_distance,
		"priority": max(0, int(source_candidate.get("priority", 0)) + class_bonus),
		"target_reason_codes": reason_codes,
		"target_public_reason": public_reason,
		"target_public_importance": "high" if task_class in ["retake_site", "contest_site"] else "medium",
		"target_debug_reason": "live commander target selection adopted %s" % task_class,
		"hero_task_id": String(task.get("task_id", "")),
		"hero_task_record": task,
	}

static func _ai_hero_task_record_live_assignment(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary,
	current_target: Dictionary,
	task_record: Dictionary = {}
) -> void:
	if session == null or current_target.is_empty():
		return
	var faction_id := String(config.get("faction_id", raid.get("spawned_by_faction_id", "")))
	var actor_id := _ai_hero_task_actor_id_from_raid(raid)
	if faction_id == "" or actor_id == "":
		return
	var target_kind := String(current_target.get("target_kind", ""))
	var target_id := String(current_target.get("target_placement_id", ""))
	if target_kind not in ["resource", "town", "artifact", "encounter", "hero", "regroup"] or target_id == "":
		return
	var task: Dictionary = task_record.duplicate(true) if not task_record.is_empty() else {}
	if task.is_empty() or String(task.get("actor_id", "")) != actor_id or String(task.get("target_id", "")) != target_id:
		task = _ai_hero_task_record_from_assignment(session, config, raid, current_target, actor_id)
	var runtime_task := _ai_hero_task_runtime_task_payload(session, config, raid, current_target, task, actor_id)
	if runtime_task.is_empty():
		return
	_ai_hero_task_upsert_live_task(session, faction_id, runtime_task)

static func _ai_hero_task_runtime_task_payload(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary,
	current_target: Dictionary,
	task: Dictionary,
	actor_id: String
) -> Dictionary:
	var faction_id := String(config.get("faction_id", raid.get("spawned_by_faction_id", "")))
	var target_kind := String(current_target.get("target_kind", task.get("target_kind", "")))
	var target_id := String(current_target.get("target_placement_id", task.get("target_id", "")))
	if faction_id == "" or actor_id == "" or target_kind == "" or target_id == "":
		return {}
	var assigned_day := int(task.get("assigned_day", 0))
	if assigned_day <= 0:
		assigned_day = int(session.day)
	var task_class := String(task.get("task_class", "contest_site"))
	var reason_codes := _normalize_string_array(task.get("priority_reason_codes", current_target.get("target_reason_codes", [])))
	if reason_codes.is_empty():
		reason_codes = ["strategic_pressure"]
	var task_id := String(task.get("task_id", ""))
	if task_id == "":
		task_id = ai_hero_task_candidate_id(
			String(session.scenario_id),
			faction_id,
			actor_id,
			task_class,
			target_kind,
			target_id,
			assigned_day,
			max(1, int(raid.get("days_active", 0)) + 1)
		)
	var payload := {
		"task_id": task_id,
		"owner_faction_id": faction_id,
		"actor_kind": "commander_roster",
		"actor_id": actor_id,
		"source_kind": String(task.get("source_kind", "commander_role_adapter")),
		"source_id": String(task.get("source_id", raid.get("placement_id", ""))),
		"task_class": task_class,
		"task_status": "active",
		"target_kind": target_kind,
		"target_id": target_id,
		"front_id": String(task.get("front_id", commander_role_front_id(String(session.scenario_id), target_kind, target_id))),
		"origin_kind": String(task.get("origin_kind", "encounter")),
		"origin_id": String(task.get("origin_id", raid.get("placement_id", ""))),
		"priority_reason_codes": reason_codes,
		"assigned_day": assigned_day,
		"expires_day": max(assigned_day + 7, int(task.get("expires_day", 0))),
		"continuity_policy": String(task.get("continuity_policy", "persist_until_invalid")),
		"route_policy": String(task.get("route_policy", "derive_route_on_turn")),
		"last_validation": "valid",
		"reservation": _ai_hero_task_default_reservation(task_class, target_kind, target_id),
	}
	if task.get("reservation", {}) is Dictionary:
		var reservation: Dictionary = task.get("reservation", {})
		if not reservation.is_empty():
			payload["reservation"] = reservation.duplicate(true)
	return payload

static func _ai_hero_task_record_from_assignment(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary,
	current_target: Dictionary,
	actor_id: String
) -> Dictionary:
	var faction_id := String(config.get("faction_id", raid.get("spawned_by_faction_id", "")))
	var target_kind := String(current_target.get("target_kind", ""))
	var target_id := String(current_target.get("target_placement_id", ""))
	var reason_codes := _normalize_string_array(raid.get("target_reason_codes", current_target.get("target_reason_codes", [])))
	if reason_codes.is_empty():
		reason_codes = ["strategic_pressure"]
	var task_class := "contest_site"
	if target_kind == "regroup":
		task_class = "rebuild_host"
	elif "active_front_support" in reason_codes:
		task_class = "stabilize_front"
	elif "town_defense" in reason_codes or "site_defense" in reason_codes or "defend_front" in reason_codes:
		task_class = "defend_front"
	elif "retake_front" in reason_codes:
		task_class = "retake_site"
	elif target_kind == "town":
		task_class = "raid_town"
	var assigned_day := int(session.day)
	var task_id := ai_hero_task_candidate_id(
		String(session.scenario_id),
		faction_id,
		actor_id,
		task_class,
		target_kind,
		target_id,
		assigned_day,
		max(1, int(raid.get("days_active", 0)) + 1)
	)
	return {
		"task_id": task_id,
		"owner_faction_id": faction_id,
		"actor_kind": "commander_roster",
		"actor_id": actor_id,
		"source_kind": "saved_task_state",
		"source_id": String(raid.get("placement_id", "")),
		"task_class": task_class,
		"task_status": "active",
		"target_kind": target_kind,
		"target_id": target_id,
		"front_id": commander_role_front_id(String(session.scenario_id), target_kind, target_id),
		"origin_kind": "encounter",
		"origin_id": String(raid.get("placement_id", "")),
		"priority_reason_codes": reason_codes,
		"assigned_day": assigned_day,
		"expires_day": assigned_day + 7,
		"continuity_policy": "persist_until_invalid",
		"route_policy": "derive_route_on_turn",
		"last_validation": "valid",
		"reservation": _ai_hero_task_default_reservation(task_class, target_kind, target_id),
	}

static func _ai_hero_task_actor_id_from_raid(raid: Dictionary) -> String:
	var commander_state = raid.get("enemy_commander_state", {})
	if commander_state is Dictionary:
		var roster_hero_id := String(commander_state.get("roster_hero_id", ""))
		if roster_hero_id != "":
			return roster_hero_id
	return String(raid.get("commander_hero_id", raid.get("placement_id", "")))

static func _ai_hero_task_live_tasks_for_faction(session: SessionStateStoreScript.SessionData, faction_id: String) -> Array:
	_ai_hero_task_reconcile_live_tasks_for_faction(session, faction_id)
	var state := _ai_hero_task_enemy_state_for_faction(session, faction_id)
	var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
	var tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
	return tasks

static func _ai_hero_task_reconcile_live_tasks_for_faction(
	session: SessionStateStoreScript.SessionData,
	faction_id: String
) -> void:
	if session == null or faction_id == "":
		return
	var states: Array = session.overworld.get("enemy_states", []) if session.overworld.get("enemy_states", []) is Array else []
	for state_index in range(states.size()):
		var state = states[state_index]
		if not (state is Dictionary) or String(state.get("faction_id", "")) != faction_id:
			continue
		var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
		var tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
		if tasks.is_empty():
			return
		var changed := false
		var next_tasks := []
		for task_value in tasks:
			if not (task_value is Dictionary):
				continue
			var task: Dictionary = task_value
			var reconciled := _ai_hero_task_reconciled_live_task(session, faction_id, task)
			if not _ai_hero_task_records_equal(task, reconciled):
				changed = true
			next_tasks.append(reconciled)
		if not changed:
			return
		state["hero_task_state"] = {
			"schema_version": 1,
			"planner_epoch": max(0, int(task_state.get("planner_epoch", 0))) + 1,
			"tasks": _ai_hero_task_prune_live_tasks(next_tasks, int(session.day)),
		}
		states[state_index] = state
		session.overworld["enemy_states"] = states
		return

static func _ai_hero_task_reconciled_live_task(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	task: Dictionary
) -> Dictionary:
	var status := String(task.get("task_status", ""))
	if status not in ["planned", "reserved", "active", "suspended"]:
		return task
	var actor_status_task := _ai_hero_task_reconcile_actor(session, faction_id, task)
	if not _ai_hero_task_records_equal(actor_status_task, task):
		return actor_status_task
	if status == "suspended":
		if not _ai_hero_task_actor_can_resume(session, faction_id, task):
			return task
		task = _ai_hero_task_with_lifecycle(task, "planned", "valid")
	var expires_day := int(task.get("expires_day", 0))
	if expires_day > 0 and expires_day < int(session.day):
		return _ai_hero_task_with_lifecycle(task, "cancelled", "invalid_task_expired")
	var target_kind := String(task.get("target_kind", ""))
	var target_id := String(task.get("target_id", ""))
	match target_kind:
		"resource":
			return _ai_hero_task_reconciled_resource_task(session, faction_id, task, target_id)
		"town":
			return _ai_hero_task_reconciled_town_task(session, faction_id, task, target_id)
		"artifact":
			return _ai_hero_task_reconciled_artifact_task(session, faction_id, task, target_id)
		"encounter":
			return _ai_hero_task_reconciled_encounter_task(session, faction_id, task, target_id)
		"hero":
			return _ai_hero_task_reconciled_hero_task(session, faction_id, task, target_id)
		"regroup":
			return _ai_hero_task_reconciled_regroup_task(session, faction_id, task, target_id)
	return task

static func _ai_hero_task_reconcile_actor(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	task: Dictionary
) -> Dictionary:
	if String(task.get("actor_kind", "commander_roster")) != "commander_roster":
		return task
	var actor_id := String(task.get("actor_id", ""))
	if actor_id == "":
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_actor_missing")
	var roster := commander_roster_for_faction(session, faction_id)
	var entry := _commander_roster_entry(roster, actor_id)
	if entry.is_empty():
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_actor_missing")
	var status := _normalize_commander_status(entry.get("status", COMMANDER_STATUS_AVAILABLE))
	if status == COMMANDER_STATUS_RECOVERING:
		return _ai_hero_task_with_lifecycle(task, "suspended", "invalid_actor_recovering")
	if not commander_can_deploy(entry):
		return _ai_hero_task_with_lifecycle(task, "suspended", "invalid_actor_rebuilding")
	return task

static func _ai_hero_task_actor_can_resume(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	task: Dictionary
) -> bool:
	if String(task.get("actor_kind", "commander_roster")) != "commander_roster":
		return false
	var actor_id := String(task.get("actor_id", ""))
	if actor_id == "":
		return false
	var roster := commander_roster_for_faction(session, faction_id)
	var entry := _commander_roster_entry(roster, actor_id)
	if entry.is_empty():
		return false
	if _normalize_commander_status(entry.get("status", COMMANDER_STATUS_AVAILABLE)) != COMMANDER_STATUS_AVAILABLE:
		return false
	return commander_can_deploy(entry)

static func _ai_hero_task_reconciled_resource_task(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	task: Dictionary,
	target_id: String
) -> Dictionary:
	if target_id == "":
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_target_missing")
	var node_result := _find_resource_by_placement(session, target_id)
	if int(node_result.get("index", -1)) < 0:
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_target_missing")
	var node: Dictionary = node_result.get("node", {})
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	var controller_id := String(node.get("collected_by_faction_id", ""))
	var task_class := String(task.get("task_class", ""))
	if task_class == "defend_front":
		if _resource_node_defensible_by_faction(node, site, faction_id, _normalize_string_array(task.get("priority_reason_codes", []))):
			return task
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_controller_changed")
	if controller_id == faction_id:
		return _ai_hero_task_with_lifecycle(task, "completed", "valid")
	if not _resource_site_is_persistent(site) and bool(node.get("collected", false)):
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_target_resolved")
	return task

static func _ai_hero_task_reconciled_town_task(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	task: Dictionary,
	target_id: String
) -> Dictionary:
	if target_id == "":
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_target_missing")
	var town_result := _find_town_by_placement(session, target_id)
	if int(town_result.get("index", -1)) < 0:
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_target_missing")
	var town: Dictionary = town_result.get("town", {})
	var owner := String(town.get("owner", "neutral"))
	var town_faction := _town_faction_id(town)
	var task_class := String(task.get("task_class", ""))
	var reason_codes := _normalize_string_array(task.get("priority_reason_codes", []))
	var same_faction_town := owner == "enemy" and town_faction == faction_id
	if task_class == "defend_front" or (task_class == "stabilize_front" and "active_front_support" not in reason_codes):
		if same_faction_town:
			return task
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_controller_changed")
	if task_class == "stabilize_front" and "active_front_support" in reason_codes:
		if same_faction_town:
			return _ai_hero_task_with_lifecycle(task, "completed", "valid")
		if owner in ["player", "enemy"]:
			return task
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_controller_changed")
	if same_faction_town:
		return _ai_hero_task_with_lifecycle(task, "completed", "valid")
	if owner not in ["player", "enemy"]:
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_controller_changed")
	return task

static func _ai_hero_task_reconciled_artifact_task(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	task: Dictionary,
	target_id: String
) -> Dictionary:
	if target_id == "":
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_target_missing")
	var artifact_result := _find_artifact_by_placement(session, target_id)
	if int(artifact_result.get("index", -1)) < 0:
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_target_missing")
	var node: Dictionary = artifact_result.get("node", {})
	if bool(node.get("collected", false)):
		if String(node.get("collected_by_faction_id", "")) == faction_id:
			return _ai_hero_task_with_lifecycle(task, "completed", "valid")
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_target_resolved")
	return task

static func _ai_hero_task_reconciled_encounter_task(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	task: Dictionary,
	target_id: String
) -> Dictionary:
	if target_id == "":
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_target_missing")
	var encounter_result := _find_encounter_by_placement(session, target_id)
	if int(encounter_result.get("index", -1)) < 0:
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_target_missing")
	var encounter: Dictionary = encounter_result.get("encounter", {})
	if OverworldRulesScript.is_encounter_resolved(session, encounter):
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_target_resolved")
	if String(encounter.get("contested_by_faction_id", "")) == faction_id:
		return _ai_hero_task_with_lifecycle(task, "completed", "valid")
	return task

static func _ai_hero_task_reconciled_hero_task(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	task: Dictionary,
	target_id: String
) -> Dictionary:
	if target_id == "":
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_target_missing")
	var hero := _player_hero_snapshot_for_task(session, target_id)
	if hero.is_empty():
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_target_missing")
	return task

static func _ai_hero_task_reconciled_regroup_task(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	task: Dictionary,
	target_id: String
) -> Dictionary:
	if target_id == "":
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_target_missing")
	var town_result := _find_town_by_placement(session, target_id)
	if int(town_result.get("index", -1)) < 0:
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_target_missing")
	var town: Dictionary = town_result.get("town", {})
	if String(town.get("owner", "neutral")) != "enemy" or _town_faction_id(town) != faction_id:
		return _ai_hero_task_with_lifecycle(task, "invalid", "invalid_controller_changed")
	return task

static func _ai_hero_task_with_lifecycle(task: Dictionary, status: String, validation: String) -> Dictionary:
	var next_task := task.duplicate(true)
	next_task["task_status"] = status
	next_task["last_validation"] = validation
	return next_task

static func _ai_hero_task_records_equal(left: Dictionary, right: Dictionary) -> bool:
	return JSON.stringify(left) == JSON.stringify(right)

static func _ai_hero_task_upsert_live_task(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	task: Dictionary
) -> void:
	var states: Array = session.overworld.get("enemy_states", []) if session.overworld.get("enemy_states", []) is Array else []
	for state_index in range(states.size()):
		var state = states[state_index]
		if not (state is Dictionary) or String(state.get("faction_id", "")) != faction_id:
			continue
		var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
		var tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
		var next_tasks := []
		for existing_value in tasks:
			if not (existing_value is Dictionary):
				continue
			var existing: Dictionary = existing_value
			if String(existing.get("task_status", "")) in ["completed", "failed", "cancelled", "invalid"]:
				next_tasks.append(existing)
				continue
			if String(existing.get("actor_id", "")) == String(task.get("actor_id", "")):
				if not _ai_hero_task_same_live_assignment(existing, task):
					var cancelled := existing.duplicate(true)
					cancelled["task_status"] = "cancelled"
					cancelled["last_validation"] = "cancelled_by_retask"
					cancelled["invalidated_by_task_id"] = String(task.get("task_id", ""))
					next_tasks.append(cancelled)
				continue
			var reservation: Dictionary = existing.get("reservation", {}) if existing.get("reservation", {}) is Dictionary else {}
			var task_reservation: Dictionary = task.get("reservation", {}) if task.get("reservation", {}) is Dictionary else {}
			if String(reservation.get("reservation_scope", "")) == "exclusive_target" \
					and String(reservation.get("reservation_key", "")) != "" \
					and String(reservation.get("reservation_key", "")) == String(task_reservation.get("reservation_key", "")):
				existing["task_status"] = "invalid"
				existing["last_validation"] = "invalid_target_reserved"
				existing["invalidated_by_task_id"] = String(task.get("task_id", ""))
			next_tasks.append(existing)
		next_tasks.append(task)
		state["hero_task_state"] = {
			"schema_version": 1,
			"planner_epoch": max(0, int(task_state.get("planner_epoch", 0))) + 1,
			"tasks": _ai_hero_task_prune_live_tasks(next_tasks, int(session.day)),
		}
		states[state_index] = state
		session.overworld["enemy_states"] = states
		return

static func _ai_hero_task_same_live_assignment(existing: Dictionary, task: Dictionary) -> bool:
	if String(existing.get("task_id", "")) != "" and String(existing.get("task_id", "")) == String(task.get("task_id", "")):
		return true
	return (
		String(existing.get("actor_id", "")) == String(task.get("actor_id", ""))
		and String(existing.get("target_kind", "")) == String(task.get("target_kind", ""))
		and String(existing.get("target_id", "")) == String(task.get("target_id", ""))
		and String(existing.get("task_class", "")) == String(task.get("task_class", ""))
	)

static func _ai_hero_task_finish_live_assignment(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	raid: Dictionary,
	task_status: String,
	validation: String
) -> void:
	if session == null or faction_id == "" or raid.is_empty():
		return
	var actor_id := _ai_hero_task_actor_id_from_raid(raid)
	var target_kind := String(raid.get("target_kind", ""))
	var target_id := String(raid.get("target_placement_id", ""))
	if actor_id == "" or target_kind == "" or target_id == "":
		return
	var states: Array = session.overworld.get("enemy_states", []) if session.overworld.get("enemy_states", []) is Array else []
	for state_index in range(states.size()):
		var state = states[state_index]
		if not (state is Dictionary) or String(state.get("faction_id", "")) != faction_id:
			continue
		var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
		var tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
		var changed := false
		var next_tasks := []
		for task_value in tasks:
			if not (task_value is Dictionary):
				continue
			var task: Dictionary = task_value
			if String(task.get("actor_id", "")) == actor_id \
					and String(task.get("target_kind", "")) == target_kind \
					and String(task.get("target_id", "")) == target_id \
					and String(task.get("task_status", "")) in ["planned", "reserved", "active"]:
				task = task.duplicate(true)
				task["task_status"] = task_status
				task["last_validation"] = validation
				changed = true
			next_tasks.append(task)
		if not changed:
			return
		state["hero_task_state"] = {
			"schema_version": 1,
			"planner_epoch": max(0, int(task_state.get("planner_epoch", 0))) + 1,
			"tasks": _ai_hero_task_prune_live_tasks(next_tasks, int(session.day)),
		}
		states[state_index] = state
		session.overworld["enemy_states"] = states
		return

static func _ai_hero_task_prune_live_tasks(tasks: Array, day: int) -> Array:
	var kept := []
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		var expires_day := int(task.get("expires_day", 0))
		if expires_day > 0 and expires_day + 3 < day:
			continue
		kept.append(task)
	kept.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("assigned_day", 0)) == int(b.get("assigned_day", 0)):
			return String(a.get("task_id", "")) < String(b.get("task_id", ""))
		return int(a.get("assigned_day", 0)) > int(b.get("assigned_day", 0))
	)
	while kept.size() > 12:
		kept.pop_back()
	return kept

static func _ai_hero_task_enemy_state_for_faction(session: SessionStateStoreScript.SessionData, faction_id: String) -> Dictionary:
	if session == null:
		return {}
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
			return state
	return {}

static func _ai_hero_task_class_for_role(role: String, target_kind: String, role_status: String = "") -> String:
	if role == COMMANDER_ROLE_RAIDER and target_kind == "town":
		return "raid_town"
	if role == COMMANDER_ROLE_RAIDER:
		return "contest_site"
	if role == COMMANDER_ROLE_RETAKER:
		return "retake_site"
	if role == COMMANDER_ROLE_DEFENDER:
		return "defend_front"
	if role == COMMANDER_ROLE_STABILIZER:
		return "stabilize_front"
	if role == COMMANDER_ROLE_RECOVERING and role_status == "cooldown":
		return "recover_commander"
	if role == COMMANDER_ROLE_RECOVERING and role_status == "rebuilding":
		return "rebuild_host"
	return "reserve"

static func _ai_hero_task_role_status_from_task_class(task_class: String) -> String:
	if task_class == "recover_commander":
		return "cooldown"
	if task_class == "rebuild_host":
		return "rebuilding"
	return "assigned"

static func _ai_hero_task_source_id(
	scenario_id: String,
	faction_id: String,
	actor_id: String,
	role: String,
	target_kind: String,
	target_id: String,
	assigned_day: int
) -> String:
	if scenario_id == "" or faction_id == "" or actor_id == "" or role == "" or target_kind == "" or target_id == "":
		return ""
	return "role:%s:%s:%s:%s:%s:%s:day_%d" % [
		scenario_id,
		faction_id,
		actor_id,
		role,
		target_kind,
		target_id,
		assigned_day,
	]

static func _ai_hero_task_default_reservation(task_class: String, target_kind: String, target_id: String) -> Dictionary:
	if task_class in AI_HERO_TASK_EXCLUSIVE_CLASSES:
		return {
			"reservation_status": "primary",
			"reservation_scope": "exclusive_target",
			"reservation_key": "%s:%s" % [target_kind, target_id],
		}
	if task_class == "stabilize_front":
		return {
			"reservation_status": "shared",
			"reservation_scope": "shared_front",
			"reservation_key": "",
		}
	return {
		"reservation_status": "none",
		"reservation_scope": "none",
		"reservation_key": "",
	}

static func _ai_hero_task_target_owner_expected(task_class: String, controller_id: String, faction_id: String) -> String:
	if task_class in ["retake_site", "contest_site"] and controller_id == "player":
		return "player-held contested resource"
	if task_class in ["defend_front", "stabilize_front"] and controller_id == faction_id:
		return "owner-held front"
	if task_class in ["recover_commander", "rebuild_host"]:
		return "own commander"
	return "contested target"

static func _ai_hero_task_reservation_sort_key(task: Dictionary) -> String:
	var active_rank := "0" if bool(task.get("actor_active_linked", false)) else "1"
	var class_rank_map := {
		"retake_site": 0,
		"defend_front": 1,
		"contest_site": 2,
		"stabilize_front": 3,
		"raid_town": 4,
		"reserve": 5,
		"recover_commander": 6,
		"rebuild_host": 7,
	}
	var class_rank := int(class_rank_map.get(String(task.get("task_class", "")), 99))
	return "%s:%02d:%s:%s" % [
		active_rank,
		class_rank,
		String(task.get("actor_id", "")),
		String(task.get("task_id", "")),
	]

static func _ai_hero_task_public_importance(task: Dictionary) -> String:
	var task_class := String(task.get("task_class", ""))
	if task_class in ["retake_site", "defend_front", "raid_town"]:
		return "high"
	if task_class in ["contest_site", "stabilize_front"]:
		return "medium"
	return "low"

static func _turn_transcript_role_proposal(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	commander_entry: Dictionary,
	target_view: Dictionary,
	proposal: Dictionary
) -> Dictionary:
	var target_kind := String(target_view.get("target_kind", ""))
	var target_id := String(target_view.get("target_id", ""))
	return {
		"timing": "",
		"roster_hero_id": String(commander_entry.get("roster_hero_id", "")),
		"commander_label": commander_display_name(commander_entry, false),
		"role": String(proposal.get("role", COMMANDER_ROLE_RESERVE)),
		"role_status": String(proposal.get("role_status", "")),
		"validity": String(proposal.get("validity", "")),
		"target_kind": target_kind,
		"target_id": target_id,
		"target_label": String(target_view.get("target_label", target_id)),
		"target_x": int(target_view.get("target_x", 0)),
		"target_y": int(target_view.get("target_y", 0)),
		"front_id": String(target_view.get("front_id", commander_role_front_id(String(session.scenario_id), target_kind, target_id))),
		"priority_reason_codes": _normalize_string_array(proposal.get("priority_reason_codes", [])),
		"public_reason": String(proposal.get("public_reason", "")),
		"assignment_id_hint": String(proposal.get("assignment_id_hint", "")),
		"expected_next_transition": String(proposal.get("expected_next_transition", "")),
		"state_policy": "report_only",
	}

static func _turn_transcript_enemy_state_counts(session: SessionStateStoreScript.SessionData, faction_id: String) -> Dictionary:
	var state := {}
	for state_value in session.overworld.get("enemy_states", []):
		if state_value is Dictionary and String(state_value.get("faction_id", "")) == faction_id:
			state = state_value
			break
	var roster: Array = state.get("commander_roster", [])
	var commander_counts := {"available": 0, "active": 0, "recovering": 0, "rebuilding": 0}
	for entry_value in roster:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var status := _normalize_commander_status(entry.get("status", COMMANDER_STATUS_AVAILABLE))
		if commander_can_deploy(entry):
			commander_counts[status] = int(commander_counts.get(status, 0)) + 1
		else:
			commander_counts["rebuilding"] = int(commander_counts.get("rebuilding", 0)) + 1
	return {
		"pressure": int(state.get("pressure", 0)),
		"raid_counter": int(state.get("raid_counter", 0)),
		"commander_counter": int(state.get("commander_counter", 0)),
		"siege_progress": int(state.get("siege_progress", 0)),
		"posture": String(state.get("posture", "")),
		"active_raid_count": _turn_transcript_active_raid_snapshots(session, faction_id).size(),
		"commander_counts": commander_counts,
		"state_policy": "derived",
	}

static func _turn_transcript_active_raid_snapshots(
	session: SessionStateStoreScript.SessionData,
	faction_id: String
) -> Array:
	var snapshots := []
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter_value in session.overworld.get("encounters", []):
		if not _is_active_raid(encounter_value, faction_id, resolved_encounters):
			continue
		var encounter: Dictionary = encounter_value
		var commander_state = encounter.get("enemy_commander_state", {})
		if not (commander_state is Dictionary):
			commander_state = {}
		var current := Vector2i(int(encounter.get("x", 0)), int(encounter.get("y", 0)))
		var goal_tiles := _goal_tiles_from_raid(session, encounter)
		var goal_distance := int(encounter.get("goal_distance", 9999))
		if not goal_tiles.is_empty():
			goal_distance = _path_distance(session, current, goal_tiles, String(encounter.get("placement_id", "")))
			if goal_distance == 9999 and current in goal_tiles:
				goal_distance = 0
		var target := _current_target_snapshot(encounter)
		snapshots.append(
			{
				"placement_id": String(encounter.get("placement_id", "")),
				"encounter_id": String(encounter.get("encounter_id", encounter.get("id", ""))),
				"raid_label": raid_display_name(encounter),
				"roster_hero_id": String(commander_state.get("roster_hero_id", "")),
				"commander_label": commander_display_name(commander_state, false),
				"x": current.x,
				"y": current.y,
				"arrived": bool(encounter.get("arrived", false)),
				"goal_distance": goal_distance,
				"target_kind": String(target.get("target_kind", "")),
				"target_id": String(target.get("target_placement_id", "")),
				"target_label": String(target.get("target_label", "")),
				"target_x": int(target.get("target_x", 0)),
				"target_y": int(target.get("target_y", 0)),
				"target_signature": _target_signature(target),
				"reason_codes": _normalize_string_array(encounter.get("target_reason_codes", [])),
				"public_reason": String(encounter.get("target_public_reason", "")),
				"public_importance": String(encounter.get("target_public_importance", "medium")),
				"state_policy": "derived",
			}
		)
	return snapshots

static func _turn_transcript_commander_links(
	session: SessionStateStoreScript.SessionData,
	faction_id: String
) -> Array:
	var links := []
	var roster := commander_roster_for_faction(session, faction_id)
	for commander_entry_value in roster:
		if not (commander_entry_value is Dictionary):
			continue
		var commander_entry: Dictionary = commander_entry_value
		var roster_hero_id := String(commander_entry.get("roster_hero_id", ""))
		var active_link := commander_role_active_encounter_link(session, faction_id, roster_hero_id)
		var linked := bool(active_link.get("linked", false))
		var status := _normalize_commander_status(commander_entry.get("status", COMMANDER_STATUS_AVAILABLE))
		var no_link_reason := ""
		if not linked:
			if status == COMMANDER_STATUS_RECOVERING:
				no_link_reason = "recovering"
			elif not commander_can_deploy(commander_entry):
				no_link_reason = "rebuilding"
			else:
				no_link_reason = "reserve"
		links.append(
			{
				"roster_hero_id": roster_hero_id,
				"commander_label": commander_display_name(commander_entry, false),
				"status": status,
				"active_placement_id": String(active_link.get("placement_id", "")),
				"linked": linked,
				"no_link_reason": no_link_reason,
				"target_kind": String(active_link.get("target_kind", "")),
				"target_id": String(active_link.get("target_id", "")),
				"target_label": String(active_link.get("target_label", "")),
				"army_status": commander_army_status(commander_entry),
				"memory_summary": commander_memory_summary(commander_entry),
				"state_policy": "derived",
			}
		)
	return links

static func _turn_transcript_resource_controller_map(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var controllers := {}
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var placement_id := String(node.get("placement_id", ""))
		if placement_id == "":
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		controllers[placement_id] = {
			"controller_id": String(node.get("collected_by_faction_id", "")),
			"target_label": String(site.get("name", placement_id)),
			"x": int(node.get("x", 0)),
			"y": int(node.get("y", 0)),
			"state_policy": "derived",
		}
	return controllers

static func _turn_transcript_town_governor_refs(reports_value: Variant, fallback_front_id: String = "") -> Array:
	var reports: Array = reports_value if reports_value is Array else [reports_value]
	var refs := []
	var allowed_types := [
		"ai_town_built",
		"ai_town_recruited",
		"ai_garrison_reinforced",
		"ai_raid_reinforced",
		"ai_commander_rebuilt",
	]
	for report_value in reports:
		if not (report_value is Dictionary):
			continue
		for town_value in report_value.get("towns", []):
			if not (town_value is Dictionary):
				continue
			var town: Dictionary = town_value
			for event_value in town.get("events", []):
				if not (event_value is Dictionary):
					continue
				var event: Dictionary = event_value
				var event_type := String(event.get("event_type", ""))
				if event_type not in allowed_types:
					continue
				var target_kind := String(event.get("target_kind", ""))
				var target_id := String(event.get("target_id", ""))
				var front_id := commander_role_front_id(String(report_value.get("scenario_id", "")), target_kind, target_id)
				if front_id == "":
					front_id = fallback_front_id
				refs.append(
					{
						"event_ref_id": String(event.get("event_id", "")),
						"event_type": event_type,
						"town_placement_id": String(town.get("placement_id", event.get("actor_id", ""))),
						"target_kind": target_kind,
						"target_id": target_id,
						"target_label": String(event.get("target_label", target_id)),
						"public_reason": String(event.get("public_reason", "")),
						"reason_codes": _normalize_string_array(event.get("reason_codes", [])),
						"supports_front_id": front_id,
						"state_policy": "derived",
					}
				)
	return refs

static func _turn_transcript_timed_proposals(proposals_value: Variant, timing: String) -> Array:
	var timed := []
	if not (proposals_value is Array):
		return timed
	for proposal_value in proposals_value:
		if not (proposal_value is Dictionary):
			continue
		var proposal: Dictionary = proposal_value.duplicate(true)
		proposal["timing"] = timing
		proposal["state_policy"] = "report_only"
		timed.append(proposal)
	return timed

static func _turn_transcript_target_assignment_records(before_snapshot: Dictionary, after_snapshot: Dictionary) -> Array:
	var before_map := _turn_transcript_raid_map(before_snapshot.get("active_raids", []))
	var records := []
	for after_raid_value in after_snapshot.get("active_raids", []):
		if not (after_raid_value is Dictionary):
			continue
		var after_raid: Dictionary = after_raid_value
		var placement_id := String(after_raid.get("placement_id", ""))
		var before_raid: Dictionary = before_map.get(placement_id, {})
		var previous_signature := String(before_raid.get("target_signature", ""))
		var current_signature := String(after_raid.get("target_signature", ""))
		if current_signature == "" or previous_signature == current_signature:
			continue
		var event_ref_id := _turn_transcript_event_ref_id(
			int(after_snapshot.get("day", 0)),
			String(after_snapshot.get("faction_id", "")),
			"ai_target_assigned",
			placement_id,
			String(after_raid.get("target_id", ""))
		)
		records.append(
			{
				"placement_id": placement_id,
				"roster_hero_id": String(after_raid.get("roster_hero_id", "")),
				"previous_target_signature": previous_signature,
				"current_target_signature": current_signature,
				"assignment_changed": true,
				"target_kind": String(after_raid.get("target_kind", "")),
				"target_id": String(after_raid.get("target_id", "")),
				"target_label": String(after_raid.get("target_label", "")),
				"target_x": int(after_raid.get("target_x", 0)),
				"target_y": int(after_raid.get("target_y", 0)),
				"reason_codes": _normalize_string_array(after_raid.get("reason_codes", [])),
				"public_reason": String(after_raid.get("public_reason", "")),
				"event_ref_id": event_ref_id,
				"state_policy": "derived",
			}
		)
	return records

static func _turn_transcript_target_no_op_records(
	before_snapshot: Dictionary,
	before_proposals: Array,
	assignment_records: Array
) -> Array:
	var assigned_commanders := {}
	for record_value in assignment_records:
		if record_value is Dictionary:
			assigned_commanders[String(record_value.get("roster_hero_id", ""))] = true
	var raid_by_commander := _turn_transcript_raid_by_commander(before_snapshot.get("active_raids", []))
	var no_ops := []
	for proposal_value in before_proposals:
		if not (proposal_value is Dictionary):
			continue
		var proposal: Dictionary = proposal_value
		var roster_hero_id := String(proposal.get("roster_hero_id", ""))
		if roster_hero_id == "" or assigned_commanders.has(roster_hero_id):
			continue
		var role_status := String(proposal.get("role_status", ""))
		var role := String(proposal.get("role", ""))
		var no_op_reason := "no_active_commander"
		var raid: Dictionary = raid_by_commander.get(roster_hero_id, {})
		if role == COMMANDER_ROLE_RECOVERING and role_status == "cooldown":
			no_op_reason = "commander_recovering"
		elif role == COMMANDER_ROLE_RECOVERING and role_status == "rebuilding":
			no_op_reason = "commander_rebuilding"
		elif String(proposal.get("validity", "")) == "invalid_target_missing":
			no_op_reason = "no_valid_target"
		elif not raid.is_empty():
			no_op_reason = "target_unchanged"
		no_ops.append(
			{
				"placement_id": String(raid.get("placement_id", "")),
				"roster_hero_id": roster_hero_id,
				"target_kind": String(proposal.get("target_kind", "")),
				"target_id": String(proposal.get("target_id", "")),
				"target_label": String(proposal.get("target_label", "")),
				"no_op_reason": no_op_reason,
				"public_reason": String(proposal.get("public_reason", "")),
				"reason_codes": _normalize_string_array(proposal.get("priority_reason_codes", [])),
				"state_policy": "derived",
			}
		)
	return no_ops

static func _turn_transcript_raid_movement_summary(before_snapshot: Dictionary, after_snapshot: Dictionary) -> Array:
	var before_map := _turn_transcript_raid_map(before_snapshot.get("active_raids", []))
	var movements := []
	for after_raid_value in after_snapshot.get("active_raids", []):
		if not (after_raid_value is Dictionary):
			continue
		var after_raid: Dictionary = after_raid_value
		var placement_id := String(after_raid.get("placement_id", ""))
		var before_raid: Dictionary = before_map.get(placement_id, {})
		if before_raid.is_empty():
			continue
		var moved := int(before_raid.get("x", 0)) != int(after_raid.get("x", 0)) or int(before_raid.get("y", 0)) != int(after_raid.get("y", 0))
		if not moved and String(after_raid.get("target_signature", "")) == "":
			continue
		movements.append(
			{
				"placement_id": placement_id,
				"roster_hero_id": String(after_raid.get("roster_hero_id", "")),
				"from": {"x": int(before_raid.get("x", 0)), "y": int(before_raid.get("y", 0))},
				"to": {"x": int(after_raid.get("x", 0)), "y": int(after_raid.get("y", 0))},
				"target_kind": String(after_raid.get("target_kind", "")),
				"target_id": String(after_raid.get("target_id", "")),
				"target_label": String(after_raid.get("target_label", "")),
				"goal_distance_before": int(before_raid.get("goal_distance", 9999)),
				"goal_distance_after": int(after_raid.get("goal_distance", 9999)),
				"arrived_before": bool(before_raid.get("arrived", false)),
				"arrived_after": bool(after_raid.get("arrived", false)),
				"movement_policy": "existing_advance_raids",
				"state_policy": "derived",
			}
		)
	return movements

static func _turn_transcript_raid_arrival_summary(before_snapshot: Dictionary, after_snapshot: Dictionary) -> Array:
	var before_map := _turn_transcript_raid_map(before_snapshot.get("active_raids", []))
	var before_controllers: Dictionary = before_snapshot.get("resource_controllers", {})
	var after_controllers: Dictionary = after_snapshot.get("resource_controllers", {})
	var arrivals := []
	for after_raid_value in after_snapshot.get("active_raids", []):
		if not (after_raid_value is Dictionary):
			continue
		var after_raid: Dictionary = after_raid_value
		var placement_id := String(after_raid.get("placement_id", ""))
		var before_raid: Dictionary = before_map.get(placement_id, {})
		if before_raid.is_empty() or not bool(after_raid.get("arrived", false)):
			continue
		var target_kind := String(after_raid.get("target_kind", ""))
		var target_id := String(after_raid.get("target_id", ""))
		var controller_before := ""
		var controller_after := ""
		if target_kind == "resource":
			controller_before = String(before_controllers.get(target_id, {}).get("controller_id", ""))
			controller_after = String(after_controllers.get(target_id, {}).get("controller_id", ""))
		if bool(before_raid.get("arrived", false)) and controller_before == controller_after:
			continue
		var event_type := "ai_raid_arrived"
		if target_kind == "resource" and controller_before != controller_after and controller_after == String(after_snapshot.get("faction_id", "")):
			event_type = "ai_site_seized"
		elif target_kind == "encounter":
			event_type = "ai_site_contested"
		var event_ref_id := _turn_transcript_event_ref_id(
			int(after_snapshot.get("day", 0)),
			String(after_snapshot.get("faction_id", "")),
			event_type,
			placement_id,
			target_id
		)
		arrivals.append(
			{
				"placement_id": placement_id,
				"roster_hero_id": String(after_raid.get("roster_hero_id", "")),
				"event_type": event_type,
				"event_ref_id": event_ref_id,
				"target_kind": target_kind,
				"target_id": target_id,
				"target_label": String(after_raid.get("target_label", "")),
				"target_controller_before": controller_before,
				"target_controller_after": controller_after,
				"site_event_ref_ids": [event_ref_id] if event_type in ["ai_site_seized", "ai_site_contested"] else [],
				"battle_queue_ref_ids": [],
				"pillage_message_ref_ids": [],
				"state_policy": "derived",
			}
		)
	return arrivals

static func _turn_transcript_phase_records(
	before_snapshot: Dictionary,
	after_snapshot: Dictionary,
	assignment_records: Array,
	movement_summary: Array,
	arrival_summary: Array,
	town_refs: Array
) -> Array:
	var phase_ids := [
		"normalize_enemy_states",
		"town_income_and_governor_projection",
		"town_build_recruit_reinforce",
		"pressure_gain",
		"advance_existing_raids",
		"battle_queue_checks",
		"spawn_raid_if_ready",
		"siege_and_posture",
		"turn_summary",
	]
	var phases := []
	for phase_id in phase_ids:
		var event_ref_ids := []
		var no_op_reason := ""
		match String(phase_id):
			"town_income_and_governor_projection", "town_build_recruit_reinforce":
				for ref_value in town_refs:
					if ref_value is Dictionary:
						event_ref_ids.append(String(ref_value.get("event_ref_id", "")))
				if event_ref_ids.is_empty():
					no_op_reason = "town_governor_only_turn"
			"advance_existing_raids":
				for record in assignment_records:
					event_ref_ids.append(String(record.get("event_ref_id", "")))
				for arrival in arrival_summary:
					event_ref_ids.append(String(arrival.get("event_ref_id", "")))
				if movement_summary.is_empty() and arrival_summary.is_empty():
					no_op_reason = "no_existing_raid_to_move"
			"spawn_raid_if_ready":
				if _turn_transcript_active_raid_count_delta(before_snapshot, after_snapshot) <= 0:
					no_op_reason = "pressure_below_launch_threshold"
			_:
				pass
		phases.append(
			{
				"phase_id": String(phase_id),
				"source_policy": "snapshot_derived",
				"faction_id": String(after_snapshot.get("faction_id", before_snapshot.get("faction_id", ""))),
				"before_counts": before_snapshot.get("enemy_state", {}),
				"after_counts": after_snapshot.get("enemy_state", {}),
				"event_ref_ids": _turn_transcript_non_empty_strings(event_ref_ids),
				"no_op_reason": no_op_reason,
			}
		)
	return phases

static func _turn_transcript_public_events(
	before_snapshot: Dictionary,
	after_snapshot: Dictionary,
	before_proposals: Array,
	assignment_records: Array,
	movement_summary: Array,
	arrival_summary: Array,
	town_refs: Array,
	phase_records: Array
) -> Array:
	var events := []
	var sequence := 1
	var faction_id := String(after_snapshot.get("faction_id", before_snapshot.get("faction_id", "")))
	var faction_label := String(after_snapshot.get("faction_label", before_snapshot.get("faction_label", faction_id)))
	var day := int(after_snapshot.get("day", before_snapshot.get("day", 0)))
	for proposal_value in before_proposals:
		if not (proposal_value is Dictionary):
			continue
		var proposal: Dictionary = proposal_value
		events.append(_turn_transcript_public_event(
			day,
			sequence,
			"ai_commander_role_observed",
			faction_id,
			faction_label,
			String(proposal.get("roster_hero_id", "")),
			String(proposal.get("commander_label", "")),
			String(proposal.get("target_kind", "")),
			String(proposal.get("target_id", "")),
			String(proposal.get("target_label", "")),
			int(proposal.get("target_x", 0)),
			int(proposal.get("target_y", 0)),
			"%s observed as %s for %s." % [
				String(proposal.get("commander_label", proposal.get("roster_hero_id", ""))),
				String(proposal.get("role", COMMANDER_ROLE_RESERVE)),
				String(proposal.get("target_label", proposal.get("target_id", "the front"))),
			],
			_normalize_string_array(proposal.get("priority_reason_codes", [])),
			String(proposal.get("public_reason", "")),
			"derived commander role",
			"medium",
			String(proposal.get("front_id", ""))
		))
		sequence += 1
	for record_value in assignment_records:
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		events.append(_turn_transcript_public_event(
			day,
			sequence,
			"ai_target_assigned",
			faction_id,
			faction_label,
			String(record.get("placement_id", "")),
			String(record.get("roster_hero_id", record.get("placement_id", ""))),
			String(record.get("target_kind", "")),
			String(record.get("target_id", "")),
			String(record.get("target_label", "")),
			int(record.get("target_x", 0)),
			int(record.get("target_y", 0)),
			"%s targets %s." % [String(record.get("roster_hero_id", "Raid host")), String(record.get("target_label", "the front"))],
			_normalize_string_array(record.get("reason_codes", [])),
			String(record.get("public_reason", "")),
			"existing target assignment",
			"high"
		))
		sequence += 1
	for movement_value in movement_summary:
		if not (movement_value is Dictionary):
			continue
		var movement: Dictionary = movement_value
		var event := _turn_transcript_public_event(
			day,
			sequence,
			"ai_raid_moved",
			faction_id,
			faction_label,
			String(movement.get("placement_id", "")),
			String(movement.get("roster_hero_id", movement.get("placement_id", ""))),
			String(movement.get("target_kind", "")),
			String(movement.get("target_id", "")),
			String(movement.get("target_label", "")),
			0,
			0,
			"%s moves toward %s." % [String(movement.get("roster_hero_id", "Raid host")), String(movement.get("target_label", "the front"))],
			[],
			"",
			"existing raid movement",
			"medium"
		)
		var from_pos: Dictionary = movement.get("from", {})
		var to_pos: Dictionary = movement.get("to", {})
		event["from_x"] = int(from_pos.get("x", 0))
		event["from_y"] = int(from_pos.get("y", 0))
		event["to_x"] = int(to_pos.get("x", 0))
		event["to_y"] = int(to_pos.get("y", 0))
		events.append(event)
		sequence += 1
	for arrival_value in arrival_summary:
		if not (arrival_value is Dictionary):
			continue
		var arrival: Dictionary = arrival_value
		events.append(_turn_transcript_public_event(
			day,
			sequence,
			String(arrival.get("event_type", "ai_raid_arrived")),
			faction_id,
			faction_label,
			String(arrival.get("placement_id", "")),
			String(arrival.get("roster_hero_id", arrival.get("placement_id", ""))),
			String(arrival.get("target_kind", "")),
			String(arrival.get("target_id", "")),
			String(arrival.get("target_label", "")),
			0,
			0,
			"%s reaches %s." % [String(arrival.get("roster_hero_id", "Raid host")), String(arrival.get("target_label", "the front"))],
			["site_seized"] if String(arrival.get("event_type", "")) == "ai_site_seized" else [],
			"site seized" if String(arrival.get("event_type", "")) == "ai_site_seized" else "",
			"existing raid arrival",
			"high"
		))
		sequence += 1
	for ref_value in town_refs:
		if not (ref_value is Dictionary):
			continue
		var ref: Dictionary = ref_value
		events.append(_turn_transcript_public_event(
			day,
			sequence,
			"ai_town_governor_support_ref",
			faction_id,
			faction_label,
			String(ref.get("town_placement_id", "")),
			String(ref.get("town_placement_id", "")),
			String(ref.get("target_kind", "")),
			String(ref.get("target_id", "")),
			String(ref.get("target_label", "")),
			0,
			0,
			"Town governor support noted for %s." % String(ref.get("target_label", ref.get("target_id", "the front"))),
			_normalize_string_array(ref.get("reason_codes", [])),
			String(ref.get("public_reason", "")),
			"supporting town governor event",
			"medium",
			String(ref.get("supports_front_id", ""))
		))
		sequence += 1
	events.append(_turn_transcript_public_event(
		day,
		sequence,
		"ai_turn_phase_summary",
		faction_id,
		faction_label,
		faction_id,
		faction_label,
		"front",
		String(options_get_case_front_id(before_proposals)),
		"enemy turn",
		0,
		0,
		"%s enemy turn summarized in %d phases." % [faction_label, phase_records.size()],
		[],
		"",
		"snapshot phase summary",
		"low",
		"turn_summary"
	))
	return events

static func _turn_transcript_public_event(
	day: int,
	sequence: int,
	event_type: String,
	faction_id: String,
	faction_label: String,
	actor_id: String,
	actor_label: String,
	target_kind: String,
	target_id: String,
	target_label: String,
	target_x: int,
	target_y: int,
	summary: String,
	reason_codes: Array,
	public_reason: String,
	debug_reason: String,
	public_importance: String = "medium",
	phase_id: String = ""
) -> Dictionary:
	return {
		"event_id": "%d:%s:%s:%s:%s:%d" % [day, faction_id, event_type, actor_id, target_id, sequence],
		"day": day,
		"sequence": sequence,
		"event_type": event_type,
		"phase_id": phase_id,
		"faction_id": faction_id,
		"faction_label": faction_label,
		"actor_id": actor_id,
		"actor_label": actor_label if actor_label != "" else actor_id,
		"target_kind": target_kind,
		"target_id": target_id,
		"target_label": target_label if target_label != "" else target_id,
		"target_x": target_x,
		"target_y": target_y,
		"visibility": "hidden_debug",
		"public_importance": public_importance,
		"summary": summary,
		"reason_codes": _normalize_string_array(reason_codes),
		"public_reason": public_reason,
		"debug_reason": debug_reason,
		"state_policy": "derived",
	}

static func _turn_transcript_source_marker_check(values: Array) -> Dictionary:
	var stack := values.duplicate(true)
	var checked := 0
	while not stack.is_empty():
		var value = stack.pop_back()
		if value is Array:
			for item in value:
				stack.append(item)
			continue
		if not (value is Dictionary):
			continue
		if value.has("phase_id") or value.has("event_type") or value.has("role") or value.has("placement_id") or value.has("event_ref_id") or value.has("roster_hero_id"):
			checked += 1
			if not (
				String(value.get("state_policy", "")) in ["derived", "report_only"]
				or String(value.get("source_policy", "")) == "snapshot_derived"
				or String(value.get("schema_status", "")) == "report_fixture_only"
			):
				return {"ok": false, "error": "transcript record missing derived/report-only source marker: %s" % JSON.stringify(value)}
		for nested_key in value.keys():
			var nested = value[nested_key]
			if nested is Array or nested is Dictionary:
				stack.append(nested)
	return {"ok": true, "checked_records": checked}

static func _turn_transcript_no_ops_valid(no_ops: Array) -> bool:
	for record_value in no_ops:
		if not (record_value is Dictionary):
			return false
		if String(record_value.get("no_op_reason", "")) not in COMMANDER_ROLE_TURN_NO_OP_REASONS:
			return false
	return true

static func _turn_transcript_raid_map(raids_value: Variant) -> Dictionary:
	var output := {}
	if not (raids_value is Array):
		return output
	for raid_value in raids_value:
		if raid_value is Dictionary:
			output[String(raid_value.get("placement_id", ""))] = raid_value
	return output

static func _turn_transcript_raid_by_commander(raids_value: Variant) -> Dictionary:
	var output := {}
	if not (raids_value is Array):
		return output
	for raid_value in raids_value:
		if raid_value is Dictionary:
			output[String(raid_value.get("roster_hero_id", ""))] = raid_value
	return output

static func _turn_transcript_merge_town_refs(before_refs_value: Variant, after_refs_value: Variant) -> Array:
	var output := []
	var seen := {}
	for source in [before_refs_value, after_refs_value]:
		if not (source is Array):
			continue
		for ref_value in source:
			if not (ref_value is Dictionary):
				continue
			var ref_id := String(ref_value.get("event_ref_id", ""))
			if ref_id == "" or seen.has(ref_id):
				continue
			seen[ref_id] = true
			output.append(ref_value)
	return output

static func _turn_transcript_non_empty_strings(values: Array) -> Array:
	var output := []
	for value in values:
		var text := String(value)
		if text != "" and text not in output:
			output.append(text)
	return output

static func _turn_transcript_active_raid_count_delta(before_snapshot: Dictionary, after_snapshot: Dictionary) -> int:
	return int(after_snapshot.get("active_raids", []).size()) - int(before_snapshot.get("active_raids", []).size())

static func _turn_transcript_event_ref_id(day: int, faction_id: String, event_type: String, actor_id: String, target_id: String) -> String:
	return "%d:%s:%s:%s:%s" % [day, faction_id, event_type, actor_id, target_id]

static func options_get_case_front_id(proposals: Array) -> String:
	for proposal_value in proposals:
		if proposal_value is Dictionary and String(proposal_value.get("front_id", "")) != "":
			return String(proposal_value.get("front_id", ""))
	return "turn_summary"

static func _commander_role_assignment_id_hint(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_hero_id: String,
	role: String,
	target_kind: String,
	target_id: String
) -> String:
	if session == null or faction_id == "" or roster_hero_id == "" or role == "" or target_kind == "" or target_id == "":
		return ""
	return "role:%s:%s:%s:%s:%s:%s:day_%d" % [
		String(session.scenario_id),
		faction_id,
		roster_hero_id,
		role,
		target_kind,
		target_id,
		int(session.day),
	]

static func _commander_role_expected_transition(role: String) -> String:
	match role:
		COMMANDER_ROLE_DEFENDER:
			return "hold_front_or_intercept"
		COMMANDER_ROLE_STABILIZER:
			return "support_front_stabilization"
		COMMANDER_ROLE_RECOVERING:
			return "wait_until_recovery_day"
		COMMANDER_ROLE_RESERVE:
			return "wait_for_target"
		_:
			return "spawn_or_link_raid"

static func _default_reason_codes_for_target(target_kind: String, target_id: String, target: Dictionary = {}) -> Array:
	match target_kind:
		"town":
			var codes := ["town_siege"]
			if bool(target.get("objective_anchor", true)) or target_id == "riverwatch_hold":
				codes.append("objective_front")
			return codes
		"resource":
			return ["route_pressure"]
		"encounter":
			return ["site_contested", "objective_front"]
		_:
			return []

static func _default_public_importance(target_kind: String, reason_codes: Array) -> String:
	if target_kind == "town" or "town_siege" in reason_codes:
		return "critical"
	if "persistent_income_denial" in reason_codes or "recruit_denial" in reason_codes or "objective_front" in reason_codes:
		return "high"
	if "site_seized" in reason_codes or "site_contested" in reason_codes:
		return "medium"
	return "low"

static func _event_visibility(session: SessionStateStoreScript.SessionData, x: int, y: int, public_importance: String) -> String:
	if OverworldRulesScript.is_tile_visible(session, x, y):
		return "visible"
	if OverworldRulesScript.is_tile_explored(session, x, y):
		return "scouted"
	if public_importance in ["critical", "high"]:
		return "rumored"
	return "hidden_debug"

static func _ai_event_summary(
	event_type: String,
	faction_label: String,
	actor_label: String,
	target_label: String,
	public_reason: String,
	summary_prefix: String = ""
) -> String:
	var actor_clause := actor_label if actor_label != "" else faction_label
	var reason_suffix := " (%s)" % public_reason if public_reason != "" else ""
	match event_type:
		"ai_target_assigned":
			var verb := summary_prefix if summary_prefix != "" else "targets"
			return "%s %s %s%s." % [actor_clause, verb, target_label, reason_suffix]
		"ai_site_seized":
			return "%s seizes %s%s." % [actor_clause, target_label, reason_suffix]
		"ai_site_contested":
			return "%s contests %s%s." % [actor_clause, target_label, reason_suffix]
		"ai_site_defended":
			return "%s defends %s%s." % [actor_clause, target_label, reason_suffix]
		"ai_town_captured":
			return "%s claims %s%s." % [actor_clause, target_label, reason_suffix]
		"ai_pressure_summary":
			return "%s pressure centers on %s%s." % [faction_label, target_label, reason_suffix]
		"ai_raid_grouped":
			return "%s consolidates on %s%s." % [actor_clause, target_label, reason_suffix]
		_:
			return "%s marks %s%s." % [actor_clause, target_label, reason_suffix]

static func _normalize_string_array(value: Variant) -> Array:
	var output := []
	if not (value is Array):
		return output
	for item in value:
		var text := String(item)
		if text != "" and text not in output:
			output.append(text)
	return output

static func _increment_count(counts: Dictionary, key: String) -> void:
	if key == "":
		key = "unspecified"
	counts[key] = int(counts.get(key, 0)) + 1

static func _adventure_spell_value(
	hero_state: Dictionary,
	movement_state: Dictionary,
	strategic_context: Dictionary,
	spell: Dictionary,
	behavior: Dictionary,
	validation: Dictionary,
	consequence: Dictionary
) -> float:
	if not bool(validation.get("ok", false)):
		return 0.0
	var restored := int(consequence.get("movement_restored", 0))
	var movement_max: int = max(1, int(movement_state.get("max", 1)))
	var value := 1.0 + (float(restored) / float(movement_max)) * 6.0
	if String(behavior.get("target_policy", "")) == "self_hero_reveal_radius":
		var reveal_radius: int = max(0, int(consequence.get("reveal_radius", 0)))
		value += min(8.0, float(reveal_radius) * 1.15)
		if bool(strategic_context.get("scouting_pressure", false)):
			value += 2.0 + min(5.0, float(max(0, int(strategic_context.get("unscouted_target_count", 0)))) * 0.75)
		if bool(strategic_context.get("hidden_site_reveal", false)):
			value += 1.5
	var objective_steps := int(strategic_context.get("objective_steps_remaining", 0))
	var movement_current := int(movement_state.get("current", 0))
	var movement_after := int(consequence.get("movement_after", movement_current))
	if objective_steps > movement_current and objective_steps <= movement_after:
		value += 5.0
	if String(strategic_context.get("target_kind", "")) in ["town", "resource_site", "objective", "threat"]:
		value += 1.5
	if bool(strategic_context.get("route_pressure", false)):
		value += 1.0
	if bool(strategic_context.get("threat_nearby", false)):
		value += 1.0
	if String(behavior.get("target_policy", "")) == "self_hero_movement_gap":
		value += 0.75
	value -= float(int(spell.get("mana_cost", 0))) * 0.2
	return value

static func _public_adventure_spell_candidate(
	spell: Dictionary,
	behavior: Dictionary,
	validation: Dictionary,
	consequence: Dictionary,
	strategic_context: Dictionary,
	value: float
) -> Dictionary:
	var recommendation := "hold"
	if bool(validation.get("ok", false)) and value >= 5.0:
		recommendation = "cast"
	return {
		"spell_id": String(spell.get("id", "")),
		"spell_name": String(spell.get("name", "")),
		"school_id": String(behavior.get("school_id", "")),
		"tier": int(behavior.get("tier", 0)),
		"primary_role": String(behavior.get("primary_role", "")),
		"role_categories": behavior.get("role_categories", []),
		"effect_type": String(behavior.get("effect_type", "")),
		"target_policy": String(behavior.get("target_policy", "")),
		"runtime_hooks": behavior.get("runtime_hooks", []),
		"map_mutation": String(behavior.get("map_mutation", "")),
		"availability": "ready" if bool(validation.get("ok", false)) else "blocked",
		"blocked_reason": String(validation.get("message", "")) if not bool(validation.get("ok", false)) else "",
		"movement_before": int(consequence.get("movement_before", 0)),
		"movement_after": int(consequence.get("movement_after", int(consequence.get("movement_before", 0)))),
		"movement_restored": int(consequence.get("movement_restored", 0)),
		"reveal_radius": int(consequence.get("reveal_radius", 0)),
		"value_band": _adventure_spell_value_band(value),
		"recommendation": recommendation,
		"reason": _adventure_spell_reason(strategic_context, behavior, validation, consequence),
	}

static func _adventure_spell_value_band(value: float) -> String:
	if value >= 10.0:
		return "decisive"
	if value >= 7.0:
		return "strong"
	if value >= 5.0:
		return "useful"
	return "low"

static func _adventure_band_rank(value_band: String) -> int:
	match value_band:
		"decisive":
			return 4
		"strong":
			return 3
		"useful":
			return 2
		_:
			return 1

static func _adventure_spell_reason(
	strategic_context: Dictionary,
	behavior: Dictionary,
	validation: Dictionary,
	consequence: Dictionary
) -> String:
	if not bool(validation.get("ok", false)):
		return "hold because the spell is not currently castable"
	var objective_steps := int(strategic_context.get("objective_steps_remaining", 0))
	var movement_before := int(consequence.get("movement_before", 0))
	var movement_after := int(consequence.get("movement_after", movement_before))
	if objective_steps > movement_before and objective_steps <= movement_after:
		return "cast because restored movement reaches the current %s" % String(strategic_context.get("target_kind", "target"))
	if String(behavior.get("target_policy", "")) == "self_hero_reveal_radius" and bool(strategic_context.get("scouting_pressure", false)):
		return "cast because scouting reveals actionable nearby targets"
	if int(consequence.get("movement_restored", 0)) > 0 and bool(strategic_context.get("route_pressure", false)):
		return "cast to preserve route pressure with the authored movement spell hook"
	if String(behavior.get("target_policy", "")) == "self_hero_movement_gap":
		return "hold until restored movement changes a route, site, town, or threat decision"
	return "hold until the map objective justifies the spell"

static func _resource_payload_summary(payload: Variant) -> String:
	if not (payload is Dictionary):
		return "site value"
	var parts := []
	for key in ["gold", "wood", "ore", "experience"]:
		var amount: int = max(0, int(payload.get(key, 0)))
		if amount > 0:
			parts.append("%d %s" % [amount, key])
	if parts.is_empty():
		return "site value"
	return ", ".join(parts)

static func _linked_player_town_bonus(session: SessionStateStoreScript.SessionData, node: Dictionary) -> int:
	var linked_town = {}
	var best_distance = 9999
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "player":
			continue
		var logistics: Dictionary = OverworldRulesScript.town_logistics_state(session, town)
		var distance: int = abs(int(node.get("x", 0)) - int(town.get("x", 0))) + abs(int(node.get("y", 0)) - int(town.get("y", 0)))
		if distance > int(logistics.get("support_radius", 0)):
			continue
		if distance < best_distance:
			best_distance = distance
			linked_town = town
	if linked_town.is_empty():
		return 0
	var bonus = 0
	match OverworldRulesScript.town_strategic_role(linked_town):
		"capital":
			bonus += 35
		"stronghold":
			bonus += 18
	var recovery: Dictionary = OverworldRulesScript.town_recovery_state(session, linked_town)
	bonus += int(recovery.get("pressure", 0)) * 8
	var capital_project: Dictionary = OverworldRulesScript.town_capital_project_state(linked_town, session)
	if bool(capital_project.get("active", false)):
		bonus += 18
	if bool(capital_project.get("vulnerable", false)):
		bonus += 22
	return bonus

static func _artifact_target_priority(session: SessionStateStoreScript.SessionData, node: Variant) -> int:
	if not (node is Dictionary) or bool(node.get("collected", false)):
		return 0
	var artifact = ContentService.get_artifact(String(node.get("artifact_id", "")))
	var bonuses = artifact.get("bonuses", {})
	var priority = 105
	priority += max(0, int(bonuses.get("overworld_movement", 0))) * 20
	priority += max(0, int(bonuses.get("scouting_radius", 0))) * 18
	priority += max(0, int(bonuses.get("battle_attack", 0))) * 15
	priority += max(0, int(bonuses.get("battle_defense", 0))) * 15
	priority += max(0, int(bonuses.get("battle_initiative", 0))) * 16
	priority += int(min(50, _target_resource_value(bonuses.get("daily_income", {})) / 80))
	priority += _objective_proximity_bonus(session, int(node.get("x", 0)), int(node.get("y", 0)))
	return priority

static func _public_artifact_target_payload(target: Dictionary) -> Dictionary:
	return {
		"target_kind": "artifact",
		"placement_id": String(target.get("placement_id", "")),
		"artifact_id": String(target.get("artifact_id", "")),
		"artifact_label": String(target.get("artifact_label", "")),
		"artifact_class": String(target.get("artifact_class", "")),
		"rarity": String(target.get("rarity", "")),
		"family": String(target.get("family", "")),
		"role_buckets": _normalize_string_array(target.get("role_buckets", [])),
		"accord_affinity": String(target.get("accord_affinity", "")),
		"faction_affinity_match": bool(target.get("faction_affinity_match", false)),
		"set_context": "set_piece" if String(target.get("set_id", "")) != "" else "standalone",
		"source_contexts": _normalize_string_array(target.get("source_context_tags", [])),
		"runtime_surfaces": _normalize_string_array(target.get("runtime_surfaces", [])),
		"strategic_band": String(target.get("strategic_band", "")),
		"reason_codes": _normalize_string_array(target.get("reason_codes", [])),
		"public_reason": String(target.get("public_reason", "")),
		"public_importance": String(target.get("public_importance", "medium")),
	}

static func _artifact_role_buckets(artifact: Dictionary) -> Array:
	var roles := _normalize_string_array(artifact.get("roles", []))
	var ai_hints: Dictionary = artifact.get("ai_hints", {}) if artifact.get("ai_hints", {}) is Dictionary else {}
	var drivers := _normalize_string_array(ai_hints.get("value_drivers", []))
	var buckets := []
	if "movement" in roles or "route" in roles or "route_tempo" in drivers or "root_route_tempo" in drivers or "fog_route_scouting" in drivers:
		buckets.append("route")
	if "scouting" in roles or "reward_modifier" in roles or "scouting_reach" in drivers or "hidden_site_reveal" in drivers:
		buckets.append("scouting")
	if "economy" in roles or "town_support" in roles or "common_resource_income" in drivers or "town_build_support" in drivers:
		buckets.append("economy")
	if "combat" in roles or "morale" in roles or "frontline_attack" in drivers or "initiative_tempo" in drivers:
		buckets.append("command")
	if "defense" in roles or "resistance" in roles or "frontline_survival" in drivers or "town_defense" in drivers:
		buckets.append("defense")
	if "magic" in roles or String(artifact.get("accord_affinity", "")) not in ["", "neutral", "none"]:
		buckets.append("magic")
	if "recruitment" in roles:
		buckets.append("recruitment")
	if "progression" in roles or _artifact_set_id_from_record(artifact) != "":
		buckets.append("progression")
	return buckets

static func _artifact_runtime_surfaces(artifact: Dictionary) -> Array:
	var bonuses = artifact.get("bonuses", {})
	if not (bonuses is Dictionary):
		return []
	var surfaces := []
	if int(bonuses.get("overworld_movement", 0)) != 0:
		surfaces.append("adventure_movement")
	if int(bonuses.get("scouting_radius", 0)) != 0:
		surfaces.append("adventure_scouting")
	if (
		int(bonuses.get("battle_attack", 0)) != 0
		or int(bonuses.get("battle_defense", 0)) != 0
		or int(bonuses.get("battle_initiative", 0)) != 0
	):
		surfaces.append("battle_command")
	var income = bonuses.get("daily_income", {})
	if income is Dictionary and not _reward_resources_for_empire(income).is_empty():
		surfaces.append("daily_common_income")
	var spell_modifiers = bonuses.get("spell_modifiers", [])
	if spell_modifiers is Array and not spell_modifiers.is_empty():
		surfaces.append("spell_modifier")
	return surfaces

static func _artifact_source_contexts(artifact_id: String) -> Array:
	var raw := ContentService.load_json(ContentService.ARTIFACTS_PATH)
	var tables = raw.get("source_reward_tables", [])
	var contexts := []
	if not (tables is Array):
		return contexts
	for table_value in tables:
		if not (table_value is Dictionary):
			continue
		var table: Dictionary = table_value
		if artifact_id not in _normalize_string_array(table.get("artifact_ids", [])):
			continue
		contexts.append(
			{
				"source_tag": String(table.get("source_tag", "")),
				"reward_context": String(table.get("reward_context", "")),
				"guard_tiers": _normalize_string_array(table.get("guard_tiers", [])),
				"rarity_bands": _normalize_string_array(table.get("rarity_bands", [])),
			}
		)
	return contexts

static func _artifact_set_id_from_record(artifact: Dictionary) -> String:
	for key in ["set_id", "artifact_set_id", "set"]:
		var value = artifact.get(key, "")
		if value is Dictionary:
			var nested_id := String(value.get("id", "")).strip_edges()
			if nested_id != "":
				return nested_id
		var label := String(value).strip_edges()
		if label != "":
			return label
	var validation_tags = artifact.get("validation_tags", {})
	if validation_tags is Dictionary:
		return String(validation_tags.get("set_id", "")).strip_edges()
	return ""

static func _artifact_taxonomy_signal_value(artifact: Dictionary, role_buckets: Array) -> int:
	var value := role_buckets.size() * 8
	match String(artifact.get("rarity", "")):
		"uncommon":
			value += 8
		"rare":
			value += 18
		"epic":
			value += 32
		"legendary":
			value += 48
		"scenario":
			value += 20
	match String(artifact.get("artifact_class", "")):
		"faction", "accord", "set_piece":
			value += 10
		"relic", "old_measure":
			value += 24
	return value

static func _artifact_runtime_signal_value(artifact: Dictionary, runtime_surfaces: Array) -> int:
	var bonuses = artifact.get("bonuses", {})
	if not (bonuses is Dictionary):
		return 0
	var value := runtime_surfaces.size() * 7
	value += max(0, int(bonuses.get("overworld_movement", 0))) * 10
	value += max(0, int(bonuses.get("scouting_radius", 0))) * 8
	value += max(0, int(bonuses.get("battle_attack", 0))) * 8
	value += max(0, int(bonuses.get("battle_defense", 0))) * 8
	value += max(0, int(bonuses.get("battle_initiative", 0))) * 9
	value += int(min(28, _target_resource_value(bonuses.get("daily_income", {})) / 120))
	return value

static func _artifact_strategic_band(signal_value: int) -> String:
	if signal_value >= 110:
		return "decisive"
	if signal_value >= 75:
		return "high"
	if signal_value >= 45:
		return "medium"
	return "low"

static func _artifact_reason_codes(
	artifact: Dictionary,
	role_buckets: Array,
	runtime_surfaces: Array,
	source_context_tags: Array,
	faction_match: bool,
	set_id: String
) -> Array:
	var codes := []
	if "route" in role_buckets:
		codes.append("route_tempo")
	if "scouting" in role_buckets:
		codes.append("scouting_reach")
	if "economy" in role_buckets:
		codes.append("economy_support")
	if "command" in role_buckets:
		codes.append("command_pressure")
	if "defense" in role_buckets:
		codes.append("defense_posture")
	if "magic" in role_buckets:
		codes.append("magic_support")
	if "daily_common_income" in runtime_surfaces and "economy_support" not in codes:
		codes.append("economy_support")
	if "battle_command" in runtime_surfaces and "command_pressure" not in codes:
		codes.append("command_pressure")
	if not source_context_tags.is_empty():
		codes.append("source_eligible")
	if faction_match:
		codes.append("faction_fit")
	if set_id != "":
		codes.append("set_progress")
	return codes

static func _artifact_public_reason(reason_codes: Array) -> String:
	if "faction_fit" in reason_codes:
		return "faction-fit relic"
	if "economy_support" in reason_codes:
		return "economy support relic"
	if "route_tempo" in reason_codes and "scouting_reach" in reason_codes:
		return "route scouting relic"
	if "route_tempo" in reason_codes:
		return "route tempo relic"
	if "scouting_reach" in reason_codes:
		return "scouting relic"
	if "defense_posture" in reason_codes:
		return "defensive relic"
	if "command_pressure" in reason_codes:
		return "command relic"
	if "magic_support" in reason_codes:
		return "magic relic"
	if "set_progress" in reason_codes:
		return "set progress relic"
	return "artifact reward"

static func _artifact_public_importance(reason_codes: Array, final_priority: int) -> String:
	if "faction_fit" in reason_codes or final_priority >= 190:
		return "high"
	if "economy_support" in reason_codes or "set_progress" in reason_codes or final_priority >= 145:
		return "medium"
	return "low"

static func _encounter_target_priority(session: SessionStateStoreScript.SessionData, encounter: Variant) -> int:
	if not (encounter is Dictionary):
		return 0
	if String(encounter.get("spawned_by_faction_id", "")) != "" or OverworldRulesScript.is_encounter_resolved(session, encounter):
		return 0
	var encounter_template = ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	var priority = 95 + int(min(80, _target_resource_value(encounter_template.get("rewards", {})) / 130))
	if _encounter_is_objective_anchor(session, encounter):
		priority += 70
	priority += _objective_proximity_bonus(session, int(encounter.get("x", 0)), int(encounter.get("y", 0)))
	return priority

static func _target_resource_value(rewards: Variant) -> int:
	if not (rewards is Dictionary):
		return 0
	return max(0, int(rewards.get("gold", 0))) + (max(0, int(rewards.get("wood", 0))) * 350) + (max(0, int(rewards.get("ore", 0))) * 350) + max(0, int(rewards.get("experience", 0)))

static func _target_resource_value_for_strategy(rewards: Variant, strategy: Dictionary) -> int:
	if not (rewards is Dictionary):
		return 0
	var weights: Dictionary = strategy.get("resource_value_weights", {})
	var total := 0.0
	total += float(max(0, int(rewards.get("gold", 0)))) * float(weights.get("gold", 1.0))
	total += float(max(0, int(rewards.get("wood", 0))) * 350) * float(weights.get("wood", 1.0))
	total += float(max(0, int(rewards.get("ore", 0))) * 350) * float(weights.get("ore", 1.0))
	total += float(max(0, int(rewards.get("experience", 0)))) * float(weights.get("experience", 1.0))
	return max(0, int(round(total)))

static func _resource_affinity_value(claim_value: int, income_value: int, weighted_claim_value: int, weighted_income_value: int) -> int:
	var claim_delta: int = max(0, weighted_claim_value - claim_value)
	var income_delta: int = max(0, weighted_income_value - income_value)
	return int(min(70.0, (float(claim_delta) / 35.0) + (float(income_delta) / 18.0)))

static func _objective_proximity_bonus(session: SessionStateStoreScript.SessionData, x: int, y: int) -> int:
	var best_distance = 9999
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary):
			continue
		var placement_id = String(town.get("placement_id", ""))
		if placement_id == "" or not _town_is_objective_anchor(session, placement_id):
			continue
		var distance: int = abs(x - int(town.get("x", 0))) + abs(y - int(town.get("y", 0)))
		if distance < best_distance:
			best_distance = distance
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if not _encounter_is_objective_anchor(session, encounter):
			continue
		var distance: int = abs(x - int(encounter.get("x", 0))) + abs(y - int(encounter.get("y", 0)))
		if distance < best_distance:
			best_distance = distance
	if best_distance == 9999:
		return 0
	if best_distance <= 1:
		return 45
	if best_distance <= 3:
		return 25
	if best_distance <= 5:
		return 10
	return 0

static func _assignment_penalty(session: SessionStateStoreScript.SessionData, target_kind: String, placement_id: String) -> int:
	if placement_id == "":
		return 0
	var penalty = 0
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not _is_active_raid(encounter, "", resolved_encounters):
			continue
		if String(encounter.get("target_kind", "")) != target_kind:
			continue
		if String(encounter.get("target_placement_id", "")) != placement_id:
			continue
		penalty += 90 if bool(encounter.get("arrived", false)) else 45
	return penalty

static func _town_started_enemy(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	var scenario = ContentService.get_scenario(session.scenario_id)
	for town in scenario.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return String(town.get("owner", "neutral")) == "enemy"
	return false

static func _town_is_objective_anchor(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	var scenario = ContentService.get_scenario(session.scenario_id)
	var objectives = scenario.get("objectives", {})
	if not (objectives is Dictionary):
		return false
	for bucket in ["victory", "defeat"]:
		for objective in objectives.get(bucket, []):
			if objective is Dictionary and String(objective.get("placement_id", "")) == placement_id:
				return true
	return false

static func _encounter_is_objective_anchor(session: SessionStateStoreScript.SessionData, encounter: Dictionary) -> bool:
	var encounter_template = ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	var victory_flags: Array = encounter_template.get("victory_flags", [])
	if not (victory_flags is Array) or victory_flags.is_empty():
		return false
	var scenario = ContentService.get_scenario(session.scenario_id)
	var objectives = scenario.get("objectives", {})
	if not (objectives is Dictionary):
		return false
	for bucket in ["victory", "defeat"]:
		for objective in objectives.get(bucket, []):
			if not (objective is Dictionary):
				continue
			if String(objective.get("type", "")) != "flag_true":
				continue
			if String(objective.get("flag", "")) in victory_flags:
				return true
	return false

static func _best_goal_tile(session: SessionStateStoreScript.SessionData, origin_pos: Vector2i, goal_tiles: Array) -> Vector2i:
	if goal_tiles.is_empty():
		return origin_pos
	var best_tile: Vector2i = goal_tiles[0]
	var best_distance = _path_distance(session, origin_pos, goal_tiles, "")
	for tile in goal_tiles:
		if not (tile is Vector2i):
			continue
		var distance = _path_distance(session, origin_pos, [tile], "")
		if distance < best_distance:
			best_distance = distance
			best_tile = tile
	return best_tile

static func _resolve_arrived_target(
	session: SessionStateStoreScript.SessionData,
	raid: Dictionary,
	state: Dictionary,
	faction_id: String,
	config: Dictionary = {}
) -> Dictionary:
	match String(raid.get("target_kind", "")):
		"town":
			var reason_codes := _normalize_string_array(raid.get("target_reason_codes", []))
			var town_result := _find_town_by_placement(session, String(raid.get("target_placement_id", "")))
			var town: Dictionary = town_result.get("town", {})
			if (
				not town.is_empty()
				and String(town.get("owner", "neutral")) == "neutral"
				and _town_garrison_strength(town) <= 0
				and ("town_expansion" in reason_codes or "neutral_town_claim" in reason_codes)
			):
				return _secure_neutral_town_target(session, raid, state, faction_id)
			if (
				not town.is_empty()
				and String(town.get("owner", "neutral")) == "enemy"
				and _town_faction_id(town) == faction_id
				and "town_defense" in reason_codes
			):
				return _defend_town_target(session, raid, state, faction_id)
			return {"encounter": raid, "state": state, "event_message": ""}
		"resource":
			var node_result = _find_resource_by_placement(session, String(raid.get("target_placement_id", "")))
			var node: Dictionary = node_result.get("node", {})
			var site := ContentService.get_resource_site(String(node.get("site_id", "")))
			if _resource_node_defensible_by_faction(node, site, faction_id, _normalize_string_array(raid.get("target_reason_codes", []))):
				return _defend_resource_target(session, raid, state, faction_id)
			var ready_report := resource_arrival_ready_report(session, raid, faction_id)
			if not bool(ready_report.get("ready", true)):
				var previous_target := _current_target_snapshot(raid)
				var redirected := redirect_resource_objective_for_risk(session, config, raid, faction_id, ready_report)
				var retask_event := ai_target_assignment_event(session, config, redirected, previous_target)
				if retask_event.is_empty():
					retask_event = ai_target_assignment_event(session, config, redirected, {})
				return {
					"encounter": redirected,
					"state": state,
					"event_message": "",
					"ai_event": retask_event,
					"risk_gated": true,
					"risk_report": ready_report,
				}
			var resource_guard := _resource_guard_encounter_for_node(session, node, site)
			if not resource_guard.is_empty():
				return _redirect_claim_to_guard_encounter(session, config, raid, state, faction_id, resource_guard, "resource")
			return _secure_resource_target(session, raid, state, faction_id)
		"artifact":
			var artifact_result = _find_artifact_by_placement(session, String(raid.get("target_placement_id", "")))
			var artifact_node: Dictionary = artifact_result.get("node", {})
			var artifact_guard := _artifact_guard_encounter_for_node(session, artifact_node)
			if not artifact_guard.is_empty():
				return _redirect_claim_to_guard_encounter(session, config, raid, state, faction_id, artifact_guard, "artifact")
			return _secure_artifact_target(session, raid, state, faction_id)
		"encounter":
			var ready_report := encounter_arrival_ready_report(session, raid, faction_id)
			if not bool(ready_report.get("ready", true)):
				var previous_target := _current_target_snapshot(raid)
				var redirected := redirect_encounter_objective_for_risk(session, config, raid, faction_id, ready_report)
				var retask_event := ai_target_assignment_event(session, config, redirected, previous_target)
				if retask_event.is_empty():
					retask_event = ai_target_assignment_event(session, config, redirected, {})
				return {
					"encounter": redirected,
					"state": state,
					"event_message": "",
					"ai_event": retask_event,
					"risk_gated": true,
					"risk_report": ready_report,
				}
			return _contest_encounter_target(session, raid, state, faction_id, config)
		"regroup":
			return _regroup_raid_at_town(session, raid, state, faction_id)
		_:
			return {"encounter": raid, "state": state, "event_message": ""}

static func _secure_resource_target(
	session: SessionStateStoreScript.SessionData,
	raid: Dictionary,
	state: Dictionary,
	faction_id: String
) -> Dictionary:
	var node_result = _find_resource_by_placement(session, String(raid.get("target_placement_id", "")))
	var node = node_result.get("node", {})
	if int(node_result.get("index", -1)) < 0:
		return {"encounter": raid, "state": state, "event_message": ""}
	var site = ContentService.get_resource_site(String(node.get("site_id", "")))
	if not _resource_node_contestable_by_faction(node, site, faction_id):
		if String(node.get("collected_by_faction_id", "")) == faction_id:
			_ai_hero_task_finish_live_assignment(session, faction_id, raid, "completed", "valid")
		return {"encounter": raid, "state": state, "event_message": ""}
	var nodes = session.overworld.get("resource_nodes", [])
	var previous_node: Dictionary = node.duplicate(true)
	var previous_controller = String(node.get("collected_by_faction_id", ""))
	var escorted_route = int(previous_node.get("response_until_day", 0)) >= session.day
	var escort_strength: int = max(0, int(previous_node.get("response_security_rating", 0)))
	var delivery_value := _recruit_payload_value(previous_node.get("delivery_manifest", {}))
	var delivery_target_label := String(previous_node.get("delivery_target_label", "the front"))
	if delivery_target_label == "":
		delivery_target_label = "the front"
	node["collected"] = true
	node["collected_by_faction_id"] = faction_id
	node["collected_day"] = session.day
	node["response_origin"] = ""
	node["response_source_town_id"] = ""
	node["response_last_day"] = 0
	node["response_until_day"] = 0
	node["response_commander_id"] = ""
	node["response_security_rating"] = 0
	node["delivery_controller_id"] = ""
	node["delivery_origin_town_id"] = ""
	node["delivery_target_kind"] = ""
	node["delivery_target_id"] = ""
	node["delivery_target_label"] = ""
	node["delivery_arrival_day"] = 0
	node["delivery_manifest"] = {}
	nodes[int(node_result.get("index", -1))] = node
	session.overworld["resource_nodes"] = nodes

	var spoils = _reward_resources_for_empire(_resource_site_claim_rewards(site))
	state["treasury"] = _merge_resources(state.get("treasury", {}), spoils)
	state["pressure"] = max(0, int(state.get("pressure", 0))) + _resource_site_pressure_value(site)
	if escorted_route:
		state["pressure"] += max(1, escort_strength)
	if delivery_value > 0:
		state["pressure"] = max(0, int(state.get("pressure", 0))) + clamp(int(ceili(float(delivery_value) / 220.0)), 1, 3)
	var updated_raid := _record_adventure_objective_success(
		session,
		faction_id,
		raid,
		COMMANDER_OUTCOME_RESOURCE_SECURED
	)
	var message = "%s seizes %s." % [_raid_name(updated_raid), String(site.get("name", "the site"))]
	if not spoils.is_empty():
		message = "%s seizes %s and strips %s." % [
			_raid_name(updated_raid),
			String(site.get("name", "the site")),
			_describe_resource_set(spoils),
		]
	if delivery_value > 0:
		message = "%s The convoy bound for %s is scattered." % [message.trim_suffix("."), delivery_target_label]
	elif escorted_route:
		message = "%s seizes %s and breaks its escorted logistics route." % [
			_raid_name(updated_raid),
			String(site.get("name", "the site")),
		]
	elif _resource_site_is_persistent(site):
		message = "%s seizes %s and denies its logistics route." % [
			_raid_name(updated_raid),
			String(site.get("name", "the site")),
		]
	var disruption_message: String = OverworldRulesScript.apply_resource_site_disruption(
		session,
		previous_node,
		site,
		previous_controller,
		faction_id
	)
	if disruption_message != "":
		message = "%s %s" % [message, disruption_message]
	var seized_codes := ["site_seized"]
	seized_codes.append_array(
		_resource_target_reason_codes(
			site,
			previous_controller == "player",
			_resource_site_is_persistent(site),
			_target_resource_value(site.get("control_income", {})),
			_recruit_payload_value(site.get("claim_recruits", {})) + _recruit_payload_value(site.get("weekly_recruits", {})),
			_resource_route_pressure_value(site),
			_linked_player_town_bonus(session, previous_node)
		)
	)
	var event := build_ai_event_record(
		session,
		{"faction_id": faction_id, "label": String(ContentService.get_faction(faction_id).get("name", faction_id))},
		"ai_site_seized",
		updated_raid,
		{
			"target_kind": "resource",
			"target_placement_id": String(updated_raid.get("target_placement_id", "")),
			"target_label": String(site.get("name", "the site")),
			"target_x": int(node.get("x", 0)),
			"target_y": int(node.get("y", 0)),
			"target_reason_codes": seized_codes,
			"target_public_reason": _public_reason_from_codes(seized_codes),
			"target_public_importance": "high" if previous_controller == "player" or _resource_site_is_persistent(site) else "medium",
			"target_debug_reason": String(updated_raid.get("target_debug_reason", "")),
		},
		{
			"summary": message,
			"state_policy": "durable_state_reference",
		}
	)
	_ai_hero_task_finish_live_assignment(session, faction_id, updated_raid, "completed", "valid")
	return {"encounter": updated_raid, "state": state, "event_message": message, "ai_event": event}

static func _defend_resource_target(
	session: SessionStateStoreScript.SessionData,
	raid: Dictionary,
	state: Dictionary,
	faction_id: String
) -> Dictionary:
	var node_result = _find_resource_by_placement(session, String(raid.get("target_placement_id", "")))
	var node = node_result.get("node", {})
	if int(node_result.get("index", -1)) < 0:
		return {"encounter": raid, "state": state, "event_message": ""}
	var site = ContentService.get_resource_site(String(node.get("site_id", "")))
	var reason_codes := _normalize_string_array(raid.get("target_reason_codes", []))
	if not _resource_node_defensible_by_faction(node, site, faction_id, reason_codes):
		return {"encounter": raid, "state": state, "event_message": ""}
	var nodes = session.overworld.get("resource_nodes", [])
	var front: Dictionary = node.get("front", {}) if node.get("front", {}) is Dictionary else {}
	front["state"] = "defend"
	front["faction_id"] = faction_id
	front["last_defended_day"] = int(session.day)
	front["defense_until_day"] = max(int(front.get("defense_until_day", 0)), int(session.day) + 2)
	front["source"] = "strategic_ai_resource_defense"
	node["front"] = front
	node["ai_defended_by_faction_id"] = faction_id
	node["ai_defended_day"] = int(session.day)
	node["ai_defense_until_day"] = max(int(node.get("ai_defense_until_day", 0)), int(session.day) + 2)
	node["ai_defense_rating"] = max(int(node.get("ai_defense_rating", 0)), raid_strength(raid))
	nodes[int(node_result.get("index", -1))] = node
	session.overworld["resource_nodes"] = nodes
	state["pressure"] = max(0, int(state.get("pressure", 0))) + 1
	var updated_raid := _record_adventure_objective_success(
		session,
		faction_id,
		raid,
		COMMANDER_OUTCOME_SITE_DEFENDED
	)
	var defended_codes := ["site_defense", "defend_front", "front_stabilization"]
	var site_label := String(site.get("name", "the site"))
	var message := "%s digs in around %s." % [_raid_name(updated_raid), site_label]
	var event := build_ai_event_record(
		session,
		{"faction_id": faction_id, "label": String(ContentService.get_faction(faction_id).get("name", faction_id))},
		"ai_site_defended",
		updated_raid,
		{
			"target_kind": "resource",
			"target_placement_id": String(updated_raid.get("target_placement_id", "")),
			"target_label": site_label,
			"target_x": int(node.get("x", 0)),
			"target_y": int(node.get("y", 0)),
			"target_reason_codes": defended_codes,
			"target_public_reason": _public_reason_from_codes(defended_codes),
			"target_public_importance": "medium",
			"target_debug_reason": String(updated_raid.get("target_debug_reason", "")),
		},
		{
			"summary": message,
			"state_policy": "durable_state_reference",
		}
	)
	return {"encounter": updated_raid, "state": state, "event_message": message, "ai_event": event}

static func _secure_neutral_town_target(
	session: SessionStateStoreScript.SessionData,
	raid: Dictionary,
	state: Dictionary,
	faction_id: String
) -> Dictionary:
	var town_result := _find_town_by_placement(session, String(raid.get("target_placement_id", "")))
	var town: Dictionary = town_result.get("town", {})
	if int(town_result.get("index", -1)) < 0 or town.is_empty():
		return {"encounter": raid, "state": state, "event_message": ""}
	if String(town.get("owner", "neutral")) != "neutral" or _town_garrison_strength(town) > 0:
		return {"encounter": raid, "state": state, "event_message": ""}
	var transition: Dictionary = OverworldRulesScript.transition_town_control(
		session,
		String(town.get("placement_id", "")),
		"enemy",
		faction_id,
		"strategic_ai_neutral_town_expansion"
	)
	if not bool(transition.get("ok", false)):
		return {"encounter": raid, "state": state, "event_message": ""}
	var captured_town: Dictionary = transition.get("town", town) if transition.get("town", town) is Dictionary else town
	state["pressure"] = max(0, int(state.get("pressure", 0))) + 2
	var updated_raid := _record_adventure_objective_success(
		session,
		faction_id,
		raid,
		COMMANDER_OUTCOME_TOWN_CAPTURED
	)
	var reason_codes := ["town_expansion", "neutral_town_claim"]
	var town_label := _town_name(captured_town)
	var message := "%s claims %s for %s." % [
		_raid_name(updated_raid),
		town_label,
		String(ContentService.get_faction(faction_id).get("name", faction_id)),
	]
	var event := build_ai_event_record(
		session,
		{"faction_id": faction_id, "label": String(ContentService.get_faction(faction_id).get("name", faction_id))},
		"ai_town_captured",
		updated_raid,
		{
			"target_kind": "town",
			"target_placement_id": String(captured_town.get("placement_id", "")),
			"target_label": town_label,
			"target_x": int(captured_town.get("x", 0)),
			"target_y": int(captured_town.get("y", 0)),
			"target_reason_codes": reason_codes,
			"target_public_reason": _public_reason_from_codes(reason_codes),
			"target_public_importance": "high",
			"target_debug_reason": "empty neutral town captured into enemy economy",
		},
		{
			"summary": message,
			"state_policy": "durable_state_reference",
		}
	)
	_ai_hero_task_finish_live_assignment(session, faction_id, updated_raid, "completed", "valid")
	return {"encounter": updated_raid, "state": state, "event_message": message, "ai_event": event}

static func _defend_town_target(
	session: SessionStateStoreScript.SessionData,
	raid: Dictionary,
	state: Dictionary,
	faction_id: String
) -> Dictionary:
	var town_result := _find_town_by_placement(session, String(raid.get("target_placement_id", "")))
	var town: Dictionary = town_result.get("town", {})
	var town_index := int(town_result.get("index", -1))
	if town_index < 0 or town.is_empty():
		return {"encounter": raid, "state": state, "event_message": ""}
	if String(town.get("owner", "neutral")) != "enemy" or _town_faction_id(town) != faction_id:
		return {"encounter": raid, "state": state, "event_message": ""}

	var army := _normalize_army_payload(raid.get("enemy_army", {}))
	var garrison: Array = town.get("garrison", []).duplicate(true) if town.get("garrison", []) is Array else []
	var transferred_count := 0
	var transferred_strength := 0
	for stack_value in army.get("stacks", []):
		if not (stack_value is Dictionary):
			continue
		var unit_id := String(stack_value.get("unit_id", ""))
		var count: int = max(0, int(stack_value.get("count", 0)))
		if unit_id == "" or count <= 0:
			continue
		garrison = _add_army_stack(garrison, unit_id, count)
		transferred_count += count
		transferred_strength += _unit_strength_value(unit_id) * count

	var front: Dictionary = town.get("front", {}) if town.get("front", {}) is Dictionary else {}
	front["state"] = "defend"
	front["faction_id"] = faction_id
	front["last_defended_day"] = int(session.day)
	front["defense_until_day"] = max(int(front.get("defense_until_day", 0)), int(session.day) + 3)
	front["stabilize_until_day"] = max(int(front.get("stabilize_until_day", 0)), int(session.day) + 3)
	front["source"] = "strategic_ai_town_defense_arrival"
	town["front"] = front
	town["garrison"] = garrison
	town["ai_defended_by_faction_id"] = faction_id
	town["ai_defended_day"] = int(session.day)
	town["ai_defense_until_day"] = max(int(town.get("ai_defense_until_day", 0)), int(session.day) + 3)
	town["ai_defense_rating"] = max(int(town.get("ai_defense_rating", 0)), _army_strength(garrison))
	town["ai_defense_reinforced_strength"] = max(0, int(town.get("ai_defense_reinforced_strength", 0))) + transferred_strength

	var updated_raid := raid.duplicate(true)
	var commander_state = updated_raid.get("enemy_commander_state", {})
	if commander_state is Dictionary and not commander_state.is_empty():
		commander_state = advance_commander_record(commander_state, COMMANDER_OUTCOME_TOWN_DEFENDED)
		var stationed_commander := sync_commander_army_continuity(
			commander_state,
			{"stacks": garrison},
			"town_defense:%s" % String(town.get("placement_id", ""))
		)
		town["ai_defender_commander_state"] = stationed_commander
		town["ai_defender_roster_hero_id"] = String(stationed_commander.get("roster_hero_id", ""))
		updated_raid["enemy_commander_state"] = stationed_commander
		sync_commander_state_to_roster(
			session,
			faction_id,
			stationed_commander,
			COMMANDER_STATUS_ACTIVE,
			"town_defense:%s" % String(town.get("placement_id", "")),
			-1,
			COMMANDER_OUTCOME_TOWN_DEFENDED
		)

	var towns = session.overworld.get("towns", [])
	towns[town_index] = town
	session.overworld["towns"] = towns

	updated_raid["enemy_army"] = {
		"id": String(army.get("id", updated_raid.get("encounter_id", "town_defense_host"))),
		"name": String(army.get("name", "Town Defense Host")),
		"stacks": [],
	}
	updated_raid["arrived"] = true
	updated_raid["town_defended_day"] = int(session.day)
	updated_raid["town_defended_strength"] = transferred_strength
	var resolved = session.overworld.get("resolved_encounters", [])
	if not (resolved is Array):
		resolved = []
	var placement_id := String(updated_raid.get("placement_id", ""))
	if placement_id != "" and placement_id not in resolved:
		resolved.append(placement_id)
		session.overworld["resolved_encounters"] = resolved

	state["pressure"] = max(0, int(state.get("pressure", 0))) + max(1, int(ceili(float(max(1, transferred_strength)) / 220.0)))
	_ai_hero_task_finish_live_assignment(session, faction_id, updated_raid, "completed", "valid")
	var defended_codes := ["town_defense", "front_stabilization", "garrison_reinforced"]
	var town_label := _town_name(town)
	var message := "%s reaches %s and folds %d unit%s into the defense." % [
		_raid_name(updated_raid),
		town_label,
		transferred_count,
		"" if transferred_count == 1 else "s",
	]
	var event := build_ai_event_record(
		session,
		{"faction_id": faction_id, "label": String(ContentService.get_faction(faction_id).get("name", faction_id))},
		"ai_town_defended",
		updated_raid,
		{
			"target_kind": "town",
			"target_placement_id": String(town.get("placement_id", "")),
			"target_label": town_label,
			"target_x": int(town.get("x", 0)),
			"target_y": int(town.get("y", 0)),
			"target_reason_codes": defended_codes,
			"target_public_reason": _public_reason_from_codes(defended_codes),
			"target_public_importance": "high",
			"target_debug_reason": String(raid.get("target_debug_reason", "")),
		},
		{
			"summary": message,
			"state_policy": "durable_state_reference",
		}
	)
	return {"encounter": updated_raid, "state": state, "event_message": message, "ai_event": event}

static func _secure_artifact_target(
	session: SessionStateStoreScript.SessionData,
	raid: Dictionary,
	state: Dictionary,
	faction_id: String
) -> Dictionary:
	var node_result = _find_artifact_by_placement(session, String(raid.get("target_placement_id", "")))
	var node = node_result.get("node", {})
	if int(node_result.get("index", -1)) < 0 or bool(node.get("collected", false)):
		return {"encounter": raid, "state": state, "event_message": ""}
	var nodes = session.overworld.get("artifact_nodes", [])
	node["collected"] = true
	node["collected_by_faction_id"] = faction_id
	node["collected_day"] = session.day
	nodes[int(node_result.get("index", -1))] = node
	session.overworld["artifact_nodes"] = nodes

	var captured_artifacts = []
	if state.get("captured_artifact_ids", []) is Array:
		for artifact_id_value in state.get("captured_artifact_ids", []):
			var artifact_id = String(artifact_id_value)
			if artifact_id != "" and artifact_id not in captured_artifacts:
				captured_artifacts.append(artifact_id)
	var claimed_artifact_id = String(node.get("artifact_id", ""))
	if claimed_artifact_id != "" and claimed_artifact_id not in captured_artifacts:
		captured_artifacts.append(claimed_artifact_id)
	state["captured_artifact_ids"] = captured_artifacts
	state["pressure"] = max(0, int(state.get("pressure", 0))) + _artifact_pressure_value(claimed_artifact_id)
	var updated_raid := raid.duplicate(true)
	var claim_result := {}
	var artifact_bonus_report := {}
	if claimed_artifact_id != "":
		var commander_state = updated_raid.get("enemy_commander_state", {})
		if commander_state is Dictionary and not commander_state.is_empty():
			claim_result = ArtifactRulesScript.claim_artifact(
				commander_state,
				claimed_artifact_id,
				"Secured",
				true
			)
			if bool(claim_result.get("ok", false)):
				var updated_commander: Dictionary = claim_result.get("hero", commander_state)
				updated_raid["enemy_commander_state"] = updated_commander
				artifact_bonus_report = ArtifactRulesScript.artifact_equip_runtime_report(updated_commander)
	updated_raid = _record_adventure_objective_success(
		session,
		faction_id,
		updated_raid,
		COMMANDER_OUTCOME_ARTIFACT_SECURED
	)
	var progressed_commander = updated_raid.get("enemy_commander_state", {})
	if progressed_commander is Dictionary and not progressed_commander.is_empty():
		artifact_bonus_report = ArtifactRulesScript.artifact_equip_runtime_report(progressed_commander)
	_ai_hero_task_finish_live_assignment(session, faction_id, updated_raid, "completed", "valid")
	var secured_message := "%s secures %s for the warhost." % [
		_raid_name(updated_raid),
		ArtifactRulesScript.describe_artifact(claimed_artifact_id),
	]
	if bool(claim_result.get("ok", false)) and bool(claim_result.get("auto_equipped", false)):
		secured_message = "%s %s equips it immediately." % [
			secured_message,
			raid_commander_display_name(updated_raid),
		]
	var reason_codes := _normalize_string_array(raid.get("target_reason_codes", []))
	if "artifact_secured" not in reason_codes:
		reason_codes.push_front("artifact_secured")
	var event := build_ai_event_record(
		session,
		{"faction_id": faction_id, "label": String(ContentService.get_faction(faction_id).get("name", faction_id))},
		"ai_artifact_secured",
		updated_raid,
		{
			"target_kind": "artifact",
			"target_placement_id": String(raid.get("target_placement_id", "")),
			"target_label": ArtifactRulesScript.describe_artifact(claimed_artifact_id),
			"target_x": int(node.get("x", 0)),
			"target_y": int(node.get("y", 0)),
			"target_reason_codes": reason_codes,
			"target_public_reason": _public_reason_from_codes(reason_codes),
			"target_public_importance": String(raid.get("target_public_importance", "high")),
			"target_debug_reason": String(raid.get("target_debug_reason", "")),
		},
		{
			"summary": secured_message,
			"state_policy": "durable_state_reference",
		}
	)
	return {
		"encounter": updated_raid,
		"state": state,
		"event_message": secured_message,
		"ai_event": event,
		"artifact_claim": claim_result,
		"artifact_bonus_report": artifact_bonus_report,
	}

static func _contest_encounter_target(
	session: SessionStateStoreScript.SessionData,
	raid: Dictionary,
	state: Dictionary,
	faction_id: String,
	config: Dictionary = {}
) -> Dictionary:
	var encounter_result = _find_encounter_by_placement(session, String(raid.get("target_placement_id", "")))
	var encounter_state = encounter_result.get("encounter", {})
	if int(encounter_result.get("index", -1)) < 0 or OverworldRulesScript.is_encounter_resolved(session, encounter_state):
		return {"encounter": raid, "state": state, "event_message": ""}
	if _encounter_is_objective_anchor(session, encounter_state):
		var encounters = session.overworld.get("encounters", [])
		var claimed_now = String(encounter_state.get("contested_by_faction_id", "")) != faction_id
		encounter_state["contested_by_faction_id"] = faction_id
		encounter_state["contested_day"] = session.day
		encounters[int(encounter_result.get("index", -1))] = encounter_state
		session.overworld["encounters"] = encounters
		if claimed_now:
			state["pressure"] = max(0, int(state.get("pressure", 0))) + 1
			var updated_raid := _record_adventure_objective_success(
				session,
				faction_id,
				raid,
				COMMANDER_OUTCOME_OBJECTIVE_SECURED
			)
			_ai_hero_task_finish_live_assignment(session, faction_id, updated_raid, "completed", "valid")
			var contest_message := "%s locks down %s and turns it into a live front." % [
				_raid_name(updated_raid),
				String(ContentService.get_encounter(String(encounter_state.get("encounter_id", encounter_state.get("id", "")))).get("name", "the outpost")),
			]
			var contest_event := build_ai_event_record(
				session,
				{"faction_id": faction_id, "label": String(ContentService.get_faction(faction_id).get("name", faction_id))},
				"ai_site_contested",
				updated_raid,
				{
					"target_kind": "encounter",
					"target_placement_id": String(encounter_state.get("placement_id", "")),
					"target_label": String(ContentService.get_encounter(String(encounter_state.get("encounter_id", encounter_state.get("id", "")))).get("name", "the outpost")),
					"target_x": int(encounter_state.get("x", 0)),
					"target_y": int(encounter_state.get("y", 0)),
					"target_reason_codes": ["site_contested", "objective_front"],
					"target_public_reason": "objective front",
					"target_public_importance": "high",
					"target_debug_reason": "objective encounter contested",
				},
				{
					"summary": contest_message,
					"state_policy": "durable_state_reference",
				}
			)
			return {
				"encounter": updated_raid,
				"state": state,
				"event_message": contest_message,
				"ai_event": contest_event,
			}
		return {"encounter": raid, "state": state, "event_message": ""}

	var resolved = session.overworld.get("resolved_encounters", [])
	var placement_id = String(encounter_state.get("placement_id", ""))
	if resolved is Array and placement_id not in resolved:
		resolved.append(placement_id)
		session.overworld["resolved_encounters"] = resolved
	var resolved_raid := _record_adventure_objective_success(
		session,
		faction_id,
		raid,
		COMMANDER_OUTCOME_OBJECTIVE_SECURED
	)
	_ai_hero_task_finish_live_assignment(session, faction_id, resolved_raid, "completed", "valid")
	var encounter_template = ContentService.get_encounter(String(encounter_state.get("encounter_id", encounter_state.get("id", ""))))
	var spoils = _reward_resources_for_empire(encounter_template.get("rewards", {}))
	state["treasury"] = _merge_resources(state.get("treasury", {}), spoils)
	state["pressure"] = max(0, int(state.get("pressure", 0))) + _pressure_from_rewards(encounter_template.get("rewards", {}))
	var message = "%s breaks %s." % [_raid_name(resolved_raid), String(encounter_template.get("name", "the frontier camp"))]
	if not spoils.is_empty():
		message = "%s breaks %s and absorbs %s." % [
			_raid_name(resolved_raid),
			String(encounter_template.get("name", "the frontier camp")),
			_describe_resource_set(spoils),
		]
	var resume_result := _resume_guarded_claim_after_guard_clear(session, config, resolved_raid, state, faction_id)
	if bool(resume_result.get("resumed", false)):
		return {
			"encounter": resume_result.get("encounter", resolved_raid),
			"state": resume_result.get("state", state),
			"event_message": message,
			"ai_event": resume_result.get("ai_event", {}),
			"guarded_claim_resumed": true,
		}
	var reason_codes := _normalize_string_array(raid.get("target_reason_codes", []))
	if "site_contested" not in reason_codes:
		reason_codes.push_front("site_contested")
	var event := build_ai_event_record(
		session,
		{"faction_id": faction_id, "label": String(ContentService.get_faction(faction_id).get("name", faction_id))},
		"ai_site_contested",
		resolved_raid,
		{
			"target_kind": "encounter",
			"target_placement_id": placement_id,
			"target_label": String(encounter_template.get("name", "the frontier camp")),
			"target_x": int(encounter_state.get("x", 0)),
			"target_y": int(encounter_state.get("y", 0)),
			"target_reason_codes": reason_codes,
			"target_public_reason": _public_reason_from_codes(reason_codes),
			"target_public_importance": String(raid.get("target_public_importance", "medium")),
			"target_debug_reason": String(raid.get("target_debug_reason", "")),
		},
		{
			"summary": message,
			"state_policy": "durable_state_reference",
		}
	)
	return {"encounter": resolved_raid, "state": state, "event_message": message, "ai_event": event}

static func _resume_guarded_claim_after_guard_clear(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	raid: Dictionary,
	state: Dictionary,
	faction_id: String
) -> Dictionary:
	var resume_target := _guarded_claim_resume_target(session, raid, faction_id)
	if resume_target.is_empty():
		return {"resumed": false, "encounter": raid, "state": state}
	var previous_target := _current_target_snapshot(raid)
	var resumed := raid.duplicate(true)
	resumed.merge(resume_target, true)
	resumed.erase("guarded_claim_kind")
	resumed.erase("guarded_claim_target_id")
	resumed.erase("guarded_claim_target_label")
	resumed["arrived"] = false
	resumed["guarded_claim_resumed_day"] = int(session.day)
	resumed = _refresh_target(session, resumed)
	var retask_event := ai_target_assignment_event(session, config, resumed, previous_target)
	if retask_event.is_empty():
		retask_event = ai_target_assignment_event(session, config, resumed, {})
	return {
		"resumed": true,
		"encounter": resumed,
		"state": state,
		"ai_event": retask_event,
	}

static func _guarded_claim_resume_target(
	session: SessionStateStoreScript.SessionData,
	raid: Dictionary,
	faction_id: String
) -> Dictionary:
	if session == null or raid.is_empty() or faction_id == "":
		return {}
	var claim_kind := String(raid.get("guarded_claim_kind", ""))
	var target_id := String(raid.get("guarded_claim_target_id", ""))
	if claim_kind == "" or target_id == "":
		return {}
	match claim_kind:
		"resource":
			var node_result := _find_resource_by_placement(session, target_id)
			if int(node_result.get("index", -1)) < 0:
				return {}
			var node: Dictionary = node_result.get("node", {})
			var site := ContentService.get_resource_site(String(node.get("site_id", "")))
			if not _resource_guard_encounter_for_node(session, node, site).is_empty():
				return {}
			if not _resource_node_contestable_by_faction(node, site, faction_id):
				return {}
			var tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
			return {
				"target_kind": "resource",
				"target_placement_id": target_id,
				"target_label": String(site.get("name", "Resource Site")),
				"target_x": tile.x,
				"target_y": tile.y,
				"goal_x": tile.x,
				"goal_y": tile.y,
				"target_reason_codes": ["guard_cleared", "guarded_resource_claim", "site_contested"],
				"target_public_reason": "claiming guarded prize",
				"target_public_importance": "high",
				"target_debug_reason": "guard cleared; resuming guarded resource claim",
			}
		"artifact":
			var artifact_result := _find_artifact_by_placement(session, target_id)
			if int(artifact_result.get("index", -1)) < 0:
				return {}
			var node: Dictionary = artifact_result.get("node", {})
			if bool(node.get("collected", false)):
				return {}
			if not _artifact_guard_encounter_for_node(session, node).is_empty():
				return {}
			var tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
			return {
				"target_kind": "artifact",
				"target_placement_id": target_id,
				"target_label": ArtifactRulesScript.describe_artifact(String(node.get("artifact_id", ""))),
				"target_x": tile.x,
				"target_y": tile.y,
				"goal_x": tile.x,
				"goal_y": tile.y,
				"target_reason_codes": ["guard_cleared", "guarded_artifact_claim", "artifact_pressure"],
				"target_public_reason": "claiming guarded prize",
				"target_public_importance": "high",
				"target_debug_reason": "guard cleared; resuming guarded artifact claim",
			}
	return {}

static func _regroup_raid_at_town(
	session: SessionStateStoreScript.SessionData,
	raid: Dictionary,
	state: Dictionary,
	faction_id: String
) -> Dictionary:
	var town_result = _find_town_by_placement(session, String(raid.get("target_placement_id", "")))
	var town = town_result.get("town", {})
	var town_index := int(town_result.get("index", -1))
	if town_index < 0 or town.is_empty():
		return {"encounter": raid, "state": state, "event_message": ""}
	if String(town.get("owner", "neutral")) != "enemy" or _town_faction_id(town) != faction_id:
		return {"encounter": raid, "state": state, "event_message": ""}

	var before_strength := raid_strength(raid)
	var desired_strength := desired_raid_strength(raid)
	var transfer_report := _transfer_town_garrison_to_raid(session, town_index, raid, max(0, desired_strength - before_strength))
	raid = transfer_report.get("raid", raid)
	var transferred_count := int(transfer_report.get("transferred_count", 0))
	var transferred_strength := int(transfer_report.get("transferred_strength", 0))
	var after_strength := raid_strength(raid)
	raid["regrouped_day"] = int(session.day)
	raid["last_regroup_town_id"] = String(town.get("placement_id", ""))
	raid["last_regroup_strength_delta"] = transferred_strength

	var ready_to_resume := not raid_regroup_needed(raid)
	if ready_to_resume:
		_ai_hero_task_finish_live_assignment(session, faction_id, raid, "completed", "valid")
		raid = _clear_regroup_target(raid)
	elif transferred_count <= 0:
		_ai_hero_task_finish_live_assignment(session, faction_id, raid, "suspended", "invalid_actor_rebuilding")
		raid = _retire_failed_regroup_to_rebuild(session, raid, faction_id, town)

	var message := ""
	if transferred_count > 0:
		message = "%s regroups at %s and folds %d unit%s into the host." % [
			_raid_name(raid),
			_town_name(town),
			transferred_count,
			"" if transferred_count == 1 else "s",
		]
	elif bool(raid.get("raid_retired_to_rebuild", false)):
		message = "%s reaches %s with no spare garrison and falls back into command rebuild." % [
			_raid_name(raid),
			_town_name(town),
		]
	else:
		message = "%s regroups at %s but finds no spare garrison." % [_raid_name(raid), _town_name(town)]
	var event := build_ai_event_record(
		session,
		{"faction_id": faction_id, "label": String(ContentService.get_faction(faction_id).get("name", faction_id))},
		"ai_raid_regrouped",
		raid,
		{
			"target_kind": "town",
			"target_placement_id": String(town.get("placement_id", "")),
			"target_label": _town_name(town),
			"target_x": int(town.get("x", 0)),
			"target_y": int(town.get("y", 0)),
			"target_reason_codes": ["regroup_understrength", "army_consolidation", "town_defense"],
			"target_public_reason": "regrouping understrength host",
			"target_public_importance": "high",
		},
		{
			"summary": message,
			"state_policy": "durable_state_reference",
		}
	)
	return {"encounter": raid, "state": state, "event_message": message, "ai_event": event}

static func _retire_failed_regroup_to_rebuild(
	session: SessionStateStoreScript.SessionData,
	raid: Dictionary,
	faction_id: String,
	town: Dictionary
) -> Dictionary:
	var retired := raid.duplicate(true)
	retired["regroup_blocked_day"] = int(session.day)
	retired["regroup_blocked_reason"] = "no_spare_garrison"
	retired["regroup_failed_count"] = max(0, int(retired.get("regroup_failed_count", 0))) + 1
	retired["raid_retired_to_rebuild"] = true
	retired["retired_to_rebuild_day"] = int(session.day)
	retired["retired_to_rebuild_town_id"] = String(town.get("placement_id", ""))
	var commander_state = retired.get("enemy_commander_state", {})
	if commander_state is Dictionary and not commander_state.is_empty():
		var updated_commander := sync_commander_army_continuity(
			commander_state,
			retired.get("enemy_army", {}),
			String(retired.get("encounter_id", retired.get("id", "")))
		)
		retired["enemy_commander_state"] = updated_commander
		sync_commander_state_to_roster(
			session,
			faction_id,
			updated_commander,
			COMMANDER_STATUS_AVAILABLE,
			"",
			0,
			String(updated_commander.get("last_outcome", ""))
		)
	var resolved = session.overworld.get("resolved_encounters", [])
	if not (resolved is Array):
		resolved = []
	var placement_id := String(retired.get("placement_id", ""))
	if placement_id != "" and placement_id not in resolved:
		resolved.append(placement_id)
		session.overworld["resolved_encounters"] = resolved
	retired = _clear_regroup_target(retired)
	retired["arrived"] = false
	return retired

static func _transfer_town_garrison_to_raid(
	session: SessionStateStoreScript.SessionData,
	town_index: int,
	raid: Dictionary,
	strength_needed: int
) -> Dictionary:
	if town_index < 0 or strength_needed <= 0:
		return {"raid": raid, "transferred_count": 0, "transferred_strength": 0}
	var towns = session.overworld.get("towns", [])
	if town_index >= towns.size() or not (towns[town_index] is Dictionary):
		return {"raid": raid, "transferred_count": 0, "transferred_strength": 0}
	var town: Dictionary = towns[town_index]
	var garrison_value = town.get("garrison", [])
	if not (garrison_value is Array):
		return {"raid": raid, "transferred_count": 0, "transferred_strength": 0}
	var garrison: Array = garrison_value
	var army: Dictionary = _normalize_army_payload(raid.get("enemy_army", {}))
	if army.is_empty():
		army = _base_enemy_army(String(raid.get("encounter_id", raid.get("id", ""))))
	if army.is_empty():
		army = {"id": String(raid.get("encounter_id", "raid")), "name": "Raid Host", "stacks": []}

	var remaining_strength: int = max(0, strength_needed)
	var transferred_count := 0
	var transferred_strength := 0
	var new_garrison: Array = []
	for stack_value in garrison:
		if not (stack_value is Dictionary):
			continue
		var unit_id := String(stack_value.get("unit_id", ""))
		var count: int = max(0, int(stack_value.get("count", 0)))
		if unit_id == "" or count <= 0:
			continue
		var unit_strength: int = max(1, _unit_strength_value(unit_id))
		var take := 0
		if remaining_strength > 0:
			take = mini(count, max(1, int(ceil(float(remaining_strength) / float(unit_strength)))))
		if take > 0:
			army["stacks"] = _add_army_stack(army.get("stacks", []), unit_id, take)
			transferred_count += take
			var strength_delta: int = unit_strength * take
			transferred_strength += strength_delta
			remaining_strength = max(0, remaining_strength - strength_delta)
		var left: int = count - take
		if left > 0:
			new_garrison.append({"unit_id": unit_id, "count": left})
	town["garrison"] = new_garrison
	towns[town_index] = town
	session.overworld["towns"] = towns
	raid["enemy_army"] = army
	var commander_state = raid.get("enemy_commander_state", {})
	if commander_state is Dictionary and not commander_state.is_empty():
		raid["enemy_commander_state"] = sync_commander_army_continuity(
			commander_state,
			army,
			String(raid.get("encounter_id", raid.get("id", "")))
		)
	return {
		"raid": raid,
		"transferred_count": transferred_count,
		"transferred_strength": transferred_strength,
	}

static func _clear_regroup_target(raid: Dictionary) -> Dictionary:
	raid["target_kind"] = ""
	raid["target_placement_id"] = ""
	raid["target_label"] = ""
	raid["target_x"] = int(raid.get("x", 0))
	raid["target_y"] = int(raid.get("y", 0))
	raid["goal_x"] = int(raid.get("x", 0))
	raid["goal_y"] = int(raid.get("y", 0))
	raid["goal_distance"] = 9999
	raid["arrived"] = false
	raid["target_public_reason"] = ""
	raid["target_reason_codes"] = []
	raid["target_public_importance"] = ""
	raid["target_debug_reason"] = ""
	return raid

static func _reward_resources_for_empire(rewards: Variant) -> Dictionary:
	var treasury = {}
	if not (rewards is Dictionary):
		return treasury
	for key in ["gold", "wood", "ore"]:
		var amount: int = max(0, int(rewards.get(key, 0)))
		if amount > 0:
			treasury[key] = amount
	return treasury

static func _pressure_from_rewards(rewards: Variant) -> int:
	if not (rewards is Dictionary):
		return 0
	var pressure = 0
	pressure += int(floor(float(_target_resource_value(_reward_resources_for_empire(rewards))) / 400.0))
	var experience: int = max(0, int(rewards.get("experience", 0)))
	if experience > 0:
		pressure += max(1, int(floor(float(experience) / 180.0)))
	return clamp(pressure, 0, 3)

static func _artifact_pressure_value(artifact_id: String) -> int:
	var artifact = ContentService.get_artifact(artifact_id)
	if artifact.is_empty():
		return 0
	var bonuses = artifact.get("bonuses", {})
	var pressure = 1
	pressure += max(0, int(bonuses.get("overworld_movement", 0)))
	pressure += max(0, int(bonuses.get("scouting_radius", 0)))
	pressure += max(0, int(bonuses.get("battle_initiative", 0)))
	if max(0, int(bonuses.get("battle_attack", 0))) + max(0, int(bonuses.get("battle_defense", 0))) > 0:
		pressure += 1
	if _target_resource_value(bonuses.get("daily_income", {})) >= 300:
		pressure += 1
	return clamp(pressure, 1, 3)

static func _raid_name(raid: Dictionary) -> String:
	var encounter = ContentService.get_encounter(String(raid.get("encounter_id", raid.get("id", ""))))
	return String(encounter.get("name", "The raid"))

static func _goal_tiles_from_raid(session: SessionStateStoreScript.SessionData, raid: Dictionary) -> Array:
	match String(raid.get("target_kind", "")):
		"town":
			var town_result = _find_town_by_placement(session, String(raid.get("target_placement_id", "")))
			if int(town_result.get("index", -1)) >= 0:
				return _town_staging_tiles(session, town_result.get("town", {}))
		"regroup":
			var town_result = _find_town_by_placement(session, String(raid.get("target_placement_id", "")))
			if int(town_result.get("index", -1)) >= 0:
				var town: Dictionary = town_result.get("town", {})
				return [Vector2i(int(town.get("x", 0)), int(town.get("y", 0)))]
		"resource", "artifact":
			return [Vector2i(int(raid.get("target_x", int(raid.get("goal_x", 0)))), int(raid.get("target_y", int(raid.get("goal_y", 0)))))]
		"encounter":
			var encounter_result = _find_encounter_by_placement(session, String(raid.get("target_placement_id", "")))
			if int(encounter_result.get("index", -1)) >= 0:
				return _encounter_staging_tiles(session, encounter_result.get("encounter", {}))
		"hero":
			var hero_position := _hero_position_for_target(session, String(raid.get("target_placement_id", "")))
			return [hero_position]
	return [Vector2i(int(raid.get("goal_x", int(raid.get("x", 0)))), int(raid.get("goal_y", int(raid.get("y", 0)))))]

static func _next_step_toward(session: SessionStateStoreScript.SessionData, start: Vector2i, goal_tiles: Array, ignore_placement_id: String) -> Vector2i:
	if goal_tiles.is_empty():
		return start
	var map_size: Vector2i = OverworldRulesScript.derive_map_size(session)
	var encounter_blocked = _occupied_tiles(session, ignore_placement_id)
	var resource_blocked = _resource_body_blocked_tiles(session, ignore_placement_id)
	var terrain_blocked = _impassable_terrain_tiles(session)
	var goal_lookup := _tile_lookup(goal_tiles)
	var visited = {}
	var queue = [start]
	var parents = {}
	visited[_pos_key(start)] = true
	var found_key = ""

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current in goal_tiles:
			found_key = _pos_key(current)
			break

		for delta in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = current + delta
			var key = _pos_key(next)
			if visited.has(key):
				continue
			if _position_blocked(next, goal_lookup, encounter_blocked, resource_blocked, terrain_blocked, map_size):
				continue
			visited[key] = true
			parents[key] = current
			queue.append(next)

	if found_key == "":
		return start

	var cursor = _vector_from_key(found_key)
	while parents.has(_pos_key(cursor)) and parents[_pos_key(cursor)] != start:
		cursor = parents[_pos_key(cursor)]
	return cursor if cursor != start else start

static func _path_distance(session: SessionStateStoreScript.SessionData, start: Vector2i, goal_tiles: Array, ignore_placement_id: String) -> int:
	if goal_tiles.is_empty():
		return 9999
	if start in goal_tiles:
		return 0
	var map_size: Vector2i = OverworldRulesScript.derive_map_size(session)
	var encounter_blocked = _occupied_tiles(session, ignore_placement_id)
	var resource_blocked = _resource_body_blocked_tiles(session, ignore_placement_id)
	var terrain_blocked = _impassable_terrain_tiles(session)
	var goal_lookup := _tile_lookup(goal_tiles)
	var visited = {}
	var queue = [{"pos": start, "distance": 0}]
	visited[_pos_key(start)] = true

	while not queue.is_empty():
		var current = queue.pop_front()
		var pos: Vector2i = current["pos"]
		var distance = int(current["distance"])
		for delta in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = pos + delta
			var key = _pos_key(next)
			if visited.has(key):
				continue
			if _position_blocked(next, goal_lookup, encounter_blocked, resource_blocked, terrain_blocked, map_size):
				continue
			if next in goal_tiles:
				return distance + 1
			visited[key] = true
			queue.append({"pos": next, "distance": distance + 1})
	return 9999

static func raid_reinforcement_route_distance(
	session: SessionStateStoreScript.SessionData,
	support_town: Dictionary,
	raid: Dictionary
) -> int:
	if session == null or support_town.is_empty() or raid.is_empty():
		return 9999
	var start := Vector2i(int(support_town.get("x", 0)), int(support_town.get("y", 0)))
	var goal := Vector2i(int(raid.get("x", 0)), int(raid.get("y", 0)))
	return _path_distance(session, start, [goal], String(raid.get("placement_id", "")))

static func _tile_lookup(tiles: Array) -> Dictionary:
	var lookup = {}
	for tile in tiles:
		if tile is Vector2i:
			lookup[_pos_key(tile)] = true
	return lookup

static func _occupied_tiles(session: SessionStateStoreScript.SessionData, ignore_placement_id: String) -> Dictionary:
	var occupied = {}
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		var placement_id = String(encounter.get("placement_id", ""))
		if placement_id == ignore_placement_id:
			continue
		if resolved_encounters is Array and placement_id in resolved_encounters:
			continue
		occupied[_pos_key(Vector2i(int(encounter.get("x", 0)), int(encounter.get("y", 0))))] = true
	return occupied

static func _resource_body_blocked_tiles(session: SessionStateStoreScript.SessionData, ignore_placement_id: String) -> Dictionary:
	var blocked = {}
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var placement_id := String(node.get("placement_id", ""))
		if placement_id == "" or placement_id == ignore_placement_id:
			continue
		var surface: Dictionary = OverworldRulesScript.overworld_object_placement_pathing_surface(session, placement_id)
		if surface.is_empty() or not bool(surface.get("blocks_body_tiles", false)):
			continue
		for tile_value in surface.get("body_tiles", []):
			if tile_value is Dictionary:
				blocked[_pos_key(Vector2i(int(tile_value.get("x", 0)), int(tile_value.get("y", 0))))] = true
	return blocked

static func _impassable_terrain_tiles(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var blocked = {}
	var map_data = session.overworld.get("map", [])
	if not (map_data is Array):
		return blocked
	for y in range(map_data.size()):
		var row = map_data[y]
		if not (row is Array):
			continue
		for x in range(row.size()):
			var terrain_id := String(row[x])
			var impassable: bool = not OverworldRulesScript.terrain_id_is_passable(terrain_id)
			if impassable:
				blocked[_pos_key(Vector2i(x, y))] = true
	return blocked

static func _position_blocked(
	pos: Vector2i,
	goal_lookup: Dictionary,
	encounter_blocked: Dictionary,
	resource_blocked: Dictionary,
	terrain_blocked: Dictionary,
	map_size: Vector2i
) -> bool:
	if pos.x < 0 or pos.y < 0 or pos.x >= map_size.x or pos.y >= map_size.y:
		return true
	var key := _pos_key(pos)
	if goal_lookup.has(key):
		return encounter_blocked.has(key)
	if terrain_blocked.has(key):
		return true
	return encounter_blocked.has(key) or resource_blocked.has(key)

static func _refresh_target(session: SessionStateStoreScript.SessionData, raid: Dictionary) -> Dictionary:
	var origin = Vector2i(int(raid.get("x", 0)), int(raid.get("y", 0)))
	match String(raid.get("target_kind", "")):
		"town":
			var town_result = _find_town_by_placement(session, String(raid.get("target_placement_id", "")))
			if int(town_result.get("index", -1)) >= 0:
				var town = town_result.get("town", {})
				var staging_tiles = _town_staging_tiles(session, town)
				var goal_tile = _best_goal_tile(session, origin, staging_tiles)
				raid["target_label"] = _town_name(town)
				raid["target_x"] = int(town.get("x", 0))
				raid["target_y"] = int(town.get("y", 0))
				raid["goal_x"] = goal_tile.x
				raid["goal_y"] = goal_tile.y
				raid["goal_distance"] = _path_distance(session, origin, staging_tiles, String(raid.get("placement_id", "")))
		"regroup":
			var town_result = _find_town_by_placement(session, String(raid.get("target_placement_id", "")))
			if int(town_result.get("index", -1)) >= 0:
				var town = town_result.get("town", {})
				var goal_tile := Vector2i(int(town.get("x", 0)), int(town.get("y", 0)))
				raid["target_label"] = "%s regroup" % _town_name(town)
				raid["target_x"] = int(town.get("x", 0))
				raid["target_y"] = int(town.get("y", 0))
				raid["goal_x"] = goal_tile.x
				raid["goal_y"] = goal_tile.y
				raid["goal_distance"] = _path_distance(session, origin, [goal_tile], String(raid.get("placement_id", "")))
		"resource":
			var resource_result = _find_resource_by_placement(session, String(raid.get("target_placement_id", "")))
			if int(resource_result.get("index", -1)) >= 0:
				var node = resource_result.get("node", {})
				raid["target_label"] = String(ContentService.get_resource_site(String(node.get("site_id", ""))).get("name", "Resource Site"))
				raid["target_x"] = int(node.get("x", 0))
				raid["target_y"] = int(node.get("y", 0))
				raid["goal_x"] = int(node.get("x", 0))
				raid["goal_y"] = int(node.get("y", 0))
				raid["goal_distance"] = _path_distance(session, origin, [Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))], String(raid.get("placement_id", "")))
		"artifact":
			var artifact_result = _find_artifact_by_placement(session, String(raid.get("target_placement_id", "")))
			if int(artifact_result.get("index", -1)) >= 0:
				var node = artifact_result.get("node", {})
				raid["target_label"] = ArtifactRulesScript.describe_artifact(String(node.get("artifact_id", "")))
				raid["target_x"] = int(node.get("x", 0))
				raid["target_y"] = int(node.get("y", 0))
				raid["goal_x"] = int(node.get("x", 0))
				raid["goal_y"] = int(node.get("y", 0))
				raid["goal_distance"] = _path_distance(session, origin, [Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))], String(raid.get("placement_id", "")))
		"encounter":
			var encounter_result = _find_encounter_by_placement(session, String(raid.get("target_placement_id", "")))
			if int(encounter_result.get("index", -1)) >= 0:
				var placement = encounter_result.get("encounter", {})
				var staging_tiles = _encounter_staging_tiles(session, placement)
				var goal_tile = _best_goal_tile(session, origin, staging_tiles)
				raid["target_label"] = String(ContentService.get_encounter(String(placement.get("encounter_id", placement.get("id", "")))).get("name", "Frontier Camp"))
				raid["target_x"] = int(placement.get("x", 0))
				raid["target_y"] = int(placement.get("y", 0))
				raid["goal_x"] = goal_tile.x
				raid["goal_y"] = goal_tile.y
				raid["goal_distance"] = _path_distance(session, origin, staging_tiles, String(raid.get("placement_id", "")))
		"hero":
			var hero_target_id := String(raid.get("target_placement_id", ""))
			var hero_position := _hero_position_for_target(session, hero_target_id)
			raid["target_label"] = _hero_label_for_target(session, hero_target_id)
			raid["target_x"] = hero_position.x
			raid["target_y"] = hero_position.y
			raid["goal_x"] = hero_position.x
			raid["goal_y"] = hero_position.y
			raid["goal_distance"] = _path_distance(
				session,
				origin,
				[hero_position],
				String(raid.get("placement_id", ""))
			)
	if String(raid.get("delivery_intercept_node_placement_id", "")) != "":
		var delivery_context: Dictionary = OverworldRulesScript.delivery_interception_context_for_encounter(session, raid)
		if bool(delivery_context.get("active", false)):
			raid["delivery_intercept_target_kind"] = String(delivery_context.get("target_kind", ""))
			raid["delivery_intercept_target_id"] = String(delivery_context.get("target_id", ""))
			raid["delivery_intercept_label"] = String(delivery_context.get("route_label", raid.get("delivery_intercept_label", "")))
			raid["target_label"] = String(delivery_context.get("pressure_label", raid.get("target_label", "")))
	return raid

static func _raid_target_valid(session: SessionStateStoreScript.SessionData, raid: Dictionary) -> bool:
	var target_kind = String(raid.get("target_kind", ""))
	var valid := false
	match target_kind:
		"town":
			var town_result = _find_town_by_placement(session, String(raid.get("target_placement_id", "")))
			if int(town_result.get("index", -1)) < 0:
				valid = false
			else:
				var town: Dictionary = town_result.get("town", {})
				var reason_codes := _normalize_string_array(raid.get("target_reason_codes", []))
				valid = String(town.get("owner", "neutral")) == "player" or (
					"town_defense" in reason_codes
					and String(town.get("owner", "neutral")) == "enemy"
					and _town_faction_id(town) == String(raid.get("spawned_by_faction_id", ""))
				) or (
					String(town.get("owner", "neutral")) == "neutral"
					and ("town_expansion" in reason_codes or "neutral_town_claim" in reason_codes)
				)
		"regroup":
			var town_result = _find_town_by_placement(session, String(raid.get("target_placement_id", "")))
			valid = (
				int(town_result.get("index", -1)) >= 0
				and String(town_result.get("town", {}).get("owner", "neutral")) == "enemy"
				and _town_faction_id(town_result.get("town", {})) == String(raid.get("spawned_by_faction_id", ""))
			)
		"resource":
			var resource_result = _find_resource_by_placement(session, String(raid.get("target_placement_id", "")))
			if int(resource_result.get("index", -1)) < 0:
				return false
			var node: Dictionary = resource_result.get("node", {})
			var site = ContentService.get_resource_site(String(node.get("site_id", "")))
			var reason_codes := _normalize_string_array(raid.get("target_reason_codes", []))
			var raid_faction := String(raid.get("spawned_by_faction_id", ""))
			valid = (
				_resource_node_contestable_by_faction(node, site, raid_faction)
				or _resource_node_defensible_by_faction(node, site, raid_faction, reason_codes)
			)
		"artifact":
			var artifact_result = _find_artifact_by_placement(session, String(raid.get("target_placement_id", "")))
			valid = int(artifact_result.get("index", -1)) >= 0 and not bool(artifact_result.get("node", {}).get("collected", false))
		"encounter":
			var encounter_result = _find_encounter_by_placement(session, String(raid.get("target_placement_id", "")))
			valid = int(encounter_result.get("index", -1)) >= 0 and not OverworldRulesScript.is_encounter_resolved(session, encounter_result.get("encounter", {}))
		"hero":
			var hero_target_id := String(raid.get("target_placement_id", ""))
			valid = hero_target_id == "" or not _find_player_hero(session, hero_target_id).is_empty()
		_:
			return false
	if not valid:
		return false
	if String(raid.get("delivery_intercept_node_placement_id", "")) != "":
		return bool(OverworldRulesScript.delivery_interception_context_for_encounter(session, raid).get("active", false))
	return true

static func _is_active_raid(encounter: Variant, faction_id: String, resolved_encounters: Variant) -> bool:
	if not (encounter is Dictionary):
		return false
	var raid_faction = String(encounter.get("spawned_by_faction_id", ""))
	if faction_id == "":
		if raid_faction == "":
			return false
	elif raid_faction != faction_id:
		return false
	var placement_id = String(encounter.get("placement_id", ""))
	return not (resolved_encounters is Array and placement_id in resolved_encounters)

static func _find_town_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for index in range(session.overworld.get("towns", []).size()):
		var town = session.overworld.get("towns", [])[index]
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return {"index": index, "town": town}
	return {"index": -1, "town": {}}

static func _find_resource_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for index in range(session.overworld.get("resource_nodes", []).size()):
		var node = session.overworld.get("resource_nodes", [])[index]
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return {"index": index, "node": node}
	return {"index": -1, "node": {}}

static func _guard_link_for_encounter(encounter: Dictionary) -> Dictionary:
	var guard = encounter.get("guard_link", {})
	if guard is Dictionary and not guard.is_empty():
		return guard
	var neutral_metadata = encounter.get("neutral_encounter", {})
	if neutral_metadata is Dictionary:
		guard = neutral_metadata.get("guard_link", {})
		if guard is Dictionary:
			return guard
	return {}

static func _resource_guard_encounter_for_node(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> Dictionary:
	if session == null or node.is_empty():
		return {}
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary) or OverworldRulesScript.is_encounter_resolved(session, encounter_value):
			continue
		var encounter: Dictionary = encounter_value
		var guard := _guard_link_for_encounter(encounter)
		if not guard.is_empty() and _resource_guard_link_targets_node(guard, node, site):
			return encounter
		if _generated_object_guard_targets(encounter, "resource", String(node.get("placement_id", ""))):
			return encounter
	return {}

static func _resource_guard_link_targets_node(guard: Dictionary, node: Dictionary, site: Dictionary) -> bool:
	var role := String(guard.get("guard_role", ""))
	var target_kind := String(guard.get("target_kind", ""))
	if role != "guards_resource_node" and target_kind != "resource_node":
		return false
	if not bool(guard.get("clear_required_for_target", false)) and not bool(guard.get("blocks_approach", false)):
		return false
	var node_placement_id := String(node.get("placement_id", ""))
	var site_id := String(site.get("id", node.get("site_id", "")))
	var target_placement_id := String(guard.get("target_placement_id", ""))
	var target_id := String(guard.get("target_id", ""))
	return (
		(target_placement_id != "" and target_placement_id == node_placement_id)
		or (target_id != "" and target_id in [node_placement_id, site_id])
	)

static func _artifact_guard_encounter_for_node(session: SessionStateStoreScript.SessionData, node: Dictionary) -> Dictionary:
	if session == null or node.is_empty():
		return {}
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary) or OverworldRulesScript.is_encounter_resolved(session, encounter_value):
			continue
		var encounter: Dictionary = encounter_value
		var guard := _guard_link_for_encounter(encounter)
		if not guard.is_empty() and _artifact_guard_link_targets_node(guard, node):
			return encounter
		if _generated_object_guard_targets(encounter, "artifact", String(node.get("placement_id", ""))):
			return encounter
	return {}

static func _artifact_guard_link_targets_node(guard: Dictionary, node: Dictionary) -> bool:
	var role := String(guard.get("guard_role", ""))
	var target_kind := String(guard.get("target_kind", ""))
	if role not in ["guards_reward", "guards_object"] and target_kind not in ["artifact", "artifact_node", "reward", "object"]:
		return false
	if not bool(guard.get("clear_required_for_target", false)) and not bool(guard.get("blocks_approach", false)):
		return false
	var node_placement_id := String(node.get("placement_id", ""))
	var artifact_id := String(node.get("artifact_id", ""))
	var target_placement_id := String(guard.get("target_placement_id", ""))
	var target_id := String(guard.get("target_id", ""))
	return (
		(target_placement_id != "" and target_placement_id == node_placement_id)
		or (target_id != "" and target_id in [node_placement_id, artifact_id])
	)

static func _generated_object_guard_targets(encounter: Dictionary, target_kind: String, target_placement_id: String) -> bool:
	if target_placement_id == "":
		return false
	if String(encounter.get("guarded_object_placement_id", "")) != target_placement_id:
		return false
	var guarded_kind := String(encounter.get("guarded_object_kind", ""))
	if target_kind == "artifact":
		return guarded_kind == "artifact"
	return guarded_kind in ["resource", "resource_site", "mine", "neutral_dwelling", "faction_outpost", "frontier_shrine", "reward_reference", "mine_placeholder"]

static func _resource_site_is_persistent(site: Dictionary) -> bool:
	return bool(site.get("persistent_control", false))

static func _resource_node_contestable_by_faction(node: Dictionary, site: Dictionary, faction_id: String) -> bool:
	if _resource_site_is_persistent(site):
		return String(node.get("collected_by_faction_id", "")) != faction_id
	return not bool(node.get("collected", false))

static func _resource_defense_reason_active(reason_codes: Array) -> bool:
	var codes := _normalize_string_array(reason_codes)
	return "site_defense" in codes or "defend_front" in codes or "front_stabilization" in codes

static func _resource_node_defensible_by_faction(node: Dictionary, site: Dictionary, faction_id: String, reason_codes: Array) -> bool:
	return (
		faction_id != ""
		and _resource_site_is_persistent(site)
		and String(node.get("collected_by_faction_id", "")) == faction_id
		and _resource_defense_reason_active(reason_codes)
	)

static func _resource_site_claim_rewards(site: Dictionary) -> Dictionary:
	var rewards = site.get("claim_rewards", site.get("rewards", {}))
	return rewards if rewards is Dictionary else {}

static func _resource_site_strategic_value(site: Dictionary) -> int:
	var value = _target_resource_value(_resource_site_claim_rewards(site))
	value += _target_resource_value(site.get("control_income", {})) / 2
	value += _recruit_payload_value(site.get("weekly_recruits", {}))
	value += _recruit_payload_value(site.get("claim_recruits", {}))
	value += max(0, int(site.get("vision_radius", 0))) * 140
	value += max(0, int(site.get("pressure_guard", 0))) * 160
	value += max(0, int(site.get("pressure_bonus", 0))) * 180
	value += _resource_site_support_value(site)
	if String(site.get("learn_spell_id", "")) != "":
		value += 220
	return value

static func _resource_site_pressure_value(site: Dictionary) -> int:
	var pressure = _pressure_from_rewards(_resource_site_claim_rewards(site))
	pressure += max(0, int(site.get("pressure_bonus", 0)))
	pressure += int(floor(float(_resource_site_support_value(site)) / 220.0))
	if max(0, int(site.get("vision_radius", 0))) > 0:
		pressure += 1
	if String(site.get("learn_spell_id", "")) != "":
		pressure += 1
	if site.get("weekly_recruits", {}) is Dictionary and not site.get("weekly_recruits", {}).is_empty():
		pressure += 1
	return clamp(pressure, 0, 4)

static func _resource_site_support_value(site: Dictionary) -> int:
	var support = site.get("town_support", {})
	if not (support is Dictionary):
		return 0
	var value = 0
	value += max(0, int(support.get("quality_bonus", 0))) * 85
	value += max(0, int(support.get("readiness_bonus", 0))) * 70
	value += max(0, int(support.get("pressure_bonus", 0))) * 120
	value += max(0, int(support.get("growth_bonus_percent", 0))) * 16
	value += max(0, int(support.get("recovery_relief", 0))) * 120
	value += max(0, int(support.get("disruption_pressure", 0))) * 90
	return value

static func _recruit_payload_value(recruits: Variant) -> int:
	var value = 0
	if not (recruits is Dictionary):
		return value
	for unit_id_value in recruits.keys():
		var unit_id = String(unit_id_value)
		var count: int = max(0, int(recruits[unit_id_value]))
		if unit_id == "" or count <= 0:
			continue
		var unit = ContentService.get_unit(unit_id)
		var tier: int = max(1, int(unit.get("tier", 1)))
		value += count * (120 + (tier * 60))
		if bool(unit.get("ranged", false)):
			value += count * 30
	return value

static func _default_enemy_strategy() -> Dictionary:
	return {
		"build_category_weights": {
			"civic": 1.0,
			"dwelling": 1.0,
			"economy": 1.0,
			"support": 1.0,
			"magic": 1.0,
		},
		"build_value_weights": {
			"income": 1.0,
			"growth": 1.0,
			"quality": 1.0,
			"readiness": 1.0,
			"pressure": 1.0,
		},
		"raid_target_weights": {
			"town": 1.0,
			"resource": 1.0,
			"artifact": 1.0,
			"encounter": 1.0,
			"hero": 1.0,
		},
		"resource_value_weights": {
			"gold": 1.0,
			"wood": 1.0,
			"ore": 1.0,
			"experience": 1.0,
		},
		"site_family_weights": {
			"neutral_dwelling": 1.0,
			"faction_outpost": 1.0,
			"frontier_shrine": 1.0,
		},
		"reinforcement": {
			"garrison_bias": 1.0,
			"raid_bias": 1.0,
			"ranged_weight": 1.0,
			"melee_weight": 1.0,
			"low_tier_weight": 1.0,
			"high_tier_weight": 1.0,
		},
		"raid": {
			"threshold_scale": 1.0,
			"max_active_bonus": 0,
			"pressure_commitment_scale": 1.0,
			"objective_weight": 1.0,
			"town_siege_weight": 1.0,
			"site_denial_weight": 1.0,
			"hero_hunt_weight": 1.0,
		},
	}

static func _merge_strategy_dict(base: Dictionary, override: Dictionary) -> Dictionary:
	var merged = base.duplicate(true)
	for key in override.keys():
		var value = override[key]
		if value is Dictionary and merged.get(key, {}) is Dictionary:
			merged[String(key)] = _merge_strategy_dict(merged.get(key, {}), value)
		else:
			merged[String(key)] = value
	return merged

static func _find_artifact_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for index in range(session.overworld.get("artifact_nodes", []).size()):
		var node = session.overworld.get("artifact_nodes", [])[index]
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return {"index": index, "node": node}
	return {"index": -1, "node": {}}

static func _find_encounter_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for index in range(session.overworld.get("encounters", []).size()):
		var encounter = session.overworld.get("encounters", [])[index]
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return {"index": index, "encounter": encounter}
	return {"index": -1, "encounter": {}}

static func _town_name(town_state: Dictionary) -> String:
	var town = ContentService.get_town(String(town_state.get("town_id", "")))
	return String(town.get("name", town_state.get("town_id", "Town")))

static func _town_faction_id(town_state: Dictionary) -> String:
	var controller := String(town_state.get("controlling_faction_id", ""))
	if String(town_state.get("owner", "neutral")) == "enemy" and controller != "":
		return controller
	var town = ContentService.get_town(String(town_state.get("town_id", "")))
	return String(town.get("faction_id", ""))

static func _describe_count_map(verb: String, counts: Dictionary) -> String:
	if counts.is_empty():
		return ""
	var parts = []
	var keys = counts.keys()
	keys.sort()
	for key in keys:
		var count = int(counts[key])
		parts.append("%d raid%s %s %s" % [count, "" if count == 1 else "s", verb, String(key)])
	return ", ".join(parts)

static func _merge_resources(base: Variant, delta: Variant) -> Dictionary:
	var merged = {}
	if base is Dictionary:
		for key in base.keys():
			merged[String(key)] = int(base[key])
	if delta is Dictionary:
		for key in delta.keys():
			var resource_key = String(key)
			merged[resource_key] = int(merged.get(resource_key, 0)) + max(0, int(delta[key]))
	return merged

static func _remove_resources(session: SessionStateStoreScript.SessionData, losses: Variant) -> Dictionary:
	var actual = {}
	if not (losses is Dictionary) or losses.is_empty():
		return actual
	var resources = session.overworld.get("resources", {}).duplicate(true)
	for key in losses.keys():
		var resource_key = String(key)
		var available: int = max(0, int(resources.get(resource_key, 0)))
		var loss: int = min(available, max(0, int(losses[key])))
		if loss > 0:
			resources[resource_key] = available - loss
			actual[resource_key] = loss
	session.overworld["resources"] = resources
	return actual

static func _describe_resource_set(resources: Dictionary) -> String:
	var parts = []
	var keys = resources.keys()
	keys.sort()
	for key in keys:
		parts.append("%d %s" % [int(resources[key]), String(key)])
	return ", ".join(parts)

static func _base_enemy_army(encounter_id: String) -> Dictionary:
	var encounter = ContentService.get_encounter(encounter_id)
	if encounter.is_empty():
		return {}
	return _normalize_army_payload(ContentService.get_army_group(String(encounter.get("enemy_group_id", ""))))

static func _encounter_guard_strength(encounter_state: Dictionary) -> int:
	if encounter_state.is_empty():
		return 0
	var army := _normalize_army_payload(encounter_state.get("enemy_army", {}))
	if army.is_empty():
		army = _base_enemy_army(String(encounter_state.get("encounter_id", encounter_state.get("id", ""))))
	return _army_strength(army.get("stacks", []))

static func _normalize_army_payload(army: Variant) -> Dictionary:
	if not (army is Dictionary):
		return {}
	var normalized_stacks = []
	for stack_value in army.get("stacks", []):
		if not (stack_value is Dictionary):
			continue
		var unit_id = String(stack_value.get("unit_id", ""))
		var count: int = max(0, int(stack_value.get("count", 0)))
		if unit_id == "" or count <= 0:
			continue
		normalized_stacks.append({"unit_id": unit_id, "count": count})
	if normalized_stacks.is_empty():
		return {}
	return {
		"id": String(army.get("id", "")),
		"name": String(army.get("name", "Raid Host")),
		"stacks": normalized_stacks,
	}

static func _army_strength(stacks: Variant) -> int:
	var total = 0
	if not (stacks is Array):
		return total
	for stack_value in stacks:
		if not (stack_value is Dictionary):
			continue
		var unit_id = String(stack_value.get("unit_id", ""))
		var count: int = max(0, int(stack_value.get("count", 0)))
		if unit_id == "" or count <= 0:
			continue
		total += _unit_strength_value(unit_id) * count
	return total

static func _unit_strength_value(unit_id: String) -> int:
	var unit = ContentService.get_unit(unit_id)
	return max(
		6,
		int(unit.get("hp", 1))
		+ int(unit.get("min_damage", 1))
		+ int(unit.get("max_damage", 1))
		+ (3 if bool(unit.get("ranged", false)) else 0)
	)

static func _add_army_stack(stacks: Variant, unit_id: String, amount: int) -> Array:
	var normalized := []
	var added := false
	if stacks is Array:
		for stack_value in stacks:
			if not (stack_value is Dictionary):
				continue
			var stack := {
				"unit_id": String(stack_value.get("unit_id", "")),
				"count": max(0, int(stack_value.get("count", 0))),
			}
			if stack["unit_id"] == unit_id:
				stack["count"] = int(stack.get("count", 0)) + max(0, amount)
				added = true
			if stack["unit_id"] != "" and int(stack.get("count", 0)) > 0:
				normalized.append(stack)
	if not added and unit_id != "" and amount > 0:
		normalized.append({"unit_id": unit_id, "count": amount})
	return normalized

static func _scale_resources(payload: Variant, multiplier: int) -> Dictionary:
	var scaled = {}
	if not (payload is Dictionary) or multiplier <= 0:
		return scaled
	for key in payload.keys():
		scaled[String(key)] = max(0, int(payload[key])) * multiplier
	return scaled

static func _raid_is_public(session: SessionStateStoreScript.SessionData, encounter: Dictionary) -> bool:
	if session == null:
		return false
	if bool(encounter.get("arrived", false)):
		if String(encounter.get("target_kind", "")) == "town":
			var town_result = _find_town_by_placement(session, String(encounter.get("target_placement_id", "")))
			if int(town_result.get("index", -1)) >= 0 and String(town_result.get("town", {}).get("owner", "neutral")) == "player":
				return true
	if OverworldRulesScript.is_tile_visible(session, int(encounter.get("x", 0)), int(encounter.get("y", 0))):
		return true
	return false

static func _pos_key(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]

static func _vector_from_key(key: String) -> Vector2i:
	var parts = key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))
