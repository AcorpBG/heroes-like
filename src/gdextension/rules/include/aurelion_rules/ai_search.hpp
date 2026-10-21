#pragma once

// The computer heroes' map search, ported from AiHeroRules._search
// (2026-10-21). Integer only; no state, safe on any thread.
//
// - prepare: the search's masks, from the level's fixed masks and what stands
//   on it now (neutral armies, heroes, the zones around hostile heroes, the
//   sites the decision already knows are open).
// - search: the breadth-first walk over those masks, with boarding, sailing,
//   landing, bought boats and portals.
//
// A tile index is y * width + x. Every mask has one byte per tile, nonzero
// where it holds. A list of lists is given as offsets (one per list, plus the
// end) into one array of tiles.

#include <cstdint>
#include <vector>

namespace aurelion::rules::ai_search {

constexpr int64_t kBoughtBoat = 4; // a step that buys its boat, added to its kind

struct Lists {
	const int32_t *offsets = nullptr; // count + 1 entries
	int64_t count = 0;
	const int32_t *items = nullptr;
	int64_t items_size = 0;
};

struct Span {
	const int32_t *items = nullptr;
	int64_t size = 0;
};

struct Bytes {
	const uint8_t *items = nullptr;
	int64_t size = 0;
};

struct PrepareInput {
	int64_t width = 0;
	int64_t height = 0;
	const uint8_t *surface_blocked = nullptr; // the level's fixed blocking
	const uint8_t *surface_stops = nullptr; // the level's object entrances
	Bytes water; // the level's water (any length; past it is land)
	const uint8_t *sea = nullptr; // the level's open water, null when it has none
	// Neutral armies, by place in the level's list: body tiles, the tiles of
	// their zone a hero can stand on, and whether each still stands.
	Lists bodies;
	Lists zones;
	const uint8_t *neutral_open = nullptr; // bodies.count entries
	Span unit_blocked; // armies and heroes no one can walk through or meet
	Span unit_stops; // heroes that end a route
	Span hero_tiles; // every hero's tile, as GDScript computes the index
	Lists guard_zones; // the zone tiles of each hostile hero
	Span site_tiles; // the level's site stops
	Bytes site_open; // the decision's record per site: 0 unknown, 1 open, 2 closed; empty outside a decision
};

// The caller owns the per-tile arrays (width * height entries each).
struct PrepareOutput {
	uint8_t *blocked = nullptr;
	uint8_t *stop_mask = nullptr;
	uint8_t *guard_mask = nullptr; // inside a standing neutral army's zone
	uint8_t *hero_zone = nullptr;
	uint8_t *pass_mask = nullptr; // sites known to be open; the pending ones are the caller's
	uint8_t *sea_open = nullptr; // with water only: sea without armies on it
	std::vector<int32_t> zone_stops; // [guard, tile] per hero-zone tile that ends a route, in order
	std::vector<int32_t> pending_sites; // site places the caller checks, in order
};

void prepare(const PrepareInput &in, PrepareOutput &out);

struct Board {
	int64_t width = 0;
	int64_t height = 0;
	const uint8_t *blocked = nullptr; // never walked onto
	const uint8_t *stop_mask = nullptr; // ends a route
	const uint8_t *pass_mask = nullptr; // a route-ending tile the walk goes on from
	const uint8_t *hero_zone = nullptr; // beside a hostile hero
	bool native_corners = false; // NativeTransit.uses_native_adjacency
	// Portals by entrance tile: [tile, exit count, exits...] per portal. A
	// portal with several exits leads to the ones seen here
	// (AiHeroRules._portal_exits).
	Span portals;
	Bytes seen;
	// Water travel; water is null when the level has none.
	const uint8_t *water = nullptr;
	const uint8_t *sea_open = nullptr; // open water a boat sails over
	const uint8_t *boats = nullptr; // a free boat stands here
	Span docks; // [visit tile, dock tile] per shipyard whose boat the player can buy
	int64_t shore_cost = 0; // a step that boards or goes ashore costs this more
	int64_t dock_cost = 0; // buying and boarding a boat at a shipyard
};

// The caller owns the per-tile arrays (width * height entries each).
struct Output {
	int32_t *dist = nullptr; // -1 where not reached
	int32_t *parent = nullptr; // -1 where not reached
	int32_t *order = nullptr; // the queue: order_count used, 0 after
	uint8_t *phase = nullptr; // with water only: 0 walking, 1 sailing, 2 ashore, | kBoughtBoat
	std::vector<int32_t> reached; // route-ending tiles, in the order reached
	int64_t order_count = 0;
	bool capped = false; // the radius cut the walk short
};

// The walk from start (a tile on the board), whose phase is start_phase
// (1 sailing, else 0), up to radius steps.
void search(const Board &board, int64_t start, int64_t start_phase, int64_t radius, Output &out);

// Both throw std::invalid_argument when an index leaves the map or a list is
// malformed.

} // namespace aurelion::rules::ai_search
