"""Off-screen render using the live map's road methods and original dirt art."""
import re
import overworld_sandy_shore_regression as runner

SOURCE = (runner.ROOT / 'scenes/overworld/OverworldMapView.gd').read_text(encoding='utf-8')
METHODS = ['_draw_road_land_path', '_road_land_corner_points', '_road_land_path_points',
           '_road_connector_start', '_road_connector_end', '_road_horizontal_lane_y',
           '_road_needs_joint_cap', '_draw_hostile_actor_marker', '_road_bridge_axis', '_draw_road_bridge',
           '_bridge_quad']
LIVE = '\n'.join('\n'.join('\t' + line for line in re.search(
    rf'^func {name}\(.*?(?=^func |\Z)', SOURCE, re.M | re.S).group().rstrip().splitlines()) for name in METHODS)
CONSTANTS = '\n'.join('\t' + line for line in re.findall(r'^const ROAD_(?:BRIDGE_\w+|CAUSEWAY_(?:DECK|GRAIN|SEAM)_COLOR) := .*$', SOURCE, re.M))
runner.DEPENDENCIES += ['OverworldRoadStyle.gd']
runner.SCRIPT = r'''extends SceneTree
const RoadStyle = preload("res://scenes/overworld/OverworldRoadStyle.gd")
class Roads extends Control:
	const ROAD_HORIZONTAL_EDGE_Y_FACTOR := 0.5
	const ROAD_LAND_EARTH_COLOR := Color(0.57,0.42,0.24,0.58)
	var dirt: Texture2D
	var roads := {}
	var _river_masks := {}
	var road_types := {}
	var calls := 0
	var bridge_calls := 0
	func _road_neighbor_directions(tile: Vector2i) -> Array:
		var result := []
		for direction in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			if roads.has(tile+direction): result.append(direction)
		# Corner steps, as the live map joins them: no road beside both tiles.
		for direction in [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:
			if roads.has(tile+direction) and not roads.has(tile+Vector2i(direction.x,0)) and not roads.has(tile+Vector2i(0,direction.y)): result.append(direction)
		return result
	func _terrain_art_texture(_path): return dirt
	func _road_tile_payload(tile: Vector2i) -> Dictionary: return {"road_type": road_types.get(tile, 1)}
	func _canvas_draw_polyline(points, color, width, aa):
		calls += 1
		draw_polyline(points,color,width,aa)
	func _canvas_draw_textured_polygon(points, colors, uvs, image):
		calls += 1
		draw_polygon(points,colors,uvs,image)
	func _canvas_draw_colored_polygon(points, color):
		bridge_calls += 1
		draw_colored_polygon(points,color)
	func _canvas_draw_polygon(points, colors):
		bridge_calls += 1
		draw_polygon(points,colors)
	func _canvas_draw_line(from, to, color, width, aa):
		bridge_calls += 1
		draw_line(from,to,color,width,aa)
	func _canvas_draw_circle(at, radius, color):
		bridge_calls += 1
		draw_circle(at,radius,color)
	func _draw() -> void:
		for tile in roads: _draw_road_land_path(tile,Rect2(Vector2(tile)*120,Vector2(120,120)))
''' + CONSTANTS + '\n' + LIVE + r'''
var checks := 0
var failures := []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960,720)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var ground = load("res://scenes/overworld/OverworldGroundSurface.gd").new()
	viewport.add_child(ground)
	ground.configure(JSON.parse_string(FileAccess.get_file_as_string(job.config)),ImageTexture.create_from_image(Image.load_from_file(job.atlas)))
	var rows := []
	var fog := []
	for y in range(6):
		rows.append(["grass","grass","grass","grass","grass","grass","grass","grass"])
		fog.append([true,true,true,true,true,true,true,true])
	ground.sync_lookup(rows,Vector2i(8,6),1,fog,1)
	ground.sync_layout(Rect2(0,0,960,720),Rect2(0,0,960,720),Vector2i(8,6))
	var roads := Roads.new()
	var root_path: String = job.config.get_base_dir().get_base_dir().get_base_dir()
	roads.dirt = ImageTexture.create_from_image(Image.load_from_file(root_path.path_join(RoadStyle.TEXTURE_PATH.trim_prefix("res://"))))
	for x in range(1,7): roads.roads[Vector2i(x,1)] = true
	for y in range(2,5): roads.roads[Vector2i(1,y)] = true
	for x in range(2,4): roads.roads[Vector2i(x,4)] = true
	for y in range(2,4): roads.roads[Vector2i(4,y)] = true
	roads.roads[Vector2i(3,5)] = true
	roads.roads[Vector2i(6,4)] = true
	roads.roads[Vector2i(7,5)] = true
	# A stream crossing the straight east-west road, and one running along it.
	roads._river_masks[Vector2i(5,1)] = 16 | 1 | 4
	roads._river_masks[Vector2i(2,1)] = 16 | 2 | 8
	# The generator's road types: gravel and cobblestone stretches.
	for y in range(2,5): roads.road_types[Vector2i(1,y)] = RoadStyle.ROAD_TYPE_COBBLESTONE
	for y in range(2,4): roads.road_types[Vector2i(4,y)] = RoadStyle.ROAD_TYPE_GRAVEL
	viewport.add_child(roads)
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(job.output.path_join("roads.png"))
	var calls_before := roads.calls
	roads._draw_hostile_actor_marker({"marker_rect":Rect2(0,0,80,80)})
	check(roads.calls == calls_before,"guard overlay still draws arrows")
	for tile in roads.roads:
		var rect := Rect2(Vector2(tile)*120,Vector2(120,120))
		var neighbors := roads._road_neighbor_directions(tile)
		var curve := roads._road_land_corner_points(rect,neighbors)
		if curve.is_empty(): continue
		check(curve[0] == roads._road_connector_end(rect,neighbors[0]) and curve[-1] == roads._road_connector_end(rect,neighbors[1]),"road exits moved")
		var strips := RoadStyle.strips(curve,120*RoadStyle.WIDTH_FACTOR,tile,rect)
		check(strips.size()==3,"road lacks feathered shoulders and painted center")
		for band in strips:
			check(band.points.size()==band.colors.size() and band.points.size()==band.uvs.size(),"invalid raster mesh")
			for point in band.points: check(is_finite(point.x) and is_finite(point.y),"nonfinite road geometry")
	var step_a := Rect2(Vector2(6,4)*120,Vector2(120,120))
	var step_b := Rect2(Vector2(7,5)*120,Vector2(120,120))
	check(Vector2i(1,1) in roads._road_neighbor_directions(Vector2i(6,4)) and roads._road_connector_end(step_a,Vector2i(1,1)) == roads._road_connector_end(step_b,Vector2i(-1,-1)),"diagonal road step does not meet at the shared corner")
	check(roads._road_bridge_axis(Vector2i(5,1),roads._road_neighbor_directions(Vector2i(5,1))) == Vector2i(1,0),"road over a crossing stream has no bridge")
	check(roads._road_bridge_axis(Vector2i(2,1),roads._road_neighbor_directions(Vector2i(2,1))) == Vector2i.ZERO,"road along a stream got a bridge")
	check(roads.bridge_calls > 0,"bridge was not drawn")
	var surfaces := {}
	for road_type in [RoadStyle.ROAD_TYPE_DIRT, RoadStyle.ROAD_TYPE_GRAVEL, RoadStyle.ROAD_TYPE_COBBLESTONE]:
		var path := RoadStyle.texture_path(road_type)
		surfaces[path] = true
		check(FileAccess.file_exists(root_path.path_join(path.trim_prefix("res://"))),"road surface missing for type %d" % road_type)
		check(RoadStyle.strips(PackedVector2Array([Vector2(0,60),Vector2(120,60)]),28.8,Vector2i.ZERO,Rect2(0,0,120,120),road_type).size() == 3,"road type %d lacks its bands" % road_type)
	check(surfaces.size() == 3,"road types share a surface")
	check(RoadStyle.texture_path(0) == RoadStyle.TEXTURE_PATH,"unknown road type is not drawn as dirt")
	print("ROAD_STYLE "+JSON.stringify({"checks":checks,"failures":failures,"draw_calls":roads.calls}))
	quit(0 if failures.is_empty() else 1)
'''

if __name__ == '__main__':
    raise SystemExit(runner.main())
