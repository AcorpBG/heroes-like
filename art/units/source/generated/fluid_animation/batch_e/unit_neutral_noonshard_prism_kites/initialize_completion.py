"""Scope publication and retention tools to the reviewed Prism Kite delivery."""
import produce as p
OLD=p.SOURCE_DIR.parent/'unit_neutral_quenchbell_ironbacks'
if __name__=='__main__':
    for name in ['commit_selected.py','cleanup_selected.py']:
        target=p.SOURCE_DIR/name;assert not target.exists(),target
        text=(OLD/name).read_text(encoding='utf-8').replace('unit_neutral_quenchbell_ironbacks','unit_neutral_noonshard_prism_kites').replace('quenchbell_ironback','noonshard_prism_kite').replace('Quenchbell Ironbacks','Noonshard Prism Kites').replace('Quenchbell Ironback','Noonshard Prism Kite').replace('ironback_','noonshard_')
        if name=='commit_selected.py':
            text=text.replace('import json,subprocess,hashlib,re','import json,subprocess,hashlib,re,os')
            text=text.replace('cwd=p.ROOT,input=input','cwd=p.ROOT,env=dict(os.environ,GIT_OPTIONAL_LOCKS="0"),input=input')
            text=text.replace("'SOLO COMPLETE: Noonshard Prism Kites; 203 original H3 poses across six dedicated actions; '","f\"SOLO COMPLETE: Noonshard Prism Kites; {completion['new_selected_poses']} original H3 poses across seven dedicated actions; \"")
            text=text.replace('actual ram captures','actual head-jab and ranged captures')
        target.write_text(text,encoding='utf-8')
    print('SCOPED_COMPLETION_RETENTION_AND_GIT_READY',flush=True)
