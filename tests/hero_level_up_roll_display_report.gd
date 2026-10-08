extends Node
## Level-up roll display (owner request 2026-10-08: show what the hero rolled
## on the level-up screen with the specialty choices). Opens the real dialog
## for real level-ups and checks the headline, the four stat tiles (rolled ones
## lit with their gain, new values), the path odds, the per-level rolls and
## that the specialty choices are still there. With LEVEL_UP_CAPTURE_DIR set
## and a window, it also saves a capture of each case.

const DialogScript = preload("res://scenes/shared/HeroLevelUpDialog.gd")
const REPORT_ID := "HERO_LEVEL_UP_ROLL_DISPLAY_REPORT"
const STAT_NAMES := {"attack": "Attack", "defense": "Defense", "power": "Spell power", "knowledge": "Knowledge"}

var _checks := 0
var _failures := []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("%s check failed: %s" % [REPORT_ID, label])

func _run() -> void:
	await _case("magic_one_level", "hero_lyra", "roll-display-a", 2)
	await _case("magic_two_levels", "hero_lyra", "roll-display-b", 3)
	await _case("might_one_level", "hero_caelen", "roll-display-c", 2)
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)

## The prompt the overworld builds (OverworldRules.get_level_up_prompt).
func _prompt(hero_id: String, growth_seed: String, level: int) -> Dictionary:
	var hero := HeroCommandRules.build_hero_from_template(ContentService.get_hero(hero_id), {}, {}, "normal")
	hero["growth_seed"] = growth_seed
	hero = HeroProgressionRules.add_experience(hero, HeroProgressionRules.experience_for_level(level)).get("hero", hero)
	var summary := HeroProgressionRules.level_up_summary(hero)
	summary["hero"] = hero.duplicate(true)
	summary["context"] = {"hero_id": hero_id, "level": summary["level"], "previous_level": summary["previous_level"], "choice": summary["choice"].duplicate(true)}
	return summary

func _case(label: String, hero_id: String, growth_seed: String, level: int) -> void:
	var prompt := _prompt(hero_id, growth_seed, level)
	var dialog = DialogScript.new()
	add_child(dialog)
	dialog.open_level_up(prompt)
	await get_tree().process_frame
	var gains: Dictionary = prompt.get("command_gains", {})
	var command: Dictionary = prompt["hero"].get("command", {})
	var headline: Label = dialog.find_child("RolledHeadline", true, false)
	_check(headline != null, "%s: rolled headline shown" % label)
	for stat in STAT_NAMES:
		var tile: Control = dialog.find_child("Stat_" + stat, true, false)
		_check(tile != null, "%s: %s tile shown" % [label, stat])
		if tile == null:
			continue
		var value: Label = tile.find_child("Value", true, false)
		_check(value != null and value.text == str(int(command.get(stat, 0))), "%s: %s tile shows the new value %d" % [label, stat, int(command.get(stat, 0))])
		var gain: Label = tile.find_child("Gain", true, false)
		var amount := int(gains.get(stat, 0))
		if amount > 0:
			_check(gain != null and gain.text == "+%d" % amount, "%s: %s tile shows +%d" % [label, stat, amount])
			_check(headline != null and headline.text.contains("+%d %s" % [amount, STAT_NAMES[stat]]), "%s: headline names +%d %s (%s)" % [label, amount, STAT_NAMES[stat], headline.text if headline != null else ""])
		else:
			_check(gain == null, "%s: %s tile shows no gain" % [label, stat])
	var odds: Label = dialog.find_child("Odds", true, false)
	var path := String(prompt.get("command_path", ""))
	_check(odds != null and odds.text.begins_with(path.capitalize()) and odds.text.contains("40%") and odds.text.contains("10%"), "%s: %s path odds shown (%s)" % [label, path, odds.text if odds != null else ""])
	var by_level: Label = dialog.find_child("RollsByLevel", true, false)
	var rolls: Array = prompt.get("command_rolls", [])
	if rolls.size() > 1:
		var all_named := by_level != null
		for roll in rolls:
			all_named = all_named and by_level.text.contains("Level %d: %s" % [int(roll.level), STAT_NAMES[String(roll.stat)]])
		_check(all_named, "%s: each level's roll is listed (%s)" % [label, by_level.text if by_level != null else ""])
	else:
		_check(by_level == null, "%s: a single level needs no per-level list" % label)
	var choice: Dictionary = prompt.get("choice", {})
	var buttons := 0
	for option in choice.get("options", []):
		if dialog.find_child("Specialty_" + String(option), true, false) != null:
			buttons += 1
	_check(not choice.is_empty() and buttons == choice.get("options", []).size(), "%s: the specialty choices are still offered (%d)" % [label, buttons])
	var directory := OS.get_environment("LEVEL_UP_CAPTURE_DIR")
	if DisplayServer.get_name() != "headless" and directory != "":
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(directory)
		dialog.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [directory, label])
	dialog.queue_free()
	await get_tree().process_frame
