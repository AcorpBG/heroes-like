"""Extract original coil-check idle and append to current unit handoff."""
import json,hashlib
from PIL import Image
from prepare_handoff import D,ROOT,components

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
master=D/'idle_v2.png';im=Image.open(master).convert('RGBA')
comps=sorted([c for c in components(master) if c['pixels']>1000],key=lambda c:c['rect'][1])
comps=[c for row in range(4) for c in sorted(comps[row*2:row*2+2],key=lambda c:c['rect'][0])]
assert len(comps)==8
h=json.loads((D/'handoff.json').read_text());u=h['units'][0]
u['frames']=[f for f in u['frames'] if f['clip']!='idle'];start=len(u['frames'])
for i,c in enumerate(comps):
 l,t,r,b=c['rect'];crop=im.crop(c['rect']);mask=Image.new('L',crop.size,0);px=mask.load();a=im.getchannel('A')
 for x,y in c['points']:px[x-l,y-t]=a.getpixel((x,y))
 crop.putalpha(mask);dest=D/('idle_v2_'+str(i).zfill(2)+'.png');crop.save(dest)
 anchor_x=[313,711,313,711,313,711,313,711][i]
 u['frames'].append({'name':'idle_'+str(i).zfill(2),'clip':'idle','source':dest.relative_to(ROOT).as_posix(),'rects':[[0,0,crop.width,crop.height]],'anchor':[anchor_x-l,b-t-1],'scale':.56,'original_source':master.relative_to(ROOT).as_posix(),'original_rect':c['rect']})
u['clips']['idle']={'indices':list(range(start,start+8)),'frame_msec':150,'loop':True,'static_frame':0}
u['preserve_clips']=[];u['source_scale_by_image']={f['source']:f['scale'] for f in u['frames']}
u['source_scale_reason']+=' New idle master uses fixed .56 for all8 poses (about362px source standing body).'
u['visual_review']['artist_observation']+=' Existing idle rejected by coordinator at128px. New idle visibly raises free hand/coil from hip to chest, rotates outward and lowers/regrips; idle_v1 bottom boots clipped, v2 generated layout repair restores soles and alpha margins. Pending acceptance.'
(D/'handoff.json').write_text(json.dumps(h,indent=2)+'\n')
p=json.loads((D/'provenance.json').read_text())
for stem,out,ref in [('idle_v1','exec-79989b90-82a5-4223-9a19-8c10da0e44b5.png',ROOT/'art/units/source/curated/unit_thornwake_thornwhip_carriers.png'),('idle_v2','exec-853695a3-7db7-4f11-a018-9a47736317cf.png',D/'idle_v1.png')]:
 path=D/(stem+'.png');prompt=D/(stem+'.prompt.txt');prompt.write_bytes(prompt.read_bytes().rstrip(b'\r\n'))
 p['sources'].append({'master':path.relative_to(ROOT).as_posix(),'master_sha256':sha(path),'prompt':prompt.relative_to(ROOT).as_posix(),'prompt_sha256':sha(prompt),'reference':ref.relative_to(ROOT).as_posix(),'reference_sha256':sha(ref),'tool':'built-in image_gen','generation_output':'C:/Users/acorp/.codex/generated_images/01a0ccd0-7438-70d0-93ac-b743b9008386/'+out,'processing':'Original connected alpha crop only, alpha<=8 removal.'})
p.setdefault('rejected_sources',[]).append({'master':'idle_v1.png','reason':'Bottom boot soles clipped at canvas boundary; repaired by generated idle_v2.'})
(D/'provenance.json').write_text(json.dumps(p,indent=2)+'\n')
print('Appended8 original idle frames, kept approved actions and movement repair unchanged')
