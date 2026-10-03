"""Import exactly the corrected unit's two textures, then review normal Strike.

The temporary import project copies existing lossless settings and resource UIDs.
No full game editor scan or renderer/settings mutation is performed.
"""
import argparse, hashlib, os, re, shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
UID = Path(__file__).resolve().parent.name
sys.path.insert(0, str(ROOT / 'tools'))
from creature_animation_lock import exclusive

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--output', required=True, type=Path)
    a = p.parse_args()
    output = a.output.resolve()
    assert output.is_relative_to(ROOT / '.artifacts')
    output.mkdir(parents=True, exist_ok=True)
    paths = [f'art/animation/runtime/fluid/{UID}.png', f'art/overworld/runtime/creature_idle/{UID}.png']
    key = 'textures/webp_compression/lossless_compression_factor'
    factor = re.search(r'(?m)^' + re.escape(key) + r'=(.+)$', (ROOT / 'project.godot').read_text())
    assert factor
    with exclusive('gpu'):
        with tempfile.TemporaryDirectory(prefix='selected-import-', dir=output) as folder:
            work = Path(folder)
            (work / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Blackbranch selected texture import"\n[rendering]\n' + key + '=' + factor[1] + '\n')
            original = {}
            options = {}
            for relative in paths:
                source = ROOT / relative
                original[relative] = hashlib.sha256(source.read_bytes()).hexdigest()
                target = work / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target)
                options[relative] = Path(str(source) + '.import').read_bytes()
                Path(str(target) + '.import').write_bytes(options[relative])
            env = dict(os.environ, APPDATA=str(work / 'profile'), XDG_DATA_HOME=str(work / 'profile'))
            with (output / 'selected-import.log').open('w', encoding='utf-8') as log:
                result = subprocess.run([a.godot, '--headless', '--path', str(work), '--editor', '--import', '--quit'], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180, creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
            text = (output / 'selected-import.log').read_text()
            assert result.returncode == 0 and not any('ERROR' in line and 'Failed to read the root certificate store.' not in line for line in text.splitlines()), text[-4000:]
            for relative in paths:
                assert hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() == original[relative]
                raw = Path(str(work / relative) + '.import').read_bytes()
                assert raw == options[relative], 'Existing import options must be byte-identical'
                cache = re.search(r'(?m)^path="res://([^"\n]+)"$', raw.decode())[1]
                assert re.fullmatch(r'\.godot/imported/' + re.escape(UID) + r'\.png-[0-9a-f]+\.ctex', cache)
                for name in [cache, cache[:-5] + '.md5']:
                    source, destination = work / name, ROOT / name
                    assert source.is_file()
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    destination.write_bytes(source.read_bytes())
        print('BLACKBRANCH_FOCUSED_IMPORT_OK: 2 textures; unchanged options and source hashes', flush=True)
        command = [sys.executable, '-B', str(ROOT / 'tools/review_upgraded_creature_completion.py'), '--godot', a.godot, '--unit', UID, '--action', 'strike', '--output', str(output / 'normal')]
        return subprocess.call(command)

if __name__ == '__main__':
    raise SystemExit(main())
