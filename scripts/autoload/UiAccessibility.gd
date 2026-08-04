class_name HeroesUiAccessibility
extends Node

const AUTO_NAME_META := &"heroes_like_accessibility_auto_name"
const AUTO_DESCRIPTION_META := &"heroes_like_accessibility_auto_description"
const MAX_NAME_LENGTH := 160
const MAX_DESCRIPTION_LENGTH := 1000
const LIVE_REGION_DESCRIPTIONS := {
	&"Event": "Reports the latest gameplay event or consequence.",
	&"Status": "Reports the current gameplay status.",
	&"SaveStatus": "Reports save-slot and save-operation changes.",
	&"ActionStatus": "Reports the latest outcome action result.",
	&"CampaignArcStatus": "Reports campaign progression changes.",
	&"GeneratedMapStatus": "Reports random-map generation progress and results.",
	&"SupportBundleStatus": "Reports support-bundle export results.",
	&"SettingsRestoreStatus": "Reports settings restore results.",
}

var _connected_control_ids := {}


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_scan_tree")


func refresh_tree(root: Node = null) -> Dictionary:
	var scan_root := root
	if scan_root == null and get_tree() != null:
		scan_root = get_tree().root
	var summary := {
		"focusable_control_count": 0,
		"named_control_count": 0,
		"described_control_count": 0,
		"live_region_count": 0,
	}
	if scan_root != null:
		_scan_node(scan_root, summary)
	return summary


func configure_control(control: Control) -> bool:
	if control == null:
		return false
	_attach_control(control)
	if control is Label and LIVE_REGION_DESCRIPTIONS.has(control.name):
		configure_live_region(
			control as Label,
			String(LIVE_REGION_DESCRIPTIONS[control.name])
		)
		return true
	if control.get_focus_mode_with_override() == Control.FOCUS_NONE:
		return false
	var generated_name := _control_name(control)
	var generated_description := _control_description(control, generated_name)
	var has_authored_name := control.accessibility_name.strip_edges() != "" and not control.has_meta(AUTO_NAME_META)
	if not has_authored_name:
		if _uses_native_text_name(control):
			if control.has_meta(AUTO_NAME_META):
				control.accessibility_name = ""
				control.remove_meta(AUTO_NAME_META)
		elif control.accessibility_name != generated_name:
			control.accessibility_name = generated_name
			control.set_meta(AUTO_NAME_META, true)
	if control.accessibility_description.strip_edges() == "" or control.has_meta(AUTO_DESCRIPTION_META):
		if control.accessibility_description != generated_description:
			control.accessibility_description = generated_description
		control.set_meta(AUTO_DESCRIPTION_META, true)
	return true


func describe_control(control: Control, semantic_name: String, description: String) -> bool:
	if control == null:
		return false
	var normalized_name := _bounded_text(semantic_name, MAX_NAME_LENGTH)
	var normalized_description := _bounded_text(description, MAX_DESCRIPTION_LENGTH)
	if normalized_name == "" or normalized_description == "":
		return false
	control.accessibility_name = normalized_name
	control.accessibility_description = normalized_description
	control.remove_meta(AUTO_NAME_META)
	control.remove_meta(AUTO_DESCRIPTION_META)
	_attach_control(control)
	return true


func configure_live_region(label: Label, description: String = "") -> bool:
	if label == null:
		return false
	label.accessibility_live = DisplayServer.LIVE_POLITE
	var normalized_description := _bounded_text(description, MAX_DESCRIPTION_LENGTH)
	if normalized_description != "" and (
		label.accessibility_description.strip_edges() == ""
		or label.has_meta(AUTO_DESCRIPTION_META)
	):
		label.accessibility_description = normalized_description
		label.set_meta(AUTO_DESCRIPTION_META, true)
	return true


func validation_snapshot(root: Node) -> Dictionary:
	var summary := refresh_tree(root)
	var missing_names := []
	var missing_descriptions := []
	var live_regions := []
	_collect_validation(root, missing_names, missing_descriptions, live_regions)
	summary["schema"] = "ui_accessibility_semantics_v1"
	summary["accessibility_support_mode"] = int(ProjectSettings.get_setting(
		"accessibility/general/accessibility_support",
		0
	))
	summary["missing_names"] = missing_names
	summary["missing_descriptions"] = missing_descriptions
	summary["live_regions"] = live_regions
	summary["ok"] = missing_names.is_empty() and missing_descriptions.is_empty()
	return summary


func semantic_name(control: Control) -> String:
	if control == null:
		return ""
	if control.accessibility_name.strip_edges() != "" and not control.has_meta(AUTO_NAME_META):
		return _bounded_text(control.accessibility_name, MAX_NAME_LENGTH)
	return _control_name(control)


func _scan_tree() -> void:
	refresh_tree()


func _scan_node(node: Node, summary: Dictionary) -> void:
	if node is Control:
		var control := node as Control
		var focusable := control.get_focus_mode_with_override() != Control.FOCUS_NONE
		configure_control(control)
		if focusable:
			summary["focusable_control_count"] = int(summary["focusable_control_count"]) + 1
			if semantic_name(control) != "":
				summary["named_control_count"] = int(summary["named_control_count"]) + 1
			if control.accessibility_description.strip_edges() != "":
				summary["described_control_count"] = int(summary["described_control_count"]) + 1
		if control.accessibility_live != DisplayServer.LIVE_OFF:
			summary["live_region_count"] = int(summary["live_region_count"]) + 1
	for child in node.get_children():
		_scan_node(child, summary)


func _collect_validation(
	node: Node,
	missing_names: Array,
	missing_descriptions: Array,
	live_regions: Array
) -> void:
	if node is Control:
		var control := node as Control
		if control.is_visible_in_tree() and control.get_focus_mode_with_override() != Control.FOCUS_NONE:
			if semantic_name(control) == "":
				missing_names.append(str(control.get_path()))
			if control.accessibility_description.strip_edges() == "":
				missing_descriptions.append(str(control.get_path()))
		if control.accessibility_live != DisplayServer.LIVE_OFF:
			live_regions.append({
				"path": str(control.get_path()),
				"mode": int(control.accessibility_live),
			})
	for child in node.get_children():
		_collect_validation(child, missing_names, missing_descriptions, live_regions)


func _attach_control(control: Control) -> void:
	var id := control.get_instance_id()
	if _connected_control_ids.has(id):
		return
	_connected_control_ids[id] = true
	var refresh_callback := _on_control_refresh_requested.bind(control)
	if not control.focus_entered.is_connected(refresh_callback):
		control.focus_entered.connect(refresh_callback)
	if not control.visibility_changed.is_connected(refresh_callback):
		control.visibility_changed.connect(refresh_callback)
	if control is OptionButton:
		var option_callback := _on_option_selected.bind(control as OptionButton)
		if not (control as OptionButton).item_selected.is_connected(option_callback):
			(control as OptionButton).item_selected.connect(option_callback)
	var exit_callback := _on_control_exited.bind(id)
	if not control.tree_exited.is_connected(exit_callback):
		control.tree_exited.connect(exit_callback, CONNECT_ONE_SHOT)


func _on_node_added(node: Node) -> void:
	if node is Control:
		call_deferred("_configure_added_control", node.get_instance_id())


func _configure_added_control(control_id: int) -> void:
	var instance = instance_from_id(control_id)
	if instance is Control and is_instance_valid(instance):
		configure_control(instance as Control)


func _on_control_refresh_requested(control: Control) -> void:
	if is_instance_valid(control):
		configure_control(control)


func _on_option_selected(_index: int, control: OptionButton) -> void:
	if is_instance_valid(control):
		call_deferred("_configure_added_control", control.get_instance_id())


func _on_control_exited(id: int) -> void:
	_connected_control_ids.erase(id)


func _control_name(control: Control) -> String:
	var value := ""
	if control is OptionButton:
		value = _option_field_name(control as OptionButton)
	elif control is Button:
		value = String((control as Button).text)
	elif control is LineEdit:
		value = _humanize_node_name(control.name)
		if value == "":
			value = String((control as LineEdit).placeholder_text)
	elif control is TextEdit:
		value = _humanize_node_name(control.name)
		if value == "":
			value = String((control as TextEdit).placeholder_text)
	if value.strip_edges() == "":
		value = _humanize_node_name(control.name)
	if value.strip_edges() == "":
		value = control.get_class()
	return _bounded_text(value, MAX_NAME_LENGTH)


func _uses_native_text_name(control: Control) -> bool:
	return control is Button and not control is OptionButton and String((control as Button).text).strip_edges() != ""


func _control_description(control: Control, semantic_name: String) -> String:
	if control is OptionButton:
		var option := control as OptionButton
		var current_value := "No selection"
		if option.selected >= 0 and option.selected < option.item_count:
			current_value = _bounded_text(String(option.get_item_text(option.selected)), MAX_NAME_LENGTH)
			if current_value == "":
				current_value = "Unnamed option"
		var current_clause := "Current value: %s." % current_value
		var tooltip := _bounded_text(control.tooltip_text, MAX_DESCRIPTION_LENGTH - current_clause.length() - 1)
		if tooltip != "":
			return _bounded_text("%s %s" % [tooltip, current_clause], MAX_DESCRIPTION_LENGTH)
		return _bounded_text("Choose an option for %s. Current value: %s." % [semantic_name, current_value], MAX_DESCRIPTION_LENGTH)
	var tooltip := _bounded_text(control.tooltip_text, MAX_DESCRIPTION_LENGTH)
	if tooltip != "":
		return tooltip
	if control is CheckButton or control is CheckBox:
		return "Toggle %s." % semantic_name
	if control is Button:
		return "Activate %s." % semantic_name
	if control is LineEdit or control is TextEdit:
		return "Enter %s." % semantic_name
	if control is Range:
		return "Adjust %s." % semantic_name
	if control is ItemList or control is Tree or control is TabBar or control is TabContainer:
		return "Choose an item from %s." % semantic_name
	return "Interact with %s." % semantic_name


func _humanize_node_name(node_name: StringName) -> String:
	return String(node_name).to_snake_case().replace("_", " ").capitalize().strip_edges()


func _option_field_name(control: OptionButton) -> String:
	var field_name := _humanize_node_name(control.name)
	field_name = field_name.replace("Ui ", "UI ").replace(" Fps", " FPS").replace("Rmg ", "RMG ")
	for suffix in [" Picker", " Selector", " Toggle"]:
		if field_name.ends_with(suffix):
			field_name = field_name.substr(0, field_name.length() - suffix.length()).strip_edges()
	if field_name == "" and control.selected >= 0 and control.selected < control.item_count:
		field_name = String(control.get_item_text(control.selected)).strip_edges()
	if field_name == "":
		field_name = "Option"
	return _bounded_text(field_name, MAX_NAME_LENGTH)


func _bounded_text(value: String, maximum_length: int) -> String:
	var normalized := " ".join(value.replace("\r", "\n").split("\n", false)).strip_edges()
	while normalized.contains("  "):
		normalized = normalized.replace("  ", " ")
	if normalized.length() > maximum_length:
		normalized = normalized.substr(0, maximum_length - 3).strip_edges() + "..."
	return normalized
