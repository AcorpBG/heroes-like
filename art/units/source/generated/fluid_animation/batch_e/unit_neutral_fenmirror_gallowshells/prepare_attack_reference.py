"""Extract unchanged original-pixel contact art for a missing closed-jaw key."""
import json
from pathlib import Path
from PIL import Image
import prepare as p

def main():
    original=json.loads((p.S/'original_reference_poses.json').read_bytes())['frames'][6]
    source=p.ROOT/original['source'];assert p.sha(source)==original['source_sha256']
    rects=original['rects'];bounds=[min(r[0] for r in rects),min(r[1] for r in rects),max(r[2] for r in rects),max(r[3] for r in rects)]
    full=Image.open(source).convert('RGBA')
    crop=Image.new('RGBA',(bounds[2]-bounds[0],bounds[3]-bounds[1]))
    for r in rects:crop.paste(full.crop(r),(r[0]-bounds[0],r[1]-bounds[1]))
    file=p.S/'references/extended_open_pincer_original.png';crop.save(file)
    p.write(file.with_suffix('.crop.json'),dict(source=original['source'],source_sha256=p.sha(source),original_frame=6,original=original,union_bounds=bounds,anchor=[original['anchor'][0]-bounds[0],original['anchor'][1]-bounds[1]],extraction='Exact original rectangle pixels, including source alpha; no resize or repaint.',sha256=p.sha(file)))
    folder=p.S/'attack_h3_v1'
    p.write(folder/'visual_review.json',dict(status='rejected',personally_reviewed_original_rgb_frames=list(range(124)),alpha_inventory='124 source mattes produced and border measured; not claimed as personally reviewed',native_review='not performed: RGB contact motion already fails',defects=[dict(source_frames=list(range(35,44))+list(range(56,68)),description='Invented incoming gold ring/connecting beam grasped by upper forward pincer plus gold-white impact starburst. Effect touches legitimate contact anatomy; cannot remove with a disconnected-background crop.')],alpha8_border_frame_count=17,originals_preserved=True,next_correction='Original closed horizontal pincer key plus quiet empty-air joint articulation guidance; regenerate only attack.'))
    p.write(p.S/'move_h3_v1/visual_review.json',dict(status='source_qualified_native_runtime_pending',personally_reviewed_original_rgb_frames=list(range(124)),personally_reviewed_enlarged_alpha_frames=list(range(124)),personally_reviewed_native128_each_facing=list(range(124)),backgrounds=['dark','light'],notes='Original claws remain separate; reciprocal near/far walking-foot articulation, body weight transfer and hanging-ring sway remain coherent. No source-edge clipping. Full sequence inspected as chronological frames; continuous engine playback and loop seam at selected timing still pending.'))
    print('ORIGINAL CONTACT REFERENCE EXTRACTED; ATTACK V1 REJECTED; MOVE SOURCE QUALIFIED')

if __name__=='__main__':main()
