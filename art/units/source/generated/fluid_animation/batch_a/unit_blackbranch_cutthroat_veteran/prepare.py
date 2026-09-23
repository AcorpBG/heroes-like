"""Pack original authored drawings without pose synthesis or deformation."""
from pathlib import Path
from PIL import Image
import json,hashlib
HERE=Path(__file__).resolve().parent;ROOT=Path(__file__).resolve().parents[7]
rel=lambda p:p.relative_to(ROOT).as_posix()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
guard=HERE.parent/'unit_river_guard_veteran'
refs={'move_contacts_v1':[HERE/'reference.png',guard/'move_contacts_v2.png'],'move_contacts_v2':[guard/'move_contacts_v2.png',HERE/'reference.png'],'move_contacts_v3':[HERE/'move_contacts_v2.png'],'move_inbetweens_v1':[guard/'move_inbetweens_v1.png',HERE/'move_contacts_v3.png']}
for row in json.loads((HERE/'generation_records.json').read_text()):
    stem=row['stem'];p=HERE/f'{stem}.prompt.txt';p.write_bytes(p.read_bytes().replace(b'\r\n',b'\n').rstrip(b'\n'))
    row.update(generator='built-in image_gen',source=rel(HERE/f'{stem}.png'),source_sha256=sha(HERE/f'{stem}.png'),prompt=rel(p),prompt_sha256=sha(p),references=[{'path':rel(r),'sha256':sha(r)} for r in refs.get(stem,[HERE/'reference.png'])],review_status='rejected_same_leading_leg' if stem=='move_contacts_v1' else ('rejected_guard_kneecap_leak' if stem=='move_contacts_v2' else 'pending_motion_review'))
    (HERE/f'{stem}.provenance.json').write_text(json.dumps(row,indent=2)+'\n',encoding='utf8')
u={'unit_id':'unit_blackbranch_cutthroat_veteran','reference_height':256,'source_facing':'right','alpha_noise_cutoff':8,'frames':[],'clips':{},'accepted_clips':[],'preserve_clips':[],'source_scale_by_image':{},'source_scale_reason':'Each complete original sheet has a fixed sourcewide resolution scale to207px hood-to-sole body reference. No individual pose rescaling or invented motion.','visual_review':{'status':'pending','notes':'Original idle, slash, recoil, crossed-blade guard, physical salute, collapse/corpse and opposite-contact walking with6 inbetweens. Move reordered finalhalf to preserve knee/foot progression; root motion review required.'}}
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
add('idle',grid('idle_v1',.45,[(199,500),(583,500),(967,500),(1351,500),(199,1005),(583,1005),(967,1005),(1351,1005)]),130,True)
attack=grid('attack_v1',.5,[(220,432),(665,432),(1104,432),(1515,432),(232,862),(681,862),(1104,862),(1546,862)],ys=(0,445,887),xs=(0,443,887,1331,1774))
attack[4]=('attack_v1',[[0,445,500,887]],[232,862],.5)
attack[5]=('attack_v1',[[500,445,887,887]],[681,862],.5)
add('attack',attack,90,contact_frame=4)
reaction=grid('reactions_v1',.46,[(236,502),(596,502),(956,502),(1330,502),(190,990),(574,990),(958,990),(1342,990)],xs=(0,400,768,1152,1536))
add('hit',reaction[:4],95);add('defend',reaction[4:],120,True)
add('death',grid('death_v1',.5,[(220,465),(665,465),(1104,465),(1545,465),(225,832),(665,840),(1104,840),(1545,840)],ys=(0,500,887),xs=(0,443,887,1331,1774)),110)
u['clips']['dead']={'indices':[u['clips']['death']['indices'][-1]],'frame_msec':1000,'loop':False,'static_frame':0}
add('cast',grid('support_v1',.47,[(184,484),(570,484),(954,484),(1338,484),(184,994),(570,994),(954,994),(1338,994)],ys=(0,495,1024)),110,gesture_kind='nonmagical_blade_salute')
keys='move_contacts_v3';mid='move_inbetweens_v1'
walk=[(keys,[[0,0,887,887]],[540,853],.2825)]
for i,a in enumerate([(284,505),(735,505),(1230,505)]):walk.append((mid,[[i*512,0,(i+1)*512,512]],list(a),.445))
walk.append((keys,[[887,0,1774,887]],[1224,853],.2825))
for i,a in [(1,(735,996)),(0,(284,996)),(2,(1230,996))]:walk.append((mid,[[i*512,512,(i+1)*512,1024]],list(a),.445))
add('move',walk,100,True)
(HERE/'handoff.json').write_text(json.dumps({'schema_version':1,'units':[u]},indent=2)+'\n',encoding='utf8')
print({k:len(v['indices']) for k,v in u['clips'].items()})
