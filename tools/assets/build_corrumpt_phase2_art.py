"""二阶段先统一闲置母版：ImageMagick转换，Pillow仅测量与校验像素。"""
from pathlib import Path
from PIL import Image
import json
import math
import shutil
import subprocess
from sprite_frames_writer import write_frames

ROOT=Path(__file__).resolve().parents[2]
PROFILE=ROOT/'data/bosses/claffert.json'


def main():
    profile=json.loads(PROFILE.read_text(encoding='utf-8'));cfg=profile['art']['phase2']
    dest=ROOT/cfg['root'].removeprefix('res://');dest.mkdir(parents=True,exist_ok=True)
    work=ROOT/'work/corrumpt_phase2';work.mkdir(parents=True,exist_ok=True)
    magick=shutil.which('magick') or str(ROOT/'work/tools/imagemagick-7.1.2-35/magick.exe')
    def run(args):
        subprocess.run([magick,*map(str,args)],check=True,capture_output=True)
    palette=ROOT/cfg['palette_reference'].removeprefix('res://')
    source=ROOT/cfg['idle_source_root'].removeprefix('res://')
    out=dest/'frames/phase_2_idle';out.mkdir(parents=True,exist_ok=True)
    aligned=[]
    for i,offset in enumerate(cfg['idle_offsets']):
        target=work/f'idle_aligned_{i}.png'
        run([source/f'{i:02d}.png','-roll',f'{offset[0]:+d}{offset[1]:+d}',
             '-channel','A','-threshold','50%','+channel','+dither','-remap',palette,target])
        aligned.append(target)
    # 只固定最内侧深色花心，不限制三层花瓣的原有闲置摆动。
    x,y=cfg['anchor'];radius=cfg['core_radius'];cw,ch=cfg['canvas']
    mask=work/'core_mask.png';patch=work/'core_patch.png'
    run(['-size',f'{cw}x{ch}','xc:black','-fill','white','-draw',f'circle {x},{y} {x+radius},{y}',
         '-threshold','50%',mask])
    run([aligned[0],mask,'-alpha','off','-compose','CopyOpacity','-composite',patch])
    paths=[];audit=[]
    for i,frame in enumerate(aligned):
        final=out/f'{i:02d}.png'
        run([frame,patch,'-compose','Over','-composite','-strip',final])
        image=Image.open(final).convert('RGBA');bounds=image.getbbox()
        colors={c for c in image.get_flattened_data() if c[3]}
        assert image.size==tuple(cfg['canvas']) and len(colors)<=32
        assert {c[3] for c in image.get_flattened_data()}=={0,255}
        paths.append(cfg['root']+f'frames/phase_2_idle/{i:02d}.png')
        audit.append({'frame':i,'bounds':bounds,'colors':len(colors),'anchor':cfg['anchor']})
    (dest/'godot').mkdir(exist_ok=True);(dest/'masters').mkdir(exist_ok=True)
    animations={'phase_2_idle':{'frames':paths,'fps':cfg['fps'],'loop':True}}
    if cfg.get('blade_source'):
        atlas=Image.open(dest/cfg['blade_source']).convert('RGBA');cols,rows=cfg['blade_grid'];w=atlas.width/cols;h=atlas.height/rows
        blade=[]
        for i,diameter in enumerate(cfg['blade_diameters']):
            rect=(round(i%cols*w),round(i//cols*h),round((i%cols+1)*w),round((i//cols+1)*h))
            crop=atlas.crop(rect);b=crop.getchannel('A').point(lambda v:255 if v>=128 else 0).getbbox()
            size=max(b[2]-b[0],b[3]-b[1]);ratio=diameter/size
            width=round(crop.width*ratio);height=round(crop.height*ratio)
            # 花心用中央深色核心标定，外伸刀瓣不参与单独缩放或偏心。
            dark=[]
            for py in range(round(crop.height*.35),round(crop.height*.65)):
                for px in range(round(crop.width*.35),round(crop.width*.65)):
                    r,g,bl,alpha=crop.getpixel((px,py))
                    if alpha>=128 and max(r,g,bl)<44:dark.append((px,py))
            center=(sum(p[0] for p in dark)/len(dark),sum(p[1] for p in dark)/len(dark)) if dark else (crop.width/2,crop.height/2)
            # 统一以花心最远半径定尺寸，避免旋转45度时尖瓣被128画布裁掉。
            radius=max(math.hypot(px-center[0],py-center[1]) for py in range(crop.height) for px in range(crop.width) if crop.getpixel((px,py))[3]>=128)
            ratio=(diameter/2-1)/radius
            width=round(crop.width*ratio);height=round(crop.height*ratio)
            native=work/f'blade_native_{i}.png';frame=dest/'frames/phase_2_extend'/f'{i:02d}.png';frame.parent.mkdir(parents=True,exist_ok=True)
            run([dest/cfg['blade_source'],'-crop',f'{rect[2]-rect[0]}x{rect[3]-rect[1]}+{rect[0]}+{rect[1]}','+repage','-sample',f'{width}x{height}!',
                 '-channel','A','-threshold','50%','+channel','+dither','-remap',palette,native])
            run(['-size',f'{cw}x{ch}','xc:none',native,'-geometry',f'{x-round(center[0]*ratio):+d}{y-round(center[1]*ratio):+d}','-compose','Over','-composite',patch,'-compose','Over','-composite',frame])
            if i==0:shutil.copyfile(out/'00.png',frame)
            blade.append(cfg['root']+f'frames/phase_2_extend/{i:02d}.png')
        animations['phase_2_extend']={'frames':blade,'fps':16,'loop':False}
        animations['phase_2_retract']={'frames':list(reversed(blade)),'fps':16,'loop':False}
        spin=[]
        for i,angle in enumerate(cfg['spin_angles']):
            frame=dest/'frames/phase_2_spin'/f'{i:02d}.png';frame.parent.mkdir(parents=True,exist_ok=True)
            run([dest/'frames/phase_2_extend/07.png','-virtual-pixel','transparent','-filter','point','-define',f'distort:viewport={cw}x{ch}+0+0','+distort','SRT',f'{x},{y} 1 {angle} {x},{y}',
                 '-channel','A','-threshold','50%','+channel','+dither','-remap',palette,patch,'-compose','Over','-composite',frame])
            spin.append(cfg['root']+f'frames/phase_2_spin/{i:02d}.png')
        animations['phase_2_spin']={'frames':spin,'fps':cfg['spin_fps'],'loop':True}
        animations['phase_2_spin_start']={'frames':spin[:4],'fps':16,'loop':False}
        animations['phase_2_spin_stop']={'frames':spin[4:]+[spin[0]],'fps':16,'loop':False}
        air=Image.open(dest/cfg['airflow_source']).convert('RGBA');aw=air.width/4;fx=[]
        for i in range(4):
            rect=(round(i*aw),0,round((i+1)*aw),air.height);b=air.crop(rect).getchannel('A').point(lambda v:255 if v>=128 else 0).getbbox()
            frame=dest/'frames/airflow'/f'{i:02d}.png';frame.parent.mkdir(parents=True,exist_ok=True)
            run([dest/cfg['airflow_source'],'-crop',f'{b[2]-b[0]}x{b[3]-b[1]}+{rect[0]+b[0]}+{b[1]}','+repage',
                 '-sample',f'{cfg["airflow_size"][0]}x{cfg["airflow_size"][1]}!','-channel','A','-threshold','50%','+channel','+dither','-remap',palette,frame])
            fx.append(cfg['root']+f'frames/airflow/{i:02d}.png')
        animations['airflow']={'frames':fx,'fps':cfg['airflow_fps'],'loop':True}
        for name in ['phase_2_extend','phase_2_spin']:
            for file in (dest/'frames'/name).glob('*.png'):
                image=Image.open(file).convert('RGBA');bounds=image.getbbox()
                assert bounds[0]>0 and bounds[1]>0 and bounds[2]<cw and bounds[3]<ch, f'Clipped blade: {file}'
    write_frames(dest/'godot/Corrumpt_phase2_frames.tres',animations)
    shutil.copyfile(out/'00.png',dest/'masters/phase_2_idle.png')
    (dest/'IDLE_VALIDATION.json').write_text(json.dumps({'frames':audit,'scale':1,'palette_reference':cfg['palette_reference']},indent=2)+'\n',encoding='utf-8')
    run([*[out/f'{i:02d}.png' for i in range(8)],'-background','#10151b','+append','-filter','point','-resize','200%',ROOT/'docs/previews/corrumpt_phase2_idle_standard.png'])
    print('PHASE2 IDLE: 8 PNG frames / 128x128 / fixed center(64,64) / 1:1 pixels / shared32 palette / stable core')


if __name__=='__main__':main()
