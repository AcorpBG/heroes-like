"""Physical bent elbow contact after three source-backed projection rejections."""
import json
import produce as p
import prepare as b

def run():
 guide=p.SOURCE_DIR/'guides/elbow_v4_matte.png';assert guide.exists()
 contact=dict(name='elbow_v4',source=guide.relative_to(p.ROOT).as_posix(),rects=[[0,0,1536,1024]],anchor=[792,900],scale=.273,alpha_noise_cutoff=8)
 identity=b.IDENTITY.replace('Original SALTBELL CASTER from supplied painting.','Original painted human rope-bell skirmisher from supplied painting.').replace('free open hand','free leather-gloved hand')
 action='ONE COMPACT ORDINARY LEFT ELBOW SHOVE AND RECOVERY. The free anatomical LEFT forearm folds close against the chest; its gloved fist remains tucked beside the sternum. Turn the chest slightly and lean forward while the bent cloth-covered LEFT ELBOW smoothly pushes a short distance SCREEN RIGHT. Follow the supplied elbow-forward pose around frame44, then smoothly withdraw torso and bent arm to ready. The left hand never extends, points, opens or projects anything. Both boots stay planted while knees flex and coat follows the torso. The anatomical RIGHT hand keeps its original tan rope coil and continuously tethered bronze bell low beside the hip throughout. One short forward body movement and recovery, quiet unchanged painted materials, no repeat. '
 plate=' Static orthographic studio camera, constant figure scale and ground anchor, entire hood, both boots, coil, rope, bell and tassel inside a generous960x640 canvas. Exactly the same solid flat magenta background throughout, RGB255,0,255. No camera motion, color changes, scene, floor, gradient, reflections, lighting pulses, symbols, extra props or detached layers. No magic, particles, spark, orb, aura, ring, flash or contact effects. Only the original physical human figure moves continuously. '
 c=dict(unit_id=b.UID,clip='attack',canvas=[960,640],anchor=[480,576],scale=.5,key_rgb=[255,0,255],seed=2026108349,references=[b.reference(16),contact],guides=[[44,1]],last=0,prompt=(identity+action+plate).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
 out=p.SOURCE_DIR/'attack_h3_v4';out.mkdir(exist_ok=True)
 if (out/'sampling_submission.json').exists():assert json.loads((out/'config.json').read_bytes())==c;return
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c);print('PREPARED',out.name)

if __name__=='__main__':run()
