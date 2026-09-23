"""Pack original authored drawings without pose synthesis or deformation."""
from pathlib import Path
from PIL import Image
import json,hashlib
HERE=Path(__file__).resolve().parent;ROOT=Path(__file__).resolve().parents[7]
rel=lambda p:p.relative_to(ROOT).as_posix()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
guard=HERE.parent/'unit_river_guard_veteran'
refs={'attack_v2':[HERE/'attack_v1.png'],'move_contacts_v1':[guard/'move_contacts_v2.png',HERE/'reference.png'],'move_inbetweens_v1':[guard/'move_inbetweens_v1.png',HERE/'move_contacts_v1.png']}
for row in json.loads((HERE/'generation_records.json').read_text()):
    stem=row['stem'];p=HERE/f'{stem}.prompt.txt';p.write_bytes(p.read_bytes().replace(b'\r\n',b'\n').rstrip(b'\n'))
    row.update(generator='built-in image_gen',source=rel(HERE/f'{stem}.png'),source_sha256=sha(HERE/f'{stem}.png'),prompt=rel(p),prompt_sha256=sha(p),references=[{'path':rel(r),'sha256':sha(r)} for r in refs.get(stem,[HERE/'reference.png'])],review_status='rejected_clipped_maul' if stem=='attack_v1' else ('withheld_weak_opposite_inbetweens' if stem=='move_inbetweens_v1' else 'pending_motion_review'))
    (HERE/f'{stem}.provenance.json').write_text(json.dumps(row,indent=2)+'\n',encoding='utf8')
u={'unit_id':'unit_bog_brute_veteran','reference_height':256,'source_facing':'right','alpha_noise_cutoff':8,'frames':[],'clips':{},'accepted_clips':[],'preserve_clips':[],'source_scale_by_image':{},'source_scale_reason':'Each complete original sheet has a fixed sourcewide resolution scale to207px hair-to-sole body reference. No individual pose rescaling or invented motion.','visual_review':{'status':'pending','notes':'Original articulated maul/shield idle, overhead strike, recoil, shield guard, salute and collapse/corpse. Movement withheld: opposite contact keys succeeded but generated inbetweens preserve leading foot too much.'}}
def add(clip,items,msec,loop=False,**kwargs):
    indices=[];images=[]
    for n,(stem,regions,anchor,scale) in enumerate(items):
        source=HERE/f'{stem}.png';indices.append(len(u['frames']))
        u['frames'].append({'name':f'{clip}_{n:02d}','clip':clip,'source':rel(source),'rects':regions,'anchor':anchor,'scale':scale})
        u['source_scale_by_image'][rel(source)]=scale
        canvas=Image.new('RGBA',(384,288));im=Image.open(source).convert('RGBA')
        for box in regions:
            patch=im.crop(box);patch.putalpha(patch.getchannel('A').point(lambda p:0 if p<=8 else p));patch=patch.resize((round(patch.width*scale),round(patch.height*scale)),Image.Resampling.LANCZOS)
            canvas.alpha_composite(patch,(round(192+(box[0]-anchor[0])*scale),round(266+(box[1]-anchor[1])*scale)))
        images.append(canvas)
    u['clips'][clip]={'indices':indices,'frame_msec':msec,'loop':loop,'static_frame':0,**kwargs}
    images[0].save(HERE/f'{clip}_preview.webp',save_all=True,append_images=images[1:],duration=msec,loop=0,lossless=True)
    sheet=Image.new('RGBA',(1536,288*((len(images)+3)//4)))
    for n,im in enumerate(images):sheet.alpha_composite(im,(n%4*384,n//4*288))
    sheet.save(HERE/f'{clip}_preview.png')
def grid(stem,scale,anchors,ys=(0,512,1024),xs=(0,384,768,1152,1536)):
    return [(stem,[[xs[i%4],ys[i//4],xs[i%4+1],ys[i//4+1]]],list(a),scale) for i,a in enumerate(anchors)]
idle=grid('idle_v1',.46,[(196,480),(580,480),(964,480),(1348,480),(196,990),(580,990),(964,990),(1348,990)])
add('idle',[idle[i] for i in [0,1,2,3,6,5,4,7]],140,True)
attack=grid('attack_v2',.53,[(220,450),(650,450),(1093,450),(1518,450),(220,850),(650,850),(1093,862),(1518,862)],ys=(0,470,887),xs=(0,443,887,1331,1774))
attack[4]=('attack_v2',[[0,470,516,705],[0,705,490,887]],[220,850],.53)
attack[5]=('attack_v2',[[516,470,919,705],[490,705,919,887]],[650,850],.53)
attack[6]=('attack_v2',[[919,470,1331,887]],[1093,862],.53)
add('attack',[attack[i] for i in [0,1,2,4,3,5,6,7]],100,contact_frame=3)
reaction=grid('reactions_v1',.48,[(290,500),(687,500),(1020,500),(1360,500),(243,975),(628,975),(970,975),(1354,975)],xs=(0,458,802,1187,1536))
reaction[0]=('reactions_v1',[[0,0,470,286],[0,286,395,380],[0,380,447,512]],[290,500],.48)
reaction[1]=('reactions_v1',[[470,0,854,286],[395,286,854,380],[447,380,854,512]],[687,500],.48)
reaction[2]=('reactions_v1',[[854,0,1208,268],[854,268,1188,512]],[1020,500],.48)
reaction[3]=('reactions_v1',[[1208,0,1536,268],[1188,268,1536,512]],[1360,500],.48)
add('hit',reaction[:4],100);add('defend',reaction[4:],120,True)
add('death',grid('death_v1',.48,[(210,465),(654,465),(1098,465),(1542,465),(210,827),(654,827),(1098,827),(1542,827)],ys=(0,500,887),xs=(0,449,887,1331,1774)),120)
u['clips']['dead']={'indices':[u['clips']['death']['indices'][-1]],'frame_msec':1000,'loop':False,'static_frame':0}
add('cast',grid('support_v1',.47,[(192,494),(576,494),(960,494),(1344,494),(192,1008),(576,1008),(960,1008),(1344,1008)],ys=(0,510,1024)),120,gesture_kind='nonmagical_maul_salute')
(HERE/'handoff.json').write_text(json.dumps({'schema_version':1,'units':[u]},indent=2)+'\n',encoding='utf8')
print({k:len(v['indices']) for k,v in u['clips'].items()})
