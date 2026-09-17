extends Button

# This button delegates admission to its owning bar; the shell still commits
# every accepted order through TownRules/HeroCommandRules.
var army_bar: VBoxContainer
var holder_id := ""
var slot_index := -1

func _get_drag_data(_position: Vector2) -> Variant:
	if disabled: return null
	var payload: Dictionary = army_bar.begin_slot_drag(holder_id, slot_index)
	if payload.is_empty(): return null
	var preview := HBoxContainer.new()
	var portrait := TextureRect.new()
	portrait.texture = icon
	portrait.custom_minimum_size = Vector2(36, 36)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.add_child(portrait)
	var caption := Label.new()
	caption.text = String(payload.get("caption", ""))
	preview.add_child(caption)
	set_drag_preview(preview)
	return payload

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return not disabled and army_bar.can_drop_stack(data, holder_id, slot_index)

func _drop_data(_position: Vector2, data: Variant) -> void:
	army_bar.drop_stack(data, holder_id, slot_index)
