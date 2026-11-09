"""Check all nine golden building assets and their legacy fallback canvases."""
import json
import argparse
from pathlib import Path
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('--renderer', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
assets = root/'PocketRepublic/Assets.xcassets/Buildings'
sizes = {'house': (128, 125), 'workshop': (160, 163), 'market': (160, 123),
         'farm': (192, 154), 'townHall': (192, 222), 'clinic': (192, 185),
         'school': (192, 206), 'police': (128, 114), 'dock': (160, 140)}
renderer = (root/'PocketRepublic/Views/BuildingArtwork.swift').read_text()
for kind, (width, height) in sizes.items():
    name = f'building_{kind}_golden'
    folder = assets/f'{name}.imageset'
    entries = json.loads((folder/'Contents.json').read_text())['images']
    assert len(entries) == 3
    if args.renderer:
        assert f'"{name}"' in renderer, f'{kind} not selected by renderer'
    assert (assets/f'building_{kind}.imageset').is_dir(), f'{kind} fallback missing'
    for scale in [1, 2, 3]:
        image = Image.open(folder/f'{name}@{scale}x.png')
        assert image.mode == 'RGBA' and image.size == (width*scale, height*scale), name
        assert all(image.getpixel(p)[3] == 0 for p in [
            (0, 0), (image.width-1, 0), (0, image.height-1), (image.width-1, image.height-1)]), name
        assert any(e['filename'] == f'{name}@{scale}x.png' and e['scale'] == f'{scale}x' for e in entries)
print('All nine golden building types / 27 PNG scales passed: dimensions, RGBA, transparent corners, catalogs, legacy fallback, plus renderer names when requested.')
