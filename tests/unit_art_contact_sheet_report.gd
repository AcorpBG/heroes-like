extends Node

const OUTPUT_DIR := "res://.artifacts/unit_art_contact_sheet_report"
const UNIT_ART_MANIFEST := "res://content/unit_art_manifest.json"
const EXPECTED_SURFACES := {
	"portrait": Vector2i(384, 512),
	"battle_icon": Vector2i(160, 160),
	"overworld_icon": Vector2i(96, 96),
}
const CONTACT_THUMB_SIZES := {
	"portrait": Vector2i(96, 128),
	"battle_icon": Vector2i(80, 80),
	"overworld_icon": Vector2i(64, 64),
}
const CONTACT_COLUMNS := {
	"portrait": 8,
	"battle_icon": 10,
	"overworld_icon": 12,
}
const CONTACT_SHEET_FILES := {
	"portrait": "portraits_contact_sheet.png",
	"battle_icon": "battle_icons_contact_sheet.png",
	"overworld_icon": "overworld_icons_contact_sheet.png",
}

var _errors: Array[String] = []
var _report := {
	"ok": false,
	"unit_count": 0,
	"manifest_count": 0,
	"surfaces": {},
	"errors": [],
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_ensure_output_dir()
	var units := _items(ContentService.load_json(ContentService.UNITS_PATH))
	var manifest := _items(ContentService.load_json(UNIT_ART_MANIFEST))
	var units_by_id := _index_by_id(units)
	var manifest_by_unit := _index_by_unit_id(manifest)
	_report["unit_count"] = units.size()
	_report["manifest_count"] = manifest.size()
	if manifest_by_unit.size() != units_by_id.size():
		_error("Unit art manifest count %d does not match authored unit count %d." % [manifest_by_unit.size(), units_by_id.size()])
	for unit_id in units_by_id.keys():
		if not manifest_by_unit.has(unit_id):
			_error("Unit art manifest is missing %s." % unit_id)
	for surface in EXPECTED_SURFACES.keys():
		_report["surfaces"][surface] = _build_surface_report(surface, units, manifest_by_unit)
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	if _errors.is_empty():
		print("UNIT_ART_CONTACT_SHEET_REPORT %s" % JSON.stringify(_summary_payload()))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _build_surface_report(surface: String, units: Array, manifest_by_unit: Dictionary) -> Dictionary:
	var expected_size: Vector2i = EXPECTED_SURFACES[surface]
	var thumb_size: Vector2i = CONTACT_THUMB_SIZES[surface]
	var columns := int(CONTACT_COLUMNS[surface])
	var rows := int(ceil(float(max(units.size(), 1)) / float(columns)))
	var margin := 8
	var sheet_width := columns * thumb_size.x + (columns + 1) * margin
	var sheet_height := rows * thumb_size.y + (rows + 1) * margin
	var sheet := Image.create(sheet_width, sheet_height, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.04, 0.045, 0.055, 1.0))

	var records := []
	var loaded_count := 0
	var visual_pass_count := 0
	for index in range(units.size()):
		var unit: Dictionary = units[index] if units[index] is Dictionary else {}
		var unit_id := String(unit.get("id", "")).strip_edges()
		var record: Dictionary = manifest_by_unit.get(unit_id, {}) if manifest_by_unit.get(unit_id, {}) is Dictionary else {}
		var path := String(record.get(surface, "")).strip_edges()
		var image: Image = _load_image(path)
		var loaded := image != null
		var metrics := {}
		if loaded:
			loaded_count += 1
			var source_size: Vector2i = image.get_size()
			if source_size != expected_size:
				_error("Unit %s %s expected %s but got %s." % [unit_id, surface, expected_size, source_size])
			metrics = _visual_metrics(image)
			if _metrics_pass(metrics):
				visual_pass_count += 1
			else:
				_error("Unit %s %s art failed visual-density gate: %s." % [unit_id, surface, JSON.stringify(metrics)])
			var thumbnail: Image = image.duplicate()
			thumbnail.resize(thumb_size.x, thumb_size.y, Image.INTERPOLATE_LANCZOS)
			var column := index % columns
			var row := int(index / columns)
			var destination := Vector2i(margin + column * (thumb_size.x + margin), margin + row * (thumb_size.y + margin))
			sheet.blit_rect(thumbnail, Rect2i(Vector2i.ZERO, thumb_size), destination)
		else:
			_error("Unit %s %s art failed to load: %s." % [unit_id, surface, path])
		records.append({
			"unit_id": unit_id,
			"name": String(unit.get("name", "")),
			"path": path,
			"contact_sheet_column": index % columns,
			"contact_sheet_row": int(index / columns),
			"loaded": loaded,
			"visual_metrics": metrics,
		})

	var output_file := String(CONTACT_SHEET_FILES[surface])
	var output_path := "%s/%s" % [OUTPUT_DIR, output_file]
	var save_error := sheet.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		_error("Failed to write %s contact sheet to %s." % [surface, output_path])
	return {
		"contact_sheet": output_path,
		"expected_size": {"x": expected_size.x, "y": expected_size.y},
		"thumb_size": {"x": thumb_size.x, "y": thumb_size.y},
		"columns": columns,
		"rows": rows,
		"loaded_count": loaded_count,
		"visual_pass_count": visual_pass_count,
		"records": records,
	}

func _visual_metrics(image: Image) -> Dictionary:
	var width: int = image.get_width()
	var height: int = image.get_height()
	var total_pixels: int = maxi(width * height, 1)
	var visible_pixels := 0
	var min_x := width
	var min_y := height
	var max_x := -1
	var max_y := -1
	var min_luma := 255
	var max_luma := 0
	var quantized_colors := {}
	for y in range(height):
		for x in range(width):
			var color := image.get_pixel(x, y)
			if color.a <= 0.03:
				continue
			visible_pixels += 1
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
			var luma := int(round((0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b) * 255.0))
			min_luma = min(min_luma, luma)
			max_luma = max(max_luma, luma)
			var key := "%d:%d:%d" % [int(color.r * 15.0), int(color.g * 15.0), int(color.b * 15.0)]
			quantized_colors[key] = true
	var bbox_width := 0
	var bbox_height := 0
	if visible_pixels > 0:
		bbox_width = max_x - min_x + 1
		bbox_height = max_y - min_y + 1
	return {
		"alpha_coverage": float(visible_pixels) / float(total_pixels),
		"visible_pixel_count": visible_pixels,
		"bbox_width_ratio": float(bbox_width) / float(maxi(width, 1)),
		"bbox_height_ratio": float(bbox_height) / float(maxi(height, 1)),
		"luminance_range": max_luma - min_luma if visible_pixels > 0 else 0,
		"quantized_color_count": quantized_colors.size(),
	}

func _metrics_pass(metrics: Dictionary) -> bool:
	return (
		float(metrics.get("alpha_coverage", 0.0)) >= 0.20
		and float(metrics.get("bbox_width_ratio", 0.0)) >= 0.35
		and float(metrics.get("bbox_height_ratio", 0.0)) >= 0.35
		and int(metrics.get("luminance_range", 0)) >= 20
		and int(metrics.get("quantized_color_count", 0)) >= 8
	)

func _load_image(path: String):
	if path == "" or not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image

func _summary_payload() -> Dictionary:
	var surface_summaries := {}
	for surface in _report["surfaces"].keys():
		var surface_report: Dictionary = _report["surfaces"][surface]
		surface_summaries[surface] = {
			"contact_sheet": surface_report.get("contact_sheet", ""),
			"loaded_count": surface_report.get("loaded_count", 0),
			"visual_pass_count": surface_report.get("visual_pass_count", 0),
		}
	return {
		"ok": true,
		"unit_count": _report["unit_count"],
		"manifest_count": _report["manifest_count"],
		"surfaces": surface_summaries,
	}

func _index_by_id(records: Array) -> Dictionary:
	var indexed := {}
	for record in records:
		if record is Dictionary:
			var id := String(record.get("id", "")).strip_edges()
			if id != "":
				indexed[id] = record
	return indexed

func _index_by_unit_id(records: Array) -> Dictionary:
	var indexed := {}
	for record in records:
		if record is Dictionary:
			var unit_id := String(record.get("unit_id", record.get("id", ""))).strip_edges()
			if unit_id != "":
				indexed[unit_id] = record
	return indexed

func _items(raw: Dictionary) -> Array:
	var items = raw.get("items", [])
	return items if items is Array else []

func _ensure_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		_error("Failed to write %s." % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))

func _error(message: String) -> void:
	push_error(message)
	_errors.append(message)
