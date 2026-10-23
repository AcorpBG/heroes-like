#!/usr/bin/env python3
"""G1 for the native battle port: GDScript time against the native port, per resolve (docs/native-rules-engine-transition.md,
Phase 1, "Checkpoint G1"; owner decision 2026-10-21).

    python tools/battle_port_g1/g1.py prepare MODE DEST [--rev REV]     # an instrumented copy of the branch point
    python tools/battle_port_g1/g1.py run DEST --corpus standard|holdout|seeds --out DIR [--jobs N] [--capture-every N]
    python tools/battle_port_g1/g1.py replay CAPDIR... --out FILE [--jobs N] [--repeat N] [--prime previous|none] [--fresh-writers] [--binary EXE]
    python tools/battle_port_g1/g1.py convert --replay FILE --out FILE [--jobs N] [--rounds N]
    python tools/battle_port_g1/g1.py summarize --resolve DIR --ported DIR --replay FILE --convert FILE [--native DIR] [--out FILE]
    python tools/battle_port_g1/g1.py remove DEST

The baseline is main at the branch point (`git merge-base HEAD origin/main`), not the branch in gdscript mode.
Since Phase 2d deleted the battle port's GDScript bodies, a baseline needs an earlier revision
(`--rev pre-native-phase2-exit`).
`prepare` makes a copy of it with tools/rules_parity.py and wraps, in that copy only:

- `BattleAutoResolveRules.resolve_active_battle`, which times each resolve (T_gd); the `_finalize_*` functions, the
  registry's other host targets (`HOST` entries: the battle ends the native loop calls in GDScript) and the result
  payload `_resolve_result` are paused out of it;
- mode `resolve`: nothing else, so T_gd carries no wrapper cost;
- mode `ported`: every function of the port registry (src/gdextension/rules/core/port/registry.cpp), which times the
  outermost entry into the ported set (T_gd_ported), less the paused calls inside it, and leaves the calls it makes
  alone: inside a ported body, calls to ported functions and to the port's native internals go straight to their raw
  bodies (a paused one keeps its wrapper);
- mode `capture`: the same entries, keeping their arguments and results as var_to_bytes blobs for the replay, and
  for each host call an entry makes its arguments before and after and its result.

Since slice 10 `resolve_active_battle` is in the registry, so each resolve is one outermost entry, as in the native
loop. The replay gives each of its host calls the captured result and arguments afterwards, outside the native clock.

Runs: the arena suites (standard, holdout: `arena.py --plain`, the game's own AI on both sides with no router) and the
six parity seeds' AI battles, reported apart. A resolve's key is the digest of its start battle and how often that
digest came before, so the three modes' lines match up. `replay` runs build/battle_port_replay (native only, no
Godot, no bridge) over the captures: each resolve's entries in one State that grows, results checked byte for byte.
r uses its cold time (every argument decoded first, all calls under one clock); r_warm and the split by layer and
function use its warm pass (each entry's arguments decoded just before it, each call under its own clock), which
finds the battle in cache as the native loop does. Each round clears the State as StateBridge::load does, keeping its
node buffers. r_first and r_warm_first use the first round, which finds the State as another resolve left it (--prime
previous, the default: the nearest earlier capture from another start battle runs untimed first, as in an engine that
keeps its State between resolves) or a new State (--prime none); r and r_warm use the median round, whose State held
the same resolve before. Every round's results are checked. `convert` times StateBridge::load at the start and store_in_place at the end of each captured
resolve, at the pool size the replay reached, in the branch's library, on a new State each round. `summarize` gives
r = T_gd_ported / T_nat_ported (per function, per layer, overall), c = T_conv / T_gd and the projection
S = 1 / (c + 1 / r). With --native, a `resolve` copy of the branch (`prepare resolve DEST --rev HEAD`) run with
battles native (before Phase 2d, HEROES_NATIVE_BATTLE=native) gives the measured time per resolve in native battle mode, the bridge included, and the
measured speed-up T_gd / T_native over the resolves both runs have.

Never run this while an owner AI batch runs; timing wants an idle machine. The timed parts (the resolve and ported
runs, the replay and the conversion) run with the same number of jobs at once, so both sides of r and c see the same
load; run.json and the .meta.json beside each replay and conversion file record the job count, the Godot binary and
any foreign Godot process seen during the run, and `summarize` reports them.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
REGISTRY = ROOT / "src/gdextension/rules/core/port/registry.cpp"
PORT_SOURCES = ROOT / "src/gdextension/rules/core/port"
LAYERS = HERE / "layers.json"
PROBE_PATH = "res://tools/battle_port_g1/g1_probe.gd"
PROBE_CONST = f'const G1 = preload("{PROBE_PATH}")'
PORT_LINE = re.compile(r"^\s*PORT\((\w+), (\w+), (\d+), (true|false),")
HOST_LINE = re.compile(r"^\s*HOST\((\w+), (\w+), (\d+)\),")
FUNC_START = re.compile(r"^static func (\w+)\(")
PRELOAD = re.compile(r'^const (\w+) = preload\("res://scripts/core/(\w+)\.gd"\)')
CLASS_NAME = re.compile(r"^class_name (\w+)")
RESOLVE = ("BattleAutoResolveRules", "resolve_active_battle")
PAUSED = {"BattleRules": re.compile(r"^_finalize_\w+$"), "BattleAutoResolveRules": re.compile(r"^_resolve_result$")}
MODES = ("resolve", "ported", "capture")
CORPORA = ("standard", "holdout", "quick", "seeds")
NEWLINE = chr(10)
IS_WINDOWS = os.name == "nt"


# --- the ported set ---------------------------------------------------------------------------------------------

def registry() -> dict[str, dict[str, bool]]:
    """Script -> {function: writes into its arguments}."""
    found: dict[str, dict[str, bool]] = {}
    for line in REGISTRY.read_text(encoding="utf-8").splitlines():
        match = PORT_LINE.match(line)
        if match:
            found.setdefault(match.group(1), {})[match.group(2)] = match.group(4) == "true"
    if not found:
        sys.exit(f"no PORT entries in {REGISTRY}")
    return found


def host_targets() -> dict[str, set[str]]:
    """Script -> the GDScript functions the port calls as host calls (gd::call_static)."""
    found: dict[str, set[str]] = {}
    for line in REGISTRY.read_text(encoding="utf-8").splitlines():
        match = HOST_LINE.match(line)
        if match:
            found.setdefault(match.group(1), set()).add(match.group(2))
    return found


def snake(name: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()


def native_internals(script: str, gd_functions: set[str], registered: set[str]) -> set[str]:
    """GDScript functions the port has as native helpers without a registry entry (called only natively)."""
    source = PORT_SOURCES / f"{snake(script)}.cpp"
    if not source.is_file():
        return set()
    defined = set(re.findall(r"^[A-Za-z_][\w:<>,*& ]*?\b(\w+)\((?:const )?State &state", source.read_text(encoding="utf-8"), re.M))
    return (defined & gd_functions) - registered


# --- GDScript text ------------------------------------------------------------------------------------------------

def code_spans(line: str) -> list[tuple[int, int]]:
    """The parts of a line outside string literals and comments."""
    spans, start, index, quote = [], 0, 0, ""
    while index < len(line):
        char = line[index]
        if quote:
            if char == "\\":
                index += 2
                continue
            if char == quote:
                quote = ""
                start = index + 1
        elif char in "\"'":
            spans.append((start, index))
            quote = char
        elif char == "#":
            spans.append((start, index))
            return spans
        index += 1
    if not quote:
        spans.append((start, len(line)))
    return spans


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


class Func:
    """One static function: its signature lines, its parameters, its return type and its body lines."""

    def __init__(self, lines: list[str], start: int):
        self.name = FUNC_START.match(lines[start]).group(1)
        self.start = start
        text, depth, index, opened = "", 0, start, False
        while True:
            line = lines[index]
            spans = code_spans(line)
            code = line[:spans[-1][1]] if spans else line  # without a trailing comment
            in_code = [False] * len(code)
            for a, b in spans:
                for position in range(a, min(b, len(code))):
                    in_code[position] = True
            end = -1
            for position, char in enumerate(code):
                if not in_code[position]:
                    continue
                if char == "(":
                    depth += 1
                    opened = True
                elif char == ")":
                    depth -= 1
                elif opened and depth == 0 and char == ":" and code[position:position + 2] != ":=":
                    end = position
                    break
            if end >= 0:
                text += code[:end]
                break
            text += code + " "
            index += 1
        self.end = index  # last signature line
        head = text[text.index("(") + 1:]
        close = head.rindex(")")
        self.params = " ".join(head[:close].split())
        returns = head[close + 1:].strip()
        self.returns = returns[2:].strip() if returns.startswith("->") else ""
        self.args = [param_name(p) for p in split_params(self.params)]
        body_end = index + 1
        while body_end < len(lines) and not re.match(r"^[^\s#]", lines[body_end]):
            body_end += 1
        self.body = (index + 1, body_end)

    def signature(self, name: str) -> str:
        return f"static func {name}({self.params}){' -> ' + self.returns if self.returns else ''}:"

    @property
    def void(self) -> bool:
        return self.returns == "void"


def find_funcs(lines: list[str]) -> dict[str, Func]:
    found = {}
    for index, line in enumerate(lines):
        match = FUNC_START.match(line)
        if match:
            if match.group(1) in found:
                sys.exit(f"two definitions of {match.group(1)}")
            found[match.group(1)] = Func(lines, index)
    return found


def call_line(func: Func, target: str) -> str:
    return f"{target}({', '.join(func.args)})"


def ported_wrapper(script: str, func: Func, writes: bool, mode: str, name: str | None = None) -> list[str]:
    """The entry wrapper, as `name` (default the function's own)."""
    raw = call_line(func, f"{func.name}__raw")
    key = f'&"{script}.{func.name}"'
    passthrough = [f"\t\t{raw}", "\t\treturn"] if func.void else [f"\t\treturn {raw}"]
    lines = [func.signature(name or func.name), "\tif G1.depth != 0:", f"\t\tG1.reentry({key})", *passthrough]
    if mode == "ported":
        lines += ["\tif not G1.on:", *passthrough, "\tG1.enter()", "\tvar g1_t0 := Time.get_ticks_usec()"]
        if func.void:
            lines += [f"\t{raw}", f"\tG1.add({key}, Time.get_ticks_usec() - g1_t0)"]
        else:
            lines += [f"\tvar g1_result = {raw}", f"\tG1.add({key}, Time.get_ticks_usec() - g1_t0)", "\treturn g1_result"]
    else:
        args = f"[{', '.join(func.args)}]"
        # The arena plays each side's BattleAiRules as its own compiled copy, with its own memos: the wrapper, inside
        # that copy, hands them over.
        memos = ", [_scoring_scope_depth, _scoring_living, _scoring_stack_terms]" if writes and script == "BattleAiRules" else ""
        lines += ["\tif not G1.on or not G1.capturing:", *passthrough,
                  f"\tvar g1_ids := G1.capture_args({args}, {'true' if writes else 'false'}{memos})"]
        after = args if writes else "[]"
        if func.void:
            lines += [f"\t{raw}", f"\tG1.capture_end({key}, g1_ids, null, {after})"]
        else:
            lines += [f"\tvar g1_result = {raw}", f"\tG1.capture_end({key}, g1_ids, g1_result, {after})", "\treturn g1_result"]
    return lines + [""]


def around_wrapper(func: Func, before: str, after: str, target: str | None = None) -> list[str]:
    raw = call_line(func, target or f"{func.name}__raw")
    if func.void:
        return [func.signature(func.name), f"\t{before}", f"\t{raw}", f"\t{after}", ""]
    return [func.signature(func.name), f"\t{before}", f"\tvar g1_result = {raw}", f"\t{after}", "\treturn g1_result", ""]


def host_wrapper(script: str, func: Func) -> list[str]:
    """A host target: paused, and in mode capture kept as a host call of the entry it runs in."""
    raw = call_line(func, f"{func.name}__raw")
    key = f'&"{script}.{func.name}"'
    args = f"[{', '.join(func.args)}]"
    lines = [func.signature(func.name), f"\tG1.pause({func.args[0]})", f"\tvar g1_host = G1.host_begin({args})"]
    if func.void:
        return lines + [f"\t{raw}", f"\tG1.host_end({key}, g1_host, null, {args})", "\tG1.resume()", ""]
    return lines + [f"\tvar g1_result = {raw}", f"\tG1.host_end({key}, g1_host, g1_result, {args})", "\tG1.resume()",
                    "\treturn g1_result", ""]


def rewrite_calls(lines: list[str], own: set[str], qualified: dict[str, set[str]]) -> int:
    """Points calls to ported functions at their raw bodies, outside strings and comments. Returns the count."""
    patterns = []
    if own:
        patterns.append(re.compile(r"(?<![\w.])(" + "|".join(sorted(own, key=len, reverse=True)) + r")\("))
    for alias, names in qualified.items():
        if names:
            patterns.append(re.compile(r"(?<![\w.])(" + alias + r"\.(?:" + "|".join(sorted(names, key=len, reverse=True)) + r"))\("))
    count = 0
    for index, line in enumerate(lines):
        pieces, last = [], 0
        for a, b in code_spans(line):
            segment = line[a:b]
            for pattern in patterns:
                segment, n = pattern.subn(r"\1__raw(", segment)
                count += n
            pieces.append(line[last:a])
            pieces.append(segment)
            last = b
        pieces.append(line[last:])
        lines[index] = "".join(pieces)
    return count


def aliases(lines: list[str], class_names: dict[str, str]) -> dict[str, str]:
    """Alias -> script stem for the script's preloads and the global class names."""
    found = dict(class_names)
    for line in lines:
        match = PRELOAD.match(line)
        if match:
            found[match.group(1)] = match.group(2)
    return found


def instrument(dest: Path, mode: str) -> list[str]:
    scripts_dir = dest / "scripts/core"
    ported = registry()
    hosts = host_targets()
    class_names = {}
    for path in scripts_dir.glob("*.gd"):
        for line in path.read_text(encoding="utf-8").split(NEWLINE)[:5]:
            match = CLASS_NAME.match(line)
            if match:
                class_names[match.group(1)] = path.stem
    sources = {stem: (scripts_dir / f"{stem}.gd").read_text(encoding="utf-8").split(NEWLINE)
               for stem in set(ported) | {RESOLVE[0]} | set(PAUSED) | set(hosts)}
    funcs = {stem: find_funcs(lines) for stem, lines in sources.items()}
    # Out of T_gd and of the entry they run in: the battle ends, the host targets and the result payload.
    paused = {stem: {name for name in funcs[stem] if (stem in PAUSED and PAUSED[stem].match(name)) or name in hosts.get(stem, set())}
              for stem in sources}
    # The ported set per script: registry entries (wrapped) and native internals (a raw copy beside the original).
    internals = {stem: native_internals(stem, set(funcs[stem]), set(ported.get(stem, {}))) for stem in sources}
    raw_names = {stem: set(ported.get(stem, {})) | internals[stem] for stem in sources}
    # The calls a ported body points at raw bodies: a paused function keeps its pause.
    rewritten = {stem: raw_names[stem] - paused[stem] for stem in sources}
    report = []
    for stem, lines in sources.items():
        missing = [name for name in raw_names[stem] | hosts.get(stem, set()) if name not in funcs[stem]]
        if missing:
            sys.exit(f"{stem}.gd at the baseline has no {missing}")
        if any(re.search(r"\bG1\b", line) for line in lines):
            sys.exit(f"{stem}.gd already names G1")
        edits: list[tuple[int, int, list[str]]] = []  # (start, end, replacement) over the original lines

        qualified = {alias: rewritten.get(target, set()) for alias, target in aliases(lines, class_names).items()}

        def raw_copy(func: Func, in_set: bool) -> list[str]:
            """The function renamed to __raw; inside the ported set its calls into the set skip the wrappers."""
            body = lines[func.body[0]:func.body[1]]
            signature = lines[func.start:func.end + 1]
            signature[0] = signature[0].replace(f"static func {func.name}(", f"static func {func.name}__raw(", 1)
            if in_set:
                counts[0] += rewrite_calls(body, rewritten[stem], qualified)
            return signature + body

        counts = [0]
        for name, func in funcs[stem].items():
            if stem == RESOLVE[0] and name == RESOLVE[1]:
                begin, end = f"G1.begin_resolve({func.args[0]})", f"G1.end_resolve({func.args[0]})"
                if mode != "resolve" and name in ported.get(stem, {}):
                    # Ported: the resolve is the outermost entry, its clock inside the resolve's.
                    inner = f"{name}__g1"
                    wrapper = around_wrapper(func, begin, end, inner) + ported_wrapper(stem, func, ported[stem][name], mode, inner)
                    kind = mode
                else:
                    wrapper, kind = around_wrapper(func, begin, end), "resolve"
            elif name in hosts.get(stem, set()):
                wrapper, kind = host_wrapper(stem, func), "host"
            elif name in paused[stem]:
                wrapper, kind = around_wrapper(func, f"G1.pause({func.args[0]})", "G1.resume()"), "paused"
            elif mode != "resolve" and name in ported.get(stem, {}):
                wrapper, kind = ported_wrapper(stem, func, ported[stem][name], mode), mode
            elif mode != "resolve" and name in internals[stem]:
                # Also called from GDScript outside the set: the original stays, the raw copy serves ported bodies.
                edits.append((func.start, func.start, raw_copy(func, True) + [""]))
                report.append(f"{stem}.{name}: native internal, raw copy")
                continue
            else:
                continue
            edits.append((func.start, func.body[1], wrapper + raw_copy(func, kind in ("ported", "capture"))))
            report.append(f"{stem}.{name}: {kind}")
        if counts[0]:
            report.append(f"{stem}: {counts[0]} calls inside the ported set point at raw bodies")
        edits.sort(key=lambda e: e[0])
        for before, after in zip(edits, edits[1:]):
            if before[1] > after[0] or before[0] == after[0]:
                sys.exit(f"{stem}.gd: overlapping edits at lines {before[0] + 1} and {after[0] + 1}")
        for start, end, replacement in reversed(edits):
            lines[start:end] = replacement
        extends = next(i for i, line in enumerate(lines) if line.startswith("extends "))
        lines[extends + 1:extends + 1] = [PROBE_CONST]
        (scripts_dir / f"{stem}.gd").write_text(NEWLINE.join(lines), encoding="utf-8", newline=NEWLINE)
    probe_dir = dest / "tools/battle_port_g1"
    probe_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(HERE / "g1_probe.gd", probe_dir / "g1_probe.gd")
    return report


# --- commands -----------------------------------------------------------------------------------------------------

def godot() -> str:
    sys.path.insert(0, str(ROOT / "tools"))
    from core_suite import find_godot  # noqa: E402
    return str(find_godot(None))


def godot_processes() -> list[str]:
    """The command lines of the running Godot processes."""
    if os.name == "nt":
        out = subprocess.run(["powershell", "-NoProfile", "-Command",
                              "Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\" | ForEach-Object { $_.CommandLine }"],
                             capture_output=True, text=True, errors="replace").stdout
    else:
        out = subprocess.run(["ps", "-eo", "args="], capture_output=True, text=True, errors="replace").stdout
        out = "\n".join(line for line in out.splitlines() if Path(line.split(" ", 1)[0]).name.lower().startswith("godot"))
    return [line.strip() for line in out.splitlines() if line.strip()]


class ForeignGodot:
    """Samples the Godot processes that are not this run's (no `own` path in their command line) while a timed run
    goes on: a timing taken beside one is not comparable."""

    def __init__(self, own: list[Path], every: float = 20.0):
        self.own = [str(path).lower() for path in own]
        self.every = every
        self.seen: set[str] = set()
        self.samples = 0
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._loop, daemon=True)

    def _sample(self) -> None:
        self.samples += 1
        for line in godot_processes():
            if not any(own in os.path.normpath(line).lower() for own in self.own):
                self.seen.add(line[:300])

    def _loop(self) -> None:
        while True:
            self._sample()
            if self._stop.wait(self.every):
                return

    def __enter__(self) -> "ForeignGodot":
        self._thread.start()
        return self

    def __exit__(self, *_exc) -> None:
        self._stop.set()
        self._thread.join()
        self._sample()

    def report(self) -> dict:
        return {"foreign_godot": sorted(self.seen), "foreign_godot_samples": self.samples}


def godot_env(profile: Path, extra: dict[str, str] | None = None) -> dict[str, str]:
    env = dict(os.environ)
    env.update({"APPDATA": str(profile), "XDG_DATA_HOME": str(profile), "XDG_CONFIG_HOME": str(profile), "XDG_CACHE_HOME": str(profile)})
    env.update(extra or {})
    return env


def check_compiles(dest: Path) -> None:
    """Loads the instrumented scripts in the copy once (parse errors would only show mid-run)."""
    with tempfile.TemporaryDirectory(prefix="g1-check-") as profile:
        script = dest / "tools/battle_port_g1/g1_check.gd"
        stems = sorted({path.stem for path in (dest / "scripts/core").glob("*.gd") if PROBE_CONST in path.read_text(encoding="utf-8")})
        script.write_text(NEWLINE.join([
            "extends SceneTree",
            "func _initialize() -> void:",
            "\tprocess_frame.connect(_run, CONNECT_ONE_SHOT)",
            "func _run() -> void:",
            "\tvar failed := 0",
            f"\tfor stem in {json.dumps(stems)}:",
            '\t\tvar script = load("res://scripts/core/%s.gd" % stem)',
            "\t\tif script == null or not script.can_instantiate():",
            "\t\t\tfailed += 1",
            '\t\t\tprinterr("G1 CHECK %s does not compile" % stem)',
            '\tprint("G1 CHECK %d failed" % failed)',
            "\tquit(1 if failed else 0)",
            "",
        ]), encoding="utf-8")
        proc = subprocess.run([godot(), "--headless", "--path", str(dest), "--audio-driver", "Dummy", "-s", str(script)],
                              env=godot_env(Path(profile)), capture_output=True, text=True, errors="replace", timeout=900)
        output = proc.stdout + proc.stderr
        if proc.returncode != 0 or "SCRIPT ERROR" in output or "Parse Error" in output:
            sys.exit(f"the instrumented copy does not compile:\n{output[-4000:]}")


def cmd_prepare(args) -> int:
    if args.mode not in MODES:
        sys.exit(f"mode must be one of {MODES}")
    rev = args.rev or subprocess.run(["git", "-C", str(ROOT), "merge-base", "HEAD", "origin/main"], capture_output=True, text=True, check=True).stdout.strip()
    subprocess.run([sys.executable, str(ROOT / "tools/rules_parity.py"), "prepare", rev, args.dest], check=True)
    dest = Path(args.dest).resolve()
    report = instrument(dest, args.mode)
    (dest / "g1_mode.txt").write_text(f"{args.mode}\n{rev}\n", encoding="utf-8")
    print(f"{dest}: mode {args.mode} at {rev[:9]}, {len(report)} functions wrapped")
    for line in report:
        print("  " + line)
    check_compiles(dest)
    print("instrumented scripts compile")
    return 0


def cmd_run(args) -> int:
    dest = Path(args.dest).resolve()
    mode = (dest / "g1_mode.txt").read_text(encoding="utf-8").split()[0]
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    env.update({"HEROES_G1_MODE": mode, "HEROES_G1_OUT": str(out / "g1"), "HEROES_G1_CAPTURE_EVERY": str(args.capture_every)})
    started = time.time()
    if args.corpus == "seeds":
        cmd = [sys.executable, str(dest / "tools/rules_parity.py"), "run", str(dest), "--jobs", str(args.jobs), "--out", str(out / "seeds")]
    else:
        cmd = [sys.executable, str(dest / "tools/battle_ai_arena/arena.py"), "--plain",
               "--suite", args.corpus, "--workers", str(args.jobs), "--out", str(out / "arena")]
    print(" ".join(cmd), flush=True)
    with ForeignGodot([dest]) as foreign:
        code = subprocess.run(cmd, env=env).returncode
    (out / "run.json").write_text(json.dumps({"mode": mode, "corpus": args.corpus, "jobs": args.jobs, "capture_every": args.capture_every,
                                              "code": code, "wall_seconds": round(time.time() - started, 1), "godot": Path(godot()).name,
                                              **foreign.report()}), encoding="utf-8")
    print(f"{args.corpus} {mode}: exit {code}, {time.time() - started:.0f} s")
    return code


def replay_binary(chosen: str | None) -> Path:
    if chosen:
        return Path(chosen).resolve()
    for candidate in (ROOT / ".artifacts/rules_native_build_windows_msvc/RelWithDebInfo/battle_port_replay.exe",
                      ROOT / ".artifacts/rules_native_build_windows_msvc/Release/battle_port_replay.exe",
                      ROOT / ".artifacts/rules_native_build_linux/battle_port_replay"):
        if candidate.is_file():
            return candidate
    sys.exit("build the battle_port_replay target first (src/gdextension/rules/CMakeLists.txt)")


def captures(dirs: list[str]) -> list[Path]:
    # Absolute: the conversion's Godot runs with --path ROOT as its working directory.
    found = sorted(path.resolve() for d in dirs for path in Path(d).rglob("cap_*.bin"))
    if not found:
        sys.exit(f"no captures under {dirs}")
    return found


def write_meta(out: str, meta: dict) -> None:
    """How a replay or conversion file was timed, beside it (`summarize` reports it)."""
    Path(out + ".meta.json").write_text(json.dumps(meta), encoding="utf-8")


def read_meta(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8")) if path.is_file() else {}


def start_digest(capture: Path) -> str:
    """cap_<digest>_<n>.bin: the digest of the battle the resolve started from."""
    return capture.stem.split("_")[1]


def primer(files: list[Path], index: int) -> Path | None:
    """The nearest capture before files[index] (wrapping) that starts from another battle. The arena plays every
    battle twice, so the capture just before can be the same resolve."""
    for step in range(1, len(files)):
        other = files[index - step]
        if start_digest(other) != start_digest(files[index]):
            return other
    return None


def cmd_replay(args) -> int:
    binary = replay_binary(args.binary)
    files = captures(args.capdir)

    def one(index: int) -> dict:
        path = files[index]
        command = [str(binary), "--repeat", str(args.repeat)]
        other = primer(files, index) if args.prime == "previous" else None
        if other is not None:
            command += ["--prime", str(other)]
        if args.fresh_writers:
            command.append("--fresh-writers")
        proc = subprocess.run(command + [str(path)], capture_output=True, text=True, errors="replace")
        if proc.returncode != 0:
            return {"file": str(path), "error": (proc.stdout + proc.stderr)[-2000:]}
        row = json.loads(proc.stdout.strip().splitlines()[-1])
        row["file"] = str(path)
        return row

    with ForeignGodot([]) as foreign, ThreadPoolExecutor(max_workers=args.jobs) as pool:
        rows = list(pool.map(one, range(len(files))))
    Path(args.out).write_text(NEWLINE.join(json.dumps(row) for row in rows) + NEWLINE, encoding="utf-8")
    write_meta(args.out, {"jobs": args.jobs, "repeat": args.repeat, "prime": args.prime, "fresh_writers": args.fresh_writers,
                          "binary": str(binary), **foreign.report()})
    bad = [row for row in rows if "error" in row or row.get("mismatches")]
    print(f"replayed {len(rows)} resolves, {len(bad)} with errors or mismatches")
    for row in bad[:10]:
        print("  " + json.dumps(row)[:400])
    return 1 if bad else 0


def cmd_convert(args) -> int:
    rows = [json.loads(line) for line in Path(args.replay).read_text(encoding="utf-8").splitlines() if line.strip()]
    jobs = [{"file": row["file"], "made_arrays": row["made_arrays"], "made_dicts": row["made_dicts"]} for row in rows if "error" not in row]
    # As many Godot processes at once as the timed runs had, so both sides of c run under the same load.
    shares = [jobs[index::args.jobs] for index in range(args.jobs) if jobs[index::args.jobs]]
    with tempfile.TemporaryDirectory(prefix="g1-convert-") as work, ForeignGodot([ROOT]) as foreign:
        procs = []
        for index, share in enumerate(shares):
            folder = Path(work) / str(index)
            folder.mkdir()
            (folder / "jobs.json").write_text(json.dumps(share), encoding="utf-8")
            cmd = [godot(), "--headless", "--path", str(ROOT), "--audio-driver", "Dummy", "-s", str(HERE / "g1_conversion.gd"),
                   "--", str(folder / "jobs.json"), str(folder / "out.jsonl"), str(args.rounds)]
            procs.append(subprocess.Popen(cmd, env=godot_env(folder / "profile"), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                          text=True, errors="replace"))
        failed = False
        for proc in procs:
            try:
                # A script error leaves a headless Godot running instead of quitting.
                output = proc.communicate(timeout=args.timeout)[0]
            except subprocess.TimeoutExpired:
                proc.kill()
                output = proc.communicate()[0] + f"\nno result after {args.timeout} s: stopped"
            if proc.returncode != 0 or "SCRIPT ERROR" in output:
                print(output[-4000:])
                failed = True
        if failed:
            return 1
        lines = [line for index in range(len(shares)) for line in (Path(work) / str(index) / "out.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
    Path(args.out).write_text(NEWLINE.join(lines) + NEWLINE, encoding="utf-8")
    write_meta(args.out, {"jobs": len(shares), "rounds": args.rounds, "godot": Path(godot()).name, **foreign.report()})
    print(f"conversion timed for {len(lines)} resolves in {len(shares)} processes: {args.out}")
    return 0


def read_lines(folder: Path) -> tuple[dict[str, list[dict]], float]:
    """Key -> resolve lines (a key can repeat across processes: the same start battle), and the timer overhead."""
    by_key: dict[str, list[dict]] = {}
    overheads = []
    for path in sorted(folder.rglob("g1_*.jsonl")):
        for line in path.read_text(encoding="utf-8").splitlines():
            row = json.loads(line)
            if "timer_overhead_us" in row:
                overheads.append(row["timer_overhead_us"])
            else:
                by_key.setdefault(row["key"], []).append(row)
    return by_key, statistics.median(overheads) if overheads else 0.0


def layer_map() -> dict[str, str]:
    return json.loads(LAYERS.read_text(encoding="utf-8")) if LAYERS.is_file() else {}


def cmd_summarize(args) -> int:
    resolve, _ = read_lines(Path(args.resolve))
    ported, overhead = read_lines(Path(args.ported))
    replay = {row.get("key", Path(row["file"]).stem[4:]): row for row in (json.loads(line) for line in Path(args.replay).read_text(encoding="utf-8").splitlines() if line.strip())}
    convert = {row["key"]: row for row in (json.loads(line) for line in Path(args.convert).read_text(encoding="utf-8").splitlines() if line.strip())}
    layers = layer_map()
    problems = []

    def mean(rows: list[dict], field: str) -> float:
        return sum(row[field] for row in rows) / len(rows)

    # Every resolve: T_gd and the ported share.
    common = sorted(set(resolve) & set(ported))
    if set(resolve) != set(ported):
        problems.append(f"resolve/ported keys differ: {len(set(resolve) - set(ported))} only in resolve, {len(set(ported) - set(resolve))} only in ported")
    t_gd = sum(mean(resolve[k], "t_gd") for k in common)
    t_ported = sum(mean(ported[k], "t_ported") - overhead * mean(ported[k], "entries") for k in common)
    entries = sum(mean(ported[k], "entries") for k in common)
    reentries = sum(mean(ported[k], "reentries") for k in common)

    # Captured resolves: r and c. A key seen twice (the same start in two processes) is left out of the sample.
    sample = sorted(k for k in replay if len(ported.get(k, [])) == 1 and len(resolve.get(k, [])) == 1 and "error" not in replay[k])
    if len(sample) != len(replay):
        problems.append(f"{len(replay) - len(sample)} replayed resolves left out (failed, or their key is not unique)")
    per_fn: dict[str, dict[str, float]] = {}
    gd_sample = nat_sample = warm_sample = conv_sample = gd_resolve_sample = 0.0
    first_sample = warm_first_sample = 0.0
    for key in sample:
        row = replay[key]
        if row.get("mismatches"):
            problems.append(f"{key}: {row['mismatches']} replay mismatches")
        if row["entries"] != round(mean(ported[key], "entries")):
            problems.append(f"{key}: {row['entries']} captured entries, {mean(ported[key], 'entries'):.0f} timed")
        gd_resolve_sample += mean(resolve[key], "t_gd")
        nat_sample += row["t_nat_us"]
        warm_sample += row.get("t_nat_warm_us", 0.0)
        first_sample += row.get("t_nat_first_us", 0.0)
        warm_first_sample += row.get("t_nat_warm_first_us", 0.0)
        for name, (calls, usec) in ported[key][0]["per_fn"].items():
            slot = per_fn.setdefault(name, {"calls": 0, "gd": 0.0, "nat": 0.0})
            slot["calls"] += calls
            slot["gd"] += usec - overhead * calls
        for name, usec in row["per_fn_us"].items():
            per_fn.setdefault(name, {"calls": 0, "gd": 0.0, "nat": 0.0})["nat"] += usec
        gd_sample += sum(usec - overhead * calls for calls, usec in ported[key][0]["per_fn"].values())
        if key in convert:
            conv_sample += convert[key]["t_load_us"] + convert[key]["t_store_us"]
        else:
            problems.append(f"{key}: no conversion timing")
    r = gd_sample / nat_sample if nat_sample else float("nan")
    r_warm = gd_sample / warm_sample if warm_sample else float("nan")
    r_first = gd_sample / first_sample if first_sample else float("nan")
    r_warm_first = gd_sample / warm_first_sample if warm_first_sample else float("nan")
    c = conv_sample / gd_resolve_sample if gd_resolve_sample else float("nan")
    def project(ratio: float) -> float:
        return 1.0 / (c + 1.0 / ratio) if ratio == ratio and c == c and ratio > 0 else float("nan")
    by_layer: dict[str, dict[str, float]] = {}
    for name, slot in per_fn.items():
        layer = by_layer.setdefault(str(layers.get(name, "?")), {"gd": 0.0, "nat": 0.0})
        layer["gd"] += slot["gd"]
        layer["nat"] += slot["nat"]
    summary = {
        "resolves": len(common),
        "t_gd_s": round(t_gd / 1e6, 3),
        "t_gd_ported_s": round(t_ported / 1e6, 3),
        "ported_share": round(t_ported / t_gd, 4) if t_gd else None,
        "entries": round(entries),
        "reentries": round(reentries),
        "timer_overhead_us": round(overhead, 4),
        "captured": len(sample),
        "captured_t_gd_s": round(gd_resolve_sample / 1e6, 3),
        "captured_t_gd_ported_s": round(gd_sample / 1e6, 3),
        "captured_t_nat_s": round(nat_sample / 1e6, 4),
        "captured_t_nat_warm_s": round(warm_sample / 1e6, 4),
        "captured_t_nat_first_s": round(first_sample / 1e6, 4),
        "captured_t_nat_warm_first_s": round(warm_first_sample / 1e6, 4),
        "captured_t_conv_s": round(conv_sample / 1e6, 4),
        "r": round(r, 2),
        "r_warm": round(r_warm, 2),
        "r_first": round(r_first, 2),
        "r_warm_first": round(r_warm_first, 2),
        "c": round(c, 4),
        "S": round(project(r), 2),
        "S_first": round(project(r_first), 2),
        "r_needed_for_10x": round(1.0 / (0.1 - c), 2) if c < 0.1 else None,
        "r_below_which_5x_fails": round(1.0 / (0.2 - c), 2) if c < 0.2 else None,
        # The split by layer and function: the replay's warm pass, each call under its own clock.
        "layers_warm": {layer: {"r": round(v["gd"] / v["nat"], 2) if v["nat"] else None, "gd_s": round(v["gd"] / 1e6, 3), "nat_s": round(v["nat"] / 1e6, 4)} for layer, v in sorted(by_layer.items())},
        "functions_warm": {name: {"calls": int(v["calls"]), "gd_us": round(v["gd"]), "nat_us": round(v["nat"]), "r": round(v["gd"] / v["nat"], 2) if v["nat"] else None}
                      for name, v in sorted(per_fn.items(), key=lambda item: -item[1]["gd"])},
        "problems": problems,
    }
    conditions = {"resolve": read_meta(Path(args.resolve) / "run.json"), "ported": read_meta(Path(args.ported) / "run.json"),
                  "replay": read_meta(Path(args.replay + ".meta.json")), "convert": read_meta(Path(args.convert + ".meta.json"))}
    jobs = {part: meta.get("jobs") for part, meta in conditions.items()}
    if len(set(jobs.values())) != 1:
        problems.append(f"the timed parts ran with different job counts: {jobs}")
    for part, meta in conditions.items():
        if meta.get("foreign_godot"):
            problems.append(f"{part}: foreign Godot processes during the run: {meta['foreign_godot']}")
    if args.native:
        native, _ = read_lines(Path(args.native))
        both = sorted(set(resolve) & set(native))
        if set(native) != set(resolve):
            problems.append(f"resolve/native keys differ: {len(set(resolve) - set(native))} only in resolve, {len(set(native) - set(resolve))} only in native")
        gd_both = sum(mean(resolve[k], "t_gd") for k in both)
        nat_both = sum(mean(native[k], "t_gd") for k in both)
        summary["native_mode"] = {"resolves": len(both), "t_gd_s": round(gd_both / 1e6, 3), "t_native_s": round(nat_both / 1e6, 3),
                                  "speedup": round(gd_both / nat_both, 2) if nat_both else None}
        conditions["native"] = read_meta(Path(args.native) / "run.json")
        if conditions["native"].get("jobs") != jobs["resolve"]:
            problems.append(f"the native run had {conditions['native'].get('jobs')} jobs, the resolve run {jobs['resolve']}")
        if conditions["native"].get("foreign_godot"):
            problems.append(f"native: foreign Godot processes during the run: {conditions['native']['foreign_godot']}")
    summary["conditions"] = conditions
    text = json.dumps(summary, indent=1)
    if args.out:
        Path(args.out).write_text(text + NEWLINE, encoding="utf-8")
    print(text)
    return 1 if problems else 0


def cmd_remove(args) -> int:
    return subprocess.run([sys.executable, str(ROOT / "tools/rules_parity.py"), "remove", args.dest]).returncode


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("prepare", help="an instrumented copy of the branch point")
    p.add_argument("mode", choices=MODES)
    p.add_argument("dest")
    p.add_argument("--rev", help="baseline revision (default: git merge-base HEAD origin/main)")
    p.set_defaults(func=cmd_prepare)
    p = sub.add_parser("run", help="play a corpus in a prepared copy")
    p.add_argument("dest")
    p.add_argument("--corpus", choices=CORPORA, required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--jobs", type=int, default=6)
    p.add_argument("--capture-every", type=int, default=1, help="capture the resolves whose start digest is a multiple of N")
    p.set_defaults(func=cmd_run)
    p = sub.add_parser("replay", help="replay captures in the native-only binary")
    p.add_argument("capdir", nargs="+")
    p.add_argument("--out", required=True)
    p.add_argument("--jobs", type=int, default=6)
    p.add_argument("--repeat", type=int, default=3)
    p.add_argument("--prime", choices=["previous", "none"], default="previous",
                   help="the State the first round finds: as the previous capture left it, or new")
    p.add_argument("--binary", help="the replay binary (default: the build tree's battle_port_replay)")
    p.add_argument("--fresh-writers", action="store_true",
                   help="every writing entry decodes its own arguments, also one that left them as it found them")
    p.set_defaults(func=cmd_replay)
    p = sub.add_parser("convert", help="time the whole-battle conversion of the captured resolves")
    p.add_argument("capdir", nargs="*")
    p.add_argument("--replay", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--jobs", type=int, default=6, help="Godot processes at once: as many as the timed runs had")
    p.add_argument("--rounds", type=int, default=5)
    p.add_argument("--timeout", type=int, default=1800, help="seconds per Godot process")
    p.set_defaults(func=cmd_convert)
    p = sub.add_parser("summarize", help="r, c and S")
    p.add_argument("--resolve", required=True)
    p.add_argument("--ported", required=True)
    p.add_argument("--replay", required=True)
    p.add_argument("--convert", required=True)
    p.add_argument("--native", help="a resolve run of the branch in native battle mode: the measured time per resolve")
    p.add_argument("--out")
    p.set_defaults(func=cmd_summarize)
    p = sub.add_parser("remove", help="delete a prepared copy")
    p.add_argument("dest")
    p.set_defaults(func=cmd_remove)
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
