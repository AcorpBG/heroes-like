"""Source-backed physical contact and articulated collapse after visual rejection."""
import argparse,json
import produce as p
import prepare as b

def authored(name,anchor,scale):
 file=p.SOURCE_DIR/'guides'/(name+'_matte.png');assert file.exists(),'Complete queued semantic guide extraction first'
 return dict(name=name,source=file.relative_to(p.ROOT).as_posix(),rects=[[0,0,1536,1024]],anchor=anchor,scale=scale,alpha_noise_cutoff=8)

def run(clip):
 if clip=='attack':
  take='attack_h3_v3';seed=2026108343
  refs=[b.reference(16),b.reference(6),authored('low_fist_v3',[768,917],.268)]
  guides=[[16,1],[34,2],[52,2],[78,1]];last=0
  action='ONE SHORT ORDINARY LEFT-HAND FIST JAB. The free anatomical LEFT leather-gloved hand closes into a small fist, draws back beside the chest, then moves smoothly straight SCREEN RIGHT below the shoulder in a compact physical punch. Extend the elbow gradually during frames16-34 to the supplied closed-fist contact pose, pause briefly34-52, then bend the elbow and withdraw along the same short path to ready. Slight torso/knee weight shift while both boots stay grounded. The anatomical RIGHT hand keeps gripping its original tan rope coil at the hip, retaining the same attached bronze handbell. Entire hand and equipment remain plain painted physical materials, with no effects or extra objects. One forward fist movement and one recovery, no turning, repeated strike, ring, flash or marks around the hand. '
 else:
  take='death_h3_v2';seed=2026108347
  refs=[b.reference(16),authored('half_crouch_v2',[770,914],.205),b.reference(13),authored('side_settle_v2',[768,850],.22),b.reference(14),b.reference(15)]
  guides=[[20,1],[40,2],[62,3],[84,4],[104,5]];last=5
  action='ONE SLOW CONTINUOUS SUPPORTED COLLAPSE through every supplied intermediate pose, without a cut or jump. Begin bending BOTH knees immediately after ready, smoothly lower hips through the supplied halfway crouch20, then place knees on ground40. Free LEFT palm reaches down to brace; torso gradually tips SCREEN RIGHT while hip and both folded legs settle onto ground through the supported side-lean62. Lower the supporting forearm and chest smoothly into side-rest84, then settle head/hood into the final original corpse104. Keep original bone lengths, two arms, two folded legs and both original boots recognizable throughout. The original RIGHT rope hand lowers its same coil and continuously attached bell onto the ground without releasing it. Entire body always inside canvas with constant scale and camera. No pose snapping, shrink, dissolving, turning, resurrection or effects. Final original corpse completely still, original bell and coil resting beside its hand. '
 identity=b.IDENTITY.replace('Original SALTBELL CASTER from supplied painting.','Original painted human rope-bell skirmisher from supplied painting.')
 c=dict(unit_id=b.UID,clip=clip,canvas=[960,640],anchor=[480,576],scale=.5,key_rgb=[255,0,255],seed=seed,references=refs,guides=guides,last=last,prompt=(identity+action+b.PLATE).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
 out=p.SOURCE_DIR/take;out.mkdir(exist_ok=True)
 if (out/'sampling_submission.json').exists():assert json.loads((out/'config.json').read_bytes())==c;return
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c);print('PREPARED',take)

if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('clips',nargs='+',choices=['attack','death']);args=a.parse_args()
 for clip in args.clips:run(clip)
