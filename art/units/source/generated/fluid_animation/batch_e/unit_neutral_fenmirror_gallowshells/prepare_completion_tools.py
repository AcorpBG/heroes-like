"""Adapt selected publication/import tools without running or accepting them."""
from pathlib import Path
import prepare as p

def main():
    source=p.ROOT/'art/units/source/generated/fluid_animation/batch_e/unit_neutral_cindervane_censerwings'
    substitutions={'unit_neutral_cindervane_censerwings':p.S.name,'cindervane_censerwing':'fenmirror_gallowshell','Cindervane Censerwing':'Fenmirror Gallowshell','Censerwing':'Gallowshell','CINDERVANE_CENSERWING':'FENMIRROR_GALLOWSHELL','cindervane':'fenmirror'}
    for name in ['publish_selected.py','run_live_review.py','verify_imported_atlas.gd','commit_selected.py','cleanup_selected.py']:
        text=(source/name).read_text(encoding='utf-8')
        for a,b in substitutions.items():text=text.replace(a,b)
        if name=='publish_selected.py':text=text.replace("['move','attack','ranged','hit','defend','cast','death']","['move','attack','hit','defend','cast','death']")
        if name=='run_live_review.py':
            start=text.index("        subprocess.run([sys.executable, str(p.SOURCE_DIR/'run_ranged_native.py')")
            text=text[:start]
        if name=='commit_selected.py':
            text=text.replace('across seven dedicated actions','across six dedicated actions').replace('actual beak-strike and ranged captures','actual pincer-strike captures')
            text=text.replace("r'COORDINATOR ACTIVE: Fenmirror Gallowshells[;,][^|]* \\| '","r'COORDINATOR ACTIVE: Fenmirror Gallowshells[;,].*?(?=WORKER ACTIVE:|\\| |$)'")
        target=p.S/name
        if target.exists():assert target.read_text(encoding='utf-8')==text
        else:target.write_text(text,encoding='utf-8')
    print('SELECTED SIX-ACTION PUBLICATION AND TWO-TEXTURE IMPORT TOOLS PREPARED; NOT EXECUTED')

if __name__=='__main__':main()
