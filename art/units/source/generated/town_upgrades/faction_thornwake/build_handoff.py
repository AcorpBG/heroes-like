"""Measure transparent source sheets and publish articulated-pose integration handoff."""
from pathlib import Path
import json
import hashlib
from PIL import Image

ROOT = Path(__file__).resolve().parents[6]
HERE = Path(__file__).resolve().parent

def gap_split(values):
    lo, hi = int(len(values)*.34), int(len(values)*.67)
    runs=[]
    start=None
    for i in range(lo,hi):
        if values[i] == 0 and start is None: start=i
        if values[i] != 0 and start is not None:
            runs.append((start,i)); start=None
    if start is not None: runs.append((start,hi))
    if not runs: raise ValueError('No transparent gutter')
    a,b=max(runs,key=lambda r:r[1]-r[0])
    return (a+b)//2

def action_rects(alpha):
    w,h=alpha.size
    try:
        sy=gap_split([alpha.crop((0,y,w,y+1)).getbbox() is not None for y in range(h)])
        rects=[]
        for top,bottom in [(0,sy),(sy,h)]:
            sx=gap_split([alpha.crop((x,top,x+1,bottom)).getbbox() is not None for x in range(w)])
            rects.extend([(0,top,sx,bottom),(sx,top,w,bottom)])
        return rects
    except ValueError:
        sx=gap_split([alpha.crop((x,0,x+1,h)).getbbox() is not None for x in range(w)])
        columns=[]
        for left,right in [(0,sx),(sx,w)]:
            sy=gap_split([alpha.crop((left,y,right,y+1)).getbbox() is not None for y in range(h)])
            columns.append([(left,0,right,sy),(left,sy,right,h)])
        return [columns[0][0],columns[1][0],columns[0][1],columns[1][1]]

units=[]
for path in sorted(HERE.glob('*_veteran.png')):
    im=Image.open(path)
    if im.mode!='RGBA' or im.getextrema()[3][0]!=0:
        print('SKIP opaque',path.name); continue
    alpha=im.getchannel('A').point(lambda v:255 if v>8 else 0)
    w,h=im.size
    row=[alpha.crop((0,y,w,y+1)).getbbox() is not None for y in range(h)]
    try: sy=gap_split(row)
    except ValueError:
        print('SKIP row gutter',path.name);continue
    frames=[]
    for top,bottom in [(0,sy),(sy,h)]:
        col=[alpha.crop((x,top,x+1,bottom)).getbbox() is not None for x in range(w)]
        try: sx=gap_split(col)
        except ValueError:
            print('SKIP col gutter',path.name);break
        for left,right in [(0,sx),(sx,w)]:
            box=alpha.crop((left,top,right,bottom)).getbbox()
            if box is None: raise ValueError(path)
            a,b,c,d=box; a+=left;c+=left;b+=top;d+=top
            foot_top=int(d-(d-b)*.10)
            feet=alpha.crop((a,foot_top,c,d)).getbbox()
            anchor=[round(a+(feet[0]+feet[2])/2,1),d-1]
            frames.append({'rects':[[left,top,right,bottom]],'anchor':anchor})
    if len(frames)!=4: continue
    units.append({'unit_id':path.stem,'source':path.relative_to(ROOT).as_posix(),'frames':frames,'alpha_noise_cutoff':8,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
for unit in units:
    path=HERE/(unit['unit_id']+'_actions.png')
    if not path.exists(): continue
    im=Image.open(path)
    if im.mode!='RGBA' or im.getextrema()[3][0]!=0:
        print('SKIP opaque action',path.name);continue
    alpha=im.getchannel('A').point(lambda v:255 if v>8 else 0)
    w,h=im.size
    try: rects=action_rects(alpha)
    except ValueError:
        print('SKIP action row gutter',path.name);continue
    frames=[]
    for left,top,right,bottom in rects:
        a,b,c,d=alpha.crop((left,top,right,bottom)).getbbox()
        a+=left;c+=left;b+=top;d+=top
        feet=alpha.crop((a,int(d-(d-b)*.10),c,d)).getbbox()
        anchor=[round(a+(feet[0]+feet[2])/2,1),d-1]
        frames.append({'source':path.relative_to(ROOT).as_posix(),'rects':[[left,top,right,bottom]],'anchor':anchor})
    if len(frames)!=4: continue
    for frame,(clip,name) in zip(frames,[('attack','attack_windup'),('attack','attack_release'),('hit','hit_recoil'),('dead','fallen')]):
        frame.update(clip=clip,name=name)
    # Authored anatomical contacts: fallen weapons extend below some bodies.
    contacts=json.loads((HERE/'action_ground_contacts.json').read_text()) if (HERE/'action_ground_contacts.json').exists() else {}
    for frame in frames:
        authored=contacts.get(unit['unit_id'],{}).get(frame['name'])
        if authored: frame['anchor']=authored
    unit['actions']=frames
out=ROOT/'.artifacts/thorn_upgrade_art_20260923/handoff.json'
out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps({'faction_id':'faction_thornwake','units':units},indent=2)+'\n',encoding='utf-8')
print('handoff units',len(units),'frames',sum(len(u['frames']) for u in units))
print('action sets',sum('actions' in u for u in units))
