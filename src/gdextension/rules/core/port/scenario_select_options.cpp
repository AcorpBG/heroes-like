// ScenarioSelectRules.gd: difficulty, labels, seeds, the player's random-map
// config and its seats (Phase 7, 7.11).

#include "aurelion_rules/port/scenario_select_rules_setup.hpp"

#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/session_state_store.hpp"

#include <cstdint>
#include <string>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::str;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// DIFFICULTY_OPTIONS.
struct DifficultyOption {
	Atom id;
	Atom label;
	Atom summary;
};
constexpr DifficultyOption kDifficultyOptions[] = {
	{ key::story, key::Story, key::extra_movement_and_economy_slower_enemy },
	{ key::normal, key::Captain, key::baseline_expedition_pressure_economy_and_combat },
	{ key::hard, key::Warlord, key::reduced_movement_and_income_faster_raids },
};

// RANDOM_MAP_SIZE_CLASS_DEFAULTS.
struct SizeClassDefault {
	Atom size_class_id;
	Atom template_id;
	Atom profile_id;
	int64_t player_count;
};
constexpr SizeClassDefault kSizeClassDefaults[] = {
	{ key::homm3_small, key::translated_rmg_template_049_v1, key::translated_rmg_profile_049_v1, 3 },
	{ key::homm3_medium, key::translated_rmg_template_002_v1, key::translated_rmg_profile_002_v1, 4 },
	{ key::homm3_large, key::translated_rmg_template_042_v1, key::translated_rmg_profile_042_v1, 4 },
	{ key::homm3_extra_large, key::translated_rmg_template_043_v1, key::translated_rmg_profile_043_v1, 5 },
};

// RandomMapGeneratorRules.DEFAULT_HERO_BY_FACTION.
struct DefaultHero {
	Atom faction_id;
	Atom hero_id;
};
constexpr DefaultHero kDefaultHeroByFaction[] = {
	{ key::faction_embercourt, key::hero_lyra },
	{ key::faction_mireclaw, key::hero_vaska },
	{ key::faction_sunvault, key::hero_solera },
	{ key::faction_thornwake, key::hero_thornwake_ardren_briarmarshal },
	{ key::faction_brasshollow, key::hero_brasshollow_marka_ironclause },
	{ key::faction_veilmourn, key::hero_veilmourn_ivara_blacktide },
};

// String(d.get(key, fallback)).
Atom string_of(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// A String field of a session's view (session.scenario_id and the like).
Atom view_string(State &state, DictRef view, Atom field) {
	return gd::to_string(gd::index(state, view, str(field)));
}

// ContentService.get_content_ids(path).
Value content_ids(State &state, Atom path) {
	return gd::call_method(state, gd::autoload(state, key::ContentService), key::get_content_ids, { str(path) });
}

bool is_lead_byte(char c) {
	return (static_cast<unsigned char>(c) & 0xc0u) != 0x80u;
}

// s.length(): the code points of the UTF-8.
int64_t code_point_count(const std::string &text) {
	int64_t count = 0;
	for (const char c : text) {
		if (is_lead_byte(c)) {
			++count;
		}
	}
	return count;
}

// The byte offset of code point `index`; the text's size past the last one.
size_t byte_offset(const std::string &text, int64_t index) {
	int64_t seen = 0;
	for (size_t at = 0; at < text.size(); ++at) {
		if (is_lead_byte(text[at])) {
			if (seen == index) {
				return at;
			}
			++seen;
		}
	}
	return text.size();
}

// s.unicode_at(i) for each i in range(s.length()).
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

// s.split(delimiter, false) of a one-character ASCII delimiter.
std::vector<std::string> split_skipping_empty(const std::string &text, char delimiter) {
	std::vector<std::string> pieces;
	size_t from = 0;
	while (true) {
		size_t end = text.find(delimiter, from);
		if (end == std::string::npos) {
			end = text.size();
		}
		if (end > from) {
			pieces.push_back(text.substr(from, end - from));
		}
		if (end == text.size()) {
			break;
		}
		from = end + 1;
	}
	return pieces;
}

// s.to_upper() / s.to_lower() of ASCII text (the engine's Unicode case tables
// are not ported).
std::string ascii_case(const std::string &text, bool upper, const char *where) {
	std::string changed = text;
	for (char &c : changed) {
		if (static_cast<unsigned char>(c) >= 0x80) {
			throw state::NotPorted(std::string(where) + ": a case change of non-ASCII text");
		}
		if (upper && c >= 'a' && c <= 'z') {
			c = static_cast<char>(c - 'a' + 'A');
		} else if (!upper && c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
		}
	}
	return changed;
}

// s.hex_to_int() of lower-case hex digits (a SHA-256 digest's prefix).
int64_t hex_digits_to_int(const std::string &digits) {
	int64_t value = 0;
	for (const char c : digits) {
		value = value * 16 + (c >= 'a' ? c - 'a' + 10 : c - '0');
	}
	return value;
}

// path.get_file().get_basename().
std::string file_basename(const std::string &path) {
	const size_t separator = path.find_last_of("/\\");
	const std::string file = separator == std::string::npos ? path : path.substr(separator + 1);
	const size_t dot = file.rfind('.');
	if (dot == std::string::npos) {
		return file;
	}
	const size_t file_separator = file.find_last_of("/\\");
	if (file_separator != std::string::npos && dot < file_separator) {
		return file;
	}
	return file.substr(0, dot);
}

// sep.join(texts).
Atom join_texts(State &state, const std::vector<Atom> &texts, char separator) {
	std::string joined;
	for (size_t index = 0; index < texts.size(); ++index) {
		if (index > 0) {
			joined += separator;
		}
		joined += state.text(texts[index]);
	}
	return state.intern(joined);
}

} // namespace

namespace scenario_select_rules {

ArrayRef build_difficulty_options(State &state, Atom selected_id) {
	const Atom normalized_id = normalize_difficulty(state, str(selected_id));
	const ArrayRef options = state.new_array();
	for (const DifficultyOption &option : kDifficultyOptions) {
		const DictRef item = state.new_dict();
		state.set(item, str(key::id), str(option.id));
		state.set(item, str(key::label), str(option.label));
		state.set(item, str(key::summary), str(option.summary));
		state.set(item, str(key::selected), gd::bool_value(string_of(state, item, key::id, key::empty) == normalized_id));
		state.append(options, dict_value(item));
	}
	return options;
}

Atom difficulty_label(State &state, Atom difficulty_id) {
	const Atom normalized_id = normalize_difficulty(state, str(difficulty_id));
	for (const DifficultyOption &option : kDifficultyOptions) {
		if (option.id == normalized_id) {
			return option.label;
		}
	}
	return key::Captain;
}

Atom difficulty_summary(State &state, Atom difficulty_id) {
	const Atom normalized_id = normalize_difficulty(state, str(difficulty_id));
	for (const DifficultyOption &option : kDifficultyOptions) {
		if (option.id == normalized_id) {
			return option.summary;
		}
	}
	return key::empty;
}

Atom launch_mode_label(State &state, Atom launch_mode) {
	const Atom normalized_mode = session_state_store::normalize_launch_mode(state, str(launch_mode));
	if (normalized_mode == key::generated_draft) {
		return key::generated_draft_2;
	}
	return normalized_mode == key::skirmish ? key::Skirmish : key::Campaign;
}

Atom build_current_session_summary(State &state, const Value &session) {
	if (session.kind == Kind::Nil) {
		return key::campaign_progress_is_saved_separately_from;
	}
	const DictRef view = gd::object_view(state, session);
	const Atom scenario_id = view_string(state, view, key::scenario_id);
	if (scenario_id == key::empty) {
		return key::campaign_progress_is_saved_separately_from;
	}
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, scenario_id);
	const Atom scenario_name = gd::stringify(state, state.get(scenario, str(key::name), str(scenario_id)));
	const Atom mode_label = launch_mode_label(state, view_string(state, view, key::launch_mode));
	const Atom selected_difficulty_label = difficulty_label(state, view_string(state, view, key::difficulty));
	std::vector<Atom> lines;
	lines.push_back(gd::format(state, key::s_s_s_6, { str(mode_label), str(selected_difficulty_label), str(scenario_name) }));
	if (view_string(state, view, key::scenario_summary) != key::empty) {
		const Atom status_text = gd::stringify(state, gd::index(state, view, str(key::scenario_status)));
		const Atom status_label = gd::capitalize(state, gd::replace(state, status_text, key::_, key::space));
		const Atom scenario_summary = view_string(state, view, key::scenario_summary);
		lines.push_back(gd::format(state, key::s_colon_s_text, { str(status_label), str(scenario_summary) }));
	}
	const DictRef overworld = session_view::overworld(state, view);
	Value hero;
	if (!state.lookup(overworld, str(key::hero), hero)) {
		hero = dict_value(state.new_dict());
	}
	const Atom hero_summary = hero_progression_rules::brief_summary(state, gd::as_dict(hero));
	if (hero_summary != key::empty) {
		lines.push_back(gd::format(state, key::hero_specialties_s, { str(hero_summary) }));
	}
	return join_texts(state, lines, '\n');
}

ArrayRef random_map_faction_options(State &state) {
	const ArrayRef options = state.new_array();
	const Value faction_ids = content_ids(state, key::factions_path);
	for (const Value &faction_id : gd::items(state, faction_ids)) {
		const DictRef faction = gd::content_row(state, ContentTable::Faction, gd::to_string(faction_id));
		if (gd::is_empty(state, faction)) {
			continue;
		}
		const DictRef option = state.new_dict();
		state.set(option, str(key::id), str(gd::stringify(state, faction_id)));
		state.set(option, str(key::label), str(gd::stringify(state, state.get(faction, str(key::name), faction_id))));
		state.append(options, dict_value(option));
	}
	return options;
}

ArrayRef random_map_hero_options_for_faction(State &state, Atom faction_id) {
	const ArrayRef options = state.new_array();
	const Value hero_ids = content_ids(state, key::heroes_path);
	for (const Value &hero_id : gd::items(state, hero_ids)) {
		const DictRef hero = gd::content_row(state, ContentTable::Hero, gd::to_string(hero_id));
		if (gd::is_empty(state, hero)
				|| string_of(state, hero, key::faction_id, key::empty) != faction_id
				|| string_of(state, hero, key::roster_state, key::live) == key::scaffold) {
			continue;
		}
		const DictRef option = state.new_dict();
		state.set(option, str(key::id), str(gd::stringify(state, hero_id)));
		state.set(option, str(key::label), str(gd::stringify(state, state.get(hero, str(key::name), hero_id))));
		state.set(option, str(key::faction_id), str(faction_id));
		state.append(options, dict_value(option));
	}
	return options;
}

Atom random_map_default_hero_id_for_faction(State &state, Atom faction_id) {
	Atom preferred = key::empty;
	for (const DefaultHero &entry : kDefaultHeroByFaction) {
		if (entry.faction_id == faction_id) {
			preferred = entry.hero_id;
			break;
		}
	}
	const DictRef preferred_hero = gd::content_row(state, ContentTable::Hero, preferred);
	if (!gd::is_empty(state, preferred_hero) && string_of(state, preferred_hero, key::faction_id, key::empty) == faction_id) {
		return preferred;
	}
	const ArrayRef options = random_map_hero_options_for_faction(state, faction_id);
	if (state.array_size(options) == 0) {
		return key::empty;
	}
	return gd::stringify(state, ai::vget(state, state.at(options, 0), key::id, str(key::empty)));
}

bool random_map_seed_requests_auto(State &state, Atom seed) {
	const Atom normalized_seed = gd::strip_edges(state, seed);
	return normalized_seed == key::empty || normalized_seed == key::aurelion_random_skirmish_10184;
}

Atom random_map_fresh_auto_seed(State &state) {
	const int64_t unix_seconds = compat::float_to_int(gd::engine_unix_time(state));
	const int64_t ticks = gd::engine_ticks_usec(state);
	const Atom mixed_text = gd::format(state, key::d_d, { gd::int_value(unix_seconds), gd::int_value(ticks) });
	const int64_t mixed_seed = gd::hash(state, str(mixed_text)) & 0x7fffffff;
	return state.intern(compat::itos(compat::engine_max<int64_t>(1, mixed_seed)));
}

DictRef random_map_h3maped_seed_record(State &state, Atom seed) {
	Atom input_seed = gd::strip_edges(state, seed);
	if (input_seed == key::empty) {
		input_seed = key::aurelion_random_skirmish_10184;
	}
	Atom numeric_seed = input_seed;
	Atom source = key::numeric;
	if (!_random_map_seed_is_unsigned_integer(state, input_seed)) {
		const Atom hash_input = gd::format(state, key::h3maped_seed_s, { str(input_seed) });
		numeric_seed = state.intern(compat::itos(_stable_hash_u31(state, hash_input)));
		source = key::stable_text_seed_hash;
	}
	const DictRef record = state.new_dict();
	state.set(record, str(key::input_seed), str(input_seed));
	state.set(record, str(key::normalized_seed), str(numeric_seed));
	state.set(record, str(key::source), str(source));
	state.set(record, str(key::algorithm), str(source == key::stable_text_seed_hash ? key::fnv1a32_positive_31bit : key::unsigned_decimal_passthrough));
	state.set(record, str(key::h3maped_requires_numeric_seed), gd::bool_value(true));
	return record;
}

bool _random_map_seed_is_unsigned_integer(State &state, Atom seed) {
	// Every byte of a code point past ASCII is past '9' too.
	const std::string &value = state.text(gd::strip_edges(state, seed));
	if (value.empty()) {
		return false;
	}
	for (const char c : value) {
		const unsigned char code = static_cast<unsigned char>(c);
		if (code < 48 || code > 57) {
			return false;
		}
	}
	return true;
}

int64_t _stable_hash_u31(State &state, Atom value) {
	int64_t hash_value = 2166136261;
	for (const uint32_t code : code_points(state.text(value))) {
		hash_value = hash_value ^ static_cast<int64_t>(code);
		hash_value = gd::mul(hash_value, 16777619) & 0xffffffff;
	}
	return compat::engine_max<int64_t>(1, hash_value & 0x7fffffff);
}

DictRef random_map_size_class_default(State &state, Atom size_class_id) {
	const DictRef size_option = _random_map_size_option(state, size_class_id);
	const Atom normalized_id = string_of(state, size_option, key::id, key::homm3_small);
	// RANDOM_MAP_SIZE_CLASS_DEFAULTS.get(normalized_id, its homm3_small entry).
	const SizeClassDefault *defaults = &kSizeClassDefaults[0];
	for (const SizeClassDefault &entry : kSizeClassDefaults) {
		if (entry.size_class_id == normalized_id) {
			defaults = &entry;
			break;
		}
	}
	const DictRef normalized_defaults = state.new_dict();
	state.set(normalized_defaults, str(key::template_id), str(defaults->template_id));
	state.set(normalized_defaults, str(key::profile_id), str(defaults->profile_id));
	state.set(normalized_defaults, str(key::player_count), gd::int_value(defaults->player_count));
	const Atom template_id = string_of(state, normalized_defaults, key::template_id, key::translated_rmg_template_049_v1);
	const int64_t requested_count = gd::int_field(state, normalized_defaults, key::player_count, 3);
	const int64_t player_count = _random_map_normalize_player_count_for_template(state, template_id, requested_count, defaults->player_count);
	state.set(normalized_defaults, str(key::player_count), gd::int_value(player_count));
	const DictRef template_option = _random_map_template_option(state, template_id);
	const ArrayRef player_counts = _random_map_template_player_count_options(state, template_id, template_option);
	state.set(normalized_defaults, str(key::player_counts), array_value(player_counts));
	return normalized_defaults;
}

DictRef build_random_map_player_config(State &state, Atom seed, Atom template_id, Atom profile_id, int64_t player_count, Atom water_mode, bool underground_enabled, Atom size_class_id, Atom template_selection_mode, Atom player_faction_id, Atom player_hero_id, Atom monster_strength, ArrayRef seat_faction_ids) {
	const DictRef seed_record = random_map_h3maped_seed_record(state, seed);
	const Atom normalized_seed = string_of(state, seed_record, key::normalized_seed, seed);
	const DictRef size_option = _random_map_size_option(state, size_class_id);
	const DictRef size_defaults = random_map_size_class_default(state, string_of(state, size_option, key::id, key::homm3_small));
	const bool auto_catalog_selection = template_selection_mode == key::native_catalog_auto
			&& gd::strip_edges(state, template_id) == key::empty
			&& gd::strip_edges(state, profile_id) == key::empty;
	Atom normalized_template_id = gd::strip_edges(state, template_id);
	if (normalized_template_id == key::empty && !auto_catalog_selection) {
		normalized_template_id = string_of(state, size_defaults, key::template_id, key::translated_rmg_template_049_v1);
	}
	const DictRef template_option = _random_map_template_option(state, normalized_template_id);
	if (!auto_catalog_selection
			&& string_of(state, template_option, key::id, key::empty) != key::empty
			&& string_of(state, template_option, key::id, key::empty) != normalized_template_id) {
		normalized_template_id = string_of(state, template_option, key::id, normalized_template_id);
	}
	Atom normalized_profile_id = gd::strip_edges(state, profile_id);
	if (normalized_profile_id == key::empty && !auto_catalog_selection) {
		const Value fallback = state.get(template_option, str(key::profile_id), str(key::translated_rmg_profile_049_v1));
		normalized_profile_id = gd::stringify(state, state.get(size_defaults, str(key::profile_id), fallback));
	}
	DictRef profile_option = _random_map_profile_option(state, normalized_profile_id);
	if (!auto_catalog_selection && string_of(state, profile_option, key::template_id, normalized_template_id) != normalized_template_id) {
		const Value fallback = state.get(size_defaults, str(key::profile_id), str(key::translated_rmg_profile_049_v1));
		normalized_profile_id = gd::stringify(state, state.get(template_option, str(key::profile_id), fallback));
		profile_option = _random_map_profile_option(state, normalized_profile_id);
	}
	const int64_t source_width = gd::int_field(state, size_option, key::source_width, 36);
	const int64_t source_height = gd::int_field(state, size_option, key::source_height, 36);
	const int64_t requested_count = player_count > 0 ? player_count : gd::int_field(state, size_defaults, key::player_count, 3);
	int64_t normalized_player_count = compat::engine_clamp<int64_t>(requested_count, 2, 8);
	if (!auto_catalog_selection) {
		const Value fallback = state.get(template_option, str(key::player_count), gd::int_value(3));
		const int64_t fallback_count = gd::to_int(state, state.get(size_defaults, str(key::player_count), fallback));
		normalized_player_count = _random_map_normalize_player_count_for_template(state, normalized_template_id, player_count, fallback_count);
	}
	const Atom normalized_water_mode = water_mode == key::normal_water ? key::normal_water : (water_mode == key::islands ? key::islands : key::land);
	const int64_t level_count = underground_enabled ? 2 : 1;
	const bool materialization_available = gd::bool_field(state, size_option, key::materialization_available, false);
	Atom runtime_policy_status = string_of(state, size_option, key::runtime_policy, key::blocked_source_size_exceeds_current_144x144x2_cap);
	// RANDOM_MAP_RUNTIME_SIZE_CAP.level_count is 2.
	if (materialization_available && level_count <= 2) {
		runtime_policy_status = key::materialize_at_source_size_within_current_144x144x2_cap;
	}
	// A seat request (seat_faction_ids, or a random player faction) is settled
	// here, from the normalized seed.
	ArrayRef seat_request = gd::duplicate_array(state, seat_faction_ids);
	if (state.array_size(seat_request) == 0 && gd::strip_edges(state, player_faction_id) == key::random) {
		seat_request = state.new_array();
		state.append(seat_request, str(key::random));
	}
	const ArrayRef seat_factions = state.array_size(seat_request) != 0
			? random_map_seat_factions(state, normalized_seed, normalized_player_count, seat_request)
			: state.new_array();
	const Atom requested_faction_id = state.array_size(seat_factions) != 0 ? gd::stringify(state, state.at(seat_factions, 0)) : player_faction_id;
	const Atom normalized_player_faction_id = _valid_random_map_player_faction_id(state, requested_faction_id);
	const Atom normalized_player_hero_id = _valid_random_map_player_hero_id(state, player_hero_id, normalized_player_faction_id);
	const ArrayRef faction_seed_order = _random_map_faction_seed_order(state, normalized_player_faction_id);
	const bool explicit_seat_factions = state.array_size(seat_faction_ids) != 0;
	Atom normalized_monster_strength = random_map_monster_strength_id(state, monster_strength);
	if (normalized_monster_strength == key::empty) {
		normalized_monster_strength = auto_catalog_selection ? key::normal : key::weak;
	}

	const DictRef result = state.new_dict();
	state.set(result, str(key::generator_version), str(key::random_map_seeded_core_v1));
	state.set(result, str(key::seed), str(normalized_seed));
	state.set(result, str(key::monster_strength), str(normalized_monster_strength));
	state.set(result, str(key::monster_strength_selected), gd::bool_value(random_map_monster_strength_id(state, monster_strength) != key::empty));
	state.set(result, str(key::seed_identity), dict_value(seed_record));

	const DictRef size = state.new_dict();
	state.set(size, str(key::preset), str(key::player_facing_skirmish_setup));
	state.set(size, str(key::size_class_id), str(string_of(state, size_option, key::id, key::homm3_small)));
	state.set(size, str(key::size_class_label), str(string_of(state, size_option, key::label, key::small_36x36)));
	state.set(size, str(key::source_model), str(string_of(state, size_option, key::source_model, key::homm3_classic_size_class)));
	state.set(size, str(key::source_width), gd::int_value(source_width));
	state.set(size, str(key::source_height), gd::int_value(source_height));
	state.set(size, str(key::requested_width), gd::int_value(source_width));
	state.set(size, str(key::requested_height), gd::int_value(source_height));
	state.set(size, str(key::width), gd::int_value(source_width));
	state.set(size, str(key::height), gd::int_value(source_height));
	state.set(size, str(key::water_mode), str(normalized_water_mode));
	state.set(size, str(key::level_count), gd::int_value(level_count));
	// RANDOM_MAP_RUNTIME_SIZE_CAP.duplicate(true).
	const DictRef runtime_size_cap = state.new_dict();
	state.set(runtime_size_cap, str(key::width), gd::int_value(144));
	state.set(runtime_size_cap, str(key::height), gd::int_value(144));
	state.set(runtime_size_cap, str(key::level_count), gd::int_value(2));
	state.set(size, str(key::runtime_size_cap), dict_value(runtime_size_cap));
	const DictRef runtime_size_policy = state.new_dict();
	state.set(runtime_size_policy, str(key::status), str(runtime_policy_status));
	state.set(runtime_size_policy, str(key::materialization_available), gd::bool_value(materialization_available));
	state.set(runtime_size_policy, str(key::rationale), str(string_of(state, size_option, key::rationale, key::empty)));
	state.set(runtime_size_policy, str(key::hidden_downscale), gd::bool_value(false));
	state.set(size, str(key::runtime_size_policy), dict_value(runtime_size_policy));
	state.set(result, str(key::size), dict_value(size));

	const DictRef player_constraints = state.new_dict();
	state.set(player_constraints, str(key::human_count), gd::int_value(1));
	state.set(player_constraints, str(key::player_count), gd::int_value(normalized_player_count));
	state.set(player_constraints, str(key::computer_count), gd::int_value(compat::engine_max<int64_t>(1, gd::sub(normalized_player_count, 1))));
	state.set(player_constraints, str(key::team_mode), str(key::free_for_all));
	state.set(result, str(key::player_constraints), dict_value(player_constraints));

	const DictRef profile = state.new_dict();
	state.set(profile, str(key::id), str(auto_catalog_selection ? key::empty : string_of(state, profile_option, key::id, normalized_profile_id)));
	state.set(profile, str(key::template_id), str(normalized_template_id));
	state.set(profile, str(key::guard_strength_profile), str(auto_catalog_selection ? normalized_monster_strength : string_of(state, profile_option, key::guard_strength_profile, key::core_low)));
	Value faction_ids;
	if (explicit_seat_factions) {
		faction_ids = array_value(gd::duplicate_array(state, seat_factions));
	} else if (normalized_player_faction_id != key::empty) {
		faction_ids = array_value(faction_seed_order);
	} else if (auto_catalog_selection) {
		faction_ids = array_value(state.new_array());
	} else if (!state.lookup(profile_option, str(key::faction_ids), faction_ids)) {
		faction_ids = array_value(state.new_array());
	}
	state.set(profile, str(key::faction_ids), faction_ids);
	state.set(result, str(key::profile), dict_value(profile));

	const DictRef template_selection = state.new_dict();
	state.set(template_selection, str(key::mode), str(auto_catalog_selection ? key::native_catalog_auto : key::size_default));
	state.set(template_selection, str(key::selection_deferred_to_native), gd::bool_value(auto_catalog_selection));
	state.set(template_selection, str(key::fallback_template_id), str(string_of(state, size_defaults, key::template_id, key::empty)));
	state.set(template_selection, str(key::fallback_profile_id), str(string_of(state, size_defaults, key::profile_id, key::empty)));
	state.set(result, str(key::template_selection), dict_value(template_selection));

	// The seat list goes into the map's identity: two line-ups share the map
	// but never a package.
	if (explicit_seat_factions) {
		state.set(result, str(key::seat_faction_ids), array_value(gd::duplicate_array(state, seat_factions)));
	}
	if (normalized_player_faction_id != key::empty && normalized_player_hero_id != key::empty) {
		const bool drawn = state.array_size(seat_request) != 0
				&& gd::strip_edges(state, gd::stringify(state, state.at(seat_request, 0))) == key::random;
		const DictRef player_setup = state.new_dict();
		state.set(player_setup, str(key::faction_id), str(normalized_player_faction_id));
		state.set(player_setup, str(key::hero_id), str(normalized_player_hero_id));
		state.set(player_setup, str(key::selection_mode), str(drawn ? key::random_from_seed : key::player_selected));
		state.set(result, str(key::player_setup), dict_value(player_setup));
	}
	return result;
}

ArrayRef random_map_seat_factions(State &state, Atom normalized_seed, int64_t player_count, ArrayRef request) {
	const ArrayRef faction_ids = state.new_array();
	const ArrayRef faction_options = random_map_faction_options(state);
	for (const Value &option : gd::items(state, array_value(faction_options))) {
		state.append(faction_ids, str(gd::stringify(state, ai::vget(state, option, key::id, str(key::empty)))));
	}
	const ArrayRef result = state.new_array();
	const int64_t seat_count = compat::engine_max<int64_t>(player_count, 1);
	for (int64_t index = 0; index < seat_count; ++index) {
		Atom entry = index < state.array_size(request) ? gd::strip_edges(state, gd::stringify(state, state.at(request, index))) : key::empty;
		if (entry == key::random && state.array_size(faction_ids) != 0) {
			const Atom draw_text = gd::format(state, key::s_seat_faction_d, { str(normalized_seed), gd::int_value(index + 1) });
			const int64_t draw = hex_digits_to_int(compat::sha256_text(state.text(draw_text)).substr(0, 8));
			entry = gd::stringify(state, state.at(faction_ids, compat::int_mod(draw, state.array_size(faction_ids))));
		} else if (!gd::array_has(state, faction_ids, str(entry))) {
			entry = key::empty;
		}
		state.append(result, str(entry));
	}
	const Atom first = gd::stringify(state, state.at(result, 0));
	Atom order_faction_id = first;
	if (first == key::empty) {
		order_faction_id = state.array_size(faction_ids) != 0 ? gd::stringify(state, state.at(faction_ids, 0)) : key::empty;
	}
	const ArrayRef order = _random_map_faction_seed_order(state, order_faction_id);
	// order.filter(func(faction_id): return faction_id not in result)
	const ArrayRef unused = state.new_array();
	for (const Value &faction_id : gd::items(state, array_value(order))) {
		if (!gd::array_has(state, result, faction_id)) {
			state.append(unused, faction_id);
		}
	}
	int64_t next = 0;
	const int64_t result_size = state.array_size(result);
	for (int64_t index = 0; index < result_size; ++index) {
		if (gd::stringify(state, state.at(result, index)) != key::empty || state.array_size(order) == 0) {
			continue;
		}
		if (next < state.array_size(unused)) {
			state.set_at(result, index, state.at(unused, next));
			next += 1;
		} else {
			state.set_at(result, index, state.at(order, compat::int_mod(index, state.array_size(order))));
		}
	}
	return result;
}

Atom _valid_random_map_player_faction_id(State &state, Atom faction_id) {
	const Atom normalized = gd::strip_edges(state, faction_id);
	if (normalized != key::empty && !gd::is_empty(state, gd::content_row(state, ContentTable::Faction, normalized))) {
		return normalized;
	}
	return key::empty;
}

Atom _valid_random_map_player_hero_id(State &state, Atom hero_id, Atom faction_id) {
	if (faction_id == key::empty) {
		return key::empty;
	}
	const Atom normalized = gd::strip_edges(state, hero_id);
	const DictRef hero = gd::content_row(state, ContentTable::Hero, normalized);
	if (!gd::is_empty(state, hero)
			&& string_of(state, hero, key::faction_id, key::empty) == faction_id
			&& string_of(state, hero, key::roster_state, key::live) != key::scaffold) {
		return normalized;
	}
	return random_map_default_hero_id_for_faction(state, faction_id);
}

ArrayRef _random_map_faction_seed_order(State &state, Atom player_faction_id) {
	if (player_faction_id == key::empty) {
		return state.new_array();
	}
	const ArrayRef ordered = state.new_array();
	state.append(ordered, str(player_faction_id));
	const ArrayRef faction_options = random_map_faction_options(state);
	for (const Value &option : gd::items(state, array_value(faction_options))) {
		const Atom faction_id = gd::stringify(state, ai::vget(state, option, key::id, str(key::empty)));
		if (faction_id != key::empty && !gd::array_has(state, ordered, str(faction_id))) {
			state.append(ordered, str(faction_id));
		}
	}
	return ordered;
}

Atom generated_skirmish_display_name(State &state, const Value &session) {
	const DictRef view = gd::object_view(state, session);
	const DictRef flags = gd::as_dict(gd::index(state, view, str(key::flags)));
	Atom package_id = key::empty;
	Value map_ref;
	if (state.lookup(flags, str(key::map_package_ref), map_ref)) {
		package_id = string_of(state, gd::as_dict(map_ref), key::package_id, key::empty);
	}
	const Atom stem = state.intern(file_basename(state.text(package_id)));
	if (stem == key::empty || gd::begins_with(state, stem, key::native_h3maped)) {
		return key::generated_realm_2;
	}
	return _title_from_package_stem(state, stem);
}

Atom _title_from_package_stem(State &state, Atom package_stem) {
	const Atom stem = gd::strip_edges(state, package_stem);
	const std::vector<std::string> parts = split_skipping_empty(state.text(stem), '-');
	if (parts.size() >= 5) {
		std::string name_words;
		for (size_t index = 1; index + 1 < parts.size(); ++index) {
			if (index > 1) {
				name_words += ' ';
			}
			name_words += parts[index];
		}
		return _title_from_kebab(state, state.intern(name_words));
	}
	return _title_from_kebab(state, gd::replace(state, stem, key::dash, key::space));
}

Atom _title_from_kebab(State &state, Atom value) {
	const std::string spaced = state.text(gd::replace(state, value, key::dash, key::space));
	std::vector<Atom> words;
	for (const std::string &word_value : split_skipping_empty(spaced, ' ')) {
		const std::string word = state.text(gd::strip_edges(state, state.intern(word_value)));
		if (word.empty()) {
			continue;
		}
		const size_t first_end = byte_offset(word, 1);
		const std::string first = ascii_case(word.substr(0, first_end), true, "ScenarioSelectRules._title_from_kebab");
		const std::string rest = ascii_case(word.substr(first_end), false, "ScenarioSelectRules._title_from_kebab");
		words.push_back(state.intern(first + rest));
	}
	return words.empty() ? key::generated_map_3 : join_texts(state, words, ' ');
}

Atom random_map_size_class_label(State &state, Atom size_class_id) {
	return string_of(state, _random_map_size_option(state, size_class_id), key::label, key::small_36x36);
}

Atom random_map_monster_strength_id(State &state, Atom value) {
	// value.strip_edges().to_lower() among RANDOM_MAP_MONSTER_STRENGTH_OPTIONS'
	// ids. Past ASCII only U+0130 (to "i") and U+212A KELVIN SIGN (to "k")
	// lower into ASCII, and only "k" is a letter of an id: any other such
	// character keeps the text off every id.
	const std::string stripped = state.text(gd::strip_edges(state, value));
	std::string lowered;
	bool kelvin_sign = false;
	for (size_t at = 0; at < stripped.size(); ++at) {
		const unsigned char c = static_cast<unsigned char>(stripped[at]);
		if (c < 0x80) {
			lowered += static_cast<char>(c >= 'A' && c <= 'Z' ? c - 'A' + 'a' : c);
			continue;
		}
		if (c == 0xe2 && at + 2 < stripped.size() && static_cast<unsigned char>(stripped[at + 1]) == 0x84
				&& static_cast<unsigned char>(stripped[at + 2]) == 0xaa) {
			kelvin_sign = true;
			at += 2;
			continue;
		}
		return key::empty;
	}
	if (kelvin_sign) {
		throw state::NotPorted("ScenarioSelectRules.random_map_monster_strength_id: to_lower() of U+212A");
	}
	for (const Atom option_id : { key::weak, key::normal, key::strong }) {
		if (state.text(option_id) == lowered) {
			return option_id;
		}
	}
	return key::empty;
}

Atom random_map_monster_strength_label(State &state, Atom value) {
	Atom strength_id = random_map_monster_strength_id(state, value);
	if (strength_id == key::empty) {
		strength_id = key::normal;
	}
	if (strength_id == key::weak) {
		return key::weak_monsters;
	}
	if (strength_id == key::normal) {
		return key::normal_monsters;
	}
	if (strength_id == key::strong) {
		return key::strong_monsters;
	}
	return strength_id;
}

Atom _skirmish_difficulty_consequence(State &state, Atom difficulty_id, Atom recommended_difficulty) {
	const Atom difficulty_text = difficulty_summary(state, difficulty_id);
	Atom recommendation = key::matches_the_recommended_setup_for_this;
	if (difficulty_id != recommended_difficulty) {
		recommendation = gd::format(state, key::recommended_setup_is_s, { str(difficulty_label(state, recommended_difficulty)) });
	}
	const Atom selected_label = difficulty_label(state, difficulty_id);
	const Atom lowered_text = state.intern(ascii_case(state.text(difficulty_text), false, "ScenarioSelectRules._skirmish_difficulty_consequence"));
	return gd::format(state, key::difficulty_consequence_s_uses_s_s, { str(selected_label), str(lowered_text), str(recommendation) });
}

Atom describe_skirmish_difficulty_check(State &state, Atom difficulty_id, Atom recommended_difficulty) {
	const Atom normalized_difficulty = normalize_difficulty(state, str(difficulty_id));
	const Atom normalized_recommendation = normalize_difficulty(state, str(recommended_difficulty));
	const Atom selected_label = difficulty_label(state, normalized_difficulty);
	const Atom recommended_label = difficulty_label(state, normalized_recommendation);
	if (normalized_difficulty == normalized_recommendation) {
		return gd::format(state, key::difficulty_check_s_matches_the_recommended, { str(selected_label) });
	}
	return gd::format(state, key::difficulty_check_s_differs_from_recommended, { str(selected_label), str(recommended_label) });
}

Atom _first_substantive_line(State &state, Atom text) {
	// text.split("\n"): the empty pieces strip to "" and are passed over.
	for (const std::string &raw_line : split_skipping_empty(state.text(text), '\n')) {
		const Atom line = gd::strip_edges(state, state.intern(raw_line));
		if (line != key::empty) {
			return line;
		}
	}
	return key::empty;
}

Atom _compact_sentence(State &state, Atom text, int64_t max_chars) {
	const Atom value = gd::strip_edges(state, text);
	const std::string value_text = state.text(value);
	if (max_chars <= 0 || code_point_count(value_text) <= max_chars) {
		return value;
	}
	Atom clipped = gd::strip_edges(state, state.intern(value_text.substr(0, byte_offset(value_text, max_chars))));
	// clipped.rfind(" "), in code points.
	const std::string clipped_text = state.text(clipped);
	const size_t space_at = clipped_text.rfind(' ');
	const int64_t last_space = space_at == std::string::npos ? -1 : code_point_count(clipped_text.substr(0, space_at));
	if (last_space > 40) {
		clipped = gd::strip_edges(state, state.intern(clipped_text.substr(0, byte_offset(clipped_text, last_space))));
	}
	return gd::format(state, key::s_5, { str(clipped) });
}

} // namespace scenario_select_rules

} // namespace aurelion::rules::port
