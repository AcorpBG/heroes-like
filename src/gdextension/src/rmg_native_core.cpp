#include "rmg_native_core.hpp"
#include "h3maped_small_rmg_embedded_data.hpp"

#include <algorithm>
#include <array>
#include <cctype>
#include <cerrno>
#include <cmath>
#include <cstring>
#include <cstdlib>
#include <limits>
#include <map>
#include <sstream>

namespace aurelion::rmg_native_core {
namespace {

struct JsonSpan {
	size_t begin = 0;
	size_t end = 0;
	bool ok = false;
};

struct H3MapedRng {
	uint32_t state = 0;

	int32_t next() {
		state = state * 0x343fdu + 0x269ec3u;
		return int32_t((state >> 16U) & 0x7fffu);
	}
};

struct TemplateRecord {
	int32_t catalog_index = -1;
	std::string id;
	std::string name;
	int32_t min_size_score = 0;
	int32_t max_size_score = 0;
	int32_t min_humans = 0;
	int32_t max_humans = 0;
	int32_t min_total_players = 0;
	int32_t max_total_players = 0;
	int32_t filtered_zone_count = 0;
	int32_t unfiltered_zone_count = 0;
	int32_t filtered_connection_count = 0;
	int32_t unfiltered_connection_count = 0;
	uint8_t human_capable_source_owner_mask = 0;
	uint8_t player_capable_source_owner_mask = 0;
	JsonSpan object_span;
	JsonSpan zones_span;
	JsonSpan connections_span;
};

struct RuntimeZoneSummary {
	bool ok = false;
	std::string blocked_reason;
	int32_t accepted_template_count = 0;
	int32_t template_selection_rng_value = 0;
	uint32_t rng_state_after_selection = 0;
	int32_t selected_vector_index = -1;
	TemplateRecord selected;
	std::vector<int32_t> mapped_slots;
	std::vector<int32_t> assignment_source_owners;
	std::vector<JsonSpan> selected_zone_spans;
};

struct RuntimeZoneRecordPlain {
	int32_t runtime_index = -1;
	int32_t source_zone_id = -1;
	std::string role;
	int32_t source_bucket = -1;
	int32_t source_owner_index = -1;
	int32_t actual_owner_color = -1;
	bool is_player_capable_zone = false;
	bool has_assigned_start = false;
	int32_t source_base_size = 0;
	std::vector<int32_t> allowed_town_slots;
	int32_t town_choice_rng_value = -1;
	int32_t town_choice_index = -1;
	int32_t town_choice_selected_allowed_ordinal = -1;
	int32_t x_after_bbox_rescale = 0;
	int32_t y_after_bbox_rescale = 0;
	int32_t level_after_bbox_rescale = 0;
	int32_t runtime_size_after_bbox_rescale = 0;
};

struct RuntimeLinkSeedPlain {
	int32_t link_index = -1;
	int32_t source_row = -1;
	int32_t source_zone_a = -1;
	int32_t source_zone_b = -1;
	int32_t runtime_a = -1;
	int32_t runtime_b = -1;
	int32_t guard_value = 0;
	bool wide = false;
	bool border_guard = false;
};

struct CoordCandidate {
	int32_t x = 0;
	int32_t y = 0;
	int32_t level = 0;
};

struct PlacementStepPlain {
	std::string pass_id;
	int32_t runtime_zone_index = -1;
	std::vector<int32_t> visible_runtime_zone_indices;
	std::string candidate_source;
	int32_t explicit_link_base_count = 0;
	int32_t fallback_base_count = 0;
	int32_t candidate_count_before_4a1ad8 = 0;
	int32_t candidate_count_after_4a1ad8 = 0;
	std::vector<CoordCandidate> candidate_preview_before_4a1ad8;
	std::vector<CoordCandidate> candidate_preview_after_4a1ad8;
	bool blocked = false;
	std::string blocked_reason;
	int32_t rng_value = -1;
	int32_t selected_candidate_index = -1;
	CoordCandidate selected_candidate;
};

struct RngEventPlain {
	std::string consumer;
	int32_t runtime_zone_index = -1;
	std::string pass_id;
	int32_t value = 0;
	int32_t modulus = 0;
	int32_t selected_index = -1;
	std::vector<int32_t> allowed_original_town_indices;
};

struct CoordinateReplaySummary {
	bool ok = false;
	std::string blocked_reason;
	int32_t minimum_source_base_size = 0;
	int32_t coordinate_prune_divisor_4a218c = 5;
	int32_t coordinate_prune_span_budget_4a218c = 0;
	int32_t coordinate_rng_calls = 0;
	int32_t town_choice_rng_calls = 0;
	uint32_t rng_state_after_0x4a218c = 0;
	int32_t bbox_min_y = 0;
	int32_t bbox_min_x = 0;
	int32_t bbox_max_y = 0;
	int32_t bbox_max_x = 0;
	int32_t bbox_height = 0;
	int32_t bbox_width = 0;
	int32_t bbox_span = 0;
	int32_t map_span = 0;
	int32_t offset_y = 0;
	int32_t offset_x = 0;
	std::vector<RuntimeZoneRecordPlain> runtime_records_after_0x49b3c1;
	std::vector<RuntimeLinkSeedPlain> link_seeds;
	std::vector<PlacementStepPlain> placement_steps;
	std::vector<RngEventPlain> rng_events;
	std::vector<RuntimeZoneRecordPlain> scaled_zone_coordinates;
};

std::string trim(const std::string &value) {
	size_t begin = 0;
	while (begin < value.size() && std::isspace(static_cast<unsigned char>(value[begin])) != 0) {
		++begin;
	}
	size_t end = value.size();
	while (end > begin && std::isspace(static_cast<unsigned char>(value[end - 1])) != 0) {
		--end;
	}
	return value.substr(begin, end - begin);
}

std::string lower_ascii(std::string value) {
	for (char &ch : value) {
		ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
	}
	return value;
}

std::vector<std::string> split(const std::string &value, char delimiter) {
	std::vector<std::string> parts;
	std::string current;
	std::istringstream stream(value);
	while (std::getline(stream, current, delimiter)) {
		parts.push_back(trim(current));
	}
	if (!value.empty() && value.back() == delimiter) {
		parts.emplace_back();
	}
	return parts;
}

bool parse_i32(const std::string &raw, int32_t &out_value) {
	char *end = nullptr;
	errno = 0;
	const long parsed = std::strtol(raw.c_str(), &end, 10);
	if (errno != 0 || end == raw.c_str() || *end != '\0') {
		return false;
	}
	if (parsed < std::numeric_limits<int32_t>::min() || parsed > std::numeric_limits<int32_t>::max()) {
		return false;
	}
	out_value = static_cast<int32_t>(parsed);
	return true;
}

bool parse_u32(const std::string &raw, uint32_t &out_value) {
	char *end = nullptr;
	errno = 0;
	const unsigned long parsed = std::strtoul(raw.c_str(), &end, 10);
	if (errno != 0 || end == raw.c_str() || *end != '\0') {
		return false;
	}
	if (parsed > std::numeric_limits<uint32_t>::max()) {
		return false;
	}
	out_value = static_cast<uint32_t>(parsed);
	return true;
}

std::string normalize_size_class(const std::string &raw) {
	const std::string value = lower_ascii(trim(raw));
	if (value == "s" || value == "small" || value == "homm3_small") {
		return "small";
	}
	if (value == "m" || value == "medium" || value == "homm3_medium") {
		return "medium";
	}
	return value;
}

std::string normalize_water_mode(const std::string &raw) {
	const std::string value = lower_ascii(trim(raw));
	if (value == "none" || value == "no_water" || value == "nowater" || value == "land") {
		return "land";
	}
	if (value == "normal" || value == "normal_water" || value == "mixed") {
		return "normal_water";
	}
	if (value == "water" || value == "islands") {
		return "islands";
	}
	return value;
}

std::string json_escape(const std::string &value) {
	std::string out;
	out.reserve(value.size() + 8);
	for (const unsigned char ch : value) {
		switch (ch) {
			case '\\':
				out += "\\\\";
				break;
			case '"':
				out += "\\\"";
				break;
			case '\b':
				out += "\\b";
				break;
			case '\f':
				out += "\\f";
				break;
			case '\n':
				out += "\\n";
				break;
			case '\r':
				out += "\\r";
				break;
			case '\t':
				out += "\\t";
				break;
			default:
				if (ch < 0x20) {
					static constexpr char HEX[] = "0123456789abcdef";
					out += "\\u00";
					out.push_back(HEX[(ch >> 4) & 0x0f]);
					out.push_back(HEX[ch & 0x0f]);
				} else {
					out.push_back(static_cast<char>(ch));
				}
				break;
		}
	}
	return out;
}

int32_t i8_from_u32_byte(uint32_t value, uint32_t shift) {
	return int32_t(int8_t((value >> shift) & 0xffU));
}

int32_t map_width_for_size(const std::string &size_class) {
	if (size_class == "medium") {
		return 72;
	}
	if (size_class == "small") {
		return 36;
	}
	return 0;
}

bool supported_one_level_land_scope(const ControlledCase &controlled_case) {
	return controlled_case.parse_ok
			&& (controlled_case.size_class == "small" || controlled_case.size_class == "medium")
			&& controlled_case.water_mode == "land"
			&& controlled_case.level_count == 1;
}

size_t skip_ws(const char *text, size_t pos, size_t end) {
	while (pos < end && std::isspace(static_cast<unsigned char>(text[pos])) != 0) {
		++pos;
	}
	return pos;
}

JsonSpan match_json_span(const char *text, size_t begin, size_t end) {
	if (begin >= end || (text[begin] != '{' && text[begin] != '[')) {
		return {};
	}
	const char open = text[begin];
	const char close = open == '{' ? '}' : ']';
	int32_t depth = 0;
	bool in_string = false;
	bool escape = false;
	for (size_t pos = begin; pos < end; ++pos) {
		const char ch = text[pos];
		if (in_string) {
			if (escape) {
				escape = false;
			} else if (ch == '\\') {
				escape = true;
			} else if (ch == '"') {
				in_string = false;
			}
			continue;
		}
		if (ch == '"') {
			in_string = true;
			continue;
		}
		if (ch == open) {
			++depth;
		} else if (ch == close) {
			--depth;
			if (depth == 0) {
				return JsonSpan { begin, pos + 1, true };
			}
		}
	}
	return {};
}

bool parse_json_string_at(const char *text, size_t begin, size_t end, std::string &out_value, size_t *out_after = nullptr) {
	if (begin >= end || text[begin] != '"') {
		return false;
	}
	std::string value;
	bool escape = false;
	for (size_t pos = begin + 1; pos < end; ++pos) {
		const char ch = text[pos];
		if (escape) {
			switch (ch) {
				case '"':
				case '\\':
				case '/':
					value.push_back(ch);
					break;
				case 'b':
					value.push_back('\b');
					break;
				case 'f':
					value.push_back('\f');
					break;
				case 'n':
					value.push_back('\n');
					break;
				case 'r':
					value.push_back('\r');
					break;
				case 't':
					value.push_back('\t');
					break;
				default:
					value.push_back(ch);
					break;
			}
			escape = false;
			continue;
		}
		if (ch == '\\') {
			escape = true;
			continue;
		}
		if (ch == '"') {
			out_value = value;
			if (out_after != nullptr) {
				*out_after = pos + 1;
			}
			return true;
		}
		value.push_back(ch);
	}
	return false;
}

JsonSpan object_key_value_span(const char *text, JsonSpan object, const char *key) {
	if (!object.ok || object.begin >= object.end || text[object.begin] != '{') {
		return {};
	}
	const size_t key_len = std::strlen(key);
	bool in_string = false;
	bool escape = false;
	int32_t depth = 0;
	for (size_t pos = object.begin; pos < object.end; ++pos) {
		const char ch = text[pos];
		if (in_string) {
			if (escape) {
				escape = false;
			} else if (ch == '\\') {
				escape = true;
			} else if (ch == '"') {
				in_string = false;
			}
			continue;
		}
		if (ch == '"') {
			if (depth == 1) {
				std::string parsed_key;
				size_t after_key = pos;
				if (parse_json_string_at(text, pos, object.end, parsed_key, &after_key) && parsed_key.size() == key_len && parsed_key == key) {
					size_t colon = skip_ws(text, after_key, object.end);
					if (colon >= object.end || text[colon] != ':') {
						return {};
					}
					size_t value_begin = skip_ws(text, colon + 1, object.end);
					if (value_begin >= object.end) {
						return {};
					}
					if (text[value_begin] == '{' || text[value_begin] == '[') {
						return match_json_span(text, value_begin, object.end);
					}
					if (text[value_begin] == '"') {
						std::string ignored;
						size_t after_value = value_begin;
						if (!parse_json_string_at(text, value_begin, object.end, ignored, &after_value)) {
							return {};
						}
						return JsonSpan { value_begin, after_value, true };
					}
					size_t value_end = value_begin;
					while (value_end < object.end && text[value_end] != ',' && text[value_end] != '}') {
						++value_end;
					}
					return JsonSpan { value_begin, value_end, true };
				}
			}
			in_string = true;
			continue;
		}
		if (ch == '{' || ch == '[') {
			++depth;
		} else if (ch == '}' || ch == ']') {
			--depth;
		}
	}
	return {};
}

bool parse_json_int(const char *text, JsonSpan span, int32_t &out_value) {
	if (!span.ok) {
		return false;
	}
	size_t begin = skip_ws(text, span.begin, span.end);
	size_t end = span.end;
	while (end > begin && std::isspace(static_cast<unsigned char>(text[end - 1])) != 0) {
		--end;
	}
	if (begin >= end) {
		return false;
	}
	std::string raw(text + begin, text + end);
	return parse_i32(raw, out_value);
}

int32_t json_int_or(const char *text, JsonSpan object, const char *key, int32_t fallback) {
	int32_t value = fallback;
	JsonSpan span = object_key_value_span(text, object, key);
	if (parse_json_int(text, span, value)) {
		return value;
	}
	return fallback;
}

std::string json_string_or(const char *text, JsonSpan object, const char *key, const std::string &fallback) {
	JsonSpan span = object_key_value_span(text, object, key);
	if (!span.ok) {
		return fallback;
	}
	size_t begin = skip_ws(text, span.begin, span.end);
	std::string value;
	if (parse_json_string_at(text, begin, span.end, value)) {
		return value;
	}
	return fallback;
}

bool json_bool_or(const char *text, JsonSpan object, const char *key, bool fallback) {
	JsonSpan span = object_key_value_span(text, object, key);
	if (!span.ok) {
		return fallback;
	}
	size_t begin = skip_ws(text, span.begin, span.end);
	size_t end = span.end;
	while (end > begin && std::isspace(static_cast<unsigned char>(text[end - 1])) != 0) {
		--end;
	}
	if (end > begin) {
		const std::string raw(text + begin, text + end);
		if (raw == "true") {
			return true;
		}
		if (raw == "false") {
			return false;
		}
	}
	int32_t value = 0;
	if (parse_json_int(text, span, value)) {
		return value != 0;
	}
	return fallback;
}

std::pair<int32_t, int32_t> json_i32_pair_or(const char *text, JsonSpan object, const char *key, std::pair<int32_t, int32_t> fallback) {
	JsonSpan span = object_key_value_span(text, object, key);
	if (!span.ok || span.begin >= span.end || text[skip_ws(text, span.begin, span.end)] != '[') {
		return fallback;
	}
	std::vector<int32_t> values;
	size_t pos = skip_ws(text, span.begin, span.end) + 1;
	while (pos < span.end) {
		pos = skip_ws(text, pos, span.end);
		if (pos >= span.end || text[pos] == ']') {
			break;
		}
		size_t value_end = pos;
		while (value_end < span.end && text[value_end] != ',' && text[value_end] != ']') {
			++value_end;
		}
		int32_t parsed = 0;
		if (parse_json_int(text, JsonSpan { pos, value_end, true }, parsed)) {
			values.push_back(parsed);
		}
		pos = value_end < span.end && text[value_end] == ',' ? value_end + 1 : value_end;
	}
	if (values.size() >= 2) {
		return std::make_pair(values[0], values[1]);
	}
	return fallback;
}

std::vector<JsonSpan> json_array_object_spans(const char *text, JsonSpan array_span) {
	std::vector<JsonSpan> spans;
	if (!array_span.ok) {
		return spans;
	}
	size_t pos = skip_ws(text, array_span.begin, array_span.end);
	if (pos >= array_span.end || text[pos] != '[') {
		return spans;
	}
	++pos;
	while (pos < array_span.end) {
		pos = skip_ws(text, pos, array_span.end);
		if (pos >= array_span.end || text[pos] == ']') {
			break;
		}
		if (text[pos] == '{') {
			JsonSpan object = match_json_span(text, pos, array_span.end);
			if (!object.ok) {
				break;
			}
			spans.push_back(object);
			pos = object.end;
			continue;
		}
		++pos;
	}
	return spans;
}

std::vector<std::string> json_array_string_values(const char *text, JsonSpan array_span) {
	std::vector<std::string> values;
	if (!array_span.ok) {
		return values;
	}
	size_t pos = skip_ws(text, array_span.begin, array_span.end);
	if (pos >= array_span.end || text[pos] != '[') {
		return values;
	}
	++pos;
	while (pos < array_span.end) {
		pos = skip_ws(text, pos, array_span.end);
		if (pos >= array_span.end || text[pos] == ']') {
			break;
		}
		if (text[pos] == '"') {
			std::string value;
			size_t after_value = pos;
			if (!parse_json_string_at(text, pos, array_span.end, value, &after_value)) {
				break;
			}
			values.push_back(value);
			pos = after_value;
			continue;
		}
		++pos;
	}
	return values;
}

int32_t bit_count_u8(uint8_t mask) {
	int32_t count = 0;
	for (int32_t index = 0; index < 8; ++index) {
		if ((mask & uint8_t(1U << uint32_t(index))) != 0) {
			++count;
		}
	}
	return count;
}

bool player_filter_allows_plain(const char *text, JsonSpan maybe_filter, int32_t humans, int32_t players) {
	if (!maybe_filter.ok) {
		return true;
	}
	return humans >= json_int_or(text, maybe_filter, "min_human", 0)
			&& humans <= json_int_or(text, maybe_filter, "max_human", 8)
			&& players >= json_int_or(text, maybe_filter, "min_total", 0)
			&& players <= json_int_or(text, maybe_filter, "max_total", 8);
}

int32_t size_score_for_case(const ControlledCase &controlled_case) {
	const int32_t map_width = map_width_for_size(controlled_case.size_class);
	const int32_t levels = std::max<int32_t>(1, controlled_case.level_count);
	if (map_width <= 0) {
		return 0;
	}
	return int32_t((int64_t(map_width) * int64_t(map_width) * int64_t(levels)) / 0x510);
}

std::vector<int32_t> owner_indices_from_mask(uint8_t mask) {
	std::vector<int32_t> indices;
	for (int32_t index = 0; index < 8; ++index) {
		if ((mask & uint8_t(1U << uint32_t(index))) != 0) {
			indices.push_back(index);
		}
	}
	return indices;
}

int32_t h3maped_town_original_index_from_id_plain(const std::string &town_id) {
	static constexpr const char *ALLOWED_TOWNS[] = {
		"castle",
		"rampart",
		"tower",
		"inferno",
		"necropolis",
		"dungeon",
		"stronghold",
		"fortress",
		"elemental",
	};
	for (int32_t index = 0; index < 9; ++index) {
		if (town_id == ALLOWED_TOWNS[size_t(index)]) {
			return index;
		}
	}
	return -1;
}

std::vector<int32_t> h3maped_allowed_town_slots_plain(const std::vector<std::string> &allowed_towns) {
	std::array<bool, 9> flags = {};
	for (const std::string &town_id : allowed_towns) {
		const int32_t town_index = h3maped_town_original_index_from_id_plain(town_id);
		if (town_index >= 0 && town_index < int32_t(flags.size())) {
			flags[size_t(town_index)] = true;
		}
	}
	std::vector<int32_t> slots;
	for (int32_t index = 0; index < int32_t(flags.size()); ++index) {
		if (flags[size_t(index)]) {
			slots.push_back(index);
		}
	}
	return slots;
}

JsonSpan template_catalog_root_span(const char *text, size_t size) {
	size_t pos = skip_ws(text, 0, size);
	if (pos >= size || text[pos] != '{') {
		return {};
	}
	return match_json_span(text, pos, size);
}

TemplateRecord template_record_from_span(const char *text, JsonSpan object, int32_t catalog_index, int32_t humans, int32_t players) {
	TemplateRecord record;
	record.catalog_index = catalog_index;
	record.id = std::string("h3maped_template_") + (catalog_index < 10 ? "00" : catalog_index < 100 ? "0" : "") + std::to_string(catalog_index);
	record.name = json_string_or(text, object, "name", "");
	record.min_size_score = json_int_or(text, object, "min_size", 0);
	record.max_size_score = json_int_or(text, object, "max_size", 0);
	const auto human_range = json_i32_pair_or(text, object, "supported_human_range", std::make_pair(0, 0));
	const auto total_range = json_i32_pair_or(text, object, "supported_total_player_range", std::make_pair(0, 0));
	record.min_humans = human_range.first;
	record.max_humans = human_range.second;
	record.min_total_players = total_range.first;
	record.max_total_players = total_range.second;
	record.object_span = object;
	record.zones_span = object_key_value_span(text, object, "zones");
	record.connections_span = object_key_value_span(text, object, "connections");
	const std::vector<JsonSpan> zone_spans = json_array_object_spans(text, record.zones_span);
	const std::vector<JsonSpan> connection_spans = json_array_object_spans(text, record.connections_span);
	record.unfiltered_zone_count = int32_t(zone_spans.size());
	record.unfiltered_connection_count = int32_t(connection_spans.size());
	for (JsonSpan zone : zone_spans) {
		if (!player_filter_allows_plain(text, object_key_value_span(text, zone, "player_filter"), humans, players)) {
			continue;
		}
		++record.filtered_zone_count;
		const int32_t owner = json_int_or(text, zone, "ownership", -1);
		if (owner < 0 || owner >= 8) {
			continue;
		}
		const std::string type = json_string_or(text, zone, "type", "");
		if (type == "human_start") {
			record.human_capable_source_owner_mask = uint8_t(record.human_capable_source_owner_mask | uint8_t(1U << uint32_t(owner)));
			record.player_capable_source_owner_mask = uint8_t(record.player_capable_source_owner_mask | uint8_t(1U << uint32_t(owner)));
		} else if (type == "computer_start") {
			record.player_capable_source_owner_mask = uint8_t(record.player_capable_source_owner_mask | uint8_t(1U << uint32_t(owner)));
		}
	}
	for (JsonSpan connection : connection_spans) {
		if (player_filter_allows_plain(text, object_key_value_span(text, connection, "player_filter"), humans, players)) {
			++record.filtered_connection_count;
		}
	}
	return record;
}

std::vector<TemplateRecord> accepted_templates_for_case(const ControlledCase &controlled_case) {
	std::vector<TemplateRecord> accepted;
	if (!supported_one_level_land_scope(controlled_case)) {
		return accepted;
	}
	const char *text = godot::h3maped_small_rmg::embedded_data::random_map_template_catalog_json();
	const size_t size = godot::h3maped_small_rmg::embedded_data::random_map_template_catalog_json_size();
	JsonSpan root = template_catalog_root_span(text, size);
	JsonSpan templates = object_key_value_span(text, root, "templates");
	const std::vector<JsonSpan> template_spans = json_array_object_spans(text, templates);
	const int32_t score = size_score_for_case(controlled_case);
	const int32_t humans = controlled_case.human_count;
	const int32_t players = controlled_case.players;
	for (int32_t index = 0; index < int32_t(template_spans.size()); ++index) {
		TemplateRecord record = template_record_from_span(text, template_spans[size_t(index)], index, humans, players);
		if (score < record.min_size_score || score > record.max_size_score) {
			continue;
		}
		if (humans < record.min_humans || humans > record.max_humans || players < record.min_total_players || players > record.max_total_players || players < humans) {
			continue;
		}
		if (controlled_case.size_class != "medium"
				&& (bit_count_u8(record.human_capable_source_owner_mask) < humans || bit_count_u8(record.player_capable_source_owner_mask) < players)) {
			continue;
		}
		accepted.push_back(record);
	}
	return accepted;
}

RuntimeZoneSummary build_runtime_zone_summary(const ControlledCase &controlled_case) {
	RuntimeZoneSummary summary;
	if (!controlled_case.parse_ok) {
		summary.blocked_reason = controlled_case.parse_error;
		return summary;
	}
	std::vector<TemplateRecord> accepted = accepted_templates_for_case(controlled_case);
	summary.accepted_template_count = int32_t(accepted.size());
	if (accepted.empty()) {
		summary.blocked_reason = "no_accepted_h3maped_templates_for_case";
		return summary;
	}
	H3MapedRng rng { controlled_case.seed };
	summary.template_selection_rng_value = rng.next();
	summary.rng_state_after_selection = rng.state;
	summary.selected_vector_index = summary.template_selection_rng_value % int32_t(accepted.size());
	summary.selected = accepted[size_t(summary.selected_vector_index)];
	summary.selected_zone_spans = json_array_object_spans(godot::h3maped_small_rmg::embedded_data::random_map_template_catalog_json(), summary.selected.zones_span);
	summary.mapped_slots.assign(8, -1);
	const std::vector<int32_t> human_indices = owner_indices_from_mask(summary.selected.human_capable_source_owner_mask);
	const std::vector<int32_t> player_indices = owner_indices_from_mask(summary.selected.player_capable_source_owner_mask);
	int32_t assigned_players = 0;
	for (int32_t index = 0; index < controlled_case.human_count && index < int32_t(human_indices.size()); ++index) {
		const int32_t source_owner = human_indices[size_t(index)];
		summary.mapped_slots[size_t(source_owner)] = assigned_players;
		summary.assignment_source_owners.push_back(source_owner);
		++assigned_players;
	}
	for (int32_t index = 0; assigned_players < controlled_case.players && index < int32_t(player_indices.size()); ++index) {
		const int32_t source_owner = player_indices[size_t(index)];
		if (summary.mapped_slots[size_t(source_owner)] != -1) {
			continue;
		}
		summary.mapped_slots[size_t(source_owner)] = assigned_players;
		summary.assignment_source_owners.push_back(source_owner);
		++assigned_players;
	}
	summary.ok = true;
	return summary;
}

int32_t json_nested_int_or(const char *text, JsonSpan object, const char *nested_key, const char *key, int32_t fallback) {
	JsonSpan nested = object_key_value_span(text, object, nested_key);
	if (!nested.ok) {
		return fallback;
	}
	return json_int_or(text, nested, key, fallback);
}

int32_t h3maped_distance_truncate_plain(int32_t ax, int32_t ay, int32_t bx, int32_t by) {
	const int64_t dx = int64_t(ax) - int64_t(bx);
	const int64_t dy = int64_t(ay) - int64_t(by);
	return int32_t(std::trunc(std::sqrt(double(dx * dx + dy * dy))));
}

int32_t ftol_truncate_plain(double value) {
	return int32_t(std::trunc(value));
}

std::vector<RuntimeZoneRecordPlain> runtime_zone_records_plain(const RuntimeZoneSummary &summary) {
	std::vector<RuntimeZoneRecordPlain> records;
	if (!summary.ok) {
		return records;
	}
	const char *text = godot::h3maped_small_rmg::embedded_data::random_map_template_catalog_json();
	for (size_t index = 0; index < summary.selected_zone_spans.size(); ++index) {
		JsonSpan zone = summary.selected_zone_spans[index];
		RuntimeZoneRecordPlain record;
		record.runtime_index = int32_t(index);
		record.source_zone_id = json_int_or(text, zone, "id", int32_t(index + 1));
		record.role = json_string_or(text, zone, "type", "");
		record.source_bucket = json_int_or(text, zone, "bucket", -1);
		record.source_owner_index = json_int_or(text, zone, "ownership", -2);
		record.actual_owner_color = record.source_owner_index >= 0 && record.source_owner_index < int32_t(summary.mapped_slots.size())
				? summary.mapped_slots[size_t(record.source_owner_index)]
				: -1;
		record.is_player_capable_zone = record.source_bucket == 0 || record.source_bucket == 1;
		record.has_assigned_start = record.is_player_capable_zone && record.actual_owner_color >= 0;
		record.source_base_size = json_int_or(text, zone, "base_size", 0);
		std::vector<std::string> allowed_towns = json_array_string_values(text, object_key_value_span(text, zone, "allowed_towns"));
		if (allowed_towns.empty()) {
			JsonSpan town_policy = object_key_value_span(text, zone, "town_policy");
			allowed_towns = json_array_string_values(text, object_key_value_span(text, town_policy, "allowed_faction_ids"));
		}
		record.allowed_town_slots = h3maped_allowed_town_slots_plain(allowed_towns);
		records.push_back(record);
	}
	return records;
}

std::vector<RuntimeLinkSeedPlain> link_seeds_plain(const ControlledCase &controlled_case, const RuntimeZoneSummary &summary) {
	std::vector<RuntimeLinkSeedPlain> seeds;
	if (!summary.ok) {
		return seeds;
	}
	const char *text = godot::h3maped_small_rmg::embedded_data::random_map_template_catalog_json();
	const std::vector<JsonSpan> links = json_array_object_spans(text, summary.selected.connections_span);
	std::map<int32_t, int32_t> runtime_index_by_source_zone_id;
	for (size_t index = 0; index < summary.selected_zone_spans.size(); ++index) {
		JsonSpan zone = summary.selected_zone_spans[index];
		const int32_t source_zone_id = json_int_or(text, zone, "id", int32_t(index + 1));
		if (source_zone_id > 0) {
			runtime_index_by_source_zone_id[source_zone_id] = int32_t(index);
		}
	}
	for (JsonSpan link : links) {
		if (!player_filter_allows_plain(text, object_key_value_span(text, link, "player_filter"), controlled_case.human_count, controlled_case.players)) {
			continue;
		}
		JsonSpan endpoints = object_key_value_span(text, link, "source_endpoints");
		const int32_t source_zone_a = json_int_or(text, link, "zone1", json_int_or(text, endpoints, "zone1", 0));
		const int32_t source_zone_b = json_int_or(text, link, "zone2", json_int_or(text, endpoints, "zone2", 0));
		if (source_zone_a <= 0 || source_zone_b <= 0) {
			continue;
		}
		JsonSpan guard = object_key_value_span(text, link, "guard");
		JsonSpan grammar_source = object_key_value_span(text, link, "grammar_source");
		RuntimeLinkSeedPlain seed;
		seed.link_index = int32_t(seeds.size());
		seed.source_row = json_int_or(text, link, "row", json_int_or(text, grammar_source, "source_row", -1));
		seed.source_zone_a = source_zone_a;
		seed.source_zone_b = source_zone_b;
		const auto found_a = runtime_index_by_source_zone_id.find(source_zone_a);
		const auto found_b = runtime_index_by_source_zone_id.find(source_zone_b);
		seed.runtime_a = found_a != runtime_index_by_source_zone_id.end() ? found_a->second : source_zone_a - 1;
		seed.runtime_b = found_b != runtime_index_by_source_zone_id.end() ? found_b->second : source_zone_b - 1;
		seed.guard_value = json_int_or(text, link, "value", json_int_or(text, link, "guard_value", json_int_or(text, guard, "value", 0)));
		seed.wide = json_bool_or(text, link, "wide", false);
		seed.border_guard = json_bool_or(text, link, "border_guard", false);
		seeds.push_back(seed);
	}
	return seeds;
}

bool candidate_valid_4a1701_plain(const RuntimeZoneRecordPlain &current, const CoordCandidate &candidate, const std::vector<CoordCandidate> &zone_positions, const std::vector<RuntimeZoneRecordPlain> &zones, const std::vector<int32_t> &visible_runtime_indices) {
	if ((current.source_bucket == 0 || current.source_bucket == 1)
			&& candidate.level == 1
			&& current.actual_owner_color != 3
			&& current.actual_owner_color != 4
			&& current.actual_owner_color != 5) {
		return false;
	}
	for (const int32_t other_index : visible_runtime_indices) {
		if (other_index < 0 || other_index >= int32_t(zones.size()) || other_index >= int32_t(zone_positions.size())) {
			continue;
		}
		const RuntimeZoneRecordPlain &other = zones[size_t(other_index)];
		const CoordCandidate other_position = zone_positions[size_t(other_index)];
		if (other.runtime_index == current.runtime_index || other_position.level != candidate.level) {
			continue;
		}
		const int32_t distance = h3maped_distance_truncate_plain(candidate.x, candidate.y, other_position.x, other_position.y);
		const int32_t minimum_tenths = (other.source_base_size + current.source_base_size) * 8;
		if (distance * 10 < minimum_tenths) {
			return false;
		}
	}
	return true;
}

bool zones_connectable_49b6e2_plain(const RuntimeZoneRecordPlain &first, const CoordCandidate &first_position, const RuntimeZoneRecordPlain &second, const CoordCandidate &second_position) {
	const int32_t distance = h3maped_distance_truncate_plain(first_position.x, first_position.y, second_position.x, second_position.y);
	const int32_t size_sum = first.source_base_size + second.source_base_size;
	if (first_position.level != second_position.level) {
		if (size_sum < distance) {
			return false;
		}
		return (size_sum - distance) > (std::min(first.source_base_size, second.source_base_size) / 2);
	}
	return size_sum * 11 >= distance * 10;
}

int32_t link_acceptance_count_4a1967_plain(const RuntimeZoneRecordPlain &current, const CoordCandidate &current_position, const std::vector<RuntimeZoneRecordPlain> &zones, const std::vector<CoordCandidate> &zone_positions, const std::vector<int32_t> &visible_runtime_indices, const std::vector<RuntimeLinkSeedPlain> &links) {
	int32_t accepted = 0;
	for (const RuntimeLinkSeedPlain &link : links) {
		int32_t other_index = -1;
		if (link.runtime_a == current.runtime_index) {
			other_index = link.runtime_b;
		} else if (link.runtime_b == current.runtime_index) {
			other_index = link.runtime_a;
		}
		if (other_index < 0 || other_index >= int32_t(zones.size()) || other_index >= int32_t(zone_positions.size())) {
			continue;
		}
		if (std::find(visible_runtime_indices.begin(), visible_runtime_indices.end(), other_index) == visible_runtime_indices.end()) {
			continue;
		}
		if (zones_connectable_49b6e2_plain(zones[size_t(other_index)], zone_positions[size_t(other_index)], current, current_position)) {
			accepted += 1;
		}
	}
	return accepted;
}

void append_angle_candidates_4a17f5_plain(const RuntimeZoneRecordPlain &base, const CoordCandidate &base_position, const RuntimeZoneRecordPlain &current, const std::vector<RuntimeZoneRecordPlain> &zones, const std::vector<CoordCandidate> &zone_positions, const std::vector<int32_t> &visible_runtime_indices, std::vector<CoordCandidate> &candidates) {
	static constexpr double X_TABLE[32] = {
		1.0, 0.9807852804032304, 0.9238795325112867, 0.8314696123025452,
		0.7071067811865476, 0.5555702330196023, 0.38268343236508984, 0.19509032201612833,
		0.0, -0.19509032201612833, -0.38268343236508984, -0.5555702330196023,
		-0.7071067811865476, -0.8314696123025452, -0.9238795325112867, -0.9807852804032304,
		-1.0, -0.9807852804032304, -0.9238795325112867, -0.8314696123025452,
		-0.7071067811865476, -0.5555702330196023, -0.38268343236508984, -0.19509032201612833,
		0.0, 0.19509032201612833, 0.38268343236508984, 0.5555702330196023,
		0.7071067811865476, 0.8314696123025452, 0.9238795325112867, 0.9807852804032304,
	};
	static constexpr double Y_TABLE[32] = {
		0.0, 0.19509032201612833, 0.38268343236508984, 0.5555702330196023,
		0.7071067811865476, 0.8314696123025452, 0.9238795325112867, 0.9807852804032304,
		1.0, 0.9807852804032304, 0.9238795325112867, 0.8314696123025452,
		0.7071067811865476, 0.5555702330196023, 0.38268343236508984, 0.19509032201612833,
		0.0, -0.19509032201612833, -0.38268343236508984, -0.5555702330196023,
		-0.7071067811865476, -0.8314696123025452, -0.9238795325112867, -0.9807852804032304,
		-1.0, -0.9807852804032304, -0.9238795325112867, -0.8314696123025452,
		-0.7071067811865476, -0.5555702330196023, -0.38268343236508984, -0.19509032201612833,
	};
	const int32_t combined_size = base.source_base_size + current.source_base_size;
	for (int32_t direction = 0; direction < 32; ++direction) {
		CoordCandidate candidate;
		candidate.x = ftol_truncate_plain(double(combined_size) * X_TABLE[direction] + double(base_position.x));
		candidate.y = ftol_truncate_plain(double(combined_size) * Y_TABLE[direction] + double(base_position.y));
		candidate.level = base_position.level;
		if (candidate_valid_4a1701_plain(current, candidate, zone_positions, zones, visible_runtime_indices)) {
			candidates.push_back(candidate);
		}
	}
}

void prune_candidates_4a1ad8_plain(const RuntimeZoneRecordPlain &current, const std::vector<RuntimeZoneRecordPlain> &zones, const std::vector<CoordCandidate> &zone_positions, const std::vector<int32_t> &visible_runtime_indices, const std::vector<RuntimeLinkSeedPlain> &links, int32_t coordinate_prune_span_budget, std::vector<CoordCandidate> &candidates) {
	if (candidates.empty()) {
		return;
	}
	int32_t best_link_count = 0;
	for (const CoordCandidate &candidate : candidates) {
		best_link_count = std::max(best_link_count, link_acceptance_count_4a1967_plain(current, candidate, zones, zone_positions, visible_runtime_indices, links));
	}
	candidates.erase(std::remove_if(candidates.begin(), candidates.end(), [&](const CoordCandidate &candidate) {
		return link_acceptance_count_4a1967_plain(current, candidate, zones, zone_positions, visible_runtime_indices, links) < best_link_count;
	}), candidates.end());
	if (candidates.empty()) {
		return;
	}

	int32_t min_y = 0;
	int32_t min_x = 0;
	int32_t max_y = 0;
	int32_t max_x = 0;
	for (const int32_t other_index : visible_runtime_indices) {
		if (other_index < 0 || other_index >= int32_t(zones.size()) || other_index >= int32_t(zone_positions.size()) || other_index == current.runtime_index) {
			continue;
		}
		const RuntimeZoneRecordPlain &other = zones[size_t(other_index)];
		const CoordCandidate other_position = zone_positions[size_t(other_index)];
		min_y = std::min(other_position.y - other.source_base_size, min_y);
		min_x = std::min(other_position.x - other.source_base_size, min_x);
		max_y = std::max(other_position.y + other.source_base_size + 1, max_y);
		max_x = std::max(other_position.x + other.source_base_size + 1, max_x);
	}

	auto candidate_span_metric = [&](const CoordCandidate &candidate) {
		const int32_t candidate_min_y = std::min(candidate.y - current.source_base_size, min_y);
		const int32_t candidate_min_x = std::min(candidate.x - current.source_base_size, min_x);
		const int32_t candidate_max_y = std::max(candidate.y + current.source_base_size + 1, max_y);
		const int32_t candidate_max_x = std::max(candidate.x + current.source_base_size + 1, max_x);
		const int32_t height = candidate_max_y - candidate_min_y;
		const int32_t width = candidate_max_x - candidate_min_x;
		return std::max(coordinate_prune_span_budget, std::max(height, width));
	};

	int32_t best_metric = 0x7d00;
	for (const CoordCandidate &candidate : candidates) {
		best_metric = std::min(best_metric, candidate_span_metric(candidate));
	}
	candidates.erase(std::remove_if(candidates.begin(), candidates.end(), [&](const CoordCandidate &candidate) {
		return best_metric < candidate_span_metric(candidate);
	}), candidates.end());
}

std::vector<CoordCandidate> coord_preview(const std::vector<CoordCandidate> &candidates, int32_t limit = 8) {
	const size_t count = std::min<size_t>(candidates.size(), size_t(std::max(0, limit)));
	return std::vector<CoordCandidate>(candidates.begin(), candidates.begin() + count);
}

CoordinateReplaySummary build_coordinate_replay_summary(const ControlledCase &controlled_case, const RuntimeZoneSummary &runtime_zone_summary) {
	CoordinateReplaySummary summary;
	if (!runtime_zone_summary.ok) {
		summary.blocked_reason = "blocked_until_runtime_zone_summary";
		return summary;
	}
	if (!supported_one_level_land_scope(controlled_case)) {
		summary.blocked_reason = "blocked_unsupported_non_small_medium_one_level_land_scope";
		return summary;
	}
	std::vector<RuntimeZoneRecordPlain> zones = runtime_zone_records_plain(runtime_zone_summary);
	std::vector<CoordCandidate> zone_positions(zones.size(), CoordCandidate {});
	summary.link_seeds = link_seeds_plain(controlled_case, runtime_zone_summary);
	summary.runtime_records_after_0x49b3c1 = zones;
	int32_t minimum_source_base_size = std::numeric_limits<int32_t>::max();
	for (const RuntimeZoneRecordPlain &zone : zones) {
		if (zone.source_base_size > 0) {
			minimum_source_base_size = std::min(minimum_source_base_size, zone.source_base_size);
		}
	}
	if (minimum_source_base_size == std::numeric_limits<int32_t>::max()) {
		minimum_source_base_size = 0;
	}
	summary.minimum_source_base_size = minimum_source_base_size;
	const int32_t map_width = map_width_for_size(controlled_case.size_class);
	const int32_t map_height = map_width;
	summary.coordinate_prune_divisor_4a218c = 5;
	summary.coordinate_prune_span_budget_4a218c = std::min(minimum_source_base_size * map_width, minimum_source_base_size * map_height) / summary.coordinate_prune_divisor_4a218c;
	H3MapedRng rng { runtime_zone_summary.rng_state_after_selection };

	auto append_rng_event = [&](const RngEventPlain &event) {
		summary.rng_events.push_back(event);
	};

	auto apply_runtime_initializer_rng = [&](int32_t zone_index) {
		if (zone_index < 0 || zone_index >= int32_t(zones.size())) {
			return;
		}
		RuntimeZoneRecordPlain &runtime = zones[size_t(zone_index)];
		if (runtime.allowed_town_slots.empty()) {
			return;
		}
		const int32_t rng_value = rng.next();
		const int32_t selected_allowed_ordinal = rng_value % int32_t(runtime.allowed_town_slots.size());
		const int32_t town_choice_index = runtime.allowed_town_slots[size_t(selected_allowed_ordinal)];
		runtime.town_choice_rng_value = rng_value;
		runtime.town_choice_selected_allowed_ordinal = selected_allowed_ordinal;
		runtime.town_choice_index = town_choice_index;
		summary.runtime_records_after_0x49b3c1[size_t(zone_index)] = runtime;
		++summary.town_choice_rng_calls;
		RngEventPlain event;
		event.consumer = "0x49b3c1";
		event.runtime_zone_index = zone_index;
		event.value = rng_value;
		event.modulus = int32_t(runtime.allowed_town_slots.size());
		event.selected_index = town_choice_index;
		event.allowed_original_town_indices = runtime.allowed_town_slots;
		append_rng_event(event);
	};

	bool complete = true;
	auto place_zone = [&](int32_t zone_index, const std::string &pass_id, const std::vector<int32_t> &visible_runtime_indices) {
		std::vector<CoordCandidate> candidates;
		PlacementStepPlain step;
		step.pass_id = pass_id;
		step.runtime_zone_index = zone_index;
		step.visible_runtime_zone_indices = visible_runtime_indices;
		if (zone_index < 0 || zone_index >= int32_t(zones.size())) {
			step.blocked = true;
			step.blocked_reason = "runtime_zone_index_out_of_range";
			complete = false;
			summary.placement_steps.push_back(step);
			return;
		}

		if (visible_runtime_indices.empty()) {
			candidates.push_back(CoordCandidate { 0, 0, 0 });
			step.candidate_source = "0x4a1f7b_empty_runtime_vector_origin";
		} else {
			int32_t explicit_base_count = 0;
			for (const RuntimeLinkSeedPlain &link : summary.link_seeds) {
				int32_t other_index = -1;
				if (link.runtime_a == zone_index) {
					other_index = link.runtime_b;
				} else if (link.runtime_b == zone_index) {
					other_index = link.runtime_a;
				}
				if (other_index < 0 || other_index >= int32_t(zones.size()) || std::find(visible_runtime_indices.begin(), visible_runtime_indices.end(), other_index) == visible_runtime_indices.end()) {
					continue;
				}
				++explicit_base_count;
				append_angle_candidates_4a17f5_plain(zones[size_t(other_index)], zone_positions[size_t(other_index)], zones[size_t(zone_index)], zones, zone_positions, visible_runtime_indices, candidates);
			}
			step.explicit_link_base_count = explicit_base_count;
			if (candidates.empty()) {
				for (const int32_t other_index : visible_runtime_indices) {
					if (other_index >= 0 && other_index < int32_t(zones.size())) {
						append_angle_candidates_4a17f5_plain(zones[size_t(other_index)], zone_positions[size_t(other_index)], zones[size_t(zone_index)], zones, zone_positions, visible_runtime_indices, candidates);
					}
				}
				step.candidate_source = "0x4a2069_existing_runtime_zone_fallback";
				step.fallback_base_count = int32_t(visible_runtime_indices.size());
			} else {
				step.candidate_source = "0x4a200c_explicit_source_link_endpoint";
			}
		}

		step.candidate_count_before_4a1ad8 = int32_t(candidates.size());
		step.candidate_preview_before_4a1ad8 = coord_preview(candidates);
		prune_candidates_4a1ad8_plain(zones[size_t(zone_index)], zones, zone_positions, visible_runtime_indices, summary.link_seeds, summary.coordinate_prune_span_budget_4a218c, candidates);
		step.candidate_count_after_4a1ad8 = int32_t(candidates.size());
		step.candidate_preview_after_4a1ad8 = coord_preview(candidates);
		if (candidates.empty()) {
			step.blocked = true;
			step.blocked_reason = "0x4a1f3b produced no coordinate candidates";
			complete = false;
			summary.placement_steps.push_back(step);
			return;
		}
		const int32_t rng_value = rng.next();
		++summary.coordinate_rng_calls;
		const int32_t selected_index = rng_value % int32_t(candidates.size());
		const CoordCandidate selected = candidates[size_t(selected_index)];
		zone_positions[size_t(zone_index)] = selected;
		step.rng_value = rng_value;
		step.selected_candidate_index = selected_index;
		step.selected_candidate = selected;
		RngEventPlain event;
		event.consumer = "0x4a1f3b_candidate_selection";
		event.runtime_zone_index = zone_index;
		event.pass_id = pass_id;
		event.value = rng_value;
		event.modulus = int32_t(candidates.size());
		event.selected_index = selected_index;
		append_rng_event(event);
		summary.placement_steps.push_back(step);
	};

	for (int32_t zone_index = 0; zone_index < int32_t(zones.size()); ++zone_index) {
		std::vector<int32_t> visible;
		for (int32_t visible_index = 0; visible_index < zone_index; ++visible_index) {
			visible.push_back(visible_index);
		}
		apply_runtime_initializer_rng(zone_index);
		place_zone(zone_index, "0x4a2226_initial_runtime_zone_insertion", visible);
	}
	std::vector<int32_t> all_visible;
	for (int32_t zone_index = 0; zone_index < int32_t(zones.size()); ++zone_index) {
		all_visible.push_back(zone_index);
	}
	for (int32_t pass = 0; pass < 2; ++pass) {
		for (int32_t zone_index = 0; zone_index < int32_t(zones.size()); ++zone_index) {
			place_zone(zone_index, pass == 0 ? "0x4a22b3_refinement_pass_1" : "0x4a22b3_refinement_pass_2", all_visible);
		}
	}

	int32_t min_y = 0;
	int32_t min_x = 0;
	int32_t max_y = 0;
	int32_t max_x = 0;
	for (size_t index = 0; index < zones.size(); ++index) {
		const RuntimeZoneRecordPlain &zone = zones[index];
		const CoordCandidate position = zone_positions[index];
		min_y = std::min(position.y - zone.source_base_size, min_y);
		min_x = std::min(position.x - zone.source_base_size, min_x);
		max_y = std::max(position.y + zone.source_base_size + 1, max_y);
		max_x = std::max(position.x + zone.source_base_size + 1, max_x);
	}
	summary.bbox_min_y = min_y;
	summary.bbox_min_x = min_x;
	summary.bbox_max_y = max_y;
	summary.bbox_max_x = max_x;
	summary.bbox_height = max_y - min_y;
	summary.bbox_width = max_x - min_x;
	summary.bbox_span = std::max(summary.bbox_height, summary.bbox_width);
	summary.map_span = std::min(map_width, map_height);
	summary.offset_y = (min_y - summary.bbox_span + max_y) / 2;
	summary.offset_x = (min_x - summary.bbox_span + max_x) / 2;
	for (size_t index = 0; index < zones.size(); ++index) {
		RuntimeZoneRecordPlain scaled = zones[index];
		CoordCandidate position = zone_positions[index];
		int32_t scaled_size = scaled.source_base_size;
		if (summary.bbox_span > 0) {
			position.x = ((position.x - summary.offset_x) * summary.map_span) / summary.bbox_span;
			position.y = ((position.y - summary.offset_y) * summary.map_span) / summary.bbox_span;
			scaled_size = (scaled.source_base_size * summary.map_span) / summary.bbox_span;
		}
		scaled.x_after_bbox_rescale = position.x;
		scaled.y_after_bbox_rescale = position.y;
		scaled.level_after_bbox_rescale = position.level;
		scaled.runtime_size_after_bbox_rescale = scaled_size;
		summary.scaled_zone_coordinates.push_back(scaled);
	}
	summary.rng_state_after_0x4a218c = rng.state;
	summary.ok = complete;
	if (!summary.ok) {
		summary.blocked_reason = "coordinate_candidate_replay_incomplete";
	}
	return summary;
}

void append_int_array_json(std::ostream &out, const std::vector<int32_t> &values) {
	out << "[";
	for (size_t index = 0; index < values.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		out << values[index];
	}
	out << "]";
}

void append_coord_json(std::ostream &out, const CoordCandidate &coord) {
	out << "{";
	out << "\"x\":" << coord.x << ",";
	out << "\"y\":" << coord.y << ",";
	out << "\"level\":" << coord.level;
	out << "}";
}

void append_coord_array_json(std::ostream &out, const std::vector<CoordCandidate> &coords) {
	out << "[";
	for (size_t index = 0; index < coords.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		append_coord_json(out, coords[index]);
	}
	out << "]";
}

void append_plain_runtime_records_json(std::ostream &out, const std::vector<RuntimeZoneRecordPlain> &records, bool include_scaled_coordinates) {
	out << "[";
	for (size_t index = 0; index < records.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const RuntimeZoneRecordPlain &record = records[index];
		out << "{";
		out << "\"runtime_index\":" << record.runtime_index << ",";
		out << "\"source_zone_id\":" << record.source_zone_id << ",";
		out << "\"role\":\"" << json_escape(record.role) << "\",";
		out << "\"source_bucket\":" << record.source_bucket << ",";
		out << "\"source_owner_index\":" << record.source_owner_index << ",";
		out << "\"actual_owner_color\":" << record.actual_owner_color << ",";
		out << "\"is_player_capable_zone\":" << (record.is_player_capable_zone ? "true" : "false") << ",";
		out << "\"has_assigned_start\":" << (record.has_assigned_start ? "true" : "false") << ",";
		out << "\"source_base_size\":" << record.source_base_size << ",";
		out << "\"allowed_original_town_indices_49b3c1\":";
		append_int_array_json(out, record.allowed_town_slots);
		out << ",";
		out << "\"town_choice_rng_value_49b3c1\":" << record.town_choice_rng_value << ",";
		out << "\"town_choice_index_49b3c1\":" << record.town_choice_index << ",";
		out << "\"town_choice_selected_allowed_ordinal_49b3c1\":" << record.town_choice_selected_allowed_ordinal;
		if (include_scaled_coordinates) {
			out << ",";
			out << "\"x_after_bbox_rescale\":" << record.x_after_bbox_rescale << ",";
			out << "\"y_after_bbox_rescale\":" << record.y_after_bbox_rescale << ",";
			out << "\"level\":" << record.level_after_bbox_rescale << ",";
			out << "\"runtime_size_after_bbox_rescale\":" << record.runtime_size_after_bbox_rescale;
		}
		out << "}";
	}
	out << "]";
}

void append_link_seed_records_json(std::ostream &out, const std::vector<RuntimeLinkSeedPlain> &links) {
	out << "[";
	for (size_t index = 0; index < links.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const RuntimeLinkSeedPlain &link = links[index];
		out << "{";
		out << "\"link_index\":" << link.link_index << ",";
		out << "\"source_row\":" << link.source_row << ",";
		out << "\"source_zone_a\":" << link.source_zone_a << ",";
		out << "\"source_zone_b\":" << link.source_zone_b << ",";
		out << "\"runtime_zone_a\":" << link.runtime_a << ",";
		out << "\"runtime_zone_b\":" << link.runtime_b << ",";
		out << "\"guard_value\":" << link.guard_value << ",";
		out << "\"wide\":" << (link.wide ? "true" : "false") << ",";
		out << "\"border_guard\":" << (link.border_guard ? "true" : "false");
		out << "}";
	}
	out << "]";
}

void append_link_seed_summary_json(std::ostream &out, const CoordinateReplaySummary &summary) {
	out << "{\n";
	out << "    \"schema_id\": \"rmg_native_cli_link_seed_summary_v1\",\n";
	out << "    \"phase_id\": \"link_seed_setup\",\n";
	out << "    \"h3maped_anchor\": \"0x4a1f3b\",\n";
	out << "    \"status\": \"" << (summary.link_seeds.empty() && !summary.ok ? "blocked" : "active_plain_cpp_link_seed_summary") << "\",\n";
	out << "    \"source\": \"original recovered h3maped template connections consumed by 0x4a1f3b\",\n";
	out << "    \"link_seed_count\": " << summary.link_seeds.size() << ",\n";
	out << "    \"materializes_coordinates\": false,\n";
	out << "    \"materializes_connection_guards\": false,\n";
	out << "    \"link_seeds\": ";
	append_link_seed_records_json(out, summary.link_seeds);
	out << "\n";
	out << "  }";
}

void append_rng_events_json(std::ostream &out, const std::vector<RngEventPlain> &events) {
	out << "[";
	for (size_t index = 0; index < events.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const RngEventPlain &event = events[index];
		out << "{";
		out << "\"consumer\":\"" << json_escape(event.consumer) << "\",";
		out << "\"runtime_zone_index\":" << event.runtime_zone_index << ",";
		if (!event.pass_id.empty()) {
			out << "\"pass\":\"" << json_escape(event.pass_id) << "\",";
		}
		out << "\"value\":" << event.value << ",";
		out << "\"modulus\":" << event.modulus << ",";
		out << "\"selected_index\":" << event.selected_index;
		if (!event.allowed_original_town_indices.empty()) {
			out << ",\"allowed_original_town_indices\":";
			append_int_array_json(out, event.allowed_original_town_indices);
		}
		out << "}";
	}
	out << "]";
}

void append_placement_steps_json(std::ostream &out, const std::vector<PlacementStepPlain> &steps) {
	out << "[";
	for (size_t index = 0; index < steps.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const PlacementStepPlain &step = steps[index];
		out << "{";
		out << "\"pass\":\"" << json_escape(step.pass_id) << "\",";
		out << "\"runtime_zone_index\":" << step.runtime_zone_index << ",";
		out << "\"runtime_vector_count_before_call\":" << step.visible_runtime_zone_indices.size() << ",";
		out << "\"visible_runtime_zone_indices\":";
		append_int_array_json(out, step.visible_runtime_zone_indices);
		out << ",";
		out << "\"candidate_source\":\"" << json_escape(step.candidate_source) << "\",";
		out << "\"explicit_link_base_count\":" << step.explicit_link_base_count << ",";
		out << "\"fallback_base_count\":" << step.fallback_base_count << ",";
		out << "\"candidate_count_before_4a1ad8\":" << step.candidate_count_before_4a1ad8 << ",";
		out << "\"candidate_preview_before_4a1ad8\":";
		append_coord_array_json(out, step.candidate_preview_before_4a1ad8);
		out << ",";
		out << "\"candidate_count_after_4a1ad8\":" << step.candidate_count_after_4a1ad8 << ",";
		out << "\"candidate_preview_after_4a1ad8\":";
		append_coord_array_json(out, step.candidate_preview_after_4a1ad8);
		out << ",";
		out << "\"blocked\":" << (step.blocked ? "true" : "false") << ",";
		out << "\"blocked_reason\":\"" << json_escape(step.blocked_reason) << "\",";
		out << "\"rng_value\":" << step.rng_value << ",";
		out << "\"selected_candidate_index\":" << step.selected_candidate_index << ",";
		out << "\"selected_candidate\":";
		append_coord_json(out, step.selected_candidate);
		out << "}";
	}
	out << "]";
}

void append_coordinate_replay_summary_json(std::ostream &out, const CoordinateReplaySummary &summary) {
	out << "{\n";
	out << "    \"schema_id\": \"rmg_native_cli_coordinate_replay_summary_v1\",\n";
	out << "    \"phase_id\": \"coordinate_replay\",\n";
	out << "    \"h3maped_anchor\": \"0x4a218c\",\n";
	out << "    \"link_endpoint_consumer_anchor\": \"0x4a1f3b\",\n";
	out << "    \"candidate_generator_anchor\": \"0x4a17f5\",\n";
	out << "    \"distance_validation_anchor\": \"0x4a1701\",\n";
	out << "    \"candidate_prune_anchor\": \"0x4a1ad8\",\n";
	out << "    \"bbox_rescale_anchor\": \"0x4a19ed\",\n";
	out << "    \"status\": \"" << (summary.ok ? "active_plain_cpp_coordinate_replay_summary" : "blocked_coordinate_candidate_replay") << "\",\n";
	out << "    \"blocked_reason\": \"" << json_escape(summary.blocked_reason) << "\",\n";
	out << "    \"source\": \"h3maped 0x4a218c interleaved runtime initializer, 0x4a1f3b endpoint walking, 0x4a17f5 candidates, 0x4a1701 spacing validation, 0x4a1ad8 pruning, and 0x4a19ed bbox rescale\",\n";
	out << "    \"materializes_zone_footprints\": false,\n";
	out << "    \"materializes_private_generated_cell_owner_words\": false,\n";
	out << "    \"placement_step_count\": " << summary.placement_steps.size() << ",\n";
	out << "    \"blanket_refinement_pass_count\": 2,\n";
	out << "    \"minimum_source_base_size\": " << summary.minimum_source_base_size << ",\n";
	out << "    \"coordinate_prune_span_budget_4a218c\": " << summary.coordinate_prune_span_budget_4a218c << ",\n";
	out << "    \"coordinate_prune_divisor_4a218c\": " << summary.coordinate_prune_divisor_4a218c << ",\n";
	out << "    \"coordinate_rng_calls_during_0x4a1f3b\": " << summary.coordinate_rng_calls << ",\n";
	out << "    \"town_choice_rng_calls_during_0x4a218c\": " << summary.town_choice_rng_calls << ",\n";
	out << "    \"total_interleaved_rng_calls_during_0x4a218c\": " << (summary.coordinate_rng_calls + summary.town_choice_rng_calls) << ",\n";
	out << "    \"rng_event_count\": " << summary.rng_events.size() << ",\n";
	out << "    \"rng_state_after_0x4a218c_replay_uint32\": " << summary.rng_state_after_0x4a218c << ",\n";
	out << "    \"runtime_zone_records_after_0x49b3c1\": ";
	append_plain_runtime_records_json(out, summary.runtime_records_after_0x49b3c1, false);
	out << ",\n";
	out << "    \"placement_steps\": ";
	append_placement_steps_json(out, summary.placement_steps);
	out << ",\n";
	out << "    \"rng_events\": ";
	append_rng_events_json(out, summary.rng_events);
	out << ",\n";
	out << "    \"bounding_box_rescale\": {";
	out << "\"min_y_before_rescale\":" << summary.bbox_min_y << ",";
	out << "\"min_x_before_rescale\":" << summary.bbox_min_x << ",";
	out << "\"max_y_before_rescale\":" << summary.bbox_max_y << ",";
	out << "\"max_x_before_rescale\":" << summary.bbox_max_x << ",";
	out << "\"height_before_rescale\":" << summary.bbox_height << ",";
	out << "\"width_before_rescale\":" << summary.bbox_width << ",";
	out << "\"selected_span_before_rescale\":" << summary.bbox_span << ",";
	out << "\"map_span\":" << summary.map_span << ",";
	out << "\"offset_y\":" << summary.offset_y << ",";
	out << "\"offset_x\":" << summary.offset_x;
	out << "},\n";
	out << "    \"scaled_zone_coordinates\": ";
	append_plain_runtime_records_json(out, summary.scaled_zone_coordinates, true);
	out << ",\n";
	out << "    \"blocked_next\": \"zone_footprint_source_nodes_0x4a3a03_0x4cc788_then_0x4a325d_owner_materialization\"\n";
	out << "  }";
}

void append_runtime_zone_summary_json(std::ostream &out, const RuntimeZoneSummary &summary) {
	const char *text = godot::h3maped_small_rmg::embedded_data::random_map_template_catalog_json();
	out << "{\n";
	out << "    \"schema_id\": \"rmg_native_cli_runtime_zone_template_summary_v1\",\n";
	out << "    \"phase_id\": \"runtime_zone_records\",\n";
	out << "    \"h3maped_anchor\": \"0x4a218c\",\n";
	out << "    \"initializer_anchor\": \"0x49b452\",\n";
	out << "    \"status\": \"" << (summary.ok ? "active_plain_cpp_template_runtime_zone_summary" : "blocked") << "\",\n";
	out << "    \"blocked_reason\": \"" << json_escape(summary.blocked_reason) << "\",\n";
	out << "    \"template_selection_mode\": \"h3maped_exe_rng_original_catalog\",\n";
	out << "    \"accepted_template_count\": " << summary.accepted_template_count << ",\n";
	out << "    \"template_selection_rng_value\": " << summary.template_selection_rng_value << ",\n";
	out << "    \"rng_state_after_selection_uint32\": " << summary.rng_state_after_selection << ",\n";
	out << "    \"selected_vector_index\": " << summary.selected_vector_index << ",\n";
	out << "    \"selected_template\": {\n";
	out << "      \"id\": \"" << json_escape(summary.selected.id) << "\",\n";
	out << "      \"source_catalog_index\": " << summary.selected.catalog_index << ",\n";
	out << "      \"source_name\": \"" << json_escape(summary.selected.name) << "\",\n";
	out << "      \"zone_count\": " << summary.selected.filtered_zone_count << ",\n";
	out << "      \"connection_count\": " << summary.selected.filtered_connection_count << ",\n";
	out << "      \"unfiltered_zone_count\": " << summary.selected.unfiltered_zone_count << ",\n";
	out << "      \"unfiltered_connection_count\": " << summary.selected.unfiltered_connection_count << ",\n";
	out << "      \"human_capable_source_owner_mask\": " << int32_t(summary.selected.human_capable_source_owner_mask) << ",\n";
	out << "      \"player_capable_source_owner_mask\": " << int32_t(summary.selected.player_capable_source_owner_mask) << "\n";
	out << "    },\n";
	out << "    \"mapped_ee4_slots\": ";
	append_int_array_json(out, summary.mapped_slots);
	out << ",\n";
	out << "    \"assignment_source_owner_order\": ";
	append_int_array_json(out, summary.assignment_source_owners);
	out << ",\n";
	int32_t assigned_start_zone_count = 0;
	int32_t unassigned_start_zone_count = 0;
	int32_t treasure_zone_count = 0;
	int32_t minimum_player_castles = 0;
	int32_t minimum_source_base_size = std::numeric_limits<int32_t>::max();
	out << "    \"runtime_zone_records\": [";
	for (size_t index = 0; index < summary.selected_zone_spans.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		JsonSpan zone = summary.selected_zone_spans[index];
		const int32_t source_owner = json_int_or(text, zone, "ownership", -2);
		const int32_t actual_owner = source_owner >= 0 && source_owner < int32_t(summary.mapped_slots.size()) ? summary.mapped_slots[size_t(source_owner)] : -1;
		const std::string role = json_string_or(text, zone, "type", "");
		const int32_t source_bucket = json_int_or(text, zone, "bucket", -1);
		const int32_t base_size = json_int_or(text, zone, "base_size", 0);
		const bool is_player_capable_zone = source_bucket == 0 || source_bucket == 1;
		const bool has_assigned_start = is_player_capable_zone && actual_owner >= 0;
		const int32_t min_castles = json_nested_int_or(text, zone, "player_towns", "min_castles", 0);
		if (role == "human_start") {
			if (actual_owner >= 0) {
				++assigned_start_zone_count;
			} else {
				++unassigned_start_zone_count;
			}
		} else if (role == "treasure") {
			++treasure_zone_count;
		}
		minimum_player_castles += min_castles;
		if (base_size > 0) {
			minimum_source_base_size = std::min(minimum_source_base_size, base_size);
		}
		out << "{";
		out << "\"runtime_index\":" << index << ",";
		out << "\"source_zone_id\":" << json_int_or(text, zone, "id", int32_t(index + 1)) << ",";
		out << "\"role\":\"" << json_escape(role) << "\",";
		out << "\"source_bucket\":" << source_bucket << ",";
		out << "\"source_owner_index\":" << source_owner << ",";
		out << "\"actual_owner_color\":" << actual_owner << ",";
		out << "\"is_player_capable_zone\":" << (is_player_capable_zone ? "true" : "false") << ",";
		out << "\"has_assigned_start\":" << (has_assigned_start ? "true" : "false") << ",";
		out << "\"runtime_byte_0x3c_inferred\":" << (has_assigned_start ? "true" : "false") << ",";
		out << "\"source_base_size\":" << base_size << ",";
		out << "\"player_min_castles\":" << min_castles << ",";
		out << "\"minimum_wood_mines\":" << json_nested_int_or(text, zone, "minimum_mines", "wood", 0) << ",";
		out << "\"minimum_ore_mines\":" << json_nested_int_or(text, zone, "minimum_mines", "ore", 0) << ",";
		out << "\"minimum_gold_mines\":" << json_nested_int_or(text, zone, "minimum_mines", "gold", 0) << ",";
		out << "\"mine_density_wood\":" << json_nested_int_or(text, zone, "mine_density", "wood", 0) << ",";
		out << "\"mine_density_ore\":" << json_nested_int_or(text, zone, "mine_density", "ore", 0) << ",";
		out << "\"mine_density_gold\":" << json_nested_int_or(text, zone, "mine_density", "gold", 0);
		out << "}";
	}
	out << "],\n";
	if (minimum_source_base_size == std::numeric_limits<int32_t>::max()) {
		minimum_source_base_size = 0;
	}
	out << "    \"runtime_zone_count\": " << summary.selected_zone_spans.size() << ",\n";
	out << "    \"assigned_start_zone_count\": " << assigned_start_zone_count << ",\n";
	out << "    \"unassigned_start_zone_count\": " << unassigned_start_zone_count << ",\n";
	out << "    \"treasure_zone_count\": " << treasure_zone_count << ",\n";
	out << "    \"minimum_player_castles\": " << minimum_player_castles << ",\n";
	out << "    \"minimum_source_base_size\": " << minimum_source_base_size << ",\n";
	out << "    \"materializes_runtime_zone_coordinates\": false,\n";
	out << "    \"materializes_private_generated_cell_owner_words\": false,\n";
	out << "    \"blocked_next\": \"coordinate_replay_and_zone_footprints_0x4a1f3b_then_0x4a325d_owner_materialization\"\n";
	out << "  }";
}

void append_initialized_generated_cell_checkpoint_json(std::ostream &out, const ControlledCase &controlled_case) {
	constexpr uint32_t WORD_0X20_DEFAULT = 0xffff7fbcU;
	constexpr uint32_t WORD_0X24_DEFAULT = 0x00000548U;
	constexpr uint32_t WORD_0X28_DEFAULT = (1U << 25U) | (1U << 27U);
	constexpr int32_t TERRAIN_CODE_DEFAULT = 8;
	const int32_t map_width = map_width_for_size(controlled_case.size_class);
	const int32_t map_height = map_width;
	const int32_t map_level_count = controlled_case.level_count;
	const int64_t cell_count = int64_t(map_width) * int64_t(map_height) * int64_t(map_level_count);
	const bool supported = supported_one_level_land_scope(controlled_case) && map_width > 0 && cell_count >= 0;
	out << "{\n";
	out << "    \"schema_id\": \"h3maped_private_state_checkpoint_0x4a4c8e_generated_cells_v1\",\n";
	out << "    \"checkpoint_id\": \"plain_cpp_initial_generated_cell_defaults\",\n";
	out << "    \"checkpoint_scope\": \"native_generated_cell_private_grid\",\n";
	out << "    \"h3maped_entry_anchor\": \"0x49ecf2_constructor_defaults_before_0x4a325d_owner_write\",\n";
	out << "    \"plain_cpp_stage\": \"constructor_default_words_only_before_runtime_zone_owner_materialization\",\n";
	out << "    \"h3maped_cell_base_pointer\": \"generator+0x14\",\n";
	out << "    \"h3maped_cell_stride_bytes\": 48,\n";
	out << "    \"h3maped_words_per_cell\": 12,\n";
	out << "    \"cell_count\": " << (supported ? cell_count : 0) << ",\n";
	out << "    \"width\": " << (supported ? map_width : 0) << ",\n";
	out << "    \"height\": " << (supported ? map_height : 0) << ",\n";
	out << "    \"level_count\": " << (supported ? map_level_count : 0) << ",\n";
	out << "    \"word_0x20_source\": \"cell_dword_index_8\",\n";
	out << "    \"word_0x24_source\": \"cell_dword_index_9\",\n";
	out << "    \"word_0x28_source\": \"cell_dword_index_10\",\n";
	out << "    \"word_0x2c_source\": \"cell_dword_index_11\",\n";
	out << "    \"owner_byte2_source\": \"0x4a4ccc sign-extends cell +0x20 byte 2\",\n";
	out << "    \"status\": \"" << (supported ? "available_constructor_defaults_only" : "blocked_unsupported_or_invalid_scope") << "\",\n";
	out << "    \"word_0x2c_available\": false,\n";
	out << "    \"default_word_0x20\": " << WORD_0X20_DEFAULT << ",\n";
	out << "    \"default_word_0x24\": " << WORD_0X24_DEFAULT << ",\n";
	out << "    \"default_word_0x28\": " << WORD_0X28_DEFAULT << ",\n";
	out << "    \"default_terrain_code\": " << TERRAIN_CODE_DEFAULT << ",\n";
	out << "    \"word_0x28_bit22_count\": 0,\n";
	out << "    \"word_0x28_bit25_count\": " << (supported ? cell_count : 0) << ",\n";
	out << "    \"word_0x28_bit26_count\": 0,\n";
	out << "    \"word_0x28_bit27_count\": " << (supported ? cell_count : 0) << ",\n";
	out << "    \"word_0x28_bit28_count\": 0,\n";
	out << "    \"word_0x2c_bit0_count\": 0,\n";
	out << "    \"owner_byte2_signed_histogram\": {\"-1\": " << (supported ? cell_count : 0) << "},\n";
	out << "    \"owner_byte3_signed_histogram\": {\"-1\": " << (supported ? cell_count : 0) << "},\n";
	out << "    \"word_0x24_terrain_histogram\": {\"8\": " << (supported ? cell_count : 0) << "},\n";
	out << "    \"word_0x24_art_histogram\": {\"21\": " << (supported ? cell_count : 0) << "},\n";
	out << "    \"word_0x28_top_byte_histogram\": {\"10\": " << (supported ? cell_count : 0) << "},\n";
	out << "    \"records\": [";
	if (supported) {
		for (int64_t flat = 0; flat < cell_count; ++flat) {
			if (flat != 0) {
				out << ",";
			}
			const int32_t level_tile_count = map_width * map_height;
			const int32_t level = int32_t(flat / level_tile_count);
			const int32_t remainder = int32_t(flat % level_tile_count);
			out << "{";
			out << "\"flat\":" << flat << ",";
			out << "\"x\":" << (remainder % map_width) << ",";
			out << "\"y\":" << (remainder / map_width) << ",";
			out << "\"level\":" << level << ",";
			out << "\"word_0x20\":" << WORD_0X20_DEFAULT << ",";
			out << "\"word_0x24\":" << WORD_0X24_DEFAULT << ",";
			out << "\"word_0x28\":" << WORD_0X28_DEFAULT << ",";
			out << "\"owner_byte2_signed\":" << i8_from_u32_byte(WORD_0X20_DEFAULT, 16U) << ",";
			out << "\"owner_byte3_signed\":" << i8_from_u32_byte(WORD_0X20_DEFAULT, 24U) << ",";
			out << "\"terrain_code\":" << TERRAIN_CODE_DEFAULT;
			out << "}";
		}
	}
	out << "]\n";
	out << "  }";
}

} // namespace

ControlledCase parse_controlled_case(const std::string &raw) {
	ControlledCase controlled_case;
	controlled_case.raw = raw;
	const std::vector<std::string> parts = split(raw, ':');
	if (parts.size() < 6) {
		controlled_case.parse_error = "expected id:size_class:players:seed:water_mode:level_count[:human_count[:computer_count[:setup_object_0x44]]]";
		return controlled_case;
	}
	controlled_case.id = parts[0];
	controlled_case.size_class = normalize_size_class(parts[1]);
	controlled_case.water_mode = normalize_water_mode(parts[4]);
	if (controlled_case.id.empty()) {
		controlled_case.parse_error = "missing case id";
		return controlled_case;
	}
	if (!parse_i32(parts[2], controlled_case.players) || controlled_case.players < 1) {
		controlled_case.parse_error = "invalid players";
		return controlled_case;
	}
	if (!parse_u32(parts[3], controlled_case.seed)) {
		controlled_case.parse_error = "invalid seed";
		return controlled_case;
	}
	if (!parse_i32(parts[5], controlled_case.level_count) || controlled_case.level_count < 1) {
		controlled_case.parse_error = "invalid level_count";
		return controlled_case;
	}
	controlled_case.human_count = 1;
	controlled_case.computer_count = std::max(0, controlled_case.players - 1);
	if (parts.size() >= 7 && !parts[6].empty() && !parse_i32(parts[6], controlled_case.human_count)) {
		controlled_case.parse_error = "invalid human_count";
		return controlled_case;
	}
	if (parts.size() >= 8 && !parts[7].empty() && !parse_i32(parts[7], controlled_case.computer_count)) {
		controlled_case.parse_error = "invalid computer_count";
		return controlled_case;
	}
	if (controlled_case.human_count < 0 || controlled_case.computer_count < 0) {
		controlled_case.parse_error = "invalid negative player split";
		return controlled_case;
	}
	if (parts.size() >= 9 && !parts[8].empty()) {
		controlled_case.setup_object_0x44_known = parse_i32(parts[8], controlled_case.setup_object_0x44);
		if (!controlled_case.setup_object_0x44_known) {
			controlled_case.parse_error = "invalid setup_object_0x44";
			return controlled_case;
		}
	}
	controlled_case.parse_ok = true;
	return controlled_case;
}

std::vector<std::string> split_case_filter(const std::string &case_filter) {
	std::vector<std::string> filters;
	for (const std::string &part : split(case_filter, ',')) {
		if (!part.empty()) {
			filters.push_back(lower_ascii(part));
		}
	}
	return filters;
}

bool case_matches_filter(const ControlledCase &controlled_case, const std::vector<std::string> &filters) {
	if (filters.empty()) {
		return true;
	}
	const std::string id = lower_ascii(controlled_case.id);
	const std::string raw = lower_ascii(controlled_case.raw);
	for (const std::string &filter : filters) {
		if (id == filter || raw.find(filter) != std::string::npos) {
			return true;
		}
	}
	return false;
}

std::string safe_case_filename(const std::string &case_id) {
	std::string out;
	out.reserve(case_id.size());
	for (const unsigned char ch : case_id) {
		if (std::isalnum(ch) != 0 || ch == '-' || ch == '_') {
			out.push_back(static_cast<char>(ch));
		} else {
			out.push_back('_');
		}
	}
	return out.empty() ? "case" : out;
}

std::string case_phase_snapshot_json(const ControlledCase &controlled_case, const std::string &status, const std::string &blocked_reason) {
	const bool supported = supported_one_level_land_scope(controlled_case);
	const int32_t width = map_width_for_size(controlled_case.size_class);
	const bool generator_mode_known = controlled_case.setup_object_0x44_known && controlled_case.setup_object_0x44 != 3;
	const bool generator_mode_randomized = controlled_case.setup_object_0x44_known && controlled_case.setup_object_0x44 == 3;
	const bool synthetic_branch_allowed = generator_mode_known && controlled_case.setup_object_0x44 != 0;
	const RuntimeZoneSummary runtime_zone_summary = build_runtime_zone_summary(controlled_case);
	const CoordinateReplaySummary coordinate_replay_summary = build_coordinate_replay_summary(controlled_case, runtime_zone_summary);
	std::ostringstream out;
	out << "{\n";
	out << "  \"schema_id\": \"rmg_native_batch_export_cli_phase_snapshot_v2\",\n";
	out << "  \"runner\": \"standalone_native_cli_no_godot\",\n";
	out << "  \"godot_process_started\": false,\n";
	out << "  \"status\": \"" << json_escape(status) << "\",\n";
	out << "  \"blocked_reason\": \"" << json_escape(blocked_reason) << "\",\n";
	out << "  \"case_id\": \"" << json_escape(controlled_case.id) << "\",\n";
	out << "  \"raw_controlled_case\": \"" << json_escape(controlled_case.raw) << "\",\n";
	out << "  \"parse_ok\": " << (controlled_case.parse_ok ? "true" : "false") << ",\n";
	out << "  \"parse_error\": \"" << json_escape(controlled_case.parse_error) << "\",\n";
	out << "  \"normalized_config\": {\n";
	out << "    \"size_class\": \"" << json_escape(controlled_case.size_class) << "\",\n";
	out << "    \"width\": " << width << ",\n";
	out << "    \"height\": " << width << ",\n";
	out << "    \"players\": " << controlled_case.players << ",\n";
	out << "    \"seed\": " << controlled_case.seed << ",\n";
	out << "    \"water_mode\": \"" << json_escape(controlled_case.water_mode) << "\",\n";
	out << "    \"level_count\": " << controlled_case.level_count << ",\n";
	out << "    \"human_count\": " << controlled_case.human_count << ",\n";
	out << "    \"computer_count\": " << controlled_case.computer_count << "\n";
	out << "  },\n";
	out << "  \"supported_one_level_land_scope\": " << (supported ? "true" : "false") << ",\n";
	out << "  \"generation_output_written\": false,\n";
	out << "  \"amap_written\": false,\n";
	out << "  \"phase_checkpoint\": \"native-rmg-private-generated-cell-grid-alignment-10184\",\n";
	out << "  \"plain_cpp_generated_cell_grid_stage\": \"constructor_defaults_before_runtime_zone_owner_materialization\",\n";
	out << "  \"generator_mode_0x10b8_source\": \"0x49ecf2 writes generator+0x10b8 from constructor arg8 ([EBP+0x24]); 0x4adfe1 supplies that arg from RMG setup object+0x44; 0x4adf88 initializes setup+0x44 to 3, then 0x4602c1 overwrites stack setup [EBP-0x80]+0x44 from [EDI+0xac]+0x10 before calling 0x4adfe1; 0x4a3a9d tests level_index == 1 || generator+0x10b8 != 0\",\n";
	out << "  \"rmg_setup_object_0x44_known\": " << (controlled_case.setup_object_0x44_known ? "true" : "false") << ",\n";
	if (controlled_case.setup_object_0x44_known) {
		out << "  \"rmg_setup_object_0x44\": " << controlled_case.setup_object_0x44 << ",\n";
	} else {
		out << "  \"rmg_setup_object_0x44\": \"unknown_missing_same_run_rmg_setup_object_0x44_capture\",\n";
	}
	out << "  \"generator_mode_0x10b8_known\": " << (generator_mode_known ? "true" : "false") << ",\n";
	if (generator_mode_known) {
		out << "  \"generator_mode_0x10b8\": " << controlled_case.setup_object_0x44 << ",\n";
	} else if (generator_mode_randomized) {
		out << "  \"generator_mode_0x10b8\": \"pending_0x49ecf2_rng_percent_3_replay_for_setup_value_3\",\n";
	} else {
		out << "  \"generator_mode_0x10b8\": \"unknown_missing_same_run_rmg_setup_object_0x44_capture\",\n";
	}
	out << "  \"synthetic_branch_condition_0x4a3a9d\": \"level_index == 1 || generator+0x10b8 != 0\",\n";
	if (generator_mode_known) {
		out << "  \"synthetic_branch_allowed_by_0x4a3a9d\": " << (synthetic_branch_allowed ? "true" : "false") << ",\n";
	} else {
		out << "  \"synthetic_branch_allowed_by_0x4a3a9d\": \"unknown_until_generator_0x10b8_rmg_setup_object_0x44_is_captured\",\n";
	}
	out << "  \"private_state_checkpoint_initial_generated_cells\": ";
	append_initialized_generated_cell_checkpoint_json(out, controlled_case);
	out << ",\n";
	out << "  \"plain_cpp_runtime_zone_template_summary\": ";
	append_runtime_zone_summary_json(out, runtime_zone_summary);
	out << ",\n";
	out << "  \"plain_cpp_link_seed_summary\": ";
	append_link_seed_summary_json(out, coordinate_replay_summary);
	out << ",\n";
	out << "  \"plain_cpp_coordinate_replay_summary\": ";
	append_coordinate_replay_summary_json(out, coordinate_replay_summary);
	out << ",\n";
	out << "  \"next_required_native_core_slice\": \"port_runtime_zone_owner_materialization_and_generated_cell_mutation_steps_after_constructor_defaults\",\n";
	out << "  \"next_required_alignment_slice\": \"port_zone_footprint_source_nodes_0x4a3a03_0x4cc788_then_0x4a325d_owner_materialization_and_capture_rmg_setup_object_0x44\"\n";
	out << "}\n";
	return out.str();
}

} // namespace aurelion::rmg_native_core
