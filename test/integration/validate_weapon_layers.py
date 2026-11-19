"""逐像素核对去武器身体、手指前景与原武器重装，保持所有已确认人物像素。"""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]


def main():
    data=json.loads((ROOT/'assets/PROCESSED/weapons/appearances/v001/manifest.json').read_text(encoding='utf8'))
    checks=0;errors=[]
    for name,animation in data['animations'].items():
        for index,frame in enumerate(animation['frames']):
            source=Image.open(ROOT/frame['source']['path'][6:]).convert('RGBA')
            if 'region' in frame['source']:
                x,y,w,h=frame['source']['region'];source=source.crop((x,y,x+w,y+h))
            original=np.array(source);body=np.array(Image.open(ROOT/frame['body'][6:]).convert('RGBA'))
            mask=np.array(Image.open(ROOT/frame['mask'][6:]).convert('L'))>0
            weapon=np.array(Image.open(ROOT/frame['skins']['original']['weapon'][6:]).convert('RGBA'))
            fingers=np.array(Image.open(ROOT/frame['foreground'][6:]).convert('RGBA'))
            result=body.copy();result[weapon[:,:,3]>0]=weapon[weapon[:,:,3]>0];result[fingers[:,:,3]>0]=fingers[fingers[:,:,3]>0]
            checks+=3
            if not np.array_equal(result,original):errors.append(f'{name}/{index}: original weapon reassembly changed pixels')
            if not np.array_equal(body[~mask],original[~mask]):errors.append(f'{name}/{index}: body pixels outside weapon mask changed')
            if not mask.any() or list(source.size)!=frame['canvas']:errors.append(f'{name}/{index}: empty mask or canvas mismatch')
    report={'actions':len(data['animations']),'frames':data['frames'],'checks':checks,'failures':errors}
    (ROOT/'work/qa/weapon_layers.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(f'WEAPON LAYER PIXELS: {data["frames"]} frames / {checks} checks / {len(errors)} failures')
    for error in errors:print('FAIL:',error)
    return int(bool(errors))


if __name__=='__main__':raise SystemExit(main())
