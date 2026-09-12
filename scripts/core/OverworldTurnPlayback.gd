extends RefCounted

const KEY := "_live_turn_playback"
const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const Levels = preload("res://scripts/core/OverworldLevelRules.gd")

static func begin(session) -> void:
	session.overworld[KEY] = []

static func finish(session) -> Array:
	var records: Array = session.overworld.get(KEY, [])
	session.overworld.erase(KEY)
	return records

static func player_turn(session, config: Dictionary) -> void:
	if not session.overworld.has(KEY): return
	var controller := PlayerRules.controller_id(config)
	var identity := PlayerRules.player(session, controller)
	var faction := PlayerRules.faction_id(session, controller)
	var name := String(ContentService.get_faction(faction).get("name",faction))
	# Player id remains explicit even when multiple opponents share a faction.
	var label := String(identity.get("name",identity.get("player_id",controller))).replace("_"," ").capitalize()
	if identity.is_empty(): label=name
	var caption := name+" — AI turn" if label.to_lower()==name.to_lower() else "%s · %s — AI turn" % [label,name]
	session.overworld[KEY].append({"kind":"turn","player_id":controller,"faction_id":faction,"caption":caption})

static func visible(session, point: Dictionary) -> bool:
	return Levels.level_of(point) == Levels.view_level(session) and OverworldRules.is_tile_visible(session,int(point.get("x",-1)),int(point.get("y",-1)),Levels.level_of(point))

static func move(session, actor: Dictionary, before: Dictionary) -> void:
	if not session.overworld.has(KEY): return
	var after := Levels.position(actor)
	var from_visible := visible(session,before)
	var to_visible := visible(session,after)
	if not from_visible and not to_visible: return
	var kind := "move" if from_visible and to_visible and Levels.level_of(before)==Levels.level_of(after) else ("appear" if to_visible else "disappear")
	var safe_from := before if from_visible else after
	var safe_to := after if to_visible else before
	var visual := _visual_actor(actor,safe_to)
	var name := _actor_name(actor)
	session.overworld[KEY].append({"kind":kind,"actor":visual,"placement_id":String(actor.get("placement_id","")),"from":safe_from.duplicate(),"to":safe_to.duplicate(),"caption":name+({"move":" is moving","appear":" comes into view","disappear":" leaves explored ground"}[kind])})

static func _visual_actor(actor: Dictionary, point: Dictionary) -> Dictionary:
	# An allowlist prevents hidden targets, task scores or planned routes from
	# entering the presentation record, even as AI state gains new fields.
	var visual := {}
	for key in ["placement_id","encounter_id","name","spawned_by_faction_id","spawned_by_player_id"]:
		if actor.has(key): visual[key]=actor[key]
	var commander: Dictionary = actor.get("enemy_commander_state",{})
	visual["enemy_commander_state"]={"roster_hero_id":commander.get("roster_hero_id",""),"faction_id":commander.get("faction_id","")}
	visual.x=point.x
	visual.y=point.y
	visual.level=Levels.level_of(point)
	return visual

static func action(session, actor: Dictionary, verb: String) -> void:
	if not session.overworld.has(KEY) or not visible(session,Levels.position(actor)): return
	var point := Levels.position(actor)
	var cue := ""
	match verb:
		"claims a nearby site", "seizes a resource site": cue = "vfx_placeholder_capture_flag"
		"engages a defending army": cue = "vfx_placeholder_guard_warning"
	session.overworld[KEY].append({"kind":"action","actor":_visual_actor(actor,point),"placement_id":String(actor.get("placement_id","")),"from":point,"to":point.duplicate(),"caption":_actor_name(actor)+" "+verb,"vfx_cue_id":cue})

static func _actor_name(actor: Dictionary) -> String:
	var commander: Dictionary = actor.get("enemy_commander_state",{})
	var hero_id := String(commander.get("roster_hero_id",""))
	var hero := ContentService.get_hero(hero_id)
	return String(hero.get("name",actor.get("name","Enemy hero")))
