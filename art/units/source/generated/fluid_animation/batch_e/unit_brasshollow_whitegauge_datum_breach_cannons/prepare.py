"""Prepare original six-leg cannon and single-operator H3 guides on CPU."""
import hashlib,json,shutil,sys,urllib.request
from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
OUT=Path(__file__).resolve().parent
UID=OUT.name
BASE=ROOT/'.artifacts/parallel_animation_20261002'/UID
BASE.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(ROOT/'tools'))
from creature_animation_lock import exclusive
from integrate_fluid_creature_animation import old_pose,clip_indices,resolve
import produce

def write(path,v):path.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
with exclusive('content'):
 manifest=json.loads((ROOT/'content/unit_animation_manifest.json').read_bytes());row=next(r for r in manifest['items'] if r['unit_id']==UID)
 packing=json.loads((ROOT/f'art/animation/source/poses/{UID}/packing.json').read_bytes())
 if not (BASE/'baseline_manifest.json').exists():
  write(BASE/'baseline_manifest.json',manifest);shutil.copyfile(ROOT/'art/overworld/creature_idle.json',BASE/'baseline_map.json')
  shutil.copyfile(resolve(row['pose_sheet']),BASE/'baseline_atlas.png');shutil.copyfile(ROOT/f'art/overworld/runtime/creature_idle/{UID}.png',BASE/'baseline_map_idle.png')
  write(OUT/'original_unit_baseline.json',dict(unit=row,map=json.loads((ROOT/'art/overworld/creature_idle.json').read_bytes())['units'][UID],packing_sha256=produce.sha(ROOT/f'art/animation/source/poses/{UID}/packing.json')))
refs={}
for f in packing['frames']:
 r=dict(f);r['source']=f'art/animation/source/poses/{UID}/'+r['source'];r['alpha_noise_cutoff']=8;refs[f['name']]=r
 if f['name']=='guard_b':
  r['rects']=r['rects']+[[1018,543,1038,800]]
  r['crop_recipe']=dict(original_muzzle_recovery=[1018,543,1038,800],reason='Inherited x1038 crop clipped original muzzle rim. Added strip contains only original rim at y670..742; separator y790..810 has zero alpha, neighboring operator enters strip only at y852..880. Anchor/scale and all original pixels unchanged.')
identity=('One original WHITEGAUGE DATUM BREACH CANNON unit exactly matching the supplied painting. One six-legged ivory/brass/black mechanical cannon walker AND exactly ONE human operator walking at its rear viewer-RIGHT side. Preserve SIX attached mechanical leg chains: three near ivory-armored legs and three far dark legs with normal occlusion, hinged knees/ankles and three-toed metal feet. Never add legs or detach a leg. Keep the single long black/brass inner gun barrel in its fixed ivory sleeve, same round muzzle diameter; boiler, two white-faced gauges, red valve wheels, original hoses, one tall chimney and warm orange furnace apertures. Operator keeps white split coat/helmet, orange goggles, two black-gloved hands, exactly two arms and two legs/boots. No new crew, weapons or mechanisms. Fixed three-quarter orthographic camera, gun points SCREEN LEFT, never mirror. Same anatomical/mechanical size and rooted chassis registration. ')
plate=(' Flat magenta RGB255,0,255 backdrop only, no floor/horizon/scenery/shadow/text/cuts/zoom/camera move. Complete barrel/chimney/leg chains/operator/boots stay safely inside canvas. Quiet physical vents, no airborne smoke, sparks, fire, shells or detached projectiles; game owns projectile and impact effects. No magical beam or new glowing hardware. Mechanical articulation rather than whole-unit wobble. ')
specs={
 'move':(['idle_hands_0','creep_front_lift','creep_middle_lift','creep_rear_lift'],[(25,1),(55,2),(85,3)],0,'One controlled IN-PLACE six-leg wave gait and matching return. Near front foot lifts, bends, swings forward, plants and loads; then near middle and rear perform their own clear lifts and loadings, with corresponding far legs moving in alternate intervals while at least three legs support chassis at all times. Every leg stays attached to its own hinge. Operator alternates both real boots in a small in-place walking cycle beside the machine while keeping both hands on original control bar. Barrel/chassis stay centered and level; no sliding feet or root translation. Return to original ready stance.'),
 'attack':(['idle_hands_0','attack_windup','melee_shove'],[(28,1),(60,2)],0,'One physical close-combat cannon-body/barrel shove with NO firing. Operator pulls the controls and braces both real boots, cannon legs spread and load; whole cannon leans forward a little through bent front joints and thrusts its solid barrel/mount forward against adjacent target. Barrel remains original full length, unchanged diameter. All six legs retain real support. Muzzle is inert during the shove, no discharge/flash/projectile. Recover by unfolding loaded joints and bringing operator elbows back to original ready.'),
 'ranged':(['idle_hands_0','attack_windup','ranged_telescoped_recoil'],[(25,1),(55,2)],0,'One aimed cannon pressure discharge and complete mechanical recovery. Adjust barrel elevation slightly, operator squeezes existing control, all six legs brace. Inner black/brass barrel visibly telescopes BACK about one third into the unchanged fixed ivory sleeve, with SAME round muzzle diameter. Operator bends both elbows and knees to absorb recoil, hands remain on controls. Muzzle internal warm light briefly changes at release; no airborne flash or projectile. The recoil piston then drives the original inner barrel back out, restoring original exposed length and aim; operator resets grip and stance and returns to ready. One discharge only, no extra barrels or crew.'),
 'hit':(['idle_hands_0','hit'],[(45,1)],0,'One RECEIVING impact recoil, mechanically inactive gun. All six legs flex and absorb a small backward chassis tilt; operator chest/helmet jerk back, both real knees bend; one gloved hand briefly flinches up beside helmet while the other retains its control-bar grip. Restore the released hand to the same control and recover both elbows. Gun does not fire or telescope as a shot; no smoke/flash. Recover stable support and original ready alignment. No terminal collapse.'),
 'defend':(['idle_hands_0','guard_a','guard_b'],[(40,1)],2,'Dedicated held defensive brace. Six legs spread and flex lower, retaining all attached chains; lower boiler/chassis behind ivory panels. Operator crouches behind rear plating, bends both knees and holds control bar firmly with both hands. Same barrel length and muzzle width. End in deep grounded guard and hold steadily. No return to ready, firing, disassembly or new shield.'),
 'cast':(['idle_hands_0','idle_hands_3'],[(55,1)],0,'One deliberate NONMAGICAL physical support and pressure-control adjustment. Operator left hand retains lower control bar; right gloved hand leaves its lower grip and reaches up to original top red valve, visibly turns that same valve once while both elbows and shoulders articulate, checks original white pressure gauge and restores the same right hand to lower control. Machinery makes a small controlled breech/elevation adjustment then returns. Six leg supports stay planted. Stronger deliberate maintenance/rally action than resting idle. Exactly two operator arms/hands. No spell, beam, new gauge, extra crew or firing.'),
 'death':(['idle_hands_0','death_buckle','death_settle','dead_operator_and_wreck'],[(40,1),(82,2)],3,'One continuous terminal failure and collapse of BOTH cannon and its single operator. Six attached leg joints buckle and splay under boiler weight, lowering chassis and original gun to the same floor. Operator loses balance, releases controls, bends both knees, falls beside rear plating with exactly two arms/two legs, and settles prone at viewer-right. Preserve original gun, chimney, gauges and leg hardware; no explosions/disappearing parts. Final machine is grounded wreck and operator completely prone. Orange furnace, muzzle and goggles cool dark at the end, no resurrection or recovery.')}
for i,(name,(names,guides,last,beat)) in enumerate(specs.items()):
 take=OUT/f'{name}_h3_v1';take.mkdir(exist_ok=True)
 if not (take/'config.json').exists():write(take/'config.json',dict(unit_id=UID,clip=name,source_facing='left',canvas=[960,544],anchor=[480,500],scale=.5,key_rgb=[255,0,255],seed=2026109400+i,references=[refs[n] for n in names],guides=guides,last=last,prompt=(identity+beat+plate).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4)))
 if not (take/'sampling_submission.json').exists():produce.prepare(take,json.loads((take/'config.json').read_bytes()))
profile=json.loads((OUT.parent/'unit_brasshollow_gaugefire_arbalists/runtime_profile.json').read_bytes());profile['runtime']=json.load(urllib.request.urlopen(produce.URL+'/system_stats'));profile['verification_date']='2026-10-02';profile['schemas']={}
for n in ['MiniMaxH3ImageToVideo','MiniMaxH3AddGuide','VAEDecodeTiled','UNETLoader','CLIPLoader','VAELoader','SaveLatent','LoadLatent','LTXVSeparateAVLatent']:
 profile['schemas'][n]=json.load(urllib.request.urlopen(produce.URL+'/object_info/'+n))[n]['input']
for r in profile['models']['files']:
 path=Path('H:/ai/minimax-h3/ComfyUI/models')/r['file'];assert path.stat().st_size==r['bytes']
write(OUT/'runtime_profile.json',profile)
write(OUT/'delivery.json',dict(takes=[f'{n}_h3_v1' for n in specs],preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Original idle8 personally qualifies after chronological/enlarged inspection; new seven H3 actions require full source/native/reflected/actual/live review.')))
measure=[]
for take in [OUT/f'{n}_h3_v1' for n in specs]:
 for guide in take.glob('guide_*_rgba.png'):
  a=np.array(Image.open(guide).convert('RGBA')).astype(np.int16);color=a[:,:,:3][a[:,:,3]>=240];R,G,B=color.T
  bands=dict(magenta=np.minimum(R,B)-G,green=G-np.maximum(R,B),blue=B-np.maximum(R,G),cyan=np.minimum(G,B)-R)
  measure.append(dict(path=guide.relative_to(ROOT).as_posix(),sha256=produce.sha(guide),opaque_pixels=len(color),maximum={k:int(v.max()) for k,v in bands.items()},percentile999={k:round(float(np.percentile(v,99.9)),3) for k,v in bands.items()}))
yellow=[]
for r in measure:
 a=np.array(Image.open(ROOT/r['path']).convert('RGBA')).astype(np.int16);v=a[:,:,:3][a[:,:,3]>=240];R,G,B=v.T;yellow.extend((np.minimum(R,G)-B)[R-G<12].tolist())
write(OUT/'foreground_measurement.json',dict(guides=measure,protected_bands={k:max(r['maximum'][k] for r in measure)+2 for k in ['magenta','green','blue','cyan']},protected_neutral_yellow_band=max(yellow)+2,yellow_note='Original bright furnace highlights include saturated neutral-axis yellow; full-palette protection disables yellow despill and requires semantic-alpha edge review.',rule='Full measured original-guide opaque palette maxima plus2; no borrowed unit color bands.'))
write(OUT/'unit_brief.json',dict(identity=identity,source_facing='left',accepted_idle='All8 source and enlarged poses inspected; operator controls/arm articulation and breech adjustments return smoothly, six support legs and one operator retained. Preserve battle/map pixels and240ms.',source_scale=.5,video_anchor=[480,500],action_guides={k:v[0] for k,v in specs.items()},constraints='No extra crew/legs, missing controls, barrel diameter/length morph, magic or airborne projectiles. Cold grounded machine AND prone operator for death.'))
print('PREPARED_SEVEN_ORIGINAL_ACTIONS',flush=True)
