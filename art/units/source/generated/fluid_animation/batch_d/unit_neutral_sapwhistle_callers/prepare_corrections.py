"""Targeted blue-plate gait and physical shove corrections, preserving rejects."""
import json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import produce as p
from prepare_h3 import ref, IDENTITY, PLATE

def make(name, references, guides, action, seed):
    out = p.SOURCE_DIR/name
    out.mkdir(exist_ok=True)
    assert not (out/"submission.json").exists(), "Submitted take is immutable"
    identity = IDENTITY.replace('dart launcher','brass tube').replace('launcher length','tube length')
    c = dict(unit_id='unit_neutral_sapwhistle_callers',clip=name.split('_')[0],canvas=[960,640],
             anchor=[470,560],scale=.5,key_rgb=[0,0,255],seed=seed,references=references,
             guides=guides,last=0,prompt=(identity+action+PLATE.replace('magenta RGB255,0,255','blue RGB0,0,255')).strip(),
             tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
    p.prepare(out,c)
    bands=[]
    for i in range(len(references)):
        a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float)
        mask=binary_erosion(a[:,:,3]>240,iterations=3)
        bands.append(float((a[:,:,2]-np.maximum(a[:,:,0],a[:,:,1]))[mask].max()))
    c['protected_foreground_chroma']=max(0,int(max(bands))+2)
    c['foreground_measurement']=dict(rule='Eroded opaque blue-minus-max(red,green) maximum plus two across original guides.',per_guide_max=bands)
    p.write(out/'config.json',c)

if __name__=='__main__':
    lift=dict(name='whistle_side_knee_lift',source=(p.SOURCE_DIR/'walk_lift_v1.png').relative_to(p.ROOT).as_posix(),
              rects=[[0,0,*Image.open(p.SOURCE_DIR/"walk_lift_v1.png").size]],anchor=[735,945],scale=.223,alpha_noise_cutoff=8)
    make('move_h3_v2',[ref(17),lift,ref(2)],[[28,1],[76,2]],
         'Perform ONE slow complete walking stride cycle in place, consisting of two opposite steps. '
         'First transfer weight to the leg under the tube-bearing arm and lift the OTHER knee high as in the first middle reference. '
         'Swing that raised foot forward, lower its heel and transfer weight onto it. '
         'Now lift the opposite foot, pass its knee forward and extend that leg into the second middle reference. '
         'Finish back in the initial stance. Each leg must take one complete forward step while the other supports the body. '
         'Hips stay centered, the hand keeps the same short brass tube securely pointed down-right; cloak follows the stride. ',2026093800)
    make('attack_h3_v2',[ref(17),ref(4),ref(5)],[[28,1],[52,2]],
         'Perform one silent physical left-arm pushing exercise. Bend the left elbow to draw the held short brass tube toward the chest. '
         'Shift weight forward and extend the left arm forcefully toward screen right, pushing the entire rigid tube forward as one object. '
         'Briefly hold the fully extended arm, then bend the elbow and lower the hand back to the initial stance. '
         'The fingers stay wrapped around the same handle throughout. The tube remains inert; only the arm, body and attached clothing move. '
         'The surrounding flat blue space remains completely empty in every frame. ',2026093801)
    d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    d['takes']=[t.replace('move_h3_v1','move_h3_v2').replace('attack_h3_v1','attack_h3_v2') for t in d['takes']]
    d['rejected_takes']={
        'move_h3_v1':'All124 originals reviewed: color cycling; clean early section still repeats a predominantly single-leg step with the other planted. Reject, guide missing lifted-knee phase and slower complete two-step cycle.',
        'attack_h3_v1':'All124 originals reviewed: color-cycling background and unwanted muzzle flash/projectile during purported melee shove. Reject, use blue plate and inert-tube arm-extension wording.'}
    for take,reason in d['rejected_takes'].items():p.write(p.SOURCE_DIR/take/'rejection.json',dict(status='rejected',reason=reason))
    p.write(p.SOURCE_DIR/'delivery.json',d)
