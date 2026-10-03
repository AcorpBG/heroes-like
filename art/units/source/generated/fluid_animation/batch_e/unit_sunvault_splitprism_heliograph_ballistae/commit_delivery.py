"""Stage only this unit and exact HEAD-based planning/attribute edits; push main."""
import hashlib
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path
import produce as p
from creature_animation_lock import exclusive

UID=p.SOURCE_DIR.name
PROGRESS_ID='art-fluid-creature-animation-20260923'
NOTE=('COMPLETED 2026-10-03: all232 live creatures have accepted idle/move/attack/hit/defend/support/death and required ranged actions. '
      'Final Heliograph delivery262 new observed action poses plus eight exact240ms idle/map phases; four905-check candidate runs and919 live Windows checks, exact imported RGBA and2232 original lossless RGB frame checks pass. '
      'Original two-wheel H3 component rotation replaces rejected static rolling footage; fixed anatomical scales and measured axle registration, no synthetic rotation. '
      'Cliffhawk companion, Prism Adept and Shard Guard extraction repairs pushed; all workers stopped and no new targets/repeat roster audits. '
      'Gameplay/saves and other231 battle/map rows preserved; no full suite or Linux execution. ')
PARAGRAPH=('Closeout complete: all 232 creatures have accepted full animation sets. Heliograph Ballista movement and six other actions are integrated, '
           'with original idle/map pixels preserved; the confirmed Cliffhawk, Prism Adept and Shard Guard repairs are pushed. '
           'Original sources and rebuild recipes remain. All workers have stopped; do not restart broad roster audits or select new targets for this completed slice. '
           'Focused Windows rendering/import checks passed; no full suite or Linux run.\n')
ATTR=('\n# Preserve original Heliograph action pixels and hash-bound production recipes.\n'
      f'art/units/source/generated/fluid_animation/batch_e/{UID}/** -text\n'
      f'art/animation/source/fluid/{UID}/*.json -text\n')

def git(*args,input=None,env=None):
    r=subprocess.run(['git','-c','maintenance.auto=false','-c','gc.auto=0',*args],cwd=p.ROOT,input=input,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if r.stderr:print(r.stderr.decode(errors='replace').strip(),flush=True)
    r.check_returncode()
    return r.stdout

def existing_noreply_identity():
    for line in git('log','-20','--format=%cn%x09%ce').decode().splitlines():
        name,email=line.split('\t')
        if email.endswith('@users.noreply.github.com'):
            return dict(os.environ,GIT_AUTHOR_NAME=name,GIT_AUTHOR_EMAIL=email,
                        GIT_COMMITTER_NAME=name,GIT_COMMITTER_EMAIL=email)
    raise RuntimeError('No existing repository GitHub noreply identity; do not publish private email')

def progress(raw):
    text=raw.decode('utf-8')
    pattern=re.compile(r'\n    \{\n      "id": "'+re.escape(PROGRESS_ID)+r'".*?\n    \}',re.S)
    hits=list(pattern.finditer(text));assert len(hits)==1
    m=hits[0];entry=m.group()
    entry,n=re.subn(r'("status": ")(?:in_progress|completed)(")',r'\1completed\2',entry,count=1);assert n==1
    note=re.search(r'"notes": ("(?:\\.|[^"\\])*")',entry);assert note
    old=json.loads(note[1])
    if not old.startswith(NOTE):entry=entry[:note.start(1)]+json.dumps(NOTE+'| '+old,ensure_ascii=False)+entry[note.end(1):]
    result=(text[:m.start()]+entry+text[m.end():]).encode('utf-8');json.loads(result)
    return result

def plan(raw):
    text=raw.decode('utf-8');heading='### Fluid creature animation across the entire roster\n'
    assert text.count(heading)==1
    if 'Closeout sequencing: end broad repeat reviews' in text:
        text,n=re.subn(r'Closeout sequencing: end broad repeat reviews[^\n]+\n',PARAGRAPH,text,count=1);assert n==1
    elif PARAGRAPH not in text:text=text.replace(heading,heading+'\n'+PARAGRAPH)
    text,n=re.subn(r'(`'+PROGRESS_ID+r'` \()(?:in progress|completed)(\))',r'\1completed\2',text,count=1);assert n==1
    return text.encode('utf-8')

def stage_blob(path,raw):
    digest=git('hash-object','-w','--stdin',input=raw).decode().strip()
    git('update-index','--cacheinfo',f'100644,{digest},{path}')

def main():
    with exclusive('git'):
        lock=p.ROOT/'.git/index.lock'
        if lock.exists():
            # A zero-byte orphan predates this operation. Never promote a
            # lock into the real index or touch historical recovery backups.
            index=p.ROOT/'.git/index';before=p.sha(index)
            check=subprocess.run(['powershell','-NoProfile','-Command',
                "@(Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^git' }).Count"],
                stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True)
            assert check.stdout.decode().strip()=='0','An active Git process owns the lock'
            assert lock.stat().st_size==0 and p.sha(index)==before
            lock.unlink();assert p.sha(index)==before
            print('Removed verified zero-byte orphan index.lock; real index unchanged',flush=True)
        assert git('branch','--show-current').decode().strip()=='main'
        existing=[s for s in git('diff','--cached','--name-only','-z').decode().split('\0') if s]
        shared={'.gitattributes','PLAN.md','ops/progress.json','content/unit_animation_manifest.json','art/overworld/creature_idle.json'}
        for path in existing:
            assert path in shared or path.startswith(p.SOURCE_DIR.relative_to(p.ROOT).as_posix()+'/') or path.startswith(f'art/animation/source/fluid/{UID}/') or path in {f'art/animation/runtime/fluid/{UID}.png',f'art/overworld/runtime/creature_idle/{UID}.png'},('Preserve foreign staging',path)
        for path,expected in [('.gitattributes',git('show','HEAD:.gitattributes')+ATTR.encode()),
                              ('PLAN.md',plan(git('show','HEAD:PLAN.md'))),
                              ('ops/progress.json',progress(git('show','HEAD:ops/progress.json')))]:
            if path in existing:assert git('show',':'+path)==expected,('Shared staging ownership changed',path)
        git('fetch','origin','main')
        assert git('rev-parse','HEAD').strip()==git('rev-parse','origin/main').strip(),'Remote advance must be reconciled first'
        for path,key in [('content/unit_animation_manifest.json','items'),('art/overworld/creature_idle.json','units')]:
            head=json.loads(git('show','HEAD:'+path))[key];work=json.loads((p.ROOT/path).read_bytes())[key]
            if key=='items':assert [r for r in head if r['unit_id']!=UID]==[r for r in work if r['unit_id']!=UID]
            else:assert {k:v for k,v in head.items() if k!=UID}=={k:v for k,v in work.items() if k!=UID}
        allowed={'.py','.gd','.uid','.json','.txt','.png','.mp4','.mkv','.latent'}
        selected=[f for f in p.SOURCE_DIR.rglob('*') if f.is_file() and f.suffix in allowed and '__pycache__' not in f.parts]
        selected += [f for f in (p.ROOT/'art/animation/source/fluid'/UID).rglob('*') if f.is_file() and f.suffix in {'.png','.json'}]
        for relative in ['content/unit_animation_manifest.json','art/overworld/creature_idle.json',
                         f'art/animation/runtime/fluid/{UID}.png',
                         f'art/overworld/runtime/creature_idle/{UID}.png']:
            selected.append(p.ROOT/relative)
        paths=sorted({f.relative_to(p.ROOT).as_posix() for f in selected})
        staged_attrs=git('show','HEAD:.gitattributes')+ATTR.encode()
        # Preserve unrelated working planning/attribute changes; stage only our
        # narrowly transformed HEAD blobs for these shared files.
        assert ATTR.encode() in (p.ROOT/'.gitattributes').read_bytes()
        stage_blob('.gitattributes',staged_attrs)
        for path,change in [('PLAN.md',plan),('ops/progress.json',progress)]:
            work=p.ROOT/path;work.write_bytes(change(work.read_bytes()))
            stage_blob(path,change(git('show','HEAD:'+path)))
        with tempfile.TemporaryDirectory(prefix='heliograph-git-',dir=p.ROOT/'.artifacts') as temp:
            pathfile=Path(temp)/'paths';pathfile.write_bytes(b'\0'.join(s.encode() for s in paths)+b'\0')
            git('add','--pathspec-from-file='+str(pathfile),'--pathspec-file-nul')
        staged=git('diff','--cached','--name-only','-z').decode().split('\0');staged=[s for s in staged if s]
        assert set(staged)<=set(paths)|{'.gitattributes','PLAN.md','ops/progress.json'}
        # Hash-bound source bytes must survive checkout on both platforms.
        listing=git('ls-files','--stage','--',p.SOURCE_DIR.relative_to(p.ROOT).as_posix()).decode()
        for line in listing.splitlines():
            info,path=line.split('\t');expected=info.split()[1];raw=(p.ROOT/path).read_bytes()
            actual=hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest();assert actual==expected,path
        print('SCOPED_STAGED',len(staged),'files; raw source bytes verified; unrelated changes excluded',flush=True)
        print(git('diff','--cached','--stat').decode()[-1400:],flush=True)
        git('commit','-m','Complete Heliograph animations and close the full creature roster',env=existing_noreply_identity())
        commit=git('rev-parse','HEAD').decode().strip();print('COMMIT',commit,flush=True)
        # Child output remains visible during the potentially large source push.
        subprocess.run(['git','-c','maintenance.auto=false','-c','gc.auto=0','push','origin','HEAD:main'],cwd=p.ROOT,check=True)
        assert git('rev-parse','HEAD').strip()==git('rev-parse','origin/main').strip()
        assert not git('diff','--cached','--name-only').strip()
        print('PUSHED_MAIN',commit,flush=True)

if __name__=='__main__':main()
