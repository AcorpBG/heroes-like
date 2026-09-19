"""Focused original vegetation selection, shared layering, masks and fog render."""
import native_scenery_formation_regression as formation

script = formation.script.replace('["grass","rough","forest"]','["grass","mire","underground"]')
script = script.replace('134 if row==1 else 135','[[135,135,135,135],[125,135,125,119],[129,129,129,129]][row][column]')
script = script.replace('starts := [1,4,8,13]','starts := [1,4,6,9]')
script = script.replace('Vector2i(15,12)','Vector2i(11,12)').replace('has("13,1")','has("9,1")')
extra = '''
    var manifest: Dictionary = ContentService.load_json("res://art/overworld/native_scenery.json")
    var rules = preload("res://scripts/persistence/NativeSceneryRules.gd")
    var types := {"woods":135,"conifers":137,"wetland":125,"deadwood":119,"fungi":129,"scrub":116}
    var reached := {}
    for family in manifest.vegetation_palettes:
        for biome in manifest.vegetation_palettes[family]:
            var source := {"native_scenery_art_version":2,"h3m_type_id":types[family]}
            for id in rules.vegetation_candidates(source,biome,""): reached[id]=true
    for family in manifest.terrain_vegetation_palettes.sand:
        var source := {"native_scenery_art_version":2,"h3m_type_id":types[family]}
        for id in rules.vegetation_candidates(source,"biome_coast_archipelago","sand"): reached[id]=true
    check(reached.size()==75,"new vegetation masses are not all reachable")
    var tree := {"native_scenery_art_version":2,"h3m_type_id":135}
    var sand := rules.vegetation_candidates(tree,"biome_coast_archipelago","sand")
    for id in sand: check(id not in rules.vegetation_candidates(tree,"biome_rough_badlands","dirt"),"sand and dirt share vegetation mass palette")
    var fixed := {"native_scenery_art_version":2,"h3m_type_id":130}
    check(rules.vegetation_candidates(fixed,"biome_rough_badlands","dirt")==rules.vegetation_candidates(fixed,"biome_deep_forest","forest"),"fixed deadwood habitat ignored")
    var overlaps := 0
    var overhangs := 0
    for key in _native_scenery_layers_by_tile:
        var layers: Array = _native_scenery_layers_by_tile[key]
        if layers.size()>1: overlaps+=1
        if not _generated_decorative_bodies_by_tile.has(key): overhangs+=1
        for i in range(layers.size()):
            if layers[i].mass_size.x*layers[i].mass_size.y>1:
                check(String(layers[i].asset_id).begins_with("native_vegetation_"),"small cluster used as vegetation mass")
            if i>0:
                check(layers[i-1].mass_origin.y+layers[i-1].mass_size.y<=layers[i].mass_origin.y+layers[i].mass_size.y,"vegetation depth order reversed")
    check(overlaps>0,"neighboring vegetation formations do not overlap")
    check(overhangs>0,"canopies confined to collision rectangles")
    var snapshot := _native_scenery_layers_by_tile.duplicate(true)
    _index_native_scenery_layers()
    check(snapshot==_native_scenery_layers_by_tile,"vegetation overlap changes on reindex")
'''
extra=formation.re.sub(r'(?m)^( +)',lambda m:'\t'*(len(m[1])//4),extra)
script=script.replace('\tvar expected := {}',extra+'\n\tvar expected := {}')
script=script.replace('/formations.png','/vegetation-overlap.png').replace('SCENERY_FORMATIONS','SCENERY_VEGETATION_OVERLAP')
if __name__=='__main__':
    raise SystemExit(formation.harness.main(script=script,node_type='Node2D'))
