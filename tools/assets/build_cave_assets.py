"""将 imagegen 洞穴母版切片、像素化并登记；原图保留，运行时不引用高分辨率母版。"""
from pathlib import Path
import json
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from pixel_grid import convert, quantize

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'assets/RAW/environments/cave/v001'
TERRAIN = ROOT / 'assets/environments/terrain/cave/v001'
PROPS = ROOT / 'assets/environments/props/cave/v001'
BACKGROUND = ROOT / 'assets/environments/backgrounds/cave/v001'
TILESET = ROOT / 'assets/environments/tilesets/cave/v001'
PREVIEW = ROOT / 'docs/previews/cave_v001'
PIXEL_SPEC = json.loads((ROOT/'data/art/cave_v001_pixel_spec.json').read_text(encoding='utf8'))
PALETTE_HEX = [c[1:] for c in PIXEL_SPEC['palette']]
PALETTE = np.array([tuple(bytes.fromhex(c)) for c in PALETTE_HEX], dtype=np.int16)
ASSETS = {}
CONVERSIONS = []


def pixel_palette(im, opaque=False):
    """只做最近邻和调色板规整，不重画母版；透明边统一为二值以避免色边。"""
    return quantize(im,PIXEL_SPEC['palette'],opaque)


def save(im, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    return 'res://' + path.relative_to(ROOT).as_posix()


def clean_sprite(im):
    """切片后删除游离的单像素噪点，保留白骨等有意义的分离碎块。"""
    im = pixel_palette(im)
    a = np.array(im)
    mask = a[:, :, 3] > 0
    visited = np.zeros(mask.shape, bool)
    for y, x in np.argwhere(mask):
        if visited[y, x]:
            continue
        group, stack = [], [(int(x), int(y))]
        visited[y, x] = True
        while stack:
            xx, yy = stack.pop()
            group.append((xx, yy))
            for dx, dy in [(1,0),(-1,0),(0,1),(0,-1)]:
                nx, ny = xx+dx, yy+dy
                if 0 <= nx < im.width and 0 <= ny < im.height and mask[ny,nx] and not visited[ny,nx]:
                    visited[ny,nx] = True
                    stack.append((nx,ny))
        if len(group) < 3:
            for xx, yy in group:
                a[yy, xx] = 0
    im = Image.fromarray(a)
    return im


def cell(source, column, row, columns, rows):
    w, h = source.size
    return source.crop((round(column*w/columns),round(row*h/rows),round((column+1)*w/columns),round((row+1)*h/rows)))


def sprite(source, column, row, columns, rows, identifier, anchor='bottom', visible_size=None, fit_size=None):
    part = cell(source,column,row,columns,rows)
    native,report=convert(part,PIXEL_SPEC['sprite_canvases'][identifier],PIXEL_SPEC['palette'],
                          anchor=anchor,alpha_cutoff=PIXEL_SPEC['alpha_cutoff'],visible_size=visible_size,fit_size=fit_size)
    CONVERSIONS.append({'id':identifier,'source_cell':[column,row,columns,rows],**report})
    return clean_sprite(native)


def register(identifier, im, path, kind, extra=None):
    ASSETS[identifier] = {'path':save(im,path),'kind':kind,'size':list(im.size),
                          'native_canvas':PIXEL_SPEC['sprite_canvases'][identifier],
                          'runtime_scale':[1,1], 'anchor':[im.width//2,im.height], 'z_index':1}
    if extra:
        ASSETS[identifier].update(extra)


def contour_polygon(mask):
    """像素覆盖保存为逐列最高点，碰撞由Godot BitMap沿alpha轮廓生成。"""
    return [int(np.where(mask[:,x])[0][0]) if mask[:,x].any() else -1 for x in range(mask.shape[1])]


def terrain():
    raw = Image.open(SOURCE/'terrain_source.png').convert('RGB')
    wall,report=convert(raw,PIXEL_SPEC['rock_field_size'],PIXEL_SPEC['palette'],opaque=True,
                        visible_size=PIXEL_SPEC['rock_field_size'])
    CONVERSIONS.append({'id':'rock_field',**report})
    save(wall,TERRAIN/'rock_field.png')
    entries = []
    # 4x4个64px原生纹理区域构成一张连续岩壁；可顺序拼回整幅，不依赖拉伸。
    for y in range(4):
        for x in range(4):
            im=wall.crop((x*64,y*64,(x+1)*64,(y+1)*64))
            entries.append((f'fill_{y*4+x:02d}',im,'fill'))
    # 外缘仅裁alpha并保留内侧纹理。每端固定4px接点，随机变化只在中间，交错仍接合。
    for side in ['top','bottom','left','right']:
        for variant in range(8):
            rng=random.Random(2100+variant)
            heights=[4]*64
            for xx in range(4,60,4):
                heights[xx:xx+4]=[rng.randint(1,9)]*4
            mask=np.ones((64,64),bool)
            for x,h in enumerate(heights):
                mask[:h,x]=False
            if side=='bottom': mask=np.flipud(mask)
            if side=='left': mask=mask.T
            if side=='right': mask=np.fliplr(mask.T)
            im=wall.crop((variant%4*64,variant//4*64,variant%4*64+64,variant//4*64+64))
            a=np.array(im); a[~mask]=0
            # 从原有色板选相邻岩面高光，明确可行走边界而不产生柔光或描边。
            for y,x in np.argwhere(mask):
                near = (y>0 and not mask[y-1,x]) if side=='top' else False
                if near:
                    c=a[y,x,:3].astype(int)
                    target=np.minimum(c+16,255)
                    a[y,x,:3]=PALETTE[np.argmin(((PALETTE-target)**2).sum(axis=1))]
            entries.append((f'edge_{side}_{variant:02d}',Image.fromarray(a),'edge_'+side))
    for concave in [False,True]:
        for corner in ['tl','tr','bl','br']:
            for variant in range(4):
                mask=np.ones((64,64),bool)
                for y in range(64):
                    for x in range(64):
                        xx=63-x if corner.endswith('r') else x
                        yy=63-y if corner.startswith('b') else y
                        threshold=12+(variant%2)*4
                        if (xx+yy<threshold or (not concave and (xx<4 or yy<4))):
                            mask[y,x]=False
                im=wall.crop((variant*64,128,variant*64+64,192))
                a=np.array(im);a[~mask]=0
                entries.append((f'{"inner" if concave else "outer"}_{corner}_{variant:02d}',Image.fromarray(a),'inner' if concave else 'outer'))
    atlas=Image.new('RGBA',(8*64,10*64))
    tile_manifest=[]
    for i,(identifier,im,kind) in enumerate(entries):
        atlas.paste(im,((i%8)*64,(i//8)*64))
        path=save(im,TERRAIN/'tiles'/f'{identifier}.png')
        tile_manifest.append({'id':identifier,'kind':kind,'atlas':[i%8,i//8],'path':path,'native_canvas':[64,64],'runtime_scale':[1,1]})
    save(atlas,TILESET/'terrain_atlas.png')
    return tile_manifest


def props():
    raw=Image.open(SOURCE/'props_source.png').convert('RGBA')
    groups=['crystal','rock','ore','bones']
    for row,kind in enumerate(groups):
        for col in range(4):
            identifier=f'{kind}_{col+1:02d}'
            extra={'light':{'color':'#79e7f0' if col<3 else '#b09fe7','energy':0.85,'radius':80}} if kind=='crystal' else {}
            register(identifier,sprite(raw,col,row,4,4,identifier),PROPS/kind/f'{identifier}.png',kind,extra)


def objects():
    raw=Image.open(SOURCE/'objects_source.png').convert('RGBA')
    names=['chest_closed','chest_locked','chest_opening','chest_open']
    chests=[sprite(raw,col,0,4,2,name,visible_size=PIXEL_SPEC['chest_visible'] if col<2 else None,fit_size=[40,40]) for col,name in enumerate(names)]
    # 全状态脚底对齐40x40；锁态只在同一闭合箱体上叠入母版锁块，确保箱体逐像素一致。
    locked=chests[0].copy()
    lock=chests[1].crop((20,24,29,36))
    locked.alpha_composite(lock,(20,24))
    chests[1]=locked
    for identifier,im in zip(names,chests):
        register(identifier,im,PROPS/'chests'/f'{identifier}.png','chest')
    for col in range(2):
        identifier=f'platform_{col+1:02d}'
        im=sprite(raw,col,1,4,2,identifier,anchor='top')
        register(identifier,im,TERRAIN/'platforms'/f'{identifier}.png','platform',{'surface_y':0,'one_way':True})
    for variant in range(4):
        identifier=f'stalagmites_{variant+1:02d}'
        im=sprite(raw,2+variant%2,1,4,2,identifier)
        if variant>=2:
            im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        a=np.array(im)[:,:,3]>0
        register(f'stalagmites_{variant+1:02d}',im,TERRAIN/'hazards'/f'stalagmites_{variant+1:02d}.png','hazard',
                 {'damage':None,'repeat_step':48,'collision':'alpha_contour','top_profile':contour_polygon(a)})


def background():
    raw=Image.open(SOURCE/'background_source.png').convert('RGB')
    canvas=PIXEL_SPEC['sprite_canvases']['deep_cavern']
    im,report=convert(raw,canvas,PIXEL_SPEC['palette'],opaque=True,visible_size=canvas)
    CONVERSIONS.append({'id':'deep_cavern',**report})
    register('deep_cavern',im,BACKGROUND/'deep_cavern.png','background',{'anchor':[0,0],'z_index':-30,'space':'screen'})


def board(tiles):
    fonts=[Path('C:/Windows/Fonts/msyh.ttc'),Path('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'),
           Path('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')]
    font_path=next((p for p in fonts if p.exists()),None)
    font=ImageFont.truetype(str(font_path),20) if font_path else ImageFont.load_default(size=20)
    small=ImageFont.truetype(str(font_path),16) if font_path else ImageFont.load_default(size=16)
    image=Image.new('RGB',(1280,1024),'#111521');draw=ImageDraw.Draw(image)
    draw.text((24,14),'CAVE · v001  /  原生像素素材',font=font,fill='#dce5e8')
    y=60
    for label,ids in [('荧光晶石 / 独立光源',[f'crystal_{i:02d}' for i in range(1,5)]),('普通岩石 / 矿石',[f'rock_{i:02d}' for i in range(1,5)]+[f'ore_{i:02d}' for i in range(1,5)]),('尸骨 / 金属宝箱',[f'bones_{i:02d}' for i in range(1,5)]+['chest_closed','chest_locked','chest_opening','chest_open']),('石质平台 / 成排石笋',['platform_01','platform_02']+[f'stalagmites_{i:02d}' for i in range(1,5)])]:
        draw.text((24,y),label,font=small,fill='#b7c9ce')
        for i,identifier in enumerate(ids):
            meta=ASSETS[identifier];im=Image.open(ROOT/meta['path'][6:])
            im=im.resize((im.width*2,im.height*2),Image.Resampling.NEAREST)
            x=32+i*153
            image.paste(im,(x,y+100-im.height),im)
            draw.text((x,y+108),identifier,font=small,fill='#8f9cae')
        y+=164
    draw.text((24,y),'岩壁填充 ×16 / 四向边缘 ×32 / 内外角 ×32',font=small,fill='#b7c9ce')
    for i,tile in enumerate(tiles[:8]+[v for v in tiles if v['kind']=='edge_top'][:8]):
        im=Image.open(ROOT/tile['path'][6:])
        x=24+(i%8)*153;yy=y+32+(i//8)*86
        image.paste(im,(x,yy),im)
    save(image,PREVIEW/'cave_asset_board.png')


def main():
    for directory in [TERRAIN,PROPS,BACKGROUND,TILESET,PREVIEW]: directory.mkdir(parents=True,exist_ok=True)
    tiles=terrain();props();objects();background()
    manifest={'id':'cave_v001','category':'cave','native_pixel_scale':1,'filter':'nearest','tile_size':64,
              'pixel_standard':'res://data/art/pixel_standards.json','pixel_spec':'res://data/art/cave_v001_pixel_spec.json',
              'palette':['#'+c for c in PALETTE_HEX], 'terrain':{'atlas':'res://assets/environments/tilesets/cave/v001/terrain_atlas.png',
              'tileset':'res://assets/environments/tilesets/cave/v001/cave_terrain.tres','continuous_field':'res://assets/environments/terrain/cave/v001/rock_field.png','variants':tiles},
              'assets':ASSETS,'chest':{'frame_seconds':0.12,'states':['closed','locked','opening','open'],'unlock_conditions':['none','encounter','key']},
              'crystal':{'pulse_seconds':2.4,'pulse_amount':0.10,'light_texture_size':128,'minimum_energy':0.1},
              'platform':{'collision_thickness':4,'collision_margin':1.0},
              'physics_layers':{'world':1,'player':2,'one_way':128,'hazard':256},
              'hazard':{'damage':None,'contract':'emit contact; room supplies configured damage; no invented balance values'},
              'production_note':'Runtime resources are pixel-quantized crops of imagegen source art. RAW files are never loaded by scenes.'}
    target=ROOT/'data/art/cave_v001.json';target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    report=ROOT/PIXEL_SPEC['conversion_report'][6:];report.parent.mkdir(parents=True,exist_ok=True)
    report.write_text(json.dumps({'tool':'tools/assets/pixel_grid.py','conversions':CONVERSIONS,'tool_version':'native-grid-v1'},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    board(tiles)
    print(f'CAVE ASSETS: {len(tiles)} terrain tiles / {len(ASSETS)} sprites / {len(PALETTE_HEX)} colors / native 1:1 / one-pass pixel-grid conversion')


if __name__=='__main__': main()
