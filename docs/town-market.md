# Town market

Owner follow-up, 2026-10-07: the market and the magic guild each have one window, the building popout; the market also converts one resource into another; the market costs only gold.

## One window

- Clicking the Marketplace or Trade Exchange opens its popout, which is the market. The Trade command and every "trade for it" button open the same popout. The Spells command opens the magic guild popout (its highest built stage).
- Trade and Spells are disabled with a hint until the building stands.
- The separate Town Market dialog, its exchange button list (`%Market`, `%MarketActions`) and the town spellbook dialog are gone. The hidden legacy management tab strip keeps its five pages; the Trade page no longer holds any market controls.
- Cost buttons route to the market popout: the construction board's Trade button and quick Trade strip, the popout upgrade line's **Trade for it**, and **Trade for it** on recruit cards in dwellings and the Muster Hall. The desk preselects the trade that covers the first missing resource (sell wood or ore for gold when gold is short). Closing the market returns to the board, dwelling or Muster Hall that asked.

## Trading desk

The market popout's main column is a HoMM-style desk: a row of resources to give (gold, wood, ore), a row of resources to get (gold, wood, ore and, at a Trade Exchange, the town's two rare imports), an amount slider with −, + and Max, the result (**Give 4 wood → 2 ore**), the rate, this week's limits, and a Trade button naming the order. Each "get" tile shows the price of one unit for the chosen give. Switching pairs never resizes the popout, and it fits without scrolling at 1280×720 and 1920×1080.

| Give → get | Mode | Price |
| --- | --- | --- |
| gold → wood/ore | buy | the market's buy rate; full lots of two at a Trade Exchange cost 10% less |
| wood/ore → gold | sell | the market's sell rate; full lots of two at a Trade Exchange pay 10% more |
| gold → rare import | buy | 1,200 gold each, 5 of each a week (Trade Exchange only) |
| wood ↔ ore | convert | the received resource at the midpoint of its buy and sell rate, paid with the given resource at its sell rate, rounded up |

- Conversion rate = (buy rate of the received resource + its sell rate) / (2 × sell rate of the given resource). It beats selling for gold and buying back, but is never one for one, so a round trip always loses. With no local abundance a Marketplace converts at 1.7 wood per ore (2.5 through gold) and a Trade Exchange at 1.3 (1.6 through gold).
- Rates come from the town's market state, so both modes follow the market tier (Marketplace or Trade Exchange) and the faction's and town's local abundance. They do not depend on how many markets the player owns.
- Weekly limits per town and resource stay 6 bought and 8 sold. A conversion counts as selling what you give and buying what you get. Rare imports are buy-only with gold; rare resources cannot be sold or converted.
- Bulk lots now apply per full lot, so buying three wood at a Trade Exchange costs one discounted lot of two plus one unit, never more than buying them separately.

## Rules and ownership

- `TownRules.market_trade_quote(market, usage, stock, give_id, receive_id, amount)` is the pure rule for every pair: mode, the most the stores and weekly limits allow, the amounts given and received, the order id, the rate and limit text, and why nothing can trade. `TownRules.market_conversion_rate` returns the exact fraction.
- `TownRules.market_desk(session, need)` builds the popout model (resources, every pair's terms and a quote for each slider amount, the suggested pair). Opening it never changes the session.
- `TownRules.perform_market_action` runs every order: `market:buy:<id>:<n>` and `market:sell:<id>:<n>` through `OverworldRules.perform_town_market_action`, `market:convert:<give>:<get>:<n>` through `TownRules._perform_market_conversion`, which re-quotes, moves both resources and records the weekly usage. The save shape (`market_usage` buy and sell buckets) is unchanged.
- `TownBuildingPanelView` renders the desk from the model's quotes and emits `market_trade_requested(action_id)`; `TownShell` performs it and refreshes the popout in place.

## Gold-only market

Every faction builds the same two market stages. The wood part of each cost became gold at 400 gold per wood, the value the economy uses to weigh construction costs (`EnemyTurnRules._resource_value`; the market itself buys wood at 500–760 and sells at 260–410), so the AI weighs both buildings exactly as before.

| Building | Before | After |
| --- | --- | --- |
| Marketplace (`building_market_square`) | 1,000 gold, 5 wood | 3,000 gold |
| Trade Exchange (`building_dev_trade_exchange`) | 2,500 gold, 5 wood | 4,500 gold |

This applies to Embercourt, Mireclaw, Sunvault, Thornwake, Brasshollow and Veilmourn alike. The retired faction exchanges (River Granary Exchange, Smugglers Flotilla, Resonant Exchange) are outside every town tree and unchanged.

## Validation

`tests/town_market_popout_report.tscn` checks the conversion rule (exact rate, better than the gold path, losing round trip, both weekly limits, gold-only imports, bulk lots) and that both market stages cost only gold in every faction. For every faction town (1920×1080 and 1280×720 alternate) it drives the real TownShell: no old market or spell dialog nodes or modes; Trade disabled without a market; the Trade command and the building click open the same popout and Spells opens the guild popout, all without scrolling; buy, sell and convert through the popout move the stockpile by exactly the shown quote and record the weekly usage; the construction board, dwelling and Muster Hall trade buttons open the market popout and closing returns to them; a Trade Exchange shows its imports, buys one with gold and refuses converting into it. Set `MARKET_TOWN=<town id>` to run one town and `MARKET_CAPTURE_DIR` to keep window captures.
