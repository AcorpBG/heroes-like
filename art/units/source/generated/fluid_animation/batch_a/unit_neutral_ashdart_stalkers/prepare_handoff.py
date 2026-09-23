"""Original drawing extraction metadata; no procedural pose painting."""
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
        frames.append(dict(name=f'{clip}_{len(indices)-1}',clip=clip,
            source=(HERE/'extracted'/d['file']).relative_to(ROOT).as_posix(),
            rects=[[0,0,r-l,b-t]],anchor=[round((r-l)/2),b-t-1],scale=scale,alpha_noise_cutoff=8))
    clips[clip]=dict(indices=indices,frame_msec=duration,loop=False,static_frame=0)
    if contact is not None:clips[clip]['contact_frame']=contact
add('attack','attack_v1',range(8),.54,105,4)
add('hit','reactions_v1',range(4),.56,105)
add('defend','reactions_v1',range(4,8),.56,125)
add('death','death_v1',range(8),.45,145)
clips['dead']=dict(indices=[clips['death']['indices'][-1]],frame_msec=150,loop=False,static_frame=0)
add('cast','cast_v1',range(8),.56,125,4)
add('ranged','ranged_v1',range(8),.62,105,4)
unit=dict(unit_id='unit_neutral_ashdart_stalkers',reference_height=256,source_facing='right',frames=frames,clips=clips,
    accepted_clips=[],preserve_clips=['idle'],unfinished_clips=['move'],
    source_scale_by_image={f['source']:f['scale'] for f in frames},
    source_scale_reason='All poses from a given original master share its fixed scale: attack 0.54, reactions 0.56, death 0.45, cast 0.56, ranged 0.62. These register different source drawing sizes to the existing 203px standing silhouette within reference height 256. Exact connected-alpha extracts inherit master scale; no per-pose size changes or warping.',
    visual_review=dict(status='pending',notes='Existing eight idle paintings reviewed: distinct elbow/blowpipe adjustment, head turn and cape response, candidate to preserve. New six action clips need coordinator motion/registration approval. Movement candidates locally rejected: near leg repeatedly leads instead of reciprocal gait. Original failed masters retained.'))
(HERE/'handoff.json').write_text(json.dumps(dict(schema_version=1,units=[unit]),indent=2)+'\n',encoding='utf-8')
for lineage in HERE.glob('*.lineage.json'):
    d=json.loads(lineage.read_text());png=lineage.with_name(lineage.name.replace('.lineage.json','.png'))
    d.update(prompt_sha256=hashlib.sha256((HERE/d['prompt_file']).read_bytes()).hexdigest(),image_sha256=hashlib.sha256(png.read_bytes()).hexdigest(),reference_sha256=hashlib.sha256((ROOT/d['reference']).read_bytes()).hexdigest(),review_status='rejected_nonreciprocal_gait' if lineage.name.startswith(('move','reverse')) else 'pending')
    lineage.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
preview=Image.new('RGBA',(2400,1560),(35,42,36,255))
for row,clip in enumerate(['attack','hit','defend','death','cast','ranged']):
    for col,index in enumerate(clips[clip]['indices']):
        f=frames[index];im=Image.open(ROOT/f['source']).convert('RGBA');s=f['scale'];im=im.resize((round(im.width*s),round(im.height*s)),Image.Resampling.LANCZOS)
        preview.alpha_composite(im,(col*300+150-round(f['anchor'][0]*s),row*260+240-round(f['anchor'][1]*s)))
preview.convert('RGB').save(HERE/'review_contact.jpg',quality=92)
print(len(frames),'new poses; movement still unfinished')

# Replay visually reviewed body ownership and anatomical anchor corrections.
import sys as _crop_sys
from pathlib import Path as _CropPath
_crop_dir = _CropPath(__file__).resolve().parent
_crop_root = next(p for p in _crop_dir.parents if (p / "project.godot").exists())
_crop_sys.path.insert(0, str(_crop_root / "tools"))
from refine_fluid_frame_crops import apply_recipe as _apply_crop_recipe
_apply_crop_recipe(_crop_dir / "handoff.json", _crop_dir / "crop_refinements.json")
