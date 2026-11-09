"""Export generated surface art on existing tile/road alpha geometry (ImageMagick)."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser()
for key in ['grass', 'water', 'sand', 'rock']:
    parser.add_argument('--' + key, required=True, type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2] / 'PocketRepublic/Assets.xcassets'
out = root / 'IslandMaterials'
out.mkdir(exist_ok=True)

def run(*values):
    subprocess.run(['magick', *map(str, values)], check=True)

def export(name, source):
    folder = out / (name + '.imageset')
    folder.mkdir(exist_ok=True)
    for scale in [1, 2, 3]:
        run(source, '-filter', 'Lanczos', '-resize', f'{64*scale}x{32*scale}!', '-strip',
            'PNG32:' + str(folder / f'{name}@{scale}x.png'))
    (folder / 'Contents.json').write_text(json.dumps({'images': [
        {'idiom': 'universal', 'filename': f'{name}@{scale}x.png', 'scale': f'{scale}x'}
        for scale in [1, 2, 3]], 'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')

with tempfile.TemporaryDirectory() as temp:
    temp = Path(temp)
    for kind in ['grass', 'water', 'sand', 'rock']:
        for frame in ([0, 1] if kind == 'water' else [0]):
            name = f'tile_{kind}_golden' + ('_f1' if frame else '')
            projected = temp / (name + '.png')
            mask = root / f'Terrain/tile_{kind}_0.imageset/tile_{kind}_0@3x.png'
            run(getattr(args, kind), '-resize', '192x192!', '-roll', '+6+0' if frame else '+0+0',
                '-virtual-pixel', 'Tile', '-define', 'distort:viewport=192x96+0+0',
                '-distort', 'AffineProjection', '0.5,0.25,-0.5,0.25,96,0', mask,
                '-compose', 'CopyOpacity', '-composite', 'PNG32:' + str(projected))
            export(name, projected)
    stone = out / 'tile_rock_golden.imageset/tile_rock_golden@3x.png'
    for folder in sorted((root / 'Roads').glob('road_*.imageset')):
        name = folder.stem
        masked = temp / (name + '.png')
        run(stone, folder / (name + '@3x.png'), '-compose', 'CopyOpacity', '-composite', 'PNG32:' + str(masked))
        export(name + '_golden', masked)
print('Exported five surface frames and all sixteen road-mask variants at 1x/2x/3x.')
