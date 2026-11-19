"""骨龙三型母版转原生逐帧：公共身体尺度、固定足底注册、单次像素网格转换。"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from pixel_grid import convert

ROOT=Path(__file__).resolve().parents[2]
RAW=ROOT/'assets/RAW/enemies/CAVE-BONE/v001'
OUT=ROOT/'assets/PROCESSED/enemies/CAVE-BONE/v001'
SPEC=json.loads((RAW/'pixel_spec.json').read_text(encoding='utf8'))


def rgba_cell(source,col,row,cols,rows):
    rect=(round(col*source.width/cols),round(row*source.height/rows),round((col+1)*source.width/cols),round((row+1)*source.height/rows))
    im=source.crop(rect).convert('RGBA')
    a=np.array(im)
    a[a[:,:,3]<SPEC['alpha_cutoff']]=0
    return Image.fromarray(a),rect


def visible_box(im):
    bbox=im.getbbox()
    if bbox is None:
        raise ValueError('Empty source frame')
    return bbox


def shared_body_scale(source,variant):
    """只按闲置身体高度定整张动作表的共同尺度，不按攻击外伸武器包围盒缩放。"""
    heights=[];roots=[]
    for col in range(variant['columns']):
        im,_=rgba_cell(source,col,0,variant['columns'],variant['rows'])
        a=np.array(im);bbox=visible_box(im)
        heights.append(bbox[3]-bbox[1])
        # 脚底的象牙色像素确定共同根点，排除斜持的枪柄或刀刃。
        band_start=round(bbox[3]-(bbox[3]-bbox[1])*0.15)
        mask=(a[:,:,3]>0)&(a[:,:,0]>150)&(a[:,:,1]>125)&(a[:,:,2]>90)&(a[:,:,0].astype(float)>a[:,:,2]*1.05)
        mask[:band_start,:]=False
        ys,xs=np.where(mask)
        roots.append((min(xs)+max(xs))/2 if len(xs) else (bbox[0]+bbox[2])/2)
    median=float(np.median(heights))
    return SPEC['native_body_height']/median,float(np.median(roots)),heights


def remove_specks(im):
    """限色后的机械去噪，不重画姿势；只清除小于2像素的游离碎点。"""
    a=np.array(im);mask=a[:,:,3]>0;seen=np.zeros(mask.shape,bool)
    for y,x in np.argwhere(mask):
        if seen[y,x]:continue
        stack=[(int(x),int(y))];seen[y,x]=True;group=[]
        while stack:
            xx,yy=stack.pop();group.append((xx,yy))
            for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)]:
                nx,ny=xx+dx,yy+dy
                if 0<=nx<im.width and 0<=ny<im.height and mask[ny,nx] and not seen[ny,nx]:
                    seen[ny,nx]=True;stack.append((nx,ny))
        if len(group)<2:
            for xx,yy in group:a[yy,xx]=0
    return Image.fromarray(a)


def write_spriteframes(identifier,actions):
    lines=['[gd_resource type="SpriteFrames" load_steps=%d format=3]'%(1+sum(len(a['frames']) for a in actions)),'']
    textures=[]
    for action in actions:
        ids=[]
        for path in action['frames']:
            tid=f'T_{len(textures)+1}'
            textures.append((tid,path));ids.append(tid)
        action['_texture_ids']=ids
    for tid,path in textures:
        lines.append(f'[ext_resource type="Texture2D" path="{path}" id="{tid}"]')
    lines.extend(['','[resource]','animations = [{'])
    chunks=[]
    for action in actions:
        frame=', '.join('{"duration": 1.0, "texture": ExtResource("'+tid+'")} ' for tid in action.pop('_texture_ids'))
        chunks.append('"frames": ['+frame+'],\n"loop": '+str(action['loop']).lower()+',\n"name": &"'+action['id']+'",\n"speed": '+str(float(action['fps'])))
    lines.append('}, {\n'.join(chunks));lines.append('}]')
    path=OUT/'godot'/f'{identifier}.tres';path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text('\n'.join(lines)+'\n',encoding='utf8')
    return 'res://'+path.relative_to(ROOT).as_posix()


def animation_gif(frames,path,fps):
    background=Image.new('RGB',frames[0].size,'#17202b')
    display=[]
    for frame in frames:
        im=background.copy();im.paste(frame,(0,0),frame)
        display.append(im.resize((im.width*4,im.height*4),Image.Resampling.NEAREST))
    display[0].save(path,save_all=True,append_images=display[1:],duration=round(1000/fps),loop=0,disposal=2)


def build_variant(identifier,variant):
    source=Image.open(RAW/variant['source']).convert('RGBA')
    scale,root_x,idle_heights=shared_body_scale(source,variant)
    result={'id':identifier,'name':variant['name'],'canvas':variant['canvas'],'root':SPEC['root'],'world_scale':[1,1],
            'direction':'right','native_body_height':SPEC['native_body_height'],'base_stats':SPEC['base_stats'],'actions':[]}
    conversion=[];previews=[];combined=[]
    for action in variant['actions']:
        frames=[];paths=[];checks=[]
        for col in range(variant['columns']):
            cell,source_rect=rgba_cell(source,col,action['row'],variant['columns'],variant['rows'])
            bbox=visible_box(cell)
            target=(max(1,round((bbox[2]-bbox[0])*scale)),max(1,round((bbox[3]-bbox[1])*scale)))
            native,report=convert(cell,target,SPEC['palette'],alpha_cutoff=SPEC['alpha_cutoff'],visible_size=target)
            native=remove_specks(native)
            canvas=Image.new('RGBA',tuple(variant['canvas']))
            offset=(round(SPEC['root'][0]+(bbox[0]-root_x)*scale),SPEC['root'][1]-target[1])
            if offset[0]<0 or offset[1]<0 or offset[0]+target[0]>canvas.width or offset[1]+target[1]>canvas.height:
                raise ValueError(f'Clipped frame: {identifier}:{action["id"]}:{col} {offset} {target}')
            canvas.alpha_composite(native,offset)
            folder=OUT/identifier/'frames'/action['id'];folder.mkdir(parents=True,exist_ok=True)
            path=folder/f'{col:02d}.png';canvas.save(path)
            relative='res://'+path.relative_to(ROOT).as_posix();paths.append(relative);frames.append(canvas)
            digest=hashlib.sha256(canvas.tobytes()).hexdigest();checks.append(digest)
            conversion.append({'action':action['id'],'frame':col,'source_rect':list(source_rect),'common_body_scale':scale,'common_source_root_x':root_x,
                               'native_registration':list(offset),'canvas_pixels':variant['canvas'],**{k:v for k,v in report.items() if k!='canvas_pixels'}})
        if len(set(checks))<4:
            raise ValueError(f'Insufficient distinct poses: {identifier}:{action["id"]}')
        sheet=Image.new('RGBA',(variant['canvas'][0]*len(frames),variant['canvas'][1]))
        for index,frame in enumerate(frames):sheet.alpha_composite(frame,(index*frame.width,0))
        sheet_path=OUT/identifier/f'{action["id"]}.png';sheet.save(sheet_path)
        gif=OUT/identifier/f'{action["id"]}.gif';animation_gif(frames,gif,action['fps'])
        item={'id':action['id'],'frames':paths,'frame_count':len(frames),'fps':action['fps'],'loop':action['loop'],'anchor':SPEC['root'],
              'canvas':variant['canvas'],'sheet':'res://'+sheet_path.relative_to(ROOT).as_posix(),'gif':'res://'+gif.relative_to(ROOT).as_posix(),'unique_frames':len(set(checks))}
        result['actions'].append(item);previews.append((identifier,action['id'],frames))
        for frame in frames:
            display=Image.new('RGB',(frame.width*4,frame.height*4+32),'#17202b')
            enlarged=frame.resize((frame.width*4,frame.height*4),Image.Resampling.NEAREST)
            display.paste(enlarged,(0,32),enlarged)
            ImageDraw.Draw(display).text((8,8),action['id'],fill='#d2dfdf')
            combined.append(display)
    result['sprite_frames']=write_spriteframes(identifier,result['actions'])
    result['source_pixel_measurement']={'idle_visible_source_heights':idle_heights,'common_scale':scale,'body_height_basis':'median idle silhouette; weapon reach never determines body scale'}
    combined[0].save(OUT/identifier/'all_actions.gif',save_all=True,append_images=combined[1:],duration=130,loop=0,disposal=2)
    return result,conversion,previews


def build_arrow():
    cfg=SPEC['projectiles']['arrow'];source=Image.open(RAW/cfg['source']).convert('RGBA')
    frames=[];paths=[];reports=[]
    for col in range(cfg['columns']):
        cell,rect=rgba_cell(source,col,0,cfg['columns'],cfg['rows'])
        native,report=convert(cell,cfg['visible_size'],SPEC['palette'],alpha_cutoff=SPEC['alpha_cutoff'],visible_size=cfg['visible_size'])
        canvas=Image.new('RGBA',tuple(cfg['canvas']));canvas.alpha_composite(native,((canvas.width-native.width)//2,(canvas.height-native.height)//2))
        path=OUT/'projectiles/arrow/frames'/f'{col:02d}.png';path.parent.mkdir(parents=True,exist_ok=True);canvas.save(path)
        paths.append('res://'+path.relative_to(ROOT).as_posix());frames.append(canvas)
        reports.append({'id':'arrow','frame':col,'source_rect':list(rect),'final_canvas':cfg['canvas'],**report})
    action={'id':'fly','frames':paths,'fps':cfg['fps'],'loop':True,'frame_count':4}
    resource=write_spriteframes('bone_arrow',[action])
    animation_gif(frames,OUT/'projectiles/arrow/fly.gif',cfg['fps'])
    return {'id':'bone_arrow','canvas':cfg['canvas'],'root':cfg['anchor'],'world_scale':[1,1],'sprite_frames':resource,'actions':[action]},reports,[('bone_arrow','fly',frames)]


def board(previews):
    row_h=120;image=Image.new('RGB',(1280,48+len(previews)*row_h),'#101721');draw=ImageDraw.Draw(image)
    font=ImageFont.load_default(size=16)
    draw.text((16,12),'CAVE BONE / native 42px body / 32-color / 1:1 / each action six distinct poses',font=font,fill='#d5dfdf')
    for index,(identifier,action,frames) in enumerate(previews):
        y=48+index*row_h;draw.text((16,y+3),identifier+' / '+action,font=font,fill='#a2bfca')
        for col,frame in enumerate(frames):
            # 原生图与2x最近邻图均只用于查看；运行帧仍保持原生文件。
            visible=frame.crop(frame.getbbox())
            display=visible.resize((visible.width*2,visible.height*2),Image.Resampling.NEAREST)
            image.paste(display,(290+col*160,y+112-display.height),display)
    image.save(OUT/'contact_sheet.png')


def validate(catalog):
    allowed={tuple(bytes.fromhex(c[1:])) for c in SPEC['palette']};count=0
    for entry in catalog['enemies']+catalog['projectiles']:
        for action in entry['actions']:
            for path in action['frames']:
                im=Image.open(ROOT/path[6:]).convert('RGBA');a=np.array(im);visible=a[:,:,3]>0
                assert list(im.size)==entry['canvas'],path
                assert set(np.unique(a[:,:,3]))<={0,255},path
                assert {tuple(x) for x in np.unique(a[:,:,:3][visible],axis=0)}<=allowed,path
                count+=1
    return count


def write_pixel_manifests(catalog,conversion):
    """补齐通用像素门禁清单；最终画布和采样画布分别登记，保留原始转换过程。"""
    assets={};canvases={};normalized=[];index=0
    for entry in catalog['enemies']+catalog['projectiles']:
        for action in entry['actions']:
            for frame,path in enumerate(action['frames']):
                identifier=f'{entry["id"]}_{action["id"]}_{frame:02d}'
                assets[identifier]={'path':path,'kind':'projectile_frame' if entry['id']=='bone_arrow' else 'enemy_frame',
                                    'native_canvas':entry['canvas'],'runtime_scale':entry['world_scale']}
                canvases[identifier]=entry['canvas']
                original=dict(conversion[index]);index+=1
                original['id']=identifier
                if original['canvas_pixels']!=entry['canvas']:
                    original['sampled_canvas_pixels']=original['canvas_pixels']
                    original['canvas_pixels']=entry['canvas']
                normalized.append(original)
    if index!=len(conversion):
        raise ValueError('Pixel records and native frames are not one-to-one')
    manifest={'id':'cave_bone_v001','pixel_standard':'res://data/art/pixel_standards.json',
              'pixel_spec':'res://'+(OUT/'pixel_spec_runtime.json').relative_to(ROOT).as_posix(),'assets':assets}
    runtime={'palette':SPEC['palette'],'max_colors':32,'sprite_canvases':canvases,
             'conversion_report':'res://'+(OUT/'pixel_conversion.json').relative_to(ROOT).as_posix(),
             'native_body_height':SPEC['native_body_height'],'body_anchor':SPEC['root'],
             'scale_policy':'shared per-sheet scale measured only on idle body; weapon reach never affects body scale'}
    for name,data in [('pixel_manifest.json',manifest),('pixel_spec_runtime.json',runtime),
                      ('pixel_conversion.json',{'tool':'tools/assets/pixel_grid.py','conversions':normalized,'tool_version':'native-grid-v1'})]:
        (OUT/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'pixel_spec.json').write_text(json.dumps(SPEC,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    catalog={'batch':'CAVE-BONE','version':'v001','format':'native-cave-enemy-art','palette':SPEC['palette'],'pixel_spec':'res://'+(OUT/'pixel_spec.json').relative_to(ROOT).as_posix(),
             'generation_mode':'built-in-image_gen','direction':'right','enemies':[],'projectiles':[],'note':'Art-only preparation; stats remain null. No combat balance or game world registration.'}
    conversion=[];previews=[]
    for identifier,variant in SPEC['variants'].items():
        entry,reports,pics=build_variant(identifier,variant)
        catalog['enemies'].append(entry);conversion+=reports;previews+=pics
    arrow,reports,pics=build_arrow();catalog['projectiles'].append(arrow);conversion+=reports;previews+=pics
    board(previews)
    (OUT/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    write_pixel_manifests(catalog,conversion)
    count=validate(catalog)
    (OUT/'qa.json').write_text(json.dumps({'images':count,'max_colors':32,'alpha':[0,255],'world_scale':[1,1],'errors':0,'frame_pose_check':'all enemy actions >=4 unique native frames'},indent=2)+'\n',encoding='utf8')
    print(f'CAVE BONE ART: {count} native frames / 3 variants / 11 body actions / 1 arrow action / 32 colors / 0 errors')


if __name__=='__main__':
    if (ROOT/'data/art/cave_enemy_imagemagick.json').exists():
        raise SystemExit('Legacy area sampler is superseded. Run tools/assets/convert_cave_imagemagick.py --magick <magick> --apply; see data/art/cave_enemy_imagemagick.json.')
    main()
