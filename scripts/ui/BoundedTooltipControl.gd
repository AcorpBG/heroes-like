extends Control

## Attached only to scriptless controls; authored owners inherit or delegate.
func _make_custom_tooltip(for_text: String) -> Object:
	return get_node("/root/ContextualHelp").make_hover_card(self, for_text)
