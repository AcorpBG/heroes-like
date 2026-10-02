"""Narrow repairs after complete chronological review of the initial seven takes."""
import json,shutil
from pathlib import Path
from PIL import Image
import produce as p
from prepare import config,ref
from record_key_provenance import main as record_key

if __name__=='__main__':
 original=Path('C:/Users/acorp/.codex/generated_images/01a0965d-a98e-7560-8e9d-802269b3760b/exec-eb88a10f-66ce-4f6c-bd88-cab3c12336ae.png')
 target=p.SOURCE_DIR/'walk_contact_original.png'
 if not target.exists():shutil.copyfile(original,target)
 im=Image.open(target);box=im.getchannel('A').point(lambda a:255 if a>8 else 0).getbbox()
 scale=.155
 key=dict(name='lowered_device_forward_contact',source=target.relative_to(p.ROOT).as_posix(),rects=[[0,0,*im.size]],anchor=[im.width//2,box[3]],scale=scale,alpha_noise_cutoff=8)
 record_key()
 config('move',[ref(17),key],[[50,1]],0,
  'A calm hooded traveler WALKING IN PLACE at a steady slow tempo, continuously alternating BOTH legs: near boot swings forward and heel touches down; far boot lifts, passes forward and touches down; then near leg repeats. Do not freeze at intermediate pose. Grounded reciprocal heel/toe contacts, modest strides and coat sway, body root remains centered. Both hands CARRY the compact wooden device LOW at waist throughout, its front pointed DOWN toward ground as supplied contact. Hands keep original rear stock and fore-end grips. Device is inert and unchanged. Never lift device toward shoulder. Return naturally to original planted ready at end. Every frame contains ONLY the one traveler and carried equipment; empty surrounding green plate.',2026102301,version='v2')
 config('attack',[ref(17),ref(6)],[[55,1]],0,
  'One continuous controlled RIGHT-FIST thrust exercise. Far LEFT hand supports the unchanged wooden equipment across low waist. Near RIGHT hand releases rear stock, closes ONE fist, draws back beside own right shoulder; the fist moves gradually FORWARD as elbow unfolds over several frames toward supplied contact55. Keep left hand and original device stable at waist. Then continuously bend RIGHT elbow to retract fist and smoothly put RIGHT hand back on rear stock. Two natural arms only, stable face/clothing. Do not hold an intermediate ready pose or snap the fist between extremes. Slow deliberate visible fist travel, clean anticipation/contact/recovery. Green surrounding area stays empty throughout.',2026102302,version='v2')
 config('cast',[ref(17),ref(5)],[[60,1]],0,
  'The hooded traveler makes one slow visible physical greeting salute with RIGHT fist. LEFT arm supports unchanged wood equipment LOW at waist with front pointed DOWN, never lifts it to aim. RIGHT hand leaves stock, elbow bends and CLOSED FIST rises beside own right shoulder at60, then smoothly lowers and regrips rear stock. This is a friendly fist salute with grounded boots and relaxed chest, no fighting. Exactly two original arms, one unchanged carried object. Continuous elbow/wrist movement, no snap to another stance. Entire surrounding green area remains completely empty for whole clip.',2026102303,version='v2')
 config('ranged',[ref(11),ref(12)],[],1,
  'Close controlled DRY-FIRE mechanical exercise of an UNLOADED wooden crossbow. Same original two hands remain on rear stock and front fore-end. Keep fixed wooden stock and original dark limbs. Index finger presses original trigger, bow string moves gradually forward from drawn position to FRONT NOCKS, slight natural backward shoulder recoil, unchanged torso size and grounded feet. There is NO ammunition on the rail and NOTHING leaves the crossbow. The quiver stays fixed at hip. End in supplied empty device pose, string FORWARD at front nocks. Do not lower or reload in this clip. Empty green surrounding area throughout. No other objects enter or leave the image.',2026102304,version='v2')
 p.write(p.SOURCE_DIR/'correction_review.json',dict(initial_takes_reviewed=list(range(124)),move='Rejected baked firing and held backward knee lifts; added one forward-contact/downward-carry reference.',attack='Rejected instantaneous fist extension26->27; fewer guides allow actual elbow extension.',cast='Rejected firing fragments41-43 and abrupt return73->74; slower friendly salute and waist-only carry.',ranged='Retain reviewed raise/lower/reload from v1; replace only release interval34-36 with original dry-fire footage after review.',death='Initial descent/roll has a long kneeling hold; active original intervals will be reviewed enlarged before selection.',rule='No synthetic intermediate/reverse/duplicate padding. New take acceptance remains pending.'))
