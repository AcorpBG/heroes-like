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
// from the native content tables the ContentService autoload holds
// (content_host.hpp), loaded as the read-only containers GDScript gets for
// them, scenarios and their terrain layers from ContentService itself, and a
// script's static vars through its script object (Object::get and set, which
// GDScript answers with its static vars). A static var is read once per call
// (and again after a host call); assignments wait for write_back().
// A row or document is asked for once per call: within a call nothing
// reloads the tables but a host call, so they would give the same object
// again. Empty results (an unknown id, a missing file) and a scenario's
// terrain layers are new objects each time, so they are asked for again.
//
// An object's view (object_view): the session as a Dictionary of its script
// variables and its metadata, made from the object when the native code first
// asks for it, as DayEngine.gd makes it. From then on the object's properties
// are read and set in the view, and write_back() sets each property the view
// holds another value for, and the metadata the view's "meta" adds, changes
// or drops. A host call reads the view again from the object afterwards.
//
// A full host call (call_static) runs a GDScript function in the middle of a call
// that writes back (begin(false, true)), so within such a call GDScript does
// run; in any other call the host call throws state::Suspend instead. It
// writes back what the call changed so far, and every node the export made
// becomes a loaded node of the container it became. The function runs, and
// every loaded node is backed again by its container, as load() first set it
// up: what the native code reads next it reads as GDScript left it. Static
// vars, content rows and the State's memo are asked for again. A pure host
// call (call_pure) changes none of that: it writes back the same way, then
// every written node stops being dirty, since Godot holds what it holds, and
// nothing is read again. Until the call's first full host call, its pure
// ones first keep what each container and static var they write held, and
// undo_write_backs() puts it back: the day port's GDScript fallback
// (port::Table::fallback) then starts from the state the call started from.
//
// diff() compares the native result with GDScript's: the same types (int and
// float, String and StringName apart), the same key order, typing and
// read-only flags, and the same container identities: a loaded container
// must be GDScript's very object, a new one must not be a loaded one, and a
// node reached twice must be one object there too. Timings are not compared:
// a float or an int under a Dictionary key ending in "_ms" matches any value
// of its type.
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
class AurelionContent;
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
	// host_calls: the call may run GDScript at a host call (a call that writes
	// back, never a validating one).
	void begin(bool validating = false, bool host_calls = false);
	// Ends a call that is not a kept session's: drops what it loaded and kept,
	// as the next begin() would, so an engine object only the call held (a
	// save's file, a JSON parser and its data) goes now, not after the engine
	// at exit.
	void end();
	// A session kept across calls (the match runner's days, Phase 6 P6-4).
	// begin_kept() starts a call that writes back and may make host calls, as
	// begin(false, true) does, but keeps the nodes the last keep() kept, with
	// their containers, the content rows and the opaque values, so a container
	// loaded before is the same node, filled as far as it was: the call reads
	// none of it again. A call that did not end in keep(), a full State or a
	// changed content revision makes it a begin(false, true). keep() ends a
	// call that returned: it writes back, exports the result, makes each node
	// the export made a loaded node of its new container, and keeps the nodes
	// the arguments, the objects' views and the content rows reach, each now
	// clean. Between calls only GDScript changes the containers: reread()
	// backs a container's node by it again, from scratch, after GDScript
	// changed it in place; drop_kept() makes the next call read everything
	// again.
	void begin_kept();
	godot::Variant keep(const state::Value &result, const state::Value *args, size_t count);
	void reread(const godot::Variant &container);
	void drop_kept() { kept_ = false; }
	state::State &state() { return state_; }

	state::Value load(const godot::Variant &value);
	godot::Variant export_value(const state::Value &value);
	// The loaded containers the native code changed, into themselves, and the
	// static vars it assigned, into their scripts. undoable: each one keeps
	// what it held before the call's first write-back into it, for
	// undo_write_backs().
	void write_back(bool undoable = false);
	// The host calls this call made that ran GDScript on the call's own state
	// (call_static): no write-back before one can be undone.
	size_t full_host_calls() const { return full_host_calls_; }
	// An undoable write-back set an object's properties or metadata (its
	// view), which undo_write_backs() does not put back.
	bool undo_lost() const { return undo_lost_; }
	// The GDScript fallback of a call that made no full host call: every
	// container and static var its pure host calls wrote back takes back, in
	// place, what it held before the call.
	void undo_write_backs();
	// A loaded container the native code wrote into, or a static var it assigned.
	bool changed_a_source() const;
	// The host calls this call made, in order: (script, function) atoms.
	const std::vector<std::pair<uint32_t, uint32_t>> &host_calls_made() const { return host_calls_made_; }
	const state::State &state() const { return state_; }
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
	// verify() without a result: the loaded containers, static vars, memo
	// shapes and RandomNumberGenerators.
	std::string verify_state(const state::Value *args, size_t count, const godot::Array &after);
	// A validating call that ended at a host call (state::Suspend), when
	// GDScript's call reaches the same one: "" when GDScript calls it with the
	// native call's host arguments, compared as diff() compares, and has left
	// the state as verify_state() finds the native call would have by then.
	std::string verify_host_call(const std::vector<state::Value> &host_args, const godot::Array &gdscript_host_args, const state::Value *args, size_t count, const godot::Array &after);
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
	state::Value object_view(state::State &state, uint32_t slot) override;
	void object_set(state::State &state, uint32_t slot, uint32_t property, const state::Value &value) override;
	state::Value view_object(state::State &state, uint32_t node) override;
	// A DayEngine view (DayEngine._view: an object's script vars, its metadata
	// under "meta" and its instance id under "instance_id") that a host call
	// takes as its object: it becomes that object's view, as object_view()
	// makes one. Nil when the node is no such view, or no GDScript may run.
	state::Value adopt_view(uint32_t node);
	bool rng_get(uint32_t slot, uint64_t &seed, uint64_t &state) override;
	void rng_set_state(uint32_t slot, uint64_t state) override;
	uint32_t rng_new(uint64_t seed, uint64_t state) override;
	state::Value content_row(state::State &state, state::ContentTable table, uint32_t id) override;
	state::Value content_file(state::State &state, uint32_t path) override;
	int64_t content_revision(state::State &state) override;
	state::Value static_get(state::State &state, uint32_t script, uint32_t name) override;
	void static_set(state::State &state, uint32_t script, uint32_t name, const state::Value &value) override;
	state::Value call_static(state::State &state, uint32_t script, uint32_t function, const state::Value *args, size_t count) override;
	state::Value call_pure(state::State &state, uint32_t script, uint32_t function, const state::Value *args, size_t count) override;
	state::TypeRef builtin_type(uint8_t builtin) override;
	void print_error(const std::string &text) override;
	void print_warning(const std::string &text) override;
	// The engine's services that game setup calls (Backing::object_call and on).
	state::Value object_call(state::State &state, uint32_t slot, uint32_t method, const state::Value *args, size_t count) override;
	bool object_has_method(state::State &state, uint32_t slot, uint32_t method) override;
	state::Value class_instantiate(state::State &state, uint32_t name) override;
	state::Value autoload(state::State &state, uint32_t name) override;
	bool file_exists(state::State &state, uint32_t path) override;
	int64_t file_length(state::State &state, uint32_t path) override;
	int64_t file_modified_time(state::State &state, uint32_t path) override;
	bool dir_entries(state::State &state, uint32_t path, std::vector<std::pair<uint32_t, bool>> &out) override;
	bool resource_exists(state::State &state, uint32_t path) override;
	uint32_t os_environment(state::State &state, uint32_t name) override;
	bool os_has_feature(state::State &state, uint32_t name) override;
	int64_t ticks_msec() override;
	int64_t ticks_usec() override;
	double unix_time() override;
	uint32_t json_stringify(state::State &state, const state::Value &value) override;
	// The engine's services that saves call (Backing::class_call_static and on).
	state::Value class_call_static(state::State &state, uint32_t class_name, uint32_t method, const state::Value *args, size_t count) override;
	state::Value engine_singleton(state::State &state, uint32_t name) override;
	uint32_t engine_format(state::State &state, uint32_t pattern, const state::Value *args, size_t count, bool &ok) override;
	uint32_t engine_str(state::State &state, const state::Value &value) override;
	state::Value engine_duplicate(state::State &state, const state::Value &value, bool deep) override;
	state::Value class_call_static_engine(state::State &state, uint32_t class_name, uint32_t method, const state::Value *args, size_t count) override;
	state::Value object_call_engine(state::State &state, uint32_t slot, uint32_t method, const state::Value *args, size_t count) override;
	bool engine_equal(state::State &state, const state::Value &a, const state::Value &b) override;
	state::Value engine_equal_loaded(state::State &state, const state::Value &a, const state::Value &b) override;

private:
	// object.method(args) for object_call and object_call_engine.
	godot::Variant call_opaque(state::State &state, uint32_t slot, uint32_t method, const state::Value *args, size_t count);
	// An engine value as an opaque value, Nil for null.
	state::Value keep_opaque(const godot::Variant &value);
	// An engine service's answer loaded: a null object (DirAccess.open of a
	// missing folder) is null, as GDScript's == null sees it.
	state::Value load_answer(const godot::Variant &value);
	// A container loaded from GDScript, or a native-built one that holds one at
	// any depth (engine_duplicate copies both by the engine).
	bool holds_loaded(const state::Value &value) const;
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
		// Its value before the call is in undo_statics_.
		bool undo_kept = false;
	};
	struct UndoStatic {
		uint32_t script = 0;
		uint32_t name = 0;
		godot::Variant value;
	};
	// An object's view: its Dict node, the node its "meta" started as, and
	// the script variables' names (atoms), in order.
	struct ObjectView {
		uint32_t slot = 0;
		uint32_t node = 0;
		uint32_t meta = 0;
		std::vector<uint32_t> fields;
		// A DayEngine view loaded from GDScript (adopt_view): its node is also
		// a loaded container, which takes the object's values after each host
		// call.
		bool adopted = false;
	};
	struct MemoShape {
		uint32_t script = 0;
		uint32_t name = 0;
		std::vector<uint64_t> shape;
	};

	state::Value load_string(const godot::String &text, state::Kind kind);
	// A node backed by its container, set up as load() sets it up when it
	// first meets the container: typing, read-only, the memo's watch.
	void back_array(uint32_t node, const godot::Array &array);
	void back_dict(uint32_t node, const godot::Dictionary &dict);
	void back_packed(uint32_t node, const godot::Variant &packed);
	// A host call's two sides: the nodes export_value made become loaded nodes
	// of the containers they became; every loaded node is backed again.
	void adopt_exported();
	void reback();
	std::string verify_after(const state::Value *args, size_t count, const godot::Array &after);
	const ObjectView *view_of(uint32_t slot) const;
	// The view's fields and metadata, read from the object again.
	void fill_view(const ObjectView &view);
	void write_view(const ObjectView &view);
	bool view_changed(const ObjectView &view) const;
	void verify_object_view(const ObjectView &view, std::string &out);
	state::TypeRef register_type(int64_t builtin, const godot::StringName &class_name, const godot::Variant &script);
	godot::Object *object_at(uint32_t slot) const;
	godot::Object *content_service();
	godot::AurelionContent *content_host();
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
	godot::String path_text(uint32_t path) const;
	// call_pure's two sides of a host call: every change written back,
	// undoably while no full host call has run, and each loaded node marked as
	// what Godot holds now; then the arguments exported.
	godot::Array begin_pure_call(const state::Value *args, size_t count);
	// The arguments of an engine service: scalars as they are, and a call with
	// a container among them written back first (begin_pure_call).
	godot::Array engine_args(const state::Value *args, size_t count, const char *what);
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
	// Per call: the views made (object_view), in the order made.
	std::vector<ObjectView> views_;
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
	// The call may run GDScript at a host call (begin's host_calls).
	bool host_calls_ = false;
	std::vector<std::pair<uint32_t, uint32_t>> host_calls_made_;
	size_t full_host_calls_ = 0;
	bool undo_lost_ = false;
	// The undoable write-backs so far: each container they wrote, with what it
	// held before (Array and Dictionary: duplicate(false); a packed array:
	// duplicate()), and each static var they assigned, with its value before.
	// A node's flag says it is kept.
	std::vector<std::pair<godot::Array, godot::Array>> undo_arrays_;
	std::vector<std::pair<godot::Dictionary, godot::Dictionary>> undo_dicts_;
	std::vector<std::pair<godot::Variant, godot::Variant>> undo_packed_;
	std::vector<UndoStatic> undo_statics_;
	std::vector<uint8_t> undo_array_kept_;
	std::vector<uint8_t> undo_dict_kept_;
	std::vector<uint8_t> undo_packed_kept_;
	std::vector<godot::Variant> array_snapshots_;
	std::vector<godot::Variant> dict_snapshots_;
	std::vector<godot::Variant> packed_snapshots_;
	// A validating call: each loaded RandomNumberGenerator it read or rolled, by
	// object id, with the state the native call left it in; and the ones the
	// native call made, which it rolls themselves.
	std::vector<std::pair<uint64_t, uint64_t>> rng_states_;
	std::vector<uint64_t> made_rngs_;
	godot::ObjectID content_service_;
	godot::ObjectID content_host_;
	// Per call: the content rows and documents loaded, by table and id atom,
	// and the content revision once read (-1 before).
	std::unordered_map<uint64_t, state::Value> content_;
	int64_t content_revision_ = -1;
	// The last call ended in keep(), at this content revision (begin_kept).
	bool kept_ = false;
	int64_t kept_revision_ = -1;
	std::vector<TypeInfo> types_; // TypeRef n is types_[n - 1]; kept across calls
	std::vector<godot::Variant> string_cache_;
	std::vector<godot::Variant> name_cache_;
	// Per export: the Variant each new node became, so a node is one object
	// (until a host call, which makes them loaded nodes: adopt_exported).
	std::unordered_map<uint32_t, godot::Variant> exported_arrays_;
	std::unordered_map<uint32_t, godot::Variant> exported_dicts_;
	std::unordered_map<uint32_t, godot::Variant> exported_packed_;
	// Per diff: the GDScript object each new node was matched with.
	std::unordered_map<uint32_t, uint64_t> matched_arrays_;
	std::unordered_map<uint32_t, uint64_t> matched_dicts_;
	std::unordered_map<uint32_t, uint64_t> matched_packed_;
};

} // namespace aurelion::rules::bridge
