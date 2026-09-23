"""Extract disconnected source sprites without painting or warping them."""
from pathlib import Path
from PIL import Image
from collections import deque
import json, hashlib

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
source = HERE / 'move_v3.png'
im = Image.open(source).convert('RGBA')
im.putalpha(im.getchannel('A').point(lambda a: 0 if a <= 4 else a))
w,h = im.size
a = bytearray(im.getchannel('A').tobytes())
groups=[]
for p in range(w*h):
    if not a[p]: continue
    a[p]=0
    q=deque([p]); pixels=[]
    while q:
        n=q.popleft(); pixels.append(n)
        x,y=n%w,n//w
        for k in ((n-1 if x else -1),(n+1 if x<w-1 else -1),(n-w if y else -1),(n+w if y<h-1 else -1)):
            if k>=0 and a[k]: a[k]=0; q.append(k)
    groups.append(pixels)
main=sorted(groups,key=len,reverse=True)[:8]
main.sort(key=lambda g:(int(sum(n//w for n in g)/len(g)/(h/2)),sum(n%w for n in g)/len(g)))
print('components',[(len(g),min(n%w for n in g),min(n//w for n in g),max(n%w for n in g),max(n//w for n in g)) for g in main])
assert all(len(g)>10000 for g in main)
centers=[(sum(n%w for n in g)/len(g),sum(n//w for n in g)/len(g)) for g in main]
assign=[[] for _ in main]
for g in groups:
    cx=sum(n%w for n in g)/len(g); cy=sum(n//w for n in g)/len(g)
    i=min(range(8),key=lambda i:(cx-centers[i][0])**2+(cy-centers[i][1])**2)
    assign[i].extend(g)
frames=[]
for i,g in enumerate(assign):
    mask=bytearray(w*h)
    for n in g: mask[n]=255
    out=Image.new('RGBA',im.size); out.paste(im,(0,0),Image.frombytes('L',im.size,bytes(mask)))
    box=out.getbbox(); out=out.crop(box); dest=HERE/f'move_v3_frame_{i:02d}.png'; out.save(dest)
    frames.append({'name':f'move_{i:02d}','clip':'move','source':dest.relative_to(ROOT).as_posix(),'rects':[[0,0,out.width,out.height]],'anchor':[out.width*0.46,out.height-3],'scale':0.78,'source_rect':list(box)})
unit={'unit_id':'unit_thornwake_barkmantle_rams_veteran','reference_height':256,'source_facing':'right','frames':frames,'clips':{'move':{'indices':list(range(8)),'frame_msec':115,'loop':True,'static_frame':0}},'accepted_clips':[],'preserve_clips':[],'visual_review':{'status':'pending','notes':'Third pilot improves all-leg articulation; root must review actual loop before acceptance. Extraction preserves disconnected alpha components and does not repaint.'}}
(HERE/'handoff.json').write_text(json.dumps({'schema_version':1,'units':[unit]},indent=2)+'\n',encoding='utf-8')
outputs=['exec-f1eaf00b-bd2d-44c3-ae92-699fa21039a0.png','exec-589d56ae-3891-4946-9b5b-fa729bfe29b2.png','exec-2717bdf7-9ee7-4349-a07d-d737c6cfc517.png']
for v,output in enumerate(outputs,1):
    p=HERE/f'move_v{v}.prompt.txt'; s=HERE/f'move_v{v}.png'
    d={'tool':'image_gen.imagegen','generation_output':'C:/Users/acorp/.codex/generated_images/01a0ccb1-b530-7752-a210-c4f820510fd7/'+output,'source_sha256':hashlib.sha256(s.read_bytes()).hexdigest(),'prompt_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'reference':'art/units/source/generated/town_upgrades/faction_thornwake/unit_thornwake_barkmantle_rams_veteran.png','status':'rejected' if v<3 else 'pending_motion_review'}
    (HERE/f'move_v{v}.generation.json').write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')


