"""Reassess dense held guide blocks with sparse original physical endpoints."""
import json
import numpy as np
from PIL import Image
import produce as p
from prepare import IDENTITY, PLATE, reference
from prepare_corrections import new_reference

def make(name,clip,refs,guides,last,action,seed):
 out=p.SOURCE_DIR/name
 if out.exists():assert not (out/'sampling_submission.json').exists() and not (out/'original.latent').exists(),'Original submitted takes are immutable'
 out.mkdir(exist_ok=True)
 c=dict(unit_id='unit_brasshollow_whitegauge_datum_lancers',clip=clip,canvas=[960,640],anchor=[480,576],scale=.5,key_rgb=[255,0,255],seed=seed,references=refs,guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)

if __name__=='__main__':
 notes={
 'move_h3_v2':'All124 original RGB and124 original RGBA chronology and14 full-size matched details personally inspected. Different leading-leg paintings exist, but13->14,52->53,80->81 and104->105 produce abrupt pose changes separated by long held blocks. This is not an accepted reciprocal fluid gait. Reassessed installed nodes_minimax_h3.py and PackedLayout model conditioning: guides are independent fixed latent rows at target temporal positions, not interpolation. Use first/last same far contact and a single opposed near contact midway, omitting old ambiguous passing guide paintings.',
 'attack_h3_v2':'All124 original RGB and124 original RGBA chronology and28 full-size matched details personally inspected. Dense repeated windup/contact guides hold large ranges. Source42 adds a white lance-tip extension connected to the weapon; diagonal transitions13-14/103-104 smear the shaft. Preserve exact take and matte. Reassess sparse original diagonal/windup/contact anchors, remove repeated anchors and request natural movement without effect trails.'}
 for take,note in notes.items():
  out=p.SOURCE_DIR/take
  p.write(out/'rejection.json',dict(status='rejected_full_take',personal_rgb_frames=124,personal_rgba_frames=124,note=note,original_sha256=p.sha(out/'original_lossless.mkv'),latent_sha256=p.sha(out/'original.latent'),matte_sha256=p.sha(out/'matte.json'),segmentation_tool_sha256=p.sha(p.SOURCE_DIR/'segment.py'),rule='Preserve originals and failed extraction provenance. No invented articulation, reversed/duplicated motion or repair of equipment geometry.'))
 near=new_reference('move_near_contact_v1',[650,1385],.15)
 diagonal=new_reference('attack_diagonal_carry_v1',[680,1155],.176)
 make('move_h3_v3','move',[reference(2),near],[[62,1]],0,
 'A fluid natural two-step walking cycle IN PLACE, continuously moving throughout the five seconds, no pauses or held poses. Begin at original FAR LEFT shield-side forward contact, NEAR RIGHT lance-side leg trailing. Transfer weight onto forward far foot, swing NEAR RIGHT leg forward with a clearly raised foreground knee, then plant NEAR RIGHT foot forward at the middle original near-contact painting. Far LEFT leg now trails behind. Transfer weight onto near foot and swing FAR LEFT knee and foot forward again, ending at original FAR LEFT contact identical to beginning. One whole reciprocal cycle, both hips/knees/ankles articulate naturally through passing and loading, continuous grounded weight transfer. Whole upright lance remains rigid in RIGHT hand and small shield remains in LEFT arm; coat tails and weights respond subtly. Keep planted boot contacts fixed, root in place and exactly two legs, no same-leg repeated steps. ',2026110421)
 make('attack_h3_v3','attack',[reference(14),reference(7)],[[62,1]],0,
 'One fluid physical spear thrust and recover with no paused pose blocks. Gradually lower the complete rigid lance from ready through diagonal carry24 to horizontal windup40. Pivot about RIGHT middle grip with tip upper right and butt lower left. Around62 extend RIGHT arm and grounded lunge SCREEN RIGHT along the horizontal shaft axis, keeping the full original straight lance intact. Retract that same arm axially into windup84, then pivot the full pole back through diagonal100 to upright ready at end. LEFT arm continuously holds the small round shield at chest. Follow whole original shaft, pointed butt, spearhead, bands and gauge exactly. Continuous natural motion between anchors; no repeated poses, frozen intervals or instant changes. Absolutely no white streaks, motion lines, extended spear tip, glow or energy effects. Render only the physical original weapon at every moment. ',2026110422)
 d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());d['takes'][0:2]=['move_h3_v3','attack_h3_v3'];d['failed_takes']=['move_h3_v1','attack_h3_v1','move_h3_v2','attack_h3_v2'];p.write(p.SOURCE_DIR/'delivery.json',d)
 records=[]
 for folder in sorted(p.SOURCE_DIR.glob('*_h3_v*')):
  for f in sorted(folder.glob('guide_*_rgba.png')):
   a=np.asarray(Image.open(f).convert('RGBA')).astype('int16');solid=a[:,:,3]>=250;v=int((np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1])[solid].max());assert v<=24
   records.append(dict(path=f.relative_to(p.ROOT).as_posix(),sha256=p.sha(f),opaque_magenta_chroma_max=v,opaque_pixels=int(solid.sum())))
 p.write(p.SOURCE_DIR/'foreground_measurement.json',dict(unit_id=d.get('unit_id','unit_brasshollow_whitegauge_datum_lancers'),measured_guides=len(records),opaque_magenta_chroma_max=max(r['opaque_magenta_chroma_max'] for r in records),unchanged_protected_band=24,records=records,rule='No matte or model setting change. Sparse guide correction after personal full source review.'))
 print('SPARSE_ORIGINAL_GUIDES_PREPARED',len(records),flush=True)
