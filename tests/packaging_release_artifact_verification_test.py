#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import stat
import subprocess
import sys
import tempfile
import unittest
import warnings
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PACKAGER = ROOT / "tools" / "package_release.py"
VERSION = "9.9.9-test"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class ReleaseArtifactVerificationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="heroes-like-package-test-")
        self.output = Path(self.temp.name) / "release"
        self._write_exports()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _write_exports(self) -> None:
        linux = self.output / "exports" / "linux-x86_64"
        windows = self.output / "exports" / "windows-x86_64"
        linux.mkdir(parents=True)
        windows.mkdir(parents=True)

        elf = bytearray(b"\x7fELF" + (b"L" * 256))
        elf[4] = 2
        elf[5] = 1
        elf[18:20] = (0x3E).to_bytes(2, "little")
        linux_binary = linux / "heroes-like.x86_64"
        linux_binary.write_bytes(elf)
        linux_binary.chmod(0o755)
        (linux / "heroes-like.pck").write_bytes(b"GDPC" + (b"P" * 128))
        (linux / "libaurelion_map_persistence.linux.template_release.x86_64.so").write_bytes(elf)

        pe = bytearray(b"MZ" + (b"W" * 254))
        pe[0x3C:0x40] = (0x80).to_bytes(4, "little")
        pe[0x80:0x84] = b"PE\x00\x00"
        pe[0x84:0x86] = (0x8664).to_bytes(2, "little")
        (windows / "heroes-like.exe").write_bytes(pe)
        (windows / "heroes-like.pck").write_bytes(b"GDPC" + (b"P" * 128))
        (windows / "aurelion_map_persistence.windows.template_release.x86_64.dll").write_bytes(pe)

    def _run(self, *args: str, expect_ok: bool = True) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            [sys.executable, str(PACKAGER), "--output-dir", str(self.output), *args],
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode == 0, expect_ok, msg=result.stdout + result.stderr)
        return result

    def _package(self) -> None:
        result = self._run("--version", VERSION, "--skip-export")
        self.assertTrue(json.loads(result.stdout)["verification"]["ok"])

    def _rewrite_checksums(self) -> None:
        archives = self.output / "archives"
        index_path = archives / "release-index.json"
        index = json.loads(index_path.read_text(encoding="utf-8"))
        for row in index["archives"]:
            archive = archives / row["path"]
            row["size_bytes"] = archive.stat().st_size
            row["sha256"] = sha256(archive)
        index_path.write_text(json.dumps(index, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (archives / "SHA256SUMS").write_text(
            "".join(f"{row['sha256']}  {row['path']}\n" for row in index["archives"]),
            encoding="ascii",
        )

    def test_generated_archives_verify_and_tampering_is_rejected(self) -> None:
        self._package()
        verified = json.loads(self._run("--verify-only").stdout)
        self.assertTrue(verified["ok"])
        self.assertEqual([row["platform"] for row in verified["platforms"]], ["linux-x86_64", "windows-x86_64"])

        linux_archive = self.output / "archives" / f"heroes-like-{VERSION}-linux-x86_64.tar.gz"
        with linux_archive.open("ab") as handle:
            handle.write(b"tampered")
        failure = self._run("--verify-only", expect_ok=False)
        self.assertIn("archive size mismatch", failure.stderr)

    def test_path_traversal_is_rejected_even_with_updated_outer_hashes(self) -> None:
        self._package()
        windows_archive = self.output / "archives" / f"heroes-like-{VERSION}-windows-x86_64.zip"
        with zipfile.ZipFile(windows_archive, "a") as archive:
            info = zipfile.ZipInfo("../escape.txt")
            info.create_system = 3
            info.external_attr = 0o644 << 16
            archive.writestr(info, b"unsafe")
        self._rewrite_checksums()
        failure = self._run("--verify-only", expect_ok=False)
        self.assertIn("unsafe archive member path", failure.stderr)

    def test_link_member_is_rejected_even_with_updated_outer_hashes(self) -> None:
        self._package()
        windows_archive = self.output / "archives" / f"heroes-like-{VERSION}-windows-x86_64.zip"
        bundle = f"heroes-like-{VERSION}-windows-x86_64"
        with zipfile.ZipFile(windows_archive, "a") as archive:
            info = zipfile.ZipInfo(f"{bundle}/unsafe-link")
            info.create_system = 3
            info.external_attr = (stat.S_IFLNK | 0o777) << 16
            archive.writestr(info, b"README.txt")
        self._rewrite_checksums()
        failure = self._run("--verify-only", expect_ok=False)
        self.assertIn("non-regular payload", failure.stderr)

    def test_duplicate_member_is_rejected_even_with_updated_outer_hashes(self) -> None:
        self._package()
        windows_archive = self.output / "archives" / f"heroes-like-{VERSION}-windows-x86_64.zip"
        bundle = f"heroes-like-{VERSION}-windows-x86_64"
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(windows_archive, "a") as archive:
                info = zipfile.ZipInfo(f"{bundle}/README.txt")
                info.create_system = 3
                info.external_attr = 0o644 << 16
                archive.writestr(info, b"duplicate")
        self._rewrite_checksums()
        failure = self._run("--verify-only", expect_ok=False)
        self.assertIn("duplicate archive member", failure.stderr)

    def test_stale_release_output_is_rejected_and_next_package_cleans_it(self) -> None:
        self._package()
        stale = self.output / "archives" / "heroes-like-old-version.zip"
        stale.write_bytes(b"stale")
        failure = self._run("--verify-only", expect_ok=False)
        self.assertIn("unexpected entries", failure.stderr)

        self._package()
        self.assertFalse(stale.exists())
        self.assertTrue(json.loads(self._run("--verify-only").stdout)["ok"])


if __name__ == "__main__":
    unittest.main()
