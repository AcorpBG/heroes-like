extends RefCounted
## HoMM3-style water travel. Boats sit on water tiles. A hero who walks onto a
## free boat boards it, and a sailing hero who steps onto open shore leaves it
## there; either step ends the hero's movement for the day. Sailing heroes move
## only on water. Shipyards build a boat at their dock, and whirlpools throw a
## boat out at another whirlpool for half of the weakest stack.
##
## Boats live in session.overworld.boats; a sailing hero carries boat_id, the
## human's heroes and the computer players' heroes alike (AiHeroRules sails
## those under the same rules). OverworldRules owns route checks and calls these
## helpers.

const Levels = preload("res://scripts/core/OverworldLevelRules.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

const BOATS_KEY := "boats"
const HERO_BOAT_KEY := "boat_id"
const BOAT_ASSET_ID := "mapobj_water_boat"
const SHIPYARD_SITE_ID := "site_shipyard"
const WHIRLPOOL_SITE_ID := "site_whirlpool"
const NEIGHBORS := [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1)]

static func boats(session) -> Array:
	return HumanEngine.native_writing(&"WaterTravelRules.boats", [session])

static func is_sailing(session) -> bool:
	return HumanEngine.native(&"WaterTravelRules.is_sailing", [session])

static func free_boats(session, level: int) -> Array:
	return HumanEngine.native_writing(&"WaterTravelRules.free_boats", [session, level])
