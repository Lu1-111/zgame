"""将已完成像素转换的独立武器按动作握点生成逐帧层；不改人物、招式和伤害数据。"""
from pathlib import Path
import argparse
import json
import math
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model',type=Path,required=True,help='JSON: id/name/weapon_type/texture/native_canvas/grip/source_angle_degrees')
    parser.add_argument('--output-dir',type=Path,required=True)
    parser.add_argument('--register',action='store_true',help='将新外观登记到正式表现清单，不改任何武器属性')
    args=parser.parse_args();spec=json.loads(args.model.read_text(encoding='utf8'))
    source_path=ROOT/spec['texture'].removeprefix('res://');source=Image.open(source_path).convert('RGBA');a=np.array(source)
    if len(spec['grip'])!=2 or any(not isinstance(v,(int,float)) or not math.isfinite(v) for v in spec['grip']):raise ValueError('Grip must contain two finite native pixel coordinates')
    if any(v<0 or v>=limit for v,limit in zip(spec['grip'],source.size)):raise ValueError('Grip lies outside the native weapon canvas')
    if not np.any(a[:,:,3]):raise ValueError('Empty weapon image')
    if list(source.size)!=spec['native_canvas'] or any(type(v) is not int or v<1 for v in spec['native_canvas']):raise ValueError('Native pixel dimensions must match JSON exactly')
    if not set(np.unique(a[:,:,3]))<={0,255}:raise ValueError('Convert soft alpha before attaching')
    if len(np.unique(a[:,:,:3][a[:,:,3]>0],axis=0))>32:raise ValueError('Convert to a <=32-color native weapon first')
    manifest_path=ROOT/'assets/PROCESSED/weapons/appearances/v001/manifest.json'
    manifest=json.loads(manifest_path.read_text(encoding='utf8'));bank={};outputs=[]
    for name,animation in manifest['animations'].items():
        if animation['module']!=spec['weapon_type']:continue
        bank[name]=[]
        for index,frame in enumerate(animation['frames']):
            width,height=frame['canvas'];yy,xx=np.indices((height,width))
            angle=math.radians(frame['socket']['angle_degrees']-spec.get('source_angle_degrees',0))
            cosine,sine=math.cos(angle),math.sin(angle);point=frame['socket']['position']
            dx,dy=xx-point[0],yy-point[1]
            sx=np.rint(dx*cosine+dy*sine+spec['grip'][0]).astype(int);sy=np.rint(-dx*sine+dy*cosine+spec['grip'][1]).astype(int)
            valid=(sx>=0)&(sy>=0)&(sx<source.width)&(sy<source.height);layer=np.zeros((height,width,4),np.uint8);layer[valid]=a[sy[valid],sx[valid]]
            if np.any(layer[[0,-1],:,3]) or np.any(layer[:,[0,-1],3]):raise ValueError(f'Weapon clips native canvas: {name}/{index}; provide an explicitly reviewed larger action canvas')
            output=args.output_dir/name/f'{index:02d}.png';outputs.append((output,Image.fromarray(layer)))
            path='res://'+output.resolve().relative_to(ROOT).as_posix()
            bank[name].append(path)
    if not bank:raise ValueError('Unknown weapon_type; no matching action module')
    if any(path.exists() for path,_ in outputs):raise ValueError('Refusing to overwrite an existing weapon bank')
    for path,image in outputs:path.parent.mkdir(parents=True,exist_ok=True);image.save(path)
    result={'id':spec['id'],'weapon_type':spec['weapon_type'],'source':spec,'animations':bank,'resampling':'native nearest rotation only; scale=1; no body edits'}
    (args.output_dir/'bank.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    if args.register:
        if not args.output_dir.resolve().is_relative_to(ROOT/'assets/PROCESSED/weapons'):raise ValueError('Registered models must be under assets/PROCESSED/weapons')
        config_path=ROOT/'data/weapon_appearances.json';config=json.loads(config_path.read_text(encoding='utf8'))
        if spec['id'] in config['skins'] and config['skins'][spec['id']].get('model_spec')!=spec:raise ValueError('Appearance ID already exists with a different model; use a new ID')
        for name,paths in bank.items():
            for frame,path in zip(manifest['animations'][name]['frames'],paths):frame['skins'][spec['id']]={'weapon':path}
        config['skins'][spec['id']]={'name':spec['name'],'weapon_type':spec['weapon_type'],'model_spec':spec}
        if spec['weapon_type']=='rifle':config['skins'][spec['id']]['rifle_texture']=spec
        manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
        config_path.write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(f'WEAPON MODEL BANK: {sum(map(len,bank.values()))} frames / {len(bank)} actions / fixed native grip / no combat edits')


if __name__=='__main__':main()
