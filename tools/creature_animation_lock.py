"""Serialize shared GPU, catalog and Git operations across creature workers.

Run a complete bounded operation while holding its lock:
python tools/creature_animation_lock.py gpu -- python path/to/run_generation.py sample move_h3_v1

Python publication scripts can use ``with exclusive('content'): ...``. Never
hold content or Git while waiting for GPU, and do not nest these locks.
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import threading

ROOT = Path(__file__).resolve().parents[1]
SCOPES = ('gpu', 'content', 'git')


@contextlib.contextmanager
def waiting_heartbeat(scope):
    """Report a blocked wait without cancelling/restarting the kernel wait."""
    stopped = threading.Event()
    def report():
        while not stopped.wait(45):
            print(f'Waiting for shared {scope}; pid={os.getpid()}', flush=True)
    reporter = threading.Thread(target=report, daemon=True)
    reporter.start()
    try:
        yield
    finally:
        stopped.set()
        reporter.join()


@contextlib.contextmanager
def exclusive(scope: str):
    if scope not in SCOPES:
        raise ValueError(f'Unknown lock scope: {scope}')
    identity = hashlib.sha256(str(ROOT.resolve()).casefold().encode()).hexdigest()[:16]
    if os.name == 'nt':
        import ctypes
        from ctypes import wintypes
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.CreateMutexW.argtypes = [ctypes.c_void_p, wintypes.BOOL, wintypes.LPCWSTR]
        kernel.CreateMutexW.restype = wintypes.HANDLE
        kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
        kernel.WaitForSingleObject.restype = wintypes.DWORD
        kernel.ReleaseMutex.argtypes = [wintypes.HANDLE]
        kernel.ReleaseMutex.restype = wintypes.BOOL
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        kernel.CloseHandle.restype = wintypes.BOOL
        handle = kernel.CreateMutexW(None, False, f'Local\\HeroesCreatureAnimation_{identity}_{scope}')
        if not handle:
            raise ctypes.WinError(ctypes.get_last_error())
        acquired = False
        try:
            # Timed waits rejoin the kernel wait queue after every timeout;
            # this allowed repeatedly renewed leases to beat older workers.
            # Keep one continuous wait. Windows still does not promise FIFO.
            with waiting_heartbeat(scope):
                result = kernel.WaitForSingleObject(handle, 0xFFFFFFFF)
            if result not in (0, 0x80):
                raise ctypes.WinError(ctypes.get_last_error())
            acquired = True
            if result == 0x80:
                print(f'Previous {scope} owner exited; recheck queue/index before mutation.', flush=True)
            print(f'Acquired shared {scope}; pid={os.getpid()}', flush=True)
            yield
        finally:
            if acquired:
                kernel.ReleaseMutex(handle)
            kernel.CloseHandle(handle)
    else:
        import fcntl
        directory = ROOT / '.artifacts' / 'creature_animation_locks'
        directory.mkdir(parents=True, exist_ok=True)
        with (directory / f'{identity}_{scope}.lock').open('a+b') as stream:
            with waiting_heartbeat(scope):
                fcntl.flock(stream, fcntl.LOCK_EX)
            try:
                print(f'Acquired shared {scope}; pid={os.getpid()}', flush=True)
                yield
            finally:
                fcntl.flock(stream, fcntl.LOCK_UN)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('scope', choices=SCOPES)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('Provide a child command after --')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    with exclusive(args.scope):
        return subprocess.call(command, stdout=sys.stdout, stderr=sys.stderr, creationflags=flags)


if __name__ == '__main__':
    sys.exit(main())
