"""Correct an unwanted stylized cyan attack trail; retain the failed original."""
import json
import produce as p
from prepare import IDENTITY,PLATE

if __name__=='__main__':
 old=p.SOURCE_DIR/'attack_h3_v1';out=p.SOURCE_DIR/'attack_h3_v2';out.mkdir(exist_ok=False)
 p.write(old/'rejection.json',dict(status='rejected',frames=list(range(32,39)),defect='Cyan luminous swoosh attached to blade during strike. Removing these complete frames would lose the continuous contact arc; do not erase the effect or publish the take.',correction='Same original physical poses, slower controlled solid-blade arc, explicit unlit edge and zero trails.'))
 c=json.loads((old/'config.json').read_bytes());c['seed']=2026092910;c['guides']=[[28,1],[64,2],[88,3]]
 c['prompt']=IDENTITY+(
  'Animate one measured physical fencing exercise. Slowly lift the right hand and its short hooked knife above the shoulder, '
  'then move that solid steel blade through a clearly observed downward-forward cutting arc. The blade and arm remain sharply painted at every instant. '
  'Bend the forward knee into the extended position, then retract the right elbow and knife to the waist and recover ready. '
  'Left arm keeps its small wooden shield in front of the chest. Only the solid hand, short grip and steel hook move; '
  'all space behind and ahead of the blade stays the exact flat blue background. '
  'No luminous arc, swoosh, trail, ribbon, motion blur, duplicate blade, sparks, light, streaks or spell effect. '
  'The steel hook is ordinary dull metal with a constant silver surface, never glowing or enlarged. One cut followed by recovery, not repeated attacks.'
 )+PLATE
 p.prepare(out,c);p.write(out/'config.json',c)
