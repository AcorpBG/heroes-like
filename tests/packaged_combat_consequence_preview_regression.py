#!/usr/bin/env python3
"""Run consequence coverage through the established isolated release bootstrap."""
import combat_consequence_preview_regression as preview
import packaged_battle_readability_regression as package

if __name__ == '__main__':
    package.battle.OUTPUT = preview.OUTPUT
    package.battle.SCRIPT = preview.SCRIPT
    raise SystemExit(package.main())
