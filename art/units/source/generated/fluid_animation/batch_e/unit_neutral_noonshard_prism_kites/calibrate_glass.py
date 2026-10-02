"""Check known original glass pixels against the actual pinned neural matte."""
import numpy as np
from PIL import Image
import segment
import produce as p

def calibrate(net):
    records=[]
    for take,index in [('move_h3_v1',0),('move_h3_v1',1),('move_h3_v1',3),('attack_h3_v1',2),('death_h3_v1',3)]:
        folder=p.SOURCE_DIR/take
        original=np.asarray(Image.open(folder/f'guide_{index}_rgba.png').convert('RGBA'))
        rgb=Image.open(folder/f'guide_{index}_chroma.png').convert('RGB')
        matte,details=segment.extract(net,rgb)
        actual=np.asarray(matte)
        opaque=original[:,:,3]>=240
        bright_glass=opaque&(original[:,:,:3].astype(np.int16).sum(axis=2)>500)
        assert opaque.any() and bright_glass.any()
        rec=dict(take=take,guide=index,original_rgba_sha256=p.sha(folder/f'guide_{index}_rgba.png'),original_rgb_sha256=p.sha(folder/f'guide_{index}_chroma.png'),opaque_retained_at128=float((actual[:,:,3][opaque]>=128).mean()),bright_glass_retained_at128=float((actual[:,:,3][bright_glass]>=128).mean()),background=details)
        path=p.ROOT/'.artifacts/noonshard_prism_kite_h3'/f'calibration-{take}-{index}.png';matte.save(path)
        records.append(rec)
        print('GLASS_CALIBRATION',take,index,round(rec['opaque_retained_at128'],5),round(rec['bright_glass_retained_at128'],5),flush=True)
    p.write(p.SOURCE_DIR/'glass_matte_calibration.json',dict(original_guides=records,rule='Known original opaque painting and bright glass should survive semantic extraction. This calibration does not confer acceptance on generated video; all124 RGB/RGBA frames require visual inspection.'))
    assert all(r['opaque_retained_at128']>=.95 and r['bright_glass_retained_at128']>=.95 for r in records),'Pinned matte removes original glass; inspect calibration before using any extracted animation'
