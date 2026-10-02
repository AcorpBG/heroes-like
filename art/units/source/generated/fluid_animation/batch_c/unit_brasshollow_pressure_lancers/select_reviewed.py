"""Select observed chronological original phases, never fabricated motion."""
import json
import produce as p

def select(take,indices,note,contact=None,msec=42):
 out=p.SOURCE_DIR/take;s=dict(source_frames=indices,frame_msec=msec,review_note=note)
 if contact is not None:s['contact_frame']=indices.index(contact)
 p.write(out/'selection.json',s);p.build(out,json.loads((out/'config.json').read_bytes()))

def original_actions():
 select('cast_h3_v1',[0]+list(range(8,27))+[32,44,54]+list(range(57,75))+[82,96,123],
  'All124 chronological original/keyed phases and enlarged lance pivot/hoses/three feet reviewed. Single physical mounted-spear readiness signal: gradual raising8-26, clear held angled spear32-54, lowering57-74 to ready. Original three feet stay planted, one cold rigid tip and intact gauge/boiler; no firing or magic. Condense ready/peak holds only, original frames at42ms, no duplicates/reverse/interpolation or frame normalization. Native review required.',24)
 select('death_h3_v1',[0,8,16]+list(range(20,97,2))+[104,123],
  'All124 chronological original/keyed phases and enlarged20-96 collapse/terminal123 reviewed. Three knees buckle, boiler lowers, tips onto its side, three original leg chains fold, attached straight spear settles with tip grounded; gauge and chimney rotate with rigid chassis. Terminal cold corpse remains grounded. Sample original collapse at12fps then retime42ms per selected phase; condense unchanged ready/corpse holds, no duplicates/reverse/interpolation or geometry normalization. Native review required.')

def corrected_actions():
 select('move_h3_v2',list(range(40,118,2)),
  'All124 chronological originals and enlarged support/contact/seam40-116 reviewed. Complete tripod cycle: far-left foot swings48-64, rear-middle swings72-86, near-right swings94-108 then returns to contact116 matching40. Original three leg chains remain distinct, two feet support each swing, boiler dimensions now match accepted idle.39 original poses sampled12fps, deliberately retimed42ms each; no held extra near-leg repetition from0-39 or endpoint guide tail118-123. No duplicates/reversal/interpolation, per-frame normalization or synthetic seam. Native review required.')
 select('attack_h3_v2',[0,8]+list(range(10,35,2))+list(range(35,43))+[46,50,56,62,66]+list(range(68,102,2))+[110,123],
  'All124 chronological originals and enlarged10-102 single spear stroke reviewed. Three knees load, rigid mounted shaft retracts then extends35-42 to held contact56, retracts68-86 and legs recover88-102. Exactly one original cold triangular point, fixed gauge and three legs; reject invented flash fromv1. Dense original thrust interval, condense windup/contact/ready holds;42ms per selected original pose. No duplicates, interpolation or geometry normalization. Native review required.',56)
 select('hit_h3_v2',[0,16,18,19,20,21,22,23,24,25,26,28,30,32,44,62,74,76,77,78,79,80,81,82,83,84,86,90,100,123],
  'All124 chronological originals and enlarged18-32/76-90 recoil/recovery reviewed. Original three knees compress, rigid boiler and mounted spear tilt back, then mechanism recovers upright. No incoming drum/explosion from rejectedv1, no detached parts or lost leg. Condense held backward lean,30 original poses at35ms for readable brief impact/recovery; no duplicates/reversal/interpolation or normalization. Native review required.',msec=35)

def repaired_defense():
 select('defend_h3_v3',[0,8]+list(range(10,45))+[50,62,80,96,112,123],
  'All124 chronological originals and enlarged0-123 foot/support/brace phases reviewed. Original painted complete spade feet recovered in guides; all three plated feet remain intact and planted as knees compress10-28, boiler lowers and single cold mounted lance tilts into guard29-44, held through123.43 chronological original poses at42ms, condense initial and held guard only. No added legs, duplicates, reversal, interpolation or per-frame normalization. Native review required.')

if __name__=='__main__':
 import sys
 if '--defense' in sys.argv:repaired_defense()
 elif '--corrected' in sys.argv:corrected_actions()
 else:original_actions()
