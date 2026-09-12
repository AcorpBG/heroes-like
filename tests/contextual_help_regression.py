#!/usr/bin/env python3
"""Exercise real bounded tooltip controls and explicit inspection lifecycle."""
import battle_readability_regression as base

OUTPUT = base.ROOT / '.artifacts/contextual_help_20260912'
SCRIPT = base.SCRIPT.split('func _ready()')[0] + r'''
func _ready()->void:
	call_deferred("run_help")
func run_help()->void:
	out=OS.get_environment("BATTLE_READABILITY_OUT")
	var dimensions=OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
	var requested:=Vector2i(int(dimensions[0]),int(dimensions[1]))
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(requested)
	get_tree().root.size=requested
	get_tree().root.content_scale_size=requested
	var help=get_node("/root/ContextualHelp")
	var button=Button.new()
	button.text="Inspect construction"
	button.tooltip_text="Riverwatch construction\nA long account of requirements, effects, costs and prerequisites. "+"Additional explanatory text. ".repeat(160)
	add_child(button)
	button.position=Vector2(24,24)
	button.size=Vector2(210,40)
	await get_tree().process_frame
	check(button.get_script()!=null,"scriptless button did not acquire bounded tooltip")
	check(button.has_method("_make_custom_tooltip"),"bounded tooltip method missing")
	check(button._make_custom_tooltip("  \n")==null,"empty text created a phantom hover popup")
	var original:String=button.tooltip_text
	if DisplayServer.get_name()!="headless": Input.warp_mouse(Vector2(40,40))
	var enter=InputEventMouseMotion.new()
	enter.position=Vector2(40,40)
	get_viewport().push_input(enter)
	var suppress:Control=button._make_custom_tooltip(original)
	check(not suppress.visible,"native tooltip popup was not suppressed")
	suppress.free()
	var card:Control=help._hover_card.get_ref()
	var minimum:Vector2=card.get_combined_minimum_size()
	check(minimum.x<=380 and minimum.y<=150,"hover surface unbounded")
	check(card.get_child(0).get_node("Summary").max_lines_visible==3,"hover summary must use three visible lines")
	check(card.mouse_filter==Control.MOUSE_FILTER_IGNORE,"hover intercepts clicks")
	check(button.tooltip_text==original,"summary overwrote authoritative detail")
	check(help.summary_text(original).length()<=240,"summary exceeded text bound")
	check(help.inspect_control(button),"explicit inspect unavailable")
	await get_tree().process_frame
	check(not is_instance_valid(card) or not card.visible,"inspect did not dismiss hover")
	check(help._detail.visible,"inspection dialog hidden")
	check(help._detail_text.text==original,"full detail lost")
	var scroll=InputEventAction.new()
	scroll.action="ui_down"
	scroll.pressed=true
	help._detail_input(scroll)
	await get_tree().process_frame
	check(help._detail_text.get_v_scroll_bar().value>0,"controller inspection cannot scroll long detail")
	check(help._detail.size.x<get_viewport().get_visible_rect().size.x,"detail clips horizontal viewport")
	check(help._detail.size.y<get_viewport().get_visible_rect().size.y,"detail clips vertical viewport")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out+"/explicit-inspection.png")
	var cancel=InputEventAction.new()
	cancel.action="ui_cancel"
	cancel.pressed=true
	help._detail_input(cancel)
	check(not help._detail.visible,"controller cancel did not dismiss inspection")
	help.inspect_control(button)
	button.hide()
	await get_tree().process_frame
	check(not help._detail.visible,"hidden owner retained inspection")
	button.show()
	help.inspect_control(button)
	var other=AcceptDialog.new()
	add_child(other)
	other.popup_centered()
	check(not help._detail.visible,"new modal retained previous inspection")
	other.hide()
	other.queue_free()
	var modal=AcceptDialog.new()
	var modal_button=Button.new()
	modal_button.text="Modal control"
	modal_button.tooltip_text="Details belonging to the focused modal control."
	modal.add_child(modal_button)
	add_child(modal)
	modal.popup_centered(Vector2i(600,500))
	modal_button.grab_focus()
	var inspect=InputEventJoypadButton.new()
	inspect.button_index=JOY_BUTTON_BACK
	inspect.pressed=true
	modal.window_input.emit(inspect)
	await get_tree().process_frame
	check(help._detail.visible and help._detail.get_parent()==modal and help._detail_text.text==modal_button.tooltip_text,"modal controller inspection used the wrong viewport")
	help._detail.window_input.emit(cancel)
	check(not help._detail.visible and modal.visible,"inspection dismissal closed its parent modal")
	modal.hide()
	modal.queue_free()
	await get_tree().process_frame
	var choices=ItemList.new()
	choices.size=Vector2(240,100)
	choices.position=Vector2(400,20)
	add_child(choices)
	choices.add_item("First destination")
	choices.add_item("Second destination")
	choices.set_item_tooltip(0,"First destination details")
	choices.set_item_tooltip(1,"Second destination details")
	choices.select(1)
	check(help.inspect_control(choices,true) and help._detail_text.text=="Second destination details","keyboard inspection ignored selected list row")
	help.dismiss()
	choices.queue_free()
	if is_instance_valid(card): card.queue_free()
	var shell=load("res://scenes/battle/BattleShell.tscn").instantiate()
	var session=fixture()
	SessionState.set_active_session(session)
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var board:Control=shell._battle_board_view
	check(board.has_method("_make_custom_tooltip"),"Battle board not bounded")
	board.grab_focus()
	var before_inspection:Dictionary=SessionState.ensure_active_session().to_dict().duplicate(true)
	check(help.inspect_control(board,true),"focused board has no inspection")
	check(help._detail_text.text==board.contextual_inspection_text(),"controller inspection uses mouse location")
	check(SessionState.ensure_active_session().to_dict()==before_inspection,"inspection changed gameplay state")
	board.set_battle_state(SessionState.ensure_active_session())
	await get_tree().process_frame
	check(not help._detail.visible,"updated battle snapshot retained stale details")
	help.dismiss()
	for point in [Vector2(12,12),Vector2(get_viewport().get_visible_rect().size.x-220,get_viewport().get_visible_rect().size.y-60)]:
		if DisplayServer.get_name()!="headless":
			Input.warp_mouse(Vector2(640,360))
			var leave=InputEventMouseMotion.new()
			leave.position=Vector2(640,360)
			Input.parse_input_event(leave)
			await get_tree().process_frame
			await get_tree().process_frame
		var edge_button=Button.new()
		edge_button.text="Inspect construction"
		edge_button.tooltip_text=original
		add_child(edge_button)
		edge_button.size=Vector2(210,40)
		edge_button.position=point
		if DisplayServer.get_name()!="headless":
			Input.warp_mouse(point+Vector2(15,15))
			var motion=InputEventMouseMotion.new()
			motion.position=point+Vector2(15,15)
			Input.parse_input_event(motion)
			await get_tree().create_timer(2.0).timeout
			var live=help._hover_card.get_ref() if help._hover_card!=null else null
			check(is_instance_valid(live),"real hover did not create card at "+str(point))
			if is_instance_valid(live):
				check(live.size.x<=380 and live.size.y<=150 and live.size.y>=40,"hover card is blank or grew past bounds")
				check(get_viewport().get_visible_rect().encloses(live.get_global_rect()),"hover card escaped game viewport")
				await RenderingServer.frame_post_draw
				var captured=get_viewport().get_texture().get_image()
				check(captured.get_size()==requested,"capture did not use requested viewport")
				captured.save_png(out+"/edge-%d.png"%int(point.x))
			help.dismiss()
		edge_button.queue_free()
		await get_tree().process_frame
	button.queue_free()
	shell.reparent(get_tree().root)
	get_tree().current_scene=shell
	var world=ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	world=SessionState.set_active_session(world)
	get_tree().change_scene_to_file("res://scenes/overworld/OverworldShell.tscn")
	await get_tree().scene_changed
	for i in range(3): await get_tree().process_frame
	var field=get_tree().current_scene
	check(help.inspect_control(field._end_turn_button),"Overworld control has no full inspection")
	check(help._detail.visible,"Overworld inspection not visible")
	var town_id:=""
	for town in world.overworld.towns:
		if town.owner=="player": town_id=town.placement_id;break
	check(town_id!="","owned town fixture absent")
	var visit:Dictionary=OverworldRules.set_active_town_visit(world,town_id)
	check(visit.ok,"town visit rejected")
	AppRouter.go_to_town()
	await get_tree().scene_changed
	for i in range(3): await get_tree().process_frame
	check(not help._detail.visible,"Overworld-to-Town retained stale inspection")
	var town_shell=get_tree().current_scene
	check(help.inspect_control(town_shell._build_action_button),"Town construction has no inspection")
	town_shell._on_open_build_catalog_pressed()
	check(not help._detail.visible,"construction ledger retained stale inspection")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out+"/town-ledger.png")
	SessionState.set_active_session(fixture())
	get_tree().change_scene_to_file("res://scenes/battle/BattleShell.tscn")
	await get_tree().scene_changed
	for i in range(3): await get_tree().process_frame
	var fresh_owner=help._hover_owner.get_ref() if help._hover_owner!=null else null
	check((fresh_owner==null or fresh_owner==get_tree().current_scene or get_tree().current_scene.is_ancestor_of(fresh_owner)) and help._detail_owner==null,"Town-to-Battle retained obsolete UI")
	SessionState.set_active_session(world)
	AppRouter.go_to_overworld()
	await get_tree().scene_changed
	for i in range(3): await get_tree().process_frame
	field=get_tree().current_scene
	var hero:Dictionary=SessionState.ensure_active_session().overworld.hero
	check(field._minimap.has_method("_make_custom_tooltip"),"minimap bypasses shared help")
	check(field._resource_label.has_method("_make_custom_tooltip"),"resource stockpile bypasses shared help")
	field.validation_hover_tile(int(hero.position.x),int(hero.position.y))
	check(help.inspect_control(field._map_view),"map tile has no explicit inspection")
	SessionState.set_active_session(fixture())
	get_tree().change_scene_to_file("res://scenes/battle/BattleShell.tscn")
	await get_tree().scene_changed
	for i in range(3): await get_tree().process_frame
	check(help._detail_owner==null and not help._detail.visible,"direct map-to-battle retained stale inspection")
	get_tree().current_scene.queue_free()
	for i in range(3): await get_tree().process_frame
	check(help._hover_owner==null and help._detail_owner==null,"removed owner retained UI")
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''

if __name__ == '__main__':
    base.OUTPUT = OUTPUT
    base.SCRIPT = SCRIPT
    original_run = base.run_probe
    def run_probe(command, env, log):
        if command[0] == 'xvfb-run':
            command = command[:1] + ['-s', '-screen 0 2880x1800x24'] + command[1:]
        return original_run(command, env, log)
    base.run_probe = run_probe
    raise SystemExit(base.main())
