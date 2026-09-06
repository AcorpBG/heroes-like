extends RefCounted

const Levels = preload("res://scripts/core/OverworldLevelRules.gd")
const NAVIGATION_DELTAS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

# Package connectivity is separate from the original artwork's authored local
# route effect. Never infer a generated exit from that artwork's offsets.
static func is_native(node: Dictionary) -> bool:
	return node.has("native_transit") or int(node.get("h3m_type_id", -1)) in [43, 44, 45, 103]

static func uses_native_adjacency(session) -> bool:
	# The recovered 0x49a318 search uses eight adjacent destination cells, not
	# Aurelion's authored-map both-side corner veto. Seed 68's original private
	# predecessor (10,12,1)->(9,11,1) crosses two rock side cells. Keep every
	# destination mask/occupant intact; do not carve the serialized map.
	return session != null and bool(session.flags.get("native_random_map_package_session_adoption", false))

static func link_of(node: Dictionary) -> Dictionary:
	var link: Variant = node.get("native_transit")
	return link if link is Dictionary else {}

static func destinations(node: Dictionary) -> Array:
	var link := link_of(node)
	if String(link.get("kind", "")) == "paired_cave":
		return [{"target_placement_id": link.get("target_placement_id", ""), "exit": link.get("exit", {})}]
	var values: Variant = link.get("destinations", [])
	return values if values is Array else []

static func point(value: Variant) -> Vector3i:
	if value is Dictionary:
		return Vector3i(int(value.get("x", -1)), int(value.get("y", -1)), Levels.level_of(value))
	return Vector3i(-1, -1, -1)

static func navigation_index(tile: Vector3i, map_size: Vector2i, level_count: int) -> int:
	if tile.x < 0 or tile.y < 0 or tile.z < 0 or tile.x >= map_size.x or tile.y >= map_size.y or tile.z >= level_count:
		return -1
	return tile.z * map_size.x * map_size.y + tile.y * map_size.x + tile.x

static func navigation_point(index: int, map_size: Vector2i) -> Vector3i:
	var area := map_size.x * map_size.y
	if index < 0 or area <= 0:
		return Vector3i(-1, -1, -1)
	var local := index % area
	return Vector3i(local % map_size.x, int(local / map_size.x), int(index / area))

static func navigation_field(map_size: Vector2i, level_count: int, blocked: PackedByteArray, links: Array, start: Vector3i, native_adjacency: bool = false) -> Dictionary:
	# Callers supply existing passability masks and already safety-checked
	# native links. This is live navigation, never a generator topology rule.
	var area := map_size.x * map_size.y
	var count := area * level_count
	var origin := navigation_index(start, map_size, level_count)
	if map_size.x <= 0 or map_size.y <= 0 or level_count not in [1, 2] or count != blocked.size() or origin < 0:
		return {"ok": false, "error": "invalid_native_navigation_surface"}
	var links_at_entry := {}
	var exits := PackedInt32Array()
	for index in range(links.size()):
		var link: Variant = links[index]
		if not (link is Dictionary):
			return {"ok": false, "error": "invalid_native_navigation_link"}
		var entry_index := navigation_index(point(link.get("entry")), map_size, level_count)
		var exit_index := navigation_index(point(link.get("exit")), map_size, level_count)
		if entry_index < 0 or exit_index < 0 or blocked[entry_index] != 0 or blocked[exit_index] != 0 or String(link.get("source_placement_id", "")) == "" or String(link.get("target_placement_id", "")) == "":
			return {"ok": false, "error": "unsafe_native_navigation_link"}
		if not links_at_entry.has(entry_index):
			links_at_entry[entry_index] = []
		links_at_entry[entry_index].append(index)
		exits.append(exit_index)
	var distances := PackedInt32Array()
	var first_steps := PackedInt32Array()
	var first_links := PackedInt32Array()
	var queue := PackedInt32Array()
	distances.resize(count)
	first_steps.resize(count)
	first_links.resize(count)
	queue.resize(count)
	distances.fill(-1)
	first_steps.fill(-1)
	first_links.fill(-1)
	distances[origin] = 0
	first_steps[origin] = origin
	queue[0] = origin
	var head := 0
	var tail := 1
	while head < tail:
		var current := int(queue[head])
		head += 1
		var tile := navigation_point(current, map_size)
		var distance := int(distances[current]) + 1
		for delta in NAVIGATION_DELTAS:
			var next_tile := Vector3i(tile.x + delta.x, tile.y + delta.y, tile.z)
			var next_index := navigation_index(next_tile, map_size, level_count)
			if next_index < 0 or blocked[next_index] != 0:
				continue
			if not native_adjacency and delta.x != 0 and delta.y != 0 and blocked[current + delta.x] != 0 and blocked[current + delta.y * map_size.x] != 0:
				continue
			if distances[next_index] < 0:
				distances[next_index] = distance
				first_steps[next_index] = next_index if current == origin else first_steps[current]
				first_links[next_index] = -1 if current == origin else first_links[current]
				queue[tail] = next_index
				tail += 1
			# Choosing a passage after walking onto its entry costs the already
			# paid approach step. Arrival through a portal does NOT use this edge.
			for link_index in links_at_entry.get(next_index, []):
				var exit_index := int(exits[int(link_index)])
				if distances[exit_index] >= 0:
					continue
				distances[exit_index] = distance
				first_steps[exit_index] = next_index if current == origin else first_steps[current]
				first_links[exit_index] = int(link_index) if current == origin else first_links[current]
				queue[tail] = exit_index
				tail += 1
		# Deliberate travel while already at an entrance, including a return
		# after teleporting, spends one step. No zero-cost portal cycles.
		for link_index in links_at_entry.get(current, []):
			var exit_index := int(exits[int(link_index)])
			if distances[exit_index] >= 0:
				continue
			distances[exit_index] = distance
			first_steps[exit_index] = current if current == origin else first_steps[current]
			first_links[exit_index] = int(link_index) if current == origin else first_links[current]
			queue[tail] = exit_index
			tail += 1
	return {"ok": true, "distances": distances, "first_steps": first_steps, "first_links": first_links, "links": links, "start_index": origin, "visited_count": tail, "map_size": map_size, "level_count": level_count}

static func contract_error(node: Dictionary, nodes_by_id: Dictionary) -> String:
	var link: Variant = node.get("native_transit")
	if not (link is Dictionary) or int(link.get("schema_version", 0)) != 1:
		return "missing_native_transit_contract"
	if String(link.get("kind", "")) != "paired_cave":
		return _portal_contract_error(node, nodes_by_id)
	var id := String(node.get("placement_id", ""))
	var peer: Dictionary = nodes_by_id.get(String(link.get("target_placement_id", "")), {})
	if id == "" or String(link.get("source_placement_id", "")) != id or peer.is_empty():
		return "missing_native_transit_peer"
	var reverse: Variant = peer.get("native_transit")
	if not (reverse is Dictionary):
		return "missing_native_transit_reverse_contract"
	if int(reverse.get("schema_version", 0)) != 1 or String(reverse.get("kind", "")) != "paired_cave" or String(reverse.get("source_function", "")) != "0x4a6cf2" or bool(reverse.get("one_way", true)):
		return "invalid_native_cave_reverse_contract"
	if String(link.get("kind", "")) != "paired_cave" or String(link.get("source_function", "")) != "0x4a6cf2" or bool(link.get("one_way", true)):
		return "invalid_native_cave_contract"
	if String(reverse.get("target_placement_id", "")) != id or String(link.get("group_id", "")) == "" or link.get("group_id") != reverse.get("group_id"):
		return "nonreciprocal_native_cave_pair"
	var entry := point(link.get("entry"))
	var exit := point(link.get("exit"))
	var visits: Array = node.get("package_visit_tiles", [])
	var peer_visits: Array = peer.get("package_visit_tiles", [])
	if visits.size() != 1 or peer_visits.size() != 1 or entry != point(visits[0]) or exit != point(peer_visits[0]):
		return "native_transit_action_tile_mismatch"
	if entry.x < 0 or entry.y < 0 or entry.z not in [0, 1] or exit.z not in [0, 1] or entry.z == exit.z or entry.x != exit.x or entry.y != exit.y:
		return "invalid_native_cave_levels"
	if point(reverse.get("entry")) != exit or point(reverse.get("exit")) != entry:
		return "native_transit_reverse_tile_mismatch"
	return ""

static func _portal_contract_error(node: Dictionary, indexed: Dictionary) -> String:
	var link := link_of(node)
	var type_id := int(node.get("h3m_type_id", -1))
	var kinds := {43: "one_way_entrance", 44: "one_way_exit", 45: "two_way_portal"}
	var id := String(node.get("placement_id", ""))
	if not kinds.has(type_id) or link.get("kind") != kinds[type_id] or String(link.get("source_function", "")) != "0x4a7605" or bool(link.get("one_way", false)) != (type_id != 45):
		return "invalid_native_portal_source_role"
	if id == "" or String(link.get("source_placement_id", "")) != id or String(link.get("group_id", "")) == "":
		return "invalid_native_portal_identity"
	var visits: Array = node.get("package_visit_tiles", [])
	if visits.size() != 1 or point(visits[0]) != point(link.get("entry")):
		return "native_transit_action_tile_mismatch"
	var entry := point(link.get("entry"))
	if entry.x < 0 or entry.y < 0 or entry.z not in [0, 1] or not (link.get("destinations") is Array):
		return "invalid_native_portal_entry_or_destinations"
	var expected := {}
	for peer in indexed.values():
		var peer_link := link_of(peer)
		var peer_type := int(peer.get("h3m_type_id", -1))
		if not is_native(peer) or int(peer.get("h3m_subtype", -2)) != int(node.get("h3m_subtype", -1)) or (peer_type == 45) != (type_id == 45):
			continue
		if peer_type not in [43, 44, 45]:
			continue
		# All native records in this exact source descriptor group must agree;
		# a missing contract cannot silently split an otherwise reachable group.
		if peer_link.get("group_id", "") != link.group_id or int(peer_link.get("schema_version", 0)) != 1 or peer_link.get("source_function", "") != "0x4a7605" or peer_link.get("kind") != kinds[peer_type] or bool(peer_link.get("one_way", false)) != (peer_type != 45) or String(peer_link.get("source_placement_id", "")) != String(peer.get("placement_id", "")):
			return "native_portal_source_group_mismatch"
		var peer_id := String(peer.get("placement_id", ""))
		if peer_id != id and ((type_id == 45 and peer_type == 45) or (type_id == 43 and peer_type == 44)):
			var peer_visits: Array = peer.get("package_visit_tiles", [])
			if peer_visits.size() != 1 or point(peer_link.get("entry")) != point(peer_visits[0]):
				return "native_transit_action_tile_mismatch"
			expected[peer_id] = point(peer_visits[0])
	var seen := {}
	for destination in link.destinations:
		if not (destination is Dictionary):
			return "invalid_native_portal_destination"
		var peer_id := String(destination.get("target_placement_id", ""))
		if seen.has(peer_id) or not expected.has(peer_id) or point(destination.get("exit")) != expected[peer_id]:
			return "native_portal_destination_set_mismatch"
		seen[peer_id] = true
	if seen.size() != expected.size():
		return "native_portal_destination_set_incomplete"
	return ""

static func nodes_by_id(nodes: Array) -> Dictionary:
	var result := {}
	for node in nodes:
		if node is Dictionary:
			result[String(node.get("placement_id", ""))] = node
	return result

static func validate(nodes: Array) -> Array:
	var errors := []
	var indexed := nodes_by_id(nodes)
	var seen := {}
	for node in nodes:
		if not (node is Dictionary) or not is_native(node):
			continue
		var id := String(node.get("placement_id", ""))
		if seen.has(id):
			errors.append({"placement_id": id, "error": "duplicate_native_transit_identity"})
		seen[id] = true
		var error := contract_error(node, indexed)
		if error != "":
			errors.append({"placement_id": String(node.get("placement_id", "")), "error": error})
	return errors

static func resolve(nodes: Array, node: Dictionary, target_id: String = "") -> Dictionary:
	var indexed := nodes_by_id(nodes)
	var error := contract_error(node, indexed)
	if error != "":
		return {"ok": false, "error": error, "message": "This passage has an invalid destination (%s)." % error}
	var link := link_of(node).duplicate(true)
	var options := destinations(node)
	if options.is_empty():
		return {"ok": false, "error": "native_passage_has_no_exit", "message": "This is an arrival-only portal." if link.get("kind") == "one_way_exit" else "This passage has no connected destination on this map."}
	if target_id == "" and options.size() > 1:
		return {"ok": false, "native_transit_choice_required": true, "destinations": options.duplicate(true), "message": "Choose a passage destination from the context actions."}
	for destination in options:
		if target_id == "" or String(destination.get("target_placement_id", "")) == target_id:
			link["target_placement_id"] = destination.target_placement_id
			link["exit"] = destination.exit.duplicate(true)
			return {"ok": true, "link": link, "entry": point(link.entry), "exit": point(link.exit), "peer": indexed[String(link.target_placement_id)]}
	return {"ok": false, "error": "native_passage_destination_not_in_group", "message": "That destination is not connected to this passage."}

static func normalize_legacy_session(session) -> void:
	var compatibility: Variant = session.overworld.get("native_transit_compatibility", {})
	if compatibility is Dictionary and int(compatibility.get("version", 0)) == 2:
		return
	var sources: Dictionary = session.overworld.get("package_source_objects_by_id", {})
	if sources.is_empty():
		return
	var caves := []
	for record in sources.values():
		if record is Dictionary and int(record.get("h3m_type_id", -1)) == 103:
			caves.append(record)
	var reconstructed := 0
	var reconstructed_portals := 0
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var source: Dictionary = sources.get(String(node.get("placement_id", "")), {})
		var source_type := int(source.get("h3m_type_id", -1))
		if source_type not in [43, 44, 45, 103]:
			continue
		node["h3m_type_id"] = source_type
		node["h3m_subtype"] = int(source.get("h3m_subtype", -1))
		if node.has("native_transit"):
			continue
		if source.get("native_transit") is Dictionary:
			node["native_transit"] = source.native_transit.duplicate(true)
			continue
		if source_type != 103:
			var visits: Array = source.get("package_visit_tiles", [])
			if visits.size() != 1:
				continue
			var options := []
			for peer in sources.values():
				if not (peer is Dictionary) or String(peer.get("placement_id", "")) == String(source.get("placement_id", "")) or int(peer.get("h3m_subtype", -2)) != int(source.get("h3m_subtype", -1)):
					continue
				if not ((source_type == 45 and int(peer.get("h3m_type_id", -1)) == 45) or (source_type == 43 and int(peer.get("h3m_type_id", -1)) == 44)):
					continue
				var peer_visits: Array = peer.get("package_visit_tiles", [])
				if peer_visits.size() == 1:
					options.append({"target_placement_id": String(peer.get("placement_id", "")), "exit": peer_visits[0].duplicate(true)})
			options.sort_custom(func(a, b): return String(a.target_placement_id) < String(b.target_placement_id))
			# Placement IDs have a final serialized ordinal; the preceding map
			# identity is retained verbatim by old package source records.
			var id := String(source.get("placement_id", ""))
			var ordinal_separator := id.rfind("_object_")
			if ordinal_separator < 1:
				continue
			var map_id := id.left(ordinal_separator)
			node["native_transit"] = {
				"schema_version": 1, "kind": "two_way_portal" if source_type == 45 else ("one_way_entrance" if source_type == 43 else "one_way_exit"),
				"source_function": "0x4a7605", "source_placement_id": id,
				"group_id": "native_portal_" + map_id + ("_two_way_" if source_type == 45 else "_one_way_") + str(int(source.get("h3m_subtype", -1))),
				"entry": visits[0].duplicate(true), "one_way": source_type != 45, "destinations": options,
			}
			reconstructed_portals += 1
			continue
		# Old packages did not store commit-sidecar links. The recovered cave
		# owner copies XY and replaces only the level (0x4a6fbf..0x4a700f).
		# Accept exactly one exact opposite-level source anchor, never nearest
		# objects or artwork offsets. Ambiguity stays invalid and observable.
		var peers := []
		for peer in caves:
			if int(peer.get("h3m_anchor_x", -2)) == int(source.get("h3m_anchor_x", -1)) and int(peer.get("h3m_anchor_y", -2)) == int(source.get("h3m_anchor_y", -1)) and int(peer.get("h3m_anchor_level", -2)) == 1 - int(source.get("h3m_anchor_level", -1)):
				peers.append(peer)
		var visits: Array = source.get("package_visit_tiles", [])
		if peers.size() != 1 or visits.size() != 1 or peers[0].get("package_visit_tiles", []).size() != 1:
			continue
		var peer: Dictionary = peers[0]
		var id := String(source.get("placement_id", ""))
		var peer_id := String(peer.get("placement_id", ""))
		node["native_transit"] = {
			"schema_version": 1, "kind": "paired_cave", "source_function": "0x4a6cf2",
			"group_id": "native_cave_" + (id if id < peer_id else peer_id),
			"source_placement_id": id, "target_placement_id": peer_id,
			"entry": visits[0].duplicate(true), "exit": peer.package_visit_tiles[0].duplicate(true),
			"one_way": false,
		}
		reconstructed += 1
	session.overworld["native_transit_compatibility"] = {"version": 2, "reconstructed_legacy_cave_ends": reconstructed, "reconstructed_legacy_portal_ends": reconstructed_portals, "errors": validate(session.overworld.get("resource_nodes", []))}
