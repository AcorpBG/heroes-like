"""Inspect every preserved RGB frame before changing any extraction rule."""
from pathlib import Path
import json,av,numpy as np
from PIL import Image,ImageDraw
S=Path(__file__).parent;R=next(p for p in S.parents if (p/'project.godot').exists());T=S/'companion_clearance_h3_v2';O=R/'.artifacts/parallel_animation_20261002/middle53_completion_audit/cliffhawk-correction/interval-plate';O.mkdir(parents=True,exist_ok=True)
with av.open(str(T/'original_lossless.mkv')) as v:frames=[f.to_image().convert('RGB') for f in v.decode(video=0)]
stats=[]
for i,im in enumerate(frames):
 a=np.array(im);med=np.array([np.median(t.reshape(-1,3),axis=0) for t in [a[:24,:24],a[:24,-24:],a[-24:,:24],a[-24:,-24:]]]);stats.append(dict(frame=i,corners=med.tolist(),spread=float(np.linalg.norm(med-np.median(med,axis=0),axis=1).max())))
for start in range(0,124,12):
 page=Image.new('RGB',(1500,350*((min(12,124-start)+2)//3)),(24,30,24));d=ImageDraw.Draw(page)
 for j,im in enumerate(frames[start:start+12]):
  x=j%3*500;y=j//3*350;page.paste(im.crop((400,40,900,360)),(x,y));d.text((x+4,y+321),str(start+j)+' corners '+str(stats[start+j]['corners']),fill='white')
 page.save(O/f'raw-interval-{start//12}.png')
for i in [0,1,2,8,12,24,48,72,96,98,120,123]:frames[i].save(O/f'full-{i:03}.png')
(T/'plate_inspection.json').write_text(json.dumps(dict(status='pending personal review',stats=stats),indent=2)+'\n');print('RAW_INTERVAL_PAGES',11,[(r['frame'],round(r['spread'],1)) for r in stats[:15]])
