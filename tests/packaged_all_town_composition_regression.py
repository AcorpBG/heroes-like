#!/usr/bin/env python3
"""Run the all-town composition/input contract in isolated release packages."""
import all_town_composition_regression as composition
import packaged_menu_and_turn_readability_regression as package

if __name__ == '__main__':
    package.ui = composition
    raise SystemExit(package.main())
