"""Literal-anatomy conditioning for the four not-yet-submitted original actions."""
import json
import produce as p
S=p.SOURCE_DIR
corrected=json.loads((S/'ranged_h3_v3/config.json').read_bytes())['prompt']
identity=corrected.split('One physical spring-and-piston')[0]
plate=corrected[corrected.index(' The orange light remains'):]
beats={
 'hit':'One RECEIVING external impact and recovery. Ready0..20;20..45 original six legs flex to absorb a small backward chassis tilt. Operator chest/helmet jerk back, both real knees bend; one gloved hand flinches up beside helmet while the other retains original control-bar grip.45..90 restore released hand to SAME bar and straighten knees/loaded leg joints;90..123 hold original ready. Cylinder retains original length throughout. Clear recoil without terminal collapse. ',
 'defend':'One deliberate grounded defensive brace and held finish. Ready0..20;20..45 original six legs spread/flex lower, keeping all chains attached and original cylinder unchanged;45..75 operator crouches behind rear ivory plating and bends both knees, BOTH hands gripping original control bar.75..123 hold supplied deep guard with stable grounded support. Same two gauges, barrel length/diameter, chimney and original plating. ',
 'cast':'One physical pressure-control support adjustment. Ready0..20;20..50 operator LEFT hand retains lower control bar while RIGHT gloved hand leaves lower grip and reaches original TOP RED valve.50..80 turns that SAME valve once with shoulder/elbow/wrist articulation and checks original white gauge;80..100 restores the SAME right hand to its original lower bar grip;100..123 holds original ready. Strong deliberate maintenance/rally gesture with exactly TWO hands/arms. Original machinery makes a small controlled breech adjustment and returns, six leg supports stay planted. ',
 'death':'One continuous terminal collapse of machine AND its single operator. Ready0..15;15..40 original six attached leg joints buckle under boiler weight, lowering chassis/cylinder toward same ground;40..82 all attached leg chains fold/splay into the supplied wreck. The ONE operator releases both hands, bends both knees, loses balance and falls beside rear plating at viewer-right, exactly two arms and two legs.82..105 machine and prone operator settle into the supplied grounded final wreck;105..123 remain fully still, cold and grounded. Original cylinder, gauges, hoses, chimney, plating and all six leg chains stay attached/present. Aperture, furnace and goggles cool completely DARK during terminal settling. '
}
for clip,beat in beats.items():
 out=S/f'{clip}_h3_v1';assert not (out/'sampling_submission.json').exists()
 c=json.loads((out/'config.json').read_bytes());c['prompt']=identity+beat+(plate if clip!='death' else ' Flat uninterrupted magenta RGB255,0,255 outside original silhouette. Original hardware retained through complete grounded collapse. Fixed camera, same original scale; entire wreck AND prone operator inside canvas. No new limbs, crew, effects, scenery, text, shadows, cuts, zoom or recovery. ')
 c['prompt']=c['prompt'].strip()
 (out/'config.json').write_text(json.dumps(c,indent=2)+'\n',encoding='utf-8');p.prepare(out,c)
 print('PREPARED_LITERAL_ACTION',clip,flush=True)
