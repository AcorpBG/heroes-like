"""Update only the existing selected coordinator note under catalog lock."""
import json,re
import produce as p
from creature_animation_lock import exclusive
from prepare_lossless_texture_imports import atomic_write

if __name__=='__main__':
    with exclusive('content'):
        path=p.ROOT/'ops/progress.json';text=path.read_text(encoding='utf-8')
        match=re.search(r'"id"\s*:\s*"art-fluid-creature-animation-20260923"[\s\S]*?"notes"\s*:\s*("(?:\\.|[^"\\])*")',text);assert match
        notes=json.loads(match[1])
        pattern=r'COORDINATOR ACTIVE: Fenmirror Gallowshells[;,].*?(?=WORKER ACTIVE:|\| |$)'
        new='COORDINATOR ACTIVE: Fenmirror Gallowshells; six original H3 actions integrated: movement40, pincer attack28, hit24, guard30, physical support40, grounded collapse42 (204 new poses). All124 RGB/alpha/native both-facing chronologies personally reviewed for each; 212 selected native poses and eight actual RIGHT-facing Strike captures reviewed. Unchanged repeat normal702 and reflected702 focused checks pass after initial missed contact observation; exact source pixels/anchors, other231 rows, accepted eight-pose idle270ms and map pixels preserved. Atlas4096x2864/46,923,776 RGBA bytes. Final isolated two-texture import/live review queued; no completed-unit claim yet. '
        notes,changed=re.subn(pattern,new,notes);assert changed==1
        start,end=match.span(1);atomic_write(path,(text[:start]+json.dumps(notes,ensure_ascii=False)+text[end:]).encode('utf-8'))
    print('ONLY SELECTED EXISTING COORDINATOR NOTE UPDATED; BROAD SLICE REMAINS IN_PROGRESS')
