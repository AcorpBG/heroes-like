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
    'move': (.64, [0,333,667,999,1330], [(335,330),(867,330),(335,664),(867,664),(335,996),(867,996),(335,1326),(867,1326)]),
    'attack': (.59, [0,385,775,1156,1536], [(260,376),(772,376),(260,760),(772,760),(260,1142),(772,1142),(260,1522),(772,1522)]),
    'reactions': (.58, [0,388,748,1123,1536], [(277,378),(789,378),(277,737),(789,737),(277,1112),(789,1112),(277,1504),(789,1504)]),
    'death': (.46, [0,515,904,1235,1536], [(285,475),(797,475),(285,880),(797,880),(285,1204),(797,1204),(285,1480),(797,1480)]),
    'cast': (.61, [0,378,762,1185,1536], [(315,373),(827,373),(315,753),(827,753),(315,1180),(827,1180),(315,1528),(827,1528)]),
}
frames=[]
clips={}
scales={}
lineage=json.loads((HERE/'lineage.json').read_text())
for name,(scale,ys,anchors) in configs.items():
    version = 'v3' if name=='attack' else 'v1'
    source=f'{REL}/{name}_{version}.png'
    scales[source]=scale
    im=Image.open(ROOT/source)
    assert im.mode=='RGBA', (name,im.mode,im.size)
    split=591 if name=='move' else 512
    starts={}
    for i in range(8):
        clip=('defend' if i<4 else 'hit') if name=='reactions' else name
        starts.setdefault(clip,len(frames))
        row,col=divmod(i,2)
        rect=[col*split,ys[row],(col+1)*split,ys[row+1]]
        if name=='ranged' and i==4: rect[2]=608
        if name=='ranged' and i==5: rect[0]=608
        frames.append({'name':f'{clip}_{i%4 if name=="reactions" else i:02d}','clip':clip,'source':source,'rects':[rect],'anchor':list(anchors[i]),'scale':scale,'alpha_noise_cutoff':8})
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
clips['attack']['indices']=[8+i for i in [0,2,4,3,1,6,5,7]]
handoff={'schema_version':1,'units':[{'unit_id':UNIT,'reference_height':256,'source_facing':'right','frames':frames,'clips':clips,'source_scale_by_image':scales,'source_scale_reason':'Each image uses one fixed scale calibrated to the old approximately 220-pixel standing body. Death source is drawn larger; no frame-specific resizing. Anchors follow the same ground reference, preserving collapse rather than aligning heads.','preserve_clips':['idle'],'accepted_clips':[],'visual_review':{'status':'pending','notes':'Existing idle inspected: spear arm raises across torso then returns and shield settles. Candidate retained. Attack v1/v2 rejected for reversing spear; v3 reordered into anticipation/contact/recovery. Body scale and temporal continuity pending coordinator review.'}}]}
(HERE/'handoff.json').write_text(json.dumps(handoff,indent=2)+'\n')
(HERE/'lineage.json').write_text(json.dumps(lineage,indent=2)+'\n')
print(f'{UNIT}: {len(frames)} source paintings; {list(clips)}; review pending')
