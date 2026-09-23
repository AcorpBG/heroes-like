"""Pack two authored contact keys and six authored inbetweens without synthetic poses."""
from pathlib import Path
import hashlib,json
from PIL import Image
HERE=Path(__file__).resolve().parent;ROOT=Path(__file__).resolve().parents[7]
rel=lambda p:p.relative_to(ROOT).as_posix()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
entries=[('move_contacts_v1','812e9340-84d2-4f11-aaa9-c577011d9deb',[HERE/'reference_neutral.png'],'rejected_same_leading_leg'),('move_contacts_v2','5ac1ed47-347b-46de-a56d-1f240823172a',[HERE/'reference_neutral.png',HERE/'pose_reference_foganchor_contacts.png'],'pending_motion_review'),('move_inbetweens_v1','599b465e-8a09-40a0-b704-8ed0a45ffdf4',[HERE/'reference_contact_a.png',HERE/'reference_contact_b.png'],'pending_motion_review')]
for stem,out,refs,status in entries:
    prompt=HERE/f'{stem}.prompt.txt';prompt.write_bytes(prompt.read_bytes().replace(b'\r\n',b'\n').rstrip(b'\n'))
    data={'generator':'built-in image_gen','source':rel(HERE/f'{stem}.png'),'source_sha256':sha(HERE/f'{stem}.png'),'prompt':rel(prompt),'prompt_sha256':sha(prompt),'references':[{'path':rel(p),'sha256':sha(p),'role':'pose_only' if 'foganchor' in str(p) else 'identity_or_contact_key'} for p in refs],'generation_output':'C:/Users/acorp/.codex/generated_images/01a0ccb1-654e-7aa2-af06-8bdc2dae09d2/exec-'+out+'.png','review_status':status}
    for ref in data['references']:
        if 'foganchor' in ref['path']:
            ref['generation_input_path']='art/units/source/generated/fluid_animation/batch_c/unit_veilmourn_dreamwake_foganchor_colossi/move_contacts_v1.png'
            ref['path']=rel(HERE/'pose_reference_foganchor_contacts.png')
            assert sha(HERE/'pose_reference_foganchor_contacts.png')==ref['sha256']
    (HERE/f'{stem}.provenance.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf8')
h=json.loads((HERE/'handoff.json').read_text());u=h['units'][0]
u['frames']=[f for f in u['frames'] if f['clip']!='move']
u['accepted_clips']=['idle','attack','hit','defend','death','dead','cast']
contact=HERE/'move_contacts_v2.png';middle=HERE/'move_inbetweens_v1.png'
items=[(contact,[0,0,887,887],[545,851],.2925)]
for i,anchor in enumerate([(310,492),(761,492),(1260,492)]):items.append((middle,[i*512,0,(i+1)*512,502],anchor,.5))
items.append((contact,[887,0,1774,887],[1237,858],.2925))
for i,anchor in enumerate([(310,991),(761,991),(1260,991)]):items.append((middle,[i*512,502,(i+1)*512,1024],anchor,.5))
indices=[];previews=[]
for n,(source,rect,anchor,scale) in enumerate(items):
    indices.append(len(u['frames']))
    regions=[rect] if n!=7 else [[1024,512,1536,1024],[1150,502,1210,512]]
    u['frames'].append({'name':f'move_{n:02d}','clip':'move','source':rel(source),'rects':regions,'anchor':anchor,'scale':scale})
    canvas=Image.new('RGBA',(320,288))
    for region in regions:
        patch=Image.open(source).convert('RGBA').crop(region)
        patch.putalpha(patch.getchannel('A').point(lambda p:0 if p<=8 else p))
        patch=patch.resize((round(patch.width*scale),round(patch.height*scale)),Image.Resampling.LANCZOS)
        canvas.alpha_composite(patch,(round(160+(region[0]-anchor[0])*scale),round(266+(region[1]-anchor[1])*scale)))
    previews.append(canvas)
u['clips']['move']={'indices':indices,'frame_msec':100,'loop':True,'static_frame':0}
u['source_scale_by_image'].update({rel(contact):.2925,rel(middle):.5})
u['source_scale_reason']+=' Walk keys original helmet-to-sole707px normalized0.2925; inbetween sheet414px normalized0.5, both207px body reference; all frames from each source share scale.'
u['visual_review']['notes']='Idle and all actions approved by root at game sizes. Move uses2 opposite contact keys plus6 originals; alternating foot depth now present, intermediate passing readability needs root motion review.'
(HERE/'handoff.json').write_text(json.dumps(h,indent=2)+'\n',encoding='utf8')
previews[0].save(HERE/'move_preview.webp',save_all=True,append_images=previews[1:],duration=100,loop=0,lossless=True)
sheet=Image.new('RGBA',(1280,576))
for i,frame in enumerate(previews):sheet.alpha_composite(frame,(i%4*320,i//4*288))
sheet.save(HERE/'move_preview.png')
print('move8 pending; existing accepted clips preserved')
