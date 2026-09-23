"""Record exact connected-source crop rectangles without repainting originals."""
import hashlib,json
from pathlib import Path
from PIL import Image
from extraction_components import components
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
REL=HERE.relative_to(ROOT).as_posix()
scales={'idle':.65,'move':.57,'attack':.65,'reactions':.65,'death':.57,'cast':.65}
ground={'idle':[432,911],'move':[412,818],'attack':[465,914],'reactions':[475,943],'death':[423,804],'cast':[479,963]}
frames=[];clips={};mapping={};lineage=json.loads((HERE/'lineage.json').read_text())
for name,scale in scales.items():
 source=f'{REL}/{name}_v1.png';im=Image.open(ROOT/source);parts=components(ROOT/source);assert len(parts)==8,(name,len(parts))
 mapping[source]=scale;starts={}
 for i,part in enumerate(parts):
  clip=('defend' if i<4 else 'hit') if name=='reactions' else name
  starts.setdefault(clip,len(frames));rects=[]
  for y,(l,r) in sorted(part['rows'].items()):
   if rects and rects[-1][0]==l and rects[-1][2]==r and rects[-1][3]==y:rects[-1][3]=y+1
   else:rects.append([l,y,r,y+1])
  row,col=divmod(i,4)
  frames.append({'name':f'{clip}_{i%4 if name=="reactions" else i:02d}','clip':clip,'source':source,'rects':rects,'anchor':[round((col+.5)*im.width/4),ground[name][row]],'scale':scale,'alpha_noise_cutoff':8})
 for clip,start in starts.items():
  n=4 if name=='reactions' else 8
  clips[clip]={'indices':list(range(start,start+n)),'loop':clip in ('idle','move'),'frame_msec':180 if clip=='idle' else 110,'static_frame':0}
  if clip in ('attack','cast'):clips[clip]['contact_frame']=4
  if clip=='death':clips['dead']={'indices':[start+7],'loop':False,'frame_msec':110,'static_frame':0}
 lineage[name].update(tool='built-in image_gen',source_file=source,prompt_file=f'{REL}/{name}_v1.prompt.txt',source_sha256=hashlib.sha256((ROOT/source).read_bytes()).hexdigest(),prompt_sha256=hashlib.sha256((HERE/f'{name}_v1.prompt.txt').read_bytes()).hexdigest(),reference_sha256={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in lineage[name]['reference_paths']})
handoff={'schema_version':1,'units':[{'unit_id':HERE.name,'reference_height':256,'source_facing':'right','frames':frames,'clips':clips,'preserve_clips':[],'accepted_clips':[],'source_scale_by_image':mapping,'source_scale_reason':'One scale per source master targets existing approximately 235px creature width and 200px antler height. Move/death masters have larger source drawings; no pose-specific autoscale.','visual_review':{'status':'pending','notes':'All poses replaced; idle forepaw lift/return and head breath. Original connected-source crop rectangles prevent neighboring tail/toe contamination. Coordinator to inspect sequence and game scale.'}}]}
(HERE/'handoff.json').write_text(json.dumps(handoff,indent=2)+'\n');(HERE/'lineage.json').write_text(json.dumps(lineage,indent=2)+'\n');print(HERE.name,len(frames),'paintings ready for review')
