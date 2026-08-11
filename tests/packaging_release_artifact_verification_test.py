#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import os
import shutil
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
VERSION = package_release_module.project_version()
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

        numeric_version = package_release_module.windows_numeric_version(VERSION)
        numeric_commas = ",".join(numeric_version.split("."))
        source_path = windows / "version-fixture.c"
        resource_path = windows / "version-fixture.rc"
        object_path = windows / "version-fixture.res.o"
        source_path.write_text("int main(void) { return 0; }\n", encoding="ascii")
        resource_path.write_text(
            f'''#include <windows.h>
1 VERSIONINFO
FILEVERSION {numeric_commas}
PRODUCTVERSION {numeric_commas}
FILEFLAGSMASK 0x3fL
FILEFLAGS 0x0L
FILEOS 0x40004L
FILETYPE 0x1L
FILESUBTYPE 0x0L
BEGIN
  BLOCK "StringFileInfo"
  BEGIN
    BLOCK "040904B0"
    BEGIN
      VALUE "CompanyName", "Aurelion Reach contributors"
      VALUE "FileDescription", "Aurelion Reach"
      VALUE "FileVersion", "{numeric_version}"
      VALUE "ProductName", "Aurelion Reach"
      VALUE "ProductVersion", "{numeric_version}"
    END
  END
  BLOCK "VarFileInfo"
  BEGIN
    VALUE "Translation", 0x0409, 1200
  END
END
''',
            encoding="ascii",
        )
        subprocess.run(
            ["x86_64-w64-mingw32-windres", str(resource_path), str(object_path)],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        subprocess.run(
            [
                "x86_64-w64-mingw32-gcc",
                "-Os",
                "-s",
                "-mwindows",
                "-Wl,--no-insert-timestamp",
                str(source_path),
                str(object_path),
                "-o",
                str(windows / "heroes-like.exe"),
            ],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        source_path.unlink()
        resource_path.unlink()
        object_path.unlink()
        pe = (windows / "heroes-like.exe").read_bytes()
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

    def _generated_nsis_sources(self) -> tuple[str, str, dict]:
        self._package()
        archive_path = self.output / "archives" / f"heroes-like-{VERSION}-windows-x86_64.zip"
        extract_root = Path(self.temp.name) / "nsis-source"
        with zipfile.ZipFile(archive_path, "r") as archive:
            archive.extractall(extract_root)
        bundle_root = extract_root / f"heroes-like-{VERSION}-windows-x86_64"
        manifest = json.loads((bundle_root / "release-manifest.json").read_text(encoding="utf-8"))
        destination = extract_root / "generated.setup.exe"
        captured: dict[str, str] = {}

        def fake_makensis(args: list[str], timeout: int = 900) -> None:
            del timeout
            script_path = Path(args[-1])
            captured["script"] = script_path.read_text(encoding="utf-8")
            captured["ownership"] = (script_path.parent / "heroes-like-ownership.ini").read_text(encoding="ascii")
            destination.write_bytes(b"MZ" + b"transactional-nsis-test")

        with mock.patch.object(package_release_module, "run", side_effect=fake_makensis):
            package_release_module.create_windows_nsis_installer(
                bundle_root,
                destination,
                VERSION,
                "makensis-test",
                manifest,
            )
        return captured["script"], captured["ownership"], manifest

    def test_windows_version_mapping_and_pe_resource_verification_fail_closed(self) -> None:
        self.assertEqual(package_release_module.windows_numeric_version("1.2.3-alpha.4"), "1.2.3.1004")
        self.assertEqual(package_release_module.windows_numeric_version("1.2.3-beta.4"), "1.2.3.2004")
        self.assertEqual(package_release_module.windows_numeric_version("1.2.3-rc.4"), "1.2.3.3004")
        self.assertEqual(package_release_module.windows_numeric_version("1.2.3"), "1.2.3.65535")
        for invalid in ("1.2", "1.2.3-preview.1", "1.2.3-alpha", "65536.0.0", "1.2.3-alpha.64536"):
            with self.subTest(version=invalid):
                with self.assertRaises(ValueError):
                    package_release_module.windows_numeric_version(invalid)

        expected_numeric = package_release_module.windows_numeric_version(VERSION)
        exe_path = self.output / "exports" / "windows-x86_64" / "heroes-like.exe"
        resource = package_release_module.verify_windows_pe_version(exe_path, VERSION)
        self.assertEqual(resource["file_version"], expected_numeric)
        self.assertEqual(resource["product_version"], expected_numeric)
        self.assertEqual(resource["strings"]["FileVersion"], expected_numeric)
        self.assertEqual(resource["strings"]["ProductVersion"], expected_numeric)
        self.assertEqual(resource["strings"]["ProductName"], "Aurelion Reach")
        self.assertEqual(resource["strings"]["FileDescription"], "Aurelion Reach")
        self.assertEqual(
            package_release_module.validate_windows_export_preset_version(VERSION),
            expected_numeric,
        )

        stale_preset_root = Path(self.temp.name) / "stale-preset"
        stale_preset_root.mkdir()
        (stale_preset_root / "export_presets.cfg").write_text(
            'application/file_version="1.0.0.0"\napplication/product_version="1.0.0.0"\n',
            encoding="utf-8",
        )
        with mock.patch.object(package_release_module, "ROOT", stale_preset_root):
            with self.assertRaisesRegex(RuntimeError, "must equal"):
                package_release_module.validate_windows_export_preset_version(VERSION)

        tampered = exe_path.with_name("tampered-version.exe")
        original_pe = exe_path.read_bytes()
        tampered.write_bytes(
            original_pe.replace(expected_numeric.encode("utf-16le"), b"9\x00" * len(expected_numeric))
            + original_pe
        )
        with self.assertRaisesRegex(RuntimeError, "version"):
            package_release_module.verify_windows_pe_version(tampered, VERSION)

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
        self.assertIn("Aurelion Reach.cmd", install_cmd)
        self.assertIn("Heroes Like.cmd", install_cmd)
        setup_head = windows_installer.read_bytes()[:4096]
        self.assertEqual(setup_head[:2], b"MZ")

    def test_generated_nsis_uses_verified_transaction_and_owned_uninstall(self) -> None:
        script, ownership, manifest = self._generated_nsis_sources()
        required_script_tokens = (
            f'VIProductVersion "{package_release_module.windows_numeric_version(VERSION)}"',
            f'VIAddVersionKey /LANG=1033 "FileVersion" "{package_release_module.windows_numeric_version(VERSION)}"',
            f'VIAddVersionKey /LANG=1033 "ProductVersion" "{package_release_module.windows_numeric_version(VERSION)}"',
            'VIAddVersionKey /LANG=1033 "ProductName" "Aurelion Reach"',
            'VIAddVersionKey /LANG=1033 "FileDescription" "Aurelion Reach"',
            "SetCompressor zlib",
            "SetCompress off",
            "CRCCheck off",
            "CRCCheck off",
            'SetOutPath "$PLUGINSDIR\\payload"',
            "heroes-like-installer-helper.exe",
            "!insertmacro VERIFY_FILE",
            'ReadEnvStr $3 "HEROES_LIKE_INSTALL_FAIL_PHASE"',
            'StrCmp $3 "precommit" injected_precommit',
            'StrCmp $3 "after_backup" injected_after_backup',
            'Rename "$INSTDIR" "$2"',
            'Rename "$2" "$INSTDIR"',
            "Call VerifyOwnedRoot",
            "Call un.VerifyOwnedRoot",
            "dynamic bounded manifest/hash/exact-root verification",
            'verify "$INSTDIR\\release-manifest.json" "$INSTDIR" windows-x86_64',
            'release-manifest.json .heroes-like-install install-ownership.ini uninstall.exe',
            'FileWrite $TxHandle "heroes-like-user-local-install-v1',
            'CreateShortcut "$SMPROGRAMS\\Aurelion Reach\\Aurelion Reach.lnk"',
            'CreateShortcut "$SMPROGRAMS\\Aurelion Reach\\Uninstall Aurelion Reach.lnk"',
            "Function SnapshotRegistration",
            "Function RestoreRegistration",
            "Function PublishRegistration",
            "Call SnapshotRegistration",
            "Call SnapshotShortcuts",
            "Call PublishRegistration",
            "Call RestoreRegistration",
            "Call RestoreShortcuts",
            'WriteRegStr HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Heroes Like" "DisplayName" "Aurelion Reach"',
            f'WriteRegStr HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Heroes Like" "DisplayVersion" "{VERSION}"',
            'WriteRegStr HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Heroes Like" "Publisher" "Aurelion Reach contributors"',
            'WriteRegStr HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Heroes Like" "DisplayIcon" \'"$INSTDIR\\heroes-like.exe",0\'',
            'WriteRegStr HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Heroes Like" "UninstallString" \'"$INSTDIR\\uninstall.exe"\'',
            'WriteRegStr HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Heroes Like" "QuietUninstallString" \'"$INSTDIR\\uninstall.exe" /S\'',
            'WriteRegDWORD HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Heroes Like" "NoModify" 1',
            'WriteRegDWORD HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Heroes Like" "NoRepair" 1',
            "registration_publish_failed:",
            'SetOutPath "$TEMP"',
        )
        for token in required_script_tokens:
            self.assertIn(token, script)
        for function_name in ("VerifyOwnedRoot", "un.VerifyOwnedRoot"):
            function = script.split(f"Function {function_name}\n", 1)[1].split("FunctionEnd", 1)[0]
            self.assertIn('verify_owned_invalid:\n  StrCpy $TxActual "invalid"', function)
            self.assertEqual(function.count('StrCpy $TxActual "ok"'), 1)
            conditional_done_branches = [
                line.strip()
                for line in function.splitlines()
                if line.strip().startswith(("StrCmp ", "IntCmp ", "IfFileExists ", "IfErrors "))
                and "verify_owned_done" in line
            ]
            self.assertEqual(conditional_done_branches, [], msg=function)
        for function_name, label in (
            ("LegacyKeyExists", "legacy_key_exists"),
            ("ArpKeyExists", "arp_key_exists"),
            ("un.ArpKeyExists", "arp_key_exists"),
        ):
            function = script.split(f"Function {function_name}\n", 1)[1].split("FunctionEnd", 1)[0]
            bounded = f"IntCmp $TxIndex 4096 {label}_done {label}_query {label}_done"
            empty_done = f'StrCmp $TxName "" {label}_done'
            self.assertIn(bounded, function)
            self.assertIn(empty_done, function)
            self.assertLess(function.index(bounded), function.index("EnumRegKey"))
            self.assertLess(function.index("EnumRegKey"), function.index(empty_done))
        self.assertLess(script.index("staged_verification_failed"), script.index('Rename "$INSTDIR" "$2"'))
        self.assertLess(script.index('Rename "$1" "$INSTDIR"'), script.index("CreateShortcut"))
        self.assertLess(script.index("Call SnapshotRegistration"), script.index('Rename "$INSTDIR" "$2"'))
        publish_index = script.index("Call PublishRegistration")
        self.assertLess(publish_index, script.index('RMDir /r "$2"', publish_index))
        publication_failure = script.split("registration_publish_failed:", 1)[1].split("commit_failed:", 1)[0]
        self.assertIn("Call RestoreShortcuts", publication_failure)
        self.assertIn("Call RestoreRegistration", publication_failure)
        install_section = script.split('Section "Install"', 1)[1].split("SectionEnd", 1)[0]
        pre_prior = install_section.split("prior_verified:", 1)[0]
        staged_file_lines = [line.strip() for line in pre_prior.splitlines() if line.strip().startswith("File ")]
        self.assertEqual(len(staged_file_lines), 1, msg=pre_prior)
        self.assertIn("heroes-like-installer-helper.exe", staged_file_lines[0])
        self.assertNotIn("CopyFiles", install_section)
        candidate_out = install_section.index('SetOutPath "$1"')
        self.assertLess(install_section.index("Call SnapshotRegistration"), candidate_out)
        self.assertLess(install_section.index("Call SnapshotShortcuts"), candidate_out)
        self.assertLess(install_section.index('RMDir /r "$INSTDIR.backup"'), candidate_out)
        candidate_tail = install_section[candidate_out:]
        for payload_name in [*(str(row["path"]) for row in manifest["files"]), "release-manifest.json"]:
            direct_file = f"File /oname={payload_name} "
            direct_index = candidate_tail.index(direct_file)
            following = candidate_tail[direct_index:].splitlines()[:2]
            self.assertEqual(following[1].strip(), "IfErrors commit_candidate_metadata_failed")
        candidate_verify = 'verify "$1\\release-manifest.json" "$1" windows-x86_64 release-manifest.json .heroes-like-install install-ownership.ini uninstall.exe'
        self.assertIn(candidate_verify, script)
        candidate_verify_index = script.index(candidate_verify)
        leave_candidate_index = script.index('SetOutPath "$TEMP"', candidate_verify_index)
        self.assertLess(candidate_verify_index, leave_candidate_index)
        self.assertLess(leave_candidate_index, script.index('ReadEnvStr $3 "HEROES_LIKE_INSTALL_FAIL_PHASE"'))
        self.assertLess(script.index(candidate_verify), script.index('Rename "$INSTDIR" "$2"'))
        self.assertNotIn("VERIFY_FILE_SIZE", script)
        self.assertNotIn("commit_candidate_failed_", script)
        registry_lookup_contracts = (
            ("LegacyKeyExists", "legacy_key_exists"),
            ("ArpKeyExists", "arp_key_exists"),
            ("un.ArpKeyExists", "arp_key_exists"),
        )
        for function_name, label_prefix in registry_lookup_contracts:
            function = script.split(f"Function {function_name}\n", 1)[1].split("FunctionEnd", 1)[0]
            self.assertIn(
                f"IntCmp $TxIndex 4096 {label_prefix}_done {label_prefix}_query {label_prefix}_done",
                function,
            )
            self.assertIn(f'StrCmp $TxName "" {label_prefix}_done', function)
        self.assertIn('commit_candidate_metadata_failed:\n  SetOutPath "$TEMP"\n  RMDir /r "$1"', script)
        live_probe = 'IfFileExists "$INSTDIR\\*.*" prior_live_root'
        backup_content_probe = 'IfFileExists "$INSTDIR.backup\\*.*" recovery_backup_refused'
        backup_path_probe = 'IfFileExists "$INSTDIR.backup" recovery_backup_refused'
        self.assertLess(script.index(live_probe), script.index(backup_content_probe))
        self.assertLess(script.index(backup_content_probe), script.index(backup_path_probe))
        self.assertLess(script.index(backup_path_probe), script.index("prior_verified:"))
        self.assertLess(script.index("prior_verified:"), script.index('RMDir /r "$INSTDIR.backup"'))
        recovery_refusal = script.split("recovery_backup_refused:", 1)[1].split("install_done:", 1)[0]
        self.assertIn("the backup was preserved", recovery_refusal)
        self.assertIn("SetErrorLevel 30", recovery_refusal)
        self.assertNotIn("RMDir", recovery_refusal)
        self.assertNotIn("Delete", recovery_refusal)
        self.assertNotIn("Rename", recovery_refusal)
        uninstall = script.split('Section "Uninstall"', 1)[1]
        self.assertLess(uninstall.index("Call un.VerifyOwnedRoot"), uninstall.index('Delete "$INSTDIR'))
        self.assertLess(uninstall.index('RMDir "$INSTDIR"'), uninstall.index('DeleteRegKey HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Heroes Like"'))
        self.assertIn("SetRegView 64", uninstall)
        self.assertIn('Delete "$SMPROGRAMS\\Aurelion Reach\\Uninstall Aurelion Reach.lnk"', uninstall)
        self.assertNotIn('RMDir /r "$INSTDIR"', uninstall)
        self.assertIn("Schema=heroes-like-windows-install-ownership-v1", ownership)
        self.assertIn("Marker=heroes-like-user-local-install-v1", ownership)
        expected_rows = [*manifest["files"], {
            "path": "release-manifest.json",
            "size_bytes": None,
            "sha256": None,
        }]
        for row in expected_rows:
            self.assertIn(f"Path={row['path']}", ownership)
            if row["size_bytes"] is not None:
                self.assertIn(f"Size={row['size_bytes']}", ownership)
                self.assertIn(f"Sha256={row['sha256']}", ownership)
        helper_rows = [row for row in manifest["files"] if row["path"] == "heroes-like-installer-helper.exe"]
        self.assertEqual(len(helper_rows), 1)

    def test_windows_nsis_rejects_compile_time_manifest_identity_disagreement(self) -> None:
        self._package()
        archive_path = self.output / "archives" / f"heroes-like-{VERSION}-windows-x86_64.zip"
        extract_root = Path(self.temp.name) / "nsis-negative"
        with zipfile.ZipFile(archive_path, "r") as archive:
            archive.extractall(extract_root)
        bundle_root = extract_root / f"heroes-like-{VERSION}-windows-x86_64"
        manifest = json.loads((bundle_root / "release-manifest.json").read_text(encoding="utf-8"))
        manifest["files"][0]["sha256"] = "0" * 64
        with self.assertRaisesRegex(RuntimeError, "identity mismatch"):
            package_release_module.windows_nsis_payload_rows(bundle_root, manifest)

    def test_windows_installer_helper_strict_copy_and_owned_remove(self) -> None:
        wine = shutil.which("wine")
        if wine is None:
            self.skipTest("Wine is required for the Windows installer helper runtime contract")
        probe_root = Path(self.temp.name) / "helper probe with spaces"
        source = probe_root / "source root"
        destination = probe_root / "destination root"
        source.mkdir(parents=True)
        (source / "alpha.exe").write_bytes(b"alpha")
        (source / "beta.pck").write_bytes(b"beta payload")
        rows = []
        for name in ("alpha.exe", "beta.pck"):
            path = source / name
            rows.append({
                "path": name,
                "sha256": sha256(path),
                "size_bytes": path.stat().st_size,
            })
        manifest = {
            "files": rows,
            "platform": "windows-x86_64",
            "product_id": "heroes-like",
            "schema_id": "heroes_like_platform_release_manifest_v2",
            "source_date_epoch": 315532800,
            "source_revision": SOURCE_REVISION,
            "version": VERSION,
        }
        manifest_path = source / "release-manifest.json"
        manifest_text = json.dumps(manifest, indent=2, sort_keys=True) + "\n"
        manifest_path.write_text(manifest_text, encoding="utf-8")
        helper = probe_root / "heroes-like-installer-helper.exe"
        package_release_module.build_windows_installer_helper(helper)
        env = os.environ.copy()
        env.update({"WINEDEBUG": "-all", "WINEPREFIX": str(probe_root / "wine-prefix")})

        def helper_run(*args: object) -> subprocess.CompletedProcess[str]:
            return subprocess.run(
                [wine, str(helper), *(str(value) for value in args)],
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                check=False,
                timeout=120,
            )

        copied = helper_run("copy", manifest_path, source, destination, "windows-x86_64")
        self.assertEqual(copied.returncode, 0, msg=copied.stdout)
        verified = helper_run(
            "verify", destination / "release-manifest.json", destination,
            "windows-x86_64", "release-manifest.json",
        )
        self.assertEqual(verified.returncode, 0, msg=verified.stdout)
        intruder = destination / "unowned-sentinel.txt"
        intruder.write_text("preserve", encoding="utf-8")
        refused = helper_run(
            "remove", destination / "release-manifest.json", destination,
            "windows-x86_64", "release-manifest.json",
        )
        self.assertNotEqual(refused.returncode, 0, msg=refused.stdout)
        self.assertTrue((destination / "alpha.exe").is_file())
        removed = helper_run(
            "remove", destination / "release-manifest.json", destination,
            "windows-x86_64", "release-manifest.json", intruder.name,
        )
        self.assertEqual(removed.returncode, 0, msg=removed.stdout)
        self.assertFalse((destination / "alpha.exe").exists())
        self.assertFalse((destination / "beta.pck").exists())
        self.assertEqual(intruder.read_text(encoding="utf-8"), "preserve")

        truncated = probe_root / "truncated-manifest.json"
        truncated.write_text(manifest_text[:manifest_text.index('  "platform"')], encoding="utf-8")
        self.assertNotEqual(helper_run("list", truncated, "windows-x86_64").returncode, 0)
        injected = probe_root / "injected-manifest.json"
        injected.write_text(
            manifest_text.rstrip()[:-1] + ', "path": "alpha.exe", "sha256": "' +
            ("0" * 64) + '", "size_bytes": 5}\n',
            encoding="utf-8",
        )
        self.assertNotEqual(helper_run("list", injected, "windows-x86_64").returncode, 0)


if __name__ == "__main__":
    unittest.main()
