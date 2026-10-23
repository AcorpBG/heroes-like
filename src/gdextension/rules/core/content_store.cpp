// ContentService's loading and lookups (scripts/autoload/ContentService.gd),
// ported under their GDScript names: load_json, get_content_by_id,
// _indexed_content_row, get_encounter, get_content_ids, canonical_town_id,
// get_biome_for_terrain, get_map_object_for_resource_site,
// set_content_override, clear_content_overrides, clear_cache and
// ai_hero_weights_errors.

#include "aurelion_rules/content_store.hpp"

#include "aurelion_rules/compat/godot_json.hpp"
#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/port/gd.hpp"

#include <algorithm>
#include <cmath>
#include <cstring>

namespace aurelion::rules::content {

namespace {

using state::Kind;
using state::State;
using state::Value;

bool begins_with(const std::string &text, const char *prefix) {
	return text.compare(0, std::strlen(prefix), prefix) == 0;
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

bool is_text(const Value &value) {
	return value.kind == Kind::String || value.kind == Kind::StringName;
}

// The GDScript ContentService's AI_HERO_WEIGHT_TABLES and AI_HERO_WHOLE_WEIGHTS.
const char *const kAiHeroWeightTables[] = {"army_power", "specialty_pick"};
const char *const kAiHeroWholeWeights[] = {
	"battle_rounds_estimate", "max_decisions_per_day", "search_days", "far_search_days", "strategic_days",
	"min_search_radius", "max_gates_weighed", "route_unexplored_min", "route_revisit_days", "boat_saving_days",
	"field_army_max", "defense_horizon_days", "max_free_fight_previews", "max_fight_vetoes", "max_idle_previews",
	"home_wait_radius", "hunt_start_day", "hunt_full_day", "sighting_memory_days", "hidden_rival_tiles",
	"passage_tile_cap", "hero_count_town_max", "extra_hero_day", "threat_reach_margin", "threat_min_reach",
	"rival_town_tiles_per_day", "avoid_days", "gate_home_detour", "dwelling_hire_min_value",
	"dwelling_creature_min_value", "visit_stat_value", "visit_level_value", "visit_spell_tier_value", "gold_reserve",
	"service_gold_reserve", "experience_service_min_gold", "exchange_min_kept", "exchange_gold_cap",
	"exchange_low_stock",
};

// A Value of one State copied into another.
Value copy_value(const State &from, const Value &value, State &to) {
	switch (value.kind) {
		case Kind::String:
		case Kind::StringName:
			return Value::of_ref(value.kind, to.intern(from.text(value.ref)));
		case Kind::Array: {
			const uint32_t made = to.new_array();
			for (const Value &item : from.array(value.ref).items) {
				to.append(made, copy_value(from, item, to));
			}
			to.array_node(made).read_only = from.array(value.ref).read_only;
			return Value::of_ref(Kind::Array, made);
		}
		case Kind::Dict: {
			const state::DictNode &node = from.dict(value.ref);
			const uint32_t made = to.new_dict();
			for (size_t index = 0; index < node.keys.size(); ++index) {
				to.set(made, copy_value(from, node.keys[index], to), copy_value(from, node.values[index], to));
			}
			to.dict_node(made).read_only = node.read_only;
			return Value::of_ref(Kind::Dict, made);
		}
		case Kind::Nil:
		case Kind::Bool:
		case Kind::Int:
		case Kind::Float:
			return value;
		default:
			throw state::NotPorted("left to GDScript: a content override holding a value JSON does not make");
	}
}

} // namespace

Store::Store(std::shared_ptr<Files> files) :
		files_(std::move(files)) {}

void Store::freeze_from(size_t arrays, size_t dicts) {
	for (size_t node = arrays; node < data_.array_count(); ++node) {
		data_.array_node(static_cast<uint32_t>(node)).read_only = true;
	}
	for (size_t node = dicts; node < data_.dict_count(); ++node) {
		data_.dict_node(static_cast<uint32_t>(node)).read_only = true;
	}
}

// String(value), for the ids a lookup compares as text: the constructor takes
// a String or StringName, and GDScript stops on any other value.
std::string Store::id_text(const Value &value, const char *what) {
	if (!value.is_string_like()) {
		throw state::ScriptError(std::string("Invalid argument for 'String' constructor: ") + gd::type_name(value) + " (a " + what + ")");
	}
	return data_.text(value.ref);
}

Value Store::parse_file(const std::string &path, std::vector<Message> &messages) {
	std::string bytes;
	if (!files_->read(path, bytes)) {
		messages.push_back({true, "Failed to open content file: " + path});
		return Value();
	}
	const size_t arrays = data_.array_count();
	const size_t dicts = data_.dict_count();
	const compat::JsonParse parsed = compat::json_parse(data_, bytes);
	if (parsed.error != 0) {
		messages.push_back({true, "Invalid JSON for content file " + path + " at line " + compat::itos(parsed.error_line) + ": " + parsed.error_message});
		return Value();
	}
	Value root = parsed.data;
	if (root.kind == Kind::Array) {
		const uint32_t wrapped = data_.new_dict();
		data_.set(wrapped, data_.string("items"), root);
		root = Value::of_ref(Kind::Dict, wrapped);
	} else if (root.kind != Kind::Dict) {
		messages.push_back({true, "Unsupported JSON root for content file: " + path});
		return Value();
	}
	freeze_from(arrays, dicts);
	return root;
}

Value Store::load_json(const std::string &path, std::vector<Message> &messages) {
	const auto cached = cache_.find(path);
	if (cached != cache_.end()) {
		return cached->second;
	}
	const auto replaced = overrides_.find(path);
	if (replaced != overrides_.end()) {
		cache_.emplace(path, replaced->second);
		return replaced->second;
	}
	if (!begins_with(path, "res://")) {
		messages.push_back({true, "Only res:// content paths are supported: " + path});
		return Value();
	}
	if (!files_->exists(path)) {
		if (begins_with(path, kArchiveDir)) {
			const uint32_t empty = data_.new_dict();
			data_.dict_node(empty).read_only = true;
			const Value none = Value::of_ref(Kind::Dict, empty);
			cache_.emplace(path, none);
			return none;
		}
		messages.push_back({true, "Missing content file: " + path});
		return Value();
	}
	const Value root = parse_file(path, messages);
	if (root.kind == Kind::Dict) {
		cache_.emplace(path, root);
	}
	return root;
}

// _items_from_raw(raw, list_key): raw.get(list_key, raw.get("entries", [])) when
// it is an Array, else Nil for [].
Value Store::items_from_raw(const Value &raw, const std::string &list_key) {
	if (raw.kind != Kind::Dict) {
		return Value();
	}
	Value items;
	if (!data_.lookup(raw.ref, data_.string(list_key), items) && !data_.lookup(raw.ref, data_.string("entries"), items)) {
		return Value();
	}
	return items.kind == Kind::Array ? items : Value();
}

const Store::Index &Store::index(const std::string &path, const std::string &list_key, const std::string &id_field, const Value &raw) {
	std::string name = path;
	name += '\n';
	name += list_key;
	name += '\n';
	name += id_field;
	const Value items = items_from_raw(raw, list_key);
	auto found = indexes_.find(name);
	if (found != indexes_.end() && found->second.items.kind == items.kind && found->second.items.ref == items.ref) {
		return found->second;
	}
	Index made;
	made.items = items;
	if (items.kind == Kind::Array) {
		const Value field = data_.string(id_field);
		const Value id_key = data_.string("id");
		for (const Value &item : data_.array(items.ref).items) {
			if (item.kind != Kind::Dict) {
				continue;
			}
			// String(item.get(id_field, item.get("id", "")))
			Value id;
			if (!data_.lookup(item.ref, field, id) && !data_.lookup(item.ref, id_key, id)) {
				id = data_.string("");
			}
			const uint32_t atom = data_.intern(id_text(id, "content id"));
			made.by_id.emplace(atom, item);
		}
	}
	return indexes_[name] = std::move(made);
}

Value Store::indexed_row(const std::string &path, const std::string &id, const std::string &list_key, const std::string &id_field, std::vector<Message> &messages) {
	const Value raw = load_json(path, messages);
	if (raw.kind != Kind::Dict || data_.dict_size(raw.ref) == 0) {
		return Value();
	}
	const Index &rows = index(path, list_key, id_field, raw);
	uint32_t atom = 0;
	if (!data_.find_atom(id, atom)) {
		return Value();
	}
	const auto row = rows.by_id.find(atom);
	return row != rows.by_id.end() ? row->second : Value();
}

Value Store::content_by_id(const std::string &path, const std::string &id, const std::string &list_key, std::vector<Message> &messages) {
	if (list_key == "items" && path == kTownsPath) {
		return indexed_row(path, canonical_town_id(id, messages), list_key, "id", messages);
	}
	return indexed_row(path, id, list_key, "id", messages);
}

Value Store::encounter(const std::string &id, std::vector<Message> &messages) {
	const Value row = content_by_id(kEncountersPath, id, "items", messages);
	if (row.kind == Kind::Nil && begins_with(id, kGeneratedCompanyEncounterPrefix)) {
		return indexed_row(kGeneratedCompaniesPath, id, "encounters", "id", messages);
	}
	return row;
}

std::vector<std::string> Store::content_ids(const std::string &path, const std::string &list_key, std::vector<Message> &messages) {
	std::vector<std::string> ids;
	const Value raw = load_json(path, messages);
	if (raw.kind != Kind::Dict || data_.dict_size(raw.ref) == 0) {
		return ids;
	}
	const Value items = items_from_raw(raw, list_key);
	if (items.kind != Kind::Array) {
		return ids;
	}
	const Value id_key = data_.string("id");
	for (const Value &item : data_.array(items.ref).items) {
		if (item.kind != Kind::Dict) {
			throw state::NotPorted("left to GDScript: get_content_ids over an item that is no Dictionary");
		}
		Value id;
		if (data_.lookup(item.ref, id_key, id)) {
			ids.push_back(id_text(id, "content id"));
		}
	}
	return ids;
}

std::string Store::canonical_town_id(const std::string &id, std::vector<Message> &messages) {
	// var aliases: Dictionary = load_json(TOWNS_PATH).get("legacy_aliases", {})
	const Value raw = load_json(kTownsPath, messages);
	Value aliases;
	if (raw.kind != Kind::Dict || !data_.lookup(raw.ref, data_.string("legacy_aliases"), aliases)) {
		return id;
	}
	if (aliases.kind != Kind::Dict) {
		throw state::NotPorted("left to GDScript: towns.json's legacy_aliases is no Dictionary");
	}
	Value alias;
	if (!data_.lookup(aliases.ref, data_.string(id), alias)) {
		return id;
	}
	return id_text(alias, "town alias");
}

std::string Store::normalize_terrain_id(const std::string &terrain_id) {
	const std::string normalized = strip_edges(terrain_id);
	if (normalized == "highland" || normalized == "hills" || normalized == "ridge") {
		return "rough";
	}
	if (normalized == "badlands") {
		return "dirt";
	}
	if (normalized == "wastes") {
		return "sand";
	}
	if (normalized == "cavern" || normalized == "underway") {
		return "underground";
	}
	if (normalized == "coast" || normalized == "shore") {
		return "water";
	}
	return normalized;
}

Value Store::biome_for_terrain(const std::string &terrain_id, std::vector<Message> &messages) {
	const std::string normalized = normalize_terrain_id(terrain_id);
	if (normalized.empty()) {
		return Value();
	}
	const Value items = items_from_raw(load_json(kBiomesPath, messages), "items");
	const Value tile_ids_key = data_.string("map_tile_ids");
	if (!biome_index_built_ || biome_items_.kind != items.kind || biome_items_.ref != items.ref) {
		// _build_biome_terrain_index: the first biome listing each map tile id,
		// or no index when one biome's map_tile_ids is not an Array.
		biome_index_built_ = true;
		biome_items_ = items;
		biome_indexed_ = true;
		biome_by_terrain_.clear();
		if (items.kind == Kind::Array) {
			for (const Value &biome : data_.array(items.ref).items) {
				if (biome.kind != Kind::Dict) {
					continue;
				}
				Value tile_ids;
				if (!data_.lookup(biome.ref, tile_ids_key, tile_ids)) {
					continue;
				}
				if (tile_ids.kind != Kind::Array) {
					biome_indexed_ = false;
					biome_by_terrain_.clear();
					break;
				}
				for (const Value &tile_id : data_.array(tile_ids.ref).items) {
					if (is_text(tile_id)) {
						biome_by_terrain_.emplace(tile_id.ref, biome);
					}
				}
			}
		}
	}
	if (biome_indexed_) {
		uint32_t atom = 0;
		if (!data_.find_atom(normalized, atom)) {
			return Value();
		}
		const auto found = biome_by_terrain_.find(atom);
		return found != biome_by_terrain_.end() ? found->second : Value();
	}
	// _scan_biome_for_terrain: `normalized_terrain in biome.get("map_tile_ids", [])`.
	for (const Value &biome : data_.array(items.ref).items) {
		if (biome.kind != Kind::Dict) {
			continue;
		}
		Value tile_ids;
		if (!data_.lookup(biome.ref, tile_ids_key, tile_ids)) {
			continue;
		}
		if (tile_ids.kind == Kind::Array) {
			for (const Value &tile_id : data_.array(tile_ids.ref).items) {
				if (is_text(tile_id) && data_.text(tile_id.ref) == normalized) {
					return biome;
				}
			}
		} else if (is_text(tile_ids)) {
			if (data_.text(tile_ids.ref).find(normalized) != std::string::npos) {
				return biome;
			}
		} else if (tile_ids.kind == Kind::Dict) {
			if (data_.has(tile_ids.ref, data_.string(normalized))) {
				return biome;
			}
		} else {
			throw state::NotPorted("left to GDScript: `in` over a biome's map_tile_ids that is no Array, String or Dictionary");
		}
	}
	return Value();
}

Value Store::map_object_for_resource_site(const std::string &site_id, std::vector<Message> &messages) {
	const std::string normalized = strip_edges(site_id);
	if (normalized.empty()) {
		return Value();
	}
	const Value items = items_from_raw(load_json(kMapObjectsPath, messages), "items");
	if (!site_index_built_ || indexes_.count("#site") == 0 || indexes_["#site"].items.ref != items.ref || indexes_["#site"].items.kind != items.kind) {
		// _build_map_object_site_index: per site id, the object with the largest
		// footprint, the first of equals.
		site_index_built_ = true;
		object_by_site_.clear();
		Index &marker = indexes_["#site"];
		marker.items = items;
		if (items.kind == Kind::Array) {
			const Value site_key = data_.string("resource_site_id");
			const Value footprint_key = data_.string("footprint");
			const Value width_key = data_.string("width");
			const Value height_key = data_.string("height");
			// _map_object_footprint_area(item)
			const auto area = [&](const Value &item) -> int64_t {
				Value footprint;
				if (!data_.lookup(item.ref, footprint_key, footprint)) {
					return 1;
				}
				if (footprint.kind != Kind::Dict) {
					return 1;
				}
				const auto side = [&](const Value &key) -> int64_t {
					Value value;
					if (!data_.lookup(footprint.ref, key, value)) {
						return 1;
					}
					switch (value.kind) {
						case Kind::Int:
							return value.i;
						case Kind::Float:
							return compat::float_to_int(value.f);
						case Kind::Bool:
							return value.b ? 1 : 0;
						case Kind::String:
							return compat::to_int(data_.text(value.ref));
						default:
							throw state::NotPorted("left to GDScript: int() of a map object's footprint side");
					}
				};
				const int64_t width = std::max<int64_t>(1, side(width_key));
				const int64_t height = std::max<int64_t>(1, side(height_key));
				return static_cast<int64_t>(static_cast<uint64_t>(width) * static_cast<uint64_t>(height));
			};
			for (const Value &item : data_.array(items.ref).items) {
				if (item.kind != Kind::Dict) {
					continue;
				}
				Value site;
				if (!data_.lookup(item.ref, site_key, site)) {
					site = data_.string("");
				}
				const uint32_t atom = data_.intern(strip_edges(id_text(site, "resource site id")));
				const auto best = object_by_site_.find(atom);
				if (best == object_by_site_.end()) {
					object_by_site_.emplace(atom, item);
				} else if (area(item) > area(best->second)) {
					best->second = item;
				}
			}
		}
	}
	uint32_t atom = 0;
	if (!data_.find_atom(normalized, atom)) {
		return Value();
	}
	const auto found = object_by_site_.find(atom);
	return found != object_by_site_.end() ? found->second : Value();
}

bool Store::set_override(const std::string &path, const Value &document, std::vector<Message> &messages) {
	if (!begins_with(path, std::string(kContentDir).append("/").c_str()) || !files_->exists(path)) {
		messages.push_back({true, "Content override refused: " + path + " is no content file."});
		return false;
	}
	std::vector<std::string> errors;
	if (path == kAiHeroWeightsPath) {
		// JSON.parse_string(FileAccess.get_file_as_string(path)), a Dictionary or {}.
		Value shipped;
		std::string bytes;
		if (files_->read(path, bytes)) {
			const compat::JsonParse parsed = compat::json_parse(data_, bytes);
			if (parsed.error != 0) {
				messages.push_back({true, "Parse JSON failed. Error at line " + compat::itos(parsed.error_line) + ": " + parsed.error_message});
			} else if (parsed.data.kind == Kind::Dict) {
				shipped = parsed.data;
			}
		}
		errors = ai_hero_weights_errors(document, shipped);
	}
	for (const std::string &message : errors) {
		messages.push_back({true, "Content override refused for " + path + ": " + message});
	}
	if (!errors.empty()) {
		return false;
	}
	overrides_[path] = document;
	clear_cache();
	return true;
}

void Store::clear_overrides() {
	if (overrides_.empty()) {
		return;
	}
	overrides_.clear();
	clear_cache();
}

void Store::clear_cache() {
	// The tables are read again from the files: a new State with only the
	// overrides copied over, so a reload frees what the old one held.
	if (overrides_.empty()) {
		data_.clear();
	} else {
		auto fresh = std::make_unique<State>();
		std::unordered_map<std::string, Value> kept;
		for (const auto &entry : overrides_) {
			kept.emplace(entry.first, copy_value(data_, entry.second, *fresh));
		}
		data_.clear();
		for (auto &entry : kept) {
			entry.second = copy_value(*fresh, entry.second, data_);
		}
		overrides_ = std::move(kept);
	}
	cache_.clear();
	indexes_.clear();
	biome_index_built_ = false;
	biome_items_ = Value();
	biome_by_terrain_.clear();
	site_index_built_ = false;
	object_by_site_.clear();
	++generation_;
	++revision_;
}

namespace {

std::string key_text(const State &data, const Value &key) {
	switch (key.kind) {
		case Kind::String:
		case Kind::StringName:
			return data.text(key.ref);
		case Kind::Int:
			return compat::itos(key.i);
		case Kind::Bool:
			return key.b ? "true" : "false";
		case Kind::Nil:
			return "<null>";
		default:
			throw state::NotPorted("left to GDScript: \"%s\" of an AI weights key that is no text, int or bool");
	}
}

bool is_whole_weight(const std::string &name) {
	for (const char *whole : kAiHeroWholeWeights) {
		if (name == whole) {
			return true;
		}
	}
	return false;
}

// _ai_hero_weight_errors(label, values, reference, reference_name, errors).
void ai_hero_weight_errors(State &data, const std::string &label, const Value &values, const Value &reference, const std::string &reference_name, std::vector<std::string> &errors) {
	const bool checked = reference.kind == Kind::Dict;
	const state::DictNode &node = data.dict(values.ref);
	const size_t count = node.keys.size();
	for (size_t index = 0; index < count; ++index) {
		const Value key = data.dict(values.ref).keys[index];
		const Value value = data.dict(values.ref).values[index];
		const std::string path = label + "." + key_text(data, key);
		Value referenced;
		if (checked && !data.lookup(reference.ref, key, referenced)) {
			errors.push_back(path + " is not in the " + reference_name);
			continue;
		}
		if ((checked ? referenced : value).kind == Kind::Dict) {
			if (value.kind == Kind::Dict) {
				ai_hero_weight_errors(data, path, value, checked ? referenced : Value(), reference_name, errors);
			} else {
				errors.push_back(path + " must be a table of numbers");
			}
		} else if (!((value.kind == Kind::Int) || (value.kind == Kind::Float && std::isfinite(value.f)))) {
			errors.push_back(path + " must be a number");
		} else {
			const double number = value.kind == Kind::Int ? static_cast<double>(value.i) : value.f;
			if (is_whole_weight(key_text(data, key)) && number != std::floor(number)) {
				errors.push_back(path + " must be a whole number");
			}
		}
	}
	if (checked && reference_name == "shipped document") {
		const state::DictNode &shipped = data.dict(reference.ref);
		for (size_t index = 0; index < shipped.keys.size(); ++index) {
			if (!data.has(values.ref, shipped.keys[index])) {
				errors.push_back(label + "." + key_text(data, shipped.keys[index]) + " is missing");
			}
		}
	}
}

} // namespace

std::vector<std::string> Store::ai_hero_weights_errors(const Value &doc, const Value &shipped) {
	std::vector<std::string> errors;
	const auto field = [&](const Value &dict, const char *name) -> Value {
		Value out;
		if (dict.kind == Kind::Dict && data_.lookup(dict.ref, data_.string(name), out)) {
			return out;
		}
		return Value();
	};
	for (const char *table_name : kAiHeroWeightTables) {
		const Value table = field(doc, table_name);
		if (table.kind == Kind::Dict) {
			ai_hero_weight_errors(data_, table_name, table, field(shipped, table_name), "shipped document", errors);
		} else {
			errors.push_back(std::string(table_name) + " must be an object");
		}
	}
	const Value sets = field(doc, "sets");
	if (sets.kind != Kind::Dict || field(sets, "default").kind != Kind::Dict) {
		errors.push_back("sets.default must be an object");
		return errors;
	}
	const Value shipped_sets = field(shipped, "sets");
	const Value shipped_default = shipped_sets.kind == Kind::Dict ? field(shipped_sets, "default") : Value();
	const Value default_set = field(sets, "default");
	ai_hero_weight_errors(data_, "sets.default", default_set, shipped_default, "shipped document", errors);
	const size_t count = data_.dict(sets.ref).keys.size();
	for (size_t index = 0; index < count; ++index) {
		const Value set_name = data_.dict(sets.ref).keys[index];
		const Value set = data_.dict(sets.ref).values[index];
		if (is_text(set_name) && data_.text(set_name.ref) == "default") {
			continue;
		}
		if (set.kind == Kind::Dict) {
			ai_hero_weight_errors(data_, "sets." + key_text(data_, set_name), set, default_set, "default set", errors);
		} else {
			errors.push_back("sets." + key_text(data_, set_name) + " must be an object");
		}
	}
	return errors;
}

} // namespace aurelion::rules::content
