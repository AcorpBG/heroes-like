extends Node

const OUTPUT_DIR := "res://.artifacts/unit_art_contact_sheet_report"
const UNIT_ART_MANIFEST := "res://content/unit_art_manifest.json"
const EXPECTED_SURFACES := {
	"portrait": Vector2i(384, 512),
	"battle_icon": Vector2i(160, 160),
	"battle_standee": Vector2i(192, 224),
	"overworld_icon": Vector2i(96, 96),
}
const CONTACT_THUMB_SIZES := {
	"portrait": Vector2i(96, 128),
	"battle_icon": Vector2i(80, 80),
	"battle_standee": Vector2i(86, 100),
	"overworld_icon": Vector2i(64, 64),
}
const CONTACT_COLUMNS := {
	"portrait": 8,
	"battle_icon": 10,
	"battle_standee": 10,
	"overworld_icon": 12,
}
const CONTACT_SHEET_FILES := {
	"portrait": "portraits_contact_sheet.png",
	"battle_icon": "battle_icons_contact_sheet.png",
	"battle_standee": "battle_standees_contact_sheet.png",
	"overworld_icon": "overworld_icons_contact_sheet.png",
}
const VISUAL_FINGERPRINT_BITS := 64

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
	var fingerprints := {}
	var fingerprint_records := []
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
			if _metrics_pass(metrics, surface):
				visual_pass_count += 1
			else:
				_error("Unit %s %s art failed visual-density gate: %s." % [unit_id, surface, JSON.stringify(metrics)])
			var fingerprint := _visual_fingerprint(image)
			var signature := String(fingerprint.get("signature", ""))
			if fingerprints.has(signature):
				_error("Unit %s %s art has duplicate visual fingerprint with %s." % [unit_id, surface, fingerprints[signature]])
			else:
				fingerprints[signature] = unit_id
			fingerprint_records.append({
				"unit_id": unit_id,
				"fingerprint": fingerprint,
			})
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
	var nearest := _nearest_visual_neighbor(fingerprint_records)
	return {
		"contact_sheet": output_path,
		"expected_size": {"x": expected_size.x, "y": expected_size.y},
		"thumb_size": {"x": thumb_size.x, "y": thumb_size.y},
		"columns": columns,
		"rows": rows,
		"loaded_count": loaded_count,
		"visual_pass_count": visual_pass_count,
		"unique_visual_fingerprint_count": fingerprints.size(),
		"nearest_visual_neighbor": nearest,
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
		"bottom_gap_ratio": float(height - 1 - max_y) / float(maxi(height, 1)) if visible_pixels > 0 else 1.0,
		"luminance_range": max_luma - min_luma if visible_pixels > 0 else 0,
		"quantized_color_count": quantized_colors.size(),
	}

func _metrics_pass(metrics: Dictionary, surface: String) -> bool:
	return (
		float(metrics.get("alpha_coverage", 0.0)) >= 0.20
		and float(metrics.get("bbox_width_ratio", 0.0)) >= 0.35
		and float(metrics.get("bbox_height_ratio", 0.0)) >= 0.35
		and int(metrics.get("luminance_range", 0)) >= 20
		and int(metrics.get("quantized_color_count", 0)) >= 8
		and (surface != "battle_standee" or float(metrics.get("bottom_gap_ratio", 1.0)) <= 0.04)
	)

func _visual_fingerprint(image: Image) -> Dictionary:
	var average_hash_bits := _average_hash_bits(image)
	var difference_hash_bits := _difference_hash_bits(image)
	var histogram := _color_histogram_bins(image)
	var signature := "%s:%s:%s" % [
		_bits_to_string(average_hash_bits),
		_bits_to_string(difference_hash_bits),
		_int_array_to_string(histogram),
	]
	return {
		"average_hash": _bits_to_string(average_hash_bits),
		"difference_hash": _bits_to_string(difference_hash_bits),
		"histogram": histogram,
		"signature": signature,
	}

func _nearest_visual_neighbor(fingerprint_records: Array) -> Dictionary:
	if fingerprint_records.size() < 2:
		return {}
	var best_score := INF
	var best_pair := {}
	for left_index in range(fingerprint_records.size()):
		var left: Dictionary = fingerprint_records[left_index]
		for right_index in range(left_index + 1, fingerprint_records.size()):
			var right: Dictionary = fingerprint_records[right_index]
			var score := _visual_similarity_score(left.get("fingerprint", {}), right.get("fingerprint", {}))
			if score < best_score:
				best_score = score
				best_pair = {
					"unit_ids": [left.get("unit_id", ""), right.get("unit_id", "")],
					"score": score,
				}
	return best_pair

func _visual_similarity_score(left: Dictionary, right: Dictionary) -> float:
	var average_distance := _bit_string_distance(String(left.get("average_hash", "")), String(right.get("average_hash", "")))
	var difference_distance := _bit_string_distance(String(left.get("difference_hash", "")), String(right.get("difference_hash", "")))
	var histogram_distance := _histogram_distance(
		left.get("histogram", []) if left.get("histogram", []) is Array else [],
		right.get("histogram", []) if right.get("histogram", []) is Array else []
	)
	return float(average_distance + difference_distance) + histogram_distance * 16.0

func _average_hash_bits(image: Image) -> Array:
	var sample := image.duplicate()
	sample.resize(8, 8, Image.INTERPOLATE_LANCZOS)
	var luminance_values := []
	var total := 0.0
	for y in range(8):
		for x in range(8):
			var luminance := _pixel_luminance(sample.get_pixel(x, y))
			luminance_values.append(luminance)
			total += luminance
	var average := total / float(VISUAL_FINGERPRINT_BITS)
	var bits := []
	for luminance in luminance_values:
		bits.append(1 if float(luminance) >= average else 0)
	return bits

func _difference_hash_bits(image: Image) -> Array:
	var sample := image.duplicate()
	sample.resize(9, 8, Image.INTERPOLATE_LANCZOS)
	var bits := []
	for y in range(8):
		for x in range(8):
			var left := _pixel_luminance(sample.get_pixel(x, y))
			var right := _pixel_luminance(sample.get_pixel(x + 1, y))
			bits.append(1 if left > right else 0)
	return bits

func _color_histogram_bins(image: Image) -> Array:
	var sample := image.duplicate()
	sample.resize(16, 16, Image.INTERPOLATE_LANCZOS)
	var histogram := []
	for _index in range(48):
		histogram.append(0)
	for y in range(16):
		for x in range(16):
			var color: Color = sample.get_pixel(x, y)
			if color.a <= 0.03:
				continue
			var red_index := clampi(int(color.r * 15.0), 0, 15)
			var green_index := clampi(int(color.g * 15.0), 0, 15)
			var blue_index := clampi(int(color.b * 15.0), 0, 15)
			histogram[red_index] = int(histogram[red_index]) + 1
			histogram[16 + green_index] = int(histogram[16 + green_index]) + 1
			histogram[32 + blue_index] = int(histogram[32 + blue_index]) + 1
	return histogram

func _pixel_luminance(color: Color) -> float:
	if color.a <= 0.03:
		return 255.0
	return (0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b) * 255.0

func _bit_string_distance(left: String, right: String) -> int:
	var length := mini(left.length(), right.length())
	var distance: int = absi(left.length() - right.length())
	for index in range(length):
		if left[index] != right[index]:
			distance += 1
	return distance

func _histogram_distance(left: Array, right: Array) -> float:
	var length := mini(left.size(), right.size())
	var distance := 0.0
	var left_total := 0.0
	var right_total := 0.0
	for value in left:
		left_total += float(value)
	for value in right:
		right_total += float(value)
	for index in range(length):
		var left_value := float(left[index]) / maxf(left_total, 1.0)
		var right_value := float(right[index]) / maxf(right_total, 1.0)
		distance += absf(left_value - right_value)
	return distance

func _bits_to_string(bits: Array) -> String:
	var packed := PackedStringArray()
	for bit in bits:
		packed.append("1" if int(bit) != 0 else "0")
	return "".join(packed)

func _int_array_to_string(values: Array) -> String:
	var packed := PackedStringArray()
	for value in values:
		packed.append(str(int(value)))
	return ",".join(packed)

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
			"unique_visual_fingerprint_count": surface_report.get("unique_visual_fingerprint_count", 0),
			"nearest_visual_neighbor": surface_report.get("nearest_visual_neighbor", {}),
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
