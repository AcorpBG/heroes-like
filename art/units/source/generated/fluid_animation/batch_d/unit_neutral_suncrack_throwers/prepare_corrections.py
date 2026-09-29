"""Correct flask continuity and the unwanted incoming object in original takes."""
import json
import produce as p
from prepare_h3 import IDENTITY, PLATE

if __name__=='__main__':
 corrections={
  'ranged':('The woman performs ONE short controlled overarm toss of the small opaque BLUE flask. '
   'The same small blue glass flask stays visibly enclosed in her RIGHT hand from the belt through the raised position, '
   'with unchanged size and blue color; it must never become an empty fist or disappear before release. '
   'Draw it beside her right ear and pause in that exact pose. Then rotate the right shoulder forward, '
   'extend the elbow toward screen right and open the fingers to release the flask. '
   'The small blue flask leaves the hand once and exits screen right without growing. '
   'Follow through with the empty right hand and recover to the starting stance. '
   'Left hand counterbalances. Scarf, goggles and belt remain unchanged. No fire, magical glow or additional objects.'),
  'hit':('An isolated woman performs one brief backward dodge and flinch, as a solo acting exercise on an empty green backdrop. '
   'Shift shoulders and head back, bend the knees, draw the right forearm across the belly and lift the left hand beside the face. '
   'Then regain balance and return to the exact initial stance. '
   'Only her body and attached costume move; hands stay empty, flasks remain secured at the belt. '
   'There is no attacker, incoming object, projectile, collision, splash, debris, blood, wound, particles or visual effect. '
   'Full body remains visible, both feet maintain support, one smooth recoil and recovery.')
 }
 for number,(clip,action) in enumerate(corrections.items()):
  old=p.SOURCE_DIR/f'{clip}_h3_v1';out=p.SOURCE_DIR/f'{clip}_h3_v2';out.mkdir(exist_ok=False)
  c=json.loads((old/'config.json').read_bytes());c['seed']=2026093500+number;c['prompt']=(IDENTITY+action+PLATE).strip()
  if clip=='ranged':c['guides']=[[36,1],[50,1],[62,2]]
  p.prepare(out,c);p.write(out/'config.json',c)
 delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
 reasons={'ranged_h3_v1':'Held flask disappears into empty fist at53-55 and reappears oversized before release57. No frames accepted.',
          'hit_h3_v1':'Unrequested incoming dark object and debris overlap the recoil at27-44. Reject; regenerate isolated flinch without an incoming effect.'}
 delivery['rejected_takes']=reasons
 delivery['takes']=[t.replace('ranged_h3_v1','ranged_h3_v2').replace('hit_h3_v1','hit_h3_v2') for t in delivery['takes']]
 for name,reason in reasons.items():p.write(p.SOURCE_DIR/name/'rejection.json',dict(status='rejected',reason=reason,review='All124 original frames inspected chronologically; ranged release enlarged. Originals retained.'))
 p.write(p.SOURCE_DIR/'delivery.json',delivery)
