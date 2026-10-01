"""Preserve built-in image master and exact reference/prompt provenance."""
import argparse,hashlib,json,shutil
from pathlib import Path
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
OWN=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('name');a.add_argument('original',type=Path);a.add_argument('references',type=Path,nargs='+');args=a.parse_args()
 dest=OWN/(args.name+'.png');assert not dest.exists();shutil.copyfile(args.original,dest)
 prompt=OWN/(args.name+'.prompt.txt');assert prompt.exists()
 info=dict(tool='built-in image_gen',output_path=str(args.original).replace('\\','/'),image=dict(path=dest.relative_to(ROOT).as_posix(),sha256=sha(dest)),prompt=dict(path=prompt.relative_to(ROOT).as_posix(),sha256=sha(prompt)),references=[dict(path=p.resolve().relative_to(ROOT).as_posix(),sha256=sha(p)) for p in args.references],visual_review=dict(status='pending',rule='Reference-only master. Count four limb chains and paired horns, compare torso proportions, root registration and alpha before H3 use.'))
 (OWN/(args.name+'.generation.json')).write_text(json.dumps(info,indent=2)+'\n')
