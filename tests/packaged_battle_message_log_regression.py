#!/usr/bin/env python3
"""Use the same isolated release bootstrap without dropping log assertions."""
import battle_message_log_regression as log
import packaged_battle_readability_regression as package

if __name__ == '__main__':
    package.battle = log
    raise SystemExit(package.main())
