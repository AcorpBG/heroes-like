"""Pack source rectangles and authored grounding metadata; never paint or warp poses."""
import hashlib
import json
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in HERE.parents if (p / 'project.godot').exists())
unit = 'unit_mireclaw_sporewake_chanters'
frames, clips = [], {}

def add(clip, stem, rects, anchors, scale, duration, contact=None):
    indices = []
    for i, (rect, anchor) in enumerate(zip(rects, anchors)):
        indices.append(len(frames))
        frames.append(dict(name=f'{clip}_{i}', clip=clip,
            source=(HERE / (stem + '.png')).relative_to(ROOT).as_posix(),
            rects=[rect], anchor=anchor, scale=scale, alpha_noise_cutoff=8))
    clips[clip] = dict(indices=indices, frame_msec=duration,
                       loop=clip in ('idle', 'move'), static_frame=0)
    if contact is not None:
        clips[clip]['contact_frame'] = contact

def grid(width=1024, height=1536):
    return [[round(c*width/2), round(r*height/4), round((c+1)*width/2), round((r+1)*height/4)] for r in range(4) for c in range(2)]

add('idle', 'idle_v1', grid(), [[310,378],[812,378],[310,762],[812,762],[310,1146],[812,1146],[310,1530],[812,1530]], .60, 135)
attack_rects=grid()
attack_rects[4]=[0,768,589,1113]
attack_rects[5]=[589,768,1024,1113]
attack_rects[6]=[0,1080,512,1536]
attack_rects[7]=[512,1080,1024,1536]
add('attack','attack_v1',attack_rects,[[300,378],[780,378],[300,762],[785,762],[225,1104],[785,1104],[300,1494],[780,1494]],.60,105,4)
reaction_rects=grid()
reaction_rects[2]=[0,350,512,768]
reaction_rects[3]=[512,350,1024,768]
reaction_rects[6]=[0,1120,555,1536]
reaction_rects[7]=[555,1120,1024,1536]
add('hit','reactions_v1',reaction_rects[:4],[[320,376],[790,376],[320,762],[790,762]],.60,105)
add('defend','reactions_v1',reaction_rects[4:],[[310,1142],[790,1142],[280,1520],[790,1520]],.60,120)
add('death','death_v1',[[0,0,512,474],[512,0,1024,478],[0,453,512,872],[512,480,1024,900],[0,921,512,1160],[512,978,1024,1160],[0,1286,512,1448],[512,1280,1024,1448]],[[310,468],[812,468],[310,858],[812,868],[310,1142],[812,1142],[310,1438],[812,1438]],.495,145)
clips['dead']=dict(indices=[clips['death']['indices'][-1]],frame_msec=150,loop=False,static_frame=0)
add('cast','cast_v1',grid(),[[300,344],[785,344],[300,731],[785,731],[300,1100],[785,1100],[300,1483],[785,1483]],.69,125,4)
ranged_rects=grid(1122,1402)
ranged_rects[4][2]=625
ranged_rects[5][0]=625
add('ranged','ranged_v1',ranged_rects,[[310,360],[855,360],[310,712],[855,712],[310,1059],[855,1059],[310,1400],[855,1400]],.64,110,4)

# Original paintings crowd row gutters. Keep disjoint source rectangles rather
# than cutting tips or importing pixels belonging to a neighbouring painting.
by_name={f['name']:f for f in frames}
by_name['attack_4']['rects']=[[0,768,589,1080],[0,1080,145,1113],[265,1080,589,1113]]
by_name['attack_6']['rects']=[[145,1080,265,1113],[0,1113,512,1536]]
by_name['death_0']['rects']=[[0,0,512,453],[230,453,512,474]]
by_name['death_2']['rects']=[[0,453,230,478],[0,478,512,872]]

# Exact connected alpha extraction prevents neighbouring sheets' tiny foot or
# antler fragments entering rectangular atlas cells. Source masters stay intact.
extracted=json.loads((HERE/'extraction.json').read_text(encoding='utf-8'))
for frame in frames:
    source_stem=Path(frame['source']).stem
    local=int(frame['name'].rsplit('_',1)[1])+(4 if frame['clip']=='defend' else 0)
    extraction=extracted[source_stem][local]
    l,t,r,b=extraction['box']
    frame['anchor']=[frame['anchor'][0]-l,b-t-1]
    frame['source']=(HERE/'extracted'/extraction['file']).relative_to(ROOT).as_posix()
    frame['rects']=[[0,0,r-l,b-t]]

# Rebuildable inspection output only: exact rectangular extraction and alpha
# noise removal; no generated-pose deformation or painted pixels.
preview=Image.new('RGBA',(8*300,7*260),(35,42,36,255))
for row,clip in enumerate(['idle','attack','hit','defend','death','cast','ranged']):
    for col,index in enumerate(clips[clip]['indices']):
        frame=frames[index]
        im=Image.open(ROOT/frame['source']).convert('RGBA')
        l=min(r[0] for r in frame['rects']); t=min(r[1] for r in frame['rects'])
        r=max(r[2] for r in frame['rects']); b=max(r[3] for r in frame['rects'])
        cut=Image.new('RGBA',(r-l,b-t))
        for x0,y0,x1,y1 in frame['rects']:
            piece=im.crop((x0,y0,x1,y1))
            piece.putalpha(piece.getchannel('A').point(lambda a:0 if a<=8 else a))
            cut.alpha_composite(piece,(x0-l,y0-t))
        scale=frame['scale']; cut=cut.resize((round(cut.width*scale),round(cut.height*scale)),Image.Resampling.LANCZOS)
        preview.alpha_composite(cut,(col*300+150-round((frame['anchor'][0]-l)*scale),row*260+240-round((frame['anchor'][1]-t)*scale)))
preview.convert('RGB').save(HERE/'review_contact.jpg',quality=92)

handoff=dict(schema_version=1,units=[dict(unit_id=unit,reference_height=256,
    source_facing='right',frames=frames,clips=clips,accepted_clips=[],preserve_clips=[],
    source_scale_by_image={frame['source']:frame['scale'] for frame in frames},
    source_scale_reason='Each master has one fixed drawing scale across all its poses. Idle/attack/reactions use 0.60, death 0.495, cast 0.69 and ranged 0.64 to register their differently sized painted figures to the original approximately 226-pixel standing silhouette at reference height 256. Derived extracted images copy unchanged source pixels, so inherit exactly their master scale. No per-pose body normalization or deformation is performed.',
    visual_review=dict(status='pending',notes='Candidate original source poses; coordinator motion and scale review required. Movement v1/v2 rejected locally: reciprocal leg phase remains insufficient. Do not merge as complete unit.'),
    unfinished_clips=['move'])])
(HERE/'handoff.json').write_text(json.dumps(handoff,indent=2)+'\n',encoding='utf-8')
for source in HERE.glob('*.lineage.json'):
    entry=json.loads(source.read_text(encoding='utf-8'))
    prompt=HERE/entry['prompt_file']
    png=source.with_name(source.name.replace('.lineage.json','.png'))
    entry['prompt_sha256']=hashlib.sha256(prompt.read_bytes()).hexdigest()
    entry['image_sha256']=hashlib.sha256(png.read_bytes()).hexdigest()
    entry['reference_sha256']=hashlib.sha256((ROOT/entry['reference']).read_bytes()).hexdigest()
    entry['review_status']='rejected_gait' if source.stem.startswith('move_') else 'pending'
    source.write_text(json.dumps(entry,indent=2)+'\n',encoding='utf-8')
print(f'{len(frames)} painted poses; {list(clips)}; move remains unresolved')
