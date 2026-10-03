"""Repair only the airborne companion interval; preserve body and later landing."""
from pathlib import Path
import json,hashlib
import numpy as np
from scipy.ndimage import label
from PIL import Image
import produce as p
S=Path(__file__).parent;R=p.ROOT;T=S/'companion_clearance_h3_v2'
assert not T.exists(),'Immutable new take only'
B=R/'art/units/source/generated/fluid_animation/batch_c/unit_neutral_cliffhawk_wardens/death_h3_v1'
records=[]
for i,seed in [(40,(640,205)),(48,(785,150))]:
 a=np.array(Image.open(B/f'matte/rgba_{i:03}.png').convert('RGBA'));labs,n=label(a[:,:,3]>=8,np.ones((3,3)))
 component=int(labs[seed[1],seed[0]]);assert component
 mask=labs==component;assert 3000<int(mask.sum())<20000
 a[~mask]=0;target=S/f'original_safe_flight_{i:03}.png';assert not target.exists();Image.fromarray(a).save(target)
 records.append(dict(original_frame=i,source=(B/f'matte/rgba_{i:03}.png').relative_to(R).as_posix(),component_seed=list(seed),component_pixels=int(mask.sum()),derived=target.name,sha256=p.sha(target),rule='Exactly one detached original bird component; unchanged RGBA inside it'))
end=S/'companion_h3_v1/matte_plate_v3/rgba_040.png'
names=[S/'original_airborne_hawk_canvas.png',S/'original_safe_flight_040.png',S/'original_safe_flight_048.png',end]
c=json.loads((S/'companion_h3_v1/config.json').read_bytes())
c['references']=[dict(source=x.relative_to(R).as_posix(),rects=[[0,0,960,544]],anchor=[480,480],scale=.5,alpha_noise_cutoff=0) for x in names]
c['last']=3;c['guides']=[[12,1],[98,2]];c['seed']=202610031236
c['prompt']='One small natural brown-and-cream hawk from the supplied reference, alone in the elevated three-quarter orthographic fantasy strategy sprite camera, facing screen-right. One head with a dark hooked beak and natural dark eyes, cream breast, brown feathered back, exactly TWO feathered wings, one intact tail and exactly TWO natural taloned feet. Preserve the original feather markings, fixed body size and proportions. Locked camera. Starting already airborne at the first supplied position, the hawk travels smoothly rightward in the HIGH safe interior flight corridor shown by the two intermediate references. Natural continuous reciprocal wingbeats; every full wing stays above the lower-left area occupied by its departed shoulder. Keep the whole bird clear of the lower-left and lower-middle canvas. Near the end it gently descends into the supplied final airborne pose, with both wings and feet still visible. The whole body, beak, wing tips, feet and tail remain well inside every border throughout. This is only the airborne departure interval; no touchdown or final standing pose. Uniform flat unchanged MAGENTA RGB255,0,255 background throughout; no floor, scenery, shadow, human, spear, second bird, extra limbs, armor, text, smoke, glow, sparks or magic.'
T.mkdir();p.write(T/'config.json',c);p.prepare(T,c);p.verify(T,c)
p.write(T/'interval_recipe.json',dict(original_body='All original 43 selected body frames remain exact',replaces_companion_interval=[0,40],retained_companion_interval=[41,122],retained_take='companion_h3_v1',original_flight_controls=records,end_reference_sha256=p.sha(end),settings='Unchanged 960x544 /124 /20 res_multistep simple /tiled VAE',status='pending full personal source and seam review'))
for i,x in enumerate(names):
 original=np.array(Image.open(x).convert('RGBA'));actual=np.array(Image.open(T/f'guide_{i}_rgba.png').convert('RGBA'))
 assert np.array_equal(original,actual),'Guide geometry changed'
 opaque=original[:,:,3]>=250;chroma=np.minimum(original[:,:,0].astype(int),original[:,:,2].astype(int))-original[:,:,1]
 print('GUIDE',i,Image.fromarray(original[:,:,3]).getbbox(),'opaque_chroma',int(chroma[opaque].max()),flush=True)
print('PREPARED_AFFECTED_INTERVAL',T.name,flush=True)
