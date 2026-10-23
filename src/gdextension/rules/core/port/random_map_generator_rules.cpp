// RandomMapGeneratorRules: the player's random map config normalized, the
// template and profile chosen and the seats assigned (Phase 7, 7.11).

#include "aurelion_rules/port/random_map_generator_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_string.hpp"

#include <cstdint>
#include <initializer_list>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

constexpr int64_t kRngModulus = 2147483647; // RNG_MODULUS
constexpr int64_t kRngMultiplier = 48271; // RNG_MULTIPLIER
constexpr int64_t kHashModulus = 4294967296; // HASH_MODULUS

// DEFAULT_FACTIONS, CORE_TERRAIN_POOL, SUPPORT_RESOURCE_SITES' site ids.
constexpr Atom kDefaultFactions[] = {
	key::faction_embercourt,
	key::faction_mireclaw,
	key::faction_sunvault,
	key::faction_thornwake,
};
constexpr int64_t kDefaultFactionCount = 4;

ArrayRef string_array(State &state, std::initializer_list<Atom> atoms) {
	const ArrayRef result = state.new_array();
	for (const Atom atom : atoms) {
		state.append(result, str(atom));
	}
	return result;
}

// A new Array with the items of the const DEFAULT_FACTIONS, CORE_TERRAIN_POOL
// or ["land"]: GDScript only reads and duplicates these consts here.
ArrayRef default_factions(State &state) {
	return string_array(state, { key::faction_embercourt, key::faction_mireclaw, key::faction_sunvault, key::faction_thornwake });
}
ArrayRef core_terrain_pool(State &state) {
	return string_array(state, { key::grass, key::snow, key::sand, key::dirt, key::rough, key::lava, key::underground });
}
ArrayRef land_only(State &state) {
	return string_array(state, { key::land });
}

// for resource in SUPPORT_RESOURCE_SITES: append(String(resource.get("site_id", "")))
ArrayRef support_resource_site_ids(State &state) {
	return string_array(state, { key::site_wood_wagon, key::site_ore_crates, key::site_waystone_cache });
}

// DEFAULT_TOWN_BY_FACTION.get(faction_id, "town_riverwatch")
Atom default_town_by_faction(Atom faction_id) {
	if (faction_id == key::faction_embercourt) {
		return key::town_riverwatch;
	}
	if (faction_id == key::faction_mireclaw) {
		return key::town_duskfen;
	}
	if (faction_id == key::faction_sunvault) {
		return key::town_prismhearth;
	}
	if (faction_id == key::faction_thornwake) {
		return key::town_thornwake_graftroot_caravan;
	}
	if (faction_id == key::faction_brasshollow) {
		return key::town_brasshollow_orevein_gantry;
	}
	if (faction_id == key::faction_veilmourn) {
		return key::town_veilmourn_bellwake_harbor;
	}
	return key::town_riverwatch;
}

// RUNTIME_SIZE_CAP.duplicate(true)
DictRef runtime_size_cap(State &state) {
	const DictRef cap = state.new_dict();
	state.set(cap, str(key::width), int_value(144));
	state.set(cap, str(key::height), int_value(144));
	state.set(cap, str(key::level_count), int_value(2));
	return cap;
}

// String(value)
Atom string_of(State &state, const Value &value) {
	return gd::stringify(state, value);
}

// String(value).strip_edges()
Atom stripped(State &state, const Value &value) {
	return gd::strip_edges(state, gd::stringify(state, value));
}

// s.to_lower() of ASCII text. Other text is not ported: the Unicode case
// tables are the engine's (the texts lowered here are the setup's option ids).
Atom to_lower(State &state, Atom text, const char *where) {
	std::string lowered = state.text(text);
	for (char &c : lowered) {
		if (static_cast<unsigned char>(c) >= 0x80) {
			throw state::NotPorted(std::string(where) + ": to_lower() of non-ASCII text");
		}
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
		}
	}
	return state.intern(lowered);
}

// s.unicode_at(i) for each i in range(s.length()): the code points of the UTF-8.
std::vector<uint32_t> code_points(const std::string &text) {
	std::vector<uint32_t> points;
	size_t index = 0;
	while (index < text.size()) {
		const unsigned char lead = static_cast<unsigned char>(text[index]);
		uint32_t point = lead;
		size_t length = 1;
		if (lead >= 0xf0) {
			point = lead & 0x07u;
			length = 4;
		} else if (lead >= 0xe0) {
			point = lead & 0x0fu;
			length = 3;
		} else if (lead >= 0xc0) {
			point = lead & 0x1fu;
			length = 2;
		}
		for (size_t next = 1; next < length && index + next < text.size(); ++next) {
			point = (point << 6) | (static_cast<unsigned char>(text[index + next]) & 0x3fu);
		}
		points.push_back(point);
		index += length;
	}
	return points;
}

// d.get(name, {}) if d.get(name, {}) is Dictionary else {}
DictRef dict_field_or_new(State &state, DictRef dict, Atom name) {
	Value found;
	if (state.lookup(dict, str(name), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// d.get(name, []) and d.get(name, {}) where the answer is kept.
Value field_or_new_array(State &state, DictRef dict, Atom name) {
	Value found;
	if (state.lookup(dict, str(name), found)) {
		return found;
	}
	return array_value(state.new_array());
}
Value field_or_new_dict(State &state, DictRef dict, Atom name) {
	Value found;
	if (state.lookup(dict, str(name), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// sep.join(array) of an Array the scripts filled with Strings (the Array
// converts to a PackedStringArray item by item).
Atom join_array(State &state, Atom separator, ArrayRef array) {
	std::vector<Atom> parts;
	for (const Value &item : gd::items(state, array_value(array))) {
		parts.push_back(gd::stringify(state, item));
	}
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// a.sort() of an Array of Strings (Variant OP_LESS: code point order, which
// is the UTF-8 byte order). The Arrays sorted here hold String(x) results.
void sort_strings(State &state, ArrayRef array, const char *where) {
	gd::sort_custom(state, array, [&state, where](const Value &a, const Value &b) {
		if (a.kind != Kind::String || b.kind != Kind::String) {
			throw state::NotPorted(std::string(where) + ": sort() of an Array that is not all Strings");
		}
		return state.text(a.ref) < state.text(b.ref);
	});
}

// RandomMapGeneratorRules.DeterministicRng, the script's inner class.
class DeterministicRng {
public:
	explicit DeterministicRng(int64_t seed_value) :
			state_(1 < seed_value ? seed_value : 1) {}

	double next_float() {
		state_ = compat::int_mod(gd::mul(state_, kRngMultiplier), kRngModulus);
		return static_cast<double>(state_) / static_cast<double>(kRngModulus);
	}

	int64_t next_index(int64_t size) {
		if (size <= 0) {
			return 0;
		}
		const int64_t picked = compat::float_to_int(compat::godot_floor(next_float() * static_cast<double>(size)));
		// min(size - 1, picked)
		return size - 1 > picked ? picked : size - 1;
	}

private:
	int64_t state_;
};

} // namespace

namespace random_map_generator_rules {

DictRef normalize_config(State &state, DictRef input_config) {
	Atom generator_version = stripped(state, gd::field_or(state, input_config, key::generator_version, str(key::random_map_seeded_core_v1)));
	if (generator_version == key::empty) {
		generator_version = key::random_map_seeded_core_v1;
	}
	Atom normalized_seed = stripped(state, gd::field_or(state, input_config, key::seed, str(key::k_0)));
	if (normalized_seed == key::empty) {
		normalized_seed = key::k_0;
	}
	const Value map_size = gd::field_or(state, input_config, key::map_size, str(key::small));
	const DictRef size = _normalize_size(state, gd::field_or(state, input_config, key::size, map_size));
	if (state.has(input_config, str(key::water_mode))) {
		state.set(size, str(key::water_mode), str(_normalize_water_mode(state, gd::field_or(state, input_config, key::water_mode, str(key::land)))));
	}
	if (state.has(input_config, str(key::level_count))) {
		state.set(size, str(key::level_count), int_value(compat::engine_clamp<int64_t>(gd::int_field(state, input_config, key::level_count, 1), 1, 2)));
		state.set(size, str(key::underground), bool_value(gd::int_field(state, size, key::level_count, 1) > 1));
	}
	Value constraints_value;
	if (!state.lookup(input_config, str(key::player_constraints), constraints_value)) {
		constraints_value = field_or_new_dict(state, input_config, key::players);
	}
	const DictRef player_constraints = _normalize_player_constraints(state, constraints_value);
	DictRef profile = _normalize_profile(state, field_or_new_dict(state, input_config, key::profile), player_constraints);
	const DictRef template_selection = _select_template_profile(state, input_config, size, player_constraints, normalized_seed, profile);
	const DictRef template_ = gd::as_dict(field_or_new_dict(state, template_selection, key::template_));
	profile = _merge_profile_with_catalog(state, profile, gd::as_dict(field_or_new_dict(state, template_selection, key::profile)), player_constraints);
	const DictRef player_assignment = _build_player_assignment(state, template_, profile, player_constraints, normalized_seed);
	if (!gd::is_empty(state, player_assignment)) {
		if (string_of(state, gd::field_or(state, player_assignment, key::assignment_policy, str(key::empty))) == key::fixed_owner_slots_first_n_players_seeded_factions) {
			Value faction_ids;
			if (!state.lookup(player_assignment, str(key::assigned_faction_ids), faction_ids)) {
				faction_ids = field_or_new_array(state, profile, key::faction_ids);
			}
			state.set(profile, str(key::faction_ids), faction_ids);
			Value town_ids;
			if (!state.lookup(player_assignment, str(key::assigned_town_ids), town_ids)) {
				town_ids = field_or_new_array(state, profile, key::town_ids);
			}
			state.set(profile, str(key::town_ids), town_ids);
		}
	}
	const DictRef content_manifest = state.new_dict();
	state.set(content_manifest, str(key::template_id), str(string_of(state, gd::field_or(state, template_, key::id, str(key::aurelion_seeded_spoke_profile_v1)))));
	state.set(content_manifest, str(key::template_source), str(string_of(state, gd::field_or(state, template_selection, key::source, str(key::empty)))));
	state.set(content_manifest, str(key::faction_ids), field_or_new_array(state, profile, key::faction_ids));
	state.set(content_manifest, str(key::town_ids), field_or_new_array(state, profile, key::town_ids));
	state.set(content_manifest, str(key::resource_site_ids), field_or_new_array(state, profile, key::resource_site_ids));
	const ArrayRef encounter_ids = state.new_array();
	state.append(encounter_ids, str(string_of(state, gd::field_or(state, profile, key::encounter_id, str(key::encounter_mire_raid)))));
	state.set(content_manifest, str(key::encounter_ids), array_value(encounter_ids));
	state.set(content_manifest, str(key::terrain_ids), field_or_new_array(state, profile, key::terrain_ids));
	const DictRef result = state.new_dict();
	state.set(result, str(key::generator_version), str(generator_version));
	state.set(result, str(key::seed), str(normalized_seed));
	state.set(result, str(key::size), dict_value(size));
	state.set(result, str(key::player_constraints), dict_value(player_constraints));
	state.set(result, str(key::profile), dict_value(profile));
	state.set(result, str(key::player_assignment), dict_value(player_assignment));
	state.set(result, str(key::template_id), str(string_of(state, gd::field_or(state, template_, key::id, str(key::aurelion_seeded_spoke_profile_v1)))));
	state.set(result, str(key::template_), dict_value(template_));
	state.set(result, str(key::template_selection), dict_value(template_selection));
	state.set(result, str(key::content_manifest_fingerprint), str(_hash32_hex(state, _stable_stringify(state, dict_value(content_manifest)))));
	return result;
}

DictRef _load_template_catalog(State &state) {
	// ContentService's cached catalog, shared across calls: read only.
	const DictRef catalog = gd::content_file(state, key::random_map_template_catalog_path);
	if (gd::is_empty(state, catalog)) {
		const DictRef fallback = state.new_dict();
		state.set(fallback, str(key::schema_id), str(key::empty));
		state.set(fallback, str(key::profiles), array_value(state.new_array()));
		state.set(fallback, str(key::templates), array_value(state.new_array()));
		return fallback;
	}
	return catalog;
}

DictRef _select_template_profile(State &state, DictRef input_config, DictRef size, DictRef player_constraints, Atom seed, DictRef input_profile) {
	const DictRef catalog = _load_template_catalog(state);
	const ArrayRef templates = gd::as_array(field_or_new_array(state, catalog, key::templates));
	const ArrayRef profiles = gd::as_array(field_or_new_array(state, catalog, key::profiles));
	// raw_profile = input_config.get("profile", {}): a missing one is an empty Dictionary.
	Value raw_profile;
	const bool raw_profile_is_dict = state.lookup(input_config, str(key::profile), raw_profile) && gd::is_dict(raw_profile);
	const bool profile_id_was_explicit = raw_profile_is_dict && state.has(raw_profile.ref, str(key::id))
			&& stripped(state, gd::field_or(state, raw_profile.ref, key::id, str(key::empty))) != key::empty;
	const bool profile_template_was_explicit = raw_profile_is_dict && state.has(raw_profile.ref, str(key::template_id))
			&& stripped(state, gd::field_or(state, raw_profile.ref, key::template_id, str(key::empty))) != key::empty;
	const bool template_id_was_explicit = state.has(input_config, str(key::template_id))
			&& stripped(state, gd::field_or(state, input_config, key::template_id, str(key::empty))) != key::empty;
	const Value profile_template_id_value = gd::field_or(state, input_profile, key::template_id, str(key::empty));
	const Atom requested_template_id = stripped(state, gd::field_or(state, input_config, key::template_id, profile_template_id_value));
	const Atom requested_profile_id = profile_id_was_explicit ? stripped(state, gd::field_or(state, input_profile, key::id, str(key::empty))) : Atom(key::empty);
	const bool explicit_catalog_request = requested_template_id != key::empty || profile_template_was_explicit;
	std::unordered_map<Atom, DictRef> profile_by_id;
	std::unordered_map<Atom, DictRef> profile_by_template;
	for (const Value &profile : gd::items(state, array_value(profiles))) {
		if (!gd::is_dict(profile)) {
			continue;
		}
		const Atom profile_id = string_of(state, gd::field_or(state, profile.ref, key::id, str(key::empty)));
		const Atom profile_template_id = string_of(state, gd::field_or(state, profile.ref, key::template_id, str(key::empty)));
		if (profile_id != key::empty) {
			profile_by_id[profile_id] = profile.ref;
		}
		if (profile_template_id != key::empty && profile_by_template.find(profile_template_id) == profile_by_template.end()) {
			profile_by_template[profile_template_id] = profile.ref;
		}
	}
	const auto requested_profile = profile_by_id.find(requested_profile_id);
	const bool has_requested_profile = requested_profile != profile_by_id.end();
	if (requested_template_id == key::empty && requested_profile_id != key::empty && !has_requested_profile) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::template_), dict_value(state.new_dict()));
		state.set(result, str(key::profile), dict_value(state.new_dict()));
		state.set(result, str(key::source), str(key::built_in_fallback_unknown_explicit_profile));
		state.set(result, str(key::requested_template_id), str(requested_template_id));
		state.set(result, str(key::requested_profile_id), str(requested_profile_id));
		return result;
	}
	const ArrayRef template_candidates = state.new_array();
	const ArrayRef candidate_rejections = state.new_array();
	bool requested_template_seen = false;
	for (const Value &template_value : gd::items(state, array_value(templates))) {
		if (!gd::is_dict(template_value)) {
			continue;
		}
		const DictRef template_ = template_value.ref;
		const Atom template_id = string_of(state, gd::field_or(state, template_, key::id, str(key::empty)));
		if (requested_template_id != key::empty && template_id != requested_template_id) {
			continue;
		}
		if (requested_template_id != key::empty && template_id == requested_template_id) {
			requested_template_seen = true;
		}
		if (requested_template_id == key::empty && has_requested_profile
				&& template_id != string_of(state, gd::field_or(state, requested_profile->second, key::template_id, str(key::empty)))) {
			continue;
		}
		const DictRef constraint_report = _template_constraint_report(state, template_, size, player_constraints);
		if (!gd::to_bool(gd::field_or(state, constraint_report, key::matches, bool_value(false)))) {
			state.append(candidate_rejections, dict_value(constraint_report));
			continue;
		}
		state.append(template_candidates, template_value);
	}
	Atom source = key::content_catalog;
	const auto first_rejection = [&state, candidate_rejections]() {
		return state.array_size(candidate_rejections) != 0 ? state.at(candidate_rejections, 0) : dict_value(state.new_dict());
	};
	if (state.array_size(template_candidates) == 0 && requested_template_id != key::empty) {
		source = key::rejected_explicit_template;
		const Atom failure_code = requested_template_seen ? key::template_constraints_failed : key::template_not_found;
		const DictRef result = state.new_dict();
		state.set(result, str(key::template_), dict_value(state.new_dict()));
		state.set(result, str(key::profile), dict_value(state.new_dict()));
		state.set(result, str(key::source), str(source));
		state.set(result, str(key::rejected), bool_value(true));
		state.set(result, str(key::failure_code), str(failure_code));
		state.set(result, str(key::rejection_reasons), array_value(_selection_rejection_reasons(state, failure_code, requested_template_id, requested_profile_id, candidate_rejections)));
		state.set(result, str(key::constraint_report), first_rejection());
		state.set(result, str(key::candidate_rejections), array_value(candidate_rejections));
		state.set(result, str(key::requested_template_id), str(requested_template_id));
		state.set(result, str(key::requested_profile_id), str(requested_profile_id));
		return result;
	}
	if (state.array_size(template_candidates) == 0 && has_requested_profile) {
		source = key::rejected_explicit_profile;
		const Atom requested_profile_template_id = string_of(state, gd::field_or(state, requested_profile->second, key::template_id, str(key::empty)));
		const DictRef result = state.new_dict();
		state.set(result, str(key::template_), dict_value(state.new_dict()));
		state.set(result, str(key::profile), dict_value(gd::deep_duplicate_dict(state, requested_profile->second)));
		state.set(result, str(key::source), str(source));
		state.set(result, str(key::rejected), bool_value(true));
		state.set(result, str(key::failure_code), str(key::profile_template_constraints_failed));
		state.set(result, str(key::rejection_reasons), array_value(_selection_rejection_reasons(state, key::profile_template_constraints_failed, requested_profile_template_id, requested_profile_id, candidate_rejections)));
		state.set(result, str(key::constraint_report), first_rejection());
		state.set(result, str(key::candidate_rejections), array_value(candidate_rejections));
		state.set(result, str(key::requested_template_id), str(requested_template_id));
		state.set(result, str(key::requested_profile_id), str(requested_profile_id));
		return result;
	}
	if (state.array_size(template_candidates) == 0) {
		source = key::built_in_fallback_no_catalog_match;
		if (explicit_catalog_request || template_id_was_explicit) {
			source = key::rejected_explicit_template;
		}
		const DictRef result = state.new_dict();
		state.set(result, str(key::template_), dict_value(state.new_dict()));
		state.set(result, str(key::profile), dict_value(state.new_dict()));
		state.set(result, str(key::source), str(source));
		state.set(result, str(key::rejected), bool_value(gd::begins_with(state, source, key::rejected)));
		state.set(result, str(key::failure_code), str(key::no_catalog_template_matched_constraints));
		state.set(result, str(key::rejection_reasons), array_value(_selection_rejection_reasons(state, key::no_catalog_template_matched_constraints, requested_template_id, requested_profile_id, candidate_rejections)));
		state.set(result, str(key::candidate_rejections), array_value(candidate_rejections));
		state.set(result, str(key::requested_template_id), str(requested_template_id));
		state.set(result, str(key::requested_profile_id), str(requested_profile_id));
		return result;
	}
	// sort_custom(_compare_template_id): String(a.get("id", "")) < String(b.get("id", ""))
	gd::sort_custom(state, template_candidates, [&state](const Value &a, const Value &b) {
		const Atom left = string_of(state, gd::field_or(state, gd::as_dict(a), key::id, str(key::empty)));
		const Atom right = string_of(state, gd::field_or(state, gd::as_dict(b), key::id, str(key::empty)));
		return state.text(left) < state.text(right);
	});
	int64_t selected_index = 0;
	if (requested_template_id == key::empty && !has_requested_profile) {
		const Atom preset = string_of(state, gd::field_or(state, size, key::preset, str(key::empty)));
		const Atom constraints_text = _stable_stringify(state, dict_value(player_constraints));
		selected_index = _stable_choice_index(state, state.array_size(template_candidates),
				gd::format(state, key::consequence_cache_key_text, { str(seed), str(preset), str(constraints_text) }));
	}
	const DictRef selected_template = gd::as_dict(state.at(template_candidates, selected_index));
	const Atom selected_template_id = string_of(state, gd::field_or(state, selected_template, key::id, str(key::empty)));
	DictRef selected_profile = 0;
	bool has_selected_profile = false;
	if (has_requested_profile && string_of(state, gd::field_or(state, requested_profile->second, key::template_id, str(key::empty))) == selected_template_id) {
		selected_profile = requested_profile->second;
		has_selected_profile = true;
	} else {
		const auto by_template = profile_by_template.find(selected_template_id);
		if (by_template != profile_by_template.end()) {
			selected_profile = by_template->second;
			has_selected_profile = true;
		}
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::template_), dict_value(gd::deep_duplicate_dict(state, selected_template)));
	state.set(result, str(key::profile), dict_value(has_selected_profile ? gd::deep_duplicate_dict(state, selected_profile) : state.new_dict()));
	state.set(result, str(key::source), str(source));
	state.set(result, str(key::rejected), bool_value(false));
	state.set(result, str(key::requested_template_id), str(requested_template_id));
	state.set(result, str(key::requested_profile_id), str(requested_profile_id));
	state.set(result, str(key::candidate_count), int_value(state.array_size(template_candidates)));
	state.set(result, str(key::constraint_report), dict_value(_template_constraint_report(state, selected_template, size, player_constraints)));
	return result;
}

bool _player_filter_allows_record(State &state, DictRef record, DictRef player_constraints) {
	Value filter_value;
	if (!state.lookup(record, str(key::player_filter), filter_value) || !gd::is_dict(filter_value) || gd::is_empty(state, filter_value.ref)) {
		return true;
	}
	const DictRef filter = filter_value.ref;
	const int64_t human_count = gd::int_field(state, player_constraints, key::human_count, 1);
	const int64_t computer_count = gd::int_field(state, player_constraints, key::computer_count, 1);
	const int64_t total_count = gd::int_field(state, player_constraints, key::total_count, gd::add(human_count, computer_count));
	const int64_t player_count = gd::int_field(state, player_constraints, key::player_count, total_count);
	return human_count >= gd::int_field(state, filter, key::min_human, 0)
			&& human_count <= gd::int_field(state, filter, key::max_human, 8)
			&& player_count >= gd::int_field(state, filter, key::min_total, 1)
			&& player_count <= gd::int_field(state, filter, key::max_total, 8);
}

ArrayRef _template_active_zones(State &state, DictRef template_, DictRef player_constraints) {
	const ArrayRef zones = state.new_array();
	for (const Value &zone : gd::field_items(state, template_, str(key::zones))) {
		if (gd::is_dict(zone) && _player_filter_allows_record(state, zone.ref, player_constraints)) {
			state.append(zones, zone);
		}
	}
	return zones;
}

ArrayRef _template_active_links(State &state, DictRef template_, DictRef player_constraints, ArrayRef zones) {
	std::unordered_set<Atom> active_zone_ids;
	if (state.array_size(zones) == 0) {
		zones = _template_active_zones(state, template_, player_constraints);
	}
	for (const Value &zone : gd::items(state, array_value(zones))) {
		if (gd::is_dict(zone)) {
			active_zone_ids.insert(string_of(state, gd::field_or(state, zone.ref, key::id, str(key::empty))));
		}
	}
	const ArrayRef links = state.new_array();
	for (const Value &link : gd::field_items(state, template_, str(key::links))) {
		if (!gd::is_dict(link)) {
			continue;
		}
		if (!_player_filter_allows_record(state, link.ref, player_constraints)) {
			continue;
		}
		if (active_zone_ids.count(string_of(state, gd::field_or(state, link.ref, key::from, str(key::empty)))) == 0
				|| active_zone_ids.count(string_of(state, gd::field_or(state, link.ref, key::to, str(key::empty)))) == 0) {
			continue;
		}
		state.append(links, link);
	}
	return links;
}

DictRef _template_constraint_report(State &state, DictRef template_, DictRef size, DictRef player_constraints) {
	const ArrayRef failures = state.new_array();
	const DictRef size_score = dict_field_or_new(state, template_, key::size_score);
	const int64_t score = _template_map_size_score(state, template_, size);
	if (score < gd::int_field(state, size_score, key::min_, 1) || score > gd::int_field(state, size_score, key::max, 999999)) {
		const int64_t low = gd::int_field(state, size_score, key::min_, 1);
		const int64_t high = gd::int_field(state, size_score, key::max, 999999);
		state.append(failures, str(gd::format(state, key::size_score_d_outside_template_range, { int_value(score), int_value(low), int_value(high) })));
	}
	const DictRef map_support = dict_field_or_new(state, template_, key::map_support);
	const Atom requested_water_mode = string_of(state, gd::field_or(state, size, key::water_mode, str(key::land)));
	Value water_modes_value;
	if (!state.lookup(map_support, str(key::water_modes), water_modes_value)) {
		water_modes_value = array_value(land_only(state));
	}
	const ArrayRef supported_water_modes = _normalized_string_array(state, water_modes_value, land_only(state));
	if (!_water_mode_supported(state, requested_water_mode, supported_water_modes)) {
		const Atom modes = join_array(state, key::comma, supported_water_modes);
		state.append(failures, str(gd::format(state, key::water_mode_s_unsupported_by_template, { str(requested_water_mode), str(modes) })));
	}
	const DictRef levels = dict_field_or_new(state, map_support, key::levels);
	ArrayRef supported_counts = state.new_array();
	// levels.get("supported_counts", []) is Array: a missing one is an empty Array.
	Value counts_value;
	if (state.lookup(levels, str(key::supported_counts), counts_value) && gd::is_array(counts_value)) {
		for (const Value &supported_count : gd::items(state, counts_value)) {
			state.append(supported_counts, int_value(gd::to_int(state, supported_count)));
		}
	}
	if (state.array_size(supported_counts) == 0) {
		supported_counts = state.new_array();
		state.append(supported_counts, int_value(1));
	}
	const int64_t requested_level_count = gd::int_field(state, size, key::level_count, 1);
	if (!gd::array_has(state, supported_counts, int_value(requested_level_count))) {
		const Atom counts_json = gd::engine_json_stringify(state, array_value(supported_counts));
		state.append(failures, str(gd::format(state, key::level_count_d_unsupported_by_template, { int_value(requested_level_count), str(counts_json) })));
	}
	const DictRef players = dict_field_or_new(state, template_, key::players);
	const DictRef humans = dict_field_or_new(state, players, key::humans);
	const DictRef total = dict_field_or_new(state, players, key::total);
	const int64_t human_count = gd::int_field(state, player_constraints, key::human_count, 1);
	const int64_t player_count = gd::int_field(state, player_constraints, key::player_count, 2);
	if (human_count < gd::int_field(state, humans, key::min_, 1) || human_count > gd::int_field(state, humans, key::max, 8)) {
		const int64_t low = gd::int_field(state, humans, key::min_, 1);
		const int64_t high = gd::int_field(state, humans, key::max, 8);
		state.append(failures, str(gd::format(state, key::human_count_d_outside_template_range, { int_value(human_count), int_value(low), int_value(high) })));
	}
	if (player_count < gd::int_field(state, total, key::min_, 2) || player_count > gd::int_field(state, total, key::max, 8)) {
		const int64_t low = gd::int_field(state, total, key::min_, 2);
		const int64_t high = gd::int_field(state, total, key::max, 8);
		state.append(failures, str(gd::format(state, key::player_count_d_outside_template_range, { int_value(player_count), int_value(low), int_value(high) })));
	}
	const ArrayRef active_zones = _template_active_zones(state, template_, player_constraints);
	const ArrayRef active_links = _template_active_links(state, template_, player_constraints, active_zones);
	const DictRef capacity = _template_start_capacity(state, active_zones);
	if (gd::int_field(state, capacity, key::human_start_capacity, 0) < human_count) {
		const int64_t human_capacity = gd::int_field(state, capacity, key::human_start_capacity, 0);
		state.append(failures, str(gd::format(state, key::human_start_capacity_d_below_requested, { int_value(human_capacity), int_value(human_count) })));
	}
	if (gd::int_field(state, capacity, key::total_start_capacity, 0) < player_count) {
		const int64_t total_capacity = gd::int_field(state, capacity, key::total_start_capacity, 0);
		state.append(failures, str(gd::format(state, key::total_start_capacity_d_below_requested, { int_value(total_capacity), int_value(player_count) })));
	}
	const DictRef graph_summary = dict_field_or_new(state, template_, key::graph_summary);
	const DictRef error_policy = dict_field_or_new(state, template_, key::error_policy);
	if (state.array_size(active_zones) == 0) {
		state.append(failures, str(key::template_has_no_active_zones_for));
	}
	if (state.array_size(active_links) == 0) {
		state.append(failures, str(key::template_has_no_active_links_for));
	}
	if (gd::to_bool(gd::field_or(state, error_policy, key::disconnected_source_graph, bool_value(false)))
			|| (state.has(graph_summary, str(key::connected)) && !gd::to_bool(gd::field_or(state, graph_summary, key::connected, bool_value(true))))) {
		const Atom policy = string_of(state, gd::field_or(state, error_policy, key::policy, str(key::unknown)));
		state.append(failures, str(gd::format(state, key::template_source_graph_is_disconnected_under, { str(policy) })));
	}
	const DictRef report = state.new_dict();
	state.set(report, str(key::matches), bool_value(state.array_size(failures) == 0));
	state.set(report, str(key::template_id), str(string_of(state, gd::field_or(state, template_, key::id, str(key::empty)))));
	state.set(report, str(key::failures), array_value(failures));
	const DictRef requested = state.new_dict();
	state.set(requested, str(key::size_score), int_value(score));
	state.set(requested, str(key::water_mode), str(requested_water_mode));
	state.set(requested, str(key::level_count), int_value(requested_level_count));
	state.set(requested, str(key::human_count), int_value(human_count));
	state.set(requested, str(key::player_count), int_value(player_count));
	state.set(report, str(key::requested), dict_value(requested));
	const DictRef supported = state.new_dict();
	state.set(supported, str(key::size_score), dict_value(gd::deep_duplicate_dict(state, size_score)));
	state.set(supported, str(key::water_modes), array_value(supported_water_modes));
	state.set(supported, str(key::level_counts), array_value(supported_counts));
	state.set(supported, str(key::humans), dict_value(gd::deep_duplicate_dict(state, humans)));
	state.set(supported, str(key::total), dict_value(gd::deep_duplicate_dict(state, total)));
	state.set(supported, str(key::supported_config_count), int_value(gd::int_field(state, players, key::supported_config_count, 0)));
	state.set(supported, str(key::team_mode), str(string_of(state, gd::field_or(state, players, key::team_mode, str(key::free_for_all)))));
	state.set(report, str(key::supported), dict_value(supported));
	state.set(report, str(key::capacity), dict_value(capacity));
	const DictRef active_graph = state.new_dict();
	state.set(active_graph, str(key::zone_count), int_value(state.array_size(active_zones)));
	state.set(active_graph, str(key::link_count), int_value(state.array_size(active_links)));
	state.set(report, str(key::active_graph), dict_value(active_graph));
	state.set(report, str(key::error_policy), dict_value(error_policy));
	state.set(report, str(key::graph_summary), dict_value(graph_summary));
	return report;
}

DictRef _template_start_capacity(State &state, ArrayRef zones) {
	const DictRef human_slots = state.new_dict();
	const DictRef total_slots = state.new_dict();
	for (const Value &zone : gd::items(state, array_value(zones))) {
		if (!gd::is_dict(zone)) {
			continue;
		}
		const Atom role = string_of(state, gd::field_or(state, zone.ref, key::role, str(key::empty)));
		const Value owner_slot = gd::field(state, zone.ref, key::owner_slot);
		if (owner_slot.kind == Kind::Nil) {
			continue;
		}
		const int64_t slot = gd::to_int(state, owner_slot);
		if (slot <= 0) {
			continue;
		}
		if (role == key::human_start) {
			state.set(human_slots, int_value(slot), bool_value(true));
			state.set(total_slots, int_value(slot), bool_value(true));
		} else if (role == key::computer_start || state.text(role).find(state.text(key::start)) != std::string::npos) {
			state.set(total_slots, int_value(slot), bool_value(true));
		}
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::human_start_capacity), int_value(state.dict_size(human_slots)));
	state.set(result, str(key::total_start_capacity), int_value(state.dict_size(total_slots)));
	state.set(result, str(key::fixed_owner_slots), array_value(_sorted_int_keys(state, total_slots)));
	state.set(result, str(key::human_owner_slots), array_value(_sorted_int_keys(state, human_slots)));
	return result;
}

ArrayRef _selection_rejection_reasons(State &state, Atom failure_code, Atom requested_template_id, Atom requested_profile_id, ArrayRef candidate_rejections) {
	const ArrayRef reasons = state.new_array();
	if (failure_code == key::template_not_found) {
		state.append(reasons, str(gd::format(state, key::requested_template_s_was_not_found, { str(requested_template_id) })));
	} else if (failure_code == key::profile_template_constraints_failed) {
		state.append(reasons, str(gd::format(state, key::requested_profile_s_template_did_not, { str(requested_profile_id) })));
	} else if (failure_code == key::template_constraints_failed) {
		state.append(reasons, str(gd::format(state, key::requested_template_s_did_not_satisfy, { str(requested_template_id) })));
	} else {
		state.append(reasons, str(key::no_catalog_template_satisfied_requested_map));
	}
	for (const Value &rejection : gd::items(state, array_value(candidate_rejections))) {
		if (!gd::is_dict(rejection)) {
			continue;
		}
		for (const Value &failure : gd::field_items(state, rejection.ref, str(key::failures))) {
			const Atom template_id = string_of(state, gd::field_or(state, rejection.ref, key::template_id, str(key::empty)));
			const Atom failure_text = string_of(state, failure);
			state.append(reasons, str(gd::format(state, key::s_colon_s_text, { str(template_id), str(failure_text) })));
		}
	}
	if (state.array_size(reasons) == 0) {
		state.append(reasons, str(failure_code));
	}
	return reasons;
}

int64_t _map_size_score(State &state, DictRef size) {
	Value width_value = gd::field_or(state, size, key::width, int_value(16));
	width_value = gd::field_or(state, size, key::requested_width, width_value);
	width_value = gd::field_or(state, size, key::source_width, width_value);
	const int64_t width = gd::to_int(state, width_value);
	Value height_value = gd::field_or(state, size, key::height, int_value(12));
	height_value = gd::field_or(state, size, key::requested_height, height_value);
	height_value = gd::field_or(state, size, key::source_height, height_value);
	const int64_t height = gd::to_int(state, height_value);
	Value level_value = gd::field_or(state, size, key::level_count, int_value(1));
	level_value = gd::field_or(state, size, key::requested_level_count, level_value);
	const int64_t level_count = gd::to_int(state, level_value);
	// max(1, int((width * height * max(1, level_count)) / 0x510))
	const int64_t levels = 1 < level_count ? level_count : 1;
	const int64_t scaled = compat::int_div(gd::mul(gd::mul(width, height), levels), 0x510);
	return 1 < scaled ? scaled : 1;
}

int64_t _template_map_size_score(State &state, DictRef template_, DictRef size) {
	int64_t score = _map_size_score(state, size);
	const DictRef map_support = dict_field_or_new(state, template_, key::map_support);
	Value water_modes_value;
	if (!state.lookup(map_support, str(key::water_modes), water_modes_value)) {
		water_modes_value = array_value(land_only(state));
	}
	const ArrayRef water_modes = _normalized_string_array(state, water_modes_value, land_only(state));
	if (string_of(state, gd::field_or(state, size, key::water_mode, str(key::land))) == key::islands
			&& gd::array_has(state, water_modes, str(key::islands_size_score_halved))) {
		// max(1, int(ceil(float(score) * 0.5)))
		const int64_t halved = compat::float_to_int(compat::godot_ceil(static_cast<double>(score) * 0.5));
		score = 1 < halved ? halved : 1;
	}
	return score;
}

bool _water_mode_supported(State &state, Atom requested_water_mode, ArrayRef supported_water_modes) {
	if (gd::array_has(state, supported_water_modes, str(requested_water_mode))) {
		return true;
	}
	if (requested_water_mode == key::islands && gd::array_has(state, supported_water_modes, str(key::islands_size_score_halved))) {
		return true;
	}
	if (requested_water_mode == key::normal_water && gd::array_has(state, supported_water_modes, str(key::islands_size_score_halved))) {
		return true;
	}
	return false;
}

Atom _normalize_water_mode(State &state, const Value &value) {
	const Atom mode = to_lower(state, stripped(state, value), "RandomMapGeneratorRules._normalize_water_mode");
	const std::string &text = state.text(mode);
	if (text == "land" || text == "none" || text == "dry") {
		return key::land;
	}
	if (text == "normal_water" || text == "normalwater" || text == "normal-water" || text == "normal water") {
		return key::normal_water;
	}
	if (text == "island" || text == "islands" || text == "water" || text == "mixed") {
		return key::islands;
	}
	return mode != key::empty ? mode : Atom(key::land);
}

int64_t _stable_choice_index(State &state, int64_t size, Atom seed_text) {
	if (size <= 0) {
		return 0;
	}
	return compat::int_mod(_hash32_int(state, seed_text), size);
}

DictRef _merge_profile_with_catalog(State &state, DictRef input_profile, DictRef catalog_profile, DictRef player_constraints) {
	const DictRef merged = gd::deep_duplicate_dict(state, input_profile);
	for (const Atom name : { key::label, key::terrain_ids, key::faction_ids, key::encounter_id, key::guard_strength_profile, key::template_id }) {
		if (!state.has(merged, str(name)) && state.has(catalog_profile, str(name))) {
			state.set(merged, str(name), gd::index(state, catalog_profile, str(name)));
		}
	}
	Value terrain_value;
	if (!state.lookup(merged, str(key::terrain_ids), terrain_value)) {
		terrain_value = array_value(core_terrain_pool(state));
	}
	const ArrayRef terrain_ids = _normalized_string_array(state, terrain_value, core_terrain_pool(state));
	Value faction_value;
	if (!state.lookup(merged, str(key::faction_ids), faction_value)) {
		faction_value = array_value(default_factions(state));
	}
	const ArrayRef faction_ids = _normalized_string_array(state, faction_value, default_factions(state));
	while (state.array_size(faction_ids) < gd::int_field(state, player_constraints, key::player_count, 2)) {
		state.append(faction_ids, str(kDefaultFactions[state.array_size(faction_ids) % kDefaultFactionCount]));
	}
	const ArrayRef town_ids = state.new_array();
	for (const Value &faction_id : gd::items(state, array_value(faction_ids))) {
		state.append(town_ids, str(default_town_by_faction(string_of(state, faction_id))));
	}
	const ArrayRef resource_site_ids = support_resource_site_ids(state);
	state.set(merged, str(key::terrain_ids), array_value(terrain_ids));
	state.set(merged, str(key::faction_ids), array_value(gd::slice(state, faction_ids, 0, gd::int_field(state, player_constraints, key::player_count, 2))));
	state.set(merged, str(key::town_ids), array_value(gd::slice(state, town_ids, 0, gd::int_field(state, player_constraints, key::player_count, 2))));
	state.set(merged, str(key::resource_site_ids), array_value(resource_site_ids));
	state.set(merged, str(key::encounter_id), str(string_of(state, gd::field_or(state, merged, key::encounter_id, str(key::encounter_mire_raid)))));
	state.set(merged, str(key::guard_strength_profile), str(string_of(state, gd::field_or(state, merged, key::guard_strength_profile, str(key::core_low)))));
	const Value catalog_family = gd::field_or(state, catalog_profile, key::template_family, str(key::content_catalog_template_graph));
	state.set(merged, str(key::template_family), str(string_of(state, gd::field_or(state, merged, key::template_family, catalog_family))));
	return merged;
}

DictRef _build_player_assignment(State &state, DictRef template_, DictRef profile, DictRef player_constraints, Atom seed) {
	if (gd::is_empty(state, template_)) {
		return state.new_dict();
	}
	const int64_t player_count = gd::int_field(state, player_constraints, key::player_count, 2);
	const int64_t human_count = gd::int_field(state, player_constraints, key::human_count, 1);
	const Atom team_mode = string_of(state, gd::field_or(state, player_constraints, key::team_mode, str(key::free_for_all)));
	const DictRef capacity = _template_start_capacity(state, _template_active_zones(state, template_, player_constraints));
	const ArrayRef fixed_owner_slots = gd::as_array(field_or_new_array(state, capacity, key::fixed_owner_slots));
	const ArrayRef active_owner_slots = state.new_array();
	for (const Value &owner_slot : gd::items(state, array_value(fixed_owner_slots))) {
		if (gd::to_int(state, owner_slot) > 0 && state.array_size(active_owner_slots) < player_count) {
			state.append(active_owner_slots, int_value(gd::to_int(state, owner_slot)));
		}
	}
	const DictRef template_factions = dict_field_or_new(state, template_, key::faction_constraints);
	const ArrayRef template_allowed = _normalized_string_array(state, field_or_new_array(state, template_factions, key::allowed), default_factions(state));
	Value profile_factions;
	if (!state.lookup(profile, str(key::faction_ids), profile_factions)) {
		profile_factions = array_value(default_factions(state));
	}
	const ArrayRef profile_allowed = _normalized_string_array(state, profile_factions, default_factions(state));
	ArrayRef base_pool = _intersection_string_arrays(state, profile_allowed, template_allowed);
	if (state.array_size(base_pool) == 0) {
		base_pool = state.array_size(template_allowed) != 0 ? template_allowed : profile_allowed;
	}
	Value import_provenance;
	const bool seeded_faction_assignment = state.lookup(template_, str(key::import_provenance), import_provenance)
			&& gd::is_dict(import_provenance) && !gd::is_empty(state, import_provenance.ref);
	const Atom template_id = string_of(state, gd::field_or(state, template_, key::id, str(key::empty)));
	DeterministicRng rng(_positive_seed(state, gd::format(state, key::s_s_player_assignment, { str(seed), str(template_id) })));
	const ArrayRef player_slots = state.new_array();
	const DictRef by_owner_slot = state.new_dict();
	const ArrayRef assigned_faction_ids = state.new_array();
	const ArrayRef assigned_town_ids = state.new_array();
	const int64_t active_count = state.array_size(active_owner_slots);
	for (int64_t index = 0; index < active_count; ++index) {
		const int64_t owner_slot = gd::to_int(state, state.at(active_owner_slots, index));
		const ArrayRef zone_allowed = _allowed_factions_for_owner_slot(state, template_, owner_slot);
		ArrayRef pool = state.array_size(zone_allowed) != 0 ? _intersection_string_arrays(state, base_pool, zone_allowed) : gd::duplicate_array(state, base_pool);
		if (state.array_size(pool) == 0) {
			pool = gd::duplicate_array(state, base_pool);
		}
		if (seeded_faction_assignment) {
			sort_strings(state, pool, "RandomMapGeneratorRules._build_player_assignment");
		}
		Atom faction_id;
		if (seeded_faction_assignment) {
			faction_id = string_of(state, state.at(pool, rng.next_index(state.array_size(pool))));
		} else {
			const int64_t pool_size = state.array_size(pool);
			if (pool_size == 0) {
				throw state::ScriptError("Modulo by zero error in operator '%'.");
			}
			faction_id = string_of(state, state.at(pool, compat::int_mod(index, pool_size)));
		}
		if (seeded_faction_assignment && state.array_size(pool) > 1) {
			int64_t guard = 0;
			while (gd::array_has(state, assigned_faction_ids, str(faction_id)) && guard < state.array_size(pool)) {
				faction_id = string_of(state, state.at(pool, rng.next_index(state.array_size(pool))));
				guard += 1;
			}
		}
		const int64_t player_slot = index + 1;
		const Atom player_type = player_slot <= human_count ? key::human : key::computer;
		// "team_%02d" % player_slot (player_slot is 1 or more)
		std::string team_text = compat::itos(player_slot);
		if (team_text.size() < 2) {
			team_text.insert(0, 2 - team_text.size(), '0');
		}
		const Atom team_id = state.intern("team_" + team_text);
		const Atom town_id = default_town_by_faction(faction_id);
		const DictRef slot_record = state.new_dict();
		state.set(slot_record, str(key::player_slot), int_value(player_slot));
		state.set(slot_record, str(key::owner_slot), int_value(owner_slot));
		state.set(slot_record, str(key::player_type), str(player_type));
		state.set(slot_record, str(key::faction_id), str(faction_id));
		state.set(slot_record, str(key::town_id), str(town_id));
		state.set(slot_record, str(key::team_id), str(team_id));
		state.set(slot_record, str(key::team_mode), str(team_mode));
		state.set(slot_record, str(key::ai_controlled), bool_value(player_type != key::human));
		state.set(slot_record, str(key::assignment_source), str(seeded_faction_assignment ? key::fixed_owner_slot_seeded_faction_selection : key::fixed_owner_slot_profile_order_preserved));
		state.append(player_slots, dict_value(slot_record));
		state.set(by_owner_slot, str(gd::stringify(state, int_value(owner_slot))), dict_value(slot_record));
		state.append(assigned_faction_ids, str(faction_id));
		state.append(assigned_town_ids, str(town_id));
	}
	const ArrayRef teams = state.new_array();
	for (const Value &slot_record : gd::items(state, array_value(player_slots))) {
		const DictRef record = gd::as_dict(slot_record);
		const DictRef team = state.new_dict();
		state.set(team, str(key::team_id), str(string_of(state, gd::field_or(state, record, key::team_id, str(key::empty)))));
		const ArrayRef team_player_slots = state.new_array();
		state.append(team_player_slots, int_value(gd::int_field(state, record, key::player_slot, 0)));
		state.set(team, str(key::player_slots), array_value(team_player_slots));
		state.set(team, str(key::mode), str(key::free_for_all));
		state.append(teams, dict_value(team));
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::schema_id), str(key::random_map_player_assignment_v1));
	state.set(result, str(key::assignment_policy), str(seeded_faction_assignment ? key::fixed_owner_slots_first_n_players_seeded_factions : key::fixed_owner_slots_first_n_players_profile_order_preserved));
	state.set(result, str(key::team_mode), str(team_mode));
	const DictRef team_metadata = state.new_dict();
	state.set(team_metadata, str(key::mode), str(key::free_for_all));
	state.set(team_metadata, str(key::supported_now), bool_value(team_mode == key::free_for_all));
	state.set(team_metadata, str(key::requested_mode), str(team_mode));
	state.set(team_metadata, str(key::teams), array_value(teams));
	state.set(result, str(key::team_metadata), dict_value(team_metadata));
	state.set(result, str(key::human_count), int_value(human_count));
	// int(player_constraints.get("computer_count", max(0, player_count - human_count)))
	const int64_t computers_left = gd::sub(player_count, human_count);
	state.set(result, str(key::computer_count), int_value(gd::int_field(state, player_constraints, key::computer_count, 0 < computers_left ? computers_left : 0)));
	state.set(result, str(key::player_count), int_value(player_count));
	state.set(result, str(key::capacity), dict_value(capacity));
	state.set(result, str(key::active_owner_slots), array_value(active_owner_slots));
	state.set(result, str(key::inactive_owner_slots), array_value(_inactive_owner_slots(state, fixed_owner_slots, active_owner_slots)));
	state.set(result, str(key::player_slots), array_value(player_slots));
	state.set(result, str(key::player_slot_by_owner_slot), dict_value(by_owner_slot));
	state.set(result, str(key::assigned_faction_ids), array_value(assigned_faction_ids));
	state.set(result, str(key::assigned_town_ids), array_value(assigned_town_ids));
	state.set(result, str(key::faction_pool), array_value(base_pool));
	return result;
}

ArrayRef _allowed_factions_for_owner_slot(State &state, DictRef template_, int64_t owner_slot) {
	ArrayRef result = state.new_array();
	for (const Value &zone : gd::field_items(state, template_, str(key::zones))) {
		if (!gd::is_dict(zone) || gd::field(state, zone.ref, key::owner_slot).kind == Kind::Nil
				|| gd::int_field(state, zone.ref, key::owner_slot, 0) != owner_slot) {
			continue;
		}
		result = _normalized_string_array(state, field_or_new_array(state, zone.ref, key::allowed_faction_ids), state.new_array());
		const DictRef town_policy = dict_field_or_new(state, zone.ref, key::town_policy);
		if (state.array_size(result) != 0) {
			result = _intersection_string_arrays(state, result, _normalized_string_array(state, field_or_new_array(state, town_policy, key::allowed_faction_ids), result));
		} else {
			result = _normalized_string_array(state, field_or_new_array(state, town_policy, key::allowed_faction_ids), state.new_array());
		}
		break;
	}
	return result;
}

ArrayRef _intersection_string_arrays(State &state, ArrayRef left, ArrayRef right) {
	const ArrayRef result = state.new_array();
	for (const Value &value : gd::items(state, array_value(left))) {
		const Atom text = string_of(state, value);
		if (gd::array_has(state, right, str(text)) && !gd::array_has(state, result, str(text))) {
			state.append(result, str(text));
		}
	}
	return result;
}

ArrayRef _inactive_owner_slots(State &state, ArrayRef fixed_owner_slots, ArrayRef active_owner_slots) {
	const ArrayRef result = state.new_array();
	for (const Value &owner_slot : gd::items(state, array_value(fixed_owner_slots))) {
		if (!gd::array_has(state, active_owner_slots, int_value(gd::to_int(state, owner_slot)))) {
			state.append(result, int_value(gd::to_int(state, owner_slot)));
		}
	}
	return result;
}

DictRef _normalize_size(State &state, const Value &size_value) {
	Atom preset = key::small;
	int64_t width = 16;
	int64_t height = 12;
	Atom water_mode = key::land;
	int64_t level_count = 1;
	Atom size_class_id = key::empty;
	Atom size_class_label = key::empty;
	Atom source_model = key::custom_runtime_dimensions;
	int64_t source_width = 0;
	int64_t source_height = 0;
	int64_t requested_level_count = 1;
	if (gd::is_string(size_value)) {
		preset = to_lower(state, stripped(state, size_value), "RandomMapGeneratorRules._normalize_size");
		if (preset == key::medium) {
			width = 24;
			height = 18;
		} else if (preset == key::large) {
			width = 32;
			height = 24;
		} else {
			preset = key::small;
		}
	} else if (gd::is_dict(size_value)) {
		const DictRef size = size_value.ref;
		preset = to_lower(state, stripped(state, gd::field_or(state, size, key::preset, str(key::custom))), "RandomMapGeneratorRules._normalize_size");
		const Value class_id = gd::field_or(state, size, key::class_id, str(key::empty));
		size_class_id = stripped(state, gd::field_or(state, size, key::size_class_id, class_id));
		size_class_label = stripped(state, gd::field_or(state, size, key::size_class_label, str(key::empty)));
		source_model = stripped(state, gd::field_or(state, size, key::source_model, str(source_model)));
		Value width_value = gd::field_or(state, size, key::width, int_value(width));
		width_value = gd::field_or(state, size, key::requested_width, width_value);
		source_width =gd::to_int(state, gd::field_or(state, size, key::source_width, width_value));
		Value height_value = gd::field_or(state, size, key::height, int_value(height));
		height_value = gd::field_or(state, size, key::requested_height, height_value);
		source_height = gd::to_int(state, gd::field_or(state, size, key::source_height, height_value));
		width = source_width;
		height = source_height;
		const Value water = gd::field_or(state, size, key::water, str(water_mode));
		water_mode = _normalize_water_mode(state, gd::field_or(state, size, key::water_mode, water));
		const Value levels = gd::field_or(state, size, key::levels, int_value(level_count));
		requested_level_count = compat::engine_clamp<int64_t>(gd::to_int(state, gd::field_or(state, size, key::level_count, levels)), 1, 2);
		level_count = requested_level_count;
	}
	if (source_width <= 0) {
		source_width = width;
	}
	if (source_height <= 0) {
		source_height = height;
	}
	if (size_class_label == key::empty && size_class_id != key::empty) {
		size_class_label = gd::capitalize(state, gd::replace(state, size_class_id, key::_, key::space));
	}
	const int64_t cap_width = 144;
	const int64_t cap_height = 144;
	const int64_t cap_level_count = 2;
	const int64_t materialized_width = compat::engine_clamp<int64_t>(source_width, 8, cap_width);
	const int64_t materialized_height = compat::engine_clamp<int64_t>(source_height, 8, cap_height);
	const int64_t materialized_level_count = compat::engine_clamp<int64_t>(requested_level_count, 1, cap_level_count);
	const bool exceeds_cap = source_width != materialized_width || source_height != materialized_height || requested_level_count != materialized_level_count;
	DictRef provided_policy = 0;
	bool has_provided_policy = false;
	if (gd::is_dict(size_value)) {
		Value policy_value;
		if (state.lookup(size_value.ref, str(key::runtime_size_policy), policy_value) && gd::is_dict(policy_value)) {
			provided_policy = policy_value.ref;
			has_provided_policy = true;
		}
	}
	// provided_policy.get(name, fallback) of the size's policy, or of {}.
	const auto policy_get = [&state, provided_policy, has_provided_policy](Atom name, const Value &fallback) {
		return has_provided_policy ? gd::field_or(state, provided_policy, name, fallback) : fallback;
	};
	bool materialization_available = gd::to_bool(policy_get(key::materialization_available, bool_value(!exceeds_cap)));
	if (exceeds_cap) {
		materialization_available = false;
	}
	const Atom status = string_of(state, policy_get(key::status,
			str(materialization_available ? key::materialize_at_requested_size_within_current_144x144x2_cap : key::blocked_source_size_exceeds_current_144x144x2_cap)));
	Atom rationale = string_of(state, policy_get(key::rationale, str(key::empty)));
	if (!materialization_available && rationale == key::empty) {
		rationale = gd::format(state, key::requested_source_size_dx_dx_d, { int_value(source_width), int_value(source_height), int_value(requested_level_count), int_value(cap_width), int_value(cap_height), int_value(cap_level_count) });
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::preset), str(preset));
	state.set(result, str(key::size_class_id), str(size_class_id));
	state.set(result, str(key::size_class_label), str(size_class_label));
	state.set(result, str(key::source_model), str(source_model));
	state.set(result, str(key::source_width), int_value(source_width));
	state.set(result, str(key::source_height), int_value(source_height));
	state.set(result, str(key::requested_width), int_value(source_width));
	state.set(result, str(key::requested_height), int_value(source_height));
	state.set(result, str(key::requested_level_count), int_value(requested_level_count));
	state.set(result, str(key::width), int_value(materialized_width));
	state.set(result, str(key::height), int_value(materialized_height));
	state.set(result, str(key::water_mode), str(water_mode));
	state.set(result, str(key::level_count), int_value(materialized_level_count));
	state.set(result, str(key::underground), bool_value(materialized_level_count > 1));
	state.set(result, str(key::runtime_size_cap), dict_value(runtime_size_cap(state)));
	const DictRef policy = state.new_dict();
	state.set(policy, str(key::status), str(status));
	state.set(policy, str(key::materialization_available), bool_value(materialization_available));
	const DictRef source_size = state.new_dict();
	state.set(source_size, str(key::width), int_value(source_width));
	state.set(source_size, str(key::height), int_value(source_height));
	state.set(source_size, str(key::level_count), int_value(requested_level_count));
	state.set(policy, str(key::source_size), dict_value(source_size));
	const DictRef materialized_size = state.new_dict();
	state.set(materialized_size, str(key::width), int_value(materialized_width));
	state.set(materialized_size, str(key::height), int_value(materialized_height));
	state.set(materialized_size, str(key::level_count), int_value(materialized_level_count));
	state.set(policy, str(key::materialized_size), dict_value(materialized_size));
	state.set(policy, str(key::cap), dict_value(runtime_size_cap(state)));
	state.set(policy, str(key::hidden_downscale), bool_value(false));
	state.set(policy, str(key::rationale), str(rationale));
	state.set(result, str(key::runtime_size_policy), dict_value(policy));
	return result;
}

DictRef _normalize_player_constraints(State &state, const Value &value) {
	int64_t human_count = 1;
	int64_t computer_count = 1;
	int64_t player_count = 2;
	Atom team_mode = key::free_for_all;
	if (gd::is_dict(value)) {
		const DictRef constraints = value.ref;
		const Value humans = gd::field_or(state, constraints, key::humans, int_value(human_count));
		human_count = compat::engine_clamp<int64_t>(gd::to_int(state, gd::field_or(state, constraints, key::human_count, humans)), 1, 8);
		if (state.has(constraints, str(key::player_count)) || state.has(constraints, str(key::total_count)) || state.has(constraints, str(key::total))) {
			Value total = gd::field_or(state, constraints, key::total, int_value(player_count));
			total = gd::field_or(state, constraints, key::total_count, total);
			player_count = compat::engine_clamp<int64_t>(gd::to_int(state, gd::field_or(state, constraints, key::player_count, total)), 1, 8);
			// max(player_count, human_count), then max(0, player_count - human_count)
			player_count = player_count < human_count ? human_count : player_count;
			const int64_t computers_left = player_count - human_count;
			computer_count = 0 < computers_left ? computers_left : 0;
		} else {
			const Value computers = gd::field_or(state, constraints, key::computers, int_value(computer_count));
			computer_count = compat::engine_clamp<int64_t>(gd::to_int(state, gd::field_or(state, constraints, key::computer_count, computers)), 0, 7);
			player_count = compat::engine_clamp<int64_t>(human_count + computer_count, 1, 8);
		}
		team_mode = to_lower(state, stripped(state, gd::field_or(state, constraints, key::team_mode, str(team_mode))), "RandomMapGeneratorRules._normalize_player_constraints");
	}
	if (team_mode == key::empty) {
		team_mode = key::free_for_all;
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::human_count), int_value(human_count));
	state.set(result, str(key::computer_count), int_value(computer_count));
	state.set(result, str(key::player_count), int_value(player_count));
	state.set(result, str(key::team_mode), str(team_mode));
	return result;
}

DictRef _normalize_profile(State &state, const Value &value, DictRef player_constraints) {
	const DictRef profile = gd::is_dict(value) ? value.ref : state.new_dict();
	Atom profile_id = stripped(state, gd::field_or(state, profile, key::id, str(key::seeded_core_frontier)));
	if (profile_id == key::empty) {
		profile_id = key::seeded_core_frontier;
	}
	Value terrain_value;
	if (!state.lookup(profile, str(key::terrain_ids), terrain_value)) {
		terrain_value = array_value(core_terrain_pool(state));
	}
	const ArrayRef terrain_ids = _normalized_string_array(state, terrain_value, core_terrain_pool(state));
	Value faction_value;
	if (!state.lookup(profile, str(key::faction_ids), faction_value)) {
		faction_value = array_value(default_factions(state));
	}
	const ArrayRef faction_ids = _normalized_string_array(state, faction_value, default_factions(state));
	while (state.array_size(faction_ids) < gd::int_field(state, player_constraints, key::player_count, 2)) {
		state.append(faction_ids, str(kDefaultFactions[state.array_size(faction_ids) % kDefaultFactionCount]));
	}
	const ArrayRef town_ids = state.new_array();
	for (const Value &faction_id : gd::items(state, array_value(faction_ids))) {
		state.append(town_ids, str(default_town_by_faction(string_of(state, faction_id))));
	}
	const ArrayRef resource_site_ids = support_resource_site_ids(state);
	const DictRef result = state.new_dict();
	state.set(result, str(key::id), str(profile_id));
	state.set(result, str(key::label), str(stripped(state, gd::field_or(state, profile, key::label, str(key::seeded_core_frontier_2)))));
	state.set(result, str(key::template_id), str(stripped(state, gd::field_or(state, profile, key::template_id, str(key::empty)))));
	state.set(result, str(key::template_family), str(key::zone_connection_spoke));
	state.set(result, str(key::terrain_ids), array_value(terrain_ids));
	state.set(result, str(key::faction_ids), array_value(gd::slice(state, faction_ids, 0, gd::int_field(state, player_constraints, key::player_count, 2))));
	state.set(result, str(key::town_ids), array_value(gd::slice(state, town_ids, 0, gd::int_field(state, player_constraints, key::player_count, 2))));
	state.set(result, str(key::resource_site_ids), array_value(resource_site_ids));
	state.set(result, str(key::encounter_id), str(string_of(state, gd::field_or(state, profile, key::encounter_id, str(key::encounter_mire_raid)))));
	state.set(result, str(key::guard_strength_profile), str(string_of(state, gd::field_or(state, profile, key::guard_strength_profile, str(key::core_low)))));
	return result;
}

ArrayRef _normalized_string_array(State &state, const Value &value, ArrayRef fallback) {
	ArrayRef result = state.new_array();
	if (gd::is_array(value)) {
		for (const Value &item : gd::items(state, value)) {
			const Atom text = stripped(state, item);
			if (text != key::empty && !gd::array_has(state, result, str(text))) {
				state.append(result, str(text));
			}
		}
	}
	if (state.array_size(result) == 0) {
		result = gd::duplicate_array(state, fallback);
	}
	return result;
}

ArrayRef _sorted_keys(State &state, DictRef value) {
	const ArrayRef keys = state.new_array();
	for (const Value &dict_key : gd::items(state, dict_value(value))) {
		state.append(keys, str(string_of(state, dict_key)));
	}
	sort_strings(state, keys, "RandomMapGeneratorRules._sorted_keys");
	return keys;
}

ArrayRef _sorted_int_keys(State &state, DictRef value) {
	const ArrayRef keys = state.new_array();
	for (const Value &dict_key : gd::items(state, dict_value(value))) {
		state.append(keys, int_value(gd::to_int(state, dict_key)));
	}
	gd::sort_custom(state, keys, [](const Value &a, const Value &b) { return gd::op_less(a, b); });
	return keys;
}

int64_t _positive_seed(State &state, Atom seed_text) {
	const int64_t hashed = _hash32_int(state, seed_text);
	return compat::int_mod(hashed, kRngModulus - 1) + 1;
}

Atom _hash32_hex(State &state, Atom text) {
	static const char kHexDigits[] = "0123456789abcdef"; // HEX_DIGITS
	int64_t value = _hash32_int(state, text);
	std::string chars;
	for (int index = 0; index < 8; ++index) {
		chars.insert(chars.begin(), kHexDigits[compat::int_mod(value, 16)]);
		value = compat::int_div(value, 16);
	}
	return state.intern(chars);
}

int64_t _hash32_int(State &state, Atom text) {
	int64_t value = 2166136261;
	for (const uint32_t point : code_points(state.text(text))) {
		value = compat::int_mod(value ^ static_cast<int64_t>(point), kHashModulus);
		value = compat::int_mod(gd::mul(value, 16777619), kHashModulus);
	}
	return value;
}

Atom _stable_stringify(State &state, const Value &value) {
	// "%s:%s" % [...], ",".join(parts) and "{%s}" / "[%s]" of Strings: the texts
	// put together as they are.
	if (gd::is_dict(value)) {
		const ArrayRef keys = _sorted_keys(state, value.ref);
		std::string out = "{";
		bool first = true;
		for (const Value &dict_key : gd::items(state, array_value(keys))) {
			const Atom key_text = string_of(state, dict_key);
			const Atom key_json = gd::engine_json_stringify(state, str(key_text));
			const Atom item = _stable_stringify(state, gd::index(state, value.ref, str(key_text)));
			if (!first) {
				out += ",";
			}
			first = false;
			out += state.text(key_json);
			out += ":";
			out += state.text(item);
		}
		out += "}";
		return state.intern(out);
	}
	if (gd::is_array(value)) {
		std::string out = "[";
		bool first = true;
		for (const Value &item : gd::items(state, value)) {
			const Atom part = _stable_stringify(state, item);
			if (!first) {
				out += ",";
			}
			first = false;
			out += state.text(part);
		}
		out += "]";
		return state.intern(out);
	}
	if (gd::is_string(value)) {
		return gd::engine_json_stringify(state, value);
	}
	if (gd::is_bool(value)) {
		return value.b ? key::true_ : key::false_;
	}
	if (value.kind == Kind::Nil) {
		return key::null;
	}
	return gd::engine_json_stringify(state, value);
}

} // namespace random_map_generator_rules

} // namespace aurelion::rules::port
