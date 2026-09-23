"""Pack source metadata only; never paint or synthesize pose pixels."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[7]
HERE = Path(__file__).resolve().parent
REL = HERE.relative_to(ROOT).as_posix()
UNIT = HERE.name
configs = {
 'move':(.57,[0,386,768,1156,1536],[(288,378),(800,378),(288,758),(800,758),(288,1146),(800,1146),(288,1525),(800,1525)]),
 'attack':(.59,[0,387,777,1155,1536],[(260,379),(772,379),(260,766),(772,766),(260,1148),(772,1148),(260,1529),(772,1529)]),
 'ranged':(.58,[0,388,779,1135,1536],[(275,381),(787,381),(275,775),(787,775),(275,1145),(787,1145),(275,1518),(787,1518)]),
 'reactions':(.55,[0,400,753,1128,1536],[(325,393),(837,393),(325,745),(837,745),(325,1120),(837,1120),(325,1515),(837,1515)]),
 'death':(.46,[0,505,923,1220,1536],[(275,490),(787,490),(275,883),(787,883),(275,1174),(787,1174),(275,1465),(787,1465)]),
 'cast':(.6,[0,375,734,1151,1536],[(275,373),(787,373),(275,752),(787,752),(275,1138),(787,1138),(275,1525),(787,1525)]),
}
frames=[]
clips={}
scales={}
lineage=json.loads((HERE/'lineage.json').read_text())
for name,(scale,ys,anchors) in configs.items():
    version='v2' if name=='ranged' else 'v1'
    source=f'{REL}/{name}_{version}.png'
    scales[source]=scale
    im=Image.open(ROOT/source)
    assert im.mode=='RGBA' and im.size==(1024,1536), (name,im.mode,im.size)
    starts={}
    for i in range(8):
        clip=('defend' if i<4 else 'hit') if name=='reactions' else name
        starts.setdefault(clip,len(frames))
        row,col=divmod(i,2)
        rect=[col*512,ys[row],(col+1)*512,ys[row+1]]
        if name=='ranged' and i==4: rect[2]=544
        if name=='ranged' and i==5: rect[0]=544
        rects=[rect]
        if name=='cast':
            if i==2: rects=[[0,375,512,734],[0,734,300,760]]
            if i==3: rects=[[512,375,1024,760]]
            if i==4: rects=[[0,760,512,1151],[300,734,512,760]]
            if i==5: rects=[[512,760,1024,1151]]
        if name=='ranged':
            if i==4: rects=[[0,779,544,1120],[0,1120,220,1150],[390,1120,544,1150]]
            if i==5: rects=[[544,779,1024,1150]]
            if i==6: rects=[[220,1120,390,1150],[0,1150,512,1536]]
            if i==7: rects=[[512,1150,1024,1536]]
        frames.append({'name':f'{clip}_{i%4 if name=="reactions" else i:02d}','clip':clip,'source':source,'rects':rects,'anchor':list(anchors[i]),'scale':scale,'alpha_noise_cutoff':8})
    for clip,start in starts.items():
        count=4 if name=='reactions' else 8
        clips[clip]={'indices':list(range(start,start+count)),'loop':clip=='move','frame_msec':100 if clip not in ('death','cast') else 120,'static_frame':0}
        if clip in ('attack','ranged','cast'): clips[clip]['contact_frame']=4
        if clip=='ranged': clips[clip]['projectile_travel_msec']=180
        if clip=='death': clips['dead']={'indices':[start+7],'loop':False,'frame_msec':120,'static_frame':0}
    for key,file in [('source_sha256',HERE/f'{name}_{version}.png'),('prompt_sha256',HERE/f'{name}_{version}.prompt.txt')]:
        lineage[name][key]=hashlib.sha256(file.read_bytes()).hexdigest()
    lineage[name]['tool']='built-in image_gen'
    lineage[name]['prompt_file']=f'{REL}/{name}_{version}.prompt.txt'
    lineage[name]['source_file']=source
    lineage[name]['reference_sha256']={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in lineage[name]['reference_paths']}
handoff={'schema_version':1,'units':[{'unit_id':UNIT,'reference_height':256,'source_facing':'right','frames':frames,'clips':clips,'source_scale_by_image':scales,'source_scale_reason':'Each image uses one fixed scale calibrated to the old approximately 220-pixel standing body. Death source is drawn larger; no frame-specific resizing. Anchors follow the same ground reference, preserving collapse rather than aligning heads.','preserve_clips':['idle'],'accepted_clips':[],'visual_review':{'status':'pending','notes':'Existing eight-frame idle inspected: arms check hip pouch and return; candidate retained. New original sequences pending coordinator motion review. Ranged v2 fixes extra stone and attaches release cord to fingers; no flying stone baked in. Fixed image scales preserve old body volume. Death rotates onto opposite side during collapse.'}}]}
(HERE/'handoff.json').write_text(json.dumps(handoff,indent=2)+'\n')
(HERE/'lineage.json').write_text(json.dumps(lineage,indent=2)+'\n')
print(f'{UNIT}: {len(frames)} source paintings; {list(clips)}; review pending')
