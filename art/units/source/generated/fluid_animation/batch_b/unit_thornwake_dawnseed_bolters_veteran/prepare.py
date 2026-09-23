"""Lossless component cutouts (except alpha <=8 noise) and review-only handoff."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image

D=Path(__file__).resolve().parent
ROOT=next(p for p in D.parents if (p/'project.godot').exists())
UID=D.name

def components(a, count):
    parents=[]; runs=[]; previous=[]
    def root(i):
        while parents[i]!=i:
            parents[i]=parents[parents[i]];i=parents[i]
        return i
    for y,row in enumerate(a>8):
        edges=np.diff(np.pad(row.astype(np.int8),(1,1)))
        current=[]
        for l,r in zip(np.flatnonzero(edges==1),np.flatnonzero(edges==-1)):
            i=len(parents);parents.append(i);runs.append((y,int(l),int(r),i));current.append((l,r,i))
            for pl,pr,pi in previous:
                if pr>=l and pl<=r: parents[root(i)]=root(pi)
        previous=current
    groups={}
    for y,l,r,i in runs:groups.setdefault(root(i),[]).append((y,l,r))
    groups=sorted(groups.values(),key=lambda rs:sum(r-l for y,l,r in rs),reverse=True)
    majors=groups[:count]
    if any(sum(r-l for y,l,r in rs)<3000 for rs in majors):raise ValueError('Eight full subjects required: '+str([sum(r-l for y,l,r in rs) for rs in groups[:12]]))
    def box(rs):return [min(l for y,l,r in rs),min(y for y,l,r in rs),max(r for y,l,r in rs),max(y for y,l,r in rs)+1]
    boxes=[box(rs) for rs in majors]
    # Detached authored seed/leaf pixels stay with the nearest full subject.
    for rs in groups[count:]:
        b=box(rs);cx=(b[0]+b[2])/2;cy=(b[1]+b[3])/2
        index=min(range(count),key=lambda i:max(boxes[i][0]-cx,0,cx-boxes[i][2])**2+max(boxes[i][1]-cy,0,cy-boxes[i][3])**2)
        majors[index].extend(rs)
    majors.sort(key=lambda rs:(round((box(rs)[1]+box(rs)[3])/2/380),box(rs)[0]))
    # Order by four pairs of vertical centers, then left/right within each pair.
    majors.sort(key=lambda rs:(box(rs)[1]+box(rs)[3])/2)
    ordered=[]
    for i in range(0,count,2):ordered.extend(sorted(majors[i:i+2],key=lambda rs:box(rs)[0]))
    return [(box(rs),rs) for rs in ordered]

SHEETS=['idle_v1','move_half_a_v2','move_half_b_v1','attack_v1','ranged_v1','hit_v1','defend_v1','death_v1','cast_v2','dead_v2']
frames=[];clips={}; extraction={}
for sheet in SHEETS:
    im=Image.open(D/(sheet+'.png')).convert('RGBA'); a=np.array(im.getchannel('A'))
    print('Extracting',sheet);parts=components(a,1 if sheet=='dead_v2' else 4 if sheet.startswith(('hit','defend','move_half')) else 8); extraction[sheet]=[]
    for i,(bbox,runs) in enumerate(parts):
        l,t,r,b=bbox; cut=im.crop(bbox); alpha=np.zeros((b-t,r-l),dtype=np.uint8)
        for y,x0,x1 in runs:alpha[y-t,x0-l:x1-l]=a[y,x0:x1]
        cut.putalpha(Image.fromarray(alpha)); filename=f'{sheet}_frame_{i:02}.png';cut.save(D/filename)
        extraction[sheet].append({'file':filename,'source_rect':bbox,'width':r-l,'height':b-t})
(D/'extraction.json').write_text(json.dumps(extraction,indent=2)+'\n')
print(json.dumps({s:[p['source_rect'] for p in ps] for s,ps in extraction.items()},indent=2))

# Anatomical anchors reviewed against planted roots or the airborne chest.
# Every image has ONE fixed scale; no frame-by-frame size normalization.
scales={s:0.65 for s in SHEETS};scales.update(hit_v1=0.445,defend_v1=0.405,death_v1=0.56,move_half_a_v2=0.55,move_half_b_v1=0.55,dead_v2=0.254)
base_x={'idle_v1':[245,740]*4,'move_half_a_v2':[375,1130,375,1140],'move_half_b_v1':[390,1150,405,1150],'attack_v1':[230,725]*4,
        'ranged_v1':[245,740]*4,'cast_v2':[250,735]*4,'death_v1':[250,750]*4,
        'hit_v1':[350,950,350,940],'defend_v1':[320,950,320,960],'dead_v2':[604]}
for sheet in SHEETS:
    clip=sheet.split('_')[0];start=len(frames)
    for i,p in enumerate(extraction[sheet]):
        l,t,r,b=p['source_rect'];ay=b-2
        frames.append(dict(name=f'{sheet}_{i:02}',clip=clip,source=(D/p['file']).relative_to(ROOT).as_posix(),
                           rects=[[0,0,p['width'],p['height']]],anchor=[base_x[sheet][i]-l,ay-t],scale=scales[sheet],
                           original_source=(D/(sheet+'.png')).relative_to(ROOT).as_posix(),source_rect=p['source_rect']))
    spec=dict(indices=list(range(start,len(frames))),frame_msec=125 if clip=='idle' else 100,loop=clip in ('idle','move'),static_frame=0)
    if clip in ('attack','ranged'):spec['contact_frame']=4
    if clip=='death':spec['static_frame']=7
    if clip=='defend':spec['static_frame']=3
    if clip in clips:clips[clip]['indices'].extend(spec['indices'])
    else:clips[clip]=spec
clips['death']['indices'][-1]=clips['dead']['indices'][0]
entry=dict(unit_id=UID,reference_height=256,source_facing='right',frames=frames,clips=clips,accepted_clips=[],preserve_clips=[],
           alpha_noise_cutoff=8,source_scale_by_image={f['source']:f['scale'] for f in frames},
           source_scale_reason='Eight-pose sources use 1024x1536 canvases; hit and defense use 1254px square masters with larger painted bodies, and death source has a taller standing figure. One fixed anatomical scale per source image preserves the existing approximately 233px tall standing body.',
           visual_review=dict(status='pending_coordinator_review',notes='Original articulated poses inspected as source sheets. Gait alternate-leg read remains ambiguous in the new four-pose halves and requires temporal review; earlier move sheets rejected for gait/spacing. Support uses two-handed salute after rejecting free-hand versions for missing weapon/extra hands. Runtime motion and cross-clip grounding require coordinator acceptance.'))
(D/'handoff.json').write_text(json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n')
outputs={'idle_v1':'8b862d93-02cf-439c-8aba-fe21d4ecd112','move_v1':'7f79820c-1ad2-4904-8653-be9474993392',
 'move_v2':'92be44c1-01c2-4b14-9b19-13a13521f85b','attack_v1':'aebaf0f9-bb4e-42e2-ae5b-f14de9259d46',
 'ranged_v1':'a72cd0c1-7f71-4636-87f5-cb3a32890a18','hit_v1':'ab6ac311-85f3-4275-87b8-270567e647a8',
 'defend_v1':'5014349a-a745-4a6e-ac6a-e82f6c3412a7','death_v1':'2538cd9d-8ca5-4d9a-820f-c680bff9510f',
 'cast_v1':'99090e85-0b6e-4bd7-9ea3-5f81b1a9085b','cast_bridge_v1':'301519b1-6087-46ae-812e-02c553eed36e',
 'cast_bridge_v2':'1498bb12-0bc5-49b8-9168-18bd0b716caf','cast_v2':'4bf8339d-b92f-464a-9e80-54d761417b98',
 'move_half_a_v1':'6e96bb68-6d63-48b3-ae1a-3ce29a6f10a5','move_half_a_v2':'db02a375-4da2-4d42-8198-262534cf4deb','move_half_b_v1':'0b33f0a7-29a7-4011-9cc3-f95275042977',
 'death_end_v1':'97b7cda6-a6ad-4f1f-b1fb-804bdfe07551','dead_v2':'6cbe53ed-23cb-4ad8-b7ab-2fbf3dc835a8'}
records=[]
for source,oid in outputs.items():
    prompt=D/(source+'.prompt.txt')
    raw=prompt.read_text().rstrip('\r\n')
    prompt.write_bytes(raw.encode('utf-8'))
    ref=f'art/animation/source/poses/{UID}/{UID}-alpha.png' if source=='idle_v1' else (D/({'move_v2':'move_v1.png','cast_bridge_v2':'cast_bridge_v1.png','move_half_a_v2':'move_half_a_v1.png','move_half_b_v1':'move_half_a_v2.png','death_end_v1':'death_v1.png','dead_v2':'death_v1.png'}.get(source,'idle_v1.png'))).relative_to(ROOT).as_posix()
    records.append(dict(source=source+'.png',source_sha256=hashlib.sha256((D/(source+'.png')).read_bytes()).hexdigest(),
                        prompt=prompt.name,prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest(),reference=ref,
                        reference_sha256=hashlib.sha256((ROOT/ref).read_bytes()).hexdigest(),
                        tool='builtin_image_gen',generated_output=f'C:/Users/acorp/.codex/generated_images/01a0cccd-6586-7c63-8ef7-909cdaa1f504/exec-{oid}.png',
                        status='rejected_retained_original' if source in ('move_v1','move_v2','move_half_a_v1','cast_v1','cast_bridge_v1','cast_bridge_v2','death_end_v1') else 'pending_visual_acceptance'))
(D/'provenance.json').write_text(json.dumps(dict(schema_version=1,unit_id=UID,generations=records,preparation='Original connected-component pixel extraction; alpha <=8 removed. No pose painting, warp, interpolation or per-frame scaling.'),indent=2)+'\n')
