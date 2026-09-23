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
      'move_v1': {'scale':.60, 'clips':['move']*8, 'anchors_x':[278,756,288,742,277,743,282,752]},
      'attack_v2': {'scale':.60, 'clips':['attack']*8, 'anchors_x':[260,752,278,772,300,773,265,766]},
      'hit_defend_v1': {'scale':.57, 'clips':['hit']*4+['defend']*4,'anchors_x':[280,777,280,760,285,741,276,748]},
      'death_v1': {'scale':.51, 'clips':['death']*8,'anchors_x':[277,789,283,782,265,763,266,770]},
      'cast_v1': {'scale':.60, 'clips':['cast']*8,'anchors_x':[260,770,268,763,265,777,265,771]},
    }
    outputs={
      'move_v1':'exec-2a7bea5c-b2ba-4d52-a643-1234483c9649.png',
      'attack_v1':'exec-a355da82-7aa8-47a2-a3ac-9c72f8992b9a.png',
      'attack_v2':'exec-b5f2ab68-ae0e-46f8-943d-3f00dcc8c7d5.png',
      'hit_defend_v1':'exec-ede5855d-db50-4b0b-85f0-bd3fdc815cd1.png',
      'death_v1':'exec-c25ddeb2-de7f-41bf-a0b7-e29df80b4e94.png',
      'cast_v1':'exec-d77415e8-1928-4452-b086-0f545dd2c3de.png',
    }
    frames=[];clips={}; lineage=[]
    ref=D/'identity_reference.png'
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
    clips['cast']['indices']=[32,33,34,35,36,37,38,39]
    clips['cast']['frame_msec']=110
    clips['dead']={'indices':[31],'frame_msec':1000,'loop':False,'static_frame':0}
    handoff={'schema_version':1,'units':[{'unit_id':'unit_thornwake_worldroot_bastion','reference_height':256,'source_facing':'right','frames':frames,'clips':clips,'accepted_clips':[],'preserve_clips':['idle'],'visual_review':{'status':'pending','artist_observation':'Existing idle inspected: eight articulated shield-arm poses with stable roots. New action draft pending coordinator review at game scale; movement half-cycle leg opposition needs closer review. Attack v1 rejected because striking arm identity switched at contact; v2 uses coherent root stomp. Live idle reference used because old curated portrait differs from current in-game construct silhouette. Support is physical open-arm protection, no added magic.'}}]}
    handoff['units'][0]['source_scale_by_image']={f['source']:f['scale'] for f in frames}
    handoff['units'][0]['source_scale_reason']='One fixed scale per whole source master shared by all eight poses: movement/attack/support .60, hit-defense .57, death .51. Source standing bodies measure roughly 350/370/415px respectively, matching the existing about 212px body at reference_height256. No per-pose sizing or warping; death collapse retains .51 all the way to corpse.'
    (D/'handoff.json').write_text(json.dumps(handoff,indent=2)+'\n')
    (D/'provenance.json').write_text(json.dumps({'schema_version':1,'unit_id':'unit_thornwake_worldroot_bastion','sources':lineage,'identity_reference_origin':{'source':'art/animation/runtime/poses/unit_thornwake_worldroot_bastion.png','frame_index':14,'processing':'Exact crop of first live idle pose; no painting or resizing.'},'rejected_sources':[{'master':'attack_v1.png','reason':'Shield-arm identity switches during contact; replaced with root-foot stomp.'}]},indent=2)+'\n')
    print('Wrote',len(frames),'original frames',list(clips))

if __name__ == '__main__':
    build()
