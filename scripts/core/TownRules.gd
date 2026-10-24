class_name TownRules
extends RefCounted
const TownDevelopment = preload("res://scripts/core/TownDevelopmentRules.gd")

const BUILDING_CATEGORY_IDS := ["civic", "dwelling", "economy", "support", "magic"]
const MARKET_GOLD := "gold"

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
static var OverworldRulesScript: Variant = load("res://scripts/core/OverworldRules.gd")
static var HeroCommandRulesScript: Variant = load("res://scripts/core/HeroCommandRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")
static var EnemyAdventureRulesScript: Variant = load("res://scripts/core/EnemyAdventureRules.gd")
static var ScenarioRulesScript: Variant = load("res://scripts/core/ScenarioRules.gd")

static var _read_scope_session_id := ""
static var _read_scope_depth := 0
static var _read_scope_cache := {}

const FACTION_SPELL_SCHOOL_ACCESS := {
	"faction_embercourt": ["beacon", "furnace"],
	"faction_mireclaw": ["mire", "root"],
	"faction_sunvault": ["lens", "beacon"],
	"faction_thornwake": ["root", "mire"],
	"faction_brasshollow": ["furnace", "old_measure"],
	"faction_veilmourn": ["veil", "old_measure"],
}

static func building_id_for_action(action_id: String) -> String:
	return HumanEngine.native(&"TownRules.building_id_for_action", [action_id])

static func building_category_icon_path(building_id: String) -> String:
	return HumanEngine.native(&"TownRules.building_category_icon_path", [building_id])

static func building_icon_path(building_id: String, faction_id: String = "") -> String:
	return HumanEngine.native(&"TownRules.building_icon_path", [building_id, faction_id])

static func faction_crest_icon_path(faction_id: String) -> String:
	var normalized_faction_id := faction_id.strip_edges()
	if ContentService.get_faction(normalized_faction_id).is_empty():
		return ""
	var crest := ContentService.get_faction_crest(normalized_faction_id)
	var icon_path := String(crest.get("icon_path", "")).strip_edges()
	if String(crest.get("id", "")) != normalized_faction_id:
		return ""
	if String(crest.get("crest_id", "")) != "faction_crest_%s" % normalized_faction_id.trim_prefix("faction_"):
		return ""
	if not icon_path.begins_with("res://art/factions/runtime/crests/") or not ResourceLoader.exists(icon_path, "Texture2D"):
		return ""
	return icon_path

static func begin_read_scope(session: SessionStateStoreScript.SessionData) -> void:
	HumanEngine.native_writing(&"TownRules.begin_read_scope", [session])

static func end_read_scope(session: SessionStateStoreScript.SessionData) -> void:
	HumanEngine.native_writing(&"TownRules.end_read_scope", [session])

static func can_visit_active_town(session: SessionStateStoreScript.SessionData) -> bool:
	return HumanEngine.native_writing(&"TownRules.can_visit_active_town", [session])

static func can_visit_active_town_bridge(session) -> bool:
	return can_visit_active_town(session)

static func get_active_town(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.get_active_town", [session])

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
	return "%s | %s%s | %s | Spell Tier %d" % [
		String(template.get("name", town.get("town_id", "Town"))),
		String(faction.get("name", template.get("faction_id", "Faction"))),
		role_label,
		town_control_label(String(town.get("owner", "neutral"))),
		current_spell_tier(town),
	]

static func town_control_label(owner: String) -> String:
	return OverworldRulesScript.town_control_label(owner)

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
	var headline := _defense_headline_for_town(town)
	if town.is_empty():
		return headline

	var stationed: Array = HeroCommandRulesScript.stationed_heroes(session, town)
	var active_hero: Dictionary = HeroCommandRulesScript.town_defending_hero(session, town)
	var active_hero_id := String(active_hero.get("id", ""))
	var reserve_lines := []
	for hero in stationed:
		if not (hero is Dictionary):
			continue
		if String(hero.get("id", "")) == active_hero_id:
			continue
		reserve_lines.append(_hero_command_line(hero))

	var lines := [
		headline,
		HeroCommandRulesScript.describe_town_defense_force(session, town),
		"- Garrison posture: %s | %d companies | %d garrison troops" % [
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
		lines.append("- Defending commander %s" % _hero_command_line(active_hero))
	if reserve_lines.is_empty():
		lines.append("- No reserve commander is stationed. The town captain will lead if the field hero departs.")
	else:
		lines.append("- Reserve commanders %s" % "; ".join(reserve_lines))
	return "\n".join(lines)

static func describe_defense_headline(session: SessionStateStoreScript.SessionData) -> String:
	return _defense_headline_for_town(get_active_town(session))

static func _defense_headline_for_town(town: Dictionary) -> String:
	return "Defense unavailable." if town.is_empty() else "Defense Posture"

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
		lines.append("- No hostile heroes are known to be marching on %s." % _town_name(town))
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
			"button_label": "Return to Field",
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
	var button_label := "Return to Field"
	var visible_text := ""
	if int(handoff.get("ready_response_action_count", 0)) > 0:
		visible_text = "Ready check: response order is open before returning to the field."
	elif move_current <= 0:
		visible_text = "Ready check: movement is spent; return to the field, then choose End Turn."
	else:
		visible_text = "Ready check: finish town orders, then return to the field with %d/%d move." % [move_current, move_max]
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

static func town_order_target_handoff(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var town := get_active_town(session)
	if town.is_empty():
		return {
			"active": false,
			"visible_text": "Order target: no active town.",
			"tooltip_text": "Town Order Target\n- No active town.",
			"next_step": "Return to the overworld.",
		}

	var action := _town_order_target_action(session, town)
	var departure := town_departure_confirmation(session)
	if action.is_empty():
		var fallback_next := _next_town_action_line(session, town)
		var fallback_visible := "Order target: no open order | Next: %s" % _short_town_handoff_text(fallback_next, 64)
		return {
			"active": false,
			"visible_text": fallback_visible,
			"tooltip_text": "Town Order Target\n- Target: no open order\n- Next practical action: %s\n- Departure: %s" % [
				fallback_next,
				String(departure.get("visible_text", "")),
			],
			"next_step": fallback_next,
		}

	var lane := String(action.get("lane", "order"))
	var label := _short_action_label(action, "Town order")
	var where := _town_order_ui_surface_for_lane(lane)
	var readiness := _town_order_readiness_line(action, lane)
	var impact := _town_order_impact_line(action, lane)
	var next_step := _town_order_next_step(action, lane, label, where, readiness)
	var visible := "Order target: %s | %s | %s" % [
		_short_town_handoff_text(label, 36),
		_short_town_handoff_text(readiness, 34),
		where,
	]
	var tooltip := "Town Order Target\n- Target: %s\n- Lane: %s\n- Where: %s\n- Readiness: %s\n- Why it matters: %s\n- Next practical action: %s\n- Departure: %s" % [
		label,
		_town_order_lane_label(lane),
		where,
		readiness,
		impact,
		next_step,
		String(departure.get("visible_text", "")),
	]
	return {
		"active": true,
		"action_id": String(action.get("id", "")),
		"lane": lane,
		"target_label": label,
		"ui_surface": where,
		"readiness": readiness,
		"why_it_matters": impact,
		"next_step": next_step,
		"visible_text": visible,
		"tooltip_text": tooltip,
		"disabled": bool(action.get("disabled", false)),
	}

static func town_action_consequence_signature(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var town := get_active_town(session)
	if town.is_empty():
		return {}
	var logistics: Dictionary = OverworldRulesScript.town_logistics_state(session, town)
	var recovery: Dictionary = OverworldRulesScript.town_recovery_state(session, town)
	var front: Dictionary = OverworldRulesScript.town_front_state(session, town)
	var recipient: Dictionary = HeroCommandRulesScript.town_recruitment_destination(session, town)
	return {
		"town_name": _town_name(town),
		"recruitment_holder_id": String(recipient.holder_id),
		"recruitment_holder_label": String(recipient.label),
		"recruitment_holder_counts": _army_unit_counts({"stacks": recipient.stacks}),
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
		"artifact_ids": ArtifactRulesScript.owned_artifact_ids(session.overworld.get("hero", {})),
	}

static func build_town_action_recap(
	session: SessionStateStoreScript.SessionData,
	lane: String,
	action_id: String,
	action: Dictionary,
	result: Dictionary,
	before: Dictionary,
	after_signature: Dictionary = {}
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
	# A caller that already read the post-order signature passes it in.
	var after := after_signature if not after_signature.is_empty() else town_action_consequence_signature(session)
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
		var build_status: Dictionary = OverworldRulesScript.get_town_build_status(town, building_id, session.day)
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
		var unit_tier := int(unit.get("tier", 0))
		var available := int(recruits.get(unit_id, 0))
		var growth := int(weekly_growth.get(unit_id, 0))
		if _unit_is_unlocked_in_town(town, unit_id):
			var growth_sources := _growth_source_summary(town, unit_id)
			var reserve_label := "x%d" % available if available > 0 else "reserve empty"
			lines.append(
				"- %s %s %s | %s | Weekly +%d%s | Cost %s" % [
					_unit_tier_label(unit_tier),
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
			"- %s %s locked | %s" % [
				_unit_tier_label(unit_tier),
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
	return HumanEngine.native_writing(&"TownRules.get_build_actions", [session])

static func get_recruit_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_recruit_actions", [session])

static func get_build_catalog(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_build_catalog", [session])

static func get_muster_catalog(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_muster_catalog", [session])

static func get_market_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_market_actions", [session])

static func get_hero_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_hero_actions", [session])

static func get_tavern_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_tavern_actions", [session])

static func get_transfer_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_transfer_actions", [session])

static func get_response_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_response_actions", [session])

static func get_spell_learning_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_spell_learning_actions", [session])

static func get_artifact_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_artifact_actions", [session])

static func get_specialty_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_specialty_actions", [session])

static func build_active_town(session: SessionStateStoreScript.SessionData, building_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.build_active_town", [session, building_id])

static func switch_active_hero_at_town(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.switch_active_hero_at_town", [session, hero_id])

## `runtime_normalized`: the caller (the Town screen) has just runtime-normalized
## the session in its order preflight, so the order skips a second full pass.
static func recruit_active_town(session: SessionStateStoreScript.SessionData, unit_id: String, requested_count: int = -1, runtime_normalized: bool = false) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.recruit_active_town", [session, unit_id, requested_count, runtime_normalized])

static func perform_market_action(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.perform_market_action", [session, action_id])

# --- market desk ----------------------------------------------------------------

## The market popout trades any resource for any other, HoMM3 style: gold buys
## a resource, a resource sells for gold, or one resource converts straight
## into another, rare resources included. A conversion charges the received
## resource at the midpoint of this market's buy and sell price and takes the
## given resource at its sell price, so it beats selling for gold and buying
## back but never pays for itself in a round trip. Every mode follows the
## town's market state (market tier, local abundance and each resource's
## economy value). A conversion counts against the given resource's weekly
## sell limit and the received resource's weekly buy limit.

static func market_trade_mode(market: Dictionary, give_id: String, receive_id: String) -> String:
	if not bool(market.get("active", false)) or give_id == receive_id:
		return ""
	var tradable: Array = market_resource_ids(market)
	if give_id == MARKET_GOLD and receive_id in tradable:
		return "buy"
	if receive_id == MARKET_GOLD and give_id in tradable:
		return "sell"
	if give_id in tradable and receive_id in tradable:
		return "convert"
	return ""

## The resources a market trades besides gold, in stockpile order.
static func market_resource_ids(market: Dictionary) -> Array:
	var buy_rates: Dictionary = market.get("buy_rates", {}) if market.get("buy_rates", {}) is Dictionary else {}
	var ids := []
	for resource_id in OverworldRulesScript.MARKET_RESOURCE_KEYS:
		if int(buy_rates.get(resource_id, 0)) > 0:
			ids.append(String(resource_id))
	return ids

## Units of `give_id` one unit of `receive_id` costs in a conversion, as the
## exact fraction numerator / denominator. Empty when the pair does not convert.
static func market_conversion_rate(market: Dictionary, give_id: String, receive_id: String) -> Dictionary:
	if market_trade_mode(market, give_id, receive_id) != "convert":
		return {}
	var sell_rates: Dictionary = market.get("sell_rates", {}) if market.get("sell_rates", {}) is Dictionary else {}
	var buy_rates: Dictionary = market.get("buy_rates", {}) if market.get("buy_rates", {}) is Dictionary else {}
	var give_sell := int(sell_rates.get(give_id, 0))
	var receive_value := int(buy_rates.get(receive_id, 0)) + int(sell_rates.get(receive_id, 0))
	if give_sell <= 0 or receive_value <= 0:
		return {}
	return {"numerator": receive_value, "denominator": 2 * give_sell}

## Units given for `receive_amount` at a conversion rate, rounded up.
static func market_conversion_give_amount(rate: Dictionary, receive_amount: int) -> int:
	var numerator := int(rate.get("numerator", 0))
	var denominator := int(rate.get("denominator", 0))
	if numerator <= 0 or denominator <= 0 or receive_amount <= 0:
		return 0
	return (receive_amount * numerator + denominator - 1) / denominator

## Terms for trading `give_id` for `receive_id` at a market. `amount` counts the
## traded resource: units bought with gold, units sold for gold, or units
## received by a conversion. Pure: reads only the market state, this week's
## normalized market usage and the stockpile. `max_amount` is the most the
## stores and weekly limits allow; `ok` says whether `amount` can trade now.
## With `with_text` false the reason, label and other texts stay empty, for
## callers that only weigh the numbers.
static func market_trade_quote(market: Dictionary, usage: Dictionary, stock: Dictionary, give_id: String, receive_id: String, amount: int, with_text: bool = true) -> Dictionary:
	var mode := market_trade_mode(market, give_id, receive_id)
	var quote := {
		"mode": mode,
		"give_id": give_id,
		"receive_id": receive_id,
		"amount": maxi(0, amount),
		"give_amount": 0,
		"receive_amount": 0,
		"max_amount": 0,
		"ok": false,
		"reason": "",
		"action_id": "",
		"label": "",
		"rate_text": "",
		"unit_text": "",
		"limit_text": "",
	}
	if mode == "":
		if with_text:
			quote["reason"] = _market_pair_reason(market, give_id, receive_id)
		return quote
	var reset_day := int(usage.get("week", 1)) * 7 + 1
	var usage_town := {"market_usage": usage}
	match mode:
		"buy":
			var unit: Dictionary = OverworldRulesScript._market_quote_from_state(market, "buy", receive_id, 1)
			var cap: Dictionary = OverworldRulesScript._market_cap_state_for_quote(usage_town, market, unit, -1)
			var gold := int(stock.get(MARKET_GOLD, 0))
			for count in range(1, int(cap.get("remaining", 0)) + 1):
				if int(OverworldRulesScript._market_quote_from_state(market, "buy", receive_id, count).get("gold_value", 0)) > gold:
					break
				quote["max_amount"] = count
			if with_text:
				var price := int(unit.get("gold_value", 0))
				quote["unit_text"] = "%s gold" % _format_market_amount(price)
				quote["rate_text"] = "%s gold each%s" % [_format_market_amount(price), _market_bulk_text(market, "buy", receive_id)]
				quote["limit_text"] = "%s bought this week: %d of %d" % [_market_resource_title(receive_id), int(cap.get("used", 0)), int(cap.get("limit", 0))]
				if int(quote.max_amount) <= 0:
					quote["reason"] = _market_limit_reason("buy", receive_id, cap, reset_day) if int(cap.get("remaining", 0)) <= 0 else "Not enough gold: 1 %s costs %s gold." % [_market_resource_name(receive_id), _format_market_amount(price)]
		"sell":
			var unit: Dictionary = OverworldRulesScript._market_quote_from_state(market, "sell", give_id, 1)
			var cap: Dictionary = OverworldRulesScript._market_cap_state_for_quote(usage_town, market, unit, -1)
			quote["max_amount"] = maxi(0, mini(int(cap.get("remaining", 0)), int(stock.get(give_id, 0))))
			if with_text:
				var price := int(unit.get("gold_value", 0))
				quote["unit_text"] = "%s per %s" % [_format_market_amount(price), _market_resource_name(give_id)]
				quote["rate_text"] = "%s gold each%s" % [_format_market_amount(price), _market_bulk_text(market, "sell", give_id)]
				quote["limit_text"] = "%s sold this week: %d of %d" % [_market_resource_title(give_id), int(cap.get("used", 0)), int(cap.get("limit", 0))]
				if int(quote.max_amount) <= 0:
					quote["reason"] = _market_limit_reason("sell", give_id, cap, reset_day) if int(cap.get("remaining", 0)) <= 0 else "No %s to sell." % _market_resource_name(give_id)
		"convert":
			var rate := market_conversion_rate(market, give_id, receive_id)
			var numerator := int(rate.get("numerator", 0))
			var denominator := int(rate.get("denominator", 0))
			var sell_cap: Dictionary = OverworldRulesScript._market_cap_state_for_quote(usage_town, market, OverworldRulesScript._market_quote_from_state(market, "sell", give_id, 1), -1)
			var buy_cap: Dictionary = OverworldRulesScript._market_cap_state_for_quote(usage_town, market, OverworldRulesScript._market_quote_from_state(market, "buy", receive_id, 1), -1)
			var give_limit := maxi(0, mini(int(stock.get(give_id, 0)), int(sell_cap.get("remaining", 0))))
			if numerator > 0 and denominator > 0:
				quote["max_amount"] = maxi(0, mini(int(buy_cap.get("remaining", 0)), (give_limit * denominator) / numerator))
			if with_text:
				var per_unit := float(numerator) / float(maxi(1, denominator))
				quote["unit_text"] = "%s %s" % [_market_ratio_text(per_unit), _market_resource_name(give_id)]
				# Read as "1 ore for 1.7 wood" or, for a valuable give, "1.2 wood for 1 aetherglass".
				if per_unit >= 1.0:
					quote["rate_text"] = "1 %s for %s %s" % [_market_resource_name(receive_id), _market_ratio_text(per_unit), _market_resource_name(give_id)]
				else:
					quote["rate_text"] = "%s %s for 1 %s" % [_market_ratio_text(1.0 / per_unit), _market_resource_name(receive_id), _market_resource_name(give_id)]
				quote["limit_text"] = "%s sold this week: %d of %d · %s bought: %d of %d" % [_market_resource_title(give_id), int(sell_cap.get("used", 0)), int(sell_cap.get("limit", 0)), _market_resource_name(receive_id), int(buy_cap.get("used", 0)), int(buy_cap.get("limit", 0))]
				if int(quote.max_amount) <= 0:
					if int(buy_cap.get("remaining", 0)) <= 0:
						quote["reason"] = _market_limit_reason("buy", receive_id, buy_cap, reset_day)
					elif int(sell_cap.get("remaining", 0)) <= 0:
						quote["reason"] = _market_limit_reason("sell", give_id, sell_cap, reset_day)
					else:
						quote["reason"] = "Needs %d %s for 1 %s." % [market_conversion_give_amount(rate, 1), _market_resource_name(give_id), _market_resource_name(receive_id)]
	var count := int(quote.amount)
	if count <= 0 or count > int(quote.max_amount):
		if with_text and String(quote.reason) == "":
			quote["reason"] = "Choose from 1 to %d." % int(quote.max_amount)
		return quote
	match mode:
		"buy":
			quote["give_amount"] = int(OverworldRulesScript._market_quote_from_state(market, "buy", receive_id, count).get("gold_value", 0))
			quote["receive_amount"] = count
			quote["action_id"] = "market:buy:%s:%d" % [receive_id, count]
		"sell":
			quote["give_amount"] = count
			quote["receive_amount"] = market_sale_gold(market, give_id, count)
			quote["action_id"] = "market:sell:%s:%d" % [give_id, count]
		"convert":
			quote["give_amount"] = market_conversion_give_amount(market_conversion_rate(market, give_id, receive_id), count)
			quote["receive_amount"] = count
			quote["action_id"] = "market:convert:%s:%s:%d" % [give_id, receive_id, count]
	if with_text:
		quote["label"] = "Trade %s %s for %s %s" % [_format_market_amount(int(quote.give_amount)), _market_resource_name(give_id), _format_market_amount(int(quote.receive_amount)), _market_resource_name(receive_id)]
	quote["ok"] = true
	return quote

## The gold a sale of `count` units of `give_id` receives when
## market_trade_quote allows it.
static func market_sale_gold(market: Dictionary, give_id: String, count: int) -> int:
	return int(OverworldRulesScript._market_quote_from_state(market, "sell", give_id, count).get("gold_value", 0))

## Short order text for a market action id, such as "Buy 2 wood" or "Convert
## wood into 3 ore".
static func market_action_label(action_id: String) -> String:
	return HumanEngine.native(&"TownRules.market_action_label", [action_id])

static func _market_pair_reason(market: Dictionary, give_id: String, receive_id: String) -> String:
	if not bool(market.get("active", false)):
		return "No market stands in this town."
	if give_id == receive_id:
		return "Choose a different resource to get."
	if give_id != MARKET_GOLD and give_id not in market_resource_ids(market):
		return "This market does not buy %s." % _market_resource_name(give_id)
	return "This market does not sell %s." % _market_resource_name(receive_id)

static func _market_ratio_text(value: float) -> String:
	return ("%.1f" % value).trim_suffix(".0")

static func _market_limit_reason(action_type: String, resource_id: String, cap: Dictionary, reset_day: int) -> String:
	return "This week's %s limit is used: %d of %d %s %s. It resets on day %d." % [
		"buy" if action_type == "buy" else "sell",
		int(cap.get("used", 0)),
		int(cap.get("limit", 0)),
		_market_resource_name(resource_id),
		"bought" if action_type == "buy" else "sold",
		reset_day,
	]

static func _market_bulk_text(market: Dictionary, action_type: String, resource_id: String) -> String:
	var bulk_amount := int(market.get("bulk_amount", 0))
	if bulk_amount <= 1 or resource_id not in market.get("bulk_resources", []):
		return ""
	var lot: Dictionary = OverworldRulesScript._market_quote_from_state(market, action_type, resource_id, bulk_amount)
	return " · %d for %s gold" % [bulk_amount, _format_market_amount(int(lot.get("gold_value", 0)))]

static func _market_resource_title(resource_id: String) -> String:
	var name := _market_resource_name(resource_id)
	return name.left(1).to_upper() + name.substr(1)

static func _market_resource_name(resource_id: String) -> String:
	var definition: Dictionary = OverworldRulesScript.resource_definition(resource_id)
	return String(definition.get("display_name", resource_id.replace("_", " "))).to_lower()

static func _format_market_amount(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + grouped

static func hire_hero_at_active_town(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.hire_hero_at_active_town", [session, hero_id])

static func transfer_in_active_town(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.transfer_in_active_town", [session, action_id])

static func manage_army_slots_in_active_town(session: SessionStateStoreScript.SessionData, source_holder_id: String, source_slot_index: int, target_holder_id: String, target_slot_index: int, amount_token: String = "all") -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.manage_army_slots_in_active_town", [session, source_holder_id, source_slot_index, target_holder_id, target_slot_index, amount_token])

## Moves a hero into the active town's garrison ("" sends the garrison hero out
## to the gate). See HeroCommandRules.set_town_garrison_hero.
static func set_garrison_hero_in_active_town(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.set_garrison_hero_in_active_town", [session, hero_id])

static func perform_response_action(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.perform_response_action", [session, action_id])

static func learn_spell_at_active_town(session: SessionStateStoreScript.SessionData, spell_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.learn_spell_at_active_town", [session, spell_id])

static func teach_visiting_heroes(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	# Explicit arrival/build mutation, never a UI/read-cache side effect. Town
	# archives define eligibility; learning has no mana, gold or mastery cost.
	var learned := {}
	if session == null or town.is_empty() or String(town.get("owner", "")) != "player":
		return {"learned": learned, "count": 0}
	var spell_ids := accessible_spell_ids(town)
	if spell_ids.is_empty():
		return {"learned": learned, "count": 0}
	HeroCommandRulesScript.commit_active_hero(session)
	var active_id := String(session.overworld.get("active_hero_id", ""))
	var heroes: Array = session.overworld.get("player_heroes", [])
	var count := 0
	for index in range(heroes.size()):
		var hero: Dictionary = heroes[index]
		if not HeroCommandRulesScript._hero_is_stationed_at_town(hero, town):
			continue
		var learned_ids := []
		for spell_id in spell_ids:
			if SpellRulesScript.knows_spell(hero, spell_id):
				continue
			var result := SpellRulesScript.learn_spell(hero, spell_id)
			if bool(result.get("ok", false)):
				hero = result.hero
				learned_ids.append(spell_id)
		if learned_ids.is_empty():
			continue
		heroes[index] = hero
		if String(hero.get("id", "")) == active_id:
			session.overworld["hero"] = hero
		learned[String(hero.id)] = learned_ids
		count += learned_ids.size()
	session.overworld["player_heroes"] = heroes
	return {"learned": learned, "count": count}

static func manage_artifact_at_active_town(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.manage_artifact_at_active_town", [session, action_id])

static func choose_specialty_at_active_town(session: SessionStateStoreScript.SessionData, specialty_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.choose_specialty_at_active_town", [session, specialty_id])

static func current_spell_tier(town: Dictionary) -> int:
	var highest_tier := 0
	for building_id_value in town.get("built_buildings", []):
		var building := ContentService.get_building(String(building_id_value))
		highest_tier = max(highest_tier, int(building.get("spell_tier", 0)))
	return highest_tier

static func accessible_spell_ids(town: Dictionary) -> Array:
	return spell_ids_through_tier(town, current_spell_tier(town))

## Library and school spells this town teaches once its guild reaches `tier`.
static func spell_ids_through_tier(town: Dictionary, tier: int) -> Array:
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
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
	for spell_id in _school_spell_ids_for_town(town_template, tier):
		if spell_id != "" and spell_id not in spell_ids:
			spell_ids.append(spell_id)
	return spell_ids

static func _school_spell_ids_for_town(town_template: Dictionary, tier: int) -> Array:
	var allowed_schools := _town_spell_school_access(town_template)
	if allowed_schools.is_empty():
		return []
	var results := []
	var raw := ContentService.load_json(ContentService.SPELLS_PATH)
	var spells: Array = raw.get("items", []) if raw.get("items", []) is Array else []
	for spell_value in spells:
		if not (spell_value is Dictionary):
			continue
		var spell: Dictionary = spell_value
		var spell_id := String(spell.get("id", ""))
		if spell_id == "":
			continue
		if int(spell.get("tier", 0)) > tier:
			continue
		if String(spell.get("school_id", "")) in allowed_schools and spell_id not in results:
			results.append(spell_id)
	return results

static func _town_spell_school_access(town_template: Dictionary) -> Array:
	var schools := []
	var faction_id := String(town_template.get("faction_id", ""))
	for school_id_value in FACTION_SPELL_SCHOOL_ACCESS.get(faction_id, []):
		var school_id := String(school_id_value)
		if school_id != "" and school_id not in schools:
			schools.append(school_id)
	if "old_measure" not in schools:
		schools.append("old_measure")
	return schools

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
					action.get("resource_cost", {}),
					int(session.day)
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

static func _town_order_target_action(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	for action in get_response_actions(session):
		if action is Dictionary and not bool(action.get("disabled", false)):
			var response: Dictionary = action.duplicate(true)
			response["lane"] = "response"
			return response

	var recommendation := _town_recommendation_action(session, town)
	if not recommendation.is_empty():
		var recommended := recommendation.duplicate(true)
		var recommended_id := String(recommended.get("id", ""))
		if recommended_id.begins_with("build:"):
			recommended["lane"] = "build"
		elif recommended_id.begins_with("recruit:"):
			recommended["lane"] = "recruit"
		else:
			recommended["lane"] = "order"
		return recommended

	for action in get_spell_learning_actions(session):
		if action is Dictionary and not bool(action.get("disabled", false)):
			var study: Dictionary = action.duplicate(true)
			study["lane"] = "study"
			return study
	for action in get_market_actions(session):
		if action is Dictionary and not bool(action.get("disabled", false)):
			var market: Dictionary = action.duplicate(true)
			market["lane"] = "market"
			return market
	for action in get_build_actions(session):
		if action is Dictionary:
			var build: Dictionary = action.duplicate(true)
			build["lane"] = "build"
			return build
	for action in get_recruit_actions(session):
		if action is Dictionary:
			var recruit: Dictionary = action.duplicate(true)
			recruit["lane"] = "recruit"
			return recruit
	return {}

static func _town_order_ui_surface_for_lane(lane: String) -> String:
	match lane:
		"build":
			return "Build tab"
		"recruit", "hero", "tavern", "transfer", "specialty":
			return "Muster tab"
		"study", "artifact":
			return "Spells tab"
		"market":
			return "Trade tab"
		"response":
			return "Log tab"
		_:
			return "Town orders"

static func _town_order_lane_label(lane: String) -> String:
	match lane:
		"build":
			return "Construction"
		"recruit":
			return "Recruitment"
		"response":
			return "Strategic response"
		"study":
			return "Spell study"
		"market":
			return "Exchange"
		"hero":
			return "Commander"
		"tavern":
			return "Hero hire"
		"transfer":
			return "Transfer"
		"artifact":
			return "Artifact"
		"specialty":
			return "Specialty"
		_:
			return "Town order"

static func _town_order_readiness_line(action: Dictionary, lane: String) -> String:
	if lane == "build":
		if bool(action.get("direct_affordable", false)):
			return "Ready now"
		if bool(action.get("market_coverable", false)):
			var market_summary := String(action.get("market_summary", ""))
			return "Needs exchange first%s" % (": %s" % market_summary if market_summary != "" else "")
		return String(action.get("disabled_reason", "Blocked by current town state"))
	if lane == "recruit":
		var direct_count := int(action.get("direct_affordable_count", 0))
		if direct_count > 0:
			return "Ready x%d" % direct_count
		var market_count := int(action.get("market_affordable_count", 0))
		if market_count > 0:
			var recruit_market_summary := String(action.get("market_summary", ""))
			return "Needs exchange x%d%s" % [
				market_count,
				": %s" % recruit_market_summary if recruit_market_summary != "" else "",
			]
		return String(action.get("disabled_reason", "Blocked by current town state"))
	if bool(action.get("disabled", false)):
		return String(action.get("disabled_reason", "Blocked by current town state"))
	var affordability := String(action.get("affordability_label", ""))
	if affordability != "":
		return affordability
	return "Ready now"

static func _town_order_impact_line(action: Dictionary, lane: String) -> String:
	var impact := String(action.get("impact_line", "")).strip_edges()
	if impact != "":
		return impact.trim_suffix(".")
	var recommendation := String(action.get("recommendation_line", "")).strip_edges()
	if recommendation != "":
		return recommendation.trim_suffix(".")
	var delivery := String(action.get("delivery_summary", "")).strip_edges()
	if delivery != "":
		return delivery.trim_suffix(".")
	var summary := String(action.get("summary", "")).strip_edges()
	if summary != "":
		var summary_lines := summary.split("\n", false)
		for line_value in summary_lines:
			var line := String(line_value).strip_edges()
			if line != "":
				return line.trim_suffix(".")
	return "%s keeps the town plan moving" % _town_order_lane_label(lane).to_lower()

static func _town_order_next_step(action: Dictionary, lane: String, label: String, where: String, readiness: String) -> String:
	if bool(action.get("disabled", false)):
		return "Resolve %s before pressing %s in %s." % [readiness.to_lower(), label, where]
	if lane == "build" and bool(action.get("market_coverable", false)) and not bool(action.get("direct_affordable", false)):
		return "Use the exchange path, then press %s in %s." % [label, where]
	if lane == "recruit" and int(action.get("direct_affordable_count", 0)) <= 0 and int(action.get("market_affordable_count", 0)) > 0:
		return "Use the exchange path, then press %s in %s." % [label, where]
	return "Press %s in %s, or leave when town orders are set." % [label, where]

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

static func _recruit_choice_impact_line(unit_id: String, ready_count: int, available_count: int) -> String:
	return HumanEngine.native(&"TownRules._recruit_choice_impact_line", [unit_id, ready_count, available_count])

static func _action_recommendation_line(lane: String, label: String, ready: bool, market_coverable: bool, shortfall_summary: String, impact_line: String) -> String:
	return HumanEngine.native(&"TownRules._action_recommendation_line", [lane, label, ready, market_coverable, shortfall_summary, impact_line])

static func _unit_tier_label(unit_tier: int) -> String:
	return HumanEngine.native(&"TownRules._unit_tier_label", [unit_tier])

static func _signed_int(value: int) -> String:
	return HumanEngine.native(&"TownRules._signed_int", [value])

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
		return "Use %s in Logistics, then return to the field route with %d move." % [label, move_left]
	var next_town_action := _next_town_action_line(session, town)
	if int(movement.get("current", 0)) <= 0:
		return "%s Then return to the field and choose End Turn to refresh movement." % next_town_action
	return "%s Then return to the field route with %d/%d move." % [
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
	var artifact_delta := _artifact_delta_summary(before.get("artifact_ids", []), after.get("artifact_ids", []))
	if artifact_delta != "":
		parts.append(artifact_delta)
	var reserve_delta := _signed_recruit_delta_summary(before.get("available_recruits", {}), after.get("available_recruits", {}), "Reserve")
	if reserve_delta != "":
		parts.append(reserve_delta)
	var army_delta := _signed_recruit_delta_summary(before.get("army_counts", {}), after.get("army_counts", {}), "Field")
	if army_delta != "":
		parts.append(army_delta)
	if lane == "recruit" and before.get("recruitment_holder_id", "") == after.get("recruitment_holder_id", ""):
		var destination_delta := _signed_recruit_delta_summary(before.get("recruitment_holder_counts", {}), after.get("recruitment_holder_counts", {}), String(after.get("recruitment_holder_label", "Local recipient")))
		if destination_delta != "":
			parts.append(destination_delta)
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
	if parts.size() == 5 and parts[0] == "market" and parts[1] == "convert":
		return "Exchange %s into %d %s" % [String(parts[2]), int(parts[4]), String(parts[3])]
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
	for resource_key in _resource_keys_for_payload(after):
		var delta := int(after.get(resource_key, 0)) - int(before.get(resource_key, 0))
		if delta == 0:
			continue
		parts.append("%s %s" % [resource_key, _signed_int(delta)])
	return "%s %s" % [label, ", ".join(parts)] if not parts.is_empty() else ""

static func _artifact_delta_summary(before_value: Variant, after_value: Variant) -> String:
	var before := _normalize_string_array(before_value)
	var after := _normalize_string_array(after_value)
	var added := []
	for artifact_id in after:
		if artifact_id not in before:
			added.append(ArtifactRulesScript.artifact_name(artifact_id))
	return "Artifact %s" % ", ".join(added) if not added.is_empty() else ""

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
	return HumanEngine.native_writing(&"TownRules._market_coverage_line", [readiness])

static func _cost_shortfall_line(readiness: Dictionary) -> String:
	return HumanEngine.native_writing(&"TownRules._cost_shortfall_line", [readiness])

static func _cost_readiness_line(resources: Dictionary, cost: Variant, readiness: Dictionary) -> String:
	return HumanEngine.native_writing(&"TownRules._cost_readiness_line", [resources, cost, readiness])

static func _stores_after_cost_line(resources: Dictionary, cost: Variant) -> String:
	return HumanEngine.native_writing(&"TownRules._stores_after_cost_line", [resources, cost])

static func _recruit_affordability_label(direct_count: int, market_count: int, shortfall_summary: String) -> String:
	return HumanEngine.native(&"TownRules._recruit_affordability_label", [direct_count, market_count, shortfall_summary])

static func _disabled_reason_line(ready: bool, market_coverable: bool, market_summary: String, shortfall_summary: String) -> String:
	return HumanEngine.native(&"TownRules._disabled_reason_line", [ready, market_coverable, market_summary, shortfall_summary])

static func _max_market_affordable_count(session: SessionStateStoreScript.SessionData, town: Dictionary, resources: Dictionary, unit_cost: Variant, available_count: int) -> int:
	return HumanEngine.native_writing(&"TownRules._max_market_affordable_count", [session, town, resources, unit_cost, available_count])

static func _multiply_resource_cost(cost: Variant, multiplier: int) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules._multiply_resource_cost", [cost, multiplier])

static func _building_line(building_id: String, state: String, build_status: Dictionary = {}) -> String:
	return HumanEngine.native_writing(&"TownRules._building_line", [building_id, state, build_status])

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
	return HumanEngine.native_writing(&"TownRules._town_name", [town])

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
	return HumanEngine.native_writing(&"TownRules._town_pressure_label", [town])

static func _describe_vulnerability_penalties(penalties: Dictionary) -> String:
	return HumanEngine.native_writing(&"TownRules._describe_vulnerability_penalties", [penalties])

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
			var pressure_clause: String = "%d known enemy hero%s already press the approaches" % [
				visible_pressuring,
				"" if visible_pressuring == 1 else "es",
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
				var marching_clause: String = "%d known enemy force%s can reach in %d day%s" % [
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
			var distant_clause: String = "%d known enemy force%s are marching on the lane" % [
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
		return "No known enemy hero is heading for %s. %s" % [_town_name(town), battlefront_summary]
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

const ENEMY_HERO_WATCH_RADIUS := 10

## Tiles between a computer player's hero and the town, or a large number for
## anything else (other armies, other levels).
static func _enemy_hero_distance_to_town(encounter: Dictionary, town: Dictionary) -> int:
	if not (encounter.get("ai_hero", null) is Dictionary) or int(encounter.get("level", 0)) != int(town.get("level", 0)):
		return 1 << 20
	return maxi(absi(int(encounter.get("x", 0)) - int(town.get("x", 0))), absi(int(encounter.get("y", 0)) - int(town.get("y", 0))))

static func _town_threat_lines(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	var scenario := ContentService.get_scenario_readonly(session.scenario_id)
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
			# An enemy hero's plans are hidden; a sighted hero close to the walls
			# is the threat a player can see.
			var hero_distance := _enemy_hero_distance_to_town(encounter, town)
			if String(encounter.get("target_placement_id", "")) != town_placement_id and hero_distance > ENEMY_HERO_WATCH_RADIUS:
				continue
			if resolved_encounters is Array and String(encounter.get("placement_id", "")) in resolved_encounters:
				continue
			var is_public: bool = EnemyAdventureRulesScript._raid_is_public(session, encounter)
			if hero_distance <= ENEMY_HERO_WATCH_RADIUS and not is_public:
				continue
			var is_pressuring := bool(encounter.get("arrived", false)) or int(encounter.get("goal_distance", 9999)) <= 0 or hero_distance <= 2
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
				var pressure_clause: String = "%d known enemy hero%s press the approaches" % [
					visible_pressuring,
					"" if visible_pressuring == 1 else "es",
				]
				if not pressuring_commanders.is_empty():
					pressure_clause += " (%s)" % ", ".join(pressuring_commanders.slice(0, min(2, pressuring_commanders.size())))
				clauses.append(pressure_clause)
		if visible_marching > 0:
			if visible_marching == 1 and not marching_commanders.is_empty():
				clauses.append("%s is marching on the town" % String(marching_commanders[0]))
			else:
				var marching_clause: String = "%d known enemy force%s are marching on the town" % [
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

static func _max_affordable_count(session: SessionStateStoreScript.SessionData, unit_cost: Variant) -> int:
	return HumanEngine.native_writing(&"TownRules._max_affordable_count", [session, unit_cost])

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
	return HumanEngine.native_writing(&"TownRules._describe_resources", [resources, empty_label])

static func _resource_keys_for_payload(value: Variant) -> Array:
	return HumanEngine.native_writing(&"TownRules._resource_keys_for_payload", [value])

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
	return HumanEngine.native_writing(&"TownRules._town_unit_ids", [town])

static func _unit_is_unlocked_in_town(town: Dictionary, unit_id: String) -> bool:
	return HumanEngine.native_writing(&"TownRules._unit_is_unlocked_in_town", [town, unit_id])

static func _unlock_building_for_unit(town: Dictionary, unit_id: String) -> String:
	return HumanEngine.native_writing(&"TownRules._unlock_building_for_unit", [town, unit_id])

static func _town_artifact_service_actions(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"TownRules._town_artifact_service_actions", [session, town])
