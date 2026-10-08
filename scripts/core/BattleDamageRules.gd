extends RefCounted
## Attack against defense, shared by the battle rules and the battle AI's
## damage estimate. Each point of attack above the target's defense adds 5%
## damage, up to +300%; each point of defense above the attack takes 2.5% off,
## down to -70%. The caps sit past any stat gap the content reaches, so every
## point of hero or creature attack and defense counts.

const ATTACK_BONUS_PER_POINT := 0.05
const ATTACK_BONUS_MAX := 3.0
const DEFENSE_REDUCTION_PER_POINT := 0.025
const DEFENSE_REDUCTION_MAX := 0.7

static func attack_defense_multiplier(attack_stat: int, defense_stat: int) -> float:
	var difference := attack_stat - defense_stat
	if difference >= 0:
		return 1.0 + minf(float(difference) * ATTACK_BONUS_PER_POINT, ATTACK_BONUS_MAX)
	return 1.0 - minf(float(-difference) * DEFENSE_REDUCTION_PER_POINT, DEFENSE_REDUCTION_MAX)
