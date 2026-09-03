extends Node

const TownStageViewScript = preload("res://scenes/town/TownStageView.gd")
const FACTION_IDS := [
	"faction_embercourt",
	"faction_mireclaw",
	"faction_sunvault",
	"faction_thornwake",
	"faction_brasshollow",
	"faction_veilmourn",
]
const STAGE_IDS := ["village", "developing", "fully_built"]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage = TownStageViewScript.new()
	add_child(stage)
	var rows: Array = []
	var ok := true
	for faction_id_value in FACTION_IDS:
		var faction_id := String(faction_id_value)
		for stage_id_value in STAGE_IDS:
			var stage_id := String(stage_id_value)
			var texture: Texture2D = stage.call("_development_scene_texture", faction_id, stage_id)
			var exact := texture != null and texture.get_size() == Vector2(1600, 900)
			rows.append({"faction_id": faction_id, "stage_id": stage_id, "exact": exact})
			ok = ok and exact
	print("TOWN_DEVELOPMENT_FIRST_IMPORT_PROBE %s" % JSON.stringify({"ok": ok, "rows": rows}))
	get_tree().quit(0 if ok else 1)
