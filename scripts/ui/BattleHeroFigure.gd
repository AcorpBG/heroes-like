class_name BattleHeroFigure
extends RefCounted
## The figure a battle hero stands as beside its army: the painted figure the
## adventure map shows for that hero (art/overworld/manifest.json
## hero_identity_sprites), else its faction's hero figure
## (hero_faction_sprites). The figures face right; the enemy's is mirrored.

const MANIFEST_PATH := "res://art/overworld/manifest.json"
const ACTOR_SPRITES_PATH := "res://art/overworld/actor_sprites.json"
# The lowest opaque rows that count as the figure's feet (foot_anchor).
const FOOT_ROWS_FRACTION := 0.05
const ALPHA_OPAQUE := 0.5

static var _loaded := false
static var _identity_assets := {}
static var _faction_assets := {}
static var _asset_paths := {}
static var _foot_anchors := {}


## The figure's texture path, or "" when neither the hero nor its faction has
## one.
static func figure_path(hero_id: String, faction_id: String) -> String:
	_ensure_loaded()
	for asset_id in [String(_identity_assets.get(hero_id, "")), String(_faction_assets.get(faction_id, ""))]:
		var path := String(_asset_paths.get(asset_id, ""))
		if path != "" and ResourceLoader.exists(path):
			return path
	return ""


## Where in the texture the figure stands: the bottom of its opaque pixels,
## centred on the opaque pixels of its lowest rows. The figures stand on one
## or two feet anywhere in their canvas, so the canvas centre is not enough.
static func foot_anchor(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ZERO
	var key := texture.resource_path if texture.resource_path != "" else str(texture.get_rid())
	if _foot_anchors.has(key):
		return _foot_anchors[key]
	var size := texture.get_size()
	var anchor := Vector2(size.x * 0.5, size.y * 0.95)
	var image := texture.get_image()
	if image != null and not image.is_empty():
		if image.is_compressed():
			image.decompress()
		var used := image.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			var bottom := used.position.y + used.size.y - 1
			var rows := maxi(2, int(round(float(used.size.y) * FOOT_ROWS_FRACTION)))
			var x_sum := 0.0
			var x_count := 0
			for y in range(maxi(used.position.y, bottom - rows + 1), bottom + 1):
				for x in range(used.position.x, used.position.x + used.size.x):
					if image.get_pixel(x, y).a >= ALPHA_OPAQUE:
						x_sum += float(x)
						x_count += 1
			var foot_x := x_sum / float(x_count) if x_count > 0 else float(used.position.x) + float(used.size.x) * 0.5
			anchor = Vector2(foot_x, float(bottom + 1))
	_foot_anchors[key] = anchor
	return anchor


## The faction crest shown on a hero's plate, or "".
static func crest_path(faction_id: String) -> String:
	if faction_id == "":
		return ""
	var path := String(ContentService.get_faction_crest(faction_id).get("icon_path", ""))
	return path if path != "" and ResourceLoader.exists(path) else ""


## The hero's portrait (spellbook header), or "".
static func portrait_path(hero_id: String) -> String:
	if hero_id == "":
		return ""
	var path := String(ContentService.get_hero_art(hero_id).get("portrait", ""))
	return path if path != "" and ResourceLoader.exists(path) else ""


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var manifest := ContentService.load_json(MANIFEST_PATH)
	for pair in [["hero_identity_sprites", _identity_assets], ["hero_faction_sprites", _faction_assets]]:
		var source: Variant = manifest.get(pair[0], {})
		if not (source is Dictionary):
			continue
		var target: Dictionary = pair[1]
		for key in source:
			var asset_id := String(source.get(key, "")).strip_edges()
			if String(key).strip_edges() != "" and asset_id != "":
				target[String(key).strip_edges()] = asset_id
	var sprites: Variant = ContentService.load_json(ACTOR_SPRITES_PATH).get("assets", {})
	if sprites is Dictionary:
		for asset_id in sprites:
			var entry: Variant = sprites.get(asset_id, {})
			if entry is Dictionary and String(entry.get("path", "")) != "":
				_asset_paths[String(asset_id)] = String(entry.get("path", ""))
