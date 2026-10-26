// battle_sim_cli: the battle tool (Phase 2c, decision D7;
// docs/native-rules-engine-transition.md), the battle AI arena's battles
// played outside Godot by the native rules core.
//
//   battle_sim_cli --content <content.snap> --corpus-dir <dir> --out <games.jsonl>
//       [--variants <variants.txt> --default <label> | --plain]
//       [--orders A:B,B:A] [--threads N]
//
// The arena's setup worker (tools/battle_ai_arena/worker.gd, a "setup" job)
// builds each battle's session in the game, as the arena's games do up to the
// battle payload, and writes each map's battles as a snapshot
// (aurelion_rules/snapshot.hpp) into the corpus folder, with the content and
// static vars the battle reads in the content snapshot. This tool plays every
// order of every battle from there, as worker.gd's _play_game goes on, and
// writes one game record per line, the same record.
//
// Each side's stacks are commanded with its own variant's weights: the battle
// code routes each call the arena's GDScript router routes (port/ai_route.hpp)
// to the side's variant, whose BattleAiRules static vars (its weights and
// memos) are its own, as each variant script's are; a call routed to no side
// takes --default. The variants file has a line per weight, label TAB key TAB
// value, the value as the arena writes it into a variant's source ("%.6f"):
// both parsers make the nearest float of such a text. A label alone is a
// variant without a literal, which reads the content's weights file. --plain
// plays the content's own weights on both sides with no router (arena.py
// --plain).
//
// What the tool leaves out of the game: a battle starts from the snapshot's
// session; a battle end where the player beats a site's guards visits the
// site through its port (OverworldRules._collect_resource_node_result), which
// the record does not read; ProfileLog answers nothing; pow, exp and log are this build's C runtime's,
// not the engine's (decision D4), and are counted. The run's counts go to
// stdout as one JSON line.

#include "aurelion_rules/battle_hex.hpp"
#include "aurelion_rules/battle_state.hpp"
#include "aurelion_rules/port/ai_hero_rules_ai.hpp"
#include "aurelion_rules/port/content_service_ai.hpp"
#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/registry.hpp"
#include "aurelion_rules/snapshot.hpp"
#include "snapshot_store.hpp"

#include <algorithm>
#include <atomic>
#include <charconv>
#include <chrono>
#include <cmath>
#include <condition_variable>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <exception>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <map>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <string>
#include <string_view>
#include <thread>
#include <unordered_map>
#include <utility>
#include <vector>

namespace {

namespace fs = std::filesystem;
namespace gd = aurelion::rules::gd;
namespace port = aurelion::rules::port;
namespace snap = aurelion::rules::snapshot;
namespace st = aurelion::rules::state;
namespace key = st::key;
using st::Kind;
using st::State;
using st::TypeRef;
using st::Value;

using Clock = std::chrono::steady_clock;

// The atoms every State has in the same place: the known keys, then the
// board's cells (State::clear).
constexpr uint32_t kFixedAtoms = static_cast<uint32_t>(key::known_count) + static_cast<uint32_t>(aurelion::rules::battle_hex::kCellCount);
// A worker's State is cleared whole, atoms too, once a game ends with more
// atoms than this: the battle logs' texts would grow it without end.
constexpr size_t kAtomLimit = 1u << 20;
// BattleAutoResolveRules.DEFAULT_STEP_LIMIT, resolve_active_battle's default.
constexpr int64_t kStepLimit = 240;

using aurelion::rules::cli::Content;
using aurelion::rules::cli::fail;
using aurelion::rules::cli::kTableNames;
using aurelion::rules::cli::load_content;
using aurelion::rules::cli::load_store;
using aurelion::rules::cli::Store;
using aurelion::rules::cli::Types;

void append_json_string(std::string &out, std::string_view text) {
	out += '"';
	for (const char c : text) {
		const unsigned char byte = static_cast<unsigned char>(c);
		switch (c) {
			case '"':
				out += "\\\"";
				break;
			case '\\':
				out += "\\\\";
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
				if (byte < 0x20) {
					char escaped[8];
					std::snprintf(escaped, sizeof(escaped), "\\u%04x", byte);
					out += escaped;
				} else {
					out += c;
				}
		}
	}
	out += '"';
}

void append_json_number(std::string &out, double number) {
	if (std::isnan(number)) {
		out += "NaN";
		return;
	}
	if (std::isinf(number)) {
		out += number > 0 ? "Infinity" : "-Infinity";
		return;
	}
	char text[32];
	std::snprintf(text, sizeof(text), "%.17g", number);
	out += text;
}

// One battle of a map, as the setup worker left it before the payload.
struct Battle {
	std::string battle_id;
	std::string kind;
	// The record's fields so far, as JSON without its closing brace.
	std::string prefix;
	std::string town;
	int64_t dice = 0;
	Value session;
	Value site;
};

// One map's snapshot: {group: {scenario_id, scenario, terrain_layers,
// content_revision}, battles: [...]}.
struct Group {
	uint64_t id = 0;
	std::unique_ptr<Store> store;
	std::string scenario_id;
	Value scenario;
	Value terrain_layers;
	int64_t revision = 0;
	std::vector<Battle> battles;
};

std::shared_ptr<Group> load_group(const fs::path &path, uint64_t id, Types &types) {
	auto group = std::make_shared<Group>();
	group->id = id;
	group->store = load_store(path, types);
	const Store &store = *group->store;
	const Value root = store.decoded.root;
	const Value record = store.get(root, "group");
	const Value battles = store.get(root, "battles");
	if (record.kind != Kind::Dict || battles.kind != Kind::Array) {
		fail(path.string() + " is no battle corpus: it needs group and battles");
	}
	group->scenario_id = store.text(store.get(record, "scenario_id"));
	group->scenario = store.get(record, "scenario");
	group->terrain_layers = store.get(record, "terrain_layers");
	const Value revision = store.get(record, "content_revision");
	group->revision = revision.kind == Kind::Int ? revision.i : 0;
	for (const Value &entry : store.state.array_node(battles.ref).items) {
		Battle battle;
		battle.battle_id = store.text(store.get(entry, "battle_id"));
		battle.kind = store.text(store.get(entry, "kind"));
		battle.prefix = store.text(store.get(entry, "prefix"));
		battle.town = store.text(store.get(entry, "town"));
		const Value dice = store.get(entry, "dice");
		battle.dice = dice.kind == Kind::Int ? dice.i : 0;
		battle.session = store.get(entry, "session");
		battle.site = store.get(entry, "site");
		if (battle.session.kind != Kind::Dict || battle.prefix.empty() || battle.prefix.front() != '{') {
			fail(path.string() + ": battle " + battle.battle_id + " has no session or record");
		}
		group->battles.push_back(std::move(battle));
	}
	return group;
}

struct Variant {
	std::string label;
	// A _weights literal, as arena.py writes one into a variant's source, in its
	// order (sorted by key); without one the variant reads the content's
	// weights file, as the game's own BattleAiRules does.
	bool literal = false;
	std::vector<std::pair<std::string, double>> weights;
};

std::vector<Variant> load_variants(const fs::path &path) {
	std::ifstream in(path, std::ios::binary);
	if (!in) {
		fail("cannot read " + path.string());
	}
	std::vector<Variant> variants;
	std::string line;
	while (std::getline(in, line)) {
		if (!line.empty() && line.back() == '\r') {
			line.pop_back();
		}
		if (line.empty() || line.front() == '#') {
			continue;
		}
		const size_t first = line.find('\t');
		const std::string label = line.substr(0, first);
		auto found = std::find_if(variants.begin(), variants.end(), [&](const Variant &v) { return v.label == label; });
		if (found == variants.end()) {
			variants.push_back(Variant{ label, false, {} });
			found = variants.end() - 1;
		}
		if (first == std::string::npos) {
			// A label alone: the content's weights.
			continue;
		}
		const size_t second = line.find('\t', first + 1);
		if (second == std::string::npos) {
			fail(path.string() + ": a line is not label, key and value: " + line);
		}
		const std::string name = line.substr(first + 1, second - first - 1);
		const std::string text = line.substr(second + 1);
		double value = 0.0;
		const auto parsed = std::from_chars(text.data(), text.data() + text.size(), value);
		if (parsed.ec != std::errc() || parsed.ptr != text.data() + text.size()) {
			fail(path.string() + ": not a number: " + text);
		}
		found->literal = true;
		found->weights.emplace_back(name, value);
	}
	return variants;
}

struct Order {
	std::string player;
	std::string enemy;
	// Indices into the variants (routed runs).
	size_t player_index = 0;
	size_t enemy_index = 0;
};

struct Options {
	fs::path content;
	fs::path corpus_dir;
	fs::path out;
	fs::path variants;
	std::string default_label;
	std::vector<Order> orders;
	bool plain = false;
	bool trace = false;
	int64_t dice = 0;
	unsigned threads = 0;
};

// What a worker counted; summed at the end.
struct Counts {
	int64_t games = 0;
	int64_t errors = 0;
	std::map<std::string, int64_t> host_calls;
	std::map<std::string, int64_t> content_misses;
	int64_t pow_calls = 0;
	int64_t exp_calls = 0;
	int64_t log_calls = 0;
	int64_t printed_errors = 0;
	int64_t printed_warnings = 0;
	std::vector<std::string> messages;

	void note(const std::string &text) {
		if (messages.size() < 20) {
			messages.push_back(text);
		}
	}
	void add(const Counts &other) {
		games += other.games;
		errors += other.errors;
		for (const auto &[name, count] : other.host_calls) {
			host_calls[name] += count;
		}
		for (const auto &[name, count] : other.content_misses) {
			content_misses[name] += count;
		}
		pow_calls += other.pow_calls;
		exp_calls += other.exp_calls;
		log_calls += other.log_calls;
		printed_errors += other.printed_errors;
		printed_warnings += other.printed_warnings;
		for (const std::string &text : other.messages) {
			note(text);
		}
	}
};

// A store's nodes and atoms in a worker's State, for the game being played.
struct StoreMap {
	const Store *store = nullptr;
	uint64_t bound = ~0ull;
	// Store atom -> game atom + 1 (0: not looked up yet).
	std::vector<uint32_t> atoms;
	// Game atom -> store atom + 2 (1: the store has no such text, 0: not looked up yet).
	std::vector<uint32_t> back;
	// Store node -> epoch << 32 | game node.
	std::vector<uint64_t> arrays;
	std::vector<uint64_t> dicts;
	std::vector<uint64_t> packeds;

	void bind(const Store *to, uint64_t id) {
		store = to;
		bound = id;
		atoms.assign(to->state.atom_count(), 0);
		back.clear();
		arrays.assign(to->state.array_count(), 0);
		dicts.assign(to->state.dict_count(), 0);
		packeds.assign(to->state.packed_count(), 0);
	}
	void forget_atoms() {
		std::fill(atoms.begin(), atoms.end(), 0);
		back.clear();
	}
	void forget_nodes() {
		std::fill(arrays.begin(), arrays.end(), 0);
		std::fill(dicts.begin(), dicts.end(), 0);
		std::fill(packeds.begin(), packeds.end(), 0);
	}
};

// A backed game node's source.
struct Source {
	StoreMap *map = nullptr;
	uint32_t node = 0;
};

// An opaque value of the game: a value the snapshot does not model, a
// RandomNumberGenerator, or the session (its view stands for it in host calls).
struct Opaque {
	std::string what;
	bool rng = false;
	uint64_t seed = 0;
	uint64_t state = 0;
};

// One thread's player: its own State and the host the ported code asks.
class Worker final : public st::Backing {
public:
	Worker(const Options &options, const Content &content, Types &types, const std::vector<Variant> &variants) :
			options_(options), content_(content), types_(types), variants_(variants) {
		state_.set_backing(this);
		content_map_.bind(content.store.get(), 0);
		label_statics_.resize(variants.size());
		routing_ = !options.plain;
	}

	Counts counts;

	// The game's record, one JSON line.
	std::string play(const Group &group, const Battle &battle, const Order &order) {
		const Clock::time_point started = Clock::now();
		begin_game(group, order);
		std::string row = battle.prefix;
		row += ",\"player_variant\":";
		append_json_string(row, order.player);
		row += ",\"enemy_variant\":";
		append_json_string(row, order.enemy);
		try {
			row += game(battle);
		} catch (const st::ScriptError &error) {
			row += error_field(std::string("native script error: ") + error.what());
		} catch (const st::NotPorted &error) {
			row += error_field(std::string("not ported: ") + error.what());
		} catch (const st::Suspend &suspend) {
			row += error_field("a host call where none may run: " + state_.text(suspend.script) + "." + state_.text(suspend.function));
		} catch (const std::exception &error) {
			row += error_field(std::string("native exception: ") + error.what());
		}
		row += ",\"ms\":";
		append_json_number(row, std::chrono::duration<double, std::milli>(Clock::now() - started).count());
		row += '}';
		++counts.games;
		return row;
	}

	// Backing: the stores' nodes, read one value at a time until filled.
	void fill_array(State &state, uint32_t node) override {
		const Source source = array_sources_[node];
		const st::ArrayNode &from = source.map->store->state.array_node(source.node);
		st::ValueList items;
		items.resize(from.items.size());
		for (size_t index = 0; index < from.items.size(); ++index) {
			items[index] = import(*source.map, from.items[index]);
		}
		state.array_node(node).items = std::move(items);
	}
	void fill_dict(State &state, uint32_t node) override {
		const Source source = dict_sources_[node];
		const st::DictNode &from = source.map->store->state.dict_node(source.node);
		st::ValueList keys;
		st::ValueList values;
		keys.resize(from.keys.size());
		values.resize(from.values.size());
		for (size_t index = 0; index < from.keys.size(); ++index) {
			keys[index] = import(*source.map, from.keys[index]);
			values[index] = import(*source.map, from.values[index]);
		}
		st::DictNode &target = state.dict_node(node);
		target.keys = std::move(keys);
		target.values = std::move(values);
	}
	int64_t array_size(uint32_t node) override {
		const Source &source = array_sources_[node];
		return static_cast<int64_t>(source.map->store->state.array_node(source.node).items.size());
	}
	Value array_at(State &, uint32_t node, int64_t index) override {
		const Source source = array_sources_[node];
		return import(*source.map, source.map->store->state.array_node(source.node).items[static_cast<size_t>(index)]);
	}
	int64_t dict_size(uint32_t node) override {
		const Source &source = dict_sources_[node];
		return static_cast<int64_t>(source.map->store->state.dict_node(source.node).keys.size());
	}
	bool dict_lookup(State &, uint32_t node, const Value &key_value, Value &out) override {
		const Source source = dict_sources_[node];
		Value store_key;
		if (!store_key_of(*source.map, key_value, store_key)) {
			return false;
		}
		Value found;
		if (!source.map->store->state.lookup(source.node, store_key, found)) {
			return false;
		}
		out = import(*source.map, found);
		return true;
	}
	void fill_packed(State &state, uint32_t node) override {
		const Source source = packed_sources_[node];
		const st::PackedNode &from = source.map->store->state.packed_node(source.node);
		st::PackedNode &target = state.packed_node(node);
		target.bytes = from.bytes;
		target.ints = from.ints;
		target.atoms.resize(from.atoms.size());
		for (size_t index = 0; index < from.atoms.size(); ++index) {
			target.atoms[index] = game_atom(*source.map, from.atoms[index]);
		}
	}

	// The session is a view (a Dictionary), so objects are only the opaque
	// values the snapshot kept by name and RandomNumberGenerators.
	Value view_object(State &, uint32_t node) override {
		return node == session_node_ ? Value::of_ref(Kind::Opaque, session_slot_) : Value();
	}
	bool rng_get(uint32_t slot, uint64_t &seed, uint64_t &rng_state) override {
		if (slot >= opaques_.size() || !opaques_[slot].rng) {
			return false;
		}
		seed = opaques_[slot].seed;
		rng_state = opaques_[slot].state;
		return true;
	}
	void rng_set_state(uint32_t slot, uint64_t rng_state) override {
		opaques_.at(slot).state = rng_state;
	}
	uint32_t rng_new(uint64_t seed, uint64_t rng_state) override {
		Opaque made;
		made.what = "RandomNumberGenerator";
		made.rng = true;
		made.seed = seed;
		made.state = rng_state;
		opaques_.push_back(made);
		return static_cast<uint32_t>(opaques_.size() - 1);
	}

	Value content_row(State &state, st::ContentTable table, uint32_t id) override {
		switch (table) {
			case st::ContentTable::Scenario:
				if (state.text(id) == group_->scenario_id && group_->scenario.kind == Kind::Dict) {
					return import(group_map_, group_->scenario);
				}
				return miss(table, id);
			case st::ContentTable::TerrainLayersForScenario:
				// A new deep copy on every call, as ContentService makes it.
				if (state.text(id) == group_->scenario_id && group_->terrain_layers.kind == Kind::Dict) {
					const Value layers = import(group_map_, group_->terrain_layers);
					return state.dict_size(layers.ref) == 0 ? Value() : gd::dict_value(gd::deep_duplicate_dict(state, layers.ref));
				}
				return miss(table, id);
			case st::ContentTable::BiomeForTerrain:
				id = port::content_service::normalize_terrain_id(state, id);
				if (id == key::empty) {
					return Value();
				}
				break;
			case st::ContentTable::MapObjectForResourceSite:
				id = gd::strip_edges(state, id);
				if (id == key::empty) {
					return Value();
				}
				break;
			default:
				break;
		}
		const Value rows = content_.tables[static_cast<size_t>(table)];
		if (rows.kind != Kind::Dict) {
			throw st::ScriptError(std::string("the content snapshot has no ") + kTableNames[static_cast<size_t>(table)] + " table");
		}
		uint32_t store_id = 0;
		Value row;
		if (!store_atom(content_map_, id, store_id) || !content_.store->state.lookup(rows.ref, Value::str(store_id), row)) {
			// ContentService's {} for an unknown id: gd::content_row makes it.
			return Value();
		}
		return import(content_map_, row);
	}
	Value content_file(State &state, uint32_t path) override {
		uint32_t store_path = 0;
		Value data;
		if (!store_atom(content_map_, path, store_path) || !content_.store->state.lookup(content_.files.ref, Value::str(store_path), data)) {
			throw st::ScriptError("ContentService.load_json(\"" + state.text(path) + "\"): a file the content snapshot does not hold");
		}
		return import(content_map_, data);
	}
	int64_t content_revision(State &) override {
		return group_->revision;
	}

	Value static_get(State &state, uint32_t script, uint32_t name) override {
		std::unordered_map<uint64_t, Value> &table = statics_for(script);
		const uint64_t slot = static_cast<uint64_t>(script) << 32 | name;
		const auto found = table.find(slot);
		if (found != table.end()) {
			return found->second;
		}
		const Value value = initial_static(state, script, name);
		table.emplace(slot, value);
		return value;
	}
	void static_set(State &, uint32_t script, uint32_t name, const Value &value) override {
		statics_for(script)[static_cast<uint64_t>(script) << 32 | name] = value;
	}

	Value call_static(State &state, uint32_t script, uint32_t function, const Value *, size_t) override {
		const std::string name = port::host_name(state.text(script), state.text(function));
		if (name == "ProfileLog.emit_general") {
			++counts.host_calls[name];
			return Value();
		}
		throw st::ScriptError(name + ": a host call the battle tool does not answer");
	}

	TypeRef builtin_type(uint8_t builtin) override {
		TypeRef &type = builtin_types_[builtin];
		if (type == 0) {
			snap::TypeInfo info;
			info.builtin = builtin;
			type = types_.ref(info);
			types_.sync(state_, known_types_);
		}
		return type;
	}

	void print_error(const std::string &text) override {
		++counts.printed_errors;
		counts.note("ERROR: " + text);
	}
	void print_warning(const std::string &text) override {
		++counts.printed_warnings;
		counts.note("WARNING: " + text);
	}

	double math_pow(double base, double exponent) override {
		++counts.pow_calls;
		return Backing::math_pow(base, exponent);
	}
	double math_exp(double x) override {
		++counts.exp_calls;
		return Backing::math_exp(x);
	}
	double math_log(double x) override {
		++counts.log_calls;
		return Backing::math_log(x);
	}

	bool routes_ai() const override {
		return routing_;
	}
	// As the router's _arena_policy: the call is counted under its side, and
	// the side's variant plays it.
	void ai_route_enter(State &, uint32_t side) override {
		auto found = std::find_if(calls_.begin(), calls_.end(), [&](const std::pair<uint32_t, int64_t> &entry) { return entry.first == side; });
		if (found == calls_.end()) {
			calls_.emplace_back(side, 1);
		} else {
			++found->second;
		}
		route_.push_back(side == key::player ? player_label_ : (side == key::enemy ? enemy_label_ : default_label_));
	}
	void ai_route_leave(State &) override {
		route_.pop_back();
	}

	void set_default_label(size_t label) { default_label_ = label; }

private:
	void begin_game(const Group &group, const Order &order) {
		if (state_.atom_count() > kAtomLimit) {
			state_.clear();
			content_map_.forget_atoms();
			group_map_.forget_atoms();
		} else {
			state_.clear_nodes();
		}
		types_.sync(state_, known_types_);
		if (group_map_.bound != group.id) {
			group_map_.bind(group.store.get(), group.id);
		}
		if (++epoch_ == 0) {
			content_map_.forget_nodes();
			group_map_.forget_nodes();
			epoch_ = 1;
		}
		group_ = &group;
		statics_.clear();
		for (auto &table : label_statics_) {
			table.clear();
		}
		calls_.clear();
		route_.clear();
		opaques_.clear();
		player_label_ = order.player_index;
		enemy_label_ = order.enemy_index;
		session_node_ = ~0u;
	}

	// As worker.gd's _play_game from the payload on: the record's fields after
	// the setup worker's.
	std::string game(const Battle &battle) {
		const Value session = import(group_map_, battle.session);
		Opaque view;
		view.what = "SessionData";
		opaques_.push_back(view);
		session_slot_ = static_cast<uint32_t>(opaques_.size() - 1);
		session_node_ = session.ref;
		Value payload;
		if (battle.kind == "siege") {
			payload = call("BattleRules.create_town_assault_payload", { session, state_.string(battle.town) });
		} else {
			const Value site = battle.site.kind == Kind::Dict ? import(group_map_, battle.site) : gd::dict_value(state_.new_dict());
			payload = call("BattleRules.create_battle_payload", { session, site });
		}
		if (payload.kind != Kind::Dict || state_.dict_size(payload.ref) == 0) {
			return error_field("battle payload is empty");
		}
		std::string out;
		// The same battle with other dice (a group's "dice").
		const int64_t dice = options_.dice != 0 ? options_.dice : battle.dice;
		if (dice != 0) {
			const uint32_t pair = state_.new_array();
			state_.append(pair, gd::int_value(gd::to_int(state_, state_.get(payload.ref, gd::str(key::combat_seed), gd::int_value(0)))));
			state_.append(pair, gd::int_value(dice));
			state_.set(payload.ref, gd::str(key::combat_seed), gd::int_value(gd::hash(state_, gd::array_value(pair))));
			for (const uint32_t erased : { key::damage_rng_version, key::damage_rng_state, key::damage_rng_roll_count, key::damage_rng_integrity }) {
				state_.erase(payload.ref, gd::str(erased));
			}
			out += ",\"dice\":" + std::to_string(dice);
		}
		gd::set_member(state_, session, key::battle, payload);
		gd::set_member(state_, session, key::game_state, state_.string("battle"));
		call("BattleRules.normalize_battle_state", { session });
		const Value battle_state = gd::member(state_, session, key::battle);
		out += ",\"combat_seed\":";
		append_json(out, field(battle_state, key::combat_seed));
		const uint32_t start_health = state_.new_array();
		for (const Value &stack : gd::items(state_, field(battle_state, key::stacks))) {
			const uint32_t health = state_.new_dict();
			for (const uint32_t name : { key::side, key::unit_id, key::base_count, key::unit_hp, key::total_health }) {
				state_.set(health, gd::str(name), field(stack, name));
			}
			state_.append(start_health, gd::dict_value(health));
		}
		out += ",\"start_health\":";
		append_json(out, gd::array_value(start_health));
		out += ",\"start_ledger\":";
		append_json(out, call("BattleRules._battle_report_casualty_ledger", { battle_state }));
		between_calls();
		const Value player_commander = field(battle_state, key::player_commander_state);
		const Value enemy_commander = field(battle_state, key::enemy_hero);
		out += ",\"player_commander\":";
		append_commander(out, player_commander);
		out += ",\"enemy_commander\":";
		append_commander(out, enemy_commander);
		out += ",\"player_hero\":";
		out += non_empty(player_commander) ? "true" : "false";
		if (battle.kind != "siege") {
			out += ",\"enemy_hero\":";
			out += non_empty(enemy_commander) && battle.kind == "hero" ? "true" : "false";
		}
		const uint32_t trace_frames = state_.new_array();
		if (options_.trace) {
			state_.set(battle_state.ref, gd::str(key::_live_action_playback_capture), gd::array_value(trace_frames));
		}
		const Value resolution = call("BattleAutoResolveRules.resolve_active_battle", { session, gd::int_value(kStepLimit), gd::int_value(0) });
		if (options_.trace) {
			const uint32_t compact = state_.new_array();
			for (const Value &frame : gd::items(state_, gd::array_value(trace_frames))) {
				const uint32_t row = state_.new_dict();
				for (const char *name : { "round", "turn_index", "active_stack_id", "selected_target_id", "playback_event", "stacks", "recent_events", "battlefield_tags", "player_commander_state", "enemy_hero" }) {
					const Value name_value = state_.string(name);
					state_.set(row, name_value, state_.get(frame.ref, name_value, Value()));
				}
				state_.append(compact, gd::dict_value(row));
			}
			out += ",\"trace_frames\":";
			append_json(out, gd::array_value(compact));
			out += ",\"action_counts\":";
			append_json(out, field(resolution, key::action_counts));
		}
		const Value flags = gd::member(state_, session, key::flags);
		const Value report = flags.kind == Kind::Dict ? state_.get(flags.ref, gd::str(key::last_battle_aftermath), gd::dict_value(state_.new_dict())) : Value();
		const bool has_report = report.kind == Kind::Dict;
		out += ",\"state\":";
		append_json_string(out, state_.text(gd::stringify(state_, field(resolution, key::state, state_.string("")))));
		out += ",\"completed\":";
		out += gd::to_bool(field(resolution, key::completed, gd::bool_value(false))) ? "true" : "false";
		out += ",\"invalid_orders\":" + std::to_string(gd::to_int(state_, field(resolution, key::invalid_orders, gd::int_value(0))));
		out += ",\"outcome\":";
		append_json_string(out, has_report ? state_.text(gd::stringify(state_, field(report, key::outcome, state_.string("")))) : std::string());
		out += ",\"rounds\":" + std::to_string(has_report ? gd::to_int(state_, field(report, key::rounds, gd::int_value(0))) : 0);
		out += ",\"end_ledger\":";
		append_json(out, has_report ? field(report, key::casualties, gd::dict_value(state_.new_dict())) : gd::dict_value(state_.new_dict()));
		out += ",\"ai_calls\":{";
		if (routing_) {
			for (size_t index = 0; index < calls_.size(); ++index) {
				if (index > 0) {
					out += ',';
				}
				append_json_string(out, state_.text(calls_[index].first));
				out += ':' + std::to_string(calls_[index].second);
			}
		}
		out += '}';
		return out;
	}

	// A top-level call into the port, as the game's switch makes it.
	Value call(const char *name, std::initializer_list<Value> args) {
		const port::Function *function = port::find_function(name);
		if (function == nullptr || static_cast<size_t>(function->arity) != args.size()) {
			fail(std::string("the port has no ") + name + " of " + std::to_string(args.size()) + " arguments");
		}
		between_calls();
		return function->call(state_, args.begin());
	}

	// What a new call in the game would see: the game reloads every container
	// for each call, so no memo answer survives one, no answer stays frozen,
	// and every container is watched.
	void between_calls() {
		state_.drop_memo();
		for (size_t node = 0; node < state_.array_count(); ++node) {
			state_.array_node(static_cast<uint32_t>(node)).guard = State::kWatched;
		}
		for (size_t node = 0; node < state_.dict_count(); ++node) {
			state_.dict_node(static_cast<uint32_t>(node)).guard = State::kWatched;
		}
		for (size_t node = 0; node < state_.packed_count(); ++node) {
			state_.packed_node(static_cast<uint32_t>(node)).guard = State::kWatched;
		}
	}

	// dict.get(name, fallback) of a Dictionary, Nil of anything else.
	Value field(const Value &dict, uint32_t name, const Value &fallback = Value()) {
		if (dict.kind != Kind::Dict) {
			return Value();
		}
		return state_.get(dict.ref, gd::str(name), fallback);
	}
	bool non_empty(const Value &value) {
		return value.kind == Kind::Dict && state_.dict_size(value.ref) != 0;
	}

	// worker.gd's _commander_features: a side's hero as the strength estimate
	// sees it.
	void append_commander(std::string &out, const Value &commander) {
		if (!non_empty(commander)) {
			out += "{}";
			return;
		}
		const Value command_value = field(commander, key::command);
		const Value command = command_value.kind == Kind::Dict ? command_value : gd::dict_value(state_.new_dict());
		const auto int_field = [&](const Value &from, uint32_t name) {
			return std::to_string(gd::to_int(state_, field(from, name, gd::int_value(0))));
		};
		out += "{\"level\":" + int_field(commander, key::level);
		out += ",\"attack\":" + int_field(command, key::attack);
		out += ",\"defense\":" + int_field(command, key::defense);
		out += ",\"power\":" + int_field(command, key::power);
		out += ",\"knowledge\":" + int_field(command, key::knowledge);
		between_calls();
		out += ",\"spell_damage\":";
		append_json_number(out, port::ai_hero_rules::_spell_damage_per_round(state_, commander.ref));
		out += '}';
	}

	// JSON.stringify of a game value: keys as their texts.
	void append_json(std::string &out, const Value &value) {
		switch (value.kind) {
			case Kind::Nil:
			case Kind::Opaque:
				out += "null";
				return;
			case Kind::Bool:
				out += value.b ? "true" : "false";
				return;
			case Kind::Int:
				out += std::to_string(value.i);
				return;
			case Kind::Float:
				append_json_number(out, value.f);
				return;
			case Kind::String:
			case Kind::StringName:
				append_json_string(out, state_.text(value.ref));
				return;
			case Kind::Vector2i:
				append_json_string(out, "(" + std::to_string(value.vx()) + ", " + std::to_string(value.vy()) + ")");
				return;
			case Kind::Vector3i:
				append_json_string(out, "(" + std::to_string(value.vx()) + ", " + std::to_string(value.vy()) + ", " + std::to_string(value.vz()) + ")");
				return;
			case Kind::Array: {
				const st::ValueList items = state_.array(value.ref).items;
				out += '[';
				for (size_t index = 0; index < items.size(); ++index) {
					if (index > 0) {
						out += ',';
					}
					append_json(out, items[index]);
				}
				out += ']';
				return;
			}
			case Kind::Dict: {
				const st::DictNode &node = state_.dict(value.ref);
				const st::ValueList keys = node.keys.list();
				const st::ValueList values = node.values;
				out += '{';
				for (size_t index = 0; index < keys.size(); ++index) {
					if (index > 0) {
						out += ',';
					}
					const Value &entry = keys[index];
					if (entry.is_string_like()) {
						append_json_string(out, state_.text(entry.ref));
					} else {
						std::string text;
						append_json(text, entry);
						append_json_string(out, text);
					}
					out += ':';
					append_json(out, values[index]);
				}
				out += '}';
				return;
			}
			case Kind::PackedByte:
			case Kind::PackedInt32:
			case Kind::PackedString: {
				const st::PackedNode &node = state_.packed(value.ref);
				out += '[';
				for (size_t index = 0; index < node.size(); ++index) {
					if (index > 0) {
						out += ',';
					}
					if (node.kind == Kind::PackedByte) {
						out += std::to_string(node.bytes[index]);
					} else if (node.kind == Kind::PackedInt32) {
						out += std::to_string(node.ints[index]);
					} else {
						append_json_string(out, state_.text(node.atoms[index]));
					}
				}
				out += ']';
				return;
			}
		}
	}

	std::string error_field(const std::string &text) {
		++counts.errors;
		counts.note(text);
		std::string out = ",\"error\":";
		append_json_string(out, text);
		return out;
	}

	Value miss(st::ContentTable table, uint32_t id) {
		++counts.content_misses[std::string(kTableNames[static_cast<size_t>(table)]) + " " + state_.text(id)];
		return Value();
	}

	std::unordered_map<uint64_t, Value> &statics_for(uint32_t script) {
		if (routing_ && script == key::battle_ai_rules_script) {
			return label_statics_[route_.empty() ? default_label_ : route_.back()];
		}
		return statics_;
	}

	// A static var's value when a game starts: a routed variant's weights
	// literal, or the setup worker's value of it.
	Value initial_static(State &state, uint32_t script, uint32_t name) {
		const Variant *variant = routing_ && script == key::battle_ai_rules_script && name == key::_weights ? &variants_[route_.empty() ? default_label_ : route_.back()] : nullptr;
		if (variant != nullptr && variant->literal) {
			const uint32_t weights = state.new_dict();
			for (const auto &[weight, number] : variant->weights) {
				state.set(weights, state.string(weight), gd::float_value(number));
			}
			return gd::dict_value(weights);
		}
		uint32_t store_script = 0;
		uint32_t store_name = 0;
		Value names;
		Value value;
		if (!store_atom(content_map_, script, store_script) || !store_atom(content_map_, name, store_name)
				|| !content_.store->state.lookup(content_.statics.ref, Value::str(store_script), names) || names.kind != Kind::Dict
				|| !content_.store->state.lookup(names.ref, Value::str(store_name), value)) {
			throw st::ScriptError(state.text(script) + "." + state.text(name) + ": a static var the content snapshot does not hold");
		}
		return import(content_map_, value);
	}

	uint32_t game_atom(StoreMap &map, uint32_t atom) {
		if (atom < kFixedAtoms) {
			return atom;
		}
		uint32_t &slot = map.atoms[atom];
		if (slot == 0) {
			slot = state_.intern(map.store->state.text(atom)) + 1;
		}
		return slot - 1;
	}

	bool store_atom(StoreMap &map, uint32_t atom, uint32_t &out) {
		if (atom < kFixedAtoms) {
			out = atom;
			return true;
		}
		if (map.back.size() <= atom) {
			map.back.resize(state_.atom_count(), 0);
		}
		uint32_t &slot = map.back[atom];
		if (slot == 0) {
			uint32_t found = 0;
			slot = map.store->state.find_atom(state_.text(atom), found) ? found + 2 : 1;
		}
		if (slot == 1) {
			return false;
		}
		out = slot - 2;
		return true;
	}

	// A lookup key in the store's atoms: false when the store has no such text.
	bool store_key_of(StoreMap &map, const Value &game_key, Value &out) {
		switch (game_key.kind) {
			case Kind::String:
			case Kind::StringName: {
				uint32_t atom = 0;
				if (!store_atom(map, game_key.ref, atom)) {
					return false;
				}
				out = Value::of_ref(game_key.kind, atom);
				return true;
			}
			case Kind::Nil:
			case Kind::Bool:
			case Kind::Int:
			case Kind::Float:
			case Kind::Vector2i:
			case Kind::Vector3i:
				out = game_key;
				return true;
			default:
				throw st::ScriptError(std::string("a lookup by a ") + gd::type_name(game_key) + " key in a snapshot's Dictionary");
		}
	}

	// A store's value in the game: each store node one backed game node per game.
	Value import(StoreMap &map, const Value &value) {
		switch (value.kind) {
			case Kind::String:
			case Kind::StringName:
				return Value::of_ref(value.kind, game_atom(map, value.ref));
			case Kind::Array:
				return Value::of_ref(Kind::Array, import_node(map, map.arrays, value.ref, Kind::Array));
			case Kind::Dict:
				return Value::of_ref(Kind::Dict, import_node(map, map.dicts, value.ref, Kind::Dict));
			case Kind::PackedByte:
			case Kind::PackedInt32:
			case Kind::PackedString:
				return Value::of_ref(value.kind, import_node(map, map.packeds, value.ref, value.kind));
			case Kind::Opaque: {
				Opaque kept;
				kept.what = map.store->decoded.unsupported.at(value.ref);
				opaques_.push_back(kept);
				return Value::of_ref(Kind::Opaque, static_cast<uint32_t>(opaques_.size() - 1));
			}
			default:
				return value;
		}
	}

	uint32_t import_node(StoreMap &map, std::vector<uint64_t> &nodes, uint32_t node, Kind kind) {
		uint64_t &slot = nodes[node];
		if ((slot >> 32) == epoch_) {
			return static_cast<uint32_t>(slot);
		}
		uint32_t made = 0;
		const State &from = map.store->state;
		if (kind == Kind::Array) {
			made = state_.new_array();
			const st::ArrayNode &source = from.array_node(node);
			st::ArrayNode &target = state_.array_node(made);
			target.backed = true;
			target.element_type = map.store->types[source.element_type];
			target.read_only = source.read_only;
			remember(array_sources_, made, map, node);
		} else if (kind == Kind::Dict) {
			made = state_.new_dict();
			const st::DictNode &source = from.dict_node(node);
			st::DictNode &target = state_.dict_node(made);
			target.backed = true;
			target.key_type = map.store->types[source.key_type];
			target.value_type = map.store->types[source.value_type];
			target.read_only = source.read_only;
			remember(dict_sources_, made, map, node);
		} else {
			made = state_.new_packed(kind);
			state_.packed_node(made).backed = true;
			remember(packed_sources_, made, map, node);
		}
		// What the game holds: the native memo's answers read from it stay only
		// while the port writes nothing into it, as the adapter's loads are.
		state_.watch_loaded(Value::of_ref(kind, made));
		slot = static_cast<uint64_t>(epoch_) << 32 | made;
		return made;
	}

	static void remember(std::vector<Source> &sources, uint32_t made, StoreMap &map, uint32_t node) {
		if (sources.size() <= made) {
			sources.resize(static_cast<size_t>(made) + 1);
		}
		sources[made] = Source{ &map, node };
	}

	const Options &options_;
	const Content &content_;
	Types &types_;
	const std::vector<Variant> &variants_;
	State state_;
	size_t known_types_ = 0;
	TypeRef builtin_types_[256] = {};
	StoreMap content_map_;
	StoreMap group_map_;
	uint32_t epoch_ = 0;
	std::vector<Source> array_sources_;
	std::vector<Source> dict_sources_;
	std::vector<Source> packed_sources_;
	const Group *group_ = nullptr;
	uint32_t session_node_ = ~0u;
	uint32_t session_slot_ = 0;
	std::vector<Opaque> opaques_;
	bool routing_ = false;
	// The global static vars, and each variant's BattleAiRules ones.
	std::unordered_map<uint64_t, Value> statics_;
	std::vector<std::unordered_map<uint64_t, Value>> label_statics_;
	// The router's _arena_calls, in insertion order; the labels of the open routes.
	std::vector<std::pair<uint32_t, int64_t>> calls_;
	std::vector<size_t> route_;
	size_t player_label_ = 0;
	size_t enemy_label_ = 0;
	size_t default_label_ = 0;
};

struct Item {
	std::shared_ptr<Group> group;
	size_t battle = 0;
	size_t order = 0;
};

// Hands out the games map by map, loading a map's snapshot when the queue runs
// low, and drops it once its games are played (its last Item goes).
class Scheduler {
public:
	Scheduler(std::vector<fs::path> paths, size_t orders, unsigned threads, Types &types) :
			paths_(std::move(paths)), orders_(orders), threads_(threads), types_(types) {}

	bool next(Item &item) {
		std::unique_lock<std::mutex> lock(mutex_);
		for (;;) {
			const bool low = ready_.size() < threads_;
			if (next_path_ < paths_.size() && (ready_.empty() || (low && loading_ == 0))) {
				const size_t index = next_path_++;
				++loading_;
				lock.unlock();
				std::shared_ptr<Group> group;
				std::string error;
				try {
					group = load_group(paths_[index], index, types_);
				} catch (const std::exception &failure) {
					error = paths_[index].string() + ": " + failure.what();
				}
				lock.lock();
				--loading_;
				if (group) {
					for (size_t battle = 0; battle < group->battles.size(); ++battle) {
						for (size_t order = 0; order < orders_; ++order) {
							ready_.push_back(Item{ group, battle, order });
						}
					}
				} else {
					errors_.push_back(error);
				}
				changed_.notify_all();
				continue;
			}
			if (!ready_.empty()) {
				item = std::move(ready_.front());
				ready_.pop_front();
				return true;
			}
			if (loading_ == 0) {
				return false;
			}
			changed_.wait(lock);
		}
	}

	std::vector<std::string> errors() const {
		const std::lock_guard<std::mutex> lock(mutex_);
		return errors_;
	}

private:
	std::vector<fs::path> paths_;
	size_t orders_;
	size_t threads_;
	Types &types_;
	mutable std::mutex mutex_;
	std::condition_variable changed_;
	std::deque<Item> ready_;
	size_t next_path_ = 0;
	int loading_ = 0;
	std::vector<std::string> errors_;
};

[[noreturn]] void usage(const std::string &problem) {
	std::fprintf(stderr,
			"battle_sim_cli: %s\n"
			"usage: battle_sim_cli --content <content.snap> --corpus-dir <dir> --out <games.jsonl>\n"
			"       [--variants <variants.txt> --default <label> | --plain] [--orders A:B,B:A] [--threads N] [--dice N] [--trace]\n",
			problem.c_str());
	std::exit(2);
}

Options parse(int argc, char **argv) {
	Options options;
	std::string orders = "A:B,B:A";
	for (int index = 1; index < argc; ++index) {
		const std::string arg = argv[index];
		const auto value = [&]() -> std::string {
			if (index + 1 >= argc) {
				usage(arg + " needs a value");
			}
			return argv[++index];
		};
		if (arg == "--content") {
			options.content = value();
		} else if (arg == "--corpus-dir") {
			options.corpus_dir = value();
		} else if (arg == "--out") {
			options.out = value();
		} else if (arg == "--variants") {
			options.variants = value();
		} else if (arg == "--default") {
			options.default_label = value();
		} else if (arg == "--orders") {
			orders = value();
		} else if (arg == "--plain") {
			options.plain = true;
		} else if (arg == "--trace") {
			options.trace = true;
		} else if (arg == "--dice") {
			options.dice = std::stoll(value());
		} else if (arg == "--threads") {
			options.threads = static_cast<unsigned>(std::stoul(value()));
		} else {
			usage("unknown argument " + arg);
		}
	}
	if (options.content.empty() || options.corpus_dir.empty() || options.out.empty()) {
		usage("--content, --corpus-dir and --out are required");
	}
	if (options.plain == !options.variants.empty()) {
		usage("give either --variants (with --default) or --plain");
	}
	size_t start = 0;
	while (start <= orders.size()) {
		const size_t comma = std::min(orders.find(',', start), orders.size());
		const std::string pair = orders.substr(start, comma - start);
		const size_t colon = pair.find(':');
		if (colon == std::string::npos || colon == 0 || colon + 1 == pair.size()) {
			usage("an order is player:enemy, got " + pair);
		}
		options.orders.push_back(Order{ pair.substr(0, colon), pair.substr(colon + 1) });
		start = comma + 1;
	}
	if (options.threads == 0) {
		options.threads = std::max(1u, std::thread::hardware_concurrency());
	}
	return options;
}

size_t label_index(const std::vector<Variant> &variants, const std::string &label) {
	for (size_t index = 0; index < variants.size(); ++index) {
		if (variants[index].label == label) {
			return index;
		}
	}
	fail("no variant is labelled " + label);
}

std::string counts_json(const Counts &counts, double seconds, unsigned threads, size_t groups, const std::vector<std::string> &group_errors) {
	std::string out = "{\"kind\":\"battle_sim_cli\",\"games\":" + std::to_string(counts.games);
	out += ",\"errors\":" + std::to_string(counts.errors);
	out += ",\"seconds\":";
	append_json_number(out, seconds);
	out += ",\"threads\":" + std::to_string(threads);
	out += ",\"groups\":" + std::to_string(groups);
	out += ",\"group_errors\":[";
	for (size_t index = 0; index < group_errors.size(); ++index) {
		out += index > 0 ? "," : "";
		append_json_string(out, group_errors[index]);
	}
	out += "],\"host_calls\":{";
	bool first = true;
	for (const auto &[name, count] : counts.host_calls) {
		out += first ? "" : ",";
		first = false;
		append_json_string(out, name);
		out += ':' + std::to_string(count);
	}
	out += "},\"content_misses\":{";
	first = true;
	for (const auto &[name, count] : counts.content_misses) {
		out += first ? "" : ",";
		first = false;
		append_json_string(out, name);
		out += ':' + std::to_string(count);
	}
	out += "},\"math_calls\":{\"pow\":" + std::to_string(counts.pow_calls) + ",\"exp\":" + std::to_string(counts.exp_calls) + ",\"log\":" + std::to_string(counts.log_calls) + "}";
	out += ",\"printed_errors\":" + std::to_string(counts.printed_errors);
	out += ",\"printed_warnings\":" + std::to_string(counts.printed_warnings);
	out += ",\"messages\":[";
	for (size_t index = 0; index < counts.messages.size(); ++index) {
		out += index > 0 ? "," : "";
		append_json_string(out, counts.messages[index]);
	}
	out += "]}";
	return out;
}

int run(int argc, char **argv) {
	Options options = parse(argc, argv);
	const Clock::time_point started = Clock::now();
	Types types;
	const Content content = load_content(options.content, types);
	std::vector<Variant> variants;
	size_t default_label = 0;
	if (!options.plain) {
		variants = load_variants(options.variants);
		default_label = label_index(variants, options.default_label);
		for (Order &order : options.orders) {
			order.player_index = label_index(variants, order.player);
			order.enemy_index = label_index(variants, order.enemy);
		}
	}
	std::vector<fs::path> paths;
	for (const fs::directory_entry &entry : fs::directory_iterator(options.corpus_dir)) {
		if (entry.is_regular_file() && entry.path().extension() == ".snap") {
			paths.push_back(entry.path());
		}
	}
	std::sort(paths.begin(), paths.end());
	const size_t groups = paths.size();
	std::ofstream out(options.out, std::ios::binary);
	if (!out) {
		fail("cannot write " + options.out.string());
	}
	Scheduler scheduler(std::move(paths), options.orders.size(), options.threads, types);
	std::mutex out_mutex;
	std::vector<std::unique_ptr<Worker>> workers;
	std::vector<std::thread> threads;
	std::vector<std::string> failures(options.threads);
	for (unsigned index = 0; index < options.threads; ++index) {
		workers.push_back(std::make_unique<Worker>(options, content, types, variants));
		workers.back()->set_default_label(default_label);
	}
	for (unsigned index = 0; index < options.threads; ++index) {
		threads.emplace_back([&, index] {
			Worker &worker = *workers[index];
			try {
				Item item;
				while (scheduler.next(item)) {
					std::string row = worker.play(*item.group, item.group->battles[item.battle], options.orders[item.order]);
					row += '\n';
					item = Item();
					const std::lock_guard<std::mutex> lock(out_mutex);
					out.write(row.data(), static_cast<std::streamsize>(row.size()));
				}
			} catch (const std::exception &error) {
				failures[index] = error.what();
			}
		});
	}
	for (std::thread &thread : threads) {
		thread.join();
	}
	out.close();
	if (!out) {
		fail("cannot write " + options.out.string());
	}
	Counts counts;
	for (const auto &worker : workers) {
		counts.add(worker->counts);
	}
	std::vector<std::string> group_errors = scheduler.errors();
	for (const std::string &failure : failures) {
		if (!failure.empty()) {
			group_errors.push_back("a worker stopped: " + failure);
		}
	}
	const double seconds = std::chrono::duration<double>(Clock::now() - started).count();
	const std::string summary = counts_json(counts, seconds, options.threads, groups, group_errors);
	std::fprintf(stdout, "%s\n", summary.c_str());
	// The workers' States hold every node their games made: freeing them one by
	// one took longer than the games (13 to 18 s after a tune.py generation), and
	// the process ends here anyway.
	std::fflush(stdout);
	std::fflush(stderr);
	std::_Exit(group_errors.empty() ? 0 : 1);
}

} // namespace

int main(int argc, char **argv) {
	try {
		return run(argc, argv);
	} catch (const std::exception &error) {
		std::fprintf(stderr, "battle_sim_cli: %s\n", error.what());
		return 2;
	}
}
