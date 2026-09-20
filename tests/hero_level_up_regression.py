"""Focused level-up rules, save continuity and actual overworld popup check."""
import argparse
from pathlib import Path

from unified_mines_regression import run_probe

SCRIPT = r'''extends Node
const Factory = preload("res://scripts/core/ScenarioFactory.gd")
const Rules = preload("res://scripts/core/OverworldRules.gd")
const Heroes = preload("res://scripts/core/HeroCommandRules.gd")
const Progression = preload("res://scripts/core/HeroProgressionRules.gd")
const Battles = preload("res://scripts/core/BattleRules.gd")
const Store = preload("res://scripts/core/SessionStateStore.gd")
var checks := 0
var failures := []
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures.append(message)
func fixture():
	var session = Factory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	Rules.normalize_overworld_state(session)
	session.overworld.towns=[]
	session.overworld.encounters=[]
	session.overworld.map_objects=[]
	session.overworld.artifact_nodes=[]
	session.overworld.resource_nodes=[{"site_id":"site_waystone_cache","object_id":"object_waystone_cache","kind":"reward_reference","placement_id":"level_chest","x":3,"y":3,"level":0,"collected":false}]
	for row in session.overworld.map: row.fill("grass")
	for row in session.overworld.fog.explored_tiles: row.fill(true)
	for row in session.overworld.fog.visible_tiles: row.fill(true)
	Rules._set_active_hero_position(session,Vector2i(3,3),0)
	Rules.invalidate_spatial_lookup(session)
	return session
func restore(session):
	var saved = Store.SessionData.new()
	saved.from_dict(session.to_dict())
	Rules.normalize_overworld_state(saved)
	return saved
func frames():
	for i in range(5): await get_tree().process_frame
func _ready(): call_deferred("run")
func run():
	var out:=OS.get_cmdline_user_args()[0]
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution("1280x720")
	DisplayServer.window_set_position(Vector2i(-16000,-16000))
	get_tree().root.size=Vector2i(1280,720)
	get_tree().root.content_scale_size=Vector2i(1280,720)
	var session=fixture()
	check(Rules.get_level_up_prompt(session).is_empty(),"new hero gets false promotion")
	Rules._award_experience(session,100)
	check(Rules.get_level_up_prompt(session).is_empty(),"sub-threshold XP opens popup")
	Rules._award_experience(session,900)
	Heroes.commit_active_hero(session)
	var prompt:Dictionary=Rules.get_level_up_prompt(session)
	check(prompt.get("previous_level")==1 and prompt.get("level")==3,"two-level XP grant not summarized")
	check(prompt.command_gains.attack==1 and prompt.command_gains.defense==1,"wrong command gains")
	check(prompt.movement_gain==2,"automatic movement gains missing")
	check(not Rules.get_level_up_prompt(restore(session)).is_empty(),"unread level lost on save")
	var context:Dictionary=prompt.context.duplicate(true)
	context.hero_id="wrong-hero"
	check(not Rules.resolve_level_up(session,context,"armsmaster").ok,"stale hero accepted")
	check(not Rules.resolve_level_up(session,prompt.context,"invalid").ok,"invalid specialty accepted")
	var before:int=Progression.pending_choices_remaining(session.overworld.hero)
	var choice_id:String=prompt.choice.options[0]
	check(Rules.resolve_level_up(session,prompt.context,choice_id).ok,"first specialty failed")
	check(Progression.pending_choices_remaining(session.overworld.hero)==before-1,"first choice not consumed exactly once")
	check(not Rules.resolve_level_up(session,prompt.context,choice_id).ok,"duplicate callback selected another level")
	prompt=Rules.get_level_up_prompt(session)
	check(not prompt.is_empty(),"next level choice lost")
	check(Rules.resolve_level_up(session,prompt.context).ok,"deferral failed")
	check(Rules.get_level_up_prompt(restore(session)).is_empty(),"dismissal not saved")
	check(Progression.pending_choices_remaining(session.overworld.hero)==before-1,"deferral discarded specialty")
	Rules._award_experience(session,500)
	Heroes.commit_active_hero(session)
	prompt=Rules.get_level_up_prompt(session)
	check(prompt.previous_level==3 and prompt.level==4 and prompt.command_gains.attack==1 and prompt.command_gains.defense==0,"next promotion includes already reviewed gains")
	# Existing saves: only unresolved progression should receive a reminder.
	var legacy:Dictionary=session.overworld.hero.duplicate(true)
	legacy.erase("level_up_presented")
	check(not Progression.level_up_summary(legacy).is_empty(),"old unresolved save lacks popup")
	for specialty in Progression.SPECIALTIES:
		for rank in range(int(specialty.max_rank)): legacy.specialties.append(specialty.id)
	legacy.pending_specialty_choices=[]
	legacy.level=15
	legacy.next_level_experience=99999
	legacy=Progression.ensure_hero_progression(legacy)
	check(Progression.level_up_summary(legacy).is_empty(),"old mastered hero replays history")
	legacy=Progression.add_experience(legacy,100000).hero
	check(not Progression.level_up_summary(legacy).is_empty() and Progression.level_up_summary(legacy).choice.is_empty(),"mastered hero loses promotion notice")
	# The battle XP path must carry the same unread state into commander writeback.
	var combat=fixture()
	combat.game_state="battle"
	combat.battle={"player_commander_source":{"type":"active_hero","hero_id":combat.overworld.hero.id},"player_commander_state":combat.overworld.hero.duplicate(true)}
	Battles._award_commander_experience(combat,1000)
	check(combat.battle.player_commander_state.level==3 and combat.battle.player_commander_state.level_up_presented==1,"battle award loses unread levels")
	check(Rules.get_level_up_prompt(combat).is_empty(),"popup interrupts battle")
	Battles._sync_player_force_from_battle(combat)
	combat.game_state="overworld"
	check(Rules.get_level_up_prompt(restore(combat)).level==3,"battle return loses level-up")
	# A town defender may earn XP while a different hero is selected.
	var company=fixture()
	var defender:Dictionary=company.overworld.hero.duplicate(true)
	defender.id="level-up-defender"
	defender.name="Town Defender"
	defender=Progression.add_experience(defender,250).hero
	defender.pending_specialty_choices=[{"level":2,"options":["wayfinder","spellwright","armsmaster"]}]
	defender.movement.current=3
	company.overworld.player_heroes.append(defender)
	Rules.normalize_overworld_state(company)
	defender=Heroes.hero_by_id(company,defender.id)
	var active_before:Dictionary=company.overworld.hero.duplicate(true)
	var defender_max:int=defender.movement.max
	prompt=Rules.get_level_up_prompt(company)
	check(prompt.context.hero_id==defender.id,"inactive defender promotion missing")
	check(Rules.resolve_level_up(company,prompt.context,"wayfinder").ok,"inactive defender cannot select specialty")
	defender=Heroes.hero_by_id(company,defender.id)
	check(defender.movement.max==defender_max+2 and defender.movement.current==5,"inactive defender movement gain incorrect: previous max %d, got %s" % [defender_max,str(defender.movement)])
	check(company.overworld.hero==active_before and company.overworld.active_hero_id==active_before.id,"defender popup changed active hero")
	check(Rules.get_level_up_prompt(restore(company)).is_empty(),"defender popup acknowledgment not saved")
	SessionState.active_session=fixture()
	session=SessionState.active_session
	var shell=load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await frames()
	check(not is_instance_valid(shell._hero_level_up_dialog),"live shell opens false level up")
	shell._on_context_action_pressed("collect_resource")
	await frames()
	check(shell._resource_reward_dialog.visible,"chest popup missing")
	check(not is_instance_valid(shell._hero_level_up_dialog),"level popup covers unopened chest")
	shell._on_resource_reward_selected("experience")
	await frames()
	var dialog=shell._hero_level_up_dialog
	check(is_instance_valid(dialog) and dialog.visible,"chest XP does not open level-up popup")
	check(not shell._resource_reward_dialog.visible,"chest remains under level popup")
	if is_instance_valid(dialog):
		check(shell._overworld_gameplay_movement_blocked_reason()=="hero_level_up_open","movement not blocked")
		check(dialog.size.x<=1280 and dialog.size.y<=720,"popup exceeds viewport")
		check(dialog.find_child("HeroPortrait",true,false).texture!=null,"portrait missing")
		var options=dialog.find_children("Specialty_*","Button",true,false)
		check(options.size()==3,"specialty options missing")
		for button in options:
			check(button.accessibility_name!="" and button.focus_mode==Control.FOCUS_ALL,"specialty button lacks accessible keyboard input")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out+"/level-up.png")
		var xp_before:int=session.overworld.hero.experience
		var pending_before:int=Progression.pending_choices_remaining(session.overworld.hero)
		options[0].pressed.emit()
		await frames()
		check(Progression.pending_choices_remaining(session.overworld.hero)==pending_before-1,"live button did not select")
		check(shell._hero_level_up_dialog.visible,"second specialty popup missing")
		check(session.overworld.hero.experience==xp_before,"popup adds experience twice")
		# Real Escape input exercises Godot's automatic dialog hiding/close signal.
		var escape:=InputEventKey.new()
		escape.keycode=KEY_ESCAPE
		escape.pressed=true
		get_viewport().push_input(escape)
		await frames()
		check(not shell._hero_level_up_dialog.visible,"Escape did not close popup")
		check(Rules.get_level_up_prompt(restore(session)).is_empty(),"Escape acknowledgment lost")
		shell._refresh()
		await frames()
		check(not shell._hero_level_up_dialog.visible,"ordinary refresh reopens dismissed popup")
		# A new promotion must wait while another modal owns input, then resume.
		shell._resource_reward_dialog.popup_centered(Vector2i(640,340))
		Rules._award_experience(session,1000)
		Heroes.commit_active_hero(session)
		shell._refresh()
		await frames()
		check(not shell._hero_level_up_dialog.visible,"promotion overlaps another dialog")
		shell._on_resource_reward_canceled()
		await get_tree().create_timer(.4).timeout
		check(shell._hero_level_up_dialog.visible,"queued promotion not resumed")
		var safety:=0
		while shell._hero_level_up_dialog.visible and safety<8:
			safety+=1
			var buttons=shell._hero_level_up_dialog.find_children("Specialty_*","Button",true,false)
			if buttons.is_empty(): break
			buttons[0].pressed.emit()
			await frames()
		check(Rules.get_level_up_prompt(restore(session)).is_empty(),"completed choices replay after save")
		# A fully mastered hero still receives command gains and a Continue button.
		session.overworld.hero=legacy.duplicate(true)
		session.overworld.hero.id=session.overworld.active_hero_id
		Heroes.commit_active_hero(session)
		shell._refresh()
		await frames()
		check(shell._hero_level_up_dialog.visible and shell._hero_level_up_dialog.get_ok_button().visible,"mastered popup missing Continue")
		shell._hero_level_up_dialog.get_ok_button().pressed.emit()
		await frames()
		check(Rules.get_level_up_prompt(restore(session)).is_empty(),"Continue did not acknowledge promotion")
	print("HERO_LEVEL_UP_REPORT "+JSON.stringify({"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    raise SystemExit(run_probe(SCRIPT, args.godot, args.output, 'HERO_LEVEL_UP_REPORT'))
