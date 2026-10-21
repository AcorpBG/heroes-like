// The computer heroes' map search (ai_search) without Godot:
//
// 1. Golden vectors (ai_search_vectors.inc): native inputs captured from the
//    six parity seeds in shadow mode, where every whole _search answer equalled
//    the GDScript one, with a digest of the native answer.
// 2. A sweep over generated boards (water, boats, docks, portals, armies and
//    heroes), digested; the digest must be the same under every compiler and
//    from one run to the next.

#include "ai_search_selftest.hpp"

#include "aurelion_rules/ai_search.hpp"

#include <cstdio>
#include <stdexcept>
#include <string>
#include <vector>

namespace search = aurelion::rules::ai_search;

namespace {

#include "ai_search_vectors.inc"

// The sweep's digest on every compiler (FNV-1a 64 over every answer).
constexpr uint64_t kSweepDigest = 0xc8fccb0644678708ULL;
constexpr int64_t kSweepBoards = 3000;

struct Fnv {
	uint64_t value = 1469598103934665603ULL;
	void add(int64_t number) {
		uint64_t bits = static_cast<uint64_t>(number);
		for (int i = 0; i < 8; ++i) {
			value ^= bits & 0xffULL;
			value *= 1099511628211ULL;
			bits >>= 8;
		}
	}
	template <typename T>
	void add_all(const T *items, int64_t size) {
		add(size);
		for (int64_t i = 0; i < size; ++i) {
			add(static_cast<int64_t>(items[i]));
		}
	}
};

// --- Vector parsing -------------------------------------------------------

std::vector<std::string> split(const std::string &text, char separator) {
	std::vector<std::string> parts;
	std::string current;
	for (char c : text) {
		if (c == separator) {
			parts.push_back(current);
			current.clear();
		} else {
			current.push_back(c);
		}
	}
	parts.push_back(current);
	return parts;
}

std::string trim(const std::string &text) {
	size_t first = 0;
	size_t last = text.size();
	while (first < last && text[first] == ' ') {
		first += 1;
	}
	while (last > first && text[last - 1] == ' ') {
		last -= 1;
	}
	return text.substr(first, last - first);
}

int64_t parse_int(const std::string &text) {
	if (text.empty()) {
		throw std::invalid_argument("empty number");
	}
	size_t index = 0;
	bool negative = false;
	if (text[0] == '-') {
		negative = true;
		index = 1;
	}
	if (index >= text.size()) {
		throw std::invalid_argument("bad number '" + text + "'");
	}
	int64_t value = 0;
	for (; index < text.size(); ++index) {
		const char c = text[index];
		if (c < '0' || c > '9') {
			throw std::invalid_argument("bad number '" + text + "'");
		}
		value = value * 10 + (c - '0');
	}
	return negative ? -value : value;
}

uint64_t parse_hex64(const std::string &text) {
	uint64_t value = 0;
	for (char c : text) {
		value <<= 4;
		if (c >= '0' && c <= '9') {
			value |= static_cast<uint64_t>(c - '0');
		} else if (c >= 'a' && c <= 'f') {
			value |= static_cast<uint64_t>(10 + (c - 'a'));
		} else {
			throw std::invalid_argument("bad digest '" + text + "'");
		}
	}
	return value;
}

// "a,b,c" (or empty) as numbers.
std::vector<int32_t> parse_list(const std::string &text) {
	std::vector<int32_t> items;
	if (text.empty()) {
		return items;
	}
	for (const std::string &part : split(text, ',')) {
		items.push_back(static_cast<int32_t>(parse_int(part)));
	}
	return items;
}

// "<length>:<hex>": a 0/1 mask, tile 4j+k in bit k of hex digit j.
std::vector<uint8_t> parse_mask(const std::string &text) {
	const size_t colon = text.find(':');
	if (colon == std::string::npos) {
		throw std::invalid_argument("bad mask");
	}
	const int64_t length = parse_int(text.substr(0, colon));
	const std::string digits = text.substr(colon + 1);
	if (static_cast<int64_t>(digits.size()) != (length + 3) / 4) {
		throw std::invalid_argument("mask length " + std::to_string(length) + " with " + std::to_string(digits.size()) + " digits");
	}
	std::vector<uint8_t> mask(static_cast<size_t>(length), 0);
	for (int64_t digit = 0; digit < static_cast<int64_t>(digits.size()); ++digit) {
		const char c = digits[static_cast<size_t>(digit)];
		int64_t value = 0;
		if (c >= '0' && c <= '9') {
			value = c - '0';
		} else if (c >= 'a' && c <= 'f') {
			value = 10 + (c - 'a');
		} else {
			throw std::invalid_argument("bad mask digit");
		}
		for (int64_t bit = 0; bit < 4 && digit * 4 + bit < length; ++bit) {
			mask[static_cast<size_t>(digit * 4 + bit)] = static_cast<uint8_t>((value >> bit) & 1);
		}
	}
	return mask;
}

// "0120..." one digit per site.
std::vector<uint8_t> parse_digits(const std::string &text) {
	std::vector<uint8_t> values;
	for (char c : text) {
		if (c < '0' || c > '9') {
			throw std::invalid_argument("bad site record");
		}
		values.push_back(static_cast<uint8_t>(c - '0'));
	}
	return values;
}

search::Span span(const std::vector<int32_t> &items) {
	return search::Span{ items.data(), static_cast<int64_t>(items.size()) };
}

search::Bytes bytes(const std::vector<uint8_t> &items) {
	return search::Bytes{ items.data(), static_cast<int64_t>(items.size()) };
}

search::Lists lists(const std::vector<int32_t> &offsets, const std::vector<int32_t> &items) {
	if (offsets.empty()) {
		return search::Lists{};
	}
	return search::Lists{ offsets.data(), static_cast<int64_t>(offsets.size()) - 1, items.data(), static_cast<int64_t>(items.size()) };
}

const uint8_t *data_or_null(const std::vector<uint8_t> &items) {
	return items.empty() ? nullptr : items.data();
}

// --- Running and digesting -------------------------------------------------

struct PrepareCase {
	int64_t width = 0;
	int64_t height = 0;
	std::vector<uint8_t> surface_blocked, surface_stops, water, sea, neutral_open, site_open;
	std::vector<int32_t> body_offsets, body_tiles, zone_offsets, zone_tiles, unit_blocked, unit_stops, hero_tiles, guard_offsets, guard_tiles, site_tiles;
};

struct PrepareAnswer {
	std::vector<uint8_t> blocked, stop_mask, guard_mask, hero_zone, pass_mask, sea_open;
	std::vector<int32_t> zone_stops, pending_sites;
};

PrepareAnswer run_prepare(const PrepareCase &c) {
	const int64_t count = c.width * c.height;
	search::PrepareInput in;
	in.width = c.width;
	in.height = c.height;
	if (static_cast<int64_t>(c.surface_blocked.size()) != count || static_cast<int64_t>(c.surface_stops.size()) != count || (!c.sea.empty() && static_cast<int64_t>(c.sea.size()) != count)) {
		throw std::invalid_argument("prepare masks do not fit the map");
	}
	in.surface_blocked = c.surface_blocked.data();
	in.surface_stops = c.surface_stops.data();
	in.water = bytes(c.water);
	in.sea = data_or_null(c.sea);
	in.bodies = lists(c.body_offsets, c.body_tiles);
	in.zones = lists(c.zone_offsets, c.zone_tiles);
	if (static_cast<int64_t>(c.neutral_open.size()) != in.bodies.count) {
		throw std::invalid_argument("neutral_open does not fit the armies");
	}
	in.neutral_open = c.neutral_open.data();
	in.unit_blocked = span(c.unit_blocked);
	in.unit_stops = span(c.unit_stops);
	in.hero_tiles = span(c.hero_tiles);
	in.guard_zones = lists(c.guard_offsets, c.guard_tiles);
	in.site_tiles = span(c.site_tiles);
	in.site_open = bytes(c.site_open);
	PrepareAnswer answer;
	answer.blocked.resize(static_cast<size_t>(count));
	answer.stop_mask.resize(static_cast<size_t>(count));
	answer.guard_mask.resize(static_cast<size_t>(count));
	answer.hero_zone.resize(static_cast<size_t>(count));
	answer.pass_mask.resize(static_cast<size_t>(count));
	if (!c.sea.empty()) {
		answer.sea_open.resize(static_cast<size_t>(count));
	}
	search::PrepareOutput out;
	out.blocked = answer.blocked.data();
	out.stop_mask = answer.stop_mask.data();
	out.guard_mask = answer.guard_mask.data();
	out.hero_zone = answer.hero_zone.data();
	out.pass_mask = answer.pass_mask.data();
	out.sea_open = c.sea.empty() ? nullptr : answer.sea_open.data();
	search::prepare(in, out);
	answer.zone_stops = out.zone_stops;
	answer.pending_sites = out.pending_sites;
	return answer;
}

void digest_prepare(const PrepareAnswer &a, Fnv &digest) {
	digest.add_all(a.blocked.data(), static_cast<int64_t>(a.blocked.size()));
	digest.add_all(a.stop_mask.data(), static_cast<int64_t>(a.stop_mask.size()));
	digest.add_all(a.guard_mask.data(), static_cast<int64_t>(a.guard_mask.size()));
	digest.add_all(a.hero_zone.data(), static_cast<int64_t>(a.hero_zone.size()));
	digest.add_all(a.pass_mask.data(), static_cast<int64_t>(a.pass_mask.size()));
	digest.add_all(a.sea_open.data(), static_cast<int64_t>(a.sea_open.size()));
	digest.add_all(a.zone_stops.data(), static_cast<int64_t>(a.zone_stops.size()));
	digest.add_all(a.pending_sites.data(), static_cast<int64_t>(a.pending_sites.size()));
}

struct WalkCase {
	int64_t width = 0;
	int64_t height = 0;
	int64_t start = 0;
	int64_t start_phase = 0;
	int64_t radius = 0;
	bool native_corners = false;
	std::vector<uint8_t> blocked, stop_mask, pass_mask, hero_zone, seen, water, sea_open, boats;
	std::vector<int32_t> portals, docks;
	int64_t shore_cost = 0;
	int64_t dock_cost = 0;
};

void run_walk(const WalkCase &c, Fnv &digest) {
	const int64_t count = c.width * c.height;
	for (const std::vector<uint8_t> *mask : { &c.blocked, &c.stop_mask, &c.pass_mask, &c.hero_zone }) {
		if (static_cast<int64_t>(mask->size()) != count) {
			throw std::invalid_argument("walk masks do not fit the map");
		}
	}
	const bool has_water = !c.water.empty();
	if (has_water && (static_cast<int64_t>(c.water.size()) != count || static_cast<int64_t>(c.sea_open.size()) != count || static_cast<int64_t>(c.boats.size()) != count)) {
		throw std::invalid_argument("water masks do not fit the map");
	}
	search::Board board;
	board.width = c.width;
	board.height = c.height;
	board.blocked = c.blocked.data();
	board.stop_mask = c.stop_mask.data();
	board.pass_mask = c.pass_mask.data();
	board.hero_zone = c.hero_zone.data();
	board.native_corners = c.native_corners;
	board.portals = span(c.portals);
	board.seen = bytes(c.seen);
	if (has_water) {
		board.water = c.water.data();
		board.sea_open = c.sea_open.data();
		board.boats = c.boats.data();
		board.docks = span(c.docks);
	}
	board.shore_cost = c.shore_cost;
	board.dock_cost = c.dock_cost;
	std::vector<int32_t> dist(static_cast<size_t>(count));
	std::vector<int32_t> parent(static_cast<size_t>(count));
	std::vector<int32_t> order(static_cast<size_t>(count));
	std::vector<uint8_t> phase(has_water ? static_cast<size_t>(count) : 0);
	search::Output out;
	out.dist = dist.data();
	out.parent = parent.data();
	out.order = order.data();
	out.phase = has_water ? phase.data() : nullptr;
	search::search(board, c.start, c.start_phase, c.radius, out);
	digest.add_all(dist.data(), count);
	digest.add_all(parent.data(), count);
	digest.add_all(order.data(), count);
	digest.add(out.order_count);
	digest.add(out.capped ? 1 : 0);
	digest.add_all(phase.data(), static_cast<int64_t>(phase.size()));
	digest.add_all(out.reached.data(), static_cast<int64_t>(out.reached.size()));
}

// One vector: "M|W <fields separated by |> : <digest>".
bool check_vector(const char *line_text, std::string &message) {
	const std::string line(line_text);
	const size_t colon = line.rfind(" : ");
	if (colon == std::string::npos || line.size() < 2) {
		message = "unparsed vector";
		return false;
	}
	const uint64_t expected = parse_hex64(trim(line.substr(colon + 3)));
	std::vector<std::string> fields = split(line.substr(2, colon - 2), '|');
	for (std::string &field : fields) {
		field = trim(field);
	}
	Fnv digest;
	if (line[0] == 'M' && fields.size() == 18) {
		PrepareCase c;
		c.width = parse_int(fields[0]);
		c.height = parse_int(fields[1]);
		c.surface_blocked = parse_mask(fields[2]);
		c.surface_stops = parse_mask(fields[3]);
		c.water = parse_mask(fields[4]);
		c.sea = parse_mask(fields[5]);
		c.body_offsets = parse_list(fields[6]);
		c.body_tiles = parse_list(fields[7]);
		c.zone_offsets = parse_list(fields[8]);
		c.zone_tiles = parse_list(fields[9]);
		c.neutral_open = parse_mask(fields[10]);
		c.unit_blocked = parse_list(fields[11]);
		c.unit_stops = parse_list(fields[12]);
		c.hero_tiles = parse_list(fields[13]);
		c.guard_offsets = parse_list(fields[14]);
		c.guard_tiles = parse_list(fields[15]);
		c.site_tiles = parse_list(fields[16]);
		c.site_open = parse_digits(fields[17]);
		digest_prepare(run_prepare(c), digest);
	} else if (line[0] == 'W' && fields.size() == 18) {
		WalkCase c;
		c.width = parse_int(fields[0]);
		c.height = parse_int(fields[1]);
		c.start = parse_int(fields[2]);
		c.start_phase = parse_int(fields[3]);
		c.radius = parse_int(fields[4]);
		c.native_corners = parse_int(fields[5]) != 0;
		c.blocked = parse_mask(fields[6]);
		c.stop_mask = parse_mask(fields[7]);
		c.pass_mask = parse_mask(fields[8]);
		c.hero_zone = parse_mask(fields[9]);
		c.portals = parse_list(fields[10]);
		c.seen = parse_mask(fields[11]);
		c.water = parse_mask(fields[12]);
		c.sea_open = parse_mask(fields[13]);
		c.boats = parse_mask(fields[14]);
		c.docks = parse_list(fields[15]);
		c.shore_cost = parse_int(fields[16]);
		c.dock_cost = parse_int(fields[17]);
		run_walk(c, digest);
	} else {
		message = "unknown vector kind or field count";
		return false;
	}
	if (digest.value != expected) {
		char buffer[96];
		std::snprintf(buffer, sizeof(buffer), "native digest %016llx, expected %016llx", static_cast<unsigned long long>(digest.value), static_cast<unsigned long long>(expected));
		message = buffer;
		return false;
	}
	return true;
}

// --- Sweep -------------------------------------------------------------------

struct XorShift {
	uint64_t state;
	uint64_t next() {
		state ^= state << 13;
		state ^= state >> 7;
		state ^= state << 17;
		return state;
	}
	int64_t below(int64_t bound) {
		return static_cast<int64_t>(next() % static_cast<uint64_t>(bound));
	}
	bool chance(int64_t percent) {
		return below(100) < percent;
	}
};

// Generated boards in the game's shapes: rock, water with a sea that objects
// cut, armies with a body and a zone, heroes, hostile zones, site stops with a
// decision record, then a walk over the result with boats, docks and portals.
uint64_t sweep_digest() {
	XorShift random{ 0x2545F4914F6CDD1DULL };
	Fnv digest;
	for (int64_t board = 0; board < kSweepBoards; ++board) {
		PrepareCase p;
		p.width = 4 + random.below(37);
		p.height = 4 + random.below(37);
		const int64_t count = p.width * p.height;
		const bool has_water = random.chance(50);
		const int64_t rock = random.below(45);
		const int64_t wet = has_water ? 10 + random.below(50) : 0;
		p.surface_blocked.assign(static_cast<size_t>(count), 0);
		p.surface_stops.assign(static_cast<size_t>(count), 0);
		p.water.assign(static_cast<size_t>(count), 0);
		for (int64_t tile = 0; tile < count; ++tile) {
			if (random.chance(wet)) {
				p.water[static_cast<size_t>(tile)] = 1;
				p.surface_blocked[static_cast<size_t>(tile)] = 1;
			} else if (random.chance(rock)) {
				p.surface_blocked[static_cast<size_t>(tile)] = 1;
			}
			if (random.chance(6)) {
				p.surface_stops[static_cast<size_t>(tile)] = 1;
			}
		}
		if (has_water) {
			p.sea = p.water;
			for (int64_t tile = 0; tile < count; ++tile) {
				if (p.sea[static_cast<size_t>(tile)] != 0 && random.chance(5)) {
					p.sea[static_cast<size_t>(tile)] = 0;
				}
			}
		}
		const int64_t armies = random.below(12);
		p.body_offsets.push_back(0);
		p.zone_offsets.push_back(0);
		for (int64_t army = 0; army < armies; ++army) {
			const int64_t at = random.below(count);
			p.body_tiles.push_back(static_cast<int32_t>(at));
			if (random.chance(30)) {
				p.body_tiles.push_back(static_cast<int32_t>(random.below(count)));
			}
			const int64_t x = at % p.width;
			const int64_t y = at / p.width;
			for (int64_t dy = -1; dy <= 1; ++dy) {
				for (int64_t dx = -1; dx <= 1; ++dx) {
					if (x + dx >= 0 && y + dy >= 0 && x + dx < p.width && y + dy < p.height && random.chance(80)) {
						p.zone_tiles.push_back(static_cast<int32_t>((y + dy) * p.width + x + dx));
					}
				}
			}
			p.body_offsets.push_back(static_cast<int32_t>(p.body_tiles.size()));
			p.zone_offsets.push_back(static_cast<int32_t>(p.zone_tiles.size()));
			p.neutral_open.push_back(random.chance(75) ? 1 : 0);
		}
		for (int64_t i = random.below(4); i > 0; --i) {
			p.unit_blocked.push_back(static_cast<int32_t>(random.below(count)));
		}
		for (int64_t i = random.below(4); i > 0; --i) {
			p.unit_stops.push_back(static_cast<int32_t>(random.below(count)));
		}
		const int64_t heroes = random.below(5);
		p.guard_offsets.push_back(0);
		for (int64_t hero = 0; hero < heroes; ++hero) {
			const int64_t at = random.below(count);
			p.hero_tiles.push_back(static_cast<int32_t>(random.chance(5) ? -1 - random.below(3) : at));
			if (random.chance(60)) {
				const int64_t x = at % p.width;
				const int64_t y = at / p.width;
				for (int64_t dy = -1; dy <= 1; ++dy) {
					for (int64_t dx = -1; dx <= 1; ++dx) {
						if ((dx != 0 || dy != 0) && x + dx >= 0 && y + dy >= 0 && x + dx < p.width && y + dy < p.height) {
							p.guard_tiles.push_back(static_cast<int32_t>((y + dy) * p.width + x + dx));
						}
					}
				}
				p.guard_offsets.push_back(static_cast<int32_t>(p.guard_tiles.size()));
			}
		}
		for (int64_t tile = 0; tile < count; ++tile) {
			if (p.surface_stops[static_cast<size_t>(tile)] != 0 && random.chance(70)) {
				p.site_tiles.push_back(static_cast<int32_t>(tile));
			}
		}
		if (random.chance(60)) {
			for (size_t site = 0; site < p.site_tiles.size(); ++site) {
				p.site_open.push_back(static_cast<uint8_t>(random.below(3)));
			}
		}
		const PrepareAnswer prepared = run_prepare(p);
		digest_prepare(prepared, digest);

		WalkCase w;
		w.width = p.width;
		w.height = p.height;
		w.blocked = prepared.blocked;
		w.stop_mask = prepared.stop_mask;
		w.pass_mask = prepared.pass_mask;
		for (int32_t site : prepared.pending_sites) {
			if (random.chance(50)) {
				w.pass_mask[static_cast<size_t>(p.site_tiles[static_cast<size_t>(site)])] = 1;
			}
		}
		w.hero_zone = prepared.hero_zone;
		w.native_corners = random.chance(30);
		if (has_water) {
			w.water = p.water;
			w.sea_open = prepared.sea_open;
			w.boats.assign(static_cast<size_t>(count), 0);
			for (int64_t tile = 0; tile < count; ++tile) {
				if (p.water[static_cast<size_t>(tile)] != 0 && random.chance(4)) {
					w.sea_open[static_cast<size_t>(tile)] = 0;
					if (random.chance(70)) {
						w.boats[static_cast<size_t>(tile)] = 1;
					}
				}
			}
			for (int64_t i = random.below(3); i > 0; --i) {
				w.docks.push_back(static_cast<int32_t>(random.below(count)));
				w.docks.push_back(static_cast<int32_t>(random.below(count)));
			}
			w.shore_cost = 1 + random.below(8);
			w.dock_cost = w.shore_cost + 1 + random.below(20);
		}
		if (random.chance(40)) {
			for (int64_t i = 1 + random.below(3); i > 0; --i) {
				w.portals.push_back(static_cast<int32_t>(random.below(count)));
				const int64_t exits = 1 + random.below(3);
				w.portals.push_back(static_cast<int32_t>(exits));
				for (int64_t e = 0; e < exits; ++e) {
					w.portals.push_back(static_cast<int32_t>(random.below(count)));
				}
			}
			w.seen.assign(static_cast<size_t>(count), 0);
			for (int64_t tile = 0; tile < count; ++tile) {
				w.seen[static_cast<size_t>(tile)] = random.chance(60) ? 1 : 0;
			}
		}
		w.start = random.below(count);
		w.start_phase = has_water && p.water[static_cast<size_t>(w.start)] != 0 && random.chance(70) ? 1 : 0;
		w.radius = random.below(70);
		// A portal list that names one tile twice keeps the last entry, as the
		// GDScript Dictionary would; the sweep allows it.
		run_walk(w, digest);
	}
	return digest.value;
}

} // namespace

bool ai_search_selftest(bool print_only, std::string &message, int64_t &checked) {
	checked = 0;
	for (const char *vector : kAiSearchVectors) {
		std::string failure;
		bool ok = false;
		try {
			ok = check_vector(vector, failure);
		} catch (const std::exception &error) {
			failure = std::string("exception: ") + error.what();
		}
		if (!ok) {
			message = "ai_search vector " + std::to_string(checked + 1) + " differs: " + failure;
			return false;
		}
		checked += 1;
	}
	uint64_t first = 0;
	uint64_t second = 0;
	try {
		first = sweep_digest();
		second = sweep_digest();
	} catch (const std::exception &error) {
		message = std::string("ai_search sweep: exception: ") + error.what();
		return false;
	}
	std::printf("rules_selftest: ai_search vectors=%lld sweep_digest=%016llx\n", static_cast<long long>(checked), static_cast<unsigned long long>(first));
	if (first != second) {
		char buffer[128];
		std::snprintf(buffer, sizeof(buffer), "ai_search: two sweeps differ (%016llx, %016llx)", static_cast<unsigned long long>(first), static_cast<unsigned long long>(second));
		message = buffer;
		return false;
	}
	if (!print_only && first != kSweepDigest) {
		char buffer[128];
		std::snprintf(buffer, sizeof(buffer), "ai_search: sweep digest %016llx, expected %016llx", static_cast<unsigned long long>(first), static_cast<unsigned long long>(kSweepDigest));
		message = buffer;
		return false;
	}
	return true;
}
