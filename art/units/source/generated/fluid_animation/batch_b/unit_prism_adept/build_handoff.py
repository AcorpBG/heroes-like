"""Rebuild source-only animation handoff; no shared catalog writes."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[7]
HERE = Path(__file__).resolve().parent
REL = HERE.relative_to(ROOT).as_posix()
generated = 'C:/Users/acorp/.codex/generated_images/01a0cccf-7af7-75c2-ae2f-73ff433f51e8/'
lineage = {
 'move_v1':'exec-9ce790c1-6050-41f1-83ff-26d25af417ba.png',
 'attack_v1':'exec-8c5ad9fd-7ff0-4f5b-9aaf-8728a3872e97.png',
 'ranged_v1':'exec-df9c3c7c-10ba-4166-8133-bbe18531d028.png',
 'cast_v1':'exec-668bce11-4b43-4385-bb77-6ba33d3b5cec.png',
 'cast_v2':'exec-a23d013f-44f6-4d33-becb-b1807f5a368d.png',
 'cast_v3':'exec-66333421-beb1-4b85-9716-535ef004c1e8.png',
 'reactions_v1':'exec-6992ad63-e24d-4127-8f6b-538d32e38db5.png',
 'death_v1':'exec-4c284717-1066-4297-ac34-c4c71555597a.png',
 'death_v2':'exec-95079e2e-af8a-493e-b062-f53d489471f2.png',
}
reference='art/units/source/curated/unit_prism_adept.png'
frames=[]
clips={}
scales={}

def sheet(name, clip, rows, xs, ground, scale=.6, count=8, first=0):
    source=f'{REL}/{name}.png'
    scales[source]=scale
    im=Image.open(HERE/f'{name}.png').convert('RGBA')
    start=len(frames)
    for i in range(first,first+count):
        col=i%2; row=i//2
        # Sheet-specific gutters; keep the attack's extended weapon intact.
        split=570 if name=='attack_v1' and row==2 else 560 if name=='reactions_v1' else im.width//2
        box=(0 if col==0 else split,rows[row],split if col==0 else im.width,rows[row+1])
        alpha=im.crop(box).getchannel('A').point(lambda a:255 if a>8 else 0)
        b=alpha.getbbox()
        if not b: raise ValueError((name,i,'empty'))
        rect=[box[0]+b[0],box[1]+b[1],box[0]+b[2],box[1]+b[3]]
        frames.append(dict(name=f'{clip}_{i-first:02}',clip=clip,source=source,rects=[rect],anchor=[xs[i],ground[i]],scale=scale))
    clips[clip]=dict(indices=list(range(start,len(frames))),frame_msec=100,loop=clip=='move',static_frame=0)

sheet('move_v1','move',[0,383,768,1148,1536],[300,765,300,767,300,765,300,765],[378,378,760,760,1141,1141,1528,1528])
sheet('attack_v1','attack',[0,391,776,1133,1536],[285,785,285,785,260,780,289,789],[380,378,766,766,1130,1133,1516,1516])
clips['attack']['contact_frame']=4
clips['attack']['frame_msec']=95
sheet('ranged_v1','ranged',[0,391,774,1143,1536],[285,765,283,765,269,765,283,765],[386,386,769,769,1140,1140,1524,1524])
clips['ranged']['contact_frame']=4
clips['ranged']['frame_msec']=95
sheet('cast_v3','cast',[0,388,773,1135,1536],[295,770,295,770,303,770,295,770],[382,382,759,759,1133,1133,1518,1518])
sheet('reactions_v1','hit',[0,402,799,1168,1536],[319,774,319,774,319,774,319,774],[399,399,797,797,1166,1166,1517,1517],scale=.58,count=4)
sheet('reactions_v1','defend',[0,402,799,1168,1536],[319,774,319,774,304,781,296,778],[399,399,797,797,1166,1166,1517,1517],scale=.58,count=4,first=4)
clips['defend']['static_frame']=3
# The first death master clipped the hood: use generated repair only for frame 1.
death_start=len(frames)
im=Image.open(HERE/'death_v2.png')
frames.append(dict(name='death_00',clip='death',source=f'{REL}/death_v2.png',rects=[[60,45,535,481]],anchor=[286,464],scale=.54))
scales[f'{REL}/death_v2.png']=.54
death_rects=[[635,30,1175,410],[60,430,590,775],[610,470,1224,785],[20,785,605,1060],[625,855,1210,1070],[10,1090,605,1285],[615,1090,1224,1285]]
death_anchors=[[913,399],[317,755],[922,755],[320,1020],[941,1020],[314,1236],[921,1236]]
for i,(rect,anchor) in enumerate(zip(death_rects,death_anchors),1):
    frames.append(dict(name=f'death_{i:02}',clip='death',source=f'{REL}/death_v1.png',rects=[rect],anchor=anchor,scale=.50))
scales[f'{REL}/death_v1.png']=.50
clips['death']=dict(indices=list(range(death_start,len(frames))),frame_msec=130,loop=False,static_frame=7)
clips['dead']=dict(indices=[len(frames)-1],frame_msec=100,loop=False,static_frame=0)
entry=dict(unit_id='unit_prism_adept',reference_height=256,source_facing='right',alpha_noise_cutoff=8,frames=frames,clips=clips,preserve_clips=['idle'],accepted_clips=[],source_scale_by_image=scales,source_scale_reason='Common regular-sheet anatomy is 370px high versus existing 223px idle. Reaction sheet uses slightly larger armor volume. Death masters depict crouched/collapsed anatomy at higher drawing resolution; repaired source 2 is independently calibrated once for the whole image.',visual_review=dict(status='pending',notes=['Existing eight idle paintings reviewed: arms lift crossbow gradually then return; proposed retention, coordinator acceptance required.','New movement, shove, firing, physical bow support, recoil, guard and collapse have distinct articulated poses.','Cast v1/v2 rejected for wrong-arm continuity at fifth pose; use v3 physical bow.','Death source1 first hood was clipped; replaced only first pose from generated source2. Review collapse transition 4 to 5 and source scale in engine.']))
(HERE/'handoff.json').write_text(json.dumps(dict(schema_version=1,units=[entry]),indent=2)+'\n',encoding='utf-8')
provenance=[]
for name,out in lineage.items():
    src=f'{REL}/cast_v1.png' if name=='cast_v2' else f'{REL}/death_v1.png' if name=='death_v2' else reference
    prompt=HERE/f'{name}.prompt.txt'
    provenance.append(dict(master=f'{REL}/{name}.png',sha256=hashlib.sha256((HERE/f'{name}.png').read_bytes()).hexdigest(),prompt=f'{REL}/{name}.prompt.txt',prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest(),reference=src,reference_sha256=hashlib.sha256((ROOT/src).read_bytes()).hexdigest(),generation_output=generated+out,tool='built-in image_gen',status='rejected arm continuity' if name in ['cast_v1','cast_v2'] else 'pending coordinator visual acceptance'))
(HERE/'provenance.json').write_text(json.dumps(dict(schema_version=1,unit_id='unit_prism_adept',sources=provenance),indent=2)+'\n',encoding='utf-8')
print(f'Wrote {len(frames)} new source frames across {len(clips)} clips; existing idle pending retention review.')
