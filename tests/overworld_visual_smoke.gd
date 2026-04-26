extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	SessionState.set_active_session(session)

	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	var map_node = shell.get_node_or_null("%Map")
	if map_node == null:
		push_error("Overworld smoke: visual map node did not load.")
		get_tree().quit(1)
		return
	if not _assert_wireframe_contract(shell):
		return
	if not await _assert_objective_stakes_ui_contract(shell):
		return
	if not _assert_small_map_fit(shell):
		return
	if not await _assert_render_cache_split(shell):
		return
	if not _assert_marker_readability_contract(shell):
		return
	if not _assert_overworld_art_contract(shell):
		return
	if not _assert_object_economy_ui_contract(shell):
		return
	if not _assert_army_stack_inspection_contract(shell):
		return
	if not _assert_hero_identity_progression_contract(shell):
		return
	if not _assert_route_decision_clarity_contract(shell):
		return
	if not _assert_artifact_reward_visibility_contract(shell):
		return
	if not await _assert_overworld_magic_affordance_contract(shell):
		return
	if not await _assert_enemy_activity_feed_contract(shell):
		return
	if not await _assert_save_resume_clarity_contract(shell):
		return
	if not await _assert_diagonal_movement_contract(shell, map_node):
		return

	var start = OverworldRules.hero_position(SessionState.ensure_active_session())
	var map_size = OverworldRules.derive_map_size(SessionState.ensure_active_session())
	var directions = [
		Vector2i.RIGHT,
		Vector2i.DOWN,
		Vector2i.UP,
		Vector2i.LEFT,
	]

	var moved = false
	for direction in directions:
		var target: Vector2i = start + direction
		if target.x < 0 or target.y < 0 or target.x >= map_size.x or target.y >= map_size.y:
			continue
		if OverworldRules.tile_is_blocked(SessionState.ensure_active_session(), target.x, target.y):
			continue
		shell._on_map_tile_pressed(target)
		await get_tree().process_frame
		var end = OverworldRules.hero_position(SessionState.ensure_active_session())
		if end != start:
			moved = true
			break

	if not moved:
		push_error("Overworld smoke: unable to advance the hero through the visual map shell.")
		get_tree().quit(1)
		return

	_assert_remembered_owned_town_remote_entry(shell)
	return

func _assert_hero_identity_progression_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Overworld smoke: shell is missing hero identity validation hooks.")
		get_tree().quit(1)
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	if not _assert_text_contains_all(
		"overworld hero identity/progression rail",
		[
			String(snapshot.get("hero_text", "")),
			String(snapshot.get("hero_tooltip_text", "")),
			String(snapshot.get("heroes_text", "")),
			String(snapshot.get("heroes_tooltip_text", "")),
		],
		["Lyra Emberwell", "Embercourt League", "Fast scouting caster", "Lv1", "XP 0/250", "Wayfinder I", "Move", "Scout", "Army"]
	):
		return false
	return true

func _assert_render_cache_split(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot") or not shell.has_method("validation_select_tile") or not shell.has_method("validation_perform_primary_action"):
		push_error("Overworld smoke: shell did not expose the validation hooks needed for render-cache assertions.")
		get_tree().quit(1)
		return false
	var session = SessionState.ensure_active_session()
	var hero_pos := OverworldRules.hero_position(session)
	var target := _first_open_adjacent_tile(session, hero_pos)
	if target.x < 0:
		push_error("Overworld smoke: could not find an adjacent open tile for render-cache coverage.")
		get_tree().quit(1)
		return false
	var initial_cache := _render_cache_metrics(shell.call("validation_snapshot"))
	if initial_cache.is_empty():
		push_error("Overworld smoke: overworld map view did not expose render-cache metrics.")
		get_tree().quit(1)
		return false
	var selection_result: Dictionary = shell.call("validation_select_tile", target.x, target.y)
	var selection_cache := _render_cache_metrics(selection_result)
	if (
		selection_cache.is_empty()
		or int(selection_cache.get("session_static_generation", -1)) != int(initial_cache.get("session_static_generation", -1))
		or int(selection_cache.get("state_generation", -1)) != int(initial_cache.get("state_generation", -1))
		or int(selection_cache.get("dynamic_generation", -1)) <= int(initial_cache.get("dynamic_generation", -1))
	):
		push_error("Overworld smoke: selecting a route target should only redraw the dynamic overworld layer. before=%s after=%s." % [initial_cache, selection_cache])
		get_tree().quit(1)
		return false
	var move_result: Dictionary = shell.call("validation_perform_primary_action")
	await get_tree().process_frame
	var move_snapshot: Dictionary = shell.call("validation_snapshot")
	var move_cache := _render_cache_metrics(move_snapshot)
	if not bool(move_result.get("ok", false)):
		push_error("Overworld smoke: primary action did not move the hero during render-cache coverage. result=%s." % move_result)
		get_tree().quit(1)
		return false
	if not _assert_action_feedback("movement feedback cue", move_snapshot, "move", ["Moved:"]):
		return false
	if not _assert_post_action_recap(
		"movement post-action recap",
		move_snapshot,
		"move",
		["Moved from", "Affected:", "Why it matters:", "Next:", "scout net", "Push toward"]
	):
		return false
	if (
		int(move_cache.get("session_static_generation", -1)) != int(selection_cache.get("session_static_generation", -1))
		or int(move_cache.get("dynamic_generation", -1)) <= int(selection_cache.get("dynamic_generation", -1))
	):
		push_error("Overworld smoke: hero movement on the fitted small map should not rebuild the session-static terrain cache. select=%s move=%s." % [selection_cache, move_cache])
		get_tree().quit(1)
		return false
	return true

func _assert_objective_stakes_ui_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot") or not shell.has_method("validation_open_frontier_drawer"):
		push_error("Overworld smoke: shell is missing objective/stakes validation hooks.")
		get_tree().quit(1)
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	if not _assert_text_contains_all(
		"River Pass objective brief",
		[
			String(snapshot.get("objective_brief_visible_text", "")),
			String(snapshot.get("objective_brief_tooltip_text", "")),
		],
		[
			"Skirmish",
			"Objectives 0/4",
			"Next Claim Duskfen Bastion",
			"Objective Stakes",
			"Progress: 0/4 victory complete",
			"Incomplete: Claim Duskfen Bastion",
			"Defeat watch:",
			"Win: River Pass holds",
			"Lose: The Mireclaw warhost breaks the pass",
			"Current progress:",
			"Next step:",
		]
	):
		return false
	shell.call("validation_open_frontier_drawer")
	var frontier_snapshot: Dictionary = shell.call("validation_snapshot")
	if not _assert_text_contains_all(
		"River Pass objective drawer",
		[String(frontier_snapshot.get("objective_summary", ""))],
		["Objective Board", "Victory 0/4", "Defeat risks 0/3 triggered", "Claim Duskfen Bastion", "Avoid Defeat", "Current progress:", "Next step:"]
	):
		return false
	shell.call("_on_close_drawers_pressed")

	var original_session = SessionState.ensure_active_session()
	var campaign_session = CampaignRules.build_session(
		CampaignRules.normalize_profile({}),
		"river-pass",
		"normal",
		"campaign_reedfall"
	)
	if campaign_session.scenario_id == "":
		push_error("Overworld smoke: could not build campaign session for objective/stakes UI coverage.")
		get_tree().quit(1)
		return false
	SessionState.active_session = campaign_session
	var campaign_shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(campaign_shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var campaign_snapshot: Dictionary = campaign_shell.call("validation_snapshot")
	if not _assert_text_contains_all(
		"Campaign objective brief",
		[
			String(campaign_snapshot.get("objective_brief_visible_text", "")),
			String(campaign_snapshot.get("objective_brief_tooltip_text", "")),
		],
		[
			"Campaign",
			"Objectives 0/4",
			"Next Claim Duskfen Bastion",
			"Campaign: Lanterns Through Reedfall",
			"Chapter I: River Pass",
			"Campaign stakes:",
			"Secure Riverwatch",
			"Campaign arc:",
		]
	):
		return false
	campaign_shell.queue_free()
	SessionState.active_session = original_session
	shell.call("_refresh")
	await get_tree().process_frame
	return true

func _assert_diagonal_movement_contract(shell: Node, map_node: Node) -> bool:
	var session = SessionState.ensure_active_session()
	var start: Vector2i = OverworldRules.hero_position(session)
	var route_goal: Vector2i = _two_step_diagonal_goal(session, start)
	if route_goal.x < 0:
		var route_origin: Vector2i = _two_step_diagonal_origin(session)
		if route_origin.x >= 0:
			_set_active_hero_position(session, route_origin)
			OverworldRules.refresh_fog_of_war(session)
			shell.call("validation_select_tile", route_origin.x, route_origin.y)
			start = route_origin
			route_goal = _two_step_diagonal_goal(session, start)
	if route_goal.x < 0:
		push_error("Overworld smoke: could not find a two-step diagonal route for pathing coverage.")
		get_tree().quit(1)
		return false

	var route_selection: Dictionary = shell.call("validation_select_tile", route_goal.x, route_goal.y)
	if String(route_selection.get("primary_action_id", "")) != "advance_route":
		push_error("Overworld smoke: diagonal route goal did not expose route advancement. snapshot=%s goal=%s." % [route_selection, route_goal])
		get_tree().quit(1)
		return false
	var shell_route: Array = shell.call("_selected_route")
	var view_route: Array = map_node.call("_build_path", start, route_goal)
	if shell_route.size() != 3 or view_route.size() != 3:
		push_error("Overworld smoke: diagonal pathing did not use the expected two one-point steps. shell_route=%s view_route=%s start=%s goal=%s." % [shell_route, view_route, start, route_goal])
		get_tree().quit(1)
		return false
	var route_delta: Vector2i = route_goal - start
	var expected_first_step: Vector2i = start + Vector2i(1 if route_delta.x > 0 else -1, 1 if route_delta.y > 0 else -1)
	if shell_route[1] != expected_first_step or view_route[1] != shell_route[1]:
		push_error("Overworld smoke: diagonal pathing did not choose the diagonal first step. shell_route=%s view_route=%s start=%s goal=%s." % [shell_route, view_route, start, route_goal])
		get_tree().quit(1)
		return false

	var movement_before_route := int(session.overworld.get("movement", {}).get("current", 0))
	var route_result: Dictionary = shell.call("validation_perform_primary_action")
	await get_tree().process_frame
	var route_finish: Vector2i = OverworldRules.hero_position(session)
	var movement_after_route := int(session.overworld.get("movement", {}).get("current", 0))
	if not bool(route_result.get("ok", false)) or route_finish != shell_route[1] or movement_after_route != movement_before_route - 1:
		push_error("Overworld smoke: diagonal route advancement did not move one diagonal step for one point. result=%s route=%s finish=%s before=%d after=%d." % [route_result, shell_route, route_finish, movement_before_route, movement_after_route])
		get_tree().quit(1)
		return false

	_set_active_hero_position(session, start)
	OverworldRules.refresh_fog_of_war(session)
	shell.call("validation_select_tile", start.x, start.y)
	var click_target: Vector2i = _diagonal_open_tile(session, start)
	if click_target.x < 0:
		push_error("Overworld smoke: could not find an adjacent diagonal tile for click movement coverage.")
		get_tree().quit(1)
		return false
	var movement_before_click := int(session.overworld.get("movement", {}).get("current", 0))
	shell._on_map_tile_pressed(click_target)
	await get_tree().process_frame
	var click_finish: Vector2i = OverworldRules.hero_position(session)
	var movement_after_click := int(session.overworld.get("movement", {}).get("current", 0))
	if click_finish != click_target or movement_after_click != movement_before_click - 1:
		push_error("Overworld smoke: diagonal map click did not move to the adjacent diagonal tile for one point. target=%s finish=%s before=%d after=%d." % [click_target, click_finish, movement_before_click, movement_after_click])
		get_tree().quit(1)
		return false
	return true

func _assert_save_resume_clarity_contract(shell: Node) -> bool:
	if (
		not shell.has_method("validation_snapshot")
		or not shell.has_method("validation_select_save_slot")
		or not shell.has_method("validation_save_to_selected_slot")
	):
		push_error("Overworld smoke: shell is missing save/resume clarity validation hooks.")
		get_tree().quit(1)
		return false
	if not bool(shell.call("validation_select_save_slot", 1)):
		push_error("Overworld smoke: save slot selection failed for resume clarity coverage.")
		get_tree().quit(1)
		return false
	var save_result: Dictionary = shell.call("validation_save_to_selected_slot")
	await get_tree().process_frame
	if not bool(save_result.get("ok", false)):
		push_error("Overworld smoke: manual save did not report a loadable summary. result=%s" % save_result)
		get_tree().quit(1)
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	if not _assert_action_feedback(
		"manual save feedback cue",
		snapshot,
		"system",
		["Saved Manual 1:", "Skirmish", "River Pass", "Day"]
	):
		return false
	var summary: Dictionary = save_result.get("summary", {}) if save_result.get("summary", {}) is Dictionary else {}
	var save_surface: Dictionary = snapshot.get("save_surface", {}) if snapshot.get("save_surface", {}) is Dictionary else {}
	if not _assert_text_contains_all(
		"manual save resume summary",
		[
			String(summary.get("summary", "")),
			String(summary.get("detail", "")),
			String(save_surface.get("latest_context", "")),
			String(save_surface.get("current_context", "")),
			String(snapshot.get("save_status_tooltip_text", "")),
		],
		["Skirmish", "River Pass", "Day", "Resume target:", "Overworld"]
	):
		return false
	return true

func _assert_wireframe_contract(shell: Node) -> bool:
	var map_panel: Control = shell.get_node_or_null("%MapPanel")
	var map_frame: Control = shell.get_node_or_null("%MapFrame")
	var sidebar_shell: Control = shell.get_node_or_null("%SidebarShell")
	var command_spine: Control = shell.get_node_or_null("%CommandSpine")
	var command_band: Control = shell.get_node_or_null("%CommandBand")
	var top_strip: Control = shell.get_node_or_null("%TopStrip")
	var event_panel: Control = shell.get_node_or_null("%EventPanel")
	var commitment_panel: Control = shell.get_node_or_null("%CommitmentPanel")
	var briefing_panel: Control = shell.get_node_or_null("%BriefingPanel")
	var action_panel: Control = shell.get_node_or_null("%ActionPanel")
	var open_command: Button = shell.get_node_or_null("%OpenCommand")
	var open_frontier: Button = shell.get_node_or_null("%OpenFrontier")
	var hero_actions: Control = shell.get_node_or_null("%HeroActions")
	var context_actions: Control = shell.get_node_or_null("%ContextActions")
	var specialty_actions: Control = shell.get_node_or_null("%SpecialtyActions")
	var spell_actions: Control = shell.get_node_or_null("%SpellActions")
	var artifact_actions: Control = shell.get_node_or_null("%ArtifactActions")
	var resource_chip: Control = shell.get_node_or_null("%ResourceChip")
	var status_chip: Control = shell.get_node_or_null("%StatusChip")
	var cue_chip: Control = shell.get_node_or_null("%CueChip")
	var required_nodes = [
		map_panel,
		map_frame,
		sidebar_shell,
		command_spine,
		command_band,
		top_strip,
		event_panel,
		commitment_panel,
		briefing_panel,
		action_panel,
		open_command,
		open_frontier,
		hero_actions,
		context_actions,
		specialty_actions,
		spell_actions,
		artifact_actions,
		resource_chip,
		status_chip,
		cue_chip,
	]
	for node in required_nodes:
		if node == null:
			push_error("Overworld smoke: wireframe contract node is missing.")
			get_tree().quit(1)
			return false

	var map_rect := map_panel.get_global_rect()
	var sidebar_rect := sidebar_shell.get_global_rect()
	var footer_rect := command_band.get_global_rect()
	var shell_rect := (shell as Control).get_global_rect() if shell is Control else get_viewport().get_visible_rect()
	var main_area := map_rect.size.x * map_rect.size.y
	var body_area := main_area + (sidebar_rect.size.x * sidebar_rect.size.y)
	if body_area <= 0.0 or main_area / body_area < 0.74:
		push_error("Overworld smoke: adventure map is not dominant enough for the wireframe contract.")
		get_tree().quit(1)
		return false
	if map_rect.size.x <= sidebar_rect.size.x * 3.0:
		push_error("Overworld smoke: right command spine is stealing too much horizontal map surface.")
		get_tree().quit(1)
		return false
	if sidebar_rect.position.x < map_rect.position.x + map_rect.size.x - 1.0:
		push_error("Overworld smoke: command spine is not fixed to the right of the map.")
		get_tree().quit(1)
		return false
	if footer_rect.size.y > max(96.0, shell_rect.size.y * 0.12):
		push_error("Overworld smoke: footer ribbon regressed into an oversized bottom slab. footer=%.1f shell=%.1f" % [footer_rect.size.y, shell_rect.size.y])
		get_tree().quit(1)
		return false
	if footer_rect.position.y < map_rect.position.y + map_rect.size.y - 1.0:
		push_error("Overworld smoke: command footer is not below the map stage.")
		get_tree().quit(1)
		return false
	for panel in [top_strip, event_panel, commitment_panel, briefing_panel]:
		if not _is_descendant_of(panel, sidebar_shell):
			push_error("Overworld smoke: light status panels must live inside the carved right shell.")
			get_tree().quit(1)
			return false
	if not _assert_decluttered_right_shell(shell, sidebar_shell, command_spine, action_panel, [hero_actions, context_actions, specialty_actions, spell_actions, artifact_actions]):
		return false
	for chip in [resource_chip, status_chip, cue_chip]:
		if not _is_descendant_of(chip, command_band):
			push_error("Overworld smoke: resources, date, and map cue must live inside the footer ribbon.")
			get_tree().quit(1)
			return false
	return true

func _assert_object_economy_ui_contract(shell: Node) -> bool:
	if not shell.has_method("validation_select_tile") or not shell.has_method("validation_hover_tile") or not shell.has_method("validation_resource_site_state"):
		push_error("Overworld smoke: shell is missing object/economy UI validation hooks.")
		get_tree().quit(1)
		return false
	var session = SessionState.ensure_active_session()
	var original_fog = session.overworld.get("fog", {}).duplicate(true)
	var original_hero_position = session.overworld.get("hero_position", {}).duplicate(true)
	var original_movement = session.overworld.get("movement", {}).duplicate(true)
	var original_resources = session.overworld.get("resources", {}).duplicate(true)
	var original_resource_nodes = session.overworld.get("resource_nodes", []).duplicate(true)
	_set_active_hero_position(session, Vector2i(1, 2))
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_refresh")

	var timber: Dictionary = shell.call("validation_select_tile", 1, 0)
	if not _assert_text_contains_all(
		"River Pass timber pickup/cache UI",
		[String(timber.get("context_summary", "")), String(timber.get("selected_tile_rail_text", ""))],
		["Pickup/cache", "Class: Pickup", "Cadence: one-time", "Reward"]
	):
		return false
	var signal_post: Dictionary = shell.call("validation_select_tile", 2, 3)
	if not _assert_text_contains_all(
		"River Pass signal post economy UI",
		[
			String(signal_post.get("context_summary", "")),
			String(signal_post.get("selected_tile_rail_text", "")),
			String(signal_post.get("map_tooltip", "")),
		],
		[
			"Transit/support object",
			"Faction Outpost",
			"Unclaimed",
			"Daily",
			"support response",
			"Control: Unclaimed; capture flips control.",
			"Economy: claim 50 gold, daily 20 gold",
			"Route: Linked Riverwatch Hold",
		]
	):
		return false
	var town_context: Dictionary = shell.call("validation_select_tile", 0, 2)
	if not _assert_text_contains_all(
		"River Pass selected town faction identity UI",
		[String(town_context.get("context_summary", "")), String(town_context.get("selected_tile_rail_text", "")), String(town_context.get("map_tooltip", ""))],
		["Riverwatch Hold", "Embercourt League", "Frontier Stronghold", "Economy:", "Stable civic investment", "Magic:", "Strategic cue:"]
	):
		return false
	if not _assert_no_ai_score_leak("selected town faction identity UI", String(town_context.get("context_summary", ""))):
		return false
	var timber_hover: Dictionary = shell.call("validation_hover_tile", 1, 0)
	if not _assert_text_contains_all(
		"River Pass timber hover tooltip",
		[String(timber_hover.get("map_tooltip", ""))],
		["Timber Wagon", "Pickup/cache", "Cadence: one-time"]
	):
		return false
	var signal_state: Dictionary = shell.call("validation_resource_site_state", "river_signal_post")
	if not _assert_text_contains_all(
		"River Pass signal post validation surface",
		[
			String(signal_state.get("surface", "")),
			String(signal_state.get("interaction_surface", "")),
			String(signal_state.get("control_summary", "")),
			String(signal_state.get("control_inspection", "")),
		],
		[
			"Transit/support object",
			"Cadence: persistent control",
			"capture/ownership",
			"income",
			"Control unclaimed",
			"claim 50 gold, daily 20 gold",
			"Linked Riverwatch Hold",
		]
	):
		return false
	_set_active_hero_position(session, Vector2i(2, 3))
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_refresh")
	var signal_result: Dictionary = shell.call("validation_perform_context_action", "collect_resource")
	if not bool(signal_result.get("ok", false)):
		push_error("Overworld smoke: signal post context order did not resolve through live UI. result=%s" % signal_result)
		get_tree().quit(1)
		return false
	var signal_snapshot: Dictionary = shell.call("validation_snapshot")
	if not _assert_action_feedback("resource site feedback cue", signal_snapshot, "collect", ["Collected:", "Ember Signal Post"]):
		return false
	if not _assert_post_action_recap(
		"resource site post-action recap",
		signal_snapshot,
		"resource_site",
		["Ember Signal Post", "Affected:", "Why it matters:", "Next:", "daily", "route"]
	):
		return false
	session.overworld["resources"] = original_resources
	session.overworld["resource_nodes"] = original_resource_nodes
	session.overworld["movement"] = original_movement
	_set_active_hero_position(session, Vector2i(1, 2))
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_refresh")

	var free_company: Dictionary = shell.call("validation_select_tile", 0, 4)
	if not _assert_text_contains_all(
		"River Pass free company recruit-site UI",
		[
			String(free_company.get("context_summary", "")),
			String(free_company.get("selected_tile_rail_text", "")),
			String(free_company.get("map_tooltip", "")),
			String(free_company.get("primary_action", {}).get("summary", "")),
		],
		[
			"Persistent recruit site",
			"Neutral Dwelling",
			"Recruit Source: Riverwatch Free Company Yard | Faction-linked muster",
			"Ready: +3 Ember Archer (T2 Ranged, 85 gold), +5 River Guard (T1 Melee, 60 gold)",
			"Weekly: +1 River Guard (T1 Melee, 60 gold) to nearest held town",
			"Cadence: persistent control | Control unclaimed",
			"Support: Dispatch Relief",
			"140 gold ready",
			"Why: Capture adds field recruits, feeds weekly musters, keeps local pay flowing.",
		]
	):
		return false

	var encounter: Dictionary = shell.call("validation_select_tile", 3, 1)
	if not _assert_text_contains_all(
		"River Pass safe encounter metadata UI",
		[
			String(encounter.get("context_summary", "")),
			String(encounter.get("selected_tile_rail_text", "")),
			String(encounter.get("primary_action", {}).get("summary", "")),
		],
		[
			"Neutral Encounter",
			"Visible Army",
			"Route Pressure",
			"Risk Light",
			"Difficulty Low",
			"Army: Blackbranch Raiders",
			"12 troops/2 groups",
			"Blackbranch Cutthroat x8",
			"Readiness: your army",
			"Ready",
			"Reward: 250 gold, 180 xp",
			"Cadence: one-time",
			"Clear: advances Break the Blackbranch raiders",
			"After clear: reveals Waystone Cache",
		]
	):
		return false
	shell.call("validation_select_tile", 1, 0)
	var encounter_hover: Dictionary = shell.call("validation_hover_tile", 3, 1)
	if not _assert_text_contains_all(
		"River Pass encounter hover tooltip",
		[String(encounter_hover.get("map_tooltip", ""))],
		["Ghoul Grove", "Risk Light", "Difficulty Low", "Blackbranch Raiders", "12 troops/2 groups", "Reward 250 gold, 180 xp", "Clear: advances Break the Blackbranch raiders"]
	):
		return false

	session.overworld["fog"] = original_fog
	session.overworld["movement"] = original_movement
	session.overworld["resources"] = original_resources
	session.overworld["resource_nodes"] = original_resource_nodes
	_set_active_hero_position(
		session,
		Vector2i(int(original_hero_position.get("x", 0)), int(original_hero_position.get("y", 0)))
	)
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_refresh")
	return true

func _assert_route_decision_clarity_contract(shell: Node) -> bool:
	if not shell.has_method("validation_select_tile") or not shell.has_method("validation_snapshot"):
		push_error("Overworld smoke: shell is missing route-decision validation hooks.")
		get_tree().quit(1)
		return false
	var session = SessionState.ensure_active_session()
	var original_fog = session.overworld.get("fog", {}).duplicate(true)
	var original_hero_position = session.overworld.get("hero_position", {}).duplicate(true)
	var original_hero = session.overworld.get("hero", {}).duplicate(true)
	var original_player_heroes = session.overworld.get("player_heroes", []).duplicate(true)
	var original_movement = session.overworld.get("movement", {}).duplicate(true)
	var original_resource_nodes = session.overworld.get("resource_nodes", []).duplicate(true)
	var original_encounters = session.overworld.get("encounters", []).duplicate(true)

	_set_active_hero_position(session, Vector2i(1, 2))
	var movement: Dictionary = session.overworld.get("movement", {})
	movement["current"] = int(movement.get("max", movement.get("current", 0)))
	session.overworld["movement"] = movement
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_refresh")

	var reachable: Dictionary = shell.call("validation_select_tile", 1, 0)
	if not _assert_route_decision_fields(
		"reachable route decision",
		reachable,
		"reachable",
		"move/collect",
		2,
		["Route:", "Timber Wagon", "Move/collect", "2 steps", "reachable today", "Move"]
	):
		return false
	if not _assert_text_contains_all(
		"reachable route visible UI",
		[
			String(reachable.get("map_cue_text", "")),
			String(reachable.get("context_visible_text", "")),
			String(reachable.get("selected_tile_rail_text", "")),
			String(reachable.get("map_tooltip", "")),
			String(reachable.get("primary_action", {}).get("summary", "")),
		],
		["Timber Wagon", "Route:", "2 step", "Move", "reachable today"]
	):
		return false

	movement = session.overworld.get("movement", {})
	movement["current"] = 1
	session.overworld["movement"] = movement
	shell.call("_refresh")
	var not_today: Dictionary = shell.call("validation_select_tile", 1, 0)
	if not _assert_route_decision_fields(
		"not-today route decision",
		not_today,
		"not_today",
		"move/collect",
		2,
		["not reachable today", "Move 1->0"]
	):
		return false

	movement = session.overworld.get("movement", {})
	movement["current"] = 0
	session.overworld["movement"] = movement
	shell.call("_refresh")
	var no_movement: Dictionary = shell.call("validation_select_tile", 1, 0)
	if not _assert_route_decision_fields(
		"no-movement route decision",
		no_movement,
		"no_movement",
		"move/collect",
		2,
		["no movement", "No movement left today", "Move 0/"]
	):
		return false

	movement = session.overworld.get("movement", {})
	movement["current"] = int(movement.get("max", movement.get("current", 0)))
	session.overworld["movement"] = movement
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_refresh")
	var blocked_tile := _first_visible_blocked_tile(session)
	if blocked_tile.x >= 0:
		var blocked: Dictionary = shell.call("validation_select_tile", blocked_tile.x, blocked_tile.y)
		if not _assert_route_decision_fields(
			"blocked route decision",
			blocked,
			"blocked",
			"move",
			0,
			["blocked", "blocks travel", "Move"]
		):
			return false

	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if not (nodes[index] is Dictionary):
			continue
		var node: Dictionary = nodes[index]
		if String(node.get("placement_id", "")) != "river_free_company":
			continue
		node["collected"] = true
		node["collected_by_faction_id"] = "player"
		node["collected_day"] = session.day
		node["response_origin"] = "field"
		node["response_source_town_id"] = "riverwatch_hold"
		node["response_last_day"] = session.day
		node["response_until_day"] = session.day + 2
		node["response_commander_id"] = String(session.overworld.get("hero", {}).get("id", ""))
		node["response_security_rating"] = 2
		node["delivery_controller_id"] = "player"
		node["delivery_origin_town_id"] = "riverwatch_hold"
		node["delivery_target_kind"] = "town"
		node["delivery_target_id"] = "riverwatch_hold"
		node["delivery_target_label"] = "Riverwatch Hold"
		node["delivery_arrival_day"] = session.day
		node["delivery_manifest"] = {"unit_river_guard": 2}
		nodes[index] = node
		break
	session.overworld["resource_nodes"] = nodes
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(
		{
			"placement_id": "smoke_mireclaw_convoy_interceptor",
			"encounter_id": "encounter_mire_raid",
			"x": 0,
			"y": 3,
			"difficulty": "scripted",
			"spawned_by_faction_id": "faction_mireclaw",
			"days_active": 2,
			"arrived": true,
			"target_kind": "resource",
			"target_placement_id": "river_free_company",
			"target_label": "Riverwatch Free Company Yard",
			"goal_x": 0,
			"goal_y": 4,
			"goal_distance": 0,
			"delivery_intercept_node_placement_id": "river_free_company",
			"enemy_army": {"id": "smoke_mireclaw_convoy_interceptor", "name": "Smoke Interceptor", "stacks": []},
		}
	)
	session.overworld["encounters"] = encounters
	_set_active_hero_position(session, Vector2i(1, 2))
	movement = session.overworld.get("movement", {})
	movement["current"] = int(movement.get("max", movement.get("current", 0)))
	session.overworld["movement"] = movement
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_refresh")
	var convoy_watch: Dictionary = shell.call("validation_select_tile", 0, 4)
	var convoy_decision: Dictionary = convoy_watch.get("selected_route_decision", {})
	var route_watch: Dictionary = convoy_decision.get("interception", {})
	if not bool(route_watch.get("active", false)):
		push_error("Overworld smoke: convoy route decision did not expose an active interception watch. snapshot=%s" % convoy_watch)
		get_tree().quit(1)
		return false
	if not _assert_text_contains_all(
		"convoy route interception clarity",
		[
			String(convoy_watch.get("selected_route_decision_text", "")),
			String(convoy_watch.get("map_cue_tooltip_text", "")),
			String(convoy_watch.get("selected_tile_rail_text", "")),
			String(convoy_watch.get("primary_action", {}).get("summary", "")),
			String(convoy_watch.get("event_tooltip_text", "")),
			String(convoy_watch.get("frontier_watch", "")),
			String(route_watch.get("tooltip_text", "")),
		],
		[
			"Watch:",
			"Convoy blocked",
			"Riverwatch Free Company Yard",
			"Riverwatch Hold",
			"Interception Watch",
			"Why it matters",
			"Next:",
			"Break",
			"control",
			"Defense readiness:",
			"Why:",
			"response",
			"intercept",
		]
	):
		return false
	if not _assert_no_ai_score_leak(
		"convoy route interception clarity",
		"\n".join([
			String(convoy_watch.get("selected_route_decision_text", "")),
			String(convoy_watch.get("map_cue_tooltip_text", "")),
			String(convoy_watch.get("event_tooltip_text", "")),
			String(convoy_watch.get("frontier_watch", "")),
			String(route_watch.get("tooltip_text", "")),
		])
	):
		return false

	session.overworld["fog"] = original_fog
	session.overworld["hero"] = original_hero
	session.overworld["player_heroes"] = original_player_heroes
	session.overworld["hero_position"] = original_hero_position
	session.overworld["movement"] = original_movement
	session.overworld["resource_nodes"] = original_resource_nodes
	session.overworld["encounters"] = original_encounters
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_refresh")
	return true

func _assert_army_stack_inspection_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Overworld smoke: shell is missing army stack validation snapshot.")
		get_tree().quit(1)
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	if not _assert_text_contains_all(
		"Overworld army stack inspection",
		[
			String(snapshot.get("army_text", "")),
			String(snapshot.get("army_visible_text", "")),
			String(snapshot.get("army_tooltip_text", "")),
		],
		["Marching Army", "Strength", "HP", "T", "Ready"]
	):
		return false
	return true

func _assert_route_decision_fields(label: String, snapshot: Dictionary, expected_status: String, expected_action_kind: String, expected_steps: int, text_needles: Array) -> bool:
	var route_decision: Dictionary = snapshot.get("selected_route_decision", {})
	if route_decision.is_empty():
		push_error("Overworld smoke: %s did not expose selected_route_decision. snapshot=%s" % [label, snapshot])
		get_tree().quit(1)
		return false
	if String(route_decision.get("status", "")) != expected_status:
		push_error("Overworld smoke: %s exposed wrong route status. expected=%s decision=%s" % [label, expected_status, route_decision])
		get_tree().quit(1)
		return false
	if String(route_decision.get("action_kind", "")) != expected_action_kind:
		push_error("Overworld smoke: %s exposed wrong action kind. expected=%s decision=%s" % [label, expected_action_kind, route_decision])
		get_tree().quit(1)
		return false
	if int(route_decision.get("steps", -1)) != expected_steps:
		push_error("Overworld smoke: %s exposed wrong step count. expected=%d decision=%s" % [label, expected_steps, route_decision])
		get_tree().quit(1)
		return false
	var text := "\n".join([
		String(snapshot.get("selected_route_decision_text", "")),
		String(snapshot.get("map_cue_text", "")),
		String(snapshot.get("map_cue_tooltip_text", "")),
		String(snapshot.get("context_visible_text", "")),
		String(snapshot.get("selected_tile_rail_text", "")),
		String(snapshot.get("map_tooltip", "")),
	])
	for needle in text_needles:
		if text.find(String(needle)) < 0:
			push_error("Overworld smoke: %s route UI missing '%s'. decision=%s text=%s" % [label, String(needle), route_decision, text])
			get_tree().quit(1)
			return false
	return true

func _assert_artifact_reward_visibility_contract(shell: Node) -> bool:
	if not shell.has_method("validation_select_tile") or not shell.has_method("validation_hover_tile") or not shell.has_method("validation_perform_primary_action"):
		push_error("Overworld smoke: shell is missing artifact reward visibility validation hooks.")
		get_tree().quit(1)
		return false
	var session = SessionState.ensure_active_session()
	var original_fog = session.overworld.get("fog", {}).duplicate(true)
	var original_hero = session.overworld.get("hero", {}).duplicate(true)
	var original_player_heroes = session.overworld.get("player_heroes", []).duplicate(true)
	var original_hero_position = session.overworld.get("hero_position", {}).duplicate(true)
	var original_movement = session.overworld.get("movement", {}).duplicate(true)
	var original_artifact_nodes = session.overworld.get("artifact_nodes", []).duplicate(true)

	_set_active_hero_position(session, Vector2i(1, 0))
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_refresh")
	var artifact_selection: Dictionary = shell.call("validation_select_tile", 2, 0)
	if not _assert_text_contains_all(
		"River Pass artifact inspection UI",
		[
			String(artifact_selection.get("context_summary", "")),
			String(artifact_selection.get("selected_tile_rail_text", "")),
			String(artifact_selection.get("primary_action", {}).get("summary", "")),
		],
		["Trailsinger Boots", "Slot Boots", "Footgear", "Exploration reward", "Standalone relic", "+2 move", "Impact Field Move +2", "Will auto-equip"]
	):
		return false

	shell.call("validation_select_tile", 1, 0)
	var artifact_hover: Dictionary = shell.call("validation_hover_tile", 2, 0)
	if not _assert_text_contains_all(
		"River Pass artifact hover tooltip",
		[String(artifact_hover.get("map_tooltip", ""))],
		["Trailsinger Boots", "Exploration reward", "+2 move", "Impact Field Move +2"]
	):
		return false

	shell.call("validation_select_tile", 2, 0)
	var collect_result: Dictionary = shell.call("validation_perform_primary_action")
	if not bool(collect_result.get("ok", false)):
		push_error("Overworld smoke: artifact primary order did not collect through live UI. result=%s" % collect_result)
		get_tree().quit(1)
		return false
	if not _assert_text_contains_all(
		"River Pass artifact collection message",
		[String(collect_result.get("message", ""))],
		["Trailsinger Boots", "Exploration reward", "+2 move", "Equipped in Boots slot"]
	):
		return false
	if not _assert_action_feedback("artifact pickup feedback cue", shell.call("validation_snapshot"), "artifact", ["Artifact:", "Trailsinger Boots"]):
		return false
	if not _assert_post_action_recap(
		"artifact post-action recap",
		shell.call("validation_snapshot"),
		"artifact",
		["Recovered Trailsinger Boots", "Affected:", "Why it matters:", "Next:", "+2 move"]
	):
		return false
	var commander_state: Dictionary = shell.call("validation_snapshot").get("commander_state", {})
	if "artifact_trailsinger_boots" not in commander_state.get("artifact_ids", []):
		push_error("Overworld smoke: collected artifact was not visible in commander state. state=%s" % commander_state)
		get_tree().quit(1)
		return false
	if not _assert_artifact_loadout_decision_contract(shell):
		return false

	session.overworld["fog"] = original_fog
	session.overworld["hero"] = original_hero
	session.overworld["player_heroes"] = original_player_heroes
	session.overworld["hero_position"] = original_hero_position
	session.overworld["movement"] = original_movement
	session.overworld["artifact_nodes"] = original_artifact_nodes
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_refresh")
	return true

func _assert_artifact_loadout_decision_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot") or not shell.has_method("validation_perform_artifact_action"):
		push_error("Overworld smoke: shell is missing artifact loadout validation hooks.")
		get_tree().quit(1)
		return false
	var session = SessionState.ensure_active_session()
	var hero: Dictionary = session.overworld.get("hero", {})
	var artifacts: Dictionary = ArtifactRules.normalize_hero_artifacts(hero.get("artifacts", {}))
	var inventory: Array = artifacts.get("inventory", [])
	if "artifact_warcrest_pennon" not in inventory:
		inventory.append("artifact_warcrest_pennon")
	artifacts["inventory"] = inventory
	hero["artifacts"] = ArtifactRules.normalize_hero_artifacts(artifacts)
	session.overworld["hero"] = hero
	shell.call("_refresh")

	var snapshot: Dictionary = shell.call("validation_snapshot")
	var gear_text := "%s\n%s" % [
		String(snapshot.get("artifact_text", "")),
		String(snapshot.get("artifact_tooltip_text", "")),
	]
	if not _assert_text_contains_all(
		"Overworld artifact loadout rail",
		[gear_text],
		[
			"Boots: Trailsinger Boots",
			"Equipped",
			"Pack",
			"Warcrest Pennon",
			"Can equip to empty Banner",
			"Gear impact",
			"Collection",
			"+1 attack",
		]
	):
		return false

	var equip_action := _validation_action_by_id(snapshot.get("artifact_actions", []), "equip_artifact:artifact_warcrest_pennon")
	if equip_action.is_empty():
		push_error("Overworld smoke: pack artifact did not expose a live equip action. snapshot=%s" % snapshot)
		get_tree().quit(1)
		return false
	if not _assert_text_contains_all(
		"Overworld artifact equip action",
		[String(equip_action.get("label", "")), String(equip_action.get("summary", ""))],
		["Equip Warcrest Pennon", "Can equip to empty Banner", "Command reward", "Impact Field no change", "Command Attack +1", "+1 attack"]
	):
		return false

	var equip_result: Dictionary = shell.call("validation_perform_artifact_action", "equip_artifact:artifact_warcrest_pennon")
	if not bool(equip_result.get("ok", false)):
		push_error("Overworld smoke: live artifact equip action did not update the loadout. result=%s" % equip_result)
		get_tree().quit(1)
		return false
	if not _assert_text_contains_all(
		"Overworld artifact equip result",
		[
			String(equip_result.get("message", "")),
			String(equip_result.get("artifact_tooltip_text", "")),
		],
		["Equipped Warcrest Pennon from pack into Banner", "Banner: Warcrest Pennon", "Equipped", "Gear impact", "Command Attack +1", "+1 attack"]
	):
		return false
	if not _assert_action_feedback("artifact equip feedback cue", shell.call("validation_snapshot"), "artifact", ["Artifact:", "Warcrest Pennon"]):
		return false

	var stow_action := _validation_action_by_id(equip_result.get("artifact_actions", []), "unequip_artifact:banner")
	if stow_action.is_empty():
		push_error("Overworld smoke: equipped artifact did not expose a live stow action. result=%s" % equip_result)
		get_tree().quit(1)
		return false
	if not _assert_text_contains_all(
		"Overworld artifact stow action",
		[String(stow_action.get("label", "")), String(stow_action.get("summary", ""))],
		["Stow Warcrest Pennon", "Move to pack", "Removes Impact", "Command Attack +1", "+1 attack"]
	):
		return false
	var stow_result: Dictionary = shell.call("validation_perform_artifact_action", "unequip_artifact:banner")
	if not bool(stow_result.get("ok", false)):
		push_error("Overworld smoke: live artifact stow action did not update the loadout. result=%s" % stow_result)
		get_tree().quit(1)
		return false
	if not _assert_text_contains_all(
		"Overworld artifact stow result",
		[String(stow_result.get("message", "")), String(stow_result.get("artifact_tooltip_text", ""))],
		["Stowed Warcrest Pennon from Banner into pack", "Removed: +1 attack", "Warcrest Pennon", "Can equip to empty Banner"]
	):
		return false
	return true

func _assert_overworld_magic_affordance_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot") or not shell.has_method("validation_select_tile") or not shell.has_method("validation_perform_primary_action") or not shell.has_method("validation_cast_overworld_spell"):
		push_error("Overworld smoke: shell is missing overworld magic validation hooks.")
		get_tree().quit(1)
		return false
	var session = SessionState.ensure_active_session()
	var original_fog = session.overworld.get("fog", {}).duplicate(true)
	var original_hero = session.overworld.get("hero", {}).duplicate(true)
	var original_player_heroes = session.overworld.get("player_heroes", []).duplicate(true)
	var original_hero_position = session.overworld.get("hero_position", {}).duplicate(true)
	var original_movement = session.overworld.get("movement", {}).duplicate(true)

	var movement: Dictionary = session.overworld.get("movement", {})
	movement["current"] = int(movement.get("max", movement.get("current", 0)))
	session.overworld["movement"] = movement
	shell.call("_refresh")
	var full_snapshot: Dictionary = shell.call("validation_snapshot")
	var full_spell_action := _validation_action_by_id(full_snapshot.get("spell_actions", []), "cast_spell:spell_waystride")
	if full_spell_action.is_empty():
		push_error("Overworld smoke: Waystride field spell action was not exposed in the live command drawer. actions=%s" % full_snapshot.get("spell_actions", []))
		get_tree().quit(1)
		return false
	if not bool(full_spell_action.get("disabled", false)):
		push_error("Overworld smoke: full-movement field spell should be disabled until movement can fit. action=%s" % full_spell_action)
		get_tree().quit(1)
		return false
	if not _assert_text_contains_all(
		"Overworld field spell unavailable affordance",
		[
			String(full_snapshot.get("spellbook_tooltip_text", "")),
			String(full_snapshot.get("spellbook_visible_text", "")),
			String(full_snapshot.get("spellbook_rail_text", "")),
			String(full_spell_action.get("summary", "")),
			String(full_spell_action.get("invalid_reason", "")),
			String(full_spell_action.get("category", "")),
			String(full_spell_action.get("readiness", "")),
			String(full_spell_action.get("effect", "")),
			String(full_spell_action.get("best_use", "")),
			String(full_spell_action.get("target_requirement", "")),
			String(full_spell_action.get("mana_state", "")),
			String(full_spell_action.get("consequence", "")),
			String(full_spell_action.get("why_cast", "")),
		],
		["Waystride", "Field Magic", "Field Route", "Cost 3", "target active hero", "No map target", "affects active hero", "Movement is already full", "Mana", "need 3", "Restores up to 4 movement", "save until movement has room"]
	):
		return false

	var start := OverworldRules.hero_position(session)
	var safe_step: Vector2i = shell.call("_first_validation_safe_step", start)
	if safe_step.x < 0:
		push_error("Overworld smoke: could not find a safe step for field spell movement coverage.")
		get_tree().quit(1)
		return false
	shell.call("validation_select_tile", safe_step.x, safe_step.y)
	var move_result: Dictionary = shell.call("validation_perform_primary_action")
	await get_tree().process_frame
	if not bool(move_result.get("ok", false)):
		push_error("Overworld smoke: could not spend movement before field spell cast coverage. result=%s" % move_result)
		get_tree().quit(1)
		return false
	var ready_snapshot: Dictionary = shell.call("validation_snapshot")
	var ready_spell_action := _validation_action_by_id(ready_snapshot.get("spell_actions", []), "cast_spell:spell_waystride")
	if ready_spell_action.is_empty() or bool(ready_spell_action.get("disabled", false)):
		push_error("Overworld smoke: spent movement did not make Waystride castable. action=%s" % ready_spell_action)
		get_tree().quit(1)
		return false
	if not _assert_text_contains_all(
		"Overworld field spell ready affordance",
		[
			String(ready_snapshot.get("spellbook_tooltip_text", "")),
			String(ready_snapshot.get("spellbook_visible_text", "")),
			String(ready_snapshot.get("spellbook_rail_text", "")),
			String(ready_spell_action.get("label", "")),
			String(ready_spell_action.get("summary", "")),
			String(ready_spell_action.get("readiness", "")),
			String(ready_spell_action.get("best_use", "")),
			String(ready_spell_action.get("target_requirement", "")),
			String(ready_spell_action.get("mana_state", "")),
			String(ready_spell_action.get("consequence", "")),
			String(ready_spell_action.get("why_cast", "")),
		],
		["Cast Waystride (3 mana)", "Field Magic", "Field Route", "Restores up to 4 movement", "Cost 3", "target active hero", "No map target", "affects active hero", "Mana", "need 3", "Ready", "recover route tempo"]
	):
		return false

	var cast_result: Dictionary = shell.call("validation_cast_overworld_spell", "spell_waystride")
	if not bool(cast_result.get("ok", false)):
		push_error("Overworld smoke: Waystride did not cast through the live overworld UI. result=%s" % cast_result)
		get_tree().quit(1)
		return false
	if not _assert_text_contains_all(
		"Overworld field spell outcome feedback",
		[String(cast_result.get("message", ""))],
		["Waystride restores", "movement", "spends 3 mana"]
	):
		return false
	var cast_snapshot: Dictionary = shell.call("validation_snapshot")
	if String(cast_snapshot.get("event_visible_text", "")).find("Waystride restores") < 0:
		push_error("Overworld smoke: spell cast outcome did not surface in the live event rail. snapshot=%s" % cast_snapshot)
		get_tree().quit(1)
		return false
	if not _assert_action_feedback("spell cast feedback cue", cast_snapshot, "cast", ["Cast:", "Waystride restores"]):
		return false

	session.overworld["fog"] = original_fog
	session.overworld["hero"] = original_hero
	session.overworld["player_heroes"] = original_player_heroes
	session.overworld["hero_position"] = original_hero_position
	session.overworld["movement"] = original_movement
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_refresh")
	return true

func _assert_enemy_activity_feed_contract(shell: Node) -> bool:
	if not shell.has_method("validation_end_turn") or not shell.has_method("validation_snapshot"):
		push_error("Overworld smoke: shell is missing enemy-activity validation hooks.")
		get_tree().quit(1)
		return false
	var before_snapshot: Dictionary = shell.call("validation_snapshot")
	var forecast_text := String(before_snapshot.get("end_turn_forecast", ""))
	var forecast_compact := String(before_snapshot.get("end_turn_forecast_compact", ""))
	var frontier_indicator := String(before_snapshot.get("chrome", {}).get("frontier_indicator", ""))
	if not _assert_text_contains_all(
		"Overworld end-turn forecast UI",
		[forecast_text, forecast_compact, frontier_indicator, String(before_snapshot.get("map_cue_tooltip_text", ""))],
		["Next day:", "income", "move resets", "Next:"]
	):
		return false
	var result: Dictionary = shell.call("validation_end_turn")
	await get_tree().process_frame
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var summary := String(result.get("enemy_activity_summary", ""))
	var resolution := String(result.get("turn_resolution_summary", snapshot.get("turn_resolution_summary", "")))
	var visible_text := String(result.get("event_visible_text", snapshot.get("event_visible_text", "")))
	var tooltip_text := String(result.get("event_tooltip_text", snapshot.get("event_tooltip_text", "")))
	var event_feed: Dictionary = result.get("event_feed", snapshot.get("event_feed", {}))
	if summary == "":
		push_error("Overworld smoke: enemy turn did not produce a recent enemy activity summary. result=%s" % result)
		get_tree().quit(1)
		return false
	if resolution.find("income") < 0 or resolution.find("Move") < 0 or resolution.find("enemy") < 0:
		push_error("Overworld smoke: end-turn resolution did not summarize income, movement reset, and enemy activity. resolution=%s result=%s" % [resolution, result])
		get_tree().quit(1)
		return false
	if visible_text.find("Turn:") < 0 or tooltip_text.find("Daybreak result:") < 0 or tooltip_text.find("Recent enemy activity:") < 0 or tooltip_text.find(summary) < 0:
		push_error("Overworld smoke: end-turn result did not surface through the compact overworld event rail. summary=%s visible=%s tooltip=%s" % [summary, visible_text, tooltip_text])
		get_tree().quit(1)
		return false
	if not _assert_text_contains_all(
		"Overworld field feed consequence recap",
		[
			tooltip_text,
			String(event_feed.get("happened", "")),
			String(event_feed.get("why_it_matters", "")),
			String(event_feed.get("affected", "")),
			String(event_feed.get("next_step", "")),
		],
		["Field Feed", "Happened:", "Affected:", "Why it matters:", "Next:", "routes", "Push toward"]
	):
		return false
	var first_enemy_cue := summary.split("|", false)[0].strip_edges()
	if first_enemy_cue.ends_with("."):
		first_enemy_cue = first_enemy_cue.left(first_enemy_cue.length() - 1)
	if not _assert_action_feedback("end-turn feedback cue", snapshot, "turn", ["Turn:", "income", "Move", first_enemy_cue]):
		return false
	if not _assert_no_ai_score_leak("enemy activity summary", summary):
		return false
	if not _assert_no_ai_score_leak("enemy activity rail", "%s\n%s" % [visible_text, tooltip_text]):
		return false
	return true

func _assert_no_ai_score_leak(label: String, text: String) -> bool:
	for token in ["base_value", "persistent_income_value", "final_priority", "assignment_penalty", "route_pressure_value", "denial_value", "debug_reason", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score"]:
		if text.find(token) >= 0:
			push_error("%s leaked AI score/debug token %s: %s" % [label, token, text])
			get_tree().quit(1)
			return false
	return true

func _assert_text_contains_all(label: String, texts: Array, needles: Array) -> bool:
	var joined := "\n".join(texts)
	for needle in needles:
		if joined.find(String(needle)) < 0:
			push_error("%s missing '%s'. text=%s" % [label, String(needle), joined])
			get_tree().quit(1)
			return false
	return true

func _assert_action_feedback(label: String, snapshot: Dictionary, expected_kind: String, needles: Array) -> bool:
	var feedback: Dictionary = snapshot.get("action_feedback", {})
	var cue_text := String(feedback.get("cue_chip_text", snapshot.get("action_feedback_text", "")))
	var full_text := String(feedback.get("full_text", feedback.get("text", "")))
	if not bool(feedback.get("active", false)) or String(feedback.get("kind", "")) != expected_kind:
		push_error("Overworld smoke: %s did not expose the expected feedback kind. feedback=%s snapshot=%s" % [label, feedback, snapshot])
		get_tree().quit(1)
		return false
	if cue_text == "" or full_text == "":
		push_error("Overworld smoke: %s did not expose validation-friendly cue text. feedback=%s" % [label, feedback])
		get_tree().quit(1)
		return false
	if cue_text != String(snapshot.get("chrome", {}).get("map_cue_text", cue_text)):
		push_error("Overworld smoke: %s cue chip text drifted from the chrome snapshot. feedback=%s chrome=%s" % [label, feedback, snapshot.get("chrome", {})])
		get_tree().quit(1)
		return false
	for needle in needles:
		if full_text.find(String(needle)) < 0 and cue_text.find(String(needle)) < 0:
			push_error("Overworld smoke: %s missing '%s'. feedback=%s" % [label, String(needle), feedback])
			get_tree().quit(1)
			return false
	return true

func _assert_post_action_recap(label: String, snapshot: Dictionary, expected_kind: String, needles: Array) -> bool:
	var recap: Dictionary = snapshot.get("post_action_recap", {})
	var feedback: Dictionary = snapshot.get("action_feedback", {})
	var event_feed: Dictionary = snapshot.get("event_feed", {})
	if recap.is_empty() and feedback.get("post_action_recap", {}) is Dictionary:
		recap = feedback.get("post_action_recap", {})
	if recap.is_empty():
		push_error("Overworld smoke: %s did not expose a post-action recap. snapshot=%s" % [label, snapshot])
		get_tree().quit(1)
		return false
	if expected_kind != "" and String(recap.get("kind", "")) != expected_kind:
		push_error("Overworld smoke: %s exposed wrong recap kind. expected=%s recap=%s" % [label, expected_kind, recap])
		get_tree().quit(1)
		return false
	var joined := "\n".join(
		[
			String(recap.get("happened", "")),
			String(recap.get("affected", "")),
			String(recap.get("why_it_matters", "")),
			String(recap.get("next_step", "")),
			String(recap.get("tooltip_text", "")),
			String(feedback.get("full_text", "")),
			String(event_feed.get("happened", "")),
			String(event_feed.get("affected", "")),
			String(event_feed.get("why_it_matters", "")),
			String(event_feed.get("next_step", "")),
			String(snapshot.get("event_tooltip_text", "")),
		]
	)
	for needle in needles:
		if joined.find(String(needle)) < 0:
			push_error("Overworld smoke: %s missing '%s'. recap=%s feedback=%s event_feed=%s" % [label, String(needle), recap, feedback, event_feed])
			get_tree().quit(1)
			return false
	if not _assert_no_ai_score_leak(label, joined):
		return false
	return true

func _validation_action_by_id(actions: Variant, action_id: String) -> Dictionary:
	if not (actions is Array):
		return {}
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if String(action.get("id", "")) == action_id:
			return action
	return {}

func _assert_small_map_fit(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Overworld smoke: shell validation snapshot is missing.")
		get_tree().quit(1)
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var viewport_metrics: Dictionary = snapshot.get("map_viewport", {})
	if viewport_metrics.is_empty():
		push_error("Overworld smoke: map viewport metrics are missing from validation snapshot.")
		get_tree().quit(1)
		return false
	if not bool(viewport_metrics.get("full_map_visible", false)):
		push_error("Overworld smoke: River Pass should still fit inside the overworld viewport. metrics=%s" % viewport_metrics)
		get_tree().quit(1)
		return false
	if not bool(viewport_metrics.get("fit_entire_map", false)):
		push_error("Overworld smoke: small-map fit mode is not active for River Pass. metrics=%s" % viewport_metrics)
		get_tree().quit(1)
		return false
	var map_size: Dictionary = viewport_metrics.get("map_size", {})
	if int(map_size.get("x", 0)) > 12 or int(map_size.get("y", 0)) > 12:
		push_error("Overworld smoke: small-map fit assertion was run against a non-small map. metrics=%s" % viewport_metrics)
		get_tree().quit(1)
		return false
	return true

func _assert_remembered_owned_town_remote_entry(shell: Node) -> bool:
	var tree := get_tree()
	if not shell.has_method("validation_select_tile") or not shell.has_method("validation_perform_primary_action"):
		push_error("Overworld smoke: shell is missing remote-town validation hooks.")
		get_tree().quit(1)
		return false
	var session = SessionState.ensure_active_session()
	var town := _first_player_town(session)
	if town.is_empty():
		push_error("Overworld smoke: River Pass did not seed an owned town for remote-entry validation.")
		get_tree().quit(1)
		return false
	var town_tile := Vector2i(int(town.get("x", 0)), int(town.get("y", 0)))
	var remote_tile := _remote_memory_tile_for_town(session, town_tile)
	if remote_tile.x < 0:
		push_error("Overworld smoke: could not find a remote hero tile outside the owned town scout ring.")
		get_tree().quit(1)
		return false
	_set_active_hero_position(session, remote_tile)
	OverworldRules.refresh_fog_of_war(session)
	if not OverworldRules.is_tile_explored(session, town_tile.x, town_tile.y):
		push_error("Overworld smoke: the previously scouted owned town was not preserved as explored memory.")
		get_tree().quit(1)
		return false
	if OverworldRules.is_tile_visible(session, town_tile.x, town_tile.y):
		push_error("Overworld smoke: remote-entry setup failed; owned town is still in the current scout net.")
		get_tree().quit(1)
		return false
	var selection: Dictionary = shell.call("validation_select_tile", town_tile.x, town_tile.y)
	if String(selection.get("primary_action_id", "")) != "visit_town":
		push_error("Overworld smoke: remembered owned town did not expose Visit Town as the primary order. snapshot=%s" % selection)
		get_tree().quit(1)
		return false
	if String(selection.get("context_summary", "")).find("Remembered Town") < 0:
		push_error("Overworld smoke: remembered owned town selection did not present a remembered-town context. snapshot=%s" % selection)
		get_tree().quit(1)
		return false
	var presentation: Dictionary = shell.call("validation_tile_presentation", town_tile.x, town_tile.y)
	if not bool(presentation.get("draws_remembered_object", false)):
		push_error("Overworld smoke: remembered owned town would not draw a remembered object marker. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if not _assert_explored_terrain_presentation(shell, town_tile, presentation):
		return false
	if not _assert_marker_style(presentation, "town", true):
		return false
	var remembered_timber_presentation: Dictionary = shell.call("validation_tile_presentation", 1, 0)
	if bool(remembered_timber_presentation.get("visible", true)) or not _assert_art_sprite(remembered_timber_presentation, "lumber_wagon", true):
		push_error("Overworld smoke: remembered mapped pickup did not keep a ghosted sprite treatment. presentation=%s" % remembered_timber_presentation)
		get_tree().quit(1)
		return false
	var visit_result: Dictionary = shell.call("validation_perform_primary_action")
	if String(session.game_state) != "town" or not bool(visit_result.get("ok", false)):
		push_error("Overworld smoke: remembered owned town primary action did not route into town management. result=%s state=%s" % [visit_result, session.game_state])
		get_tree().quit(1)
		return false
	var active_town := TownRules.get_active_town(session)
	if String(active_town.get("placement_id", "")) != String(town.get("placement_id", "")):
		push_error("Overworld smoke: remote town route activated the wrong town. active=%s expected=%s" % [active_town, town])
		get_tree().quit(1)
		return false
	tree.quit(0)
	return true

func _assert_explored_terrain_presentation(shell: Node, remembered_tile: Vector2i, remembered_presentation: Dictionary) -> bool:
	var terrain_presentation: Dictionary = remembered_presentation.get("terrain_presentation", {})
	if not bool(remembered_presentation.get("explored", false)) or bool(remembered_presentation.get("visible", true)):
		push_error("Overworld smoke: terrain-memory assertion was not run against an explored tile outside the scout net. presentation=%s" % remembered_presentation)
		get_tree().quit(1)
		return false
	if not bool(terrain_presentation.get("terrain_fully_visible", false)):
		push_error("Overworld smoke: explored terrain outside the scout net is not staying fully visible at %s. presentation=%s" % [remembered_tile, remembered_presentation])
		get_tree().quit(1)
		return false
	if bool(terrain_presentation.get("uses_memory_terrain_dimming", true)) or float(terrain_presentation.get("memory_overlay_alpha", 1.0)) > 0.01:
		push_error("Overworld smoke: explored terrain outside the scout net is still using memory dimming at %s. presentation=%s" % [remembered_tile, remembered_presentation])
		get_tree().quit(1)
		return false
	if String(terrain_presentation.get("pattern_detail", "")) != "full":
		push_error("Overworld smoke: explored terrain outside the scout net lost full terrain detail at %s. presentation=%s" % [remembered_tile, remembered_presentation])
		get_tree().quit(1)
		return false
	if String(terrain_presentation.get("visible_terrain_grid_mode", "")) != "fog_boundary_only" or float(terrain_presentation.get("visible_terrain_grid_alpha", 1.0)) > 0.01 or bool(terrain_presentation.get("explored_intertile_seams", true)):
		push_error("Overworld smoke: explored terrain still reports a visible per-tile grid/seam treatment at %s. presentation=%s" % [remembered_tile, remembered_presentation])
		get_tree().quit(1)
		return false

	var session = SessionState.ensure_active_session()
	var unexplored_tile := _first_unexplored_tile(session)
	if unexplored_tile.x < 0:
		push_error("Overworld smoke: could not find an unexplored tile to guard hidden fog presentation.")
		get_tree().quit(1)
		return false
	var unexplored_presentation: Dictionary = shell.call("validation_tile_presentation", unexplored_tile.x, unexplored_tile.y)
	var unexplored_terrain: Dictionary = unexplored_presentation.get("terrain_presentation", {})
	if bool(unexplored_presentation.get("explored", true)) or not bool(unexplored_terrain.get("unexplored_hidden", false)):
		push_error("Overworld smoke: unscouted terrain is not staying hidden at %s. presentation=%s" % [unexplored_tile, unexplored_presentation])
		get_tree().quit(1)
		return false
	if bool(unexplored_terrain.get("terrain_fully_visible", true)):
		push_error("Overworld smoke: unscouted terrain became fully visible instead of remaining hidden at %s. presentation=%s" % [unexplored_tile, unexplored_presentation])
		get_tree().quit(1)
		return false
	if not bool(unexplored_terrain.get("unexplored_wireframe", false)) or float(unexplored_terrain.get("unexplored_wireframe_alpha", 0.0)) < 0.30:
		push_error("Overworld smoke: unexplored terrain lost its necessary hidden-ground wireframe treatment at %s. presentation=%s" % [unexplored_tile, unexplored_presentation])
		get_tree().quit(1)
		return false
	return true

func _assert_marker_readability_contract(shell: Node) -> bool:
	if not shell.has_method("validation_tile_presentation"):
		push_error("Overworld smoke: shell is missing marker-presentation validation hooks.")
		get_tree().quit(1)
		return false
	var session = SessionState.ensure_active_session()
	var marker_specs := [
		{"kind": "town", "tile": _first_visible_town_tile(session)},
		{"kind": "resource", "tile": _first_visible_resource_tile(session)},
		{"kind": "artifact", "tile": _first_visible_artifact_tile(session)},
		{"kind": "encounter", "tile": _first_visible_encounter_tile(session)},
	]
	for spec in marker_specs:
		var kind := String(spec.get("kind", ""))
		var tile: Vector2i = spec.get("tile", Vector2i(-1, -1))
		if tile.x < 0:
			push_error("Overworld smoke: could not find a visible %s marker candidate." % kind)
			get_tree().quit(1)
			return false
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		if not _assert_marker_style(presentation, kind, false):
			return false
		if kind == "town" and not _assert_town_non_entry_footprint(shell, presentation):
			return false

	var hero_tile := OverworldRules.hero_position(session)
	var hero_presentation: Dictionary = shell.call("validation_tile_presentation", hero_tile.x, hero_tile.y)
	var hero_readability: Dictionary = hero_presentation.get("marker_readability", {})
	if not bool(hero_presentation.get("has_visible_hero", false)) or not bool(hero_readability.get("hero_emphasis", false)):
		push_error("Overworld smoke: active hero marker is not emphasized. presentation=%s" % hero_presentation)
		get_tree().quit(1)
		return false
	if float(hero_readability.get("hero_symbol_extent_fraction", 0.0)) < 0.33:
		push_error("Overworld smoke: active hero symbol is too small to read against terrain. presentation=%s" % hero_presentation)
		get_tree().quit(1)
		return false
	if not bool(hero_readability.get("selection_emphasis", false)) or float(hero_readability.get("focus_ring_width_px", 0.0)) < 3.0:
		push_error("Overworld smoke: current selection focus is not readable on the map. presentation=%s" % hero_presentation)
		get_tree().quit(1)
		return false
	if not _assert_hero_presence_correction(hero_readability, hero_presentation):
		return false
	var hero_object_kinds: Array = hero_readability.get("object_kinds", [])
	if "town" in hero_object_kinds:
		if not _assert_town_grounding_correction(hero_readability, hero_presentation):
			return false
	return true

func _assert_marker_style(presentation: Dictionary, expected_kind: String, remembered: bool) -> bool:
	var readability: Dictionary = presentation.get("marker_readability", {})
	var object_kinds: Array = readability.get("object_kinds", [])
	var is_town := expected_kind == "town"
	var uses_procedural_fallback := bool(readability.get("procedural_world_silhouette", false))
	var art: Dictionary = presentation.get("art_presentation", {})
	var uses_mapped_sprite := bool(art.get("uses_asset_sprite", false)) and not is_town
	if expected_kind not in object_kinds:
		push_error("Overworld smoke: expected %s marker kind was missing. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if not bool(readability.get("ground_anchor", false)):
		push_error("Overworld smoke: %s marker lacks terrain-grounded placement metadata. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if String(readability.get("presence_model", "")) != "footprint_scaled_world_object":
		push_error("Overworld smoke: %s marker no longer reports object-first footprint presence. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	var expected_occlusion := "town_sprite_settled_without_base_ellipse" if is_town else ("ground_contact_without_foreground_lip" if uses_procedural_fallback else ("sprite_contact_without_foreground_lip" if uses_mapped_sprite else ""))
	if String(readability.get("occlusion_model", "")) != expected_occlusion:
		push_error("Overworld smoke: %s marker no longer reports the expected foreground contact model. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if is_town:
		if not _assert_town_grounding_correction(readability, presentation):
			return false
	elif uses_procedural_fallback:
		if not _assert_procedural_fallback_grounding(readability, expected_kind, presentation):
			return false
	elif uses_mapped_sprite:
		if not _assert_mapped_sprite_grounding(readability, expected_kind, presentation):
			return false
	elif String(readability.get("anchor_shape", "")) != "terrain_ellipse_footprint":
		push_error("Overworld smoke: %s marker lacks the terrain-grounded anchor needed to read against the map. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	else:
		push_error("Overworld smoke: %s marker used an unsupported non-town/non-procedural/non-mapped grounding path. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if int(readability.get("footprint_width_tiles", 0)) <= 0 or int(readability.get("footprint_height_tiles", 0)) <= 0:
		push_error("Overworld smoke: %s marker does not expose authored/default footprint dimensions. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if expected_kind == "town":
		if int(readability.get("footprint_width_tiles", 0)) != 3 or int(readability.get("footprint_height_tiles", 0)) != 2:
			push_error("Overworld smoke: town marker must present as a 3x2 footprint. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
		var town_presentation: Dictionary = presentation.get("town_presentation", {})
		if not bool(town_presentation.get("has_town_footprint", false)) or String(town_presentation.get("presentation_model", "")) != "town_3x2_footprint_bottom_middle_entry":
			push_error("Overworld smoke: town presentation metadata does not expose the 3x2 model. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
		if String(town_presentation.get("entry_role", "")) != "bottom_middle_visit_approach" or not bool(town_presentation.get("entry_is_visit_tile", false)):
			push_error("Overworld smoke: town presentation does not report the bottom-middle visit approach tile. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
		if not bool(town_presentation.get("is_entry_tile", false)) or String(town_presentation.get("tile_role", "")) != "bottom_middle_visit_approach":
			push_error("Overworld smoke: selected town tile is not reported as the entry approach. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
		if not bool(town_presentation.get("non_entry_tiles_blocked", false)) or bool(town_presentation.get("visible_helper_cues", true)) or bool(town_presentation.get("footprint_helper_glyphs", true)) or bool(town_presentation.get("entry_apron_cue", true)) or bool(town_presentation.get("entry_wedge_cue", true)) or bool(town_presentation.get("gate_cue", true)) or bool(town_presentation.get("helper_circle_cue", true)):
			push_error("Overworld smoke: town presentation must preserve blocked non-entry metadata without visible helper apron/gate/glyph cues. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
	var min_anchor_width := 0.36 if uses_mapped_sprite else (0.40 if uses_procedural_fallback else 0.60)
	var min_anchor_height := 0.06 if uses_mapped_sprite else (0.12 if uses_procedural_fallback else 0.20)
	if float(readability.get("footprint_anchor_width_fraction", 0.0)) < min_anchor_width or float(readability.get("footprint_anchor_height_fraction", 0.0)) < min_anchor_height:
		push_error("Overworld smoke: %s footprint anchor is too small to read as placed ground contact. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if bool(readability.get("ui_badge_plate", true)):
		push_error("Overworld smoke: %s marker regressed to a UI badge plate instead of a terrain footprint. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if float(readability.get("min_symbol_extent_fraction", 0.0)) < 0.33:
		push_error("Overworld smoke: %s marker symbol is too small for at-a-glance readability. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if remembered:
		if is_town:
			if bool(readability.get("memory_echo", false)) or String(readability.get("town_remembered_treatment", "")) != "ghosted_sprite_without_echo_plate":
				push_error("Overworld smoke: remembered town should use ghosted sprite treatment without the removed echo plate. presentation=%s" % presentation)
				get_tree().quit(1)
				return false
		elif not bool(readability.get("memory_echo", false)):
			push_error("Overworld smoke: remembered %s marker lacks a distinguishable memory treatment. presentation=%s" % [expected_kind, presentation])
			get_tree().quit(1)
			return false
		if float(readability.get("remembered_marker_alpha", 0.0)) < 0.80 or float(readability.get("outline_alpha", 0.0)) < 0.70:
			push_error("Overworld smoke: remembered %s marker is still too faint. presentation=%s" % [expected_kind, presentation])
			get_tree().quit(1)
			return false
	else:
		if bool(readability.get("memory_echo", false)):
			push_error("Overworld smoke: visible %s marker was styled like a remembered marker. presentation=%s" % [expected_kind, presentation])
			get_tree().quit(1)
			return false
		var visible_grid_suppressed := String(readability.get("visible_terrain_grid_mode", "")) == "fog_boundary_only" and float(readability.get("grid_alpha", 1.0)) <= 0.08 and not bool(readability.get("explored_intertile_seams", true))
		var anchor_floor := 0.12 if uses_mapped_sprite else (0.16 if uses_procedural_fallback else 0.30)
		if not is_town and (float(readability.get("anchor_alpha", 0.0)) < anchor_floor or float(readability.get("outline_alpha", 0.0)) < 0.85 or not visible_grid_suppressed):
			push_error("Overworld smoke: visible %s marker grounding or map contrast regressed. presentation=%s" % [expected_kind, presentation])
			get_tree().quit(1)
			return false
	return true

func _assert_procedural_fallback_grounding(readability: Dictionary, expected_kind: String, presentation: Dictionary) -> bool:
	if String(readability.get("anchor_shape", "")) != "family_terrain_contact_scuffs":
		push_error("Overworld smoke: procedural %s fallback still reports the old terrain-ellipse marker anchor. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if not bool(readability.get("procedural_fallback_grounding", false)) or String(readability.get("procedural_grounding_model", "")) != "family_specific_contact_scuffs_no_marker_plate":
		push_error("Overworld smoke: procedural %s fallback does not expose the family-specific contact-scuff grounding model. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if bool(readability.get("contrast_plate", true)) or bool(readability.get("shared_marker_plate", true)) or float(readability.get("plate_alpha", 1.0)) > 0.01 or float(readability.get("ring_alpha", 1.0)) > 0.01:
		push_error("Overworld smoke: procedural %s fallback still exposes the shared marker plate or ring. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if bool(readability.get("terrain_quieting_bed", true)) or String(readability.get("placement_bed_model", "")) != "" or float(readability.get("placement_bed_alpha", 1.0)) > 0.01:
		push_error("Overworld smoke: procedural %s fallback still reports the broad terrain quieting bed. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if not bool(readability.get("procedural_contact_disturbance", false)) or String(readability.get("procedural_contact_disturbance_model", "")) != "thin_terrain_contact_disturbance":
		push_error("Overworld smoke: procedural %s fallback lacks the thin terrain contact disturbance. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if float(readability.get("procedural_contact_disturbance_alpha", 0.0)) < 0.16 or float(readability.get("procedural_contact_disturbance_alpha", 1.0)) > 0.24:
		push_error("Overworld smoke: procedural %s fallback contact disturbance alpha is outside the grounded-object range. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if bool(readability.get("upper_mass_backdrop", true)) or String(readability.get("upper_mass_backdrop_model", "")) != "" or bool(readability.get("vertical_mass_shadow", true)):
		push_error("Overworld smoke: procedural %s fallback still reports upper-mass backdrop/shadow support. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if bool(readability.get("foreground_occlusion_lip", true)) or not bool(readability.get("procedural_contact_marks", false)):
		push_error("Overworld smoke: procedural %s fallback still reports the foreground lip instead of contact marks. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if String(readability.get("depth_cue_model", "")) != "localized_contact_shadow_without_backdrop":
		push_error("Overworld smoke: procedural %s fallback does not report localized contact-shadow depth. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if bool(readability.get("directional_contact_shadow", true)) or not bool(readability.get("localized_contact_shadow", false)) or String(readability.get("contact_shadow_model", "")) != "localized_object_contact_shadow":
		push_error("Overworld smoke: procedural %s fallback still reports the shared directional cast shadow. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	if float(readability.get("contact_shadow_alpha", 0.0)) < 0.24 or bool(readability.get("base_occlusion_pads", true)) or float(readability.get("base_occlusion_alpha", 1.0)) > 0.01:
		push_error("Overworld smoke: procedural %s fallback lacks localized contact shadow or still reports base occlusion pads. presentation=%s" % [expected_kind, presentation])
		get_tree().quit(1)
		return false
	return true

func _assert_town_grounding_correction(readability: Dictionary, presentation: Dictionary) -> bool:
	if String(readability.get("anchor_shape", "")) != "town_contact_cues_no_base_ellipse":
		push_error("Overworld smoke: town still reports a base ellipse anchor instead of quiet contact cues. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if bool(readability.get("terrain_quieting_bed", true)) or String(readability.get("placement_bed_model", "")) != "" or float(readability.get("placement_bed_alpha", 1.0)) > 0.01:
		push_error("Overworld smoke: town still reports a filled terrain underlay/quieting bed. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if bool(readability.get("upper_mass_backdrop", true)) or bool(readability.get("vertical_mass_shadow", true)):
		push_error("Overworld smoke: town still reports upper-mass shadow/backdrop treatment. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if String(readability.get("depth_cue_model", "")) != "town_contact_line_without_cast_shadow" or bool(readability.get("directional_contact_shadow", true)) or float(readability.get("contact_shadow_alpha", 1.0)) > 0.01:
		push_error("Overworld smoke: town still reports directional cast-shadow depth cues. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if bool(readability.get("base_occlusion_pads", true)) or float(readability.get("base_occlusion_alpha", 1.0)) > 0.01:
		push_error("Overworld smoke: town still reports foreground base occlusion pads. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if String(readability.get("town_grounding_model", "")) != "town_sprite_settled_without_base_ellipse" or String(readability.get("town_footprint_cue_model", "")) != "no_visible_helper_cues_3x2_contract":
		push_error("Overworld smoke: town grounding metadata does not describe the no-ellipse presentation. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if bool(readability.get("town_base_ellipse", true)) or bool(readability.get("town_underlay", true)) or bool(readability.get("town_cast_shadow", true)) or not bool(readability.get("town_contact_cue", false)):
		push_error("Overworld smoke: town grounding flags did not remove base ellipse/underlay/cast shadow while preserving contact cues. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	var town_presentation: Dictionary = presentation.get("town_presentation", {})
	if bool(town_presentation.get("base_ellipse", true)) or bool(town_presentation.get("filled_underlay", true)) or bool(town_presentation.get("cast_shadow", true)):
		push_error("Overworld smoke: town presentation payload still exposes the removed ellipse/underlay/shadow treatment. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if String(town_presentation.get("footprint_cue_model", "")) != "no_visible_helper_cues_3x2_contract":
		push_error("Overworld smoke: town footprint cue metadata does not describe the cue-free 3x2 contract. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if bool(town_presentation.get("visible_helper_cues", true)) or bool(town_presentation.get("footprint_helper_glyphs", true)) or bool(town_presentation.get("entry_apron_cue", true)) or bool(town_presentation.get("entry_wedge_cue", true)) or bool(town_presentation.get("gate_cue", true)) or bool(town_presentation.get("helper_circle_cue", true)):
		push_error("Overworld smoke: town presentation payload still exposes visible helper footprint/entry cues. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	return true

func _assert_hero_presence_correction(readability: Dictionary, presentation: Dictionary) -> bool:
	if String(readability.get("hero_presence_model", "")) != "placed_world_hero_figure":
		push_error("Overworld smoke: active hero does not report the placed world-figure presence model. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if String(readability.get("hero_anchor_shape", "")) != "hero_foot_contact_shadow" or String(readability.get("hero_grounding_model", "")) != "hero_foot_contact_without_base_ellipse":
		push_error("Overworld smoke: active hero still lacks the hero-specific foot-contact grounding model. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if String(readability.get("hero_depth_cue_model", "")) != "hero_foot_contact_shadow_with_boot_occlusion":
		push_error("Overworld smoke: active hero does not report boot-level depth/occlusion contact. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if bool(readability.get("hero_badge_plate", true)) or bool(readability.get("hero_base_ellipse", true)) or bool(readability.get("hero_terrain_quieting_bed", true)) or bool(readability.get("hero_upper_mass_backdrop", true)) or bool(readability.get("hero_shared_marker_plate", true)):
		push_error("Overworld smoke: active hero regressed toward the staged badge/ellipse support. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if not bool(readability.get("hero_world_figure", false)) or not bool(readability.get("hero_foot_contact_shadow", false)) or not bool(readability.get("hero_boot_occlusion", false)):
		push_error("Overworld smoke: active hero lacks world-figure, foot-shadow, or boot-occlusion cues. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if float(readability.get("hero_contact_shadow_alpha", 0.0)) < 0.30 or float(readability.get("hero_boot_occlusion_alpha", 0.0)) < 0.34:
		push_error("Overworld smoke: active hero foot-contact depth cues are too faint. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if float(readability.get("hero_foot_anchor_width_fraction", 0.0)) < 0.50 or float(readability.get("hero_foot_anchor_height_fraction", 0.0)) < 0.12:
		push_error("Overworld smoke: active hero foot-contact anchor is too small to read as placed on terrain. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	if String(readability.get("hero_selection_ring_source", "")) != "tile_focus":
		push_error("Overworld smoke: active hero selection readability is no longer tied to the tile focus ring. presentation=%s" % presentation)
		get_tree().quit(1)
		return false
	return true

func _assert_town_non_entry_footprint(shell: Node, entry_presentation: Dictionary) -> bool:
	var town_presentation: Dictionary = entry_presentation.get("town_presentation", {})
	var blocked_cells: Array = town_presentation.get("blocked_footprint_cells", [])
	if blocked_cells.is_empty():
		push_error("Overworld smoke: town 3x2 footprint did not expose any blocked non-entry cells. presentation=%s" % entry_presentation)
		get_tree().quit(1)
		return false
	for cell_value in blocked_cells:
		if not (cell_value is Dictionary):
			continue
		var cell: Dictionary = cell_value
		var cell_presentation: Dictionary = shell.call("validation_tile_presentation", int(cell.get("x", -1)), int(cell.get("y", -1)))
		var cell_town: Dictionary = cell_presentation.get("town_presentation", {})
		if not bool(cell_presentation.get("has_town_non_entry", false)):
			push_error("Overworld smoke: town footprint cell does not read as a non-entry town tile. cell=%s presentation=%s" % [cell, cell_presentation])
			get_tree().quit(1)
			return false
		if bool(cell_town.get("is_visit_tile", true)) or not bool(cell_town.get("presentation_blocked", false)) or String(cell_town.get("tile_role", "")) != "blocked_non_entry_footprint":
			push_error("Overworld smoke: town non-entry footprint cell is not presentation-blocked. cell=%s presentation=%s" % [cell, cell_presentation])
			get_tree().quit(1)
			return false
		return true
	push_error("Overworld smoke: town footprint blocked-cell payload contained no usable in-bounds cells. presentation=%s" % entry_presentation)
	get_tree().quit(1)
	return false

func _assert_mapped_sprite_grounding(readability: Dictionary, label: String, presentation: Dictionary) -> bool:
	if String(readability.get("anchor_shape", "")) != "mapped_sprite_local_contact_scuffs" or not bool(readability.get("mapped_sprite_grounding", false)):
		push_error("Overworld smoke: mapped %s sprite does not report the local contact-scuff anchor. presentation=%s" % [label, presentation])
		get_tree().quit(1)
		return false
	if String(readability.get("mapped_sprite_grounding_model", "")) != "localized_sprite_contact_scuffs" or not bool(readability.get("mapped_sprite_contact_disturbance", false)):
		push_error("Overworld smoke: mapped %s sprite lacks localized contact scuffs. presentation=%s" % [label, presentation])
		get_tree().quit(1)
		return false
	if String(readability.get("mapped_sprite_contact_disturbance_model", "")) != "thin_sprite_contact_disturbance" or float(readability.get("mapped_sprite_contact_disturbance_alpha", 0.0)) < 0.12:
		push_error("Overworld smoke: mapped %s sprite contact scuffs are missing or too faint. presentation=%s" % [label, presentation])
		get_tree().quit(1)
		return false
	if bool(readability.get("terrain_quieting_bed", true)) or String(readability.get("placement_bed_model", "")) != "" or float(readability.get("placement_bed_alpha", 1.0)) > 0.01:
		push_error("Overworld smoke: mapped %s sprite still reports a broad placement bed. presentation=%s" % [label, presentation])
		get_tree().quit(1)
		return false
	if bool(readability.get("upper_mass_backdrop", true)) or String(readability.get("upper_mass_backdrop_model", "")) != "" or bool(readability.get("vertical_mass_shadow", true)):
		push_error("Overworld smoke: mapped %s sprite still reports upper-mass backdrop or vertical shadow support. presentation=%s" % [label, presentation])
		get_tree().quit(1)
		return false
	if bool(readability.get("foreground_occlusion_lip", true)) or bool(readability.get("base_occlusion_pads", true)) or bool(readability.get("shared_marker_plate", true)):
		push_error("Overworld smoke: mapped %s sprite still reports foreground lip/base pads/shared marker plate. presentation=%s" % [label, presentation])
		get_tree().quit(1)
		return false
	if not bool(readability.get("localized_contact_shadow", false)) or String(readability.get("contact_shadow_model", "")) != "localized_sprite_contact_shadow" or float(readability.get("contact_shadow_alpha", 0.0)) < 0.22:
		push_error("Overworld smoke: mapped %s sprite lacks localized contact-shadow readability. presentation=%s" % [label, presentation])
		get_tree().quit(1)
		return false
	return true

func _assert_overworld_art_contract(shell: Node) -> bool:
	if not shell.has_method("validation_tile_presentation"):
		push_error("Overworld smoke: shell is missing art-presentation validation hooks.")
		get_tree().quit(1)
		return false
	var grass_presentation: Dictionary = shell.call("validation_tile_presentation", 1, 2)
	var grass_terrain: Dictionary = grass_presentation.get("terrain_presentation", {})
	if String(grass_terrain.get("rendering_mode", "")) != "homm3_local_reference_prototype":
		push_error("Overworld smoke: HoMM3 local prototype terrain atlas is not active on the overworld map. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if bool(grass_terrain.get("uses_sampled_texture", true)) or bool(grass_terrain.get("generated_source_primary", true)) or not bool(grass_terrain.get("uses_homm3_local_prototype", false)) or not bool(grass_terrain.get("texture_loaded", false)):
		push_error("Overworld smoke: overworld terrain is not reporting the HoMM3 local prototype tile bank. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if String(grass_terrain.get("primary_base_model", "")) != "homm3_local_reference_prototype" or String(grass_terrain.get("terrain_noise_profile", "")) != "homm3_extracted_atlas_frame":
		push_error("Overworld smoke: overworld terrain does not expose the HoMM3 extracted-atlas base model. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if String(grass_terrain.get("terrain_variant_selection", "")) != "accepted_web_relation_class_row_lookup" or String(grass_terrain.get("homm3_terrain_lookup_model", "")) != "accepted_web_prototype_relation_class_row_lookup":
		push_error("Overworld smoke: grass terrain does not expose the accepted web relation-class terrain lookup contract. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if String(grass_terrain.get("homm3_interior_frame_selection", "")) != "accepted_web_full_row_bucket_selection" or bool(grass_terrain.get("homm3_uses_interior_variant_cycle", true)):
		push_error("Overworld smoke: HoMM3 terrain interior frames still report the retired patch-hash variant cycling contract. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if not bool(grass_terrain.get("homm3_local_reference_only", false)) or String(grass_terrain.get("tile_art_source_basis", "")) != "homm3_extracted_local_reference_prototype":
		push_error("Overworld smoke: HoMM3 prototype terrain did not report its local-reference source basis. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if String(grass_terrain.get("terrain_group", "")) != "grasslands" or String(grass_terrain.get("style_id", "")) == "":
		push_error("Overworld smoke: grass terrain does not expose grammar group/style metadata. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if String(grass_terrain.get("visible_terrain_grid_mode", "")) != "fog_boundary_only" or float(grass_terrain.get("visible_terrain_grid_alpha", 1.0)) > 0.01 or bool(grass_terrain.get("explored_intertile_seams", true)):
		push_error("Overworld smoke: visible grass terrain still reports per-cell black grid seams. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if not bool(grass_terrain.get("road_overlay", false)) or String(grass_terrain.get("road_overlay_id", "")) != "road_dirt" or not bool(grass_terrain.get("road_overlay_art", false)) or String(grass_terrain.get("road_shape_model", "")) != "homm3_4_neighbor_overlay_lookup":
		push_error("Overworld smoke: authored River Pass road overlay is not using HoMM3 4-neighbor road art. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if String(grass_terrain.get("road_connection_source", "")) != "orthogonal_same_type_road_tiles" or not bool(grass_terrain.get("road_same_type_adjacency", false)) or not bool(grass_terrain.get("road_orthogonal_mask_only", false)):
		push_error("Overworld smoke: River Pass road overlay is not being rebuilt from 4-neighbor same-type road adjacency. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if bool(grass_terrain.get("road_horizontal_edge_riding", true)) or bool(grass_terrain.get("road_diagonal_connections", true)) or String(grass_terrain.get("road_piece_selection_model", "")) != "homm3_4_neighbor_mask_lookup":
		push_error("Overworld smoke: River Pass road still reports old lane or diagonal-road topology. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false
	if String(grass_terrain.get("road_joint_cap_model", "")) != "connection_aware_joint_cap" or not bool(grass_terrain.get("road_joint_cap", false)):
		push_error("Overworld smoke: River Pass road intersection does not expose the connection-aware joint cap contract. presentation=%s" % grass_presentation)
		get_tree().quit(1)
		return false

	var forest_edge_presentation: Dictionary = shell.call("validation_tile_presentation", 1, 1)
	var forest_edge_terrain: Dictionary = forest_edge_presentation.get("terrain_presentation", {})
	if (
		String(forest_edge_terrain.get("terrain_group", "")) != "forest"
		or not bool(forest_edge_terrain.get("neighbor_aware_transitions", false))
		or String(forest_edge_terrain.get("transition_calculation_model", "")) != "accepted_web_prototype_relation_class_row_lookup"
		or String(forest_edge_terrain.get("homm3_terrain_family", "")) != "grass"
		or String(forest_edge_terrain.get("homm3_logical_degrade_note", "")) == ""
		or String(forest_edge_terrain.get("transition_shape_model", "")) != "homm3_base_atlas_frame"
	):
		push_error("Overworld smoke: logical forest terrain did not report its explicit HoMM3 grass-atlas prototype degradation. presentation=%s" % forest_edge_presentation)
		get_tree().quit(1)
		return false
	var session = SessionState.ensure_active_session()
	if not _assert_bridge_material_resolver_payloads(shell, session):
		return false
	if not _assert_solid_region_interior_stability(shell, session):
		return false
	var town_tile := _first_visible_town_tile(session)
	if town_tile.x < 0:
		push_error("Overworld smoke: could not find a visible town for default town sprite validation.")
		get_tree().quit(1)
		return false
	var town_presentation: Dictionary = shell.call("validation_tile_presentation", town_tile.x, town_tile.y)
	if not _assert_art_sprite(town_presentation, "frontier_town", false):
		return false
	var encounter_tile := _first_visible_encounter_tile(session)
	if encounter_tile.x < 0:
		push_error("Overworld smoke: could not find a visible encounter for default encounter sprite validation.")
		get_tree().quit(1)
		return false
	var encounter_presentation: Dictionary = shell.call("validation_tile_presentation", encounter_tile.x, encounter_tile.y)
	if not _assert_art_sprite(encounter_presentation, "hostile_camp", false):
		return false
	var timber_presentation: Dictionary = shell.call("validation_tile_presentation", 1, 0)
	if not _assert_art_sprite(timber_presentation, "lumber_wagon", false):
		return false
	var artifact_presentation: Dictionary = shell.call("validation_tile_presentation", 2, 0)
	if not _assert_art_sprite(artifact_presentation, "adventurers_bundle", false):
		return false
	var fallback_presentation: Dictionary = shell.call("validation_tile_presentation", 2, 3)
	var fallback_art: Dictionary = fallback_presentation.get("art_presentation", {})
	if bool(fallback_art.get("uses_asset_sprite", true)) or not bool(fallback_art.get("fallback_procedural_marker", false)):
		push_error("Overworld smoke: unmapped faction outpost did not preserve procedural marker fallback. presentation=%s" % fallback_presentation)
		get_tree().quit(1)
		return false
	if String(fallback_art.get("fallback_silhouette_model", "")) != "family_specific_procedural_world_object":
		push_error("Overworld smoke: procedural fallback object did not report the family-specific world silhouette model. presentation=%s" % fallback_presentation)
		get_tree().quit(1)
		return false
	if String(fallback_art.get("fallback_grounding_model", "")) != "family_specific_contact_scuffs_no_marker_plate" or bool(fallback_art.get("fallback_shared_marker_plate", true)) or bool(fallback_art.get("fallback_upper_mass_backdrop", true)) or bool(fallback_art.get("fallback_foreground_lip", true)):
		push_error("Overworld smoke: procedural fallback object did not report the no-plate/no-backdrop/no-lip grounding correction. presentation=%s" % fallback_presentation)
		get_tree().quit(1)
		return false
	if String(fallback_art.get("fallback_contact_shadow_model", "")) != "localized_object_contact_shadow":
		push_error("Overworld smoke: procedural fallback object did not report localized contact shadow grounding. presentation=%s" % fallback_presentation)
		get_tree().quit(1)
		return false
	return true

func _assert_bridge_material_resolver_payloads(shell: Node, session) -> bool:
	var original_map = session.overworld.get("map", []).duplicate(true)
	var original_fog = session.overworld.get("fog", {}).duplicate(true)
	var map_size := OverworldRules.derive_map_size(session)
	if map_size.x < 9 or map_size.y < 5:
		push_error("Overworld smoke: bridge resolver fixture requires at least a 9x5 map, got %s." % map_size)
		get_tree().quit(1)
		return false
	var working_map := []
	for y in range(map_size.y):
		var row := []
		for x in range(map_size.x):
			row.append("grass")
		working_map.append(row)
	var paint_plan := [
		{"tile": Vector2i(2, 1), "terrain": "badlands"},
		{"tile": Vector2i(4, 1), "terrain": "badlands"},
		{"tile": Vector2i(4, 0), "terrain": "badlands"},
		{"tile": Vector2i(4, 2), "terrain": "badlands"},
		{"tile": Vector2i(3, 1), "terrain": "badlands"},
		{"tile": Vector2i(5, 1), "terrain": "wastes"},
		{"tile": Vector2i(2, 3), "terrain": "swamp"},
		{"tile": Vector2i(7, 3), "terrain": "snow"},
		{"tile": Vector2i(7, 1), "terrain": "cavern"},
		{"tile": Vector2i(7, 0), "terrain": "cavern"},
		{"tile": Vector2i(7, 2), "terrain": "cavern"},
		{"tile": Vector2i(6, 1), "terrain": "cavern"},
		{"tile": Vector2i(8, 1), "terrain": "grass"},
	]
	for entry in paint_plan:
		var tile: Vector2i = entry.get("tile", Vector2i.ZERO)
		working_map[tile.y][tile.x] = String(entry.get("terrain", "grass"))
	session.overworld["map"] = working_map
	var controlled_tiles := []
	for y in range(map_size.y):
		for x in range(map_size.x):
			controlled_tiles.append(Vector2i(x, y))
	_reveal_validation_tiles(session, controlled_tiles)
	shell.call("_refresh")
	var cases := [
		{
			"tile": Vector2i(1, 1),
			"source": "badlands",
			"kind": "direct_bridge_material",
			"rule": "full_receiver_direct_dirt_contact",
			"class": "dirt_earth_bridge",
			"family": "dirt",
			"block": "native_to_dirt_transition",
			"source_level": "fact",
			"model": "direct_bridge_material_contact_lookup",
			"stamp": {"table": "full_receiver_native_to_dirt_5x4_provisional_stamp_table", "direction": "E", "frame": "00_15", "offset": {"x": 1, "y": 0}, "bridge_family": "dirt", "target_block": "native_to_dirt_transition", "source_kind": "cardinal_source"},
		},
		{
			"tile": Vector2i(4, 1),
			"source": "wastes",
			"kind": "direct_bridge_material",
			"rule": "dirt_receiver_direct_sand_contact",
			"class": "sand_bridge",
			"family": "sand",
			"block": "dirt_to_sand_transition",
			"source_level": "fact",
			"model": "direct_dirt_sand_receiver_lookup",
		},
		{
			"tile": Vector2i(1, 3),
			"source": "swamp",
			"kind": "routed_bridge",
			"rule": "grass_swamp_via_dirt_bridge",
			"class": "dirt_earth_bridge",
			"family": "dirt",
			"block": "native_to_dirt_transition",
			"source_level": "inference",
			"model": "grass_swamp_via_dirt_bridge",
			"stamp": {"table": "full_receiver_native_to_dirt_5x4_provisional_stamp_table", "direction": "E", "frame": "00_15", "offset": {"x": 1, "y": 0}, "bridge_family": "dirt", "target_block": "native_to_dirt_transition", "source_kind": "cardinal_source"},
		},
		{
			"tile": Vector2i(6, 3),
			"source": "snow",
			"kind": "preferred_bridge_class",
			"rule": "full_receiver_prefers_dirt_bridge_class",
			"class": "dirt_earth_bridge",
			"family": "dirt",
			"block": "native_to_dirt_transition",
			"source_level": "editor_observation",
			"model": "receiver_preferred_bridge_class_lookup",
			"stamp": {"table": "full_receiver_native_to_dirt_5x4_provisional_stamp_table", "direction": "E", "frame": "00_15", "offset": {"x": 1, "y": 0}, "bridge_family": "dirt", "target_block": "native_to_dirt_transition", "source_kind": "cardinal_source", "mixed_reserved": true},
		},
		{
			"tile": Vector2i(7, 1),
			"source": "grass",
			"kind": "unresolved_fallback",
			"rule": "subterranean_preferred_bridge_class_provisional",
			"class": "subterranean_preferred_class_unresolved",
			"family": "dirt",
			"block": "native_to_dirt_transition",
			"source_level": "provisional",
			"model": "provisional_subterranean_dirt_bridge_fallback",
			"provisional": true,
			"stamp": {"table": "full_receiver_native_to_dirt_5x4_provisional_stamp_table", "direction": "E", "frame": "00_15", "offset": {"x": 1, "y": 0}, "bridge_family": "dirt", "target_block": "native_to_dirt_transition", "source_kind": "cardinal_source", "mixed_reserved": true},
		},
	]
	for case in cases:
		var tile: Vector2i = case.get("tile", Vector2i.ZERO)
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		var terrain: Dictionary = presentation.get("terrain_presentation", {})
		if not _assert_live_bridge_resolver_case(terrain, case):
			_restore_solid_region_fixture(shell, session, original_map, original_fog)
			push_error("Overworld smoke: bridge material resolver metadata did not match case %s. presentation=%s" % [case, presentation])
			get_tree().quit(1)
			return false
	_restore_solid_region_fixture(shell, session, original_map, original_fog)
	return true

func _assert_live_bridge_resolver_case(terrain: Dictionary, expected: Dictionary) -> bool:
	var expected_selection := String(expected.get("selection", "bridge_transition"))
	if expected.has("selection") and String(terrain.get("homm3_selection_kind", "")) != expected_selection:
		return false
	if String(terrain.get("homm3_visual_selection_model", "")) != "accepted_web_prototype_relation_class_row_lookup.v1":
		return false
	if String(terrain.get("homm3_bridge_resolver_model", "")) != "accepted_web_prototype_relation_class_row_lookup.v1":
		return false
	var stamp_expected = expected.get("stamp", {})
	if stamp_expected is Dictionary and not stamp_expected.is_empty():
		if not _assert_full_receiver_stamp_payload(terrain, stamp_expected):
			return false
	var sources: Array = terrain.get("transition_cardinal_sources", [])
	var expected_source := String(expected.get("source", ""))
	for source_value in sources:
		if not (source_value is Dictionary):
			continue
		var source: Dictionary = source_value
		if (
			String(source.get("source_terrain", "")) == expected_source
			and String(source.get("bridge_source_kind", "")) == String(expected.get("kind", ""))
			and String(source.get("bridge_rule_id", "")) == String(expected.get("rule", ""))
			and String(source.get("bridge_class", "")) == String(expected.get("class", ""))
			and String(source.get("resolved_bridge_family", "")) == String(expected.get("family", ""))
			and String(source.get("bridge_source_level", "")) == String(expected.get("source_level", ""))
			and String(source.get("bridge_resolution_model", "")) == String(expected.get("model", ""))
		):
			return true
	return false

func _assert_full_receiver_stamp_payload(terrain: Dictionary, expected: Dictionary) -> bool:
	if not bool(terrain.get("homm3_uses_land_receiver_stamp_tables", false)):
		return false
	if bool(terrain.get("homm3_allows_generic_land_edge_masks", true)):
		return false
	if String(terrain.get("homm3_visual_selection_model", "")) != "accepted_web_prototype_relation_class_row_lookup.v1":
		return false
	if String(terrain.get("homm3_final_normalization_model", "")) != "final_normalization_4bbfcc_reclassifies_settled_owner_map":
		return false
	if String(terrain.get("homm3_stamp_selection_model", "")) != "":
		return false
	if String(terrain.get("homm3_stamp_selected_frame", "")) != "":
		return false
	if int(terrain.get("homm3_shape_class", 0)) <= 0:
		return false
	if String(terrain.get("homm3_relation_grid", "")) == "":
		return false
	if String(expected.get("bridge_family", "")) != "" and String(terrain.get("homm3_bridge_family", "")) != String(expected.get("bridge_family", "")):
		return false
	if String(expected.get("target_block", "")) != "" and String(terrain.get("homm3_selected_frame_block", "")) != String(expected.get("target_block", "")):
		return false
	if expected.has("shape_class") and int(terrain.get("homm3_shape_class", 0)) != int(expected.get("shape_class", -1)):
		return false
	if expected.has("row_group") and String(terrain.get("homm3_row_group", "")) != String(expected.get("row_group", "")):
		return false
	if expected.has("frame") and expected.has("shape_class") and String(terrain.get("homm3_terrain_frame", "")) != String(expected.get("frame", "")):
		return false
	var expected_flip := String(expected.get("flip", String(terrain.get("homm3_terrain_flip", ""))))
	if String(terrain.get("homm3_terrain_flip", "")) != expected_flip:
		return false
	if expected.has("flip_h") and bool(terrain.get("homm3_terrain_flip_h", false)) != bool(expected.get("flip_h", false)):
		return false
	if expected.has("flip_v") and bool(terrain.get("homm3_terrain_flip_v", false)) != bool(expected.get("flip_v", false)):
		return false
	if String(terrain.get("homm3_web_prototype_selection_model", "")) != String(terrain.get("homm3_visual_selection_model", "")):
		return false
	return true

func _assert_solid_region_interior_stability(shell: Node, session) -> bool:
	var center := Vector2i(4, 2)
	var original_map = session.overworld.get("map", []).duplicate(true)
	var original_fog = session.overworld.get("fog", {}).duplicate(true)
	var map_size := OverworldRules.derive_map_size(session)
	var controlled_tiles := []
	for y in range(map_size.y):
		for x in range(map_size.x):
			var tile := Vector2i(x, y)
			controlled_tiles.append(tile)
	for receiver_terrain in ["grass", "snow"]:
		var working_map := []
		for y in range(map_size.y):
			var row := []
			for x in range(map_size.x):
				row.append("badlands")
			working_map.append(row)
		for y in range(center.y - 1, center.y + 2):
			for x in range(center.x - 1, center.x + 2):
				working_map[y][x] = receiver_terrain
		session.overworld["map"] = working_map
		_reveal_validation_tiles(session, controlled_tiles)
		shell.call("_refresh")

		var north_edge := center + Vector2i(0, -1)
		var edge_presentation: Dictionary = shell.call("validation_tile_presentation", north_edge.x, north_edge.y)
		var edge_terrain: Dictionary = edge_presentation.get("terrain_presentation", {})
		if (
			String(edge_terrain.get("terrain", "")) != receiver_terrain
			or String(edge_terrain.get("homm3_selection_kind", "")) != "bridge_transition"
			or String(edge_terrain.get("transition_edge_mask", "")) != "N"
			or String(edge_terrain.get("homm3_bridge_family", "")) != "dirt"
			or String(edge_terrain.get("homm3_selected_frame_block", "")) != "native_to_dirt_transition"
			or int(edge_terrain.get("edge_transition_count", 0)) != 1
			or int(edge_terrain.get("propagated_transition_count", -1)) != 0
			or "badlands" not in edge_terrain.get("transition_source_terrain_ids", [])
		):
			_restore_solid_region_fixture(shell, session, original_map, original_fog)
			push_error("Overworld smoke: %s block outer edge did not keep the dirt transition frame. presentation=%s" % [receiver_terrain, edge_presentation])
			get_tree().quit(1)
			return false
		if not _assert_full_receiver_stamp_payload(edge_terrain, {
			"table": "full_receiver_native_to_dirt_5x4_provisional_stamp_table",
			"direction": "N",
			"frame": "00_08",
			"offset": {"x": 0, "y": -1},
			"bridge_family": "dirt",
			"target_block": "native_to_dirt_transition",
			"source_kind": "cardinal_source",
			"mixed_reserved": true,
		}):
			_restore_solid_region_fixture(shell, session, original_map, original_fog)
			push_error("Overworld smoke: %s block outer edge did not expose source-anchored dirt stamp metadata. presentation=%s" % [receiver_terrain, edge_presentation])
			get_tree().quit(1)
			return false

		var interior_presentation: Dictionary = shell.call("validation_tile_presentation", center.x, center.y)
		var interior_terrain: Dictionary = interior_presentation.get("terrain_presentation", {})
		if not _assert_solid_region_interior_payload(interior_terrain, receiver_terrain):
			_restore_solid_region_fixture(shell, session, original_map, original_fog)
			push_error("Overworld smoke: %s block interior selected a dirt/sand transition stamp. presentation=%s" % [receiver_terrain, interior_presentation])
			get_tree().quit(1)
			return false

	_restore_solid_region_fixture(shell, session, original_map, original_fog)
	return true

func _assert_solid_region_interior_payload(terrain: Dictionary, expected_terrain: String) -> bool:
	if String(terrain.get("terrain", "")) != expected_terrain:
		return false
	if String(terrain.get("homm3_selection_kind", "")) != "interior":
		return false
	if bool(terrain.get("homm3_propagated_transition", false)):
		return false
	if String(terrain.get("homm3_selected_frame_block", "")) != "native_interiors":
		return false
	if String(terrain.get("homm3_stamp_table_id", "")) != "":
		return false
	if String(terrain.get("transition_edge_mask", "")) != "" or String(terrain.get("transition_corner_mask", "")) != "":
		return false
	if int(terrain.get("edge_transition_count", -1)) != 0 or int(terrain.get("corner_transition_count", -1)) != 0 or int(terrain.get("propagated_transition_count", -1)) != 0:
		return false
	if "badlands" in terrain.get("transition_source_terrain_ids", []) or "wastes" in terrain.get("transition_source_terrain_ids", []):
		return false
	return true

func _restore_solid_region_fixture(shell: Node, session, original_map, original_fog) -> void:
	session.overworld["map"] = original_map.duplicate(true) if original_map is Array else []
	session.overworld["fog"] = original_fog.duplicate(true) if original_fog is Dictionary else {}
	shell.call("_refresh")

func _reveal_validation_tiles(session, tiles: Array) -> void:
	var map_size := OverworldRules.derive_map_size(session)
	var visible_tiles := []
	var explored_tiles := []
	for y in range(map_size.y):
		var visible_row := []
		var explored_row := []
		for x in range(map_size.x):
			visible_row.append(false)
			explored_row.append(false)
		visible_tiles.append(visible_row)
		explored_tiles.append(explored_row)
	for tile_value in tiles:
		if not (tile_value is Vector2i):
			continue
		var tile: Vector2i = tile_value
		if tile.x < 0 or tile.y < 0 or tile.x >= map_size.x or tile.y >= map_size.y:
			continue
		visible_tiles[tile.y][tile.x] = true
		explored_tiles[tile.y][tile.x] = true
	session.overworld["fog"] = {
		"visible_tiles": visible_tiles,
		"explored_tiles": explored_tiles,
		"visible_count": tiles.size(),
		"explored_count": tiles.size(),
		"total_tiles": map_size.x * map_size.y,
	}

func _assert_art_sprite(presentation: Dictionary, expected_asset_id: String, remembered: bool) -> bool:
	var art: Dictionary = presentation.get("art_presentation", {})
	var asset_ids: Array = art.get("sprite_asset_ids", [])
	var is_town := expected_asset_id == "frontier_town"
	if not bool(art.get("uses_asset_sprite", false)) or expected_asset_id not in asset_ids:
		push_error("Overworld smoke: expected overworld sprite %s was not used. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if bool(art.get("fallback_procedural_marker", true)):
		push_error("Overworld smoke: mapped overworld sprite %s still reported procedural fallback. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if is_town:
		if String(art.get("sprite_settlement_model", "")) != "town_sprite_settled_without_base_ellipse" or String(art.get("sprite_depth_cue_model", "")) != "town_contact_line_without_cast_shadow":
			push_error("Overworld smoke: town sprite does not report the quiet no-ellipse grounding model. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
		if bool(art.get("sprite_placement_bed", true)) or bool(art.get("sprite_upper_mass_backdrop", true)) or bool(art.get("sprite_vertical_mass_shadow", true)):
			push_error("Overworld smoke: town sprite still reports placement bed or shadow/backdrop treatment. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
		if String(art.get("town_sprite_grounding_model", "")) != "town_sprite_settled_without_base_ellipse" or String(art.get("town_footprint_cue_model", "")) != "no_visible_helper_cues_3x2_contract":
			push_error("Overworld smoke: town art metadata does not expose the corrected footprint grounding model. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
		if bool(art.get("town_base_ellipse", true)) or bool(art.get("town_underlay", true)) or bool(art.get("town_cast_shadow", true)) or bool(art.get("town_vertical_mass_shadow", true)):
			push_error("Overworld smoke: town art metadata still exposes removed ellipse/underlay/shadow treatment. presentation=%s" % presentation)
			get_tree().quit(1)
			return false
		return true
	if String(art.get("sprite_settlement_model", "")) != "mapped_sprite_contact_grounding_no_support_stack" or bool(art.get("settled_sprite_occlusion", true)):
		push_error("Overworld smoke: mapped overworld sprite %s is not reporting the no-support-stack contact grounding. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if not bool(art.get("sprite_depth_contact_cues", false)) or String(art.get("sprite_depth_cue_model", "")) != "localized_sprite_contact_shadow_without_backdrop":
		push_error("Overworld smoke: mapped overworld sprite %s is not reporting localized contact depth cues. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if bool(art.get("sprite_placement_bed", true)) or String(art.get("sprite_placement_bed_model", "")) != "":
		push_error("Overworld smoke: mapped overworld sprite %s still reports a placement bed. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if bool(art.get("sprite_upper_mass_backdrop", true)) or String(art.get("sprite_upper_mass_backdrop_model", "")) != "" or bool(art.get("sprite_vertical_mass_shadow", true)):
		push_error("Overworld smoke: mapped overworld sprite %s still reports upper-mass backdrop or vertical shadow support. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if not bool(art.get("mapped_sprite_grounding", false)) or String(art.get("mapped_sprite_grounding_model", "")) != "localized_sprite_contact_scuffs":
		push_error("Overworld smoke: mapped overworld sprite %s does not report localized contact-scuff grounding. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if String(art.get("mapped_sprite_contact_shadow_model", "")) != "localized_sprite_contact_shadow" or not bool(art.get("mapped_sprite_contact_scuffs", false)):
		push_error("Overworld smoke: mapped overworld sprite %s does not report localized contact shadow/scuffs. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if bool(art.get("mapped_sprite_foreground_lip", true)) or bool(art.get("mapped_sprite_support_stack", true)):
		push_error("Overworld smoke: mapped overworld sprite %s still reports foreground-lip/support-stack treatment. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	if remembered and String(art.get("remembered_sprite_treatment", "")) != "ghosted_sprite_with_ground_anchor":
		push_error("Overworld smoke: remembered sprite %s did not report ghosted memory treatment. presentation=%s" % [expected_asset_id, presentation])
		get_tree().quit(1)
		return false
	return true

func _first_player_town(session) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			return town_value
	return {}

func _remote_memory_tile_for_town(session, town_tile: Vector2i) -> Vector2i:
	var map_size := OverworldRules.derive_map_size(session)
	var scout_radius := HeroCommandRules.scouting_radius_for_hero(session.overworld.get("hero", {}))
	for y in range(map_size.y - 1, -1, -1):
		for x in range(map_size.x - 1, -1, -1):
			var tile := Vector2i(x, y)
			if abs(tile.x - town_tile.x) + abs(tile.y - town_tile.y) <= scout_radius:
				continue
			if OverworldRules.tile_is_blocked(session, tile.x, tile.y):
				continue
			if not _town_at(session, tile).is_empty():
				continue
			return tile
	return Vector2i(-1, -1)

func _first_unexplored_tile(session) -> Vector2i:
	var map_size := OverworldRules.derive_map_size(session)
	for y in range(map_size.y - 1, -1, -1):
		for x in range(map_size.x - 1, -1, -1):
			if not OverworldRules.is_tile_explored(session, x, y):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _two_step_diagonal_goal(session, start: Vector2i) -> Vector2i:
	var map_size: Vector2i = OverworldRules.derive_map_size(session)
	for offset in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var first_step: Vector2i = start + offset
		var goal: Vector2i = start + (offset * 2)
		if goal.x < 0 or goal.y < 0 or goal.x >= map_size.x or goal.y >= map_size.y:
			continue
		if OverworldRules.tile_is_blocked(session, first_step.x, first_step.y):
			continue
		if OverworldRules.tile_is_blocked(session, goal.x, goal.y):
			continue
		if _tile_has_fixture_object(session, first_step) or _tile_has_fixture_object(session, goal):
			continue
		if not OverworldRules.is_tile_explored(session, goal.x, goal.y):
			continue
		return goal
	return Vector2i(-1, -1)

func _two_step_diagonal_origin(session) -> Vector2i:
	var map_size: Vector2i = OverworldRules.derive_map_size(session)
	for y in range(map_size.y):
		for x in range(map_size.x):
			var origin: Vector2i = Vector2i(x, y)
			if OverworldRules.tile_is_blocked(session, origin.x, origin.y):
				continue
			if _tile_has_fixture_object(session, origin):
				continue
			for offset in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
				var first_step: Vector2i = origin + offset
				var goal: Vector2i = origin + (offset * 2)
				if goal.x < 0 or goal.y < 0 or goal.x >= map_size.x or goal.y >= map_size.y:
					continue
				if OverworldRules.tile_is_blocked(session, first_step.x, first_step.y):
					continue
				if OverworldRules.tile_is_blocked(session, goal.x, goal.y):
					continue
				if _tile_has_fixture_object(session, first_step) or _tile_has_fixture_object(session, goal):
					continue
				return origin
	return Vector2i(-1, -1)

func _diagonal_open_tile(session, start: Vector2i) -> Vector2i:
	var map_size: Vector2i = OverworldRules.derive_map_size(session)
	for offset in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var tile: Vector2i = start + offset
		if tile.x < 0 or tile.y < 0 or tile.x >= map_size.x or tile.y >= map_size.y:
			continue
		if OverworldRules.tile_is_blocked(session, tile.x, tile.y):
			continue
		if _tile_has_fixture_object(session, tile):
			continue
		return tile
	return Vector2i(-1, -1)

func _tile_has_fixture_object(session, tile: Vector2i) -> bool:
	for collection_name in ["towns", "resource_sites", "artifacts", "encounters"]:
		for entry in session.overworld.get(collection_name, []):
			if entry is Dictionary and int(entry.get("x", -1)) == tile.x and int(entry.get("y", -1)) == tile.y:
				return true
	return false

func _town_at(session, tile: Vector2i) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and int(town_value.get("x", -1)) == tile.x and int(town_value.get("y", -1)) == tile.y:
			return town_value
	return {}

func _set_active_hero_position(session, tile: Vector2i) -> void:
	var position := {"x": tile.x, "y": tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _first_visible_town_tile(session) -> Vector2i:
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var tile := Vector2i(int(town_value.get("x", -1)), int(town_value.get("y", -1)))
		if OverworldRules.is_tile_visible(session, tile.x, tile.y):
			return tile
	return Vector2i(-1, -1)

func _first_visible_resource_tile(session) -> Vector2i:
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var tile := Vector2i(int(node.get("x", -1)), int(node.get("y", -1)))
		if not OverworldRules.is_tile_visible(session, tile.x, tile.y):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if bool(site.get("persistent_control", false)) or not bool(node.get("collected", false)):
			return tile
	return Vector2i(-1, -1)

func _first_visible_artifact_tile(session) -> Vector2i:
	for node_value in session.overworld.get("artifact_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var tile := Vector2i(int(node.get("x", -1)), int(node.get("y", -1)))
		if not bool(node.get("collected", false)) and OverworldRules.is_tile_visible(session, tile.x, tile.y):
			return tile
	return Vector2i(-1, -1)

func _first_visible_encounter_tile(session) -> Vector2i:
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		var tile := Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))
		if OverworldRules.is_tile_visible(session, tile.x, tile.y) and not OverworldRules.is_encounter_resolved(session, encounter):
			return tile
	return Vector2i(-1, -1)

func _assert_decluttered_right_shell(shell: Node, sidebar_shell: Control, command_spine: Control, action_panel: Control, action_containers: Array) -> bool:
	if command_spine == null or not (command_spine is VBoxContainer):
		push_error("Overworld smoke: contextual drawers must use a stacked command container, not a tab strip.")
		get_tree().quit(1)
		return false
	if _contains_tab_container(sidebar_shell):
		push_error("Overworld smoke: cramped right-rail TabContainer returned and can collapse labels into vertical text.")
		get_tree().quit(1)
		return false
	if command_spine.is_visible_in_tree():
		push_error("Overworld smoke: Command/Frontier/Tile drawers must not be permanently visible at startup.")
		get_tree().quit(1)
		return false
	if action_panel == null or not action_panel.is_visible_in_tree():
		push_error("Overworld smoke: Command and Frontier must remain accessible through compact drawer buttons.")
		get_tree().quit(1)
		return false
	if shell.get_node_or_null("%MarchPanel") != null or shell.get_node_or_null("%MapHint") != null:
		push_error("Overworld smoke: old permanent movement hint or march-control footer returned.")
		get_tree().quit(1)
		return false
	for direction_button in ["MoveNorth", "MoveSouth", "MoveWest", "MoveEast"]:
		if shell.get_node_or_null("%" + direction_button) != null:
			push_error("Overworld smoke: footer march direction button %s returned." % direction_button)
			get_tree().quit(1)
			return false
	var map_cue = shell.get_node_or_null("%MapCue")
	if map_cue is Label:
		var cue_text := String((map_cue as Label).text)
		if cue_text.find("WASD") >= 0 or cue_text.find("Click route") >= 0 or cue_text.find("Click adjacent") >= 0:
			push_error("Overworld smoke: footer cue regressed into permanent movement-hint text: %s" % cue_text)
			get_tree().quit(1)
			return false
	if not _assert_drawer_toggle(shell, "command"):
		return false
	if not _assert_drawer_toggle(shell, "frontier"):
		return false
	for container in action_containers:
		if container == null or not (container is VBoxContainer):
			push_error("Overworld smoke: drawer actions must be full-width vertical command rows.")
			get_tree().quit(1)
			return false
		if container.is_visible_in_tree() and container.get_global_rect().size.x < 220.0:
			push_error("Overworld smoke: action drawer width collapsed below readable command-button width.")
			get_tree().quit(1)
			return false
		for child in container.get_children():
			if child is Button and child.visible and child.get_global_rect().size.x < 200.0:
				push_error("Overworld smoke: drawer command button collapsed into an unreadable chip.")
				get_tree().quit(1)
				return false
	if _has_vertical_text_like_label(sidebar_shell):
		push_error("Overworld smoke: right rail contains a visible label/control shaped like vertical text.")
		get_tree().quit(1)
		return false
	if not _assert_compact_rail_text(shell):
		return false
	return true

func _assert_drawer_toggle(shell: Node, drawer: String) -> bool:
	var state: Dictionary = {}
	match drawer:
		"command":
			state = shell.validation_open_command_drawer()
			if not bool(state.get("command_drawer_visible", false)):
				push_error("Overworld smoke: Command button did not open the command drawer.")
				get_tree().quit(1)
				return false
			if bool(state.get("frontier_drawer_visible", false)):
				push_error("Overworld smoke: Command drawer opened on top of the Frontier drawer.")
				get_tree().quit(1)
				return false
		"frontier":
			state = shell.validation_open_frontier_drawer()
			if not bool(state.get("frontier_drawer_visible", false)):
				push_error("Overworld smoke: Frontier button did not open the frontier drawer.")
				get_tree().quit(1)
				return false
			if bool(state.get("command_drawer_visible", false)):
				push_error("Overworld smoke: Frontier drawer opened on top of the Command drawer.")
				get_tree().quit(1)
				return false
		_:
			push_error("Overworld smoke: unknown drawer assertion %s." % drawer)
			get_tree().quit(1)
			return false
	if bool(state.get("order_panel_visible", false)):
		push_error("Overworld smoke: hidden Order panel became permanent while opening %s." % drawer)
		get_tree().quit(1)
		return false
	shell._on_close_drawers_pressed()
	var closed_state: Dictionary = shell._validation_chrome_state()
	if bool(closed_state.get("command_spine_visible", false)):
		push_error("Overworld smoke: drawer spine stayed visible after closing %s." % drawer)
		get_tree().quit(1)
		return false
	return true

func _assert_compact_rail_text(shell: Node) -> bool:
	var label_budgets := {
		"Event": 1,
		"Commitment": 2,
		"Briefing": 2,
		"Hero": 2,
		"Army": 1,
		"Heroes": 1,
		"Context": 2,
		"Specialties": 1,
		"Spellbook": 1,
		"Artifacts": 1,
		"Visibility": 1,
		"Objectives": 1,
		"Threats": 1,
		"Forecast": 1,
	}
	for label_name in label_budgets.keys():
		var label_node = shell.get_node_or_null("%" + String(label_name))
		if not (label_node is Label):
			push_error("Overworld smoke: compact rail label %s is missing." % String(label_name))
			get_tree().quit(1)
			return false
		var label := label_node as Label
		if not label.is_visible_in_tree():
			continue
		var lines := _visible_text_lines(label.text)
		if lines.size() > int(label_budgets[label_name]):
			push_error("Overworld smoke: %s rail label has %d visible lines; budget is %d." % [String(label_name), lines.size(), int(label_budgets[label_name])])
			get_tree().quit(1)
			return false
		if label.text.find("+ ") >= 0 and label.text.find("more") >= 0:
			push_error("Overworld smoke: %s rail label exposes hidden-report '+ more' wording." % String(label_name))
			get_tree().quit(1)
			return false
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF or not label.clip_text:
			push_error("Overworld smoke: %s rail label must trim overflow instead of wrapping into a text wall." % String(label_name))
			get_tree().quit(1)
			return false
		for line in lines:
			if String(line).length() > 48:
				push_error("Overworld smoke: %s rail label line is too long for the compact right rail: %s" % [String(label_name), String(line)])
				get_tree().quit(1)
				return false
	return true

func _visible_text_lines(text: String) -> Array[String]:
	var lines: Array[String] = []
	for raw_line in text.split("\n", false):
		var line := raw_line.strip_edges()
		if line != "":
			lines.append(line)
	return lines

func _first_open_adjacent_tile(session, origin: Vector2i) -> Vector2i:
	var map_size := OverworldRules.derive_map_size(session)
	for direction_value in [
		Vector2i.RIGHT,
		Vector2i.DOWN,
		Vector2i.UP,
		Vector2i.LEFT,
		Vector2i(1, 1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(-1, -1),
	]:
		var direction: Vector2i = direction_value
		var tile := origin + direction
		if tile.x < 0 or tile.y < 0 or tile.x >= map_size.x or tile.y >= map_size.y:
			continue
		if OverworldRules.tile_is_blocked(session, tile.x, tile.y):
			continue
		if not OverworldRules.is_tile_explored(session, tile.x, tile.y):
			continue
		if _tile_has_overworld_object(session, tile):
			continue
		return tile
	return Vector2i(-1, -1)

func _first_visible_blocked_tile(session) -> Vector2i:
	var map_size := OverworldRules.derive_map_size(session)
	for y in range(map_size.y):
		for x in range(map_size.x):
			if not OverworldRules.is_tile_visible(session, x, y):
				continue
			if OverworldRules.tile_is_blocked(session, x, y):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _tile_has_overworld_object(session, tile: Vector2i) -> bool:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and int(town.get("x", -1)) == tile.x and int(town.get("y", -1)) == tile.y:
			return true
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and not bool(node.get("collected", false)) and int(node.get("x", -1)) == tile.x and int(node.get("y", -1)) == tile.y:
			return true
	for node in session.overworld.get("artifact_nodes", []):
		if node is Dictionary and not bool(node.get("collected", false)) and int(node.get("x", -1)) == tile.x and int(node.get("y", -1)) == tile.y:
			return true
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and int(encounter.get("x", -1)) == tile.x and int(encounter.get("y", -1)) == tile.y and not OverworldRules.is_encounter_resolved(session, encounter):
			return true
	return false

func _render_cache_metrics(snapshot: Dictionary) -> Dictionary:
	var viewport_metrics: Dictionary = snapshot.get("map_viewport", {})
	var render_cache: Dictionary = viewport_metrics.get("render_cache", {})
	if render_cache.is_empty():
		return {}
	return {
		"session_static_generation": int(render_cache.get("session_static_generation", -1)),
		"state_generation": int(render_cache.get("state_generation", -1)),
		"dynamic_generation": int(render_cache.get("dynamic_generation", -1)),
		"session_static_reason": String(render_cache.get("session_static_reason", "")),
		"state_reason": String(render_cache.get("state_reason", "")),
		"dynamic_reason": String(render_cache.get("dynamic_reason", "")),
	}

func _contains_tab_container(node: Node) -> bool:
	if node is TabContainer:
		return true
	for child in node.get_children():
		if _contains_tab_container(child):
			return true
	return false

func _has_vertical_text_like_label(node: Node) -> bool:
	if node is Label or node is Button:
		var control := node as Control
		if control.is_visible_in_tree():
			var text := ""
			if node is Label:
				text = String((node as Label).text)
			elif node is Button:
				text = String((node as Button).text)
			text = text.strip_edges()
			var rect := control.get_global_rect()
			if text.length() >= 5 and rect.size.x < 70.0 and rect.size.y > rect.size.x * 1.4:
				return true
	for child in node.get_children():
		if _has_vertical_text_like_label(child):
			return true
	return false

func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var cursor := node.get_parent()
	while cursor != null:
		if cursor == ancestor:
			return true
		cursor = cursor.get_parent()
	return false
