#!/usr/bin/env python3
"""Runtime body/clip/corpse acceptance, NOT completion of new-art roster coverage."""
import os
import sys
import battle_readability_regression as runner

ROOT = runner.ROOT
OUTPUT = ROOT / '.artifacts/battle-unit-animation-size-20260913'
run_probe = runner.run_probe
probe_environment = runner.probe_environment
COMPILED_OWNERS = ('scenes/battle/BattleBoardView.gdc', 'scripts/ui/BattleUnitPose.gdc',
                  'scripts/core/BattleFootprint.gdc', 'scripts/core/BattleRules.gdc',
                  'scripts/core/BattleAiRules.gdc')
SCRIPT = runner.SCRIPT.split('func _ready()')[0] + r'''
const Body=preload("res://scripts/core/BattleFootprint.gd")
const Pose=preload("res://scripts/ui/BattleUnitPose.gd")
const AI=preload("res://scripts/core/BattleAiRules.gd")
func _ready()->void: call_deferred("run")
func wide_fixture():
	var session=fixture()
	var stack:Dictionary=BattleRules._build_battle_stack("unit_embercourt_sluicefire_lindworms",3,"player",0)
	stack.battle_id=session.battle.stacks[0].battle_id
	stack.hex={"q":4,"r":3}
	stack.abilities=[]
	session.battle.stacks[0]=stack
	session.battle.stacks[1].hex={"q":2,"r":3}
	session.battle.stacks[2].hex={"q":8,"r":3}
	BattleRules._ensure_battle_hex_state(session.battle)
	BattleRules._sync_distance_from_hexes(session.battle)
	return session
func capture(name:String,requested:Vector2i)->void:
	if DisplayServer.get_name()=="headless": return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	check(image.get_size()==requested,"incorrect viewport dimensions")
	image.save_png(out.path_join(name+".png"))
func capture_idle_phase(board:Control,stack:Dictionary,animation:Dictionary,phase:int,requested:Vector2i):
	# A nominal SceneTreeTimer delay starts within a render frame and PNG work
	# consumes wall time. It cannot prove two distinct displayed idle phases.
	# Observe real wall-clock phase away from its boundary; never rebase the
	# game's idle clock or change its authored timing to obtain a screenshot.
	var spec:Dictionary=Pose.clip(animation,"idle_hold")
	var frame_ms:=maxi(1,int(spec.get("frame_msec",150)))
	var target:Rect2=Pose.region(animation,"idle_hold",1.0,phase*frame_ms,false)
	var deadline:=Time.get_ticks_msec()+frame_ms*maxi(2,int(spec.get("frames",2)))*4+2000
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		var tick:=Time.get_ticks_msec()
		var within_frame:=float(tick%frame_ms)/float(frame_ms)
		if within_frame<0.2 or within_frame>0.65:continue
		if board._animation_frame_region_for_stack(stack)!=target:continue
		await RenderingServer.frame_post_draw
		if board._animation_frame_region_for_stack(stack)!=target:continue
		var image:=get_viewport().get_texture().get_image()
		check(image.get_size()==requested,"idle capture size mismatch")
		return {"image":image,"region":str(target),"tick_msec":Time.get_ticks_msec()}
	check(false,"idle phase never rendered: "+String(stack.unit_id)+" phase "+str(phase))
	return {}
func run()->void:
	out=OS.get_environment("BATTLE_READABILITY_OUT")
	var session=wide_fixture()
	var profiles:Dictionary=ContentService.load_json("res://content/unit_battle_size_manifest.json").units
	var roster:Array=ContentService.load_json("res://content/units.json").items
	check(profiles.size()==roster.size(),"size roster incomplete")
	for unit in roster:
		check(profiles.has(unit.id),"unit has no reviewed size: "+unit.id)
		var profiled:=BattleRules._build_battle_stack(unit.id,1,"player",0)
		check(profiled.battle_footprint==profiles[unit.id].footprint and is_equal_approx(profiled.battle_visual_scale,profiles[unit.id].visual_scale),"size profile not adopted: "+unit.id)
	var a:Dictionary=session.battle.stacks[0]
	var b:Dictionary=session.battle.stacks[1]
	check(Body.width(a)==2 and a.battle_visual_scale>1.0,"authored large profile not adopted")
	check(Body.cells(a)==[{"q":4,"r":3},{"q":3,"r":3}],"player body not behind anchor")
	var enemy:Dictionary=a.duplicate(true)
	enemy.side="enemy"
	check(Body.cells(enemy)==[{"q":4,"r":3},{"q":5,"r":3}],"enemy body not mirrored")
	var vector_legacy:Dictionary=a.duplicate(true)
	vector_legacy.hex=Vector2i(4,3)
	check(Body.cells(vector_legacy)==Body.cells(a),"legacy vector hex boundary changed")
	vector_legacy.hex={"x":4,"y":3}
	check(Body.cells(vector_legacy)==Body.cells(a),"legacy x/y hex boundary changed")
	for side in ["player","enemy"]:
		var body:Dictionary=a.duplicate(true)
		body.side=side
		for r in range(7):
			for q in range(11):
				var anchor:Dictionary={"q":q,"r":r}
				var expected:=q>0 if side=="player" else q<10
				check(Body.fits(body,anchor,{},11,7)==expected,"edge body accepted/clipped")
	var occupied:=BattleRules.battle_occupancy_map(session.battle)
	check(occupied["3,3"]==a.battle_id and occupied["4,3"]==a.battle_id,"rear cell absent from occupancy")
	check(BattleRules._stack_hex_distance(a,b)==1 and AI._stack_hex_distance(a,b)==1,"rules/AI ignore near body cell")
	check(BattleRules._can_make_melee_attack(a,session.battle,b),"adjacent rear-cell melee rejected")
	check(BattleRules._can_make_melee_attack(b,session.battle,a),"rear-cell target cannot be attacked")
	check(not Body.fits(a,{"q":3,"r":3},occupied,11,7),"rear body may overlap enemy")
	var before:Dictionary=session.to_dict().duplicate(true)
	for destination in BattleRules.legal_destinations_for_active_stack(session.battle):
		check(Body.fits(a,destination,occupied,11,7),"legal movement clips another stack")
		var path:=BattleRules._presentation_walk_path(session.battle,a.hex,destination)
		check(not path.is_empty() and path.size()-1<=a.speed,"missing/overlong actual body path")
		for cell in path: check(Body.fits(a,cell,occupied,11,7),"animation path clips body")
	check(session.to_dict()==before,"body queries mutate state")
	var pulled=wide_fixture()
	pulled.battle.stacks[0].hex={"q":5,"r":3}
	BattleRules._sync_occupied_hexes(pulled.battle)
	check(BattleRules._apply_hookline_pull(pulled.battle,pulled.battle.stacks[1],pulled.battle.stacks[0]),"two-cell defender cannot be pulled from body range two")
	var shifted:Dictionary=BattleRules._get_stack_by_id(pulled.battle,pulled.battle.stacks[0].battle_id)
	check(Body.distance(shifted,pulled.battle.stacks[1])==1 and Body.fits(shifted,shifted.hex,BattleRules.battle_occupancy_map(pulled.battle),11,7),"hookline clips or fails to reach whole body")
	var rejected_before:Dictionary=pulled.battle.duplicate(true)
	BattleRules._set_stack_hex(pulled.battle,shifted.battle_id,{"q":0,"r":3})
	check(pulled.battle==rejected_before,"direct relocation clips rear off board")
	var direct=Store.new_session_data()
	direct.from_dict(before.duplicate(true))
	var action:=BattleRules.perform_presented_action(session,"strike")
	var ordinary:=BattleRules.perform_player_action(direct,"strike")
	check(action.ok and ordinary.ok and session.to_dict()==direct.to_dict(),"large presented action diverges from ordinary rules")
	var opposing=wide_fixture()
	var large_enemy:=BattleRules._build_battle_stack("unit_embercourt_sluicefire_lindworms",8,"enemy",0)
	large_enemy.battle_id=opposing.battle.stacks[1].battle_id
	large_enemy.hex={"q":7,"r":3}
	large_enemy.speed=3
	large_enemy.abilities=[]
	opposing.battle.stacks[1]=large_enemy
	opposing.battle.stacks[2].hex={"q":9,"r":1}
	BattleRules._ensure_battle_hex_state(opposing.battle)
	BattleRules._sync_distance_from_hexes(opposing.battle)
	var opposing_direct=Store.new_session_data()
	opposing_direct.from_dict(opposing.to_dict().duplicate(true))
	var enemy_presented:=BattleRules.perform_presented_action(opposing,"defend")
	var enemy_ordinary:=BattleRules.perform_player_action(opposing_direct,"defend")
	check(enemy_presented.ok and enemy_ordinary.ok and opposing.to_dict()==opposing_direct.to_dict(),"large enemy turn playback differs from ordinary AI")
	for body in opposing.battle.get("stacks",[]):
		if BattleRules._alive_count(body)>0: check(Body.fits(body,body.hex,BattleRules.battle_occupancy_map(opposing.battle),11,7),"large enemy AI turn overlaps a body")
	var restored=Store.new_session_data()
	restored.from_dict(session.to_dict().duplicate(true))
	check(restored.to_dict()==session.to_dict(),"large stack save round trip changed state")
	check(BattleRules._normalize_stack(a).battle_footprint==2,"normalization drops large body")
	var legacy:Dictionary=a.duplicate(true)
	legacy.erase("battle_footprint")
	legacy.erase("battle_visual_scale")
	check(BattleRules._normalize_stack(legacy).battle_footprint==1,"legacy battle silently expands its body")
	var crowded=fixture()
	crowded.battle.stacks=[]
	for side in ["player","enemy"]:
		for i in range(7):
			var stack:=BattleRules._build_battle_stack("unit_embercourt_sluicefire_lindworms",2,side,i)
			stack.hex={"q":0,"r":0}
			crowded.battle.stacks.append(stack)
	BattleRules._ensure_battle_hex_state(crowded.battle)
	check(BattleRules.battle_occupancy_map(crowded.battle).size()==28,"crowded deployment loses/overlaps bodies")
	for stack in crowded.battle.stacks: check(Body.fits(stack,stack.hex,BattleRules.battle_occupancy_map(crowded.battle),11,7),"invalid crowded deployment")
	# Clip coordinates are metadata-driven; this synthetic layout tests indexing,
	# not acceptance of the rejected generator output or any roster art claim.
	var animation:Dictionary={"pose_sheet":"probe","pose_frame_size":{"width":256,"height":256},"pose_clips":{}}
	for i in range(Pose.REQUIRED_CLIPS.size()):
		animation.pose_clips[Pose.REQUIRED_CLIPS[i]]={"row":i,"frames":4,"loop":i==0 or i==1,"frame_msec":150,"static_frame":0}
	check(not Pose.facing_flip(animation,"player") and Pose.facing_flip(animation,"enemy"),"default right-facing pose reflection changed")
	animation.pose_source_facing="left"
	check(Pose.facing_flip(animation,"player") and not Pose.facing_flip(animation,"enemy"),"left-facing source does not orient both battle sides")
	check(not Pose.facing_flip({"pose_source_facing":"left"},"player"),"legacy art incorrectly uses pose-facing metadata")
	animation.erase("pose_source_facing")
	check(Pose.region(animation,"idle_hold",1.0,0,false)!=Pose.region(animation,"idle_hold",1.0,160,false),"idle does not cycle")
	check(Pose.region(animation,"move_path_step",0.2,0,true)==Pose.region(animation,"move_path_step",0.8,600,true),"reduced motion cycles")
	var normal_clock:Dictionary={"started_at_msec":1000,"max_duration_ms":700,"base_duration_ms":700}
	var fast_clock:Dictionary={"started_at_msec":1000,"max_duration_ms":294,"base_duration_ms":700}
	check(Pose.elapsed_msec({},1234)==1234,"idle wall clock lost")
	check(not Pose.waiting_for_start({},999),"idle is treated as a queued reaction")
	check(Pose.waiting_for_start(normal_clock,999),"reaction starts before its deadline")
	check(not Pose.waiting_for_start(normal_clock,1000),"reaction still held at its deadline")
	check(not Pose.waiting_for_start(normal_clock,1100),"running reaction treated as pending")
	check(not Pose.waiting_for_start({"max_duration_ms":700},999),"legacy record without start time delayed")
	check(Pose.elapsed_msec(normal_clock,800)==0,"queued event animated before start")
	check(Pose.elapsed_msec(normal_clock,1000)==0,"event starts midway through global cycle")
	check(Pose.elapsed_msec(normal_clock,1350)==350,"normal event clock drift")
	check(Pose.elapsed_msec(fast_clock,1147)==350,"fast movement legs do not follow travel speed")
	check(Pose.elapsed_msec({"started_at_msec":1000,"max_duration_ms":700},1350)==350,"legacy presentation record clock incompatible")
	check(Pose.region(animation,"move_path_step",0.5,Pose.elapsed_msec(normal_clock,1350),false)==Pose.region(animation,"move_path_step",0.5,Pose.elapsed_msec(fast_clock,1147),false),"speed changes stride phase at equal action progress")
	check(Pose.region(animation,"death_rout_remove",1.0,0,false,true)==Rect2(0,1280,256,256),"corpse not dedicated final row")
	var packed:Dictionary={"pose_frame_size":{"width":512,"height":256},"pose_columns":4,"pose_clips":{"attack":{"frames":3,"indices":[6,7,8]}}}
	check(Pose.region(packed,"melee_windup_release",1.0,0,false)==Rect2(0,512,512,256),"packed attack fails to cross atlas row")
	check(Pose.grounded_rect(Vector2(300,400),100,Rect2(0,0,512,256))==Rect2(200,300,200,100),"rectangular pose distorts or loses ground anchor")
	var anchored:=Pose.grounded_rect(Vector2(300,400),128,Rect2(512,256,512,256),{"pose_ground_margin":20})
	check(anchored==Rect2(172,282,256,128),"authored padding lifts the anatomical ground anchor")
	check(is_equal_approx(anchored.position.y+(256.0-20.0)*0.5,400.0),"authored ground line does not meet battlefield ground")
	check(Pose.grounded_rect(Vector2(300,400),256,Rect2(0,0,512,256),{"pose_ground_margin":20})==Rect2(44,164,512,256),"ground anchor changes with visual scale")
	var live=SessionState.set_active_session(wide_fixture())
	var shell=load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(shell)
	for i in range(8): await get_tree().process_frame
	var dimensions:=OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
	var requested:=Vector2i(int(dimensions[0]),int(dimensions[1]))
	if OS.get_environment("BATTLE_POSE_RESTING_SAMPLES")=="1":
		# The pixel comparison below isolates the sprite in this small-screen
		# fixture. Reject other sizes rather than comparing an unrelated ROI.
		check(requested==Vector2i(1280,720),"roster resting samples require 1280x720")
	# Accessibility toggles reapply all SettingsService presentation fields.
	# Persist the requested size in this disposable probe profile so later
	# reduced-motion tests cannot silently restore the release's default size.
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution(OS.get_environment("TOWN_OVERLAY_RESOLUTION"))
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(requested)
	get_tree().root.size=requested
	get_tree().root.content_scale_size=requested
	for i in range(4): await get_tree().process_frame
	var board:Control=shell._battle_board_view
	check(board._stack_id_at_cell(Vector2i(3,3))==live.battle.stacks[0].battle_id,"rear hex UI lookup fails")
	check(board._stack_standee_size(32,live.battle.stacks[0]).y>board._stack_standee_size(32,live.battle.stacks[1]).y,"large sprite not larger")
	await capture("large-body",requested)
	# Isolated clip fixture exercises corpse ownership without accepting any
	# production art. Reset borrowed-content indexes before replacing the domain.
	var original_manifest:Dictionary=ContentService.load_json(ContentService.UNIT_ANIMATION_PATH).duplicate(true)
	var fixture_manifest:Dictionary=original_manifest.duplicate(true)
	for row in fixture_manifest.items:
		if row.unit_id==live.battle.stacks[0].unit_id:
			row.pose_sheet=row.sprite_sheet
			row.pose_frame_size={"width":64,"height":64}
			row.pose_clips={"dead":{"row":6,"column":3,"frames":1}}
			row.pose_source_facing="left"
	ContentService.clear_cache()
	ContentService._cache[ContentService.UNIT_ANIMATION_PATH]=fixture_manifest
	live.battle.stacks[0].total_health=0
	BattleRules._sync_occupied_hexes(live.battle)
	board.finish_action_playback(live)
	var corpses:Array=board._battle_corpse_entries(board._current_hex_layout())
	check(corpses.size()==1 and corpses[0].region.has_area(),"dead sprite disappears after event expiry")
	check(corpses.size()==1 and corpses[0].flip,"left-facing player corpse not reflected with live art")
	check(board._stack_id_at_cell(Vector2i(3,3))=="" and board._stack_id_at_cell(Vector2i(4,3))=="","corpse owns input or occupancy")
	check(not BattleRules.battle_occupancy_map(live.battle).has("3,3"),"dead rear remains occupied")
	# No screenshot of a fixture corpse is presented as production artwork.
	var resumed=Store.new_session_data()
	resumed.from_dict(live.to_dict().duplicate(true))
	board.finish_action_playback(resumed)
	check(board._battle_corpse_entries(board._current_hex_layout()).size()==1,"save/resume loses corpse")
	resumed.battle.stacks[0].total_health=100
	board.finish_action_playback(resumed)
	check(board._battle_corpse_entries(board._current_hex_layout()).is_empty(),"revived stack also draws a corpse")
	ContentService.clear_cache()
	ContentService._cache[ContentService.UNIT_ANIMATION_PATH]=original_manifest
	var river=fixture()
	var river_stack:=BattleRules._build_battle_stack("unit_river_guard",10,"player",0)
	river_stack.battle_id=river.battle.stacks[0].battle_id
	river_stack.hex={"q":4,"r":3}
	river.battle.stacks[0]=river_stack
	BattleRules._sync_occupied_hexes(river.battle)
	board.finish_action_playback(river)
	var river_animation:=ContentService.get_unit_animation("unit_river_guard")
	check(board._stack_token_art_source(river_stack)=="event_animation_sheet","original idle pose not used in normal battle")
	# Two same-unit presentation actors must not share the application's loop
	# phase. Compare away from frame boundaries so real render ticks are safe.
	var prior_reduced_motion:=SettingsService.reduced_motion_enabled()
	SettingsService.set_reduced_motion_enabled(false)
	var phase_actor:Dictionary=river_stack.duplicate(true)
	phase_actor.battle_id="independent_pose_clock"
	var clock_now:=Time.get_ticks_msec()
	for item in [[river_stack.battle_id,40],[phase_actor.battle_id,210]]:
		board._stack_animation_playback_records[item[0]]={"state":"move_path_step","started_at_msec":clock_now-int(item[1]),"max_duration_ms":700,"base_duration_ms":700}
		board._stack_animation_playback_until_msec[item[0]]=clock_now+2000
	check(board._animation_frame_region_for_stack(river_stack)!=board._animation_frame_region_for_stack(phase_actor),"live event loops still share global application phase")
	SettingsService.set_reduced_motion_enabled(true)
	check(board._animation_frame_region_for_stack(river_stack)==board._animation_frame_region_for_stack(phase_actor),"event clock animates reduced-motion poses")
	SettingsService.set_reduced_motion_enabled(prior_reduced_motion)
	board._stack_animation_playback_records.clear()
	board._stack_animation_playback_until_msec.clear()
	# A future event keeps its corpse lifetime but must not show an early hit,
	# kneel, lunge or VFX. Mutate only the copied display snapshot, never saves.
	var committed_before_wait:Dictionary=river.to_dict().duplicate(true)
	var waiting_snapshot:Dictionary=river.battle.duplicate(true)
	waiting_snapshot.active_stack_id=waiting_snapshot.stacks[1].battle_id
	board.set_battle_presentation_snapshot(waiting_snapshot)
	var waiting_actor:Dictionary=board._battle.stacks[0]
	var waiting_id:String=waiting_actor.battle_id
	var waiting_layout:Dictionary=board._current_hex_layout()
	var waiting_cells:Dictionary={waiting_id:Vector2i(4,3),"queued_source":Vector2i(7,3)}
	for pair in [["battle_unit_hit","hit_stagger"],["battle_unit_death","death_rout_remove"],["battle_retaliation","retaliation_release"]]:
		var waiting_clock:int=Time.get_ticks_msec()
		var queued:Dictionary={"battle_id":waiting_id,"event_id":pair[0],"state":pair[1],"source_battle_id":"queued_source","target_battle_id":"queued_source","started_at_msec":waiting_clock+60000,"max_duration_ms":700,"base_duration_ms":700,"selected_vfx_cue_ids":["vfx_placeholder_damage_tick"]}
		board._stack_animation_playback_records[waiting_id]=queued
		board._stack_animation_playback_until_msec[waiting_id]=waiting_clock+60700
		board._stack_animation_cue_playback_records[waiting_id]=queued.duplicate(true)
		waiting_actor.total_health=0 if pair[0]=="battle_unit_death" else 100
		for reduced in [false,true]:
			SettingsService.set_reduced_motion_enabled(reduced)
			waiting_actor.defending=true
			check(board._animation_state_for_stack(waiting_actor)=="defend_brace","queued reaction replaces held guard: "+pair[0])
			# A looping guard keeps its resting clock, whereas a one-shot guard
			# holds progress 1. Sample either side of the call to avoid a clock
			# boundary flake; elapsed zero would falsely freeze the guard loop.
			var before_guard_sample:int=Time.get_ticks_msec()
			var held_guard:Rect2=board._animation_frame_region_for_stack(waiting_actor)
			var after_guard_sample:int=Time.get_ticks_msec()
			check(held_guard in [Pose.region(river_animation,"defend_brace",1.0,before_guard_sample,reduced),Pose.region(river_animation,"defend_brace",1.0,after_guard_sample,reduced)],"queued reaction does not preserve the resting guard clock")
			check(board._stack_presentation_motion(waiting_actor,Vector2i(4,3),waiting_layout,waiting_cells).is_empty(),"queued reaction displaces body before contact")
			check(board._vfx_draw_entries(waiting_layout,waiting_cells).is_empty(),"queued reaction exposes VFX before contact")
			check(board._stack_visible_for_presentation(waiting_actor),"pending casualty disappears before death playback")
			check(board._battle_corpse_entries(waiting_layout).is_empty(),"pending casualty already draws final corpse")
			waiting_actor.defending=false
			check(board._animation_state_for_stack(waiting_actor)=="idle_hold","queued unbraced reaction is not idle")
		queued.started_at_msec=Time.get_ticks_msec()-100
		board._stack_animation_cue_playback_records[waiting_id].started_at_msec=queued.started_at_msec
		check(board._animation_state_for_stack(waiting_actor)==pair[1],"due reaction does not start")
		check(not board._stack_presentation_motion(waiting_actor,Vector2i(4,3),waiting_layout,waiting_cells).is_empty(),"due reaction motion stays suppressed")
	# Future movement holds at the source, not the authoritative destination.
	board._stack_animation_playback_records[waiting_id]={"event_id":"battle_unit_move","state":"move_path_step","started_at_msec":Time.get_ticks_msec()+60000,"from_q":3,"from_r":3,"to_q":4,"to_r":3}
	var queued_move:Dictionary=board._stack_presentation_motion(waiting_actor,Vector2i(4,3),waiting_layout,waiting_cells)
	var source_center:Vector2=board._hex_center(Vector2i(3,3),waiting_layout)
	check(Vector2(queued_move.center_x,queued_move.center_y).distance_to(source_center)<0.02,"queued move waits at destination instead of source")
	SettingsService.set_reduced_motion_enabled(prior_reduced_motion)
	check(river.to_dict()==committed_before_wait,"pending-pose sampling changed committed battle/save state")
	board.finish_action_playback(river)
	for state in ["idle_hold","move_path_step","melee_windup_release","defend_brace","death_rout_remove"]:
		check(Pose.region(river_animation,state,0.5,180,false).has_area(),"missing candidate state: "+state)
	await capture("river-guard-idle",requested)
	river_stack.total_health=0
	BattleRules._sync_occupied_hexes(river.battle)
	board.finish_action_playback(river)
	check(board._battle_corpse_entries(board._current_hex_layout()).size()==1,"generated River Guard corpse missing")
	await capture("river-guard-dead",requested)
	var unit_count:=0
	var enabled_pose_count:=0
	var reviewed_pose_count:=0
	var resting_captures:=0
	var resting_samples:=[]
	var capture_resting:=OS.get_environment("BATTLE_POSE_RESTING_SAMPLES")=="1" and DisplayServer.get_name()!="headless"
	for unit in ContentService.load_json("res://content/units.json").items:
		var stack:=BattleRules._build_battle_stack(unit.id,0,"player",0)
		stack.hex={"q":4,"r":3}
		board.set_battle_presentation_snapshot({"stacks":[stack]})
		var mapped:=ContentService.get_unit_animation(unit.id)
		if Pose.has_authored_poses(mapped):
			check(board._battle_corpse_entries(board._current_hex_layout()).size()==1,"authored corpse missing: "+unit.id)
			if capture_resting:
				# The action replay correctly allows survivors onto a casualty's
				# freed cell, which can obscure its final pose. Inspect every
				# actual corpse alone, plus two real-time idle phases, in the
				# existing small-screen packaged acceptance pass.
				await capture(unit.id+"-resting-dead",requested)
				var living:=BattleRules._build_battle_stack(unit.id,2,"player",0)
				living.hex={"q":4,"r":3}
				board.set_battle_presentation_snapshot({"stacks":[living]})
				check(board._battle_corpse_entries(board._current_hex_layout()).is_empty(),"living resting sample draws a corpse: "+unit.id)
				check(board._animation_state_for_stack(living)=="idle_hold","resting sample does not use idle: "+unit.id)
				var idle_a:Dictionary=await capture_idle_phase(board,living,mapped,0,requested)
				var idle_b:Dictionary=await capture_idle_phase(board,living,mapped,1,requested)
				if not idle_a.is_empty() and not idle_b.is_empty():
					check(idle_a.region!=idle_b.region,"real-time idle repeats the same authored frame: "+unit.id)
					check(idle_a.image.get_region(Rect2i(400,140,400,190)).get_data()!=idle_b.image.get_region(Rect2i(400,140,400,190)).get_data(),"displayed idle phases are pixel-identical: "+unit.id)
					idle_a.image.save_png(out.path_join(unit.id+"-resting-idle-a.png"))
					idle_b.image.save_png(out.path_join(unit.id+"-resting-idle-b.png"))
					idle_a.erase("image")
					idle_b.erase("image")
					resting_samples.append({"unit_id":unit.id,"idle_a":idle_a,"idle_b":idle_b})
					resting_captures+=3
			enabled_pose_count+=1
			if String(mapped.get("pose_review_status", "")).begins_with("accepted_playback_"):
				reviewed_pose_count+=1
		else:
			check(board._battle_corpse_entries(board._current_hex_layout()).is_empty(),"unapproved legacy affine corpse exposed: "+unit.id)
			unit_count+=1
	shell.queue_free()
	for i in range(3): await get_tree().process_frame
	# The fast probe exits during the entry stinger. Stop audio explicitly and
	# let the audio mixer release playbacks before terminating its test tree.
	MusicAudio.stop_stinger()
	MusicAudio.stop_music("unit_body_probe_teardown")
	await get_tree().create_timer(0.15).timeout
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"legacy_corpse_units_rejected":unit_count,"new_pose_roster_enabled":enabled_pose_count,"resting_captures":resting_captures,"resting_samples":resting_samples,"new_pose_roster_accepted":reviewed_pose_count,"scope":"runtime, footprint and pose routing; accepted count reads manifest review metadata, not automatic visual certification"}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''

def main():
    if '--roster-resting-samples' in sys.argv:
        os.environ['BATTLE_POSE_RESTING_SAMPLES'] = '1'
        sys.argv.remove('--roster-resting-samples')
    if '--platform' in sys.argv:
        import packaged_menu_and_turn_readability_regression as package
        package.ui = sys.modules[__name__]
        return package.main()
    runner.ROOT, runner.OUTPUT, runner.SCRIPT = ROOT, OUTPUT, SCRIPT
    runner.run_probe, runner.probe_environment = run_probe, probe_environment
    return runner.main()

if __name__ == '__main__':
    raise SystemExit(main())
