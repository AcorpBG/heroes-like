#include "aurelion_rules/ai_search.hpp"

#include <cstddef>
#include <cstdint>
#include <stdexcept>
#include <string>

namespace aurelion::rules::ai_search {
namespace {

// AiHeroRules.NEIGHBOR_DX, NEIGHBOR_DY: the walk tries the neighbours in this order.
constexpr int64_t kDx[8] = { 1, -1, 0, 0, 1, 1, -1, -1 };
constexpr int64_t kDy[8] = { 0, 0, 1, -1, 1, -1, 1, -1 };

constexpr uint8_t kSailing = 1;
constexpr uint8_t kAshore = 2;

// A boarding or landing step held back until the walk reaches its distance.
struct Held {
	int64_t distance;
	int64_t tile;
	int64_t parent;
	int64_t phase;
};

// AiHeroRules._hold_step: in distance order, after the steps of equal distance.
void hold_step(std::vector<Held> &deferred, const Held &step) {
	size_t at = deferred.size();
	while (at > 0 && deferred[at - 1].distance > step.distance) {
		at -= 1;
	}
	deferred.insert(deferred.begin() + static_cast<std::ptrdiff_t>(at), step);
}

int64_t map_count(int64_t width, int64_t height) {
	// Tiles are int32 in the queue, parents and lists.
	if (width <= 0 || height <= 0 || width > (int64_t(1) << 20) || height > (int64_t(1) << 20) || width * height > INT32_MAX) {
		throw std::invalid_argument("map size " + std::to_string(width) + "x" + std::to_string(height));
	}
	return width * height;
}

int64_t tile_at(int64_t tile, int64_t count, const char *what) {
	if (tile < 0 || tile >= count) {
		throw std::invalid_argument(std::string(what) + " " + std::to_string(tile) + " is off the map of " + std::to_string(count) + " tiles");
	}
	return tile;
}

void check_lists(const Lists &lists, const char *what) {
	if (lists.count == 0) {
		return;
	}
	if (lists.offsets == nullptr || lists.offsets[0] != 0 || lists.offsets[lists.count] != lists.items_size) {
		throw std::invalid_argument(std::string(what) + ": offsets do not cover the items");
	}
	for (int64_t i = 0; i < lists.count; ++i) {
		if (lists.offsets[i + 1] < lists.offsets[i]) {
			throw std::invalid_argument(std::string(what) + ": offsets go backwards");
		}
	}
}

} // namespace

void prepare(const PrepareInput &in, PrepareOutput &out) {
	const int64_t count = map_count(in.width, in.height);
	check_lists(in.bodies, "bodies");
	check_lists(in.zones, "zones");
	check_lists(in.guard_zones, "guard zones");
	if (in.zones.count != in.bodies.count) {
		throw std::invalid_argument("bodies and zones differ in count");
	}
	if (in.site_open.size != 0 && in.site_open.size != in.site_tiles.size) {
		throw std::invalid_argument("site record and site list differ in size");
	}
	uint8_t *blocked = out.blocked;
	uint8_t *stop_mask = out.stop_mask;
	uint8_t *guard_mask = out.guard_mask;
	uint8_t *hero_zone = out.hero_zone;
	uint8_t *pass_mask = out.pass_mask;
	for (int64_t tile = 0; tile < count; ++tile) {
		blocked[tile] = in.surface_blocked[tile];
		stop_mask[tile] = in.surface_stops[tile];
		guard_mask[tile] = 0;
		hero_zone[tile] = 0;
		pass_mask[tile] = 0;
	}
	out.zone_stops.clear();
	out.pending_sites.clear();
	// Tiles an army or hero stands on, and tiles a dynamic stop ends a route
	// on (AiHeroRules._search's army_tiles and dynamic_stops keys).
	std::vector<uint8_t> army(static_cast<size_t>(count), 0);
	std::vector<uint8_t> dynamic(static_cast<size_t>(count), 0);
	for (int64_t record = 0; record < in.bodies.count; ++record) {
		if (in.neutral_open[record] == 0) {
			continue;
		}
		for (int64_t i = in.bodies.offsets[record]; i < in.bodies.offsets[record + 1]; ++i) {
			const int64_t tile = tile_at(in.bodies.items[i], count, "army body");
			blocked[tile] = 1;
			army[static_cast<size_t>(tile)] = 1;
		}
		for (int64_t i = in.zones.offsets[record]; i < in.zones.offsets[record + 1]; ++i) {
			const int64_t tile = tile_at(in.zones.items[i], count, "army zone");
			stop_mask[tile] = 1;
			guard_mask[tile] = 1;
			dynamic[static_cast<size_t>(tile)] = 1;
		}
	}
	for (int64_t i = 0; i < in.unit_blocked.size; ++i) {
		const int64_t tile = tile_at(in.unit_blocked.items[i], count, "unit");
		blocked[tile] = 1;
		army[static_cast<size_t>(tile)] = 1;
	}
	for (int64_t i = 0; i < in.unit_stops.size; ++i) {
		const int64_t tile = tile_at(in.unit_stops.items[i], count, "unit stop");
		stop_mask[tile] = 1;
		dynamic[static_cast<size_t>(tile)] = 1;
	}
	// Heroes guard the tiles around them: a hostile hero's zone ends a route,
	// except where a hero or army stands or no one can stand.
	std::vector<uint8_t> hero_at(static_cast<size_t>(count), 0);
	for (int64_t i = 0; i < in.hero_tiles.size; ++i) {
		const int64_t tile = in.hero_tiles.items[i];
		if (tile >= 0 && tile < count) {
			hero_at[static_cast<size_t>(tile)] = 1;
		}
	}
	for (int64_t guard = 0; guard < in.guard_zones.count; ++guard) {
		for (int64_t i = in.guard_zones.offsets[guard]; i < in.guard_zones.offsets[guard + 1]; ++i) {
			const int64_t tile = tile_at(in.guard_zones.items[i], count, "hero zone");
			const bool on_water = tile < in.water.size && in.water.items[tile] != 0;
			if (hero_at[static_cast<size_t>(tile)] != 0 || army[static_cast<size_t>(tile)] != 0 || (in.surface_blocked[tile] != 0 && in.surface_stops[tile] == 0 && !on_water)) {
				continue;
			}
			hero_zone[tile] = 1;
			stop_mask[tile] = 1;
			dynamic[static_cast<size_t>(tile)] = 1;
			out.zone_stops.push_back(static_cast<int32_t>(guard));
			out.zone_stops.push_back(static_cast<int32_t>(tile));
		}
	}
	if (in.sea != nullptr) {
		uint8_t *sea_open = out.sea_open;
		for (int64_t tile = 0; tile < count; ++tile) {
			sea_open[tile] = army[static_cast<size_t>(tile)] != 0 ? 0 : in.sea[tile];
		}
	}
	// Sites the hero may walk across: the decision's record answers for the
	// ones it knows, the caller checks the rest.
	for (int64_t site = 0; site < in.site_tiles.size; ++site) {
		const int64_t tile = tile_at(in.site_tiles.items[site], count, "site");
		if (dynamic[static_cast<size_t>(tile)] != 0 || army[static_cast<size_t>(tile)] != 0) {
			continue;
		}
		if (in.site_open.size != 0 && in.site_open.items[site] != 0) {
			if (in.site_open.items[site] == 1) {
				pass_mask[tile] = 1;
			}
			continue;
		}
		out.pending_sites.push_back(static_cast<int32_t>(site));
	}
}

void search(const Board &board, int64_t start, int64_t start_phase, int64_t radius, Output &out) {
	const int64_t width = board.width;
	const int64_t height = board.height;
	const int64_t count = map_count(width, height);
	tile_at(start, count, "start");
	const bool has_water = board.water != nullptr;
	if (start_phase != 0 && !(has_water && start_phase == kSailing)) {
		throw std::invalid_argument("start phase " + std::to_string(start_phase));
	}
	const uint8_t *blocked = board.blocked;
	const uint8_t *stop_mask = board.stop_mask;
	const uint8_t *pass_mask = board.pass_mask;
	const uint8_t *hero_zone = board.hero_zone;
	const uint8_t *water = board.water;
	const uint8_t *sea_open = board.sea_open;
	const uint8_t *boats = board.boats;
	int32_t *dist = out.dist;
	int32_t *parent = out.parent;
	int32_t *order = out.order;
	uint8_t *phase = out.phase;
	for (int64_t tile = 0; tile < count; ++tile) {
		dist[tile] = -1;
		parent[tile] = -1;
		order[tile] = 0;
	}
	if (has_water) {
		for (int64_t tile = 0; tile < count; ++tile) {
			phase[tile] = 0;
		}
	}
	std::vector<int32_t> &reached = out.reached;
	reached.clear();

	// Per portal tile, where its exits start in portal_exits (-1: no portal),
	// and the exits as _portal_exits gives them: the one exit of a fixed
	// portal, else the exits seen.
	std::vector<int64_t> portal_at;
	std::vector<int32_t> portal_exits;
	if (board.portals.size > 0) {
		portal_at.assign(static_cast<size_t>(count), -1);
		int64_t at = 0;
		while (at < board.portals.size) {
			if (at + 1 >= board.portals.size) {
				throw std::invalid_argument("portal list ends inside an entry");
			}
			const int64_t tile = tile_at(board.portals.items[at], count, "portal");
			const int64_t exits = board.portals.items[at + 1];
			if (exits < 0 || at + 2 + exits > board.portals.size) {
				throw std::invalid_argument("portal exit count " + std::to_string(exits));
			}
			portal_at[static_cast<size_t>(tile)] = static_cast<int64_t>(portal_exits.size());
			const int64_t count_slot = static_cast<int64_t>(portal_exits.size());
			portal_exits.push_back(0);
			for (int64_t i = 0; i < exits; ++i) {
				const int64_t exit = tile_at(board.portals.items[at + 2 + i], count, "portal exit");
				if (exits == 1 || (exit < board.seen.size && board.seen.items[exit] != 0)) {
					portal_exits.push_back(static_cast<int32_t>(exit));
					portal_exits[static_cast<size_t>(count_slot)] += 1;
				}
			}
			at += 2 + exits;
		}
	}
	// Per tile, the dock of the shipyard visited there (-1: none).
	std::vector<int32_t> dock_at;
	if (has_water && board.docks.size > 0) {
		if (board.docks.size % 2 != 0) {
			throw std::invalid_argument("dock list has an odd length");
		}
		dock_at.assign(static_cast<size_t>(count), -1);
		for (int64_t at = 0; at < board.docks.size; at += 2) {
			const int64_t visit = tile_at(board.docks.items[at], count, "shipyard");
			dock_at[static_cast<size_t>(visit)] = static_cast<int32_t>(tile_at(board.docks.items[at + 1], count, "dock"));
		}
	}
	const bool has_portals = !portal_at.empty();
	const bool has_docks = !dock_at.empty();

	int64_t tail = 0;
	const auto enqueue = [&](int64_t tile) {
		if (tail >= count) {
			throw std::logic_error("search queue overflow");
		}
		order[tail] = static_cast<int32_t>(tile);
		tail += 1;
	};

	if (has_water && start_phase == kSailing) {
		phase[start] = kSailing;
	}
	dist[start] = 0;
	enqueue(start);
	int64_t head = 0;
	const bool native_corners = board.native_corners;
	// A hero that stopped on a portal goes through it first thing.
	if (has_portals && portal_at[static_cast<size_t>(start)] >= 0) {
		const int64_t first = portal_at[static_cast<size_t>(start)];
		const int64_t exits = portal_exits[static_cast<size_t>(first)];
		for (int64_t i = 0; i < exits; ++i) {
			const int64_t exit = portal_exits[static_cast<size_t>(first + 1 + i)];
			if (dist[exit] < 0) {
				dist[exit] = 1;
				parent[exit] = static_cast<int32_t>(start);
				// An exit beside a hostile hero is as far as the hero gets.
				if (hero_zone[exit] != 0) {
					reached.push_back(static_cast<int32_t>(exit));
					continue;
				}
				enqueue(exit);
			}
		}
	}
	bool capped = false;
	std::vector<Held> deferred;
	size_t deferred_head = 0;
	while (head < tail || deferred_head < deferred.size()) {
		if (deferred_head < deferred.size()) {
			// A held-back step joins the queue once the walk has come within one
			// step of its distance, which keeps the queue in distance order.
			const int64_t limit = head < tail ? static_cast<int64_t>(dist[order[head]]) + 1 : deferred[deferred_head].distance;
			while (deferred_head < deferred.size() && deferred[deferred_head].distance <= limit) {
				const Held held = deferred[deferred_head];
				deferred_head += 1;
				const int64_t at = held.tile;
				if (dist[at] >= 0) {
					continue;
				}
				dist[at] = static_cast<int32_t>(held.distance);
				parent[at] = static_cast<int32_t>(held.parent);
				phase[at] = static_cast<uint8_t>(held.phase);
				if (stop_mask[at] != 0) {
					reached.push_back(static_cast<int32_t>(at));
					if (pass_mask[at] == 0) {
						continue;
					}
				}
				enqueue(at);
			}
			if (head >= tail) {
				continue;
			}
		}
		const int64_t current = order[head];
		head += 1;
		const int64_t here = dist[current];
		const int64_t next_distance = here + 1;
		if (next_distance > radius) {
			capped = true;
			continue;
		}
		const int64_t cx = current % width;
		const int64_t cy = current / width;
		// Only a tile on the map's edge has neighbours off the map.
		const bool on_edge = cx == 0 || cy == 0 || cx == width - 1 || cy == height - 1;
		const int64_t here_phase = has_water ? phase[current] : 0;
		const int64_t mode = here_phase & 3;
		if (here_phase == 0 && has_docks && dock_at[static_cast<size_t>(current)] >= 0 && dist[dock_at[static_cast<size_t>(current)]] < 0) {
			// The shipyard here builds a boat at its dock and the hero boards it.
			if (here + 1 + board.dock_cost <= radius) {
				hold_step(deferred, Held{ here + 1 + board.dock_cost, dock_at[static_cast<size_t>(current)], current, kSailing | kBoughtBoat });
			} else {
				capped = true;
			}
		}
		for (int64_t direction = 0; direction < 8; ++direction) {
			const int64_t dx = kDx[direction];
			const int64_t dy = kDy[direction];
			if (on_edge && (cx + dx < 0 || cy + dy < 0 || cx + dx >= width || cy + dy >= height)) {
				continue;
			}
			const int64_t next = current + dy * width + dx;
			if (dist[next] >= 0) {
				continue;
			}
			if (has_water) {
				if (water[next] != 0) {
					if (mode == kSailing) {
						if (dx != 0 && dy != 0 && !native_corners && sea_open[current + dx] == 0 && sea_open[current + dy * width] == 0) {
							continue;
						}
						if (stop_mask[next] != 0) {
							dist[next] = static_cast<int32_t>(next_distance);
							parent[next] = static_cast<int32_t>(current);
							phase[next] = static_cast<uint8_t>(here_phase);
							reached.push_back(static_cast<int32_t>(next));
							if (pass_mask[next] != 0) {
								enqueue(next);
							}
						} else if (sea_open[next] != 0) {
							dist[next] = static_cast<int32_t>(next_distance);
							parent[next] = static_cast<int32_t>(current);
							phase[next] = static_cast<uint8_t>(here_phase);
							enqueue(next);
						}
					} else if (here_phase == 0 && boats[next] != 0) {
						if (next_distance + board.shore_cost <= radius) {
							hold_step(deferred, Held{ next_distance + board.shore_cost, next, current, kSailing });
						} else {
							capped = true;
						}
					}
					continue;
				}
				if (mode == kSailing) {
					if (stop_mask[next] != 0 || blocked[next] == 0) {
						if (next_distance + board.shore_cost <= radius) {
							hold_step(deferred, Held{ next_distance + board.shore_cost, next, current, kAshore | (here_phase & kBoughtBoat) });
						} else {
							capped = true;
						}
					}
					continue;
				}
			}
			if (dx != 0 && dy != 0 && !native_corners && blocked[current + dx] != 0 && blocked[current + dy * width] != 0) {
				continue;
			}
			if (stop_mask[next] != 0) {
				dist[next] = static_cast<int32_t>(next_distance);
				parent[next] = static_cast<int32_t>(current);
				if (has_water) {
					phase[next] = static_cast<uint8_t>(here_phase);
				}
				reached.push_back(static_cast<int32_t>(next));
				if (pass_mask[next] != 0) {
					enqueue(next);
				} else if (has_portals && portal_at[static_cast<size_t>(next)] >= 0 && hero_zone[next] == 0) {
					// Through the portal: the hero comes out standing on an exit
					// and the route goes on from there.
					const int64_t first = portal_at[static_cast<size_t>(next)];
					const int64_t exits = portal_exits[static_cast<size_t>(first)];
					for (int64_t i = 0; i < exits; ++i) {
						const int64_t exit = portal_exits[static_cast<size_t>(first + 1 + i)];
						if (dist[exit] < 0) {
							dist[exit] = static_cast<int32_t>(next_distance + 1);
							parent[exit] = static_cast<int32_t>(next);
							if (has_water) {
								phase[exit] = static_cast<uint8_t>(here_phase);
							}
							if (hero_zone[exit] != 0) {
								reached.push_back(static_cast<int32_t>(exit));
								continue;
							}
							enqueue(exit);
						}
					}
				}
				continue;
			}
			if (blocked[next] != 0) {
				continue;
			}
			dist[next] = static_cast<int32_t>(next_distance);
			parent[next] = static_cast<int32_t>(current);
			if (has_water) {
				phase[next] = static_cast<uint8_t>(here_phase);
			}
			enqueue(next);
		}
	}
	// The hero's own tile counts as reached at distance zero.
	if (stop_mask[start] != 0) {
		reached.push_back(static_cast<int32_t>(start));
	}
	out.order_count = tail;
	out.capped = capped;
}

} // namespace aurelion::rules::ai_search
