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
    'move': (.59, [0,384,765,1130,1536], [(300,378),(812,378),(300,757),(812,757),(300,1122),(812,1122),(300,1515),(812,1515)]),
    'attack': (.62, [0,390,774,1153,1536], [(255,366),(767,366),(255,757),(767,757),(255,1133),(767,1133),(255,1515),(767,1515)]),
    'ranged': (.59, [0,395,775,1145,1536], [(280,378),(792,378),(280,757),(792,757),(280,1130),(792,1130),(280,1515),(792,1515)]),
    'reactions': (.59, [0,385,742,1115,1536], [(280,375),(792,375),(280,737),(792,737),(280,1107),(792,1107),(280,1510),(792,1510)]),
    'death': (.46, [0,515,900,1230,1536], [(290,480),(802,480),(290,833),(802,833),(290,1158),(802,1158),(290,1490),(802,1490)]),
    'cast': (.59, [0,386,765,1146,1536], [(280,376),(792,376),(280,756),(792,756),(280,1138),(792,1138),(280,1515),(792,1515)]),
}
frames=[]
clips={}
scales={}
lineage=json.loads((HERE/'lineage.json').read_text())
for name,(scale,ys,anchors) in configs.items():
    source=f'{REL}/{name}_v1.png'
    scales[source]=scale
    im=Image.open(ROOT/source)
    assert im.mode=='RGBA' and im.size==(1024,1536), (name,im.mode,im.size)
    starts={}
    for i in range(8):
        clip=('defend' if i<4 else 'hit') if name=='reactions' else name
        starts.setdefault(clip,len(frames))
        row,col=divmod(i,2)
        rect=[col*512,ys[row],(col+1)*512,ys[row+1]]
        if name=='ranged' and i==4: rect[2]=608
        if name=='ranged' and i==5: rect[0]=608
        frames.append({'name':f'{clip}_{i%4 if name=="reactions" else i:02d}','clip':clip,'source':source,'rects':[rect],'anchor':list(anchors[i]),'scale':scale,'alpha_noise_cutoff':8})
    for clip,start in starts.items():
        count=4 if name=='reactions' else 8
        clips[clip]={'indices':list(range(start,start+count)),'loop':clip=='move','frame_msec':100 if clip not in ('death','cast') else 120,'static_frame':0}
        if clip in ('attack','ranged','cast'): clips[clip]['contact_frame']=4
        if clip=='ranged': clips[clip]['projectile_travel_msec']=180
        if clip=='death': clips['dead']={'indices':[start+7],'loop':False,'frame_msec':120,'static_frame':0}
    for key,file in [('source_sha256',HERE/f'{name}_v1.png'),('prompt_sha256',HERE/f'{name}_v1.prompt.txt')]:
        lineage[name][key]=hashlib.sha256(file.read_bytes()).hexdigest()
    lineage[name]['tool']='built-in image_gen'
    lineage[name]['prompt_file']=f'{REL}/{name}_v1.prompt.txt'
    lineage[name]['source_file']=source
    lineage[name]['reference_sha256']={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in lineage[name]['reference_paths']}
handoff={'schema_version':1,'units':[{'unit_id':UNIT,'reference_height':256,'source_facing':'right','frames':frames,'clips':clips,'source_scale_by_image':scales,'source_scale_reason':'Each image uses one fixed scale calibrated to the old approximately 220-pixel standing body. Death source is drawn larger; no frame-specific resizing. Anchors follow the same ground reference, preserving collapse rather than aligning heads.','preserve_clips':['idle'],'accepted_clips':[],'visual_review':{'status':'pending','notes':'Original eight idle poses inspected: arms check belt lantern and return, candidate retained. New original sources require coordinator motion review. Skate gait has distinct paintings but similar half cycles; verify actual alternating foot readability. Ranged release projectile lies outside nominal cell, explicitly included in source crop. Alpha <=8 is background noise only.'}}]}
(HERE/'handoff.json').write_text(json.dumps(handoff,indent=2)+'\n')
(HERE/'lineage.json').write_text(json.dumps(lineage,indent=2)+'\n')
print(f'{UNIT}: {len(frames)} source paintings; {list(clips)}; review pending')
