"""Original three-person Resonant Chorister references and distinct action briefs."""
import json
from pathlib import Path
SOURCE=Path(__file__).resolve().parent
UNIT='unit_sunvault_resonant_choristers'
IDENTITY=(
 'Locked orthographic camera. Rich original hand-painted fantasy strategy sprite, full group visible against a perfectly flat vivid GREEN RGB(0,255,0) background and green limb gaps. '
 'Exactly THREE adult human choristers in the same compact formation, each with exactly two arms and two legs. '
 'The tall central lead has long fair hair and carries one long straight gold staff with one large circular gold sun ring, blue-violet central jewel and fixed small crystal points at its top. '
 'At IMAGE LEFT stands the shorter light-skinned short brown-haired book reader holding one open dark-bound crystal hymn book in both hands. '
 'At IMAGE RIGHT stands the dark-skinned dark-haired percussionist holding one round gold-and-blue crystal hand drum at chest height. '
 'All three wear their own white and deep-blue robes with ornate gold trim, white/gold shoulder armor and golden boots. '
 'Maintain their three distinct faces, six legitimate arms, six legs, clothing, relative positions and original equipment. '
 'Hands remain connected to the same staff, open book and hand drum; each instrument keeps its original fixed geometry and attached crystals. '
 'The group faces three-quarter image right at fixed anatomical scale, grounded on the same horizontal plane. '
 'Camera and lighting remain still. The surrounding background stays uniformly green and empty throughout. Only the original bodies, robes and carried instruments are visible. '
)
ACTIONS={
 'move':([2],0,[],
  'The three people walk in place through two relaxed complete reciprocal gait cycles. Each alternates their own two boots through contact, load, lift, passing and planting. '
  'Their torsos stay centered for engine travel, their relative formation is maintained and their garments follow the steps. '
  'The center lead keeps the staff upright, the left reader holds the book, and the right player holds the drum. Finish naturally at the original contact phase.'),
 'defend':([18,8],1,[],
  'The group lowers smoothly into a held protective crouch. All three bend their knees under their own bodies. '
  'The center lead brings the staff diagonally across the front with both hands; left reader hugs the book and the right player keeps the drum close. '
  'They remain alert in the final low braced stance, with their three heads and instruments clearly separate.'),
 'hit':([18,10],0,[[42,1]],
  'One brief physical jolt makes the three choristers flex their knees and recoil through shoulders and heads, while retaining all instruments. '
  'The lead leans back moderately and both companions react in their own places. They regain balance gradually and return to the original ready formation.'),
 'attack':([18,6,7],0,[[32,1],[60,2]],
  'One physical staff thrust by the central lead. The lead draws the same staff diagonally back, then extends it toward image right using both arms and shoulders. '
  'Both hands stay on the one rigid shaft. Recover by retracting the staff and returning it upright. '
  'The two companions brace their feet and hold the same book and drum in their own places. The circular staff head remains an unchanged solid ornament.'),
 'ranged':([15,16],0,[[52,1]],
  'One coordinated projected-voice action. The three singers inhale visibly through shoulders, lift their chins, open their mouths and sing toward image right. '
  'The lead raises the upright staff slightly, the left singer presents the open hymn book forward and the right singer raises the drum slightly while retaining it. '
  'Their mouths close as shoulders and forearms settle naturally back into the original ready stance. All crystals remain fixed, solid painted objects.'),
 'cast':([18,11],0,[[54,1]],
  'One solemn supportive kneeling ritual. All three slowly bend their knees, incline their heads and lower their carried instruments toward their own laps in a shared respectful bow. '
  'After a brief low kneeling pause, they stand smoothly back up, extend their knees and lift their heads into the original ready formation. '
  'The lead keeps the same staff in both hands, while companions retain the open book and hand drum. This is a calm physical bow and rise.'),
 'death':([18,11],1,[],
  'First part of a continuous collapse: the three choristers lose strength and lower smoothly from standing to kneeling in their own formation. '
  'Their knees bend gradually, hips descend and heads bow. The lead lowers the same staff diagonally with both hands; the companions retain book and drum. '
  'Reach the original kneeling pose through continuous articulated bending, with all three bodies separate and grounded. End held on the knees.'),
}
DEATH_PARTS={
 'death_fall_v1':([11,12],
  'Continue from the original kneeling formation into a supported side fall. The lead gradually tips toward image left, bends the supporting arms and lowers the long staff across the foreground. '
  'The left reader and right drummer each lower their own upper body and instrument onto the floor within their original place. '
  'All three retain their bodies, faces, clothing and instruments. Reach the original low side-fallen pose continuously with heads leftward and all equipment lowered.'),
 'death_settle_v1':([12,14],
  'Continue from the low side-fallen group. The three supporting elbows gradually bend and all shoulders and heads settle gently onto the ground. '
  'Keep the lead head toward image left and legs toward image right. The long staff lies across the foreground, the book stays beside the left reader and the drum beside the right player. '
  'Cloth and limbs settle into the original fully grounded three-person corpse. End completely still.'),
}
def pose(index):
 x,y=index%4*512,index//4*256
 return dict(source=f'art/animation/runtime/poses/{UNIT}.png',rects=[[x,y,x+512,y+256]],anchor=[x+256,y+248],scale=1,alpha_noise_cutoff=8)
if __name__=='__main__':
 for number,(clip,(indices,last,guides,action)) in enumerate(ACTIONS.items()):
  out=SOURCE/f'{clip}_v1';out.mkdir(exist_ok=True);assert not (out/'submission.json').exists()
  config=dict(unit_id=UNIT,clip=clip,scale=.8,anchor=[480,480],key_rgb=[0,255,0],protected_foreground_chroma=56,
   references=[pose(i) for i in indices],last=last,guides=guides,seed=926101+number,
   tiled_decode=dict(tile_size=256,overlap=64,temporal_size=16,temporal_overlap=4),prompt=IDENTITY+action)
  (out/'config.json').write_text(json.dumps(config,indent=2)+'\n',encoding='utf-8')
 for number,(take,(indices,action)) in enumerate(DEATH_PARTS.items()):
  out=SOURCE/take;out.mkdir(exist_ok=True);assert not (out/'submission.json').exists()
  config=dict(unit_id=UNIT,clip='death',scale=.8,anchor=[480,480],key_rgb=[0,255,0],protected_foreground_chroma=56,
   references=[pose(i) for i in indices],last=1,guides=[],seed=926108+number,
   tiled_decode=dict(tile_size=256,overlap=64,temporal_size=16,temporal_overlap=4),prompt=IDENTITY+action)
  (out/'config.json').write_text(json.dumps(config,indent=2)+'\n',encoding='utf-8')
 (SOURCE/'delivery.json').write_text(json.dumps(dict(takes=[],visual_review=dict(status='pending',notes='Original three-person identity and native action review required.')),indent=2)+'\n',encoding='utf-8')
