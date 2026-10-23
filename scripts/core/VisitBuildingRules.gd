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

static func apply_ai_weights(weights: Dictionary) -> void:
	AI_STAT_VALUE = int(weights["visit_stat_value"])
	AI_EXPERIENCE_SHARE = float(weights["visit_experience_share"])
	AI_LEVEL_VALUE = int(weights["visit_level_value"])
	AI_SPELL_TIER_VALUE = int(weights["visit_spell_tier_value"])
	AI_COST_SHARE = float(weights["visit_cost_share"])
	_ai_weights_ready = true

static func is_visit_building(site: Dictionary) -> bool:
	return String(site.get("family", "")) == FAMILY and site.get("visit", {}) is Dictionary

static func spec(site: Dictionary) -> Dictionary:
	var value = site.get("visit", {})
	return value if value is Dictionary else {}

static func cadence(site: Dictionary) -> String:
	return String(spec(site).get("cadence", CADENCE_ONCE_PER_HERO))

static func cost(site: Dictionary, choice_id: String = "") -> Dictionary:
	if choice_id != "":
		for choice in choices(site):
			if choice is Dictionary and String(choice.get("id", "")) == choice_id and choice.get("cost", {}) is Dictionary and not choice.get("cost", {}).is_empty():
				return choice.get("cost", {}).duplicate(true)
	var value = spec(site).get("cost", {})
	return value.duplicate(true) if value is Dictionary else {}

static func required_level(site: Dictionary) -> int:
	return max(0, int(spec(site).get("required_level", 0)))

static func choices(site: Dictionary) -> Array:
	var value = spec(site).get("choices", [])
	return value if value is Array else []

static func effects(site: Dictionary, choice_id: String = "") -> Dictionary:
	if choice_id != "":
		for choice in choices(site):
			if choice is Dictionary and String(choice.get("id", "")) == choice_id:
				var chosen = choice.get("effects", {})
				return chosen.duplicate(true) if chosen is Dictionary else {}
		return {}
	var value = spec(site).get("effects", {})
	return value.duplicate(true) if value is Dictionary else {}

static func week_index(day: int) -> int:
	return int(floor(float(max(1, day) - 1) / float(WEEK_LENGTH)))

## Whether visitor_key (a hero id, or "ai:<faction>" for computer players) may
## use the building on this day. A once-per-side building checks side (the
## visitor key when empty). Returns {ok, message}.
static func readiness(node: Dictionary, site: Dictionary, visitor_key: String, day: int, side: String = "") -> Dictionary:
	var visits = node.get(HERO_VISITS, {})
	if not (visits is Dictionary):
		visits = {}
	match cadence(site):
		CADENCE_ALWAYS:
			pass
		CADENCE_ONCE_PER_SIDE:
			var side_visits = node.get(SIDE_VISITS, {})
			if side_visits is Dictionary and side_visits.has(side if side != "" else visitor_key):
				return {"ok": false, "message": "You have already used %s; what it shows stays revealed." % String(site.get("name", "this site"))}
		CADENCE_WEEKLY_SITE:
			var last_site_day := int(node.get(SITE_LAST_VISIT_DAY, 0))
			if last_site_day > 0 and week_index(last_site_day) == week_index(day):
				return {"ok": false, "message": "%s is spent until the new week begins on day %d." % [String(site.get("name", "This site")), (week_index(day) + 1) * WEEK_LENGTH + 1]}
		CADENCE_WEEKLY_PER_HERO:
			if visits.has(visitor_key) and week_index(int(visits[visitor_key])) == week_index(day):
				return {"ok": false, "message": "This hero already visited %s this week." % String(site.get("name", "this site"))}
		CADENCE_DAILY_PER_HERO:
			if visits.has(visitor_key) and int(visits[visitor_key]) >= day:
				return {"ok": false, "message": "This hero already visited %s today." % String(site.get("name", "this site"))}
		_:
			if visits.has(visitor_key):
				return {"ok": false, "message": "This hero has already visited %s." % String(site.get("name", "this site"))}
	return {"ok": true, "message": ""}

static func record_visit(node: Dictionary, site: Dictionary, visitor_key: String, day: int, side: String = "") -> void:
	var visits = node.get(HERO_VISITS, {})
	if not (visits is Dictionary):
		visits = {}
	visits[visitor_key] = day
	node[HERO_VISITS] = visits
	if cadence(site) == CADENCE_ONCE_PER_SIDE:
		var side_visits = node.get(SIDE_VISITS, {})
		if not (side_visits is Dictionary):
			side_visits = {}
		side_visits[side if side != "" else visitor_key] = day
		node[SIDE_VISITS] = side_visits
	if cadence(site) == CADENCE_WEEKLY_SITE:
		node[SITE_LAST_VISIT_DAY] = day

static func cadence_label(site: Dictionary) -> String:
	return HumanEngine.native(&"VisitBuildingRules.cadence_label", [site])

static func effect_summary(effect: Dictionary) -> String:
	var parts := []
	var gains = effect.get("resources", {})
	if gains is Dictionary and not gains.is_empty():
		parts.append("+%s" % _resource_text(gains))
	var stats = effect.get("stats", {})
	if stats is Dictionary:
		for key in STAT_KEYS:
			if int(stats.get(key, 0)) != 0:
				parts.append("+%d %s" % [int(stats.get(key, 0)), key])
	if int(effect.get("experience", 0)) > 0:
		parts.append("+%s XP" % _thousands(int(effect.get("experience", 0))))
	if int(effect.get("levels", 0)) > 0:
		parts.append("+%d level" % int(effect.get("levels", 0)))
	if int(effect.get("spell_tier", 0)) > 0:
		parts.append("teaches a tier %d spell" % int(effect.get("spell_tier", 0)))
	match String(effect.get("mana", "")):
		"refill":
			parts.append("refills mana")
		"week_double":
			parts.append("double mana until the week ends")
	if int(effect.get("movement", 0)) > 0:
		parts.append("+%d movement now" % int(effect.get("movement", 0)))
	if int(effect.get("week_movement", 0)) > 0:
		parts.append("+%d movement each day this week" % int(effect.get("week_movement", 0)))
	var boosts = effect.get("battle_boosts", {})
	if boosts is Dictionary:
		for key in BOOST_KEYS:
			if int(boosts.get(key, 0)) != 0:
				parts.append("+%d %s next battle" % [int(boosts.get(key, 0)), key])
	var rest_day = effect.get("day7_battle_boosts", {})
	if rest_day is Dictionary:
		for key in BOOST_KEYS:
			if int(rest_day.get(key, 0)) != 0:
				parts.append("+%d more %s on day 7 of the week" % [int(rest_day.get(key, 0)), key])
	if int(effect.get("reveal_radius", 0)) > 0:
		parts.append("reveals the land within %d tiles" % int(effect.get("reveal_radius", 0)))
	if String(effect.get("reveal", "")) == "level":
		parts.append("reveals this map level")
	if bool(effect.get("market", false)):
		parts.append("trades resources")
	return ", ".join(parts)

## One line for tooltips and inspection: effect, price and cadence.
static func summary(site: Dictionary) -> String:
	return HumanEngine.native(&"VisitBuildingRules.summary", [site])

## AI weighting in gold-equivalent value, so computer heroes seek stat, spell
## and growth buildings the way they seek pickups.
static func ai_value(site: Dictionary) -> int:
	if not _ai_weights_ready:
		apply_ai_weights(ContentService.default_ai_hero_weights())
	var effect := effects(site)
	if not choices(site).is_empty():
		var first = choices(site)[0]
		effect = first.get("effects", {}) if first is Dictionary else {}
	var value := 0
	var stats = effect.get("stats", {})
	if stats is Dictionary:
		for key in STAT_KEYS:
			value += AI_STAT_VALUE * max(0, int(stats.get(key, 0)))
	value += int(float(int(effect.get("experience", 0))) * AI_EXPERIENCE_SHARE)
	value += AI_LEVEL_VALUE * max(0, int(effect.get("levels", 0)))
	value += AI_SPELL_TIER_VALUE * max(0, int(effect.get("spell_tier", 0)))
	# Commanders keep only lasting growth; boosts, mana and movement are worth
	# nothing to them yet.
	value -= int(float(int(cost(site).get("gold", 0))) * AI_COST_SHARE)
	return max(0, value)

static func _resource_text(resources: Dictionary) -> String:
	var parts := []
	for key in resources.keys():
		parts.append("%s %s" % [_thousands(int(resources[key])), String(key).replace("_", " ")])
	return ", ".join(parts)

static func _thousands(value: int) -> String:
	var digits := str(value)
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	return digits + grouped
