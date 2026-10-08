# Town market

Owner follow-ups, 2026-10-07:

- The market and the magic guild each have one window, the building popout.
- The market converts one resource into another.
- The market costs only gold. Owner decision, 2026-10-08: the Marketplace costs 1,000 gold and the Trade Exchange 3,000 gold, 5 wood and 5 ore (see Market costs).
- Rare resources are fully tradeable, HoMM3 style: any resource for any other. This replaces the earlier rule that rare resources could only be bought at a Trade Exchange (the "rare import").

## One window

- Clicking the Marketplace or Trade Exchange opens its popout, which is the market. The Trade command and every "trade for it" button open the same popout. The Spells command opens the magic guild popout (its highest built stage).
- Trade and Spells are disabled with a hint until the building stands.
- The separate Town Market dialog, its exchange button list (`%Market`, `%MarketActions`) and the town spellbook dialog are gone. The hidden legacy management tab strip keeps its five pages; the Trade page no longer holds any market controls.
- Cost buttons route to the market popout: the construction board's Trade button and quick Trade strip, the popout upgrade line's **Trade for it**, and **Trade for it** on recruit cards in dwellings and the Muster Hall. The desk preselects the trade that covers the first missing resource (sell wood or ore for gold when gold is short). Closing the market returns to the board, dwelling or Muster Hall that asked.

## Trading desk

The market popout's main column is a HoMM-style desk. "You give" and "You get" each list every resource: gold, wood, ore and all six rare resources, as tiles wrapped into a five-column grid. Then come an amount slider with −, + and Max, the result (**Give 4 wood → 2 ore**), the rate, this week's limits, and a Trade button naming the order. Each "get" tile shows the price of one unit for the chosen give. Switching pairs never resizes the popout, and it fits without scrolling at 1280×720 and 1920×1080.

| Give → get | Mode | Price |
| --- | --- | --- |
| gold → any resource | buy | the market's buy rate; full lots of two wood or ore at a Trade Exchange cost 10% less |
| any resource → gold | sell | the market's sell rate; full lots of two wood or ore at a Trade Exchange pay 10% more |
| any resource ↔ any other | convert | the received resource at the midpoint of its buy and sell rate, paid with the given resource at its sell rate, rounded up |

- **Prices.** Every resource prices off the same curve: local abundance and the market tier's adjustment, then scaled by its economy value. `OverworldRules.MARKET_RESOURCE_VALUES` mirrors the economy's valuation `EnemyTurnRules._resource_value` (wood and ore 400, every rare 800, the valuation `validate_repo` pins), so a rare resource costs and sells for twice wood or ore. The report checks that the two tables match, so the AI never values a rare differently from the market. With no local abundance:

| Market | Wood and ore buy / sell | Rare buy / sell |
| --- | --- | --- |
| Marketplace | 720 / 290 | 1,440 / 580 |
| Trade Exchange | 590 / 380 | 1,180 / 760 |

  A town's own abundant resources (from faction and town income) are cheaper to buy and pay more to sell, for rares as for wood and ore.
- **Conversion rate** = (buy rate of the received resource + its sell rate) / (2 × sell rate of the given resource). It beats selling for gold and buying back, but a round trip always loses. Examples with no local abundance:

| Conversion | Marketplace | Trade Exchange | Through gold, Marketplace |
| --- | --- | --- | --- |
| wood → ore, rare → rare | 1.7 per unit | 1.3 | 2.5 |
| wood → rare | 3.5 wood per rare | 2.6 | 5.0 |
| rare → wood | 1.1 wood per rare | 1.6 | 0.8 |

  When one given unit buys more than one received unit (a rare into wood), the slider steps by whole given units, so no step pays for a fraction it does not receive.
- **No profitable cycle.** Buy prices always exceed every sell price, so no buy-then-sell loop pays, in one town or across towns and tiers. Each conversion leg costs more than its value back, so cycling conversions loses, and buying, converting and selling loses too. `tests/town_market_popout_report` checks every pair across all twelve town markets.
- **Weekly limits.** Limits apply per town, resource and week. A conversion counts as selling what you give and buying what you get. Automatic cost coverage, as used by construction readiness and the AI, still sells only wood and ore; rares are sold on purpose at the desk.

| Market | Wood and ore bought / sold | Each rare bought / sold |
| --- | --- | --- |
| Marketplace | 6 / 8 | 2 / 3 |
| Trade Exchange | 8 / 10 | 5 / 5 |

- **Old imports.** The old Trade Exchange import (the faction's two rares at 1,200 gold, 5 a week, buy only) is gone; rares buy through the same path as everything else. Its weekly counter already lived in the town's `market_usage.buy` bucket, so a saved count carries over and counts against the rare buy limit. The AI's rare banking for T6/T7 projects (`OverworldRules.bank_town_rare_imports`) uses the same prices and limits for every rare at either tier.
- Bulk lots apply per full lot, so buying three wood at a Trade Exchange costs one discounted lot of two plus one unit, never more than buying them separately.

## Rules and ownership

- `TownRules.market_trade_quote(market, usage, stock, give_id, receive_id, amount)` is the pure rule for every pair: mode, the most the stores and weekly limits allow, the amounts given and received, the order id, the rate and limit text, and why nothing can trade. `TownRules.market_conversion_rate` returns the exact fraction.
- `TownRules.market_desk(session, need)` builds the popout model (resources, every pair's terms and a quote for each slider step, the suggested pair). Opening it never changes the session.
- `TownRules.perform_market_action` runs every order: `market:buy:<id>:<n>` and `market:sell:<id>:<n>` through `OverworldRules.perform_town_market_action`, `market:convert:<give>:<get>:<n>` through `TownRules._perform_market_conversion`, which re-quotes, moves both resources and records the weekly usage. The save shape (`market_usage` buy and sell buckets) is unchanged.
- `OverworldRules._town_market_state` prices every market resource (`MARKET_RESOURCE_KEYS`) and lists the rares in `rare_resources`. Market profiles in `content/buildings.json` carry the tier's rate adjustments, which rares share with wood and ore, and the per-resource weekly limit bonuses.
- `TownBuildingPanelView` renders the desk from the model's quotes and emits `market_trade_requested(action_id)`; `TownShell` performs it and refreshes the popout in place.

## Market costs

Every faction builds the same two market stages. On 2026-10-07 both became gold-only (the wood part turned into gold at 400 per wood). On 2026-10-08 the owner made the first stage cheap, because a town without a market falls behind for good when it lacks a single resource, and gave the second stage a small wood and ore cost:

| Building | 2026-10-07 | Now |
| --- | --- | --- |
| Marketplace (`building_market_square`) | 3,000 gold | 1,000 gold |
| Trade Exchange (`building_dev_trade_exchange`) | 4,500 gold | 3,000 gold, 5 wood, 5 ore |

This applies to Embercourt, Mireclaw, Sunvault, Thornwake, Brasshollow and Veilmourn alike. The retired faction exchanges (River Granary Exchange, Smugglers Flotilla, Resonant Exchange) are outside every town tree and unchanged.

Computer towns value each market stage like a Storehouse: two weeks of the Storehouse's wood and ore income, 1.8 times that while a missing resource holds up their build list (`AiHeroRules._market_value`). The Marketplace therefore comes among a town's first builds, ahead of the hall upgrades, and the Trade Exchange about level with a Storehouse (`docs/ai-plays-by-player-rules.md`).

## Validation

`tests/town_market_popout_report.tscn` checks the trade rules:

- Wood and ore: the exact conversion rate, better than the gold path, a losing round trip, both weekly limits and bulk lots.
- Rare resources, in every town at both tiers: all eight resources trade, rares are priced above wood and ore, the market values equal the AI valuation, the Trade Exchange is better for every resource, the limits are those listed above, and every pair quotes exactly.
- No profitable buy/sell or conversion cycle in one town or across towns, and a saved import count that still counts.
- The two market stages cost what the table under Market costs lists, in every faction.

For every faction town (1920×1080 and 1280×720 alternate) it then drives the real TownShell:

- No old market or spell dialog nodes or modes, and Trade is disabled without a market.
- The Trade command and the building click open the same popout and Spells opens the guild popout, all without scrolling.
- Both rows list all nine resources.
- The popout buys and sells wood and ore, converts wood into ore, buys a rare, sells a rare, converts a rare into wood, wood into a rare and one rare into another. Each moves the stockpile by exactly the shown quote and records the weekly usage, and used-up limits refuse further orders.
- The construction board, dwelling and Muster Hall trade buttons open the market popout, and closing it returns to them.
- The Trade Exchange is better than the Marketplace for rares and allows more of them.

Set `MARKET_TOWN=<town id>` to run one town and `MARKET_CAPTURE_DIR` to keep window captures. `tests/town_rare_import_regression.py` covers the same rare rules for all six factions in session state: prices, both tiers' limits, save, capture and rebuild persistence, week reset, old saves, shared cost coverage and AI banking.
