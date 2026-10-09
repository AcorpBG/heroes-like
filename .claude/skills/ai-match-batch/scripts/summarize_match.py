"""Summarize one ai_versus_ai_match_report JSON record.

Usage: python summarize_match.py <record.json>

last_day_standing is the last day a player held a town or a hero; for the
winner it is the final day. Battles are logged from the attacker's side, so
few lost battles is normal.
"""
import collections
import json
import sys

r = json.load(open(sys.argv[1], encoding="utf-8"))
st = r["setup"]
L = r["ledger"]
T = [e for e in r["timeline"] if e["type"] == "town_captured"]
B = r["battles"]
out = {
    "match_seed": st["match_seed"],
    "map_seed": st["map_seed"],
    "map_size": "%dx%d" % (st["map_size"].get("x", 0), st["map_size"].get("y", 0)),
    "towns_on_map": len(r.get("town_weeks", [{"towns": []}])[0]["towns"]),
    "factions": {s["player_id"]: s["faction"] for s in st["seats"]},
    "winner": r["winner"] or "none (day cap)",
    "winner_faction": next((s["faction"] for s in st["seats"] if s["player_id"] == r["winner"]), ""),
    "final_day": r["final_day"],
    "slowest_ai_day_ms": r["ai_turn_ms_max"],
    "battles": len(B),
    "battles_lost": sum(1 for b in B if b["result"] != "won"),
    "battle_kinds": dict(collections.Counter(b["defender_kind"] for b in B)),
    "town_captures": len(T),
    "captures_of_neutral_towns": sum(1 for e in T if e["from"] == "neutral"),
    "captures_without_defender": sum(1 for e in T if e["from"] != "neutral" and e["garrison_power"] <= 0),
    "last_day_standing": {p: max([row["day"] for row in L if row["sides"][p]["towns"] > 0 or row["sides"][p]["heroes"]] + [0]) for p in L[0]["sides"]},
    "final_sides": {p: {"towns": s["towns"], "heroes": len(s["heroes"]), "hero_strength": round(s["hero_power"]), "garrison_strength": round(s["garrison_power"]), "gold": s["treasury"].get("gold", 0), "sites": s["sites"]} for p, s in L[-1]["sides"].items()},
}
print(json.dumps(out, indent=1))
