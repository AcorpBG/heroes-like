"""Builds the per-side router that stands in for BattleAiRules.gd inside an arena worker.

The game calls the battle AI through static functions of res://scripts/core/BattleAiRules.gd.
The worker replaces that script in memory (never on disk) with the router generated here: one
stub per static function, with the same signature, that forwards the call to the variant
playing the acting stack's side. Each variant is a full copy of BattleAiRules.gd, so its own
internal calls stay inside it.

A call is routed by the first parameter that names the acting stack (see STACK_PARAMS), else
by a side string parameter, else to the enemy's variant for functions named after the enemy,
else to the default variant. Shared plumbing such as payload merges takes the default.
"""
from __future__ import annotations

import re
from dataclasses import dataclass

STACK_PARAMS = ("active_stack", "stack", "attacker", "acting_stack", "actor", "caster_stack", "source_stack")
SIDE_PARAMS = ("side", "acting_side")
_IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


@dataclass
class StaticFunc:
    name: str
    params_text: str
    param_names: list[str]
    return_type: str  # "" when not annotated


def _matching_close(text: str, open_index: int) -> int:
    """Index of the bracket closing the one at open_index, skipping strings."""
    pairs = {"(": ")", "[": "]", "{": "}"}
    depth = 0
    quote = ""
    i = open_index
    while i < len(text):
        ch = text[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = ""
        elif ch in "\"'":
            quote = ch
        elif ch in pairs:
            depth += 1
        elif ch in pairs.values():
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError(f"unbalanced bracket at {open_index}")


def _split_top_level(text: str) -> list[str]:
    parts: list[str] = []
    depth = 0
    quote = ""
    current = ""
    for ch in text:
        if quote:
            current += ch
            if ch == quote:
                quote = ""
            continue
        if ch in "\"'":
            quote = ch
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "," and depth == 0:
            parts.append(current)
            current = ""
            continue
        current += ch
    if current.strip():
        parts.append(current)
    return [part.strip() for part in parts if part.strip()]


def _strip_comments(params_text: str) -> str:
    return "\n".join(line.split("#", 1)[0] if "#" in line and '"' not in line else line for line in params_text.splitlines())


def parse_static_funcs(source: str) -> list[StaticFunc]:
    funcs: list[StaticFunc] = []
    for match in re.finditer(r"^static func ([A-Za-z_][A-Za-z0-9_]*)\(", source, flags=re.MULTILINE):
        open_index = match.end() - 1
        close_index = _matching_close(source, open_index)
        params_text = _strip_comments(source[open_index + 1 : close_index])
        colon = source.index(":", close_index)
        tail = source[close_index + 1 : colon].strip()
        return_type = tail[2:].strip() if tail.startswith("->") else ""
        params = _split_top_level(params_text)
        names = []
        for param in params:
            ident = _IDENT.match(param)
            if ident is None:
                raise ValueError(f"cannot read parameter {param!r} of {match.group(1)}")
            names.append(ident.group(0))
        funcs.append(StaticFunc(match.group(1), ", ".join(params), names, return_type))
    return funcs


def _top_level_consts(source: str) -> list[str]:
    """Every top-level const declaration, multi-line ones included."""
    consts: list[str] = []
    for match in re.finditer(r"^const [A-Za-z_][A-Za-z0-9_]*", source, flags=re.MULTILINE):
        end = source.find("\n", match.start())
        line = source[match.start() : end if end >= 0 else len(source)]
        for opener in "([{":
            index = line.find(opener)
            if index >= 0 and line.count(opener) > line.count({"(": ")", "[": "]", "{": "}"}[opener]):
                close = _matching_close(source, match.start() + index)
                line = source[match.start() : close + 1]
                break
        consts.append(line)
    return consts


def _side_expression(func: StaticFunc) -> str:
    for name in STACK_PARAMS:
        if name in func.param_names:
            return f"_arena_side_of({name})"
    for name in SIDE_PARAMS:
        if name in func.param_names:
            return f"String({name})"
    if "enemy" in func.name.lower():
        return '"enemy"'
    return '""'


def strip_class_name(source: str) -> str:
    """A variant copy loads beside the real script, so it must not claim its global name."""
    return re.sub(r"^class_name\s+\w+\s*$", "", source, count=1, flags=re.MULTILINE)


def build_router(source: str) -> str:
    funcs = parse_static_funcs(source)
    reserved = {f.name for f in funcs if f.name.startswith("_arena_")}
    if reserved:
        raise ValueError(f"BattleAiRules.gd already defines {sorted(reserved)}")
    lines = [
        "extends RefCounted",
        "## Generated by tools/battle_ai_arena/router.py inside an arena worker only.",
        "## Stands in for BattleAiRules.gd and forwards each call to the variant",
        "## playing the acting stack's side.",
        "",
        *_top_level_consts(source),
        "",
        "static var _arena_policies: Dictionary = {}",
        "static var _arena_default: Script = null",
        "static var _arena_calls: Dictionary = {}",
        "",
        "static func _arena_install(policies: Dictionary, default_policy: Script) -> void:",
        "\t_arena_policies = policies",
        "\t_arena_default = default_policy",
        "\t_arena_calls = {}",
        "",
        "static func _arena_side_of(value: Variant) -> String:",
        '\treturn String(value.get("side", "")) if value is Dictionary else ""',
        "",
        "static func _arena_policy(side: String) -> Script:",
        "\tvar policy: Script = _arena_policies.get(side, _arena_default)",
        "\t_arena_calls[side] = int(_arena_calls.get(side, 0)) + 1",
        "\treturn policy",
        "",
    ]
    for func in funcs:
        signature = f"static func {func.name}({func.params_text})"
        if func.return_type:
            signature += f" -> {func.return_type}"
        call = f"_arena_policy({_side_expression(func)}).{func.name}({', '.join(func.param_names)})"
        lines.append(signature + ":")
        lines.append(f"\t{call}" if func.return_type == "void" else f"\treturn {call}")
        lines.append("")
    return "\n".join(lines)
