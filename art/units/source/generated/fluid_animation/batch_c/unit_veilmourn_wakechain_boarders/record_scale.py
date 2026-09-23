import json
from pathlib import Path
p=Path(__file__).parent/'handoff.json'; h=json.loads(p.read_text()); u=h['units'][0]
u['source_scale_by_image']={f['source']:f['scale'] for f in u['frames']}
u['source_scale_reason']='Source masters have different generated canvas and anatomical resolutions. One fixed scale is used for every drawing from each original master: idle/reaction .60; attack .63; death .55; support .65; gait source keys .285, source contact .277, original gait .67, 3-pose far half .34, 6-pose inbetweens .48. Pixel-exact connected-component cutout crops preserve those original master scales. No per-pose normalization, warping or body-size adjustment.'
p.write_text(json.dumps(h,indent=2)+'\n')
