extends Node

const REPORT_ID := "ACCESSIBILITY_SCREEN_READER_SEMANTICS_REPORT"

var _failed := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if int(ProjectSettings.get_setting("accessibility/general/accessibility_support", -1)) != 0:
		return _fail("Project accessibility support is not in automatic native mode.")

	var fixture := VBoxContainer.new()
	fixture.name = "AccessibilityFixture"
	add_child(fixture)

	var generated := Button.new()
	generated.name = "GeneratedCommand"
	generated.text = "Launch campaign"
	generated.tooltip_text = "Open the selected campaign chapter without changing saved expeditions."
	fixture.add_child(generated)

	var authored := Button.new()
	authored.name = "AuthoredCommand"
	authored.text = "Internal label"
	authored.accessibility_name = "Open campaign details"
	authored.accessibility_description = "Review the selected campaign before starting it."
	fixture.add_child(authored)

	var fallback := Button.new()
	fallback.name = "IconOnlyCommand"
	fixture.add_child(fallback)

	var entry := LineEdit.new()
	entry.name = "SaveNameInput"
	entry.placeholder_text = "Optional save name"
	fixture.add_child(entry)

	var event := Label.new()
	event.name = "Event"
	event.text = "A frontier route opened."
	fixture.add_child(event)

	await _settle()
	var fixture_snapshot: Dictionary = UiAccessibility.validation_snapshot(fixture)
	if not bool(fixture_snapshot.get("ok", false)):
		return _fail("Fixture controls are missing semantics: %s" % fixture_snapshot)
	if generated.accessibility_name != "" or UiAccessibility.semantic_name(generated) != "Launch campaign":
		return _fail("Button text did not remain its effective native accessibility name: %s" % UiAccessibility.semantic_name(generated))
	if not generated.accessibility_description.contains("without changing saved expeditions"):
		return _fail("Button tooltip did not become its accessibility description.")
	if authored.accessibility_name != "Open campaign details" or authored.accessibility_description != "Review the selected campaign before starting it.":
		return _fail("Authored accessibility semantics were replaced.")
	if fallback.accessibility_name != "Icon Only Command" or fallback.accessibility_description != "Activate Icon Only Command.":
		return _fail("Icon-only command did not receive a readable node-name fallback: %s / %s" % [fallback.accessibility_name, fallback.accessibility_description])
	if entry.accessibility_name != "Save Name Input" or entry.accessibility_description != "Enter Save Name Input.":
		return _fail("Text entry did not receive a stable field identity: %s" % entry.accessibility_name)
	if event.accessibility_live != DisplayServer.LIVE_POLITE:
		return _fail("Event label is not a polite native live region.")
	if event.accessibility_name != "":
		return _fail("Live label text was replaced by a static accessibility name.")

	generated.text = "Resume campaign"
	generated.tooltip_text = "Resume the latest selected campaign checkpoint."
	generated.grab_focus()
	await _settle()
	if UiAccessibility.semantic_name(generated) != "Resume campaign" or not generated.accessibility_description.contains("latest selected campaign checkpoint"):
		return _fail("Derived semantics did not refresh with changed control text and tooltip.")

	var dynamic := Button.new()
	dynamic.name = "DynamicRecruitOrder"
	dynamic.text = "Recruit wardens"
	dynamic.tooltip_text = "Recruit the selected available stack."
	fixture.add_child(dynamic)
	await _settle()
	if UiAccessibility.semantic_name(dynamic) != "Recruit wardens" or dynamic.accessibility_description == "":
		return _fail("Dynamically inserted control did not receive semantics.")

	var menu = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(menu)
	await _settle()
	var menu_snapshot: Dictionary = UiAccessibility.validation_snapshot(menu)
	if not bool(menu_snapshot.get("ok", false)):
		return _fail("Visible main-menu controls are missing native semantics: %s" % menu_snapshot)
	if int(menu_snapshot.get("focusable_control_count", 0)) < 20:
		return _fail("Main-menu semantic scan covered too few focusable controls: %s" % menu_snapshot)
	for node_name in ["OpenCampaign", "OpenSkirmish", "OpenSaves", "OpenSettings", "OpenEditor", "Quit"]:
		var control := menu.get_node_or_null("BackdropCommandHotspots/%s" % node_name) as Control
		if control == null or UiAccessibility.semantic_name(control) == "" or control.accessibility_description == "":
			return _fail("Main-menu command lacks native semantics: %s" % node_name)

	var result := {
		"schema": "accessibility_screen_reader_semantics_report_v1",
		"accessibility_support_mode": 0,
		"fixture_focusable_controls": int(fixture_snapshot.get("focusable_control_count", 0)),
		"menu_focusable_controls": int(menu_snapshot.get("focusable_control_count", 0)),
		"menu_live_regions": int(menu_snapshot.get("live_region_count", 0)),
		"dynamic_control_named": UiAccessibility.semantic_name(dynamic) != "",
		"authored_semantics_preserved": true,
	}
	print("%s PASS %s" % [REPORT_ID, JSON.stringify(result)])
	menu.queue_free()
	fixture.queue_free()
	get_tree().quit(0)


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
