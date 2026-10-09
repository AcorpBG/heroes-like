extends Node
## Floating gain text (owner request 2026-10-09: when the hero picks up
## anything, float what was gained and let it fade). Checks the gain lines
## OverworldGainFeed builds from before/after snapshots, then walks a hero on
## a generated small map onto a wood pile through the real shell: the line
## waits for the walk, floats, and is gone after its lifetime. With
## GAIN_FLOATER_CAPTURE set and a window, saves a capture while it floats.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const OverworldShellScene = preload("res://scenes/overworld/OverworldShell.tscn")
const GainFeed = preload("res://scripts/core/OverworldGainFeed.gd")
const GainFloaters = preload("res://scenes/overworld/OverworldGainFloaters.gd")
const REPORT_ID := "OVERWORLD_GAIN_FLOATERS_REPORT"
const SEED := "gain-floaters-20261009"

var _checks := 0
var _failures := []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("%s check failed: %s" % [REPORT_ID, label])

func _frames(count: int) -> void:
	for index in range(count):
		await get_tree().process_frame

func _run() -> void:
	_check_lines()
	await _check_live_pickup()
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)

func _texts(lines: Array) -> Array:
	return lines.map(func(line): return String(line.text))

func _check_lines() -> void:
	var site_id := "site_brightwood_sawmill"
	var before := {
		"resources": {"gold": 1000, "wood": 5, "ore": 2},
		"hero_id": "hero_caelen",
		"experience": 100,
		"command": {"attack": 1, "defense": 2, "power": 0, "knowledge": 1},
		"artifacts": [],
		"spells": [],
		"mana": 10,
		"movement": 12,
		"army": {"unit_ember_archer": 10},
		"boosts": {},
		"owned_sites": {},
	}
	var artifact_id := String(ContentService.load_json(ContentService.ARTIFACTS_PATH).get("items", [{}])[0].get("id", ""))
	var spell_id := "spell_waystride"
	var after := before.duplicate(true)
	after.resources = {"gold": 1500, "wood": 3, "ore": 2, "aetherglass": 2}
	after.experience = 600
	after.command.attack = 2
	after.artifacts = [artifact_id]
	after.spells = [spell_id]
	after.mana = 20
	after.movement = 7
	after.army = {"unit_ember_archer": 14}
	after.boosts = {"cohesion": 2}
	after.owned_sites = {"camp_1": site_id}
	var lines := GainFeed.gains(before, after, 5)
	var texts := _texts(lines)
	var unit_name := String(ContentService.get_unit("unit_ember_archer").get("name", "unit_ember_archer"))
	var expected := [
		"Sawmill claimed",
		String(ContentService.get_artifact(artifact_id).get("name", artifact_id)),
		"+500 Gold",
		"+2 Aetherglass",
		"+4 %s" % unit_name,
		"+1 Attack",
		"Learned %s" % String(ContentService.get_spell(spell_id).get("name", spell_id)),
		"+500 Experience",
		"+10 Mana",
		"+2 Cohesion next battle",
		"-2 Wood",
	]
	_check(texts == expected, "gain lines in order: %s" % [texts])
	_check(String(lines[2].get("icon", "")).ends_with(".png") and String(lines[2].get("tone", "")) == "gain", "resource lines carry their icon and gain tone")
	_check(String(lines[lines.size() - 1].get("tone", "")) == "cost", "spending is shown as a cost")
	_check(not ("+0 Movement" in texts) and not texts.any(func(text): return String(text).ends_with("Movement")), "a walk that spent 5 of the 5 lost movement shows no movement line")
	var stable := after.duplicate(true)
	stable.movement = 20
	_check("+13 Movement" in _texts(GainFeed.gains(before, stable, 5)), "a stable at the end of a 5-step walk shows the movement it restored (+13)")
	var other_hero := after.duplicate(true)
	other_hero.hero_id = "hero_lyra"
	_check(not ("+1 Attack" in _texts(GainFeed.gains(before, other_hero))), "no hero lines when the active hero changed")
	_check(GainFeed.gains(before, before.duplicate(true)).is_empty(), "nothing gained, nothing floats")
	var picked := before.duplicate(true)
	picked.owned_sites = {"pile_1": "site_split_wood_pile"}
	picked.resources = {"gold": 1000, "wood": 15, "ore": 2}
	_check(_texts(GainFeed.gains(before, picked)) == ["+10 Wood"], "a one-time pickup is not 'claimed': %s" % [_texts(GainFeed.gains(before, picked))])

func _check_live_pickup() -> void:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(SEED, "", "", 2, "land", false, "homm3_small", ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT, "faction_embercourt", "hero_caelen")
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	_check(bool(setup.get("ok", false)), "small generated setup")
	if not bool(setup.get("ok", false)):
		return
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	OverworldRules.normalize_overworld_state(session)
	var hero_tile: Vector2i = OverworldRules.hero_position(session)
	var target := Vector2i(-1, -1)
	for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var tile: Vector2i = hero_tile + step
		if not OverworldRules.tile_is_blocked(session, tile.x, tile.y) and not OverworldRules.tile_has_route_interaction(session, tile.x, tile.y):
			target = tile
			break
	_check(target.x >= 0, "a free tile next to the hero")
	if target.x < 0:
		return
	var nodes: Array = session.overworld.get("resource_nodes", [])
	nodes.append({"placement_id": "gain_floater_wood", "site_id": "site_split_wood_pile", "object_id": "object_split_wood_pile", "x": target.x, "y": target.y, "level": 0, "collected": false})
	session.overworld["resource_nodes"] = nodes
	OverworldRules.invalidate_spatial_lookup(session)
	session.game_state = "overworld"
	session = SessionState.set_active_session(session)
	var shell = OverworldShellScene.instantiate()
	add_child(shell)
	await _frames(8)
	var view = shell.get("_map_view")
	var wood_before := int(session.overworld.get("resources", {}).get("wood", 0))
	shell.call("_try_move", target.x - hero_tile.x, target.y - hero_tile.y)
	var wood_gained := int(session.overworld.get("resources", {}).get("wood", 0)) - wood_before
	_check(wood_gained > 0, "walking onto the wood pile collected wood (+%d)" % wood_gained)
	var floaters: Dictionary = view.call("validation_gain_floaters")
	_check(int(floaters.get("pending", 0)) + int(floaters.get("live", 0)) >= 1, "the gain is queued to float: %s" % floaters)
	var seen := false
	var waited := 0.0
	while waited < 2.0 and not seen:
		await _frames(1)
		waited += get_process_delta_time()
		seen = ("+%d Wood" % wood_gained) in view.call("validation_gain_floaters").get("texts", [])
	_check(seen, "'+%d Wood' floats above the hero (%s)" % [wood_gained, view.call("validation_gain_floaters")])
	var capture := OS.get_environment("GAIN_FLOATER_CAPTURE")
	if DisplayServer.get_name() != "headless" and capture != "":
		# A fuller gain one tile away, to show how several lines stack.
		var sample := [
			{"text": "Ember Hatchery claimed", "icon": "", "tone": "claim"},
			{"text": String(ContentService.get_artifact("artifact_trailsinger_boots").get("name", "Trailsinger Boots")), "icon": ArtifactRules.artifact_icon_path("artifact_trailsinger_boots"), "tone": "artifact"},
			{"text": "+750 Gold", "icon": OverworldRules.resource_icon_path("gold"), "tone": "gain"},
			{"text": "+500 Experience", "icon": "", "tone": "gain"},
			{"text": "-2 Ore", "icon": OverworldRules.resource_icon_path("ore"), "tone": "cost"},
		]
		view.call("show_gain_floaters", hero_tile + Vector2i(5, 4), sample)
		await get_tree().create_timer(1.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture)
	await get_tree().create_timer(GainFloaters.LIFETIME + 0.6).timeout
	floaters = view.call("validation_gain_floaters")
	_check(int(floaters.get("live", 0)) == 0 and int(floaters.get("pending", 0)) == 0, "the text has faded out after its lifetime: %s" % floaters)
	shell.queue_free()
	await _frames(2)
