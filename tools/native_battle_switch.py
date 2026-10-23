#!/usr/bin/env python3
"""Writes the HEROES_NATIVE_<SUBSYSTEM> switch into every ported function.

Each subsystem of the native rules port (docs/native-rules-engine-transition.md)
lists its ported functions as the PORT(...) entries of its registry file and has
an engine script that holds its mode (SUBSYSTEMS below; the day port:
src/gdextension/rules/core/port/day_registry.cpp and DayEngine.gd). For each
function, scripts/core/<Script>.gd (or scripts/persistence/<Script>.gd) gets:

    static func normalize_overworld_state(session: SessionData) -> void:      # the switch
        if _day_engine_mode == DayEngine.GDSCRIPT:
            normalize_overworld_state__gd(session)
        ...
    static func normalize_overworld_state__gd(session: SessionData) -> void:  # the GDScript body
        ...

and every switched script gets the engine's preload and its mode in a static
var.

A host function, one the phase leaves in GDScript and its ports call (the
HOST(Script, function, arity) entries of the registry file), gets a wrapper
over its renamed body the same way:

    static func _host_function(session: SessionData) -> Dictionary:
        if _day_engine_mode == DayEngine.SHADOW:
            DayEngine.host_point(&"Script._host_function", [session])
        return _host_function__gd(session)

In gdscript and native mode it runs the body (the native port's host call
calls the wrapper by name); in shadow mode it first checks the native port's
run that stopped at this host call (AurelionRules.port_validate_point).

A checked function, one a subsystem ports only inside a larger native call
(the CHECK(Script, function, arity, writes, ...) entries), runs its GDScript
body in gdscript and native mode, for its callers outside that call; in shadow
mode it is checked like a ported function, so a shadow run checks each of its
calls on its own.

The tool runs again after each new port: a switch that no longer matches
its registry entry or its GDScript signature is rewritten, and one whose entry
was renamed or removed is taken out again (the `__gd` body gets its name back).
A subsystem only touches the switches that read its own mode. --check only
reports what it would change and exits 1 if anything.

A slice's merge turns its entries into NATIVE(Script, function, arity, writes,
...) ones (Phase 7, owner decision D-d): the function runs only as its native
port, so its switch becomes a thin wrapper over the engine's native call and
its `__gd` body is deleted:

    static func tile_is_blocked(session: SessionData, x: int, y: int, level: int = -1) -> bool:
        return HumanEngine.native_writing(&"OverworldRules.tile_is_blocked", [session, x, y, level])

An autoload's method (scripts/autoload, SaveService) gets the same wrapper as
an instance func; its port reads the autoload's vars as the object's members.

A script left without switches keeps the engine's preload and loses its mode.
A subsystem whose port falls back to GDScript (the day's) has no NATIVE
entries: a wrapper has no body to fall back to.

The battle port's switch went with its GDScript copies in Phase 2d: battles run
native only, and its functions that GDScript still calls are thin wrappers over
BattleEngine.native and native_writing.

    python tools/native_battle_switch.py                      # every subsystem
    python tools/native_battle_switch.py --subsystem day
    python tools/native_battle_switch.py --check
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PORT_DIR = ROOT / "src/gdextension/rules/core/port"
# The folders of the scripts a registry names (by file name, unique across them).
SCRIPT_DIRS = (ROOT / "scripts/core", ROOT / "scripts/persistence", ROOT / "scripts/autoload")
PORT_LINE = re.compile(r"^\s*(PORT|CHECK|NATIVE)\((\w+), (\w+), (\d+), (true|false),")
HOST_LINE = re.compile(r"^\s*HOST\((\w+), (\w+), (\d+)\)")
NEWLINE = chr(10)
SIGNATURE = re.compile(r"^(?:static )?func (\w+)\((.*)\)\s*(->\s*([\w\[\]., ]+))?\s*:\s*$")


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
        # DayEngine -> _day_engine_mode
        self.mode_var = "_" + re.sub(r"(?<!^)(?=[A-Z])", "_", engine).lower() + "_mode"
        self.engine_const = f'const {engine} = preload("res://scripts/core/{engine}.gd")'
        self.mode_line = f"static var {self.mode_var}: int = {engine}.mode"


# One entry per subsystem: its registry file in core/port and its engine script.
SUBSYSTEMS = {
    "day": Subsystem("day_registry.cpp", "DayEngine", fallback=True, validate=True),
    "human": Subsystem("human_registry.cpp", "HumanEngine", fallback=False, validate=True),
}


def ported_functions(subsystem: Subsystem) -> list[tuple[str, str, int, bool, bool, bool]]:
    """(script, function, arity, writes, checked only, merged) of each PORT, CHECK and NATIVE entry."""
    if not subsystem.registry.is_file():
        raise SystemExit(f"{subsystem.registry} is missing")
    found = []
    for line in subsystem.registry.read_text(encoding="utf-8").splitlines():
        match = PORT_LINE.match(line)
        if match:
            checked = match.group(1) == "CHECK"
            merged = match.group(1) == "NATIVE"
            if checked and not subsystem.validate:
                raise SystemExit(f"{subsystem.registry.name}: CHECK entries need a subsystem whose shadow validates (validate=True)")
            if merged and subsystem.fallback:
                raise SystemExit(f"{subsystem.registry.name}: NATIVE entries need a port that never falls back to GDScript")
            found.append((match.group(2), match.group(3), int(match.group(4)), match.group(5) == "true", checked, merged))
    if not found:
        raise SystemExit(f"no PORT or NATIVE entries in {subsystem.registry}")
    return found


def host_functions(subsystem: Subsystem) -> list[tuple[str, str, int]]:
    found = []
    for line in subsystem.registry.read_text(encoding="utf-8").splitlines():
        match = HOST_LINE.match(line)
        if match:
            found.append((match.group(1), match.group(2), int(match.group(3))))
    if found and not subsystem.validate:
        # A shadow check stops at a host call only where it validates.
        raise SystemExit(f"{subsystem.registry.name}: HOST entries need a subsystem whose shadow validates (validate=True)")
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


def local_name(base: str, names: list[str]) -> str:
    # A local of the switch, renamed when a parameter has its name.
    name = base
    while name in names:
        name = "switch_" + name
    return name


def switch_lines(subsystem: Subsystem, script: str, name: str, params: str, returns: str, writes: bool) -> list[str]:
    signature = f"static func {name}({params}){' -> ' + returns if returns else ''}:"
    names = [param_name(p) for p in split_params(params)]
    args = ", ".join(names)
    result, before, native_result = (local_name(base, names) for base in ("result", "before", "native_result"))
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
                f"\t\tvar {native_result} = {engine}.native({key}, [{args}])",
                f"\t\treturn {call} if {engine}.not_ported() else {native_result}",
            ]
        else:
            lines += [f"\t\treturn {engine}.native({key}, [{args}])"]
        lines += [
            f"\tvar {result} = {call}",
            f"\t{engine}.check({key}, [{args}], {result})",
            f"\treturn {result}",
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
            f"\t\tvar {before} := {engine}.before_writing({before_args})",
            f"\t\t{call}",
            f"\t\t{engine}.check_writing({key}, {before}, [{args}], null)",
        ]
    else:
        lines += [
            f"\tif {mode} == {engine}.GDSCRIPT:",
            f"\t\treturn {call}",
            f"\tif {mode} == {engine}.NATIVE:",
        ]
        if subsystem.fallback:
            lines += [
                f"\t\tvar {native_result} = {engine}.native_writing({key}, [{args}])",
                f"\t\treturn {call} if {engine}.not_ported() else {native_result}",
            ]
        else:
            lines += [f"\t\treturn {engine}.native_writing({key}, [{args}])"]
        lines += [
            f"\tvar {before} := {engine}.before_writing({before_args})",
            f"\tvar {result} = {call}",
            f"\t{engine}.check_writing({key}, {before}, [{args}], {result})",
            f"\treturn {result}",
        ]
    return lines + [""]


def host_lines(subsystem: Subsystem, script: str, name: str, params: str, returns: str) -> list[str]:
    signature = f"static func {name}({params}){' -> ' + returns if returns else ''}:"
    args = ", ".join(param_name(p) for p in split_params(params))
    call = f"{name}__gd({args})"
    return [
        signature,
        f"\tif {subsystem.mode_var} == {subsystem.engine}.SHADOW:",
        f'\t\t{subsystem.engine}.host_point(&"{script}.{name}", [{args}])',
        f"\t{call}" if returns == "void" else f"\treturn {call}",
        "",
    ]


def check_lines(subsystem: Subsystem, script: str, name: str, params: str, returns: str) -> list[str]:
    signature = f"static func {name}({params}){' -> ' + returns if returns else ''}:"
    names = [param_name(p) for p in split_params(params)]
    args = ", ".join(names)
    result, before = (local_name(base, names) for base in ("result", "before"))
    call = f"{name}__gd({args})"
    key = f'&"{script}.{name}"'
    mode, engine = subsystem.mode_var, subsystem.engine
    lines = [signature, f"\tif {mode} != {engine}.SHADOW:"]
    if returns == "void":
        return lines + [
            f"\t\t{call}",
            "\t\treturn",
            f"\tvar {before} := {engine}.before_writing({key}, [{args}])",
            f"\t{call}",
            f"\t{engine}.check_writing({key}, {before}, [{args}], null)",
            "",
        ]
    return lines + [
        f"\t\treturn {call}",
        f"\tvar {before} := {engine}.before_writing({key}, [{args}])",
        f"\tvar {result} = {call}",
        f"\t{engine}.check_writing({key}, {before}, [{args}], {result})",
        f"\treturn {result}",
        "",
    ]


def native_lines(subsystem: Subsystem, script: str, name: str, params: str, returns: str, writes: bool, static: bool = True) -> list[str]:
    signature = f"{'static ' if static else ''}func {name}({params}){' -> ' + returns if returns else ''}:"
    args = ", ".join(param_name(p) for p in split_params(params))
    if returns == "void" and not writes:
        raise SystemExit(f"{script}.{name}: a void function that writes nothing has no result")
    call = f'{subsystem.engine}.{"native_writing" if writes else "native"}(&"{script}.{name}", [{args}])'
    return [signature, f"\t{call}" if returns == "void" else f"\treturn {call}", ""]


def body_end(lines: list[str], start: int) -> int:
    """The line after a function's last line of code (its signature may span lines)."""
    end = start
    while not lines[end].rstrip().endswith(":"):
        end += 1
    end += 1
    while end < len(lines) and (lines[end].strip() == "" or lines[end][:1] in ("\t", " ")):
        end += 1
    while lines[end - 1].strip() == "":
        end -= 1
    return end


def wrapper_lines(subsystem: Subsystem, script: str, name: str, params: str, returns: str, writes: bool, host: bool, checked: bool = False) -> list[str]:
    if host:
        return host_lines(subsystem, script, name, params, returns)
    if checked:
        return check_lines(subsystem, script, name, params, returns)
    return switch_lines(subsystem, script, name, params, returns, writes)


def add_engine_header(subsystem: Subsystem, lines: list[str], path: Path, with_mode: bool = True) -> bool:
    if subsystem.engine_const in lines:
        if with_mode and subsystem.mode_line not in lines:
            lines.insert(lines.index(subsystem.engine_const) + 1, subsystem.mode_line)
            return True
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
        lines[insert:insert] = ["", subsystem.engine_const] + ([subsystem.mode_line] if with_mode else [])
        return True
    lines[insert:insert] = [subsystem.engine_const] + ([subsystem.mode_line] if with_mode else [])
    return True


def signature_of(path: Path, lines: list[str], start: int, name: str, untyped: bool = False) -> tuple[str, str]:
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
    if not returns and not untyped:
        raise SystemExit(f"{path.name}: {name} has no declared return type")
    return params, returns


def definitions(lines: list[str], name: str, methods: bool = False) -> list[int]:
    """A static func's lines; with methods, an instance func's too (an autoload's NATIVE entries)."""
    return [i for i, line in enumerate(lines) if line.startswith(f"static func {name}(") or (methods and line.startswith(f"func {name}("))]


def switch_bounds(path: Path, lines: list[str], name: str) -> tuple[int, int]:
    gd = definitions(lines, f"{name}__gd")
    tops = definitions(lines, name)
    if len(gd) != 1 or len(tops) != 1 or tops[0] > gd[0]:
        raise SystemExit(f"{path.name}: {name} must have one switch right above one {name}__gd")
    return tops[0], gd[0]


def switch_script(subsystem: Subsystem, path: Path, functions: list[tuple[str, int, bool, bool, bool, bool]], check: bool) -> list[str]:
    lines = path.read_text(encoding="utf-8").split(NEWLINE)
    # A host function's wrapper reads the mode too: it is registered as a switch is.
    registered = {name: (arity, writes, host, checked) for name, arity, writes, host, checked, merged in functions if not merged}
    merged = {name: (arity, writes) for name, arity, writes, host, checked, is_merged in functions if is_merged}
    changes = []
    if functions and add_engine_header(subsystem, lines, path, with_mode=bool(registered)):
        changes.append(f"{path.name}: {subsystem.engine} preload" + (" and mode" if registered else ""))
    all_switched = [m.group(1) for m in (re.match(r"^static func (\w+)__gd\(", line) for line in lines) if m]
    switched = []
    for name in all_switched:
        top, gd = switch_bounds(path, lines, name)
        if any(subsystem.mode_var in line for line in lines[top:gd]):
            switched.append(name)
    for name in switched:
        top, gd = switch_bounds(path, lines, name)
        params, returns = signature_of(path, lines, gd, f"{name}__gd")
        if name in merged:
            arity, writes = merged[name]
            if len(split_params(params)) != arity:
                raise SystemExit(f"{path.name}: {name} takes {len(split_params(params))} parameters, {subsystem.registry.name} says {arity}")
            lines[top:body_end(lines, gd)] = native_lines(subsystem, path.stem, name, params, returns, writes)[:-1]
            changes.append(f"{path.name}: {name} merged, a wrapper over its port (its __gd body deleted)")
            continue
        if name not in registered:
            # Renamed or removed in the registry: the switch would call a missing native function.
            lines[gd] = lines[gd].replace(f"static func {name}__gd(", f"static func {name}(", 1)
            del lines[top:gd]
            changes.append(f"{path.name}: {name} has no registry entry, switch removed")
            continue
        arity, writes, host, checked = registered[name]
        if len(split_params(params)) != arity:
            raise SystemExit(f"{path.name}: {name} takes {len(split_params(params))} parameters, {subsystem.registry.name} says {arity}")
        expected = wrapper_lines(subsystem, path.stem, name, params, returns, writes, host, checked)
        if lines[top:gd] != expected:
            lines[top:gd] = expected
            changes.append(f"{path.name}: {name} switch rewritten (signature or registry entry changed)")
    for name, (arity, writes, host, checked) in registered.items():
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
        lines[starts[0]:starts[0]] = wrapper_lines(subsystem, path.stem, name, params, returns, writes, host, checked)
        changes.append(f"{path.name}: {name}" + (" (host wrapper)" if host else ""))
    for name, (arity, writes) in merged.items():
        if name in switched:
            continue
        starts = definitions(lines, name, methods=True)
        if len(starts) != 1:
            raise SystemExit(f"{path.name}: {len(starts)} definitions of {name}")
        # An instance func may leave its result untyped (a method that answers a session or null).
        static = lines[starts[0]].startswith("static func ")
        params, returns = signature_of(path, lines, starts[0], name, untyped=not static)
        if len(split_params(params)) != arity:
            raise SystemExit(f"{path.name}: {name} takes {len(split_params(params))} parameters, {subsystem.registry.name} says {arity}")
        expected = native_lines(subsystem, path.stem, name, params, returns, writes, static)[:-1]
        end = body_end(lines, starts[0])
        if lines[starts[0]:end] == expected:
            continue
        # The body is one line after the signature, which may span lines.
        signature_end = starts[0]
        while not lines[signature_end].rstrip().endswith(":"):
            signature_end += 1
        if end - signature_end != 2 or f"{subsystem.engine}.native" not in lines[signature_end + 1]:
            raise SystemExit(f"{path.name}: {name} is a NATIVE entry with a GDScript body; delete the body by hand")
        lines[starts[0]:end] = expected
        changes.append(f"{path.name}: {name} wrapper rewritten (signature or registry entry changed)")
    # The mode line of a script whose switches are gone, and the preload nothing calls.
    mode_uses = [i for i, line in enumerate(lines) if subsystem.mode_var in line and line != subsystem.mode_line]
    if not mode_uses and subsystem.mode_line in lines:
        lines.remove(subsystem.mode_line)
        changes.append(f"{path.name}: {subsystem.engine} mode removed, no switch reads it")
    engine_uses = [line for line in lines if f"{subsystem.engine}." in line and line != subsystem.engine_const]
    if not engine_uses and subsystem.engine_const in lines:
        lines.remove(subsystem.engine_const)
        changes.append(f"{path.name}: {subsystem.engine} preload removed, nothing calls it")
    if changes and not check:
        path.write_text(NEWLINE.join(lines), encoding="utf-8", newline=NEWLINE)
    return changes


def switch_subsystem(name: str, subsystem: Subsystem, check: bool) -> int:
    by_script: dict[str, list[tuple[str, int, bool, bool, bool, bool]]] = {}
    ported = ported_functions(subsystem)
    hosts = host_functions(subsystem)
    ported_names = {f"{script}.{function}" for script, function, _, _, _, _ in ported}
    for script, function, _ in hosts:
        if f"{script}.{function}" in ported_names:
            raise SystemExit(f"{subsystem.registry.name}: {script}.{function} is both a PORT and a HOST entry")
    for script, function, arity, writes, checked, merged in ported:
        by_script.setdefault(script, []).append((function, arity, writes, False, checked, merged))
    for script, function, arity in hosts:
        by_script.setdefault(script, []).append((function, arity, True, True, False, False))
    changes = []
    for script, functions in sorted(by_script.items()):
        paths = [folder / f"{script}.gd" for folder in SCRIPT_DIRS if (folder / f"{script}.gd").is_file()]
        if len(paths) != 1:
            raise SystemExit(f"{subsystem.registry.name} names {script}, which is not one script in {', '.join(str(f) for f in SCRIPT_DIRS)}")
        changes += switch_script(subsystem, paths[0], functions, check)
    # Scripts with this subsystem's switches but no registry entries left.
    for path in sorted(p for folder in SCRIPT_DIRS for p in folder.glob("*.gd")):
        if path.stem not in by_script and subsystem.mode_var in path.read_text(encoding="utf-8"):
            changes += switch_script(subsystem, path, [], check)
    for change in changes:
        print(("would change: " if check else "changed: ") + f"{name}: {change}")
    if not changes:
        merged = sum(1 for entry in ported if entry[5])
        wrapped = f", every host function wrapped ({len(hosts)})" if hosts else ""
        natives = f", every merged one a wrapper over its port ({merged})" if merged else ""
        print(f"{name}: every ported function is switched ({len(ported) - merged}){natives}{wrapped}")
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
