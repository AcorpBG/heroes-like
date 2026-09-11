#!/usr/bin/env python3
"""Run identical town roster pointer/entry checks in isolated release packages."""
import town_roster_double_click_regression as roster
import packaged_menu_and_turn_readability_regression as package
if __name__=='__main__':
    package.ui=roster
    raise SystemExit(package.main())
