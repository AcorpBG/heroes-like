class_name HeroPortraitView
extends TextureRect

var _hero_id := ""
var _portrait_path := ""


func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_PASS
	_clear_portrait()


func set_hero_id(hero_id: String) -> bool:
	_clear_portrait()
	if hero_id == "":
		return false
	var hero := ContentService.get_hero(hero_id)
	var art := ContentService.get_hero_art(hero_id)
	var portrait_path := String(art.get("portrait", ""))
	if hero.is_empty() or portrait_path == "" or not ResourceLoader.exists(portrait_path, "Texture2D"):
		return false
	var portrait_texture := ResourceLoader.load(portrait_path, "Texture2D") as Texture2D
	if portrait_texture == null:
		return false
	_hero_id = hero_id
	_portrait_path = portrait_path
	texture = portrait_texture
	tooltip_text = "%s portrait" % String(hero.get("name", hero_id))
	visible = true
	return true


func validation_snapshot() -> Dictionary:
	return {
		"hero_id": _hero_id,
		"portrait_path": _portrait_path,
		"tooltip_text": tooltip_text,
		"visible": visible,
		"size": size,
	}


func _clear_portrait() -> void:
	_hero_id = ""
	_portrait_path = ""
	texture = null
	tooltip_text = ""
	visible = false
