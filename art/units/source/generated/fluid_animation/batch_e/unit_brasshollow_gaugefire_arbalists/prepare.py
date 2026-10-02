"""Prepare original Gaugefire guides and bounded H3 action takes on CPU."""
import hashlib,json,shutil,sys
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
OUT=Path(__file__).resolve().parent
UID='unit_brasshollow_gaugefire_arbalists'
sys.path.insert(0,str(ROOT/'tools'))
from integrate_fluid_creature_animation import old_pose,clip_indices,resolve
BASE=ROOT/'.artifacts/parallel_animation_20261002'/UID
BASE.mkdir(parents=True,exist_ok=True)
def write(p,v):p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
if not (OUT/'produce.py').exists():
 example=ROOT/'art/units/source/generated/fluid_animation/batch_d/unit_neutral_rootvault_barkhulks'
 for name in ['produce.py','stage_video.py','run_generation.py','segment.py']:
  text=(example/name).read_text(encoding='utf-8').replace('unit_neutral_rootvault_barkhulks',UID).replace('Rootvault Barkhulk','Gaugefire Arbalist').replace('Rootvault','Gaugefire').replace('rootvault_barkhulk','gaugefire_arbalist').replace("ROOT/'.artifacts/gaugefire_arbalist_h3'","ROOT/'.artifacts/parallel_animation_20261002/unit_brasshollow_gaugefire_arbalists'")
  (OUT/name).write_text(text,encoding='utf-8')
 shutil.copyfile(example/'matting_model.json',OUT/'matting_model.json')
manifest=json.loads((ROOT/'content/unit_animation_manifest.json').read_bytes())
row=next(r for r in manifest['items'] if r['unit_id']==UID)
if not (BASE/'baseline_manifest.json').exists():
 write(BASE/'baseline_manifest.json',manifest)
 shutil.copyfile(ROOT/'art/overworld/creature_idle.json',BASE/'baseline_map.json')
 shutil.copyfile(resolve(row['pose_sheet']),BASE/'baseline_atlas.png')
 shutil.copyfile(ROOT/f'art/overworld/runtime/creature_idle/{UID}.png',BASE/'baseline_map_idle.png')
 packing=json.loads((ROOT/f'art/animation/source/poses/{UID}/packing.json').read_bytes())
 write(OUT/'original_unit_baseline.json',dict(unit=row,map=json.loads((ROOT/'art/overworld/creature_idle.json').read_bytes())['units'][UID],packing_sha256=hashlib.sha256((ROOT/f'art/animation/source/poses/{UID}/packing.json').read_bytes()).hexdigest()))
packing=json.loads((ROOT/f'art/animation/source/poses/{UID}/packing.json').read_bytes())
refs={}
for f in packing['frames']:
 r=dict(f);r['source']=f'art/animation/source/poses/{UID}/'+r['source'];r['alpha_noise_cutoff']=8;refs[f['name']]=r
identity=('One original GAUGEFIRE ARBALIST, exactly the supplied painterly armored human. Exactly two arms with two black-gloved hands, two legs and two boots. Original closed charcoal steel helmet with brass crest and one narrow orange visor. Charcoal long split coat, rust red central cloth, brass-edged pauldrons and knee armor, original compact orange boiler backpack and hip canister. One original brass and steel pressure crossbow with curved limbs, one central rail, one red circular gauge, one orange pressure chamber. Rear right hand holds trigger grip, front left hand supports the underside of the rail; preserve both legitimate grips and crossbow dimensions. No sword, shield, wand or magic. Fixed three-quarter side orthographic camera facing SCREEN RIGHT. Same anatomical body scale, grounded boots and centered pelvis. ')
plate=(' Entire backdrop flat magenta RGB255,0,255; no scenery, horizon, floor, cast shadow, text, zoom, cuts or camera movement. All boots, hands, crossbow limbs and boiler stay in canvas. No detached projectiles, sparks or fire effects; the game renders projectile flight separately. Visible articulated motion, never global sprite wobble. ')
specs={
 'move':(['idle_hands_0','walk_contact_a','walk_near_passing'],[(28,1),(88,2)],0,'Two complete controlled walking cycles IN PLACE. Alternate near and far legs through lifted passing, forward heel contact, load and rear toe push. Both knees and ankles bend naturally, coat trails; crossbow held securely in both hands. Boots lift cleanly and make alternating ground contacts. No sliding, foot duplication or root translation. Return to original ready stance.'),
 'attack':(['idle_hands_0','melee_windup','melee_shove'],[(32,1),(66,2)],0,'One deliberate physical close-combat crossbow-stock shove. Draw crossbow close, bend both elbows and knees, then extend both hands to thrust the solid crossbow stock/body forward into the adjacent enemy, keeping all equipment intact. No bolt fires. Weight transfers with a small grounded step, elbows fold to recover back to ready.'),
 'ranged':(['idle_hands_0','idle_hands_3','ranged_discharged','reload_cocking_empty','reload_insert_single_bolt'],[(24,1),(45,2),(72,3),(95,4)],0,'One aimed pressure-crossbow shot then physically visible reload. Raise the crossbow to shoulder aim, squeeze trigger and recoil slightly, leaving the central rail empty after discharge. No airborne projectile or flash is painted. Keep the left hand supporting the rail, briefly release the right trigger hand to cock the pressure mechanism, use that same right hand to place one bolt on the central rail, restore the right trigger grip and lower to original ready. No additional crossbows or hands.'),
 'hit':(['idle_hands_0','hit'],[(52,1)],0,'One readable impact recoil then complete recovery. Chest and helmet recoil backward, knees absorb the hit, elbows flex while retaining crossbow grips. No fall; boots remain grounded. Regain balance and return naturally to original ready.'),
 'defend':(['idle_hands_0','guard_a','guard_b'],[(48,1)],2,'Transition into a dedicated held defensive brace. Bend knees, lower body, pull elbows inward and raise the crossbow firmly across the chest; lean behind armored shoulder. Both boots remain planted. End in the low guarded stance and hold it steadily; do not return to ready.'),
 'cast':(['idle_hands_0'],[],0,'One nonmagical physical support signal. Keep right hand holding trigger grip, lift left hand off the rail, raise the empty gloved left hand near chest in a clear short rally gesture, open and close it once, then return the same left hand to underside support grip and restore ready. Exactly two hands at every moment. No magical glow, spell, summoned object or beam.'),
 'death':(['idle_hands_0','death_kneel','death_fall','dead_cold'],[(40,1),(78,2)],3,'One continuous terminal armored collapse. Lose strength, bend knees and sink into kneeling, torso tilts forward and sideways, release balance and fall onto the side with both real arms and legs intact. Crossbow comes to rest on the ground beside the body. End fully grounded prone corpse, helmet and equipment cooling; no recovery or resurrection. Maintain body proportions through fall.')}
for n,(names,guides,last,beat) in specs.items():
 take=OUT/f'{n}_h3_v1';take.mkdir(exist_ok=True)
 if not (take/'config.json').exists():write(take/'config.json',dict(unit_id=UID,clip=n,canvas=[960,544],anchor=[440,496],scale=.5,key_rgb=[255,0,255],seed=2026108200+list(specs).index(n),references=[refs[x] for x in names],guides=guides,last=last,prompt=(identity+beat+plate).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4)))
import produce
for n in specs:
 take=OUT/f'{n}_h3_v1'
 if not (take/'submission.json').exists():produce.prepare(take,json.loads((take/'config.json').read_bytes()))
sheet=Image.new('RGB',(1600,900),(31,36,39));draw=ImageDraw.Draw(sheet)
atlas=Image.open(BASE/'baseline_atlas.png').convert('RGBA')
for j,i in enumerate(clip_indices(row['pose_clips']['idle'],row['pose_columns'])):
 im,_=old_pose(atlas,row,i);im.thumbnail((180,380));x=j%8*200;y=20;sheet.paste(im,(x,y),im);draw.text((x,420),f'idle {j}',fill='white')
for j,n in enumerate(specs):
 im=Image.open(OUT/f'{n}_h3_v1/guide_0_rgba.png').crop((180,40,850,520));im.thumbnail((195,350));sheet.paste(im,(j*220,470),im);draw.text((j*220,850),n,fill='white')
sheet.save(BASE/'reference_overview.png')
print('Prepared seven original action configs; accepted idle preserved for review.',flush=True)
