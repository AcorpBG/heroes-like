class_name TownRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
static var OverworldRulesScript: Variant = load("res://scripts/core/OverworldRules.gd")
static var HeroCommandRulesScript: Variant = load("res://scripts/core/HeroCommandRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
static var EnemyAdventureRulesScript: Variant = load("res://scripts/core/EnemyAdventureRules.gd")
static var ScenarioRulesScript: Variant = load("res://scripts/core/ScenarioRules.gd")

static var _read_scope_session_id := ""
static var _read_scope_depth := 0
static var _read_scope_cache := {}

static func begin_read_scope(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	var session_id := String(session.session_id)
	if _read_scope_depth > 0 and session_id == _read_scope_session_id:
		_read_scope_depth += 1
		return
	_read_scope_session_id = session_id
	_read_scope_depth = 1
	_read_scope_cache = {}

static func end_read_scope(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	if _read_scope_depth <= 0 or String(session.session_id) != _read_scope_session_id:
		return
	_read_scope_depth -= 1
	if _read_scope_depth <= 0:
		_read_scope_depth = 0
		_read_scope_session_id = ""
		_read_scope_cache = {}

static func _read_cache_has(session: SessionStateStoreScript.SessionData, key: String) -> bool:
	return (
		session != null
		and _read_scope_depth > 0
		and String(session.session_id) == _read_scope_session_id
		and _read_scope_cache.has(key)
	)

static func _read_cache_get(session: SessionStateStoreScript.SessionData, key: String):
	if not _read_cache_has(session, key):
		return null
	return _read_scope_cache[key]

static func _read_cache_store(session: SessionStateStoreScript.SessionData, key: String, value: Variant) -> void:
	if session == null or _read_scope_depth <= 0 or String(session.session_id) != _read_scope_session_id:
		return
	_read_scope_cache[key] = value

static func can_visit_active_town(session: SessionStateStoreScript.SessionData) -> bool:
	var town := get_active_town(session)
	return not town.is_empty() and String(town.get("owner", "neutral")) == "player"

static func can_visit_active_town_bridge(session) -> bool:
	return can_visit_active_town(session)

static func get_active_town(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if _read_cache_has(session, "active_town"):
		return _read_cache_get(session, "active_town")
	var result := _find_active_town_result(session)
	var town: Dictionary = result.get("town", {})
	_read_cache_store(session, "active_town", town)
	return town

static func describe_status(session: SessionStateStoreScript.SessionData) -> String:
	var pos: Vector2i = OverworldRulesScript.hero_position(session)
	var days_until_growth: int = OverworldRulesScript.days_until_next_weekly_growth(session.day)
	var week := _week_of_day(session.day)
	var weekday := _weekday_of_day(session.day)
	var growth_clause := "Weekly muster refreshes today." if OverworldRulesScript.is_weekly_growth_day(session.day) else "Next muster Day %d in %d day%s" % [
		OverworldRulesScript.next_weekly_growth_day(session.day),
		days_until_growth,
		"" if days_until_growth == 1 else "s",
	]
	return "Week %d Day %d | Field Pos %d,%d | %s" % [
		week,
		weekday,
		pos.x,
		pos.y,
		growth_clause,
	]

static func describe_header(session: SessionStateStoreScript.SessionData) -> String:
	var town := get_active_town(session)
	if town.is_empty():
		return "No town is under command."
	var template := ContentService.get_town(String(town.get("town_id", "")))
	var faction := ContentService.get_faction(String(template.get("faction_id", "")))
	var role_label := ""
	match OverworldRulesScript.town_strategic_role(town):
		"capital":
			role_label = " | Capital Anchor"
		"stronghold":
			role_label = " | Frontier Stronghold"
	return "%s | %s%s | Owner %s | Spell Tier %d" % [
		String(template.get("name", town.get("town_id", "Town"))),
		String(faction.get("name", template.get("faction_id", "Faction"))),
		role_label,
		String(town.get("owner", "neutral")).capitalize(),
		current_spell_tier(town),
	]

static func describe_summary(session: SessionStateStoreScript.SessionData) -> String:
	var town := get_active_town(session)
	if town.is_empty():
		return "No active town."
	var weekly_growth := _describe_recruit_delta(OverworldRulesScript.town_weekly_growth(town, session))
	var reinforcement_quality: int = OverworldRulesScript.town_reinforcement_quality(town, session)
	var battle_readiness: int = OverworldRulesScript.town_battle_readiness(town, session)
	var pressure_output: int = OverworldRulesScript.town_pressure_output(town, session)
	var built_buildings = town.get("built_buildings", [])
	var available_orders := get_build_actions(session).size()
	var locked_plans := _locked_building_count(town)
	var spell_tier := current_spell_tier(town)
	var days_until_growth: int = OverworldRulesScript.days_until_next_weekly_growth(session.day)
	var capital_project: Dictionary = OverworldRulesScript.town_capital_project_state(town, session)
	var battlefront: Dictionary = OverworldRulesScript.town_battlefront_profile(town)
	var logistics: Dictionary = OverworldRulesScript.town_logistics_state(session, town)
	var recovery: Dictionary = OverworldRulesScript.town_recovery_state(session, town)
	var front: Dictionary = OverworldRulesScript.town_front_state(session, town)
	var occupation: Dictionary = OverworldRulesScript.town_occupation_state(session, town)
	var market: Dictionary = OverworldRulesScript.town_market_state(town)
	var parts := [
		"%s" % OverworldRulesScript.describe_town_identity_surface(town, session),
		"%s" % OverworldRulesScript.town_strategic_summary(town),
		"Battlefront %s" % String(battlefront.get("summary", "The defenders will meet the assault in ordinary lines.")),
		"Daily income %s | Spell tier %d | Built works %d" % [
			_describe_resources(OverworldRulesScript.town_income(town, session)),
			spell_tier,
			built_buildings.size() if built_buildings is Array else 0,
		],
		"Next weekly muster Day %d in %d day%s | Growth %s" % [
			OverworldRulesScript.next_weekly_growth_day(session.day),
			days_until_growth,
			"" if days_until_growth == 1 else "s",
			weekly_growth,
		],
		"%s %d | Reinforcement %s | Battle readiness %d" % [
			_town_pressure_label(town),
			pressure_output,
			_reinforcement_grade(reinforcement_quality),
			battle_readiness,
		],
		"Open plans %d | Deferred plans %d | %s" % [
			available_orders,
			locked_plans,
			_describe_building_category_counts(built_buildings),
		],
		"Logistics %s" % _logistics_watch_summary(logistics),
	]
	if bool(front.get("active", false)):
		parts.append("Front %s" % String(front.get("summary", "")))
	if bool(occupation.get("active", false)):
		parts.append("Occupation %s" % String(occupation.get("summary", "")))
	var delivery_summary := _convoy_watch_summary(logistics)
	if delivery_summary != "":
		parts.append("Convoys %s" % delivery_summary)
	if bool(market.get("active", false)):
		parts.append(
			"Exchange %s | Buy wood %d, ore %d | Sell wood %d, ore %d" % [
				String(market.get("building_name", "Market")),
				int(market.get("buy_rates", {}).get("wood", 0)),
				int(market.get("buy_rates", {}).get("ore", 0)),
				int(market.get("sell_rates", {}).get("wood", 0)),
				int(market.get("sell_rates", {}).get("ore", 0)),
			]
		)
	if bool(recovery.get("active", false)):
		parts.append("Recovery %s" % String(recovery.get("summary", "")))
	else:
		parts.append("Recovery lines steady | %d/day relief" % int(recovery.get("relief_per_day", 1)))
	if bool(capital_project.get("active", false)):
		var project_line := "Capital project online %d/%d | %s" % [
			int(capital_project.get("progress_complete", 0)),
			int(capital_project.get("progress_total", 0)),
			String(capital_project.get("summary", "The stronghold is driving a theater-wide escalation.")),
		]
		var support_summary := _project_support_summary(capital_project)
		if support_summary != "":
			project_line += " | %s" % support_summary
		parts.append(project_line)
	elif int(capital_project.get("total", 0)) > 0:
		parts.append(
			"Capital project %d/%d | Next %s | %s" % [
				int(capital_project.get("progress_complete", 0)),
				int(capital_project.get("progress_total", 0)),
				String(capital_project.get("next_label", "final anchor works")),
				_project_support_summary(capital_project),
			]
		)
	return "\n".join(parts)

static func describe_production_overview(session: SessionStateStoreScript.SessionData) -> String:
	var town := get_active_town(session)
	if town.is_empty():
		return "Production Overview\n- No active town."

	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var faction := ContentService.get_faction(String(town_template.get("faction_id", "")))
	var built_buildings = town.get("built_buildings", [])
	var built_count: int = built_buildings.size() if built_buildings is Array else 0
	var build_actions := get_build_actions(session)
	var recruit_actions := get_recruit_actions(session)
	var weekly_growth: Dictionary = OverworldRulesScript.town_weekly_growth(town, session)
	var ready_builds := _count_ready_actions(build_actions)
	var ready_recruits := _count_ready_actions(recruit_actions)
	var role: String = OverworldRulesScript.town_strategic_role(town).capitalize()
	if role == "":
		role = "Frontier"
	return "\n".join(
		[
			"Production Overview",
			"- Owner %s | Faction %s | %s" % [
				String(town.get("owner", "neutral")).capitalize(),
				String(faction.get("name", town_template.get("faction_id", "Faction"))),
				role,
			],
			"- Income/day %s | Works %d built, %d open, %d deferred" % [
				_describe_resources(OverworldRulesScript.town_income(town, session)),
				built_count,
				build_actions.size(),
				_locked_building_count(town),
			],
			"- Muster %d waiting | Weekly %s on Day %d" % [
				_recruit_pool_total(town.get("available_recruits", {})),
				_describe_recruit_delta(weekly_growth),
				OverworldRulesScript.next_weekly_growth_day(session.day),
			],
			"- Ready now build %d/%d, recruit %d/%d | Next: %s" % [
				ready_builds,
				build_actions.size(),
				ready_recruits,
				recruit_actions.size(),
				_next_town_action_line(session, town),
			],
			"- Practical priority: %s" % _town_recommendation_line(session, town),
		]
	)

static func describe_outlook_board(session: SessionStateStoreScript.SessionData) -> String:
	var town := get_active_town(session)
	if town.is_empty():
		return "Defense Outlook\n- No active town."

	var readiness: int = OverworldRulesScript.town_battle_readiness(town, session)
	var reinforcement_quality: int = OverworldRulesScript.town_reinforcement_quality(town, session)
	var pressure_output: int = OverworldRulesScript.town_pressure_output(town, session)
	var logistics: Dictionary = OverworldRulesScript.town_logistics_state(session, town)
	var recovery: Dictionary = OverworldRulesScript.town_recovery_state(session, town)
	var capital_project: Dictionary = OverworldRulesScript.town_capital_project_state(town, session)
	var battlefront: Dictionary = OverworldRulesScript.town_battlefront_profile(town)
	var threat_state: Dictionary = OverworldRulesScript.town_public_threat_state(session, town)
	var front_state: Dictionary = OverworldRulesScript.town_front_state(session, town)
	var occupation_state: Dictionary = OverworldRulesScript.town_occupation_state(session, town)
	var stationed: Array = HeroCommandRulesScript.stationed_heroes(session, town)
	var reserve_count := _stationed_reserve_count(session, stationed)
	var response_actions := get_response_actions(session)
	var ready_response_count := _count_ready_actions(response_actions)
	var movement_state := _active_hero_movement_state(session)
	var lines := [
		"Defense Outlook",
		"- Outlook: %s | Walls %s | Readiness %d | Reinforcement %s | %s %d" % [
			_town_outlook_grade(
				readiness,
				threat_state,
				front_state,
				occupation_state,
				logistics,
				recovery,
				capital_project,
				reserve_count,
				ready_response_count
			),
			_defense_grade(town),
			readiness,
			_reinforcement_grade(reinforcement_quality),
			_town_pressure_label(town),
			pressure_output,
		],
		"- Frontier watch: %s" % _town_frontier_outlook_line(town, threat_state, front_state, occupation_state, battlefront),
		"- Dispatch readiness: %s" % _town_dispatch_readiness_line(
			response_actions.size(),
			ready_response_count,
			movement_state,
			reserve_count
		),
		"- Support chain: %s" % _town_support_watch_line(town, logistics, recovery, capital_project),
	]
	return "\n".join(lines)

static func describe_command_ledger(session: SessionStateStoreScript.SessionData) -> String:
	var town := get_active_town(session)
	if town.is_empty():
		return "Order Ledger\n- No active town."
	var lines := [
		"Order Ledger",
		"- Construction: %s" % _build_order_ledger_line(session, town),
		"- Recruitment: %s" % _recruit_order_ledger_line(session, town),
		"- Response: %s" % _response_order_ledger_line(session, town),
		"- Coverage: %s" % _coverage_order_ledger_line(session, town),
	]
	return "\n".join(lines)

static func describe_defense(session: SessionStateStoreScript.SessionData) -> String:
	var town := get_active_town(session)
	if town.is_empty():
		return "Defense unavailable."

	var stationed: Array = HeroCommandRulesScript.stationed_heroes(session, town)
	var active_hero_value: Variant = session.overworld.get("hero", {})
	var active_hero: Dictionary = active_hero_value if active_hero_value is Dictionary else {}
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	var reserve_lines := []
	for hero in stationed:
		if not (hero is Dictionary):
			continue
		if String(hero.get("id", "")) == active_hero_id:
			continue
		reserve_lines.append(_hero_command_line(hero))

	var lines := [
		"Defense Posture",
		"- %s | %d companies | %d total troops" % [
			_defense_grade(town),
			_garrison_company_count(town),
			_garrison_headcount(town),
		],
		"- Battle readiness %d | Reinforcement %s" % [
			OverworldRulesScript.town_battle_readiness(town, session),
			_reinforcement_grade(OverworldRulesScript.town_reinforcement_quality(town, session)),
		],
		"- Defense readiness: %s" % OverworldRulesScript.describe_town_defense_readiness_warning(session, town),
		"- Garrison %s" % _describe_garrison(town),
		"- Logistics %s" % _logistics_watch_summary(OverworldRulesScript.town_logistics_state(session, town)),
	]
	var recovery: Dictionary = OverworldRulesScript.town_recovery_state(session, town)
	if bool(recovery.get("active", false)):
		lines.append("- Recovery %s" % String(recovery.get("summary", "")))
	if not active_hero.is_empty():
		lines.append("- Active defender %s" % _hero_command_line(active_hero))
	if reserve_lines.is_empty():
		lines.append("- No reserve commander is stationed. The town captain will lead if the field hero departs.")
	else:
		lines.append("- Reserve commanders %s" % "; ".join(reserve_lines))
	return "\n".join(lines)

static func describe_threats(session: SessionStateStoreScript.SessionData) -> String:
	var town := get_active_town(session)
	if town.is_empty():
		return "Threat watch unavailable."

	var lines := ["Frontier Watch"]
	var threat_lines := _town_threat_lines(session, town)
	var capital_project: Dictionary = OverworldRulesScript.town_capital_project_state(town, session)
	var battlefront: Dictionary = OverworldRulesScript.town_battlefront_profile(town)
	var logistics: Dictionary = OverworldRulesScript.town_logistics_state(session, town)
	var recovery: Dictionary = OverworldRulesScript.town_recovery_state(session, town)
	var front_state: Dictionary = OverworldRulesScript.town_front_state(session, town)
	var occupation_state: Dictionary = OverworldRulesScript.town_occupation_state(session, town)
	if threat_lines.is_empty():
		lines.append("- No hostile raid hosts are currently aligned on %s." % _town_name(town))
		lines.append("- Defense readiness: %s" % OverworldRulesScript.describe_town_defense_readiness_warning(session, town))
		if bool(front_state.get("active", false)):
			lines.append("- Front watch: %s" % String(front_state.get("summary", "")))
		if bool(occupation_state.get("active", false)):
			lines.append("- Occupation watch: %s" % String(occupation_state.get("summary", "")))
		lines.append("- The walls hold a %s over the frontier roads." % _defense_grade(town).to_lower())
		if String(battlefront.get("summary", "")) != "":
			lines.append("- Siege profile: %s" % String(battlefront.get("summary", "")))
		lines.append("- Logistics chain: %s" % _logistics_watch_summary(logistics))
		if bool(recovery.get("active", false)):
			lines.append("- Recovery watch: %s" % String(recovery.get("summary", "")))
		if int(capital_project.get("total", 0)) > 0:
			lines.append("- Capital watch: %s" % _project_watch_summary(capital_project))
		return "\n".join(lines)

	for threat_line in threat_lines:
		lines.append("- %s" % threat_line)
	lines.append("- Defense readiness: %s" % OverworldRulesScript.describe_town_defense_readiness_warning(session, town))
	if String(battlefront.get("summary", "")) != "":
		lines.append("- Siege profile: %s" % String(battlefront.get("summary", "")))
	lines.append("- Logistics chain: %s" % _logistics_watch_summary(logistics))
	if logistics.get("disrupted_site_labels", []) is Array and not logistics.get("disrupted_site_labels", []).is_empty():
		lines.append("- Denied routes: %s" % ", ".join(logistics.get("disrupted_site_labels", [])))
	if logistics.get("threatened_site_labels", []) is Array and not logistics.get("threatened_site_labels", []).is_empty():
		lines.append("- Threatened routes: %s" % ", ".join(logistics.get("threatened_site_labels", [])))
	if logistics.get("response_site_labels", []) is Array and not logistics.get("response_site_labels", []).is_empty():
		lines.append("- Active route orders: %s" % ", ".join(logistics.get("response_site_labels", [])))
	if bool(recovery.get("active", false)):
		lines.append("- Recovery watch: %s" % String(recovery.get("summary", "")))
	if bool(occupation_state.get("active", false)):
		lines.append("- Occupation watch: %s" % String(occupation_state.get("summary", "")))
	if int(capital_project.get("total", 0)) > 0:
		lines.append("- Capital watch: %s" % _project_watch_summary(capital_project))
	return "\n".join(lines)

static func describe_event_feed(
	session: SessionStateStoreScript.SessionData,
	last_message: String = "",
	action_recap: Dictionary = {}
) -> String:
	var town := get_active_town(session)
	if town.is_empty():
		return "Town Dispatch\n- No active town."

	var open_builds := get_build_actions(session).size()
	var open_recruits := get_recruit_actions(session).size()
	var open_study := get_spell_learning_actions(session).size()
	var recap_text := String(action_recap.get("text", ""))
	var lead_line := recap_text if recap_text != "" else ("Latest order: %s" % last_message if last_message != "" else "The council chamber awaits fresh orders.")
	var pressure_line := _pressure_brief(session, town)
	var logistics: Dictionary = OverworldRulesScript.town_logistics_state(session, town)
	var recovery: Dictionary = OverworldRulesScript.town_recovery_state(session, town)
	var market_actions := get_market_actions(session).size()
	var response_actions := get_response_actions(session).size()
	var handoff := town_handoff_recap(session)
	var lines := [
		"Town Dispatch",
		lead_line if recap_text != "" else "- %s" % String(handoff.get("visible_text", lead_line)),
		"- Construction %d | Recruitment %d | Study %d" % [open_builds, open_recruits, open_study],
	]
	if bool(handoff.get("active", false)):
		lines.append("- Affected: %s" % String(handoff.get("affected", "")))
		lines.append("- Why it matters: %s" % String(handoff.get("why_it_matters", "")))
		lines.append("- Next practical action: %s" % String(handoff.get("next_step", "")))
	if pressure_line != "":
		lines.append("- %s" % pressure_line)
	lines.append("- Defense readiness: %s" % OverworldRulesScript.describe_town_defense_readiness_warning(session, town))
	if bool(recovery.get("active", false)):
		lines.append("- Recovery watch: %s" % String(recovery.get("summary", "")))
	elif int(logistics.get("disrupted_count", 0)) > 0 or int(logistics.get("threatened_count", 0)) > 0:
		lines.append("- Logistics watch: %s" % _logistics_watch_summary(logistics))
	if market_actions > 0:
		lines.append("- Exchange orders %d" % market_actions)
	if response_actions > 0:
		lines.append("- Strategic response orders %d" % response_actions)
	return "\n".join(lines)

static func town_handoff_recap(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var town := get_active_town(session)
	if town.is_empty():
		return {
			"active": false,
			"visible_text": "Handoff: no active town.",
			"affected": "",
			"why_it_matters": "",
			"next_step": "Return to the overworld.",
			"tooltip_text": "Town Handoff\n- No active town.",
		}

	var town_name := _town_name(town)
	var front: Dictionary = OverworldRulesScript.town_front_state(session, town)
	var occupation: Dictionary = OverworldRulesScript.town_occupation_state(session, town)
	var logistics: Dictionary = OverworldRulesScript.town_logistics_state(session, town)
	var recovery: Dictionary = OverworldRulesScript.town_recovery_state(session, town)
	var response_actions := get_response_actions(session)
	var ready_response := _first_ready_action(response_actions)
	var movement := _active_hero_movement_state(session)
	var affected := _town_handoff_affected_line(town_name, front, occupation, logistics, ready_response)
	var why := _town_handoff_why_line(town, front, occupation, logistics, recovery, ready_response)
	var next := _town_handoff_next_line(session, town, ready_response, movement)
	var visible := "Handoff: %s | Why: %s | Next: %s" % [
		_short_town_handoff_text(affected, 58),
		_short_town_handoff_text(why, 70),
		_short_town_handoff_text(next, 72),
	]
	var tooltip := "Town Handoff\n- Affected: %s\n- Why it matters: %s\n- Next practical action: %s" % [
		affected,
		why,
		next,
	]
	return {
		"active": true,
		"town_name": town_name,
		"affected": affected,
		"why_it_matters": why,
		"next_step": next,
		"visible_text": visible,
		"tooltip_text": tooltip,
		"ready_response_action_count": 1 if not ready_response.is_empty() else 0,
		"movement_current": int(movement.get("current", 0)),
		"movement_max": int(movement.get("max", 0)),
	}

static func town_departure_confirmation(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var town := get_active_town(session)
	if town.is_empty():
		return {
			"active": false,
			"button_label": "Leave",
			"visible_text": "Ready check: no active town.",
			"tooltip_text": "Departure Check\n- No active town.",
			"next_step": "Return to the overworld.",
		}

	var handoff := town_handoff_recap(session)
	var movement := _active_hero_movement_state(session)
	var move_current := int(movement.get("current", 0))
	var move_max := int(movement.get("max", 0))
	var recommendation := _town_recommendation_line(session, town)
	var next_step := String(handoff.get("next_step", _next_town_action_line(session, town)))
	var button_label := "Leave / End Turn" if move_current <= 0 else "Leave: %d/%d Move" % [move_current, move_max]
	var visible_text := ""
	if int(handoff.get("ready_response_action_count", 0)) > 0:
		visible_text = "Ready check: response order is open before leaving."
	elif move_current <= 0:
		visible_text = "Ready check: finish town orders, then leave and end turn."
	else:
		visible_text = "Ready check: finish town orders, then leave with %d/%d move." % [move_current, move_max]
	var tooltip := "Departure Check\n- Town readiness: %s\n- Affected: %s\n- Why it matters: %s\n- Next practical action: %s" % [
		recommendation,
		String(handoff.get("affected", "")),
		String(handoff.get("why_it_matters", "")),
		next_step,
	]
	return {
		"active": true,
		"button_label": button_label,
		"visible_text": visible_text,
		"tooltip_text": tooltip,
		"town_readiness": recommendation,
		"affected": String(handoff.get("affected", "")),
		"why_it_matters": String(handoff.get("why_it_matters", "")),
		"next_step": next_step,
		"movement_current": move_current,
		"movement_max": move_max,
		"ready_response_action_count": int(handoff.get("ready_response_action_count", 0)),
	}

static func town_action_consequence_signature(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var town := get_active_town(session)
	if town.is_empty():
		return {}
	var logistics: Dictionary = OverworldRulesScript.town_logistics_state(session, town)
	var recovery: Dictionary = OverworldRulesScript.town_recovery_state(session, town)
	var front: Dictionary = OverworldRulesScript.town_front_state(session, town)
	return {
		"town_name": _town_name(town),
		"resources": _duplicate_dictionary(session.overworld.get("resources", {})),
		"built_buildings": _normalize_string_array(town.get("built_buildings", [])),
		"available_recruits": _duplicate_dictionary(town.get("available_recruits", {})),
		"army_counts": _army_unit_counts(session.overworld.get("army", {})),
		"income": OverworldRulesScript.town_income(town, session),
		"weekly_growth": OverworldRulesScript.town_weekly_growth(town, session),
		"battle_readiness": OverworldRulesScript.town_battle_readiness(town, session),
		"reinforcement_quality": OverworldRulesScript.town_reinforcement_quality(town, session),
		"pressure_output": OverworldRulesScript.town_pressure_output(town, session),
		"logistics_summary": String(logistics.get("summary", "")),
		"logistics_impact": String(logistics.get("impact_summary", "")),
		"recovery_summary": String(recovery.get("summary", "")),
		"front_summary": String(front.get("summary", "")),
		"front_active": bool(front.get("active", false)),
		"build_action_count": get_build_actions(session).size(),
		"recruit_action_count": get_recruit_actions(session).size(),
		"market_action_count": get_market_actions(session).size(),
		"response_action_count": get_response_actions(session).size(),
	}

static func build_town_action_recap(
	session: SessionStateStoreScript.SessionData,
	lane: String,
	action_id: String,
	action: Dictionary,
	result: Dictionary,
	before: Dictionary
) -> Dictionary:
	var message := String(result.get("message", ""))
	if not bool(result.get("ok", false)):
		return {
			"active": false,
			"kind": lane,
			"action_id": action_id,
			"message": message,
			"text": message,
		}
	var after := town_action_consequence_signature(session)
	var happened := _town_action_happened_line(lane, action_id, action, message)
	var affected := _town_action_affected_line(lane, action_id, action, before, after)
	var matters := _town_action_matters_line(session, lane, before, after)
	var next := _town_action_next_line(session)
	var text := "After order: %s\nAffected: %s\nWhy it matters: %s\nNext: %s" % [
		happened,
		affected,
		matters,
		next,
	]
	var tooltip := "Action Recap\n- Happened: %s\n- Affected: %s\n- Why it matters: %s\n- Next: %s" % [
		happened,
		affected,
		matters,
		next,
	]
	return {
		"active": true,
		"kind": lane,
		"action_id": action_id,
		"label": String(action.get("label", action_id)),
		"happened": happened,
		"affected": affected,
		"why_it_matters": matters,
		"next_step": next,
		"matters": matters,
		"next": next,
		"text": text,
		"tooltip_text": tooltip,
		"message": message,
	}

static func describe_buildings(session: SessionStateStoreScript.SessionData) -> String:
	var town := get_active_town(session)
	if town.is_empty():
		return "Buildings unavailable."

	var built_lines := []
	for building_id_value in town.get("built_buildings", []):
		var building_id := String(building_id_value)
		if building_id == "":
			continue
		built_lines.append("- %s" % _building_line(building_id, "built"))

	var available_lines := []
	for action in get_build_actions(session):
		if not (action is Dictionary):
			continue
		available_lines.append("- %s" % String(action.get("ledger_line", action.get("summary", action.get("label", "Build")))))

	var locked_lines := []
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var built_buildings = town.get("built_buildings", [])
	for building_id_value in town_template.get("buildable_building_ids", []):
		var building_id := String(building_id_value)
		if building_id == "" or building_id in built_buildings:
			continue
		var build_status: Dictionary = OverworldRulesScript.get_town_build_status(town, building_id)
		if bool(build_status.get("buildable", false)):
			continue
		locked_lines.append("- %s" % _building_line(building_id, "locked", build_status))

	var parts := []
	parts.append("Construction Ledger")
	parts.append(
		"Built works %d | Open orders %d | Deferred plans %d | %s" % [
			built_buildings.size() if built_buildings is Array else 0,
			available_lines.size(),
			locked_lines.size(),
			_describe_building_category_counts(built_buildings),
		]
	)
	parts.append("Built Works")
	parts.append("\n".join(built_lines) if not built_lines.is_empty() else "- No permanent works yet")
	parts.append("Open Orders")
	parts.append("\n".join(available_lines) if not available_lines.is_empty() else "- No open construction orders")
	if not locked_lines.is_empty():
		parts.append("Deferred Plans")
		parts.append("\n".join(locked_lines))
	return "\n".join(parts)

static func describe_recruitment(session: SessionStateStoreScript.SessionData) -> String:
	var town := get_active_town(session)
	if town.is_empty():
		return "Recruitment unavailable."

	var lines := []
	var recruits = town.get("available_recruits", {})
	var weekly_growth: Dictionary = OverworldRulesScript.town_weekly_growth(town, session)
	var days_until_growth: int = OverworldRulesScript.days_until_next_weekly_growth(session.day)
	var reinforcement_grade := _reinforcement_grade(OverworldRulesScript.town_reinforcement_quality(town, session))
	var logistics: Dictionary = OverworldRulesScript.town_logistics_state(session, town)
	var recovery: Dictionary = OverworldRulesScript.town_recovery_state(session, town)
	var occupation: Dictionary = OverworldRulesScript.town_occupation_state(session, town)
	for unit_id in _town_unit_ids(town):
		var unit := ContentService.get_unit(unit_id)
		var available := int(recruits.get(unit_id, 0))
		var growth := int(weekly_growth.get(unit_id, 0))
		if _unit_is_unlocked_in_town(town, unit_id):
			var growth_sources := _growth_source_summary(town, unit_id)
			var reserve_label := "x%d" % available if available > 0 else "reserve empty"
			lines.append(
				"- %s %s | %s | Weekly +%d%s | Cost %s" % [
					String(unit.get("name", unit_id)),
					reserve_label,
					OverworldRulesScript.describe_unit_recruit_brief(unit_id, available),
					max(0, growth),
					" via %s" % growth_sources if growth_sources != "" else "",
					_describe_resources(OverworldRulesScript.town_recruit_cost(session, town, unit_id)),
				]
			)
			continue
		var unlock_building_id := _unlock_building_for_unit(town, unit_id)
		var unlock_building := ContentService.get_building(unlock_building_id)
		var build_status: Dictionary = OverworldRulesScript.get_town_build_status(town, unlock_building_id)
		lines.append(
			"- %s locked | %s" % [
				String(unit.get("name", unit_id)),
				String(
					build_status.get(
						"blocked_message",
						"Build %s." % String(unlock_building.get("name", unlock_building_id))
					)
				),
				]
			)
	return "Recruit Reserves\nNext levy Day %d in %d day%s\n%s" % [
		OverworldRulesScript.next_weekly_growth_day(session.day),
		days_until_growth,
		"" if days_until_growth == 1 else "s",
		(
			"Reserve quality %s | Logistics %s%s%s\n%s" % [
				reinforcement_grade,
				_logistics_watch_summary(logistics),
				" | Convoys %s" % _convoy_watch_summary(logistics) if _convoy_watch_summary(logistics) != "" else "",
				(
					" | Occupation %s" % String(occupation.get("compact_summary", "pacifying"))
					if bool(occupation.get("active", false))
					else (" | Recovery %s" % String(recovery.get("summary", "")) if bool(recovery.get("active", false)) else "")
				),
				"\n".join(lines),
			]
		) if not lines.is_empty() else (
			"Reserve quality %s%s%s\n- No recruits are waiting" % [
				reinforcement_grade,
				" | Convoys %s" % _convoy_watch_summary(logistics) if _convoy_watch_summary(logistics) != "" else "",
				" | Occupation %s" % String(occupation.get("compact_summary", "pacifying")) if bool(occupation.get("active", false)) else "",
			]
		),
	]

static func describe_market(session: SessionStateStoreScript.SessionData) -> String:
	var town := get_active_town(session)
	if town.is_empty():
		return "Exchange Hall\n- No active town."
	return OverworldRulesScript.describe_town_market(session, town)

static func describe_spell_access(session: SessionStateStoreScript.SessionData) -> String:
	var town := get_active_town(session)
	if town.is_empty():
		return "Spell study unavailable."

	var tier := current_spell_tier(town)
	if tier <= 0:
		return "Spell Study\n- No archive halls are standing in this town"

	var lines := []
	var hero = session.overworld.get("hero", {})
	for spell_id in accessible_spell_ids(town):
		var spell := ContentService.get_spell(spell_id)
		if spell.is_empty():
			continue
		var status := "Known" if SpellRulesScript.knows_spell(hero, spell_id) else "Ready to learn"
		lines.append(
			"- %s | %s | %s" % [
				status,
				SpellRulesScript.spell_category_label(spell),
				SpellRulesScript.describe_spell_inspection_line(hero, spell),
			]
		)
	return "Spell Study\nTier %d archive access\n%s" % [
		tier,
		"\n".join(lines) if not lines.is_empty() else "- No spell leaves are catalogued here",
	]

static func describe_artifacts(session: SessionStateStoreScript.SessionData) -> String:
	return ArtifactRulesScript.describe_management(session.overworld.get("hero", {}))

static func describe_heroes(session: SessionStateStoreScript.SessionData) -> String:
	var town := get_active_town(session)
	if town.is_empty():
		return "Command\n- No active town."
	var stationed: Array = HeroCommandRulesScript.stationed_heroes(session, town)
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	var lines := ["Command Wing"]
	var active_found := false
	for hero in stationed:
		if not (hero is Dictionary):
			continue
		if String(hero.get("id", "")) == active_hero_id:
			lines.append("- Gate command: %s" % _hero_command_line(hero))
			active_found = true
			break
	if not active_found:
		lines.append("- No hero is currently commanding from the walls.")
	for hero in stationed:
		if not (hero is Dictionary):
			continue
		if String(hero.get("id", "")) == active_hero_id:
			continue
		lines.append("- Stationed reserve: %s" % _hero_command_line(hero))
	if lines.size() == 2 and not active_found:
		lines.append("- The town captain will anchor the defense if the city is assaulted.")
	elif lines.size() == 1:
		lines.append("- No stationed heroes.")
	return "\n".join(lines)

static func describe_specialties(session: SessionStateStoreScript.SessionData) -> String:
	return HeroProgressionRulesScript.describe_specialties(session.overworld.get("hero", {}))

static func describe_tavern(session: SessionStateStoreScript.SessionData) -> String:
	var town := get_active_town(session)
	if town.is_empty():
		return "Wayfarers Hall\n- No active town."
	return HeroCommandRulesScript.describe_tavern(session, town)

static func describe_transfer(session: SessionStateStoreScript.SessionData) -> String:
	var town := get_active_town(session)
	if town.is_empty():
		return "Transfer\n- No active town."
	return HeroCommandRulesScript.describe_town_transfer(session, town)

static func describe_responses(session: SessionStateStoreScript.SessionData) -> String:
	var town := get_active_town(session)
	if town.is_empty():
		return "Strategic Response\n- No active town."
	return OverworldRulesScript.describe_town_response_panel(session, town)

static func get_build_actions(session: SessionStateStoreScript.SessionData) -> Array:
	if _read_cache_has(session, "build_actions"):
		return _read_cache_get(session, "build_actions")
	var town := get_active_town(session)
	if town.is_empty():
		var empty := []
		_read_cache_store(session, "build_actions", empty)
		return empty

	var actions := []
	var resources = session.overworld.get("resources", {})
	for building_id in _available_building_ids(town):
		var building := ContentService.get_building(building_id)
		var build_status: Dictionary = OverworldRulesScript.get_town_build_status(town, building_id)
		var cost = building.get("cost", {})
		var projection: String = OverworldRulesScript.describe_town_build_projection(session, town, building_id)
		var readiness: Dictionary = OverworldRulesScript.town_cost_readiness(town, resources, cost)
		var direct_affordable := bool(readiness.get("direct_affordable", false))
		var market_coverable := bool(readiness.get("market_affordable", false)) and not direct_affordable
		var market_summary := _market_coverage_line(readiness)
		var shortfall_summary := _cost_shortfall_line(readiness)
		var affordability_line := _cost_readiness_line(resources, cost, readiness)
		var after_spend_line := _stores_after_cost_line(resources, cost)
		var impact_line := _build_choice_impact_line(session, town, building_id, building)
		var summary_lines := [
			"%s | Cost %s" % [
				_building_line(building_id, "available", build_status),
				_describe_resources(cost),
			],
			projection,
			impact_line,
			affordability_line,
		]
		if direct_affordable:
			if after_spend_line != "":
				summary_lines.append("After build stores: %s." % after_spend_line)
		elif market_coverable and market_summary != "":
			summary_lines.append("Exchange path: %s" % market_summary)
		elif shortfall_summary != "":
			summary_lines.append("Blocker: %s" % shortfall_summary)
		actions.append(
			{
				"id": "build:%s" % building_id,
				"label": "Build %s" % String(building.get("name", building_id)),
				"summary": "\n".join(summary_lines),
				"button_label": "Build %s | %s" % [
					String(building.get("name", building_id)),
					_build_action_badge(direct_affordable, market_coverable),
				],
				"ledger_line": "%s | Cost %s | %s" % [
					_building_line(building_id, "available", build_status),
					_describe_resources(cost),
					String(affordability_line).trim_suffix("."),
				],
				"impact_line": impact_line,
				"recommendation_line": _action_recommendation_line(
					"Build",
					String(building.get("name", building_id)),
					direct_affordable,
					market_coverable,
					shortfall_summary,
					impact_line
				),
				"cost": cost,
				"affordability_label": String(affordability_line).trim_suffix("."),
				"direct_affordable": direct_affordable,
				"market_coverable": market_coverable,
				"market_summary": market_summary,
				"shortfall_summary": shortfall_summary,
				"disabled_reason": _disabled_reason_line(direct_affordable, market_coverable, market_summary, shortfall_summary),
				"disabled": not direct_affordable,
			}
		)
	_read_cache_store(session, "build_actions", actions)
	return actions

static func get_recruit_actions(session: SessionStateStoreScript.SessionData) -> Array:
	if _read_cache_has(session, "recruit_actions"):
		return _read_cache_get(session, "recruit_actions")
	var town := get_active_town(session)
	if town.is_empty():
		var empty := []
		_read_cache_store(session, "recruit_actions", empty)
		return empty

	var actions := []
	var resources = session.overworld.get("resources", {})
	for unit_id in OverworldRulesScript.get_town_recruit_options(town):
		var unit := ContentService.get_unit(unit_id)
		var available := int(town.get("available_recruits", {}).get(unit_id, 0))
		var weekly_growth := int(OverworldRulesScript.town_weekly_growth(town, session).get(unit_id, 0))
		var unit_cost: Dictionary = OverworldRulesScript.town_recruit_cost(session, town, unit_id)
		var direct_affordable_count: int = min(available, _max_affordable_count(session, unit_cost))
		var market_affordable_count := _max_market_affordable_count(town, resources, unit_cost, available)
		var direct_recruit_cost := _multiply_resource_cost(unit_cost, direct_affordable_count)
		var recruit_impact_line := _recruit_choice_impact_line(unit_id, direct_affordable_count, available)
		var market_summary := ""
		if market_affordable_count > direct_affordable_count:
			var market_readiness: Dictionary = OverworldRulesScript.town_cost_readiness(
				town,
				resources,
				_multiply_resource_cost(unit_cost, market_affordable_count)
			)
			market_summary = _market_coverage_line(market_readiness)
		var shortfall_summary := ""
		if market_affordable_count <= 0:
			shortfall_summary = _cost_shortfall_line(OverworldRulesScript.town_cost_readiness(town, resources, unit_cost))
		var summary_lines := [
			"%s x%d | %s | Weekly +%d | Cost %s" % [
				String(unit.get("name", unit_id)),
				available,
				OverworldRulesScript.describe_unit_recruit_brief(unit_id, available),
				weekly_growth,
				_describe_resources(unit_cost),
			]
		]
		if recruit_impact_line != "":
			summary_lines.append(recruit_impact_line)
		if direct_affordable_count > 0:
			summary_lines.append("Ready: current stores can field %d now for %s." % [
				direct_affordable_count,
				_describe_resources(direct_recruit_cost),
			])
			var after_recruit_line := _stores_after_cost_line(resources, direct_recruit_cost)
			if after_recruit_line != "":
				summary_lines.append("After recruit stores: %s | Town reserve remains %d." % [
					after_recruit_line,
					max(0, available - direct_affordable_count),
				])
		elif market_affordable_count > 0 and market_summary != "":
			summary_lines.append("Exchange can unlock %d now: %s" % [market_affordable_count, market_summary])
		elif shortfall_summary != "":
			summary_lines.append("Blocker: %s" % shortfall_summary)
		actions.append(
			{
				"id": "recruit:%s" % unit_id,
				"label": "Recruit %s" % String(unit.get("name", unit_id)),
				"button_label": "Recruit %s | %s" % [
					String(unit.get("name", unit_id)),
					_recruit_action_badge(direct_affordable_count, market_affordable_count),
				],
				"summary": "\n".join(summary_lines),
				"impact_line": recruit_impact_line,
				"recommendation_line": _action_recommendation_line(
					"Recruit",
					String(unit.get("name", unit_id)),
					direct_affordable_count > 0,
					market_affordable_count > direct_affordable_count,
					shortfall_summary,
					recruit_impact_line
				),
				"unit_cost": unit_cost,
				"available_count": available,
				"weekly_growth": weekly_growth,
				"affordability_label": _recruit_affordability_label(direct_affordable_count, market_affordable_count, shortfall_summary),
				"direct_affordable_count": direct_affordable_count,
				"market_affordable_count": market_affordable_count,
				"market_coverable": market_affordable_count > direct_affordable_count,
				"market_summary": market_summary,
				"shortfall_summary": shortfall_summary,
				"disabled_reason": _disabled_reason_line(direct_affordable_count > 0, market_affordable_count > direct_affordable_count, market_summary, shortfall_summary),
				"disabled": direct_affordable_count <= 0,
			}
		)
	_read_cache_store(session, "recruit_actions", actions)
	return actions

static func get_market_actions(session: SessionStateStoreScript.SessionData) -> Array:
	if _read_cache_has(session, "market_actions"):
		return _read_cache_get(session, "market_actions")
	var town := get_active_town(session)
	if town.is_empty():
		var empty := []
		_read_cache_store(session, "market_actions", empty)
		return empty
	var actions: Array = OverworldRulesScript.get_town_market_actions(session, town)
	_read_cache_store(session, "market_actions", actions)
	return actions

static func get_hero_actions(session: SessionStateStoreScript.SessionData) -> Array:
	if _read_cache_has(session, "hero_actions"):
		return _read_cache_get(session, "hero_actions")
	var town := get_active_town(session)
	if town.is_empty():
		var empty := []
		_read_cache_store(session, "hero_actions", empty)
		return empty
	var actions: Array = HeroCommandRulesScript.get_town_switch_actions(session, town)
	_read_cache_store(session, "hero_actions", actions)
	return actions

static func get_tavern_actions(session: SessionStateStoreScript.SessionData) -> Array:
	if _read_cache_has(session, "tavern_actions"):
		return _read_cache_get(session, "tavern_actions")
	var town := get_active_town(session)
	if town.is_empty():
		var empty := []
		_read_cache_store(session, "tavern_actions", empty)
		return empty
	var actions: Array = HeroCommandRulesScript.get_tavern_actions(session, town)
	_read_cache_store(session, "tavern_actions", actions)
	return actions

static func get_transfer_actions(session: SessionStateStoreScript.SessionData) -> Array:
	if _read_cache_has(session, "transfer_actions"):
		return _read_cache_get(session, "transfer_actions")
	var town := get_active_town(session)
	if town.is_empty():
		var empty := []
		_read_cache_store(session, "transfer_actions", empty)
		return empty
	var actions: Array = HeroCommandRulesScript.get_town_transfer_actions(session, town)
	_read_cache_store(session, "transfer_actions", actions)
	return actions

static func get_response_actions(session: SessionStateStoreScript.SessionData) -> Array:
	if _read_cache_has(session, "response_actions"):
		return _read_cache_get(session, "response_actions")
	var town := get_active_town(session)
	if town.is_empty():
		var empty := []
		_read_cache_store(session, "response_actions", empty)
		return empty
	var actions: Array = OverworldRulesScript.get_town_response_actions(session, town)
	_read_cache_store(session, "response_actions", actions)
	return actions

static func get_spell_learning_actions(session: SessionStateStoreScript.SessionData) -> Array:
	if _read_cache_has(session, "spell_learning_actions"):
		return _read_cache_get(session, "spell_learning_actions")
	var town := get_active_town(session)
	if town.is_empty():
		var empty := []
		_read_cache_store(session, "spell_learning_actions", empty)
		return empty

	var actions := []
	var hero = session.overworld.get("hero", {})
	for spell_id in accessible_spell_ids(town):
		if SpellRulesScript.knows_spell(hero, spell_id):
			continue
		var spell := ContentService.get_spell(spell_id)
		if spell.is_empty():
			continue
		var mana_cost: int = HeroProgressionRulesScript.adjusted_mana_cost(hero, int(spell.get("mana_cost", 0)))
		actions.append(
			{
				"id": "learn_spell:%s" % spell_id,
				"label": "Learn %s (%d mana)" % [String(spell.get("name", spell_id)), mana_cost],
				"summary": "%s\n%s" % [
					String(spell.get("name", spell_id)),
					SpellRulesScript.describe_spell_inspection_line(hero, spell),
				],
				"cost": mana_cost,
				"category": SpellRulesScript.spell_category_label(spell),
				"disabled": false,
			}
		)
	_read_cache_store(session, "spell_learning_actions", actions)
	return actions

static func get_artifact_actions(session: SessionStateStoreScript.SessionData) -> Array:
	if _read_cache_has(session, "artifact_actions"):
		return _read_cache_get(session, "artifact_actions")
	var actions: Array = ArtifactRulesScript.get_management_actions(session.overworld.get("hero", {}))
	_read_cache_store(session, "artifact_actions", actions)
	return actions

static func get_specialty_actions(session: SessionStateStoreScript.SessionData) -> Array:
	if _read_cache_has(session, "specialty_actions"):
		return _read_cache_get(session, "specialty_actions")
	var actions: Array = HeroProgressionRulesScript.get_choice_actions(session.overworld.get("hero", {}))
	_read_cache_store(session, "specialty_actions", actions)
	return actions

static func build_active_town(session: SessionStateStoreScript.SessionData, building_id: String) -> Dictionary:
	return OverworldRulesScript.build_in_active_town(session, building_id)

static func switch_active_hero_at_town(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	var town := get_active_town(session)
	if town.is_empty():
		return {"ok": false, "message": "No town is available for command changes."}
	var stationed: Array = HeroCommandRulesScript.stationed_heroes(session, town)
	var stationed_here := false
	for hero in stationed:
		if hero is Dictionary and String(hero.get("id", "")) == hero_id:
			stationed_here = true
			break
	if not stationed_here:
		return {"ok": false, "message": "Only heroes stationed in the active town can take command here."}
	var result: Dictionary = HeroCommandRulesScript.set_active_hero(session, hero_id)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "Unable to change command."))}
	return _finalize_town_result(session, true, String(result.get("message", "")))

static func recruit_active_town(session: SessionStateStoreScript.SessionData, unit_id: String, requested_count: int = -1) -> Dictionary:
	return OverworldRulesScript.recruit_in_active_town(session, unit_id, requested_count)

static func perform_market_action(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	var town := get_active_town(session)
	if town.is_empty():
		return {"ok": false, "message": "No town is available for exchange orders."}
	return OverworldRulesScript.perform_town_market_action(session, town, action_id)

static func hire_hero_at_active_town(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	var town := get_active_town(session)
	if town.is_empty():
		return {"ok": false, "message": "No town is available for hero recruitment."}
	var result: Dictionary = HeroCommandRulesScript.recruit_hero_at_town(session, town, hero_id)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "Hero recruitment failed."))}
	return _finalize_town_result(session, true, String(result.get("message", "")))

static func transfer_in_active_town(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	var town := get_active_town(session)
	if town.is_empty():
		return {"ok": false, "message": "No town is available for transfer orders."}
	var parts := action_id.split(":")
	if parts.size() != 5 or parts[0] != "transfer":
		return {"ok": false, "message": "That transfer order is invalid."}
	var result: Dictionary = HeroCommandRulesScript.transfer_town_stack(session, town, parts[1], parts[2], parts[3], parts[4])
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "Transfer failed."))}
	return _finalize_town_result(session, true, String(result.get("message", "")))

static func perform_response_action(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	var town := get_active_town(session)
	if town.is_empty():
		return {"ok": false, "message": "No town is available for strategic response orders."}
	return OverworldRulesScript.perform_town_response_action(session, town, action_id)

static func learn_spell_at_active_town(session: SessionStateStoreScript.SessionData, spell_id: String) -> Dictionary:
	var town := get_active_town(session)
	if town.is_empty():
		return {"ok": false, "message": "No town archives are available here."}
	if spell_id not in accessible_spell_ids(town):
		return {"ok": false, "message": "That spell is not catalogued in this town."}

	var hero_value: Variant = session.overworld.get("hero", {})
	var hero: Dictionary = hero_value if hero_value is Dictionary else {}
	var result: Dictionary = SpellRulesScript.learn_spell(hero, spell_id)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "Study failed."))}

	session.overworld["hero"] = result.get("hero", hero)
	var message := "%s in %s" % [String(result.get("message", "Spell learned.")), _town_name(town)]
	return _finalize_town_result(session, true, message)

static func manage_artifact_at_active_town(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	return OverworldRulesScript.perform_artifact_action(session, action_id)

static func choose_specialty_at_active_town(session: SessionStateStoreScript.SessionData, specialty_id: String) -> Dictionary:
	return OverworldRulesScript.choose_specialty(session, specialty_id)

static func current_spell_tier(town: Dictionary) -> int:
	var highest_tier := 0
	for building_id_value in town.get("built_buildings", []):
		var building := ContentService.get_building(String(building_id_value))
		highest_tier = max(highest_tier, int(building.get("spell_tier", 0)))
	return highest_tier

static func accessible_spell_ids(town: Dictionary) -> Array:
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var tier := current_spell_tier(town)
	if tier <= 0:
		return []

	var spell_ids := []
	for entry in town_template.get("spell_library", []):
		if not (entry is Dictionary):
			continue
		if int(entry.get("tier", 0)) > tier:
			continue
		for spell_id_value in entry.get("spell_ids", []):
			var spell_id := String(spell_id_value)
			if spell_id != "" and spell_id not in spell_ids:
				spell_ids.append(spell_id)
	return spell_ids

static func _build_order_ledger_line(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	var build_actions := get_build_actions(session)
	for action in build_actions:
		if action is Dictionary and not bool(action.get("disabled", false)):
			return "%s is ready now." % String(action.get("ledger_line", action.get("label", "Build order")))
	for action in build_actions:
		if action is Dictionary and bool(action.get("market_coverable", false)):
			return "%s waits on stores. Exchange path: %s." % [
				String(action.get("ledger_line", action.get("label", "Build order"))),
				String(action.get("market_summary", "trade through the exchange")),
			]
	for action in build_actions:
		if action is Dictionary:
			var shortfall := String(action.get("shortfall_summary", ""))
			if shortfall != "":
				return "%s is blocked by reserves: %s." % [
					String(action.get("ledger_line", action.get("label", "Build order"))),
					shortfall,
				]
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var built_buildings = town.get("built_buildings", [])
	for building_id_value in town_template.get("buildable_building_ids", []):
		var building_id := String(building_id_value)
		if building_id == "" or building_id in built_buildings:
			continue
		var build_status: Dictionary = OverworldRulesScript.get_town_build_status(town, building_id)
		if bool(build_status.get("buildable", false)):
			continue
		return "%s stays deferred: %s." % [
			String(ContentService.get_building(building_id).get("name", building_id)),
			String(build_status.get("blocked_message", "No opening order is available.")),
		]
	return "No new works are open in this town."

static func _recruit_order_ledger_line(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	var recruit_actions := get_recruit_actions(session)
	var best_ready := {}
	var best_market := {}
	var best_blocked := {}
	for action in recruit_actions:
		if not (action is Dictionary):
			continue
		if int(action.get("direct_affordable_count", 0)) > int(best_ready.get("direct_affordable_count", 0)):
			best_ready = action
		if int(action.get("market_affordable_count", 0)) > int(best_market.get("market_affordable_count", 0)):
			best_market = action
		if int(action.get("available_count", 0)) > int(best_blocked.get("available_count", 0)):
			best_blocked = action
	if not best_ready.is_empty() and int(best_ready.get("direct_affordable_count", 0)) > 0:
		return "%s can field %d now from current stores." % [
			String(best_ready.get("label", "Recruit order")).trim_prefix("Recruit "),
			int(best_ready.get("direct_affordable_count", 0)),
		]
	if not best_market.is_empty() and int(best_market.get("market_affordable_count", 0)) > 0:
		return "%s x%d wait in reserve. Exchange can unlock %d now: %s." % [
			String(best_market.get("label", "Recruit order")).trim_prefix("Recruit "),
			int(best_market.get("available_count", 0)),
			int(best_market.get("market_affordable_count", 0)),
			String(best_market.get("market_summary", "trade through the exchange")),
		]
	if not best_blocked.is_empty() and int(best_blocked.get("available_count", 0)) > 0:
		var blocker := String(best_blocked.get("shortfall_summary", "stores are too thin"))
		return "%s x%d wait in reserve, but %s." % [
			String(best_blocked.get("label", "Recruit order")).trim_prefix("Recruit "),
			int(best_blocked.get("available_count", 0)),
			blocker,
		]
	var next_levy_day: int = OverworldRulesScript.next_weekly_growth_day(session.day)
	var best_empty_unit_id := ""
	var best_empty_growth := 0
	for unit_id in _town_unit_ids(town):
		if not _unit_is_unlocked_in_town(town, unit_id):
			continue
		var available := int(town.get("available_recruits", {}).get(unit_id, 0))
		var growth := int(OverworldRulesScript.town_weekly_growth(town, session).get(unit_id, 0))
		if available <= 0 and growth > best_empty_growth:
			best_empty_growth = growth
			best_empty_unit_id = unit_id
	if best_empty_unit_id != "":
		var sources := _growth_source_summary(town, best_empty_unit_id)
		return "%s reserve is empty. Next levy Day %d adds %d%s." % [
			String(ContentService.get_unit(best_empty_unit_id).get("name", best_empty_unit_id)),
			next_levy_day,
			best_empty_growth,
			" via %s" % sources if sources != "" else "",
		]
	for unit_id in _town_unit_ids(town):
		if _unit_is_unlocked_in_town(town, unit_id):
			continue
		var unlock_building_id := _unlock_building_for_unit(town, unit_id)
		if unlock_building_id == "":
			continue
		var build_status: Dictionary = OverworldRulesScript.get_town_build_status(town, unlock_building_id)
		return "%s stays locked until %s." % [
			String(ContentService.get_unit(unit_id).get("name", unit_id)),
			String(build_status.get("blocked_message", "the proper works are raised")),
		]
	return "No levy option is currently open."

static func _response_order_ledger_line(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	var response_actions := get_response_actions(session)
	var logistics: Dictionary = OverworldRulesScript.town_logistics_state(session, town)
	var recovery: Dictionary = OverworldRulesScript.town_recovery_state(session, town)
	var movement_state := _active_hero_movement_state(session)
	for action in response_actions:
		if action is Dictionary and not bool(action.get("disabled", false)):
			var movement_clause := ""
			if int(action.get("movement_cost", 0)) > 0:
				movement_clause = " | %d move left after dispatch" % int(action.get("remaining_movement_after_order", 0))
			var delivery_clause := ""
			if String(action.get("delivery_summary", "")) != "":
				delivery_clause = " | %s" % String(action.get("delivery_summary", ""))
			return "%s is ready now%s%s." % [
				String(action.get("label", "Response order")),
				movement_clause,
				delivery_clause,
			]
	for action in response_actions:
		if action is Dictionary and bool(action.get("market_coverable", false)):
			return "%s waits on stores. Exchange path: %s." % [
				String(action.get("label", "Response order")),
				String(action.get("market_summary", "trade through the exchange")),
			]
	for action in response_actions:
		if action is Dictionary and bool(action.get("movement_blocked", false)):
			return "%s needs %d move, but the active commander only has %d/%d." % [
				String(action.get("label", "Response order")),
				int(action.get("movement_cost", 0)),
				int(movement_state.get("current", 0)),
				int(movement_state.get("max", 0)),
			]
	for action in response_actions:
		if action is Dictionary and bool(action.get("resource_blocked", false)):
			return "%s is blocked by reserves: %s." % [
				String(action.get("label", "Response order")),
				_cost_shortfall_line(OverworldRulesScript.town_cost_readiness(
					town,
					session.overworld.get("resources", {}),
					action.get("resource_cost", {})
				)),
			]
	if bool(recovery.get("active", false)):
		return "%s | Stabilization still needs %d day%s at %d/day relief." % [
			String(logistics.get("summary", "Routes are strained")),
			int(recovery.get("days_to_clear", 0)),
			"" if int(recovery.get("days_to_clear", 0)) == 1 else "s",
			int(recovery.get("relief_per_day", 1)),
		]
	if int(logistics.get("disrupted_count", 0)) > 0 or int(logistics.get("threatened_count", 0)) > 0:
		return "%s. No linked response order is currently open from this town." % _logistics_watch_summary(logistics)
	return "No immediate route or recovery order is open."

static func _coverage_order_ledger_line(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	var stationed: Array = HeroCommandRulesScript.stationed_heroes(session, town)
	var reserve_names := []
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	for hero in stationed:
		if not (hero is Dictionary):
			continue
		if String(hero.get("id", "")) == active_hero_id:
			continue
		reserve_names.append(String(hero.get("name", "Reserve commander")))
	var movement_state := _active_hero_movement_state(session)
	if reserve_names.is_empty():
		return "No reserve commander covers the walls if the field hero rides out. Active command holds %d/%d move." % [
			int(movement_state.get("current", 0)),
			int(movement_state.get("max", 0)),
		]
	var shown_names := reserve_names.slice(0, min(2, reserve_names.size()))
	var names := ", ".join(shown_names)
	if reserve_names.size() > shown_names.size():
		names += ", and %d more" % (reserve_names.size() - shown_names.size())
	return "%s cover the walls while active command holds %d/%d move for town orders." % [
		names,
		int(movement_state.get("current", 0)),
		int(movement_state.get("max", 0)),
	]

static func _town_recommendation_line(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	var recommendation := _town_recommendation_action(session, town)
	if recommendation.is_empty():
		return _next_town_action_line(session, town)
	var label := _short_action_label(recommendation, "Town order")
	var impact := String(recommendation.get("impact_line", "")).trim_suffix(".")
	var readiness := String(recommendation.get("affordability_label", ""))
	if readiness == "":
		readiness = String(recommendation.get("disabled_reason", ""))
	if impact != "" and readiness != "":
		return "%s | %s | %s" % [label, readiness, impact]
	if impact != "":
		return "%s | %s" % [label, impact]
	if readiness != "":
		return "%s | %s" % [label, readiness]
	return "%s is the clearest town order." % label

static func _town_recommendation_action(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	var best_action := {}
	var best_score := -999999
	for action in get_build_actions(session):
		if not (action is Dictionary):
			continue
		var score := _town_build_recommendation_score(town, action)
		if score > best_score:
			best_score = score
			best_action = action
	for action in get_recruit_actions(session):
		if not (action is Dictionary):
			continue
		var score := _town_recruit_recommendation_score(action)
		if score > best_score:
			best_score = score
			best_action = action
	return best_action

static func _town_build_recommendation_score(town: Dictionary, action: Dictionary) -> int:
	var building_id := String(action.get("id", "")).trim_prefix("build:")
	var building := ContentService.get_building(building_id)
	var score := 0
	if bool(action.get("direct_affordable", false)):
		score += 120
	elif bool(action.get("market_coverable", false)):
		score += 70
	else:
		score += 20
	match String(building.get("category", "")):
		"dwelling":
			score += 28
		"support":
			score += 24
		"economy":
			score += 18
		"magic":
			score += 12
		"civic":
			score += 10
	if String(building.get("unlock_unit_id", "")) != "":
		score += 18
	var growth = building.get("growth_bonus", {})
	if growth is Dictionary:
		for unit_id in growth.keys():
			score += max(0, int(growth.get(unit_id, 0))) * 3
	score += max(0, int(building.get("readiness_bonus", 0))) * 2
	score += max(0, int(building.get("pressure_bonus", 0))) * 8
	var income = building.get("income", {})
	if income is Dictionary:
		score += min(18, int(floori(float(int(income.get("gold", 0))) / 50.0)))
	if OverworldRulesScript.town_strategic_role(town) == "stronghold":
		score += max(0, int(building.get("readiness_bonus", 0)))
	return score

static func _town_recruit_recommendation_score(action: Dictionary) -> int:
	var ready_count := int(action.get("direct_affordable_count", 0))
	var market_count := int(action.get("market_affordable_count", 0))
	var unit_id := String(action.get("id", "")).trim_prefix("recruit:")
	var score := 0
	if ready_count > 0:
		score += 105
	elif market_count > 0:
		score += 62
	else:
		score += 15
	score += min(40, int(floori(float(OverworldRulesScript.unit_stack_strength_value(unit_id, max(ready_count, 1))) / 6.0)))
	score += min(16, int(action.get("available_count", 0)) * 2)
	score += min(12, int(action.get("weekly_growth", 0)) * 2)
	return score

static func _build_choice_impact_line(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	building_id: String,
	building: Dictionary
) -> String:
	var projected_town := town.duplicate(true)
	var built_buildings = projected_town.get("built_buildings", [])
	if not (built_buildings is Array):
		built_buildings = []
	built_buildings = built_buildings.duplicate()
	if building_id not in built_buildings:
		built_buildings.append(building_id)
	projected_town["built_buildings"] = built_buildings
	var parts := []
	var readiness_delta: int = OverworldRulesScript.town_battle_readiness(projected_town, session) - OverworldRulesScript.town_battle_readiness(town, session)
	if readiness_delta != 0:
		parts.append("readiness %s" % _signed_int(readiness_delta))
	var quality_delta: int = OverworldRulesScript.town_reinforcement_quality(projected_town, session) - OverworldRulesScript.town_reinforcement_quality(town, session)
	if quality_delta != 0:
		parts.append("muster quality %s" % _signed_int(quality_delta))
	var pressure_delta: int = OverworldRulesScript.town_pressure_output(projected_town, session) - OverworldRulesScript.town_pressure_output(town, session)
	if pressure_delta != 0:
		parts.append("%s %s" % [_town_pressure_label(town).to_lower(), _signed_int(pressure_delta)])
	var unlock_unit_id := String(building.get("unlock_unit_id", ""))
	if unlock_unit_id != "":
		var unit := ContentService.get_unit(unlock_unit_id)
		parts.append("opens %s recruits" % String(unit.get("name", unlock_unit_id)))
	if parts.is_empty():
		match String(building.get("category", "")):
			"economy":
				parts.append("raises income for later build and recruit orders")
			"magic":
				parts.append("opens spell access without changing wall strength now")
			_:
				parts.append("steadies the town without an immediate readiness swing")
	return "Defense/frontier: %s." % " | ".join(parts)

static func _recruit_choice_impact_line(unit_id: String, ready_count: int, available_count: int) -> String:
	var field_count: int = max(0, ready_count)
	if field_count <= 0:
		return "Defense/frontier: reserves are waiting, but stores do not field this stack yet."
	var strength: int = OverworldRulesScript.unit_stack_strength_value(unit_id, field_count)
	return "Defense/frontier: fields strength +%d to the marching army; %d remain in town reserve." % [
		strength,
		max(0, available_count - field_count),
	]

static func _action_recommendation_line(
	lane: String,
	label: String,
	ready: bool,
	market_coverable: bool,
	shortfall_summary: String,
	impact_line: String
) -> String:
	var status := "ready now" if ready else ("needs exchange first" if market_coverable else "blocked")
	var parts := ["%s %s is %s" % [lane, label, status]]
	if not ready and not market_coverable and shortfall_summary != "":
		parts.append("Blocker: %s" % shortfall_summary)
	if impact_line != "":
		parts.append(impact_line)
	return ". ".join(parts)

static func _build_action_badge(ready: bool, market_coverable: bool) -> String:
	if ready:
		return "Ready"
	if market_coverable:
		return "Trade"
	return "Blocked"

static func _recruit_action_badge(ready_count: int, market_count: int) -> String:
	if ready_count > 0:
		return "Ready x%d" % ready_count
	if market_count > 0:
		return "Trade x%d" % market_count
	return "Blocked"

static func _signed_int(value: int) -> String:
	return "%+d" % value

static func _next_town_action_line(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	var build_actions := get_build_actions(session)
	for action in build_actions:
		if not (action is Dictionary) or bool(action.get("disabled", false)):
			continue
		var projection := _action_projection_line(action)
		if projection != "":
			return "%s: %s" % [_short_action_label(action, "Build order"), projection]
		return "%s is ready." % _short_action_label(action, "Build order")

	var recruit_actions := get_recruit_actions(session)
	for action in recruit_actions:
		if not (action is Dictionary) or int(action.get("direct_affordable_count", 0)) <= 0:
			continue
		return "%s fields %d now." % [
			_short_action_label(action, "Recruit order"),
			int(action.get("direct_affordable_count", 0)),
		]

	for action in get_response_actions(session):
		if action is Dictionary and not bool(action.get("disabled", false)):
			return "%s secures the frontier chain." % _short_action_label(action, "Response order")

	for action in get_spell_learning_actions(session):
		if action is Dictionary and not bool(action.get("disabled", false)):
			return "%s expands the hero spellbook." % _short_action_label(action, "Study order")

	for action in get_market_actions(session):
		if action is Dictionary and not bool(action.get("disabled", false)):
			return "%s converts stores for blocked orders." % _short_action_label(action, "Exchange")

	for action in build_actions:
		if action is Dictionary and bool(action.get("market_coverable", false)):
			return "Trade first for %s." % _short_action_label(action, "Build order")
	for action in recruit_actions:
		if action is Dictionary and bool(action.get("market_coverable", false)):
			return "Trade first for %s." % _short_action_label(action, "Recruit order")
	for action in build_actions:
		if action is Dictionary:
			return "%s blocked: %s." % [
				_short_action_label(action, "Build order"),
				String(action.get("disabled_reason", "stores are too thin")).trim_prefix("Blocked: "),
			]
	for action in recruit_actions:
		if action is Dictionary:
			return "%s blocked: %s." % [
				_short_action_label(action, "Recruit order"),
				String(action.get("disabled_reason", "stores are too thin")).trim_prefix("Blocked: "),
			]
	var weekly_growth := _describe_recruit_delta(OverworldRulesScript.town_weekly_growth(town, session))
	if weekly_growth != "none":
		return "Hold for Day %d muster (%s)." % [
			OverworldRulesScript.next_weekly_growth_day(session.day),
			weekly_growth,
		]
	return "Leave town; no production order is open."

static func _first_ready_action(actions: Array) -> Dictionary:
	for action in actions:
		if action is Dictionary and not bool(action.get("disabled", false)):
			return action
	return {}

static func _town_handoff_affected_line(
	town_name: String,
	front: Dictionary,
	occupation: Dictionary,
	logistics: Dictionary,
	ready_response: Dictionary
) -> String:
	if bool(occupation.get("active", false)):
		return "%s occupation and recovery front" % town_name
	if bool(front.get("active", false)):
		var enemy_label := String(front.get("enemy_label", ""))
		if enemy_label != "":
			return "%s %s front against %s" % [town_name, String(front.get("mode", "front")).capitalize(), enemy_label]
		return "%s active front" % town_name
	if not ready_response.is_empty():
		return "%s response order: %s" % [
			town_name,
			_short_action_label(ready_response, "Response order"),
		]
	if int(logistics.get("disrupted_count", 0)) > 0 or int(logistics.get("threatened_count", 0)) > 0:
		return "%s frontier support chain" % town_name
	return "%s town order queue and return route" % town_name

static func _town_handoff_why_line(
	town: Dictionary,
	front: Dictionary,
	occupation: Dictionary,
	logistics: Dictionary,
	recovery: Dictionary,
	ready_response: Dictionary
) -> String:
	if bool(occupation.get("active", false)) and String(occupation.get("summary", "")) != "":
		return String(occupation.get("summary", ""))
	if bool(front.get("active", false)) and String(front.get("summary", "")) != "":
		return String(front.get("summary", ""))
	if not ready_response.is_empty():
		var delivery_summary := String(ready_response.get("delivery_summary", ""))
		if delivery_summary != "":
			return "dispatch can carry reserves into the next field route: %s" % delivery_summary
		return "dispatch can steady a linked frontier route before enemy pressure compounds"
	var logistics_summary := _logistics_watch_summary(logistics)
	if int(logistics.get("disrupted_count", 0)) > 0 or int(logistics.get("threatened_count", 0)) > 0 or int(logistics.get("support_gap", 0)) > 0:
		return logistics_summary
	if bool(recovery.get("active", false)) and String(recovery.get("summary", "")) != "":
		return String(recovery.get("summary", ""))
	return "%s orders shape the army, walls, and field route before leaving town" % _town_name(town)

static func _town_handoff_next_line(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	ready_response: Dictionary,
	movement: Dictionary
) -> String:
	if not ready_response.is_empty():
		var label := _short_action_label(ready_response, "Response order")
		var move_left := int(ready_response.get("remaining_movement_after_order", movement.get("current", 0)))
		return "Use %s in Logistics, then leave for the field route with %d move." % [label, move_left]
	var next_town_action := _next_town_action_line(session, town)
	if int(movement.get("current", 0)) <= 0:
		return "%s Then leave town and end the day to refresh movement." % next_town_action
	return "%s Then Leave to resume the field route with %d/%d move." % [
		next_town_action,
		int(movement.get("current", 0)),
		int(movement.get("max", 0)),
	]

static func _short_town_handoff_text(text: String, max_chars: int) -> String:
	var trimmed := text.strip_edges().replace("\n", " ")
	if max_chars <= 3 or trimmed.length() <= max_chars:
		return trimmed
	return "%s..." % trimmed.left(max_chars - 3)

static func _short_action_label(action: Dictionary, fallback: String) -> String:
	var label := String(action.get("label", fallback))
	for prefix in ["Build ", "Recruit ", "Learn "]:
		if label.begins_with(prefix):
			return label.trim_prefix(prefix)
	return label

static func _action_projection_line(action: Dictionary) -> String:
	var summary_lines := String(action.get("summary", "")).split("\n", false)
	for line_value in summary_lines:
		var line := String(line_value).strip_edges()
		if not line.begins_with("Projection:"):
			continue
		line = line.trim_prefix("Projection:").strip_edges().trim_suffix(".")
		if line.length() > 72:
			line = "%s..." % line.left(69)
		return line
	return ""

static func _town_action_happened_line(lane: String, action_id: String, action: Dictionary, message: String) -> String:
	var first_sentence := _first_sentence(message)
	if first_sentence != "":
		return first_sentence
	var label := _short_action_label(action, action_id)
	match lane:
		"build":
			return "Built %s." % label
		"recruit":
			return "Recruited %s." % label
		"market":
			return "%s resolved through the exchange." % label
		"response":
			return "%s resolved as a frontier order." % label
		_:
			return "%s resolved." % label

static func _town_action_affected_line(
	lane: String,
	action_id: String,
	action: Dictionary,
	before: Dictionary,
	after: Dictionary
) -> String:
	var parts := []
	match lane:
		"build":
			var building_id := action_id.trim_prefix("build:")
			var building := ContentService.get_building(building_id)
			parts.append("Building %s" % String(building.get("name", _short_action_label(action, building_id))))
		"recruit":
			var unit_id := action_id.trim_prefix("recruit:")
			var unit := ContentService.get_unit(unit_id)
			parts.append("Unit %s" % String(unit.get("name", _short_action_label(action, unit_id))))
		"market":
			parts.append(_market_action_target_line(action_id, action))
		"response":
			parts.append("Order %s" % _short_action_label(action, action_id))
		_:
			parts.append("Order %s" % _short_action_label(action, action_id))
	var built_delta := _built_delta_summary(before.get("built_buildings", []), after.get("built_buildings", []))
	if built_delta != "":
		parts.append(built_delta)
	var resource_delta := _signed_resource_delta_summary(before.get("resources", {}), after.get("resources", {}))
	if resource_delta != "":
		parts.append(resource_delta)
	var reserve_delta := _signed_recruit_delta_summary(before.get("available_recruits", {}), after.get("available_recruits", {}), "Reserve")
	if reserve_delta != "":
		parts.append(reserve_delta)
	var army_delta := _signed_recruit_delta_summary(before.get("army_counts", {}), after.get("army_counts", {}), "Field")
	if army_delta != "":
		parts.append(army_delta)
	if parts.size() <= 1:
		parts.append("Town queue and stores updated.")
	return " | ".join(parts)

static func _town_action_matters_line(
	session: SessionStateStoreScript.SessionData,
	lane: String,
	before: Dictionary,
	after: Dictionary
) -> String:
	var parts := []
	var readiness_delta := int(after.get("battle_readiness", 0)) - int(before.get("battle_readiness", 0))
	if readiness_delta != 0:
		parts.append("readiness %s" % _signed_int(readiness_delta))
	var quality_delta := int(after.get("reinforcement_quality", 0)) - int(before.get("reinforcement_quality", 0))
	if quality_delta != 0:
		parts.append("muster quality %s" % _signed_int(quality_delta))
	var pressure_delta := int(after.get("pressure_output", 0)) - int(before.get("pressure_output", 0))
	if pressure_delta != 0:
		var town := get_active_town(session)
		parts.append("%s %s" % [_town_pressure_label(town).to_lower(), _signed_int(pressure_delta)])
	var income_delta := _signed_resource_delta_summary(before.get("income", {}), after.get("income", {}), "Income")
	if income_delta != "":
		parts.append(income_delta)
	var growth_delta := _signed_recruit_delta_summary(before.get("weekly_growth", {}), after.get("weekly_growth", {}), "Weekly muster")
	if growth_delta != "":
		parts.append(growth_delta)
	var logistics_summary := String(after.get("logistics_summary", ""))
	if logistics_summary != "" and logistics_summary != String(before.get("logistics_summary", "")):
		parts.append("logistics %s" % logistics_summary)
	if bool(after.get("front_active", false)) and String(after.get("front_summary", "")) != "":
		parts.append(String(after.get("front_summary", "")))
	if not parts.is_empty():
		return "Production/defense now shows %s." % " | ".join(parts)
	match lane:
		"market":
			return "Stores shifted, so the next blocked build or recruit order may be closer."
		"recruit":
			return "The marching army is stronger while the town reserve is thinner."
		"build":
			return "The town engine changed even if frontier numbers stayed steady this turn."
		"response":
			return "The frontier chain was acted on before enemy pressure can compound."
		_:
			return "The town state changed; review the next available order before leaving."

static func _town_action_next_line(session: SessionStateStoreScript.SessionData) -> String:
	var town := get_active_town(session)
	if town.is_empty():
		return "Return to the overworld."
	return _next_town_action_line(session, town)

static func _first_sentence(text: String) -> String:
	var trimmed := text.strip_edges()
	if trimmed == "":
		return ""
	var period_index := trimmed.find(".")
	if period_index < 0:
		return trimmed
	return trimmed.left(period_index + 1)

static func _market_action_target_line(action_id: String, action: Dictionary) -> String:
	var parts := action_id.split(":")
	if parts.size() == 4 and parts[0] == "market":
		return "Exchange %s %d %s" % [
			String(parts[1]),
			int(parts[3]),
			String(parts[2]),
		]
	return "Exchange %s" % _short_action_label(action, action_id)

static func _built_delta_summary(before_value: Variant, after_value: Variant) -> String:
	var before := _normalize_string_array(before_value)
	var after := _normalize_string_array(after_value)
	var added := []
	for building_id in after:
		if building_id in before:
			continue
		var building := ContentService.get_building(building_id)
		added.append(String(building.get("name", building_id)))
	if added.is_empty():
		return ""
	return "Built %s" % ", ".join(added)

static func _signed_resource_delta_summary(before_value: Variant, after_value: Variant, label: String = "Stores") -> String:
	var before := _duplicate_dictionary(before_value)
	var after := _duplicate_dictionary(after_value)
	var parts := []
	for resource_key in ["gold", "wood", "ore"]:
		var delta := int(after.get(resource_key, 0)) - int(before.get(resource_key, 0))
		if delta == 0:
			continue
		parts.append("%s %s" % [resource_key, _signed_int(delta)])
	return "%s %s" % [label, ", ".join(parts)] if not parts.is_empty() else ""

static func _signed_recruit_delta_summary(before_value: Variant, after_value: Variant, label: String) -> String:
	var before := _duplicate_dictionary(before_value)
	var after := _duplicate_dictionary(after_value)
	var unit_ids := []
	for unit_id_value in before.keys():
		var before_unit_id := String(unit_id_value)
		if before_unit_id not in unit_ids:
			unit_ids.append(before_unit_id)
	for unit_id_value in after.keys():
		var after_unit_id := String(unit_id_value)
		if after_unit_id not in unit_ids:
			unit_ids.append(after_unit_id)
	unit_ids.sort()
	var parts := []
	for unit_id in unit_ids:
		var delta := int(after.get(unit_id, 0)) - int(before.get(unit_id, 0))
		if delta == 0:
			continue
		var unit := ContentService.get_unit(unit_id)
		parts.append("%s %s" % [String(unit.get("name", unit_id)), _signed_int(delta)])
	return "%s %s" % [label, ", ".join(parts)] if not parts.is_empty() else ""

static func _army_unit_counts(army: Variant) -> Dictionary:
	var counts := {}
	var stacks = army.get("stacks", []) if army is Dictionary else []
	if not (stacks is Array):
		return counts
	for stack in stacks:
		if not (stack is Dictionary):
			continue
		var unit_id := String(stack.get("unit_id", ""))
		if unit_id == "":
			continue
		counts[unit_id] = int(counts.get(unit_id, 0)) + max(0, int(stack.get("count", 0)))
	return counts

static func _duplicate_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

static func _normalize_string_array(value: Variant) -> Array[String]:
	var normalized: Array[String] = []
	if not (value is Array):
		return normalized
	for entry in value:
		var text := String(entry)
		if text != "":
			normalized.append(text)
	return normalized

static func _market_coverage_line(readiness: Dictionary) -> String:
	var actions = readiness.get("market_actions", [])
	if not (actions is Array) or actions.is_empty():
		return ""
	var shown := []
	for index in range(min(2, actions.size())):
		shown.append(String(actions[index]))
	var summary := "; ".join(shown)
	if actions.size() > 2:
		summary += "; %d more step%s" % [
			actions.size() - 2,
			"" if actions.size() - 2 == 1 else "s",
		]
	return summary

static func _cost_shortfall_line(readiness: Dictionary) -> String:
	var shortfall_summary := _describe_resources(readiness.get("direct_shortfall", {}), "")
	var gold_short := int(max(
		0,
		int(readiness.get("required_gold_total", 0)) - int(readiness.get("available_gold_total", 0))
	))
	if shortfall_summary != "":
		if bool(readiness.get("market_active", false)) and gold_short > 0:
			return "need %s, and even a full exchange leaves %d gold short" % [shortfall_summary, gold_short]
		return "need %s" % shortfall_summary
	if gold_short > 0:
		if bool(readiness.get("market_active", false)):
			return "even a full exchange leaves %d gold short" % gold_short
		return "need %d more gold" % gold_short
	return "stores are too thin"

static func _cost_readiness_line(resources: Dictionary, cost: Variant, readiness: Dictionary) -> String:
	if not (cost is Dictionary) or cost.is_empty():
		return "Ready: no resource cost."
	var stock_line := _stock_against_cost_line(resources, cost)
	if bool(readiness.get("direct_affordable", false)):
		return "Ready: stores cover %s." % stock_line
	if bool(readiness.get("market_affordable", false)) and bool(readiness.get("market_active", false)):
		return "Needs exchange: stores show %s." % stock_line
	var shortfall := _cost_shortfall_line(readiness)
	return "Blocked: %s." % shortfall

static func _stock_against_cost_line(resources: Dictionary, cost: Variant) -> String:
	if not (cost is Dictionary) or cost.is_empty():
		return "no cost"
	var parts := []
	for resource_key in ["gold", "wood", "ore"]:
		var required := int(cost.get(resource_key, 0))
		if required <= 0:
			continue
		parts.append("%s %d/%d" % [resource_key, int(resources.get(resource_key, 0)), required])
	return ", ".join(parts) if not parts.is_empty() else "no cost"

static func _stores_after_cost_line(resources: Dictionary, cost: Variant) -> String:
	if not (cost is Dictionary):
		return ""
	var after := {}
	for resource_key in ["gold", "wood", "ore"]:
		after[resource_key] = max(0, int(resources.get(resource_key, 0)) - int(cost.get(resource_key, 0)))
	return _describe_resources(after, "none")

static func _recruit_affordability_label(direct_count: int, market_count: int, shortfall_summary: String) -> String:
	if direct_count > 0:
		return "Ready now x%d" % direct_count
	if market_count > 0:
		return "Needs exchange x%d" % market_count
	if shortfall_summary != "":
		return "Blocked: %s" % shortfall_summary
	return "Blocked: stores are too thin"

static func _disabled_reason_line(ready: bool, market_coverable: bool, market_summary: String, shortfall_summary: String) -> String:
	if ready:
		return ""
	if market_coverable and market_summary != "":
		return "Use exchange first: %s" % market_summary
	if shortfall_summary != "":
		return "Blocked: %s" % shortfall_summary
	return "Blocked: stores are too thin"

static func _max_market_affordable_count(
	town: Dictionary,
	resources: Dictionary,
	unit_cost: Variant,
	available_count: int
) -> int:
	for recruit_count in range(max(available_count, 0), 0, -1):
		if OverworldRulesScript.can_afford_cost_with_town_market(
			town,
			resources,
			_multiply_resource_cost(unit_cost, recruit_count)
		):
			return recruit_count
	return 0

static func _multiply_resource_cost(cost: Variant, multiplier: int) -> Dictionary:
	var scaled := {}
	if cost is Dictionary:
		for key in cost.keys():
			scaled[String(key)] = int(cost[key]) * multiplier
	return scaled

static func _find_active_town_result(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return OverworldRulesScript.active_town_visit_result(session)

static func _available_building_ids(town: Dictionary) -> Array:
	return OverworldRulesScript.get_town_build_options(town)

static func _building_line(building_id: String, state: String, build_status: Dictionary = {}) -> String:
	var building := ContentService.get_building(building_id)
	var parts := [String(building.get("name", building_id))]
	var effect_summary := _building_effect_summary(building)
	if effect_summary != "":
		parts.append(effect_summary)
	if state == "locked":
		var blocked_message := String(build_status.get("blocked_message", ""))
		if blocked_message != "":
			parts.append(blocked_message)
	return " | ".join(parts)

static func _building_effect_summary(building: Dictionary) -> String:
	var parts := []
	var category := String(building.get("category", ""))
	if category != "":
		parts.append(category.capitalize())
	var upgrade_from := String(building.get("upgrade_from", ""))
	if upgrade_from != "":
		var upgrade_building := ContentService.get_building(upgrade_from)
		parts.append("Upgrades %s" % String(upgrade_building.get("name", upgrade_from)))
	var income := _describe_resources(building.get("income", {}), "")
	if income != "":
		parts.append("Income %s" % income)
	var market_summary := _market_building_summary(building)
	if market_summary != "":
		parts.append(market_summary)
	var unlock_unit_id := String(building.get("unlock_unit_id", ""))
	if unlock_unit_id != "":
		var unit := ContentService.get_unit(unlock_unit_id)
		parts.append("Trains %s" % String(unit.get("name", unlock_unit_id)))
	if int(building.get("spell_tier", 0)) > 0:
		parts.append("Spell Tier %d" % int(building.get("spell_tier", 0)))
	var growth_bonus = building.get("growth_bonus", {})
	if growth_bonus is Dictionary and not growth_bonus.is_empty():
		var growth_parts := []
		for unit_id in growth_bonus.keys():
			var unit := ContentService.get_unit(String(unit_id))
			growth_parts.append("+%d %s" % [int(growth_bonus[unit_id]), String(unit.get("name", unit_id))])
		growth_parts.sort()
		parts.append("Growth %s" % ", ".join(growth_parts))
	var recruit_discount = building.get("recruitment_discount_percent", {})
	if recruit_discount is Dictionary and not recruit_discount.is_empty():
		var discount_parts := []
		for unit_id in recruit_discount.keys():
			var unit := ContentService.get_unit(String(unit_id))
			discount_parts.append("-%d%% %s" % [int(recruit_discount[unit_id]), String(unit.get("name", unit_id))])
		discount_parts.sort()
		parts.append("Discount %s" % ", ".join(discount_parts))
	if int(building.get("readiness_bonus", 0)) > 0:
		parts.append("Readiness +%d" % int(building.get("readiness_bonus", 0)))
	if int(building.get("pressure_bonus", 0)) > 0:
		parts.append("%s +%d" % [_pressure_noun_for_building(building), int(building.get("pressure_bonus", 0))])
	if int(building.get("recovery_relief", 0)) > 0:
		parts.append("Recovery +%d/day" % int(building.get("recovery_relief", 0)))
	var capital_project = building.get("capital_project", {})
	if capital_project is Dictionary and not capital_project.is_empty():
		parts.append("Capital project")
		if int(capital_project.get("defense_bonus", 0)) > 0:
			parts.append("Defense +%d" % int(capital_project.get("defense_bonus", 0)))
		if int(capital_project.get("max_active_raids_bonus", 0)) > 0:
			parts.append("Raid slots +%d" % int(capital_project.get("max_active_raids_bonus", 0)))
		if int(capital_project.get("recovery_guard", 0)) > 0:
			parts.append("Recovery +%d/day" % int(capital_project.get("recovery_guard", 0)))
		var support_requirements = capital_project.get("support_requirements", {})
		if support_requirements is Dictionary and not support_requirements.is_empty():
			parts.append("Needs %s" % _describe_support_requirements(support_requirements))
		var vulnerability_penalties = capital_project.get("vulnerability_penalties", {})
		if vulnerability_penalties is Dictionary and not vulnerability_penalties.is_empty():
			parts.append("Cut chain: %s" % _describe_vulnerability_penalties(vulnerability_penalties))
	return " | ".join(parts)

static func _describe_building_names(building_ids: Variant) -> String:
	var names := []
	if building_ids is Array:
		for building_id_value in building_ids:
			var building := ContentService.get_building(String(building_id_value))
			names.append(String(building.get("name", building_id_value)))
	return ", ".join(names)

static func _week_of_day(day: int) -> int:
	return int(floori(float(max(day, 1) - 1) / 7.0)) + 1

static func _weekday_of_day(day: int) -> int:
	return ((max(day, 1) - 1) % 7) + 1

static func _locked_building_count(town: Dictionary) -> int:
	var locked_count := 0
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var built_buildings = town.get("built_buildings", [])
	for building_id_value in town_template.get("buildable_building_ids", []):
		var building_id := String(building_id_value)
		if building_id == "" or building_id in built_buildings:
			continue
		if not bool(OverworldRulesScript.get_town_build_status(town, building_id).get("buildable", false)):
			locked_count += 1
	return locked_count

static func _describe_building_category_counts(building_ids: Variant) -> String:
	if not (building_ids is Array):
		return "No standing works"
	var counts := {}
	for building_id_value in building_ids:
		var category := String(ContentService.get_building(String(building_id_value)).get("category", "support"))
		if category == "":
			category = "support"
		counts[category] = int(counts.get(category, 0)) + 1
	if counts.is_empty():
		return "No standing works"
	var categories := counts.keys()
	categories.sort()
	var parts := []
	for category_value in categories:
		var category := String(category_value)
		parts.append("%s %d" % [category.capitalize(), int(counts.get(category, 0))])
	return ", ".join(parts)

static func _describe_garrison(town: Dictionary) -> String:
	var lines := []
	for stack in town.get("garrison", []):
		if not (stack is Dictionary):
			continue
		lines.append(OverworldRulesScript.describe_stack_inspection_line(stack))
	return "; ".join(lines) if not lines.is_empty() else "No standing garrison"

static func _garrison_company_count(town: Dictionary) -> int:
	var companies := 0
	for stack in town.get("garrison", []):
		if stack is Dictionary and int(stack.get("count", 0)) > 0:
			companies += 1
	return companies

static func _garrison_headcount(town: Dictionary) -> int:
	var headcount := 0
	for stack in town.get("garrison", []):
		if stack is Dictionary:
			headcount += max(0, int(stack.get("count", 0)))
	return headcount

static func _garrison_strength(town: Dictionary) -> int:
	var total_strength := 0
	for stack in town.get("garrison", []):
		if not (stack is Dictionary):
			continue
		var unit := ContentService.get_unit(String(stack.get("unit_id", "")))
		var count := int(max(0, int(stack.get("count", 0))))
		total_strength += count * max(
			6,
			int(unit.get("hp", 1))
			+ int(unit.get("min_damage", 1))
			+ int(unit.get("max_damage", 1))
			+ (3 if bool(unit.get("ranged", false)) else 0)
		)
	return total_strength

static func _defense_grade(town: Dictionary) -> String:
	var strength := _garrison_strength(town)
	if strength >= 260:
		return "Fortified Watch"
	if strength >= 140:
		return "Steady Watch"
	if strength > 0:
		return "Thin Watch"
	return "Open Walls"

static func _town_name(town: Dictionary) -> String:
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	return String(town_template.get("name", town.get("town_id", "Town")))

static func _town_identity_summary(town: Dictionary) -> String:
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var summary := String(town_template.get("identity_summary", ""))
	if summary != "":
		return summary
	var faction := ContentService.get_faction(String(town_template.get("faction_id", "")))
	return String(faction.get("identity_summary", "No town identity has been authored yet."))

static func _hero_command_line(hero: Dictionary) -> String:
	return "%s | %s | %s" % [
		HeroCommandRulesScript.hero_identity_context_line(hero),
		HeroCommandRulesScript.hero_progress_context_line(hero),
		HeroCommandRulesScript.hero_readiness_context_line(hero, true),
	]

static func _army_summary(army: Variant) -> String:
	var stacks = army.get("stacks", []) if army is Dictionary else []
	var parts := []
	if stacks is Array:
		for stack in stacks:
			if not (stack is Dictionary):
				continue
			var count := int(max(0, int(stack.get("count", 0))))
			if count <= 0:
				continue
			var unit_id := String(stack.get("unit_id", ""))
			var unit_name := String(ContentService.get_unit(unit_id).get("name", unit_id))
			parts.append("%s x%d" % [unit_name, count])
	return ", ".join(parts) if not parts.is_empty() else "No troops"

static func _growth_source_summary(town: Dictionary, unit_id: String) -> String:
	var source_names := []
	for building_id_value in town.get("built_buildings", []):
		var building_id := String(building_id_value)
		var building := ContentService.get_building(building_id)
		if String(building.get("unlock_unit_id", "")) == unit_id:
			source_names.append(String(building.get("name", building_id)))
			continue
		var growth_bonus = building.get("growth_bonus", {})
		if growth_bonus is Dictionary and int(growth_bonus.get(unit_id, 0)) > 0:
			source_names.append(String(building.get("name", building_id)))
	source_names.sort()
	return ", ".join(source_names)

static func _reinforcement_grade(quality: int) -> String:
	if quality >= 60:
		return "surge-ready"
	if quality >= 36:
		return "field-ready"
	if quality > 0:
		return "thin"
	return "stalled"

static func _town_pressure_label(town: Dictionary) -> String:
	match String(ContentService.get_town(String(town.get("town_id", ""))).get("faction_id", "")):
		"faction_embercourt":
			return "Frontier leverage"
		"faction_mireclaw":
			return "Raid pressure"
		"faction_sunvault":
			return "Relay reach"
		"faction_thornwake":
			return "Root pressure"
		"faction_brasshollow":
			return "Siege pressure"
		"faction_veilmourn":
			return "Fog pressure"
		_:
			return "Pressure"

static func _pressure_noun_for_building(building: Dictionary) -> String:
	var building_id := String(building.get("id", ""))
	if building_id.begins_with("building_war_drum") or building_id.begins_with("building_smugglers") or building_id.begins_with("building_floodtide"):
		return "Pressure"
	if building_id.begins_with("building_resonant") or building_id.begins_with("building_harmonic") or building_id.begins_with("building_aurora"):
		return "Reach"
	if building_id.begins_with("building_thornwake"):
		return "Rooting"
	if building_id.begins_with("building_brasshollow"):
		return "Pressure"
	if building_id.begins_with("building_veilmourn"):
		return "Fog"
	return "Leverage"

static func _market_building_summary(building: Dictionary) -> String:
	match String(building.get("id", "")):
		"building_market_square":
			return "Exchange wood or ore against gold"
		"building_river_granary_exchange":
			return "Bulk wood lots and stronger river timber rates"
		"building_resonant_exchange":
			return "Bulk ore lots and stronger relay crystal rates"
		_:
			return ""

static func _describe_support_requirements(requirements: Dictionary) -> String:
	var parts := []
	for family_id in requirements.keys():
		var count := int(max(0, int(requirements.get(family_id, 0))))
		if count <= 0:
			continue
		var label := ""
		match String(family_id):
			"neutral_dwelling":
				label = "dwelling"
			"faction_outpost":
				label = "outpost"
			"frontier_shrine":
				label = "shrine"
			_:
				label = String(family_id)
		parts.append("%d %s" % [count, label])
	parts.sort()
	return ", ".join(parts)

static func _describe_vulnerability_penalties(penalties: Dictionary) -> String:
	var parts := []
	if int(penalties.get("quality_penalty", 0)) > 0:
		parts.append("quality -%d" % int(penalties.get("quality_penalty", 0)))
	if int(penalties.get("readiness_penalty", 0)) > 0:
		parts.append("readiness -%d" % int(penalties.get("readiness_penalty", 0)))
	if int(penalties.get("pressure_penalty", 0)) > 0:
		parts.append("pressure -%d" % int(penalties.get("pressure_penalty", 0)))
	if int(penalties.get("growth_penalty_percent", 0)) > 0:
		parts.append("growth -%d%%" % int(penalties.get("growth_penalty_percent", 0)))
	return ", ".join(parts)

static func _project_support_summary(capital_project: Dictionary) -> String:
	var parts := []
	var support_total := int(capital_project.get("support_total", 0))
	if support_total > 0:
		var support_summary := "%d/%d support anchors" % [
			int(capital_project.get("support_met", 0)),
			support_total,
		]
		var missing = capital_project.get("missing_support_labels", [])
		if missing is Array and not missing.is_empty():
			support_summary += " | Missing %s" % ", ".join(missing)
		parts.append(support_summary)
	else:
		var next_label := String(capital_project.get("next_label", ""))
		if next_label != "":
			parts.append("Next %s" % next_label)
		else:
			parts.append("Build the final anchor works here to unlock a stronger late-war push.")
	if int(capital_project.get("recovery_guard", 0)) > 0:
		parts.append("Recovery +%d/day" % int(capital_project.get("recovery_guard", 0)))
	if bool(capital_project.get("vulnerable", false)):
		var penalties := _describe_vulnerability_penalties(
			{
				"quality_penalty": int(capital_project.get("quality_penalty", 0)),
				"readiness_penalty": int(capital_project.get("readiness_penalty", 0)),
				"pressure_penalty": int(capital_project.get("pressure_penalty", 0)),
				"growth_penalty_percent": int(capital_project.get("growth_penalty_percent", 0)),
			}
		)
		if penalties != "":
			parts.append("Cut chain: %s" % penalties)
		var vulnerability_summary := String(capital_project.get("vulnerability_summary", ""))
		if vulnerability_summary != "":
			parts.append(vulnerability_summary)
	return " | ".join(parts)

static func _project_watch_summary(capital_project: Dictionary) -> String:
	var summary := _project_support_summary(capital_project)
	if bool(capital_project.get("active", false)):
		summary = "Online | %s" % summary
	if bool(capital_project.get("vulnerable", false)):
		summary += " | Vulnerable"
	return summary

static func _logistics_watch_summary(logistics: Dictionary) -> String:
	var summary := String(logistics.get("summary", "No linked frontier routes."))
	var impact_summary := String(logistics.get("impact_summary", ""))
	if impact_summary != "":
		return "%s | %s" % [summary, impact_summary]
	return summary

static func _convoy_watch_summary(logistics: Dictionary) -> String:
	var delivery_lines = logistics.get("delivery_site_labels", [])
	if not (delivery_lines is Array) or delivery_lines.is_empty():
		return ""
	var shown := []
	for index in range(min(2, delivery_lines.size())):
		shown.append(String(delivery_lines[index]))
	var summary := "; ".join(shown)
	if delivery_lines.size() > 2:
		summary += "; %d more line%s" % [
			delivery_lines.size() - 2,
			"" if delivery_lines.size() - 2 == 1 else "s",
		]
	return summary

static func _town_outlook_grade(
	readiness: int,
	threat_state: Dictionary,
	front_state: Dictionary,
	occupation_state: Dictionary,
	logistics: Dictionary,
	recovery: Dictionary,
	capital_project: Dictionary,
	reserve_count: int,
	ready_response_count: int
) -> String:
	var severity := 0
	if int(threat_state.get("visible_pressuring", 0)) > 0 or int(threat_state.get("siege_progress", 0)) > 0:
		severity += 3
	elif int(threat_state.get("visible_marching", 0)) > 0:
		severity += 2 if int(threat_state.get("nearest_goal_distance", 9999)) <= 1 else 1
	elif bool(threat_state.get("hidden_targeting", false)):
		severity += 1
	if bool(front_state.get("active", false)):
		severity += 2 if String(front_state.get("mode", "")) == "retake" else 1
	if bool(occupation_state.get("active", false)):
		severity += 2
	if readiness <= 18:
		severity += 2
	elif readiness <= 30:
		severity += 1
	if int(logistics.get("disrupted_count", 0)) > 0 or int(logistics.get("support_gap", 0)) > 0:
		severity += 2
	elif int(logistics.get("threatened_count", 0)) > 0:
		severity += 1
	if bool(recovery.get("active", false)):
		severity += 1
	if bool(capital_project.get("vulnerable", false)):
		severity += 1
	if reserve_count <= 0:
		severity += 1
	if ready_response_count <= 0 and (int(logistics.get("threatened_count", 0)) > 0 or bool(recovery.get("active", false))):
		severity += 1
	if severity >= 7:
		return "Brittle perimeter"
	if severity >= 4:
		return "Contested watch"
	if readiness >= 40 and reserve_count > 0:
		return "Strong defensive posture"
	if severity >= 2:
		return "Guarded but strained"
	return "Ready watch"

static func _town_frontier_outlook_line(
	town: Dictionary,
	threat_state: Dictionary,
	front_state: Dictionary,
	occupation_state: Dictionary,
	battlefront: Dictionary
) -> String:
	var clauses := []
	var visible_pressuring := int(threat_state.get("visible_pressuring", 0))
	var visible_marching := int(threat_state.get("visible_marching", 0))
	var nearest_goal_distance := int(threat_state.get("nearest_goal_distance", 9999))
	var pressuring_commanders = threat_state.get("pressuring_commanders", [])
	var marching_commanders = threat_state.get("marching_commanders", [])
	var siege_progress := int(threat_state.get("siege_progress", 0))
	var siege_capture_progress := int(max(1, int(threat_state.get("siege_capture_progress", 1))))
	if visible_pressuring > 0:
		if visible_pressuring == 1 and pressuring_commanders is Array and not pressuring_commanders.is_empty():
			clauses.append("%s already presses the approaches" % String(pressuring_commanders[0]))
		else:
			var pressure_clause: String = "%d known raid host%s already press the approaches" % [
				visible_pressuring,
				"" if visible_pressuring == 1 else "s",
			]
			if pressuring_commanders is Array and not pressuring_commanders.is_empty():
				var shown_pressuring = pressuring_commanders.slice(0, min(2, pressuring_commanders.size()))
				pressure_clause += " (%s)" % ", ".join(shown_pressuring)
			clauses.append(pressure_clause)
	if visible_marching > 0:
		if nearest_goal_distance <= 2:
			if visible_marching == 1 and marching_commanders is Array and not marching_commanders.is_empty():
				clauses.append("%s can reach in %d day%s" % [
					String(marching_commanders[0]),
					max(1, nearest_goal_distance),
					"" if max(1, nearest_goal_distance) == 1 else "s",
				])
			else:
				var marching_clause: String = "%d known host%s can reach in %d day%s" % [
					visible_marching,
					"" if visible_marching == 1 else "s",
					max(1, nearest_goal_distance),
					"" if max(1, nearest_goal_distance) == 1 else "s",
				]
				if marching_commanders is Array and not marching_commanders.is_empty():
					var shown_marching = marching_commanders.slice(0, min(2, marching_commanders.size()))
					marching_clause += " (%s)" % ", ".join(shown_marching)
				clauses.append(marching_clause)
		else:
			var distant_clause: String = "%d known host%s are marching on the lane" % [
				visible_marching,
				"" if visible_marching == 1 else "s",
			]
			if marching_commanders is Array and not marching_commanders.is_empty():
				var shown_distant = marching_commanders.slice(0, min(2, marching_commanders.size()))
				distant_clause += " (%s)" % ", ".join(shown_distant)
			clauses.append(distant_clause)
	if bool(threat_state.get("hidden_targeting", false)):
		clauses.append("scouts report hostile movement beyond the fog")
	if siege_progress > 0:
		clauses.append("siege pressure %d/%d is already building" % [siege_progress, siege_capture_progress])
	if bool(front_state.get("active", false)):
		var front_summary := String(front_state.get("summary", ""))
		if front_summary != "":
			clauses.append(front_summary)
	if bool(occupation_state.get("active", false)):
		clauses.append(String(occupation_state.get("summary", "")))
	if clauses.is_empty():
		var battlefront_summary := String(battlefront.get("summary", "The approaches currently favor the defenders."))
		return "No public raid lane is aligned on %s. %s" % [_town_name(town), battlefront_summary]
	return "; ".join(clauses)

static func _town_dispatch_readiness_line(
	response_count: int,
	ready_response_count: int,
	movement_state: Dictionary,
	reserve_count: int
) -> String:
	var movement_current := int(movement_state.get("current", 0))
	var movement_max := int(movement_state.get("max", 0))
	var parts := []
	if response_count <= 0:
		parts.append("No immediate route or recovery order is open")
	elif ready_response_count > 0:
		parts.append("%d response order%s ready" % [
			ready_response_count,
			"" if ready_response_count == 1 else "s",
		])
	else:
		parts.append("Response orders exist, but current stores or movement block dispatch")
	parts.append("Commander move %d/%d" % [movement_current, movement_max])
	if reserve_count > 0:
		parts.append("%d reserve commander%s cover the walls" % [
			reserve_count,
			"" if reserve_count == 1 else "s",
		])
	else:
		parts.append("No reserve commander covers the walls if the field hero rides out")
	return " | ".join(parts)

static func _town_support_watch_line(
	town: Dictionary,
	logistics: Dictionary,
	recovery: Dictionary,
	capital_project: Dictionary
) -> String:
	var parts := []
	if bool(capital_project.get("vulnerable", false)):
		var capital_parts := ["Capital chain exposed"]
		var missing_support = capital_project.get("missing_support_labels", [])
		if missing_support is Array and not missing_support.is_empty():
			capital_parts.append("Missing %s" % ", ".join(missing_support.slice(0, min(2, missing_support.size()))))
		elif String(capital_project.get("vulnerability_summary", "")) != "":
			capital_parts.append(String(capital_project.get("vulnerability_summary", "")))
		parts.append(" | ".join(capital_parts))
	if int(logistics.get("disrupted_count", 0)) > 0 or int(logistics.get("threatened_count", 0)) > 0 or int(logistics.get("support_gap", 0)) > 0:
		var logistics_line := String(logistics.get("summary", "Strained chain"))
		var impact_parts := []
		var disrupted_labels = logistics.get("disrupted_site_labels", [])
		var threatened_labels = logistics.get("threatened_site_labels", [])
		var missing_family_labels = logistics.get("missing_family_labels", [])
		if disrupted_labels is Array and not disrupted_labels.is_empty():
			impact_parts.append("Denied %s" % ", ".join(disrupted_labels.slice(0, min(2, disrupted_labels.size()))))
		elif threatened_labels is Array and not threatened_labels.is_empty():
			impact_parts.append("Threatened %s" % ", ".join(threatened_labels.slice(0, min(2, threatened_labels.size()))))
		elif missing_family_labels is Array and not missing_family_labels.is_empty():
			impact_parts.append("Missing %s" % ", ".join(missing_family_labels.slice(0, min(2, missing_family_labels.size()))))
		if int(logistics.get("gap_readiness_penalty", 0)) > 0:
			impact_parts.append("Readiness -%d" % int(logistics.get("gap_readiness_penalty", 0)))
		if int(logistics.get("gap_growth_penalty_percent", 0)) > 0:
			impact_parts.append("Recruits -%d%%" % int(logistics.get("gap_growth_penalty_percent", 0)))
		if int(logistics.get("gap_pressure_penalty", 0)) > 0:
			impact_parts.append("%s -%d" % [_town_pressure_label(town), int(logistics.get("gap_pressure_penalty", 0))])
		if not impact_parts.is_empty():
			logistics_line += " | %s" % ", ".join(impact_parts)
		parts.append(logistics_line)
	if bool(recovery.get("active", false)):
		parts.append("Recovery delayed %d day%s at %d/day relief" % [
			int(recovery.get("days_to_clear", 0)),
			"" if int(recovery.get("days_to_clear", 0)) == 1 else "s",
			int(recovery.get("relief_per_day", 1)),
		])
	if parts.is_empty():
		return "%s | Recovery lines clear" % String(logistics.get("summary", "Stable chain"))
	return " | ".join(parts)

static func _active_hero_movement_state(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var hero = session.overworld.get("hero", {})
	var hero_movement = hero.get("movement", {}) if hero is Dictionary else {}
	var overworld_movement = session.overworld.get("movement", {})
	return {
		"current": max(0, int(hero_movement.get("current", overworld_movement.get("current", 0)))),
		"max": max(0, int(hero_movement.get("max", overworld_movement.get("max", 0)))),
	}

static func _count_ready_actions(actions: Array) -> int:
	var ready_count := 0
	for action in actions:
		if action is Dictionary and not bool(action.get("disabled", false)):
			ready_count += 1
	return ready_count

static func _stationed_reserve_count(session: SessionStateStoreScript.SessionData, stationed: Array) -> int:
	var reserve_count := 0
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	for hero in stationed:
		if hero is Dictionary and String(hero.get("id", "")) != active_hero_id:
			reserve_count += 1
	return reserve_count

static func _town_threat_lines(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	var scenario := ContentService.get_scenario(session.scenario_id)
	var threat_lines := []
	var town_placement_id := String(town.get("placement_id", ""))
	var front_state: Dictionary = OverworldRulesScript.town_front_state(session, town)
	if town_placement_id == "":
		return threat_lines

	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for config in scenario.get("enemy_factions", []):
		if not (config is Dictionary):
			continue
		var faction_id := String(config.get("faction_id", ""))
		if faction_id == "":
			continue
		var visible_marching := 0
		var visible_pressuring := 0
		var hidden_targeting := false
		var pressuring_commanders: Array = []
		var marching_commanders: Array = []
		for encounter in session.overworld.get("encounters", []):
			if not (encounter is Dictionary):
				continue
			if String(encounter.get("spawned_by_faction_id", "")) != faction_id:
				continue
			if String(encounter.get("target_placement_id", "")) != town_placement_id:
				continue
			if resolved_encounters is Array and String(encounter.get("placement_id", "")) in resolved_encounters:
				continue
			var is_public: bool = EnemyAdventureRulesScript._raid_is_public(session, encounter)
			var is_pressuring := bool(encounter.get("arrived", false)) or int(encounter.get("goal_distance", 9999)) <= 0
			var commander_name := String(OverworldRulesScript.encounter_commander_threat_label(encounter))
			if is_public:
				if is_pressuring:
					visible_pressuring += 1
					if commander_name != "" and commander_name not in pressuring_commanders:
						pressuring_commanders.append(commander_name)
				else:
					visible_marching += 1
					if commander_name != "" and commander_name not in marching_commanders:
						marching_commanders.append(commander_name)
			else:
				hidden_targeting = true

		var state := _enemy_state_for_faction(session, faction_id)
		var siege_progress := 0
		if String(config.get("siege_target_placement_id", "")) == town_placement_id:
			siege_progress = max(0, int(state.get("siege_progress", 0)))
		var commander_recovery := ""
		var commander_rebuild := ""
		if (
			String(config.get("siege_target_placement_id", "")) == town_placement_id
			or visible_marching > 0
			or visible_pressuring > 0
			or hidden_targeting
			or siege_progress > 0
		):
			commander_recovery = EnemyAdventureRulesScript.public_commander_recovery_summary(
				session,
				faction_id,
				state.get("commander_roster", [])
			)
			commander_rebuild = EnemyAdventureRulesScript.public_commander_rebuild_summary(
				session,
				faction_id,
				state.get("commander_roster", [])
			)
		if (
			visible_marching <= 0
			and visible_pressuring <= 0
			and not hidden_targeting
			and siege_progress <= 0
			and commander_recovery == ""
			and commander_rebuild == ""
		):
			continue

		var clauses := []
		if visible_pressuring > 0:
			if visible_pressuring == 1 and not pressuring_commanders.is_empty():
				clauses.append("%s presses the approaches" % String(pressuring_commanders[0]))
			else:
				var pressure_clause: String = "%d known raid host%s press the approaches" % [
					visible_pressuring,
					"" if visible_pressuring == 1 else "s",
				]
				if not pressuring_commanders.is_empty():
					pressure_clause += " (%s)" % ", ".join(pressuring_commanders.slice(0, min(2, pressuring_commanders.size())))
				clauses.append(pressure_clause)
		if visible_marching > 0:
			if visible_marching == 1 and not marching_commanders.is_empty():
				clauses.append("%s is marching on the town" % String(marching_commanders[0]))
			else:
				var marching_clause: String = "%d known host%s are marching on the town" % [
					visible_marching,
					"" if visible_marching == 1 else "s",
				]
				if not marching_commanders.is_empty():
					marching_clause += " (%s)" % ", ".join(marching_commanders.slice(0, min(2, marching_commanders.size())))
				clauses.append(marching_clause)
		if hidden_targeting:
			clauses.append("scouts report hostile movement beyond the fog")
		if siege_progress > 0:
			clauses.append("siege pressure %d/%d" % [
				siege_progress,
				max(1, int(config.get("siege_capture_progress", 1))),
			])
		if bool(front_state.get("active", false)) and String(front_state.get("faction_id", "")) == faction_id:
			var front_clause := String(front_state.get("public_clause", ""))
			if front_clause != "":
				clauses.append(front_clause)
		if commander_recovery != "":
			clauses.append(commander_recovery)
		if commander_rebuild != "":
			clauses.append(commander_rebuild)
		threat_lines.append("%s: %s" % [
			String(config.get("label", ContentService.get_faction(faction_id).get("name", faction_id))),
			"; ".join(clauses),
		])
	return threat_lines

static func _pressure_brief(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	var threat_lines := _town_threat_lines(session, town)
	if threat_lines.is_empty():
		return "%s reports quiet roads beyond the walls." % _town_name(town)
	return threat_lines[0]

static func _enemy_state_for_faction(session: SessionStateStoreScript.SessionData, faction_id: String) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
			return state
	return {}

static func _can_afford(session: SessionStateStoreScript.SessionData, cost: Variant) -> bool:
	var resources = session.overworld.get("resources", {})
	if not (cost is Dictionary):
		return true
	for key in cost.keys():
		if int(resources.get(String(key), 0)) < int(cost[key]):
			return false
	return true

static func _max_affordable_count(session: SessionStateStoreScript.SessionData, unit_cost: Variant) -> int:
	if not (unit_cost is Dictionary) or unit_cost.is_empty():
		return 999
	var resources = session.overworld.get("resources", {})
	var max_affordable := 999
	for key in unit_cost.keys():
		var price := int(max(1, int(unit_cost[key])))
		max_affordable = min(max_affordable, int(int(resources.get(String(key), 0)) / price))
	return max_affordable

static func _merge_resources(base: Variant, delta: Variant) -> Dictionary:
	var merged := {"gold": 0, "wood": 0, "ore": 0}
	if base is Dictionary:
		for key in merged.keys():
			merged[key] = int(base.get(key, 0))
	if delta is Dictionary:
		for key in delta.keys():
			var resource_key := String(key)
			if resource_key == "experience":
				continue
			merged[resource_key] = int(merged.get(resource_key, 0)) + int(delta[key])
	return merged

static func _describe_resources(resources: Variant, empty_label: String = "none") -> String:
	if not (resources is Dictionary):
		return empty_label
	var parts := []
	for key in ["gold", "wood", "ore"]:
		var amount := int(resources.get(key, 0))
		if amount > 0:
			parts.append("%d %s" % [amount, key])
	return ", ".join(parts) if not parts.is_empty() else empty_label

static func _describe_recruit_delta(delta: Variant) -> String:
	if not (delta is Dictionary):
		return "none"
	var parts := []
	var unit_ids := []
	for unit_id_value in delta.keys():
		unit_ids.append(String(unit_id_value))
	unit_ids.sort()
	for unit_id in unit_ids:
		var amount := int(delta.get(unit_id, 0))
		if amount <= 0:
			continue
		var unit := ContentService.get_unit(unit_id)
		parts.append("+%d %s" % [amount, String(unit.get("name", unit_id))])
	return ", ".join(parts) if not parts.is_empty() else "none"

static func _recruit_pool_total(recruits: Variant) -> int:
	var total := 0
	if recruits is Dictionary:
		for value in recruits.values():
			total += max(0, int(value))
	return total

static func _town_unit_ids(town: Dictionary) -> Array:
	var unit_ids := []
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var building_ids := []
	for building_id_value in town_template.get("starting_building_ids", []):
		building_ids.append(String(building_id_value))
	for building_id_value in town_template.get("buildable_building_ids", []):
		building_ids.append(String(building_id_value))
	for building_id in building_ids:
		var unlock_unit_id := String(ContentService.get_building(building_id).get("unlock_unit_id", ""))
		if unlock_unit_id != "" and unlock_unit_id not in unit_ids:
			unit_ids.append(unlock_unit_id)
	for unit_id_value in town.get("available_recruits", {}).keys():
		var unit_id := String(unit_id_value)
		if unit_id != "" and unit_id not in unit_ids:
			unit_ids.append(unit_id)
	for unit_id_value in OverworldRulesScript.town_weekly_growth(town).keys():
		var unit_id := String(unit_id_value)
		if unit_id != "" and unit_id not in unit_ids:
			unit_ids.append(unit_id)
	return unit_ids

static func _unit_is_unlocked_in_town(town: Dictionary, unit_id: String) -> bool:
	return int(OverworldRulesScript.town_weekly_growth(town).get(unit_id, 0)) > 0

static func _unlock_building_for_unit(town: Dictionary, unit_id: String) -> String:
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var building_ids := []
	for building_id_value in town_template.get("starting_building_ids", []):
		building_ids.append(String(building_id_value))
	for building_id_value in town_template.get("buildable_building_ids", []):
		building_ids.append(String(building_id_value))
	for building_id in building_ids:
		if String(ContentService.get_building(building_id).get("unlock_unit_id", "")) == unit_id:
			return building_id
	return ""

static func _finalize_town_result(session: SessionStateStoreScript.SessionData, ok: bool, base_message: String) -> Dictionary:
	HeroCommandRulesScript.commit_active_hero(session)
	OverworldRulesScript.refresh_fog_of_war(session)
	var messages := []
	if base_message != "":
		messages.append(base_message)

	var scenario_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var scenario_message := String(scenario_result.get("message", ""))
	HeroCommandRulesScript.commit_active_hero(session)
	OverworldRulesScript.refresh_fog_of_war(session)
	if scenario_message != "":
		messages.append(scenario_message)

	return {
		"ok": ok,
		"message": " ".join(messages),
		"scenario_status": session.scenario_status,
	}
