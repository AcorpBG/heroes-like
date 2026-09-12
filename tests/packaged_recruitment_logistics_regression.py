#!/usr/bin/env python3
"""Run the local recruitment contract against isolated Linux/Windows packages."""
import recruitment_logistics_regression as probe
import packaged_battle_readability_regression as package

if __name__ == '__main__':
    package.battle.OUTPUT = probe.OUTPUT
    package.battle.SCRIPT = probe.SCRIPT
    raise SystemExit(package.main())
