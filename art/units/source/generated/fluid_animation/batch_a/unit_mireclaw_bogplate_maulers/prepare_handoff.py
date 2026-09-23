"""Rebuild source rectangle/anchor handoff; never paints or warps sprite pixels."""
from pathlib import Path
from collections import deque
from PIL import Image
import numpy as np
import json, hashlib
D=Path(__file__).resolve().parent
ROOT=next(p for p in D.parents if (p/'project.godot').exists())
uid=D.name
def components(path):
    a=np.asarray(Image.open(path).convert('RGBA'))[:,:,3]; mask=a>8; h,w=mask.shape
    seen=np.zeros_like(mask); found=[]
    for y,x in zip(*np.where(mask)):
        if seen[y,x]: continue
        q=deque([(int(x),int(y))]); seen[y,x]=True; pts=[]
        while q:
            xx,yy=q.popleft(); pts.append((xx,yy))
            for nx,ny in ((xx-1,yy),(xx+1,yy),(xx,yy-1),(xx,yy+1)):
                if 0<=nx<w and 0<=ny<h and mask[ny,nx] and not seen[ny,nx]:
                    seen[ny,nx]=True; q.append((nx,ny))
        if len(pts)>10000:
            xs,ys=zip(*pts); found.append((min(xs),min(ys),max(xs)+1,max(ys)+1,pts))
    return found,(w,h)
def rectangles(c):
    # Exact connected silhouette spans prevent neighbour-tail contamination where
    # the painter exceeded a nominal cell. Original RGBA pixels remain unchanged.
    rows={}
    for x,y in c[4]: rows.setdefault(y,[]).append(x)
    runs=[]
    for y,xs in sorted(rows.items()):
        xs.sort(); start=prev=xs[0]
        for x in xs[1:]:
            if x>prev+1: runs.append([start,y,prev+1,y+1]); start=x
            prev=x
        runs.append([start,y,prev+1,y+1])
    return runs
frames=[]; clips={}; scales={}; provenance=[]
for source,cols,rows,scale,names in [('move_v1',2,4,.65,['move']*8),('attack_v1',2,4,.65,['attack']*8),('reactions_v1',2,4,.65,['hit']*4+['defend']*4),('death_v2',2,4,.57,['death']*8),('cast_v1',2,4,.65,['cast']*8)]:
    path=D/(source+'.png'); cs,(w,h)=components(path)
    assert len(cs)==8,(source,len(cs))
    cs.sort(key=lambda c:(int((c[1]+c[3])/2/(h/rows)),c[0]))
    rel=path.relative_to(ROOT).as_posix(); scales[rel]=scale
    for i,(c,clip) in enumerate(zip(cs,names)):
        n=len(frames); indices=clips.setdefault(clip,{'indices':[],'frame_msec':120 if clip=='idle' else 90,'loop':clip in ['idle','move'],'static_frame':0})['indices']; indices.append(n)
        col=i%cols
        frames.append({'name':clip+'_'+str(len(indices)-1).zfill(2),'clip':clip,'source':rel,'rects':rectangles(c),'anchor':[round((col+.5)*w/cols),c[3]],'scale':scale})
    provenance.append({'source':rel,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'prompt':path.with_suffix('.prompt.txt').relative_to(ROOT).as_posix(),'prompt_sha256':hashlib.sha256(path.with_suffix('.prompt.txt').read_bytes()).hexdigest()})
clips['attack']['contact_frame']=4
clips['cast']['contact_frame']=4
clips['death']['frame_msec']=110
clips['defend']['static_frame']=3
clips['dead']={'indices':[clips['death']['indices'][-1]],'frame_msec':100,'loop':False,'static_frame':0}
unit={'unit_id':uid,'reference_height':256,'source_facing':'right','alpha_noise_cutoff':8,'frames':frames,'clips':clips,'accepted_clips':[],'preserve_clips':['idle'],'source_scale_by_image':scales,'source_scale_reason':'One fixed scale per original source; normal 350-pixel standing body at .65 matches inherited 227-pixel idle. Death standing figure painted at 398 pixels uses .57. No per-pose size normalization.','visual_review':{'status':'pending','notes':'Artist inspected 40 new poses and existing eight-pose idle: idle articulates both hands/arms in a gentle hammer adjustment and return with fixed feet, retained pending root motion review. Hammer two-handed strike, physical rally support, monotonic corpse collapse. Rejected death_v1 kneeling pose omitted hammer head; targeted image edit death_v2 restores it.'}}
(D/'handoff.json').write_text(json.dumps({'schema_version':1,'units':[unit]},indent=2)+'\n')
outputs=json.loads((D/'generation_outputs.json').read_text())
(D/'provenance.json').write_text(json.dumps({'unit_id':uid,'generator':'built_in_imagegen','reference':'art/units/source/curated/'+uid+'.png','reference_sha256':hashlib.sha256((ROOT/'art/units/source/curated'/ (uid+'.png')).read_bytes()).hexdigest(),'outputs':outputs,'sources':provenance,'rejected_sources':['death_v1.png'],'extraction':'Original alpha greater than 8 connected silhouette spans; no pixel repainting, deformations or pose duplication. Corpse uses final death pose.'},indent=2)+'\n')
print(uid,len(frames),{k:len(v['indices']) for k,v in clips.items()})
