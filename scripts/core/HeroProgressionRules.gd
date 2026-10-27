class_name HeroProgressionRules
extends RefCounted

const BattleEngine = preload("res://scripts/core/BattleEngine.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")
const NativeRules = preload("res://scripts/core/NativeRules.gd")
const CHOICE_SIZE := 3
const SPECIALTY_INSIGNIA_ATLAS_PATH := "res://art/heroes/runtime/specialties/hero_specialty_insignia_atlas.png"
const SPECIALTY_INSIGNIA_CELL_SIZE := Vector2i(28, 28)
const RANK_LABELS := ["I", "II", "III", "IV"]
## Recruit-growth specialties raise dwellings up to this tier.
const RECRUIT_GROWTH_MAX_TIER := 6
## The specialty catalog: content/hero_specialties.json (ids, names, per-rank
## text and bonuses, icon cells, group and command path).
const SPECIALTIES_PATH := "res://content/hero_specialties.json"
const SPECIALTY_INSIGNIA_ATLAS_SIZE := Vector2i(196, 140)
## Level-up offers lean toward a hero's own focus specialties, then toward
## those of its command path (might: command, magic: magic).
const OFFER_FOCUS_WEIGHT := 4.0
const OFFER_PATH_WEIGHT := 2.5
const OFFER_OTHER_WEIGHT := 1.0
static var _catalog_source: Variant = null
static var _catalog_index := {}
## Each level-up rolls one command stat, weighted by the hero's command path
## (heroes.json): might commanders mostly train attack and defense, magic
## commanders power and knowledge. The roll comes from the hero's growth seed
## and the level reached, so saving, loading or the tavern's preview never
## re-roll it, while each game's heroes draw their own seeds.
const COMMAND_GAIN_WEIGHTS := {
	"might": {"attack": 40, "defense": 40, "power": 10, "knowledge": 10},
	"magic": {"attack": 10, "defense": 10, "power": 40, "knowledge": 40},
}
const COMMAND_STATS := ["attack", "defense", "power", "knowledge"]

static func ensure_hero_progression(hero_state: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"HeroProgressionRules.ensure_hero_progression", [hero_state])

static func level_up_summary(hero_state: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"HeroProgressionRules.level_up_summary", [hero_state])

static func advance_to_level(hero_state: Dictionary, target_level: int) -> Dictionary:
	return HumanEngine.native_writing(&"HeroProgressionRules.advance_to_level", [hero_state, target_level])

static func get_choice_actions(hero_state: Dictionary) -> Array:
	return HumanEngine.native_writing(&"HeroProgressionRules.get_choice_actions", [hero_state])

static func brief_summary(hero_state: Dictionary) -> String:
	return HumanEngine.native_writing(&"HeroProgressionRules.brief_summary", [hero_state])

static func summarize_specialty_ids(specialty_ids: Variant, use_short_names: bool = true) -> String:
	return HumanEngine.native_writing(&"HeroProgressionRules.summarize_specialty_ids", [specialty_ids, use_short_names])

static func pending_choices_remaining(hero_state: Dictionary) -> int:
	return HumanEngine.native_writing(&"HeroProgressionRules.pending_choices_remaining", [hero_state])

static func current_pending_choice(hero_state: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"HeroProgressionRules.current_pending_choice", [hero_state])

static func pending_choice_summary(pending_choice: Dictionary) -> String:
	return HumanEngine.native_writing(&"HeroProgressionRules.pending_choice_summary", [pending_choice])

static func specialty_rank(hero_state: Dictionary, specialty_id: String) -> int:
	return HumanEngine.native_writing(&"HeroProgressionRules.specialty_rank", [hero_state, specialty_id])

## The catalog's specialties in authored order (read-only rows).
static func specialties() -> Array:
	return HumanEngine.native(&"HeroProgressionRules.specialties", [])

static func specialty_definition(specialty_id: String) -> Dictionary:
	return HumanEngine.native(&"HeroProgressionRules.specialty_definition", [specialty_id])

## What `specialty_id` gives at `rank` (1-based), as shown to the player.
static func rank_text(specialty_id: String, rank: int) -> String:
	return HumanEngine.native(&"HeroProgressionRules.rank_text", [specialty_id, rank])

static func _specialty_row(specialty_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"HeroProgressionRules._specialty_row", [specialty_id])

## The catalog rows by id, shared and read-only; rebuilt when the content changes.
static func _specialty_catalog() -> Dictionary:
	return BattleEngine.native_writing(&"HeroProgressionRules._specialty_catalog", [])

static func specialty_id_for_action(action_id: String) -> String:
	return HumanEngine.native(&"HeroProgressionRules.specialty_id_for_action", [action_id])

static func specialty_insignia_description(specialty_id: String) -> String:
	return HumanEngine.native(&"HeroProgressionRules.specialty_insignia_description", [specialty_id])

static func specialty_insignia_texture(specialty_id: String) -> Texture2D:
	var specialty := _specialty_row(specialty_id)
	var region_value: Variant = specialty.get("icon_region", [])
	if specialty.is_empty() \
		or String(specialty.get("icon_id", "")) != "specialty_insignia_%s" % specialty_id \
		or not (region_value is Array) \
		or region_value.size() != 4 \
		or not ResourceLoader.exists(SPECIALTY_INSIGNIA_ATLAS_PATH, "Texture2D"):
		return null
	var region := Rect2(
		float(region_value[0]),
		float(region_value[1]),
		float(region_value[2]),
		float(region_value[3])
	)
	if region.size != Vector2(SPECIALTY_INSIGNIA_CELL_SIZE) \
		or region.position.x < 0.0 \
		or region.position.y < 0.0 \
		or region.end.x > float(SPECIALTY_INSIGNIA_ATLAS_SIZE.x) \
		or region.end.y > float(SPECIALTY_INSIGNIA_ATLAS_SIZE.y):
		return null
	var atlas := load(SPECIALTY_INSIGNIA_ATLAS_PATH) as Texture2D
	if atlas == null or atlas.get_size() != Vector2(SPECIALTY_INSIGNIA_ATLAS_SIZE):
		return null
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = region
	return texture

static func aggregate_bonuses(hero_state: Dictionary) -> Dictionary:
	return BattleEngine.native_writing(&"HeroProgressionRules.aggregate_bonuses", [hero_state])

static func adjusted_mana_cost(hero_state: Dictionary, base_cost: int, school_id: String = "") -> int:
	return BattleEngine.native_writing(&"HeroProgressionRules.adjusted_mana_cost", [hero_state, base_cost, school_id])

static func rank_label(rank: int) -> String:
	return HumanEngine.native(&"HeroProgressionRules.rank_label", [rank])

static func _normalize_specialties_in(catalog: Dictionary, value: Variant) -> Array:
	return BattleEngine.native(&"HeroProgressionRules._normalize_specialties_in", [catalog, value])

static func command_gain_stat(hero_state: Dictionary, level_number: int) -> String:
	return HumanEngine.native_writing(&"HeroProgressionRules.command_gain_stat", [hero_state, level_number])
