extends RefCounted
## Attack against defense, shared by the battle rules and the battle AI's
## damage estimate. Each point of attack above the target's defense adds 5%
## damage, up to +300%; each point of defense above the attack takes 2.5% off,
## down to -70%. The caps sit past any stat gap the content reaches, so every
## point of hero or creature attack and defense counts.

const BattleEngine = preload("res://scripts/core/BattleEngine.gd")
static var _battle_engine_mode: int = BattleEngine.mode

const ATTACK_BONUS_PER_POINT := 0.05
const ATTACK_BONUS_MAX := 3.0
const DEFENSE_REDUCTION_PER_POINT := 0.025
const DEFENSE_REDUCTION_MAX := 0.7

## Commander specialty values a battle hero payload carries (content
## hero_specialties.json bonuses); BattleRules._hero_payload_from_state fills them.
const HERO_SPECIALTY_BATTLE_KEYS := [
	"melee_damage_pct",
	"ranged_damage_pct",
	"damage_taken_pct",
	"retaliation_damage_pct",
	"siege_damage_pct",
	"defend_defense_bonus",
	"battle_cohesion",
	"battle_momentum",
	"creature_health_pct",
	"victory_recovery_pct",
	"mana_after_victory",
	"reward_bonus_pct",
]

## The side assaulting a town in this battle, "" when it is no town fight.
static func town_assault_side(battle: Dictionary) -> String:
	if _battle_engine_mode == BattleEngine.GDSCRIPT:
		return town_assault_side__gd(battle)
	if _battle_engine_mode == BattleEngine.NATIVE:
		return BattleEngine.native(&"BattleDamageRules.town_assault_side", [battle])
	var result = town_assault_side__gd(battle)
	BattleEngine.check(&"BattleDamageRules.town_assault_side", [battle], result)
	return result

static func town_assault_side__gd(battle: Dictionary) -> String:
	var context = battle.get("context", {})
	var context_type := String(context.get("type", "")) if context is Dictionary else ""
	if context_type == "town_assault":
		return "player"
	if context_type == "town_defense":
		return "enemy"
	return ""

## Specialty damage between two commanders: the attacker's melee or ranged
## bonus, plus retaliation and siege bonuses when they apply, against the
## defender's damage reduction.
static func hero_damage_multiplier(attacker_hero: Dictionary, defender_hero: Dictionary, is_ranged: bool, is_retaliation: bool, is_town_assault: bool) -> float:
	if _battle_engine_mode == BattleEngine.GDSCRIPT:
		return hero_damage_multiplier__gd(attacker_hero, defender_hero, is_ranged, is_retaliation, is_town_assault)
	if _battle_engine_mode == BattleEngine.NATIVE:
		return BattleEngine.native(&"BattleDamageRules.hero_damage_multiplier", [attacker_hero, defender_hero, is_ranged, is_retaliation, is_town_assault])
	var result = hero_damage_multiplier__gd(attacker_hero, defender_hero, is_ranged, is_retaliation, is_town_assault)
	BattleEngine.check(&"BattleDamageRules.hero_damage_multiplier", [attacker_hero, defender_hero, is_ranged, is_retaliation, is_town_assault], result)
	return result

static func hero_damage_multiplier__gd(attacker_hero: Dictionary, defender_hero: Dictionary, is_ranged: bool, is_retaliation: bool, is_town_assault: bool) -> float:
	var pct := int(attacker_hero.get("ranged_damage_pct" if is_ranged else "melee_damage_pct", 0))
	if is_retaliation:
		pct += int(attacker_hero.get("retaliation_damage_pct", 0))
	if is_town_assault:
		pct += int(attacker_hero.get("siege_damage_pct", 0))
	var taken := maxf(0.1, 1.0 + float(int(defender_hero.get("damage_taken_pct", 0))) / 100.0)
	return (1.0 + float(pct) / 100.0) * taken

static func attack_defense_multiplier(attack_stat: int, defense_stat: int) -> float:
	if _battle_engine_mode == BattleEngine.GDSCRIPT:
		return attack_defense_multiplier__gd(attack_stat, defense_stat)
	if _battle_engine_mode == BattleEngine.NATIVE:
		return BattleEngine.native(&"BattleDamageRules.attack_defense_multiplier", [attack_stat, defense_stat])
	var result = attack_defense_multiplier__gd(attack_stat, defense_stat)
	BattleEngine.check(&"BattleDamageRules.attack_defense_multiplier", [attack_stat, defense_stat], result)
	return result

static func attack_defense_multiplier__gd(attack_stat: int, defense_stat: int) -> float:
	var difference := attack_stat - defense_stat
	if difference >= 0:
		return 1.0 + minf(float(difference) * ATTACK_BONUS_PER_POINT, ATTACK_BONUS_MAX)
	return 1.0 - minf(float(-difference) * DEFENSE_REDUCTION_PER_POINT, DEFENSE_REDUCTION_MAX)
