#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import os
import stat
import subprocess
import sys
import tarfile
import tempfile
import unittest
import warnings
import zipfile
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools import package_release as package_release_module


PACKAGER = ROOT / "tools" / "package_release.py"
VERSION = "9.9.9-test"
SOURCE_REVISION = "a" * 40


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
        env = os.environ.copy()
        env["SOURCE_DATE_EPOCH"] = "315532800"
        result = subprocess.run(
            [
                sys.executable,
                str(PACKAGER),
                "--output-dir",
                str(self.output),
                "--source-revision",
                SOURCE_REVISION,
                *args,
            ],
            cwd=ROOT,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode == 0, expect_ok, msg=result.stdout + result.stderr)
        return result

    def _package(self) -> None:
        result = self._run("--version", VERSION, "--skip-export")
        verification = json.loads(result.stdout)["verification"]
        self.assertTrue(verification["ok"])
        self.assertEqual(
            [row["platform"] for row in verification["installers"]],
            ["linux-x86_64", "windows-x86_64"],
        )
        self.assertEqual(verification["source_revision"], SOURCE_REVISION)

    def _rewrite_checksums(self) -> None:
        archives = self.output / "archives"
        index_path = archives / "release-index.json"
        index = json.loads(index_path.read_text(encoding="utf-8"))
        archive_rows = {str(row["platform"]): row for row in index["archives"]}
        for row in archive_rows.values():
            archive = archives / row["path"]
            row["size_bytes"] = archive.stat().st_size
            row["sha256"] = sha256(archive)
        for row in index["installers"]:
            installer = archives / row["path"]
            row["size_bytes"] = installer.stat().st_size
            row["sha256"] = sha256(installer)
            source = archive_rows[str(row["platform"])]
            row["source_archive_path"] = source["path"]
            row["source_archive_sha256"] = source["sha256"]
        index_path.write_text(json.dumps(index, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (archives / "SHA256SUMS").write_text(
            "".join(
                f"{row['sha256']}  {row['path']}\n"
                for row in sorted([*index["archives"], *index["installers"]], key=lambda value: value["path"])
            ),
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

    def test_build_info_is_deterministic_and_bound_to_each_platform(self) -> None:
        self._package()
        archives = self.output / "archives"
        index = json.loads((archives / "release-index.json").read_text(encoding="utf-8"))
        self.assertEqual(index["schema_id"], "heroes_like_release_index_v3")
        self.assertEqual(index["source_revision"], SOURCE_REVISION)
        expected_common = {
            "schema_id": "heroes_like_build_info_v1",
            "product_id": "heroes-like",
            "version": VERSION,
            "source_revision": SOURCE_REVISION,
            "source_date_epoch": 315532800,
        }

        linux_archive = archives / f"heroes-like-{VERSION}-linux-x86_64.tar.gz"
        with tarfile.open(linux_archive, "r:gz") as archive:
            member = archive.extractfile(f"heroes-like-{VERSION}-linux-x86_64/build-info.json")
            self.assertIsNotNone(member)
            linux_info = json.loads(member.read().decode("utf-8"))
        windows_archive = archives / f"heroes-like-{VERSION}-windows-x86_64.zip"
        with zipfile.ZipFile(windows_archive, "r") as archive:
            windows_info = json.loads(
                archive.read(f"heroes-like-{VERSION}-windows-x86_64/build-info.json").decode("utf-8")
            )
        self.assertEqual(linux_info, {**expected_common, "platform": "linux-x86_64"})
        self.assertEqual(windows_info, {**expected_common, "platform": "windows-x86_64"})

    def test_release_index_source_revision_disagreement_is_rejected(self) -> None:
        self._package()
        index_path = self.output / "archives" / "release-index.json"
        index = json.loads(index_path.read_text(encoding="utf-8"))
        index["source_revision"] = "b" * 40
        index_path.write_text(json.dumps(index, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        failure = self._run("--verify-only", expect_ok=False)
        self.assertIn("platform manifest source revision mismatch", failure.stderr)

    def test_build_info_tampering_is_rejected_with_updated_outer_hashes(self) -> None:
        self._package()
        archive_path = self.output / "archives" / f"heroes-like-{VERSION}-windows-x86_64.zip"
        replacement_path = archive_path.with_suffix(".replacement.zip")
        build_info_name = f"heroes-like-{VERSION}-windows-x86_64/build-info.json"
        with zipfile.ZipFile(archive_path, "r") as source, zipfile.ZipFile(
            replacement_path, "w"
        ) as replacement:
            for member in source.infolist():
                payload = source.read(member.filename)
                if member.filename == build_info_name:
                    info = json.loads(payload.decode("utf-8"))
                    info["source_revision"] = "b" * 40
                    payload = (json.dumps(info, indent=2, sort_keys=True) + "\n").encode("utf-8")
                replacement.writestr(member, payload)
        replacement_path.replace(archive_path)
        self._rewrite_checksums()
        failure = self._run("--verify-only", expect_ok=False)
        self.assertIn("archive payload hash mismatch for windows-x86_64/build-info.json", failure.stderr)

    def test_source_revision_validation_and_dirty_local_source_rejection(self) -> None:
        failure = self._run(
            "--version",
            VERSION,
            "--skip-export",
            "--source-revision",
            "not-a-full-revision",
            expect_ok=False,
        )
        self.assertIn("full lowercase Git object id", failure.stderr)

        repo = Path(self.temp.name) / "source-repo"
        repo.mkdir()
        subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
        tracked = repo / "tracked.txt"
        tracked.write_text("clean\n", encoding="utf-8")
        subprocess.run(["git", "add", "tracked.txt"], cwd=repo, check=True)
        subprocess.run(
            ["git", "-c", "user.name=Package Test", "-c", "user.email=package@example.invalid", "commit", "-qm", "fixture"],
            cwd=repo,
            check=True,
        )
        expected_revision = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=repo, check=True, text=True, stdout=subprocess.PIPE
        ).stdout.strip()
        with mock.patch.object(package_release_module, "ROOT", repo):
            self.assertEqual(package_release_module.resolve_source_revision(""), expected_revision)
            tracked.write_text("dirty\n", encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "tracked changes"):
                package_release_module.resolve_source_revision("")

    def test_runnable_installer_tampering_is_rejected(self) -> None:
        self._package()
        installer = self.output / "archives" / f"heroes-like-{VERSION}-linux-x86_64.run"
        with installer.open("ab") as handle:
            handle.write(b"tampered")
        failure = self._run("--verify-only", expect_ok=False)
        self.assertIn("installer hash mismatch", failure.stderr)

    def test_linux_embedded_archive_tampering_is_rejected_with_updated_outer_hash(self) -> None:
        self._package()
        installer = self.output / "archives" / f"heroes-like-{VERSION}-linux-x86_64.run"
        payload = bytearray(installer.read_bytes())
        payload[-1] ^= 0x01
        installer.write_bytes(payload)
        installer.chmod(0o755)
        self._rewrite_checksums()
        failure = self._run("--verify-only", expect_ok=False)
        self.assertIn("embedded archive hash mismatch", failure.stderr)

    def test_runnable_installers_are_reproducible(self) -> None:
        self._package()
        archives = self.output / "archives"
        names = [
            f"heroes-like-{VERSION}-linux-x86_64.run",
            f"heroes-like-{VERSION}-windows-x86_64.setup.exe",
        ]
        first = {name: sha256(archives / name) for name in names}
        self._package()
        second = {name: sha256(archives / name) for name in names}
        self.assertEqual(first, second)

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

    def test_installer_payloads_are_verified_and_linux_lifecycle_is_reversible(self) -> None:
        self._package()
        archives = self.output / "archives"
        linux_archive = archives / f"heroes-like-{VERSION}-linux-x86_64.tar.gz"
        windows_archive = archives / f"heroes-like-{VERSION}-windows-x86_64.zip"
        linux_installer = archives / f"heroes-like-{VERSION}-linux-x86_64.run"
        windows_installer = archives / f"heroes-like-{VERSION}-windows-x86_64.setup.exe"
        extract_root = Path(self.temp.name) / "extracted"
        with tarfile.open(linux_archive, "r:gz") as archive:
            archive.extractall(extract_root, filter="data")
        linux_bundle = extract_root / f"heroes-like-{VERSION}-linux-x86_64"

        install_root = Path(self.temp.name) / "installed-linux"
        bin_root = Path(self.temp.name) / "bin"
        applications_root = Path(self.temp.name) / "applications"
        user_data = Path(self.temp.name) / "user-data"
        user_data.mkdir()
        sentinel = user_data / "save.json"
        sentinel.write_text("preserve", encoding="utf-8")
        env = os.environ.copy()
        env.update(
            {
                "HEROES_LIKE_INSTALL_DIR": str(install_root),
                "HEROES_LIKE_BIN_DIR": str(bin_root),
                "HEROES_LIKE_APPLICATIONS_DIR": str(applications_root),
            }
        )
        unowned_root = Path(self.temp.name) / "unowned"
        unowned_root.mkdir()
        unowned_sentinel = unowned_root / "keep.txt"
        unowned_sentinel.write_text("keep", encoding="utf-8")
        unowned_env = dict(env)
        unowned_env["HEROES_LIKE_INSTALL_DIR"] = str(unowned_root)
        refused_uninstall = subprocess.run(
            ["sh", str(linux_bundle / "uninstall.sh")],
            env=unowned_env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
        )
        self.assertNotEqual(refused_uninstall.returncode, 0, msg=refused_uninstall.stdout)
        self.assertEqual(unowned_sentinel.read_text(encoding="utf-8"), "keep")

        self.assertTrue(os.access(linux_installer, os.X_OK))
        install = subprocess.run(
            [str(linux_installer)],
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
        )
        self.assertEqual(install.returncode, 0, msg=install.stdout)
        self.assertTrue((install_root / "heroes-like.x86_64").is_file())
        self.assertTrue(os.access(install_root / "heroes-like.x86_64", os.X_OK))
        self.assertTrue((bin_root / "heroes-like").is_file())
        self.assertTrue((applications_root / "heroes-like.desktop").is_file())

        uninstall = subprocess.run(
            ["sh", str(linux_bundle / "uninstall.sh")],
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
        )
        self.assertEqual(uninstall.returncode, 0, msg=uninstall.stdout)
        self.assertFalse(install_root.exists())
        self.assertFalse((bin_root / "heroes-like").exists())
        self.assertFalse((applications_root / "heroes-like.desktop").exists())
        self.assertEqual(sentinel.read_text(encoding="utf-8"), "preserve")

        with zipfile.ZipFile(windows_archive, "r") as archive:
            names = {Path(name).name for name in archive.namelist()}
            install_cmd = archive.read(f"heroes-like-{VERSION}-windows-x86_64/install.cmd").decode("ascii")
        self.assertIn("install.cmd", names)
        self.assertIn("uninstall.cmd", names)
        self.assertIn("HEROES_LIKE_INSTALL_DIR", install_cmd)
        self.assertIn("Heroes Like.cmd", install_cmd)
        setup_head = windows_installer.read_bytes()[:4096]
        self.assertEqual(setup_head[:2], b"MZ")


if __name__ == "__main__":
    unittest.main()
