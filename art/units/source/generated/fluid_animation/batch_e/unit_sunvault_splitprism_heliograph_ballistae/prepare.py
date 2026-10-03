"""Prepare seven H3 action guides from personally inspected original paintings."""
import copy
import json
from PIL import Image, ImageDraw
import produce as p

def main():
    S=p.SOURCE_DIR
    original=json.loads((S/'original_pose_references.json').read_bytes())
    # One scale per original master. Body, wheel diameters and operator height
    # are registered to the live ready; never normalize an individual pose.
    master_scales={'continuity-alpha/ready-defense-margins.png':.45,
                   'continuity-alpha/rolling-four.png':.40,
                   'continuity-alpha/actions-four.png':.39,
                   'continuity-alpha/melee-pair.png':.28,
                   'continuity-alpha/death-hit.png':.36}
    refs=copy.deepcopy(original)
    for ref in refs:
        for suffix,scale in master_scales.items():
            if ref['source'].endswith(suffix):ref['scale']=scale
    refs.extend(json.loads((S/'contact_support_keys_v1/references.json').read_bytes()))
    identity=('One original ivory, gold and cobalt Heliograph Ballista, a mechanical fantasy siege carriage. '
        'Exactly two large cobalt-and-gold spoked wheels on one axle. Exactly three articulated stabilizer struts ending in gold star-shaped feet. '
        'One central tilted round blue-glass mirror with a gold rim, one long cobalt-blue crystalline front launcher pointing LEFT, and one shorter amber rear crystal arm pointing RIGHT. '
        'Exactly one ivory-and-gold armored human operator on the rear-right platform, blue helmet plume and blue cape, exactly two arms and two legs, hands on the original rear control crank. '
        'Preserve all original wheel diameters, axle, launcher lengths, mirror, gold fittings, limb counts and operator proportions. Fixed elevated three-quarter tactical camera facing LEFT. '
        'No camera move, zoom, new wheels, extra operators, added legs, changing colors, new weapon, text, scenery, floor plane, smoke, glow pulses, projectiles, rays, flash, sparks or particles. '
        'Use the same flat pale blue-gray background over the whole image in every frame. Entire carriage, tips and feet stay safely inside the frame. ')
    specs={
      'move_h3_v1':dict(indices=[2,3,4,5],guides=[[24,1],[48,2],[72,3],[96,0]],last=0,action='move',
        beats='With all three star-foot stabilizers folded tightly upward beside the chassis throughout travel, roll naturally in place on the two original wheels. Spokes turn continuously about their own fixed hubs, both wheels turn together. The operator performs a full hand-crank circle using bending elbows, knees softly balancing on the platform; cape follows the effort. Keep the same centered axle position and ground contact. Complete two steady rolling cycles and match the first rolling pose at the end. Do not deploy stabilizers during rolling, do not walk on them, do not replace rotation with whole-carriage sliding.'),
      'attack_h3_v1':dict(indices=[0,24],guides=[[42,1]],last=0,action='attack',
        beats='One physical melee counterthrust with the rigid chassis and front stabilizer. The operator draws the rear lever back while bending both elbows and bracing knees. Shift weight into the two original wheels and three star feet, thrust the front-left stabilizer and chassis toward LEFT for one blunt mechanical contact, then recoil and smoothly recover ready. The blue and amber crystals remain solid unfired equipment; do not shoot, cast or light them. Preserve all three star feet and exactly two wheels throughout.'),
      'ranged_h3_v1':dict(indices=[0,6,7],guides=[[24,1],[45,2]],last=0,action='ranged',
        beats='One deliberate firing cycle. Operator leans forward and turns the winding crank, mirror and blue front launcher aim LEFT. Pull the trigger with the same hand, the blue launcher recoils slightly on its original mount, both elbows and torso take the recoil, three star feet stay planted, then the operator winds back to original ready. Animate the mechanical firing anticipation, release and recovery only; the game draws the traveling shot separately. No projectile, beam, blast, flying crystal, second muzzle or altered launcher geometry.'),
      'hit_h3_v1':dict(indices=[0,12],guides=[[36,1]],last=0,action='hit',
        beats='One brief physical impact reaction: operator elbows recoil, torso leans back, knees bend, the mounted mirror tips slightly with the shock and chassis rocks gently onto planted original star feet. Wheels and all three feet remain intact. Recover hands on the original crank and return to ready. No collapse, ejection, flashing hit color or attacker.'),
      'defend_h3_v1':dict(indices=[0,10,11],guides=[[38,1],[64,2]],last=2,action='defend',
        beats='A dedicated defensive brace: lock the three articulated gold star feet down, lower the axle slightly between the original two wheels, rotate the round mirror more upright as cover and have the operator tuck behind it while retaining the crank grip. Reach the supplied distinct low brace, hold this protective pose through the end, no return to ready and no new shield.'),
      'cast_h3_v1':dict(indices=[0,25],guides=[[48,1]],last=0,action='cast',
        beats='A physical calibration and relay gesture, not magical casting. The operator visibly turns the rear crank through a measured half turn using both arms; the original central round blue-glass mirror pivots upward then gently rotates back to its original calibrated angle, pause to signal readiness, restore hands and stance. Three star feet stay planted, wheels remain still, launchers do not fire. No magical circle, halo, flash, new lens, added arm, moving projectile or invented light.'),
      'death_h3_v1':dict(indices=[0,13,14,15],guides=[[28,1],[66,2],[94,3]],last=3,action='death',
        beats='One continuous physical collapse: operator loses grip and knees buckle, three stabilizers fold under the carriage, the two-wheel chassis lowers and tilts to the supplied original low wreck. Operator slides off the same rear platform to the foreground ground, blue cape and both arms settle beside the fallen body. Mirror and both crystalline arms remain attached, wheels do not multiply. End in the supplied grounded dim wreck with one motionless fallen operator; all equipment rests naturally, no levitating pieces, disintegration, resurrection or return to ready.')}
    out=p.ROOT/'.artifacts/heliograph_ballista_h3/guides';out.mkdir(parents=True,exist_ok=True)
    for number,(take,spec) in enumerate(specs.items()):
        references=[refs[i] for i in spec['indices']]
        c=dict(unit_id=S.name,canvas=[960,704],scale=.45,anchor=[480,576],key_rgb=[190,206,222],seed=2026100340+number,
               references=references,guides=spec['guides'],last=spec['last'],prompt=(identity+spec['beats']).strip(),action=spec['action'],
               tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4),visual_review='pending_personal_guides_and_original_video',selection='not_selected',
               scale_reason='Fixed .45 extraction at preserved 256 reference height; complete ready master .45, rolling .40, actions .39, melee .28 and collapse .36 registered by wheel diameter, ivory chassis and operator height, never per-frame bounds or shrinking to fit atlas.')
        folder=S/take;folder.mkdir(exist_ok=True)
        if (folder/'sampling_submission.json').exists():assert json.loads((folder/'config.json').read_bytes())==c
        else:p.write(folder/'config.json',c);p.prepare(folder,c)
    all_guides=[S/take/f'guide_{i}_chroma.png' for take in specs for i in range(len(specs[take]['indices']))]
    for page in range((len(all_guides)+7)//8):
        review=Image.new('RGB',(1920,752),(27,38,29));draw=ImageDraw.Draw(review)
        for slot,file in enumerate(all_guides[page*8:(page+1)*8]):
            x,y=slot%4*480,slot//4*376
            review.paste(Image.open(file).resize((480,352),Image.Resampling.LANCZOS),(x,y+24))
            draw.text((x+6,y+5),file.parent.name+'/'+file.name,fill=(204,193,152))
        review.save(out/f'all_original_guides_{page}.png')
    # Actual native and enlarged registration of each guide, both facings.
    unique={}
    for spec in specs.values():
        for i in spec['indices']:unique[i]=refs[i]
    for reflected in [False,True]:
        for page in range((len(unique)+7)//8):
            review=Image.new('RGB',(1920,1000),(27,38,29));draw=ImageDraw.Draw(review)
            for slot,(i,ref) in enumerate(list(unique.items())[page*8:(page+1)*8]):
                x,y=slot%4*480,slot//4*500
                if slot%2:review.paste((221,213,197),(x,y,x+480,y+500))
                pose,(dx,dy)=p.source_pose(dict(ref,scale=ref['scale']*.5),8)
                if reflected:pose=pose.transpose(Image.Transpose.FLIP_LEFT_RIGHT);dx=-dx-pose.width
                for multiplier,origin in [(1,(x+170,y+206)),(2,(x+240,y+460))]:
                    im=pose.resize((pose.width*multiplier,pose.height*multiplier),Image.Resampling.NEAREST)
                    px,py=origin[0]+dx*multiplier,origin[1]+dy*multiplier
                    assert x<=px and px+im.width<=x+480 and y+25<=py and py+im.height<=y+500,(i,px,py,im.size)
                    review.paste(im,(px,py),im);draw.line((x+8,origin[1],x+470,origin[1]),fill=(105,132,81))
                draw.text((x+9,y+8),f'{i}: {ref["name"]}; original scale {ref["scale"]}',fill=(153,113,65))
            review.save(out/f'guide_registration_facing{int(reflected)}_{page}.png')
    brief=json.loads((S/'brief.json').read_bytes())
    brief['preserve']='All eight existing idle poses16-23 at240ms personally reviewed native128/enlarged on dark/light both facings. Stable two wheels, three star feet, operator hand-crank articulation and cape return; preserve their exact battle/map pixels, timing and anchors.'
    brief['guide_review']='Prepared from original master rectangles, alpha and per-master anatomical scales; guide registration and complete H3 canvases remain pending personal review. New clips not yet generated or accepted.'
    p.write(S/'brief.json',brief)
    print('SEVEN ORIGINAL H3 GUIDE SETS PREPARED; NO VIDEO ACCEPTED')

if __name__=='__main__':main()
