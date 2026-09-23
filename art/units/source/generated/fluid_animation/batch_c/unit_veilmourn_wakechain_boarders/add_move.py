import json,hashlib
from pathlib import Path
from PIL import Image,ImageDraw
D=Path(__file__).parent;R=Path.cwd()
# Eight original drawings selected from source contact and half-gait paintings, no reflected or duplicated poses.
spec=[('move_keys_v1',[0,0,887,887],[537,836],.285,'near_contact'),('move_v1',[512,0,1024,384],[817,369],.67,'near_load'),('move_far_half_v1',[724,0,1448,724],[1112,692],.34,'far_passing'),('move_far_half_v1',[1448,0,2172,724],[1862,692],.34,'far_reach'),('move_contacts_v2',[0,0,887,887],[540,865],.277,'far_contact'),('move_far_half_v1',[0,0,724,724],[438,704],.34,'far_load'),('move_inbetweens_v1',[512,0,1024,500],[787,488],.48,'near_passing'),('move_inbetweens_v1',[0,490,512,1000],[308,982],.48,'near_reach')]
h=json.loads((D/'handoff.json').read_text());u=h['units'][0];u['frames']=[f for f in u['frames'] if f['clip']!='move'];indices=[]
canvas=Image.new('RGBA',(1200,560),(35,42,35,255));dr=ImageDraw.Draw(canvas)
for i,(stem,rect,anchor,scale,phase) in enumerate(spec):
 indices.append(len(u['frames'])); f={'name':f'move_{i}','clip':'move','source':(D/(stem+'.png')).relative_to(R).as_posix(),'rects':[rect],'anchor':anchor,'scale':scale,'phase':phase,'alpha_noise_cutoff':8};u['frames'].append(f)
 im=Image.open(D/(stem+'.png')).crop(rect);im.putalpha(im.getchannel('A').point(lambda x:0 if x<=8 else x));im=im.resize((round(im.width*scale),round(im.height*scale))); ax=(anchor[0]-rect[0])*scale;ay=(anchor[1]-rect[1])*scale
 canvas.alpha_composite(im,(round((i%4)*300+150-ax),round((i//4)*280+265-ay)));dr.text(((i%4)*300+8,(i//4)*280+8),f'{i+1}: {phase}',fill='white')
u['clips']['move']={'indices':indices,'frame_msec':100,'loop':True,'static_frame':0};u['visual_review']['notes']='Eight-frame alternating gait assembled from original contact and half-cycle paintings; fixed scale per image, no mirroring/padding/warping. All seven actions pending coordinator review; no live catalogs changed.'
(D/'handoff.json').write_text(json.dumps(h,indent=2)+'\n');canvas.save(D/'move_review.png')
p=json.loads((D/'provenance.json').read_text()); sources={
'move_contacts_v2':('exec-c29ef091-1ad5-4c75-af7c-82a3c6bd9a45.png',['art/units/source/curated/unit_veilmourn_wakechain_boarders.png','art/units/source/generated/fluid_animation/batch_c/unit_veilmourn_dreamwake_foganchor_colossi/move_contacts_v1.png']),
'move_inbetweens_v1':('exec-6affa927-7bf0-4028-adab-798fe45c9be0.png',[(D/'move_keys_v1.png').relative_to(R).as_posix(),(D/'move_contacts_v2.png').relative_to(R).as_posix()]),
'move_far_half_v1':('exec-873fef5a-3a47-45e5-9ae3-a2ed80d2a9a5.png',[(D/'move_contacts_v2.png').relative_to(R).as_posix()])}
for stem,(out,refs) in sources.items():
 prompt=D/(stem+'.prompt.txt');raw=prompt.read_bytes().decode('utf-8-sig').strip();prompt.write_bytes(raw.encode('utf-8'))
 p['generations']=[v for v in p['generations'] if v['source']!=stem+'.png']
 p['generations'].append({'source':stem+'.png','source_sha256':hashlib.sha256((D/(stem+'.png')).read_bytes()).hexdigest(),'prompt_file':prompt.name,'prompt_sha256':hashlib.sha256(prompt.read_bytes()).hexdigest(),'tool':'image_gen.imagegen','generation_output':'C:/Users/acorp/.codex/generated_images/01a0ccd1-f6ce-7f42-b36a-45bac5e6eca7/'+out,'references':refs,'reference_sha256':[hashlib.sha256((R/ref).read_bytes()).hexdigest() for ref in refs],'status':'selected_frames_pending_review'})
for v in p['generations']:
 if v['source'] in ['move_keys_v1.png','move_v1.png']:v['status']='whole_cycle_rejected_selected_contact_frame_pending_review'
(D/'provenance.json').write_text(json.dumps(p,indent=2)+'\n');print(len(u['frames']),'frames pending')
