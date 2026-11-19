"""ImageMagick直接从RAW点采样洞穴敌怪：固定网格/锚点、共享16色、无抖动；同步0.75倍逐帧时长。"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFont
import numpy as np
from sprite_frames_writer import write_frames

ROOT=Path(__file__).resolve().parents[2]
RECIPE=ROOT/'data/art/cave_enemy_imagemagick.json'
TOOL_VERSION='imagemagick-point-v2'


def run(binary,arguments):
    environment={**os.environ,'MAGICK_THREAD_LIMIT':'1','MAGICK_OCL_DEVICE':'OFF'}
    result=subprocess.run([str(binary),*map(str,arguments)],capture_output=True,text=True,env=environment,check=True)
    return result.stdout.strip()


def geometry(rect):
    x,y,right,bottom=rect
    return f'{right-x}x{bottom-y}{x:+d}{y:+d}'


def palette_file(colors,path):
    """数值色板仅作为ImageMagick的remap输入，不进行图像采样。"""
    image=Image.new('RGB',(len(colors),1))
    image.putdata([tuple(bytes.fromhex(color[1:])) for color in colors])
    image.save(path)


def convert_frame(binary,frame,palette,destination,config):
    """所有剪裁、点采样、限色、alpha阈值和固定位置合成都由magick执行。"""
    destination.parent.mkdir(parents=True,exist_ok=True)
    w,h=frame['canvas_pixels'];sample=frame['sampled_pixels'];x,y=frame['offset']
    arguments=['-limit','thread','1','-size',f'{w}x{h}','xc:none','(',ROOT/frame['source'],
               '-alpha','on','-channel','A','-threshold',str(config['alpha_source_threshold_percent'])+'%','+channel',
               '-crop',geometry(frame['source_rect']),'+repage','-crop',geometry(frame['crop']),'+repage',
               '-filter','point','-sample',f'{sample[0]}x{sample[1]}!',
               '-channel','A','-threshold',str(config['alpha_output_threshold_percent'])+'%','+channel',
               '(','+clone','-alpha','extract','-write','mpr:alpha','+delete',')',
               '-alpha','off','+dither','-remap',palette,'mpr:alpha','-alpha','off',
               '-compose','CopyAlpha','-composite',')',
               '-geometry',f'{x:+d}{y:+d}','-compose','Over','-composite','-depth','8',
               '-strip','-define','png:exclude-chunks=all','-define','png:color-type=6','PNG32:'+str(destination)]
    run(binary,arguments)
    return list(map(str,arguments))


def write_gif(binary,frames,path,fps,scale):
    """GIF只作检视，逐帧分配厘秒误差，循环总时长按新fps取最近可表达值。"""
    command=['-limit','thread','1','-dispose','Background','-loop','0','+dither']
    for index,frame in enumerate(frames):
        delay=round((index+1)*100/fps)-round(index*100/fps)
        command+=['(','-delay',str(delay),ROOT/frame[6:],'-sample',f'{scale*100}%',')']
    command.append(path)
    run(binary,command)


def refresh_contact_sheets(package):
    """检视拼图用已转换的帧排版，整数nearest放大不作为运行资源。"""
    folder=ROOT/package['folder'];rows=[]
    font_path=Path('C:/Windows/Fonts/msyh.ttc')
    font=ImageFont.truetype(str(font_path),16) if font_path.exists() else ImageFont.load_default(size=16)
    for entity in package['entities']:
        w,h=entity['canvas']
        sheet=Image.new('RGBA',(w*6,h*len(entity['actions'])),(17,21,33,255))
        for row,action in enumerate(entity['actions']):
            for col,path in enumerate(action['frames']):
                im=Image.open(ROOT/path[6:]).convert('RGBA')
                sheet.alpha_composite(im,(col*w,row*h));rows.append((entity['name'],action['id'],col,im))
        if 'CAVE-BEASTS' in package['folder']:
            target=folder/('effects/'+entity['id'] if len(entity['actions'])==1 else entity['id'])/'contact_sheet.png'
            sheet.save(target)
    if 'CAVE-BONE' in package['folder']:
        actions=[(entity,action) for entity in package['entities'] for action in entity['actions']]
        board=Image.new('RGB',(1536,44+len(actions)*230),'#111521');draw=ImageDraw.Draw(board)
        draw.text((12,12),'ImageMagick / 16色 / 固定原生画布 / 动画速度0.75×',font=font,fill='#dce5ed')
        for row,(entity,action) in enumerate(actions):
            y=44+row*230
            draw.text((12,y),entity['name']+' / '+action['id'],font=font,fill='#a5b7cd')
            for col,path in enumerate(action['frames']):
                im=Image.open(ROOT/path[6:]).convert('RGBA');im=im.crop(im.getbbox())
                im=im.resize((im.width*2,im.height*2),Image.Resampling.NEAREST)
                board.paste(im,(12+col*256,y+216-im.height),im)
        board.save(folder/'contact_sheet.png')
    else:
        entities=[e for e in package['entities'] if len(e['actions'])>1]
        board=Image.new('RGB',(1480,44+220*len(entities)),'#111521');draw=ImageDraw.Draw(board)
        draw.text((12,12),'ImageMagick点采样 / 16色 / 原生1:1 / 动画0.75×',font=font,fill='#dce5ed')
        for row,entity in enumerate(entities):
            y=44+220*row;draw.text((12,y+24),entity['name'],font=font,fill='#dce5ed')
            selected=[a for a in entity['actions'] if a['id']!='move']
            for col,action in enumerate(selected):
                index=0 if action['id']=='idle' else 3
                im=Image.open(ROOT/action['frames'][index][6:]).convert('RGBA');im=im.crop(im.getbbox())
                im=im.resize((im.width*2,im.height*2),Image.Resampling.NEAREST)
                x=220+col*310;board.paste(im,(x,y+180-im.height),im)
                draw.text((x,y+185),action['id'],font=font,fill='#9cadc3')
        board.save(folder/'overview.png')


def apply_conversion(binary,stage,config,report):
    """完整批次通过数值和可见性校验后替换；速度始终从不可变base_fps计算，重跑不会重复减速。"""
    actual={record['id']:record for record in report['conversions']}
    expected={frame['id'] for package in config['packages'].values() for frame in package['frames']}
    if set(actual)!=expected:
        raise ValueError('Only the complete registered 184-frame batch may replace runtime art')
    for package in config['packages'].values():
        allowed={tuple(bytes.fromhex(v[1:])) for v in package['palette']}
        for frame in package['frames']:
            im=Image.open(actual[frame['id']]['stage_output']).convert('RGBA');a=np.array(im)
            colors={tuple(v) for v in np.unique(a[:,:,:3][a[:,:,3]>0],axis=0)}
            if list(im.size)!=frame['canvas_pixels'] or not colors<=allowed or not set(np.unique(a[:,:,3]))<={0,255} or im.getbbox() is None:
                raise ValueError('Invalid staged pixel frame: '+frame['id'])
        for entity in package['entities']:
            for action in entity['actions']:
                hashes=[hashlib.sha256(Image.open(actual[next(f['id'] for f in package['frames'] if f['output']==path)]['stage_output']).convert('RGBA').tobytes()).hexdigest() for path in action['frames']]
                if len(set(hashes))<min(4,len(hashes)):
                    raise ValueError('Animation lost its distinct poses: '+entity['id']+'/'+action['id'])
    multiplier=config['speed_multiplier'];changes=[]
    for batch,package in config['packages'].items():
        folder=ROOT/package['folder']
        for frame in package['frames']:
            shutil.copy2(actual[frame['id']]['stage_output'],ROOT/frame['output'][6:])
        timing={tuple(action['frames']):action for entity in package['entities'] for action in entity['actions']}
        def update(value):
            if isinstance(value,dict):
                if 'fps' in value and 'frames' in value and isinstance(value['frames'],list) and tuple(value['frames']) in timing:
                    action=timing[tuple(value['frames'])]
                    value['base_fps']=action['base_fps'];value['fps']=action['base_fps']*multiplier
                    value['speed_multiplier']=multiplier
                    value['duration_seconds']=len(action['frames'])/value['fps']
                    if 'sha256' in value:value['sha256']=[hashlib.sha256(Image.open(ROOT/p[6:]).convert('RGBA').tobytes()).hexdigest() for p in value['frames']]
                    if 'visible_rects' in value:value['visible_rects']=[list(Image.open(ROOT/p[6:]).getbbox()) for p in value['frames']]
                    if 'unique_frames' in value:value['unique_frames']=len(set(hashlib.sha256(Image.open(ROOT/p[6:]).convert('RGBA').tobytes()).hexdigest() for p in value['frames']))
                for key,item in value.items():
                    if key=='palette' and isinstance(item,list):value[key]=package['palette']
                    else:update(item)
            elif isinstance(value,list):
                for item in value:update(item)
        for path in folder.rglob('catalog.json'):
            catalog=json.loads(path.read_text(encoding='utf8'));update(catalog)
            catalog['pixel_conversion']='res://data/art/cave_enemy_imagemagick.json'
            catalog['art_revision']='imagemagick_v002'
            catalog['processing']='ImageMagick point sampling from RAW; no dithering; shared 16-color palette; fixed native canvas and anchor'
            if 'generation' in catalog:catalog['generation']='Source: built-in imagegen. Runtime conversion: ImageMagick point sampling, hard alpha, no averaging.'
            path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
        for entity in package['entities']:
            animations={}
            combined=[]
            for action in entity['actions']:
                fps=action['base_fps']*multiplier
                animations[action['id']]={'frames':action['frames'],'fps':fps,'loop':action['loop']}
                changes.append({'entity':entity['id'],'action':action['id'],'base_fps':action['base_fps'],'fps':fps,
                                'old_seconds':len(action['frames'])/action['base_fps'],'new_seconds':len(action['frames'])/fps})
                if batch=='CAVE-BONE':
                    gif=folder/('projectiles/arrow/fly.gif' if entity['id']=='bone_arrow' else entity['id']+'/'+action['id']+'.gif')
                    if entity['id']!='bone_arrow':
                        sheet=folder/entity['id']/(action['id']+'.png')
                        run(binary,[*[ROOT/f[6:] for f in action['frames']],'+append','-strip','-define','png:exclude-chunks=all','PNG32:'+str(sheet)])
                else:
                    gif=folder/('effects/'+entity['id']+'/preview.gif' if len(entity['actions'])==1 else entity['id']+'/'+action['id']+'.gif')
                write_gif(binary,action['frames'],gif,fps,config['preview_integer_scale'])
                combined.extend(action['frames'])
            write_frames(ROOT/entity['sprite_frames'][6:],animations)
            if batch=='CAVE-BONE' and entity['id']!='bone_arrow':
                # 合集使用各动作本身的逐帧时长，保持与单独GIF和引擎一致。
                command=['-limit','thread','1','-dispose','Background','-loop','0','+dither']
                for action in entity['actions']:
                    fps=action['base_fps']*multiplier
                    for index,path in enumerate(action['frames']):
                        delay=round((index+1)*100/fps)-round(index*100/fps)
                        command+=['(','-delay',str(delay),ROOT/path[6:],'-sample',f'{config["preview_integer_scale"]*100}%',')']
                run(binary,[*command,folder/entity['id']/'all_actions.gif'])
        spec_path=folder/'pixel_spec_runtime.json'
        spec=json.loads(spec_path.read_text(encoding='utf8'));spec.update({'palette':package['palette'],'max_colors':len(package['palette']),
            'conversion_report':'res://'+(folder/'pixel_conversion.json').relative_to(ROOT).as_posix(),
            'sampling':'ImageMagick point sampling from RAW, no averaging, no dithering',
            'art_revision':'imagemagick_v002'})
        spec_path.write_text(json.dumps(spec,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
        if (folder/'pixel_spec.json').exists():
            extra=json.loads((folder/'pixel_spec.json').read_text(encoding='utf8'))
            extra.update({'palette':package['palette'],'max_colors':len(package['palette']),'effective_animation_multiplier':multiplier,
                          'active_recipe':'res://data/art/cave_enemy_imagemagick.json'})
            for entity in package['entities']:
                rows=extra.get('variants',{}).get(entity['id'],{}).get('actions',[])
                for action in rows:
                    base=next(a['base_fps'] for a in entity['actions'] if a['id']==action['id'])
                    action.update({'base_fps':base,'fps':base*multiplier})
            (folder/'pixel_spec.json').write_text(json.dumps(extra,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
        package_report={key:value for key,value in report.items() if key!='conversions'}
        package_report['conversions']=[actual[frame['id']] for frame in package['frames']]
        for record in package_report['conversions']:record.pop('stage_output',None)
        (folder/'pixel_conversion.json').write_text(json.dumps(package_report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
        for entity in package['entities']:
            conversion=folder/entity['id']/'conversion.json'
            if conversion.exists():
                conversion.write_text(json.dumps([r for r in package_report['conversions'] if r['entity']==entity['id']],ensure_ascii=False,indent=2)+'\n',encoding='utf8')
        refresh_contact_sheets(package)
    definition=ROOT/'data/enemy_designs/cave_v001.json'
    catalog=json.loads(definition.read_text(encoding='utf8'))
    all_actions={tuple(action['frames']):action for package in config['packages'].values() for entity in package['entities'] for action in entity['actions']}
    for entity in catalog['enemies']+catalog['effects']:
        for action in entity['actions']:
            base=all_actions[tuple(action['frames'])]['base_fps']
            action.update({'base_fps':base,'fps':base*multiplier,'speed_multiplier':multiplier,'duration_seconds':len(action['frames'])/(base*multiplier)})
    catalog['animation_speed_multiplier']=multiplier
    catalog['art_revision']='imagemagick_v002'
    definition.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    (stage/'speed_changes.json').write_text(json.dumps(changes,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(f'APPLIED: {len(expected)} ImageMagick frames / {len(changes)} animations at {multiplier}x',flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--magick',type=Path,required=True)
    parser.add_argument('--stage',type=Path,default=ROOT/'work/cave_imagemagick_v002')
    parser.add_argument('--trial',action='store_true')
    parser.add_argument('--full-palette',action='store_true')
    parser.add_argument('--apply',action='store_true')
    args=parser.parse_args()
    config=json.loads(RECIPE.read_text(encoding='utf8'));args.magick=args.magick.resolve()
    if args.apply and (args.trial or args.full_palette):parser.error('--apply requires the full approved palette batch')
    stage=args.stage.resolve();stage.mkdir(parents=True,exist_ok=True)
    version=run(args.magick,['-version']).splitlines()[0]
    report={'tool':'tools/assets/convert_cave_imagemagick.py','tool_version':TOOL_VERSION,
            'imagemagick_version':version,'imagemagick_sha256':hashlib.sha256(args.magick.read_bytes()).hexdigest(),
            'recipe':'res://data/art/cave_enemy_imagemagick.json','conversions':[]}
    for batch,package in config['packages'].items():
        colors=package['palette']
        if args.full_palette:
            old=json.loads((ROOT/'backup/2026-11-17_cave_before_imagemagick'/package['folder']/'pixel_spec_runtime.json').read_text(encoding='utf8'))
            colors=old['palette']
        palette=stage/(batch+'_palette.png');palette_file(colors,palette)
        selected=package['frames']
        if args.trial:
            selected=[f for f in selected if f['entity'] in ['bone_dragon_blade','cave_spider','cavern_hunter'] and f['action']=='idle' and f['index']==0]
        for frame in selected:
            source=ROOT/frame['source']
            if hashlib.sha256(source.read_bytes()).hexdigest()!=frame['source_sha256']:
                raise ValueError(f'Source changed; recalibrate numeric recipe first: {source}')
            destination=stage/Path(frame['output'][6:]).relative_to(package['folder'])
            destination=stage/batch/destination.relative_to(stage)
            command=convert_frame(args.magick,frame,palette,destination,config)
            stripe_record=None
            if frame['entity']=='cave_spider':
                from apply_cave_spider_stripes import apply_one
                stripe_record=apply_one(args.magick,f'{frame["action"]}/{frame["index"]:02d}',destination,destination,stage/'spider_masks')
            report['conversions'].append({**frame,'canvas_pixels':frame['canvas_pixels'],'resampling_passes':1,
                'runtime_scale':[1,1],'sampling':'ImageMagick_point_sample_no_dither_shared_palette',
                'palette_limit':len(colors),'stage_output':str(destination),'command':command,
                'output_sha256':hashlib.sha256(destination.read_bytes()).hexdigest(),
                'rgba_sha256':hashlib.sha256(Image.open(destination).convert('RGBA').tobytes()).hexdigest()})
            if stripe_record is not None:report['conversions'][-1]['native_stripe_overlay']=stripe_record
        print(f'IMAGEMAGICK {batch}: {len(selected)} actual RAW conversions / {len(colors)} shared colors',flush=True)
    (stage/'conversion.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    if args.apply:apply_conversion(args.magick,stage,config,report)


if __name__=='__main__':main()
