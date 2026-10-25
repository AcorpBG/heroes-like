#pragma once

// The content snapshot the rules tools outside Godot read (battle_sim_cli,
// match_sim_cli), written by match_sim_cli --write-content for the battle AI
// arena and the AI match runner scene (tests/ai_versus_ai_match_report.gd):
// {files, tables, statics, revision, project}, from the project folder. The
// files are the content::Store's (the game's ContentService loads them so,
// slice 7.10), the tables its lookups by id as ContentService's getters answer
// them, the rules scripts' static vars as a game starts: their declarations'
// values read from the .gd files, then AiHeroRules.army_power([], {}) run
// natively, which applies the AI weights as a game's first call does. A static
// var initializer it cannot read is an error, not a guess. It replaced the
// GDScript capture (rules_snapshot.gd's content_snapshot) and writes the same
// snapshot, but for the engine object NativeRules._api, which no native code
// reads (checked 2026-10-25).

#include "aurelion_rules/battle_state.hpp"
#include "aurelion_rules/content_store.hpp"
#include "aurelion_rules/disk_files.hpp"
#include "aurelion_rules/port/content_service_ai.hpp"
#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/registry.hpp"
#include "aurelion_rules/port/turn_port.hpp"
#include "aurelion_rules/snapshot.hpp"
#include "snapshot_store.hpp"

#include <algorithm>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <map>
#include <memory>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace aurelion::rules::cli {

namespace content_snapshot_detail {

namespace fs = std::filesystem;
namespace content = aurelion::rules::content;
namespace gd = aurelion::rules::gd;
using st::Kind;
using st::State;
using st::Value;

// The art files game setup reads through ContentService.load_json, the
// folders of the scripts whose static vars the native rules read (the rules,
// and the generated map adoption's), the tables (state::ContentTable) with the
// file whose ids each is asked for, and the art rows found by the unit or hero
// id their items name. A generated map's session registers no scenario draft,
// so the scenario and terrain layers tables are left out: their lookups answer {}.
inline constexpr const char *kArtFiles[] = {
	"res://art/overworld/manifest.json",
	"res://art/overworld/creature_idle.json",
	"res://art/overworld/native_scenery.json",
};
inline constexpr const char *kRulesDirs[] = { "scripts/core", "scripts/persistence" };
struct TableSource {
	const char *name;
	const char *path;
};
inline constexpr TableSource kContentTables[] = {
	{ "Unit", content::kUnitsPath },
	{ "Hero", content::kHeroesPath },
	{ "Faction", content::kFactionsPath },
	{ "Spell", content::kSpellsPath },
	{ "Artifact", content::kArtifactsPath },
	{ "ResourceSite", content::kResourceSitesPath },
	{ "Building", content::kBuildingsPath },
	{ "Town", content::kTownsPath },
	{ "MapObject", content::kMapObjectsPath },
	{ "Encounter", content::kEncountersPath },
	{ "ArmyGroup", content::kArmyGroupsPath },
	{ "Resource", content::kResourcesPath },
	{ "NeutralDwelling", content::kNeutralDwellingsPath },
	{ "BuildingArt", content::kBuildingArtPath },
	{ "SpellIcon", content::kSpellIconsPath },
	{ "SpellSchoolIcon", content::kSpellSchoolIconsPath },
	{ "BuildingCategoryIcon", content::kBuildingCategoryIconsPath },
	{ "FactionCrest", content::kFactionCrestsPath },
	{ "Biome", content::kBiomesPath },
	{ "Campaign", content::kCampaignsPath },
};
struct IndexedSource {
	const char *name;
	const char *path;
	const char *field;
};
inline constexpr IndexedSource kIndexedTables[] = {
	{ "UnitArt", content::kUnitArtPath, "unit_id" },
	{ "HeroArt", content::kHeroArtPath, "hero_id" },
	{ "UnitAnimation", content::kUnitAnimationPath, "unit_id" },
};
// Variant::OBJECT, and its type name: how a snapshot keeps a Script.
inline constexpr uint8_t kObjectType = 24;

// A static var's GDScript type, as an assignment converts into it.
enum class VarType { Untyped, Float, Int, Bool, String, Dictionary, Array, Object };

// A GDScript constant expression of the declarations: {}, [], a string, a
// number, true, false, null, nested, over lines, with # comments.
class Literal {
public:
	Literal(State &state, std::string_view text, const std::string &where) :
			state_(state), text_(text), where_(where) {}

	Value parse() {
		const Value value = item();
		space();
		if (pos_ != text_.size()) {
			bad("text after the value");
		}
		return value;
	}

private:
	[[noreturn]] void bad(const std::string &what) const { fail(where_ + ": " + what + " in the initializer " + std::string(text_)); }

	void space() {
		while (pos_ < text_.size()) {
			const char c = text_[pos_];
			if (c == '#') {
				while (pos_ < text_.size() && text_[pos_] != '\n') {
					++pos_;
				}
			} else if (static_cast<unsigned char>(c) <= 32) {
				++pos_;
			} else {
				return;
			}
		}
	}
	bool take(char c) {
		space();
		if (pos_ < text_.size() && text_[pos_] == c) {
			++pos_;
			return true;
		}
		return false;
	}
	bool word(std::string_view name) {
		space();
		if (text_.substr(pos_, name.size()) != name) {
			return false;
		}
		const size_t end = pos_ + name.size();
		if (end < text_.size() && (std::isalnum(static_cast<unsigned char>(text_[end])) || text_[end] == '_')) {
			return false;
		}
		pos_ = end;
		return true;
	}

	Value item() {
		space();
		if (pos_ >= text_.size()) {
			bad("no value");
		}
		const char c = text_[pos_];
		if (c == '{') {
			++pos_;
			const uint32_t dict = state_.new_dict();
			while (!take('}')) {
				const Value key = item();
				if (!take(':')) {
					bad("a key without ':'");
				}
				state_.set(dict, key, item());
				if (!take(',')) {
					if (!take('}')) {
						bad("no '}'");
					}
					break;
				}
			}
			return gd::dict_value(dict);
		}
		if (c == '[') {
			++pos_;
			const uint32_t array = state_.new_array();
			while (!take(']')) {
				state_.append(array, item());
				if (!take(',')) {
					if (!take(']')) {
						bad("no ']'");
					}
					break;
				}
			}
			return gd::array_value(array);
		}
		if (c == '"') {
			return state_.string(string());
		}
		if (word("true")) {
			return gd::bool_value(true);
		}
		if (word("false")) {
			return gd::bool_value(false);
		}
		if (word("null")) {
			return Value();
		}
		return number();
	}

	std::string string() {
		++pos_;
		std::string out;
		while (pos_ < text_.size() && text_[pos_] != '"') {
			char c = text_[pos_++];
			if (c == '\\') {
				if (pos_ >= text_.size()) {
					bad("a string that does not end");
				}
				const char escaped = text_[pos_++];
				switch (escaped) {
					case 'n':
						c = '\n';
						break;
					case 't':
						c = '\t';
						break;
					case '"':
					case '\\':
						c = escaped;
						break;
					default:
						bad(std::string("the escape \\") + escaped);
				}
			}
			out += c;
		}
		if (pos_ >= text_.size()) {
			bad("a string that does not end");
		}
		++pos_;
		return out;
	}

	Value number() {
		const size_t start = pos_;
		if (pos_ < text_.size() && (text_[pos_] == '-' || text_[pos_] == '+')) {
			++pos_;
		}
		bool is_float = false;
		while (pos_ < text_.size()) {
			const char c = text_[pos_];
			if (std::isdigit(static_cast<unsigned char>(c)) || c == '_') {
				++pos_;
			} else if (c == '.' || c == 'e' || c == 'E' || ((c == '-' || c == '+') && (text_[pos_ - 1] == 'e' || text_[pos_ - 1] == 'E'))) {
				is_float = true;
				++pos_;
			} else {
				break;
			}
		}
		std::string digits;
		for (size_t index = start; index < pos_; ++index) {
			if (text_[index] != '_') {
				digits += text_[index];
			}
		}
		if (digits.empty() || digits == "-" || digits == "+") {
			bad("an expression it does not read");
		}
		char *end = nullptr;
		if (is_float) {
			const double number = std::strtod(digits.c_str(), &end);
			if (end == nullptr || *end != '\0') {
				bad("a number it does not read");
			}
			return gd::float_value(number);
		}
		const long long number = std::strtoll(digits.c_str(), &end, 10);
		if (end == nullptr || *end != '\0') {
			bad("a number it does not read");
		}
		return gd::int_value(static_cast<int64_t>(number));
	}

	State &state_;
	std::string_view text_;
	std::string where_;
	size_t pos_ = 0;
};

// The value an assignment of value to a var of this type stores.
inline Value converted(VarType type, const Value &value) {
	if (type == VarType::Float && value.kind == Kind::Int) {
		return gd::float_value(static_cast<double>(value.i));
	}
	if (type == VarType::Int && value.kind == Kind::Float) {
		return gd::int_value(static_cast<int64_t>(value.f));
	}
	return value;
}

// A static var as the snapshot holds it: where its value is, and its type.
struct StaticSlot {
	uint32_t values = 0;
	Value name;
	VarType type = VarType::Untyped;
};

// The host the native army_power runs on: the store's State, its files and
// tables, and the static vars being captured.
class Host final : public st::Backing {
public:
	Host(content::Store &store, Types &types) :
			store_(store), types_(types) {}

	std::map<uint64_t, StaticSlot> statics;
	Value tables[kTableCount];
	int64_t printed = 0;

	void fill_array(State &, uint32_t) override { fail("the content snapshot's nodes are not backed"); }
	void fill_dict(State &, uint32_t) override { fail("the content snapshot's nodes are not backed"); }
	int64_t array_size(uint32_t) override { fail("the content snapshot's nodes are not backed"); }
	Value array_at(State &, uint32_t, int64_t) override { fail("the content snapshot's nodes are not backed"); }
	int64_t dict_size(uint32_t) override { fail("the content snapshot's nodes are not backed"); }
	bool dict_lookup(State &, uint32_t, const Value &, Value &) override { fail("the content snapshot's nodes are not backed"); }

	Value content_row(State &state, st::ContentTable table, uint32_t id) override {
		if (table == st::ContentTable::BiomeForTerrain) {
			id = port::content_service::normalize_terrain_id(state, id);
		} else if (table == st::ContentTable::MapObjectForResourceSite) {
			id = gd::strip_edges(state, id);
		}
		const Value rows = tables[static_cast<size_t>(table)];
		Value row;
		if (rows.kind != Kind::Dict || !state.lookup(rows.ref, gd::str(id), row)) {
			return Value();
		}
		return row;
	}
	Value content_file(State &state, uint32_t path) override {
		std::vector<content::Message> messages;
		const Value data = store_.load_json(state.text(path), messages);
		report(messages);
		return data.kind == Kind::Dict ? data : gd::dict_value(state.new_dict());
	}
	int64_t content_revision(State &) override { return store_.revision(); }

	Value static_get(State &state, uint32_t script, uint32_t name) override {
		const StaticSlot &slot = find(state, script, name);
		return state.get(slot.values, slot.name, Value());
	}
	void static_set(State &state, uint32_t script, uint32_t name, const Value &value) override {
		const StaticSlot &slot = find(state, script, name);
		state.set(slot.values, slot.name, converted(slot.type, value));
	}

	st::TypeRef builtin_type(uint8_t builtin) override {
		snap::TypeInfo info;
		info.builtin = builtin;
		const st::TypeRef type = types_.ref(info);
		types_.sync(store_.scratch(), known_types_);
		return type;
	}
	void print_error(const std::string &text) override {
		++printed;
		std::fprintf(stderr, "ERROR: %s\n", text.c_str());
	}
	void print_warning(const std::string &text) override {
		++printed;
		std::fprintf(stderr, "WARNING: %s\n", text.c_str());
	}

	void report(const std::vector<content::Message> &messages) {
		for (const content::Message &message : messages) {
			if (message.error) {
				print_error(message.text);
			} else {
				print_warning(message.text);
			}
		}
	}

private:
	const StaticSlot &find(State &state, uint32_t script, uint32_t name) {
		const auto found = statics.find(static_cast<uint64_t>(script) << 32 | name);
		if (found == statics.end()) {
			throw st::ScriptError(state.text(script) + "." + state.text(name) + ": a static var the rules scripts do not declare");
		}
		return found->second;
	}

	content::Store &store_;
	Types &types_;
	size_t known_types_ = 0;
};

inline std::string read_text(const fs::path &path) {
	const std::vector<uint8_t> bytes = read_file(path);
	return std::string(bytes.begin(), bytes.end());
}

// The names of the files directly in dir with this extension, sorted as
// DirAccess.get_files_at sorts them.
inline std::vector<std::string> files_at(const fs::path &dir, const std::string &extension) {
	std::vector<std::string> names;
	for (const fs::directory_entry &entry : fs::directory_iterator(dir)) {
		if (entry.is_regular_file() && entry.path().extension().u8string() == "." + extension) {
			names.push_back(entry.path().filename().u8string());
		}
	}
	std::sort(names.begin(), names.end());
	return names;
}

inline VarType type_named(const std::string &name, const std::string &where) {
	static const std::map<std::string, VarType> types = {
		{ "float", VarType::Float },
		{ "int", VarType::Int },
		{ "bool", VarType::Bool },
		{ "String", VarType::String },
		{ "Dictionary", VarType::Dictionary },
		{ "Array", VarType::Array },
		{ "Variant", VarType::Untyped },
		{ "Object", VarType::Object },
	};
	const auto found = types.find(name);
	if (found == types.end()) {
		fail(where + ": a static var type the content snapshot does not read: " + name);
	}
	return found->second;
}

inline VarType type_of_value(const Value &value) {
	switch (value.kind) {
		case Kind::Float:
			return VarType::Float;
		case Kind::Int:
			return VarType::Int;
		case Kind::Bool:
			return VarType::Bool;
		case Kind::String:
			return VarType::String;
		case Kind::Dict:
			return VarType::Dictionary;
		case Kind::Array:
			return VarType::Array;
		default:
			return VarType::Untyped;
	}
}

// The value a typed var without an initializer holds.
inline Value default_of(State &state, VarType type) {
	switch (type) {
		case VarType::Float:
			return gd::float_value(0.0);
		case VarType::Int:
			return gd::int_value(0);
		case VarType::Bool:
			return gd::bool_value(false);
		case VarType::String:
			return state.string("");
		case VarType::Dictionary:
			return gd::dict_value(state.new_dict());
		case VarType::Array:
			return gd::array_value(state.new_array());
		default:
			return Value();
	}
}

// HumanEngine._mode_from_environment(): DayEngine.MODES of HEROES_NATIVE_HUMAN,
// native for "" or an unknown name.
inline Value human_mode() {
	std::string name = port::turn::environment("HEROES_NATIVE_HUMAN");
	const size_t begin = name.find_first_not_of(" \t\r\n");
	const size_t end = name.find_last_not_of(" \t\r\n");
	name = begin == std::string::npos ? std::string() : name.substr(begin, end - begin + 1);
	std::transform(name.begin(), name.end(), name.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
	return gd::int_value(name == "gdscript" ? 0 : (name == "shadow" ? 2 : 1));
}

// The script's static vars, in their order: {name: value} into values, each
// slot into host.statics. False when it declares none.
inline bool read_statics(State &state, Host &host, const fs::path &file, const std::string &script, uint32_t values, std::vector<std::string> &opaques) {
	const std::string source = read_text(file);
	std::vector<std::string> lines;
	size_t start = 0;
	while (start <= source.size()) {
		const size_t newline = std::min(source.find('\n', start), source.size());
		std::string line = source.substr(start, newline - start);
		if (!line.empty() && line.back() == '\r') {
			line.pop_back();
		}
		lines.push_back(std::move(line));
		start = newline + 1;
	}
	const std::string prefix = "static var ";
	bool any = false;
	for (size_t index = 0; index < lines.size(); ++index) {
		const std::string &line = lines[index];
		if (line.rfind(prefix, 0) != 0) {
			continue;
		}
		size_t pos = prefix.size();
		const size_t name_start = pos;
		if (pos >= line.size() || !(std::isalpha(static_cast<unsigned char>(line[pos])) || line[pos] == '_')) {
			continue;
		}
		while (pos < line.size() && (std::isalnum(static_cast<unsigned char>(line[pos])) || line[pos] == '_')) {
			++pos;
		}
		const std::string name = line.substr(name_start, pos - name_start);
		const std::string where = script + ":" + std::to_string(index + 1) + " " + name;
		// The rest: [":" type] ["=" initializer], or ":=" initializer; the
		// initializer's brackets may run over the next lines.
		std::string rest = line.substr(pos);
		const auto trim = [](std::string text) {
			const size_t begin = text.find_first_not_of(" \t");
			const size_t end = text.find_last_not_of(" \t");
			return begin == std::string::npos ? std::string() : text.substr(begin, end - begin + 1);
		};
		rest = trim(rest);
		VarType type = VarType::Untyped;
		bool inferred = false;
		std::string initializer;
		if (rest.rfind(":=", 0) == 0) {
			inferred = true;
			initializer = trim(rest.substr(2));
		} else if (rest.rfind(":", 0) == 0) {
			const size_t equals = rest.find('=');
			type = type_named(trim(rest.substr(1, equals == std::string::npos ? std::string::npos : equals - 1)), where);
			if (equals != std::string::npos) {
				initializer = trim(rest.substr(equals + 1));
			}
		} else if (rest.rfind("=", 0) == 0) {
			initializer = trim(rest.substr(1));
		} else if (!rest.empty() && rest[0] != '#') {
			fail(where + ": a static var declaration the content snapshot does not read: " + line);
		}
		if (!initializer.empty() && (initializer[0] == '{' || initializer[0] == '[')) {
			const auto depth_of = [](const std::string &text) {
				int depth = 0;
				bool quoted = false;
				for (size_t at = 0; at < text.size(); ++at) {
					const char c = text[at];
					if (quoted) {
						if (c == '\\') {
							++at;
						} else if (c == '"') {
							quoted = false;
						}
					} else if (c == '"') {
						quoted = true;
					} else if (c == '#') {
						while (at < text.size() && text[at] != '\n') {
							++at;
						}
					} else if (c == '{' || c == '[') {
						++depth;
					} else if (c == '}' || c == ']') {
						--depth;
					}
				}
				return depth;
			};
			while (depth_of(initializer) > 0 && index + 1 < lines.size()) {
				initializer += "\n" + lines[++index];
			}
		}
		Value value;
		const std::string load_prefix = "load(\"";
		if (initializer.empty()) {
			value = default_of(state, type);
		} else if (initializer.rfind(load_prefix, 0) == 0 && initializer.size() > load_prefix.size() + 2 &&
				initializer.compare(initializer.size() - 2, 2, "\")") == 0) {
			// A Script, which a snapshot keeps as an opaque Object.
			opaques.push_back(initializer.substr(load_prefix.size(), initializer.size() - load_prefix.size() - 2));
			value = Value::of_ref(Kind::Opaque, static_cast<uint32_t>(opaques.size() - 1));
		} else if (initializer == "_mode_from_environment()" && script == "res://scripts/core/HumanEngine.gd") {
			value = human_mode();
		} else {
			value = Literal(state, initializer, where).parse();
		}
		if (inferred) {
			type = type_of_value(value);
		}
		value = converted(type, value);
		const Value key = state.string(name);
		state.set(values, key, value);
		StaticSlot slot;
		slot.values = values;
		slot.name = key;
		slot.type = type;
		host.statics[static_cast<uint64_t>(state.intern(script)) << 32 | state.intern(name)] = slot;
		any = true;
	}
	return any;
}

} // namespace content_snapshot_detail

// The content snapshot of the project folder: {files, tables, statics,
// revision, project}, encoded. types: the registry the typed containers'
// types go into.
inline std::vector<uint8_t> build_content_snapshot(const std::filesystem::path &project, Types &types) {
	using namespace content_snapshot_detail;
	fs::path root = fs::absolute(project).lexically_normal();
	if (!root.has_filename()) {
		root = root.parent_path();
	}
	if (!fs::is_directory(root / "content")) {
		fail(root.u8string() + " is no project folder: it has no content folder");
	}
	content::Store store(std::make_shared<content::DiskFiles>(root.generic_u8string(), true));
	State &state = store.scratch();
	Host host(store, types);
	std::vector<content::Message> messages;
	const auto file = [&](const std::string &path) {
		const Value data = store.load_json(path, messages);
		return data.kind == Kind::Dict ? data : gd::dict_value(state.new_dict());
	};
	const auto get = [&](const Value &dict, const char *name, const Value &fallback) {
		return dict.kind == Kind::Dict ? state.get(dict.ref, state.string(name), fallback) : fallback;
	};
	// ContentService._items_from_raw(raw): raw.get("items", raw.get("entries", [])), an Array or [].
	const auto items_of = [&](const Value &raw) {
		const Value items = get(raw, "items", get(raw, "entries", Value()));
		return items.kind == Kind::Array ? state.array(items.ref).items : st::ValueList();
	};
	const auto text_of = [&](const Value &value) { return state.text(gd::stringify(state, value)); };
	const auto found = [&](const Value &row) { return row.kind == Kind::Dict && state.dict_size(row.ref) != 0; };

	const uint32_t files = state.new_dict();
	for (const std::string &name : files_at(root / "content", "json")) {
		const std::string path = std::string(content::kContentDir) + "/" + name;
		state.set(files, state.string(path), file(path));
	}
	for (const char *path : kArtFiles) {
		state.set(files, state.string(path), file(path));
	}

	const uint32_t tables = state.new_dict();
	const auto table_index = [](const char *name) {
		for (size_t index = 0; index < kTableCount; ++index) {
			if (std::string_view(kTableNames[index]) == name) {
				return index;
			}
		}
		fail(std::string("no content table ") + name);
	};
	for (const TableSource &source : kContentTables) {
		const std::string table = source.name;
		std::vector<std::string> ids = { "" };
		for (const std::string &id : store.content_ids(source.path, "items", messages)) {
			ids.push_back(id);
		}
		if (table == "Town") {
			const Value aliases = get(file(source.path), "legacy_aliases", Value());
			if (aliases.kind == Kind::Dict) {
				for (const Value &alias : state.dict(aliases.ref).keys.list()) {
					ids.push_back(text_of(alias));
				}
			}
		} else if (table == "Encounter") {
			for (const std::string &id : store.content_ids(content::kGeneratedCompaniesPath, "encounters", messages)) {
				ids.push_back(id);
			}
		}
		const uint32_t rows = state.new_dict();
		for (const std::string &id : ids) {
			const Value row = table == "Encounter" ? store.encounter(id, messages) : store.content_by_id(source.path, id, "items", messages);
			const Value key = state.string(id);
			if (!state.has(rows, key) && found(row)) {
				state.set(rows, key, row);
			}
		}
		state.set(tables, state.string(table), gd::dict_value(rows));
		host.tables[table_index(source.name)] = gd::dict_value(rows);
	}
	// By the id each lookup asks with: the stripped site id, the normalized terrain.
	const uint32_t by_site = state.new_dict();
	for (const Value &item : items_of(file(content::kMapObjectsPath))) {
		if (item.kind != Kind::Dict) {
			continue;
		}
		const std::string site_id = state.text(gd::strip_edges(state, gd::stringify(state, get(item, "resource_site_id", state.string("")))));
		if (!site_id.empty() && !state.has(by_site, state.string(site_id))) {
			const Value row = store.map_object_for_resource_site(site_id, messages);
			state.set(by_site, state.string(site_id), row.kind == Kind::Dict ? row : gd::dict_value(state.new_dict()));
		}
	}
	state.set(tables, state.string("MapObjectForResourceSite"), gd::dict_value(by_site));
	host.tables[table_index("MapObjectForResourceSite")] = gd::dict_value(by_site);
	const uint32_t by_terrain = state.new_dict();
	for (const Value &biome : items_of(file(content::kBiomesPath))) {
		const Value tiles = get(biome, "map_tile_ids", gd::array_value(state.new_array()));
		if (biome.kind != Kind::Dict || tiles.kind != Kind::Array) {
			continue;
		}
		for (const Value &tile : state.array(tiles.ref).items) {
			const std::string terrain = tile.is_string_like() ? state.text(tile.ref) : std::string();
			if (!terrain.empty() && content::Store::normalize_terrain_id(terrain) == terrain && !state.has(by_terrain, state.string(terrain))) {
				const Value row = store.biome_for_terrain(terrain, messages);
				if (found(row)) {
					state.set(by_terrain, state.string(terrain), row);
				}
			}
		}
	}
	state.set(tables, state.string("BiomeForTerrain"), gd::dict_value(by_terrain));
	host.tables[table_index("BiomeForTerrain")] = gd::dict_value(by_terrain);
	for (const IndexedSource &source : kIndexedTables) {
		const uint32_t rows = state.new_dict();
		for (const Value &item : items_of(file(source.path))) {
			const std::string id = item.kind == Kind::Dict ? text_of(get(item, source.field, state.string(""))) : std::string();
			if (!state.has(rows, state.string(id))) {
				const Value row = store.indexed_row(source.path, id, "items", source.field, messages);
				if (found(row)) {
					state.set(rows, state.string(id), row);
				}
			}
		}
		state.set(tables, state.string(source.name), gd::dict_value(rows));
		host.tables[table_index(source.name)] = gd::dict_value(rows);
	}
	host.report(messages);

	// Each rules script's static vars, by its path and their names.
	const uint32_t statics = state.new_dict();
	std::vector<std::string> opaques;
	for (const char *dir : kRulesDirs) {
		for (const std::string &name : files_at(root / dir, "gd")) {
			const std::string script = std::string("res://") + dir + "/" + name;
			const uint32_t values = state.new_dict();
			if (read_statics(state, host, root / dir / name, script, values, opaques)) {
				state.set(statics, state.string(script), gd::dict_value(values));
			}
		}
	}
	// As the arena's worker did before its capture: army_power applies the AI
	// weights from the content at its first call.
	const port::Function *army_power = port::find_function("AiHeroRules.army_power");
	if (army_power == nullptr || army_power->arity != 2) {
		fail("the port has no AiHeroRules.army_power of 2 arguments");
	}
	state.set_backing(&host);
	state.drop_memo();
	const Value args[2] = { gd::array_value(state.new_array()), gd::dict_value(state.new_dict()) };
	army_power->call(state, args);
	state.set_backing(nullptr);

	const uint32_t snapshot = state.new_dict();
	state.set(snapshot, state.string("files"), gd::dict_value(files));
	state.set(snapshot, state.string("tables"), gd::dict_value(tables));
	state.set(snapshot, state.string("statics"), gd::dict_value(statics));
	state.set(snapshot, state.string("revision"), gd::int_value(store.revision()));
	state.set(snapshot, state.string("project"), state.string(root.generic_u8string()));
	snap::EncodeHooks hooks;
	hooks.type = [&](st::TypeRef type) { return types.info(type); };
	hooks.opaque = [](uint32_t) { return std::make_pair(kObjectType, std::string("Object")); };
	return snap::encode(state, gd::dict_value(snapshot), hooks);
}

} // namespace aurelion::rules::cli
