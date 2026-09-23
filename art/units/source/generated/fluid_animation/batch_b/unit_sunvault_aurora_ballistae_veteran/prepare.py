"""Alpha-only extraction and rigid source-scale normalization; never paints poses."""
from pathlib import Path
from PIL import Image
from collections import deque
import hashlib, json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]

def extract(stem,rows,scale,count=8):
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
    main=sorted(groups,key=len,reverse=True)[:count]
    main.sort(key=lambda g:(int(sum(n//w for n in g)/len(g)/(h/rows)),sum(n%w for n in g)/len(g)))
    assert all(len(g)>10000 for g in main),(stem,[len(g) for g in main])
    centers=[(sum(n%w for n in g)/len(g),sum(n//w for n in g)/len(g)) for g in main]
    assigned=[[] for _ in main]
    for g in groups:
        cx=sum(n%w for n in g)/len(g);cy=sum(n//w for n in g)/len(g)
        i=min(range(count),key=lambda i:(cx-centers[i][0])**2+(cy-centers[i][1])**2)
        if stem=='ranged_v1' and 348<cx<490 and 625<cy<670 and len(g)<4000: i=4
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
for stem,rows,scale,count,parts in [
 ('idle_v1',4,.52,8,[('idle',0,8,135,True)]),
 ('move_v1',4,.54,8,[('move',0,8,110,True)]),
 ('attack_v1',4,.54,8,[('attack',0,8,95,False)]),
 ('cast_v1',4,.53,8,[('cast',0,8,110,False)]),
 ('hit_defend_v1',4,.52,8,[('hit',0,4,90,False),('defend',4,8,120,False)]),
 ('death_v1',4,.51,8,[('death',0,8,125,False)]),
]:
    fs=extract(stem,rows,scale,count)
    for name,start,end,msec,loop in parts:
        indices=clips.get(name,{}).get('indices',[])
        for f in fs[start:end]:
            f['clip']=name;indices.append(len(frames));frames.append(f)
        clips[name]={'indices':indices,'frame_msec':msec,'loop':loop,'static_frame':0}
        if name in ('attack','ranged'):clips[name]['contact_frame']=4
clips['dead']={'indices':[clips['death']['indices'][-1]],'frame_msec':125,'loop':False,'static_frame':0}
unit={'unit_id':'unit_sunvault_aurora_ballistae_veteran','reference_height':256,'source_facing':'right','frames':frames,'clips':clips,'accepted_clips':[],'preserve_clips':[],'source_scale_by_image':{f['source']:f['scale'] for f in frames},'source_scale_reason':'One rigid source-specific normalization matching roughly210px standing armored body; layout corrections changed source figure resolution. Never per-pose fit.','visual_review':{'status':'pending','notes':'Original dedicated crystalline construct actions. Full eight-frame walk requires native gait continuity review; core shell partly obscures hip joints. Physical salute, punch and continuous intact collapse.'}}
(HERE/'handoff.json').write_text(json.dumps({'schema_version':1,'units':[unit]},indent=2)+'\n',encoding='utf-8')
for p in HERE.glob('*.prompt.txt'):p.write_bytes(p.read_bytes().rstrip(b'\r\n'))
for meta in HERE.glob('*.generation.json'):
    d=json.loads(meta.read_text());stem=meta.name.removesuffix('.generation.json')
    d['source_sha256']=hashlib.sha256((HERE/(stem+'.png')).read_bytes()).hexdigest()
    d['prompt_sha256']=hashlib.sha256((HERE/(stem+'.prompt.txt')).read_bytes()).hexdigest()
    ref=Path(d['reference']);d['reference']=ref.relative_to(ROOT).as_posix() if ref.is_absolute() else ref.as_posix()
    meta.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
src=ROOT/'art/animation/source/poses/unit_sunvault_aurora_ballistae_veteran/unit_sunvault_aurora_ballistae_veteran_source-alpha.png'
(HERE/'identity_reference.recipe.json').write_text(json.dumps({'operation':'crop_only','source':src.relative_to(ROOT).as_posix(),'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'rect':[0,0,640,625],'output_sha256':hashlib.sha256((HERE/'identity_reference.png').read_bytes()).hexdigest()},indent=2)+'\n',encoding='utf-8')



