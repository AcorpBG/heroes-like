"""Extract original painted components; never synthesize or distort poses."""
from pathlib import Path
from collections import deque
import json, hashlib
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in HERE.parents if (p/'project.godot').exists())

def components(path):
    im = Image.open(path).convert('RGBA')
    ink = np.array(im.getchannel('A')) > 8
    labels = np.zeros(ink.shape, dtype=np.int32)
    height, width = ink.shape
    found = []
    for y, x in zip(*np.nonzero(ink)):
        if labels[y,x]: continue
        number = len(found)+1
        q = deque([(int(x),int(y))]); labels[y,x]=number
        pixels = []
        while q:
            xx,yy = q.popleft(); pixels.append((xx,yy))
            for nx,ny in ((xx-1,yy),(xx+1,yy),(xx,yy-1),(xx,yy+1)):
                if 0 <= nx < width and 0 <= ny < height and ink[ny,nx] and not labels[ny,nx]:
                    labels[ny,nx]=number;q.append((nx,ny))
        xs,ys=zip(*pixels)
        found.append({'n':number,'size':len(pixels),'bbox':[min(xs),min(ys),max(xs)+1,max(ys)+1], 'center':[sum(xs)/len(xs),sum(ys)/len(ys)]})
    return im,labels,found

def safe_rects(labels,main,others):
    l,t,r,b=main['bbox']
    foreign=np.isin(labels,[o['n'] for o in others])
    rects=[];active={}
    for y in range(t,b):
        okay=~foreign[y,l:r]
        padded=np.pad(okay,(1,1),constant_values=False)
        edges=np.flatnonzero(padded[1:]!=padded[:-1])
        runs={(l+int(x),l+int(z)) for x,z in zip(edges[::2],edges[1::2])}
        for key in list(active):
            if key not in runs: rects.append(active.pop(key))
        for key in runs:
            if key in active:active[key][3]=y+1
            else:active[key]=[key[0],y,key[1],y+1]
    rects.extend(active.values())
    return rects

if __name__=='__main__':
    configs={
      'move':(.565,[226,696,1156,1633]*2,[407,406,405,406,821,822,818,825]),
      'ranged':(.625,[291,735]*4,[365,365,747,749,1135,1137,1509,1509]),
      'death':(.49,[280,780]*4,[472,472,873,885,1188,1186,1482,1481]),
      'attack':(.57,[282,770,290,775,280,770,288,778],[387,386,773,774,1147,1148,1527,1528]),
      'cast':(.61,[280,735]*4,[367,368,751,753,1143,1143,1522,1523]),
      'reactions':(.515,[318,737]*4,[414,414,835,837,1200,1200,1519,1519])}
    generation_ids={'move':'68ea6dd6-1fff-415c-8f64-037c19a00ba0','ranged':'b97b4fc3-d634-4d1f-ad01-6d3a88aad9e9','death':'79805af6-d7e9-4396-b74a-0e1a1bfc8aed','attack':'c7a9a2fa-bceb-46ad-b699-9348a906e306','cast':'240a1f4e-c3d8-410a-b48b-0afcc502e449','reactions':'a8452040-b525-4920-920f-d8640fc6e544'}
    generation_ids['move']='047e5798-cdd0-4bbb-a9ed-00d091917df6'
    frames=[];clips={};provenance=[]
    for kind,(scale,xs,ys) in configs.items():
        version='_v2' if kind=='move' else '_v1'
        path=HERE/(kind+version+'.png')
        im,labels,found=components(path)
        mains=[c for c in found if c['size']>10000]
        mains.sort(key=lambda c:(round(c['center'][1]/380),c['center'][0]))
        assert len(mains)==8,(kind,len(mains))
        # Sort pairs by vertical centroid, then left/right, including collapsed poses.
        mains.sort(key=lambda c:c['center'][1])
        columns=4 if kind=='move' else 2
        mains=[c for start in range(0,8,columns) for c in sorted(mains[start:start+columns],key=lambda c:c['center'][0])]
        start=len(frames)
        for i,main in enumerate(mains):
            clip=kind if kind!='reactions' else ('hit' if i<4 else 'defend')
            rects=safe_rects(labels,main,[o for o in mains if o!=main])
            frames.append({'name':f'{clip}_{i if kind!="reactions" else i%4:02d}','clip':clip,'source':path.relative_to(ROOT).as_posix(),'rects':rects,'anchor':[xs[i],ys[i]],'scale':scale})
        if kind=='reactions':
            clips['hit']={'indices':list(range(start,start+4)),'frame_msec':100,'loop':False,'static_frame':1}
            clips['defend']={'indices':list(range(start+4,start+8)),'frame_msec':100,'loop':False,'static_frame':3}
        else:
            clips[kind]={'indices':list(range(start,start+8)),'frame_msec':100 if kind!='death' else 120,'loop':kind=='move','static_frame':0}
            if kind in ('ranged','attack','cast'):clips[kind]['contact_frame']=5 if kind=='ranged' else 4
            if kind=='death':clips['dead']={'indices':[start+7],'frame_msec':120,'loop':False,'static_frame':0}
        prompt=HERE/(kind+version+'.prompt.txt')
        prompt.write_bytes(prompt.read_bytes().rstrip(b'\r\n'))
        sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
        provenance.append({'clip':kind,'tool':'built-in image_gen','prompt':prompt.relative_to(ROOT).as_posix(),'prompt_sha256':sha(prompt),'reference':'art/units/source/curated/unit_ember_archer.png','reference_sha256':sha(ROOT/'art/units/source/curated/unit_ember_archer.png'),'master':path.relative_to(ROOT).as_posix(),'master_sha256':sha(path),'generation_output':'C:/Users/acorp/.codex/generated_images/01a0ccce-2711-7133-9769-7d380293a5ac/exec-'+generation_ids[kind]+'.png'})
    handoff={'schema_version':1,'units':[{'unit_id':'unit_ember_archer','reference_height':256,'source_facing':'right','alpha_noise_cutoff':8,'frames':frames,'clips':clips,'accepted_clips':[],'preserve_clips':['idle'],'visual_review':{'status':'pending','artist_notes':'Existing eight-pose idle reviewed: bow-hand and elbow articulate through a coherent breathing/equipment loop. New originals have explicit gait, draw-release, physical salute, punch, hit/guard and grounded collapse. Isolated original connected components prevent close-gutter contamination. Coordinator motion/scale review required.'}}]}
    guide=HERE/'move_pose_reference.png'
    provenance[0]['pose_reference']=guide.relative_to(ROOT).as_posix()
    provenance[0]['pose_reference_sha256']=hashlib.sha256(guide.read_bytes()).hexdigest()
    provenance[0]['pose_reference_lineage']='Reviewed original Weirshield eight-pose contact/inbetween sequence composed by fluid_art_a; copied as durable image-generation pose input.'
    old=HERE/'move_v1.png';oldprompt=HERE/'move_v1.prompt.txt'
    provenance.append({'clip':'move_v1','tool':'built-in image_gen','status':'rejected_gait','reason':'same-leading-leg ambiguity through halves; replaced by newly painted skeleton-guided move_v2','master':old.relative_to(ROOT).as_posix(),'master_sha256':hashlib.sha256(old.read_bytes()).hexdigest(),'prompt':oldprompt.relative_to(ROOT).as_posix(),'prompt_sha256':hashlib.sha256(oldprompt.read_bytes()).hexdigest(),'generation_output':'C:/Users/acorp/.codex/generated_images/01a0ccce-2711-7133-9769-7d380293a5ac/exec-68ea6dd6-1fff-415c-8f64-037c19a00ba0.png','reference':'art/units/source/curated/unit_ember_archer.png'})
    handoff['units'][0]['visual_review']['artist_notes']+=' Move_v2 now follows the reviewed opposite-contact skeleton guide, newly painted with archer identity. Root approved retained idle and attack/hit/defend/death/cast and ranged art; corrected gait awaits root review. Ranged contact is zero-based frame5 at empty-bow release.'
    handoff['units'][0]['source_scale_by_image']={f['source']:f['scale'] for f in frames}
    handoff['units'][0]['source_scale_reason']='Each original sheet uses a different painted body height within its canvas. One fixed scale per entire original matches the existing 219-pixel upright anatomy; no frame-specific scaling. Death and crouched reaction poses retain their original collapse proportions.'
    (HERE/'handoff.json').write_text(json.dumps(handoff,indent=2)+'\n')
    (HERE/'provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
    print('Prepared',len(frames),'new original poses;',len(clips),'clips; idle retained pending review')
