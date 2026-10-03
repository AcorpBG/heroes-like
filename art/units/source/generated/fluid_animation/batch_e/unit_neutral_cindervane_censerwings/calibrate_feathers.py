"""Measure retention of known original feathers, ember marks and talons."""
import numpy as np
from PIL import Image
import segment
import produce as p

def calibrate(net):
    records=[]
    target=p.ROOT/'.artifacts/cindervane_censerwing_h3';target.mkdir(exist_ok=True)
    for take,index in [('move_h3_v1',0),('move_h3_v1',1),('move_h3_v1',3),('attack_h3_v1',2),('death_h3_v1',3)]:
        out=p.SOURCE_DIR/take
        original=np.asarray(Image.open(out/f'guide_{index}_rgba.png').convert('RGBA'))
        matte,detail=segment.extract(net,Image.open(out/f'guide_{index}_chroma.png').convert('RGB'))
        actual=np.asarray(matte);solid=original[:,:,3]>=240
        ember=solid&(original[:,:,0]>180)&(original[:,:,1]>65)&(original[:,:,2]<100)
        dark=solid&(original[:,:,:3].max(axis=2)<100)
        assert solid.any() and ember.any() and dark.any()
        rec=dict(take=take,guide=index,original_rgba_sha256=p.sha(out/f'guide_{index}_rgba.png'),original_rgb_sha256=p.sha(out/f'guide_{index}_chroma.png'),opaque_retained_at128=float((actual[:,:,3][solid]>=128).mean()),ember_retained_at128=float((actual[:,:,3][ember]>=128).mean()),dark_feather_retained_at128=float((actual[:,:,3][dark]>=128).mean()),background=detail)
        matte.save(target/f'calibration-{take}-{index}.png');records.append(rec)
        print('FEATHER_CALIBRATION',take,index,rec['opaque_retained_at128'],rec['ember_retained_at128'],rec['dark_feather_retained_at128'],flush=True)
    p.write(p.SOURCE_DIR/'feather_matte_calibration.json',dict(original_guides=records,rule='Known original opaque feathers, ember marks and dark anatomy must survive pinned extraction. Generated video acceptance still requires all chronological RGB/alpha and native review.'))
    assert all(min(r['opaque_retained_at128'],r['ember_retained_at128'],r['dark_feather_retained_at128'])>=.95 for r in records), 'Original anatomy lost in matte; inspect before accepting generated frames'
