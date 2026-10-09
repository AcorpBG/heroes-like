"""Pick faction line-ups for a batch of AI-vs-AI matches.

Usage: python pick_lineups.py <matches> <players> [--mirrors]

Prints one comma-separated line-up per match. Without --mirrors no faction
appears twice in a match and no two matches share the same set of factions
(when there are enough combinations); seat order is shuffled.
"""
import itertools
import json
import os
import random
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))


def factions():
    data = json.load(open(os.path.join(ROOT, "content", "factions.json"), encoding="utf-8"))
    items = data["items"] if isinstance(data, dict) else data
    return sorted(item["id"] for item in items)


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    matches, players = int(sys.argv[1]), int(sys.argv[2])
    mirrors = "--mirrors" in sys.argv
    ids = factions()
    if mirrors or players > len(ids):
        lineups = [[random.choice(ids) for _ in range(players)] for _ in range(matches)]
    else:
        combos = list(itertools.combinations(ids, players))
        random.shuffle(combos)
        lineups = [list(combos[i % len(combos)]) for i in range(matches)]
        for lineup in lineups:
            random.shuffle(lineup)
    for lineup in lineups:
        print(",".join(lineup))


if __name__ == "__main__":
    main()
