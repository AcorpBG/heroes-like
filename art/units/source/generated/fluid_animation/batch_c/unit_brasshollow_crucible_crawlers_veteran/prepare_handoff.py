"""Original articulated crawler poses; source-coordinate crops and registration."""
from pathlib import Path
import hashlib,json
from PIL import Image
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[6];uid=HERE.name
unit=dict(unit_id=uid,reference_height=256,source_facing='right',frames=[],clips={},accepted_clips=[],preserve_clips=[],visual_review={'status':'pending','notes':'Four-legged crawler, original articulated gait, recoil, bracing, physical support salute, and grounded inert corpse.'},source_scale_by_image={},source_scale_reason='Fixed 0.72 scale across all originals, no per-pose resizing.',provenance={'tool':'builtin_image_gen','references':['art/animation/source/poses/'+uid+'/'+uid+'_source-alpha.png'],'sources':[]})
outputs={'idle_v1':'exec-75b85474-7377-4872-8632-873186619b21.png','move_v1':'exec-6da113f6-8789-4912-a1d7-1198b6d69798.png','attack_v1':'exec-93eef405-161e-4ebf-9e7b-590f2639da41.png','ranged_v1':'exec-0221a7ae-ad2e-4288-a6ce-64a1d347e128.png','death_v1':'exec-3422f703-48c3-406f-bcbd-85f182bac2a3.png','reactions_v1':'exec-954b0c66-36ff-41bb-ac90-df93bf00b3d4.png','support_v1':'exec-648e3a5b-cf36-4573-9d02-6afbf77ba5a8.png'}
for stem,out in outputs.items():
    src=HERE/(stem+'.png');prompt=HERE/(stem+'.prompt.txt')
    unit['provenance']['sources'].append(dict(image=src.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(src.read_bytes()).hexdigest(),prompt=prompt.relative_to(ROOT).as_posix(),prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest(),generation_output='C:/Users/acorp/.codex/generated_images/01a0ccb1-fd32-7871-9a3b-64fb488c298f/'+out,status='pending_review'))
renders={}
def add(clip,stem,indices,anchors,overrides=None):
    im=Image.open(HERE/(stem+'.png')).convert('RGBA');w,h=im.size;source=(HERE/(stem+'.png')).relative_to(ROOT).as_posix();scale=.72
    unit['source_scale_by_image'][source]=scale
    for local,i in enumerate(indices):
        c,r=i%4,i//4;rects=[[round(w*c/4),round(h*r/2),round(w*(c+1)/4),round(h*(r+1)/2)]]
        if overrides and i in overrides:rects=overrides[i]
        ax,ay=anchors[local];index=len(unit['frames'])
        unit['frames'].append(dict(name=clip+'_'+str(local),clip=clip,source=source,rects=rects,anchor=[ax,ay],scale=scale,alpha_noise_cutoff=8))
        unit['clips'].setdefault(clip,dict(indices=[],frame_msec=110,loop=clip in ['idle','move']))['indices'].append(index)
        left=min(x[0] for x in rects);top=min(x[1] for x in rects);right=max(x[2] for x in rects);bottom=max(x[3] for x in rects)
        crop=Image.new('RGBA',(right-left,bottom-top))
        for rect in rects:crop.paste(im.crop(rect),(rect[0]-left,rect[1]-top))
        crop.putalpha(crop.getchannel('A').point(lambda a:a if a>=8 else 0))
        crop=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.LANCZOS)
        canvas=Image.new('RGBA',(512,320));canvas.alpha_composite(crop,(256-round((ax-left)*scale),290-round((ay-top)*scale)));renders.setdefault(clip,[]).append(canvas)
anchors=lambda top,bottom:[(220,top),(664,top),(1107,top),(1551,top),(220,bottom),(664,bottom),(1107,bottom),(1551,bottom)]
add('idle','idle_v1',range(8),anchors(398,785))
add('move','move_v1',range(8),anchors(397,788))
attack_rects={4:[[0,444,462,887],[462,590,486,666]],5:[[486,444,901,666],[462,666,887,887]],6:[[901,444,1331,666],[887,666,1331,887]]}
add('attack','attack_v1',range(8),anchors(386,796),attack_rects)
unit['clips']['attack']['contact_frame']=4
add('ranged','ranged_v1',range(8),anchors(399,796),{4:[[0,444,461,650],[0,650,444,887]],5:[[461,444,887,650],[444,650,887,887]]})
unit['clips']['ranged']['contact_frame']=4
add('hit','reactions_v1',range(4),anchors(380,798)[:4])
add('defend','reactions_v1',range(4,8),anchors(380,798)[4:],{4:[[0,444,439,887]],5:[[439,444,881,887]],6:[[881,444,1331,887]]})
add('cast','support_v1',range(8),anchors(382,820))
unit['clips']['cast']['contact_frame']=4
death_rects={4:[[0,444,450,887]],5:[[450,444,883,887]],6:[[883,444,1322,887]],7:[[1322,444,1774,887]]}
add('death','death_v1',range(8),anchors(411,823),death_rects)
unit['clips']['dead']=dict(indices=[unit['clips']['death']['indices'][-1]],frame_msec=110,loop=False)
unit['clips']['idle'].update(frame_msec=130,static_frame=0);unit['clips']['move']['frame_msec']=100
(HERE/'handoff.json').write_text(json.dumps(dict(schema_version=1,units=[unit]),indent=2)+'\n',encoding='utf-8')
preview=HERE/'preview';preview.mkdir(exist_ok=True)
for clip,poses in renders.items():
    poses[0].save(preview/(clip+'.gif'),save_all=True,append_images=poses[1:]+([poses[-1]]*3 if clip not in ['idle','move'] else []),duration=unit['clips'][clip]['frame_msec'],loop=0,disposal=2)
    sheet=Image.new('RGBA',(1024,640 if len(poses)>4 else 320),(38,40,34,255))
    for i,p in enumerate(poses):sheet.alpha_composite(p.resize((256,160),Image.Resampling.LANCZOS),((i%4)*256,(i//4)*320+80))
    sheet.save(preview/(clip+'.png'))
print(json.dumps({'unit_id':uid,'frames':len(unit['frames']),'clips':{k:len(v['indices']) for k,v in unit['clips'].items()}}))


# Replay reviewed ownership correction after grid extraction.
import sys as _crop_sys
from pathlib import Path as _CropPath
_crop_dir = _CropPath(__file__).resolve().parent
_crop_root = next(p for p in _crop_dir.parents if (p / "project.godot").exists())
_crop_sys.path.insert(0, str(_crop_root / "tools"))
from refine_fluid_frame_crops import apply_recipe as _apply_crop_recipe
_apply_crop_recipe(_crop_dir / "handoff.json", _crop_dir / "crop_refinements.json")
