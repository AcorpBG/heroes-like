"""Exclude eight proven neighboring helmet/boot tips from legacy source cells.

Only the rectangle union changes. Original RGBA, complete intended anatomy,
weapon/shield pixels, ground anchors, scale and all clip timings are retained.
The overhead blade begins at y=388 exactly; its complete tip remains selected.
"""
import copy,json,sys
from pathlib import Path
HERE=Path(__file__).parent
BEFORE=HERE/'reviewed_handoff_before_cell_repair_20261003.json'
HOLES={'attack_02':[290,756,302,764],'attack_05':[858,764,882,769],
 'hit_01':[692,368,710,380],'hit_02':[444,380,465,384],
 'hit_03':[752,759,761,763],'defend_00':[369,1112,380,1118],
 'defend_01':[727,1111,738,1118],'defend_02':[452,1118,462,1121]}
def build():
 result=copy.deepcopy(json.loads(BEFORE.read_bytes()));entry=result['units'][0]
 for f in entry['frames']:
  if f['name'] not in HOLES:continue
  l,t,r,b=f['rects'][0];hl,ht,hr,hb=HOLES[f['name']]
  assert l<hl<hr<r and t<=ht<hb<=b
  f['rects']=[p for p in [[l,t,r,ht],[l,hb,r,b],[l,ht,hl,hb],[hr,ht,r,hb]] if p[0]<p[2] and p[1]<p[3]]
  f['source_cell_exclusion']={'box':HOLES[f['name']],'reason':'Isolated helmet or boot from neighboring original row; whole intended character/equipment excluded from removal.'}
 entry['visual_review']={'status':'pending','notes':['Eight proven neighboring-row tip fragments excluded; original anatomy/equipment/source pixels, anchors/scales/timings preserved. Focused changed-frame native/import review required.']}
 return result
if __name__=='__main__':
 destination=Path(sys.argv[1]);destination.write_text(json.dumps(build(),indent=2)+'\n');print(destination)
