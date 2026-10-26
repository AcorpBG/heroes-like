// GeneratedRewardRules (scripts/persistence/GeneratedRewardRules.gd): a random
// map object's translation by meaning into the runtime's sites, dwellings,
// creature banks, Pandora's boxes and their guards. Every roll is a stable hash
// of the placement id.

#include "aurelion_rules/port/generated_reward_rules.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/content_service_ai.hpp"
#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/generated_neutral_encounter_rules.hpp"
#include "aurelion_rules/port/hero_progression_rules_turn.hpp"
#include "aurelion_rules/port/native_transit_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_string.hpp"

#include <cstdint>
#include <initializer_list>
#include <string>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::State;
using state::Value;
namespace key = state::key;

// String(d.get(key, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify_or_fallback(state, state.get(dict, str(field), str(fallback)));
}

// `d.get(key, {}) if d.get(key, {}) is Dictionary else {}`.
DictRef dict_field_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// `d.get(key, []) if d.get(key, []) is Array else []`.
ArrayRef array_field_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_array(found)) {
		return found.ref;
	}
	return state.new_array();
}

// CONST[key] of a constant Dictionary whose key is missing.
[[noreturn]] void missing_key(const std::string &missing) {
	throw state::ScriptError("Invalid access to property or key '" + missing + "' on a base object of type 'Dictionary'.");
}

// value in [ints].
bool one_of(int64_t value, std::initializer_list<int64_t> ids) {
	for (const int64_t id : ids) {
		if (id == value) {
			return true;
		}
	}
	return false;
}

// value in [Strings] of a constant list.
template <size_t N>
bool has_atom(Atom value, const Atom (&list)[N]) {
	for (const Atom item : list) {
		if (item == value) {
			return true;
		}
	}
	return false;
}

// a.sort() of an Array of Strings: String < String, by code points (their
// UTF-8 bytes), with Godot's own sort.
void sort_strings(State &state, ArrayRef array) {
	gd::sort_custom(state, array, [&state](const Value &a, const Value &b) { return gd::text(state, a) < gd::text(state, b); });
}

// _hash32 of a text's UTF-8: FNV-1a with a MurmurHash3 finalizer, in
// GDScript's 64-bit ints masked to 32 bits (a product that wraps keeps its low
// 32 bits).
int64_t hash32_text(const std::string &text) {
	uint64_t value = 2166136261u;
	for (const char byte : text) {
		value = ((value ^ static_cast<uint64_t>(static_cast<unsigned char>(byte))) * 16777619u) & 0xffffffffu;
	}
	value ^= value >> 16;
	value = (value * 0x85ebca6bu) & 0xffffffffu;
	value ^= value >> 13;
	value = (value * 0xc2b2ae35u) & 0xffffffffu;
	value ^= value >> 16;
	return static_cast<int64_t>(value);
}

// _pick over a constant list of Strings.
Atom pick_atom(State &state, const Atom *options, size_t count, Atom key_text, Atom salt) {
	if (count == 0) {
		return key::empty;
	}
	return options[generated_reward_rules::_roll(state, key_text, salt, static_cast<int64_t>(count))];
}
template <size_t N>
Atom pick_atom(State &state, const Atom (&options)[N], Atom key_text, Atom salt) {
	return pick_atom(state, options, N, key_text, salt);
}

// RARE_RESOURCES and COLLECTIBLE_RESOURCES.
constexpr Atom kRareResources[] = {key::aetherglass, key::embergrain, key::peatwax, key::verdant_grafts, key::brass_scrip, key::memory_salt};
constexpr Atom kCollectibleResources[] = {key::wood, key::ore, key::aetherglass, key::embergrain, key::peatwax, key::verdant_grafts, key::brass_scrip, key::memory_salt};

// PILE_SITES and MINE_SITES, in their literals' order.
struct ResourceSite {
	Atom resource;
	Atom site;
};
constexpr ResourceSite kPileSites[] = {
	{key::wood, key::site_split_wood_pile},
	{key::ore, key::site_quarry_chip_hod},
	{key::gold, key::site_road_writ_purse},
	{key::aetherglass, key::site_aetherglass_splinter_lot},
	{key::embergrain, key::site_embergrain_sample_sack},
	{key::peatwax, key::site_peatwax_votive_bundle},
	{key::verdant_grafts, key::site_verdant_graft_bundle},
	{key::brass_scrip, key::site_brass_scrip_case},
	{key::memory_salt, key::site_memory_salt_jar},
};
constexpr ResourceSite kMineSites[] = {
	{key::wood, key::site_brightwood_sawmill},
	{key::ore, key::site_ridge_quarry},
	{key::gold, key::site_reef_coin_assay},
	{key::aetherglass, key::site_aetherglass_lens_house},
	{key::embergrain, key::site_embergrain_warm_granary},
	{key::peatwax, key::site_peatwax_reed_yard},
	{key::verdant_grafts, key::site_verdant_graft_nursery},
	{key::brass_scrip, key::site_brass_scrip_mint},
	{key::memory_salt, key::site_memory_salt_pan},
};

// PILE_SITES[resource_id] / MINE_SITES[resource_id].
template <size_t N>
Atom site_of(State &state, const ResourceSite (&sites)[N], Atom resource_id) {
	for (const ResourceSite &entry : sites) {
		if (entry.resource == resource_id) {
			return entry.site;
		}
	}
	missing_key(state.text(resource_id));
}

// H3M_COMMON_RESOURCE_BY_SUBTYPE.get(subtype, "").
Atom common_resource(int64_t subtype) {
	return subtype == 0 ? key::wood : (subtype == 2 ? key::ore : (subtype == 6 ? key::gold : key::empty));
}

// H3M_RARE_SUBTYPES.find(subtype).
int64_t rare_subtype_index(int64_t subtype) {
	constexpr int64_t kRareSubtypes[] = {1, 3, 4, 5};
	for (int64_t index = 0; index < 4; ++index) {
		if (kRareSubtypes[index] == subtype) {
			return index;
		}
	}
	return -1;
}

// The HoMM3 types resolve translates.
constexpr int64_t kTypePandora = 6;
constexpr int64_t kTypeBoat = 8;
constexpr int64_t kTypeKeymaster = 10;
constexpr int64_t kTypeCampfire = 12;
constexpr int64_t kTypeCreatureGenerator = 17;
constexpr int64_t kTypeMultiGenerator = 20;
constexpr int64_t kTypeFlotsam = 29;
constexpr int64_t kTypeLeanTo = 39;
constexpr int64_t kTypeMine = 53;
constexpr int64_t kTypeMysticalGarden = 55;
constexpr int64_t kTypeRandomResource = 76;
constexpr int64_t kTypeRefugeeCamp = 78;
constexpr int64_t kTypeResource = 79;
constexpr int64_t kTypeSeaChest = 82;
constexpr int64_t kTypeShipyard = 87;
constexpr int64_t kTypeSpellScroll = 93;
constexpr int64_t kTypeTreasureChest = 101;
constexpr int64_t kTypeSubterraneanGate = 103;
constexpr int64_t kTypeWagon = 105;
constexpr int64_t kTypeWarriorsTomb = 108;
constexpr int64_t kTypeWaterWheel = 109;
constexpr int64_t kTypeWhirlpool = 111;
constexpr int64_t kTypeWindmill = 112;
constexpr int64_t kTypeRandomDwelling = 216;
constexpr int64_t kTypeRandomDwellingByLevel = 217;
constexpr int64_t kTypeRandomDwellingByFaction = 218;
constexpr int64_t kTypeAbandonedMine = 220;
constexpr int64_t kElderTreeType = 102;
constexpr int64_t kFortuneType = 30;

constexpr Atom kWaterWheelSites[] = {key::site_charter_countinghouse, key::site_tide_kiln};
constexpr Atom kWindmillSites[] = {key::site_wind_press, key::site_saw_chain, key::site_smelter_annex};

// VISIT_SITE_BY_TYPE and SPELL_SHRINE_BY_TYPE, in their literals' order.
struct VisitSite {
	int64_t type;
	Atom site;
};
constexpr VisitSite kVisitSites[] = {
	{4, key::site_visit_proving_rostrum},
	{11, key::site_tide_bell_shrine},
	{13, key::site_contract_scribe_booth},
	{14, key::site_root_accord_ring},
	{23, key::site_visit_drum_cairn},
	{27, key::site_lens_calibration_cart},
	{28, key::site_root_accord_ring},
	{30, key::site_root_accord_ring},
	{31, key::site_wayfarer_menders_tent},
	{32, key::site_visit_facet_orrery},
	{37, key::site_lens_calibration_cart},
	{38, key::site_root_accord_ring},
	{41, key::site_visit_grand_archive},
	{47, key::site_visit_arcane_collegium},
	{48, key::site_visit_moonspring},
	{49, key::site_visit_ley_well},
	{51, key::site_visit_bell_spire},
	{52, key::site_root_accord_ring},
	{56, key::site_wayfarer_menders_tent},
	{61, key::site_visit_clamp_forge},
	{64, key::site_furnace_oath_marker},
	{94, key::site_courier_change_post},
	{96, key::site_wayfarer_infirmary},
	{99, key::site_market_caravanserai},
	{100, key::site_visit_lorestone},
	{102, key::site_visit_elder_graft_tree},
	{107, key::site_visit_war_college},
	{110, key::site_ash_cooler_kitchen},
	{221, key::site_market_caravanserai},
};
struct AdventureService { int64_t type; const char *site; };
constexpr AdventureService kAdventureServices[] = {
	{95, "site_wayfarer_lodge"}, {62, "site_captive_stockade"}, {97, "site_whisper_exchange"},
	{35, "site_muster_foundry"}, {7, "site_veiled_bazaar"}, {213, "site_free_company_exchange"},
};
struct SpellShrine {
	int64_t type;
	Atom site;
	int64_t tier;
};
constexpr SpellShrine kSpellShrines[] = {
	{88, key::site_oath_ember_shrine, 1},
	{89, key::site_reedscript_vow_shrine, 2},
	{90, key::site_prism_measure_shrine, 3},
};
constexpr Atom kScoutingSites[] = {key::site_watchtower_beacon, key::site_mist_lighthouse, key::site_hilltop_signal_nest, key::site_marsh_listener_post, key::site_prism_survey_frame, key::site_underway_echo_well, key::site_coast_bell_watch};
constexpr Atom kSignSites[] = {key::site_mile_writ_sign, key::site_reed_knot_waypost, key::site_switchback_cairn, key::site_ash_road_marker, key::site_underway_chalk_index};
constexpr Atom kLandmarkSites[] = {key::site_ember_signal_brazier, key::site_bog_drum_totem, key::site_prism_relay_lens, key::site_thornwake_graft_arch, key::site_brasshollow_gauge_shrine, key::site_veilmourn_bell_mast, key::site_granary_lock_exchange, key::site_blackwater_shrine_marker, key::site_prism_yard_standard};
constexpr Atom kGrowthSites[] = {key::site_visit_bell_spire, key::site_visit_drum_cairn, key::site_visit_clamp_forge, key::site_visit_facet_orrery, key::site_visit_lorestone, key::site_oath_ember_shrine};

// GATE_SITES and GATE_SITES_BY_TERRAIN.
constexpr Atom kGateSites[] = {
	key::site_charter_bar_gate,
	key::site_thorn_seal_gate,
	key::site_brass_toll_arch,
	key::site_reef_chain_boom,
	key::site_frost_toll_bar,
	key::site_ash_sluice_lock,
	key::site_toll_chain_court,
	key::site_root_lease_gate,
	key::site_pressure_rail_stop,
};
struct TerrainGates {
	Atom terrain;
	Atom sites[3];
	size_t count;
};
constexpr TerrainGates kGateSitesByTerrain[] = {
	{key::grass, {key::site_charter_bar_gate, key::site_toll_chain_court, key::site_thorn_seal_gate}, 3},
	{key::dirt, {key::site_charter_bar_gate, key::site_brass_toll_arch, 0}, 2},
	{key::sand, {key::site_toll_chain_court, key::site_reef_chain_boom, 0}, 2},
	{key::snow, {key::site_frost_toll_bar, 0, 0}, 1},
	{key::swamp, {key::site_thorn_seal_gate, key::site_root_lease_gate, key::site_reef_chain_boom}, 3},
	{key::rough, {key::site_brass_toll_arch, key::site_pressure_rail_stop, key::site_charter_bar_gate}, 3},
	{key::underground, {key::site_brass_toll_arch, key::site_pressure_rail_stop, 0}, 2},
	{key::lava, {key::site_ash_sluice_lock, 0, 0}, 1},
};

// H3M_DWELLING_LEVEL by Creature Generator 1 subtype (0 to 79).
constexpr int64_t kDwellingLevel[] = {
	4, 7, 3, 6, 7, 6, 1, 2, 7, 6,
	7, 3, 2, 5, 6, 3, 4, 2, 5, 2,
	1, 1, 2, 5, 7, 3, 2, 3, 7, 1,
	2, 4, 6, 4, 5, 5, 6, 4, 4, 3,
	5, 7, 5, 1, 7, 5, 1, 3, 3, 6,
	4, 6, 5, 4, 1, 2, 1, 2, 4, 1,
	6, 7, 7, 7, 7, 7, 6, 4, 6, 2,
	5, 4, 3, 1, 1, 2, 3, 3, 2, 5,
};

// CREATURE_BANKS. Guard and troop stacks are [HoMM3 creature AI value,
// headcount]; a level without rewards, rares, troops, artifacts or spell_tier
// leaves the vector empty (or the tier 0), which the GDScript reads the same as
// the missing key.
struct NativeStack {
	int64_t creature;
	int64_t count;
};
struct Amount {
	Atom resource;
	int64_t amount;
};
struct BankLevel {
	int64_t chance;
	std::vector<NativeStack> guard;
	std::vector<Amount> rewards;
	std::vector<int64_t> rares;
	std::vector<NativeStack> troops;
	std::vector<Atom> artifacts;
	int64_t spell_tier = 0;
};
struct BankUnit {
	int64_t creature;
	Atom unit_id;
};
struct Bank {
	const char *id;
	Atom site_id;
	std::vector<BankUnit> units;
	std::vector<int64_t> upgrade;
	std::vector<BankLevel> levels;
};

const std::vector<Bank> &creature_banks() {
	static const std::vector<Bank> banks = {
		{"16:0", key::site_brasswake_depot,
			{{1266, key::unit_neutral_gaugecoil_orewyrms}, {1443, key::unit_neutral_gaugecoil_orewyrms}},
			{1266, 1443},
			{
				{30, {{1266, 20}}, {{key::wood, 4}, {key::ore, 4}}, {4, 4, 4, 4}},
				{30, {{1266, 30}}, {{key::wood, 6}, {key::ore, 6}}, {6, 6, 6, 6}},
				{30, {{1266, 40}}, {{key::wood, 8}, {key::ore, 8}}, {8, 8, 8, 8}},
				{10, {{1266, 50}}, {{key::wood, 10}, {key::ore, 10}}, {10, 10, 10, 10}},
			}},
		{"16:1", key::site_barrow_vault,
			{{138, key::unit_neutral_kilnward_mallets}, {209, key::unit_neutral_kilnward_mallets}},
			{138, 209},
			{
				{30, {{138, 50}}, {{key::gold, 2500}}, {0, 0, 2, 0}},
				{30, {{138, 75}}, {{key::gold, 4000}}, {0, 0, 3, 0}},
				{30, {{138, 100}}, {{key::gold, 5000}}, {0, 0, 5, 0}},
				{10, {{138, 150}}, {{key::gold, 7500}}, {0, 0, 10, 0}},
			}},
		{"16:2", key::site_glassbound_eyrie,
			{{351, key::unit_neutral_cliffhawk_wardens}, {448, key::unit_neutral_cliffhawk_wardens}, {5019, key::unit_neutral_noonshard_prism_kites}},
			{351, 448},
			{
				{30, {{351, 50}}, {}, {}, {{5019, 1}}},
				{30, {{351, 100}}, {}, {}, {{5019, 2}}},
				{30, {{351, 150}}, {}, {}, {{5019, 3}}},
				{10, {{351, 200}}, {}, {}, {{5019, 4}}},
			}},
		{"16:3", key::site_furnace_vault,
			{{50, key::unit_neutral_charcoal_mauls}, {60, key::unit_neutral_charcoal_mauls}},
			{50, 60},
			{
				{30, {{50, 100}}, {{key::gold, 1000}}, {2, 0, 0, 0}},
				{30, {{50, 150}}, {{key::gold, 1500}}, {3, 0, 0, 0}},
				{30, {{50, 200}}, {{key::gold, 2000}}, {4, 0, 0, 0}},
				{10, {{50, 300}}, {{key::gold, 3000}}, {6, 0, 0, 0}},
			}},
		{"16:4", key::site_drowned_reliquary,
			{{517, key::unit_neutral_mireglass_belltoads}, {577, key::unit_neutral_mireglass_belltoads}},
			{517, 577},
			{
				{30, {{517, 20}}, {{key::gold, 2000}}, {0, 5, 0, 0}},
				{30, {{517, 30}}, {{key::gold, 3000}}, {0, 6, 0, 0}},
				{30, {{517, 40}}, {{key::gold, 4000}}, {0, 8, 0, 0}},
				{10, {{517, 50}}, {{key::gold, 5000}}, {0, 10, 0, 0}},
			}},
		{"16:5", key::site_amber_reliquary,
			{{2016, key::unit_neutral_fenmirror_gallowshells}, {2840, key::unit_neutral_fenmirror_gallowshells}},
			{2016, 2840},
			{
				{30, {{2016, 10}}, {{key::gold, 4000}}, {0, 8, 0, 0}},
				{30, {{2016, 15}}, {{key::gold, 6000}}, {0, 12, 0, 0}},
				{30, {{2016, 20}}, {{key::gold, 8000}}, {0, 16, 0, 0}},
				{10, {{2016, 30}}, {{key::gold, 12000}}, {0, 24, 0, 0}},
			}},
		{"16:6", key::site_hive_of_reeds,
			{{312, key::unit_neutral_bogbell_mauls}, {1350, key::unit_neutral_miremoon_crownmaws}},
			{},
			{
				{30, {{312, 30}}, {}, {}, {{1350, 4}}},
				{30, {{312, 45}}, {}, {}, {{1350, 6}}},
				{30, {{312, 60}}, {}, {}, {{1350, 8}}},
				{10, {{312, 90}}, {}, {}, {{1350, 12}}},
			}},
		{"24", key::site_storm_bell_wreck,
			{{315, key::unit_neutral_tideglass_skyrays}},
			{},
			{
				{30, {{315, 20}}, {{key::gold, 3000}}},
				{30, {{315, 30}}, {{key::gold, 3000}}, {}, {}, {key::treasure}},
				{30, {{315, 40}}, {{key::gold, 4000}}, {}, {}, {key::treasure}},
				{10, {{315, 60}}, {{key::gold, 6000}}, {}, {}, {key::minor}},
			}},
		{"25", key::site_wyrmcrown_hoard,
			{{4872, key::unit_neutral_rootvault_barkhulks}, {4702, key::unit_neutral_deepforge_vaultwyrms}, {8613, key::unit_neutral_quenchbell_ironbacks}, {8721, key::unit_neutral_gloambell_wake_mantas}},
			{},
			{
				{30, {{4872, 8}, {4702, 5}, {8613, 2}, {8721, 1}}, {{key::gold, 20000}}, {}, {}, {key::treasure, key::minor, key::major, key::relic}},
				{30, {{4872, 8}, {4702, 6}, {8613, 3}, {8721, 2}}, {{key::gold, 30000}}, {}, {}, {key::minor, key::major, key::relic, key::relic}},
				{30, {{4872, 8}, {4702, 6}, {8613, 4}, {8721, 3}}, {{key::gold, 40000}}, {}, {}, {key::major, key::relic, key::relic, key::relic}},
				{10, {{4872, 8}, {4702, 7}, {8613, 6}, {8721, 5}}, {{key::gold, 50000}}, {}, {}, {key::relic, key::relic, key::relic, key::relic}},
			}},
		{"63", key::site_mirror_archive,
			{{600, key::unit_neutral_basalt_wardens}, {775, key::unit_neutral_sumpstone_guards}},
			{},
			{
				{100, {{600, 14}, {600, 13}, {600, 13}, {775, 10}, {775, 10}}, {}, {}, {}, {}, 5},
			}},
		{"84", key::site_prism_ossuary,
			{{60, key::unit_veilmourn_bellwake_oars_veteran}, {98, key::unit_veilmourn_wakechain_boarders_veteran}, {252, key::unit_veilmourn_mourning_lanterns_veteran}, {555, key::unit_veilmourn_mirrorkeel_reavers_veteran}},
			{},
			{
				{30, {{60, 30}, {98, 20}}, {{key::gold, 1500}}},
				{30, {{60, 25}, {98, 20}, {252, 5}}, {{key::gold, 2000}}},
				{30, {{60, 20}, {98, 20}, {252, 10}, {555, 5}}, {{key::gold, 2500}}, {}, {}, {key::treasure}},
				{10, {{60, 20}, {98, 20}, {252, 10}, {555, 10}}, {{key::gold, 5000}}, {}, {}, {key::treasure}},
			}},
		{"85", key::site_wreck_locker,
			{{252, key::unit_neutral_tidepool_cutters}},
			{},
			{
				{30, {{252, 10}}, {{key::gold, 2000}}},
				{30, {{252, 15}}, {{key::gold, 3000}}},
				{30, {{252, 25}}, {{key::gold, 4000}}, {}, {}, {key::treasure}},
				{10, {{252, 50}}, {{key::gold, 5000}}, {}, {}, {key::minor}},
			}},
	};
	return banks;
}

// CREATURE_BANKS.has(id).
const Bank *find_bank(const std::string &id) {
	for (const Bank &bank : creature_banks()) {
		if (id == bank.id) {
			return &bank;
		}
	}
	return nullptr;
}

// CREATURE_BANKS[bank_id].
const Bank &bank_of(State &state, Atom bank_id) {
	const Bank *bank = find_bank(state.text(bank_id));
	if (bank == nullptr) {
		missing_key(state.text(bank_id));
	}
	return *bank;
}

// bank.levels[level - 1] (a negative index counts from the end).
const BankLevel &level_row(const Bank &bank, int64_t level) {
	const int64_t asked = gd::sub(level, 1);
	const int64_t size = static_cast<int64_t>(bank.levels.size());
	const int64_t index = asked < 0 ? asked + size : asked;
	if (index < 0 || index >= size) {
		throw state::ScriptError("Out of bounds get index '" + compat::itos(asked) + "' (on base: 'Array')");
	}
	return bank.levels[static_cast<size_t>(index)];
}

// String(bank.units.get(creature, "")).
Atom unit_of(const Bank &bank, int64_t creature) {
	for (const BankUnit &unit : bank.units) {
		if (unit.creature == creature) {
			return unit.unit_id;
		}
	}
	return key::empty;
}

// A new Array of [creature, count] Arrays (a constant's stacks, or its
// duplicate(true)).
ArrayRef stacks_array(State &state, const std::vector<NativeStack> &stacks) {
	const ArrayRef result = state.new_array();
	for (const NativeStack &stack : stacks) {
		const ArrayRef pair = state.new_array();
		state.append(pair, int_value(stack.creature));
		state.append(pair, int_value(stack.count));
		state.append(result, array_value(pair));
	}
	return result;
}

// A new Dictionary of bank.units ({creature: unit_id}, in the literal's order).
DictRef units_dict(State &state, const Bank &bank) {
	const DictRef units = state.new_dict();
	for (const BankUnit &unit : bank.units) {
		state.set(units, int_value(unit.creature), str(unit.unit_id));
	}
	return units;
}

// troops[String(stack.unit_id)] = int(troops.get(String(stack.unit_id), 0)) + int(stack.count)
void add_stack(State &state, DictRef troops, const Value &stack) {
	const Atom unit_id = gd::stringify_or_fallback(state, ai::vmember(state, stack, key::unit_id));
	const int64_t had = gd::to_int(state, state.get(troops, str(unit_id), int_value(0)));
	const int64_t count = gd::to_int(state, ai::vmember(state, stack, key::count));
	state.set(troops, str(unit_id), int_value(gd::add(had, count)));
}

// The spell ids of one tier in spells.json, sorted (_tier_spell_id and
// _scroll_spell_id).
ArrayRef tier_spell_candidates(State &state, int64_t tier) {
	const ArrayRef candidates = state.new_array();
	for (const Value &spell : gd::field_items(state, gd::content_file(state, key::spells_path), str(key::items))) {
		if (gd::is_dict(spell) && gd::int_field(state, spell.ref, key::tier, 0) == tier && text(state, spell.ref, key::id, key::empty) != key::empty) {
			state.append(candidates, str(text(state, spell.ref, key::id, key::empty)));
		}
	}
	sort_strings(state, candidates);
	return candidates;
}

// {PAYLOAD_REWARDS: {resource_id: amount}}.
DictRef rewards_payload(State &state, Atom resource_id, int64_t amount) {
	const DictRef rewards = state.new_dict();
	state.set(rewards, str(resource_id), int_value(amount));
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::payload_rewards), dict_value(rewards));
	return payload;
}

// {PAYLOAD_SPELL_IDS: [spell_id]} if spell_id != "" else {}.
DictRef spell_payload(State &state, Atom spell_id) {
	const DictRef payload = state.new_dict();
	if (spell_id != key::empty) {
		const ArrayRef spell_ids = state.new_array();
		state.append(spell_ids, str(spell_id));
		state.set(payload, str(key::payload_spell_ids), array_value(spell_ids));
	}
	return payload;
}

} // namespace

namespace generated_reward_rules {

DictRef resolve(State &state, DictRef object, ArrayRef towns, ArrayRef terrain_rows) {
	const int64_t type_id = gd::int_field(state, object, key::h3m_type_id, -1);
	const int64_t subtype = gd::int_field(state, object, key::h3m_subtype, -1);
	const Atom key_text = gd::strip_edges(state, text(state, object, key::placement_id, key::empty));
	if (type_id < 0 || key_text == key::empty) {
		return state.new_dict();
	}
	if (one_of(type_id, {9, 33, 212, 215, 219})) {
		return _node(state, object, _gate_site(state, object, key_text, terrain_rows), key::resource_site, state.new_dict());
	}
	if (one_of(type_id, {43, 44, 45})) {
		// PORTAL_SITES.
		const Atom site = type_id == 45 ? key::site_wayring : (type_id == 43 ? key::site_waygate : key::site_wayfall);
		return _node(state, object, site, text(state, object, key::kind, key::resource_site), state.new_dict());
	}
	const Atom bank_id = bank_key(state, type_id, subtype);
	if (bank_id != key::empty) {
		return _creature_bank(state, object, key_text, bank_id);
	}
	if (type_id == kTypePandora) {
		return _pandora(state, object, key_text);
	}
	if (type_id == kTypeWarriorsTomb) {
		return _warriors_tomb(state, object, key_text);
	}
	switch (type_id) {
		case kTypeShipyard:
			return _node(state, object, key::site_shipyard, key::resource_site, state.new_dict());
		case kTypeWhirlpool:
			return _node(state, object, key::site_whirlpool, key::resource_site, state.new_dict());
		case kTypeSubterraneanGate:
			return _node(state, object, key::site_basalt_undergate, text(state, object, key::kind, key::resource_site), state.new_dict());
		case kTypeCreatureGenerator: {
			const int64_t level = subtype >= 0 && subtype < 80 ? kDwellingLevel[subtype] : 0;
			if (level <= 0) {
				return state.new_dict();
			}
			const bool neutral = one_of(subtype, {62, 63, 64, 65, 66, 67, 73, 74, 75, 76, 77, 78, 79});
			return _dwelling(state, object, key_text, level, neutral ? key::empty : _nearest_town_faction(state, object, towns));
		}
		case kTypeMultiGenerator: {
			// MULTI_DWELLING_BY_SUBTYPE.get(subtype, MULTI_DWELLING_BY_SUBTYPE[0])
			const Atom site = subtype == 1 ? key::site_three_gauge_chapter_foundry : key::site_five_bough_veteran_grove;
			return _node(state, object, site, text(state, object, key::kind, key::neutral_dwelling), state.new_dict());
		}
		case kTypeRefugeeCamp:
			return _node(state, object, key::site_dwelling_drifters_camp, text(state, object, key::kind, key::neutral_dwelling), state.new_dict());
		case kTypeRandomDwelling:
		case kTypeRandomDwellingByFaction: {
			const int64_t tier = _weighted_tier(state, key_text);
			return _dwelling(state, object, key_text, tier, _nearest_town_faction(state, object, towns));
		}
		case kTypeRandomDwellingByLevel: {
			const int64_t tier = compat::engine_clamp<int64_t>(gd::add(subtype, 1), 1, 7);
			return _dwelling(state, object, key_text, tier, _nearest_town_faction(state, object, towns));
		}
		case kTypeResource: {
			Atom resource_id = common_resource(subtype);
			if (resource_id == key::empty && rare_subtype_index(subtype) >= 0) {
				resource_id = pick_atom(state, kRareResources, key_text, key::rare);
			}
			return resource_id != key::empty ? _pile(state, object, key_text, resource_id) : state.new_dict();
		}
		case kTypeRandomResource:
			return _pile(state, object, key_text, _random_resource_id(state, key_text));
		case kTypeLeanTo: {
			const Atom resource_id = pick_atom(state, kCollectibleResources, key_text, key::lean_to);
			const Atom site = site_of(state, kPileSites, resource_id);
			const DictRef payload = rewards_payload(state, resource_id, _roll_range(state, key_text, key::amount, 1, 5));
			return _node(state, object, site, key::reward_reference, payload, resource_id);
		}
		case kTypeWagon: {
			const Atom resource_id = pick_atom(state, kCollectibleResources, key_text, key::wagon);
			const Atom site = site_of(state, kPileSites, resource_id);
			const DictRef payload = rewards_payload(state, resource_id, _roll_range(state, key_text, key::amount, 2, 5));
			return _node(state, object, site, key::reward_reference, payload, resource_id);
		}
		case kTypeCampfire: {
			const Atom resource_id = pick_atom(state, kCollectibleResources, key_text, key::campfire);
			const DictRef rewards = state.new_dict();
			state.set(rewards, str(key::gold), int_value(gd::mul(100, _roll_range(state, key_text, key::gold, 4, 6))));
			state.set(rewards, str(resource_id), int_value(_roll_range(state, key_text, key::amount, 4, 6)));
			const DictRef payload = state.new_dict();
			state.set(payload, str(key::payload_rewards), dict_value(rewards));
			return _node(state, object, key::site_wayfarer_camp_cache, key::reward_reference, payload);
		}
		case kTypeFlotsam: {
			// hauls[_roll(key, "haul", hauls.size())] of a new
			// [{"wood": 5}, {"wood": 5, "gold": 200}, {"wood": 10, "gold": 500}].
			const int64_t haul_index = _roll(state, key_text, key::haul, 3);
			const DictRef haul = state.new_dict();
			state.set(haul, str(key::wood), int_value(haul_index == 2 ? 10 : 5));
			if (haul_index > 0) {
				state.set(haul, str(key::gold), int_value(haul_index == 2 ? 500 : 200));
			}
			const DictRef payload = state.new_dict();
			state.set(payload, str(key::payload_rewards), dict_value(haul));
			return _node(state, object, key::site_millroad_plank_stack, key::reward_reference, payload);
		}
		case kTypeSeaChest:
			return _node(state, object, site_of(state, kPileSites, key::gold), key::reward_reference, rewards_payload(state, key::gold, 1500), key::gold);
		case kTypeTreasureChest: {
			// TREASURE_CHEST_TIERS: [gold, experience].
			constexpr int64_t kTiers[3][2] = {{1000, 500}, {1500, 1000}, {2000, 1500}};
			const int64_t *tier = kTiers[_roll(state, key_text, key::tier, 3)];
			const DictRef rewards = state.new_dict();
			state.set(rewards, str(key::gold), int_value(tier[0]));
			const DictRef payload = state.new_dict();
			state.set(payload, str(key::payload_rewards), dict_value(rewards));
			state.set(payload, str(key::payload_reward_choices), array_value(treasure_chest_choices(state, tier[0], tier[1])));
			return _node(state, object, key::site_waystone_cache, key::reward_reference, payload);
		}
		case kTypeSpellScroll: {
			const Atom spell_id = _scroll_spell_id(state, key_text);
			return _node(state, object, key::site_spell_scroll, key::reward_reference, spell_payload(state, spell_id));
		}
		case kTypeMine: {
			Atom mine_resource = common_resource(subtype);
			if (mine_resource == key::empty && rare_subtype_index(subtype) >= 0) {
				mine_resource = pick_atom(state, kRareResources, key_text, key::rare_mine);
			}
			if (mine_resource == key::empty) {
				return state.new_dict();
			}
			return _node(state, object, site_of(state, kMineSites, mine_resource), key::mine, state.new_dict(), mine_resource);
		}
		case kTypeAbandonedMine: {
			// _pick(MINE_SITES.keys(), key, "abandoned_mine")
			constexpr size_t kMineCount = sizeof(kMineSites) / sizeof(kMineSites[0]);
			const Atom mine_resource = kMineSites[_roll(state, key_text, key::abandoned_mine, static_cast<int64_t>(kMineCount))].resource;
			return _node(state, object, site_of(state, kMineSites, mine_resource), key::mine, state.new_dict(), mine_resource);
		}
		case kTypeWaterWheel:
			return _node(state, object, pick_atom(state, kWaterWheelSites, key_text, key::water_wheel), key::resource_site, state.new_dict());
		case kTypeWindmill: {
			const Atom site_id = pick_atom(state, kWindmillSites, key_text, key::windmill);
			const DictRef payload = state.new_dict();
			if (site_id == key::site_wind_press) {
				const Atom resource_id = pick_atom(state, kRareResources, key_text, key::wind_press);
				const DictRef rewards = state.new_dict();
				state.set(rewards, str(resource_id), int_value(_roll_range(state, key_text, key::amount, 3, 6)));
				state.set(payload, str(key::payload_rewards), dict_value(rewards));
			}
			return _node(state, object, site_id, key::resource_site, payload);
		}
		case kTypeMysticalGarden:
			return _node(state, object, key::site_orchard_levy_post, key::resource_site, state.new_dict());
		default:
			break;
	}
	return _visit_building(state, object, key_text, type_id);
}

DictRef _visit_building(State &state, DictRef object, Atom key_text, int64_t type_id) {
	for (const auto &service : kAdventureServices) if (service.type == type_id) return _node(state, object, state.intern(service.site), key::resource_site, state.new_dict());
	for (const SpellShrine &shrine : kSpellShrines) {
		if (shrine.type == type_id) {
			const Atom spell_id = _tier_spell_id(state, key_text, shrine.tier);
			return _node(state, object, shrine.site, key::resource_site, spell_payload(state, spell_id));
		}
	}
	for (const VisitSite &visit : kVisitSites) {
		if (visit.type != type_id) {
			continue;
		}
		const DictRef payload = state.new_dict();
		if (type_id == kElderTreeType) {
			// HoMM3: a third of the trees are free, a third ask 2,000 gold, a third 10 of a rare.
			const int64_t price = _roll(state, key_text, key::tree_price, 3);
			if (price == 1 || price == 2) {
				const DictRef cost = state.new_dict();
				if (price == 1) {
					state.set(cost, str(key::gold), int_value(2000));
				} else {
					state.set(cost, str(pick_atom(state, kRareResources, key_text, key::tree_rare)), int_value(10));
				}
				const DictRef visit_payload = state.new_dict();
				state.set(visit_payload, str(key::cost), dict_value(cost));
				state.set(payload, str(key::payload_visit), dict_value(visit_payload));
			}
		} else if (type_id == kFortuneType) {
			const DictRef boosts = state.new_dict();
			state.set(boosts, str(key::momentum), int_value(_roll_range(state, key_text, key::fortune, 1, 3)));
			const DictRef effects = state.new_dict();
			state.set(effects, str(key::battle_boosts), dict_value(boosts));
			const DictRef visit_payload = state.new_dict();
			state.set(visit_payload, str(key::effects), dict_value(effects));
			state.set(payload, str(key::payload_visit), dict_value(visit_payload));
		}
		return _node(state, object, visit.site, key::resource_site, payload);
	}
	if (one_of(type_id, {42, 58, 60})) {
		return _node(state, object, pick_atom(state, kScoutingSites, key_text, key::scouting), key::resource_site, state.new_dict());
	}
	if (one_of(type_id, {59, 91})) {
		return _node(state, object, pick_atom(state, kSignSites, key_text, key::sign), key::resource_site, state.new_dict());
	}
	if (type_id == 57) {
		return _node(state, object, pick_atom(state, kLandmarkSites, key_text, key::landmark), key::resource_site, state.new_dict());
	}
	if (one_of(type_id, {81, 104, 113})) {
		return _node(state, object, pick_atom(state, kGrowthSites, key_text, key::learning), key::resource_site, state.new_dict());
	}
	if (text(state, object, key::native_authored_pool_id, key::empty) == key::interactable_site) {
		return _node(state, object, _pick(state, _visit_fallback_sites(state), key_text, key::visit_fallback), key::resource_site, state.new_dict());
	}
	return state.new_dict();
}

bool is_skipped(State &state, DictRef object) {
	const int64_t type_id = gd::int_field(state, object, key::h3m_type_id, -1);
	return type_id == kTypeBoat || type_id == kTypeKeymaster || native_transit_rules::is_dead_end(state, object);
}

DictRef boat_tile(State &state, DictRef object) {
	if (gd::int_field(state, object, key::h3m_type_id, -1) != kTypeBoat) {
		return state.new_dict();
	}
	const DictRef visit = dict_field_or_new(state, object, key::visit_tile);
	const int64_t level = gd::to_int(state, state.get(visit, str(key::level), gd::field_or(state, object, key::level, int_value(0))));
	const int64_t x = gd::to_int(state, state.get(visit, str(key::x), gd::field_or(state, object, key::x, int_value(0))));
	const int64_t y = gd::to_int(state, state.get(visit, str(key::y), gd::field_or(state, object, key::y, int_value(0))));
	const DictRef tile = state.new_dict();
	state.set(tile, str(key::x), int_value(x));
	state.set(tile, str(key::y), int_value(y));
	state.set(tile, str(key::level), int_value(level));
	return tile;
}

Atom _gate_site(State &state, DictRef object, Atom key_text, ArrayRef terrain_rows) {
	const Atom *options = kGateSites;
	size_t count = sizeof(kGateSites) / sizeof(kGateSites[0]);
	const int64_t x = gd::int_field(state, object, key::x, -1);
	const int64_t y = gd::int_field(state, object, key::y, -1);
	if (gd::int_field(state, object, key::level, 0) == 0 && y >= 0 && y < state.array_size(terrain_rows)) {
		const Value row = state.at(terrain_rows, y);
		if (gd::is_array(row) && x >= 0 && x < state.array_size(row.ref)) {
			const Atom terrain = content_service::normalize_terrain_id(state, gd::stringify_or_fallback(state, state.at(row.ref, x)));
			// GATE_SITES_BY_TERRAIN.get(terrain, GATE_SITES)
			for (const TerrainGates &entry : kGateSitesByTerrain) {
				if (entry.terrain == terrain) {
					options = entry.sites;
					count = entry.count;
					break;
				}
			}
		}
	}
	return pick_atom(state, options, count, key_text, key::gate);
}

DictRef _dwelling(State &state, DictRef object, Atom key_text, int64_t tier, Atom faction_id) {
	const DictRef pools = _dwelling_pools(state);
	Atom site_id = key::empty;
	for (int64_t distance = 0; distance < 7; ++distance) {
		for (const int64_t candidate_tier : {gd::sub(tier, distance), gd::add(tier, distance)}) {
			if (candidate_tier < 1 || candidate_tier > 7 || site_id != key::empty) {
				continue;
			}
			// var faction_pool: Array = pools.get("%s|%d" % [...], []) if faction_id != "" else []
			ArrayRef pool = 0;
			bool found_pool = false;
			if (faction_id != key::empty) {
				Value faction_pool;
				const Atom pool_key = state.intern(state.text(faction_id) + "|" + compat::itos(candidate_tier));
				if (state.lookup(pools, str(pool_key), faction_pool)) {
					pool = gd::as_array(faction_pool);
					found_pool = state.array_size(pool) > 0;
				}
			}
			// var pool: Array = faction_pool if not faction_pool.is_empty() else pools.get("|%d" % tier, [])
			if (!found_pool) {
				Value neutral_pool;
				if (state.lookup(pools, str(state.intern("|" + compat::itos(candidate_tier))), neutral_pool)) {
					pool = gd::as_array(neutral_pool);
					found_pool = state.array_size(pool) > 0;
				}
			}
			if (found_pool) {
				site_id = _pick(state, pool, key_text, key::dwelling);
			}
		}
		if (site_id != key::empty) {
			break;
		}
	}
	if (site_id == key::empty) {
		return state.new_dict();
	}
	return _node(state, object, site_id, text(state, object, key::kind, key::neutral_dwelling), state.new_dict());
}

DictRef _dwelling_pools(State &state) {
	const DictRef cache = gd::as_dict(gd::static_var(state, key::generated_reward_rules_script, key::_dwelling_pool_cache));
	if (!gd::is_empty(state, cache)) {
		return cache;
	}
	for (const Value &site : gd::field_items(state, gd::content_file(state, key::resource_sites_path), str(key::items))) {
		if (!gd::is_dict(site) || text(state, site.ref, key::family, key::empty) != key::neutral_dwelling ||
				text(state, site.ref, key::dwelling_kind, key::single) != key::single) {
			continue;
		}
		const Atom site_id = text(state, site.ref, key::id, key::empty);
		// var recruits = site.get("weekly_recruits", {}): a missing one is empty.
		Value recruits;
		const bool has_recruits = state.lookup(site.ref, str(key::weekly_recruits), recruits);
		if (gd::is_empty(state, gd::content_row(state, state::ContentTable::MapObjectForResourceSite, site_id))) {
			continue;
		}
		if (!has_recruits || !gd::is_dict(recruits) || state.dict_size(recruits.ref) != 1) {
			continue;
		}
		// String(recruits.keys()[0])
		const Atom recruit_id = gd::stringify_or_fallback(state, *gd::items(state, recruits).begin());
		const DictRef unit = gd::content_row(state, state::ContentTable::Unit, recruit_id);
		const Atom faction = text(state, unit, key::faction_id, key::empty);
		const int64_t unit_tier = gd::int_field(state, unit, key::tier, 1);
		const Atom pool_key = state.intern(state.text(faction) + "|" + compat::itos(unit_tier));
		// var pool: Array = _dwelling_pool_cache.get(pool_key, [])
		Value found;
		const ArrayRef pool = state.lookup(cache, str(pool_key), found) ? gd::as_array(found) : state.new_array();
		state.append(pool, str(site_id));
		state.set(cache, str(pool_key), array_value(pool));
	}
	// for pool_key in _dwelling_pool_cache.keys(): _dwelling_pool_cache[pool_key].sort()
	const ArrayRef pool_keys = gd::keys(state, cache);
	for (const Value &pool_key : gd::items(state, array_value(pool_keys))) {
		sort_strings(state, gd::as_array(gd::index(state, cache, pool_key)));
	}
	return cache;
}

Atom _nearest_town_faction(State &state, DictRef object, ArrayRef towns) {
	Atom best = key::empty;
	int64_t best_distance = int64_t(1) << 30;
	const int64_t level = gd::int_field(state, object, key::level, 0);
	for (const Value &town : gd::items(state, array_value(towns))) {
		if (!gd::is_dict(town) || gd::int_field(state, town.ref, key::level, 0) != level) {
			continue;
		}
		const int64_t town_x = gd::int_field(state, town.ref, key::x, 0);
		const int64_t object_x = gd::int_field(state, object, key::x, 0);
		const int64_t town_y = gd::int_field(state, town.ref, key::y, 0);
		const int64_t object_y = gd::int_field(state, object, key::y, 0);
		const int64_t distance = gd::add(compat::absi(gd::sub(town_x, object_x)), compat::absi(gd::sub(town_y, object_y)));
		Atom faction_id = text(state, town.ref, key::faction_id, key::empty);
		if (faction_id == key::empty) {
			const DictRef town_row = gd::content_row(state, state::ContentTable::Town, text(state, town.ref, key::town_id, key::empty));
			faction_id = text(state, town_row, key::faction_id, key::empty);
		}
		if (faction_id != key::empty && distance < best_distance) {
			best_distance = distance;
			best = faction_id;
		}
	}
	return best;
}

int64_t _weighted_tier(State &state, Atom key_text) {
	// RANDOM_DWELLING_TIER_WEIGHTS of tiers 1 to 7.
	constexpr int64_t kWeights[] = {25, 20, 18, 15, 10, 7, 5};
	int64_t total = 0;
	for (const int64_t weight : kWeights) {
		total += weight;
	}
	int64_t roll = _roll(state, key_text, key::dwelling_tier, total);
	for (int64_t tier = 1; tier <= 7; ++tier) {
		roll -= kWeights[tier - 1];
		if (roll < 0) {
			return tier;
		}
	}
	return 1;
}

ArrayRef _visit_fallback_sites(State &state) {
	const ArrayRef sites = state.new_array();
	for (const VisitSite &visit : kVisitSites) {
		if (!gd::array_has(state, sites, str(visit.site))) {
			state.append(sites, str(visit.site));
		}
	}
	for (const SpellShrine &shrine : kSpellShrines) {
		state.append(sites, str(shrine.site));
	}
	sort_strings(state, sites);
	return sites;
}

Atom _tier_spell_id(State &state, Atom key_text, int64_t tier) {
	return _pick(state, tier_spell_candidates(state, tier), key_text, key::shrine_spell);
}

ArrayRef treasure_chest_choices(State &state, int64_t gold, int64_t experience) {
	const ArrayRef choices = state.new_array();
	const DictRef gold_choice = state.new_dict();
	state.set(gold_choice, str(key::id), str(key::gold));
	state.set(gold_choice, str(key::label), str(state.intern("Take " + state.text(_thousands(state, gold)) + " gold")));
	const DictRef gold_rewards = state.new_dict();
	state.set(gold_rewards, str(key::gold), int_value(gold));
	state.set(gold_choice, str(key::rewards), dict_value(gold_rewards));
	state.append(choices, dict_value(gold_choice));
	const DictRef experience_choice = state.new_dict();
	state.set(experience_choice, str(key::id), str(key::experience));
	state.set(experience_choice, str(key::label), str(state.intern("Gain " + state.text(_thousands(state, experience)) + " experience")));
	const DictRef experience_rewards = state.new_dict();
	state.set(experience_rewards, str(key::experience), int_value(experience));
	state.set(experience_choice, str(key::rewards), dict_value(experience_rewards));
	state.append(choices, dict_value(experience_choice));
	return choices;
}

Atom bank_key(State &state, int64_t type_id, int64_t subtype) {
	const std::string by_subtype = compat::itos(type_id) + ":" + compat::itos(subtype);
	if (find_bank(by_subtype) != nullptr) {
		return state.intern(by_subtype);
	}
	const std::string by_type = compat::itos(type_id);
	return find_bank(by_type) != nullptr ? state.intern(by_type) : key::empty;
}

DictRef _creature_bank(State &state, DictRef object, Atom key_text, Atom bank_id) {
	const Bank &bank = bank_of(state, bank_id);
	const int64_t level = bank_level_roll(state, key_text, bank_id);
	const BankLevel &row = level_row(bank, level);
	// var rewards: Dictionary = row.get("rewards", {}).duplicate()
	const DictRef rewards = state.new_dict();
	for (const Amount &reward : row.rewards) {
		state.set(rewards, str(reward.resource), int_value(reward.amount));
	}
	const ArrayRef rare_order = _rare_order(state, key_text);
	for (size_t index = 0; index < row.rares.size(); ++index) {
		if (row.rares[index] > 0) {
			const Atom resource_id = gd::stringify_or_fallback(state, state.at(rare_order, static_cast<int64_t>(index)));
			const int64_t had = gd::to_int(state, state.get(rewards, str(resource_id), int_value(0)));
			state.set(rewards, str(resource_id), int_value(gd::add(had, row.rares[index])));
		}
	}
	const ArrayRef spell_ids = state.new_array();
	if (row.spell_tier > 0) {
		const Atom spell_id = _tier_spell_id(state, key_text, row.spell_tier);
		if (spell_id != key::empty) {
			state.append(spell_ids, str(spell_id));
		}
	}
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::payload_rewards), dict_value(rewards));
	// _troops_for_native(row.get("troops", []), bank.units): the constants are
	// only read there, so new copies stand in for them.
	const DictRef troops = _troops_for_native(state, stacks_array(state, row.troops), units_dict(state, bank));
	state.set(payload, str(key::payload_recruits), dict_value(troops));
	state.set(payload, str(key::payload_spell_ids), array_value(spell_ids));
	state.set(payload, str(key::payload_vision_radius), int_value(0));
	// row.get("artifacts", []).duplicate()
	const ArrayRef artifacts = state.new_array();
	for (const Atom artifact_class : row.artifacts) {
		state.append(artifacts, str(artifact_class));
	}
	state.set(payload, str(key::payload_artifact_classes), array_value(artifacts));
	const DictRef node = _node(state, object, bank.site_id, key::resource_site, payload);
	state.set(node, str(key::generated_bank_level), int_value(level));
	return node;
}

int64_t bank_level_roll(State &state, Atom key_text, Atom bank_id) {
	const std::vector<BankLevel> &levels = bank_of(state, bank_id).levels;
	int64_t total = 0;
	for (const BankLevel &row : levels) {
		total = gd::add(total, row.chance);
	}
	int64_t roll = _roll(state, key_text, key::bank_level, total);
	for (size_t index = 0; index < levels.size(); ++index) {
		roll = gd::sub(roll, levels[index].chance);
		if (roll < 0) {
			return static_cast<int64_t>(index) + 1;
		}
	}
	return static_cast<int64_t>(levels.size());
}

ArrayRef native_guard_stacks(State &state, Atom key_text, Atom bank_id, int64_t level) {
	// GUARD_STACK_COUNT 5, UPGRADE_CHANCE_PCT 50.
	constexpr int64_t kGuardStackCount = 5;
	const Bank &bank = bank_of(state, bank_id);
	const std::vector<NativeStack> &guard = level_row(bank, level).guard;
	if (guard.size() != 1) {
		return stacks_array(state, guard);
	}
	int64_t upgraded = -1;
	if (!bank.upgrade.empty() && _roll(state, key_text, key::bank_upgrade, 100) < 50) {
		upgraded = _roll(state, key_text, key::bank_upgrade_stack, kGuardStackCount);
	}
	const int64_t total = guard[0].count;
	const ArrayRef stacks = state.new_array();
	for (int64_t index = 0; index < kGuardStackCount; ++index) {
		const int64_t count = total / kGuardStackCount + (index < total % kGuardStackCount ? 1 : 0);
		if (count > 0) {
			const ArrayRef stack = state.new_array();
			state.append(stack, int_value(index == upgraded ? bank.upgrade[1] : guard[0].creature));
			state.append(stack, int_value(count));
			state.append(stacks, array_value(stack));
		}
	}
	return stacks;
}

ArrayRef bank_guard_stacks(State &state, DictRef node) {
	const Atom bank_id = bank_key(state, gd::int_field(state, node, key::h3m_type_id, -1), gd::int_field(state, node, key::h3m_subtype, -1));
	const int64_t level = gd::int_field(state, node, key::generated_bank_level, 0);
	if (bank_id == key::empty || level < 1 || level > static_cast<int64_t>(bank_of(state, bank_id).levels.size())) {
		return state.new_array();
	}
	const ArrayRef native = native_guard_stacks(state, text(state, node, key::placement_id, key::empty), bank_id, level);
	const Bank &bank = bank_of(state, bank_id);
	const ArrayRef unit_ids = state.new_array();
	for (const Value &stack : gd::items(state, array_value(native))) {
		state.append(unit_ids, str(unit_of(bank, gd::to_int(state, ai::vindex(state, stack, int_value(0))))));
	}
	return generated_neutral_encounter_rules::stacks_for_native_budget(state, native, unit_ids);
}

DictRef _troops_for_native(State &state, ArrayRef native_stacks, DictRef units) {
	const ArrayRef unit_ids = state.new_array();
	for (const Value &stack : gd::items(state, array_value(native_stacks))) {
		const int64_t creature = gd::to_int(state, ai::vindex(state, stack, int_value(0)));
		state.append(unit_ids, str(gd::stringify_or_fallback(state, state.get(units, int_value(creature), str(key::empty)))));
	}
	const DictRef troops = state.new_dict();
	const ArrayRef stacks = generated_neutral_encounter_rules::stacks_for_native_budget(state, native_stacks, unit_ids);
	for (const Value &stack : gd::items(state, array_value(stacks))) {
		add_stack(state, troops, stack);
	}
	return troops;
}

ArrayRef _rare_order(State &state, Atom key_text) {
	const ArrayRef order = state.new_array();
	for (const Atom resource_id : kRareResources) {
		state.append(order, str(resource_id));
	}
	// "%s|bank_rare|%s" % [key, a]
	const std::string prefix = state.text(key_text) + "|bank_rare|";
	gd::sort_custom(state, order, [&state, &prefix](const Value &a, const Value &b) {
		return hash32_text(prefix + gd::text(state, a)) < hash32_text(prefix + gd::text(state, b));
	});
	return order;
}

DictRef _warriors_tomb(State &state, DictRef object, Atom key_text) {
	// WARRIORS_TOMB_CLASS_WEIGHTS: treasure 30, minor 50, major 15, relic 5.
	constexpr Atom kClasses[] = {key::treasure, key::minor, key::major, key::relic};
	constexpr int64_t kWeights[] = {30, 50, 15, 5};
	int64_t total = 0;
	for (const int64_t weight : kWeights) {
		total += weight;
	}
	int64_t roll = _roll(state, key_text, key::tomb_class, total);
	Atom artifact_class = key::treasure;
	for (size_t index = 0; index < 4; ++index) {
		roll -= kWeights[index];
		if (roll < 0) {
			artifact_class = kClasses[index];
			break;
		}
	}
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::payload_rewards), dict_value(state.new_dict()));
	state.set(payload, str(key::payload_recruits), dict_value(state.new_dict()));
	state.set(payload, str(key::payload_spell_ids), array_value(state.new_array()));
	state.set(payload, str(key::payload_vision_radius), int_value(0));
	const ArrayRef classes = state.new_array();
	state.append(classes, str(artifact_class));
	state.set(payload, str(key::payload_artifact_classes), array_value(classes));
	const DictRef node = _node(state, object, key::site_basalt_oath_tomb, key::resource_site, payload);
	state.set(node, str(key::generated_reward_unguarded), bool_value(true));
	return node;
}

DictRef _pandora(State &state, DictRef object, Atom key_text) {
	const DictRef contents = dict_field_or_new(state, object, key::h3m_pandora_contents);
	const DictRef rewards = state.new_dict();
	const int64_t experience = gd::int_field(state, contents, key::experience, 0);
	if (experience > 0) {
		state.set(rewards, str(key::experience), int_value(experience_for_h3m(state, experience)));
	}
	const ArrayRef resources = array_field_or_new(state, contents, key::resources);
	const ArrayRef rare_order = _rare_order(state, key_text);
	const int64_t resource_count = compat::engine_min<int64_t>(state.array_size(resources), 7);
	for (int64_t subtype = 0; subtype < resource_count; ++subtype) {
		const int64_t amount = gd::to_int(state, state.at(resources, subtype));
		if (amount <= 0) {
			continue;
		}
		Atom resource_id = common_resource(subtype);
		if (resource_id == key::empty) {
			resource_id = gd::stringify_or_fallback(state, state.at(rare_order, rare_subtype_index(subtype)));
		}
		const int64_t had = gd::to_int(state, state.get(rewards, str(resource_id), int_value(0)));
		state.set(rewards, str(resource_id), int_value(gd::add(had, amount)));
	}
	const ArrayRef creatures = array_field_or_new(state, contents, key::creatures);
	const DictRef troops = state.new_dict();
	const int64_t creature_count = state.array_size(creatures);
	for (int64_t index = 0; index < creature_count; ++index) {
		// var creature: Dictionary = creatures[index] if it is a Dictionary else {}
		const Value creature = state.at(creatures, index);
		const auto creature_int = [&](Atom field) {
			return gd::is_dict(creature) ? gd::int_field(state, creature.ref, field, 0) : int64_t(0);
		};
		const int64_t tier = compat::engine_clamp<int64_t>(gd::add(creature_int(key::level), 1), 1, 7);
		const Atom unit_id = _neutral_unit_for_tier(state, key_text, tier, index);
		const ArrayRef native = state.new_array();
		const ArrayRef stack = state.new_array();
		state.append(stack, int_value(creature_int(key::ai_value)));
		state.append(stack, int_value(creature_int(key::quantity)));
		state.append(native, array_value(stack));
		const ArrayRef unit_ids = state.new_array();
		state.append(unit_ids, str(unit_id));
		const ArrayRef stacks = generated_neutral_encounter_rules::stacks_for_native_budget(state, native, unit_ids);
		for (const Value &budget_stack : gd::items(state, array_value(stacks))) {
			add_stack(state, troops, budget_stack);
		}
	}
	if (gd::is_empty(state, contents)) {
		// A package from before the box contents were exported: HoMM3's
		// smallest gold box.
		state.set(rewards, str(key::gold), int_value(5000));
	}
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::payload_rewards), dict_value(rewards));
	state.set(payload, str(key::payload_recruits), dict_value(troops));
	state.set(payload, str(key::payload_spell_ids), array_value(_pandora_spell_ids(state, contents, key_text)));
	const DictRef node = _node(state, object, key::site_hushlock_casket, key::reward_reference, payload);
	state.set(node, str(key::generated_reward_unguarded), bool_value(true));
	return node;
}

int64_t experience_for_h3m(State &state, int64_t amount) {
	// H3M_LEVEL_EXPERIENCE: HoMM3 experience for hero levels 1 to 15.
	constexpr int64_t kTable[] = {0, 1000, 2000, 3200, 4600, 6200, 8000, 10000, 12200, 14700, 17500, 20600, 24320, 28784, 34140};
	constexpr int64_t kSize = sizeof(kTable) / sizeof(kTable[0]);
	int64_t index = 0;
	while (index + 2 < kSize && amount >= kTable[index + 1]) {
		index += 1;
	}
	const double span = static_cast<double>(kTable[index + 1] - kTable[index]);
	const double fraction = compat::engine_clamp(static_cast<double>(gd::sub(amount, kTable[index])) / span, 0.0, 1.0);
	const int64_t level = index + 1;
	const double low = static_cast<double>(hero_progression_rules::experience_for_level(state, level));
	const double high = static_cast<double>(hero_progression_rules::experience_for_level(state, level + 1));
	const double scaled = (high - low) * fraction;
	return gd::mul(compat::float_to_int(compat::godot_round((low + scaled) / 50.0)), 50);
}

ArrayRef _pandora_spell_ids(State &state, DictRef contents, Atom key_text) {
	const ArrayRef levels = array_field_or_new(state, contents, key::spell_levels);
	if (state.array_size(levels) == 0) {
		return state.new_array();
	}
	const ArrayRef masks = array_field_or_new(state, contents, key::spell_school_masks);
	int64_t common_school = 15;
	for (const Value &mask : gd::items(state, array_value(masks))) {
		common_school &= gd::to_int(state, mask);
	}
	// var spells: Array = ContentService.load_json(...).get("items", [])
	const DictRef file = gd::content_file(state, key::spells_path);
	Value spells_value;
	const ArrayRef spells = state.lookup(file, str(key::items), spells_value) ? gd::as_array(spells_value) : state.new_array();
	Atom school_id = key::empty;
	if (one_of(common_school, {1, 2, 4, 8})) {
		const ArrayRef schools = state.new_array();
		for (const Value &spell : gd::items(state, array_value(spells))) {
			if (gd::is_dict(spell) && text(state, spell.ref, key::school_id, key::empty) != key::empty &&
					!gd::array_has(state, schools, str(text(state, spell.ref, key::school_id, key::empty)))) {
				state.append(schools, str(text(state, spell.ref, key::school_id, key::empty)));
			}
		}
		sort_strings(state, schools);
		school_id = _pick(state, schools, key_text, key::pandora_school);
	}
	const ArrayRef spell_ids = state.new_array();
	for (const Value &spell : gd::items(state, array_value(spells))) {
		if (!gd::is_dict(spell) || text(state, spell.ref, key::id, key::empty) == key::empty) {
			continue;
		}
		if (gd::array_has(state, levels, int_value(gd::int_field(state, spell.ref, key::tier, 0))) &&
				(school_id == key::empty || text(state, spell.ref, key::school_id, key::empty) == school_id)) {
			state.append(spell_ids, str(text(state, spell.ref, key::id, key::empty)));
		}
	}
	sort_strings(state, spell_ids);
	return spell_ids;
}

Atom _neutral_unit_for_tier(State &state, Atom key_text, int64_t tier, int64_t index) {
	const ArrayRef candidates = state.new_array();
	for (const Value &unit : gd::field_items(state, gd::content_file(state, key::units_path), str(key::items))) {
		if (gd::is_dict(unit) && text(state, unit.ref, key::faction_id, key::empty) == key::empty && gd::int_field(state, unit.ref, key::tier, 0) == tier) {
			state.append(candidates, str(text(state, unit.ref, key::id, key::empty)));
		}
	}
	sort_strings(state, candidates);
	// "pandora_unit_%d" % index
	return _pick(state, candidates, key_text, state.intern("pandora_unit_" + compat::itos(index)));
}

DictRef _pile(State &state, DictRef object, Atom key_text, Atom resource_id) {
	int64_t amount = 0;
	if (resource_id == key::gold) {
		amount = gd::mul(100, _roll_range(state, key_text, key::amount, 5, 10));
	} else if (has_atom(resource_id, kRareResources)) {
		amount = _roll_range(state, key_text, key::amount, 3, 6);
	} else {
		amount = _roll_range(state, key_text, key::amount, 5, 10);
	}
	const Atom site = site_of(state, kPileSites, resource_id);
	return _node(state, object, site, key::reward_reference, rewards_payload(state, resource_id, amount), resource_id);
}

DictRef _node(State &state, DictRef object, Atom site_id, Atom kind, DictRef payload, Atom resource_id) {
	const DictRef node = gd::deep_duplicate_dict(state, object);
	state.set(node, str(key::site_id), str(site_id));
	state.set(node, str(key::kind), str(kind));
	state.set(node, str(key::native_record_kind), str(kind));
	if (resource_id != key::empty) {
		state.set(node, str(key::resource_id), str(resource_id));
	} else {
		state.erase(node, str(key::resource_id));
	}
	// ContentService.get_map_object_for_resource_site(site_id).
	const DictRef map_object = gd::content_row(state, state::ContentTable::MapObjectForResourceSite, site_id);
	const Atom object_id = gd::strip_edges(state, text(state, map_object, key::id, key::empty));
	if (object_id != key::empty) {
		state.set(node, str(key::object_id), str(object_id));
	}
	for (const Value &payload_key : gd::items(state, array_value(gd::keys(state, payload)))) {
		state.set(node, payload_key, gd::index(state, payload, payload_key));
	}
	const std::string translation = "h3m_type_" + compat::itos(gd::int_field(state, object, key::h3m_type_id, -1));
	state.set(node, str(key::generated_reward_translation), str(state.intern(translation)));
	return node;
}

Atom _random_resource_id(State &state, Atom key_text) {
	// HoMM3 rolls the seven resources evenly; the four rare slots spread over six rares.
	const int64_t subtype = _roll(state, key_text, key::random_resource, 7);
	const Atom resource_id = common_resource(subtype);
	return resource_id != key::empty ? resource_id : pick_atom(state, kRareResources, key_text, key::rare);
}

Atom _scroll_spell_id(State &state, Atom key_text) {
	// SCROLL_TIER_WEIGHTS of tiers 1 to 4.
	constexpr int64_t kWeights[] = {40, 30, 20, 10};
	int64_t total = 0;
	for (const int64_t weight : kWeights) {
		total += weight;
	}
	int64_t roll = _roll(state, key_text, key::scroll_tier, total);
	int64_t chosen_tier = 1;
	for (int64_t tier = 1; tier <= 4; ++tier) {
		roll -= kWeights[tier - 1];
		if (roll < 0) {
			chosen_tier = tier;
			break;
		}
	}
	const ArrayRef candidates = tier_spell_candidates(state, chosen_tier);
	return state.array_size(candidates) > 0 ? _pick(state, candidates, key_text, key::scroll_spell) : key::empty;
}

Atom _pick(State &state, ArrayRef options, Atom key_text, Atom salt) {
	if (state.array_size(options) == 0) {
		return key::empty;
	}
	return gd::stringify_or_fallback(state, state.at(options, _roll(state, key_text, salt, state.array_size(options))));
}

int64_t _roll_range(State &state, Atom key_text, Atom salt, int64_t low, int64_t high) {
	return gd::add(low, _roll(state, key_text, salt, gd::add(gd::sub(high, low), 1)));
}

int64_t _roll(State &state, Atom key_text, Atom salt, int64_t count) {
	// _hash32("%s|%s" % [key, salt]) % max(1, count): the hash is never negative.
	const int64_t hash = hash32_text(state.text(key_text) + "|" + state.text(salt));
	return hash % compat::engine_max<int64_t>(1, count);
}

int64_t _hash32(State &state, Atom text) {
	return hash32_text(state.text(text));
}

Atom _thousands(State &state, int64_t value) {
	std::string digits = compat::itos(value);
	std::string grouped;
	while (digits.size() > 3) {
		grouped = "," + digits.substr(digits.size() - 3) + grouped;
		digits = digits.substr(0, digits.size() - 3);
	}
	return state.intern(digits + grouped);
}

} // namespace generated_reward_rules

} // namespace aurelion::rules::port
