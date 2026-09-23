"""Lossless component cutouts (except alpha <=8 noise) and review-only handoff."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image

D=Path(__file__).resolve().parent
ROOT=next(p for p in D.parents if (p/'project.godot').exists())
UID=D.name

def components(a, count, columns=2):
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
    for i in range(0,count,columns):ordered.extend(sorted(majors[i:i+columns],key=lambda rs:box(rs)[0]))
    return [(box(rs),rs) for rs in ordered]

SHEETS=['idle_v2','move_v1','attack_v1','ranged_v1','hit_v2','defend_v2','death_v1','cast_v3']
frames=[];clips={}; extraction={}
for sheet in SHEETS:
    im=Image.open(D/(sheet+'.png')).convert('RGBA'); a=np.array(im.getchannel('A'))
    print('Extracting',sheet);parts=components(a,4 if sheet.startswith(('hit','defend')) else 8,4 if sheet=='cast_v3' else 2); extraction[sheet]=[]
    for i,(bbox,runs) in enumerate(parts):
        l,t,r,b=bbox; cut=im.crop(bbox); alpha=np.zeros((b-t,r-l),dtype=np.uint8)
        for y,x0,x1 in runs:alpha[y-t,x0-l:x1-l]=a[y,x0:x1]
        cut.putalpha(Image.fromarray(alpha)); filename=f'{sheet}_frame_{i:02}.png';cut.save(D/filename)
        extraction[sheet].append({'file':filename,'source_rect':bbox,'width':r-l,'height':b-t})
(D/'extraction.json').write_text(json.dumps(extraction,indent=2)+'\n')
print(json.dumps({s:[p['source_rect'] for p in ps] for s,ps in extraction.items()},indent=2))

# Anatomical anchors reviewed against planted roots or the airborne chest.
# Every image has ONE fixed scale; no frame-by-frame size normalization.
scales={s:0.61 for s in SHEETS};scales.update(hit_v2=0.50,defend_v2=0.405,cast_v3=0.67)
base_x={'idle_v2':[275,788]*4,'move_v1':[280,790]*4,'attack_v1':[275,790]*4,
        'ranged_v1':[275,790]*4,'cast_v3':[225,670,1110,1555]*2,'death_v1':[280,790]*4,
        'hit_v2':[375,950,370,970],'defend_v2':[352,952,375,985]}
flight_y=[410,410,770,780,1140,1140,1530,1530]
for sheet in SHEETS:
    clip=sheet.split('_')[0];start=len(frames)
    for i,p in enumerate(extraction[sheet]):
        l,t,r,b=p['source_rect'];ay=flight_y[i] if clip=='move' else b-2
        frames.append(dict(name=f'{clip}_{i:02}',clip=clip,source=(D/p['file']).relative_to(ROOT).as_posix(),
                           rects=[[0,0,p['width'],p['height']]],anchor=[base_x[sheet][i]-l,ay-t],scale=scales[sheet],
                           original_source=(D/(sheet+'.png')).relative_to(ROOT).as_posix(),source_rect=p['source_rect']))
    spec=dict(indices=list(range(start,len(frames))),frame_msec=125 if clip=='idle' else 100,loop=clip in ('idle','move'),static_frame=0)
    if clip in ('attack','ranged'):spec['contact_frame']=4
    if clip=='death':spec['static_frame']=7
    if clip=='defend':spec['static_frame']=3
    clips[clip]=spec
clips['dead']=dict(indices=[clips['death']['indices'][-1]],frame_msec=100,loop=False,static_frame=0)
prior=json.loads((D/'handoff.json').read_text())['units'][0] if (D/'handoff.json').exists() else {}
entry=dict(unit_id=UID,reference_height=256,source_facing='right',frames=frames,clips=clips,accepted_clips=[c for c in prior.get('accepted_clips',[]) if c!='cast'],preserve_clips=[],
           alpha_noise_cutoff=8,source_scale_by_image={f['source']:f['scale'] for f in frames},
           source_scale_reason='Eight-pose sources use 1024x1536 canvases; hit and defense use 1254px square masters with larger painted bodies. One fixed anatomical scale per source image preserves the existing approximately 231px tall standing body.',
           visual_review=dict(status='pending_coordinator_review',notes='Original articulated poses inspected as source sheets. Runtime motion and cross-clip grounding require coordinator acceptance.'))
(D/'handoff.json').write_text(json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n')
outputs={'idle_v1':'f13f5329-78ff-4876-885f-4091313ec5f8','idle_v2':'476bc8ab-6938-4d97-a480-5be0c8e99a33',
 'move_v1':'32a4eec3-2484-4c91-8282-84c4caf40950','attack_v1':'96903ef2-1dba-482f-8c42-c961862ce47f',
 'ranged_v1':'5dfa149e-df52-4f57-adfc-6f52c733ff0a','reaction_v1':'4c8c2a46-8bc0-4860-b91e-a3c8a61814dc',
 'death_v1':'6dfe3ec5-eee0-4519-bfbb-c2756aa945fc','cast_v1':'0c20e685-8a48-486c-b22a-c0f6cea9e58a',
 'hit_v2':'771e0821-538d-472b-806e-830dbeb38aff','defend_v2':'1641e715-4fdc-40a1-a702-e6f1999a14da','cast_v2':'6f748bf8-8d91-4683-b2de-68a849c1bc2b','cast_v3':'5c2522b1-b85d-42b8-924f-4228d3a45619'}
records=[]
for source,oid in outputs.items():
    prompt=D/(source+'.prompt.txt')
    raw=prompt.read_text().rstrip('\r\n')
    # The first invocation used PowerShell Get-Content -Raw, whose stdout adds CRLF.
    if source=='idle_v1':raw+='\r\n'
    prompt.write_bytes(raw.encode('utf-8'))
    ref=f'art/animation/source/poses/{UID}/{UID}-alpha.png' if source=='idle_v1' else (D/('idle_v1.png' if source=='idle_v2' else 'cast_v2.png' if source=='cast_v3' else 'idle_v2.png')).relative_to(ROOT).as_posix()
    records.append(dict(source=source+'.png',source_sha256=hashlib.sha256((D/(source+'.png')).read_bytes()).hexdigest(),
                        prompt=prompt.name,prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest(),reference=ref,
                        reference_sha256=hashlib.sha256((ROOT/ref).read_bytes()).hexdigest(),
                        tool='builtin_image_gen',generated_output=f'C:/Users/acorp/.codex/generated_images/01a0cccd-6586-7c63-8ef7-909cdaa1f504/exec-{oid}.png',
                        status='rejected_spacing_or_anatomy_retained_original' if source in ('idle_v1','reaction_v1','cast_v1','cast_v2') else 'pending_visual_acceptance'))
(D/'provenance.json').write_text(json.dumps(dict(schema_version=1,unit_id=UID,generations=records,preparation='Original connected-component pixel extraction; alpha <=8 removed. No pose painting, warp, interpolation or per-frame scaling.'),indent=2)+'\n')
