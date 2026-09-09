"""Original state paintings with actual earned native state-selected coverage.

All state resolver inputs are detached assertions, never world mutation. Actual
captures retain the saved identity, ownership, position, fog and complete state.
"""
from overworld_recurring_site_cutout_probe import SCRIPT as SITE_SCRIPT

SCRIPT=SITE_SCRIPT.replace('specs.size()==30,"all thirty original site paintings"',
                          'specs.size()==34,"all thirty-four original state paintings"')
# Avoid overwriting a named screenshot with another copy of the same asset.
# Still retain every affected original placement in the report and full saves.
SCRIPT=SCRIPT.replace('    var affected_native := []','    var affected_native := []\n    var captured_states := {}')
SCRIPT=SCRIPT.replace('        if OverworldRules.is_tile_visible(session,tile.x,tile.y,int(node.get("level",0))):\n            await capture(view,tile,key,node,"actual state-selected original native resource site")',
'''        var rendered_node: Dictionary=view._resource_node_at(tile)
        if rendered_node.is_empty():
            check(bool(node.get("collected",false)),"only consumed original resource records are absent from renderer")
            continue
        check(rendered_node.get("placement_id","")==node.get("placement_id","") and view._resource_asset_id(rendered_node)==key,"original rendered resource placement and state authority")
        if not captured_states.has(key) and OverworldRules.is_tile_visible(session,tile.x,tile.y,int(node.get("level",0))):
            await capture(view,tile,key,node,"actual state-selected original native resource site")
            captured_states[key]=true''')
SCRIPT=SCRIPT.replace('    var galleries: Array=await gallery(view,specs)',
'''    check(affected_native.size()>0 and captured_states.size()>0,"actual earned affected native states, not only detached coverage")
    var galleries: Array=await gallery(view,specs)''')
