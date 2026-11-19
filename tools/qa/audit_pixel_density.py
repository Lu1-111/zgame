"""核对实际引用的角色/forest/cave尺寸，并输出原生1倍与4倍最近邻对照图。"""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[2]


def image_info(resource):
    im=Image.open(ROOT/resource.removeprefix('res://')).convert('RGBA')
    return {'path':resource,'pixels':list(im.size),'visible_rect':list(im.getbbox())}


def main():
    standard=json.loads((ROOT/'data/art/pixel_standards.json').read_text(encoding='utf8'))
    cave=json.loads((ROOT/'data/art/cave_v001.json').read_text(encoding='utf8'))
    hero=image_info(standard['reference']['player_path'])
    hero.update({'role':'approved_player_reference','world_units_per_texel':1,'note':'approved master preserved unchanged'})
    references=[hero]
    legacy=[]
    forest_current=[]
    for map_id in ['forest_01','forest_02','forest_03']:
        cfg=json.loads((ROOT/f'data/maps/{map_id}_art.json').read_text(encoding='utf8'))
        layout=json.loads((ROOT/f'data/maps/{map_id}.json').read_text(encoding='utf8'))
        if layout.get('background'):
            background=image_info(layout['background'])
            background.update({'map':map_id,'status':'native_640x360_screen_background','runtime_filter':'nearest','runtime_scale':[1,1]})
            forest_current.append(background)
        wall=image_info(cfg['wall']['texture'])
        world=cfg['wall']['world_size']
        wall.update({'map':map_id,'world_pixels':world,'source_texels_per_world_unit':[wall['pixels'][i]/world[i] for i in range(2)],'status':'native_world_field'})
        forest_current.append(wall)
        for key,entry in cfg.get('decoration_assets',{}).items():
            data=image_info(entry['texture'])
            data.update({'map':map_id,'id':key,'status':'native_world_prop','runtime_scale':[1,1]})
            forest_current.append(data)
    for entry in standard['known_legacy']:
        legacy.append({**entry,'note':'Original snapshot: backup/2026-11-17_forest_original; not used by rebuilt forest maps'})
    for identifier,entry in cave['assets'].items():
        data=image_info(entry['path'])
        data.update({'id':identifier,'space':entry.get('space','world'),'runtime_scale':entry['runtime_scale'],'native_canvas':entry['native_canvas']})
        references.append(data)
    document={'date':'2026-11-17','basis':'640x360 logical screen, approved 64x64 player with ~42px visible height; foreground 1 texel/world unit',
              'approved_and_current_cave':references,'current_forest':forest_current,'historical_forest_deviations':legacy,
              'scope':'Forest v002 and cave native conversion; approved actor masters unchanged; old forest source/maps backed up'}
    target=ROOT/'docs/art/audits/pixel_density-2026-11-17.json'
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(json.dumps(document,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    make_board(cave,standard)
    make_enemy_board(standard)
    print(f'PIXEL DENSITY AUDIT: player 64x64 / visible height {hero["visible_rect"][3]-hero["visible_rect"][1]}px; cave + forest v002 scale 1:1; {len(legacy)} historical forest references recorded')


def make_board(cave,standard):
    candidates=[Path('C:/Windows/Fonts/msyh.ttc'),Path('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'),Path('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')]
    path=next((x for x in candidates if x.exists()),None)
    font=ImageFont.truetype(str(path),20) if path else ImageFont.load_default(size=20)
    image=Image.new('RGB',(1400,900),'#111521');draw=ImageDraw.Draw(image)
    draw.text((24,16),'原生像素密度核对 · 仅裁透明边，不重缩放角色',font=font,fill='#e3e7ed')
    ids=['player','crystal_03','rock_02','ore_01','bones_02','chest_locked','platform_01','stalagmites_01','tile']
    sprites=[]
    for identifier in ids:
        path=standard['reference']['player_path'] if identifier=='player' else cave['terrain']['variants'][0]['path'] if identifier=='tile' else cave['assets'][identifier]['path']
        im=Image.open(ROOT/path[6:]).convert('RGBA')
        size=im.size
        visible=im.crop(im.getbbox())
        sprites.append((identifier,visible,size))
    draw.text((24,55),'1×：实际文件像素（窗口放大另算）',font=font,fill='#a9c3d1')
    for i,(identifier,im,size) in enumerate(sprites):
        x=28+i*150
        image.paste(im,(x,165-im.height),im)
        caption={'stalagmites_01':'石笋','chest_locked':'上锁宝箱','platform_01':'石台'}.get(identifier,identifier)
        draw.text((x,175),caption,font=font,fill='#c4ced8')
        draw.text((x,202),f'{size[0]}×{size[1]}',font=font,fill='#8795aa')
    draw.text((24,250),'4× nearest：只用于检查像素网格，放大图不作为运行素材',font=font,fill='#a9c3d1')
    for i,(identifier,im,size) in enumerate(sprites):
        x=28+(i%5)*274;baseline=495+(i//5)*340
        enlarged=im.resize((im.width*4,im.height*4),Image.Resampling.NEAREST)
        image.paste(enlarged,(x,baseline-enlarged.height),enlarged)
        draw.text((x,baseline+7),identifier,font=font,fill='#c4ced8')
    image.save(ROOT/'docs/previews/cave_v001/cave_pixel_density_comparison.png')


def make_enemy_board(standard):
    """新敌怪与已确认主角同密度排列；只裁透明边，4倍图只作为检查用途。"""
    cfg=json.loads((ROOT/'data/enemy_designs/cave_v001.json').read_text(encoding='utf8'))
    path=Path('C:/Windows/Fonts/msyh.ttc')
    font=ImageFont.truetype(str(path),18) if path.exists() else ImageFont.load_default(size=18)
    rows=[{'name':'主角参照','canvas':[64,64],'path':standard['reference']['player_path']}]
    rows += [{'name':r['name'],'canvas':r['canvas'],'path':r['actions'][0]['frames'][0]} for r in cfg['enemies']]
    board=Image.new('RGB',(1680,1300),'#111521');draw=ImageDraw.Draw(board)
    draw.text((24,16),'1×原生像素 · 主角可见高度42px · 未按武器外伸缩放本体',font=font,fill='#dce5ed')
    images=[]
    for index,row in enumerate(rows):
        im=Image.open(ROOT/row['path'][6:]).convert('RGBA');im=im.crop(im.getbbox());images.append(im)
        x=24+index*205
        board.paste(im,(x,145-im.height),im)
        draw.text((x,155),row['name'],font=font,fill='#dce5ed')
        draw.text((x,181),f'{row["canvas"][0]}×{row["canvas"][1]}画布',font=font,fill='#93a4b9')
    draw.text((24,225),'4× nearest检查 · 下图放大不供运行使用',font=font,fill='#a5bfca')
    for index,(row,im) in enumerate(zip(rows,images)):
        x=24+(index%3)*552;baseline=540+(index//3)*340
        enlarged=im.resize((im.width*4,im.height*4),Image.Resampling.NEAREST)
        board.paste(enlarged,(x,baseline-enlarged.height),enlarged)
        draw.text((x,baseline+8),row['name'],font=font,fill='#dce5ed')
    board.save(ROOT/'docs/previews/cave_enemies_v001/native_density.png')


if __name__=='__main__': main()
