"""ITM-B01：只切格、固定比例 Nearest 缩放、语义锚点整数平移与资源打包。"""
from pathlib import Path
from collections import deque
import argparse
import base64
import hashlib
import json
import math
import shutil
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path('/home/lululu/zgame')
RAW = ROOT / 'assets/RAW/items/ITM-B01/v001'
OUT = ROOT / 'assets/PROCESSED/items/ITM-B01/v001'
IDS = ['potion_small', 'potion_mana', 'potion_sta', 'milk_bomb', 'mushroom',
       'honey_wax', 'milk_crystal', 'hp_fragment', 'sta_fragment',
       'mana_fragment', 'bag_expand', 'map_fragment', 'ability_double_jump']
TRACK = {'hp_fragment':'ITM-01', 'sta_fragment':'ITM-02', 'mana_fragment':'ITM-03',
         'bag_expand':'ITM-04', 'map_fragment':'ITM-05', 'potion_small':'ITM-06',
         'mushroom':'ITM-07', 'potion_mana':'ITM-08', 'potion_sta':'ITM-09',
         'milk_bomb':'ITM-10', 'honey_wax':'ITM-11', 'milk_crystal':'ITM-12',
         'ability_double_jump':'OBJ-06 / ABL-01'}
NEAREST = Image.Resampling.NEAREST
ANCHOR = [16, 24]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def dump(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n')


def primary_bbox(im):
    """用最大可见连通主体定位语义底边；仅分析，不修改 alpha。"""
    mask = np.array(im.getchannel('A')) >= 128
    h, w = mask.shape
    seen = np.zeros_like(mask)
    best = (0, (0, 0, w, h))
    for y, x in zip(*np.nonzero(mask)):
        if seen[y,x]:
            continue
        q = deque([(int(x), int(y))]); seen[y,x] = True
        count = 0; x0=x1=int(x); y0=y1=int(y)
        while q:
            xx, yy = q.popleft(); count += 1
            x0=min(x0,xx); x1=max(x1,xx); y0=min(y0,yy); y1=max(y1,yy)
            for nx,ny in ((xx-1,yy),(xx+1,yy),(xx,yy-1),(xx,yy+1)):
                if 0<=nx<w and 0<=ny<h and mask[ny,nx] and not seen[ny,nx]:
                    seen[ny,nx]=True; q.append((nx,ny))
        if count > best[0]:
            best=(count,(x0,y0,x1+1,y1+1))
    if best[0] == 0:
        raise ValueError('没有可见主体')
    return best[1]


def semantic_bbox(im, item_id):
    # 能力奖励的两层弧泡也是主体，必须一起注册到最下层弧泡底部。
    if item_id == 'ability_double_jump':
        return Image.fromarray((np.array(im.getchannel('A'))>=128).astype('uint8')*255).getbbox()
    return primary_bbox(im)


def uri(im):
    import io
    b=io.BytesIO(); im.save(b,format='PNG')
    return 'data:image/png;base64,'+base64.b64encode(b.getvalue()).decode()


def spriteframes(path, rows):
    lines=['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (1+sum(len(r['frames']) for r in rows)), '']
    idx=1
    for row in rows:
        row['_exts']=[]
        for frame in row['frames']:
            res='res://'+str((OUT/frame['path']).relative_to(ROOT))
            lines.append('[ext_resource type="Texture2D" path="%s" id="%d"]' % (res,idx))
            row['_exts'].append(str(idx)); idx+=1
    lines+=['','[resource]','animations = [']
    anims=[]
    for row in rows:
        frames=', '.join('{"duration": 1.0, "texture": ExtResource("%s")}'%i for i in row.pop('_exts'))
        anims.append('{"frames": [%s], "loop": true, "name": &"%s", "speed": 4.0}'%(frames,row['id']))
    lines+=[',\n'.join(anims),']']
    path.write_text('\n'.join(lines)+'\n')


def build():
    sources={i:list(RAW.rglob('ITEM_'+i+'_idle_v001.png')) for i in IDS}
    assert all(len(p)==1 for p in sources.values()), {i:len(p) for i,p in sources.items()}
    assert not OUT.exists(), '成品目录已存在；修订请新建版本，不覆盖。'
    items={v['id']:v for v in json.loads((ROOT/'data/items.json').read_text())['items']}
    (OUT/'godot').mkdir(parents=True)
    (OUT/'icons').mkdir()
    (OUT/'sheets').mkdir()
    result=[]
    for item_id in IDS:
        path=sources[item_id][0]; source=Image.open(path)
        assert source.mode=='RGBA', (path,source.mode)
        w,h=source.size
        assert w%2==0 and h%2==0
        cw,ch=w//2,h//2
        cells=[source.crop((i%2*cw,i//2*ch,(i%2+1)*cw,(i//2+1)*ch)) for i in range(4)]
        bodies=[semantic_bbox(im,item_id) for im in cells]
        roots=[[(b[0]+b[2])/2,b[3]] for b in bodies]
        if item_id=='ability_double_jump':
            # 闪星不可影响能力主体的横向root；根部仍取最低奶泡弧环。
            roots=[[(primary_bbox(im)[0]+primary_bbox(im)[2])/2,b[3]] for im,b in zip(cells,bodies)]
        # 每项单一尺度；不以每帧包围框改变大小。把完整 alpha 边缘纳入安全留白。
        s=(22 if item_id=='ability_double_jump' else 18)/max(max(b[2]-b[0],b[3]-b[1]) for b in bodies)
        for im,root in zip(cells,roots):
            b=im.getbbox(); assert b
            for extent,space in ((root[0]-b[0],ANCHOR[0]-2),(b[2]-root[0],32-ANCHOR[0]-2),
                                 (root[1]-b[1],ANCHOR[1]-2),(b[3]-root[1],32-ANCHOR[1]-2)):
                if extent>0:
                    s=min(s,space/extent)
        frames=[]; outputs=[]
        (OUT/'frames'/item_id).mkdir(parents=True)
        for i,(cell,root) in enumerate(zip(cells,roots)):
            # 先在共同大画布中按语义底边作整数配准，再统一降采样，避免源格排版差引起采样相位跳动。
            pre_dx=cw-math.floor(root[0]); pre_dy=ch-int(root[1])
            registered=Image.new('RGBA',(cw*2,ch*2)); registered.paste(cell,(pre_dx,pre_dy))
            scaled=registered.resize((max(1,round(cw*2*s)),max(1,round(ch*2*s))),NEAREST)
            # resize 的实际坐标倍率写入记录；帧间尺寸完全相同。
            sx,sy=scaled.width/(cw*2),scaled.height/(ch*2)
            body=semantic_bbox(scaled,item_id)
            dx=ANCHOR[0]-math.floor((body[0]+body[2])/2)
            dy=ANCHOR[1]-body[3]
            if item_id=='ability_double_jump' and i>0:
                # 弧环闪光导致阈值包围盒上下变化1px时，保持同一个源语义root，不追逐发光边缘。
                dx,dy=frames[0]['translation']
            box=scaled.getbbox()
            assert box and 0<box[0]+dx and box[2]+dx<32 and 0<box[1]+dy and box[3]+dy<32, (item_id,i,box,dx,dy)
            output=Image.new('RGBA',(32,32)); output.paste(scaled,(dx,dy))
            rel='frames/%s/ITEM_%s_idle_v001_f%02d.png'%(item_id,item_id,i+1)
            output.save(OUT/rel); outputs.append(output)
            a=np.array(output)[:,:,3]
            frame={'path':rel,'sourceRect':[i%2*cw,i//2*ch,cw,ch],
                   'sourceSemanticAnchor':root,'sourceBodyBBox':list(bodies[i]),
                   'sourceAlphaBBox':list(cell.getbbox()),'scaleNominal':s,'scaleActual':[sx,sy],
                   'preResizeTranslation':[pre_dx,pre_dy],'registeredCanvas':[cw*2,ch*2],
                   'translation':[dx,dy],'anchor':ANCHOR,'outputBodyBBox':list(semantic_bbox(output,item_id)),
                   'alphaBBox':list(output.getbbox()),'sha256':sha(OUT/rel),
                   'visiblePixels':int(np.sum(a>=128)), 'edgeAlphaNonzero':bool(a[0].any() or a[-1].any() or a[:,0].any() or a[:,-1].any())}
            frames.append(frame)
        sheet=Image.new('RGBA',(128,32))
        for i,im in enumerate(outputs):sheet.paste(im,(i*32,0))
        sheetpath='sheets/ITEM_%s_idle_v001_sheet.png'%item_id; sheet.save(OUT/sheetpath)
        # UI 图标直接取RAW首帧主体和固定5%留白，舍去远处装饰闪点；不二次缩放世界帧。
        ib=bodies[0]; margin=round(max(ib[2]-ib[0],ib[3]-ib[1])*0.05)
        icon_rect=[max(0,ib[0]-margin),max(0,ib[1]-margin),min(cw,ib[2]+margin),min(ch,ib[3]+margin)]
        icon=cells[0].crop(icon_rect)
        ratio=min(20/icon.width,20/icon.height)
        icon=icon.resize((max(1,round(icon.width*ratio)),max(1,round(icon.height*ratio))),NEAREST)
        canvas=Image.new('RGBA',(24,24)); canvas.paste(icon,((24-icon.width)//2,(24-icon.height)//2))
        iconpath='icons/ITEM_%s_icon_v001.png'%item_id; canvas.save(OUT/iconpath)
        diffs=[]
        for i,im in enumerate(outputs):
            aa=np.array(im).astype(int); bb=np.array(outputs[(i+1)%4]).astype(int)
            union=(aa[:,:,3]>=128)|(bb[:,:,3]>=128)
            diffs.append({'from':i,'to':(i+1)%4,'alphaSilhouetteIoU':float(np.sum((aa[:,:,3]>=128)&(bb[:,:,3]>=128))/max(1,np.sum(union))),
                          'meanPremultipliedDifference':float(np.abs(aa[:,:,:3]*aa[:,:,3,None]/255-bb[:,:,:3]*bb[:,:,3,None]/255).mean())})
        data=items[item_id]
        result.append({'id':item_id,'trackingId':TRACK[item_id],'name':data['name'],'type':data['type'],
                       'countsInTwelve':item_id!='ability_double_jump','size':[32,32],'anchor':ANCHOR,
                       'fps':4,'loop':True,'frameOrder':[0,1,2,3],'icon':iconpath,'iconSourceRect':icon_rect,'iconScale':ratio,'sheet':sheetpath,
                       'source':str(path.relative_to(ROOT)),'sourceSHA256':sha(path),'sourceSize':[w,h],
                       'prompt':str(path.with_suffix('.prompt.txt').relative_to(ROOT)),
                       'frames':frames,'continuity':diffs})
    manifest={'batch':'ITM-B01','version':'v001','generator':'built-in image_gen','formalItemCount':12,'extraAbilityCount':1,
              'scope':'素材展示组件；未接入游戏拾取/背包/碰撞/数值。',
              'processing':'保留RAW；切2x2格、每项固定尺度Nearest、主体底边整数对齐；不抠底、不阈值修改alpha、不重绘、不补间。',
              'defaults':{'anchor':ANCHOR,'worldCanvas':[32,32],'iconCanvas':[24,24],'fps':4,
                          'bobAmplitude':1.0,'bobPeriod':2.0,'baseLift':2.0,'pickupDuration':0.35,'pickupRise':8.0,'pickupEasePower':3.0},'items':result}
    dump(OUT/'manifest.json',manifest)
    atlas=Image.new('RGBA',(128,32*len(result)))
    icon_atlas=Image.new('RGBA',(24*len(result),24))
    for index,row in enumerate(result):
        atlas.paste(Image.open(OUT/row['sheet']),(0,index*32))
        icon_atlas.paste(Image.open(OUT/row['icon']),(index*24,0))
        row['atlasRects']=[[i*32,index*32,32,32] for i in range(4)]
        row['iconAtlasRect']=[index*24,0,24,24]
    atlas.save(OUT/'ITM-B01_v001_atlas.png')
    icon_atlas.save(OUT/'ITM-B01_v001_icons.png')
    manifest['atlas']={'file':'ITM-B01_v001_atlas.png','size':list(atlas.size),'grid':[4,len(result)],'trim':False,'rotate':False}
    manifest['iconAtlas']={'file':'ITM-B01_v001_icons.png','size':list(icon_atlas.size)}
    dump(OUT/'manifest.json',manifest)
    spriteframes(OUT/'godot/ItemSpriteFrames.tres',result)
    make_catalog(manifest)
    make_contact(result)
    make_preview(manifest)
    (OUT/'processing').mkdir()
    shutil.copy2(__file__,OUT/'processing/build.py')
    template=Path(__file__).with_name('preview_template.html')
    if not template.exists():
        template=ROOT/'work/items_pipeline/preview_template.html'
    shutil.copy2(template,OUT/'processing/preview_template.html')
    for filename in ('ItemVisual.gd','ItemVisual.tscn'):
        template=Path(__file__).with_name(filename+'.txt')
        if not template.exists():
            template=ROOT/'work/items_pipeline'/filename
        shutil.copy2(template,OUT/'godot'/filename)
        shutil.copy2(template,OUT/'processing'/(filename+'.txt'))
    dump(OUT/'qa.json',{'itemCount':len(result),'frameCount':sum(len(r['frames']) for r in result),
                      'trueAlpha':all(Image.open(OUT/f['path']).mode=='RGBA' for r in result for f in r['frames']),
                      'noAlphaAtEdges':all(not f['edgeAlphaNonzero'] for r in result for f in r['frames']),
                      'allSemanticAnchorsFixed':all(f['anchor']==ANCHOR for r in result for f in r['frames']),
                      'bodyBottomDeviationPxMax':max(abs(f['outputBodyBBox'][3]-24) for r in result for f in r['frames']),
                      'uniqueFrameHashes':{r['id']:len(set(f['sha256'] for f in r['frames'])) for r in result},
                      'sourceNotModified':all(sha(ROOT/r['source'])==r['sourceSHA256'] for r in result),
                      'reviewRequired':'需结合preview检查造型/闪点及3→0循环接缝，IoU仅诊断，不自动等同于通过。'})
    print('BUILT',OUT,'13 items / 52 frames / 13 icons')


def make_catalog(manifest):
    prefix='res://'+str(OUT.relative_to(ROOT))+'/'
    lines=['extends RefCounted','## 由本批 manifest 生成的展示参数；贴图预载保证导出依赖完整。',
           'const FRAMES: SpriteFrames = preload("ItemSpriteFrames.tres")',
           'const DEFAULTS: Dictionary = '+json.dumps(manifest['defaults'],ensure_ascii=False,indent=2),
           'const ITEMS: Dictionary = {']
    for row in manifest['items']:
        lines.append('    &"%s": {"anchor": Vector2(%s, %s), "icon": preload("%s%s")},'%(row['id'],*ANCHOR,prefix,row['icon']))
    lines+=['}']
    (OUT/'godot/ItemCatalog.gd').write_text('\n'.join(lines)+'\n')


def make_contact(rows):
    im=Image.new('RGB',(1000,math.ceil(len(rows)/4)*230),'#171421'); d=ImageDraw.Draw(im)
    fonts=list(Path('/usr/share/fonts').rglob('*CJK*.ttc'))
    font=ImageFont.truetype(str(fonts[0]),16) if fonts else ImageFont.load_default()
    small=ImageFont.truetype(str(fonts[0]),12) if fonts else font
    for i,row in enumerate(rows):
        x=i%4*250; y=i//4*230
        d.rounded_rectangle((x+8,y+8,x+242,y+222),radius=12,fill='#262135',outline='#4a405e')
        d.text((x+22,y+20),row['name'],font=font,fill='#fff2d5')
        d.text((x+22,y+46),row['id'],font=small,fill='#a99abb')
        sprite=Image.open(OUT/row['frames'][0]['path']).resize((128,128),NEAREST)
        im.paste(sprite,(x+32,y+68),sprite)
        icon=Image.open(OUT/row['icon']).resize((72,72),NEAREST)
        im.paste(icon,(x+165,y+100),icon)
        d.text((x+22,y+200),'WORLD 32x32    ICON 24x24',font=small,fill='#bdaccb')
    im.save(OUT/'contact_sheet.png')


def make_preview(manifest):
    data=json.loads(json.dumps(manifest))
    for row in data['items']:
        row['images']=[uri(Image.open(OUT/f['path'])) for f in row['frames']]
        row['iconData']=uri(Image.open(OUT/row['icon']))
    data['actor']=uri(Image.open(ROOT/'assets/PROCESSED/characters/CHR-01/v001/CHR-01_canonical_right_v001.png'))
    template=Path(__file__).with_name('preview_template.html')
    if not template.exists():
        template=ROOT/'work/items_pipeline/preview_template.html'
    (OUT/'preview.html').write_text(template.read_text().replace('__DATA__',json.dumps(data,ensure_ascii=False)))


if __name__=='__main__':
    build()
