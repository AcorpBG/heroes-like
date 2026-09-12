#!/usr/bin/env python3
"""Authoritative non-mutating exchange ranges plus real Battle UI/playback."""
import battle_readability_regression as base

OUTPUT = base.ROOT / '.artifacts/combat_consequence_20260912'
CHECKS = r'''
func consequence_checks()->void:
	for mode in ["adjacent", "approach", "ranged", "lethal", "spent", "harry", "overheat", "reflection", "hookline"]:
		for seed in range(1,13):
			var session=fixture()
			var a:Dictionary=session.battle.stacks[0]
			var d:Dictionary=session.battle.stacks[1]
			var ally:Dictionary=a.duplicate(true)
			ally.battle_id="preview_ally"
			ally.hex={"q":0,"r":0}
			session.battle.stacks.append(ally)
			session.battle.turn_order=[a.battle_id,ally.battle_id,d.battle_id,session.battle.stacks[2].battle_id]
			a.min_damage=2
			a.max_damage=5
			d.min_damage=2
			d.max_damage=6
			if mode!="approach":a.hex={"q":4,"r":3}
			if mode in ["ranged", "reflection"]:
				a.ranged=true
				a.shots_remaining=8
			if mode=="harry":a.abilities=ContentService.get_unit("unit_ember_archer").abilities.duplicate(true)
			if mode=="overheat":a.abilities=ContentService.get_unit("unit_brasshollow_debt_engine_exactors").abilities.duplicate(true)
			if mode=="reflection":d.abilities=ContentService.get_unit("unit_sunvault_shard_wardens").abilities.duplicate(true)
			if mode=="hookline":a.abilities=ContentService.get_unit("unit_mireclaw_ferrychain_lashers").abilities.duplicate(true)
			if mode=="lethal":d.total_health=60
			if mode=="spent":d.retaliations_left=0
			session.battle.combat_seed=seed
			BattleRules._initialize_damage_rng_state(session,session.battle)
			BattleRules._sync_occupied_hexes(session.battle)
			BattleRules._sync_distance_from_hexes(session.battle)
			var before:Dictionary=session.to_dict().duplicate(true)
			var action:String="shoot" if mode in ["ranged", "reflection"] else "strike"
			var preview:Dictionary=BattleRules.attack_consequence_preview(session.battle,action,d.battle_id)
			check(preview.ok,"legal preview rejected: "+mode)
			for i in range(3):check(BattleRules.attack_consequence_preview(session.battle,action,d.battle_id)==preview,"preview unstable")
			check(session.to_dict()==before,"preview mutated full state/RNG")
			if not preview.ok:continue
			var tampered:Dictionary=preview.duplicate(true)
			tampered=BattleRules.attack_consequence_preview(session.battle,action,d.battle_id)
			tampered.damage.min_damage=-999
			check(BattleRules.attack_consequence_preview(session.battle,action,d.battle_id).damage.min_damage>=0,"caller mutated cached forecast")
			var target_hp:int=d.total_health
			var actor_hp:int=a.total_health
			var target_count:int=BattleRules._alive_count(d)
			var actor_count:int=BattleRules._alive_count(a)
			var result:Dictionary=BattleRules.perform_player_action(session,action)
			check(result.ok,"previewed order rejected")
			check(a.hex==preview.destination,"committed approach differs from preview")
			var dealt:int=target_hp-int(d.total_health)
			var received:int=actor_hp-int(a.total_health)
			check(dealt>=mini(target_hp,preview.damage.min_damage) and dealt<=preview.damage.max_damage,"damage outside range")
			check(received>=mini(actor_hp,preview.incoming.min_damage) and received<=preview.incoming.max_damage,"retaliation outside range")
			var lost:int=target_count-BattleRules._alive_count(d)
			var own_lost:int=actor_count-BattleRules._alive_count(a)
			check(lost>=preview.damage.min_units and lost<=preview.damage.max_units,"target losses outside range")
			check(own_lost>=preview.incoming.min_units and own_lost<=preview.incoming.max_units,"own losses outside range")
			if mode=="spent":check(preview.incoming.max_damage==0,"spent retaliation advertised")
	var s=fixture()
	var saved:Dictionary=s.to_dict().duplicate(true)
	var movement:Dictionary=BattleRules.advance_consequence_preview(s.battle)
	check(movement.ok and s.to_dict()==saved,"advance preview illegal or mutating")
	var mover:Dictionary=BattleRules.get_active_stack(s.battle)
	var moved:Dictionary=BattleRules.perform_player_action(s,"advance")
	check(moved.ok and mover.hex==movement.destination,"advance commitment differs from preview")
	s.from_dict(saved)
	check(not BattleRules.attack_consequence_preview(s.battle,"strike","gone").ok,"missing target accepted")
	s.battle.stacks[0].speed=1
	check(not BattleRules.attack_consequence_preview(s.battle,"strike",s.battle.selected_target_id).ok,"unreachable target accepted")
	s.from_dict(saved)
	s.battle.turn_index=1
	s.battle.active_stack_id=s.battle.stacks[1].battle_id
	check(BattleRules.upcoming_actor_ids(s.battle)[0]==s.battle.active_stack_id,"initiative starts with already-acted stack")
	s.battle.stacks[2].total_health=0
	check(BattleRules.upcoming_actor_ids(s.battle).size()==1,"initiative includes dead stack")
	s.from_dict(saved)
	var ally:Dictionary=s.battle.stacks[0].duplicate(true)
	ally.battle_id="spell_preview_ally"
	ally.hex={"q":0,"r":0}
	s.battle.stacks.append(ally)
	s.battle.turn_order.insert(1,ally.battle_id)
	BattleRules._sync_occupied_hexes(s.battle)
	var spells:Array=BattleRules.get_spell_actions(s)
	for action in spells:
		var before:Dictionary=s.to_dict().duplicate(true)
		var preview:Dictionary=BattleRules.spell_consequence_preview(s,String(action.id).trim_prefix("cast_spell:"))
		check(s.to_dict()==before,"spell preview mutated state/RNG/mana")
		check(bool(preview.ok)==not bool(action.get("disabled",false)),"spell preview legality differs from action")
		if not preview.ok:continue
		var copy=Store.new_session_data()
		copy.from_dict(before.duplicate(true))
		var target:Dictionary=BattleRules._get_stack_by_id(copy.battle,preview.target_id)
		var hp:int=target.total_health
		var cast:Dictionary=BattleRules.cast_player_spell(copy,String(action.id).trim_prefix("cast_spell:"))
		check(cast.ok,"previewed spell cannot cast")
		if int(preview.damage)>0:
			check(hp-int(target.total_health)==mini(hp,int(preview.damage)),"spell damage differs from forecast")

func capture_consequence(shell,session)->void:
	var before:Dictionary=session.to_dict().duplicate(true)
	shell._preview_combat_action("strike")
	check(shell._battle_board_view._consequence_preview.ok,"visible strike consequence absent")
	check(session.to_dict()==before,"hover commits combat")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("consequence-approach.png"))
	var elapsed:int=Time.get_ticks_usec()
	for i in range(20):BattleRules.attack_consequence_preview(session.battle,"strike",session.battle.selected_target_id)
	print("CONSEQUENCE_PREVIEW_20_USEC "+str(Time.get_ticks_usec()-elapsed))
	for action in BattleRules.get_spell_actions(session):
		if bool(action.get("disabled",false)):continue
		shell._preview_combat_action(String(action.id))
		check(shell._battle_board_view._consequence_preview.ok,"spell button has no live preview")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("consequence-spell.png"))
		break
	check(session.to_dict()==before,"preview controls changed combat state")
	var board=shell._battle_board_view
	board.grab_focus()
	var target:Dictionary=BattleRules.get_selected_target(session.battle)
	board._controller_cursor_cell=Vector2i(int(target.hex.q),int(target.hex.r))
	board._sync_controller_cursor_preview()
	check(board._consequence_preview.get("target_id","")==target.battle_id,"controller cursor preview points at another target")
	var motion:=InputEventMouseMotion.new()
	motion.position=board._hex_center(Vector2i(int(target.hex.q),int(target.hex.r)),board._current_hex_layout())
	board._gui_input(motion)
	check(board._consequence_preview.get("target_id","")==target.battle_id,"mouse hover preview points at another target")
	check(session.to_dict()==before,"mouse/controller preview committed an order")
	board.release_focus()
	var original:Dictionary=session.battle.duplicate(true)
	for kind in ["adjacent","ranged"]:
		session.battle=original.duplicate(true)
		var a:Dictionary=BattleRules.get_active_stack(session.battle)
		a.hex={"q":4,"r":3}
		if kind=="ranged":
			a.ranged=true
			a.shots_remaining=8
		BattleRules._sync_occupied_hexes(session.battle)
		BattleRules._sync_distance_from_hexes(session.battle)
		board.set_battle_state(session)
		board.preview_attack("shoot" if kind=="ranged" else "strike",session.battle.selected_target_id)
		check(board._consequence_preview.ok,"missing "+kind+" preview")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("consequence-"+kind+".png"))
	session.battle=original
	board.set_battle_state(session)
	shell._battle_board_view.set_consequence_preview({})
	check(shell._battle_board_view._consequence_preview.is_empty(),"preview dismissal failed")
'''

SCRIPT = base.SCRIPT.replace('func run() -> void:', CHECKS+'\nfunc run() -> void:')
SCRIPT = SCRIPT.replace('out=OS.get_environment("BATTLE_READABILITY_OUT")',
                        'out=OS.get_environment("BATTLE_READABILITY_OUT")\n\tconsequence_checks()')
SCRIPT = SCRIPT.replace('var clicked: Dictionary=shell._on_board_stack_focus_requested',
                        'await capture_consequence(shell,rendered)\n\t\tvar clicked: Dictionary=shell._on_board_stack_focus_requested')

if __name__ == '__main__':
    base.OUTPUT = OUTPUT
    base.SCRIPT = SCRIPT
    raise SystemExit(base.main())
