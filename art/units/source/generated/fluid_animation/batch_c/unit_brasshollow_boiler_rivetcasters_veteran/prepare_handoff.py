"""Source rectangles and anatomical registration for original Twinboiler poses."""
from pathlib import Path
import hashlib,json
from PIL import Image
HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[6];uid=HERE.name
unit=dict(unit_id=uid,reference_height=256,source_facing='right',frames=[],clips={},accepted_clips=[],preserve_clips=[],visual_review={'status':'pending','notes':'Eight distinct poses per long clip, including melee/ranged and physical salute. Isolated salute correction preserves same raised arm.'},source_scale_by_image={},source_scale_reason='One fixed scale per original source normalizes independently generated body heights to225pixels; never per-frame bbox resizing.',provenance={'tool':'builtin_image_gen','references':['art/animation/source/poses/'+uid+'/'+uid+'_source-alpha.png'],'sources':[]})
outputs={
 'move_v3':'exec-c93b4f8c-7198-4a74-894c-9db07aaba909.png',
 'idle_v1':'exec-bae582ab-cb6c-4c96-93c3-602b2e6ef05e.png',
 'idle_v2':'exec-46816e9f-154b-4e07-86f4-eb516c2ccea1.png',
 'ranged_v1':'exec-c4e5a8cc-d311-4c8a-a9d1-4055dab50f71.png',
 'ranged_v2':'exec-2730a681-55b6-45c7-b169-f9394db13cc7.png',
 'move_v1':'exec-e614c8a7-557a-4a87-832a-6bb372d2b10e.png',
 'move_alpha_v2':'exec-f40f9128-d683-445f-ac74-de90eaecf7b7.png',
 'attack_v1':'exec-13b91480-bcf5-4847-9b26-ad04699e0671.png',
 'death_v1':'exec-f815bb7d-1a8e-4e90-aea9-e577b4107cd1.png',
 'reactions_v1':'exec-77dab001-9655-4eb2-a535-1490c76bc626.png',
 'support_v1':'exec-e24db1ba-02a8-41b3-b1ff-f8e62f004cb5.png',
 'support_v2':'exec-bf62e677-60ee-4df9-abdb-13ebce058d97.png',
 'support_hand_v3':'exec-e0ca5cdd-4840-4167-9f93-d862b2dd9103.png',
}
for stem,out in outputs.items():
    src=HERE/(stem+'.png');prompt=HERE/(stem+'.prompt.txt')
    unit['provenance']['sources'].append(dict(image=src.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(src.read_bytes()).hexdigest(),prompt=prompt.relative_to(ROOT).as_posix(),prompt_sha256=hashlib.sha256(prompt.read_bytes()).hexdigest(),generation_output='C:/Users/acorp/.codex/generated_images/01a0ccb1-fd32-7871-9a3b-64fb488c298f/'+out,status='superseded' if stem in ['idle_v1','ranged_v1','move_alpha_v2','support_v1'] else 'pending_review'))
unit['provenance']['derived_reference']={'path':(HERE/'support_hand_reference.png').relative_to(ROOT).as_posix(),'source':'support_v2.png','rect':[887,0,1331,444],'used_by':'support_hand_v3'}
renders={}
def add(clip,stem,indices,scale,anchors,columns=4,rows=2,rect_overrides=None):
    src=HERE/(stem+'.png');im=Image.open(src).convert('RGBA');w,h=im.size;sourcepath=src.relative_to(ROOT).as_posix();unit['source_scale_by_image'][sourcepath]=scale
    for local,i in enumerate(indices):
        col,row=i%columns,i//columns;rect=[round(w*col/columns),round(h*row/rows),round(w*(col+1)/columns),round(h*(row+1)/rows)]
        if rect_overrides and i in rect_overrides:rect=rect_overrides[i]
        ax,ay=anchors[local];index=len(unit['frames'])
        unit['frames'].append(dict(name=clip+'_'+str(len(renders.get(clip,[]))),clip=clip,source=sourcepath,rects=[rect],anchor=[ax,ay],scale=scale,alpha_noise_cutoff=8))
        unit['clips'].setdefault(clip,dict(indices=[],frame_msec=110,loop=clip in ['idle','move']))['indices'].append(index)
        crop=im.crop(rect);crop=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.LANCZOS)
        canvas=Image.new('RGBA',(512,288));canvas.alpha_composite(crop,(256-round((ax-rect[0])*scale),272-round((ay-rect[1])*scale)));renders.setdefault(clip,[]).append(canvas)
add('idle','idle_v2',range(8),.66,[(238,408),(681,408),(1124,408),(1567,408),(238,831),(681,831),(1124,831),(1567,831)])
add('attack','attack_v1',range(8),.56,[(235,428),(690,428),(1129,428),(1560,428),(223,852),(687,852),(1115,852),(1560,852)],rect_overrides={4:[0,444,530,887],5:[530,444,915,887],6:[915,444,1331,887]})
unit['clips']['attack']['contact_frame']=4
move_rects={i:[([0,415,785,1166][i%4]),512*(i//4),([415,785,1166,1536][i%4]),512*(i//4+1)] for i in range(8)}
add('move','move_v3',[4,1,2,6,3,0,5,7],.56,[(216,954),(596,456),(960,456),(973,954),(1339,456),(215,456),(601,954),(1346,954)],rect_overrides=move_rects)
unit['clips']['move']['painted_phase_order']=['near contact','near support / far trails','far knee lifts','far shin extends','far heel contact','far flat contact / near trails','far support / near knee lifts','near shin extends']
add('ranged','ranged_v2',range(8),.645,[(167,527),(471,527),(782,527),(1092,527),(174,1105),(477,1105),(787,1105),(1099,1105)],rect_overrides={0:[0,0,332,627],1:[332,0,646,627],2:[646,0,951,627],3:[951,0,1254,627],4:[0,627,340,1254],5:[340,627,645,1254],6:[645,627,948,1254],7:[948,627,1254,1254]})
unit['clips']['ranged']['contact_frame']=4
add('hit','reactions_v1',range(4),.56,[(244,421),(705,421),(1128,421),(1560,421)])
add('defend','reactions_v1',[4,7,5,6],.56,[(244,853),(1560,853),(705,853),(1128,853)])
death_rects={i:[round(1774*(i%4)/4),0 if i<4 else 500,round(1774*(i%4+1)/4),500 if i<4 else 887] for i in range(8)}
death_rects[2]=[887,0,1270,500];death_rects[3]=[1270,0,1774,500]
death_rects[6]=[887,500,1304,887];death_rects[7]=[1304,500,1774,887]
add('death','death_v1',range(8),.575,[(222,464),(658,464),(1098,464),(1530,464),(217,846),(660,846),(1097,846),(1540,846)],rect_overrides=death_rects)
unit['clips']['dead']=dict(indices=[unit['clips']['death']['indices'][-1]],frame_msec=110,loop=False)
add('cast','support_v2',[0,1,2],.65,[(223,431),(675,431),(1118,431)])
add('cast','support_hand_v3',[0],.235,[(602,1190)],columns=1,rows=1)
add('cast','support_v2',[4,5,6,7],.65,[(223,840),(675,840),(1118,840),(1573,840)])
unit['clips']['cast']['contact_frame']=3
unit['clips']['idle'].update(frame_msec=125,static_frame=0);unit['clips']['move']['frame_msec']=100
(HERE/'handoff.json').write_text(json.dumps(dict(schema_version=1,units=[unit]),indent=2)+'\n',encoding='utf-8')
preview=HERE/'preview';preview.mkdir(exist_ok=True)
for clip,poses in renders.items():
    poses[0].save(preview/(clip+'.gif'),save_all=True,append_images=poses[1:]+([poses[-1]]*3 if clip not in ['idle','move'] else []),duration=unit['clips'][clip]['frame_msec'],loop=0,disposal=2)
    sheet=Image.new('RGBA',(1024,288 if len(poses)==4 else 576),(38,40,34,255))
    for i,p in enumerate(poses):sheet.alpha_composite(p.resize((256,144),Image.Resampling.LANCZOS),((i%4)*256,(i//4)*288+72))
    sheet.save(preview/(clip+'.png'))
print(json.dumps({'unit_id':uid,'frames':len(unit['frames']),'clips':{k:len(v['indices']) for k,v in unit['clips'].items()}}))
