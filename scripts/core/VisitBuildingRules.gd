extends RefCounted
## HoMM-style visit buildings: a site that stays on the map and gives a hero
## one clear effect, free unless the site names a price. The placed node keeps
## a visit memory per hero (or per side, or per site for weekly sites), so each
## hero can use a building once, once a day or once a week, and a side can chart
## or survey once. See docs/visit-buildings.md.

const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

const FAMILY := "visit_building"
const HERO_VISITS := "hero_visits"
const SIDE_VISITS := "side_visits"
const SITE_LAST_VISIT_DAY := "site_last_visit_day"
const WEEK_BONUSES := "week_bonuses"
const BATTLE_BOOSTS := "battle_boosts"

const CADENCE_ONCE_PER_HERO := "once_per_hero"
const CADENCE_ONCE_PER_SIDE := "once_per_side"
const CADENCE_DAILY_PER_HERO := "daily_per_hero"
const CADENCE_WEEKLY_PER_HERO := "weekly_per_hero"
const CADENCE_WEEKLY_SITE := "weekly_site"
const CADENCE_ALWAYS := "always"
const WEEK_LENGTH := 7
const STAT_KEYS := ["attack", "defense", "power", "knowledge"]
const BOOST_KEYS := ["cohesion", "momentum"]
const BOOST_CAP := 3
## AI weights (content/ai_hero_weights.json) for ai_value: gold per stat point,
## the share of experience and of the price that counts, gold per level and per
## spell tier. AiHeroRules puts a computer player's set in place
## (apply_ai_weights); until it does, the default set.
static var AI_STAT_VALUE: int
static var AI_EXPERIENCE_SHARE: float
static var AI_LEVEL_VALUE: int
static var AI_SPELL_TIER_VALUE: int
static var AI_COST_SHARE: float
static var _ai_weights_ready := false

static func cadence_label(site: Dictionary) -> String:
	return HumanEngine.native(&"VisitBuildingRules.cadence_label", [site])

static func summary(site: Dictionary) -> String:
	return HumanEngine.native(&"VisitBuildingRules.summary", [site])
