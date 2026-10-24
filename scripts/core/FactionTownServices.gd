extends RefCounted

const Progression = preload("res://scripts/core/HeroProgressionRules.gd")
const Spells = preload("res://scripts/core/SpellRules.gd")
## AI weights (content/ai_hero_weights.json) for useful_to_ai: the gold a
## service that costs gold leaves; mana restored at this share or below; gold
## before buying experience; wood and ore an exchange leaves; gold below which,
## or stock at or below which, an exchange is worth it. AiHeroRules puts a
## computer player's set in place (apply_ai_weights); until it does, the
## default set.
static var AI_GOLD_RESERVE: int
static var AI_RESTORE_MANA_SHARE: float
static var AI_EXPERIENCE_MIN_GOLD: int
static var AI_EXCHANGE_MIN_KEPT: int
static var AI_EXCHANGE_GOLD_CAP: int
static var AI_EXCHANGE_LOW_STOCK: int
static var _ai_weights_ready := false
