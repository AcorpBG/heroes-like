extends Node

## Portal networks on a real generated map (docs/portal-networks.md).
## Large land seed 1041912569 selects template 6LM10. Its generator places 17
## portal connections, so the 17th reuses two-way colour 0, and its zone 13
## link to itself is built twice as one-way networks that never leave that
## zone. The report drives the real package, session and overworld rules:
## one network per connection, dead-end networks left off, a random exit for
## portals with several, per-kind art and text, and the save migration.

const NativeTransit = preload("res://scripts/core/NativeTransitRules.gd")
const Bridge = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
const OverworldShellScene = preload("res://scenes/overworld/OverworldShell.tscn")
const REPORT_ID := "PORTAL_NETWORKS_REPORT"
const CAPTURE_DIR := "res://.artifacts/portal_networks"
const SITE_BY_KIND := {"two_way_portal": "site_wayring", "one_way_entrance": "site_waygate", "one_way_exit": "site_wayfall"}

var _failures := []
var _checks := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var config: Dictionary = ScenarioSelectRules.build_random_map_player_config("1041912569", "", "", 4, "land", false, "homm3_large", ScenarioSelectRules.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO, "faction_veilmourn", "hero_veilmourn_ivara_blacktide")
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": REPORT_ID})
	_check(String(generated.get("final_payload_fnv1a32", "")) == "cb90d9b8", "generation is unchanged: the final payload keeps FNV cb90d9b8")
	var objects: Array = generated.map_document.get_objects()
	var dead_ends := _check_package(objects)
	var adoption: Dictionary = service.convert_generated_payload(generated, {"feature_gate": REPORT_ID})
	var session = Bridge.build_session_from_adoption(adoption)
	if session == null:
		_finish("the generated map did not adopt into a session")
		return
	OverworldRules.normalize_overworld_state(session)
	session.overworld["encounters"] = []
	_check_session(session, dead_ends)
	_check_travel(session)
	_check_text(session)
	_check_migration(session, dead_ends)
	_check_art()
	await _check_rendering(session)
	_finish()

func _finish(fatal: String = "") -> void:
	if fatal != "":
		_failures.append(fatal)
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures}
	if _failures.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	else:
		push_error("%s failed: %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)

# --- package -------------------------------------------------------------------

func _check_package(objects: Array) -> Array:
	var portals := objects.filter(func(o): return o is Dictionary and int(o.get("h3m_type_id", -1)) in [43, 44, 45])
	_check(portals.size() == 50, "the map keeps all 50 generated portals (got %d)" % portals.size())
	var groups := {}
	var networks := {"two_way": {}, "one_way": {}}
	var dead_ends := []
	for portal in portals:
		var link := NativeTransit.link_of(portal)
		var type_id := int(portal.h3m_type_id)
		_check(int(link.get("connection_index", -1)) >= 0, "%s records its connection" % portal.placement_id)
		networks["two_way" if type_id == 45 else "one_way"][int(link.get("network_index", -1))] = true
		var group: Array = groups.get(String(link.get("group_id", "")), [])
		group.append(portal)
		groups[String(link.get("group_id", ""))] = group
		var expected_destinations: int = {45: 1, 43: 2, 44: 0}[type_id]
		_check(NativeTransit.destinations(portal).size() == expected_destinations, "%s has %d destination(s)" % [portal.placement_id, expected_destinations])
		if bool(link.get("same_zone", false)):
			dead_ends.append(portal)
	_check(networks.two_way.size() == 9 and networks.two_way.has(8), "the reused two-way colour becomes a ninth network (got %s)" % str(networks.two_way.keys()))
	_check(networks.one_way.size() == 8, "the eight one-way connections stay eight networks")
	for group_id in groups:
		var members: Array = groups[group_id]
		var two_way := int(members[0].h3m_type_id) == 45
		_check(members.size() == (2 if two_way else 4), "%s holds exactly one connection (%d ends)" % [group_id, members.size()])
	var dead_networks := {}
	for portal in dead_ends:
		dead_networks[NativeTransit.link_of(portal).group_id] = true
		_check(int(portal.h3m_type_id) in [43, 44] and NativeTransit.link_of(portal).connection_zones == [12, 12], "%s is a one-way end of the zone 12 self link" % portal.placement_id)
	_check(dead_ends.size() == 8 and dead_networks.size() == 2, "the self link's two one-way networks are flagged as dead ends (got %d ends)" % dead_ends.size())
	return dead_ends

# --- session -------------------------------------------------------------------

func _portal_nodes(session) -> Array:
	return session.overworld.get("resource_nodes", []).filter(func(n): return n is Dictionary and NativeTransit.portal_kind(n) != "")

func _check_session(session, dead_ends: Array) -> void:
	var nodes := _portal_nodes(session)
	_check(nodes.size() == 42, "dead-end networks are left off the map (42 portals, got %d)" % nodes.size())
	var counts := {}
	for node in nodes:
		var kind := NativeTransit.portal_kind(node)
		_check(String(node.get("site_id", "")) == SITE_BY_KIND[kind], "%s uses the %s art" % [node.placement_id, SITE_BY_KIND[kind]])
		counts[kind] = int(counts.get(kind, 0)) + 1
	_check(counts == {"two_way_portal": 18, "one_way_entrance": 12, "one_way_exit": 12}, "18 Wayrings, 12 Waygates, 12 Wayfalls (got %s)" % str(counts))
	_check(NativeTransit.validate(session.overworld.get("resource_nodes", [])).is_empty(), "every remaining portal contract is valid")
	var blocked: Dictionary = OverworldRules._blocked_tile_index(session, 0)
	for portal in dead_ends:
		var tile := Vector2i(int(portal.x), int(portal.y))
		_check(not blocked.has(OverworldRules._tile_key(tile)), "the dead-end tile %s is free ground" % str(tile))

# --- travel --------------------------------------------------------------------

func _node_by_id(session, placement_id: String) -> Dictionary:
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return node
	return {}

func _stand_at(session, node: Dictionary) -> void:
	var entry := NativeTransit.point(NativeTransit.link_of(node).get("entry"))
	OverworldRules._set_active_hero_position(session, Vector2i(entry.x, entry.y), entry.z)
	var top := int(session.overworld.get("movement", {}).get("max", 0))
	session.overworld["movement"] = {"current": top, "max": top}

func _hero_tile(session) -> Vector2i:
	return OverworldRules.hero_position(session)

func _check_travel(session) -> void:
	var nodes := _portal_nodes(session)
	var ring: Dictionary = nodes.filter(func(n): return NativeTransit.portal_kind(n) == "two_way_portal")[0]
	var twin := _node_by_id(session, String(NativeTransit.destinations(ring)[0].target_placement_id))
	_stand_at(session, ring)
	var result: Dictionary = OverworldRules.travel_native_passage(session, ring, 1)
	var twin_exit := NativeTransit.point(NativeTransit.destinations(ring)[0].exit)
	_check(bool(result.get("ok", false)) and _hero_tile(session) == Vector2i(twin_exit.x, twin_exit.y), "a Wayring sends the hero to its twin")
	_check(int(session.overworld.movement.current) == int(session.overworld.movement.max) - 1, "stepping through from the entrance costs one movement (left %s)" % str(session.overworld.movement))
	_check(String(result.get("message", "")).contains(OverworldRules.native_portal_display_name(ring)), "the travel message names the coloured portal")
	var back: Dictionary = OverworldRules.travel_native_passage(session, twin, 1)
	var ring_entry := NativeTransit.point(NativeTransit.link_of(ring).entry)
	_check(bool(back.get("ok", false)) and _hero_tile(session) == Vector2i(ring_entry.x, ring_entry.y), "and back again")

	var gate: Dictionary = nodes.filter(func(n): return NativeTransit.portal_kind(n) == "one_way_entrance")[0]
	var exits := {}
	for destination in NativeTransit.destinations(gate):
		var tile := NativeTransit.point(destination.exit)
		exits[Vector2i(tile.x, tile.y)] = String(destination.target_placement_id)
	var seen := {}
	for trip in range(16):
		_stand_at(session, gate)
		var trip_result: Dictionary = OverworldRules.travel_native_passage(session, gate, 1)
		_check(bool(trip_result.get("ok", false)) and exits.has(_hero_tile(session)), "Waygate trip %d lands on one of its Wayfalls" % trip)
		seen[_hero_tile(session)] = true
	_check(seen.size() == 2, "over 16 trips a Waygate uses both of its Wayfalls at random")
	_stand_at(session, gate)
	var trips: Dictionary = session.overworld.get(OverworldRules.NATIVE_TRANSIT_TRIPS_KEY, {}).duplicate(true)
	OverworldRules.travel_native_passage(session, gate, 1)
	var first := _hero_tile(session)
	_stand_at(session, gate)
	session.overworld[OverworldRules.NATIVE_TRANSIT_TRIPS_KEY] = trips
	OverworldRules.travel_native_passage(session, gate, 1)
	_check(_hero_tile(session) == first, "a reloaded trip replays the same random exit")

	var fall := _node_by_id(session, exits.values()[0])
	_stand_at(session, fall)
	var stay := _hero_tile(session)
	var refused: Dictionary = OverworldRules.travel_native_passage(session, fall, 1)
	_check(not bool(refused.get("ok", false)) and String(refused.get("message", "")).contains("arrival-only") and _hero_tile(session) == stay, "a Wayfall cannot be entered")
	var walked: Dictionary = OverworldRules.travel_native_passage(session, fall, 0)
	_check(bool(walked.get("ok", false)) and bool(walked.get("native_transit_unavailable", false)) and _hero_tile(session) == stay, "walking onto a Wayfall is a legal move that goes nowhere")
	_check(OverworldRules._resource_site_action_label(ring, {}) == "Step Through" and OverworldRules._resource_site_action_label(fall, {}) == "Inspect", "portal actions read Step Through / Inspect")

# --- text ----------------------------------------------------------------------

func _check_text(session) -> void:
	var nodes := _portal_nodes(session)
	for kind in SITE_BY_KIND:
		var node: Dictionary = nodes.filter(func(n): return NativeTransit.portal_kind(n) == kind)[0]
		var text := OverworldRules.describe_native_portal(session, node)
		var colour := String(NativeTransit.network_colour(node).name)
		_check(text.begins_with("%s %s" % [colour, ContentService.get_resource_site(SITE_BY_KIND[kind]).name]), "%s text starts with its coloured name: %s" % [kind, text])
		var phrase: String = {"two_way_portal": "two-way portal", "one_way_entrance": "one-way portal", "one_way_exit": "cannot be entered"}[kind]
		_check(text.contains(phrase), "%s text says '%s': %s" % [kind, phrase, text])
	var names := {}
	for node in nodes:
		if NativeTransit.portal_kind(node) == "two_way_portal":
			names[OverworldRules.native_portal_display_name(node)] = true
	_check(names.size() == 9, "each two-way network has its own colour name (got %d)" % names.size())

# --- migration -----------------------------------------------------------------

func _check_migration(session, dead_ends: Array) -> void:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	var legacy := []
	var gate_before := {}
	for node in nodes:
		var copy: Dictionary = node.duplicate(true)
		if NativeTransit.portal_kind(copy) != "":
			copy["site_id"] = "site_slipgate_mirror"
			copy["object_id"] = "object_slipgate_mirror"
		elif int(copy.get("h3m_type_id", -1)) in [9, 33, 212, 215, 219] and gate_before.is_empty():
			gate_before = copy.duplicate(true)
		legacy.append(copy)
	for portal in dead_ends:
		var old: Dictionary = portal.duplicate(true)
		old["site_id"] = "site_slipgate_mirror"
		old["collected"] = false
		legacy.append(old)
	session.overworld["resource_nodes"] = legacy
	session.overworld[OverworldRules.GENERATED_TRANSIT_TRANSLATION_KEY] = 1
	session.overworld["native_transit_pending_arrival"] = {"hero_id": "probe"}
	OverworldRules.normalize_overworld_state(session)
	var migrated := _portal_nodes(session)
	_check(migrated.size() == 42 and migrated.all(func(n): return String(n.site_id) == SITE_BY_KIND[NativeTransit.portal_kind(n)]), "a version 1 save gets per-kind portal art and loses its dead-end networks")
	_check(not session.overworld.has("native_transit_pending_arrival"), "the old destination-choice credit is cleared")
	_check(int(session.overworld.get(OverworldRules.GENERATED_TRANSIT_TRANSLATION_KEY, 0)) == 2, "the save is now at translation version 2")
	if not gate_before.is_empty():
		_check(_node_by_id(session, String(gate_before.placement_id)) == gate_before, "version 1 gates are left exactly as they were")

# --- art -----------------------------------------------------------------------

func _check_art() -> void:
	var manifest: Dictionary = ContentService.load_json("res://art/overworld/manifest.json")
	for slug in ["wayring", "waygate", "wayfall"]:
		for layer in ["", "_glow"]:
			var asset: Dictionary = manifest.get("object_assets", {}).get("mapobj_%s%s" % [slug, layer], {})
			var image := Image.load_from_file(ProjectSettings.globalize_path(String(asset.get("path", ""))))
			_check(image != null and image.get_size() == Vector2i(512, 512) and image.detect_alpha() != Image.ALPHA_NONE, "mapobj_%s%s is a 512px sprite with transparency" % [slug, layer])
		var mapped := ContentService.get_map_object_for_resource_site("site_%s" % slug)
		_check(String(mapped.get("id", "")) == "object_%s" % slug, "site_%s links to object_%s" % [slug, slug])

# --- rendering -----------------------------------------------------------------

## The real map view draws each kind's sprite with its network glow. With a
## window, the south-west cluster is captured for review.
func _check_rendering(session) -> void:
	# Open ground amid the zone 23 cluster: Waygates and Wayfalls of two
	# one-way networks and two Wayrings sit within a few tiles of it.
	var blocked: Dictionary = OverworldRules._blocked_tile_index(session, 0)
	var stand := Vector2i(33, 85)
	for radius in range(4):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var tile := Vector2i(33 + dx, 85 + dy)
				if stand == Vector2i(33, 85) and not blocked.has(OverworldRules._tile_key(tile)) and _portal_nodes(session).all(func(n): return Vector2i(int(n.x), int(n.y)) != tile):
					stand = tile
	OverworldRules._set_active_hero_position(session, stand, 0)
	session = SessionState.set_active_session(session)
	OverworldRules.normalize_overworld_state(session)
	var shell = OverworldShellScene.instantiate()
	add_child(shell)
	for _frame in range(6):
		await get_tree().process_frame
	var view = shell.get("_map_view")
	for kind in SITE_BY_KIND:
		var node: Dictionary = _portal_nodes(session).filter(func(n): return NativeTransit.portal_kind(n) == kind)[0]
		var asset_id: String = view.call("_resource_asset_id", node) if view != null else ""
		var slug := String(SITE_BY_KIND[kind]).trim_prefix("site_")
		_check(asset_id == "mapobj_%s" % slug, "the map view draws %s with mapobj_%s (got %s)" % [kind, slug, asset_id])
		_check(view != null and view.call("_object_texture_for_asset", asset_id + "_glow") is Texture2D, "the map view loads the %s glow layer" % slug)
	var fx: Dictionary = view.call("validation_portal_fx_snapshot") if view != null else {}
	var effects: Array = fx.get("effects", [])
	_check(["orbit", "inward_spiral", "falling_beam"].all(func(effect): return effects.has(effect)), "the cluster animates all three portal kinds %s" % str(fx))
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
		await RenderingServer.frame_post_draw
		var first := get_viewport().get_texture().get_image()
		first.save_png("%s/portal_cluster.png" % CAPTURE_DIR)
		var frames_before := int(view.call("validation_portal_fx_snapshot").get("frames_drawn", 0))
		for _frame in range(24):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var second := get_viewport().get_texture().get_image()
		second.save_png("%s/portal_cluster_later.png" % CAPTURE_DIR)
		_check(int(view.call("validation_portal_fx_snapshot").get("frames_drawn", 0)) > frames_before, "the portal light keeps redrawing")
		_check(_images_differ(first, second, fx.get("viewport_rects", [])), "the portal light moves between frames")
		if OS.get_environment("HEROES_PORTAL_FX_FRAMES") != "":
			# Review aid: a short close-up sequence of the animated cluster.
			view.set("large_map_visible_tile_span_override", 9.0)
			view.call("_invalidate_state_cache", "portal_networks_closeup")
			for index in range(int(OS.get_environment("HEROES_PORTAL_FX_FRAMES"))):
				for _frame in range(3):
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/closeup_%02d.png" % [CAPTURE_DIR, index])
	SettingsService.set_reduced_motion_enabled(true)
	view.call("_invalidate_state_cache", "portal_networks_reduced_motion")
	for _frame in range(4):
		await get_tree().process_frame
	_check(int(view.call("validation_portal_fx_snapshot").get("portals", -1)) == 0, "reduced motion keeps portals still")
	SettingsService.set_reduced_motion_enabled(false)
	shell.queue_free()
	for _frame in range(2):
		await get_tree().process_frame

## Pixels inside every portal's own canvas must change: other overworld
## animation elsewhere on screen does not count.
func _images_differ(first: Image, second: Image, rects: Array) -> bool:
	if rects.is_empty():
		return false
	var bounds := Rect2i(Vector2i.ZERO, Vector2i(mini(first.get_width(), second.get_width()), mini(first.get_height(), second.get_height())))
	for rect_value in rects:
		var area := Rect2i(Rect2(rect_value)).intersection(bounds)
		var changed := 0
		for y in range(area.position.y, area.end.y, 2):
			for x in range(area.position.x, area.end.x, 2):
				var a := first.get_pixel(x, y)
				var b := second.get_pixel(x, y)
				if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.08:
					changed += 1
		if changed < 4:
			return false
	return true
