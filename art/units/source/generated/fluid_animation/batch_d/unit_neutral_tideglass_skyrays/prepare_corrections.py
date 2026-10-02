"""Repair named motion defects using unmodified observed H3 contact/wing poses."""
import json
import produce as p
from prepare import ref,IDENTITY

def observed(take,index):
 source=p.SOURCE_DIR/take/'matte'/f'rgba_{index:03}.png'
 record=json.loads((p.SOURCE_DIR/take/'original.json').read_bytes())
 return dict(source=source.relative_to(p.ROOT).as_posix(),rects=[[0,0,960,544]],anchor=[480,480],scale=.5,alpha_noise_cutoff=0,original_video=(p.SOURCE_DIR/take/'original_lossless.mkv').relative_to(p.ROOT).as_posix(),original_video_sha256=record['sha256'],original_rgb_sha256=record['decoded_rgb_sha256'][index],original_video_frame=index,original_video_time_seconds=index/24,matte_recipe=(p.SOURCE_DIR/take/'matte.json').relative_to(p.ROOT).as_posix())

def correction(clip,refs,guides,last,prompt,seed):
 out=p.SOURCE_DIR/(clip+'_h3_v3');out.mkdir(exist_ok=True)
 c=dict(unit_id='unit_neutral_tideglass_skyrays',clip=clip,canvas=[960,640],anchor=[480,576],scale=.5,key_rgb=[0,0,255],seed=seed,references=refs,guides=guides,last=last,prompt=IDENTITY+prompt+' Flat blue background, locked camera, no floor/shadow/scenery/particles/projectile. Extra upper canvas clearance keeps BOTH wing tips inside the frame. Body stays at the same physical reference size. Do not rotate toward camera, zoom, resize, add bells/appendages or cut between states.',protected_foreground_chroma=0,tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
 p.prepare(out,c);p.write(out/'config.json',c);p.verify(out,c)

if __name__=='__main__':
 correction('attack',[ref(16),observed('attack_h3_v2',40)],[[48,1]],0,' One coherent close-range ram. First second draw pointed head and chest back to load, fold near and far wings slightly backwards; then drive the snout SCREEN RIGHT to the single frame48 contact painting, belly bells and soft ribbons trail behind. Unfold and recover smoothly for the remainder to exact ready. Do not make a second charge, fly upward or twist the body down. Continuous jointed motion between all poses, no snap/cut. ',2026105102)
 correction('defend',[ref(16),observed('cast_h3_v2',24),observed('defend_h3_v2',57)],[[32,1],[64,2]],2,' Continuous defensive wing curl beginning immediately. In the first third lift and curve BOTH original membranes upward to the halfway painting at frame32, then keep bending their roots to form a protective canopy over the pointed head and attached bell harness at frame64. Head tucks only slightly, original tail and soft fin ribbons curl close. Hold that complete guard through the last second. Every intermediate wing angle must be visible: do not hold ready and abruptly replace it with the guard. Same ray body/camera/harness throughout. ',2026105105)
 for take,reason in [('attack_h3_v2','Raised wings clip the upper canvas at frames60-61 and contact guide produces an abrupt orientation change.'),('defend_h3_v2','Missing brace transition: ready is replaced by a fully folded canopy at frame57.')]:
  p.write(p.SOURCE_DIR/take/'review.json',dict(status='rejected_motion_defect',reason=reason,reviewed_all124_chronological_frames=True,enlarged_suspect_frames_reviewed=True,originals_preserved=True))
 d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());d['takes']=[t.replace('attack_h3_v2','attack_h3_v3').replace('defend_h3_v2','defend_h3_v3') for t in d['takes']];d['visual_review']['notes']+=' Rejected attackv2 clipped upper wing tips/frame63-to64 snap and defendv2 missing brace transition. Correct those two only with original observed contact/partial-wing/guard guides and 96px additional headroom; fixed .5 output scale remains unchanged.';p.write(p.SOURCE_DIR/'delivery.json',d)
