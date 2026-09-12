#!/usr/bin/env python3
"""Exercise the town-defense contract against isolated Linux/Windows releases."""
import town_defender_clarity_regression as probe
import packaged_battle_readability_regression as package

if __name__ == '__main__':
    package.battle.OUTPUT = probe.OUTPUT
    package.battle.SCRIPT = probe.SCRIPT
    raise SystemExit(package.main())
