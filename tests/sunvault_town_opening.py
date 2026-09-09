#!/usr/bin/env python3
"""Retain a normal generated Large Sunvault opening through the shared driver.

The driver's private result marker is retained; its body is configured for the
actual faction, hero, town and supported Large request. No native rules change.
"""
import mireclaw_town_opening as shared


def script_text():
    script = shared.SCRIPT
    for old, new in (('"homm3_medium"', '"homm3_large"'),
                     ('"faction_mireclaw"', '"faction_sunvault"'),
                     ('"hero_vaska"', '"hero_solera"'),
                     ('"town_duskfen"', '"town_prismhearth"'),
                     ('did not produce Duskfen', 'did not produce Prismhearth')):
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
