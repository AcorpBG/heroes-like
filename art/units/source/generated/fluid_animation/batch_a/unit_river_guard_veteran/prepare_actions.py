"""Crop/pack original painted action sequences, preserving per-source body scale."""
from pathlib import Path
import hashlib,json
from PIL import Image

HERE=Path(__file__).resolve().parent
ROOT=Path(__file__).resolve().parents[7]
rel=lambda p:p.relative_to(ROOT).as_posix()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
outputs={'attack_v1':'cde371fa-d23b-481e-bc85-c1292388ec30','attack_v2':'8d47540c-2ca2-4cfa-af61-96e97a7a619a','move_v1':'e3e9e232-b489-4f03-b3fc-c23de96265b5','move_v2':'f5d791a4-2825-4033-ba07-472c6bfb843e','reactions_v1':'45ec200c-49ac-4fd6-96b8-2852499a97bd','death_v1':'54d97a72-0a4c-469e-a0de-276c265d8625','support_v1':'4d77eaae-4622-4d72-bb7e-299f3ffa2af0'}
outputs.update({'move_v3':'7ddd2daf-50c8-4d0a-87e1-b7cfa0704c95','move_opposite_v1':'90f68a51-c58b-4542-8772-696f274f03ed','move_return_v1':'a3fc0cd9-c1cb-4604-8b99-95ff187046de'})
for stem,output in outputs.items():
    prompt=HERE/f'{stem}.prompt.txt'
    prompt.write_bytes(prompt.read_bytes().replace(b'\r\n',b'\n').rstrip(b'\n'))
    refs=[HERE/('attack_v1.png' if stem=='attack_v2' else ('reference_upperbody.png' if stem=='move_v3' else 'reference_neutral.png'))]
    if stem=='move_return_v1':refs=[HERE/'move_opposite_v1.png',HERE/'reference_neutral.png']
    status='rejected_non_alternating_gait' if stem.startswith('move_') else ('rejected_reversed_spear_frame2' if stem=='attack_v1' else 'pending_motion_review')
    data={'generator':'built-in image_gen','source':rel(HERE/f'{stem}.png'),'source_sha256':sha(HERE/f'{stem}.png'),'prompt':rel(prompt),'prompt_sha256':sha(prompt),'references':[{'path':rel(p),'sha256':sha(p)} for p in refs],'generation_output':'C:/Users/acorp/.codex/generated_images/01a0ccb1-654e-7aa2-af06-8bdc2dae09d2/exec-'+output+'.png','review_status':status}
    (HERE/f'{stem}.provenance.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf8')

handoff=json.loads((HERE/'handoff.json').read_text())
u=handoff['units'][0]
u['frames']=u['frames'][:8]
u['clips']={k:v for k,v in u['clips'].items() if k=='idle'}
u['accepted_clips']=['idle']
u['visual_review']['notes']='Root approved idle rendered at128/64. Action sequences pending root motion review. Rejected move drafts are not in handoff.'

def add(clip,stem,rects,anchors,scale,msec,**kwargs):
    source=HERE/f'{stem}.png'
    image=Image.open(source).convert('RGBA')
    indices=[]; previews=[]
    for n,(regions,anchor) in enumerate(zip(rects,anchors)):
        indices.append(len(u['frames']))
        u['frames'].append({'name':f'{clip}_{n:02d}','clip':clip,'source':rel(source),'rects':regions,'anchor':list(anchor),'scale':scale})
        canvas=Image.new('RGBA',(384,288))
        for box in regions:
            patch=image.crop(box)
            patch.putalpha(patch.getchannel('A').point(lambda p:0 if p<=8 else p))
            patch=patch.resize((round(patch.width*scale),round(patch.height*scale)),Image.Resampling.LANCZOS)
            canvas.alpha_composite(patch,(round(192+(box[0]-anchor[0])*scale),round(266+(box[1]-anchor[1])*scale)))
        previews.append(canvas)
    u['clips'][clip]={'indices':indices,'frame_msec':msec,'loop':clip in ('defend','cast'),'static_frame':0,**kwargs}
    u['source_scale_by_image'][rel(source)]=scale
    previews[0].save(HERE/f'{clip}_preview.webp',save_all=True,append_images=previews[1:],duration=msec,loop=0,lossless=True)
    contact=Image.new('RGBA',(384*4,288*((len(previews)+3)//4)))
    for n,frame in enumerate(previews):contact.alpha_composite(frame,(n%4*384,n//4*288))
    contact.save(HERE/f'{clip}_preview.png')

attack=[[[0,0,443,443]],[[443,0,887,443]],[[887,0,1331,443]],[[1331,0,1774,443]],[[0,443,440,887],[440,560,525,700]],[[525,443,965,887],[440,700,525,887]],[[965,443,1332,887]],[[1332,443,1774,887]]]
add('attack','attack_v2',attack,[(194,435),(630,435),(1081,435),(1487,435),(167,858),(613,858),(1082,858),(1530,864)],.58,90,contact_frame=4)
reaction_rects=[[[i%4*384,i//4*512,(i%4+1)*384,(i//4+1)*512]] for i in range(8)]
reaction_anchors=[(213,500),(596,500),(981,500),(1365,500),(207,1000),(591,1000),(975,1000),(1359,1000)]
add('hit','reactions_v1',reaction_rects[:4],reaction_anchors[:4],.5,95)
add('defend','reactions_v1',reaction_rects[4:],reaction_anchors[4:],.5,120)
death_rects=[[[[0,443,887,1331][i%4],0 if i<4 else 493,[443,887,1331,1774][i%4],493 if i<4 else 887]] for i in range(8)]
add('death','death_v1',death_rects,[(206,475),(649,475),(1116,475),(1548,475),(225,814),(664,818),(1105,835),(1550,835)],.55,110)
u['clips']['dead']={'indices':[u['clips']['death']['indices'][-1]],'frame_msec':1000,'loop':False,'static_frame':0}
support_anchors=[(208,493),(591,493),(976,493),(1360,493),(208,1007),(591,1007),(976,1007),(1360,1007)]
add('cast','support_v1',reaction_rects,support_anchors,.5,110,gesture_kind='nonmagical_spear_salute')
u['source_scale_reason']='Source-wide resolution normalization only: original idle486px spear-to-sole x0.5; return608px x0.4. Other1536x1024 standing sheets use0.5. Attack1774x887 bodyheight356px x0.58 and death standing skeletonapprox375px x0.55 match original207px helmet-to-sole reference. Collapse is never resized per pose.'
(HERE/'handoff.json').write_text(json.dumps(handoff,indent=2)+'\n',encoding='utf8')
print({k:len(v['indices']) for k,v in u['clips'].items()})
