#!/usr/bin/env python3
"""Use the established isolated release bootstrap for shared-help acceptance."""
import contextual_help_regression as help_probe
import packaged_battle_readability_regression as package

if __name__ == '__main__':
    package.battle.OUTPUT = help_probe.OUTPUT
    package.battle.SCRIPT = help_probe.SCRIPT
    raise SystemExit(package.main())
