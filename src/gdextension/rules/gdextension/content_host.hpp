#pragma once

// The native content tables' door (aurelion_rules/content_store.hpp,
// docs/native-rules-engine-transition.md, Phase 7, slice 7.10). The
// ContentService autoload holds one AurelionContent and asks it for documents
// and rows by id. Each node of the tables becomes one read-only Dictionary or
// Array, made when first asked for and handed out from then on, so every
// caller gets the same object, as from ContentService's cache; the port
// bridge loads those very objects (content_variant). A reload (clear_cache,
// an override) makes new ones.

#include "aurelion_rules/content_store.hpp"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <cstdint>
#include <memory>
#include <vector>

namespace godot {

class AurelionContent : public RefCounted {
	GDCLASS(AurelionContent, RefCounted)

protected:
	static void _bind_methods();

public:
	AurelionContent();
	~AurelionContent() override;

	// ContentService's queries. A document or row is a read-only Dictionary,
	// or null for none (ContentService's {}), whose push_error is printed.
	Variant load_json(const String &path);
	Variant content_by_id(const String &path, const String &id, const String &list_key);
	Variant indexed_row(const String &path, const String &id, const String &list_key, const String &id_field);
	Variant encounter(const String &id);
	PackedStringArray content_ids(const String &path, const String &list_key);
	String canonical_town_id(const String &id);
	String normalize_terrain_id(const String &terrain_id) const;
	Variant biome_for_terrain(const String &terrain_id);
	Variant map_object_for_resource_site(const String &site_id);
	// set_content_override: false, with the refusals printed, when refused.
	bool set_override(const String &path, const Dictionary &document);
	void clear_overrides();
	void clear_cache();
	int64_t revision() const;
	void bump_revision();
	// _validate_content: prints what is wrong with the shipped content.
	void validate();

	// For the port bridge.
	aurelion::rules::content::Store &store() { return *store_; }
	// A value of store().data() as the Variant GDScript gets for it.
	Variant content_variant(const aurelion::rules::state::Value &value);
	// Prints a lookup's messages.
	static void report(const std::vector<aurelion::rules::content::Message> &messages);

private:
	// The Variants made so far, by node and atom, of the tables' data as it
	// is at generation_.
	void sync();
	const Variant &string_variant(uint32_t atom);

	std::unique_ptr<aurelion::rules::content::Store> store_;
	uint64_t generation_ = 0;
	std::vector<Variant> arrays_;
	std::vector<Variant> dicts_;
	std::vector<Variant> strings_;
};

} // namespace godot
