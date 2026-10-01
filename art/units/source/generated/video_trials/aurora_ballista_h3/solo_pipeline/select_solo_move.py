"""Select one original rolling cycle; preserve all seven accepted actions."""
import copy,json
import produce as p

if __name__=='__main__':
 out=p.SOURCE_DIR/'move_rigid_phase_v6'
 selection=dict(source_frames=list(range(32,48)),frame_msec=42,review_note='Pending native review. All124 original RGB/matte frames viewed chronologically, both wheel faces enlarged; selected original32..47 retain straight eight-spoke phase progression about fixed hubs/rims and folded supports. Source48 matches32 wheel phase; inspect47-to32 boundary. Fixed960x544/.425 scale/480,520 root; no generated derivatives, interpolation, reversing, padding, wheel rotation/warps or per-frame normalization. Preserve original42ms-per-frame timing (672ms loop); brief source motion blur stays original. Continuous video playback/manual playtest unclaimed.')
 p.write(out/'selection.json',selection);p.build(out,json.loads((out/'config.json').read_bytes()))
 previous=json.loads((p.ROOT/'art/animation/source/fluid/unit_aurora_ballista/reviewed_handoff.json').read_bytes())['units'][0]
 movement=json.loads((out/'handoff.json').read_bytes())['units'][0]
 combined=p.combine(previous,movement)
 sources=copy.deepcopy(previous['provenance'])
 # The older combined recipe retained only the last action's original records.
 # Recover the unchanged accepted takes' complete lineage explicitly.
 for take in ['attack_v1','ranged_v1','defend_v1','hit_v1','cast_v1','death_v1']:
  accepted=json.loads((p.SOURCE_DIR.parent/take/'handoff.json').read_bytes())['units'][0]
  for key,record in accepted['provenance'].items():
   assert p.sha(p.ROOT/record['path'])==record['sha256'],record['path']
   sources[take+'_'+key]=record
 combined['provenance']={**sources,**{'move_rigid_phase_v6_'+k:v for k,v in movement['provenance'].items()}}
 combined['preserved_accepted_clips']=['idle'];combined['visual_review']=dict(status='pending',notes=selection['review_note']+' Accepted idle8/attack25/ranged24/hit17/defend14/support22/death26+dead remain unchanged.')
 p.write(p.SOURCE_DIR/'handoff_solo_move.json',dict(schema_version=1,units=[combined]))
 p.write(p.SOURCE_DIR/'solo_delivery.json',dict(unit_id='unit_aurora_ballista',baseline_commit='167d3616405056af9841761a47b273741b816fd5',new_takes=['move_rigid_phase_v6'],new_clips=['move'],preserved_published_clips=['idle','attack','ranged','hit','defend','cast','death','dead'],visual_review=combined['visual_review'],source_indices=selection['source_frames'],runtime_frame_msec=42,reassessment='Five unsuccessful rigid-spoke attempts were reassessed. Isolated authored half-spoke phase supported two consistent full-carriage guide phases pinned every8frames; all original intermediates independently reviewed. Solo work; no agents.'))
 print('Pending original rolling16, seven published actions and map idle retained')
