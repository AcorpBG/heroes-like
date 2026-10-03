"""Import only this unit's two textures, verify pixels, then review live playback."""
import json, os, re, shutil, subprocess, sys, tempfile
from pathlib import Path
import produce as p
from creature_animation_lock import exclusive
from prepare_lossless_texture_imports import atomic_write

UID = 'unit_neutral_cindervane_censerwings'
GODOT = os.environ.get('GODOT_BIN', 'D:/Games/godot/Godot_v4.6.2-stable_win64_console.exe' if os.name == 'nt' else 'godot')
OUT = p.ROOT / '.artifacts/parallel_animation_20261003' / UID
PATHS = [f'art/animation/runtime/fluid/{UID}.png',
         f'art/overworld/runtime/creature_idle/{UID}.png']


def engine(root, arguments, log):
    profile = log.parent/'isolated_import_profile'
    profile.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, APPDATA=str(profile), XDG_DATA_HOME=str(profile),
               GODOT_SILENCE_ROOT_WARNING='1')
    with log.open('w', encoding='utf-8') as stream:
        result = subprocess.run([GODOT, '--headless', '--path', str(root),
                                 '--audio-driver', 'Dummy', *arguments],
                                env=env, stdout=stream, stderr=subprocess.STDOUT,
                                timeout=180, creationflags=subprocess.CREATE_NO_WINDOW
                                if os.name == 'nt' else 0)
    output = log.read_text(encoding='utf-8')
    errors = [line for line in output.splitlines()
              if ('ERROR' in line or 'leaked' in line)
              and 'Failed to read the root certificate store.' not in line]
    assert result.returncode == 0 and not errors, (result.returncode, errors, log)
    return output


def import_selected():
    # No editor scan of the game: a disposable project has exactly two rasters
    # at their actual res:// paths, with any existing options/UID preserved.
    with tempfile.TemporaryDirectory(prefix='cindervane-import-', dir=OUT) as folder:
        work = Path(folder)
        (work/'project.godot').write_text(
            'config_version=5\n[application]\nconfig/name="Cindervane texture import"\n'
            '[rendering]\ntextures/webp_compression/lossless_compression_factor=100.0\n')
        originals = {}
        existing_options = {}
        for relative in PATHS:
            source = p.ROOT/relative
            originals[relative] = p.sha(source)
            target = work/relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            options = Path(str(source)+'.import')
            if options.exists():
                existing_options[relative] = options.read_bytes()
                Path(str(target)+'.import').write_bytes(existing_options[relative])
        engine(work, ['--editor', '--import'], OUT/'selected_import.log')
        # Preserve the existing map configuration; create a normal Godot
        # configuration only for the newly published battle atlas.
        replacements = {}
        for relative in PATHS:
            options = Path(str(work/relative)+'.import')
            raw = options.read_bytes()
            if relative in existing_options:
                assert raw == existing_options[relative], relative
            text = raw.decode('utf-8')
            assert re.search(r'^compress/mode=0$', text, re.M), relative
            cache = re.search(r'^path="res://([^"\n]+)"$', text, re.M)[1]
            assert re.fullmatch(r'\.godot/imported/[^/]+\.ctex', cache), cache
            replacements[relative+'.import'] = raw
            for name in [cache, cache[:-5]+'.md5']:
                replacements[name] = (work/name).read_bytes()
        # These cache/options paths belong only to this UID, so no shared
        # catalog lock is needed or nested inside the GPU lease.
        assert originals == {name:p.sha(p.ROOT/name) for name in PATHS}
        for name, raw in replacements.items():
            target = p.ROOT/name
            assert target.resolve().is_relative_to(p.ROOT.resolve())
            atomic_write(target, raw)
        output = engine(p.ROOT,
                        ['--script', str(p.SOURCE_DIR/'verify_imported_atlas.gd')],
                        OUT/'imported_pixels.log')
        assert 'CINDERVANE_CENSERWING_IMPORTED_ATLAS_OK' in output
        print(output, flush=True)
        p.write(OUT/'selected_import.json',
                dict(source_sha256=originals, scoped_textures=PATHS,
                     imported_battle_atlas_exact_rgba=True))


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    with exclusive('gpu'):
        import_selected()
        subprocess.run([sys.executable, str(p.SOURCE_DIR/'run_native_review.py'),
                        '--godot', GODOT, '--live', '--unit', UID, '--render',
                        '--output', str(OUT/'live_native')], cwd=p.ROOT, check=True)
        subprocess.run([sys.executable, str(p.SOURCE_DIR/'run_ranged_native.py'),
                        '--godot', GODOT, '--live', '--unit', UID, '--render',
                        '--output', str(OUT/'live_ranged')], cwd=p.ROOT, check=True)
