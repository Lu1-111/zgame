"""登记已人工核对的像素包数值，供独立验收使用；不改变图像、不执行自动缩放。"""
from pathlib import Path
import argparse
import json
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest',required=True,type=Path)
    args=parser.parse_args()
    manifest=args.manifest.resolve()
    cfg=json.loads(manifest.read_text(encoding='utf8'))
    spec=json.loads((ROOT/cfg['pixel_spec'][6:]).read_text(encoding='utf8'))
    designs=json.loads((ROOT/'data/enemy_designs/cave_v001.json').read_text(encoding='utf8'))
    anchors={path:row['anchor'] for row in designs['enemies']+designs['effects'] for action in row['actions'] for path in action['frames']}
    assets=list(cfg['assets'].values()) if isinstance(cfg['assets'],dict) else list(cfg['assets'])
    terrain=cfg.get('terrain',{})
    assets+=terrain.get('variants',[])
    for name in ['continuous_field','atlas']:
        if name in terrain:assets.append({'path':terrain[name],'anchor':[0,0]})
    metrics={}
    for entry in assets:
        path=entry['path']
        im=Image.open(ROOT/path.removeprefix('res://')).convert('RGBA')
        declared=entry.get('native_canvas',list(im.size))
        if list(im.size)!=declared:
            raise ValueError(f'Declared canvas does not match image: {path}')
        metrics[path]={'native_canvas':declared,'visible_rect':list(im.getbbox()),
                       'anchor':entry.get('anchor',anchors.get(path,[0,0])),
                       'runtime_scale':[1,1],'palette_limit':spec['max_colors']}
    target=ROOT/'data/art/pixel_contracts'/(cfg['id']+'.json')
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(json.dumps({'manifest':manifest.relative_to(ROOT).as_posix(),'assets':metrics},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    packages_path=ROOT/'data/art/pixel_packages.json'
    packages=json.loads(packages_path.read_text(encoding='utf8'))
    for row in packages['packages']:
        if row['manifest']==manifest.relative_to(ROOT).as_posix():row['metrics']=target.relative_to(ROOT).as_posix()
    packages_path.write_text(json.dumps(packages,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(f'PIXEL METRICS REGISTERED: {len(metrics)} images; no image was modified')


if __name__=='__main__':main()
