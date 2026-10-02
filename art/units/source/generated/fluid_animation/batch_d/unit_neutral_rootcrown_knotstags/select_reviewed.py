"""Select chronological original H3 frames; never interpolate or warp poses."""
import json
import produce as p

selections = {
 'idle': ([0,10,16,20,24,28,32,36,40,52,64,76,84,88,92,96,104,123],160,None,0,
  'Near front-root lift and return, crown/ears/mane/tail response; six legs and three pods retained. Shorten stationary hold. Same eighteen phases for map idle; horizontal strip stays below 4096 pixels.'),
 'move': (list(range(0,124,2))+[123],42,None,0,
  'Two forward gait cycles with reciprocal front-root wrists and middle/hind hoof support. Original six-leg identity, matching ready endpoints, stationary ground anchor.'),
 'attack': ([0,12,24]+list(range(26,85,2))+list(range(86,105,2))+[112,123],33,68,68,
  'Load weight, lower and drive attached crown forward, contact at original frame 68, recover. Keep three seedpods and six supporting legs. No projectile or fabricated ranged action.'),
 'hit': ([0,6]+list(range(8,65,2))+[80,123],33,None,32,
  'Chest/neck recoil with front-root bend and tail reaction, then recover. Peak recoil is the reduced-motion pose.'),
 'defend': ([0,6]+list(range(8,41,2))+[56,88,123],42,None,123,
  'Lower shoulders and crown into a held protective stance. Six limb groups stay attached; last frame is held guard.'),
 'cast': ([0,10,16]+list(range(18,37))+[48,64,80]+list(range(84,109))+[116,123],33,34,34,
  'Physical rally/support gesture: front-root curls up, neck and crown respond, wrist lowers to ready. Shorten the held gesture. No invented spell projectile; peak lift is reduced-motion pose.'),
 'death': ([0,8,16,20]+list(range(22,49))+[56,68,80,86]+list(range(88,109))+[116,123],33,None,123,
  'Original two-stage collapse: legs buckle and fold beneath torso, then neck/crown settle to ground. Shorten the crown-up pause while retaining its intermediate descent. Grounded final corpse faces right; far folded legs are naturally occluded.'),
}

for clip,(indices,msec,contact,static,note) in selections.items():
 assert indices==sorted(set(indices)) and indices[0]==0 and indices[-1]==123
 take=p.SOURCE_DIR/(clip+'_h3_v2')
 selection=dict(source_frames=indices,frame_msec=msec,static_frame=indices.index(static),review_note=note)
 if contact is not None: selection['contact_frame']=indices.index(contact)
 p.write(take/'selection.json',selection)
 p.build(take,json.loads((take/'config.json').read_bytes()))
p.assemble()
print('Selected original poses:',{k:len(v[0]) for k,v in selections.items()},'total',sum(len(v[0]) for v in selections.values()))
