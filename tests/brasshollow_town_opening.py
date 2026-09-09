#!/usr/bin/env python3
"""Retain a normal generated Large Brasshollow opening through the shared driver."""
import mireclaw_town_opening as shared


def script_text():
    script = shared.SCRIPT
    for old, new in (('"homm3_medium"', '"homm3_large"'),
                     ('"faction_mireclaw"', '"faction_brasshollow"'),
                     ('"hero_vaska"', '"hero_brasshollow_marka_ironclause"'),
                     ('"town_duskfen"', '"town_brasshollow_orevein_gantry"'),
                     ('did not produce Duskfen', 'did not produce Orevein Gantry')):
        assert old in script, 'shared opening contract changed: ' + old
        script = script.replace(old, new)
    anchor='\t\tif session.day!=1'
    assert anchor in script
    return script.replace(anchor, '\t\treport["actual_identity"]={"hero_id":session.hero_id,"day":session.day,"scenario_status":session.scenario_status}\n'+anchor)


def main():
    shared.SCRIPT = script_text()
    return shared.main()


if __name__ == '__main__':
    raise SystemExit(main())
