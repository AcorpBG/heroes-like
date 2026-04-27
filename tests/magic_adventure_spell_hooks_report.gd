extends Node

const REPORT_ID := "MAGIC_ADVENTURE_SPELL_HOOKS_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var raw := ContentService.load_json(ContentService.SPELLS_PATH)
	var spells: Array = raw.get("items", [])
	var report := SpellRules.adventure_spell_behavior_report(spells)
	if not bool(report.get("ok", false)):
		_fail(String(report.get("errors", [])))
		return
	if int(report.get("adventure_spell_count", 0)) != 3:
		_fail("Expected the current authored overworld spell set to contain 3 spells.")
		return
	for required_hook in ["overworld_movement_restore", "mana_spend", "movement_clamp"]:
		if int(report.get("runtime_hook_counts", {}).get(required_hook, 0)) <= 0:
			_fail("Missing adventure runtime hook %s." % required_hook)
			return

	var hero := SpellRules.ensure_hero_spellbook(
		{
			"name": "Route Caster",
			"command": {"power": 1, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": [
					"spell_waystride",
					"spell_trailglyph",
					"spell_beacon_path",
				],
				"mana": {"current": 40, "max": 40},
			},
		}
	)
	var movement := {"current": 2, "max": 10}
	var trailglyph := ContentService.get_spell("spell_trailglyph")
	var target_contract := SpellRules.adventure_spell_target_contract(hero, movement, trailglyph)
	var consequence := SpellRules.adventure_spell_consequence_preview(hero, movement, trailglyph)
	if not bool(target_contract.get("ok", false)) or String(target_contract.get("target_kind", "")) != "self_hero":
		_fail("Trailglyph did not expose a valid self-hero adventure target contract: %s" % target_contract)
		return
	if int(consequence.get("movement_before", -1)) != 2 or int(consequence.get("movement_after", -1)) != 8:
		_fail("Trailglyph consequence preview did not clamp movement correctly: %s" % consequence)
		return
	if bool(consequence.get("changes_fog", true)) or bool(consequence.get("changes_site_state", true)) or bool(consequence.get("changes_resources", true)):
		_fail("Trailglyph consequence preview claimed unsupported map/resource mutation: %s" % consequence)
		return

	var actions := SpellRules.get_overworld_actions(hero, movement)
	if not _assert_public_payload("overworld spell actions", actions):
		return
	if not _has_action_contract(actions, "cast_spell:spell_trailglyph"):
		_fail("Trailglyph action did not include target and consequence contracts.")
		return

	var cast_result := SpellRules.cast_overworld_spell(hero, movement, "spell_trailglyph")
	if not bool(cast_result.get("ok", false)):
		_fail("SpellRules Trailglyph cast failed: %s" % cast_result)
		return
	if int(cast_result.get("movement", {}).get("current", 0)) != 8:
		_fail("SpellRules Trailglyph cast did not restore the expected movement: %s" % cast_result)
		return
	if int(cast_result.get("hero", {}).get("spellbook", {}).get("mana", {}).get("current", 0)) != 36:
		_fail("SpellRules Trailglyph cast did not spend the expected mana: %s" % cast_result)
		return
	if not _assert_public_payload("SpellRules cast result", cast_result):
		return

	var session := ScenarioFactory.create_session("river-pass", "normal", SessionStateStore.LAUNCH_MODE_CAMPAIGN)
	OverworldRules.normalize_overworld_state(session)
	var session_hero: Dictionary = session.overworld.get("hero", {})
	session_hero = SpellRules.ensure_hero_spellbook(session_hero)
	var spellbook: Dictionary = session_hero.get("spellbook", {})
	spellbook["known_spell_ids"] = ["spell_waystride", "spell_trailglyph", "spell_beacon_path"]
	spellbook["mana"] = {"current": 40, "max": 40}
	session_hero["spellbook"] = spellbook
	session_hero["movement"] = {"current": 1, "max": 10}
	session.overworld["hero"] = session_hero
	session.overworld["movement"] = {"current": 1, "max": 10}
	var player_heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	if not player_heroes.is_empty() and player_heroes[0] is Dictionary:
		player_heroes[0] = session_hero
		session.overworld["player_heroes"] = player_heroes
	var live_result := OverworldRules.cast_overworld_spell(session, "spell_beacon_path")
	if not bool(live_result.get("ok", false)):
		_fail("OverworldRules Beacon Path cast failed: %s" % live_result)
		return
	if int(session.overworld.get("movement", {}).get("current", 0)) != 6:
		_fail("OverworldRules Beacon Path did not restore bounded movement: %s" % live_result)
		return
	var recap: Dictionary = live_result.get("post_action_recap", {}) if live_result.get("post_action_recap", {}) is Dictionary else {}
	if String(recap.get("kind", "")) != "spell":
		_fail("OverworldRules spell cast did not expose a spell post-action recap: %s" % live_result)
		return
	if not String(recap.get("affected", "")).contains("active hero") or not String(recap.get("affected", "")).contains("restores"):
		_fail("Spell recap did not include public target and consequence text: %s" % recap)
		return
	if not _assert_public_payload("OverworldRules live result", live_result):
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": report.get("schema_status", ""),
		"adventure_spell_count": report.get("adventure_spell_count", 0),
		"runtime_hook_counts": report.get("runtime_hook_counts", {}),
		"target_policy_counts": report.get("target_policy_counts", {}),
		"cases": {
			"target_contract": {
				"spell_id": String(target_contract.get("spell_id", "")),
				"target_kind": String(target_contract.get("target_kind", "")),
				"target_requirement": String(target_contract.get("target_requirement", "")),
			},
			"consequence_preview": {
				"spell_id": String(consequence.get("spell_id", "")),
				"movement_before": int(consequence.get("movement_before", 0)),
				"movement_after": int(consequence.get("movement_after", 0)),
				"movement_restored": int(consequence.get("movement_restored", 0)),
			},
			"live_overworld_cast": {
				"spell_id": "spell_beacon_path",
				"movement_after": int(session.overworld.get("movement", {}).get("current", 0)),
				"recap_kind": String(recap.get("kind", "")),
			},
		},
		"caveats": [
			"This report proves bounded adventure-map movement spell hooks only; scouting, site state, resources, artifacts, AI casting, and save migration remain outside this slice.",
		],
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _has_action_contract(actions: Array, action_id: String) -> bool:
	for action in actions:
		if not (action is Dictionary):
			continue
		if String(action.get("id", "")) != action_id:
			continue
		return action.get("target_contract", {}) is Dictionary and action.get("consequence_preview", {}) is Dictionary
	return false

func _assert_public_payload(label: String, payload: Variant) -> bool:
	var surface_text := JSON.stringify(payload).to_lower()
	for leak_token in ["debug", "score", "internal"]:
		if surface_text.contains(leak_token):
			_fail("%s leaked %s: %s" % [label, leak_token, surface_text])
			return false
	return true

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
