extends Node

const REPORT_ID := "CAMPAIGN_ARC_EMBLEM_RUNTIME_REPORT"
const CAPTURE_DIR := "res://.artifacts/campaign_arc_emblem_runtime_report"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const SEAL_CASES := {
	"campaign_reedfall": {"scenario_id": "river-pass", "seal_id": "campaign_chapter_seal_river_pass", "path": "res://art/campaigns/runtime/chapter_seals/river_pass_break.png", "source_path": "res://art/campaigns/source/generated/chapter_seals/river_pass_break_source.png", "source_sha256": "d450ac3f483cdbc5ac9f93e5d06630198227071e7959707b633a1817a492fdb7", "runtime_sha256": "d63a5bac8f158aecf84bd55e82d5b9ec646b23cd4b56359db1d3c3f6cfcb5ab3", "alt_text": "A broken stone bridge, amber watch-lantern, and marsh reeds frame the rushing River Pass."},
	"campaign_stonewake": {"scenario_id": "stonewake-watch", "seal_id": "campaign_chapter_seal_stonewake_watch", "path": "res://art/campaigns/runtime/chapter_seals/stonewake_watch.png", "source_path": "res://art/campaigns/source/generated/chapter_seals/stonewake_watch_source.png", "source_sha256": "ee76be3995be59f4986dac8c39ef4703504caaff86d12c9b9addf5a72ba263b2", "runtime_sha256": "5849acd0882bdf8232c0a7b8ef3fd33ffdba2e041bbb70024f7cf56302884561", "alt_text": "A blue-beacon watchstone rises from a chained basin rim at Stonewake Watch."},
	"campaign_bogbound_oath": {"scenario_id": "bogbound-oath", "seal_id": "campaign_chapter_seal_bogbound_oath", "path": "res://art/campaigns/runtime/chapter_seals/bogbound_riverwatch.png", "source_path": "res://art/campaigns/source/generated/chapter_seals/bogbound_riverwatch_source.png", "source_sha256": "14b61d19f0dc89257aff566dbb6bffc6160fa813676cad2ea117d313292950ad", "runtime_sha256": "62aa1bdd5c245c5ceaa085004ddb374d0e7de943014203c5a183f245646ce15c", "alt_text": "Crooked mangrove roots and a pale oath cord bind a fen-lit Riverwatch marker."},
	"campaign_shards_of_daybreak": {"scenario_id": "prismhearth-watch", "seal_id": "campaign_chapter_seal_prismhearth_watch", "path": "res://art/campaigns/runtime/chapter_seals/prismhearth_relay.png", "source_path": "res://art/campaigns/source/generated/chapter_seals/prismhearth_relay_source.png", "source_sha256": "d4b17671ae0068ef9df681338d6a319d98a4578a2cd52d1d9fc0f3c210953b29", "runtime_sha256": "3ce752a69e733e48bf6160a5bcd77385fbd69e80765a46e0cff649cb5c371bf9", "alt_text": "Three sun-glass prisms focus warm rays into a relit Prismhearth relay."},
	"campaign_ninefold_survey": {"scenario_id": "ironbridge-stand", "seal_id": "campaign_chapter_seal_ironbridge_stand", "path": "res://art/campaigns/runtime/chapter_seals/ironbridge_stand.png", "source_path": "res://art/campaigns/source/generated/chapter_seals/ironbridge_stand_source.png", "source_sha256": "b4fe4a6fd0781265495338f2f37bdfab77147e2d918c4b0c76495e0a3056e810", "runtime_sha256": "b94c9c9d0ee95ca0f0fd047c5f218d9a5b05fc8036ca5cf1e04ba029eb9b8d41", "alt_text": "A brass survey tripod stands on a riveted iron bridge above a cold river channel."},
	"campaign_frontier_claims": {"scenario_id": "mireford-skirmish", "seal_id": "campaign_chapter_seal_mireford_skirmish", "path": "res://art/campaigns/runtime/chapter_seals/rootbound_mireford.png", "source_path": "res://art/campaigns/source/generated/chapter_seals/rootbound_mireford_source.png", "source_sha256": "ff4b59b5fbca2abd8e26972163688ba9a3faa3c5bbdf7a55a2a9a910758f9b11", "runtime_sha256": "97493928b398bc2c0cb343b82c28c49aef3f118cefcc8473f171abd1a622dc52", "alt_text": "Living roots form a greenwood arch over three stepping stones at Rootbound Mireford."},
}
const CASES := [
	{
		"campaign_id": "campaign_reedfall",
		"emblem_id": "campaign_emblem_reedfall",
		"path": "res://art/campaigns/runtime/emblems/reedfall_lantern.png",
		"source_path": "res://art/campaigns/source/generated/emblems/reedfall_lantern_source.png",
		"source_sha256": "04f179aac96ec8b9f32e437e8e9a670dc8bf50038c7507f90601ac181fdeefcc",
		"runtime_sha256": "5b4c3ee3a6b3a7deddeeadb31dfbb74aeb57b0bf3e6c9dbfe47cc79ec4b18c4c",
		"alt_text": "An amber expedition lantern carried through a broken reed arch above a flooded causeway.",
	},
	{
		"campaign_id": "campaign_stonewake",
		"emblem_id": "campaign_emblem_stonewake",
		"path": "res://art/campaigns/runtime/emblems/stonewake_watchstone.png",
		"source_path": "res://art/campaigns/source/generated/emblems/stonewake_watchstone_source.png",
		"source_sha256": "accf4f194395b3d39ad28020dca2f0b19368cb00ef3d0be2937614c621e18104",
		"runtime_sha256": "39529488cc94ce12a61d490d02776db06cb67f173b50a4cf6152d76dd3cbf934",
		"alt_text": "A beacon-topped watchstone rising from basin water behind a locked ferry chain.",
	},
	{
		"campaign_id": "campaign_bogbound_oath",
		"emblem_id": "campaign_emblem_bogbound_oath",
		"path": "res://art/campaigns/runtime/emblems/bogbound_oath_drum.png",
		"source_path": "res://art/campaigns/source/generated/emblems/bogbound_oath_drum_source.png",
		"source_sha256": "3a08c43387f6b45f863366b23c72b0b969316cc4873e5fcbc00129f0bc382ea8",
		"runtime_sha256": "45d2572d109b19386ef868ee5cda135dd5d0bf8907cf58b51763e7465abce770",
		"alt_text": "A marsh oath ring binding a rooted war drum beneath a pale vow flame.",
	},
	{
		"campaign_id": "campaign_shards_of_daybreak",
		"emblem_id": "campaign_emblem_shards_of_daybreak",
		"path": "res://art/campaigns/runtime/emblems/daybreak_shards.png",
		"source_path": "res://art/campaigns/source/generated/emblems/daybreak_shards_source.png",
		"source_sha256": "34392ea0dfa071a2ec0349536904287619714b14649989fdf3dbceb19cddeebe",
		"runtime_sha256": "e0f63a7666d560aaa8946fde4513f2350b05a4c6de618227fd34d8b6fc08d779",
		"alt_text": "Three separated dawn-prism shards focus their light into one relit frontier relay.",
	},
	{
		"campaign_id": "campaign_ninefold_survey",
		"emblem_id": "campaign_emblem_ninefold_survey",
		"path": "res://art/campaigns/runtime/emblems/ninefold_survey_compass.png",
		"source_path": "res://art/campaigns/source/generated/emblems/ninefold_survey_compass_source.png",
		"source_sha256": "439ad7a4e099470a11d0776b766dfcf4205065fec827128b5aa031d421bb5cf6",
		"runtime_sha256": "dd4b5e2903d08a4365affae64c7456721ecb12bf496bcea54086c3cd00f8ecab",
		"alt_text": "A many-spoked brass survey compass measures three rivers converging at a white marker.",
	},
	{
		"campaign_id": "campaign_frontier_claims",
		"emblem_id": "campaign_emblem_frontier_claims",
		"path": "res://art/campaigns/runtime/emblems/frontier_claims_cairn.png",
		"source_path": "res://art/campaigns/source/generated/emblems/frontier_claims_cairn_source.png",
		"source_sha256": "36eea7fcce958d8ab5e08cb624d3b592129834de2543d25e4bcd2e44808a4fb5",
		"runtime_sha256": "173d5cf7a1f5d8152f8f7f55e7c19a2c59db9139aff6581ba483fc9122b11b7d",
		"alt_text": "Six colored frontier routes braid around a dark claim cairn and its blank charter plaque.",
	},
]

var _original_profile := {}
var _original_settings := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	_original_profile = CampaignProgression.ensure_profile().duplicate(true)
	_original_settings = SettingsService.ensure_settings().duplicate(true)
	var capture_settings := _original_settings.duplicate(true)
	capture_settings["accessibility"]["ui_scale_percent"] = 100
	capture_settings["accessibility"]["large_ui_text"] = false
	capture_settings["accessibility"]["high_contrast_ui"] = false
	SettingsService.settings = capture_settings
	SettingsService.apply_settings()
	if not _validate_content_and_bytes():
		return
	if SessionState.SAVE_VERSION != 9:
		_fail("Campaign emblem presentation changed save version %d." % SessionState.SAVE_VERSION)
		return
	var original_window_size := get_window().size
	var original_content_scale_size := get_window().content_scale_size
	for viewport_size in VIEWPORT_SIZES:
		if not await _validate_live_menu(viewport_size):
			return
	get_window().content_scale_size = original_content_scale_size
	get_window().size = original_window_size
	_restore_profile()
	_restore_settings()
	print(REPORT_ID, " ", JSON.stringify({
		"ok": true,
		"campaign_count": CASES.size(),
		"opening_chapter_seal_count": SEAL_CASES.size(),
		"later_text_only_chapter_count": 18,
		"unique_runtime_texture_count": CASES.size(),
		"viewports": VIEWPORT_SIZES,
		"list_icon_size": Vector2i(24, 24),
		"selected_emblem_size": Vector2i(30, 30),
		"missing_asset_fails_closed": true,
		"save_version": SessionState.SAVE_VERSION,
	}))
	get_tree().quit(0)

func _validate_content_and_bytes() -> bool:
	var campaign_ids := CampaignRules.campaign_ids()
	if campaign_ids.size() != CASES.size():
		_fail("Expected exactly six live campaigns, got %s." % campaign_ids)
		return false
	var source_hashes := {}
	var runtime_hashes := {}
	for case_value in CASES:
		var case: Dictionary = case_value
		var campaign_id := String(case.get("campaign_id", ""))
		var campaign := ContentService.get_campaign(campaign_id)
		var source_path := String(case.get("source_path", ""))
		var runtime_path := String(case.get("path", ""))
		if String(campaign.get("emblem_id", "")) != String(case.get("emblem_id", "")) \
				or String(campaign.get("emblem_path", "")) != runtime_path \
				or String(campaign.get("emblem_source_path", "")) != source_path \
				or String(campaign.get("emblem_alt_text", "")) != String(case.get("alt_text", "")) \
				or String(campaign.get("emblem_source_sha256", "")) != String(case.get("source_sha256", "")) \
				or String(campaign.get("emblem_runtime_sha256", "")) != String(case.get("runtime_sha256", "")):
			_fail("Campaign emblem provenance changed for %s: %s" % [campaign_id, JSON.stringify(campaign)])
			return false
		if CampaignRules.campaign_emblem_path(campaign_id) != runtime_path \
				or CampaignRules.campaign_emblem_alt_text(campaign_id) != String(case.get("alt_text", "")):
			_fail("Campaign emblem runtime authority rejected %s." % campaign_id)
			return false
		var source_image := _load_png(source_path)
		var runtime_image := _load_png(runtime_path)
		if source_image == null or source_image.get_size() != Vector2i(1254, 1254) \
				or runtime_image == null or runtime_image.get_size() != Vector2i(128, 128) \
				or source_image.detect_alpha() == Image.ALPHA_NONE \
				or runtime_image.detect_alpha() == Image.ALPHA_NONE \
				or source_image.get_pixel(0, 0).a > 0.01 \
				or runtime_image.get_pixel(0, 0).a > 0.01 \
				or FileAccess.get_sha256(source_path) != String(case.get("source_sha256", "")) \
				or FileAccess.get_sha256(runtime_path) != String(case.get("runtime_sha256", "")):
			_fail("Campaign emblem bytes, dimensions, or alpha changed for %s." % campaign_id)
			return false
		source_hashes[String(case.get("source_sha256", ""))] = true
		runtime_hashes[String(case.get("runtime_sha256", ""))] = true
	if source_hashes.size() != CASES.size() or runtime_hashes.size() != CASES.size():
		_fail("Campaign emblem payloads must remain byte-distinct.")
		return false
	if CampaignRules.campaign_emblem_path("campaign_not_authored") != "" \
			or CampaignRules.campaign_emblem_alt_text("campaign_not_authored") != "":
		_fail("Unknown campaign emblem authority did not fail closed.")
		return false
	var seal_source_hashes := {}
	var seal_runtime_hashes := {}
	var chapter_count := 0
	var seal_count := 0
	for case_value in CASES:
		var campaign_id := String(case_value.get("campaign_id", ""))
		var seal: Dictionary = SEAL_CASES.get(campaign_id, {})
		var campaign := ContentService.get_campaign(campaign_id)
		var scenario_id := String(seal.get("scenario_id", ""))
		for scenario_value in campaign.get("scenarios", []):
			if not (scenario_value is Dictionary):
				continue
			chapter_count += 1
			var scenario: Dictionary = scenario_value
			if String(scenario.get("seal_id", "")) == "":
				continue
			seal_count += 1
			if String(scenario.get("scenario_id", "")) != scenario_id \
					or String(scenario.get("seal_id", "")) != String(seal.get("seal_id", "")) \
					or String(scenario.get("seal_path", "")) != String(seal.get("path", "")) \
					or String(scenario.get("seal_source_path", "")) != String(seal.get("source_path", "")) \
					or String(scenario.get("seal_alt_text", "")) != String(seal.get("alt_text", "")) \
					or String(scenario.get("seal_source_sha256", "")) != String(seal.get("source_sha256", "")) \
					or String(scenario.get("seal_runtime_sha256", "")) != String(seal.get("runtime_sha256", "")):
				_fail("Campaign chapter seal provenance changed for %s: %s" % [campaign_id, JSON.stringify(scenario)])
				return false
		var source_image := _load_png(String(seal.get("source_path", "")))
		var runtime_image := _load_png(String(seal.get("path", "")))
		if source_image == null or source_image.get_size() != Vector2i(1254, 1254) \
				or runtime_image == null or runtime_image.get_size() != Vector2i(64, 64) \
				or source_image.detect_alpha() == Image.ALPHA_NONE \
				or runtime_image.detect_alpha() == Image.ALPHA_NONE \
				or source_image.get_pixel(0, 0).a > 0.01 \
				or runtime_image.get_pixel(0, 0).a > 0.01 \
				or FileAccess.get_sha256(String(seal.get("source_path", ""))) != String(seal.get("source_sha256", "")) \
				or FileAccess.get_sha256(String(seal.get("path", ""))) != String(seal.get("runtime_sha256", "")):
			_fail("Campaign chapter seal bytes, dimensions, or alpha changed for %s." % campaign_id)
			return false
		if CampaignRules.campaign_chapter_seal_path(campaign_id, scenario_id) != String(seal.get("path", "")) \
				or CampaignRules.campaign_chapter_seal_alt_text(campaign_id, scenario_id) != String(seal.get("alt_text", "")):
			_fail("Campaign chapter seal runtime authority rejected %s." % scenario_id)
			return false
		seal_source_hashes[String(seal.get("source_sha256", ""))] = true
		seal_runtime_hashes[String(seal.get("runtime_sha256", ""))] = true
	if chapter_count != 24 or seal_count != 6 or seal_source_hashes.size() != 6 or seal_runtime_hashes.size() != 6:
		_fail("Campaign chapter-seal coverage must remain six opening seals and eighteen text-only later chapters.")
		return false
	if CampaignRules.campaign_chapter_seal_path("campaign_reedfall", "not-authored") != "" \
			or CampaignRules.campaign_chapter_seal_alt_text("campaign_reedfall", "not-authored") != "":
		_fail("Unknown campaign chapter-seal authority did not fail closed.")
		return false
	return true

func _validate_live_menu(viewport_size: Vector2i) -> bool:
	get_window().content_scale_size = viewport_size
	get_window().size = viewport_size
	await _settle(3)
	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await _settle(3)
	shell.call("validation_open_campaign_stage")
	await _settle(2)
	var expected_item_rows := []
	for case_value in CASES:
		var case: Dictionary = case_value
		expected_item_rows.append({
			"campaign_id": String(case.get("campaign_id", "")),
			"path": String(case.get("path", "")),
			"loaded": true,
		})
	for case_value in CASES:
		var case: Dictionary = case_value
		if not bool(shell.call("validation_select_campaign", String(case.get("campaign_id", "")))):
			_fail("Campaign menu could not select %s." % String(case.get("campaign_id", "")))
			return false
		await _settle(2)
		var snapshot: Dictionary = shell.call("validation_snapshot")
		var emblem: Dictionary = snapshot.get("campaign_arc_emblem", {}) if snapshot.get("campaign_arc_emblem", {}) is Dictionary else {}
		if not _selected_emblem_exact(emblem, case, expected_item_rows):
			_fail("Campaign menu emblem mismatch for %s at %s: %s" % [String(case.get("campaign_id", "")), viewport_size, JSON.stringify(emblem)])
			return false
		var seal: Dictionary = SEAL_CASES.get(String(case.get("campaign_id", "")), {})
		var layout: Dictionary = snapshot.get("campaign_layout", {}) if snapshot.get("campaign_layout", {}) is Dictionary else {}
		var chapter_rows: Array = layout.get("chapter_items", []) if layout.get("chapter_items", []) is Array else []
		if layout.get("chapter_list_fixed_icon_size", Vector2i.ZERO) != Vector2i(24, 24) \
				or chapter_rows.is_empty() \
				or String(chapter_rows[0].get("id", "")) != String(seal.get("scenario_id", "")) \
				or String(chapter_rows[0].get("seal_path", "")) != String(seal.get("path", "")) \
				or String(chapter_rows[0].get("seal_alt_text", "")) != String(seal.get("alt_text", "")) \
				or not String(chapter_rows[0].get("tooltip", "")).contains(String(seal.get("alt_text", ""))):
			_fail("Campaign opening-chapter seal mismatch for %s at %s: %s" % [String(case.get("campaign_id", "")), viewport_size, JSON.stringify(chapter_rows)])
			return false
		for row_index in range(1, chapter_rows.size()):
			if String(chapter_rows[row_index].get("seal_path", "")) != "" or String(chapter_rows[row_index].get("seal_alt_text", "")) != "":
				_fail("Later campaign chapter incorrectly claimed opening-seal coverage: %s" % JSON.stringify(chapter_rows[row_index]))
				return false
		await _capture(viewport_size, String(case.get("campaign_id", "")))
	var campaign_list := shell.find_child("CampaignList", true, false) as ItemList
	if campaign_list == null:
		_fail("Campaign list is missing from the live menu.")
		return false
	if not bool(shell.call("validation_select_campaign", String(CASES[0].get("campaign_id", "")))):
		_fail("Could not reset campaign selection before keyboard proof.")
		return false
	campaign_list.grab_focus()
	await _press_navigation(viewport_size == VIEWPORT_SIZES[0])
	var navigation_snapshot: Dictionary = shell.call("validation_snapshot")
	var expected_case: Dictionary = CASES[1]
	if String(navigation_snapshot.get("selected_campaign_id", "")) != String(expected_case.get("campaign_id", "")) \
			or String((navigation_snapshot.get("campaign_arc_emblem", {}) as Dictionary).get("texture_path", "")) != String(expected_case.get("path", "")):
		_fail("Campaign emblem did not follow %s list navigation at %s: %s" % ["keyboard" if viewport_size == VIEWPORT_SIZES[0] else "controller", viewport_size, JSON.stringify(navigation_snapshot)])
		return false
	var entries: Array = shell.get("_campaign_entries")
	var saved_entry: Dictionary = Dictionary(entries[1]).duplicate(true)
	entries[1]["emblem_path"] = "res://art/campaigns/runtime/emblems/missing_campaign_emblem.png"
	shell.set("_campaign_entries", entries)
	shell.call("_refresh_selected_campaign_emblem")
	var missing_snapshot: Dictionary = shell.call("validation_snapshot").get("campaign_arc_emblem", {})
	if bool(missing_snapshot.get("visible", true)) or String(missing_snapshot.get("texture_path", "")) != "" \
			or String(missing_snapshot.get("accessibility_description", "")) != "The selected campaign arc has no loaded emblem.":
		_fail("Missing campaign emblem did not fail closed: %s" % JSON.stringify(missing_snapshot))
		return false
	entries[1] = saved_entry
	shell.set("_campaign_entries", entries)
	shell.call("_refresh_selected_campaign_emblem")
	if shell.call("_load_campaign_chapter_seal_texture", "res://art/campaigns/runtime/chapter_seals/missing_chapter_seal.png") != null:
		_fail("Missing campaign chapter seal did not fail closed.")
		return false
	shell.queue_free()
	await _settle(2)
	return true

func _selected_emblem_exact(emblem: Dictionary, case: Dictionary, expected_item_rows: Array) -> bool:
	var rect: Dictionary = emblem.get("rect", {}) if emblem.get("rect", {}) is Dictionary else {}
	var header_rect: Dictionary = emblem.get("header_rect", {}) if emblem.get("header_rect", {}) is Dictionary else {}
	return bool(emblem.get("visible", false)) \
		and String(emblem.get("texture_path", "")) == String(case.get("path", "")) \
		and String(emblem.get("tooltip_text", "")).contains(String(case.get("alt_text", ""))) \
		and String(emblem.get("accessibility_name", "")).ends_with("campaign emblem") \
		and String(emblem.get("accessibility_description", "")) == String(case.get("alt_text", "")) \
		and int(emblem.get("stretch_mode", -1)) == TextureRect.STRETCH_KEEP_ASPECT_CENTERED \
		and int(emblem.get("expand_mode", -1)) == TextureRect.EXPAND_IGNORE_SIZE \
		and emblem.get("list_fixed_icon_size", Vector2i.ZERO) == Vector2i(24, 24) \
		and emblem.get("item_emblems", []) == expected_item_rows \
		and float(rect.get("width", 0.0)) >= 30.0 \
		and float(rect.get("height", 0.0)) >= 30.0 \
		and float(rect.get("x", -1.0)) >= float(header_rect.get("x", 0.0)) - 0.5 \
		and float(rect.get("right", 0.0)) <= float(header_rect.get("right", -1.0)) + 0.5 \
		and float(rect.get("y", -1.0)) >= float(header_rect.get("y", 0.0)) - 0.5 \
		and float(rect.get("bottom", 0.0)) <= float(header_rect.get("bottom", -1.0)) + 0.5

func _press_navigation(use_keyboard: bool) -> void:
	if use_keyboard:
		var pressed := InputEventAction.new()
		pressed.action = "ui_down"
		pressed.pressed = true
		Input.parse_input_event(pressed)
		await _settle(1)
		var released := InputEventAction.new()
		released.action = "ui_down"
		released.pressed = false
		Input.parse_input_event(released)
	else:
		var pressed := InputEventJoypadButton.new()
		pressed.button_index = JOY_BUTTON_DPAD_DOWN
		pressed.pressed = true
		Input.parse_input_event(pressed)
		await _settle(1)
		var released := InputEventJoypadButton.new()
		released.button_index = JOY_BUTTON_DPAD_DOWN
		released.pressed = false
		Input.parse_input_event(released)
	await _settle(2)

func _load_png(path: String) -> Image:
	var image := Image.new()
	return image if image.load(ProjectSettings.globalize_path(path)) == OK else null

func _capture(viewport_size: Vector2i, campaign_id: String) -> void:
	if OS.get_environment("CAMPAIGN_ARC_EMBLEM_CAPTURE") != "1":
		return
	await RenderingServer.frame_post_draw
	var absolute_dir := ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var path := "%s/%s_%dx%d.png" % [absolute_dir, campaign_id, viewport_size.x, viewport_size.y]
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		_fail("Could not save campaign emblem capture %s: %s" % [path, error])

func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await get_tree().process_frame

func _restore_profile() -> void:
	if _original_profile.is_empty():
		return
	CampaignProgression.profile = CampaignRules.normalize_profile(_original_profile)
	CampaignProgression.save_profile()

func _restore_settings() -> void:
	if _original_settings.is_empty():
		return
	SettingsService.settings = _original_settings.duplicate(true)
	SettingsService.apply_settings()

func _fail(message: String) -> void:
	_restore_profile()
	_restore_settings()
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
	await get_tree().process_frame
