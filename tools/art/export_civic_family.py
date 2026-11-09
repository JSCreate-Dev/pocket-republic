"""Export generated building family on unchanged logical canvases (ImageMagick)."""
import argparse
import json
from pathlib import Path
import subprocess

sizes = {'farm': (192, 154), 'townHall': (192, 222), 'clinic': (192, 185),
         'school': (192, 206), 'police': (128, 114), 'dock': (160, 140)}
parser = argparse.ArgumentParser()
for kind in sizes:
    parser.add_argument('--' + kind, required=True, type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2] / 'PocketRepublic/Assets.xcassets/Buildings'
for kind, (width, height) in sizes.items():
    name = f'building_{kind}_golden'
    folder = root / f'{name}.imageset'
    folder.mkdir(exist_ok=True)
    largest = folder / f'{name}@3x.png'
    # Top/side safe margin, while bottom-center ground contact remains anchored.
    subprocess.run(['magick', str(getattr(args, kind)), '-trim', '+repage', '-filter', 'Lanczos',
                    '-resize', f'{width*3-6}x{height*3-6}', '-background', 'none', '-gravity', 'south',
                    '-extent', f'{width*3}x{height*3}', '-colorspace', 'sRGB', '-strip', 'PNG32:'+str(largest)], check=True)
    for scale in [1, 2]:
        subprocess.run(['magick', str(largest), '-filter', 'Lanczos', '-resize', f'{width*scale}x{height*scale}',
                        '-strip', 'PNG32:'+str(folder/f'{name}@{scale}x.png')], check=True)
    (folder/'Contents.json').write_text(json.dumps({'images': [
        {'idiom': 'universal', 'filename': f'{name}@{scale}x.png', 'scale': f'{scale}x'}
        for scale in [1, 2, 3]], 'info': {'author': 'xcode', 'version': 1}}, indent=2)+'\n')
print('Exported six new building families, 18 RGBA PNG scales, with original canvases and bottom anchors.')
