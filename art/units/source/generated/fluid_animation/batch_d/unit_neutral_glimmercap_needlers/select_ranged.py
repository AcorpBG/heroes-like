"""Assemble observed preparation, one corrected release and original recovery."""
import json
import numpy as np
from PIL import Image
from scipy.ndimage import label
import produce as p
from select_reviewed import select

if __name__=='__main__':
    prep=[0,12]+list(range(14,36))+[40,44]
    recovery=list(range(80,116))
    select('ranged_h3_v1',prep+recovery,35,'Retain original loaded-needle check/raise14-35 and loaded aim44, then empty pipe lowering/reload80-115. Neither rejected firing46-49 nor repeated shot74-79 is selected.',44)
    take='ranged_release_h3_v2';out=p.SOURCE_DIR/take
    indices=list(range(0,11))+[41,123]
    s=dict(source_frames=indices,frame_msec=35,contact_frame=3,review_note='One original loaded-to-empty release0-3, stable two-handed rigid pipe/grips, held empty aim. Separate only the fully detached video-owned dart3 onward across an empty vertical gap; runtime owns flight. Full original video and matte pixels remain retained.',runtime_projectile_separation={})
    for i in indices:
        im=Image.open(out/'matte'/f'rgba_{i:03}.png');pixels=np.asarray(im)[:,:,3]>=8
        labels,n=label(pixels,structure=np.ones((3,3),dtype=np.uint8));sizes=np.bincount(labels.ravel());sizes[0]=0;body=int(sizes.argmax())
        xmax=int(np.where(labels==body)[1].max())
        if i>=3 and pixels[:,xmax+6:].any():
            split=next(x for x in range(xmax+3,im.width-3) if not pixels[:,x-2:x+3].any() and pixels[:,x+3:].any())
            s['runtime_projectile_separation'][str(i)]=dict(split_x=split,reason='Fully detached source projectile to the right of rigid empty pipe. Five-column transparent gap; all body, hands and held equipment retained. Game owns projectile flight.')
    p.write(out/'selection.json',s);p.build(out,json.loads((out/'config.json').read_bytes()))
    path=p.SOURCE_DIR/'delivery.json';delivery=json.loads(path.read_bytes())
    delivery['takes']=['move_h3_v1','attack_h3_v1','hit_h3_v2','defend_h3_v1','cast_h3_v1','death_h3_v2','ranged_h3_v1',take]
    seq=[dict(take='ranged_h3_v1',video_frame=i) for i in prep]
    #44 is the exact loaded aim guide. The corrected take begins on the same
    #painting; omit that duplicate guide and preserve actual1-10 release.
    seq += [dict(take=take,video_frame=i) for i in indices if i!=0]
    seq += [dict(take='ranged_h3_v1',video_frame=i) for i in recovery]
    delivery['clip_sequences']={'ranged':dict(frames=seq,timing=dict(frame_msec=35,contact_frame=next(i for i,f in enumerate(seq) if f['take']==take and f['video_frame']==3)),review_note='Exact original loaded aim44 to the same guide in corrected release1; corrected empty terminal123 to original empty lowering80. No morph/crossfade or synthetic frame. One runtime-owned projectile.')}
    p.write(path,delivery)
    review=json.loads((p.SOURCE_DIR/'correction_review.json').read_bytes())
    review['rejected']['attack_h3_v2']='Needle becomes a long projectile38-45; retain failed original and use the first take with only50-52 malformed static settling excluded.'
    review['selected_repair']='Attack first take49->53 is an observed matching held body/grip, preserving all actual thrust frames44-49. Ranged corrected detached flight is separated from body across a verified transparent gap. Defense ends at valid held guard37. Hit/death use corrected footage.'
    p.write(p.SOURCE_DIR/'correction_review.json',review)
    p.assemble()
    u=json.loads((p.SOURCE_DIR/'handoff.json').read_bytes())['units'][0]
    print({k:len(v['indices']) for k,v in u['clips'].items()})
