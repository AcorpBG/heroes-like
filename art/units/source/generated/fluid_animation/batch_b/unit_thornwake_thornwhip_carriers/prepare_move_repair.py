"""Pack eight original opposing-contact gait paintings; no generated motion pixels."""
from pathlib import Path
import json, hashlib
from PIL import Image
from prepare_handoff import components, ROOT, D

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

sources={
 'move_contacts_v1':{'anchors':[515,1290],'output':'exec-0f2bbb70-ecb4-40a4-9e1a-18d4ef3bba86.png'},
 'move_between_a_v1':{'anchors':[355,977,1600],'output':'exec-7a58f514-d0e4-418c-b0cf-7cc2471ff4e9.png'},
 'move_between_b_v1':{'anchors':[355,977,1600],'output':'exec-51d1332f-7ec3-4539-acf5-ec994203ff42.png'},
}
frames_by_source={};new_lineage=[]
for stem,spec in sources.items():
 path=D/(stem+'.png');im=Image.open(path).convert('RGBA')
 comps=sorted([c for c in components(path) if c['pixels']>1000],key=lambda c:c['rect'][0])
 assert len(comps)==len(spec['anchors'])
 fs=[]
 for i,c in enumerate(comps):
  l,t,r,b=c['rect'];crop=im.crop(c['rect']);mask=Image.new('L',crop.size,0);px=mask.load();alpha=im.getchannel('A')
  for x,y in c['points']:px[x-l,y-t]=alpha.getpixel((x,y))
  crop.putalpha(mask);dest=D/(stem+'_'+str(i).zfill(2)+'.png');crop.save(dest)
  fs.append({'name':'move_repaired_'+stem+'_'+str(i),'clip':'move','source':dest.relative_to(ROOT).as_posix(),'rects':[[0,0,crop.width,crop.height]],'anchor':[spec['anchors'][i]-l,b-t-1],'scale':.245,'original_source':path.relative_to(ROOT).as_posix(),'original_rect':c['rect']})
 frames_by_source[stem]=fs
 prompt=D/(stem+'.prompt.txt');prompt.write_bytes(prompt.read_bytes().rstrip(b'\r\n'))
 refs=[ROOT/'art/units/source/curated/unit_thornwake_thornwhip_carriers.png']
 if stem=='move_contacts_v1':refs.insert(0,ROOT/'art/units/source/generated/fluid_animation/batch_c/unit_veilmourn_dreamwake_foganchor_colossi/move_contacts_v1.png')
 else:refs=[D/('move_reference_'+('a' if '_a_' in stem else 'b')+'.png')]
 new_lineage.append({'master':path.relative_to(ROOT).as_posix(),'master_sha256':sha(path),'prompt':prompt.relative_to(ROOT).as_posix(),'prompt_sha256':sha(prompt),'tool':'built-in image_gen','generation_output':'C:/Users/acorp/.codex/generated_images/01a0ccd0-7438-70d0-93ac-b743b9008386/'+spec['output'],'references':[{'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)} for p in refs],'processing':'Original alpha component crop only, alpha<=8 removed; anatomy unchanged.'})
c=frames_by_source['move_contacts_v1'];a=frames_by_source['move_between_a_v1'];b=frames_by_source['move_between_b_v1']
ordered=[c[0],a[0],a[1],c[1],b[0],b[1],b[2],a[2]]
h=json.loads((D/'handoff.json').read_text());u=h['units'][0];u['frames'][:8]=ordered
u['source_scale_by_image']={f['source']:f['scale'] for f in u['frames']}
u['source_scale_reason']+=' Repaired movement uses a single .245 scale on all three new gait masters: standing bodies are about827px. Contact/intermediate images retain identical source body volume; no per-pose normalization.'
u['visual_review']['artist_observation']+=' Movement v1 held after coordinator saw same leg leading. Repaired sequence has opposing toward-camera contacts and six original inbetweens ordered near heel/down/far pass/far heel/down/near pass/near reach/near heel reach. Pending gait review.'
(D/'handoff.json').write_text(json.dumps(h,indent=2)+'\n')
p=json.loads((D/'provenance.json').read_text());p['sources']+=new_lineage;p.setdefault('rejected_sources',[]).append({'master':'move_v1.png','reason':'Repeated leading leg in both halfcycles; retained original source, not current movement handoff.'});p['move_reference_crops']={'source':'move_contacts_v1.png','processing':'Exact left/right alpha bounding crops only'}
(D/'provenance.json').write_text(json.dumps(p,indent=2)+'\n')
print('Replaced only eight movement frames with opposing-contact paintings')
