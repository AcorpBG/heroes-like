"""Register original pose pixels with fixed source-level scaling only."""
import hashlib,json
from pathlib import Path
from PIL import Image
HERE=Path(__file__).resolve().parent
ROOT=next(p for p in HERE.parents if (p/'project.godot').exists())
extracted=json.loads((HERE/'extraction.json').read_text())
frames=[];clips={}

def add(clip,stem,selection,scale,duration,contact=None):
    indices=[]
    for i in selection:
        d=extracted[stem][i];l,t,r,b=d['box'];indices.append(len(frames))
        # Center of grounded torso, excluding wide antler tips and strike reach.
        anchor_x=(l+r)/2
        frames.append(dict(name=f'{clip}_{len(clips.get(clip,{}).get("indices",[]))+len(indices)-1}',clip=clip,
          source=(HERE/'extracted'/d['file']).relative_to(ROOT).as_posix(),
          rects=[[0,0,r-l,b-t]],anchor=[round(anchor_x-l),b-t-1],scale=scale,alpha_noise_cutoff=8))
    if clip in clips: clips[clip]['indices'].extend(indices)
    else: clips[clip]=dict(indices=indices,frame_msec=duration,loop=clip=='move',static_frame=0)
    if contact is not None:clips[clip]['contact_frame']=contact

add('move','move_v1',range(4),.53,115)
add('move','move_return_v1',range(4),.38,115)
add('attack','attack_v1',range(8),.55,105,4)
add('hit','reactions_v1',range(4),.53,105)
add('defend','reactions_v1',range(4,8),.53,125)
add('death','death_v1',range(8),.54,145)
clips['dead']=dict(indices=[clips['death']['indices'][-1]],frame_msec=150,loop=False,static_frame=0)
add('cast','cast_v3',range(8),.61,125,4)
unit=dict(unit_id='unit_neutral_ashcrown_kilnelk',reference_height=256,source_facing='right',frames=frames,clips=clips,
   accepted_clips=[],preserve_clips=['idle'],
   source_scale_by_image={f['source']:f['scale'] for f in frames},
   source_scale_reason='One fixed scale for each complete original sheet. 0.53 movement/reactions, 0.38 newly painted four-frame opposite-foreleg swing, 0.55 attack, 0.54 death and 0.61 portrait-layout physical bellow register the different source drawing resolutions to the existing roughly 225px standing height at reference height 256. Extraction changes alpha outside connected subjects only, never anatomy; no per-pose resizing.',
   visual_review=dict(status='pending',notes='Existing eight idle paintings visually reviewed: distinct tail sweep, neck/head breathing and ember mane changes with coherent planted limbs; retain candidate. New movement combines first four original far-foreleg phases with four newly painted near-foreleg swing phases. Motion/ground/contact review still required. Cast v1/v2 rejected for right border crowding; v3 portrait layout selected.'))
(HERE/'handoff.json').write_text(json.dumps(dict(schema_version=1,units=[unit]),indent=2)+'\n',encoding='utf-8')
for lineage in HERE.glob('*.lineage.json'):
    d=json.loads(lineage.read_text());png=lineage.with_name(lineage.name.replace('.lineage.json','.png'))
    d.update(prompt_sha256=hashlib.sha256((HERE/d['prompt_file']).read_bytes()).hexdigest(),image_sha256=hashlib.sha256(png.read_bytes()).hexdigest(),reference_sha256=hashlib.sha256((ROOT/d['reference']).read_bytes()).hexdigest(),review_status='pending')
    if lineage.name in ('cast_v1.lineage.json','cast_v2.lineage.json'):d['review_status']='rejected_border_crowding'
    lineage.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
preview=Image.new('RGBA',(2400,1560),(35,42,36,255))
for row,clip in enumerate(['move','attack','hit','defend','death','cast']):
    for col,index in enumerate(clips[clip]['indices']):
        f=frames[index];im=Image.open(ROOT/f['source']).convert('RGBA');s=f['scale'];im=im.resize((round(im.width*s),round(im.height*s)),Image.Resampling.LANCZOS)
        preview.alpha_composite(im,(col*300+150-round(f['anchor'][0]*s),row*260+240-round(f['anchor'][1]*s)))
preview.convert('RGB').save(HERE/'review_contact.jpg',quality=92)
print(len(frames),'new poses; old eight idle retained pending root acceptance')
