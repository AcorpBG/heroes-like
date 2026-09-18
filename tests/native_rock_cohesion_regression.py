"""Dense sand/dirt rock contact and terrain-palette regression."""
import native_scenery_formation_regression as formation

script = formation.script.replace('["grass","rough","forest"]', '["sand","dirt","mire"]')
script = script.replace('134 if row==1 else 135', '134')
script = script.replace('starts := [1,4,8,13]', 'starts := [1,4,6,9]')
script = script.replace('Vector2i(15,12)', 'Vector2i(11,12)').replace('has("13,1")', 'has("9,1")')
extra = '''
    var source := {"native_scenery_art_version":2,"h3m_type_id":134}
    var sand := _native_scenery_assets(source,Vector2i(1,1))
    var dirt := _native_scenery_assets(source,Vector2i(1,6))
    check(sand.size()>=25 and dirt.size()>=25,"terrain palette lost variety")
    for id in sand: check(id not in dirt,"sand and dirt share rock art")
    var cross_record_joins := 0
    for cell in _generated_decorative_bodies_by_tile.values():
        for contact in cell.get("generated_body_rock_contacts",[]):
            for tile in contact.tiles:
                check(_generated_decorative_bodies_by_tile.has(_tile_key(tile)),"contact invented blocked cell")
            var a: Vector2i=contact.tiles[0]
            var b: Vector2i=contact.tiles[-1]
            check(_terrain_at(a)==_terrain_at(b),"rock bed crossed a terrain boundary")
            check(abs(a.x-b.x)+abs(a.y-b.y)<=1,"rock bed jumped a passage")
            var bounds := Rect2(Vector2(a),Vector2(b-a+Vector2i.ONE))
            check(bounds.encloses(contact.rect),"rock bed extends onto passable ground")
            if _generated_decorative_bodies_by_tile[_tile_key(a)].placement_id!=_generated_decorative_bodies_by_tile[_tile_key(b)].placement_id:
                cross_record_joins+=1
    check(cross_record_joins>0,"neighboring source blockers remain separate")
'''
extra = formation.re.sub(r'(?m)^( +)',lambda m:'\t'*(len(m[1])//4),extra)
script = script.replace('\tvar expected := {}',extra+'\n\tvar expected := {}')
script = script.replace('/formations.png','/rock-cohesion.png').replace('SCENERY_FORMATIONS','SCENERY_ROCK_COHESION')
if __name__=='__main__':
    raise SystemExit(formation.harness.main(script=script,node_type='Node2D'))
