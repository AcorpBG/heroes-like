"""Keep the original knee-fold and grounded roll between ready and corpse."""
import json
import produce as p

def main():
    folder=p.SOURCE_DIR/'death_h3_v1'
    assert not (folder/'sampling_submission.json').exists(), 'Submitted source is immutable'
    c=json.loads((folder/'config.json').read_bytes())
    original=json.loads((p.SOURCE_DIR/'original_reference_poses.json').read_bytes())['frames']
    c['references']=[original[i] for i in [0,9,10,11]]
    c['guides']=[[32,1],[74,2]]
    c['last']=3
    c['prompt'] += ' The first intermediate original guide is the knees-folded lowered torso, not a standing recoil. The second original guide shows the body rolled low with the arch and both pincers resting toward the same ground. Pass through these in order with continuous joint bending, then settle into the final original corpse without a cut or pose replacement.'
    p.write(folder/'config.json',c)
    p.prepare(folder,c)
    p.write(folder/'guide_review.json',dict(status='original_keyposes_reviewed_source_unsubmitted',original_pose_indices=[0,9,10,11],guide_frames=[32,74],native128_dark_light=True,notes='Original knee-fold, low roll and corpse personally inspected alongside all20 original poses. Both pincers, folded six-leg identity, back arch and attached rings remain coherent and share the recorded ground. Guides do not establish animation acceptance.'))
    print('ORIGINAL_DEATH_GUIDES_PREPARED_NO_GPU_SUBMISSION',flush=True)

if __name__=='__main__':main()
