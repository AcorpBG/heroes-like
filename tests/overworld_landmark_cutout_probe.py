"""Forty exact landmark/state identities; earned native gameplay stays intact."""
from overworld_state_cutout_probe import SCRIPT as STATE_SCRIPT

assert 'specs.size()==34,"all thirty-four original state paintings"' in STATE_SCRIPT
SCRIPT=STATE_SCRIPT.replace('specs.size()==34,"all thirty-four original state paintings"',
                           'specs.size()==40,"all forty original landmark and state paintings"')
needle='        check(unclaimed==expected_unclaimed,key+" current unclaimed state retained")'
assert needle in SCRIPT
SCRIPT=SCRIPT.replace(needle,'''        if site in ["site_granary_lock_exchange","site_blackwater_shrine_marker","site_prism_yard_standard"]:
            check(ContentService.get_resource_site(site).get("family","")=="faction_landmark","original landmark family precedence retained")
            expected_unclaimed=key
        check(unclaimed==expected_unclaimed,key+" current unclaimed state retained")''')
