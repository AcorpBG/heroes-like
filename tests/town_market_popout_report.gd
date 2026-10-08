extends Node

## Focused live report for the Town market popout. For every faction town
## template it drives the real TownShell: the Trade command and the market
## building open one popout, the old separate market and spell dialogs are
## gone, the popout buys and sells for gold and converts one resource into
## another at the shown rate, and every "trade for it" cost button opens the
## market popout. Every resource trades for every other, rare resources
## included: the popout buys, sells and converts them at the shown rate within
## the weekly limits. It also checks the trade rules themselves (values, tiers,
## limits, no profitable cycle anywhere) and that the market costs gold only.

const TownShellScene = preload("res://scenes/town/TownShell.tscn")
const Board = preload("res://scripts/core/TownConstructionBoard.gd")
const OverworldLevelRulesScript = preload("res://scripts/core/OverworldLevelRules.gd")
const CAPTURE_DIR := "res://.artifacts/town_market_popout"
const TAVERN_ID := "building_wayfarers_hall"
const MARKET_ID := "building_market_square"
const EXCHANGE_ID := "building_dev_trade_exchange"
const STOCK := {"gold": 20000, "wood": 20, "ore": 20, "aetherglass": 6, "embergrain": 6, "peatwax": 6, "verdant_grafts": 6, "brass_scrip": 6, "memory_salt": 6}
const RARES := ["aetherglass", "embergrain", "peatwax", "verdant_grafts", "brass_scrip", "memory_salt"]

var _errors := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var capture_dir := OS.get_environment("MARKET_CAPTURE_DIR")
	if capture_dir == "":
		capture_dir = ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var original_size := get_window().size
	var rule_rows := _check_rules()
	var rare_rows := _check_rare_rules()
	var cost_rows := _check_market_costs()
	var only := OS.get_environment("MARKET_TOWN")
	var rows := []
	var templates := []
	for town_value in ContentService.load_json("res://content/towns.json").get("items", []):
		if only == "" or String(town_value.get("id", "")) == only:
			templates.append(String(town_value.get("id", "")))
	for index in range(templates.size()):
		var viewport_size := Vector2i(1920, 1080) if index % 2 == 0 else Vector2i(1280, 720)
		var row: Dictionary = await _run_town(String(templates[index]), viewport_size, capture_dir)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_errors.append("%s failed: %s" % [templates[index], JSON.stringify(row.get("failures", []))])
	get_window().size = original_size
	var report := {
		"ok": _errors.is_empty(),
		"schema": "town_market_popout_report_v1",
		"rules": rule_rows,
		"rare_rules": rare_rows,
		"costs": cost_rows,
		"town_count": rows.size(),
		"rows": rows,
		"errors": _errors,
	}
	if _errors.is_empty():
		print("TOWN_MARKET_POPOUT_REPORT %s" % JSON.stringify(report))
	else:
		push_error("TOWN_MARKET_POPOUT_REPORT failed: %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

# --- pure rules ---------------------------------------------------------------

func _check_rules() -> Dictionary:
	var failures := []
	var usage := {"week": 1, "buy": {"wood": 0, "ore": 0}, "sell": {"wood": 0, "ore": 0}}
	var stock := {"gold": 5000, "wood": 30, "ore": 1}
	var cases := []
	for market in [_market_fixture(MARKET_ID), _market_fixture(EXCHANGE_ID)]:
		var rate: Dictionary = TownRules.market_conversion_rate(market, "wood", "ore")
		var numerator := int(market.buy_rates.ore) + int(market.sell_rates.ore)
		var denominator := 2 * int(market.sell_rates.wood)
		_check(failures, int(rate.get("numerator", 0)) == numerator and int(rate.get("denominator", 0)) == denominator, "conversion rate %s" % rate)
		var quote: Dictionary = TownRules.market_trade_quote(market, usage, stock, "wood", "ore", 3)
		var expected_give := ceili(3.0 * float(numerator) / float(denominator))
		_check(failures, String(quote.get("mode", "")) == "convert" and bool(quote.get("ok", false)) and int(quote.get("give_amount", 0)) == expected_give and int(quote.get("receive_amount", 0)) == 3, "conversion quote %s" % quote)
		_check(failures, String(quote.get("action_id", "")) == "market:convert:wood:ore:3", "conversion action id %s" % quote.get("action_id", ""))
		# Never one for one, always better than selling for gold and buying back.
		var per_unit := float(numerator) / float(denominator)
		var via_gold := float(market.buy_rates.ore) / float(market.sell_rates.wood)
		_check(failures, per_unit > 1.0 and per_unit < via_gold, "conversion %.2f between 1 and the gold path %.2f" % [per_unit, via_gold])
		var back: Dictionary = TownRules.market_conversion_rate(market, "ore", "wood")
		var round_trip := per_unit * float(back.get("numerator", 0)) / float(back.get("denominator", 1))
		_check(failures, round_trip > 1.0, "wood to ore and back gains %.2f" % round_trip)
		# The weekly limits bind both sides: sells of the given resource, buys of the received one.
		var max_now := int(quote.get("max_amount", 0))
		var sell_cap := int(market.sell_caps.wood)
		var buy_cap := int(market.buy_caps.ore)
		_check(failures, max_now == mini(buy_cap, int(floor(float(mini(sell_cap, 30)) * float(denominator) / float(numerator)))), "conversion max %d" % max_now)
		var spent := {"week": 1, "buy": {"wood": 0, "ore": buy_cap}, "sell": {"wood": 0, "ore": 0}}
		_check(failures, int(TownRules.market_trade_quote(market, spent, stock, "wood", "ore", 1).get("max_amount", -1)) == 0, "conversion ignores the ore buy limit")
		var sold := {"week": 1, "buy": {"wood": 0, "ore": 0}, "sell": {"wood": sell_cap, "ore": 0}}
		_check(failures, int(TownRules.market_trade_quote(market, sold, stock, "wood", "ore", 1).get("max_amount", -1)) == 0, "conversion ignores the wood sell limit")
		_check(failures, not bool(TownRules.market_trade_quote(market, usage, {"wood": 1}, "wood", "ore", 1).get("ok", true)), "conversion without enough wood")
		# Buy and sell use the existing gold rates; lots of two stay discounted.
		var buy: Dictionary = TownRules.market_trade_quote(market, usage, stock, "gold", "wood", 1)
		_check(failures, String(buy.get("mode", "")) == "buy" and int(buy.get("give_amount", 0)) == int(market.buy_rates.wood) and String(buy.get("action_id", "")) == "market:buy:wood:1", "buy quote %s" % buy)
		var sell: Dictionary = TownRules.market_trade_quote(market, usage, stock, "ore", "gold", 1)
		_check(failures, String(sell.get("mode", "")) == "sell" and int(sell.get("receive_amount", 0)) == int(market.sell_rates.ore) and String(sell.get("action_id", "")) == "market:sell:ore:1", "sell quote %s" % sell)
		if not market.get("bulk_resources", []).is_empty():
			var three: Dictionary = TownRules.market_trade_quote(market, usage, stock, "gold", "wood", 3)
			var two: Dictionary = TownRules.market_trade_quote(market, usage, stock, "gold", "wood", 2)
			_check(failures, int(three.get("give_amount", 0)) == int(two.get("give_amount", 0)) + int(market.buy_rates.wood), "bulk lots price %s" % three)
		_check(failures, TownRules.market_trade_mode(market, "wood", "wood") == "" and TownRules.market_trade_mode(market, "gold", "gold") == "", "same resource trades")
		cases.append({"market": String(market.get("building_id", "")), "wood_per_ore": per_unit, "gold_path": via_gold, "round_trip": round_trip, "max_now": max_now})
	if not failures.is_empty():
		_errors.append("rules: %s" % JSON.stringify(failures))
	return {"ok": failures.is_empty(), "cases": cases, "failures": failures}

func _market_fixture(building_id: String, town_id: String = "town_riverwatch") -> Dictionary:
	var built := ["building_town_hall", MARKET_ID]
	if building_id == EXCHANGE_ID:
		built.append(EXCHANGE_ID)
	return OverworldRules.town_market_state({"town_id": town_id, "built_buildings": built})

## Rare resources trade like any other, HoMM3 style, at both market tiers and in
## every faction town: priced at their economy value, better at the Trade
## Exchange, held to smaller weekly limits, and never profitable in a cycle.
func _check_rare_rules() -> Dictionary:
	var failures := []
	var markets := []
	for town_value in ContentService.load_json("res://content/towns.json").get("items", []):
		for building_id in [MARKET_ID, EXCHANGE_ID]:
			markets.append(_market_fixture(building_id, String(town_value.get("id", ""))))
	# Computer players trade through these same quotes (ai_player_rules_report),
	# so neither side sees a cheaper rare.
	var empty := {"week": 1, "buy": {}, "sell": {}}
	var stock := {"gold": 100000}
	for resource_id in OverworldRules.MARKET_RESOURCE_KEYS:
		stock[resource_id] = 100
	for index in range(markets.size()):
		var market: Dictionary = markets[index]
		var ids: Array = TownRules.market_resource_ids(market)
		_check(failures, ids == OverworldRules.MARKET_RESOURCE_KEYS, "market trades %s" % [ids])
		var exchange := int(market.get("tier", 0)) >= 2
		for rare in RARES:
			for common in ["wood", "ore"]:
				_check(failures, int(market.buy_rates[rare]) > int(market.buy_rates[common]) and int(market.sell_rates[rare]) > int(market.sell_rates[common]), "%s is not worth more than %s" % [rare, common])
			_check(failures, int(market.buy_caps[rare]) == (5 if exchange else 2) and int(market.sell_caps[rare]) == (5 if exchange else 3), "%s caps %d/%d" % [rare, market.buy_caps[rare], market.sell_caps[rare]])
		for common in ["wood", "ore"]:
			_check(failures, int(market.buy_caps[common]) == (20 if exchange else 12) and int(market.sell_caps[common]) == (24 if exchange else 16), "%s caps %d/%d" % [common, market.buy_caps[common], market.sell_caps[common]])
		if exchange:
			var square: Dictionary = markets[index - 1]
			for resource_id in ids:
				_check(failures, int(market.buy_rates[resource_id]) < int(square.buy_rates[resource_id]) and int(market.sell_rates[resource_id]) > int(square.sell_rates[resource_id]), "Trade Exchange is not better for %s" % resource_id)
		# Every pair quotes, and conversions charge exactly the midpoint-over-sell rate.
		for give_id in ids:
			_check(failures, int(TownRules.market_trade_quote(market, empty, stock, give_id, "gold", 1).get("receive_amount", 0)) == int(market.sell_rates[give_id]), "sell %s" % give_id)
			_check(failures, int(TownRules.market_trade_quote(market, empty, stock, "gold", give_id, 1).get("give_amount", 0)) == int(market.buy_rates[give_id]), "buy %s" % give_id)
			for receive_id in ids:
				if give_id == receive_id:
					continue
				var rate: Dictionary = TownRules.market_conversion_rate(market, give_id, receive_id)
				var back: Dictionary = TownRules.market_conversion_rate(market, receive_id, give_id)
				var per_unit := float(rate.numerator) / float(rate.denominator)
				var most := int(TownRules.market_trade_quote(market, empty, stock, give_id, receive_id, 1).get("max_amount", 0))
				var count := mini(2, most)
				var quote: Dictionary = TownRules.market_trade_quote(market, empty, stock, give_id, receive_id, count)
				var expected_give := (count * int(rate.numerator) + int(rate.denominator) - 1) / int(rate.denominator)
				_check(failures, most >= 1 and bool(quote.get("ok", false)) and int(quote.give_amount) == expected_give and int(quote.receive_amount) == count, "convert %s to %s: %s" % [give_id, receive_id, quote])
				_check(failures, per_unit * float(back.numerator) / float(back.denominator) > 1.0, "%s to %s and back gains" % [give_id, receive_id])
				_check(failures, per_unit < float(market.buy_rates[receive_id]) / float(market.sell_rates[give_id]), "converting %s to %s is not better than selling and buying" % [give_id, receive_id])
				_check(failures, float(market.buy_rates[give_id]) * per_unit > float(market.sell_rates[receive_id]), "buying %s to convert and sell %s pays" % [give_id, receive_id])
	# No cycle pays across towns and tiers either: buy anywhere, sell anywhere,
	# convert in one town and back in another.
	var cross_failures := 0
	for first in markets:
		for second in markets:
			for give_id in OverworldRules.MARKET_RESOURCE_KEYS:
				if int(second.sell_rates[give_id]) >= int(first.buy_rates[give_id]):
					cross_failures += 1
				for receive_id in OverworldRules.MARKET_RESOURCE_KEYS:
					if give_id == receive_id:
						continue
					var there: Dictionary = TownRules.market_conversion_rate(first, give_id, receive_id)
					var back: Dictionary = TownRules.market_conversion_rate(second, receive_id, give_id)
					if float(there.numerator) / float(there.denominator) * float(back.numerator) / float(back.denominator) <= 1.0:
						cross_failures += 1
	_check(failures, cross_failures == 0, "%d profitable cross-town cycles" % cross_failures)
	# Saved import counters already lived in the weekly buy bucket; they now count
	# against the rare buy limit.
	var exchange_market := _market_fixture(EXCHANGE_ID, "town_veilmourn_bellwake_harbor")
	var legacy: Dictionary = OverworldRules._normalize_towns([{"town_id": "town_veilmourn_bellwake_harbor", "placement_id": "legacy", "owner": "player", "built_buildings": ["building_town_hall", MARKET_ID, EXCHANGE_ID], "market_usage": {"week": 1, "buy": {"wood": 0, "ore": 0, "memory_salt": 3}, "sell": {"wood": 0, "ore": 0}}}], 3)[0]
	var legacy_cap: Dictionary = OverworldRules._market_cap_state_for_quote(legacy, exchange_market, OverworldRules._market_quote_from_state(exchange_market, "buy", "memory_salt", 1), 3)
	_check(failures, int(legacy_cap.get("used", -1)) == 3 and int(legacy_cap.get("remaining", -1)) == 2, "saved import counter %s" % legacy_cap)
	if not failures.is_empty():
		_errors.append("rare rules: %s" % JSON.stringify(failures))
	return {"ok": failures.is_empty(), "market_count": markets.size(), "failures": failures}

## Owner decision 2026-10-08: the Marketplace costs 1,000 gold and the Trade
## Exchange 3,000 gold, 5 wood and 5 ore, in every faction's town.
const MARKET_COSTS := {
	MARKET_ID: {"gold": 1000},
	EXCHANGE_ID: {"gold": 3000, "wood": 5, "ore": 5},
}

func _cost_matches(cost: Dictionary, expected: Dictionary) -> bool:
	if expected.is_empty() or cost.size() != expected.size():
		return false
	for key in expected.keys():
		if int(cost.get(key, -1)) != int(expected[key]):
			return false
	return true

func _check_market_costs() -> Dictionary:
	var failures := []
	var costs := {}
	for town_value in ContentService.load_json("res://content/towns.json").get("items", []):
		var template: Dictionary = town_value
		for building_id_value in Board.town_building_ids(template):
			var building := ContentService.get_building(String(building_id_value))
			if not (building.get("market_profile", {}) is Dictionary) or building.get("market_profile", {}).is_empty():
				continue
			var cost: Dictionary = building.get("cost", {})
			costs["%s/%s" % [String(template.get("faction_id", "")), String(building_id_value)]] = cost
			var expected: Dictionary = MARKET_COSTS.get(String(building_id_value), {})
			_check(failures, _cost_matches(cost, expected), "%s %s costs %s, expected %s" % [template.get("id", ""), building_id_value, cost, expected])
	if not failures.is_empty():
		_errors.append("costs: %s" % JSON.stringify(failures))
	return {"ok": failures.is_empty(), "costs": costs}

# --- live popout --------------------------------------------------------------

func _run_town(template_id: String, viewport_size: Vector2i, capture_dir: String) -> Dictionary:
	var failures := []
	get_window().size = viewport_size
	await _frames(2)
	var template := ContentService.get_town(template_id)
	var ids := _pick_buildings(Board.town_building_ids(template))
	for key in ["dwelling", "guild"]:
		if String(ids.get(key, "")) == "":
			return {"ok": false, "template_id": template_id, "failures": ["no %s building" % key]}
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var town := _first_player_town(session)
	if town.is_empty():
		return {"ok": false, "template_id": template_id, "failures": ["player_town_missing"]}
	var base_unit := String(ContentService.get_building(ids.dwelling).get("unlock_unit_id", ""))
	town["town_id"] = template_id
	town["built_buildings"] = ["building_town_hall", TAVERN_ID, ids.dwelling, ids.guild]
	town["available_recruits"] = {base_unit: 10}
	town["market_usage"] = {}
	town["last_build_day"] = 0
	session.day = 2
	session.overworld["resources"] = STOCK.duplicate(true)
	_station_active_hero(session, town)
	var visit: Dictionary = OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	if not bool(visit.get("ok", false)):
		return {"ok": false, "template_id": template_id, "failures": ["town_visit"], "visit": visit}
	session = SessionState.set_active_session(session)
	var shell = TownShellScene.instantiate()
	add_child(shell)
	await _frames(3)

	# The old separate market and spell dialogs are gone.
	_check(failures, shell.get_node_or_null("%MarketActions") == null and shell.get_node_or_null("%Market") == null, "old market panel nodes still exist")
	_check(failures, shell.get("_spellbook_view") == null and shell.find_child("SpellbookView", true, false) == null, "old town spellbook dialog still exists")
	for old_mode in ["trade", "spells"]:
		shell.call("_open_town_catalog", old_mode)
		await _frames(1)
		_check(failures, not bool(shell.call("_town_catalog_is_open")) and String(shell.get("_town_catalog_mode")) != old_mode, "old %s dialog still opens" % old_mode)
		shell.call("_close_town_catalog", false)
	# Without a market the Trade command explains what to build.
	var trade_button: Button = shell.get_node("%TradeAction")
	_check(failures, trade_button.disabled and trade_button.tooltip_text.contains("Market"), "Trade command without a market: %s" % trade_button.tooltip_text)
	shell.call("validation_activate_direct_action", "trade")
	await _frames(2)
	_check(failures, not bool(shell.call("_town_catalog_is_open")), "Trade opened a window without a market")

	# Build the market: its popout is the only market window.
	var live = SessionState.ensure_active_session()
	_set_built(live, ["building_town_hall", TAVERN_ID, ids.dwelling, ids.guild, MARKET_ID])
	shell.call("_refresh")
	await _frames(2)
	_check(failures, not trade_button.disabled, "Trade command stays disabled with a market")
	var direct: Dictionary = shell.call("validation_activate_direct_action", "trade")
	await _frames(3)
	var from_command: Dictionary = shell.call("validation_building_information_snapshot", MARKET_ID)
	_check(failures, String(direct.get("active_dialog_mode", "")) == "building_info" and bool(from_command.get("open", false)) and String(from_command.get("panel", {}).get("kind", "")) == "market", "Trade command opens the market popout %s" % direct)
	var from_building: Dictionary = await _open(shell, MARKET_ID)
	_check(failures, String(from_building.get("mode", "")) == "building_info" and String(from_building.get("title", "")) == String(from_command.get("title", "")) and String(from_building.get("panel", {}).get("building_id", "")) == MARKET_ID, "building click and Trade command differ")
	_no_scroll(failures, from_building, "market")
	var spells: Dictionary = shell.call("validation_activate_direct_action", "spells")
	await _frames(3)
	var guild_info: Dictionary = shell.call("validation_building_information_snapshot", ids.guild)
	_check(failures, String(spells.get("active_dialog_mode", "")) == "building_info" and String(guild_info.get("panel", {}).get("kind", "")) == "guild" and String(shell.get("_selected_building_info_id")) == ids.guild, "Spells command opens the guild popout %s" % spells)
	_no_scroll(failures, guild_info, "guild")
	await _capture(capture_dir, template_id, "guild", viewport_size)

	var info: Dictionary = await _open(shell, MARKET_ID)
	var view = shell.get("_building_info_surface")
	var market_rows := {}
	# Buy two wood for gold.
	market_rows["buy"] = await _trade(shell, view, failures, "gold", "wood", 2)
	await _capture(capture_dir, template_id, "market_buy", viewport_size)
	# Sell three ore for gold.
	market_rows["sell"] = await _trade(shell, view, failures, "ore", "gold", 3)
	# Convert wood straight into ore at the shown rate.
	market_rows["convert"] = await _trade(shell, view, failures, "wood", "ore", 2, capture_dir, template_id, viewport_size)
	var usage: Dictionary = TownRules.get_active_town(SessionState.ensure_active_session()).get("market_usage", {})
	var convert_row: Dictionary = market_rows.get("convert", {})
	_check(failures, int(usage.get("buy", {}).get("wood", 0)) == 2 and int(usage.get("buy", {}).get("ore", 0)) == 2, "weekly buys %s" % usage)
	_check(failures, int(usage.get("sell", {}).get("ore", 0)) == 3 and int(usage.get("sell", {}).get("wood", 0)) == int(convert_row.get("give_amount", -1)), "weekly sells %s" % usage)
	info = shell.call("validation_building_information_snapshot", MARKET_ID)
	_check(failures, bool(info.get("open", false)) and String(info.get("panel", {}).get("building_id", "")) == MARKET_ID, "market popout closed after trading")
	_no_scroll(failures, info, "market after trades")

	# Rare resources trade like any other: every resource in both rows, then buy,
	# sell and convert them with fresh weekly limits.
	var desk: Dictionary = shell.get("_building_info_surface").call("validation_snapshot").get("market", {})
	_check(failures, desk.get("give_tiles", []).size() == 9 and desk.get("receive_tiles", {}).size() == 9, "market rows %s / %s" % [desk.get("give_tiles", []), desk.get("receive_tiles", {}).keys()])
	_reset_market_usage(SessionState.ensure_active_session())
	shell.call("_refresh_building_information")
	await _frames(2)
	market_rows["buy_rare"] = await _trade(shell, null, failures, "gold", RARES[0], 2, capture_dir, template_id, viewport_size, "market_rare_buy")
	await _check_cap_holds(shell, failures, "gold", RARES[0])
	market_rows["sell_rare"] = await _trade(shell, null, failures, RARES[1], "gold", 3)
	await _check_cap_holds(shell, failures, RARES[1], "gold")
	market_rows["rare_to_wood"] = await _trade(shell, null, failures, RARES[2], "wood", 2)
	market_rows["wood_to_rare"] = await _trade(shell, null, failures, "wood", RARES[3], 1)
	market_rows["rare_to_rare"] = await _trade(shell, null, failures, RARES[4], RARES[5], 1, capture_dir, template_id, viewport_size, "market_rare_convert")
	info = shell.call("validation_building_information_snapshot", MARKET_ID)
	_no_scroll(failures, info, "market after rare trades")

	# Cost buttons that offered an exchange open the market popout.
	var routes := await _check_trade_routes(shell, failures, ids, base_unit)

	# The Trade Exchange trades the same resources at better rates and with
	# larger limits.
	shell.call("_close_town_catalog", false)
	live = SessionState.ensure_active_session()
	var square_market: Dictionary = OverworldRules.town_market_state(TownRules.get_active_town(live))
	_set_built(live, ["building_town_hall", TAVERN_ID, ids.dwelling, ids.guild, MARKET_ID, EXCHANGE_ID])
	live.overworld["resources"] = STOCK.duplicate(true)
	shell.call("_refresh")
	await _frames(2)
	info = await _open(shell, EXCHANGE_ID)
	_no_scroll(failures, info, "trade exchange")
	var exchange_market: Dictionary = OverworldRules.town_market_state(TownRules.get_active_town(live))
	_check(failures, int(exchange_market.buy_rates[RARES[0]]) < int(square_market.buy_rates[RARES[0]]) and int(exchange_market.sell_rates[RARES[0]]) > int(square_market.sell_rates[RARES[0]]), "Trade Exchange rare rates are not better")
	var exchange_usage: Dictionary = OverworldRules._normalize_town_market_usage_state(TownRules.get_active_town(live).get("market_usage", {}), int(live.day))
	var exchange_room := int(TownRules.market_trade_quote(exchange_market, exchange_usage, live.overworld.get("resources", {}), "gold", RARES[0], 1).get("max_amount", 0))
	_check(failures, exchange_room > int(square_market.buy_caps[RARES[0]]), "Trade Exchange rare limit %d" % exchange_room)
	market_rows["exchange_buy_rare"] = await _trade(shell, null, failures, "gold", RARES[0], exchange_room)
	await _check_cap_holds(shell, failures, "gold", RARES[0])
	market_rows["exchange_convert"] = await _trade(shell, null, failures, RARES[5], "ore", 2, capture_dir, template_id, viewport_size, "exchange_convert")
	shell.queue_free()
	await _frames(2)
	return {"ok": failures.is_empty(), "template_id": template_id, "viewport": viewport_size, "trades": market_rows, "routes": routes, "failures": failures}

## Picks a pair in the popout, sets the amount, checks the shown quote against
## the rule, presses Trade and checks the stockpile moved by exactly that quote.
func _trade(shell: Node, view, failures: Array, give_id: String, receive_id: String, amount: int, capture_dir: String = "", template_id: String = "", viewport_size := Vector2i.ZERO, step: String = "") -> Dictionary:
	_dismiss_presentation(shell)
	await _frames(1)
	view = shell.get("_building_info_surface")
	_check(failures, bool(view.call("validation_select_market_pair", give_id, receive_id)), "select %s for %s" % [give_id, receive_id])
	# Giving a valuable resource steps by whole given units; take the nearest offered amount.
	var steps: Array = view.call("validation_snapshot").get("market", {}).get("steps", [])
	if amount not in steps and not steps.is_empty():
		amount = int(steps.filter(func(step): return int(step) >= amount).front()) if steps.any(func(step): return int(step) >= amount) else int(steps.back())
	_check(failures, bool(view.call("validation_set_market_amount", amount)), "amount %d for %s" % [amount, receive_id])
	await _frames(2)
	var shown: Dictionary = view.call("validation_snapshot").get("market", {})
	var live = SessionState.ensure_active_session()
	var town: Dictionary = TownRules.get_active_town(live)
	var market: Dictionary = OverworldRules.town_market_state(town)
	var usage: Dictionary = OverworldRules._normalize_town_market_usage_state(town.get("market_usage", {}), int(live.day))
	var before: Dictionary = live.overworld.get("resources", {}).duplicate(true)
	var expected: Dictionary = TownRules.market_trade_quote(market, usage, before, give_id, receive_id, amount)
	_check(failures, bool(expected.get("ok", false)), "rule refuses %s>%s x%d: %s" % [give_id, receive_id, amount, expected.get("reason", "")])
	_check(failures, int(shown.get("give_amount", -1)) == int(expected.get("give_amount", -2)) and int(shown.get("receive_amount", -1)) == int(expected.get("receive_amount", -2)), "popout shows %s, rule %s" % [shown, expected])
	_check(failures, String(shown.get("rate_text", "")) == String(expected.get("rate_text", "")) and String(shown.get("rate_text", "")) != "", "shown rate %s" % shown.get("rate_text", ""))
	_check(failures, String(shown.get("result_text", "")).contains(Board.format_amount(int(expected.get("give_amount", 0)))) and bool(shown.get("trade_enabled", false)), "shown result %s" % shown.get("result_text", ""))
	if capture_dir != "":
		await _capture(capture_dir, template_id, step if step != "" else "market_%s" % String(expected.get("mode", "")), viewport_size)
	_check(failures, bool(view.call("validation_press_market_trade")), "press %s trade" % give_id)
	await _frames(3)
	_dismiss_presentation(shell)
	await _frames(2)
	var after: Dictionary = SessionState.ensure_active_session().overworld.get("resources", {})
	for resource_id in Board.RESOURCE_ORDER:
		var delta := int(after.get(resource_id, 0)) - int(before.get(resource_id, 0))
		var expected_delta := 0
		if resource_id == give_id:
			expected_delta = -int(expected.get("give_amount", 0))
		elif resource_id == receive_id:
			expected_delta = int(expected.get("receive_amount", 0))
		_check(failures, delta == expected_delta, "%s>%s moved %s by %d, expected %d" % [give_id, receive_id, resource_id, delta, expected_delta])
	var refreshed: Dictionary = shell.get("_building_info_surface").call("validation_snapshot").get("market", {})
	_check(failures, String(refreshed.get("give_id", "")) == give_id and String(refreshed.get("receive_id", "")) == receive_id and int(refreshed.get("stock", {}).get(give_id, -1)) == int(after.get(give_id, 0)), "popout did not refresh in place %s" % refreshed)
	return {"mode": String(expected.get("mode", "")), "amount": amount, "give_amount": int(expected.get("give_amount", 0)), "receive_amount": int(expected.get("receive_amount", 0)), "rate_text": String(expected.get("rate_text", ""))}

## After a trade used up a weekly limit, the popout offers no more and the order
## itself is refused without touching the stores.
func _check_cap_holds(shell: Node, failures: Array, give_id: String, receive_id: String) -> void:
	var view = shell.get("_building_info_surface")
	view.call("validation_select_market_pair", give_id, receive_id)
	await _frames(1)
	var shown: Dictionary = view.call("validation_snapshot").get("market", {})
	_check(failures, int(shown.get("max_amount", -1)) == 0 and not bool(shown.get("trade_enabled", true)) and String(shown.get("reason", "")).contains("limit"), "%s>%s limit not shown: %s" % [give_id, receive_id, shown])
	var live = SessionState.ensure_active_session()
	var before: Dictionary = live.overworld.get("resources", {}).duplicate(true)
	var forged := "market:buy:%s:1" % receive_id if give_id == "gold" else "market:sell:%s:1" % give_id
	_check(failures, not bool(TownRules.perform_market_action(live, forged).get("ok", true)) and live.overworld.get("resources", {}) == before, "%s passed the weekly limit" % forged)

func _reset_market_usage(session) -> void:
	var active: Dictionary = TownRules.get_active_town(session)
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if String(towns[index].get("placement_id", "")) == String(active.get("placement_id", "")):
			towns[index]["market_usage"] = {}

func _check_trade_routes(shell: Node, failures: Array, ids: Dictionary, base_unit: String) -> Dictionary:
	var routes := {}
	var live = SessionState.ensure_active_session()
	# Short of gold, rich in wood and ore: every cost the market can cover offers a trade.
	live.overworld["resources"] = {"gold": 40, "wood": 120, "ore": 120, "aetherglass": 0, "embergrain": 0, "peatwax": 0, "verdant_grafts": 0, "brass_scrip": 0, "memory_salt": 0}
	_reset_market_usage(live)
	shell.call("_close_town_catalog", false)
	shell.call("_refresh")
	await _frames(2)

	# Construction board: the selected trade tile's Trade button.
	shell.call("validation_open_town_catalog", "build")
	await _frames(3)
	var screen = shell.get("_construction_screen")
	var trade_slot := ""
	var trade_building := ""
	for slot in Board.ordered_slots(screen.board()):
		if String(slot.get("status", "")) == Board.STATUS_TRADE and String(slot.get("next_id", "")) != "":
			trade_slot = String(slot.get("id", ""))
			trade_building = String(slot.get("next_id", ""))
			break
	_check(failures, trade_slot != "", "no market-coverable construction slot")
	if trade_slot != "":
		screen.select_slot(trade_slot)
		await _frames(1)
		var board_trade: Button = screen.get("_trade_button")
		_check(failures, board_trade != null and board_trade.visible, "construction Trade button hidden")
		if board_trade != null:
			board_trade.pressed.emit()
		await _frames(3)
		var opened: Dictionary = shell.call("validation_building_information_snapshot", MARKET_ID)
		var suggested: Dictionary = shell.get("_building_info_surface").call("validation_snapshot").get("market", {})
		routes["construction"] = _routed(failures, shell, opened, "construction Trade")
		_check(failures, not bool(screen.visible), "construction board stayed over the market")
		_check(failures, String(suggested.get("receive_id", "")) == "gold" and String(suggested.get("give_id", "")) in ["wood", "ore"], "market did not suggest selling for the missing gold %s" % suggested)
		# Closing the market returns to the board with the same building selected.
		shell.call("_on_town_catalog_close_pressed")
		await _frames(3)
		_check(failures, bool(screen.visible) and screen.selected_building_id() == trade_building, "closing the market did not return to construction (%s)" % screen.selected_building_id())
		shell.call("_close_town_catalog", false)
		await _frames(2)

	# Dwelling popout: the recruit card's Trade for it.
	var dwelling: Dictionary = await _open(shell, ids.dwelling)
	var view = shell.get("_building_info_surface")
	_check(failures, bool(view.call("validation_press_recruit_trade", base_unit)), "dwelling recruit card offers no Trade for it %s" % dwelling.get("panel", {}).get("recruit", []))
	await _frames(3)
	routes["dwelling"] = _routed(failures, shell, shell.call("validation_building_information_snapshot", MARKET_ID), "dwelling Trade for it")
	shell.call("_on_town_catalog_close_pressed")
	await _frames(3)
	_check(failures, String(shell.get("_town_catalog_mode")) == "building_info" and String(shell.get("_selected_building_info_id")) == ids.dwelling, "closing the market did not return to the dwelling")
	shell.call("_close_town_catalog", false)
	await _frames(2)

	# Muster Hall: the compact recruit card's Trade for it.
	shell.call("validation_open_town_catalog", "muster")
	await _frames(4)
	var muster_trade: Button = null
	for card in shell.get_node("%RecruitActions").get_children():
		if card.has_method("snapshot") and String(card.get("unit_id")) == base_unit:
			muster_trade = card.find_child("TradeButton", true, false) as Button
	_check(failures, muster_trade != null, "muster card offers no Trade for it")
	if muster_trade != null:
		muster_trade.pressed.emit()
		await _frames(3)
		routes["muster"] = _routed(failures, shell, shell.call("validation_building_information_snapshot", MARKET_ID), "muster Trade for it")
		shell.call("_on_town_catalog_close_pressed")
		await _frames(3)
		_check(failures, String(shell.get("_town_catalog_mode")) == "muster", "closing the market did not return to the Muster Hall")
	shell.call("_close_town_catalog", false)
	await _frames(2)

	# The market's own upgrade: the Trade Exchange.
	var market_info: Dictionary = await _open(shell, MARKET_ID)
	var upgrade: Dictionary = market_info.get("panel", {}).get("upgrade", {})
	_check(failures, String(upgrade.get("next_id", "")) == EXCHANGE_ID, "market upgrade line %s" % upgrade)
	_check(failures, _cost_matches(ContentService.get_building(EXCHANGE_ID).get("cost", {}), MARKET_COSTS[EXCHANGE_ID]), "Trade Exchange cost %s" % ContentService.get_building(EXCHANGE_ID).get("cost", {}))
	return routes

func _routed(failures: Array, shell: Node, info: Dictionary, label: String) -> bool:
	var exact := bool(info.get("open", false)) and String(info.get("mode", "")) == "building_info" and String(shell.get("_selected_building_info_id")) == MARKET_ID and String(info.get("panel", {}).get("kind", "")) == "market"
	_check(failures, exact, "%s did not open the market popout: %s" % [label, info.get("mode", "")])
	return exact

func _pick_buildings(template_ids: Array) -> Dictionary:
	var ids := {}
	for building_id_value in template_ids:
		var building_id := String(building_id_value)
		var building := ContentService.get_building(building_id)
		var stage := int(building.get("stage", 1))
		if int(building.get("dwelling_tier", 0)) == 1 and int(building.get("choice_branch", 1)) == 1 and stage == 1:
			ids["dwelling"] = building_id
		elif String(building.get("line_id", "")) == "guild" and stage == 1:
			ids["guild"] = building_id
	return ids

func _set_built(session, built: Array) -> void:
	var active: Dictionary = TownRules.get_active_town(session)
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if String(towns[index].get("placement_id", "")) == String(active.get("placement_id", "")):
			towns[index]["built_buildings"] = built.duplicate()
	session.overworld["towns"] = towns

func _open(shell: Node, building_id: String) -> Dictionary:
	_dismiss_presentation(shell)
	await _frames(2)
	shell.call("validation_activate_building_information", building_id)
	await _frames(3)
	return shell.call("validation_building_information_snapshot", building_id)

func _no_scroll(failures: Array, info: Dictionary, label: String) -> void:
	_check(failures, not bool(info.get("scroll_needed", true)), "%s popout needs a scrollbar (panel %s)" % [label, info.get("panel_size", Vector2.ZERO)])

func _dismiss_presentation(shell: Node) -> void:
	var stage = shell.get("_town_stage_view")
	if stage != null and stage.has_method("dismiss_town_action_presentation"):
		stage.call("dismiss_town_action_presentation")

func _check(failures: Array, condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame

func _first_player_town(session) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			return town_value
	return {}

func _station_active_hero(session, town: Dictionary) -> void:
	var entrance: Dictionary = OverworldLevelRulesScript.town_entrance(town)
	var position := {"x": int(entrance.get("x", 0)), "y": int(entrance.get("y", 0))}
	if entrance.has("level"):
		position["level"] = int(entrance.get("level", 0))
	session.overworld["hero_position"] = position.duplicate(true)
	var hero = session.overworld.get("hero", {})
	if hero is Dictionary:
		hero["x"] = position.x
		hero["y"] = position.y
		hero["position"] = position.duplicate(true)
		session.overworld["hero"] = hero
		var heroes: Array = session.overworld.get("player_heroes", [])
		for index in range(heroes.size()):
			if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(hero.get("id", "")):
				heroes[index]["x"] = position.x
				heroes[index]["y"] = position.y
				heroes[index]["position"] = position.duplicate(true)
		session.overworld["player_heroes"] = heroes

func _capture(capture_dir: String, template_id: String, step: String, viewport_size: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s_%s_%dx%d.png" % [capture_dir, template_id, step, viewport_size.x, viewport_size.y])
