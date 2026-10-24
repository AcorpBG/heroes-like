extends RefCounted
## A placed resource site can carry its own payload. Generated maps roll
## HoMM-style amounts, chest tiers, scroll spells, creature-bank levels and
## Pandora's Box contents per placement; authored placements use the site
## definition unchanged. A site that stays on the map after its claim pays that
## claim payload once per placement: recapturing it grants ownership only,
## never the payload again.


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
