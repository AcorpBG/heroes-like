#!/usr/bin/env python3
"""Writes the HEROES_NATIVE_<SUBSYSTEM> switch into every ported function.

Each subsystem of the native rules port (docs/native-rules-engine-transition.md)
lists its ported functions as the PORT(...) entries of its registry file and has
an engine script that holds its mode (SUBSYSTEMS below; the battle port:
src/gdextension/rules/core/port/registry.cpp and BattleEngine.gd). For each
function, scripts/core/<Script>.gd gets:

    static func _hex_cell(q: int, r: int) -> Dictionary:      # the switch
        if _battle_engine_mode == BattleEngine.GDSCRIPT:
            return _hex_cell__gd(q, r)
        ...
    static func _hex_cell__gd(q: int, r: int) -> Dictionary:  # the GDScript body
        ...

and every switched script gets the engine's preload and its mode in a static
var. The tool runs again after each new port: a switch that no longer matches
its registry entry or its GDScript signature is rewritten, and one whose entry
was renamed or removed is taken out again (the `__gd` body gets its name back).
A subsystem only touches the switches that read its own mode. --check only
reports what it would change and exits 1 if anything.

    python tools/native_battle_switch.py                      # every subsystem
    python tools/native_battle_switch.py --subsystem battle
    python tools/native_battle_switch.py --check
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PORT_DIR = ROOT / "src/gdextension/rules/core/port"
SCRIPTS = ROOT / "scripts/core"
PORT_LINE = re.compile(r"^\s*PORT\((\w+), (\w+), (\d+), (true|false),")
NEWLINE = chr(10)
SIGNATURE = re.compile(r"^static func (\w+)\((.*)\)\s*(->\s*([\w\[\], ]+))?\s*:\s*$")


class Subsystem:
    def __init__(self, registry: str, engine: str, fallback: bool = False, validate: bool = False) -> None:
        self.registry = PORT_DIR / registry
        self.engine = engine
        # A port that leaves paths to GDScript (state::NotPorted): in native
        # mode the switch runs the GDScript body when the engine's not_ported()
        # says the native call reached one.
        self.fallback = fallback
        # Shadow of a writing function without a copy of its arguments: the
        # engine's before_writing(key, args) runs the native port first
        # (AurelionRules.port_validate_begin) and returns the check's handle.
        self.validate = validate
        # BattleEngine -> _battle_engine_mode
        self.mode_var = "_" + re.sub(r"(?<!^)(?=[A-Z])", "_", engine).lower() + "_mode"
        self.engine_const = f'const {engine} = preload("res://scripts/core/{engine}.gd")'
        self.mode_line = f"static var {self.mode_var}: int = {engine}.mode"


# One entry per subsystem: its registry file in core/port and its engine script.
SUBSYSTEMS = {
    "battle": Subsystem("registry.cpp", "BattleEngine"),
    "ai": Subsystem("ai_registry.cpp", "AiEngine", fallback=True, validate=True),
}


def ported_functions(subsystem: Subsystem) -> list[tuple[str, str, int, bool]]:
    if not subsystem.registry.is_file():
        raise SystemExit(f"{subsystem.registry} is missing")
    found = []
    for line in subsystem.registry.read_text(encoding="utf-8").splitlines():
        match = PORT_LINE.match(line)
        if match:
            found.append((match.group(1), match.group(2), int(match.group(3)), match.group(4) == "true"))
    if not found:
        raise SystemExit(f"no PORT entries in {subsystem.registry}")
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


def switch_lines(subsystem: Subsystem, script: str, name: str, params: str, returns: str, writes: bool) -> list[str]:
    signature = f"static func {name}({params}){' -> ' + returns if returns else ''}:"
    args = ", ".join(param_name(p) for p in split_params(params))
    call = f"{name}__gd({args})"
    key = f'&"{script}.{name}"'
    void = returns == "void"
    mode, engine = subsystem.mode_var, subsystem.engine
    before_args = f"{key}, [{args}]" if subsystem.validate else f"[{args}]"
    lines = [signature]
    if not writes:
        if void:
            raise SystemExit(f"{script}.{name}: a void function that writes nothing has no result to check")
        lines += [
            f"\tif {mode} == {engine}.GDSCRIPT:",
            f"\t\treturn {call}",
            f"\tif {mode} == {engine}.NATIVE:",
        ]
        if subsystem.fallback:
            lines += [
                f"\t\tvar native_result = {engine}.native({key}, [{args}])",
                f"\t\treturn {call} if {engine}.not_ported() else native_result",
            ]
        else:
            lines += [f"\t\treturn {engine}.native({key}, [{args}])"]
        lines += [
            f"\tvar result = {call}",
            f"\t{engine}.check({key}, [{args}], result)",
            "\treturn result",
        ]
    elif void:
        lines += [
            f"\tif {mode} == {engine}.GDSCRIPT:",
            f"\t\t{call}",
            f"\telif {mode} == {engine}.NATIVE:",
            f"\t\t{engine}.native_writing({key}, [{args}])",
        ]
        if subsystem.fallback:
            lines += [
                f"\t\tif {engine}.not_ported():",
                f"\t\t\t{call}",
            ]
        lines += [
            "\telse:",
            f"\t\tvar before := {engine}.before_writing({before_args})",
            f"\t\t{call}",
            f"\t\t{engine}.check_writing({key}, before, [{args}], null)",
        ]
    else:
        lines += [
            f"\tif {mode} == {engine}.GDSCRIPT:",
            f"\t\treturn {call}",
            f"\tif {mode} == {engine}.NATIVE:",
        ]
        if subsystem.fallback:
            lines += [
                f"\t\tvar native_result = {engine}.native_writing({key}, [{args}])",
                f"\t\treturn {call} if {engine}.not_ported() else native_result",
            ]
        else:
            lines += [f"\t\treturn {engine}.native_writing({key}, [{args}])"]
        lines += [
            f"\tvar before := {engine}.before_writing({before_args})",
            f"\tvar result = {call}",
            f"\t{engine}.check_writing({key}, before, [{args}], result)",
            "\treturn result",
        ]
    return lines + [""]


def add_engine_header(subsystem: Subsystem, lines: list[str], path: Path) -> bool:
    if subsystem.engine_const in lines:
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
        lines[insert:insert] = ["", subsystem.engine_const, subsystem.mode_line]
        return True
    lines[insert:insert] = [subsystem.engine_const, subsystem.mode_line]
    return True


def signature_of(path: Path, lines: list[str], start: int, name: str) -> tuple[str, str]:
    # A signature over several lines (one parameter per line) is read as one.
    line, end = lines[start], start
    while not line.rstrip().endswith(":") and end + 1 < len(lines):
        end += 1
        line += " " + lines[end].strip()
    match = SIGNATURE.match(line)
    if not match:
        raise SystemExit(f"{path.name}: {name} has no readable signature: {line!r}")
    params, returns = match.group(2), (match.group(4) or "").strip()
    if end > start:
        params = ", ".join(split_params(params))
    if not returns:
        raise SystemExit(f"{path.name}: {name} has no declared return type")
    return params, returns


def definitions(lines: list[str], name: str) -> list[int]:
    return [i for i, line in enumerate(lines) if line.startswith(f"static func {name}(")]


def switch_bounds(path: Path, lines: list[str], name: str) -> tuple[int, int]:
    gd = definitions(lines, f"{name}__gd")
    tops = definitions(lines, name)
    if len(gd) != 1 or len(tops) != 1 or tops[0] > gd[0]:
        raise SystemExit(f"{path.name}: {name} must have one switch right above one {name}__gd")
    return tops[0], gd[0]


def switch_script(subsystem: Subsystem, path: Path, functions: list[tuple[str, int, bool]], check: bool) -> list[str]:
    lines = path.read_text(encoding="utf-8").split(NEWLINE)
    registered = {name: (arity, writes) for name, arity, writes in functions}
    changes = []
    if functions and add_engine_header(subsystem, lines, path):
        changes.append(f"{path.name}: {subsystem.engine} preload and mode")
    all_switched = [m.group(1) for m in (re.match(r"^static func (\w+)__gd\(", line) for line in lines) if m]
    switched = []
    for name in all_switched:
        top, gd = switch_bounds(path, lines, name)
        if any(subsystem.mode_var in line for line in lines[top:gd]):
            switched.append(name)
    for name in switched:
        top, gd = switch_bounds(path, lines, name)
        params, returns = signature_of(path, lines, gd, f"{name}__gd")
        if name not in registered:
            # Renamed or removed in the registry: the switch would call a missing native function.
            lines[gd] = lines[gd].replace(f"static func {name}__gd(", f"static func {name}(", 1)
            del lines[top:gd]
            changes.append(f"{path.name}: {name} has no registry entry, switch removed")
            continue
        arity, writes = registered[name]
        if len(split_params(params)) != arity:
            raise SystemExit(f"{path.name}: {name} takes {len(split_params(params))} parameters, {subsystem.registry.name} says {arity}")
        expected = switch_lines(subsystem, path.stem, name, params, returns, writes)
        if lines[top:gd] != expected:
            lines[top:gd] = expected
            changes.append(f"{path.name}: {name} switch rewritten (signature or registry entry changed)")
    for name, (arity, writes) in registered.items():
        if name in switched:
            continue
        if name in all_switched:
            raise SystemExit(f"{path.name}: {name} is already switched by another subsystem")
        starts = definitions(lines, name)
        if len(starts) != 1:
            raise SystemExit(f"{path.name}: {len(starts)} definitions of {name}")
        params, returns = signature_of(path, lines, starts[0], name)
        if len(split_params(params)) != arity:
            raise SystemExit(f"{path.name}: {name} takes {len(split_params(params))} parameters, {subsystem.registry.name} says {arity}")
        lines[starts[0]] = lines[starts[0]].replace(f"static func {name}(", f"static func {name}__gd(", 1)
        lines[starts[0]:starts[0]] = switch_lines(subsystem, path.stem, name, params, returns, writes)
        changes.append(f"{path.name}: {name}")
    if changes and not check:
        path.write_text(NEWLINE.join(lines), encoding="utf-8", newline=NEWLINE)
    return changes


def switch_subsystem(name: str, subsystem: Subsystem, check: bool) -> int:
    by_script: dict[str, list[tuple[str, int, bool]]] = {}
    for script, function, arity, writes in ported_functions(subsystem):
        by_script.setdefault(script, []).append((function, arity, writes))
    changes = []
    for script, functions in sorted(by_script.items()):
        if not (SCRIPTS / f"{script}.gd").is_file():
            raise SystemExit(f"{subsystem.registry.name} names {script}, which is not a script in {SCRIPTS}")
        changes += switch_script(subsystem, SCRIPTS / f"{script}.gd", functions, check)
    # Scripts with this subsystem's switches but no registry entries left.
    for path in sorted(SCRIPTS.glob("*.gd")):
        if path.stem not in by_script and subsystem.mode_var in path.read_text(encoding="utf-8"):
            changes += switch_script(subsystem, path, [], check)
    for change in changes:
        print(("would change: " if check else "changed: ") + f"{name}: {change}")
    if not changes:
        print(f"{name}: every ported function is switched ({sum(len(f) for f in by_script.values())})")
    return len(changes)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--subsystem", choices=sorted(SUBSYSTEMS), help="only this subsystem (default: every one)")
    parser.add_argument("--check", action="store_true", help="report missing switches without writing them")
    options = parser.parse_args()
    names = [options.subsystem] if options.subsystem else list(SUBSYSTEMS)
    changes = sum(switch_subsystem(name, SUBSYSTEMS[name], options.check) for name in names)
    return 1 if options.check and changes else 0


if __name__ == "__main__":
    sys.exit(main())
