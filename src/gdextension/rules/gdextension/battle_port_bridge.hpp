#pragma once

// One call of a ported battle function from GDScript (BattleEngine.gd).
//
// load() turns the arguments into Values without converting them: an Array or
// Dictionary becomes a backed node that reads its source container one value
// at a time, and is filled from it only when the native code needs it whole;
// a packed array becomes a backed node that copies its elements when first
// read. A container reached twice is one node; so is a packed array, which
// Godot shares between the Variants that hold it.
//
// export_value() turns the result into a Variant: a node loaded from a
// container is that container, so is_same() holds as it would in GDScript; a
// node the native code made becomes a new container. write_back() writes the
// loaded containers the native code changed back into themselves.
//
// The host services: an opaque object's properties are read with Object::get,
// a RandomNumberGenerator's seed and state through its methods, content rows
// from the ContentService autoload, loaded as the containers they are, and a
// script's static vars through its script object (Object::get and set, which
// GDScript answers with its static vars). A static var is read once per call;
// assignments wait for write_back().
// A row or document is asked for once per call: within a call no GDScript
// runs, so ContentService would return the same object again. Its empty
// results (an unknown id, a missing file) and a scenario's terrain layers are
// new objects each time, so they are asked for again.
//
// diff() compares the native result with GDScript's: the same types (int and
// float, String and StringName apart), the same key order, typing and
// read-only flags, and the same container identities: a loaded container
// must be GDScript's very object, a new one must not be a loaded one, and a
// node reached twice must be one object there too. Timings are not compared:
// a float under a Dictionary key ending in "_ms" matches any float.
//
// verify() is the shadow check of a function that writes into its arguments
// when copying them for the native run would cost too much (the AI targets'
// sessions), or that keeps memos in static vars, which the native call must
// find as GDScript's call does (the battle port): the native call runs first
// on the arguments themselves and writes nothing back, then GDScript's call
// runs, and verify() compares what GDScript left with what the native call
// would have written. A validating
// call (begin(true)) keeps each container as it loads it, one level deep,
// for the containers the native code read only in part. It rolls a
// RandomNumberGenerator it loaded on its own record of the state, which
// verify() compares with the state GDScript's call left, so GDScript's call
// rolls from where the native call started.

#include "aurelion_rules/battle_state.hpp"

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <cstdint>
#include <optional>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

namespace godot {
class RandomNumberGenerator;
}

namespace aurelion::rules::bridge {

// Shadow, for a function that writes into its arguments: a copy of them as the
// GDScript call finds them, for the native run (BattleEngine.before_writing).
// Unlike args.duplicate(true), a container reached twice is one copy, as the
// original is one object; a RandomNumberGenerator is a new one with the same
// seed and state; an object with a script (the session) is a new instance of
// its script with every script variable copied the same way. A Dictionary's
// keys and any other object are shared.
godot::Array copy_for_shadow(const godot::Array &args);

class PortBridge : public state::Backing {
public:
	PortBridge();

	// Starts a call: drops the last call's nodes, sources and static vars.
	// A validating call keeps each container as it loads it, for verify().
	void begin(bool validating = false);
	state::State &state() { return state_; }

	state::Value load(const godot::Variant &value);
	godot::Variant export_value(const state::Value &value);
	// The loaded containers the native code changed, into themselves, and the
	// static vars it assigned, into their scripts.
	void write_back();
	// A loaded container the native code wrote into, or a static var it assigned.
	bool changed_a_source() const;
	// "" when the native value is GDScript's.
	std::string diff(const state::Value &native, const godot::Variant &gdscript);
	// After a validating call and GDScript's call of the same function: "" when
	// GDScript returned the native result and left every container the native
	// code loaded, and every static var it read or assigned, as the native
	// call would have. args are the native call's arguments and after the
	// GDScript call's, afterwards: an argument that is another Dictionary now
	// (a session's view, which the engine script makes again) is compared by
	// its contents, and so is its "meta".
	std::string verify(const state::Value &result, const godot::Variant &gdscript_result, const state::Value *args, size_t count, const godot::Array &after);
	// A validating call, after the native call: the shape of each memo the
	// native port shares with GDScript (port::Table::shared_memos) that the native call
	// left alone, which verify then finds as GDScript's call left it.
	void keep_memo_shapes();

	void fill_array(state::State &state, uint32_t node) override;
	void fill_dict(state::State &state, uint32_t node) override;
	int64_t array_size(uint32_t node) override;
	state::Value array_at(state::State &state, uint32_t node, int64_t index) override;
	int64_t dict_size(uint32_t node) override;
	bool dict_lookup(state::State &state, uint32_t node, const state::Value &key, state::Value &out) override;
	void fill_packed(state::State &state, uint32_t node) override;

	state::Value object_get(state::State &state, uint32_t slot, uint32_t property) override;
	bool rng_get(uint32_t slot, uint64_t &seed, uint64_t &state) override;
	void rng_set_state(uint32_t slot, uint64_t state) override;
	uint32_t rng_new(uint64_t seed, uint64_t state) override;
	state::Value content_row(state::State &state, state::ContentTable table, uint32_t id) override;
	state::Value content_file(state::State &state, uint32_t path) override;
	int64_t content_revision(state::State &state) override;
	state::Value static_get(state::State &state, uint32_t script, uint32_t name) override;
	void static_set(state::State &state, uint32_t script, uint32_t name, const state::Value &value) override;
	void print_error(const std::string &text) override;
	void print_warning(const std::string &text) override;
	// The engine's pow, exp and log (UtilityFunctions), as GDScript calls them.
	double math_pow(double base, double exponent) override;
	double math_exp(double x) override;
	double math_log(double x) override;

private:
	struct TypeInfo {
		uint32_t builtin = 0;
		godot::StringName class_name;
		godot::Variant script;
	};
	// A static var the call read or assigned: its value now, as the native code
	// sees it.
	struct StaticVar {
		uint32_t script = 0;
		uint32_t name = 0;
		state::Value value;
		bool assigned = false;
	};
	struct MemoShape {
		uint32_t script = 0;
		uint32_t name = 0;
		std::vector<uint64_t> shape;
	};

	state::Value load_string(const godot::String &text, state::Kind kind);
	state::TypeRef register_type(int64_t builtin, const godot::StringName &class_name, const godot::Variant &script);
	godot::Object *object_at(uint32_t slot) const;
	godot::Object *content_service();
	const godot::Variant &string_variant(uint32_t atom, bool name);
	godot::Variant key_variant(const state::Value &key);
	godot::Array fresh_array(const state::ArrayNode &node) const;
	godot::Dictionary fresh_dict(const state::DictNode &node) const;
	bool same_type(state::TypeRef type, int64_t builtin, const godot::StringName &class_name, const godot::Variant &script) const;
	void diff_value(const state::Value &native, const godot::Variant &gdscript, std::string &path, std::string &out);
	bool same_made_rng(const godot::Variant &made, const godot::Variant &gdscript) const;
	void diff_array_items(const state::ArrayNode &node, const godot::Array &array, std::string &path, std::string &out);
	void diff_dict_items(const state::DictNode &node, const godot::Dictionary &dict, std::string &path, std::string &out);
	godot::Object *script_object(uint32_t script);
	godot::StringName static_name(uint32_t name) const;
	// A validating call's record of a loaded generator's state, made on first use;
	// null outside a validating call and for a generator the call made.
	uint64_t *validating_state(godot::RandomNumberGenerator *rng);
	void verify_view(uint32_t node, const godot::Dictionary &now, std::string &path, std::vector<bool> &views, int depth, std::string &out);
	void verify_loaded(const godot::Array &after, const std::vector<bool> &views, std::string &out);
	std::string where(const godot::Variant &container, const godot::Array &after);

	state::State state_;
	// The container each loaded node reads, by node; none for the native's own.
	std::vector<std::optional<godot::Array>> array_sources_;
	std::vector<std::optional<godot::Dictionary>> dict_sources_;
	std::unordered_map<uint64_t, uint32_t> array_nodes_;
	std::unordered_map<uint64_t, uint32_t> dict_nodes_;
	// The packed array each loaded packed node holds, by node.
	std::vector<std::optional<godot::Variant>> packed_sources_;
	std::unordered_map<uint64_t, uint32_t> packed_nodes_;
	std::vector<godot::Variant> opaque_;
	// The scripts whose static vars the port reads, by path; kept across calls.
	std::unordered_map<std::string, godot::Variant> scripts_;
	// Per call: the static vars read or assigned, in first-use order, by
	// (script << 32 | name).
	std::vector<StaticVar> statics_;
	std::unordered_map<uint64_t, size_t> static_slots_;
	// A validating call: the shared memos the native call left alone (keep_memo_shapes).
	std::vector<MemoShape> memo_shapes_;
	// A validating call: each loaded container as it was loaded, by node
	// (Array and Dictionary: duplicate(false); a packed array: duplicate()).
	bool validating_ = false;
	std::vector<godot::Variant> array_snapshots_;
	std::vector<godot::Variant> dict_snapshots_;
	std::vector<godot::Variant> packed_snapshots_;
	// A validating call: each loaded RandomNumberGenerator it read or rolled, by
	// object id, with the state the native call left it in; and the ones the
	// native call made, which it rolls themselves.
	std::vector<std::pair<uint64_t, uint64_t>> rng_states_;
	std::vector<uint64_t> made_rngs_;
	godot::ObjectID content_service_;
	// Per call: the content rows and documents loaded, by table and id atom,
	// and the content revision once read (-1 before).
	std::unordered_map<uint64_t, state::Value> content_;
	int64_t content_revision_ = -1;
	std::vector<TypeInfo> types_; // TypeRef n is types_[n - 1]; kept across calls
	std::vector<godot::Variant> string_cache_;
	std::vector<godot::Variant> name_cache_;
	// Per export: the Variant each new node became, so a node is one object.
	std::unordered_map<uint32_t, godot::Variant> exported_arrays_;
	std::unordered_map<uint32_t, godot::Variant> exported_dicts_;
	std::unordered_map<uint32_t, godot::Variant> exported_packed_;
	// Per diff: the GDScript object each new node was matched with.
	std::unordered_map<uint32_t, uint64_t> matched_arrays_;
	std::unordered_map<uint32_t, uint64_t> matched_dicts_;
	std::unordered_map<uint32_t, uint64_t> matched_packed_;
};

} // namespace aurelion::rules::bridge
