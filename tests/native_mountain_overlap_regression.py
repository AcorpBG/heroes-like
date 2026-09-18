"""Focused multi-tile mountain selection, overlap ordering and fog rendering."""
import native_rock_cohesion_regression as rocks

script = rocks.script
extra = '''
    var manifest: Dictionary = ContentService.load_json("res://art/overworld/native_scenery.json")
    var rules = preload("res://scripts/persistence/NativeSceneryRules.gd")
    var mountain_source := {"native_scenery_art_version":2,"h3m_type_id":134}
    var reached := {}
    for biome in manifest.mountain_palettes:
        var pool: Array = rules.mountain_candidates(mountain_source,biome,"")
        check(pool.size()==5,"mountain biome lost its five original silhouettes")
        for id in pool: reached[id]=true
    for id in rules.mountain_candidates(mountain_source,"biome_coast_archipelago","sand"): reached[id]=true
    check(reached.size()==50,"not all original mountain masses reachable")
    var overlaps := 0
    var overhangs := 0
    for key in _native_mountains_by_tile:
        var layers: Array = _native_mountains_by_tile[key]
        if layers.size()>1: overlaps+=1
        if not _generated_decorative_bodies_by_tile.has(key): overhangs+=1
        for i in range(layers.size()):
            check(String(layers[i].asset_id).begins_with("native_mountain_"),"boulder cluster used as mountain")
            if i>0:
                check(layers[i-1].mass_origin.y+layers[i-1].mass_size.y <= layers[i].mass_origin.y+layers[i].mass_size.y,"mountain depth order reversed")
    check(overlaps>0,"renderer has no overlapping mountain layers")
    check(overhangs>0,"peaks remain confined to collision rectangles")
    var snapshot := _native_mountains_by_tile.duplicate(true)
    _index_native_mountain_layers()
    check(snapshot==_native_mountains_by_tile,"reindex changed mountain overlap geometry")
'''
extra = rocks.formation.re.sub(r'(?m)^( +)',lambda m:'\t'*(len(m[1])//4),extra)
script = script.replace('\tvar expected := {}',extra+'\n\tvar expected := {}')
script = script.replace('/rock-cohesion.png','/mountain-overlap.png').replace('SCENERY_ROCK_COHESION','SCENERY_MOUNTAIN_OVERLAP')
if __name__=='__main__':
    raise SystemExit(rocks.formation.harness.main(script=script,node_type='Node2D'))
