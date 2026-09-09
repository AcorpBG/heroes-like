"""Source-backed mixed-family cutouts, unchanged geometry and atlas neighbors."""
import collections
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock

from PIL import Image, ImageFilter

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('legacy_recovery',ROOT/'tools/prepare_overworld_legacy_cutouts.py')
legacy=importlib.util.module_from_spec(spec);spec.loader.exec_module(legacy)


def largest_component(image):
    """Independent 8-connected original-paint mask; not a repair algorithm."""
    w,h=image.size;remaining={i for i,p in enumerate(image.getdata()) if p[3]}
    largest=[]
    while remaining:
        queue=[remaining.pop()];points=[]
        while queue:
            i=queue.pop();points.append(i)
            for dy in (-1,0,1):
                for dx in (-1,0,1):
                    x,y=i%w+dx,i//w+dy;j=y*w+x
                    if 0<=x<w and 0<=y<h and j in remaining:remaining.remove(j);queue.append(j)
        if len(points)>len(largest):largest=points
    return largest


class LegacyCutoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe,cls.manifest,cls.sources=legacy.inputs()
        cls.proof=json.loads((legacy.PACKET/'manifest.json').read_text())
        cls.recovered={k:legacy.recover(row,cls.sources) for k,row in cls.recipe['assets'].items()}

    def test_exact_35_row_20_file_cohort_and_18_clean_controls(self):
        self.assertEqual(collections.Counter(r['mode'] for r in self.recipe['assets'].values()),dict(original_hero=6,generated_tree=16,generated_state=1,generated_prop=2,remove_neighbor=10))
        self.assertEqual(len(self.proof['files']),20)
        self.assertEqual(len(self.recipe['preserved_controls']),18)
        self.assertEqual(set(self.proof['assets']),set(self.recipe['assets']))
        self.assertEqual(self.proof['preserved_controls'],self.recipe['preserved_controls'])

    def test_source_generation_and_processing_provenance(self):
        for field,path in [('recipe_sha256',legacy.RECIPE),('processing_tool_sha256',Path(legacy.__file__)),('material_engine_sha256',legacy.ENGINE),('matte_engine_sha256',legacy.material.ENGINE)]:
            self.assertEqual(self.proof[field],legacy.base.digest(path))
        self.assertEqual(self.proof['sources'],self.recipe['sources'])
        generation=json.loads(legacy.base.local(self.recipe['generation_manifest']).read_text())
        self.assertEqual({r['key'] for r in generation['jobs']},{'trees','crownmere','sawmill','quarry'})
        self.assertEqual(self.proof['generation_sha256'],legacy.base.digest(legacy.base.local(self.recipe['generation_manifest'])))
        for row in self.recipe['assets'].values():
            self.assertEqual(legacy.base.digest(legacy.before_path(row['original_manifest_entry'])),row['before_sha256'])

    def test_runtime_trim_and_atlas_pixels_match_exact_source_reconstruction(self):
        for key,(expected,geometry) in self.recovered.items():
            with self.subTest(asset=key):
                entry=self.manifest['object_assets'][key]
                with Image.open(legacy.base.local(entry['path'])) as image:
                    actual=legacy.region(image,entry)
                    self.assertEqual(actual.mode,'RGBA')
                    self.assertEqual(actual.size,tuple(self.recipe['assets'][key]['canvas_size']))
                    self.assertEqual(actual.tobytes(),expected.tobytes())
                with Image.open(legacy.base.local(entry['source_trimmed'])) as image:self.assertEqual(image.tobytes(),expected.tobytes())
                self.assertEqual(self.proof['assets'][key]['geometry'],geometry)
                self.assertEqual(entry['runtime_sha256'],legacy.base.digest(legacy.base.local(entry['path'])))
                self.assertEqual(self.proof['assets'][key]['trim_sha256'],legacy.base.digest(legacy.base.local(entry['source_trimmed'])))

    def test_exact_identity_canvas_anchor_footprint_region_metadata_unchanged(self):
        provenance={'source_trimmed','source_generated','source_model','source_manifest','source_processing_manifest','runtime_sha256'}
        for key,row in self.recipe['assets'].items():
            entry=self.manifest['object_assets'][key]
            self.assertEqual({k:v for k,v in entry.items() if k not in provenance},{k:v for k,v in row['original_manifest_entry'].items() if k not in provenance})
            self.assertEqual({k:v for k,v in entry.items() if k not in ('source_processing_manifest','runtime_sha256')},legacy.expected_entry(row,self.recipe))

    def test_clean_controls_and_original_processed_sources_untouched(self):
        for key,row in self.recipe['preserved_controls'].items():
            entry=self.manifest['object_assets'][key]
            self.assertEqual(entry,row['original_manifest_entry'])
            before=legacy.region(legacy.original_image(entry),entry)
            with Image.open(legacy.base.local(entry['path'])) as actual:self.assertEqual(legacy.region(actual,entry).tobytes(),before.tobytes())
        for row in self.recipe['assets'].values():
            if 'before_trim_sha256' in row:self.assertEqual(legacy.base.digest(legacy.base.local(row['original_manifest_entry']['source_trimmed'])),row['before_trim_sha256'])

    def test_original_hero_painting_registration_is_independent_rgb_evidence(self):
        for key,row in self.recipe['assets'].items():
            if row['mode']!='original_hero':continue
            original=legacy.original_image(row['original_manifest_entry'])
            x,y=row['original_cell_origin'];cell=self.sources['heroes'].crop((x,y,x+512,y+512))
            samples=[(p,q) for i,(p,q) in enumerate(zip(original.getdata(),cell.getdata())) if i%17==0 and p[3]>128 and p[1]>35]
            self.assertGreater(len(samples),500)
            self.assertTrue(all(p[:3]==q for p,q in samples),key)

    def test_heroes_preserve_boot_baseline_and_never_stretch(self):
        for key,row in self.recipe['assets'].items():
            if row['mode']!='original_hero':continue
            _,g=self.recovered[key];l,t,r,b=g['source_painted_bounds'];w,h=g['painted_size']
            self.assertEqual([w,h],[round((r-l)*g['scale']),round((b-t)*g['scale'])])
            self.assertEqual(g['canvas_origin'][1]+h,min(507,g['original_canvas_bounds'][3]))
            self.assertLessEqual(g['scale'],1)

    def test_crownmere_preserves_original_full_source_44_bilinear_pad2(self):
        key='resource_site_neutral_miremoon_crownmere_controlled';row=self.recipe['assets'][key]
        original=Image.open(legacy.base.local(row['original_manifest_entry']['source_generated'])).convert('RGBA')
        reference=Image.new('RGBA',(48,48));reference.paste(original.resize((44,44),Image.Resampling.BILINEAR),(2,2))
        before=legacy.region(legacy.original_image(row['original_manifest_entry']),row['original_manifest_entry'])
        errors=[sum(abs(p[c]-q[c]) for c in range(3))/3 for p,q in zip(before.getdata(),reference.getdata()) if p[3]>245 and max(p[:3])-min(p[:3])>30]
        self.assertGreater(len(errors),100);self.assertLess(sum(errors)/len(errors),1.1)
        self.assertEqual(self.recovered[key][1],{'source_resize':[44,44],'canvas_origin':[2,2]})

    def test_tree_atlas_has_16_distinct_complete_transparent_paintings(self):
        rasters=[]
        for key,row in self.recipe['assets'].items():
            if row['mode']!='generated_tree':continue
            image=self.recovered[key][0];l,t,r,b=image.getbbox()
            self.assertTrue(4<=l<r<=124 and 4<=t<b<=124)
            self.assertEqual(image.getchannel('A').getextrema(),(0,255))
            self.assertGreater(sum(p[3]==255 for p in image.getdata()),4000)
            rasters.append(image.tobytes())
        self.assertEqual(len(set(rasters)),16)

    def test_fragment_removal_keeps_entire_original_main_subject_byte_exact(self):
        for key,row in self.recipe['assets'].items():
            if row['mode']!='remove_neighbor':continue
            before=legacy.original_image(row['original_manifest_entry']);after=self.recovered[key][0]
            a,b=list(before.getdata()),list(after.getdata())
            for i in largest_component(before):self.assertEqual(a[i],b[i],(key,i%512,i//512))
            self.assertTrue(all(q==(0,0,0,0) or p==q for p,q in zip(a,b)),key)
            self.assertLess(sum(p[3]>0 for p in b),sum(p[3]>0 for p in a),key)
        # The deliberately separated watchtower foreground rock is not dust.
        key='watchtower';before=legacy.original_image(self.recipe['assets'][key]['original_manifest_entry'])
        self.assertEqual(before.crop((318,375,344,388)).tobytes(),self.recovered[key][0].crop((318,375,344,388)).tobytes())

    def test_source_neutral_interiors_survive(self):
        sampled=0
        for key,row in self.recipe['assets'].items():
            if row['mode']=='remove_neighbor':continue
            source=self.sources[row['source']].crop(row['source_rect']);paint=legacy.source_paint(self.sources[row['source']],row)
            l,t,_,_=row['source_rect']
            for i,p in enumerate(source.getdata()):
                if i%113 or min(p[0],p[2])-p[1]>8:continue
                x,y=i%source.width,i//source.width
                if any(a<=x+l<c and b<=y+t<d for a,b,c,d in row.get('excluded_source_rects',[])):continue
                self.assertEqual(paint.getpixel((x,y)),(*p,255),(key,x,y));sampled+=1
        self.assertGreater(sampled,10000)

    def test_intentional_hero_prism_and_flower_pigments_survive(self):
        sampled=0
        for key,row in self.recipe['assets'].items():
            if not row.get('chromatic_source_rects'):continue
            source=self.sources[row['source']].crop(row['source_rect']);paint=legacy.source_paint(self.sources[row['source']],row)
            mask=Image.new('L',source.size)
            mask.putdata([0 if g<=24 and min(r,b)>80 and min(r,b)-g>64 else 255 for r,g,b in source.getdata()])
            interior=mask.filter(ImageFilter.MinFilter(5));l,t,_,_=row['source_rect']
            for i,p in enumerate(source.getdata()):
                x,y=i%source.width,i//source.width
                if i%7 or not interior.getpixel((x,y)) or not any(a<=x+l<c and b<=y+t<d for a,b,c,d in row['chromatic_source_rects']):continue
                self.assertEqual(paint.getpixel((x,y)),(*p,255),(key,x,y));sampled+=1
        self.assertGreater(sampled,400)

    def test_every_before_raster_fails_new_visible_art_acceptance(self):
        for key,row in self.recipe['assets'].items():
            before=legacy.region(legacy.original_image(row['original_manifest_entry']),row['original_manifest_entry'])
            after=self.recovered[key][0]
            old=Image.new('RGB',before.size,'#334c3a');new=old.copy()
            old.paste(before,(0,0),before);new.paste(after,(0,0),after)
            self.assertNotEqual(old.tobytes(),new.tobytes(),key)

    def test_corrupt_sources_identity_and_output_paths_fail_closed(self):
        with mock.patch.object(legacy.base,'digest',return_value='corrupt'):
            with self.assertRaisesRegex(ValueError,'provenance changed'):legacy.inputs()
        bad=json.loads(json.dumps(self.manifest));bad['object_assets']['generated_tree_autumn']['atlas_region'][0]=128
        with mock.patch.object(legacy,'ART_MANIFEST',mock.Mock(read_text=lambda:json.dumps(bad))):
            with self.assertRaisesRegex(ValueError,'Identity or placement'):legacy.inputs()
        for path in (ROOT,ROOT/'art',legacy.PACKET):
            with self.assertRaisesRegex(ValueError,'outside registered art'):legacy.prepare(path)

    def test_clipped_tree_branch_and_generation_corner_noise_are_rejected(self):
        row=dict(self.recipe['assets']['generated_tree_badland'],source_rect=[652,893,979,1205])
        with self.assertRaisesRegex(ValueError,'clips paint'):legacy.source_paint(self.sources['trees'],row)
        row=dict(self.recipe['assets']['generated_tree_autumn'],excluded_source_rects=[])
        with self.assertRaisesRegex(ValueError,'retains backing'):legacy.source_paint(self.sources['trees'],row)


if __name__=='__main__':unittest.main()
