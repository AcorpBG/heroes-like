extends Node

const REPORT_ID := "CAMPAIGN_ARC_EMBLEM_RUNTIME_REPORT"
const CAPTURE_DIR := "res://.artifacts/campaign_arc_emblem_runtime_report"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const SEAL_CASES := [
	{"campaign_id": "campaign_reedfall", "scenario_id": "river-pass", "stem": "river_pass_break", "source_sha256": "d450ac3f483cdbc5ac9f93e5d06630198227071e7959707b633a1817a492fdb7", "runtime_sha256": "d63a5bac8f158aecf84bd55e82d5b9ec646b23cd4b56359db1d3c3f6cfcb5ab3", "alt_text": "A broken stone bridge, amber watch-lantern, and marsh reeds frame the rushing River Pass."},
	{"campaign_id": "campaign_reedfall", "scenario_id": "causeway-stand", "stem": "causeway_stand", "source_sha256": "9e446b8b93c0acf4033ece8e949d1ab118afd66b3f00aa4ec2b828f5c082ef2a", "runtime_sha256": "556338390f075aa6b05632d924edad8c71e7f9b5bead4518ed6e81ca09ff16f4", "alt_text": "A flooded stone causeway crosses dark marsh water toward a chained gate lit by two bridgehead lanterns."},
	{"campaign_id": "campaign_reedfall", "scenario_id": "fen-crown", "stem": "fen_crown", "source_sha256": "880e93ba2be1b047c6edc141ccf97885065ea938a210ad63f2b941a49fb7e91b", "runtime_sha256": "c0df9c248e0f84b77417e483e84d461bc1ae6f46868231e3a72e28e8d07a99e3", "alt_text": "Five reed towers rise around a gold-roofed command pavilion on the crown-shaped marsh isle."},
	{"campaign_id": "campaign_stonewake", "scenario_id": "stonewake-watch", "stem": "stonewake_watch", "source_sha256": "ee76be3995be59f4986dac8c39ef4703504caaff86d12c9b9addf5a72ba263b2", "runtime_sha256": "5849acd0882bdf8232c0a7b8ef3fd33ffdba2e041bbb70024f7cf56302884561", "alt_text": "A blue-beacon watchstone rises from a chained basin rim at Stonewake Watch."},
	{"campaign_id": "campaign_stonewake", "scenario_id": "reedbarrow-ferry", "stem": "reedbarrow_ferry", "source_sha256": "df1f77e78e88c17f3a3544d5f0fd89185a4dc12b77472c22c8466ef0bf334cc2", "runtime_sha256": "7cb1c03a3c95514eea8a17a0f901541ab81503976d684edc5ed74df7ca764fec", "alt_text": "A broken iron ferry chain spans two timber posts before a low burial barrow."},
	{"campaign_id": "campaign_stonewake", "scenario_id": "nightglass-redoubt", "stem": "nightglass_redoubt", "source_sha256": "07260aaaa5453803cedbd284fdf396a212e88d8560c74c3a5c24ee3757bc15b8", "runtime_sha256": "6faa14b26537e4352dfab9a4e93d6fb1cc2fc05066d71cd00aa767a01423e215", "alt_text": "A luminous fracture splits the black-glass redoubt above its mirrored causeway."},
	{"campaign_id": "campaign_bogbound_oath", "scenario_id": "bogbound-oath", "stem": "bogbound_riverwatch", "source_sha256": "14b61d19f0dc89257aff566dbb6bffc6160fa813676cad2ea117d313292950ad", "runtime_sha256": "62aa1bdd5c245c5ceaa085004ddb374d0e7de943014203c5a183f245646ce15c", "alt_text": "Crooked mangrove roots and a pale oath cord bind a fen-lit Riverwatch marker."},
	{"campaign_id": "campaign_bogbound_oath", "scenario_id": "charter-pyre", "stem": "charter_pyre", "source_sha256": "da7ec65032e4bc12ba764c46f73d3d5952efed046b6ec0d611676612b4e82064", "runtime_sha256": "7329ae5042968c32e98f7552d3fd2162df3f83374c138cbd5b7bea85b31979d6", "alt_text": "A three-pronged beacon brazier burns a rolled road charter above two grain sheaves."},
	{"campaign_id": "campaign_bogbound_oath", "scenario_id": "lockmarsh-surge", "stem": "lockmarsh_surge", "source_sha256": "ea4a63c459cfb2466e2c1132ae909a64a117f05f81a2602faaf5e7315da11b8d", "runtime_sha256": "63419da25b1462a06269b4138495dbe1d3a534e7d2e226757c5c594dcefd4469", "alt_text": "A curling marsh surge breaks through the square lock gate of Highwater Keep."},
	{"campaign_id": "campaign_shards_of_daybreak", "scenario_id": "prismhearth-watch", "stem": "prismhearth_relay", "source_sha256": "d4b17671ae0068ef9df681338d6a319d98a4578a2cd52d1d9fc0f3c210953b29", "runtime_sha256": "3ce752a69e733e48bf6160a5bcd77385fbd69e80765a46e0cff649cb5c371bf9", "alt_text": "Three sun-glass prisms focus warm rays into a relit Prismhearth relay."},
	{"campaign_id": "campaign_shards_of_daybreak", "scenario_id": "glassroad-sundering", "stem": "glassroad_sundering", "source_sha256": "ce9c5edd8be72ac9d98d1f2978a197d1bb51c835d8c882f8ea42276f75217762", "runtime_sha256": "6412db420d9f22842fbb3e4394d1cd3e33aa4426e828f04c53e5ce6ad8b64309", "alt_text": "A straight amber glass road snaps at its center in a burst of large sun-glass shards."},
	{"campaign_id": "campaign_shards_of_daybreak", "scenario_id": "daybreak-spire", "stem": "daybreak_spire", "source_sha256": "97c5a6ab06071c51bc6da6a8a395c6a5129a00dc2fbf809a7024f43b7227cada", "runtime_sha256": "564f9b177987536e69af1ba6edbf5a2dbc7f252cf0042963067c138a2b15cdb9", "alt_text": "Three mirror batteries cast dawn rays around a slender spire while one mirror lies shattered."},
	{"campaign_id": "campaign_ninefold_survey", "scenario_id": "ironbridge-stand", "stem": "ironbridge_stand", "source_sha256": "b4fe4a6fd0781265495338f2f37bdfab77147e2d918c4b0c76495e0a3056e810", "runtime_sha256": "b94c9c9d0ee95ca0f0fd047c5f218d9a5b05fc8036ca5cf1e04ba029eb9b8d41", "alt_text": "A brass survey tripod stands on a riveted iron bridge above a cold river channel."},
	{"campaign_id": "campaign_ninefold_survey", "scenario_id": "glassfen-breakers", "stem": "glassfen_breakers", "source_sha256": "77231e6be6bb21975777b78d8b44006302ac5f24eca7c1d38fe548db760b0ac7", "runtime_sha256": "fc76097428a56b2d4b334398c14a542f95a62e61768bc11cacd1a87fb81ed187", "alt_text": "Three prismatic crystal shards rise from a marsh relay struck by two prepared beams."},
	{"campaign_id": "campaign_ninefold_survey", "scenario_id": "ninefold-confluence", "stem": "ninefold_confluence", "source_sha256": "a6b78ef553c594d2aeec16db8a4ae01b5f3cdf76d9277c504bd5e8cf8892e332", "runtime_sha256": "fdbe9805ab9c069d95f1159c428f237fe180ae4899573c9489450b3174e5ad3c", "alt_text": "Nine stone routes radiate from a circular survey table marked by a brass compass."},
	{"campaign_id": "campaign_frontier_claims", "scenario_id": "mireford-skirmish", "stem": "rootbound_mireford", "source_sha256": "ff4b59b5fbca2abd8e26972163688ba9a3faa3c5bbdf7a55a2a9a910758f9b11", "runtime_sha256": "97493928b398bc2c0cb343b82c28c49aef3f118cefcc8473f171abd1a622dc52", "alt_text": "Living roots form a greenwood arch over three stepping stones at Rootbound Mireford."},
	{"campaign_id": "campaign_frontier_claims", "scenario_id": "orevein-contract", "stem": "orevein_contract", "source_sha256": "e2eddd6fe35fbdd63a281f8c891747562517e1d09d75bf6936bb2e9714c3d74f", "runtime_sha256": "0a503e34b9259e72db2cb161fbda611a0e873a43f426e2bb9c8d08b2e521e788", "alt_text": "A chained brass claim stamp presses a river-crossing contract beside two ore crystals."},
	{"campaign_id": "campaign_frontier_claims", "scenario_id": "bellwake-wreck-claim", "stem": "bellwake_wreck_claim", "source_sha256": "8576848ca5f2c4f796834073e6db15be6d56b445a91decdafb20d75542f0ed04", "runtime_sha256": "5f181bd299ee6307fccdb358a2d98241e39021e39d4dac797bd09cdedc9da7c0", "alt_text": "A tilted verdigris bell prow rises from a drowned wreck beside a pale mirror-chart shard."},
	{"campaign_id": "campaign_frontier_claims", "scenario_id": "rootgate-toll", "stem": "rootgate_toll", "source_sha256": "62370292da2fa0806d573c9a44f1a8dd576492d32e052033612568daa56e6744", "runtime_sha256": "82d4b1dbbdfc1916859bd3a8142adaf2ceaffc133e9486c493a374c71c973ad0", "alt_text": "Two massive living roots cross beneath and split an iron toll gate and its barrier."},
	{"campaign_id": "campaign_frontier_claims", "scenario_id": "fogchart-mooring", "stem": "fogchart_mooring", "source_sha256": "cc2a1cc4cb815ae01c8928ec805b24194d4b2052c36ae54fb4bc66e4ccb2747a", "runtime_sha256": "e8ec1862ad25e034af3dc82931be15d3003e680005549bc6470e139a08b181cb", "alt_text": "A rope-looped mooring post stands above a sinking chart scroll amid three fog wisps."},
	{"campaign_id": "campaign_frontier_claims", "scenario_id": "clauseworks-counterclaim", "stem": "clauseworks_counterclaim", "source_sha256": "621a0bbeeb64e0d327ef757fc25101e6bcbb667e57712f6b3bfda6644d36edeb", "runtime_sha256": "b081514c6501e2d5436c82cd2398590e70ddea43aae07e43366c138deada9775", "alt_text": "Two opposing claim stamps split a folded docket and burst its central sealing wax."},
	{"campaign_id": "campaign_frontier_claims", "scenario_id": "nightglass-ledger-reversal", "stem": "nightglass_ledger_reversal", "source_sha256": "531665744543d8c9063d991d8be77d1c81194255019dcebcb2e430183e3e4ac9", "runtime_sha256": "08eebfc7920df09dad5859399a9187facdef309e7d726e1b12972630a871fc8e", "alt_text": "A chain shaped as a reversing arrow curls over an inverted dark-glass ledger and brass valve."},
	{"campaign_id": "campaign_frontier_claims", "scenario_id": "halo-reserve-refraction-claim", "stem": "halo_reserve_refraction", "source_sha256": "161d5eecc43ed42682f14ea667973d40e147fe5cefe11926336f418f3b4272f7", "runtime_sha256": "a8f3631a68e930a4491df79a6df396fc5864ecaccf8a2768c278a23f20cb8e25", "alt_text": "A brass halo lens bends one claim beam into three rays around a thorn-root obstruction."},
	{"campaign_id": "campaign_frontier_claims", "scenario_id": "charter-bastion-counterseal", "stem": "charter_bastion_counterseal", "source_sha256": "2b0d1308b5273e10cc19930f8b73ccc72e804dc8e1c59d4ff62ad72582d85629", "runtime_sha256": "0a3b17538d418cd704bc9e02bf4844f7bde13be4d8ed4c6da10a36d2324391cd", "alt_text": "A many-sided bastion bears a blank gold counterseal ringed by reed, stone, root, prism, ore, and parchment."},
]
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
		"chapter_seal_count": SEAL_CASES.size(),
		"opening_chapter_seal_count": 6,
		"later_chapter_seal_count": 18,
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
		var campaign := ContentService.get_campaign(campaign_id)
		for scenario_value in campaign.get("scenarios", []):
			if not (scenario_value is Dictionary):
				continue
			chapter_count += 1
			var scenario: Dictionary = scenario_value
			var scenario_id := String(scenario.get("scenario_id", ""))
			var seal := _seal_case(campaign_id, scenario_id)
			if seal.is_empty():
				_fail("Campaign chapter is missing its exact seal manifest: %s/%s" % [campaign_id, scenario_id])
				return false
			var seal_id := "campaign_chapter_seal_%s" % scenario_id.replace("-", "_")
			var source_path := _seal_source_path(seal)
			var runtime_path := _seal_runtime_path(seal)
			seal_count += 1
			if String(scenario.get("seal_id", "")) != seal_id \
					or String(scenario.get("seal_path", "")) != runtime_path \
					or String(scenario.get("seal_source_path", "")) != source_path \
					or String(scenario.get("seal_alt_text", "")) != String(seal.get("alt_text", "")) \
					or String(scenario.get("seal_source_sha256", "")) != String(seal.get("source_sha256", "")) \
					or String(scenario.get("seal_runtime_sha256", "")) != String(seal.get("runtime_sha256", "")):
				_fail("Campaign chapter seal provenance changed for %s/%s: %s" % [campaign_id, scenario_id, JSON.stringify(scenario)])
				return false
			var source_image := _load_png(source_path)
			var runtime_image := _load_png(runtime_path)
			if source_image == null or source_image.get_size() != Vector2i(1254, 1254) \
					or runtime_image == null or runtime_image.get_size() != Vector2i(64, 64) \
					or source_image.detect_alpha() == Image.ALPHA_NONE \
					or runtime_image.detect_alpha() == Image.ALPHA_NONE \
					or source_image.get_pixel(0, 0).a > 0.01 \
					or runtime_image.get_pixel(0, 0).a > 0.01 \
					or FileAccess.get_sha256(source_path) != String(seal.get("source_sha256", "")) \
					or FileAccess.get_sha256(runtime_path) != String(seal.get("runtime_sha256", "")):
				_fail("Campaign chapter seal bytes, dimensions, or alpha changed for %s/%s." % [campaign_id, scenario_id])
				return false
			if CampaignRules.campaign_chapter_seal_path(campaign_id, scenario_id) != runtime_path \
					or CampaignRules.campaign_chapter_seal_alt_text(campaign_id, scenario_id) != String(seal.get("alt_text", "")):
				_fail("Campaign chapter seal runtime authority rejected %s/%s." % [campaign_id, scenario_id])
				return false
			seal_source_hashes[String(seal.get("source_sha256", ""))] = true
			seal_runtime_hashes[String(seal.get("runtime_sha256", ""))] = true
	if chapter_count != 24 or seal_count != 24 or seal_source_hashes.size() != 24 or seal_runtime_hashes.size() != 24:
		_fail("Campaign chapter-seal coverage must remain exact and byte-distinct for all 24 chapters.")
		return false
	if CampaignRules.campaign_chapter_seal_path("campaign_reedfall", "not-authored") != "" \
			or CampaignRules.campaign_chapter_seal_alt_text("campaign_reedfall", "not-authored") != "":
		_fail("Unknown campaign chapter-seal authority did not fail closed.")
		return false
	return true

func _seal_case(campaign_id: String, scenario_id: String) -> Dictionary:
	for seal_value in SEAL_CASES:
		var seal: Dictionary = seal_value
		if String(seal.get("campaign_id", "")) == campaign_id and String(seal.get("scenario_id", "")) == scenario_id:
			return seal
	return {}

func _seal_source_path(seal: Dictionary) -> String:
	return "res://art/campaigns/source/generated/chapter_seals/%s_source.png" % String(seal.get("stem", ""))

func _seal_runtime_path(seal: Dictionary) -> String:
	return "res://art/campaigns/runtime/chapter_seals/%s.png" % String(seal.get("stem", ""))

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
		var layout: Dictionary = snapshot.get("campaign_layout", {}) if snapshot.get("campaign_layout", {}) is Dictionary else {}
		var chapter_rows: Array = layout.get("chapter_items", []) if layout.get("chapter_items", []) is Array else []
		if layout.get("chapter_list_fixed_icon_size", Vector2i.ZERO) != Vector2i(24, 24) \
				or chapter_rows.is_empty():
			_fail("Campaign chapter-seal list is missing or has the wrong icon size for %s at %s." % [String(case.get("campaign_id", "")), viewport_size])
			return false
		for row_value in chapter_rows:
			var row: Dictionary = row_value
			var seal := _seal_case(String(case.get("campaign_id", "")), String(row.get("id", "")))
			if seal.is_empty() \
					or String(row.get("seal_path", "")) != _seal_runtime_path(seal) \
					or String(row.get("seal_alt_text", "")) != String(seal.get("alt_text", "")) \
					or not String(row.get("tooltip", "")).contains(String(seal.get("alt_text", ""))):
				_fail("Campaign chapter seal mismatch for %s at %s: %s" % [String(case.get("campaign_id", "")), viewport_size, JSON.stringify(row)])
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
