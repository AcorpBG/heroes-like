"""Alpha-only extraction and rigid source-scale normalization; never paints poses."""
from pathlib import Path
from PIL import Image
from collections import deque
import hashlib, json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]

def extract(stem,rows,scale):
    im=Image.open(HERE/(stem+'.png')).convert('RGBA')
    im.putalpha(im.getchannel('A').point(lambda a:0 if a<=4 else a))
    w,h=im.size; a=bytearray(im.getchannel('A').tobytes()); groups=[]
    for p in range(w*h):
        if not a[p]: continue
        a[p]=0; q=deque([p]); g=[]
        while q:
            n=q.popleft();g.append(n);x,y=n%w,n//w
            for k in (n-1 if x else -1,n+1 if x<w-1 else -1,n-w if y else -1,n+w if y<h-1 else -1):
                if k>=0 and a[k]:a[k]=0;q.append(k)
        groups.append(g)
    main=sorted(groups,key=len,reverse=True)[:8]
    main.sort(key=lambda g:(int(sum(n//w for n in g)/len(g)/(h/rows)),sum(n%w for n in g)/len(g)))
    assert all(len(g)>10000 for g in main),(stem,[len(g) for g in main])
    centers=[(sum(n%w for n in g)/len(g),sum(n//w for n in g)/len(g)) for g in main]
    assigned=[[] for _ in main]
    for g in groups:
        cx=sum(n%w for n in g)/len(g);cy=sum(n//w for n in g)/len(g)
        i=min(range(8),key=lambda i:(cx-centers[i][0])**2+(cy-centers[i][1])**2)
        assigned[i].extend(g)
    frames=[]
    for i,g in enumerate(assigned):
        mask=bytearray(w*h)
        for n in g:mask[n]=255
        out=Image.new('RGBA',im.size);out.paste(im,(0,0),Image.frombytes('L',im.size,bytes(mask)))
        box=out.getbbox();out=out.crop(box)
        dest=HERE/f'{stem}_frame_{i:02d}.png';out.save(dest)
        frames.append({'name':f'{stem}_{i:02d}','source':dest.relative_to(ROOT).as_posix(),'rects':[[0,0,out.width,out.height]],'anchor':[out.width*.46,out.height-3],'scale':scale,'source_rect':list(box)})
    print(stem,[(f['rects'][0][2],f['rects'][0][3]) for f in frames])
    return frames

frames=[];clips={}
for stem,rows,scale,parts in [
    ('move_v3',2,.78,[('move',0,8,115,True)]),
    ('idle_v2',4,.67,[('idle',0,8,135,True)]),
    ('attack_v2',4,.70,[('attack',0,8,95,False)]),
    ('hit_defend_v1',4,.67,[('hit',0,4,90,False),('defend',4,8,120,False)]),
    ('death_v1',4,.67,[('death',0,8,125,False)]),
    ('cast_v2',4,.80,[('cast',0,8,115,False)]),
]:
    fs=extract(stem,rows,scale)
    for name,start,end,msec,loop in parts:
        indices=[]
        for f in fs[start:end]:
            f['clip']=name;indices.append(len(frames));frames.append(f)
        clips[name]={'indices':indices,'frame_msec':msec,'loop':loop,'static_frame':0}
        if name=='attack':clips[name]['contact_frame']=4
clips['dead']={'indices':[clips['death']['indices'][-1]],'frame_msec':125,'loop':False,'static_frame':0}
unit={'unit_id':'unit_thornwake_barkmantle_rams_veteran','reference_height':256,'source_facing':'right','frames':frames,'clips':clips,'accepted_clips':['move'],'preserve_clips':[],'visual_review':{'status':'partial','notes':'Root accepted move_v3 after engine review. Remaining five clips pending root motion review. Each source sheet uses fixed rigid scale to match approved body size; no per-pose scaling or warping. All source alpha<=4 discarded only to remove invisible edge/background RGB.'}}
unit['source_scale_by_image']={f['source']:f['scale'] for f in frames}
unit['source_scale_reason']='Different generated sheet resolutions require one rigid normalization factor per sheet to match approved movement body size. Every pose extracted from a given sheet uses identical scale; no per-pose fitting, warping or length-dependent resizing.'
(HERE/'handoff.json').write_text(json.dumps({'schema_version':1,'units':[unit]},indent=2)+'\n',encoding='utf-8')
records={
'cast_v2':('exec-000ce8eb-01be-4e33-a3c0-356e0cbda89d.png','cast_v1.png','pending_motion_review'),
'cast_v1':('exec-078882df-5334-4446-a41d-c3387fe4bb15.png','identity_reference.png','pending_motion_review'),
'move_v4':('exec-ef48295e-6bd9-4996-ad1d-6e9d8c08ce9a.png','move_v3.png','unused_edge_retry'),
'idle_v1':('exec-fbdf19d9-4937-4bc3-af2d-fbd11eb1cae9.png',None,'rejected_clipped_silhouette'),
'idle_v2':('exec-7e3038d4-72bc-4c57-9ab7-d9f1d9870e4b.png','identity_reference.png','pending_motion_review'),
'attack_v1':('exec-e121fe62-8803-4aef-94f6-40105ff64be4.png','identity_reference.png','rejected_clipped_horn'),
'attack_v2':('exec-71a79abe-a03f-4105-9f1a-3ab2a5e00614.png','attack_v1.png','pending_motion_review'),
'hit_defend_v1':('exec-2a76de6f-4dc4-4e19-83d1-5b4a7ac2f5fd.png','identity_reference.png','pending_motion_review'),
'death_v1':('exec-0da4dbcc-6d7c-4034-8a09-c37989f52886.png','identity_reference.png','pending_motion_review'),
}
for stem,(output,ref,status) in records.items():
    prompt=HERE/(stem+'.prompt.txt');prompt.write_bytes(prompt.read_bytes().rstrip(b'\r\n'))
    source=HERE/(stem+'.png')
    reference=(HERE/ref).relative_to(ROOT).as_posix() if ref else 'art/units/source/generated/town_upgrades/faction_thornwake/unit_thornwake_barkmantle_rams_veteran.png'
    d={'tool':'image_gen.imagegen','generation_output':'C:/Users/acorp/.codex/generated_images/01a0ccb1-b530-7752-a210-c4f820510fd7/'+output,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'prompt_sha256':hashlib.sha256(prompt.read_bytes()).hexdigest(),'reference':reference,'status':status}
    (HERE/(stem+'.generation.json')).write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')


