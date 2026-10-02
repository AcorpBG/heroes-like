"""Bounded native and reflected review of the complete original unit."""
import subprocess,sys
import produce as p
from creature_animation_lock import exclusive

if __name__=='__main__':
    out=p.ROOT/'.artifacts/parallel_animation_20261002/unit_neutral_quenchbell_ironbacks'
    godot='D:/Games/godot/Godot_v4.6.2-stable_win64_console.exe'
    with exclusive('gpu'):
        for script,name in [('run_native_review.py','candidate_native'),('run_mirrored_native.py','mirrored_native')]:
            subprocess.run([sys.executable,str(p.SOURCE_DIR/script),'--godot',godot,'--handoff',str(p.SOURCE_DIR/'handoff.json'),'--render','--output',str(out/name)],cwd=p.ROOT,check=True)
