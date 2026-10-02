"""Recover the complete original spade feet excluded by legacy guard crops."""
import json
import numpy as np
from PIL import Image
import produce as p

def main():
 c=json.loads((p.SOURCE_DIR/'defend_h3_v2/config.json').read_bytes())
 c['references'][1]['rects']=[[534,520,1044,860],[480,860,1000,1024]]
 c['references'][2]['rects']=[[1047,520,1536,860],[1000,860,1536,1024]]
 for f in c['references'][1:]:
  f['crop_recipe']=dict(kind='original_pixel_guard_foot_recovery',reason='Legacy row crops cut the far screen-left spade foot. Expand only lower rows into the clear inter-figure gap; preserve complete original painted feet, source anchors and fixed family scale. No new/repainted pixels.')
 c['seed']=2026100921;out=p.SOURCE_DIR/'defend_h3_v3';out.mkdir(exist_ok=True);assert not (out/'submission.json').exists();p.write(out/'config.json',c);p.prepare(out,c)
 maxima=[]
 for i in range(len(c['references'])):
  a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(int);v=a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]);maxima.append(int(v[a[:,:,3]>=245].max()))
 c['protected_foreground_chroma']=max(maxima)+2;p.write(out/'config.json',c);p.verify(out,c)
 p.write(out/'foreground_measurement.json',dict(original_guide_green_minus_max_red_blue=maxima,opaque_alpha_minimum=245,margin=2,protected_foreground_chroma=c['protected_foreground_chroma']))
 rejects=json.loads((p.SOURCE_DIR/'rejected_takes.json').read_bytes());rejects['defend_h3_v2']='Scale corrected, but original legacy guard crop clipped screen-left spade foot. Reassessed original painting; recover complete original foot pixels across clear lower-row gaps, then regenerate. No prompt-only repetition.';p.write(p.SOURCE_DIR/'rejected_takes.json',rejects)

if __name__=='__main__':main()
