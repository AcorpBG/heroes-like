"""New immutable source takes addressing personally observed source defects."""
import json
import produce as p
import prepare

def attack_v2():
 out=p.SOURCE_DIR/'attack_h3_v2';out.mkdir(exist_ok=True)
 assert not (out/'sampling_submission.json').exists(),'Never overwrite submitted source'
 original=json.loads((p.SOURCE_DIR/'attack_h3_v1/config.json').read_bytes())
 c=dict(original)
 c['seed']=2026109132
 c['references']=[prepare.reference(i) for i in [16,5,6,19]]
 c['guides']=[[36,1],[58,2],[80,3]]
 c['prompt']=(prepare.IDENTITY+
  'Quiet physical arm exercise in an empty studio. Slowly bend the knees and bend the near RIGHT elbow, with the right hand wrapped around the same short wooden mallet handle. Raise the intact crescent-headed mallet beside the right shoulder. Move the right elbow forward and extend that same arm and gripped mallet horizontally toward SCREEN RIGHT, stopping in empty air in the supplied forward pose. The mallet is a solid dull brass crescent on an ordinary wooden handle, continuously attached to that right-hand grip, with its original moss tassel. Briefly hold that extended pose, then bend the same elbow and lower the mallet back to the ready pose. Left elbow keeps its original buckler beside the chest; the separate waist drum stays attached. Both boots remain grounded while the torso leans into this one short reach and recovers. All surfaces remain solid painted leather, wood and dull brass under completely steady diffuse studio illumination. Empty space surrounds the mallet throughout the entire movement; only the original character and its three original pieces of equipment are visible. ' +
  'Locked orthographic camera, fixed original body scale and support plane y576, ample margins. Plain quiet studio backdrop, no floor or scenery. A single continuous take with steady illumination and one controlled arm movement.').strip()
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
 p.write(out/'correction.json',dict(previous_take='attack_h3_v1',observed_defects=['Drawn white-yellow flash and particles at source frames38-49 cover the mallet.','At contact frame39, the original flash hides the mallet head and its matte becomes an empty pointing hand.','At windup frame30, the hand/handle silhouette stretches ambiguously.'],method='Retain original identity and equipped windup/contact guides, add original recovery guide19, and generate a new quiet solid-material studio arm exercise. No source-frame surgery, matte erasure or quality/model/settings change.'))
 print('PREPARED_CORRECTION attack_h3_v2',flush=True)

def ranged_v2():
 out=p.SOURCE_DIR/'ranged_h3_v2';out.mkdir(exist_ok=True)
 assert not (out/'sampling_submission.json').exists(),'Never overwrite submitted source'
 c=dict(json.loads((p.SOURCE_DIR/'ranged_h3_v1/config.json').read_bytes()))
 c['seed']=2026109236
 c['references']=[prepare.reference(i) for i in [16,9,10,19]]
 c['guides']=[[24,1],[42,2],[60,1],[78,2],[92,3],[108,0]]
 c['last']=0
 c['prompt']=(prepare.IDENTITY+
  'A quiet musician practices two slow controlled taps on the separate strapped waist drum in an empty studio. Bend the near RIGHT elbow and raise the original mallet beside the shoulder, then lower its solid dull brass crescent head to touch the front waist drum. Raise the same mallet once more beside the shoulder and make a second gentle drum tap. After that second tap, bend the same right elbow, hold the original wooden handle close to the sternum in the supplied recovery pose, and slowly lower it beside the right hip to the supplied ready pose. Exactly two taps followed by this simple gradual recovery, with no extra flourish. The right fingers stay continuously closed around the same visible wooden shaft, the brass crescent head stays solid with constant shape and steady illumination, and the original moss tassel follows naturally. The original far LEFT buckler stays beside the chest, separate from the waist drum. Both boots stay planted. Calm controlled motions with crisp opaque hands and equipment throughout. Only this original character and its three original pieces of equipment are visible. Locked orthographic studio camera, unchanged body scale and support plane y576. Flat magenta backdrop, ample margins, steady diffuse light, no floor or scenery. No flashes, particles, emitted projectiles, symbols or extra weapons.').strip()
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
 p.write(out/'correction.json',dict(previous_take='ranged_h3_v1',observed_defects=['Original recovery104-109 morphs the crescent head and gripping wrist into purple/brown blurred blocks.'],method='Use original two drum-contact guides plus explicit original chest and ready recovery guides for a new slow quiet two-tap take. Preserve the rejected original. No frame skipping, anatomy painting or settings change.'))
 print('PREPARED_CORRECTION ranged_h3_v2',flush=True)

def death_v2():
 out=p.SOURCE_DIR/'death_h3_v2';out.mkdir(exist_ok=True)
 assert not (out/'sampling_submission.json').exists(),'Never overwrite submitted source'
 c=dict(json.loads((p.SOURCE_DIR/'death_h3_v1/config.json').read_bytes()))
 c['seed']=2026109237
 c['references']=[prepare.reference(i) for i in [16,12,13,14,15]]
 c['guides']=[[30,1],[44,1],[66,2],[78,2],[102,3]]
 c['last']=4
 c['prompt']=(prepare.IDENTITY+
  'One slow continuous supported collapse in an empty quiet studio. Flex both knees and lower into the supplied equipped kneeling pose. Keep the near RIGHT fingers closed around the original mallet shaft and slowly lower that whole intact arm and mallet outside the waist drum toward the ground. Shift the hips gently onto the ground and extend that same opaque right forearm into the supplied seated support pose, still holding the same mallet; show a continuous solid wrist, hand, wooden handle and brass crescent throughout this slow transition. The hand and mallet stay outside the separate strapped waist drum. Keep both original folded legs and boots present, and the far LEFT arm with its attached wooden buckler beside the body. From the supported seated pose slowly lower the torso and both folded legs onto the ground. End in the supplied intact resting corpse with the mallet beside the near hand, buckler beside the head and drum still attached at the waist. Hold the final corpse still. All movements are gradual physical joint movements with solid opaque original materials under steady light. Locked orthographic camera, unchanged anatomical scale, fixed support plane y576, plain flat magenta backdrop, generous margins, no floor or scenery. No cuts, abrupt pose replacement, extra limbs, disintegration, ghosting, flashes or resurrection.').strip()
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
 p.write(out/'correction.json',dict(previous_take='death_h3_v1',observed_defects=['Original kneel-to-seat transition60-61 blurs the right forearm, wrist and mallet grip into a translucent claw-like smear beside the drum.'],method='Repeat original equipped kneel and seated-support guides to stabilize the physical transition and request a slow continuous opaque arm/hand path outside the drum. Preserve the rejected original and all recipes. No transition skipping, painting or settings change.'))
 print('PREPARED_CORRECTION death_h3_v2',flush=True)

def death_v3():
 out=p.SOURCE_DIR/'death_h3_v3';out.mkdir(exist_ok=True)
 assert not (out/'sampling_submission.json').exists(),'Never overwrite submitted source'
 c=dict(json.loads((p.SOURCE_DIR/'death_h3_v2/config.json').read_bytes()))
 c['seed']=2026109337
 guides=p.SOURCE_DIR/'death_guides_v3'
 seated=dict(name='seated_closed_grip',source=(guides/'seated_closed_grip_original.png').relative_to(p.ROOT).as_posix(),rects=[[0,0,1537,1023]],anchor=[768,921],scale=.3125,alpha_noise_cutoff=8)
 half=dict(name='supported_half_side_fall',source=(guides/'half_side_fall_original.png').relative_to(p.ROOT).as_posix(),rects=[[0,0,1536,1024]],anchor=[768,880],scale=.2,alpha_noise_cutoff=8)
 c['references']=[prepare.reference(16),prepare.reference(12),seated,half,prepare.reference(14),prepare.reference(15)]
 c['guides']=[[24,1],[52,2],[76,3],[100,4]]
 c['last']=5
 c['prompt']=(prepare.IDENTITY+
  'One quiet continuous supported collapse with the original equipment. Slowly bend both knees and lower into the supplied equipped kneeling pose. Without opening the near RIGHT-hand grip, lower that same intact mallet and shift the hips onto the ground into the supplied seated pose with a solid closed right hand around the wooden handle outside the separate waist drum. Gradually turn the hips and fold both legs while lowering the torso toward SCREEN RIGHT onto the near right forearm, passing through the supplied halfway side-fall pose. The right wrist, fingers and wooden mallet shaft stay solid and visibly connected, and the brass crescent head remains intact beside the hand. Continue slowly lowering the torso and both folded legs onto the ground into the supplied prone and final corpse poses. The far LEFT arm lowers its attached buckler beside the head and the separate strapped waist drum remains at the waist. Every joint transition is gradual with clear opaque hands, arms, legs and equipment. No fast flailing or extra flourish. Hold the final intact equipped corpse still. Locked orthographic camera, fixed original anatomical scale and support plane y576, empty flat magenta studio background, generous margins and steady diffuse illumination. Only the original character, one gripped mallet, one attached buckler and one strapped drum are visible. No cuts, abrupt pose replacement, duplicated equipment, ghosting, leafy substitute limbs, disintegration, effects or resurrection.').strip()
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
 p.write(out/'correction.json',dict(previous_take='death_h3_v2',observed_defects=['Right wrist remains ghosted at57 during the kneel-to-seat transition.','At late side-fall98 the near arm and mallet become a leaf-like smear;99-100 have malformed/doubled head silhouettes.'],method='Use built-in imagegen only to create a closed-grip derivative of the original seated painting and a physically supported intermediate side-fall guide, with their exact original/reference/prompt hashes and fixed whole-guide anatomical scales. Generate a completely new H3 take with evenly spaced original/derivative keyposes. No animation-frame painting, transition skipping or quality/model/settings change.'))
 print('PREPARED_CORRECTION death_h3_v3',flush=True)

def death_v4():
 out=p.SOURCE_DIR/'death_h3_v4';out.mkdir(exist_ok=True)
 assert not (out/'sampling_submission.json').exists(),'Never overwrite submitted source'
 c=dict(json.loads((p.SOURCE_DIR/'death_h3_v3/config.json').read_bytes()))
 c['seed']=2026109437
 c['references']=[prepare.reference(16),prepare.reference(15)]
 c['guides']=[];c['last']=1
 c['prompt']=(prepare.IDENTITY+
  'A single uninterrupted animation of this equipped drummer slowly collapsing onto the ground. Start moving immediately: knees steadily bend, the torso leans sideways toward SCREEN RIGHT, the hips descend, and both knees settle onto the ground. Without pausing in a posed tableau, continue the same physical movement: the near right elbow bends to brace the descending body, hips and both folded legs roll gently onto the side, the head lowers, and the body comes to rest in the supplied equipped corpse position. Make the joint movement continuous across the entire take, with many clearly different intermediate body positions. Keep the near RIGHT fingers firmly wrapped around the same short wooden mallet shaft throughout; its solid brass crescent head and moss tassel follow the wrist outside the strapped waist drum. The far LEFT arm keeps its original round buckler attached, lowering it beside the head. The separate crescent-marked waist drum stays firmly strapped to the torso and turns with it. Exactly two human arms and two legs remain anatomically connected and opaque during the gradual supported fall. Original boots, youthful face, long brown hair, crest, costume and original painted materials remain consistent. Finish the collapse around four seconds and let the equipment and cloak settle naturally into the supplied final resting pose. Stationary orthographic camera, fixed body scale, unchanged ground support plane y576, generous empty margins, steady diffuse illumination, flat magenta background without a visible floor. No pauses between descent stages, cuts, pose replacement, extra limbs, transferred equipment, blur, ghosting, disintegration, flashes or resurrection.').strip()
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
 p.write(out/'correction.json',dict(previous_take='death_h3_v3',observed_defects=['Abrupt original pose replacements23-to24,35-to36 and75-to76 after long nearly frozen holds.','Near right-hand grip becomes blurred at74-75 immediately before the side fall.'],method='Retain original ready and final equipped corpse endpoints but remove the intermediate still-guide constraints. Request one continuously moving supported collapse with no stage pauses and intact gripping anatomy. Preserve all prior originals and derivative guides. No generated animation-frame editing, frame skipping or model/quality/settings changes.'))
 print('PREPARED_CORRECTION death_h3_v4',flush=True)

def death_v5():
 out=p.SOURCE_DIR/'death_h3_v5';out.mkdir(exist_ok=True)
 assert not (out/'sampling_submission.json').exists(),'Never overwrite submitted source'
 c=dict(json.loads((p.SOURCE_DIR/'death_h3_v4/config.json').read_bytes()))
 c['seed']=2026109537;c['anchor']=[480,528]
 c['prompt']=c['prompt'].replace('support plane y576','support plane y528').replace('generous empty margins','generous empty margins, with the entire held mallet and its tassel always inside the frame')
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
 p.write(out/'correction.json',dict(previous_take='death_h3_v4',observed_defects=['Mallet tassel reaches source bottom edge during the supported descent47-57; up to29 alpha>=8 border pixels.'],method='Translate both original ready/corpse guides upward48 pixels together and adjust the fixed source anchor by the same48 pixels. Same anatomy scale, canvas, model, sampling and matting settings. Endpoint-only continuous physical collapse retained; no animation-frame repositioning or transition omission. Preserve all prior source originals.'))
 print('PREPARED_CORRECTION death_h3_v5',flush=True)

if __name__=='__main__':
 import argparse
 parser=argparse.ArgumentParser();parser.add_argument('takes',nargs='+',choices=['attack_v2','ranged_v2','death_v2','death_v3','death_v4','death_v5']);args=parser.parse_args()
 for name in args.takes:globals()[name]()
