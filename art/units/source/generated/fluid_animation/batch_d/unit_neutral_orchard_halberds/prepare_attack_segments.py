"""Second correction: isolate chop and recovery instead of six competing guides."""
import json
import produce as p
base=json.loads((p.SOURCE_DIR/'attack_h3_v2/config.json').read_bytes())
identity=base['prompt'].split('Perform ONE controlled')[0]
common=' Fixed elevated orthographic camera, fixed original body scale and planted foot registration. Exactly two arms and legs. Left arm holds the same wicker shield throughout; right hand grips one straight wooden shaft and its small single SILVER billhook blade. Move the weapon only within the image plane; never point toward the camera, enlarge the blade or spin the shaft. Full figure and all weapon tips remain inside the canvas. Uniform flat saturated blue background throughout. No scenery, light effects, trails, shadows or particles.'
specs={
 'attack_chop_h3_v3':([base['references'][i] for i in [0,1,4,2]],[[28,1],[72,2]],3,
  'Perform ONE slow overhead chop, then STOP with the blade down at screen right. Begin upright ready. Raise the right hand smoothly above the right shoulder into the supplied overhead windup. Bring the blade forward through the supplied horizontal chest-height intermediate pose. Continue downward toward screen right into the supplied low strike pose. The blade follows exactly ONE downward arc. Hold the final LOW position; DO NOT recover, raise the weapon again, rotate it in a circle or attack twice.'),
 'attack_recover_h3_v3':([base['references'][i] for i in [2,3,4,0]],[[25,1],[72,2]],3,
  'Perform ONLY the recovery after a completed chop. Start with the blade LOW at screen right. Set the raised rear boot down, regain a stable stance, bend the right elbow and lift the weapon gradually through the supplied horizontal chest-height pose. Continue lifting into the original vertical ready carry. Hold ready. This is ONE unhurried recovery, with no attack, overhead windup, downward swing, shaft spin or extra gesture.')}
for n,(name,(refs,guides,last,action)) in enumerate(specs.items()):
 out=p.SOURCE_DIR/name;out.mkdir(exist_ok=False)
 c=dict(base,references=refs,guides=guides,last=last,seed=2026092995+n,prompt=identity+action+common)
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
p.write(p.SOURCE_DIR/'attack_h3_v2/rejection.json',dict(status='rejected',defects=['The blade-size correction is mostly stable, but the six-guide full-action take invents multiple chops and shaft spins before/after the contact.'],correction='Reassess control: split one downward chop and one upward recovery into separate videos, each with two intermediate guides and action-specific endpoints. Reuse the reviewed original intermediate painting; no equivalent full-cycle retry.'))
print('Prepared two bounded attack segments')
