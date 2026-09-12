#!/usr/bin/env python3
"""Same living scenery coverage against isolated Linux/Windows releases."""
import overworld_living_scenery_regression as scenery
import packaged_menu_and_turn_readability_regression as package

if __name__ == '__main__':
    package.ui = scenery
    raise SystemExit(package.main())
