"""Replace rejected overhead throws with distinct chest support and low release."""
import argparse,json
import produce as p
import prepare as b

def prepare(clip):
 out=p.SOURCE_DIR/(clip+'_h3_v2');out.mkdir(exist_ok=True)
 if clip=='ranged':
  refs=[b.reference(16),b.reference(11)];guides=[[42,1],[58,1]];seed=2026108326
  action='One PHYSICAL SHOULDER-LEVEL horizontal bell-on-rope strike. Both hands and the original bronze bell ALWAYS stay below the hood and below shoulder height, inside broad canvas margins. Draw the equipped RIGHT coil-hand briefly back at waist level, then extend that same hand smoothly SCREEN RIGHT to the supplied low horizontal release pose. The ONE continuously tethered bronze bell travels forward in a short horizontal stroke at chest height, never overhead, never above the hood. Hold this clear forward contact briefly, then retrieve the same original rope and bell and recover to exact ready. Free LEFT hand balances behind the body. Keep original bell size; no detached projectile, duplicate bell, extra limbs, glow, flashes, sparks or new equipment. Runtime owns distant projectile flight; show only the physically attached bell and continuous rope. '
 else:
  master=p.SOURCE_DIR/'guides/chest_bell_v2_matte.png';assert master.exists(),'Complete GPU semantic guide extraction first'
  refs=[b.reference(16),dict(name='chest_bell_support',source=master.relative_to(p.ROOT).as_posix(),rects=[[0,0,1536,1024]],anchor=[768,917],scale=.3025,alpha_noise_cutoff=8)]
  guides=[[32,1],[56,1],[70,1]];seed=2026108325
  action='One quiet CHEST-LEVEL bell support gesture. Slowly lift the equipped anatomical RIGHT rope-coil hand only to the upper chest; its ONE original bronze handbell hangs just below the coil at the sternum. Bring the free LEFT palm gently inward beneath the bell and bow the original hood slightly, looking down at the bell. Pause deliberately in the supplied chest pose, gently shake the attached bell once by a small wrist movement, then lower the same rope coil and bell back to waist level and withdraw the free palm to exact original ready. BOTH elbows and hands stay below shoulder height. The bell never travels overhead or beyond either shoulder; no throwing, horizontal strike or lunging. Preserve the same two arms, two planted legs, hand grips and attached bronze bell. Plain physical painted hands/equipment throughout, no glow, sparks, flash, rings, beams, stars, magical aura, background light, extra equipment or camera movement. '
 c=dict(unit_id=b.UID,clip=clip,canvas=[960,640],anchor=[480,576],scale=.5,key_rgb=[255,0,255],seed=seed,references=refs,guides=guides,last=0,prompt=(b.IDENTITY+action+b.PLATE).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
 if (out/'sampling_submission.json').exists():assert json.loads((out/'config.json').read_bytes())==c;return
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
 print('Prepared',out.name,flush=True)

if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('clips',nargs='+',choices=['cast','ranged']);args=a.parse_args()
 for clip in args.clips:prepare(clip)
