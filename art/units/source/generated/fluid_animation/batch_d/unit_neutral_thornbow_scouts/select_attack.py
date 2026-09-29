"""Assemble reviewed original raise, shove and recovery without interpolation."""
import json
import produce as p

opening=list(range(12,21,2))+list(range(21,35))+list(range(36,51,2))
body=list(range(29,46))+[48,52,56,60,64,67]+list(range(68,109,2))
for take,indices,note in [
 ('attack_raise_h3_v4',opening,'All124 chronological frames and enlarged12/16/18/20/21/22/23/24/28/34/42/50 reviewed. New original halfway guide preserves both arms, bow and face through raising. Same final windup as attack_v1 frame29; native join review pending.'),
 ('attack_h3_v1',body,'Retained guard-to-shove and recovery after the rejected23-24 opening smear. All original frames reviewed; select dense contact and alternate recovery frames, shorten static hold. No reversal or interpolation.')]:
 out=p.SOURCE_DIR/take
 s=dict(source_frames=indices,frame_msec=32,review_note=note)
 if take=='attack_h3_v1':s['contact_frame']=indices.index(45)
 p.write(out/'selection.json',s);p.build(out,json.loads((out/'config.json').read_bytes()))
d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
d['attack_segments']=['attack_raise_h3_v4','attack_h3_v1']
d['attack_frame_msec']=32
d['attack_contact_frame']=len(opening)+body.index(45)
d['attack_timing_reason']='Retimed selected original24fps frames to32ms for a2.272-second anticipation/contact/recovery. Dense original samples around contacts; long source holds shortened. No synthetic frames.'
d['visual_review']=dict(status='pending',notes='Seven dedicated H3 actions assembled, all originals inspected chronologically and enlarged equipment details reviewed. Candidate battle-scale review pending. Eight accepted idle/map frames preserved. No continuous-playback or manual-playtest claim.')
p.write(p.SOURCE_DIR/'delivery.json',d);p.assemble()
print('Melee frames:',len(opening)+len(body),'contact:',d['attack_contact_frame'])
