"""Summarize one ai_versus_ai_match_report JSON record.

Usage: python summarize_match.py <record.json>

last_day_standing is the last day a player held a town or a hero; for the
winner it is the final day. Battles are logged from the attacker's side, so
few lost battles is normal. The summary is tools/ai_match_batch.py's, which
also puts it in each results.jsonl line.
"""
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "..", "tools"))
from ai_match_batch import summarize_record  # noqa: E402

if len(sys.argv) < 2:
    sys.exit(__doc__)
print(json.dumps(summarize_record(json.load(open(sys.argv[1], encoding="utf-8"))), indent=1))
