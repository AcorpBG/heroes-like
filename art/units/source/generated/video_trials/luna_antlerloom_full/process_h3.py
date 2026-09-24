"""Losslessly matte/review an H3 source video and build the pending handoff."""
import argparse,hashlib,json
from pathlib import Path
import av,numpy as np
from scipy.ndimage import label
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[6]
BASE=Path(__file__).resolve().parent
UID='unit_thornwake_stagknot_runners_veteran'
REFERENCE_HEIGHT=256
MINIMUMS={'idle':8,'move':8,'attack':8,'hit':4,'defend':4,'cast':8,'death':8}
ACTIONS=tuple(MINIMUMS)
PROMPT_FILE=BASE/'prepare_h3.py'

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,d):p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
def key(rgb):
 a=np.asarray(rgb,dtype=np.float32)
 corner_tiles=[a[:24,:24],a[:24,-24:],a[-24:,:24],a[-24:,-24:]]
 corner_medians=np.array([np.median(tile.reshape(-1,3),axis=0) for tile in corner_tiles])
 bg=np.median(corner_medians,axis=0)
 spread=float(np.max(np.linalg.norm(corner_medians-bg,axis=1)))
 if spread>10:raise ValueError(f'unsafe spatially varying corner plate {bg}; median spread={spread:.2f}')
 if bg[1] < bg[0]*.5 and bg[1] < bg[2]*.5:
  # Flat magenta key: preserve greens and unmix anti-aliased boundaries.
  chroma=np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1]
  bgc=min(bg[0],bg[2])-bg[1]
  if bgc<32:raise ValueError(f'unsafe magenta corner key estimate {bg}')
  alpha=np.clip((bgc-chroma)/bgc,0,1)
  color=np.clip((a-(1-alpha[:,:,None])*bg)/np.maximum(alpha[:,:,None],.001),0,255)
  mode='flat_magenta_chroma_unmix'
 else:
  # Some H3 samples switch to another perfectly flat color plate mid-clip.
  # Estimate its alpha by projecting edge pixels onto the nearest confidently
  # foreground color in the same frame, preserving green foliage on green plates.
  from scipy.ndimage import distance_transform_edt
  dist=np.linalg.norm(a-bg,axis=2); sure=dist>80
  if not np.any(sure):raise ValueError(f'no confident foreground pixels against flat plate {bg}')
  dist_to,inds=distance_transform_edt(~sure,return_indices=True)
  foreground=a[inds[0],inds[1]]; fv=foreground-bg; dv=a-bg
  alpha=np.clip(np.sum(dv*fv,axis=2)/np.maximum(1,np.sum(fv*fv,axis=2)),0,1)
  alpha[sure]=1
  alpha[dist<18]=0
  color=np.clip((a-(1-alpha[:,:,None])*bg)/np.maximum(alpha[:,:,None],.001),0,255)
  mode='flat_plate_projected_unmix_bg_distance_floor_18'
 out=np.dstack([color,alpha*255]).astype('uint8');out[out[:,:,3]<8]=0
 # Retain every >8-alpha connected creature component that contains at least
 # one confidently opaque pixel. This removes disconnected plate noise while
 # keeping thin antler branches, blossoms, hanging panels, and hooves attached
 # to their own solid pixels.
 mask=out[:,:,3]>=8; labels,n=label(mask,structure=np.ones((3,3),dtype=np.uint8))
 solid=np.unique(labels[out[:,:,3]>=128]); keep=np.zeros(n+1,dtype=bool);keep[solid]=True;keep[0]=False
 out[~keep[labels]]=0
 return Image.fromarray(out,'RGBA'),dict(background_rgb=[round(float(v),3) for v in bg],corner_median_spread=round(float(spread),3),mode=mode,component_rule='alpha>=8 components retained only when they contain alpha>=128 source pixels')

def process(action):
 folder=BASE/action; video=folder/'original_lossless.mkv'; mat=folder/'matte'; mat.mkdir(exist_ok=True)
 with av.open(str(video)) as c: frames=[f.to_image().convert('RGB') for f in c.decode(video=0)]
 if len(frames)!=124:raise ValueError(f'{action} decoded {len(frames)} source frames, expected 124')
 hashes=[]; bg_meta=[]
 for i,rgb in enumerate(frames):
  im,meta=key(rgb)
  if action=='cast_v4':
   # This original palette contains no magenta. Remove residual key-color
   # spill from RGB only; retain the extracted alpha and all fine branches.
   pixels=np.array(im,dtype=np.int16)
   spill=np.maximum(0,np.minimum(pixels[:,:,0],pixels[:,:,2])-pixels[:,:,1])
   pixels[:,:,0]-=spill; pixels[:,:,2]-=spill
   im=Image.fromarray(pixels.astype('uint8'),'RGBA')
   meta['despill']='subtract max(0,min(R,B)-G) from R and B; alpha unchanged; no magenta in original palette'
  p=mat/f'rgba_{i:03}.png'; im.save(p); hashes.append(sha(p)); bg_meta.append(meta)
 # Every fourth observed source frame in temporal order. The sheet is a review aid, not a pose count.
 chosen=list(range(0,124,4)); cell=(240,168); sheet=Image.new('RGB',(cell[0]*5,cell[1]*7),(38,45,34)); d=ImageDraw.Draw(sheet)
 for n,i in enumerate(chosen):
  x=n%5*cell[0];y=n//5*cell[1]; im=Image.open(mat/f'rgba_{i:03}.png').convert('RGBA'); im.thumbnail((240,136),Image.Resampling.LANCZOS)
  sheet.paste((38,45,34),(x,y,x+cell[0],y+cell[1])); sheet.paste(im,(x+(240-im.width)//2,y+24),im)
  d.text((x+6,y+5),f'{i:03d}  {i/24:.2f}s',fill='white')
 sheet.save(folder/'review_source_24fps.png')
 # 12fps keyed movie preview; all 124 RGBA samples remain individually preserved.
 images=[Image.open(mat/f'rgba_{i:03}.png').convert('RGBA').resize((480,272),Image.Resampling.LANCZOS) for i in range(0,124,2)]
 images[0].save(folder/'review_transparent_12fps.webp',save_all=True,append_images=images[1:],duration=83,loop=0,lossless=True)
 write(folder/'matte.json',dict(source='original_lossless.mkv decoded frames',source_frame_count=124,source_fps=24,key='per-frame median of four corner samples; reject if four 24px corner medians differ by more than 10 RGB-distance; magenta uses chroma unmix; alternate uniform plates use nearest confident foreground projection unmix',background_frames=bg_meta,alpha='per-frame unmix; disconnected alpha>=8 components without opaque (>=128) source pixels removed; no global cutoff increase',rgba_sha256=hashes,contact_sheet='review_source_24fps.png',animated_review='review_transparent_12fps.webp',review_status='pending'))
 print(json.dumps({'action':action,'matte_frames':len(hashes),'contact_sheet':str(folder/'review_source_24fps.png'),'animation':str(folder/'review_transparent_12fps.webp')}))

def build(selected_path):
 selection_document=json.loads(Path(selected_path).read_text(encoding='utf-8'))
 selections=selection_document['actions']
 actions=[name for name in ACTIONS if name in selections]
 unknown=set(selections)-set(ACTIONS)
 if unknown:raise ValueError(f'unknown actions in selection: {sorted(unknown)}')
 if not actions:raise ValueError('selection contains no clips')
 rows=[]; provenance={}
 for action in actions:
  selection=selections[action]; folder=BASE/selection.get('source_directory',action)
  ids=selection['source_frames']
  if len(ids)<MINIMUMS[action] or len(set(ids))!=len(ids):raise ValueError(f'{action} selection needs at least {MINIMUMS[action]} unique source frames')
  if any(not 0<=int(i)<124 for i in ids):raise ValueError(f'{action} selected source frame out of range')
  for i in ids:
   src=folder/'matte'/f'rgba_{int(i):03}.png'
   if not src.is_file():raise FileNotFoundError(src)
  selection['meaningful_phase_review']=selection.get('meaningful_phase_review','pending visual review')
  provenance[action]=dict(prompt_file=(folder/'prompt.txt').relative_to(ROOT).as_posix(),prompt_sha256=sha(folder/'prompt.txt'),workflow=(folder/'workflow_api.json').relative_to(ROOT).as_posix(),workflow_sha256=sha(folder/'workflow_api.json'),submission=json.loads((folder/'submission.json').read_text(encoding='utf-8')),original=(folder/'original_lossless.mkv').relative_to(ROOT).as_posix(),original_sha256=sha(folder/'original_lossless.mkv'),original_meta=json.loads((folder/'original.json').read_text(encoding='utf-8')),guides=json.loads((folder/'guides.json').read_text(encoding='utf-8'))['guides'],matte=(folder/'matte.json').relative_to(ROOT).as_posix())
 clips={}
 offset=0
 for action in actions:
  count=len(selections[action]['source_frames'])
  clips[action]=dict(indices=list(range(offset,offset+count)),frame_msec=int(selections[action].get('frame_msec',83)),loop=action in ('idle','move'),static_frame=count-1 if action in ('defend','death') else 0)
  sel=selections[action]
  if 'frame_durations_msec' in sel: clips[action]['frame_durations_msec']=sel['frame_durations_msec']
  if action in ('attack','cast'):
   contact=int(sel['contact_source_frame_index']); clips[action]['contact_frame']=min(range(count),key=lambda j:abs(int(sel['source_frames'][j])-contact))
   if action=='cast': clips[action]['static_frame']=clips[action]['contact_frame']
  offset+=count
 frames=[]
 for action in actions:
  sel=selections[action]; folder=BASE/sel.get('source_directory',action)
  count=len(sel['source_frames'])
  for source_i in sel['source_frames']:
   folder=BASE/sel.get('source_directory',action); src=folder/'matte'/f'rgba_{int(source_i):03}.png'
   frames.append(dict(name=f'{action}_h3_{int(source_i):03}',clip=action,source=src.relative_to(ROOT).as_posix(),rects=[[0,0,960,544]],anchor=[480,492],scale=.890625,alpha_noise_cutoff=0,video_frame=int(source_i),video_time_seconds=round(int(source_i)/24,6)))
 handoff=dict(schema_version=1,units=[dict(unit_id=UID,reference_height=REFERENCE_HEIGHT,source_facing='right',alpha_noise_cutoff=0,frames=frames,clips=clips,source_scale_reason='All action footage is 960x544 decoded H3 pixels. The prepared source guide uses 0.5 original-pixel scale while the original pose recipe uses 0.4453125; applying 0.890625 to H3 output preserves the original 256px anatomical reference and fixed ground anchor [480,492]. No per-pose scale or bounding-box stabilization.',provenance=dict(tool='local_comfyui_minimax_h3',actions=provenance),visual_review=dict(status='pending',notes=selection_document.get('review_note','Candidate requires independent visual acceptance; idle is shared with overworld playback.')))])
 out=BASE/'handoff.json';write(out,handoff);write(BASE/'selection_review.json',{'actions':selections,'excluded_actions':selection_document.get('excluded_actions',{}),'source_scale':.890625});print(out)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('verb',choices=['process','build']);p.add_argument('target');a=p.parse_args();process(a.target) if a.verb=='process' else build(a.target)
