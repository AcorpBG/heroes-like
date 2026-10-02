"""Selected original active intervals; no interpolation, reversal or padding."""
import produce as p

def select(take,indices,note,contact=None,**extras):
 out=p.SOURCE_DIR/take;c=p.json.loads((out/'config.json').read_bytes())
 s=dict(source_frames=indices,frame_msec=42,review_note=note,**extras)
 if contact is not None:s['contact_frame']=contact
 p.write(out/'selection.json',s);p.build(out,c)

if __name__=='__main__':
 select('hit_h3_v1',list(range(24,34))+list(range(98,105)),
  'All124 original frames reviewed chronologically, enlarged24-33/98-103 on dark/light: original two hands retain stock/fore-end, knee-supported chest/head recoil and return. Remove only long original hold34-97; retain active recoil and recovery at source24fps42ms; unchanged anchor/scale.')
 select('defend_h3_v1',list(range(24,47)),
  'All124 originals and enlarged brace reviewed: continuous knee/hip bend, original two grips and intact device. Select actual descent24-46 and hold final guard; omit long identical source hold. Exactly two arms/two legs, original fixed scale/ground.')
 select('death_h3_v1',list(range(30,57))+list(range(80,101)),
  'All124 originals and enlarged descent/roll reviewed. Retain knee/hip descent30-56, then continued equipment lowering80-89 and side roll90-100. Omit long kneeling hold57-79; original knee/contact/hand registration matches across cut. Head right/boots left, retained original device grounded beside hands; final original corpse held, no synthetic motion.')
 select('move_h3_v2',[0]+list(range(7,75)),
  'All124 original frames and enlarged boot/grip/seam phases reviewed. Select the first complete reciprocal heel/toe walking cycle with both legs loading/passing and returning to planted ready. Original lowered two-hand carry remains intact, no firing/effects; fixed root/scale. Exclude later repeated cycle75-123 and initial idle holds1-6. Native review still required.')
 select('attack_h3_v2',list(range(8,18))+list(range(46,59))+list(range(74,88))+list(range(106,117)),
  'All124 originals and enlarged fists/grips reviewed. Dedicated near RIGHT fist windup/continuous elbow extension/contact/retraction/regrip; far LEFT cradles original device. Keep actual active phases and omit unchanged holds only; physically matching seams17->46,58->74,87->106. No third hand, baked effect, equipment loss or synthetic poses.',contact=19)
 select('cast_h3_v2',list(range(8,29))+list(range(62,76))+list(range(84,102)),
  'All124 originals and enlarged fist/forearm/grip phases reviewed. Physical near RIGHT fist encouragement salute with continuous elbow rise/lowering, LEFT cradle and original stock regrip. Dedicated gesture, no forward strike, spell effect or projectile. Omit long holds29-61/76-83, retain brief peak62 and clean matching seams.')
 select('ranged_h3_v1',list(range(6,19))+list(range(31,42))+list(range(49,74))+list(range(83,100))+list(range(112,122)),
  'All124 originals and enlarged stock/string/hands reviewed. Original two-grip raise/aim, trigger/string release34, supported shoulder recoil, empty lower and short stock reload then ready. Source34/35 include completely detached projectile atx790+; split only across reviewed empty x725 boundary while retaining all original character/weapon pixels throughx664. Runtime owns projectile flight. Full original matte/video retained. Failed dry-fire v2 emits repeated volleys and is rejected.',contact=16,
  runtime_projectile_separation={str(i):dict(axis='x',split_x=725,reason='Detached runtime-owned bolt, original character endsx664; empty vertical gap665-789 reviewed, no anatomy or held device crosses boundary.') for i in [34,35]})
 p.write(p.SOURCE_DIR/'delivery.json',dict(takes=['move_h3_v2','attack_h3_v2','hit_h3_v1','defend_h3_v1','cast_h3_v2','ranged_h3_v1','death_h3_v1'],preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Seven selected original action sequences personally reviewed chronologically and enlarged; focused candidate/native/mirror acceptance pending. Preserve eight accepted articulated idle phases.')))
 p.assemble()
