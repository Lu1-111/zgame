"""ImageMagick转换过场逐帧与虚空素材；Pillow只测量，首尾严格复用既有母版。"""
from pathlib import Path
from PIL import Image
import subprocess
import json
from sprite_frames_writer import write_frames

ROOT = Path(__file__).resolve().parents[2]


def main():
    profile = json.loads((ROOT/'data/bosses/claffert.json').read_text(encoding='utf-8'))
    dest = ROOT/profile['sequence']['root'].removeprefix('res://')
    magick = ROOT/'work/tools/imagemagick-7.1.2-35/magick.exe'
    palette = ROOT/profile['art']['phase2']['palette_reference'].removeprefix('res://')
    temp = ROOT/'work/corrumpt_sequences'
    temp.mkdir(exist_ok=True, parents=True)

    def run(args):
        subprocess.run([str(magick), *map(str, args)], check=True, capture_output=True)

    result = {}
    for kind, cols, rows, canvas in [('opening', 3, 2, 128), ('void', 4, 1, 96)]:
        source = dest/'sources'/f'{kind}.png'
        sheet = Image.open(source).convert('RGBA')
        w, h = sheet.width/cols, sheet.height/rows
        frames = []
        folder = dest/'frames'/kind
        folder.mkdir(parents=True, exist_ok=True)
        for index in range(cols*rows):
            x, y = round(index % cols*w), round(index//cols*h)
            width, height = round((index % cols+1)*w)-x, round((index//cols+1)*h)-y
            crop = sheet.crop((x, y, x+width, y+height))
            box = crop.getchannel('A').point(lambda a: 255 if a >= 200 else 0).getbbox()
            bw, bh = box[2]-box[0], box[3]-box[1]
            ratio = 84/max(bw, bh) if kind == 'void' else 84/bh
            sw, sh = round(bw*ratio), round(bh*ratio)
            native = temp/f'{kind}_{index}.png'
            frame = folder/f'{index:02d}.png'
            run([source, '-crop', f'{bw}x{bh}+{x+box[0]}+{y+box[1]}', '+repage',
                 '-sample', f'{sw}x{sh}!', '-channel', 'A', '-threshold', '75%', '+channel',
                 '+dither', '-remap', palette, native])
            offset = f'+{(canvas-sw)//2}+{112-sh if kind == "opening" else (canvas-sh)//2}'
            background = temp/'void_disk.png'
            if kind == 'void':
                run(['-size', '96x96', 'xc:none', '+antialias', '-fill', '#0d090d', '-draw', 'circle 48,48 82,48', background])
            run([background if kind == 'void' else '-size', *([] if kind == 'void' else ['128x128', 'xc:none']),
                 native, '-geometry', offset, '-compose', 'Over', '-composite',
                 '-channel', 'A', '-threshold', '50%', '+channel', '+dither', '-remap', palette, '-strip', frame])
            frames.append(profile['sequence']['root']+f'frames/{kind}/{index:02d}.png')
        result[kind] = {'frames': frames, 'fps': 12, 'loop': kind == 'void'}
    # 首尾使用已批准正式帧，不重绘、不重标人物或Boss尺寸。
    import shutil
    shutil.copyfile(ROOT/profile['art']['root'].removeprefix('res://')/'frames/phase_1_idle/00.png', dest/'frames/opening/00.png')
    shutil.copyfile(ROOT/profile['art']['phase2']['root'].removeprefix('res://')/'frames/phase_2_idle/00.png', dest/'frames/opening/05.png')
    write_frames(dest/'CorrumptSequence_frames.tres', result)
    print('SEQUENCE ART: 6 opening frames128x128, exact approved endpoints; 4 void frames96x96')


if __name__ == '__main__':
    main()
