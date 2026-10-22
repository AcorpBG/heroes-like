extends RefCounted
## A placed resource site can carry its own payload. Generated maps roll
## HoMM-style amounts, chest tiers, scroll spells, creature-bank levels and
## Pandora's Box contents per placement; authored placements use the site
## definition unchanged. A site that stays on the map after its claim pays that
## claim payload once per placement: recapturing it grants ownership only,
## never the payload again.

const TurnEngine = preload("res://scripts/core/TurnEngine.gd")
static var _turn_engine_mode: int = TurnEngine.mode

const PAYLOAD_REWARDS := "payload_rewards"
const PAYLOAD_REWARD_CHOICES := "payload_reward_choices"
const PAYLOAD_SPELL_IDS := "payload_spell_ids"
const PAYLOAD_VISIT := "payload_visit"
# Troops that join on the claim; empty means none.
const PAYLOAD_RECRUITS := "payload_recruits"
const PAYLOAD_VISION_RADIUS := "payload_vision_radius"
# The HoMM3 classes (treasure, minor, major, relic) of the artifacts the claim
# draws instead of the site's own reward table, one artifact each; empty means
# none (ArtifactRules.H3M_ARTIFACT_CLASS_RARITIES).
const PAYLOAD_ARTIFACT_CLASSES := "payload_artifact_classes"
const CLAIM_ARTIFACT_CLASSES := "claim_artifact_classes"
# The rarity of the one artifact the claim draws instead of the site's own
# reward table; empty means no artifact. Saved creature banks from before the
# artifact classes still hold it.
const PAYLOAD_ARTIFACT_RARITY := "payload_artifact_rarity"
const CLAIM_ARTIFACT_RARITY := "claim_artifact_rarity"
const CLAIM_PAYLOAD_SPENT := "claim_payload_spent"
const PAYLOAD_KEYS := [
	PAYLOAD_REWARDS,
	PAYLOAD_REWARD_CHOICES,
	PAYLOAD_SPELL_IDS,
	PAYLOAD_VISIT,
	PAYLOAD_RECRUITS,
	PAYLOAD_VISION_RADIUS,
	PAYLOAD_ARTIFACT_CLASSES,
	PAYLOAD_ARTIFACT_RARITY,
]

static func site_for_node(node: Dictionary, site: Dictionary = {}) -> Dictionary:
	if site.is_empty():
		site = ContentService.get_resource_site(String(node.get("site_id", "")))
	if site.is_empty() or not _has_node_payload(node, site):
		return site
	var effective: Dictionary = site.duplicate(true)
	var rewards = node.get(PAYLOAD_REWARDS, null)
	if rewards is Dictionary:
		effective["claim_rewards"] = rewards.duplicate(true)
		effective.erase("rewards")
	var choices = node.get(PAYLOAD_REWARD_CHOICES, null)
	if choices is Array:
		effective["reward_choices"] = choices.duplicate(true)
	var spell_ids = node.get(PAYLOAD_SPELL_IDS, null)
	if spell_ids is Array:
		effective.erase("learn_spell_id")
		effective["learn_spell_ids"] = spell_ids.duplicate()
	var visit_override = node.get(PAYLOAD_VISIT, null)
	if visit_override is Dictionary and effective.get("visit", {}) is Dictionary:
		var visit: Dictionary = effective.get("visit", {}).duplicate(true)
		for key in visit_override.keys():
			visit[key] = visit_override[key].duplicate(true) if visit_override[key] is Dictionary or visit_override[key] is Array else visit_override[key]
		effective["visit"] = visit
	var recruits = node.get(PAYLOAD_RECRUITS, null)
	if recruits is Dictionary:
		_erase_claim_recruits(effective)
		if not recruits.is_empty():
			effective["claim_recruits"] = recruits.duplicate(true)
	if node.has(PAYLOAD_VISION_RADIUS):
		effective["vision_radius"] = maxi(0, int(node.get(PAYLOAD_VISION_RADIUS, 0)))
	var artifact_classes = node.get(PAYLOAD_ARTIFACT_CLASSES, null)
	if artifact_classes is Array:
		effective[CLAIM_ARTIFACT_CLASSES] = artifact_classes.duplicate()
	var artifact_rarity = node.get(PAYLOAD_ARTIFACT_RARITY, null)
	if artifact_rarity is String:
		effective[CLAIM_ARTIFACT_RARITY] = artifact_rarity
	if claim_payload_spent(node, site):
		for key in ["claim_rewards", "rewards", "reward_choices", "learn_spell_id", "learn_spell_ids"]:
			effective.erase(key)
		_erase_claim_recruits(effective)
	return effective

static func _erase_claim_recruits(effective: Dictionary) -> void:
	effective.erase("claim_recruits")
	var roster = effective.get("neutral_roster", {})
	if roster is Dictionary and roster.has("claim_recruits"):
		roster.erase("claim_recruits")
		effective["neutral_roster"] = roster

static func claim_payload_spent(node: Dictionary, site: Dictionary) -> bool:
	return bool(site.get("persistent_control", false)) and bool(node.get(CLAIM_PAYLOAD_SPENT, false))

static func mark_claimed(node: Dictionary, site: Dictionary) -> void:
	if _turn_engine_mode != TurnEngine.SHADOW:
		mark_claimed__gd(node, site)
		return
	var before := TurnEngine.before_writing(&"ResourceNodePayloadRules.mark_claimed", [node, site])
	mark_claimed__gd(node, site)
	TurnEngine.check_writing(&"ResourceNodePayloadRules.mark_claimed", before, [node, site], null)

static func mark_claimed__gd(node: Dictionary, site: Dictionary) -> void:
	if bool(site.get("persistent_control", false)):
		node[CLAIM_PAYLOAD_SPENT] = true

static func _has_node_payload(node: Dictionary, site: Dictionary) -> bool:
	for key in PAYLOAD_KEYS:
		if node.has(key):
			return true
	return claim_payload_spent(node, site)
