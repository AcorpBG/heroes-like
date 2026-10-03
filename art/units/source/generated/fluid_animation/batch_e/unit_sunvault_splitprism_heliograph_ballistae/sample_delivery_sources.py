"""Sample reviewed originals at 12fps; retain rapid physical contacts at 24fps."""
import json
import produce as p
import build_delivery as build

TAKES={
    'ranged_h3_v2': range(22,29),
    'attack_h3_v1': range(64,69),
    'hit_h3_v2': range(40,45),
    'defend_h3_v2': (),
    'death_h3_v2': range(70,85),
    'cast_h3_v3': (),
}

def main():
    baseline=json.loads((p.SOURCE_DIR/'original_unit_baseline.json').read_bytes())
    total=0
    for take,dense in TAKES.items():
        folder=p.SOURCE_DIR/take
        original=folder/'selection_full24fps.json'
        if not original.exists():
            original.write_bytes((folder/'selection.json').read_bytes())
        old=json.loads(original.read_bytes());indices=old['source_frames']
        assert all(b==a+1 for a,b in zip(indices,indices[1:]))
        selected=sorted(set(indices[::2])|({indices[-1]})|(set(dense)&set(indices)))
        durations=[(b-a)*old['frame_msec'] for a,b in zip(selected,selected[1:])]+[old['frame_msec']]
        assert sum(durations)==len(indices)*old['frame_msec']
        new=dict(old,source_frames=selected,frame_msec=84,
            frame_durations_msec=durations,
            review_note=old['review_note']+' Production sampling keeps original duration and all physical contact/collapse transitions; 12fps elsewhere, original24fps source retained. Retimed native runtime review remains pending.',
            sampling=dict(full24fps_selection_sha256=p.sha(original),
                rule='Observed originals only: every second24fps frame plus unchanged dense physical contact interval and final original.',
                dense_source_frames=list(dense),original_duration_msec=len(indices)*old['frame_msec']))
        if 'contact_frame' in old:
            source_contact=indices[old['contact_frame']]
            assert source_contact in selected
            new['contact_frame']=selected.index(source_contact)
            assert sum(durations[:new['contact_frame']])==old['contact_frame']*old['frame_msec']
        p.write(folder/'selection.json',new)
        part=build.build(take,baseline)
        assert len(part['frames'])==len(selected)
        total+=len(selected)
        print(take,len(indices),'->',len(selected),'originals;',sum(durations),'ms unchanged',flush=True)
    print('SIX_SOURCE_PARTS',total,'originals; full-unit runtime acceptance still pending',flush=True)

if __name__=='__main__':main()
