import json,hashlib
from PIL import Image
import produce as p
UID='unit_neutral_saltwake_bellwhales'
def local(path):return p.ROOT/path.removeprefix('res://')
out=p.SOURCE_DIR/'original_baseline.json';assert not out.exists()
row=next(r for r in json.loads((p.ROOT/'content/unit_animation_manifest.json').read_bytes())['items'] if r['unit_id']==UID)
maprow=json.loads((p.ROOT/'art/overworld/creature_idle.json').read_bytes())['units'][UID]
im=Image.open(local(row['pose_sheet'])).convert('RGBA');w,h=[row['pose_frame_size'][k] for k in ['width','height']];cols=row['pose_columns']
hashes=[hashlib.sha256(im.crop(((i%cols)*w,(i//cols)*h,(i%cols+1)*w,(i//cols+1)*h)).tobytes()).hexdigest() for i in row['pose_clips']['idle']['indices']]
p.write(out,dict(row=row,map_row=maprow,idle_rgba_sha256=hashes,map_png_sha256=p.sha(local(maprow['path'])),original_pose_atlas_sha256=p.sha(local(row['pose_sheet'])),curated_sha256=p.sha(local(row['curated_source']))))
print('IDLE_BASELINE_PRESERVED',len(hashes),flush=True)
