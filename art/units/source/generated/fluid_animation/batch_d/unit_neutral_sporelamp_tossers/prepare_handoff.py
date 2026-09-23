"""Rebuild handoff rectangles and provenance from untouched generated masters."""
from pathlib import Path
from collections import deque
import hashlib, json
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
UID = HERE.name
GEN = 'C:/Users/acorp/.codex/generated_images/01a0ccd3-9789-78e2-b817-2ac75766ba4d/'
OUTPUTS = {
 'ranged_v1': 'exec-24488b91-5e81-4a78-ad15-c696e27bfb40.png',
 'move_v1_rejected': 'exec-5d0cfc1e-2f2e-4853-8b03-a1b0660426f0.png',
 'move_v2_rejected': 'exec-2f42e4b6-da35-413a-8570-326cfaf6ad5b.png',
 'attack_v1_rejected': 'exec-51fda14c-f3c5-471d-9275-ac385ae0c92c.png',
 'death_v1': 'exec-de4954e7-5faf-44a4-a7fa-a0e63527e6d7.png',
 'reactions_v1': 'exec-7b59d833-4898-4244-822a-b55bd5e8ac26.png',
 'cast_v1': 'exec-f4ec42e4-5e9a-4fe5-8a8f-9b1c93c044a6.png',
 'attack_v2': 'exec-42f66923-48b1-4baa-baa4-80020b112c3e.png',
 'move_v3_rejected': 'exec-ce9fd4a5-754c-4ce6-b47a-f7063634bd1b.png',
 'move_contacts_v1': 'exec-f18e22de-b608-4505-90c7-a3e09a43df2a.png',
 'move_inbetweens_v1': 'exec-2f06a65c-cbee-42f9-a3d2-3234a07d3c9b.png',
}

def components(image):
    mask=image.getchannel('A').point(lambda a:255 if a>8 else 0)
    w,h=mask.size; data=bytearray(mask.tobytes()); result=[]
    for start in range(len(data)):
        if not data[start]: continue
        queue=deque([start]);data[start]=0;count=0
        x0=x1=start%w;y0=y1=start//w
        while queue:
            i=queue.popleft();x=i%w;y=i//w;count+=1
            x0=min(x0,x);x1=max(x1,x);y0=min(y0,y);y1=max(y1,y)
            for j in ((i-1 if x else -1),(i+1 if x+1<w else -1),i-w,i+w):
                if 0<=j<len(data) and data[j]:data[j]=0;queue.append(j)
        if count>1000:result.append(([x0,y0,x1+1,y1+1],count,(start%w,start//w)))
    return result

def extract_component(image, seed_rect, exact_seed=None):
    """Retain exact connected cutout pixels, excluding neighboring poses."""
    w,h=image.size; alpha=image.getchannel('A'); data=alpha.load()
    x0,y0,x1,y1=seed_rect
    seed=exact_seed or next((x,y) for y in range(y0,y1) for x in range(x0,x1) if data[x,y]>8)
    queue=deque([seed]);seen={seed}
    while queue:
        x,y=queue.popleft()
        for nx,ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            if 0<=nx<w and 0<=ny<h and (nx,ny) not in seen and data[nx,ny]>8:
                seen.add((nx,ny));queue.append((nx,ny))
    return seen

SPECS={
 'move_contacts_v1': {'scale':0.245,'clips':['move']*2,'xs':[480,1370],'ys':[857,862]},
 'move_inbetweens_v1': {'scale':0.396,'columns':3,'clips':['move']*6,'xs':[282,771,1264,284,770,1265],'ys':[506,490,511,1011,1003,1010]},
 'ranged_v1': {'scale':0.586,'clips':['ranged']*8,'xs':[322,824,309,815,315,806,310,813],'ys':[347,350,688,690,1018,1018,1340,1340]},
 'attack_v2': {'scale':0.528,'clips':['attack']*8,'xs':[291,786,298,787,299,781,295,783],'ys':[374,380,754,759,1128,1128,1507,1509]},
 'cast_v1': {'scale':0.552,'clips':['cast']*8,'xs':[280,760,278,756,282,760,283,759],'ys':[370,374,734,737,1129,1120,1501,1501]},
 'death_v1': {'scale':0.477,'clips':['death']*8,'xs':[273,768,280,766,285,769,281,772],'ys':[460,467,860,858,1159,1147,1447,1450]},
 'reactions_v1': {'scale':0.53,'clips':['hit']*4+['defend']*4,'xs':[291,752,297,758,298,758,300,755],'ys':[380,378,762,772,1139,1137,1497,1498]},
}

def build():
    provenance={'schema_version':1,'tool':'built_in_image_gen','unit_id':UID,'reference':'art/units/source/curated/'+UID+'.png','generations':[],'extraction':[]}
    for name,output in OUTPUTS.items():
        prompt=HERE/(name.replace('_rejected','')+'.prompt.txt')
        # apply_patch added one terminal newline; tool received exact text without it.
        text=prompt.read_text(encoding='utf-8').rstrip('\n')
        prompt.write_bytes(text.encode('utf-8'))
        source=HERE/(name+'.png')
        provenance['generations'].append({'master':source.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'prompt':prompt.relative_to(ROOT).as_posix(),'prompt_sha256':hashlib.sha256(prompt.read_bytes()).hexdigest(),'generation_output':GEN+output,'reference':str(HERE/'move_v1_rejected.png') if name=='move_v2_rejected' else provenance['reference'],'status':'rejected' if 'rejected' in name else 'pending_visual_review','rejection_reason':('same lead leg repeats instead of alternating full gait' if name.startswith('move') else 'hand assignment changes during lamp swing') if 'rejected' in name else None})
    entry={'unit_id':UID,'reference_height':256,'source_facing':'right','alpha_noise_cutoff':8,'frames':[],'clips':{},'accepted_clips':[],'preserve_clips':['idle'],'source_scale_by_image':{},'source_scale_reason':'Original masters differ in anatomical drawing resolution. Each master uses one fixed scale matching the existing 197-pixel idle body height; per-frame extraction never rescales artwork.','visual_review':{'status':'pending','existing_idle':'Eight original poses inspected: coherent bottle/lamp arm movement with fixed ground; recommend retention, final review by coordinator.','unfinished':['move: three generated candidates rejected for repeated lead leg']}}
    prepared=HERE/'prepared';prepared.mkdir(exist_ok=True)
    for name,spec in SPECS.items():
        image=Image.open(HERE/(name+'.png')).convert('RGBA')
        cs=components(image);bodies=[x for x in cs if x[1]>10000]
        bodies.sort(key=lambda x:(round(x[0][1]/(image.height/4)),x[0][0]))
        assert len(bodies)==len(spec['clips']),(name,bodies)
        # Rows are determined by pairing sorted upper edges, then left-to-right.
        bodies.sort(key=lambda x:x[0][1])
        cols=spec.get('columns',2)
        bodies=[v for i in range(0,len(bodies),cols) for v in sorted(bodies[i:i+cols],key=lambda x:x[0][0])]
        for i,(box,count,seed) in enumerate(bodies):
            pixels=extract_component(image,box,seed)
            if name=='ranged_v1' and i==4:
                pixels.update(extract_component(image,[531,686,587,741]))
            left=min(x for x,y in pixels);top=min(y for x,y in pixels)
            right=max(x for x,y in pixels)+1;bottom=max(y for x,y in pixels)+1
            out=Image.new('RGBA',(right-left,bottom-top));src=image.load();dst=out.load()
            for x,y in pixels:dst[x-left,y-top]=src[x,y]
            target=prepared/(name+'_'+str(i).zfill(2)+'.png');out.save(target)
            rel=target.relative_to(ROOT).as_posix();clip=spec['clips'][i];index=len(entry['frames'])
            entry['frames'].append({'name':clip+'_'+str(i).zfill(2),'clip':clip,'source':rel,'rects':[[0,0,out.width,out.height]],'anchor':[spec['xs'][i]-left,spec['ys'][i]-top],'scale':spec['scale']})
            entry['source_scale_by_image'][rel]=spec['scale']
            entry['clips'].setdefault(clip,{'indices':[],'frame_msec':110 if clip in ['death','hit','defend'] else 100,'loop':False,'static_frame':0})['indices'].append(index)
            provenance['extraction'].append({'source':rel,'master':(HERE/(name+'.png')).relative_to(ROOT).as_posix(),'source_bounds':[left,top,right,bottom],'alpha_noise_cutoff':8,'method':'Exact connected foreground pixels; separate thrown flask retained on ranged contact. No repainting, warping or pose interpolation.','scale':spec['scale']})
    entry['clips']['attack']['contact_frame']=4
    if 'ranged' in entry['clips']: entry['clips']['ranged']['contact_frame']=4
    entry['clips']['defend']['static_frame']=3
    entry['clips']['dead']={'indices':[entry['clips']['death']['indices'][-1]],'frame_msec':110,'loop':False,'static_frame':0}
    if 'move_contacts_v1' in SPECS:
        indices=entry['clips']['move']['indices']
        entry['clips']['move']['indices']=[indices[i] for i in [0,2,3,4,1,5,6,7]]
        entry['clips']['move']['loop']=True
        entry['visual_review']['unfinished']=[]
        entry['visual_review']['movement']='Replaced failed text-only sheets with two opposite-foot contacts plus six newly painted inbetweens using accepted soldier gait as skeleton reference only; root review pending.'
        for generation in provenance['generations']:
            if generation['master'].endswith('move_contacts_v1.png'):
                generation['references']=['art/units/source/generated/fluid_animation/batch_a/unit_river_guard_veteran/move_contacts_v2.png',provenance['reference']]
            if generation['master'].endswith('move_inbetweens_v1.png'):
                generation['references']=['art/units/source/generated/fluid_animation/batch_a/unit_river_guard_veteran/move_inbetweens_v1.png',(HERE/'move_contacts_v1.png').relative_to(ROOT).as_posix()]
    (HERE/'handoff.json').write_text(json.dumps({'schema_version':1,'units':[entry]},indent=2)+'\n',encoding='utf-8')
    (HERE/'provenance.json').write_text(json.dumps(provenance,indent=2)+'\n',encoding='utf-8')

if __name__=='__main__':
    build()

# Replay visually reviewed body ownership and anatomical anchor corrections.
import sys as _crop_sys
from pathlib import Path as _CropPath
_crop_dir = _CropPath(__file__).resolve().parent
_crop_root = next(p for p in _crop_dir.parents if (p / "project.godot").exists())
_crop_sys.path.insert(0, str(_crop_root / "tools"))
from refine_fluid_frame_crops import apply_recipe as _apply_crop_recipe
_apply_crop_recipe(_crop_dir / "handoff.json", _crop_dir / "crop_refinements.json")
