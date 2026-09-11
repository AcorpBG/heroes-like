#!/usr/bin/env python3
"""Run Embercourt composition checks against the isolated release packages."""
import embercourt_town_overlap_regression as overlap
import packaged_menu_and_turn_readability_regression as package
if __name__ == '__main__':
    package.ui = overlap
    raise SystemExit(package.main())
