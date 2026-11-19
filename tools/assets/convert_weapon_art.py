"""像素画RAW使用ImageMagick单次Point采样到登记的原生武器尺寸；不重画人物。"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess
import os
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
PALETTE=['#17131c','#29232d','#383944','#50515f','#6b6d7c','#9094a4','#b9bdc9','#e5e6e8',
         '#45302a','#6e4030','#985736','#c0804b','#e5ad72','#5d5a43','#938063','#d0b480',
         '#fff1ce','#696b2b','#97aa3b','#3e562b','#442438','#704351','#9c5367','#e5a6b4',
         '#4d071c','#920d28','#d02a35','#b95219','#d8a532','#fff0a0','#08748c','#35d7ec']


def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf8')


def res(path):return 'res://'+path.relative_to(ROOT).as_posix()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sources',type=Path,help='首次接入的id/source/prompt清单；省略时使用仓库RAW与转换记录重建')
    parser.add_argument('--magick',type=Path,required=True)
    args=parser.parse_args()
    env={**os.environ,'MAGICK_THREAD_LIMIT':'1','MAGICK_OCL_DEVICE':'OFF'}
    def run(cmd):return subprocess.run([str(args.magick.resolve()),*map(str,cmd)],capture_output=True,text=True,check=True,env=env).stdout.strip()
    version=run(['-version']).splitlines()[0]
    stage=ROOT/'work/weapons_2026_11_18';stage.mkdir(parents=True,exist_ok=True)
    palette=Image.new('RGB',(len(PALETTE),1));palette.putdata([tuple(bytes.fromhex(c[1:])) for c in PALETTE]);palette.save(stage/'palette.png')
    weapons={w['id']:w for w in json.loads((ROOT/'data/weapons.json').read_text(encoding='utf8'))['weapons']}
    recipes=[];assets=[]
    sources=json.loads(args.sources.read_text(encoding='utf8')) if args.sources else [
        {'id':r['id'],'source':str(ROOT/r['source'][6:]),
         'prompt':json.loads((ROOT/r['source'][6:]).with_name('generation.json').read_text(encoding='utf8'))['prompt']}
        for r in json.loads((ROOT/'data/art/weapon_conversion_v001.json').read_text(encoding='utf8'))['conversions']]
    for source in sources:
        id=source['id'];raw=ROOT/'assets/RAW/weapons'/id/'v001/source.png';raw.parent.mkdir(parents=True,exist_ok=True)
        if Path(source['source']).resolve()!=raw.resolve():shutil.copy2(source['source'],raw)
        write(raw.parent/'generation.json',{'tool':'built-in imagegen','prompt':source['prompt'],'policy':'pixel-art-first RAW; not runtime art; normalized separately'})
        im=Image.open(raw).convert('RGBA');alpha=im.getchannel('A').point(lambda a:255 if a>=128 else 0)
        bbox=alpha.getbbox()
        if not bbox:raise ValueError('Empty source: '+id)
        width,height=bbox[2]-bbox[0],bbox[3]-bbox[1]
        limit=32 if id=='hammer_05' else 34
        ratio=min(limit/width,18/height);sample=[round(width*ratio),round(height*ratio)]
        offset=[2,(24-sample[1])//2]
        folder=ROOT/'assets/PROCESSED/weapons'/id/'v001';folder.mkdir(parents=True,exist_ok=True)
        output=folder/'model.png'
        command=['-limit','thread','1','-size','48x24','xc:none','(',raw,'-alpha','on','-channel','A','-threshold','50%','+channel',
                 '-crop',f'{width}x{height}+{bbox[0]}+{bbox[1]}','+repage','-filter','point','-sample',f'{sample[0]}x{sample[1]}!',
                 '-channel','A','-threshold','50%','+channel','(','+clone','-alpha','extract','-write','mpr:alpha','+delete',')',
                 '-alpha','off','+dither','-remap',stage/'palette.png','mpr:alpha','-alpha','off','-compose','CopyAlpha','-composite',')',
                 '-geometry',f'+{offset[0]}+{offset[1]}','-compose','Over','-composite','-depth','8','-strip','-define','png:color-type=6','PNG32:'+str(output)]
        run(command)
        # 来源均为横向武器，握柄位于左端约15%；此固定握点逐帧复用，不按外伸包围盒再缩放。
        grip=[7,12]
        model={'id':id,'name':weapons[id]['name'],'weapon_type':weapons[id]['weapon_type'],'texture':res(output),
               'native_canvas':[48,24],'grip':grip,'source_angle_degrees':0,'runtime_scale':[1,1]}
        write(folder/'model.json',model)
        record={'id':id,'source':res(raw),'source_pixels':list(im.size),'source_crop':list(bbox),'sampled_pixels':sample,
                'canvas_pixels':[48,24],'offset':offset,'anchor':grip,'runtime_scale':[1,1],'resampling_passes':1,
                'sampling':'ImageMagick Point; fixed target; no dither; RGB remap and alpha mask separated',
                'source_sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'output_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),
                'command':[str(v) for v in command]}
        recipes.append(record)
        assets.append({'path':res(output),'native_canvas':[48,24],'runtime_scale':[1,1],'anchor':grip})
    report=ROOT/'data/art/weapon_conversion_v001.json'
    write(report,{'tool':'tools/assets/convert_weapon_art.py','tool_version':'weapon-point-v1 / '+version,'conversions':recipes})
    spec=ROOT/'assets/PROCESSED/weapons/catalog_v001/pixel_spec.json'
    write(spec,{'palette':PALETTE,'max_colors':32,'sprite_canvases':{r['id']:[48,24] for r in recipes},'conversion_report':res(report)})
    master=ROOT/'assets/PROCESSED/weapons/appearances/v001/manifest.json'
    if master.exists():
        for animation in json.loads(master.read_text(encoding='utf8'))['animations'].values():
            for frame in animation['frames']:
                for row in sources:
                    if row['id'] in frame['skins']:
                        assets.append({'path':frame['skins'][row['id']]['weapon'],'native_canvas':frame['canvas'],
                                       'runtime_scale':[1,1],'anchor':[int(v) for v in frame['anchor']],
                                       'derived_from':row['id'],'sampling':'native 1:1 nearest rotation of converted model; fixed per-frame socket'})
    write(spec.parent/'pixel_manifest.json',{'id':'weapons_v001','pixel_standard':'res://data/art/pixel_standards.json','pixel_spec':res(spec),'assets':assets})
    print(f'WEAPON POINT CONVERSION: {len(recipes)} RAWs / 48x24 / <=32 colors / hard alpha / native grip; {version}')


if __name__=='__main__':main()
