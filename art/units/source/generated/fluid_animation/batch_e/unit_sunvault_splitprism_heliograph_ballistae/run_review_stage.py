"""Run only Heliograph's bounded offscreen native/action review stage."""
import argparse
import os
import subprocess
import sys
import produce as p
from creature_animation_lock import exclusive

GODOT = os.environ.get('GODOT_BIN', 'D:/Games/godot/Godot_v4.6.2-stable_win64_console.exe' if os.name == 'nt' else 'godot')
UID = p.SOURCE_DIR.name
OUT = p.ROOT/'.artifacts/parallel_animation_20261003'/UID


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('stage', choices=['candidate_pair', 'candidate_ranged', 'live_pair', 'live_ranged'])
    args = parser.parse_args()
    scripts = [('run_native_review.py', False), ('run_mirrored_native.py', False)] if args.stage.endswith('_pair') else [('run_ranged_native.py', False), ('run_ranged_native.py', True)]
    with exclusive('gpu'):
        for name, reflected in scripts:
            label = {'run_native_review.py': 'native', 'run_mirrored_native.py': 'mirrored', 'run_ranged_native.py': 'ranged'}[name]
            if reflected: label += '_reflected'
            source = ['--live'] if args.stage.startswith('live_') else ['--handoff', str(p.SOURCE_DIR/'handoff.json')]
            subprocess.run([sys.executable, str(p.SOURCE_DIR/name), '--godot', GODOT,
                            *source, '--unit', UID, '--render', '--overview-only',
                            '--output', str(OUT/(args.stage+'_'+label)), *(['--mirrored'] if reflected else [])], cwd=p.ROOT, check=True)
    print('BOUNDED_REVIEW_COMPLETED', args.stage, flush=True)
