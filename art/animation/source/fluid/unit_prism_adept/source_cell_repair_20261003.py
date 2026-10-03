"""Exclude eight proven neighboring hood tips; preserve original art and registration.

The original RGBA cells overlap the following row by 4..18 pixels. Each
excluded box is isolated from the intended character's boots and clothing.
Original pixels, whole-image scale, anchors, clip timing and other poses remain.
"""
import copy,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[5]
HERE=Path(__file__).parent
BEFORE=HERE/'reviewed_handoff_before_cell_repair_20261003.json'
HOLES={'hit_00':[249,387,309,402],'hit_01':[703,382,767,402],
       'hit_02':[255,791,300,799],'ranged_04':[246,1135,286,1143],
       'ranged_05':[751,1137,773,1143],'defend_01':[717,1160,757,1168],
       'cast_04':[299,1129,314,1135],'cast_05':[773,1129,792,1135]}
def build():
 original=json.loads(BEFORE.read_bytes());result=copy.deepcopy(original);entry=result['units'][0]
 for f in entry['frames']:
  if f['name'] not in HOLES:continue
  l,t,r,b=f['rects'][0];hl,ht,hr,hb=HOLES[f['name']]
  assert l<hl<hr<r and t<ht<hb==b
  # A three-rectangle union removes only the proven foreign corner region.
  f['rects']=[[l,t,r,ht],[l,ht,hl,b],[hr,ht,r,b]]
  f['source_cell_exclusion']={'box':HOLES[f['name']], 'reason':'Detached hood from following source row; original boots lie outside this box.'}
 entry['visual_review']={'status':'pending','notes':['Source-cell repair: eight isolated following-row hood tips; originals, scales, anchors, anatomy, equipment and timing retained. Focused changed-frame native/import review required.']}
 return result
if __name__=='__main__':
 destination=Path(sys.argv[1]);destination.write_text(json.dumps(build(),indent=2)+'\n');print(destination)
