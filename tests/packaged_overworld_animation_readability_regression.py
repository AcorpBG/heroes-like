#!/usr/bin/env python3
"""Run the same overworld animation probe against isolated exported owners."""
import overworld_animation_readability_regression as animation
import packaged_menu_and_turn_readability_regression as package

if __name__ == '__main__':
    package.ui = animation
    raise SystemExit(package.main())
