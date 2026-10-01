"""Retain one original reciprocal gait cycle, preserving six accepted actions."""
import json,copy
import numpy as np
from PIL import Image
from scipy.ndimage import label
import produce as p
if __name__=='__main__':
 out=p.SOURCE_DIR/'move_h3_v3';indices=list(range(61,122,2));exclusions={}
 for i in indices:
  im=np.asarray(Image.open(out/'matte'/f'rgba_{i:03}.png'));labs,n=label(im[:,:,3]>=8,structure=np.ones((3,3),np.uint8));counts=np.bincount(labs.ravel());body=int(np.argmax(counts[1:])+1)
  box=[232,388,248,406];x0,y0,x1,y1=box;region=labs[y0:y1,x0:x1];area=int(np.count_nonzero(region))
  if area:
   assert area<=150 and not np.any(region==body)
   exclusions[str(i)]=dict(background_rect=box,reason='Disconnected68-75pixel pale fragment inherited from legacy run-guide crop, left of all cloth/body/rope; explicit original-pixel boundary excludes only this noncharacter fragment. All original matte/video retained.')
 selection=dict(source_frames=indices,frame_msec=35,original_pixel_exclusions=exclusions,review_note='Pending native acceptance. All124 original RGB and matte frames viewed chronologically, all31 selected gait phases enlarged on dark/light. One complete cycle source61..121 sampled every2frames, then121-to61matching stride boundary; near/far knee guards retain independent thighs/shins/boots and alternating contacts, loading and passing. No standing pause, two arms keep compact twin-hook pole grips and original rope/cloth. Fixed960x640canvas/.5scale/470,560root. Gameplay35ms yields1085ms loop from2.54s slow source; no reversals, duplicate padding, interpolation, stabilization or per-frame normalization. Only verified disconnected pale source fragment excluded by documented crop, no subject erased. Continuous video playback/manual test unclaimed.')
 p.write(out/'selection.json',selection);p.build(out,json.loads((out/'config.json').read_bytes()))
 previous=json.loads((p.ROOT/'art/animation/source/fluid/unit_neutral_kitehook_runners/reviewed_handoff.json').read_bytes())['units'][0]
 move=json.loads((out/'handoff.json').read_bytes())['units'][0]
 combined=p.combine(previous,move);combined['provenance']={**copy.deepcopy(previous['provenance']),**{'move_h3_v3_'+k:v for k,v in move['provenance'].items()}}
 combined['preserved_accepted_clips']=['idle'];combined['visual_review']=dict(status='pending',notes=selection['review_note']+' Previously accepted attack22/hit19/defend12/support19/death26+dead and articulated idle8 remain unchanged.')
 p.write(p.SOURCE_DIR/'handoff_solo_move.json',dict(schema_version=1,units=[combined]))
 p.write(p.SOURCE_DIR/'solo_delivery.json',dict(unit_id='unit_neutral_kitehook_runners',baseline_commit='bb92e54f9bea9856fa20cb3e44a0b5b8eafd1aad',new_takes=['move_h3_v3'],new_clips=['move'],preserved_published_clips=['idle','attack','hit','defend','cast','death','dead'],visual_review=combined['visual_review'],source_indices=indices,runtime_frame_msec=35,reassessment='Two previous failed gait attempts had upright ready holds. New matched near/far passing guides and opposed contacts maintain continuous gait with four phase guides twice. No agents used.'))
 print('Pending solo movement31; other6 accepted actions retained exactly; crop exclusions',len(exclusions))
