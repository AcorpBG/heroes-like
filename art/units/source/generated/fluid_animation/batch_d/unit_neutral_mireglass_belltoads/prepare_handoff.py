"""Pack source metadata only; never paint or synthesize pose pixels."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[7]
HERE = Path(__file__).resolve().parent
REL = HERE.relative_to(ROOT).as_posix()
UNIT = HERE.name
configs={
 'idle':(.62,[0,444,887],[(220,365),(664,365),(1108,365),(1552,365),(220,780),(664,780),(1108,780),(1552,780)]),
 'move':(.62,[0,444,887],[(220,390),(664,390),(1108,390),(1552,390),(220,790),(664,790),(1108,790),(1552,790)]),
 'attack':(.53,[0,512,1024],[(192,470),(576,470),(960,470),(1344,470),(192,898),(576,898),(960,898),(1344,898)]),
 'ranged':(.55,[0,444,887],[(220,397),(664,397),(1108,397),(1552,397),(220,800),(664,800),(1108,800),(1552,800)]),
 'reactions':(.62,[0,444,887],[(220,382),(664,382),(1108,382),(1552,382),(220,790),(664,790),(1108,790),(1552,790)]),
 'death':(.53,[0,444,887],[(220,420),(664,420),(1108,420),(1552,420),(220,802),(664,802),(1108,802),(1552,802)]),
 'cast':(.54,[0,512,1024],[(192,470),(576,470),(960,470),(1344,470),(192,955),(576,955),(960,955),(1344,955)]),
}
frames=[]
clips={}
scales={}
lineage=json.loads((HERE/'lineage.json').read_text())
for name,(scale,ys,anchors) in configs.items():
    version='v1' if name in ('attack','cast') else 'v2'
    source=f'{REL}/{name}_{version}.png'
    scales[source]=scale
    im=Image.open(ROOT/source)
    assert im.mode=='RGBA', (name,im.mode,im.size)
    xs=[round(im.width*i/4) for i in range(5)]
    starts={}
    for i in range(8):
        clip=('defend' if i<4 else 'hit') if name=='reactions' else name
        starts.setdefault(clip,len(frames))
        row,col=divmod(i,4)
        rect=[xs[col],ys[row],xs[col+1],ys[row+1]]
        if name=='move' and i==4: rect[2]=474
        if name=='move' and i==5: rect[0]=474
        frames.append({'name':f'{clip}_{i%4 if name=="reactions" else i:02d}','clip':clip,'source':source,'rects':[rect],'anchor':list(anchors[i]),'scale':scale,'alpha_noise_cutoff':8})
    for clip,start in starts.items():
        count=4 if name=='reactions' else 8
        clips[clip]={'indices':list(range(start,start+count)),'loop':clip in ('idle','move'),'frame_msec':100 if clip not in ('death','cast') else 120,'static_frame':0}
        if clip in ('attack','ranged','cast'): clips[clip]['contact_frame']=4
        if clip=='ranged': clips[clip]['projectile_travel_msec']=180
        if clip=='death': clips['dead']={'indices':[start+7],'loop':False,'frame_msec':120,'static_frame':0}
    for key,file in [('source_sha256',HERE/f'{name}_{version}.png'),('prompt_sha256',HERE/f'{name}_{version}.prompt.txt')]:
        lineage[name][key]=hashlib.sha256(file.read_bytes()).hexdigest()
    lineage[name]['tool']='built-in image_gen'
    lineage[name]['prompt_file']=f'{REL}/{name}_{version}.prompt.txt'
    lineage[name]['source_file']=source
    lineage[name]['reference_sha256']={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in lineage[name]['reference_paths']}
clips['defend']['indices']=[32,35,33,34]
clips['idle']['frame_msec']=180
handoff={'schema_version':1,'units':[{'unit_id':UNIT,'reference_height':256,'source_facing':'right','frames':frames,'clips':clips,'source_scale_by_image':scales,'source_scale_reason':'Each image uses one fixed scale calibrated to the old approximately 200-pixel wide frog body. Death source is drawn larger; no frame-specific resizing. Anchors follow the same ground reference, preserving collapse rather than aligning heads.','preserve_clips':[],'accepted_clips':[],'visual_review':{'status':'pending','notes':'All clips replaced including idle. V2 framing repair preserves distinct eight phase poses but safely insets toe tips. Reaction defense reordered to end in low brace. Compare body volume against existing frog art; fixed source scales calibrated to approximately 200px body width, not humanoid height. No detached projectile drawn.'}}]}
from extraction_components import components
for clip in ('attack','cast'):
    parts=components(HERE/f'{clip}_v1.png')
    assert len(parts)==8
    for frame,part in zip([f for f in frames if f['clip']==clip],parts):
        rects=[]
        for y,(left,right) in sorted(part['rows'].items()):
            if rects and rects[-1][0]==left and rects[-1][2]==right and rects[-1][3]==y:rects[-1][3]=y+1
            else:rects.append([left,y,right,y+1])
        frame['rects']=rects
(HERE/'handoff.json').write_text(json.dumps(handoff,indent=2)+'\n')
(HERE/'lineage.json').write_text(json.dumps(lineage,indent=2)+'\n')
print(f'{UNIT}: {len(frames)} source paintings; {list(clips)}; review pending')
