"""Replay the reviewed original-image registration recipe."""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
sys.path.insert(0, str(ROOT / 'tools'))
from register_fluid_source_sheets import register

register(HERE, json.loads((HERE / 'registration.json').read_text(encoding='utf-8')))
