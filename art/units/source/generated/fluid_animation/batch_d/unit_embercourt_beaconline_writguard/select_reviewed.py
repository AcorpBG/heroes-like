"""Select observed original motion; pending native acceptance."""
import json
import produce as p
def choose(take,indices,note,contact=None,exclusions=None):
 out=p.SOURCE_DIR/take;c=json.loads((out/'config.json').read_bytes());s=dict(source_frames=indices,frame_msec=42,review_note=note)
 if contact is not None:s['contact_frame']=contact
 if exclusions:s['original_pixel_exclusions']=exclusions
 p.write(out/'selection.json',s);p.build(out,c)
if __name__=='__main__':
 choose('move_h3_v1',list(range(0,33)),'First complete reciprocal walking cycle. Both leg contact/loading/passing phases, stable right-hand standard and left-hand axe/forearm shield. Later repeated cycles excluded; no root normalization.')
 choose('hit_h3_v1',list(range(18,36))+list(range(49,56)),'First backward lean and recovery, removing unchanged recoil hold35-49 across matching posture. Later unrequested second recoil excluded. Standard/axe/shield retained.')
 exclusions={}
 for i in range(29,40):
  rects=[]
  if i>=30:rects.append([580,264,601,292])
  if i<=35 or i==39:rects.append([258,462,280,480])
  exclusions[str(i)]=dict(background_rects=rects,kind='reviewed_disconnected_background_specks',reason='Personally inspected original pixels: two isolated pale backdrop flecks above/right of body and below/left of standard; never cloth, anatomy, lamps, equipment or overlapping effects. <=150 pixels per rectangle; full original matte/video retained.')
 choose('death_h3_v1',list(range(18,40)),'Continuous knee bend, descent, sideways roll and grounded head-left corpse with standard/axe resting down and shield on left forearm. Original poses retain source-wide scale; sparse independently reviewed backdrop flecks excluded only via original-pixel rectangles.',exclusions=exclusions)
 choose('cast_h3_v1',list(range(22,42))+list(range(72,88)),'Dedicated physical right-arm raised-standard rally and lowered recovery. Left hand retains axe/left forearm shield. Peak support at source36. Unchanged raised-standard hold41-72 shortened across matching posture; no magic or attack alias.',contact=14)
 choose('attack_h3_v2',list(range(18,51))+list(range(67,99)),'Corrected clean left-axe windup, downward-forward release and articulated recovery, retaining right-hand original standard and left forearm shield. No baked swing arc. Contact source44 at maximum forward blade extension across torso height, preceding low follow-through50-67 hold that is shortened; recovery retained chronologically.',contact=26)
 out=p.SOURCE_DIR/'attack_h3_v2';s=json.loads((out/'selection.json').read_bytes());s['frame_msec']=33;s['retiming_reason']='Retain every selected original frame and its24fps source timestamp;30fps runtime tempo (33ms) keeps heavy armored melee/recovery2.145seconds instead of2.730seconds. Validate actual clock-driven Normal/Fast/reduced motion before acceptance.';p.write(out/'selection.json',s);p.build(out,json.loads((out/'config.json').read_bytes()))
 specks={str(i):dict(background_rect=[542,78,566,89],kind='reviewed_disconnected_background_speck',reason='Isolated horizontal dark artifact above/right of standard and helmet, inherited from legacy brace source;<=150 original pixels, never original equipment/anatomy. Unmodified matte/video preserved.') for i in range(22,34)}
 choose('defend_h3_v2',list(range(18,34)),'Dedicated planted knee/shield brace with stable original standard head, two original arms and held guard. Isolated inherited backdrop dash removed through original-pixel crop only.',exclusions=specks)
 d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());d['takes']=['move_h3_v1','attack_h3_v2','hit_h3_v1','defend_h3_v2','cast_h3_v1','death_h3_v1'];d['visual_review']=dict(status='pending',notes='Six dedicated original H3 actions selected after complete chronological review of eight takes; two original failures retained. Corrected clean axe motion and original standard in guard. Review every native/mirrored phase, contact/recovery timing and retained idle before publication.');p.write(p.SOURCE_DIR/'delivery.json',d);p.assemble();print('Six actions assembled:197 original new poses, native acceptance pending.')
