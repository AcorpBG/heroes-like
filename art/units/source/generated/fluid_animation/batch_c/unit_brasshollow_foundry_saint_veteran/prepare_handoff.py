"""Register original hand-painted sources; never synthesize missing animation poses."""
from pathlib import Path
import hashlib,json
from PIL import Image
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
uid=HERE.name
unit=dict(unit_id=uid,reference_height=256,source_facing='right',frames=[],clips={},accepted_clips=[],preserve_clips=[],visual_review={'status':'pending','notes':'Dedicated original sequences; inspect two-step gait continuity and death landing.'},source_scale_by_image={},source_scale_reason='Fixed per-source scales normalize independent original sheet body heights to approximately225pixels. Same original image always uses same scale; no per-pose warp or scaling.',provenance={'tool':'builtin_image_gen','references':['art/animation/source/poses/'+uid+'/'+uid+'_source-alpha.png'],'sources':[]})
outputs={
 'attack_v1':'exec-6be76c40-2399-4aee-8256-623c63879fcc.png',
 'idle_v1':'exec-c4c3b732-4b7d-45ee-80d0-c6cc8d9db071.png',
 'move_v1':'exec-2f98d353-98cc-40b0-b0e8-cdf32f5d9e2c.png',
 'move_v2':'exec-b04e87d5-391c-41fc-9739-d009c860f68d.png',
 'move_farstep_v3':'exec-b0140d51-2f08-45d2-9038-6b4395acaddb.png',
 'death_v1':'exec-0f8b2b30-a799-4c38-b9a0-3cdc2c134c6a.png',
 'death_direction_v2':'exec-ab4883ea-75d7-4433-af76-521784b1aa32.png',
 'death_landing_v3':'exec-498e5464-28ef-46ad-aab3-b456554c1533.png',
 'reactions_v1':'exec-21824d96-a139-41b7-902b-b893ed2f4200.png',
 'support_v1':'exec-d6105dbe-d89f-4760-b1b0-23e4f49a09e2.png',
}
for stem,out in outputs.items():
    src=HERE/(stem+'.png'); prompt=HERE/(stem+'.prompt.txt')
    unit['provenance']['sources'].append(dict(image=src.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(src.read_bytes()).hexdigest(),prompt=prompt.relative_to(ROOT).as_posix(),prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest(),generation_output='C:/Users/acorp/.codex/generated_images/01a0ccb1-fd32-7871-9a3b-64fb488c298f/'+out,status='rejected' if stem in ['move_v1','death_direction_v2'] else 'pending_review'))
renders={}
def add(clip,stem,source_indices,scale,anchors,columns=4,rect_overrides=None):
    src=HERE/(stem+'.png'); im=Image.open(src).convert('RGBA'); w,h=im.size
    sourcepath=src.relative_to(ROOT).as_posix(); unit['source_scale_by_image'][sourcepath]=scale
    for local,i in enumerate(source_indices):
        col,row=i%columns,i//columns
        rect=[round(w*col/columns),round(h*row/2),round(w*(col+1)/columns),round(h*(row+1)/2)]
        if rect_overrides and i in rect_overrides: rect=rect_overrides[i]
        ax,ay=anchors[local]
        index=len(unit['frames']); frame=dict(name=clip+'_'+str(len(renders.get(clip,[]))),clip=clip,source=sourcepath,rects=[rect],anchor=[ax,ay],scale=scale,alpha_noise_cutoff=8)
        unit['frames'].append(frame)
        unit['clips'].setdefault(clip,dict(indices=[],frame_msec=110,loop=clip in ['idle','move']))['indices'].append(index)
        crop=im.crop(rect); crop=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.LANCZOS)
        canvas=Image.new('RGBA',(512,288));canvas.alpha_composite(crop,(256-round((ax-rect[0])*scale),272-round((ay-rect[1])*scale)))
        renders.setdefault(clip,[]).append(canvas)
add('idle','idle_v1',range(8),.56,[(265,417),(681,417),(1110,417),(1558,417),(265,849),(681,849),(1110,849),(1558,849)])
add('attack','attack_v1',range(8),.56,[(207,421),(660,421),(1103,421),(1550,421),(205,842),(666,842),(1113,842),(1560,842)],rect_overrides={4:[0,444,500,887],5:[500,444,887,887]})
unit['clips']['attack']['contact_frame']=4
add('move','move_v2',range(4),.585,[(214,418),(658,418),(1104,418),(1549,418)])
add('move','move_farstep_v3',range(4),.395,[(345,594),(968,594),(345,1210),(968,1210)],columns=2)
add('hit','reactions_v1',range(4),.56,[(209,413),(657,413),(1106,413),(1560,413)])
add('defend','reactions_v1',range(4,8),.56,[(209,852),(657,852),(1106,852),(1560,852)])
add('death','death_v1',range(4),.56,[(205,433),(651,433),(1100,433),(1546,433)])
add('death','death_landing_v3',range(4),.39,[(313,582),(943,584),(313,1137),(943,1143)],columns=2)
unit['clips']['dead']=dict(indices=[unit['clips']['death']['indices'][-1]],frame_msec=110,loop=False)
add('cast','support_v1',range(8),.56,[(252,419),(674,419),(1107,419),(1543,419),(239,859),(674,859),(1107,859),(1543,859)],rect_overrides={4:[0,444,494,887],5:[494,444,887,887]})
unit['clips']['cast']['contact_frame']=4
unit['clips']['idle'].update(frame_msec=125,static_frame=0)
unit['clips']['move']['frame_msec']=100
unit['accepted_clips']=['idle','attack','move','hit','defend','death','dead','cast']
unit['visual_review']={'status':'accepted','reviewer':'root','surface':'Godot rendered motion for all seven clips','notes':'Root approved articulated hands/punch, gait, guard/recoil, physical support and grounded cold-furnace corpse on2026-09-23.'}
(HERE/'handoff.json').write_text(json.dumps(dict(schema_version=1,units=[unit]),indent=2)+'\n',encoding='utf-8')
preview=HERE/'preview';preview.mkdir(exist_ok=True)
for clip,poses in renders.items():
    poses[0].save(preview/(clip+'.gif'),save_all=True,append_images=poses[1:]+([poses[-1]]*3 if clip not in ['idle','move'] else []),duration=unit['clips'][clip]['frame_msec'],loop=0,disposal=2)
    sheet=Image.new('RGBA',(1024,288 if len(poses)==4 else 576),(38,40,34,255))
    for i,p in enumerate(poses):
        pic=p.resize((256,144),Image.Resampling.LANCZOS);sheet.alpha_composite(pic,((i%4)*256,(i//4)*288+72))
    sheet.save(preview/(clip+'.png'))
print(json.dumps({'unit_id':uid,'frames':len(unit['frames']),'clips':{k:len(v['indices']) for k,v in unit['clips'].items()}}))
