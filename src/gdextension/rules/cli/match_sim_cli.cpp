// match_sim_cli: the AI match runner without Godot (Phase 8, P8-3, P8-4 and
// P8-7; docs/native-rules-engine-transition.md).
//
//   match_sim_cli [--threads N]
//
// The match runner scene (tests/ai_versus_ai_match_report.gd) makes each
// match's map in the game. With HEROES_AI_MATCH_PREPARE it writes the map's
// setup and its two packages, with the match's settings, as a snapshot
// (aurelion_rules/snapshot.hpp), with the content and the rules scripts'
// static vars in content.snap beside it, and stops. This tool goes on from
// there as the scene does: the session starts natively from the packages
// (ScenarioSelectRules.start_random_map_skirmish_session_from_setup, Phase 7's
// 7.11), the human seat goes to the computer (AiSeatRules.hand_human_seat_to_ai)
// and the days play, each the day registry's OverworldRules.end_turn. The
// scene's GDScript around them (the handover's check, the digest, the notes,
// the ledger, the town weeks, the end of the match, the record and the report
// line) is C++ here, calling the same native functions. It writes what the
// scene writes.
//
// The settings are the scene's: HEROES_AI_MATCH_* in the environment for one
// match, or HEROES_AI_MATCH_LIST, a JSON array of objects of them, one per
// match (a setting an object leaves out comes from the environment).
// HEROES_AI_MATCH_SNAPSHOT names a match's setup snapshot and
// HEROES_AI_MATCH_CONTENT its content snapshot (default: content.snap in the
// same folder). The tool reads HEROES_AI_MATCH_OUT, _MAX_DAYS, _DIGEST, _DUMP,
// _DUMP_DAY, _DIGEST_BLANK and _TRACE; the snapshot fixes everything else (the
// seed, the map, the line-up, the weight sets). The matches play on --threads
// threads (default: one per core, at most one per match), one match per thread
// at a time. Each match prints its lines together when it ends: in a list its
// AI_VERSUS_AI_MATCH_BEGIN line first, then its errors, warnings and trace
// lines, then its report line. A last line, MATCH_SIM_CLI {...}, counts what
// the host answered. The exit code is 1 when a match failed.
//
// The host (P8-3, P8-7): content rows and files come from the content
// snapshot, any content override (seat weight sets) from the setup snapshot.
// The map package service and its documents are the core's port of them
// (aurelion_rules/map_packages.hpp), reading the packages the snapshot carries;
// the art the packages name is looked up in the project folder the scene ran
// in (content::DiskFiles). The new session is a SessionData of this host's
// (SessionStateStore.new_session_data). A generated map's session registers no
// scenario draft, so its scenario and terrain layers rows are {}. Static vars
// start, in each match, as the content snapshot's capture of a game that has
// played nothing: memos and caches empty, the AI weights loaded from
// content/ai_hero_weights.json by the native _use_weights where the game's
// GDScript loads them. They stay from one day to the next, as the game's do.
// pow, exp and log are the core's portable ones, as in the game. The session
// stays one State across the days, as the game's kept session does (P6-4):
// between days only the scene's own changes reach it, and the State drops
// what nothing holds any more after each day. A day answers no host call: a
// host call, or a path the native port leaves to GDScript (a NATIVE FALLBACK
// in the game), fails the match.

#include "aurelion_rules/battle_state.hpp"
#include "aurelion_rules/compat/godot_json.hpp"
#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/disk_files.hpp"
#include "aurelion_rules/map_packages.hpp"
#include "aurelion_rules/port/content_service_ai.hpp"
#include "aurelion_rules/port/enemy_turn_rules.hpp"
#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/registry.hpp"
#include "aurelion_rules/port/turn_port.hpp"
#include "aurelion_rules/snapshot.hpp"
#include "snapshot_store.hpp"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <filesystem>
#include <fstream>
#include <map>
#include <memory>
#include <mutex>
#include <set>
#include <string>
#include <string_view>
#include <thread>
#include <unordered_map>
#include <utility>
#include <vector>

#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#endif

namespace {

namespace fs = std::filesystem;
namespace cli = aurelion::rules::cli;
namespace compat = aurelion::rules::compat;
namespace gd = aurelion::rules::gd;
namespace port = aurelion::rules::port;
namespace snap = aurelion::rules::snapshot;
namespace st = aurelion::rules::state;
namespace key = st::key;
namespace players = port::player_identity_rules;
namespace map_packages = aurelion::rules::map_packages;
using cli::Content;
using cli::fail;
using cli::kTableNames;
using cli::Store;
using cli::Types;
using st::Kind;
using st::State;
using st::TypeRef;
using st::Value;

using Clock = std::chrono::steady_clock;

constexpr const char *kReportId = "AI_VERSUS_AI_MATCH_REPORT";
constexpr const char *kBeginId = "AI_VERSUS_AI_MATCH_BEGIN";
constexpr int64_t kDefaultMaxDays = 320;
constexpr const char *kDefaultOut = "ai_versus_ai_match.json";
// A worker's State is cleared whole, atoms too, between matches once it holds
// more atoms than this: the logs' texts would grow it without end.
constexpr size_t kAtomLimit = size_t(1) << 20;

// SessionData's fields, as a view carries them (DayEngine.SESSION_FIELDS),
// and their GDScript types: i int, s String, d Dictionary.
constexpr const char *kSessionFields[] = {
	"save_version",
	"session_id",
	"scenario_id",
	"hero_id",
	"day",
	"difficulty",
	"launch_mode",
	"game_state",
	"scenario_status",
	"scenario_summary",
	"overworld",
	"battle",
	"flags",
};
constexpr size_t kFieldCount = sizeof(kSessionFields) / sizeof(kSessionFields[0]);
constexpr char kFieldTypes[] = "isssisssssddd";
static_assert(sizeof(kFieldTypes) == kFieldCount + 1, "a type per session field");
enum Field : size_t {
	kDay = 4,
	kGameState = 7,
	kOverworld = 10,
	kBattle = 11,
	kFlags = 12,
};

// --------------------------------------------------------------- JSON text

// "\"" + text.json_escape() + "\"" (String::json_escape): the backslash,
// \b \f \n \r \t \v and the quote; other characters as they are.
void append_json_string(std::string &out, std::string_view text) {
	out += '"';
	for (const char c : text) {
		switch (c) {
			case '\\':
				out += "\\\\";
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
			case '\v':
				out += "\\v";
				break;
			case '"':
				out += "\\\"";
				break;
			default:
				out += c;
		}
	}
	out += '"';
}

std::string vector_text(const Value &value) {
	if (value.kind == Kind::Vector2i) {
		return "(" + compat::itos(value.vx()) + ", " + compat::itos(value.vy()) + ")";
	}
	return "(" + compat::itos(value.vx()) + ", " + compat::itos(value.vy()) + ", " + compat::itos(value.vz()) + ")";
}

// String(key) of a Dictionary key, as JSON writes it.
std::string key_text(const State &state, const Value &value) {
	switch (value.kind) {
		case Kind::String:
		case Kind::StringName:
			return state.text(value.ref);
		case Kind::Int:
			return compat::itos(value.i);
		case Kind::Float:
			return compat::num(value.f);
		case Kind::Bool:
			return value.b ? "true" : "false";
		case Kind::Nil:
			return "<null>";
		case Kind::Vector2i:
		case Kind::Vector3i:
			return vector_text(value);
		default:
			return gd::type_name(value);
	}
}

// StringLikeVariantOrder: String-likes by their text (UTF-8 byte order is code
// point order), anything else by Variant's <, its type first.
bool key_less(const State &state, const Value &a, const Value &b) {
	if (a.is_string_like() && b.is_string_like()) {
		return state.text(a.ref) < state.text(b.ref);
	}
	if (a.kind != b.kind) {
		return gd::type_of(a) < gd::type_of(b);
	}
	switch (a.kind) {
		case Kind::Int:
			return a.i < b.i;
		case Kind::Float:
			return a.f < b.f;
		case Kind::Bool:
			return !a.b && b.b;
		default:
			return false;
	}
}

// JSON.stringify(value, indent, sort_keys, full_precision) (JSON::_stringify),
// at depth levels of indent.
struct Json {
	const State &state;
	std::string indent;
	bool sort_keys = true;
	bool full_precision = false;

	void pad(std::string &out, int depth) const {
		for (int level = 0; level < depth; ++level) {
			out += indent;
		}
	}
	const char *newline() const { return indent.empty() ? "" : "\n"; }

	// [items], each item written at depth + 1.
	template <typename Write>
	void list(std::string &out, size_t count, int depth, Write write) const {
		if (count == 0) {
			out += "[]";
			return;
		}
		out += '[';
		out += newline();
		for (size_t index = 0; index < count; ++index) {
			if (index > 0) {
				out += ',';
				out += newline();
			}
			pad(out, depth + 1);
			write(index);
		}
		out += newline();
		pad(out, depth);
		out += ']';
	}

	void write(std::string &out, const Value &value, int depth) const {
		switch (value.kind) {
			case Kind::Nil:
			case Kind::Opaque:
				out += "null";
				return;
			case Kind::Bool:
				out += value.b ? "true" : "false";
				return;
			case Kind::Int:
				out += compat::itos(value.i);
				return;
			case Kind::Float:
				out += compat::json_float(value.f, full_precision);
				return;
			case Kind::String:
			case Kind::StringName:
				append_json_string(out, state.text(value.ref));
				return;
			case Kind::Vector2i:
			case Kind::Vector3i:
				append_json_string(out, vector_text(value));
				return;
			case Kind::Array: {
				const st::ValueList &items = state.array(value.ref).items;
				list(out, items.size(), depth, [&](size_t index) { write(out, items[index], depth + 1); });
				return;
			}
			case Kind::PackedByte:
			case Kind::PackedInt32:
			case Kind::PackedString: {
				const st::PackedNode &node = state.packed(value.ref);
				list(out, node.size(), depth, [&](size_t index) {
					if (node.kind == Kind::PackedByte) {
						out += compat::itos(node.bytes[index]);
					} else if (node.kind == Kind::PackedInt32) {
						out += compat::itos(node.ints[index]);
					} else {
						append_json_string(out, state.text(node.atoms[index]));
					}
				});
				return;
			}
			case Kind::Dict: {
				const st::DictNode &node = state.dict(value.ref);
				std::vector<size_t> order(node.keys.size());
				for (size_t index = 0; index < order.size(); ++index) {
					order[index] = index;
				}
				const st::ValueList &keys = node.keys.list();
				if (sort_keys) {
					std::sort(order.begin(), order.end(), [&](size_t a, size_t b) { return key_less(state, keys[a], keys[b]); });
				}
				if (order.empty()) {
					// An empty Array is "[]", an empty Dictionary its two
					// statement ends and its closing indent.
					out += '{';
					out += newline();
					out += newline();
					pad(out, depth);
					out += '}';
					return;
				}
				out += '{';
				out += newline();
				for (size_t index = 0; index < order.size(); ++index) {
					if (index > 0) {
						out += ',';
						out += newline();
					}
					pad(out, depth + 1);
					append_json_string(out, key_text(state, keys[order[index]]));
					out += indent.empty() ? ":" : ": ";
					write(out, node.values[order[index]], depth + 1);
				}
				out += newline();
				pad(out, depth);
				out += '}';
				return;
			}
		}
	}

	std::string text(const Value &value, int depth = 0) const {
		std::string out;
		write(out, value, depth);
		return out;
	}
};

// ------------------------------------------------------------ settings

std::string strip(const std::string &text) {
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

// OS.get_environment(name), as the port reads it.
std::string environment(const char *name) {
	return port::turn::environment(name);
}

// One match's settings: its list entry's, else the environment's (the scene's
// _env).
struct Settings {
	std::map<std::string, std::string> values;
	bool listed = false;

	std::string get(const char *name) const {
		const auto found = values.find(name);
		return found != values.end() ? found->second : environment(name);
	}
};

// HEROES_AI_MATCH_LIST's entries, each value as String(value) makes it.
std::vector<Settings> read_list(const std::string &path) {
	const std::vector<uint8_t> bytes = cli::read_file(path);
	State parsed;
	const compat::JsonParse result = compat::json_parse(parsed, std::string_view(reinterpret_cast<const char *>(bytes.data()), bytes.size()));
	if (result.error != 0 || result.data.kind != Kind::Array) {
		fail("HEROES_AI_MATCH_LIST " + path + " holds no JSON array of objects.");
	}
	std::vector<Settings> list;
	for (const Value &entry : parsed.array(result.data.ref).items) {
		if (entry.kind != Kind::Dict) {
			fail("HEROES_AI_MATCH_LIST " + path + " holds no JSON array of objects.");
		}
		Settings settings;
		settings.listed = true;
		const st::DictNode &node = parsed.dict(entry.ref);
		for (size_t index = 0; index < node.keys.size(); ++index) {
			const Value &item = node.values[index];
			std::string text;
			if (item.is_string_like()) {
				text = parsed.text(item.ref);
			} else if (item.kind == Kind::Float) {
				text = compat::num(item.f);
			} else if (item.kind == Kind::Bool) {
				text = item.b ? "true" : "false";
			}
			settings.values[key_text(parsed, node.keys.list()[index])] = text;
		}
		list.push_back(std::move(settings));
	}
	return list;
}

// OS.set_environment: the Win32 environment the port reads
// (port::turn::environment) and the C runtime's.
void set_environment(const char *name, const char *value) {
#ifdef _WIN32
	std::wstring wide_name;
	std::wstring wide_value;
	for (const char *c = name; *c != '\0'; ++c) {
		wide_name.push_back(static_cast<wchar_t>(static_cast<unsigned char>(*c)));
	}
	for (const char *c = value; *c != '\0'; ++c) {
		wide_value.push_back(static_cast<wchar_t>(static_cast<unsigned char>(*c)));
	}
	SetEnvironmentVariableW(wide_name.c_str(), wide_value.c_str());
	_putenv_s(name, value);
#else
	setenv(name, value, 1);
#endif
}

// ----------------------------------------------------------------- host

// A store's nodes and atoms in a worker's State, for the match being played.
struct StoreMap {
	const Store *store = nullptr;
	// Store atom -> game atom + 1 (0: not looked up yet).
	std::vector<uint32_t> atoms;
	// Game atom -> store atom + 2 (1: the store has no such text, 0: not looked up yet).
	std::vector<uint32_t> back;
	// Store node -> epoch << 32 | game node.
	std::vector<uint64_t> arrays;
	std::vector<uint64_t> dicts;
	std::vector<uint64_t> packeds;

	void bind(const Store *to) {
		store = to;
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

// An opaque value of the game: the session (slot 0; its view stands for it),
// a value the snapshot does not model, a RandomNumberGenerator, or what game
// setup asks for: the map package service, a map or scenario document (its
// state in the worker's documents) and the ContentService and SessionState
// autoloads.
struct Opaque {
	std::string what;
	bool rng = false;
	uint64_t seed = 0;
	uint64_t state = 0;
	int document = -1;
};

// What the workers counted; summed at the end.
struct Counts {
	int64_t matches = 0;
	int64_t failed = 0;
	int64_t days = 0;
	std::map<std::string, int64_t> host_calls;
	std::map<std::string, int64_t> content_misses;
	int64_t pow_calls = 0;
	int64_t exp_calls = 0;
	int64_t log_calls = 0;
	int64_t printed_errors = 0;
	int64_t printed_warnings = 0;
	size_t most_atoms = 0;

	void add(const Counts &other) {
		matches += other.matches;
		failed += other.failed;
		days += other.days;
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
		most_atoms = std::max(most_atoms, other.most_atoms);
	}
};

// The content snapshots the matches name, each loaded once and shared.
class Contents {
public:
	explicit Contents(Types &types) :
			types_(types) {}

	const Content &get(const fs::path &path) {
		const std::string name = fs::absolute(path).lexically_normal().generic_string();
		const std::lock_guard<std::mutex> lock(mutex_);
		auto found = loaded_.find(name);
		if (found == loaded_.end()) {
			found = loaded_.emplace(name, std::make_unique<Content>(cli::load_content(path, types_))).first;
		}
		return *found->second;
	}

private:
	Types &types_;
	std::mutex mutex_;
	std::map<std::string, std::unique_ptr<Content>> loaded_;
};

// The texts the scene's GDScript names, as atoms of a worker's State.
struct Names {
	uint32_t fields[kFieldCount] = {};
	uint32_t meta, instance_id, untouched_meta;
	uint32_t day, sides, treasury, towns, buildings, heroes, hero, level, power, x, y, hero_power, garrison_power, sites,
			explored, economy, decisions, turn_ms;
	uint32_t enemy_states, players, player_id, owner, enemy, neutral, built_buildings, garrison, enemy_commander_state,
			resource_nodes, encounters, resolved_encounters, placement_id, town_id, faction_id, available_recruits;
	uint32_t economy_log, decision_log, capture_log, battle_log, explored_key, ai_hero, goal, kind, id, gold;
	uint32_t enemy_turn_profile, factions, phases_ms;
	uint32_t type, town, from, to, town_placement_id, town_captured, hero_hired, hero_fell, hired_day, fell_day,
			experience, battle_wins, name, faction, built, recruits, recruits_power, stacks, unit_id, count;
	uint32_t session_id, scenario_id, game_state, scenario_status, scenario_summary, overworld, battle, flags;
	uint32_t zero;

	void make(State &state) {
		for (size_t index = 0; index < kFieldCount; ++index) {
			fields[index] = state.intern(kSessionFields[index]);
		}
		const auto n = [&](const char *text) { return state.intern(text); };
		meta = n("meta");
		instance_id = n("instance_id");
		untouched_meta = n("_overworld_session_untouched_between_days");
		day = n("day");
		sides = n("sides");
		treasury = n("treasury");
		towns = n("towns");
		buildings = n("buildings");
		heroes = n("heroes");
		hero = n("hero");
		level = n("level");
		power = n("power");
		x = n("x");
		y = n("y");
		hero_power = n("hero_power");
		garrison_power = n("garrison_power");
		sites = n("sites");
		explored = n("explored");
		economy = n("economy");
		decisions = n("decisions");
		turn_ms = n("turn_ms");
		enemy_states = n("enemy_states");
		players = n("players");
		player_id = n("player_id");
		owner = n("owner");
		enemy = n("enemy");
		neutral = n("neutral");
		built_buildings = n("built_buildings");
		garrison = n("garrison");
		enemy_commander_state = n("enemy_commander_state");
		resource_nodes = n("resource_nodes");
		encounters = n("encounters");
		resolved_encounters = n("resolved_encounters");
		placement_id = n("placement_id");
		town_id = n("town_id");
		faction_id = n("faction_id");
		available_recruits = n("available_recruits");
		economy_log = n("ai_economy_log");
		decision_log = n("ai_decision_log");
		capture_log = n("ai_capture_log");
		battle_log = n("ai_battle_log");
		explored_key = n("ai_explored");
		ai_hero = n("ai_hero");
		goal = n("goal");
		kind = n("kind");
		id = n("id");
		gold = n("gold");
		enemy_turn_profile = n("enemy_turn_profile");
		factions = n("factions");
		phases_ms = n("phases_ms");
		type = n("type");
		town = n("town");
		from = n("from");
		to = n("to");
		town_placement_id = n("town_placement_id");
		town_captured = n("town_captured");
		hero_hired = n("hero_hired");
		hero_fell = n("hero_fell");
		hired_day = n("hired_day");
		fell_day = n("fell_day");
		experience = n("experience");
		battle_wins = n("battle_wins");
		name = n("name");
		faction = n("faction");
		built = n("built");
		recruits = n("recruits");
		recruits_power = n("recruits_power");
		stacks = n("stacks");
		unit_id = n("unit_id");
		count = n("count");
		session_id = fields[1];
		scenario_id = fields[2];
		game_state = fields[kGameState];
		scenario_status = fields[8];
		scenario_summary = fields[9];
		overworld = fields[kOverworld];
		battle = fields[kBattle];
		flags = fields[kFlags];
		zero = n("0");
	}
};

// The native functions the scene calls, by their registry names.
struct Calls {
	const port::Function *start_session = nullptr;
	const port::Function *normalize = nullptr;
	const port::Function *end_turn = nullptr;
	const port::Function *hero_power = nullptr;
	const port::Function *army_power = nullptr;
	const port::Function *active_hero_entries = nullptr;
	const port::Function *hero_name = nullptr;
	const port::Function *town_name = nullptr;

	static const port::Function *find(const char *name, int arity) {
		const port::Function *function = port::find_function(name);
		if (function == nullptr || function->arity != arity) {
			fail(std::string("the port has no ") + name + " of " + std::to_string(arity) + " arguments");
		}
		return function;
	}
	Calls() :
			start_session(find("ScenarioSelectRules.start_random_map_skirmish_session_from_setup", 1)),
			normalize(find("OverworldRules.normalize_overworld_state", 1)),
			end_turn(find("OverworldRules.end_turn", 1)),
			hero_power(find("AiHeroRules.hero_power", 1)),
			army_power(find("AiHeroRules.army_power", 2)),
			active_hero_entries(find("AiHeroRules.active_hero_entries", 2)),
			hero_name(find("AiHeroRules.hero_name", 1)),
			town_name(find("EnemyTurnRules._town_name", 1)) {}
};

// The match failed: the scene's _fail, which ends the match.
struct MatchFailed {
	std::string message;
};

// One thread's player: its own State and the host the ported code asks.
class Worker final : public st::Backing {
public:
	Worker(Contents &contents, Types &types, const Calls &calls) :
			contents_(contents), types_(types), calls_(calls) {
		state_.set_backing(this);
		names_.make(state_);
	}

	Counts counts;

	// The match's lines, as the scene prints them; false when it failed.
	bool play(const Settings &settings, std::string &lines) {
		started_ = Clock::now();
		lines_ = &lines;
		out_path_ = strip(settings.get("HEROES_AI_MATCH_OUT"));
		if (out_path_.empty()) {
			out_path_ = kDefaultOut;
		}
		// ProjectSettings.globalize_path leaves a path outside res:// and user:// as it is.
		out_text_ = out_path_;
		if (settings.listed) {
			std::string begin = std::string(kBeginId) + " {\"out\":";
			append_json_string(begin, out_text_);
			lines += begin + "}\n";
		}
		bool ok = false;
		try {
			match(settings);
			ok = true;
		} catch (const MatchFailed &failed) {
			report_failure(failed.message);
		} catch (const st::ScriptError &error) {
			report_failure(std::string("The native rules port failed: native script error: ") + error.what());
		} catch (const st::NotPorted &error) {
			report_failure(std::string("The native rules port failed: a path it leaves to GDScript: ") + error.what());
		} catch (const st::Suspend &suspend) {
			report_failure("The native rules port failed: a host call: " + state_.text(suspend.script) + "." + state_.text(suspend.function));
		} catch (const std::exception &error) {
			report_failure(std::string("The match runner failed: ") + error.what());
		}
		digest_.close();
		++counts.matches;
		counts.failed += ok ? 0 : 1;
		counts.most_atoms = std::max(counts.most_atoms, state_.atom_count());
		lines_ = nullptr;
		return ok;
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

	// The session is a view (a Dictionary), as DayEngine.gd makes one for each
	// native call; it stands for the session object, opaque slot 0.
	Value view_object(State &, uint32_t node) override {
		return node == view_node_ ? Value::of_ref(Kind::Opaque, 0) : Value();
	}
	// Game setup takes the new session as an object: its view, one for the
	// call (the match takes it back when the call returns), reads and writes
	// its fields.
	Value object_view(State &, uint32_t slot) override {
		if (slot != 0 || object_.kind != Kind::Dict) {
			throw st::ScriptError("a view of " + opaques_.at(slot).what + ", which is no session");
		}
		return gd::dict_value(view_node_ != ~0u ? view_node_ : make_view());
	}
	Value object_get(State &state, uint32_t slot, uint32_t property) override {
		const Value view = object_view(state, slot);
		Value found;
		if (!state.lookup(view.ref, gd::str(property), found)) {
			throw st::ScriptError("SessionData has no property " + state.text(property));
		}
		return found;
	}
	void object_set(State &state, uint32_t slot, uint32_t property, const Value &value) override {
		const Value view = object_view(state, slot);
		if (property == names_.meta || property == names_.instance_id || !state.has(view.ref, gd::str(property))) {
			throw st::ScriptError("SessionData has no script variable " + state.text(property));
		}
		state.set(view.ref, gd::str(property), value);
	}

	// ClassDB.instantiate("MapPackageService"), the core's port of it.
	Value class_instantiate(State &state, uint32_t name) override {
		if (state.text(name) != "MapPackageService") {
			throw st::ScriptError(state.text(name) + ": a class the match runner does not make");
		}
		return new_opaque("MapPackageService");
	}
	// The autoloads game setup calls: ContentService (canonical_town_id) and
	// SessionState (its active session, which nothing here reads).
	Value autoload(State &state, uint32_t name) override {
		const std::string &text = state.text(name);
		if (text != "ContentService" && text != "SessionState") {
			throw st::ScriptError(text + ": an autoload the match runner does not have");
		}
		return new_opaque(text);
	}
	Value object_call(State &state, uint32_t slot, uint32_t method, const Value *args, size_t count) override {
		const std::string what = opaques_.at(slot).what;
		const std::string &name = state.text(method);
		if (what == "MapPackageService" && (name == "load_map_package" || name == "load_scenario_package")) {
			if (count < 1 || !args[0].is_string_like()) {
				throw st::ScriptError("MapPackageService." + name + " takes a String path");
			}
			const std::string path = state.text(args[0].ref);
			if (name == "load_map_package") {
				const Value document = new_opaque("MapDocument");
				opaques_[document.ref].document = static_cast<int>(map_documents_.size());
				map_documents_.push_back(std::make_unique<map_packages::MapDocument>());
				return map_packages::load_map_package(state, *disk_, path, *map_documents_.back(), document);
			}
			const Value document = new_opaque("ScenarioDocument");
			opaques_[document.ref].document = static_cast<int>(scenario_documents_.size());
			scenario_documents_.push_back(std::make_unique<map_packages::ScenarioDocument>());
			return map_packages::load_scenario_package(state, *disk_, path, *scenario_documents_.back(), document);
		}
		const int document = opaques_.at(slot).document;
		if (what == "MapDocument" && document >= 0 && static_cast<size_t>(document) < map_documents_.size()) {
			return map_packages::map_document_call(state, *map_documents_[document], name, args, count);
		}
		if (what == "ScenarioDocument" && document >= 0 && static_cast<size_t>(document) < scenario_documents_.size()) {
			return map_packages::scenario_document_call(state, *scenario_documents_[document], name, args, count);
		}
		if (what == "ContentService" && name == "canonical_town_id" && count == 1) {
			return canonical_town_id(state, gd::to_string(args[0]));
		}
		if (what == "SessionState" && name == "set") {
			return Value();
		}
		throw st::ScriptError(what + "." + name + ": a method the match runner does not answer");
	}
	bool object_has_method(State &state, uint32_t slot, uint32_t method) override {
		const std::string &what = opaques_.at(slot).what;
		const std::string &name = state.text(method);
		if (what == "MapDocument") {
			return map_packages::map_document_has_method(name);
		}
		if (what == "ScenarioDocument") {
			return map_packages::scenario_document_has_method(name);
		}
		throw st::ScriptError(what + ".has_method(\"" + name + "\"): a question the match runner does not answer");
	}
	bool file_exists(State &state, uint32_t path) override {
		return disk_ != nullptr && disk_->exists(state.text(path));
	}
	bool resource_exists(State &state, uint32_t path) override {
		return disk_ != nullptr && disk_->resource_exists(state.text(path));
	}
	// OS.has_feature("editor"): the scene runs in the editor binary.
	bool os_has_feature(State &state, uint32_t name) override {
		if (state.text(name) != "editor") {
			throw st::ScriptError("OS.has_feature(\"" + state.text(name) + "\"): a feature the match runner does not know");
		}
		return true;
	}
	uint32_t os_environment(State &state, uint32_t name) override {
		return state.intern(environment(state.text(name).c_str()));
	}
	uint32_t json_stringify(State &state, const Value &value) override {
		return state.intern(gd::json_stringify(state, value));
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
			case st::ContentTable::TerrainLayersForScenario:
				// The match's own scenario: a generated map's session
				// registers no draft, and ContentService answers {}.
				return state.text(id) == scenario_id_ ? Value() : miss(table, id);
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
		const Value rows = content_->tables[static_cast<size_t>(table)];
		if (rows.kind != Kind::Dict) {
			throw st::ScriptError(std::string("the content snapshot has no ") + kTableNames[static_cast<size_t>(table)] + " table");
		}
		uint32_t store_id = 0;
		Value row;
		if (!store_atom(content_rows_, id, store_id) || !content_->store->state.lookup(rows.ref, Value::str(store_id), row)) {
			// ContentService's {} for an unknown id: gd::content_row makes it.
			return Value();
		}
		return import(content_rows_, row);
	}
	Value content_file(State &state, uint32_t path) override {
		uint32_t store_path = 0;
		Value data;
		if (files_.kind == Kind::Dict && store_atom(match_rows_, path, store_path) && match_store_->state.lookup(files_.ref, Value::str(store_path), data)) {
			return import(match_rows_, data);
		}
		if (!store_atom(content_rows_, path, store_path) || !content_->store->state.lookup(content_->files.ref, Value::str(store_path), data)) {
			throw st::ScriptError("ContentService.load_json(\"" + state.text(path) + "\"): a file the content snapshot does not hold");
		}
		return import(content_rows_, data);
	}
	int64_t content_revision(State &) override {
		return content_revision_;
	}

	Value static_get(State &state, uint32_t script, uint32_t name) override {
		const uint64_t slot = static_cast<uint64_t>(script) << 32 | name;
		const auto found = statics_.find(slot);
		if (found != statics_.end()) {
			return found->second;
		}
		const Value value = initial_static(state, script, name);
		statics_.emplace(slot, value);
		return value;
	}
	void static_set(State &, uint32_t script, uint32_t name, const Value &value) override {
		statics_[static_cast<uint64_t>(script) << 32 | name] = value;
	}

	Value call_static(State &state, uint32_t script, uint32_t function, const Value *args, size_t count) override {
		const std::string name = port::host_name(state.text(script), state.text(function));
		++counts.host_calls[name];
		if (name == "ProfileLog.emit_general") {
			return Value();
		}
		if (name == "SessionStateStore.new_session_data" && count == 7) {
			return new_session_data(args);
		}
		throw st::ScriptError(name + ": a host call the match runner does not answer");
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
		print("ERROR: " + text);
	}
	void print_warning(const std::string &text) override {
		++counts.printed_warnings;
		print("WARNING: " + text);
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

private:
	// ------------------------------------------------------- the match

	// The scene's _play from the map's setup on.
	void match(const Settings &settings) {
		const std::string snapshot_text = strip(settings.get("HEROES_AI_MATCH_SNAPSHOT"));
		if (snapshot_text.empty()) {
			throw MatchFailed{ "HEROES_AI_MATCH_SNAPSHOT names no setup snapshot (the scene's HEROES_AI_MATCH_PREPARE writes them)." };
		}
		const fs::path snapshot = fs::u8path(snapshot_text);
		const std::string content_text = strip(settings.get("HEROES_AI_MATCH_CONTENT"));
		const fs::path content_path = content_text.empty() ? snapshot.parent_path() / "content.snap" : fs::u8path(content_text);
		const Content &content = contents_.get(content_path);
		std::unique_ptr<Store> match_store = cli::load_store(snapshot, types_);
		begin_match(content, *match_store);
		const Store &store = *match_store;
		const Value root = store.decoded.root;
		const Value setup = store.get(root, "setup");
		const Value packages = store.get(root, "packages");
		if (setup.kind != Kind::Dict || packages.kind != Kind::Dict) {
			fail(snapshot.string() + " is no setup snapshot: it needs setup and packages");
		}
		files_ = store.get(root, "files");
		const Value revision = store.get(root, "content_revision");
		content_revision_ = revision.kind == Kind::Int ? revision.i : 0;
		const std::string match_seed = store.text(store.get(root, "match_seed"));
		const std::string map_seed = store.text(store.get(root, "map_seed"));
		const std::string map_source = store.text(store.get(root, "map"));
		const std::string wanted_seed = strip(settings.get("HEROES_AI_MATCH_SEED"));
		if (!wanted_seed.empty() && wanted_seed != "random" && wanted_seed != match_seed) {
			throw MatchFailed{ "HEROES_AI_MATCH_SNAPSHOT " + snapshot_text + " holds match " + match_seed + ", not " + wanted_seed + "." };
		}
		// The project folder the scene ran in, with the packages it wrote in
		// their places.
		disk_ = std::make_unique<aurelion::rules::content::DiskFiles>(store.text(store.get(root, "project")), true);
		const st::DictNode &package_node = store.state.dict_node(packages.ref);
		for (size_t index = 0; index < package_node.keys.size(); ++index) {
			const Value bytes = package_node.values[index];
			if (bytes.kind != Kind::PackedByte) {
				fail(snapshot.string() + " holds a package that is no PackedByteArray");
			}
			const std::vector<uint8_t> &data = store.state.packed_node(bytes.ref).bytes;
			disk_->add(store.text(package_node.keys.list()[index]), std::string(data.begin(), data.end()));
		}
		scenario_id_ = store.text(store.get(store.get(store.get(setup, "package_startup"), "session_boundary_record"), "scenario_id"));

		start_session(import_deep(match_deep_, setup));
		hand_over(store, root, match_seed, map_seed);

		int64_t max_days = kDefaultMaxDays;
		if (!settings.get("HEROES_AI_MATCH_MAX_DAYS").empty()) {
			max_days = compat::to_int(settings.get("HEROES_AI_MATCH_MAX_DAYS"));
		}
		const std::string trace_setting = strip(settings.get("HEROES_AI_MATCH_TRACE"));
		const bool trace = !trace_setting.empty() && trace_setting != "0";
		const std::string digest_path = strip(settings.get("HEROES_AI_MATCH_DIGEST"));
		if (!digest_path.empty()) {
			digest_.open(fs::u8path(digest_path), std::ios::binary | std::ios::trunc);
			if (!digest_) {
				throw MatchFailed{ "HEROES_AI_MATCH_DIGEST " + digest_path + " cannot be written." };
			}
		}
		dump_path_ = strip(settings.get("HEROES_AI_MATCH_DUMP"));
		dump_day_ = -1;
		if (!dump_path_.empty() && !strip(settings.get("HEROES_AI_MATCH_DUMP_DAY")).empty()) {
			dump_day_ = compat::to_int(settings.get("HEROES_AI_MATCH_DUMP_DAY"));
			max_days = std::min(max_days, dump_day_);
		}
		blank_scopes_.clear();
		blank_fields_.clear();
		const std::string blank = settings.get("HEROES_AI_MATCH_DIGEST_BLANK");
		size_t start = 0;
		while (start <= blank.size()) {
			const size_t comma = std::min(blank.find(',', start), blank.size());
			if (comma > start) {
				const std::string item = strip(blank.substr(start, comma - start));
				if (item.rfind("overworld.", 0) == 0 || item.rfind("flags.", 0) == 0) {
					blank_scopes_.push_back(item);
				} else {
					blank_fields_.insert(item);
				}
			}
			start = comma + 1;
		}

		std::vector<std::string> ledger;
		std::vector<std::string> town_weeks;
		timeline_.clear();
		heroes_seen_ = gd::dict_value(state_.new_dict());
		captures_seen_ = 0;
		int64_t ai_ms_max = 0;
		std::string winner;
		const Json indented{ state_, "  ", true, false };
		town_weeks.push_back(indented.text(town_snapshot(), 2));
		last_row_ = day_row();
		ledger.push_back(indented.text(last_row_, 2));
		// session.set_meta(OverworldRules.SESSION_UNTOUCHED_BETWEEN_DAYS_META, true)
		state_.set(object_meta_.ref, gd::name_value(names_.untouched_meta), gd::bool_value(true));
		digest_day();
		while (day() < max_days) {
			compact();
			const Clock::time_point day_started = Clock::now();
			const Value turn = call_with_view(calls_.end_turn, {});
			ai_ms_max = std::max<int64_t>(ai_ms_max, std::chrono::duration_cast<std::chrono::milliseconds>(Clock::now() - day_started).count());
			++counts.days;
			if (text_of(field(kGameState)) != "overworld" || !gd::is_empty(state_, gd::as_dict(field(kBattle)))) {
				throw MatchFailed{ "Day " + compat::itos(day()) + " left the overworld (" + text_of(field(kGameState)) + ") with no human seat." };
			}
			digest_day();
			note_changes();
			if (trace) {
				print_trace();
			}
			const Value row = day_row();
			// Every hero decision of the day, with the alternatives it weighed.
			const gd::DictRef flags = gd::as_dict(field(kFlags));
			state_.set(row.ref, gd::str(names_.decisions), state_.get(flags, gd::str(names_.decision_log), gd::array_value(state_.new_array())));
			state_.set(flags, gd::str(names_.decision_log), gd::array_value(state_.new_array()));
			// Where each computer player's turn went, in milliseconds by phase.
			const Value profile = get(turn, names_.enemy_turn_profile, gd::dict_value(state_.new_dict()));
			const Value sides = get(row, names_.sides);
			for (const Value &faction_profile : gd::items(state_, get(profile, names_.factions, gd::array_value(state_.new_array())))) {
				if (faction_profile.kind != Kind::Dict) {
					continue;
				}
				const Value player = gd::str(gd::stringify(state_, get(faction_profile, names_.player_id, state_.string(""))));
				if (state_.has(sides.ref, player)) {
					state_.set(gd::as_dict(state_.get(sides.ref, player, Value())), gd::str(names_.turn_ms), get(faction_profile, names_.phases_ms, gd::dict_value(state_.new_dict())));
				}
			}
			ledger.push_back(indented.text(row, 2));
			last_row_ = row;
			if (day() % 7 == 1) {
				town_weeks.push_back(indented.text(town_snapshot(), 2));
			}
			if (match_over()) {
				const std::vector<uint32_t> standing = standing_players();
				winner = standing.empty() ? "none" : state_.text(standing.front());
				break;
			}
		}

		const Value battles = state_.get(gd::as_dict(field(kFlags)), gd::str(names_.battle_log), gd::array_value(state_.new_array()));
		const uint32_t heroes = state_.new_array();
		for (const Value &value : state_.dict(heroes_seen_.ref).values) {
			state_.append(heroes, value);
		}
		std::string record = "{\n";
		const auto entry = [&](const char *name, const std::string &text) {
			if (record.size() > 2) {
				record += ",\n";
			}
			record += "  ";
			append_json_string(record, name);
			record += ": " + text;
		};
		const auto fragments = [&](const std::vector<std::string> &items) {
			std::string out;
			indented.list(out, items.size(), 1, [&](size_t index) { out += items[index]; });
			return out;
		};
		entry("ai_turn_ms_max", compat::itos(ai_ms_max));
		entry("battles", indented.text(battles, 1));
		entry("day_cap", compat::itos(max_days));
		entry("decided", winner.empty() ? "false" : "true");
		entry("final_day", compat::itos(day()));
		entry("heroes", indented.text(gd::array_value(heroes), 1));
		entry("ledger", fragments(ledger));
		std::string report_id;
		append_json_string(report_id, kReportId);
		entry("report_id", report_id);
		entry("setup", indented.text(setup_, 1));
		entry("timeline", fragments(timeline_));
		entry("town_weeks", fragments(town_weeks));
		std::string winner_text;
		append_json_string(winner_text, winner);
		entry("winner", winner_text);
		record += "\n}";
		std::ofstream file(fs::u8path(out_path_), std::ios::binary | std::ios::trunc);
		if (file) {
			file << record;
		}

		const uint32_t summary = state_.new_dict();
		const auto put = [&](const char *name, const Value &value) { state_.set(summary, state_.string(name), value); };
		put("ok", gd::bool_value(true));
		put("match_seed", state_.string(match_seed));
		put("map_seed", state_.string(map_seed));
		const uint32_t factions = state_.new_array();
		for (const Value &seat : gd::items(state_, get(setup_, state_.intern("seats"), gd::array_value(state_.new_array())))) {
			state_.append(factions, get(seat, names_.faction_id));
		}
		put("factions", gd::array_value(factions));
		put("handover", handover_);
		put("winner", state_.string(winner));
		put("winner_faction", winner.empty() || winner == "none" ? state_.string("") : gd::str(players::faction_id(state_, make_view(), state_.intern(winner))));
		put("final_day", gd::int_value(day()));
		put("battles", gd::int_value(battles.kind == Kind::Array ? state_.array_size(battles.ref) : 0));
		put("timeline_events", gd::int_value(static_cast<int64_t>(timeline_.size())));
		put("ai_turn_ms_max", gd::int_value(ai_ms_max));
		put("final", last_row_);
		put("out", state_.string(out_text_));
		put("seconds", gd::float_value(seconds()));
		put("map", state_.string(map_source));
		print(std::string(kReportId) + " " + Json{ state_, "", true, false }.text(gd::dict_value(summary)));
	}

	// The scene's _fail: the error, and a report line that says it failed.
	void report_failure(const std::string &message) {
		print("ERROR: " + message);
		const uint32_t summary = state_.new_dict();
		state_.set(summary, state_.string("ok"), gd::bool_value(false));
		state_.set(summary, state_.string("error"), state_.string(message));
		state_.set(summary, state_.string("out"), state_.string(out_text_));
		state_.set(summary, state_.string("seconds"), gd::float_value(seconds()));
		print(std::string(kReportId) + " " + Json{ state_, "", true, false }.text(gd::dict_value(summary)));
	}

	double seconds() const {
		const int64_t ms = std::chrono::duration_cast<std::chrono::milliseconds>(Clock::now() - started_).count();
		return compat::snappedf(static_cast<double>(ms) / 1000.0, 0.1);
	}

	void print(const std::string &line) {
		if (lines_ != nullptr) {
			*lines_ += line;
			*lines_ += '\n';
		}
	}

	void begin_match(const Content &content, const Store &match_store) {
		if (state_.atom_count() > kAtomLimit) {
			state_.clear();
			content_rows_.forget_atoms();
			content_deep_.forget_atoms();
			names_.make(state_);
		} else {
			state_.clear_nodes();
		}
		types_.sync(state_, known_types_);
		if (content_ != &content) {
			content_ = &content;
			content_rows_.bind(content.store.get());
			content_deep_.bind(content.store.get());
		}
		match_store_ = &match_store;
		match_rows_.bind(&match_store);
		match_deep_.bind(&match_store);
		if (++epoch_ == 0) {
			content_rows_.forget_nodes();
			content_deep_.forget_nodes();
			epoch_ = 1;
		}
		array_sources_.clear();
		dict_sources_.clear();
		packed_sources_.clear();
		statics_.clear();
		opaques_.clear();
		Opaque session;
		session.what = "SessionData";
		opaques_.push_back(session);
		map_documents_.clear();
		scenario_documents_.clear();
		disk_.reset();
		scenario_id_.clear();
		view_node_ = ~0u;
		object_ = object_meta_ = instance_id_ = setup_ = handover_ = heroes_seen_ = last_row_ = Value();
	}

	Value new_opaque(const std::string &what) {
		Opaque made;
		made.what = what;
		opaques_.push_back(made);
		return Value::of_ref(Kind::Opaque, static_cast<uint32_t>(opaques_.size() - 1));
	}

	// ------------------------------------------------------ the new session

	// The scene's _start_session from the map's setup:
	// ScenarioSelectRules.start_random_map_skirmish_session_from_setup loads
	// the packages, adopts them into a new SessionData and normalizes it, and
	// the scene normalizes it once more.
	void start_session(const Value &setup) {
		state_.drop_memo();
		const Value session = calls_.start_session->call(state_, &setup);
		if (view_node_ != ~0u) {
			take_view(view_node_);
		}
		// The documents are the setup's: nothing holds them after it.
		map_documents_.clear();
		scenario_documents_.clear();
		if (session.kind != Kind::Opaque || session.ref != 0 || object_.kind != Kind::Dict || text_of(field(2)) == "") {
			throw MatchFailed{ "The generated session could not start." };
		}
		call_with_view(calls_.normalize, {});
	}

	// SessionStateStore.new_session_data: SessionData.new(session_id,
	// scenario_id, hero_id, day, overworld_state, difficulty, launch_mode), the
	// session object, slot 0: its fields as SessionData._init sets them (the
	// clock's milliseconds for an empty session id, the launch mode one of
	// SUPPORTED_LAUNCH_MODES, the overworld state copied deep) and no metadata.
	Value new_session_data(const Value *args) {
		const auto text = [&](const Value &value) { return gd::str(gd::to_string(value)); };
		Value session_id = text(args[0]);
		if (state_.text(session_id.ref).empty()) {
			session_id = state_.string(compat::itos(gd::engine_ticks_msec(state_)));
		}
		Value launch_mode = text(args[6]);
		const std::string &mode = state_.text(launch_mode.ref);
		if (mode != "campaign" && mode != "skirmish" && mode != "generated_draft") {
			launch_mode = state_.string("campaign");
		}
		const Value values[kFieldCount] = {
			gd::int_value(9),
			session_id,
			text(args[1]),
			text(args[2]),
			gd::int_value(gd::to_int(state_, args[3])),
			text(args[5]),
			launch_mode,
			state_.string("overworld"),
			state_.string("in_progress"),
			state_.string(""),
			args[4].kind == Kind::Dict ? gd::dict_value(gd::deep_duplicate_dict(state_, args[4].ref)) : gd::dict_value(state_.new_dict()),
			gd::dict_value(state_.new_dict()),
			gd::dict_value(state_.new_dict()),
		};
		object_ = gd::dict_value(state_.new_dict());
		for (size_t index = 0; index < kFieldCount; ++index) {
			state_.set(object_.ref, gd::str(names_.fields[index]), values[index]);
		}
		object_meta_ = gd::dict_value(state_.new_dict());
		instance_id_ = gd::int_value(1);
		view_node_ = ~0u;
		return Value::of_ref(Kind::Opaque, 0);
	}

	// ContentService.canonical_town_id(id): a retired town id's alias.
	Value canonical_town_id(State &state, uint32_t id) {
		const Value towns = content_file(state, state.intern(aurelion::rules::content::kTownsPath));
		const Value aliases = get(towns, state.intern("legacy_aliases"), Value());
		Value alias;
		if (aliases.kind != Kind::Dict || !state.lookup(aliases.ref, gd::str(id), alias)) {
			return gd::str(id);
		}
		return gd::str(gd::to_string(alias));
	}

	// The scene's _play from the session's start to the match: the seats, the
	// human seat handed to the computer, the battle log, the seats' weight
	// sets, the handover's check and the record's setup.
	void hand_over(const Store &store, const Value &root, const std::string &match_seed, const std::string &map_seed) {
		const auto setting = [&](const char *name) { return import_deep(match_deep_, store.get(root, name)); };
		const int64_t player_count = gd::to_int(state_, setting("player_count"));
		const Value seat_factions = setting("seat_factions");
		const Value seat_weights = setting("seat_weights");
		seats_.clear();
		for (const Value &record : gd::items(state_, overworld_list(names_.players))) {
			seats_.push_back(string_of(get(record, names_.player_id, state_.string(""))));
		}
		if (static_cast<int64_t>(seats_.size()) != player_count) {
			const uint32_t listed = state_.new_array();
			for (const uint32_t seat : seats_) {
				state_.append(listed, gd::str(seat));
			}
			throw MatchFailed{ "Expected a " + compat::itos(player_count) + "-player map, got " + Json{ state_, "", true, false }.text(gd::array_value(listed)) + "." };
		}
		const Value resources = state_.get(overworld(), state_.string("resources"), gd::dict_value(state_.new_dict()));
		const Value start_treasury = gd::dict_value(gd::deep_duplicate_dict(state_, gd::as_dict(resources)));
		if (hand_human_seat_to_ai() != seats_.front()) {
			throw MatchFailed{ "The human seat could not be handed to the computer." };
		}
		// AiHeroRules.BATTLE_LOG_FLAG, and each seat's WEIGHT_SET_KEY when it
		// plays another set than DEFAULT_WEIGHT_SET.
		state_.set(gd::as_dict(field(kFlags)), state_.string("ai_battle_log_enabled"), gd::bool_value(true));
		const int64_t weighted = seat_weights.kind == Kind::Array ? state_.array_size(seat_weights.ref) : 0;
		for (int64_t index = 0; index < weighted; ++index) {
			const uint32_t weight_set = string_of(get(state_.at(seat_weights.ref, index), state_.intern("set")));
			if (state_.text(weight_set) != "default") {
				state_.set(gd::as_dict(seat_state(seats_[static_cast<size_t>(index)])), state_.string("ai_weight_set"), gd::str(weight_set));
			}
		}
		handover_ = check_handover(seat_factions, start_treasury);

		const uint32_t record = state_.new_dict();
		const auto put = [&](gd::DictRef dict, const char *name, const Value &value) { state_.set(dict, state_.string(name), value); };
		put(record, "match_seed", state_.string(match_seed));
		put(record, "map_seed", state_.string(map_seed));
		put(record, "swapped", setting("swapped"));
		put(record, "scenario_id", gd::str(string_of(field(2))));
		put(record, "map_size", state_.get(overworld(), state_.string("map_size"), gd::dict_value(state_.new_dict())));
		put(record, "guards", setting("guards"));
		put(record, "water", setting("water"));
		put(record, "levels", setting("levels"));
		put(record, "start_treasury", live_resources(start_treasury));
		const uint32_t seat_rows = state_.new_array();
		put(record, "seats", gd::array_value(seat_rows));
		for (size_t index = 0; index < seats_.size(); ++index) {
			const uint32_t faction_id = players::faction_id(state_, make_view(), seats_[index]);
			const gd::DictRef faction = gd::content_row(state_, st::ContentTable::Faction, faction_id);
			const uint32_t capitals = state_.new_array();
			for (const Value &town : towns_of(seats_[index])) {
				const uint32_t capital = state_.new_dict();
				put(capital, "placement_id", gd::str(string_of(get(town, names_.placement_id, state_.string("")))));
				put(capital, "name", gd::str(string_of(town_name(town))));
				put(capital, "x", gd::int_value(int_of(town, names_.x, 0)));
				put(capital, "y", gd::int_value(int_of(town, names_.y, 0)));
				state_.append(capitals, gd::dict_value(capital));
			}
			const uint32_t row = state_.new_dict();
			put(row, "player_id", gd::str(seats_[index]));
			put(row, "faction_id", gd::str(faction_id));
			put(row, "faction", gd::str(string_of(state_.get(faction, gd::str(names_.name), state_.string("")))));
			put(row, "towns", gd::array_value(capitals));
			if (weighted != 0) {
				put(row, "weights", state_.at(seat_weights.ref, static_cast<int64_t>(index)));
			}
			state_.append(seat_rows, gd::dict_value(row));
		}
		view_node_ = ~0u;
		setup_ = gd::dict_value(record);
	}

	// AiSeatRules.hand_human_seat_to_ai(session): the human seat's player, its
	// towns and its treasury become the computer's; the seat, or "" when there
	// is no human seat. Its GDScript calls the native normalize; here all of it
	// runs on one view.
	uint32_t hand_human_seat_to_ai() {
		const gd::DictRef view = make_view();
		state_.drop_memo();
		const auto overworld_of = [&] { return gd::as_dict(state_.get(view, gd::str(names_.overworld), Value())); };
		const auto value_of = [&](const char *name, const Value &fallback) { return state_.get(overworld_of(), state_.string(name), fallback); };
		uint32_t seat = key::empty;
		if (players::has_human_seat(state_, view)) {
			seat = string_of(value_of("active_player_id", state_.string("")));
			const Value records = value_of("players", gd::array_value(state_.new_array()));
			bool found = false;
			for (const Value &record : gd::items(state_, records)) {
				if (record.kind == Kind::Dict && string_of(get(record, names_.player_id, state_.string(""))) == seat) {
					state_.set(record.ref, state_.string("human"), gd::bool_value(false));
					state_.set(record.ref, state_.string("computer"), gd::bool_value(true));
					state_.set(record.ref, gd::str(names_.owner), gd::str(names_.enemy));
					found = true;
				}
			}
			if (!found) {
				seat = key::empty;
			}
		}
		if (seat != key::empty) {
			const gd::ArrayRef towns = gd::duplicate_array(state_, gd::as_array(value_of("towns", gd::array_value(state_.new_array()))));
			for (const Value &town : gd::items(state_, gd::array_value(towns))) {
				if (town.kind == Kind::Dict && state_.text(string_of(get(town, names_.owner, state_.string("")))) == "player") {
					port::overworld_rules::transition_town_control(state_, view, string_of(get(town, names_.placement_id, state_.string(""))), names_.enemy, seat,
							state_.intern("ai_seat"));
				}
			}
			const Value treasury = gd::dict_value(gd::deep_duplicate_dict(state_, gd::as_dict(value_of("resources", gd::dict_value(state_.new_dict())))));
			const uint32_t emptied = state_.new_dict();
			for (const char *name : { "gold", "wood", "ore" }) {
				state_.set(emptied, state_.string(name), gd::int_value(0));
			}
			state_.set(overworld_of(), state_.string("resources"), gd::dict_value(emptied));
			state_.set(overworld_of(), state_.string("player_heroes"), gd::array_value(state_.new_array()));
			state_.set(overworld_of(), state_.string("active_hero_id"), state_.string(""));
			state_.set(view, gd::str(names_.fields[3]), state_.string(""));
			port::overworld_rules::normalize_overworld_state(state_, view);
			for (const Value &entry : gd::items(state_, value_of("enemy_states", gd::array_value(state_.new_array())))) {
				if (entry.kind == Kind::Dict && players::controller_id(state_, entry.ref, key::empty) == seat) {
					state_.set(entry.ref, gd::str(names_.treasury), treasury);
				}
			}
			port::overworld_rules::invalidate_spatial_lookup(state_, view);
		}
		take_view(view);
		return seat;
	}

	// The scene's _check_handover: no human seat or hero is left, and each seat
	// has its computer player state, its drawn faction, a town and the start
	// treasury; {seat: {faction, towns}}.
	Value check_handover(const Value &drawn, const Value &start_treasury) {
		if (players::has_human_seat(state_, make_view())) {
			throw MatchFailed{ "A human seat is left after the handover." };
		}
		if (state_.array_size(gd::as_array(overworld_list(state_.intern("player_heroes")))) != 0) {
			throw MatchFailed{ "Human heroes are left after the handover." };
		}
		const Json compact_json{ state_, "", true, false };
		const uint32_t result = state_.new_dict();
		for (size_t index = 0; index < seats_.size(); ++index) {
			const uint32_t seat = seats_[index];
			const std::string seat_text = state_.text(seat);
			const Value seat_state_value = seat_state(seat);
			if (gd::is_empty(state_, seat_state_value.ref)) {
				throw MatchFailed{ seat_text + " has no computer player state." };
			}
			const uint32_t faction_id = players::faction_id(state_, make_view(), seat);
			const uint32_t wanted = string_of(drawn.kind == Kind::Array ? state_.at(drawn.ref, static_cast<int64_t>(index)) : Value());
			if (faction_id != wanted) {
				throw MatchFailed{ seat_text + " plays " + state_.text(faction_id) + ", not the drawn " + state_.text(wanted) + "." };
			}
			const st::ValueList towns = towns_of(seat);
			if (towns.empty()) {
				throw MatchFailed{ seat_text + " holds no town." };
			}
			const Value treasury = get(seat_state_value, names_.treasury, gd::dict_value(state_.new_dict()));
			if (!gd::equal(state_, live_resources(treasury), live_resources(start_treasury))) {
				throw MatchFailed{ seat_text + " starts with " + compact_json.text(treasury) + ", not " + compact_json.text(start_treasury) + "." };
			}
			const uint32_t row = state_.new_dict();
			state_.set(row, gd::str(names_.faction), gd::str(wanted));
			state_.set(row, gd::str(names_.towns), gd::int_value(static_cast<int64_t>(towns.size())));
			state_.set(result, gd::str(seat), gd::dict_value(row));
		}
		view_node_ = ~0u;
		return gd::dict_value(result);
	}

	// ---------------------------------------------------- the session object

	const Value &field(size_t index) const {
		static const Value nil;
		const st::DictNode &node = state_.dict(object_.ref);
		return index < node.values.size() ? node.values[index] : nil;
	}
	int64_t day() const { return gd::to_int(state_, field(kDay)); }
	std::string text_of(const Value &value) const { return value.is_string_like() ? state_.text(value.ref) : std::string(); }

	// DayEngine._view: the session's fields, a new Dictionary of its metadata
	// and its instance id, a new view for each native call.
	gd::DictRef make_view() {
		const uint32_t view = state_.new_dict();
		for (size_t index = 0; index < kFieldCount; ++index) {
			state_.set(view, gd::str(names_.fields[index]), field(index));
		}
		const uint32_t meta = state_.new_dict();
		const st::DictNode &from = state_.dict(object_meta_.ref);
		const st::ValueList keys = from.keys.list();
		const st::ValueList values = from.values;
		for (size_t index = 0; index < keys.size(); ++index) {
			state_.set(meta, keys[index], values[index]);
		}
		state_.set(view, gd::str(names_.meta), gd::dict_value(meta));
		state_.set(view, gd::str(names_.instance_id), instance_id_);
		view_node_ = view;
		return view;
	}

	// DayEngine._take_views: the session takes its view's fields back (each as
	// its typed property converts it) and its metadata.
	void take_view(gd::DictRef view) {
		for (size_t index = 0; index < kFieldCount; ++index) {
			const Value value = state_.get(view, gd::str(names_.fields[index]), Value());
			if (!gd::is_same(state_, field(index), value)) {
				state_.set(object_.ref, gd::str(names_.fields[index]), coerce(index, value));
			}
		}
		const Value meta = state_.get(view, gd::str(names_.meta), Value());
		if (meta.kind != Kind::Dict) {
			throw st::ScriptError("the native call left the session view's meta no Dictionary");
		}
		const st::ValueList had = state_.dict(object_meta_.ref).keys.list();
		for (const Value &name : had) {
			if (!state_.has(meta.ref, name)) {
				state_.erase(object_meta_.ref, name);
			}
		}
		const st::ValueList keys = state_.dict(meta.ref).keys.list();
		const st::ValueList values = state_.dict(meta.ref).values;
		for (size_t index = 0; index < keys.size(); ++index) {
			Value old;
			const bool present = state_.lookup(object_meta_.ref, keys[index], old);
			if (values[index].kind == Kind::Nil) {
				// set_meta(name, null) removes it.
				state_.erase(object_meta_.ref, keys[index]);
			} else if (!present || !gd::is_same(state_, old, values[index])) {
				state_.set(object_meta_.ref, present ? keys[index] : gd::name_value(gd::to_string(keys[index])), values[index]);
			}
		}
		view_node_ = ~0u;
	}

	// session.set(field, value) of a typed property: the value as the
	// property's type constructs it, or the old one when it cannot.
	Value coerce(size_t index, const Value &value) {
		switch (kFieldTypes[index]) {
			case 'i':
				if (value.kind == Kind::Int) {
					return value;
				}
				if (value.kind == Kind::Float && std::isfinite(value.f)) {
					return gd::int_value(static_cast<int64_t>(value.f));
				}
				if (value.kind == Kind::Bool) {
					return gd::int_value(value.b ? 1 : 0);
				}
				break;
			case 's':
				if (value.kind == Kind::String) {
					return value;
				}
				if (value.kind == Kind::StringName) {
					return gd::str(value.ref);
				}
				break;
			default:
				if (value.kind == Kind::Dict) {
					return value;
				}
				break;
		}
		print("WARNING: SessionData." + std::string(kSessionFields[index]) + " takes no " + gd::type_name(value) + "; it keeps its value.");
		return field(index);
	}

	// A top-level native call, as GDScript's switch makes one; the session is
	// the first argument, as a view (DayEngine.native_writing).
	Value call_with_view(const port::Function *function, std::initializer_list<Value> rest) {
		std::vector<Value> args;
		const gd::DictRef view = make_view();
		args.push_back(gd::dict_value(view));
		args.insert(args.end(), rest.begin(), rest.end());
		state_.drop_memo();
		const Value result = function->call(state_, args.data());
		take_view(view);
		return result;
	}
	Value call(const port::Function *function, std::initializer_list<Value> args) {
		state_.drop_memo();
		return function->call(state_, args.begin());
	}

	// What nothing holds any more goes, after each day as the game's kept
	// session drops it (PortBridge::keep), and each node is as loaded again:
	// watched, not frozen, with no memo (State::compact).
	void compact() {
		std::vector<Value> roots = { object_, object_meta_, instance_id_, setup_, handover_, heroes_seen_, last_row_, Value::of_ref(Kind::Opaque, 0) };
		for (const auto &[slot, value] : statics_) {
			roots.push_back(value);
		}
		// The content rows and files handed out stay, as the game keeps them.
		for (StoreMap *map : { &content_rows_, &match_rows_ }) {
			const auto handed = [&](const std::vector<uint64_t> &nodes, Kind kind) {
				for (const uint64_t slot : nodes) {
					if ((slot >> 32) == epoch_) {
						const uint32_t node = static_cast<uint32_t>(slot);
						roots.push_back(Value::of_ref(kind == Kind::PackedByte ? state_.packed_node(node).kind : kind, node));
					}
				}
			};
			handed(map->arrays, Kind::Array);
			handed(map->dicts, Kind::Dict);
			handed(map->packeds, Kind::PackedByte);
		}
		const st::State::Compaction maps = state_.compact(roots, opaques_.size());
		const auto renumber = [&](Value &value) {
			if (value.kind == Kind::Array) {
				value.ref = maps.arrays[value.ref];
			} else if (value.kind == Kind::Dict) {
				value.ref = maps.dicts[value.ref];
			} else if (value.is_packed()) {
				value.ref = maps.packeds[value.ref];
			} else if (value.kind == Kind::Opaque) {
				value.ref = maps.opaques[value.ref];
			}
		};
		for (Value *value : { &object_, &object_meta_, &instance_id_, &setup_, &handover_, &heroes_seen_, &last_row_ }) {
			renumber(*value);
		}
		for (auto &[slot, value] : statics_) {
			renumber(value);
		}
		renumber_sources(array_sources_, maps.arrays, state_.array_count());
		renumber_sources(dict_sources_, maps.dicts, state_.dict_count());
		renumber_sources(packed_sources_, maps.packeds, state_.packed_count());
		for (StoreMap *map : { &content_rows_, &content_deep_, &match_rows_, &match_deep_ }) {
			renumber_map(map->arrays, maps.arrays);
			renumber_map(map->dicts, maps.dicts);
			renumber_map(map->packeds, maps.packeds);
		}
		size_t kept = 0;
		for (size_t slot = 0; slot < maps.opaques.size(); ++slot) {
			if (maps.opaques[slot] != st::State::kDropped) {
				if (kept != slot) {
					opaques_[kept] = std::move(opaques_[slot]);
				}
				++kept;
			}
		}
		opaques_.resize(kept);
		view_node_ = ~0u;
	}

	static void renumber_sources(std::vector<Source> &sources, const std::vector<uint32_t> &map, size_t count) {
		std::vector<Source> next(count);
		const size_t end = std::min(sources.size(), map.size());
		for (size_t node = 0; node < end; ++node) {
			if (map[node] != st::State::kDropped) {
				next[map[node]] = sources[node];
			}
		}
		sources.swap(next);
	}
	void renumber_map(std::vector<uint64_t> &nodes, const std::vector<uint32_t> &map) const {
		for (uint64_t &slot : nodes) {
			if ((slot >> 32) != epoch_) {
				continue;
			}
			const uint32_t node = static_cast<uint32_t>(slot);
			const uint32_t to = node < map.size() ? map[node] : st::State::kDropped;
			slot = to == st::State::kDropped ? 0 : (static_cast<uint64_t>(epoch_) << 32 | to);
		}
	}

	// --------------------------------------------- the scene's GDScript

	// d.get(key, fallback) of a Dictionary value; Nil of anything else.
	Value get(const Value &dict, uint32_t name, const Value &fallback = Value()) const {
		return dict.kind == Kind::Dict ? state_.get(dict.ref, gd::str(name), fallback) : Value();
	}
	gd::DictRef overworld() const { return gd::as_dict(field(kOverworld)); }
	Value overworld_list(uint32_t name) {
		return state_.get(overworld(), gd::str(name), gd::array_value(state_.new_array()));
	}
	uint32_t string_of(const Value &value) { return gd::stringify(state_, value); }

	double army_power(const Value &stacks) {
		return gd::to_float(call(calls_.army_power, { stacks, gd::dict_value(state_.new_dict()) }));
	}
	double hero_power(const Value &entry) {
		return gd::to_float(call(calls_.hero_power, { entry }));
	}
	Value hero_name(const Value &entry) {
		return call(calls_.hero_name, { entry });
	}
	Value town_name(const Value &town) {
		return call(calls_.town_name, { town });
	}
	st::ValueList active_hero_entries(uint32_t seat) {
		const Value entries = call_with_view(calls_.active_hero_entries, { gd::str(seat) });
		return state_.array(gd::as_array(entries)).items;
	}

	// _state: the seat's computer player state, {} without one.
	Value seat_state(uint32_t seat) {
		for (const Value &entry : gd::items(state_, overworld_list(names_.enemy_states))) {
			if (entry.kind == Kind::Dict && players::controller_id(state_, entry.ref, key::empty) == seat) {
				return entry;
			}
		}
		return gd::dict_value(state_.new_dict());
	}
	st::ValueList towns_of(uint32_t seat) {
		st::ValueList result;
		for (const Value &town : gd::items(state_, overworld_list(names_.towns))) {
			if (town.kind == Kind::Dict && string_of(get(town, names_.owner, state_.string(""))) == names_.enemy && players::town_controller_id(state_, town.ref) == seat) {
				result.push_back(town);
			}
		}
		return result;
	}
	Value town_by_placement(uint32_t placement_id) {
		for (const Value &town : gd::items(state_, overworld_list(names_.towns))) {
			if (town.kind == Kind::Dict && string_of(get(town, names_.placement_id, state_.string(""))) == placement_id) {
				return town;
			}
		}
		return gd::dict_value(state_.new_dict());
	}
	Value live_resources(const Value &pool) {
		const uint32_t result = state_.new_dict();
		if (pool.kind == Kind::Dict) {
			const st::ValueList keys = state_.dict(pool.ref).keys.list();
			for (const Value &name : keys) {
				const int64_t amount = gd::to_int(state_, state_.get(pool.ref, name, Value()));
				if (amount != 0) {
					state_.set(result, gd::str(string_of(name)), gd::int_value(amount));
				}
			}
		}
		return gd::dict_value(result);
	}
	int64_t int_of(const Value &dict, uint32_t name, int64_t fallback) {
		return gd::to_int(state_, get(dict, name, gd::int_value(fallback)));
	}
	// AiHeroRules.explored_tile_count(state): the set bits of level 0's map.
	int64_t explored_tile_count(const Value &seat_state) {
		const Value stored = get(seat_state, names_.explored_key, gd::dict_value(state_.new_dict()));
		const uint32_t encoded = stored.kind == Kind::Dict ? string_of(state_.get(stored.ref, gd::str(names_.zero), state_.string(""))) : key::empty;
		if (encoded == key::empty) {
			return 0;
		}
		const gd::PackedRef bytes = gd::base64_to_raw(state_, encoded);
		const uint8_t *data = gd::packed_bytes(state_, bytes);
		int64_t count = 0;
		for (int64_t index = 0; index < gd::packed_size(state_, bytes); ++index) {
			for (uint32_t bits = data[index]; bits != 0; bits >>= 1) {
				count += bits & 1;
			}
		}
		return count;
	}

	// _digest_day: the session's digest line, and its dump on the dump day.
	void digest_day() {
		if (!digest_.is_open() && dump_day_ != day()) {
			return;
		}
		const std::vector<Value> parts = state_parts();
		if (digest_.is_open()) {
			std::string line = compat::itos(day()) + "\t";
			for (const Value &part : parts) {
				char hex[16];
				std::snprintf(hex, sizeof(hex), "%08x", static_cast<unsigned>(static_cast<uint32_t>(gd::hash(state_, part))));
				line += hex;
			}
			line += '\n';
			digest_ << line;
			digest_.flush();
		}
		if (dump_day_ == day()) {
			const gd::DictRef dumped = gd::duplicate_dict(state_, parts[0].ref);
			state_.set(dumped, gd::str(names_.overworld), parts[1]);
			state_.set(dumped, gd::str(names_.battle), parts[2]);
			state_.set(dumped, gd::str(names_.flags), parts[3]);
			std::ofstream dump(fs::u8path(dump_path_), std::ios::binary | std::ios::trunc);
			if (dump) {
				dump << Json{ state_, "", false, true }.text(gd::dict_value(dumped));
			}
		}
	}

	// _state_parts: the header fields, overworld, battle and flags, blanked as
	// asked.
	std::vector<Value> state_parts() {
		Value overworld_part = field(kOverworld);
		Value flags_part = field(kFlags);
		if (!blank_scopes_.empty()) {
			overworld_part = gd::dict_value(gd::duplicate_dict(state_, gd::as_dict(overworld_part)));
			flags_part = gd::dict_value(gd::duplicate_dict(state_, gd::as_dict(flags_part)));
			for (const std::string &scope : blank_scopes_) {
				const gd::DictRef part = scope.rfind("overworld.", 0) == 0 ? overworld_part.ref : flags_part.ref;
				const size_t dot = scope.find('.');
				const std::string name = scope.substr(dot + 1, scope.find('.', dot + 1) - dot - 1);
				const Value child = state_.get(part, state_.string(name), Value());
				if (child.kind == Kind::Dict) {
					state_.set(part, state_.string(name), blanked(child.ref));
				}
			}
		}
		const uint32_t header = state_.new_dict();
		for (const uint32_t name : { names_.day, names_.session_id, names_.scenario_id, names_.game_state, names_.scenario_status, names_.scenario_summary }) {
			state_.set(header, gd::str(name), state_.get(object_.ref, gd::str(name), Value()));
		}
		return { gd::dict_value(header), overworld_part, field(kBattle), flags_part };
	}

	// _blanked: a copy with every blanked field "", in nested Dictionaries.
	Value blanked(gd::DictRef value) {
		const uint32_t out = state_.new_dict();
		const st::ValueList keys = state_.dict(value).keys.list();
		const st::ValueList values = state_.dict(value).values;
		for (size_t index = 0; index < keys.size(); ++index) {
			if (blank_fields_.count(state_.text(string_of(keys[index]))) != 0) {
				state_.set(out, keys[index], state_.string(""));
			} else if (values[index].kind == Kind::Dict) {
				state_.set(out, keys[index], blanked(values[index].ref));
			} else {
				state_.set(out, keys[index], values[index]);
			}
		}
		return gd::dict_value(out);
	}

	// _note_changes: town captures, hires and fallen heroes since yesterday.
	void note_changes() {
		const Json indented{ state_, "  ", true, false };
		const Value captures = state_.get(gd::as_dict(field(kFlags)), gd::str(names_.capture_log), gd::array_value(state_.new_array()));
		const int64_t capture_count = state_.array_size(gd::as_array(captures));
		for (int64_t index = captures_seen_; index < capture_count; ++index) {
			const Value logged = state_.at(captures.ref, index);
			gd::as_dict(logged);
			const Value town = town_by_placement(string_of(get(logged, names_.town_placement_id, state_.string(""))));
			const uint32_t event = state_.new_dict();
			state_.set(event, gd::str(names_.day), gd::int_value(int_of(logged, names_.day, 0)));
			state_.set(event, gd::str(names_.type), gd::str(names_.town_captured));
			state_.set(event, gd::str(names_.town), gd::str(string_of(get(logged, names_.town, state_.string("")))));
			state_.set(event, gd::str(names_.x), gd::int_value(int_of(town, names_.x, 0)));
			state_.set(event, gd::str(names_.y), gd::int_value(int_of(town, names_.y, 0)));
			state_.set(event, gd::str(names_.from), gd::str(string_of(get(logged, names_.from, state_.string("")))));
			state_.set(event, gd::str(names_.to), gd::str(string_of(get(logged, names_.player_id, state_.string("")))));
			state_.set(event, gd::str(names_.hero), gd::str(string_of(get(logged, names_.hero, state_.string("")))));
			state_.set(event, gd::str(names_.hero_power), gd::float_value(compat::snappedf(gd::to_float(get(logged, names_.hero_power, gd::float_value(0.0))), 0.1)));
			state_.set(event, gd::str(names_.garrison_power), gd::float_value(compat::snappedf(gd::to_float(get(logged, names_.garrison_power, gd::float_value(0.0))), 0.1)));
			timeline_.push_back(indented.text(gd::dict_value(event), 2));
		}
		captures_seen_ = capture_count;
		// Fallen heroes stay in the encounter list, marked resolved, so a hero
		// hired and beaten on one day is still seen.
		const Value resolved = overworld_list(names_.resolved_encounters);
		const st::ValueList encounters = state_.array(gd::as_array(overworld_list(names_.encounters))).items;
		for (const Value &entry : encounters) {
			if (entry.kind != Kind::Dict || get(entry, names_.ai_hero).kind != Kind::Dict) {
				continue;
			}
			const uint32_t seat = players::raid_controller_id(state_, entry.ref);
			if (std::find(seats_.begin(), seats_.end(), seat) == seats_.end()) {
				continue;
			}
			const uint32_t placement_id = string_of(get(entry, names_.placement_id, state_.string("")));
			const Value commander = get(entry, names_.enemy_commander_state, gd::dict_value(state_.new_dict()));
			gd::as_dict(commander);
			if (!state_.has(heroes_seen_.ref, gd::str(placement_id))) {
				const uint32_t seen = state_.new_dict();
				state_.set(seen, gd::str(names_.placement_id), gd::str(placement_id));
				state_.set(seen, gd::str(names_.player_id), gd::str(seat));
				state_.set(seen, gd::str(names_.hero), hero_name(entry));
				state_.set(seen, gd::str(names_.hired_day), gd::int_value(day()));
				state_.set(seen, gd::str(names_.fell_day), gd::int_value(0));
				state_.set(heroes_seen_.ref, gd::str(placement_id), gd::dict_value(seen));
				const uint32_t event = state_.new_dict();
				state_.set(event, gd::str(names_.day), gd::int_value(day()));
				state_.set(event, gd::str(names_.type), gd::str(names_.hero_hired));
				state_.set(event, gd::str(names_.player_id), gd::str(seat));
				state_.set(event, gd::str(names_.hero), hero_name(entry));
				timeline_.push_back(indented.text(gd::dict_value(event), 2));
			}
			const Value seen = state_.get(heroes_seen_.ref, gd::str(placement_id), Value());
			if (int_of(seen, names_.fell_day, 0) != 0) {
				continue;
			}
			state_.set(seen.ref, gd::str(names_.level), gd::int_value(int_of(commander, names_.level, 1)));
			state_.set(seen.ref, gd::str(names_.experience), gd::int_value(int_of(commander, names_.experience, 0)));
			state_.set(seen.ref, gd::str(names_.power), gd::float_value(compat::snappedf(hero_power(entry), 0.1)));
			state_.set(seen.ref, gd::str(names_.battle_wins), gd::int_value(int_of(commander, names_.battle_wins, 0)));
			if (gd::array_has(state_, gd::as_array(resolved), gd::str(placement_id))) {
				state_.set(seen.ref, gd::str(names_.fell_day), gd::int_value(day()));
				const uint32_t event = state_.new_dict();
				state_.set(event, gd::str(names_.day), gd::int_value(day()));
				state_.set(event, gd::str(names_.type), gd::str(names_.hero_fell));
				state_.set(event, gd::str(names_.player_id), gd::str(seat));
				state_.set(event, gd::str(names_.hero), gd::str(string_of(get(seen, names_.hero))));
				timeline_.push_back(indented.text(gd::dict_value(event), 2));
			}
		}
	}

	// _print_trace: each seat's heroes, goals and towns.
	void print_trace() {
		for (const uint32_t seat : seats_) {
			std::string heroes;
			for (const Value &entry : active_hero_entries(seat)) {
				const Value goal = get(get(entry, names_.ai_hero, gd::dict_value(state_.new_dict())), names_.goal, gd::dict_value(state_.new_dict()));
				const std::string goal_id = state_.text(string_of(get(goal, names_.id, state_.string(""))));
				const size_t at = goal_id.find("_object_");
				std::string slice;
				if (at != std::string::npos) {
					const size_t begin = at + 8;
					const size_t next = goal_id.find("_object_", begin);
					slice = goal_id.substr(begin, next == std::string::npos ? std::string::npos : next - begin);
				}
				heroes += (heroes.empty() ? "" : " ") + text_of(hero_name(entry)) + "(" + compat::itos(static_cast<int64_t>(hero_power(entry))) + ")@" +
						compat::itos(int_of(entry, names_.x, 0)) + "," + compat::itos(int_of(entry, names_.y, 0)) + ">" +
						state_.text(string_of(get(goal, names_.kind, state_.string("")))) + ":" + slice;
			}
			std::string towns;
			for (const Value &town : towns_of(seat)) {
				towns += (towns.empty() ? "" : " ") + text_of(town_name(town)) + "@" + compat::itos(int_of(town, names_.x, 0)) + "," + compat::itos(int_of(town, names_.y, 0)) +
						" g" + compat::itos(static_cast<int64_t>(army_power(get(town, names_.garrison, gd::array_value(state_.new_array())))));
			}
			const Value treasury = get(seat_state(seat), names_.treasury, gd::dict_value(state_.new_dict()));
			print("MATCH_TRACE d" + compat::itos(day()) + " " + state_.text(seat) + " gold=" + compat::itos(int_of(treasury, names_.gold, 0)) + " " + heroes + " | " + towns);
		}
	}

	// _town_snapshot: every town as the week starts.
	Value town_snapshot() {
		const uint32_t rows = state_.new_array();
		const st::ValueList towns = state_.array(gd::as_array(overworld_list(names_.towns))).items;
		for (const Value &town : towns) {
			if (town.kind != Kind::Dict) {
				continue;
			}
			uint32_t owner = names_.neutral;
			if (string_of(get(town, names_.owner, state_.string(""))) == names_.enemy) {
				owner = players::town_controller_id(state_, town.ref);
			}
			const Value recruits = get(town, names_.available_recruits, gd::dict_value(state_.new_dict()));
			const Value garrison = get(town, names_.garrison, gd::array_value(state_.new_array()));
			const uint32_t row = state_.new_dict();
			state_.set(row, gd::str(names_.name), gd::str(string_of(town_name(town))));
			state_.set(row, gd::str(names_.x), gd::int_value(int_of(town, names_.x, 0)));
			state_.set(row, gd::str(names_.y), gd::int_value(int_of(town, names_.y, 0)));
			state_.set(row, gd::str(names_.owner), gd::str(owner));
			const gd::DictRef content_town = gd::content_row(state_, st::ContentTable::Town, string_of(get(town, names_.town_id, state_.string(""))));
			state_.set(row, gd::str(names_.faction), gd::str(string_of(state_.get(content_town, gd::str(names_.faction_id), state_.string("")))));
			state_.set(row, gd::str(names_.built), gd::array_value(gd::duplicate_array(state_, gd::as_array(get(town, names_.built_buildings, gd::array_value(state_.new_array()))))));
			state_.set(row, gd::str(names_.recruits), gd::dict_value(gd::duplicate_dict(state_, gd::as_dict(recruits))));
			state_.set(row, gd::str(names_.garrison), gd::float_value(army_power(garrison)));
			const uint32_t offered = state_.new_array();
			const st::ValueList unit_ids = state_.dict(recruits.ref).keys.list();
			for (const Value &unit_id : unit_ids) {
				const uint32_t stack = state_.new_dict();
				state_.set(stack, gd::str(names_.unit_id), gd::str(string_of(unit_id)));
				state_.set(stack, gd::str(names_.count), gd::int_value(gd::to_int(state_, state_.get(recruits.ref, unit_id, gd::int_value(0)))));
				state_.append(offered, gd::dict_value(stack));
			}
			state_.set(row, gd::str(names_.recruits_power), gd::float_value(army_power(gd::array_value(offered))));
			const uint32_t stacks = state_.new_array();
			for (const Value &stack : gd::items(state_, garrison)) {
				state_.append(stacks, state_.string(state_.text(string_of(get(stack, names_.unit_id, state_.string("")))) + ":" + compat::itos(int_of(stack, names_.count, 0))));
			}
			state_.set(row, gd::str(names_.stacks), gd::array_value(stacks));
			state_.append(rows, gd::dict_value(row));
		}
		const uint32_t week = state_.new_dict();
		state_.set(week, gd::str(names_.day), gd::int_value(day()));
		state_.set(week, gd::str(names_.towns), gd::array_value(rows));
		return gd::dict_value(week);
	}

	// _day_row: each seat's treasury, towns, heroes and sites today.
	Value day_row() {
		const uint32_t row = state_.new_dict();
		const uint32_t sides = state_.new_dict();
		state_.set(row, gd::str(names_.day), gd::int_value(day()));
		state_.set(row, gd::str(names_.sides), gd::dict_value(sides));
		for (const uint32_t seat : seats_) {
			const Value seat_state_value = seat_state(seat);
			const st::ValueList towns = towns_of(seat);
			int64_t buildings = 0;
			double garrison_power = 0.0;
			for (const Value &town : towns) {
				buildings += state_.array_size(gd::as_array(get(town, names_.built_buildings, gd::array_value(state_.new_array()))));
				garrison_power += army_power(get(town, names_.garrison, gd::array_value(state_.new_array())));
			}
			const uint32_t heroes = state_.new_array();
			double hero_power_sum = 0.0;
			for (const Value &entry : active_hero_entries(seat)) {
				const double power = hero_power(entry);
				hero_power_sum += power;
				const uint32_t hero = state_.new_dict();
				state_.set(hero, gd::str(names_.hero), hero_name(entry));
				state_.set(hero, gd::str(names_.level), gd::int_value(int_of(get(entry, names_.enemy_commander_state, gd::dict_value(state_.new_dict())), names_.level, 1)));
				state_.set(hero, gd::str(names_.power), gd::float_value(compat::snappedf(power, 0.1)));
				state_.set(hero, gd::str(names_.x), gd::int_value(int_of(entry, names_.x, 0)));
				state_.set(hero, gd::str(names_.y), gd::int_value(int_of(entry, names_.y, 0)));
				state_.append(heroes, gd::dict_value(hero));
			}
			int64_t sites = 0;
			for (const Value &node : gd::items(state_, overworld_list(names_.resource_nodes))) {
				if (node.kind == Kind::Dict && players::resource_controller_id(state_, node.ref) == seat) {
					++sites;
				}
			}
			const Value economy = get(state_.get(gd::as_dict(field(kFlags)), gd::str(names_.economy_log), gd::dict_value(state_.new_dict())), seat, gd::dict_value(state_.new_dict()));
			const uint32_t side = state_.new_dict();
			state_.set(side, gd::str(names_.treasury), live_resources(get(seat_state_value, names_.treasury, gd::dict_value(state_.new_dict()))));
			state_.set(side, gd::str(names_.towns), gd::int_value(static_cast<int64_t>(towns.size())));
			state_.set(side, gd::str(names_.buildings), gd::int_value(buildings));
			state_.set(side, gd::str(names_.heroes), gd::array_value(heroes));
			state_.set(side, gd::str(names_.hero_power), gd::float_value(compat::snappedf(hero_power_sum, 0.1)));
			state_.set(side, gd::str(names_.garrison_power), gd::float_value(compat::snappedf(garrison_power, 0.1)));
			state_.set(side, gd::str(names_.sites), gd::int_value(sites));
			state_.set(side, gd::str(names_.explored), gd::int_value(explored_tile_count(seat_state_value)));
			state_.set(side, gd::str(names_.economy), gd::dict_value(gd::duplicate_dict(state_, gd::as_dict(economy))));
			state_.set(sides, gd::str(seat), gd::dict_value(side));
		}
		return gd::dict_value(row);
	}

	// AiSeatRules.standing_players: the players holding a town or a hero.
	std::vector<uint32_t> standing_players() {
		std::vector<uint32_t> result;
		for (const Value &record : gd::items(state_, overworld_list(names_.players))) {
			if (record.kind != Kind::Dict) {
				continue;
			}
			const uint32_t player_id = string_of(get(record, names_.player_id, state_.string("")));
			if (state_.array_size(port::enemy_turn_rules::_owned_town_entries(state_, make_view(), player_id)) != 0 ||
					!active_hero_entries(player_id).empty()) {
				result.push_back(player_id);
			}
		}
		return result;
	}
	// AiSeatRules.match_over: every standing player allied with the first.
	bool match_over() {
		const std::vector<uint32_t> standing = standing_players();
		for (const uint32_t player_id : standing) {
			if (!players::allied(state_, gd::dict_value(make_view()), standing.front(), player_id)) {
				return false;
			}
		}
		return true;
	}

	// ------------------------------------------------------ the stores

	Value miss(st::ContentTable table, uint32_t id) {
		++counts.content_misses[std::string(kTableNames[static_cast<size_t>(table)]) + " " + state_.text(id)];
		return Value();
	}

	// A static var's value when a match starts: the content snapshot's.
	Value initial_static(State &state, uint32_t script, uint32_t name) {
		uint32_t store_script = 0;
		uint32_t store_name = 0;
		Value names;
		Value value;
		if (!store_atom(content_deep_, script, store_script) || !store_atom(content_deep_, name, store_name) ||
				!content_->store->state.lookup(content_->statics.ref, Value::str(store_script), names) || names.kind != Kind::Dict ||
				!content_->store->state.lookup(names.ref, Value::str(store_name), value)) {
			throw st::ScriptError(state.text(script) + "." + state.text(name) + ": a static var the content snapshot does not hold");
		}
		return import_deep(content_deep_, value);
	}

	uint32_t game_atom(StoreMap &map, uint32_t atom) {
		if (atom < key::known_count) {
			return atom;
		}
		uint32_t &slot = map.atoms[atom];
		if (slot == 0) {
			slot = state_.intern(map.store->state.text(atom)) + 1;
		}
		return slot - 1;
	}

	bool store_atom(StoreMap &map, uint32_t atom, uint32_t &out) {
		if (atom < key::known_count) {
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

	Value opaque_of(const StoreMap &map, const Value &value) {
		Opaque kept;
		kept.what = map.store->decoded.unsupported.at(value.ref);
		opaques_.push_back(kept);
		return Value::of_ref(Kind::Opaque, static_cast<uint32_t>(opaques_.size() - 1));
	}

	// A store's value in the match, each store node one backed node, filled
	// when read: the content rows and files, which are read-only or only read.
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
			case Kind::Opaque:
				return opaque_of(map, value);
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

	// A store's value in the match whole, at once: the session and the static
	// vars, which the days change. A container reached from two places is one
	// node, as in the game.
	Value import_deep(StoreMap &map, const Value &value) {
		switch (value.kind) {
			case Kind::String:
			case Kind::StringName:
				return Value::of_ref(value.kind, game_atom(map, value.ref));
			case Kind::Opaque:
				return opaque_of(map, value);
			case Kind::Array: {
				uint64_t &slot = map.arrays[value.ref];
				if ((slot >> 32) == epoch_) {
					return Value::of_ref(Kind::Array, static_cast<uint32_t>(slot));
				}
				const uint32_t made = state_.new_array();
				map.arrays[value.ref] = static_cast<uint64_t>(epoch_) << 32 | made;
				const st::ArrayNode &source = map.store->state.array_node(value.ref);
				st::ValueList items;
				items.resize(source.items.size());
				for (size_t index = 0; index < source.items.size(); ++index) {
					items[index] = import_deep(map, source.items[index]);
				}
				st::ArrayNode &target = state_.array_node(made);
				target.items = std::move(items);
				target.element_type = map.store->types[source.element_type];
				target.read_only = source.read_only;
				target.guard = State::kWatched;
				return Value::of_ref(Kind::Array, made);
			}
			case Kind::Dict: {
				uint64_t &slot = map.dicts[value.ref];
				if ((slot >> 32) == epoch_) {
					return Value::of_ref(Kind::Dict, static_cast<uint32_t>(slot));
				}
				const uint32_t made = state_.new_dict();
				map.dicts[value.ref] = static_cast<uint64_t>(epoch_) << 32 | made;
				const st::DictNode &source = map.store->state.dict_node(value.ref);
				st::ValueList keys;
				st::ValueList values;
				keys.resize(source.keys.size());
				values.resize(source.values.size());
				const st::ValueList &source_keys = source.keys.list();
				for (size_t index = 0; index < source_keys.size(); ++index) {
					keys[index] = import_deep(map, source_keys[index]);
					values[index] = import_deep(map, source.values[index]);
				}
				st::DictNode &target = state_.dict_node(made);
				target.keys = std::move(keys);
				target.values = std::move(values);
				target.key_type = map.store->types[source.key_type];
				target.value_type = map.store->types[source.value_type];
				target.read_only = source.read_only;
				target.guard = State::kWatched;
				return Value::of_ref(Kind::Dict, made);
			}
			case Kind::PackedByte:
			case Kind::PackedInt32:
			case Kind::PackedString: {
				uint64_t &slot = map.packeds[value.ref];
				if ((slot >> 32) == epoch_) {
					return Value::of_ref(value.kind, static_cast<uint32_t>(slot));
				}
				const uint32_t made = state_.new_packed(value.kind);
				map.packeds[value.ref] = static_cast<uint64_t>(epoch_) << 32 | made;
				const st::PackedNode &source = map.store->state.packed_node(value.ref);
				st::PackedNode &target = state_.packed_node(made);
				target.bytes = source.bytes;
				target.ints = source.ints;
				target.atoms.resize(source.atoms.size());
				for (size_t index = 0; index < source.atoms.size(); ++index) {
					target.atoms[index] = game_atom(map, source.atoms[index]);
				}
				target.guard = State::kWatched;
				return Value::of_ref(value.kind, made);
			}
			default:
				return value;
		}
	}

	Contents &contents_;
	Types &types_;
	const Calls &calls_;
	State state_;
	Names names_;
	size_t known_types_ = 0;
	TypeRef builtin_types_[256] = {};
	const Content *content_ = nullptr;
	const Store *match_store_ = nullptr;
	// The content snapshot's rows and files (backed, filled when read) and its
	// static vars (whole); the setup snapshot's files (backed) and its setup and
	// settings (whole).
	StoreMap content_rows_;
	StoreMap content_deep_;
	StoreMap match_rows_;
	StoreMap match_deep_;
	uint32_t epoch_ = 0;
	std::vector<Source> array_sources_;
	std::vector<Source> dict_sources_;
	std::vector<Source> packed_sources_;
	std::vector<Opaque> opaques_;
	std::unordered_map<uint64_t, Value> statics_;
	// The match's scenario id, its files on disk (the packages from the
	// snapshot) and, while the session starts, the package documents.
	std::string scenario_id_;
	std::unique_ptr<aurelion::rules::content::DiskFiles> disk_;
	std::vector<std::unique_ptr<map_packages::MapDocument>> map_documents_;
	std::vector<std::unique_ptr<map_packages::ScenarioDocument>> scenario_documents_;
	Value files_;
	int64_t content_revision_ = 0;
	// The session object: its fields (kSessionFields' order), its metadata and
	// its instance id; the view of the native call in progress.
	Value object_;
	Value object_meta_;
	Value instance_id_;
	uint32_t view_node_ = ~0u;
	// The match: the record's setup and handover, the seats, what the notes
	// and the ledger keep.
	Value setup_;
	Value handover_;
	std::vector<uint32_t> seats_;
	Value heroes_seen_;
	Value last_row_;
	std::vector<std::string> timeline_;
	int64_t captures_seen_ = 0;
	std::ofstream digest_;
	std::string dump_path_;
	int64_t dump_day_ = -1;
	std::vector<std::string> blank_scopes_;
	std::set<std::string> blank_fields_;
	std::string out_path_;
	std::string out_text_;
	Clock::time_point started_;
	std::string *lines_ = nullptr;
};

std::string counts_json(const Counts &counts, double seconds, unsigned threads) {
	std::string out = "{\"matches\":" + std::to_string(counts.matches);
	out += ",\"failed\":" + std::to_string(counts.failed);
	out += ",\"days\":" + std::to_string(counts.days);
	out += ",\"seconds\":" + compat::json_float(seconds);
	out += ",\"threads\":" + std::to_string(threads);
	const auto table = [&](const char *name, const std::map<std::string, int64_t> &entries) {
		out += ",\"";
		out += name;
		out += "\":{";
		bool first = true;
		for (const auto &[entry, count] : entries) {
			out += first ? "" : ",";
			first = false;
			append_json_string(out, entry);
			out += ':' + std::to_string(count);
		}
		out += '}';
	};
	table("host_calls", counts.host_calls);
	table("content_misses", counts.content_misses);
	out += ",\"math_calls\":{\"pow\":" + std::to_string(counts.pow_calls) + ",\"exp\":" + std::to_string(counts.exp_calls) + ",\"log\":" + std::to_string(counts.log_calls) + "}";
	out += ",\"printed_errors\":" + std::to_string(counts.printed_errors);
	out += ",\"printed_warnings\":" + std::to_string(counts.printed_warnings);
	out += ",\"most_atoms\":" + std::to_string(counts.most_atoms);
	out += '}';
	return out;
}

[[noreturn]] void usage(const std::string &problem) {
	std::fprintf(stderr,
			"match_sim_cli: %s\n"
			"usage: match_sim_cli [--threads N]\n"
			"       (settings: HEROES_AI_MATCH_* or HEROES_AI_MATCH_LIST, as tests/ai_versus_ai_match_report.gd takes them)\n",
			problem.c_str());
	std::exit(2);
}

int run(int argc, char **argv) {
	unsigned threads = 0;
	for (int index = 1; index < argc; ++index) {
		const std::string arg = argv[index];
		if (arg == "--threads" && index + 1 < argc) {
			threads = static_cast<unsigned>(std::stoul(argv[++index]));
		} else {
			usage("unknown argument " + arg);
		}
	}
	const Clock::time_point started = Clock::now();
	std::vector<Settings> matches;
	const std::string list_path = strip(environment("HEROES_AI_MATCH_LIST"));
	if (!list_path.empty()) {
		matches = read_list(list_path);
	} else {
		matches.emplace_back();
	}
	// The scene records each computer player's turn time by phase.
	set_environment("HEROES_STRATEGIC_AI_PROFILE", "1");
	if (threads == 0) {
		threads = std::max(1u, std::thread::hardware_concurrency());
	}
	threads = static_cast<unsigned>(std::max<size_t>(1, std::min<size_t>(threads, matches.size())));
	Types types;
	Contents contents(types);
	const Calls calls;
	std::vector<std::unique_ptr<Worker>> workers;
	for (unsigned index = 0; index < threads; ++index) {
		workers.push_back(std::make_unique<Worker>(contents, types, calls));
	}
	std::atomic<size_t> next{ 0 };
	std::atomic<bool> all_ok{ true };
	std::mutex out_mutex;
	std::vector<std::thread> pool;
	for (unsigned index = 0; index < threads; ++index) {
		pool.emplace_back([&, index] {
			Worker &worker = *workers[index];
			for (size_t match = next++; match < matches.size(); match = next++) {
				std::string lines;
				if (!worker.play(matches[match], lines)) {
					all_ok = false;
				}
				const std::lock_guard<std::mutex> lock(out_mutex);
				std::fwrite(lines.data(), 1, lines.size(), stdout);
				std::fflush(stdout);
			}
		});
	}
	for (std::thread &thread : pool) {
		thread.join();
	}
	Counts counts;
	for (const auto &worker : workers) {
		counts.add(worker->counts);
	}
	const double seconds = std::chrono::duration<double>(Clock::now() - started).count();
	std::fprintf(stdout, "MATCH_SIM_CLI %s\n", counts_json(counts, seconds, threads).c_str());
	// The workers' States hold every node their matches made, and the process
	// ends here anyway.
	std::fflush(stdout);
	std::fflush(stderr);
	std::_Exit(all_ok ? 0 : 1);
}

} // namespace

int main(int argc, char **argv) {
	try {
		return run(argc, argv);
	} catch (const std::exception &error) {
		std::fprintf(stderr, "match_sim_cli: %s\n", error.what());
		return 2;
	}
}
