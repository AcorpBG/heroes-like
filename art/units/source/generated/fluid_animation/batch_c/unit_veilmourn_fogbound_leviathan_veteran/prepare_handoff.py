"""Crop/pack original generated poses without synthesizing or repainting motion."""
from pathlib import Path
import json, hashlib
from PIL import Image

ROOT=Path(__file__).resolve().parents[7]
HERE=Path(__file__).resolve().parent
uid=HERE.name
source=HERE/'attack_v2.png'
im=Image.open(source).convert('RGBA')
w,h=im.size
xs=[round(w*i/4) for i in range(5)]
ys=[0,round(h/2),h]
frames=[]
poses=[]
phases=['ready','compression','jaw_open_anticipation','launch','bite_contact','weight_absorption','recovery','settle']
# Anatomical body/ground registration, not per-frame bounding-box scaling.
anchors=[(184,407),(624,408),(1067,409),(1510,409),(184,817),(624,817),(1067,817),(1510,817)]
for i in range(8):
    col,row=i%4,i//4
    rect=[xs[col],ys[row],xs[col+1],ys[row+1]]
    frames.append(dict(name='attack_'+str(i),clip='attack',source=source.relative_to(ROOT).as_posix(),rects=[rect],anchor=list(anchors[i]),scale=0.64,phase=phases[i]))
    if i==6:
        frames[-1]['source']=(HERE/'attack_recovery_v3.png').relative_to(ROOT).as_posix()
        crop=Image.open(HERE/'attack_recovery_v3.png').convert('RGBA').crop(rect)
    else:
        crop=im.crop(rect)
    crop=crop.resize((round(crop.width*.64),round(crop.height*.64)),Image.Resampling.LANCZOS)
    canvas=Image.new('RGBA',(512,288))
    ax,ay=anchors[i]
    canvas.alpha_composite(crop,(256-round((ax-rect[0])*.64),272-round((ay-rect[1])*.64)))
    poses.append(canvas)
unit=dict(unit_id=uid,reference_height=256,source_facing='right',frames=frames,clips={'attack':dict(indices=list(range(8)),frame_msec=100,contact_frame=4,loop=False)},accepted_clips=[],preserve_clips=[],visual_review=dict(status='pending',notes='Eight distinct generated bite phases; v1 rejected for edge clipping; v2 submitted for motion review.'),provenance={'tool':'builtin_image_gen','references':['art/animation/source/poses/'+uid+'/'+uid+'-alpha.png'],'sources':[]})
outputs=['exec-6f06fc3a-6d3e-4f19-8158-4b5f39aeb631.png','exec-4cef03ab-565f-4b96-8df3-ff360d49213a.png']
for v,out in zip([1,2],outputs):
    img=HERE/f'attack_v{v}.png'; prompt=HERE/f'attack_v{v}.prompt.txt'
    unit['provenance']['sources'].append(dict(image=img.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(img.read_bytes()).hexdigest(),prompt=prompt.relative_to(ROOT).as_posix(),prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest(),generation_output='C:/Users/acorp/.codex/generated_images/01a0ccb1-fd32-7871-9a3b-64fb488c298f/'+out,status='rejected_clipping' if v==1 else 'pending_review'))
fix=HERE/'attack_recovery_v3.png'; fixprompt=HERE/'attack_recovery_v3.prompt.txt'
unit['provenance']['sources'].append(dict(image=fix.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(fix.read_bytes()).hexdigest(),prompt=fixprompt.relative_to(ROOT).as_posix(),prompt_sha256=hashlib.sha256(fixprompt.read_bytes()).hexdigest(),generation_output='C:/Users/acorp/.codex/generated_images/01a0ccb1-fd32-7871-9a3b-64fb488c298f/exec-c8f02531-9f69-4fba-922f-d4e6cce4240e.png',status='pending_review',used_frames=[6],reference='attack_v2.png'))
fix=HERE/'death_corpse_v2.png'; fixprompt=HERE/'death_corpse_v2.prompt.txt'
unit['provenance']['sources'].append(dict(image=fix.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(fix.read_bytes()).hexdigest(),prompt=fixprompt.relative_to(ROOT).as_posix(),prompt_sha256=hashlib.sha256(fixprompt.read_bytes()).hexdigest(),generation_output='C:/Users/acorp/.codex/generated_images/01a0ccb1-fd32-7871-9a3b-64fb488c298f/exec-bc8b760d-0250-46cb-aef4-f91004a38ed5.png',status='pending_review',used_frames=[5,6,7],reference='death_v1.png'))
extra=[
    ('support_v1','cast',0.585,[(183,426),(627,426),(1070,426),(1514,426),(183,833),(627,833),(1070,833),(1514,833)],'exec-4ccb9c0a-6d0c-458f-a729-ea83407c6542.png',110),
    ('idle_v1','idle',0.57,[(183,400),(627,401),(1070,400),(1514,400),(183,817),(627,817),(1070,817),(1514,817)],'exec-7b34169a-dcbd-4256-a2a3-34a194a9624a.png',125),
    ('move_v1','move',0.585,[(183,418),(627,418),(1070,418),(1514,418),(183,818),(627,818),(1070,818),(1514,818)],'exec-3581ddf1-b2fe-4c71-aefe-63a9fcb83a55.png',100),
    ('death_v1','death',0.585,[(183,427),(627,427),(1070,427),(1514,427),(183,785),(627,785),(1070,785),(1514,785)],'exec-8969e389-9a59-4469-988c-fb87d583ba81.png',110),
    ('reactions_v1','reactions',0.585,[(183,432),(627,432),(1070,432),(1514,432),(183,833),(627,833),(1070,833),(1514,833)],'exec-58985e03-f5b1-42b9-8461-8163cd0835de.png',110),
]
extra_poses={}
for stem,clip,scale,clipanchors,out,timing in extra:
    img=HERE/(stem+'.png'); prompt=HERE/(stem+'.prompt.txt'); master=Image.open(img).convert('RGBA')
    source_path=img.relative_to(ROOT).as_posix()
    unit['provenance']['sources'].append(dict(image=source_path,sha256=hashlib.sha256(img.read_bytes()).hexdigest(),prompt=prompt.relative_to(ROOT).as_posix(),prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest(),generation_output='C:/Users/acorp/.codex/generated_images/01a0ccb1-fd32-7871-9a3b-64fb488c298f/'+out,status='pending_review'))
    start=len(unit['frames'])
    for i in range(8):
        col,row=i%4,i//4; rect=[xs[col],ys[row],xs[col+1],ys[row+1]]
        frameclip=clip if clip!='reactions' else ('hit' if i<4 else 'defend')
        unit['frames'].append(dict(name=frameclip+'_'+str(i%4 if clip=='reactions' else i),clip=frameclip,source=source_path,rects=[rect],anchor=list(clipanchors[i]),scale=scale))
        if clip=='death' and i>=5:
            unit['frames'][-1]['source']=(HERE/'death_corpse_v2.png').relative_to(ROOT).as_posix()
            crop=Image.open(HERE/'death_corpse_v2.png').convert('RGBA').crop(rect)
        else:
            crop=master.crop(rect)
        crop=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.LANCZOS)
        canvas=Image.new('RGBA',(512,288)); ax,ay=clipanchors[i]
        canvas.alpha_composite(crop,(256-round((ax-rect[0])*scale),272-round((ay-rect[1])*scale)))
        extra_poses.setdefault(frameclip,[]).append(canvas)
    if clip=='reactions':
        unit['clips']['hit']=dict(indices=list(range(start,start+4)),frame_msec=timing,loop=False)
        unit['clips']['defend']=dict(indices=list(range(start+4,start+8)),frame_msec=timing,loop=False)
    else:
        unit['clips'][clip]=dict(indices=list(range(start,start+8)),frame_msec=timing,loop=clip in ['idle','move'])
        if clip=='idle': unit['clips'][clip]['static_frame']=0
        if clip=='cast': unit['clips'][clip]['contact_frame']=3
        if clip=='death': unit['clips']['dead']=dict(indices=[start+7],frame_msec=timing,loop=False)
unit['visual_review']['notes']='Eight authored poses each for attack, idle, move and death; four hit and four defend. Attack recovery mouth corrected to closed withdrawal; death final three poses repainted with closed eyes, dim sacs and limp foreleg. All pending motion review. Different source-sheet scales normalize the same anatomical torso width, never frame-by-frame scale changes.'
unit['source_scale_by_image']={frame['source']:frame['scale'] for frame in unit['frames']}
unit['source_scale_reason']='Independent original generated sheets use different creature sizes within equal 1774x887 canvases. Source-fixed scales normalize the visible torso width to the accepted idle design; every pose from one source uses exactly the same scale. No per-pose bbox normalization or deformation.'
unit['accepted_clips']=['idle','move','attack','hit','defend','death','dead','cast']
unit['visual_review']={'status':'accepted','reviewer':'root','surface':'Godot rendered motion for all seven clips','notes':'Coordinator approved all seven clips after inspecting corrected single-bite recovery, visible foreleg motion, grounded persistent corpse and physical support acknowledgement on 2026-09-23.'}
for frame in unit['frames']:
    frame['alpha_noise_cutoff']=8
(HERE/'handoff.json').write_text(json.dumps(dict(schema_version=1,units=[unit]),indent=2)+'\n',encoding='utf-8')
preview=HERE/'preview'
preview.mkdir(exist_ok=True)
for clip,pp in extra_poses.items():
    pp[0].save(preview/(clip+'.gif'),save_all=True,append_images=pp[1:]+([pp[-1]]*3 if clip in ['death','hit','defend'] else []),duration=125 if clip=='idle' else 110,loop=0,disposal=2)
    contact=Image.new('RGBA',(1024,288 if len(pp)==4 else 576),(38,40,34,255))
    for i,p in enumerate(pp):
        pic=p.copy(); pic.thumbnail((256,288),Image.Resampling.LANCZOS)
        contact.alpha_composite(pic,((i%4)*256,(i//4)*288+72))
    contact.save(preview/(clip+'.png'))
poses[0].save(preview/'attack.gif',save_all=True,append_images=poses[1:]+[poses[-1]]*3,duration=100,loop=0,disposal=2)
sheet=Image.new('RGBA',(1024,576),(38,40,34,255))
for i,p in enumerate(poses):
    p.thumbnail((256,288),Image.Resampling.LANCZOS)
    sheet.alpha_composite(p,((i%4)*256,(i//4)*288+72))
sheet.save(preview/'attack.png')
print(json.dumps({'source_size':[w,h],'handoff':str(HERE/'handoff.json'),'frame_alpha_bounds':[im.crop([xs[i%4],ys[i//4],xs[i%4+1],ys[i//4+1]]).getbbox() for i in range(8)]}))
