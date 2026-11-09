"""Validate exported material dimensions, alpha masks and water frames."""
from pathlib import Path
from PIL import Image, ImageChops
import json

root = Path(__file__).resolve().parents[2] / 'PocketRepublic/Assets.xcassets'
folders = list((root / 'IslandMaterials').glob('*.imageset'))
assert len(folders) == 21
for folder in folders:
    name = folder.stem
    catalog = json.loads((folder / 'Contents.json').read_text())
    assert len(catalog['images']) == 3
    for scale in [1, 2, 3]:
        image = Image.open(folder / f'{name}@{scale}x.png')
        assert image.mode == 'RGBA' and image.size == (64*scale, 32*scale), name
        assert all(image.getpixel(p)[3] == 0 for p in [
            (0, 0), (image.width-1, 0), (0, image.height-1), (image.width-1, image.height-1)]), name
    old_name = name.replace('_golden', '')
    if name.startswith('road_'):
        original = root / 'Roads' / f'{old_name}.imageset' / f'{old_name}@3x.png'
    else:
        kind = name.split('_')[1]
        original = root / 'Terrain' / f'tile_{kind}_0.imageset/tile_{kind}_0@3x.png'
    actual = Image.open(folder / f'{name}@3x.png').getchannel('A')
    expected = Image.open(original).getchannel('A')
    assert ImageChops.difference(actual, expected).getbbox() is None, name
water = root / 'IslandMaterials'
first = Image.open(water / 'tile_water_golden.imageset/tile_water_golden@3x.png')
next_frame = Image.open(water / 'tile_water_golden_f1.imageset/tile_water_golden_f1@3x.png')
assert ImageChops.difference(first.convert('RGB'), next_frame.convert('RGB')).getbbox() is not None
print('63 RGBA exports passed: scale sizes, transparent corners, catalog entries, exact legacy 3x masks and distinct water frames.')
