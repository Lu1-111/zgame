"""ImageMagick组装共同本体与触手逐帧：一比一像素、共同本体像素绝不随状态重画或镜像。"""
from pathlib import Path
from PIL import Image
import json
import math
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[2]
PROFILE=ROOT/'data/bosses/claffert.json'


def main():
    profile=json.loads(PROFILE.read_text(encoding='utf-8'));cfg=profile['art']['unified']
    dest=ROOT/cfg['root'].removeprefix('res://');dest.mkdir(parents=True,exist_ok=True)
    work=ROOT/'work/corrumpt_unified';work.mkdir(parents=True,exist_ok=True)
    magick=shutil.which('magick') or str(ROOT/'work/tools/imagemagick-7.1.2-35/magick.exe')
    def run(args):
        result=subprocess.run([magick,*map(str,args)],capture_output=True,text=True)
        if result.returncode:raise RuntimeError(result.stderr)
        return result.stdout.strip()
    def save_frame(image,name,index):
        path=dest/'frames'/name/f'{index:02d}.png';path.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(image,path)
        return cfg['root']+f'frames/{name}/{index:02d}.png'
    palette=dest/'palette.png'
    run(['-size','1x1',*[f'xc:{color}' for color in cfg['palette']],'+append','-depth','8',palette])
    core=work/'body.png'
    run([dest/cfg['body_source'],'-channel','A','-threshold','50%','+channel','-trim','+repage',
         '-sample',f'{cfg["body_visible_width"]}x{cfg["body_visible_height"]}!',
         '+dither','-remap',palette,'-strip',core])
    body=[];bx,by=map(int,cfg['body_anchor']);cw,ch=map(int,cfg['body_canvas'])
    for index,(dx,dy) in enumerate(cfg['body_pulse_deltas']):
        width,height=int(cfg['body_visible_width']+dx),int(cfg['body_visible_height']+dy)
        resized=work/f'body_{index}.png';target=work/f'body_canvas_{index}.png'
        if cfg.get('body_runtime_reference_root'):
            shutil.copyfile(ROOT/cfg['body_runtime_reference_root'].removeprefix('res://')/'frames/phase_1_idle'/f'{index:02d}.png',target)
        else:
            run([core,'-sample',f'{width}x{height}!',resized])
            run(['-size',f'{cw}x{ch}','xc:none',resized,'-geometry',f'+{bx-width//2}+{by-height}','-compose','Over','-composite',target])
        body.append(save_frame(target,'phase_1_idle',index))
    # 源图只读测定左端根点；所有图像转换、缩放与合成均交给ImageMagick。
    atlas_path=dest/cfg['arm_source'];atlas=Image.open(atlas_path).convert('RGBA')
    cols,rows=map(int,cfg['arm_source_grid']);cellw=atlas.width/cols;cellh=atlas.height/rows
    edges=[0]
    alpha=atlas.getchannel('A')
    for line in range(1,rows):
        center=line*cellh;choices=[]
        for y in range(round(center-cellh*.22),round(center+cellh*.22)):
            occupied=sum(value>=128 for value in alpha.crop((0,y,atlas.width,y+1)).get_flattened_data())
            choices.append((occupied,abs(y-center),y))
        edges.append(min(choices)[2])
    edges.append(atlas.height)
    edges=cfg.get('arm_row_edges',edges)
    armw,armh=map(int,cfg['arm_canvas']);ax,ay=map(int,cfg['arm_anchor'])
    arm_cache={}
    def connected_bounds(crop,point):
        # 只读定位根端所属连通块，排除邻格尾梢或根部几颗像素撑大包围盒。
        alpha=crop.getchannel('A')
        occupied={(x,y) for y in range(crop.height) for x in range(crop.width) if alpha.getpixel((x,y))>=128}
        start=min(occupied,key=lambda pixel:(pixel[0]-point[0])**2+(pixel[1]-point[1])**2)
        occupied.remove(start);stack=[start];xs=[start[0]];ys=[start[1]]
        while stack:
            x,y=stack.pop()
            for neighbor in [(x-1,y),(x+1,y),(x,y-1),(x,y+1),(x-1,y-1),(x-1,y+1),(x+1,y-1),(x+1,y+1)]:
                if neighbor in occupied:
                    occupied.remove(neighbor);stack.append(neighbor);xs.append(neighbor[0]);ys.append(neighbor[1])
        return min(xs),min(ys),max(xs)+1,max(ys)+1
    def arm(index,length,height,down=False):
        key=(index,length,height,down)
        if key in arm_cache:return arm_cache[key]
        # 绘制图集的长平挥末端越过名义分格；利用实际空白隔离完整藤蔓，排除相邻格末梢。
        cell=(round((index%cols)*cellw+cellw*.10),edges[index//cols],min(atlas.width,round((index%cols+1)*cellw+cellw*.12)),edges[index//cols+1])
        if cfg.get('isolate_arm_component'):
            # 根端连通块能排除其他格，因此保留整行右侧范围，长触手末梢不会被格线裁断。
            cell=(round((index%cols)*cellw),edges[index//cols],atlas.width,edges[index//cols+1])
        source_path=atlas_path
        override=cfg.get('arm_overrides',{}).get(str(index))
        if override:
            source_path=dest/override['path'];source=Image.open(source_path).convert('RGBA');cell=(0,0,source.width,source.height)
            crop=source
        else:
            crop=atlas.crop(cell)
        mask=crop.getchannel('A').point(lambda a:255 if a>=128 else 0)
        bounds=mask.getbbox()
        if bounds is None:raise RuntimeError(f'Empty source arm {index}')
        if cfg.get('isolate_arm_component'):
            mark=override['source_anchor'] if override else cfg['arm_source_anchors'][index]
            bounds=connected_bounds(crop,(float(mark[0])-cell[0],float(mark[1])-cell[1]))
        x0,y0,x1,y1=bounds;ys=[]
        if cfg.get('arm_fit')=='isotropic_reach':
            # 只做等比重采样：不单独压扁高度或拉长宽度，细纹与棘刺不会变成大片色带。
            mark=override['source_anchor'] if override else cfg['arm_source_anchors'][index]
            root_x,root_y=float(mark[0])-cell[0],float(mark[1])-cell[1]
            ratio=float(length)/max(1,x1-root_x)
            width=max(1,round((x1-x0)*ratio));native_h=max(1,round((y1-y0)*ratio))
            image=work/f'arm_{index}_{length}_{height}_{int(down)}.png'
            source_crop=work/f'arm_crop_{index}_{length}_{height}_{int(down)}.png'
            run([source_path,'-crop',f'{x1-x0}x{y1-y0}+{cell[0]+x0}+{cell[1]+y0}','+repage',
                 '-sample',f'{width}x{native_h}!', '-channel','A','-threshold','50%','+channel','+dither','-remap',palette,source_crop])
            left=ax-round((root_x-x0)*ratio);top=ay-round((root_y-y0)*ratio)
            if left<0 or left+width>armw or top<0 or top+native_h>armh:raise RuntimeError(f'Arm outside canvas: {key}, x={left}..{left+width}, y={top}..{top+native_h}')
            run(['-size',f'{armw}x{armh}','xc:none',source_crop,'-geometry',f'+{left}+{top}','-compose','Over','-composite',image])
            if not down:
                # 只隐藏埋入地面的根端，不改变触手的粗细和纹理。
                clip=int(cfg['arm_ground_clip_y'])
                run([image,'-crop',f'{armw}x{clip}+0+0','+repage','-gravity','NorthWest','-background','none','-extent',f'{armw}x{armh}',image])
            arm_cache[key]=image
            return image
        for y in range(y0,y1):
            if any(crop.getpixel((x,y))[3]>=128 for x in range(x0,min(x1,x0+max(2,round((x1-x0)*.035))))):ys.append(y)
        root_y=sum(ys)/len(ys)
        vertical=max(1,(y1-root_y) if down else (root_y-y0))
        ratio=float(height)/vertical
        width=max(1,round(length));native_h=max(1,round((y1-y0)*ratio))
        image=work/f'arm_{index}_{length}_{height}_{int(down)}.png'
        source_crop=work/f'arm_crop_{index}_{length}_{height}_{int(down)}.png'
        run([atlas_path,'-crop',f'{x1-x0}x{y1-y0}+{cell[0]+x0}+{cell[1]+y0}','+repage',
             '-sample',f'{width}x{native_h}!', '-channel','A','-threshold','50%','+channel','+dither','-remap',palette,source_crop])
        top=ay-round((root_y-y0)*ratio)
        if top<0 or top+native_h>armh:raise RuntimeError(f'Arm outside canvas: {key}, y={top}..{top+native_h}')
        run(['-size',f'{armw}x{armh}','xc:none',source_crop,'-geometry',f'+{ax}+{top}','-compose','Over','-composite',image])
        arm_cache[key]=image
        return image
    idle=[arm(int(cfg.get('idle_sources',[0,1,2,3])[i]),int(cfg['idle_lengths'][i]),int(cfg['idle_heights'][i])) for i in range(4)]
    raises=[idle[0]]+[arm(4+i,int(cfg['raise_lengths'][i]),int(cfg['raise_heights'][i])) for i in range(1,4)]
    swing=[arm(int(cfg['swing_sources'][i]),int(cfg['swing_lengths'][i]),int(cfg['swing_heights'][i])) for i in range(6)]
    empty=work/'empty.png';run(['-size',f'{armw}x{armh}','xc:none',empty])
    retract=[arm(13,int(length),int(height)) for length,height in zip(cfg['retract_lengths'],cfg['retract_heights'])]
    slam=raises+[swing[0],swing[-1]]+retract+[idle[0]]
    bury=arm(14,28,16,True)
    withdraw=arm(15,24,18)
    # 地下阶段仍保留地表根端，避免两侧触手交替闪灭。
    spikes=[idle[0],bury,bury,idle[0],idle[0],withdraw,idle[0],idle[0]]
    casting=[idle[0],idle[1],idle[2],idle[0]]
    actions={'arm_idle':idle,'slam':slam,'slam_downstroke':swing,'spikes':spikes,
             'needles':casting,'gravity':casting,'spores':casting,'repel':casting}
    output={'phase_1_idle':{'frames':body,'loop':True,'fps':cfg['fps']}}
    for name,images in actions.items():
        output[name]={'frames':[save_frame(image,name,index) for index,image in enumerate(images)],
                      'loop':name=='arm_idle','fps':12 if name=='slam_downstroke' else cfg['fps']}
    # 另存完整帧预览，核心本体从同一张body_canvas_0逐字节覆盖，方向只改变触手。
    previews={};pw,ph=map(int,cfg['preview_canvas']);px,py=map(int,cfg['preview_anchor']);ox,oy=map(int,cfg['arm_attachment'])
    def compose(name,index,right,left):
        flipped=work/'left.png';run([left,'-flop',flipped])
        target=work/f'preview_{name}_{index}.png'
        run(['-size',f'{pw}x{ph}','xc:none',flipped,'-geometry',f'+{px-ox-(armw-ax)}+{py+oy-ay}','-compose','Over','-composite',
             right,'-geometry',f'+{px+ox-ax}+{py+oy-ay}','-compose','Over','-composite',
             work/'body_canvas_0.png','-geometry',f'+{px-bx}+{py-by}','-compose','Over','-composite',target])
        path=dest/'preview_frames'/name/f'{index:02d}.png';path.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(target,path)
        return cfg['root']+f'preview_frames/{name}/{index:02d}.png'
    for name in ['phase_1_idle',*actions.keys()]:
        images=idle if name in ['phase_1_idle','arm_idle'] else actions[name]
        if name=='phase_1_idle':images=[idle[index%4] for index in range(8)]
        previews[name]={'frames':[compose(name,index,image,idle[0]) for index,image in enumerate(images)],'fps':cfg['fps'],'loop':name=='phase_1_idle'}
    # 二阶段维持已确认花体，缩至相同84像素量级；保持花心居中。
    flower=[];fcw,fch=map(int,cfg['flower_canvas']);fx,fy=map(int,cfg['flower_anchor'])
    for index in range(8):
        original=ROOT/cfg['body_runtime_reference_root'].removeprefix('res://')/'frames/phase_2_idle'/f'{index:02d}.png'
        flower.append(save_frame(original,'phase_2_idle',index))
    output['phase_2_idle']={'frames':flower,'fps':cfg['fps'],'loop':True}
    effect_atlas=Image.open(dest/cfg['effect_source']).convert('RGBA') if cfg.get('effect_source') else None
    for name,size in cfg['effect_sizes'].items():
        frames=[]
        crops=[];union=None
        if effect_atlas:
            row=cfg['effect_rows'][name];cols=int(cfg['effect_columns']);ew=effect_atlas.width/cols
            for index in range(4):
                rect=(round(index*ew),int(row[0]),round((index+1)*ew),int(row[1]))
                bounds=effect_atlas.crop(rect).getchannel('A').point(lambda a:255 if a>=128 else 0).getbbox()
                crops.append(rect)
                union=bounds if union is None else (min(union[0],bounds[0]),min(union[1],bounds[1]),max(union[2],bounds[2]),max(union[3],bounds[3]))
            factor=min(size[0]/(union[2]-union[0]),size[1]/(union[3]-union[1]))
        for index in range(4):
            image=work/f'fx_{name}_{index}.png'
            if effect_atlas and cfg.get('effect_frame_boxes'):
                boxes=cfg['effect_frame_boxes'][name];x0,y0,x1,y1=boxes[index];rect=crops[index]
                mw=max(b[2]-b[0] for b in boxes);mh=max(b[3]-b[1] for b in boxes)
                factor=min(size[0]/mw,size[1]/mh)
                fit=cfg['effect_fit'][name]
                if fit=='canvas':
                    sw=max(1,round((x1-x0)*size[0]/mw));sh=max(1,round((y1-y0)*size[1]/mh))
                else:
                    sw=max(1,round((x1-x0)*factor));sh=max(1,round((y1-y0)*factor))
                temp=work/f'fx_crop_{name}_{index}.png'
                run([dest/cfg['effect_source'],'-crop',f'{x1-x0}x{y1-y0}+{rect[0]+x0}+{rect[1]+y0}','+repage','-sample',f'{sw}x{sh}!',
                     '-channel','A','-threshold','50%','+channel','+dither','-remap',palette,temp])
                run(['-size',f'{size[0]}x{size[1]}','xc:none',temp,'-geometry',f'+{(size[0]-sw)//2}+{size[1]-sh if name in ["spike","impact"] else (size[1]-sh)//2}','-compose','Over','-composite',image])
            elif effect_atlas:
                rect=crops[index];x0,y0,x1,y1=union;sw=max(1,round((x1-x0)*factor));sh=max(1,round((y1-y0)*factor))
                if name in cfg.get('ring_rendering',{}).get('kinds',[]):
                    # 环带纹理保留固定原生高度，动态扩散只改变采样位置，不缩放纹素。
                    run([dest/cfg['effect_source'],'-crop',f'{x1-x0}x{y1-y0}+{rect[0]+x0}+{rect[1]+y0}','+repage','-sample',f'{size[0]}x{size[1]}!',
                         '-channel','A','-threshold','50%','+channel','+dither','-remap',palette,image])
                else:
                    temp=work/f'fx_crop_{name}_{index}.png'
                    run([dest/cfg['effect_source'],'-crop',f'{x1-x0}x{y1-y0}+{rect[0]+x0}+{rect[1]+y0}','+repage','-sample',f'{sw}x{sh}!',
                         '-channel','A','-threshold','50%','+channel','+dither','-remap',palette,temp])
                    run(['-size',f'{size[0]}x{size[1]}','xc:none',temp,'-geometry',f'+{(size[0]-sw)//2}+{size[1]-sh if name in ["spike","impact"] else (size[1]-sh)//2}','-compose','Over','-composite',image])
            else:
                raise RuntimeError('当前版本需要effect_source，不能回退到弃用的历史特效。')
            frames.append(save_frame(image,name,index))
        output[name]={'frames':frames,'fps':cfg['fps'],'loop':name in ['needle','spore','gravity_ring']}
    from sprite_frames_writer import write_frames
    (dest/'godot').mkdir(exist_ok=True);(dest/'masters').mkdir(exist_ok=True)
    write_frames(dest/'godot/Corrumpt_combat_frames.tres',output)
    write_frames(dest/'godot/Claffert_idle_frames.tres',{name:output[name] for name in ['phase_1_idle','phase_2_idle']})
    write_frames(dest/'godot/Corrumpt_preview_frames.tres',previews)
    run([work/'body_canvas_0.png','-trim','+repage',dest/'masters/phase_1_idle.png'])
    run([dest/'frames/phase_2_idle/00.png','-trim','+repage',dest/'masters/phase_2_idle.png'])
    profile['art']['root']=cfg['root']
    profile['art']['pixel']={'body_canvas':cfg['body_canvas'],'body_anchor':cfg['body_anchor'],'body_height':cfg['body_visible_height'],
                            'body_width':cfg['body_visible_width'],'render_scale':1,'pixels_per_world_unit':1,
                            'flower_canvas':cfg['flower_canvas'],'flower_anchor':cfg['flower_anchor'],'animations':{}}
    profile['art']['anchors']={'phase_1_idle':[cfg['body_anchor']]*8,'phase_2_idle':[cfg['flower_anchor']]*8}
    profile['art']['native_cell']={'phase_1_idle':cfg['body_canvas'],'phase_2_idle':cfg['flower_canvas']}
    profile['art']['combat_anchors']={name:[cfg['arm_anchor']]*len(row['frames']) for name,row in output.items() if name in actions}
    for name,row in output.items():
        profile['art']['pixel']['animations'][name]={'frames':list(range(len(row['frames']))),'kind':'body' if name=='phase_1_idle' else 'flower' if name=='phase_2_idle' else 'arm' if name in actions else 'fx'}
    cfg['arm_source_row_edges']=edges
    cfg['body_source_shared_by_all_states']=True
    PROFILE.write_text(json.dumps(profile,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('CORRUMPT UNIFIED: common persistent body, 84px height (player 42px), 1:1 pixels, tendril fit='+cfg.get('arm_fit','legacy')+', stable root')


if __name__=='__main__':main()
