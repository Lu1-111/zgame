"""新增/修改像素资产门禁：登记像素数、32色色板、硬alpha及一次原生网格转换记录。"""
from pathlib import Path
import argparse
import json
import re
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]


def resolve(path):
    return ROOT/path.removeprefix('res://')


def check(manifest):
    cfg=json.loads(manifest.read_text(encoding='utf8'))
    spec=json.loads(resolve(cfg['pixel_spec']).read_text(encoding='utf8'))
    standard=json.loads(resolve(cfg['pixel_standard']).read_text(encoding='utf8'))
    allowed={tuple(bytes.fromhex(c[1:])) for c in spec['palette']}
    failures=[]
    if int(spec['max_colors'])>int(standard['default_palette_limit']) or len(allowed)>int(spec['max_colors']):
        failures.append('Palette exceeds the numeric project limit; exceptions require an explicit approved contract')
    rows=[]
    assets=list(cfg['assets'].values()) if isinstance(cfg['assets'],dict) else list(cfg['assets'])
    terrain=cfg.get('terrain',{})
    assets+=terrain.get('variants',[])
    extra_images=[]
    if 'continuous_field' in terrain:
        extra_images.append((terrain['continuous_field'],spec['rock_field_size']))
    if 'atlas' in terrain:
        extra_images.append((terrain['atlas'],[spec['atlas_columns']*spec['tile_size'],spec['atlas_rows']*spec['tile_size']]))
    for extra,size in extra_images:
        assets.append({'path':extra,'native_canvas':size,'runtime_scale':[1,1]})
    for entry in assets:
        path=resolve(entry['path'])
        im=Image.open(path).convert('RGBA');a=np.array(im)
        visible=a[:,:,3]>0
        color_count=len(np.unique(a[:,:,:3][visible],axis=0))
        colors={tuple(v) for v in np.unique(a[:,:,:3][visible],axis=0)}
        expected=entry.get('native_canvas')
        if not expected or len(expected)!=2 or any(type(v) is not int or v<1 for v in expected):
            failures.append(f'{path.name}: canvas must be two positive integer pixel counts')
        if expected is None or list(im.size)!=expected:
            failures.append(f'{path.name}: actual pixels {im.size} != declared {expected}')
        if entry.get('runtime_scale')!=standard['runtime_foreground_scale']:
            failures.append(f'{path.name}: runtime scale is not native 1:1')
        if not set(np.unique(a[:,:,3]))<={0,255}:
            failures.append(f'{path.name}: smoothed alpha edge')
        if color_count>int(spec['max_colors']) or not colors<=allowed:
            failures.append(f'{path.name}: {color_count} colors outside declared palette')
        import_file=path.with_suffix(path.suffix+'.import')
        if import_file.exists() and re.search(r'mipmaps/generate=true',import_file.read_text(encoding='utf8')):
            failures.append(f'{path.name}: mipmaps enabled')
        rows.append({'path':entry['path'],'pixels':list(im.size),'visible_rect':im.getbbox(),'colors':color_count,'alpha':[int(v) for v in np.unique(a[:,:,3])]})
    conversions=json.loads(resolve(spec['conversion_report']).read_text(encoding='utf8')) if spec.get('conversion_report') else {'conversions':[]}
    if standard.get('converter_required',False) and conversions['conversions']:
        tool=str(conversions.get('tool','')).split(' (')[0]
        if tool not in standard['approved_converter_paths'] or not (ROOT/tool).is_file():
            failures.append('Generated source requires an approved dedicated pixel-conversion tool and its conversion report')
        if not conversions.get('tool_version'):
            failures.append('Conversion report must record its tool version')
    if not conversions['conversions'] and not all(item.get('authored_native',False) for item in assets):
        failures.append('Provide a converter report or explicitly register authored_native for hand-placed pixel assets')
    for record in conversions['conversions']:
        if record['resampling_passes']!=1 or record['runtime_scale']!=[1,1]:
            failures.append(f'{record["id"]}: must convert once onto final pixel grid')
        if record['id'] in spec['sprite_canvases'] and record['canvas_pixels']!=spec['sprite_canvases'][record['id']]:
            failures.append(f'{record["id"]}: converter output does not match native canvas')
    output={'standard':cfg['pixel_standard'],'manifest':manifest.relative_to(ROOT).as_posix(),'images':rows,'failures':failures,
            'visual_review_required':'1x actual view + nearest 4x; dimensions alone do not prove artistic pixel quality'}
    destination=ROOT/'work/qa/pixel_assets.json';destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(f'PIXEL ASSET QA: {len(rows)} images / native declared sizes / <= {spec["max_colors"]} colors / binary alpha / one-pass conversion / {len(failures)} failures')
    for error in failures: print('FAIL: '+error)
    return bool(failures)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest',required=True,type=Path)
    args=parser.parse_args()
    raise SystemExit(check(args.manifest.resolve()))


if __name__=='__main__': main()
