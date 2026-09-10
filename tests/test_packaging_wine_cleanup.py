from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from wine_prefix_cleanup import cleanup_prefix, managed_prefixes


class WineCleanupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.artifacts = Path(self.temp.name) / "artifacts"
        self.artifacts.mkdir()
        self.prefixes = tuple(self.artifacts / p for p in ("wine-prefix", "generated-wine-prefix"))

    def populate(self, prefix):
        system = prefix / "drive_c/windows/system32"
        system.mkdir(parents=True)
        (system / "kernel32.dll").write_bytes(b"disposable Wine system")
        users = prefix / "drive_c/users"
        saves = users / "root/AppData/Roaming/Godot/app_userdata/heroes-like/saves"
        saves.mkdir(parents=True)
        (saves / "earned.json").write_bytes(b'{"earned": true}\n')
        (prefix / "system.reg").write_text("Wine registry")
        return users, saves.relative_to(users) / "earned.json"

    def stopped(self, *args, **kwargs):
        return subprocess.CompletedProcess(args[0], 0, stdout="")

    def test_success_preserves_user_data_and_unrelated_evidence(self):
        evidence = self.artifacts / "report.json"
        evidence.write_bytes(b"retained report")
        external = Path(self.temp.name) / "external"
        external.mkdir()
        (external / "document").write_bytes(b"retained external file")
        with patch("wine_prefix_cleanup.subprocess.run", side_effect=self.stopped) as run:
            with managed_prefixes(self.prefixes, self.artifacts, "wineserver") as receipt:
                for prefix in self.prefixes:
                    users, save = self.populate(prefix)
                    (users / "root/Documents").symlink_to(external, target_is_directory=True)
        self.assertTrue(receipt["ok"])
        self.assertEqual([c.args[0][1] for c in run.call_args_list], ["-k", "-w", "-k", "-w"])
        for row, prefix in zip(receipt["after_run"], self.prefixes):
            self.assertFalse(prefix.exists())
            saved = Path(row["preserved_user_data"]["path"])
            self.assertEqual((saved / save).read_bytes(), b'{"earned": true}\n')
            self.assertTrue((saved / "root/Documents").is_symlink())
        self.assertEqual(evidence.read_bytes(), b"retained report")
        self.assertEqual((external / "document").read_bytes(), b"retained external file")
        self.assertTrue(json.loads((self.artifacts / "wine-prefix-cleanup.json").read_text())["ok"])

    def test_exception_timeout_and_keyboard_interrupt_remove_partial_prefixes(self):
        for exception in (RuntimeError("game failed"), subprocess.TimeoutExpired("wine", 1), KeyboardInterrupt()):
            with self.subTest(exception=type(exception).__name__):
                previous = signal.getsignal(signal.SIGTERM)
                with patch("wine_prefix_cleanup.subprocess.run", side_effect=self.stopped):
                    with self.assertRaises(type(exception)):
                        with managed_prefixes(self.prefixes, self.artifacts, "wineserver"):
                            for prefix in self.prefixes:
                                self.populate(prefix)
                            raise exception
                self.assertTrue(all(not p.exists() for p in self.prefixes))
                self.assertEqual(signal.getsignal(signal.SIGTERM), previous)

    def test_leftovers_from_previous_run_keep_their_saves(self):
        _, save = self.populate(self.prefixes[0])
        with patch("wine_prefix_cleanup.subprocess.run", side_effect=self.stopped):
            with managed_prefixes(self.prefixes, self.artifacts, "wineserver") as receipt:
                self.assertFalse(self.prefixes[0].exists())
                self.populate(self.prefixes[0])
        old = Path(receipt["before_run"][0]["preserved_user_data"]["path"])
        new = Path(receipt["after_run"][0]["preserved_user_data"]["path"])
        self.assertNotEqual(old, new)
        self.assertEqual((old / save).read_bytes(), (new / save).read_bytes())

    def test_shutdown_failure_or_timeout_keeps_prefix(self):
        for outcome in (subprocess.CompletedProcess([], 1, stdout="busy"), subprocess.TimeoutExpired("wineserver", 1)):
            with self.subTest(outcome=type(outcome).__name__):
                prefix = self.prefixes[0]
                if not prefix.exists():
                    self.populate(prefix)
                with patch("wine_prefix_cleanup.subprocess.run", side_effect=[self.stopped([]), outcome]):
                    result = cleanup_prefix(prefix, self.artifacts, "wineserver")
                self.assertFalse(result["ok"])
                self.assertTrue((prefix / "drive_c/windows/system32/kernel32.dll").is_file())
                self.assertTrue((prefix / "drive_c/users").is_dir())

    def test_missing_wineserver_keeps_prefix(self):
        self.populate(self.prefixes[0])
        self.assertFalse(cleanup_prefix(self.prefixes[0], self.artifacts, "")["ok"])
        self.assertTrue(self.prefixes[0].is_dir())

    def test_already_stopped_server_still_waits_before_removal(self):
        self.populate(self.prefixes[0])
        outcomes = [subprocess.CompletedProcess([], 1, stdout=""), self.stopped([])]
        with patch("wine_prefix_cleanup.subprocess.run", side_effect=outcomes) as run:
            result = cleanup_prefix(self.prefixes[0], self.artifacts, "wineserver")
        self.assertTrue(result["ok"])
        self.assertFalse(self.prefixes[0].exists())
        self.assertEqual([c.args[0][1] for c in run.call_args_list], ["-k", "-w"])

    def test_symlinks_and_outside_prefix_are_rejected(self):
        external = Path(self.temp.name) / "external"
        self.populate(external)
        prefix = self.prefixes[0]
        prefix.symlink_to(external, target_is_directory=True)
        self.assertFalse(cleanup_prefix(prefix, self.artifacts, "wineserver")["ok"])
        self.assertFalse(cleanup_prefix(external, self.artifacts, "wineserver")["ok"])
        prefix.unlink()
        prefix.mkdir()
        (prefix / "drive_c").symlink_to(external / "drive_c", target_is_directory=True)
        self.assertFalse(cleanup_prefix(prefix, self.artifacts, "wineserver")["ok"])
        self.assertTrue((external / "drive_c/windows/system32/kernel32.dll").is_file())

    @unittest.skipUnless(os.name == "posix", "POSIX process signals")
    def test_real_sigterm_unwinds_and_cleans_prefixes(self):
        server = Path(self.temp.name) / "wineserver"
        server.write_text("#!/bin/sh\nexit 0\n")
        server.chmod(0o755)
        script = """
import sys,time
from pathlib import Path
from wine_prefix_cleanup import managed_prefixes
root=Path(sys.argv[1])
prefixes=(root/'wine-prefix',root/'generated-wine-prefix')
with managed_prefixes(prefixes,root,sys.argv[2]):
    for p in prefixes:
        (p/'drive_c/windows').mkdir(parents=True)
    print('ready',flush=True)
    time.sleep(30)
"""
        env = {**os.environ, "PYTHONPATH": str(ROOT / "tools"), "PYTHONDONTWRITEBYTECODE": "1"}
        process = subprocess.Popen([sys.executable, "-c", script, str(self.artifacts), str(server)],
                                   env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            self.assertEqual(process.stdout.readline().strip(), "ready")
            process.send_signal(signal.SIGTERM)
            _, stderr = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 128 + signal.SIGTERM, stderr)
            self.assertTrue(all(not p.exists() for p in self.prefixes))
            self.assertTrue(json.loads((self.artifacts / "wine-prefix-cleanup.json").read_text())["ok"])
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()

    def test_packaging_main_reports_cleanup_failure(self):
        spec = importlib.util.spec_from_file_location("windows_smoke_cleanup_test", ROOT / "tests/packaging_windows_export_smoke.py")
        smoke = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(smoke)
        def run_smoke():
            self.populate(self.prefixes[0])
            return {"ok": True}, {"ok": True}
        with patch.multiple(smoke, ARTIFACT_DIR=self.artifacts, WINE_PREFIX=self.prefixes[0],
                            GENERATED_WINE_PREFIX=self.prefixes[1], REPORT_PATH=self.artifacts / "report.json",
                            WINESERVER_BINARY="wineserver", run_smoke=run_smoke):
            with patch("wine_prefix_cleanup.subprocess.run", return_value=subprocess.CompletedProcess([], 1, stdout="busy")):
                self.assertEqual(smoke.main(), 1)
        report = json.loads((self.artifacts / "report.json").read_text())
        self.assertFalse(report["ok"])
        self.assertFalse(report["wine_prefix_cleanup"]["ok"])


if __name__ == "__main__":
    unittest.main()
