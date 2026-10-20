#!/usr/bin/env python3
"""Writes the HEROES_NATIVE_BATTLE switch into every ported battle function.

The ported functions are the PORT(...) entries of
src/gdextension/rules/core/port/registry.cpp (docs/native-rules-engine-transition.md,
Phase 1). For each one, scripts/core/<Script>.gd gets:

    static func _hex_cell(q: int, r: int) -> Dictionary:      # the switch
        if _battle_engine_mode == BattleEngine.GDSCRIPT:
            return _hex_cell__gd(q, r)
        ...
    static func _hex_cell__gd(q: int, r: int) -> Dictionary:  # the GDScript body
        ...

and every switched script gets the BattleEngine preload and its mode in a static
var. Switches already written are left alone, so the tool runs again after each
new port. --check only reports what it would change and exits 1 if anything.

    python tools/native_battle_switch.py
    python tools/native_battle_switch.py --check
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "src/gdextension/rules/core/port/registry.cpp"
SCRIPTS = ROOT / "scripts/core"
ENGINE_CONST = 'const BattleEngine = preload("res://scripts/core/BattleEngine.gd")'
MODE_VAR = "static var _battle_engine_mode: int = BattleEngine.mode"
PORT_LINE = re.compile(r"^\s*PORT\((\w+), (\w+), (\d+), (true|false),")
SIGNATURE = re.compile(r"^static func (\w+)\((.*)\)\s*(->\s*([\w\[\], ]+))?\s*:\s*$")


def ported_functions() -> list[tuple[str, str, int, bool]]:
    found = []
    for line in REGISTRY.read_text(encoding="utf-8").splitlines():
        match = PORT_LINE.match(line)
        if match:
            found.append((match.group(1), match.group(2), int(match.group(3)), match.group(4) == "true"))
    if not found:
        raise SystemExit(f"no PORT entries in {REGISTRY}")
    return found


def split_params(text: str) -> list[str]:
    params, depth, current = [], 0, ""
    for char in text:
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        if char == "," and depth == 0:
            params.append(current.strip())
            current = ""
        else:
            current += char
    if current.strip():
        params.append(current.strip())
    return params


def param_name(param: str) -> str:
    return re.split(r"[:=]", param, maxsplit=1)[0].strip()


def switch_lines(script: str, name: str, params: str, returns: str, writes: bool) -> list[str]:
    signature = f"static func {name}({params}){' -> ' + returns if returns else ''}:"
    args = ", ".join(param_name(p) for p in split_params(params))
    call = f"{name}__gd({args})"
    key = f'&"{script}.{name}"'
    void = returns == "void"
    lines = [signature]
    if not writes:
        if void:
            raise SystemExit(f"{script}.{name}: a void function that writes nothing has no result to check")
        lines += [
            "\tif _battle_engine_mode == BattleEngine.GDSCRIPT:",
            f"\t\treturn {call}",
            "\tif _battle_engine_mode == BattleEngine.NATIVE:",
            f"\t\treturn BattleEngine.native({key}, [{args}])",
            f"\tvar result = {call}",
            f"\tBattleEngine.check({key}, [{args}], result)",
            "\treturn result",
        ]
    elif void:
        lines += [
            "\tif _battle_engine_mode == BattleEngine.GDSCRIPT:",
            f"\t\t{call}",
            "\telif _battle_engine_mode == BattleEngine.NATIVE:",
            f"\t\tBattleEngine.native_writing({key}, [{args}])",
            "\telse:",
            f"\t\tvar before := BattleEngine.before_writing([{args}])",
            f"\t\t{call}",
            f"\t\tBattleEngine.check_writing({key}, before, [{args}], null)",
        ]
    else:
        lines += [
            "\tif _battle_engine_mode == BattleEngine.GDSCRIPT:",
            f"\t\treturn {call}",
            "\tif _battle_engine_mode == BattleEngine.NATIVE:",
            f"\t\treturn BattleEngine.native_writing({key}, [{args}])",
            f"\tvar before := BattleEngine.before_writing([{args}])",
            f"\tvar result = {call}",
            f"\tBattleEngine.check_writing({key}, before, [{args}], result)",
            "\treturn result",
        ]
    return lines + [""]


def add_engine_header(lines: list[str], path: Path) -> bool:
    if ENGINE_CONST in lines:
        return False
    # After the last top-level preload, else after `extends` and its doc comment.
    insert = -1
    for index, line in enumerate(lines):
        if line.startswith("const ") and "preload(" in line:
            insert = index + 1
        if line.startswith("static func") or line.startswith("func "):
            break
    if insert < 0:
        insert = next((i + 1 for i, line in enumerate(lines) if line.startswith("extends ")), 0)
        while insert < len(lines) and lines[insert].startswith("##"):
            insert += 1
        lines[insert:insert] = ["", ENGINE_CONST, MODE_VAR]
        return True
    lines[insert:insert] = [ENGINE_CONST, MODE_VAR]
    return True


def switch_script(path: Path, functions: list[tuple[str, int, bool]], check: bool) -> list[str]:
    lines = path.read_text(encoding="utf-8").split("\n")
    changes = []
    if add_engine_header(lines, path):
        changes.append(f"{path.name}: BattleEngine preload and mode")
    for name, arity, writes in functions:
        if any(line.startswith(f"static func {name}__gd(") for line in lines):
            continue
        starts = [i for i, line in enumerate(lines) if line.startswith(f"static func {name}(")]
        if len(starts) != 1:
            raise SystemExit(f"{path.name}: {len(starts)} definitions of {name}")
        match = SIGNATURE.match(lines[starts[0]])
        if not match:
            raise SystemExit(f"{path.name}: {name} has no one-line signature: {lines[starts[0]]!r}")
        params, returns = match.group(2), (match.group(4) or "").strip()
        if len(split_params(params)) != arity:
            raise SystemExit(f"{path.name}: {name} takes {len(split_params(params))} parameters, registry.cpp says {arity}")
        if not returns:
            raise SystemExit(f"{path.name}: {name} has no declared return type")
        lines[starts[0]] = lines[starts[0]].replace(f"static func {name}(", f"static func {name}__gd(", 1)
        lines[starts[0]:starts[0]] = switch_lines(path.stem, name, params, returns, writes)
        changes.append(f"{path.name}: {name}")
    if changes and not check:
        path.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    return changes


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="report missing switches without writing them")
    options = parser.parse_args()
    by_script: dict[str, list[tuple[str, int, bool]]] = {}
    for script, name, arity, writes in ported_functions():
        by_script.setdefault(script, []).append((name, arity, writes))
    changes = []
    for script, functions in sorted(by_script.items()):
        changes += switch_script(SCRIPTS / f"{script}.gd", functions, options.check)
    for change in changes:
        print(("missing: " if options.check else "switched: ") + change)
    if not changes:
        print(f"every ported function is switched ({sum(len(f) for f in by_script.values())})")
    return 1 if options.check and changes else 0


if __name__ == "__main__":
    sys.exit(main())
