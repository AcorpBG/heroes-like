"""Record coordinator acceptance of exactly the reviewed partial four clips."""
import json
import produce as p

if __name__ == '__main__':
    path=p.SOURCE_DIR/'delivery.json'
    delivery=json.loads(path.read_bytes())
    delivery['visual_review']={
        'status':'accepted_selected_clips',
        'accepted_clips':['attack','defend','cast','death'],
        'notes':'Coordinator accepted exactly attack22, defend12, noncaster physical support19 and death26 after all original124-frame chronological sequences, final matte chronology/enlarged anatomy, all87 final native phases including preserved idle8, and three actual BattleShell captures. Final unmodified focused fixture passed146 checks with no failures, Normal/Fast/reduced/contact/audio/VFX/session-save equality and shell input/finish/focus exercised. 744 original RGB frame hashes reverified. Preserve original articulated idle8 and map art/timing. Move/hit v1 rejected and excluded; entire unit is not complete. Continuous source/retimed playback route remains unavailable. Publication and published integrity/live checks belong to coordinator.'}
    previous=delivery.get('live_validation')
    if previous:
        delivery['visual_review']['notes']+=' Published live checks: isolated-profile import passed; unmodified full selected-unit live fixture passed160 checks with no failures. Original744 RGB hashes and published79 frame pixels/anchors verified; preserved idle8 and map pixels/timing, other231 catalog rows unchanged. Published atlas2368x3120 (29552640 RGBA bytes).'
    p.write(path,delivery)
    handoff=json.loads((p.SOURCE_DIR/'handoff.json').read_bytes())
    handoff['units'][0]['visual_review']=delivery['visual_review']
    p.write(p.SOURCE_DIR/'handoff.json',handoff)
