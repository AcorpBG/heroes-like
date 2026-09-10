"""Bound disposable Wine prefixes while retaining their user data and evidence."""
from __future__ import annotations

from contextlib import contextmanager
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile


def cleanup_prefix(prefix: Path, artifact_dir: Path, wineserver: str, timeout: int = 30) -> dict:
    """Stop this prefix's server, preserve users, then remove its system files.

    Never follow a prefix/user-directory symlink or remove a prefix whose Wine
    server did not shut down. User data is renamed on the same filesystem, so
    saves and logs survive without copying Wine's large Windows installation.
    """
    result = {"prefix": str(prefix), "ok": False, "removed": False}
    try:
        if prefix.parent.resolve() != artifact_dir.resolve() or prefix.is_symlink():
            raise ValueError(f"Refusing a prefix outside the artifact directory: {prefix}")
        if not prefix.exists():
            result["ok"] = True
            return result
        if not prefix.is_dir() or prefix.is_mount():
            raise ValueError(f"Refusing a non-directory or mounted prefix: {prefix}")
        for child in (prefix / "drive_c", prefix / "drive_c/users"):
            if child.is_symlink():
                raise ValueError(f"Refusing linked Wine user data: {child}")
        if not wineserver:
            raise RuntimeError("wineserver is unavailable; retaining the prefix")
        env = {**os.environ, "WINEPREFIX": str(prefix), "WINEDEBUG": "-all"}
        result["server_shutdown"] = []
        for option in ("-k", "-w"):
            stopped = subprocess.run(
                [wineserver, option], env=env, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, text=True, errors="replace",
                timeout=timeout, check=False,
            )
            result["server_shutdown"].append({"option": option, "returncode": stopped.returncode})
            # Wine returns 1 without output when -k finds no running server.
            # Still require -w to succeed before touching any prefix files.
            already_stopped = option == "-k" and stopped.returncode == 1 and not stopped.stdout.strip()
            if stopped.returncode != 0 and not already_stopped:
                raise RuntimeError(f"wineserver {option} failed: {stopped.stdout[-2000:]}")
        users = prefix / "drive_c/users"
        if users.exists():
            saved_dir = Path(tempfile.mkdtemp(prefix=prefix.name + "-user-data-", dir=artifact_dir))
            saved_users = saved_dir / "users"
            users.rename(saved_users)
            result["preserved_user_data"] = {"original": str(users), "path": str(saved_users)}
        shutil.rmtree(prefix)
        result.update(ok=True, removed=True)
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
        result["error"] = str(exc)
    return result


def _terminate(signum: int, _frame: object) -> None:
    # SystemExit unwinds the context manager just like Ctrl-C/KeyboardInterrupt.
    raise SystemExit(128 + signum)


@contextmanager
def managed_prefixes(prefixes: tuple[Path, ...], artifact_dir: Path, wineserver: str, timeout: int = 30):
    """Clean up on success, failure, timeout, Ctrl-C, and SIGTERM.

    SIGKILL and host loss cannot run finally blocks; the next invocation cleans
    any leftovers in its output directory before creating fresh environments.
    """
    artifact_dir.mkdir(parents=True, exist_ok=True)
    receipt = {"ok": False, "before_run": [], "after_run": []}
    previous_handler = signal.signal(signal.SIGTERM, _terminate)
    try:
        for prefix in prefixes:
            row = cleanup_prefix(prefix, artifact_dir, wineserver, timeout)
            receipt["before_run"].append(row)
            if not row["ok"]:
                raise RuntimeError(f"Cannot reset Wine prefix: {row['error']}")
        yield receipt
    finally:
        # Finish shutdown even if another termination signal arrives mid-cleanup.
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        try:
            receipt["after_run"] = [cleanup_prefix(p, artifact_dir, wineserver, timeout) for p in prefixes]
            receipt["ok"] = all(row["ok"] for row in receipt["before_run"] + receipt["after_run"])
            (artifact_dir / "wine-prefix-cleanup.json").write_text(
                json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8",
            )
            if not receipt["ok"]:
                print("Wine cleanup incomplete; see wine-prefix-cleanup.json", file=sys.stderr)
        finally:
            signal.signal(signal.SIGTERM, previous_handler)
