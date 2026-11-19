"""洞穴兽类母版→共用32色/固定比例逐帧画布；不启动Godot、不修改游戏数值。"""
from pathlib import Path
import json
import hashlib
import statistics
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from pixel_grid import quantize
from sprite_frames_writer import write_frames

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'assets/RAW/enemies/CAVE-BEASTS/v001'
OUT=ROOT/'assets/PROCESSED/enemies/CAVE-BEASTS/v001'
SPEC=json.loads((SOURCE/'pixel_spec.json').read_text(encoding='utf8'))
PALETTE=SPEC['palette']


def res(path):
    return 'res://'+path.relative_to(ROOT).as_posix()


def crop_frames(source,rows):
    image=Image.open(SOURCE/source).convert('RGBA')
    w,h=image.size
    frames=[]
    for row in range(rows):
        frames.append([image.crop((round(col*w/6),round(row*h/rows),round((col+1)*w/6),round((row+1)*h/rows))) for col in range(6)])
    return image,frames


def opaque_bbox(im):
    a=np.array(im)
    mask=(a[:,:,3]>=SPEC['alpha_cutoff']).astype(np.uint8)*255
    return Image.fromarray(mask).getbbox()


def clean(im):
    a=np.array(im)
    mask=a[:,:,3]>0
    seen=np.zeros(mask.shape,bool)
    for y,x in np.argwhere(mask):
        if seen[y,x]: continue
        stack=[(int(x),int(y))];seen[y,x]=True;group=[]
        while stack:
            xx,yy=stack.pop();group.append((xx,yy))
            for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)]:
                nx,ny=xx+dx,yy+dy
                if 0<=nx<im.width and 0<=ny<im.height and mask[ny,nx] and not seen[ny,nx]:
                    seen[ny,nx]=True;stack.append((nx,ny))
        if len(group)<2:
            for xx,yy in group: a[yy,xx]=0
    return Image.fromarray(a)


def fixed_sample(source,scale,canvas,anchor,source_anchor,lift=0):
    """全怪共用scale，仅对整格做一次预乘alpha面积采样；绝不逐帧按包围盒改变大小。"""
    arr=np.array(source).astype(np.float32)/255.0
    arr[arr[:,:,3]<SPEC['alpha_cutoff']/255.0]=0
    dims=(max(1,round(source.width*scale)),max(1,round(source.height*scale)))
    alpha=Image.fromarray(arr[:,:,3]).resize(dims,Image.Resampling.BOX)
    aa=np.array(alpha)
    channels=[]
    for ch in range(3):
        premult=Image.fromarray(arr[:,:,ch]*arr[:,:,3]).resize(dims,Image.Resampling.BOX)
        channels.append(np.array(premult)/np.maximum(aa,1e-6))
    sampled=Image.fromarray(np.clip(np.dstack(channels+[aa])*255,0,255).astype(np.uint8))
    sampled=clean(quantize(sampled,PALETTE))
    result=Image.new('RGBA',tuple(canvas))
    offset=(round(anchor[0]-source_anchor[0]*scale),round(anchor[1]-source_anchor[1]*scale+lift))
    result.alpha_composite(sampled,offset)
    return result,{'source_pixels':list(source.size),'sampled_pixels':list(dims),'canvas_pixels':canvas,'scale':scale,
                   'source_anchor':list(source_anchor),'anchor':anchor,'paste':list(offset),'vertical_motion':lift,
                   'resampling_passes':1,'runtime_scale':[1,1],'sampling':'constant_scale_cell_area_then_32_palette'}


def gif(frames,path,fps):
    palette=[]
    for color in PALETTE: palette.extend(bytes.fromhex(color[1:]))
    palette+= [0]*(768-len(palette))
    images=[]
    colors=np.array([tuple(bytes.fromhex(c[1:])) for c in PALETTE])
    for frame in frames:
        a=np.array(frame)
        index=np.zeros(a.shape[:2],dtype=np.uint8)
        for n,c in enumerate(colors): index[np.all(a[:,:,:3]==c,axis=2)]=n
        index[a[:,:,3]==0]=255
        p=Image.fromarray(index,mode='P');p.putpalette(palette);p.info['transparency']=255
        images.append(p.resize((p.width*2,p.height*2),Image.Resampling.NEAREST))
    images[0].save(path,save_all=True,append_images=images[1:],duration=round(1000/fps),loop=0,disposal=2,transparency=255,optimize=False)


def write_entity(definition):
    folder=OUT/definition['id'];folder.mkdir(parents=True,exist_ok=True)
    source,rows=crop_frames(definition['source'],len(definition['rows']))
    boxes=[opaque_bbox(f) for f in rows[0]]
    scale=definition['reference_visible_height']/statistics.median(box[3]-box[1] for box in boxes)
    catalog={'id':definition['id'],'name':definition['name'],'canvas':definition['canvas'],'anchor':definition['anchor'],
             'palette':PALETTE,'native_pixel_scale':1,'runtime_scale':[1,1],'filter':'nearest','base_hp':None,'base_damage':None,
             'poise':None,'resist':{'physical':None,'magic':None},'direction':'right','combat_implemented':False,
             'source':res(SOURCE/definition['source']),'source_sha256':hashlib.sha256((SOURCE/definition['source']).read_bytes()).hexdigest(),
             'body_scale':scale,'reference_visible_height':definition['reference_visible_height'],'animations':{},'projectiles':{},'effects':{}}
    animation_data={};conversion=[];allimages=[]
    for row,action in enumerate(definition['rows']):
        frames=[];frame_paths=[]
        directory=folder/'frames'/action;directory.mkdir(parents=True,exist_ok=True)
        for col,frame in enumerate(rows[row]):
            box=opaque_bbox(frame)
            source_anchor=(frame.width/2,frame.height/2) if definition.get('floating') else (frame.width/2,box[3])
            lift=definition.get('pose_vertical_offset',{}).get(action,[0]*6)[col]
            im,record=fixed_sample(frame,scale,definition['canvas'],definition['anchor'],source_anchor,lift)
            target=directory/f'{col:02d}.png';im.save(target)
            frames.append(im);frame_paths.append(res(target));conversion.append({'action':action,'frame':col,**record})
        fps=definition['fps'][row];loop=action in ['idle','move']
        sha=[hashlib.sha256(im.tobytes()).hexdigest() for im in frames]
        catalog['animations'][action]={'frames':frame_paths,'frame_count':6,'fps':fps,'loop':loop,'canvas':definition['canvas'],'anchor':definition['anchor'],
                                          'unique_frames':len(set(sha)),'sha256':sha,'visible_rects':[list(im.getbbox()) for im in frames],
                                          'grounded':not definition.get('floating'),
                                          'phase_tags':['cycle']*6 if loop else ['prepare','prepare','extend','active','recover','recover']}
        if action in ['web_spit','tail_crystal_shot']:
            catalog['animations'][action]['suggested_emission_frame']=3
        if action=='leap_slam':
            catalog['animations'][action]['suggested_impact_frame']=4
        if action in ['shell_defense','charge_ready']:
            catalog['animations'][action]['hold_frame']=3 if action=='shell_defense' else 5
        animation_data[action]={'frames':frame_paths,'fps':fps,'loop':loop}
        gif(frames,folder/f'{action}.gif',fps)
        allimages.append((action,frames))
    frames_path=folder/'sprite_frames.tres';write_frames(frames_path,animation_data)
    catalog['sprite_frames']=res(frames_path)
    (folder/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    (folder/'conversion.json').write_text(json.dumps(conversion,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    contact_sheet(allimages,folder/'contact_sheet.png',definition['canvas'])
    return catalog


def write_effect(definition):
    folder=OUT/'effects'/definition['id'];folder.mkdir(parents=True,exist_ok=True)
    source,rows=crop_frames(definition['source'],definition['rows'])
    originals=rows[definition['row']]
    boxes=[opaque_bbox(frame) for frame in originals]
    if definition.get('max_visible_width'):
        scale=definition['max_visible_width']/max(box[2]-box[0] for box in boxes)
    else:
        scale=definition['reference_width']/statistics.median(box[2]-box[0] for box in boxes)
    frames=[];paths=[];reports=[]
    for col,frame in enumerate(originals):
        box=boxes[col]
        source_anchor=(frame.width/2,box[3]) if definition['kind']=='effect' else ((box[0]+box[2])/2,(box[1]+box[3])/2)
        im,record=fixed_sample(frame,scale,definition['canvas'],definition['anchor'],source_anchor)
        target=folder/f'{col:02d}.png';im.save(target);frames.append(im);paths.append(res(target));reports.append(record)
    frames_path=folder/'sprite_frames.tres'
    write_frames(frames_path,{definition['id']:{'frames':paths,'fps':definition['fps'],'loop':definition['loop']}})
    gif(frames,folder/'preview.gif',definition['fps'])
    catalog={**definition,'frames':paths,'frame_count':6,'sprite_frames':res(frames_path),'palette':PALETTE,'runtime_scale':[1,1],
             'unique_frames':len(set(hashlib.sha256(im.tobytes()).hexdigest() for im in frames)),'body_scale':scale,
             'conversion':reports,'damage':None,'speed':None,'lifetime':None}
    (folder/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    contact_sheet([(definition['id'],frames)],folder/'contact_sheet.png',definition['canvas'])
    return catalog


def contact_sheet(actions,path,canvas):
    w,h=canvas
    image=Image.new('RGBA',(w*6,h*len(actions)),(17,21,33,255))
    for row,(_,frames) in enumerate(actions):
        for col,frame in enumerate(frames): image.alpha_composite(frame,(col*w,row*h))
    image.save(path)


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    catalogs=[write_entity(definition) for definition in SPEC['enemies']]
    effects=[write_effect(definition) for definition in SPEC['effects']]
    for catalog in catalogs:
        for effect in effects:
            if effect['owner']==catalog['id']:
                catalog['projectiles' if effect['kind']=='projectile' else 'effects'][effect['id']]=res(OUT/'effects'/effect['id']/'catalog.json')
        path=OUT/catalog['id']/'catalog.json';path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    index={'batch':'CAVE-BEASTS','version':'v001','pixel_spec':res(SOURCE/'pixel_spec.json'),'prompts':res(SOURCE/'prompts.json'),
           'enemies':{c['id']:res(OUT/c['id']/'catalog.json') for c in catalogs},'effects':{e['id']:res(OUT/'effects'/e['id']/'catalog.json') for e in effects},
           'palette':PALETTE,'native_pixel_scale':1,'runtime_scale':[1,1],'stats':'unassigned placeholders, no combat balancing authored',
           'generation':'built-in imagegen; actual articulated source poses; constant-scale one-pass area conversion, no per-frame bounding-box rescale'}
    (OUT/'catalog.json').write_text(json.dumps(index,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    pixel_manifest(catalogs,effects)
    overview(catalogs)
    validate(catalogs,effects)


def overview(catalogs):
    candidates=[Path('C:/Windows/Fonts/msyh.ttc'),Path('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc')]
    path=next((p for p in candidates if p.exists()),None)
    font=ImageFont.truetype(str(path),22) if path else ImageFont.load_default(size=22)
    small=ImageFont.truetype(str(path),17) if path else ImageFont.load_default(size=17)
    image=Image.new('RGBA',(1480,940),(17,21,33,255));draw=ImageDraw.Draw(image)
    draw.text((24,16),'CAVE-BEASTS · 原生像素怪物动作（图中2×仅用于查看）',font=font,fill='#dce5ed')
    labels={'ram':'撞击','shell_defense':'缩壳防御','claw_attack':'前爪攻击','web_spit':'吐丝','charge_ready':'发光攻击准备',
            'elbow_blade':'前爪岩刃','leap_slam':'跃起下砸','tail_crystal_shot':'扬尾晶石发射'}
    for row,catalog in enumerate(catalogs):
        top=64+row*214;baseline=top+156
        draw.text((24,top+28),catalog['name'],font=font,fill='#e7e3d2')
        draw.text((24,top+60),f'{catalog["canvas"][0]}×{catalog["canvas"][1]} / 本体原生',font=small,fill='#8f9fb3')
        actions=['idle']+[key for key in catalog['animations'] if key not in ['idle','move']]
        for column,action in enumerate(actions):
            frame=0 if action=='idle' else 5 if action=='charge_ready' else 2 if action in ['shell_defense','leap_slam','elbow_blade'] else 3
            im=Image.open(ROOT/catalog['animations'][action]['frames'][frame][6:]).convert('RGBA')
            im=im.crop(im.getbbox());im=im.resize((im.width*2,im.height*2),Image.Resampling.NEAREST)
            x=240+column*290
            image.alpha_composite(im,(x,baseline-im.height))
            draw.text((x,baseline+8),'闲置 / 移动已另备' if action=='idle' else labels[action],font=small,fill='#becbd8')
    image.save(OUT/'overview.png')


def pixel_manifest(catalogs,effects):
    assets={};canvases={};records=[]
    for catalog in catalogs:
        report=json.loads((OUT/catalog['id']/'conversion.json').read_text(encoding='utf8'))
        for name,action in catalog['animations'].items():
            for frame,path in enumerate(action['frames']):
                identifier=f'{catalog["id"]}_{name}_{frame:02d}'
                assets[identifier]={'path':path,'kind':'enemy_frame','native_canvas':catalog['canvas'],'runtime_scale':[1,1]}
                canvases[identifier]=catalog['canvas']
                record=next(r for r in report if r['action']==name and r['frame']==frame)
                records.append({'id':identifier,**record})
    for effect in effects:
        for frame,path in enumerate(effect['frames']):
            identifier=f'{effect["id"]}_{frame:02d}'
            assets[identifier]={'path':path,'kind':effect['kind'],'native_canvas':effect['canvas'],'runtime_scale':[1,1]}
            canvases[identifier]=effect['canvas']
            records.append({'id':identifier,**effect['conversion'][frame]})
    (OUT/'pixel_conversion.json').write_text(json.dumps({'tool':'tools/assets/build_cave_beasts_art.py (fixed-scale one-pass pixel-grid sampler)','conversions':records,'tool_version':'native-grid-v1'},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    (OUT/'pixel_spec_runtime.json').write_text(json.dumps({'palette':PALETTE,'max_colors':32,'sprite_canvases':canvases,'conversion_report':res(OUT/'pixel_conversion.json')},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    (OUT/'pixel_manifest.json').write_text(json.dumps({'id':'cave_beasts_v001','pixel_standard':'res://data/art/pixel_standards.json',
            'pixel_spec':res(OUT/'pixel_spec_runtime.json'),'assets':assets},ensure_ascii=False,indent=2)+'\n',encoding='utf8')


def validate(catalogs,effects):
    failures=[];checked=0
    allowed={tuple(bytes.fromhex(c[1:])) for c in PALETTE}
    for catalog in catalogs:
        scales=[]
        for name,action in catalog['animations'].items():
            if action['unique_frames']<4: failures.append(f'{catalog["id"]}/{name}: not enough unique poses')
            for path in action['frames']:
                im=Image.open(ROOT/path[6:]).convert('RGBA');a=np.array(im);checked+=1
                if list(im.size)!=catalog['canvas']: failures.append(f'{path}: incorrect canvas')
                if not set(np.unique(a[:,:,3]))<={0,255}: failures.append(f'{path}: alpha')
                if not {tuple(x) for x in a[a[:,:,3]>0][:,:3]}<=allowed: failures.append(f'{path}: palette')
                bbox=im.getbbox()
                if bbox[0]==0 or bbox[1]==0 or bbox[2]==im.width or bbox[3]==im.height: failures.append(f'{path}: clipping')
    for effect in effects:
        checked+=len(effect['frames'])
        if effect['unique_frames']<4: failures.append(effect['id']+': insufficient distinct frames')
    report={'images':checked,'failures':failures,'frame_count':sum(a['frame_count'] for c in catalogs for a in c['animations'].values())+sum(e['frame_count'] for e in effects),
            'enemy_count':len(catalogs),'action_count':sum(len(c['animations']) for c in catalogs),'effect_count':len(effects),'palette_count':32,
            'note':'Godot import/unit/runtime validation deliberately deferred to coordinating root agent'}
    (OUT/'qa.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps(report,ensure_ascii=False))
    if failures: raise SystemExit(1)


if __name__=='__main__':
    if (ROOT/'data/art/cave_enemy_imagemagick.json').exists():
        raise SystemExit('Legacy area sampler is superseded. Run tools/assets/convert_cave_imagemagick.py --magick <magick> --apply; see data/art/cave_enemy_imagemagick.json.')
    main()
