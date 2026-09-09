"""Source-backed decorative recovery, original geometry and replacement checks."""
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock

from PIL import Image, ImageFilter

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('decoration_recovery',ROOT/'tools/prepare_overworld_decoration_cutouts.py')
decor=importlib.util.module_from_spec(spec)
spec.loader.exec_module(decor)


class DecorationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe,cls.manifest,cls.sheets=decor.load_inputs()
        cls.proof=json.loads((decor.PACKET/'manifest.json').read_text())
        cls.expected={k:decor.recover(cls.sheets[v['source']],v) for k,v in cls.recipe['assets'].items()}

    def test_complete_original_membership_with_15_unchanged_controls(self):
        self.assertEqual(len(self.recipe['assets']),185)
        self.assertEqual(len(self.recipe['sources']),13)
        self.assertEqual(len(self.recipe['preserved_controls']),15)
        self.assertEqual(set(self.proof['assets']),set(self.recipe['assets']))
        self.assertEqual(self.proof['preserved_controls'],self.recipe['preserved_controls'])
        self.assertEqual(sum(v.get('mode')=='generated_replacement' for v in self.recipe['assets'].values()),1)
        self.assertEqual(sum(v.get('mode')=='retain_canvas_remove_neighbor' for v in self.recipe['assets'].values()),1)

    def test_exact_recipe_original_and_generated_provenance(self):
        for field,path in [('recipe_sha256',decor.RECIPE),('processing_tool_sha256',Path(decor.__file__)),('material_engine_sha256',decor.MATERIAL_ENGINE),('matte_engine_sha256',decor.material.ENGINE)]:
            self.assertEqual(self.proof[field],decor.base.digest(path))
        for key,row in self.recipe['assets'].items():
            self.assertEqual(decor.base.digest(decor.PACKET/(key+'_before.png')),row['before_sha256'])
        self.assertEqual(self.proof['sources'],self.recipe['sources'])
        generated=self.proof['generated_replacements']['decor_ash_heatglass_haze_sheet']
        self.assertEqual(decor.base.digest(decor.base.local(generated['path'])),generated['sha256'])
        self.assertEqual(decor.base.digest(decor.base.local(generated['generation_manifest'])),generated['generation_manifest_sha256'])

    def test_every_runtime_and_trim_reproduce_exactly(self):
        for key,expected in self.expected.items():
            with self.subTest(asset=key):
                entry=self.manifest['object_assets'][key]
                runtime=decor.base.local(entry['path']);trim=decor.base.local(entry['source_trimmed'])
                with Image.open(runtime) as actual:
                    self.assertEqual(actual.mode,'RGBA')
                    self.assertEqual(actual.size,(512,512))
                    self.assertEqual(actual.tobytes(),expected.tobytes())
                with Image.open(trim) as actual:self.assertEqual(actual.tobytes(),decor.trimmed(expected,self.recipe['assets'][key]).tobytes())
                self.assertEqual(entry['runtime_sha256'],decor.base.digest(runtime))
                self.assertEqual(self.proof['assets'][key]['runtime_sha256'],decor.base.digest(runtime))
                self.assertEqual(self.proof['assets'][key]['trim_sha256'],decor.base.digest(trim))

    def test_mapping_and_all_nonprovenance_metadata_unchanged(self):
        mappings=json.loads((ROOT/'art/overworld/decorative_object_sprites.json').read_text())['object_sprite_mappings']
        for key,row in self.recipe['assets'].items():
            entry=self.manifest['object_assets'][key]
            self.assertEqual({k:v for k,v in entry.items() if k not in ('runtime_sha256','source_processing_manifest')},decor.expected_manifest_entry(row))
            self.assertEqual(mappings[entry['assigned_decorative_object_id']]['asset_id'],key)

    def test_original_bilinear_scale_alignment_is_independent_pixel_evidence(self):
        for key,row in self.recipe['assets'].items():
            if row['source']=='base':continue
            with self.subTest(asset=key):
                before=decor.before_image(row)
                cell=self.sheets[row['source']].crop(tuple(row['original_cell']))
                w,h=cell.size
                self.assertEqual(row['original_resize'],[int(w*512/max(w,h)),int(h*512/max(w,h))])
                reference=Image.new('RGB',(512,512));reference.paste(cell.resize(tuple(row['original_resize']),Image.Resampling.BILINEAR),tuple(row['original_origin']))
                interior=before.getchannel('A').point(lambda a:255 if a==255 else 0).filter(ImageFilter.MinFilter(9))
                samples=[]
                for i,p in enumerate(before.getdata()):
                    if i%13 or not interior.getpixel((i%512,i//512)) or min(p[0],p[2])>=p[1]-5:continue
                    q=reference.getpixel((i%512,i//512));samples.append(sum(abs(p[c]-q[c]) for c in range(3))/3)
                self.assertGreater(len(samples),0)
                self.assertLess(sum(samples)/len(samples),2.5)

    def test_six_clipped_paintings_use_only_recorded_integer_translation(self):
        shifts={k:v['canvas_shift'] for k,v in self.recipe['assets'].items() if v['canvas_shift']!=[0,0]}
        self.assertEqual(shifts,{
            'decor_frost_icefall_anchor':[0,-23],
            'decor_frost_snowblind_drift_shadow':[0,-3],
            'decor_frost_highland_rime_cliff_band':[0,-55],
            'decor_grass_mire_cutwater_reed_shelf':[0,-40],
            'decor_coast_underway_sinkhole_quay':[0,-50],
            'decor_forest_mire_root_reed_mat':[0,-43],
        })
        for key in shifts:
            row=self.recipe['assets'][key]
            extended=decor.extended_canvas(self.sheets[row['source']],row)
            self.assertFalse(decor.clipped(extended,row))
            self.assertTrue(decor.clipped(extended,dict(row,canvas_shift=[0,0])))

    def test_no_sheet_dividers_and_neutral_opaque_detail_preserved(self):
        sampled=0
        for key,row in self.recipe['assets'].items():
            if row.get('mode'):continue
            with self.subTest(asset=key):
                source=self.sheets[row['source']].crop(tuple(row['source_rect']))
                recovered=decor.source_cell(self.sheets[row['source']],row)
                bounds=recovered.getbbox()
                self.assertGreater(bounds[0],0);self.assertGreater(bounds[1],0)
                self.assertLess(bounds[2],source.width);self.assertLess(bounds[3],source.height)
                for i,(r,g,b) in enumerate(source.getdata()):
                    if i%29 or min(r,b)-g>8:continue
                    self.assertEqual(recovered.getpixel((i%source.width,i//source.width)),(r,g,b,255))
                    sampled+=1
        self.assertGreater(sampled,10000)

    def test_every_original_colored_material_interior_is_preserved(self):
        sampled=0
        for key,row in self.recipe['assets'].items():
            if row.get('mode') or not row['chromatic_source_rects']:continue
            source=self.sheets[row['source']].crop(tuple(row['source_rect']))
            recovered=decor.source_cell(self.sheets[row['source']],row)
            mask=Image.new('L',source.size)
            mask.putdata([0 if g<=24 and min(r,b)>80 and min(r,b)-g>64 else 255 for r,g,b in source.getdata()])
            interior=mask.filter(ImageFilter.MinFilter(5))
            l,t,_,_=row['source_rect']
            for i,p in enumerate(source.getdata()):
                x,y=i%source.width,i//source.width
                if i%11 or not interior.getpixel((x,y)) or not any(a<=x+l<c and b<=y+t<d for a,b,c,d in row['chromatic_source_rects']):continue
                self.assertEqual(recovered.getpixel((x,y)),(*p,255),(key,x,y))
                sampled+=1
        self.assertGreater(sampled,1000)

    def test_brasspipe_removes_only_detached_neighbor_and_keeps_trim_placement(self):
        key='decor_underway_brasspipe_cavern_wall';row=self.recipe['assets'][key]
        before=decor.before_image(row);after=self.expected[key]
        self.assertIsNotNone(before.crop((0,0,512,70)).getbbox())
        self.assertIsNone(after.crop((0,0,512,70)).getbbox())
        self.assertEqual(before.crop((0,70,512,512)).tobytes(),after.crop((0,70,512,512)).tobytes())
        self.assertEqual(row['trim_size'],[460,483])
        canvas=Image.new('RGBA',(512,512));canvas.paste(decor.trimmed(after,row),tuple(row['trim_canvas_origin']))
        self.assertEqual(canvas.tobytes(),after.tobytes())

    def test_generated_heatglass_is_original_colored_alpha_not_checkerboard(self):
        key='decor_ash_heatglass_haze_sheet';row=self.recipe['assets'][key]
        asset=self.expected[key];entry=self.manifest['object_assets'][key]
        self.assertNotIn('source_generated_atlas',entry)
        self.assertEqual(entry['source_generated'],row['generated_replacement']['path'])
        l,t,r,b=asset.getbbox();left,top,right,bottom=row['generated_replacement']['fit_rect']
        self.assertTrue(left<=l<r<=right and top<=t<b<=bottom)
        self.assertEqual(asset.getchannel('A').getextrema(),(0,255))
        self.assertGreater(sum(a==255 for _,_,_,a in asset.getdata()),40000)
        self.assertGreater(sum(a>128 and b>r and b>g for r,g,b,a in asset.getdata()),1000)
        self.assertGreater(sum(a>128 and r>g>b for r,g,b,a in asset.getdata()),1000)

    def test_corrupt_sources_swapped_ids_and_clean_control_edits_fail_closed(self):
        with mock.patch.object(decor.base,'digest',return_value='corrupt'):
            with self.assertRaisesRegex(ValueError,'sheet hash changed'):decor.load_inputs()
        bad=json.loads(json.dumps(self.manifest))
        bad['object_assets']['decor_orchard_root_wall']['assigned_decorative_object_id']='object_reef_line'
        with mock.patch.object(decor,'ART_MANIFEST',mock.Mock(read_text=lambda:json.dumps(bad))):
            with self.assertRaisesRegex(ValueError,'Identity/placement'):decor.load_inputs()
        bad=json.loads(json.dumps(self.manifest));bad['object_assets']['decor_grass_root_millstone']['path']='res://wrong.png'
        with mock.patch.object(decor,'ART_MANIFEST',mock.Mock(read_text=lambda:json.dumps(bad))):
            with self.assertRaisesRegex(ValueError,'Previously clean archetype changed'):decor.load_inputs()

    def test_every_before_image_fails_new_visible_art_acceptance(self):
        for key,after in self.expected.items():
            before=decor.before_image(self.recipe['assets'][key])
            old=Image.new('RGB',(512,512),'#334c3a');new=old.copy()
            old.paste(before,(0,0),before);new.paste(after,(0,0),after)
            self.assertNotEqual(old.tobytes(),new.tobytes(),key)

    def test_recovery_rejects_art_overwrites_partial_installs_and_clipping(self):
        for path in (ROOT,ROOT/'art',decor.PACKET):
            with self.assertRaisesRegex(ValueError,'outside registered art'):decor.prepare(path)
        with self.assertRaisesRegex(ValueError,'whole reviewed cohorts'):decor.prepare(ROOT,True,['decor_reef_line'])
        row=dict(self.recipe['assets']['decor_frost_icefall_anchor'],canvas_shift=[0,0])
        with self.assertRaisesRegex(ValueError,'Refusing clipped painting'):decor.recover(self.sheets[row['source']],row)

    def test_regression_rejects_the_initially_shaved_original_edge_pixels(self):
        for key,rect in [('decor_quarry_chalk_rub',[947,5,1249,306]),('decor_soot_banner_tatters',[5,320,306,619])]:
            row=dict(self.recipe['assets'][key],source_rect=rect)
            with self.subTest(asset=key),self.assertRaisesRegex(ValueError,'Source rectangle clips paint'):
                decor.recover(self.sheets[row['source']],row)


if __name__=='__main__':unittest.main()
