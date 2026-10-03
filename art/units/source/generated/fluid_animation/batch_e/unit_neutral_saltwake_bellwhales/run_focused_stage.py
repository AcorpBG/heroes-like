"""Run a bounded pair of selected-unit checks under one outer GPU lease."""
import argparse,json,subprocess,sys,datetime
import produce as p

UID='unit_neutral_saltwake_bellwhales'
a=argparse.ArgumentParser();a.add_argument('stage',choices=['candidate_pair','candidate_ranged','import','live_pair','map_static']);args=a.parse_args()
target=p.ROOT/'.artifacts/parallel_animation_20261002'/UID
godot='D:/Games/godot/Godot_v4.6.2-stable_win64_console.exe'
queue=p.request(p.URL,'/queue')
assert not queue['queue_running'] and not queue['queue_pending'],'A Comfy job still owns GPU work; do not render concurrently'
cases={'candidate_pair':[('run_native_review.py','candidate/native',False),('run_mirrored_native.py','candidate/mirror',False)],'candidate_ranged':[('run_ranged_native.py','candidate/ranged',False)],'live_pair':[('run_native_review.py','live/native',True),('run_ranged_native.py','live/ranged',True)],'map_static':[('run_map_static_review.py','live/map_static',True)]}
if args.stage=='import':
 commands=[[sys.executable,str(p.SOURCE_DIR/'run_import_check.py')]]
else:
 commands=[]
 for tool,out,live in cases[args.stage]:
  command=[sys.executable,str(p.SOURCE_DIR/tool),'--godot',godot,'--unit',UID,'--output',str(target/out),'--render','--overview-only']
  command+=['--live'] if live else ['--handoff',str(p.SOURCE_DIR/'handoff.json')]
  commands.append(command)
for command in commands:
 print('FOCUSED_STAGE_START',args.stage,command[1],flush=True)
 result=subprocess.run(command,cwd=p.ROOT,creationflags=subprocess.CREATE_NO_WINDOW)
 if result.returncode:raise SystemExit(result.returncode)
record=dict(stage=args.stage,terminal_exit_code=0,completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),commands=commands)
p.write(target/(args.stage+'_terminal.json'),record)
print('FOCUSED_STAGE_TERMINAL',args.stage,flush=True)
