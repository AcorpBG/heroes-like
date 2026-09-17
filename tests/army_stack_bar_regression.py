#!/usr/bin/env python3
"""Existing seven-slot/save/combat checks through today's direct Town Log UI."""
import battle_readability_regression as runner

ROOT = runner.ROOT
OUTPUT = ROOT / '.artifacts/graphical-usability-20260917'
SCRIPT = (ROOT / 'tests/army_stack_management_bar_runtime_report.gd').read_text()
SCRIPT = SCRIPT.replace('ARMY_STACK_MANAGEMENT_BAR_RUNTIME_REPORT', 'BATTLE_READABILITY_REPORT')
# The historical fixture targets a hidden Logistics tab. Use the same live
# Town Log route the owner now clicks; keep every transfer/save/body assertion.
OLD_TOWN_ROUTE = '''\tvar tabs = shell.get_node_or_null("%ManagementTabs")
\tif tabs != null:
\t\ttabs.current_tab = 4'''
assert SCRIPT.count(OLD_TOWN_ROUTE) == 1
SCRIPT = SCRIPT.replace(OLD_TOWN_ROUTE, '\tshell._on_open_log_dialog_pressed()')


def main():
    runner.OUTPUT = OUTPUT
    runner.SCRIPT = SCRIPT
    return runner.main()


if __name__ == '__main__':
    raise SystemExit(main())
