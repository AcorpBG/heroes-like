extends Node

const REPORT_ID := "LIVE_VALIDATION_SCREENSHOT_ORIENTATION_REPORT"
const STEP_ID := "orientation_fixture"
const TOP_COLOR := Color(0.92, 0.08, 0.12, 1.0)
const BOTTOM_COLOR := Color(0.06, 0.18, 0.94, 1.0)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport_size := Vector2i(get_viewport().get_visible_rect().size)
	if viewport_size.x < 4 or viewport_size.y < 4:
		return _fail("The viewport is too small for an orientation fixture: %s" % viewport_size)

	var fixture := Control.new()
	fixture.name = "OrientationFixture"
	fixture.position = Vector2.ZERO
	fixture.size = Vector2(viewport_size)
	add_child(fixture)

	var top_band := ColorRect.new()
	top_band.name = "TopBand"
	top_band.color = TOP_COLOR
	top_band.position = Vector2.ZERO
	top_band.size = Vector2(float(viewport_size.x), float(viewport_size.y) * 0.5)
	fixture.add_child(top_band)

	var bottom_band := ColorRect.new()
	bottom_band.name = "BottomBand"
	bottom_band.color = BOTTOM_COLOR
	bottom_band.position = Vector2(0.0, float(viewport_size.y) * 0.5)
	bottom_band.size = Vector2(float(viewport_size.x), float(viewport_size.y) * 0.5)
	fixture.add_child(bottom_band)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var raw_image := get_viewport().get_texture().get_image()
	if raw_image == null or raw_image.is_empty():
		return _fail("The live viewport image was unavailable.")
	var raw_top := raw_image.get_pixel(raw_image.get_width() / 2, raw_image.get_height() / 4)
	var raw_bottom := raw_image.get_pixel(raw_image.get_width() / 2, raw_image.get_height() * 3 / 4)
	if not _color_matches(raw_top, TOP_COLOR) or not _color_matches(raw_bottom, BOTTOM_COLOR):
		return _fail("The raw Godot viewport did not preserve the authored top/bottom fixture: %s / %s" % [raw_top, raw_bottom])

	var output_dir := ProjectSettings.globalize_path("user://live_validation_screenshot_orientation_report")
	var make_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if make_error != OK:
		return _fail("Could not create the focused screenshot output directory: %s" % make_error)
	var previous_output_dir = LiveValidationHarness.get("_output_dir")
	LiveValidationHarness.set("_output_dir", output_dir)
	var screenshot_path := String(LiveValidationHarness.call("_capture_screenshot", STEP_ID))
	LiveValidationHarness.set("_output_dir", previous_output_dir)
	if screenshot_path != "%s/%s.png" % [output_dir, STEP_ID] or not FileAccess.file_exists(screenshot_path):
		return _fail("The production capture helper did not write the exact focused PNG: %s" % screenshot_path)

	var saved_image := Image.load_from_file(screenshot_path)
	if saved_image == null or saved_image.is_empty():
		return _fail("The production screenshot could not be loaded: %s" % screenshot_path)
	var saved_top := saved_image.get_pixel(saved_image.get_width() / 2, saved_image.get_height() / 4)
	var saved_bottom := saved_image.get_pixel(saved_image.get_width() / 2, saved_image.get_height() * 3 / 4)
	var top_exact := _color_matches(saved_top, raw_top)
	var bottom_exact := _color_matches(saved_bottom, raw_bottom)
	if not top_exact or not bottom_exact:
		return _fail("The production screenshot inverted or changed the live viewport orientation: %s / %s" % [saved_top, saved_bottom])

	var payload := {
		"ok": true,
		"viewport_size": viewport_size,
		"raw_top": raw_top.to_html(true),
		"raw_bottom": raw_bottom.to_html(true),
		"saved_top": saved_top.to_html(true),
		"saved_bottom": saved_bottom.to_html(true),
		"top_exact": top_exact,
		"bottom_exact": bottom_exact,
		"png_written": true,
	}
	DirAccess.remove_absolute(screenshot_path)
	DirAccess.remove_absolute(output_dir)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)


func _color_matches(actual: Color, expected: Color) -> bool:
	return (
		absf(actual.r - expected.r) <= 0.02
		and absf(actual.g - expected.g) <= 0.02
		and absf(actual.b - expected.b) <= 0.02
		and absf(actual.a - expected.a) <= 0.02
	)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
