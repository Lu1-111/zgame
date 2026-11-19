"""将原生像素条纹叠到未加纹ImageMagick蜘蛛帧；不缩放、不改alpha/轮廓/动作/帧率，可安全重跑。"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import shutil
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from convert_cave_imagemagick import run, convert_frame, palette_file

ROOT=Path(__file__).resolve().parents[2]
RAW=ROOT/'assets/RAW/enemies/CAVE-BEASTS/v001/spider_stripes'
RULES=RAW/'masks.json'
LIVE=ROOT/'assets/PROCESSED/enemies/CAVE-BEASTS/v001/cave_spider'
DEFAULT_STAGE=ROOT/'work/spider_stripes'
RECIPE=ROOT/'data/art/cave_enemy_imagemagick.json'
TOOL_VERSION='spider-native-stripes-v1'


def rgba_sha(path):
    return hashlib.sha256(Image.open(path).convert('RGBA').tobytes()).hexdigest()


def recipe():
    cfg=json.loads(RECIPE.read_text(encoding='utf8'))
    package=cfg['packages']['CAVE-BEASTS']
    spider=next(e for e in package['entities'] if e['id']=='cave_spider')
    return cfg,package,spider


def load_rules():
    rules=json.loads(RULES.read_text(encoding='utf8'))
    cfg,package,spider=recipe()
    if package['palette']!=rules['palette'] or spider['canvas']!=rules['canvas'] or spider['anchor']!=rules['anchor']:
        raise ValueError('Spider palette/canvas/anchor changed; manually recalibrate stripe masks')
    if cfg['speed_multiplier']!=rules['speed_multiplier']:
        raise ValueError('Animation speed policy changed')
    return rules


def command_points(points):
    return ' '.join(f'{round(x)},{round(y)}' for x,y in points)


def abdomen_points(points,frame):
    left,top,right,bottom=frame['abdomen_rect']
    center=((left+right)/2,(top+bottom)/2)
    angle=math.radians(frame.get('abdomen_angle_deg',0))
    output=[]
    for x,y in points:
        xx=left+x*(right-left);yy=top+y*(bottom-top)
        dx,dy=xx-center[0],yy-center[1]
        output.append((center[0]+dx*math.cos(angle)-dy*math.sin(angle),center[1]+dx*math.sin(angle)+dy*math.cos(angle)))
    return output


def apply_one(binary,key,source,destination,stage,rules=None):
    """给RAW点采样后的单帧加纹，适合在convert_frame后、计算输出hash前挂接；输入必须未加纹。"""
    rules=rules or load_rules()
    frame=rules['frames'][key]
    source=Path(source);destination=Path(destination);stage=Path(stage)
    stage.mkdir(parents=True,exist_ok=True)
    before=np.array(Image.open(source).convert('RGBA'))
    if list(Image.fromarray(before).size)!=rules['canvas']:
        raise ValueError(f'{key}: native frame dimensions changed')
    expected=frame.get('unstriped_rgba_sha256')
    if expected and hashlib.sha256(before.tobytes()).hexdigest()!=expected:
        raise ValueError(f'{key}: input is not the registered unstriped ImageMagick frame; refusing cumulative stripes')
    w,h=rules['canvas'];tag=key.replace('/','_')
    candidate=stage/(tag+'_candidate.png')
    eligible=stage/(tag+'_eligible.png')
    inner=stage/(tag+'_inner.png')
    mask=stage/(tag+'_mask.png')
    draw=['-size',f'{w}x{h}','xc:black','+antialias','-fill','none','-stroke','white','-strokewidth',str(rules['body_stroke'])]
    for points in rules['abdomen_polylines']:
        draw+=['-draw','polyline '+command_points(abdomen_points(points,frame))]
    draw+=['-strokewidth',str(rules['cap_stroke']),'-draw','polyline '+command_points(frame['cap_line'])]
    draw+=['-strokewidth',str(rules['leg_stroke'])]
    for points in frame['leg_bands']:
        draw+=['-draw','polyline '+command_points(points)]
    run(binary,[*draw,'-threshold','50%','-alpha','off','-depth','8',candidate])
    colors=[source,'-alpha','off','-fuzz','0%','-fill','white']
    for color in rules['eligible_colors']: colors+=['-opaque',color]
    run(binary,[*colors,'-fill','black','+opaque','white','-depth','8',eligible])
    run(binary,[source,'-alpha','extract','-morphology','Erode',f'Diamond:{rules["preserve_boundary_radius"]}','-depth','8',inner])
    run(binary,[candidate,'-alpha','off',eligible,'-alpha','off','-compose','Multiply','-composite',inner,'-alpha','off',
                '-compose','Multiply','-composite','-threshold','50%','-alpha','off','-depth','8',mask])
    destination.parent.mkdir(parents=True,exist_ok=True)
    temporary=stage/(tag+'_striped.png')
    run(binary,[source,'(','-size',f'{w}x{h}','xc:'+rules['stripe_color'],mask,'-alpha','off','-compose','CopyAlpha','-composite',')',
                '-compose','Over','-composite','-depth','8','-strip','-define','png:exclude-chunks=all','-define','png:color-type=6','PNG32:'+str(temporary)])
    after=np.array(Image.open(temporary).convert('RGBA'))
    result=validate_frame(key,before,after,rules)
    if result['failures']: raise ValueError(json.dumps(result,ensure_ascii=False))
    shutil.copy2(temporary,destination)
    canonical=RAW/'compiled_masks'/key
    canonical=canonical.with_suffix('.png');canonical.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(mask,canonical)
    return {**result,'mask':canonical.relative_to(ROOT).as_posix(),'source_rgba_sha256':hashlib.sha256(before.tobytes()).hexdigest(),
            'output_rgba_sha256':hashlib.sha256(after.tobytes()).hexdigest(),'native_canvas':rules['canvas'],'anchor':rules['anchor'],
            'sampling_passes':0,'postprocess':'ImageMagick native integer-pixel chevron/leg-band mask; no resampling',
            'tool_version':TOOL_VERSION,'palette':rules['palette']}


def validate_frame(key,before,after,rules):
    failures=[]
    visible=before[:,:,3]>0
    padded=np.pad(visible,1,constant_values=False)
    inner=visible & padded[:-2,1:-1] & padded[2:,1:-1] & padded[1:-1,:-2] & padded[1:-1,2:]
    boundary=visible & ~inner
    changed=np.any(before[:,:,:3]!=after[:,:,:3],axis=2)
    before_colors={tuple(x) for x in before[visible][:,:3]}
    after_colors={tuple(x) for x in after[visible][:,:3]}
    if before.shape!=after.shape: failures.append('canvas changed')
    if not np.array_equal(before[:,:,3],after[:,:,3]): failures.append('alpha changed')
    if not np.array_equal(before[:,:,:3][boundary],after[:,:,:3][boundary]): failures.append('outer contour RGB changed')
    if before_colors!=after_colors: failures.append('per-frame color set changed')
    if not after_colors<={tuple(bytes.fromhex(c[1:])) for c in rules['palette']}: failures.append('outside shared palette')
    if not set(np.unique(after[:,:,3]))<={0,255}: failures.append('non-binary alpha')
    count=int(changed.sum());area=int(visible.sum())
    if count<20 or count>area*0.18: failures.append('stripe coverage outside restrained readable range')
    if (changed & boundary).any(): failures.append('stripe touches silhouette')
    return {'frame':key,'changed_pixels':count,'visible_pixels':area,'coverage':count/area,
            'alpha_equal':bool(np.array_equal(before[:,:,3],after[:,:,3])),
            'outline_rgb_equal':bool(np.array_equal(before[:,:,:3][boundary],after[:,:,:3][boundary])),
            'before_color_count':len(before_colors),'after_color_count':len(after_colors),'failures':failures}


def source_frames(binary,stage):
    """每次直接按现行RAW→Point配方重建未加纹基线，不以已加纹输出作为输入。"""
    cfg,package,spider=recipe()
    folder=stage/'unstriped';folder.mkdir(parents=True,exist_ok=True)
    palette=stage/'shared16.png';palette_file(package['palette'],palette)
    for frame in package['frames']:
        if frame['entity']!='cave_spider': continue
        source=ROOT/frame['source']
        if hashlib.sha256(source.read_bytes()).hexdigest()!=frame['source_sha256']:
            raise ValueError('RAW source changed')
        destination=folder/frame['action']/f'{frame["index"]:02d}.png'
        convert_frame(binary,frame,palette,destination,cfg)
    return folder


def backup_live(stage):
    backup=stage/'before_original'
    if (backup/'manifest.json').exists(): return backup
    backup.mkdir(parents=True,exist_ok=True)
    (backup/'.gdignore').write_text('',encoding='utf8')
    files=list(LIVE.glob('frames/*/*.png'))+list(LIVE.glob('*.gif'))+[LIVE/'contact_sheet.png',LIVE/'sprite_frames.tres',LIVE/'catalog.json']
    records=[]
    for source in files:
        if not source.exists(): continue
        target=backup/source.relative_to(LIVE);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
        records.append({'original':source.relative_to(ROOT).as_posix(),'backup':target.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
    (backup/'manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    return backup


def previews(binary,before,after,output,spider,cfg):
    output.mkdir(parents=True,exist_ok=True)
    font_path=Path('C:/Windows/Fonts/msyh.ttc')
    font=ImageFont.truetype(str(font_path),16) if font_path.exists() else ImageFont.load_default(size=16)
    sheet=Image.new('RGBA',(128*6,96*4),(17,21,33,255))
    comparison=Image.new('RGBA',(256*6,122*4),(17,21,33,255));draw=ImageDraw.Draw(comparison)
    for row,action in enumerate(spider['actions']):
        key=action['id'];paths=[]
        for index in range(6):
            old=Image.open(before/key/f'{index:02d}.png').convert('RGBA');new=Image.open(after/key/f'{index:02d}.png').convert('RGBA')
            sheet.alpha_composite(new,(128*index,96*row))
            comparison.alpha_composite(old,(256*index,122*row+26));comparison.alpha_composite(new,(256*index+128,122*row+26))
            draw.text((256*index+4,122*row+4),f'{key} {index:02d}  前 / 后',font=font,fill='#c5ced0')
            paths.append(after/key/f'{index:02d}.png')
        fps=action['base_fps']*cfg['speed_multiplier']
        arguments=['-limit','thread','1','-dispose','Background','-loop','0','+dither']
        for index,path in enumerate(paths):
            delay=round((index+1)*100/fps)-round(index*100/fps)
            arguments+=['(','-delay',str(delay),path,'-sample','200%',')']
        run(binary,[*arguments,output/(key+'.gif')])
    sheet.save(output/'contact_sheet.png');comparison.save(output/'stripes_before_after_24.png')
    close=Image.new('RGBA',(1024,416),(17,21,33,255));d=ImageDraw.Draw(close)
    for column,(path,label) in enumerate([(before/'idle/00.png','原版'),(after/'idle/00.png','浅灰条纹')]):
        image=Image.open(path).convert('RGBA').resize((512,384),Image.Resampling.NEAREST)
        close.alpha_composite(image,(column*512,32));d.text((column*512+16,8),label+' · 4×nearest检视',font=font,fill='#c5ced0')
    close.save(output/'stripes_idle_comparison_4x.png')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--magick',type=Path,required=True)
    parser.add_argument('--stage',type=Path,default=DEFAULT_STAGE)
    parser.add_argument('--input-dir',type=Path,help='Optional already converted unstriped frames/<action>/<nn>.png; verified by registered RGBA hashes')
    parser.add_argument('--output-dir',type=Path,help='Optional destination frames folder for converter pipeline integration')
    parser.add_argument('--apply',action='store_true',help='Replace live 24 frames + spider-only PNG/GIF previews; never edits package metadata or SpriteFrames')
    parser.add_argument('--verify-live',action='store_true',help='Rebuild stripes from unstriped RAW-derived frames and require all live RGBA hashes to match')
    args=parser.parse_args();binary=args.magick.resolve();stage=args.stage.resolve();stage.mkdir(parents=True,exist_ok=True)
    rules=load_rules();cfg,package,spider=recipe()
    before=args.input_dir.resolve() if args.input_dir else source_frames(binary,stage)
    after=stage/'striped';records=[]
    protected={name:hashlib.sha256((LIVE/name).read_bytes()).hexdigest() for name in ['sprite_frames.tres','catalog.json']}
    for key in rules['frames']:
        records.append(apply_one(binary,key,before/(key+'.png'),after/(key+'.png'),stage/'masks',rules))
    previews(binary,before,after,stage/'previews',spider,cfg)
    if args.output_dir:
        destination=args.output_dir.resolve()
        for key in rules['frames']:
            target=destination/(key+'.png');target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(after/(key+'.png'),target)
    if args.apply:
        backup_live(stage)
        for key in rules['frames']: shutil.copy2(after/(key+'.png'),LIVE/'frames'/(key+'.png'))
        for source in (stage/'previews').iterdir(): shutil.copy2(source,LIVE/source.name)
    if args.verify_live:
        for key in rules['frames']:
            if rgba_sha(after/(key+'.png'))!=rgba_sha(LIVE/'frames'/(key+'.png')):
                raise ValueError(f'{key}: live frame differs from reproducible stripe output')
    if protected!={name:hashlib.sha256((LIVE/name).read_bytes()).hexdigest() for name in protected}:
        raise ValueError('Protected metadata/SpriteFrames unexpectedly changed')
    report={'id':rules['id'],'tool':str(Path(__file__).relative_to(ROOT)),'imagemagick':run(binary,['-version']).splitlines()[0],
            'canvas':rules['canvas'],'anchor':rules['anchor'],'palette_size':len(rules['palette']),'speed_multiplier':cfg['speed_multiplier'],
            'frames':records,'frame_count':len(records),'failures':[],'metadata_untouched':True,
            'source_policy':'unstriped ImageMagick Point frames only; reject already striped input hashes; default regenerates baseline from RAW',
            'backup':str(stage/'before_original') if (stage/'before_original').exists() else None,
            'live_rgba_verified':bool(args.verify_live)}
    (stage/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    if args.apply: (LIVE/'stripe_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(f'SPIDER STRIPES: {len(records)} native frames / alpha+outline+canvas+per-frame colors unchanged / 16 palette / fps untouched / 0 failures')


if __name__=='__main__':main()
