"""Inspect alpha components; no artwork is synthesized by this recipe."""
from pathlib import Path
from collections import deque
import json
import hashlib
from PIL import Image
import numpy as np

D = Path(__file__).resolve().parent
ROOT = D.parents[6]

def components(path):
    im = Image.open(path).convert('RGBA')
    alpha = np.array(im.getchannel('A')) > 8
    h, w = alpha.shape
    found = []
    for y in range(h):
        for x in np.flatnonzero(alpha[y]):
            if not alpha[y, x]:
                continue
            q = deque([(int(x), y)])
            alpha[y, x] = False
            left = right = int(x)
            top = bottom = y
            count = 0
            pixels = []
            while q:
                px, py = q.popleft()
                count += 1
                pixels.append((px,py))
                left = min(left, px)
                right = max(right, px)
                top = min(top, py)
                bottom = max(bottom, py)
                for nx, ny in ((px-1,py),(px+1,py),(px,py-1),(px,py+1)):
                    if 0 <= nx < w and 0 <= ny < h and alpha[ny,nx]:
                        alpha[ny,nx] = False
                        q.append((nx,ny))
            if count > 100:
                found.append({'pixels':count,'rect':[left,top,right+1,bottom+1], 'points':pixels})
    return sorted(found, key=lambda r:r['rect'][1])

def build():
    spec = {
      'move_v1': {'scale':.56, 'clips':['move']*8, 'anchors_x':[242,725,239,725,243,730,244,730]},
      'attack_v1': {'scale':.56, 'clips':['attack']*8, 'anchors_x':[270,795,271,735,180,692,268,758]},
      'hit_defend_v1': {'scale':.56, 'clips':['hit']*4+['defend']*4,'anchors_x':[300,792,319,774,314,768,303,764]},
      'death_v1': {'scale':.49, 'clips':['death']*8,'anchors_x':[332,843,302,813,280,800,280,800], 'anchors_y':[440,440,826,838,1150,1150,1447,1440]},
      'cast_v1': {'scale':.58, 'clips':['cast']*8,'anchors_x':[312,780,312,780,311,784,311,789]},
    }
    outputs={
      'move_v1':'exec-2a397f6f-6f9e-4073-9c45-ecab6796e83e.png',
      'attack_v1':'exec-59deae66-f3bf-4ad7-a6dd-a3a9496df591.png',
      'hit_defend_v1':'exec-18a4c8dd-2eb4-4665-9fe8-0cff1e2c37a3.png',
      'death_v1':'exec-502cd263-9008-4ae6-8c2b-472ba80b4e3b.png',
      'cast_v1':'exec-a5706fa5-bf38-47f7-ac33-0b27512d8e66.png',
    }
    frames=[];clips={}; lineage=[]
    ref=ROOT/'art/units/source/curated/unit_thornwake_thornwhip_carriers.png'
    for stem, settings in spec.items():
        path=D/(stem+'.png'); source=Image.open(path).convert('RGBA')
        comps=[c for c in components(path) if c['pixels']>1000]
        assert len(comps)==8,(stem,len(comps))
        comps=sorted(comps,key=lambda c:c['rect'][1])
        comps=[c for row in range(4) for c in sorted(comps[row*2:row*2+2],key=lambda c:c['rect'][0])]
        for i,c in enumerate(comps):
            clip=settings['clips'][i]
            rect=c['rect'];l,t,r,b=rect
            crop=source.crop(rect)
            mask=Image.new('L',crop.size,0)
            mask_px=mask.load();a=source.getchannel('A')
            for x,y in c['points']:mask_px[x-l,y-t]=a.getpixel((x,y))
            crop.putalpha(mask)
            dest=D/(stem+'_'+str(i).zfill(2)+'.png');crop.save(dest)
            index=len(frames)
            anchor_y=settings.get('anchors_y',[None]*8)[i]
            frames.append({'name':clip+'_'+str(i).zfill(2),'clip':clip,'source':dest.relative_to(ROOT).as_posix(),'rects':[[0,0,crop.width,crop.height]],'anchor':[settings['anchors_x'][i]-l,(b-1 if anchor_y is None else anchor_y)-t],'scale':settings['scale'],'original_source':path.relative_to(ROOT).as_posix(),'original_rect':rect})
            clips.setdefault(clip,{'indices':[]})['indices'].append(index)
        prompt=D/(stem+'.prompt.txt');prompt.write_bytes(prompt.read_bytes().rstrip(b'\r\n'))
        lineage.append({'master':path.relative_to(ROOT).as_posix(),'master_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'prompt':prompt.relative_to(ROOT).as_posix(),'prompt_sha256':hashlib.sha256(prompt.read_bytes()).hexdigest(),'generation_output':'C:/Users/acorp/.codex/generated_images/01a0ccd0-7438-70d0-93ac-b743b9008386/'+outputs[stem],'reference':ref.relative_to(ROOT).as_posix(),'reference_sha256':hashlib.sha256(ref.read_bytes()).hexdigest(),'tool':'built-in image_gen','processing':'Extract original connected alpha component; discard alpha <= 8 background only. No synthesized/interpolated/warped poses.'})
    for clip, data in clips.items():
        data.update(frame_msec=100 if clip=='attack' else 110,loop=clip=='move',static_frame=3 if clip=='defend' else 0)
    clips['attack']['contact_frame']=4
    clips['death']['frame_msec']=120
    clips['cast']['indices']=[32,34,33,35,36,37,38,39]
    clips['cast']['frame_msec']=110
    clips['dead']={'indices':[31],'frame_msec':1000,'loop':False,'static_frame':0}
    handoff={'schema_version':1,'units':[{'unit_id':'unit_thornwake_thornwhip_carriers','reference_height':256,'source_facing':'right','frames':frames,'clips':clips,'accepted_clips':[],'preserve_clips':['idle'],'visual_review':{'status':'pending','artist_observation':'Existing idle inspected: eight articulated hand/whip-coil poses with stable planted feet. New actions pending coordinator review at game scale. Support order follows fist-to-heart then forward rally and recovery; no magic. Alpha extraction prevents overlapping whip bounding rectangles from including adjacent sprites.'}}]}
    handoff['units'][0]['source_scale_by_image']={f['source']:f['scale'] for f in frames}
    handoff['units'][0]['source_scale_reason']='Fixed scale for each complete generated master, shared by every original pose extracted from that master: move/attack/hit-defense .56, death .49, support .58. Masters painted the standing body at different pixel resolutions (about 360, 410, and 348 px); these constants retain the existing about 203 px anatomy at reference_height 256. No per-pose sizing, warping or normalization; all death poses retain the same .49 scale as standing death frame 1, so collapse changes height naturally.'
    (D/'handoff.json').write_text(json.dumps(handoff,indent=2)+'\n')
    (D/'provenance.json').write_text(json.dumps({'schema_version':1,'unit_id':'unit_thornwake_thornwhip_carriers','sources':lineage},indent=2)+'\n')
    print('Wrote',len(frames),'original frames',list(clips))

if __name__ == '__main__':
    build()
