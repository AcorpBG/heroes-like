// ContentService's start-up checks of the live content (its _validate_content
// and the checks it ran), ported under their GDScript names: what is wrong with
// the shipped files, as push_warning lines. The archived authored scenarios,
// campaigns and terrain layers are no longer checked (owner decision
// 2026-10-23). A check GDScript stops on with a runtime error ends that check
// with an error message, and the next one runs, as GDScript goes on with the
// caller.

#include "aurelion_rules/content_store.hpp"

#include "aurelion_rules/port/gd.hpp"

#include <algorithm>
#include <exception>
#include <initializer_list>
#include <string>
#include <unordered_map>
#include <vector>

namespace aurelion::rules::content {

namespace {

using state::Kind;
using state::State;
using state::Value;

bool begins_with(const std::string &text, const std::string &prefix) {
	return text.compare(0, prefix.size(), prefix) == 0;
}

bool ends_with(const std::string &text, const std::string &suffix) {
	return text.size() >= suffix.size() && text.compare(text.size() - suffix.size(), suffix.size(), suffix) == 0;
}

std::string trim_prefix(const std::string &text, const std::string &prefix) {
	return begins_with(text, prefix) ? text.substr(prefix.size()) : text;
}

// s.strip_edges(): the characters up to code 32 dropped at both ends.
std::string strip_edges(const std::string &text) {
	size_t begin = 0;
	size_t end = text.size();
	while (begin < end && static_cast<unsigned char>(text[begin]) <= 32) {
		++begin;
	}
	while (end > begin && static_cast<unsigned char>(text[end - 1]) <= 32) {
		--end;
	}
	return text.substr(begin, end - begin);
}

// s.length(): code points.
size_t length(const std::string &text) {
	size_t count = 0;
	for (const char c : text) {
		if ((static_cast<unsigned char>(c) & 0xC0) != 0x80) {
			++count;
		}
	}
	return count;
}

bool one_of(const std::string &text, std::initializer_list<const char *> values) {
	for (const char *value : values) {
		if (text == value) {
			return true;
		}
	}
	return false;
}

// The spell schools a spell, a school sigil or a faction's preference names
// (docs/magic-system.md, The shape).
const std::initializer_list<const char *> kSpellSchoolIds = {"furnace", "root", "beacon", "veil"};

bool contains(const std::vector<std::string> &values, const std::string &text) {
	for (const std::string &value : values) {
		if (value == text) {
			return true;
		}
	}
	return false;
}

// A Dictionary of rows by String(id), as _index_items builds it: in the order
// each id first came, the last row of an id kept.
class RowIndex {
public:
	void put(const std::string &id, const Value &row) {
		const auto made = rows_.emplace(id, row);
		if (made.second) {
			ids_.push_back(id);
		} else {
			made.first->second = row;
		}
	}
	bool has(const std::string &id) const { return rows_.count(id) != 0; }
	// The row, or Nil for index.get(id, {}).
	Value at(const std::string &id) const {
		const auto found = rows_.find(id);
		return found != rows_.end() ? found->second : Value();
	}
	size_t size() const { return ids_.size(); }
	const std::vector<std::string> &ids() const { return ids_; }

private:
	std::vector<std::string> ids_;
	std::unordered_map<std::string, Value> rows_;
};

class Check {
public:
	Check(State &data, Files &files, std::vector<Message> &out) :
			d_(data), files_(files), out_(out) {
		empty_text_ = d_.string("");
		const uint32_t dict = d_.new_dict();
		d_.dict_node(dict).read_only = true;
		empty_dict_ = Value::of_ref(Kind::Dict, dict);
		const uint32_t array = d_.new_array();
		d_.array_node(array).read_only = true;
		empty_array_ = Value::of_ref(Kind::Array, array);
	}

	Value empty_dict() const { return empty_dict_; }
	Value empty_array() const { return empty_array_; }

	// One function of the checks: a runtime error ends it with an error
	// message (false), and its caller goes on.
	template <typename Body>
	bool guard(const char *name, Body body) {
		try {
			body();
			return true;
		} catch (const std::exception &failure) {
			out_.push_back({true, std::string("ContentService.") + name + ": " + failure.what()});
			return false;
		}
	}
	// A helper's answer; false when a runtime error ends it (a typed function
	// GDScript stops in returns its type's default).
	template <typename Body>
	bool ask(const char *name, Body body) {
		try {
			return body();
		} catch (const std::exception &failure) {
			out_.push_back({true, std::string("ContentService.") + name + ": " + failure.what()});
			return false;
		}
	}

	// _index_items(items): rows with an id, by String(id); none when GDScript
	// stops in it.
	RowIndex index_items(const Value &items) {
		RowIndex index;
		if (items.kind != Kind::Array) {
			return index;
		}
		const bool made = guard("_index_items", [&] {
			const Value id_key = d_.string("id");
			for (const Value &item : gd::items(d_, items)) {
				Value id;
				if (item.kind == Kind::Dict && d_.lookup(item.ref, id_key, id)) {
					index.put(str(id), item);
				}
			}
		});
		return made ? index : RowIndex();
	}

	// _index_unit_art_items / _index_hero_art_items (name): rows by
	// String(item.get(id_field, item.get("id", ""))), "" left out; none when
	// GDScript stops in it.
	RowIndex index_by(const Value &items, const char *id_field, const char *name) {
		RowIndex index;
		if (items.kind != Kind::Array) {
			return index;
		}
		const bool made = guard(name, [&] {
			for (const Value &item : gd::items(d_, items)) {
				if (item.kind != Kind::Dict) {
					continue;
				}
				const std::string id = str(get(item, id_field, get(item, "id", empty_text_)));
				if (!id.empty()) {
					index.put(id, item);
				}
			}
		});
		return made ? index : RowIndex();
	}

	void terrain_grammar(const Value &grammar, const RowIndex &biome_index);
	void biome(const Value &biome);
	void resource_site(const Value &site, const RowIndex &unit_index, const RowIndex &spell_index, const RowIndex &neutral_dwelling_index, const RowIndex &army_group_index, const RowIndex &encounter_index);
	void map_object(const Value &map_object, const RowIndex &biome_index, const RowIndex &resource_site_index, const RowIndex &faction_index);
	void neutral_dwelling(const Value &dwelling, const RowIndex &unit_index, const RowIndex &resource_site_index, const RowIndex &map_object_index, const RowIndex &army_group_index, const RowIndex &encounter_index, const RowIndex &biome_index);
	void faction(const Value &faction, const RowIndex &town_index, const RowIndex &hero_index, const Value &terrain_grammar);
	void hero(const Value &hero, const RowIndex &faction_index, const RowIndex &spell_index);
	void unit(const Value &unit, const RowIndex &faction_index);
	void hero_art_manifest(const RowIndex &hero_index, const RowIndex &hero_art_index);
	void unit_art_manifest(const RowIndex &unit_index, const RowIndex &unit_art_index);
	void unit_animation_manifest(const RowIndex &unit_index, const Value &manifest, const RowIndex &unit_animation_index);
	void army_group(const Value &army_group, const RowIndex &faction_index, const RowIndex &unit_index);
	void building(const Value &building, const RowIndex &building_index, const RowIndex &unit_index);
	void town(const Value &town, const RowIndex &faction_index, const RowIndex &building_index, const RowIndex &unit_index);
	void encounter(const Value &encounter, const RowIndex &army_group_index, const RowIndex &spell_index);
	void artifact(const Value &artifact, const RowIndex &spell_index);
	void spell_school_icons(const RowIndex &icon_index);
	void spell_icons(const RowIndex &spell_index, const RowIndex &icon_index);
	void faction_crests(const RowIndex &faction_index, const RowIndex &crest_index);
	void building_category_icons(const RowIndex &icon_index);
	void building_art_manifest(const RowIndex &building_index, const RowIndex &art_index);
	void resources(const RowIndex &resource_index);
	void spell(const Value &spell);
	void retired_spells(const Value &items, const RowIndex &spell_index);
	void map_effect(const std::string &spell_id, const Value &spell, const Value &effect, const std::string &context);
	void warn(const std::string &text) { out_.push_back({false, text}); }

private:
	// value.get(key, fallback) on a Dictionary; GDScript stops on any other.
	Value get(const Value &dict, const char *key, const Value &fallback) {
		if (dict.kind != Kind::Dict) {
			gd::not_a_dict(dict);
		}
		Value found;
		return d_.lookup(dict.ref, d_.string(key), found) ? found : fallback;
	}
	Value get(const Value &dict, const std::string &key, const Value &fallback) {
		return get(dict, key.c_str(), fallback);
	}
	// A row of an index, or {} for none.
	Value row(const RowIndex &index, const std::string &id) {
		const Value found = index.at(id);
		return found.kind == Kind::Nil ? empty_dict_ : found;
	}
	bool has(const Value &dict, const char *key) {
		if (dict.kind != Kind::Dict) {
			gd::not_a_dict(dict);
		}
		return d_.has(dict.ref, d_.string(key));
	}
	// String(value): of a String or StringName; any other value stops GDScript.
	std::string str(const Value &value) { return d_.text(gd::to_string(value)); }
	// String(dict.get(key, ""))
	std::string text(const Value &dict, const char *key) { return str(get(dict, key, empty_text_)); }
	// int(dict.get(key, fallback))
	int64_t integer(const Value &dict, const char *key, int64_t fallback) { return gd::to_int(d_, get(dict, key, Value::of_int(fallback))); }
	// bool(dict.get(key, false))
	bool flag(const Value &dict, const char *key) { return gd::to_bool(get(dict, key, Value::of_bool(false))); }
	bool is_dict(const Value &value) const { return value.kind == Kind::Dict; }
	bool is_array(const Value &value) const { return value.kind == Kind::Array; }
	// value.is_empty() of a Dictionary or Array.
	bool empty(const Value &value) const {
		if (value.kind == Kind::Dict) {
			return d_.dict_size(value.ref) == 0;
		}
		if (value.kind == Kind::Array) {
			return d_.array(value.ref).items.empty();
		}
		if (value.is_string_like()) {
			return d_.text(value.ref).empty();
		}
		throw state::ScriptError(std::string("Nonexistent function 'is_empty' in base '") + gd::type_name(value) + "'");
	}
	// text in container
	bool in(const std::string &text, const Value &container) {
		if (container.is_string_like()) {
			return d_.text(container.ref).find(text) != std::string::npos;
		}
		return gd::in(d_, d_.string(text), container);
	}
	// `for x in value`
	gd::Items each(const Value &value) { return gd::items(d_, value); }
	// The keys of a Dictionary, as dict.keys() gives them.
	gd::Items keys(const Value &dict) {
		if (dict.kind != Kind::Dict) {
			gd::not_a_dict(dict);
		}
		return gd::items(d_, dict);
	}
	// dict[key] of a key the Dictionary has.
	Value at(const Value &dict, const Value &key) {
		Value found;
		d_.lookup(dict.ref, key, found);
		return found;
	}
	bool resource_exists(const std::string &path) { return files_.resource_exists(path); }

	void editor_base_terrain_options(const Value &grammar, const std::vector<std::string> &terrain_ids);
	void terrain_tile_art(const Value &terrain_class, const std::string &terrain_id);
	void road_overlay_tile_art(const Value &overlay, const std::string &overlay_id);
	void art_path(const std::string &path, const std::string &label);
	bool unit_is_neutral(const Value &unit);
	void recruit_payload(const std::string &label, const Value &recruits, const RowIndex &unit_index, bool require_neutral_units);

	State &d_;
	Files &files_;
	std::vector<Message> &out_;
	Value empty_text_;
	Value empty_dict_;
	Value empty_array_;
};

bool looks_like_hex_color(const std::string &value) {
	const size_t size = length(value);
	return begins_with(value, "#") && (size == 7 || size == 9);
}

bool supported_resource_site_family(const std::string &family) {
	return one_of(family, {
		"one_shot_pickup", "mine", "neutral_dwelling", "faction_outpost", "frontier_shrine", "guarded_reward_site",
		"scouting_structure", "transit_object", "repeatable_service", "visit_building", "staged_resource_front",
		"support_producer", "shrine", "sign_waypoint", "scenario_objective", "faction_landmark",
	});
}

bool supported_map_object_family(const std::string &family) {
	return one_of(family, {
		"pickup", "mine", "neutral_dwelling", "neutral_encounter", "shrine", "guarded_reward_site",
		"scouting_structure", "transit_object", "repeatable_service", "blocker", "decoration", "faction_landmark",
		"staged_resource_front", "support_producer", "sign_waypoint", "scenario_objective",
	});
}

void Check::resources(const RowIndex &resource_index) {
	const char *const expected_ids[] = {
		"gold", "wood", "ore", "aetherglass", "embergrain", "peatwax",
		"verdant_grafts", "brass_scrip", "memory_salt",
	};
	if (resource_index.size() != 9) {
		warn("Production resource registry must define exactly the nine live stockpile resources.");
	}
	for (const char *resource_id : expected_ids) {
		const Value resource = row(resource_index, resource_id);
		if (empty(resource)) {
			warn(std::string("Production resource registry is missing ") + resource_id + ".");
			continue;
		}
		for (const char *key : {"display_name", "category", "market_tier", "icon_id", "icon_path", "material_cue"}) {
			if (strip_edges(text(resource, key)).empty()) {
				warn(std::string("Production resource ") + resource_id + " must define " + key + ".");
			}
		}
		if (!flag(resource, "stockpile")) {
			warn(std::string("Production resource ") + resource_id + " must remain a live stockpile resource.");
		}
		const std::string icon_path = text(resource, "icon_path");
		if (!begins_with(icon_path, "res://art/economy/runtime/resources/") || !ends_with(icon_path, ".png")) {
			warn(std::string("Production resource ") + resource_id + " must use the shipped economy resource icon family.");
		} else {
			art_path(icon_path, std::string("Production resource ") + resource_id + " icon");
		}
	}
}

void Check::terrain_grammar(const Value &grammar, const RowIndex &biome_index) {
	if (text(grammar, "rendering_model") != "authored_autotile_layers") {
		warn("Terrain grammar must declare rendering_model authored_autotile_layers.");
	}
	if (text(grammar, "primary_base_model") != "original_quiet_tile_bank") {
		warn("Terrain grammar must declare original_quiet_tile_bank as the active shippable base model.");
	}
	if (text(grammar, "generated_source_policy") != "reference_only_inactive") {
		warn("Terrain grammar must keep generated renderer-study sources reference-only and inactive.");
	}
	const Value classes = get(grammar, "terrain_classes", empty_array_);
	if (!is_array(classes) || empty(classes)) {
		warn("Terrain grammar must define terrain_classes.");
		return;
	}
	std::vector<std::string> terrain_ids;
	for (const Value &terrain_class : each(classes)) {
		if (!is_dict(terrain_class)) {
			warn("Terrain grammar contains a non-dictionary terrain class.");
			continue;
		}
		const std::string terrain_id = text(terrain_class, "id");
		if (terrain_id.empty()) {
			warn("Terrain grammar terrain classes must define id.");
			continue;
		}
		if (contains(terrain_ids, terrain_id)) {
			warn("Terrain grammar repeats terrain id " + terrain_id + ".");
		}
		terrain_ids.push_back(terrain_id);
		const std::string biome_id = text(terrain_class, "biome_id");
		if (biome_id.empty() || !biome_index.has(biome_id)) {
			warn("Terrain grammar " + terrain_id + " references missing biome " + biome_id + ".");
		}
		for (const char *key : {"terrain_group", "autotile_family", "style_id", "pattern", "readability_role"}) {
			if (text(terrain_class, key).empty()) {
				warn("Terrain grammar " + terrain_id + " must define " + key + ".");
			}
		}
		for (const char *color_key : {"base_color", "detail_color", "edge_color"}) {
			if (!looks_like_hex_color(text(terrain_class, color_key))) {
				warn("Terrain grammar " + terrain_id + " must define " + color_key + " as a hex color.");
			}
		}
		if (integer(terrain_class, "transition_priority", -1) < 0) {
			warn("Terrain grammar " + terrain_id + " must define transition_priority >= 0.");
		}
		// The movement points a step onto the ground costs, in half points (docs/overworld-terrain-movement.md).
		const Value movement_cost = get(terrain_class, "movement_cost", Value());
		const double points = movement_cost.kind == Kind::Int || movement_cost.kind == Kind::Float ? gd::to_float(movement_cost) : 0.0;
		if (!(points >= 0.5 && points <= 100.0) || points * 2.0 != static_cast<double>(static_cast<int64_t>(points * 2.0))) {
			warn("Terrain grammar " + terrain_id + " must define movement_cost as a number of half points from 0.5 to 100.");
		}
		const Value supports = get(terrain_class, "supports", empty_array_);
		if (!is_array(supports) || !in("edge_transitions", supports)) {
			warn("Terrain grammar " + terrain_id + " must support edge_transitions.");
		}
		if (one_of(terrain_id, {"grass", "plains", "forest", "mire", "swamp", "rough"})) {
			guard("_validate_terrain_tile_art", [&] { terrain_tile_art(terrain_class, terrain_id); });
		}
	}

	for (const char *required_id : {"grass", "snow", "sand", "dirt", "rough", "lava", "underground", "water", "rock"}) {
		if (!contains(terrain_ids, required_id)) {
			warn(std::string("Terrain grammar must define authored terrain class ") + required_id + ".");
		}
	}
	guard("_validate_editor_base_terrain_options", [&] { editor_base_terrain_options(grammar, terrain_ids); });

	std::vector<std::string> overlay_ids;
	const Value overlays = get(grammar, "overlay_classes", empty_array_);
	if (!is_array(overlays) || empty(overlays)) {
		warn("Terrain grammar must define overlay_classes.");
		return;
	}
	for (const Value &overlay : each(overlays)) {
		if (!is_dict(overlay)) {
			warn("Terrain grammar contains a non-dictionary overlay class.");
			continue;
		}
		const std::string overlay_id = text(overlay, "id");
		if (overlay_id.empty()) {
			warn("Terrain grammar overlay classes must define id.");
			continue;
		}
		overlay_ids.push_back(overlay_id);
		if (text(overlay, "layer") != "road") {
			warn("Terrain grammar overlay " + overlay_id + " must currently use layer road.");
		}
		for (const char *color_key : {"color", "edge_color", "shadow_color", "center_color"}) {
			if (!looks_like_hex_color(text(overlay, color_key))) {
				warn("Terrain grammar overlay " + overlay_id + " must define " + color_key + " as a hex color.");
			}
		}
		if (gd::to_float(get(overlay, "width_fraction", Value::of_float(0.0))) <= 0.0) {
			warn("Terrain grammar overlay " + overlay_id + " must define width_fraction > 0.");
		}
		if (overlay_id == "road_dirt") {
			guard("_validate_road_overlay_tile_art", [&] { road_overlay_tile_art(overlay, overlay_id); });
		}
	}
	if (!contains(overlay_ids, "road_dirt")) {
		warn("Terrain grammar must define the road_dirt overlay.");
	}
}

void Check::editor_base_terrain_options(const Value &grammar, const std::vector<std::string> &terrain_ids) {
	struct Option {
		const char *id;
		const char *label;
		const char *family;
		const char *atlas;
	};
	static const Option expected_options[] = {
		{"grass", "Grass", "grass", "grastl"},
		{"snow", "Snow", "snow", "snowtl"},
		{"sand", "Sand", "sand", "sandtl"},
		{"dirt", "Dirt", "dirt", "dirttl"},
		{"rough", "Rough", "rough", "rougtl"},
		{"lava", "Lava", "lava", "lavatl"},
		{"underground", "Underground", "subterranean", "subbtl"},
		{"water", "Water", "water", "watrtl"},
		{"rock", "Rock/None", "rock", "rocktl"},
	};
	const size_t expected_count = sizeof(expected_options) / sizeof(expected_options[0]);
	const Value options = get(grammar, "editor_base_terrain_options", empty_array_);
	if (!is_array(options)) {
		warn("Terrain grammar must define editor_base_terrain_options for the map editor picker.");
		return;
	}
	const size_t option_count = d_.array(options.ref).items.size();
	if (option_count != expected_count) {
		warn("Terrain grammar editor_base_terrain_options must expose the HoMM3-style base terrain family set.");
	}
	const Value homm3 = get(grammar, "homm3_local_prototype", empty_dict_);
	const Value terrain_id_map = is_dict(homm3) ? get(homm3, "terrain_id_map", empty_dict_) : empty_dict_;
	const Value terrain_families = is_dict(homm3) ? get(homm3, "terrain_families", empty_dict_) : empty_dict_;
	for (size_t index = 0; index < std::min(option_count, expected_count); ++index) {
		const Value option = d_.array(options.ref).items[index];
		if (!is_dict(option)) {
			warn("Terrain grammar editor_base_terrain_options contains a non-dictionary option.");
			continue;
		}
		const Option &expected = expected_options[index];
		const std::string terrain_id = text(option, "id");
		const std::string label = text(option, "label");
		const std::string family_id = text(option, "homm3_family");
		const std::string atlas_id = text(option, "homm3_atlas");
		if (terrain_id != expected.id || label != expected.label) {
			warn("Terrain grammar editor base terrain option " + std::to_string(index) + " must be " + expected.id + " labeled " + expected.label + ".");
		}
		if (!contains(terrain_ids, terrain_id)) {
			warn("Terrain grammar editor base terrain option " + terrain_id + " must reference an authored terrain id.");
		}
		if (family_id != expected.family || atlas_id != expected.atlas) {
			warn("Terrain grammar editor base terrain option " + terrain_id + " must map to HoMM3 family " + expected.family + " / atlas " + expected.atlas + ".");
		}
		const Value mapping = is_dict(terrain_id_map) ? get(terrain_id_map, terrain_id, empty_dict_) : empty_dict_;
		if (is_dict(mapping) && text(mapping, "family") != family_id) {
			warn("Terrain grammar editor base terrain option " + terrain_id + " must agree with its HoMM3 terrain_id_map family.");
		}
		const Value family = is_dict(terrain_families) ? get(terrain_families, family_id, empty_dict_) : empty_dict_;
		if (is_dict(family) && text(family, "atlas") != atlas_id) {
			warn("Terrain grammar editor base terrain option " + terrain_id + " must agree with its HoMM3 family atlas.");
		}
	}
}

void Check::terrain_tile_art(const Value &terrain_class, const std::string &terrain_id) {
	const Value tile_art = get(terrain_class, "tile_art", empty_dict_);
	if (!is_dict(tile_art)) {
		warn("Terrain grammar " + terrain_id + " must define tile_art for the original terrain tile bank.");
		return;
	}
	const Value base_tiles = get(tile_art, "base_tiles", empty_array_);
	if (!is_array(base_tiles) || empty(base_tiles)) {
		warn("Terrain grammar " + terrain_id + " tile_art must define base_tiles.");
	} else {
		for (const Value &entry : each(base_tiles)) {
			if (!is_dict(entry)) {
				warn("Terrain grammar " + terrain_id + " tile_art contains a non-dictionary base tile.");
				continue;
			}
			const std::string path = text(entry, "path");
			if (text(entry, "variant_key").empty()) {
				warn("Terrain grammar " + terrain_id + " base tile " + path + " must define variant_key.");
			}
			art_path(path, "Terrain grammar " + terrain_id + " base tile");
		}
	}
	const Value edge_overlays = get(tile_art, "edge_overlays", empty_dict_);
	if (!is_dict(edge_overlays)) {
		warn("Terrain grammar " + terrain_id + " tile_art must define edge_overlays.");
		return;
	}
	for (const char *direction : {"N", "E", "S", "W"}) {
		art_path(text(edge_overlays, direction), "Terrain grammar " + terrain_id + " edge overlay " + direction);
	}
}

void Check::road_overlay_tile_art(const Value &overlay, const std::string &overlay_id) {
	const Value tile_art = get(overlay, "tile_art", empty_dict_);
	if (!is_dict(tile_art)) {
		warn("Terrain grammar overlay " + overlay_id + " must define tile_art.");
		return;
	}
	art_path(text(tile_art, "center"), "Terrain grammar overlay " + overlay_id + " center tile");
	const Value connectors = get(tile_art, "connectors", empty_dict_);
	if (!is_dict(connectors)) {
		warn("Terrain grammar overlay " + overlay_id + " tile_art must define connectors.");
		return;
	}
	for (const char *direction : {"N", "E", "S", "W", "NE", "SE", "SW", "NW"}) {
		art_path(text(connectors, direction), "Terrain grammar overlay " + overlay_id + " connector " + direction);
	}
	const Value connection_pieces = get(tile_art, "connection_pieces", empty_dict_);
	if (is_dict(connection_pieces)) {
		for (const char *connection_key : {"NE+SW", "NW+SE"}) {
			art_path(text(connection_pieces, connection_key), "Terrain grammar overlay " + overlay_id + " connection piece " + connection_key);
		}
	}
}

void Check::art_path(const std::string &path, const std::string &label) {
	if (path.empty()) {
		warn(label + " must define a runtime art path.");
		return;
	}
	if (!begins_with(path, "res://")) {
		warn(label + " path " + path + " must be a res:// path.");
		return;
	}
	if (!resource_exists(path)) {
		warn(label + " path " + path + " does not exist.");
	}
}

void Check::biome(const Value &biome) {
	const std::string biome_id = text(biome, "id");
	if (text(biome, "name").empty()) {
		warn("Biome " + biome_id + " must define a name.");
	}
	const Value map_tile_ids = get(biome, "map_tile_ids", empty_array_);
	if (!is_array(map_tile_ids) || empty(map_tile_ids)) {
		warn("Biome " + biome_id + " must define at least one map_tile_id.");
	} else {
		for (const Value &tile_id_value : each(map_tile_ids)) {
			if (str(tile_id_value).empty()) {
				warn("Biome " + biome_id + " cannot contain an empty map_tile_id.");
			}
		}
	}
	if (!has(biome, "passable")) {
		warn("Biome " + biome_id + " must explicitly define passable.");
	}
	for (const Value &family_id_value : each(get(biome, "allowed_site_families", empty_array_))) {
		const std::string family_id = str(family_id_value);
		if (!family_id.empty() && !supported_resource_site_family(family_id)) {
			warn("Biome " + biome_id + " references unsupported site family " + family_id + ".");
		}
	}
	for (const char *list_key : {"encounter_palette_tags", "decoration_palette", "blocker_palette", "route_roles"}) {
		const Value values = get(biome, list_key, empty_array_);
		if (!is_array(values) || empty(values)) {
			warn("Biome " + biome_id + " must define non-empty " + list_key + ".");
		}
	}
}

bool Check::unit_is_neutral(const Value &unit) {
	return ask("_unit_is_neutral", [&] { return flag(unit, "neutral") || text(unit, "affiliation") == "neutral"; });
}

void Check::recruit_payload(const std::string &label, const Value &recruits, const RowIndex &unit_index, bool require_neutral_units) {
	guard("_validate_recruit_payload", [&] {
		if (recruits.kind == Kind::Nil) {
			return;
		}
		if (!is_dict(recruits)) {
			warn(label + " must be a dictionary.");
			return;
		}
		for (const Value &unit_id_value : keys(recruits)) {
			const std::string unit_id = str(unit_id_value);
			if (unit_id.empty() || !unit_index.has(unit_id)) {
				warn(label + " references missing unit " + unit_id + ".");
				continue;
			}
			if (gd::to_int(d_, at(recruits, unit_id_value)) <= 0) {
				warn(label + " must define positive recruit counts for " + unit_id + ".");
			}
			if (require_neutral_units && !unit_is_neutral(row(unit_index, unit_id))) {
				warn(label + " must use neutral units; " + unit_id + " is faction-linked.");
			}
		}
	});
}

void Check::resource_site(const Value &site, const RowIndex &unit_index, const RowIndex &spell_index, const RowIndex &neutral_dwelling_index, const RowIndex &army_group_index, const RowIndex &encounter_index) {
	const std::string site_id = text(site, "id");
	if (text(site, "name").empty()) {
		warn("Resource site " + site_id + " must define a name.");
	}
	std::string family = str(get(site, "family", d_.string("one_shot_pickup")));
	if (family.empty()) {
		family = "one_shot_pickup";
	}
	if (!supported_resource_site_family(family)) {
		warn("Resource site " + site_id + " uses unsupported family " + family + ".");
	}

	for (const char *resource_key : {"rewards", "claim_rewards", "control_income", "service_cost"}) {
		const Value resources = get(site, resource_key, empty_dict_);
		if (has(site, resource_key) && !is_dict(resources)) {
			warn("Resource site " + site_id + " " + resource_key + " must be a dictionary.");
		} else if (is_dict(resources)) {
			for (const Value &key : keys(resources)) {
				if (str(key).empty()) {
					warn("Resource site " + site_id + " " + resource_key + " cannot contain an empty resource key.");
				}
				if (gd::to_int(d_, at(resources, key)) < 0) {
					warn("Resource site " + site_id + " " + resource_key + " values must be >= 0 for " + str(key) + ".");
				}
			}
		}
	}

	for (const char *recruit_key : {"claim_recruits", "weekly_recruits"}) {
		const Value recruits = get(site, recruit_key, empty_dict_);
		if (has(site, recruit_key) && !is_dict(recruits)) {
			warn("Resource site " + site_id + " " + recruit_key + " must be a dictionary.");
		} else if (is_dict(recruits)) {
			recruit_payload("Resource site " + site_id + " " + recruit_key, recruits, unit_index, false);
		}
	}

	if (has(site, "claim_flags")) {
		const Value claim_flags = get(site, "claim_flags", empty_dict_);
		if (!is_dict(claim_flags)) {
			warn("Resource site " + site_id + " claim_flags must be a dictionary.");
		} else {
			for (const Value &flag_key : keys(claim_flags)) {
				if (strip_edges(str(flag_key)).empty()) {
					warn("Resource site " + site_id + " claim_flags cannot contain an empty flag key.");
				}
			}
		}
	}

	const Value neutral_roster = get(site, "neutral_roster", empty_dict_);
	if (has(site, "neutral_roster")) {
		if (!is_dict(neutral_roster)) {
			warn("Resource site " + site_id + " neutral_roster must be a dictionary.");
		} else {
			recruit_payload("Resource site " + site_id + " neutral_roster claim_recruits", get(neutral_roster, "claim_recruits", empty_dict_), unit_index, true);
			recruit_payload("Resource site " + site_id + " neutral_roster weekly_recruits", get(neutral_roster, "weekly_recruits", empty_dict_), unit_index, true);
			const std::string guard_army_group_id = text(neutral_roster, "guard_army_group_id");
			if (!guard_army_group_id.empty() && !army_group_index.has(guard_army_group_id)) {
				warn("Resource site " + site_id + " neutral_roster references missing guard army group " + guard_army_group_id + ".");
			}
			const std::string guard_encounter_id = text(neutral_roster, "guard_encounter_id");
			if (!guard_encounter_id.empty() && !encounter_index.has(guard_encounter_id)) {
				warn("Resource site " + site_id + " neutral_roster references missing guard encounter " + guard_encounter_id + ".");
			}
		}
	}

	std::vector<std::string> lesson_spell_ids;
	const std::string legacy_spell_id = text(site, "learn_spell_id");
	if (!legacy_spell_id.empty()) {
		lesson_spell_ids.push_back(legacy_spell_id);
	}
	const Value authored_spell_ids = get(site, "learn_spell_ids", empty_array_);
	if (has(site, "learn_spell_ids") && !is_array(authored_spell_ids)) {
		warn("Resource site " + site_id + " learn_spell_ids must be an array.");
	} else if (is_array(authored_spell_ids)) {
		for (const Value &spell_id_value : each(authored_spell_ids)) {
			const std::string authored_spell_id = str(spell_id_value);
			if (!authored_spell_id.empty() && !contains(lesson_spell_ids, authored_spell_id)) {
				lesson_spell_ids.push_back(authored_spell_id);
			}
		}
	}
	for (const std::string &spell_id : lesson_spell_ids) {
		if (!spell_index.has(spell_id)) {
			warn("Resource site " + site_id + " references missing lesson spell " + spell_id + ".");
		}
	}
	// A site teaches a guild spell of each tier it names, picked where it stands
	// (docs/magic-system.md, Guilds and learning).
	const Value lesson_tiers = get(site, "learn_spell_tiers", empty_array_);
	if (has(site, "learn_spell_tiers") && !is_array(lesson_tiers)) {
		warn("Resource site " + site_id + " learn_spell_tiers must be an array.");
	} else if (is_array(lesson_tiers)) {
		for (const Value &tier_value : each(lesson_tiers)) {
			const int64_t tier = gd::to_int(d_, tier_value);
			if (tier < 1 || tier > 5) {
				warn("Resource site " + site_id + " learn_spell_tiers must hold tiers 1 to 5.");
			}
		}
	}

	if (family == "mine") {
		if (!flag(site, "persistent_control")) {
			warn("Mine site " + site_id + " must be persistent-control content.");
		}
		const Value control_income = get(site, "control_income", empty_dict_);
		if (!is_dict(control_income) || empty(control_income)) {
			warn("Mine site " + site_id + " must define control_income.");
		}
	} else if (family == "neutral_dwelling") {
		const std::string dwelling_family_id = text(site, "neutral_dwelling_family_id");
		if (!dwelling_family_id.empty() && !neutral_dwelling_index.has(dwelling_family_id)) {
			warn("Neutral dwelling site " + site_id + " references missing neutral dwelling family " + dwelling_family_id + ".");
		}
		const std::string scope = text(site, "dwelling_scope");
		if (!scope.empty() && !one_of(scope, {"neutral", "faction_linked", "biome_linked"})) {
			warn("Neutral dwelling site " + site_id + " uses unsupported dwelling_scope " + scope + ".");
		}
		const Value dwelling_recruits = get(site, "weekly_recruits", empty_dict_);
		const bool refugee_camp = text(site, "dwelling_kind") == "refugee_camp";
		if (!refugee_camp && !(is_dict(dwelling_recruits) && !empty(dwelling_recruits))) {
			warn("Neutral dwelling site " + site_id + " must define the creatures it musters in weekly_recruits.");
		}
		if (has(site, "claim_recruits")) {
			warn("Neutral dwelling site " + site_id + " must not grant claim_recruits; creatures are hired at the dwelling.");
		}
	} else if (family == "scouting_structure") {
		if (!flag(site, "persistent_control")) {
			warn("Scouting site " + site_id + " must be persistent-control content.");
		}
		if (integer(site, "vision_radius", 0) <= 0) {
			warn("Scouting site " + site_id + " must define vision_radius > 0.");
		}
	} else if (family == "guarded_reward_site") {
		if (!flag(site, "guarded")) {
			warn("Guarded reward site " + site_id + " must set guarded=true.");
		}
		const Value guard_profile = get(site, "guard_profile", empty_dict_);
		if (!is_dict(guard_profile) || empty(guard_profile)) {
			warn("Guarded reward site " + site_id + " must define guard_profile.");
		}
	} else if (family == "transit_object") {
		const Value transit_profile = get(site, "transit_profile", empty_dict_);
		if (!is_dict(transit_profile) || empty(transit_profile)) {
			warn("Transit site " + site_id + " must define transit_profile.");
		}
	} else if (family == "repeatable_service") {
		if (!flag(site, "repeatable")) {
			warn("Repeatable service site " + site_id + " must set repeatable=true.");
		}
		if (integer(site, "visit_cooldown_days", 0) <= 0) {
			warn("Repeatable service site " + site_id + " must define visit_cooldown_days > 0.");
		}
	}
}

void Check::map_object(const Value &map_object, const RowIndex &biome_index, const RowIndex &resource_site_index, const RowIndex &faction_index) {
	const std::string object_id = text(map_object, "id");
	if (text(map_object, "name").empty()) {
		warn("Map object " + object_id + " must define a name.");
	}
	const std::string family = text(map_object, "family");
	if (family.empty() || !supported_map_object_family(family)) {
		warn("Map object " + object_id + " uses unsupported family " + family + ".");
	}
	const Value biome_ids = get(map_object, "biome_ids", empty_array_);
	if (!is_array(biome_ids) || empty(biome_ids)) {
		warn("Map object " + object_id + " must define at least one biome_id.");
	} else {
		for (const Value &biome_id_value : each(biome_ids)) {
			const std::string biome_id = str(biome_id_value);
			if (biome_id.empty() || !biome_index.has(biome_id)) {
				warn("Map object " + object_id + " references missing biome " + biome_id + ".");
			}
		}
	}
	const std::string site_id = text(map_object, "resource_site_id");
	if (!site_id.empty() && !resource_site_index.has(site_id)) {
		warn("Map object " + object_id + " references missing resource_site_id " + site_id + ".");
	}
	const std::string faction_id = text(map_object, "faction_id");
	if (!faction_id.empty() && !faction_index.has(faction_id)) {
		warn("Map object " + object_id + " references missing faction_id " + faction_id + ".");
	}
	const Value footprint = get(map_object, "footprint", empty_dict_);
	if (!is_dict(footprint)) {
		warn("Map object " + object_id + " must define a footprint dictionary.");
	} else if (integer(footprint, "width", 0) <= 0 || integer(footprint, "height", 0) <= 0) {
		warn("Map object " + object_id + " footprint dimensions must be > 0.");
	}
	if (!has(map_object, "passable")) {
		warn("Map object " + object_id + " must explicitly define passable.");
	}
	if (!has(map_object, "visitable")) {
		warn("Map object " + object_id + " must explicitly define visitable.");
	}
	const Value roles = get(map_object, "map_roles", empty_array_);
	if (!is_array(roles) || empty(roles)) {
		warn("Map object " + object_id + " must define non-empty map_roles.");
	}
}

void Check::neutral_dwelling(const Value &dwelling, const RowIndex &unit_index, const RowIndex &resource_site_index, const RowIndex &map_object_index, const RowIndex &army_group_index, const RowIndex &encounter_index, const RowIndex &biome_index) {
	const std::string dwelling_id = text(dwelling, "id");
	if (text(dwelling, "name").empty()) {
		warn("Neutral dwelling " + dwelling_id + " must define a name.");
	}
	if (text(dwelling, "summary").empty()) {
		warn("Neutral dwelling " + dwelling_id + " must define a summary.");
	}
	for (const Value &biome_id_value : each(get(dwelling, "biome_ids", empty_array_))) {
		const std::string biome_id = str(biome_id_value);
		if (biome_id.empty() || !biome_index.has(biome_id)) {
			warn("Neutral dwelling " + dwelling_id + " references missing biome " + biome_id + ".");
		}
	}
	const Value unit_ids = get(dwelling, "unit_ids", empty_array_);
	if (!is_array(unit_ids) || empty(unit_ids)) {
		warn("Neutral dwelling " + dwelling_id + " must define unit_ids.");
	} else {
		for (const Value &unit_id_value : each(unit_ids)) {
			const std::string unit_id = str(unit_id_value);
			if (unit_id.empty() || !unit_index.has(unit_id)) {
				warn("Neutral dwelling " + dwelling_id + " references missing unit " + unit_id + ".");
			} else if (!unit_is_neutral(row(unit_index, unit_id))) {
				warn("Neutral dwelling " + dwelling_id + " unit " + unit_id + " must be authored as neutral.");
			}
		}
	}
	for (const Value &site_id_value : each(get(dwelling, "site_ids", empty_array_))) {
		const std::string site_id = str(site_id_value);
		if (site_id.empty() || !resource_site_index.has(site_id)) {
			warn("Neutral dwelling " + dwelling_id + " references missing site " + site_id + ".");
			continue;
		}
		const Value site = row(resource_site_index, site_id);
		if (text(site, "family") != "neutral_dwelling") {
			warn("Neutral dwelling " + dwelling_id + " site " + site_id + " must use family neutral_dwelling.");
		}
		const std::string site_family_id = text(site, "neutral_dwelling_family_id");
		if (!site_family_id.empty() && site_family_id != dwelling_id) {
			warn("Neutral dwelling " + dwelling_id + " site " + site_id + " references a different neutral_dwelling_family_id.");
		}
	}
	for (const Value &object_id_value : each(get(dwelling, "map_object_ids", empty_array_))) {
		const std::string object_id = str(object_id_value);
		if (object_id.empty() || !map_object_index.has(object_id)) {
			warn("Neutral dwelling " + dwelling_id + " references missing map object " + object_id + ".");
			continue;
		}
		if (text(row(map_object_index, object_id), "family") != "neutral_dwelling") {
			warn("Neutral dwelling " + dwelling_id + " map object " + object_id + " must use family neutral_dwelling.");
		}
	}
	for (const Value &group_id_value : each(get(dwelling, "army_group_ids", empty_array_))) {
		const std::string group_id = str(group_id_value);
		if (group_id.empty() || !army_group_index.has(group_id)) {
			warn("Neutral dwelling " + dwelling_id + " references missing army group " + group_id + ".");
			continue;
		}
		if (text(row(army_group_index, group_id), "affiliation") != "neutral") {
			warn("Neutral dwelling " + dwelling_id + " army group " + group_id + " must be neutral.");
		}
	}
	for (const Value &encounter_id_value : each(get(dwelling, "encounter_ids", empty_array_))) {
		const std::string encounter_id = str(encounter_id_value);
		if (encounter_id.empty() || !encounter_index.has(encounter_id)) {
			warn("Neutral dwelling " + dwelling_id + " references missing encounter " + encounter_id + ".");
			continue;
		}
		const std::string encounter_group_id = text(row(encounter_index, encounter_id), "enemy_group_id");
		if (!encounter_group_id.empty() && army_group_index.has(encounter_group_id)) {
			if (text(row(army_group_index, encounter_group_id), "affiliation") != "neutral") {
				warn("Neutral dwelling " + dwelling_id + " encounter " + encounter_id + " must use a neutral army group.");
			}
		}
	}
}

void Check::faction(const Value &faction, const RowIndex &town_index, const RowIndex &hero_index, const Value &terrain_grammar) {
	const std::string faction_id = text(faction, "id");
	for (const Value &town_id_value : each(get(faction, "town_ids", empty_array_))) {
		const std::string town_id = str(town_id_value);
		if (!town_id.empty() && !town_index.has(town_id)) {
			warn("Faction " + faction_id + " references missing town id " + town_id + ".");
		}
	}
	for (const Value &hero_id_value : each(get(faction, "hero_ids", empty_array_))) {
		const std::string hero_id = str(hero_id_value);
		if (!hero_id.empty() && !hero_index.has(hero_id)) {
			warn("Faction " + faction_id + " references missing hero id " + hero_id + ".");
		}
	}
	const std::string preferred_school_id = text(faction, "preferred_spell_school_id");
	if (!one_of(preferred_school_id, kSpellSchoolIds)) {
		warn("Faction " + faction_id + " must name a spell school as preferred_spell_school_id, not '" + preferred_school_id + "'.");
	}
	// The terrains its heroes step on as on grass (docs/overworld-terrain-movement.md), each a terrain class once.
	const Value home_terrains = get(faction, "home_terrain_ids", empty_array_);
	if (!is_array(home_terrains)) {
		warn("Faction " + faction_id + " must give home_terrain_ids as an array of terrain ids.");
		return;
	}
	std::vector<std::string> seen;
	for (const Value &terrain_value : each(home_terrains)) {
		const std::string terrain_id = str(terrain_value);
		bool known = false;
		for (const Value &terrain_class : each(get(terrain_grammar, "terrain_classes", empty_array_))) {
			known = known || (is_dict(terrain_class) && text(terrain_class, "id") == terrain_id);
		}
		if (!known || contains(seen, terrain_id)) {
			warn("Faction " + faction_id + " home_terrain_ids must name terrain classes of terrain_grammar.json once each, not '" + terrain_id + "'.");
		}
		seen.push_back(terrain_id);
	}
}

void Check::hero(const Value &hero, const RowIndex &faction_index, const RowIndex &spell_index) {
	const std::string hero_id = text(hero, "id");
	const std::string faction_id = text(hero, "faction_id");
	if (faction_id.empty() || !faction_index.has(faction_id)) {
		warn("Hero " + hero_id + " references missing faction id " + faction_id + ".");
	} else if (!in(hero_id, get(row(faction_index, faction_id), "hero_ids", empty_array_))) {
		warn("Hero " + hero_id + " must be listed in faction " + faction_id + " hero_ids.");
	}
	if (integer(hero, "base_movement", 0) <= 0) {
		warn("Hero " + hero_id + " must define base_movement > 0.");
	}
	const Value recruit_cost = get(hero, "recruit_cost", empty_dict_);
	if (has(hero, "recruit_cost") && !is_dict(recruit_cost)) {
		warn("Hero " + hero_id + " recruit_cost must be a dictionary.");
	} else if (is_dict(recruit_cost)) {
		for (const Value &resource_key : keys(recruit_cost)) {
			if (str(resource_key).empty()) {
				warn("Hero " + hero_id + " recruit_cost cannot contain an empty resource key.");
			}
			if (gd::to_int(d_, at(recruit_cost, resource_key)) < 0) {
				warn("Hero " + hero_id + " recruit_cost must be >= 0 for " + str(resource_key) + ".");
			}
		}
	}
	for (const Value &spell_id_value : each(get(hero, "starting_spell_ids", empty_array_))) {
		const std::string spell_id = str(spell_id_value);
		if (!spell_id.empty() && !spell_index.has(spell_id)) {
			warn("Hero " + hero_id + " references missing starting spell id " + spell_id + ".");
		}
	}
}

void Check::unit(const Value &unit, const RowIndex &faction_index) {
	const std::string unit_id = text(unit, "id");
	const std::string faction_id = text(unit, "faction_id");
	if (unit_is_neutral(unit)) {
		if (!faction_id.empty()) {
			warn("Neutral unit " + unit_id + " should not reference faction id " + faction_id + ".");
		}
	} else if (faction_id.empty() || !faction_index.has(faction_id)) {
		warn("Unit " + unit_id + " references missing faction id " + faction_id + ".");
	}
	if (integer(unit, "hp", 0) <= 0) {
		warn("Unit " + unit_id + " must define hp > 0.");
	}
	if (integer(unit, "max_damage", 0) <= 0) {
		warn("Unit " + unit_id + " must define max_damage > 0.");
	}
}

void Check::hero_art_manifest(const RowIndex &hero_index, const RowIndex &hero_art_index) {
	for (const std::string &hero_id : hero_index.ids()) {
		if (!hero_art_index.has(hero_id)) {
			warn("Hero art manifest is missing hero " + hero_id + ".");
			continue;
		}
		const std::string path = text(row(hero_art_index, hero_id), "portrait");
		if (path.empty() || !begins_with(path, "res://")) {
			warn("Hero art " + hero_id + " must define portrait as a res:// path.");
		} else if (!resource_exists(path)) {
			warn("Hero art " + hero_id + " portrait file is missing: " + path + ".");
		}
	}
	for (const std::string &hero_id : hero_art_index.ids()) {
		if (!hero_index.has(hero_id)) {
			warn("Hero art manifest references unknown hero " + hero_id + ".");
		}
	}
}

void Check::unit_art_manifest(const RowIndex &unit_index, const RowIndex &unit_art_index) {
	for (const std::string &unit_id : unit_index.ids()) {
		if (!unit_art_index.has(unit_id)) {
			warn("Unit art manifest is missing unit " + unit_id + ".");
			continue;
		}
		const Value record = row(unit_art_index, unit_id);
		for (const char *surface : {"portrait", "battle_icon", "battle_standee", "overworld_icon"}) {
			const std::string path = text(record, surface);
			if (path.empty() || !begins_with(path, "res://")) {
				warn("Unit art " + unit_id + " must define " + surface + " as a res:// path.");
			} else if (!resource_exists(path)) {
				warn("Unit art " + unit_id + " " + surface + " file is missing: " + path + ".");
			}
		}
	}
	for (const std::string &unit_id : unit_art_index.ids()) {
		if (!unit_index.has(unit_id)) {
			warn("Unit art manifest references unknown unit " + unit_id + ".");
		}
	}
}

void Check::unit_animation_manifest(const RowIndex &unit_index, const Value &manifest, const RowIndex &unit_animation_index) {
	if (text(manifest, "schema_id") != "unit_animation_manifest_v1") {
		warn("Unit animation manifest has unexpected schema id " + d_.text(gd::stringify(d_, get(manifest, "schema_id", empty_text_))) + ".");
	}
	if (integer(manifest, "frames_per_state", 0) <= 0) {
		warn("Unit animation manifest must define frames_per_state > 0.");
	}
	const Value listed_states = get(manifest, "states", empty_array_);
	const size_t state_count = is_array(listed_states) ? d_.array(listed_states.ref).items.size() : 0;
	if (state_count == 0) {
		warn("Unit animation manifest must define battle troop states.");
	}
	for (const std::string &unit_id : unit_index.ids()) {
		if (!unit_animation_index.has(unit_id)) {
			warn("Unit animation manifest is missing unit " + unit_id + ".");
			continue;
		}
		const Value record = row(unit_animation_index, unit_id);
		const std::string path = text(record, "sprite_sheet");
		if (path.empty() || !begins_with(path, "res://")) {
			warn("Unit animation " + unit_id + " must define sprite_sheet as a res:// path.");
		} else if (!resource_exists(path)) {
			warn("Unit animation " + unit_id + " sprite sheet file is missing: " + path + ".");
		}
		const Value record_states = get(record, "states", empty_array_);
		const size_t record_state_count = is_array(record_states) ? d_.array(record_states.ref).items.size() : 0;
		if (record_state_count != state_count) {
			warn("Unit animation " + unit_id + " state count " + std::to_string(record_state_count) + " does not match manifest state count " + std::to_string(state_count) + ".");
		}
	}
	for (const std::string &unit_id : unit_animation_index.ids()) {
		if (!unit_index.has(unit_id)) {
			warn("Unit animation manifest references unknown unit " + unit_id + ".");
		}
	}
}

void Check::army_group(const Value &army_group, const RowIndex &faction_index, const RowIndex &unit_index) {
	const std::string group_id = text(army_group, "id");
	const std::string faction_id = text(army_group, "faction_id");
	const std::string affiliation = text(army_group, "affiliation");
	if (affiliation == "neutral") {
		if (!faction_id.empty()) {
			warn("Neutral army group " + group_id + " should not reference faction id " + faction_id + ".");
		}
	} else if (faction_id.empty()) {
		warn("Army group " + group_id + " must define faction_id or affiliation=neutral.");
	} else if (!faction_index.has(faction_id)) {
		warn("Army group " + group_id + " references missing faction id " + faction_id + ".");
	}

	const Value stacks = get(army_group, "stacks", empty_array_);
	if (!is_array(stacks) || empty(stacks)) {
		warn("Army group " + group_id + " has no stacks.");
		return;
	}
	for (const Value &stack : each(stacks)) {
		if (!is_dict(stack)) {
			continue;
		}
		const std::string unit_id = text(stack, "unit_id");
		if (unit_id.empty() || !unit_index.has(unit_id)) {
			warn("Army group " + group_id + " references missing unit id " + unit_id + ".");
		} else if (affiliation == "neutral" && !unit_is_neutral(row(unit_index, unit_id))) {
			warn("Neutral army group " + group_id + " stack " + unit_id + " must use neutral units.");
		}
		if (integer(stack, "count", 0) <= 0) {
			warn("Army group " + group_id + " has non-positive stack count for unit " + unit_id + ".");
		}
	}
}

void Check::building(const Value &building, const RowIndex &building_index, const RowIndex &unit_index) {
	const std::string building_id = text(building, "id");
	const std::string unlock_unit_id = text(building, "unlock_unit_id");
	if (!unlock_unit_id.empty() && !unit_index.has(unlock_unit_id)) {
		warn("Building " + building_id + " references missing unlock_unit_id " + unlock_unit_id + ".");
	}
	if (has(building, "spell_tier") && integer(building, "spell_tier", 0) <= 0) {
		warn("Building " + building_id + " must define spell_tier > 0 when present.");
	}
	const Value requires = get(building, "requires", empty_array_);
	if (is_array(requires)) {
		for (const Value &requirement : each(requires)) {
			const std::string requirement_id = str(requirement);
			if (!requirement_id.empty() && !building_index.has(requirement_id)) {
				warn("Building " + building_id + " references missing requirement " + requirement_id + ".");
			}
		}
	}
}

void Check::town(const Value &town, const RowIndex &faction_index, const RowIndex &building_index, const RowIndex &unit_index) {
	const std::string town_id = text(town, "id");
	const std::string faction_id = text(town, "faction_id");
	if (faction_id.empty() || !faction_index.has(faction_id)) {
		warn("Town " + town_id + " references missing faction id " + faction_id + ".");
	}
	for (const Value &building_id_value : each(get(town, "starting_building_ids", empty_array_))) {
		const std::string building_id = str(building_id_value);
		if (!building_id.empty() && !building_index.has(building_id)) {
			warn("Town " + town_id + " references missing starting building id " + building_id + ".");
		}
	}
	for (const Value &building_id_value : each(get(town, "buildable_building_ids", empty_array_))) {
		const std::string building_id = str(building_id_value);
		if (!building_id.empty() && !building_index.has(building_id)) {
			warn("Town " + town_id + " references missing buildable building id " + building_id + ".");
		}
	}
	for (const Value &garrison_stack : each(get(town, "garrison", empty_array_))) {
		if (!is_dict(garrison_stack)) {
			continue;
		}
		const std::string unit_id = text(garrison_stack, "unit_id");
		if (unit_id.empty() || !unit_index.has(unit_id)) {
			warn("Town " + town_id + " references missing garrison unit id " + unit_id + ".");
		}
	}
}

void Check::encounter(const Value &encounter, const RowIndex &army_group_index, const RowIndex &spell_index) {
	const std::string encounter_id = text(encounter, "id");
	const std::string enemy_group_id = text(encounter, "enemy_group_id");
	if (enemy_group_id.empty() || !army_group_index.has(enemy_group_id)) {
		warn("Encounter " + encounter_id + " references missing enemy_group_id " + enemy_group_id + ".");
	}
	if (integer(encounter, "max_rounds", 0) <= 0) {
		warn("Encounter " + encounter_id + " must define max_rounds > 0.");
	}
	const Value commander = get(encounter, "enemy_commander", empty_dict_);
	if (has(encounter, "enemy_commander") && !is_dict(commander)) {
		warn("Encounter " + encounter_id + " enemy commander must be a dictionary.");
	}
	if (is_dict(commander) && !empty(commander)) {
		if (!is_dict(get(commander, "command", empty_dict_))) {
			warn("Encounter " + encounter_id + " enemy commander must define a command dictionary.");
		}
		for (const Value &spell_id_value : each(get(commander, "starting_spell_ids", empty_array_))) {
			const std::string spell_id = str(spell_id_value);
			if (spell_id.empty() || !spell_index.has(spell_id)) {
				warn("Encounter " + encounter_id + " references missing enemy commander spell id " + spell_id + ".");
				continue;
			}
			if (text(row(spell_index, spell_id), "context") != "battle") {
				warn("Encounter " + encounter_id + " enemy commander spell " + spell_id + " must be a battle spell.");
			}
		}
	}
}

void Check::artifact(const Value &artifact, const RowIndex &spell_index) {
	const std::string artifact_id = text(artifact, "id");
	const std::string slot = text(artifact, "slot");
	if (slot.empty()) {
		warn("Artifact " + artifact_id + " must define a slot.");
	} else if (!one_of(slot, {"boots", "banner", "armor", "trinket", "head", "neck", "cloak", "hand", "ring"})) {
		warn("Artifact " + artifact_id + " uses unsupported slot " + slot + ".");
	}
	// A scroll lends its spell instead of a bonus (docs/magic-system.md).
	if (text(artifact, "artifact_class") == "spell_scroll") {
		const std::string spell_id = text(artifact, "spell_id");
		if (!spell_index.has(spell_id)) {
			warn("Spell scroll " + artifact_id + " must name an existing spell, not " + spell_id + ".");
		}
		if (slot != "trinket") {
			warn("Spell scroll " + artifact_id + " must be a trinket.");
		}
		return;
	}
	const Value bonuses = get(artifact, "bonuses", empty_dict_);
	if (!is_dict(bonuses) || empty(bonuses)) {
		warn("Artifact " + artifact_id + " must define at least one bonus.");
	}
}

void Check::spell_school_icons(const RowIndex &icon_index) {
	for (const char *school_id : kSpellSchoolIds) {
		const Value icon = row(icon_index, school_id);
		if (empty(icon)) {
			warn(std::string("Spell school ") + school_id + " must define an icon manifest row.");
			continue;
		}
		if (text(icon, "icon_id") != std::string("spell_school_sigil_") + school_id) {
			warn(std::string("Spell school ") + school_id + " must own its stable sigil icon id.");
		}
		if (strip_edges(text(icon, "material_language")).empty()) {
			warn(std::string("Spell school ") + school_id + " must define material language.");
		}
		art_path(text(icon, "icon_path"), std::string("Spell school ") + school_id + " sigil");
	}
	for (const std::string &school_id : icon_index.ids()) {
		if (!one_of(school_id, kSpellSchoolIds)) {
			warn("Spell school icon manifest contains unsupported school " + school_id + ".");
		}
	}
}

// The spells retired at the magic switch: each gone from spells.json, each
// replaced by a guild spell an older save's heroes can know.
void Check::retired_spells(const Value &items, const RowIndex &spell_index) {
	if (!is_array(items)) {
		return;
	}
	for (const Value &item : each(items)) {
		const std::string spell_id = text(item, "id");
		const std::string replacement_id = text(item, "replacement_spell_id");
		if (spell_index.has(spell_id)) {
			warn("Retired spell " + spell_id + " is still in spells.json.");
		}
		if (!spell_index.has(replacement_id)) {
			warn("Retired spell " + spell_id + " names missing replacement " + replacement_id + ".");
		} else if (flag(row(spell_index, replacement_id), "scroll_only")) {
			warn("Retired spell " + spell_id + " must be replaced by a guild spell, not the scroll-only " + replacement_id + ".");
		}
	}
}

void Check::spell_icons(const RowIndex &spell_index, const RowIndex &icon_index) {
	for (const std::string &spell_id : icon_index.ids()) {
		const Value icon = row(icon_index, spell_id);
		const Value spell = row(spell_index, spell_id);
		if (empty(spell)) {
			warn("Spell icon manifest references unsupported spell " + spell_id + ".");
			continue;
		}
		if (text(icon, "spell_id") != spell_id) {
			warn("Spell icon " + spell_id + " must retain its exact spell id.");
		}
		if (text(icon, "school_id") != text(spell, "school_id")) {
			warn("Spell icon " + spell_id + " must retain its authored school id.");
		}
		if (text(icon, "icon_id") != "spell_signature_icon_" + trim_prefix(spell_id, "spell_")) {
			warn("Spell icon " + spell_id + " must own its stable signature icon id.");
		}
		art_path(text(icon, "icon_path"), "Spell " + spell_id + " signature icon");
	}
}

void Check::faction_crests(const RowIndex &faction_index, const RowIndex &crest_index) {
	for (const std::string &faction_id : faction_index.ids()) {
		const Value crest = row(crest_index, faction_id);
		if (empty(crest)) {
			warn("Faction " + faction_id + " must define a crest manifest row.");
			continue;
		}
		if (text(crest, "crest_id") != "faction_crest_" + trim_prefix(faction_id, "faction_")) {
			warn("Faction " + faction_id + " must own its stable crest id.");
		}
		if (strip_edges(text(crest, "material_language")).empty()) {
			warn("Faction " + faction_id + " must define crest material language.");
		}
		const std::string icon_path = text(crest, "icon_path");
		if (!begins_with(icon_path, "res://art/factions/runtime/crests/") || !ends_with(icon_path, ".png")) {
			warn("Faction " + faction_id + " crest must use the production faction crest art domain.");
		} else {
			art_path(icon_path, "Faction " + faction_id + " crest");
		}
	}
	for (const std::string &faction_id : crest_index.ids()) {
		if (!faction_index.has(faction_id)) {
			warn("Faction crest manifest contains unsupported faction " + faction_id + ".");
		}
	}
}

void Check::building_category_icons(const RowIndex &icon_index) {
	const std::initializer_list<const char *> expected_category_ids = {"civic", "dwelling", "economy", "support", "magic"};
	for (const char *category_id : expected_category_ids) {
		const Value icon = row(icon_index, category_id);
		if (empty(icon)) {
			warn(std::string("Building category ") + category_id + " must define an icon manifest row.");
			continue;
		}
		if (text(icon, "icon_id") != std::string("building_category_sigil_") + category_id) {
			warn(std::string("Building category ") + category_id + " must own its stable sigil icon id.");
		}
		if (strip_edges(text(icon, "material_language")).empty()) {
			warn(std::string("Building category ") + category_id + " must define material language.");
		}
		art_path(text(icon, "icon_path"), std::string("Building category ") + category_id + " sigil");
	}
	for (const std::string &category_id : icon_index.ids()) {
		if (!one_of(category_id, expected_category_ids)) {
			warn("Building category icon manifest contains unsupported category " + category_id + ".");
		}
	}
}

void Check::building_art_manifest(const RowIndex &building_index, const RowIndex &art_index) {
	for (const std::string &building_id : art_index.ids()) {
		const Value art = row(art_index, building_id);
		if (!building_index.has(building_id) || text(art, "building_id") != building_id) {
			warn("Building art manifest contains unsupported building " + building_id + ".");
			continue;
		}
		if (text(art, "source_kind") != "curated_original_building") {
			warn("Building " + building_id + " must own curated original building art.");
		}
		const std::string source_path = text(art, "source_path");
		const std::string icon_path = text(art, "icon_path");
		if (!begins_with(source_path, "res://art/towns/source/buildings/curated/")) {
			warn("Building " + building_id + " source must use the curated building art domain.");
		} else if (files_.editor()) {
			art_path(source_path, "Building " + building_id + " curated source");
		}
		if (!begins_with(icon_path, "res://art/towns/runtime/buildings/")) {
			warn("Building " + building_id + " icon must use the runtime building art domain.");
		} else {
			art_path(icon_path, "Building " + building_id + " runtime icon");
		}
	}
}

// A map spell (docs/magic-system-spells.md, Map): its mechanic, the numbers that mechanic needs (each growing with
// power by <name>_power_scale and <name>_power_divisor, never below 0), and how it is aimed: at the hero, or at a
// tile the player picks.
void Check::map_effect(const std::string &spell_id, const Value &spell, const Value &effect, const std::string &context) {
	struct MapMechanic {
		const char *id;
		std::initializer_list<const char *> terms;
		const char *target_mode;
	};
	static const MapMechanic kMechanics[] = {
		{ "map_sight", { "tiles" }, "self" },
		{ "map_move", { "tiles" }, "self" },
		{ "map_scout", { "radius" }, "self" },
		{ "map_lens", { "radius" }, "self" },
		{ "map_mine", { "days" }, "self" },
		{ "map_road", { "days" }, "self" },
		{ "map_forest_ways", { "days" }, "self" },
		{ "map_mire_ways", { "days" }, "self" },
		{ "map_slow_zone", { "days", "radius" }, "self" },
		{ "map_watch", { "days", "radius" }, "self" },
		{ "map_flare", { "radius", "range" }, "tile_selected" },
		{ "map_block", { "days" }, "tile_selected" },
		{ "map_jump_forest", { "range" }, "tile_selected" },
		{ "map_town", { "range" }, "tile_selected" },
		{ "map_ferry", { "range" }, "tile_selected" },
		{ "map_jump", { "range" }, "tile_selected" },
	};
	if (context != "overworld") {
		warn("Spell " + spell_id + " map_effect must use overworld context.");
	}
	const std::string mechanic = text(effect, "map");
	for (const MapMechanic &known : kMechanics) {
		if (mechanic != known.id) {
			continue;
		}
		for (const char *term : known.terms) {
			const std::string name(term);
			if (integer(effect, term, 0) <= 0 || integer(effect, (name + "_power_scale").c_str(), 0) < 0 || integer(effect, (name + "_power_divisor").c_str(), 0) < 0) {
				warn("Spell " + spell_id + " " + mechanic + " must define " + name + " > 0, " + name + "_power_scale >= 0 and " + name + "_power_divisor >= 0.");
			}
		}
		if (text(spell, "target_mode") != known.target_mode) {
			warn("Spell " + spell_id + " " + mechanic + " must use target_mode " + known.target_mode + ".");
		}
		// The ground ways name the terrain classes they make cost like grass.
		if (mechanic == "map_forest_ways" || mechanic == "map_mire_ways") {
			const Value terrains = get(effect, "terrains", empty_array_);
			bool named = is_array(terrains) && !empty(terrains);
			for (const Value &terrain : each(terrains)) {
				named = named && !str(terrain).empty();
			}
			if (!named) {
				warn("Spell " + spell_id + " " + mechanic + " must name its terrains.");
			}
		}
		return;
	}
	warn("Spell " + spell_id + " uses unsupported map mechanic " + mechanic + ".");
}

void Check::spell(const Value &spell) {
	const std::string spell_id = text(spell, "id");
	const std::string school_id = text(spell, "school_id");
	const int64_t tier = integer(spell, "tier", 0);
	const std::string accord_family = text(spell, "accord_family");
	const std::string primary_role = text(spell, "primary_role");
	const Value role_categories = get(spell, "role_categories", empty_array_);
	const std::string context = text(spell, "context");
	// The basic tier's school is for spells only: it has no sigil of its own.
	if (!one_of(school_id, kSpellSchoolIds) && school_id != "basic") {
		warn("Spell " + spell_id + " uses unsupported school_id " + school_id + ".");
	}
	if (tier < 1 || tier > 5) {
		warn("Spell " + spell_id + " tier must be between 1 and 5.");
	}
	const Value scroll_only = get(spell, "scroll_only", Value());
	if (scroll_only.kind != Kind::Nil && scroll_only.kind != Kind::Bool) {
		warn("Spell " + spell_id + " scroll_only must be true or false.");
	}
	if (accord_family.empty()) {
		warn("Spell " + spell_id + " must define accord_family.");
	}
	if (primary_role.empty()) {
		warn("Spell " + spell_id + " must define primary_role.");
	}
	if (!is_array(role_categories) || empty(role_categories)) {
		warn("Spell " + spell_id + " must define role_categories.");
	} else if (in("economy_map_utility", role_categories) && context != "overworld") {
		warn("Spell " + spell_id + " economy_map_utility role must use overworld context.");
	}
	if (!one_of(context, {"overworld", "battle"})) {
		warn("Spell " + spell_id + " uses unsupported context " + context + ".");
	}
	if (integer(spell, "mana_cost", 0) <= 0) {
		warn("Spell " + spell_id + " must define mana_cost > 0.");
	}

	const Value effect = get(spell, "effect", empty_dict_);
	if (!is_dict(effect)) {
		warn("Spell " + spell_id + " must define an effect payload.");
		return;
	}
	const std::string type = text(effect, "type");
	// A boost that lasts: modifiers or an amount (SpellRules.battle_spell_modifiers).
	const Value modifiers = get(effect, "modifiers", empty_dict_);
	const bool lasting_boost = (is_dict(modifiers) && !empty(modifiers)) || has(effect, "amount");
	if (type == "restore_movement") {
		if (integer(effect, "amount", 0) <= 0) {
			warn("Spell " + spell_id + " must define restore_movement amount > 0.");
		}
	} else if (type == "reveal_radius") {
		if (gd::to_int(d_, get(effect, "amount", get(effect, "radius", Value::of_int(0)))) <= 0) {
			warn("Spell " + spell_id + " must define reveal_radius amount > 0.");
		}
	} else if (type == "damage_enemy") {
		// Black Tide takes a share of the creatures instead of a sum.
		const int64_t creature_pct = integer(effect, "creature_pct", 0);
		if (creature_pct > 100 || integer(effect, "creature_pct_power_scale", 0) < 0) {
			warn("Spell " + spell_id + " must define creature_pct up to 100 and creature_pct_power_scale >= 0.");
		}
		if (creature_pct <= 0 && integer(effect, "base_damage", 0) <= 0) {
			warn("Spell " + spell_id + " must define damage base_damage > 0.");
		}
		if (integer(effect, "power_scale", -1) < 0) {
			warn("Spell " + spell_id + " must define damage power_scale >= 0.");
		}
	} else if (type == "defense_buff" || type == "initiative_buff" || type == "attack_buff") {
		if (integer(effect, "amount", 0) <= 0) {
			warn("Spell " + spell_id + " must define buff amount > 0.");
		}
		if (integer(effect, "duration_rounds", 0) <= 0) {
			warn("Spell " + spell_id + " must define duration_rounds > 0.");
		}
	} else if (type == "control_enemy") {
		const Value status_effect = get(effect, "status_effect", empty_dict_);
		if (!is_dict(status_effect) || text(status_effect, "effect_id").empty()) {
			warn("Spell " + spell_id + " must define control status_effect.effect_id.");
		}
		if (integer(status_effect, "duration_rounds", 0) <= 0) {
			warn("Spell " + spell_id + " must define control duration_rounds > 0.");
		}
	} else if (type == "recover_ally") {
		if (gd::to_int(d_, get(effect, "base_restore", get(effect, "amount", Value::of_int(0)))) <= 0) {
			warn("Spell " + spell_id + " must define recovery amount > 0.");
		}
		// A plain heal leaves nothing behind; a heal with a ward needs its rounds.
		if (lasting_boost && integer(effect, "duration_rounds", 0) <= 0) {
			warn("Spell " + spell_id + " must define duration_rounds > 0.");
		}
	} else if (type == "cleanse_ally") {
		// The statuses it lifts, or a count of the newest harmful effects.
		const Value cleanse_effect_ids = get(effect, "cleanse_effect_ids", empty_array_);
		const bool names_statuses = is_array(cleanse_effect_ids) && !empty(cleanse_effect_ids);
		if (!names_statuses && integer(effect, "count", 0) <= 0) {
			warn("Spell " + spell_id + " must define cleanse_effect_ids or a count > 0.");
		}
		if ((names_statuses || lasting_boost) && integer(effect, "duration_rounds", 0) <= 0) {
			warn("Spell " + spell_id + " must define duration_rounds > 0.");
		}
	} else if (type == "dispel_enemy") {
		if (integer(effect, "count", 0) <= 0) {
			warn("Spell " + spell_id + " must define dispel count > 0.");
		}
	} else if (type == "move_ally") {
		if (integer(effect, "range", 0) <= 0) {
			warn("Spell " + spell_id + " must define move range > 0.");
		}
	} else if (type == "graft_allies" || type == "transfer_ally" || type == "swap_allies" || type == "swap_enemy") {
		// Two stacks: the first picked as the target mode says, the second when cast.
		const std::string wanted_mode = type == "swap_enemy" ? "enemy_selected" : "ally_selected";
		if (text(spell, "target_mode") != wanted_mode) {
			warn("Spell " + spell_id + " " + type + " must use target_mode " + wanted_mode + ".");
		}
		if (type == "graft_allies" && integer(effect, "duration_rounds", 0) <= 0) {
			warn("Spell " + spell_id + " must define duration_rounds > 0.");
		}
		if (type == "transfer_ally" && integer(effect, "base_restore", 0) <= 0) {
			warn("Spell " + spell_id + " must define transfer base_restore > 0.");
		}
		if ((type == "swap_allies" || type == "swap_enemy") && integer(effect, "range", 0) <= 0) {
			warn("Spell " + spell_id + " must define swap range > 0.");
		}
	} else if (type == "ground_effect") {
		// Ground on hexes the cast picks: what it is, its shape, how long it holds and what it does.
		if (text(spell, "target_mode") != "hex_selected") {
			warn("Spell " + spell_id + " ground_effect must use target_mode hex_selected.");
		}
		const std::string ground = text(effect, "ground");
		if (!one_of(ground, {"fire_ground", "bramble_ground", "pillar", "murk", "trap", "wall", "barrier", "prism", "mire", "snare", "grove", "dome"})) {
			warn("Spell " + spell_id + " uses unsupported ground " + ground + ".");
		}
		const std::string shape = text(effect, "shape");
		if (!shape.empty() && !one_of(shape, {"single", "line", "blob", "area"})) {
			warn("Spell " + spell_id + " uses unsupported ground shape " + shape + ".");
		}
		// A line's length (3 unless it says) and a blob's size.
		const int64_t length = integer(effect, "length", 3);
		if (length < 1 || length > 6) {
			warn("Spell " + spell_id + " ground length must be 1 to 6.");
		}
		if (shape == "blob" && (integer(effect, "count", 0) <= 0 || integer(effect, "count_power_divisor", 0) < 0)) {
			warn("Spell " + spell_id + " must define blob count > 0 and count_power_divisor >= 0.");
		}
		const Value ground_battle_long = get(effect, "battle_long", Value());
		if (ground_battle_long.kind != Kind::Nil && ground_battle_long.kind != Kind::Bool) {
			warn("Spell " + spell_id + " battle_long must be true or false.");
		}
		const bool lasts_battle = flag(effect, "battle_long");
		if (ground != "trap" && ground != "snare" && !lasts_battle && integer(effect, "duration_rounds", 0) <= 0) {
			warn("Spell " + spell_id + " must define duration_rounds > 0.");
		}
		// A snare lays no ground: it gives the stacks its area catches a status.
		if (ground == "snare") {
			const Value snare_status = get(effect, "status_effect", Value());
			if (snare_status.kind != Kind::Dict || text(snare_status, "effect_id").empty() || integer(snare_status, "duration_rounds", 0) <= 0) {
				warn("Spell " + spell_id + " snare must define a status_effect with effect_id and duration_rounds > 0.");
			}
		}
		if (one_of(ground, {"fire_ground", "bramble_ground", "trap", "prism"}) && integer(effect, "base_damage", 0) <= 0) {
			warn("Spell " + spell_id + " must define ground base_damage > 0.");
		}
		if (ground == "pillar" && integer(effect, "defense", 0) <= 0) {
			warn("Spell " + spell_id + " must define pillar defense > 0.");
		}
		// Elder Grove heals its side's stacks in it and lends them defense.
		if (ground == "grove" && (integer(effect, "base_restore", 0) <= 0 || integer(effect, "power_scale", 0) < 0 || integer(effect, "defense", 0) < 0)) {
			warn("Spell " + spell_id + " must define grove base_restore > 0, power_scale >= 0 and defense >= 0.");
		}
		if (ground == "trap") {
			const Value status_effect = get(effect, "status_effect", empty_dict_);
			if (!is_dict(status_effect) || text(status_effect, "effect_id").empty()) {
				warn("Spell " + spell_id + " must define trap status_effect.effect_id.");
			}
		}
	} else if (type == "ally_effect") {
		// A lasting effect on one of the hero's stacks: a mechanic, modifiers or both.
		const Value mechanic = get(effect, "mechanic", empty_dict_);
		if ((!is_dict(mechanic) || empty(mechanic)) && !lasting_boost) {
			warn("Spell " + spell_id + " must define an ally_effect mechanic or modifiers.");
		}
		if (integer(effect, "duration_rounds", 0) <= 0) {
			warn("Spell " + spell_id + " must define duration_rounds > 0.");
		}
	} else if (type == "sacrifice" || type == "doom_enemy" || type == "free_volley") {
		// Aimed at an enemy stack: a payment in health, a doom that tolls later, the caster's shooters.
		if (text(spell, "target_mode") != "enemy_selected") {
			warn("Spell " + spell_id + " " + type + " must use target_mode enemy_selected.");
		}
		if (type == "sacrifice") {
			const int64_t cost_pct = integer(effect, "cost_pct", 0);
			if (cost_pct < 1 || cost_pct > 99 || integer(effect, "damage_pct", 0) <= 0) {
				warn("Spell " + spell_id + " must define sacrifice cost_pct 1 to 99 and damage_pct > 0.");
			}
		}
		// A doom tolls fixed damage, or a share of the creatures (Death's Door).
		const bool doom_share = integer(effect, "doom_pct", 0) > 0;
		if (type == "doom_enemy" && !doom_share && (integer(effect, "base_damage", 0) <= 0 || integer(effect, "power_scale", -1) < 0 || integer(effect, "duration_rounds", 0) <= 0)) {
			warn("Spell " + spell_id + " must define doom base_damage > 0, power_scale >= 0 and duration_rounds > 0.");
		}
		if (type == "doom_enemy" && doom_share && (integer(effect, "doom_pct", 0) > 100 || integer(effect, "doom_pct_power_scale", -1) < 0 || integer(effect, "duration_rounds", 0) <= 0)) {
			warn("Spell " + spell_id + " must define doom_pct 1 to 100, doom_pct_power_scale >= 0 and duration_rounds > 0.");
		}
		if (type == "free_volley" && integer(effect, "volley_pct", 0) <= 0) {
			warn("Spell " + spell_id + " must define volley_pct > 0.");
		}
	} else if (type == "taunt_enemy" || type == "pull_enemy") {
		// Goad's status and the stack it names; Uproot's drag and its Staggered.
		if (text(spell, "target_mode") != "enemy_selected") {
			warn("Spell " + spell_id + " " + type + " must use target_mode enemy_selected.");
		}
		const Value status_effect = get(effect, "status_effect", empty_dict_);
		if (!is_dict(status_effect) || text(status_effect, "effect_id").empty() || integer(status_effect, "duration_rounds", 0) <= 0) {
			warn("Spell " + spell_id + " must define " + type + " status_effect.effect_id and duration_rounds > 0.");
		}
		if (type == "pull_enemy" && integer(effect, "range", 0) <= 0) {
			warn("Spell " + spell_id + " must define pull range > 0.");
		}
	} else if (type == "temp_creatures" || type == "damage_around") {
		// On one of the hero's stacks: creatures for this battle, or a blow at the enemies beside it.
		if (!one_of(text(spell, "target_mode"), {"ally_selected", "ally_active"})) {
			warn("Spell " + spell_id + " " + type + " must use target_mode ally_selected or ally_active.");
		}
		if (type == "temp_creatures" && integer(effect, "base_restore", 0) <= 0) {
			warn("Spell " + spell_id + " must define temp_creatures base_restore > 0.");
		}
		if (type == "damage_around" && (integer(effect, "base_damage", 0) <= 0 || integer(effect, "power_scale", -1) < 0 || integer(effect, "heal_pct", 100) < 0)) {
			warn("Spell " + spell_id + " must define damage_around base_damage > 0, power_scale >= 0 and heal_pct >= 0.");
		}
	} else if (type == "battle_aura") {
		// Over the whole battle for some rounds: the caster's side keeps watch.
		if (text(spell, "target_mode") != "battle") {
			warn("Spell " + spell_id + " battle_aura must use target_mode battle.");
		}
		// Watchful Light heals; Second Sun burns the other side for the battle; Eternal Noon keeps statuses off.
		const std::string aura = text(effect, "aura");
		if (!one_of(aura, {"triage", "sun", "noon", "green_return", "hollow_crown"})) {
			warn("Spell " + spell_id + " uses unsupported aura " + aura + ".");
		}
		if (aura == "triage" && (integer(effect, "base_restore", 0) <= 0 || integer(effect, "duration_rounds", 0) <= 0)) {
			warn("Spell " + spell_id + " must define battle_aura base_restore > 0 and duration_rounds > 0.");
		}
		if (aura == "sun" && (integer(effect, "base_damage", 0) <= 0 || integer(effect, "power_scale", -1) < 0)) {
			warn("Spell " + spell_id + " must define sun base_damage > 0 and power_scale >= 0.");
		}
		if (aura == "noon" && integer(effect, "duration_rounds", 0) <= 0) {
			warn("Spell " + spell_id + " must define noon duration_rounds > 0.");
		}
		// Green Return: a share of the fallen's starting creatures.
		const int64_t return_pct = integer(effect, "return_pct", 0);
		if (aura == "green_return" && (return_pct <= 0 || return_pct > 100 || integer(effect, "return_pct_power_scale", 0) < 0)) {
			warn("Spell " + spell_id + " must define green_return return_pct 1 to 100 and return_pct_power_scale >= 0.");
		}
		// Hollow Crown: the share of a fallen stack's starting creatures its Risen rise with, for their rounds.
		const int64_t crown_pct = integer(effect, "pct", 0);
		if (aura == "hollow_crown" && (crown_pct <= 0 || crown_pct > 100 || integer(effect, "pct_power_scale", 0) < 0 || integer(effect, "duration_rounds", 0) <= 0)) {
			warn("Spell " + spell_id + " must define hollow_crown pct 1 to 100, pct_power_scale >= 0 and duration_rounds > 0.");
		}
	} else if (type == "conjure") {
		// A stack on the field for some rounds: summoned creatures or the Risen on a hex, a decoy or a clockwork copy of
		// a stack, an elder treant with its trees, or the Risen of every fallen stack.
		const std::string kind = text(effect, "conjure");
		if (!one_of(kind, {"summon", "risen", "decoy", "clone", "elder", "risen_all"})) {
			warn("Spell " + spell_id + " uses unsupported conjure " + kind + ".");
		}
		const std::string wanted_mode = (kind == "decoy" || kind == "clone") ? "ally_selected" : (kind == "elder" || kind == "risen_all") ? "battle" : "hex_selected";
		if (text(spell, "target_mode") != wanted_mode) {
			warn("Spell " + spell_id + " conjure " + kind + " must use target_mode " + wanted_mode + ".");
		}
		if (integer(effect, "duration_rounds", 0) <= 0) {
			warn("Spell " + spell_id + " must define duration_rounds > 0.");
		}
		if (one_of(kind, {"summon", "risen", "elder"}) && (integer(effect, "base_health", 0) <= 0 || integer(effect, "power_scale", -1) < 0)) {
			warn("Spell " + spell_id + " must define conjure base_health > 0 and power_scale >= 0.");
		}
		if ((kind == "summon" || kind == "elder") && text(effect, "unit_id").empty()) {
			warn("Spell " + spell_id + " must define the summoned unit_id.");
		}
		// A share of a stack's creatures: Clockwork Twin's of the living, Drowned Host's of the starting ones.
		const int64_t share_pct = integer(effect, "pct", 0);
		if ((kind == "clone" || kind == "risen_all") && (share_pct <= 0 || share_pct > 100 || integer(effect, "pct_power_scale", 0) < 0)) {
			warn("Spell " + spell_id + " must define conjure pct 1 to 100 and pct_power_scale >= 0.");
		}
		if (integer(effect, "trees", 0) < 0) {
			warn("Spell " + spell_id + " conjure trees must be 0 or more.");
		}
		if (integer(effect, "stacks", 1) < 1) {
			warn("Spell " + spell_id + " conjure stacks must be 1 or more.");
		}
		const std::string place = text(effect, "place");
		if (!place.empty() && !one_of(place, {"beside_own", "anywhere", "fallen", "beside_target"})) {
			warn("Spell " + spell_id + " uses unsupported conjure place " + place + ".");
		}
		const Value flies = get(effect, "flies", Value());
		if (flies.kind != Kind::Nil && flies.kind != Kind::Bool) {
			warn("Spell " + spell_id + " flies must be true or false.");
		}
		if (integer(effect, "speed", 0) < 0) {
			warn("Spell " + spell_id + " conjure speed must be 0 or more.");
		}
		const Value immobile = get(effect, "immobile", Value());
		if (immobile.kind != Kind::Nil && immobile.kind != Kind::Bool) {
			warn("Spell " + spell_id + " immobile must be true or false.");
		}
	} else if (type == "rewind") {
		// One of the hero's stacks goes back to how it stood at an earlier round's start.
		if (text(spell, "target_mode") != "ally_selected") {
			warn("Spell " + spell_id + " rewind must use target_mode ally_selected.");
		}
		if (integer(effect, "rounds_back", 0) <= 0 || integer(effect, "rounds_back_power_divisor", 0) < 0) {
			warn("Spell " + spell_id + " must define rewind rounds_back > 0 and rounds_back_power_divisor >= 0.");
		}
	} else if (type == "recast") {
		// Echo casts the side's last spell of the battle again, with more spell power.
		if (text(spell, "target_mode") != "battle") {
			warn("Spell " + spell_id + " recast must use target_mode battle.");
		}
		if (integer(effect, "power_bonus", 0) < 0 || integer(effect, "power_bonus_power_divisor", 0) < 0) {
			warn("Spell " + spell_id + " must define recast power_bonus >= 0 and power_bonus_power_divisor >= 0.");
		}
	} else if (type == "charm_enemy") {
		// An enemy stack attacks a stack of its own side, at a share of its damage.
		if (text(spell, "target_mode") != "enemy_selected") {
			warn("Spell " + spell_id + " charm_enemy must use target_mode enemy_selected.");
		}
		if (integer(effect, "damage_pct", 0) <= 0 || integer(effect, "damage_pct_power_scale", -1) < 0) {
			warn("Spell " + spell_id + " must define charm damage_pct > 0 and damage_pct_power_scale >= 0.");
		}
	} else if (type == "map_effect") {
		map_effect(spell_id, spell, effect, context);
	} else {
		warn("Spell " + spell_id + " uses unsupported effect type " + type + ".");
	}
	// A mechanic holds numbers and flags; a follow-up status names its effect and turns.
	for (const Value &holder : { effect, get(effect, "status_effect", empty_dict_) }) {
		const Value mechanic = get(holder, "mechanic", empty_dict_);
		if (!is_dict(mechanic)) {
			warn("Spell " + spell_id + " mechanic must be a dictionary.");
			continue;
		}
		for (const Value &value : d_.dict(mechanic.ref).values) {
			if (!gd::is_int(value) && !gd::is_float(value) && !gd::is_bool(value)) {
				warn("Spell " + spell_id + " mechanic values must be numbers or true/false.");
				break;
			}
		}
	}
	const Value follow_status = get(effect, "follow_status_effect", empty_dict_);
	if (!is_dict(follow_status)) {
		warn("Spell " + spell_id + " follow_status_effect must be a dictionary.");
	} else if (!empty(follow_status) && (text(follow_status, "effect_id").empty() || integer(follow_status, "duration_rounds", 0) <= 0)) {
		warn("Spell " + spell_id + " follow_status_effect must define effect_id and duration_rounds > 0.");
	}
	// Grasp of the Deep's stun for a stack already Rooted, and Long Night's flight for the smallest stack.
	for (const char *field : { "rooted_stun_status", "flee_smallest_status" }) {
		const Value status = get(effect, field, empty_dict_);
		if (!is_dict(status)) {
			warn("Spell " + spell_id + " " + field + " must be a dictionary.");
		} else if (!empty(status) && (text(status, "effect_id").empty() || integer(status, "duration_rounds", 0) <= 0)) {
			warn("Spell " + spell_id + " " + field + " must define effect_id and duration_rounds > 0.");
		}
	}
	// The stacks a cast reaches beyond its target: a splash, a beam, sparks, a
	// drain, every stack, and from a mastery rank the stacks next to the target
	// or every stack of its side.
	const std::string splash = text(effect, "splash");
	if (!splash.empty() && splash != "adjacent") {
		warn("Spell " + spell_id + " splash must be adjacent.");
	}
	const std::string reach = text(effect, "reach");
	if (!reach.empty() && reach != "all" && reach != "adjacent") {
		warn("Spell " + spell_id + " reach must be all or adjacent.");
	}
	const int64_t reach_pct = integer(effect, "reach_pct", 100);
	if (reach_pct < 1 || reach_pct > 100) {
		warn("Spell " + spell_id + " reach_pct must be 1 to 100.");
	}
	// A status that spreads to the target's neighbours needs the status.
	const std::string status_splash = text(effect, "status_splash");
	if (!status_splash.empty() && ((status_splash != "adjacent" && status_splash != "all") || text(get(effect, "status_effect", empty_dict_), "effect_id").empty())) {
		warn("Spell " + spell_id + " status_splash must be adjacent or all and needs status_effect.effect_id.");
	}
	// Jumps: the share of the damage at each jump, and more jumps from a mastery rank.
	const Value chain = get(effect, "chain", empty_array_);
	if (!gd::is_array(chain)) {
		warn("Spell " + spell_id + " chain must be a list.");
	} else {
		for (const Value &pct : d_.array(chain.ref).items) {
			const int64_t share = gd::is_int(pct) || gd::is_float(pct) ? gd::to_int(d_, pct) : 0;
			if (share < 1 || share > 100) {
				warn("Spell " + spell_id + " chain entries must be 1 to 100.");
				break;
			}
		}
	}
	const Value mastery_chain = get(effect, "mastery_chain", empty_array_);
	if (!gd::is_array(mastery_chain)) {
		warn("Spell " + spell_id + " mastery_chain must be a list.");
	} else {
		for (const Value &entry : d_.array(mastery_chain.ref).items) {
			const int64_t rank = is_dict(entry) ? integer(entry, "rank", 0) : 0;
			const int64_t share = is_dict(entry) ? integer(entry, "pct", 0) : 0;
			if (rank < 1 || rank > 4 || share < 1 || share > 100) {
				warn("Spell " + spell_id + " mastery_chain entries need a rank of 1 to 4 and a pct of 1 to 100.");
				break;
			}
		}
	}
	if (integer(effect, "push", 0) < 0) {
		warn("Spell " + spell_id + " push must not be negative.");
	}
	for (const char *flag : {"heat_burst", "raise", "fixed_duration"}) {
		const Value value = get(effect, flag, Value());
		if (value.kind != Kind::Nil && value.kind != Kind::Bool) {
			warn("Spell " + spell_id + " " + flag + " must be true or false.");
		}
	}
	const Value battle_long = get(get(effect, "status_effect", empty_dict_), "battle_long", Value());
	if (battle_long.kind != Kind::Nil && battle_long.kind != Kind::Bool) {
		warn("Spell " + spell_id + " status_effect battle_long must be true or false.");
	}
	// The modifiers that grow with power must be among the spell's modifiers.
	const Value modifiers_scaled = get(effect, "modifiers_scaled", empty_array_);
	if (!gd::is_array(modifiers_scaled)) {
		warn("Spell " + spell_id + " modifiers_scaled must be a list.");
	} else {
		for (const Value &field : d_.array(modifiers_scaled.ref).items) {
			if (!field.is_string_like() || !is_dict(modifiers) || !has(modifiers, d_.text(field.ref).c_str())) {
				warn("Spell " + spell_id + " modifiers_scaled must name the spell's modifiers.");
				break;
			}
		}
	}
	if (integer(effect, "random_hits", 0) < 0 || integer(effect, "random_hits_power_divisor", 0) < 0) {
		warn("Spell " + spell_id + " random_hits and its divisor must not be negative.");
	}
	const int64_t drain_pct = integer(effect, "drain_pct", 0);
	if (drain_pct < 0 || drain_pct > 100) {
		warn("Spell " + spell_id + " drain_pct must be 0 to 100.");
	}
	const Value mastery_reach = get(spell, "mastery_reach", empty_array_);
	if (!gd::is_array(mastery_reach)) {
		warn("Spell " + spell_id + " mastery_reach must be a list.");
	} else {
		for (const Value &entry : d_.array(mastery_reach.ref).items) {
			const std::string entry_reach = is_dict(entry) ? text(entry, "reach") : std::string();
			const int64_t rank = is_dict(entry) ? integer(entry, "rank", 0) : 0;
			if (rank < 1 || rank > 4 || (entry_reach != "adjacent" && entry_reach != "all")) {
				warn("Spell " + spell_id + " mastery_reach entries need a rank of 1 to 4 and a reach of adjacent or all.");
				break;
			}
		}
	}
}

} // namespace

void Store::validate(std::vector<Message> &messages) {
	Check check(data_, *files_, messages);
	// _items_from_raw(load_json(path)): the list, or Nil for none.
	const auto list = [&](const char *path) {
		return items_from_raw(load_json(path, messages), "items");
	};
	const RowIndex faction_index = check.index_items(list(kFactionsPath));
	const RowIndex faction_crest_index = check.index_items(list(kFactionCrestsPath));
	const RowIndex hero_index = check.index_items(list(kHeroesPath));
	const RowIndex hero_art_index = check.index_by(list(kHeroArtPath), "hero_id", "_index_hero_art_items");
	const RowIndex unit_index = check.index_items(list(kUnitsPath));
	const RowIndex unit_art_index = check.index_by(list(kUnitArtPath), "unit_id", "_index_unit_art_items");
	Value unit_animation_raw = load_json(kUnitAnimationPath, messages);
	if (unit_animation_raw.kind == Kind::Nil) {
		unit_animation_raw = check.empty_dict();
	}
	const RowIndex unit_animation_index = check.index_by(items_from_raw(unit_animation_raw, "items"), "unit_id", "_index_unit_art_items");
	const RowIndex army_group_index = check.index_items(list(kArmyGroupsPath));
	const RowIndex town_index = check.index_items(list(kTownsPath));
	const RowIndex building_index = check.index_items(list(kBuildingsPath));
	const RowIndex building_art_index = check.index_items(list(kBuildingArtPath));
	const RowIndex resource_index = check.index_items(list(kResourcesPath));
	const RowIndex resource_site_index = check.index_items(list(kResourceSitesPath));
	const RowIndex biome_index = check.index_items(list(kBiomesPath));
	Value terrain_grammar = load_json(kTerrainGrammarPath, messages);
	if (terrain_grammar.kind == Kind::Nil) {
		terrain_grammar = check.empty_dict();
	}
	const RowIndex map_object_index = check.index_items(list(kMapObjectsPath));
	const RowIndex neutral_dwelling_index = check.index_items(list(kNeutralDwellingsPath));
	const RowIndex artifact_index = check.index_items(list(kArtifactsPath));
	const RowIndex spell_index = check.index_items(list(kSpellsPath));
	const RowIndex spell_icon_index = check.index_items(list(kSpellIconsPath));
	const RowIndex spell_school_icon_index = check.index_items(list(kSpellSchoolIconsPath));
	const RowIndex building_category_icon_index = check.index_items(list(kBuildingCategoryIconsPath));
	const RowIndex encounter_index = check.index_items(list(kEncountersPath));

	const auto each_row = [](const RowIndex &index, const auto &visit) {
		for (const std::string &id : index.ids()) {
			visit(index.at(id));
		}
	};
	check.guard("_validate_terrain_grammar", [&] { check.terrain_grammar(terrain_grammar, biome_index); });
	each_row(biome_index, [&](const Value &row) { check.guard("_validate_biome", [&] { check.biome(row); }); });
	each_row(resource_site_index, [&](const Value &row) {
		check.guard("_validate_resource_site", [&] { check.resource_site(row, unit_index, spell_index, neutral_dwelling_index, army_group_index, encounter_index); });
	});
	each_row(map_object_index, [&](const Value &row) {
		check.guard("_validate_map_object", [&] { check.map_object(row, biome_index, resource_site_index, faction_index); });
	});
	each_row(neutral_dwelling_index, [&](const Value &row) {
		check.guard("_validate_neutral_dwelling", [&] { check.neutral_dwelling(row, unit_index, resource_site_index, map_object_index, army_group_index, encounter_index, biome_index); });
	});
	each_row(faction_index, [&](const Value &row) { check.guard("_validate_faction", [&] { check.faction(row, town_index, hero_index, terrain_grammar); }); });
	check.guard("_validate_faction_crests", [&] { check.faction_crests(faction_index, faction_crest_index); });
	each_row(hero_index, [&](const Value &row) { check.guard("_validate_hero", [&] { check.hero(row, faction_index, spell_index); }); });
	check.guard("_validate_hero_art_manifest", [&] { check.hero_art_manifest(hero_index, hero_art_index); });
	each_row(unit_index, [&](const Value &row) { check.guard("_validate_unit", [&] { check.unit(row, faction_index); }); });
	check.guard("_validate_unit_art_manifest", [&] { check.unit_art_manifest(unit_index, unit_art_index); });
	check.guard("_validate_unit_animation_manifest", [&] { check.unit_animation_manifest(unit_index, unit_animation_raw, unit_animation_index); });
	each_row(army_group_index, [&](const Value &row) { check.guard("_validate_army_group", [&] { check.army_group(row, faction_index, unit_index); }); });
	each_row(building_index, [&](const Value &row) { check.guard("_validate_building", [&] { check.building(row, building_index, unit_index); }); });
	check.guard("_validate_building_art_manifest", [&] { check.building_art_manifest(building_index, building_art_index); });
	check.guard("_validate_resources", [&] { check.resources(resource_index); });
	each_row(town_index, [&](const Value &row) {
		check.guard("_validate_town", [&] { check.town(row, faction_index, building_index, unit_index); });
	});
	each_row(artifact_index, [&](const Value &row) { check.guard("_validate_artifact", [&] { check.artifact(row, spell_index); }); });
	each_row(spell_index, [&](const Value &row) { check.guard("_validate_spell", [&] { check.spell(row); }); });
	check.guard("_validate_retired_spells", [&] { check.retired_spells(list(kRetiredSpellsPath), spell_index); });
	check.guard("_validate_spell_icons", [&] { check.spell_icons(spell_index, spell_icon_index); });
	check.guard("_validate_spell_school_icons", [&] { check.spell_school_icons(spell_school_icon_index); });
	check.guard("_validate_building_category_icons", [&] { check.building_category_icons(building_category_icon_index); });
	each_row(encounter_index, [&](const Value &row) { check.guard("_validate_encounter", [&] { check.encounter(row, army_group_index, spell_index); }); });
	for (const std::string &message : ai_hero_weights_errors(load_json(kAiHeroWeightsPath, messages), Value())) {
		check.warn("Overworld AI weights: " + message + ".");
	}
}

} // namespace aurelion::rules::content
