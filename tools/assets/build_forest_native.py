"""重制森林全套原生素材并登记，布局不变；旧素材和地图已完整备份。"""
from pathlib import Path
import json
import random
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from pixel_grid import convert,quantize

ROOT=Path(__file__).resolve().parents[2]
RAW=ROOT/'assets/RAW/environments/forest/v002'
BASE=ROOT/'assets/environments'
TERRAIN=BASE/'terrain/forest/v002'
PROPS=BASE/'props/forest/v002'
BG=BASE/'backgrounds/forest/v002'
FX=ROOT/'assets/effects/forest_mist_v2'
PALETTE=json.loads((ROOT/'docs/art/drafts/forest_decorations.json').read_text(encoding='utf8'))['palette']
SIZES={'fallen_log':[96,40],'broken_waystone':[32,48],'forest_fungi':[48,32],'hanging_roots':[48,64],
       'glow_fungi':[48,32],'seedpod_vines':[48,64],'root_arch':[96,64],'moss_rocks':[48,32],
       'wooden_chest':[48,32],'ruin_switch':[32,48],'fern_mushrooms':[48,32],'vine':[32,64]}
ASSETS={};REPORT=[]


def save(im,path):
    path.parent.mkdir(parents=True,exist_ok=True);im.save(path)
    return 'res://'+path.relative_to(ROOT).as_posix()


def add(key,im,path,kind,anchor='bottom'):
    a=im.getbbox()
    xs=np.where(np.array(im)[:,:,3][a[1] if anchor=='top' else a[3]-1,:]>0)[0]
    foot=int(xs[np.argmin(abs(xs-im.width/2))]) if len(xs) else im.width//2
    ASSETS[key]={'path':save(im,path),'kind':kind,'size':list(im.size),'native_canvas':list(im.size),'runtime_scale':[1,1],
                 'anchor':[foot,a[1] if anchor=='top' else a[3]],'visible_rect':[a[0],a[1],a[2]-a[0],a[3]-a[1]],'z_index':1}


def native(raw,size,key,anchor='bottom',opaque=False):
    im,report=convert(raw,size,PALETTE,anchor=anchor,opaque=opaque,visible_size=size if opaque else None)
    REPORT.append({'id':key,**report})
    return im


def main():
    field=native(Image.open(RAW/'terrain_source.png'),[256,256],'rock_field',opaque=True)
    add('rock_field',field,TERRAIN/'rock_field.png','terrain')
    background=native(Image.open(RAW/'background_source.png'),[640,360],'forest_background',opaque=True)
    add('forest_background',background,BG/'deep_woodland.png','background')
    ASSETS['forest_background'].update({'space':'screen','z_index':-30,'anchor':[0,0]})
    sheet=Image.open(RAW/'props_source.png').convert('RGBA')
    for i,(key,size) in enumerate(SIZES.items()):
        x=i%4;y=i//4
        raw=sheet.crop((round(x*sheet.width/4),round(y*sheet.height/3),round((x+1)*sheet.width/4),round((y+1)*sheet.height/3)))
        anchor='top' if key in ['hanging_roots','seedpod_vines','vine'] else 'bottom'
        im=native(raw,size,key,anchor)
        add(key,im,PROPS/(key+'.png'),'prop',anchor)
    # 从原生岩石场派生拼接片，禁止在运行时拉长纹理；每片都保留世界像素尺度。
    solid=field.crop((0,0,64,32));a=np.array(solid)
    moss=[tuple(bytes.fromhex(c[1:])) for c in PALETTE[:8]]
    for y in range(4):
        for x in range(64):a[y,x,:3]=moss[3+(x*7+y*3)%4]
    add('solid_top',Image.fromarray(a),TERRAIN/'solid_top.png','terrain')
    log=Image.open(PROPS/'fallen_log.png').convert('RGBA')
    branch=log.crop((16,16,80,28));branch=quantize(branch,PALETTE)
    aa=np.array(branch);aa[:3,:,3]=255
    for x in range(64):aa[0,x,:3]=moss[4+x%3]
    add('branch_platform',Image.fromarray(aa),TERRAIN/'branch_platform.png','terrain')
    gate=log.crop((16,12,80,28)).transpose(Image.Transpose.ROTATE_90)
    add('wood_gate',gate,PROPS/'wood_gate.png','prop')
    # 原篝火的32px逐帧本来就是原生图块；只转色板/硬alpha并另存新目录，不放大。
    fire_source=Image.open(ROOT/'assets/third_party/metroidvania_forge/ch_02_world_building_foundations/forgotten_forest_example_tileset.png').convert('RGBA')
    for i in range(5):
        frame=quantize(fire_source.crop((512+i*32,266,544+i*32,320)),PALETTE)
        canvas=Image.new('RGBA',(32,56));canvas.alpha_composite(frame,(0,2))
        add(f'fire_{i+1:02d}',canvas,PROPS/f'fire_{i+1:02d}.png','prop')
        ASSETS[f'fire_{i+1:02d}']['authored_native']=True
    edge_ids=[]
    for side in ['top','bottom','left','right']:
        for n in range(8):
            im=field.crop(((n%4)*64,(n//4)*64,(n%4+1)*64,(n//4+1)*64));a=np.array(im)
            rng=random.Random(n+810)
            for x in range(64):
                h=2 if x<3 or x>=61 else rng.randrange(1,6)
                a[:h,x]=0
            im=Image.fromarray(a)
            if side=='bottom':im=im.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            if side=='left':im=im.transpose(Image.Transpose.ROTATE_90)
            if side=='right':im=im.transpose(Image.Transpose.ROTATE_270)
            key=f'edge_{side}_{n:02d}';add(key,im,TERRAIN/'edges'/(key+'.png'),'terrain');edge_ids.append(key)
    # 已有雾墙动作转换为原生32格，再在运行时按所需实体范围平铺，不非等比拉伸。
    old=json.loads((ROOT/'backup/2026-11-17_forest_original/data/forest_mist.json').read_text(encoding='utf8'))
    source=Image.open(ROOT/old['sheet'][6:]).convert('RGBA')
    fog=Image.new('RGBA',(32*8,32))
    for i in range(8):
        raw=source.crop((i*old['cell'][0],0,(i+1)*old['cell'][0],old['cell'][1]))
        frame,report=convert(raw,[32,32],['#20352d','#87947b','#c7d0ac','#f1e7c3'],visible_size=[32,32])
        fog.alpha_composite(frame,(i*32,0));REPORT.append({'id':f'mist_{i}',**report})
    add('mist_sheet',fog,FX/'mist_sheet.png','effect')
    old.update({'source':'res://assets/effects/forest_mist_v2/mist_sheet.png','sheet':'res://assets/effects/forest_mist_v2/mist_sheet.png','cell':[32,32],'native_tiled':True})
    (ROOT/'data/forest_mist.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    spec={'id':'forest_v002_pixels','standard':'res://data/art/pixel_standards.json','palette':PALETTE,'max_colors':32,
          'sprite_canvases':{k:v['size'] for k,v in ASSETS.items()},'conversion_report':'res://docs/art/audits/forest_pixel_conversion.json',
          'surface_snap_distance':96,'contact_probe':1,'contact_embed':1,'platform_tile_width':64,'background_opacity':0.75}
    manifest={'id':'forest_v002','pixel_spec':'res://data/art/forest_v002_pixel_spec.json','pixel_standard':spec['standard'],
              'assets':ASSETS,'palette':PALETTE,'native_pixel_scale':1,'filter':'nearest','edge_variants':edge_ids}
    for name,data in [('forest_v002_pixel_spec.json',spec),('forest_v002.json',manifest)]:
        (ROOT/'data/art'/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    report=ROOT/'docs/art/audits/forest_pixel_conversion.json';report.parent.mkdir(parents=True,exist_ok=True)
    report.write_text(json.dumps({'tool':'tools/assets/pixel_grid.py','conversions':REPORT,'tool_version':'native-grid-v1'},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    update_map_data(manifest)
    print('FOREST NATIVE:',len(ASSETS),'assets / 32 colors / 1:1')


def update_map_data(manifest):
    for i in range(1,4):
        p=ROOT/f'data/maps/forest_{i:02d}_art.json';d=json.loads(p.read_text(encoding='utf8'))
        d['pixel_native']=True;d['pixel_manifest']='res://data/art/forest_v002.json'
        d['wall']['texture']=ASSETS['rock_field']['path'];d['wall']['world_size']=[256,256];d['wall']['tint']='#ffffff'
        for kind,key in [('solid','solid_top'),('oneway','branch_platform')]:
            size=ASSETS[key]['size'];d[kind].update({'texture':ASSETS[key]['path'],'region':[0,0,*size],'surface_y':0,'body_source_depth':size[1],
                'cap_source_width':8,'cap_world_width':8,'segment_world_width':64,'tint':'#ffffff'})
        d['gate'].update({'texture':ASSETS['wood_gate']['path'],'region':[0,0,*ASSETS['wood_gate']['size']]})
        d['vine_texture']=ASSETS['vine']['path']
        for item in d.get('decorations',[]):
            key='moss_rocks' if 'moss_rocks' in item['texture'] else 'fern_mushrooms'
            item['texture']=ASSETS[key]['path'];item['scale']=1;item['asset_id']=key
        for item in d.get('vines',[]):item['scale']=1
        if 'decoration_assets' in d:
            for key,old in d['decoration_assets'].items():
                new=ASSETS[key];old.update({'texture':new['path'],'visible_rect':new['visible_rect'],'anchor_pixel':new['anchor'],'pixel_native':True,'tint':'#ffffff'})
            d['chest'].update({'texture':ASSETS['wooden_chest']['path'],'width':48})
            d['mechanism'].update({'switch_texture':ASSETS['ruin_switch']['path'],'switch_visible_rect':ASSETS['ruin_switch']['visible_rect'],
                                   'switch_width':ASSETS['ruin_switch']['visible_rect'][2]})
        p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
        p=ROOT/f'data/maps/forest_{i:02d}.json';layout=json.loads(p.read_text(encoding='utf8'))
        layout['background']=ASSETS['forest_background']['path'];layout['background_tint']='#bacdc0'
        p.write_text(json.dumps(layout,ensure_ascii=False,indent=2)+'\n',encoding='utf8')


if __name__=='__main__':main()
