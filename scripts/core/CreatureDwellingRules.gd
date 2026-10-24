extends RefCounted
## HoMM3-style creature dwellings. A dwelling makes one creature (a few
## multi-creature dwellings make several) at that creature's weekly growth.
## A hero hires them at the dwelling; tier 1 creatures are free. Unhired
## creatures do not carry over: the population resets each week. Tier 5 and
## higher dwellings keep a guard of three weeks of their creature, and every
## side has to beat that guard once before it can flag the dwelling. Each
## flagged dwelling adds +1 weekly growth for its creature in the owner's
## towns. See docs/creature-dwellings.md.

const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

const FAMILY := "neutral_dwelling"
const KIND_REFUGEE_CAMP := "refugee_camp"
const POPULATION := "dwelling_population"
const POPULATION_WEEK := "dwelling_week"
const GUARD_BEATEN := "dwelling_guard_beaten"
const GUARD_SURVIVORS := "dwelling_guard_survivors"
const WEEK_LENGTH := 7
const GUARD_MIN_TIER := 5
const GUARD_WEEKS := 3
const FREE_TIER := 1
const NODE_KEYS := [POPULATION, POPULATION_WEEK, GUARD_BEATEN, GUARD_SURVIVORS]

static var _refugee_pool: Array = []
static var _base_by_upgrade: Dictionary = {}
## AI weight (content/ai_hero_weights.json): the least week_value counts a
## creature worth. AiHeroRules puts a computer player's set in place
## (apply_ai_weights); until it does, the default set.
static var AI_CREATURE_MIN_VALUE: int
static var _ai_weights_ready := false

static func summary(node: Dictionary, site: Dictionary, day: int) -> String:
	return HumanEngine.native(&"CreatureDwellingRules.summary", [node, site, day])
