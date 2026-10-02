"""Select visually reviewed original temporal action intervals; never synthesize poses."""
import json
import produce as p

def select(clip,indices,msec,note,contact=None,durations=None):
 out=p.SOURCE_DIR/(clip+'_h3_v1');assert indices==sorted(set(indices))
 selection=dict(source_frames=indices,frame_msec=msec,review_note=note)
 if contact is not None:selection['contact_frame']=indices.index(contact)
 if durations is not None:
  assert len(durations)==len(indices) and min(durations)>=30
  selection['frame_durations_msec']=durations
 p.write(out/'selection.json',selection);p.build(out,json.loads((out/'config.json').read_bytes()))
 print(clip,len(indices),'contact source',contact)

if __name__=='__main__':
 select('move',list(range(18,42)),42,'All124 original frames reviewed. Three complete coordinated four-wing cycles from18-41; retain each original downstroke and return through matching raised-wing loop boundary. Stable thorax, two feather antennae, six attached/occluded legs. Exclude opening/ending static waits and unrelated later flaps.')
 indices=[0,4,8,9,10]+[i for i in range(39,62) if i!=47]+list(range(63,92,2))+[100,123]
 durations=[35]*len(indices);durations[indices.index(46)]=70
 select('attack',indices,35,'All124 original frames reviewed, with enlarged44-55 contact transition. Join matching loaded-wing poses10/39 to remove repeated pre-strike flutter. Exclude malformed folded limb/wing frame47;46/48 keep adjacent original anticipation/extension,70ms interval. One front-pair claw rake at51, other four legs tucked/occluded, original wing support and leg recovery. No pixel repaint or interpolation.',contact=51,durations=durations)
 select('ranged',[0,4,7,8,9]+list(range(73,102))+[105,110,116,123],35,'All124 originals and enlarged charge/release/recovery reviewed. Join matching raised-wing charge9/73; exclude repeated charged flutter10-72. One amber-facet charge, wing-root fan release at96, original dimming/recovery. No baked projectile; game owns projectile flight.',contact=96)
 select('hit',[0,20]+list(range(24,32))+list(range(54,64))+[80,123],33,'All124 originals reviewed. Select one thorax/abdomen recoil with antenna and attached-leg response; join matching recoiled wing poses31/54 to remove repeated held-impact flutter. Recover through original58-63 into ready. Distinct from grounded death.')
 select('defend',[0,44]+list(range(46,90,2))+[92,96,104,112,123],42,'All124 originals reviewed. Remove initial ready wait; retain progressive folding four-wing canopy46-88, antenna bow and leg tuck, then settled guard. Terminal123 is held shield posture, never an idle alias.')
 select('cast',[0,6,10,12,14,16,18,20]+list(range(102,124,2))+[123],55,'All124 originals reviewed. One innate slow wing-fan/antenna bow with front-leg articulation and existing lantern glow. Join matching lifted wings20/102 to remove repeated signaling flutter, then gradual wing-root and leg recovery. Dedicated support video; no humanoid spellcasting or idle reuse.',contact=108)
 select('death',[0,8]+list(range(14,72,2))+[74,80,88,96,108,116,123],42,'All124 originals and enlarged collapse/landing/settling reviewed. Four-wing loss of lift, six-leg curl and attached antennae settle continuously; amber facets dim. Terminal123 retains original physical ground contact and holds corpse. Trim stationary waits without changing source scale or anatomical registration.')
 p.assemble()
