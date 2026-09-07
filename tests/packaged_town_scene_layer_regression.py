#!/usr/bin/env python3
"""Run the existing paid Town/save/input probe using only an isolated release pack.

The loose files contain only the Python-owned probe, never game scripts or art.
Windows/Wine uses the same assertions without screenshot operations because its
headless display cannot draw. Linux retains the rendered visual evidence.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile

import town_scene_layer_regression as layers

sys.path.insert(0, str(layers.ROOT / 'tools'))
from compact_export_pck import read_directory


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def windows_path(path):
    return 'Z:' + str(Path(path).resolve()).replace('/', '\\')


def headless_script(script):
    removed = []
    result = []
    for line in script.splitlines():
        if line.strip() == 'await RenderingServer.frame_post_draw' or line.strip().startswith('get_viewport().get_texture().get_image().save_png('):
            removed.append(line.strip())
            result.append(line[:len(line)-len(line.lstrip())] + 'pass # Headless package: no visual capture; all assertions retained.')
        else:
            result.append(line)
    frames = sum(line == 'await RenderingServer.frame_post_draw' for line in removed)
    if not frames or len(removed) != 2 * frames:
        raise ValueError('Expected paired frame/capture operations in the existing probe')
    return '\n'.join(result) + '\n', removed


def run(command, env, log, cwd, timeout):
    process = subprocess.Popen(command, cwd=cwd, env=env, stdout=log,
                               stderr=subprocess.STDOUT, start_new_session=True)
    try:
        return process.wait(timeout=timeout)
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=5)


def main():
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--pack', type=Path, required=True)
    parser.add_argument('--platform', choices=('linux', 'windows'), required=True)
    parser.add_argument('--wine-prefix', type=Path)
    parser.add_argument('--bootstrap-controls', action='store_true', help='Also prove inert normal startup and rejected path/hash/base-type controls')
    args, forwarded = parser.parse_known_args()
    binary, pack = args.binary.resolve(strict=True), args.pack.resolve(strict=True)
    if binary.parent != pack.parent or binary.stem != pack.stem or not binary.is_file() or not pack.is_file():
        parser.error('matching-stem binary and standalone pack must share an isolated export directory')
    export = binary.parent
    # No loose source/resource tree, symlinks, or existing override probes may
    # satisfy a missing packaged dependency. Only official export products.
    allowed_suffixes = ('.pck', '.exe', '.x86_64', '.so', '.dll')
    inventory = list(export.iterdir())
    if any(p.is_symlink() or not p.is_file() or not p.name.endswith(allowed_suffixes) for p in inventory):
        parser.error('export directory contains non-package files or symlinks')
    payload = pack.read_bytes()
    _, entries = read_directory(payload)
    manifest_path = 'content/town_building_scene_art_manifest.json'
    entry = next(e for e in entries if e.path == manifest_path)
    if json.loads(payload[entry.offset:entry.offset+entry.size]) != json.loads((layers.ROOT/manifest_path).read_text()):
        parser.error('release pack does not contain the current exact scene-art manifest')
    if len(payload) > 250_000_000:
        parser.error('release pack exceeds the unchanged package ceiling')
    owner_paths = {'scenes/town/TownShell.gdc', 'scenes/town/TownStageView.gdc',
                   'scenes/town/TownBuildingHotspot.gdc', 'scripts/autoload/LiveValidationHarness.gdc'}
    packed_owners = {e.path: hashlib.sha256(payload[e.offset:e.offset+e.size]).hexdigest()
                     for e in entries if e.path in owner_paths}
    if set(packed_owners) != owner_paths:
        parser.error('release pack is missing required compiled Town/bootstrap owners')
    del payload
    hashes = {str(p): sha(p) for p in inventory}
    details = dict(platform=args.platform, pack_bytes=pack.stat().st_size,
                   pack_sha256=hashes[str(pack)], current_manifest_equal=True,
                   packed_runtime_owner_sha256=packed_owners,
                   isolated_export_inventory=[p.name for p in inventory],
                   entry_count=len(entries), visual_capture=args.platform=='linux')
    wine_env = None
    if args.platform == 'windows':
        if args.wine_prefix is None or args.wine_prefix.exists():
            parser.error('Windows requires a new nonexistent --wine-prefix')
        if not all(shutil.which(tool) for tool in ('wine', 'wineboot', 'wineserver')):
            parser.error('Wine runtime tools unavailable')
        wine_env = dict(WINEPREFIX=str(args.wine_prefix.resolve()), WINEARCH='win64',
                        WINEDEBUG='-all', WINEDLLOVERRIDES='dinput8=')

    def bootstrap_controls(work, script, env, destination):
        path = work/'probe.gd'
        source = 'extends Node\nfunc _ready():\n\tprint("TOWN_BOOTSTRAP_CONTROL_EXECUTED")\n\tget_tree().quit()\n'
        marker = 'TOWN_BOOTSTRAP_CONTROL_EXECUTED'
        accepted_path = 'res://'+work.name+'/probe.gd'
        cases = [
            ('inert_without_flow', source, accepted_path, None, False, ''),
            ('reject_traversal', source, 'res://'+work.name+'/../probe.gd', None, True, 'path/hash rejected'),
            ('reject_hash', source, accepted_path, '0'*64, True, 'path/hash rejected'),
            ('reject_base_type', 'extends RefCounted\n', accepted_path, None, True, 'not an instantiable Node script'),
            ('accept_exact_node', source, accepted_path, None, True, ''),
        ]
        results = []
        try:
            for name, body, resource, override_hash, enabled, error in cases:
                path.write_text(body)
                digest = override_hash or hashlib.sha256(body.encode()).hexdigest()
                command = (['wine', str(binary)] if args.platform=='windows' else [str(binary)])
                command += ['--headless', '--audio-driver', 'Dummy', '--accessibility', 'disabled', '--rendering-method', 'gl_compatibility']
                if not enabled: command += ['--quit-after', '60']
                command += ['--', '--live-validation-town-probe-path='+resource, '--live-validation-town-probe-sha256='+digest]
                if enabled: command += ['--live-validation-flow=python_town_scene_probe']
                log_path = destination/('bootstrap_'+name+'.log')
                with log_path.open('w') as log:
                    code = run(command, env, log, export, 60)
                text = log_path.read_text()
                executed = marker in text
                ok = (code==1 and error in text and not executed) if error else (code==0 and executed==enabled and 'SCRIPT ERROR:' not in text and 'ERROR:' not in text)
                results.append(dict(case=name, ok=ok, returncode=code, probe_executed=executed))
        finally:
            path.write_text(script)
        (destination/'bootstrap-controls.json').write_text(json.dumps(results, indent=2)+'\n')
        details['bootstrap_controls'] = results
        if not all(row['ok'] for row in results):
            raise RuntimeError('Packaged Town bootstrap control failed; see bootstrap-controls.json')

    def packaged_probe(command, env, log, timeout_seconds=900):
        original_scene = layers.ROOT / command[-1].removeprefix('res://')
        script = (original_scene.parent/'probe.gd').read_text()
        details['original_probe_sha256'] = hashlib.sha256(script.encode()).hexdigest()
        if args.platform == 'windows':
            script, details['omitted_headless_capture_operations'] = headless_script(script)
        details['packaged_probe_sha256'] = hashlib.sha256(script.encode()).hexdigest()
        with tempfile.TemporaryDirectory(prefix='_town_scene_probe_', dir=export) as temporary:
            work = Path(temporary)
            (work/'probe.gd').write_text(script)
            # Official release templates disallow --main-pack/--path overrides.
            # Use their normal adjacent matching-stem PCK, with cwd isolated too.
            arguments = ['--audio-driver', 'Dummy',
                         '--accessibility', 'disabled', '--resolution', env['TOWN_OVERLAY_RESOLUTION'],
                         '--', '--live-validation-flow=python_town_scene_probe',
                         '--live-validation-town-probe-path=res://'+work.name+'/probe.gd',
                         '--live-validation-town-probe-sha256='+details['packaged_probe_sha256']]
            if args.platform == 'linux':
                command = ['dbus-run-session', '--', 'xvfb-run', '-a', '-s', '-screen 0 2200x1200x24', str(binary)] + arguments
            else:
                env = dict(env, **wine_env)
                for key in ('TOWN_OVERLAY_SAVE', 'TOWN_OVERLAY_OUTPUT', 'TOWN_HARBOR_DEVELOPED_SAVE'):
                    if key in env: env[key] = windows_path(env[key])
                for initial in (['wineboot', '-u'], ['wineserver', '-k'], ['wineserver', '-w']):
                    if run(initial, env, log, export, 90) != 0:
                        raise RuntimeError('Fresh Wine prefix initialization failed')
                command = ['wine', str(binary), '--headless', '--rendering-method', 'gl_compatibility'] + arguments
            try:
                if args.bootstrap_controls:
                    bootstrap_controls(work, script, env, Path(log.name).parent)
                return run(command, env, log, export, timeout_seconds)
            finally:
                if args.platform == 'windows':
                    run(['wineserver', '-k'], env, log, export, 30)
                    run(['wineserver', '-w'], env, log, export, 30)

    layers.run_probe = packaged_probe
    sys.argv = [str(Path(layers.__file__))] + forwarded
    code = layers.main()
    label = forwarded[forwarded.index('--label')+1]
    report_path = layers.OUTPUT/label/'report.json'
    report = json.loads(report_path.read_text())
    details['export_unchanged'] = hashes == {str(p): sha(p) for p in export.iterdir()}
    details['all_probe_assertions_retained'] = True
    details['ok'] = code == 0 and report['ok'] and details['export_unchanged']
    (report_path.parent/'packaged-report.json').write_text(json.dumps(details, indent=2)+'\n')
    print(json.dumps(details))
    return 0 if details['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
