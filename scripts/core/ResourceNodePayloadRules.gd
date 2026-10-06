extends RefCounted
## A placed resource site can carry its own payload. Generated maps roll
## HoMM-style amounts, chest tiers and scroll spells per placement; authored
## placements use the site definition unchanged. A site that stays on the map
## after its claim pays that claim payload once per placement: recapturing it
## grants ownership only, never the payload again.

const PAYLOAD_REWARDS := "payload_rewards"
const PAYLOAD_REWARD_CHOICES := "payload_reward_choices"
const PAYLOAD_SPELL_IDS := "payload_spell_ids"
const CLAIM_PAYLOAD_SPENT := "claim_payload_spent"

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
	if claim_payload_spent(node, site):
		for key in ["claim_rewards", "rewards", "reward_choices", "claim_recruits", "learn_spell_id", "learn_spell_ids"]:
			effective.erase(key)
		var roster = effective.get("neutral_roster", {})
		if roster is Dictionary and roster.has("claim_recruits"):
			roster.erase("claim_recruits")
			effective["neutral_roster"] = roster
	return effective

static func claim_payload_spent(node: Dictionary, site: Dictionary) -> bool:
	return bool(site.get("persistent_control", false)) and bool(node.get(CLAIM_PAYLOAD_SPENT, false))

static func mark_claimed(node: Dictionary, site: Dictionary) -> void:
	if bool(site.get("persistent_control", false)):
		node[CLAIM_PAYLOAD_SPENT] = true

static func _has_node_payload(node: Dictionary, site: Dictionary) -> bool:
	return (
		node.has(PAYLOAD_REWARDS)
		or node.has(PAYLOAD_REWARD_CHOICES)
		or node.has(PAYLOAD_SPELL_IDS)
		or claim_payload_spent(node, site)
	)
